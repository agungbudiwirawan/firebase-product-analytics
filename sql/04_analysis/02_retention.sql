-- =====================================================================
-- ANALISIS 02: RETENTION
-- Pertanyaan: Berapa persen pengguna baru yang kembali di hari ke-1, 7, dan 30?
-- Definisi:
--   - Hanya pengguna baru (punya first_open di periode data), tanpa install anomaly.
--   - Dn retention = % pengguna yang aktif TEPAT di hari ke-n setelah install.
--   - Pengguna hanya dihitung jika sudah cukup umur (install + n hari <= tanggal data terakhir).
-- Catatan: karena data disampel, aktivitas di hari ke-n bisa tidak ikut tercatat,
-- jadi angka retensi cenderung lebih rendah dari aslinya.
-- File ini berisi 2 query.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2a: Cohort mingguan (untuk heatmap / tabel cohort)
-- ---------------------------------------------------------------------
WITH max_d AS (
  SELECT MAX(event_date) AS m FROM flood_it_analytics.fct_daily_users
),

cohort AS (
  SELECT
    user_pseudo_id,
    install_date,
    DATE_TRUNC(install_date, WEEK(MONDAY)) AS cohort_week
  FROM flood_it_analytics.dim_users
  WHERE is_new_user AND NOT is_install_anomaly
),

act AS (
  SELECT
    user_pseudo_id,
    LOGICAL_OR(days_since_install = 1)  AS d1,
    LOGICAL_OR(days_since_install = 7)  AS d7,
    LOGICAL_OR(days_since_install = 30) AS d30
  FROM flood_it_analytics.fct_daily_users
  WHERE days_since_install IN (1, 7, 30)
  GROUP BY user_pseudo_id
),

u AS (
  SELECT
    c.cohort_week,
    IFNULL(a.d1,  FALSE) AS d1,
    IFNULL(a.d7,  FALSE) AS d7,
    IFNULL(a.d30, FALSE) AS d30,
    DATE_ADD(c.install_date, INTERVAL 1  DAY) <= m.m AS elig_d1,
    DATE_ADD(c.install_date, INTERVAL 7  DAY) <= m.m AS elig_d7,
    DATE_ADD(c.install_date, INTERVAL 30 DAY) <= m.m AS elig_d30
  FROM cohort c
  LEFT JOIN act a USING (user_pseudo_id)
  CROSS JOIN max_d m
)

SELECT
  IFNULL(CAST(cohort_week AS STRING), 'SEMUA') AS cohort,
  COUNT(*)                                     AS new_users,
  ROUND(100 * COUNTIF(d1  AND elig_d1)  / NULLIF(COUNTIF(elig_d1),  0), 1) AS d1_retention_pct,
  ROUND(100 * COUNTIF(d7  AND elig_d7)  / NULLIF(COUNTIF(elig_d7),  0), 1) AS d7_retention_pct,
  ROUND(100 * COUNTIF(d30 AND elig_d30) / NULLIF(COUNTIF(elig_d30), 0), 1) AS d30_retention_pct
FROM u
GROUP BY ROLLUP (cohort_week)
ORDER BY cohort;   -- baris 'SEMUA' (total) muncul paling bawah


-- ---------------------------------------------------------------------
-- 2b: Kurva retensi hari 0-30 (untuk grafik garis)
-- ---------------------------------------------------------------------
WITH max_d AS (
  SELECT MAX(event_date) AS m FROM flood_it_analytics.fct_daily_users
),

new_users AS (
  SELECT user_pseudo_id, install_date
  FROM flood_it_analytics.dim_users
  WHERE is_new_user AND NOT is_install_anomaly
),

days AS (
  SELECT d FROM UNNEST(GENERATE_ARRAY(0, 30)) AS d
),

eligible AS (
  SELECT days.d, COUNT(*) AS n
  FROM days
  CROSS JOIN new_users
  CROSS JOIN max_d
  WHERE DATE_ADD(new_users.install_date, INTERVAL days.d DAY) <= max_d.m
  GROUP BY days.d
),

active AS (
  SELECT
    f.days_since_install AS d,
    COUNT(DISTINCT f.user_pseudo_id) AS n
  FROM flood_it_analytics.fct_daily_users f
  JOIN new_users USING (user_pseudo_id)
  WHERE f.days_since_install BETWEEN 0 AND 30
  GROUP BY d
)

SELECT
  e.d                                       AS day_since_install,
  e.n                                       AS eligible_users,
  IFNULL(a.n, 0)                            AS active_users,
  ROUND(100 * IFNULL(a.n, 0) / e.n, 2)      AS retention_pct
FROM eligible e
LEFT JOIN active a USING (d)
ORDER BY day_since_install;
