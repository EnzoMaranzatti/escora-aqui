-- Fase 5: a instituição cadastra o ponto, confirma doações, cuida das metas
-- e pede mudanças de dados. As ações que mexem em linhas de outras pessoas
-- (a doação é do doador) ou em colunas protegidas (status, current) são
-- funções SECURITY DEFINER: elas conferem quem chama e fazem só aquela troca.

REVOKE EXECUTE ON FUNCTION public.first_name_of FROM public, anon, authenticated;

-- ── O status da doação mudou ────────────────────────────────
-- Um gatilho só para todas as trocas: assim a regra da meta vale não
-- importa qual função mudou o status.
CREATE FUNCTION public.after_donation_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    g public.goals;
    p public.places;
    what text;
BEGIN
    SELECT * INTO p FROM public.places WHERE id = NEW.place_id;
    SELECT * INTO g FROM public.goals WHERE id = NEW.goal_id;
    what := CASE WHEN g.id IS NULL THEN public.fmt_money(NEW.amount) ELSE public.fmt_amount(g, NEW.amount) END;

    -- Confirmada: a meta avança. Só aqui "current" sobe (regra do "modelo B").
    IF NEW.status = 'confirmed' THEN
        IF g.id IS NOT NULL THEN
            UPDATE public.goals
            SET current = current + NEW.amount, helpers = helpers + 1
            WHERE id = g.id
            RETURNING * INTO g;

            -- Chegou no alvo: meta concluída e aviso para todo mundo que ajudou.
            IF g.current >= g.target AND g.status = 'open' THEN
                UPDATE public.goals SET status = 'done', done_at = now() WHERE id = g.id;
                INSERT INTO public.notices (user_id, kind, title, body, place_id)
                SELECT DISTINCT d.donor_id, 'goal_done'::public.notice_kind,
                       'A meta de ' || p.name || ' foi concluída',
                       public.fmt_amount(g, g.target, false) || ' arrecadados. Obrigado por fazer parte.',
                       p.id
                FROM public.donations d
                WHERE d.goal_id = g.id AND d.status = 'confirmed' AND d.donor_id IS NOT NULL;
            END IF;
        END IF;

        IF (SELECT notify_confirm FROM public.profiles WHERE id = NEW.donor_id) THEN
            PERFORM public.notify(
                NEW.donor_id, 'confirmed',
                CASE WHEN NEW.type = 'voluntariado' THEN 'Sua presença foi confirmada' ELSE 'Sua doação foi confirmada' END,
                CASE WHEN NEW.type = 'voluntariado'
                     THEN 'A ' || p.name || ' marcou sua presença em ' || coalesce(g.action_name, 'uma ação') || '.'
                     ELSE 'A ' || p.name || ' confirmou o recebimento de ' || what || '.' END,
                p.id
            );
        END IF;

    ELSIF NEW.status = 'not_found' THEN
        PERFORM public.notify(
            NEW.donor_id, 'not_found',
            'A ' || p.name || ' não encontrou sua doação',
            'Confira o comprovante em Minhas doações.',
            p.id
        );

    -- Inscrição cancelada (pela pessoa ou porque a ação foi cancelada): a vaga volta.
    ELSIF NEW.status = 'cancelled' AND OLD.status = 'enrolled' AND g.id IS NOT NULL THEN
        UPDATE public.goals SET enrolled = greatest(enrolled - 1, 0) WHERE id = g.id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER donations_after_status AFTER UPDATE OF status ON public.donations
    FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.after_donation_status();

-- ── Confirmar, "não encontrei" e presença ───────────────────

