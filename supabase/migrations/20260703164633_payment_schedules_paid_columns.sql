alter table public.payment_schedules
  add column paid numeric(12,2) not null default 0,
  add column paid_date date;
