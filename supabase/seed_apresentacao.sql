-- Dados de apresentação: doadores, doações, avaliações, avisos e mais pontos.
--
-- Rode DEPOIS do seed.sql, uma vez só, no SQL Editor do Supabase (cole tudo e
-- clique em Run). Se os dados já estiverem lá, o script para sem mudar nada.
--
-- Tudo é fictício:
--   • Contas demo.*@example.com (domínio reservado, não recebe e-mail). Elas
--     não têm senha: existem só para doar e avaliar, ninguém entra com elas.
--   • CNPJs com dígitos verificadores errados de propósito, para nunca
--     coincidirem com uma empresa de verdade (o app não deixaria cadastrar).
--   • Chaves Pix em @example.org ou nesses CNPJs: nenhum banco aceita.
--
-- As doações passam pelos gatilhos de verdade: a meta só sobe quando a doação
-- é confirmada, e os avisos nascem sozinhos. No fim, os horários dos avisos
-- são espalhados para não aparecer tudo como "agora".
--
-- Todas as contas que já existem quando o script roda ganham o mesmo lado de
-- doador: doações em vários estados, uma inscrição em voluntariado, uma doação
-- mensal, pontos seguidos e avisos. Contas criadas depois veem só o mapa.
-- Só a dev.drenato@gmail.com tem a Casa Exemplo (modo instituição) e a equipe:
-- Pix e itens para confirmar, histórico, uma "não encontrada" e avaliações.

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'dev.drenato@gmail.com') THEN
        RAISE EXCEPTION 'Crie a conta dev.drenato@gmail.com e rode o seed.sql antes.';
    END IF;
    IF EXISTS (SELECT 1 FROM auth.users WHERE email LIKE 'demo.%@example.com') THEN
        RAISE EXCEPTION 'Os dados de apresentação já estão no banco.';
    END IF;
END;
$$;

CREATE TEMP TABLE demo_dev ON COMMIT DROP AS
SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com';

-- As contas reais (criadas antes das fictícias logo abaixo).
CREATE TEMP TABLE demo_people ON COMMIT DROP AS
SELECT p.id FROM public.profiles p;

-- ── Contas fictícias ────────────────────────────────────────
-- 301 a 310 doam; 311 a 316 são responsáveis pelos pontos novos.
-- O gatilho on_auth_user_created cria o perfil com o primeiro nome.

INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
)
SELECT
    '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
    u.email, '', now() - interval '40 days',
    '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', u.name),
    now() - interval '40 days', now() - interval '40 days', '', '', '', ''
FROM (VALUES
    ('00000000-0000-4000-8000-000000000301', 'demo.ana@example.com', 'Ana Souza'),
    ('00000000-0000-4000-8000-000000000302', 'demo.bruno@example.com', 'Bruno Carvalho'),
    ('00000000-0000-4000-8000-000000000303', 'demo.camila@example.com', 'Camila Rocha'),
    ('00000000-0000-4000-8000-000000000304', 'demo.daniel@example.com', 'Daniel Pereira'),
    ('00000000-0000-4000-8000-000000000305', 'demo.eduarda@example.com', 'Eduarda Martins'),
    ('00000000-0000-4000-8000-000000000306', 'demo.felipe@example.com', 'Felipe Araújo'),
    ('00000000-0000-4000-8000-000000000307', 'demo.gabriela@example.com', 'Gabriela Lima'),
    ('00000000-0000-4000-8000-000000000308', 'demo.henrique@example.com', 'Henrique Costa'),
    ('00000000-0000-4000-8000-000000000309', 'demo.isabela@example.com', 'Isabela Ferreira'),
    ('00000000-0000-4000-8000-000000000310', 'demo.joao@example.com', 'João Batista'),
    ('00000000-0000-4000-8000-000000000311', 'demo.marcia@example.com', 'Márcia Duarte'),
    ('00000000-0000-4000-8000-000000000312', 'demo.renata@example.com', 'Renata Vieira'),
    ('00000000-0000-4000-8000-000000000313', 'demo.sergio@example.com', 'Sérgio Mendes'),
    ('00000000-0000-4000-8000-000000000314', 'demo.wagner@example.com', 'Wagner Alves'),
    ('00000000-0000-4000-8000-000000000315', 'demo.bianca@example.com', 'Bianca Torres'),
    ('00000000-0000-4000-8000-000000000316', 'demo.claudio@example.com', 'Cláudio Ramos')
) AS u (id, email, name);

