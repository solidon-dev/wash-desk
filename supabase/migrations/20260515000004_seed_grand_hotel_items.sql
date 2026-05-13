-- ============================================================
-- 샘플 데이터: 강남 그랜드호텔 (client_id = 576b5258-bf14-44db-bcff-64d4c42e081b)
-- factory_id = 3008d6ce-f262-44c2-a6e5-fe5f50bbcf70
-- ============================================================

DO $$
DECLARE
  v_factory_id  uuid := '3008d6ce-f262-44c2-a6e5-fe5f50bbcf70';
  v_client_id   uuid := '576b5258-bf14-44db-bcff-64d4c42e081b';

  -- 카테고리 ID
  cat_bed       uuid;
  cat_bath      uuid;
  cat_table     uuid;
  cat_uniform   uuid;
  cat_curtain   uuid;
  cat_kitchen   uuid;
  cat_spa       uuid;
  cat_misc      uuid;

  -- 품목 ID (bed)
  i_sheet_s     uuid;
  i_sheet_d     uuid;
  i_sheet_k     uuid;
  i_pillow      uuid;
  i_pillow_cvr  uuid;
  i_duvet       uuid;
  i_duvet_cvr_s uuid;
  i_duvet_cvr_d uuid;
  i_duvet_cvr_k uuid;
  i_pad         uuid;
  i_mattress    uuid;

  -- 품목 ID (bath)
  i_towel_face  uuid;
  i_towel_bath  uuid;
  i_towel_hand  uuid;
  i_towel_foot  uuid;
  i_robe        uuid;
  i_bath_mat    uuid;
  i_slippers    uuid;

  -- 품목 ID (table)
  i_cloth_round uuid;
  i_cloth_rect  uuid;
  i_napkin      uuid;
  i_runner      uuid;
  i_overlay     uuid;
  i_skirt       uuid;
  i_chair_cover uuid;

  -- 품목 ID (uniform)
  i_shirt       uuid;
  i_apron       uuid;
  i_trousers    uuid;
  i_jacket      uuid;
  i_vest        uuid;
  i_cap         uuid;
  i_chef_coat   uuid;

  -- 품목 ID (curtain)
  i_curtain_s   uuid;
  i_curtain_l   uuid;
  i_blackout    uuid;
  i_voile       uuid;

  -- 품목 ID (kitchen)
  i_mop         uuid;
  i_cleaning    uuid;
  i_dish_cloth  uuid;
  i_floor_cloth uuid;

  -- 품목 ID (spa)
  i_spa_towel   uuid;
  i_spa_robe    uuid;
  i_sauna_towel uuid;
  i_wrap        uuid;

  -- 품목 ID (misc)
  i_flag        uuid;
  i_bag         uuid;
  i_cover       uuid;

BEGIN

-- ── 카테고리 생성 ──────────────────────────────────────────
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '침구류',    0) RETURNING id INTO cat_bed;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '욕실용품',  1) RETURNING id INTO cat_bath;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '테이블웨어', 2) RETURNING id INTO cat_table;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '유니폼',    3) RETURNING id INTO cat_uniform;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '커튼·암막', 4) RETURNING id INTO cat_curtain;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '주방용품',  5) RETURNING id INTO cat_kitchen;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '스파·사우나', 6) RETURNING id INTO cat_spa;
INSERT INTO public.categories (factory_id, name, sort_order) VALUES
  (v_factory_id, '기타',      7) RETURNING id INTO cat_misc;

-- ── 침구류 품목 ───────────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '시트 (싱글)', 'Single Sheet', 0) RETURNING id INTO i_sheet_s;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '시트 (더블)', 'Double Sheet', 1) RETURNING id INTO i_sheet_d;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '시트 (킹)', 'King Sheet', 2) RETURNING id INTO i_sheet_k;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '베개', 'Pillow', 3) RETURNING id INTO i_pillow;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '베개 커버', 'Pillow Cover', 4) RETURNING id INTO i_pillow_cvr;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '이불', 'Duvet', 5) RETURNING id INTO i_duvet;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '이불 커버 (싱글)', 'Duvet Cover S', 6) RETURNING id INTO i_duvet_cvr_s;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '이불 커버 (더블)', 'Duvet Cover D', 7) RETURNING id INTO i_duvet_cvr_d;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '이불 커버 (킹)', 'Duvet Cover K', 8) RETURNING id INTO i_duvet_cvr_k;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '침대 패드', 'Bed Pad', 9) RETURNING id INTO i_pad;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bed, v_factory_id, '매트리스 커버', 'Mattress Cover', 10) RETURNING id INTO i_mattress;

