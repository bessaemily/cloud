import 'package:flutter/material.dart';

import '../modelos/mensagem.dart';

/// Exibe uma mensagem alinhada conforme quem a enviou.
class BalaoMensagem extends StatelessWidget {
  const BalaoMensagem({super.key, required this.mensagem});

  final Mensagem mensagem;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final corDoBalao = mensagem.ehUsuario ? cores.primary : Colors.white;
    final corDoTexto = mensagem.ehUsuario
        ? Colors.white
        : const Color(0xFF202337);

    return Align(
      alignment: mensagem.ehUsuario
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mensagem.ehUsuario) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: cores.primaryContainer,
                child: Icon(Icons.auto_awesome, size: 17, color: cores.primary),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 310),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: corDoBalao,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mensagem.ehUsuario ? 18 : 5),
                    bottomRight: Radius.circular(mensagem.ehUsuario ? 5 : 18),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D202337),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  mensagem.conteudo,
                  style: TextStyle(color: corDoTexto, height: 1.4),
                ),
              ),
            ),
            if (mensagem.ehUsuario) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}
