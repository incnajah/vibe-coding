# Filament — Admin Panel

## Generate, do not hand-write

```bash
php artisan make:filament-resource Package --generate --view
php artisan make:filament-relation-manager PackageResource departures departs_on
php artisan make:filament-user
```

`--generate` reads the migration and produces form and table schemas matching the installed Filament version. Hand-written Resources drift from the actual API, which is exactly the failure this skill is trying to avoid.

## Form layout — sections, never a flat list

`--generate` emits every column as a flat list of fields. That is a starting point, not a form. Eight stacked inputs means the writer scrolls past publishing controls to reach the body, every time they edit.

Group into **sections**, and split the work from the decisions about the work:

```php
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;

return $schema->components([
    Grid::make(3)->schema([
        Section::make('Konten')
            ->description('Judul, ringkasan, dan isi.')
            ->icon('heroicon-o-document-text')
            ->schema([ /* the thing being made */ ])
            ->columnSpan(2),

        Section::make('Publikasi')
            ->description('Siapa menulis, dan kapan tampil.')
            ->icon('heroicon-o-paper-airplane')
            ->schema([ /* status, author, dates, visibility */ ])
            ->columnSpan(1),
    ]),
])->columns(1);
```

Rules that make this consistent across every resource in the panel:

- **Two columns: content 2/3, meta 1/3.** The main artifact on the left; author, status, dates, and flags on the right. Same split everywhere, so an admin never hunts for the publish control.
- **Every section gets a description.** One line saying what belongs in it. It is the cheapest documentation in the app and it sits exactly where the question is asked.
- **Long text spans the full width** of its section. A `Textarea` in a half-column is unusable.
- **`->helperText()` on anything with a rule** — a slug that must not change after publishing, a field that is derived when left blank. Say it at the field, not in a wiki.
- **More than about ten fields → `Tabs`,** not a longer page. Beyond that, scrolling hides state and people miss required fields.
- **Never `Section::make()` with no title** just to draw a box. A card with no label is decoration.

`Fieldset` groups related fields *inside* a section; `Section` is the card. Do not nest sections in sections — the nesting reads as hierarchy that is not there.

## Non-negotiables

**Panel access in production.** Implement `FilamentUser` on the User model. Without it, Filament blocks access outside `local` and the user reports "works on my machine, 403 on the server."

```php
class User extends Authenticatable implements FilamentUser
{
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->is_admin; // or a role check
    }
}
```

**Policies, not inline checks.** Filament respects Laravel policies automatically. Generate them (`php artisan make:policy PackagePolicy --model=Package`) rather than reimplementing authorization inside Resources.

**Relation managers for one-to-many.** Repeaters are for embedded/JSON-ish structures, not for editing related records. Using a repeater where a relation manager belongs produces sync bugs that are painful to trace.

**Media through a library.** `SpatieMediaLibraryFileUpload` so admin and frontend read images through one abstraction, with conversions defined once on the model.

## The dashboard — always replace the stock one

Filament scaffolds `/admin` with two widgets, and **both must go, every time**:

- `AccountWidget` — a "Welcome, Admin" card with a sign-out button that already exists in the user menu
- `FilamentInfoWidget` — Filament's own logo, version number, and links to its documentation

Neither says one word about the client's data. A panel that opens on them is the clearest possible signal that nobody finished the job — and it is the first screen the client sees, every single day.

Remove them from the panel provider:

```php
->widgets([])   // AccountWidget and FilamentInfoWidget deleted, imports too
->discoverWidgets(in: app_path('Filament/Admin/Widgets'), for: 'App\Filament\Admin\Widgets')
```

Then build a dashboard that answers *"what should I look at today?"*

**Row one — stat cards.** Three to five, no more. Each is a number the owner would actually check, with a one-line description and a colour that means something.

```php
class PostStats extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        // One grouped query, not one per tile. A dashboard that fires a query
        // per card is the first thing to get slow as the data grows.
        $c = Post::query()
            ->selectRaw('count(*) as total')
            ->selectRaw('sum(case when published_at is not null then 1 else 0 end) as published')
            ->first();

        return [
            Stat::make('Total artikel', (int) $c->total)
                ->description('Semua status')
                ->descriptionIcon('heroicon-m-document-text')
                ->chart($this->weeklyTrend())      // sparkline: trend beats a number
                ->color('gray'),
            Stat::make('Terbit', (int) $c->published)
                ->description('Terlihat pembaca')
                ->color('success'),
        ];
    }
}
```

