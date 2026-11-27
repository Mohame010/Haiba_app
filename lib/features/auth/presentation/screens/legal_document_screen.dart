import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

enum LegalDocumentType { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  bool get _isPrivacy => type == LegalDocumentType.privacy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isPrivacy ? 'سياسة الخصوصية' : 'الشروط والأحكام',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'IBM',
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
          child: _isPrivacy
              ? const _PrivacyPolicyContent()
              : const _TermsContent(),
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;

  const _LegalSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'IBM',
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            body,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.sp,
              height: 1.8,
              color: AppColors.textSecondary,
              fontFamily: 'IBM',
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: 'سياسة الخصوصية',
          body:
              'توضح هذه السياسة كيف يجمع تطبيق هيبة بياناتك ويستخدمها ويحميها عند استخدام خدمات التعلم، الاختبارات، الإشعارات، تنزيل المحتوى وعمليات الدفع.\n\nآخر تحديث: 7 نوفمبر 2026\nينطبق على تطبيق هيبة',
        ),
        _LegalSection(
          title: '1. نطاق هذه السياسة',
          body:
              'تنطبق هذه السياسة على تطبيق هيبة والخدمات المرتبطة به. باستخدام التطبيق أو إنشاء حساب، فإنك تقر بقراءة هذه السياسة. إذا كنت ولي أمر لطالب قاصر، يرجى مراجعتها نيابة عنه.',
        ),
        _LegalSection(
          title: '2. البيانات التي نجمعها',
          body:
              'بيانات الحساب والملف التعليمي:\n• الاسم، رقم الهاتف، تاريخ الميلاد، المرحلة والصف الدراسي.\n• بيانات تسجيل الدخول والتحقق من رقم الهاتف.\n• حالة الحساب والاشتراكات والمحتوى المتاح للطالب.\n\nبيانات التعلم والاستخدام:\n• الدروس المشاهدة، موضع استكمال الفيديو، تقدم التعلم والمحتوى المحمّل.\n• إجابات الاختبارات، الدرجات، المحاولات، وترتيب لوحة المتصدرين عند توفرها.\n• الملاحظات والتعليقات التوضيحية التي تحفظها محليًا داخل المستندات.\n\nبيانات الجهاز والإشعارات:\nقد نجمع معرّف تثبيت عشوائي، اسم أو طراز الجهاز، نظام التشغيل ورمز Firebase Cloud Messaging لربط الحساب بجهازك، حماية الجلسات وإرسال الإشعارات.\n\nالموقع: لا يستخدم الإصدار الحالي من التطبيق موقعك الجغرافي لتقديم خدماته.',
        ),
        _LegalSection(
          title: '3. كيف نستخدم البيانات',
          body:
              '• إنشاء الحساب والتحقق منه وتأمين تسجيل الدخول.\n• تخصيص المحتوى حسب المرحلة والصف الدراسي.\n• تشغيل الدروس والاختبارات وحفظ التقدم وإتاحة المحتوى دون اتصال.\n• إرسال إشعارات تعليمية وتشغيلية وإشعارات تقدم التنزيل.\n• منع إساءة الاستخدام، حماية حقوق المحتوى، تشخيص الأعطال وتحسين الخدمة.\n• الامتثال للالتزامات القانونية وحل النزاعات.',
        ),
        _LegalSection(
          title: '4. مشاركة البيانات ومقدمو الخدمة',
          body:
              'لا نبيع بياناتك الشخصية. نشارك الحد الأدنى اللازم فقط مع مقدمي خدمات يساعدوننا في تشغيل التطبيق، ومنهم:\n\n• Supabase: المصادقة، قاعدة البيانات، التخزين والوظائف الخلفية.\n• Google Firebase: إرسال الإشعارات وتشغيل خدمات التطبيق الأساسية.\n• مزودو الاستضافة وتوصيل المحتوى: بث وتنزيل المواد التعليمية.\n\nقد نفصح عن معلومات عندما يفرض القانون ذلك، أو لحماية المستخدمين وحقوقنا وأمن الخدمة. قد تُعالج البيانات في دول توجد بها خوادم مقدمي الخدمة، مع تطبيق وسائل حماية مناسبة.',
        ),
        _LegalSection(
          title: '5. الاحتفاظ بالبيانات وأمنها',
          body:
              'نحتفظ بالبيانات طوال مدة نشاط حسابك وبالقدر اللازم لتقديم الخدمة، ثم نحذفها أو نخفي هويتها عندما تنتفي الحاجة، مع مراعاة متطلبات المحاسبة ومكافحة الاحتيال والالتزامات القانونية. قد تبقى النسخ الاحتياطية لمدة محدودة قبل حذفها دوريًا.\n\nنستخدم وسائل حماية تقنية وتنظيمية معقولة، مثل اتصالات مشفرة وضوابط وصول. ومع ذلك، لا توجد وسيلة نقل أو تخزين إلكتروني آمنة بنسبة 100%.',
        ),
        _LegalSection(
          title: '6. اختياراتك وحقوقك وحذف الحساب',
          body:
              '• يمكنك مراجعة بعض بيانات الملف الشخصي داخل التطبيق.\n• يمكنك تعطيل الإشعارات من إعدادات جهازك.\n• يمكنك حذف المحتوى الذي نزلته محليًا من داخل التطبيق أو بحذف بيانات التطبيق.\n• يمكنك طلب الوصول إلى بياناتك أو تصحيحها أو حذف حسابك وبياناته، وفقًا للقانون.\n\nلطلب حذف الحساب: افتح التطبيق ثم انتقل إلى الملف الشخصي ← الدعم والتواصل، وأرسل طلبًا بعنوان «حذف الحساب» مع رقم الهاتف المسجل. سنتحقق من ملكية الحساب قبل التنفيذ، وقد نحتفظ بسجلات محدودة يفرضها القانون.',
        ),
        _LegalSection(
          title: '7. خصوصية الطلاب القُصّر',
          body:
              'صُمم التطبيق لخدمة الطلاب، وقد يستخدمه أشخاص دون سن الرشد. يجب أن ينشئ القاصر حسابه ويستخدم الخدمات بموافقة ولي الأمر أو الوصي وفق القانون المحلي. نجمع البيانات اللازمة لتقديم التعليم وتأمين الحساب فقط، ولا نستخدم بيانات الطلاب القُصّر للإعلانات الموجهة. يمكن لولي الأمر التواصل معنا لمراجعة بيانات القاصر أو تصحيحها أو طلب حذفها.',
        ),
        _LegalSection(
          title: '9. تواصل معنا',
          body:
              'للاستفسارات المتعلقة بالخصوصية أو ممارسة حقوقك، تواصل مع فريق هيبة من خلال قسم الملف الشخصي ← الدعم والتواصل داخل التطبيق. اذكر أن طلبك متعلق بالخصوصية حتى يتم توجيهه بشكل صحيح.',
        ),
      ],
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: 'الشروط والأحكام',
          body:
              'باستخدام تطبيق هيبة أو إنشاء حساب، فإنك توافق على الالتزام بهذه الشروط والأحكام. إذا كنت طالبًا قاصرًا، يجب أن يتم استخدام التطبيق بموافقة ولي الأمر أو الوصي.',
        ),
        _LegalSection(
          title: 'استخدام التطبيق',
          body:
              'يُستخدم التطبيق للتعلم والاختبارات والوصول إلى المحتوى التعليمي. يجب إدخال بيانات صحيحة، والحفاظ على سرية بيانات تسجيل الدخول، وعدم مشاركة الحساب أو استخدام التطبيق بطريقة تضر بالمستخدمين أو الخدمة.',
        ),
        _LegalSection(
          title: 'المحتوى والملكية الفكرية',
          body:
              'جميع الدروس والاختبارات والمواد المتاحة داخل التطبيق مملوكة لهيبة أو للجهات المرخصة لها. لا يجوز نسخها أو إعادة نشرها أو بيعها أو استخدامها خارج التطبيق دون إذن مسبق.',
        ),
        _LegalSection(
          title: 'إيقاف الحساب والتعديلات',
          body:
              'يجوز لنا تعليق أو إيقاف الحساب عند مخالفة هذه الشروط أو إساءة استخدام الخدمة. قد نحدّث هذه الشروط عند الحاجة، وسيظهر تاريخ آخر تحديث داخل التطبيق.',
        ),
        _LegalSection(
          title: 'تواصل معنا',
          body:
              'للاستفسارات أو طلبات الدعم، انتقل إلى الملف الشخصي ← الدعم والتواصل داخل التطبيق.',
        ),
      ],
    );
  }
}

