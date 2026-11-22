-- =====================================================================
-- MART: fct_sessions
-- 1 baris = 1 sesi (sesi baru jika jeda tidak aktif > 30 menit).
-- Output: flood_it_analytics.fct_sessions
-- =====================================================================
CREATE OR REPLACE TABLE flood_it_analytics.fct_sessions AS

SELECT
  session_key,
  user_pseudo_id,
  session_number,
  MIN(event_date)                                AS session_date,
  MIN(event_ts)                                  AS session_start,
  MAX(event_ts)                                  AS session_end,
  TIMESTAMP_DIFF(MAX(event_ts), MIN(event_ts), SECOND) AS session_duration_sec,
  ROUND(SUM(IFNULL(engagement_time_msec, 0)) / 1000, 1) AS engagement_sec,
  COUNT(*)                                       AS events,
  COUNTIF(event_name = 'screen_view')            AS screen_views,

  -- aktivitas bermain per mode
  COUNTIF(event_name = 'level_start_quickplay')    AS quickplay_starts,
  COUNTIF(event_name = 'level_complete_quickplay') AS quickplay_completes,
  COUNTIF(event_name = 'level_start')              AS progression_starts,
  COUNTIF(event_name = 'level_complete')           AS progression_completes,

  -- monetisasi ringan
  COUNTIF(event_name = 'use_extra_steps')        AS extra_steps_used,
  COUNTIF(event_name = 'ad_reward')              AS ads_rewarded,

  -- konteks (nilai dari event pertama sesi)
  ARRAY_AGG(platform    ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS platform,
  ARRAY_AGG(app_version ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS app_version,
  ARRAY_AGG(country     ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS country,

  LOGICAL_OR(is_anomaly_day)                     AS is_anomaly_day,
  LOGICAL_OR(is_known_bad_release)               AS is_known_bad_release
FROM flood_it_analytics.stg_events
GROUP BY session_key, user_pseudo_id, session_number;
