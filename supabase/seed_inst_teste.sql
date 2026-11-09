-- ── Conta de instituição da apresentação ───────────────────────
--
-- Monta o Instituto Raízes do Bairro para a conta
--     inst.teste@escoraaqui.app / escora2026
-- criada pela API de signup. A instituição é fictícia, mas os números são
-- coerentes entre si: o que o painel soma bate com as doações da lista, e o
-- que cada meta mostra bate com as doações confirmadas daquela meta.
--
-- Os doadores são os fictícios do seed_apresentacao.sql (301 a 310) mais a
-- conta doador.teste@escoraaqui.app.
--
-- Rodar no SQL Editor do painel. Sem TEMP TABLE de propósito: o SQL Editor
-- não mantém tabela temporária entre os comandos do script.
--
-- As doações entram pelo mesmo caminho do app, não "prontas": o
-- check_new_donation (fase 4) é um BEFORE INSERT que decide o status pelo
-- tipo (pix → waiting, itens → items_agreed, voluntariado → enrolled) e
-- zera o confirmed_at, então não adianta inserir já confirmado. O script
-- insere e depois confirma com UPDATE, que é o que a instituição faz na
-- tela. Quem soma o progresso das metas é o gatilho da fase 5.
--
-- Por isso as metas nascem zeradas aqui: os 47 kits, os R$ 2.180 e as 200
-- cestas são construídos pelas doações, e a meta das cestas se fecha
-- sozinha ao bater o alvo. Os números na tela são consequência dos dados,
-- não um valor digitado — se a banca perguntar, a conta fecha.

-- ── Limpeza, para poder rodar de novo ──────────────────────────
DELETE FROM public.reviews    WHERE place_id = '00000000-0000-4000-8000-0000000009a1';
DELETE FROM public.donations  WHERE place_id = '00000000-0000-4000-8000-0000000009a1';
DELETE FROM public.monthly_gifts WHERE place_id = '00000000-0000-4000-8000-0000000009a1';
DELETE FROM public.goals      WHERE place_id = '00000000-0000-4000-8000-0000000009a1';
DELETE FROM public.places     WHERE id = '00000000-0000-4000-8000-0000000009a1';

-- ── O ponto ────────────────────────────────────────────────────
INSERT INTO public.places (
    id, owner_id, status, name, type_label, kind, responsible, phone,
    cnpj, legal_name, cnpj_status, indicated_by,
    about, distributes, causes, accepts,
    street, number, neighborhood, city, location,
    hours, receive_days, photo_path,
    pix_key_type, pix_key, payee,
    verified_at, last_reviewed
)
SELECT
    '00000000-0000-4000-8000-0000000009a1',
    (SELECT id FROM auth.users WHERE email = 'inst.teste@escoraaqui.app'),
    'active', 'Instituto Raízes do Bairro', 'Associação', 'care',
    'Vera Lúcia Monteiro', '(17) 98814-2207',
    '45.678.901/0001-75', 'Associação Raízes do Bairro', 'ativa', NULL,
    'Atendemos 62 crianças no contraturno escolar com reforço de leitura e matemática, lanche e atividades de arte. As famílias atendidas recebem cesta básica uma vez por mês.',
    'Reforço escolar de segunda a quinta, das 13h30 às 17h. Cestas na última sexta do mês, das 9h às 15h.',
    '{"Educação","Crianças","Alimentos"}', '{itens,pix,voluntariado}',
    'Rua Independência', '1255', 'Vila Toninho', 'São José do Rio Preto',
    'SRID=4326;POINT(-49.39960 -20.84120)',
    'segunda a sexta, das 8h às 18h', '{1,2,3,4,5}',
    'assets/images/places/escola-viva.jpg',
    'CNPJ', '45.678.901/0001-75', 'Associação Raízes do Bairro',
    now() - interval '2 months', now() - interval '12 days'
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'inst.teste@escoraaqui.app');

