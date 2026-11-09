-- ── Fase 9 · foto nos cupons do catálogo ───────────────────────
--
-- A tabela catalog_items nasceu sem coluna de foto, e o card do catálogo
-- mostrava só um ícone. As fotos ficam no app (assets/images/partners/),
-- não no banco: aqui guardamos o caminho, do mesmo jeito que places já faz.
--
-- A migração da fase 9 (20261103212526) já foi aplicada e não se edita.

ALTER TABLE public.catalog_items
    ADD COLUMN IF NOT EXISTS photo_path text;

COMMENT ON COLUMN public.catalog_items.photo_path IS
    'Caminho da foto dentro do app (assets/images/partners/...). Nulo cai no ícone.';

-- Os oito cupons de demonstração do seed_fase9.sql.
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/cafe_manha.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000951';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/livros.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000952';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/frutas.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000953';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/cinema.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000954';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/academia.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000955';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/bolo.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000956';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/thermas.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000957';
UPDATE public.catalog_items SET photo_path = 'assets/images/partners/parque_familia.jpg'
    WHERE id = '00000000-0000-4000-8000-000000000958';

-- Esta máquina não tem CLI do Supabase, psql nem Docker: a migração é
-- aplicada pelo SQL Editor do painel. A linha abaixo marca a migração como
-- já aplicada, para o `supabase db push` de quem tem a CLI não repetir.
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261108163000', 'fase9_fotos_catalogo')
ON CONFLICT (version) DO NOTHING;
