-- تمديد العقد: يمدّد تاريخ نهاية العقد نفسه (يزيد المدة)، بغض النظر عن وجود تسعير أصلاً
-- التمديد يكون إما مجانياً (بدون أي إضافة مالية) أو مدفوعاً بمبلغ يدخله المستخدم يدوياً بالكامل
create table public.extensions (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  old_end_date date not null,
  new_end_date date not null,
  days_added integer not null default 0,
  extension_type text not null default 'free' check (extension_type in ('free','paid')),
  amount numeric(12,2) not null default 0,
  note text,
  entered_by text,
  created_at timestamptz not null default now()
);

create index idx_extensions_contract on public.extensions(contract_id);

alter table public.extensions enable row level security;

create policy extensions_select on public.extensions for select to authenticated using (is_active_user());
create policy extensions_insert on public.extensions for insert to authenticated with check (has_perm('contracts','edit'));
create policy extensions_delete on public.extensions for delete to authenticated using (has_perm('contracts','edit'));
