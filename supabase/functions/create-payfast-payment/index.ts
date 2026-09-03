// Deno Edge Function. Called by the Flutter app (via
// `supabase.functions.invoke('create-payfast-payment', ...)`) when a user
// starts a wallet top-up. Creates a pending wallet_transactions row and
// returns a signed Payfast payment URL for the app to open in a WebView.
//
// Required secrets (set via `supabase secrets set`, never shipped in the
// app): PAYFAST_MERCHANT_ID, PAYFAST_MERCHANT_KEY. Optional:
// PAYFAST_PASSPHRASE (strongly recommended — set one in the Payfast
// dashboard), PAYFAST_MODE ("sandbox" | "live", defaults to "sandbox").
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are provided
// automatically by the Supabase Edge Functions runtime.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { centsToRands, payfastHost, payfastSignature } from '../_shared/payfast.ts';

const MIN_AMOUNT_CENTS = 1000; // R10 — matches the app's lowest stake preset
const MAX_AMOUNT_CENTS = 500000; // R5,000 — abuse/typo guard, not a product rule

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

function functionsBaseUrl(): string {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  return `${supabaseUrl}/functions/v1`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Scoped to the caller's own JWT, purely to authenticate them.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Not authenticated' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let body: { amount_cents?: unknown };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const amountCents = Number(body.amount_cents);
  if (
    !Number.isInteger(amountCents) ||
    amountCents < MIN_AMOUNT_CENTS ||
    amountCents > MAX_AMOUNT_CENTS
  ) {
    return new Response(
      JSON.stringify({
        error: `amount_cents must be an integer between ${MIN_AMOUNT_CENTS} and ${MAX_AMOUNT_CENTS}`,
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const merchantId = Deno.env.get('PAYFAST_MERCHANT_ID');
  const merchantKey = Deno.env.get('PAYFAST_MERCHANT_KEY');
  const passphrase = Deno.env.get('PAYFAST_PASSPHRASE') ?? undefined;
  if (!merchantId || !merchantKey) {
    console.error('PAYFAST_MERCHANT_ID / PAYFAST_MERCHANT_KEY not configured');
    return new Response(JSON.stringify({ error: 'Payments are not configured yet' }), {
      status: 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // service-role client: inserting a transaction row isn't something the
  // authenticated/anon Postgres role is allowed to do directly (see
  // supabase/migrations/0002_wallet_transactions.sql) — only this function.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: transaction, error: insertError } = await adminClient
    .from('wallet_transactions')
    .insert({ user_id: user.id, type: 'topup', amount_cents: amountCents, status: 'pending' })
    .select('id')
    .single();

  if (insertError || !transaction) {
    console.error('Failed to create wallet_transactions row', insertError);
    return new Response(JSON.stringify({ error: 'Could not start payment' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const transactionId = transaction.id as string;
  const { error: updateError } = await adminClient
    .from('wallet_transactions')
    .update({ payfast_payment_id: transactionId })
    .eq('id', transactionId);
  if (updateError) {
    console.error('Failed to stamp payfast_payment_id', updateError);
  }

  const base = functionsBaseUrl();

  // Order matters: it's part of what gets signed, and must be reproduced
  // (in the order Payfast re-sends it) when validating the ITN.
  const fields: Array<[string, string]> = [
    ['merchant_id', merchantId],
    ['merchant_key', merchantKey],
    ['return_url', `${base}/payfast-return`],
    ['cancel_url', `${base}/payfast-cancel`],
    ['notify_url', `${base}/payfast-itn`],
    ['email_address', user.email ?? ''],
    ['m_payment_id', transactionId],
    ['amount', centsToRands(amountCents)],
    ['item_name', 'Forgo wallet top-up'],
  ];

  const signature = payfastSignature(fields, passphrase);
  const query = fields
    .map(([key, value]) => `${key}=${encodeURIComponent(value).replace(/%20/g, '+')}`)
    .concat(`signature=${signature}`)
    .join('&');

  const paymentUrl = `${payfastHost()}/eng/process?${query}`;

  return new Response(JSON.stringify({ payment_url: paymentUrl, transaction_id: transactionId }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
