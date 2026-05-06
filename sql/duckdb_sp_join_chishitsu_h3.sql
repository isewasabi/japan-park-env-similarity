-- 1. 拡張機能のインストール／ロード
INSTALL spatial;
LOAD spatial;

-- 2. 入力テーブル作成
CREATE OR REPLACE TABLE h3 AS
SELECT
  *,
  geometry::GEOMETRY AS geom_h3
FROM read_parquet('h3_jpn_res9.parquet');

CREATE OR REPLACE TABLE chishitsu AS
SELECT
  *,
  geometry::GEOMETRY AS geom_ch
FROM read_parquet('fixed_seamless_chishitsu_4326.parquet');

-- 3. CTE と CREATE TABLE の結合
CREATE OR REPLACE TABLE h3_with_ch AS
WITH
  overlaps_cte AS (
    SELECT
      h.index,
      c.lithology1,
      c.group_en,
      c.chishitsu_age,
      ST_Area(
        ST_Intersection(h.geom_h3, c.geom_ch)
      ) AS overlap_area
    FROM h3 AS h
    JOIN chishitsu AS c
      ON ST_Intersects(h.geom_h3, c.geom_ch)
  ),
  ranked AS (
    SELECT
      *,
      ROW_NUMBER() OVER (
        PARTITION BY index
        ORDER BY overlap_area DESC
      ) AS rn
    FROM overlaps_cte
  )
SELECT
  h.*,
  r.lithology1,
  r.group_en,
  r.chishitsu_age
FROM h3 AS h
LEFT JOIN (
  SELECT index, lithology1, group_en, chishitsu_age
  FROM ranked
  WHERE rn = 1
) AS r
USING (index);

-- 4. 最終結果を書き出し
COPY (
  SELECT * FROM h3_with_ch
) TO 'h3_jpn_res9_with_chishitsu.parquet' (FORMAT PARQUET);