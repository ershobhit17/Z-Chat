import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/theme_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _recoveryEmailController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool? _isUsernameAvailable;
  bool _isCheckingUsername = false;
  Timer? _debounceTimer;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim().toLowerCase();
    if (trimmed.length < 3) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final auth = context.read<AuthService>();
      final available = await auth.isUsernameAvailable(trimmed);
      if (mounted) {
        setState(() {
          _isUsernameAvailable = available;
          _isCheckingUsername = false;
        });
      }
    });
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim().toLowerCase();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final recoveryEmail = _recoveryEmailController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username and password are required.');
      return;
    }

    if (username.length < 3) {
      setState(() => _errorMessage = 'Username must be at least 3 characters.');
      return;
    }

    // RegEx validation for username
    final validUsername = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validUsername.hasMatch(username)) {
      setState(() => _errorMessage = 'Username can only contain letters, numbers, and underscores.');
      return;
    }

    if (_isUsernameAvailable == false) {
      setState(() => _errorMessage = 'This username is already taken. Please choose another.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.signUp(
        username: username,
        password: password,
        displayName: displayName.isEmpty ? username : displayName,
        recoveryEmail: recoveryEmail.isNotEmpty ? recoveryEmail : null,
      );

      if (mounted) {
        context.read<ThemeProvider>().loadFromSupabase();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final err = e.toString().replaceAll('Exception:', '').trim();
          if (err.contains('SocketFailed') || err.contains('Failed host lookup') || err.contains('SocketException') || err.contains('errno = 7')) {
            _errorMessage = 'Unable to connect to server. Please check your internet connection or mobile data settings.';
          } else {
            _errorMessage = err;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF09090C);
    const surfaceDark = Color(0xFF131318);
    const borderDark = Color(0xFF22222A);
    const accentColor = Color(0xFF7C5CFF);
    const textMuted = Color(0xFF8E8E9A);

    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row with Back button and Logo Mark
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderDark, width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // balance back button
                  ],
                ),
                const SizedBox(height: 20),

                // Title & Subtitle
                Center(
                  child: Text(
                    'Create your account',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Choose a unique username to get started',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Error Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1319),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5484D).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE5484D)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFFFA2A5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderDark, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Display Name
                      Text(
                        'Display Name',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _displayNameController,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: textMuted, size: 18),
                          hintText: 'e.g. Alex',
                          hintStyle: GoogleFonts.inter(color: textMuted.withValues(alpha: 0.6), fontSize: 13.5),
                          filled: true,
                          fillColor: const Color(0xFF0C0C10),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username
                      Text(
                        'Username',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.alternate_email_rounded, color: textMuted, size: 18),
                          suffixIcon: _isCheckingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                                  ),
                                )
                              : _isUsernameAvailable != null
                                  ? Icon(
                                      _isUsernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                      color: _isUsernameAvailable! ? const Color(0xFF30A46C) : const Color(0xFFE5484D),
                                      size: 18,
                                    )
                                  : null,
                          hintText: 'alex_z',
                          hintStyle: GoogleFonts.inter(color: textMuted.withValues(alpha: 0.6), fontSize: 13.5),
                          filled: true,
                          fillColor: const Color(0xFF0C0C10),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Text(
                        'Password',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: textMuted, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: textMuted,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          hintText: 'Minimum 6 characters',
                          hintStyle: GoogleFonts.inter(color: textMuted.withValues(alpha: 0.6), fontSize: 13.5),
                          filled: true,
                          fillColor: const Color(0xFF0C0C10),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Recovery Email (Optional)
                      Row(
                        children: [
                          Text(
                            'Recovery Email',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(optional)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: _recoveryEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.mail_outline_rounded, color: textMuted, size: 18),
                          hintText: 'alex@example.com',
                          hintStyle: GoogleFonts.inter(color: textMuted.withValues(alpha: 0.6), fontSize: 13.5),
                          filled: true,
                          fillColor: const Color(0xFF0C0C10),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _handleRegister,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Create Account',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.inter(color: textMuted, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Sign in',
                        style: GoogleFonts.inter(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'No phone number • 100% Private',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
