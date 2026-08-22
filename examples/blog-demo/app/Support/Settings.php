<?php

namespace App\Support;

use App\Models\Setting;
use Illuminate\Support\Facades\Cache;

/**
 * The only way settings are read. Scattering Setting::where('key', ...) around
 * the app means no cache, no defaults, and a typo in a key returning null with
 * no complaint.
 */
final class Settings
{
    private const CACHE_KEY = 'settings.all';

    /** Defaults live in code, so a missing row is never a 500. */
    public const DEFAULTS = [
        'site_title' => 'Catatan',
        'tagline' => 'Tulisan pendek tentang apa pun yang sedang dikerjakan.',
        'favicon_path' => null,
        'contact_email' => null,
        'posts_per_page' => 9,
        'show_author' => true,
    ];

    public function all(): array
    {
        $stored = Cache::rememberForever(
            self::CACHE_KEY,
            fn () => Setting::query()->pluck('value', 'key')->all(),
        );

        return [...self::DEFAULTS, ...$stored];
    }

    public function get(string $key, mixed $default = null): mixed
    {
        return $this->all()[$key] ?? $default ?? self::DEFAULTS[$key] ?? null;
    }

    public function forget(): void
    {
        Cache::forget(self::CACHE_KEY);
    }

    // Typed accessors at the edges: one place to change a key, one place to
    // guarantee the shape.
    public function siteTitle(): string
    {
        return (string) $this->get('site_title');
    }

    public function tagline(): string
    {
        return (string) $this->get('tagline');
    }

    public function faviconUrl(): ?string
    {
        $path = $this->get('favicon_path');

        return $path ? asset('storage/'.$path) : null;
    }

    public function postsPerPage(): int
    {
        return max(1, (int) $this->get('posts_per_page'));
    }

    public function showAuthor(): bool
    {
        return (bool) $this->get('show_author');
    }
}
