# Supabase 작업 에이전트 가이드

이 문서는 AI 에이전트가 이 프로젝트의 Supabase DB 작업을 처음부터 끝까지 수행할 수 있도록 작성된 가이드입니다.

---

## ⚡ 에이전트 시작 프로토콜 (항상 맨 먼저 실행)

작업 시작 전 아래 순서를 반드시 따른다.

### 1단계. SECRETS.md 존재 여부 확인

`supabase/SECRETS.md` 파일이 존재하는지 확인한다.

- **파일이 있으면** → 파일을 읽어 시크릿 정보를 로드하고 바로 작업을 시작한다.
- **파일이 없으면** → 2단계로 이동한다.

### 2단계. 사용자에게 정보 요청 (SECRETS.md 없을 때만)

아래 항목을 사용자에게 요청한다. 한꺼번에 달라고 한다.

| 항목 | 설명 |
|------|------|
| WSL sudo 패스워드 | WSL Ubuntu의 sudo 비밀번호 |
| Supabase DB 패스워드 | Supabase 프로젝트 DB 비밀번호 |
| Supabase Access Token | 대시보드 발급 토큰 (`sbp_`로 시작) |
| Supabase Anon Key | 대시보드 → Settings → API → anon public |

> Access Token 발급: https://supabase.com/dashboard/account/tokens → "Generate new token"

### 3단계. SECRETS.md 생성

정보를 받으면 즉시 `supabase/SECRETS.md` 를 아래 형식으로 생성한다.
이 파일은 `.gitignore`에 등록되어 있으므로 깃헙에 올라가지 않는다.

```markdown
# 프로젝트 시크릿 정보

> ⚠️ 이 파일은 .gitignore에 등록되어 있습니다. 절대 커밋/푸시하지 마세요.

## WSL

| 항목 | 값 |
|------|-----|
| sudo 패스워드 | 입력값 |
| WSL 유저 | winco |

## Supabase

| 항목 | 값 |
|------|-----|
| Project Ref | jmyxnyrhymqyqzyvknox |
| DB 패스워드 | 입력값 |
| Anon Key | 입력값 |
| Service Role Key | 입력값 |
| Access Token | 입력값 |
| DB Host (Pooler) | aws-1-ap-northeast-2.pooler.supabase.com |
| DB Host (Direct) | db.jmyxnyrhymqyqzyvknox.supabase.co (IPv6 전용) |
| DB Port | 5432 |
| DB Name | postgres |
| DB User (Pooler) | postgres.jmyxnyrhymqyqzyvknox |
| Dashboard URL | https://supabase.com/dashboard/project/jmyxnyrhymqyqzyvknox |

## 프로젝트 경로

| 항목 | 값 |
|------|-----|
| Windows 경로 | C:\Users\winco\OneDrive\Desktop\wash-desk-admin |
| WSL 경로 | /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin |
```

파일 생성 후 바로 작업을 시작한다.

---

## 환경 정보

- **OS**: Windows + WSL2 (Ubuntu 26.04)
- **Supabase Project Ref**: `jmyxnyrhymqyqzyvknox`
- **DB Host (Direct)**: `db.jmyxnyrhymqyqzyvknox.supabase.co` ← IPv6 전용, WSL에서 안 됨
- **DB Host (Session Pooler)**: `aws-1-ap-northeast-2.pooler.supabase.com` ← IPv4, WSL에서 사용
- **DB Port**: `5432`
- **DB Name**: `postgres`
- **DB User (Pooler용)**: `postgres.jmyxnyrhymqyqzyvknox`
- **DB User (Direct용)**: `postgres`

> ⚠️ WSL 환경은 IPv4만 지원하므로 **반드시 Session Pooler 호스트**를 사용해야 합니다.

---

## 사전 준비 — 도구 설치 여부 확인

작업 시작 전 아래 명령어로 설치 여부를 먼저 확인하세요.

```
wsl bash -c "which psql; psql --version; which supabase; supabase --version; which docker; docker --version"
```

---

## Step 1. psql 설치 (미설치 시)

```
wsl bash -c "echo 'WSL_PASSWORD' | sudo -S apt-get update -y && echo 'WSL_PASSWORD' | sudo -S apt-get install -y postgresql-client"
```

---

## Step 2. Supabase CLI 설치 (미설치 시)

```
wsl bash -c "curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz -o /tmp/supabase.tar.gz && tar -xzf /tmp/supabase.tar.gz -C /tmp && echo 'WSL_PASSWORD' | sudo -S mv /tmp/supabase /usr/local/bin/supabase"
```

설치 확인:
```
wsl bash -c "supabase --version"
```

---

## Step 3. Docker Engine 설치 (미설치 시)

