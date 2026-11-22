# 📱 Mobile App Event Data Validation & Product Analytics

> Validasi kualitas data event tracking Firebase dan analisis perilaku pengguna aplikasi mobile menggunakan **BigQuery (SQL)** dan **Looker Studio**.

![status](https://img.shields.io/badge/status-in%20progress-yellow) ![BigQuery](https://img.shields.io/badge/BigQuery-SQL-4285F4) ![Looker Studio](https://img.shields.io/badge/Looker%20Studio-Dashboard-669DF6) ![Firebase](https://img.shields.io/badge/Firebase-Analytics-FFCA28)

---

## 📌 Daftar Isi
1. [Latar Belakang](#-latar-belakang)
2. [Masalah yang Diangkat](#-masalah-yang-diangkat)
3. [Tujuan Project](#-tujuan-project)
4. [Dataset](#-dataset)
5. [Tech Stack](#-tech-stack)
6. [Alur Project](#-alur-project)
7. [Tahapan Pengerjaan](#-tahapan-pengerjaan)
8. [Data Model](#-data-model)
9. [Definisi Metrik](#-definisi-metrik)
10. [Dashboard](#-dashboard)
11. [Hasil & Insight](#-hasil--insight)
12. [Rekomendasi](#-rekomendasi)
13. [Keterbatasan](#-keterbatasan)
14. [Relevansi ke Aplikasi Streaming / OTT](#-relevansi-ke-aplikasi-streaming--ott)
15. [Struktur Repository](#-struktur-repository)
16. [Cara Menjalankan](#-cara-menjalankan)

---

## 🧭 Latar Belakang

*Flood-It!* adalah game puzzle mobile (Android & iOS) yang mengirim setiap aktivitas pengguna ke **Firebase Analytics**: membuka aplikasi, memulai level, menyelesaikan level, memakai item, hingga menonton iklan. Data mentah ini diekspor ke **BigQuery** dalam format *nested* (satu baris per event, dengan detail di kolom `event_params`).

Tim produk ingin memahami **di mana pengguna berhenti bermain dan mengapa retensi turun**. Namun keputusan produk hanya bisa diambil jika **data tracking-nya dapat dipercaya**. Event yang hilang, duplikat, atau parameter yang kosong dapat menghasilkan insight yang salah.

## ❓ Masalah yang Diangkat

**Bagian A: Kualitas data (Data Validation)**
1. Apakah semua event terkirim dengan parameter yang lengkap dan tipe data yang benar?
2. Apakah ada event duplikat atau urutan event yang tidak logis (misalnya `level_end` tanpa `level_start`)?
3. Apakah ada versi aplikasi atau platform yang tracking-nya rusak (volume event tiba-tiba turun)?

**Bagian B: Perilaku pengguna (Product Analytics)**
1. Berapa pengguna aktif harian/bulanan, dan seberapa "lengket" aplikasinya?
2. Berapa persen pengguna baru yang kembali di hari ke-1, ke-7, dan ke-30?
3. Di tahap mana pengguna paling banyak berhenti (funnel drop-off)?
4. Apakah ada perbedaan perilaku antar platform, negara, dan versi aplikasi?

## 🎯 Tujuan Project

| # | Tujuan | Output |
|---|---|---|
| 1 | Mendokumentasikan event & parameter yang dikirim aplikasi | **Tracking plan** (`docs/tracking_plan.md`) |
| 2 | Membuktikan data layak dipakai sebelum dianalisis | **Data quality report** per event |
| 3 | Mengubah data nested menjadi tabel analitik yang rapi | Tabel **staging & mart** di BigQuery |
| 4 | Menjawab pertanyaan produk dengan metrik yang jelas | Analisis retention, funnel, engagement |
| 5 | Menyajikan hasil untuk stakeholder non-teknis | **Dashboard Looker Studio** + rekomendasi |

## 🗂 Dataset

| Item | Keterangan |
|---|---|
| Sumber | Google BigQuery public dataset |
| Tabel | `firebase-public-project.analytics_153293282.events_*` |
| Aplikasi | *Flood-It!* (Android & iOS) |
| Periode | ± Juni–Oktober 2018 (*sharded* per hari: `events_YYYYMMDD`) |
| Granularitas | 1 baris = 1 event oleh 1 pengguna pada 1 waktu |
| Skema | Firebase / GA4 export standar |

Kolom utama:

| Kolom | Tipe | Isi |
|---|---|---|
| `event_date`, `event_timestamp` | STRING, INT64 | Waktu event |
| `event_name` | STRING | Jenis aktivitas |
| `event_params` | ARRAY<STRUCT> | Detail aktivitas (key–value, perlu `UNNEST`) |
| `user_pseudo_id` | STRING | ID pengguna anonim |
| `user_properties` | ARRAY<STRUCT> | Atribut pengguna |
| `device`, `geo`, `app_info` | STRUCT | Perangkat, lokasi, versi aplikasi |
| `platform` | STRING | ANDROID / IOS |

## 🛠 Tech Stack

| Tools | Kegunaan |
|---|---|
| **BigQuery (SQL)** | Eksplorasi, validasi, transformasi, agregasi |
| **Looker Studio** | Dashboard interaktif |
| **Firebase Analytics** | Sumber data event |
| **Google Tag Manager + GA4** *(opsional)* | Praktik implementasi & testing event tracking |
| **GitHub** | Dokumentasi & version control |

## 🔄 Alur Project

```mermaid
flowchart TD
    A["Raw Firebase Events<br/>events_* (nested)"] --> B["1. Eksplorasi<br/>event & parameter apa saja"]
    B --> C["2. Tracking Plan<br/>dokumentasi event & params"]
    C --> D["3. Data Validation<br/>completeness, duplikat,<br/>urutan, tipe data, anomali"]
    D --> E{"Data layak<br/>dipakai?"}
    E -- "Tidak" --> F["Catat issue +<br/>aturan cleaning"]
    F --> G
    E -- "Ya" --> G["4. Staging<br/>stg_events (flatten / UNNEST)"]
    G --> H["5. Data Mart<br/>fct_sessions, fct_daily_users,<br/>fct_level_funnel, dim_users"]
    H --> I["6. Analisis<br/>DAU/MAU, retention,<br/>funnel, segmentasi"]
    H --> J["7. Dashboard<br/>Looker Studio"]
    I --> K["8. Insight &<br/>Rekomendasi"]
    J --> K

    L["(Opsional) GTM + GA4<br/>di website demo"] -.-> M["Preview Mode &<br/>DebugView testing"]
    M -.-> C
```

## 🧱 Tahapan Pengerjaan

### 1. Eksplorasi data
- Rentang tanggal, jumlah pengguna, jumlah event.
- Daftar `event_name` beserta frekuensinya.
- Daftar `key` di `event_params` per event beserta tipe nilainya (`string_value` / `int_value` / `double_value`).

### 2. Tracking plan
Dokumen yang menjelaskan setiap event: kapan dipicu, parameter apa yang wajib, dan tipe datanya. Menjadi **acuan** untuk validasi di tahap berikutnya.

| event_name | Trigger | Parameter wajib | Tipe |
|---|---|---|---|
| `first_open` | Pertama kali aplikasi dibuka setelah install | – | – |
| `session_start` | Sesi baru dimulai | – | – |
| `level_start_quickplay` | Pengguna memulai level | `level_name` | STRING |
| `level_end_quickplay` | Level berakhir | `level_name` | STRING |
| `post_score` | Skor dicatat | `score`, `level_name` | INT, STRING |
| … | … | … | … |

*Nama event final disesuaikan dengan hasil eksplorasi.*

### 3. Data validation
| Cek | Pertanyaan | Contoh logika SQL |
|---|---|---|
| **Completeness** | Parameter wajib kosong? | `COUNTIF(level_name IS NULL) / COUNT(*)` per event |
| **Uniqueness** | Ada event duplikat? | `GROUP BY user_pseudo_id, event_name, event_timestamp HAVING COUNT(*) > 1` |
| **Validity** | Tipe nilai sesuai? Nilai masuk akal? | `score < 0`, nilai di kolom tipe yang salah |
| **Sequence** | Urutan event logis? | `level_end` tanpa `level_start` sebelumnya di sesi yang sama |
| **Consistency** | Pengguna punya `first_open`? | Pengguna aktif tanpa event `first_open` |
| **Anomaly** | Volume event wajar per versi/platform? | Event harian per `app_info.version`, cari penurunan tajam |

Output: tabel **data quality scorecard** (event × jenis cek × % lolos).

### 4–5. Transformasi (staging → mart)
Mengubah data nested menjadi tabel datar yang siap dianalisis dan dihubungkan ke Looker Studio (lihat [Data Model](#-data-model)).

### 6. Analisis
- **Engagement**: DAU, WAU, MAU, stickiness, durasi sesi, sesi per pengguna.
- **Retention**: cohort mingguan berdasarkan tanggal `first_open`, D1/D7/D30.
- **Funnel**: `first_open` → `level_start` → `level_end` → `post_score`, serta drop-off per level.
- **Segmentasi**: platform, negara, versi aplikasi.

### 7. Dashboard
Dibangun di Looker Studio dengan sumber tabel mart BigQuery.

### 8. Insight & rekomendasi
Diringkas dalam bahasa bisnis di bagian [Hasil & Insight](#-hasil--insight).

## 🧩 Data Model

```mermaid
erDiagram
    stg_events {
        date event_date
        timestamp event_ts
        string user_pseudo_id
        int session_number
        string event_name
        string level_name
        int score
        string platform
        string app_version
        string country
    }
    dim_users {
        string user_pseudo_id PK
        date first_open_date
        string first_platform
        string first_country
        string first_app_version
    }
    fct_sessions {
        string session_key PK
        string user_pseudo_id FK
        timestamp session_start
        int session_duration_sec
        int events_count
        int levels_played
    }
    fct_daily_users {
        date event_date
        string user_pseudo_id FK
        int sessions
        int events
        int days_since_install
    }
    fct_level_funnel {
        string level_name
        int users_started
        int users_ended
        float completion_rate
    }
    dim_users ||--o{ fct_sessions : has
    dim_users ||--o{ fct_daily_users : has
    stg_events ||--o{ fct_sessions : builds
    stg_events ||--o{ fct_level_funnel : builds
```

## 📏 Definisi Metrik

| Metrik | Definisi |
|---|---|
| **DAU / MAU** | Jumlah `user_pseudo_id` unik yang punya minimal 1 event dalam sehari / 30 hari |
| **Stickiness** | DAU ÷ MAU, makin tinggi makin sering pengguna kembali |
| **Dn Retention** | % pengguna dari cohort `first_open` yang aktif tepat di hari ke-n setelah install |
| **Session** | Rangkaian event satu pengguna tanpa jeda tidak aktif lebih dari 30 menit (`ga_session_id` belum tersedia di dataset 2018) |
| **User completion rate** | Pengguna yang pernah `level_complete` ÷ pengguna yang pernah `level_start` di level tersebut |
| **Win rate** | `level_complete` ÷ (`level_complete` + `level_fail`) |
| **Reach** | Pengguna yang memulai level n ÷ pengguna yang memulai level 1 |
| **Data quality pass rate** | % baris event yang lolos semua cek validasi |

## 📊 Dashboard

| Halaman | Isi |
|---|---|
| **1. Data Health** | Scorecard kualitas data, volume event harian per versi/platform, daftar issue |
| **2. Overview** | DAU/MAU, stickiness, pengguna baru, sesi per pengguna |
| **3. Retention** | Cohort heatmap, kurva D1/D7/D30 |
| **4. Funnel & Level** | Funnel utama, completion rate per level, titik drop-off |
| **5. Segmentasi** | Perbandingan platform, negara, versi aplikasi |

🔗 *Link dashboard: (diisi setelah publish)*

## 💡 Hasil & Insight

> Angka dihitung dari data sampel (50.000 event/hari). Angka absolut lebih kecil dari aslinya, tetapi pola dan perbandingan antar segmen tetap dapat dipakai. Detail kualitas data: [`docs/data_quality_report.md`](docs/data_quality_report.md).

### A. Kualitas data

1. **Rilis iOS 2.6.30 merusak tracking.** Versi ini tidak mengirim `level_complete` di mode Progression (0 dari 4.772 level selesai), menghilangkan `level_name`, dan membuat `level_end` Quickplay tidak sama dengan `complete + fail` (selisih 19%). Semua diperbaiki di iOS 2.6.31.
2. **7 hari data anomali** (18 Juni – 1 Juli): `screen_view` hilang dari sampel sehingga DAU tampak melonjak ×2,5. Tanpa koreksi, MAU rolling terlihat "turun" 40% di akhir Juli padahal tidak ada pengguna yang hilang.
3. Selain itu data **cukup sehat**: duplikat < 0,02%, dan parameter wajib di event Quickplay, monetisasi, dan event otomatis 100% lengkap.

### B. Perilaku pengguna

**1. Hari pertama adalah titik kehilangan terbesar**

| Hari setelah install | Masih aktif |
|---|---|
| D1 | 21,5% |
| D7 | 5,5% |
| D30 | 2,1% |

78% pengguna baru tidak kembali setelah hari pertama, dan hanya 45,6% yang pernah kembali di hari lain. Setelah D7 kurva mendatar di 2–3% (pemain inti).

**2. Level 5–10 adalah "tembok kesulitan" mode Progression**

| Level | Win rate | Reach (vs level 1) |
|---|---|---|
| 1–4 | 94–100% | 100% → 72% |
| **5–10** | **38–62%** | **65% → 28%** |
| 11–17 | 86–100% | ±25% (stabil) |

Hanya 1 dari 4 pemain Progression yang mencapai level 11. Pemain yang lolos level 10 hampir tidak hilang lagi. Level 27 dan 29 juga sangat sulit (win rate 8% dan 11%).

**3. Quickplay lebih sulit untuk pemula dibanding Progression**

| Mode | Pengguna baru yang mencoba | Yang pernah menang (dari yang mencoba) |
|---|---|---|
| Quickplay | 70,0% | 46% |
| Progression | 51,8% | 89% |

Papan Quickplay L hanya dimenangkan 32% percobaan, papan S 65%.

**4. Fitur bantuan jarang dipakai**
Hanya 28,2% pengguna baru memakai item (langkah tambahan / koin) dan **3,1% menonton iklan reward**, padahal pemain paling sering kalah di level 5–10.

**5. Retensi D1 turun ±10 poin sejak cohort 27 Agustus 2018**

| Segmen | D1 sebelum | D1 sesudah |
|---|---|---|
| Android | 26,5% | 15,1% |
| iOS | 22,9% | 14,9% |
| Amerika Serikat | 28,2% | 12,6% |
| Android 2.62 (versi sama) | 26,6% | 15,7% |

Penurunan terjadi di **semua** platform, negara, dan versi. Pergeseran komposisi pengguna hanya menjelaskan ±0,5 dari 10,5 poin, bukan disebabkan rilis aplikasi, dan tidak ada sumber akuisisi baru. Dugaan tersisa: musim (masuk sekolah di AS, penurunan terbesar −15,6 poin) atau efek sampling. **Belum dapat dipastikan dari data ini.**

**6. Engagement per hari aktif menurun**
Stickiness (DAU ÷ MAU bulanan) turun dari 15,3% (Juni) ke 8,4% (September), dan waktu bermain per hari aktif turun dari 13,0 ke 10,3 menit, sementara rata-rata sesi tetap ±1,5 per hari.

**7. Perbedaan antar negara**
India menyumbang 17–19% pengguna baru, tetapi waktu bermainnya paling rendah (3,9 menit per hari aktif, vs 7,1 menit di AS dan Jepang). Jepang memiliki retensi dan engagement paling stabil.

## ✅ Rekomendasi

| # | Masalah | Bukti | Aksi | Metrik yang dipantau |
|---|---|---|---|---|
| 1 | Tracking rusak lolos ke produksi | iOS 2.6.30: `level_complete` = 0 | Wajibkan **QA tracking sebelum rilis** (Firebase DebugView + checklist dari tracking plan), dan pasang **alert harian** jika volume event inti per versi turun tajam | % event lolos validasi per versi |
| 2 | Pemain berhenti di level 5–10 | Win rate 38–62%; 58% pemain yang mencapai level 5 berhenti sebelum level 11 | **Turunkan kesulitan level 5–9**, atau beri langkah tambahan gratis setelah 2× kalah | Reach level 11, D7 retention |
| 3 | Pemula kesulitan di Quickplay | Win 46% vs 89% di Progression | **Arahkan pengguna baru ke Progression** di sesi pertama; Quickplay papan L dibuka setelah level tertentu | D1 retention, % pengguna baru yang menang di sesi pertama |
| 4 | Iklan reward hampir tidak dipakai | 3,1% pengguna baru | **Tawarkan iklan reward tepat saat pemain kalah** di level sulit (5–10, 27, 29) | % pengguna yang menonton iklan, win rate setelah iklan |
| 5 | D1 turun sejak akhir Agustus | −10 poin di semua segmen | Ulangi analisis dengan **data lengkap (tanpa sampling)** dan bandingkan dengan tahun sebelumnya untuk memastikan efek musim | D1 per cohort mingguan |

Rekomendasi 2–4 sebaiknya diuji dengan **A/B test** sebelum diterapkan ke semua pengguna.

## ⚠️ Keterbatasan
- Dataset adalah **sampel publik** dari satu game pada tahun 2018, bukan data produksi terkini.
- Data **dipotong tepat 50.000 event per hari**. Angka absolut (DAU, jumlah event) lebih kecil dari aslinya, sebagian urutan event terpotong, dan komposisi platform per hari ikut dipengaruhi cara sampling.
- Data revenue sangat sedikit (27 `in_app_purchase`) dan atribusi kampanye hanya tersedia untuk sebagian pengguna Android.
- `user_pseudo_id` berbasis instalasi aplikasi, sehingga satu orang dengan dua perangkat terhitung dua pengguna.
- Validasi dilakukan pada data hasil export. Pengujian langsung di aplikasi (Firebase DebugView) tidak dapat dilakukan karena tidak ada akses ke aplikasi aslinya. Sebagai gantinya, praktik testing dilakukan di website demo dengan GTM + GA4 *(opsional)*.

## 📺 Relevansi ke Aplikasi Streaming / OTT

Struktur data Firebase sama untuk semua jenis aplikasi. Hanya nama event yang berbeda:

| Game (dataset ini) | Aplikasi streaming |
|---|---|
| `level_start` | `video_play` |
| `level_end` | `video_complete` |
| `level_name` | `content_title`, `content_id` |
| `use_extra_steps` | `skip_ad`, `subscribe_click` |
| Completion rate per level | Completion rate per konten / episode |
| Retention pemain | Retention penonton |

## 📁 Struktur Repository

```
firebase-product-analytics/
├── README.md
├── docs/
│   ├── tracking_plan.md
│   ├── data_quality_report.md
│   └── images/                 # screenshot dashboard, diagram
├── sql/
│   ├── 00_exploration/
│   ├── 01_validation/
│   ├── 02_staging/
│   ├── 03_marts/
│   └── 04_analysis/
└── gtm_demo/                   # (opsional) website demo + screenshot testing
```

## ▶️ Cara Menjalankan
1. Buka [BigQuery Console](https://console.cloud.google.com/bigquery) dan aktifkan **BigQuery Sandbox** (gratis).
2. Buat dataset sendiri, misalnya `flood_it_analytics`, untuk menyimpan tabel staging dan mart.
3. Jalankan file SQL secara berurutan: `00_exploration` → `01_validation` → `02_staging` → `03_marts` → `04_analysis`.
4. Hubungkan Looker Studio ke tabel di `flood_it_analytics`.

---

👤 **Author:** *(nama kamu)* · [LinkedIn](#) · [Email](#)
