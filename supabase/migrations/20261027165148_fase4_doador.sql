-- Fase 4: quem doa registra Pix, itens e voluntariado, segue pontos,
-- avalia, denuncia e faz doação mensal. As regras que não podem depender
-- do app (vagas, meta aberta, quem vê o quê) ficam aqui no banco.

-- ── Textos iguais aos do app (lib/core/format.dart) ─────────

-- 1234.5 → "R$ 1.234,50"; sem centavos quando cents = false e o valor é inteiro.
CREATE FUNCTION public.fmt_money(v numeric, cents boolean DEFAULT true)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT 'R$ ' || translate(
        to_char(v, CASE WHEN NOT cents AND v = trunc(v) THEN 'FM999,999,990' ELSE 'FM999,999,990.00' END),
        ',.', '.,'
    );
$$;

-- 1234 → "1.234"
CREATE FUNCTION public.fmt_count(v numeric)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT translate(to_char(round(v), 'FM999,999,990'), ',', '.');
$$;

-- 570 minutos → "9h30"; 540 → "9h"
CREATE FUNCTION public.fmt_hour(minutes integer)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT (minutes / 60)::text || 'h' || CASE WHEN minutes % 60 = 0 THEN '' ELSE lpad((minutes % 60)::text, 2, '0') END;
$$;

-- Quantidade de uma meta: "R$ 50,00", "3 kg de feijão", "40 cobertores", "2 voluntários".
CREATE FUNCTION public.fmt_amount(g public.goals, v numeric, cents boolean DEFAULT true)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
    SELECT CASE g.type
        WHEN 'pix' THEN public.fmt_money(v, cents)
        WHEN 'itens' THEN
            CASE WHEN g.unit = 'unidades' THEN public.fmt_count(v) || ' ' || g.item
                 ELSE public.fmt_count(v) || ' ' || g.unit || ' de ' || g.item END
        ELSE CASE WHEN round(v) = 1 THEN '1 voluntário' ELSE public.fmt_count(v) || ' voluntários' END
    END;
$$;

-- ── Avisos ──────────────────────────────────────────────────
-- Todo aviso nasce por esta função, chamada pelos gatilhos e pelas funções
-- das fases 4 a 7. Ninguém insere em notices pelo app (não há política de INSERT).
CREATE FUNCTION public.notify(
    target uuid, kind public.notice_kind, title text, body text, place uuid DEFAULT NULL
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER SET search_path = ''
AS $$
    INSERT INTO public.notices (user_id, kind, title, body, place_id)
    SELECT target, kind, title, body, place
    WHERE target IS NOT NULL;
$$;

-- As funções internas não ficam abertas para chamar pelo app.
REVOKE EXECUTE ON FUNCTION public.notify FROM public, anon, authenticated;

-- ── Doação nova: conferir antes de gravar ───────────────────
-- Roda antes de cada INSERT em donations. RAISE EXCEPTION cancela a gravação
-- e a mensagem chega no app como erro (PostgrestException).
CREATE FUNCTION public.check_new_donation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    p public.places;
    g public.goals;
BEGIN
    SELECT * INTO p FROM public.places WHERE id = NEW.place_id;
    IF p.status IS DISTINCT FROM 'active' THEN
        RAISE EXCEPTION 'Este ponto não está recebendo doações agora.';
    END IF;
    IF NEW.type = 'pix' AND p.pix_paused THEN
        RAISE EXCEPTION 'O Pix deste ponto está pausado enquanto a chave nova é analisada.';
    END IF;

    -- O status depende só do tipo: o app não escolhe.
    NEW.status := CASE NEW.type
        WHEN 'pix' THEN 'waiting'
        WHEN 'itens' THEN 'items_agreed'
        ELSE 'enrolled'
    END::public.donation_status;
    NEW.confirmed_at := NULL;

    IF NEW.goal_id IS NULL THEN
        -- Só a doação mensal pode vir sem meta (quando o ponto não tem meta de Pix aberta).
        IF NEW.type <> 'pix' OR NEW.monthly_gift_id IS NULL THEN
            RAISE EXCEPTION 'Escolha uma meta para doar.';
        END IF;
    ELSE
        SELECT * INTO g FROM public.goals WHERE id = NEW.goal_id;
        IF g.place_id IS DISTINCT FROM NEW.place_id OR g.type IS DISTINCT FROM NEW.type THEN
            RAISE EXCEPTION 'Essa meta não é deste ponto.';
        END IF;
        IF g.status <> 'open' OR NOT g.published THEN
            RAISE EXCEPTION 'Essa meta não está mais aberta.';
        END IF;
        IF NEW.type = 'voluntariado' THEN
            IF g.enrolled >= g.target THEN
                RAISE EXCEPTION 'As vagas dessa ação acabaram.';
            END IF;
            IF EXISTS (
                SELECT 1 FROM public.donations
                WHERE goal_id = g.id AND donor_id = NEW.donor_id AND status = 'enrolled'
            ) THEN
                RAISE EXCEPTION 'Você já está inscrito nessa ação.';
            END IF;
            NEW.amount := 1;
            NEW.scheduled_for := g.action_day;
        END IF;
    END IF;

    IF NEW.monthly_gift_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.monthly_gifts WHERE id = NEW.monthly_gift_id AND donor_id = NEW.donor_id
    ) THEN
        RAISE EXCEPTION 'Essa doação mensal não é sua.';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER donations_check BEFORE INSERT ON public.donations
    FOR EACH ROW EXECUTE FUNCTION public.check_new_donation();