`supabase db pull` 은 내부적으로 Docker를 사용합니다. Docker Desktop 없이 WSL에 Engine만 설치합니다.

```
wsl bash -c "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && echo 'WSL_PASSWORD' | sudo -S sh /tmp/get-docker.sh"
```

Docker 데몬 시작 및 권한 설정:
```
wsl bash -c "echo 'WSL_PASSWORD' | sudo -S service docker start && echo 'WSL_PASSWORD' | sudo -S usermod -aG docker $(whoami)"
```

이후 명령은 `sudo docker` 대신 `sudo -S docker` 형태로 실행하세요.

---

## Step 4. DB 연결 테스트

```
wsl bash -c "PGPASSWORD='DB_PASSWORD' psql -h aws-1-ap-northeast-2.pooler.supabase.com -U postgres.jmyxnyrhymqyqzyvknox -d postgres -c '\dt public.*'"
```

테이블 목록이 출력되면 연결 성공입니다.

---

## Step 5. Supabase 프로젝트 초기화 및 링크

프로젝트 루트에서 실행:

```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && supabase init"
```

링크:
```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase link --project-ref jmyxnyrhymqyqzyvknox --password 'DB_PASSWORD'"
```

---

## Step 6. DB Pull (마이그레이션 파일 생성)

```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase db pull --password 'DB_PASSWORD' --linked"
```

### 오류 대응

**① 마이그레이션 히스토리 불일치 오류**
```
The remote database's migration history does not match local files...
```
→ 에러 메시지에서 마이그레이션 ID를 확인하고 repair 실행:
```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase migration repair --status applied MIGRATION_ID --password 'DB_PASSWORD' --linked"
```
그 후 `db pull` 재시도.

**② Docker 연결 오류**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```
→ Step 3으로 돌아가 Docker Engine 설치 후 데몬 시작.

---

## Step 7. DB Push (다른 프로젝트에 스키마 적용)

새 Supabase 프로젝트에 현재 스키마를 적용할 때:

1. 새 프로젝트 ref로 link:
```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase link --project-ref NEW_PROJECT_REF --password 'NEW_DB_PASSWORD'"
```

2. push:
```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase db push --password 'NEW_DB_PASSWORD' --linked"
```

---

## Step 8. 리모트 DB 변경 워크플로우 (마이그레이션 push)

> ✅ Docker 불필요 — 리모트에 즉시 반영됩니다.

RPC 추가, RLS 변경, 테이블 수정 등 DB 스키마를 바꿀 때 사용합니다.
히스토리가 남아 추적이 가능하므로 psql 직접 실행보다 이 방법을 권장합니다.

**1) 마이그레이션 파일 생성**
```
wsl -e bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase migration new MIGRATION_NAME"
```
→ `supabase/migrations/TIMESTAMP_MIGRATION_NAME.sql` 파일이 생성됩니다.

**2) SQL 작성**

생성된 파일에 실행할 SQL을 작성합니다.

```sql
-- 예: RPC 추가
CREATE OR REPLACE FUNCTION public.my_function(p_id uuid)
RETURNS json
LANGUAGE plpgsql
AS $$
BEGIN
  -- ...
END;
$$;

-- 예: RLS 정책 추가
CREATE POLICY "factory_member_only" ON public.invoices
  FOR ALL USING (is_factory_member(factory_id));

-- 예: 컬럼 추가
ALTER TABLE public.clients ADD COLUMN memo text;
```

**3) 리모트에 push**
```
wsl -e bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase db push --password 'DB_PASSWORD' --linked"
```

**4) 타입 재생성**

DB 스키마가 바뀌었으므로 Step 9 타입 생성을 반드시 실행하세요.

---

## Step 9. Edge Function 배포

> ✅ Docker 불필요 — 리모트에 즉시 배포됩니다.
> ❌ 로컬 실행(serve)은 Docker 필요

**1) 함수 파일 생성 (신규일 때)**
```
wsl -e bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase functions new FUNCTION_NAME"
```
→ `supabase/functions/FUNCTION_NAME/index.ts` 파일이 생성됩니다.

**2) 함수 코드 작성**

`supabase/functions/FUNCTION_NAME/index.ts` 에 Deno 기반 TypeScript로 작성합니다.

```ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

serve(async (req) => {
  const { name } = await req.json();
  return new Response(JSON.stringify({ message: `Hello ${name}` }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

**3) 리모트에 배포**
```
wsl -e bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase functions deploy FUNCTION_NAME"
```

**4) 배포된 함수 목록 확인**
```
wsl -e bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase functions list"
```

**5) 클라이언트에서 호출**
```ts
const { data, error } = await supabase.functions.invoke('FUNCTION_NAME', {
  body: { name: 'world' },
});
```

---

## Step 10. TypeScript 타입 생성 (type gen)

DB 스키마 변경 후 타입을 최신화할 때 실행합니다.

**1) Docker 데몬 시작**
```
wsl -e bash -c "echo WSL_PASSWORD | sudo -S service docker start && echo STARTED"
```

