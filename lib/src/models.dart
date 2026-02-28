/// Data models for the Tolinku SDK.
///
/// All models support JSON serialization via [fromJson] factory constructors
/// and [toJson] methods.
library;

/// Response from creating a referral.
class CreateReferralResponse {
  /// Creates a [CreateReferralResponse] instance.
  const CreateReferralResponse({
    required this.referralCode,
    this.referralUrl,
    required this.referralId,
  });

  /// Creates a [CreateReferralResponse] from a JSON map.
  factory CreateReferralResponse.fromJson(Map<String, dynamic> json) {
    return CreateReferralResponse(
      referralCode: json['referral_code'] as String,
      referralUrl: json['referral_url'] as String?,
      referralId: json['referral_id'] as String,
    );
  }

  /// The unique referral code.
  final String referralCode;

  /// The full referral URL, if available.
  final String? referralUrl;

  /// The document ID of the created referral.
  final String referralId;

  /// Converts this response to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'referral_code': referralCode,
      if (referralUrl != null) 'referral_url': referralUrl,
      'referral_id': referralId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateReferralResponse &&
        other.referralCode == referralCode &&
        other.referralUrl == referralUrl &&
        other.referralId == referralId;
  }

  @override
  int get hashCode {
    return Object.hash(referralCode, referralUrl, referralId);
  }
}

/// Details of an existing referral, returned by the GET endpoint.
class ReferralDetails {
  /// Creates a [ReferralDetails] instance.
  const ReferralDetails({
    required this.referrerId,
    required this.status,
    this.milestone,
    required this.milestoneHistory,
    this.rewardType,
    this.rewardValue,
    required this.rewardClaimed,
    this.createdAt,
  });

  /// Creates a [ReferralDetails] from a JSON map.
  factory ReferralDetails.fromJson(Map<String, dynamic> json) {
    return ReferralDetails(
      referrerId: json['referrer_id'] as String,
      status: json['status'] as String,
      milestone: json['milestone'] as String?,
      milestoneHistory: (json['milestone_history'] as List<dynamic>?) ?? [],
      rewardType: json['reward_type'] as String?,
      rewardValue: json['reward_value']?.toString(),
      rewardClaimed: json['reward_claimed'] as bool,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  /// The user ID of the referrer.
  final String referrerId;

  /// Current status of the referral (e.g. "pending", "completed").
  final String status;

  /// Current milestone.
  final String? milestone;

  /// History of milestones reached.
  final List<dynamic> milestoneHistory;

  /// The type of reward (e.g. "credit").
  final String? rewardType;

  /// The reward value (string, e.g. "10" or "5.00").
  final String? rewardValue;

  /// Whether the reward has been claimed.
  final bool rewardClaimed;

  /// Creation timestamp (parsed from ISO 8601 string if provided by the API).
  final DateTime? createdAt;

  /// Converts this to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'referrer_id': referrerId,
      'status': status,
      if (milestone != null) 'milestone': milestone,
      'milestone_history': milestoneHistory,
      if (rewardType != null) 'reward_type': rewardType,
      if (rewardValue != null) 'reward_value': rewardValue,
      'reward_claimed': rewardClaimed,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReferralDetails &&
        other.referrerId == referrerId &&
        other.status == status &&
        other.milestone == milestone &&
        other.rewardType == rewardType &&
        other.rewardValue == rewardValue &&
        other.rewardClaimed == rewardClaimed &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      referrerId,
      status,
      milestone,
      rewardType,
      rewardValue,
      rewardClaimed,
      createdAt,
    );
  }
}

/// The nested referral object returned from the complete endpoint.
class CompletedReferral {
  /// Creates a [CompletedReferral] instance.
  const CompletedReferral({
    required this.id,
    required this.referrerId,
    required this.referredUserId,
    required this.status,
    this.milestone,
    this.completedAt,
    this.rewardType,
    this.rewardValue,
  });

