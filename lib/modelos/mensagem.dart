/// Representa uma mensagem enviada pelo usuário ou pelo assistente.
class Mensagem {
  const Mensagem({
    required this.conteudo,
    required this.ehUsuario,
    this.ehAviso = false,
  });

  final String conteudo;
  final bool ehUsuario;
  final bool ehAviso;
}
