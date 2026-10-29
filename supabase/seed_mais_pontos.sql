-- Mais 6 pontos fictícios (127 a 132), com propostas que o mapa ainda não
-- tinha: dignidade menstrual, cursinho popular, biblioteca, apoio a pacientes
-- com câncer, escolinha de futebol e banho para quem vive na rua.
--
-- Rode depois do seed.sql e do seed_apresentacao.sql:
--   supabase db query --linked -f supabase/seed_mais_pontos.sql
-- Se os pontos já estiverem lá, o script para sem mudar nada.
--
-- Como no seed_apresentacao.sql: contas demo.*@example.com sem senha, CNPJs
-- com dígitos errados de propósito e chaves Pix em @example.org.

BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.places WHERE id = '00000000-0000-4000-8000-000000000127') THEN
        RAISE EXCEPTION 'Os pontos 127 a 132 já estão no banco.';
    END IF;
END;
$$;

-- ── Responsáveis (317 a 322) ────────────────────────────────

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
    ('00000000-0000-4000-8000-000000000317', 'demo.larissa@example.com', 'Larissa Nogueira'),
    ('00000000-0000-4000-8000-000000000318', 'demo.rafael@example.com', 'Rafael Moura'),
    ('00000000-0000-4000-8000-000000000319', 'demo.helena@example.com', 'Helena Barros'),
    ('00000000-0000-4000-8000-000000000320', 'demo.patricia@example.com', 'Patrícia Lopes'),
    ('00000000-0000-4000-8000-000000000321', 'demo.thiago@example.com', 'Thiago Rezende'),
    ('00000000-0000-4000-8000-000000000322', 'demo.vera@example.com', 'Vera Antunes')
) AS u (id, email, name);

-- ── Pontos ──────────────────────────────────────────────────
-- Todos a menos de 5 km do centro (o raio padrão do mapa).

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
    '00000000-0000-4000-8000-000000000127', '00000000-0000-4000-8000-000000000317',
    'active', 'Coletivo Ciclo Digno', 'Coletivo', 'care', 'Larissa Nogueira', '(17) 90000-0127',
    NULL, '', '', '00000000-0000-4000-8000-000000000122',
    'Distribuímos absorventes em escolas públicas e abrigos, para nenhuma menina faltar à aula por falta deles.',
    'Kits entregues nas escolas parceiras toda segunda-feira.',
    '{"Higiene e limpeza","Crianças"}', '{itens,pix}',
    'Rua Bahia', '1.870', 'Vila Imperial', 'São José do Rio Preto', 'SRID=4326;POINT(-49.39500 -20.81500)',
    'terça e quinta, das 14h às 19h', '{2,4}', 'assets/images/places/costura-solidaria.jpg',
    'E-mail', 'ciclodigno@example.org', 'Larissa Nogueira',
    now() - interval '14 days', now() - interval '14 days'
),
(
    '00000000-0000-4000-8000-000000000128', '00000000-0000-4000-8000-000000000318',
    'active', 'Cursinho Popular Ponte', 'Escola', 'school', 'Rafael Moura', '(17) 90000-0128',
    '78.901.234/0001-65', 'Associação Cursinho Popular Ponte', 'ativa', NULL,
    'Preparamos jovens de escola pública para o Enem, com aulas à noite dadas por voluntários.',
    NULL,
    '{"Educação"}', '{voluntariado,itens}',
    'Rua Marechal Deodoro', '3.044', 'Vila Falavina', 'São José do Rio Preto', 'SRID=4326;POINT(-49.38800 -20.79900)',
    'segunda a sexta, das 18h30 às 22h', '{1,2,3,4,5}', 'assets/images/places/liberal.jpg',
    NULL, NULL, NULL,
    now() - interval '40 days', now() - interval '20 days'
),
(
    '00000000-0000-4000-8000-000000000129', '00000000-0000-4000-8000-000000000319',
    'active', 'Biblioteca Comunitária Ler Junto', 'Associação', 'school', 'Helena Barros', '(17) 90000-0129',
    '89.012.345/0001-76', 'Associação Ler Junto', 'ativa', NULL,
    'Biblioteca aberta para o bairro, com empréstimo de livros e contação de histórias para crianças.',
    NULL,
    '{"Material escolar","Crianças","Educação"}', '{itens,voluntariado}',
    'Rua Independência', '512', 'Jardim Novo Mundo', 'São José do Rio Preto', 'SRID=4326;POINT(-49.37200 -20.83000)',
    'terça a sábado, das 9h às 17h', '{2,3,4,5,6}', 'assets/images/places/semear.jpg',
    NULL, NULL, NULL,
    now() - interval '55 days', now() - interval '18 days'
),
(
    '00000000-0000-4000-8000-000000000130', '00000000-0000-4000-8000-000000000320',
    'active', 'Rede Rosa de Apoio', 'ONG', 'care', 'Patrícia Lopes', '(17) 90000-0130',
    '90.123.456/0001-87', 'Rede Rosa de Apoio ao Paciente Oncológico', 'ativa', NULL,
    'Apoiamos pacientes com câncer de famílias de baixa renda: transporte para o tratamento, lenços e cestas.',
    'Lenços e cestas entregues às quartas, com hora marcada.',
    '{"Saúde"}', '{pix,itens}',
    'Rua Silva Jardim', '2.260', 'Parque Celeste', 'São José do Rio Preto', 'SRID=4326;POINT(-49.36000 -20.81800)',
    'segunda a sexta, das 8h às 16h', '{1,2,3,4,5}', 'assets/images/places/boa-vista.jpg',
    'CNPJ', '90.123.456/0001-87', 'Rede Rosa de Apoio ao Paciente Oncológico',
    now() - interval '90 days', now() - interval '28 days'
),
(
    '00000000-0000-4000-8000-000000000131', '00000000-0000-4000-8000-000000000321',
    'active', 'Escolinha Bom de Bola', 'Associação', 'school', 'Thiago Rezende', '(17) 90000-0131',
    '13.579.246/0001-80', 'Associação Esportiva Bom de Bola', 'ativa', NULL,
    'Futebol gratuito para 70 crianças de 7 a 14 anos, com a condição de estarem matriculadas na escola.',
    NULL,
    '{"Crianças","Educação"}', '{itens,voluntariado}',
    'Avenida Philadelpho Gouveia Netto', '1.400', 'Bom Jardim', 'São José do Rio Preto', 'SRID=4326;POINT(-49.38100 -20.83500)',
    'terça, quinta e sábado, das 8h às 11h', '{2,4,6}', 'assets/images/places/vila-nova.jpg',
    NULL, NULL, NULL,
    now() - interval '35 days', now() - interval '10 days'
),
(
    '00000000-0000-4000-8000-000000000132', '00000000-0000-4000-8000-000000000322',
    'active', 'Banho Solidário Centro', 'Coletivo', 'church', 'Vera Antunes', '(17) 90000-0132',
    NULL, '', '', '00000000-0000-4000-8000-000000000124',
    'Um ônibus adaptado com chuveiros que oferece banho, roupa limpa e corte de cabelo a quem vive na rua.',
    'Banho às quartas e sábados, das 8h às 12h, na praça.',
    '{"Pessoas em situação de rua","Higiene e limpeza"}', '{itens,voluntariado,pix}',
    'Rua Prudente de Moraes', '88', 'Vila Elvira', 'São José do Rio Preto', 'SRID=4326;POINT(-49.35600 -20.80800)',
    'quarta e sábado, das 7h às 13h', '{3,6}', 'assets/images/places/sopao-esperanca.jpg',
    'E-mail', 'banhosolidario@example.org', 'Vera Antunes',
    now() - interval '7 days', now() - interval '7 days'
);

