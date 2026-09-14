import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_widget.dart';

Widget _toastShell(ToastData data) => Scaffold(
  body: Align(
    alignment: .topCenter,
    child: ToastWidget(data: data, onDismiss: () {}),
  ),
);

@CordatoPreview(
  group: 'Core / Toasts',
  name: 'Informação',
  size: Size(390.0, 180.0),
)
Widget previewInfoToastWidget() => _toastShell(
  const ToastData(
    id: 1,
    title: 'Tudo sob controle',
    description: 'Seus dados estão atualizados.',
  ),
);

@CordatoPreview(
  group: 'Core / Toasts',
  name: 'Sucesso',
  size: Size(390.0, 180.0),
)
Widget previewSuccessToastWidget() => _toastShell(
  const ToastData(
    id: 2,
    variant: .success,
    title: 'Gasto salvo',
    description: 'O novo gasto foi adicionado com sucesso.',
  ),
);

@CordatoPreview(group: 'Core / Toasts', name: 'Aviso', size: Size(390.0, 180.0))
Widget previewWarningToastWidget() => _toastShell(
  const ToastData(
    id: 3,
    variant: .warning,
    title: 'Orçamento próximo do limite',
    description: 'Você já utilizou 80% do valor planejado.',
  ),
);

@CordatoPreview(
  group: 'Core / Toasts',
  name: 'Erro com ação',
  size: Size(390.0, 180.0),
)
Widget previewErrorToastWidget() => _toastShell(
  ToastData(
    id: 4,
    variant: .error,
    title: 'Não foi possível salvar',
    description: 'Verifique sua conexão e tente novamente.',
    action: ToastAction(label: 'Tentar', onPressed: () {}),
  ),
);
