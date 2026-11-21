-- =====================================================================
-- روسم للتجميل — قاعدة البيانات المشتركة بين تطبيق الزبائن ونسخة المركز
-- (مواعيد المركز IBRA). شغّل هذا الملف مرة واحدة في Supabase:
--   Dashboard → SQL Editor → New query → الصق المحتوى → Run
-- يمكن تشغيله أكثر من مرة بأمان (IF NOT EXISTS / OR REPLACE).
-- برمجة وتطوير ابراهيم الخزرجي
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- الموظفون (حسابات بريد/كلمة مرور تنشأ من لوحة Supabase → Authentication)
-- ---------------------------------------------------------------------
create table if not exists public.staff_members (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  role         text not null default 'staff' check (role in ('admin','staff')),
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from staff_members where user_id = auth.uid() and active);
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from staff_members where user_id = auth.uid() and active and role = 'admin');
$$;

create or replace function public.staff_name(uid uuid) returns text
language sql stable security definer set search_path = public as $$
  select display_name from staff_members where user_id = uid;
$$;

-- ---------------------------------------------------------------------
-- إعدادات المركز (صف واحد)
-- ---------------------------------------------------------------------
create table if not exists public.center_settings (
  id                    int primary key default 1 check (id = 1),
  name                  text not null default 'روسم للتجميل',
  phone                 text not null default '07718814000',
  address               text not null default 'بغداد — الكرادة داخل، شارع سبع قصور، فرحان مول',
  lat                   double precision not null default 33.3060,
  lng                   double precision not null default 44.4290,
  show_staff_names      boolean not null default false,  -- إظهار اسم من رد للزبون
  welcome_voice_url     text,                            -- صوت الترحيب عند «وصّلني»
  arrival_voice_url     text,                            -- صوت «وصلتي»
  working_hours         text not null default 'السبت – الخميس، 10 صباحاً – 9 مساءً',
  -- عروض القرب
  proximity_enabled     boolean not null default true,
  proximity_radius_m    int not null default 500 check (proximity_radius_m between 150 and 5000),
  proximity_from_min    int not null default 600,   -- 10:00 صباحاً (دقائق من منتصف الليل، بتوقيت بغداد)
  proximity_to_min      int not null default 1260,  -- 9:00 مساءً
  proximity_cooldown_d  int not null default 7,     -- مرة كل 7 أيام لنفس الزبون كحد أقصى
  min_app_build         int not null default 0,     -- لإجبار تحديث النسخ القديمة جداً
  latest_apk_url        text,                       -- رابط آخر APK لنسخة الموقع
  latest_apk_build      int not null default 0,
  updated_at            timestamptz not null default now()
);
insert into public.center_settings (id) values (1) on conflict (id) do nothing;

-- خطوات الوصول داخل المول حتى باب المركز (نص + صوت)
create table if not exists public.mall_steps (
  id        bigserial primary key,
  sort      int not null default 0,
  text      text not null,
  voice_url text
);

-- ---------------------------------------------------------------------
-- الزبائن (حساب مجهول يُنشأ تلقائياً + الاسم والرقم)
-- ---------------------------------------------------------------------
create table if not exists public.customers (
  id                uuid primary key references auth.users(id) on delete cascade,
  name              text not null default '',
  phone             text not null default '',
  neighbor_tier     text check (neighbor_tier in ('building','near','area')),  -- يُحسب على جهاز الزبون، لا نخزن موقعه
  proximity_on      boolean not null default false,
  promo_opt_in      boolean not null default true,    -- إشعارات العروض (يقدر يطفيها)
  app_build         int not null default 0,
  platform          text,
  created_at        timestamptz not null default now(),
  last_seen_at      timestamptz not null default now()
);

create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null check (kind in ('customer','staff')),
  platform   text,
  updated_at timestamptz not null default now()
);
create index if not exists device_tokens_user on public.device_tokens(user_id);

-- ---------------------------------------------------------------------
-- الخدمات والموظفون كما يراهم الزبون (تُزامَن من نسخة المركز)
-- ---------------------------------------------------------------------
create table if not exists public.public_services (
  id           bigint primary key,       -- نفس رقم الخدمة في نسخة المركز
  name         text not null,
  duration_min int not null default 30,
  price        numeric not null default 0,
  color        bigint not null default 4282220543,
  sort         int not null default 0,
  active       boolean not null default true
);

