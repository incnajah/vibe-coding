<?php

namespace App\Filament\Admin\Pages;

use App\Actions\Settings\SaveSettings;
use App\Support\Settings;
use Filament\Actions\Action;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use BackedEnum;
use Filament\Pages\Page;
use Filament\Schemas\Components\Actions;
use Filament\Schemas\Components\EmbeddedSchema;
use Filament\Schemas\Components\Form;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use UnitEnum;

/**
 * A Page, not a Resource: there is no list of settings to browse, and no
 * create or delete. One form, one save.
 *
 * @property-read Schema $form
 */
class ManageSettings extends Page
{
    // Generated Resources get an icon for free; a hand-written Page does not,
    // and a sidebar item with no icon is the one that looks broken.
    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCog6Tooth;

    protected static string|UnitEnum|null $navigationGroup = 'Sistem';

    protected static ?string $navigationLabel = 'Pengaturan';

    protected static ?string $title = 'Pengaturan situs';

    protected static ?int $navigationSort = 90;

    /** @var array<string, mixed>|null */
    public ?array $data = [];

    public function mount(Settings $settings): void
    {
        $this->form->fill([
            'site_title' => $settings->get('site_title'),
            'tagline' => $settings->get('tagline'),
            'favicon_path' => $settings->get('favicon_path'),
            'contact_email' => $settings->get('contact_email'),
            'posts_per_page' => $settings->get('posts_per_page'),
            'show_author' => $settings->get('show_author'),
        ]);
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Identitas situs')
                    ->description('Muncul di header, judul tab, dan hasil pencarian.')
                    ->icon('heroicon-o-identification')
                    ->columns(2)
                    ->schema([
                        TextInput::make('site_title')
                            ->label('Judul situs')
                            ->required()
                            ->maxLength(60)
                            ->helperText('Maksimal 60 karakter agar tidak terpotong di Google.'),

                        TextInput::make('contact_email')
                            ->label('Email kontak')
                            ->email()
                            ->maxLength(255),

                        Textarea::make('tagline')
                            ->label('Slogan')
                            ->rows(2)
                            ->maxLength(160)
                            ->helperText('Dipakai sebagai meta description halaman depan. Maksimal 160 karakter.')
                            ->columnSpanFull(),
                    ]),

                Section::make('Tampilan')
                    ->description('Favicon dan pengaturan daftar artikel.')
                    ->icon('heroicon-o-paint-brush')
                    ->columns(2)
                    ->schema([
                        FileUpload::make('favicon_path')
                            ->label('Favicon')
                            ->image()
                            ->disk('public')
                            ->directory('branding')
                            ->maxSize(512)
                            ->helperText('PNG atau SVG, sisi 32–512px. Maksimal 512 KB.')
                            ->columnSpanFull(),

                        TextInput::make('posts_per_page')
                            ->label('Artikel per halaman')
                            ->numeric()
                            ->minValue(1)
                            ->maxValue(48)
                            ->required(),

                        Toggle::make('show_author')
                            ->label('Tampilkan nama penulis')
                            ->helperText('Matikan untuk blog satu orang.'),
                    ]),
            ])
            ->statePath('data');
    }

    /**
     * v5 composes the page body from a schema rather than a custom Blade view.
     * Wrapping the form in Form::make() with a footer is what gives it the
     * submit handler and the sticky action bar every other panel page has.
     */
    public function content(Schema $schema): Schema
    {
        return $schema->components([
            Form::make([EmbeddedSchema::make('form')])
                ->id('form')
                ->livewireSubmitHandler('save')
                ->footer([
                    Actions::make($this->getFormActions())->key('form-actions'),
                ]),
        ]);
    }

    protected function getFormActions(): array
    {
        return [
            Action::make('save')
                ->label('Simpan')
                ->submit('save'),
        ];
    }

    public function save(SaveSettings $save): void
    {
        // Validation lives in the schema; the Action owns the write and the
        // cache invalidation. The page just wires the two together.
        $save->handle($this->form->getState());

        Notification::make()
            ->title('Pengaturan disimpan')
            ->success()
            ->send();
    }
}
