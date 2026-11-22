# Tracking Plan – Flood-It!

> Trigger merupakan asumsi berdasarkan nama event dan parameter, karena dokumentasi asli tidak tersedia.
> Tipe data yang diharapkan ditetapkan dari hasil eksplorasi (`sql/00_exploration/03_event_params.sql`).

## Kategori
- **Otomatis**: dikirim oleh Firebase SDK tanpa kode tambahan.
- **Recommended**: event standar Firebase yang dipasang developer.
- **Custom**: event buatan developer khusus untuk aplikasi ini.

## Event inti

| Event | Kategori | Trigger | Parameter wajib (tipe yang diharapkan) |
|---|---|---|---|
| `first_open` | Otomatis | Pengguna membuka aplikasi pertama kali setelah install | – |
| `session_start` | Otomatis | Pengguna memulai sesi baru | – |
| `screen_view` | Otomatis | Pengguna pindah layar | `firebase_screen_class` (string), `firebase_screen_id` (int) |
| `user_engagement` | Otomatis | Aplikasi aktif di layar | `engagement_time_msec` (int) |
| `app_remove` | Otomatis | Pengguna menghapus aplikasi permainan | – |
| `level_start_quickplay` | Custom – Quickplay | Pengguna memulai permainan di mode Quick Play | `board` (string) |
| `level_end_quickplay` | Custom – Quickplay | Pengguna mengakhiri permainan di mode Quick Play | `board` (string) |
| `level_complete_quickplay` | Custom – Quickplay | Pengguna berhasil menyelesaikan papan di mode Quick Play | `board` (string), `value` (int) |
| `level_fail_quickplay` | Custom – Quickplay | Pengguna gagal menyelesaikan papan di mode Quick Play | `board` (string) |
| `level_start` | Custom – Progression | Pengguna memulai level di mode Progression | `level` (int), `level_name` (string) |
| `level_end` | Custom – Progression | Level di mode Progression berakhir (menang atau kalah) | `level` (int), `level_name` (string) |
| `level_complete` | Custom – Progression | Pengguna berhasil menyelesaikan level di mode Progression | `level` (int), `level_name` (string) |
| `level_fail` | Custom – Progression | Pengguna gagal menyelesaikan level di mode Progression | `level` (int), `level_name` (string) |
| `post_score` | Custom | Skor pengguna dikirim setelah level berakhir | `score` (int), `level` (int), `level_name` (string) |
| `select_content` | Recommended | Pengguna memilih mode, level, atau ukuran papan di menu | `content_type` (string), `item_id` (string) |
| `spend_virtual_currency` | Recommended | Pengguna membelanjakan koin virtual untuk membeli item | `item_name` (string), `virtual_currency_name` (string), `value` (int) |
| `use_extra_steps` | Custom | Pengguna menggunakan langkah tambahan saat langkah terakhir habis | `item_name` (string), `value` (int) |
| `ad_reward` | Custom | Pengguna menonton iklan sampai selesai dan mendapat hadiah | `ad_unit_code` (string), `type` (string), `value` (int) |

## Catatan dari eksplorasi
- Data adalah sampel: tepat 50.000 event per hari.
- Ada dua mode permainan: Quickplay (`*_quickplay`, parameter `board`) dan Progression (parameter `level`, `level_name`).
- Parameter `level` dan `score` dikirim dalam dua format: int tanpa `level_name`, atau double dengan `level_name`. Terjadi di Android dan iOS.
- iOS 2.6.30 mengirim `level` sebagai int tanpa `level_name` di semua event `level_start` (diperbaiki di 2.6.31). Android 2.62 mengalami hal sama di ±5% event.
- `select_content.item_id` tidak konsisten huruf besar/kecil (`quickplay` vs `Quickplay`).
- `select_content` mencatat 3 jenis pilihan: mode, level, dan ukuran papan (S/M/L).
