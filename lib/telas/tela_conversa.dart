import 'package:flutter/material.dart';

import '../componentes/balao_mensagem.dart';
import '../modelos/mensagem.dart';
import '../servicos/servico_gemini.dart';

/// Tela principal para conversar com o Assistente Inteligente.
class TelaConversa extends StatefulWidget {
  const TelaConversa({super.key});

  @override
  State<TelaConversa> createState() => _EstadoTelaConversa();
}

class _EstadoTelaConversa extends State<TelaConversa> {
  final ServicoGemini _servicoGemini = ServicoGemini();
  final TextEditingController _controladorMensagem = TextEditingController();
  final ScrollController _controladorRolagem = ScrollController();

  final List<Mensagem> listaMensagens = [
    const Mensagem(
      conteudo: 'Olá! Como posso ajudar você hoje?',
      ehUsuario: false,
    ),
  ];
  bool carregandoResposta = false;

  @override
  void dispose() {
    _controladorMensagem.dispose();
    _controladorRolagem.dispose();
    _servicoGemini.fechar();
    super.dispose();
  }

  /// Envia a pergunta e acrescenta a resposta do Gemini à conversa.
  Future<void> enviarMensagem() async {
    final mensagemUsuario = _controladorMensagem.text.trim();
    if (mensagemUsuario.isEmpty || carregandoResposta) return;

    _controladorMensagem.clear();
    setState(() {
      listaMensagens.add(Mensagem(conteudo: mensagemUsuario, ehUsuario: true));
      carregandoResposta = true;
    });
    _rolarAteOFim();

    try {
      final respostaInteligenciaArtificial = await _servicoGemini.obterResposta(
        mensagens: List<Mensagem>.unmodifiable(listaMensagens),
      );
      if (!mounted) return;
      setState(() {
        listaMensagens.add(
          Mensagem(conteudo: respostaInteligenciaArtificial, ehUsuario: false),
        );
      });
    } catch (_) {
      if (!mounted) return;
      final mensagemDeErro = ServicoGemini.chaveApi.trim().isEmpty
          ? 'Configure a chave da API Gemini para começar a conversar.'
          : 'Não foi possível obter uma resposta.\n'
                'Verifique sua chave da API Gemini e sua conexão com a internet.';
      setState(() {
        listaMensagens.add(
          Mensagem(conteudo: mensagemDeErro, ehUsuario: false, ehAviso: true),
        );
      });
    } finally {
      if (mounted) {
        setState(() => carregandoResposta = false);
        _rolarAteOFim();
      }
    }
  }

  /// Apaga o histórico e mostra novamente a saudação inicial.
  void limparConversa() {
    setState(() {
      listaMensagens
        ..clear()
        ..add(
          const Mensagem(
            conteudo: 'Olá! Como posso ajudar você hoje?',
            ehUsuario: false,
          ),
        );
    });
    _rolarAteOFim();
  }

  void _rolarAteOFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controladorRolagem.hasClients) return;
      _controladorRolagem.animateTo(
        _controladorRolagem.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: cores.primaryContainer,
              child: Icon(Icons.auto_awesome, color: cores.primary),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistente Inteligente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Conectado ao Gemini',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Limpar conversa',
            onPressed: carregandoResposta ? null : limparConversa,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _controladorRolagem,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                itemCount: listaMensagens.length + (carregandoResposta ? 1 : 0),
                itemBuilder: (context, indice) {
                  if (indice == listaMensagens.length) {
                    return const BalaoMensagem(
                      mensagem: Mensagem(
                        conteudo: 'Aguarde, estou pensando...',
                        ehUsuario: false,
                      ),
                    );
                  }
                  return BalaoMensagem(mensagem: listaMensagens[indice]);
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controladorMensagem,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => enviarMensagem(),
                      decoration: InputDecoration(
                        hintText: 'Digite sua pergunta...',
                        filled: true,
                        fillColor: const Color(0xFFF2F3F8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton.filled(
                    tooltip: 'Enviar mensagem',
                    onPressed: carregandoResposta ? null : enviarMensagem,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: cores.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
