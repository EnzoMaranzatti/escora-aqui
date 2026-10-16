# Direção visual — Escora aqui

Base: Estratégia de marca — Escora aqui · Modo claro · Oct 5, 2026

## Conceito visual

**Direção: Apoio firme.** Palavras-guia: firme, claro, morno, próximo, verificável.

A marca se veste como algo em que dá para se apoiar. Tem a solidez e a ordem de uma instituição séria (o lado Governante), com a temperatura de quem está perto (o lado Cuidador). A confiança não vem de brasões, carimbos ou azul de repartição, e sim da clareza: informação bem organizada, contraste forte e cores que parecem da terra, não do órgão público. O calor aparece em doses medidas, nunca como apelo emocional.

| Eixo | Posição | Por quê |
| --- | --- | --- |
| Quente ↔ frio | Morno, levemente quente | Acolhedor 6/10. Frio puxa para o governo; muito quente puxa para o apelo |
| Orgânico ↔ geométrico | Geométrico com cantos suaves | Ordem do Governante suavizada pelo Cuidador |
| Denso ↔ arejado | Arejado | Claro 9/10 e leitura à distância no balcão |
| Clássico ↔ contemporâneo | Contemporâneo | O clássico aproxima do institucional vetado |
| Sóbrio ↔ expressivo | Sóbrio, com um acento expressivo | Emotivo 2/10, mas o acento evita o "sério demais" |

**Escopo:** este guia cobre o modo claro. O modo escuro fica como evolução futura.

## Sistema de cor

### Cores de marca e proporção

Proporção de uso: **60% cinzas mornos** (fundos e superfícies), **30% petróleo** (estrutura, ações e marca) e **10% terracota** (acento). O ocre aparece de forma pontual.

| Cor | Base | Papel |
| --- | --- | --- |
| Petróleo (primária) | `#1F6268` (600) | Confiança e estabilidade sem azul-governo. Botões principais, selo de verificação, barra de progresso, links. Tipo de ajuda: **Pix** |
| Terracota (acento) | `#9C4529` (600) | Calor e proximidade, a terra do interior. Destaques pontuais e meta perto do prazo. Tipo de ajuda: **itens** |
| Ocre (apoio) | `#8F641B` (600) | Tipo de ajuda: **voluntariado**. Também serve de base para o alerta |
| Cinza morno | `#F8F6F3` (50) a `#221F1B` (900) | Fundos, texto e divisores. Tira a frieza institucional |

### Escalas 50–900

| Degrau | Petróleo | Terracota | Ocre | Cinza morno |
| --- | --- | --- | --- | --- |
| 50 | `#EEF6F6` | `#FBF1EC` | `#FBF5E6` | `#F8F6F3` |
| 100 | `#D5E9EA` | `#F5DCD0` | `#F5E6C2` | `#EFECE7` |
| 200 | `#ABD2D4` | `#EBB9A2` | `#EBCD8A` | `#E2DDD6` |
| 300 | `#7BB5B9` | `#DE9273` | `#DFB25A` | `#CBC4BA` |
| 400 | `#4C9499` | `#CF6E4B` | `#CF9836` | `#A69E93` |
| 500 | `#2B777D` | `#B95634` | `#B07D22` | `#82796E` |
| 600 | `#1F6268` | `#9C4529` | `#8F641B` | `#655D54` |
| 700 | `#194F54` | `#7D3722` | `#704E16` | `#4D4740` |
| 800 | `#143E42` | `#5F2A1B` | `#533A12` | `#36312C` |
| 900 | `#0E2D30` | `#421D13` | `#3A280D` | `#221F1B` |

**Usos típicos dos degraus:**

- **50–100:** fundos suaves de chips, banners e cards destacados.
- **200–300:** bordas de destaque, trilho da barra de progresso e estados selecionados leves.
- **500:** ícones, anel de foco e elementos de interface com contraste mínimo de 3:1.
- **600:** cor-base das ações e dos pins.
- **700–800:** hover e pressed, e texto colorido sobre fundos claros.
- **900:** uso raro, só para texto em fundo 50 da mesma cor.

