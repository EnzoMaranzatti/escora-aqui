-- Permissões (RLS): quem pode ler e escrever o quê.
-- Com o RLS ligado, tudo fica bloqueado. Cada política abaixo é uma exceção:
-- "pode passar quem cumprir esta regra".
--
-- auth.uid()   = id de quem está logado fazendo o pedido
-- USING        = em quais linhas já existentes a pessoa pode mexer
-- WITH CHECK   = como a linha precisa ficar depois de criada ou alterada
--
-- Ações que mexem em várias tabelas de uma vez (confirmar doação, aprovar
-- ponto, marcar presença) não têm política aqui: viram funções nas fases 4 a 6.

-- ── Funções de ajuda ────────────────────────────────────────
-- SECURITY DEFINER: leem as tabelas por cima do RLS, como o gatilho do profiles.
-- STABLE: a resposta não muda durante um mesmo pedido.

-- A pessoa logada é da equipe de validação?
CREATE FUNCTION public.is_team()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = ''
AS $$
    SELECT coalesce(
        (SELECT is_team FROM public.profiles WHERE id = auth.uid()),
        false
    );
$$;

-- A pessoa logada é dona deste ponto?
-- EXISTS (SELECT 1 ...) = "existe pelo menos uma linha assim?"
CREATE FUNCTION public.owns_place(place uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.places WHERE id = place AND owner_id = auth.uid()
    );
$$;

-- Liga o RLS
ALTER TABLE public.profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.places         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_gifts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.donations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports        ENABLE ROW LEVEL SECURITY;

-- profiles 
-- Sem política de INSERT: quem cria o perfil é o gatilho do cadastro.

-- Cada um vê o próprio perfil; a equipe vê todos.
CREATE POLICY "profiles: ver o próprio ou equipe"
ON public.profiles FOR SELECT TO authenticated
USING (id = auth.uid() OR public.is_team());

-- Cada um edita só o próprio perfil.
CREATE POLICY "profiles: editar o próprio"
ON public.profiles FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- E só estas colunas. is_team fica de fora: ninguém se coloca na equipe.
REVOKE UPDATE ON public.profiles FROM anon, authenticated;
GRANT UPDATE (
    full_name, first_name, phone, birth_date, avatar_path, city, uf, position,
    help_types, causes, notify_goals, notify_confirm, notify_volunteer, radius_km
) ON public.profiles TO authenticated;

-- places 
-- Duas políticas para a mesma ação (dois UPDATE): basta cumprir uma delas.

-- Todos veem pontos ativos; o dono vê o seu em qualquer situação; a equipe vê tudo.
CREATE POLICY "places: ver"
ON public.places FOR SELECT TO authenticated
USING (status = 'active' OR owner_id = auth.uid() OR public.is_team());

-- Qualquer pessoa logada começa um cadastro, sempre como rascunho e em nome próprio.
CREATE POLICY "places: começar cadastro"
ON public.places FOR INSERT TO authenticated
WITH CHECK (owner_id = auth.uid() AND status = 'draft');

-- O dono edita enquanto é rascunho ou está em ajuste, e só pode mandar para análise.
-- Não consegue se aprovar sozinho.
CREATE POLICY "places: dono edita rascunho"
ON public.places FOR UPDATE TO authenticated
USING (owner_id = auth.uid() AND status IN ('draft', 'adjust'))
WITH CHECK (owner_id = auth.uid() AND status IN ('draft', 'adjust', 'review', 'awaiting_indication'));

-- A equipe altera qualquer ponto (aprovar, pausar, remover).
CREATE POLICY "places: equipe altera"
ON public.places FOR UPDATE TO authenticated
USING (public.is_team())
WITH CHECK (public.is_team());

-- O dono pode apagar um rascunho que desistiu de enviar.
CREATE POLICY "places: dono apaga rascunho"
ON public.places FOR DELETE TO authenticated
USING (owner_id = auth.uid() AND status = 'draft');

-- goals 

-- Todos veem metas publicadas de pontos ativos; o dono e a equipe veem todas.
-- "places p" dá o apelido p à tabela; goals.place_id é o place_id da meta.
CREATE POLICY "goals: ver"
ON public.goals FOR SELECT TO authenticated
USING (
    (published AND EXISTS (
        SELECT 1 FROM public.places p
        WHERE p.id = goals.place_id AND p.status = 'active'
    ))
    OR public.owns_place(place_id)
    OR public.is_team()
);

-- O dono cria metas no próprio ponto, sempre começando do zero.
CREATE POLICY "goals: dono cria"
ON public.goals FOR INSERT TO authenticated
WITH CHECK (public.owns_place(place_id) AND current = 0 AND status = 'open');

