# تشغيل الربط — روسم للتجميل + مواعيد المركز IBRA

هذا الدليل يفعّل الربط بين **تطبيق الزبائن «روسم للتجميل»** و**نسخة المركز «مواعيد المركز IBRA»**.
كل الخطوات مجانية ضمن الخطط المجانية لـ Supabase و Firebase. خذ وقتك، كل خطوة مرة وحدة بس.

> بدون هذي الخطوات التطبيق يشتغل بـ **وضع العرض** (بيانات تجريبية) حتى تشوف شكله.

---

## 1) قاعدة البيانات — Supabase

1. سوّ حساب على https://supabase.com واضغط **New project** (اختار أقرب منطقة، مثلاً Frankfurt).
2. من **SQL Editor → New query** الصق محتوى `backend/supabase/schema.sql` واضغط **Run**.
3. من **Authentication → Sign In / Providers**:
   - فعّل **Allow anonymous sign-ins** (حتى الزبون يدخل بدون كلمة سر).
   - طفّي **Confirm email** (حتى حسابات الموظفين تشتغل فوراً).
4. من **Project Settings → API** انسخ:
   - `Project URL`
   - `anon public key`

## 2) الإشعارات — Firebase

1. سوّ مشروع على https://console.firebase.google.com
2. ضيف **3 تطبيقات** للمشروع:
   - Android بالمعرّف `com.ibraprogram.rawsam` (تطبيق الزبائن)
   - Android بالمعرّف `com.ibraprogram.ibra_center` (نسخة المركز)
   - iOS بالمعرّف `com.ibraprogram.rawsam` (والثاني `com.ibraprogram.ibraCenter` إذا تريد المركز على آيفون)
   - ما تحتاج تنزّل ملفات google-services — بس انسخ الأرقام من الخطوة الجاية.
3. من **Project settings → General** انسخ: `Web API Key`، `Project ID`، `Project number` (هذا هو Sender ID)، و `App ID` لكل تطبيق.
4. من **Project settings → Service accounts → Generate new private key** نزّل ملف JSON (نحتاجه بالخطوة 3).
5. للآيفون: من **Project settings → Cloud Messaging** ارفع مفتاح APNs (من حساب مطوّر آبل). بدونه إشعارات الآيفون ما توصل.

## 3) دالة الإرسال — Supabase Edge Function

1. من Supabase: **Edge Functions → Deploy a new function → Via Editor**، سمّها `push`.
2. الصق محتوى `backend/supabase/functions/push/index.ts` واضغط **Deploy**.
3. من إعدادات الدالة طفّي **Enforce JWT verification** (الدالة محمية بكلمة سر خاصة بيها).
4. من **Edge Functions → Secrets** ضيف:
   - `FIREBASE_SERVICE_ACCOUNT` = محتوى ملف JSON كامل من Firebase
   - `PUSH_HOOK_SECRET` = أي كلمة سر طويلة تختارها
5. من **SQL Editor** الصق محتوى `backend/supabase/push.sql` وشغّله، وبعدها شغّل هذا السطر بقيمك:
   ```sql
   update public.push_config
   set url = 'https://XXXX.supabase.co/functions/v1/push', secret = 'نفس-كلمة-السر'
   where id = 1;
   ```

## 4) أسرار GitHub (حتى ينبني التطبيق مربوط)

بمستودع `ibra-booking`: **Settings → Secrets and variables → Actions → New repository secret**

| الاسم | القيمة |
|---|---|
| `RAWSAM_SUPABASE_URL` | Project URL |
| `RAWSAM_SUPABASE_ANON_KEY` | anon public key |
| `RAWSAM_FB_API_KEY` | Web API Key |
| `RAWSAM_FB_SENDER_ID` | Project number |
| `RAWSAM_FB_PROJECT_ID` | Project ID |
| `RAWSAM_FB_APP_ID_ANDROID` | App ID لتطبيق الزبائن أندرويد |
| `RAWSAM_FB_APP_ID_IOS` | App ID لتطبيق الزبائن آيفون |
| `RAWSAM_FB_APP_ID_CENTER_ANDROID` | App ID لنسخة المركز أندرويد |
| `RAWSAM_FB_APP_ID_CENTER_IOS` | App ID لنسخة المركز آيفون (اختياري) |

بعدها ارفع أي تعديل (أو من **Actions** شغّل البناء يدوياً) وتنبني النسخ مربوطة.

> نسخة المركز تقدر تنربط حتى بدون إعادة البناء: **المزيد ← تطبيق الزبائن** واكتب الـ URL والمفتاح.

## 5) أول تشغيل بالمركز

1. افتح **مواعيد المركز IBRA ← المزيد ← تطبيق الزبائن**.
2. اختار **أول مرة (حساب المدير)** — أول حساب يصير المدير.
3. **معلومات المركز**: وكف بباب المركز واضغط **موقعي الحالي** ثم حفظ (مهم لعروض القرب والخرائط).
4. سجّل **صوت الترحيب** و**خطوات المول** بصوت البنت.
5. **مزامنة الخدمات** حتى تطلع خدماتك وأسعارك.
6. **حسابات الموظفين**: ضيف محمد وباقي الموظفين.
7. **عروض القرب والجيران**: ضيف عرض القرب (مثلاً خصم 10%).

---

## كيف يشتغل كل جزء

| الميزة | الطريقة |
|---|---|
| المحادثة | محادثة وحدة لكل زبون ويا المركز. كل الموظفين يشوفونها، و«فلان يرد هسه» يمنع ردّين بنفس الوقت. اسم الموظف يطلع للزبون حسب الإعداد، وداخلياً ينحفظ دائماً. |
| الحجز | من المحادثة ← أيقونة التقويم ← نفس نموذج الحجز (خدمة، موظف، أوقات فارغة) ← ينحفظ بجدول الموظف ويوصل للزبون كبطاقة + إشعار + تذكير قبل ساعتين وربع ساعة. |
| المنشورات | تلصق رابط منشور انستا/فيس عام ← يطلع داخل التطبيق بالتضمين الرسمي، بدون أي ربط بحسابك ← إشعار لكل الزبائن بالصوت اللي تختاره. |
| عروض القرب | الجهاز نفسه يحس من يدخل الزبون دائرة المركز (الموقع ما يوصل للسيرفر) ← تنبيه «مدام صرت قريب…» ← من يفتحه ينصرف كوبون. يحترم الساعات والتكرار اللي تحددها. |
| عروض الجيران | الزبون يختار أو يحدد تلقائياً إذا بيته قريب (ننحفظ بس الشريحة) ← كل يوم 10 الصبح يتوزع العرض للمستحقين حسب التكرار. |
| الكوبون | كود `RSM-XXXXX` + باركود ← الموظف يمسحه ← «استخدام» مرة وحدة، وينسجل منو استخدمه ومتى. |
| الأصوات | لكل نوع إشعار صوت مدمج بالتطبيق (`apps/rawsam/assets/sounds`). لتبديلها بصوت عراقي ضع ملفات WAV بنفس الأسماء. |

برمجة وتطوير ابراهيم الخزرجي — https://ibraprogram.netlify.app/
