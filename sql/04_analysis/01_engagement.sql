-- =====================================================================
-- ANALISIS 01: ENGAGEMENT (DAU, MAU, stickiness)
-- Pertanyaan: Berapa pengguna aktif harian/bulanan, dan seberapa "lengket" aplikasinya?
-- Catatan:
--   - MAU = pengguna unik dalam 30 hari terakhir (rolling), dihitung mulai hari ke-30.
--   - Hari anomali ditandai, dan dikeluarkan dari ringkasan (1b).
--   - Data sampel 50.000 event/hari: angka absolut lebih kecil dari aslinya.
-- File ini berisi 2 query.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1a: Deret harian (untuk grafik garis di dashboard)
-- ---------------------------------------------------------------------
WITH dates AS (
  SELECT
    event_date,
    COUNT(*)                         AS dau,
    SUM(sessions)                    AS sessions,
    ROUND(AVG(engagement_sec) / 60, 1) AS avg_engagement_min_per_user,
    LOGICAL_OR(is_anomaly_day)       AS is_anomaly_day
  FROM flood_it_analytics.fct_daily_users
  GROUP BY event_date
),

mau AS (
  SELECT
    d.event_date,
    COUNT(DISTINCT f.user_pseudo_id) AS mau
  FROM dates d
  JOIN flood_it_analytics.fct_daily_users f
    ON f.event_date BETWEEN DATE_SUB(d.event_date, INTERVAL 29 DAY) AND d.event_date
  GROUP BY d.event_date
),

first_day AS (
  SELECT MIN(event_date) AS d0 FROM dates
)

SELECT
  d.event_date,
  d.dau,
  IF(d.event_date >= DATE_ADD(f.d0, INTERVAL 29 DAY), m.mau, NULL) AS mau_30d,
  IF(d.event_date >= DATE_ADD(f.d0, INTERVAL 29 DAY),
     ROUND(100 * d.dau / m.mau, 1), NULL)                          AS stickiness_pct,
  ROUND(d.sessions / d.dau, 2)                                     AS sessions_per_user,
  d.avg_engagement_min_per_user,
  d.is_anomaly_day
FROM dates d
JOIN mau m USING (event_date)
CROSS JOIN first_day f
ORDER BY d.event_date;


-- ---------------------------------------------------------------------
-- 1b: Ringkasan per bulan (tanpa hari anomali)
-- ---------------------------------------------------------------------
SELECT
  DATE_TRUNC(event_date, MONTH)                                   AS month,
  COUNT(DISTINCT event_date)                                      AS days,
  ROUND(COUNT(*) / COUNT(DISTINCT event_date))                    AS avg_dau,
  COUNT(DISTINCT user_pseudo_id)                                  AS mau,
  ROUND(100 * (COUNT(*) / COUNT(DISTINCT event_date))
            / COUNT(DISTINCT user_pseudo_id), 1)                  AS stickiness_pct,
  ROUND(SUM(sessions) / COUNT(*), 2)                              AS sessions_per_active_day,
  ROUND(AVG(engagement_sec) / 60, 1)                              AS engagement_min_per_active_day
FROM flood_it_analytics.fct_daily_users
WHERE NOT is_anomaly_day
GROUP BY month
ORDER BY month;
