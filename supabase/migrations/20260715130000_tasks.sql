-- قائمة المهام: أي مستخدم يملك صلاحية "المهام - إضافة" يقدر يسند مهمة لمستخدم محدد أو لكل مستخدمي دور معيّن
-- إذا أُسندت المهمة لدور كامل، أول من ينجزها من أصحاب هذا الدور تُعتبر منجَزة للجميع (حالة واحدة مشتركة)
create table public.tasks (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  assignee_type text not null check (assignee_type in ('user','role')),
  assignee_user_id bigint references public.app_users(id) on delete cascade,
  assignee_role text,
  due_date date,
  status text not null default 'pending' check (status in ('pending','done')),
  created_by text,
  created_by_id bigint references public.app_users(id) on delete set null,
  completed_by text,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_tasks_assignee_user on public.tasks(assignee_user_id);
create index idx_tasks_assignee_role on public.tasks(assignee_role);
create index idx_tasks_status on public.tasks(status);

alter table public.tasks enable row level security;

create policy tasks_select on public.tasks for select to authenticated using (is_active_user());
create policy tasks_insert on public.tasks for insert to authenticated with check (has_perm('tasks','add'));
-- التحديث (تعليم كمنجزة) مسموح لصاحب صلاحية التعديل، أو لأي مستخدم مُسندة له المهمة مباشرة أو عبر دوره
create policy tasks_update on public.tasks for update to authenticated using (
  has_perm('tasks','edit')
  or exists (
    select 1 from public.app_users u
    where u.auth_user_id = auth.uid() and u.active = true
      and (u.id = tasks.assignee_user_id or (tasks.assignee_type = 'role' and u.role = tasks.assignee_role))
  )
);
-- الحذف مسموح لصاحب صلاحية الحذف، أو لمن أنشأ المهمة نفسها
create policy tasks_delete on public.tasks for delete to authenticated using (
  has_perm('tasks','delete')
  or exists (
    select 1 from public.app_users u
    where u.auth_user_id = auth.uid() and u.active = true and u.id = tasks.created_by_id
  )
);

-- دالة آمنة تُرجع فقط (المعرّف، الاسم، الدور) لكل المستخدمين المفعّلين — تُستخدم لتعبئة قائمة "إسناد لمستخدم"
-- بدون كشف أعمدة حساسة (كلمة المرور المشفّرة والملح، تفاصيل الصلاحيات) لغير الأدمن
create or replace function public.list_assignable_users()
returns table(id bigint, name text, role text)
language sql
security definer
set search_path = public
as $$
  select id, name, role from public.app_users where active = true order by name;
$$;
revoke all on function public.list_assignable_users() from public;
grant execute on function public.list_assignable_users() to authenticated;
