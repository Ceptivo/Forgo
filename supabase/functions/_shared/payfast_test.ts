// Run with: deno test supabase/functions/_shared/payfast_test.ts
import { strict as assert } from 'node:assert';
import { md5Hex } from './md5.ts';
import { centsToRands, payfastSignature } from './payfast.ts';

Deno.test('md5Hex matches known vectors', () => {
  assert.equal(md5Hex(''), 'd41d8cd98f00b204e9800998ecf8427e');
  assert.equal(md5Hex('abc'), '900150983cd24fb0d6963f7d28e17f72');
  assert.equal(
    md5Hex('The quick brown fox jumps over the lazy dog'),
    '9e107d9d372bb6826bd81d3542a419d6',
  );
});

Deno.test('payfastSignature is sensitive to field order', () => {
  const a = payfastSignature([
    ['a', '1'],
    ['b', '2'],
  ]);
  const b = payfastSignature([
    ['b', '2'],
    ['a', '1'],
  ]);
  // Signature IS order-sensitive per Payfast's spec — swapping order must
  // change the signature, otherwise the implementation would be wrong.
  assert.equal(a === b, false);
});

Deno.test('payfastSignature drops empty-valued fields (per Payfast spec)', () => {
  const withEmpty = payfastSignature([
    ['a', '1'],
    ['b', ''],
    ['c', '2'],
  ]);
  const withoutEmpty = payfastSignature([
    ['a', '1'],
    ['c', '2'],
  ]);
  assert.equal(withEmpty, withoutEmpty);
});

Deno.test('payfastSignature appends passphrase when given', () => {
  const withoutPassphrase = payfastSignature([['a', '1']]);
  const withPassphrase = payfastSignature([['a', '1']], 'secret');
  assert.equal(withoutPassphrase === withPassphrase, false);
});

Deno.test('an outgoing payment request and a simulated ITN response sign identically', () => {
  const passphrase = 'jt7NOE43FZPn';

  const outgoing: Array<[string, string]> = [
    ['merchant_id', '10000100'],
    ['merchant_key', '46f0cd694581a'],
    ['email_address', 'demo@forgo.co.za'],
    ['m_payment_id', 'txn-123'],
    ['amount', centsToRands(20000)],
    ['item_name', 'Forgo wallet top-up'],
  ];
  const outgoingSignature = payfastSignature(outgoing, passphrase);

  // Build the query string the way create-payfast-payment does...
  const query = outgoing
    .map(([k, v]) => `${k}=${encodeURIComponent(v).replace(/%20/g, '+')}`)
    .concat(`signature=${outgoingSignature}`)
    .join('&');

  // ...and re-derive the fields the way payfast-itn parses an incoming
  // notification: split out `signature`, keep the rest in received order.
  const received = new URLSearchParams(query);
  const recomputeFields: Array<[string, string]> = [];
  let receivedSignature = '';
  for (const [key, value] of received) {
    if (key === 'signature') receivedSignature = value;
    else recomputeFields.push([key, value]);
  }

  assert.equal(payfastSignature(recomputeFields, passphrase), receivedSignature);
});
