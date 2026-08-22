<?php

namespace Database\Seeders;

use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::updateOrCreate(
            ['email' => 'admin@example.com'],
            [
                'name' => 'Admin',
                'password' => Hash::make('password'),
                'is_admin' => true,
            ],
        );

        // Seed demo data so the app is not an empty shell when it is first opened.
        $articles = [
            ['Kenapa slug lebih baik daripada id di URL', 'URL yang bisa dibaca manusia bukan soal estetika saja.'],
            ['Menyimpan uang sebagai decimal, bukan float', 'Satu pembulatan yang salah bisa hidup bertahun-tahun di laporan keuangan.'],
            ['Empty state itu pekerjaan desain, bukan cadangan', 'Layar kosong adalah layar pertama yang dilihat pengguna baru.'],
            ['N+1 hampir selalu penyebab halaman lambat', 'Sebelum menyalahkan runtime, hitung dulu jumlah query-nya.'],
            ['Token mengalahkan komponen', 'Lima puluh komponen tanpa batasan tetap melenceng, hanya di lebih banyak tempat.'],
        ];

        foreach ($articles as $i => [$title, $excerpt]) {
            Post::updateOrCreate(
                ['slug' => Str::slug($title)],
                [
                    'user_id' => $admin->getKey(),
                    'title' => $title,
                    'excerpt' => $excerpt,
                    'body' => self::body($excerpt),
                    'published_at' => now()->subDays(($i + 1) * 3),
                ],
            );
        }

        // One draft, to prove drafts never reach the public pages.
        Post::updateOrCreate(
            ['slug' => 'catatan-yang-belum-selesai'],
            [
                'user_id' => $admin->getKey(),
                'title' => 'Catatan yang belum selesai',
                'excerpt' => 'Ini draft. Kalau kamu melihatnya di halaman publik, ada yang salah.',
                'body' => self::body('Draft tidak boleh muncul di mana pun selain panel admin.'),
                'published_at' => null,
            ],
        );
    }

    private static function body(string $lead): string
    {
        return implode("\n\n", [
            $lead,
            'Keputusan kecil di awal proyek menentukan berapa banyak pekerjaan yang menumpuk enam bulan kemudian. Yang terasa sepele saat menulis baris pertama sering jadi hal yang paling mahal untuk diubah.',
            'Aturan praktisnya sederhana: pilih yang paling mudah dibatalkan. Kalau dua pilihan sama-sama masuk akal, ambil yang perubahannya nanti cuma menyentuh satu berkas.',
            'Sisanya adalah disiplin. Bukan alat yang menjaga konsistensi sebuah basis kode, melainkan kebiasaan menolak jalan pintas yang hanya menghemat lima menit hari ini.',
        ]);
    }
}
