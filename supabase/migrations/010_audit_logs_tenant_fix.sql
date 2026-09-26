-- 010 – Audit logs tenant fix
--
-- audit_logs is tenant-scoped by RLS, but unlike every other business table
-- it never received the auto `set_tenant_id()` trigger, and the app inserts
-- rows without an explicit tenant_id. The insert was therefore rejected by
-- the `audit_logs_insert` policy (tenant_id = current_tenant_id()) and audit
-- entries silently never reached the database.

create trigger trg_set_tenant_audit_logs before insert on public.audit_logs
    for each row execute function public.set_tenant_id();