-- ---------------------------------------------------------------------
-- المحادثات: محادثة واحدة لكل زبون مع المركز
-- ---------------------------------------------------------------------
create table if not exists public.conversations (
  id                  uuid primary key default gen_random_uuid(),
  customer_id         uuid not null unique references public.customers(id) on delete cascade,
  last_message        text not null default '',
  last_message_at     timestamptz not null default now(),
  unread_staff        int not null default 0,
  unread_customer     int not null default 0,
  handling_staff      uuid references auth.users(id) on delete set null,  -- «فلان يرد هسه»
  handling_until      timestamptz,
  created_at          timestamptz not null default now()
);
create index if not exists conversations_last on public.conversations(last_message_at desc);

create table if not exists public.messages (
  id              bigserial primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender          text not null check (sender in ('customer','staff','system')),
  staff_user      uuid references auth.users(id) on delete set null,  -- داخلي: من رد فعلاً (يُحفظ دائماً)
  display_name    text,          -- ما يراه الزبون: اسم الموظف إن كان الإعداد مفعلاً وإلا فارغ
  kind            text not null default 'text' check (kind in ('text','image','booking','coupon')),
  body            text not null default '',
  image_url       text,
  ref_id          text,          -- رقم الحجز أو الكوبون للبطاقات
  created_at      timestamptz not null default now()
);
create index if not exists messages_conv on public.messages(conversation_id, id);

