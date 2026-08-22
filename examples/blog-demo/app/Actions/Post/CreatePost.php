<?php

namespace App\Actions\Post;

use App\Models\Post;
use App\Models\User;
use Illuminate\Support\Str;

final class CreatePost
{
    /** @param array{title:string, body:string, excerpt?:string|null} $data */
    public function handle(User $author, array $data): Post
    {
        return Post::create([
            'user_id' => $author->getKey(),
            'title' => $data['title'],
            'slug' => $this->uniqueSlug($data['title']),
            'excerpt' => $data['excerpt'] ?? Str::limit(strip_tags($data['body']), 160),
            'body' => $data['body'],
            'published_at' => null,
        ]);
    }

    /** Slug collisions are a unique-constraint violation, not a rare edge case. */
    private function uniqueSlug(string $title): string
    {
        $base = Str::slug($title) ?: 'post';
        $slug = $base;
        $n = 1;

        while (Post::where('slug', $slug)->exists()) {
            $slug = $base.'-'.(++$n);
        }

        return $slug;
    }
}
