# Copy do onboarding — Escora aqui

Base: Estratégia de marca — Escora aqui · Tom herdado da estratégia · Oct 5, 2026

## Visão geral

**Objetivo:** levar a pessoa do primeiro contato até o mapa já filtrado com o que ela quer ajudar, mostrando valor antes de pedir qualquer dado.

**Público neste momento:** novo usuário (doador ou voluntário), no primeiro uso.

&#91;embedded content: fluxo de onboarding · 10 passos, cadastro no fim\]

Os passos 1 a 3 apresentam o app e podem ser pulados (o "Pular" leva direto ao passo 4). A cidade é obrigatória, porque sem ela não existe mapa. A conta só é pedida no passo 8, quando a pessoa já viu o mapa reagir às escolhas dela.

**Regras gerais do fluxo:**

- **Progresso:** os passos 1 a 3 usam indicador de pontos. Os passos 4 a 8 mostram "Passo X de 5" (o passo 4 é "Passo 1 de 5" e o passo 8, "Passo 5 de 5").
- **Voltar:** disponível a partir do passo 2, sempre com o rótulo "Voltar".
- **Escolhas antes da conta:** ficam guardadas no aparelho e são salvas na conta quando ela é criada. Se a pessoa fechar o app, o onboarding recomeça do passo onde parou.
- **Variáveis:** textos entre chaves, como {n} e {cidade}, são preenchidos pelo app.
- **Exemplos:** instituições, valores e datas que aparecem nas telas são fictícios, como pede o briefing.

## Fluxo: onboarding do doador

### Passo 0 — Abertura

- **Objetivo do passo:** apresentar a marca enquanto o app carrega.
- **Interação:** pontos de apoio (fotos em círculo) chegam ao redor da marca, como na referência de órbita.
- **Marca:** Escora aqui
- **Descritor:** Ajuda verificada perto de você.
- **Botões:** nenhum.
- **Regra de transição:** avança sozinho para o passo 1 em cerca de 2 segundos, ou ao toque na tela.

### Passo 1 — Boas-vindas

- **Objetivo do passo:** entregar a mensagem-mestra.
- **Interação:** o mapa aparece ao fundo, e os pins surgem um a um.
- **Título:** Veja quem precisa de ajuda perto de você.
- **Descrição:** Instituições de Rio Preto e região mostram o que falta agora, e por quê.
- **Botão primário:** Continuar
- **Botão secundário:** Pular
- **Regra de transição:** "Continuar" vai ao passo 2; "Pular" vai ao passo 4.

### Passo 2 — Verificado

- **Objetivo do passo:** mostrar por que dá para confiar nos pontos (pilar 1).
- **Interação:** um card de instituição fictícia recebe o selo de verificado.
- **Título:** Todo ponto no mapa foi verificado.
- **Descrição:** Antes de aparecer aqui, cada instituição passa por análise: CNPJ, endereço e foto do local.
- **Selo no card:** Verificado em 12/09
- **Botão primário:** Continuar
- **Botão secundário:** Pular
- **Regra de transição:** "Continuar" vai ao passo 3; "Pular" vai ao passo 4.

### Passo 3 — Com motivo

- **Objetivo do passo:** explicar a meta com motivo e o Pix direto (pilares 2 e 4).
- **Interação:** a barra de progresso de uma meta fictícia preenche até cerca de 60%.
- **Título:** Toda meta tem um motivo.
- **Descrição:** Você vê quanto falta, até quando e para quê. E o Pix vai direto para a instituição, sem taxa.
- **Card de exemplo:**
  - **Instituição:** Casa Exemplo
  - **Meta:** 40 cobertores até 30/06
  - **Motivo:** a frente fria aumentou o número de acolhidos.
  - **Progresso:** 24 de 40
- **Botão primário:** Continuar
- **Botão secundário:** Pular
- **Regra de transição:** os dois botões levam ao passo 4.

### Passo 4 — Sua cidade

