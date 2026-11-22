-- =====================================================================
-- ANALISIS 03: FUNNEL
-- Pertanyaan: Di tahap mana pengguna paling banyak berhenti?
-- Funnel dihitung di level PENGGUNA (pernah / tidak pernah melakukan aksi),
-- sesuai aturan cleaning #9 di data_quality_report.md.
-- File ini berisi 2 query.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3a: Funnel pengguna baru (dari install sampai aksi lanjutan)
-- ---------------------------------------------------------------------
WITH new_users AS (
  SELECT user_pseudo_id
  FROM flood_it_analytics.dim_users
  WHERE is_new_user AND NOT is_install_anomaly
),

flags AS (
  SELECT
    e.user_pseudo_id,
    LOGICAL_OR(e.event_name = 'level_start_quickplay')    AS qp_started,
    LOGICAL_OR(e.event_name = 'level_complete_quickplay') AS qp_completed,
    LOGICAL_OR(e.event_name = 'level_start')              AS prog_started,
    LOGICAL_OR(e.event_name = 'level_complete')           AS prog_completed,
    LOGICAL_OR(e.event_name = 'completed_5_levels')       AS prog_5_levels,
    LOGICAL_OR(e.event_base = 'level_start')              AS any_started,
    LOGICAL_OR(e.event_base = 'level_complete')           AS any_completed,
    LOGICAL_OR(e.event_name IN ('use_extra_steps', 'spend_virtual_currency')) AS used_items,
    LOGICAL_OR(e.event_name = 'ad_reward')                AS watched_ad,
    COUNT(DISTINCT e.event_date) >= 2                     AS returned_another_day
  FROM flood_it_analytics.stg_events e
  JOIN new_users USING (user_pseudo_id)
  GROUP BY e.user_pseudo_id
),

totals AS (
  SELECT
    COUNT(*)                     AS a01_install,
    COUNTIF(any_started)         AS a02_started_any_level,
    COUNTIF(any_completed)       AS a03_completed_any_level,
    COUNTIF(returned_another_day) AS a04_returned_another_day,
    COUNTIF(qp_started)          AS b01_quickplay_started,
    COUNTIF(qp_completed)        AS b02_quickplay_completed,
    COUNTIF(prog_started)        AS c01_progression_started,
    COUNTIF(prog_completed)      AS c02_progression_completed,
    COUNTIF(prog_5_levels)       AS c03_progression_5_levels,
    COUNTIF(used_items)          AS d01_used_items,
    COUNTIF(watched_ad)          AS d02_watched_reward_ad
  FROM flags
)

SELECT
  step,
  users,
  ROUND(100 * users / MAX(users) OVER (), 1) AS pct_of_installs
FROM totals
UNPIVOT (users FOR step IN (
  a01_install, a02_started_any_level, a03_completed_any_level, a04_returned_another_day,
  b01_quickplay_started, b02_quickplay_completed,
  c01_progression_started, c02_progression_completed, c03_progression_5_levels,
  d01_used_items, d02_watched_reward_ad
))
ORDER BY step;


-- ---------------------------------------------------------------------
-- 3b: Funnel per level / ukuran papan
--   reach_pct      = % pengguna yang sampai ke level ini dibanding level pertama
--   drop_from_prev = % pengguna yang hilang dibanding level sebelumnya
-- (iOS 2.6.30 sudah dikeluarkan di fct_level_funnel)
-- ---------------------------------------------------------------------
SELECT
  mode,
  level_or_board,
  users_started,
  users_completed,
  user_completion_rate,
  win_rate,
  struggle_ratio,
  -- SAFE_DIVIDE: hasilnya NULL (bukan error) kalau pembaginya 0
  IF(mode = 'progression',
     ROUND(100 * SAFE_DIVIDE(users_started, FIRST_VALUE(users_started) OVER w), 1), NULL) AS reach_pct,
  IF(mode = 'progression',
     ROUND(100 * (1 - SAFE_DIVIDE(users_started, LAG(users_started) OVER w)), 1), NULL)   AS drop_from_prev_pct
FROM flood_it_analytics.fct_level_funnel
-- level 0 dan 31 hanya muncul di event retry/reset, tanpa level_start;
-- kalau ikut, level 0 jadi "level pertama" dan semua reach_pct jadi kosong
WHERE users_started > 0
WINDOW w AS (PARTITION BY mode ORDER BY level_num, level_or_board)
ORDER BY mode, level_num, level_or_board;
