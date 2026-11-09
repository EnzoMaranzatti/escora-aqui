-- Dados de apresentação da fase 9: parceiros, catálogo de cupons e pontos.
--
-- Rode DEPOIS da migração 20261103212526_fase9_bonificacao.sql e do
-- seed_apresentacao.sql, uma vez só, no SQL Editor do Supabase (cole tudo e
-- clique em Run). Se os parceiros já estiverem lá, o script para sem mudar
-- nada.
--
-- Tudo é fictício. Os parceiros ilustram a ideia do catálogo (empresa dá
-- cupom usando capacidade ociosa, em troca de divulgação); nenhuma parceria
-- existe de verdade, nem os códigos dos cupons valem em lugar nenhum.
--
-- Os pontos não são inventados: eles nascem das funções da fase 9 rodando
-- sobre as doações confirmadas que já estão no banco. O seed_apresentacao
-- rodou antes da fase 9 existir, então aquelas doações passaram sem pontuar;
-- aqui elas são reprocessadas pela mesma função que o gatilho chama.

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'points_profiles'
    ) THEN
        RAISE EXCEPTION 'Aplique a migração da fase 9 antes deste seed.';
    END IF;
    IF EXISTS (SELECT 1 FROM public.partners) THEN
        RAISE EXCEPTION 'Os dados de apresentação da fase 9 já estão no banco.';
    END IF;
END;
$$;

-- ── Parceiros ───────────────────────────────────────────────
-- Região de São José do Rio Preto, a mesma dos pontos do mapa. O Thermas dos
-- Laranjais (Olímpia, 50 km) é o exemplo que o professor usou para explicar a
-- ideia: ingresso em dia de baixa ocupação não custa caixa para o parque.

INSERT INTO public.partners (id, name) VALUES
    ('00000000-0000-4000-8000-000000000901', 'Thermas dos Laranjais'),
    ('00000000-0000-4000-8000-000000000902', 'Cine Jardim'),
    ('00000000-0000-4000-8000-000000000903', 'Padaria Pão da Praça'),
    ('00000000-0000-4000-8000-000000000904', 'Livraria Beira de Página'),
    ('00000000-0000-4000-8000-000000000905', 'Academia Movimenta'),
    ('00000000-0000-4000-8000-000000000906', 'Hortifruti Bom Campo');

-- ── Catálogo ────────────────────────────────────────────────
-- Custos calibrados para o saldo das contas de demonstração: alguns cupons
-- dão para trocar na hora, um está esgotado, um pede nível e um fica longe de
-- propósito, para a tela mostrar os quatro estados que ela sabe desenhar.

INSERT INTO public.catalog_items (id, partner_id, title, description, points_cost, min_level, stock) VALUES
    ('00000000-0000-4000-8000-000000000951', '00000000-0000-4000-8000-000000000903',
     'Café da manhã para dois',
     'Dois cafés, dois pães na chapa e um bolo do dia. Vale de segunda a sexta, até as 10h.',
     120, 'bronze', 20),

    ('00000000-0000-4000-8000-000000000952', '00000000-0000-4000-8000-000000000904',
     'R$ 30 em livros',
     'Desconto em qualquer título da loja, sem valor mínimo de compra.',
     150, 'bronze', 4),

    ('00000000-0000-4000-8000-000000000953', '00000000-0000-4000-8000-000000000906',
     'Cesta de frutas da semana',
     'Monte uma cesta de até 3 kg com as frutas da banca do dia.',
     180, 'prata', NULL),

    ('00000000-0000-4000-8000-000000000954', '00000000-0000-4000-8000-000000000902',
     'Dois ingressos de cinema',
     'Sessões de segunda a quinta, qualquer filme em cartaz. Pipoca não inclusa.',
     200, 'bronze', 3),

    ('00000000-0000-4000-8000-000000000955', '00000000-0000-4000-8000-000000000905',
     'Uma semana de academia',
     'Sete dias de acesso livre, com uma aula de avaliação física.',
     300, 'ouro', 10),

    ('00000000-0000-4000-8000-000000000956', '00000000-0000-4000-8000-000000000903',
     'Bolo de aniversário',
     'Bolo de 1,5 kg, sabor à escolha, encomendado com três dias de antecedência.',
     400, 'prata', 0),

    ('00000000-0000-4000-8000-000000000957', '00000000-0000-4000-8000-000000000901',
     'Ingresso do Thermas dos Laranjais',
     'Um ingresso de dia inteiro, de segunda a quinta, fora das férias escolares.',
     600, 'prata', 15),

    ('00000000-0000-4000-8000-000000000958', '00000000-0000-4000-8000-000000000901',
     'Dia no parque para a família',
     'Quatro ingressos de dia inteiro, com estacionamento e um almoço no parque.',
     2000, 'black', 5);

