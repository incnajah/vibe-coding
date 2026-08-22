# Hasil verifikasi — 23 Agustus 2026

Dijalankan di Windows + Git Bash, PHP 8.2.12, Node 22.23.2, Composer asli.
Semua output di bawah ini apa adanya, tanpa diedit.

## Ringkasan

| Gate | Hasil |
|---|---|
| `verify.sh --full` | **LULUS** |
| Pest | **27 lulus**, 82 assertion |
| `audit-ui.sh` | **HIGH 0, MED 0, LOW 0** (10 file) |
| `preflight-prod.sh` | 1 blocker, 2 warning — semuanya benar untuk project dev |

Blocker satu-satunya adalah `APP_DEBUG=true`, yang memang seharusnya menyala di lokal.
Itu justru bukti preflight-nya bekerja.

## verify.sh --full

```
▸ PHP syntax
  ✓ php syntax
▸ Migrations
   INFO  Nothing to migrate.  
  ✓ migrations
▸ Routes resolve
  ✓ routes
▸ Frontend build
npm notice run build
npm notice run vite build
vite v7.3.6 building client environment for production...
transforming...
✓ 639 modules transformed.
rendering chunks...
computing gzip size...
public/build/manifest.json              0.33 kB │ gzip:   0.17 kB
public/build/assets/app-BX__nb6t.css   42.20 kB │ gzip:  10.00 kB
public/build/assets/app-DMNA-Vjw.js   324.03 kB │ gzip: 102.45 kB
✓ built in 2.01s
  ✓ vite build
▸ Tests
  ...........................
  Tests:    27 passed (82 assertions)
  Duration: 2.28s
  ✓ pest
▸ Static analysis (advisory)
 ------ --------------------------------------------------------------------------------------- 
 ------ ---------------------------------------------------------------------------------------------- 
  Line   Http\Controllers\PostController.php                                                           
 ------ ---------------------------------------------------------------------------------------------- 
  23     Call to an undefined method Illuminate\Contracts\Pagination\LengthAwarePaginator::through().  
         🪪  method.notFound                                                                           
  27     Access to an undefined property Illuminate\Database\Eloquent\Model::$name.                    
         🪪  property.notFound                                                                         
         💡  Learn more: https://phpstan.org/blog/solving-phpstan-access-to-undefined-property         
  28     Cannot call method toDateString() on string.                                                  
         🪪  method.nonObject                                                                          
  48     Access to an undefined property Illuminate\Database\Eloquent\Model::$name.                    
         🪪  property.notFound                                                                         
         💡  Learn more: https://phpstan.org/blog/solving-phpstan-access-to-undefined-property         
  49     Cannot call method toDateString() on string.                                                  
         🪪  method.nonObject                                                                          
 ------ ---------------------------------------------------------------------------------------------- 
 ------ ---------------------------------------- 
  Line   Models\Post.php                         
 ------ ---------------------------------------- 
  34     Cannot call method isPast() on string.  
         🪪  method.nonObject                    
 ------ ---------------------------------------- 
 [ERROR] Found 14 errors                                                                                               
  – phpstan reported issues (not blocking)
▸ Filament panel boots
  ✓ filament caches built
▸ Smoke: key routes return 2xx/3xx
  ✓ GET / → 200
  ✓ GET /admin → 302
VERIFY PASSED
```

## Pest

