import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../models/models.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  UserProfile? _currentProfile;
  bool _isLoading = true;
  Timer? _heartbeatTimer;

  UserProfile? get currentProfile => _currentProfile;
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  bool get isLoading => _isLoading;

  AuthService() {
    _init();
  }

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (session != null) {
        await _fetchProfile(session.user.id);
        _updateOnlineStatus(true);
        _startHeartbeat();
      } else {
        _stopHeartbeat();
        _currentProfile = null;
      }
      _isLoading = false;
      notifyListeners();
    });

    if (_supabase.auth.currentUser != null) {
      _fetchProfile(_supabase.auth.currentUser!.id).then((_) {
        _updateOnlineStatus(true);
        _startHeartbeat();
        _isLoading = false;
        notifyListeners();
      });
    } else {
      _isLoading = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (currentUser != null) {
        _updateOnlineStatus(true);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _updateOnlineStatus(false);
    super.dispose();
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        _currentProfile = UserProfile.fromJson(res);
      }
    } catch (e) {
      debugPrint('Error fetching current profile: $e');
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Username validation: 3-20 characters, alphanumeric, underscores, dots
  String? validateUsername(String username) {
    final trimmed = username.trim();
    if (trimmed.length < 3) return 'Username must be at least 3 characters';
    if (trimmed.length > 20) return 'Username cannot exceed 20 characters';
    final validRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!validRegex.hasMatch(trimmed)) {
      return 'Only letters, numbers, underscores, and dots are allowed';
    }
    return null;
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final lower = username.trim().toLowerCase();
    try {
      final res = await _supabase
          .from('profiles')
          .select('id')
          .eq('username_lower', lower)
          .maybeSingle();
      return res == null;
    } catch (e) {
      return true;
    }
  }

  // Sign up using Username + Password
  Future<void> signUp({
    required String username,
    required String password,
    required String displayName,
    String? recoveryEmail,
  }) async {
    final lowerUsername = username.trim().toLowerCase();
    final validationError = validateUsername(username);
    if (validationError != null) {
      throw Exception(validationError);
    }

    final isAvailable = await isUsernameAvailable(username);
    if (!isAvailable) {
      throw Exception('Username "@$username" is already taken.');
    }

    // Map username to internal Supabase Auth email deterministically
    // (recovery email is stored in metadata and profiles for account recovery)
    final authEmail = '$lowerUsername@${AppConstants.internalAuthDomain}';

    final authRes = await _supabase.auth.signUp(
      email: authEmail,
      password: password,
      data: {
        'username': username.trim(),
        'username_lower': lowerUsername,
        'display_name': displayName.trim().isEmpty ? username.trim() : displayName.trim(),
        'recovery_email': recoveryEmail?.trim(),
      },
    );

    final user = authRes.user;
    if (user != null) {
      // If authRes.session is null, immediately signInWithPassword
      if (authRes.session == null) {
        try {
          await _supabase.auth.signInWithPassword(email: authEmail, password: password);
        } catch (_) {}
      }

      // Upsert profile safely (the Postgres trigger handle_new_user already did this)
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'username': username.trim(),
          'username_lower': lowerUsername,
          'display_name': displayName.trim().isEmpty ? username.trim() : displayName.trim(),
          'is_online': true,
          'last_seen': DateTime.now().toIso8601String(),
        });
      } catch (upsertErr) {
        debugPrint('Profile handled by database trigger or upsert note: $upsertErr');
      }

      await _fetchProfile(user.id);
      _updateOnlineStatus(true);
      notifyListeners();
    }
  }

  // Sign in using Username + Password
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final trimmed = username.trim();
    final lowerUsername = trimmed.toLowerCase().replaceAll('@', '');

    if (lowerUsername.isEmpty) {
      throw Exception('Please enter your username or email.');
    }

    if (password.isEmpty) {
      throw Exception('Please enter your password.');
    }

    // Determine the email to attempt login with
    final isDirectEmail = trimmed.contains('@') && trimmed.contains('.');
    final emailToUse = isDirectEmail
        ? trimmed
        : '$lowerUsername@${AppConstants.internalAuthDomain}';

    try {
      // Perform direct Supabase Auth signIn
      final authRes = await _supabase.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );

      if (authRes.user != null) {
        await _fetchProfile(authRes.user!.id);
        _updateOnlineStatus(true);
        notifyListeners();
      }
    } on AuthApiException catch (e) {
      if (e.code == 'invalid_credentials' ||
          e.message.toLowerCase().contains('invalid login credentials')) {
        throw Exception('Incorrect username or password. Please verify your details.');
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        throw Exception('Account not verified. Please check your email or contact support.');
      } else {
        throw Exception(e.message);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _updateOnlineStatus(false);
    await _supabase.auth.signOut();
    _currentProfile = null;
    notifyListeners();
  }

  // Update Profile
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? status,
    String? avatarUrl,
    String? avatarObjectKey,
    String? bannerObjectKey,
    bool? isPrivate,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (status != null) updates['status'] = status;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (avatarObjectKey != null) updates['avatar_object_key'] = avatarObjectKey;
    if (bannerObjectKey != null) updates['banner_object_key'] = bannerObjectKey;
    if (isPrivate != null) updates['is_private'] = isPrivate;

    await _supabase.from('profiles').update(updates).eq('id', user.id);
    await _fetchProfile(user.id);
    notifyListeners();
  }
}