-- ── Metas ──────────────────────────────────────────────────────
-- current e helpers batem com as doações confirmadas mais abaixo.
INSERT INTO public.goals (
    id, place_id, type, target, current, helpers, item, unit,
    deadline, reason, cause, status, done_at
) VALUES
    -- Perto de fechar: é a que o painel mostra primeiro, por ter o prazo mais curto.
    ('00000000-0000-4000-8000-0000000009b1', '00000000-0000-4000-8000-0000000009a1',
     'itens', 60, 0, 0, 'material escolar', 'kits', current_date + 8,
     'as turmas do contraturno voltam em duas semanas e 13 crianças ainda estão sem material.',
     'Material escolar', 'open', NULL),
    -- No meio do caminho.
    ('00000000-0000-4000-8000-0000000009b2', '00000000-0000-4000-8000-0000000009a1',
     'pix', 3500, 0, 0, '', 'unidades', current_date + 22,
     'reformar o telhado da sala de leitura, que começou a vazar nas chuvas de novembro.',
     'Educação', 'open', NULL),
    -- Nasce aberta e com prazo no futuro porque o banco recusa doação para
    -- meta fechada. As 8 doações abaixo a levam ao alvo e o gatilho a fecha;
    -- no fim do script o prazo e a data de conclusão voltam para o passado.
    ('00000000-0000-4000-8000-0000000009b4', '00000000-0000-4000-8000-0000000009a1',
     'itens', 200, 0, 0, 'cestas básicas', 'unidades', current_date + 30,
     'garantir a cesta do mês para as 200 famílias cadastradas.',
     'Alimentos', 'open', NULL);

-- Voluntariado: horário em minutos desde a meia-noite (13h30 = 810, 17h = 1020).
-- current fica em 0 porque a ação ainda não aconteceu — os 7 inscritos
-- aparecem pela lista de doações, não pelo progresso da meta.
INSERT INTO public.goals (
    id, place_id, type, target, current, helpers, deadline, reason, cause, status,
    action_name, action_task, action_day, action_start, action_end
) VALUES
    ('00000000-0000-4000-8000-0000000009b3', '00000000-0000-4000-8000-0000000009a1',
     'voluntariado', 12, 0, 0, current_date + 5,
     'cada voluntário acompanha um grupo de quatro crianças na leitura.',
     'Educação', 'open',
     'Mutirão de reforço escolar',
     'Ler com grupos de quatro crianças e ajudar nos exercícios de matemática. Não precisa ser professor: a equipe orienta na hora.',
     current_date + 5, 810, 1020);

-- ── Doações confirmadas: meta do material escolar (19 pessoas, 47 kits) ──
INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT ('00000000-0000-4000-8000-000000009' || d.n)::uuid,
       (SELECT id FROM auth.users WHERE email = d.quem),
       '00000000-0000-4000-8000-0000000009a1',
       '00000000-0000-4000-8000-0000000009b1',
       'itens', d.qtd,
       (current_date - d.dias + 1),
       now() - (d.dias || ' days')::interval
FROM (VALUES
    ('d01', 'demo.ana@example.com',       2, 38), ('d02', 'demo.bruno@example.com',    3, 36),
    ('d03', 'demo.camila@example.com',    1, 34), ('d04', 'demo.daniel@example.com',   4, 32),
    ('d05', 'demo.eduarda@example.com',   2, 30), ('d06', 'demo.felipe@example.com',   3, 28),
    ('d07', 'demo.gabriela@example.com',  2, 26), ('d08', 'demo.henrique@example.com', 1, 24),
    ('d09', 'demo.isabela@example.com',   5, 22), ('d0a', 'demo.joao@example.com',     2, 20),
    ('d0b', 'doador.teste@escoraaqui.app',3, 18), ('d0c', 'demo.ana@example.com',      2, 16),
    ('d0d', 'demo.camila@example.com',    1, 14), ('d0e', 'demo.daniel@example.com',   4, 12),
    ('d0f', 'demo.felipe@example.com',    3, 10), ('d10', 'demo.gabriela@example.com', 2,  8),
    ('d11', 'demo.isabela@example.com',   2,  6), ('d12', 'demo.joao@example.com',     3,  4),
    ('d13', 'demo.bruno@example.com',     2,  2)
) AS d (n, quem, qtd, dias)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = d.quem);

-- ── Doações confirmadas: meta do telhado (14 pessoas, R$ 2.180) ──
INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, created_at)
SELECT ('00000000-0000-4000-8000-000000009' || d.n)::uuid,
       (SELECT id FROM auth.users WHERE email = d.quem),
       '00000000-0000-4000-8000-0000000009a1',
       '00000000-0000-4000-8000-0000000009b2',
       'pix', d.valor,
       now() - (d.dias || ' days')::interval
