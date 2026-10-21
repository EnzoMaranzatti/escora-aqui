
-- Cria os pontos de apoio (ONGs, igrejas, escolas)
CREATE TABLE public.places (
    -- identificador do ponto, gerado sozinho
    id               UUID                       PRIMARY KEY DEFAULT gen_random_uuid(),

    -- quem cadastrou (aponta para profiles)
    owner_id         UUID                       NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,

    -- situação do ponto; começa como rascunho
    status           public.place_status        NOT NULL DEFAULT 'draft',

    -- em que passo do cadastro a pessoa parou (0 a 5)
    draft_step       SMALLINT                   NOT NULL DEFAULT 0 CHECK (draft_step BETWEEN 0 AND 5),

    -- nome e tipo escrito (Igreja, ONG, Coletivo...)
    name             TEXT                       NOT NULL DEFAULT '',
    type_label       TEXT                       NOT NULL DEFAULT '',

    -- ícone do pin no mapa
    kind             public.place_kind          NOT NULL DEFAULT 'care',

    -- responsável pelo ponto e telefone dele
    responsible      TEXT                       NOT NULL DEFAULT '',
    phone            TEXT                       NOT NULL DEFAULT '',
    phone_verified   BOOLEAN                    NOT NULL DEFAULT false,

    -- CNPJ (vazio para coletivo sem CNPJ) e dados da BrasilAPI
    cnpj             TEXT,
    legal_name       TEXT                       NOT NULL DEFAULT '',
    cnpj_status      TEXT                       NOT NULL DEFAULT '',
    cnpj_unchecked   BOOLEAN                    NOT NULL DEFAULT false,

    -- ponto verificado que indicou este coletivo
    indicated_by     UUID                       REFERENCES public.places (id) ON DELETE SET NULL,

    -- textos do perfil do ponto
    about            TEXT                       NOT NULL DEFAULT '',
    distributes      TEXT,

    -- causas e formas de ajuda aceitas
    causes           TEXT[]                     NOT NULL DEFAULT '{}',
    accepts          public.help_type[]         NOT NULL DEFAULT '{}',

    -- endereço
    cep              TEXT                       NOT NULL DEFAULT '',
    street           TEXT                       NOT NULL DEFAULT '',
    number           TEXT                       NOT NULL DEFAULT '',
    complement       TEXT                       NOT NULL DEFAULT '',
    neighborhood     TEXT                       NOT NULL DEFAULT '',
    city             TEXT                       NOT NULL DEFAULT '',

    -- posição no mapa; vazia enquanto é rascunho
    location         extensions.geography(Point, 4326),

    -- horário em texto livre e dias que recebe (1 = segunda ... 7 = domingo)
    hours            TEXT                       NOT NULL DEFAULT '',
    receive_days     SMALLINT[]                 NOT NULL DEFAULT '{1,2,3,4,5}' CHECK (receive_days <@ '{1,2,3,4,5,6,7}'),

    -- caminho da foto no Storage
    photo_path       TEXT,

    -- chave Pix e nome do favorecido
    pix_key_type     TEXT,
    pix_key          TEXT,
    payee            TEXT,

    -- true enquanto a troca de chave Pix espera a equipe
    pix_paused       BOOLEAN                    NOT NULL DEFAULT false,

    -- motivo e mensagem da equipe (ajuste, recusa, pausa)
    status_reason    TEXT,
    status_message   TEXT,

    -- quando foi aprovado e quando os dados foram revisados (a cada 90 dias)
    verified_at      TIMESTAMPTZ,
    last_reviewed    TIMESTAMPTZ                NOT NULL DEFAULT now(),

    -- quando o cadastro começou
    created_at       TIMESTAMPTZ                NOT NULL DEFAULT now()
);