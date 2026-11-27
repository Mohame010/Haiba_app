class AppConstants {
  /// The active teacher UUID for which this application instance is scoped and branded.
  /// Any student registering will be linked to this teacher, and all content
  /// (lectures, exams, leaderboard, teacher info) will be filtered for this teacher.
  static const String activeTeacherId = '11111111-1111-1111-1111-111111111111';

  // Supported Stages
  static const String stagePreparatory = 'إعدادي';
  static const String stageSecondary = 'ثانوي';
  static const String stageBaccalaureate = 'بكالوريا';
  static const String stageUniversity = 'طالب جامعي';

  static const List<String> allStages = [
    stagePreparatory,
    stageSecondary,
    stageBaccalaureate,
    stageUniversity,
  ];

  // Grade lists per stage
  static const List<String> preparatoryGrades = [
    'الصف الأول الإعدادي',
    'الصف الثاني الإعدادي',
    'الصف الثالث الإعدادي',
  ];

  static const List<String> secondaryGrades = [
    'الصف الأول الثانوي',
    'الصف الثاني الثانوي',
    'الصف الثالث الثانوي',
  ];

  static const List<String> baccalaureateGrades = [
    'بكالوريا - سنة أولى',
    'بكالوريا - سنة ثانية',
  ];

  static const List<String> universityGrades = [
    'الفرقة الأولى',
    'الفرقة الثانية',
    'الفرقة الثالثة',
    'الفرقة الرابعة',
  ];

  static const List<String> allGrades = [
    ...secondaryGrades,
    ...preparatoryGrades,
    ...baccalaureateGrades,
    ...universityGrades,
  ];

  static List<String> getGradesForStage(String stage) {
    switch (stage) {
      case stageBaccalaureate:
        return baccalaureateGrades;
      case stageUniversity:
        return universityGrades;
      case stagePreparatory:
        return preparatoryGrades;
      case stageSecondary:
      default:
        return secondaryGrades;
    }
  }
}
