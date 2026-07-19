-- تحويل نظام المهام إلى نظام تذاكر (تيكت):
-- الموظف يرد بنص على المهمة (إنجاز أو تعطل بسبب معين)، والمدير يقدر يرسل رداً آخر لو فيه تعطل/مشكلة،
-- وإغلاق المهمة (تعليمها "منجزة" نهائياً) صار صلاحية حصرية لمن أنشأ المهمة فقط — وليس المُسند إليه.
create table public.task_messages (
  id bigint generated always as identity primary key,
  task_id bigint not null references public.tasks(id) on delete cascade,
  sender_id bigint references public.app_users(id),
  sender_name text,
  body text not null,
  reply_kind text check (reply_kind in ('update','done_report','blocked_report')),
  created_at timestamptz not null default now()
);
create index idx_task_messages_task on public.task_messages(task_id);

alter table public.task_messages enable row level security;

create policy task_messages_select on public.task_messages for select to authenticated using (is_active_user());

-- الإرسال مسموح فقط لمن أنشأ المهمة أو لمن أُسندت له مباشرة أو عبر دوره
create policy task_messages_insert on public.task_messages for insert to authenticated with check (
  exists (
    select 1 from public.tasks t
    join public.app_users u on u.auth_user_id = auth.uid() and u.active = true
    where t.id = task_messages.task_id
      and (u.id = t.created_by_id or u.id = t.assignee_user_id or (t.assignee_type = 'role' and u.role = t.assignee_role))
  )
);

-- إغلاق المهمة (status='done') صار صلاحية حصرية لمن أنشأها، أو لصاحب صلاحية تعديل المهام — وليس المُسند إليه
drop policy if exists tasks_update on public.tasks;
create policy tasks_update on public.tasks for update to authenticated using (
  has_perm('tasks','edit')
  or exists (
    select 1 from public.app_users u
    where u.auth_user_id = auth.uid() and u.active = true and u.id = tasks.created_by_id
  )
);
