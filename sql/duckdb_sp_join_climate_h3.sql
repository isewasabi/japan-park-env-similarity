-- 1. 拡張機能のインストール／ロード
INSTALL spatial;
LOAD spatial;

-- 2. 入力テーブル作成
CREATE OR REPLACE TABLE h3 AS
SELECT
  *,
  geometry::GEOMETRY AS geom_h3
FROM read_parquet('h3_jpn_res9.parquet');

CREATE OR REPLACE TABLE climate AS
SELECT
  *,
  geometry::GEOMETRY AS geom_ch
FROM read_parquet('fixed_climate_mesh3_4326.parquet');

-- 3. CTE と CREATE TABLE の結合
CREATE OR REPLACE TABLE h3_with_ch AS
WITH
  overlaps_cte AS (
    SELECT
      h.index,
      c.prec_year,
      c.ave_temp_y,
      c.max_snow_y,
      ST_Area(
        ST_Intersection(h.geom_h3, c.geom_ch)
      ) AS overlap_area
    FROM h3 AS h
    JOIN climate AS c
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
  r.prec_year,
  r.ave_temp_y,
  r.max_snow_y
FROM h3 AS h
LEFT JOIN (
  SELECT index, prec_year, ave_temp_y, max_snow_y
  FROM ranked
  WHERE rn = 1
) AS r
USING (index);

-- 4. 最終結果を書き出し
COPY (
  SELECT * FROM h3_with_ch
) TO 'h3_jpn_res9_with_climate.parquet' (FORMAT PARQUET);