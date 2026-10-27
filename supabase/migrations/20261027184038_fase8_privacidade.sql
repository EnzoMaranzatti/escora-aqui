-- Fase 8 (privacidade): duas correções.
--
-- 1. O nome e o telefone do responsável pelo ponto apareciam para qualquer
--    pessoa logada pela API (a tela promete: "Ele não aparece no app").
--    Agora só o dono do ponto e a equipe leem essas duas colunas.
-- 2. Apagar a conta deixava o caminho do comprovante nas doações para outros
--    pontos. Agora ele sai junto. (Os arquivos em si o app apaga pelo Storage
--    antes de chamar delete_account: o Supabase não deixa apagar arquivo por SQL.)

-- ── 1. Colunas privadas de places ───────────────────────────
-- O RLS escolhe LINHAS; para esconder COLUNAS, o caminho é tirar o SELECT da
-- tabela inteira e devolver coluna por coluna, menos responsible e phone.
-- Atenção: uma coluna nova em places precisa entrar neste GRANT.
REVOKE SELECT ON public.places FROM anon, authenticated;
GRANT SELECT (
    id, owner_id, status, draft_step, name, type_label, kind, phone_verified,
    cnpj, legal_name, cnpj_status, cnpj_unchecked, indicated_by, about, distributes,
    causes, accepts, cep, street, number, complement, neighborhood, city, location,
    hours, receive_days, photo_path, pix_key_type, pix_key, payee, pix_paused,
    status_reason, status_message, verified_at, last_reviewed, created_at
) ON public.places TO authenticated;

-- A view da fase 3 usava "p.*", que agora inclui colunas proibidas. Ela é
-- refeita com a lista de colunas, e places_near (que devolve a view) junto.
DROP FUNCTION public.places_near(double precision, double precision, double precision);
DROP VIEW public.places_geo;

CREATE VIEW public.places_geo WITH (security_invoker = true) AS
SELECT
    p.id, p.owner_id, p.status, p.draft_step, p.name, p.type_label, p.kind, p.phone_verified,
    p.cnpj, p.legal_name, p.cnpj_status, p.cnpj_unchecked, p.indicated_by, p.about, p.distributes,
    p.causes, p.accepts, p.cep, p.street, p.number, p.complement, p.neighborhood, p.city, p.location,
    p.hours, p.receive_days, p.photo_path, p.pix_key_type, p.pix_key, p.payee, p.pix_paused,
    p.status_reason, p.status_message, p.verified_at, p.last_reviewed, p.created_at,
    extensions.st_y(p.location::extensions.geometry) AS lat,
    extensions.st_x(p.location::extensions.geometry) AS lng
FROM public.places p;

CREATE FUNCTION public.places_near(lat double precision, lng double precision, km double precision DEFAULT 50)
RETURNS SETOF public.places_geo
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
    SELECT g.*
    FROM public.places_geo g
    WHERE g.status = 'active'
      AND extensions.st_dwithin(
          g.location,
          extensions.st_setsrid(extensions.st_makepoint(places_near.lng, places_near.lat), 4326)::extensions.geography,
          km * 1000
      )
    ORDER BY extensions.st_distance(
        g.location,
        extensions.st_setsrid(extensions.st_makepoint(places_near.lng, places_near.lat), 4326)::extensions.geography
    );
$$;

-- Quem pode ver o contato: o dono do ponto e a equipe (a fila mostra o
-- telefone para a equipe conferir). Para os outros ids, não volta nada.
CREATE FUNCTION public.place_contacts(ids uuid[])
RETURNS TABLE (id uuid, responsible text, phone text)
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = ''
AS $$
    SELECT p.id, p.responsible, p.phone
    FROM public.places p
    WHERE p.id = ANY (ids)
      AND (p.owner_id = auth.uid() OR public.is_team());
$$;

REVOKE EXECUTE ON FUNCTION public.place_contacts FROM public, anon;

-- ── 2. Apagar a conta leva o comprovante junto ──────────────
-- O app precisa listar a própria pasta para apagar os arquivos. Nos baldes
-- públicos (places e avatars) ainda não havia regra de leitura da pasta.
CREATE POLICY "arquivos: ver a sua pasta"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id IN ('places', 'avatars')
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE OR REPLACE FUNCTION public.delete_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Entre na sua conta para apagá-la.';
    END IF;
    -- As doações para outros pontos ficam (sem doador), mas sem o comprovante.
    UPDATE public.donations SET receipt_path = NULL WHERE donor_id = auth.uid();
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;
