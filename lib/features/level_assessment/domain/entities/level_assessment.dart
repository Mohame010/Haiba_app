enum AssessmentSkill { pronunciation, reading, writing }

extension AssessmentSkillX on AssessmentSkill {
  String get databaseValue => name;

  String get arabicName => switch (this) {
    AssessmentSkill.pronunciation => 'النطق',
    AssessmentSkill.reading => 'القراءة',
    AssessmentSkill.writing => 'الكتابة',
  };
}

enum StudentLevel { beginner, intermediate, distinguished, legendary }

extension StudentLevelX on StudentLevel {
  String get databaseValue => name;

  String get arabicName => switch (this) {
    StudentLevel.beginner => 'مبتدئ',
    StudentLevel.intermediate => 'متوسط',
    StudentLevel.distinguished => 'متميز',
    StudentLevel.legendary => 'أسطوري',
  };

  static StudentLevel fromScore(num score) {
    if (score >= 85) return StudentLevel.legendary;
    if (score >= 65) return StudentLevel.distinguished;
    if (score >= 40) return StudentLevel.intermediate;
    return StudentLevel.beginner;
  }

  static StudentLevel fromDatabase(String? value) => switch (value) {
    'legendary' => StudentLevel.legendary,
    'distinguished' => StudentLevel.distinguished,
    'intermediate' => StudentLevel.intermediate,
    _ => StudentLevel.beginner,
  };
}

class LevelAssessmentQuestion {
  final String id;
  final AssessmentSkill skill;
  final String prompt;
  final String? contextText;
  final List<String> options;
  final int correctOption;
  final String explanation;

  const LevelAssessmentQuestion({
    required this.id,
    required this.skill,
    required this.prompt,
    this.contextText,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });
}

class LevelAssessmentResult {
  final String? id;
  final int pronunciationScore;
  final int readingScore;
  final int writingScore;
  final int overallScore;
  final StudentLevel pronunciationLevel;
  final StudentLevel readingLevel;
  final StudentLevel writingLevel;
  final StudentLevel overallLevel;
  final DateTime? completedAt;

  const LevelAssessmentResult({
    this.id,
    required this.pronunciationScore,
    required this.readingScore,
    required this.writingScore,
    required this.overallScore,
    required this.pronunciationLevel,
    required this.readingLevel,
    required this.writingLevel,
    required this.overallLevel,
    this.completedAt,
  });

  factory LevelAssessmentResult.fromScores({
    required int pronunciationScore,
    required int readingScore,
    required int writingScore,
  }) {
    final overall = ((pronunciationScore + readingScore + writingScore) / 3)
        .round();
    return LevelAssessmentResult(
      pronunciationScore: pronunciationScore,
      readingScore: readingScore,
      writingScore: writingScore,
      overallScore: overall,
      pronunciationLevel: StudentLevelX.fromScore(pronunciationScore),
      readingLevel: StudentLevelX.fromScore(readingScore),
      writingLevel: StudentLevelX.fromScore(writingScore),
      overallLevel: StudentLevelX.fromScore(overall),
    );
  }

  factory LevelAssessmentResult.fromMap(Map<String, dynamic> map) {
    return LevelAssessmentResult(
      id: map['id'] as String?,
      pronunciationScore: (map['pronunciation_score'] as num?)?.round() ?? 0,
      readingScore: (map['reading_score'] as num?)?.round() ?? 0,
      writingScore: (map['writing_score'] as num?)?.round() ?? 0,
      overallScore: (map['overall_score'] as num?)?.round() ?? 0,
      pronunciationLevel: StudentLevelX.fromDatabase(
        map['pronunciation_level'] as String?,
      ),
      readingLevel: StudentLevelX.fromDatabase(map['reading_level'] as String?),
      writingLevel: StudentLevelX.fromDatabase(map['writing_level'] as String?),
      overallLevel: StudentLevelX.fromDatabase(map['overall_level'] as String?),
      completedAt: DateTime.tryParse(map['completed_at'] as String? ?? ''),
    );
  }

  int scoreFor(AssessmentSkill skill) => switch (skill) {
    AssessmentSkill.pronunciation => pronunciationScore,
    AssessmentSkill.reading => readingScore,
    AssessmentSkill.writing => writingScore,
  };

  StudentLevel levelFor(AssessmentSkill skill) => switch (skill) {
    AssessmentSkill.pronunciation => pronunciationLevel,
    AssessmentSkill.reading => readingLevel,
    AssessmentSkill.writing => writingLevel,
  };
}
