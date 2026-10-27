# Escora aqui: passagem para o back-end

O front-end (Flutter, iOS e Android) está pronto e funciona de ponta a ponta,
mas **todos os dados vivem na memória do app** e somem quando ele fecha. Este
documento explica o que o app já faz, onde está o "back-end falso" e o que
precisa virar servidor de verdade.

## 1. O que é o app

Mapa de pontos de apoio (ONGs, igrejas, escolas, coletivos) **verificados**
perto da pessoa. Cada ponto publica **metas** com prazo e motivo, e quem está
perto ajuda de três formas:

| Forma | Como funciona |
| --- | --- |
| **Pix** | O doador copia a chave da instituição e paga **no app do banco**. Depois registra no app quanto doou (com comprovante opcional). A meta só avança quando a **instituição confirma** o recebimento ("modelo B"). |
| **Itens** | O doador combina a quantidade e a data de entrega. A instituição confirma quando recebe. |
| **Voluntariado** | O doador se inscreve numa ação (dia e horário). A instituição marca presença depois. |

**O app não movimenta dinheiro.** O Escora aqui não recebe valor nem cobra
taxa. Isso é regra de produto e aparece nos textos.

Existem três modos de uso, todos no mesmo app:

1. **Doador:** mapa, perfil do ponto, doar, "Minhas doações", avisos, perfil.
2. **Instituição:** quem cadastrou um ponto troca para esse modo. Tem painel, metas, caixa de doações para confirmar e dados do ponto.
3. **Equipe de validação:** fila de cadastros para aprovar, pedir ajuste ou recusar, mais denúncias e gestão dos pontos (pausar, remover, reativar).

## 2. Onde está o back-end falso

```
lib/data/
  models.dart   entidades (Place, Goal, Donation, MonthlyGift, Notice, Submission...)
  store.dart    AppStore: um ChangeNotifier global (`store`) com TODAS as ações
  seed.dart     12 pontos fictícios em volta do usuário + fila da equipe
  br_api.dart   BrasilAPI (CNPJ) e ViaCEP: já são APIs reais e gratuitas
```

As telas só leem `store.<lista>` e chamam `store.<ação>()`. **Caminho
sugerido:** manter os nomes dos métodos do `AppStore` e trocar o corpo de cada
um por chamadas à API (ou criar uma camada de repositório por baixo). Assim
quase nenhuma tela precisa mudar. Os métodos hoje são síncronos; ao virarem
`Future`, as telas que chamam precisam de `await` e de um estado de
carregamento (a maioria já tem `loading`).

`lib/features/onboarding/onboarding_state.dart` guarda as escolhas do
onboarding (cidade, posição, formas de ajuda, causas, avisos). Isso também
deve ir para o perfil do usuário no servidor.

## 3. Entidades

Os campos completos estão em `lib/data/models.dart`.

- **Usuário** (hoje são campos soltos no `AppStore`): nome, nome completo, e-mail, celular, data de nascimento (opcional), foto, cidade/posição, formas de ajuda, causas, preferências de aviso, pontos que acompanha (`followed`), modo atual, se é da equipe (`isTeam`).
- **Place** (ponto de apoio): nome, tipo, `kind` (school/church/care), endereço, CEP, posição (lat/lng), horários, dias de recebimento, "sobre", "o que distribui", causas, formas de ajuda aceitas, CNPJ (ou indicação, para coletivos sem CNPJ), razão social, situação do CNPJ, chave Pix + tipo + favorecido, responsável, telefone, foto, `status` (`draft, review, awaitingIndication, adjust, refused, active, paused, removed`), `pixPaused`, `verifiedAt`, `lastReviewed`, motivo e mensagem de status, avaliações.
- **Goal** (meta de um ponto): tipo (pix/itens/voluntariado), alvo, atual, item e unidade, prazo, motivo, causa, ação de voluntariado (nome, tarefa, dia, início, fim), `status` (`open, done, expired, closed`), quantos ajudaram, inscritos, `published` (metas criadas antes da aprovação ficam guardadas até o ponto ser aprovado).
- **Donation:** ponto, meta (pode vir vazia na doação mensal sem meta Pix aberta), tipo, valor ou quantidade, data, doador, data combinada (itens/voluntariado), tem comprovante, `status` (`waiting, confirmed, notFound, enrolled, itemsAgreed, cancelled, absent`), confirmada em, já avaliada.
- **MonthlyGift** (doação mensal): ponto, valor, dia do mês (1 a 28), pausada, meses já pagos. **Não é débito automático:** no dia, o app avisa e a pessoa paga no banco. Cada mês vira uma `Donation` Pix normal.
- **Notice** (aviso): tipo (`newGoal, confirmed, notFound, volunteerReminder, goalDone, monthlyReminder` para doador; `approved, adjust, refused, paused, reactivated, newDonation` para instituição), título, texto, ponto, lido.
- **Submission** (fila da equipe): `novo` (cadastro), `correcao` (reenvio após ajuste), `mudanca` (troca de dados sensíveis, como a chave Pix), com o mapa de mudanças.
- **Report** (denúncia): ponto, motivo (lista fixa `reportReasons`), texto.
- **Review:** nome, data, estrelas, comentário. A pessoa avalia depois de uma doação confirmada.

