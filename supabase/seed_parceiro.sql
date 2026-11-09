-- ── Conta de parceiro da apresentação ──────────────────────────
--
-- Liga a conta  parceiro.teste@escoraaqui.app / escora2026
-- (criada pela API de signup, id ecf4dd58-3c15-4b51-a91b-9a73d5047480)
-- à Livraria Beira de Página, que é a dona do cupom "R$ 30 em livros".
--
-- Por que a Livraria e não as Thermas: o único cupom já trocado no banco
-- (ESC-D6611B, do doador.teste) é dela. Assim a demonstração fecha o ciclo
-- de verdade — o doador mostra o código que já tem na tela "Minhas trocas"
-- e o parceiro dá baixa nele ao vivo, sem precisar preparar nada.
--
-- Rodar no SQL Editor do painel, DEPOIS da migração 20261109113000
-- (fase 10), que é quem cria owner_id e used_at. Sem TEMP TABLE: o SQL
-- Editor não mantém tabela temporária entre os comandos do script.

-- ── 1. A empresa ganha dono ─────────────────────────────────
UPDATE public.partners
SET owner_id = (SELECT id FROM auth.users WHERE email = 'parceiro.teste@escoraaqui.app')
WHERE id = '00000000-0000-4000-8000-000000000904';

-- ── 2. Estoque que aguenta o histórico ──────────────────────
-- Nasceu com 3 no seed da fase 9, só para a tela do doador mostrar "quase
-- acabando". Com as trocas abaixo ele ficaria negativo.
UPDATE public.catalog_items SET stock = 20
WHERE id = '00000000-0000-4000-8000-000000000952';

-- ── 3. Saldo para os doadores fictícios trocarem ────────────
-- As trocas abaixo descontam 150 pontos de cada um. O saldo que eles têm
-- depende de quantas doações o seed da apresentação sorteou, então aqui o
-- script completa quem ficou abaixo disso — com a linha de extrato junto,
-- para o saldo continuar sendo a soma do extrato.
INSERT INTO public.points_ledger (user_id, amount, reason, note)
SELECT pp.user_id, 150 - pp.balance, 'bonus_mensal_login', 'Ajuste dos dados de demonstração'
FROM public.points_profiles pp
JOIN auth.users u ON u.id = pp.user_id
WHERE u.email IN (
        'demo.ana@example.com', 'demo.bruno@example.com', 'demo.camila@example.com',
        'demo.daniel@example.com', 'demo.eduarda@example.com')
  AND pp.balance < 150
  -- quem já trocou não é completado de novo (o script pode rodar duas vezes)
  AND NOT EXISTS (
      SELECT 1 FROM public.redemptions r
      WHERE r.user_id = pp.user_id
        AND r.catalog_item_id = '00000000-0000-4000-8000-000000000952'
  );

UPDATE public.points_profiles pp
SET balance = 150
FROM auth.users u
WHERE u.id = pp.user_id
  AND u.email IN (
        'demo.ana@example.com', 'demo.bruno@example.com', 'demo.camila@example.com',
        'demo.daniel@example.com', 'demo.eduarda@example.com')
  AND pp.balance < 150
  -- quem já trocou não é completado de novo (o script pode rodar duas vezes)
  AND NOT EXISTS (
      SELECT 1 FROM public.redemptions r
      WHERE r.user_id = pp.user_id
        AND r.catalog_item_id = '00000000-0000-4000-8000-000000000952'
  );

-- ── 4. Trocas dos doadores fictícios ────────────────────────
-- Feitas do jeito que a função redeem_catalog_item faria: desconta o saldo,
-- grava a linha do extrato e baixa o estoque. Quem não tiver saldo
-- simplesmente não entra — por isso o WHERE pp.balance >= 150. O script
-- pode rodar duas vezes sem duplicar (ON CONFLICT no código do cupom).
INSERT INTO public.redemptions (user_id, catalog_item_id, points_spent, code, redeemed_at, used_at)
SELECT
    u.id,
    '00000000-0000-4000-8000-000000000952',
    150,
    t.code,
    now() - (t.dias || ' days')::interval,
    CASE WHEN t.usado THEN now() - (t.dias - 1 || ' days')::interval END
FROM (VALUES
    ('demo.ana@example.com',      'ESC-7K2M4Q', 21, true),
    ('demo.bruno@example.com',    'ESC-B3X9PL', 17, true),
    ('demo.camila@example.com',   'ESC-R5T1WZ', 12, true),
    ('demo.daniel@example.com',   'ESC-N8H6VC', 8,  false),
    ('demo.eduarda@example.com',  'ESC-J4D2YF', 4,  false)
) AS t(quem, code, dias, usado)
JOIN auth.users u            ON u.email = t.quem
JOIN public.points_profiles pp ON pp.user_id = u.id AND pp.balance >= 150
ON CONFLICT (code) DO NOTHING;

-- O extrato de quem trocou (mesma linha que a função grava).
INSERT INTO public.points_ledger (user_id, amount, reason, note, created_at)
SELECT r.user_id, -r.points_spent, 'canje', 'R$ 30 em livros', r.redeemed_at
FROM public.redemptions r
WHERE r.catalog_item_id = '00000000-0000-4000-8000-000000000952'
  AND r.user_id <> (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app')
  AND NOT EXISTS (
      SELECT 1 FROM public.points_ledger l
      WHERE l.user_id = r.user_id AND l.reason = 'canje' AND l.created_at = r.redeemed_at
  );

-- O saldo e o estoque acompanham.
UPDATE public.points_profiles pp
SET balance = pp.balance - 150
FROM public.redemptions r
WHERE r.user_id = pp.user_id
  AND r.catalog_item_id = '00000000-0000-4000-8000-000000000952'
  AND r.user_id <> (SELECT id FROM auth.users WHERE email = 'doador.teste@escoraaqui.app')
  AND pp.balance >= 150;

UPDATE public.catalog_items
SET stock = 20 - (
    SELECT count(*) FROM public.redemptions r
    WHERE r.catalog_item_id = '00000000-0000-4000-8000-000000000952'
)
WHERE id = '00000000-0000-4000-8000-000000000952';

-- ── 5. Conferência ──────────────────────────────────────────
-- Esperado: empresa_ligada = Livraria Beira de Página, cupons_trocados = 6,
-- cupons_usados = 3, demo_ainda_vale = true, estoque = 14. O que importa é o
-- demo_ainda_vale: é o cupom ESC-D6611B que a apresentação vai validar ao vivo.
SELECT
    (SELECT name FROM public.partners
      WHERE owner_id = (SELECT id FROM auth.users WHERE email = 'parceiro.teste@escoraaqui.app'))
        AS empresa_ligada,
    (SELECT count(*) FROM public.redemptions
      WHERE catalog_item_id = '00000000-0000-4000-8000-000000000952')
        AS cupons_trocados,
    (SELECT count(*) FROM public.redemptions
      WHERE catalog_item_id = '00000000-0000-4000-8000-000000000952' AND used_at IS NOT NULL)
        AS cupons_usados,
    (SELECT used_at IS NULL FROM public.redemptions WHERE code = 'ESC-D6611B')
        AS demo_ainda_vale,
    (SELECT stock FROM public.catalog_items
      WHERE id = '00000000-0000-4000-8000-000000000952')
        AS estoque;