- **Objetivo do passo:** definir onde o mapa vai abrir (pilar 3).
- **Progresso:** Passo 1 de 5
- **Título:** Onde você está?
- **Descrição:** Usamos sua localização só para mostrar os pontos mais perto. Você pode trocar a cidade quando quiser.
- **Botão primário:** Usar minha localização
- **Botão secundário:** Escolher cidade
- **Campo (ao tocar em "Escolher cidade"):**
  - **Label:** Cidade
  - **Placeholder:** Digite o nome da cidade
  - **Ajuda:** Por enquanto, o Escora aqui funciona em São José do Rio Preto e região.
  - **Botão:** Confirmar cidade
- **Interação:** quando a cidade é definida, o mapa centraliza nela e os pins aparecem, ainda em cinza.
- **Contador sobre o mapa:** {n} pontos de apoio em {cidade}
- **Regra de transição:** a localização liberada ou uma cidade da região confirmada leva ao passo 5. Permissão negada abre a busca de cidade. Cidade fora da região mostra o estado "Cidade fora da região". Não há "Pular".

### Passo 5 — Como você quer ajudar

- **Objetivo do passo:** escolher as formas de ajuda (pilar 4). É o momento "o mapa reage".
- **Progresso:** Passo 2 de 5
- **Título:** Como você quer ajudar?
- **Descrição:** Escolha uma ou mais. Dá para mudar depois.
- **Opções (seleção múltipla):**
  - **Pix:** Doe qualquer valor direto para a instituição, sem taxa.
  - **Itens:** Leve alimentos, roupas ou outros itens até o ponto.
  - **Voluntariado:** Doe seu tempo em ações com dia e hora marcados.
- **Interação:** ao tocar numa opção, os pins daquele tipo acendem na cor dele, e o contador atualiza na hora.
- **Contador sobre o mapa:** {n} pontos precisam disso perto de você
- **Botão primário:** Continuar
- **Botão secundário:** Voltar
- **Regra de transição:** "Continuar" só fica ativo com pelo menos uma opção marcada.

### Passo 6 — Causas

- **Objetivo do passo:** escolher as causas, que alimentam o filtro do mapa e os avisos.
- **Progresso:** Passo 3 de 5
- **Título:** O que mais te move?
- **Descrição:** Escolha as causas que você quer acompanhar.
- **Opções (pílulas, seleção múltipla):** Alimentos · Roupas e agasalhos · Higiene e limpeza · Material escolar · Crianças · Idosos · Pessoas em situação de rua · Animais · Saúde · Educação
- **Interação:** a cada pílula marcada, o contador atualiza ao vivo.
- **Contador:** {n} metas abertas nessas causas perto de você
- **Botão primário:** Continuar
- **Botão secundário:** Pular
- **Regra de transição:** os dois botões levam ao passo 7. Sem causa escolhida, o mapa mostra todas.

### Passo 7 — Avisos

- **Objetivo do passo:** pedir a permissão de notificações, mostrando o ganho antes.
- **Progresso:** Passo 4 de 5
- **Título:** Quer saber quando surgir uma meta nova?
- **Descrição (com causas escolhidas):** Avisamos quando uma instituição perto de você abrir uma meta nas causas que você escolheu.
- **Descrição (sem causas):** Avisamos quando uma instituição perto de você abrir uma meta nova.
- **Prévia de notificação (exemplo fictício):**
  - **Título:** Casa Exemplo abriu uma meta
  - **Texto:** 30 kg de arroz até sexta. Motivo: aumentou o número de famílias atendidas.
- **Botão primário:** Ativar avisos
- **Botão secundário:** Agora não
- **Regra de transição:** "Ativar avisos" abre o pedido de permissão do sistema e, em seguida, vai ao passo 8. "Agora não" vai direto ao passo 8.

### Passo 8 — Criar conta

