import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/teacher_admin_service.dart';

class TeacherExamFormPage extends StatefulWidget {
  const TeacherExamFormPage({
    super.key,
    required this.service,
    required this.session,
    required this.lectureId,
  });

  final TeacherAdminService service;
  final TeacherAdminSession session;
  final String lectureId;

  @override
  State<TeacherExamFormPage> createState() => _TeacherExamFormPageState();
}

class _TeacherExamFormPageState extends State<TeacherExamFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController(text: '15');
  final _attempts = TextEditingController(text: '1');
  final _passScore = TextEditingController(text: '1');
  final List<_QuestionDraft> _questions = [_QuestionDraft()];
  bool _published = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    _attempts.dispose();
    _passScore.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final totalScore = _questions.fold<int>(
      0,
      (sum, question) => sum + int.parse(question.points.text),
    );
    if (int.parse(_passScore.text) > totalScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'درجة النجاح لا يمكن أن تزيد عن الدرجة الكلية ($totalScore)',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.service.createExam(
        session: widget.session,
        lectureId: widget.lectureId,
        title: _title.text,
        description: _description.text,
        durationMinutes: int.parse(_duration.text),
        maxAttempts: int.parse(_attempts.text),
        passScore: int.parse(_passScore.text),
        isPublished: _published,
        questions: _questions.map((q) => q.toMap()).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ الامتحان: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إضافة امتحان للحصة')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _textField(_title, 'اسم الامتحان', required: true),
            _textField(_description, 'وصف الامتحان', lines: 3),
            Row(
              children: [
                Expanded(child: _numberField(_duration, 'الوقت بالدقائق')),
                const SizedBox(width: 10),
                Expanded(child: _numberField(_attempts, 'عدد المحاولات')),
              ],
            ),
            _numberField(_passScore, 'درجة النجاح'),
            SwitchListTile(
              value: _published,
              onChanged: (value) => setState(() => _published = value),
              title: const Text('نشر الامتحان الآن'),
            ),
            const Divider(height: 32),
            ..._questions.asMap().entries.map(
              (entry) => _QuestionCard(
                index: entry.key,
                draft: entry.value,
                canDelete: _questions.length > 1,
                onChanged: () => setState(() {}),
                onDelete: () => setState(() {
                  _questions.removeAt(entry.key).dispose();
                }),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _questions.add(_QuestionDraft())),
              icon: const Icon(Icons.add),
              label: const Text('إضافة سؤال آخر'),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الامتحان'),
          ),
        ),
      ),
    ),
  );
}

class _QuestionDraft {
  final text = TextEditingController();
  final points = TextEditingController(text: '1');
  final options = List.generate(4, (_) => TextEditingController());
  String answerType = 'mcq';
  int correctOption = 0;
  PlatformFile? media;
  String mediaType = 'text';

  Map<String, dynamic> toMap() => {
    'question_text': text.text.trim(),
    'points': int.parse(points.text),
    'answer_type': answerType,
    'media_type': mediaType,
    'media': media,
    'options': answerType == 'mcq'
        ? options.map((e) => e.text.trim()).toList()
        : <String>[],
    'correct_answer': answerType == 'mcq'
        ? options[correctOption].text.trim()
        : null,
  };

  void dispose() {
    text.dispose();
    points.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.draft,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final _QuestionDraft draft;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'السؤال ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (canDelete)
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete)),
            ],
          ),
          _textField(draft.text, 'نص السؤال', required: true, lines: 2),
          DropdownButtonFormField<String>(
            initialValue: draft.answerType,
            decoration: const InputDecoration(
              labelText: 'طريقة الإجابة',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'mcq',
                child: Text('اختيار من متعدد MCQ'),
              ),
              DropdownMenuItem(value: 'essay', child: Text('إجابة مقالية')),
            ],
            onChanged: (value) {
              draft.answerType = value!;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _numberField(draft.points, 'درجة السؤال'),
          if (draft.answerType == 'mcq')
            RadioGroup<int>(
              groupValue: draft.correctOption,
              onChanged: (value) {
                if (value == null) return;
                draft.correctOption = value;
                onChanged();
              },
              child: Column(
                children: draft.options
                    .asMap()
                    .entries
                    .map(
                      (entry) => RadioListTile<int>(
                        value: entry.key,
                        title: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: 'الاختيار ${entry.key + 1}',
                          ),
                          validator: (value) =>
                              draft.answerType == 'mcq' &&
                                  (value?.trim().isEmpty ?? true)
                              ? 'اكتب الاختيار'
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: [
                  'jpg',
                  'jpeg',
                  'png',
                  'webp',
                  'mp3',
                  'm4a',
                  'wav',
                  'aac',
                ],
              );
              if (result == null) return;
              draft.media = result.files.single;
              final extension = draft.media!.extension?.toLowerCase();
              draft.mediaType = ['mp3', 'm4a', 'wav', 'aac'].contains(extension)
                  ? 'audio'
                  : 'image';
              onChanged();
            },
            icon: Icon(
              draft.mediaType == 'audio' ? Icons.audio_file : Icons.image,
            ),
            label: Text(draft.media?.name ?? 'إضافة صورة أو ملف صوتي للسؤال'),
          ),
        ],
      ),
    ),
  );
}

Widget _textField(
  TextEditingController controller,
  String label, {
  bool required = false,
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
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
        : null,
  ),
);

Widget _numberField(TextEditingController controller, String label) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final number = int.tryParse(value ?? '');
      return number == null || number <= 0 ? 'اكتب رقمًا أكبر من صفر' : null;
    },
  ),
);
