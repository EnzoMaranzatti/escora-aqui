# Escora aqui

App Flutter (iOS e Android): mapa de instituições verificadas perto de você.

## Rodar

```bash
flutter pub get
flutter run

xcrun simctl boot "iPhone 17 Pro"
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
flutter run
```

Atalho de desenvolvimento para abrir uma tela direto:

```bash
flutter run --dart-define=START=causes
```

Valores: `intro`, `verified`, `goal`, `location`, `located`, `help`, `causes`,
`notifications`, `account`, `create`, `login`, `home`. Sem `START`, abre na capa.

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
docs/BACKEND.md  passagem para o back-end
```

## Ainda simulado (sem back-end)

Os dados vivem em memória (`lib/data/store.dart`) e somem ao fechar o app.
Conta, login, SMS, avisos e respostas das instituições são simulados. O que
falta e como encaixar o servidor está em [`docs/BACKEND.md`](docs/BACKEND.md).
