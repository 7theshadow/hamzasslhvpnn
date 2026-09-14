// lib/logs_screen.dart
// شاشة "السجلات" — ملخص مرتب ومفهوم لحالة الاتصال (متل تطبيقات VPN
// الاحترافية)، مش سطور تقنية خام من نواة sing-box.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'theme.dart';
import 'models.dart';

enum _LineKind { header, info, success, error, muted }

class _FriendlyLine {
  final String text;
  final _LineKind kind;
  _FriendlyLine(this.text, this.kind);
}

class LogsScreen extends StatefulWidget {
  final SingboxClient client;
  final ServerItem? server;
  final String? configJson;

  const LogsScreen({super.key, required this.client, this.server, this.configJson});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<_FriendlyLine> _lines = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _stateSub;
  StreamSubscription? _faultSub;
  bool _lastConnectedLike = false;

  @override
  void initState() {
    super.initState();
    _buildConfigSummary();

    _stateSub = widget.client.serviceStateStream.listen((state) {
      if (!mounted) return;
      final s = state.toString().toUpperCase();

      final isDisconnectedLike = s.contains('STOP') ||
          s.contains('IDLE') ||
          s.contains('DISCONNECT') ||
          s.contains('ERROR') ||
          s.contains('FAIL');
      final isTransitioning =
          (s.contains('START') && !s.contains('STARTED')) || s.contains('CONNECTING');

      if (isDisconnectedLike) {
        if (_lastConnectedLike) {
          _addLine('تم قطع الاتصال', _LineKind.muted);
        }
        _lastConnectedLike = false;
      } else if (isTransitioning) {
        _addLine('جاري الاتصال بـ VPN...', _LineKind.info);
      } else {
        if (!_lastConnectedLike) {
          _addLine('فتح واجهة الشبكة (tun0)', _LineKind.info);
          _addLine('IPv4 محلي: 172.19.0.1/30', _LineKind.info);
          _addLine('تم الاتصال بنجاح ✅', _LineKind.success);
        }
        _lastConnectedLike = true;
      }
    });

    _faultSub = widget.client.faultStream.listen((error) {
      if (!mounted) return;
      _addLine('خطأ: $error', _LineKind.error);
    });
  }

  void _buildConfigSummary() {
    final server = widget.server;
    if (server == null) {
      _lines.add(_FriendlyLine('لسا ما اخترت سيرفر.', _LineKind.muted));
      return;
    }
    final modeLabel = server.mode == ConnectionMode.v2ray
        ? 'V2RAY/XRAY - VLESS'
        : (server.mode == ConnectionMode.ssh ? 'SSH' : 'SSL Direct');

    _lines.add(_FriendlyLine('Config:', _LineKind.header));
    _lines.add(_FriendlyLine('ID: ${server.id}', _LineKind.muted));
    _lines.add(_FriendlyLine('الاسم: ${server.name}', _LineKind.muted));
    if (server.description.isNotEmpty) {
      _lines.add(_FriendlyLine('الوصف: ${server.description}', _LineKind.muted));
    }
    _lines.add(_FriendlyLine('الوضع: $modeLabel', _LineKind.muted));

    // نقرا معلومات حقيقية من الكونفيغ الفعلي المبني (JSON) بدل افتراضات.
    final raw = widget.configJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final dns = decoded['dns'] as Map<String, dynamic>?;
        final servers = (dns?['servers'] as List?) ?? [];
        if (servers.isNotEmpty) {
          final dnsTypes = servers.map((s) => (s as Map)['type'] ?? '').join(', ');
          _lines.add(_FriendlyLine('DNS: $dnsTypes', _LineKind.muted));
        }
        final outbounds = (decoded['outbounds'] as List?) ?? [];
        final proxyOutbound = outbounds.cast<Map?>().firstWhere(
              (o) => o?['tag'] == 'proxy',
              orElse: () => null,
            );
        if (proxyOutbound != null) {
          final tls = proxyOutbound['tls'] as Map<String, dynamic>?;
          if (tls != null && tls['enabled'] == true) {
            _lines.add(_FriendlyLine('TLS: مفعّل (SNI: ${tls['server_name'] ?? '-'})', _LineKind.muted));
          }
          _lines.add(_FriendlyLine('السيرفر: ${proxyOutbound['server']}:${proxyOutbound['server_port']}', _LineKind.muted));
        }
      } catch (_) {
        // إذا فشل تحليل الكونفيغ لأي سبب، منتجاهل التفاصيل الإضافية بهدوء.
      }
    }
  }

  void _addLine(String text, _LineKind kind) {
    setState(() => _lines.add(_FriendlyLine(text, kind)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _faultSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Color _colorFor(_LineKind kind) {
    switch (kind) {
      case _LineKind.success:
        return AppColors.green;
      case _LineKind.error:
        return AppColors.red;
      case _LineKind.header:
        return AppColors.textPrimary;
      case _LineKind.muted:
        return AppColors.textMuted;
      case _LineKind.info:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('السجلات', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'مسح',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() {
              _lines.clear();
              _buildConfigSummary();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _lines.length,
          itemBuilder: (context, index) {
            final line = _lines[index];
            final isHeader = line.kind == _LineKind.header;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                line.text,
                style: TextStyle(
                  color: _colorFor(line.kind),
                  fontSize: isHeader ? 15 : 14,
                  fontWeight: isHeader || line.kind == _LineKind.success
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
