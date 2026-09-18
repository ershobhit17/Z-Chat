import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Server-controlled app version checking.
/// Reads the app_config table and determines if an update is required.
/// Call [checkVersion] on app startup before rendering the main UI.
class AppVersionService {
  static final AppVersionService instance = AppVersionService._();
  AppVersionService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Current app version — must match pubspec.yaml version
  static const String currentVersion = '1.0.0';

  AppVersionResult? _lastResult;
  AppVersionResult? get lastResult => _lastResult;

  /// Checks the server for the minimum and latest versions.
  /// Returns null if the check fails (don't block the user).
  Future<AppVersionResult?> checkVersion() async {
    try {
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'web';

      final res = await _supabase
          .from('app_config')
          .select()
          .eq('platform', platform)
          .eq('is_active', true)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (res == null) {
        // Also try 'all' platform config
        final allRes = await _supabase
            .from('app_config')
            .select()
            .eq('platform', 'all')
            .eq('is_active', true)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (allRes == null) return null;
        return _parseResult(allRes);
      }

      final result = _parseResult(res);
      _lastResult = result;
      return result;
    } catch (e) {
      debugPrint('AppVersionService: version check failed ($e) — proceeding normally');
      return null; // Don't block users if check fails
    }
  }

  AppVersionResult _parseResult(Map<String, dynamic> json) {
    final minVersion = json['minimum_supported_version'] as String? ?? '1.0.0';
    final latestVersion = json['latest_version'] as String? ?? '1.0.0';
    final updateRequired = json['update_required'] as bool? ?? false;
    final message = json['update_message'] as String? ?? 'A new version is available.';
    final storeUrl = json['store_url'] as String?;

    final isBelowMinimum = _compareVersions(currentVersion, minVersion) < 0;
    final isBelowLatest = _compareVersions(currentVersion, latestVersion) < 0;

    return AppVersionResult(
      currentVersion: currentVersion,
      minimumVersion: minVersion,
      latestVersion: latestVersion,
      isForceUpdateRequired: updateRequired || isBelowMinimum,
      isSoftUpdateAvailable: !isBelowMinimum && isBelowLatest,
      message: message,
      storeUrl: storeUrl,
    );
  }

  /// Compare two semver strings. Returns negative if a < b.
  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((v) => int.tryParse(v) ?? 0).toList();
    final bParts = b.split('.').map((v) => int.tryParse(v) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }

  /// Opens the appropriate app store to update.
  Future<void> openStore(String? storeUrl) async {
    if (storeUrl == null || storeUrl.isEmpty) return;
    try {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open store: $e');
    }
  }
}

class AppVersionResult {
  final String currentVersion;
  final String minimumVersion;
  final String latestVersion;
  final bool isForceUpdateRequired;
  final bool isSoftUpdateAvailable;
  final String message;
  final String? storeUrl;

  const AppVersionResult({
    required this.currentVersion,
    required this.minimumVersion,
    required this.latestVersion,
    required this.isForceUpdateRequired,
    required this.isSoftUpdateAvailable,
    required this.message,
    this.storeUrl,
  });
}

/// Widget that wraps the app and shows force/soft update dialogs.
/// Place this around the main content in AuthWrapper or HomeScreen.
class AppVersionGate extends StatefulWidget {
  final Widget child;

  const AppVersionGate({super.key, required this.child});

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> {
  bool _checked = false;
  bool _isForceUpdateRequired = false;
  AppVersionResult? _result;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    final result = await AppVersionService.instance.checkVersion();
    if (!mounted) return;

    if (result == null) {
      setState(() => _checked = true);
      return;
    }

    setState(() {
      _checked = true;
      _result = result;
      _isForceUpdateRequired = result.isForceUpdateRequired;
    });

    if (result.isSoftUpdateAvailable && !result.isForceUpdateRequired) {
      _showSoftUpdateDialog(result);
    }
  }

  void _showSoftUpdateDialog(AppVersionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppVersionService.instance.openStore(result.storeUrl);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      // Brief loading while checking version — shows app background color
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isForceUpdateRequired && _result != null) {
      return _ForceUpdateScreen(result: _result!);
    }

    return widget.child;
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final AppVersionResult result;

  const _ForceUpdateScreen({required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'Z',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Update Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your version: ${result.currentVersion}  •  Required: ${result.minimumVersion}',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => AppVersionService.instance.openStore(result.storeUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Update Z Chat',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
