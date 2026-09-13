# Flash backup v2

> First machine-readable contract draft (2026-09-05):
> [Schema](contracts/flash-backup-v2.schema.json),
> [normative draft and implementation gaps](contracts/README.md), and
> [plain-language manager guide](flash-backup-protocol-for-managers.md).
> The strict standard and separate recovery entry are now wired into all three
> clients; real-device transfer and end-to-end recovery acceptance remain open.
> Existing compatibility behavior and known cross-platform differences are
> documented separately.

`flash-backup-v2` is the portable, full-snapshot format shared by Android,
macOS, and HarmonyOS. It keeps each content section independently versioned
so record codecs can also be reused by a future synchronization protocol.

## Envelope

```json
{
  "version": "flash-backup-v2",
  "exportedAt": "2026-08-31T12:00:00.000Z",
  "appVersion": "0.1.0",
  "notes": "",
  "schemas": { "logs": 1, "emotions": 1, "tasks": 1 },
  "data": { "logs": [], "emotions": [], "tasks": [] }
}
```

- Dates and instants are strict ISO-8601 strings. Instants are normalized to
  UTC with millisecond precision; calendar days use `yyyy-MM-dd`.
- IDs are UUID strings. Text and collection limits have shared nominal values,
  but counting and rejection behavior still differ; see the contract gap table.
- A reader rejects a known section whose schema version it cannot understand.
  Unknown future sections require a new envelope version so an old client
  cannot silently discard user data during a round trip.
- v2 clients import `flash-backup-v1` as schemas `logs:1`, `emotions:1`, and an
  empty task section. v1 clients safely reject v2.

## Task schema 1

```json
{
  "id": "a3ec0f9e-f4dc-4d4d-9cd0-ef97ba17c486",
  "title": "提交设计作业",
  "notes": "附上最终原型",
  "colorTag": "urgent",
  "importance": 3,
  "due": {
    "kind": "dateTime",
    "at": "2026-09-05T01:00:00.000Z",
    "timeZone": "Asia/Shanghai"
  },
  "reminderAt": "2026-09-05T00:30:00.000Z",
  "completedAt": null,
  "createdAt": "2026-08-31T12:00:00.000Z",
  "updatedAt": "2026-08-31T12:00:00.000Z"
}
```

An all-day due value is encoded as:

```json
{ "kind": "allDay", "date": "2026-09-05" }
```

Rules:

- `title`: non-blank, at most 200 characters.
- `notes`: nullable, at most 100,000 characters.
- `colorTag`: one of the existing six Flash color tags.
- `importance`: integer from 0 through 4.
- `due.kind`: `allDay` or `dateTime`. An all-day due value requires a real
  calendar date. A timed due value requires a valid instant and IANA time-zone
  identifier.
- `reminderAt`, `completedAt`: nullable normalized instants.
- `createdAt`, `updatedAt`: required normalized instants; `updatedAt` cannot be
  earlier than `createdAt`.
- OS notification IDs and permission state are local implementation details
  and are never exported.

## Import and merge

- Overwrite replaces all logs, emotions, and tasks in one logical operation.
- Merge matches records by ID. Existing log/emotion behavior remains incoming
  snapshot wins. Tasks compare `updatedAt`; the newer value wins. If timestamps
  tie but content differs, the explicitly imported value wins and is reported
  as changed.
- Local-only records remain during merge.
- After a successful import, platforms that implement local notifications
  rebuild future, incomplete reminders from `reminderAt`. Completed or overdue
  reminders are cancelled. Other clients preserve the field unchanged.

## Future automatic synchronization

Backup v2 remains a snapshot format. Automatic synchronization will use a
separate `flash-sync-v1` transport envelope with account-independent cursors,
operations, tombstones, and conflict metadata. Sync operations will carry the
same section names, schema numbers, and record objects defined here. Keeping
snapshot and synchronization envelopes separate prevents backup files from
acquiring server state, device identifiers, or partial-history semantics.

A proposed batch has this shape (reserved design, not accepted by current
backup importers):

```json
{
  "protocol": "flash-sync-v1",
  "batchId": "785f88b1-f1b0-47df-a1b8-b4aa80369129",
  "deviceId": "locally-generated-installation-id",
  "afterCursor": "opaque-server-cursor-or-null",
  "schemas": { "logs": 1, "emotions": 1, "tasks": 1 },
  "operations": [
    {
      "operationId": "1d7ad5b9-f9a2-49c1-99e8-c615c86b939c",
      "section": "tasks",
      "recordId": "a3ec0f9e-f4dc-4d4d-9cd0-ef97ba17c486",
      "kind": "upsert",
      "changedAt": "2026-08-31T12:00:00.000Z",
      "record": { "id": "...", "title": "...", "due": { "kind": "allDay", "date": "2026-09-05" } }
    }
  ]
}
```

Reserved synchronization rules:

- `batchId` and `operationId` make retries idempotent. The returned cursor is
  opaque and monotonically advances per sync collection; clients never derive
  or compare cursor contents.
- An operation is either `upsert` with a section-schema record, or `delete`
  with a record ID and tombstone timestamp. Tombstones are retained long enough
  for offline devices and are compacted only after an explicit retention rule.
- Each installation keeps sync metadata (`revision`, content hash,
  `changedAt`, deletion state) in a local side table. This metadata is not part
  of portable backups. It also supplies mutation time for current log/emotion
  records, which intentionally do not expose `updatedAt` in schema 1.
- Task conflicts first compare `updatedAt`; equal-time divergent content is
  preserved as a conflict instead of being silently discarded. Other sections
  use server revision plus the local mutation metadata. A future UI can offer
  “keep mine”, “keep theirs”, or duplicate-as-copy resolution.
- Device identity, authentication, endpoint discovery, encryption, retry/backoff,
  network constraints, and tombstone retention belong to the transport and
  account layer. None are written into `flash-backup-v2` files.
- Pull changes before pushing local operations, apply a batch transactionally,
  rebuild local reminder jobs, then persist the new cursor. A failed batch does
  not advance the cursor.
