import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xendit/widgets/custom_app_bar.dart';

/// Minimal WebView wrapper to display Xendit checkout invoice.
///
/// - Loads [checkoutUrl].
/// - Intercepts navigation to [returnDeepLink].
/// - When intercepted, pops the page and calls [onReturn] with the full [Uri].
class CheckoutWebView extends StatefulWidget {
  /// Xendit invoice URL (`invoice_url`) to load in the WebView.
  final String checkoutUrl;

  /// Custom deep link URL to intercept as success/failure redirect.
  final String returnDeepLink;

  /// Callback triggered when the deep link is hit.
  ///
  /// The full [Uri] (including query parameters) is passed back.
  final ValueChanged<Uri> onReturn;

  /// Optional title for the AppBar.
  final String? appBarTitle;

  /// Creates a [CheckoutWebView].
  const CheckoutWebView({
    super.key,
    required this.checkoutUrl,
    required this.returnDeepLink,
    required this.onReturn,
    this.appBarTitle,
  });

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (req) {
            if (req.url.startsWith(widget.returnDeepLink)) {
              widget.onReturn(Uri.parse(req.url));
              if (mounted) Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: widget.appBarTitle ?? ''),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
