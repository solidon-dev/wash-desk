-- factory_id: super_admin 이 아닌 계정은 반드시 공장 지정
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_factory_id_required;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_factory_id_required
    CHECK (
      role = 'super_admin'::public.user_role
      OR factory_id IS NOT NULL
    );

-- phone: 01012345678 형태 (숫자만, 010/011/016/017/018/019 로 시작, 10~11자리)
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_phone_format;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_phone_format
    CHECK (
      phone IS NULL
      OR phone ~ '^01[016789][0-9]{7,8}$'
    );
