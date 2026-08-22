<?php

namespace App\Filament\Admin\Widgets;

use App\Models\Post;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget;
use Illuminate\Database\Eloquent\Builder;

class LatestPosts extends TableWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    public function table(Table $table): Table
    {
        return $table
            ->heading('Artikel terbaru')
            ->description('Lima tulisan terakhir yang disentuh.')
            ->query(
                Post::query()->with('author:id,name')->latest('updated_at')->limit(5)
            )
            ->paginated(false)
            ->columns([
                TextColumn::make('title')->label('Judul')->limit(50)->weight('medium'),
                TextColumn::make('author.name')->label('Penulis'),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->state(fn (Post $record) => match (true) {
                        $record->published_at === null => 'Draft',
                        $record->published_at->isFuture() => 'Terjadwal',
                        default => 'Terbit',
                    })
                    ->color(fn (string $state) => match ($state) {
                        'Terbit' => 'success',
                        'Terjadwal' => 'warning',
                        default => 'gray',
                    }),
                TextColumn::make('updated_at')->label('Diubah')->since(),
            ]);
    }
}
