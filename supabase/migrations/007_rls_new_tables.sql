-- ============================================================
-- DashTab POS – RLS Policies for New Tables (Phase 2)
-- Settings, Shifts, Cash Drawers, Modifiers, Roles/Permissions
-- ============================================================

-- Enable RLS on all new tables
alter table public.settings                  enable row level security;
alter table public.shifts                    enable row level security;
alter table public.cash_drawer_transactions  enable row level security;
alter table public.modifier_groups           enable row level security;
alter table public.modifiers                 enable row level security;
alter table public.product_modifier_groups   enable row level security;
alter table public.order_item_modifiers      enable row level security;
alter table public.roles                     enable row level security;
alter table public.permissions               enable row level security;
alter table public.role_permissions          enable row level security;
alter table public.user_roles                enable row level security;

-- ─── Settings ────────────────────────────────────────────────
create policy "settings_select" on public.settings
    for select using (tenant_id = public.current_tenant_id());
create policy "settings_insert" on public.settings
    for insert with check (tenant_id = public.current_tenant_id());
create policy "settings_update" on public.settings
    for update using (tenant_id = public.current_tenant_id());
create policy "settings_delete" on public.settings
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Shifts ──────────────────────────────────────────────────
create policy "shifts_select" on public.shifts
    for select using (tenant_id = public.current_tenant_id());
create policy "shifts_insert" on public.shifts
    for insert with check (tenant_id = public.current_tenant_id());
create policy "shifts_update" on public.shifts
    for update using (tenant_id = public.current_tenant_id());
create policy "shifts_delete" on public.shifts
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Cash Drawer Transactions ────────────────────────────────
create policy "cash_drawer_select" on public.cash_drawer_transactions
    for select using (tenant_id = public.current_tenant_id());
create policy "cash_drawer_insert" on public.cash_drawer_transactions
    for insert with check (tenant_id = public.current_tenant_id());
create policy "cash_drawer_update" on public.cash_drawer_transactions
    for update using (tenant_id = public.current_tenant_id());
create policy "cash_drawer_delete" on public.cash_drawer_transactions
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Modifier Groups ─────────────────────────────────────────
create policy "modifier_groups_select" on public.modifier_groups
    for select using (tenant_id = public.current_tenant_id());
create policy "modifier_groups_insert" on public.modifier_groups
    for insert with check (tenant_id = public.current_tenant_id());
create policy "modifier_groups_update" on public.modifier_groups
    for update using (tenant_id = public.current_tenant_id());
create policy "modifier_groups_delete" on public.modifier_groups
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Modifiers ───────────────────────────────────────────────
create policy "modifiers_select" on public.modifiers
    for select using (tenant_id = public.current_tenant_id());
create policy "modifiers_insert" on public.modifiers
    for insert with check (tenant_id = public.current_tenant_id());
create policy "modifiers_update" on public.modifiers
    for update using (tenant_id = public.current_tenant_id());
create policy "modifiers_delete" on public.modifiers
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Product-Modifier Group Link ─────────────────────────────
create policy "product_modifier_groups_select" on public.product_modifier_groups
    for select using (tenant_id = public.current_tenant_id());
create policy "product_modifier_groups_insert" on public.product_modifier_groups
    for insert with check (tenant_id = public.current_tenant_id());
create policy "product_modifier_groups_delete" on public.product_modifier_groups
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Order Item Modifiers ────────────────────────────────────
create policy "order_item_modifiers_select" on public.order_item_modifiers
    for select using (tenant_id = public.current_tenant_id());
create policy "order_item_modifiers_insert" on public.order_item_modifiers
    for insert with check (tenant_id = public.current_tenant_id());
create policy "order_item_modifiers_update" on public.order_item_modifiers
    for update using (tenant_id = public.current_tenant_id());
create policy "order_item_modifiers_delete" on public.order_item_modifiers
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Roles ───────────────────────────────────────────────────
create policy "roles_select" on public.roles
    for select using (tenant_id = public.current_tenant_id());
create policy "roles_insert" on public.roles
    for insert with check (tenant_id = public.current_tenant_id());
create policy "roles_update" on public.roles
    for update using (tenant_id = public.current_tenant_id());
create policy "roles_delete" on public.roles
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Permissions (global, all tenants can read) ──────────────
create policy "permissions_select" on public.permissions
    for select using (true);

-- ─── Role Permissions ────────────────────────────────────────
create policy "role_permissions_select" on public.role_permissions
    for select using (tenant_id = public.current_tenant_id());
create policy "role_permissions_insert" on public.role_permissions
    for insert with check (tenant_id = public.current_tenant_id());
create policy "role_permissions_update" on public.role_permissions
    for update using (tenant_id = public.current_tenant_id());
create policy "role_permissions_delete" on public.role_permissions
    for delete using (tenant_id = public.current_tenant_id());

-- ─── User Roles ──────────────────────────────────────────────
create policy "user_roles_select" on public.user_roles
    for select using (tenant_id = public.current_tenant_id());
create policy "user_roles_insert" on public.user_roles
    for insert with check (tenant_id = public.current_tenant_id());
create policy "user_roles_update" on public.user_roles
    for update using (tenant_id = public.current_tenant_id());
create policy "user_roles_delete" on public.user_roles
    for delete using (tenant_id = public.current_tenant_id());