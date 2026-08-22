<?php

namespace App\Filament\Admin\Widgets;

use App\Models\Post;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Carbon;

class PostStats extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        // One grouped query instead of four counts. A dashboard that fires a
        // query per tile is the first thing to get slow as data grows.
        $now = now();
        $counts = Post::query()
            ->selectRaw('count(*) as total')
            ->selectRaw('sum(case when published_at is not null and published_at <= ? then 1 else 0 end) as published', [$now])
            ->selectRaw('sum(case when published_at is null then 1 else 0 end) as drafts', [])
            ->selectRaw('sum(case when published_at > ? then 1 else 0 end) as scheduled', [$now])
            ->first();

        return [
            Stat::make('Total artikel', (int) $counts->total)
                ->description('Semua status')
                ->descriptionIcon('heroicon-m-document-text')
                ->chart($this->weeklyTrend())
                ->color('gray'),

            Stat::make('Terbit', (int) $counts->published)
                ->description('Terlihat pembaca')
                ->descriptionIcon('heroicon-m-globe-alt')
                ->color('success'),

            Stat::make('Draft', (int) $counts->drafts)
                ->description('Belum dipublikasikan')
                ->descriptionIcon('heroicon-m-pencil-square')
                ->color((int) $counts->drafts > 0 ? 'warning' : 'gray'),

            Stat::make('Terjadwal', (int) $counts->scheduled)
                ->description('Tampil otomatis nanti')
                ->descriptionIcon('heroicon-m-clock')
                ->color('info'),
        ];
    }

    /** Published posts per week for the last 8 weeks — the sparkline under the total. */
    private function weeklyTrend(): array
    {
        $since = Carbon::now()->subWeeks(7)->startOfWeek();

        $byWeek = Post::query()
            ->whereNotNull('published_at')
            ->where('published_at', '>=', $since)
            ->get(['published_at'])
            ->groupBy(fn (Post $p) => $p->published_at->startOfWeek()->toDateString())
            ->map->count();

        return collect(range(7, 0))
            ->map(fn (int $i) => (int) ($byWeek[Carbon::now()->subWeeks($i)->startOfWeek()->toDateString()] ?? 0))
            ->all();
    }
}
