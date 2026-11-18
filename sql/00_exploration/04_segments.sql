SELECT
  platform,
  app_info.version AS app_version,
  geo.country,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY 1, 2, 3
ORDER BY users DESC
LIMIT 30;
