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
  migrations/   tabelas (fase 1) e regras (fases 3 a 8), em ordem de data
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
| view `places_geo` | `places` com `lat` e `lng` em números (a coluna `location` volta em hexadecimal) |
| `goals.helpers`, `goals.enrolled` | quem doa não vê as doações dos outros, mas a tela mostra "12 ajudaram" e "3 vagas" |
| `donations.donor_name`, `monthly_gifts.donor_name`, `reviews.author_name` | o primeiro nome que a instituição e o perfil do ponto mostram (profiles é privado) |
| `submissions.patch` | numa mudança de dados, o que vai para `places` se a equipe aprovar |
| baldes `places`, `avatars` (públicos) e `receipts` (privado) | fotos dos pontos, fotos de perfil e comprovantes |

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

## 5. Regras de negócio (todas no banco)

- **A meta só avança com a confirmação da instituição.** Só o gatilho `after_donation_status` mexe em `goals.current` (a coluna não está no `GRANT UPDATE`). Ao chegar no alvo, a meta vira `done` e todos que ajudaram recebem aviso.
- **Doação nova** (`check_new_donation`): o ponto precisa estar ativo, a meta aberta, publicada e do mesmo tipo; o status é decidido pelo banco (Pix `waiting`, itens `items_agreed`, voluntariado `enrolled`); sem meta, só a doação mensal.
- **Voluntariado:** não passa do número de vagas, não se inscreve duas vezes; presença confirmada conta na meta; falta vira `absent`; cancelar devolve a vaga.
- **Trocar a chave Pix** pausa o Pix do ponto (`pix_paused`) até a equipe aprovar. Com o Pix pausado, o banco recusa doações Pix.
- **Mudanças de dados** (endereço, foto, responsável, chave Pix) passam pela equipe; nome, "sobre", o que distribui e horários não.
- **Uma conta, um ponto** (`one_place_per_owner`). Recusado ou removido não conta.
- **Revisão a cada 90 dias** (`last_reviewed`); a equipe vê os vencidos.
- **Fila da equipe:** urgente com mais de 3 dias úteis (calculado no app).
- **Aprovar** ativa o ponto e publica as metas guardadas; **ajuste** e **recusa** mandam motivo; **pausar** e **remover** tiram do mapa. Numa mudança de dados, ajuste e recusa só descartam a mudança (e despausam o Pix).
- **Avisos** nascem só pelo banco (função `notify`, gatilhos e funções acima); o app não insere em `notices`.

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

Ainda em aberto: confirmar o prazo de 90 dias e se uma recusa deve bloquear
novos cadastros com o mesmo CNPJ (hoje não bloqueia).

## 8. Serviços externos (todos gratuitos e sem chave)

- **Mapa:** OpenFreeMap, estilo em `assets/map/escora_style.json`.
- **Cidades:** API do IBGE. **Geocodificação:** nativa do iOS/Android (`geocoding`).
- **CNPJ:** BrasilAPI. **CEP:** ViaCEP (`lib/data/br_api.dart`).

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
