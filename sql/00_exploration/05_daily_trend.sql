SELECT
  PARSE_DATE('%Y%m%d', event_date) AS date,
  COUNT(DISTINCT user_pseudo_id)   AS dau,
  COUNT(*)                         AS events
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY date
ORDER BY date;
