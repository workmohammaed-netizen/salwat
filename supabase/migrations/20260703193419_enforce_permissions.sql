-- ============================================================
-- يفرض صلاحيات app_users.permissions فعليًا على قاعدة البيانات
-- بدل الاعتماد فقط على إخفاء/إظهار الأزرار بالواجهة.
--
-- القراءة (SELECT) تبقى مفتوحة لأي مستخدم مسجّل دخول ومفعّل على كل الجداول،
-- لأن شاشات كثيرة (التقارير، تفاصيل العقد، صفحة الدفعات...) تحتاج تقرأ من
-- أكثر من جدول مترابط لعرض بياناتها حتى لو المستخدم ما عنده صلاحية "عرض"
-- على تلك الصفحة تحديدًا. التعديل/الإضافة/الحذف (الخطر الفعلي) هي اللي تُقيَّد.
-- ============================================================

create or replace function public.has_perm(page text, action text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.app_users
    where auth_user_id = auth.uid() and active = true and role = 'admin'
  )
  or exists (
    select 1 from public.app_users
    where auth_user_id = auth.uid() and active = true
      and coalesce((permissions -> page ->> action)::boolean, false) = true
  );
$$;

create or replace function public.is_active_user()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.app_users where auth_user_id = auth.uid() and active = true);
$$;

-- ── contracts (صفحة العقود) ──
drop policy if exists contracts_authenticated_all on public.contracts;
create policy contracts_select on public.contracts for select to authenticated using (is_active_user());
create policy contracts_insert on public.contracts for insert to authenticated with check (has_perm('contracts','add'));
create policy contracts_update on public.contracts for update to authenticated using (has_perm('contracts','edit')) with check (has_perm('contracts','edit'));
create policy contracts_delete on public.contracts for delete to authenticated using (has_perm('contracts','delete'));

-- ── discounts / flows / flow_discounts (تُدار من داخل تفاصيل العقد — صفحة العقود) ──
drop policy if exists discounts_authenticated_all on public.discounts;
create policy discounts_select on public.discounts for select to authenticated using (is_active_user());
create policy discounts_insert on public.discounts for insert to authenticated with check (has_perm('contracts','add'));
create policy discounts_delete on public.discounts for delete to authenticated using (has_perm('contracts','delete'));

drop policy if exists flows_authenticated_all on public.flows;
create policy flows_select on public.flows for select to authenticated using (is_active_user());
create policy flows_insert on public.flows for insert to authenticated with check (has_perm('contracts','add'));
create policy flows_delete on public.flows for delete to authenticated using (has_perm('contracts','delete'));

drop policy if exists flow_discounts_authenticated_all on public.flow_discounts;
create policy flow_discounts_select on public.flow_discounts for select to authenticated using (is_active_user());
create policy flow_discounts_insert on public.flow_discounts for insert to authenticated with check (has_perm('contracts','add'));
create policy flow_discounts_delete on public.flow_discounts for delete to authenticated using (has_perm('contracts','delete'));

-- ── payments / invoices / payment_schedules / client_balances (صفحة الدفعات) ──
drop policy if exists payments_authenticated_all on public.payments;
create policy payments_select on public.payments for select to authenticated using (is_active_user());
create policy payments_insert on public.payments for insert to authenticated with check (has_perm('payments','add'));
create policy payments_update on public.payments for update to authenticated using (has_perm('payments','edit')) with check (has_perm('payments','edit'));
create policy payments_delete on public.payments for delete to authenticated using (has_perm('payments','delete'));

drop policy if exists invoices_authenticated_all on public.invoices;
create policy invoices_select on public.invoices for select to authenticated using (is_active_user());
create policy invoices_insert on public.invoices for insert to authenticated with check (has_perm('payments','add'));
create policy invoices_delete on public.invoices for delete to authenticated using (has_perm('payments','delete'));

-- جدولة الأقساط تُنشأ أثناء إضافة عقد جديد (صلاحية العقود) وتُعدَّل من صفحة الدفعات
drop policy if exists payment_schedules_authenticated_all on public.payment_schedules;
create policy payment_schedules_select on public.payment_schedules for select to authenticated using (is_active_user());
create policy payment_schedules_insert on public.payment_schedules for insert to authenticated with check (has_perm('contracts','add') or has_perm('payments','add'));
create policy payment_schedules_update on public.payment_schedules for update to authenticated using (has_perm('payments','edit')) with check (has_perm('payments','edit'));
create policy payment_schedules_delete on public.payment_schedules for delete to authenticated using (has_perm('payments','delete'));

