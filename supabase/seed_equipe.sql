-- ── Conta da equipe e trabalho para ela analisar ───────────────
--
-- Sem isto o modo equipe existe no app (Cadastros · Denúncias · Pontos) e no
-- banco (fase 6), mas ninguém consegue entrar: `profiles.is_team` nasce false
-- e nenhum seed promovia alguém. A fila também estava vazia — era por isso que
-- o tour quebrava em `queue.first`.
--
-- A conta  equipe.teste@escoraaqui.app / escora2026  (Lucas Ferreira) já foi
-- criada pela API de signup em 10/11/2026. Aqui ela só ganha o crachá.
--
-- Rodar no SQL Editor do painel. Pode rodar mais de uma vez: tudo é
-- idempotente (ON CONFLICT DO NOTHING / WHERE NOT EXISTS).

-- ── 1. O crachá da equipe ───────────────────────────────────
UPDATE public.profiles
SET is_team = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'equipe.teste@escoraaqui.app');

-- ── 2. Responsáveis dos pontos que vão entrar na fila ───────
-- Mesmo padrão dos outros seeds: conta sem senha, só para o ponto ter dono.
INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
)
SELECT
    '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
    u.email, '', now() - interval '12 days',
    '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', u.name),
    now() - interval '12 days', now() - interval '12 days', '', '', '', ''
FROM (VALUES
    ('00000000-0000-4000-8000-000000000323', 'demo.marcos@example.com',  'Marcos Pereira'),
    ('00000000-0000-4000-8000-000000000324', 'demo.juliana@example.com', 'Juliana Castro'),
    ('00000000-0000-4000-8000-000000000325', 'demo.sergio@example.com',  'Sérgio Almeida')
) AS u (id, email, name)
-- O índice único de `auth.users` é o e-mail, não o id: se uma destas contas
-- já tiver sido criada por outro seed (com outro id), o ON CONFLICT (id) não
-- segura e o script inteiro aborta. Por isso o filtro por e-mail vem antes.
WHERE NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.email = u.email)
ON CONFLICT (id) DO NOTHING;

-- ── 3. Três cadastros esperando análise ─────────────────────
-- `status = 'review'` mantém os três fora do mapa do doador: quem decide é a
-- equipe. Um deles é coletivo sem CNPJ indicado por um ponto já verificado,
-- para a tela de análise mostrar também esse caminho.
INSERT INTO public.places (
    id, owner_id, status, name, type_label, kind, responsible, phone,
    cnpj, legal_name, cnpj_status, indicated_by,
    about, distributes, causes, accepts,
    street, number, neighborhood, city, location,
    hours, receive_days, photo_path,
    pix_key_type, pix_key, payee,
    verified_at, last_reviewed, created_at
) VALUES
(
    '00000000-0000-4000-8000-000000000133', (SELECT id FROM auth.users WHERE email = 'demo.marcos@example.com'),
    'review', 'Casa de Acolhida Novo Dia', 'Abrigo', 'care', 'Marcos Pereira', '(17) 90000-0133',
    '12.345.678/0001-95', 'Associação Casa de Acolhida Novo Dia', 'ativa', NULL,
    'Acolhemos homens em situação de rua por até 90 dias, com banho, cama e ajuda para tirar documentos.',
    'Jantar servido todos os dias às 19h.',
    '{"Moradia","Alimentação"}', '{itens,pix,voluntariado}',
    'Rua Silva Jardim', '2.310', 'Boa Vista', 'São José do Rio Preto', 'SRID=4326;POINT(-49.37200 -20.80600)',
    'todos os dias, das 17h às 22h', '{1,2,3,4,5,6,7}', 'assets/images/places/abrigo-recanto.jpg',
    'CNPJ', '12.345.678/0001-95', 'Associação Casa de Acolhida Novo Dia',
    NULL, now() - interval '5 days', now() - interval '5 days'
),
(
    '00000000-0000-4000-8000-000000000134', (SELECT id FROM auth.users WHERE email = 'demo.juliana@example.com'),
    'review', 'Horta Comunitária Boa Esperança', 'Coletivo', 'care', 'Juliana Castro', '(17) 90000-0134',
    NULL, '', '', '00000000-0000-4000-8000-000000000122',
    'Cuidamos de uma horta no terreno da paróquia e dividimos a colheita com 40 famílias do bairro.',
    'Cestas de verdura entregues nas quartas.',
    '{"Alimentação","Meio ambiente"}', '{itens,voluntariado}',
    'Rua Independência', '540', 'Vila Toninho', 'São José do Rio Preto', 'SRID=4326;POINT(-49.40100 -20.82400)',
    'quarta e sábado, das 8h às 12h', '{3,6}', 'assets/images/places/cozinha-jardim.jpg',
    NULL, NULL, NULL,
    NULL, now() - interval '2 days', now() - interval '2 days'
),
(
    '00000000-0000-4000-8000-000000000135', (SELECT id FROM auth.users WHERE email = 'demo.sergio@example.com'),
    'review', 'Instituto Mãos que Ensinam', 'ONG', 'school', 'Sérgio Almeida', '(17) 90000-0135',
    '98.765.432/0001-10', 'Instituto Mãos que Ensinam', 'ativa', NULL,
    'Reforço escolar de matemática e português para crianças do 3º ao 5º ano, no contraturno.',
    NULL,
    '{"Educação","Crianças"}', '{voluntariado,pix}',
    'Avenida Alberto Andaló', '4.120', 'Centro', 'São José do Rio Preto', 'SRID=4326;POINT(-49.38200 -20.81200)',
    'segunda a quinta, das 13h às 17h', '{1,2,3,4}', 'assets/images/places/escola-viva.jpg',
    'E-mail', 'maosqueensinam@example.org', 'Instituto Mãos que Ensinam',
    NULL, now() - interval '9 days', now() - interval '9 days'
)
ON CONFLICT (id) DO NOTHING;

