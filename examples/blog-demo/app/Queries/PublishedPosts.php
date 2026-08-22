<?php

namespace App\Queries;

use App\Models\Post;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

final class PublishedPosts
{
    /** Eager loads the author: the listing renders it on every row. */
    public function paginate(int $perPage = 9): LengthAwarePaginator
    {
        return Post::query()
            ->published()
            ->with('author:id,name')
            ->latest('published_at')
            ->paginate($perPage);
    }
}
