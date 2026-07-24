-- 펫패스 Supabase 스키마
-- 적용: Supabase 대시보드 → SQL Editor 에 붙여넣고 실행
--
-- ⚠ RLS 를 켜지 않으면 anon 키만으로 누구나 테이블을 읽고 삭제할 수 있습니다.
--   anon 키는 앱에 노출되는 것이 정상인 키이므로, 보호는 전적으로 RLS 가 합니다.

-- ────────────────────────────────────────────────
-- places : 정규화된 장소 + 제약 조건
-- ────────────────────────────────────────────────
create table if not exists places (
  content_id        text primary key,
  schema_version    int  not null default 1,

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

  -- 구조화된 제약 조건
  has_detail        boolean not null default false,
  acmpy_type        text,        -- all_area / partial_area / not_allowed / unknown_value / null
  guide_dog_only    boolean not null default false,
  max_weight_kg     real,
  size_restriction  text,        -- small / medium / large / null
  breed_restricted  boolean not null default false,
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

create index if not exists places_area_idx   on places (area_code, sigungu_code);
create index if not exists places_type_idx   on places (content_type_id);
create index if not exists places_weight_idx on places (max_weight_kg);
create index if not exists places_geo_idx    on places (lat, lng);

-- ────────────────────────────────────────────────
-- reports : 사용자 현장 검증 제보 (보완 장치)
-- ────────────────────────────────────────────────
create table if not exists reports (
  id           bigserial primary key,
  content_id   text not null references places(content_id) on delete cascade,
  device_hash  text not null,           -- 익명 기기 식별자. 개인정보 아님
  agrees       boolean not null,        -- 공공데이터 조건과 일치했는가
  note         text check (char_length(note) <= 300),
  created_at   timestamptz not null default now()
);

create index if not exists reports_content_idx on reports (content_id);

-- 같은 기기가 같은 장소에 하루 한 번만
create unique index if not exists reports_once_per_day
  on reports (content_id, device_hash, (created_at::date));

-- ────────────────────────────────────────────────
-- RLS — 반드시 켤 것
-- ────────────────────────────────────────────────
alter table places  enable row level security;
alter table reports enable row level security;

-- places : 누구나 읽기만. 쓰기는 service_role(배치)만 가능
drop policy if exists places_read on places;
create policy places_read on places
  for select using (true);

-- reports : 누구나 삽입 가능, 읽기는 집계 목적으로 허용, 수정·삭제 불가
drop policy if exists reports_insert on reports;
create policy reports_insert on reports
  for insert with check (
    char_length(coalesce(note, '')) <= 300
    and char_length(device_hash) between 8 and 128
  );

drop policy if exists reports_read on reports;
create policy reports_read on reports
  for select using (true);

-- update / delete 정책을 만들지 않음 = 아무도 못 함 (service_role 제외)

-- ────────────────────────────────────────────────
-- 제보 집계 뷰 (앱은 이걸 조회)
-- ────────────────────────────────────────────────
create or replace view place_report_summary as
select
  content_id,
  count(*)                              as report_count,
  count(*) filter (where agrees)        as agree_count,
  count(*) filter (where not agrees)    as disagree_count,
  max(created_at)                       as last_reported_at
from reports
group by content_id;
