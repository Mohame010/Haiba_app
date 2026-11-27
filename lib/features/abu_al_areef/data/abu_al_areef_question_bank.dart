import '../domain/abu_al_areef_question.dart';

typedef _Verb = ({String base, String past, String participle, String third});
typedef _Word = ({String word, String definition});

const _subjects = <String>[
  'I',
  'you',
  'we',
  'they',
  'he',
  'she',
  'Ahmed',
  'Mona',
  'my brother',
  'the students',
];

const _objects = <String>[
  'lesson',
  'email',
  'project',
  'story',
  'report',
  'room',
  'meal',
  'picture',
  'message',
  'exercise',
];

const _verbs = <_Verb>[
  (base: 'write', past: 'wrote', participle: 'written', third: 'writes'),
  (base: 'read', past: 'read', participle: 'read', third: 'reads'),
  (base: 'make', past: 'made', participle: 'made', third: 'makes'),
  (base: 'take', past: 'took', participle: 'taken', third: 'takes'),
  (base: 'speak', past: 'spoke', participle: 'spoken', third: 'speaks'),
  (base: 'learn', past: 'learned', participle: 'learned', third: 'learns'),
  (base: 'study', past: 'studied', participle: 'studied', third: 'studies'),
  (base: 'watch', past: 'watched', participle: 'watched', third: 'watches'),
  (base: 'visit', past: 'visited', participle: 'visited', third: 'visits'),
  (base: 'finish', past: 'finished', participle: 'finished', third: 'finishes'),
  (base: 'begin', past: 'began', participle: 'begun', third: 'begins'),
  (base: 'choose', past: 'chose', participle: 'chosen', third: 'chooses'),
  (base: 'drive', past: 'drove', participle: 'driven', third: 'drives'),
  (base: 'eat', past: 'ate', participle: 'eaten', third: 'eats'),
  (base: 'find', past: 'found', participle: 'found', third: 'finds'),
  (base: 'give', past: 'gave', participle: 'given', third: 'gives'),
  (base: 'know', past: 'knew', participle: 'known', third: 'knows'),
  (base: 'leave', past: 'left', participle: 'left', third: 'leaves'),
  (base: 'meet', past: 'met', participle: 'met', third: 'meets'),
  (base: 'pay', past: 'paid', participle: 'paid', third: 'pays'),
  (base: 'run', past: 'ran', participle: 'run', third: 'runs'),
  (base: 'send', past: 'sent', participle: 'sent', third: 'sends'),
  (base: 'sing', past: 'sang', participle: 'sung', third: 'sings'),
  (base: 'sleep', past: 'slept', participle: 'slept', third: 'sleeps'),
  (base: 'teach', past: 'taught', participle: 'taught', third: 'teaches'),
  (base: 'think', past: 'thought', participle: 'thought', third: 'thinks'),
  (
    base: 'understand',
    past: 'understood',
    participle: 'understood',
    third: 'understands',
  ),
  (base: 'wear', past: 'wore', participle: 'worn', third: 'wears'),
  (base: 'win', past: 'won', participle: 'won', third: 'wins'),
  (base: 'build', past: 'built', participle: 'built', third: 'builds'),
  (base: 'buy', past: 'bought', participle: 'bought', third: 'buys'),
  (base: 'catch', past: 'caught', participle: 'caught', third: 'catches'),
  (base: 'clean', past: 'cleaned', participle: 'cleaned', third: 'cleans'),
  (base: 'close', past: 'closed', participle: 'closed', third: 'closes'),
  (base: 'cook', past: 'cooked', participle: 'cooked', third: 'cooks'),
  (base: 'draw', past: 'drew', participle: 'drawn', third: 'draws'),
  (base: 'drink', past: 'drank', participle: 'drunk', third: 'drinks'),
  (
    base: 'explain',
    past: 'explained',
    participle: 'explained',
    third: 'explains',
  ),
  (base: 'help', past: 'helped', participle: 'helped', third: 'helps'),
  (base: 'invite', past: 'invited', participle: 'invited', third: 'invites'),
  (base: 'open', past: 'opened', participle: 'opened', third: 'opens'),
  (base: 'play', past: 'played', participle: 'played', third: 'plays'),
  (
    base: 'remember',
    past: 'remembered',
    participle: 'remembered',
    third: 'remembers',
  ),
  (base: 'sell', past: 'sold', participle: 'sold', third: 'sells'),
  (base: 'show', past: 'showed', participle: 'shown', third: 'shows'),
  (base: 'solve', past: 'solved', participle: 'solved', third: 'solves'),
  (base: 'travel', past: 'traveled', participle: 'traveled', third: 'travels'),
  (base: 'use', past: 'used', participle: 'used', third: 'uses'),
  (base: 'work', past: 'worked', participle: 'worked', third: 'works'),
  (base: 'create', past: 'created', participle: 'created', third: 'creates'),
];

