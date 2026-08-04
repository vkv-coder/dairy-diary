-- Dairy Diary (gaushala.anyapps.in) Supabase migration
-- Project: jqqnnkzozjskziaizajg (shared "Dhobi-digital" project)
-- Single-tenant: one owner (auth.uid()) owns all gau_ rows.

create table if not exists gau_customers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  name text not null,
  phone1 text,
  phone2 text,
  type text not null check (type in ('Pickup','Delivery')),
  morning_qty numeric not null default 0,
  evening_qty numeric not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists gau_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  customer_name text not null,
  entry_date date not null,
  session text not null check (session in ('m','e')),
  qty numeric not null default 0,
  unique (owner_id, customer_name, entry_date, session)
);

create table if not exists gau_payments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  customer_name text not null,
  payment_date date not null,
  amount numeric not null default 0,
  unique (owner_id, customer_name, payment_date)
);

create table if not exists gau_bill_history (
  owner_id uuid not null default auth.uid(),
  customer_name text not null,
  last_from date,
  last_to date,
  primary key (owner_id, customer_name)
);

create table if not exists gau_settings (
  owner_id uuid primary key default auth.uid(),
  rate_pickup numeric not null default 90,
  rate_delivery numeric not null default 100,
  rate_cancel numeric not null default 10
);

alter table gau_customers enable row level security;
alter table gau_entries enable row level security;
alter table gau_payments enable row level security;
alter table gau_bill_history enable row level security;
alter table gau_settings enable row level security;

create policy "owner full access" on gau_customers
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "owner full access" on gau_entries
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "owner full access" on gau_payments
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "owner full access" on gau_bill_history
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "owner full access" on gau_settings
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Accumulate-on-conflict payment insert, matches original app's
-- payments[d][name] = (payments[d][name]||0) + amt behavior, done
-- atomically server-side to avoid a read-then-write race.
create or replace function gau_add_payment(p_customer_name text, p_date date, p_amount numeric)
returns void
language sql
security invoker
as $$
  insert into gau_payments (owner_id, customer_name, payment_date, amount)
  values (auth.uid(), p_customer_name, p_date, p_amount)
  on conflict (owner_id, customer_name, payment_date)
  do update set amount = gau_payments.amount + excluded.amount;
$$;

revoke execute on function gau_add_payment(text, date, numeric) from public;
grant execute on function gau_add_payment(text, date, numeric) to authenticated;