**2) 타입 생성**
```
wsl -e bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase gen types typescript --linked --schema public > src/lib/supabase/database.types.ts"
```

**3) 첫 줄 오염 확인 (중요)**

> ⚠️ 출력 파일 첫 줄에 Docker 로그(`Initialising login role...`)가 섞여 들어올 수 있습니다.
> 생성 후 `database.types.ts` 첫 줄이 `export type Json =` 으로 시작하는지 확인하고,
> 그 이전의 불필요한 줄은 반드시 삭제하세요.

**4) types.ts 재생성**

`database.types.ts` 가 갱신되면 `src/lib/supabase/types.ts` 도 테이블/RPC 목록에 맞게 다시 작성해야 합니다.
`types.ts` 는 `database.types.ts` 에서 자동 export 되는 헬퍼 타입(`Tables`, `TablesInsert`, `TablesUpdate`, `Enums`)을 그대로 import 해서 각 테이블/RPC 별 named alias 를 만드는 파일입니다.

---

## Step 11. Supabase 클라이언트 초기화 구조

**파일 위치:**
```
src/lib/supabase/
├── database.types.ts   # supabase gen types 자동 생성 — 절대 직접 수정 금지
├── types.ts            # 외부에서 임포트할 타입 레퍼 — 여기서만 가져다 쓸 것
└── client.ts           # createClient 초기화
```

**`.env` 파일 (프로젝트 루트):**
```
PUBLIC_SUPABASE_URL=https://jmyxnyrhymqyqzyvknox.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your-anon-key
PRIVATE_SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

> `PRIVATE_` 접두사가 붙은 변수는 SvelteKit 서버에서만 접근 가능. 클라이언트에 절대 노출되지 않음.
> Service Role Key 는 Supabase 대시보드 → Settings → API → `service_role secret` 에서 확인.

**`client.ts` 내용:**
```
import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import type { Database } from './database.types';

export const supabase = createClient<Database>(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);
```

**`types.ts` 작성 규칙:**
- `database.types.ts` 에서 `Tables`, `TablesInsert`, `TablesUpdate`, `Enums` 를 import
- 각 테이블 Row/Insert/Update named alias 를 만든다
- `Database['public']['Functions']` 에서 RPC `Args` / `Returns` alias 를 만든다
- 직접 `Database['public']['Tables'][T]['Row']` 같이 중첩 접근하지 않는다

**사용 예시:**
```
// 타입만 쓸 때
import type { Invoice, InvoiceInsert, ProcessInventoryOutArgs } from '$lib/supabase/types';

// 쿼리할 때
import { supabase } from '$lib/supabase/client';
const { data, error } = await supabase.from('invoices').select('*');

// RPC 호출
const { data } = await supabase.rpc('process_inventory_out', { p_inventory_id: '...', p_quantity: 1, p_created_by: '...' });
```

---

## Step 12. API 파일 컨벤션 (`src/lib/api/`)

이 프로젝트의 Supabase 쿼리/돌연산 로직은 모두 `src/lib/api/` 하에 둥니다.

**폴더 구조:**
```
src/lib/api/
├── auth.ts          # Supabase Auth 세션/로그인/로그아웃 (테이블 아님, 예외)
├── profiles.ts      # profiles 테이블 CRUD
├── clients.ts       # clients 테이블 CRUD
├── invoices.ts      # invoices 테이블 CRUD
├── ...              # 테이블명과 1:1 매핑
└── rpc.ts           # RPC 함수 모음 (커지면 주제별로 분리)
```

**서버 전용 Admin API 구조:**

유저 생성/밴/삭제 등 `service_role` 이 필요한 작업은 반드시 서버에서만 처리한다.

```
src/routes/(app)/users/
└── +page.server.ts   # form actions — createUser, updateUser, banUser, unbanUser
```

서버 액션 내부에서 Admin 클라이언트를 이렇게 초기화한다:
```ts
import { PRIVATE_SUPABASE_SERVICE_ROLE_KEY } from '$env/static/private';
import { PUBLIC_SUPABASE_URL } from '$env/static/public';
import { createClient } from '@supabase/supabase-js';

