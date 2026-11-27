import 'package:material_ui/material_ui.dart';

import '../../data/services/gemini_study_service.dart';

class AiPdfStudyScreen extends StatefulWidget {
  final String pdfPath;
  final String title;

  const AiPdfStudyScreen({
    super.key,
    required this.pdfPath,
    required this.title,
  });

  @override
  State<AiPdfStudyScreen> createState() => _AiPdfStudyScreenState();
}

class _AiPdfStudyScreenState extends State<AiPdfStudyScreen> {
  final GeminiStudyService _service = GeminiStudyService();
  final Set<String> _types = {'multiple_choice'};
  int _count = 10;
  bool _loading = false;
  AiStudyPack? _pack;
  int _questionIndex = 0;
  int _score = 0;
  bool _examStarted = false;
  bool _finished = false;
  String? _selectedAnswer;
  final TextEditingController _shortAnswer = TextEditingController();

  @override
  void dispose() {
    _shortAnswer.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_types.isEmpty) return;
    setState(() => _loading = true);
    try {
      final pack = await _service.analyzePdf(
        pdfPath: widget.pdfPath,
        questionTypes: _types,
        questionCount: _count,
      );
      if (mounted) setState(() => _pack = pack);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submitAnswer() {
    final pack = _pack!;
    final question = pack.questions[_questionIndex];
    final answer = question.type == 'short_answer'
        ? _shortAnswer.text.trim()
        : _selectedAnswer?.trim() ?? '';
    if (answer.isEmpty) return;
    final normalize = (String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalize(answer) == normalize(question.correctAnswer)) _score++;

    if (_questionIndex + 1 >= pack.questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _questionIndex++;
        _selectedAnswer = null;
        _shortAnswer.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التلخيص والامتحان بالذكاء الاصطناعي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _finished
          ? _buildResult()
          : _examStarted
          ? _buildQuestion()
          : _buildSetupAndSummary(),
    );
  }

  Widget _buildSetupAndSummary() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        const Text(
          'اختر أنواع الأسئلة:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        CheckboxListTile(
          value: _types.contains('multiple_choice'),
          title: const Text('اختيار من متعدد'),
          onChanged: (_) => setState(() => _toggleType('multiple_choice')),
        ),
        CheckboxListTile(
          value: _types.contains('true_false'),
          title: const Text('صح أو خطأ'),
          onChanged: (_) => setState(() => _toggleType('true_false')),
        ),
        CheckboxListTile(
          value: _types.contains('short_answer'),
          title: const Text('إجابة قصيرة'),
          onChanged: (_) => setState(() => _toggleType('short_answer')),
        ),
        Text('عدد الأسئلة: $_count'),
        Slider(
          value: _count.toDouble(),
          min: 5,
          max: 25,
          divisions: 4,
          label: '$_count',
          onChanged: (value) => setState(() => _count = value.round()),
        ),
        FilledButton.icon(
          onPressed: _types.isEmpty ? null : _generate,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('تلخيص وإنشاء الامتحان'),
        ),
        if (_pack != null) ...[
          const SizedBox(height: 24),
          const Text(
            'الملخص',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(_pack!.summary, textAlign: TextAlign.right),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _pack!.questions.isEmpty
                ? null
                : () => setState(() => _examStarted = true),
            child: Text('ابدأ الامتحان (${_pack!.questions.length} سؤال)'),
          ),
        ],
      ],
    );
  }

  void _toggleType(String type) {
    _types.contains(type) ? _types.remove(type) : _types.add(type);
  }

  Widget _buildQuestion() {
    final question = _pack!.questions[_questionIndex];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LinearProgressIndicator(
          value: (_questionIndex + 1) / _pack!.questions.length,
        ),
        const SizedBox(height: 18),
        Text('السؤال ${_questionIndex + 1} من ${_pack!.questions.length}'),
        const SizedBox(height: 10),
        Text(
          question.question,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        if (question.type == 'short_answer')
          TextField(
            controller: _shortAnswer,
            decoration: const InputDecoration(
              labelText: 'اكتب إجابتك',
              border: OutlineInputBorder(),
            ),
          )
        else
          ...question.options.map(
            (option) => RadioListTile<String>(
              value: option,
              groupValue: _selectedAnswer,
              title: Text(option),
              onChanged: (value) => setState(() => _selectedAnswer = value),
            ),
          ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _submitAnswer,
          child: const Text('تأكيد الإجابة'),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final total = _pack?.questions.length ?? 0;
    final percent = total == 0 ? 0 : ((_score / total) * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              'نتيجتك: $_score من $total',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text('$percent%', style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() {
                _questionIndex = 0;
                _score = 0;
                _finished = false;
                _examStarted = false;
                _selectedAnswer = null;
              }),
              child: const Text('إعادة الاختبار'),
            ),
          ],
        ),
      ),
    );
  }
}
