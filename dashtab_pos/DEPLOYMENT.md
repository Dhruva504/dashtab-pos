# DashTab POS — Deployment & Operations Runbook

This document walks a fresh deployment from an empty Supabase project to a
working, market-launchable POS install. The app has **no demo data layer** —
every screen reads from and writes to Supabase.

## 1. Architecture in one paragraph

- **Flutter desktop app** (Windows/Android/iOS/web) talks directly to Supabase
  using the anon key. Row Level Security (RLS) scopes every query to the
  authenticated tenant via a `tenant_id` JWT claim.
- **Tenant model**: one restaurant/workspace = one `tenants` row. The first
  user who registers gets a workspace created automatically
  (`public.bootstrap_tenant` RPC) and their JWT stamped with `tenant_id`.
- **The store**: `lib/core/theme/demo_data.dart` exposes `demo` — a
  `ChangeNotifier` facade that mirrors the design's data model. `demo.init()`
  loads everything after login; every mutation persists to Supabase in the
  background; realtime/polling keeps orders, tables and the kitchen board live.
- **Fiscal**: orders carry invoice numbers, payment method, tip, factura type
  and customer NIF. Audit logs are insert-only.

## 2. Apply the database schema

Open your Supabase project → **SQL Editor** and run the migrations **in
order**. They are idempotent (`create ... if not exists`).

1. `supabase/migrations/001_schema.sql` — core tables
2. `supabase/migrations/002_rls_policies.sql` — RLS + tenant helpers
3. `supabase/migrations/003_views.sql` — order-number trigger, kitchen view
4. `supabase/migrations/004_seed.sql` — intentionally empty (workspaces are
   provisioned per account by `bootstrap_tenant` on first login)
5. `supabase/migrations/006_missing_tables.sql` — settings, shifts, roles
6. `supabase/migrations/007_rls_new_tables.sql` — RLS for those
7. `supabase/migrations/008_launch_schema.sql` — **required for launch**:
   suppliers, purchase orders, gift cards, notifications, branches, counters,
   the extra display columns, `next_counter` and `bootstrap_tenant` RPCs
8. `supabase/migrations/009_staff_provisioning.sql` — **required for staff
   accounts**: the `create_staff_user` RPC (owners/managers provision real
   logins for staff from the app) and the audit-log user foreign key

`005_rls_verification.sql` is a verification/QA script — run it in a staging
project, not production.

> `bootstrap_tenant` uses `auth.set_claim`, available on Supabase projects
> running Postgres 15 + newer platform images (all projects created after
> mid-2023). On older images, replace the `set_tenant_claim` function body
> with the classic `raw_app_meta_data` update via the admin API.

## 3. Project configuration (Auth)

1. **Auth → Providers** → enable Email. Recommended for a POS:
   - Disable *Confirm email* for instant onboarding, **or** keep it on — the
     app shows a clear "confirm your email" message and the user then logs in.
   - Optionally disable *Confirm phone*.
2. **Auth → URL Configuration** — no action needed for the desktop app.
3. **Realtime**: ensure the live board works (orders, tables, kitchen). In
   **Database → Publications**, add `supabase_realtime` to these tables:
   `orders`, `order_items`, `tables`. If you leave it out, the app falls back
   to a 20-second poll — fine but not as snappy.

## 4. Build the app

The Supabase URL and anon key are compiled in. They can be overridden per
environment without code changes:

