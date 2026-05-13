-- factories: super_admin만 UPDATE/DELETE/INSERT 가능 (원복)
-- factory_admin은 /factories 자체에 접근 불가 (서버 레벨 redirect)
-- 따라서 RLS는 단순하게 super_admin 전용으로 유지

DROP POLICY IF EXISTS factories_update ON public.factories;
CREATE POLICY factories_update ON public.factories FOR UPDATE
  USING (my_role() = 'super_admin'::user_role);

-- 이전 마이그레이션에서 생성한 트리거/함수 제거
DROP TRIGGER IF EXISTS trg_prevent_factory_deactivate ON public.factories;
DROP FUNCTION IF EXISTS public.prevent_factory_deactivate_by_non_super();
