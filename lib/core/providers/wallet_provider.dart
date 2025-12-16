import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletProvider extends ChangeNotifier {
  double _balance = 0.0;
  double _orderFee = 500.0;
  double _creditLimit = -10000.0;
  bool _canPlaceOrder = true;
  bool _isLoading = false;
  String? _error;
  
  List<WalletTransaction> _transactions = [];
  
  // Realtime subscriptions
  StreamSubscription? _walletSubscription;
  StreamSubscription? _transactionsSubscription;
  String? _currentMerchantId;
  
  // Getters
  double get balance => _balance;
  double get orderFee => _orderFee;
  double get creditLimit => _creditLimit;
  bool get canPlaceOrder => _canPlaceOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WalletTransaction> get transactions => _transactions;
  
  // Format balance for display
  String get formattedBalance => '${_balance.toStringAsFixed(0)} IQD';
  
  // Check if balance is low (within 20% of credit limit)
  bool get isBalanceLow {
    final threshold = _creditLimit + ((_creditLimit.abs()) * 0.2);
    return _balance <= threshold;
  }
  
  // Check if balance is critical (at or below credit limit)
  bool get isBalanceCritical => _balance <= _creditLimit;
  
  // Initialize wallet data
  Future<void> initialize(String merchantId) async {
    _isLoading = true;
    _error = null;
    _currentMerchantId = merchantId;
    notifyListeners();
    
    try {
      await loadWalletData(merchantId);
      await loadTransactions(merchantId);
      
      // Set up realtime listeners
      _setupRealtimeListeners(merchantId);
    } catch (e) {
      _error = 'فشل تحميل بيانات المحفظة: $e';
      print('Error initializing wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Set up realtime listeners
  void _setupRealtimeListeners(String merchantId) {
    // Cancel existing subscriptions
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    
    // Listen to wallet balance changes
    _walletSubscription = Supabase.instance.client
        .from('merchant_wallets')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .listen(
      (data) {
        if (data.isNotEmpty) {
          final walletData = data.first;
          _balance = (walletData['balance'] as num).toDouble();
          _orderFee = (walletData['order_fee'] as num).toDouble();
          _creditLimit = (walletData['credit_limit'] as num).toDouble();
          _canPlaceOrder = _balance >= _creditLimit;
          notifyListeners();
          print('💰 Wallet updated via realtime: $_balance IQD');
        }
      },
      onError: (error) {
        print('❌ Wallet realtime error: $error');
      },
    );
    
    // Listen to transaction changes
    _transactionsSubscription = Supabase.instance.client
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false)
        .limit(50)
        .listen(
      (data) {
        _transactions = data
            .map((json) => WalletTransaction.fromJson(json))
            .toList();
        notifyListeners();
        print('📝 Transactions updated via realtime: ${_transactions.length} transactions');
      },
      onError: (error) {
        print('❌ Transactions realtime error: $error');
      },
    );
  }
  
  // Load wallet data
  Future<void> loadWalletData(String merchantId) async {
    try {
      final response = await Supabase.instance.client
          .from('merchant_wallets')
          .select()
          .eq('merchant_id', merchantId)
          .maybeSingle();
      
      if (response != null) {
        _balance = (response['balance'] as num).toDouble();
        _orderFee = (response['order_fee'] as num).toDouble();
        _creditLimit = (response['credit_limit'] as num).toDouble();
        _canPlaceOrder = _balance >= _creditLimit;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      rethrow;
    }
  }
  
  // Load transactions
  Future<void> loadTransactions(String merchantId, {int limit = 50}) async {
    try {
      final response = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      _transactions = (response as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading transactions: $e');
      rethrow;
    }
  }
  
  // Top up wallet
  Future<bool> topUpWallet({
    required String merchantId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await Supabase.instance.client.rpc(
        'add_wallet_balance',
        params: {
          'p_merchant_id': merchantId,
          'p_amount': amount,
          'p_payment_method': paymentMethod,
          'p_notes': notes,
        },
      );
      
      if (response != null && response['success'] == true) {
        // Reload wallet data
        await loadWalletData(merchantId);
        await loadTransactions(merchantId);
        return true;
      }
      
      return false;
    } catch (e) {
      _error = 'فشل شحن المحفظة: $e';
      print('Error topping up wallet: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create Wayl payment link
  Future<Map<String, dynamic>?> createWaylPaymentLink({
    required String merchantId,
    required double amount,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[WalletProvider] Creating Wayl payment link - merchantId: $merchantId, amount: $amount');
      
      final response = await Supabase.instance.client.functions.invoke(
        'wayl-payment',
        body: {
          'merchant_id': merchantId,
          'amount': amount,
          'notes': notes,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[WalletProvider] Request timed out');
          throw TimeoutException('Request timed out after 30 seconds');
        },
      );
      
      print('[WalletProvider] Response received');
      print('[WalletProvider] Response status: ${response.status}');
      print('[WalletProvider] Response data type: ${response.data.runtimeType}');
      print('[WalletProvider] Response data: ${response.data}');
      
      if (response.status == 200) {
        if (response.data != null) {
          final data = response.data as Map<String, dynamic>;
          print('[WalletProvider] Payment link created successfully');
          print('[WalletProvider] Payment URL: ${data['payment_url']}');
          return data;
        } else {
          print('[WalletProvider] Response status is 200 but data is null');
          _error = 'Received empty response from server';
          return null;
        }
      } else {
        // Handle error response (status 400, 500, etc.)
        final errorData = response.data is Map<String, dynamic> 
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final errorMessage = errorData['error'] ?? 'فشل إنشاء رابط الدفع (Status: ${response.status})';
        _error = errorMessage;
        print('[WalletProvider] Error response: $errorMessage');
        print('[WalletProvider] Full error data: $errorData');
        return null;
      }
    } on TimeoutException catch (e) {
      _error = 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
      print('[WalletProvider] Timeout error: $e');
      return null;
    } catch (e, stackTrace) {
      _error = 'فشل إنشاء رابط الدفع: $e';
      print('[WalletProvider] Error creating Wayl payment link: $e');
      print('[WalletProvider] Error type: ${e.runtimeType}');
      print('[WalletProvider] Stack trace: $stackTrace');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('[WalletProvider] Finally block executed - isLoading: $_isLoading');
    }
  }
  
  // Get wallet summary
  Future<Map<String, dynamic>?> getWalletSummary(String merchantId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_wallet_summary',
        params: {'p_merchant_id': merchantId},
      );
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting wallet summary: $e');
      return null;
    }
  }
  
  // Refresh wallet data
  Future<void> refresh(String merchantId) async {
    await initialize(merchantId);
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Dispose and cleanup
  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}

// Wallet Transaction Model
class WalletTransaction {
  final String id;
  final String merchantId;
  final String transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? orderId;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  
  WalletTransaction({
    required this.id,
    required this.merchantId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });
  
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      merchantId: json['merchant_id'],
      transactionType: json['transaction_type'],
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      orderId: json['order_id'],
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  // Get display title based on transaction type
  String get title {
    switch (transactionType) {
      case 'top_up':
        return 'شحن المحفظة';
      case 'order_fee':
        return 'رسوم توصيل';
      case 'refund':
        return 'استرجاع';
      case 'adjustment':
        return 'تعديل';
      case 'initial_gift':
        return 'هدية ترحيبية';
      default:
        return 'معاملة';
    }
  }
  
  // Get icon based on transaction type
  IconData get icon {
    switch (transactionType) {
      case 'top_up':
        return Icons.add_circle;
      case 'order_fee':
        return Icons.shopping_bag;
      case 'refund':
        return Icons.replay;
      case 'adjustment':
        return Icons.tune;
      case 'initial_gift':
        return Icons.card_giftcard;
      default:
        return Icons.receipt;
    }
  }
  
  // Get color based on transaction type
  Color get color {
    return amount >= 0 
        ? Colors.green 
        : Colors.red;
  }
  
  // Get formatted amount
  String get formattedAmount {
    final absAmount = amount.abs().toStringAsFixed(0);
    final sign = amount >= 0 ? '+' : '-';
    return '$sign $absAmount IQD';
  }
  
  // Get payment method display name
  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case 'zain_cash':
        return 'زين كاش';
      case 'qi_card':
        return 'بطاقة كي';
      case 'hur_representative':
        return 'ممثل حر';
      case 'admin_adjustment':
        return 'تعديل إداري';
      case 'initial_gift':
        return 'هدية ترحيبية';
      case 'wayl':
        return 'Wayl';
      default:
        return paymentMethod ?? 'غير محدد';
    }
  }
}