const adminClient = createClient(PUBLIC_SUPABASE_URL, PRIVATE_SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

// 유저 생성
await adminClient.auth.admin.createUser({
  email: `${username}@mail.com`,
  password,
  email_confirm: true,
  user_metadata: { full_name: name }
});

// 밴 (876600h = 100년)
await adminClient.auth.admin.updateUser(userId, { ban_duration: '876600h' });

// 밴 해제
await adminClient.auth.admin.updateUser(userId, { ban_duration: 'none' });
```

> `adminClient` 는 절대 `src/lib/supabase/client.ts` 에 넣지 않는다. 서버 파일(`+page.server.ts`, `+server.ts`) 안에서만 초기화해서 사용한다.

**파일 생성 규칙:**

| 상황 | 파일명 |
|------|--------|
| 테이블 CRUD | 테이블명 그대로 (`profiles.ts`, `clients.ts` 등) |
| Supabase Auth | `auth.ts` (고정) |
| RPC 함수 | `rpc.ts` 에 모으다가 커지면 주제별 분리 |

**`auth.ts` 기본 구조 (참고용):**
```ts
import { supabase } from '$lib/supabase/client';
import type { Session, User } from '@supabase/supabase-js';

export let session = $state<Session | null>(null);
export let user = $state<User | null>(null);
export let authReady = $state(false);

export function initAuth() { ... }
export async function login(username: string, password: string) {
  // username + '@mail.com' 으로 이메일 조합
  const email = `${username}@mail.com`;
  return supabase.auth.signInWithPassword({ email, password });
}
export async function logout() { ... }
```

**테이블 CRUD 파일 기본 구조 (예: `profiles.ts`):**
```ts
import { supabase } from '$lib/supabase/client';
import type { Profile, ProfileInsert, ProfileUpdate } from '$lib/supabase/types';

export async function getProfile(id: string) {
  return supabase.from('profiles').select('*').eq('id', id).single();
}

export async function updateProfile(id: string, data: ProfileUpdate) {
  return supabase.from('profiles').update(data).eq('id', id);
}
```

**`rpc.ts` 기본 구조:**
```ts
import { supabase } from '$lib/supabase/client';
import type { ProcessInventoryOutArgs } from '$lib/supabase/types';

export async function processInventoryOut(args: ProcessInventoryOutArgs) {
  return supabase.rpc('process_inventory_out', args);
}
```

**임포트 방식:**
```ts
import { login, logout, session } from '$lib/api/auth';
import { getProfile, updateProfile } from '$lib/api/profiles';
import { processInventoryOut } from '$lib/api/rpc';
```

---

## 기타 유용한 명령어

### 마이그레이션 목록 확인
```
wsl bash -c "cd /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin && SUPABASE_ACCESS_TOKEN='SB_ACCESS_TOKEN' supabase migration list --linked"
```

### 특정 테이블 데이터 확인
```
wsl bash -c "PGPASSWORD='DB_PASSWORD' psql -h aws-1-ap-northeast-2.pooler.supabase.com -U postgres.jmyxnyrhymqyqzyvknox -d postgres -c 'SELECT * FROM public.TABLE_NAME LIMIT 10;'"
```

### 스키마만 dump (pg_dump 방식)
```
wsl bash -c "PGPASSWORD='DB_PASSWORD' pg_dump -h aws-1-ap-northeast-2.pooler.supabase.com -U postgres.jmyxnyrhymqyqzyvknox -d postgres --schema=public --schema-only --no-owner --no-acl -f /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin/supabase/schema.sql"
```

### seed 데이터 dump (pg_dump 방식)
```
wsl bash -c "PGPASSWORD='DB_PASSWORD' pg_dump -h aws-1-ap-northeast-2.pooler.supabase.com -U postgres.jmyxnyrhymqyqzyvknox -d postgres --schema=public --data-only --inserts -f /mnt/c/Users/winco/OneDrive/Desktop/wash-desk-admin/supabase/seed.sql"
```

---

## 프로젝트 파일 구조

```
wash-desk-admin/
└── supabase/
    ├── config.toml                          # Supabase 프로젝트 설정
    ├── AGENT_GUIDE.md                       # 이 문서
    ├── schema.sql                           # pg_dump 방식 스키마 백업
    ├── seed.sql                             # pg_dump 방식 데이터 백업
    └── migrations/
        └── 20260513073449_remote_schema.sql # supabase db pull로 생성된 마이그레이션
```

---

## 변수 치환 요약

문서 내 명령어에서 아래 값을 실제 값으로 교체하세요:

| 변수 | 실제 값 |
|------|---------|
| `WSL_PASSWORD` | 사용자에게 요청 |
| `DB_PASSWORD` | 사용자에게 요청 |
| `SB_ACCESS_TOKEN` | 사용자에게 요청 (sbp_로 시작) |
| `NEW_PROJECT_REF` | 대상 Supabase 프로젝트 ref |
| `NEW_DB_PASSWORD` | 대상 프로젝트 DB 패스워드 |
| `MIGRATION_ID` | 에러 메시지에서 확인 |
| `TABLE_NAME` | 조회할 테이블명 |