drop policy if exists client_balances_authenticated_all on public.client_balances;
create policy client_balances_select on public.client_balances for select to authenticated using (is_active_user());
create policy client_balances_insert on public.client_balances for insert to authenticated with check (has_perm('payments','add') or has_perm('payments','edit'));
create policy client_balances_update on public.client_balances for update to authenticated using (has_perm('payments','edit')) with check (has_perm('payments','edit'));

-- ── clients / hotels / axes / carriers / contract_statuses / discount_reasons / classifications / client_hotels (صفحة قاعدة البيانات) ──
drop policy if exists clients_authenticated_all on public.clients;
create policy clients_select on public.clients for select to authenticated using (is_active_user());
create policy clients_insert on public.clients for insert to authenticated with check (has_perm('database','add'));
create policy clients_update on public.clients for update to authenticated using (has_perm('database','edit')) with check (has_perm('database','edit'));
create policy clients_delete on public.clients for delete to authenticated using (has_perm('database','delete'));

drop policy if exists hotels_authenticated_all on public.hotels;
create policy hotels_select on public.hotels for select to authenticated using (is_active_user());
create policy hotels_insert on public.hotels for insert to authenticated with check (has_perm('database','add'));
create policy hotels_update on public.hotels for update to authenticated using (has_perm('database','edit')) with check (has_perm('database','edit'));
create policy hotels_delete on public.hotels for delete to authenticated using (has_perm('database','delete'));

drop policy if exists axes_authenticated_all on public.axes;
create policy axes_select on public.axes for select to authenticated using (is_active_user());
create policy axes_insert on public.axes for insert to authenticated with check (has_perm('database','add'));
create policy axes_update on public.axes for update to authenticated using (has_perm('database','edit')) with check (has_perm('database','edit'));
create policy axes_delete on public.axes for delete to authenticated using (has_perm('database','delete'));

drop policy if exists carriers_authenticated_all on public.carriers;
create policy carriers_select on public.carriers for select to authenticated using (is_active_user());
create policy carriers_insert on public.carriers for insert to authenticated with check (has_perm('database','add'));
create policy carriers_update on public.carriers for update to authenticated using (has_perm('database','edit')) with check (has_perm('database','edit'));
create policy carriers_delete on public.carriers for delete to authenticated using (has_perm('database','delete'));

drop policy if exists contract_statuses_authenticated_all on public.contract_statuses;
create policy contract_statuses_select on public.contract_statuses for select to authenticated using (is_active_user());
create policy contract_statuses_insert on public.contract_statuses for insert to authenticated with check (has_perm('database','add'));
create policy contract_statuses_delete on public.contract_statuses for delete to authenticated using (has_perm('database','delete'));

drop policy if exists discount_reasons_authenticated_all on public.discount_reasons;
create policy discount_reasons_select on public.discount_reasons for select to authenticated using (is_active_user());
create policy discount_reasons_insert on public.discount_reasons for insert to authenticated with check (has_perm('database','add'));
create policy discount_reasons_delete on public.discount_reasons for delete to authenticated using (has_perm('database','delete'));

drop policy if exists classifications_authenticated_all on public.classifications;
create policy classifications_select on public.classifications for select to authenticated using (is_active_user());
create policy classifications_insert on public.classifications for insert to authenticated with check (has_perm('database','add'));
create policy classifications_delete on public.classifications for delete to authenticated using (has_perm('database','delete'));

drop policy if exists client_hotels_authenticated_all on public.client_hotels;
create policy client_hotels_select on public.client_hotels for select to authenticated using (is_active_user());
create policy client_hotels_insert on public.client_hotels for insert to authenticated with check (has_perm('database','add') or has_perm('database','edit'));
create policy client_hotels_delete on public.client_hotels for delete to authenticated using (has_perm('database','edit') or has_perm('database','delete'));

-- ── audit_log (صفحة سجل التعديلات) ──
-- الإضافة مفتوحة لأي مستخدم نشط (تسجيل تلقائي كأثر جانبي لأي عملية بأي صفحة)،
-- أما عرض السجل نفسه فمقيّد بصلاحية "عرض" على صفحة سجل التعديلات (أو الأدمن).
drop policy if exists audit_log_authenticated_all on public.audit_log;
create policy audit_log_select on public.audit_log for select to authenticated using (has_perm('auditlog','view'));
create policy audit_log_insert on public.audit_log for insert to authenticated with check (is_active_user());
