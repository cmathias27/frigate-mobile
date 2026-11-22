import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/frigate/server_config.dart';
import '../../core/session/session_controller.dart';
import '../../l10n/app_localizations.dart';

/// Screen 1 of mock-ups: connect to a Frigate server.
class LoginScreen extends StatefulWidget {
  final SessionController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _localUrlController;
  late final TextEditingController _remoteUrlController;
  late final TextEditingController _userController;
  late final TextEditingController _passController;

  bool _allowSelfSigned = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final existing = widget.controller.config;
    _nameController = TextEditingController(
      text: existing?.name ?? 'Maison',
    );
    _localUrlController = TextEditingController(
      text: existing?.localUrl ?? 'https://192.168.1.10:8971',
    );
    _remoteUrlController = TextEditingController(
      text: existing?.remoteUrl ?? '',
    );
    _userController = TextEditingController(
      text: existing?.username ?? '',
    );
    _passController = TextEditingController();
    _allowSelfSigned = existing?.allowSelfSignedCert ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localUrlController.dispose();
    _remoteUrlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final config = ServerConfig(
      name: _nameController.text.trim(),
      localUrl: ServerConfig.normalizeUrl(_localUrlController.text.trim()),
      remoteUrl: _remoteUrlController.text.trim().isNotEmpty
          ? ServerConfig.normalizeUrl(_remoteUrlController.text.trim())
          : null,
      username: _userController.text.trim(),
      allowSelfSignedCert: _allowSelfSigned,
    );

    final success = await widget.controller.login(
      config: config,
      password: _passController.text,
    );

    if (!mounted) return;
    if (!success && widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'F',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06121F),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.loginTitle,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.loginSubtitle,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textDim,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Server name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l.serverNameLabel,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? l.requiredField
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Local URL (port 8971)
                    TextFormField(
                      controller: _localUrlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: l.localUrlLabel,
                        hintText: l.localUrlHint,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l.requiredField;
                        }
                        final uri = Uri.tryParse(ServerConfig.normalizeUrl(v));
                        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                          return l.invalidUrl;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Remote URL (optional)
                    TextFormField(
                      controller: _remoteUrlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: l.remoteUrlLabel,
                        hintText: l.remoteUrlHint,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Username & Password
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _userController,
                            decoration: InputDecoration(
                              labelText: l.usernameLabel,
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? l.requiredField
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _passController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: l.passwordLabel,
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: AppColors.textDim,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? l.requiredField : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Self-signed switch
                    SwitchListTile(
                      value: _allowSelfSigned,
                      onChanged: (v) => setState(() => _allowSelfSigned = v),
                      title: Text(
                        l.selfSignedLabel,
                        style: text.bodySmall,
                      ),
                      tileColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      dense: true,
                    ),
                    const SizedBox(height: 24),

                    // Connect button
                    ListenableBuilder(
                      listenable: widget.controller,
                      builder: (context, _) {
                        final loading = widget.controller.isLoading;
                        return FilledButton(
                          onPressed: loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: const Color(0xFF06121F),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF06121F),
                                  ),
                                )
                              : Text(
                                  l.connectButton,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
