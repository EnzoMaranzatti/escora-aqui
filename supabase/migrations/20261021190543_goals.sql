-- Cria a tabela de metas de cada ponto
CREATE TABLE public.goals (
    -- identificador da meta, gerado sozinho
    id               UUID                   PRIMARY KEY DEFAULT gen_random_uuid(),

    -- ponto dono da meta; apagou o ponto, apaga as metas
    place_id         UUID                   NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    -- pix, itens ou voluntariado
    type             public.help_type       NOT NULL,

    -- alvo: reais, quantidade ou vagas; precisa ser maior que zero
    target           NUMERIC                NOT NULL CHECK (target > 0),

    -- quanto já foi confirmado pela instituição
    current          NUMERIC                NOT NULL DEFAULT 0 CHECK (current >= 0),

    -- metas de itens: o que e em que unidade
    item             TEXT                   NOT NULL DEFAULT '',
    unit             TEXT                   NOT NULL DEFAULT 'unidades' CHECK (unit IN ('unidades', 'kg', 'litros', 'pacotes', 'kits')),

    -- causa da meta (opcional)
    cause            TEXT,

    -- prazo e motivo
    deadline         DATE                   NOT NULL,
    reason           TEXT                   NOT NULL DEFAULT '',

    -- situação; começa aberta
    status           public.goal_status     NOT NULL DEFAULT 'open',
    done_at          TIMESTAMPTZ,

    -- false enquanto o ponto ainda está em análise
    published        BOOLEAN                NOT NULL DEFAULT true,

    -- a instituição já viu o aviso "Meta concluída"
    seen_done        BOOLEAN                NOT NULL DEFAULT false,

    -- só voluntariado: nome da ação, tarefa e dia
    action_name      TEXT,
    action_task      TEXT,
    action_day       DATE,

    -- só voluntariado: horário em minutos desde a meia-noite (9h = 540)
    action_start     SMALLINT               CHECK (action_start BETWEEN 0 AND 1440),
    action_end       SMALLINT               CHECK (action_end BETWEEN 0 AND 1440),

    -- quando a meta foi criada
    created_at       TIMESTAMPTZ            NOT NULL DEFAULT now(),

    -- meta de voluntariado precisa de nome, dia e horário válido
    CONSTRAINT volunteer_needs_action CHECK (
        type <> 'voluntariado'
        OR (action_name IS NOT NULL AND action_day IS NOT NULL
            AND action_start IS NOT NULL AND action_end > action_start)
    )
);