  /// Creates a [CompletedReferral] from a JSON map.
  factory CompletedReferral.fromJson(Map<String, dynamic> json) {
    return CompletedReferral(
      id: json['id'] as String,
      referrerId: json['referrer_id'] as String,
      referredUserId: json['referred_user_id'] as String,
      status: json['status'] as String,
      milestone: json['milestone'] as String?,
      completedAt: json['completed_at'] as String?,
      rewardType: json['reward_type'] as String?,
      rewardValue: json['reward_value']?.toString(),
    );
  }

  /// The referral document ID.
  final String id;

  /// The referrer's user ID.
  final String referrerId;

  /// The referred user's ID.
  final String referredUserId;

  /// Current status.
  final String status;

  /// Current milestone.
  final String? milestone;

  /// When the referral was completed (ISO 8601 string).
  final String? completedAt;

  /// The type of reward.
  final String? rewardType;

  /// The reward value (string, e.g. "10" or "5.00").
  final String? rewardValue;

  /// Converts this to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referrer_id': referrerId,
      'referred_user_id': referredUserId,
      'status': status,
      if (milestone != null) 'milestone': milestone,
      if (completedAt != null) 'completed_at': completedAt,
      if (rewardType != null) 'reward_type': rewardType,
      if (rewardValue != null) 'reward_value': rewardValue,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletedReferral &&
        other.id == id &&
        other.referrerId == referrerId &&
        other.referredUserId == referredUserId &&
        other.status == status &&
        other.milestone == milestone &&
        other.completedAt == completedAt &&
        other.rewardType == rewardType &&
        other.rewardValue == rewardValue;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      referrerId,
      referredUserId,
      status,
      milestone,
      completedAt,
      rewardType,
      rewardValue,
    );
  }
}

/// Response from completing a referral; wraps the nested referral object.
class CompleteReferralResponse {
  /// Creates a [CompleteReferralResponse] instance.
  const CompleteReferralResponse({required this.referral});

  /// Creates a [CompleteReferralResponse] from a JSON map.
  factory CompleteReferralResponse.fromJson(Map<String, dynamic> json) {
    return CompleteReferralResponse(
      referral: CompletedReferral.fromJson(
        json['referral'] as Map<String, dynamic>,
      ),
    );
  }

  /// The completed referral details.
  final CompletedReferral referral;

  /// Converts this to a JSON map.
  Map<String, dynamic> toJson() {
    return {'referral': referral.toJson()};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompleteReferralResponse && other.referral == referral;
  }

  @override
  int get hashCode => referral.hashCode;
}

/// The nested referral object returned from the milestone endpoint.
class MilestoneReferral {
  /// Creates a [MilestoneReferral] instance.
  const MilestoneReferral({
    required this.id,
    required this.referralCode,
    required this.milestone,
    required this.status,
    this.rewardType,
    this.rewardValue,
  });

  /// Creates a [MilestoneReferral] from a JSON map.
  factory MilestoneReferral.fromJson(Map<String, dynamic> json) {
    return MilestoneReferral(
      id: json['id'] as String,
      referralCode: json['referral_code'] as String,
      milestone: json['milestone'] as String,
      status: json['status'] as String,
      rewardType: json['reward_type'] as String?,
      rewardValue: json['reward_value']?.toString(),
    );
  }

  /// The referral document ID.
  final String id;

  /// The referral code.
  final String referralCode;

  /// The current milestone.
  final String milestone;

  /// Current status.
  final String status;

  /// The type of reward.
  final String? rewardType;

  /// The reward value (string, e.g. "10" or "5.00").
  final String? rewardValue;

  /// Converts this to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referral_code': referralCode,
      'milestone': milestone,
      'status': status,
      if (rewardType != null) 'reward_type': rewardType,
      if (rewardValue != null) 'reward_value': rewardValue,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MilestoneReferral &&
        other.id == id &&
        other.referralCode == referralCode &&
        other.milestone == milestone &&
        other.status == status &&
        other.rewardType == rewardType &&
        other.rewardValue == rewardValue;
  }

  @override
  int get hashCode {
    return Object.hash(id, referralCode, milestone, status, rewardType, rewardValue);
  }
}

