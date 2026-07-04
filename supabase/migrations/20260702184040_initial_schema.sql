-- ============================================================
-- رواحل المشاعر — initial schema, derived from index.html.html
-- ============================================================

-- ── Reference / lookup tables ──────────────────────────────

create table public.carriers (
  id bigint generated always as identity primary key,
  name text not null unique,
  notes text
);

create table public.classifications (
  id bigint generated always as identity primary key,
  name text not null,
  type text not null check (type in ('محور', 'مسار')),
  notes text
);

create table public.axes (
  id bigint generated always as identity primary key,
  name text not null unique,
  operator_id bigint references public.carriers(id),
  routes text[] not null default '{}',
  points text[] not null default '{}',
  type text
);

create table public.hotels (
  id bigint generated always as identity primary key,
  name text not null,
  location text,
  axis_id bigint references public.axes(id),
  notes text
);

create table public.clients (
  id bigint generated always as identity primary key,
  name text not null,
  contact text,
  notes text
);

create table public.client_hotels (
  client_id bigint not null references public.clients(id) on delete cascade,
  hotel_id bigint not null references public.hotels(id) on delete cascade,
  primary key (client_id, hotel_id)
);

create table public.contract_statuses (
  id bigint generated always as identity primary key,
  name text not null unique,
  color text,
  description text
);

create table public.discount_reasons (
  id bigint generated always as identity primary key,
  reason text not null,
  notes text
);

-- ── Core: contracts ─────────────────────────────────────────

create table public.contracts (
  id bigint generated always as identity primary key,
  display_id text,
  parent_id bigint references public.contracts(id) on delete set null,
  client_id bigint references public.clients(id),
  hotel_id bigint references public.hotels(id),
  axis_id bigint references public.axes(id),
  point text,
  carrier_id bigint references public.carriers(id),
  rental_order text,
  buses integer not null default 0,
  route text default 'عادي',
  shift text default 'كاملة',
  start_shift text,
  end_shift text,
  start_date date not null,
  end_date date not null,
  days integer not null default 0,
  price numeric(12,2) default 0,
  rental_rate numeric(12,2) default 0,
  rental_cost numeric(12,2) default 0,
  total numeric(12,2) default 0,
  original_total numeric(12,2) default 0,
  remaining numeric(12,2) default 0,
  status text,
  distributed_payment boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_contracts_client on public.contracts(client_id);
create index idx_contracts_hotel on public.contracts(hotel_id);
create index idx_contracts_axis on public.contracts(axis_id);
create index idx_contracts_parent on public.contracts(parent_id);

-- ── Money movements ─────────────────────────────────────────

create table public.payments (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  amount numeric(12,2) not null,
  method text not null check (method in ('نقد', 'تحويل')),
  sender text,
  receiver text,
  ref text,
  bank_from text,
  bank_to text,
  transfer_status text,
  note text,
  paid_at date not null default current_date,
  created_at timestamptz not null default now()
);
create index idx_payments_contract on public.payments(contract_id);

create table public.discounts (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  days numeric(6,2),
  reason text,
  disc_type text,
  amount numeric(12,2) not null,
  disc_buses numeric(6,2),
  operation_disc numeric(12,2),
  rental_disc numeric(12,2),
  entered_by text,
  date_from date,
  date_to date,
  note text,
  created_at timestamptz not null default now()
);
create index idx_discounts_contract on public.discounts(contract_id);

create table public.flows (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  due_date date,
  days integer not null,
  buses integer not null,
  shift text,
  price numeric(12,2),
  rental_rate numeric(12,2),
  op_cost numeric(12,2),
  rn_cost numeric(12,2),
  amount numeric(12,2) not null,
  paid numeric(12,2) not null default 0,
  note text,
  entered_by text,
  created_at timestamptz not null default now()
);
create index idx_flows_contract on public.flows(contract_id);

create table public.flow_discounts (
  id bigint generated always as identity primary key,
  flow_id bigint references public.flows(id) on delete cascade,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  days numeric(6,2),
  reason text,
  amount numeric(12,2) not null,
  op_disc numeric(12,2),
  rn_disc numeric(12,2),
  date_from date,
  date_to date,
  entered_by text,
  note text,
  created_at timestamptz not null default now()
);
create index idx_flow_discounts_contract on public.flow_discounts(contract_id);

create table public.invoices (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  from_date date not null,
  to_date date not null,
  days_in_period integer,
  daily_rate numeric(12,2),
  amount numeric(12,2) not null,
  saved_at timestamptz not null default now()
);
create index idx_invoices_contract on public.invoices(contract_id);

create table public.payment_schedules (
  id bigint generated always as identity primary key,
  contract_id bigint not null references public.contracts(id) on delete cascade,
  installment_num integer not null,
  due_date date not null,
  amount numeric(12,2) not null,
  status text not null default 'بانتظار السداد'
);
create index idx_payment_schedules_contract on public.payment_schedules(contract_id);

-- ── Audit / users / roles ───────────────────────────────────

create table public.audit_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  user_name text,
  action_type text,
  contract_id bigint references public.contracts(id) on delete set null,
  hotel text,
  details text,
  note text
);
create index idx_audit_log_contract on public.audit_log(contract_id);

create table public.roles (
  id bigint generated always as identity primary key,
  name text not null unique,
  permissions jsonb not null default '{}'::jsonb
);

create table public.app_users (
  id bigint generated always as identity primary key,
  email text not null unique,
  name text,
  password_hash text,
  password_salt text,
  role_id bigint references public.roles(id),
  role text,
  permissions jsonb not null default '{}'::jsonb,
  edit_completed boolean not null default false,
  created_at timestamptz not null default now()
);

-- ── Row Level Security ──────────────────────────────────────
-- Enabled on every table. The app currently authenticates users itself
-- (client-side hash check against app_users) rather than via Supabase Auth,
-- so for now only the `authenticated` and `service_role` Postgres roles get
-- access — the public/anon key alone cannot read or write anything.
-- Once the app's login is wired to Supabase Auth, these policies keep working
-- as-is; tighten them later (e.g. per-user/per-role) if needed.

do $$
declare
  t text;
begin
  for t in
    select unnest(array[
      'carriers','classifications','axes','hotels','clients','client_hotels',
      'contract_statuses','discount_reasons','contracts','payments','discounts',
      'flows','flow_discounts','invoices','payment_schedules','audit_log',
      'roles','app_users'
    ])
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format(
      'create policy %I on public.%I for all to authenticated using (true) with check (true);',
      t || '_authenticated_all', t
    );
  end loop;
end $$;
