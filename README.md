# Escora aqui

App Flutter (iOS e Android): mapa de instituições verificadas perto de você.
Back-end no [Supabase](https://supabase.com) (plano gratuito).

## Rodar o app

### 1. Primeira vez na máquina

```bash
flutter pub get
```

Crie o arquivo `env.json` na raiz do projeto (ao lado do `pubspec.yaml`). Ele
fica fora do Git, então precisa ser criado em cada computador:

```json
{
  "SUPABASE_URL": "https://snnkvhlsnkvolbmskmjv.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_Frs92xrJR7wUmwe6dPqOHA_DmGWLEA4"
}
```

A chave pública (`sb_publishable_…`) pode ficar aqui: quem protege os dados são
as permissões do banco (RLS). A chave secreta (`sb_secret_…`) e a senha do banco
nunca vão para o código, o README ou o Git.

### 2. Abrir o simulador

No Xcode 27 não existe mais o app "Simulator": a tela do iPhone abre no DeviceHub.

```bash
xcrun simctl boot "iPhone 17 Pro"
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
```

Se o primeiro comando disser `Unable to boot device in current state: Booted`,
o iPhone já estava ligado. Pode seguir.

### 3. Rodar

```bash
flutter run --dart-define-from-file=env.json
```

Ou aperte **F5** no VS Code: o `.vscode/launch.json` já passa o `env.json`.
Sem o `env.json`, o app não sabe qual é o projeto do Supabase.

No terminal do `flutter run`: `r` recarrega, `R` reinicia, `q` encerra.

### Atalhos de desenvolvimento

Abrir uma tela direto:

```bash
flutter run --dart-define-from-file=env.json --dart-define=START=causes
```

Valores: `intro`, `verified`, `goal`, `location`, `located`, `help`, `causes`,
`notifications`, `account`, `create`, `login`, `home`, `inst` (modo
instituição), `team` (painel da equipe), `returning`. Sem `START`, abre na capa.

Depois de usar um `START`, rode de novo sem ele. Senão o app instalado no
simulador continua abrindo sempre naquela tela.

## Banco de dados (Supabase)

- **Projeto:** `snnkvhlsnkvolbmskmjv`, região São Paulo, plano Free.
- **Painel:** [supabase.com/dashboard](https://supabase.com/dashboard).
- **Mapa das tabelas:** [diagrama do banco](https://claude.ai/artifact/PfvjLDyFpuezoCH9jSMssW).

### Arquivos

```
supabase/
  config.toml
  migrations/        um arquivo por etapa, rodam em ordem pela data no nome
    …_extensoes_e_tipos.sql   PostGIS e os 7 tipos (enums)
    …_profiles.sql            perfis + gatilho que cria o perfil no cadastro
    …_places.sql              pontos de apoio (o rascunho também mora aqui)
    …_goals.sql               metas
    …_doacoes.sql             monthly_gifts, donations, reviews
    …_seguir_e_avisos.sql     follows, notices
    …_equipe.sql              submissions, reports
    …_indices.sql             índice do mapa e das chaves estrangeiras
    …_permissoes.sql          RLS: quem lê e escreve o quê
  seed.sql           dados de teste (os pontos fictícios do seed.dart)
```

### CLI do Supabase

Primeira vez na máquina (rode no seu terminal, não pelo `!` do Claude Code: o
login abre o navegador):

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref snnkvhlsnkvolbmskmjv   # pede a senha do banco
```

Mudar o banco:

```bash
supabase migration new nome_da_mudanca   # cria o arquivo vazio em migrations/
# escreva o SQL no arquivo
supabase db push                         # envia o que o banco ainda não tem
supabase migration list                  # mostra o que já foi enviado
```

**Regra:** um arquivo que já foi enviado com `db push` não se edita. Para
corrigir, crie um arquivo novo. Se o `db push` der erro, nada foi aplicado:
corrija o mesmo arquivo e rode de novo.

### Dados de teste

O `seed.sql` cria 14 pontos (12 ativos e 2 na fila da equipe), 15 metas e 3
denúncias em volta do centro de São José do Rio Preto. Todos pertencem à conta
`dev.drenato@gmail.com`, que também é da equipe (`is_team = true`). A conta
precisa existir antes (Authentication → Users).

```bash
supabase db push --include-seed
```

Ele já foi rodado no banco do projeto. Se o `seed.sql` mudar e for rodado de
novo, os pontos que já existem dão erro de id repetido: apague-os antes no
painel (Table Editor).

## Mapa (gratuito, sem chave)

- **Dados:** [OpenFreeMap](https://openfreemap.org) (OpenStreetMap), tiles vetoriais sem limite de uso e sem cadastro.
- **Visual:** estilo próprio em `assets/map/escora_style.json` (cores da marca, ruas arredondadas).
- **Render:** `flutter_map` + `vector_map_tiles`. Pins, raio e animações são widgets Flutter.
- **Cidades:** API pública do IBGE. **Geocodificação:** geocoder nativo do iOS/Android (pacote `geocoding`).

A atribuição "OpenStreetMap contributors / OpenFreeMap" aparece no mapa principal, como pedem os termos.

## Estrutura

```
lib/
  core/        tema (cores, tipografia, motion), componentes, rotas, ícones
  data/        modelos, store em memória (back-end falso), dados fictícios, BrasilAPI/ViaCEP
  features/
    splash/ intro/ signup/ auth/   capa, onboarding, conta
    home/ map/ place/              mapa, pins e perfil do ponto
    donate/ donations/ notices/    doar (Pix, itens, voluntariado, mensal), histórico, avisos
    profile/                       perfil e edição de dados
    institution/                   modo instituição: cadastro, painel, metas, doações
    team/                          painel da equipe de validação
  dev/         ferramenta de tour para capturas de tela
supabase/      banco de dados: migrações e dados de teste
docs/BACKEND.md  passagem para o back-end
```

## Andamento do back-end

| Fase | O que é | Situação |
| --- | --- | --- |
| 1 · Fundação | tabelas, permissões, dados de teste, app ligado ao Supabase | pronta |
| 2 · Contas | criar conta, login (e-mail e Google), perfil do onboarding | próxima |
| 3 · Mapa e leitura | pontos por raio, perfil do ponto e metas vindos do banco | |
| 4 · Doador | registrar doações, seguir, avaliar, denunciar, doação mensal | |
| 5 · Instituição | cadastro, fotos, confirmar doações, metas, troca de chave Pix | |
| 6 · Equipe | fila de validação, denúncias, pausar e remover pontos | |
| 7 · Avisos | lembretes diários, avisos em tempo real, push | |
| 8 · Produção | termos, LGPD, testes, backup | |

O app já se conecta ao Supabase, mas as telas ainda usam os dados em memória
(`lib/data/store.dart`), que somem ao fechar o app. Conta, login, SMS, avisos e
respostas das instituições continuam simulados até as próximas fases. Detalhes
em [`docs/BACKEND.md`](docs/BACKEND.md).
