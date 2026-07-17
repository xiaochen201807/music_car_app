import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/device_auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/luxury_loading_indicator.dart';

/// Full-screen hard gate: the app is unusable until activation succeeds.
class DeviceActivationGate extends StatefulWidget {
  const DeviceActivationGate({
    super.key,
    required this.authService,
    required this.onActivated,
  });

  final DeviceAuthService authService;
  final VoidCallback onActivated;

  @override
  State<DeviceActivationGate> createState() => _DeviceActivationGateState();
}

class _DeviceActivationGateState extends State<DeviceActivationGate> {
  final TextEditingController _codeController = TextEditingController();
  String _deviceId = '';
  String _message = '请输入管理员下发的激活码';
  bool _busy = false;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final String id = await widget.authService.getDeviceId();
    // Touch verify with empty code so worker records pending device.
    unawaited(widget.authService.verifyActivation(''));
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceId = id;
      _loadingId = false;
    });
  }

  Future<void> _submit() async {
    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _message = '请输入激活码';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = '正在校验…';
    });
    final DeviceAuthSnapshot result = await widget.authService.verifyActivation(
      code,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _message = result.message;
    });
    if (result.activated && !deviceAuthIsExpired(result)) {
      HapticFeedback.mediumImpact();
      widget.onActivated();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _copyDeviceId() async {
    if (_deviceId.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _deviceId));
    HapticFeedback.selectionClick();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设备码已复制，请发送给管理员授权')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.xl),
              children: <Widget>[
                const SizedBox(height: AppSpace.xl2),
                Text(
                  '设备激活',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '本应用采用一机一码授权。未激活前无法使用任何功能。\n支持月卡 / 季卡 / 年卡 / 终身。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.xl2),
                GlassCard(
                  radius: AppRadius.panel,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  shadows: const <BoxShadow>[],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '设备码',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      if (_loadingId)
                        const Center(child: LuxuryLoadingIndicator(size: 22))
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                            vertical: AppSpace.md,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: theme.brightness == Brightness.light
                                  ? 0.55
                                  : 0.28,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                            border: Border.all(
                              color: colors.outlineVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          child: SelectableText(
                            _deviceId,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpace.md),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.tonalIcon(
                          onPressed: _loadingId ? null : _copyDeviceId,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('复制设备码发给管理员'),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      Text(
                        '激活码',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      TextField(
                        controller: _codeController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                        decoration: InputDecoration(
                          hintText: 'AUTH-XXXX-XXXXXXXXXXXX',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.md,
                            vertical: AppSpace.md,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : Text(
                                  '激活并进入应用',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colors.onPrimary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
