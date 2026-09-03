-- Forgo: wallet top-ups via Payfast
--
-- Run this in the Supabase SQL editor (Project > SQL Editor) for
-- https://zfsklkcsfpygjmgwzaeb.supabase.co, or via `supabase db push` if
-- you're using the Supabase CLI. Same as 0001_profiles.sql, the app only
-- holds the anon key and can't run DDL itself, so this needs to be applied
-- manually.

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('topup')),
  amount_cents bigint not null check (amount_cents > 0),
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed', 'cancelled')),
  -- Our own reference sent to Payfast as m_payment_id.
  payfast_payment_id text,
  -- Payfast's own pf_payment_id, filled in once the ITN confirms payment.
  payfast_pf_payment_id text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists wallet_transactions_user_id_idx
  on public.wallet_transactions (user_id);

create unique index if not exists wallet_transactions_payfast_payment_id_idx
  on public.wallet_transactions (payfast_payment_id)
  where payfast_payment_id is not null;

alter table public.wallet_transactions enable row level security;

create policy "Users can view own transactions"
  on public.wallet_transactions for select
  using (auth.uid() = user_id);

-- No insert/update policy for the authenticated role: transactions are only
-- ever created and completed by the create-payfast-payment / payfast-itn
-- Edge Functions, which use the service-role key and bypass RLS entirely.

-- Atomically marks a transaction completed and credits the user's wallet.
-- Called only from the payfast-itn Edge Function (service role) after it
-- has validated the notification came from Payfast — see
-- supabase/functions/payfast-itn. Idempotent: Payfast can and does resend
-- the same ITN, so a second call for an already-completed transaction is a
-- no-op rather than double-crediting the wallet.
create or replace function public.credit_wallet_from_transaction(
  p_transaction_id uuid,
  p_pf_payment_id text
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid;
  v_amount_cents bigint;
  v_status text;
begin
  select user_id, amount_cents, status
    into v_user_id, v_amount_cents, v_status
    from public.wallet_transactions
    where id = p_transaction_id
    for update;

  if not found then
    raise exception 'Transaction % not found', p_transaction_id;
  end if;

  if v_status = 'completed' then
    return;
  end if;

  update public.wallet_transactions
    set status = 'completed',
        payfast_pf_payment_id = p_pf_payment_id,
        completed_at = now()
    where id = p_transaction_id;

  update public.profiles
    set wallet_balance_cents = wallet_balance_cents + v_amount_cents
    where id = v_user_id;
end;
$$;

-- Must never be callable by end users directly (it would let anyone credit
-- any wallet) — only the payfast-itn Edge Function calls it, via the
-- service-role key, which bypasses grants entirely.
revoke execute on function public.credit_wallet_from_transaction(uuid, text)
  from public, anon, authenticated;
