-- ── Fila da equipe ──────────────────────────────────────────
-- Cadastro novo, correção depois de ajuste ou troca de dados sensíveis.
CREATE TABLE public.submissions (
    id            UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ponto que está sendo analisado
    place_id      UUID                     NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    -- novo, correcao ou mudanca
    kind          public.submission_kind   NOT NULL,

    -- só em mudanca: o que mudou, ex.: {"Chave Pix": "nova"}
    changes       JSONB                    NOT NULL DEFAULT '{}',

    -- quando entrou na fila; mais de 3 dias úteis fica urgente
    sent_at       TIMESTAMPTZ              NOT NULL DEFAULT now(),

    -- quando e quem da equipe decidiu (vazio enquanto está na fila)
    resolved_at   TIMESTAMPTZ,
    resolved_by   UUID                     REFERENCES public.profiles (id) ON DELETE SET NULL
);

-- ── Denúncias ───────────────────────────────────────────────
-- Feitas por doadores sobre um ponto.
CREATE TABLE public.reports (
    id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ponto denunciado
    place_id      UUID           NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    -- quem denunciou; se excluir a conta, a denúncia fica
    author_id     UUID           REFERENCES public.profiles (id) ON DELETE SET NULL,

    -- um dos 4 motivos fixos do app (reportReasons)
    reason        TEXT           NOT NULL CHECK (reason IN (
                                     'As informações estão erradas',
                                     'O ponto não funciona mais',
                                     'Suspeito de golpe',
                                     'Outro motivo'
                                 )),

    -- comentário livre de quem denunciou
    body          TEXT           NOT NULL DEFAULT '',

    created_at    TIMESTAMPTZ    NOT NULL DEFAULT now(),

    -- quando e quem da equipe resolveu
    resolved_at   TIMESTAMPTZ,
    resolved_by   UUID           REFERENCES public.profiles (id) ON DELETE SET NULL
);