-- ── 욕실용품 품목 ──────────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '페이스 타월', 'Face Towel', 0) RETURNING id INTO i_towel_face;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '배스 타월', 'Bath Towel', 1) RETURNING id INTO i_towel_bath;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '핸드 타월', 'Hand Towel', 2) RETURNING id INTO i_towel_hand;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '풋 타월', 'Foot Towel', 3) RETURNING id INTO i_towel_foot;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '목욕 가운 (로브)', 'Bath Robe', 4) RETURNING id INTO i_robe;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '욕실 매트', 'Bath Mat', 5) RETURNING id INTO i_bath_mat;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_bath, v_factory_id, '슬리퍼', 'Slippers', 6) RETURNING id INTO i_slippers;

-- ── 테이블웨어 품목 ───────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '원형 테이블보', 'Round Tablecloth', 0) RETURNING id INTO i_cloth_round;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '사각 테이블보', 'Rect Tablecloth', 1) RETURNING id INTO i_cloth_rect;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '냅킨', 'Napkin', 2) RETURNING id INTO i_napkin;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '테이블 러너', 'Table Runner', 3) RETURNING id INTO i_runner;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '오버레이', 'Overlay', 4) RETURNING id INTO i_overlay;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '테이블 스커트', 'Table Skirt', 5) RETURNING id INTO i_skirt;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_table, v_factory_id, '의자 커버', 'Chair Cover', 6) RETURNING id INTO i_chair_cover;

-- ── 유니폼 품목 ───────────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '와이셔츠', 'Dress Shirt', 0) RETURNING id INTO i_shirt;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '앞치마', 'Apron', 1) RETURNING id INTO i_apron;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '바지', 'Trousers', 2) RETURNING id INTO i_trousers;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '재킷', 'Jacket', 3) RETURNING id INTO i_jacket;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '조끼', 'Vest', 4) RETURNING id INTO i_vest;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '모자', 'Cap', 5) RETURNING id INTO i_cap;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_uniform, v_factory_id, '조리복', 'Chef Coat', 6) RETURNING id INTO i_chef_coat;

-- ── 커튼·암막 품목 ───────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_curtain, v_factory_id, '커튼 (소)', 'Curtain S', 0) RETURNING id INTO i_curtain_s;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_curtain, v_factory_id, '커튼 (대)', 'Curtain L', 1) RETURNING id INTO i_curtain_l;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_curtain, v_factory_id, '암막 커튼', 'Blackout Curtain', 2) RETURNING id INTO i_blackout;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_curtain, v_factory_id, '보일 커튼', 'Voile Curtain', 3) RETURNING id INTO i_voile;

-- ── 주방용품 품목 ─────────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_kitchen, v_factory_id, '대걸레 (몹)', 'Mop', 0) RETURNING id INTO i_mop;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_kitchen, v_factory_id, '청소포', 'Cleaning Cloth', 1) RETURNING id INTO i_cleaning;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_kitchen, v_factory_id, '행주', 'Dish Cloth', 2) RETURNING id INTO i_dish_cloth;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_kitchen, v_factory_id, '바닥 걸레', 'Floor Cloth', 3) RETURNING id INTO i_floor_cloth;

-- ── 스파·사우나 품목 ──────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_spa, v_factory_id, '스파 타월', 'Spa Towel', 0) RETURNING id INTO i_spa_towel;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_spa, v_factory_id, '스파 가운', 'Spa Robe', 1) RETURNING id INTO i_spa_robe;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_spa, v_factory_id, '사우나 타월', 'Sauna Towel', 2) RETURNING id INTO i_sauna_towel;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_spa, v_factory_id, '랩 타월 (바디 랩)', 'Body Wrap', 3) RETURNING id INTO i_wrap;