-- ── Metas ───────────────────────────────────────────────────

INSERT INTO public.goals (
    id, place_id, type, target, current, helpers, item, unit, deadline, reason, cause, created_at
) VALUES
    ('00000000-0000-4000-8000-000000000233', '00000000-0000-4000-8000-000000000127',
     'itens', 200, 64, 13, 'absorventes', 'pacotes', current_date + 12,
     'duas escolas novas entraram no projeto e pediram kits para 90 alunas.', 'Higiene e limpeza', now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000234', '00000000-0000-4000-8000-000000000127',
     'pix', 600, 135, 5, '', 'unidades', current_date + 25,
     'instalar dispensers de absorvente nos banheiros de três escolas.', 'Higiene e limpeza', now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000236', '00000000-0000-4000-8000-000000000128',
     'itens', 40, 12, 6, 'apostilas do Enem', 'unidades', current_date + 9,
     'a turma deste semestre começou com 40 alunos, e só 12 têm apostila.', 'Educação', now() - interval '6 days'),
    ('00000000-0000-4000-8000-000000000237', '00000000-0000-4000-8000-000000000129',
     'itens', 150, 88, 21, 'livros infantis', 'unidades', current_date + 15,
     'as estantes das crianças estão quase vazias depois do mês das férias.', 'Crianças', now() - interval '8 days'),
    ('00000000-0000-4000-8000-000000000239', '00000000-0000-4000-8000-000000000130',
     'pix', 2500, 1310, 24, '', 'unidades', current_date + 11,
     'pagar a van que leva 9 pacientes para a quimioterapia em Barretos durante um mês.', 'Saúde', now() - interval '10 days'),
    ('00000000-0000-4000-8000-000000000240', '00000000-0000-4000-8000-000000000130',
     'itens', 80, 35, 9, 'lenços para cabeça', 'unidades', current_date + 20,
     'doze pacientes novas começaram o tratamento este mês.', 'Saúde', now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000241', '00000000-0000-4000-8000-000000000131',
     'itens', 25, 6, 3, 'chuteiras', 'unidades', current_date + 14,
     'muitos alunos treinam descalços ou de chinelo na quadra de cimento.', 'Crianças', now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000243', '00000000-0000-4000-8000-000000000132',
     'itens', 120, 47, 15, 'higiene', 'kits', current_date + 6,
     'o número de pessoas atendidas por dia passou de 30 para 45.', 'Higiene e limpeza', now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000244', '00000000-0000-4000-8000-000000000132',
     'pix', 900, 410, 12, '', 'unidades', current_date + 18,
     'trocar o aquecedor de água do ônibus, que queimou na semana passada.', 'Pessoas em situação de rua', now() - interval '6 days');

