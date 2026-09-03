import { md5Hex } from './md5.ts';

/**
 * Payfast signature + host helpers, shared by create-payfast-payment (which
 * builds an outgoing signed payment request) and payfast-itn (which
 * validates an incoming notification the same way).
 *
 * Spec: https://developers.payfast.co.za/docs#step_1_form_fields
 * The signature is an MD5 of `key=value&key=value...` for every field
 * *in the order given* (excluding the signature field itself), each value
 * URL-encoded PHP-`urlencode`-style (spaces as `+`, uppercase hex escapes),
 * with `&passphrase=<urlencoded passphrase>` appended when one is set.
 */

export function payfastMode(): 'sandbox' | 'live' {
  return Deno.env.get('PAYFAST_MODE') === 'live' ? 'live' : 'sandbox';
}

export function payfastHost(): string {
  return payfastMode() === 'live'
    ? 'https://www.payfast.co.za'
    : 'https://sandbox.payfast.co.za';
}

/** PHP's urlencode: like encodeURIComponent, but spaces become `+` and the
 * hex escapes are uppercase — both of which encodeURIComponent already
 * does, so only the space substitution needs handling. */
function phpUrlEncode(value: string): string {
  return encodeURIComponent(value).replace(/%20/g, '+');
}

/**
 * `fields` must be an array (not a plain object) so callers control the
 * exact field order — required because the signature is order-sensitive
 * and, for an incoming ITN, must match the order Payfast POSTed them in.
 */
export function payfastSignature(
  fields: Array<[string, string]>,
  passphrase?: string,
): string {
  let pairs = fields
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${key}=${phpUrlEncode(value.toString().trim())}`);

  if (passphrase) {
    pairs = [...pairs, `passphrase=${phpUrlEncode(passphrase.trim())}`];
  }

  return md5Hex(pairs.join('&'));
}

export function centsToRands(cents: number): string {
  return (cents / 100).toFixed(2);
}
