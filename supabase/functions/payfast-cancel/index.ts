// Where Payfast redirects the user's browser/webview if they cancel the
// payment. The app's WebView detects navigation to this URL and closes
// itself; no wallet-crediting happens here or needs to.
Deno.serve(() => {
  return new Response(
    `<!doctype html><html><head><meta charset="utf-8"><title>Payment cancelled</title>
    <style>body{font-family:sans-serif;background:#000;color:#fff;display:flex;
    align-items:center;justify-content:center;height:100vh;margin:0}</style></head>
    <body><p>Payment cancelled — you can close this window.</p></body></html>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
});
