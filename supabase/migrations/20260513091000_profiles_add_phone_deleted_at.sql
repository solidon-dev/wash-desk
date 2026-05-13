-- profiles 에 phone, deleted_at 추가
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

CREATE INDEX IF NOT EXISTS profiles_deleted_at_idx ON public.profiles(deleted_at);

-- deleted_at 있는 유저는 자기 자신도 못 봄
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (
    (id = auth.uid() AND deleted_at IS NULL)
    OR my_role() = 'super_admin'::public.user_role
    OR (my_factory_id() IS NOT NULL AND factory_id = my_factory_id() AND deleted_at IS NULL)
  );

-- super_admin 만 profiles insert 가능 (유저 생성은 서버 액션에서 admin API 사용)
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (my_role() = 'super_admin'::public.user_role);
