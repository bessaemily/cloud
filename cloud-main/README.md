# Assistente Inteligente

Aplicativo Flutter de conversa com o Gemini. A interface e os nomes definidos
no código estão em português brasileiro para facilitar a apresentação do
projeto.

## Configurar a chave da API

1. Crie uma chave no Google AI Studio.
2. Na raiz do projeto, abra `configuracao.env.json`.
3. Substitua o valor vazio de `CHAVE_API_GEMINI` pela sua chave.

O arquivo local não é incluído no Git. O arquivo `configuracao.exemplo.json`
mostra o formato necessário e não contém uma chave verdadeira.

## Executar o aplicativo

No terminal, dentro da pasta `cloudia`, execute:

```sh
flutter run --dart-define-from-file=configuracao.env.json
```

O serviço lê `CHAVE_API_GEMINI` com `String.fromEnvironment` durante a
compilação. A chave passada ao aplicativo pode ser extraída do pacote instalado;
para publicar um produto, proteja o acesso à API em um servidor próprio.

## Organização do código

- `lib/main.dart`: inicia o aplicativo e define o tema.
- `lib/telas/tela_conversa.dart`: controla a tela e o histórico da conversa.
- `lib/servicos/servico_gemini.dart`: envia as mensagens à API Gemini.
- `lib/modelos/mensagem.dart`: representa uma mensagem da conversa.
- `lib/componentes/balao_mensagem.dart`: desenha cada balão de mensagem.

## Verificar o código

```sh
flutter analyze
```
