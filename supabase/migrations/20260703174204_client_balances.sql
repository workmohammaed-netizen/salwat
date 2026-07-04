create table public.client_balances (
  client_id bigint primary key references public.clients(id) on delete cascade,
  amount numeric(12,2) not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.client_balances enable row level security;

create policy client_balances_authenticated_all
  on public.client_balances for all
  to authenticated
  using (true) with check (true);
