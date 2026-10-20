import 'package:flutter/material.dart';

import 'telas/tela_conversa.dart';

void main() {
  runApp(const AplicativoAssistenteInteligente());
}

class AplicativoAssistenteInteligente extends StatelessWidget {
  const AplicativoAssistenteInteligente({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistente Inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4965D8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        useMaterial3: true,
      ),
      home: const TelaConversa(),
    );
  }
}
