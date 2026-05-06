-- 1. 拡張機能のインストール／ロード
INSTALL spatial;
LOAD spatial;

-- 2. 入力テーブル作成
CREATE OR REPLACE TABLE h3 AS
SELECT
  *,
  geometry::GEOMETRY AS geom_h3
FROM read_parquet('h3_jpn_res9.parquet');

CREATE OR REPLACE TABLE bichikei AS
SELECT
  *,
  geometry::GEOMETRY AS geom_ch
FROM read_parquet('fixed_chikei_jiban250_4326.parquet');

-- 3. CTE と CREATE TABLE の結合
CREATE OR REPLACE TABLE h3_with_ch AS
WITH
  overlaps_cte AS (
    SELECT
      h.index,
      c.bichikei_en,
      ST_Area(
        ST_Intersection(h.geom_h3, c.geom_ch)
      ) AS overlap_area
    FROM h3 AS h
    JOIN bichikei AS c
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
  r.bichikei_en
FROM h3 AS h
LEFT JOIN (
  SELECT index, bichikei_en
  FROM ranked
  WHERE rn = 1
) AS r
USING (index);

-- 4. 最終結果を書き出し
COPY (
  SELECT * FROM h3_with_ch
) TO 'h3_jpn_res9_with_bichikei.parquet' (FORMAT PARQUET);