-- Fase 8: apagar a própria conta (LGPD; a Apple também exige em apps com cadastro).
-- Apagar de auth.users leva junto, pelos ON DELETE da fase 1:
--   profiles, o ponto da pessoa (e as metas e doações dele), follows,
--   notices e doações mensais. Nas doações feitas a outros pontos, o
--   doador vira NULL: a instituição mantém o histórico sem saber quem foi.
CREATE FUNCTION public.delete_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Entre na sua conta para apagá-la.';
    END IF;
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_account FROM public, anon;
