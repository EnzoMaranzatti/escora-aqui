-- ── Doação mensal ───────────────────────────────────────────
-- Não é débito automático: no dia, o app lembra e a pessoa paga no banco.
CREATE TABLE public.monthly_gifts (
    id           UUID           PRIMARY KEY DEFAULT gen_random_uuid(),

    -- quem doa e para qual ponto
    donor_id     UUID           NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
    place_id     UUID           NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    -- valor em reais
    amount       NUMERIC        NOT NULL CHECK (amount > 0),

    -- dia do mês do lembrete; até 28 porque todo mês tem
    day          SMALLINT       NOT NULL CHECK (day BETWEEN 1 AND 28),

    paused       BOOLEAN        NOT NULL DEFAULT false,

    -- desde quando doa
    since        DATE           NOT NULL DEFAULT current_date,

    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- ── Doações ─────────────────────────────────────────────────
-- Cada ajuda registrada. A meta só avança quando a instituição confirma.
CREATE TABLE public.donations (
    id                UUID                     PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ponto que recebe
    place_id          UUID                     NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    -- meta (vazia na doação mensal sem meta Pix aberta)
    goal_id           UUID                     REFERENCES public.goals (id) ON DELETE SET NULL,

    -- quem doou; se excluir a conta, a doação fica como anônima
    donor_id          UUID                     REFERENCES public.profiles (id) ON DELETE SET NULL,

    -- se veio de uma doação mensal
    monthly_gift_id   UUID                     REFERENCES public.monthly_gifts (id) ON DELETE SET NULL,

    -- pix, itens ou voluntariado
    type              public.help_type         NOT NULL,

    -- reais ou quantidade; 1 no voluntariado
    amount            NUMERIC                  NOT NULL CHECK (amount > 0),

    -- dia combinado: entrega dos itens ou dia da ação
    scheduled_for     DATE,

    -- comprovante do Pix no Storage (opcional)
    receipt_path      TEXT,

    -- situação; começa aguardando a instituição
    status            public.donation_status   NOT NULL DEFAULT 'waiting',
    confirmed_at      TIMESTAMPTZ,

    created_at        TIMESTAMPTZ              NOT NULL DEFAULT now()
);

-- ── Avaliações ──────────────────────────────────────────────
-- Feita depois de uma doação confirmada. Uma por doação.
CREATE TABLE public.reviews (
    id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),

    -- a doação avaliada; UNIQUE impede avaliar duas vezes
    donation_id   UUID           NOT NULL UNIQUE REFERENCES public.donations (id) ON DELETE CASCADE,

    -- ponto avaliado
    place_id      UUID           NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    -- quem avaliou; se excluir a conta, a avaliação fica
    author_id     UUID           REFERENCES public.profiles (id) ON DELETE SET NULL,

    -- de 1 a 5 estrelas
    stars         SMALLINT       NOT NULL CHECK (stars BETWEEN 1 AND 5),
    comment       TEXT           NOT NULL DEFAULT '',

    created_at    TIMESTAMPTZ    NOT NULL DEFAULT now()
);
