/// Result of a Xendit checkout (invoice-based) flow.
class XenditPaymentResult {
  /// Xendit invoice ID (e.g., `inv-1234`).
  final String invoiceId;

  /// Invoice status: `"PENDING"`, `"PAID"`, `"EXPIRED"`, etc.
  final String status;

  /// Raw API response body captured during verification.
  final Map<String, dynamic> raw;

  /// Creates an immutable [XenditPaymentResult].
  const XenditPaymentResult({
    required this.invoiceId,
    required this.status,
    required this.raw,
  });

  /// Convenience getter: `true` if [status] is `"PAID"`.
  bool get isPaid => status.toUpperCase() == 'PAID';
}

/// Exception thrown for Xendit checkout errors.
class XenditCheckoutException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional root cause object.
  final Object? cause;

  /// Creates a [XenditCheckoutException].
  XenditCheckoutException(this.message, [this.cause]);

  @override
  String toString() => 'XenditCheckoutException: $message';
}