```bash
cd dashtab_pos
flutter build windows --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

The anon key is the **publishable** key — RLS is the security boundary, never
ship a service-role key in a client.

## 5. First run (onboarding)

1. Launch the app → **"New here? Create your workspace"**.
2. Enter restaurant name, your name, email and password.
3. The backend creates the tenant, links your user as **Owner**, seeds the
   default payment methods (Cash / Card / Bizum / Gift Card), IVA rates
   (21/10/4%), a Main Floor with 13 tables and the first branch, then stamps
   your JWT with the tenant claim. You land on a fully working dashboard.
4. From **Settings → Restaurant** set your legal name, CIF, invoice prefix,
   address and contact details — these appear on receipts and invoices.

Staff accounts are provisioned from inside the app: an Owner or Manager adds
the person in **Staff** with an email and a temporary password, and the
`create_staff_user` RPC (009) creates the auth user, links it to the same
workspace and stamps the tenant claim. The staff member then signs in with
those credentials on any terminal.

### 5a. Test data (testing/staging only — not for production launch)

The app is empty until a workspace is onboarded. For UAT and demo purposes
run `supabase/seed_test_data.sql` in the SQL Editor **after** migrations
001–009. It creates a fully populated "DashTab Madrid · Gran Vía" workspace:

- **6 real auth users** (all pre-confirmed, password `Dashtab123!`):
  `owner@dashtab.app` (Owner), `mostapha@dashtab.app` (Manager),
  `samantha@dashtab.app` (Cashier), `maja@dashtab.app` (Chef),
  `lucia@dashtab.app` (Waiter), `carlos@dashtab.app` (Kitchen Staff)
- The full design menu (13 products with images, supplier costs, IVA
  21/10/4%, categories), 15 tables in 4 zones with 4 open orders, 6 customers,
  6 suppliers, 8 inventory items, 4 gift cards, 3 purchase orders, 8 orders
  (open / kitchen / paid) with line items and payments, an open shift with cash
  drawer movements, audit log, notifications, two promo codes (`HOTO10` = 10%
  off, `MENUDIA` = €2.50 off — manageable in Settings → Promo Codes), the
  workspace fiscal settings (legal name, CIF, invoice prefix `FAC/A/`) and the
  invoice/order counters resumed (next order `907664`).

It is **safe to re-run**: it upserts the tenant by slug, users by email
(auth.users uses a partial unique index, so the seed upserts via an explicit
loop, not `on conflict (email)`), guards every other insert with
`where not exists`, and never moves counters backwards. Existing auth users
keep their ids; their password/metadata is refreshed to the test values.

Delete the rows (or skip this file) before a clean production launch.

## 6. Release checklist

- [ ] Migrations 001–009 applied; `005` verification passed on staging
- [ ] Email auth enabled; confirmation policy chosen
- [ ] Realtime publication includes `orders`, `order_items`, `tables`
- [ ] Backups scheduled (Supabase project → Backups → enable daily, PITR for
      production)
- [ ] Build with `--dart-define` pointing at the **production** project
- [ ] Smoke test: register → add products → table check-in → POS order →
      send to kitchen → payment (cash + card + gift card) → refund →
      shift open/close (Z-Report) → settings persist across relaunch
- [ ] Spanish fiscal launch: engage an *asesor fiscal* — the system provides
      sequential invoicing, factura simplificada/completa, NIF capture, the
      insert-only audit log and cash-drawer Z-reports, but **does not**
      provide AEAT/Verifactu certification; connect a certified Verifactu
      provider if your obligation profile requires it

## 7. Known limitations & next milestones

These are deliberately scoped out of the first release and tracked for the
maintenance phase:

- **Branch switching** currently selects a branch for display; data is
  tenant-wide (one branch = one workspace at launch). Per-branch scoping of
  orders is the natural next step.
- **Invoice numbering** uses an atomic per-tenant counter RPC but the client
  displays an optimistic number before the RPC returns; two terminals charging
  simultaneously could theoretically show the same number briefly. The DB row
  always gets its number from the counter on write.
- **Multi-terminal** race on *order numbers* is avoided (no unique constraint)
  but worth adding a `unique (tenant_id, order_number)` once one-branch
  deployments are validated.
- **Connectivity**: the app requires internet — every write goes straight to
  Supabase and failures surface in the sync banner. An offline order queue for
  selling through outages is a maintenance-phase feature.
- **Roles & Permissions**: each staff account stores its role and the RBAC
  tables exist (`roles`, `permissions`, `role_permissions`, `user_roles`), but
  per-view enforcement is not yet wired — every workspace member can use all
  screens. Server-side, only owners/managers may provision new staff.
- **Printing** uses the OS print dialog (`printing` package): 80 mm receipts
  from the payment modal / Orders, and A4 Z-reports from Shift. Direct
  ESC/POS printing to a specific network printer is a maintenance-phase
  enhancement.
- **Card & Bizum** payments are confirmed manually by the cashier (the app
  records the payment after the terminal/Bizum is approved); an automatic
  terminal integration is future work.
