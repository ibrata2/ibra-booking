-- =====================================================================
-- روسم للتجميل — الإشعارات الفورية والعروض الدورية
-- شغّله بعد schema.sql وبعد نشر دالة push (انظر backend/README.md)
-- =====================================================================

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- عنوان دالة الإرسال وسرّها (لا يقرؤه أحد من التطبيقات)
create table if not exists public.push_config (
  id     int primary key default 1 check (id = 1),
  url    text,     -- https://<project-ref>.supabase.co/functions/v1/push
  secret text      -- نفس قيمة PUSH_HOOK_SECRET في أسرار الدالة
);
alter table public.push_config enable row level security;
insert into public.push_config (id) values (1) on conflict (id) do nothing;

-- ⚠️ عدّل السطر التالي بعنوان مشروعك وسرّك ثم شغّله:
-- update public.push_config set url = 'https://XXXX.supabase.co/functions/v1/push', secret = 'ضع-كلمة-سر-طويلة' where id = 1;

create or replace function public.notify_push() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare cfg push_config;
begin
  select * into cfg from push_config where id = 1;
  if cfg.url is null or cfg.url = '' then return new; end if;
  perform net.http_post(
    url := cfg.url,
    body := jsonb_build_object('type', TG_OP, 'table', TG_TABLE_NAME, 'record', to_jsonb(new)),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', coalesce(cfg.secret, '')),
    timeout_milliseconds := 8000
  );
  return new;
exception when others then
  -- فشل الإشعار لا يمنع حفظ البيانات أبداً
  return new;
end $$;

drop trigger if exists trg_push_posts on public.posts;
create trigger trg_push_posts after insert on public.posts
for each row when (new.notify) execute function public.notify_push();

drop trigger if exists trg_push_messages on public.messages;
create trigger trg_push_messages after insert on public.messages
for each row execute function public.notify_push();

drop trigger if exists trg_push_coupons on public.coupons;
create trigger trg_push_coupons after insert on public.coupons
for each row execute function public.notify_push();

drop trigger if exists trg_push_bookings on public.bookings;
create trigger trg_push_bookings after insert or update of status, start_at on public.bookings
for each row execute function public.notify_push();

-- عروض الجيران: كل يوم الساعة 10 صباحاً بتوقيت بغداد (07:00 UTC)
do $$
begin
  perform cron.unschedule('rs_neighbors_daily');
exception when others then null;
end $$;
select cron.schedule('rs_neighbors_daily', '0 7 * * *', $$select public.issue_neighbor_offers()$$);
