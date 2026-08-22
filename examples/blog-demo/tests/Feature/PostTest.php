<?php

use App\Actions\Post\CreatePost;
use App\Actions\Post\PublishPost;
use App\Actions\Post\UnpublishPost;
use App\Models\Post;
use App\Models\User;
use App\Queries\PublishedPosts;

it('creates a draft, never a published post', function () {
    $post = (new CreatePost)->handle(User::factory()->create(), [
        'title' => 'Halo Dunia',
        'body' => 'Isi artikel pertama.',
    ]);

    expect($post->published_at)->toBeNull()
        ->and($post->slug)->toBe('halo-dunia')
        ->and($post->isPublished())->toBeFalse();
});

it('derives a unique slug when titles collide', function () {
    $author = User::factory()->create();
    $a = (new CreatePost)->handle($author, ['title' => 'Sama Persis', 'body' => 'x']);
    $b = (new CreatePost)->handle($author, ['title' => 'Sama Persis', 'body' => 'y']);

    expect($a->slug)->toBe('sama-persis')
        ->and($b->slug)->toBe('sama-persis-2');
});

it('stamps published_at on publish and clears it on unpublish', function () {
    $post = Post::factory()->draft()->create();

    expect((new PublishPost)->handle($post)->published_at)->not->toBeNull();
    expect((new UnpublishPost)->handle($post->refresh())->published_at)->toBeNull();
});

it('does not move published_at when publishing twice', function () {
    $post = Post::factory()->create(['published_at' => now()->subDays(3)]);
    $first = $post->published_at;

    expect((new PublishPost)->handle($post)->published_at->timestamp)
        ->toBe($first->timestamp);
});

it('never leaks drafts or future posts to readers', function () {
    Post::factory()->count(2)->create();
    Post::factory()->draft()->create(['title' => 'Rahasia']);
    Post::factory()->create(['title' => 'Besok', 'published_at' => now()->addDay()]);

    $titles = (new PublishedPosts)->paginate()->pluck('title');

    expect($titles)->toHaveCount(2)
        ->and($titles)->not->toContain('Rahasia')
        ->and($titles)->not->toContain('Besok');
});

it('shows published posts on the index and hides drafts', function () {
    $live = Post::factory()->create(['title' => 'Terbit']);
    $draft = Post::factory()->draft()->create(['title' => 'Draft']);

    $this->get('/')->assertOk();
    $this->get("/posts/{$live->slug}")->assertOk();
    $this->get("/posts/{$draft->slug}")->assertNotFound();
});
