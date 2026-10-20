# Dokumentasi REST API Mobile App - Central Portal

Panduan integrasi REST API Central Portal untuk pengembang aplikasi mobile (**Flutter**, **React Native**, **Kotlin/Android**, atau **Swift/iOS**).

**Terakhir diperbarui:** 20 Oktober 2026

**Perubahan:** penyesuaian kontrak login, penegasan penghentian absensi berbasis selfie/lokasi, penambahan endpoint ringkasan absensi, aturan kesetaraan modul Kinerja dengan web, serta dokumentasi SOP/Dokumen.

**Acuan utama implementasi mobile:** file Markdown ini (`MOBILE_API_DOCUMENTATION.md`). Spesifikasi OpenAPI/YAML bersifat pelengkap teknis dan harus mengikuti keputusan bisnis dalam dokumen ini.

**Spesifikasi Swagger/OpenAPI:** [MOBILE_API_DOCUMENTATION.yaml](MOBILE_API_DOCUMENTATION.yaml)

**URL production:** `https://arqomtechnology.cloud/api/openapi.yaml`

---

## 1. Konsep Dasar & Arsitektur

### 1.1 Base URL
- **Development / Local**: `http://<IP_SERVER_ATAU_HOST>:8000/api`
- **Production**: `https://arqomtechnology.cloud/api`

### 1.2 Headers Wajib
Setiap request wajib menyertakan header berikut:
```http
Accept: application/json
Content-Type: application/json
```
Untuk endpoint yang membutuhkan autentikasi, sertakan token Sanctum:
```http
Authorization: Bearer <ACCESS_TOKEN>
```

### 1.3 Format Respon Standar
Semua endpoint mengembalikan respon JSON terstruktur:
* **Respon Sukses (200 / 201)**:
  ```json
  {
    "status": "success",
    "message": "Pesan deskriptif (opsional)",
    "data": { ... }
  }
  ```
* **Respon Validasi Gagal (422)**:
  ```json
  {
    "status": "error",
    "message": "Pesan kesalahan utama.",
    "errors": {
      "field_name": ["Detail pesan kesalahan validasi."]
    }
  }
  ```
* **Respon Tidak Terautentikasi (401)**:
  ```json
  {
    "message": "Unauthenticated."
  }
  ```

---

## 2. Modul Autentikasi (Auth)

### 2.1 Login Karyawan
Menukarkan kredensial karyawan dengan token akses personal (Sanctum).

* **Endpoint**: `POST /api/login`
* **Auth**: Tidak perlu
* **Request Body**:
  ```json
  {
    "identifier": "karyawan@arqomtechnology.cloud",
    "password": "rahasiaPassword"
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Login berhasil",
    "data": {
      "token": "1|abc12345xyzSanctumTokenGenerated...",
      "user": {
        "id": 12,
        "arqom_global_id": 45,
        "name": "Ahmad Fauzi",
        "email": "ahmad.fauzi@arqomtechnology.cloud",
        "division": "Engineering",
        "position": "Mobile Developer"
      }
    }
  }
  ```

### 2.2 Profil Pengguna Login (Me)
Mengambil informasi lengkap karyawan yang sedang login.

* **Endpoint**: `GET /api/me`
* **Auth**: Wajib (`Bearer Token`)
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": {
      "id": 12,
      "arqom_global_id": 45,
      "name": "Ahmad Fauzi",
      "email": "ahmad.fauzi@arqomtechnology.cloud",
      "division": "Engineering",
      "position": "Mobile Developer"
    }
  }
  ```

### 2.3 Logout
Mencabut (*revoke*) token akses aktif di perangkat.

* **Endpoint**: `POST /api/logout`
* **Auth**: Wajib (`Bearer Token`)
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Berhasil logout."
  }
  ```

---

### 2.4 Dashboard Mobile
Mengambil ringkasan konten portal untuk halaman awal aplikasi. Mulai versi agenda berbasis audiens, respons dashboard juga memiliki properti `agendas` selain `announcements` dan `activities` yang sudah ada.

* **Endpoint**: `GET /api/dashboard`
* **Auth**: Wajib (`Bearer Token`)
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": {
      "announcements": [],
      "activities": [],
      "agendas": [
        {
          "id": 24,
          "title": "Olahraga Bersama",
          "type": "Agenda Lainnya",
          "event_date": "2026-10-24",
          "start_time": "08:00",
          "location": "Lapangan",
          "audience_label": "Semua pegawai aktif",
          "deep_link": "artech://agenda/24"
        }
      ]
    }
  }
  ```

Catatan:

- `agendas` maksimal berisi lima agenda mendatang, diurutkan berdasarkan tanggal dan waktu mulai.
- Agenda di dalam dashboard sudah difilter berdasarkan pengguna yang sedang login. Jangan menggabungkannya dengan data agenda akun lain atau cache lintas akun.
- `activities` dipertahankan untuk kompatibilitas versi aplikasi lama dan bukan pengganti `agendas`.

---

## 3. Modul Absensi & Riwayat Kehadiran (Terintegrasi Mesin FingerSpot & Web Portal)

Sistem presensi Central Portal telah terintegrasi secara *realtime* dengan:
1. **Mesin Absensi Fisik (FingerSpot / ADMS)**: Setiap scan jari/wajah di kantor langsung disinkronkan ke server dan terpetakan ke profil karyawan (`hcga_employees`).
2. **Jadwal Jam Kerja & Kebijakan Kantor (`hcga_work_schedules`)**: Menghitung secara otomatis jam masuk, briefing, toleransi keterlambatan, jam pulang, lembur, dan status alpa.
3. **Pengajuan Terpadu**: Otomatis mengenali Cuti, Izin, Sakit, Perjalanan Dinas, Tugas Lapangan lama, dan Lembur yang sudah berstatus final `Disetujui`, baik diajukan dari web maupun mobile.
4. **Kalender Libur Nasional & Kantor (`hcga_holidays`)**: Akhir pekan dan tanggal merah otomatis ditandai sebagai `Hari Libur`.

#### Aturan dampak pengajuan terhadap absensi

| Status/jenis pengajuan | Dampak pada absensi API |
| :--- | :--- |
| `Menunggu Manager`, `Menunggu HCGA`, `Ditolak`, `Dibatalkan` | Tidak mengubah status absensi. |
| `Disetujui` + `cuti` | Status efektif `Cuti` pada hari kerja dalam rentang tanggal. |
| `Disetujui` + `izin` | Status efektif `Izin` pada hari kerja dalam rentang tanggal. |
| `Disetujui` + `sakit` | Status efektif `Sakit` pada hari kerja dalam rentang tanggal. |
| `Disetujui` + `perjalanan_dinas` / `tugas_lapangan` | Status efektif `Perjalanan Dinas`, termasuk untuk setiap peserta pengajuan kelompok. |
| `Disetujui` + `lembur` | Status efektif `Lembur`, termasuk untuk setiap peserta pengajuan kelompok. |

Catatan penting:

- Cuti, izin, dan sakit tidak mengganti status `Hari Libur` pada akhir pekan atau hari libur kantor/nasional.
- Perjalanan dinas dan lembur dapat berlaku pada hari libur jika tanggal tersebut memang termasuk rentang pengajuan.
- Jika beberapa pengajuan final bertumpuk pada tanggal yang sama, approval final terbaru menjadi status efektif.
- Koreksi manual Admin HCGA (`source: central_manual_edit`) tetap menjadi sumber paling berwenang dan tidak ditimpa oleh pengajuan.
- Integrasi dilakukan saat API membaca data, sehingga pengajuan lama yang sudah final juga langsung dikenali tanpa membuat baris presensi duplikat.

---

### 3.1 Ambil Riwayat Absensi Per Karyawan (Integrated History)
Mengambil kalender dan riwayat presensi harian lengkap beserta status kehadiran dan statistik bulanan.
* **Karyawan Biasa / Head / Manager non-HCGA (SCOPE_PERSONAL)**: Sesuai aturan web portal, hanya dapat mengakses riwayat kehadiran miliknya sendiri. Tidak dapat melihat data karyawan lain.
* **Direksi / HCGA (Manager & Staff) / Superadmin (SCOPE_READ_ALL / SCOPE_MANAGE)**: Dapat melihat riwayat seluruh karyawan perusahaan lintas divisi dengan menyertakan parameter `?employee_id=...`.

* **Endpoint**: `GET /api/attendance/history`
* **Query Parameters (Opsional)**:
  - `month` (`integer`, 1-12): Bulan yang diinginkan (default: bulan berjalan).
  - `year` (`integer`, misal `2026`): Tahun yang diinginkan (default: tahun berjalan).
  - `employee_id` (`integer`, opsional): ID karyawan target (khusus Direksi/HCGA/Superadmin). Jika dipanggil oleh karyawan biasa untuk ID orang lain, akan menghasilkan respon `403 Forbidden`.
  - `status` (`string`, opsional): Filter status tertentu (`"Hadir"`, `"Terlambat"`, `"Belum Absen Pulang"`, `"Izin"`, `"Sakit"`, `"Cuti"`, `"Perjalanan Dinas"`, `"Lembur"`, `"Tidak Hadir"`, `"Hari Libur"`).
  - `order` (`string`, opsional): Urutan tanggal (`"desc"` tanggal terbaru di atas, atau `"asc"`). Default: `"desc"`.
  - `page` & `per_page` (`integer`, opsional): Pengaturan paginasi (default `per_page=31` agar seluruh hari dalam bulan langsung tampil).
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Riwayat absensi berhasil dimuat.",
    "data": {
      "employee": {
        "id": 46,
        "name": "wowo",
        "email": "wowo@arqomtechnology.cloud",
        "division": "Project Management",
        "position": "Manager Machinery Project and Quality",
        "status": "Aktif",
        "join_date": "2026-09-01"
      },
      "period": {
        "month": 10,
        "year": 2026,
        "month_name": "Oktober 2026",
        "days_in_month": 31
      },
      "schedule": {
        "name": "Jam Kerja Utama",
        "check_in_target": "07:50:00",
        "work_start_time": "08:00:00",
        "check_out_time": "17:00:00",
        "late_tolerance_minutes": 15
      },
      "statistics": {
        "Hadir": 4,
        "Terlambat": 3,
        "Belum Absen Pulang": 1,
        "Tidak Hadir": 1,
        "Belum Absen": 0,
        "Sakit": 0,
        "Izin": 0,
        "Cuti": 0,
        "Perjalanan Dinas": 0,
        "Lembur": 0,
        "Hari Libur": 5,
        "total_hadir_dan_dinas": 8,
        "hari_kerja_berlalu": 9,
        "persentase_kehadiran": 88.9
      },
      "history": [
        {
          "id": 774,
          "date": "2026-10-14",
          "day_name": "Rabu",
          "day_code": "RAB",
          "is_today": true,
          "is_weekend": false,
          "is_holiday": false,
          "status": "Terlambat",
          "status_badge": "warning",
          "status_source": "attendance_record",
          "approved_request": null,
          "check_in_at": "2026-10-14T14:04:45+07:00",
          "check_in_time": "14:04:45",
          "check_out_at": "2026-10-14T14:15:11+07:00",
          "check_out_time": "14:15:11",
          "source": "fingerspot_adms",
          "source_label": "Mesin Absensi (FingerSpot)",
          "late_category": "alpha_candidate",
          "late_label": "Kandidat Alpha",
          "late_minutes": 374,
          "early_leave_minutes": 164,
          "notes": "[PIN:10] Sinkronisasi mesin presensi"
        },
        {
          "id": 732,
          "date": "2026-10-13",
          "day_name": "Selasa",
          "day_code": "SEL",
          "is_today": false,
          "is_weekend": false,
          "is_holiday": false,
          "status": "Hadir",
          "status_badge": "success",
          "status_source": "attendance_record",
          "approved_request": null,
          "check_in_at": "2026-10-13T07:48:10+07:00",
          "check_in_time": "07:48:10",
          "check_out_at": "2026-10-13T17:05:22+07:00",
          "check_out_time": "17:05:22",
          "source": "fingerspot_adms",
          "source_label": "Mesin Absensi (FingerSpot)",
          "late_category": "tepat_waktu",
          "late_label": "Tepat Waktu",
          "late_minutes": 0,
          "early_leave_minutes": 0,
          "notes": null
        },
        {
          "id": null,
          "date": "2026-10-11",
          "day_name": "Minggu",
          "day_code": "MIN",
          "is_today": false,
          "is_weekend": true,
          "is_holiday": false,
          "status": "Hari Libur",
          "status_badge": "secondary",
          "status_source": "calendar",
          "approved_request": null,
          "check_in_at": null,
          "check_in_time": null,
          "check_out_at": null,
          "check_out_time": null,
          "source": null,
          "source_label": null,
          "late_category": null,
          "late_label": "Hari Libur",
          "late_minutes": 0,
          "early_leave_minutes": 0,
          "notes": null
        },
        {
          "id": null,
          "date": "2026-10-09",
          "day_name": "Jumat",
          "day_code": "JUM",
          "is_today": false,
          "is_weekend": false,
          "is_holiday": false,
          "status": "Cuti",
          "status_badge": "primary",
          "status_source": "approved_request",
          "approved_request": {
            "id": 31,
            "request_number": "REQ-20261013-153045-321",
            "request_type": "cuti",
            "type_label": "Cuti",
            "description": "Keperluan wisuda saudara",
            "start_date": "2026-10-09",
            "end_date": "2026-10-09",
            "location": null,
            "approved_at": "2026-10-08 15:30:45"
          },
          "check_in_at": null,
          "check_in_time": null,
          "check_out_at": null,
          "check_out_time": null,
          "source": "approved_request",
          "source_label": "Pengajuan Internal Disetujui",
          "late_category": null,
          "late_label": "Cuti",
          "late_minutes": 0,
          "early_leave_minutes": 0,
          "notes": "Keperluan wisuda saudara"
        },
        {
          "id": 373,
          "date": "2026-10-05",
          "day_name": "Senin",
          "day_code": "SEN",
          "is_today": false,
          "is_weekend": false,
          "is_holiday": false,
          "status": "Perjalanan Dinas",
          "status_badge": "purple",
          "status_source": "attendance_record",
          "approved_request": null,
          "check_in_at": "2026-10-05T08:00:00+07:00",
          "check_in_time": "08:00:00",
          "check_out_at": "2026-10-05T17:00:00+07:00",
          "check_out_time": "17:00:00",
          "source": "central_portal",
          "source_label": "Portal Web Central",
          "late_category": "tepat_waktu",
          "late_label": "Tepat Waktu (Dinas Luar)",
          "late_minutes": 0,
          "early_leave_minutes": 0,
          "notes": "Dinas Luar: Quality Control Mesin ke Bengkel Rekanan"
        }
      ],
      "pagination": {
        "current_page": 1,
        "last_page": 1,
        "per_page": 31,
        "total": 14
      }
    }
  }
  ```

