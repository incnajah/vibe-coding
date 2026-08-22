# Learned

Lessons promoted out of real builds by `scripts/learn.sh`. Each one cost something
to discover — a wrong diagnosis, a fix cycle, or a correction from the user.

Read `self-improvement.md` before adding to this file. Two rules matter most:

- **Cap: 40 entries.** Past that, promoting means retiring, not appending. This file
  competes for context with guidance already known to be good.
- **Retire, do not annotate.** A lesson contradicted by a newer version gets deleted.
  Two entries disagreeing about the same API is worse than neither.

Entry format:

```markdown
## <short title>
<!-- applies: filament/filament:^4 laravel/framework:^13 -->

**Believed:** <the assumption that turned out wrong>
**Actually:** <what is true>
**Signal:** <what to check, and when, so the assumption is never made again>
```

The `applies:` comment is optional and lists composer packages the lesson depends on.
`learn.sh` flags entries whose packages are missing from the current project, which
is usually the sign that an entry has expired.

<!-- entries-below -->

<!-- No lessons promoted yet. This file fills up as builds hit real failures. -->