-- ── Pontos novos (121 a 126) ────────────────────────────────
-- As fotos repetem as do seed: o projeto só tem essas 14.

INSERT INTO public.places (
    id, owner_id, status, name, type_label, kind, responsible, phone,
    cnpj, legal_name, cnpj_status, indicated_by,
    about, distributes, causes, accepts,
    street, number, neighborhood, city, location,
    hours, receive_days, photo_path,
    pix_key_type, pix_key, payee,
    verified_at, last_reviewed
) VALUES
(
    '00000000-0000-4000-8000-000000000121', '00000000-0000-4000-8000-000000000311',
    'active', 'Banco de Alimentos Esperança Viva', 'Associação', 'care', 'Márcia Duarte', '(17) 90000-0121',
    '23.456.789/0001-10', 'Associação Esperança Viva', 'ativa', NULL,
    'Recolhemos alimentos de mercados e feiras do bairro e montamos cestas para famílias cadastradas.',
    'Cestas básicas na primeira e na terceira sexta do mês.',
    '{"Alimentos"}', '{itens,pix}',
    'Rua Jamil Feres Kfouri', '640', 'Jardim Americano', 'São José do Rio Preto', 'SRID=4326;POINT(-49.35920 -20.82680)',
    'segunda a sexta, das 8h às 17h', '{1,2,3,4,5}', 'assets/images/places/cozinha-jardim.jpg',
    'CNPJ', '23.456.789/0001-10', 'Associação Esperança Viva',
    now() - interval '21 days', now() - interval '21 days'
),
(
    '00000000-0000-4000-8000-000000000122', '00000000-0000-4000-8000-000000000312',
    'active', 'Lar dos Pequenos', 'ONG', 'care', 'Renata Vieira', '(17) 90000-0122',
    '34.567.890/0001-21', 'Lar dos Pequenos de Rio Preto', 'ativa', NULL,
    'Acolhemos crianças de 0 a 6 anos no contraturno, enquanto as mães trabalham.',
    NULL,
    '{"Crianças","Saúde"}', '{pix,itens,voluntariado}',
    'Rua Delegado Pinto de Toledo', '1.188', 'Vila Maceno', 'São José do Rio Preto', 'SRID=4326;POINT(-49.38810 -20.82050)',
    'segunda a sexta, das 7h às 18h', '{1,2,3,4,5}', 'assets/images/places/santo-dumont.jpg',
    'E-mail', 'lardospequenos@example.org', 'Lar dos Pequenos de Rio Preto',
    now() - interval '48 days', now() - interval '12 days'
),
(
    '00000000-0000-4000-8000-000000000123', '00000000-0000-4000-8000-000000000313',
    'active', 'Escola Comunitária Novo Horizonte', 'Escola', 'school', 'Sérgio Mendes', '(17) 90000-0123',
    '45.678.901/0001-32', 'Instituto Educacional Novo Horizonte', 'ativa', NULL,
    'Reforço escolar gratuito para 80 alunos do ensino fundamental, de segunda a quinta.',
    NULL,
    '{"Educação","Material escolar"}', '{itens,voluntariado}',
    'Rua Antônio de Godoy', '2.301', 'Jardim Seyon', 'São José do Rio Preto', 'SRID=4326;POINT(-49.40120 -20.80590)',
    'segunda a quinta, das 13h às 18h', '{1,2,3,4}', 'assets/images/places/escola-viva.jpg',
    NULL, NULL, NULL,
    now() - interval '60 days', now() - interval '30 days'
),
(
    '00000000-0000-4000-8000-000000000124', '00000000-0000-4000-8000-000000000314',
    'active', 'Igreja Bom Pastor', 'Igreja', 'church', 'Wagner Alves', '(17) 90000-0124',
    '56.789.012/0001-43', 'Igreja Evangélica Bom Pastor', 'ativa', NULL,
    'Servimos café da manhã para pessoas em situação de rua e distribuímos roupas aos sábados.',
    'Café da manhã de segunda a sábado, às 7h. Roupas aos sábados.',
    '{"Pessoas em situação de rua","Roupas e agasalhos"}', '{itens,pix}',
    'Rua Siqueira Campos', '455', 'Higienópolis', 'São José do Rio Preto', 'SRID=4326;POINT(-49.36480 -20.79620)',
    'segunda a sábado, das 6h30 às 12h', '{1,2,3,4,5,6}', 'assets/images/places/sao-lucas.jpg',
    'CNPJ', '56.789.012/0001-43', 'Igreja Evangélica Bom Pastor',
    now() - interval '15 days', now() - interval '15 days'
),
(
    '00000000-0000-4000-8000-000000000125', '00000000-0000-4000-8000-000000000315',
    'active', 'Amigos dos Bichos', 'Coletivo', 'care', 'Bianca Torres', '(17) 90000-0125',
    NULL, '', '', '00000000-0000-4000-8000-000000000110',
    'Grupo de vizinhos que resgata, trata e coloca para adoção cães e gatos abandonados.',
    NULL,
    '{"Animais"}', '{itens,pix}',
    'Rua Paulo Setúbal', '89', 'Parque Industrial', 'São José do Rio Preto', 'SRID=4326;POINT(-49.41150 -20.81620)',
    'sábado e domingo, das 9h às 13h', '{6,7}', 'assets/images/places/patas.jpg',
    'E-mail', 'amigosdosbichos@example.org', 'Bianca Torres',
    now() - interval '9 days', now() - interval '9 days'
),
(
    '00000000-0000-4000-8000-000000000126', '00000000-0000-4000-8000-000000000316',
    'active', 'Casa de Repouso Vó Nena', 'ONG', 'care', 'Cláudio Ramos', '(17) 90000-0126',
    '67.890.123/0001-54', 'Associação Vó Nena de Amparo ao Idoso', 'ativa', NULL,
    'Cuidamos de 22 idosos sem família, com refeições, remédios e acompanhamento médico.',
    NULL,
    '{"Idosos","Higiene e limpeza"}', '{itens,pix,voluntariado}',
    'Rua Aníbal Carvalho', '730', 'Jardim Planalto', 'São José do Rio Preto', 'SRID=4326;POINT(-49.34020 -20.81950)',
    'todos os dias, das 8h às 20h', '{1,2,3,4,5,6,7}', 'assets/images/places/lar-aurora.jpg',
    'CNPJ', '67.890.123/0001-54', 'Associação Vó Nena de Amparo ao Idoso',
    now() - interval '70 days', now() - interval '25 days'
);