Keterangan sumber status:

- `attendance_record`: status berasal dari baris presensi mesin, mobile, web, atau koreksi HCGA.
- `approved_request`: status efektif berasal dari pengajuan final; detailnya tersedia pada objek `approved_request`.
- `calendar`: status berasal dari kalender hari libur.
- `calculated`: status dihitung karena belum/tidak ada presensi.
- `employment_period`: tanggal berada di luar masa kerja pegawai.

Field `approved_request` selalu `null` jika status tidak berasal dari pengajuan. Jika pegawai tetap melakukan scan pada tanggal pengajuan, waktu `check_in_at`/`check_out_at` dan sumber scan tetap dikembalikan, sedangkan `status_source` menjelaskan bahwa status efektif berasal dari pengajuan.

---

### 3.2 Ambil Riwayat Absensi Karyawan Spesifik (Direct URL)
Alternatif langsung untuk mengambil riwayat absensi seorang karyawan berdasarkan ID-nya:

* **Endpoint**: `GET /api/attendance/employee/{employee_id}`
* **Query Parameters (Opsional)**: `?month=10&year=2026&status=Hadir`
* **Respon Sukses (200 OK)**: Struktur respon sama persis dengan `GET /api/attendance/history`.

---

### 3.3 Daftar Karyawan yang Dapat Dipilih (Dropdown Filter Atasan/HCGA)
Digunakan pada aplikasi mobile untuk mengisi opsi *dropdown / picker* pemilihan karyawan saat Direksi, HCGA, atau Superadmin ingin melihat riwayat absensi karyawan lain. Untuk karyawan biasa, endpoint ini hanya mengembalikan profil dirinya sendiri (karena sesuai aturan web, karyawan biasa hanya bisa melihat absensinya sendiri).

* **Endpoint**: `GET /api/attendance/employees`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Daftar karyawan berhasil dimuat.",
    "data": [
      {
        "id": 1,
        "name": "Aditya Ramadhona",
        "email": "adit@arqomtechnology.cloud",
        "division": "Direksi",
        "position": "Direktur",
        "status": "Aktif"
      },
      {
        "id": 46,
        "name": "wowo",
        "email": "wowo@arqomtechnology.cloud",
        "division": "Project Management",
        "position": "Manager Machinery Project and Quality",
        "status": "Aktif"
      }
    ]
  }
  ```

---

### 3.4 Status Presensi Hari Ini (Realtime Status)
Menampilkan status presensi hari ini secara instan, mendeteksi secara *live* apakah karyawan sudah menempelkan jari di mesin FingerSpot atau belum.

* **Endpoint**: `GET /api/attendance/today`
* **Query Params (Opsional)**: `?employee_id=46` (untuk memeriksa status presensi bawahan hari ini)
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Data absensi hari ini berhasil dimuat.",
    "data": {
      "date": "2026-10-14",
      "status": "Terlambat",
      "status_badge": "warning",
      "status_source": "attendance_record",
      "approved_request": null,
      "check_in": {
        "recorded": true,
        "time": "14:04:45",
        "timestamp": "2026-10-14T14:04:45+07:00"
      },
      "check_out": {
        "recorded": true,
        "time": "14:15:11",
        "timestamp": "2026-10-14T14:15:11+07:00"
      },
      "source": "fingerspot_adms",
      "source_label": "Mesin Absensi (FingerSpot)",
      "late_minutes": 374,
      "late_category": "alpha_candidate",
      "late_label": "Kandidat Alpha",
      "notes": "[PIN:10] Sinkronisasi mesin presensi",
      "schedule": {
        "check_in_target": "07:50:00",
        "work_start": "08:00:00",
        "check_out_target": "17:00:00"
      }
    }
  }
  ```

---

### 3.5 Statistik Kehadiran Bulanan (Statistik Terpadu)
Rekapitulasi total kehadiran bulanan (Tepat Waktu, Terlambat, Sakit, Izin, Cuti, Dinas, Alpa, Libur).

Statistik dihitung dari status efektif yang sama dengan riwayat. Karena itu, pengajuan final otomatis masuk ke total `Sakit`, `Izin`, `Cuti`, `Perjalanan Dinas`, atau `Lembur`; pengajuan pending/ditolak/dibatalkan tidak ikut dihitung.

* **Endpoint**: `GET /api/attendance/statistics`
* **Query Params (Opsional)**: `?month=10&year=2026&employee_id=46`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Statistik absensi berhasil dimuat.",
    "data": {
      "employee": {
        "id": 46,
        "name": "wowo",
        "email": "wowo@arqomtechnology.cloud",
        "division": "Project Management",
        "position": "Manager Machinery Project and Quality"
      },
      "period": {
        "month": 10,
        "year": 2026,
        "month_name": "Oktober 2026",
        "days_in_month": 31
      },
      "statistics": {
        "Hadir": 4,
        "Terlambat": 3,
        "Belum Absen Pulang": 1,
        "Tidak Hadir": 1,
        "Belum Absen": 0,
        "Sakit": 0,
        "Izin": 0,
        "Cuti": 0,
        "Perjalanan Dinas": 0,
        "Lembur": 0,
        "Hari Libur": 5,
        "total_hadir_dan_dinas": 8,
        "hari_kerja_berlalu": 9,
        "persentase_kehadiran": 88.9
      }
    }
  }
  ```

---

### 3.6 Ringkasan Kalender dan Absensi Bulanan
Alias untuk mengambil data riwayat, kalender kerja, dan statistik bulanan dalam satu respons. Struktur respons sama dengan `GET /api/attendance/history`.

* **Endpoint**: `GET /api/attendance/summary`
* **Query Params (Opsional)**:
  - `month`: `1`–`12`
  - `year`: `2020`–`2100`
  - `employee_id`: ID karyawan, hanya jika pengguna memiliki hak akses

---

### 3.7 Export Rekapan Absensi ke CSV
Mengunduh rekapan absensi bulanan karyawan dalam format CSV (Excel).

* **Endpoint**: `GET /api/attendance/export?month=10&year=2026` *(opsional: `&employee_id=46`)*
* **Respon**: Berkas unduhan CSV berheader `Tanggal, Hari, Status, Jam Masuk, Jam Pulang, Sumber Presensi, Keterlambatan, Menit Telat, Catatan`.

---

### 3.8 Catatan Penghentian Absensi Selfie dan Lokasi

Absensi mobile yang meminta **kamera selfie**, **foto**, **GPS**, **koordinat**, atau validasi **radius lokasi kantor sudah tidak digunakan** dan tidak boleh diimplementasikan pada aplikasi mobile baru.

Ketentuan implementasi mobile:

- Jangan meminta permission kamera atau lokasi untuk kebutuhan absensi.
- Jangan menampilkan form unggah selfie, peta, jarak dari kantor, atau pesan validasi radius.
- Data kehadiran mobile dibaca dari sumber terintegrasi Central Portal: mesin FingerSpot/ADMS, koreksi resmi Admin HCGA, jadwal kerja, hari libur, dan pengajuan yang telah disetujui.
- Endpoint `POST /api/attendance/check-in` dan `POST /api/attendance/check-out` adalah endpoint **legacy**. Endpoint tersebut masih tercatat di backend untuk kompatibilitas aplikasi lama, tetapi berada di luar kontrak aplikasi mobile baru dan **tidak boleh dipanggil**.
- Jika kemudian diperlukan pencatatan masuk/pulang langsung dari mobile tanpa selfie dan lokasi, kontrak endpoint baru atau perubahan endpoint legacy harus disepakati dan diterapkan terlebih dahulu di backend.

---

## 4. Modul Kinerja Karyawan (Performance - 3 Menu)

Sistem kinerja telah diformulasikan ke dalam **3 Menu Terintegrasi**:

```
[1. Target Bulanan] ---> (Dipecah per pekan) ---> [2. Weekly Plan]
         ^                                               |
         |                                               v
   (Dihitung ulang) <---- [3. Weekly Review] <-----------+
                         (Evaluasi tiap Jumat)
