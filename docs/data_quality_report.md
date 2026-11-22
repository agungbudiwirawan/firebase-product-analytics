# Data Quality Report – Flood-It! Firebase Events

> Periode data: 12 Juni – 3 Oktober 2018 · 15.175 pengguna · 5,7 juta event
> Acuan validasi: [`docs/tracking_plan.md`](tracking_plan.md) · Query: [`sql/01_validation/`](../sql/01_validation/)

## Ringkasan Eksekutif

- **Rilis iOS 2.6.30 merusak tracking.** Versi ini tidak mengirim `level_complete` di mode Progression, menghilangkan `level_name`, dan membuat `level_end` Quickplay tidak sama dengan `complete + fail`. Semua masalah ini sudah diperbaiki di iOS 2.6.31.
- **7 hari data anomali** (18–19, 25–26, 28, 30 Juni, dan 1 Juli). Sebagian besar `screen_view` hilang dari sampel, sehingga DAU terlihat melonjak ×2,5. Lonjakan ini **bukan pertumbuhan nyata**.
- **Duplikat sangat kecil** (< 0,02%) dan semua parameter wajib di event Quickplay, monetisasi, dan event otomatis **100% lengkap**.
- Data adalah **sampel 50.000 event per hari**, sehingga jumlah absolut tidak mewakili volume asli dan sebagian urutan event bisa terpotong.

## Scorecard

| # | Temuan | Cek | Dampak | Tingkat |
|---|---|---|---|---|
| 1 | iOS 2.6.30 tidak mengirim `level_complete` (Progression) | 04b | Win rate Progression iOS 2.6.30 tidak bisa dihitung | 🔴 Tinggi |
| 2 | `level_name` hilang di 10–12% event Progression; `level` dikirim sebagai int atau double | 01 | Analisis per level kehilangan data jika memakai `level_name` | 🔴 Tinggi |
| 3 | Quickplay: `level_end` ≠ `complete + fail` di versi lama | 04b | Completion rate Quickplay bias di versi lama | 🟠 Sedang |
| 4 | 7 hari anomali: `screen_view` hilang, DAU melonjak | 05 | Tren DAU dan metrik layar salah di hari tersebut | 🟠 Sedang |
| 5 | `post_score` dikirim di kedua mode, tapi parameternya khas Progression; 15% terkirim beruntun | 03b | Skor Quickplay sulit diinterpretasi | 🟠 Sedang |
| 6 | Urutan `start → end` valid hanya 42–45% (Progression) dan 72% (Quickplay) | 03a | Funnel tidak bisa dihitung dengan memasangkan event | 🟡 Perlu konteks |
| 7 | Komposisi platform harian berubah drastis (iOS 23–89%) | 05 | Perbandingan platform per hari tidak andal | 🟡 Efek sampling |
| 8 | Event muncul sebelum `first_open` | 04a, 06 | Tidak berdampak pada cohort harian | 🟢 Rendah |
| 9 | Duplikat persis ±190 baris | 02 | Tidak signifikan | 🟢 Rendah |
| 10 | `use_extra_steps.value` selalu double | 01 | Ekspektasi tracking plan yang perlu diperbarui, bukan bug | 🟢 Rendah |

## Detail Temuan

### 1. iOS 2.6.30 tidak mengirim `level_complete` (Progression)
| Platform | Versi | `level_end` | `level_complete` | `level_fail` | Selisih |
|---|---|---|---|---|---|
| iOS | 2.6.30 | 4.772 | **0** | 1.632 | **3.140** |
| iOS | 2.6.31 | 7.516 | 4.910 | 2.606 | 0 |
| Android | 2.62 | 39.695 | 27.316 | 12.324 | 55 |

Di iOS 2.6.30, pemain yang menang hanya tercatat sebagai `level_end`. Masalah ini hilang di 2.6.31.

### 2. `level_name` hilang dan tipe `level` tidak konsisten
| Event | % `level_name` terisi | % `level` sebagai int |
|---|---|---|
| `level_start` | 88,24% | 11,76% |
| `level_end` | 88,07% | 11,93% |
| `level_fail` | 88,54% | 11,46% |
| `post_score` | 90,11% | 9,89% |

- Event yang mengirim `level` sebagai **int selalu tanpa `level_name`**. Event yang mengirim double selalu dengan `level_name`.
- Per versi: iOS 2.6.30 → 100% int; iOS 2.6.31 → 100% double; Android 2.62 → ±5% int.
- Tren harian: persentase `level_start` tanpa nama tinggi di Juni (30–58%) dan turun ke hampir 0% di akhir September, seiring pengguna beralih ke iOS 2.6.31.
- `level_complete`: 3,7% event tidak membawa `level` maupun `level_name`.

