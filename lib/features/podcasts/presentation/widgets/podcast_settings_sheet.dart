import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_colors.dart';

class PodcastReadingTheme {
  const PodcastReadingTheme({
    required this.name,
    required this.pageColor,
    required this.textColor,
    required this.highlightColor,
  });

  final String name;
  final Color pageColor;
  final Color textColor;
  final Color highlightColor;

  static const List<PodcastReadingTheme> presets = [
    PodcastReadingTheme(
      name: 'كلاسيكي',
      pageColor: Color(0xFFF8FAFC),
      textColor: Color(0xFF1E1B4B),
      highlightColor: Color(0xFFFFE28A),
    ),
    PodcastReadingTheme(
      name: 'سيبيا ورقي',
      pageColor: Color(0xFFF4ECD8),
      textColor: Color(0xFF2E241A),
      highlightColor: Color(0xFFFCD34D),
    ),
    PodcastReadingTheme(
      name: 'ليلي فاخر',
      pageColor: Color(0xFF0F172A),
      textColor: Color(0xFFE2E8F0),
      highlightColor: Color(0xFF4338CA),
    ),
    PodcastReadingTheme(
      name: 'نعناعي مريح',
      pageColor: Color(0xFFEDF7EE),
      textColor: Color(0xFF143020),
      highlightColor: Color(0xFFA7F3D0),
    ),
    PodcastReadingTheme(
      name: 'قهوة عتيقة',
      pageColor: Color(0xFFEFE6DD),
      textColor: Color(0xFF2B2018),
      highlightColor: Color(0xFFF59E0B),
    ),
  ];
}

class PodcastSettingsSheet extends StatefulWidget {
  const PodcastSettingsSheet({
    super.key,
    required this.currentTheme,
    required this.englishFontSize,
    required this.arabicFontSize,
    required this.showTranslation,
    required this.showVideo,
    required this.onThemeChanged,
    required this.onEnglishFontSizeChanged,
    required this.onArabicFontSizeChanged,
    required this.onShowTranslationChanged,
    required this.onShowVideoChanged,
  });

  final PodcastReadingTheme currentTheme;
  final double englishFontSize;
  final double arabicFontSize;
  final bool showTranslation;
  final bool showVideo;
  final ValueChanged<PodcastReadingTheme> onThemeChanged;
  final ValueChanged<double> onEnglishFontSizeChanged;
  final ValueChanged<double> onArabicFontSizeChanged;
  final ValueChanged<bool> onShowTranslationChanged;
  final ValueChanged<bool> onShowVideoChanged;

  static Future<void> show(
    BuildContext context, {
    required PodcastReadingTheme currentTheme,
    required double englishFontSize,
    required double arabicFontSize,
    required bool showTranslation,
    required bool showVideo,
    required ValueChanged<PodcastReadingTheme> onThemeChanged,
    required ValueChanged<double> onEnglishFontSizeChanged,
    required ValueChanged<double> onArabicFontSizeChanged,
    required ValueChanged<bool> onShowTranslationChanged,
    required ValueChanged<bool> onShowVideoChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PodcastSettingsSheet(
        currentTheme: currentTheme,
        englishFontSize: englishFontSize,
        arabicFontSize: arabicFontSize,
        showTranslation: showTranslation,
        showVideo: showVideo,
        onThemeChanged: onThemeChanged,
        onEnglishFontSizeChanged: onEnglishFontSizeChanged,
        onArabicFontSizeChanged: onArabicFontSizeChanged,
        onShowTranslationChanged: onShowTranslationChanged,
        onShowVideoChanged: onShowVideoChanged,
      ),
    );
  }

  @override
  State<PodcastSettingsSheet> createState() => _PodcastSettingsSheetState();
}

class _PodcastSettingsSheetState extends State<PodcastSettingsSheet> {
  late PodcastReadingTheme _theme;
  late double _englishSize;
  late double _arabicSize;
  late bool _showTranslation;
  late bool _showVideo;

  @override
  void initState() {
    super.initState();
    _theme = widget.currentTheme;
    _englishSize = widget.englishFontSize;
    _arabicSize = widget.arabicFontSize;
    _showTranslation = widget.showTranslation;
    _showVideo = widget.showVideo;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'إعدادات وثيمات البودكاست',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preset Themes (Same as novels)
          const Text(
            'أنماط العرض المعتمدة (نفس ثيمات الروايات)',
            style: TextStyle(
              fontFamily: 'IBM',
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: PodcastReadingTheme.presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final preset = PodcastReadingTheme.presets[index];
                final isSelected =
                    preset.pageColor.toARGB32() == _theme.pageColor.toARGB32() &&
                    preset.textColor.toARGB32() == _theme.textColor.toARGB32();

                return GestureDetector(
                  onTap: () {
                    setState(() => _theme = preset);
                    widget.onThemeChanged(preset);
                  },
                  child: Container(
                    width: 90,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: preset.pageColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.black12,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        else
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Aa',
                          style: TextStyle(
                            color: preset.textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.name,
                          style: TextStyle(
                            color: preset.textColor.withValues(alpha: 0.9),
                            fontFamily: 'IBM',
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          // Show Translation Switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'عرض الترجمة العربية الفورية',
              style: TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'إظهار الترجمة المزامنة أسفل كل جملة',
              style: TextStyle(fontFamily: 'IBM', fontSize: 12),
            ),
            value: _showTranslation,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _showTranslation = val);
              widget.onShowTranslationChanged(val);
            },
          ),
          const Divider(height: 18),

          // Show Background Video Switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'عرض فيديو الخلفية',
              style: TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'تشغيل المقاطع البصرية التزامنية في خلفية النص',
              style: TextStyle(fontFamily: 'IBM', fontSize: 12),
            ),
            value: _showVideo,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _showVideo = val);
              widget.onShowVideoChanged(val);
            },
          ),
          const Divider(height: 26),

          // English Font Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'حجم الخط الإنجليزي',
                style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w700),
              ),
              Text(
                '${_englishSize.round()} pt',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            min: 12,
            max: 30,
            divisions: 9,
            value: _englishSize.clamp(12, 30),
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _englishSize = val);
              widget.onEnglishFontSizeChanged(val);
            },
          ),
          const SizedBox(height: 10),

          // Arabic Font Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'حجم الخط العربي',
                style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w700),
              ),
              Text(
                '${_arabicSize.round()} pt',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            min: 11,
            max: 26,
            divisions: 8,
            value: _arabicSize.clamp(11, 26),
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _arabicSize = val);
              widget.onArabicFontSizeChanged(val);
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
