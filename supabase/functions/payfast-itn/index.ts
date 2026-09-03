// Deno Edge Function. This is Payfast's server-to-server Instant
// Transaction Notification (ITN) webhook — the *authoritative* signal that
// a payment completed. The app's own return_url/cancel_url redirects are
// only for UX; never credit a wallet from those, only from here.
//
// Validation, per https://developers.payfast.co.za/docs#step_2_confirm_payment :
//   1. Recompute the signature over the fields as received and compare.
//   2. Post the raw notification back to Payfast's `query/validate`
//      endpoint and require it to answer "VALID" — this is what actually
//      proves the request came from Payfast (source-IP checking is the
//      other documented option; this is the simpler, equally-authoritative
//      one and doesn't require hardcoding/refreshing Payfast's IP ranges).
//   3. Cross-check the amount against what we recorded when the payment was
//      created, so a validated-but-tampered amount can't under/over-credit.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { payfastHost, payfastSignature } from '../_shared/payfast.ts';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const rawBody = await req.text();

  // Preserve field order exactly as Payfast sent it — the signature is
  // order-sensitive and URLSearchParams iterates in that order.
  const received = new URLSearchParams(rawBody);
  const fields: Array<[string, string]> = [];
  let receivedSignature = '';
  for (const [key, value] of received) {
    if (key === 'signature') {
      receivedSignature = value;
    } else {
      fields.push([key, value]);
    }
  }

  const passphrase = Deno.env.get('PAYFAST_PASSPHRASE') ?? undefined;
  const expectedSignature = payfastSignature(fields, passphrase);
  if (expectedSignature !== receivedSignature) {
    console.error('ITN signature mismatch', { expectedSignature, receivedSignature });
    return new Response('Invalid signature', { status: 400 });
  }

  // Server-to-server confirmation that this notification really came from
  // Payfast (a forged POST could get the signature right if it knew the
  // passphrase, but couldn't get Payfast's own validate endpoint to vouch
  // for it).
  const validateResponse = await fetch(`${payfastHost()}/eng/query/validate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: rawBody,
  });
  const validateText = (await validateResponse.text()).trim();
  if (validateText !== 'VALID') {
    console.error('Payfast validate endpoint rejected notification', validateText);
    return new Response('Not valid', { status: 400 });
  }

  const params = Object.fromEntries(fields);
  const transactionId = params['m_payment_id'];
  const paymentStatus = params['payment_status'];
  const amountGross = Number(params['amount_gross']);
  const pfPaymentId = params['pf_payment_id'] ?? '';

  if (!transactionId) {
    console.error('ITN missing m_payment_id');
    return new Response('Missing m_payment_id', { status: 400 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: transaction, error: fetchError } = await adminClient
    .from('wallet_transactions')
    .select('id, amount_cents, status')
    .eq('id', transactionId)
    .maybeSingle();

  if (fetchError || !transaction) {
    console.error('ITN for unknown transaction', transactionId, fetchError);
    return new Response('Unknown transaction', { status: 404 });
  }

  if (paymentStatus !== 'COMPLETE') {
    await adminClient
      .from('wallet_transactions')
      .update({ status: 'failed' })
      .eq('id', transactionId)
      .eq('status', 'pending');
    return new Response('OK', { status: 200 });
  }

  const expectedRands = transaction.amount_cents / 100;
  if (Math.abs(expectedRands - amountGross) > 0.01) {
    console.error('ITN amount mismatch', { expectedRands, amountGross, transactionId });
    return new Response('Amount mismatch', { status: 400 });
  }

  const { error: creditError } = await adminClient.rpc('credit_wallet_from_transaction', {
    p_transaction_id: transactionId,
    p_pf_payment_id: pfPaymentId,
  });
  if (creditError) {
    console.error('Failed to credit wallet', creditError);
    return new Response('Failed to credit wallet', { status: 500 });
  }

  return new Response('OK', { status: 200 });
});