### 3. Quickplay: `level_end` ≠ `complete + fail`
| Platform | Versi | Selisih | % dari `level_end` |
|---|---|---|---|
| iOS | 2.6.30 | 10.226 | 19,2% |
| Android | 2.62 | 7.863 | 5,2% |
| iOS | 2.6.27 | 1.293 | 5,4% |
| iOS | 2.6.31 | 13 | 0,0% |

Selisih ada di hampir semua versi lama dan hilang di iOS 2.6.31.

### 4. Tujuh hari anomali
| Metrik | Hari normal | Hari anomali |
|---|---|---|
| DAU | ±450 | ±1.200 |
| Event per pengguna | ±110 | ±40 |
| % `screen_view` | ±41% | 3,5–14% |
| % `user_engagement` | ±23% | 31–43% |

Tanggal: 2018-06-18, 06-19, 06-25, 06-26, 06-28, 06-30, 07-01.

### 5. `post_score` di kedua mode
| Event sebelum `post_score` | % |
|---|---|
| `level_end_quickplay` | 37,4% |
| `level_complete_quickplay` | 29,5% |
| `post_score` | 15,3% |
| `level_end` | 6,2% |
| `level_complete` | 5,3% |
| `level_fail_quickplay` | 4,9% |
| Lainnya | 1,4% |

Sekitar 72% `post_score` dikirim setelah event Quickplay, padahal parameternya (`level`, `level_name`) hanya relevan untuk Progression.

### 6. Urutan `level_start → level_end`
| Mode | Platform | % valid | End setelah end | Level/papan berbeda |
|---|---|---|---|---|
| Progression | Android | 41,97% | 26,8% | 29,4% |
| Progression | iOS | 44,73% | 25,8% | 27,2% |
| Quickplay | Android | 72,11% | 27,7% | 0,1% |
| Quickplay | iOS | 72,92% | 26,9% | 0,1% |

Bukan otomatis bug. Kemungkinan penyebab: event `start` tidak ikut tersampel, atau pemain memakai retry/reset sehingga `level_end` muncul tanpa `level_start` baru.

### 7. Komposisi platform harian
| Periode | % event iOS |
|---|---|
| 12–17 Juni | ±70% |
| 20 Juni – Agustus | ±23–49% |
| September | 44–89% |

### 8. Event sebelum `first_open`
| Selisih waktu | Pengguna | % |
|---|---|---|
| < 1 menit | 2.459 | 68% |
| 1–60 menit | 1.127 | 31% |
| > 1 hari | 12 | 0,3% |

99,7% selisih di bawah 1 jam, jadi tanggal install tetap akurat. Catatan lain: 10.856 pengguna (72%) tidak punya `first_open` karena sudah install sebelum periode data, dan 3 pengguna punya `first_open` dobel.

### 9. Duplikat
Total ±190 baris duplikat persis (user, event, timestamp, dan parameter identik). Tertinggi: `spend_virtual_currency` 0,011%.

## Aturan Cleaning untuk Staging

| # | Aturan | Menangani temuan |
|---|---|---|
| 1 | Hapus duplikat persis | 9 |
| 2 | `level = COALESCE(int_value, CAST(double_value AS INT64))` | 2 |
| 3 | `LOWER(item_id)` di `select_content` | Eksplorasi |
| 4 | Tambah kolom `mode` (`quickplay` / `progression`) | 5, 6 |
| 5 | `is_anomaly_day = TRUE` untuk 7 tanggal anomali | 4 |
| 6 | `is_known_bad_release = TRUE` untuk iOS 2.6.30 | 1, 2, 3 |
| 7 | Tanggal install = tanggal `first_open` | 8 |
| 8 | `is_install_anomaly = TRUE` untuk selisih > 1 hari | 8 |
| 9 | Funnel dihitung di level pengguna, bukan memasangkan event | 6 |

## Rekomendasi untuk Tim Developer
1. Tambahkan **cek tracking otomatis sebelum rilis** (QA dengan Firebase DebugView) untuk event inti: `level_start`, `level_end`, `level_complete`, `level_fail`.
2. **Standarkan tipe data** `level` dan `score` menjadi integer di semua platform.
3. **Pisahkan `post_score`** per mode, atau tambahkan parameter `mode`.
4. Seragamkan huruf `item_id` (`quickplay` vs `Quickplay`).
5. Perbarui tracking plan: `use_extra_steps.value` bertipe double.

## Keterbatasan
- Data adalah sampel 50.000 event per hari dari dataset publik, sehingga sebagian temuan (urutan, komposisi platform) bisa dipengaruhi cara sampling.
- Tidak ada akses ke kode aplikasi atau dokumentasi tracking asli. Trigger dan parameter wajib adalah asumsi.
