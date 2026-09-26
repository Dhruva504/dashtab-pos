-- ============================================================
-- DashTab POS – Launch Schema (Phase 8)
-- Completes the schema so every screen in the app is backed by
-- a real table: suppliers, purchase orders, gift cards,
-- notifications, branches, counters + bootstrap/onboarding RPC.
-- ============================================================

-- ─── Column additions (idempotent) ──────────────────────────
alter table public.products
    add column if not exists stock_qty numeric not null default 0,
    add column if not exists sold_count integer not null default 0;

alter table public.customers
    add column if not exists visits integer not null default 0,
    add column if not exists total_spent numeric not null default 0,
    add column if not exists points integer not null default 0,
    add column if not exists tier text not null default 'Bronze',
    add column if not exists last_visit_at timestamptz;

alter table public.users
    add column if not exists role text not null default 'Staff',
    add column if not exists phone text,
    add column if not exists hired_at date;

alter table public.tables
    add column if not exists guest text,
    add column if not exists persons integer,
    add column if not exists zone text not null default 'Indoor';

alter table public.order_items
    add column if not exists kitchen_stage integer not null default 0; -- 0=Incoming 1=Preparing 2=Ready 3=Done

alter table public.inventory
    add column if not exists category text,
    add column if not exists sku text,
    add column if not exists cost numeric not null default 0,
    add column if not exists supplier_name text,
    add column if not exists expiry date;

