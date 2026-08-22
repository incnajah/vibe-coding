<?php

namespace App\Actions\Post;

use App\Models\Post;

final class UnpublishPost
{
    public function handle(Post $post): Post
    {
        $post->update(['published_at' => null]);

        return $post->refresh();
    }
}
