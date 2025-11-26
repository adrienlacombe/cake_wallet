import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cw_starknet/starknet_exceptions.dart';

class StarknetExplorerApi {
  // Using Voyager Beta API
  static const String _baseUrl = 'https://api.voyager.online/beta';

  Future<List<Map<String, dynamic>>> getTransactions(String address, {int page = 1, int pageSize = 20}) async {
    final url = Uri.parse('$_baseUrl/txns?to=$address&ps=$pageSize&p=$page');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Voyager API returns { "items": [...], "lastPage": ... }
        if (data is Map<String, dynamic> && data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(data['items'] as List);
        } else {
          return [];
        }
      } else {
        print('Explorer API error: ${response.statusCode} - ${response.body}');
        // Return empty list instead of throwing to avoid blocking the UI
        return [];
      }
    } catch (e) {
      print('Explorer API connection error: $e');
      // Return empty list on connection error
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTransfers(String address, {int page = 1, int pageSize = 20}) async {
    final url = Uri.parse('$_baseUrl/transfers?to=$address&ps=$pageSize&p=$page');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('items')) {
          return List<Map<String, dynamic>>.from(data['items'] as List);
        } else {
          return [];
        }
      } else {
        print('Explorer API error (transfers): ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Explorer API connection error (transfers): $e');
      return [];
    }
  }
}
