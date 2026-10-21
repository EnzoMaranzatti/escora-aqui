-- Tabela de usuários
CREATE TABLE public.profiles(
      -- mesmo id da conta de login (auth.users)
    -- É o identificador da pessoa, ligado à conta de login. Se a conta for apagada, o perfil some junto.
    --  identificador único, um código longo
    id              uuid                PRIMARY KEY REFERENCES auth.users(id)   ON DELETE CASCADE,
    
    -- Sempre tem valor. Se não vier nada, fica um texto vazio.
    -- Nome completo
    full_name       TEXT                NOT NULL DEFAULT '',

    -- Primeiro nome. O "você" das telas
    first_name      TEXT                NOT NULL DEFAULT '',

    -- Celular(opcional)
    phone           TEXT,

    -- Data de nascimento(opcional)
    birth_date      DATE,

    -- Caminho da foto do perfil no Storage(opcional)
    -- Guarda o caminho e não a foto em si
    avatar_path     TEXT,

    -- Cidade escolhida no onboarding
    city            TEXT,

    -- Estado, sempre duas letras
    uf              CHAR(2),

    -- posição da pessoa no mapa (lat/lng)
    -- Um ponto no mapa, no sistema de coordenadas do GPS. Pode ficar vazio, para quem não deu a localização.
    position         extensions.geography(Point, 4326),

    -- Formas de ajuda escolhida(pix, itens, voluntariado)
    help_types      public.help_type[]              NOT NULL DEFAULT '{}',

    -- Causas escolhidas(Alimentos, idosos...)
    -- Uma lista de textos. Começa vazia.
    causes          TEXT[]              NOT NULL DEFAULT '{}',

    -- Preferências de aviso: começam todas ligadas
    notify_goals      BOOLEAN               NOT NULL DEFAULT true,
    notify_confirm    BOOLEAN               NOT NULL DEFAULT true,
    notify_volunteer  BOOLEAN               NOT NULL DEFAULT true,

     -- raio da busca no mapa, em km
    --  Começa em 5 e só aceita 5, 10, 20 ou 50.
    radius_km         SMALLINT              NOT NULL DEFAULT 5 CHECK (radius_km IN (5, 10, 20, 50)),

     -- Faz parte da equipe de validação?
    --  Começa em "não". Só a equipe muda isso, direto no banco.
    is_team           BOOLEAN               NOT NULL DEFAULT false,

    -- Quando o perfil foi criado
    -- Data e hora do cadastro, preenchidas sozinhas. É a última coluna, então não leva vírgula. Depois dela vem o ); que fecha a tabela.
    created_at        TIMESTAMPTZ           NOT NULL DEFAULT now()
);

-- cria uma função chamada "cuidar do usuário novo" (
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER -- é uma função feita para ser chamada por um gatilho
LANGUAGE plpgsql --escrita na linguagem de funções do Postgres

-- roda com permissão de administrador. Precisa disso porque quem está se cadastrando ainda não tem permissão para escrever em profiles
-- trava a função para usar só os nomes completos (public.profiles).
SECURITY DEFINER SET search_path = ''  

-- o corpo da função fica entre os dois cifrões duplos
AS $$ 
BEGIN

    -- Insere uma linha nova preenchendo as três colunas correspondentes
    INSERT INTO public.profiles(id, full_name, first_name)

    -- Os valores na mesma ordem das colunas
    VALUES(
        -- new é a conta que acabou de ser criada. new.id é o id dela
        new.id, 
        coalesce(new.raw_user_meta_data ->> 'full_name', ''),

        --  corta o nome nos espaços e pega o 1º pedaço
        coalesce(split_part(new.raw_user_meta_data ->> 'full_name', ' ', 1), '')
    );

    --  todo gatilho precisa devolver a linha no fim, é a regra do Postgres
    RETURN new;
END;
$$;

--  cria um gatilho chamado "quando uma conta for criada"
CREATE Trigger on_auth_user_created
    --  dispara logo depois que uma linha entra em auth.users
    AFTER INSERT ON auth.users
    --  uma vez para cada conta nova
    -- chama a função de cima
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();