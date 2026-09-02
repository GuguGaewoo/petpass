-- 003_grant_service_role.sql
-- service_role(배치·백엔드)에 places / kto_api_log 접근 권한을 부여한다.
--
-- 왜 필요한가
--   002 에서 anon/authenticated 에는 SELECT 를 부여했으나 service_role 은
--   빠뜨렸다. 이 프로젝트는 기본 권한(default privileges)이 service_role 에
--   자동으로 부여되지 않는 설정이어서, 아래가 모두 실패했다.
--
--     seed_supabase.py  → 42501 permission denied for table places
--     sync_service.py   → 동일
--     backend/main.py   → 동일
--
--   service_role 은 RLS 정책을 우회하지만, 테이블 GRANT 는 그것과 별개로
--   반드시 있어야 한다. RLS 를 켰다고 권한까지 생기는 것은 아니다.
--
-- 적용: Supabase 대시보드 → SQL Editor 에서 실행
--       (운영 DB 에는 2026-08-29 적용 완료)

-- ────────────────────────────────────────────────
-- places: 배치가 읽고 쓴다
-- ────────────────────────────────────────────────
grant select, insert, update, delete on public.places to service_role;

-- ────────────────────────────────────────────────
-- kto_api_log: 배치·백엔드가 Open API 호출 이력을 남긴다
--   bigserial 기본키를 쓰므로 시퀀스 권한도 함께 필요하다.
-- ────────────────────────────────────────────────
grant select, insert on public.kto_api_log to service_role;
grant usage, select on sequence public.kto_api_log_id_seq to service_role;

-- anon/authenticated 에는 kto_api_log 권한을 주지 않는다.
-- 호출 이력은 사용자에게 공개하지 않는 서버 전용 데이터다.

-- ────────────────────────────────────────────────
-- 확인
-- ────────────────────────────────────────────────
-- select table_name, grantee,
--        string_agg(privilege_type, ', ' order by privilege_type) as privs
-- from information_schema.role_table_grants
-- where table_schema = 'public'
--   and table_name in ('places', 'kto_api_log')
--   and grantee in ('service_role', 'anon', 'authenticated')
-- group by table_name, grantee
-- order by table_name, grantee;
