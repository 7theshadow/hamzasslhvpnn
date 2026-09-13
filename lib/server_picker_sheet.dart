// lib/server_picker_sheet.dart
// Bottom Sheet لاختيار سيرفر: فئات -> سيرفرات -> (يوزر/باسورد أو UUID حسب النوع)
//
// طريقة الاستخدام من HomeScreen:
//
//   final result = await showModalBottomSheet<ServerSelectionResult>(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => ServerPickerSheet(token: myToken),
//   );
//   if (result != null) { ... استخدم result.server و result.uuid أو result.username/password }

import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'api_service.dart';

class ServerSelectionResult {
  final ServerItem server;
  final String? uuid;
  final String? username;
  final String? password;

  ServerSelectionResult({
    required this.server,
    this.uuid,
    this.username,
    this.password,
  });
}

class ServerPickerSheet extends StatefulWidget {
  const ServerPickerSheet({super.key});

  @override
  State<ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends State<ServerPickerSheet> {
  late Future<List<ServerCategory>> _future;
  ServerCategory? _selectedCategory; // null = نعرض قائمة الفئات
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = ApiService.fetchServers();
  }

  void _refresh() {
    setState(() {
      _future = ApiService.fetchServers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF172448), Color(0xFF101A35)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              if (_selectedCategory == null) _buildSearchAndRefresh(),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<ServerCategory>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.blueAccent),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذر تحميل السيرفرات\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    final categories = snapshot.data ?? [];
                    if (categories.isEmpty) {
                      return const Center(
                        child: Text('لا توجد سيرفرات متاحة حالياً',
                            style: TextStyle(color: AppColors.textMuted)),
                      );
                    }

                    if (_selectedCategory == null) {
                      return _buildCategoriesList(categories, scrollController);
                    } else {
                      return _buildServersList(_selectedCategory!, scrollController);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (_selectedCategory != null)
          IconButton(
            onPressed: () => setState(() => _selectedCategory = null),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
        Expanded(
          child: Text(
            _selectedCategory == null ? 'اختر سيرفر' : _selectedCategory!.name,
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildSearchAndRefresh() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'ابحث عن سيرفر...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildCategoriesList(List<ServerCategory> categories, ScrollController controller) {
    final filtered = _search.isEmpty
        ? categories
        : categories.where((c) => c.name.toLowerCase().contains(_search)).toList();

    return ListView.separated(
      controller: controller,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cat = filtered[index];
        return _OptionTile(
          title: cat.name,
          trailing: Text('${cat.servers.length}', style: AppTextStyles.pill),
          onTap: () => setState(() => _selectedCategory = cat),
        );
      },
    );
  }

  Widget _buildServersList(ServerCategory category, ScrollController controller) {
    final servers = _search.isEmpty
        ? category.servers
        : category.servers.where((s) => s.name.toLowerCase().contains(_search)).toList();

    if (servers.isEmpty) {
      return const Center(
        child: Text('لا توجد سيرفرات بهاي الفئة', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView.separated(
      controller: controller,
      itemCount: servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final server = servers[index];
        return _OptionTile(
          title: server.name,
          subtitle: server.description,
          iconUrl: server.iconUrl,
          onTap: () => _handleServerTap(server),
        );
      },
    );
  }

  Future<void> _handleServerTap(ServerItem server) async {
    final result = await showDialog<ServerSelectionResult>(
      context: context,
      builder: (_) => _CredentialsDialog(server: server),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result); // يرجع النتيجة النهائية لشاشة الهوم
    }
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? iconUrl;
  final Widget? trailing;
  final VoidCallback onTap;

  const _OptionTile({
    required this.title,
    this.subtitle,
    this.iconUrl,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: GlassCard(
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            if (iconUrl != null && iconUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(iconUrl!, width: 26, height: 26, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 26, height: 26)),
              )
            else
              const SizedBox(width: 26, height: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: AppTextStyles.label),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// نافذة إدخال بيانات الاتصال حسب نوع السيرفر
class _CredentialsDialog extends StatefulWidget {
  final ServerItem server;
  const _CredentialsDialog({required this.server});

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  final _uuidCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final needsUserPass = widget.server.needsUsernamePassword;

    return Dialog(
      backgroundColor: const Color(0xFF162242),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.server.name, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            if (!needsUserPass) ...[
              _buildField(controller: _uuidCtrl, label: 'UUID', hint: '00000000-0000-0000-0000-000000000000'),
            ] else ...[
              _buildField(controller: _userCtrl, label: 'اسم المستخدم', hint: 'username'),
              const SizedBox(height: 10),
              _buildField(
                controller: _passCtrl,
                label: 'كلمة المرور',
                hint: '••••••',
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.blueAccent),
                    onPressed: _confirm,
                    child: const Text('اتصال'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
      ],
    );
  }

  void _confirm() {
    final needsUserPass = widget.server.needsUsernamePassword;

    if (!needsUserPass && _uuidCtrl.text.trim().isEmpty) {
      _showError('عبي حقل UUID');
      return;
    }
    if (needsUserPass && (_userCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty)) {
      _showError('عبي اسم المستخدم وكلمة المرور');
      return;
    }

    Navigator.of(context).pop(
      ServerSelectionResult(
        server: widget.server,
        uuid: needsUserPass ? null : _uuidCtrl.text.trim(),
        username: needsUserPass ? _userCtrl.text.trim() : null,
        password: needsUserPass ? _passCtrl.text.trim() : null,
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