-- ── Pontos seguidos (antes das metas novas, para o aviso "abriu uma meta") ─

INSERT INTO public.follows (user_id, place_id, created_at)
SELECT p.id, f.place::uuid, f.at
FROM demo_people p
CROSS JOIN (VALUES
    ('00000000-0000-4000-8000-000000000102', now() - interval '20 days'),
    ('00000000-0000-4000-8000-000000000106', now() - interval '18 days'),
    ('00000000-0000-4000-8000-000000000110', now() - interval '10 days'),
    ('00000000-0000-4000-8000-000000000121', now() - interval '6 days')
) AS f (place, at);

INSERT INTO public.follows (user_id, place_id, created_at) VALUES
    ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000101', now() - interval '30 days'),
    ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000101', now() - interval '25 days'),
    ('00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000122', now() - interval '12 days');

-- ── Metas dos pontos novos ──────────────────────────────────
-- helpers = quantas pessoas já ajudaram antes (o "current" já vem preenchido).

INSERT INTO public.goals (
    id, place_id, type, target, current, helpers, item, unit, deadline, reason, cause, created_at
) VALUES
    ('00000000-0000-4000-8000-000000000221', '00000000-0000-4000-8000-000000000121',
     'itens', 40, 12, 5, 'cestas básicas', 'kits', current_date + 14,
     'o fim do ano aumenta a procura, e 15 famílias novas se cadastraram.', 'Alimentos', now() - interval '4 days'),
    -- as doações das contas reais (R$ 40 cada) concluem esta meta; o current
    -- é acertado logo abaixo, conforme o número de contas
    ('00000000-0000-4000-8000-000000000222', '00000000-0000-4000-8000-000000000121',
     'pix', 800, 760, 11, '', 'unidades', current_date + 5,
     'comprar um freezer usado para guardar as doações de carne.', 'Alimentos', now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000223', '00000000-0000-4000-8000-000000000122',
     'itens', 60, 21, 7, 'fraldas infantis', 'pacotes', current_date + 8,
     'cinco bebês novos entraram na creche este mês.', 'Crianças', now() - interval '6 days'),
    ('00000000-0000-4000-8000-000000000225', '00000000-0000-4000-8000-000000000123',
     'itens', 30, 9, 4, 'mochilas', 'unidades', current_date + 18,
     'muitos alunos carregam o material em sacolas plásticas.', 'Material escolar', now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000227', '00000000-0000-4000-8000-000000000124',
     'itens', 50, 31, 9, 'cobertores', 'unidades', current_date + 7,
     'a previsão é de mais uma frente fria na semana que vem.', 'Roupas e agasalhos', now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000228', '00000000-0000-4000-8000-000000000124',
     'pix', 2000, 450, 6, '', 'unidades', current_date + 30,
     'reformar o banheiro do salão onde servimos o café da manhã.', 'Pessoas em situação de rua', now() - interval '8 days'),
    ('00000000-0000-4000-8000-000000000229', '00000000-0000-4000-8000-000000000125',
     'itens', 80, 26, 8, 'ração', 'kg', current_date + 6,
     'resgatamos uma ninhada de 7 filhotes na semana passada.', 'Animais', now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000230', '00000000-0000-4000-8000-000000000126',
     'itens', 40, 17, 6, 'fraldas geriátricas', 'pacotes', current_date + 10,
     'o estoque do mês acabou antes do previsto.', 'Idosos', now() - interval '7 days'),
    ('00000000-0000-4000-8000-000000000231', '00000000-0000-4000-8000-000000000126',
     'pix', 1000, 220, 4, '', 'unidades', current_date + 20,
     'comprar duas cadeiras de banho para os moradores com pouca mobilidade.', 'Idosos', now() - interval '11 days');

