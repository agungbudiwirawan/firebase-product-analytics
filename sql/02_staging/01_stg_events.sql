-- =====================================================================
-- STAGING: stg_events
-- Mengubah data Firebase mentah (nested) menjadi 1 tabel datar yang bersih.
-- 1 baris = 1 event.
--
-- Aturan cleaning (dari docs/data_quality_report.md):
--   #1 Hapus duplikat persis
--   #2 level & score: gabungkan int + double jadi satu angka
--   #3 item_id diubah ke huruf kecil
--   #4 Kolom mode: quickplay / progression
--   #5 Flag is_anomaly_day untuk 7 tanggal anomali
--   #6 Flag is_known_bad_release untuk iOS 2.6.30
-- Tambahan:
--   Sesi dihitung sendiri (ga_session_id tidak ada di dataset 2018):
--   sesi baru dimulai jika pengguna tidak aktif lebih dari 30 menit.
--
-- Output: flood_it_analytics.stg_events
-- =====================================================================
-- Catatan: tabel TIDAK dipartisi per tanggal. Di BigQuery Sandbox, partisi
-- otomatis kedaluwarsa 60 hari setelah tanggalnya, jadi data 2018 akan
-- langsung terhapus kalau dipartisi.
CREATE OR REPLACE TABLE flood_it_analytics.stg_events
CLUSTER BY event_name, user_pseudo_id
AS

WITH raw AS (
  SELECT
    *,
    TO_JSON_STRING(event_params) AS params_json
  FROM `firebase-public-project.analytics_153293282.events_*`
),

-- #1 Hapus duplikat persis: simpan hanya 1 baris per kombinasi identik
dedup AS (
  SELECT * EXCEPT (rn)
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (
        PARTITION BY user_pseudo_id, event_name, event_timestamp, params_json
      ) AS rn
    FROM raw
  )
  WHERE rn = 1
),

flat AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date)  AS event_date,
    TIMESTAMP_MICROS(event_timestamp) AS event_ts,
    event_timestamp                   AS event_ts_micros,
    user_pseudo_id,
    event_name,

    -- #4 mode permainan
    CASE
      WHEN ENDS_WITH(event_name, '_quickplay') THEN 'quickplay'
      WHEN event_name IN ('level_start', 'level_end', 'level_complete', 'level_fail',
                          'level_retry', 'level_reset', 'level_up', 'completed_5_levels')
        THEN 'progression'
    END AS mode,

    -- nama event tanpa akhiran _quickplay, supaya kedua mode bisa dibandingkan
    REGEXP_REPLACE(event_name, r'_quickplay$', '') AS event_base,

    -- #2 parameter angka: ambil dari int_value ATAU double_value
    (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64))
       FROM UNNEST(event_params) WHERE key = 'level')  AS level,
    (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64))
       FROM UNNEST(event_params) WHERE key = 'score')  AS score,
    (SELECT COALESCE(CAST(value.int_value AS FLOAT64), value.double_value)
       FROM UNNEST(event_params) WHERE key = 'value')  AS value_num,

    -- parameter teks
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'level_name')   AS level_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'board')        AS board,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'content_type') AS content_type,
    -- #3 huruf kecil
    (SELECT LOWER(value.string_value) FROM UNNEST(event_params) WHERE key = 'item_id') AS item_id,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'item_name')    AS item_name,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'firebase_screen_class') AS screen_class,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'engagement_time_msec')  AS engagement_time_msec,

    -- konteks
    platform,
    app_info.version AS app_version,
    geo.country      AS country,
    device.category  AS device_category,

    -- #5 tanggal anomali (screen_view hilang dari sampel, DAU melonjak)
    PARSE_DATE('%Y%m%d', event_date) IN UNNEST([
      DATE '2018-06-18', DATE '2018-06-19', DATE '2018-06-25', DATE '2018-06-26',
      DATE '2018-06-28', DATE '2018-06-30', DATE '2018-07-01'
    ]) AS is_anomaly_day,

    -- #6 rilis yang diketahui merusak tracking level
    (platform = 'IOS' AND app_info.version = '2.6.30') AS is_known_bad_release
  FROM dedup
),

-- Sesi: tandai event pertama setelah jeda > 30 menit
session_flag AS (
  SELECT
    *,
    IF(
      LAG(event_ts_micros) OVER (PARTITION BY user_pseudo_id ORDER BY event_ts_micros) IS NULL
      OR event_ts_micros
         - LAG(event_ts_micros) OVER (PARTITION BY user_pseudo_id ORDER BY event_ts_micros)
         > 30 * 60 * 1000000,
      1, 0
    ) AS is_new_session
  FROM flat
)

SELECT
  * EXCEPT (is_new_session),
  SUM(is_new_session) OVER (
    PARTITION BY user_pseudo_id ORDER BY event_ts_micros
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS session_number,
  CONCAT(
    user_pseudo_id, '-',
    CAST(SUM(is_new_session) OVER (
      PARTITION BY user_pseudo_id ORDER BY event_ts_micros
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS STRING)
  ) AS session_key
FROM session_flag;