FROM (VALUES
    ('e01', 'demo.ana@example.com',        50, 40), ('e02', 'demo.bruno@example.com',   100, 37),
    ('e03', 'demo.camila@example.com',    200, 35), ('e04', 'demo.daniel@example.com',  150, 33),
    ('e05', 'demo.eduarda@example.com',    30, 29), ('e06', 'demo.felipe@example.com',  500, 27),
    ('e07', 'demo.gabriela@example.com',  100, 25), ('e08', 'demo.henrique@example.com', 80, 21),
    ('e09', 'demo.isabela@example.com',   120, 17), ('e0a', 'demo.joao@example.com',    250, 15),
    ('e0b', 'doador.teste@escoraaqui.app', 60, 11), ('e0c', 'demo.ana@example.com',     200,  9),
    ('e0d', 'demo.eduarda@example.com',   140,  5), ('e0e', 'demo.henrique@example.com',200,  3)
) AS d (n, quem, valor, dias)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = d.quem);

-- ── Doações confirmadas: meta das cestas, já concluída (8 pessoas, 200) ──
INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT ('00000000-0000-4000-8000-000000009' || d.n)::uuid,
       (SELECT id FROM auth.users WHERE email = d.quem),
       '00000000-0000-4000-8000-0000000009a1',
       '00000000-0000-4000-8000-0000000009b4',
       'itens', d.qtd,
       (current_date - d.dias + 1),
       now() - (d.dias || ' days')::interval
FROM (VALUES
    ('f01', 'demo.ana@example.com',      40, 52), ('f02', 'demo.camila@example.com',   30, 48),
    ('f03', 'demo.daniel@example.com',   25, 44), ('f04', 'demo.felipe@example.com',   20, 40),
    ('f05', 'demo.gabriela@example.com', 35, 30), ('f06', 'demo.isabela@example.com',  20, 20),
    ('f07', 'demo.joao@example.com',     15, 12), ('f08', 'demo.bruno@example.com',    15,  7)
) AS d (n, quem, qtd, dias)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = d.quem);

-- ── Voluntários inscritos para o mutirão (7 das 12 vagas) ───────
-- status 'enrolled' e dia dentro da semana: é o que o painel conta em
-- "Voluntários inscritos nesta semana".
INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, created_at)
SELECT ('00000000-0000-4000-8000-000000009' || d.n)::uuid,
       (SELECT id FROM auth.users WHERE email = d.quem),
       '00000000-0000-4000-8000-0000000009a1',
       '00000000-0000-4000-8000-0000000009b3',
       'voluntariado', 1,
       now() - (d.dias || ' days')::interval
FROM (VALUES
    ('a01', 'demo.ana@example.com',       6), ('a02', 'demo.daniel@example.com',   5),
    ('a03', 'demo.eduarda@example.com',   4), ('a04', 'demo.gabriela@example.com', 3),
    ('a05', 'demo.henrique@example.com',  2), ('a06', 'demo.joao@example.com',     1),
    ('a07', 'doador.teste@escoraaqui.app',1)
) AS d (n, quem, dias)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = d.quem);

-- ── Esperando a instituição confirmar ──────────────────────────
-- É o que enche a aba Doações e o número do painel.
INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, scheduled_for, created_at)
SELECT ('00000000-0000-4000-8000-000000009' || d.n)::uuid,
       (SELECT id FROM auth.users WHERE email = d.quem),
       '00000000-0000-4000-8000-0000000009a1',
       d.meta::uuid, d.tipo::public.help_type, d.qtd,
       d.dia, now() - (d.horas || ' hours')::interval
FROM (VALUES
    ('c01', 'doador.teste@escoraaqui.app', '00000000-0000-4000-8000-0000000009b2', 'pix',    80, NULL::date,            5),
    ('c02', 'demo.ana@example.com',        '00000000-0000-4000-8000-0000000009b1', 'itens',   5, current_date + 2,     26),
    ('c03', 'demo.bruno@example.com',      '00000000-0000-4000-8000-0000000009b2', 'pix',   150, NULL::date,           31)
) AS d (n, quem, meta, tipo, qtd, dia, horas)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = d.quem);