### Cinzas: undertone morno (decisão de marca)

O cinza tem undertone **morno**, puxado para o bege e a pedra, e não neutro nem frio. *Por quê:* o cinza frio é o que mais deixa um app com cara de sistema público. O morno mantém a seriedade e adiciona a temperatura do Cuidador sem precisar de cor.

| Cinza | Uso |
| --- | --- |
| 50 | Fundo do app |
| Branco `#FFFFFF` | Cards e superfícies sobre o fundo 50 |
| 100 | Fundo de campos e áreas agrupadas |
| 200 | Divisores, bordas decorativas e fundo de botão desabilitado |
| 300 | Trilho de barra e skeleton de carregamento |
| 500 | Borda de campos de formulário, ícones inativos e texto desabilitado |
| 600 | Texto secundário |
| 700 | Texto de apoio enfático |
| 900 | Texto principal |

### Semânticas

| Estado | Texto | Fundo suave | Base (ícone/botão) |
| --- | --- | --- | --- |
| Sucesso | `#24633C` | `#EAF4EC` | `#2F7A4B` |
| Erro | `#A3231B` | `#FCECEA` | `#B3261E` |
| Alerta | Ocre 800 `#533A12` | Ocre 50 `#FBF5E6` | Ocre 600 |
| Info | Petróleo 800 `#143E42` | Petróleo 50 `#EEF6F6` | Petróleo 600 |

O erro é um vermelho carmim, propositalmente distante da terracota. **A terracota nunca comunica erro.**

### Regra de estados

- **Hover / foco visual:** degrau +100 (por exemplo, 600 → 700).
- **Pressed:** degrau +200 (600 → 800).
- **Disabled:** fundo cinza 200 com texto cinza 500, sem sombra.
- **Foco de teclado / acessibilidade:** anel de 2px em petróleo 500, afastado 2px do elemento.
- **Selecionado:** fundo 50 da cor, com borda ou ícone em 600.

### Pares de contraste validados (WCAG)

| Texto / fundo | Razão | Selo | Uso |
| --- | --- | --- | --- |
| Cinza 900 / cinza 50 | 15,2:1 | AAA | Texto principal |
| Cinza 900 / branco | 16,4:1 | AAA | Texto em cards |
| Cinza 700 / cinza 50 | 8,5:1 | AAA | Texto de apoio |
| Cinza 600 / cinza 50 | 6,0:1 | AA | Texto secundário |
| Cinza 600 / branco | 6,5:1 | AA | Texto secundário em card |
| Branco / petróleo 600 | 7,0:1 | AAA | Botão principal |
| Branco / petróleo 700 | 9,2:1 | AAA | Botão em hover |
| Petróleo 700 / cinza 50 | 8,5:1 | AAA | Links |
| Petróleo 600 / branco | 7,0:1 | AAA | Texto e ícone de marca em card |
| Petróleo 800 / petróleo 50 | 10,7:1 | AAA | Info e selo |
| Branco / terracota 600 | 6,4:1 | AA | Botão ou chip de acento |
| Terracota 600 / cinza 50 | 5,9:1 | AA | Texto de destaque |
| Terracota 700 / terracota 50 | 7,7:1 | AAA | Chip de itens |
| Branco / ocre 600 | 5,2:1 | AA | Pin de voluntariado |
| Ocre 800 / ocre 50 | 9,7:1 | AAA | Alerta e chip de voluntariado |
| Sucesso texto / fundo | 6,4:1 | AA | Mensagem de sucesso |
| Erro texto / fundo | 6,5:1 | AA | Mensagem de erro |
| Branco / erro base | 6,5:1 | AA | Botão destrutivo |

**Para elementos de interface (mínimo 3:1):** cinza 500 sobre cinza 50 tem 4,0:1 e serve para bordas de campo e ícones. Petróleo 500 sobre cinza 50 tem 4,8:1 e serve para o anel de foco.

