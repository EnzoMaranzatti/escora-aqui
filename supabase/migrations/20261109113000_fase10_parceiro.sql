-- ── Fase 10 · o parceiro entra no app ──────────────────────────
--
-- Até aqui o parceiro existia só como linha em `partners`: dava cupom, mas
-- não tinha login nem tela, e nada registrava que o cupom foi usado. Quem
-- recebia o código "ESC-A1B2C3" no balcão não tinha como conferir se ele era
-- de verdade nem impedir que a mesma pessoa usasse duas vezes.
--
-- Esta fase resolve as duas coisas:
--   1. `partners.owner_id` liga a empresa a uma conta do app;
--   2. `redemptions.used_at` guarda a baixa do cupom.
--
-- A conta do parceiro nasce pelo signup normal e a equipe liga ela à empresa
-- com um UPDATE (não há tela de cadastro: parceria é contrato, não autoatendimento).
--
-- As migrações da fase 9 (20261103212526 e 20261108163000) já foram
-- aplicadas e não se editam.

-- ── 1. A empresa ganha dono ─────────────────────────────────
ALTER TABLE public.partners
    ADD COLUMN IF NOT EXISTS owner_id uuid REFERENCES public.profiles (id) ON DELETE SET NULL;

COMMENT ON COLUMN public.partners.owner_id IS
    'Conta que entra no app pelo modo parceiro. Nula enquanto a equipe não liga.';

-- Uma conta cuida de uma empresa só; várias empresas sem dono continuam valendo.
CREATE UNIQUE INDEX IF NOT EXISTS partners_owner_id_key
    ON public.partners (owner_id) WHERE owner_id IS NOT NULL;

-- ── 2. O cupom ganha baixa ──────────────────────────────────
ALTER TABLE public.redemptions
    ADD COLUMN IF NOT EXISTS used_at timestamptz;

COMMENT ON COLUMN public.redemptions.used_at IS
    'Quando o parceiro deu baixa no balcão. Nulo = cupom ainda vale.';

CREATE INDEX IF NOT EXISTS redemptions_code_idx ON public.redemptions (code);

-- ── 3. Quem sou eu, parceiro? ───────────────────────────────
-- Usada pelas políticas e pelas funções abaixo. STABLE porque não muda
-- dentro da mesma consulta. Não precisa de SECURITY DEFINER: a política
-- "partners: todos veem" já deixa qualquer conta ler a tabela.
CREATE OR REPLACE FUNCTION public.my_partner_id()
RETURNS uuid
LANGUAGE sql
STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT id FROM public.partners WHERE owner_id = auth.uid();
$$;

-- ── 4. O parceiro vê os cupons dele, inclusive os fora do ar ─
-- A política da fase 9 só mostra item `active` (ou já trocado pela pessoa).
-- O parceiro precisa ver também o que ele tirou do catálogo.
DROP POLICY IF EXISTS "catalog_items: o parceiro vê os seus" ON public.catalog_items;
CREATE POLICY "catalog_items: o parceiro vê os seus"
ON public.catalog_items FOR SELECT TO authenticated
USING (partner_id = public.my_partner_id());

-- ── 5. Procurar um cupom pelo código ────────────────────────
-- O que a tela de validação mostra antes de dar baixa. SECURITY DEFINER
-- porque atravessa a RLS de `redemptions` e `profiles` — e por isso filtra
-- pelo parceiro de quem chamou: um parceiro nunca enxerga cupom de outro.
--
-- Devolve só o primeiro nome de quem trocou: é o suficiente para conferir
-- no balcão, sem abrir o perfil da pessoa.
CREATE OR REPLACE FUNCTION public.partner_find_redemption(p_code text)
RETURNS TABLE (
    code         text,
    title        text,
    points_spent integer,
    redeemed_at  timestamptz,
    used_at      timestamptz,
    donor_name   text
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    me uuid := public.my_partner_id();
BEGIN
    IF me IS NULL THEN
        RAISE EXCEPTION 'Esta conta não é de um parceiro.';
    END IF;

    RETURN QUERY
    SELECT r.code, ci.title, r.points_spent, r.redeemed_at, r.used_at, pr.first_name
    FROM public.redemptions r
    JOIN public.catalog_items ci ON ci.id = r.catalog_item_id
    JOIN public.profiles pr      ON pr.id = r.user_id
    WHERE upper(btrim(r.code)) = upper(btrim(p_code))
      AND ci.partner_id = me;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cupom não encontrado.';
    END IF;
END;
$$;

-- ── 6. Dar baixa ────────────────────────────────────────────
-- O UPDATE só pega a linha com `used_at IS NULL`: dois caixas tentando ao
-- mesmo tempo, só o primeiro marca. Devolve a hora que ficou gravada.
CREATE OR REPLACE FUNCTION public.partner_use_redemption(p_code text)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    me    uuid := public.my_partner_id();
    quando timestamptz;
BEGIN
    IF me IS NULL THEN
        RAISE EXCEPTION 'Esta conta não é de um parceiro.';
    END IF;

    UPDATE public.redemptions r
    SET used_at = now()
    FROM public.catalog_items ci
    WHERE ci.id = r.catalog_item_id
      AND ci.partner_id = me
      AND upper(btrim(r.code)) = upper(btrim(p_code))
      AND r.used_at IS NULL
    RETURNING r.used_at INTO quando;

    IF quando IS NOT NULL THEN
        RETURN quando;
    END IF;

    -- Não marcou: ou o cupom não é deste parceiro, ou já tinha sido usado.
    -- As duas mensagens são diferentes porque as duas são úteis no balcão.
    IF EXISTS (
        SELECT 1 FROM public.redemptions r
        JOIN public.catalog_items ci ON ci.id = r.catalog_item_id
        WHERE upper(btrim(r.code)) = upper(btrim(p_code)) AND ci.partner_id = me
    ) THEN
        RAISE EXCEPTION 'Esse cupom já foi usado.';
    END IF;

    RAISE EXCEPTION 'Cupom não encontrado.';
END;
$$;

-- ── 7. Os cupons do parceiro, com as contas ─────────────────
-- A tela "Meus cupons" mostra uma linha por item. As contagens vêm daqui
-- prontas para não expor as linhas de `redemptions` (que têm o user_id).
CREATE OR REPLACE FUNCTION public.partner_catalog()
RETURNS TABLE (
    id           uuid,
    title        text,
    description  text,
    points_cost  integer,
    min_level    public.points_level,
    stock        integer,
    active       boolean,
    photo_path   text,
    redeemed     bigint,
    used         bigint
)
LANGUAGE sql
STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT
        ci.id, ci.title, ci.description, ci.points_cost, ci.min_level,
        ci.stock, ci.active, ci.photo_path,
        count(r.id)                                    AS redeemed,
        count(r.id) FILTER (WHERE r.used_at IS NOT NULL) AS used
    FROM public.catalog_items ci
    LEFT JOIN public.redemptions r ON r.catalog_item_id = ci.id
    WHERE ci.partner_id = public.my_partner_id()
    GROUP BY ci.id
    ORDER BY ci.active DESC, ci.points_cost;
$$;

-- Esta máquina não tem CLI do Supabase, psql nem Docker: a migração é
-- aplicada pelo SQL Editor do painel. A linha abaixo marca a migração como
-- já aplicada, para o `supabase db push` de quem tem a CLI não repetir.
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261109113000', 'fase10_parceiro')
ON CONFLICT (version) DO NOTHING;
