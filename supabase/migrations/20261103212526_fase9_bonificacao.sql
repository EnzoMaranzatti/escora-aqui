-- Fase 9: sistema de bonificação (pontos). Ideia do professor: transformar
-- quem doa por interesse próprio em retenção, com uma experiência parecida
-- com Duolingo (telas ainda não desenhadas).
--
-- Regras fechadas com o usuário (2026-11-03):
--   • Dinheiro: R$10 = 20 pontos (2 pontos por real). Nunca decai.
--   • Item: 2 pontos por item doado, independente de kg/litro/pacote/unidade
--     (a tabela donations não guarda preço do item, só quantidade).
--   • Nível Bronze → Prata → Ouro → Doador Black: qualquer uma das 3 trilhas
--     libera, a que vier primeiro (doações de R$10+, pontos acumulados ou
--     itens doados). Black só pela trilha de pontos ou de itens (10.000
--     pontos ou 500+ itens); o limiar de pontos foi calculado para equivaler
--     a R$5.000 doados, mesma lógica das outras trilhas — ajustável.
--   • Login diário: seg-sex 2 pts, sáb 4 pts, dom 6 pts; bônus de 40 pontos
--     se bater o mês inteiro sem falhar um dia.
--   • Sequência mensal de doação: doar todo mês aumenta um multiplicador de
--     pontos. Falhar um mês só pausa (não zera); 30 dias de carência, depois
--     decai até sumir em ~10 dias. O multiplicador em si (+10% por mês de
--     sequência) é uma suposição minha para poder modelar — a confirmar com
--     o usuário quando as telas forem desenhadas.
--   • Catálogo de parceiros (cupons/ingressos) custa pontos e exige nível
--     mínimo. Parceiros e itens do catálogo são cadastrados direto no banco
--     pela equipe (sem tela própria ainda), como os dados de demonstração.
--   • Eventos sazonais: só a estrutura da tabela por enquanto — datas e
--     bônus específicos ainda não foram definidos, e nenhuma função usa essa
--     tabela ainda (não bloqueia o resto da modelagem).
--   • Indicação de amigo e meta coletiva por instituição ficaram de fora
--     (extras "se der tempo", não fechados).

CREATE TYPE public.points_level AS ENUM ('bronze', 'prata', 'ouro', 'black');

-- Motivo de cada linha do extrato (PointsReason no Dart).
CREATE TYPE public.points_reason AS ENUM (
    'doacao_dinheiro', 'doacao_item', 'login_diario', 'bonus_mensal_login', 'sequencia_doacao', 'canje'
);

-- ── Perfil de pontos ────────────────────────────────────────
-- Um por pessoa (igual profiles). Separado de profiles porque é um conjunto
-- de colunas grande e só deste assunto.
CREATE TABLE public.points_profiles (
    user_id                  UUID               PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,

    -- saldo: pode ser gasto no catálogo de parceiros
    balance                  INTEGER            NOT NULL DEFAULT 0 CHECK (balance >= 0),

    -- total ganho desde sempre; nunca decai, usado para o nível (trilha "pontos")
    lifetime                 INTEGER            NOT NULL DEFAULT 0 CHECK (lifetime >= 0),

    level                    public.points_level NOT NULL DEFAULT 'bronze',

    -- trilha "doações": quantas doações de R$10+ (Pix) já foram confirmadas
    qualifying_donations     INTEGER            NOT NULL DEFAULT 0 CHECK (qualifying_donations >= 0),

    -- trilha "itens": soma das quantidades de itens confirmados (kg, litros, pacotes, unidades juntos)
    items_donated            INTEGER            NOT NULL DEFAULT 0 CHECK (items_donated >= 0),

    -- login diário
    login_streak_days        INTEGER            NOT NULL DEFAULT 0,
    login_last_date          DATE,
    login_month              DATE,
    login_month_misses       INTEGER            NOT NULL DEFAULT 0,

    -- sequência mensal de doação
    donation_streak_months   INTEGER            NOT NULL DEFAULT 0,
    donation_last_at         TIMESTAMPTZ
);