-- Voluntariado: próximo sábado (6), próxima quarta (3) e próxima quinta (4).
INSERT INTO public.goals (
    id, place_id, type, target, deadline, reason, cause,
    action_name, action_task, action_day, action_start, action_end, created_at
) VALUES
    ('00000000-0000-4000-8000-000000000235', '00000000-0000-4000-8000-000000000128',
     'voluntariado', 3,
     current_date + 1 + (4 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'o simulado é no sábado, e os alunos têm muitas dúvidas de matemática.', 'Educação',
     'Plantão de dúvidas de matemática',
     'Tirar dúvidas de matemática do Enem com grupos de 5 alunos. Precisa saber o conteúdo do ensino médio.',
     current_date + 1 + (4 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     19 * 60, 21 * 60 + 30, now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000238', '00000000-0000-4000-8000-000000000129',
     'voluntariado', 4,
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'a roda de leitura de sábado cresceu e precisa de mais gente.', 'Crianças',
     'Contação de histórias',
     'Ler em voz alta para crianças de 4 a 8 anos e ajudar na atividade de desenho depois.',
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     9 * 60, 11 * 60, now() - interval '4 days'),
    ('00000000-0000-4000-8000-000000000242', '00000000-0000-4000-8000-000000000131',
     'voluntariado', 4,
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'o treinador está sozinho com 30 crianças aos sábados.', 'Crianças',
     'Ajudante de treino',
     'Montar os circuitos, organizar os times e ficar de olho na hidratação das crianças.',
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     8 * 60, 11 * 60, now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000245', '00000000-0000-4000-8000-000000000132',
     'voluntariado', 6,
     current_date + 1 + (3 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'quarta-feira é o dia mais cheio do ônibus.', 'Pessoas em situação de rua',
     'Mutirão do banho',
     'Receber as pessoas, entregar toalhas e kits e servir o café. A equipe orienta no começo.',
     current_date + 1 + (3 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     7 * 60, 12 * 60, now() - interval '1 day');

-- ── Algumas doações e avaliações de doadores fictícios ──────

INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT d.id::uuid, d.donor::uuid, d.place::uuid, d.goal::uuid, d.type::public.help_type, d.amount, d.day, d.at
FROM (VALUES
    ('00000000-0000-4000-8000-000000000551', '00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000127', '00000000-0000-4000-8000-000000000233', 'itens', 10, current_date - 3, now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000552', '00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000130', '00000000-0000-4000-8000-000000000239', 'pix', 100, NULL::date, now() - interval '7 days'),
    ('00000000-0000-4000-8000-000000000553', '00000000-0000-4000-8000-000000000308', '00000000-0000-4000-8000-000000000129', '00000000-0000-4000-8000-000000000237', 'itens', 12, current_date - 4, now() - interval '6 days'),
    ('00000000-0000-4000-8000-000000000554', '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000132', '00000000-0000-4000-8000-000000000243', 'itens', 5, current_date - 2, now() - interval '3 days')
) AS d (id, donor, place, goal, type, amount, day, at);

UPDATE public.donations
SET status = 'confirmed', confirmed_at = created_at + interval '1 day'
WHERE id IN (
    '00000000-0000-4000-8000-000000000551', '00000000-0000-4000-8000-000000000552',
    '00000000-0000-4000-8000-000000000553', '00000000-0000-4000-8000-000000000554'
);

INSERT INTO public.reviews (donation_id, place_id, author_id, stars, comment, created_at)
SELECT d.id, d.place_id, d.donor_id, r.stars, r.comment, d.confirmed_at + interval '2 hours'
FROM (VALUES
    ('00000000-0000-4000-8000-000000000551', 5, 'Projeto lindo e muito necessário. Entreguei os pacotes em minutos.'),
    ('00000000-0000-4000-8000-000000000552', 5, 'Mandaram foto da van levando os pacientes. Dá confiança.'),
    ('00000000-0000-4000-8000-000000000553', 4, 'Biblioteca acolhedora. Levei meus filhos para conhecer.'),
    ('00000000-0000-4000-8000-000000000554', 5, 'O trabalho deles muda o dia de quem está na rua.')
) AS r (donation, stars, comment)
JOIN public.donations d ON d.id = r.donation::uuid;

COMMIT;
