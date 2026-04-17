import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  // ---------------------------------------------------------
  // 1. Send Text Messages (For the Chatbox)
  // ---------------------------------------------------------
  static Future<String> sendMessage(String message, bool isCustomer) async {
    try {
      // We use the local URL for testing, change to prod URL for Render later
      final response = await http.post(
        Uri.parse('${AppConstants.localApiBaseUrl}/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'sender': isCustomer ? 'customer' : 'cashier',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? "Message received.";
      } else {
        return "Error: Backend returned ${response.statusCode}";
      }
    } catch (e) {
      // If the Python server isn't running, it will catch the error here
      print("Connection error: $e");
      return "Connection failed. Is the Python server running?";
    }
  }

  // ---------------------------------------------------------
  // 2. Fetch Inventory (For the "View Available Items" button)
  // ---------------------------------------------------------
  static Future<List<dynamic>> fetchInventory() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.localApiBaseUrl}/inventory'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['items'] ?? [];
      }
      return [];
    } catch (e) {
      print("Inventory fetch error: $e");
      return [];
    }
  }

  // ---------------------------------------------------------
  // 3. Real-Time ASL Video Stream Setup
  // ---------------------------------------------------------
  // Standard HTTP is too slow for real-time video frames. 
  // For the hackathon, you will likely connect to Python via WebSockets here.
  static void connectVideoStream() {
    print("Ready to connect WebSocket for MediaPipe processing...");
    // TODO: Implement web_socket_channel package to stream camera frames
    // to Python OpenCV/MediaPipe and receive text translations instantly.
  }
}