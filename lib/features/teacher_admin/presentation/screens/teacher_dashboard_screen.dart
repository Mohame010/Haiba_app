import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../data/teacher_admin_service.dart';
import '../widgets/pronunciation_submission_review.dart';
import 'teacher_exam_form_page.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _service = TeacherAdminService();
  late final TabController _tabs;
  TeacherAdminSession? _session;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _pronunciationSubmissions = [];
  bool _pronunciationLoading = true;
  String? _pronunciationError;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final session = await _service.currentSession();
      if (session == null) {
        if (mounted) context.go(AppRoutes.teacherLogin);
        return;
      }
      final results = await Future.wait([
        _service.courses(session.teacherId),
        _service.lectures(session.teacherId),
        _service.offers(session.teacherId),
      ]);
      if (!mounted) return;
      setState(() {
        _session = session;
        _courses = results[0];
        _lectures = results[1];
        _offers = results[2];
      });
      unawaited(_loadPronunciationSubmissions());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPronunciationSubmissions() async {
    if (mounted) {
      setState(() {
        _pronunciationLoading = true;
        _pronunciationError = null;
      });
    }
    try {
      final submissions = await _service.pronunciationSubmissions();
      if (!mounted) return;
      setState(() {
        _pronunciationSubmissions = submissions;
        _pronunciationLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pronunciationError = error.toString();
        _pronunciationLoading = false;
      });
    }
  }

  Future<void> _addCurrent() async {
    final session = _session;
    if (session == null) return;
    if (_tabs.index == 3 || _tabs.index == 4) return;
    if (_tabs.index == 0) {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CourseFormPage(service: _service, session: session),
        ),
      );
      if (created == true) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة الكورس بنجاح')),
          );
        }
      }
      return;
    }
    if (_tabs.index == 1) {
      final lectureId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => LectureFormPage(
            service: _service,
            session: session,
            courses: _courses,
          ),
        ),
      );
      if (lectureId != null) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ الحصة، وسيستمر رفع الفيديو في الخلفية'),
            ),
          );
          final addExam = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('إضافة امتحان'),
              content: const Text('هل تريد إضافة امتحان على الحصة الآن؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('لاحقًا'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('إضافة امتحان'),
                ),
              ],
            ),
          );
          if (addExam == true && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeacherExamFormPage(
                  service: _service,
                  session: session,
                  lectureId: lectureId,
                ),
              ),
            );
            await _load();
          }
        }
      }
      return;
    }
    final dialog = OfferFormDialog(
      service: _service,
      session: session,
      courses: _courses,
      lectures: _lectures,
    );
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => dialog,
    );
    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
      }
    }
  }

  Future<void> _changePassword() async {
    final formKey = GlobalKey<FormState>();
    final currentPassword = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    var obscure = true;
    final passwords = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPassword,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.isEmpty ?? true)
                      ? 'اكتب كلمة المرور الحالية'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: password,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'اكتب 8 أحرف أو أرقام على الأقل'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmation,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != password.text
                      ? 'كلمتا المرور غير متطابقتين'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, (
                    currentPassword.text,
                    password.text,
                  ));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    currentPassword.dispose();
    password.dispose();
    confirmation.dispose();
    if (passwords == null || !mounted) return;
    try {
      await _service.changePassword(
        currentPassword: passwords.$1,
        newPassword: passwords.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تغيير كلمة المرور: $error')));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة المدرس'),
          actions: [
            IconButton(
              onPressed: _changePassword,
              tooltip: 'تغيير كلمة المرور',
              icon: const Icon(Icons.password_rounded),
            ),
            IconButton(
              onPressed: _load,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await _service.signOut();
                if (context.mounted) context.go(AppRoutes.teacherLogin);
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'الكورسات', icon: Icon(Icons.school_outlined)),
              Tab(text: 'الحصص', icon: Icon(Icons.play_lesson_outlined)),
              Tab(text: 'العروض', icon: Icon(Icons.local_offer_outlined)),
              Tab(
                text: 'تدريبات النطق',
                icon: Icon(Icons.record_voice_over_outlined),
              ),
              Tab(text: 'الإشعارات', icon: Icon(Icons.notifications_outlined)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, retry: _load)
            : TabBarView(
                controller: _tabs,
                children: [
                  _AdminList(
                    emptyText: 'لم تتم إضافة كورسات بعد',
                    items: _courses,
                    title: (item) => item['title']?.toString() ?? '',
                    subtitle: (item) =>
                        '${item['price'] ?? 0} ج.م • ${item['grade'] ?? 'بدون صف'}',
                    icon: Icons.school,
                    onTap: (item) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ContentDetailsPage(
                          type: _AdminContentType.course,
                          item: item,
                        ),
                      ),
                    ),
                  ),
                  _AdminList(
                    emptyText: 'لم تتم إضافة حصص بعد',
                    items: _lectures,
                    title: (item) => item['title']?.toString() ?? '',
                    subtitle: (item) =>
                        '${item['online_price'] ?? 0} ج.م • ${item['course_id'] == null ? 'حصة منفردة' : 'داخل كورس'}',
                    icon: Icons.play_circle_outline,
                    onTap: (item) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _ContentDetailsPage(
                          type: _AdminContentType.lecture,
                          item: item,
                          service: _service,
                          session: _session,
                        ),
                      ),
                    ),
                  ),
                  _AdminList(
                    emptyText: 'لم تتم إضافة عروض بعد',
                    items: _offers,
                    title: (item) => item['title']?.toString() ?? '',
                    subtitle: (item) {
                      final contents = item['commerce_offer_items'];
                      final count = contents is List ? contents.length : 0;
                      return '${item['offer_price'] ?? 0} ج.م • $count محتوى';
                    },
                    icon: Icons.local_offer,
                  ),
                  PronunciationSubmissionReview(
                    service: _service,
                    submissions: _pronunciationSubmissions,
                    isLoading: _pronunciationLoading,
                    error: _pronunciationError,
                    onRetry: _loadPronunciationSubmissions,
                  ),
                  _NotificationComposer(
                    service: _service,
                    session: _session!,
                    lectures: _lectures,
                  ),
                ],
              ),
        floatingActionButton:
            _loading || _session == null || _tabs.index == 3 || _tabs.index == 4
            ? null
            : FloatingActionButton.extended(
                onPressed: _addCurrent,
                icon: const Icon(Icons.add),
                label: const Text('إضافة جديد'),
              ),
      ),
    );
  }
}

