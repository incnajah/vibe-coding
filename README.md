# Claude Skills — Bikin Aplikasi Laravel Cukup dengan Ngomong

Kamu cerita mau bikin aplikasi apa dan fiturnya apa saja. Claude yang mengerjakan: bikin database, halaman admin, halaman website, sampai testing — lalu mengecek sendiri hasilnya sampai benar-benar jalan.

Repo ini isinya "skill" — semacam **buku petunjuk yang dibaca Claude** supaya dia tahu cara mengerjakannya dengan benar dan konsisten.

---

## Daftar isi

1. [Ini sebenarnya apa?](#1-ini-sebenarnya-apa)
2. [Yang harus ada di komputermu](#2-yang-harus-ada-di-komputermu)
3. [Cara pasang (5 menit)](#3-cara-pasang-5-menit)
4. [Cek sudah terpasang atau belum](#4-cek-sudah-terpasang-atau-belum)
5. [Cara pakai — 6 langkah](#5-cara-pakai--6-langkah)
6. [Contoh nyata dari nol sampai jadi](#6-contoh-nyata-dari-nol-sampai-jadi)
7. [Kalau error](#7-kalau-error)
8. [Fitur lanjutan](#8-fitur-lanjutan)
9. [Buku manual script](#9-buku-manual-script)
10. [Yang belum sempurna](#10-yang-belum-sempurna)

---

## 1. Ini sebenarnya apa?

Bayangkan kamu punya pegawai programmer. Kalau kamu bilang *"bikinin website travel umroh"*, dia perlu tahu:

- Cara kerja perusahaanmu
- Standar penulisan kode yang dipakai
- Harus tes apa saja sebelum bilang "selesai"

**Skill = buku petunjuk itu.** Kamu kasih ke Claude sekali, lalu setiap kali kamu minta bikin aplikasi, dia sudah tahu caranya.

### Ada tiga skill di sini. Pasang dua saja.

| Skill | Gunanya | Pasang? |
|---|---|---|
| `laravel-app-builder` | Bikin aplikasi dari cerita fiturmu | ✅ Ya |
| `ui-design-system` | Bikin tampilan rapi dan seragam | ✅ Ya |
| `laravel-filament-inertia` | Versi lama dari yang pertama | ❌ Jangan |

Kenapa yang ketiga jangan? Karena isinya sudah dilebur ke yang pertama. Kalau dua-duanya dipasang, Claude bingung mau pakai yang mana, dan hasilnya jadi tidak menentu. Penjelasan lengkap ada di [bagian 8](#kenapa-skill-ketiga-jangan-dipasang).

### Istilah yang akan sering muncul

Baca sekali, nanti tidak bingung:

| Istilah | Artinya dengan bahasa manusia |
|---|---|
| **Laravel** | Kerangka kerja untuk bikin website. Seperti rangka mobil — kamu tinggal pasang bodinya |
| **Filament** | Halaman admin yang sudah jadi. Tempat kamu menambah/mengedit data |
| **React** | Yang bikin halaman depan (yang dilihat pengunjung) terasa cepat |
| **Database** | Tempat semua data disimpan. Bayangkan Excel raksasa |
| **ERD** | Gambar yang menunjukkan tabel-tabel database dan hubungannya |
| **Migrasi** | Perintah untuk membuat tabel di database |
| **Slice** | Satu fitur utuh, dari database sampai tampilan. Dikerjakan satu per satu |
| **Terminal** | Layar hitam tempat mengetik perintah. Di Windows: buka **Git Bash** |

---

## 2. Yang harus ada di komputermu

Lima program. Cek dulu, jangan asal install ulang.

**Buka terminal**, lalu ketik satu per satu:

```bash
php -v          # butuh 8.2 atau lebih baru
composer -V     # butuh versi 2
node -v         # butuh 18 atau lebih baru
npm -v
git --version
```

Kalau salah satu bilang `command not found`, berarti belum terpasang:

| Belum ada | Install dari |
|---|---|
| PHP | [Laravel Herd](https://herd.laravel.com) (paling gampang, Windows & Mac) atau XAMPP |
| Composer | [getcomposer.org/download](https://getcomposer.org/download/) |
| Node + npm | [nodejs.org](https://nodejs.org) — pilih versi **LTS** |
| Git | [git-scm.com](https://git-scm.com) |

> **Pengguna Windows:** semua perintah di dokumen ini dijalankan di **Git Bash**, bukan Command Prompt dan bukan PowerShell. Git Bash otomatis ikut terpasang bersama Git. Cari "Git Bash" di menu Start.

Satu lagi yang **sangat disarankan** tapi tidak wajib: **Claude Code CLI**. Ini yang membuat Claude bisa melihat isi database dan membuka browser sungguhan untuk mengecek hasil kerjanya. Cek dengan `claude --version`.

---

## 3. Cara pasang (5 menit)

### Kalau kamu pakai Claude Code (di terminal)

Copy-paste blok ini, jalankan sekaligus:

```bash
git clone https://github.com/incnajah/vibe-coding.git
cd vibe-coding
mkdir -p ~/.claude/skills
cp -r claude-skills-laravel/install-these/laravel-app-builder ~/.claude/skills/
cp -r claude-skills-laravel/install-these/ui-design-system    ~/.claude/skills/
```

Selesai. Skill sekarang aktif di **semua** project.

Mau pakai agent tambahan juga? (Penjelasan di [bagian 8](#8-fitur-lanjutan) — boleh dilewati dulu.)

```bash
mkdir -p ~/.claude/agents
cp claude-skills-laravel/agents/*.md ~/.claude/agents/
```

### Kalau kamu pakai claude.ai atau aplikasi Claude

Buka dua file ini, lalu klik tombol **Save skill**:

- `claude-skills-laravel/laravel-app-builder.skill`
- `claude-skills-laravel/ui-design-system.skill`

> ⚠️ **Penting:** di chat claude.ai tidak ada terminal. Claude tetap bisa bikin rencana, ERD, dan file kode untuk kamu salin — tapi dia **tidak bisa** menjalankan dan mengetes aplikasinya sendiri. Untuk yang otomatis penuh, pakai Claude Code.

---

## 4. Cek sudah terpasang atau belum

```bash
ls ~/.claude/skills/
```

Harusnya muncul:

```
laravel-app-builder  ui-design-system
```

Kalau kosong atau kurang, ulangi langkah 3.

**Masih tidak terdeteksi Claude?** Pastikan struktur foldernya begini — file `SKILL.md` harus langsung di dalam foldernya, tidak bersarang lebih dalam:

```
~/.claude/skills/laravel-app-builder/SKILL.md   ← benar
~/.claude/skills/laravel-app-builder/laravel-app-builder/SKILL.md   ← salah
```

Lalu tutup sesi Claude Code dan buka baru.

---

## 5. Cara pakai — 6 langkah

### Langkah 1 — Siapkan project

Buat folder kosong, masuk ke sana, jalankan satu perintah ini:

```bash
SKILL_DIR=~/.claude/skills/laravel-app-builder
bash "$SKILL_DIR/scripts/bootstrap.sh" travel-umroh
```

Ganti `travel-umroh` dengan nama projectmu.

**Apa yang terjadi:** program ini memasang semua bahan yang dibutuhkan — Laravel, halaman admin, React, database, alat testing. Butuh 5–15 menit tergantung internet. Biarkan saja jalan.

> **Kenapa harus pakai `$SKILL_DIR`?** Karena file `bootstrap.sh` ada di folder skill, bukan di folder projectmu. Kalau kamu ketik `bash scripts/bootstrap.sh` saja, komputer tidak akan menemukannya.

Di baris paling akhir akan muncul:

```
PROJECT_ROOT=/home/kamu/travel-umroh
```

### Langkah 2 — Masuk ke folder project

```bash
cd travel-umroh
```

**Ini wajib.** Semua perintah setelah ini harus dijalankan dari dalam folder project.

### Langkah 3 — Pasang komponen tampilan

```bash
npx shadcn@latest init
```

Program ini akan bertanya beberapa hal — jawab saja dengan Enter (pilihan bawaannya sudah benar). Cukup sekali seumur project.

> Kenapa tidak otomatis? Karena dia bertanya, dan pertanyaan akan membuat proses otomatis Claude berhenti menggantung menunggu jawaban yang tidak pernah datang.

### Langkah 4 — Ceritakan mau bikin apa

Sekarang buka Claude Code di folder ini, dan **ngomong biasa saja**. Tidak perlu istilah teknis:

> Website travel umroh. Ada paket umroh, destinasi, muthowif, hotel, harga beda-beda per tanggal berangkat, album foto, dan tombol WhatsApp langsung ke admin.

Claude akan membuat dokumen perencanaan di folder `docs/`:

| File | Isinya |
|---|---|
| `docs/prd.md` | Masalah yang dipecahkan, siapa penggunanya, tolok ukur sukses, apa yang **tidak** dibuat |
| `docs/erd.md` | Gambar tabel database dan hubungannya |
| `docs/workflows.md` | **Hanya kalau aplikasimu berupa alur kerja.** Siapa melakukan apa, urutannya, dan status yang boleh berpindah ke mana |
| `docs/plan.md` | Urutan pengerjaan, fitur per fitur |

**Kapan `workflows.md` dibuat?** Kalau satu data berpindah tangan antar beberapa orang secara berurutan.

- *Website travel* → tidak perlu. Data paket cuma ditambah dan ditampilkan.
- *Aplikasi resto dengan QR per meja* → **perlu.** Satu pesanan bergerak dari pelanggan → koki → kasir → balik ke pelanggan. Yang penting bukan tabelnya, tapi perpindahannya.

Kalau langkah ini dilewati pada aplikasi jenis kedua, hasilnya empat halaman yang sama-sama mengubah kolom `status` tanpa kesepakatan apa arti nilainya — dan itu baru terasa setelah semuanya terlanjur dibangun.

Dia akan **menebak sendiri** hal-hal teknis (kolom tanggal, tempat foto, alamat halaman) tanpa bertanya. Yang ditanyakan **maksimal 3**, dan hanya yang mahal kalau salah:

1. Ada pembayaran online, atau cuma tampil harga?
2. Satu perusahaan saja, atau banyak perusahaan dengan data terpisah?
3. Pengunjung perlu daftar akun, atau cukup lihat-lihat lalu chat WhatsApp?

### Langkah 5 — Periksa ERD-nya (INI PENTING)

Claude akan menunjukkan gambar database dan bertanya sekali:

> Ini rencananya. Ada yang salah atau kurang sebelum aku bangun?

**Baca beneran.** Ini satu-satunya tempat berhenti. Kalau strukturnya salah dan baru ketahuan nanti, perbaikannya berjam-jam. Kalau ketahuan sekarang, dua menit.

Kamu tidak perlu paham teknisnya. Cukup cek dari sisi bisnis:

- Semua yang mau kamu simpan sudah ada tabelnya?
- Hubungannya masuk akal? (Contoh: *satu paket bisa punya banyak tanggal berangkat* — benar?)
- Ada yang kelebihan atau kurang?

Jawab pakai bahasa biasa: *"muthowif bisa lebih dari satu per paket"* — Claude akan memperbaiki ERD-nya lalu lanjut.

> **Buru-buru?** Bilang **"langsung saja"** atau **"jangan tanya-tanya"** di pesan pertama. Gate ini dilewati dan dia langsung mengerjakan.

### Langkah 6 — Tunggu dan pantau

Claude mengerjakan **satu fitur sampai tuntas**, baru pindah ke fitur berikutnya. Jadi aplikasi selalu dalam kondisi bisa dilihat, tidak menunggu semuanya selesai dulu.

Kamu akan lihat laporan seperti ini:

```
✓ Slice 1/6 — Login + halaman admin
✓ Slice 2/6 — Paket umroh: database, admin, halaman /paket, 11 tes lulus
▸ Slice 3/6 — Tanggal keberangkatan & harga
```

Setiap fitur selesai, dia mengetes sendiri. Kalau gagal, dia baca errornya dan perbaiki — sampai 6 kali percobaan. Kalau tetap gagal, **dia berhenti dan cerita apa masalahnya**, tidak berpura-pura sudah selesai.

Kalau semua sudah beres, jalankan pemeriksaan siap-produksi:

```bash
bash "$SKILL_DIR/scripts/preflight-prod.sh"
```

Ini mengecek hal-hal yang bikin aplikasi celaka setelah online — misalnya mode debug masih menyala (bocorin password ke pengunjung) atau antrian pekerjaan belum disetel.

---

## 6. Contoh nyata dari nol sampai jadi

Semua yang kamu ketik, berurutan:

```bash
# 1. Siapkan
mkdir ~/projects && cd ~/projects
SKILL_DIR=~/.claude/skills/laravel-app-builder
bash "$SKILL_DIR/scripts/bootstrap.sh" travel-umroh
cd travel-umroh
npx shadcn@latest init

# 2. Buka Claude Code di sini
claude
```

Lalu di dalam Claude, kamu ketik:

> Website travel umroh. Paket umroh, destinasi, muthowif, hotel, harga per tanggal keberangkatan, album foto, tombol WhatsApp langsung.

**Claude bertanya:** *"Ada pembayaran online, atau harga cuma ditampilkan?"*

**Kamu jawab:** *"Cuma ditampilkan, pesan lewat WhatsApp."*

**Claude menampilkan ERD.** Isinya kira-kira:

```
PAKET ──punya banyak──> TANGGAL_BERANGKAT (tanggal, harga, sisa kursi)
PAKET ──dipandu──> MUTHOWIF
PAKET ──menginap di──> HOTEL
PAKET ──mengunjungi──> DESTINASI
```

**Kamu baca**, lalu bilang: *"Muthowif-nya bisa lebih dari satu per paket."*

**Claude memperbaiki**, lalu mulai mengerjakan. Setelah selesai kamu dapat:

- Halaman admin di `/admin` — tempat menambah paket, upload foto, atur harga
- Halaman publik di `/paket` — daftar paket yang bisa dilihat pengunjung
- Tombol WhatsApp yang langsung membuka chat dengan pesan otomatis
- Data contoh sudah terisi, jadi tidak kosong melompong saat dibuka
- File `README.md` di dalam project berisi cara menjalankan + username & password admin

Buka aplikasinya:

```bash
php artisan serve
```

Lalu buka `http://localhost:8000` di browser.

### Contoh kedua: aplikasi resto yang lebih rumit

Kamu ketik:

> Aplikasi web resto di mall. Tiap meja ada QR code, pelanggan scan lalu pesan sendiri. Pesanan langsung masuk ke layar koki dan ke kasir. Pelanggan bisa lihat status pesanannya.

Ini beda jenis dari contoh travel tadi. Di sini **satu pesanan berpindah tangan**: pelanggan → koki → kasir → balik ke pelanggan. Jadi Claude membuat `docs/workflows.md` juga, isinya:

**Siapa pakai apa:**

| Pelaku | Alat | Login | Sinyal |
|---|---|---|---|
| Pelanggan | HP sendiri, scan QR | tidak login — pakai token meja | wifi mall, sering putus |
| Koki | layar dapur | terikat perangkat | kabel |
| Kasir | mesin kasir | PIN | kabel |
| Pemilik | laptop | password | di mana saja |

**Perjalanan status pesanan:**

```
draft ──pesan──> placed ──koki terima──> confirmed ──> cooking ──> ready
                    │                        │
                    └──koki tolak──> rejected└──manajer batalkan──> cancelled

ready ──diantar──> served ──dibayar──> settled
```

Setiap panah menjadi **satu perintah tersendiri** dengan aturan siapa yang boleh menjalankannya. Bukan satu tombol "ubah status" yang bisa dipakai siapa saja untuk mengisi apa saja — itu cara paling cepat merusak data.

**Dan Claude memutuskan hal-hal yang tidak kamu sebutkan tapi pasti bermasalah:**

- Pelanggan tap tombol "Pesan" dua kali karena wifi lambat → tanpa pengaman jadi dua pesanan. Diberi pengaman.
- Layar dapur menyala 9 jam, koneksinya putus di jam ke-3 → harus otomatis nyambung lagi, kalau tidak layarnya diam-diam berhenti update.
- QR meja bisa difoto dan dipakai besok → tokennya dibatasi hanya selama meja itu terbuka.
- Koki menandai "siap" bersamaan dengan kasir menutup tagihan → dikunci supaya tidak saling menimpa.

**Urutan pengerjaannya juga beda.** Untuk aplikasi seperti ini, Claude membangun dan **mengetes seluruh perpindahan status dulu, sebelum ada tampilan sama sekali**. Alasannya: perpindahan status itulah aplikasinya; layar cuma jendela untuk melihatnya. Salah di sana setelah 4 layar jadi, berarti benerin 4 layar.

**Dokumennya ikut diperbarui.** Kalau di tengah jalan ternyata ada perpindahan status yang mustahil, Claude memperbaiki `docs/workflows.md` bersamaan dengan kodenya, dan mencatat alasannya di `docs/decisions.md`. Diagram yang tidak lagi cocok dengan kode lebih berbahaya daripada tidak ada diagram, karena orang berikutnya percaya begitu saja.

---

## 7. Kalau error

Cari gejalanya di kolom kiri.

| Yang muncul di layar | Artinya | Cara benerin |
|---|---|---|
| `No such file or directory` saat menjalankan script | Salah alamat file | Pakai `$SKILL_DIR` seperti di contoh, jangan `bash scripts/...` |
| `verify.sh must run from the Laravel project root` | Kamu belum masuk ke folder project | `cd nama-project` dulu |
| `bad interpreter: ...^M` | File rusak karena format baris Windows | `sed -i 's/\r$//' namafile.sh` |
| `missing required tools: composer` | Ada program yang belum terpasang | Lihat [bagian 2](#2-yang-harus-ada-di-komputermu) |
| `no usable test runner` | Alat testing belum siap | `vendor/bin/pest --init` |
| Halaman `/admin` bilang **403** | Akun kamu belum diizinkan masuk panel | Claude harus menambahkan `canAccessPanel()` di model User |
| Tampilan admin berantakan setelah upload ke server | Aset belum dibangun ulang | Jalankan `php artisan filament:assets` di server |
| `Port 8899 already in use` | Port sedang dipakai program lain | `VERIFY_PORT=9000 bash "$SKILL_DIR/scripts/verify.sh" --full` |
| `npm error ERESOLVE` | Versi paket bentrok | `bootstrap.sh` versi terbaru sudah menanganinya — pastikan kamu pakai yang terbaru |

**Aturan umum kalau bingung:** copy seluruh pesan error, tempel ke Claude, dan bilang *"ini errornya, tolong perbaiki"*. Dia memang dirancang untuk membaca error sungguhan, bukan menebak.

---

## 8. Fitur lanjutan

Boleh dilewati kalau baru mulai.

### Claude bisa kerja seperti tim, bukan satu orang

Kalau ada 3 fitur atau lebih yang **tidak saling bersentuhan**, Claude bisa membagi kerja ke beberapa "pegawai" sekaligus:

| Peran | Tugas |
|---|---|
| **Lead** | Bikin rencana, bagi tugas, gabungkan hasil, ngobrol denganmu |
| **Builder** | Kerjakan satu fitur, masing-masing di ruang kerja terpisah |
| **Reviewer** | Periksa hasil builder — **tanpa** diberi tahu alasan si builder |
| **QA** | Tes hasil gabungan: jalankan tes, buka browser sungguhan, baca error |

Reviewer sengaja tidak diberi penjelasan builder. Kalau dia tahu alasannya, dia cuma mengecek "apakah kode cocok dengan cerita" — bukan "apakah ceritanya benar".

Pasang agent-nya:

```bash
mkdir -p ~/.claude/agents
cp claude-skills-laravel/agents/*.md ~/.claude/agents/
```

> ⚠️ Kerja paralel memakai token beberapa kali lipat. Claude akan memberi tahu sebelum melakukannya. Untuk project kecil, satu agent saja lebih hemat dan sama bagusnya.

### Claude belajar dari kesalahannya

Setiap kali ada kesalahan yang butuh 2 kali percobaan atau lebih, Claude mencatatnya di `docs/lessons.md` di dalam projectmu.

Di akhir pekerjaan, pelajaran yang **berlaku umum** (bukan cuma untuk project ini) bisa dinaikkan ke dalam skill-nya sendiri:

```bash
bash "$SKILL_DIR/scripts/learn.sh"          # lihat dulu apa yang mau ditambahkan
bash "$SKILL_DIR/scripts/learn.sh" --apply  # baru simpan
```

Kenapa dua langkah? Karena menulis ke skill mengubah perilaku Claude di **semua** project berikutnya, selamanya. Itu bukan hal yang boleh terjadi diam-diam. Kamu harus lihat dulu apa yang mau ditambahkan.

Batasnya 40 catatan. Lewat dari itu, menambah berarti membuang yang lama — bukan menumpuk. Catatan yang terlalu banyak justru menenggelamkan panduan yang sudah bagus.

### Kenapa skill ketiga jangan dipasang

`laravel-filament-inertia` adalah versi pertama. Isinya sudah dipindah ke dalam `laravel-app-builder`.

Masalahnya: keduanya sama-sama mengaku ahli "Laravel + Filament + Inertia". Kalau dua-duanya aktif, Claude kadang pakai yang satu, kadang yang lain, kadang dua-duanya sekaligus lalu mengulang-ulang hal yang sama.

Pasang dia **hanya kalau** kamu cuma mau nasihat arsitektur, tanpa mesin pembangun otomatis. Pilih salah satu.

---

## 9. Buku manual script

### `bootstrap.sh` — menyiapkan project baru

```bash
bash "$SKILL_DIR/scripts/bootstrap.sh" [nama-project]
```

- Aman dijalankan berkali-kali. Yang sudah ada dilewati.
- Nama project boleh dikosongkan **hanya** kalau kamu sudah di dalam project Laravel.
- Baris terakhir mencetak `PROJECT_ROOT=...` — itu folder yang harus kamu masuki.
- Kalau ada yang gagal dipasang, dia mencetak daftar **Degraded capabilities** — jujur, tidak disembunyikan.
- Tidak menjalankan `npx shadcn init` (karena bertanya-tanya dan akan menggantung proses otomatis).

### `verify.sh` — mengecek aplikasi masih waras

```bash
bash "$SKILL_DIR/scripts/verify.sh" [--full]
```

Harus dijalankan **dari dalam folder project**.

| Diperiksa | Kapan |
|---|---|
| Kode PHP tidak salah ketik | selalu |
| Database bisa dibuat | selalu |
| Semua alamat halaman terdaftar | selalu |
| Tes lulus | selalu |
| Tampilan bisa dibangun | selalu |
| Analisa kode mendalam | `--full` |
| Halaman `/` dan `/admin/login` benar-benar terbuka | `--full` |

Kode keluar: `0` lulus, `1` ada yang gagal, `2` salah cara pakai.

### `audit-ui.sh` — mengecek tampilan tetap seragam

```bash
bash ~/.claude/skills/ui-design-system/scripts/audit-ui.sh [folder-kode] [folder-css]
```

Bawaan: `resources/js` dan `resources/css`.

Mencari hal-hal yang bikin tampilan pelan-pelan jadi berantakan: warna ditulis manual, ukuran asal-asalan, tombol yang tidak bisa dipakai lewat keyboard, gambar tanpa keterangan, komponen kembar.

Hasilnya diberi peringkat **HIGH / MED / LOW**. Kode keluar `1` kalau ada HIGH.

### `preflight-prod.sh` — mengecek siap online atau belum

```bash
bash "$SKILL_DIR/scripts/preflight-prod.sh"
```

Mencari masalah yang baru terasa **setelah** aplikasi online:

- Mode debug masih menyala → halaman error membocorkan password database ke siapa pun
- Antrian pekerjaan belum disetel → kirim email jadi bagian dari loading halaman
- `.env` (file berisi semua password) ikut masuk ke Git
- Panel admin akan 403 di server
- Belum ada pemantau error → kamu baru tahu rusak dari komplain klien

Yang **tidak bisa** dicek dari sini (sertifikat HTTPS, backup, penjadwal di server) dia sebutkan sebagai *belum diperiksa* — bukan dianggap beres.

### `learn.sh` — menyimpan pelajaran ke dalam skill

```bash
bash "$SKILL_DIR/scripts/learn.sh"          # lihat saja
bash "$SKILL_DIR/scripts/learn.sh" --apply  # simpan
```

---

## 10. Yang belum sempurna

Ditulis apa adanya. Lebih baik kamu tahu sekarang daripada kaget nanti.

<!-- STATUS-E2E -->

- **Belum diuji di PowerShell atau Command Prompt.** Semua script ditulis untuk bash. Di Windows pakai **Git Bash** (ikut terpasang bersama Git) atau WSL. Ini bukan rencana untuk diperbaiki — Git Bash sudah ada di setiap komputer yang punya Git.

- **Skill tidak memasang MCP diam-diam.** MCP adalah kemampuan tambahan yang membuat Claude bisa melihat isi database dan membuka browser. `bootstrap.sh` menjalankan perintah pemasangannya secara terbuka dan melaporkan mana yang gagal — dia tidak mengubah setelan komputermu tanpa memberitahu.

- **Skill tidak memasang skill lain.** Keduanya berdiri sendiri. Yang benar-benar menambahkan panduan tambahan ke dalam project adalah `php artisan boost:install`, dan itu berjalan di dalam projectmu saja.

- **`ui-design-system` mengurus keteraturan, bukan selera.** Dia memastikan tampilan konsisten dan bisa diakses semua orang. Dia **tidak** menentukan aplikasimu cantik atau tidak. Untuk arah visual, tentukan sendiri atau pakai skill desain terpisah.

- **Claude tetap bisa salah.** Skill ini membuat dia lebih jarang salah dan lebih jujur saat salah — bukan tidak pernah salah. Gate ERD di langkah 5 ada justru karena itu. Baca ERD-nya.

---

## Lisensi & kontribusi

Silakan pakai, ubah, dan sebarkan. Kalau kamu menemukan bug atau punya perbaikan, buka issue atau pull request di [github.com/incnajah/vibe-coding](https://github.com/incnajah/vibe-coding).