-- O dono edita as metas do próprio ponto...
CREATE POLICY "goals: dono edita"
ON public.goals FOR UPDATE TO authenticated
USING (public.owns_place(place_id))
WITH CHECK (public.owns_place(place_id));

-- ...mas não mexe em current nem em status: isso só muda com confirmação (fase 5).
REVOKE UPDATE ON public.goals FROM anon, authenticated;
GRANT UPDATE (
    target, item, unit, cause, deadline, reason, seen_done,
    action_name, action_task, action_day, action_start, action_end
) ON public.goals TO authenticated;

-- monthly_gifts 

-- O doador faz tudo com as próprias doações mensais.
CREATE POLICY "monthly_gifts: doador mexe nas suas"
ON public.monthly_gifts FOR ALL TO authenticated
USING (donor_id = auth.uid())
WITH CHECK (donor_id = auth.uid());

-- O dono do ponto vê quem doa todo mês para ele.
CREATE POLICY "monthly_gifts: dono do ponto vê"
ON public.monthly_gifts FOR SELECT TO authenticated
USING (public.owns_place(place_id));

-- donations 
-- Sem política de UPDATE: confirmar, "não encontrei", presença e cancelar
-- viram funções nas fases 4 e 5.

-- O doador vê as suas; o dono do ponto vê as que recebeu; a equipe vê todas.
CREATE POLICY "donations: ver"
ON public.donations FOR SELECT TO authenticated
USING (donor_id = auth.uid() OR public.owns_place(place_id) OR public.is_team());

-- O doador registra em nome próprio, sempre como pendente. Ninguém se autoconfirma.
CREATE POLICY "donations: doador registra"
ON public.donations FOR INSERT TO authenticated
WITH CHECK (
    donor_id = auth.uid()
    AND status IN ('waiting', 'items_agreed', 'enrolled')
    AND confirmed_at IS NULL
);

-- reviews

-- Avaliações são públicas (aparecem no perfil do ponto). true = todas as linhas.
CREATE POLICY "reviews: todos veem"
ON public.reviews FOR SELECT TO authenticated
USING (true);

-- Só avalia quem fez a doação, depois de confirmada, e no ponto certo.
CREATE POLICY "reviews: doador avalia"
ON public.reviews FOR INSERT TO authenticated
WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM public.donations d
        WHERE d.id = reviews.donation_id
          AND d.donor_id = auth.uid()
          AND d.status = 'confirmed'
          AND d.place_id = reviews.place_id
    )
);

-- follows

-- Cada um segue e deixa de seguir por conta própria.
CREATE POLICY "follows: cada um mexe nos seus"
ON public.follows FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- notices
-- Sem política de INSERT: os avisos são criados pelo banco, nas funções das
-- próximas fases. O app não cria aviso.

-- Cada um vê os próprios avisos.
CREATE POLICY "notices: ver os seus"
ON public.notices FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- Cada um marca os próprios avisos como lidos...
CREATE POLICY "notices: marcar como lido"
ON public.notices FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ...e só a coluna read. Não dá para reescrever o texto do aviso.
REVOKE UPDATE ON public.notices FROM anon, authenticated;
GRANT UPDATE (read) ON public.notices TO authenticated;

-- submissions

-- O dono vê a fila do próprio ponto; a equipe vê tudo.
CREATE POLICY "submissions: ver"
ON public.submissions FOR SELECT TO authenticated
USING (public.owns_place(place_id) OR public.is_team());

-- O dono manda o próprio ponto para a fila, sempre como não resolvido.
CREATE POLICY "submissions: dono envia"
ON public.submissions FOR INSERT TO authenticated
WITH CHECK (public.owns_place(place_id) AND resolved_at IS NULL AND resolved_by IS NULL);

-- Só a equipe resolve.
CREATE POLICY "submissions: equipe resolve"
ON public.submissions FOR UPDATE TO authenticated
USING (public.is_team())
WITH CHECK (public.is_team());

-- reports
-- Quem denuncia não vê a denúncia depois: protege quem denunciou e o ponto.

-- Qualquer pessoa logada denuncia, em nome próprio.
CREATE POLICY "reports: denunciar"
ON public.reports FOR INSERT TO authenticated
WITH CHECK (author_id = auth.uid() AND resolved_at IS NULL AND resolved_by IS NULL);

-- Só a equipe vê e resolve denúncias.
CREATE POLICY "reports: equipe vê"
ON public.reports FOR SELECT TO authenticated
USING (public.is_team());

CREATE POLICY "reports: equipe resolve"
ON public.reports FOR UPDATE TO authenticated
USING (public.is_team())
WITH CHECK (public.is_team());