/// Response from updating a milestone; wraps the nested referral object.
class MilestoneResponse {
  /// Creates a [MilestoneResponse] instance.
  const MilestoneResponse({required this.referral});

  /// Creates a [MilestoneResponse] from a JSON map.
  factory MilestoneResponse.fromJson(Map<String, dynamic> json) {
    return MilestoneResponse(
      referral: MilestoneReferral.fromJson(
        json['referral'] as Map<String, dynamic>,
      ),
    );
  }

  /// The milestone referral details.
  final MilestoneReferral referral;

  /// Converts this to a JSON map.
  Map<String, dynamic> toJson() {
    return {'referral': referral.toJson()};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MilestoneResponse && other.referral == referral;
  }

  @override
  int get hashCode => referral.hashCode;
}

/// Response from claiming a reward.
class ClaimRewardResponse {
  /// Creates a [ClaimRewardResponse] instance.
  const ClaimRewardResponse({
    required this.success,
    required this.referralCode,
    required this.rewardClaimed,
  });

  /// Creates a [ClaimRewardResponse] from a JSON map.
  factory ClaimRewardResponse.fromJson(Map<String, dynamic> json) {
    return ClaimRewardResponse(
      success: json['success'] as bool,
      referralCode: json['referral_code'] as String,
      rewardClaimed: json['reward_claimed'] as bool,
    );
  }

  /// Whether the claim was successful.
  final bool success;

  /// The referral code.
  final String referralCode;

  /// Whether the reward has been claimed.
  final bool rewardClaimed;

  /// Converts this to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'referral_code': referralCode,
      'reward_claimed': rewardClaimed,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClaimRewardResponse &&
        other.success == success &&
        other.referralCode == referralCode &&
        other.rewardClaimed == rewardClaimed;
  }

  @override
  int get hashCode {
    return Object.hash(success, referralCode, rewardClaimed);
  }
}

/// A single entry on the referral leaderboard.
class LeaderboardEntry {
  /// Creates a [LeaderboardEntry] instance.
  const LeaderboardEntry({
    required this.referrerId,
    this.referrerName,
    required this.total,
    required this.completed,
    required this.pending,
    this.totalRewardValue,
  });

  /// Creates a [LeaderboardEntry] from a JSON map.
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      referrerId: json['referrer_id'] as String,
      referrerName: json['referrer_name'] as String?,
      total: json['total'] as int,
      completed: json['completed'] as int,
      pending: json['pending'] as int,
      totalRewardValue: json['total_reward_value']?.toString(),
    );
  }

  /// The user ID of the referrer.
  final String referrerId;

  /// Optional display name.
  final String? referrerName;

  /// Total number of referrals.
  final int total;

  /// Number of completed referrals.
  final int completed;

  /// Number of pending referrals.
  final int pending;

  /// Total reward value as a string, if applicable.
  final String? totalRewardValue;

  /// Converts this entry to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'referrer_id': referrerId,
      if (referrerName != null) 'referrer_name': referrerName,
      'total': total,
      'completed': completed,
      'pending': pending,
      if (totalRewardValue != null) 'total_reward_value': totalRewardValue,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardEntry &&
        other.referrerId == referrerId &&
        other.referrerName == referrerName &&
        other.total == total &&
        other.completed == completed &&
        other.pending == pending &&
        other.totalRewardValue == totalRewardValue;
  }

  @override
  int get hashCode {
    return Object.hash(
      referrerId,
      referrerName,
      total,
      completed,
      pending,
      totalRewardValue,
    );
  }
}

/// Represents a deferred deep link returned when claiming.
class DeferredLink {
  /// Creates a [DeferredLink] instance.
  const DeferredLink({
    required this.deepLinkPath,
    required this.appspaceId,
    this.referrerId,
    this.referralCode,
  });