```

### Status kesetaraan dengan web

Mobile harus memakai aturan bisnis dan sumber data yang sama dengan halaman web. Jangan membuat logika pengganti hanya di sisi aplikasi.

| Fitur | Status implementasi mobile | Catatan |
| :--- | :--- | :--- |
| Baca Target Bulanan | Siap | Menggunakan data target yang sama dengan web. |
| Tambah/ubah Target Bulanan | Belum boleh diaktifkan di production | Backend API perlu menyamakan validasi kepemilikan parent dan rentang tanggal dengan web. |
| Baca Weekly Plan | Siap | Menggunakan rencana mingguan yang sama dengan web. |
| Tambah/ubah Weekly Plan | Belum boleh diaktifkan di production | Backend API perlu menyinkronkan Daily Logbook, perpindahan pekan, subtask, dan perlindungan item yang bersumber dari Monthly Target. |
| Weekly Review | Siap | Validasi dan perhitungan progres telah mengikuti alur web. |

Scope versi ini hanya mencakup tiga menu di atas. Dashboard Kinerja, OKR, KPI, Monthly Planning, Work Program, Daily Logbook/Kanban, laporan mingguan/bulanan, dan workflow penguncian yang tersedia di web belum menjadi kontrak API mobile dalam dokumen ini.

---

### MENU 1: Target Bulanan (Monthly Targets)

#### 4.1 Ambil Hierarki Target Bulanan
Mengambil target bulanan bertingkat (`Main Target` ➔ `Weekly Target` ➔ `Daily Target`) beserta statistik progres.

* **Endpoint**: `GET /api/performance/monthly-targets`
* **Query Params (Opsional)**:
  - `year`: `2026`
  - `period`: `Oktober 2026`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": {
      "year": 2026,
      "current_period": "Oktober 2026",
      "available_periods": ["September 2026", "Oktober 2026", "November 2026"],
      "targets": [
        {
          "id": 21,
          "level": "main",
          "title": "Pengembangan Fitur Mobile Absensi & Kinerja",
          "expected_results": "Aplikasi rilis di Play Store & internal tester",
          "status": "in_progress",
          "priority": "high",
          "approval_status": "approved",
          "pic_name": "Ahmad Fauzi",
          "children": [
            {
              "id": 45,
              "parent_id": 21,
              "level": "weekly",
              "title": "Integrasi REST API Kinerja Mingguan",
              "status": "completed",
              "priority": "high",
              "start_date": "2026-10-12",
              "deadline": "2026-10-16",
              "pic_name": "Ahmad Fauzi",
              "children": [
                {
                  "id": 89,
                  "parent_id": 45,
                  "level": "daily",
                  "title": "Membuat endpoint Weekly Review",
                  "status": "completed",
                  "priority": "normal"
                }
              ]
            }
          ]
        }
      ],
      "summary": {
        "total_main": 1,
        "total_weekly": 1,
        "completed_weekly": 1,
        "progress_percent": 100
      }
    }
  }
  ```

#### 4.2 Tambah Target Bulanan
Menambahkan target baru (`main`, `weekly`, atau `daily`). Jika menambahkan level `weekly` atau `daily`, target akan otomatis disinkronkan ke dalam *Weekly Plan*.

Aturan yang wajib sama dengan web sebelum fitur tulis diaktifkan:

- `weekly` wajib mempunyai `parent_id` level `main` dan `start_date`.
- `daily` wajib mempunyai `parent_id` level `weekly` dan `deadline`.
- Parent harus dimiliki pengguna yang sedang login, kecuali akses administrator yang memang diizinkan.
- `deadline` Daily Target harus berada di dalam rentang pekan Weekly Target induk.
- Periode sub-target mengikuti periode parent dan tidak boleh ditentukan berbeda oleh mobile.

* **Endpoint**: `POST /api/performance/monthly-targets`
* **Request Body**:
  ```json
  {
    "year": 2026,
    "level": "main",
    "period": "Oktober 2026",
    "title": "Optimalisasi Performa Database Portal",
    "expected_results": "Query response time di bawah 100ms",
    "priority": "high",
    "status": "not_started",
    "start_date": "2026-10-01",
    "deadline": "2026-10-31",
    "notes": "Fokus pada indexing tabel logs"
  }
  ```
  *(Untuk level `weekly` atau `daily`, sertakan `"parent_id": <ID_PARENT>`)*
* **Respon Sukses (201 Created)**:
  ```json
  {
    "status": "success",
    "message": "Target berhasil ditambahkan.",
    "data": {
      "id": 22,
      "title": "Optimalisasi Performa Database Portal",
      "status": "not_started"
    }
  }
  ```

#### 4.3 Update Target Bulanan
* **Endpoint**: `PATCH /api/performance/monthly-targets/{id}`
* **Request Body** *(hanya kirim field yang ingin diubah)*:
  ```json
  {
    "status": "completed",
    "deadline": "2026-10-25"
  }
  ```

---

### MENU 2: Weekly Plan (Rencana Mingguan)

#### 4.4 Ambil Rencana Pekan Berjalan
Mengambil daftar rencana kerja untuk pekan yang dipilih, lengkap dengan sub-task harian dan target bulanan yang terhubung.

* **Endpoint**: `GET /api/performance/weekly-plan`
* **Query Params (Opsional)**:
  - `week_date`: `2026-10-12` *(tanggal acuan dalam pekan tersebut, default: hari ini)*
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": {
      "week": {
        "start": "2026-10-12",
        "end": "2026-10-18",
        "iso_year": 2026,
        "iso_week": 42,
        "label": "12 Okt – 18 Okt 2026"
      },
      "plans": [
        {
          "id": 14,
          "title": "Rencana Mingguan",
          "approval_status": "draft",
          "execution_status": "in_progress",
          "items": [
            {
              "id": 101,
              "monthly_target_id": 45,
              "monthly_target_title": "Integrasi REST API Kinerja Mingguan",
              "title": "Slicing UI Weekly Review & Integrasi API",
              "details": "Pastikan penanganan offline mode siap",
              "expected_output": "Layar Weekly Review selesai",
              "start_date": "2026-10-12",
              "target_date": "2026-10-16",
              "priority": "high",
              "execution_status": "in_progress",
              "progress_percent": 60,
              "daily_tasks": [
                {
                  "id": 301,
                  "title": "Setup state management form review",
                  "work_date": "2026-10-13",
                  "execution_status": "completed",
                  "progress_percent": 100
                }
              ]
            }
          ]
        }
      ]
    }
  }
  ```

#### 4.5 Tambah Item Rencana Mingguan Mandiri
Menambahkan rencana mandiri di luar target bulanan.

* **Endpoint**: `POST /api/performance/weekly-plan`
* **Request Body**:
  ```json
  {
    "week_date": "2026-10-12",
    "title": "Riset library push notification Firebase",
    "expected_output": "Dokumen perbandingan FCM vs OneSignal",
    "priority": "normal",
    "target_date": "2026-10-15"
  }
  ```

#### 4.6 Update Rincian Rencana Mingguan
Mengubah informasi perencanaan aktivitas (judul, target tanggal, prioritas, keterangan).

> **Penting**: Update progres (`progress_percent`), status pengerjaan (`execution_status`), kendala, dan rencana perbaikan **TIDAK** dilakukan di sini, melainkan terpusat pada **Menu 3: Weekly Review** setiap akhir pekan (Jumat), selaras dengan sistem web.

> **Status integrasi**: Jangan aktifkan aksi ini di production sebelum backend menyinkronkan perubahan tanggal dengan Daily Logbook dan menolak perubahan field sumber untuk item yang berasal dari Monthly Target, sama seperti web.

* **Endpoint**: `PATCH /api/performance/weekly-plan/items/{id}`
* **Request Body** *(opsional, kirim field yang ingin diubah)*:
  ```json
  {
    "title": "Slicing UI Weekly Review & Integrasi API Mobile",
    "details": "Menyelesaikan implementasi handling offline",
    "expected_output": "Layar Weekly Review selesai & terintegrasi",
    "target_date": "2026-10-16",
    "priority": "high"
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Rincian rencana mingguan berhasil diperbarui.",
    "data": {
      "id": 101,
      "title": "Slicing UI Weekly Review & Integrasi API Mobile",
      "target_date": "2026-10-16",
      "priority": "high"
    }
  }
  ```

---

### MENU 3: Weekly Review (Evaluasi Mingguan)

#### 4.7 Ambil Item Evaluasi Akhir Pekan
Diakses oleh karyawan setiap akhir pekan (Jumat) untuk mengevaluasi semua aktivitas yang dikerjakan selama pekan tersebut.

* **Endpoint**: `GET /api/performance/weekly-review`
* **Query Params (Opsional)**:
  - `week_date`: `2026-10-12`
* **Aturan Item Review**:
  - Jika sebuah target mempunyai `sub_items`, yang dapat direview dan dikirim ke endpoint simpan adalah setiap ID di dalam `sub_items`.
  - Target induk ditandai dengan `is_main_plan: true` dan hanya menjadi ringkasan. Status serta progresnya dihitung otomatis dari seluruh sub-target.
  - Jika `sub_items` kosong, ID target tersebut dapat direview secara langsung.
  - `daily_tasks` pada respons Weekly Review merupakan alias kompatibilitas dari `sub_items` untuk aplikasi versi lama. Pengembangan baru disarankan menggunakan `sub_items`.
  - Nilai `summary.total_items`, `completed_items`, dan `average_progress` dihitung dari item yang benar-benar dapat direview, bukan dari target induk dan sub-target secara bersamaan.
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": {
      "week": {
        "start": "2026-10-12",
        "end": "2026-10-18",
        "iso_year": 2026,
        "iso_week": 42,
        "label": "12 Okt – 18 Okt 2026"
      },
      "review_date": "2026-10-16",
      "review_timing": "upcoming",
      "summary": {
        "total_items": 2,
        "completed_items": 1,
        "average_progress": 80
      },
      "plans": [
        {
          "id": 14,
          "title": "Rencana Mingguan",
          "owner_name": "Ahmad Fauzi",
          "execution_status": "in_progress",
          "items": [
            {
              "id": 101,
              "title": "Pengembangan Sistem Kinerja",
              "is_main_plan": true,
              "monthly_target_id": 45,
              "priority": "high",
              "expected_output": "Modul kinerja siap digunakan",
              "execution_status": "in_progress",
              "progress_percent": 60,
              "obstacle": null,
              "improvement_plan": null,
              "sub_items": [
                {
                  "id": 102,
                  "title": "Integrasi API Weekly Review",
                  "monthly_target_id": 46,
                  "priority": "high",
                  "expected_output": "Data review dapat disimpan",
                  "details": null,
                  "start_date": "2026-10-12",
                  "target_date": "2026-10-16",
                  "execution_status": "in_progress",
                  "progress_percent": 60,
                  "obstacle": "Menunggu pengujian aplikasi mobile",
                  "improvement_plan": null,
                  "pic_name": null
                }
              ],
              "daily_tasks": [
                {
                  "id": 102,
                  "title": "Integrasi API Weekly Review",
                  "monthly_target_id": 46,
                  "priority": "high",
                  "expected_output": "Data review dapat disimpan",
                  "details": null,
                  "start_date": "2026-10-12",
                  "target_date": "2026-10-16",
                  "execution_status": "in_progress",
                  "progress_percent": 60,
                  "obstacle": "Menunggu pengujian aplikasi mobile",
                  "improvement_plan": null,
                  "pic_name": null
                }
              ]
            },
            {
              "id": 103,
              "title": "Dokumentasi penggunaan modul",
              "is_main_plan": false,
              "monthly_target_id": null,
              "priority": "normal",
              "expected_output": "Panduan penggunaan tersedia",
              "execution_status": "completed",
              "progress_percent": 100,
              "obstacle": null,
              "improvement_plan": "Perbarui panduan ketika alur berubah",
              "sub_items": [],
              "daily_tasks": []
            }
          ]
        }
      ]
    }
  }
  ```

