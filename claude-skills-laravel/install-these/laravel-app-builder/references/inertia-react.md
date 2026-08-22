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

## SEO

Inertia renders client-side, so pages need explicit head management or they ship empty metadata:

```tsx
import { Head } from '@inertiajs/react'
<Head>
  <title>{package.name}</title>
  <meta name="description" content={package.metaDescription} />
</Head>
```

If SEO is a stated requirement and the content is mostly static, flag it at the ERD gate: Blade would serve that content better than a client-rendered SPA, and SSR is real added complexity. This is worth one sentence to the user, not a silent decision either way.

## WhatsApp integration

It is a link, not an API. Build the URL server-side so the message template lives in one place:

```php
'whatsappUrl' => 'https://wa.me/' . config('contact.whatsapp')
    . '?text=' . urlencode("Halo, saya tertarik dengan paket {$package->name}"),
```

## Verification checklist per page

- Query count in Debugbar is in single digits
- `data-page` payload is not carrying unused props
- Browser console has zero errors
- Form validation errors render from the server
- Page works on a 375px viewport
