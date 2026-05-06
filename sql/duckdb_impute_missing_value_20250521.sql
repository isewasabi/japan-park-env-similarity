-- 0. H3 拡張のインストール＆ロード
INSTALL h3 FROM community;
LOAD h3;

-- 1. 元データ読み込み＋16進文字列→数値インデックス変換
CREATE OR REPLACE TABLE base2 AS
SELECT
  *,
  h3_string_to_h3("h3_9") AS h3int
FROM read_parquet('h3_jpn_res9_source.parquet');

-- 2. 各セルについて、半径10セルの隣接全セルリストを展開
CREATE OR REPLACE TABLE neighbor_list AS
SELECT
  b.h3int           AS origin_cell,
  t.neighbor_cell   AS neighbor_cell
FROM base2 AS b
CROSS JOIN UNNEST( h3_grid_disk(b.h3int, 10) ) AS t(neighbor_cell);

-- 3. 隣接セルごとの平均値＆非欠損数を集計
CREATE OR REPLACE TABLE neighbor_stats AS
SELECT
  h3int                                  AS neighbor_cell,
  AVG(elev_mean)       AS avg_elev,
  SUM(CASE WHEN elev_mean IS NOT NULL THEN 1 ELSE 0 END) AS cnt_elev,
  AVG(slopemean)       AS avg_slope,
  SUM(CASE WHEN slopemean IS NOT NULL THEN 1 ELSE 0 END) AS cnt_slope,
  AVG(chishitsu_age)   AS avg_chishitsu_age,
  SUM(CASE WHEN chishitsu_age IS NOT NULL THEN 1 ELSE 0 END) AS cnt_chishitsu_age,
  AVG(prec_year)       AS avg_prec_year,
  SUM(CASE WHEN prec_year IS NOT NULL THEN 1 ELSE 0 END) AS cnt_prec_year,
  AVG(ave_temp_y)      AS avg_ave_temp_y,
  SUM(CASE WHEN ave_temp_y IS NOT NULL THEN 1 ELSE 0 END) AS cnt_ave_temp_y,
  AVG(max_snow_y)      AS avg_max_snow_y,
  SUM(CASE WHEN max_snow_y IS NOT NULL THEN 1 ELSE 0 END) AS cnt_max_snow_y
FROM base2
GROUP BY h3int;

-- 4. origin_cell×neighbor_cell を結合し、距離 dist を計算してひとまとめに
CREATE OR REPLACE TABLE neighbor_detail AS
SELECT
  nl.origin_cell,
  ns.avg_elev,
  ns.cnt_elev,
  ns.avg_slope,
  ns.cnt_slope,
  ns.avg_chishitsu_age,
  ns.cnt_chishitsu_age,
  ns.avg_prec_year,
  ns.cnt_prec_year,
  ns.avg_ave_temp_y,
  ns.cnt_ave_temp_y,
  ns.avg_max_snow_y,
  ns.cnt_max_snow_y,
  h3_grid_distance(nl.origin_cell, nl.neighbor_cell) AS dist
FROM neighbor_list AS nl
LEFT JOIN neighbor_stats AS ns
  ON nl.neighbor_cell = ns.neighbor_cell;

-- 5. 各連続値カラムについて、「最小 dist かつ cnt_>0」の平均値を選択する CTE／テーブル
CREATE OR REPLACE TABLE chosen_elev AS
SELECT origin_cell, avg_elev
FROM (
  SELECT
    nd.origin_cell,
    nd.avg_elev,
    nd.dist,
    ROW_NUMBER() OVER (
      PARTITION BY nd.origin_cell
      ORDER BY nd.dist
    ) AS rn
  FROM neighbor_detail AS nd
  WHERE nd.cnt_elev > 0
) sub
WHERE rn = 1;

CREATE OR REPLACE TABLE chosen_slope AS
SELECT origin_cell, avg_slope
FROM (
  SELECT
    nd.origin_cell,
    nd.avg_slope,
    nd.dist,
    ROW_NUMBER() OVER (
      PARTITION BY nd.origin_cell
      ORDER BY nd.dist
    ) AS rn
  FROM neighbor_detail AS nd
  WHERE nd.cnt_slope > 0
) sub
WHERE rn = 1;