-- الإبلاغ عن محادثة (متطلب المتاجر للمحتوى بين المستخدمين)
create table if not exists public.reports (
  id              bigserial primary key,
  conversation_id uuid references public.conversations(id) on delete cascade,
  reporter        uuid references auth.users(id) on delete cascade,
  reason          text not null default '',
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- الحجوزات كما يراها الزبون (الحجز الكامل يبقى في جدول الموظف بالمركز)
-- ---------------------------------------------------------------------
create table if not exists public.bookings (
  id                   uuid primary key default gen_random_uuid(),
  customer_id          uuid not null references public.customers(id) on delete cascade,
  service_name         text not null default '',
  staff_name           text not null default '',
  start_at             timestamptz not null,
  end_at               timestamptz not null,
  price                numeric not null default 0,
  status               text not null default 'confirmed' check (status in ('confirmed','cancelled','completed','postponed')),
  notes                text not null default '',
  local_appointment_id bigint,         -- رقم الحجز في جهاز المركز
  created_by           uuid references auth.users(id) on delete set null,
  created_at           timestamptz not null default now()
);
create index if not exists bookings_customer on public.bookings(customer_id, start_at);

-- ---------------------------------------------------------------------
-- المنشورات (رابط انستا/فيس يُعرض داخل التطبيق) والعروض
-- ---------------------------------------------------------------------
create table if not exists public.posts (
  id          bigserial primary key,
  kind        text not null default 'post' check (kind in ('post','offer')),
  url         text,                   -- رابط المنشور (انستغرام/فيسبوك) — اختياري
  platform    text check (platform in ('instagram','facebook','other')),
  title       text not null default '',
  body        text not null default '',
  image_url   text,
  sound       text not null default 'rs_post',
  notify      boolean not null default true,
  pinned      boolean not null default false,
  expires_at  timestamptz,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists posts_created on public.posts(created_at desc);

-- أعمالنا (صور مرفوعة إلى Storage → bucket «works»)
create table if not exists public.works (
  id         bigserial primary key,
  category   text not null default 'tattoo',  -- tattoo, piercing, laser, skin, other
  image_url  text not null,
  caption    text not null default '',
  sort       int not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- العروض الذكية والهدايا (كوبونات بكود وباركود)
-- ---------------------------------------------------------------------
create table if not exists public.offers (
  id             bigserial primary key,
  kind           text not null check (kind in ('proximity','neighbor','general')),
  title          text not null,                -- «مدام صرتي قريبة… مري علينا»
  body           text not null default '',
  discount_text  text not null default '',     -- «خصم 10%»
  neighbor_tiers text[] not null default '{}',  -- لعروض الجيران: building / near / area
  every_days     int not null default 30,       -- لعروض الجيران: تتكرر كل كم يوم
  valid_days     int not null default 7,        -- صلاحية الكوبون
  sound          text not null default 'rs_gift',
  active         boolean not null default true,
  created_at     timestamptz not null default now()
);

create table if not exists public.coupons (
  id            bigserial primary key,
  code          text not null unique,
  offer_id      bigint references public.offers(id) on delete set null,
  customer_id   uuid not null references public.customers(id) on delete cascade,
  title         text not null,
  discount_text text not null default '',
  status        text not null default 'active' check (status in ('active','used','expired')),
  expires_at    timestamptz not null,
  used_at       timestamptz,
  used_by       uuid references auth.users(id) on delete set null,
  used_by_name  text,
  created_at    timestamptz not null default now()
);
create index if not exists coupons_customer on public.coupons(customer_id, created_at desc);
create index if not exists coupons_offer on public.coupons(offer_id, customer_id, created_at desc);

-- =====================================================================
-- المشغلات (Triggers)
-- =====================================================================

-- اسم الموظف الظاهر للزبون حسب الإعداد، وتحديث آخر رسالة وعدادات غير المقروء
create or replace function public.messages_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare show boolean;
begin
  if new.sender = 'staff' then
    new.staff_user := coalesce(new.staff_user, auth.uid());
    select show_staff_names into show from center_settings where id = 1;
    new.display_name := case when coalesce(show,false) then staff_name(new.staff_user) else null end;
  else
    new.staff_user := null;
    if new.sender = 'customer' then new.display_name := null; end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_messages_before on public.messages;
create trigger trg_messages_before before insert on public.messages
for each row execute function public.messages_before_insert();

create or replace function public.messages_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update conversations set
    last_message = case new.kind when 'image' then '📷 صورة' when 'booking' then '📅 حجز' when 'coupon' then '🎁 هدية' else left(new.body, 140) end,
    last_message_at = new.created_at,
    unread_staff = case when new.sender = 'customer' then unread_staff + 1 else unread_staff end,
    unread_customer = case when new.sender <> 'customer' then unread_customer + 1 else unread_customer end,
    handling_staff = case when new.sender = 'staff' then new.staff_user else handling_staff end,
    handling_until = case when new.sender = 'staff' then now() + interval '2 minutes' else handling_until end
  where id = new.conversation_id;
  return new;
end $$;

drop trigger if exists trg_messages_after on public.messages;
create trigger trg_messages_after after insert on public.messages
for each row execute function public.messages_after_insert();

-- =====================================================================
-- الدوال (RPC)
-- =====================================================================

-- تسجيل/تحديث بيانات الزبون وإنشاء محادثته
create or replace function public.upsert_customer(p_name text, p_phone text, p_platform text default null, p_build int default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare conv uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into customers (id, name, phone, platform, app_build)
  values (auth.uid(), coalesce(p_name,''), coalesce(p_phone,''), p_platform, coalesce(p_build,0))
  on conflict (id) do update set
    name = case when excluded.name <> '' then excluded.name else customers.name end,
    phone = case when excluded.phone <> '' then excluded.phone else customers.phone end,
    platform = coalesce(excluded.platform, customers.platform),
    app_build = greatest(excluded.app_build, customers.app_build),
    last_seen_at = now();
  insert into conversations (customer_id) values (auth.uid()) on conflict (customer_id) do nothing;
  select id into conv from conversations where customer_id = auth.uid();
  return conv;
end $$;

-- تسجيل رمز الإشعارات للجهاز
create or replace function public.register_token(p_token text, p_kind text, p_platform text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if p_kind = 'staff' and not is_staff() then raise exception 'not staff'; end if;
  insert into device_tokens (token, user_id, kind, platform) values (p_token, auth.uid(), p_kind, p_platform)
  on conflict (token) do update set user_id = excluded.user_id, kind = excluded.kind, platform = excluded.platform, updated_at = now();
end $$;

-- الزبون قرأ رسائل المركز
create or replace function public.mark_read_customer() returns void
language sql security definer set search_path = public as $$
  update conversations set unread_customer = 0 where customer_id = auth.uid();
$$;

-- الموظف قرأ المحادثة
create or replace function public.mark_read_staff(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_staff() then raise exception 'not staff'; end if;
  update conversations set unread_staff = 0 where id = p_conv;
end $$;

-- «فلان يرد هسه»: الموظف يحجز المحادثة لدقيقتين (يتجدد أثناء الكتابة)
create or replace function public.claim_conversation(p_conv uuid) returns text
language plpgsql security definer set search_path = public as $$
declare cur uuid; until_ts timestamptz;
begin
  if not is_staff() then raise exception 'not staff'; end if;
  select handling_staff, handling_until into cur, until_ts from conversations where id = p_conv for update;
  if cur is not null and cur <> auth.uid() and until_ts > now() then
    return staff_name(cur);   -- مشغولة عند موظف آخر
  end if;
  update conversations set handling_staff = auth.uid(), handling_until = now() + interval '2 minutes' where id = p_conv;
  return null;
end $$;

-- كود كوبون قصير سهل القراءة: RSM-XXXX
create or replace function public.new_coupon_code() returns text
language plpgsql as $$
declare c text; alphabet text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; i int;
begin
  loop
    c := 'RSM-';
    for i in 1..5 loop c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1); end loop;
    exit when not exists(select 1 from coupons where code = c);
  end loop;
  return c;
end $$;

-- عرض القرب: يُستدعى من جهاز الزبون بعد دخوله دائرة المركز.
-- لا يُرسل موقع الزبون — فقط أنه دخل المنطقة. يحترم الأوقات ومدة التكرار.
create or replace function public.claim_proximity_offer() returns setof public.coupons
language plpgsql security definer set search_path = public as $$
declare s center_settings; o offers; m int; last_ts timestamptz; c coupons;
begin
  if auth.uid() is null then return; end if;
  if not exists(select 1 from customers where id = auth.uid()) then return; end if;
  select * into s from center_settings where id = 1;
  if not s.proximity_enabled then return; end if;
  m := extract(hour from (now() at time zone 'Asia/Baghdad'))::int * 60 + extract(minute from (now() at time zone 'Asia/Baghdad'))::int;
  if m < s.proximity_from_min or m > s.proximity_to_min then return; end if;
  select * into o from offers where kind = 'proximity' and active order by created_at desc limit 1;
  if o.id is null then return; end if;
  select max(cp.created_at) into last_ts from coupons cp join offers ox on ox.id = cp.offer_id
    where cp.customer_id = auth.uid() and ox.kind = 'proximity';
  if last_ts is not null and last_ts > now() - make_interval(days => s.proximity_cooldown_d) then return; end if;
  insert into coupons (code, offer_id, customer_id, title, discount_text, expires_at)
  values (new_coupon_code(), o.id, auth.uid(), o.title, o.discount_text, now() + make_interval(days => o.valid_days))
  returning * into c;
  return next c;
end $$;

-- عرض عام يرسله المركز لكل الزبائن (أو لشريحة الجيران) فوراً
create or replace function public.issue_offer_now(p_offer bigint) returns int
language plpgsql security definer set search_path = public as $$
declare o offers; n int := 0;
begin
  if not is_staff() then raise exception 'not staff'; end if;
  select * into o from offers where id = p_offer;
  if o.id is null then return 0; end if;
  insert into coupons (code, offer_id, customer_id, title, discount_text, expires_at)
  select new_coupon_code(), o.id, cu.id, o.title, o.discount_text, now() + make_interval(days => o.valid_days)
  from customers cu
  where cu.promo_opt_in
    and (o.kind <> 'neighbor' or cu.neighbor_tier = any(o.neighbor_tiers));
  get diagnostics n = row_count;
  return n;
end $$;

-- عروض الجيران الدورية: تُشغَّل يومياً (pg_cron) وتعطي كل جار كوبوناً كل every_days
create or replace function public.issue_neighbor_offers() returns int
language plpgsql security definer set search_path = public as $$
declare o offers; n int := 0; k int;
begin
  for o in select * from offers where kind = 'neighbor' and active loop
    insert into coupons (code, offer_id, customer_id, title, discount_text, expires_at)
    select new_coupon_code(), o.id, cu.id, o.title, o.discount_text, now() + make_interval(days => o.valid_days)
    from customers cu
    where cu.promo_opt_in
      and cu.neighbor_tier = any(o.neighbor_tiers)
      and not exists (
        select 1 from coupons cp where cp.customer_id = cu.id and cp.offer_id = o.id
          and cp.created_at > now() - make_interval(days => o.every_days)
      );
    get diagnostics k = row_count;
    n := n + k;
  end loop;
  update coupons set status = 'expired' where status = 'active' and expires_at < now();
  return n;
end $$;

-- معاينة كوبون عند الموظف قبل الاستخدام
create or replace function public.coupon_info(p_code text)
returns table (code text, title text, discount_text text, status text, expires_at timestamptz,
               customer_name text, customer_phone text, used_at timestamptz, used_by_name text)
language plpgsql security definer set search_path = public as $$
begin
  if not is_staff() then raise exception 'not staff'; end if;
  return query
    select cp.code, cp.title, cp.discount_text,
           case when cp.status = 'active' and cp.expires_at < now() then 'expired' else cp.status end,
           cp.expires_at, cu.name, cu.phone, cp.used_at, cp.used_by_name
    from coupons cp join customers cu on cu.id = cp.customer_id
    where cp.code = upper(trim(p_code));
end $$;

-- استخدام الكوبون (مرة وحدة فقط)
create or replace function public.redeem_coupon(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare c coupons;
begin
  if not is_staff() then raise exception 'not staff'; end if;
  select * into c from coupons where code = upper(trim(p_code)) for update;
  if c.id is null then return 'not_found'; end if;
  if c.status = 'used' then return 'used'; end if;
  if c.status = 'expired' or c.expires_at < now() then
    update coupons set status = 'expired' where id = c.id;
    return 'expired';
  end if;
  update coupons set status = 'used', used_at = now(), used_by = auth.uid(), used_by_name = staff_name(auth.uid()) where id = c.id;
  return 'ok';
end $$;

-- أول موظف يسجل دخول من نسخة المركز يصير المدير تلقائياً (مرة وحدة فقط)
create or replace function public.claim_first_admin(p_name text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  if exists(select 1 from staff_members) then return is_staff(); end if;
  insert into staff_members (user_id, display_name, role) values (auth.uid(), coalesce(nullif(trim(p_name), ''), 'المدير'), 'admin');
  return true;
end $$;

-- حذف حساب الزبون مع كل بياناته (متطلب Apple و Google)
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then return; end if;
  delete from auth.users where id = auth.uid();
end $$;

-- إحصائيات العروض للوحة المركز
create or replace function public.offer_stats()
returns table (offer_id bigint, title text, kind text, sent bigint, used bigint)
language plpgsql security definer set search_path = public as $$
begin
  if not is_staff() then raise exception 'not staff'; end if;
  return query
    select o.id, o.title, o.kind, count(c.id), count(c.id) filter (where c.status = 'used')
    from offers o left join coupons c on c.offer_id = o.id
    group by o.id order by o.created_at desc;
end $$;

-- =====================================================================
-- الصلاحيات (Row Level Security)
-- =====================================================================
alter table public.staff_members   enable row level security;
alter table public.center_settings enable row level security;
alter table public.mall_steps      enable row level security;
alter table public.customers       enable row level security;
alter table public.device_tokens   enable row level security;
alter table public.public_services enable row level security;
alter table public.conversations   enable row level security;
alter table public.messages        enable row level security;
alter table public.reports         enable row level security;
alter table public.bookings        enable row level security;
alter table public.posts           enable row level security;
alter table public.works           enable row level security;
alter table public.offers          enable row level security;
alter table public.coupons         enable row level security;

do $$
declare t text;
begin
  -- حذف السياسات القديمة لإعادة إنشائها
  for t in select policyname || ' on ' || schemaname || '.' || tablename from pg_policies
           where schemaname = 'public' and policyname like 'rs_%' loop
    execute 'drop policy if exists ' || t;
  end loop;
end $$;

-- الموظفون: يرون بعضهم، والمدير يدير
create policy rs_staff_read on public.staff_members for select using (is_staff());
create policy rs_staff_admin on public.staff_members for all using (is_admin()) with check (is_admin());

-- إعدادات المركز وخطوات المول والخدمات والمنشورات والأعمال: يقرؤها الجميع، يعدلها الموظفون
create policy rs_settings_read on public.center_settings for select using (true);
create policy rs_settings_write on public.center_settings for update using (is_staff()) with check (is_staff());
create policy rs_steps_read on public.mall_steps for select using (true);
create policy rs_steps_write on public.mall_steps for all using (is_staff()) with check (is_staff());
create policy rs_services_read on public.public_services for select using (true);
create policy rs_services_write on public.public_services for all using (is_staff()) with check (is_staff());
create policy rs_posts_read on public.posts for select using (true);
create policy rs_posts_write on public.posts for all using (is_staff()) with check (is_staff());
create policy rs_works_read on public.works for select using (true);
create policy rs_works_write on public.works for all using (is_staff()) with check (is_staff());
create policy rs_offers_read on public.offers for select using (is_staff() or (active and kind = 'proximity'));
create policy rs_offers_write on public.offers for all using (is_staff()) with check (is_staff());

-- الزبائن: كل زبون يرى نفسه، والموظفون يرون الكل
create policy rs_customers_self on public.customers for select using (id = auth.uid() or is_staff());
create policy rs_customers_update on public.customers for update using (id = auth.uid()) with check (id = auth.uid());

create policy rs_tokens_self on public.device_tokens for select using (user_id = auth.uid());
create policy rs_tokens_delete on public.device_tokens for delete using (user_id = auth.uid());

-- المحادثات والرسائل
create policy rs_conv_read on public.conversations for select using (customer_id = auth.uid() or is_staff());
create policy rs_conv_staff on public.conversations for update using (is_staff()) with check (is_staff());

create policy rs_msg_read on public.messages for select using (
  is_staff() or exists(select 1 from conversations c where c.id = conversation_id and c.customer_id = auth.uid())
);
create policy rs_msg_customer_insert on public.messages for insert with check (
  sender = 'customer' and kind in ('text','image')
  and exists(select 1 from conversations c where c.id = conversation_id and c.customer_id = auth.uid())
);
create policy rs_msg_staff_insert on public.messages for insert with check (is_staff() and sender in ('staff','system'));

create policy rs_reports_insert on public.reports for insert with check (reporter = auth.uid());
create policy rs_reports_read on public.reports for select using (is_staff());

-- الحجوزات والكوبونات
create policy rs_bookings_read on public.bookings for select using (customer_id = auth.uid() or is_staff());
create policy rs_bookings_staff on public.bookings for all using (is_staff()) with check (is_staff());
create policy rs_coupons_read on public.coupons for select using (customer_id = auth.uid() or is_staff());
create policy rs_coupons_staff on public.coupons for all using (is_staff()) with check (is_staff());

-- صلاحيات الجداول للتطبيقات (الحماية الفعلية بسياسات RLS فوق)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.center_settings, public.mall_steps, public.public_services, public.posts, public.works to anon;
grant usage, select on all sequences in schema public to authenticated;

-- السماح بالتنفيذ
grant execute on function public.upsert_customer(text,text,text,int) to authenticated;
grant execute on function public.register_token(text,text,text) to authenticated;
grant execute on function public.mark_read_customer() to authenticated;
grant execute on function public.mark_read_staff(uuid) to authenticated;
grant execute on function public.claim_conversation(uuid) to authenticated;
grant execute on function public.claim_proximity_offer() to authenticated;
grant execute on function public.issue_offer_now(bigint) to authenticated;
grant execute on function public.coupon_info(text) to authenticated;
grant execute on function public.redeem_coupon(text) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.offer_stats() to authenticated;
grant execute on function public.claim_first_admin(text) to authenticated;
revoke execute on function public.issue_neighbor_offers() from public, anon, authenticated;

-- =====================================================================
-- البث اللحظي (Realtime) للمحادثة والمنشورات والكوبونات والحجوزات
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array['messages','conversations','posts','coupons','bookings'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- =====================================================================
-- التخزين: صور الأعمال والمحادثة وأصوات التوجيه
-- =====================================================================
insert into storage.buckets (id, name, public) values ('works', 'works', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('chat', 'chat', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('voice', 'voice', true) on conflict (id) do nothing;

drop policy if exists rs_storage_staff on storage.objects;
create policy rs_storage_staff on storage.objects for all
  using (bucket_id in ('works','voice','chat') and public.is_staff())
  with check (bucket_id in ('works','voice','chat') and public.is_staff());

-- الزبون يرفع صوره داخل مجلد باسمه في chat فقط
drop policy if exists rs_storage_customer_chat on storage.objects;
create policy rs_storage_customer_chat on storage.objects for insert
  with check (bucket_id = 'chat' and (storage.foldername(name))[1] = auth.uid()::text);


-- ===== تحديث 2 (العروض) =====
alter table public.offers add column if not exists audience text not null default 'all';
alter table public.offers add column if not exists target_ids uuid[] not null default '{}';
do $$ begin
  alter table public.offers add constraint offers_audience_chk check (audience in ('all','only','except'));
exception when duplicate_object then null; end $$;

-- منين جا الكوبون: near = الزبون مر قريب (التنبيه محلي بجهازه) / staff = المركز أرسله (إشعار)
alter table public.coupons add column if not exists via text not null default 'staff';

-- كل عرض مرة وحدة لكل زبون
delete from public.coupons a using public.coupons b
  where a.offer_id is not null and a.offer_id = b.offer_id and a.customer_id = b.customer_id and a.id > b.id;
create unique index if not exists coupons_offer_customer on public.coupons(offer_id, customer_id) where offer_id is not null;

-- إيقاف عروض الجيران القديمة
update public.offers set active = false where kind = 'neighbor';

create or replace function public.offer_targets_customer(o public.offers, cid uuid) returns boolean
language sql immutable as $$
  select case o.audience
    when 'only' then cid = any(o.target_ids)
    when 'except' then not (cid = any(o.target_ids))
    else true end;
$$;

-- عرض القرب: الزبون دخل منطقة المركز
create or replace function public.claim_proximity_offer() returns setof public.coupons
language plpgsql security definer set search_path = public as $$
declare s center_settings; o offers; m int; c coupons;
begin
  if auth.uid() is null then return; end if;
  if not exists(select 1 from customers where id = auth.uid()) then return; end if;
  select * into s from center_settings where id = 1;
  if not s.proximity_enabled then return; end if;
  m := extract(hour from (now() at time zone 'Asia/Baghdad'))::int * 60 + extract(minute from (now() at time zone 'Asia/Baghdad'))::int;
  if m < s.proximity_from_min or m > s.proximity_to_min then return; end if;
  update coupons set status = 'expired' where customer_id = auth.uid() and status = 'active' and expires_at < now();
  -- عنده هدية قرب صالحة؟ ينتظر لحد ما تنتهي أو يستخدمها
  if exists(select 1 from coupons cp join offers ox on ox.id = cp.offer_id
            where cp.customer_id = auth.uid() and ox.kind = 'proximity' and cp.status = 'active') then
    return;
  end if;
  -- أقدم عرض قرب شغال ما استلمه بعد ومسموح إله
  select * into o from offers ox
   where ox.kind = 'proximity' and ox.active
     and public.offer_targets_customer(ox, auth.uid())
     and not exists(select 1 from coupons cp where cp.offer_id = ox.id and cp.customer_id = auth.uid())
   order by ox.created_at asc limit 1;
  if o.id is null then return; end if;
  insert into coupons (code, offer_id, customer_id, title, discount_text, expires_at, via)
  values (new_coupon_code(), o.id, auth.uid(), o.title, o.discount_text, now() + make_interval(days => o.valid_days), 'near')
  on conflict do nothing
  returning * into c;
  if c.id is not null then return next c; end if;
end $$;

-- «أرسل الآن»: للي ما استلموا هالعرض بس، حسب الاختيار
create or replace function public.issue_offer_now(p_offer bigint) returns int
language plpgsql security definer set search_path = public as $$
declare o offers; n int := 0;
begin
  if not is_staff() then raise exception 'not staff'; end if;
  select * into o from offers where id = p_offer;
  if o.id is null then return 0; end if;
  insert into coupons (code, offer_id, customer_id, title, discount_text, expires_at, via)
  select new_coupon_code(), o.id, cu.id, o.title, o.discount_text, now() + make_interval(days => o.valid_days), 'staff'
  from customers cu
  where (cu.promo_opt_in or o.audience = 'only')
    and public.offer_targets_customer(o, cu.id)
    and not exists(select 1 from coupons cp where cp.offer_id = o.id and cp.customer_id = cu.id)
  on conflict do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- منو استلم العرض ومنو لا
create or replace function public.offer_recipients(p_offer bigint)
returns table (customer_id uuid, name text, phone text, allowed boolean, code text, status text, received_at timestamptz, used_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare o offers;
begin
  if not is_staff() then raise exception 'not staff'; end if;
  select * into o from offers where id = p_offer;
  return query
    select cu.id, cu.name, cu.phone, public.offer_targets_customer(o, cu.id),
           cp.code,
           case when cp.id is null then null
                when cp.status = 'active' and cp.expires_at < now() then 'expired' else cp.status end,
           cp.created_at, cp.used_at
    from customers cu
    left join coupons cp on cp.offer_id = o.id and cp.customer_id = cu.id
    where cu.name <> ''
    order by cp.created_at desc nulls last, cu.name;
end $$;

-- كانت توزع عروض الجيران يومياً — هسه بس تنهي الكوبونات المنتهية
create or replace function public.issue_neighbor_offers() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update coupons set status = 'expired' where status = 'active' and expires_at < now();
  get diagnostics n = row_count;
  return n;
end $$;

grant execute on function public.offer_recipients(bigint) to authenticated;
grant execute on function public.claim_proximity_offer() to authenticated;
grant execute on function public.issue_offer_now(bigint) to authenticated;


-- ===== تحديث 3 (الإرسال حسب المنطقة) =====
alter table public.customers add column if not exists area text;            -- karrada | baghdad | outside
alter table public.customers add column if not exists dist_km numeric;      -- البعد عن المركز (مقرّب لنص كيلو)
alter table public.customers add column if not exists area_at timestamptz;

alter table public.offers add column if not exists near_km numeric not null default 2;
alter table public.offers drop constraint if exists offers_audience_chk;
alter table public.offers add constraint offers_audience_chk
  check (audience in ('all','near','karrada','baghdad','only','except'));

alter table public.posts add column if not exists audience text not null default 'all';
alter table public.posts add column if not exists near_km numeric not null default 2;
alter table public.posts add column if not exists target_ids uuid[] not null default '{}';

-- الزبون يحدّث منطقته
create or replace function public.update_my_area(p_area text, p_dist numeric) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  update customers set
    area = case when p_area in ('karrada','baghdad','outside') then p_area else null end,
    dist_km = round(greatest(p_dist, 0) * 2) / 2,
    area_at = now()
  where id = auth.uid();
end $$;

-- هل الزبون ضمن الجمهور؟
create or replace function public.customer_in_audience(aud text, targets uuid[], near numeric, cu public.customers)
returns boolean language sql stable as $$
  select case aud
    when 'near' then cu.dist_km is not null and cu.dist_km <= near
    when 'karrada' then cu.area = 'karrada'
    when 'baghdad' then cu.area in ('karrada','baghdad')
    when 'only' then cu.id = any(targets)
    when 'except' then not (cu.id = any(targets))
    else true end;
$$;

create or replace function public.offer_targets_customer(o public.offers, cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select public.customer_in_audience(o.audience, o.target_ids, o.near_km, cu) from customers cu where cu.id = cid), false);
$$;

-- كم زبون راح يوصله (للمركز قبل الإرسال)
create or replace function public.audience_count(aud text, targets uuid[], near numeric) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not is_staff() then raise exception 'not staff'; end if;
  select count(*) into n from customers cu
   where cu.name <> '' and (cu.promo_opt_in or aud = 'only') and public.customer_in_audience(aud, targets, near, cu);
  return n;
end $$;

-- لدالة الإشعارات (service role فقط): أرقام الزبائن ضمن جمهور المنشور
create or replace function public.audience_customer_ids(aud text, targets uuid[], near numeric) returns setof uuid
language sql stable security definer set search_path = public as $$
  select cu.id from customers cu
   where (cu.promo_opt_in or aud = 'only') and public.customer_in_audience(aud, targets, near, cu);
$$;

grant execute on function public.update_my_area(text, numeric) to authenticated;
grant execute on function public.audience_count(text, uuid[], numeric) to authenticated;
revoke execute on function public.audience_customer_ids(text, uuid[], numeric) from public, anon, authenticated;