- **Objetivo do passo:** criar a conta e salvar as escolhas feitas.
- **Progresso:** Passo 5 de 5
- **Título:** Salve suas escolhas.
- **Descrição:** Crie sua conta para guardar sua cidade, suas causas e seus avisos.
- **Botão social:** Continuar com Google
- **Separador:** ou
- **Campos:**

| Campo | Label | Placeholder | Ajuda | Erro |
| --- | --- | --- | --- | --- |
| Nome | Nome | Como podemos te chamar? | — | Digite seu nome. |
| E-mail | E-mail | seu@email.com | — | Confira o e-mail: ele precisa ter o formato nome@exemplo.com. |
| Senha | Senha | Crie uma senha | Mínimo de 8 caracteres, com pelo menos um número. *(sempre visível, antes de qualquer erro)* | A senha precisa ter pelo menos 8 caracteres e um número. |

- **Aviso legal:** Ao criar a conta, você concorda com os Termos de uso e a Política de privacidade.
- **Botão primário:** Criar conta
- **Botão secundário:** Voltar
- **Link:** Já tem conta? Entrar
- **Carregando:** Criando sua conta…
- **Erro — e-mail já cadastrado:** Este e-mail já tem uma conta. *(ação: Entrar com este e-mail)*
- **Erro — falha no Google:** Não conseguimos entrar com o Google. Tente de novo ou use seu e-mail.
- **Regra de transição:** a conta criada salva as escolhas e leva ao passo 9. Se a pessoa cancelar a janela do Google, ela volta para esta tela sem mensagem de erro.

### Passo 9 — Chegada

- **Objetivo do passo:** entregar o mapa já personalizado e ensinar o próximo gesto.
- **Interação:** o mapa abre filtrado pelas formas de ajuda e causas escolhidas, com os pins nas cores de cada tipo.
- **Mensagem de boas-vindas (banner):** Pronto, {nome}. Estes são os pontos que precisam do que você escolheu.
- **Dica única (sobre um pin):** Toque num ponto para ver o que ele precisa e por quê.
- **Botão da dica:** Entendi
- **Regra de transição:** a dica aparece só uma vez. Depois dela, o onboarding termina e o app segue no mapa.

## Estados

### Tela: Sua cidade (passo 4)

**Permissão de localização negada**

- **Título:** Tudo bem, escolha sua cidade.
- **Descrição:** Você pode liberar a localização depois, nas configurações do celular.
- **Ação primária:** Escolher cidade
- **Regra de exibição:** aparece quando a pessoa nega o pedido de localização do sistema.

**Localização indisponível**

- **Título:** Não encontramos sua localização agora.
- **Descrição:** Escolha sua cidade na lista para continuar.
- **Ação primária:** Escolher cidade
- **Ação secundária:** Tentar de novo
- **Regra de exibição:** aparece quando a permissão existe, mas o GPS não responde em cerca de 10 segundos.

**Cidade fora da região**

- **Título:** Ainda não chegamos em {cidade}.
- **Descrição:** Por enquanto, o Escora aqui funciona em São José do Rio Preto e região. Quer conhecer o mapa de Rio Preto?
- **Ação primária:** Ver Rio Preto
- **Ação secundária:** Escolher outra cidade
- **Regra de exibição:** aparece quando a localização ou a cidade escolhida está fora da região piloto.

**Busca sem resultado**

- **Texto:** Não encontramos "{busca}". Confira o nome da cidade.
- **Regra de exibição:** aparece abaixo do campo quando a busca não encontra nenhuma cidade.

**Carregando o mapa**

- **Texto:** Buscando pontos perto de você…
- **Regra de exibição:** aparece se o mapa levar mais de 1 segundo para carregar.

### Telas: Como ajudar e Causas (passos 5 e 6)

**Nenhum ponto para a escolha**

- **Texto no lugar do contador:** Ainda não há pontos com isso perto de você. Você pode manter a escolha e ser avisado quando surgir.
- **Regra de exibição:** aparece quando o contador chega a zero para a combinação marcada. A escolha continua válida e não bloqueia o avanço.

