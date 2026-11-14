# flash-backup-v3 · Personal library

2026-11-14. iOS-first complete snapshot; Apple shared codec reads v1/v2/v3. Other clients must explicitly reject v3 until upgraded. This does not enable LAN.

The root retains v2 `exportedAt`, `appVersion`, `notes`, `schemas`, `data`; changes `version` to `flash-backup-v3` and requires `personalLibrary`. Existing content partitions retain schema 1/2 semantics. See `flash-backup-v3.schema.json` and `fixtures/valid-library-v3.json`.

`personalLibrary` contains `tags`, `links`, `filters`, `reminders`, `showEmotions`, `summaryHour`, `summaryMinute`, `summaryEnabled`, `summaryIntervalDays`, `remindersNeedConfirmation`.

- Tags: UUID `id`, NFC-normalized trimmed `name` (1–80 characters); names unique case-insensitively. At most 1,000 tags.
- Links: dictionary from `log:<UUID>`, `emotion:<UUID>`, `task:<UUID>` to at most 20 unique tag IDs. Ideas use the log key so a category edit preserves tags. Every record and tag reference must resolve.
- Saved filters: at most 100; UUID/name, kinds (`log/idea/emotion/task`), query, tagIDs, matchAll, colors, favoritesOnly, startDay/endDay (empty or yyyy-MM-dd), taskStatus (`all/open/completed`), oldestFirst. Conditions combine with AND. Multi-tag default is OR; task status only applies to tasks. Date bounds are inclusive; tasks use their due date. Results are computed, not stored.
- Reminders: one rule per idea, `id` = idea UUID, `enabled`, `intervalDays` = 1/3/7, hour 9–21, minute 0–59, anchorDay. Every cycle schedules one notification and one follow-up 30 minutes later, excluding quiet hours 22:00–09:00. Import requires explicit activation; runtime completion/snooze and system permissions are not portable.
- All object fields are strict, including nested filters and reminder definitions; unknown fields, invalid references, duplicates and incompatible versions reject the whole import before writing. Maximum plaintext remains 50 MiB.
- Merge unifies tags by normalized name and remaps associations/filter IDs; existing record associations are unioned. Same-ID filters/rules use incoming definitions. Preferences use incoming values. Overwrite replaces all content and metadata atomically. Importing a v1/v2 snapshot by overwrite clears metadata, explicitly stated in the preview; merging it preserves local metadata.
- `flash-backup-enc-v1` cryptography and wire envelope are unchanged. Decrypted bytes may contain a supported v2 or v3 snapshot; an old client rejects an unsupported inner version and must not write data.

SwiftData schema V3 adds one typed, Codable metadata aggregate without changing frozen V1/V2 content entities. All mutations and import/rollback use the same ModelContext transaction as the content. macOS preserves metadata even without iOS feature UI.

Native tests cover V2 store migration, encrypted v3 round-trip, import activation, metadata deletion, filter results, leap/month ends and reminder timing. Actual iPhone notification delivery/30-minute follow-up and accessibility remain separate device acceptance gates.
