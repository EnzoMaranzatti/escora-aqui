-- Dados de teste: os pontos fictícios de lib/data/seed.dart.
--
-- Todos os pontos pertencem à conta de teste abaixo. Ela precisa existir antes
-- (Authentication → Users). Se não existir, o primeiro INSERT falha com
-- "null value in column owner_id".
--
-- Diferenças do seed.dart:
--   • Posição fixa em volta do centro de São José do Rio Preto (no app, os
--     pontos eram gerados em volta de onde a pessoa estava).
--   • ids fixos (…0101 a …0114 para pontos, …0201 a …0215 para metas), para as
--     metas e a fila conseguirem apontar para o ponto certo.
--   • Datas relativas a hoje, como no Dart: current_date + 6 = daqui a 6 dias.
--   • Sem avaliações nem doações: cada uma precisa de um doador de verdade.
--     O "current" das metas já vem preenchido para as barras de progresso.
--   • photo_path aponta para a foto de banco em assets/images/places/.
--   • Posição no PostGIS: longitude primeiro, depois latitude.

-- A conta de teste também entra na equipe, para testar o painel de validação.
UPDATE public.profiles SET is_team = true, first_name = 'Diego'
WHERE id = (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com');

-- ── Pontos ativos ───────────────────────────────────────────

INSERT INTO public.places (
    id, owner_id, status, name, type_label, kind, responsible,
    cnpj, legal_name, cnpj_status, indicated_by,
    about, distributes, causes, accepts,
    street, number, neighborhood, city, location,
    hours, receive_days, photo_path,
    pix_key_type, pix_key, payee,
    verified_at, last_reviewed
) VALUES
(
    '00000000-0000-4000-8000-000000000101',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Casa Exemplo', 'Igreja', 'church', 'Helena Prado',
    '12.345.678/0001-90', 'Associação Beneficente Casa Exemplo', 'ativa', NULL,
    'Acolhemos pessoas em situação de rua com pernoite, banho e jantar. A casa é mantida pela comunidade da paróquia e por voluntários do bairro.',
    'Jantar todos os dias, às 19h. Cobertores e roupas às quartas.',
    '{"Roupas e agasalhos","Pessoas em situação de rua"}', '{itens,pix}',
    'Rua das Acácias', '120', 'Vila Nova', 'São José do Rio Preto', 'SRID=4326;POINT(-49.38637 -20.80316)',
    'segunda a sábado, das 8h às 18h', '{1,2,3,4,5,6}', 'assets/images/places/casa-exemplo.jpg',
    'CNPJ', '12.345.678/0001-90', 'Associação Beneficente Casa Exemplo',
    now() - interval '33 days', now()
),
(
    '00000000-0000-4000-8000-000000000102',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Instituição Santo Dumont', 'ONG', 'care', 'Paulo Tavares',
    '23.456.789/0001-01', 'Instituto Santo Dumont de Apoio à Criança', 'ativa', NULL,
    'Atendemos crianças com doenças crônicas e suas famílias, com acompanhamento de saúde, transporte para consultas e apoio com medicamentos.',
    NULL,
    '{"Crianças","Saúde"}', '{pix}',
    'Avenida Brasil', '2.410', 'Jardim Santo Antônio', 'São José do Rio Preto', 'SRID=4326;POINT(-49.35466 -20.78779)',
    'segunda a sexta, das 9h às 17h', '{1,2,3,4,5}', 'assets/images/places/santo-dumont.jpg',
    'CNPJ', '23.456.789/0001-01', 'Instituto Santo Dumont de Apoio à Criança',
    now() - interval '41 days', now()
),
(
    '00000000-0000-4000-8000-000000000103',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Instituição Liberal', 'Escola', 'school', 'Sônia Ribeiro',
    '34.567.890/0001-12', 'Associação Educacional Liberal', 'ativa', NULL,
    'Escola comunitária de ensino fundamental, com 160 alunos em período integral.',
    'Uniforme e material escolar no início de cada semestre.',
    '{"Educação","Material escolar"}', '{itens,voluntariado}',
    'Rua Bernardino de Campos', '845', 'Boa Vista', 'São José do Rio Preto', 'SRID=4326;POINT(-49.37099 -20.82487)',
    'segunda a sexta, das 7h às 17h', '{1,2,3,4,5}', 'assets/images/places/liberal.jpg',
    NULL, NULL, NULL,
    now() - interval '58 days', now()
),
(
    '00000000-0000-4000-8000-000000000104',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Projeto Semear', 'Coletivo', 'school', 'Lucas Andrade',
    NULL, '', '', '00000000-0000-4000-8000-000000000103',
    'Coletivo de professores voluntários que dá reforço escolar gratuito para crianças do bairro.',
    NULL,
    '{"Crianças","Educação"}', '{voluntariado}',
    'Rua Aurora', '77', 'Eldorado', 'São José do Rio Preto', 'SRID=4326;POINT(-49.39886 -20.81673)',
    'sábados, das 8h às 13h', '{6}', 'assets/images/places/semear.jpg',
    NULL, NULL, NULL,
    now() - interval '20 days', now()
),
(
    '00000000-0000-4000-8000-000000000105',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Cozinha Comunitária Jardim', 'Associação', 'care', 'Rosa Lima',
    '45.678.901/0001-23', 'Associação de Moradores do Jardim', 'ativa', NULL,
    'Servimos almoço de segunda a sexta para famílias do bairro, com alimentos doados e comprados em mutirão.',
    'Almoço de segunda a sexta, das 11h às 13h.',
    '{"Alimentos"}', '{itens}',
    'Rua Ipiranga', '1.032', 'Redentora', 'São José do Rio Preto', 'SRID=4326;POINT(-49.36235 -20.81311)',
    'segunda a sexta, das 8h às 14h', '{1,2,3,4,5}', 'assets/images/places/cozinha-jardim.jpg',
    NULL, NULL, NULL,
    now() - interval '12 days', now()
),
(
    '00000000-0000-4000-8000-000000000106',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Lar Aurora', 'ONG', 'care', 'Irene Campos',
    '56.789.012/0001-34', 'Lar Aurora de Assistência ao Idoso', 'ativa', NULL,
    'Casa de longa permanência para idosos, com 14 moradores e cuidado 24 horas.',
    NULL,
    '{"Idosos","Saúde"}', '{pix,voluntariado}',
    'Rua Coronel Spínola', '310', 'Vila Ercília', 'São José do Rio Preto', 'SRID=4326;POINT(-49.38157 -20.79140)',
    'todos os dias, das 9h às 18h', '{1,2,3,4,5,6,7}', 'assets/images/places/lar-aurora.jpg',
    'E-mail', 'doacoes@laraurora.org.br', 'Lar Aurora de Assistência ao Idoso',
    -- revisão vencida (mais de 90 dias), aparece no painel da equipe
    now() - interval '70 days', now() - interval '104 days'
),
(
    '00000000-0000-4000-8000-000000000107',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Escola Viva', 'Escola', 'school', 'Marcos Faria',
    '67.890.123/0001-45', 'Instituto Educacional Escola Viva', 'ativa', NULL,
    'Escola de educação de jovens e adultos, com turmas à tarde e à noite.',
    NULL,
    '{"Material escolar","Educação"}', '{itens}',
    'Rua Tiradentes', '58', 'São Deocleciano', 'São José do Rio Preto', 'SRID=4326;POINT(-49.34601 -20.80768)',
    'segunda a sexta, das 13h às 21h', '{1,2,3,4,5}', 'assets/images/places/escola-viva.jpg',
    NULL, NULL, NULL,
    now() - interval '25 days', now()
),
(
    '00000000-0000-4000-8000-000000000108',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Abrigo Recanto', 'Associação', 'church', 'Fábio Nunes',
    '78.901.234/0001-56', 'Associação Recanto de Acolhida', 'ativa', NULL,
    'Abrigo temporário com 30 vagas para pessoas em situação de rua, com apoio para documentos e emprego.',
    NULL,
    '{"Pessoas em situação de rua","Higiene e limpeza"}', '{itens,voluntariado}',
    'Rua das Palmeiras', '402', 'Jardim Alto Alegre', 'São José do Rio Preto', 'SRID=4326;POINT(-49.40655 -20.79502)',
    'todos os dias, das 8h às 20h', '{1,2,3,4,5,6,7}', 'assets/images/places/abrigo-recanto.jpg',
    NULL, NULL, NULL,
    now() - interval '47 days', now()
),
(
    '00000000-0000-4000-8000-000000000109',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Associação Vila Nova', 'Associação', 'church', 'Antônio Melo',
    '89.012.345/0001-67', 'Associação dos Moradores da Vila Nova', 'ativa', NULL,
    'Associação de moradores que monta e entrega cestas básicas para famílias cadastradas no bairro.',
    'Cestas básicas às quintas, das 14h às 16h.',
    '{"Alimentos","Idosos"}', '{pix}',
    'Rua Pará', '1.215', 'Vila Nova', 'São José do Rio Preto', 'SRID=4326;POINT(-49.36715 -20.78055)',
    'terça e quinta, das 14h às 18h', '{2,4}', 'assets/images/places/vila-nova.jpg',
    'Telefone', '(17) 99812-4410', 'Associação dos Moradores da Vila Nova',
    now() - interval '90 days', now()
),
(
    '00000000-0000-4000-8000-000000000110',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Grupo Patas do Bairro', 'Coletivo', 'care', 'Juliana Moreira Santos',
    NULL, '', '', '00000000-0000-4000-8000-000000000109',
    'Grupo de protetores que resgata, trata e encaminha para adoção cães e gatos do bairro.',
    NULL,
    '{"Animais"}', '{itens,pix}',
    'Rua Saldanha Marinho', '96', 'Pinheirinho', 'São José do Rio Preto', 'SRID=4326;POINT(-49.39310 -20.83300)',
    'segunda a sábado, das 9h às 17h', '{1,2,3,4,5,6}', 'assets/images/places/patas.jpg',
    'Chave aleatória', '7f3c1a2e-9b4d-4e8a-a1c2-5d6e7f8a9b0c', 'Juliana Moreira Santos',
    now() - interval '16 days', now()
),
(
    '00000000-0000-4000-8000-000000000111',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Centro Comunitário Boa Vista', 'Associação', 'school', 'Tereza Gomes',
    '90.123.456/0001-78', 'Centro Comunitário Boa Vista', 'ativa', NULL,
    'Centro comunitário com biblioteca, oficinas e reforço escolar para crianças e adolescentes.',
    NULL,
    '{"Educação","Crianças"}', '{voluntariado}',
    'Rua Voluntários de São Paulo', '3.120', 'Boa Vista', 'São José do Rio Preto', 'SRID=4326;POINT(-49.35081 -20.83120)',
    'segunda a sexta, das 13h às 18h', '{1,2,3,4,5}', 'assets/images/places/boa-vista.jpg',
    NULL, NULL, NULL,
    -- revisão vencida (mais de 90 dias)
    now() - interval '64 days', now() - interval '97 days'
),
(
    '00000000-0000-4000-8000-000000000112',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'active', 'Paróquia São Lucas', 'Igreja', 'church', 'Pe. Renato',
    '01.234.567/0001-89', 'Mitra Diocesana · Paróquia São Lucas', 'ativa', NULL,
    'Paróquia que organiza a campanha do agasalho para três comunidades da zona norte.',
    NULL,
    '{"Alimentos","Roupas e agasalhos"}', '{itens}',
    'Rua São Lucas', '15', 'Solo Sagrado', 'São José do Rio Preto', 'SRID=4326;POINT(-49.37772 -20.83934)',
    'segunda a sábado, das 8h às 12h', '{1,2,3,4,5,6}', 'assets/images/places/sao-lucas.jpg',
    NULL, NULL, NULL,
    now() - interval '6 days', now()
);

-- ── Pontos em análise (fila da equipe) ──────────────────────

INSERT INTO public.places (
    id, owner_id, status, name, type_label, kind, responsible, phone,
    cnpj, legal_name, cnpj_status, indicated_by,
    about, causes, accepts,
    street, number, neighborhood, city, location,
    hours, receive_days, photo_path,
    pix_key_type, pix_key, payee
) VALUES
(
    '00000000-0000-4000-8000-000000000113',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'review', 'Sopão Esperança', 'Igreja', 'church', 'Cláudia Reis', '(17) 99645-2210',
    '11.222.333/0001-44', 'Paróquia Nossa Senhora da Esperança', 'ativa', NULL,
    'Servimos sopa às sextas para pessoas em situação de rua da região central.',
    '{"Alimentos","Pessoas em situação de rua"}', '{itens,pix}',
    'Rua Cuiabá', '480', 'Jardim Simões', 'São José do Rio Preto', 'SRID=4326;POINT(-49.40271 -20.82577)',
    'sexta, das 17h às 21h', '{5}', 'assets/images/places/sopao-esperanca.jpg',
    'CNPJ', '11.222.333/0001-44', 'Paróquia Nossa Senhora da Esperança'
),
(
    '00000000-0000-4000-8000-000000000114',
    (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
    'review', 'Costura Solidária', 'Coletivo', 'care', 'Dona Cida', '(17) 98120-7733',
    NULL, '', '', '00000000-0000-4000-8000-000000000112',
    'Oficina de costura que transforma roupas doadas em agasalhos e cobertores.',
    '{"Roupas e agasalhos"}', '{itens,voluntariado}',
    'Rua General Glicério', '2.050', 'Centro', 'São José do Rio Preto', 'SRID=4326;POINT(-49.34313 -20.79412)',
    'terça a sábado, das 9h às 16h', '{2,3,4,5,6}', 'assets/images/places/costura-solidaria.jpg',
    NULL, NULL, NULL
);

INSERT INTO public.submissions (place_id, kind, sent_at) VALUES
    ('00000000-0000-4000-8000-000000000113', 'novo', now() - interval '5 days'),
    ('00000000-0000-4000-8000-000000000114', 'novo', now() - interval '1 day');

-- ── Metas de itens e Pix ────────────────────────────────────

INSERT INTO public.goals (
    id, place_id, type, target, current, item, unit, deadline, reason, cause, status, done_at
) VALUES
    ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
     'itens', 40, 22, 'cobertores', 'unidades', current_date + 6,
     'a frente fria aumentou o número de acolhidos.', 'Roupas e agasalhos', 'open', NULL),
    ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000101',
     'pix', 1500, 640, '', 'unidades', current_date + 12,
     'consertar o fogão industrial da cozinha, que parou na semana passada.', 'Pessoas em situação de rua', 'open', NULL),
    ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000102',
     'pix', 3000, 2160, '', 'unidades', current_date + 3,
     'comprar remédios de uso contínuo para 18 crianças atendidas.', 'Saúde', 'open', NULL),
    ('00000000-0000-4000-8000-000000000205', '00000000-0000-4000-8000-000000000103',
     'itens', 25, 10, 'material escolar', 'kits', current_date + 20,
     '12 alunos novos chegaram depois do início das aulas.', 'Material escolar', 'open', NULL),
    ('00000000-0000-4000-8000-000000000207', '00000000-0000-4000-8000-000000000105',
     'itens', 30, 19, 'arroz', 'kg', current_date + 4,
     'o número de famílias atendidas subiu de 40 para 55.', 'Alimentos', 'open', NULL),
    ('00000000-0000-4000-8000-000000000208', '00000000-0000-4000-8000-000000000106',
     'pix', 1200, 580, '', 'unidades', current_date + 9,
     'comprar fraldas geriátricas para os 14 moradores neste mês.', 'Idosos', 'open', NULL),
    ('00000000-0000-4000-8000-000000000209', '00000000-0000-4000-8000-000000000107',
     'itens', 60, 15, 'cadernos', 'unidades', current_date + 25,
     'a escola abriu uma turma noturna para adultos.', 'Material escolar', 'open', NULL),
    ('00000000-0000-4000-8000-000000000210', '00000000-0000-4000-8000-000000000108',
     'itens', 80, 46, 'higiene', 'kits', current_date + 5,
     'o abrigo passou a receber pessoas de outros bairros no inverno.', 'Higiene e limpeza', 'open', NULL),
    -- meta concluída há 2 dias
    ('00000000-0000-4000-8000-000000000211', '00000000-0000-4000-8000-000000000109',
     'pix', 2500, 2500, '', 'unidades', current_date + 2,
     'montar 25 cestas básicas para as famílias cadastradas.', 'Alimentos', 'done', now() - interval '2 days'),
    ('00000000-0000-4000-8000-000000000212', '00000000-0000-4000-8000-000000000110',
     'itens', 50, 18, 'ração', 'kg', current_date + 2,
     '12 resgates neste mês, e o estoque acaba na sexta.', 'Animais', 'open', NULL),
    -- meta que venceu sem chegar no alvo
    ('00000000-0000-4000-8000-000000000213', '00000000-0000-4000-8000-000000000110',
     'pix', 500, 300, '', 'unidades', current_date - 2,
     'castração de 4 cães resgatados.', 'Animais', 'expired', NULL),
    ('00000000-0000-4000-8000-000000000215', '00000000-0000-4000-8000-000000000112',
     'itens', 100, 67, 'agasalhos', 'unidades', current_date + 10,
     'a campanha do inverno vai atender três comunidades este ano.', 'Roupas e agasalhos', 'open', NULL);