-- ── Extrato de pontos ───────────────────────────────────────
-- Cada ganho ou gasto, com o motivo. A tela "meus pontos" lê daqui.
CREATE TABLE public.points_ledger (
    id            UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID               NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,

    -- positivo (ganho) ou negativo (canje no catálogo)
    amount        INTEGER            NOT NULL,
    reason        public.points_reason NOT NULL,

    -- doação que originou os pontos, quando for o caso
    donation_id   UUID               REFERENCES public.donations (id) ON DELETE SET NULL,

    note          TEXT               NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ        NOT NULL DEFAULT now()
);

-- ── Catálogo de parceiros ───────────────────────────────────
-- Empresas que dão cupons/ingressos usando capacidade ociosa (ex.: Thermas
-- dos Laranjais), em troca de divulgação. Cadastrado direto no banco.
CREATE TABLE public.partners (
    id            UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT               NOT NULL,
    logo_path     TEXT,
    created_at    TIMESTAMPTZ        NOT NULL DEFAULT now()
);

CREATE TABLE public.catalog_items (
    id            UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id    UUID               NOT NULL REFERENCES public.partners (id) ON DELETE CASCADE,

    title         TEXT               NOT NULL,
    description   TEXT               NOT NULL DEFAULT '',

    points_cost   INTEGER            NOT NULL CHECK (points_cost > 0),
    min_level     public.points_level NOT NULL DEFAULT 'bronze',

    -- NULL = sem limite; cada canje desconta 1
    stock         INTEGER            CHECK (stock IS NULL OR stock >= 0),

    active        BOOLEAN            NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ        NOT NULL DEFAULT now()
);

-- ── Canjes ──────────────────────────────────────────────────
-- Histórico do que cada pessoa já trocou. ON DELETE RESTRICT: mesmo que o
-- item saia do catálogo depois, o histórico do canje continua existindo.
CREATE TABLE public.redemptions (
    id               UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID            NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    catalog_item_id  UUID            NOT NULL REFERENCES public.catalog_items (id) ON DELETE RESTRICT,
    points_spent     INTEGER         NOT NULL CHECK (points_spent > 0),

    -- o que a pessoa mostra no parceiro ("ESC-A1B2C3"), criado no canje
    code             TEXT            NOT NULL UNIQUE,

    redeemed_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- ── Eventos sazonais ────────────────────────────────────────
-- Só a estrutura: datas e bônus específicos ainda não foram decididos, e
-- nenhuma função usa esta tabela ainda.
CREATE TABLE public.seasonal_events (
    id            UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT               NOT NULL,
    starts_on     DATE               NOT NULL,
    ends_on       DATE               NOT NULL CHECK (ends_on >= starts_on),
    bonus_points  INTEGER            NOT NULL CHECK (bonus_points > 0),
    created_at    TIMESTAMPTZ        NOT NULL DEFAULT now()
);

-- ── Índices ─────────────────────────────────────────────────
-- Chaves estrangeiras, como na fase 1. points_profiles.user_id já é a PK.
CREATE INDEX points_ledger_user_id_idx ON public.points_ledger (user_id);
CREATE INDEX points_ledger_donation_id_idx ON public.points_ledger (donation_id);
CREATE INDEX catalog_items_partner_id_idx ON public.catalog_items (partner_id);
CREATE INDEX redemptions_user_id_idx ON public.redemptions (user_id);
CREATE INDEX redemptions_catalog_item_id_idx ON public.redemptions (catalog_item_id);

-- ── Permissões (RLS) ────────────────────────────────────────
ALTER TABLE public.points_profiles  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points_ledger    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partners         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasonal_events  ENABLE ROW LEVEL SECURITY;

-- Sem política de INSERT/UPDATE para authenticated em nenhuma das seis: o
-- saldo, o extrato e os canjes só mudam pelas funções abaixo (SECURITY
-- DEFINER); o catálogo e os eventos são cadastrados direto no banco.

CREATE POLICY "points_profiles: ver o próprio ou equipe"
ON public.points_profiles FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_team());

CREATE POLICY "points_ledger: ver o próprio ou equipe"
ON public.points_ledger FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_team());

CREATE POLICY "partners: todos veem"
ON public.partners FOR SELECT TO authenticated
USING (true);