### Tela: Avisos (passo 7)

**Notificações negadas no sistema**

- **Texto (aviso curto):** Sem problema. Você pode ativar os avisos depois, no seu perfil.
- **Regra de exibição:** aparece por cerca de 3 segundos quando a pessoa nega a permissão do sistema. Depois, segue para o passo 8.

### Todas as telas

**Sem internet**

- **Título:** Você está sem internet.
- **Descrição:** Suas escolhas continuam guardadas. Quando a conexão voltar, seguimos daqui.
- **Ação primária:** Tentar de novo
- **Regra de exibição:** aparece quando uma ação que depende de rede (carregar o mapa ou criar a conta) falha por falta de conexão.

## Mapa estratégico

| Momento-âncora | Mensagem-chave | Implicação atendida |
| --- | --- | --- |
| Passo 0 · Abertura | Descritor: ajuda verificada perto de você | O nome precisa de descritor (risco do nome) |
| Passo 1 · Boas-vindas | Mensagem-mestra: o que falta agora, e por quê, perto de você | Linguagem de proximidade |
| Passo 2 · Verificado | Todo ponto no mapa foi verificado | Selo com data e critérios em uma frase |
| Passo 3 · Com motivo | Toda meta tem um motivo; Pix direto, sem taxa | Fórmula quantidade + prazo + motivo; dizer "sem taxa" explicitamente |
| Passos 5 e 6 | O que falta perto de você, agora | O mapa reage; o contador usa linguagem de proximidade |
| Passo 7 · Avisos | O que falta perto de você, agora | Prévia de aviso segue a fórmula da meta |
| Passo 8 · Conta | — (operacional) | Frases curtas, sem burocratês |
| Demo no balcão | — | Uma decisão por tela; fluxo inteiro em menos de 2 minutos |

## Scorecard

| Critério | Nota |
| --- | --- |
| Aderência ao tom | 9 |
| Clareza operacional | 9 |
| Ação verbal | 9 |
| Ausência de jargão | 10 |
| Honestidade | 9 |
| Especificidade | 9 |
| Obediência à estratégia (zero vocabulário proibido) | 9 |

**Média: 9,1. Aprovado na 1ª iteração.**

## Nota de decisões

- **Conta no fim:** a pessoa vê o mapa reagir antes de entregar qualquer dado. Pedir cadastro antes de mostrar valor é onde mais gente desiste.
- **"Usar minha localização" em vez de "Permitir":** o verbo diz o que acontece, e a descrição antecipa por que o app precisa disso.
- **"Ativar avisos" / "Agora não":** "agora não" deixa claro que dá para mudar depois, sem culpa.
- **"Salve suas escolhas" como título do cadastro:** o cadastro vira consequência do que a pessoa já fez, e não uma barreira.
- **Regra de senha visível antes do erro**, como pede o padrão de cadastro.
- **"Verificado" sem prometer garantia:** o passo 2 diz exatamente o que é checado (CNPJ, endereço e foto), seguindo o princípio "honesto sobre o que garante".
- **Exclamações:** nenhuma. "Pronto, {nome}." substitui comemorações, alinhado ao motion sem confete.

## Pendências

- [ ] Definir a lista de cidades da região piloto (por exemplo: São José do Rio Preto, Mirassol, Bady Bassitt, Cedral)
- [ ] Validar a lista final de causas com o Diego (ela também vira filtro no banco de dados)
- [ ] Escrever os Termos de uso e a Política de privacidade, ou usar um modelo simples para a demo
- [ ] Copy do fluxo "Entrar" e da recuperação de senha (fora do escopo desta rodada)
- [ ] Confirmar o descritor "Ajuda verificada perto de você"

## Próximos passos

Esta copy alimenta a etapa de **estrutura** (organização das telas, grid e espaçamento) e depois o **design** das telas, sempre aplicando a direção visual.