#### 4.8 Simpan Batch Weekly Review (Simpan Sekaligus)
Mengirimkan pembaruan status dan progres untuk seluruh aktivitas dalam satu request.
* **Aturan Penting**:
  - Gunakan ID dari `sub_items` jika target mempunyai sub-target. Pada contoh respons sebelumnya, kirim ID `102`, bukan ID induk `101`.
  - Target yang tidak mempunyai sub-target dapat disimpan menggunakan ID targetnya sendiri, seperti ID `103` pada contoh.
  - Jika `execution_status` = `completed`, otomatis progres diatur menjadi `100%`, dan karyawan dapat mengisi `improvement_plan`.
  - Jika belum selesai (`in_progress` / `not_started`), karyawan mengisi `obstacle` (kendala yang dihadapi).
  - Sistem di backend otomatis **menghitung ulang** persentase mingguan dan menyinkronkan status target bulanan.
  - Gunakan nilai pada `data.items` dari respons sebagai hasil akhir yang tersimpan di server.

* **Endpoint**: `PATCH /api/performance/weekly-review` *(bisa juga menggunakan `POST`)*
* **Request Body**:
  ```json
  {
    "week_date": "2026-10-12",
    "items": {
      "102": {
        "execution_status": "completed",
        "progress_percent": 100,
        "improvement_plan": "Mulai integrasi lebih awal di awal pekan agar testing lebih maksimal",
        "obstacle": null
      },
      "103": {
        "execution_status": "completed",
        "progress_percent": 100,
        "improvement_plan": "Perbarui panduan ketika alur berubah",
        "obstacle": null
      }
    }
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Weekly Review berhasil disimpan dan status kinerja telah dihitung ulang.",
    "data": {
      "week_date": "2026-10-12",
      "updated_count": 2,
      "items": [
        {
          "id": 102,
          "execution_status": "completed",
          "progress_percent": 100,
          "obstacle": null,
          "improvement_plan": "Mulai integrasi lebih awal di awal pekan agar testing lebih maksimal",
          "updated_at": "2026-10-16 15:30:00"
        },
        {
          "id": 103,
          "execution_status": "completed",
          "progress_percent": 100,
          "obstacle": null,
          "improvement_plan": "Perbarui panduan ketika alur berubah",
          "updated_at": "2026-10-16 15:30:00"
        }
      ]
    }
  }
  ```

* **Respon Target Induk Dikirim Langsung (422 Unprocessable Entity)**:
  ```json
  {
    "message": "Target induk tidak dapat direview langsung. Simpan progres melalui sub-target."
  }
  ```
  Muat ulang data dari endpoint GET, lalu kirim ID yang tersedia di dalam `sub_items`.

---

## 5. Modul Pengajuan (Cuti, Izin, Sakit, Lembur, & Dinas)

Modul ini mengelola seluruh izin dan permohonan ketidakhadiran/tugas khusus karyawan, terhubung langsung ke alur persetujuan (*approval flow*) berjenjang.

### 5.1 Alur Logika Persetujuan (Workflow Logic)
```
[Karyawan Ajukan Permohonan via HP]
                  │
                  ▼
         [Pengecekan Level Role]
         ┌────────┴────────┐
         │                 │
 (Staff / Intern)     (Manager HCGA / Direktur)
         │                 │
         ▼                 ▼
[Menunggu Manager]   [Disetujui Otomatis]
(Atasan Langsung)
         │ (Jika Approve)
         ▼
  [Menunggu HCGA]
 (Verifikasi HCGA)
         │ (Jika Approve)
         ▼
    [Disetujui]
```
1. **Karyawan dengan Manager Divisi** (Staff / Lead / Magang di bawah Manager divisi):
   - Alur: `manager_hcga`
   - Status awal: `Menunggu Manager` (menunggu persetujuan atasan divisi).
   - Jika Manager menyetujui, status naik menjadi `Menunggu HCGA`.
   - Jika Manager menolak, status langsung menjadi `Ditolak`.
2. **Karyawan Langsung di Bawah HCGA / Direktur** (seperti akun *Test User* atau karyawan yang atasannya langsung adalah HCGA / Direksi):
   - Alur: `hcga_only`
   - Approval tahap manager otomatis dilewati (`manager_approval_status: "Dilewati"`).
   - Pengajuan **langsung masuk ke HCGA** dengan status awal: `Menunggu HCGA`.
3. **Karyawan dengan Level Manager**:
   - Alur: `hcga_only` -> pengajuan diteruskan langsung ke Manager HCGA (`Menunggu HCGA`).
4. **Manager HCGA / Direktur / Superadmin**:
   - Alur: `auto_approved` -> langsung berstatus `Disetujui` secara otomatis.

Pengajuan baru berdampak pada absensi setelah status utamanya menjadi final `Disetujui`. Persetujuan Manager tahap pertama yang baru mengubah status menjadi `Menunggu HCGA` belum mengubah absensi. Untuk alur `auto_approved`, dampaknya langsung aktif setelah pengajuan berhasil dibuat.

Setiap objek pengajuan dari endpoint daftar, detail, pembuatan, pembaruan, dan approval memiliki field berikut:

```json
"attendance_impact": {
  "affects_attendance": true,
  "is_effective": false,
  "effective_after_status": "Disetujui",
  "effective_status": "Perjalanan Dinas",
  "start_date": "2026-10-25",
  "end_date": "2026-10-28"
}
```

- `affects_attendance`: tipe pengajuan dikenali oleh modul absensi.
- `is_effective`: dampak sudah aktif karena pengajuan sudah final `Disetujui`.
- `effective_status`: status yang akan/ sedang tampil pada endpoint absensi.

---

### 5.2 Metadata Form Pengajuan & Hak Akses Form
Mobile app wajib memanggil endpoint ini sebelum menampilkan form pengajuan untuk mengetahui:
1. **Hak Akses Tipe Pengajuan (`can_use_elevated_types`)**:
   - **Minimal Level Head** (`Head`, `Lead`, `Manager`, `Manager HCGA`, `Direktur`, `Superadmin`): Mengembalikan `can_use_elevated_types: true` dan dapat mengajukan semua 5 jenis pengajuan (`cuti`, `izin`, `sakit`, `lembur`, `perjalanan_dinas`).
   - **Level Staff & Magang** (`Staff`, `Intern`, `PKL`): Mengembalikan `can_use_elevated_types: false` dan **hanya bisa mengajukan 3 tipe dasar**: `cuti`, `izin`, `sakit`. Jika staff memaksa kirim `lembur` atau `perjalanan_dinas`, API akan menolak dengan **HTTP 403 Forbidden**.
2. **Daftar Pegawai Aktif (`employees`)**:
   - Hanya dimuat jika `can_use_elevated_types: true`. Digunakan untuk memilih peserta pada Perjalanan Dinas (Individu maupun Kelompok).

* **Endpoint**: `GET /api/requests/meta`
* **Respon Sukses (200 OK) - Contoh Akun Level Head / Manager**:
  ```json
  {
    "status": "success",
    "data": {
      "user_role": "head",
      "can_use_elevated_types": true,
      "available_types": [
        { "key": "cuti", "label": "Libur Cuti", "elevated": false },
        { "key": "izin", "label": "Tidak Masuk (Izin)", "elevated": false },
        { "key": "sakit", "label": "Tidak Masuk (Sakit)", "elevated": false },
        { "key": "lembur", "label": "Lembur", "elevated": true },
        { "key": "perjalanan_dinas", "label": "Perjalanan Dinas", "elevated": true }
      ],
      "employees": [
        {
          "id": 1,
          "name": "Ahmad Fauzi",
          "division": "IT & Development",
          "position": "Backend Developer"
        },
        {
          "id": 2,
          "name": "Budi Santoso",
          "division": "Operations",
          "position": "Operational Staff"
        }
      ]
    }
  }
  ```
* **Respon Sukses (200 OK) - Contoh Akun Level Staff / Magang**:
  ```json
  {
    "status": "success",
    "data": {
      "user_role": "staff",
      "can_use_elevated_types": false,
      "available_types": [
        { "key": "cuti", "label": "Libur Cuti", "elevated": false },
        { "key": "izin", "label": "Tidak Masuk (Izin)", "elevated": false },
        { "key": "sakit", "label": "Tidak Masuk (Sakit)", "elevated": false }
      ],
      "employees": []
    }
  }
  ```

---

### 5.3 Pemetaan Kolom Formulir Input (Web vs Mobile API)

Berikut adalah keselarasan 100% antara input form di web portal (`requests_v2.blade.php`) dengan parameter request di API:

| Kolom Form (Web & API) | Tipe Data | Wajib / Opsional | Berlaku Untuk Tipe Pengajuan | Penjelasan / Aturan Validasi |
| :--- | :--- | :--- | :--- | :--- |
| `request_type` | `string` | **Wajib** (jika lewat `/api/requests`) | Semua | `cuti`, `izin`, `sakit` (semua karyawan); `lembur`, `perjalanan_dinas` (**hanya bisa diajukan oleh minimal level Head**) |
| `start_date` | `date (YYYY-MM-DD)` | **Wajib** | Semua | Tanggal mulai izin / sakit / cuti / lembur atau tanggal keberangkatan dinas |
| `end_date` | `date (YYYY-MM-DD)` | *Kondisional* | Lembur, Dinas (Wajib); Izin, Sakit, Cuti (Opsional) | Wajib untuk lembur & dinas. Untuk izin, sakit, dan cuti opsional jika hanya 1 hari, wajib diisi jika berdurasi lebih dari 1 hari (`after_or_equal:start_date`) |
| `start_time` | `time (HH:mm)` | *Kondisional* | Lembur (Wajib); Dinas (Opsional) | Format 24 jam `HH:mm` (contoh: `"17:30"`). Di web: Jam Keberangkatan / Jam Mulai |
| `end_time` | `time (HH:mm)` | *Kondisional* | Lembur (Wajib); Dinas (Opsional) | Format 24 jam `HH:mm`. Untuk lembur harus setelah `start_time` |
| `location` | `string (maks 180)` | *Kondisional* | Perjalanan Dinas (Wajib) | Alamat atau kota tujuan dinas |
| `tipe_waktu` | `string` | *Kondisional* | Perjalanan Dinas (Wajib) | Pilihan radio di web: `'harian'` atau `'menginap'` |
| `tipe_peserta` | `string` | *Kondisional* | Perjalanan Dinas (Wajib) | Pilihan radio di web: `'individu'` atau `'kelompok'` |
| `peserta` / `peserta[]` | `array of integer` | *Kondisional* | Perjalanan Dinas (Wajib), Lembur (Opsional) | Daftar ID pegawai yang ditugaskan (**bisa lintas divisi**). Jika lembur diisi peserta > 1, otomatis dianggap lembur tim/kelompok |
| `description` | `string (maks 2000)` | **Wajib** | Semua | Keterangan / alasan permohonan izin/sakit/cuti atau keperluan lembur/dinas |
| `attachment` | `file (maks 2MB)` | Opsional | Semua | Lampiran bukti (foto surat keterangan dokter/SKD untuk sakit, bukti izin, foto tiket, JPG/PNG/WEBP/PDF) |

