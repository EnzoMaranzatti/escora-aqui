-- ── Fase 12 · o parceiro cria os próprios cupons ───────────────
--
-- Até a fase 10 o parceiro só conferia código no balcão: quem punha cupom no
-- catálogo era a equipe, direto no banco. Funcionava para a demonstração, mas
-- deixava a empresa sem ter o que fazer no app além de dar baixa — e cada
-- cupom novo dependia de alguém da equipe abrir o painel.
--
-- O contrato continua sendo com a equipe (é ela quem liga a conta à empresa,
-- em `partners.owner_id`). O que muda é que, com a empresa já ligada, o
-- cupom é dela: ela cria, e ela tira do catálogo.
--
-- `catalog_items` continua sem política de INSERT/UPDATE. Tudo passa por
-- duas funções SECURITY DEFINER, que são o único lugar onde as regras
-- moram:
--   · o cupom sempre nasce na empresa de quem chamou (`my_partner_id()`),
--     então não dá para criar em nome de outra;
--   · o custo em pontos tem piso e teto. É a moeda do app inteiro: um cupom
--     de 1 ponto esvaziaria o sentido de doar, e o teto segura erro de
--     digitação (60000 no lugar de 600);
--   · no máximo 12 cupons no ar por empresa, para o catálogo do doador não
--     virar vitrine de uma loja só.
--
-- As migrações anteriores já foram aplicadas e não se editam.

-- ── 1. Criar um cupom ───────────────────────────────────────
-- Devolve o id do cupom criado. As mensagens de erro já saem em português:
-- o app mostra o texto do banco do jeito que vem.
CREATE OR REPLACE FUNCTION public.partner_create_item(
    p_title       text,
    p_description text,
    p_points_cost integer,
    p_min_level   public.points_level DEFAULT 'bronze',
    p_stock       integer             DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    me     uuid := public.my_partner_id();
    titulo text := btrim(coalesce(p_title, ''));
    texto  text := btrim(coalesce(p_description, ''));
    novo   uuid;
BEGIN
    IF me IS NULL THEN
        RAISE EXCEPTION 'Esta conta não é de um parceiro.';
    END IF;

    IF char_length(titulo) < 3 OR char_length(titulo) > 60 THEN
        RAISE EXCEPTION 'O nome do cupom precisa ter de 3 a 60 letras.';
    END IF;

    IF char_length(texto) > 200 THEN
        RAISE EXCEPTION 'A descrição pode ter até 200 letras.';
    END IF;

    IF p_points_cost IS NULL OR p_points_cost < 50 OR p_points_cost > 5000 THEN
        RAISE EXCEPTION 'O cupom precisa custar de 50 a 5.000 pontos.';
    END IF;

    IF p_points_cost % 10 <> 0 THEN
        RAISE EXCEPTION 'Use um valor redondo, de 10 em 10 pontos.';
    END IF;

    IF p_stock IS NOT NULL AND (p_stock < 1 OR p_stock > 9999) THEN
        RAISE EXCEPTION 'A quantidade vai de 1 a 9.999. Deixe em branco para não ter limite.';
    END IF;

    IF (SELECT count(*) FROM public.catalog_items ci
         WHERE ci.partner_id = me AND ci.active) >= 12 THEN
        RAISE EXCEPTION 'Sua empresa já tem 12 cupons no catálogo. Tire um do ar para criar outro.';
    END IF;

    -- Dois cupons com o mesmo nome no ar confundem quem está no balcão.
    IF EXISTS (SELECT 1 FROM public.catalog_items ci
                WHERE ci.partner_id = me AND ci.active
                  AND lower(btrim(ci.title)) = lower(titulo)) THEN
        RAISE EXCEPTION 'Sua empresa já tem um cupom com esse nome no catálogo.';
    END IF;

    INSERT INTO public.catalog_items
        (partner_id, title, description, points_cost, min_level, stock, active)
    VALUES
        (me, titulo, texto, p_points_cost, coalesce(p_min_level, 'bronze'), p_stock, true)
    RETURNING id INTO novo;

    RETURN novo;
END;
$$;

-- ── 2. Tirar do catálogo e pôr de volta ─────────────────────
-- Não existe apagar: quem já trocou pontos por este cupom continua com o
-- código na mão (`redemptions` é ON DELETE RESTRICT), e o parceiro continua
-- podendo dar baixa. Fora do ar, o cupom só some para quem ainda não trocou.
CREATE OR REPLACE FUNCTION public.partner_set_item_active(p_item uuid, p_active boolean)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    me    uuid := public.my_partner_id();
    ficou boolean;
BEGIN
    IF me IS NULL THEN
        RAISE EXCEPTION 'Esta conta não é de um parceiro.';
    END IF;

    -- Voltar ao ar passa pelo mesmo teto de quem cria.
    IF p_active AND (SELECT count(*) FROM public.catalog_items ci
                      WHERE ci.partner_id = me AND ci.active AND ci.id <> p_item) >= 12 THEN
        RAISE EXCEPTION 'Sua empresa já tem 12 cupons no catálogo. Tire um do ar antes.';
    END IF;

    UPDATE public.catalog_items ci
    SET active = p_active
    WHERE ci.id = p_item AND ci.partner_id = me
    RETURNING ci.active INTO ficou;

    IF ficou IS NULL THEN
        RAISE EXCEPTION 'Cupom não encontrado.';
    END IF;

    RETURN ficou;
END;
$$;

-- Só quem está logado chama; a checagem de "é parceiro" é das funções.
REVOKE ALL ON FUNCTION public.partner_create_item(text, text, integer, public.points_level, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.partner_set_item_active(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.partner_create_item(text, text, integer, public.points_level, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.partner_set_item_active(uuid, boolean) TO authenticated;

-- Esta máquina não tem CLI do Supabase, psql nem Docker: a migração é
-- aplicada pelo SQL Editor do painel. A linha abaixo marca a migração como
-- já aplicada, para o `supabase db push` de quem tem a CLI não repetir.
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261110170000', 'fase12_parceiro_cria_cupom')
ON CONFLICT (version) DO NOTHING;

-- PostgREST guarda a lista de funções em cache: sem isto o app recebe
-- "function not found" até o cache virar sozinho.
NOTIFY pgrst, 'reload schema';