**Pares reprovados, fora do sistema de texto:** cinza 500 sobre cinza 50 como texto comum (4,0:1) e cinza 400 sobre cinza 50 (2,5:1). O cinza 400 serve apenas para elementos decorativos.

## Sistema tipográfico

Todas as fontes são do Google Fonts e funcionam no Flutter pelo pacote `google_fonts` ou embutidas nos assets.

| Papel | Recomendada | Alternativas | Por quê |
| --- | --- | --- | --- |
| Títulos, botões e números de destaque | **Plus Jakarta Sans** | Manrope, Figtree | Geométrica contemporânea com cantos suaves: firme sem ser dura, próxima sem ser fofa. Traz a ordem do Governante com o calor do Cuidador |
| Corpo e interface | **Source Sans 3** | Atkinson Hyperlegible, IBM Plex Sans | Humanista, de letras abertas e ótima leitura em tela pequena. Tem algarismos tabulares, essenciais para valores e metas |
| Fallback de sistema | Roboto (Android) / SF Pro (iOS) | — | Padrão das plataformas |

### Escala (base 16, razão aproximada 1,2)

Valores em pixels lógicos do Flutter.

| Nível | Fonte | Tamanho / altura de linha | Peso | Espaçamento entre letras |
| --- | --- | --- | --- | --- |
| Display | Jakarta | 34 / 40 | 700 | −0,5 |
| H1 | Jakarta | 28 / 34 | 700 | −0,3 |
| H2 | Jakarta | 24 / 30 | 700 | −0,2 |
| H3 | Jakarta | 20 / 26 | 600 | −0,1 |
| H4 | Jakarta | 17 / 22 | 600 | 0 |
| Body-lg | Source Sans 3 | 18 / 26 | 400 | 0 |
| Body | Source Sans 3 | 16 / 24 | 400 | 0 |
| Body-sm | Source Sans 3 | 14 / 20 | 400 | +0,1 |
| Label (botões, abas) | Jakarta | 16 / 20 | 600 | +0,1 |
| Caption | Source Sans 3 | 13 / 18 | 400 | +0,2 |
| Overline | Jakarta | 12 / 16 | 600, caixa alta | +0,8 |
| Número de meta | Jakarta, algarismos tabulares | 28 / 32 | 700 | −0,3 |

### Regras de uso

- **Pareamento:** Jakarta em títulos, botões e números; Source Sans 3 em todo o texto corrido e na interface. Nunca usar Jakarta em parágrafos.
- **Pesos permitidos:** Jakarta 600 e 700; Source Sans 3 400 e 600 (o 600 só para ênfase dentro do corpo). Nada de pesos finos (300 ou menos), que somem no balcão.
- **Valores em reais e metas:** sempre com algarismos tabulares (`FontFeature.tabularFigures()` no Flutter), para que os números não "dancem" quando a barra de progresso atualiza.
- **Itálico:** não é usado na interface. **Caixa alta:** só no overline, nunca em botões ou títulos.
- **Comprimento de linha:** até cerca de 60 caracteres em textos de explicação, como o motivo da meta.
- **Mínimos:** nenhuma informação essencial abaixo de 13px; o display nunca abaixo de 28px.

## Identidade aplicada

### Logo

Ainda não existe; é uma pendência do Enzo como designer. Princípios para quando ela for criada:

- Um logotipo em Plus Jakarta Sans 700 (ou desenho próprio a partir dela) em petróleo 600, com um símbolo simples que funcione sozinho no ícone do app.
- O símbolo pode explorar a ideia de **apoio e escora**: algo que sustenta e se inclina, um ponto firme. Evitar mãos, corações, escudos e brasões.
- O ícone do app deve ser legível em 48px e funcionar em petróleo sobre branco ou em branco sobre petróleo.

### Superfícies

**Raios de canto**

| Token | Valor | Onde |
| --- | --- | --- |
| sm | 6 | Chips, tags e badges retangulares |
| md | 10 | Botões e campos de formulário |
| lg | 16 | Cards e cards flutuantes sobre o mapa |
| xl | 24 | Topo de bottom sheets |
| full | 999 | Pins, avatares e badges circulares |

