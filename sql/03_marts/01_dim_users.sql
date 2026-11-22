-- =====================================================================
-- MART: dim_users
-- 1 baris = 1 pengguna. Profil dasar + tanggal install.
-- Aturan cleaning:
--   #7 Tanggal install = tanggal first_open
--   #8 is_install_anomaly = first_open tercatat > 1 hari setelah event pertama
-- Output: flood_it_analytics.dim_users
-- =====================================================================
CREATE OR REPLACE TABLE flood_it_analytics.dim_users AS

WITH agg AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'first_open', event_ts, NULL)) AS first_open_ts,
    -- pakai event_date (zona waktu laporan Firebase), BUKAN DATE(event_ts) yang UTC,
    -- supaya sama dengan event_date di fct_daily_users
    MIN(IF(event_name = 'first_open', event_date, NULL)) AS first_open_date,
    MIN(event_ts)                                      AS first_event_ts,
    MIN(event_date)                                    AS first_seen_date,
    MAX(event_date)                                    AS last_seen_date,
    COUNT(DISTINCT event_date)                         AS active_days,
    COUNT(DISTINCT session_key)                        AS total_sessions,
    COUNT(*)                                           AS total_events,
    -- atribut dari event PERTAMA pengguna
    ARRAY_AGG(platform    ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS first_platform,
    ARRAY_AGG(country     ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS first_country,
    ARRAY_AGG(app_version ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS first_app_version
  FROM flood_it_analytics.stg_events
  GROUP BY user_pseudo_id
)

SELECT
  user_pseudo_id,
  first_open_date                AS install_date,
  first_open_ts IS NOT NULL      AS is_new_user,   -- install di dalam periode data
  first_seen_date,
  last_seen_date,
  active_days,
  total_sessions,
  total_events,
  first_platform,
  first_country,
  first_app_version,
  IFNULL(TIMESTAMP_DIFF(first_open_ts, first_event_ts, HOUR) >= 24, FALSE) AS is_install_anomaly
FROM agg;
