import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Comprehensive error types
enum ErrorType {
  networkConnection,      // No internet, connection refused
  networkTimeout,         // Request timeout
  networkHandshake,       // HandshakeException, SSL errors
  networkClosed,          // Connection closed before completion
  authExpired,            // Session expired, 401
  authInvalid,            // Invalid credentials
  serverError,            // 500, 502, 503
  rateLimit,              // 429 Too Many Requests
  notFound,               // 404
  permissionDenied,       // 403
  unknown,                // Other errors
}

/// Error recovery strategy
enum RecoveryStrategy {
  retry,                  // Retry the request
  refreshSession,         // Refresh auth session then retry
  reconnect,              // Reconnect to Supabase
  showError,              // Show error to user
  silentFail,             // Fail silently (non-critical operations)
  forceLogout,            // Force user logout
}

/// Error information class
class AppError {
  final ErrorType type;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final RecoveryStrategy strategy;
  final bool isRetryable;
  final int? httpStatusCode;
  final DateTime timestamp;

  AppError({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
    required this.strategy,
    this.isRetryable = true,
    this.httpStatusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'AppError($type): $message';
}

/// Comprehensive error manager with retry logic and recovery strategies
class ErrorManager {
  static final ErrorManager _instance = ErrorManager._internal();
  factory ErrorManager() => _instance;
  ErrorManager._internal();

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration baseRetryDelay = Duration(seconds: 1);
  static const Duration maxRetryDelay = Duration(seconds: 30);
  static const Duration sessionRefreshTimeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 15);

  // State tracking
  bool _isRefreshingSession = false;
  bool _isReconnecting = false;
  DateTime? _lastSessionRefresh;
  DateTime? _lastReconnectAttempt;
  Timer? _connectionCheckTimer;

  /// Analyze error and return AppError with recovery strategy
  static AppError analyzeError(dynamic error, [StackTrace? stackTrace]) {
    final errorString = error.toString().toLowerCase();
    final errorType = _determineErrorType(error, errorString);
    final strategy = _determineRecoveryStrategy(errorType, error);
    final message = _getUserFriendlyMessage(errorType, error);

    int? httpStatusCode;
    if (error is PostgrestException) {
      // PostgrestException.code is a string like '401', 'PGRST301', etc.
      // Try to extract numeric HTTP status code
      final codeStr = error.code ?? '';
      if (codeStr.isNotEmpty && RegExp(r'^\d{3}$').hasMatch(codeStr)) {
        httpStatusCode = int.tryParse(codeStr);
      } else if (codeStr.contains('401')) {
        httpStatusCode = 401;
      } else if (codeStr.contains('403')) {
        httpStatusCode = 403;
      } else if (codeStr.contains('404')) {
        httpStatusCode = 404;
      } else if (codeStr.contains('429')) {
        httpStatusCode = 429;
      } else if (codeStr.contains('500')) {
        httpStatusCode = 500;
      }
    }

    return AppError(
      type: errorType,
      message: message,
      originalError: error,
      stackTrace: stackTrace,
      strategy: strategy,
      isRetryable: _isRetryableError(errorType),
      httpStatusCode: httpStatusCode,
    );
  }

  /// Determine error type from error object
  static ErrorType _determineErrorType(dynamic error, String errorString) {
    // Network handshake errors
    if (error is HandshakeException ||
        errorString.contains('handshake') ||
        errorString.contains('connection terminated during handshake') ||
        errorString.contains('ssl') ||
        errorString.contains('tls')) {
      return ErrorType.networkHandshake;
    }

    // Connection closed errors
    if (errorString.contains('connection closed') ||
        errorString.contains('connection terminated') ||
        errorString.contains('connection reset') ||
        errorString.contains('broken pipe') ||
        errorString.contains('connection closed before full header')) {
      return ErrorType.networkClosed;
    }

    // Network timeout
    if (error is SocketException ||
        error is TimeoutException ||
        errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return ErrorType.networkTimeout;
    }

    // Network connection errors
    if (error is SocketException ||
        errorString.contains('network') ||
        errorString.contains('connection refused') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no internet') ||
        errorString.contains('no connection')) {
      return ErrorType.networkConnection;
    }

    // Auth errors
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '401' || code == 'PGRST301' || code.contains('401')) {
        return ErrorType.authExpired;
      }
      if (code == '403' || code.contains('403')) {
        return ErrorType.permissionDenied;
      }
      if (code == '404' || code.contains('404')) {
        return ErrorType.notFound;
      }
      if (code == '429' || code.contains('429')) {
        return ErrorType.rateLimit;
      }
      if (code.contains('500') || code.contains('502') || code.contains('503')) {
        return ErrorType.serverError;
      }
    }

    // Check error string for auth keywords
    if (errorString.contains('401') ||
        errorString.contains('unauthorized') ||
        errorString.contains('session expired') ||
        errorString.contains('token expired') ||
        errorString.contains('authentication')) {
      return ErrorType.authExpired;
    }

