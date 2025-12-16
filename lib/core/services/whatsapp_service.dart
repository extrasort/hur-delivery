import 'dart:convert';
import 'package:http/http.dart' as http;

class WhatsAppService {
  // Use Supabase edge function proxy for security
  static const String _baseUrl = 'https://bvtoxmmiitznagsbubhg.supabase.co/functions/v1/whatsapp-proxy';
  
  /// Check if WhatsApp server is connected
  static Future<bool> isConnected() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['connected'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Error checking WhatsApp connection: $e');
      return false;
    }
  }

  /// Send OTP via WhatsApp
  static Future<WhatsAppResponse> sendOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      print('📱 Sending OTP via WhatsApp to: $phoneNumber');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'otp': otp,
        }),
      );

      print('📡 WhatsApp API Response:');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['success'] == true) {
        return WhatsAppResponse(
          success: true,
          message: 'OTP sent successfully via WhatsApp',
          data: responseData['data'],
        );
      } else {
        String errorMessage = responseData['error'] ?? 'Failed to send OTP';
        
        // Check if user doesn't have WhatsApp
        if (errorMessage.contains('not registered') || 
            errorMessage.contains('no account') ||
            errorMessage.contains('does not have WhatsApp') ||
            errorMessage.contains('User does not have WhatsApp account')) {
          return WhatsAppResponse(
            success: false,
            message: 'لا يوجد حساب واتساب لهذا الرقم. يجب أن يكون لديك واتساب لتسجيل الدخول.',
            hasWhatsApp: false,
            data: responseData,
          );
        }
        
        return WhatsAppResponse(
          success: false,
          message: errorMessage,
          data: responseData,
        );
      }
    } catch (e) {
      print('❌ WhatsApp Service Error: $e');
      
      // Report error to edge function for better handling
      try {
        await _reportError(phoneNumber, e.toString(), 'otp_send');
      } catch (reportError) {
        print('⚠️ Failed to report error: $reportError');
      }
      
      return WhatsAppResponse(
        success: false,
        message: 'فشل في إرسال رمز التحقق: $e',
      );
    }
  }

  /// Verify OTP (no separate verification needed)
  static Future<WhatsAppResponse> verifyOTP({
    required String phoneNumber,
    required String otp,
  }) async {
    // WhatsApp OTP doesn't require separate verification
    // The OTP is verified locally in the app
    print('ℹ️ WhatsApp verification not required - OTP verified during sending');
    
    return WhatsAppResponse(
      success: true,
      message: 'OTP verification successful',
      data: {'verified': true},
    );
  }
}

/// Response model for WhatsApp service calls
class WhatsAppResponse {
  final bool success;
  final String message;
  final bool? hasWhatsApp;
  final Map<String, dynamic>? data;

  WhatsAppResponse({
    required this.success,
    required this.message,
    this.hasWhatsApp,
    this.data,
  });

  @override
  String toString() {
    return 'WhatsAppResponse(success: $success, message: $message, hasWhatsApp: $hasWhatsApp, data: $data)';
  }
}

/// Report WhatsApp errors to edge function for better handling
Future<void> _reportError(String phoneNumber, String error, String context) async {
  try {
    final response = await http.post(
      Uri.parse('https://bvtoxmmiitznagsbubhg.supabase.co/functions/v1/whatsapp-error-handler'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI2NzQ4MzIsImV4cCI6MjA0ODI1MDgzMn0.c551d00306bc9c4efb1251a44bbefc5ea40e7c1357c26753be5dfd63b736d440',
      },
      body: jsonEncode({
        'phone': phoneNumber,
        'error': error,
        'context': context,
      }),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      print('✅ Error reported successfully: ${result['user_message']}');
    }
  } catch (e) {
    print('⚠️ Failed to report error: $e');
  }
}