## 4. Ações (o que vira endpoint)

| Quem | Métodos no `AppStore` |
| --- | --- |
| Conta | **Pronto** em `lib/data/auth.dart`: `criarConta`, `entrar`, `entrarComGoogle`, `restaurarSessao`, `carregarPerfil`, `salvarPreferencias`, `salvarDados`, `pedirLinkDeSenha`, `ouvirLinkDeSenha`, `salvarSenhaNova`, `sair` |
| Doador | `follow`, `unfollow`, `registerPix`, `registerItems`, `enroll`, `cancelEnrollment`, `rate`, `report`, `markRead`, `markAllRead` |
| Doação mensal | `startMonthly`, `updateMonthly`, `toggleMonthly`, `cancelMonthly`, `payMonthly` |
| Instituição | `startDraft`, `submitDraft`, `reopenDraft` (cadastro em 5 passos), `confirm`, `markNotFound`, `savePresence`, `cancelAction`, `addGoal`, `closeGoal`, `extendGoal`, `renewReview`, `requestChange`, `changePixKey` |
| Equipe | `approve`, `askAdjust`, `refuse`, `keepOnMap`, `pause`, `remove`, `reactivate` |

## 5. Regras de negócio que hoje estão no front

O servidor precisa ser a fonte da verdade delas:

- A meta só avança com **confirmação da instituição** (`confirm`). Ao chegar no alvo, vira `done` e quem doou recebe aviso.
- **Voluntariado:** a presença marcada vira doação confirmada; falta vira `absent`.
- **Trocar a chave Pix** gera uma `Submission` do tipo `mudanca` e pausa o Pix do ponto (`pixPaused`) até a equipe aprovar.
- **Revisão periódica:** o ponto precisa confirmar os dados a cada **90 dias** (`daysSinceReview > 90`). Depois disso aparece como vencido no painel da equipe.
- **Fila da equipe:** um item fica urgente com mais de 3 dias úteis.
- **Status do ponto:** aprovar ativa o ponto e publica as metas guardadas; ajuste e recusa mandam motivo e mensagem; pausar e remover tiram o ponto do mapa.
- **Doação mensal:** o lembrete sai no dia escolhido se não estiver pausada e o mês ainda não foi pago. O pagamento conta na meta Pix aberta do ponto, se existir.

## 6. O que está simulado e precisa de verdade

| Hoje | Precisa |
| --- | --- |
| ~~Criar conta, login e "Continuar com Google" sempre dão certo~~ | **Feito** com Supabase Auth (e-mail/senha + Google no iOS + link no e-mail para senha nova). Falta o Google no Android |
| Código SMS do celular do responsável aparece num toast | Verificação por SMS (ou trocar por e-mail) |
| `simulateReplies`: timers fingem a instituição confirmando Pix (25 s), um doador se inscrevendo (15 s), lembrete mensal (20 s) e doador mensal novo (30 s) | Remover. Isso vem de outros usuários e de jobs agendados |
| Avisos só dentro do app (`notices`) | Push (APNs/FCM) + job diário para lembretes (voluntariado na véspera, doação mensal no dia) |
| Fotos (ponto, comprovante, avatar) são caminhos de arquivo local | Upload para storage e URL no registro |
| Fotos de banco (CC0, StockSnap) para os 12 pontos fictícios em `assets/images/places/` | Somem quando os pontos forem reais (`Place.image` usa primeiro a foto enviada) |
| `isTeam = true` para todo mundo (demonstração) | Papel de equipe definido no servidor |
| Pontos gerados em volta da posição do usuário (`seed.dart`) | Busca por raio (5 → 10 → 20 → 50 km) e filtros por forma de ajuda e causa no servidor |

## 7. Serviços externos já usados (todos gratuitos e sem chave)

- **Mapa:** OpenFreeMap (tiles vetoriais do OpenStreetMap) com estilo próprio em `assets/map/escora_style.json`.
- **Cidades:** API do IBGE. **Geocodificação:** nativa do iOS/Android (pacote `geocoding`).
- **CNPJ:** BrasilAPI. **CEP:** ViaCEP (`lib/data/br_api.dart`). Vale repetir a checagem do CNPJ no servidor.

O projeto evita serviços pagos: é um projeto escolar, e a ideia é ficar em
planos gratuitos.

## 8. Pendências de produto ainda abertas

- Textos de Ajuda e Termos de uso (hoje: "Essa página chega na próxima versão.").
- Confirmar o prazo de revisão de 90 dias.
- Um responsável pode ter mais de um ponto?
- Uma recusa bloqueia novos cadastros com o mesmo CNPJ?
- LGPD: CPF não é coletado; data de nascimento é opcional e ainda não é usada para nada.

## 9. Rodar e testar telas

```bash
flutter pub get
flutter run                                 # começa pela capa
flutter run --dart-define=START=inst        # direto no modo instituição (demo)
flutter run --dart-define=START=team        # direto no painel da equipe
flutter run --dart-define=START=returning   # usuário que já tem conta
```

**Modo tour (capturas sem tocar na tela):**

```bash
flutter run --dart-define=START=tour --dart-define=TOUR_FILE=/tmp/tour.txt
echo place > /tmp/tour.txt
```

Os nomes de tela aceitos estão em `lib/dev/tour.dart`.
