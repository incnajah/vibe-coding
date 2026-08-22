<?php

namespace App\Http\Controllers;

use App\Models\Post;
use App\Queries\PublishedPosts;
use App\Support\Settings;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Inertia\Response;

class PostController extends Controller
{
    public function index(PublishedPosts $published, Settings $settings): Response
    {
        // Page size is a setting, not a magic number in a controller.
        $posts = $published->paginate($settings->postsPerPage());

        return Inertia::render('Posts/Index', [
            // Shaped explicitly. Passing the model through would leak every column
            // into the page HTML and tie the frontend to the schema.
            'posts' => [
                'data' => $posts->through(fn (Post $post) => [
                    'slug' => $post->slug,
                    'title' => $post->title,
                    'excerpt' => $post->excerpt,
                    'author' => $post->author?->name,
                    'publishedAt' => $post->published_at?->toDateString(),
                    'readingMinutes' => $this->readingMinutes($post->body),
                ])->items(),
                'nextPageUrl' => $posts->nextPageUrl(),
                'prevPageUrl' => $posts->previousPageUrl(),
            ],
        ]);
    }

    public function show(string $slug): Response
    {
        $post = Post::query()->published()->with('author:id,name')
            ->where('slug', $slug)
            ->firstOrFail();

        return Inertia::render('Posts/Show', [
            'post' => [
                'title' => $post->title,
                'excerpt' => $post->excerpt,
                'paragraphs' => preg_split('/\n{2,}/', trim($post->body)) ?: [],
                'author' => $post->author?->name,
                'publishedAt' => $post->published_at?->toDateString(),
                'readingMinutes' => $this->readingMinutes($post->body),
            ],
        ]);
    }

    private function readingMinutes(string $body): int
    {
        return max(1, (int) ceil(Str::wordCount(strip_tags($body)) / 200));
    }
}
