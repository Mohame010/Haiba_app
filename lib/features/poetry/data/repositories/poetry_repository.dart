import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../novels/domain/novel_entities.dart';

/// Repository for the Interactive English Poetry module.
/// Provides level-divided poems (Beginner A1-A2, Intermediate B1-B2, Advanced C1)
/// with full line-by-line translations, audio synthesis, and interactive vocabulary.
class PoetryRepository {
  PoetryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Curated educational English poems designed specifically for language learners,
  /// structured with CEFR levels, line-by-line translations, and vocabulary glossaries.
  static final List<Novel> _curatedPoems = [
    // ── BEGINNER (A1-A2) ──
    Novel(
      id: 'poem-beg-morning-sun',
      title: 'The Morning Sun',
      description:
          'قصيدة تعليمية مبسطة تصف إشراقة الصباح والأمل وبداية يوم دراسي جديد بنقاء وطاقة إيجابية.',
      level: 'beginner',
      coverUrl:
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&auto=format&fit=crop',
      isFree: true,
      chapters: const [
        NovelChapter(
          id: 'poem-beg-morning-sun-ch1',
          title: 'The Morning Sun',
          order: 1,
          text: '''The golden sun begins to rise,
It paints with light the morning skies.
A gentle breeze begins to blow,
The birds are singing soft and low.

Wake up today with happy eyes,
Where every dream and wonder lies.
We walk our path and learn anew,
The world is bright and fresh for you.''',
          translation: '''تبدأ الشمس الذهبية في الشروق،
وترسم بالضوء سماء الصباح.
يبدأ نسيم لطيف في الهبوب،
والطيور تغرد بصوت عذب وهادئ.

استيقظ اليوم بعيون سعيدة،
حيث تكمن كل الأحلام والروائع.
نسير في طريقنا ونتعلم من جديد،
فالعالم مشرق ومفعم بالنشاط لأجلك.''',
          audioUrl: '',
        ),
      ],
      wordDictionary: const {
        'golden': NovelWord(
          word: 'golden',
          arabicMeaning: 'ذهبي اللون / براق',
          contextMeaning: 'ذهبي ومشرق كالذهب',
          transcription: '/ˈɡoʊl.dən/',
          novelTitle: 'The Morning Sun',
          chapterNumber: 1,
        ),
        'gentle': NovelWord(
          word: 'gentle',
          arabicMeaning: 'لطيف / رقيق',
          contextMeaning: 'نسيم هادئ ولطيف',
          transcription: '/ˈdʒen.təl/',
          novelTitle: 'The Morning Sun',
          chapterNumber: 1,
        ),
        'breeze': NovelWord(
          word: 'breeze',
          arabicMeaning: 'نسيم عليل',
          contextMeaning: 'هواء خفيف منعش',
          transcription: '/briːz/',
          novelTitle: 'The Morning Sun',
          chapterNumber: 1,
        ),
        'anew': NovelWord(
          word: 'anew',
          arabicMeaning: 'من جديد / مجدداً',
          contextMeaning: 'نبدأ رحلة التعلم من جديد',
          transcription: '/əˈnuː/',
          novelTitle: 'The Morning Sun',
          chapterNumber: 1,
        ),
      },
    ),
    Novel(
      id: 'poem-beg-silent-garden',
      title: 'My Little Garden',
      description:
          'قصيدة ممتعة وبسيطة عن حديقة خضراء وأزهار تتفتح، مناسبة لبناء الحصيلة اللغوية الأساسية.',
      level: 'beginner',
      coverUrl:
          'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=600&auto=format&fit=crop',
      isFree: true,
      chapters: const [
        NovelChapter(
          id: 'poem-beg-silent-garden-ch1',
          title: 'My Little Garden',
          order: 1,
          text: '''In my garden green and wide,
Little flowers bloom inside.
Red and yellow, blue and white,
Dancing in the warm sunlight.

Water falls from morning rain,
Washing away every pain.
Nature grows with peaceful grace,
In this quiet, lovely place.''',
          translation: '''في حديقتي الخضراء الواسعة،
تتفتح زهور صغيرة في الأرجاء.
حمراء وصفراء، زرقاء وبيضاء،
ترقص في ضوء الشمس الدافئ.

يتساقط الماء من مطر الصباح،
ليغسل كل تعب وحزن بعيداً.
تنمو الطبيعة بسكينة وجمال،
في هذا المكان الهادئ البديع.''',
          audioUrl: '',
        ),
      ],
      wordDictionary: const {
        'bloom': NovelWord(
          word: 'bloom',
          arabicMeaning: 'يزدهر / يتفتح',
          contextMeaning: 'تتفتح الأزهار وتزهر',
          transcription: '/bluːm/',
          novelTitle: 'My Little Garden',
          chapterNumber: 1,
        ),
        'grace': NovelWord(
          word: 'grace',
          arabicMeaning: 'سكينة ورشاقة / جمال',
          contextMeaning: 'بجمال وسكينة ربانية',
          transcription: '/ɡreɪs/',
          novelTitle: 'My Little Garden',
          chapterNumber: 1,
        ),
      },
    ),

    // ── INTERMEDIATE (B1-B2) ──
    Novel(
      id: 'poem-int-whispers-wind',
      title: 'Whispers of the Wind',
      description:
          'قصيدة تأملية ملهمة بمستوى متوسط تتناول الاستماع لأصوات الطبيعة والتحلي بالثقة والشجاعة.',
      level: 'intermediate',
      coverUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&auto=format&fit=crop',
      isFree: true,
      chapters: const [
        NovelChapter(
          id: 'poem-int-whispers-wind-ch1',
          title: 'Whispers of the Wind',
          order: 1,
          text: '''Listen closely to the mountain breeze,
Moving softly through ancient trees.
It speaks of journeys far and wide,
Of oceans deep and stars that guide.

Do not fear the stormy night,
Behind the dark there waits the light.
For courage is a steady flame,
That remembers your true name.

Step forward with an open heart,
Every ending is a brand new start.
The world awaits your steady hand,
To leave your mark upon the sand.''',
          translation: '''استمع بانتباه لنسيم الجبال الشاهقة،
وهو ينساب برقة عبر الأشجار العتيقة.
يحدثنا عن رحلات امتدت عبر الآفاق البعيدة،
وعن محيطات عميقة ونجوم تهدي السائرين.

لا تخشَ ظلمة الليل العاصف،
فخلف كل ظلام ينتظر فجر من نور.
إذ إن الشجاعة شعلة راسخة لا تنطفئ،
تذكرك دائماً بجوهرك الحقيقي.

امضِ إلى الأمام بقلب منفتح،
فكل نهاية ما هي إلا بداية جديدة تماماً.
والعالم ينتظر عزيمتك الصادقة،
لتترك أثرك النبيل فوق رمال الحياة.''',
          audioUrl: '',
        ),
      ],
      wordDictionary: const {
        'ancient': NovelWord(
          word: 'ancient',
          arabicMeaning: 'عتيق / ضارب في القدم',
          contextMeaning: 'أشجار معمرة وقديمة',
          transcription: '/ˈeɪn.ʃənt/',
          novelTitle: 'Whispers of the Wind',
          chapterNumber: 1,
        ),
        'courage': NovelWord(
          word: 'courage',
          arabicMeaning: 'الشجاعة والجسارة',
          contextMeaning: 'شعلة الشجاعة الداخلية',
          transcription: '/ˈkɜːr.ɪdʒ/',
          novelTitle: 'Whispers of the Wind',
          chapterNumber: 1,
        ),
        'steady': NovelWord(
          word: 'steady',
          arabicMeaning: 'ثابت / راسخ',
          contextMeaning: 'شعلة راسخة وثابتة',
          transcription: '/ˈsted.i/',
          novelTitle: 'Whispers of the Wind',
          chapterNumber: 1,
        ),
      },
    ),
    Novel(
      id: 'poem-int-bridge-knowledge',
      title: 'The Bridge of Knowledge',
      description:
          'قصيدة شعرية ملهمة عن قوة القراءة والتعليم واللغة في بناء جسور التواصل بين العقول والحضارات.',
      level: 'intermediate',
      coverUrl:
          'https://images.unsplash.com/photo-1457369804613-52c61a468e7d?w=600&auto=format&fit=crop',
      isFree: false,
      chapters: const [
        NovelChapter(
          id: 'poem-int-bridge-knowledge-ch1',
          title: 'The Bridge of Knowledge',
          order: 1,
          text: '''A book can take you miles away,
Beyond the limits of the day.
With every word upon the page,
You walk across a different age.

Words are bridges built of thought,
Carrying truths so dearly bought.
They link the reader to the sage,
Across the river of time and age.

So turn the leaf and hold the pen,
And find your voice among all men.
For knowledge is the brightest crown,
That lifts the soul and tears doubt down.''',
          translation: '''يستطيع الكتاب أن يحملك أميالاً بعيدة،
متجاوزاً حدود يومك الحاضر.
ومع كل كلمة مدونة فوق صفحته،
تخطو سائراً عبر أزمنة وحقب مختلفة.

إن الكلمات جسور شيدتها الأفكار،
تحمل حقائق غالية ونفيسة.
تربط القارئ بالحكيم والمعلم،
عبر نهر الزمان والقرون الطويلة.

فاقلب الصفحة وأمسك بالقلم،
واكتشف صوتك وأثرك بين الجميع.
فالعلم والمعرفة هما التاج الأكثر بريقاً،
يرفع الروح عالياً ويهدم كل شك وظلام.''',
          audioUrl: '',
        ),
      ],
      wordDictionary: const {
        'sage': NovelWord(
          word: 'sage',
          arabicMeaning: 'الحكيم / العالم الفطن',
          contextMeaning: 'يربط القارئ بالشخص الحكيم',
          transcription: '/seɪdʒ/',
          novelTitle: 'The Bridge of Knowledge',
          chapterNumber: 1,
        ),
        'crown': NovelWord(
          word: 'crown',
          arabicMeaning: 'تاج الفخار والمجد',
          contextMeaning: 'أبهى وأسطع تاج للعقل',
          transcription: '/kraʊn/',
          novelTitle: 'The Bridge of Knowledge',
          chapterNumber: 1,
        ),
      },
    ),

    // ── ADVANCED (C1) ──
    Novel(
      id: 'poem-adv-echoes-silence',
      title: 'Echoes in the Silence',
      description:
          'قصيدة أدبية فلسفية رفيعة المستوى تستعرض فلسفة الزمن والذاكرة وقوة الفكر الإنساني الخالد.',
      level: 'advanced',
      coverUrl:
          'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600&auto=format&fit=crop',
      isFree: false,
      chapters: const [
        NovelChapter(
          id: 'poem-adv-echoes-silence-ch1',
          title: 'Echoes in the Silence',
          order: 1,
          text: '''Amidst the silent tapestry of night,
Where distant constellations weave their light,
The restless mind contemplates the deep,
Awake while all the weary shadows sleep.

Time flows relentless like a boundless tide,
No mortal hand can turn its course aside.
Yet in the realm of art and sculpted verse,
We capture fragments of the universe.

The transient hour fades into the past,
Yet noble thoughts eternally will last.
Within the quiet sanctuary of the soul,
The broken pieces once again turn whole.''',
          translation: '''في خضم النسيج الصامت لستار الليل،
حيث تنسج الكوكبات البعيدة خيوط ضيائها،
يتأمل العقل القلق أغوار الوجود العميقة،
يقظاً بينما تستسلم الظلال المنهكة للسبات.

يمضي الزمان بلا هوادة كمد بحري لا يحده شاطئ،
وما من يد بشرية بوسعها أن تحيد مساره المحتوم.
غير أننا في محراب الفن وشعر البيان المصقول،
نقتنص شذرات خالدة من هذا الكون الفسيح.

تتلاشى الساعات العابرة في دروب الماضي،
لكن الأفكار النبيلة تظل مخلدة أبد الدهر.
وداخل المحراب الهادئ لأعماق الروح،
تلتئم الأجزاء المتناثرة لتغدو كلاً متكاملاً من جديد.''',
          audioUrl: '',
        ),
      ],
      wordDictionary: const {
        'tapestry': NovelWord(
          word: 'tapestry',
          arabicMeaning: 'نسيج فني بديع / ستارة موشاة',
          contextMeaning: 'نسيج الليل المرصع بالنجوم',
          transcription: '/ˈtæp.ə.stri/',
          novelTitle: 'Echoes in the Silence',
          chapterNumber: 1,
        ),
        'relentless': NovelWord(
          word: 'relentless',
          arabicMeaning: 'لا هوادة فيه / مستمر بلا توقف',
          contextMeaning: 'الزمن الذي يمضي دون أن يوقفه شيء',
          transcription: '/rɪˈlent.ləs/',
          novelTitle: 'Echoes in the Silence',
          chapterNumber: 1,
        ),
        'transient': NovelWord(
          word: 'transient',
          arabicMeaning: 'عابر / زائل / قصير الأجل',
          contextMeaning: 'الساعات العابرة في الحياة',
          transcription: '/ˈtræn.zi.ənt/',
          novelTitle: 'Echoes in the Silence',
          chapterNumber: 1,
        ),
        'sanctuary': NovelWord(
          word: 'sanctuary',
          arabicMeaning: 'محراب / ملاذ آمن ومقدس',
          contextMeaning: 'الملاذ الهادئ داخل الروح',
          transcription: '/ˈsæŋk.tʃu.er.i/',
          novelTitle: 'Echoes in the Silence',
          chapterNumber: 1,
        ),
      },
    ),
  ];

  /// Returns curated poem by ID if matching.
  static Novel? getCuratedPoemById(String id) {
    try {
      return _curatedPoems.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Fetches poems filtered by level with pagination.
  Future<List<Novel>> fetchPoems({
    String? level,
    int offset = 0,
    int limit = 10,
  }) async {
    // 1. Check if Supabase has published poems
    try {
      var query = _client
          .from('novels')
          .select('*, novel_chapters(*)')
          .eq('is_published', true)
          .eq('category', 'poetry');

      if (level != null && level.isNotEmpty) {
        query = query.eq('level', level);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return rows
          .whereType<Map>()
          .map((row) => Novel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      rethrow;
    }
  }

  /// Fetches a single poem by its ID (from curated list or Supabase).
  Future<Novel?> fetchPoem(String poemId) async {
    try {
      final row = await _client
          .from('novels')
          .select('*, novel_chapters(*)')
          .eq('id', poemId)
          .eq('category', 'poetry')
          .maybeSingle();

      if (row != null) {
        return Novel.fromMap(row);
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }
}
