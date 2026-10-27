-- Fase 3: o mapa, o perfil do ponto e as metas passam a vir do banco.

-- ── Latitude e longitude prontas ────────────────────────────
-- A coluna location volta para o app em hexadecimal (EWKB). Esta "view"
-- (uma consulta salva que se usa como tabela) repete places e acrescenta
-- lat e lng em números comuns.
-- security_invoker: quem consulta a view continua preso ao RLS de places,
-- então cada um só vê os pontos que já podia ver.
CREATE VIEW public.places_geo WITH (security_invoker = true) AS
SELECT
    p.*,
    extensions.st_y(p.location::extensions.geometry) AS lat,
    extensions.st_x(p.location::extensions.geometry) AS lng
FROM public.places p;

-- ── Busca por raio ──────────────────────────────────────────
-- Pontos ativos até "km" quilômetros de (lat, lng), do mais perto ao mais longe.
-- O app pede 50 km de uma vez e filtra 5 → 10 → 20 → 50 na tela.
-- st_dwithin usa o índice places_location_idx (gist) da fase 1.
-- places_near.lat (e não só lat): a view também tem colunas lat e lng, e
-- sem o nome da função na frente o Postgres usaria a coluna do ponto.
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

-- ── Contadores das metas ────────────────────────────────────
-- Quem doa não enxerga as doações dos outros (RLS), mas a tela mostra
-- "12 pessoas ajudaram" e "3 vagas". Os números ficam na própria meta e
-- só os gatilhos das fases 4 e 5 mexem neles (não estão no GRANT UPDATE).
ALTER TABLE public.goals
    ADD COLUMN helpers  INTEGER NOT NULL DEFAULT 0 CHECK (helpers >= 0),
    ADD COLUMN enrolled INTEGER NOT NULL DEFAULT 0 CHECK (enrolled >= 0);

-- ── Primeiro nome de quem doa e de quem avalia ──────────────
-- profiles só é visível para a própria pessoa. A instituição precisa ver
-- "Ana registrou R$ 50,00" e o perfil do ponto mostra "Ana, ★★★★★".
-- Então o primeiro nome é copiado na hora em que a linha nasce.
ALTER TABLE public.donations     ADD COLUMN donor_name  TEXT NOT NULL DEFAULT '';
ALTER TABLE public.monthly_gifts ADD COLUMN donor_name  TEXT NOT NULL DEFAULT '';
ALTER TABLE public.reviews       ADD COLUMN author_name TEXT NOT NULL DEFAULT '';

CREATE FUNCTION public.first_name_of(uid uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = ''
AS $$
    SELECT coalesce(nullif((SELECT first_name FROM public.profiles WHERE id = uid), ''), 'Alguém');
$$;

-- Gatilho BEFORE INSERT: preenche o nome antes de a linha ser gravada.
-- O app não escolhe o nome: mesmo que mande outro, o gatilho sobrescreve.
CREATE FUNCTION public.fill_person_name()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF TG_TABLE_NAME = 'reviews' THEN
        NEW.author_name := public.first_name_of(NEW.author_id);
    ELSE
        NEW.donor_name := public.first_name_of(NEW.donor_id);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER donations_fill_name BEFORE INSERT ON public.donations
    FOR EACH ROW EXECUTE FUNCTION public.fill_person_name();
CREATE TRIGGER monthly_gifts_fill_name BEFORE INSERT ON public.monthly_gifts
    FOR EACH ROW EXECUTE FUNCTION public.fill_person_name();
CREATE TRIGGER reviews_fill_name BEFORE INSERT ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.fill_person_name();
