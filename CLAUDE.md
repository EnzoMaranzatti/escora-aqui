# Escora aqui

App Flutter (iOS e Android) de pontos de apoio verificados perto da pessoa.
Projeto escolar. **Sempre responda em português.**

- **Front-end:** pronto. Os dados ficam em memória: `lib/data/store.dart` (um `AppStore` global chamado `store`), mais `seed.dart` e `models.dart`.
- **Próximo passo é o back-end.** Leia `docs/BACKEND.md` antes de começar: entidades, ações, regras de negócio e o que está simulado.
- **Só serviços gratuitos.** Mapa no OpenFreeMap; BrasilAPI, ViaCEP e IBGE sem chave. Não introduza APIs pagas sem perguntar.

## Convenções

- **Identidade visual:** `style-guide.md` (cores, tipografia, fotografia, motion). Estratégia e tom de voz: `brand-strategy.md`. Textos do onboarding: `copy-onbording.md`.
- **Navegação:** sempre `context.push(...)` / `context.replaceAll(...)` de `lib/core/routes.dart` (`EscoraRoute`, com transição própria e deslizar para voltar).
- **Ícones:** `lib/core/icons.dart` tem só os glifos Phosphor usados. O pacote `phosphor_flutter` não compila nesta versão do Flutter. Para um ícone novo, pegue o codepoint em `~/.pub-cache/hosted/pub.dev/phosphor_flutter-2.1.0/lib/src/`.
- **Componentes:** ficam em `lib/core/widgets/` (`kit.dart`, `scaffolds.dart`, `sheets.dart`). Reutilize antes de criar.
- **Antes de entregar:** `flutter analyze` precisa ficar limpo.

## Rodar

```bash
flutter run                              # capa
flutter run --dart-define=START=inst     # modo instituição (demo)
flutter run --dart-define=START=team     # painel da equipe
```

Depois de rodar com `START=...` no simulador, reinstale a versão normal
(`flutter run` sem `START`). Senão o app abre sempre naquela tela.
