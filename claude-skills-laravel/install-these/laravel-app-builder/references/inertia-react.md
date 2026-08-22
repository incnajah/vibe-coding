# Inertia + React + shadcn/ui — Public Frontend

## Props are a contract, not a database dump

Never pass an Eloquent model straight through. It leaks every column into the page's HTML — including ones that should never reach the browser — and couples the frontend to the schema.

```php
public function show(Package $package): Response
{
    return Inertia::render('Packages/Show', [
        'package' => [
            'slug'       => $package->slug,
            'name'       => $package->name,
            'price'      => $package->base_price,
            'departures' => $package->departures->map(fn ($d) => [
                'date'  => $d->departs_on->toDateString(),
                'price' => $d->price,
                'seats' => $d->seats_total - $d->seats_taken,
            ]),
        ],
        'related' => Inertia::defer(fn () => $this->related($package)),
    ]);
}
```

Always eager load before shaping. `$package->departures` inside a map without `->with('departures')` is an N+1 that the page will not visibly report.

## Keep the initial payload small

Inertia v2 gives three tools; use them by default rather than as an optimization pass:

- `Inertia::defer(...)` for below-the-fold data — loads after first paint
- `<WhenVisible>` for sections the user may never scroll to
- Partial reloads for filters and search:

```tsx
router.get(route('packages.index'), { q }, {
  only: ['packages'],
  preserveState: true,
  replace: true,
})
```

A filter that triggers a full page visit re-sends every prop on the page. This is the most common reason an Inertia app feels slower than it should.

## Forms

Laravel validation is the source of truth. Do not build a parallel client-side schema with different rules — they drift, and the user gets an error the frontend said was fine.

```tsx
const { data, setData, post, processing, errors } = useForm({
  name: '', email: '', phone: '',
})

const submit = (e: React.FormEvent) => {
  e.preventDefault()
  post(route('inquiries.store'))
}
```

Render `errors.name` directly. Server errors arrive as props with no extra wiring.

## shadcn/ui

Components are **copied into the repo**, not installed as a dependency. They live in `resources/js/components/ui/` and are project code — edit them freely.

```bash
npx shadcn@latest init
npx shadcn@latest add button card dialog form input select
```

Add only components actually used. A bulk `add` of thirty components leaves thirty files to maintain and review.

## State

There is no need for Redux or Zustand in an Inertia app. The server is the store. State that is not server data (open/closed dialogs, form drafts) stays local with `useState`. Reaching for a global store in an Inertia app usually means props are being fought rather than used.

## Structure

```
resources/js/
├── Pages/            # one file per Inertia::render target — mirrors the render string
│   ├── Packages/Index.tsx
│   └── Packages/Show.tsx
├── Layouts/
│   └── PublicLayout.tsx
├── components/
│   ├── ui/           # shadcn — copied, yours to edit
│   └── <feature>/    # app components
└── lib/utils.ts
```

Persistent layout so navigation does not remount the shell:

```tsx
Index.layout = (page: React.ReactNode) => <PublicLayout>{page}</PublicLayout>
```

## SEO — `<Head>` is not enough, and this is measurable

```tsx
import { Head } from '@inertiajs/react'
<Head>
  <title>{package.name}</title>
  <meta name="description" content={package.metaDescription} />
</Head>
```

That sets the title **in the browser, after hydration.** The HTML the server sends still carries whatever `app.blade.php` hardcoded. Verified on a real page: `<Head><title>{post.title}</title></Head>` renders correctly for a human, while `curl` of the same URL returns `<title>Laravel</title>` and no description tag at all.

So: fine for users, useless for any crawler that does not execute JavaScript.

Three honest options, in increasing cost:

1. **Serve that content from Blade instead.** A catalogue or article page is mostly static; Blade renders real metadata with no extra moving parts. This is usually the right answer.
2. **Turn on Inertia SSR** — `php artisan inertia:start-ssr`, plus a Node process to keep alive in production. Real added operational cost.
3. **Inject the title server-side** into the Blade view for the routes that matter, and accept `<Head>` for the rest.

If SEO is a stated requirement, raise this at the ERD gate in one sentence rather than deciding silently. Shipping a client-rendered SPA to a client who expects Google traffic is the kind of gap that surfaces months later.

## Reading the payload

The props Inertia sends are in a JSON script tag, not an HTML attribute — the older `data-page="..."` attribute form is gone:

```bash
curl -s http://127.0.0.1:8000/ | grep -o 'data-page="app"[^>]*>{.*}</script>'
```

Check its size on any page that feels slow. Props the page never reads are pure weight on every visit.

## WhatsApp integration

It is a link, not an API. Build the URL server-side so the message template lives in one place:

```php
'whatsappUrl' => 'https://wa.me/' . config('contact.whatsapp')
    . '?text=' . urlencode("Halo, saya tertarik dengan paket {$package->name}"),
```

## Verification checklist per page

- Query count in Debugbar is in single digits
- the JSON payload in the `data-page="app"` script tag is not carrying unused props
- Browser console has zero errors
- Form validation errors render from the server
- Page works on a 375px viewport