**Row two — a table widget** of the five most recently touched records, `->paginated(false)`, `columnSpan('full')`. It answers "what changed?" without a click.

**Optionally a chart** — but only where a trend actually informs a decision. A chart of four data points is decoration.

Rules that keep dashboards useful rather than decorative:

- **Every tile is a number someone acts on.** "Total users" on a site with one user is noise. If nobody would change behaviour based on it, cut it.
- **Colour carries meaning.** `success` for healthy, `warning` for something needing attention, `gray` for neutral. A dashboard where everything is green teaches people to ignore green.
- **One query per widget, not per tile.** Aggregate with conditional sums.
- **Set `protected static ?int $sort`** on each widget or the order changes between environments.
- **Test the widgets, not just the page.** They render lazily, so `$this->get('/admin')->assertSee('Total artikel')` fails on a perfectly working dashboard. Use `Livewire::test(PostStats::class)->assertSee(...)`.

Assert the boilerplate is actually gone, or it quietly comes back on the next scaffold:

```php
$this->actingAs($admin)->get('/admin')
    ->assertDontSee('filamentphp.com/docs')
    ->assertDontSee('fi-account-widget');
```

## Table performance

Filament tables render every visible row server-side. On any table expected to grow:

```php
->deferLoading()
->paginated([25, 50, 100])
->defaultSort('created_at', 'desc')
```

Never compute a value per row in PHP that the query could compute. A `->getStateUsing()` closure that touches a relationship is an N+1 on every page load — eager load it on the table query instead:

```php
->modifyQueryUsing(fn (Builder $query) => $query->with(['muthowif', 'media']))
```

## Custom actions call Actions

```php
Action::make('publish')
    ->icon('heroicon-o-check-circle')
    ->requiresConfirmation()
    ->visible(fn (Package $record) => ! $record->published_at)
    ->action(fn (Package $record, PublishPackage $publish) => $publish->handle($record))
    ->successNotificationTitle('Paket dipublikasikan');
```

The closure contains no logic. It resolves an Action class and calls it. If a closure grows past three lines, the logic belongs in `app/Actions/`.

## Multi-tenancy

Filament v4+ scopes all panel queries to the current tenant automatically and associates new records via model events. On v3, only tables, URL resolution, and global search are scoped — relation managers, custom pages, and actions need manual scoping, which is a genuine security footgun. If a v3 project needs tenancy, say so explicitly.

## Testing admin flows

Filament ships testing helpers. Cover the flows that would actually break something — create, edit, custom actions, authorization — not exhaustive coverage of generated CRUD.

Drive the panel, do not just assert the page returns 200. These are the calls that matter:

```php
Livewire::test(ListPosts::class)->loadTable()->assertCanSeeTableRecords([$a, $b]);
Livewire::test(CreatePost::class)->fillForm([...])->call('create')->assertHasNoFormErrors();
Livewire::test(EditPost::class, ['record' => $id])->fillForm([...])->call('save');
Livewire::test(ListPosts::class)->callTableAction('publish', $post)->assertHasNoTableActionErrors();
Livewire::test(EditPost::class, ['record' => $id])->callAction('delete');
```

```php
it('publishes a package', function () {
    $package = Package::factory()->unpublished()->create();

    livewire(EditPackage::class, ['record' => $package->getKey()])
        ->callAction('publish')
        ->assertHasNoActionErrors();

    expect($package->refresh()->published_at)->not->toBeNull();
});
```

## Common runtime failures and their causes

| Symptom | Usual cause |
|---|---|
| `/admin/login` returns 404 | v5 does not call `->login()` in the generated panel provider — add it, or nobody can sign in |
| Every generated admin link 404s | The model overrides `getRouteKeyName()` (e.g. to `slug`) for public URLs. Filament derives its record routes from the same key, so `/admin/posts/{id}/edit` stops resolving. Leave the route key alone and bind the slug explicitly in the public route instead |
| `assertCanSeeTableRecords` finds nothing | The table uses `deferLoading()`, so rows are not fetched until the table loads. Call `->loadTable()` first in the test |
| 403 on `/admin` in production | `canAccessPanel()` not implemented |
| Styles broken after deploy | `php artisan filament:assets` not run; or app CSS merged into the panel |
| Upload works locally, 404 in production | `php artisan storage:link` missing, or wrong `default_filesystem_disk` |
| Action fires but nothing happens | Queue worker not running |
| Slow table | N+1 from a `getStateUsing` closure touching relations |