-- Voluntariado: próximo sábado (6) e próxima terça (2), como no seed.sql.
INSERT INTO public.goals (
    id, place_id, type, target, deadline, reason, cause,
    action_name, action_task, action_day, action_start, action_end, created_at
) VALUES
    ('00000000-0000-4000-8000-000000000224', '00000000-0000-4000-8000-000000000122',
     'voluntariado', 5,
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'as crianças pediram uma tarde diferente no fim do mês.', 'Crianças',
     'Tarde de brincadeiras',
     'Organizar jogos, pintura e contação de histórias com as crianças de 3 a 6 anos.',
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     14 * 60, 17 * 60, now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000226', '00000000-0000-4000-8000-000000000123',
     'voluntariado', 4,
     current_date + 1 + (2 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'a turma do 3º ano ainda tem dificuldade com leitura.', 'Educação',
     'Reforço de português',
     'Ler com duplas de alunos do 3º ano e ajudar nos exercícios de escrita.',
     current_date + 1 + (2 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     14 * 60, 16 * 60, now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000232', '00000000-0000-4000-8000-000000000126',
     'voluntariado', 6,
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'os moradores sentem falta de visitas nos fins de semana.', 'Idosos',
     'Visita e café da tarde',
     'Conversar, jogar dominó e servir o café da tarde com os moradores.',
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     15 * 60, 17 * 60, now() - interval '3 days');

UPDATE public.goals
SET current = greatest(0, 800 - 40 * (SELECT count(*) FROM demo_people))
WHERE id = '00000000-0000-4000-8000-000000000222';

-- Uma vaga no mutirão para cada conta real, além das 3 fictícias.
UPDATE public.goals
SET target = greatest(target, 5 + (SELECT count(*) FROM demo_people))
WHERE id = '00000000-0000-4000-8000-000000000204';

-- As metas do seed.sql já vinham com "current", mas ninguém tinha ajudado.
UPDATE public.goals
SET helpers = helpers + greatest(2, least(14, (current / CASE WHEN type = 'pix' THEN 90 ELSE 4 END)::int))
WHERE place_id BETWEEN '00000000-0000-4000-8000-000000000101' AND '00000000-0000-4000-8000-000000000114'
  AND type <> 'voluntariado' AND current > 0;

-- ── Doações ─────────────────────────────────────────────────
-- Todas entram como o app grava (o gatilho decide o status). Depois, algumas
-- são confirmadas ou marcadas como não encontradas, como a instituição faria.

INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT d.id::uuid, coalesce(d.donor::uuid, (SELECT id FROM demo_dev)), d.place::uuid, d.goal::uuid,
       d.type::public.help_type, d.amount, d.day, d.at
FROM (VALUES
    -- Casa Exemplo (101): Pix 202 e cobertores 201
    ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000202', 'pix', 50, NULL::date, now() - interval '2 hours'),
    ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000202', 'pix', 120, NULL, now() - interval '1 day'),
    ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000202', 'pix', 30, NULL, now() - interval '6 days'),
    ('00000000-0000-4000-8000-000000000504', '00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000202', 'pix', 80, NULL, now() - interval '9 days'),
    ('00000000-0000-4000-8000-000000000505', '00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000202', 'pix', 25, NULL, now() - interval '7 days'),
    ('00000000-0000-4000-8000-000000000506', '00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', 'itens', 3, current_date + 1, now() - interval '5 hours'),
    ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', 'itens', 5, current_date + 2, now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000508', '00000000-0000-4000-8000-000000000308', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', 'itens', 4, current_date - 4, now() - interval '5 days'),
    -- outros pontos do seed
    ('00000000-0000-4000-8000-000000000511', '00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000203', 'pix', 100, NULL, now() - interval '12 days'),
    ('00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000203', 'pix', 40, NULL, now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000513', '00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000207', 'itens', 5, current_date - 3, now() - interval '6 days'),
    ('00000000-0000-4000-8000-000000000514', '00000000-0000-4000-8000-000000000309', '00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000207', 'itens', 3, current_date - 1, now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000515', '00000000-0000-4000-8000-000000000308', '00000000-0000-4000-8000-000000000106', '00000000-0000-4000-8000-000000000208', 'pix', 60, NULL, now() - interval '15 days'),
    ('00000000-0000-4000-8000-000000000516', '00000000-0000-4000-8000-000000000310', '00000000-0000-4000-8000-000000000106', '00000000-0000-4000-8000-000000000208', 'pix', 35, NULL, now() - interval '8 days'),
    ('00000000-0000-4000-8000-000000000517', '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000108', '00000000-0000-4000-8000-000000000210', 'itens', 3, current_date - 2, now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000518', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000112', '00000000-0000-4000-8000-000000000215', 'itens', 6, current_date - 6, now() - interval '10 days'),
    ('00000000-0000-4000-8000-000000000519', '00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000112', '00000000-0000-4000-8000-000000000215', 'itens', 2, current_date - 2, now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000520', '00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000110', '00000000-0000-4000-8000-000000000212', 'itens', 5, current_date - 1, now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000521', '00000000-0000-4000-8000-000000000309', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000205', 'itens', 2, current_date - 5, now() - interval '8 days'),
    -- pontos novos
    ('00000000-0000-4000-8000-000000000531', '00000000-0000-4000-8000-000000000310', '00000000-0000-4000-8000-000000000124', '00000000-0000-4000-8000-000000000227', 'itens', 4, current_date - 2, now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000532', '00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000122', '00000000-0000-4000-8000-000000000223', 'itens', 6, current_date - 1, now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000533', '00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000126', '00000000-0000-4000-8000-000000000231', 'pix', 70, NULL, now() - interval '6 days')
) AS d (id, donor, place, goal, type, amount, day, at);

-- O mesmo histórico de doador para cada conta real.
INSERT INTO public.donations (donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT p.id, d.place::uuid, d.goal::uuid, d.type::public.help_type, d.amount, d.day, d.at
FROM demo_people p
CROSS JOIN (VALUES
    ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000203', 'pix', 50, NULL::date, now() - interval '11 days'),
    ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000205', 'itens', 2, current_date - 3, now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000121', '00000000-0000-4000-8000-000000000222', 'pix', 40, NULL, now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000106', '00000000-0000-4000-8000-000000000208', 'pix', 30, NULL, now() - interval '20 hours'),
    ('00000000-0000-4000-8000-000000000108', '00000000-0000-4000-8000-000000000210', 'itens', 2, current_date + 2, now() - interval '1 day')
) AS d (place, goal, type, amount, day, at);

-- Inscrições em voluntariado (o gatilho ocupa a vaga e põe o dia da ação).
INSERT INTO public.donations (donor_id, place_id, goal_id, type, amount, created_at)
SELECT p.id, '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000204',
       'voluntariado', 1, now() - interval '2 days'
FROM demo_people p;

INSERT INTO public.donations (donor_id, place_id, goal_id, type, amount, created_at)
SELECT v.donor::uuid, v.place::uuid, v.goal::uuid, 'voluntariado', 1, v.at
FROM (VALUES
    ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000204', now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000204', now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000309', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000204', now() - interval '1 day'),
    ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000206', now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000310', '00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000206', now() - interval '1 day'),
    ('00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000111', '00000000-0000-4000-8000-000000000214', now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000122', '00000000-0000-4000-8000-000000000224', now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000122', '00000000-0000-4000-8000-000000000224', now() - interval '1 day'),
    ('00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000126', '00000000-0000-4000-8000-000000000232', now() - interval '2 days')
) AS v (donor, place, goal, at);

-- Confirmadas: um dia depois do registro (a meta sobe pelo gatilho).
UPDATE public.donations
SET status = 'confirmed', confirmed_at = created_at + interval '1 day'
WHERE id IN (
    '00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000504',
    '00000000-0000-4000-8000-000000000508', '00000000-0000-4000-8000-000000000511',
    '00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000513',
    '00000000-0000-4000-8000-000000000514', '00000000-0000-4000-8000-000000000515',
    '00000000-0000-4000-8000-000000000516', '00000000-0000-4000-8000-000000000517',
    '00000000-0000-4000-8000-000000000518', '00000000-0000-4000-8000-000000000519',
    '00000000-0000-4000-8000-000000000520', '00000000-0000-4000-8000-000000000521',
    '00000000-0000-4000-8000-000000000531', '00000000-0000-4000-8000-000000000532',
    '00000000-0000-4000-8000-000000000533'
);

-- As das contas reais: Pix da Santo Dumont, kits da Liberal e o freezer
-- (a última confirmação conclui a meta e avisa todo mundo que ajudou).
UPDATE public.donations
SET status = 'confirmed', confirmed_at = created_at + interval '1 day'
WHERE donor_id IN (SELECT id FROM demo_people)
  AND goal_id IN ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000205',
                  '00000000-0000-4000-8000-000000000222');

-- A Casa Exemplo não achou este Pix no extrato.
UPDATE public.donations SET status = 'not_found'
WHERE id = '00000000-0000-4000-8000-000000000505';

-- ── Doação mensal de cada conta real ────────────────────────

INSERT INTO public.monthly_gifts (donor_id, place_id, amount, day, since, created_at)
SELECT p.id, '00000000-0000-4000-8000-000000000106', 20, 10, current_date - 75, now() - interval '75 days'
FROM demo_people p;

-- ── Avaliações (só de doações confirmadas) ──────────────────

INSERT INTO public.reviews (donation_id, place_id, author_id, stars, comment, created_at)
SELECT d.id, d.place_id, d.donor_id, r.stars, r.comment, d.confirmed_at + interval '3 hours'
FROM (VALUES
    ('00000000-0000-4000-8000-000000000503', 5, 'Confirmaram o Pix no dia seguinte e ainda mandaram foto do fogão consertado.'),
    ('00000000-0000-4000-8000-000000000504', 4, 'Gostei de ver a meta subindo. Só demorou um pouco para confirmar.'),
    ('00000000-0000-4000-8000-000000000508', 5, 'Fui entregar os cobertores e fui muito bem recebido. Lugar sério.'),
    ('00000000-0000-4000-8000-000000000511', 5, 'Dá para ver que o dinheiro vira remédio de verdade. Recomendo.'),
    ('00000000-0000-4000-8000-000000000512', 4, 'Equipe atenciosa, responderam rápido.'),
    ('00000000-0000-4000-8000-000000000513', 5, 'Entreguei o arroz em cinco minutos, tudo organizado.'),
    ('00000000-0000-4000-8000-000000000515', 5, 'Os idosos são muito bem cuidados. Doo todo mês.'),
    ('00000000-0000-4000-8000-000000000516', 4, ''),
    ('00000000-0000-4000-8000-000000000517', 5, 'Abrigo limpo e acolhedor. Voltarei no inverno.'),
    ('00000000-0000-4000-8000-000000000518', 5, 'A paróquia separa tudo por tamanho. Dá gosto de ajudar.'),
    ('00000000-0000-4000-8000-000000000520', 3, 'Ajudam muitos animais, mas o horário de entrega é curto.'),
    ('00000000-0000-4000-8000-000000000531', 5, 'Serviram café para mais de 50 pessoas no dia em que fui.'),
    ('00000000-0000-4000-8000-000000000532', 5, 'As crianças são muito bem tratadas. Ambiente alegre.')
) AS r (donation, stars, comment)
JOIN public.donations d ON d.id = r.donation::uuid;

-- A conta dev também avaliou (uma só, para não repetir o comentário no perfil).
INSERT INTO public.reviews (donation_id, place_id, author_id, stars, comment, created_at)
SELECT d.id, d.place_id, d.donor_id, 5,
       'Transparente: a meta mostra exatamente para onde vai o dinheiro.', d.confirmed_at + interval '3 hours'
FROM public.donations d
WHERE d.donor_id = (SELECT id FROM demo_dev) AND d.goal_id = '00000000-0000-4000-8000-000000000203';

-- ── Avisos ──────────────────────────────────────────────────
-- Os gatilhos avisaram a conta dev de toda doação nos 14 pontos do seed (ela
-- é dona de todos). No app, o ponto dela é só a Casa Exemplo.
DELETE FROM public.notices
WHERE user_id = (SELECT id FROM demo_dev) AND kind = 'new_donation'
  AND created_at = now() AND place_id <> '00000000-0000-4000-8000-000000000101';

-- Os avisos criados agora ganham o horário da doação que os gerou.
UPDATE public.notices n
SET created_at = d.created_at, read = d.created_at < now() - interval '1 day'
FROM public.donations d
WHERE n.user_id = (SELECT id FROM demo_dev) AND n.kind = 'new_donation' AND n.created_at = now()
  AND d.place_id = n.place_id AND d.type <> 'voluntariado'
  AND n.body LIKE d.donor_name || ' registrou %';

UPDATE public.notices n
SET created_at = d.confirmed_at, read = d.confirmed_at < now() - interval '2 days'
FROM public.donations d
WHERE n.user_id IN (SELECT id FROM demo_people) AND n.kind IN ('confirmed', 'goal_done') AND n.created_at = now()
  AND d.donor_id = n.user_id AND d.place_id = n.place_id AND d.status = 'confirmed';

UPDATE public.notices n
SET created_at = g.created_at, read = true
FROM public.goals g
WHERE n.user_id IN (SELECT id FROM demo_people) AND n.kind = 'new_goal' AND n.created_at = now()
  AND g.place_id = n.place_id AND n.body LIKE public.fmt_amount(g, g.target, false) || ' até %';

-- A meta do freezer foi concluída pelas doações das contas reais, não agora.
UPDATE public.goals
SET done_at = now() - interval '1 day'
WHERE id = '00000000-0000-4000-8000-000000000222';

INSERT INTO public.notices (user_id, kind, title, body, place_id, read, created_at)
SELECT p.id, n.kind::public.notice_kind, n.title, n.body, n.place::uuid, n.read, n.at
FROM demo_people p
CROSS JOIN (VALUES
    ('volunteer_reminder', 'Sua ação está chegando',
     'Mutirão de pintura das salas, na Instituição Liberal, no sábado às 8h.',
     '00000000-0000-4000-8000-000000000103', false, now() - interval '40 minutes'),
    ('monthly_reminder', 'Dia da sua doação mensal',
     'R$ 20,00 para o Lar Aurora. Pague no app do seu banco e registre aqui.',
     '00000000-0000-4000-8000-000000000106', true, now() - interval '18 days')
) AS n (kind, title, body, place, read, at);

INSERT INTO public.notices (user_id, kind, title, body, place_id, read, created_at) VALUES
    ((SELECT id FROM demo_dev), 'approved',
     'Casa Exemplo foi aprovada',
     'Seu ponto já aparece no mapa com o selo de verificado.',
     '00000000-0000-4000-8000-000000000101', true, now() - interval '33 days');

COMMIT;