> [!TIP]
> **Pemilihan Peserta Lintas Divisi (Lembur & Perjalanan Dinas):**  
> Pengaju (minimal level Head) **bebas memilih karyawan dari divisi mana saja (lintas divisi)**. Endpoint metadata `GET /api/requests/meta` menyediakan daftar seluruh karyawan aktif beserta nama divisinya (`division`) sehingga UI mobile app dapat mengelompokkan atau menampilkan label divisi pada dropdown/picker peserta. Seluruh karyawan yang dipilih akan otomatis menerima pengajuan tersebut di menu riwayat aplikasi mereka.

> [!IMPORTANT]
> **Perbedaan Antara Pengajuan Izin dan Sakit:**  
> - **Tidak Masuk (Izin)** (`request_type: "izin"`): Digunakan ketika karyawan berhalangan hadir karena urusan pribadi, keluarga, administrasi, dsb. Field yang digunakan: `start_date`, `end_date` (opsional jika 1 hari), `description` (alasan izin), dan `attachment` (opsional, jika ada surat/dokumen pendukung).
> - **Tidak Masuk (Sakit)** (`request_type: "sakit"`): Digunakan ketika karyawan berhalangan hadir karena kondisi medis/sakit. Field yang digunakan: `start_date`, `end_date` (opsional jika 1 hari), `description` (penjelasan sakit / diagnosa), dan `attachment` (opsional namun sangat dianjurkan untuk melampirkan Surat Keterangan Dokter / SKD).

---

### 5.4 Ambil Riwayat Pengajuan Sendiri
Mengambil daftar pengajuan yang pernah dibuat oleh karyawan yang login **maupun pengajuan Perjalanan Dinas Kelompok di mana karyawan tersebut terdaftar sebagai peserta**.

> [!NOTE]
> **Otomatis Masuk ke Riwayat Seluruh Anggota Kelompok:**  
> Jika seorang atasan/koordinator membuat pengajuan Perjalanan Dinas dengan `tipe_peserta: "kelompok"`, seluruh pegawai yang dipilih dalam `peserta[]` akan **secara otomatis melihat pengajuan tersebut di menu Riwayat Pengajuan masing-masing**.  
> Anggota kelompok memiliki akses membaca detail lengkap pengajuan (`GET /api/requests/{id}`), namun tombol batalkan (`can_cancel`) hanya aktif bagi pembuat pengajuan (`is_owner: true`).

* **Endpoint**: `GET /api/requests`
* **Query Params (Opsional)**:
  - `status`: Filter status (`Menunggu Manager`, `Menunggu HCGA`, `Disetujui`, `Ditolak`, `Dibatalkan`)
  - `request_type`: Filter tipe (`cuti`, `izin`, `sakit`, `lembur`, `perjalanan_dinas`)
