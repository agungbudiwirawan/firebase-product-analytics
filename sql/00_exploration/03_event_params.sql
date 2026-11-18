SELECT
  event_name,
  p.key AS param_key,
  COUNT(*) AS total,
  COUNTIF(p.value.string_value IS NOT NULL) AS as_string,
  COUNTIF(p.value.int_value    IS NOT NULL) AS as_int,
  COUNTIF(p.value.double_value IS NOT NULL) AS as_double
FROM `firebase-public-project.analytics_153293282.events_*`,
  UNNEST(event_params) AS p
GROUP BY event_name, param_key
ORDER BY event_name, total DESC;