**Elevação** (sombra com cinza 900 em baixa opacidade, nunca preto puro)

| Nível | Valor | Onde |
| --- | --- | --- |
| 0 | Sem sombra, borda de 1px em cinza 200 | Cards sobre o fundo do app |
| 1 | 0 1 2 / 8% | Botões elevados e chips selecionados |
| 2 | 0 4 12 / 10% | Cards flutuantes sobre o mapa |
| 3 | 0 12 32 / 14% | Bottom sheets e diálogos |

**Bordas:** 1px em cinza 200 nas bordas decorativas e 1px em cinza 500 nas bordas de campos, que precisam de 3:1. Em estado de foco, a borda do campo vira 2px em petróleo 600.

### Iconografia

- **Biblioteca:** Phosphor Icons (pacote `phosphor_flutter`), no peso **Regular** para estados normais e **Fill** para estados ativos e selecionados. Alternativa: Lucide.
- **Estilo:** traço de cerca de 1,5px com cantos arredondados, sobre grade de 24px. Tamanhos de 20px na interface e 24px na navegação.
- **Ícones-chave:** selo de verificação com o ícone de selo com check (SealCheck), em petróleo; Pix com o ícone de moedas (ou o símbolo oficial do Pix, respeitando as regras de uso dele); itens com o ícone de pacote (Package); voluntariado com o ícone de grupo de pessoas (UsersThree).
- **Regra:** nada de ícones de mãos segurando coração ou similares. Nunca misturar bibliotecas.

### Pins do mapa

Cada tipo de ajuda tem **cor + ícone**. A cor nunca carrega a informação sozinha, o que importa para pessoas com daltonismo.

| Tipo | Pin | Ícone (branco) |
| --- | --- | --- |
| Pix | Petróleo 600 | Moedas |
| Itens | Terracota 600 | Pacote |
| Voluntariado | Ocre 600 | Grupo de pessoas |
| Vários tipos | Petróleo 600 com contador | Número de tipos |

O pin selecionado cresce cerca de 20% e ganha sombra de nível 2. O selo de verificado aparece no card do ponto, não no pin, para não poluir o mapa (todos os pontos no mapa já são verificados).

**Estilo do mapa:** base clara e dessaturada, puxada para os cinzas mornos, sem as cores saturadas do mapa padrão. Os pins precisam ser o único elemento colorido forte da tela.

### Fotografia

- **Luz e temperatura:** luz natural, levemente quente, com cores reais e sem filtros pesados.
- **O que mostrar:** espaços (fachadas, salas, cozinhas comunitárias) e ações (organizar doações, montar cestas), em enquadramento médio ou aberto.
- **Pessoas:** em ação, de lado ou de costas; nunca close de sofrimento. Evitar crianças identificáveis.
- **Relação com a paleta:** nenhum overlay colorido nem duotone. A foto entra limpa, com raio lg, e a cor da marca fica na interface ao redor.
- **Para a demo:** como os dados são fictícios, as fotos podem ser de banco de imagens ou geradas, desde que sigam estas regras e não mostrem instituições reais reconhecíveis.

### Grafismos

Sem gradientes, texturas ou padrões. A identidade vem de cor, tipografia e ordem. *Exceção:* a barra de progresso da meta é o único elemento gráfico recorrente, com preenchimento sólido em petróleo 600 sobre trilho em cinza 200, altura de 8px e raio full.

### Motion

- **Firme e rápido:** transições entre 150 e 250ms. Nada demora.
- **Curva padrão:** ease-out (`Curves.easeOutCubic` no Flutter). Sem bounce nem elástico, que deixam a marca brincalhona demais.
- **O que anima:** a barra de progresso preenche uma vez ao entrar na tela (cerca de 600ms), o pin selecionado cresce, o bottom sheet sobe e as confirmações aparecem com fade e uma leve subida.
- **O que nunca anima:** confete, comemorações exageradas, loops chamativos ou textos piscando. A confirmação de doação é calma.

## Anti-padrões visuais

**Vetos do cliente:**

