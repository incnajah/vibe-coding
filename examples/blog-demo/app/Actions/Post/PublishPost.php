<?php

namespace App\Actions\Post;

use App\Models\Post;

final class PublishPost
{
    public function handle(Post $post): Post
    {
        if ($post->published_at !== null) {
            return $post;
        }

        $post->update(['published_at' => now()]);

        return $post->refresh();
    }
}
