import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/widgets/pin_field_widget.dart';
import 'package:cordato/features/authentication/presentation/validators/code_validation.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/widgets/app_bar_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/header_confirmation_code_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/resend_cooldown_label_widget.dart';

final class ConfirmationCodeScreen extends StatefulWidget {
  final MagicLinkCommand command;
  final CodeValidation validation;

  const ConfirmationCodeScreen({
    super.key,
    required this.command,
    required this.validation,
  });

  @override
  State<ConfirmationCodeScreen> createState() => _ConfirmationCodeScreenState();
}

final class _ConfirmationCodeScreenState extends State<ConfirmationCodeScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  Timer? _timer;
  bool _isResending = false;
  Duration _resendRemaining = .zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.command.resend.results.addListener(_handleResend);
    _resendCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.command.resend.results.removeListener(_handleResend);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    state == .resumed ? _resendCooldown() : _timer?.cancel();
  }

  void _validate() => _formKey.currentState?.validate();

  void _resend() {
    if (_isResending) return;

    final remaining = widget.command.resendRemaining;
    if (remaining > .zero) {
      _resendCooldown();
      return;
    }

    final email = widget.command.email;
    if (email == null) {
      context.showToast(
        variant: .error,
        title: 'E-mail não informado',
        description: 'Informe seu e-mail para solicitar um novo código.',
      );
      return;
    }

    setState(() => _isResending = true);
    widget.command.resend.run(email);
  }

  void _handleResend() {
    final command = widget.command.resend.results.value;
    if (!mounted || !_isResending || command.isRunning) return;

    if (command.hasError) {
      setState(() => _isResending = false);
      context.showToast(
        variant: .error,
        title: 'Erro ao reenviar e-mail',
        description: 'Não foi possível enviar um novo código. Tente novamente.',
      );
      return;
    }

    if (command.isSuccess) {
      widget.command.startCooldown();
      setState(() => _isResending = false);
      _resendCooldown();
      context.showToast(
        variant: .success,
        title: 'Código reenviado',
        description: 'Enviamos um novo código para o seu e-mail.',
      );
    }
  }

  void _resendCooldown() {
    _timer?.cancel();
    _updateResendCooldown();

    if (_resendRemaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateResendCooldown();
      });
    }
  }

  void _updateResendCooldown() {
    final remaining = widget.command.resendRemaining;
    if (!mounted) return;

    setState(() => _resendRemaining = remaining);
    if (remaining == .zero) _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarMagicLinkWidget(),
      body: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: Column(
            spacing: 16.0,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: .symmetric(vertical: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        spacing: 24.0,
                        crossAxisAlignment: .stretch,
                        children: [
                          HeaderConfirmationCodeWidget(),
                          PinFieldWidget(
                            controller: _controller,
                            validation: widget.validation,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                spacing: 4.0,
                crossAxisAlignment: .stretch,
                children: [
                  ResendCooldownLabelWidget(remaining: _resendRemaining),
                  OutlineButtonWidget(
                    label: 'Reenviar',
                    isLoading: _isResending,
                    onTap: _isResending || _resendRemaining > .zero
                        ? null
                        : _resend,
                  ),
                  const SizedBox(height: 12.0),
                  ElevatedButtonWidget(label: 'Confirmar', onTap: _validate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
