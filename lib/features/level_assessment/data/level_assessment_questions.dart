import '../domain/entities/level_assessment.dart';

const levelAssessmentQuestions = <LevelAssessmentQuestion>[
  LevelAssessmentQuestion(
    id: 'p1',
    skill: AssessmentSkill.pronunciation,
    prompt: 'Which word has the same vowel sound as "cat"?',
    options: ['Car', 'Map', 'Call', 'Cake'],
    correctOption: 1,
    explanation: 'Cat and map share the short /a/ sound.',
  ),
  LevelAssessmentQuestion(
    id: 'p2',
    skill: AssessmentSkill.pronunciation,
    prompt: 'Which word starts with a different sound?',
    options: ['Chair', 'Child', 'Chemistry', 'Choose'],
    correctOption: 2,
    explanation: 'Chemistry starts with /k/; the others start with /tʃ/.',
  ),
  LevelAssessmentQuestion(
    id: 'p3',
    skill: AssessmentSkill.pronunciation,
    prompt: 'Which word contains a silent letter?',
    options: ['Know', 'Grow', 'Show', 'Slow'],
    correctOption: 0,
    explanation: 'The letter k in "know" is silent.',
  ),
  LevelAssessmentQuestion(
    id: 'p4',
    skill: AssessmentSkill.pronunciation,
    prompt: 'Where is the stress in the word "important"?',
    options: ['IM-port-ant', 'im-POR-tant', 'im-por-TANT', 'All are correct'],
    correctOption: 1,
    explanation: 'The main stress is on the second syllable: im-POR-tant.',
  ),
  LevelAssessmentQuestion(
    id: 'p5',
    skill: AssessmentSkill.pronunciation,
    prompt: 'Which word ends with the /t/ sound?',
    options: ['Played', 'Wanted', 'Worked', 'Needed'],
    correctOption: 2,
    explanation: 'The -ed ending in "worked" is pronounced /t/.',
  ),
  LevelAssessmentQuestion(
    id: 'p6',
    skill: AssessmentSkill.pronunciation,
    prompt: 'Which pair is pronounced differently?',
    options: ['Sea / see', 'Right / write', 'Though / through', 'Son / sun'],
    correctOption: 2,
    explanation: 'Though and through have different vowel sounds.',
  ),
  LevelAssessmentQuestion(
    id: 'r1',
    skill: AssessmentSkill.reading,
    contextText:
        'Mona gets up at seven. She eats breakfast, then walks to school.',
    prompt: 'How does Mona go to school?',
    options: ['By bus', 'On foot', 'By car', 'By bike'],
    correctOption: 1,
    explanation: '"Walks to school" means she goes on foot.',
  ),
  LevelAssessmentQuestion(
    id: 'r2',
    skill: AssessmentSkill.reading,
    contextText:
        'The museum is closed on Mondays, but it opens from 9 a.m. to 5 p.m. on other days.',
    prompt: 'When can you visit the museum?',
    options: [
      'Monday morning',
      'Tuesday at 3 p.m.',
      'Friday at 7 p.m.',
      'Every night',
    ],
    correctOption: 1,
    explanation: 'Tuesday at 3 p.m. is within the stated opening hours.',
  ),
  LevelAssessmentQuestion(
    id: 'r3',
    skill: AssessmentSkill.reading,
    contextText:
        'Although the match was difficult, the team remained confident and eventually won.',
    prompt: 'What does "eventually" mean here?',
    options: ['At first', 'In the end', 'Suddenly', 'Probably'],
    correctOption: 1,
    explanation: 'Eventually means after some time, or in the end.',
  ),
  LevelAssessmentQuestion(
    id: 'r4',
    skill: AssessmentSkill.reading,
    contextText:
        'Online learning offers flexibility; however, students must manage their time carefully to succeed.',
    prompt: 'What is the main idea?',
    options: [
      'Online learning is always easy.',
      'Students should avoid online courses.',
      'Flexibility requires good time management.',
      'Classrooms are no longer useful.',
    ],
    correctOption: 2,
    explanation:
        'The sentence balances flexibility with the need for time management.',
  ),
  LevelAssessmentQuestion(
    id: 'r5',
    skill: AssessmentSkill.reading,
    contextText:
        'The proposal was initially rejected. Nevertheless, the committee agreed to reconsider it after receiving new evidence.',
    prompt: 'Why did the committee reconsider the proposal?',
    options: [
      'It was popular.',
      'New evidence arrived.',
      'The rules changed.',
      'The proposal was shorter.',
    ],
    correctOption: 1,
    explanation: 'The new evidence caused the committee to reconsider.',
  ),
  LevelAssessmentQuestion(
    id: 'r6',
    skill: AssessmentSkill.reading,
    contextText:
        'Far from being a weakness, asking thoughtful questions can reveal intellectual curiosity and strengthen understanding.',
    prompt: 'What can be inferred from the sentence?',
    options: [
      'Questions show a lack of knowledge.',
      'Curiosity can improve learning.',
      'Only teachers should ask questions.',
      'Understanding never changes.',
    ],
    correctOption: 1,
    explanation:
        'The writer presents thoughtful questioning as a way to learn more deeply.',
  ),
  LevelAssessmentQuestion(
    id: 'w1',
    skill: AssessmentSkill.writing,
    prompt: 'Choose the correct sentence.',
    options: [
      'She go to school.',
      'She goes to school.',
      'She going to school.',
      'She gone to school.',
    ],
    correctOption: 1,
    explanation: 'With she/he/it in the present simple, the verb takes -s.',
  ),
  LevelAssessmentQuestion(
    id: 'w2',
    skill: AssessmentSkill.writing,
    prompt: 'Complete: I have lived here ___ 2020.',
    options: ['for', 'since', 'from', 'at'],
    correctOption: 1,
    explanation: 'Use "since" with a specific starting point.',
  ),
  LevelAssessmentQuestion(
    id: 'w3',
    skill: AssessmentSkill.writing,
    prompt: 'Choose the best punctuation.',
    options: [
      'After dinner we watched a film.',
      'After dinner, we watched a film.',
      'After, dinner we watched a film.',
      'After dinner we, watched a film.',
    ],
    correctOption: 1,
    explanation: 'An introductory phrase is followed by a comma.',
  ),
  LevelAssessmentQuestion(
    id: 'w4',
    skill: AssessmentSkill.writing,
    prompt: 'Choose the sentence with the correct conditional.',
    options: [
      'If it rains, we will stay home.',
      'If it will rain, we stay home.',
      'If it raining, we will stay home.',
      'If it rain, we stayed home.',
    ],
    correctOption: 0,
    explanation:
        'The first conditional uses present simple after if and will in the result.',
  ),
  LevelAssessmentQuestion(
    id: 'w5',
    skill: AssessmentSkill.writing,
    prompt: 'Choose the clearest formal sentence.',
    options: [
      'The results are kind of good.',
      'The results indicate a significant improvement.',
      'The results are super amazing.',
      'The results got way better and stuff.',
    ],
    correctOption: 1,
    explanation: 'It is precise, formal, and grammatically complete.',
  ),
  LevelAssessmentQuestion(
    id: 'w6',
    skill: AssessmentSkill.writing,
    prompt:
        'Choose the best connector: The task was demanding; ___, she completed it on time.',
    options: ['therefore', 'however', 'because', 'unless'],
    correctOption: 1,
    explanation:
        '"However" introduces the contrast between difficulty and completion.',
  ),
];