-- ── Metas de voluntariado ───────────────────────────────────
-- Dia da ação = próximo sábado (6) ou terça (2), a partir de amanhã.
-- isodow: 1 = segunda … 7 = domingo, igual ao weekday do Dart.

INSERT INTO public.goals (
    id, place_id, type, target, deadline, reason, cause,
    action_name, action_task, action_day, action_start, action_end
) VALUES
    ('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000103',
     'voluntariado', 10,
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'as salas precisam estar prontas para a feira de ciências.', 'Educação',
     'Mutirão de pintura das salas',
     'Lixar e pintar as paredes de três salas. A escola fornece tinta, rolos e lanche.',
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     8 * 60, 12 * 60),
    ('00000000-0000-4000-8000-000000000206', '00000000-0000-4000-8000-000000000104',
     'voluntariado', 6,
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'a turma de matemática dobrou depois das férias.', 'Educação',
     'Reforço de matemática',
     'Acompanhar grupos de 4 crianças do 5º ano nos exercícios da semana.',
     current_date + 1 + (6 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     9 * 60, 12 * 60),
    ('00000000-0000-4000-8000-000000000214', '00000000-0000-4000-8000-000000000111',
     'voluntariado', 4,
     current_date + 1 + (2 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     'a biblioteca recebeu 300 livros novos e quer que as crianças conheçam.', 'Educação',
     'Oficina de leitura',
     'Ler em voz alta e conversar sobre os livros com grupos de 6 crianças.',
     current_date + 1 + (2 - extract(isodow FROM current_date + 1)::int + 7) % 7,
     14 * 60, 16 * 60);

-- ── Denúncias abertas ───────────────────────────────────────

INSERT INTO public.reports (place_id, author_id, reason, body, created_at) VALUES
    ('00000000-0000-4000-8000-000000000110',
     (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
     'Suspeito de golpe', 'Pediram Pix numa conta de pessoa física, achei estranho.', now() - interval '1 day'),
    ('00000000-0000-4000-8000-000000000110',
     (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
     'As informações estão erradas', '', now() - interval '3 days'),
    ('00000000-0000-4000-8000-000000000107',
     (SELECT id FROM auth.users WHERE email = 'dev.drenato@gmail.com'),
     'O ponto não funciona mais', 'Fui no sábado e estava fechado.', now() - interval '2 days');
