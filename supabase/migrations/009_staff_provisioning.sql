-- ============================================================
-- 009 – Staff provisioning
--
-- create_staff_user: lets an Owner/Manager create a real login
-- account for a staff member from inside the app. The function
-- runs as security definer so it can write to auth.users (which
-- the client cannot touch directly with the anon key), links the
-- new auth user to the caller's tenant, and stamps the tenant
-- claim so the new user's JWT works with all RLS policies on
-- first login.
-- ============================================================

create or replace function public.create_staff_user(
    p_email text,
    p_password text,
    p_full_name text,
    p_role text default 'Staff',
    p_phone text default null
)
returns public.users
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
    v_caller uuid := auth.uid();
    v_tenant uuid := public.current_tenant_id();
    v_caller_role text;
    v_auth_user uuid;
    v_row public.users;
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
    if v_tenant is null then
        raise exception 'Caller does not belong to a workspace';
    end if;

    select coalesce(role, 'Staff') into v_caller_role
    from public.users
    where user_id = v_caller
    limit 1;
    if v_caller_role not in ('Owner', 'Manager', 'Admin', 'Administrator') then
        raise exception 'Only owners and managers can create staff accounts';
    end if;

    if p_email is null or position('@' in coalesce(p_email, '')) < 2 then
        raise exception 'A valid email address is required';
    end if;
    if p_password is null or length(p_password) < 8 then
        raise exception 'Password must be at least 8 characters';
    end if;
    if exists (select 1 from auth.users where lower(email) = lower(p_email)) then
        raise exception 'An account with this email already exists';
    end if;

    v_auth_user := gen_random_uuid();
    insert into auth.users (
        id, instance_id, aud, role, email,
        encrypted_password, email_confirmed_at,
        created_at, updated_at,
        raw_app_meta_data, raw_user_meta_data
    ) values (
        v_auth_user, '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', lower(p_email),
        crypt(p_password, gen_salt('bf')), now(),
        now(), now(),
        jsonb_build_object('tenant_id', v_tenant, 'provider', 'email',
                           'providers', jsonb_build_array('email')),
        jsonb_build_object('full_name', p_full_name)
    );

    insert into public.users (user_id, email, full_name, role, phone, is_active, tenant_id)
    values (v_auth_user, lower(p_email), p_full_name, p_role, p_phone, true, v_tenant)
    returning * into v_row;

    perform public.set_tenant_claim(v_auth_user, v_tenant);
    return v_row;
end;
$$;

revoke execute on function public.create_staff_user(text, text, text, text, text) from public, anon;
grant execute on function public.create_staff_user(text, text, text, text, text) to authenticated;

-- ============================================================
-- Audit log user join.
-- audit_logs.user_id historically stored the auth.users id, but the
-- app joins it against public.users for the author name/role. Add
-- the real foreign key (after clearing any orphaned values) so the
-- join resolves; the app now writes the public.users row id.
-- ============================================================
update public.audit_logs
set user_id = null
where user_id is not null
  and not exists (select 1 from public.users u where u.id = audit_logs.user_id);

alter table public.audit_logs
    drop constraint if exists fk_audit_logs_user;
alter table public.audit_logs
    add constraint fk_audit_logs_user
    foreign key (user_id) references public.users(id) on delete set null;
