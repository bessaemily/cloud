import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// MODELO – Turno
// ─────────────────────────────────────────────

/// Representa o retorno de um turno da IA.
class Turno {
  const Turno({
    required this.narrativa,
    required this.opcoes,
    required this.vida,
    required this.inventario,
    required this.fim,
  });

  final String narrativa;
  final List<String> opcoes;
  final int vida;
  final List<String> inventario;
  final bool fim;

  /// Converte o JSON retornado pela IA em um objeto [Turno].
  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      narrativa: json['narrativa'] as String? ?? '',
      opcoes: (json['opcoes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      vida: (json['vida'] as num?)?.toInt() ?? 100,
      inventario: (json['inventario'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fim: json['fim'] as bool? ?? false,
    );
  }
}

// ─────────────────────────────────────────────
// SERVIÇO DE IA – IaService
// ─────────────────────────────────────────────

/// Serviço que gerencia o prompt de sistema, o histórico de mensagens
/// e a chamada HTTP à API do Gemini.
class IaService {
  IaService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  /// Chave da API passada via --dart-define=CHAVE_API_GEMINI=...
  static const String chaveApi = String.fromEnvironment('CHAVE_API_GEMINI');

  static const String _enderecoApi =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.6-flash:generateContent';

  static const String _instrucaoSistema = '''
Você é o mestre de um RPG de texto em português do Brasil.

Regras:
- A aventura dura de 8 a 12 turnos.
- Cada turno deve ter exatamente 3 opções para o jogador, exceto no turno final, onde a lista de opções deve ser vazia.
- A vida do jogador começa em 100 e nunca pode passar de 100. Se chegar a 0, o jogo termina em derrota.
- Mantenha o inventário sempre atualizado conforme as ações do jogador.
- Responda SOMENTE em JSON puro, sem texto fora do formato. Nenhuma explicação extra, apenas o JSON.

Formato de resposta obrigatório:
{
  "narrativa": "Texto da cena, até 4 frases.",
  "opcoes": ["Opção 1", "Opção 2", "Opção 3"],
  "vida": 100,
  "inventario": ["item1"],
  "fim": false
}
''';

  final http.Client _cliente;

  /// Histórico de mensagens enviadas à API (alternando user e model).
  final List<Map<String, Object>> _historico = [];

  /// Envia uma mensagem à IA, atualiza o histórico e devolve um [Turno].
  Future<Turno> enviar(String mensagem) async {
    if (chaveApi.trim().isEmpty) {
      throw StateError(
        'A chave da API não foi configurada.\n'
        'Use: flutter run --dart-define=CHAVE_API_GEMINI=SuaChaveAqui',
      );
    }

    // Adiciona a mensagem do usuário ao histórico.
    _historico.add({
      'role': 'user',
      'parts': [
        {'text': mensagem},
      ],
    });

    final corpoRequisicao = <String, Object>{
      'system_instruction': {
        'parts': [
          {'text': _instrucaoSistema},
        ],
      },
      'contents': _historico,
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 1.0,
      },
    };

    final resposta = await _cliente
        .post(
          Uri.parse(_enderecoApi),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': chaveApi,
          },
          body: jsonEncode(corpoRequisicao),
        )
        .timeout(const Duration(seconds: 30));

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));

    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      // Remove a mensagem do histórico, pois a chamada falhou.
      _historico.removeLast();
      final erroApi = dados is Map<String, dynamic> ? dados['error'] : null;
      final detalhe =
          erroApi is Map<String, dynamic> ? erroApi['message'] : null;
      throw Exception(detalhe ?? 'A API Gemini retornou um erro.');
    }

    if (dados is! Map<String, dynamic>) {
      _historico.removeLast();
      throw const FormatException('A resposta da API Gemini é inválida.');
    }

    // Extrai o texto da resposta.
    final candidatos = dados['candidates'] as List<dynamic>?;
    final primeiroCandidato =
        (candidatos != null && candidatos.isNotEmpty) ? candidatos.first : null;
    final conteudo = primeiroCandidato is Map<String, dynamic>
        ? primeiroCandidato['content']
        : null;
    final partes = conteudo is Map<String, dynamic>
        ? conteudo['parts'] as List<dynamic>?
        : null;
    final textos = partes
            ?.whereType<Map<String, dynamic>>()
            .map((parte) => parte['text'])
            .whereType<String>()
            .toList() ??
        [];

    if (textos.isEmpty) {
      _historico.removeLast();
      throw const FormatException('A API Gemini não retornou uma resposta.');
    }

    final textoResposta = textos.join().trim();

    // Guarda a resposta do modelo no histórico.
    _historico.add({
      'role': 'model',
      'parts': [
        {'text': textoResposta},
      ],
    });

    // Remove eventuais blocos de código markdown como ```json ... ``` se o modelo retornar
    String jsonLimpo = textoResposta;
    if (jsonLimpo.startsWith('```')) {
      final linhas = jsonLimpo.split('\n');
      if (linhas.isNotEmpty && linhas.first.startsWith('```')) {
        linhas.removeAt(0);
      }
      if (linhas.isNotEmpty && linhas.last.startsWith('```')) {
        linhas.removeLast();
      }
      jsonLimpo = linhas.join('\n').trim();
    }

    // Converte o JSON em um Turno.
    final dynamic jsonTurno = jsonDecode(jsonLimpo);
    if (jsonTurno is! Map<String, dynamic>) {
      throw const FormatException('O JSON retornado não é um objeto válido.');
    }

    return Turno.fromJson(jsonTurno);
  }

  /// Limpa o histórico para uma nova aventura.
  void limparHistorico() {
    _historico.clear();
  }

  /// Fecha a conexão HTTP.
  void fechar() {
    _cliente.close();
  }
}

