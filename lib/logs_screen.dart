// lib/logs_screen.dart
// شاشة سجلات حية (Live Logs) — تعرض سجلات نواة sing-box لحظة بلحظة
// عشان نقدر نشخص أخطاء الاتصال الحقيقية (TLS، WS، DNS...) بدل التخمين.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'theme.dart';

class LogsScreen extends StatefulWidget {
  final SingboxClient client;

  const LogsScreen({super.key, required this.client});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<String> _lines = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    _logSub = widget.client.coreLogStream.listen((entries) {
      if (!mounted) return;
      setState(() {
        for (final e in entries) {
          // نستخدم toString() لتفادي الاعتماد على أسماء حقول داخلية قد
          // تختلف بين نسخ المكتبة (level/message/timestamp...).
          _lines.add(e.toString());
        }
        // نحد عدد الأسطر المحفوظة حتى ما تصير الذاكرة مشكلة بجلسة طويلة
        if (_lines.length > 500) {
          _lines.removeRange(0, _lines.length - 500);
        }
      });
      _scrollToBottom();
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _lines.add('[logs stream error] $e'));
    });
  }

  void _scrollToBottom() {
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
    _logSub?.cancel();
    _scrollController.dispose();
    super.dispose();
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
            tooltip: 'نسخ الكل',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _lines.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _lines.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ السجلات')),
                    );
                  },
          ),
          IconButton(
            tooltip: 'مسح',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _lines.clear()),
          ),
        ],
      ),
      body: SafeArea(
        child: _lines.isEmpty
            ? const Center(
                child: Text(
                  'لا يوجد سجلات بعد.\nجرب تضغط اتصال وشوف شو رح يظهر هون.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _lines.length,
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final isError = line.toLowerCase().contains('error') ||
                      line.toLowerCase().contains('fail') ||
                      line.toLowerCase().contains('fatal');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.glass,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isError ? Colors.redAccent.withOpacity(0.5) : AppColors.glassBorder,
                      ),
                    ),
                    child: SelectableText(
                      line,
                      style: TextStyle(
                        color: isError ? Colors.redAccent.shade100 : AppColors.textPrimary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