-- ── 4. A fila ───────────────────────────────────────────────
-- Dois cadastros novos e uma troca de chave Pix de um ponto já no mapa. O de
-- 9 dias entra como urgente (mais de 3 dias úteis), que é o caso que a tela
-- da equipe destaca.
INSERT INTO public.submissions (id, place_id, kind, changes, sent_at)
VALUES
('00000000-0000-4000-8000-00000000a133', '00000000-0000-4000-8000-000000000133', 'novo',     '{}', now() - interval '5 days'),
('00000000-0000-4000-8000-00000000a134', '00000000-0000-4000-8000-000000000134', 'novo',     '{}', now() - interval '2 days'),
('00000000-0000-4000-8000-00000000a135', '00000000-0000-4000-8000-000000000135', 'novo',     '{}', now() - interval '9 days'),
('00000000-0000-4000-8000-00000000a107', '00000000-0000-4000-8000-000000000107', 'mudanca',
    '{"Chave Pix": "escolaviva.nova@example.org", "Favorecido": "Associação Escola Viva"}',
    now() - interval '1 day')
ON CONFLICT (id) DO NOTHING;

-- A troca de chave Pix fica parada até a equipe decidir (regra da fase 5).
UPDATE public.places SET pix_paused = true
WHERE id = '00000000-0000-4000-8000-000000000107'
  AND EXISTS (SELECT 1 FROM public.submissions
               WHERE place_id = '00000000-0000-4000-8000-000000000107'
                 AND kind = 'mudanca' AND resolved_at IS NULL);

-- ── 5. Denúncias abertas ────────────────────────────────────
-- Os motivos são os quatro fixos do app (o CHECK da tabela só aceita esses).
-- O autor é procurado pelo e-mail; se a conta fictícia não existir neste
-- banco, a denúncia é pulada em vez de derrubar o script.
INSERT INTO public.reports (id, place_id, author_id, reason, body, created_at)
SELECT * FROM (VALUES
('00000000-0000-4000-8000-00000000b001'::uuid, '00000000-0000-4000-8000-000000000103'::uuid,
 (SELECT id FROM auth.users WHERE email = 'demo.ana@example.com'),
 'O ponto não funciona mais'::text,
 'Passei lá no sábado e no domingo e estava fechado nos dois dias. Os vizinhos disseram que mudou de endereço.'::text,
 now() - interval '4 days'),
('00000000-0000-4000-8000-00000000b002'::uuid, '00000000-0000-4000-8000-000000000110'::uuid,
 (SELECT id FROM auth.users WHERE email = 'demo.bruno@example.com'),
 'As informações estão erradas'::text,
 'O horário no app diz até 18h, mas eles fecham às 16h. Perdi a viagem com as doações no carro.'::text,
 now() - interval '2 days'),
('00000000-0000-4000-8000-00000000b003'::uuid, '00000000-0000-4000-8000-000000000112'::uuid,
 (SELECT id FROM auth.users WHERE email = 'demo.camila@example.com'),
 'Suspeito de golpe'::text,
 'A chave Pix que aparece no app está no nome de uma pessoa física, e não da paróquia. Achei estranho.'::text,
 now() - interval '1 day')
) AS r (id, place_id, author_id, reason, body, created_at)
WHERE r.author_id IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ── 6. Conferência ─────────────────────────────────────────
-- Esperado: equipe_ok = true, na_fila = 4, urgentes >= 1, denuncias_abertas = 3.
SELECT
    (SELECT is_team FROM public.profiles
      WHERE id = (SELECT id FROM auth.users WHERE email = 'equipe.teste@escoraaqui.app')) AS equipe_ok,
    (SELECT count(*) FROM public.submissions WHERE resolved_at IS NULL)                   AS na_fila,
    (SELECT count(*) FROM public.submissions
      WHERE resolved_at IS NULL AND sent_at < now() - interval '3 days')                  AS urgentes,
    (SELECT count(*) FROM public.reports WHERE resolved_at IS NULL)                       AS denuncias_abertas,
    (SELECT count(*) FROM public.places WHERE status = 'review')                          AS em_analise;
