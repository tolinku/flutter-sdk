import 'http_client.dart';
import 'models.dart';

/// Provides referral management methods via the Tolinku API.
class Referrals {
  /// Creates a [Referrals] instance backed by the given [httpClient].
  const Referrals(this._httpClient);

  final TolinkuHttpClient _httpClient;

  /// Creates a new referral for the given [userId].
  ///
  /// Optionally attach [metadata] and a [userName] for display purposes.
  /// Returns the created [CreateReferralResponse].
  ///
  /// Throws [ArgumentError] if [userId] is empty.
  Future<CreateReferralResponse> create({
    required String userId,
    Map<String, dynamic>? metadata,
    String? userName,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'User ID must not be empty.',
      );
    }
    if (userName != null && userName.trim().isEmpty) {
      throw ArgumentError.value(
        userName,
        'userName',
        'User name must not be empty when provided.',
      );
    }

    final data = await _httpClient.post(
      '/v1/api/referral/create',
      body: {
        'user_id': userId,
        if (metadata != null) 'metadata': metadata,
        if (userName != null) 'user_name': userName,
      },
    );
    return CreateReferralResponse.fromJson(data);
  }

  /// Retrieves referral information for the given [code].
  ///
  /// Throws [ArgumentError] if [code] is empty.
  Future<ReferralDetails> get(String code) async {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(
        code,
        'code',
        'Referral code must not be empty.',
      );
    }

    // URL-encode the referral code to prevent path traversal.
    final encodedCode = Uri.encodeComponent(code);
    final data = await _httpClient.get('/v1/api/referral/$encodedCode');
    return ReferralDetails.fromJson(data);
  }

  /// Completes a referral, recording that [referredUserId] signed up via
  /// [code].
  ///
  /// Optionally specify a [milestone] to set on completion and a
  /// [referredUserName] for display purposes.
  ///
  /// Throws [ArgumentError] if [code] or [referredUserId] is empty.
  Future<CompleteReferralResponse> complete({
    required String code,
    required String referredUserId,
    String? milestone,
    String? referredUserName,
  }) async {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(
        code,
        'code',
        'Referral code must not be empty.',
      );
    }
    if (referredUserId.trim().isEmpty) {
      throw ArgumentError.value(
        referredUserId,
        'referredUserId',
        'Referred user ID must not be empty.',
      );
    }
    if (milestone != null && milestone.trim().isEmpty) {
      throw ArgumentError.value(
        milestone,
        'milestone',
        'Milestone must not be empty when provided.',
      );
    }
    if (referredUserName != null && referredUserName.trim().isEmpty) {
      throw ArgumentError.value(
        referredUserName,
        'referredUserName',
        'Referred user name must not be empty when provided.',
      );
    }

    final data = await _httpClient.post(
      '/v1/api/referral/complete',
      body: {
        'referral_code': code,
        'referred_user_id': referredUserId,
        if (milestone != null) 'milestone': milestone,
        if (referredUserName != null) 'referred_user_name': referredUserName,
      },
    );
    return CompleteReferralResponse.fromJson(data);
  }

  /// Updates the milestone for a referral identified by [code].
  ///
  /// Throws [ArgumentError] if [code] or [milestone] is empty.
  Future<MilestoneResponse> milestone({
    required String code,
    required String milestone,
  }) async {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(
        code,
        'code',
        'Referral code must not be empty.',
      );
    }
    if (milestone.trim().isEmpty) {
      throw ArgumentError.value(
        milestone,
        'milestone',
        'Milestone must not be empty.',
      );
    }

    final data = await _httpClient.post(
      '/v1/api/referral/milestone',
      body: {
        'referral_code': code,
        'milestone': milestone,
      },
    );
    return MilestoneResponse.fromJson(data);
  }

  /// Fetches the referral leaderboard.
  ///
  /// Optionally specify [limit] to control how many entries are returned.
  Future<List<LeaderboardEntry>> leaderboard({int? limit}) async {
    final queryParams = <String, String>{};
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    final data = await _httpClient.get(
      '/v1/api/referral/leaderboard',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    final list = data['leaderboard'] as List<dynamic>? ?? [];
    return list
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Claims a reward for the referral identified by [code].
  ///
  /// Throws [ArgumentError] if [code] is empty.
  Future<ClaimRewardResponse> claimReward({required String code}) async {
    if (code.trim().isEmpty) {
      throw ArgumentError.value(
        code,
        'code',
        'Referral code must not be empty.',
      );
    }

    final data = await _httpClient.post(
      '/v1/api/referral/claim-reward',
      body: {
        'referral_code': code,
      },
    );
    return ClaimRewardResponse.fromJson(data);
  }
}
