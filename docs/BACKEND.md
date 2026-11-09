# Escora aqui: como o back-end funciona

O app (Flutter, iOS e Android) usa o **Supabase** no plano gratuito: banco
Postgres com PostGIS, login (Auth), arquivos (Storage), tempo real (Realtime)
e tarefas agendadas (pg_cron). Este documento explica onde fica cada parte e
onde mora cada regra de negócio.

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

Três modos no mesmo app: **doador**, **instituição** (quem cadastrou um ponto)
e **equipe de validação** (`profiles.is_team`, definido só no banco).

## 2. Onde fica cada parte

```
lib/data/
  auth.dart     conta: criar, entrar (e-mail e Google), sessão, perfil, senha, sair, apagar
  remote.dart   tudo o que lê e grava no Supabase, e a conversão linha → modelo
  store.dart    AppStore (`store`): o estado que as telas leem e as ações que chamam
  models.dart   Place, Goal, Donation, MonthlyGift, Notice, Submission, Report
  br_api.dart   BrasilAPI (CNPJ) e ViaCEP
supabase/
  migrations/   tabelas (fase 1) e regras (fases 3 a 9), em ordem de data
  seed.sql      dados de teste
```

**Como uma ação funciona** (ex.: `store.registerPix`):

1. O store muda a lista na hora, e a tela já mostra a doação.
2. Em segundo plano, `remote.dart` grava no banco (e envia o comprovante para o Storage).
3. Depois, o store **recarrega tudo** do banco (`refresh`), e a tela fica igual ao servidor.
4. Se o banco recusar, a mensagem da função SQL (em português) aparece num aviso (`store.errors`, mostrado pelo `main.dart`), e o recarregamento desfaz o que a tela tinha mostrado antes.

**Quando recarrega:** ao abrir o app (antes da primeira tela, se já houver
sessão), depois de cada ação e quando chega um aviso novo pelo tempo real (para
a equipe, também quando a fila ou as denúncias mudam).

## 3. Tabelas

