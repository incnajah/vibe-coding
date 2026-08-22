# Blog Demo — hasil nyata dari skill ini

Aplikasi ini **bukan contoh yang ditulis tangan untuk dokumentasi.** Ini benar-benar dibangun dengan mengikuti proses `laravel-app-builder`, dari folder kosong, lalu diverifikasi dengan gate-nya sendiri.

Bukti lengkapnya ada di [`docs/test-report.md`](docs/test-report.md) — output apa adanya, tidak diedit.

| Gate | Hasil |
|---|---|
| `verify.sh --full` | **LULUS** — syntax, migrasi, route, build Vite, tes, panel Filament, `GET / → 200`, `GET /admin → 302` |
| Pest | **27 lulus**, 82 assertion |
| `audit-ui.sh` | **HIGH 0, MED 0, LOW 0** |
| `preflight-prod.sh` | 1 blocker (`APP_DEBUG=true`) — memang benar untuk project lokal |

---

## Cara menjalankan

```bash
composer install
npm install
cp .env.example .env
php artisan key:generate

touch database/database.sqlite
php artisan migrate --seed
php artisan storage:link

composer run dev
```

Buka `http://localhost:8000`.

**Login admin:** `admin@example.com` / `password`

> Di Windows, `composer run dev` bawaan Laravel akan langsung mati karena `php artisan pail` butuh ekstensi `pcntl`. `bootstrap.sh` sudah membuang pail dari script `dev`, dan `composer.json` di sini sudah bersih.

---

## Apa yang ada di dalamnya

**Publik**

- `/` — daftar artikel, grid kartu, judul dan slogan diambil dari Settings
- `/posts/{slug}` — halaman baca, lebar teks dibatasi ~65 karakter
- Draft **tidak pernah** bocor: `/posts/{slug}` untuk artikel draft mengembalikan 404

**Admin (`/admin`)**

- Dashboard dengan 4 kartu statistik + sparkline tren mingguan, dan tabel artikel terbaru.
  Widget bawaan Filament ("Welcome" dan logo Filament) dibuang.
- CRUD artikel lengkap: list, create, edit, delete
- Aksi Terbitkan / Tarik langsung dari tabel
- **Pengaturan** — judul situs, slogan, favicon, email kontak, artikel per halaman, tampilkan penulis

---

## Yang layak dilihat di kodenya

Empat keputusan yang dijaga skill ini, dan bisa kamu periksa sendiri:

**1. Business logic tidak pernah ada di UI.** Filament resource dan controller cuma pemanggil tipis.

```
app/Actions/Post/PublishPost.php      ← logikanya di sini
app/Filament/.../Tables/PostsTable.php ← cuma memanggilnya
```

Publish harus menstempel tanggal dan membersihkan cache dengan urutan yang sama, dari mana pun dipicu. Kalau logikanya di dalam resource, pemanggil kedua diam-diam mengerjakan lebih sedikit — dan bug jenis ini tidak melempar error, cuma menghasilkan data salah.

**2. Prop Inertia dibentuk eksplisit, bukan model mentah.** Lihat `app/Http/Controllers/PostController.php`. Model mentah membocorkan setiap kolom ke HTML halaman dan mengikat frontend ke skema database.

**3. Settings key-value, bukan kolom per setting.** `database/migrations/*_create_settings_table.php` cuma punya `group`, `key`, `value`. Menambah setting baru tidak perlu migrasi — dibuktikan oleh tes `it('adds a brand new setting without a migration')`.

**4. Token, bukan warna manual.** `resources/css/app.css` mendefinisikan peran (`--color-primary`, `--color-surface`), bukan nama warna. Dark mode adalah override token, bukan `dark:` di setiap komponen — makanya `audit-ui.sh` bersih.

---

## Tes

```bash
vendor/bin/pest
```

27 tes, dikelompokkan sesuai yang dijaga:

| File | Menjaga |
|---|---|
| `PostTest.php` | Action, slug unik, draft tidak bocor ke pembaca |
| `AdminPanelTest.php` | CRUD lewat panel sungguhan, aksi publish, non-admin ditolak, dashboard bukan boilerplate |
| `SettingsTest.php` | Default, tipe data lewat JSON, cache invalidation, dan settings benar-benar mengubah halaman publik |
| `NavigationTest.php` | Setiap item sidebar punya ikon — jebakan yang cuma terlihat kalau panel dibuka |
| `ExampleTest.php` | Halaman depan terbuka |

---

## Diambil dari sini

Skill-nya ada di [`../../claude-skills-laravel/`](../../claude-skills-laravel/). Baca [README utama](../../README.md) untuk cara memasang dan memakainya.
