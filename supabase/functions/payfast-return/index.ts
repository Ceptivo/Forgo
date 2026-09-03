// Where Payfast redirects the user's browser/webview after a successful
// payment. This is UX only — the app's WebView detects navigation to this
// URL and closes itself; the wallet is actually credited by payfast-itn,
// which is the only source of truth for whether payment succeeded.
Deno.serve(() => {
  return new Response(
    `<!doctype html><html><head><meta charset="utf-8"><title>Payment received</title>
    <style>body{font-family:sans-serif;background:#000;color:#fff;display:flex;
    align-items:center;justify-content:center;height:100vh;margin:0}</style></head>
    <body><p>Payment received — you can close this window.</p></body></html>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
});