  /// Creates a [DeferredLink] from a JSON map.
  factory DeferredLink.fromJson(Map<String, dynamic> json) {
    return DeferredLink(
      deepLinkPath: json['deep_link_path'] as String,
      appspaceId: json['appspace_id'] as String,
      referrerId: json['referrer_id'] as String?,
      referralCode: json['referral_code'] as String?,
    );
  }

  /// The deep link path the user should be navigated to.
  final String deepLinkPath;

  /// The appspace ID this link belongs to.
  final String appspaceId;

  /// The referrer's user ID, if this is a referral link.
  final String? referrerId;

  /// A referral code associated with this deferred link, if any.
  final String? referralCode;

  /// Converts this deferred link to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'deep_link_path': deepLinkPath,
      'appspace_id': appspaceId,
      if (referrerId != null) 'referrer_id': referrerId,
      if (referralCode != null) 'referral_code': referralCode,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeferredLink &&
        other.deepLinkPath == deepLinkPath &&
        other.appspaceId == appspaceId &&
        other.referrerId == referrerId &&
        other.referralCode == referralCode;
  }

  @override
  int get hashCode {
    return Object.hash(
      deepLinkPath,
      appspaceId,
      referrerId,
      referralCode,
    );
  }
}

/// Represents an in-app message fetched from the API.
class TolinkuMessage {
  /// Creates a [TolinkuMessage] instance.
  const TolinkuMessage({
    required this.id,
    required this.name,
    this.title,
    this.body,
    required this.trigger,
    this.triggerValue,
    this.backgroundColor,
    required this.priority,
    this.dismissDays,
    this.maxImpressions,
    this.minIntervalHours,
  });

  /// Creates a [TolinkuMessage] from a JSON map.
  factory TolinkuMessage.fromJson(Map<String, dynamic> json) {
    return TolinkuMessage(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      trigger: json['trigger'] as String,
      triggerValue: json['trigger_value'] as String?,
      backgroundColor: json['background_color'] as String?,
      priority: json['priority'] as int,
      dismissDays: json['dismiss_days'] as int?,
      maxImpressions: json['max_impressions'] as int?,
      minIntervalHours: json['min_interval_hours'] as int?,
    );
  }

  /// Unique message identifier.
  final String id;

  /// Internal name for the message.
  final String name;

  /// Message title.
  final String? title;

  /// Message body content.
  final String? body;

  /// The trigger that activates this message.
  final String trigger;

  /// Optional value associated with the trigger (e.g. event name, screen name).
  final String? triggerValue;

  /// Background color for the message (hex string).
  final String? backgroundColor;

  /// Display priority. Higher values are shown first.
  final int priority;

  /// Number of days to suppress the message after dismissal.
  final int? dismissDays;

  /// Maximum number of times to show the message per user.
  final int? maxImpressions;

  /// Minimum hours between displays of the message.
  final int? minIntervalHours;

  /// Converts this message to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      'trigger': trigger,
      if (triggerValue != null) 'trigger_value': triggerValue,
      if (backgroundColor != null) 'background_color': backgroundColor,
      'priority': priority,
      if (dismissDays != null) 'dismiss_days': dismissDays,
      if (maxImpressions != null) 'max_impressions': maxImpressions,
      if (minIntervalHours != null) 'min_interval_hours': minIntervalHours,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TolinkuMessage &&
        other.id == id &&
        other.name == name &&
        other.title == title &&
        other.body == body &&
        other.trigger == trigger &&
        other.triggerValue == triggerValue &&
        other.backgroundColor == backgroundColor &&
        other.priority == priority &&
        other.dismissDays == dismissDays &&
        other.maxImpressions == maxImpressions &&
        other.minIntervalHours == minIntervalHours;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      title,
      body,
      trigger,
      triggerValue,
      backgroundColor,
      priority,
      dismissDays,
      maxImpressions,
      minIntervalHours,
    );
  }
}

/// Parses a value that may be a String (ISO 8601) or null into a [DateTime].
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

