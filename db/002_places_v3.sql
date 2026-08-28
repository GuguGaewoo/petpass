-- 002_places_v3.sql
-- 목적: Supabase에 `places` 테이블을 v3 스키마로 새로 만든다
--       (docs/schema.md, pipeline/normalize.py 기준).
--
-- ✅ 확인 완료 (Supabase MCP로 실제 프로젝트 조회, 2026-08-28)
--   프로젝트: Petpass (opawzxypkyvpqqimqnla, ap-northeast-2)
--   현재 public 스키마에는 아래 두 개만 존재한다.
--     - reports        (BASE TABLE) — 현장 제보. RLS 켜짐, INSERT 정책만 있음
--     - report_counts  (VIEW)       — reports 집계. anon 에 SELECT grant
--   즉 places 테이블은 아직 전혀 없다. reports/report_counts 는
--   app/lib/data/report_repository.dart 가 기대하는 컬럼(place_title,
--   verdict_feedback, body, device_hash)·집계 방식과 정확히 일치하므로
--   그대로 두고 이 마이그레이션에서 건드리지 않는다.
--
--   그래서 이 파일은 ALTER 가 아니라 CREATE TABLE IF NOT EXISTS 부터
--   시작한다 — 지금 상태(테이블 없음)에서 그대로 실행하면 된다.
--
-- 적용: Supabase 대시보드 → SQL Editor 에 이 파일 내용만 붙여넣고 실행

-- ────────────────────────────────────────────────
-- 1) places 테이블 — 없으면 새로 만든다 (v1 기본 골격)
-- ────────────────────────────────────────────────
create table if not exists public.places (
  content_id        text primary key,
  schema_version    int  not null default 3,

  -- 장소 기본 정보
  title             text not null,
  address           text,
  content_type      text,
  content_type_id   text,
  area_code         text,
  sigungu_code      text,
  lat               double precision,
  lng               double precision,
  tel               text,
  image             text,

  -- 구조화된 제약 조건 (v1)
  has_detail        boolean not null default false,
  acmpy_type        text,        -- all_area / partial_area / unknown_value / null
  guide_dog_only    boolean not null default false,
  max_weight_kg     real,
  required_items    text[] default '{}',
  provided_items    text[] default '{}',
  rental_items      text[] default '{}',
  purchasable_items text[] default '{}',
  facilities        text[] default '{}',
  extra_fee         boolean not null default false,
  outdoor_only      boolean not null default false,
  risk_notes        text,
  etc_info          text,

  -- 판정 근거 및 추적
  source_text       jsonb  not null default '{}',
  last_modified     timestamptz,
  collected_at      timestamptz not null default now(),
  confidence        real not null default 0
);

-- ────────────────────────────────────────────────
-- 2) v3 신규 컬럼 추가
--    (테이블을 방금 새로 만들었어도 add column if not exists 는
--     아무 문제 없이 통과한다 — 멱등성을 위해 그대로 둔다)
-- ────────────────────────────────────────────────
alter table public.places
  -- 국문 관광정보 보강 (normalize.py: overview, homepage)
  add column if not exists overview text not null default '',
  add column if not exists homepage text not null default '',

  -- 판정 1차/2차 보조 플래그
  add column if not exists explicitly_denied boolean not null default false,
  add column if not exists needs_inquiry boolean not null default false,
  add column if not exists all_breed_ok boolean not null default false,

  -- 체중 조건 근거 추적
  add column if not exists weight_source text,
  add column if not exists weight_in_etc_only boolean not null default false,

  -- 견종 크기 제한
  add column if not exists size_limit text,
  add column if not exists fierce_excluded boolean not null default false,

  -- 입마개: 체중 조건부 / 견종(맹견) 조건부는 서로 다른 조건이다.
  add column if not exists muzzle_over_kg real,
  add column if not exists muzzle_if_fierce boolean not null default false,

  add column if not exists max_count integer,

  add column if not exists free_use boolean not null default false,
  add column if not exists see_etc_info boolean not null default false,
  add column if not exists zone_detail_in_text boolean not null default false,

  -- 목록에서 사라진 장소를 삭제 대신 비활성화하기 위한 플래그
  add column if not exists is_active boolean not null default true,

  -- 상세화면 진입 시 백엔드가 실제 KTO API로 마지막으로 확인한 시각
  add column if not exists live_checked_at timestamptz;

-- ────────────────────────────────────────────────
-- 3) 조회 성능 인덱스
-- ────────────────────────────────────────────────
create index if not exists places_area_idx
  on public.places (area_code, sigungu_code);

create index if not exists places_active_idx
  on public.places (is_active);

create index if not exists places_active_area_idx
  on public.places (is_active, area_code);

-- ────────────────────────────────────────────────
-- 4) RLS — places 테이블을 방금 새로 만들었다면 반드시 필요하다.
--    켜지 않으면 anon 키만으로 누구나 쓰기·삭제까지 할 수 있다.
-- ────────────────────────────────────────────────
alter table public.places enable row level security;

drop policy if exists places_read on public.places;
create policy places_read on public.places
  for select using (true);

-- update/insert/delete 정책을 만들지 않는다 = service_role(배치·백엔드)만 쓸 수 있다.

grant usage on schema public to anon, authenticated;
grant select on public.places to anon, authenticated;

-- ────────────────────────────────────────────────
-- 5) KTO Open API 호출 로그
--    심사/운영 모니터링 용도. 사용자에게 공개하지 않는다.
-- ────────────────────────────────────────────────
create table if not exists public.kto_api_log (
  id             bigserial primary key,
  endpoint       text not null,          -- 예: areaBasedList2, detailPetTour2
  content_id     text,
  caller         text not null check (caller in ('batch', 'live')),
  success        boolean not null,
  error_message  text,
  called_at      timestamptz not null default now()
);

create index if not exists kto_api_log_called_at_idx
  on public.kto_api_log (called_at desc);

alter table public.kto_api_log enable row level security;

-- anon/authenticated 용 정책을 만들지 않는다.
-- 즉 service_role(배치·백엔드) 키를 가진 서버 프로세스만 접근할 수 있다.
-- grant 문도 anon/authenticated 에는 주지 않는다.

-- ────────────────────────────────────────────────
-- 6) 확인
-- ────────────────────────────────────────────────
-- select column_name, data_type from information_schema.columns
-- where table_schema = 'public' and table_name = 'places'
-- order by ordinal_position;
--
-- select tablename, rowsecurity from pg_tables
-- where schemaname = 'public' and tablename in ('places', 'kto_api_log');
