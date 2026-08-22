<?php

namespace App\Filament\Admin\Resources\Posts\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\Str;

class PostForm
{
    /**
     * Two columns: the work on the left, the decisions about it on the right.
     * A flat list of eight fields makes the writer scroll past publishing
     * controls to reach the body, every single time.
     */
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Grid::make(3)
                    ->schema([
                        self::content()->columnSpan(2),
                        self::sidebar()->columnSpan(1),
                    ]),
            ])
            ->columns(1);
    }

    private static function content(): Section
    {
        return Section::make('Konten')
            ->description('Judul, ringkasan, dan isi artikel.')
            ->icon('heroicon-o-document-text')
            ->schema([
                TextInput::make('title')
                    ->label('Judul')
                    ->required()
                    ->maxLength(255)
                    ->live(onBlur: true)
                    // Only derive the slug while creating. Changing it after
                    // publication breaks every link already shared.
                    ->afterStateUpdated(function (string $operation, $state, callable $set) {
                        if ($operation === 'create') {
                            $set('slug', Str::slug((string) $state));
                        }
                    })
                    ->columnSpanFull(),

                TextInput::make('slug')
                    ->required()
                    ->maxLength(255)
                    ->unique(ignoreRecord: true)
                    ->prefix('/posts/')
                    ->helperText('Bagian URL. Hindari mengubahnya setelah terbit.')
                    ->columnSpanFull(),

                TextInput::make('excerpt')
                    ->label('Ringkasan')
                    ->maxLength(255)
                    ->helperText('Muncul di daftar artikel. Kosongkan untuk diambil otomatis dari isi.')
                    ->columnSpanFull(),

                Textarea::make('body')
                    ->label('Isi')
                    ->required()
                    ->rows(20)
                    ->helperText('Pisahkan paragraf dengan satu baris kosong.')
                    ->columnSpanFull(),
            ]);
    }

    private static function sidebar(): Section
    {
        return Section::make('Publikasi')
            ->description('Siapa menulis, dan kapan tampil.')
            ->icon('heroicon-o-paper-airplane')
            ->schema([
                Select::make('user_id')
                    ->label('Penulis')
                    ->relationship('author', 'name')
                    ->default(fn () => auth()->id())
                    ->searchable()
                    ->preload()
                    ->required(),

                DateTimePicker::make('published_at')
                    ->label('Diterbitkan pada')
                    ->seconds(false)
                    ->helperText('Kosong berarti draft. Tanggal di masa depan belum tampil.'),
            ]);
    }
}
