WITH u AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'first_open', event_timestamp, NULL)) AS first_open_ts,
    MIN(event_timestamp) AS first_event_ts
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
)
SELECT
  CASE
    WHEN (first_open_ts - first_event_ts) / 1e6 < 1     THEN '1. < 1 detik'
    WHEN (first_open_ts - first_event_ts) / 1e6 < 60    THEN '2. 1-60 detik'
    WHEN (first_open_ts - first_event_ts) / 1e6 < 3600  THEN '3. 1-60 menit'
    WHEN (first_open_ts - first_event_ts) / 1e6 < 86400 THEN '4. 1-24 jam'
    ELSE '5. > 1 hari'
  END AS gap_bucket,
  COUNT(*) AS users
FROM u
WHERE first_open_ts > first_event_ts
GROUP BY gap_bucket
ORDER BY gap_bucket;