const _words = <_Word>[
  (word: 'ancient', definition: 'very old'),
  (word: 'brave', definition: 'showing courage'),
  (word: 'calm', definition: 'peaceful and not worried'),
  (word: 'difficult', definition: 'not easy'),
  (word: 'enormous', definition: 'very large'),
  (word: 'fragile', definition: 'easily broken'),
  (word: 'generous', definition: 'willing to give and share'),
  (word: 'honest', definition: 'truthful'),
  (word: 'improve', definition: 'make something better'),
  (word: 'journey', definition: 'a trip from one place to another'),
  (word: 'knowledge', definition: 'information and understanding'),
  (word: 'loyal', definition: 'faithful and supportive'),
  (word: 'modern', definition: 'related to the present time'),
  (word: 'narrow', definition: 'not wide'),
  (word: 'obvious', definition: 'easy to notice or understand'),
  (word: 'patient', definition: 'able to wait without becoming angry'),
  (word: 'quick', definition: 'moving or happening fast'),
  (word: 'rare', definition: 'not common'),
  (word: 'silent', definition: 'making no sound'),
  (word: 'tiny', definition: 'very small'),
  (word: 'unique', definition: 'one of a kind'),
  (word: 'valuable', definition: 'worth a lot or very useful'),
  (word: 'wise', definition: 'having good judgment'),
  (word: 'accurate', definition: 'correct and exact'),
  (word: 'benefit', definition: 'an advantage or helpful result'),
  (word: 'complex', definition: 'made of many connected parts'),
  (word: 'decline', definition: 'become less or decrease'),
  (word: 'efficient', definition: 'working well without waste'),
  (word: 'frequent', definition: 'happening often'),
  (word: 'gradual', definition: 'happening slowly over time'),
  (word: 'hesitate', definition: 'pause before doing something'),
  (word: 'identify', definition: 'recognize and name'),
  (word: 'maintain', definition: 'keep in good condition'),
  (word: 'obtain', definition: 'get or acquire'),
  (word: 'predict', definition: 'say what will happen'),
  (word: 'require', definition: 'need something'),
  (word: 'significant', definition: 'important or noticeable'),
  (word: 'temporary', definition: 'lasting for a limited time'),
  (word: 'various', definition: 'several different kinds'),
  (word: 'adapt', definition: 'change to suit new conditions'),
  (word: 'consequence', definition: 'a result of an action'),
  (word: 'demonstrate', definition: 'show clearly'),
  (word: 'evaluate', definition: 'judge quality or value'),
  (word: 'fundamental', definition: 'basic and essential'),
  (word: 'interpret', definition: 'explain the meaning'),
  (word: 'perspective', definition: 'a particular point of view'),
  (word: 'relevant', definition: 'connected to the subject'),
  (word: 'sufficient', definition: 'enough for a purpose'),
  (word: 'transform', definition: 'change completely'),
  (word: 'validate', definition: 'confirm that something is correct'),
];

const _vocabularyLeads = <String>[
  'Choose the word meaning',
  'Which word means',
  'Select the best match for',
  'Find the word defined as',
  'Pick the vocabulary item meaning',
  'What word has the meaning',
  'Choose the closest word to',
  'Identify the word that means',
  'Which option is defined as',
  'Select the word whose definition is',
];

List<AbuAlAreefQuestion>? _cache;

List<AbuAlAreefQuestion> get abuAlAreefQuestions =>
    _cache ??= List.unmodifiable(_buildQuestions());

