-- 1. invoices.status 컬럼 및 CHECK 제약 제거
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_status_check;
ALTER TABLE public.invoices DROP COLUMN IF EXISTS status;

-- 2. log_type enum 생성
CREATE TYPE public.log_type AS ENUM ('in', 'out');

-- 3. inventory_logs.log_type 컬럼 타입 변경 (text → log_type)
ALTER TABLE public.inventory_logs DROP CONSTRAINT IF EXISTS inventory_logs_log_type_check;
ALTER TABLE public.inventory_logs
  ALTER COLUMN log_type TYPE public.log_type USING log_type::text::public.log_type;
