-- 1. 拡張機能のインストール／ロード
INSTALL spatial;
LOAD spatial;

-- 2. 入力テーブル作成
CREATE OR REPLACE TABLE h3 AS
SELECT
  *,
  geometry::GEOMETRY AS geom_h3
FROM read_parquet('h3_jpn_res9.parquet');

CREATE OR REPLACE TABLE nationalpark AS
SELECT
  *,
  geometry::GEOMETRY AS geom_np
FROM read_parquet('jpn_nps.parquet');

-- 3. CTE と CREATE TABLE の結合
CREATE OR REPLACE TABLE h3_with_np AS
WITH
  overlaps_cte AS (
    SELECT
      h.index,
      np.name,
      np.zone,
      ST_Area(
        ST_Intersection(h.geom_h3, np.geom_np)
      ) AS overlap_area
    FROM h3 AS h
    JOIN nationalpark AS np
      ON ST_Intersects(h.geom_h3, np.geom_np)
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
  r.name,
  r.zone
FROM h3 AS h
LEFT JOIN (
  SELECT index, name, zone
  FROM ranked
  WHERE rn = 1
) AS r
USING (index);

-- 4. 最終結果を書き出し
COPY (
  SELECT * FROM h3_with_np
) TO 'h3_jpn_res9_with_nationalpark.parquet' (FORMAT PARQUET);