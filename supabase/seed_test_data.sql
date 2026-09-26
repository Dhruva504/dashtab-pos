-- ============================================================
-- DashTab POS – TEST DATA SEED
-- Creates a fully populated workspace with REAL Supabase auth
-- users so the app has something to show during testing.
--
--   Test users (password for ALL: Dashtab123!)
--     owner@dashtab.app     → Reda Bayi      (Owner)
--     mostapha@dashtab.app  → Mostapha Bayi  (Manager)
--     samantha@dashtab.app  → Samantha Smith (Cashier)
--     maja@dashtab.app      → Maja Becker    (Chef)
--     lucia@dashtab.app     → Lucía Fernández (Waiter)
--     carlos@dashtab.app    → Carlos Ruiz    (Kitchen Staff)
--
-- SAFE TO RE-RUN: every statement is guarded (on conflict /
-- where not exists). Delete the rows (or this file) before a
-- clean production launch if you don't want test data.
-- Requires migrations 001–008 applied first.
-- ============================================================

do $$
declare
    v_tenant      uuid;
    v_owner       uuid;
    v_manager     uuid;
    v_cashier     uuid;
    v_chef        uuid;
    v_waiter      uuid;
    v_waiter2     uuid;
    v_pub_owner   uuid;
    v_pub_manager uuid;
    v_pub_cashier uuid;
    v_pub_chef    uuid;
    v_pub_waiter  uuid;
    v_pub_waiter2 uuid;
    v_user        uuid;
    r             record;
    v_set         text;
    v_where       text;
    v_tax10       uuid;
    v_tax21       uuid;
    v_tax4        uuid;
    v_cat_burgers uuid;
    v_cat_pizza   uuid;
    v_cat_sandw   uuid;
    v_cat_snacks  uuid;
    v_cat_salads  uuid;
    v_cat_mains   uuid;
    v_cat_drinks  uuid;
    v_cat_dessert uuid;
    v_pm_cash     uuid;
    v_pm_card     uuid;
    v_pm_bizum    uuid;
    v_pm_gc       uuid;
    v_floor       uuid;
    v_shift       uuid;
begin

-- ─── Tenant (reuses/upgrades the 'demo' slug) ───────────────
insert into public.tenants (name, slug, currency_code, locale, timezone, address, phone, email)
values (
    'DashTab Madrid · Gran Vía', 'demo', 'EUR', 'es-ES', 'Europe/Madrid',
    'Calle de Gran Vía 28, 28013 Madrid', '+34 91 555 0123', 'hola@dashtab.es'
)
on conflict (slug) do update set
    name = excluded.name, currency_code = excluded.currency_code,
    locale = excluded.locale, timezone = excluded.timezone,
    address = excluded.address, phone = excluded.phone, email = excluded.email,
    updated_at = now()
returning id into v_tenant;

-- ─── Real auth users (email + password, pre-confirmed) ───────
-- Upsert by email. Written as an explicit select/insert/update loop
-- instead of `on conflict (email)` because Supabase's auth.users uses
-- a partial unique index (email where deleted_at is null), which
-- `on conflict (email)` cannot infer.
for r in select * from (values
    ('owner@dashtab.app',    'Reda Bayi',       'admin'),
    ('mostapha@dashtab.app', 'Mostapha Bayi',   'admin'),
    ('samantha@dashtab.app', 'Samantha Smith',  'staff'),
    ('maja@dashtab.app',     'Maja Becker',     'staff'),
    ('lucia@dashtab.app',    'Lucía Fernández', 'staff'),
    ('carlos@dashtab.app',   'Carlos Ruiz',     'staff')
) as t(email, full_name, role) loop
    v_user := null;
    select id into v_user from auth.users where email = r.email limit 1;
    if v_user is null then
        insert into auth.users (
            instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at
        ) values (
            '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
            r.email, crypt('Dashtab123!', gen_salt('bf')), now(),
            jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'tenant_id', v_tenant::text,'role', r.role),
            jsonb_build_object('full_name', r.full_name), now(), now()
        )
        returning id into v_user;
    else
        -- Re-run: keep the same id, refresh password + metadata.
        update auth.users set
            encrypted_password = crypt('Dashtab123!', gen_salt('bf')),
            email_confirmed_at = now(),
            raw_app_meta_data  = jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'tenant_id', v_tenant::text,'role', r.role),
            raw_user_meta_data = jsonb_build_object('full_name', r.full_name),
            updated_at         = now()
        where id = v_user;
    end if;
    if r.email = 'owner@dashtab.app' then
        v_owner := v_user;
    elsif r.email = 'mostapha@dashtab.app' then
        v_manager := v_user;
    elsif r.email = 'samantha@dashtab.app' then
        v_cashier := v_user;
    elsif r.email = 'maja@dashtab.app' then
        v_chef := v_user;
    elsif r.email = 'lucia@dashtab.app' then
        v_waiter := v_user;
    elsif r.email = 'carlos@dashtab.app' then
        v_waiter2 := v_user;
    end if;

    -- Complete GoTrue user record: an auth.identities row (version-safe
    -- against older/newer auth schemas; harmless if already present).
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
    ) then
        insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
        values (v_user::text, v_user,
                jsonb_build_object('sub', v_user::text, 'email', r.email, 'email_verified', true),
                'email', now(), now(), now())
        on conflict (provider, provider_id) do nothing;
    end if;
end loop;

