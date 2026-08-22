<?php

use App\Actions\Settings\SaveSettings;
use App\Filament\Admin\Pages\ManageSettings;
use App\Models\Setting;
use App\Models\User;
use App\Support\Settings;
use Livewire\Livewire;

beforeEach(function () {
    $this->admin = User::factory()->create(['is_admin' => true]);
});

it('falls back to defaults when nothing is stored', function () {
    $settings = app(Settings::class);

    expect($settings->siteTitle())->toBe('Catatan')
        ->and($settings->postsPerPage())->toBe(9)
        ->and($settings->faviconUrl())->toBeNull();
});

it('adds a brand new setting without a migration', function () {
    // The whole point of key-value: this key did not exist a second ago.
    app(SaveSettings::class)->handle(['whatsapp_number' => '628123456789']);

    expect(app(Settings::class)->get('whatsapp_number'))->toBe('628123456789');
});

it('keeps types intact through the json column', function () {
    app(SaveSettings::class)->handle(['show_author' => false, 'posts_per_page' => 12]);

    $fresh = app(Settings::class);
    $fresh->forget();

    expect($fresh->get('show_author'))->toBeFalse()
        ->and($fresh->get('posts_per_page'))->toBe(12);
});

it('invalidates the cache on write', function () {
    $settings = app(Settings::class);
    expect($settings->siteTitle())->toBe('Catatan');

    app(SaveSettings::class)->handle(['site_title' => 'Blog Baru']);

    expect(app(Settings::class)->siteTitle())->toBe('Blog Baru');
});

it('saves the settings form from the panel', function () {
    Livewire::actingAs($this->admin)
        ->test(ManageSettings::class)
        ->fillForm([
            'site_title' => 'Jurnal Harian',
            'tagline' => 'Ditulis pelan-pelan.',
            'contact_email' => 'halo@example.com',
            'posts_per_page' => 6,
            'show_author' => false,
        ])
        ->call('save')
        ->assertHasNoFormErrors();

    $settings = app(Settings::class);
    expect($settings->siteTitle())->toBe('Jurnal Harian')
        ->and($settings->tagline())->toBe('Ditulis pelan-pelan.')
        ->and($settings->postsPerPage())->toBe(6)
        ->and($settings->showAuthor())->toBeFalse();
});

it('rejects a title longer than the search-result limit', function () {
    Livewire::actingAs($this->admin)
        ->test(ManageSettings::class)
        ->fillForm(['site_title' => str_repeat('a', 61)])
        ->call('save')
        ->assertHasFormErrors(['site_title']);
});

it('stores settings as rows, not columns', function () {
    app(SaveSettings::class)->handle(['site_title' => 'X', 'tagline' => 'Y']);

    expect(Setting::pluck('key')->sort()->values()->all())->toBe(['site_title', 'tagline']);
});

it('applies the site title and tagline to the public page', function () {
    app(SaveSettings::class)->handle([
        'site_title' => 'Warung Kata',
        'tagline' => 'Sepiring tulisan setiap minggu.',
    ]);

    $res = $this->get('/')->assertOk();

    $res->assertSee('Warung Kata', escape: false)
        ->assertSee('Sepiring tulisan setiap minggu.', escape: false);
});

it('applies posts_per_page to the public listing', function () {
    \App\Models\Post::factory()->count(7)->create(['user_id' => $this->admin->id]);

    app(SaveSettings::class)->handle(['posts_per_page' => 3]);

    $html = $this->get('/')->getContent();
    preg_match('/data-page="app"[^>]*>(\{.*?\})<\/script>/s', $html, $m);
    $props = json_decode($m[1], true);

    expect($props['props']['posts']['data'])->toHaveCount(3);
});

it('renders a favicon link only when one is set', function () {
    $this->get('/')->assertDontSee('rel="icon"', escape: false);

    app(SaveSettings::class)->handle(['favicon_path' => 'branding/icon.png']);

    $this->get('/')->assertSee('rel="icon"', escape: false)
        ->assertSee('branding/icon.png', escape: false);
});
