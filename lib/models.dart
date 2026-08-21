import 'services/rank_service.dart';

/// Status of a single quest on a given day.
enum QuestStatus { pending, verified, missed }

/// A trackable habit / quest.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.time,
    required this.category,
    required this.emoji,
  });

  final String id;
  final String name;

  /// AppIcons stroke name.
  final String icon;
  final String time;
  final String category;
  final String emoji;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'time': time,
    'category': category,
    'emoji': emoji,
  };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    time: json['time'] as String,
    category: json['category'] as String,
    emoji: json['emoji'] as String,
  );
}

/// A chat bubble in the Qubi assistant.
class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  Map<String, dynamic> toJson() => {'fromUser': fromUser, 'text': text};

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    fromUser: json['fromUser'] as bool,
    text: json['text'] as String,
  );
}

/// A row in the weekly league leaderboard.
class LeagueEntry {
  const LeagueEntry({
    required this.rank,
    required this.name,
    required this.initials,
    required this.xp,
    required this.streak,
    required this.tier,
    required this.isMe,
    required this.level,
  });

  final int rank;
  final String name;
  final String initials;
  final int xp;
  final int streak;
  final String tier;
  final bool isMe;
  final int level;

  /// Convenience getter to parse the string [tier] into a [RankTier] enum.
  RankTier get tierEnum {
    return RankTier.values.firstWhere(
      (t) => t.name == tier.toLowerCase(),
      orElse: () => RankTier.bronze,
    );
  }
}
