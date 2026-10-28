-- CNPJ conferido pelo banco no envio do cadastro.
--
-- O app consulta a BrasilAPI no celular e grava a razão social e a situação.
-- O banco não conferia nada: quem chamasse a API direto podia mandar qualquer
-- número. Agora submit_place recusa:
--   1. CNPJ com dígitos verificadores errados;
--   2. CNPJ que já está em outro ponto (na fila, em ajuste, ativo ou pausado);
--   3. CNPJ que já teve um cadastro recusado (decisão de 2026-10-28: a recusa
--      é para casos graves, como documento falso).
-- A razão social continua sendo conferida pela equipe, que consulta a base
-- pública de novo na fila de cadastros.
-- Os pontos que já estão no banco não mudam: a regra vale só no envio.

-- Dígitos verificadores do CNPJ (aceita com ou sem pontuação).
CREATE FUNCTION public.cnpj_valido(cnpj text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
    d text := regexp_replace(coalesce(cnpj, ''), '\D', '', 'g');
    pesos int[] := '{6,5,4,3,2,9,8,7,6,5,4,3,2}';
    soma int;
    resto int;
    digito int;
    n int;
    i int;
BEGIN
    -- Todos os dígitos iguais (00.000.000/0000-00…) passam na conta, mas não valem.
    IF length(d) <> 14 OR d = repeat(left(d, 1), 14) THEN
        RETURN false;
    END IF;
    -- Primeiro dígito: 12 números com os pesos 5..2, 9..2; o segundo, 13 com 6..2, 9..2.
    FOREACH n IN ARRAY ARRAY[12, 13] LOOP
        soma := 0;
        FOR i IN 1..n LOOP
            soma := soma + substr(d, i, 1)::int * pesos[i + 13 - n];
        END LOOP;
        resto := soma % 11;
        -- Fora do IF: o plpgsql lê a condição do IF só até o primeiro THEN.
        digito := CASE WHEN resto < 2 THEN 0 ELSE 11 - resto END;
        IF substr(d, n + 1, 1)::int <> digito THEN
            RETURN false;
        END IF;
    END LOOP;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_place(place uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    first_time boolean;
    numero text;
BEGIN
    SELECT regexp_replace(p.cnpj, '\D', '', 'g') INTO numero
    FROM public.places p
    WHERE p.id = place AND p.owner_id = auth.uid() AND p.status IN ('draft', 'adjust');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Esse cadastro não pode ser enviado agora.';
    END IF;

    IF numero IS NOT NULL AND numero <> '' THEN
        IF NOT public.cnpj_valido(numero) THEN
            RAISE EXCEPTION 'Confira o CNPJ: os números não batem.';
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.places o
            WHERE o.id <> place
              AND regexp_replace(o.cnpj, '\D', '', 'g') = numero
              AND o.status IN ('review', 'awaiting_indication', 'adjust', 'active', 'paused')
        ) THEN
            RAISE EXCEPTION 'Esse CNPJ já está cadastrado em outro ponto. Se é da sua instituição, fale com a equipe.';
        END IF;
        IF EXISTS (
            SELECT 1 FROM public.places o
            WHERE o.id <> place
              AND regexp_replace(o.cnpj, '\D', '', 'g') = numero
              AND o.status = 'refused'
        ) THEN
            RAISE EXCEPTION 'Esse CNPJ teve um cadastro recusado. Para tentar de novo, fale com a equipe.';
        END IF;
    END IF;

    UPDATE public.places SET status = 'review' WHERE id = place;
    first_time := NOT EXISTS (SELECT 1 FROM public.submissions WHERE place_id = place);
    -- Um envio pendente por vez.
    DELETE FROM public.submissions WHERE place_id = place AND resolved_at IS NULL AND kind <> 'mudanca';
    INSERT INTO public.submissions (place_id, kind)
    VALUES (place, CASE WHEN first_time THEN 'novo' ELSE 'correcao' END::public.submission_kind);
END;
$$;