-- ── Pontos das doações que já estavam no banco ──────────────
-- O seed_apresentacao confirmou doações antes da fase 9 existir, então elas
-- nunca passaram pela função de pontos. Aqui cada uma é reprocessada pela
-- mesma função que o gatilho da fase 5 chama, na ordem em que foi confirmada.
-- O NOT EXISTS evita contar duas vezes se este seed rodar de novo.

DO $$
DECLARE d public.donations;
BEGIN
    FOR d IN
        SELECT * FROM public.donations
        WHERE status = 'confirmed'
          AND donor_id IS NOT NULL
          AND type IN ('pix', 'itens')
          AND NOT EXISTS (
              SELECT 1 FROM public.points_ledger l WHERE l.donation_id = donations.id
          )
        ORDER BY coalesce(confirmed_at, created_at)
    LOOP
        PERFORM public.register_qualifying_donation(d);
    END LOOP;
END;
$$;

-- ── Conta de doador de demonstração ─────────────────────────
-- A doador.teste@escoraaqui.app foi criada depois do seed_apresentacao, então
-- não pegou o histórico de doador. Quatro doações em quatro meses seguidos,
-- que é o que faz nascer a sequência mensal.
--
-- Três entram pela doação mensal (R$ 50 para o Lar Aurora): a check_new_donation
-- (fase 4) só aceita doação sem meta quando é Pix de uma doação mensal, e é
-- justamente a história que a sequência conta. A de itens precisa de meta, então
-- usa a ração do Amigos dos Bichos, que está em 26 de 80 kg: 6 kg não encostam
-- no alvo, e nenhuma barra do mapa muda de lugar.

-- Sem tabela temporária: o SQL Editor não garante que ela sobreviva de um
-- comando para o outro, então cada trecho procura a conta pelo e-mail.

INSERT INTO public.monthly_gifts (id, donor_id, place_id, amount, day, since, created_at)
SELECT '00000000-0000-4000-8000-000000000970', (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app'),
       '00000000-0000-4000-8000-000000000106', 50, 10,
       (current_date - interval '3 months')::date,
       now() - interval '3 months' - interval '3 days'
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'doador.teste@escoraaqui.app');

INSERT INTO public.donations
    (id, donor_id, place_id, goal_id, monthly_gift_id, type, amount, created_at)
SELECT d.id::uuid, (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app'),
       '00000000-0000-4000-8000-000000000106', NULL,
       '00000000-0000-4000-8000-000000000970', 'pix', 50, d.at
FROM (VALUES
    ('00000000-0000-4000-8000-000000000971', now() - interval '3 months' - interval '2 days'),
    ('00000000-0000-4000-8000-000000000973', now() - interval '1 month' - interval '1 day'),
    ('00000000-0000-4000-8000-000000000974', now() - interval '4 days')
) AS d (id, at)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'doador.teste@escoraaqui.app');

