-- =====================================================================
-- ANALISIS 05: KENAPA RETENSI D1 TURUN MULAI COHORT 27 AGUSTUS?
-- D1 cohort sebelum 27 Agu: ±21-32%  |  sejak 27 Agu: ±11-18%
--
-- Dua kemungkinan penyebab:
--   (a) MIX SHIFT: komposisi pengguna baru berubah (lebih banyak dari segmen
--       yang retensinya memang rendah), padahal retensi tiap segmen tetap.
--   (b) PENURUNAN NYATA: retensi turun di hampir SEMUA segmen.
-- Cara membaca hasil:
--   - share_before vs share_after berubah besar  -> indikasi (a)
--   - d1_before vs d1_after turun di semua segmen -> indikasi (b)
-- =====================================================================
WITH max_d AS (
  SELECT MAX(event_date) AS m FROM flood_it_analytics.fct_daily_users
),

c AS (
  SELECT
    u.*,
    u.install_date >= DATE '2018-08-27' AS is_after
  FROM flood_it_analytics.dim_users u
  CROSS JOIN max_d
  WHERE u.is_new_user
    AND NOT u.is_install_anomaly
    AND DATE_ADD(u.install_date, INTERVAL 1 DAY) <= max_d.m   -- sudah bisa dihitung D1
),

act AS (
  SELECT DISTINCT user_pseudo_id, TRUE AS d1
  FROM flood_it_analytics.fct_daily_users
  WHERE days_since_install = 1
),

x AS (
  SELECT c.*, IFNULL(a.d1, FALSE) AS d1
  FROM c
  LEFT JOIN act a USING (user_pseudo_id)
),

long AS (
  SELECT 'platform' AS dimension, first_platform AS segment, is_after, d1 FROM x
  UNION ALL
  SELECT 'country',
         IF(first_country IN ('United States', 'India', 'Japan', 'Canada',
                              'United Kingdom', 'Australia'),
            first_country, 'Lainnya'),
         is_after, d1
  FROM x
  UNION ALL
  SELECT 'app_version', CONCAT(first_platform, ' ', first_app_version), is_after, d1 FROM x
)

SELECT
  dimension,
  segment,
  COUNTIF(NOT is_after)                                                     AS users_before,
  COUNTIF(is_after)                                                         AS users_after,
  ROUND(100 * COUNTIF(NOT is_after) / SUM(COUNTIF(NOT is_after)) OVER (PARTITION BY dimension), 1) AS share_before_pct,
  ROUND(100 * COUNTIF(is_after)     / SUM(COUNTIF(is_after))     OVER (PARTITION BY dimension), 1) AS share_after_pct,
  ROUND(100 * COUNTIF(NOT is_after AND d1) / NULLIF(COUNTIF(NOT is_after), 0), 1) AS d1_before_pct,
  ROUND(100 * COUNTIF(is_after AND d1)     / NULLIF(COUNTIF(is_after), 0), 1)     AS d1_after_pct
FROM long
GROUP BY dimension, segment
HAVING users_before + users_after >= 50
ORDER BY dimension, users_after DESC;