-- ── Doação nova: depois de gravar ───────────────────────────
-- Voluntariado ocupa uma vaga; Pix e itens avisam a instituição.
CREATE FUNCTION public.after_new_donation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    g public.goals;
    what text;
BEGIN
    IF NEW.type = 'voluntariado' THEN
        UPDATE public.goals SET enrolled = enrolled + 1 WHERE id = NEW.goal_id;
        RETURN NULL;
    END IF;

    SELECT * INTO g FROM public.goals WHERE id = NEW.goal_id;
    what := CASE WHEN g.id IS NULL THEN public.fmt_money(NEW.amount) ELSE public.fmt_amount(g, NEW.amount) END;
    PERFORM public.notify(
        (SELECT owner_id FROM public.places WHERE id = NEW.place_id),
        'new_donation',
        'Nova doação para confirmar',
        NEW.donor_name || ' registrou ' || what || '.',
        NEW.place_id
    );
    RETURN NULL;  -- em gatilho AFTER, o retorno é ignorado
END;
$$;

CREATE TRIGGER donations_after_insert AFTER INSERT ON public.donations
    FOR EACH ROW EXECUTE FUNCTION public.after_new_donation();

-- ── Cancelar inscrição no voluntariado ──────────────────────
-- Quem doa não tem UPDATE em donations (RLS). Esta função faz só esta troca.
-- A vaga volta pelo gatilho de mudança de status (fase 5).
CREATE FUNCTION public.cancel_enrollment(donation uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    UPDATE public.donations SET status = 'cancelled'
    WHERE id = donation AND donor_id = auth.uid() AND status = 'enrolled';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Essa inscrição não pode mais ser cancelada.';
    END IF;
END;
$$;

-- ── Meta nova: avisar quem segue o ponto ────────────────────
-- Vale para a meta publicada num ponto ativo e para as metas guardadas
-- que a aprovação publica (published false → true).
CREATE FUNCTION public.announce_goal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    p public.places;
BEGIN
    IF NOT NEW.published OR NEW.status <> 'open' THEN RETURN NULL; END IF;
    IF TG_OP = 'UPDATE' AND OLD.published THEN RETURN NULL; END IF;
    SELECT * INTO p FROM public.places WHERE id = NEW.place_id;
    IF p.status <> 'active' THEN RETURN NULL; END IF;

    INSERT INTO public.notices (user_id, kind, title, body, place_id)
    SELECT f.user_id, 'new_goal',
           p.name || ' abriu uma meta',
           public.fmt_amount(NEW, NEW.target, false) || ' até ' || to_char(NEW.deadline, 'DD/MM') || '.',
           p.id
    FROM public.follows f
    JOIN public.profiles pr ON pr.id = f.user_id
    WHERE f.place_id = p.id AND pr.notify_goals AND f.user_id <> p.owner_id;
    RETURN NULL;
END;
$$;

CREATE TRIGGER goals_announce AFTER INSERT OR UPDATE OF published ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.announce_goal();

-- ── Fotos e comprovantes (Storage) ──────────────────────────
-- Três "baldes": fotos dos pontos e de perfil são públicas (qualquer um vê
-- pelo link); comprovantes de Pix são privados.
INSERT INTO storage.buckets (id, name, public) VALUES
    ('places', 'places', true),
    ('avatars', 'avatars', true),
    ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

-- Cada pessoa grava só dentro da pasta com o próprio id: <id>/arquivo.jpg
-- storage.foldername('abc/foto.jpg') = {abc}
CREATE POLICY "arquivos: enviar na sua pasta"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id IN ('places', 'avatars', 'receipts')
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "arquivos: apagar da sua pasta"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id IN ('places', 'avatars', 'receipts')
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- O comprovante: quem enviou, a instituição que recebeu e a equipe.
CREATE POLICY "comprovantes: ver"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'receipts'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_team()
        OR EXISTS (
            SELECT 1 FROM public.donations d
            WHERE d.receipt_path = storage.objects.name AND public.owns_place(d.place_id)
        )
    )
);
