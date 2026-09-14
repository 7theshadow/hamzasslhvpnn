// lib/singbox_config_builder.dart
// يبني إعدادات (Config JSON) بصيغة Sing-box انطلاقاً من بيانات السيرفر
// المخزّنة بلوحة التحكم (سواء V2Ray/VLESS أو SSH).

import 'dart:convert';
import 'dart:io';
import 'models.dart';

class SingboxConfigBuilder {
  /// يحل اسم الدومين إلى IP حقيقي *قبل* تشغيل الـ VPN (وقت الشبكة عادية بدون
  /// تنل)، عشان نتفادى مشكلة "حلقة مقفلة": sing-box ما يقدر يحل الدومين
  /// من جوا نفسه لأنه التنل نفسه لسا مش شغال وبانتظار نفس الحل!
  static Future<String?> resolveHostIp(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 6),
      );
      if (addresses.isNotEmpty) return addresses.first.address;
    } catch (_) {
      // فشل الحل مؤقتاً؛ منرجع null ومنخلي sing-box يحاول بنفسه كـ fallback
    }
    return null;
  }

  /// يبني JSON كامل جاهز لتمريره لـ client.connect(SessionOptions(config: ...))
  /// [resolvedIp] اختياري: IP تم حله مسبقاً (خارج التنل) لدومين سيرفر VLESS،
  /// إذا انمرر منستخدمه كـ server مباشرة بدل الدومين لتفادي مشكلة DNS loop.
  static String build({
    required ServerItem server,
    String? uuid,
    String? username,
    String? password,
    String? resolvedIp,
  }) {
    final Map<String, dynamic> outbound = server.mode == ConnectionMode.v2ray
        ? _buildVlessOutbound(server, uuid ?? '', resolvedIp)
        : _buildSshOutbound(server, username ?? '', password ?? '');

    final config = {
      'log': {'level': 'warn'},
      'dns': {
        'servers': [
          {
            'type': 'local',
            'tag': 'dns-local',
          },
        ],
        'strategy': 'ipv4_only',
      },
      'inbounds': [
        {
          'type': 'tun',
          'interface_name': 'tun0',
          'address': ['172.19.0.1/30'],
          'auto_route': true,
          'strict_route': true,
          'stack': 'gvisor',
        },
      ],
      'outbounds': [
        outbound,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': {
        'rules': [
          {'action': 'sniff'},
          {'action': 'hijack-dns'},
        ],
        'auto_detect_interface': true,
        'final': 'proxy',
      },
    };

    return jsonEncode(config);
  }

  /// يبني outbound من رابط vless://uuid@host:port?params (uuid ممكن يكون فاضي بالرابط
  /// ونعوضه من قيمة uuid يلي دخلها المستخدم بالتطبيق)
  static Map<String, dynamic> _buildVlessOutbound(
    ServerItem server,
    String enteredUuid,
    String? resolvedIp,
  ) {
    final raw = (server.config['v2ray_config'] ?? '').toString().trim();
    final uri = Uri.parse(raw);

    final realUuid = uri.userInfo.isNotEmpty ? uri.userInfo : enteredUuid;
    final qp = uri.queryParameters;

    final security = qp['security'] ?? 'none';
    final type = qp['type'] ?? 'tcp';
    final sni = qp['sni'] ?? uri.host;
    final wsHost = qp['host'] ?? uri.host;
    final path = qp['path'] ?? '/';
    final insecure = (qp['insecure'] == '1' || qp['allowInsecure'] == '1');
    final fp = qp['fp'] ?? 'chrome';

    // إذا كان في IP جاهز محفوظ بإعدادات هالسيرفر (server_ip بلوحة التحكم)،
    // نستخدمه فورًا بدون أي محاولة حل دومين نهائيًا — أسرع وأضمن.
    final configuredIp = (server.config['server_ip'] ?? '').toString().trim();

    // إذا عندنا IP محلول مسبقاً (خارج التنل) نستخدمه كعنوان اتصال مباشر،
    // وإلا نرجع للدومين العادي (sing-box بيحاول يحله بنفسه كـ fallback).
    final serverAddress = configuredIp.isNotEmpty
        ? configuredIp
        : (resolvedIp ?? uri.host);

    final Map<String, dynamic> outbound = {
      'type': 'vless',
      'tag': 'proxy',
      'server': serverAddress,
      'server_port': uri.hasPort ? uri.port : 443,
      'uuid': realUuid,
      'packet_encoding': 'xudp',
      'domain_strategy': 'ipv4_only',
    };

    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': path,
        'headers': {'Host': wsHost},
      };
    }

    if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'insecure': insecure,
        'utls': {'enabled': true, 'fingerprint': fp},
      };
    }

    return outbound;
  }

  /// يبني outbound من نوع SSH انطلاقاً من بيانات server/port المخزنة
  /// + اسم المستخدم وكلمة المرور يلي دخلهم الشخص بالتطبيق
  static Map<String, dynamic> _buildSshOutbound(ServerItem server, String username, String password) {
    final host = (server.config['server'] ?? '').toString();
    final port = int.tryParse((server.config['port'] ?? '22').toString()) ?? 22;

    return {
      'type': 'ssh',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'user': username,
      'password': password,
    };
  }
}
