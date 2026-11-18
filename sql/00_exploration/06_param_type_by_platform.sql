SELECT
  platform,
  event_name,
  COUNTIF(p.value.int_value    IS NOT NULL) AS level_as_int,
  COUNTIF(p.value.double_value IS NOT NULL) AS level_as_double,
  COUNTIF(EXISTS(SELECT 1 FROM UNNEST(event_params) WHERE key = 'level_name')) AS has_level_name
FROM `firebase-public-project.analytics_153293282.events_*`,
  UNNEST(event_params) AS p
WHERE p.key = 'level'
  AND event_name IN ('level_start', 'level_end', 'post_score')
GROUP BY platform, event_name
ORDER BY event_name, platform;