* **Respon Sukses (200 OK) - Contoh Pengajuan Pribadi & Perjalanan Dinas Kelompok**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "id": 20,
        "request_number": "REQ-20261012-140020-511",
        "request_type": "perjalanan_dinas",
        "type_label": "Perjalanan Dinas",
        "title": "Pengajuan Perjalanan Dinas - Budi Santoso",
        "description": "Kunjungan instalasi mesin dan training operator di Surabaya",
        "start_date": "2026-10-25",
        "end_date": "2026-10-28",
        "start_time": "08:00",
        "end_time": "17:00",
        "location": "Surabaya, Jawa Timur",
        "details": {
          "tipe_waktu": "menginap",
          "tipe_peserta": "kelompok",
          "peserta_ids": [2, 54],
          "peserta": [
            {
              "id": 2,
              "name": "Budi Santoso",
              "division": "Operations",
              "position": "Lead Field Engineer"
            },
            {
              "id": 54,
              "name": "Test User",
              "division": "Information Technology",
              "position": "staff it"
            }
          ]
        },
        "attachment_url": null,
        "employee": {
          "name": "Budi Santoso",
          "email": "budi@arqomtechnology.cloud",
          "division": "Operations",
          "position": "Lead Field Engineer"
        },
        "status": "Menunggu Manager",
        "display_status": "MENUNGGU ATASAN",
        "status_class": "bg-orange-50 text-orange-600 border-orange-200",
        "attendance_impact": {
          "affects_attendance": true,
          "is_effective": false,
          "effective_after_status": "Disetujui",
          "effective_status": "Perjalanan Dinas",
          "start_date": "2026-10-25",
          "end_date": "2026-10-28"
        },
        "is_owner": false,
        "is_participant": true,
        "can_cancel": false,
        "approval_flow": "manager_hcga",
        "manager_approval": {
          "status": "Menunggu",
          "approved_by": null,
          "approved_at": null,
          "note": null
        },
        "hcga_approval": {
          "status": "Belum Diproses",
          "approved_by": null,
          "approved_at": null,
          "note": null
        },
        "submitted_at": "2026-10-12 14:00:20"
      }
    ]
  }
  ```

---

### 5.5 Buat Pengajuan Baru

Tersedia **dua metode pemanggilan**:
1. **Endpoint Terpadu**: `POST /api/requests` (menyertakan parameter `request_type`).
2. **Dedicated Endpoints**: Endpoint khusus per jenis pengajuan tanpa perlu menyertakan `request_type`:
   - `POST /api/requests/izin` -> Khusus Tidak Masuk (Izin)
   - `POST /api/requests/sakit` -> Khusus Tidak Masuk (Sakit)
   - `POST /api/requests/cuti` -> Khusus Libur Cuti
   - `POST /api/requests/lembur` -> Khusus Lembur (minimal level Head)
   - `POST /api/requests/perjalanan-dinas` -> Khusus Perjalanan Dinas (minimal level Head)

* **Content-Type**: `multipart/form-data` atau `application/json` (jika tanpa lampiran file)

#### A. Contoh Pengajuan Tidak Masuk (Izin)
* **Endpoint**: `POST /api/requests/izin` (atau `POST /api/requests` dengan `request_type: "izin"`)
* **Payload Request**:
  ```json
  {
    "start_date": "2026-10-20",
    "end_date": "2026-10-21",
    "description": "Izin tidak masuk kerja karena perpanjangan SIM dan keperluan administrasi kependudukan di luar kota"
  }
  ```
* **Respon Sukses (201 Created)**:
  ```json
  {
    "status": "success",
    "message": "Pengajuan berhasil dibuat dan menunggu persetujuan Manager.",
    "data": {
      "id": 22,
      "request_number": "REQ-20261013-090321-190",
      "request_type": "izin",
      "type_label": "Tidak Masuk (Izin)",
      "title": "Pengajuan Tidak Masuk (Izin) - Ahmad Fauzi",
      "description": "Izin tidak masuk kerja karena perpanjangan SIM dan keperluan administrasi kependudukan di luar kota",
      "start_date": "2026-10-20",
      "end_date": "2026-10-21",
      "start_time": null,
      "end_time": null,
      "location": null,
      "details": null,
      "attachment_url": null,
      "employee": {
        "name": "Ahmad Fauzi",
        "email": "ahmad@centralportal.local",
        "division": "IT & Development",
        "position": "Backend Developer"
      },
      "status": "Menunggu Manager",
      "display_status": "MENUNGGU ATASAN",
      "status_class": "bg-orange-50 text-orange-600 border-orange-200",
      "is_owner": true,
      "is_participant": false,
      "can_cancel": true,
      "approval_flow": "manager_hcga",
      "manager_approval": {
        "status": "Menunggu",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "hcga_approval": {
        "status": "Belum Diproses",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "submitted_at": "2026-10-13 09:03:21"
    }
  }
  ```

#### B. Contoh Pengajuan Tidak Masuk (Sakit)
* **Endpoint**: `POST /api/requests/sakit` (atau `POST /api/requests` dengan `request_type: "sakit"`)
* **Payload Request (`multipart/form-data`)**:
  - `start_date`: `"2026-10-22"`
  - `end_date`: `"2026-10-23"`
  - `description`: `"Sakit demam dan flu, disarankan istirahat dokter selama 2 hari"`
  - `attachment`: `[File foto surat dokter: surat_dokter.jpg]`
* **Respon Sukses (201 Created)**:
  ```json
  {
    "status": "success",
    "message": "Pengajuan berhasil dibuat dan menunggu persetujuan Manager.",
    "data": {
      "id": 23,
      "request_number": "REQ-20261013-090332-363",
      "request_type": "sakit",
      "type_label": "Tidak Masuk (Sakit)",
      "title": "Pengajuan Tidak Masuk (Sakit) - Ahmad Fauzi",
      "description": "Sakit demam dan flu, disarankan istirahat dokter selama 2 hari",
      "start_date": "2026-10-22",
      "end_date": "2026-10-23",
      "start_time": null,
      "end_time": null,
      "location": null,
      "details": null,
      "attachment_url": "http://127.0.0.1:8000/storage/requests/surat_dokter.jpg",
      "employee": {
        "name": "Ahmad Fauzi",
        "email": "ahmad@centralportal.local",
        "division": "IT & Development",
        "position": "Backend Developer"
      },
      "status": "Menunggu Manager",
      "display_status": "MENUNGGU ATASAN",
      "status_class": "bg-orange-50 text-orange-600 border-orange-200",
      "is_owner": true,
      "is_participant": false,
      "can_cancel": true,
      "approval_flow": "manager_hcga",
      "manager_approval": {
        "status": "Menunggu",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "hcga_approval": {
        "status": "Belum Diproses",
        "approved_by": null,
        "approved_at": null,
        "note": null
      }
    }
  }
  ```

#### C. Contoh Pengajuan Lembur

> [!IMPORTANT]
> **Aturan Hak Akses Pengajuan Lembur (Sama seperti Perjalanan Dinas):**  
> - Pengajuan lembur **hanya bisa diajukan oleh akun dengan minimal level Head** (Head, Manager, Manager HCGA, Direktur, Superadmin).
> - Akun level Staf atau Magang yang mencoba mengajukan lembur akan ditolak oleh sistem dengan respon **`403 Forbidden`** (*"Pengajuan perjalanan dinas dan lembur hanya bisa diajukan oleh minimal level Head."*).
> - **Dapat Diajukan Untuk Tim/Kelompok**: Seorang Head atau Manager dapat mengajukan lembur untuk dirinya sendiri maupun untuk anggota timnya dengan menyertakan parameter `peserta: [id1, id2, ...]`. Jika `peserta` disertakan, pengajuan lembur akan **otomatis muncul di menu riwayat seluruh anggota tim** yang didaftarkan.
> - **Alur Persetujuan**:
>   - Jika diajukan oleh **Head**: Naik ke **Manager** divisi terlebih dahulu (`Menunggu Manager`), lalu setelah disetujui naik ke **HCGA**.
>   - Jika diajukan oleh **Manager**: Diteruskan langsung ke **HCGA** (`Menunggu HCGA`).
>   - Jika diajukan oleh **Manager HCGA / Direktur / Superadmin**: Disetujui otomatis (`auto_approved`).

* **Endpoint**: `POST /api/requests/lembur` (atau `POST /api/requests` dengan `request_type: "lembur"`)
* **Content-Type**: `application/json` atau `multipart/form-data`
* **Form Fields**:
  - `start_date` (`date`, wajib): Tanggal pelaksanaan lembur (contoh: `"2026-10-28"`).
  - `end_date` (`date`, opsional): Tanggal berakhir lembur (jika kosong, otomatis sama dengan `start_date`).
  - `start_time` (`time`, wajib): Jam mulai lembur format `HH:mm` (contoh: `"17:30"`).
  - `end_time` (`time`, wajib): Jam selesai lembur format `HH:mm` (contoh: `"21:00"`). Harus setelah `start_time`.
  - `description` (`string`, wajib): Rincian pekerjaan/proyek yang dikerjakan saat lembur.
  - `peserta` (`array of integer`, opsional): Daftar ID pegawai yang ditugaskan lembur (jika lembur tim).
  - `attachment` (`file`, opsional): Lampiran bukti/memo tugas lembur (maks 2MB).

* **Contoh Payload Request (Lembur Tim / Kelompok oleh Head)**:
  ```json
  {
    "start_date": "2026-10-28",
    "end_date": "2026-10-28",
    "start_time": "17:30",
    "end_time": "21:00",
    "description": "Lembur tim IT & Development untuk finalisasi rilis sprint modul pengajuan",
    "peserta": [2, 54]
  }
  ```

* **Respon Sukses (201 Created)**:
  ```json
  {
    "status": "success",
    "message": "Pengajuan berhasil dibuat dan menunggu persetujuan Manager.",
    "data": {
      "id": 28,
      "request_number": "REQ-20261013-094123-939",
      "request_type": "lembur",
      "type_label": "Lembur",
      "title": "Pengajuan Lembur - Nur Adinda Guswantoro",
      "description": "Lembur tim IT & Development untuk finalisasi rilis sprint modul pengajuan",
      "start_date": "2026-10-28",
      "end_date": "2026-10-28",
      "start_time": "17:30",
      "end_time": "21:00",
      "location": null,
      "details": {
        "tipe_peserta": "kelompok",
        "peserta_ids": [2, 54],
        "peserta": [
          {
            "id": 2,
            "name": "Budi Santoso",
            "division": "IT & Development",
            "position": "Frontend Developer"
          },
          {
            "id": 54,
            "name": "Test User",
            "division": "IT & Development",
            "position": "staff it"
          }
        ]
      },
      "attachment_url": null,
      "employee": {
        "name": "Nur Adinda Guswantoro",
        "email": "guswan@arqomtechnology.cloud",
        "division": "Engineering,Reaserch and Development",
        "position": "Lead Engineering,Reaserch and Development"
      },
      "status": "Menunggu Manager",
      "display_status": "MENUNGGU ATASAN",
      "status_class": "bg-orange-50 text-orange-600 border-orange-200",
      "is_owner": true,
      "is_participant": false,
      "can_cancel": true,
      "approval_flow": "manager_hcga",
      "manager_approval": {
        "status": "Menunggu",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "hcga_approval": {
        "status": "Belum Diproses",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "submitted_at": "2026-10-13 09:41:23"
    }
  }
  ```

---

### 5.6 Perbarui / Edit Pengajuan (Selama Masih Pending)
Karyawan dapat memperbarui informasi pengajuan miliknya (misalnya menambahkan lampiran surat dokter yang baru diperoleh, atau merubah durasi tanggal dan keterangan) selama statusnya belum diproses oleh atasan/HCGA.

* **Endpoint**: `PUT /api/requests/{id}` atau `PATCH /api/requests/{id}`
* **Content-Type**: `multipart/form-data` atau `application/json`
* **Form Fields**: Sama seperti saat membuat pengajuan baru.
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Pengajuan berhasil diperbarui.",
    "data": {
      "id": 23,
      "request_number": "REQ-20261013-090332-363",
      "request_type": "sakit",
      "type_label": "Tidak Masuk (Sakit)",
      "title": "Pengajuan Tidak Masuk (Sakit) - Ahmad Fauzi",
      "description": "Sakit demam tinggi dan tipes, istirahat dokter diperpanjang 3 hari",
      "start_date": "2026-10-22",
      "end_date": "2026-10-24",
      "status": "Menunggu Manager",
      "display_status": "MENUNGGU ATASAN"
    }
  }
  ```

---

### 5.7 Detail Pengajuan
Mengambil detail satu pengajuan secara lengkap berdasarkan ID (termasuk riwayat catatan persetujuan atasan & HCGA).

* **Endpoint**: `GET /api/requests/{id}`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": {
      "id": 18,
      "request_number": "REQ-20261012-083015-412",
      "request_type": "cuti",
      "type_label": "Libur Cuti",
      "title": "Pengajuan Cuti - Ahmad Fauzi",
      "description": "Cuti tahunan keperluan keluarga di luar kota",
      "start_date": "2026-10-20",
      "end_date": "2026-10-22",
      "start_time": null,
      "end_time": null,
      "location": null,
      "details": null,
      "attachment_url": null,
      "employee": {
        "name": "Ahmad Fauzi",
        "email": "ahmad@centralportal.local",
        "division": "IT & Development",
        "position": "Backend Developer"
      },
      "status": "Menunggu Manager",
      "display_status": "MENUNGGU ATASAN",
      "status_class": "bg-orange-50 text-orange-600 border-orange-200",
      "can_cancel": true,
      "approval_flow": "manager_hcga",
      "manager_approval": {
        "status": "Menunggu",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "hcga_approval": {
        "status": "Menunggu",
        "approved_by": null,
        "approved_at": null,
        "note": null
      },
      "submitted_at": "2026-10-12 08:30:15"
    }
  }
  ```

---

### 5.8 Batalkan Pengajuan
Karyawan dapat membatalkan pengajuan miliknya selama statusnya masih menunggu (*pending*).

* **Endpoint**: `DELETE /api/requests/{id}`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Pengajuan berhasil dibatalkan."
  }
  ```

---

### 5.9 Daftar Pengajuan yang Perlu Disetujui (Inbox Approval Atasan)
Menampilkan daftar permohonan staf/bawahan yang memerlukan persetujuan dari akun Manager/Atasan yang sedang login.

* **Endpoint**: `GET /api/requests/approvals`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "id": 18,
        "request_number": "REQ-20261012-083015-412",
        "request_type": "cuti",
        "type_label": "Libur Cuti",
        "title": "Pengajuan Cuti - Budi Santoso",
        "description": "Cuti tahunan 3 hari",
        "start_date": "2026-10-20",
        "end_date": "2026-10-22",
        "employee": {
          "name": "Budi Santoso",
          "email": "budi@arqomtechnology.cloud",
          "division": "Engineering",
          "position": "Frontend Developer"
        },
        "status": "Menunggu Manager",
        "display_status": "MENUNGGU ATASAN"
      }
    ]
  }
  ```

---

### 5.10 Setujui Pengajuan (Approve by Manager)
Atasan menyetujui pengajuan bawahan.

Jika hasil endpoint masih `status: "Menunggu HCGA"`, absensi belum berubah. Dampak baru aktif ketika approval final menghasilkan `status: "Disetujui"`; periksa `data.attendance_impact.is_effective` agar aplikasi mobile tidak menebak dari tahap approval.

* **Endpoint**: `POST /api/requests/{id}/approve`
* **Request Body (JSON)**:
  ```json
  {
    "note": "Disetujui. Pastikan pekerjaan pekan ini diserahterimakan ke rekan tim."
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Persetujuan berhasil diproses: Disetujui.",
    "data": {
      "id": 18,
      "status": "Menunggu HCGA",
      "display_status": "MENUNGGU HCGA",
      "manager_approval": {
        "status": "Disetujui",
        "approved_by": "Manager Engineering",
        "note": "Disetujui. Pastikan pekerjaan pekan ini diserahterimakan ke rekan tim."
      }
    }
  }
  ```

---

### 5.11 Tolak Pengajuan (Reject by Manager)
Atasan menolak pengajuan bawahan disertai alasan penolakan.

* **Endpoint**: `POST /api/requests/{id}/reject`
* **Request Body (JSON)**:
  ```json
  {
    "note": "Mohon dijadwalkan ulang karena jadwal rilis aplikasi di tanggal tersebut."
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Persetujuan berhasil diproses: Ditolak.",
    "data": {
      "id": 18,
      "status": "Ditolak",
      "display_status": "DITOLAK",
      "manager_approval": {
        "status": "Ditolak",
        "note": "Mohon dijadwalkan ulang karena jadwal rilis aplikasi di tanggal tersebut."
      }
    }
  }
  ```

---

## 6. Agenda Perusahaan

Agenda dibuat dan dikelola melalui kalender web Central Portal (`/portal/kalender`). API mobile bersifat **baca-saja** dan otomatis membatasi data berdasarkan audiens agenda.

### 6.1 Aturan Audiens dan Hak Tampil

| `audience_scope` | Penerima notifikasi dan pengguna yang dapat melihat |
| :--- | :--- |
| `all` | Seluruh pegawai aktif. |
| `division` | Pegawai aktif dengan `division` yang tercantum dalam `target_divisions`. |
| `users` | Pengguna yang ID-nya tercantum dalam `target_user_ids`; pembuat agenda otomatis termasuk. |

Aturan tambahan:

- Pembuat agenda tetap dapat melihat agenda buatannya.
- Superadmin, Direksi, dan HCGA dapat melihat seluruh agenda untuk kebutuhan administrasi, tetapi reminder tetap hanya dikirim kepada audiens agenda.
- Mobile tidak boleh menampilkan hasil cache agenda milik akun sebelumnya setelah pengguna logout atau berganti akun.
- Jenis agenda yang valid: `Meeting`, `Libur`, `Agenda Lainnya`, dan `Deadline`.

### 6.2 Daftar Agenda Saya

* **Endpoint**: `GET /api/agendas`
* **Auth**: Wajib (`Bearer Token`)
* **Query Parameters**:

  | Parameter | Tipe | Wajib | Aturan |
  | :--- | :--- | :--- | :--- |
  | `from` | `date` | Tidak | Format `YYYY-MM-DD`; default tanggal hari ini WIB. |
  | `to` | `date` | Tidak | Format `YYYY-MM-DD`, tidak boleh sebelum `from`; default tiga bulan setelah `from`. |
  | `type` | `string` | Tidak | Salah satu jenis agenda yang valid. |
  | `page` | `integer` | Tidak | Halaman pagination; default `1`. |
  | `per_page` | `integer` | Tidak | `1`–`100`; default `30`. |

Contoh request:

```http
GET /api/agendas?from=2026-10-19&to=2026-11-30&type=Agenda%20Lainnya&per_page=30
Authorization: Bearer <ACCESS_TOKEN>
Accept: application/json
```

* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "id": 24,
        "title": "Olahraga Bersama",
        "type": "Agenda Lainnya",
        "event_date": "2026-10-24",
        "event_end_date": null,
        "start_time": "08:00",
        "end_time": "09:30",
        "starts_at": "2026-10-24T08:00:00+07:00",
        "location": "Lapangan",
        "pic": null,
        "description": "Olahraga rutin perusahaan.",
        "audience_scope": "all",
        "audience_label": "Semua pegawai aktif",
        "reminder_offsets": [1440, 120],
        "deep_link": "artech://agenda/24",
        "updated_at": "2026-10-19T15:20:00+07:00"
      }
    ],
    "meta": {
      "current_page": 1,
      "per_page": 30,
      "total": 1,
      "last_page": 1
    }
  }
  ```

Catatan field:

- `starts_at` menggunakan zona waktu `Asia/Jakarta` dan bernilai `null` untuk agenda tanpa jam mulai.
- `event_end_date` terutama digunakan untuk agenda `Libur` yang berlangsung lebih dari satu hari.
- `reminder_offsets` berisi menit sebelum agenda, misalnya `1440` = H-1 dan `120` = dua jam sebelumnya. Array kosong berarti tidak ada reminder terjadwal.
- `audience_label` aman dipakai sebagai label tampilan. Mobile tidak memerlukan daftar ID penerima.

### 6.3 Detail Agenda

* **Endpoint**: `GET /api/agendas/{id}`
* **Auth**: Wajib (`Bearer Token`)
* **Respon Sukses (200 OK)**: Objek pada `data` menggunakan struktur field yang sama dengan item daftar agenda.
* **Respon Tidak Ditemukan (404)**: Dikembalikan jika agenda tidak ada **atau** pengguna bukan bagian dari audiens. API sengaja tidak membedakan kedua kondisi tersebut untuk mencegah kebocoran informasi.

```json
{
  "status": "success",
  "data": {
    "id": 24,
    "title": "Olahraga Bersama",
    "type": "Agenda Lainnya",
    "event_date": "2026-10-24",
    "event_end_date": null,
    "start_time": "08:00",
    "end_time": "09:30",
    "starts_at": "2026-10-24T08:00:00+07:00",
    "location": "Lapangan",
    "pic": null,
    "description": "Olahraga rutin perusahaan.",
    "audience_scope": "all",
    "audience_label": "Semua pegawai aktif",
    "reminder_offsets": [1440, 120],
    "deep_link": "artech://agenda/24",
    "updated_at": "2026-10-19T15:20:00+07:00"
  }
}
```

### 6.4 Kontrak Reminder dan Deep-Link Mobile

Agenda dari web dapat memilih maksimal dua reminder: `1440` (H-1), `120` (dua jam), `60` (satu jam), atau `30` menit sebelum mulai. Form web baru secara default memilih H-1 dan dua jam. Agenda tanpa jam mulai dihitung mulai pukul `08:00 WIB` untuk keperluan reminder.

Scheduler memeriksa reminder setiap menit. Setiap kombinasi agenda, penerima, waktu mulai, dan offset memiliki kunci deduplikasi sehingga proses scheduler yang berulang tidak membuat notifikasi ganda.

Jenis notifikasi yang perlu ditangani mobile:

| `type` | Pemicu | Tindakan mobile |
| :--- | :--- | :--- |
| `agenda_reminder` | Waktu reminder agenda tercapai. | Buka detail agenda berdasarkan `agenda_id`. |
| `agenda_updated` | Agenda yang sudah ada diubah. | Segarkan detail dan daftar agenda. |
| `agenda_cancelled` | Agenda dihapus/dibatalkan. | Hapus dari cache lokal dan kembali ke daftar agenda jika detail sedang terbuka. |
| `performance_daily_reminder` | Pengingat logbook hari kerja pukul `08:00 WIB`. | Buka halaman logbook harian melalui `action_url`. |

Contoh data FCM untuk reminder agenda (seluruh nilai FCM `data` dikirim sebagai string):

```json
{
  "notification_id": "2c97fa86-33b0-5f27-a417-cb87a84cc0f0",
  "type": "agenda_reminder",
  "entity_type": "central_agenda",
  "entity_id": "24",
  "agenda_id": "24",
  "starts_at": "2026-10-24T08:00:00+07:00",
  "reminder_offset_minutes": "120",
  "deep_link": "artech://agenda/24",
  "priority": "high",
  "click_action": "FLUTTER_NOTIFICATION_CLICK"
}
```

Saat notifikasi diketuk, gunakan `agenda_id` untuk memanggil `GET /api/agendas/{id}`. Jika hasilnya `404`, tampilkan pesan bahwa agenda sudah tidak tersedia dan segarkan daftar lokal.

---

## 7. Notifikasi & Push Notification (Bilah Notifikasi HP)

Sistem notifikasi mobile menampilkan pesan pada **bilah notifikasi perangkat (status bar notification HP)** dan menyimpan salinannya di inbox aplikasi. Sumber notifikasi mencakup perubahan status pengajuan, agenda perusahaan, serta pengingat logbook.

Alur kerja push notification:
1. Saat pengguna login di mobile app, aplikasi mengambil token FCM (*Firebase Cloud Messaging*) / APNs lalu mendaftarkannya ke server via endpoint `POST /api/notifications/register-device`.
2. Saat ada peristiwa yang perlu diberitahukan—misalnya pengajuan disetujui/ditolak, reminder agenda jatuh tempo, agenda diperbarui/dibatalkan, atau pengingat logbook pukul `08:00 WIB`—backend secara otomatis:
   - Menyimpan notifikasi ke dalam database *inbox* pengguna.
   - Mengirimkan *Push Notification payload* ke perangkat pengguna sehingga memunculkan notifikasi di bilah atas HP.
3. Saat pengguna mengetuk notifikasi, aplikasi menentukan tujuan dari `type` dan payload `data`: gunakan `request_id` untuk pengajuan, `agenda_id`/`deep_link` untuk agenda, atau `action_url` untuk pengingat logbook.

---

### 7.1 Daftarkan Device Token Perangkat (FCM Token)
Dipanggil setiap kali user berhasil login atau saat token FCM diperbarui oleh Firebase SDK di smartphone.

* **Endpoint**: `POST /api/notifications/register-device`
* **Headers**: `Authorization: Bearer <token>`, `Content-Type: application/json`
* **Request Body (JSON)**:
  ```json
  {
    "device_token": "fcm_token_panjang_dari_firebase_sdk_1234567890abcdef...",
    "device_type": "android",
    "device_name": "Samsung Galaxy S24 Ultra"
  }
  ```
* **Parameter Request**:
  - `device_token` (`string`, wajib): Token registrasi FCM / APNs perangkat (maks 500 karakter).
  - `device_type` (`string`, opsional): Tipe sistem operasi (`"android"`, `"ios"`, atau `"web"`). Default: `"android"`.
  - `device_name` (`string`, opsional): Nama perangkat user (maks 150 karakter, misal: `"Xiaomi Redmi Note 12"`).
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Perangkat berhasil didaftarkan untuk menerima push notification.",
    "data": {
      "device_token": "fcm_token_panjang_dari_firebase_sdk_1234567890abcdef...",
      "device_type": "android",
      "device_name": "Samsung Galaxy S24 Ultra",
      "is_active": true
    }
  }
  ```

---

### 7.2 Hapus / Nonaktifkan Device Token (Saat Logout)
Dipanggil saat pengguna melakukan logout dari aplikasi agar HP tersebut tidak lagi menerima notifikasi milik akun tersebut.

* **Endpoint**: `POST /api/notifications/unregister-device`
* **Request Body (JSON)**:
  ```json
  {
    "device_token": "fcm_token_panjang_dari_firebase_sdk_1234567890abcdef..."
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Perangkat berhasil dinonaktifkan dari penerimaan push notification."
  }
  ```

---

### 7.3 Ambil Daftar Notifikasi In-App (Pusat Notifikasi / Lonceng)
Mengambil riwayat notifikasi untuk ditampilkan di halaman lonceng notifikasi aplikasi.

* **Endpoint**: `GET /api/notifications`
* **Query Params (Opsional)**:
  - `unread_only`: `true` atau `false` (hanya tampilkan yang belum dibaca).
  - `limit`: Jumlah notifikasi per halaman (default: `30`, maks: `100`).
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "id": "e3b0c442-98fc-1c14-9afb-4c8996fb9242",
        "title": "Pengajuan Lembur Disetujui Atasan",
        "body": "Pengajuan Lembur (REQ-20261013-094123-939) telah disetujui oleh atasan (Budi Santoso) dan diteruskan ke HCGA.",
        "type": "request_approved",
        "data": {
          "request_id": 28,
          "request_number": "REQ-20261013-094123-939",
          "request_type": "lembur",
          "status": "Menunggu HCGA",
          "decision": "Disetujui",
          "reviewer": "Budi Santoso",
          "note": "Disetujui untuk lembur sprint rilis."
        },
        "is_read": false,
        "read_at": null,
        "created_at": "2026-10-13 15:30:00",
        "time_ago": "5 menit yang lalu"
      },
      {
        "id": "f4c1d553-09ad-2d25-8bec-5d9aa7fa0353",
        "title": "Pengajuan Cuti Disetujui HCGA",
        "body": "Pengajuan Cuti (REQ-20261012-083015-412) telah disetujui sepenuhnya oleh HCGA (Zaim Al Faruqy).",
        "type": "request_approved",
        "data": {
          "request_id": 18,
          "request_number": "REQ-20261012-083015-412",
          "request_type": "cuti",
          "status": "Disetujui",
          "decision": "Disetujui",
          "reviewer": "Zaim Al Faruqy",
          "note": "Disetujui sesuai kuota cuti tahunan."
        },
        "is_read": true,
        "read_at": "2026-10-13 14:00:00",
        "created_at": "2026-10-13 13:45:00",
        "time_ago": "2 jam yang lalu"
      }
    ],
    "unread_count": 1
  }
  ```

