-- =====================================================================
-- CEK 05: ANOMALY (pola harian yang tidak wajar)
-- Karena jumlah event dipotong 50.000/hari, yang dibandingkan adalah PROPORSI,
-- bukan jumlah mentah.
-- Pertanyaan:
--   - Kenapa DAU melonjak ke ~1.200 di beberapa tanggal?
--   - Kapan level_start mulai/berhenti kehilangan level_name?
-- =====================================================================
SELECT
  PARSE_DATE('%Y%m%d', event_date)                                   AS date,
  COUNT(DISTINCT user_pseudo_id)                                     AS dau,
  ROUND(COUNT(*) / COUNT(DISTINCT user_pseudo_id), 1)                AS events_per_user,
  ROUND(100 * COUNTIF(platform = 'IOS') / COUNT(*), 1)               AS pct_events_ios,
  ROUND(100 * COUNTIF(event_name = 'screen_view') / COUNT(*), 1)     AS pct_screen_view,
  ROUND(100 * COUNTIF(event_name = 'user_engagement') / COUNT(*), 1) AS pct_user_engagement,
  ROUND(100 * COUNTIF(event_name LIKE 'level_%') / COUNT(*), 1)      AS pct_level_events,
  -- % level_start (progression) yang TIDAK membawa level_name
  ROUND(100 * COUNTIF(event_name = 'level_start'
          AND NOT EXISTS(SELECT 1 FROM UNNEST(event_params) WHERE key = 'level_name'))
        / NULLIF(COUNTIF(event_name = 'level_start'), 0), 1)         AS pct_level_start_no_name
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY date
ORDER BY date;
