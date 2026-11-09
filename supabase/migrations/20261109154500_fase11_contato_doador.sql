-- ── Fase 11 · a instituição consegue falar com quem doou ───────
--
-- Até aqui a tela de doações mostrava só o primeiro nome (donations.donor_name,
-- denormalizado desde a fase 3). Quando a doação é de itens, alguém precisa
-- combinar a entrega; quando é Pix, a instituição quer agradecer. Não havia
-- como: `profiles` é privado e a RLS não deixa um ponto ler o perfil de
-- ninguém.
--
-- Decisão de privacidade (registrada em docs/BACKEND.md):
--   • O contato só aparece para o dono do ponto que RECEBEU aquela doação.
--   • Só sai o que serve para combinar a entrega: nome, telefone, e-mail e
--     cidade. Nada de data de nascimento, causas, raio ou histórico de outros
--     pontos.
--   • O app diz na tela por que aquele contato está ali.
--   • Doação de conta apagada (donor_id nulo) não devolve nada.
--
-- Nada aqui altera tabela: é uma função de leitura só.

-- ── O contato de quem fez uma doação ────────────────────────
-- SECURITY DEFINER porque atravessa a RLS de `profiles` e de `auth.users`.
-- O filtro que segura tudo é o EXISTS: a doação precisa ser de um ponto
-- cujo owner_id é quem está chamando.
CREATE OR REPLACE FUNCTION public.place_donor_contact(p_donation uuid)
RETURNS TABLE (
    full_name  text,
    first_name text,
    phone      text,
    email      text,
    city       text,
    uf         text,
    since      timestamptz
)
LANGUAGE sql
STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT pr.full_name, pr.first_name, pr.phone, u.email::text, pr.city, pr.uf, pr.created_at
    FROM public.donations d
    JOIN public.places   pl ON pl.id = d.place_id
    JOIN public.profiles pr ON pr.id = d.donor_id
    LEFT JOIN auth.users  u ON u.id = d.donor_id
    WHERE d.id = p_donation
      AND pl.owner_id = auth.uid();
$$;

COMMENT ON FUNCTION public.place_donor_contact(uuid) IS
    'Contato de quem doou, só para o dono do ponto que recebeu a doação (fase 11).';

-- Esta máquina não tem CLI do Supabase, psql nem Docker: a migração é
-- aplicada pelo SQL Editor do painel. A linha abaixo marca a migração como
-- já aplicada, para o `supabase db push` de quem tem a CLI não repetir.
INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261109154500', 'fase11_contato_doador')
ON CONFLICT (version) DO NOTHING;