-- GoTrue scans several auth.users token columns as non-null strings;
-- direct SQL inserts leave them NULL, which breaks sign-in with
-- "Database error querying schema". Repair any that exist (built from
-- information_schema, so it adapts to older/newer GoTrue schemas).
select string_agg(format('%I = ''''', column_name), ', '),
       string_agg(format('%I IS NULL', column_name), ' OR ')
into v_set, v_where
from information_schema.columns
where table_schema = 'auth'
  and table_name = 'users'
  and column_name in (
      'confirmation_token', 'recovery_token',
      'email_change_token_new', 'email_change',
      'email_change_token_current', 'reauthentication_token',
      'phone_change', 'phone_change_token'
  )
  and is_nullable = 'YES';
if v_set is not null and v_where is not null then
    execute 'update auth.users set ' || v_set || ' where ' || v_where;
end if;

-- ─── Public users (staff) linked to auth + tenant ────────────
insert into public.users (user_id, email, full_name, role, phone, hired_at, is_active, tenant_id)
select v_owner, 'owner@dashtab.app', 'Reda Bayi', 'Owner', '+34 612 345 678', '2017-11-12', true, v_tenant
where not exists (select 1 from public.users u where u.user_id = v_owner)
returning id into v_pub_owner;

if v_pub_owner is null then select id into v_pub_owner from public.users where user_id = v_owner limit 1; end if;

insert into public.users (user_id, email, full_name, role, phone, hired_at, is_active, tenant_id)
select v_manager, 'mostapha@dashtab.app', 'Mostapha Bayi', 'Manager', '+34 622 111 222', '2018-03-02', true, v_tenant
where not exists (select 1 from public.users u where u.user_id = v_manager)
returning id into v_pub_manager;

if v_pub_manager is null then select id into v_pub_manager from public.users where user_id = v_manager limit 1; end if;

insert into public.users (user_id, email, full_name, role, phone, hired_at, is_active, tenant_id)
select v_cashier, 'samantha@dashtab.app', 'Samantha Smith', 'Cashier', '+34 644 555 666', '2021-02-01', true, v_tenant
where not exists (select 1 from public.users u where u.user_id = v_cashier)
returning id into v_pub_cashier;

if v_pub_cashier is null then select id into v_pub_cashier from public.users where user_id = v_cashier limit 1; end if;

insert into public.users (user_id, email, full_name, role, phone, hired_at, is_active, tenant_id)
select v_chef, 'maja@dashtab.app', 'Maja Becker', 'Chef', '+34 655 777 888', '2020-09-14', true, v_tenant
where not exists (select 1 from public.users u where u.user_id = v_chef)
returning id into v_pub_chef;

if v_pub_chef is null then select id into v_pub_chef from public.users where user_id = v_chef limit 1; end if;

insert into public.users (user_id, email, full_name, role, phone, hired_at, is_active, tenant_id)
select v_waiter, 'lucia@dashtab.app', 'Lucía Fernández', 'Waiter', '+34 677 121 314', '2023-01-08', true, v_tenant
where not exists (select 1 from public.users u where u.user_id = v_waiter)
returning id into v_pub_waiter;

if v_pub_waiter is null then select id into v_pub_waiter from public.users where user_id = v_waiter limit 1; end if;

insert into public.users (user_id, email, full_name, role, phone, hired_at, is_active, tenant_id)
select v_waiter2, 'carlos@dashtab.app', 'Carlos Ruiz', 'Kitchen Staff', '+34 688 232 425', '2023-04-15', true, v_tenant
where not exists (select 1 from public.users u where u.user_id = v_waiter2)
returning id into v_pub_waiter2;

if v_pub_waiter2 is null then select id into v_pub_waiter2 from public.users where user_id = v_waiter2 limit 1; end if;

-- ─── Tax rates (IVA) ─────────────────────────────────────────
insert into public.tax_rates (name, rate, is_inclusive, is_default, is_active, tenant_id)
select 'IVA General 21%', 21, true, true, true, v_tenant
where not exists (select 1 from public.tax_rates tr where tr.tenant_id = v_tenant and tr.rate = 21)
returning id into v_tax21;

insert into public.tax_rates (name, rate, is_inclusive, is_default, is_active, tenant_id)
select 'IVA Reducido 10%', 10, true, false, true, v_tenant
where not exists (select 1 from public.tax_rates tr where tr.tenant_id = v_tenant and tr.rate = 10)
returning id into v_tax10;

insert into public.tax_rates (name, rate, is_inclusive, is_default, is_active, tenant_id)
select 'IVA Super-reducido 4%', 4, true, false, true, v_tenant
where not exists (select 1 from public.tax_rates tr where tr.tenant_id = v_tenant and tr.rate = 4)
returning id into v_tax4;

-- Old GST 5% from the phase-1 seed becomes inactive.
update public.tax_rates set is_active = false, updated_at = now()
where tenant_id = v_tenant and rate = 5;

if v_tax21 is null then select id into v_tax21 from public.tax_rates where tenant_id = v_tenant and rate = 21 limit 1; end if;
if v_tax10 is null then select id into v_tax10 from public.tax_rates where tenant_id = v_tenant and rate = 10 limit 1; end if;
if v_tax4  is null then select id into v_tax4  from public.tax_rates where tenant_id = v_tenant and rate = 4  limit 1; end if;

-- ─── Payment methods ─────────────────────────────────────────
insert into public.payment_methods (name, type, sort_order, is_active, tenant_id)
select 'Cash', 0, 1, true, v_tenant
where not exists (select 1 from public.payment_methods pm where pm.tenant_id = v_tenant and pm.name = 'Cash')
returning id into v_pm_cash;

insert into public.payment_methods (name, type, sort_order, is_active, tenant_id)
select 'Card', 1, 2, true, v_tenant
where not exists (select 1 from public.payment_methods pm where pm.tenant_id = v_tenant and pm.name = 'Card')
returning id into v_pm_card;

insert into public.payment_methods (name, type, sort_order, is_active, tenant_id)
select 'Bizum', 1, 3, true, v_tenant
where not exists (select 1 from public.payment_methods pm where pm.tenant_id = v_tenant and pm.name = 'Bizum')
returning id into v_pm_bizum;

insert into public.payment_methods (name, type, sort_order, is_active, tenant_id)
select 'Gift Card', 1, 4, true, v_tenant
where not exists (select 1 from public.payment_methods pm where pm.tenant_id = v_tenant and pm.name = 'Gift Card')
returning id into v_pm_gc;

if v_pm_cash  is null then select id into v_pm_cash  from public.payment_methods where tenant_id = v_tenant and name = 'Cash' limit 1; end if;
if v_pm_card  is null then select id into v_pm_card  from public.payment_methods where tenant_id = v_tenant and name = 'Card' limit 1; end if;
if v_pm_bizum is null then select id into v_pm_bizum from public.payment_methods where tenant_id = v_tenant and name = 'Bizum' limit 1; end if;
if v_pm_gc    is null then select id into v_pm_gc    from public.payment_methods where tenant_id = v_tenant and name = 'Gift Card' limit 1; end if;

-- ─── Categories ──────────────────────────────────────────────
insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Burgers', 1, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Burgers')
returning id into v_cat_burgers;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Pizza', 2, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Pizza')
returning id into v_cat_pizza;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Sandwich', 3, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Sandwich')
returning id into v_cat_sandw;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Snacks', 4, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Snacks')
returning id into v_cat_snacks;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Salads', 5, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Salads')
returning id into v_cat_salads;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Mains', 6, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Mains')
returning id into v_cat_mains;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Drinks', 7, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Drinks')
returning id into v_cat_drinks;

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Desserts', 8, true, v_tenant
where not exists (select 1 from public.categories c where c.tenant_id = v_tenant and c.name = 'Desserts')
returning id into v_cat_dessert;

if v_cat_burgers is null then select id into v_cat_burgers from public.categories where tenant_id = v_tenant and name = 'Burgers' limit 1; end if;
if v_cat_pizza   is null then select id into v_cat_pizza   from public.categories where tenant_id = v_tenant and name = 'Pizza' limit 1; end if;
if v_cat_sandw   is null then select id into v_cat_sandw   from public.categories where tenant_id = v_tenant and name = 'Sandwich' limit 1; end if;
if v_cat_snacks  is null then select id into v_cat_snacks  from public.categories where tenant_id = v_tenant and name = 'Snacks' limit 1; end if;
if v_cat_salads  is null then select id into v_cat_salads  from public.categories where tenant_id = v_tenant and name = 'Salads' limit 1; end if;
if v_cat_mains   is null then select id into v_cat_mains   from public.categories where tenant_id = v_tenant and name = 'Mains' limit 1; end if;
if v_cat_drinks  is null then select id into v_cat_drinks  from public.categories where tenant_id = v_tenant and name = 'Drinks' limit 1; end if;
if v_cat_dessert is null then select id into v_cat_dessert from public.categories where tenant_id = v_tenant and name = 'Desserts' limit 1; end if;

-- ─── Products (the design menu) ──────────────────────────────
insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_burgers, 'Classic Cheeseburger', 7.49, 18, 32, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/16d11ba51-d2ba-4158-bf8b-981e3a4e5aaa.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Classic Cheeseburger');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_burgers, 'Double Smash Burger', 9.90, 12, 28, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/149672526-985b-4451-a08e-041e391fb2ee.png', 2, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Double Smash Burger');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_pizza, 'Margherita Pizza', 11.48, 9, 41, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/165dc237e-0130-4e0d-b19d-a205010f0d1d.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Margherita Pizza');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_pizza, 'Super Supreme Pizza', 14.20, 7, 23, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/195cafe85-adb2-48a6-b4af-2e6af8a266bf.png', 2, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Super Supreme Pizza');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_sandw, 'Grilled Chicken Melt', 8.90, 14, 19, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/1fcd26e5b-21bd-4782-97a9-7cbd20dfb1a4.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Grilled Chicken Melt');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_sandw, 'Beef BLT Sandwich', 7.90, 0, 11, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/1104a9e3d-3036-4040-8def-e9650cb7ef8f.png', 2, true, false, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Beef BLT Sandwich');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_snacks, 'Crispy French Fries', 3.50, 36, 57, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/1cec2a681-2249-4669-a7e8-9927151124fa.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Crispy French Fries');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_snacks, 'Hot Fried Chicken', 6.90, 4, 33, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/17b7cb8b4-cab0-4e1f-b8e4-577fd5e5bd46.png', 2, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Hot Fried Chicken');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_salads, 'Italian Salad', 7.49, 16, 26, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/17dae4588-a9a9-44dd-87be-18743f846646.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Italian Salad');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_mains, 'Spaghetti Bolognese', 10.90, 11, 21, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/13021c2ce-21da-4661-801e-2db855126501.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Spaghetti Bolognese');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_drinks, 'Fresh Orange Juice', 4.00, 24, 44, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/125eb0e42-16b6-4839-b027-33461e4f34f8.png', 1, true, true, v_tax21, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Fresh Orange Juice');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_drinks, 'Iced Cappuccino', 4.50, 2, 38, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/1cef3d0cb-4070-4ea2-a52b-319d3b8d7e8c.png', 2, true, true, v_tax21, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Iced Cappuccino');

insert into public.products (category_id, name, price, stock_qty, sold_count, image_url, sort_order, is_active, is_available, tax_rate_id, tenant_id)
select v_cat_dessert, 'Chocolate Lava Cake', 6.20, 8, 17, 'https://image.qwenlm.ai/public_source/18a9e4ce-b978-4967-b02b-32c4441cbfdb/1aecdba8a-c5ff-4bf1-8e00-b97cfb0ad68b.png', 1, true, true, v_tax10, v_tenant
where not exists (select 1 from public.products p where p.tenant_id = v_tenant and p.name = 'Chocolate Lava Cake');

-- ─── Floor & tables (design layout) ──────────────────────────
insert into public.floors (name, background_color, is_active, tenant_id)
select 'Main Floor', '#1a1a2e', true, v_tenant
where not exists (select 1 from public.floors f where f.tenant_id = v_tenant and f.name = 'Main Floor')
returning id into v_floor;

if v_floor is null then select id into v_floor from public.floors where tenant_id = v_tenant and name = 'Main Floor' limit 1; end if;

insert into public.tables (floor_id, name, capacity, status, guest, persons, x, y, width, height, shape, zone, tenant_id)
select v_floor, t.tname, t.cap, t.st, t.guest, t.pax, t.x, 40, 100, 100, 0, t.zone, v_tenant
from (values
    ('T1', 2, 0, null::text, null::int, 20,  'Indoor'),
    ('T2', 4, 0, null, null, 140, 'Indoor'),
    ('T3', 4, 1, 'Jhon Cena', 4, 260, 'Indoor'),
    ('T4', 2, 0, null, null, 380, 'Indoor'),
    ('T5', 4, 0, null, null, 20,  'Indoor'),
    ('T6', 4, 0, null, null, 140, 'Indoor'),
    ('T7', 2, 1, 'Kathryn M.', 2, 260, 'Indoor'),
    ('T8', 6, 0, null, null, 380, 'Indoor'),
    ('T9', 2, 0, null, null, 560, 'Terrace'),
    ('T10', 4, 2, 'Kathryn P.', 4, 560, 'Terrace'),
    ('T11', 4, 0, null, null, 20,  'Terrace'),
    ('T12', 6, 0, null, null, 140, 'Terrace'),
    ('B1', 2, 0, null, null, 20,  'Bar'),
    ('B2', 2, 1, 'Walk-in', 1, 140, 'Bar'),
    ('P1', 8, 0, null, null, 300, 'Private')
) as t(tname, cap, st, guest, pax, x, zone)
where not exists (select 1 from public.tables tb where tb.tenant_id = v_tenant and tb.name = t.tname);

-- Apply the design layout (zone + x position) to tables that already
-- exist from earlier seeds, and mark the demo-occupied ones.
update public.tables tb set
    zone = src.zone,
    x    = src.x
from (values
    ('T1','Indoor',20), ('T2','Indoor',140), ('T3','Indoor',260), ('T4','Indoor',380),
    ('T5','Indoor',20), ('T6','Indoor',140), ('T7','Indoor',260), ('T8','Indoor',380),
    ('T9','Terrace',560), ('T10','Terrace',560), ('T11','Terrace',20), ('T12','Terrace',140),
    ('B1','Bar',20), ('B2','Bar',140), ('P1','Private',300)
) as src(name, zone, x)
where tb.tenant_id = v_tenant and tb.name = src.name;

update public.tables tb set
    status = src.st, guest = src.guest, persons = src.pax
from (values
    ('T3',  1, 'Jhon Cena',  4),
    ('T5',  1, null,         4),
    ('T7',  1, 'Kathryn M.', 2),
    ('B2',  1, 'Walk-in',    1),
    ('T10', 2, 'Kathryn P.', 4)
) as src(name, st, guest, pax)
where tb.tenant_id = v_tenant and tb.name = src.name;

-- ─── Customers ───────────────────────────────────────────────
insert into public.customers (name, phone, email, visits, total_spent, points, tier, last_visit_at, notes, tenant_id)
select 'Jessica Alba', '+34 612 345 001', 'jessica@example.com', 24, 412.50, 412, 'Silver', now() - interval '2 days', 'Vegetarian', v_tenant
where not exists (select 1 from public.customers c where c.tenant_id = v_tenant and c.phone = '+34 612 345 001');

insert into public.customers (name, phone, email, visits, total_spent, points, tier, last_visit_at, notes, tenant_id)
select 'Sofía Martínez', '+34 622 345 002', 'sofia.m@example.com', 47, 986.20, 986, 'Silver', now(), 'None', v_tenant
where not exists (select 1 from public.customers c where c.tenant_id = v_tenant and c.phone = '+34 622 345 002');

insert into public.customers (name, phone, email, visits, total_spent, points, tier, last_visit_at, notes, tenant_id)
select 'Diego Torres', '+34 633 345 003', 'diego.t@example.com', 18, 287.40, 287, 'Bronze', now() - interval '7 days', 'Gluten-free', v_tenant
where not exists (select 1 from public.customers c where c.tenant_id = v_tenant and c.phone = '+34 633 345 003');

insert into public.customers (name, phone, email, visits, total_spent, points, tier, last_visit_at, notes, tenant_id)
select 'Arkel Hikmat', '+34 644 345 004', 'arkel@example.com', 62, 2148.30, 2148, 'Gold', now(), 'None', v_tenant
where not exists (select 1 from public.customers c where c.tenant_id = v_tenant and c.phone = '+34 644 345 004');

insert into public.customers (name, phone, email, visits, total_spent, points, tier, last_visit_at, notes, tenant_id)
select 'Lucía Romero', '+34 655 345 005', 'lucia.r@example.com', 9, 142.80, 142, 'Bronze', now() - interval '3 days', 'Vegan', v_tenant
where not exists (select 1 from public.customers c where c.tenant_id = v_tenant and c.phone = '+34 655 345 005');

insert into public.customers (name, phone, email, visits, total_spent, points, tier, last_visit_at, notes, tenant_id)
select 'Pablo García', '+34 666 345 006', 'pablo.g@example.com', 31, 678.90, 678, 'Silver', now() - interval '1 day', 'None', v_tenant
where not exists (select 1 from public.customers c where c.tenant_id = v_tenant and c.phone = '+34 666 345 006');

-- ─── Suppliers ───────────────────────────────────────────────
insert into public.suppliers (name, contact, phone, email, category, terms, address, tenant_id)
select 'Makro España S.A.', 'Carlos Mendoza', '+34 91 555 0100', 'ventas@makro.es', 'Food & Beverages', '30 days', 'Polígono Industrial Cobo Calleja, Madrid', v_tenant
where not exists (select 1 from public.suppliers s where s.tenant_id = v_tenant and s.name = 'Makro España S.A.');

insert into public.suppliers (name, contact, phone, email, category, terms, address, tenant_id)
select 'Cárnicas Segovia', 'Javier Pastor', '+34 921 555 0300', 'comercial@carnicassegovia.es', 'Meat & Seafood', 'COD', 'Segovia, Castilla y León', v_tenant
where not exists (select 1 from public.suppliers s where s.tenant_id = v_tenant and s.name = 'Cárnicas Segovia');

insert into public.suppliers (name, contact, phone, email, category, terms, address, tenant_id)
select 'Pescados Mar Azul', 'María Castro', '+34 986 555 0400', 'ventas@marazul.es', 'Meat & Seafood', 'COD', 'Vigo, Pontevedra', v_tenant
where not exists (select 1 from public.suppliers s where s.tenant_id = v_tenant and s.name = 'Pescados Mar Azul');

insert into public.suppliers (name, contact, phone, email, category, terms, address, tenant_id)
select 'Lácteos Picos de Europa', 'Beatriz Ortega', '+34 985 555 0500', 'comercial@lacteospe.es', 'Dairy', '15 days', 'Cangas de Onís, Asturias', v_tenant
where not exists (select 1 from public.suppliers s where s.tenant_id = v_tenant and s.name = 'Lácteos Picos de Europa');

insert into public.suppliers (name, contact, phone, email, category, terms, address, tenant_id)
select 'Panadería La Espiga', 'Diego Romero', '+34 91 555 0600', 'horno@laespiga.es', 'Bakery', 'COD', 'Madrid Centro', v_tenant
where not exists (select 1 from public.suppliers s where s.tenant_id = v_tenant and s.name = 'Panadería La Espiga');

insert into public.suppliers (name, contact, phone, email, category, terms, address, tenant_id)
select 'Froiz Logística', 'Ana Vidal', '+34 981 555 0200', 'pedidos@froiz.es', 'Food & Beverages', '15 days', 'A Coruña, Galicia', v_tenant
where not exists (select 1 from public.suppliers s where s.tenant_id = v_tenant and s.name = 'Froiz Logística');

-- ─── Inventory ───────────────────────────────────────────────
insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Beef Patty 100g', 'Meat', 'MT-PTTY-100', 42, 'units', 0.85, 20, 'Cárnicas Segovia', '2026-08-15', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'MT-PTTY-100');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Pizza Dough', 'Bakery', 'BK-DOUGH-30', 18, 'units', 1.20, 15, 'Panadería La Espiga', '2026-08-10', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'BK-DOUGH-30');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Mozzarella Cheese', 'Dairy', 'DA-MOZ-1KG', 8.5, 'kg', 6.40, 5, 'Lácteos Picos de Europa', '2026-08-20', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'DA-MOZ-1KG');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Fresh Tomato', 'Vegetables', 'VG-TOM-1KG', 24, 'kg', 1.80, 10, 'Makro España S.A.', '2026-08-12', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'VG-TOM-1KG');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Salmon Fillet', 'Meat & Seafood', 'SF-SALM-1KG', 6.8, 'kg', 18.50, 4, 'Pescados Mar Azul', '2026-08-08', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'SF-SALM-1KG');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Coca-Cola Can 330ml', 'Beverages', 'BV-CC-330', 120, 'units', 0.45, 48, 'Makro España S.A.', '2026-12-31', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'BV-CC-330');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Cooking Oil 5L', 'Dry goods', 'DG-OIL-5L', 4, 'L', 8.20, 6, 'Makro España S.A.', '2027-01-15', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'DG-OIL-5L');

insert into public.inventory (name, category, sku, quantity, unit, cost, reorder_level, supplier_name, expiry, tenant_id)
select 'Dish Soap 5L', 'Cleaning', 'CL-DS-5L', 2, 'L', 4.50, 5, 'Makro España S.A.', '2028-06-01', v_tenant
where not exists (select 1 from public.inventory i where i.tenant_id = v_tenant and i.sku = 'CL-DS-5L');

-- ─── Gift cards ──────────────────────────────────────────────
insert into public.gift_cards (code, amount, balance, recipient, issued_at, expires_at, status, tenant_id)
select 'BP-GC-7H2K9A', 25.00, 18.50, 'Jessica Alba', now() - interval '24 days', now() + interval '180 days', 'Active', v_tenant
where not exists (select 1 from public.gift_cards g where g.tenant_id = v_tenant and g.code = 'BP-GC-7H2K9A');

insert into public.gift_cards (code, amount, balance, recipient, issued_at, expires_at, status, tenant_id)
select 'BP-GC-3M8X2F', 50.00, 50.00, 'Pablo García', now() - interval '14 days', now() + interval '360 days', 'Active', v_tenant
where not exists (select 1 from public.gift_cards g where g.tenant_id = v_tenant and g.code = 'BP-GC-3M8X2F');

insert into public.gift_cards (code, amount, balance, recipient, issued_at, expires_at, status, tenant_id)
select 'BP-GC-9P4K1Q', 100.00, 0.00, 'Arkel Hikmat', now() - interval '62 days', now() + interval '300 days', 'Redeemed', v_tenant
where not exists (select 1 from public.gift_cards g where g.tenant_id = v_tenant and g.code = 'BP-GC-9P4K1Q');

insert into public.gift_cards (code, amount, balance, recipient, issued_at, expires_at, status, tenant_id)
select 'BP-GC-5L6Z8W', 15.00, 15.00, '', now() - interval '10 days', now() + interval '180 days', 'Active', v_tenant
where not exists (select 1 from public.gift_cards g where g.tenant_id = v_tenant and g.code = 'BP-GC-5L6Z8W');

-- ─── Branch ──────────────────────────────────────────────────
insert into public.branches (name, full_name, city, cif, manager, terminals, status, tenant_id)
select 'Gran Vía', 'DashTab Madrid · Gran Vía', 'Madrid', 'B-12345678', 'Reda Bayi', 3, 'active', v_tenant
where not exists (select 1 from public.branches b where b.tenant_id = v_tenant and b.name = 'Gran Vía');

-- ─── Purchase orders ─────────────────────────────────────────
insert into public.purchase_orders (po_number, supplier_name, items_count, total, expected_at, status, tenant_id)
select 'PO-2026-0042', 'Makro España S.A.', 8, 482.30, current_date + 2, 'Pending', v_tenant
where not exists (select 1 from public.purchase_orders po where po.tenant_id = v_tenant and po.po_number = 'PO-2026-0042');

insert into public.purchase_orders (po_number, supplier_name, items_count, total, expected_at, status, tenant_id)
select 'PO-2026-0041', 'Cárnicas Segovia', 5, 318.90, current_date, 'Received', v_tenant
where not exists (select 1 from public.purchase_orders po where po.tenant_id = v_tenant and po.po_number = 'PO-2026-0041');

insert into public.purchase_orders (po_number, supplier_name, items_count, total, expected_at, status, tenant_id)
select 'PO-2026-0040', 'Pescados Mar Azul', 4, 672.50, current_date - 1, 'Partial', v_tenant
where not exists (select 1 from public.purchase_orders po where po.tenant_id = v_tenant and po.po_number = 'PO-2026-0040');

-- ─── Orders ──────────────────────────────────────────────────
-- Open orders (Pending) on occupied tables
insert into public.orders (order_number, order_type, status, table_id, waiter_id, subtotal, tax_amount, discount_amount, total, notes, created_at, tenant_id)
select '907663', 0, 0, t.id, v_pub_waiter, 18.48, 1.85, 0, 20.33, null, now() - interval '36 minutes', v_tenant
from public.tables t where t.tenant_id = v_tenant and t.name = 'T3'
on conflict do nothing;

insert into public.orders (order_number, order_type, status, table_id, waiter_id, subtotal, tax_amount, discount_amount, total, notes, created_at, tenant_id)
select '907662', 0, 0, t.id, v_pub_waiter, 19.48, 2.83, 0, 22.31, null, now() - interval '53 minutes', v_tenant
from public.tables t where t.tenant_id = v_tenant and t.name = 'T7'
on conflict do nothing;

-- In the kitchen pipeline
insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, notes, created_at, tenant_id)
select '907661', 1, 1, 19.89, 1.99, 0, 21.88, null, now() - interval '18 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, notes, created_at, tenant_id)
select '907660', 2, 1, 25.20, 2.96, 0, 28.16, 'Ring bell on arrival', now() - interval '12 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, table_id, waiter_id, subtotal, tax_amount, discount_amount, total, notes, created_at, tenant_id)
select '907659', 0, 3, t.id, v_pub_waiter, 21.80, 2.18, 0, 23.98, null, now() - interval '7 minutes', v_tenant
from public.tables t where t.tenant_id = v_tenant and t.name = 'T5'
on conflict do nothing;

-- Paid orders (tables freed, so table_id is null)
insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, payment_method, invoice_number, tip_amount, factura_type, customer_nif, closed_at, created_at, tenant_id)
select '907658', 0, 6, 21.68, 2.61, 0, 24.29, 'Card', 'FAC/A/2026/00423', 0, 'simplificada', null, now() - interval '90 minutes', now() - interval '95 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, payment_method, invoice_number, tip_amount, factura_type, customer_nif, closed_at, created_at, tenant_id)
select '907657', 1, 6, 13.40, 1.34, 0, 14.74, 'Cash', 'FAC/A/2026/00424', 1.47, 'simplificada', null, now() - interval '2 hours', now() - interval '2 hours 5 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, payment_method, invoice_number, tip_amount, factura_type, customer_nif, closed_at, created_at, tenant_id)
select '907656', 2, 6, 25.29, 2.53, 0, 27.82, 'Bizum', 'FAC/A/2026/00425', 0, 'completa', 'A12345678', now() - interval '3 hours', now() - interval '3 hours 10 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, payment_method, invoice_number, tip_amount, factura_type, customer_nif, closed_at, created_at, tenant_id)
select '907655', 0, 5, 24.70, 2.47, 0, 27.17, null, null, 0, null, null, now() - interval '4 hours', now() - interval '4 hours 20 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, payment_method, invoice_number, tip_amount, factura_type, customer_nif, closed_at, created_at, tenant_id)
select '907654', 0, 6, 23.20, 3.31, 0, 26.51, 'Cash', 'FAC/A/2026/00426', 0, 'simplificada', null, now() - interval '5 hours', now() - interval '5 hours 15 minutes', v_tenant
on conflict do nothing;

insert into public.orders (order_number, order_type, status, subtotal, tax_amount, discount_amount, total, payment_method, invoice_number, tip_amount, factura_type, customer_nif, closed_at, created_at, tenant_id)
select '907653', 1, 6, 11.49, 1.99, 0, 13.48, 'Bizum', 'FAC/A/2026/00427', 0, 'simplificada', null, now() - interval '6 hours', now() - interval '6 hours 20 minutes', v_tenant
on conflict do nothing;

-- ─── Order items ─────────────────────────────────────────────
-- 907663 (Pending, T3)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 10, 1.50, 14.98, 14.98, null, 0, 0, v_tenant
from public.orders o, public.products p where o.order_number = '907663' and p.name = 'Classic Cheeseburger' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.35, 3.50, 3.50, null, 0, 0, v_tenant
from public.orders o, public.products p where o.order_number = '907663' and p.name = 'Crispy French Fries' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907662 (Pending, T7)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 1.15, 11.48, 11.48, null, 0, 0, v_tenant
from public.orders o, public.products p where o.order_number = '907662' and p.name = 'Margherita Pizza' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 21, 1.68, 8.00, 8.00, null, 0, 0, v_tenant
from public.orders o, public.products p where o.order_number = '907662' and p.name = 'Fresh Orange Juice' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907661 (Preparing, kitchen — Incoming)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.75, 7.49, 7.49, null, 1, 0, v_tenant
from public.orders o, public.products p where o.order_number = '907661' and p.name = 'Italian Salad' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 10, 1.24, 12.40, 12.40, 'Extra warm', 1, 0, v_tenant
from public.orders o, public.products p where o.order_number = '907661' and p.name = 'Chocolate Lava Cake' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907660 (Preparing, kitchen — Preparing)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 1.42, 14.20, 14.20, null, 1, 1, v_tenant
from public.orders o, public.products p where o.order_number = '907660' and p.name = 'Super Supreme Pizza' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 10, 0.70, 7.00, 7.00, null, 1, 1, v_tenant
from public.orders o, public.products p where o.order_number = '907660' and p.name = 'Crispy French Fries' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 21, 0.84, 4.00, 4.00, null, 1, 1, v_tenant
from public.orders o, public.products p where o.order_number = '907660' and p.name = 'Fresh Orange Juice' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907659 (Ready — kitchen Ready)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 10, 2.18, 21.80, 21.80, null, 1, 2, v_tenant
from public.orders o, public.products p where o.order_number = '907659' and p.name = 'Spaghetti Bolognese' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907658 (Paid — Card)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 1.15, 11.48, 11.48, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907658' and p.name = 'Margherita Pizza' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 21, 0.84, 4.00, 4.00, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907658' and p.name = 'Fresh Orange Juice' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.62, 6.20, 6.20, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907658' and p.name = 'Chocolate Lava Cake' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907657 (Paid — Cash)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.99, 9.90, 9.90, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907657' and p.name = 'Double Smash Burger' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.35, 3.50, 3.50, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907657' and p.name = 'Crispy French Fries' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907656 (Paid — Bizum)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 10, 1.78, 17.80, 17.80, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907656' and p.name = 'Grilled Chicken Melt' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.75, 7.49, 7.49, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907656' and p.name = 'Italian Salad' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907654 (Paid — Cash)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 1.42, 14.20, 14.20, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907654' and p.name = 'Super Supreme Pizza' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 2, p.price, 0, 21, 1.89, 9.00, 9.00, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907654' and p.name = 'Iced Cappuccino' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- 907653 (Paid — Bizum)
insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 10, 0.75, 7.49, 7.49, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907653' and p.name = 'Classic Cheeseburger' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

insert into public.order_items (order_id, product_id, product_name, quantity, unit_price, discount_amount, tax_rate, tax_amount, subtotal, total, notes, status, kitchen_stage, tenant_id)
select o.id, p.id, p.name, 1, p.price, 0, 21, 0.84, 4.00, 4.00, null, 2, 3, v_tenant
from public.orders o, public.products p where o.order_number = '907653' and p.name = 'Fresh Orange Juice' and p.tenant_id = v_tenant and o.tenant_id = v_tenant
on conflict do nothing;

-- ─── Payments (for paid orders) ──────────────────────────────
insert into public.payments (order_id, payment_method_id, amount, tip_amount, change_amount, status, reference, tenant_id)
select o.id, pm.id, o.total, o.tip_amount, 0, 0, o.invoice_number, v_tenant
from public.orders o, public.payment_methods pm
where o.order_number = '907658' and pm.name = 'Card' and o.tenant_id = v_tenant and pm.tenant_id = v_tenant
on conflict do nothing;

insert into public.payments (order_id, payment_method_id, amount, tip_amount, change_amount, status, reference, tenant_id)
select o.id, pm.id, o.total, o.tip_amount, 0, 0, o.invoice_number, v_tenant
from public.orders o, public.payment_methods pm
where o.order_number = '907657' and pm.name = 'Cash' and o.tenant_id = v_tenant and pm.tenant_id = v_tenant
on conflict do nothing;

insert into public.payments (order_id, payment_method_id, amount, tip_amount, change_amount, status, reference, tenant_id)
select o.id, pm.id, o.total, o.tip_amount, 0, 0, o.invoice_number, v_tenant
from public.orders o, public.payment_methods pm
where o.order_number = '907656' and pm.name = 'Bizum' and o.tenant_id = v_tenant and pm.tenant_id = v_tenant
on conflict do nothing;

insert into public.payments (order_id, payment_method_id, amount, tip_amount, change_amount, status, reference, tenant_id)
select o.id, pm.id, o.total, o.tip_amount, 0, 0, o.invoice_number, v_tenant
from public.orders o, public.payment_methods pm
where o.order_number = '907654' and pm.name = 'Cash' and o.tenant_id = v_tenant and pm.tenant_id = v_tenant
on conflict do nothing;

insert into public.payments (order_id, payment_method_id, amount, tip_amount, change_amount, status, reference, tenant_id)
select o.id, pm.id, o.total, o.tip_amount, 0, 0, o.invoice_number, v_tenant
from public.orders o, public.payment_methods pm
where o.order_number = '907653' and pm.name = 'Bizum' and o.tenant_id = v_tenant and pm.tenant_id = v_tenant
on conflict do nothing;

-- ─── Open shift + cash drawer (opened by the cashier) ────────
insert into public.shifts (user_id, opened_at, opening_cash, cash_sales, cash_refunds, cash_in_out, status, tenant_id)
select v_pub_cashier, now() - interval '3 hours', 150.00, 41.25, 0, 26.50, 0, v_tenant
where not exists (select 1 from public.shifts s where s.tenant_id = v_tenant and s.status = 0)
returning id into v_shift;

if v_shift is not null then
    insert into public.cash_drawer_transactions (shift_id, type, amount, reason, user_id, tenant_id)
    values (v_shift, 0, 150.00, 'Opening float', v_pub_cashier, v_tenant);

    insert into public.cash_drawer_transactions (shift_id, type, amount, reason, user_id, tenant_id)
    select v_shift, 0, 26.50, 'Float top-up', v_pub_cashier, v_tenant
    where not exists (select 1 from public.cash_drawer_transactions t where t.shift_id = v_shift and t.reason = 'Float top-up');
end if;

-- ─── Audit trail ─────────────────────────────────────────────
insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values, tenant_id)
select v_pub_cashier, 'Order #907658 paid', 'pay', '907658', '€24.29 via Card · FAC/A/2026/00423', v_tenant
where not exists (select 1 from public.audit_logs a where a.tenant_id = v_tenant and a.entity_id = '907658' and a.action = 'Order #907658 paid');

insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values, tenant_id)
select v_pub_manager, 'New product created', 'create', '1', 'Tuna Croissant · €7.90 · IVA 10%', v_tenant
where not exists (select 1 from public.audit_logs a where a.tenant_id = v_tenant and a.action = 'New product created');

insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values, tenant_id)
select v_pub_cashier, 'Cash drawer opened', 'auth', 'shift', 'Shift opened · Float €150.00', v_tenant
where not exists (select 1 from public.audit_logs a where a.tenant_id = v_tenant and a.action = 'Cash drawer opened');

insert into public.audit_logs (user_id, action, entity_type, entity_id, new_values, tenant_id)
select v_pub_owner, 'User logged in', 'auth', 'owner@dashtab.app', 'Branch: Gran Vía · Terminal A', v_tenant
where not exists (select 1 from public.audit_logs a where a.tenant_id = v_tenant and a.action = 'User logged in');

-- ─── Notifications ───────────────────────────────────────────
insert into public.notifications (title, subtitle, kind, unread, tenant_id)
select 'Order #907658 paid successfully', '€24.29 · Card', 'ok', true, v_tenant
where not exists (select 1 from public.notifications n where n.tenant_id = v_tenant and n.title = 'Order #907658 paid successfully');

insert into public.notifications (title, subtitle, kind, unread, tenant_id)
select 'Low stock alert', 'Iced Cappuccino · 2 left', 'warn', true, v_tenant
where not exists (select 1 from public.notifications n where n.tenant_id = v_tenant and n.title = 'Low stock alert');

insert into public.notifications (title, subtitle, kind, unread, tenant_id)
select 'Gift card BP-GC-7H2K9A issued', '€25.00 · Customer: Jessica Alba', 'ok', false, v_tenant
where not exists (select 1 from public.notifications n where n.tenant_id = v_tenant and n.title like 'Gift card BP-GC-7H2K9A%');

insert into public.notifications (title, subtitle, kind, unread, tenant_id)
select 'Day closed · Z-Report generated', 'Cash €1.847,20 · 42 orders', 'ok', false, v_tenant
where not exists (select 1 from public.notifications n where n.tenant_id = v_tenant and n.title like 'Day closed%');

-- ─── Product costs (supplier cost per dish → real margins/profit) ──
update public.products set cost = 2.65 where tenant_id = v_tenant and name = 'Classic Cheeseburger';
update public.products set cost = 3.40 where tenant_id = v_tenant and name = 'Double Smash Burger';
update public.products set cost = 3.10 where tenant_id = v_tenant and name = 'Margherita Pizza';
update public.products set cost = 4.35 where tenant_id = v_tenant and name = 'Super Supreme Pizza';
update public.products set cost = 2.90 where tenant_id = v_tenant and name = 'Grilled Chicken Melt';
update public.products set cost = 2.70 where tenant_id = v_tenant and name = 'Beef BLT Sandwich';
update public.products set cost = 0.85 where tenant_id = v_tenant and name = 'Crispy French Fries';
update public.products set cost = 2.10 where tenant_id = v_tenant and name = 'Hot Fried Chicken';
update public.products set cost = 2.30 where tenant_id = v_tenant and name = 'Italian Salad';
update public.products set cost = 3.20 where tenant_id = v_tenant and name = 'Spaghetti Bolognese';
update public.products set cost = 0.95 where tenant_id = v_tenant and name = 'Fresh Orange Juice';
update public.products set cost = 0.80 where tenant_id = v_tenant and name = 'Iced Cappuccino';
update public.products set cost = 1.75 where tenant_id = v_tenant and name = 'Chocolate Lava Cake';

-- ─── Promo codes (manageable from Settings → Promo Codes) ────
insert into public.discounts (name, type, value, is_active, tenant_id)
select 'HOTO10', 0, 10, true, v_tenant
where not exists (select 1 from public.discounts d where d.tenant_id = v_tenant and d.name = 'HOTO10');

insert into public.discounts (name, type, value, is_active, tenant_id)
select 'MENUDIA', 1, 2.50, true, v_tenant
where not exists (select 1 from public.discounts d where d.tenant_id = v_tenant and d.name = 'MENUDIA');

-- ─── Workspace settings (receipt/invoice identity) ───────────
insert into public.settings (key, value, tenant_id)
values
    ('legal_name', 'DashTab Restaurantes S.L.', v_tenant),
    ('cif', 'B-87654321', v_tenant),
    ('invoice_prefix', 'FAC/A/', v_tenant)
on conflict (tenant_id, key) do update set value = excluded.value, updated_at = now();

-- ─── Counters (resume numbering) ─────────────────────────────
insert into public.counters (tenant_id, name, value)
values (v_tenant, 'orders', 907664), (v_tenant, 'invoice', 427)
on conflict (tenant_id, name) do update set value = greatest(counters.value, excluded.value);

end $$;

-- ============================================================
-- Verification
-- ============================================================
select 'auth users' as what, count(*) as cnt from auth.users where raw_app_meta_data->>'tenant_id' = (select id::text from public.tenants where slug = 'demo');
select 'products' as what, count(*) as cnt from public.products where tenant_id = (select id from public.tenants where slug = 'demo');
select 'orders' as what, count(*) as cnt from public.orders where tenant_id = (select id from public.tenants where slug = 'demo');
select 'tables' as what, count(*) as cnt from public.tables where tenant_id = (select id from public.tenants where slug = 'demo');
select 'customers' as what, count(*) as cnt from public.customers where tenant_id = (select id from public.tenants where slug = 'demo');