CREATE FUNCTION public.confirm_donation(donation uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.donations SET status = 'confirmed', confirmed_at = now()
    WHERE id = donation
      AND public.owns_place(place_id)
      AND status IN ('waiting', 'items_agreed', 'enrolled');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa doação não pode ser confirmada.';
    END IF;
END;
$$;

CREATE FUNCTION public.mark_not_found(donation uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.donations SET status = 'not_found'
    WHERE id = donation
      AND public.owns_place(place_id)
      AND status IN ('waiting', 'items_agreed');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa doação não pode ser marcada.';
    END IF;
END;
$$;

-- Faltou na ação de voluntariado.
CREATE FUNCTION public.mark_absent(donation uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.donations SET status = 'absent'
    WHERE id = donation AND public.owns_place(place_id) AND status = 'enrolled';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa inscrição não pode ser marcada.';
    END IF;
END;
$$;

-- ── Metas ───────────────────────────────────────────────────

CREATE FUNCTION public.close_goal(goal uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.goals SET status = 'closed', done_at = now()
    WHERE id = goal AND public.owns_place(place_id) AND status IN ('open', 'expired');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa meta não pode ser encerrada.';
    END IF;
END;
$$;

-- Prorrogar: novo prazo e a meta volta a ficar aberta.
CREATE FUNCTION public.extend_goal(goal uuid, new_deadline date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF new_deadline < (now() AT TIME ZONE 'America/Sao_Paulo')::date THEN
        RAISE EXCEPTION 'O novo prazo precisa ser hoje ou depois.';
    END IF;
    UPDATE public.goals SET deadline = new_deadline, status = 'open', done_at = NULL
    WHERE id = goal AND public.owns_place(place_id) AND status IN ('open', 'expired', 'closed');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa meta não pode ser prorrogada.';
    END IF;
END;
$$;

-- Cancelar a ação de voluntariado: a meta fecha e as inscrições caem.
CREATE FUNCTION public.cancel_action(goal uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.goals SET status = 'closed', done_at = now()
    WHERE id = goal AND public.owns_place(place_id) AND type = 'voluntariado';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa ação não pode ser cancelada.';
    END IF;
    UPDATE public.donations SET status = 'cancelled' WHERE goal_id = goal AND status = 'enrolled';
END;
$$;

-- ── Cadastro do ponto ───────────────────────────────────────

-- Uma conta, um ponto (decisão de produto). Um ponto recusado ou removido
-- não conta: a pessoa pode começar outro.
-- Vale para quem usa o app (auth.uid() existe). O seed.sql roda direto no
-- banco, sem ninguém logado, e cria os 14 pontos de teste na mesma conta.
CREATE FUNCTION public.one_place_per_owner()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.places
        WHERE owner_id = NEW.owner_id AND status NOT IN ('refused', 'removed')
    ) THEN
        RAISE EXCEPTION 'Sua conta já tem um ponto de apoio.';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER places_one_per_owner BEFORE INSERT ON public.places
    FOR EACH ROW EXECUTE FUNCTION public.one_place_per_owner();

-- Enviar para a equipe: o rascunho (ou o cadastro com ajuste) vai para a fila.
-- Pontos sem CNPJ também vão direto para a equipe, que confere a indicação.
CREATE FUNCTION public.submit_place(place uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    first_time boolean;
BEGIN
    UPDATE public.places SET status = 'review'
    WHERE id = place AND owner_id = auth.uid() AND status IN ('draft', 'adjust');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Esse cadastro não pode ser enviado agora.';
    END IF;
    first_time := NOT EXISTS (SELECT 1 FROM public.submissions WHERE place_id = place);
    -- Um envio pendente por vez.
    DELETE FROM public.submissions WHERE place_id = place AND resolved_at IS NULL AND kind <> 'mudanca';
    INSERT INTO public.submissions (place_id, kind)
    VALUES (place, CASE WHEN first_time THEN 'novo' ELSE 'correcao' END::public.submission_kind);
END;
$$;

-- Textos que não passam pela equipe: nome no mapa, sobre, o que distribui
-- e horários. O dono não tem UPDATE em ponto ativo (RLS), por isso a função.
-- patch = {"name": ..., "about": ..., "distributes": ..., "hours": ..., "receive_days": [1,2,3]}
CREATE FUNCTION public.edit_place(place uuid, patch jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.places SET
        name         = coalesce(patch ->> 'name', name),
        about        = coalesce(patch ->> 'about', about),
        distributes  = CASE WHEN patch ? 'distributes' THEN patch ->> 'distributes' ELSE distributes END,
        hours        = coalesce(patch ->> 'hours', hours),
        receive_days = coalesce(
            (SELECT array_agg(d::smallint) FROM jsonb_array_elements_text(patch -> 'receive_days') d),
            receive_days
        )
    WHERE id = place AND owner_id = auth.uid() AND status NOT IN ('refused', 'removed');
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Esse ponto não pode ser editado.';
    END IF;
END;
$$;

-- Revisão periódica: "os dados continuam certos" (a cada 90 dias).
CREATE FUNCTION public.renew_review(place uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.places SET last_reviewed = now() WHERE id = place AND owner_id = auth.uid();
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Esse ponto não é seu.';
    END IF;
END;
$$;

-- ── Mudança de dados sensíveis ──────────────────────────────
-- Endereço, foto, responsável e chave Pix passam pela equipe.
-- changes: o que a equipe lê ({"Responsável": "Ana Souza"}).
-- patch:   o que vai para places se aprovar ({"responsible": "Ana Souza"}).
ALTER TABLE public.submissions ADD COLUMN patch JSONB NOT NULL DEFAULT '{}';

CREATE FUNCTION public.request_change(place uuid, changes jsonb, patch jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.places
        WHERE id = place AND owner_id = auth.uid() AND status IN ('active', 'paused')
    ) THEN
        RAISE EXCEPTION 'Esse ponto não pode pedir mudanças agora.';
    END IF;
    -- Um pedido novo substitui o anterior que ainda está na fila.
    DELETE FROM public.submissions WHERE place_id = place AND kind = 'mudanca' AND resolved_at IS NULL;
    INSERT INTO public.submissions (place_id, kind, changes, patch)
    VALUES (place, 'mudanca', changes, patch);
END;
$$;

-- Trocar a chave Pix pausa o Pix do ponto até a equipe aprovar a chave nova.
CREATE FUNCTION public.change_pix_key(place uuid, key_type text, key text, new_payee text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    PERFORM public.request_change(
        place,
        jsonb_build_object('Chave Pix', key_type || ': ' || key, 'Favorecido', new_payee),
        jsonb_build_object('pix_key_type', key_type, 'pix_key', key, 'payee', new_payee)
    );
    UPDATE public.places SET pix_paused = true WHERE id = place;
END;
$$;