-- ─── Suppliers ──────────────────────────────────────────────
create table if not exists public.suppliers (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    contact         text,
    phone           text,
    email           text,
    category        text,
    terms           text,
    address         text,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Purchase Orders ────────────────────────────────────────
create table if not exists public.purchase_orders (
    id              uuid primary key default gen_random_uuid(),
    po_number       text not null,
    supplier_name   text not null,
    items_count     integer not null default 0,
    total           numeric not null default 0,
    expected_at     date,
    status          text not null default 'Pending', -- Pending | Partial | Received
    notes           text,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Gift Cards ─────────────────────────────────────────────
create table if not exists public.gift_cards (
    id              uuid primary key default gen_random_uuid(),
    code            text not null,
    amount          numeric not null default 0,
    balance         numeric not null default 0,
    recipient       text,
    issued_at       timestamptz not null default now(),
    expires_at      date,
    status          text not null default 'Active', -- Active | Redeemed | Expired
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now()
);

-- ─── Notifications ──────────────────────────────────────────
create table if not exists public.notifications (
    id              uuid primary key default gen_random_uuid(),
    title           text not null,
    subtitle        text,
    kind            text not null default 'ok', -- ok | warn | err
    unread          boolean not null default true,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now()
);

-- ─── Branches ───────────────────────────────────────────────
create table if not exists public.branches (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    full_name       text,
    city            text,
    cif             text,
    manager         text,
    terminals       integer not null default 1,
    status          text not null default 'active',
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Counters (order numbers, invoice numbers, PO numbers) ──
create table if not exists public.counters (
    tenant_id   uuid not null references public.tenants(id) on delete cascade,
    name        text not null,
    value       integer not null default 0,
    primary key (tenant_id, name)
);

-- ─── Indexes ────────────────────────────────────────────────
create index if not exists idx_suppliers_tenant on public.suppliers(tenant_id);
create index if not exists idx_purchase_orders_tenant on public.purchase_orders(tenant_id);
create index if not exists idx_gift_cards_tenant on public.gift_cards(tenant_id);
create index if not exists idx_gift_cards_code on public.gift_cards(code);
create index if not exists idx_notifications_tenant on public.notifications(tenant_id);
create index if not exists idx_branches_tenant on public.branches(tenant_id);

-- ─── Order display/fiscal columns (payment method, invoice, tip) ─
alter table public.orders
    add column if not exists payment_method text,
    add column if not exists invoice_number text,
    add column if not exists tip_amount numeric not null default 0,
    add column if not exists factura_type text,
    add column if not exists customer_nif text;

-- ─── Shift running totals (cash reconciliation) ─────────────
alter table public.shifts
    add column if not exists cash_sales numeric not null default 0,
    add column if not exists cash_refunds numeric not null default 0,
    add column if not exists cash_in_out numeric not null default 0;

-- ─── RLS on new tables ──────────────────────────────────────
alter table public.suppliers        enable row level security;
alter table public.purchase_orders  enable row level security;
alter table public.gift_cards       enable row level security;
alter table public.notifications    enable row level security;
alter table public.branches         enable row level security;
alter table public.counters         enable row level security;

create policy "suppliers_select" on public.suppliers
    for select using (tenant_id = public.current_tenant_id());
create policy "suppliers_insert" on public.suppliers
    for insert with check (tenant_id = public.current_tenant_id());
create policy "suppliers_update" on public.suppliers
    for update using (tenant_id = public.current_tenant_id());
create policy "suppliers_delete" on public.suppliers
    for delete using (tenant_id = public.current_tenant_id());

create policy "purchase_orders_select" on public.purchase_orders
    for select using (tenant_id = public.current_tenant_id());
create policy "purchase_orders_insert" on public.purchase_orders
    for insert with check (tenant_id = public.current_tenant_id());
create policy "purchase_orders_update" on public.purchase_orders
    for update using (tenant_id = public.current_tenant_id());
create policy "purchase_orders_delete" on public.purchase_orders
    for delete using (tenant_id = public.current_tenant_id());

create policy "gift_cards_select" on public.gift_cards
    for select using (tenant_id = public.current_tenant_id());
create policy "gift_cards_insert" on public.gift_cards
    for insert with check (tenant_id = public.current_tenant_id());
create policy "gift_cards_update" on public.gift_cards
    for update using (tenant_id = public.current_tenant_id());
create policy "gift_cards_delete" on public.gift_cards
    for delete using (tenant_id = public.current_tenant_id());

create policy "notifications_select" on public.notifications
    for select using (tenant_id = public.current_tenant_id());
create policy "notifications_insert" on public.notifications
    for insert with check (tenant_id = public.current_tenant_id());
create policy "notifications_update" on public.notifications
    for update using (tenant_id = public.current_tenant_id());
create policy "notifications_delete" on public.notifications
    for delete using (tenant_id = public.current_tenant_id());

create policy "branches_select" on public.branches
    for select using (tenant_id = public.current_tenant_id());
create policy "branches_insert" on public.branches
    for insert with check (tenant_id = public.current_tenant_id());
create policy "branches_update" on public.branches
    for update using (tenant_id = public.current_tenant_id());
create policy "branches_delete" on public.branches
    for delete using (tenant_id = public.current_tenant_id());

create policy "counters_select" on public.counters
    for select using (tenant_id = public.current_tenant_id());

-- ─── Auto tenant_id triggers for new tables ─────────────────
create trigger trg_set_tenant_suppliers before insert on public.suppliers
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_purchase_orders before insert on public.purchase_orders
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_gift_cards before insert on public.gift_cards
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_notifications before insert on public.notifications
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_branches before insert on public.branches
    for each row execute function public.set_tenant_id();

-- ─── Updated-at triggers ────────────────────────────────────
create trigger trg_suppliers_updated before update on public.suppliers
    for each row execute function public.set_updated_at();
create trigger trg_purchase_orders_updated before update on public.purchase_orders
    for each row execute function public.set_updated_at();
create trigger trg_branches_updated before update on public.branches
    for each row execute function public.set_updated_at();

-- ============================================================
-- next_counter(tenant_id, name) – atomic per-tenant counter
-- Used for order numbers, invoice numbers, purchase orders.
-- ============================================================
create or replace function public.next_counter(p_name text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    v_tenant uuid := public.current_tenant_id();
    v_value integer;
begin
    if v_tenant is null then
        raise exception 'No tenant claim in session';
    end if;
    insert into public.counters (tenant_id, name, value)
    values (v_tenant, p_name, 1)
    on conflict (tenant_id, name)
    do update set value = public.counters.value + 1
    returning value into v_value;
    return v_value;
end;
$$;

-- ============================================================
-- bootstrap_tenant – first-run onboarding for a new workspace.
-- Creates the tenant, links the signed-in auth user, seeds the
-- default payment methods / tax rates / floor & tables / branch,
-- and stamps tenant_id (+role) into the user's JWT claims.
-- Idempotent: safe to call on every login of a user without a
-- tenant. The client must refresh the session afterwards so the
-- new claims reach the JWT (RLS depends on them).
-- ============================================================
create or replace function public.bootstrap_tenant(
    p_restaurant_name text default null,
    p_full_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
    v_tenant_id uuid;
    v_floor_id uuid;
    v_email text;
begin
    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select tenant_id into v_tenant_id
    from public.users
    where user_id = v_user_id
    limit 1;

    if v_tenant_id is not null then
        perform public.set_tenant_claim(v_user_id, v_tenant_id);
        return v_tenant_id;
    end if;

    select email into v_email from auth.users where id = v_user_id;
    v_email := coalesce(v_email, 'workspace@dashtab.app');

    insert into public.tenants (name, slug, currency_code, locale, timezone)
    values (
        coalesce(nullif(p_restaurant_name, ''), split_part(v_email, '@', 1)),
        'ws-' || substr(gen_random_uuid()::text, 1, 8),
        'EUR',
        'es-ES',
        'Europe/Madrid'
    )
    returning id into v_tenant_id;

    insert into public.users (user_id, email, full_name, role, tenant_id)
    values (
        v_user_id,
        v_email,
        coalesce(nullif(p_full_name, ''), split_part(v_email, '@', 1)),
        'Owner',
        v_tenant_id
    );

    -- Seed defaults so a fresh workspace is usable immediately
    insert into public.payment_methods (name, type, sort_order, tenant_id)
    values
        ('Cash', 0, 1, v_tenant_id),
        ('Card', 1, 2, v_tenant_id),
        ('Bizum', 1, 3, v_tenant_id),
        ('Gift Card', 1, 4, v_tenant_id);

    insert into public.tax_rates (name, rate, is_inclusive, is_default, is_active, tenant_id)
    values
        ('IVA General 21%', 21, true, true, true, v_tenant_id),
        ('IVA Reducido 10%', 10, true, false, true, v_tenant_id),
        ('IVA Super-reducido 4%', 4, true, false, true, v_tenant_id);

    insert into public.floors (name, background_color, is_active, tenant_id)
    values ('Main Floor', '#1a1a2e', true, v_tenant_id)
    returning id into v_floor_id;

    insert into public.tables (floor_id, name, capacity, x, y, width, height, shape, zone, tenant_id)
    values
        (v_floor_id, 'T1', 2, 20,  40, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T2', 4, 140, 40, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T3', 4, 260, 40, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T4', 2, 380, 40, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T5', 4, 20,  180, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T6', 4, 140, 180, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T7', 2, 260, 180, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T8', 6, 380, 180, 100, 100, 0, 'Indoor',  v_tenant_id),
        (v_floor_id, 'T9', 2, 560, 40, 100, 100, 0, 'Terrace', v_tenant_id),
        (v_floor_id, 'T10', 4, 560, 160, 100, 100, 0, 'Terrace', v_tenant_id),
        (v_floor_id, 'B1', 2, 20, 320, 100, 100, 0, 'Bar',     v_tenant_id),
        (v_floor_id, 'B2', 2, 140, 320, 100, 100, 0, 'Bar',     v_tenant_id),
        (v_floor_id, 'P1', 8, 300, 320, 100, 100, 0, 'Private', v_tenant_id);

    insert into public.branches (name, full_name, city, terminals, tenant_id)
    values (
        'Main',
        coalesce(nullif(p_restaurant_name, ''), 'Main Location'),
        '',
        1,
        v_tenant_id
    );

    perform public.set_tenant_claim(v_user_id, v_tenant_id);
    return v_tenant_id;
end;
$$;

-- ============================================================
-- set_tenant_claim – stamps tenant_id (+ role) into the JWT.
-- Uses auth.set_claim when available (Supabase >= 1.18).
-- ============================================================
create or replace function public.set_tenant_claim(p_user_id uuid, p_tenant_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if exists (
        select 1 from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'auth' and p.proname = 'set_claim'
    ) then
        perform auth.set_claim(p_user_id, 'tenant_id', p_tenant_id::text);
        perform auth.set_claim(p_user_id, 'role', 'admin');
    end if;
end;
$$;

-- ─── Widen table-free trigger: Paid (6) and Refunded (7) also free
-- the table, so settling from any terminal releases the seat.
create or replace function public.update_table_status()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' and new.table_id is not null then
        update public.tables
        set status = 1, -- Occupied
            updated_at = now()
        where id = new.table_id;
    elsif tg_op = 'UPDATE' and new.status in (4, 5, 6, 7) and old.status not in (4, 5, 6, 7) then
        -- Order closed, cancelled, paid or refunded - free the table
        if new.table_id is not null then
            update public.tables
            set status = 0, -- Free
                guest = null,
                persons = null,
                updated_at = now()
            where id = new.table_id;
        end if;
    end if;
    return new;
end;
$$;

-- ─── Grants ─────────────────────────────────────────────────
grant execute on function public.next_counter(text) to authenticated, anon;
grant execute on function public.bootstrap_tenant(text, text) to authenticated, anon;
grant execute on function public.set_tenant_claim(uuid, uuid) to authenticated, anon;
