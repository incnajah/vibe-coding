# Claude Skills — Laravel + Filament + Inertia React

Tiga skill. **Pasang dua, jangan tiga.** Alasannya di bagian bawah.

## Isi

```
claude-skills-laravel/
├── laravel-app-builder.skill      ← pasang ini
├── ui-design-system.skill         ← pasang ini
├── laravel-filament-inertia.skill ← JANGAN pasang bersama dua di atas
│
├── install-these/                 (versi folder, sumber yang bisa diedit)
│   ├── laravel-app-builder/
│   └── ui-design-system/
└── optional-superseded/
    └── laravel-filament-inertia/
```

File `.skill` adalah paket siap pasang. Folder di dalam `install-these/` adalah sumbernya — edit di situ kalau mau ubah isi, lalu pasang ulang folder-nya.

## Cara pasang

**Claude.ai / aplikasi Claude** — buka file `.skill`, klik **Save skill**.

**Claude Code** — salin foldernya, dari root repo ini:

```bash
cp -r claude-skills-laravel/install-these/laravel-app-builder ~/.claude/skills/
cp -r claude-skills-laravel/install-these/ui-design-system ~/.claude/skills/
```

Untuk satu project saja, pakai `.claude/skills/` di dalam project.

## Menjalankan script-nya

Script tinggal di dalam folder skill, bukan di dalam project. Waktu build, direktori kerja adalah **project**, jadi `bash scripts/verify.sh` tidak akan ketemu. Selalu pakai path skill-nya:

```bash
SKILL_DIR=~/.claude/skills/laravel-app-builder
bash "$SKILL_DIR/scripts/bootstrap.sh" nama-project
cd nama-project                     # bootstrap.sh mencetak PROJECT_ROOT=… di baris terakhir
bash "$SKILL_DIR/scripts/verify.sh" # dijalankan dari root project
```

Semua script keluar dengan status non-zero kalau ada yang gagal, jadi bisa langsung dipakai sebagai gate CI.

## Apa isi masing-masing

### `laravel-app-builder` — bangun aplikasi dari deskripsi fitur

Orkestrator utama. Deskripsikan fitur, dia menyusun spec + ERD sendiri, lalu membangun slice demi slice sambil menjalankan loop verify-fix sampai aplikasi benar-benar jalan.

- `scripts/bootstrap.sh` — install Laravel, Filament, Inertia + React + TypeScript, Tailwind v4, Ziggy, Media Library, Pest, Larastan, Debugbar. Inertia diwire sampai jalan: middleware didaftarkan di `bootstrap/app.php`, `app.blade.php`, `app.tsx`, `vite.config.js`, `tsconfig.json`. Juga `pest --init`, `phpstan.neon`, `git init` + commit pertama, dan registrasi MCP **laravel-boost** (schema, model, route, tinker, log browser, semantic search dokumentasi Laravel) dan **playwright** (verifikasi browser sungguhan). Idempoten, aman dijalankan ulang.
  Satu hal yang sengaja tidak dijalankan: `npx shadcn@latest init` — promptnya interaktif dan akan menggantung loop otonom. Script mencetak perintahnya; jalankan sekali sebelum bikin komponen.
- `scripts/verify.sh` — gate loop: syntax, migrasi, route, Pest, vite build; `--full` menambah phpstan, filament:optimize, dan smoke test HTTP (server dev-nya dimatikan bersih lewat trap, termasuk kalau script diinterupsi).
- `references/` — requirements→ERD, kontrak arsitektur (Action layer), Filament, Inertia+React, mekanika loop otonom.

**Butuh terminal.** Jalankan di Claude Code atau Cowork. Di chat claude.ai dia akan bilang jujur bahwa loop-nya tidak bisa berjalan, lalu tetap menghasilkan plan, ERD, dan file kode.

### `ui-design-system` — UI konsisten berbasis komponen

Token → primitives → patterns → features. Bukan atomic design lima tier (alasannya ada di dalam SKILL.md).

- `scripts/audit-ui.sh` — deteksi drift: hex mentah, arbitrary Tailwind value, `focus:outline-none` tanpa pengganti, `<div onClick>`, `<img>` tanpa `alt`, komponen duplikat, token bernama literal. Peringkat HIGH/MED/LOW, exit non-zero pada HIGH, siap masuk CI. Argumen: `audit-ui.sh [source-dir] [css-dir]`, default `resources/js` dan `resources/css`.
- `references/` — token, tier komponen, states & aksesibilitas, parity Filament↔React.

Skill ini menangani **sistem**, bukan selera. Untuk arah estetik, pakai skill desain seperti `frontend-design` kalau tersedia di environment-mu; skill ini merujuk ke sana dan tidak menggantikannya.

## Kenapa skill ketiga jangan dipasang bersamaan

`laravel-filament-inertia` adalah versi pertama, dan isinya sudah dilebur ke `laravel-app-builder/references/architecture.md`. Deskripsi trigger-nya sudah dipersempit jadi "guidance saja, tanpa build loop", tapi cakupan stack-nya tetap sama persis. Kalau keduanya aktif, triggering jadi tidak bisa diprediksi: kadang yang satu, kadang yang lain, kadang keduanya masuk konteks dan saling mengulang.

Dia disertakan hanya kalau kamu ingin panduan arsitektur ringan **tanpa** mesin build otonom. Pilih salah satu, bukan dua-duanya.

## Urutan pemakaian

```
1. bootstrap.sh                 → stack + MCP siap, lalu cd ke PROJECT_ROOT
2. npx shadcn@latest init       → sekali, interaktif
3. deskripsikan fitur           → spec + ERD + plan
4. review ERD (satu-satunya gate)
5. arah visual                  → frontend-design / kesepakatan dengan user
6. encode jadi token            → ui-design-system
7. build loop per slice         → verify.sh setiap slice
8. audit-ui.sh                  → sebelum tiap commit
```

## Prasyarat

PHP 8.2+, Composer, Node 18+, npm, git. Untuk MCP: Claude Code CLI.

Baseline pertengahan 2026: Laravel 13.x, Filament v4 & v5 (v5 hanya dukungan Livewire v4, nol fitur baru), Inertia v2, Tailwind v4. Script tetap memeriksa versi terpasang alih-alih berasumsi.

Script ditulis untuk bash + GNU/BSD coreutils (Linux, macOS, WSL, Git Bash). Belum diuji di PowerShell murni.

## Yang tidak dilakukan skill ini

Skill tidak memasang MCP diam-diam — `bootstrap.sh` menjalankan perintahnya dan melaporkan mana yang gagal, lalu mencetak daftar kemampuan yang jadi degraded. Skill juga tidak memasang skill lain; keduanya self-contained. Yang benar-benar mem-publish skill tambahan ke dalam project adalah `php artisan boost:install`.
