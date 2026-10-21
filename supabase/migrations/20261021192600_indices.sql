-- Índices: deixam as buscas rápidas. Não mudam nenhum dado.
-- Nome de cada um: tabela_coluna_idx.

-- ── Mapa ────────────────────────────────────────────────────
-- Busca por distância ("pontos a até 5 km"). GiST entende posições.
CREATE INDEX places_location_idx ON public.places USING gist (location);

-- ── Chaves estrangeiras (FK) ────────────────────────────────
-- O Postgres não cria índice para FK sozinho; é por elas que o app busca.

-- places
CREATE INDEX places_owner_id_idx ON public.places (owner_id);
CREATE INDEX places_indicated_by_idx ON public.places (indicated_by);

-- goals
CREATE INDEX goals_place_id_idx ON public.goals (place_id);

-- monthly_gifts
CREATE INDEX monthly_gifts_donor_id_idx ON public.monthly_gifts (donor_id);
CREATE INDEX monthly_gifts_place_id_idx ON public.monthly_gifts (place_id);

-- donations
CREATE INDEX donations_place_id_idx ON public.donations (place_id);
CREATE INDEX donations_goal_id_idx ON public.donations (goal_id);
CREATE INDEX donations_donor_id_idx ON public.donations (donor_id);
CREATE INDEX donations_monthly_gift_id_idx ON public.donations (monthly_gift_id);

-- reviews (donation_id já tem índice por causa do UNIQUE)
CREATE INDEX reviews_place_id_idx ON public.reviews (place_id);
CREATE INDEX reviews_author_id_idx ON public.reviews (author_id);

-- follows (user_id já é o começo da PRIMARY KEY)
CREATE INDEX follows_place_id_idx ON public.follows (place_id);

-- notices
CREATE INDEX notices_user_id_idx ON public.notices (user_id);
CREATE INDEX notices_place_id_idx ON public.notices (place_id);

-- submissions
CREATE INDEX submissions_place_id_idx ON public.submissions (place_id);
CREATE INDEX submissions_resolved_by_idx ON public.submissions (resolved_by);

-- reports
CREATE INDEX reports_place_id_idx ON public.reports (place_id);
CREATE INDEX reports_author_id_idx ON public.reports (author_id);
CREATE INDEX reports_resolved_by_idx ON public.reports (resolved_by);
