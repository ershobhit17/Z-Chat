import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Content moderation service that proxies Sightengine via a Supabase Edge Function.
/// The Sightengine credentials are stored as Supabase secrets — never in the client.
///
/// Policy when moderation is unavailable: allow_pending (configured server-side).
/// Thresholds (block/review) are configured in the Edge Function.
class ModerationService {
  static final ModerationService instance = ModerationService._();
  ModerationService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Moderate text content (post caption, comment, etc.)
  ///
  /// Returns [ModerationResult.allowed] if content is safe.
  /// Returns [ModerationResult.blocked] if content must be rejected.
  /// Returns [ModerationResult.review] if content needs human review.
  /// Returns [ModerationResult.pendingModeration] if service is unavailable (allow through).
  Future<ModerationResult> moderateText({
    required String text,
    required String targetType, // 'post', 'comment', 'message', 'profile'
    required String targetId,
    String? userId,
  }) async {
    if (text.trim().isEmpty) return ModerationResult.allowed();

    try {
      return await _callModerationEdgeFunction(
        type: 'text',
        content: text,
        targetType: targetType,
        targetId: targetId,
        userId: userId,
      );
    } catch (e) {
      debugPrint('ModerationService.moderateText error: $e — allowing with pending flag');
      return ModerationResult.pendingModeration();
    }
  }

  /// Moderate an image by URL (publicly accessible ImageKit URL).
  Future<ModerationResult> moderateImage({
    required String imageUrl,
    required String targetType,
    required String targetId,
    String? userId,
  }) async {
    if (imageUrl.isEmpty) return ModerationResult.allowed();

    try {
      return await _callModerationEdgeFunction(
        type: 'image',
        content: imageUrl,
        targetType: targetType,
        targetId: targetId,
        userId: userId,
      );
    } catch (e) {
      debugPrint('ModerationService.moderateImage error: $e — allowing with pending flag');
      return ModerationResult.pendingModeration();
    }
  }

  Future<ModerationResult> _callModerationEdgeFunction({
    required String type,
    required String content,
    required String targetType,
    required String targetId,
    String? userId,
  }) async {
    final res = await _supabase.functions.invoke(
      'moderate-content',
      body: {
        'type': type,
        'content': content,
        'target_type': targetType,
        'target_id': targetId,
        'user_id': ?userId,
      },
    );

    if (res.status != 200 || res.data == null) {
      debugPrint('Moderation Edge Function returned status ${res.status}');
      return ModerationResult.pendingModeration();
    }

    final data = res.data is Map<String, dynamic>
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data.toString()) as Map<String, dynamic>;

    final status = data['status'] as String? ?? 'pending_moderation';
    final category = data['category'] as String?;
    final score = (data['score'] as num?)?.toDouble();
    final reason = data['reason'] as String?;

    return ModerationResult(
      status: _parseStatus(status),
      category: category,
      score: score,
      reason: reason,
    );
  }

  ModerationStatus _parseStatus(String status) {
    switch (status) {
      case 'allowed':
        return ModerationStatus.allowed;
      case 'blocked':
        return ModerationStatus.blocked;
      case 'review':
        return ModerationStatus.review;
      default:
        return ModerationStatus.pendingModeration;
    }
  }

  /// Submit a user report via the atomic DB function.
  /// Handles deduplication and threshold enforcement server-side.
  Future<ReportResult> submitReport({
    required String targetType, // 'user', 'post', 'comment', 'moment'
    required String targetId,
    required String reportedUserId,
    required String reason,
    String? description,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return ReportResult(success: false, error: 'Not authenticated');

    try {
      final res = await _supabase.rpc('submit_report', params: {
        'p_reporter_id': uid,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_reported_user_id': reportedUserId,
        'p_reason': reason,
        'p_description': description,
      });

      final data = res as Map<String, dynamic>?;
      if (data == null) return ReportResult(success: false, error: 'Unknown error');

      return ReportResult(
        success: data['success'] as bool? ?? false,
        error: data['error'] as String?,
        reportId: data['report_id'] as String?,
      );
    } catch (e) {
      debugPrint('ModerationService.submitReport error: $e');
      return ReportResult(success: false, error: e.toString());
    }
  }
}

// ─── Result Types ─────────────────────────────────────────────────────────────

enum ModerationStatus { allowed, blocked, review, pendingModeration }

class ModerationResult {
  final ModerationStatus status;
  final String? category;
  final double? score;
  final String? reason;

  const ModerationResult({
    required this.status,
    this.category,
    this.score,
    this.reason,
  });

  factory ModerationResult.allowed() =>
      const ModerationResult(status: ModerationStatus.allowed);

  factory ModerationResult.blocked({String? category, double? score}) =>
      ModerationResult(status: ModerationStatus.blocked, category: category, score: score);

  factory ModerationResult.review({String? category, double? score}) =>
      ModerationResult(status: ModerationStatus.review, category: category, score: score);

  factory ModerationResult.pendingModeration() =>
      const ModerationResult(status: ModerationStatus.pendingModeration);

  bool get isAllowed => status == ModerationStatus.allowed || status == ModerationStatus.pendingModeration;
  bool get isBlocked => status == ModerationStatus.blocked;
  bool get needsReview => status == ModerationStatus.review;

  /// Human-readable error message for blocked content.
  String get blockedMessage {
    switch (category) {
      case 'nudity':
        return 'This content contains explicit material and cannot be posted.';
      case 'gore':
        return 'This content contains graphic violence and cannot be posted.';
      case 'harassment':
        return 'This content appears to violate our community guidelines.';
      case 'profanity':
        return 'Your message contains language that violates our community guidelines.';
      case 'hate_symbols':
        return 'This content contains prohibited symbols and cannot be posted.';
      case 'weapon':
        return 'This content cannot be posted due to our community guidelines.';
      default:
        return 'This content violates our community guidelines and cannot be posted.';
    }
  }
}

class ReportResult {
  final bool success;
  final String? error;
  final String? reportId;

  const ReportResult({
    required this.success,
    this.error,
    this.reportId,
  });
}
