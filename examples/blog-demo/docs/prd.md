# Blog — Product Requirements

## Problem
Penulis butuh tempat menulis dan menerbitkan artikel tanpa menyentuh kode, dan
pembaca butuh halaman yang cepat dan enak dibaca.

## Actors
| Actor | Device | Auth | What they need to do |
|---|---|---|---|
| Pembaca | apa saja | tidak login | membaca daftar artikel dan satu artikel |
| Admin | laptop, panel Filament | email + password | menulis, mengedit, menerbitkan, menarik kembali |

## Success criteria
- Admin bisa membuat artikel dan menerbitkannya tanpa bantuan developer
- Artikel yang belum diterbitkan tidak pernah terlihat pembaca
- Halaman daftar dan detail terbuka dengan status 200

## Entities
| Entity | Purpose | Key fields |
|---|---|---|
| users | admin panel | name, email, password, is_admin |
| posts | artikel | title, slug, excerpt, body, published_at |

## Shape
Catalogue-shaped. Satu peran menulis, satu peran membaca; tidak ada data yang
berpindah tangan berurutan, jadi tidak ada docs/workflows.md.
Publish/unpublish adalah satu flag bertanggal, bukan mesin status.

## Slices
1. Posts — admin CRUD + terbit/tarik, halaman publik `/` dan `/posts/{slug}`
   Acceptance: admin membuat artikel, menerbitkannya, artikel muncul di `/`
   dan halamannya terbuka; artikel draft tidak muncul di mana pun.

## Out of scope (v1)
- Komentar: butuh moderasi dan anti-spam, itu proyek tersendiri
- Kategori dan tag: belum ada cukup artikel untuk butuh navigasi
- Gambar sampul: butuh storage dan konversi
- Pencarian: daftar masih cukup pendek

## Open risks
- Belum ada editor kaya. Body disimpan sebagai teks biasa dengan paragraf.
