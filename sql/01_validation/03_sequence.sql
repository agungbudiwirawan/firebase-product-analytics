-- =====================================================================
-- CEK 4: SEQUENCE (urutan event logis)
-- Pertanyaan: Apakah setiap level_end didahului level_start untuk level/papan yang sama?
--   start tanpa end = wajar (pemain berhenti di tengah jalan)
--   end tanpa start = TIDAK wajar (event hilang, tracking salah, atau efek sampling)
-- Catatan: data adalah sampel 50.000 event/hari, jadi sebagian "end tanpa start"
-- bisa terjadi karena event start tidak ikut tersampel.
-- File ini berisi 2 query. Di BigQuery, hasil tiap query muncul terpisah.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4a: level_end didahului level_start?
-- ---------------------------------------------------------------------
WITH lv AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    platform,
    IF(ENDS_WITH(event_name, '_quickplay'), 'quickplay', 'progression') AS mode,
    IF(STARTS_WITH(event_name, 'level_start'), 'start', 'end')         AS step,
    -- level progression: gabungkan int & double jadi satu angka
    (SELECT COALESCE(value.int_value, CAST(value.double_value AS INT64))
       FROM UNNEST(event_params) WHERE key = 'level')                  AS level,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'board') AS board
  FROM `firebase-public-project.analytics_153293282.events_*`
  WHERE event_name IN ('level_start', 'level_end', 'level_start_quickplay', 'level_end_quickplay')
),

seq AS (
  SELECT
    *,
    LAG(step)  OVER w AS prev_step,
    LAG(level) OVER w AS prev_level,
    LAG(board) OVER w AS prev_board
  FROM lv
  WINDOW w AS (PARTITION BY user_pseudo_id, mode ORDER BY event_timestamp)
),

flagged AS (
  SELECT
    *,
    (IFNULL(prev_level, -1) = IFNULL(level, -1)
     AND IFNULL(prev_board, '') = IFNULL(board, '')) AS same_target
  FROM seq
  WHERE step = 'end'
)

SELECT
  mode,
  platform,
  COUNT(*)                                                   AS total_end,
  COUNTIF(prev_step = 'start' AND same_target)               AS valid,
  COUNTIF(prev_step IS NULL)                                 AS end_without_any_start,
  COUNTIF(prev_step = 'end')                                 AS end_after_end,
  COUNTIF(prev_step = 'start' AND NOT same_target)           AS level_or_board_mismatch,
  ROUND(100 * COUNTIF(prev_step = 'start' AND same_target) / COUNT(*), 2) AS pct_valid
FROM flagged
GROUP BY mode, platform
ORDER BY mode, platform;


-- ---------------------------------------------------------------------
-- 4b: post_score dikirim setelah event apa?
-- Tujuan: memastikan post_score muncul di mode Progression saja
-- atau juga di Quickplay.
-- ---------------------------------------------------------------------
WITH e AS (
  SELECT user_pseudo_id, event_timestamp, event_name
  FROM `firebase-public-project.analytics_153293282.events_*`
  WHERE event_name IN ('post_score',
                       'level_end', 'level_complete', 'level_fail',
                       'level_end_quickplay', 'level_complete_quickplay', 'level_fail_quickplay')
),

s AS (
  SELECT
    *,
    LAG(event_name) OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp) AS prev_event
  FROM e
)

SELECT
  IFNULL(prev_event, '(tidak ada)')                 AS prev_event,
  COUNT(*)                                          AS post_score_events,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct
FROM s
WHERE event_name = 'post_score'
GROUP BY prev_event
ORDER BY post_score_events DESC;
