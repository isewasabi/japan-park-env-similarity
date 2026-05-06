-- 拡張の読み込み（必要に応じて）
INSTALL spatial;
LOAD spatial;

-- 各ファイルをテーブルとして読み込み
CREATE TABLE joined_base AS SELECT * FROM 'joined_result.parquet';
CREATE TABLE joined_chishitsu AS SELECT * FROM 'joined_result_chishitsu.parquet';
CREATE TABLE joined_bichikei AS SELECT * FROM 'joined_result_bichikei.parquet';
CREATE TABLE joined_elevation AS SELECT * FROM 'joined_result_elevation.parquet';
CREATE TABLE joined_slope AS SELECT * FROM 'joined_result_slope.parquet';

-- indexをキーにJOINし、geometryは1つのものを使う（重複しない前提）
CREATE OR REPLACE TABLE merged_result AS
SELECT
    base.index,
    base.geometry,
    base.name,
    base.zone,
    ch.formatio_1,
    ch.group_en,
    ch.lithology1,
    ch.chishitsu_age,
    bi.JCODE,
    bi.bichikei_en,
    elev.elev_mean,
    elev.elev_max,
    sl.slopemean,
    sl.slopemax
FROM joined_base base
LEFT JOIN joined_chishitsu ch ON base.index = ch.index
LEFT JOIN joined_bichikei bi ON base.index = bi.index
LEFT JOIN joined_elevation elev ON base.index = elev.index
LEFT JOIN joined_slope sl ON base.index = sl.index;

-- GeoParquetとして保存
COPY merged_result TO 'merged_result.parquet' (FORMAT 'parquet');