CREATE OR REPLACE TABLE chosen_chishitsu_age AS
SELECT origin_cell, avg_chishitsu_age
FROM (
  SELECT
    nd.origin_cell,
    nd.avg_chishitsu_age,
    nd.dist,
    ROW_NUMBER() OVER (
      PARTITION BY nd.origin_cell
      ORDER BY nd.dist
    ) AS rn
  FROM neighbor_detail AS nd
  WHERE nd.cnt_chishitsu_age > 0
) sub
WHERE rn = 1;

CREATE OR REPLACE TABLE chosen_prec_year AS
SELECT origin_cell, avg_prec_year
FROM (
  SELECT
    nd.origin_cell,
    nd.avg_prec_year,
    nd.dist,
    ROW_NUMBER() OVER (
      PARTITION BY nd.origin_cell
      ORDER BY nd.dist
    ) AS rn
  FROM neighbor_detail AS nd
  WHERE nd.cnt_prec_year > 0
) sub
WHERE rn = 1;

CREATE OR REPLACE TABLE chosen_ave_temp_y AS
SELECT origin_cell, avg_ave_temp_y
FROM (
  SELECT
    nd.origin_cell,
    nd.avg_ave_temp_y,
    nd.dist,
    ROW_NUMBER() OVER (
      PARTITION BY nd.origin_cell
      ORDER BY nd.dist
    ) AS rn
  FROM neighbor_detail AS nd
  WHERE nd.cnt_ave_temp_y > 0
) sub
WHERE rn = 1;

CREATE OR REPLACE TABLE chosen_max_snow_y AS
SELECT origin_cell, avg_max_snow_y
FROM (
  SELECT
    nd.origin_cell,
    nd.avg_max_snow_y,
    nd.dist,
    ROW_NUMBER() OVER (
      PARTITION BY nd.origin_cell
      ORDER BY nd.dist
    ) AS rn
  FROM neighbor_detail AS nd
  WHERE nd.cnt_max_snow_y > 0
) sub
WHERE rn = 1;

-- 6. 全体平均を計算（最終フォールバック用）
CREATE OR REPLACE TABLE global_avg AS
SELECT
  AVG(elev_mean)     AS global_elev,
  AVG(slopemean)     AS global_slope,
  AVG(chishitsu_age) AS global_chishitsu_age,
  AVG(prec_year)     AS global_prec_year,
  AVG(ave_temp_y)    AS global_ave_temp_y,
  AVG(max_snow_y)    AS global_max_snow_y
FROM base2;

-- 7. 最終 imputed テーブルを作成
CREATE OR REPLACE TABLE imputed AS
SELECT
  -- まずはすべての元カラムを保持しつつ、
  b.* EXCLUDE (elev_mean, slopemean, chishitsu_age, prec_year, ave_temp_y, max_snow_y),
  -- NULL→隣接平均→全体平均 の順で埋める
  COALESCE(b.elev_mean,      ce.avg_elev,           g.global_elev)           AS elev_mean,
  COALESCE(b.slopemean,      cs.avg_slope,          g.global_slope)          AS slopemean,
  COALESCE(b.chishitsu_age,  cca.avg_chishitsu_age, g.global_chishitsu_age)  AS chishitsu_age,
  COALESCE(b.prec_year,      cp.avg_prec_year,      g.global_prec_year)      AS prec_year,
  COALESCE(b.ave_temp_y,     cav.avg_ave_temp_y,    g.global_ave_temp_y)     AS ave_temp_y,
  COALESCE(b.max_snow_y,     cms.avg_max_snow_y,    g.global_max_snow_y)     AS max_snow_y
FROM base2 AS b
LEFT JOIN chosen_elev          AS ce  ON b.h3int = ce.origin_cell
LEFT JOIN chosen_slope         AS cs  ON b.h3int = cs.origin_cell
LEFT JOIN chosen_chishitsu_age AS cca ON b.h3int = cca.origin_cell
LEFT JOIN chosen_prec_year     AS cp  ON b.h3int = cp.origin_cell
LEFT JOIN chosen_ave_temp_y    AS cav ON b.h3int = cav.origin_cell
LEFT JOIN chosen_max_snow_y    AS cms ON b.h3int = cms.origin_cell
CROSS JOIN global_avg AS g;

-- 8. 必要に応じて Parquet に書き出し
COPY imputed
  TO 'h3_jpn_res9_source_imputed.parquet'
  (FORMAT PARQUET);