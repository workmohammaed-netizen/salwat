-- إصلاح: التسجيل الجديد يفشل إذا كان فيه صف قديم بجدول app_users بنفس البريد
-- (مثلاً شخص سبق أن سُجّل ثم حُذف حسابه من صفحة "المستخدمون" — الحذف يمسح صف
-- app_users بس يبقي حساب Supabase Auth كما هو، فأي محاولة تسجيل لاحقة بنفس
-- البريد كانت تفشل بسبب تعارض مع القيد الفريد unique على عمود email).
-- الحل: نستخدم upsert (ON CONFLICT) بدل insert العادي، فيربط الصف الموجود
-- بالحساب الجديد بدل ما يفشل بالكامل.

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
  )
  on conflict (email) do update set
    auth_user_id = excluded.auth_user_id,
    name = coalesce(public.app_users.name, excluded.name);
  -- ملاحظة: لا نلمس role/permissions/active للصف الموجود مسبقاً — يبقى بحالته
  -- (نشط أو موقوف، صلاحياته) كما ضبطها الأدمن، فقط نربطه بحساب Supabase الجديد.

  return new;
end;
$$;
