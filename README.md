# Escora aqui

Aplicativo para iOS e Android que mostra, num mapa, pontos de apoio verificados
perto de você: ONGs, igrejas, escolas e coletivos. Cada ponto publica metas com
prazo e motivo, e quem está por perto escolhe como ajudar:

- **Pix:** a pessoa copia a chave da instituição, paga no app do banco e
  registra a doação. A meta só avança quando a instituição confirma que recebeu.
- **Itens:** combina a quantidade e o dia da entrega. A instituição confirma ao receber.
- **Voluntariado:** inscreve-se numa ação com dia e horário. A instituição marca a presença.

O app não movimenta dinheiro e não cobra taxa.

Ele tem três modos:

| Modo | Quem usa | O que faz |
| --- | --- | --- |
| Doador | qualquer conta | mapa, perfil do ponto, doar, minhas doações, avisos |
| Instituição | quem cadastrou um ponto | painel, metas, doações para confirmar, dados do ponto |
| Equipe de validação | contas marcadas como equipe no banco | aprovar cadastros, denúncias, pausar e remover pontos |

Feito em Flutter, com back-end no [Supabase](https://supabase.com) (plano gratuito).

> [!WARNING]
> **Por enquanto, o app só foi testado no iOS (simulador).** O código é o mesmo
> para Android, mas ninguém do grupo tem o Android Studio instalado, então o app
> nunca foi compilado para Android. Faltam, no mínimo:
>
> - instalar o Android Studio (ele traz o Java e o emulador) e rodar `flutter run` num Android;
> - **"Continuar com Google" no Android:** criar no Google Cloud (projeto
>   `escora-aqui`) um cliente do tipo **Android**, com o pacote
>   `com.escoraaqui.escora_aqui` e o SHA-1 da chave de debug
>   (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).
>   O código já está pronto; sem esse cliente, o Google recusa o login no Android.

## Sumário

1. [Rodar o app](#rodar-o-app)
2. [Testar o ciclo completo](#testar-o-ciclo-completo)
3. [Banco de dados (Supabase)](#banco-de-dados-supabase)
4. [Contas (Supabase Auth)](#contas-supabase-auth)
5. [Como o grupo trabalha com o Git](#como-o-grupo-trabalha-com-o-git)
6. [Problemas comuns](#problemas-comuns)
7. [Mapa](#mapa-gratuito-sem-chave)
8. [Estrutura do código](#estrutura-do-código)
9. [Andamento](#andamento)

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
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_Frs92xrJR7wUmwe6dPqOHA_DmGWLEA4",
  "GOOGLE_WEB_CLIENT_ID": "256374281446-fcvvdvbqvv3gkf78jbeohtn6nlqg3pam.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "256374281446-sqgupbprsbqojm0mmmjke8o43geqerlb.apps.googleusercontent.com"
}
```

Nada disso é segredo. A chave pública (`sb_publishable_…`) pode ficar no app
porque quem protege os dados são as permissões do banco (RLS). Os dois
`GOOGLE_…_CLIENT_ID` são do "Continuar com Google" (projeto `escora-aqui` no
Google Cloud).

O que **nunca** vai para o código, o README ou o Git: a chave secreta do
Supabase (`sb_secret_…`), a senha do banco e a chave secreta do Google (que
fica só no painel do Supabase).

### 2. Abrir o simulador

No Xcode 27 não existe mais o app "Simulator": a tela do iPhone abre no DeviceHub.

Veja quais iPhones estão instalados e ligue um deles pelo nome:

```bash
xcrun simctl list devices available | grep iPhone
xcrun simctl boot "iPhone 18 Pro"
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
```

Se aparecer `Unable to boot device in current state: Booted`, o iPhone já
estava ligado. Pode seguir.

### 3. Rodar

```bash
flutter run --dart-define-from-file=env.json
```

Ou aperte **F5** no VS Code: o `.vscode/launch.json` já passa o `env.json`.
Sem o `env.json`, o app não sabe qual é o projeto do Supabase.

A primeira compilação leva alguns minutos. Espere aparecer
`Flutter run key commands` antes de testar. Depois disso, no terminal do
`flutter run`: `r` recarrega, `R` reinicia, `q` encerra. Se você mudar o
`Info.plist` ou adicionar um pacote, encerre com `q` e rode de novo.

### Atalhos de desenvolvimento

Abrir uma tela direto:

```bash
flutter run --dart-define-from-file=env.json --dart-define=START=causes
```

Valores: `intro`, `verified`, `goal`, `location`, `located`, `help`, `causes`,
`notifications`, `account`, `create`, `login`, `home`, `inst` (modo
instituição) e `team` (painel da equipe). Sem `START`, o app abre na capa, ou no
mapa se já houver uma conta conectada.

`inst` e `team` usam a conta conectada: entre antes com uma conta que tenha
ponto (para `inst`) ou que seja da equipe (para `team`). Sem isso, o app abre no mapa.

Depois de usar um `START`, rode de novo sem ele. Senão o app instalado no
simulador continua abrindo sempre naquela tela.

## Testar o ciclo completo

É o roteiro da apresentação: uma doação sai do doador, passa pela instituição e
volta como aviso.

**Contas**

- `dev.drenato@gmail.com`: é da equipe e dona dos 14 pontos de teste. No modo
  instituição aparece sempre a **Casa Exemplo**. A senha fica com o grupo e não
  vai para o README.
- Qualquer outra conta, criada no próprio app: faz o papel de doador.

**Passo a passo**

1. Com a conta de doador, abra a **Casa Exemplo** no mapa e registre um Pix.
2. Saia (Perfil → Sair da conta) e entre com `dev.drenato@gmail.com`.
3. Vá em Perfil → modo instituição → **Doações** e confirme a doação. A barra da meta sobe.
4. Volte para a conta de doador: em **Avisos** chegou "Sua doação foi confirmada".

**Outros caminhos que valem mostrar**

- **Voluntariado:** inscreva-se numa ação. Ao tentar de novo, o app avisa que você já está inscrito.
- **Cadastro de ponto:** com uma conta nova, Perfil → Para instituições. O
  cadastro vai para a fila; com `dev.drenato@gmail.com`, aprove em Perfil →
  Painel da equipe. O ponto aparece no mapa.
- **Trocar a chave Pix:** no modo instituição, em Ponto. O Pix do ponto fica
  pausado até a equipe aprovar a chave nova.

## Banco de dados (Supabase)

- **Projeto:** `snnkvhlsnkvolbmskmjv`, região São Paulo, plano Free.
- **Painel:** [supabase.com/dashboard](https://supabase.com/dashboard).
- **Mapa das tabelas:** [diagrama do banco](https://claude.ai/artifact/PfvjLDyFpuezoCH9jSMssW).
- **Como o back-end funciona** (onde fica cada regra): [`docs/BACKEND.md`](docs/BACKEND.md).

Tudo o que o app usa no Supabase sai das migrações: as tabelas e as permissões,
as regras de negócio (funções e gatilhos), os baldes de fotos e comprovantes
(Storage), o tempo real dos avisos e a tarefa diária das 8h (pg_cron). Num
projeto novo, o `supabase db push` monta tudo isso. No painel, só é preciso
configurar o login (veja [Contas](#contas-supabase-auth)).

### Arquivos

```
supabase/
  config.toml
  migrations/        um arquivo por etapa, rodam em ordem pela data no nome
    …_extensoes_e_tipos.sql      PostGIS e os 7 tipos (enums)
    …_profiles.sql               perfis e o gatilho que cria o perfil no cadastro
    …_places.sql                 pontos de apoio (o rascunho também mora aqui)
    …_goals.sql                  metas
    …_doacoes.sql                monthly_gifts, donations, reviews
    …_seguir_e_avisos.sql        follows, notices
    …_equipe.sql                 submissions, reports
    …_indices.sql                índice do mapa e das chaves estrangeiras
    …_permissoes.sql             RLS: quem lê e escreve o quê
    …_fase3_mapa_e_leitura.sql   view com lat/lng, busca por raio, nomes e contadores
    …_fase4_doador.sql           regras da doação, avisos, Storage (fotos e comprovantes)
    …_fase5_instituicao.sql      confirmar doação, metas, cadastro e mudanças do ponto
    …_fase6_equipe.sql           aprovar, ajuste, recusa, pausar, remover, reativar
    …_fase7_avisos.sql           tempo real e tarefa diária (pg_cron)
    …_fase8_conta.sql            apagar a própria conta
    …_fase8_privacidade.sql      contato do responsável privado; comprovante sai junto com a conta
    …_cnpj_no_envio.sql          CNPJ conferido pelo banco no envio do cadastro
  seed.sql           dados de teste (14 pontos, 15 metas, 3 denúncias)
  seed_apresentacao.sql  doadores, doações, avaliações, avisos e mais 6 pontos (fictícios)
```

### CLI do Supabase

Primeira vez na máquina (rode num terminal comum, porque o login abre o navegador):

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

**Regras:**

- Um arquivo que já foi enviado com `db push` não se edita. Para corrigir, crie
  um arquivo novo. Se o `db push` der erro, nada foi aplicado: corrija o mesmo
  arquivo e rode de novo.
- **Primeiro o banco, depois o app.** Se uma mudança no app depende de uma
  migração nova, rode o `supabase db push` antes de juntar o código na `main`.
  Um app que chama uma função que o banco ainda não tem não carrega os pontos.
- Se criar uma coluna nova em `places`, inclua-a no `GRANT SELECT` e na view
  `places_geo` (veja a migração `fase8_privacidade`). Senão o app não enxerga a coluna.

### Dados de teste

O `seed.sql` cria 14 pontos (12 ativos e 2 na fila da equipe), 15 metas e 3
denúncias em volta do centro de São José do Rio Preto. Todos pertencem à conta
`dev.drenato@gmail.com`, que também é da equipe (`is_team = true`). A conta
precisa existir antes (Authentication → Users).

A regra do app é "uma conta, um ponto", mas essa conta de teste tem os 14. No
modo instituição ela mostra sempre a **Casa Exemplo** (o primeiro ponto ativo).
Para testar o cadastro de um ponto do zero, use outra conta.

```bash
supabase db push --include-seed
```

Ele já foi rodado no banco do projeto. Se o `seed.sql` mudar e for rodado de
novo, os pontos que já existem dão erro de id repetido: apague-os antes no
painel (Table Editor).

Para a apresentação, o `seed_apresentacao.sql` acrescenta 10 doadores
fictícios, 37 doações em vários estados, 14 avaliações, avisos para a conta de
teste e mais 6 pontos com metas. Rode-o uma vez, depois do `seed.sql`, colando
o arquivo no **SQL Editor** do painel. Se os dados já estiverem lá, ele para
sem mudar nada.

### Testar mudanças no banco sem mexer no projeto

Com o Docker ligado, dá para rodar o Supabase no próprio computador, com as
mesmas migrações. O passo a passo está em [`docs/BACKEND.md`](docs/BACKEND.md),
seção 9.

### Backup e pausa

- **Backup:** o plano gratuito não guarda backups para baixar. De vez em quando,
  rode `supabase db dump --linked -f backup.sql` e guarde o arquivo fora do Git.
- **Pausa:** o Supabase pausa o projeto depois de 1 semana sem uso. Abra o app
  ou o painel uns dias antes de apresentar.

## Contas (Supabase Auth)

O código fica em `lib/data/auth.dart`: criar conta, entrar (e-mail ou Google),
esqueci a senha, abrir já logado, salvar o perfil, sair e apagar a conta. As
telas só chamam essas funções.

O que fica configurado no painel do Supabase (não está no Git):

| Onde | Como deixar |
| --- | --- |
| Authentication → Sign In / Providers → **Email** | ligado; **Confirm email** desligado; senha mínima **8** |
| Authentication → Sign In / Providers → **Google** | ligado; Client IDs = `GOOGLE_WEB_CLIENT_ID,GOOGLE_IOS_CLIENT_ID` (do `env.json`, nessa ordem); Client Secret = chave secreta do cliente Web; **Skip nonce checks** desligado |
| Authentication → URL Configuration → **Redirect URLs** | `escoraaqui://senha-nova` (já está no `config.toml`; enviado com `supabase config push`) |

No Google Cloud, enquanto o app estiver "em teste", só os e-mails cadastrados
em Google Auth Platform → Público → **Usuários de teste** conseguem entrar com Google.

**Esqueci minha senha** usa o e-mail padrão do Supabase, que manda um link (no
plano gratuito, o texto desse e-mail não pode ser mudado). O link passa pelo
Supabase e volta para `escoraaqui://senha-nova`, que abre o app na tela "Crie
uma senha nova". Esse endereço está registrado no `ios/Runner/Info.plist` e no
`android/app/src/main/AndroidManifest.xml`. O link precisa ser aberto **no
mesmo aparelho** em que a pessoa pediu.

Para testar no simulador: peça o link no app, copie o link do e-mail no Mac e
rode `xcrun simctl openurl booted "LINK_COPIADO"`.

**Limite do e-mail gratuito:** o servidor de e-mail que vem com o Supabase só
entrega para os e-mails da **equipe do projeto** (Organization → Team) e manda
poucos e-mails por hora. Para mandar para qualquer pessoa, é preciso ligar um
SMTP próprio em Authentication → Emails → SMTP Settings (há opções gratuitas,
como o Resend e o Brevo).

## Como o grupo trabalha com o Git

A `main` é a versão que funciona. Cada mudança nasce num branch próprio:

```bash
git switch main
git pull                          # pega o que o grupo já enviou
git switch -c nome-da-mudanca     # cria o branch

# ... trabalha, roda o app, confere com: flutter analyze

git add caminho/dos/arquivos
git commit -m "O que mudou, em uma frase"
```

Quando estiver pronto:

```bash
supabase db push                  # só se a mudança tiver migração nova (vem antes!)
git switch main
git pull
git merge nome-da-mudanca
git push
git branch -d nome-da-mudanca     # o branch já está dentro da main
```

Antes de juntar na `main`, o `flutter analyze` precisa terminar sem nenhum aviso.

## Problemas comuns

| O que aparece | O que é | Como resolver |
| --- | --- | --- |
| `No supported devices connected` | o simulador está desligado | ligue um iPhone (veja [Abrir o simulador](#2-abrir-o-simulador)) |
| `FileSystemException … Operation timed out, errno = 60` no build | a pasta do projeto está no iCloud (Mesa ou Documentos) e o iCloud tirou o arquivo do disco | mova o projeto para fora do iCloud (ex.: `~/Projetos`). Se não der, apague `build` e `.dart_tool` e crie no lugar links para `~/Library/Caches` (`ln -s ~/Library/Caches/escora-aqui-build build`) |
| O app abre sempre na mesma tela | foi rodado com `START=...` | rode de novo sem o `START` |
| "Não deu para carregar os pontos" | migração que o app usa ainda não está no banco, o projeto do Supabase foi pausado ou falta internet | rode `supabase migration list`; se faltar alguma, `supabase db push`. Se o projeto estiver pausado, reative no painel |
| O botão de criar conta fica girando | o login por e-mail está desligado no painel | ligue em Authentication → Sign In / Providers → Email |
| "Acesso bloqueado" no Google | o e-mail não está nos usuários de teste do Google Cloud | adicione em Google Auth Platform → Público → Usuários de teste |
| O e-mail de "esqueci minha senha" não chega | limite do e-mail gratuito, ou o e-mail não é da equipe do projeto | olhe o spam, espere alguns minutos ou use um e-mail da equipe |
| `null value in column "owner_id"` ao rodar o seed | a conta `dev.drenato@gmail.com` não existe nesse banco | crie a conta antes (Authentication → Users) |
| O simulador pede passkey no login do Google | o simulador não tem as passkeys do seu iPhone | na tela do Google, toque em "Tentar de outro jeito" e entre com a senha |

## Mapa (gratuito, sem chave)

- **Dados:** [OpenFreeMap](https://openfreemap.org) (OpenStreetMap), tiles vetoriais sem limite de uso e sem cadastro.
- **Visual:** estilo próprio em `assets/map/escora_style.json` (cores da marca, ruas arredondadas).
- **Render:** `flutter_map` + `vector_map_tiles`. Pins, raio e animações são widgets Flutter.
- **Cidades:** API pública do IBGE. **Geocodificação:** geocoder nativo do iOS/Android (pacote `geocoding`).

A atribuição "OpenStreetMap contributors / OpenFreeMap" aparece no mapa principal, como pedem os termos.

## Estrutura do código

```
lib/
  core/        tema (cores, tipografia, motion), componentes, rotas, ícones
  data/        auth (conta), remote (Supabase), store (estado das telas), modelos, BrasilAPI/ViaCEP
  features/
    splash/ intro/ signup/ auth/   capa, onboarding, conta
    home/ map/ place/              mapa, pins e perfil do ponto
    donate/ donations/ notices/    doar (Pix, itens, voluntariado, mensal), histórico, avisos
    profile/                       perfil, edição de dados, ajuda e termos
    institution/                   modo instituição: cadastro, painel, metas, doações
    team/                          painel da equipe de validação
  dev/         ferramenta de tour para capturas de tela
supabase/      banco de dados: migrações e dados de teste
docs/BACKEND.md  como o back-end funciona e onde fica cada regra
```

As telas leem o `store` (`lib/data/store.dart`). Cada ação do store mostra o
resultado na hora, grava no banco pelo `lib/data/remote.dart` e depois recarrega
os dados. As regras que não podem depender do app (a meta só sobe com
confirmação, vagas do voluntariado, quem vê o quê) ficam nas funções e gatilhos
das migrações.

## Andamento

| Fase | O que é | Situação |
| --- | --- | --- |
| 1 · Fundação | tabelas, permissões, dados de teste, app ligado ao Supabase | pronta |
| 2 · Contas | criar conta, login (e-mail e Google), perfil do onboarding | pronta no iOS (Google no Android pendente) |
| 3 · Mapa e leitura | pontos por raio, perfil do ponto e metas vindos do banco | pronta |
| 4 · Doador | registrar doações, seguir, avaliar, denunciar, doação mensal | pronta |
| 5 · Instituição | cadastro, fotos, confirmar doações, metas, troca de chave Pix | pronta (sem verificação por SMS, que é paga) |
| 6 · Equipe | fila de validação, denúncias, pausar e remover pontos | pronta |
| 7 · Avisos | lembretes diários, avisos em tempo real | pronta, sem push no celular (exige a conta paga da Apple) |
| 8 · Produção | termos, LGPD, privacidade, backup | termos, privacidade e apagar a conta prontos; backup é manual |

Ainda em aberto: confirmar o prazo de revisão dos pontos (hoje, 90 dias) e
decidir se uma recusa deve impedir um novo cadastro com o mesmo CNPJ (hoje não impede).
