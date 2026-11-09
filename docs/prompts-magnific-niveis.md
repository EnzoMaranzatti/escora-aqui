# Prompts do Magnific — medalhas dos níveis

Quatro ilustrações, uma por nível: **Bronze, Prata, Ouro e Doador Black**.
Estilo tirado da referência: 3D de argila macia (soft clay), cantos
arredondados, fita dobrada em cima, estrela de quatro pontas gravada no
centro, objeto único isolado em fundo branco.

**Configuração sugerida no Magnific**
- Modelo: `imagen-nano-banana-2-1` (o mesmo das fotos dos parceiros)
- Proporção: **1:1** (quadrado — a medalha é um ícone, não uma foto)
- **Bronze e Prata** saem da mesma base (argila fosca): gerar o Bronze
  primeiro e usar a imagem dele como *referência de estilo* no Prata,
  trocando só as palavras de cor.
- **Ouro e Black têm prompt próprio** (metal polido e cristal). Não usar o
  Bronze como referência neles — é justamente o que faz o ouro sair fosco.
  A silhueta repetida já segura a família.

---

## Base do estilo (vale para as quatro)

```
Ultra-detailed 3D rendered achievement medal, soft matte clay material with
subtle glossy highlights, rounded friendly shapes, circular medal hanging from
a short folded fabric ribbon at the top, a four-pointed sparkle star embossed
in the center of the medal, soft inner bevel, smooth color gradient across the
surface, gentle ambient occlusion, soft diffused studio lighting, delicate drop
shadow, isolated single object, centered composition, pure white background,
premium mobile app reward badge, playful and warm, octane render, 8K, ultra
detailed, no text, no letters, no numbers, no watermark
```

---

## 1. Bronze

```
[base do estilo] + warm terracotta and burnt copper color palette, medal body
in soft terracotta (#CF6E4B) blending into deep burnt copper (#7D3722), pale
cream ribbon (#F5DCD0), soft peach highlights
```

## 2. Prata

```
[base do estilo] + cool pearl silver and warm light grey palette, medal body in
soft pearl grey (#E2DDD6) blending into warm stone grey (#82796E), off-white
ribbon (#F8F6F3), delicate silver sheen
```

## 3. Ouro  ⚠️ não usa a base

O ouro **sai da base de propósito**: com "soft matte clay" ele vira um bronze
claro (foi o que aconteceu na primeira tentativa). Aqui a argila fosca dá
lugar a metal polido e a cor sobe de saturação — o ocre da marca (#DFB25A) é
dessaturado demais para ler como ouro sozinho.

A silhueta é a mesma das outras (medalha redonda, fita dobrada, estrela de
quatro pontas), então continua sendo a mesma família. O que muda é o
material, e essa diferença é a hierarquia: **argila fosca → metal polido →
cristal**.

### Opção A — metal polido (segura)

```
Ultra-detailed 3D rendered achievement medal, polished metallic gold with
mirror-like specular highlights and warm reflections, rounded friendly shapes,
circular medal hanging from a short folded satin ribbon at the top, a
four-pointed sparkle star embossed in the center, bright saturated yellow gold
(#FFD24A) on the raised surfaces falling to rich amber (#E8941A) in the
recesses, polished bevelled rim catching a bright rim light, deep cream satin
ribbon (#F5E6C2) with a soft sheen, dramatic studio lighting with a key light
from the upper left, soft reflected bounce, delicate drop shadow, isolated
single object, centered composition, pure white background, premium mobile app
reward badge, octane render, 8K, ultra detailed, no text, no letters, no
numbers, no watermark
```

### Opção B — metal polido com brilho (a mais chamativa)

Mesma coisa da A, mais o fim:

```
… plus small white star-shaped sparkle glints floating around the medal, a
subtle warm golden glow radiating behind it, lens-flare highlight on the
polished rim, radiant and celebratory
```

Gerar a **A primeiro**. Se ainda ficar perto do prata, ir para a B.

## 4. Doador Black  ⚠️ não usa a base

O Black é o topo: fecha a escada **argila fosca → metal polido → cristal**.
Vale usar a referência do crachá de cristal (aquela do "TOP RATED") como
inspiração de material.

```
Ultra-detailed 3D rendered achievement medal, polished dark metal and faceted
translucent crystal, circular medal hanging from a short folded satin ribbon,
a four-pointed sparkle star in polished gold embedded in the center, deep
petrol teal and graphite palette, medal body in dark
petrol (#143E42) blending into near-black graphite (#0E2D30), thin
mirror-polished golden rim (#FFD24A) catching the light, dark teal satin
ribbon (#194F54), subtle internal refractions and rainbow caustics in the
crystal, dramatic studio lighting, isolated single object, centered
composition, pure white background, elegant and premium, octane render, 8K,
ultra detailed, no text, no letters, no numbers, no watermark
```

---

## Depois de gerar

1. Baixar as quatro em PNG.
2. Salvar em `assets/images/levels/` como `bronze.png`, `prata.png`,
   `ouro.png`, `black.png`.
3. Declarar a pasta no `pubspec.yaml` (em `assets:`).
4. Trocar o ícone Phosphor (`medal` / `crown`) pela imagem no
   `_LevelBadge` do `points_screen.dart` e na comemoração do
   `level_up_sheet.dart`.

> As fotos dos 8 parceiros geradas em 04/11 continuam na conta do Magnific
> sem terem sido baixadas — vale baixar tudo na mesma sessão.