-- Uma que a instituição não encontrou: o app precisa mostrar esse caso.
INSERT INTO public.donations (id, donor_id, place_id, goal_id, type, amount, created_at)
SELECT '00000000-0000-4000-8000-0000000009c9',
       (SELECT id FROM auth.users WHERE email = 'demo.henrique@example.com'),
       '00000000-0000-4000-8000-0000000009a1',
       '00000000-0000-4000-8000-0000000009b2',
       'pix', 45, now() - interval '13 days'
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo.henrique@example.com');

-- ── A instituição confirma o recebimento ───────────────────────
-- É este passo que faz o progresso aparecer: para cada linha, o gatilho da
-- fase 5 soma o valor na meta, conta mais uma pessoa ajudando, avisa quem
-- doou e credita os pontos. Os 47 kits, os R$ 2.180 e as 200 cestas são o
-- resultado dessas somas, não um número digitado na meta.
--
-- Os ids terminam em d.. (material escolar), e.. (telhado) e f.. (cestas).
-- Os que terminam em c.. ficam de fora: são os pendentes de propósito.

-- Itens: a instituição confirma no dia seguinte, quando a entrega chega.
UPDATE public.donations
SET status = 'confirmed', confirmed_at = created_at + interval '1 day'
WHERE place_id = '00000000-0000-4000-8000-0000000009a1'
  AND (id::text LIKE '00000000-0000-4000-8000-000000009d%'
    OR id::text LIKE '00000000-0000-4000-8000-000000009f%');

-- Pix: confirma no mesmo dia, ao ver o extrato.
UPDATE public.donations
SET status = 'confirmed', confirmed_at = created_at + interval '4 hours'
WHERE place_id = '00000000-0000-4000-8000-0000000009a1'
  AND id::text LIKE '00000000-0000-4000-8000-000000009e%';

-- A que a instituição não encontrou no extrato.
UPDATE public.donations
SET status = 'not_found'
WHERE id = '00000000-0000-4000-8000-0000000009c9';

-- ── A meta das cestas volta para o passado ─────────────────────
-- O gatilho fechou a meta sozinho ao bater as 200 cestas, com data de hoje.
-- Aqui o prazo e a conclusão voltam para onde deveriam estar, e seen_done
-- fica marcado para o painel não abrir o aviso de meta nova concluída.
UPDATE public.goals
SET deadline = current_date - 6,
    done_at  = now() - interval '6 days',
    seen_done = true
WHERE id = '00000000-0000-4000-8000-0000000009b4';

-- ── Avisos ─────────────────────────────────────────────────────
-- Cada inserção gerou um "Nova doação para confirmar" e cada confirmação
-- gerou outro, todos marcados com a hora de agora: 90 avisos de uma vez,
-- sobre doações de semanas atrás. Apago tudo e deixo só o que faz sentido
-- hoje — as três doações que ainda esperam a instituição.
DELETE FROM public.notices WHERE place_id = '00000000-0000-4000-8000-0000000009a1';

INSERT INTO public.notices (user_id, kind, title, body, place_id, created_at)
SELECT p.owner_id, 'new_donation'::public.notice_kind,
       'Nova doação para confirmar',
       d.donor_name || ' registrou ' || public.fmt_amount(g, d.amount) || '.',
       p.id, d.created_at
FROM public.donations d
JOIN public.places p ON p.id = d.place_id
JOIN public.goals  g ON g.id = d.goal_id
WHERE d.place_id = '00000000-0000-4000-8000-0000000009a1'
  AND d.status IN ('waiting', 'items_agreed');

-- ── Doações mensais ────────────────────────────────────────────
INSERT INTO public.monthly_gifts (id, donor_id, place_id, amount, day, since)
SELECT ('00000000-0000-4000-8000-000000009' || d.n)::uuid,
       (SELECT id FROM auth.users WHERE email = d.quem),
       '00000000-0000-4000-8000-0000000009a1',
       d.valor, d.dia, current_date - (d.meses * 30)
