-- =====================================================================
-- روسم للتجميل — تحديث 3: الإرسال حسب المنطقة
--  • تطبيق الزبون يحفظ منطقته التقريبية (الكرادة / بغداد / خارج بغداد) وبعده عن المركز بالكيلو
--    — يتحدث كل ما يفتح التطبيق (إذا مفعّل الموقع)، وما نحفظ إحداثياته
--  • المنشورات والعروض: تحدد منو يوصله الإشعار — الكل / القريبين / الكرادة / بغداد / محددين / الكل ماعدا
-- شغّله مرة وحدة بعد update_2.sql
-- =====================================================================

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
