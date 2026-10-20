import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modelos/mensagem.dart';

/// Envia o histórico da conversa à API Gemini e devolve a resposta em texto.
class ServicoGemini {
  ServicoGemini({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  static const String chaveApi = String.fromEnvironment('CHAVE_API_GEMINI');
  static const String instrucaoSistema =
      'Você é o Assistente Inteligente. Responda em português brasileiro, '
      'com clareza, educação e explicações adequadas para quem está aprendendo.';
  static const String _enderecoApi =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.6-flash:generateContent';

  final http.Client _cliente;

  /// Obtém uma resposta do Gemini com base nas mensagens da conversa.
  Future<String> obterResposta({required List<Mensagem> mensagens}) async {
    if (chaveApi.trim().isEmpty) {
      throw StateError('A chave da API Gemini não foi configurada.');
    }

    final uri = Uri.parse(_enderecoApi);
    final corpoRequisicao = <String, Object>{
      'system_instruction': {
        'parts': [
          {'text': instrucaoSistema},
        ],
      },
      'contents': mensagens
          .where((mensagem) => !mensagem.ehAviso)
          .map(
            (mensagem) => {
              'role': mensagem.ehUsuario ? 'user' : 'model',
              'parts': [
                {'text': mensagem.conteudo},
              ],
            },
          )
          .toList(),
    };

    final resposta = await _cliente
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': chaveApi,
          },
          body: jsonEncode(corpoRequisicao),
        )
        .timeout(const Duration(seconds: 30));

    final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      final erroApi = dados is Map<String, dynamic> ? dados['error'] : null;
      final detalhe = erroApi is Map<String, dynamic>
          ? erroApi['message']
          : null;
      throw Exception(detalhe ?? 'A API Gemini retornou um erro.');
    }

    if (dados is! Map<String, dynamic>) {
      throw const FormatException('A resposta da API Gemini é inválida.');
    }

    final candidatos = dados['candidates'] as List<dynamic>?;
    final primeiroCandidato = candidatos == null || candidatos.isEmpty
        ? null
        : candidatos.first;
    final conteudo = primeiroCandidato is Map<String, dynamic>
        ? primeiroCandidato['content']
        : null;
    final partes = conteudo is Map<String, dynamic>
        ? conteudo['parts'] as List<dynamic>?
        : null;
    final textos =
        partes
            ?.whereType<Map<String, dynamic>>()
            .map((parte) => parte['text'])
            .whereType<String>()
            .toList() ??
        [];

    if (textos.isEmpty) {
      throw const FormatException('A API Gemini não retornou uma resposta.');
    }

    return textos.join();
  }

  /// Fecha a conexão HTTP quando o serviço deixa de ser usado.
  void fechar() {
    _cliente.close();
  }
}
