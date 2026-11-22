-- =====================================================================
-- CEK 3: UNIQUENESS (duplikat)
-- Pertanyaan: Apakah ada event yang tercatat lebih dari sekali?
-- Definisi duplikat: user, event, timestamp, DAN isi parameter sama persis.
-- Event berbeda di timestamp yang sama itu wajar, jadi tidak dihitung.
-- =====================================================================
WITH keyed AS (
  SELECT
    event_name,
    user_pseudo_id,
    event_timestamp,
    TO_JSON_STRING(event_params) AS params_json,
    COUNT(*) AS n
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY event_name, user_pseudo_id, event_timestamp, params_json
)

SELECT
  event_name,
  SUM(n)                              AS total_rows,
  SUM(n - 1)                          AS duplicate_rows,
  ROUND(100 * SUM(n - 1) / SUM(n), 3) AS pct_duplicate
FROM keyed
GROUP BY event_name
ORDER BY duplicate_rows DESC;
