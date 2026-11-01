# Scoped schema2 compatibility / Android Room4→5 plan

Owner approval received2026-10-24. This is the existing `flash-backup-v2` section schema2, already written by Apple; no schema3, envelope rewrite, store relocation, App Group move, secret or keystore change is authorized. Legacy LAN stays disabled independently.

## Data and compatibility boundary

Carry nullable `isFavorite` through logs/emotions/tasks, nullable integer1–5 `intensity` on emotions, and nullable UUID-shaped `sourceLogId` on tasks. `sourceLogId` is a soft reference: preserve dangling IDs without a foreign key or cascade. Missing/null means unspecified; preserve false distinctly from true. No new favorite/intensity/source-link UI is introduced.

Readers continue accepting section1 and2 independently. Section1 must reject presence of schema2 fields, even null; unknown section versions/fields still fail closed in strict and recovery paths. Type/range/UUID/date/byte/count/depth/token checks remain. Recovery may skip invalid records only under the existing explicit recovery policy, never silently discard unknown versions/fields. Writers emit section2 and preserve all supported fields. Old section1-only peers explicitly reject these exports; there is no relabeling or field stripping.

## Android migration

Existing Room database version4→5; five nullable columns, no table replacement or existing-row rewrite:

```sql
ALTER TABLE logs ADD COLUMN isFavorite INTEGER;
ALTER TABLE emotions ADD COLUMN isFavorite INTEGER;
ALTER TABLE emotions ADD COLUMN intensity INTEGER;
ALTER TABLE tasks ADD COLUMN isFavorite INTEGER;
ALTER TABLE tasks ADD COLUMN sourceLogId TEXT;
```

Room maps nullable Boolean to INTEGER; existing rows receive NULL. Keep primary keys, indexes, task columns and `idea_view_state` foreign key/read timestamps unchanged. Register4→5 alongside1→2→3→4 in production and native test builders. Keep exported Room schemas3/4; generate schema5 with the existing compiler. No destructive migration/downgrade fallback. Backup `schemas` and database version are separate namespaces.

The real SQLite/Room gates must cover populated4→5,1/2→5 chains, existing3→4 validation, null defaults, a second open, true/false/intensity/soft-link save→close→reopen→export, merge/overwrite and read-state preservation. Inject an exception after additive DDL inside Room migration and verify the transaction retains version4, original records/read-state and old column layout. This tests failure rollback; it does not prove physical power-loss/storage-controller behavior.

## HarmonyOS persistence

Inspect the existing `id/sort_key/payload` RDB rows before editing. These fields live inside the existing JSON payload; update model validation/normalization/merge/diff/serialization to retain them, and test real source with the existing RDB fakes plus native build. Existing rows lacking fields remain valid. Do not add a database migration unless actual schema changes prove necessary and fall within the owner's approval. Do not touch encrypted-RDB credential handling in this branch.

## Rollback and failure behavior

- Room owns the migration transaction; propagate open/migration errors, retain the original data, and do not delete/recreate the database to recover.
- An old Android v4 binary may not open a v5 database. An old Harmony binary can open its unchanged payload table but discard schema2 fields while loading/editing/exporting. Roll back UI separately while retaining the compatible data/model/serializer layer and LAN disablement, or use a reviewed forward fix. Never use an old reader, introduce destructive downgrade, or restore plaintext LAN as rollback.
- Do not create an automatic plaintext pre-migration snapshot. A user-approved recovery export uses the existing strict backup/private-file paths and a compatible reader; it must preserve schema2 fields.
- No signing/team/deployment/permission/SDK changes. No production store or real user records are migrated by developer probes; all evidence uses disposable stores and fictional data.

## Acceptance evidence

The baseline Apple production exporter generated2,639 bytes, SHA256 `cc9718e96f86ce50df4c028a673cfcd2d37ce385e0235c3e1d1764889f6fffa2`; unchanged Android/Harmony production parsers rejected those exact bytes. After implementation, consume the same artifact through both parsers, commit into isolated stores, close/reopen, export through each production writer, and consume those exact outputs on Apple and the other receiver. Compare all model fields, not only counts. Also run actual installed-app UI export/import where possible and distinguish it from host codecs, emulator/simulator, and real devices.

Until native migration/rollback/reopen and actual-export cross-platform checks pass, this document and an approved migration are not an acceptance verdict.

## Executed implementation checkpoint

Android candidate:91 JVM tests per variant; native12pass/1manual-probe skip; populated migration and injected-DDL rollback passed; explicit separate write/read invocations passed with force-stop between. Actual Apple artifact metadata survives Android native Room and a native re-export. Harmony candidate:278 host/contract tests and unsigned native build pass; existing payload schema unchanged, row reload/ordinary-edit metadata coverage uses explicit RDB fakes. Cross-export codec checks compare every incoming schema2 metadata field. No Harmony device or real-device Android/iOS acceptance is implied. See verification.md and retained raw logs/hashes.