FROM (VALUES
    ('b01', 'demo.ana@example.com',       50,  5, 5),
    ('b02', 'demo.camila@example.com',    30, 10, 3),
    ('b03', 'demo.felipe@example.com',   100,  1, 7),
    ('b04', 'demo.isabela@example.com',   25, 20, 2),
    ('b05', 'demo.joao@example.com',      40, 15, 4)
) AS d (n, quem, valor, dia, meses)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = d.quem);

-- ── Avaliações ─────────────────────────────────────────────────
INSERT INTO public.reviews (donation_id, place_id, author_id, stars, comment, created_at)
SELECT ('00000000-0000-4000-8000-000000009' || r.doacao)::uuid,
       '00000000-0000-4000-8000-0000000009a1',
       (SELECT id FROM auth.users WHERE email = r.quem),
       r.estrelas, r.texto, now() - (r.dias || ' days')::interval
FROM (VALUES
    ('d09', 'demo.isabela@example.com',   5, 'Entreguei os kits numa quinta e já vi as crianças usando no mesmo dia. A Vera explicou tudo o que ainda falta.', 21),
    ('e06', 'demo.felipe@example.com',    5, 'Mandei o Pix e recebi a confirmação no mesmo dia, com foto da nota do material. Transparência total.', 26),
    ('f01', 'demo.ana@example.com',       4, 'Organização boa na entrega das cestas. Só achei o estacionamento complicado na sexta.', 51),
    ('e0a', 'demo.joao@example.com',      5, 'Acompanho há meses. Sempre avisam quando a meta fecha e contam o que foi feito com o dinheiro.', 14),
    ('d0e', 'demo.daniel@example.com',    5, 'Levei material escolar e fui recebido pela coordenadora. Dá pra ver que o espaço é bem cuidado.', 11),
    ('f05', 'demo.gabriela@example.com',  4, 'Doei cestas e deu tudo certo. Demorou um pouco pra confirmar, mas avisaram antes.', 29)
) AS r (doacao, quem, estrelas, texto, dias)
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = r.quem)
  AND EXISTS (SELECT 1 FROM public.donations WHERE id = ('00000000-0000-4000-8000-000000009' || r.doacao)::uuid);

-- ── Conferência ────────────────────────────────────────────────
-- Primeira linha: o resumo do ponto.
SELECT p.name AS ponto,
       (SELECT count(*) FROM public.goals g WHERE g.place_id = p.id AND g.status = 'open') AS metas_abertas,
       (SELECT count(*) FROM public.donations d WHERE d.place_id = p.id AND d.status = 'confirmed') AS confirmadas,
       (SELECT count(*) FROM public.donations d WHERE d.place_id = p.id AND d.status IN ('waiting', 'items_agreed')) AS a_confirmar,
       (SELECT count(*) FROM public.donations d WHERE d.place_id = p.id AND d.status = 'enrolled') AS voluntarios,
       (SELECT count(*) FROM public.donations d WHERE d.place_id = p.id AND d.status = 'not_found') AS nao_encontradas,
       (SELECT count(*) FROM public.monthly_gifts m WHERE m.place_id = p.id) AS mensais,
       (SELECT count(*) FROM public.reviews r WHERE r.place_id = p.id) AS avaliacoes,
       (SELECT round(avg(r.stars), 1) FROM public.reviews r WHERE r.place_id = p.id) AS nota
FROM public.places p
WHERE p.id = '00000000-0000-4000-8000-0000000009a1';

-- Segunda: cada meta conferida contra as próprias doações. As colunas
-- "bate_valor" e "bate_gente" precisam vir todas com true — é a prova de que
-- o número da tela é a soma das doações, e não um valor escrito à mão.
SELECT g.status,
       coalesce(g.item, g.action_name) AS meta,
       g.current, g.target, g.helpers, g.enrolled,
       g.current = coalesce((SELECT sum(d.amount) FROM public.donations d
                             WHERE d.goal_id = g.id AND d.status = 'confirmed'), 0) AS bate_valor,
       g.helpers = (SELECT count(*) FROM public.donations d
                    WHERE d.goal_id = g.id AND d.status = 'confirmed') AS bate_gente,
       g.deadline, g.done_at
FROM public.goals g
WHERE g.place_id = '00000000-0000-4000-8000-0000000009a1'
ORDER BY g.status, g.deadline;
