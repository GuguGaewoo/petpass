-- 004_banned_zones.sql
-- 동반할 수 없는 구역의 '유형' 목록.
--
-- 원문에는 어느 구역이 막혔는지 적혀 있으나 지금까지 구조화되지 않아
-- "이용 구역 안내" 에 원문만 그대로 노출됐다. 실측 45건에서 유형을
-- 뽑아낼 수 있어 컬럼으로 저장한다.
--
-- 값 예: {실내}, {전시,식음료}
-- 유형: 실내 / 식음료 / 전시 / 숙박 / 체육 / 자연 / 탈것
--
-- 구역명 자체(청운답원 등)는 그 장소에만 있는 고유명사가 많아 담지 않는다.
-- 그런 경우 이 배열은 비고, 기존처럼 zone_detail_in_text 가 원문 확인을
-- 유도한다.
--
-- 적용: Supabase 대시보드 → SQL Editor 에서 실행

alter table public.places
  add column if not exists banned_zones text[] not null default '{}';

-- "실내는 못 들어가는 곳" 같은 조회를 위한 인덱스.
-- text[] 는 GIN 이라야 포함 검색(@>, &&)이 인덱스를 탄다.
create index if not exists places_banned_zones_idx
  on public.places using gin (banned_zones);

-- ────────────────────────────────────────────────
-- 확인
-- ────────────────────────────────────────────────
-- select banned_zones, count(*)
-- from public.places
-- where banned_zones <> '{}'
-- group by banned_zones
-- order by count(*) desc;