List<AbuAlAreefQuestion> _buildQuestions() {
  final questions = <AbuAlAreefQuestion>[];
  for (var verbIndex = 0; verbIndex < _verbs.length; verbIndex++) {
    final verb = _verbs[verbIndex];
    for (
      var subjectIndex = 0;
      subjectIndex < _subjects.length;
      subjectIndex++
    ) {
      final subject = _subjects[subjectIndex];
      final singular = subjectIndex >= 4 && subjectIndex <= 8;
      _add(
        questions,
        id: 'present-$verbIndex-$subjectIndex',
        level: AbuAlAreefLevel.beginner,
        category: 'Present simple',
        prompt: 'Complete: $subject ___ English every day. (${verb.base})',
        choices: [verb.base, verb.third, verb.past, 'will ${verb.base}'],
        answer: singular ? verb.third : verb.base,
      );
      _add(
        questions,
        id: 'past-$verbIndex-$subjectIndex',
        level: AbuAlAreefLevel.intermediate,
        category: 'Past simple',
        prompt: 'Yesterday, $subject ___ the task. (${verb.base})',
        choices: [verb.base, verb.past, verb.participle, verb.third],
        answer: verb.past,
      );
      final auxiliary = singular ? 'has' : 'have';
      final wrongAuxiliary = singular ? 'have' : 'has';
      _add(
        questions,
        id: 'perfect-$verbIndex-$subjectIndex',
        level: AbuAlAreefLevel.intermediate,
        category: 'Present perfect',
        prompt: 'Complete: $subject ___ already ___ it. (${verb.base})',
        choices: [
          '$auxiliary ${verb.participle}',
          '$wrongAuxiliary ${verb.participle}',
          '$auxiliary ${verb.past}',
          'is ${verb.participle}',
        ],
        answer: '$auxiliary ${verb.participle}',
      );
      _add(
        questions,
        id: 'conditional-$verbIndex-$subjectIndex',
        level: AbuAlAreefLevel.distinguished,
        category: 'First conditional',
        prompt:
            'If $subject ${verb.base} today, what is the correct result clause?',
        choices: [
          '$subject will ${verb.base} tomorrow.',
          '$subject ${verb.past} tomorrow.',
          '$subject will ${verb.past} tomorrow.',
          '$subject ${verb.third} yesterday.',
        ],
        answer: '$subject will ${verb.base} tomorrow.',
      );
    }
  }

  for (var wordIndex = 0; wordIndex < _words.length; wordIndex++) {
    final entry = _words[wordIndex];
    for (var leadIndex = 0; leadIndex < _vocabularyLeads.length; leadIndex++) {
      final distractors = [
        _words[(wordIndex + 7) % _words.length].word,
        _words[(wordIndex + 19) % _words.length].word,
        _words[(wordIndex + 31) % _words.length].word,
      ];
      _add(
        questions,
        id: 'vocabulary-$wordIndex-$leadIndex',
        level: wordIndex < 20
            ? AbuAlAreefLevel.beginner
            : wordIndex < 40
            ? AbuAlAreefLevel.distinguished
            : AbuAlAreefLevel.legendary,
        category: 'Vocabulary',
        prompt: '${_vocabularyLeads[leadIndex]} "${entry.definition}"?',
        choices: [entry.word, ...distractors],
        answer: entry.word,
      );
    }
  }

  for (var verbIndex = 0; verbIndex < _verbs.length; verbIndex++) {
    final verb = _verbs[verbIndex];
    for (var objectIndex = 0; objectIndex < _objects.length; objectIndex++) {
      final object = _objects[objectIndex];
      final correct = 'The $object is ${verb.participle} every day.';
      _add(
        questions,
        id: 'passive-$verbIndex-$objectIndex',
        level: AbuAlAreefLevel.legendary,
        category: 'Passive voice',
        prompt:
            'Choose the correct passive form: People ${verb.base} the $object every day.',
        choices: [
          correct,
          'The $object ${verb.third} every day.',
          'The $object was ${verb.past} every day.',
          'The $object is ${verb.base} every day.',
        ],
        answer: correct,
      );
    }
  }
  assert(questions.length == 3000);
  return questions;
}

void _add(
  List<AbuAlAreefQuestion> target, {
  required String id,
  required AbuAlAreefLevel level,
  required String category,
  required String prompt,
  required List<String> choices,
  required String answer,
}) {
  final unique = choices.toSet().toList();
  while (unique.length < 4) {
    unique.add('None of these ${unique.length + 1}');
  }
  final shift = id.codeUnits.fold<int>(0, (sum, value) => sum + value) % 4;
  final rotated = [...unique.skip(shift), ...unique.take(shift)];
  target.add(
    AbuAlAreefQuestion(
      id: id,
      level: level,
      category: category,
      prompt: prompt,
      options: rotated,
      correctOption: rotated.indexOf(answer),
    ),
  );
}