-- ── 기타 품목 ─────────────────────────────────────────────
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_misc, v_factory_id, '행사용 깃발', 'Event Flag', 0) RETURNING id INTO i_flag;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_misc, v_factory_id, '세탁물 수거백', 'Laundry Bag', 1) RETURNING id INTO i_bag;
INSERT INTO public.items (category_id, factory_id, name_ko, name_en, sort_order) VALUES
  (cat_misc, v_factory_id, '가구 보호 커버', 'Furniture Cover', 2) RETURNING id INTO i_cover;

-- ── 단가 등록 (강남 그랜드호텔, 2026-01-01 기준) ──────────
INSERT INTO public.item_prices (item_id, client_id, unit_price, effective_from) VALUES
  -- 침구류
  (i_sheet_s,    v_client_id,  1200, '2026-01-01'),
  (i_sheet_d,    v_client_id,  1500, '2026-01-01'),
  (i_sheet_k,    v_client_id,  1800, '2026-01-01'),
  (i_pillow,     v_client_id,   800, '2026-01-01'),
  (i_pillow_cvr, v_client_id,   600, '2026-01-01'),
  (i_duvet,      v_client_id,  3500, '2026-01-01'),
  (i_duvet_cvr_s,v_client_id,  1500, '2026-01-01'),
  (i_duvet_cvr_d,v_client_id,  1800, '2026-01-01'),
  (i_duvet_cvr_k,v_client_id,  2200, '2026-01-01'),
  (i_pad,        v_client_id,  2000, '2026-01-01'),
  (i_mattress,   v_client_id,  2500, '2026-01-01'),
  -- 욕실용품
  (i_towel_face, v_client_id,   500, '2026-01-01'),
  (i_towel_bath, v_client_id,   900, '2026-01-01'),
  (i_towel_hand, v_client_id,   600, '2026-01-01'),
  (i_towel_foot, v_client_id,   500, '2026-01-01'),
  (i_robe,       v_client_id,  3000, '2026-01-01'),
  (i_bath_mat,   v_client_id,  1200, '2026-01-01'),
  (i_slippers,   v_client_id,   300, '2026-01-01'),
  -- 테이블웨어
  (i_cloth_round,v_client_id,  2500, '2026-01-01'),
  (i_cloth_rect, v_client_id,  2000, '2026-01-01'),
  (i_napkin,     v_client_id,   400, '2026-01-01'),
  (i_runner,     v_client_id,   800, '2026-01-01'),
  (i_overlay,    v_client_id,  1200, '2026-01-01'),
  (i_skirt,      v_client_id,  3000, '2026-01-01'),
  (i_chair_cover,v_client_id,  1500, '2026-01-01'),
  -- 유니폼
  (i_shirt,      v_client_id,  2000, '2026-01-01'),
  (i_apron,      v_client_id,  1000, '2026-01-01'),
  (i_trousers,   v_client_id,  2500, '2026-01-01'),
  (i_jacket,     v_client_id,  4000, '2026-01-01'),
  (i_vest,       v_client_id,  2000, '2026-01-01'),
  (i_cap,        v_client_id,   800, '2026-01-01'),
  (i_chef_coat,  v_client_id,  2500, '2026-01-01'),
  -- 커튼·암막
  (i_curtain_s,  v_client_id,  5000, '2026-01-01'),
  (i_curtain_l,  v_client_id,  8000, '2026-01-01'),
  (i_blackout,   v_client_id, 10000, '2026-01-01'),
  (i_voile,      v_client_id,  4000, '2026-01-01'),
  -- 주방용품
  (i_mop,        v_client_id,   600, '2026-01-01'),
  (i_cleaning,   v_client_id,   300, '2026-01-01'),
  (i_dish_cloth, v_client_id,   300, '2026-01-01'),
  (i_floor_cloth,v_client_id,   500, '2026-01-01'),
  -- 스파·사우나
  (i_spa_towel,  v_client_id,  1000, '2026-01-01'),
  (i_spa_robe,   v_client_id,  4000, '2026-01-01'),
  (i_sauna_towel,v_client_id,   700, '2026-01-01'),
  (i_wrap,       v_client_id,  1500, '2026-01-01'),
  -- 기타
  (i_flag,       v_client_id,  5000, '2026-01-01'),
  (i_bag,        v_client_id,   200, '2026-01-01'),
  (i_cover,      v_client_id,  2000, '2026-01-01');

END $$;
