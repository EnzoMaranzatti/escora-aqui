-- Fase 7: avisos em tempo real e tarefas diárias.
-- Os avisos já nascem pelos gatilhos e funções das fases 4 a 6. Aqui:
--   1. o app passa a receber avisos novos na hora (Realtime);
--   2. uma tarefa diária (pg_cron) fecha metas vencidas e manda lembretes.
-- Push no celular fica de fora: no iPhone exige a conta paga da Apple.

-- ── Tempo real ──────────────────────────────────────────────
-- "supabase_realtime" é a lista de tabelas que o Supabase transmite.
-- O RLS continua valendo: cada um só recebe os próprios avisos, e só a
-- equipe recebe a fila e as denúncias.
ALTER PUBLICATION supabase_realtime ADD TABLE public.notices, public.submissions, public.reports;

-- ── A tarefa diária ─────────────────────────────────────────
CREATE FUNCTION public.daily_jobs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    today date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
BEGIN
    -- 1. Metas com prazo vencido saem do mapa como "expirada".
    UPDATE public.goals SET status = 'expired', done_at = now()
    WHERE status = 'open' AND deadline < today;

    -- 2. Voluntariado: lembrete na véspera para quem está inscrito.
    INSERT INTO public.notices (user_id, kind, title, body, place_id)
    SELECT d.donor_id, 'volunteer_reminder',
           'Amanhã: ' || g.action_name,
           'Das ' || public.fmt_hour(g.action_start) || ' às ' || public.fmt_hour(g.action_end)
               || ', em ' || p.street || ', ' || p.number || ' · ' || p.neighborhood || '.',
           p.id
    FROM public.donations d
    JOIN public.goals g ON g.id = d.goal_id
    JOIN public.places p ON p.id = d.place_id
    JOIN public.profiles pr ON pr.id = d.donor_id
    WHERE d.status = 'enrolled' AND g.action_day = today + 1 AND pr.notify_volunteer;

    -- 3. Doação mensal: lembrete no dia escolhido, se o mês ainda não foi pago.
    INSERT INTO public.notices (user_id, kind, title, body, place_id)
    SELECT m.donor_id, 'monthly_reminder',
           'Dia da sua doação mensal',
           public.fmt_money(m.amount) || ' para ' || p.name || '. Toque para fazer o Pix com o valor pronto.',
           p.id
    FROM public.monthly_gifts m
    JOIN public.places p ON p.id = m.place_id
    WHERE NOT m.paused
      AND p.status = 'active'
      AND m.day = extract(day FROM today)
      AND NOT EXISTS (
          SELECT 1 FROM public.donations d
          WHERE d.monthly_gift_id = m.id
            AND date_trunc('month', d.created_at AT TIME ZONE 'America/Sao_Paulo') = date_trunc('month', today::timestamp)
      );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.daily_jobs FROM public, anon, authenticated;

-- pg_cron: o "despertador" do Postgres, gratuito no Supabase.
-- '0 11 * * *' = todo dia às 11h UTC, que são 8h em Brasília.
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('escora-tarefas-diarias', '0 11 * * *', 'SELECT public.daily_jobs()');
