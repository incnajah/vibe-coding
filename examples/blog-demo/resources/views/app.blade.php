<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="h-full">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    @php($siteSettings = app(\App\Support\Settings::class))
    <title inertia>{{ $siteSettings->siteTitle() }}</title>
    <meta name="description" content="{{ $siteSettings->tagline() }}">
    @if ($favicon = $siteSettings->faviconUrl())
        <link rel="icon" href="{{ $favicon }}">
    @endif
    @routes
    @viteReactRefresh
    @vite(['resources/css/app.css', 'resources/js/app.tsx'])
    @inertiaHead
</head>
<body class="h-full antialiased">
    @inertia
</body>
</html>