    // Check for rate limiting
    if (errorString.contains('429') || errorString.contains('rate limit')) {
      return ErrorType.rateLimit;
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('internal server error')) {
      return ErrorType.serverError;
    }

    return ErrorType.unknown;
  }

  /// Determine recovery strategy based on error type
  static RecoveryStrategy _determineRecoveryStrategy(ErrorType type, dynamic error) {
    switch (type) {
      case ErrorType.authExpired:
        return RecoveryStrategy.refreshSession;
      
      case ErrorType.networkHandshake:
      case ErrorType.networkClosed:
      case ErrorType.networkConnection:
        return RecoveryStrategy.reconnect;
      
      case ErrorType.networkTimeout:
      case ErrorType.serverError:
      case ErrorType.rateLimit:
        return RecoveryStrategy.retry;
      
      case ErrorType.permissionDenied:
        return RecoveryStrategy.showError;
      
      case ErrorType.notFound:
        return RecoveryStrategy.showError;
      
      case ErrorType.unknown:
        return RecoveryStrategy.showError;
      
      default:
        return RecoveryStrategy.showError;
    }
  }

  /// Check if error is retryable
  static bool _isRetryableError(ErrorType type) {
    return [
      ErrorType.networkConnection,
      ErrorType.networkTimeout,
      ErrorType.networkHandshake,
      ErrorType.networkClosed,
      ErrorType.serverError,
      ErrorType.rateLimit,
    ].contains(type);
  }

  /// Get user-friendly error message in Arabic
  static String _getUserFriendlyMessage(ErrorType type, dynamic error) {
    // If it's a database (PostgREST) error, try to surface a concise message
    String? dbMsg;
    if (error is PostgrestException) {
      final parts = <String>{
        _asTrimmedString(error.message) ?? '',
        _asTrimmedString(error.details) ?? '',
        _asTrimmedString(error.hint) ?? '',
      }..removeWhere((value) => value.isEmpty);

      if (parts.isNotEmpty) {
        dbMsg = parts.join(' • ');
      }
    }

    switch (type) {
      case ErrorType.networkConnection:
        return 'لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك والمحاولة مرة أخرى.';
      
      case ErrorType.networkTimeout:
        return 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
      
      case ErrorType.networkHandshake:
      case ErrorType.networkClosed:
        return 'فشل الاتصال بالخادم. يتم إعادة الاتصال تلقائياً...';
      
      case ErrorType.authExpired:
        return 'انتهت صلاحية الجلسة. يتم تحديث الجلسة...';
      
      case ErrorType.authInvalid:
        return 'بيانات الاعتماد غير صحيحة. يرجى تسجيل الدخول مرة أخرى.';
      
      case ErrorType.serverError:
        return dbMsg?.isNotEmpty == true
            ? dbMsg!
            : 'خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً.';
      
      case ErrorType.rateLimit:
        return 'تم إرسال طلبات كثيرة. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.';
      
      case ErrorType.notFound:
        return 'المورد المطلوب غير موجود.';
      
      case ErrorType.permissionDenied:
        return 'ليس لديك الصلاحية للوصول إلى هذا المورد.';
      
      case ErrorType.unknown:
        return dbMsg?.isNotEmpty == true
            ? dbMsg!
            : 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }
  }

  static String? _asTrimmedString(dynamic value) {
    if (value == null) return null;
    final str = value is String ? value : value.toString();
    final trimmed = str.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Handle error with automatic recovery
  Future<T?> handleError<T>({
    required Future<T> Function() operation,
    String? operationName,
    bool isCritical = false,
    int maxRetries = ErrorManager.maxRetries,
    RecoveryStrategy? overrideStrategy,
    VoidCallback? onRetry,
    VoidCallback? onFailure,
  }) async {
    AppError? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final result = await operation();
        if (attempt > 0) {
          print('✅ Operation ${operationName ?? "unknown"} succeeded after $attempt retries');
        }
        return result;
      } catch (error, stackTrace) {
        lastError = analyzeError(error, stackTrace);
        
        print('❌ Error in ${operationName ?? "operation"} (attempt ${attempt + 1}/${maxRetries + 1}):');
        print('   Type: ${lastError.type}');
        print('   Strategy: ${lastError.strategy}');
        print('   Error: $error');

        // Apply recovery strategy
        final strategy = overrideStrategy ?? lastError.strategy;
        final shouldRetry = attempt < maxRetries && lastError.isRetryable;

        switch (strategy) {
          case RecoveryStrategy.retry:
            if (shouldRetry) {
              final delay = _calculateRetryDelay(attempt);
              print('⏳ Retrying in ${delay.inSeconds}s...');
              await Future.delayed(delay);
              onRetry?.call();
              continue;
            }
            break;

          case RecoveryStrategy.refreshSession:
            if (shouldRetry && await _refreshSession()) {
              print('✅ Session refreshed, retrying...');
              onRetry?.call();
              continue;
            } else if (isCritical) {
              print('❌ Critical operation failed after session refresh');
              onFailure?.call();
              return null;
            }
            break;

          case RecoveryStrategy.reconnect:
            if (shouldRetry && await _reconnectSupabase()) {
              print('✅ Reconnected, retrying...');
              onRetry?.call();
              continue;
            } else if (isCritical) {
              print('❌ Critical operation failed after reconnect');
              onFailure?.call();
              return null;
            }
            break;

          case RecoveryStrategy.silentFail:
            if (!isCritical) {
              print('⚠️ Non-critical error, failing silently');
              return null;
            }
            break;

          case RecoveryStrategy.forceLogout:
            print('🔐 Forcing logout due to auth error');
            // This should be handled by AuthProvider
            onFailure?.call();
            return null;

          case RecoveryStrategy.showError:
            print('⚠️ Showing error to user');
            onFailure?.call();
            return null;
        }

        // If we get here, all retries failed
        if (isCritical) {
          print('❌ Critical operation failed after all retries');
          onFailure?.call();
        }
        return null;
      }
    }

    return null;
  }

  /// Calculate exponential backoff delay
  static Duration _calculateRetryDelay(int attempt) {
    final delay = Duration(
      milliseconds: (baseRetryDelay.inMilliseconds * (1 << attempt)).clamp(
        baseRetryDelay.inMilliseconds,
        maxRetryDelay.inMilliseconds,
      ),
    );
    return delay;
  }

  /// Refresh Supabase session
  Future<bool> _refreshSession() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshingSession) {
      print('⏳ Session refresh already in progress, waiting...');
      int waitCount = 0;
      while (_isRefreshingSession && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
      return !_isRefreshingSession;
    }

    // Throttle refresh attempts
    if (_lastSessionRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastSessionRefresh!);
      if (timeSinceLastRefresh < sessionRefreshTimeout) {
        print('⏳ Session refresh throttled (${timeSinceLastRefresh.inSeconds}s ago)');
        return false;
      }
    }

    _isRefreshingSession = true;
    _lastSessionRefresh = DateTime.now();

    try {
      print('🔄 Refreshing Supabase session...');
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        // Try to refresh the session
        final response = await Supabase.instance.client.auth.refreshSession()
            .timeout(sessionRefreshTimeout);
        
        if (response.session != null) {
          print('✅ Session refreshed successfully');
          _isRefreshingSession = false;
          return true;
        }
      }

      print('⚠️ No active session to refresh');
      _isRefreshingSession = false;
      return false;
    } catch (e) {
      print('❌ Session refresh failed: $e');
      _isRefreshingSession = false;
      return false;
    }
  }

  /// Reconnect to Supabase
  Future<bool> _reconnectSupabase() async {
    // Prevent concurrent reconnect attempts
    if (_isReconnecting) {
      print('⏳ Reconnection already in progress, waiting...');
      int waitCount = 0;
      while (_isReconnecting && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }
      return !_isReconnecting;
    }

    // Throttle reconnect attempts
    if (_lastReconnectAttempt != null) {
      final timeSinceLastReconnect = DateTime.now().difference(_lastReconnectAttempt!);
      if (timeSinceLastReconnect < connectionTimeout) {
        print('⏳ Reconnect throttled (${timeSinceLastReconnect.inSeconds}s ago)');
        return false;
      }
    }

    _isReconnecting = true;
    _lastReconnectAttempt = DateTime.now();

    try {
      print('🔄 Reconnecting to Supabase...');
      
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('❌ No internet connection');
        _isReconnecting = false;
        return false;
      }

      // Try a simple query to test connection
      await Supabase.instance.client
          .from('users')
          .select('id')
          .limit(1)
          .timeout(connectionTimeout);

      print('✅ Reconnected to Supabase successfully');
      _isReconnecting = false;
      return true;
    } catch (e) {
      print('❌ Reconnection failed: $e');
      _isReconnecting = false;
      return false;
    }
  }

  /// Check if internet connection is available
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Safe execute with automatic error handling
  static Future<T?> safeExecute<T>({
    required Future<T> Function() operation,
    String? operationName,
    bool isCritical = false,
    T? defaultValue,
    RecoveryStrategy? strategy,
  }) async {
    return await _instance.handleError<T>(
      operation: operation,
      operationName: operationName,
      isCritical: isCritical,
      overrideStrategy: strategy,
    ) ?? defaultValue;
  }

  /// Cleanup resources
  void dispose() {
    _connectionCheckTimer?.cancel();
  }
}

/// Extension methods for easy error handling
extension ErrorHandlingExtension on Future {
  Future<T?> handleError<T>({
    String? operationName,
    bool isCritical = false,
    T? defaultValue,
  }) async {
    return await ErrorManager.safeExecute<T>(
      operation: () => this as Future<T>,
      operationName: operationName,
      isCritical: isCritical,
      defaultValue: defaultValue,
    );
  }
}
