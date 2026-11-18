SELECT
  MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_date,
  MAX(PARSE_DATE('%Y%m%d', event_date)) AS last_date,
  COUNT(DISTINCT event_date)            AS total_days,
  COUNT(DISTINCT user_pseudo_id)        AS total_users,
  COUNT(*)                              AS total_events
FROM `firebase-public-project.analytics_153293282.events_*`;
