-- ============================================================
-- DashTab POS – RLS Verification (Phase 7)
-- Creates test users for multiple tenants and verifies
-- complete tenant isolation via Row Level Security.
--
-- HOW TO RUN:
--   1. Open your Supabase project → SQL Editor
--   2. Run this script (it is idempotent)
--   3. Review the verification output at the bottom
-- ============================================================

-- ─── 1. Create a second test tenant ─────────────────────────
insert into public.tenants (name, slug, currency_code, locale, timezone)
values ('Test Restaurant B', 'test-b', 'INR', 'en-IN', 'Asia/Kolkata')
on conflict (slug) do nothing;

-- ─── 2. Create Supabase auth users for testing ──────────────
-- Note: These are created in auth.users (handled by Supabase Auth).
-- In the SQL editor you can create them via the Dashboard (Auth → Users)
-- or via the signUp API. The public.users rows below link to them.
--
-- For automated testing, use the Supabase Auth admin API or
-- the dashboard to create users with these emails:
--   tenant-a-owner@dashtab.test  (Demo Restaurant)
--   tenant-b-owner@dashtab.test  (Test Restaurant B)
--
-- ⚠️ CRITICAL: You MUST add `tenant_id` to each user's **app_metadata**
-- (NOT user_metadata). Supabase includes `app_metadata` in the JWT claims
-- but NOT `user_metadata`. RLS relies on `auth.jwt()->>'tenant_id'`, so
-- tenant_id must live in app_metadata for RLS to filter correctly.
-- This can be set in the Auth dashboard (Users → Edit → app_metadata)
-- or via the Admin API (see supabase/set_tenant_claims.ps1).

-- ─── 3. Link users to tenants (sample rows) ─────────────────
-- These assume the auth.users rows exist. Replace the user_id
-- values with the actual UUIDs from auth.users.
-- insert into public.users (user_id, email, full_name, is_active, tenant_id)
-- select au.id, au.email, 'Tenant A Owner', true, t.id
-- from auth.users au
-- cross join public.tenants t
-- where au.email = 'tenant-a-owner@dashtab.test'
--   and t.slug = 'demo'
--   and not exists (
--       select 1 from public.users u
--       where u.email = au.email and u.tenant_id = t.id
--   );

-- insert into public.users (user_id, email, full_name, is_active, tenant_id)
-- select au.id, au.email, 'Tenant B Owner', true, t.id
-- from auth.users au
-- cross join public.tenants t
-- where au.email = 'tenant-b-owner@dashtab.test'
--   and t.slug = 'test-b'
--   and not exists (
--       select 1 from public.users u
--       where u.email = au.email and u.tenant_id = t.id
--   );

-- ─── 4. Seed test data for the second tenant ─────────────────
insert into public.payment_methods (name, type, is_active, sort_order, tenant_id)
select 'Cash', 0, true, 1, t.id
from public.tenants t
where t.slug = 'test-b'
  and not exists (
      select 1 from public.payment_methods pm
      where pm.tenant_id = t.id and pm.name = 'Cash'
  );

insert into public.payment_methods (name, type, is_active, sort_order, tenant_id)
select 'Card', 1, true, 2, t.id
from public.tenants t
where t.slug = 'test-b'
  and not exists (
      select 1 from public.payment_methods pm
      where pm.tenant_id = t.id and pm.name = 'Card'
  );

insert into public.tax_rates (name, rate, is_inclusive, is_default, is_active, tenant_id)
select 'GST 5%', 5, true, true, true, t.id
from public.tenants t
where t.slug = 'test-b'
  and not exists (
      select 1 from public.tax_rates tr
      where tr.tenant_id = t.id and tr.name = 'GST 5%'
  );

insert into public.floors (name, background_color, is_active, tenant_id)
select 'Main Floor', '#1a1a2e', true, t.id
from public.tenants t
where t.slug = 'test-b'
  and not exists (
      select 1 from public.floors f
      where f.tenant_id = t.id and f.name = 'Main Floor'
  );

insert into public.tables (floor_id, name, capacity, status, x, y, width, height, shape, tenant_id)
select f.id, 'B' || gs, 4, 0, (gs - 1) * 120, 50, 100, 100, 0, f.tenant_id
from public.floors f
cross join generate_series(1, 4) as gs
where f.name = 'Main Floor'
  and not exists (
      select 1 from public.tables t
      where t.floor_id = f.id and t.name = 'B' || gs
  );

insert into public.categories (name, sort_order, is_active, tenant_id)
select 'Tenant B Starters', 1, true, t.id
from public.tenants t
where t.slug = 'test-b'
  and not exists (
      select 1 from public.categories c
      where c.tenant_id = t.id and c.name = 'Tenant B Starters'
  );

insert into public.products (category_id, name, price, sort_order, is_active, is_available, tenant_id)
select c.id, 'Tenant B Special', 199, 1, true, true, c.tenant_id
from public.categories c
where c.name = 'Tenant B Starters'
  and not exists (
      select 1 from public.products p
      where p.category_id = c.id and p.name = 'Tenant B Special'
  );

-- ─── 5. VERIFICATION QUERIES ─────────────────────────────────
-- Run these AFTER logging in as each test user (or use the
-- "Run as" feature in the SQL editor with a user's JWT).

-- 5a. Data isolation check: each tenant should only see its own data.
-- Expected: Tenant A sees only 'demo' rows; Tenant B sees only 'test-b' rows.

-- SELECT 'Tenant A products' as check_name, count(*) as cnt
-- FROM public.products
-- WHERE tenant_id = (select id from public.tenants where slug = 'demo');
--
-- SELECT 'Tenant B products' as check_name, count(*) as cnt
-- FROM public.products
-- WHERE tenant_id = (select id from public.tenants where slug = 'test-b');

-- 5b. Cross-tenant access attempt (should return 0 rows / error):
-- SELECT * FROM public.products
-- WHERE tenant_id = (select id from public.tenants where slug = 'test-b')
--   AND tenant_id <> public.current_tenant_id();

-- 5c. Service-role access (backend operations use service_role key).
-- The service_role bypasses RLS. Verify with:
-- SELECT * FROM public.products LIMIT 5;

-- 5d. Confirm RLS is enabled on all business tables:
select tablename
from pg_tables
where schemaname = 'public'
  and tablename in (
      'tenants','users','categories','products','floors','tables',
      'customers','orders','order_items','payment_methods','payments',
      'inventory','discounts','audit_logs','tax_rates'
  )
  and rowsecurity = true
order by tablename;

-- 5e. Confirm tenant_id auto-set trigger works:
-- Insert a product as a logged-in user WITHOUT specifying tenant_id,
-- then verify tenant_id equals the JWT's tenant_id.