INSERT INTO public.donations
    (id, donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT '00000000-0000-4000-8000-000000000972', (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app'),
       '00000000-0000-4000-8000-000000000125',
       '00000000-0000-4000-8000-000000000229',
       'itens', 6, (current_date - interval '2 months')::date,
       now() - interval '2 months' - interval '4 days'
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'doador.teste@escoraaqui.app');

-- Confirmar dispara o gatilho da fase 5, que agora pontua.
UPDATE public.donations
SET status = 'confirmed', confirmed_at = created_at + interval '1 day'
WHERE id IN (
    '00000000-0000-4000-8000-000000000971', '00000000-0000-4000-8000-000000000972',
    '00000000-0000-4000-8000-000000000973', '00000000-0000-4000-8000-000000000974'
);

-- O gatilho da fase 5 criou um aviso "Sua doação foi confirmada" para cada
-- uma das quatro, todos com a hora de agora. Cada aviso volta para a data da
-- confirmação que o gerou, pareando os dois pela ordem.

WITH av AS (
    SELECT id, place_id,
           row_number() OVER (PARTITION BY place_id ORDER BY created_at, id) AS n
    FROM public.notices
    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app') AND kind = 'confirmed'
), dt AS (
    SELECT place_id, confirmed_at,
           row_number() OVER (PARTITION BY place_id ORDER BY confirmed_at) AS n
    FROM public.donations
    WHERE id IN (
        '00000000-0000-4000-8000-000000000971', '00000000-0000-4000-8000-000000000972',
        '00000000-0000-4000-8000-000000000973', '00000000-0000-4000-8000-000000000974'
    )
)
UPDATE public.notices n
SET created_at = dt.confirmed_at, read = dt.confirmed_at < now() - interval '15 days'
FROM av JOIN dt ON dt.place_id = av.place_id AND dt.n = av.n
WHERE n.id = av.id;

-- ── Sequência mensal ────────────────────────────────────────
-- A função usa now() para marcar o mês da doação, então reprocessar um
-- histórico antigo deixa todo mundo com sequência de 1 mês. Aqui a sequência
-- é recalculada a partir das datas de verdade: meses seguidos com doação
-- confirmada, terminando no mês da última. O bônus de 10% por mês entra pela
-- própria award_points, para o extrato ficar igual ao de uma sequência viva.

DO $$
DECLARE
    r      record;
    meses  date[];
    streak int;
    i      int;
    base   int;
    bonus  int;
BEGIN
    FOR r IN
        SELECT donor_id,
               array_agg(DISTINCT date_trunc('month', coalesce(confirmed_at, created_at)
                                             AT TIME ZONE 'America/Sao_Paulo')::date
                          ORDER BY date_trunc('month', coalesce(confirmed_at, created_at)
                                             AT TIME ZONE 'America/Sao_Paulo')::date) AS meses,
               max(coalesce(confirmed_at, created_at)) AS ultima
        FROM public.donations
        WHERE status = 'confirmed' AND donor_id IS NOT NULL AND type IN ('pix', 'itens')
        GROUP BY donor_id
    LOOP
        meses := r.meses;

        -- Conta de trás para frente quantos meses seguidos chegam até o último.
        streak := 1;
        i := array_length(meses, 1);
        WHILE i > 1 AND meses[i - 1] = (meses[i] - interval '1 month')::date LOOP
            streak := streak + 1;
            i := i - 1;
        END LOOP;

        UPDATE public.points_profiles
        SET donation_streak_months = streak, donation_last_at = r.ultima
        WHERE user_id = r.donor_id;

        -- O bônus que a sequência teria rendido na última doação do mês final.
        IF streak > 1 THEN
            -- Pelo mês da doação, não pelo do extrato: as linhas acabaram de
            -- ser gravadas e todas estão com a hora de agora (as datas de
            -- verdade só entram no fim deste seed).
            SELECT round(sum(l.amount))::int INTO base
            FROM public.points_ledger l
            JOIN public.donations d ON d.id = l.donation_id
            WHERE l.user_id = r.donor_id
              AND l.reason IN ('doacao_dinheiro', 'doacao_item')
              AND date_trunc('month', coalesce(d.confirmed_at, d.created_at)
                             AT TIME ZONE 'America/Sao_Paulo')::date
                  = meses[array_length(meses, 1)];

            bonus := round(coalesce(base, 0) * (streak - 1) * 0.1)::int;
            IF bonus > 0 THEN
                PERFORM public.award_points(
                    r.donor_id, bonus, 'sequencia_doacao', NULL,
                    streak || ' meses seguidos doando'
                );
            END IF;
        END IF;
    END LOOP;
END;
$$;

-- ── Login diário ────────────────────────────────────────────
-- Cinco dias seguidos até ontem: quem abrir o app hoje vê a sequência virar
-- seis e os pontos do dia entrarem na frente de todos, que é a graça da
-- demonstração.

UPDATE public.points_profiles
SET login_streak_days  = 5,
    login_last_date    = current_date - 1,
    login_month        = date_trunc('month', current_date)::date,
    login_month_misses = 0;

-- ── Uma troca já feita ──────────────────────────────────────
-- Para "Minhas trocas" não abrir vazia. Faz na mão o que a
-- redeem_catalog_item faz, porque ela depende de auth.uid() e aqui não há
-- ninguém logado. Desconta do saldo, baixa o estoque, grava o extrato e o
-- código do cupom.

DO $$
DECLARE
    eu     uuid := (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app');
    item   public.catalog_items;
    codigo text := 'ESC-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
BEGIN
    IF eu IS NULL THEN RETURN; END IF;
    SELECT * INTO item FROM public.catalog_items
    WHERE id = '00000000-0000-4000-8000-000000000952';

    IF (SELECT balance FROM public.points_profiles WHERE user_id = eu) < item.points_cost THEN
        RETURN;
    END IF;

    UPDATE public.points_profiles SET balance = balance - item.points_cost WHERE user_id = eu;
    UPDATE public.catalog_items SET stock = stock - 1 WHERE id = item.id;

    INSERT INTO public.points_ledger (user_id, amount, reason, note, created_at)
    VALUES (eu, -item.points_cost, 'canje', item.title, now() - interval '9 days');

    INSERT INTO public.redemptions (user_id, catalog_item_id, points_spent, code, redeemed_at)
    VALUES (eu, item.id, item.points_cost, codigo, now() - interval '9 days');
END;
$$;

-- ── Datas do extrato ────────────────────────────────────────
-- As funções gravam o extrato com a hora de agora. Cada linha que veio de uma
-- doação volta para a data em que a doação foi confirmada, senão o extrato
-- inteiro aparece como "hoje". Por último, para o extrato não começar com uma
-- linha de hoje antes dos pontos do login, o bônus de sequência fica no dia da
-- última doação.

UPDATE public.points_ledger l
SET created_at = coalesce(d.confirmed_at, d.created_at)
FROM public.donations d
WHERE l.donation_id = d.id;

UPDATE public.points_ledger l
SET created_at = pp.donation_last_at
FROM public.points_profiles pp
WHERE l.user_id = pp.user_id
  AND l.reason = 'sequencia_doacao'
  AND pp.donation_last_at IS NOT NULL;

COMMIT;
