import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';

/// Result of a completed WebView session. `success` only means the user
/// was redirected to Payfast's return URL — it is NOT proof the payment
/// went through (that's payfast-itn's job, server-side). Treat this purely
/// as "should we refresh the wallet balance and show an optimistic
/// message", not as payment confirmation.
enum PayfastOutcome { success, cancelled, closed }

class PayfastWebviewScreen extends StatefulWidget {
  const PayfastWebviewScreen({super.key, required this.paymentUrl});

  final String paymentUrl;

  @override
  State<PayfastWebviewScreen> createState() => _PayfastWebviewScreenState();
}

class _PayfastWebviewScreenState extends State<PayfastWebviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  static String get _returnUrl =>
      '${AppConfig.supabaseUrl}/functions/v1/payfast-return';
  static String get _cancelUrl =>
      '${AppConfig.supabaseUrl}/functions/v1/payfast-cancel';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (request.url.startsWith(_returnUrl)) {
              Navigator.of(context).pop(PayfastOutcome.success);
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(_cancelUrl)) {
              Navigator.of(context).pop(PayfastOutcome.cancelled);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top up'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(PayfastOutcome.closed),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
