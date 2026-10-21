-- WITH SCHEMA EXTENSIONS: Guarda o pacote na "pasta" extensions, sepaarada das coisas do app.

-- Liga o PostGIS: faz o banco entender localização(lat/lng).
-- É usado na busca de pontos por raio no mapa
CREATE extension IF NOT EXISTS postgis WITH SCHEMA extensions;

-- CREATE TYPE: Cria um tipo novo
-- Public: A pasta do banco onde ele fica. public é a principal, onde ficam as coisas do app.
-- help_type: O nome do tipo, em snake_case(palavras separadas por _)
-- as ENUM: é uma lista fechada
-- ('pix', ...): Valores permitidos entre aspas simples
-- ;: Fim do comando

-- formas de ajuda(Helptype no Dart).
CREATE TYPE public.help_type as ENUM('pix', 'itens', 'voluntariado');

-- Ícone do pim no mapa(Placekind no dart).
CREATE TYPE public.place_kind as ENUM('school', 'church', 'care');

-- Situação do ponto de apoio(PlaceStatus no dart).
CREATE TYPE public.place_status as ENUM(
     'draft', 'review', 'awaiting_indication', 'adjust', 'refused', 'active', 'paused', 'removed'
);

-- Situação da meta (GoalStatus no Dart).
CREATE TYPE public.goal_status as ENUM ('open', 'done', 'expired', 'closed');

-- Situação da doação (DonationStatus no Dart).
CREATE TYPE public.donation_status as ENUM(
    'waiting', 'confirmed', 'not_found', 'enrolled', 'items_agreed', 'cancelled', 'absent'
);

-- Tipos de aviso(NoticeKind no Dart).
-- Os 6 primeiros são do doador;, os 6 últimos, da instituição.
CREATE TYPE public.notice_kind as ENUM(
    'new_goal', 'confirmed', 'not_found', 'volunteer_reminder', 'goal_done', 'monthly_reminder', 'approved', 'adjust', 'refused', 'paused', 'reactivated', 'new_donation'
);

-- Tipo de item na fila da equipe(SubmissionKind no Dart).
CREATE TYPE public.submission_kind as ENUM('novo', 'correcao', 'mudanca');
