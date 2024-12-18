import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart'; // To load JSON file from assets

class FCMService {
  static const String _scopes = 'https://www.googleapis.com/auth/firebase.messaging';

  // Load the service account key
  static Future<ServiceAccountCredentials> _loadServiceAccount() async {
    final jsonString = await rootBundle.loadString('assets/hedieaty-3314d-ecae65072600.json');
    final jsonMap = json.decode(jsonString);
    return ServiceAccountCredentials.fromJson(jsonMap);
  }

  // Generate OAuth 2.0 Token
  static Future<AutoRefreshingAuthClient> _getAuthClient() async {
    final credentials = await _loadServiceAccount();
    return clientViaServiceAccount(credentials, [_scopes]);
  }

  // Send Notification via HTTP v1 API
  static Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final client = await _getAuthClient();
    final projectId = "hedieaty-3314d"; // Replace with your Firebase Project ID

    final url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    final payload = {
      "message": {
        "token": token,
        "notification": {
          "title": title,
          "body": body,
        },
        "data": data ?? {},
      }
    };

    final response = await client.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      print("Notification sent successfully: ${response.body}");
    } else {
      print("Failed to send notification: ${response.statusCode} ${response.body}");
    }

    client.close();
  }
}
