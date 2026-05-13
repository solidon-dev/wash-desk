-- clients 테이블에 soft delete용 deleted_at 컬럼 추가
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz DEFAULT NULL;
