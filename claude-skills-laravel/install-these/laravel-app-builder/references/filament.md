# Filament — Admin Panel

## Generate, do not hand-write

```bash
php artisan make:filament-resource Package --generate --view
php artisan make:filament-relation-manager PackageResource departures departs_on
php artisan make:filament-user
```

`--generate` reads the migration and produces form and table schemas matching the installed Filament version. Hand-written Resources drift from the actual API, which is exactly the failure this skill is trying to avoid.

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
| 403 on `/admin` in production | `canAccessPanel()` not implemented |
| Styles broken after deploy | `php artisan filament:assets` not run; or app CSS merged into the panel |
| Upload works locally, 404 in production | `php artisan storage:link` missing, or wrong `default_filesystem_disk` |
| Action fires but nothing happens | Queue worker not running |
| Slow table | N+1 from a `getStateUsing` closure touching relations |