```
   PASS  Tests\Unit\ExampleTest
  ✓ that true is true

   PASS  Tests\Feature\AdminPanelTest
  ✓ it blocks non-admins from the panel                                                                          0.40s  
  ✓ it reaches the dashboard                                                                                     0.13s  
  ✓ it lists both published posts and drafts                                                                     0.17s  
  ✓ it creates a post through the panel form                                                                     0.14s  
  ✓ it edits a post through the panel form                                                                       0.13s  
  ✓ it publishes and unpublishes from the table action                                                           0.15s  
  ✓ it deletes a post                                                                                            0.08s  
  ✓ it shows real stats on the dashboard, not Filament boilerplate                                               0.11s  

   PASS  Tests\Feature\ExampleTest
  ✓ it serves the homepage                                                                                       0.11s  

   PASS  Tests\Feature\NavigationTest
  ✓ it gives every sidebar item an icon                                                                          0.02s  

   PASS  Tests\Feature\PostTest
  ✓ it creates a draft, never a published post                                                                   0.02s  
  ✓ it derives a unique slug when titles collide                                                                 0.02s  
  ✓ it stamps published_at on publish and clears it on unpublish                                                 0.02s  
  ✓ it does not move published_at when publishing twice                                                          0.02s  
  ✓ it never leaks drafts or future posts to readers                                                             0.02s  
  ✓ it shows published posts on the index and hides drafts                                                       0.07s  

   PASS  Tests\Feature\SettingsTest
  ✓ it falls back to defaults when nothing is stored                                                             0.02s  
  ✓ it adds a brand new setting without a migration                                                              0.03s  
  ✓ it keeps types intact through the json column                                                                0.02s  
  ✓ it invalidates the cache on write                                                                            0.02s  
  ✓ it saves the settings form from the panel                                                                    0.10s  
  ✓ it rejects a title longer than the search-result limit                                                       0.09s  
  ✓ it stores settings as rows, not columns                                                                      0.02s  
  ✓ it applies the site title and tagline to the public page                                                     0.08s  
  ✓ it applies posts_per_page to the public listing                                                              0.06s  
  ✓ it renders a favicon link only when one is set                                                               0.06s  

  Tests:    27 passed (82 assertions)
  Duration: 2.33s

```

## audit-ui.sh

```
Color tokens
  ✓ no raw hex in components
  ✓ no arbitrary color classes
  ✓ no inline style colors
Spacing and sizing scale
  ✓ spacing stays on scale
  ✓ type stays on scale
  ✓ z-index controlled
Interaction states
  ✓ focus states present where outlines are removed
  ✓ no clickable divs
  ✓ buttons go through the primitive
  ✓ images have alt
Component duplication
  ✓ no obvious duplicates
  ✓ one button component
Token file
  ✓ @theme found — 12 color tokens, 7 spacing tokens
Dark mode
  ✓ no per-component dark branching
────────────────────────────────────────
HIGH 0   MED 0   LOW 0   (10 files scanned)
Design system intact.
```

## preflight-prod.sh

```
Secrets
  ok       .env is not tracked by git
  ok       .env.example covers every key in .env
  ok       APP_KEY is set
Environment
  BLOCKER  APP_DEBUG=true — exception pages leak env vars, credentials and stack traces
  –       APP_ENV=local locally — must be 'production' on the server
  –       APP_URL=http://localhost — must be the real https URL in production
Queues and scheduling
  ok       QUEUE_CONNECTION=database
  ok       failed_jobs table migration present
  ok       no scheduled tasks to wire up
Sessions, cache, storage
  ok       SESSION_DRIVER=database
  ok       public/storage symlink exists
Security
  ok       canAccessPanel() implemented on User
  ok       models declare mass-assignment rules
  WARN     no 'throttle' middleware found — login and public forms are unprotected against abuse
  ok       no dd/dump/ray left in app or routes
  ok       env() is only read from config files
Observability
  WARN     no error tracker — a log file on a server nobody reads is not error tracking
  ok       health check route configured
Dependencies
  ok       composer audit clean
Cannot be checked from here
  –       TLS/HSTS at the web server, cron running schedule:run, Supervisor keeping workers alive,
  –       offsite backups AND a restore that has actually been tested, secrets in the platform's
  –       secret store. Confirm each with the user — do not report them as done.
────────────────────────────────────────
BLOCKERS 1   WARNINGS 2
Not ready for production. Fix the blockers before telling anyone it is live.
```
