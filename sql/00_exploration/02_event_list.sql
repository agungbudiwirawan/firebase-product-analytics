SELECT
  event_name,
  COUNT(*)                       AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS total_users
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY event_name
ORDER BY total_events DESC;
