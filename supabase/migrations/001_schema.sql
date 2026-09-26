-- ============================================================
-- DashTab POS – Supabase Schema (Phase 1)
-- Supabase-first, multi-tenant POS SaaS
-- All tables include tenant_id for Row Level Security
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ─── Tenants ──────────────────────────────────────────────────
create table if not exists public.tenants (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    slug            text not null unique,
    address         text,
    phone           text,
    email           text,
    currency_code   text not null default 'INR',
    locale          text not null default 'en-IN',
    timezone        text not null default 'Asia/Kolkata',
    logo_url        text,
    is_active       boolean not null default true,
    tenant_id       uuid,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Users (linked to Supabase auth.users) ────────────────────
create table if not exists public.users (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid references auth.users(id) on delete cascade,
    email           text,
    full_name       text,
    pin             text,
    is_active       boolean not null default true,
    last_login_at   timestamptz,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Categories ───────────────────────────────────────────────
create table if not exists public.categories (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    description     text,
    sort_order      integer not null default 0,
    color           text,
    icon            text,
    is_active       boolean not null default true,
    parent_id       uuid references public.categories(id),
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Tax Rates ────────────────────────────────────────────────
create table if not exists public.tax_rates (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    rate            numeric not null default 0,
    is_inclusive    boolean not null default false,
    is_default      boolean not null default false,
    is_active       boolean not null default true,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Products ─────────────────────────────────────────────────
create table if not exists public.products (
    id              uuid primary key default gen_random_uuid(),
    category_id     uuid references public.categories(id) on delete cascade,
    name            text not null,
    short_name      text,
    description     text,
    price           numeric not null default 0,
    cost            numeric,
    sku             text,
    barcode         text,
    image_url       text,
    sort_order      integer not null default 0,
    color           text,
    is_active       boolean not null default true,
    is_available    boolean not null default true,
    tax_rate_id     uuid references public.tax_rates(id),
    prep_time_minutes integer,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Floors & Tables ──────────────────────────────────────────
create table if not exists public.floors (
    id                  uuid primary key default gen_random_uuid(),
    name                text not null,
    background_color    text not null default '#1a1a2e',
    background_image_url text,
    is_active           boolean not null default true,
    tenant_id           uuid not null references public.tenants(id) on delete cascade,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create table if not exists public.tables (
    id              uuid primary key default gen_random_uuid(),
    floor_id        uuid not null references public.floors(id) on delete cascade,
    name            text not null,
    capacity        integer not null default 4,
    status          integer not null default 0, -- 0=Free, 1=Occupied, 2=Reserved, 3=Cleaning
    x               double precision not null default 0,
    y               double precision not null default 0,
    width           double precision not null default 100,
    height          double precision not null default 100,
    shape           integer not null default 0, -- 0=Rectangle, 1=Circle
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Customers ────────────────────────────────────────────────
create table if not exists public.customers (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    email           text,
    phone           text,
    address         text,
    notes           text,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Orders ───────────────────────────────────────────────────
create table if not exists public.orders (
    id              uuid primary key default gen_random_uuid(),
    order_number    text not null,
    order_type      integer not null default 0, -- 0=DineIn, 1=Takeaway, 2=Delivery
    status          integer not null default 0, -- 0=Open, 1=SentToKitchen, 2=PartiallyServed, 3=Served, 4=Closed, 5=Cancelled, 6=Paid, 7=Refunded
    table_id        uuid references public.tables(id),
    customer_id     uuid references public.customers(id),
    waiter_id       uuid references public.users(id),
    subtotal        numeric not null default 0,
    tax_amount      numeric not null default 0,
    discount_amount numeric not null default 0,
    total           numeric not null default 0,
    notes           text,
    closed_at       timestamptz,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Order Items ──────────────────────────────────────────────
create table if not exists public.order_items (
    id                  uuid primary key default gen_random_uuid(),
    order_id            uuid not null references public.orders(id) on delete cascade,
    product_id          uuid references public.products(id),
    product_name        text not null,
    quantity            integer not null default 1,
    unit_price          numeric not null default 0,
    discount_amount     numeric not null default 0,
    tax_rate            numeric not null default 0,
    tax_amount          numeric not null default 0,
    subtotal            numeric not null default 0,
    total               numeric not null default 0,
    notes               text,
    status              integer not null default 0, -- 0=Pending, 1=SentToKitchen, 2=Completed, 3=Cancelled
    sent_to_kitchen_at  timestamptz,
    tenant_id           uuid not null references public.tenants(id) on delete cascade,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- ─── Payment Methods ──────────────────────────────────────────
create table if not exists public.payment_methods (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    type            integer not null default 0, -- 0=Cash, 1=Card
    is_active       boolean not null default true,
    sort_order      integer not null default 0,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Payments ─────────────────────────────────────────────────
create table if not exists public.payments (
    id                  uuid primary key default gen_random_uuid(),
    order_id            uuid not null references public.orders(id) on delete cascade,
    payment_method_id   uuid not null references public.payment_methods(id),
    amount              numeric not null default 0,
    tip_amount          numeric not null default 0,
    change_amount       numeric not null default 0,
    status              integer not null default 0, -- 0=Completed, 1=Refunded, 2=Failed
    reference           text,
    tenant_id           uuid not null references public.tenants(id) on delete cascade,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- ─── Inventory ────────────────────────────────────────────────
create table if not exists public.inventory (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    quantity        numeric not null default 0,
    unit            text,
    reorder_level   numeric not null default 0,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Discounts ────────────────────────────────────────────────
create table if not exists public.discounts (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    type            integer not null default 0, -- 0=Percentage, 1=Fixed
    value           numeric not null default 0,
    is_active       boolean not null default true,
    valid_from      timestamptz,
    valid_until     timestamptz,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Audit Logs ───────────────────────────────────────────────
create table if not exists public.audit_logs (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid,
    action          text not null,
    entity_type     text not null,
    entity_id       text not null,
    old_values      text,
    new_values      text,
    ip_address      text,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now()
);

-- ─── Indexes ──────────────────────────────────────────────────
create index if not exists idx_categories_tenant on public.categories(tenant_id);
create index if not exists idx_products_tenant on public.products(tenant_id);
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_floors_tenant on public.floors(tenant_id);
create index if not exists idx_tables_tenant on public.tables(tenant_id);
create index if not exists idx_tables_floor on public.tables(floor_id);
create index if not exists idx_orders_tenant on public.orders(tenant_id);
create index if not exists idx_orders_table on public.orders(table_id);
create index if not exists idx_order_items_tenant on public.order_items(tenant_id);
create index if not exists idx_order_items_order on public.order_items(order_id);
create index if not exists idx_payments_tenant on public.payments(tenant_id);
create index if not exists idx_payments_order on public.payments(order_id);
create index if not exists idx_users_tenant on public.users(tenant_id);
create index if not exists idx_customers_tenant on public.customers(tenant_id);
create index if not exists idx_inventory_tenant on public.inventory(tenant_id);
create index if not exists idx_payment_methods_tenant on public.payment_methods(tenant_id);

-- ─── Updated-at trigger ───────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger trg_tenants_updated before update on public.tenants
    for each row execute function public.set_updated_at();
create trigger trg_users_updated before update on public.users
    for each row execute function public.set_updated_at();
create trigger trg_categories_updated before update on public.categories
    for each row execute function public.set_updated_at();
create trigger trg_products_updated before update on public.products
    for each row execute function public.set_updated_at();
create trigger trg_floors_updated before update on public.floors
    for each row execute function public.set_updated_at();
create trigger trg_tables_updated before update on public.tables
    for each row execute function public.set_updated_at();
create trigger trg_orders_updated before update on public.orders
    for each row execute function public.set_updated_at();
create trigger trg_order_items_updated before update on public.order_items
    for each row execute function public.set_updated_at();
create trigger trg_payments_updated before update on public.payments
    for each row execute function public.set_updated_at();
create trigger trg_inventory_updated before update on public.inventory
    for each row execute function public.set_updated_at();
create trigger trg_customers_updated before update on public.customers
    for each row execute function public.set_updated_at();
create trigger trg_payment_methods_updated before update on public.payment_methods
    for each row execute function public.set_updated_at();
create trigger trg_discounts_updated before update on public.discounts
    for each row execute function public.set_updated_at();
