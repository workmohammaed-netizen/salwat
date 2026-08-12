-- مرفقات العقود (ملفات PDF) — تُدار من نافذة تفاصيل العقد
create table public.contract_files (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  file_name text not null,
  file_url text not null,
  note text,
  uploaded_by text,
  uploaded_at timestamptz not null default now()
);

create index idx_contract_files_contract on public.contract_files(contract_id);

alter table public.contract_files enable row level security;

create policy contract_files_select on public.contract_files
  for select to authenticated using (is_active_user());

create policy contract_files_insert on public.contract_files
  for insert to authenticated with check (has_perm('contracts', 'add'));

create policy contract_files_delete on public.contract_files
  for delete to authenticated using (has_perm('contracts', 'delete'));

-- Storage: دلو "contract-files" (أنشئه من لوحة Supabase → Storage قبل تنفيذ هذا الملف)
-- سياسات الوصول لملفات الدلو، بنفس صلاحيات صفحة العقود
create policy contract_files_storage_select on storage.objects
  for select to authenticated
  using (bucket_id = 'contract-files' and is_active_user());

create policy contract_files_storage_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'contract-files' and has_perm('contracts', 'add'));

create policy contract_files_storage_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'contract-files' and has_perm('contracts', 'delete'));
