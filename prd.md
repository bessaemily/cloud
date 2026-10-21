# PRD de Implementação – Aventura IA

*App Flutter de RPG de texto com IA na nuvem · Grupo 1 – IA na Nuvem · Versão 1.0*

## 1. Visão geral

**Aventura IA** é um minijogo em Flutter no qual uma IA na nuvem (API do Google Gemini) atua como mestre de um RPG de texto. O jogador escolhe um tema, lê a cena gerada e decide a próxima ação entre três opções. A cada jogada o app consulta a IA, que devolve a história, as opções e o estado do jogo (vida e inventário) em JSON. O app trata esse JSON e o transforma em interface.

O projeto atende ao enunciado da atividade: é um app Flutter pronto, com chamada a IA na nuvem, simples de explicar, implementar ao vivo e modificar pela turma.

## 2. Problema e objetivos

**Problema.** Chatbots genéricos mostram apenas texto e pouco da integração real entre app e IA. A turma precisa ver como consumir uma API de IA, tratar o retorno estruturado e aplicá-lo em uma interface.

**Objetivos**

- Demonstrar de forma clara o ciclo requisição → resposta → tratamento → tela.
- Entregar um app divertido, que prenda a atenção durante a apresentação.
- Ter uma única função de chamada à IA (`enviar()`), pequena o bastante para ser implementada ao vivo.
- Permitir modificações simples pela turma (trocar prompt, tratar novo campo, criar nova tela).

**Fora dos objetivos:** login de usuários, banco de dados, multiplayer, publicação em loja e backend próprio.

## 3. Escopo

| Dentro do escopo | Fora do escopo |
|---|---|
| Tela inicial com escolha de tema | Cadastro e login |
| Tela de jogo com narrativa, opções, vida e inventário | Salvar partidas entre sessões |
| Histórico de conversa enviado a cada turno | Imagens ou áudio gerados por IA |
| Tela de fim de jogo e reinício | Servidor intermediário (proxy) |
| Tratamento de erros de rede e de API | Internacionalização completa |

## 4. Requisitos funcionais

| ID | Requisito | Prioridade |
|---|---|---|
| RF01 | O app deve exibir uma lista de temas (fantasia, ficção científica, terror, pirataria) e iniciar a aventura ao selecionar um. | Alta |
| RF02 | O app deve enviar à IA uma mensagem inicial com o tema escolhido. | Alta |
| RF03 | A IA deve responder em JSON com `narrativa`, `opcoes`, `vida`, `inventario` e `fim`. | Alta |
| RF04 | O app deve exibir a narrativa, a barra de vida e o inventário a partir do JSON. | Alta |
| RF05 | O app deve exibir as opções como botões; ao tocar, envia a escolha à IA. | Alta |
| RF06 | O app deve reenviar o histórico completo em cada chamada, para a IA manter a continuidade da história. | Alta |
| RF07 | Quando `fim` for verdadeiro, o app deve ocultar as opções e mostrar o botão "Jogar novamente". | Alta |
| RF08 | O app deve mostrar indicador de carregamento durante a chamada e mensagem clara em caso de erro. | Média |
| RF09 | O jogador deve poder reiniciar a aventura a qualquer momento, limpando o histórico. | Média |
| RF10 | (Extra) O jogador pode digitar uma ação livre além das opções. | Baixa |

## 5. Requisitos não funcionais

- **Simplicidade:** código em um único arquivo (`lib/main.dart`), com três blocos bem separados: modelo, serviço de IA e interface.
- **Segurança:** a chave de API não deve ficar escrita no código; usa-se `--dart-define=GEMINI_KEY=...`.
- **Desempenho:** a resposta de cada turno deve aparecer em poucos segundos, e o app deve continuar fluido durante a espera.
- **Robustez:** falhas de rede, resposta fora do formato ou erro HTTP não podem derrubar o app.
- **Compatibilidade:** Android (principal) e, opcionalmente, iOS, web e desktop.
- **Custo:** uso do plano gratuito do Google AI Studio, sujeito a limites de requisições.

## 6. Arquitetura

**Fluxo de uma jogada**

1. O jogador toca em uma opção na `TelaJogo`.
2. A tela chama `IaService.enviar(mensagem)`.
3. O serviço adiciona a mensagem ao histórico e faz um `POST` à API do Gemini (`generateContent`).
4. A API devolve um texto em JSON, que o serviço guarda no histórico como resposta do modelo.
5. O serviço converte o JSON em um objeto `Turno`.
6. A tela atualiza o estado (`setState`) e redesenha narrativa, vida, inventário e opções.

**Componentes**

| Componente | Responsabilidade |
|---|---|
| `Turno` | Modelo de dados de um turno; método `fromJson`. |
| `IaService` | Prompt de sistema, histórico, chamada HTTP e conversão do retorno. |
| `RpgApp` | Configuração do `MaterialApp` e do tema escuro. |
| `TelaJogo` | Estado (turno atual, carregando, erro), menu inicial e tela de jogo. |

**Dependências:** `flutter` e o pacote `http`.

## 7. Contrato com a IA

**Endpoint:** `POST https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent`