- **Cara de governo:** azul-marinho institucional, brasões, escudos, faixas, fontes como Arial ou Public Sans, layouts de formulário de repartição. *(veto do cliente)*
- **Sério demais:** interface toda em cinza e petróleo, sem nenhum acento quente, e excesso de texto. *(veto do cliente)*
- **Clichês:** mãos, corações, mãos dadas, "corrente do bem" e arco-íris. *(veto do cliente)*
- **Infantil:** cores saturadas, fontes arredondadas demais, ilustrações cartoon, mascotes e gamificação com medalhas. *(veto do cliente)*

**Armadilhas do segmento:**

- Fotos de sofrimento em close.
- Vermelho de urgência piscando.
- Confete ao doar.

**Usos proibidos do próprio sistema:**

- Terracota para comunicar erro.
- Cinza 400 ou 500 como texto comum.
- Ocre como texto pequeno sobre branco.
- Pins diferenciados só por cor.
- Petróleo 600 como fundo de blocos de texto longo.
- Mais de um acento quente na mesma tela.

## Rastreabilidade estratégica

| Implicação visual da estratégia | Como a direção atende |
| --- | --- |
| Selo de verificação sóbrio, nunca carimbo | Ícone de selo com check em petróleo, sobre fundo petróleo 50; sem brasão nem moldura |
| Barra de progresso central, sem gamificação | Barra sólida de 8px, número de meta em display tabular, sem medalhas |
| Mapa como herói; pins diferenciam tipo de ajuda | Mapa claro e dessaturado; pins em três cores, cada uma com ícone |
| Confirmação calma, sem confete | Motion com fade e leve subida; confete é anti-padrão |
| Fotografia real, sem close de sofrimento | Regras de fotografia: espaços e ações, luz natural |
| Fugir do azul-governo e dos saturados infantis | Petróleo + terracota + cinzas mornos |
| Tipografia legível e humana | Source Sans 3 (humanista) no corpo; mínimo de 13px |
| Hierarquia legível à distância (balcão) | Escala com display de 34, pesos firmes e contraste AAA no texto principal |
| Personalidade: confiável 9, acolhedor 6, emotivo 2 | Base sóbria e firme (petróleo, geometria) + calor dosado (cinza morno, terracota a 10%) |

## Scorecard

| Critério | Nota | Justificativa |
| --- | --- | --- |
| Coerência com a personalidade | 9 | Todos os sistemas expressam a ideia de cuidado por meio de ordem |
| Obediência aos vetos | 9 | Os quatro vetos foram tratados em cor, tipo, ícones, foto e motion |
| Diferenciação | 8 | Distante do azul institucional e dos clichês do setor; o território visual dos concorrentes não foi mapeado em detalhe |
| Acessibilidade | 9 | Todos os pares de texto recomendados passam AA, a maioria AAA; os pins não dependem só de cor |
| Completude para consumo | 8 | Tokens e regras prontos; a logo é pendência |

**Média: 8,6. Aprovado na 1ª iteração.**

## Nota de decisões

- **Petróleo em vez de azul:** mantém a confiança que o azul transmite, mas sai do território de órgão público.
- **Terracota como acento:** é o calor da terra do interior, usado a 10% para não virar apelo.
- **Cinza morno:** é a decisão que mais tira a cara de sistema, sem precisar de mais cor.
- **Duas fontes com papéis claros:** a Jakarta dá firmeza aos títulos e números; a Source Sans 3 dá leitura humana ao corpo.
- **Pins com cor e ícone:** acessibilidade e leitura rápida no mapa.
- **Modo claro apenas:** decisão de escopo do autor.

## Pendências

- [ ] Criar a logo e o ícone do app (Enzo), seguindo os princípios da seção Logo
- [ ] Escolher a camada de mapa clara e dessaturada compatível com o `flutter_map`
- [ ] Modo escuro, como evolução futura

## Próximos passos

Este guia alimenta a etapa de **copy-webapp** (o tom vem da estratégia), a de **estrutura** (telas, grid e espaçamento) e a de **design**.
