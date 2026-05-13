-- factories UPDATE 정책: factory_admin도 자기 공장 기본 정보 수정 가능
DROP POLICY IF EXISTS factories_update ON public.factories;
CREATE POLICY factories_update ON public.factories FOR UPDATE
  USING (
    (my_role() = 'super_admin'::user_role)
    OR (my_role() = 'factory_admin'::user_role AND id = my_factory_id())
  );

-- deleted_at 변경(비활성화/활성화)은 super_admin만 가능하도록 트리거로 강제
CREATE OR REPLACE FUNCTION public.prevent_factory_deactivate_by_non_super()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
    IF my_role() <> 'super_admin'::user_role THEN
      RAISE EXCEPTION 'permission denied: only super_admin can deactivate/activate factories';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_factory_deactivate ON public.factories;
CREATE TRIGGER trg_prevent_factory_deactivate
  BEFORE UPDATE ON public.factories
  FOR EACH ROW EXECUTE FUNCTION public.prevent_factory_deactivate_by_non_super();
