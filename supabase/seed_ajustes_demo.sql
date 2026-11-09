-- ── Ajustes nos dados de demonstração ─────────────────────────
--
-- Nada aqui é regra de negócio: é só arrumar o que ficou torto nos seeds
-- para a apresentação. Pode rodar quantas vezes quiser.

-- ── 1. Nome de quem doou ────────────────────────────────────
-- `donations.donor_name` e `monthly_gifts.donor_name` são colunas
-- denormalizadas (fase 3): o gatilho copia o primeiro nome do perfil **no
-- momento do insert**. Quem mudou o nome depois continuou aparecendo com o
-- antigo — por isso a tela da instituição mostrava "Doador registrou
-- R$ 80,00". Isto recopia do perfil.
UPDATE public.donations d
SET donor_name = p.first_name
FROM public.profiles p
WHERE p.id = d.donor_id
  AND d.donor_name IS DISTINCT FROM p.first_name;

UPDATE public.monthly_gifts m
SET donor_name = p.first_name
FROM public.profiles p
WHERE p.id = m.donor_id
  AND m.donor_name IS DISTINCT FROM p.first_name;

-- ── 2. Doações dentro da semana atual (opcional) ────────────
-- O seed da instituição espalha as doações de 2 a 38 dias atrás. Se a
-- apresentação cair numa segunda ou terça, a aba Resumo mostra "0 doações
-- esta semana", o que não é erro mas fica pobre na tela. Isto puxa as três
-- doações confirmadas mais recentes para dentro da semana corrente.
--
-- Se preferir mostrar o número verdadeiro, é só não rodar este bloco.
WITH recentes AS (
    SELECT id, row_number() OVER (ORDER BY created_at DESC) AS n
    FROM public.donations
    WHERE place_id = '00000000-0000-4000-8000-0000000009a1'
      AND status = 'confirmed'
    LIMIT 3
)
UPDATE public.donations d
SET created_at = date_trunc('day', now())
                 - ((r.n - 1) || ' days')::interval
                 + interval '10 hours',
    confirmed_at = date_trunc('day', now()) - ((r.n - 1) || ' days')::interval + interval '14 hours'
FROM recentes r
WHERE d.id = r.id
  AND d.created_at < date_trunc('week', now());

-- ── 3. Conferência ──────────────────────────────────────────
SELECT
    (SELECT count(*) FROM public.donations d
       JOIN public.profiles p ON p.id = d.donor_id
      WHERE d.donor_name IS DISTINCT FROM p.first_name)          AS nomes_fora_de_sincronia,
    (SELECT count(*) FROM public.donations
      WHERE place_id = '00000000-0000-4000-8000-0000000009a1'
        AND status = 'confirmed'
        AND created_at >= date_trunc('week', now()))             AS confirmadas_nesta_semana;
