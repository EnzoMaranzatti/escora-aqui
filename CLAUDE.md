# Escora aqui

App Flutter (iOS e Android) de pontos de apoio verificados perto da pessoa.
Projeto escolar. **Sempre responda em português.**

- **Front-end e back-end prontos (fases 1 a 8).** As telas leem `lib/data/store.dart` (um `AppStore` global chamado `store`). Cada ação do store atualiza a tela na hora, grava pelo `lib/data/remote.dart` e recarrega do banco. Conta e login ficam em `lib/data/auth.dart`.
- **Regras de negócio no banco:** funções e gatilhos em `supabase/migrations/`. Leia `docs/BACKEND.md` antes de mudar uma regra. Migração já enviada (`supabase db push`) não se edita: crie outra.
- **Só serviços gratuitos.** Mapa no OpenFreeMap; BrasilAPI, ViaCEP e IBGE sem chave. Não introduza APIs pagas sem perguntar.

## Convenções

- **Identidade visual:** `style-guide.md` (cores, tipografia, fotografia, motion). Estratégia e tom de voz: `brand-strategy.md`. Textos do onboarding: `copy-onbording.md`.
- **Navegação:** sempre `context.push(...)` / `context.replaceAll(...)` de `lib/core/routes.dart` (`EscoraRoute`, com transição própria e deslizar para voltar).
- **Ícones:** `lib/core/icons.dart` tem só os glifos Phosphor usados (as fontes inteiras estão em `assets/fonts/`). O pacote `phosphor_flutter` não compila nesta versão do Flutter, e o Font Awesome também não (o `FaIconData` deixou de ser um `IconData`; no plano gratuito, só 169 ícones têm contorno). Os três pesos usam **o mesmo codepoint** (só muda a família da fonte), então dá para pedir outro peso de um glifo já declarado com `.bold`/`.fill` — a regra de peso está no topo de `icons.dart`. Para um ícone novo: `flutter pub add phosphor_flutter:2.1.0`, pegue o codepoint em `~/.pub-cache/hosted/pub.dev/phosphor_flutter-2.1.0/lib/src/phosphor_icons_regular.dart` (ou `_fill`) e `flutter pub remove phosphor_flutter`.
- **Componentes:** ficam em `lib/core/widgets/` (`kit.dart`, `scaffolds.dart`, `sheets.dart`). Reutilize antes de criar.
- **Antes de entregar:** `flutter analyze` precisa ficar limpo.

## Rodar

```bash
flutter run --dart-define-from-file=env.json                              # capa (ou mapa, se já entrou)
flutter run --dart-define-from-file=env.json --dart-define=START=inst     # modo instituição (conta com ponto)
flutter run --dart-define-from-file=env.json --dart-define=START=team     # painel da equipe (conta da equipe)
```

Depois de rodar com `START=...` no simulador, reinstale a versão normal
(`flutter run` sem `START`). Senão o app abre sempre naquela tela.
