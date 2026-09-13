// lib/home_screen.dart
// الشاشة الرئيسية: خلفية غرادينت غامقة + زر اتصال دائري + زر اختيار سيرفر Pill
// بعد اختيار السيرفر من ServerPickerSheet، هون بس عليك تربط زر "اتصال" فعلياً
// بمكتبة V2Ray/SSH الحقيقية (الخطوة يلي لسا ناقصة بالمشروع).

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'singbox_config_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'models.dart';
import 'server_picker_sheet.dart';
import 'api_service.dart';

enum ConnectionState { disconnected, connecting, connected }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ServerSelectionResult? _selection;
  ConnectionState _state = ConnectionState.disconnected;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  UserAccountInfo? _accountInfo;

  final SingboxClient _client = SingboxClient();
  bool _clientReady = false;
  StreamSubscription? _stateSub;
  StreamSubscription? _faultSub;

  @override
  void initState() {
    super.initState();
    _client.initialize().then((_) {
      if (mounted) setState(() => _clientReady = true);
    });

    _stateSub = _client.serviceStateStream.listen((state) {
      if (!mounted) return;
      final s = state.toString().toUpperCase();
      if (s.contains('CONNECTED') && !s.contains('DIS')) {
        if (_state != ConnectionState.connected) {
          setState(() => _state = ConnectionState.connected);
          _startTimer();
          _loadAccountInfo();
        }
      } else if (s.contains('STOP') || s.contains('DISCONNECT') || s.contains('IDLE')) {
        _stopTimer();
        setState(() {
          _state = ConnectionState.disconnected;
          _accountInfo = null;
        });
      }
    });

    _faultSub = _client.faultStream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ بالاتصال: $error')),
      );
      _stopTimer();
      setState(() => _state = ConnectionState.disconnected);
    });
  }

  /// يجيب معرف جهاز ثابت (يتولد مرة وحدة ويتحفظ محلياً)
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id == null) {
      final rand = Random();
      id = List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  Future<void> _loadAccountInfo() async {
    if (_selection == null) return;
    final server = _selection!.server;
    final checkUrl = server.checkUserUrl;
    final uuid = _selection!.uuid;

    if (checkUrl == null || checkUrl.isEmpty || uuid == null || uuid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لا يوجد check_user_url أو UUID (checkUrl=$checkUrl, uuid=$uuid)')),
        );
      }
      return;
    }

    try {
      final deviceId = await _getDeviceId();
      final info = await ApiService.checkUser(checkUserUrl: checkUrl, uuid: uuid, deviceId: deviceId);
      if (mounted) {
        if (info == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('checkUser رجع null - راجع الـ UUID أو رد السيرفر')),
          );
        }
        setState(() => _accountInfo = info);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ بجلب بيانات الحساب: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _elapsed = Duration.zero;
  }

  String _formatElapsed() {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateSub?.cancel();
    _faultSub?.cancel();
    super.dispose();
  }

  Future<void> _openServerPicker() async {
    final result = await showModalBottomSheet<ServerSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ServerPickerSheet(),
    );

    if (result != null) {
      setState(() => _selection = result);
    }
  }

  Future<void> _onConnectPressed() async {
    if (_selection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر سيرفر أول')),
      );
      return;
    }

    if (!_clientReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مكتبة الاتصال لسا عم تتجهز، جرب بعد ثانية')),
      );
      return;
    }

    final server = _selection!.server;

    final String configJson;
    try {
      configJson = SingboxConfigBuilder.build(
        server: server,
        uuid: _selection!.uuid,
        username: _selection!.username,
        password: _selection!.password,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('إعدادات هالسيرفر غير صالحة: $e')),
      );
      return;
    }

    try {
      await _client.checkConfig(configJson);

      setState(() => _state = ConnectionState.connecting);

      final granted = await _client.requestVPNPermission();
      if (!granted) {
        setState(() => _state = ConnectionState.disconnected);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لازم توافق على صلاحية VPN مشان تتصل')),
          );
        }
        return;
      }

      await _client.connect(SessionOptions(
        config: configJson,
        networkMode: NetworkMode.vpn,
        notification: const NotificationConfig(
          title: 'MyTunnel',
          showTrafficStats: true,
          showStopButton: true,
          stopButtonLabel: 'قطع الاتصال',
        ),
      ));
      // ملاحظة: تحديث الحالة لـ "متصل" بيصير تلقائياً من serviceStateStream فوق.
    } catch (e) {
      setState(() => _state = ConnectionState.disconnected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الاتصال: $e')),
        );
      }
    }
  }

  Future<void> _onDisconnectPressed() async {
    await _client.disconnect();
    _stopTimer();
    setState(() {
      _state = ConnectionState.disconnected;
      _accountInfo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildTopBar(),
                if (_accountInfo != null) ...[
                  const SizedBox(height: 14),
                  _buildAccountInfoCard(),
                ],
                const Spacer(),
                _buildActiveTime(),
                const SizedBox(height: 10),
                _buildServerPickerPill(),
                const SizedBox(height: 26),
                _buildConnectButton(),
                const SizedBox(height: 14),
                _buildStatusText(),
                const Spacer(),
                if (_state == ConnectionState.connected) _buildTrafficPanel(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    final info = _accountInfo!;
    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.purple.withOpacity(0.3),
            child: Text(
              info.username.isNotEmpty ? info.username[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.username, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('الأيام المتبقية: ${info.expirationDays}', style: AppTextStyles.label),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ينتهي: ${info.expirationDate}', style: AppTextStyles.label),
              Text('الأجهزة: ${info.countConnections}/${info.limitConnections}', style: AppTextStyles.label),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _circleIconButton(Icons.menu, () {}),
        Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEghoKrVBbi9v7F-G8_Mm9V3oTX-53_4-OrNbsZZGW59OeHvWAD9NBiRs4bdqdQcjvmaEMnfHE6mk9Ly3VaP2vX6xbr45Sl6iWQ4N0EOlc9AGx7Zlbitov6S7j370ljFIKeokY0ZXp7iRXkp8wo1VeYjACzuiTy_1x7n_WHXa8a6f86b3ORIU3ytfQd0mCLL/s320/20260401_171515.png',
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Text('MyTunnel', style: AppTextStyles.title),
              ),
            ),
          ],
        ),
        _circleIconButton(Icons.person_outline, () {}),
      ],
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }

  Widget _buildActiveTime() {
    return Column(
      children: [
        Text(
          _state == ConnectionState.connected ? 'الوقت النشط' : 'غير متصل - اضغط للاتصال',
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 4),
        Text(
          _state == ConnectionState.connected ? _formatElapsed() : '--:--:--',
          style: AppTextStyles.value,
        ),
      ],
    );
  }

  Widget _buildServerPickerPill() {
    final label = _selection?.server.name ?? 'اختر سيرفر';
    return InkWell(
      onTap: _openServerPicker,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, color: AppColors.textPrimary, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.pill,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    final isConnected = _state == ConnectionState.connected;
    final isConnecting = _state == ConnectionState.connecting;

    return GestureDetector(
      onTap: (isConnected || isConnecting)
          ? _onDisconnectPressed
          : _onConnectPressed,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.connectButtonGradient,
          border: Border.all(
            color: isConnected ? AppColors.green : AppColors.purple.withOpacity(0.6),
            width: 2,
          ),
          boxShadow: isConnected
              ? [BoxShadow(color: AppColors.purple.withOpacity(0.3), blurRadius: 30, spreadRadius: 4)]
              : [],
        ),
        child: Center(
          child: isConnecting
              ? const CircularProgressIndicator(color: Colors.white)
              : Icon(
                  isConnected ? Icons.power_settings_new : Icons.power_settings_new,
                  color: Colors.white,
                  size: 64,
                ),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    switch (_state) {
      case ConnectionState.connected:
        text = 'متصل';
        break;
      case ConnectionState.connecting:
        text = 'جارٍ الاتصال...';
        break;
      default:
        text = 'غير متصل';
    }
    return Text(text, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600));
  }

  Widget _buildTrafficPanel() {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _TrafficStat(label: 'تنزيل', value: '0 MB', icon: Icons.arrow_downward),
          _TrafficStat(label: 'رفع', value: '0 MB', icon: Icons.arrow_upward),
          _TrafficStat(label: 'Ping', value: '-- ms', icon: Icons.speed),
        ],
      ),
    );
  }
}

class _TrafficStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TrafficStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.cyan, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        Text(label, style: AppTextStyles.label),
      ],
    );
  }
}