**Cabeçalhos:** `Content-Type: application/json` e `x-goog-api-key: <chave>`.

**Corpo da requisição**

- `systemInstruction`: define o papel de mestre do jogo, as regras e o formato de saída.
- `contents`: lista de mensagens alternando `user` e `model` (o histórico completo).
- `generationConfig`: `responseMimeType: application/json` (força a resposta em JSON) e `temperature: 1.0`.

**Formato esperado da resposta (dentro de `candidates[0].content.parts[0].text`)**

```json
{
  "narrativa": "Texto da cena, até 4 frases.",
  "opcoes": ["Opção 1", "Opção 2", "Opção 3"],
  "vida": 100,
  "inventario": ["tocha"],
  "fim": false
}
```

**Regras do prompt de sistema**

- Aventura em português do Brasil, com 8 a 12 turnos.
- Exatamente 3 opções por turno, exceto no final (lista vazia).
- Vida inicial 100, máximo 100; vida 0 encerra o jogo com derrota.
- Inventário sempre atualizado.
- Resposta somente em JSON, sem texto fora do formato.

## 8. Telas

**Menu inicial**

- Título e instrução "Escolha o tema da aventura".
- Um botão por tema.
- Indicador de carregamento enquanto o primeiro turno é gerado.
- Mensagem de erro em vermelho, se a chamada falhar.

**Tela de jogo**

- Topo: barra de vida (0 a 100) com valor numérico.
- Linha de inventário com um *chip* por item.
- Área central rolável com a narrativa.
- Rodapé: três botões de opção ou, no fim do jogo, o botão "Jogar novamente".
- Barra do aplicativo com ícone de reiniciar.

## 9. Plano de implementação

| Fase | Entrega | Critério de conclusão |
|---|---|---|
| 1. Preparação | Projeto Flutter criado, pacote `http` instalado, chave gerada no Google AI Studio. | `flutter run` abre o app sem erros. |
| 2. Modelo | Classe `Turno` com `fromJson`. | Um JSON de exemplo é convertido corretamente. |
| 3. Serviço de IA | `IaService` com prompt, histórico e `enviar()`. | Uma chamada de teste retorna um `Turno` válido. |
| 4. Interface | Menu inicial e tela de jogo. | Uma partida completa é jogável até o fim. |
| 5. Tratamento de erros | Carregamento, mensagens de erro e reinício. | Sem internet ou com chave inválida, o app mostra erro e continua funcionando. |
| 6. Testes | Três partidas completas, uma por tema, mais cenários de erro. | Checklist da seção 10 aprovado. |
| 7. Apresentação | Slides, ensaio da implementação ao vivo e vídeo. | Roteiro da seção 13 cumprido no tempo. |

## 10. Critérios de aceite

- [ ] Cada um dos quatro temas inicia uma aventura.
- [ ] Narrativa, vida e inventário refletem exatamente o JSON recebido.
- [ ] A história mantém coerência entre os turnos (a IA lembra de escolhas anteriores).
- [ ] Vida zerada ou conclusão da trama exibe o fim de jogo.
- [ ] "Jogar novamente" e o ícone de reiniciar limpam o histórico e voltam ao menu.
- [ ] Sem internet, ou com chave inválida, o app exibe mensagem de erro sem travar.
- [ ] A chave de API não aparece em nenhum arquivo do projeto.

## 11. Riscos e mitigações

| Risco | Impacto | Mitigação |
|---|---|---|
| IA devolve JSON inválido ou fora do formato | App quebra ao converter | Usar `responseMimeType: application/json`, envolver `jsonDecode` em `try/catch` e permitir tentar de novo. |
| Limite do plano gratuito atingido durante a apresentação | Demonstração interrompida | Testar antes, evitar chamadas excessivas e ter um vídeo gravado de reserva. |
| Internet instável na sala | Chamada ao vivo falha | Usar o roteiro com o código já pronto e a chamada em outro dispositivo ou rede móvel de apoio. |
| Nome do modelo mudar ou ser descontinuado | Erro 404 na API | Manter o nome em uma constante e conferir o modelo atual no Google AI Studio antes de apresentar. |
| Histórico crescer demais | Custo e latência maiores | A aventura é curta (8 a 12 turnos), então o histórico permanece pequeno. |
| Vazamento da chave de API | Uso indevido da cota | Usar `--dart-define`, não publicar a chave no repositório e revogá-la após a apresentação. |

## 12. Custos, segurança e privacidade

- **Custos:** a API cobra por tokens de entrada e saída. O plano gratuito do Google AI Studio cobre o uso do trabalho, com limites de requisições por minuto e por dia. Como o histórico é reenviado a cada turno, o consumo cresce ao longo da partida.
- **Segurança:** em um app de produção, a chave ficaria em um servidor intermediário, e o app falaria com esse servidor. Neste trabalho, o app chama a API diretamente, o que é aceitável para fins didáticos, mas deve ser citado como limitação.
- **Privacidade:** o texto digitado pelo jogador é enviado à nuvem. O app não deve coletar dados pessoais, e o jogador deve evitar informar dados sensíveis.
