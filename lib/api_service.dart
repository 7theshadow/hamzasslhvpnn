// lib/api_service.dart
// يتصل بـ api/get_settings.php ويرجع قائمة الفئات مع سيرفراتها.
// أصبح بدون توكن/تسجيل دخول - الـ API عام حسب طلب صاحب المشروع.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  // غيّر الدومين إذا احتاج الأمر
  static const String baseUrl = 'https://web.hamzasslh.biz.tr/api';

  /// يجيب الفئات مع السيرفرات الجاهزة داخل كل وحدة
  static Future<List<ServerCategory>> fetchServers() async {
    final url = Uri.parse('$baseUrl/get_settings.php');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('فشل الاتصال بالسيرفر (${response.statusCode})');
    }

    final data = jsonDecode(response.body);

    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error']);
    }

    final List<dynamic> rawCategories = data['categories'] ?? [];
    return rawCategories
        .map((e) => ServerCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// يتحقق من بيانات الحساب عبر check_user_url الخاص بالسيرفر (نمط DTunnel):
  /// GET {checkUserUrl}/check/{uuid}?deviceId={deviceId}
  static Future<UserAccountInfo?> checkUser({
    required String checkUserUrl,
    required String uuid,
    required String deviceId,
  }) async {
    final url = Uri.parse('$checkUserUrl/check/$uuid?deviceId=$deviceId');

    final response = await http.get(url, headers: {'Accept': 'application/json'});

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data is Map && data.containsKey('error')) return null;

    return UserAccountInfo.fromJson(data as Map<String, dynamic>);
  }
}