Dez tabelas, criadas na fase 1 (mapa no [diagrama do banco](https://claude.ai/artifact/PfvjLDyFpuezoCH9jSMssW)):
`profiles`, `places`, `goals`, `monthly_gifts`, `donations`, `reviews`,
`follows`, `notices`, `submissions`, `reports`. As fases seguintes acrescentaram:

| O quê | Por quê |
| --- | --- |
| view `places_geo` | `places` com `lat` e `lng` em números (a coluna `location` volta em hexadecimal), sem `responsible` e `phone` |
| função `place_contacts(ids)` | nome e telefone do responsável, só para o dono do ponto e para a equipe |
| `goals.helpers`, `goals.enrolled` | quem doa não vê as doações dos outros, mas a tela mostra "12 ajudaram" e "3 vagas" |
| `donations.donor_name`, `monthly_gifts.donor_name`, `reviews.author_name` | o primeiro nome que a instituição e o perfil do ponto mostram (profiles é privado) |
| `submissions.patch` | numa mudança de dados, o que vai para `places` se a equipe aprovar |
| baldes `places`, `avatars` (públicos) e `receipts` (privado) | fotos dos pontos, fotos de perfil e comprovantes |

A **fase 9 (bonificação)** acrescentou seis tabelas: `points_profiles` (saldo,
nível e sequências de cada pessoa, uma linha por perfil), `points_ledger` (o
extrato: cada ganho e cada gasto, com o motivo), `partners` e `catalog_items`
(o catálogo de cupons dos parceiros), `redemptions` (o que cada um já trocou,
com o código do cupom)
e `seasonal_events` (só a estrutura: as datas e os bônus ainda não foram
definidos, e nenhuma função usa essa tabela).

O app lê tudo isso em `loadAll` (`remote.dart`) e guarda em `store.points`,
`store.pointsEntries`, `store.catalogItems` e `store.redemptions`. Essas cinco
consultas ficam num `try` separado: **com a fase 9 fora do banco, só a aba
Pontos fica vazia** (o erro aparece no console como `fase 9 (pontos)
indisponível`) e o resto do app carrega normalmente. O `register_daily_login`
falha do mesmo jeito, sem atrapalhar o login.

## 4. Ações e onde elas rodam

Ações simples são INSERT/UPDATE direto, protegidas pelo RLS. As que mexem em
linhas de outra pessoa ou em colunas protegidas são **funções** (`rpc`) que
conferem quem chama.

| Quem | Ação no store | No banco |
| --- | --- | --- |
| Doador | `registerPix`, `registerItems`, `enroll`, `payMonthly` | INSERT em `donations` (gatilho `check_new_donation` confere tudo) |
| | `cancelEnrollment` | `cancel_enrollment()` |
| | `follow`, `unfollow`, `rate`, `report`, `markRead`, `markAllRead` | INSERT/DELETE/UPDATE direto |
| | `startMonthly`, `updateMonthly`, `toggleMonthly`, `cancelMonthly` | `monthly_gifts` direto |
| Instituição | `confirm`, `markNotFound`, `savePresence` | `confirm_donation()`, `mark_not_found()`, `mark_absent()` |
| | `addGoal` | INSERT em `goals` |
| | `closeGoal`, `extendGoal`, `cancelAction`, `markGoalSeen` | `close_goal()`, `extend_goal()`, `cancel_action()`, UPDATE de `seen_done` |
| | `submitDraft` | INSERT (ou UPDATE no ajuste) em `places` + `submit_place()` |
| | `savePlaceInfo`, `renewReview` | `edit_place()`, `renew_review()` |
| | `requestChange`, `changePixKey` | `request_change()`, `change_pix_key()` |
| Equipe | `approve`, `askAdjust`, `refuse` | `approve_submission()`, `ask_adjust()`, `refuse_submission()` |
| | `keepOnMap`, `pause`, `remove`, `reactivate` | `keep_on_map()`, `pause_place()`, `remove_place()`, `reactivate_place()` |
| Conta | `apagarConta` (auth.dart) | `delete_account()` |
| Pontos | login diário (a cada sessão aberta) | `register_daily_login()` |
| | canjear um cupom do catálogo | `redeem_catalog_item()` |
| | pontos da doação | ninguém chama: saem do gatilho `donations_after_status`, quando a instituição confirma |

## 5. Regras de negócio (todas no banco)

- **A meta só avança com a confirmação da instituição.** Só o gatilho `after_donation_status` mexe em `goals.current` (a coluna não está no `GRANT UPDATE`). Ao chegar no alvo, a meta vira `done` e todos que ajudaram recebem aviso.
- **Doação nova** (`check_new_donation`): o ponto precisa estar ativo, a meta aberta, publicada e do mesmo tipo; o status é decidido pelo banco (Pix `waiting`, itens `items_agreed`, voluntariado `enrolled`); sem meta, só a doação mensal.
- **Voluntariado:** não passa do número de vagas, não se inscreve duas vezes; presença confirmada conta na meta; falta vira `absent`; cancelar devolve a vaga.
- **Trocar a chave Pix** pausa o Pix do ponto (`pix_paused`) até a equipe aprovar. Com o Pix pausado, o banco recusa doações Pix.
- **Mudanças de dados** (endereço, foto, responsável, chave Pix) passam pela equipe; nome, "sobre", o que distribui e horários não.
- **Uma conta, um ponto** (`one_place_per_owner`). Recusado ou removido não conta.
- **CNPJ no envio** (`submit_place`, com `cnpj_valido`): o banco recusa CNPJ com dígitos errados, CNPJ que já está em outro ponto (na fila, em ajuste, ativo ou pausado) e CNPJ que já teve cadastro recusado. A razão social vem do celular de quem cadastra, por isso a fila da equipe consulta a BrasilAPI de novo e compara (e mostra "não consultado" quando a consulta falhou no cadastro).
- **Revisão a cada 90 dias** (`last_reviewed`); a equipe vê os vencidos.
- **Fila da equipe:** urgente com mais de 3 dias úteis (calculado no app).
- **Aprovar** ativa o ponto e publica as metas guardadas; **ajuste** e **recusa** mandam motivo; **pausar** e **remover** tiram do mapa. Numa mudança de dados, ajuste e recusa só descartam a mudança (e despausam o Pix).
- **Contato do responsável é privado:** `places.responsible` e `places.phone` não têm SELECT para `authenticated` (fase 8, privacidade). Coluna nova em `places` precisa entrar no `GRANT SELECT` dessa migração e na view `places_geo`.
- **Apagar a conta** apaga antes os arquivos da pessoa no Storage (pelo app) e depois os dados (`delete_account`); as doações a outros pontos ficam sem doador e sem comprovante.
- **Avisos** nascem só pelo banco (função `notify`, gatilhos e funções acima); o app não insere em `notices`.

### Bonificação (fase 9)

Nenhum ponto é calculado no app: o saldo e o nível só mudam por funções do
banco, e `points_profiles` não tem política de INSERT nem de UPDATE.

- **Pontos da doação** saem do mesmo gatilho que faz a meta avançar
  (`after_donation_status`), ou seja **só quando a instituição confirma**:
  dinheiro vale 2 pontos por real (R$10 = 20 pontos) e item vale 2 pontos por
  item, independente de kg/litro/pacote/unidade (a tabela `donations` não
  guarda preço de item, só quantidade). Voluntariado não dá pontos.
- **Nível** (Bronze → Prata → Ouro → Black) é o maior entre três trilhas, a que
  vier primeiro: doações de R$10+ (5 / 20), pontos acumulados (100 / 500 /
  10.000) ou itens doados (50 / 150 / 500). Black só pela trilha de pontos ou
  de itens. Os três contadores nunca diminuem, então o nível nunca cai.
- **Saldo e total histórico são colunas diferentes:** o canje gasta o saldo
  (`balance`); o total (`lifetime`), que decide o nível, nunca decai.
- **Login diário** (`register_daily_login`): seg-sex 2 pontos, sábado 4,
  domingo 6, e 40 pontos de bônus quem fecha o mês sem falhar um dia. Chamar
  duas vezes no mesmo dia não pontua de novo.
- **Sequência mensal de doação** rende +10% de pontos por mês seguido. Falhar
  um mês só **pausa**: são 30 dias de carência e mais ~10 de decaimento antes
  de a sequência voltar a zero (punir com reset quem doa dinheiro gera
  frustração, diferente de um app gratuito).
- **Canje** (`redeem_catalog_item`): o banco confere o nível mínimo do item, o
  estoque e o saldo, desconta num `UPDATE` condicional (dois canjes ao mesmo
  tempo não deixam o saldo negativo) e gera o **código do cupom**
  (`redemptions.code`, tipo `ESC-A1B2C3`), que é o que a pessoa mostra no
  parceiro. Um item fora do catálogo (`active` false) continua visível para
  quem já trocou, senão a tela de trocas perderia o nome do cupom.
  Parceiros e itens do catálogo são cadastrados direto no banco pela equipe,
  como os dados de demonstração — não há tela para isso.

### Parceiro (fase 10)

Até a fase 9 o parceiro existia só como linha em `partners`: entregava o
cupom, mas não tinha login e nada registrava que o código foi usado. A fase
10 fecha esse ciclo com duas colunas e três funções.

- **`partners.owner_id`** liga a empresa a uma conta do app (índice único
  parcial: uma conta cuida de uma empresa só). A conta nasce pelo signup
  normal e **a equipe faz o `UPDATE`** — parceria é contrato, não
  autoatendimento, então não existe tela de cadastro de parceiro.
- **`redemptions.used_at`** guarda a baixa. Nulo = o cupom ainda vale.
- **`my_partner_id()`** responde "qual empresa é a de quem está chamando" e é
  o filtro de tudo o que vem abaixo.
- **`partner_find_redemption(p_code)`** procura o cupom pelo código, sem
  diferenciar maiúscula de minúscula nem espaço em volta. É `SECURITY
  DEFINER` porque atravessa a RLS de `redemptions` e `profiles` — e por isso
  filtra por `my_partner_id()`: **um parceiro nunca enxerga cupom de outro**,
  e a resposta traz só o **primeiro nome** de quem trocou, o suficiente para
  conferir no balcão sem abrir o perfil da pessoa.
- **`partner_use_redemption(p_code)`** dá a baixa num `UPDATE` condicionado a
  `used_at IS NULL`: dois caixas tentando ao mesmo tempo, só o primeiro
  marca. Quando não marca, a função distingue "já foi usado" de "não
  encontrado" — as duas respostas são úteis em pé no caixa.
- **`partner_catalog()`** devolve os cupons da empresa já com as contagens
  (trocados, usados) somadas no banco, em vez de deixar o app ler as linhas
  de `redemptions`, que têm o `user_id` de quem trocou.
- A política nova `"catalog_items: o parceiro vê os seus"` existe porque a
  da fase 9 só mostra item `active`: o parceiro precisa ver também o que
  saiu do catálogo, senão o histórico dele some.

No app isso é o `AppMode.partner`, com duas abas (Validar · Cupons). A porta
de entrada é o link **"Sou parceiro"** na tela de entrar, que leva a um login
próprio, sem Google e sem "criar conta". Uma conta que não é de parceiro é
desconectada ali mesmo, com a mensagem de usar a tela normal.

### Contato de quem doou (fase 11)

Migração `20261109154500_fase11_contato_doador.sql`. Não cria nem altera
tabela: é uma função de leitura só.

`place_donor_contact(p_donation uuid)` devolve nome, telefone, e-mail,
cidade e desde quando a pessoa tem conta. É `SECURITY DEFINER` porque
atravessa a RLS de `profiles` e de `auth.users`, e o que segura tudo é uma
condição só:

```sql
WHERE d.id = p_donation AND pl.owner_id = auth.uid()
```

Quer dizer: **só o dono do ponto que recebeu aquela doação** vê o contato
de quem a fez. Outro ponto, a equipe ou outro doador recebem zero linhas.

Decisões de privacidade tomadas aqui:

- Sai só o que serve para combinar uma entrega ou agradecer. Data de
  nascimento, causas escolhidas, raio de busca e doações feitas para
  **outros** pontos não saem.
- Doação de conta apagada (`donor_id` nulo) não devolve nada — o `JOIN`
  com `profiles` já elimina a linha.
- A tela da doação diz, em texto, por que aquele contato está ali: "Você vê
  este contato porque a pessoa doou para o seu ponto."
- O histórico "quantas vezes esta pessoa já doou aqui" **não** passa por esta
  função: ele é contado no app em cima das doações do próprio ponto, que a
  instituição já podia ler.

Enquanto a migração não estiver aplicada, a chamada falha, o app engole o
erro e a tela mostra "O contato desta pessoa não está disponível". Nada
mais quebra.

## 6. Tarefas diárias e tempo real (fase 7)

`daily_jobs()` roda todo dia às 8h de Brasília (`pg_cron`, `0 11 * * *` em UTC):

- metas com prazo vencido viram `expired`;
- lembrete de voluntariado na véspera (para quem tem `notify_volunteer`);
- lembrete da doação mensal no dia escolhido, se o mês ainda não foi pago.

O Realtime transmite `notices`, `submissions` e `reports`; o RLS continua
valendo para o que cada um recebe.

**Push no celular ficou de fora:** no iPhone exige a conta paga da Apple
(US$ 99/ano). Os avisos aparecem dentro do app.

## 7. Decisões de produto (2026-10-27)

| Pergunta | Decisão |
| --- | --- |
| Ponto sem CNPJ: quem confirma a indicação? | A equipe, na fila de cadastros (o status `awaiting_indication` não é usado) |
| SMS do celular do responsável | Tirado (SMS é pago). O telefone é só contato; a equipe confere |
| Um responsável pode ter mais de um ponto? | Não: uma conta, um ponto |
| Dados de demonstração | Só dados reais. A conta `dev.drenato@gmail.com` é da equipe e dona dos 14 pontos de teste |
| Prazo da revisão periódica (2026-10-28) | 90 dias |
| Uma recusa bloqueia o mesmo CNPJ? (2026-10-28) | Sim: a recusa é para casos graves. Para tentar de novo, a pessoa fala com a equipe |
| O CNPJ é dado sensível? (2026-10-28) | Não: é público na Receita e aparece no perfil do ponto. Sensíveis são o nome e o telefone do responsável (só dono e equipe) e os comprovantes (balde privado) |
| Pontos por item doado (2026-11-03) | 2 pontos por item, independente da unidade. `donations` só guarda quantidade, não preço |
| Limiar de pontos do Black (2026-11-03) | 10.000 pontos, o equivalente a R$5.000 doados, para manter a lógica das outras trilhas |
| Multiplicador da sequência mensal | +10% por mês seguido: **suposição**, ainda não confirmada com o usuário |
| Voluntariado dá pontos? | Ainda não. As regras fechadas só cobrem dinheiro e item |
| Indicação de amigo e meta coletiva por instituição | Fora da fase 9 (extras "se der tempo") |

## 8. Serviços externos (todos gratuitos e sem chave)

- **Mapa:** OpenFreeMap, estilo em `assets/map/escora_style.json`.
- **Cidades:** API do IBGE. **Geocodificação:** nativa do iOS/Android (`geocoding`).
- **CNPJ:** BrasilAPI, no cadastro e de novo na fila da equipe. **CEP:** ViaCEP (`lib/data/br_api.dart`).

## 9. Testar o banco sem mexer no projeto de verdade

Com o Docker ligado, o Supabase roda localmente com as mesmas migrações:

```bash
supabase start -x studio,imgproxy,vector,logflare,edge-runtime,supavisor,postgres-meta,realtime
supabase db reset --local --no-seed     # recria o banco local do zero
# crie as contas de teste no login local e depois:
docker exec -i supabase_db_escora-aqui psql -U postgres -d postgres < supabase/seed.sql
supabase stop
```

Para o app usar o banco local, rode com um `env` que tenha
`SUPABASE_URL=http://127.0.0.1:54321` e a chave pública que o `supabase start`
mostra.