---

### 7.4 Jumlah Notifikasi Belum Dibaca (Badge Counter Lonceng)
Mengambil total angka notifikasi yang belum dibaca untuk ditampilkan pada ikon *badge* lonceng notifikasi (misal tanda merah angka `3`).

* **Endpoint**: `GET /api/notifications/unread-count`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "unread_count": 3
  }
  ```

---

### 7.5 Tandai Satu Notifikasi Sudah Dibaca
Dipanggil saat pengguna mengetuk / membuka salah satu notifikasi.

* **Endpoint**: `PATCH /api/notifications/{id}/read` (bisa juga `POST /api/notifications/{id}/read`)
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Notifikasi ditandai telah dibaca."
  }
  ```

---

### 7.6 Tandai Seluruh Notifikasi Sudah Dibaca
Dipanggil saat pengguna menekan tombol "Tandai Semua Dibaca" (*Mark All Read*).

* **Endpoint**: `POST /api/notifications/mark-all-read`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Seluruh notifikasi ditandai telah dibaca."
  }
  ```

---

### 7.7 Uji Coba Push Notification ke Bilah HP (Test Push)
Endpoint khusus bagi tim pengembang mobile untuk menguji langsung apakah push notification muncul di bilah notifikasi smartphone mereka.

* **Endpoint**: `POST /api/notifications/test-push`
* **Request Body (JSON, Opsional)**:
  ```json
  {
    "title": "Uji Coba Push Notification Central Portal",
    "body": "Pengajuan lembur Anda telah di-ACC oleh atasan!"
  }
  ```
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Test notifikasi berhasil dikirim.",
    "data": {
      "notification_id": "b6476d19-11cf-41c0-af1b-98cc11ea401c",
      "push": {
        "tokens_count": 1,
        "sent": true,
        "fcm_response": {
          "multicast_id": 8192837192,
          "success": 1,
          "failure": 0
        }
      }
    }
  }
  ```

---

### 7.8 Format Payload Push Notification di Bilah Notifikasi HP

