-- Fase 6: a equipe de validação aprova, pede ajuste, recusa e cuida das
-- denúncias. Cada função começa conferindo is_team() e termina avisando o
-- dono do ponto, como o store.dart fazia em memória.

-- Fecha um item da fila: quem decidiu e quando.
CREATE FUNCTION public.resolve_submission(sub uuid)
RETURNS public.submissions
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    s public.submissions;
BEGIN
    IF NOT public.is_team() THEN
        RAISE EXCEPTION 'Só a equipe de validação pode fazer isso.';
    END IF;
    UPDATE public.submissions SET resolved_at = now(), resolved_by = auth.uid()
    WHERE id = sub AND resolved_at IS NULL
    RETURNING * INTO s;
    IF s.id IS NULL THEN
        RAISE EXCEPTION 'Esse item já saiu da fila.';
    END IF;
    RETURN s;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_submission FROM public, anon, authenticated;

-- ── Aprovar ─────────────────────────────────────────────────
-- Cadastro novo ou correção: o ponto entra no mapa e as metas guardadas
-- são publicadas. Mudança de dados: os dados novos (patch) vão para o ponto.
CREATE FUNCTION public.approve_submission(sub uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    s public.submissions := public.resolve_submission(sub);
    p public.places;
BEGIN
    IF s.kind = 'mudanca' THEN
        UPDATE public.places SET
            pix_key_type = coalesce(s.patch ->> 'pix_key_type', pix_key_type),
            pix_key      = coalesce(s.patch ->> 'pix_key', pix_key),
            payee        = coalesce(s.patch ->> 'payee', payee),
            pix_paused   = CASE WHEN s.patch ? 'pix_key' THEN false ELSE pix_paused END,
            responsible  = coalesce(s.patch ->> 'responsible', responsible),
            street       = coalesce(s.patch ->> 'street', street),
            number       = coalesce(s.patch ->> 'number', number),
            neighborhood = coalesce(s.patch ->> 'neighborhood', neighborhood),
            photo_path   = coalesce(s.patch ->> 'photo_path', photo_path),
            last_reviewed = now()
        WHERE id = s.place_id
        RETURNING * INTO p;
        PERFORM public.notify(p.owner_id, 'approved', 'Mudança aprovada',
            'Os dados novos de ' || p.name || ' já aparecem no app.', p.id);
        RETURN;
    END IF;

    UPDATE public.places SET
        status = 'active',
        verified_at = coalesce(verified_at, now()),
        last_reviewed = now(),
        status_reason = NULL,
        status_message = NULL
    WHERE id = s.place_id
    RETURNING * INTO p;
    -- O gatilho goals_announce (fase 4) avisa quem segue o ponto.
    UPDATE public.goals SET published = true WHERE place_id = p.id AND NOT published;
    PERFORM public.notify(p.owner_id, 'approved', p.name || ' está no mapa',
        'Seu ponto foi verificado. Já dá para criar metas.', p.id);
END;
$$;

-- ── Pedir ajuste ────────────────────────────────────────────
-- reasons: os motivos marcados, já juntos em um texto ("a foto não mostra o local; ...").
-- Numa mudança de dados, o ponto continua como está: só a mudança volta.
CREATE FUNCTION public.ask_adjust(sub uuid, reasons text, message text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    s public.submissions := public.resolve_submission(sub);
    p public.places;
BEGIN
    IF s.kind = 'mudanca' THEN
        UPDATE public.places SET pix_paused = false WHERE id = s.place_id RETURNING * INTO p;
        PERFORM public.notify(p.owner_id, 'adjust', 'Sua mudança de dados não foi aprovada',
            'Motivo: ' || reasons || '. Os dados anteriores continuam valendo.', p.id);
        RETURN;
    END IF;
    UPDATE public.places SET status = 'adjust', status_reason = reasons, status_message = nullif(trim(message), '')
    WHERE id = s.place_id
    RETURNING * INTO p;
    PERFORM public.notify(p.owner_id, 'adjust', 'Seu cadastro precisa de um ajuste',
        'Motivo: ' || reasons || '. Toque para corrigir.', p.id);
END;
$$;

-- ── Recusar ─────────────────────────────────────────────────
CREATE FUNCTION public.refuse_submission(sub uuid, reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    s public.submissions := public.resolve_submission(sub);
    p public.places;
BEGIN
    IF s.kind = 'mudanca' THEN
        UPDATE public.places SET pix_paused = false WHERE id = s.place_id RETURNING * INTO p;
        PERFORM public.notify(p.owner_id, 'refused', 'Sua mudança de dados não foi aprovada',
            'Motivo: ' || trim(reason) || '.', p.id);
        RETURN;
    END IF;
    UPDATE public.places SET status = 'refused', status_reason = trim(reason)
    WHERE id = s.place_id
    RETURNING * INTO p;
    PERFORM public.notify(p.owner_id, 'refused', 'Seu cadastro não foi aprovado',
        'Motivo: ' || trim(reason) || '.', p.id);
END;
$$;

-- ── Denúncias e pontos no mapa ──────────────────────────────

-- Fecha as denúncias abertas de um ponto.
CREATE FUNCTION public.resolve_reports(place uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER SET search_path = ''
AS $$
    UPDATE public.reports SET resolved_at = now(), resolved_by = auth.uid()
    WHERE place_id = place AND resolved_at IS NULL;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_reports FROM public, anon, authenticated;

CREATE FUNCTION public.team_only()
RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_team() THEN
        RAISE EXCEPTION 'Só a equipe de validação pode fazer isso.';
    END IF;
END;
$$;

-- A denúncia não procede: o ponto continua no mapa.
CREATE FUNCTION public.keep_on_map(place uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    PERFORM public.team_only();
    PERFORM public.resolve_reports(place);
END;
$$;

-- Pausar: sai do mapa enquanto a equipe analisa.
CREATE FUNCTION public.pause_place(place uuid, reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    p public.places;
BEGIN
    PERFORM public.team_only();
    UPDATE public.places SET status = 'paused', status_reason = trim(reason)
    WHERE id = place AND status = 'active'
    RETURNING * INTO p;
    IF p.id IS NULL THEN
        RAISE EXCEPTION 'Só um ponto ativo pode ser pausado.';
    END IF;
    PERFORM public.resolve_reports(place);
    PERFORM public.notify(p.owner_id, 'paused', 'Seu ponto foi pausado',
        'Recebemos uma denúncia e estamos analisando. Motivo: ' || p.status_reason || '.', p.id);
END;
$$;

-- Remover: sai do mapa de vez e as metas abertas fecham.
CREATE FUNCTION public.remove_place(place uuid, reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    p public.places;
BEGIN
    PERFORM public.team_only();
    UPDATE public.places SET status = 'removed', status_reason = trim(reason)
    WHERE id = place AND status IN ('active', 'paused')
    RETURNING * INTO p;
    IF p.id IS NULL THEN
        RAISE EXCEPTION 'Esse ponto não pode ser removido.';
    END IF;
    UPDATE public.goals SET status = 'closed', done_at = now() WHERE place_id = place AND status = 'open';
    PERFORM public.resolve_reports(place);
    PERFORM public.notify(p.owner_id, 'refused', p.name || ' saiu do mapa',
        'Motivo: ' || p.status_reason || '.', p.id);
END;
$$;

-- Reativar: a análise terminou e o ponto volta ao mapa.
CREATE FUNCTION public.reactivate_place(place uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    p public.places;
BEGIN
    PERFORM public.team_only();
    UPDATE public.places SET status = 'active', status_reason = NULL, status_message = NULL
    WHERE id = place AND status IN ('paused', 'removed')
    RETURNING * INTO p;
    IF p.id IS NULL THEN
        RAISE EXCEPTION 'Esse ponto já está no mapa.';
    END IF;
    PERFORM public.notify(p.owner_id, 'reactivated', p.name || ' está de volta no mapa',
        'A análise terminou. Suas metas voltaram a aparecer.', p.id);
END;
$$;
