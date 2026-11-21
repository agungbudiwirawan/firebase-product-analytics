-- =====================================================================
-- CEK 1 & 2: COMPLETENESS + TYPE VALIDITY
-- Pertanyaan:
--   (1) Apakah parameter wajib (sesuai tracking plan) selalu terisi?
--   (2) Apakah nilainya dikirim dengan tipe data yang diharapkan?
-- 1 baris hasil = 1 pasangan (event, parameter wajib).
-- =====================================================================
WITH required AS (
  -- Daftar parameter wajib + tipe yang diharapkan, diambil dari docs/tracking_plan.md
  SELECT * FROM UNNEST([
    STRUCT('screen_view' AS event_name, 'firebase_screen_class' AS param_key, 'string' AS expected_type),
    ('screen_view',              'firebase_screen_id',    'int'),
    ('user_engagement',          'engagement_time_msec',  'int'),
    ('level_start_quickplay',    'board',                 'string'),
    ('level_end_quickplay',      'board',                 'string'),
    ('level_complete_quickplay', 'board',                 'string'),
    ('level_complete_quickplay', 'value',                 'int'),
    ('level_fail_quickplay',     'board',                 'string'),
    ('level_start',              'level',                 'int'),
    ('level_start',              'level_name',            'string'),
    ('level_end',                'level',                 'int'),
    ('level_end',                'level_name',            'string'),
    ('level_complete',           'level',                 'int'),
    ('level_complete',           'level_name',            'string'),
    ('level_fail',               'level',                 'int'),
    ('level_fail',               'level_name',            'string'),
    ('post_score',               'score',                 'int'),
    ('post_score',               'level',                 'int'),
    ('post_score',               'level_name',            'string'),
    ('select_content',           'content_type',          'string'),
    ('select_content',           'item_id',               'string'),
    ('spend_virtual_currency',   'item_name',             'string'),
    ('spend_virtual_currency',   'virtual_currency_name', 'string'),
    ('spend_virtual_currency',   'value',                 'int'),
    ('use_extra_steps',          'item_name',             'string'),
    ('use_extra_steps',          'value',                 'int'),
    ('ad_reward',                'ad_unit_code',          'string'),
    ('ad_reward',                'type',                  'string'),
    ('ad_reward',                'value',                 'int')
  ])
),

events AS (
  SELECT event_name, event_params
  FROM `firebase-public-project.analytics_153293282.events_*`
  WHERE event_name IN (SELECT DISTINCT event_name FROM required)
),

checked AS (
  SELECT
    r.event_name,
    r.param_key,
    r.expected_type,
    -- (1) parameter ada dan punya nilai (di tipe apa pun)
    EXISTS(
      SELECT 1 FROM UNNEST(e.event_params) p
      WHERE p.key = r.param_key
        AND (p.value.string_value IS NOT NULL OR p.value.int_value   IS NOT NULL
          OR p.value.double_value IS NOT NULL OR p.value.float_value IS NOT NULL)
    ) AS is_present,
    -- (2) nilainya ada di "laci" tipe yang benar
    EXISTS(
      SELECT 1 FROM UNNEST(e.event_params) p
      WHERE p.key = r.param_key
        AND (   (r.expected_type = 'string' AND p.value.string_value IS NOT NULL)
             OR (r.expected_type = 'int'    AND p.value.int_value    IS NOT NULL))
    ) AS is_correct_type
  FROM events e
  JOIN required r ON e.event_name = r.event_name
)

SELECT
  event_name,
  param_key,
  expected_type,
  COUNT(*)                                            AS total_events,
  COUNTIF(is_present)                                 AS present,
  ROUND(100 * COUNTIF(is_present) / COUNT(*), 2)      AS pct_present,
  COUNTIF(is_correct_type)                            AS correct_type,
  ROUND(100 * COUNTIF(is_correct_type) / COUNT(*), 2) AS pct_correct_type
FROM checked
GROUP BY event_name, param_key, expected_type
ORDER BY pct_correct_type, pct_present;
