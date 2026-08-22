<?php

namespace App\Filament\Admin\Resources\Posts\Tables;

use App\Actions\Post\PublishPost;
use App\Actions\Post\UnpublishPost;
use App\Models\Post;
use Filament\Actions\Action;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class PostsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            // Eager load the author: without this the name column is an N+1 on
            // every page of the table.
            ->modifyQueryUsing(fn (Builder $query) => $query->with('author:id,name'))
            ->defaultSort('created_at', 'desc')
            ->deferLoading()
            ->paginated([25, 50, 100])
            ->columns([
                TextColumn::make('title')
                    ->label('Judul')
                    ->searchable()
                    ->limit(60)
                    ->weight('medium'),

                TextColumn::make('author.name')
                    ->label('Penulis')
                    ->sortable()
                    ->toggleable(),

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

                TextColumn::make('published_at')
                    ->label('Terbit')
                    ->dateTime('d M Y, H:i')
                    ->placeholder('—')
                    ->sortable(),
            ])
            ->filters([
                TernaryFilter::make('published_at')
                    ->label('Sudah terbit')
                    ->nullable(),
            ])
            ->recordActions([
                // The closure resolves an Action class and calls it. No logic here:
                // the same sequence must run whether it is triggered from the panel
                // or from a controller.
                Action::make('publish')
                    ->label('Terbitkan')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->visible(fn (Post $record) => $record->published_at === null)
                    ->action(fn (Post $record) => app(PublishPost::class)->handle($record))
                    ->successNotificationTitle('Artikel diterbitkan'),

                Action::make('unpublish')
                    ->label('Tarik')
                    ->icon('heroicon-o-eye-slash')
                    ->color('gray')
                    ->requiresConfirmation()
                    ->visible(fn (Post $record) => $record->published_at !== null)
                    ->action(fn (Post $record) => app(UnpublishPost::class)->handle($record))
                    ->successNotificationTitle('Artikel ditarik dari publik'),

                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
