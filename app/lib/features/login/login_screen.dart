import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/frigate/server_config.dart';
import '../../core/session/session_controller.dart';
import '../../l10n/app_localizations.dart';
import 'certificate_dialog.dart';
import 'session_error_text.dart';

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
    // A first server gets a name in the user's language, set once the
    // translations are known (didChangeDependencies).
    _nameController = TextEditingController(text: existing?.name);
    _localUrlController = TextEditingController(text: existing?.localUrl);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.controller.config == null && _nameController.text.isEmpty) {
      _nameController.text = AppLocalizations.of(context).serverNameDefault;
    }
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

  /// Logs in; [trusted] is the certificate fingerprint just confirmed.
  Future<void> _submit({String? trusted}) async {
    if (!_formKey.currentState!.validate()) return;

    final localUrl = ServerConfig.normalizeUrl(_localUrlController.text.trim());
    final existing = widget.controller.config;
    final config = ServerConfig(
      name: _nameController.text.trim(),
      localUrl: localUrl,
      remoteUrl: _remoteUrlController.text.trim().isNotEmpty
          ? ServerConfig.normalizeUrl(_remoteUrlController.text.trim())
          : null,
      username: _userController.text.trim(),
      allowSelfSignedCert: _allowSelfSigned,
      // A confirmed certificate belongs to its address only.
      certFingerprint:
          trusted ??
          (existing?.localUrl == localUrl ? existing?.certFingerprint : null),
    );

    final success = await widget.controller.login(
      config: config,
      password: _passController.text,
    );

    if (!mounted) return;
    final certificate = widget.controller.pendingCertificate;
    if (!success && certificate != null && trusted == null) {
      final trust = await showCertificateDialog(context, certificate);
      if (trust && mounted) await _submit(trusted: certificate.fingerprint);
    }
    // Any other failure is shown above the button (_error).
  }

  /// Why the last attempt, the start or the session failed; after a
  /// failed start, the saved session can be tried again as is.
  Widget _error(AppLocalizations l, TextTheme text) {
    final controller = widget.controller;
    final error = controller.error;
    if (error == null || controller.isLoading) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          spacing: 8,
          children: [
            Icon(Icons.error_outline_rounded, color: color, size: 20),
            Expanded(
              child: Text(sessionErrorText(l, error), style: text.bodyMedium),
            ),
            // Trying again cannot confirm a certificate: logging in does.
            if (controller.status == SessionStatus.connectionError &&
                error != SessionError.certificateToConfirm)
              TextButton(
                onPressed: controller.retry,
                child: Text(l.sessionRetry),
              ),
          ],
        ),
      ),
    );
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
                      validator: (v) => addressError(l, v, required: true),
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
                      validator: (v) => addressError(l, v, required: false),
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
                        final button = FilledButton(
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_error(l, text), button],
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
