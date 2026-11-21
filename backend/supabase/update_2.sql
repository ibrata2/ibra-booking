-- =====================================================================
-- روسم للتجميل — تحديث 2: العروض
--  • إلغاء عروض الجيران
--  • كل عرض يوصل للزبون مرة وحدة بس (ما يتكرر)
--  • تحدد منو يستلم العرض: الكل / زبائن محددين / الكل ماعدا محددين
--  • الزبون اللي عنده هدية قرب صالحة ما يستلم غيرها لحد ما تنتهي أو يستخدمها، وبعدها يستلم العرض الجاي
--  • «أرسل الآن» يرسل العرض للي ما استلموه بس
-- شغّله مرة وحدة: SQL Editor → New query → الصق → Run
-- =====================================================================

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
