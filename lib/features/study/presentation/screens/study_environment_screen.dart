import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../lectures/presentation/widgets/pdf_viewer/pdf_document_store.dart';
import '../../../lectures/presentation/widgets/pdf_viewer/pdf_editor_screen.dart';
import '../../../lectures/presentation/widgets/pdf_viewer/pdf_word_translation_dialog.dart';
import '../../../novels/presentation/widgets/novel_saved_words_screen.dart';

class StudyEnvironmentScreen extends StatefulWidget {
  const StudyEnvironmentScreen({super.key});

  @override
  State<StudyEnvironmentScreen> createState() => _StudyEnvironmentScreenState();
}

class _StudyEnvironmentScreenState extends State<StudyEnvironmentScreen> {
  final _store = const PdfDocumentStore();
  late Future<List<RecentPdfDocument>> _recentFiles;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _recentFiles = _store.loadRecentDocuments();
  }

  Future<void> _refreshFiles() async {
    setState(() {
      _isRefreshing = true;
      _recentFiles = _store.loadRecentDocuments();
    });
    try {
      await _recentFiles;
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (!mounted || path == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PdfEditorScreen(
          pdfUrl: Uri.file(path).toString(),
          title: result!.files.single.name,
          enableAmbientSounds: true,
          preventScreenshots: false,
        ),
      ),
    );
    if (mounted) {
      await _refreshFiles();
    }
  }

  Future<void> _openRecent(RecentPdfDocument document) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PdfEditorScreen(
          pdfUrl: document.url,
          title: document.title,
          enableAmbientSounds: true,
          preventScreenshots: false,
        ),
      ),
    );
    if (mounted) {
      await _refreshFiles();
    }
  }

  Future<void> _deleteRecent(RecentPdfDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إزالة من السجل'),
        content: Text(
          'هل تريد إزالة "${document.title}" من سجل آخر الملفات؟\n(لن يُحذف الملف الأصلي من جهازك)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _store.removeRecent(document.url);
      if (mounted) {
        await _refreshFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إزالة الملف من السجل')),
          );
        }
      }
    }
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inSeconds < 45) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24 && now.day == time.day) {
      final hour = time.hour > 12
          ? time.hour - 12
          : (time.hour == 0 ? 12 : time.hour);
      final period = time.hour >= 12 ? 'م' : 'ص';
      final minute = time.minute.toString().padLeft(2, '0');
      return 'اليوم $hour:$minute $period';
    }
    if (difference.inDays < 2) return 'أمس';
    return '${time.year}/${time.month}/${time.day}';
  }

  Future<void> _showQuickWordLookup(BuildContext context) async {
    final controller = TextEditingController();
    final word = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'نطق وترجمة كلمة',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اكتب أي كلمة للاستماع إلى نطقها الصوتي الدقيق ومعرفة معناها وحفظها:',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'e.g. challenge, vocabulary...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    Navigator.pop(dialogCtx, val.trim());
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'IBM')),
            ),
            FilledButton.icon(
              onPressed: () {
                final val = controller.text.trim();
                if (val.isNotEmpty) {
                  Navigator.pop(dialogCtx, val);
                }
              },
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              label: const Text(
                'نطق وترجمة',
                style: TextStyle(fontFamily: 'IBM'),
              ),
            ),
          ],
        ),
      ),
    );

    if (word != null && word.trim().isNotEmpty && context.mounted) {
      PdfWordTranslationDialog.show(
        context,
        word: word.trim(),
        pdfTitle: 'بيئة المذاكرة',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        'بيئة المذاكرة',
        style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      actions: [
        // IconButton(
        //   tooltip: 'نطق وترجمة كلمة',
        //   onPressed: () => _showQuickWordLookup(context),
        //   icon: const Icon(
        //     Icons.record_voice_over_rounded,
        //     color: AppColors.primary,
        //   ),
        // ),
        IconButton(
          tooltip: 'حصيلة الكلمات المحفوظة',
          onPressed: () => NovelSavedWordsScreen.open(context),
          icon: const Icon(
            Icons.collections_bookmark_rounded,
            color: AppColors.primary,
          ),
        ),
        IconButton(
          tooltip: 'تحديث السجل',
          onPressed: _isRefreshing ? null : _refreshFiles,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refreshFiles,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeroCard(context),
          const SizedBox(height: 18),
          _buildQuickLookupCard(context),
          const SizedBox(height: 24),
          _buildRecentsSection(context),
          const SizedBox(height: 28),
          _buildFeaturesSection(context),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );

  Widget _buildHeroCard(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF6D28D9), Color(0xFF4F46E5)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6D28D9).withValues(alpha: .28),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ذاكر بتركيز وذكاء',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'IBM',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'افتح أي ملف PDF، ظلل النقاط المهمة، أضف شروحات وملاحظات بحجم الخط الذي يناسبك، وشغّل أصوات الخلفية للتركيز العميق.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .9),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _pickPdf,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4F46E5),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text(
            'رفع ملف PDF من جهازك',
            style: TextStyle(
              fontFamily: 'IBM',
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildQuickLookupCard(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                color: Color(0xFF059669),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ترجمة ونطق الكلمات',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'استمع للنطق الصوتي لأي كلمة وتعرّف على ترجمتها فوراً',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => _showQuickWordLookup(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'اكتب أي كلمة للاستماع لنطقها وترجمتها...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.volume_up_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'نطق وترجمة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'IBM',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildRecentsSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'آخر الملفات المفتوحة',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _refreshFiles,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('تحديث'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      FutureBuilder<List<RecentPdfDocument>>(
        future: _recentFiles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          final files = snapshot.data ?? const <RecentPdfDocument>[];
          if (files.isEmpty) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا توجد ملفات حديثة بعد',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'أي ملف PDF تفتحه وتعدل عليه سيظهر هنا دائماً للرجوع إليه بسهولة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length > 8 ? 8 : files.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildRecentFileCard(context, file);
            },
          );
        },
      ),
    ],
  );

  Widget _buildRecentFileCard(BuildContext context, RecentPdfDocument file) =>
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: () => _openRecent(file),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFE53935),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 11,
                                  color: Color(0xFF15803D),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'محفوظ بالتعديلات',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(file.openedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) {
                    if (value == 'open') {
                      _openRecent(file);
                    } else if (value == 'delete') {
                      _deleteRecent(file);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text('فتح الملف'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'إزالة من السجل',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildFeaturesSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'أدوات ومميزات المذاكرة',
        style: TextStyle(
          fontFamily: 'IBM',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      // _buildFeatureItem(
      //   icon: Icons.translate_rounded,
      //   color: const Color(0xFF10B981),
      //   title: 'ترجمة ونطق الكلمات',
      //   description:
      //       'حدد أي كلمة داخل الـ PDF أو ابحث عنها لنطقها الصوتي الدقيق وترجمتها وحفظها.',
      //   onTap: () => _showQuickWordLookup(context),
      // ),
      const SizedBox(height: 10),
      _buildFeatureItem(
        icon: Icons.border_color_rounded,
        color: const Color(0xFFF59E0B),
        title: 'تظليل وتصفح ذكي',
        description:
            'ظلل النصوص بألوان مختلفة، واستخدم زر التصفح للتحرك في الـ PDF بسهولة.',
      ),
      const SizedBox(height: 10),
      _buildFeatureItem(
        icon: Icons.text_fields_rounded,
        color: const Color(0xFF7C3AED),
        title: 'نصوص وملاحظات مخصصة',
        description:
            'اكتب ملحوظاتك على الصفحات وتحكم في حجم الخط ليصغر لأقصى درجة تناسب الصفحة.',
      ),
      const SizedBox(height: 10),
      _buildFeatureItem(
        icon: Icons.music_note_rounded,
        color: const Color(0xFF3B82F6),
        title: 'أصوات خلفية للمذاكرة',
        description:
            'ميكسر أصوات هادئة (مطر، مقهى، بحر، وطبيعة) تعمل في الخلفية لزيادة تركيزك.',
      ),
    ],
  );

  Widget _buildFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    VoidCallback? onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
