-- ============================================================
-- 013 – Owner/Manager can reset a staff member's password
--
-- set_staff_password: the app cannot write to auth.users with the
-- anon key, so this security-definer function does it: verifies the
-- caller is Owner/Manager in the same tenant, then replaces the
-- bcrypt hash of the linked auth user. The plain password never
-- leaves the RPC call and is never stored in plain text anywhere.
-- ============================================================

create or replace function public.set_staff_password(
    p_staff_id uuid,
    p_password text
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
    v_caller uuid := auth.uid();
    v_tenant uuid := public.current_tenant_id();
    v_caller_role text;
    v_auth_user uuid;
    v_staff_tenant uuid;
begin
    if v_caller is null then
        raise exception 'Not authenticated';
    end if;

    if v_tenant is null then
        select tenant_id into v_tenant
        from public.users
        where user_id = v_caller
        limit 1;
    end if;

    select coalesce(role, 'Staff') into v_caller_role
    from public.users
    where user_id = v_caller
    limit 1;
    if v_caller_role not in ('Owner', 'Manager', 'Admin', 'Administrator') then
        raise exception 'Only owners and managers can change passwords';
    end if;

    if p_password is null or length(p_password) < 8 then
        raise exception 'Password must be at least 8 characters';
    end if;

    select user_id, tenant_id
      into v_auth_user, v_staff_tenant
    from public.users
    where id = p_staff_id;

    if v_auth_user is null then
        raise exception 'This staff member has no login account';
    end if;
    if v_tenant is not null and v_staff_tenant is distinct from v_tenant then
        raise exception 'That staff member belongs to another workspace';
    end if;

    update auth.users
       set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
           updated_at = now()
     where id = v_auth_user;

    if not found then
        raise exception 'Login account not found';
    end if;
end;
$$;

revoke execute on function public.set_staff_password(uuid, text) from public, anon;
grant execute on function public.set_staff_password(uuid, text) to authenticated;
