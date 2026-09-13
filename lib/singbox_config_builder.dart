// lib/singbox_config_builder.dart
// يبني إعدادات (Config JSON) بصيغة Sing-box انطلاقاً من بيانات السيرفر
// المخزّنة بلوحة التحكم (سواء V2Ray/VLESS أو SSH).

import 'dart:convert';
import 'models.dart';

class SingboxConfigBuilder {
  /// يبني JSON كامل جاهز لتمريره لـ client.connect(SessionOptions(config: ...))
  static String build({
    required ServerItem server,
    String? uuid,
    String? username,
    String? password,
  }) {
    final Map<String, dynamic> outbound = server.mode == ConnectionMode.v2ray
        ? _buildVlessOutbound(server, uuid ?? '')
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
      },
      'inbounds': [
        {
          'type': 'tun',
          'interface_name': 'tun0',
          'address': ['172.19.0.1/30'],
          'auto_route': true,
          'strict_route': true,
          'stack': 'system',
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
        ],
        'auto_detect_interface': true,
        'final': 'proxy',
      },
    };

    return jsonEncode(config);
  }

  /// يبني outbound من رابط vless://uuid@host:port?params (uuid ممكن يكون فاضي بالرابط
  /// ونعوضه من قيمة uuid يلي دخلها المستخدم بالتطبيق)
  static Map<String, dynamic> _buildVlessOutbound(ServerItem server, String enteredUuid) {
    final raw = (server.config['v2ray_config'] ?? '').toString().trim();
    final uri = Uri.parse(raw);

    final realUuid = uri.userInfo.isNotEmpty ? uri.userInfo : enteredUuid;
    final qp = uri.queryParameters;

    final security = qp['security'] ?? 'none';
    final type = qp['type'] ?? 'tcp';
    final sni = qp['sni'] ?? uri.host;
    final path = qp['path'] ?? '/';
    final insecure = (qp['insecure'] == '1' || qp['allowInsecure'] == '1');
    final fp = qp['fp'] ?? 'chrome';

    final Map<String, dynamic> outbound = {
      'type': 'vless',
      'tag': 'proxy',
      'server': uri.host,
      'server_port': uri.hasPort ? uri.port : 443,
      'uuid': realUuid,
      'packet_encoding': 'xudp',
    };

    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': path,
        'headers': {'Host': sni},
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
