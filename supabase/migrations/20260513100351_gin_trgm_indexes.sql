-- pg_trgm 확장 활성화 (trigram 기반 ilike 가속)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- factories.name GIN trigram 인덱스
CREATE INDEX IF NOT EXISTS factories_name_trgm_idx
  ON public.factories USING gin (name gin_trgm_ops);

-- profiles.full_name GIN trigram 인덱스 (사용자 검색)
CREATE INDEX IF NOT EXISTS profiles_full_name_trgm_idx
  ON public.profiles USING gin (full_name gin_trgm_ops);
