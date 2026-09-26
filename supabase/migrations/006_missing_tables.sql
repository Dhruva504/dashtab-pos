-- ============================================================
-- DashTab POS – Missing Tables (Phase 2)
-- Settings, Shifts, Cash Drawers, Modifiers, Roles/Permissions
-- ============================================================

-- ─── Settings ────────────────────────────────────────────────
create table if not exists public.settings (
    id              uuid primary key default gen_random_uuid(),
    key             text not null,
    value           text,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    unique (tenant_id, key)
);

-- ─── Shifts ──────────────────────────────────────────────────
create table if not exists public.shifts (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.users(id) on delete cascade,
    opened_at       timestamptz not null default now(),
    closed_at       timestamptz,
    opening_cash    numeric not null default 0,
    closing_cash    numeric,
    expected_cash   numeric,
    variance        numeric,
    status          integer not null default 0, -- 0=Open, 1=Closed
    notes           text,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Cash Drawer Transactions ────────────────────────────────
create table if not exists public.cash_drawer_transactions (
    id              uuid primary key default gen_random_uuid(),
    shift_id        uuid not null references public.shifts(id) on delete cascade,
    type            integer not null default 0, -- 0=CashIn, 1=CashOut, 2=Sale, 3=Refund
    amount          numeric not null default 0,
    reason          text,
    order_id        uuid references public.orders(id),
    user_id         uuid references public.users(id),
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now()
);

-- ─── Modifier Groups ─────────────────────────────────────────
create table if not exists public.modifier_groups (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    description     text,
    min_selections  integer not null default 0,
    max_selections  integer not null default 1,
    is_required     boolean not null default false,
    is_active       boolean not null default true,
    sort_order      integer not null default 0,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Modifiers ───────────────────────────────────────────────
create table if not exists public.modifiers (
    id              uuid primary key default gen_random_uuid(),
    group_id        uuid not null references public.modifier_groups(id) on delete cascade,
    name            text not null,
    price           numeric not null default 0,
    is_active       boolean not null default true,
    sort_order      integer not null default 0,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- ─── Product-Modifier Group Link ─────────────────────────────
create table if not exists public.product_modifier_groups (
    product_id      uuid not null references public.products(id) on delete cascade,
    modifier_group_id uuid not null references public.modifier_groups(id) on delete cascade,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    primary key (product_id, modifier_group_id)
);

-- ─── Order Item Modifiers ────────────────────────────────────
create table if not exists public.order_item_modifiers (
    id              uuid primary key default gen_random_uuid(),
    order_item_id   uuid not null references public.order_items(id) on delete cascade,
    modifier_id     uuid not null references public.modifiers(id),
    modifier_name   text not null,
    price           numeric not null default 0,
    quantity        integer not null default 1,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now()
);

-- ─── Roles ───────────────────────────────────────────────────
create table if not exists public.roles (
    id              uuid primary key default gen_random_uuid(),
    name            text not null,
    description     text,
    is_system       boolean not null default false,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    unique (tenant_id, name)
);

-- ─── Permissions ─────────────────────────────────────────────
create table if not exists public.permissions (
    id              uuid primary key default gen_random_uuid(),
    name            text not null unique,
    description     text,
    created_at      timestamptz not null default now()
);

-- ─── Role Permissions ────────────────────────────────────────
create table if not exists public.role_permissions (
    role_id         uuid not null references public.roles(id) on delete cascade,
    permission_id   uuid not null references public.permissions(id) on delete cascade,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    primary key (role_id, permission_id)
);

-- ─── User Roles ──────────────────────────────────────────────
create table if not exists public.user_roles (
    user_id         uuid not null references public.users(id) on delete cascade,
    role_id         uuid not null references public.roles(id) on delete cascade,
    tenant_id       uuid not null references public.tenants(id) on delete cascade,
    created_at      timestamptz not null default now(),
    primary key (user_id, role_id)
);

-- ─── Indexes ─────────────────────────────────────────────────
create index if not exists idx_settings_tenant on public.settings(tenant_id);
create index if not exists idx_shifts_tenant on public.shifts(tenant_id);
create index if not exists idx_shifts_user on public.shifts(user_id);
create index if not exists idx_cash_drawer_shift on public.cash_drawer_transactions(shift_id);
create index if not exists idx_cash_drawer_tenant on public.cash_drawer_transactions(tenant_id);
create index if not exists idx_modifier_groups_tenant on public.modifier_groups(tenant_id);
create index if not exists idx_modifiers_group on public.modifiers(group_id);
create index if not exists idx_modifiers_tenant on public.modifiers(tenant_id);
create index if not exists idx_order_item_modifiers_item on public.order_item_modifiers(order_item_id);
create index if not exists idx_order_item_modifiers_tenant on public.order_item_modifiers(tenant_id);
create index if not exists idx_roles_tenant on public.roles(tenant_id);
create index if not exists idx_user_roles_user on public.user_roles(user_id);

-- ─── Updated-at triggers for new tables ──────────────────────
create trigger trg_settings_updated before update on public.settings
    for each row execute function public.set_updated_at();
create trigger trg_shifts_updated before update on public.shifts
    for each row execute function public.set_updated_at();
create trigger trg_modifier_groups_updated before update on public.modifier_groups
    for each row execute function public.set_updated_at();
create trigger trg_modifiers_updated before update on public.modifiers
    for each row execute function public.set_updated_at();
create trigger trg_roles_updated before update on public.roles
    for each row execute function public.set_updated_at();

-- ─── Auto-set tenant_id triggers for new tables ──────────────
create trigger trg_set_tenant_settings before insert on public.settings
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_shifts before insert on public.shifts
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_cash_drawer before insert on public.cash_drawer_transactions
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_modifier_groups before insert on public.modifier_groups
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_modifiers before insert on public.modifiers
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_product_modifier_groups before insert on public.product_modifier_groups
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_order_item_modifiers before insert on public.order_item_modifiers
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_roles before insert on public.roles
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_role_permissions before insert on public.role_permissions
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_user_roles before insert on public.user_roles
    for each row execute function public.set_tenant_id();

-- ─── Seed default permissions ────────────────────────────────
insert into public.permissions (name, description) values
    ('pos.view', 'View POS screen'),
    ('pos.operate', 'Operate POS (add items, process orders)'),
    ('menu.view', 'View menu'),
    ('menu.manage', 'Create/edit/delete menu items'),
    ('categories.manage', 'Create/edit/delete categories'),
    ('tables.manage', 'Create/edit/delete tables and floors'),
    ('orders.view', 'View orders'),
    ('orders.manage', 'Create/edit/close orders'),
    ('orders.refund', 'Process refunds'),
    ('payments.process', 'Process payments'),
    ('payments.refund', 'Process payment refunds'),
    ('customers.view', 'View customers'),
    ('customers.manage', 'Create/edit/delete customers'),
    ('inventory.view', 'View inventory'),
    ('inventory.manage', 'Manage inventory'),
    ('reports.view', 'View reports'),
    ('reports.export', 'Export reports'),
    ('staff.manage', 'Manage staff users'),
    ('settings.manage', 'Manage tenant settings'),
    ('discounts.manage', 'Manage discounts'),
    ('taxes.manage', 'Manage tax rates'),
    ('shifts.manage', 'Manage shifts and cash drawer'),
    ('kitchen.view', 'View kitchen display'),
    ('kitchen.manage', 'Update kitchen order status')
on conflict (name) do nothing;