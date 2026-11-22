-- =====================================================================
-- ANALISIS 04: SEGMENTASI
-- Pertanyaan: Apakah perilaku pengguna berbeda antar platform, negara, dan versi aplikasi?
-- Segmen diambil dari event PERTAMA pengguna (dim_users.first_*).
-- Metrik engagement tanpa hari anomali; retensi hanya untuk pengguna baru.
-- =====================================================================
WITH max_d AS (
  SELECT MAX(event_date) AS m FROM flood_it_analytics.fct_daily_users
),

daily AS (
  SELECT
    user_pseudo_id,
    AVG(engagement_sec) / 60 AS avg_engagement_min,
    AVG(sessions)            AS avg_sessions_per_day,
    SUM(levels_started)      AS levels_started,
    LOGICAL_OR(days_since_install = 1) AS d1,
    LOGICAL_OR(days_since_install = 7) AS d7
  FROM flood_it_analytics.fct_daily_users
  WHERE NOT is_anomaly_day
  GROUP BY user_pseudo_id
),

u AS (
  SELECT
    d.*,
    IFNULL(x.d1, FALSE) AS d1,
    IFNULL(x.d7, FALSE) AS d7,
    x.avg_engagement_min,
    x.avg_sessions_per_day,
    x.levels_started,
    d.is_new_user AND NOT d.is_install_anomaly
      AND DATE_ADD(d.install_date, INTERVAL 1 DAY) <= m.m AS elig_d1,
    d.is_new_user AND NOT d.is_install_anomaly
      AND DATE_ADD(d.install_date, INTERVAL 7 DAY) <= m.m AS elig_d7
  FROM flood_it_analytics.dim_users d
  LEFT JOIN daily x USING (user_pseudo_id)
  CROSS JOIN max_d m
),

long AS (
  SELECT 'platform'    AS dimension, first_platform    AS segment, u.* FROM u
  UNION ALL
  SELECT 'country'     AS dimension, first_country     AS segment, u.* FROM u
  UNION ALL
  SELECT 'app_version' AS dimension, CONCAT(first_platform, ' ', first_app_version) AS segment, u.* FROM u
)

SELECT
  dimension,
  segment,
  COUNT(*)                                     AS users,
  COUNTIF(is_new_user)                         AS new_users,
  ROUND(AVG(active_days), 1)                   AS avg_active_days,
  ROUND(AVG(avg_sessions_per_day), 2)          AS avg_sessions_per_active_day,
  ROUND(AVG(avg_engagement_min), 1)            AS avg_engagement_min_per_active_day,
  ROUND(AVG(levels_started), 1)                AS avg_levels_started,
  ROUND(100 * COUNTIF(d1 AND elig_d1) / NULLIF(COUNTIF(elig_d1), 0), 1) AS d1_retention_pct,
  ROUND(100 * COUNTIF(d7 AND elig_d7) / NULLIF(COUNTIF(elig_d7), 0), 1) AS d7_retention_pct
FROM long
GROUP BY dimension, segment
HAVING users >= 200            -- segmen kecil diabaikan supaya tidak menyesatkan
ORDER BY dimension, users DESC;
