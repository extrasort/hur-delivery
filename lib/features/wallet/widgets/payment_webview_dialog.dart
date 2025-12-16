import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../shared/widgets/responsive_container.dart';
import '../../../core/localization/app_localizations.dart';

/// WebView dialog for displaying payment pages (Wayl checkout)
class PaymentWebViewDialog extends StatefulWidget {
  final String paymentUrl;
  final String? referenceId;
  final VoidCallback? onPaymentComplete;
  final VoidCallback? onPaymentCancelled;
  final VoidCallback? onError;

  const PaymentWebViewDialog({
    super.key,
    required this.paymentUrl,
    this.referenceId,
    this.onPaymentComplete,
    this.onPaymentCancelled,
    this.onError,
  });

  @override
  State<PaymentWebViewDialog> createState() => _PaymentWebViewDialogState();
}

class _PaymentWebViewDialogState extends State<PaymentWebViewDialog> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[PaymentWebView] Page started loading: $url');
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            print('[PaymentWebView] Page finished loading: $url');
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('[PaymentWebView] Error: ${error.description}');
            print('[PaymentWebView] Error code: ${error.errorCode}');
            print('[PaymentWebView] Error type: ${error.errorType}');
            
            // Show error to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).errorLoadingPaymentPage(error.description)),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            
            widget.onError?.call();
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            print('[PaymentWebView] Navigation request: $url');

            // Check if this is a success/redirect URL
            // Wayl typically redirects to redirectionUrl after payment
            // Also check for common success indicators
            if (url.contains('payment-success') || 
                url.contains('payment_success') ||
                url.contains('/success') ||
                url.contains('payment-completed') ||
                url.contains('payment_completed') ||
                url.contains('completed') ||
                (widget.referenceId != null && url.contains(widget.referenceId!.toLowerCase()))) {
              print('[PaymentWebView] Payment success detected from URL: $url');
              // Close dialog and notify parent
              // The webhook will handle updating the wallet balance
              Future.microtask(() {
                if (mounted) {
                  Navigator.of(context).pop();
                  widget.onPaymentComplete?.call();
                }
              });
              return NavigationDecision.prevent;
            }

            // Check if this is a cancellation URL
            if (url.contains('payment-cancelled') || 
                url.contains('payment_cancelled') ||
                url.contains('/cancel') ||
                url.contains('/cancelled')) {
              print('[PaymentWebView] Payment cancelled');
              Future.microtask(() {
                if (mounted) {
                  Navigator.of(context).pop();
                  widget.onPaymentCancelled?.call();
                }
              });
              return NavigationDecision.prevent;
            }

            // Allow navigation to payment pages
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            final url = change.url?.toLowerCase() ?? '';
            print('[PaymentWebView] URL changed: $url');
            
            // Check for success indicators in URL changes
            if (url.contains('success') || url.contains('completed')) {
              print('[PaymentWebView] Success detected in URL change');
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.of(context).pop();
                  widget.onPaymentComplete?.call();
                }
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));

    print('[PaymentWebView] Initialized with URL: ${widget.paymentUrl}');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'صفحة الدفع',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPaymentCancelled?.call();
                    },
                  ),
                ],
              ),
            ),
            // WebView
            Flexible(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Container(
                      color: Colors.white,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
            // Footer info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يمكنك الدفع عبر Zain Cash، Qi Card، أو بطاقات Visa/Mastercard',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

