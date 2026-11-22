-- =====================================================================
-- CEK 04: CONSISTENCY
-- (4a) first_open: tiap pengguna maksimal 1 kali, dan harus jadi event pertamanya.
-- (4b) Jumlah level_end harus = level_complete + level_fail di tiap mode.
-- File ini berisi 2 query. Di BigQuery, hasil tiap query muncul terpisah.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4a: first_open
-- ---------------------------------------------------------------------
WITH u AS (
  SELECT
    user_pseudo_id,
    COUNTIF(event_name = 'first_open')                        AS n_first_open,
    MIN(IF(event_name = 'first_open', event_timestamp, NULL)) AS first_open_ts,
    MIN(event_timestamp)                                      AS first_event_ts
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
)

SELECT
  COUNT(*)                                                      AS total_users,
  COUNTIF(n_first_open = 0)                                     AS users_without_first_open,
  COUNTIF(n_first_open > 1)                                     AS users_multi_first_open,
  COUNTIF(n_first_open >= 1 AND first_event_ts < first_open_ts) AS users_with_events_before_first_open
FROM u;


-- ---------------------------------------------------------------------
-- 4b: end vs complete + fail, per mode, platform, dan versi
-- ---------------------------------------------------------------------
SELECT
  IF(ENDS_WITH(event_name, '_quickplay'), 'quickplay', 'progression') AS mode,
  platform,
  app_info.version                                   AS app_version,
  COUNTIF(STARTS_WITH(event_name, 'level_end'))      AS n_end,
  COUNTIF(STARTS_WITH(event_name, 'level_complete')) AS n_complete,
  COUNTIF(STARTS_WITH(event_name, 'level_fail'))     AS n_fail,
  COUNTIF(STARTS_WITH(event_name, 'level_end'))
    - COUNTIF(STARTS_WITH(event_name, 'level_complete'))
    - COUNTIF(STARTS_WITH(event_name, 'level_fail')) AS gap   -- idealnya 0
FROM `firebase-public-project.analytics_153293282.events_*`
WHERE event_name IN ('level_end', 'level_complete', 'level_fail',
                     'level_end_quickplay', 'level_complete_quickplay', 'level_fail_quickplay')
GROUP BY mode, platform, app_version
HAVING n_end >= 100   -- abaikan versi dengan data sangat sedikit
ORDER BY mode, ABS(gap) DESC;
