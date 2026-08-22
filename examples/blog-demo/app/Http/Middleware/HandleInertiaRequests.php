<?php

namespace App\Http\Middleware;

use App\Support\Settings;
use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function version(Request $request): ?string
    {
        return parent::version($request);
    }

    /**
     * Site identity is shared, not repeated in every controller. It is read
     * from one cached call, so this costs nothing per request.
     *
     * @return array<string, mixed>
     */
    public function share(Request $request): array
    {
        $settings = app(Settings::class);

        return [
            ...parent::share($request),
            'site' => [
                'title' => $settings->siteTitle(),
                'tagline' => $settings->tagline(),
                'showAuthor' => $settings->showAuthor(),
            ],
        ];
    }
}