class _LegacyTermsContent extends StatelessWidget {
  const _LegacyTermsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalSection(
          title: 'الشروط والأحكام',
          body:
              'باستخدام تطبيق هيبة أو إنشاء حساب، فإنك توافق على الالتزام بهذه الشروط والأحكام. إذا كنت طالبًا قاصرًا، يجب أن يتم استخدام التطبيق بموافقة ولي الأمر أو الوصي.',
        ),
        _LegalSection(
          title: 'استخدام التطبيق',
          body:
              'يُستخدم التطبيق للتعلم والاختبارات والوصول إلى المحتوى التعليمي. يجب إدخال بيانات صحيحة، والحفاظ على سرية بيانات تسجيل الدخول، وعدم مشاركة الحساب أو استخدام التطبيق بطريقة تضر بالمستخدمين أو الخدمة.',
        ),
        _LegalSection(
          title: 'المحتوى والملكية الفكرية',
          body:
              'جميع الدروس والاختبارات والمواد المتاحة داخل التطبيق مملوكة لهيبة أو للجهات المرخصة لها. لا يجوز نسخها أو إعادة نشرها أو بيعها أو استخدامها خارج التطبيق دون إذن مسبق.',
        ),
        _LegalSection(
          title: 'الاشتراكات والمدفوعات',
          body:
              'قد تتطلب بعض الخدمات اشتراكًا أو دفعًا. تظهر تفاصيل السعر والمدة قبل إتمام العملية، وتخضع عمليات الدفع لسياسات مزود الدفع المعتمد.',
        ),
        _LegalSection(
          title: 'إيقاف الحساب والتعديلات',
          body:
              'يجوز لنا تعليق أو إيقاف الحساب عند مخالفة هذه الشروط أو إساءة استخدام الخدمة. قد نحدّث هذه الشروط عند الحاجة، وسيظهر تاريخ آخر تحديث داخل التطبيق.',
        ),
        _LegalSection(
          title: 'تواصل معنا',
          body:
              'للاستفسارات أو طلبات الدعم، انتقل إلى الملف الشخصي ← الدعم والتواصل داخل التطبيق.',
        ),
      ],
    );
  }
}
