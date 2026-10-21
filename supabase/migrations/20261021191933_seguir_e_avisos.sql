--  Seguir pontos
-- Quem acompanha qual ponto (o coração no perfil do ponto).
CREATE TABLE public.follows (
    -- quem segue
    user_id      UUID           NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,

    -- ponto seguido
    place_id     UUID           NOT NULL REFERENCES public.places (id) ON DELETE CASCADE,

    created_at   TIMESTAMPTZ    NOT NULL DEFAULT now(),

    -- o par pessoa + ponto é a chave: ninguém segue o mesmo ponto duas vezes
    PRIMARY KEY (user_id, place_id)
);

-- Avisos 
-- Um aviso para uma pessoa. Avisos da instituição vão para o dono do ponto.
CREATE TABLE public.notices (
    id           UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),

    -- quem recebe o aviso
    user_id      UUID                 NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,

    -- tipo do aviso (nova meta, doação confirmada, aprovado...)
    kind         public.notice_kind   NOT NULL,

    -- título e texto do aviso
    title        TEXT                 NOT NULL,
    body         TEXT                 NOT NULL,

    -- ponto do aviso (opcional)
    place_id     UUID                 REFERENCES public.places (id) ON DELETE CASCADE,

    -- já foi lido?
    read         BOOLEAN              NOT NULL DEFAULT false,

    created_at   TIMESTAMPTZ          NOT NULL DEFAULT now()
);