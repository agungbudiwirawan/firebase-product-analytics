-- =====================================================================
-- MART: fct_level_funnel
-- 1 baris = 1 level (Progression) atau 1 ukuran papan (Quickplay).
-- Aturan cleaning #9: funnel dihitung di level PENGGUNA
-- (berapa pengguna yang pernah start / complete / fail), bukan memasangkan event.
-- iOS 2.6.30 dikeluarkan karena tidak mengirim level_complete (Progression).
-- Output: flood_it_analytics.fct_level_funnel
-- =====================================================================
CREATE OR REPLACE TABLE flood_it_analytics.fct_level_funnel AS

WITH base AS (
  SELECT
    mode,
    IF(mode = 'progression', CAST(level AS STRING), board) AS level_or_board,
    level,
    user_pseudo_id,
    event_base
  FROM flood_it_analytics.stg_events
  WHERE mode IS NOT NULL
    AND event_base IN ('level_start', 'level_end', 'level_complete', 'level_fail', 'level_retry', 'level_reset')
    AND NOT is_known_bad_release
),

agg AS (
  SELECT
    mode,
    level_or_board,
    ANY_VALUE(level) AS level_num,     -- untuk mengurutkan level Progression
    COUNT(DISTINCT IF(event_base = 'level_start',    user_pseudo_id, NULL)) AS users_started,
    COUNT(DISTINCT IF(event_base = 'level_complete', user_pseudo_id, NULL)) AS users_completed,
    COUNT(DISTINCT IF(event_base = 'level_fail',     user_pseudo_id, NULL)) AS users_failed,
    COUNTIF(event_base = 'level_start')    AS starts,
    COUNTIF(event_base = 'level_complete') AS completes,
    COUNTIF(event_base = 'level_fail')     AS fails,
    COUNTIF(event_base = 'level_retry')    AS retries,
    COUNTIF(event_base = 'level_reset')    AS resets
  FROM base
  WHERE level_or_board IS NOT NULL
  GROUP BY mode, level_or_board
)

SELECT
  *,
  ROUND(SAFE_DIVIDE(users_completed, users_started), 4)  AS user_completion_rate,
  ROUND(SAFE_DIVIDE(completes, completes + fails), 4)    AS win_rate,      -- dari percobaan yang selesai
  ROUND(SAFE_DIVIDE(fails + retries + resets, starts), 4) AS struggle_ratio -- makin tinggi makin sulit
FROM agg;
