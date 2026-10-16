import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../shared/done_view.dart';

/// "Denunciar ponto": anyone can flag a problem, without accusing.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.placeId});

  final String placeId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _reason;
  String _text = '';
  bool _tried = false;
  bool _sent = false;

  bool get _other => _reason == reportReasons.last;
  bool get _textOk => !_other || _text.trim().isNotEmpty;

  void _send() {
    if (!_textOk) {
      setState(() => _tried = true);
      return;
    }
    store.report(widget.placeId, _reason!, _text);
    HapticFeedback.mediumImpact();
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return DoneView(
        icon: PhosphorIconsRegular.flag,
        title: 'Denúncia recebida.',
        text: 'Nossa equipe vai analisar este ponto. Se houver um problema, ele sai do mapa até ser resolvido.',
        primary: 'Voltar ao ponto',
        onPrimary: () => Navigator.pop(context),
      );
    }
    return FlowScaffold(
      title: 'O que está acontecendo com este ponto?',
      primary: 'Enviar denúncia',
      primaryIcon: null,
      onPrimary: _reason == null ? null : _send,
      secondary: 'Cancelar',
      onSecondary: () => Navigator.pop(context),
      children: [
        for (final r in reportReasons) ...[
          OptionTile(
            title: r,
            selected: _reason == r,
            onTap: () => setState(() {
              _reason = r;
              _tried = false;
            }),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        AppTextField(
          label: 'Conte o que aconteceu',
          hint: 'Opcional, mas ajuda nossa análise',
          maxLines: 4,
          minLines: 3,
          capitalization: TextCapitalization.sentences,
          error: _tried && !_textOk ? 'Conte em poucas palavras o que aconteceu.' : null,
          onChanged: (v) => setState(() => _text = v),
        ),
      ],
    );
  }
}
