تم تعديل النظام ليتوافق مع الجداول الفعلية عندك.

الذي تغير:
- الاعتماد على online_price بدل price للحصص.
- دعم علاقتي الكورس مع الحصص:
  - lectures.course_id
  - course_lectures
- مزامنة العلاقتين تلقائيًا.
- عند الاشتراك في كورس تُفتح كل حصصه.
- إضافة قسم مستقل باسم «اشتراكاتي».
- فصل الكورسات غير المشترَك بها في «كورسات متاحة للاشتراك».
- عرض عدد حصص الكورس الحقيقي داخل العرض.
- عند الضغط على العرض تظهر أسماء حصص الكورس.
- إصلاح صلاحيات الاشتراكات القديمة تلقائيًا.
1. شغّل Migration الجديدة
[202611050001_sync_course_lectures.sql (line 1)](J:/from-desktop-projects/q360education/q360education/supabase/migrations/202611050001_sync_course_lectures.sql:1)

هذه الـmigration تقوم بـ:
- إضافة course_id و`online_price` إذا لم يكونا موجودين.
- نقل كل علاقات lectures.course_id إلى course_lectures.
- إنشاء Trigger لمزامنة أي حصة جديدة تلقائيًا.
- إصلاح صلاحيات الاشتراكات القديمة.
- إضافة RPC للاشتراك في الكورسات المجانية.
2. لماذا العرض كان يقول 0 محتوى؟
وجود حصص مرتبطة بالكورس لا يربط العرض بالكورس تلقائيًا. يجب أن يحتوي العرض على صف في:
commerce_offer_items
اربط العرض بالكورس بهذا SQL:
insert into public.commerce_offer_items (
  offer_id,
  item_type,
  course_id,
  access_duration_days,
  view_limit,
  sort_order
)
select
  'OFFER_UUID_HERE',
  'course',
  'COURSE_UUID_HERE',
  30,
  null,
  1
where not exists (
  select 1
  from public.commerce_offer_items
  where offer_id = 'OFFER_UUID_HERE'
    and course_id = 'COURSE_UUID_HERE'
);
بعد ذلك سيحسب التطبيق عدد الحصص الموجودة داخل الكورس، سواء كانت مرتبطة من course_lectures أو lectures.course_id.

للتأكد من الربط:
select
  o.title as offer_title,
  c.title as course_title,
  count(distinct l.id) as lectures_count
from public.commerce_offers o
join public.commerce_offer_items oi on oi.offer_id = o.id
join public.courses c on c.id = oi.course_id
left join public.lectures l on
  l.course_id = c.id
  or exists (
    select 1
    from public.course_lectures cl
    where cl.course_id = c.id
      and cl.lecture_id = l.id
  )
where o.id = 'OFFER_UUID_HERE'
group by o.title, c.title;
3. ظهور الكورس في «اشتراكاتي»
الكورس سيظهر تلقائيًا بعد:
- نجاح الدفع وتأكيد الـWebhook.
- أو تفعيل كود يحتوي على الكورس.
- أو الاشتراك في كورس مجاني.
التعديل في [lectures_list_screen.dart (line 567)](J:/from-desktop-projects/q360education/q360education/lib/features/lectures/presentation/screens/lectures_list_screen.dart:567).
4. أعد نشر دالة إنشاء الفاتورة
لأنها أصبحت تقرأ online_price:
supabase functions deploy fawaterak-create-invoice
ثم أوقف التطبيق وشغّله من جديد.

التحقق النهائي:
Flutter Analyze: No issues found
Tests: 30/30 passed