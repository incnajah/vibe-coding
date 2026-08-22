# Lessons

## 2026-08-23 — Laravel's stock Feature/ExampleTest has no RefreshDatabase
<!-- applies: laravel/framework:^12 pestphp/pest:^3 -->

**Believed:** `uses(TestCase::class, RefreshDatabase::class)->in('Feature')` in
tests/Pest.php covers every test under tests/Feature.
**Actually:** it only binds Pest test files. The skeleton's `ExampleTest` is a
PHPUnit **class**, so it is untouched and runs against an unmigrated in-memory
database.
**Cost:** 1 verify cycle. The error read `no such table: posts` at ExampleTest
line 17, which points at the homepage rather than at the missing trait.
**Generalises:** yes — hits every project the moment `/` reads the database,
which is nearly all of them.
**Signal:** convert the stock ExampleTest to Pest syntax during bootstrap, or the
first real homepage turns the suite red for a reason unrelated to the code.