-- Item fora do catálogo (active false) continua visível para quem já trocou:
-- é assim que a tela de trocas mostra o nome do que a pessoa pegou.
CREATE POLICY "catalog_items: ver ativos, trocados ou equipe"
ON public.catalog_items FOR SELECT TO authenticated
USING (
    active
    OR public.is_team()
    OR EXISTS (
        SELECT 1 FROM public.redemptions r
        WHERE r.catalog_item_id = catalog_items.id AND r.user_id = auth.uid()
    )
);

CREATE POLICY "redemptions: ver o próprio ou equipe"
ON public.redemptions FOR SELECT TO authenticated
USING (user_id = auth.uid() OR public.is_team());

CREATE POLICY "seasonal_events: todos veem"
ON public.seasonal_events FOR SELECT TO authenticated
USING (true);

-- ── Ganhar pontos (uso interno) ─────────────────────────────
-- Soma no saldo e no total histórico, grava a linha do extrato e recalcula o
-- nível. Chamada só pelas funções desta fase, nunca direto pelo app.
CREATE FUNCTION public.award_points(
    p_user uuid, p_amount int, p_reason public.points_reason,
    p_donation uuid DEFAULT NULL, p_note text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF p_user IS NULL OR p_amount <= 0 THEN RETURN; END IF;

    INSERT INTO public.points_profiles (user_id) VALUES (p_user) ON CONFLICT (user_id) DO NOTHING;
    UPDATE public.points_profiles
    SET balance = balance + p_amount, lifetime = lifetime + p_amount
    WHERE user_id = p_user;

    INSERT INTO public.points_ledger (user_id, amount, reason, donation_id, note)
    VALUES (p_user, p_amount, p_reason, p_donation, p_note);

    PERFORM public.recompute_level(p_user);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.award_points FROM public, anon, authenticated;

-- O nível é sempre o maior entre as 3 trilhas; como os contadores nunca
-- diminuem, o nível também nunca cai.
CREATE FUNCTION public.recompute_level(p_user uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    pp public.points_profiles;
    tier int;
BEGIN
    SELECT * INTO pp FROM public.points_profiles WHERE user_id = p_user;
    IF NOT FOUND THEN RETURN; END IF;

    tier := greatest(
        CASE WHEN pp.qualifying_donations >= 20 THEN 2 WHEN pp.qualifying_donations >= 5 THEN 1 ELSE 0 END,
        CASE WHEN pp.lifetime >= 10000 THEN 3 WHEN pp.lifetime >= 500 THEN 2 WHEN pp.lifetime >= 100 THEN 1 ELSE 0 END,
        CASE WHEN pp.items_donated >= 500 THEN 3 WHEN pp.items_donated >= 150 THEN 2 WHEN pp.items_donated >= 50 THEN 1 ELSE 0 END
    );
    UPDATE public.points_profiles SET level = CASE tier
        WHEN 3 THEN 'black' WHEN 2 THEN 'ouro' WHEN 1 THEN 'prata' ELSE 'bronze'
    END::public.points_level
    WHERE user_id = p_user;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recompute_level FROM public, anon, authenticated;

-- ── Doação confirmada: pontos de dinheiro ou item ───────────
-- Chamada pelo gatilho de status da doação (fase 5), só quando confirmada.
-- Voluntariado não entra: a regra fechada com o usuário só cobre dinheiro e
-- item.
CREATE FUNCTION public.register_qualifying_donation(d public.donations)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    pp         public.points_profiles;
    base       int;
    bonus      int;
    streak     int;
    reason     public.points_reason;
    this_month date := date_trunc('month', now() AT TIME ZONE 'America/Sao_Paulo')::date;
BEGIN
    INSERT INTO public.points_profiles (user_id) VALUES (d.donor_id) ON CONFLICT (user_id) DO NOTHING;
    SELECT * INTO pp FROM public.points_profiles WHERE user_id = d.donor_id;

    IF d.type = 'pix' THEN
        base := round(d.amount * 2)::int;
        reason := 'doacao_dinheiro';
        IF d.amount >= 10 THEN
            UPDATE public.points_profiles SET qualifying_donations = qualifying_donations + 1
            WHERE user_id = d.donor_id;
        END IF;
    ELSE -- itens
        base := round(d.amount * 2)::int;
        reason := 'doacao_item';
        UPDATE public.points_profiles SET items_donated = items_donated + round(d.amount)::int
        WHERE user_id = d.donor_id;
    END IF;

    -- Sequência mensal: um mês sem doar só pausa (não zera); depois de 30
    -- dias de carência + 10 de decaimento ela já chegou a zero, e a próxima
    -- doação começa uma sequência nova.
    IF pp.donation_last_at IS NULL THEN
        streak := 1;
    ELSIF date_trunc('month', pp.donation_last_at AT TIME ZONE 'America/Sao_Paulo')::date = this_month THEN
        streak := greatest(pp.donation_streak_months, 1);
    ELSIF now() - pp.donation_last_at > interval '40 days' THEN
        streak := 1;
    ELSE
        streak := pp.donation_streak_months + 1;
    END IF;
    UPDATE public.points_profiles
    SET donation_streak_months = streak, donation_last_at = now()
    WHERE user_id = d.donor_id;

    PERFORM public.award_points(d.donor_id, base, reason, d.id);

    -- +10% por mês de sequência (suposição minha, a confirmar).
    IF streak > 1 THEN
        bonus := round(base * (streak - 1) * 0.1)::int;
        IF bonus > 0 THEN
            PERFORM public.award_points(
                d.donor_id, bonus, 'sequencia_doacao', d.id,
                streak || ' meses seguidos doando'
            );
        END IF;
    END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.register_qualifying_donation FROM public, anon, authenticated;

-- Mesma função da fase 5, com a chamada dos pontos adicionada no trecho de
-- doação confirmada.
CREATE OR REPLACE FUNCTION public.after_donation_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    g public.goals;
    p public.places;
    what text;
BEGIN
    SELECT * INTO p FROM public.places WHERE id = NEW.place_id;
    SELECT * INTO g FROM public.goals WHERE id = NEW.goal_id;
    what := CASE WHEN g.id IS NULL THEN public.fmt_money(NEW.amount) ELSE public.fmt_amount(g, NEW.amount) END;

    IF NEW.status = 'confirmed' THEN
        IF g.id IS NOT NULL THEN
            UPDATE public.goals
            SET current = current + NEW.amount, helpers = helpers + 1
            WHERE id = g.id
            RETURNING * INTO g;

            IF g.current >= g.target AND g.status = 'open' THEN
                UPDATE public.goals SET status = 'done', done_at = now() WHERE id = g.id;
                INSERT INTO public.notices (user_id, kind, title, body, place_id)
                SELECT DISTINCT d.donor_id, 'goal_done'::public.notice_kind,
                       'A meta de ' || p.name || ' foi concluída',
                       public.fmt_amount(g, g.target, false) || ' arrecadados. Obrigado por fazer parte.',
                       p.id
                FROM public.donations d
                WHERE d.goal_id = g.id AND d.status = 'confirmed' AND d.donor_id IS NOT NULL;
            END IF;
        END IF;

        IF (SELECT notify_confirm FROM public.profiles WHERE id = NEW.donor_id) THEN
            PERFORM public.notify(
                NEW.donor_id, 'confirmed',
                CASE WHEN NEW.type = 'voluntariado' THEN 'Sua presença foi confirmada' ELSE 'Sua doação foi confirmada' END,
                CASE WHEN NEW.type = 'voluntariado'
                     THEN 'A ' || p.name || ' marcou sua presença em ' || coalesce(g.action_name, 'uma ação') || '.'
                     ELSE 'A ' || p.name || ' confirmou o recebimento de ' || what || '.' END,
                p.id
            );
        END IF;

        -- Pontos: só dinheiro (Pix) e item, só se tiver doador (não some pontos de conta apagada).
        IF NEW.donor_id IS NOT NULL AND NEW.type IN ('pix', 'itens') THEN
            PERFORM public.register_qualifying_donation(NEW);
        END IF;

    ELSIF NEW.status = 'not_found' THEN
        PERFORM public.notify(
            NEW.donor_id, 'not_found',
            'A ' || p.name || ' não encontrou sua doação',
            'Confira o comprovante em Minhas doações.',
            p.id
        );

    ELSIF NEW.status = 'cancelled' AND OLD.status = 'enrolled' AND g.id IS NOT NULL THEN
        UPDATE public.goals SET enrolled = greatest(enrolled - 1, 0) WHERE id = g.id;
    END IF;
    RETURN NULL;
END;
$$;

-- ── Login diário ─────────────────────────────────────────────
-- Chamada pelo app a cada sessão aberta. Não faz nada se já tiver pontuado
-- hoje (idempotente: pode chamar de novo sem medo).
CREATE FUNCTION public.register_daily_login()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    me        uuid := auth.uid();
    pp        public.points_profiles;
    today     date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
    cur_month date := date_trunc('month', today)::date;
    dow       int  := extract(dow FROM today)::int; -- 0 domingo … 6 sábado
    misses    int;
    streak    int;
BEGIN
    IF me IS NULL THEN RETURN; END IF;

    INSERT INTO public.points_profiles (user_id) VALUES (me) ON CONFLICT (user_id) DO NOTHING;
    SELECT * INTO pp FROM public.points_profiles WHERE user_id = me;

    -- Já pontuou hoje: chamar de novo não faz nada.
    IF pp.login_last_date = today THEN RETURN; END IF;

    IF pp.login_month IS DISTINCT FROM cur_month THEN
        -- Virou o mês: quem não falhou nenhum dia no mês que passou leva 40 pontos.
        IF pp.login_month IS NOT NULL AND pp.login_month_misses = 0 THEN
            PERFORM public.award_points(me, 40, 'bonus_mensal_login');
        END IF;
        -- O mês novo já começa contando como falha os dias que passaram antes
        -- deste login: quem cria a conta no dia 20 não fecha o mês com um login.
        misses := today - cur_month;
    ELSE
        -- Os dias entre o último login e ontem.
        misses := pp.login_month_misses + greatest(today - pp.login_last_date - 1, 0);
    END IF;

    -- Dias seguidos (para a tela): quebra a sequência quem fica um dia fora.
    streak := CASE WHEN today - pp.login_last_date = 1 THEN pp.login_streak_days + 1 ELSE 1 END;

    UPDATE public.points_profiles
    SET login_last_date    = today,
        login_month        = cur_month,
        login_month_misses = misses,
        login_streak_days  = streak
    WHERE user_id = me;

    PERFORM public.award_points(
        me,
        CASE WHEN dow BETWEEN 1 AND 5 THEN 2 WHEN dow = 6 THEN 4 ELSE 6 END,
        'login_diario'
    );
END;
$$;

-- ── Canjear no catálogo de parceiros ────────────────────────
CREATE FUNCTION public.redeem_catalog_item(item uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    ci public.catalog_items;
    pp public.points_profiles;
BEGIN
    SELECT * INTO ci FROM public.catalog_items WHERE id = item AND active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Esse item não está disponível.';
    END IF;
    SELECT * INTO pp FROM public.points_profiles WHERE user_id = auth.uid();
    IF NOT FOUND OR pp.level < ci.min_level THEN
        RAISE EXCEPTION 'Seu nível ainda não libera esse item.';
    END IF;

    -- Desconta só se o saldo der: dois canjes ao mesmo tempo não deixam o
    -- saldo negativo.
    UPDATE public.points_profiles SET balance = balance - ci.points_cost
    WHERE user_id = auth.uid() AND balance >= ci.points_cost;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pontos insuficientes para esse item.';
    END IF;

    -- Estoque vazio (NULL) é sem limite.
    IF ci.stock IS NOT NULL THEN
        UPDATE public.catalog_items SET stock = stock - 1 WHERE id = item AND stock > 0;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Esse item esgotou.';
        END IF;
    END IF;

    INSERT INTO public.points_ledger (user_id, amount, reason, note)
    VALUES (auth.uid(), -ci.points_cost, 'canje', ci.title);
    INSERT INTO public.redemptions (user_id, catalog_item_id, points_spent, code)
    VALUES (auth.uid(), item, ci.points_cost, 'ESC-' || upper(substr(md5(gen_random_uuid()::text), 1, 6)));
END;
$$;

-- ── Perfil novo já nasce com a linha de pontos ──────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles(id, full_name, first_name)
    VALUES(
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', ''),
        coalesce(split_part(new.raw_user_meta_data ->> 'full_name', ' ', 1), '')
    );
    INSERT INTO public.points_profiles (user_id) VALUES (new.id);
    RETURN new;
END;
$$;

-- Contas que já existiam antes desta fase também precisam da linha.
INSERT INTO public.points_profiles (user_id)
SELECT id FROM public.profiles
ON CONFLICT (user_id) DO NOTHING;
