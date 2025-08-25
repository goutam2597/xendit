import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'checkout_webview.dart';
import 'xendit_models.dart';

/// Xendit checkout helper (invoice-based).
///
/// Typical flow:
/// 1. Create invoice via Xendit REST API.
/// 2. Get `invoice_url`.
/// 3. Open checkout in a WebView.
/// 4. Intercept deep link return (success/failure).
/// 5. Optionally verify via `GET /v2/invoices/{id}`.
///
/// ⚠️ In production:
/// - Create invoices on your server using your **Secret Key**.
/// - Pass only `invoice_url` into the app.
/// - Use server webhooks for authoritative status.
class XenditCheckout {
  /// Creates an invoice and opens checkout in a WebView.
  ///
  /// [apiKey] must be a **Public Key** for sandbox/demo.
  ///
  /// - [externalId] unique external ID for this invoice.
  /// - [payerEmail] payer’s email address.
  /// - [description] short description of the payment.
  /// - [amount] invoice amount as integer string in the currency’s base unit
  ///   (e.g. `'100000'` for IDR 100,000).
  /// - [currency] (default `'IDR'`) — e.g. `'IDR'`, `'PHP'` (availability depends on your Xendit account).
  /// - [returnDeepLink] custom URL scheme for redirect back into the app.
  /// - [baseUrl] Xendit base API URL (default `https://api.xendit.co`).
  ///
  /// Returns a [XenditPaymentResult] with invoice ID and status.
  static Future<XenditPaymentResult> startPayment({
    required BuildContext context,
    required String apiKey,
    required String externalId,
    required String payerEmail,
    required String description,
    required String amount,
    required String returnDeepLink,
    String currency = 'USD',
    String baseUrl = 'https://api.xendit.co',
    String? appBarTitle,
  }) async {
    // 1) Create invoice
    final res = await http.post(
      Uri.parse('$baseUrl/v2/invoices'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:'))}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'external_id': externalId,
        'payer_email': payerEmail,
        'description': description,
        'amount': int.parse(amount),
        'currency': currency,
        'success_redirect_url': returnDeepLink,
        'failure_redirect_url': returnDeepLink,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw XenditCheckoutException(
        'Invoice creation failed: ${res.statusCode} ${res.body}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final invoiceId = body['id'] as String?;
    final invoiceUrl = body['invoice_url'] as String?;
    final status = body['status'] as String?;

    if (invoiceId == null || invoiceUrl == null) {
      throw XenditCheckoutException('Invalid invoice response');
    }

    // 2) Open checkout
    String finalStatus = status ?? 'PENDING';
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutWebView(
            checkoutUrl: invoiceUrl,
            returnDeepLink: returnDeepLink,
            onReturn: (uri) {
              final qStatus = uri.queryParameters['status'];
              if (qStatus != null) finalStatus = qStatus.toUpperCase();
            },
            appBarTitle: appBarTitle ?? 'Xendit Checkout',
          ),
        ),
      );
    }

    // 3) Verify via GET /v2/invoices/{id}
    try {
      final verifyRes = await http.get(
        Uri.parse('$baseUrl/v2/invoices/$invoiceId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:'))}',
          'Accept': 'application/json',
        },
      );
      if (verifyRes.statusCode == 200) {
        final verifyBody = jsonDecode(verifyRes.body);
        finalStatus = (verifyBody['status'] ?? finalStatus).toString();
        return XenditPaymentResult(
          invoiceId: invoiceId,
          status: finalStatus,
          raw: verifyBody,
        );
      }
    } catch (_) {
      // fall back to interim status
    }

    return XenditPaymentResult(
      invoiceId: invoiceId,
      status: finalStatus,
      raw: body,
    );
  }
}
