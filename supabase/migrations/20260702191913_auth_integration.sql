-- ============================================================
-- Link app_users to Supabase Auth + auto-provision on signup
-- + admin-only management of app_users (previously wide open)
-- ============================================================

alter table public.app_users
  add column auth_user_id uuid unique references auth.users(id) on delete cascade,
  add column active boolean not null default false;

-- password_hash/password_salt belonged to the old in-page auth system;
-- Supabase Auth now owns credentials, so these columns are no longer written to.
alter table public.app_users
  alter column password_hash drop not null,
  alter column password_salt drop not null;

-- ── auto-provision a public.app_users row whenever someone confirms signup ──
-- First person ever to sign up becomes an active admin with full permissions.
-- Everyone after that starts inactive ("بانتظار تفعيل الأدمن") with no permissions,
-- matching the app's existing admin-approval flow.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_first boolean;
  full_perms jsonb := '{}'::jsonb;
  empty_perms jsonb := '{}'::jsonb;
  page text;
begin
  select count(*) = 0 into is_first from public.app_users;

  for page in select unnest(array['contracts','operations','payments','alerts','reports','database','auditlog'])
  loop
    full_perms := full_perms || jsonb_build_object(page, jsonb_build_object('view',true,'add',true,'edit',true,'delete',true,'export',true));
    empty_perms := empty_perms || jsonb_build_object(page, jsonb_build_object('view',false,'add',false,'edit',false,'delete',false,'export',false));
  end loop;

  insert into public.app_users (auth_user_id, email, name, role, permissions, active)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    case when is_first then 'admin' else 'user' end,
    case when is_first then full_perms else empty_perms end,
    is_first
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ── tighten app_users RLS: it previously allowed any authenticated user
-- full read/write on every row, which would let a non-admin grant themselves
-- admin/active status directly through the API. ──

drop policy if exists app_users_authenticated_all on public.app_users;

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.app_users
    where auth_user_id = auth.uid() and role = 'admin' and active = true
  );
$$;

create policy app_users_select_own_or_admin
  on public.app_users for select
  to authenticated
  using (auth_user_id = auth.uid() or public.is_admin());

create policy app_users_update_admin_only
  on public.app_users for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy app_users_insert_admin_only
  on public.app_users for insert
  to authenticated
  with check (public.is_admin());

create policy app_users_delete_admin_only
  on public.app_users for delete
  to authenticated
  using (public.is_admin());
