<?php

use App\Filament\Admin\Resources\Posts\Pages\ListPosts;
use App\Filament\Admin\Widgets\LatestPosts;
use App\Filament\Admin\Widgets\PostStats;
use App\Models\Post;
use App\Models\User;
use Filament\Facades\Filament;
use Livewire\Livewire;

beforeEach(function () {
    $this->admin = User::factory()->create(['is_admin' => true]);
    Filament::setCurrentPanel('admin');
});

it('blocks non-admins from the panel', function () {
    $this->actingAs(User::factory()->create(['is_admin' => false]))
        ->get('/admin')
        ->assertForbidden();
});

it('reaches the dashboard', function () {
    $this->actingAs($this->admin)->get('/admin')->assertOk();
});

it('lists both published posts and drafts', function () {
    $live = Post::factory()->create(['title' => 'Artikel Terbit', 'user_id' => $this->admin->id]);
    $draft = Post::factory()->draft()->create(['title' => 'Artikel Draft', 'user_id' => $this->admin->id]);

    $this->actingAs($this->admin)->get('/admin/posts')->assertOk();

    // The table uses deferLoading(), so rows arrive in a follow-up Livewire
    // request and are absent from the first HTML response. Assert against the
    // component, not the response body.
    Livewire::actingAs($this->admin)
        ->test(ListPosts::class)
        // deferLoading() means rows are not fetched until the table loads.
        ->loadTable()
        // Admin sees both, unlike the public side which only sees published.
        ->assertCanSeeTableRecords([$live, $draft]);
});

it('creates a post through the panel form', function () {
    $this->actingAs($this->admin)->get('/admin/posts/create')->assertOk();

    Livewire::actingAs($this->admin)
        ->test(\App\Filament\Admin\Resources\Posts\Pages\CreatePost::class)
        ->fillForm([
            'user_id' => $this->admin->id,
            'title' => 'Ditulis lewat panel',
            'slug' => 'ditulis-lewat-panel',
            'body' => "Paragraf pertama.\n\nParagraf kedua.",
        ])
        ->call('create')
        ->assertHasNoFormErrors();

    expect(Post::where('slug', 'ditulis-lewat-panel')->exists())->toBeTrue();
});

it('edits a post through the panel form', function () {
    $post = Post::factory()->create(['title' => 'Judul Lama', 'user_id' => $this->admin->id]);

    $this->actingAs($this->admin)->get("/admin/posts/{$post->getKey()}/edit")->assertOk();

    Livewire::actingAs($this->admin)
        ->test(\App\Filament\Admin\Resources\Posts\Pages\EditPost::class, ['record' => $post->getKey()])
        ->fillForm(['title' => 'Judul Baru'])
        ->call('save')
        ->assertHasNoFormErrors();

    expect($post->refresh()->title)->toBe('Judul Baru');
});

it('publishes and unpublishes from the table action', function () {
    $post = Post::factory()->draft()->create(['user_id' => $this->admin->id]);

    Livewire::actingAs($this->admin)
        ->test(ListPosts::class)
        ->callTableAction('publish', $post)
        ->assertHasNoTableActionErrors();

    expect($post->refresh()->published_at)->not->toBeNull();

    Livewire::actingAs($this->admin)
        ->test(ListPosts::class)
        ->callTableAction('unpublish', $post)
        ->assertHasNoTableActionErrors();

    expect($post->refresh()->published_at)->toBeNull();
});

it('deletes a post', function () {
    $post = Post::factory()->create(['user_id' => $this->admin->id]);

    Livewire::actingAs($this->admin)
        ->test(\App\Filament\Admin\Resources\Posts\Pages\EditPost::class, ['record' => $post->getKey()])
        ->callAction('delete');

    expect(Post::find($post->getKey()))->toBeNull();
});

it('shows real stats on the dashboard, not Filament boilerplate', function () {
    Post::factory()->count(3)->create(['user_id' => $this->admin->id]);
    Post::factory()->draft()->create(['user_id' => $this->admin->id]);

    // The stock widgets must be gone: a "Welcome" card and a link to Filament's
    // own docs are the clearest sign of a panel nobody finished.
    $this->actingAs($this->admin)->get('/admin')->assertOk()
        ->assertDontSee('filamentphp.com/docs')
        ->assertDontSee('fi-account-widget')
        ->assertDontSee('fi-filament-info-widget');

    // Filament widgets render lazily, so their content is not in the first
    // response. Assert the component itself.
    Livewire::actingAs($this->admin)
        ->test(PostStats::class)
        ->assertSee('Total artikel')
        ->assertSee('Terbit')
        ->assertSee('Draft')
        ->assertSee('Terjadwal');

    Livewire::actingAs($this->admin)
        ->test(LatestPosts::class)
        ->assertSee('Artikel terbaru');
});