// ─────────────────────────────────────────────
// INTERFACE – RpgApp + TelaJogo
// ─────────────────────────────────────────────

void main() {
  runApp(const RpgApp());
}

/// Configuração do MaterialApp com tema escuro.
class RpgApp extends StatelessWidget {
  const RpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aventura IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TelaJogo(),
    );
  }
}

/// Tela principal que contém o menu de temas e a interface do jogo.
class TelaJogo extends StatefulWidget {
  const TelaJogo({super.key});

  @override
  State<TelaJogo> createState() => _EstadoTelaJogo();
}

class _EstadoTelaJogo extends State<TelaJogo> {
  final IaService _iaService = IaService();

  // Temas disponíveis conforme RF01.
  static const List<Map<String, dynamic>> _temas = [
    {'nome': '⚔️  Fantasia', 'valor': 'fantasia medieval'},
    {'nome': '🚀  Ficção Científica', 'valor': 'ficção científica'},
    {'nome': '👻  Terror', 'valor': 'terror'},
    {'nome': '🏴‍☠️  Pirataria', 'valor': 'pirataria'},
  ];

  Turno? _turnoAtual;
  bool _carregando = false;
  String? _erro;
  bool _jogoIniciado = false;

  @override
  void dispose() {
    _iaService.fechar();
    super.dispose();
  }