class _NotificationComposer extends StatefulWidget {
  const _NotificationComposer({
    required this.service,
    required this.session,
    required this.lectures,
  });

  final TeacherAdminService service;
  final TeacherAdminSession session;
  final List<Map<String, dynamic>> lectures;

  @override
  State<_NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends State<_NotificationComposer> {
  static const _allStudents = '__all__';
  static const _destinations = <(String, String)>[
    ('صندوق الإشعارات', AppRoutes.notifications),
    ('الرئيسية', AppRoutes.main),
    ('قائمة الحصص', AppRoutes.lectures),
    ('تفاصيل حصة محددة', AppRoutes.lectureDetails),
    ('قائمة الامتحانات', AppRoutes.allExams),
    ('تفاصيل امتحان محدد', AppRoutes.examDetails),
    ('لوحة الشرف', AppRoutes.leaderboard),
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _exams = [];
  String _recipient = _allStudents;
  String _route = AppRoutes.notifications;
  String? _actionId;
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        widget.service.students(),
        widget.service.exams(widget.session.teacherId),
      ]);
      if (!mounted) return;
      setState(() {
        _students = results[0];
        _exams = results[1];
        _loading = false;
      });
    } catch (error) {
      debugPrint('Teacher notification options load failed: $error');
      if (!mounted) return;
      setState(() {
        _loadError =
            'تعذر تحميل بيانات الطلاب والإشعارات. تأكد من تحديث قاعدة البيانات ثم أعد المحاولة.';
        _loading = false;
      });
    }
  }

  bool get _needsActionId =>
      _route == AppRoutes.lectureDetails || _route == AppRoutes.examDetails;

  List<Map<String, dynamic>> get _actionItems =>
      _route == AppRoutes.lectureDetails ? widget.lectures : _exams;

  Map<String, dynamic>? get _selectedStudent {
    if (_recipient == _allStudents) return null;
    for (final student in _students) {
      if (student['id'] == _recipient) return student;
    }
    return null;
  }

  Future<void> _chooseRecipient() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StudentPickerSheet(
        students: _students,
        selectedId: _recipient,
        allStudentsValue: _allStudents,
        onBlockChanged: _setStudentBlocked,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _recipient = selected);
    }
  }

  Future<void> _setStudentBlocked(
    Map<String, dynamic> student,
    bool isBlocked,
  ) async {
    await widget.service.setStudentBlocked(
      studentId: student['id'] as String,
      isBlocked: isBlocked,
    );
    if (!mounted) return;
    setState(() {
      final index = _students.indexWhere((item) => item['id'] == student['id']);
      if (index != -1) {
        _students[index] = {..._students[index], 'is_blocked': isBlocked};
      }
      if (isBlocked && _recipient == student['id']) {
        _recipient = _allStudents;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBlocked
              ? 'تم حظر ${student['name']} وإنهاء جلساته'
              : 'تم فك الحظر عن ${student['name']}',
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final result = await widget.service.sendNotification(
        title: _title.text,
        body: _body.text,
        actionRoute: _route,
        actionId: _needsActionId ? _actionId : null,
        studentId: _recipient == _allStudents ? null : _recipient,
      );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ الإشعار لـ ${result['stored_for'] ?? 0} طالب وإرساله بنجاح',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الإشعار: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _ErrorView(message: _loadError!, retry: _loadOptions);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إرسال إشعار للطلاب',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تُحفظ الرسالة في صندوق الطالب أولاً، ثم تُرسل كإشعار فوري.',
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: _chooseRecipient,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'المستلم',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people_outline),
                      suffixIcon: Icon(Icons.search_rounded),
                    ),
                    child: Text(
                      _selectedStudent == null
                          ? 'كل الطلاب'
                          : '${_selectedStudent!['name']} • ${_selectedStudent!['phone']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الإشعار',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'اكتب عنوان الإشعار'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'اكتب نص الرسالة'
                      : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _route,
                  decoration: const InputDecoration(
                    labelText: 'الصفحة عند الضغط',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.ads_click_outlined),
                  ),
                  items: _destinations
                      .map(
                        (destination) => DropdownMenuItem(
                          value: destination.$2,
                          child: Text(destination.$1),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _route = value ?? AppRoutes.notifications;
                    _actionId = null;
                  }),
                ),
                if (_needsActionId) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_route),
                    initialValue: _actionId,
                    decoration: InputDecoration(
                      labelText: _route == AppRoutes.lectureDetails
                          ? 'اختر الحصة'
                          : 'اختر الامتحان',
                      border: const OutlineInputBorder(),
                    ),
                    items: _actionItems
                        .map(
                          (item) => DropdownMenuItem(
                            value: item['id'] as String,
                            child: Text(
                              item['title']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _actionId = value),
                    validator: (value) => value == null
                        ? 'اختر المحتوى الذي سيفتحه الإشعار'
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال الإشعار'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet({
    required this.students,
    required this.selectedId,
    required this.allStudentsValue,
    required this.onBlockChanged,
  });

  final List<Map<String, dynamic>> students;
  final String selectedId;
  final String allStudentsValue;
  final Future<void> Function(Map<String, dynamic>, bool) onBlockChanged;

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _search = TextEditingController();
  late List<Map<String, dynamic>> _students;
  String _query = '';
  String? _updatingId;

  @override
  void initState() {
    super.initState();
    _students = widget.students.map((student) => {...student}).toList();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _students;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return _students.where((student) {
      final name = student['name']?.toString().toLowerCase() ?? '';
      final phone = student['phone']?.toString() ?? '';
      return name.contains(query) ||
          phone.contains(query) ||
          (digits.isNotEmpty &&
              phone.replaceAll(RegExp(r'\D'), '').contains(digits));
    }).toList();
  }

  Future<void> _toggleBlock(Map<String, dynamic> student) async {
    final isBlocked = student['is_blocked'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBlocked ? 'فك حظر الطالب' : 'حظر الطالب'),
        content: Text(
          isBlocked
              ? 'هل تريد السماح لـ ${student['name']} باستخدام التطبيق مرة أخرى؟'
              : 'سيتم إنهاء كل جلسات ${student['name']} ولن يتمكن من استخدام التطبيق حتى تفك الحظر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: !isBlocked
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isBlocked ? 'فك الحظر' : 'حظر'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingId = student['id'] as String);
    try {
      await widget.onBlockChanged(student, !isBlocked);
      if (!mounted) return;
      setState(() {
        final index = _students.indexWhere(
          (item) => item['id'] == student['id'],
        );
        if (index != -1) {
          _students[index] = {..._students[index], 'is_blocked': !isBlocked};
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث حالة الطالب: $error')));
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'اختر الطالب',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups_rounded),
                    ),
                    title: const Text(
                      'كل الطلاب',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: widget.selectedId == widget.allStudentsValue
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () =>
                        Navigator.pop(context, widget.allStudentsValue),
                  ),
                  const Divider(),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('لا يوجد طالب مطابق للبحث')),
                    ),
                  for (final student in filtered)
                    _StudentSearchTile(
                      student: student,
                      selected: widget.selectedId == student['id'],
                      updating: _updatingId == student['id'],
                      onSelect: student['is_blocked'] == true
                          ? null
                          : () =>
                                Navigator.pop(context, student['id'] as String),
                      onToggleBlock: () => _toggleBlock(student),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentSearchTile extends StatelessWidget {
  const _StudentSearchTile({
    required this.student,
    required this.selected,
    required this.updating,
    required this.onSelect,
    required this.onToggleBlock,
  });

  final Map<String, dynamic> student;
  final bool selected;
  final bool updating;
  final VoidCallback? onSelect;
  final VoidCallback onToggleBlock;

  @override
  Widget build(BuildContext context) {
    final blocked = student['is_blocked'] == true;
    return Card(
      color: blocked ? Colors.red.withAlpha(12) : null,
      child: ListTile(
        onTap: onSelect,
        leading: CircleAvatar(
          backgroundColor: blocked
              ? Colors.red.withAlpha(25)
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            blocked ? Icons.person_off_outlined : Icons.person_outline,
            color: blocked ? Colors.red : null,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                student['name']?.toString() ?? 'طالب',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (blocked)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 6),
                child: Text(
                  'محظور',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${student['phone'] ?? ''} • ${student['grade'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: updating
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: blocked ? 'فك الحظر' : 'حظر الطالب',
                onPressed: onToggleBlock,
                icon: Icon(
                  blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                  color: blocked ? Colors.green : Colors.red,
                ),
              ),
      ),
    );
  }
}

class _AdminList extends StatelessWidget {
  const _AdminList({
    required this.items,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emptyText,
    this.onTap,
  });

  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) title;
  final String Function(Map<String, dynamic>) subtitle;
  final IconData icon;
  final String emptyText;
  final ValueChanged<Map<String, dynamic>>? onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final enabled = item['is_published'] ?? item['is_active'] ?? true;
          return Card(
            child: ListTile(
              onTap: onTap == null ? null : () => onTap!(item),
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(
                title(item),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(subtitle(item)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled == true ? Icons.check_circle : Icons.visibility_off,
                    color: enabled == true ? Colors.green : Colors.grey,
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _AdminContentType { course, lecture }

class _ContentDetailsPage extends StatelessWidget {
  const _ContentDetailsPage({
    required this.type,
    required this.item,
    this.service,
    this.session,
  });

  final _AdminContentType type;
  final Map<String, dynamic> item;
  final TeacherAdminService? service;
  final TeacherAdminSession? session;

  @override
  Widget build(BuildContext context) {
    final isCourse = type == _AdminContentType.course;
    final thumbnail = item['thumbnail_url'] as String?;
    final contents = item['lecture_contents'] as List<dynamic>? ?? const [];
    final courseLectures = <String, Map<String, dynamic>>{};
    if (isCourse) {
      for (final raw in item['direct_lectures'] as List<dynamic>? ?? const []) {
        final lecture = Map<String, dynamic>.from(raw as Map);
        final id = lecture['id'] as String?;
        if (id != null) courseLectures[id] = lecture;
      }
      for (final raw in item['course_lectures'] as List<dynamic>? ?? const []) {
        final mapping = Map<String, dynamic>.from(raw as Map);
        final embedded = mapping['lectures'];
        if (embedded is Map) {
          final lecture = Map<String, dynamic>.from(embedded);
          final id = lecture['id'] as String?;
          if (id != null) courseLectures[id] = lecture;
        }
      }
    }
    final details = <(String, String)>[
      ('النوع', isCourse ? 'كورس' : 'حصة'),
      ('المرحلة', item['stage']?.toString() ?? 'غير محدد'),
      ('الصف', item['grade']?.toString() ?? 'غير محدد'),
      (
        'المادة',
        isCourse
            ? 'اللغة الإنجليزية'
            : item['subject']?.toString() ?? 'اللغة الإنجليزية',
      ),
      if (!isCourse)
        ('الباب أو الوحدة', item['chapter']?.toString() ?? 'غير محدد'),
      if (!isCourse)
        ('رقم الدرس', item['lesson_number']?.toString() ?? 'غير محدد'),
      if (isCourse) ('السعر', '${item['price'] ?? 0} ج.م'),
      if (!isCourse) ('سعر الأونلاين', '${item['online_price'] ?? 0} ج.م'),
      if (!isCourse) ('سعر السنتر', '${item['center_price'] ?? 0} ج.م'),
      (
        'الحالة',
        item['is_published'] == true ? 'منشور ومتاح للطلاب' : 'غير منشور',
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isCourse ? 'تفاصيل الكورس' : 'تفاصيل الحصة'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (thumbnail?.isNotEmpty == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  thumbnail!,
                  height: 210,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              item['title']?.toString() ?? '',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if ((item['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item['description'].toString()),
            ],
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: details
                    .map(
                      (detail) => ListTile(
                        title: Text(detail.$1),
                        trailing: SizedBox(
                          width: 180,
                          child: Text(
                            detail.$2,
                            textAlign: TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (isCourse) ...[
              const SizedBox(height: 20),
              Text(
                'حصص الكورس (${courseLectures.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (courseLectures.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لم تتم إضافة حصص إلى الكورس بعد.'),
                  ),
                )
              else
                ...courseLectures.values.map(
                  (lecture) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(lecture['title']?.toString() ?? 'حصة'),
                      trailing: Icon(
                        lecture['is_published'] == true
                            ? Icons.check_circle
                            : Icons.visibility_off,
                        color: lecture['is_published'] == true
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
            ],
            if (!isCourse) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: service == null || session == null
                    ? null
                    : () async {
                        final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => TeacherExamFormPage(
                              service: service!,
                              session: session!,
                              lectureId: item['id'].toString(),
                            ),
                          ),
                        );
                        if (created == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تمت إضافة الامتحان بنجاح'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.assignment_add),
                label: const Text('إضافة امتحان للحصة'),
              ),
              const SizedBox(height: 20),
              Text(
                'محتوى الحصة (${contents.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (contents.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لا توجد ملفات مرتبطة بالحصة.'),
                  ),
                )
              else
                ...contents.map((raw) {
                  final content = Map<String, dynamic>.from(raw as Map);
                  return Card(
                    child: ListTile(
                      leading: Icon(switch (content['content_type']) {
                        'video' => Icons.play_circle_outline,
                        'pdf' => Icons.picture_as_pdf_outlined,
                        'audio' => Icons.audio_file_outlined,
                        _ => Icons.insert_drive_file_outlined,
                      }),
                      title: Text(content['title']?.toString() ?? 'ملف'),
                      subtitle: Text(content['content_type']?.toString() ?? ''),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );
}

class CourseFormPage extends StatefulWidget {
  const CourseFormPage({
    super.key,
    required this.service,
    required this.session,
  });
  final TeacherAdminService service;
  final TeacherAdminSession session;

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends State<CourseFormPage> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController(text: '0');
  String? _stage;
  String? _grade;
  String _level = 'beginner';
  String _recommendedSkill = 'overall';
  final _minScore = TextEditingController(text: '0');
  final _maxScore = TextEditingController(text: '39');
  PlatformFile? _thumbnail;
  bool _published = true;
  bool _saving = false;

  String? _placementScoreValidator(String? value) {
    final score = int.tryParse(value ?? '');
    if (score == null) return 'أدخل رقمًا صحيحًا';
    if (score < 0 || score > 100) return 'من 0 إلى 100';
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _minScore.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.createCourse(
        session: widget.session,
        title: _title.text,
        description: _description.text,
        stage: _stage!,
        grade: _grade!,
        price: double.parse(_price.text),
        isPublished: _published,
        level: _level,
        recommendedSkill: _recommendedSkill,
        minPlacementScore: int.parse(_minScore.text),
        maxPlacementScore: int.parse(_maxScore.text),
        thumbnail: _thumbnail,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إضافة كورس جديد')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _requiredField(_title, 'اسم الكورس'),
                  _field(_description, 'وصف الكورس', lines: 3),
                  DropdownButtonFormField<String>(
                    initialValue: _stage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المرحلة الدراسية',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.allStages
                        .map(
                          (stage) => DropdownMenuItem(
                            value: stage,
                            child: Text(
                              stage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _stage = value;
                      _grade = null;
                    }),
                    validator: (value) => value == null ? 'اختر المرحلة' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_stage),
                    initialValue: _grade,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الصف الدراسي',
                      border: OutlineInputBorder(),
                    ),
                    items: _stage == null
                        ? const []
                        : AppConstants.getGradesForStage(_stage!)
                              .map(
                                (grade) => DropdownMenuItem(
                                  value: grade,
                                  child: Text(
                                    grade,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                    onChanged: _stage == null
                        ? null
                        : (value) => setState(() => _grade = value),
                    validator: (value) => value == null ? 'اختر الصف' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: 'اللغة الإنجليزية',
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'المادة',
                      prefixIcon: Icon(Icons.translate_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _numberField(_price, 'السعر'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _level,
                    decoration: const InputDecoration(
                      labelText: 'المستوى المناسب للكورس',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'beginner', child: Text('مبتدئ')),
                      DropdownMenuItem(
                        value: 'intermediate',
                        child: Text('متوسط'),
                      ),
                      DropdownMenuItem(
                        value: 'distinguished',
                        child: Text('متميز'),
                      ),
                      DropdownMenuItem(
                        value: 'legendary',
                        child: Text('أسطوري'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _level = value;
                        switch (value) {
                          case 'beginner':
                            _minScore.text = '0';
                            _maxScore.text = '39';
                            break;
                          case 'intermediate':
                            _minScore.text = '40';
                            _maxScore.text = '64';
                            break;
                          case 'distinguished':
                            _minScore.text = '65';
                            _maxScore.text = '84';
                            break;
                          case 'legendary':
                            _minScore.text = '85';
                            _maxScore.text = '100';
                            break;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _recommendedSkill,
                    decoration: const InputDecoration(
                      labelText: 'المهارة التي يعالجها الكورس',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'overall',
                        child: Text('المستوى العام'),
                      ),
                      DropdownMenuItem(
                        value: 'pronunciation',
                        child: Text('النطق'),
                      ),
                      DropdownMenuItem(
                        value: 'reading',
                        child: Text('القراءة'),
                      ),
                      DropdownMenuItem(
                        value: 'writing',
                        child: Text('الكتابة'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _recommendedSkill = value ?? 'overall'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minScore,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'أقل درجة مناسبة',
                            suffixText: '%',
                            border: OutlineInputBorder(),
                          ),
                          validator: _placementScoreValidator,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxScore,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'أعلى درجة مناسبة',
                            suffixText: '%',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final error = _placementScoreValidator(value);
                            if (error != null) return error;
                            final min = int.tryParse(_minScore.text) ?? 0;
                            final max = int.tryParse(value ?? '') ?? 0;
                            return min > max
                                ? 'يجب أن تكون أكبر من الأقل'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  _FileButton(
                    label: _thumbnail?.name ?? 'اختيار صورة للكورس',
                    icon: Icons.image_outlined,
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        setState(() => _thumbnail = result.files.single);
                      }
                    },
                  ),
                  SwitchListTile(
                    value: _published,
                    onChanged: (value) => setState(() => _published = value),
                    title: const Text('نشر الكورس الآن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الكورس'),
          ),
        ),
      ),
    ),
  );
}

class LectureFormPage extends StatefulWidget {
  const LectureFormPage({
    super.key,
    required this.service,
    required this.session,
    required this.courses,
  });
  final TeacherAdminService service;
  final TeacherAdminSession session;
  final List<Map<String, dynamic>> courses;

  @override
  State<LectureFormPage> createState() => _LectureFormPageState();
}

class _PronunciationWordDraft {
  _PronunciationWordDraft()
    : controller = TextEditingController(),
      durationSeconds = 5;

  final TextEditingController controller;
  int durationSeconds;

  void dispose() => controller.dispose();
}

class _LectureFormPageState extends State<LectureFormPage> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _chapter = TextEditingController();
  final _lesson = TextEditingController();
  final _onlinePrice = TextEditingController(text: '0');
  final _centerPrice = TextEditingController(text: '0');
  final _linkTitle = TextEditingController();
  final _linkUrl = TextEditingController();
  String? _stage;
  String? _grade;
  String? _courseId;
  PlatformFile? _thumbnail;
  List<PlatformFile> _files = [];
  bool _published = true;
  bool _saving = false;
  bool _pronunciationEnabled = false;
  final List<_PronunciationWordDraft> _pronunciationWords = [];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _chapter.dispose();
    _lesson.dispose();
    _onlinePrice.dispose();
    _centerPrice.dispose();
    _linkTitle.dispose();
    _linkUrl.dispose();
    for (final word in _pronunciationWords) {
      word.dispose();
    }
    super.dispose();
  }

  void _addPronunciationWord() {
    setState(() => _pronunciationWords.add(_PronunciationWordDraft()));
  }

  List<Map<String, dynamic>>? _validatedPronunciationWords() {
    if (!_pronunciationEnabled) return const [];
    if (_pronunciationWords.isEmpty) {
      _showError(context, 'أضف كلمة واحدة على الأقل لواجب النطق');
      return null;
    }
    final words = <Map<String, dynamic>>[];
    for (final draft in _pronunciationWords) {
      final word = draft.controller.text.trim();
      if (word.isEmpty) {
        _showError(context, 'اكتب كل الكلمات المطلوبة في واجب النطق');
        return null;
      }
      words.add({'word': word, 'max_duration_seconds': draft.durationSeconds});
    }
    return words;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_files.isEmpty && _linkUrl.text.trim().isEmpty) {
      _showError(context, 'اختر ملفًا أو أضف رابطًا واحدًا على الأقل');
      return;
    }
    final pronunciationWords = _validatedPronunciationWords();
    if (pronunciationWords == null) return;
    setState(() => _saving = true);
    try {
      final lectureId = await widget.service.createLecture(
        session: widget.session,
        title: _title.text,
        description: _description.text,
        stage: _stage!,
        grade: _grade!,
        subject: 'اللغة الإنجليزية',
        chapter: _chapter.text,
        lessonNumber: _lesson.text,
        onlinePrice: double.parse(_onlinePrice.text),
        centerPrice: double.parse(_centerPrice.text),
        isPublished: _published,
        courseId: _courseId,
        thumbnail: _thumbnail,
        contentFiles: _files,
        contentLinks: _linkUrl.text.trim().isEmpty
            ? const []
            : [
                {
                  'title': _linkTitle.text.trim().isEmpty
                      ? 'رابط إضافي'
                      : _linkTitle.text.trim(),
                  'url': _linkUrl.text.trim(),
                },
              ],
        pronunciationWords: pronunciationWords,
      );
      if (mounted) Navigator.pop(context, lectureId);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إضافة حصة جديدة')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _courseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'مكان الحصة',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'حصة منفردة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...widget.courses.map(
                        (course) => DropdownMenuItem<String?>(
                          value: course['id'] as String,
                          child: Text(
                            'داخل: ${course['title']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _courseId = value),
                  ),
                  const SizedBox(height: 12),
                  _requiredField(_title, 'اسم الحصة'),
                  _field(_description, 'الوصف', lines: 3),
                  DropdownButtonFormField<String>(
                    initialValue: _stage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المرحلة الدراسية',
                      border: OutlineInputBorder(),
                    ),
                    items: AppConstants.allStages
                        .map(
                          (stage) => DropdownMenuItem(
                            value: stage,
                            child: Text(
                              stage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _stage = value;
                      _grade = null;
                    }),
                    validator: (value) => value == null ? 'اختر المرحلة' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_stage),
                    initialValue: _grade,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الصف الدراسي',
                      border: OutlineInputBorder(),
                    ),
                    items: _stage == null
                        ? const []
                        : AppConstants.getGradesForStage(_stage!)
                              .map(
                                (grade) => DropdownMenuItem(
                                  value: grade,
                                  child: Text(
                                    grade,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                    onChanged: _stage == null
                        ? null
                        : (value) => setState(() => _grade = value),
                    validator: (value) => value == null ? 'اختر الصف' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: 'اللغة الإنجليزية',
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'المادة',
                      prefixIcon: Icon(Icons.translate_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(_chapter, 'الباب أو الوحدة'),
                  _field(_lesson, 'رقم الدرس'),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(_onlinePrice, 'سعر الأونلاين'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(_centerPrice, 'سعر السنتر')),
                    ],
                  ),
                  _FileButton(
                    label: _thumbnail?.name ?? 'اختيار صورة للحصة',
                    icon: Icons.image_outlined,
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null) {
                        setState(() => _thumbnail = result.files.single);
                      }
                    },
                  ),
                  _FileButton(
                    label: _files.isEmpty
                        ? 'اختيار فيديو أو PDF أو صوت أو صورة'
                        : 'تم اختيار ${_files.length} ملف',
                    icon: Icons.upload_file,
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        type: FileType.custom,
                        allowedExtensions: [
                          'mp4',
                          'mov',
                          'mkv',
                          'webm',
                          'pdf',
                          'mp3',
                          'm4a',
                          'wav',
                          'aac',
                          'jpg',
                          'jpeg',
                          'png',
                          'webp',
                        ],
                      );
                      if (result != null) setState(() => _files = result.files);
                    },
                  ),
                  if (_files.isNotEmpty)
                    ..._files.map(
                      (file) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(file.name),
                      ),
                    ),
                  _field(_linkTitle, 'عنوان الرابط (اختياري)'),
                  TextFormField(
                    controller: _linkUrl,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رابط إضافي للطلاب (اختياري)',
                      hintText: 'https://example.com',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final uri = Uri.tryParse(text);
                      return uri != null && uri.hasScheme
                          ? null
                          : 'اكتب رابطًا صحيحًا';
                    },
                  ),
                  _buildPronunciationEditor(),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _published,
                    onChanged: (value) => setState(() => _published = value),
                    title: const Text('نشر الحصة الآن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'جارٍ الرفع والحفظ...' : 'حفظ الحصة'),
          ),
        ),
      ),
    ),
  );

  Widget _buildPronunciationEditor() => Card(
    margin: const EdgeInsets.only(top: 16),
    color: const Color(0xFFFAF8FF),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pronunciationEnabled,
            onChanged: (enabled) {
              setState(() {
                _pronunciationEnabled = enabled;
                if (enabled && _pronunciationWords.isEmpty) {
                  _pronunciationWords.add(_PronunciationWordDraft());
                }
              });
            },
            title: const Text(
              'إضافة واجب تسجيل النطق',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('يسجل الطالب كل كلمة ويرسلها لتراجعها بنفسك'),
            secondary: const Icon(
              Icons.record_voice_over_rounded,
              color: Color(0xFF6D28D9),
            ),
          ),
          if (_pronunciationEnabled) ...[
            const Divider(height: 18),
            for (var index = 0; index < _pronunciationWords.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pronunciationWords[index].controller,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'الكلمة ${index + 1}',
                          hintText: 'مثال: pronunciation',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<int>(
                        initialValue:
                            _pronunciationWords[index].durationSeconds,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المدة',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (var seconds = 1; seconds <= 10; seconds++)
                            DropdownMenuItem(
                              value: seconds,
                              child: Text('$seconds ث'),
                            ),
                        ],
                        onChanged: (seconds) {
                          if (seconds != null) {
                            setState(() {
                              _pronunciationWords[index].durationSeconds =
                                  seconds;
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف الكلمة',
                      onPressed: () {
                        final removed = _pronunciationWords.removeAt(index);
                        removed.dispose();
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _pronunciationWords.length >= 30
                    ? null
                    : _addPronunciationWord,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة كلمة'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class OfferFormDialog extends StatefulWidget {
  const OfferFormDialog({
    super.key,
    required this.service,
    required this.session,
    required this.courses,
    required this.lectures,
  });
  final TeacherAdminService service;
  final TeacherAdminSession session;
  final List<Map<String, dynamic>> courses;
  final List<Map<String, dynamic>> lectures;

  @override
  State<OfferFormDialog> createState() => _OfferFormDialogState();
}

class _OfferFormDialogState extends State<OfferFormDialog> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _badge = TextEditingController();
  final _price = TextEditingController();
  final _originalPrice = TextEditingController();
  final _days = TextEditingController();
  final _views = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_selected.isEmpty) {
      _showError(context, 'اختر كورسًا أو حصة واحدة على الأقل داخل العرض');
      return;
    }
    final original = _optionalDouble(_originalPrice.text);
    final offerPrice = double.parse(_price.text);
    if (original != null && original < offerPrice) {
      _showError(context, 'السعر قبل الخصم يجب ألا يقل عن سعر العرض');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.createOffer(
        session: widget.session,
        title: _title.text,
        description: _description.text,
        badge: _badge.text,
        offerPrice: offerPrice,
        originalPrice: original,
        accessDurationDays: _optionalInt(_days.text),
        viewLimit: _optionalInt(_views.text),
        items: _selected.map((value) {
          final split = value.indexOf(':');
          return {
            'type': value.substring(0, split),
            'id': value.substring(split + 1),
          };
        }).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FormDialog(
    title: 'إضافة عرض',
    saving: _saving,
    onSave: _save,
    child: Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _requiredField(_title, 'اسم العرض'),
          _field(_description, 'تفاصيل العرض', lines: 3),
          _field(_badge, 'شارة العرض، مثال: وفر 30%'),
          Row(
            children: [
              Expanded(child: _numberField(_price, 'سعر العرض')),
              const SizedBox(width: 8),
              Expanded(
                child: _optionalNumberField(_originalPrice, 'السعر قبل الخصم'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _optionalNumberField(_days, 'مدة الوصول بالأيام'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _optionalNumberField(_views, 'عدد المشاهدات')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'محتوى العرض',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Text(
            'اترك المدة أو عدد المشاهدات فارغًا إذا كان الوصول غير محدود.',
          ),
          const SizedBox(height: 8),
          ...widget.courses.map(
            (item) => _selectionTile('course', item, Icons.school_outlined),
          ),
          ...widget.lectures.map(
            (item) =>
                _selectionTile('lecture', item, Icons.play_circle_outline),
          ),
          if (widget.courses.isEmpty && widget.lectures.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('أضف كورسًا أو حصة أولًا.'),
            ),
        ],
      ),
    ),
  );

  Widget _selectionTile(String type, Map<String, dynamic> item, IconData icon) {
    final key = '$type:${item['id']}';
    return CheckboxListTile(
      value: _selected.contains(key),
      secondary: Icon(icon),
      title: Text(item['title']?.toString() ?? ''),
      subtitle: Text(type == 'course' ? 'كورس' : 'حصة'),
      onChanged: (checked) => setState(
        () => checked == true ? _selected.add(key) : _selected.remove(key),
      ),
    );
  }
}

class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.child,
    required this.saving,
    required this.onSave,
  });
  final String title;
  final Widget child;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            trailing: IconButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'جارٍ الرفع والحفظ...' : 'حفظ'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FileButton extends StatelessWidget {
  const _FileButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    ),
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  int lines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: controller,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  ),
);

Widget _requiredField(TextEditingController controller, String label) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      ),
    );

Widget _numberField(TextEditingController controller, String label) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final number = double.tryParse(value ?? '');
      return number == null || number < 0 ? 'اكتب رقمًا صحيحًا' : null;
    },
  ),
);

Widget _optionalNumberField(TextEditingController controller, String label) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value != null &&
                value.trim().isNotEmpty &&
                (double.tryParse(value) == null || double.parse(value) <= 0)
            ? 'رقم غير صحيح'
            : null,
      ),
    );

double? _optionalDouble(String value) =>
    value.trim().isEmpty ? null : double.parse(value);
int? _optionalInt(String value) =>
    value.trim().isEmpty ? null : int.parse(value);

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('تعذر الحفظ: $error'), backgroundColor: Colors.red),
  );
}
