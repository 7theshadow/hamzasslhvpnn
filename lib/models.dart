// lib/models.dart
// موديلات تطابق شكل الرد من api/get_settings.php

class ServerCategory {
  final int id;
  final String name;
  final String color;
  final List<ServerItem> servers;

  ServerCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.servers,
  });

  factory ServerCategory.fromJson(Map<String, dynamic> json) {
    return ServerCategory(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      color: json['color'] ?? '#11182600',
      servers: (json['servers'] as List<dynamic>? ?? [])
          .map((e) => ServerItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum ConnectionMode { v2ray, sslDirect, ssh }

ConnectionMode connectionModeFromString(String value) {
  switch (value) {
    case 'v2ray':
      return ConnectionMode.v2ray;
    case 'ssh':
      return ConnectionMode.ssh;
    case 'ssl_direct':
    default:
      return ConnectionMode.sslDirect;
  }
}

class ServerItem {
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final ConnectionMode mode;
  final String? iconUrl;
  final String? checkUserUrl;
  final Map<String, dynamic> config;

  ServerItem({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.mode,
    required this.iconUrl,
    required this.checkUserUrl,
    required this.config,
  });

  factory ServerItem.fromJson(Map<String, dynamic> json) {
    return ServerItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.parse(json['category_id'].toString()),
      mode: connectionModeFromString(json['connection_mode'] ?? 'v2ray'),
      iconUrl: json['icon_url'],
      checkUserUrl: json['check_user_url'],
      config: Map<String, dynamic>.from(json['config'] ?? {}),
    );
  }

  /// هل هالسيرفر بحاجة يوزر/باسورد بدل UUID؟
  bool get needsUsernamePassword => mode != ConnectionMode.v2ray;
}

/// بيانات الحساب المرجعة من check_user_url (بناءً على UUID)
class UserAccountInfo {
  final String username;
  final int expirationDays;
  final String expirationDate;
  final int limitConnections;
  final int countConnections;

  UserAccountInfo({
    required this.username,
    required this.expirationDays,
    required this.expirationDate,
    required this.limitConnections,
    required this.countConnections,
  });

  factory UserAccountInfo.fromJson(Map<String, dynamic> json) {
    return UserAccountInfo(
      username: json['username']?.toString() ?? '',
      expirationDays: int.tryParse(json['expiration_days'].toString()) ?? 0,
      expirationDate: json['expiration_date']?.toString() ?? '--',
      limitConnections: int.tryParse(json['limit_connections'].toString()) ?? 0,
      countConnections: int.tryParse(json['count_connections'].toString()) ?? 0,
    );
  }
}
