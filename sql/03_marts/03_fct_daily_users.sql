-- =====================================================================
-- MART: fct_daily_users
-- 1 baris = 1 pengguna aktif pada 1 tanggal.
-- Dasar untuk DAU/MAU, stickiness, dan retention (via days_since_install).
-- Output: flood_it_analytics.fct_daily_users
-- =====================================================================
CREATE OR REPLACE TABLE flood_it_analytics.fct_daily_users AS

SELECT
  e.event_date,
  e.user_pseudo_id,
  u.install_date,
  u.is_new_user,
  DATE_DIFF(e.event_date, u.install_date, DAY)   AS days_since_install,  -- NULL jika install sebelum periode data
  COUNT(DISTINCT e.session_key)                  AS sessions,
  COUNT(*)                                       AS events,
  ROUND(SUM(IFNULL(e.engagement_time_msec, 0)) / 1000, 1) AS engagement_sec,
  COUNTIF(e.event_base = 'level_start')          AS levels_started,
  COUNTIF(e.event_base = 'level_complete')       AS levels_completed,
  ARRAY_AGG(e.platform    ORDER BY e.event_ts LIMIT 1)[OFFSET(0)] AS platform,
  ARRAY_AGG(e.app_version ORDER BY e.event_ts LIMIT 1)[OFFSET(0)] AS app_version,
  ARRAY_AGG(e.country     ORDER BY e.event_ts LIMIT 1)[OFFSET(0)] AS country,
  LOGICAL_OR(e.is_anomaly_day)                   AS is_anomaly_day
FROM flood_it_analytics.stg_events e
JOIN flood_it_analytics.dim_users u USING (user_pseudo_id)
GROUP BY e.event_date, e.user_pseudo_id, u.install_date, u.is_new_user;