  /// Inicia uma nova aventura com o tema escolhido (RF02).
  Future<void> _iniciarAventura(String tema) async {
    setState(() {
      _carregando = true;
      _erro = null;
      _jogoIniciado = false;
    });

    try {
      final turno = await _iaService.enviar(
        'Inicie uma aventura de RPG com o tema: $tema. '
        'Apresente a cena inicial e as primeiras opções.',
      );
      if (!mounted) return;
      setState(() {
        _turnoAtual = turno;
        _jogoIniciado = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = _mensagemDeErro(e);
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Envia a opção escolhida à IA (RF05, RF06).
  Future<void> _enviarOpcao(String opcao) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final turno = await _iaService.enviar(opcao);
      if (!mounted) return;
      setState(() => _turnoAtual = turno);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = _mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Reinicia a aventura, voltando ao menu (RF09).
  void _reiniciar() {
    _iaService.limparHistorico();
    setState(() {
      _turnoAtual = null;
      _jogoIniciado = false;
      _carregando = false;
      _erro = null;
    });
  }

  String _mensagemDeErro(Object e) {
    if (IaService.chaveApi.trim().isEmpty) {
      return 'Configure a chave da API:\n'
          'flutter run --dart-define=CHAVE_API_GEMINI=SuaChaveAqui';
    }
    final msg = e.toString();
    if (msg.contains('RESOURCE_EXHAUSTED') || msg.contains('429')) {
      return 'Limite de requisições atingido (Cota temporária da API).\n'
          'Aguarde cerca de 30 a 60 segundos antes de tentar novamente.';
    }
    if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('ClientException')) {
      return 'Sem conexão com a internet ou servidor inacessível. Verifique sua rede.';
    }
    if (e is FormatException) {
      return 'A IA não devolveu o formato esperado nesta rodada. Tente novamente.';
    }
    return 'Erro ao contatar a IA:\n${e.toString().replaceAll('Exception: ', '')}';
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _jogoIniciado ? _appBarJogo() : null,
      body: SafeArea(
        child: _jogoIniciado ? _corpoJogo() : _menuInicial(),
      ),
    );
  }

  // ─── MENU INICIAL ───

  Widget _menuInicial() {
    final cores = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories,
              size: 72,
              color: cores.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aventura IA',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cores.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha o tema da aventura',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cores.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            // Botões de tema.
            ..._temas.map(
              (tema) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed:
                        _carregando ? null : () => _iniciarAventura(tema['valor'] as String),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(fontSize: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(tema['nome'] as String),
                  ),
                ),
              ),
            ),
            // Indicador de carregamento (RF08).
            if (_carregando) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Criando sua aventura...',
                style: TextStyle(color: cores.onSurfaceVariant),
              ),
            ],
            // Mensagem de erro (RF08).
            if (_erro != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cores.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _erro!,
                  style: TextStyle(color: cores.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── APP BAR DO JOGO ───

  PreferredSizeWidget _appBarJogo() {
    return AppBar(
      title: const Text('Aventura IA'),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Reiniciar aventura',
          onPressed: _carregando ? null : _reiniciar,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── CORPO DO JOGO ───

  Widget _corpoJogo() {
    final turno = _turnoAtual;
    if (turno == null) return const SizedBox.shrink();

    final cores = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ─ Barra de vida (RF04).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: turno.vida.clamp(0, 100) / 100,
                        minHeight: 14,
                        backgroundColor: cores.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          turno.vida > 50
                              ? Colors.greenAccent.shade400
                              : turno.vida > 25
                                  ? Colors.orangeAccent
                                  : Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${turno.vida}/100',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              // ─ Inventário (RF04).
              if (turno.inventario.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: turno.inventario
                        .map(
                          (item) => Chip(
                            avatar: const Icon(Icons.backpack, size: 16),
                            label: Text(item),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        // ─ Narrativa (RF04).
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turno.narrativa,
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cores.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _erro!,
                      style: TextStyle(color: cores.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // ─ Indicador de carregamento durante a jogada (RF08).
        if (_carregando)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(),
          ),
        // ─ Opções / Fim de jogo (RF05, RF07).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _botoesDeAcao(turno, cores),
        ),
      ],
    );
  }

  Widget _botoesDeAcao(Turno turno, ColorScheme cores) {
    // Fim de jogo (RF07).
    if (turno.fim || turno.vida <= 0) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: turno.vida <= 0
                  ? cores.errorContainer
                  : cores.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              turno.vida <= 0 ? '💀 Você foi derrotado!' : '🏆 Fim da aventura!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: turno.vida <= 0
                    ? cores.onErrorContainer
                    : cores.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _reiniciar,
              icon: const Icon(Icons.replay),
              label: const Text('Jogar novamente'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Opções normais (RF05).
    return Column(
      children: turno.opcoes
          .map(
            (opcao) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _carregando ? null : () => _enviarOpcao(opcao),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: cores.outline),
                  ),
                  child: Text(
                    opcao,
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
