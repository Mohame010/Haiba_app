enum AbuAlAreefLevel { beginner, intermediate, distinguished, legendary }

extension AbuAlAreefLevelX on AbuAlAreefLevel {
  String get arabicLabel {
    switch (this) {
      case AbuAlAreefLevel.beginner:
        return 'مبتدئ';
      case AbuAlAreefLevel.intermediate:
        return 'متوسط';
      case AbuAlAreefLevel.distinguished:
        return 'متميز';
      case AbuAlAreefLevel.legendary:
        return 'أسطوري';
    }
  }
}

class AbuAlAreefQuestion {
  final String id;
  final AbuAlAreefLevel level;
  final String category;
  final String prompt;
  final List<String> options;
  final int correctOption;

  const AbuAlAreefQuestion({
    required this.id,
    required this.level,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctOption,
  });
}

class AbuAlAreefConfig {
  final bool multiplayer;
  final String firstPlayer;
  final String secondPlayer;
  final int rounds;

  const AbuAlAreefConfig({
    required this.multiplayer,
    required this.firstPlayer,
    this.secondPlayer = '',
    this.rounds = 10,
  });
}