Saat backend mengirimkan push notification via FCM, payload notifikasi pengajuan memiliki struktur berikut. Field spesifik di dalam `data` berbeda menurut `type`; kontrak agenda dijelaskan pada bagian 6.4.

```json
{
  "to": "fcm_token_perangkat",
  "priority": "high",
  "content_available": true,
  "notification": {
    "title": "Pengajuan Lembur Disetujui Atasan",
    "body": "Pengajuan Lembur (REQ-20261013-094123-939) telah disetujui oleh atasan (Budi Santoso) dan diteruskan ke HCGA.",
    "sound": "default",
    "badge": 1,
    "android_channel_id": "portal_requests_channel",
    "channel_id": "portal_requests_channel"
  },
  "data": {
    "notification_id": "e3b0c442-98fc-1c14-9afb-4c8996fb9242",
    "type": "request_approved",
    "request_id": "28",
    "request_number": "REQ-20261013-094123-939",
    "request_type": "lembur",
    "status": "Menunggu HCGA",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

---

### 7.9 Panduan Munculnya Pop-Up Notifikasi di Layar HP (Heads-Up Banner)

Agar notifikasi prioritas tinggi dapat **langsung muncul melayang di atas layar HP (Pop-up Heads-Up Banner)** dan bergetar/berbunyi:

#### 1. Perilaku Berdasarkan Kondisi Aplikasi
| Kondisi Aplikasi di HP | Perilaku Pop-Up | Keterangan |
| :--- | :--- | :--- |
| **Aplikasi Ditutup / Terkunci / Background** | **Otomatis Muncul Pop-Up Melayang** | Sistem Android & iOS otomatis menampilkan heads-up banner di bagian atas layar + ikon di bilah status bar atas. |
| **Aplikasi Sedang Terbuka (Foreground)** | Ditangani oleh Mobile SDK | Developer mobile dapat memunculkan banner lokal via `flutter_local_notifications` atau in-app alert dialog. |

#### 2. Konfigurasi Wajib di Mobile Client (Flutter / React Native)
Untuk memastikan Android menampilkan banner melayang dengan suara/getar:
1. **Daftarkan Notification Channel dengan Prioritas MAX**:
   Pastikan channel ID sesuai dengan yang dikirim backend: `portal_requests_channel`.
   ```dart
   // Contoh konfigurasi Flutter (main.dart):
   const AndroidNotificationChannel channel = AndroidNotificationChannel(
     'portal_requests_channel', // Harus sama persis dengan backend
     'Notifikasi Central Portal',
     description: 'Pengajuan, agenda perusahaan, dan pengingat aktivitas kerja',
     importance: Importance.max, // PENTING: max memunculkan Pop-up Heads-up Banner di atas layar
     playSound: true,
     enableVibration: true,
   );

   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
       FlutterLocalNotificationsPlugin();

   await flutterLocalNotificationsPlugin
       .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
       ?.createNotificationChannel(channel);
   ```

2. **Minta Izin Notifikasi (Android 13+ & iOS)**:
   Saat user login, panggil:
   ```dart
   NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
     alert: true,
     badge: true,
     sound: true,
   );
   ```

3. **Navigasi Otomatis Saat Pop-Up Diketuk**:
   ```dart
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     final type = message.data['type'];

     if (type == 'agenda_reminder' ||
         type == 'agenda_updated' ||
         type == 'agenda_cancelled') {
       final agendaId = int.tryParse(message.data['agenda_id'] ?? '');
       if (agendaId != null && type != 'agenda_cancelled') {
         Navigator.pushNamed(context, '/agenda-detail', arguments: agendaId);
       } else {
         Navigator.pushNamed(context, '/agendas');
       }
     } else if (message.data['request_id'] != null) {
       final requestId = message.data['request_id'];
       Navigator.pushNamed(context, '/request-detail', arguments: requestId);
     } else if (type == 'performance_daily_reminder') {
       Navigator.pushNamed(context, '/daily-logbook');
     }
   });
   ```

   Terapkan logika yang sama untuk `FirebaseMessaging.instance.getInitialMessage()` agar deep-link tetap bekerja ketika aplikasi sebelumnya tertutup sepenuhnya.

---

### 7.10 Langkah Konfigurasi Firebase (FCM) di Backend & Mobile App

Push notification ke bilah status HP membutuhkan perantara **Firebase Cloud Messaging (FCM)** milik Google (Layanan ini **100% Gratis** tanpa batas kuota notifikasi).

#### A. Konfigurasi di Firebase Console (Hanya Sekali)
1. Buka [Firebase Console (Project: arqom-e2b17)](https://console.firebase.google.com/).
2. Masuk ke **Project Settings (Ikon Gerigi ⚙️)** > tab **Service accounts** (Akun Layanan).
3. Anda akan melihat bagian **Firebase Admin SDK**. Klik tombol biru **"Generate new private key"** (Buat kunci privat baru).
4. Browser akan mengunduh sebuah file JSON kredensial (misal: `arqom-e2b17-firebase-adminsdk-xxxxx.json`).
5. Daftarkan aplikasi Android (masukkan package name `arqom_one.cloud`) lalu unduh file `google-services.json` untuk dipasang di aplikasi mobile.

#### B. Konfigurasi di Backend Laravel (Central Portal)
Backend Central Portal secara resmi mendukung **Firebase Cloud Messaging HTTP v1 API** (standar terbaru Google):
1. Simpan file JSON yang diunduh tadi ke dalam folder server:
   ```
   storage/app/firebase/firebase_credentials.json
   ```
2. *(Opsional jika nama file berbeda)*, tentukan path-nya di `.env`:
   ```env
   FIREBASE_CREDENTIALS=storage/app/firebase/firebase_credentials.json
   ```
   *Atau jika menggunakan Legacy Server Key:*
   ```env
   FCM_SERVER_KEY=AAAA...
   ```
> [!NOTE]
> **Graceful Fallback Backend:**  
> Jika kredensial Firebase belum diisi di `.env`, backend **tidak akan crash atau error**. Notifikasi tetap otomatis tersimpan ke tabel database `notifications` (inbox pengguna tetap menerima notifikasi), dan rincian payload akan dicatat rapi di `storage/logs/laravel.log`.

#### C. Konfigurasi di Frontend Mobile (Flutter / React Native)
1. Letakkan file `google-services.json` ke folder `android/app/`.
2. Pasang plugin Firebase:
   ```bash
   flutter pub add firebase_core firebase_messaging flutter_local_notifications
   ```
3. Saat user berhasil login di mobile app, ambil device token lalu kirimkan ke API Central Portal:
   ```dart
   String? fcmToken = await FirebaseMessaging.instance.getToken();
   if (fcmToken != null) {
     await http.post(
       Uri.parse('https://portal-domain.com/api/notifications/register-device'),
       headers: {
         'Authorization': 'Bearer $authToken',
         'Content-Type': 'application/json',
       },
       body: jsonEncode({
         'device_token': fcmToken,
         'device_type': Platform.isAndroid ? 'android' : 'ios',
         'device_name': 'Xiaomi Redmi / iPhone',
       }),
     );
   }
   ```

---

## 8. Modul SOP & Dokumen Resmi

Modul ini menampilkan dokumen aktif yang sudah dipublikasikan dan dapat diakses pengguna sesuai cakupan divisinya. Pengguna dengan status intern tidak memperoleh akses (`403 Forbidden`).

Gunakan prefix utama `/api/sop`. Prefix `/api/documents` tersedia sebagai alias kompatibilitas dan mempunyai kontrak respons yang sama.

### 8.1 Daftar Kategori Dokumen

* **Endpoint**: `GET /api/sop/categories`
* **Alias**: `GET /api/documents/categories`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "data": [
      { "key": "all", "name": "Semua Dokumen", "count": 12 },
      { "key": "sop", "name": "SOP", "count": 5 },
      { "key": "kebijakan", "name": "Kebijakan", "count": 3 }
    ]
  }
  ```

### 8.2 Daftar Dokumen yang Dapat Diakses

* **Endpoint**: `GET /api/sop`
* **Alias**: `GET /api/documents`
* **Query Params (Opsional)**:
  - `category`: kategori dokumen atau `all`
  - `search`: pencarian pada judul, deskripsi, atau nama file
  - `sort`: `latest`, `oldest`, `title_asc`, atau `title_desc`
  - `page`: nomor halaman, default `1`
  - `per_page`: jumlah item, default `20`, maksimal `100`
* **Respon Sukses (200 OK)**:
  ```json
  {
    "status": "success",
    "message": "Daftar dokumen SOP berhasil dimuat.",
    "data": [
      {
        "id": 17,
        "title": "SOP Pengajuan Cuti",
        "category": "sop",
        "category_label": "SOP",
        "description": "Alur pengajuan dan persetujuan cuti.",
        "division_scope": "all",
        "target_label": "Semua Divisi",
        "target_divisions": [],
        "document_type": "file",
        "original_name": "sop-pengajuan-cuti.pdf",
        "mime_type": "application/pdf",
        "file_size": 245760,
        "file_size_formatted": "240 KB",
        "file_extension": "pdf",
        "download_url": "https://arqomtechnology.cloud/api/sop/17/download",
        "view_url": "https://arqomtechnology.cloud/api/sop/17/view",
        "external_url": null,
        "published_at": "2026-10-20T08:00:00+07:00",
        "published_date": "20/10/2026",
        "created_by_name": "Admin HCGA"
      }
    ],
    "meta": {
      "current_page": 1,
      "last_page": 1,
      "per_page": 20,
      "total": 1
    }
  }
  ```

### 8.3 Detail Dokumen

* **Endpoint**: `GET /api/sop/{id}`
* **Alias**: `GET /api/documents/{id}`
* **Respon Sukses**: objek `data` menggunakan field yang sama dengan item pada daftar dokumen.
* **404**: dokumen tidak ditemukan, belum aktif, belum dipublikasikan, atau pengguna tidak memiliki hak akses.

### 8.4 Lihat atau Unduh Dokumen

* **Lihat inline**: `GET /api/sop/{id}/view`
* **Unduh**: `GET /api/sop/{id}/download`
* **Alias**: endpoint yang sama tersedia dengan prefix `/api/documents`.
* **Auth**: utamakan `Authorization: Bearer <ACCESS_TOKEN>` pada request file.
* Untuk `document_type: "file"`, server mengembalikan file inline atau attachment sesuai endpoint.
* Untuk `document_type: "url"`, server mengarahkan pengguna ke `external_url`.
* Mobile harus menghormati respons `401`, `403`, dan `404`; jangan menyimpan atau menampilkan dokumen dari akun lain melalui cache lintas akun.

---

## 9. Ringkasan Kode Error (HTTP Status Codes)

| Kode | Arti | Solusi untuk Mobile Client |
| :--- | :--- | :--- |
| `200` | OK | Permintaan berhasil diproses. |
| `201` | Created | Data baru berhasil dibuat. |
| `401` | Unauthorized | Token kadaluarsa / tidak valid. Alihkan pengguna kembali ke halaman Login. |
| `403` | Forbidden | Karyawan tidak memiliki hak akses mengubah/menyetujui data tersebut. Tampilkan dialog peringatan. |
| `404` | Not Found | Data pengajuan, target, atau item rencana tidak ditemukan. |
| `422` | Unprocessable Entity | Validasi gagal (misal: format jam salah, tanggal selesai sebelum tanggal mulai). Tampilkan pesan error pada form. |
| `500` | Internal Server Error | Kesalahan pada server backend. |
