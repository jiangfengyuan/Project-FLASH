# 01 — Codebase baseline review (read-only)

Reviewer: Claude (independent, read-only). Companion to `00-baseline.md` (finding B-1, offline PIN recovery). Nothing in this report is a verdict on any hardening branch.

**Revision 2 (2026-10-24, second pass).** A second, independent read-only pass re-checked every finding of revision 1 against the `e9a0aa6` source and extended the report. Changes: F-02's example zone corrected (Apple reports `Asia/Calcutta`, so India is not the Apple example; Vietnam/Nepal/Myanmar/Ukraine are) and backed with a full diff against Apple's own zone list; F-04 downgraded High → Medium, because the only distributed APK is signed with a local *debug* certificate rather than the committed key; F-07, F-08 and F-19 gained evidence; five new findings F-23 … F-27 were added (F-23 is High and was reproduced on the host). Revision 1 is preserved in the reviewer's scratchpad, not in the repo.

---

## 1. Scope, commit, environment, limitations

### 1.1 What was reviewed

| Item | Value |
| --- | --- |
| Repository | `app/` (remote `git@github.com:jiangfengyuan/Project-FLASH.git`) |
| Reviewed commit | `e9a0aa6a2a147b8ebd9be81d1c298c5b4a2eab25` (`docs(ios): record the manual verification pass`, 2026-10-24 15:00 +0800), branch `feat/ios-native` |
| Product worktree state | Clean for tracked files. Untracked, **reviewer-only, not product code**: `docs/review/00-baseline.md`, `scripts/review/offline_pin_crack.py`, and this file. |
| Other worktrees | Revision 1 saw a Codex worktree on `codex/security-performance-hardening` (`70bc41c`). At revision 2 `git worktree list` shows `codex/security-performance-hardening` at `4d28844` (`/Users/haydenjiang/Documents/Codex/2026-10-24/.../flash-hardening`) and `codex/hardening-continuation` at `39d8fe0` (`.worktrees/codex-hardening`). **Neither was opened, read, or touched.** Everything here is about `e9a0aa6`. |
| Worktree state at revision 2 | `git status --short` in `app/`: only `?? docs/review/` and `?? scripts/review/` (reviewer files). Tracked files are identical to `e9a0aa6`, so reading the working tree is reading the commit. |
| Source read | FlashKit (`shared/FlashKit`, all of `FlashCore/Data`, `Presentation`, selected `Domain`/`FlashDesign`), iOS (`ios/`), macOS (`macos/`), Android (`android/app/src/main`, tests, Gradle, manifest, backup rules), HarmonyOS (`harmonyos/entry/src/main/ets/data`, `state` call sites, config, tests), contracts (`docs/contracts`, `scripts/backup-contract`), CI (`.github/workflows`), docs (README, ROADMAP, `docs/*`, `AGENTS.md`). About 51k tracked lines exist; UI view files were sampled by grep and targeted reads, not read line by line. |
| Product repo changes made | None in either revision. No production code, tests, contracts, CI, signing, or manifests were modified. |
| Rev. 2 re-read in full | `LocalBackupTransfer.{swift,kt,ets}`, `BackupService.swift`, `FlashRepository.swift`, `FlashDatabase.swift`, `TaskReminderScheduler.{swift,kt,ets}`, `IdeaViewStateStore.swift`, `BackupImportCoordinator.swift`, `BackupTransfer.swift`, iOS `FlashApp`/`RootView`/`IdeaReminderCenter`/`SettingsScreen`, Android `SettingsViewModel`/`FlashRepository`/`Backup.kt` export path/manifest/`build.gradle.kts`, HarmonyOS `FlashStore.ets` (load, quarantine, write paths), `BackupFiles.ets`, build/obfuscation/module config, CI workflow and Xcode schemes; other cited lines were spot-checked. |

### 1.2 Environment

macOS (Darwin 27.2), Xcode-beta present, Node v26.2.0, Python 3.13.7. No Android device/emulator, no HarmonyOS device, no iOS simulator session, no network checks (GitHub Actions status and repo visibility were **not** queried).

### 1.3 What was executed (everything else is static reading)

No builds, no test suites, no benchmarks were run (as instructed, to stay out of Codex's way). Two cheap read-only reproductions were run, using throwaway files **outside the repo** in the session scratchpad. They are the only "additional tooling" and exist because the claims they support (F-02, F-09) are otherwise easy to dispute from source alone:

1. F-02: Python rewrote a copy of `docs/contracts/fixtures/valid-full.json` with `timeZone: "Asia/Kolkata"` (and a second copy with `"UTC"`) into `/private/tmp/claude-501/-Users-haydenjiang-Documents-DEV-flash-Alpha/b80d1478-dd84-4938-9c98-65557c832e31/scratchpad/`; the repo's own `node scripts/backup-contract/validate.cjs <file>` was run on them. Result: Kolkata copy exit 1 (`TIME_ZONE`), UTC copy exit 0.
2. F-09: a 12-line Swift program (`.../scratchpad/swiftprobe/probe.swift`, compiled with Xcode-beta `swiftc` and a scratchpad module cache) that copies the exact `uuidRegex` pattern and `isUUID` body from `BackupService.swift:214-215,660-662` and probes trailing line terminators.

Revision 2 added four more throwaway probes, all in the revision-2 scratchpad (`/private/tmp/claude-501/-Users-haydenjiang-Documents-DEV-flash-Alpha/faf813c4-13e2-40d9-8901-b301a261e395/scratchpad/`), none in the repo:

3. F-23: `harmonyprobe/split-delivery.cjs` loads the real `LocalBackupTransfer.ets` through the repo's own `harmonyos/tests/ets-loader.cjs` with the same Node-crypto fakes the repo tests use, and delivers the proof line and the `OK` line as two `message` events. Result: `RESULT failed: 发送方响应头过长`. Control `harmonyprobe/control-delayed.cjs` (same, with 20 ms between the two events): `RESULT ok: {}`.
4. F-02: `tzprobe/all.swift` prints `TimeZone.knownTimeZoneIdentifiers` on this Mac (443 ids) and a Python diff against `canonical-timezones.json`.
5. F-04: `apksigner verify --print-certs` and `aapt2 dump` (Android SDK build-tools 37.0.0, Android Studio JBR) on `../releases/Flash-Alpha010.apk`. The historical keystore blob was extracted from git into the scratchpad only to confirm it is a PKCS#12 blob; **it was not opened with the leaked password.**
6. No builds, test suites or benchmarks were run in either revision.

### 1.4 Status vocabulary

- **CONFIRMED DEFECT**: the behaviour follows from the code as written (cited lines), and/or was reproduced as described. "Static" means confirmed by reading, not by running the app.
- **RISK**: a real weakness or design hazard; the failure needs a particular condition.
- **HYPOTHESIS**: plausible from code, depends on platform/runtime behaviour or on measurements that were not taken. A measurement/test plan is given.
- **NOT VERIFIED**: could not be checked here.

No numeric performance claim is made anywhere. Performance items are hypotheses with a measurement plan.

### 1.5 Limitations that affect confidence

- No device evidence of any kind. Notification behaviour, Bonjour/NSD behaviour, HarmonyOS runtime semantics, VoiceOver/TalkBack, and low-storage behaviour were not observed.
- UI view files were not audited line by line; accessibility and design-token observations in §3.1 are grep-level.
- I could not see whether Codex has already changed any of these areas. If a finding is fixed on that branch, this report is simply a snapshot of `e9a0aa6`.

---

## 2. Executive summary

27 findings. **0 Critical, 5 High, 13 Medium, 9 Low.** Status mix: 15 CONFIRMED DEFECT (static reading or reproduction), 5 RISK, 7 HYPOTHESIS.

| Severity | Count | IDs |
| --- | --- | --- |
| Critical | 0 | — |
| High | 5 | F-01, F-02, F-03, F-23, F-05 (F-05 is a HYPOTHESIS) |
| Medium | 13 | F-04 (downgraded in rev. 2), F-06 … F-15, F-24, F-25 |
| Low | 9 | F-16 … F-22, F-26, F-27 |

IDs are stable across revisions so other agents can keep referring to them; §3 is ordered by severity, not by ID.

The points that matter most:

1. **F-01 — the LAN sender hands the entire backup to any peer that sends a `CHALLENGE`.** The PIN proves the *sender* to the receiver; nothing proves the *receiver* to the sender. An attacker on the same network can pull the plaintext backup without the PIN, without sniffing, and the sender then reports "sent successfully" (all three platforms). This is different from B-1 (passive capture + offline PIN search) and is not fixed by replacing the HMAC proof alone.
2. **F-02 — the time-zone whitelist is a V8/ICU *legacy-name* list.** It contains `Asia/Calcutta`, `Europe/Kiev`, `Asia/Saigon`, … and omits `Asia/Kolkata`, `Europe/Kyiv`, `Asia/Ho_Chi_Minh`, … 36 of the 443 identifiers in Apple's own `TimeZone.knownTimeZoneIdentifiers` are rejected, including `Asia/Ho_Chi_Minh`, `Asia/Kathmandu`, `Asia/Yangon`, `Europe/Kyiv` and `GMT`. One timed task created in such a zone makes **every strict export, share and LAN send fail** (the whole backup, not just that task). Reproduced against the repo's own validator. The test fixtures all use Shanghai/New York/Berlin/Tokyo/Sydney/UTC, so CI cannot see it.
3. **F-03 — Apple platforms always export section schema 2; Android and HarmonyOS only read schema 1.** Mac/iPhone → Android/HarmonyOS file import and LAN receive cannot work, while the README still says the formats are "可互读".
4. **F-23 (new) — the HarmonyOS LAN receiver fails a genuine transfer whenever the `OK` header arrives in a later socket event than the proof line.** The proof check is async and the parser keeps reading the next line as a proof meanwhile. Reproduced with the repo's own loader (`发送方响应头过长`). The HarmonyOS sender always sends the proof, the header and the payload as three separate writes, and every repo test delivers them in one event, so the tests cannot see it.
5. **F-05 — HarmonyOS release builds enable property obfuscation with almost no keep rules, while storage and export are `JSON.stringify` of ArkTS objects** (hypothesis; one release build would settle it).
6. **F-04 (downgraded to Medium)** — the committed release keystore and literal passwords are still in history on every branch, but the only distributed APK (`releases/Flash-Alpha010.apk`) is signed with a local `CN=Android Debug` certificate, not that key. Separately, that APK is `debuggable=true` and `allowBackup=true`.
7. **CI (F-13):** no iOS job exists; the 194 FlashKit tests (backup contract, repository, migration, LAN) are run neither by CI nor by either Xcode scheme; Android release/R8 and HarmonyOS hvigor builds never run.
8. **Further HarmonyOS reliability gaps (new):** the task-reminder rebuild publishes every replacement before cancelling the old set, which likely exceeds HarmonyOS's per-app reminder quota at about 16 pending reminders (F-24, RISK). The RDB "transaction" around overwrite/merge mixes a synchronous `beginTransaction()` with awaited async writes (F-25, HYPOTHESIS). Together with F-08, these make the HarmonyOS data path the least verified of the four platforms.

---

## 3. Findings (by severity)

Conventions: line numbers are for `e9a0aa6`. "Codex" fields only describe overlap with the *announced* hardening scope (LAN auth, resource limits, performance); they are not an assessment of that branch.

### F-01 — LAN sender releases the full plaintext backup to any peer; attacker pull is reported as success

- **Severity:** High
- **Status:** CONFIRMED DEFECT (static, three implementations; not executed on devices)
- **Platforms:** iOS, macOS, Android, HarmonyOS (sender role)
- **Evidence:**
  - Swift: `shared/FlashKit/Sources/FlashCore/Data/LocalBackupTransfer.swift:352-389` (`handleClientLine` → `answer`) writes `FLASH-AERO/1 <proof>`, `OK <size> <mac>` and the payload in response to any well-formed `CHALLENGE <32 hex>`; no receiver credential is checked. `:337-345` maps "peer sent FIN after an answer" to `.confirmed`.
  - Kotlin: `android/.../data/LocalBackupTransfer.kt:176-230` (`handleSenderConnection`); `:207` `writeAnswer(...)` after only a regex match (`:197-205`); `:213` `answered && !rejected -> ConnectionOutcome.PAIRED`; `:143-165` `serveSession` returns `true`; `SettingsViewModel.kt` shows "局域网备份已发送".
  - ArkTS: `harmonyos/.../data/LocalBackupTransfer.ets:151-157` (`answer`), `:242` call, `:203-211` close ⇒ `stop(!rejected)` ⇒ success, `:195` idle timer ⇒ `finish(true)` even without a close.
  - Spec: `docs/contracts/lan-handshake-v1.1.md` — the PIN is used only to build `proof`/`mac`; "本规格不解决端到端加密".
- **Scenario:** Alice taps "局域网发送" on a café/hotel/dorm Wi-Fi. A second host runs `dns-sd -B _flashbackup._tcp`, connects to the advertised port, sends `CHALLENGE 00112233445566778899aabbccddeeff\n`, reads the proof line, the `OK <n> <mac>` line and `n` bytes of JSON, then closes. It never needs the PIN. Alice's device (a) has lost its single-use session (the listener is cancelled on `.confirmed`/`PAIRED`), (b) tells Alice the backup was sent, and (c) Bob's real receiver, if any, cannot connect any more.
- **Reproduction (not executed here):** two devices on one LAN; the second uses a raw TCP client as above; observe the full JSON and the sender-side success toast. Test idea for each platform's loopback suite: connect with a raw socket, send a syntactically valid `CHALLENGE`, assert that **no payload bytes** are returned and that the session is not marked successful.
- **Impact:** confidentiality of the entire journal (logs, ideas, emotions with notes, tasks) to any LAN peer for the 60 s session window; integrity of the user's mental model (false "sent" result); denial of the intended transfer. Affects every sender platform; every receiver is unaffected by this particular flaw.
- **Relation to documented findings:** B-1 covers passive capture and offline PIN search, and the "plaintext on the wire" note. This is an *active, PIN-less pull*. Not covered by "LAN is trusted" language in the UI either, because the PIN is presented as the pairing control.
- **Smallest corrective direction:** do not release payload bytes until the receiver has proven knowledge of the session secret (mutual authentication; a PAKE with key confirmation, then AEAD keyed from the session key). Decide "success" from an authenticated receiver acknowledgement, not from a TCP FIN. A stronger proof alone (HMAC replaced by something else) does **not** close this.
- **Codex relation:** *related and likely overlapping* with LAN-auth work; the acceptance bar in `00-baseline.md` ("transcript must not allow offline PIN verification") should be extended with "an unauthenticated peer receives no payload bytes" and "an unauthenticated close never produces a success result".

### F-02 — Time-zone whitelist is ICU/V8 legacy names; real device zones make strict export fail for the whole backup

- **Severity:** High
- **Status:** CONFIRMED DEFECT (whitelist content and failure path reproduced/static; Apple's known-identifier list diffed on this Mac; the identifier a particular device reports for `TimeZone.current`/`ZoneId.systemDefault()` was not observed, see "Not verified")
- **Platforms:** iOS, macOS, Android (export/share/LAN-send blocked); HarmonyOS (see below); contract tooling
- **Evidence:**
  - `scripts/backup-contract/canonical-timezones.json` (420 entries) contains `Asia/Calcutta`, `Asia/Saigon`, `Asia/Katmandu`, `Asia/Rangoon`, `Europe/Kiev`, `America/Buenos_Aires`, `America/Godthab`, `Pacific/Truk`, `Africa/Asmera`; it does **not** contain `Asia/Kolkata`, `Asia/Ho_Chi_Minh`, `Asia/Kathmandu`, `Asia/Yangon`, `Europe/Kyiv`, `America/Argentina/Buenos_Aires`, `America/Nuuk`, `Pacific/Chuuk`, `Africa/Asmara`. (Node 26's `Intl.supportedValuesOf('timeZone')` also returns `Asia/Calcutta`, not `Asia/Kolkata`.)
  - Task zones are taken straight from the device: Swift `shared/FlashKit/Sources/FlashDesign/Features/Calendar/TaskEditorView.swift:19-20,129` (`TimeZone.current.identifier`); Android `.../ui/calendar/TaskEditorDialog.kt:64-65` (`ZoneId.systemDefault()`); ArkTS `.../state/CalendarController.ets:107,183,196` (`i18n.getTimeZone().getID()`).
  - Strict export re-validates everything: Swift `BackupService.swift:299-304` (`exportStrictJSON` → `parseStrict`), `:655-658` (`canonicalTimeZone`), `:468` (`skipped > 0` ⇒ throw); Kotlin `Backup.kt:126` (`.also { parseStrict(it) }`), `:190-198`; ArkTS `BackupService.ets:255-264` (`exportTasks` throws on an invalid record), `:549-562`.
  - UI surfaces only a generic failure (e.g. `ios/Flash/UI/Settings/SettingsScreen.swift:171-174` "生成备份失败，请重试"); the detailed error goes to `print`.
  - Tracked note `.superpowers/audit-2026-09-19/timezone-alignment-report.md` asserts the 420 entries are "标准 IANA 时区 ID", and `docs/contracts/README.md` §3 says `UTC` and `Etc/*` are **not** valid, while `validate.cjs:79-84` and the JSON explicitly include `UTC`/`Etc/UTC` (doc/implementation contradiction).
  - Fixtures only use `Asia/Shanghai`, `America/New_York`, `Europe/Berlin`, `Asia/Tokyo`, `Australia/Sydney`, `UTC` (`valid-time-zones.json`).
  - **Rev. 2 diff against Apple's own list (executed, §1.3(4)):** of the 443 entries in `TimeZone.knownTimeZoneIdentifiers` on this Mac, 36 are not in the whitelist: `Africa/Asmara`, `America/Argentina/{Buenos_Aires,Catamarca,Cordoba,Jujuy,Mendoza}`, `America/Atikokan`, `America/Indiana/Indianapolis`, `America/Kentucky/Louisville`, `America/Montreal`, `America/Nipigon`, `America/Nuuk`, `America/Pangnirtung`, `America/Rainy_River`, `America/Santa_Isabel`, `America/Shiprock`, `America/Thunder_Bay`, `America/Yellowknife`, `Antarctica/South_Pole`, `Asia/Choibalsan`, `Asia/Chongqing`, `Asia/Harbin`, `Asia/Ho_Chi_Minh`, `Asia/Kashgar`, `Asia/Kathmandu`, `Asia/Yangon`, `Atlantic/Faroe`, `Australia/Currie`, `Europe/Kyiv`, `Europe/Uzhgorod`, `Europe/Zaporozhye`, `GMT`, `Pacific/Chuuk`, `Pacific/Johnston`, `Pacific/Kanton`, `Pacific/Pohnpei`. Apple's list contains `Asia/Calcutta` and not `Asia/Kolkata`, so **revision 1's India example does not hold for Apple devices** (Android not verified).
- **Scenario:** a user in Vietnam (`Asia/Ho_Chi_Minh`, which Apple lists and the whitelist lacks), Nepal, Myanmar or Ukraine creates one timed task with a reminder, then taps Export, Share, or LAN-send. The exporter produces JSON, `parseStrict` rejects that task (`canonicalTimeZone` false) and aborts. No backup can be produced until the task is deleted or edited to an all-day task. The same applies to every zone in the list above, and to Android devices if they report the modern spellings (not verified). On the recovery import path the same tasks from an existing backup are *skipped* (counted in "跳过异常数据") — silent data loss on restore.
- **Reproduction (executed):** see §1.3(1): `node scripts/backup-contract/validate.cjs .../kolkata.json` → `{"valid":false,"errors":[{"path":"/data/tasks/0/due/timeZone","code":"TIME_ZONE",…}]}`, exit 1; `…/utc.json` → valid. The validator, Swift, Kotlin and ArkTS share one list (`grep` confirms `Asia/Ho_Chi_Minh`/`Europe/Kyiv` absent and `Asia/Saigon`/`Europe/Kiev` present in all four). Native test idea: build a `TaskItem` with `timeZone = "Asia/Ho_Chi_Minh"` and call `BackupService.exportStrictJSON` / `Backup.exportJson` / `BackupService.exportJSON`; expect success once fixed.
- **HarmonyOS note:** `FlashStore.loadBusinessData` validates *stored* rows with the exchange validator (`FlashStore.ets:274-278` → `validatedTask` → `validTimeZone`). Any stored task whose zone is outside the list is hidden at next launch and quarantined (see F-08). Whether `i18n.getTimeZone().getID()` yields legacy ICU names (which would match) was not verified.
- **Impact:** the headline feature (backup/transfer) fails entirely for a large user population on Apple/Android; restore silently drops tasks; the CI fixtures cannot see it.
- **Smallest corrective direction:** (a) normalise the device identifier to the contract identifier at task creation (alias map), (b) widen the import whitelist to a superset that includes both IANA canonical and ICU legacy spellings, normalising to one on read, (c) make export failures actionable (identify the offending record), (d) add non-Shanghai fixtures (Kolkata, Kyiv, Ho_Chi_Minh, `UTC`, `Etc/UTC`) and reconcile `README.md` §3 with the list.
- **Codex relation:** *independent of LAN/performance work but likely to conflict textually* with any change to `BackupService`, `CanonicalTimeZones.*`, or `scripts/backup-contract` (shared contract files).

### F-03 — Apple platforms export section schema 2; Android and HarmonyOS accept only schema 1

- **Severity:** High
- **Status:** CONFIRMED DEFECT against README claim (behaviour is *documented* in the contract as "待跟进", so not a surprise bug; the headline claim is what is wrong)
- **Platforms:** iOS, macOS ↔ Android, HarmonyOS
- **Evidence:** Swift exports `"schemas": 2/2/2` always (`BackupService.swift:204,289-291`); Kotlin accepts only `1` (`Backup.kt:40,219`) and exports `1` (`:112-114`); ArkTS accepts only `1` (`BackupService.ets:292`) and exports `1` (`:219`). Android/ArkTS models have no `isFavorite`, `intensity`, `sourceLogId`. `README.md` says the two formats are "两端格式一致、可互读"; `docs/contracts/*` never mention iOS (grep: no match for "iOS" in `docs/contracts`, `docs/flash-backup-*.md`). `valid-schema2.json` is consumed only by Node and Swift tests (`BackupContractTests.swift:17`), not by Android or ArkTS.
- **Scenario:** a Mac/iPhone user sends a backup to an Android phone by file, share sheet, or LAN. The receiver downloads the full payload (LAN) and then fails at parse with "不支持的 logs 分区版本" / "备份数据结构不完整或分区版本不兼容". The recovery path rejects it as well.
- **Impact:** Apple → Android/HarmonyOS migration impossible in every mode; Android/HarmonyOS → Apple works. No silent data loss (explicit rejection), but a core promise is unmet. Favorites, intensity and idea→task links cannot round-trip through Android/HarmonyOS even after follow-up work unless those fields are added there.
- **Smallest corrective direction:** emit a partition as schema 1 whenever none of its records uses a schema-2-only field (valid under the contract, which defines the version as the declared record shape) — this alone restores Apple → Android for most users — and schedule real schema-2 support on Android/ArkTS; fix README wording; add `valid-schema2` to Android/ArkTS tests as *expected-rejected* until then.
- **Codex relation:** *independent* of the announced scope; *likely to conflict* with any edit to `BackupService.exportJSON` / `parseStrict`.

### F-23 — HarmonyOS LAN receiver misparses the pipelined answer while the async proof check is pending (new in rev. 2)

- **Severity:** High
- **Status:** CONFIRMED DEFECT (reproduced on the host with the repo's own loader and fakes; how often real HarmonyOS socket events interleave with the crypto callback was NOT VERIFIED on a device)
- **Platforms:** HarmonyOS (receiver role; any sender platform)
- **Evidence:**
  - `harmonyos/entry/src/main/ets/data/LocalBackupTransfer.ets:445-460`: in the `proof` phase the parser consumes the proof line, starts `handshakeProof(...)` (async `cryptoFramework` HMAC) and `return`s. `phase` stays `'proof'` until the promise settles (`:451-454`); no "verification pending" flag exists.
  - `:537-541`: every `message` event calls `absorb` → `process()` unconditionally. If the next TCP segment arrives before the HMAC promise settles, `process()` resumes in the `proof` phase, reads the `OK <size> <mac>` line (≥ 71 bytes) against the 64-byte proof limit (`:428-431`) and fails with `发送方响应头过长`. A payload chunk in that position fails the same way, or as `无效响应`.
  - The HarmonyOS sender issues the proof line, the `OK` line and the payload as three separate `connection.send` calls (`:154-156`); Swift and Kotlin senders pipeline too. A 50 MiB payload necessarily arrives as many events.
  - Every receiver test delivers proof + OK (+ payload) in **one** `client.emit(...)` (`tests/security-audit.test.cjs:140,150,162,172,194`, `tests/review-fixes.test.cjs:430,450,455,467`); the one split-delivery test sleeps 70 ms between events (`review-fixes.test.cjs:466-471`), long enough for the fake HMAC to resolve.
- **Reproduction (executed, §1.3(3)):** proof line in event 1, `OK 2 <mac>\n{}` in event 2, synchronously → `RESULT failed: 发送方响应头过长`; with 20 ms between events → `RESULT ok: {}`.
- **Scenario:** a user receives a backup on a HarmonyOS phone from any sender. Whether it succeeds depends on whether the crypto callback runs before the next socket event. For realistic payload sizes the receiver can fail with a misleading "response header too long" error, restart discovery, and fail again. The sender's 60 s session and the user's patience run out.
- **Impact:** the HarmonyOS LAN-receive feature is unreliable in a way host tests cannot see. No data corruption: the transfer fails closed.
- **Smallest corrective direction:** while a proof (or MAC) verification is pending, buffer incoming bytes without parsing (a `verifying` flag checked at the top of `process()`), and resume parsing from the settle callback. Add a host test that emits the proof line and the `OK` line in two synchronous events, and one that streams the payload in many small events.
- **Codex relation:** *related* to LAN hardening (same file); any protocol rewrite should carry the split-delivery test.

### F-05 — HarmonyOS release build enables property obfuscation while data is `JSON.stringify` of ArkTS objects

- **Severity:** High (potential impact), **Status:** HYPOTHESIS
- **Platforms:** HarmonyOS release HAP
- **Evidence:** `harmonyos/entry/obfuscation-rules.txt:1-6` enables property, top-level, file-name and export obfuscation and keeps only `FlashStore` and `BackupService` global names. `entry/build-profile.json5:11-17` applies it to the `release` option set. Persisted rows and exported documents are produced with `JSON.stringify(item)` (`FlashStore.ets:555,824`; `BackupService.ets:226`) from object/interface fields (`id`, `content`, `colorTag`, `createdAt`, `due.timeZone`, …) and read back with `JSON.parse` + property access (`BackupService.ets:272`). Host tests run un-obfuscated sources; the CI never builds a HAP; no HarmonyOS device evidence exists (`acceptance.md`).
- **Failure scenario (if the premise holds):** the obfuscator renames statically declared property names; a release HAP then writes rows/exports with renamed keys, which a debug build, another platform, or the strict validator reads as unknown fields; on upgrade between builds, stored rows fail validation and are quarantined (F-08).
- **Test plan:** build one release HAP and inspect the obfuscation name cache for `colorTag`/`createdAt`/`timeZone`; on a device (or the Previewer), export a backup from the release build and check the JSON keys against `flash-backup-v2.schema.json`. If keys are renamed, add the model field names as keep rules (or use dynamic accessors).
- **Codex relation:** *independent*; not a host-test-visible issue.

### F-04 — Release keystore and scripts with literal passwords remain in git history

- **Severity:** Medium (rev. 1: High; downgraded because the distributed APK was shown not to use this key)
- **Status:** CONFIRMED (presence in history; distributed APK signer checked); exposure of the repo NOT VERIFIED
- **Platforms:** Android (distribution signing); repository hygiene
- **Evidence:** `git log --all -- android/app/flash-release.keystore`: added in `4c78c55` (2026-07-14, "add generated dev keystore"), removed in `1ae0f0f` (2026-08-14). `git branch -a --contains 4c78c55` lists every branch including `origin/main`, `origin/feat/ios-native`, `origin/phase3-mobile-release` and both Codex branches. At `4c78c55`, `scripts/generate-android-keystore.sh` and `android/release-signing.env.example` contain literal store/key password assignments (values deliberately not reproduced here). `.gitignore:` "Android 签名密钥（严禁入库；曾发生泄露，密钥需轮换）". Current `scripts/generate-android-keystore.sh` and `android/app/build.gradle.kts:20-37` are env-driven and refuse default passwords (good).
- **Rev. 2 evidence (executed, §1.3(5)):** `apksigner verify --print-certs releases/Flash-Alpha010.apk` → `certificate DN: C=US, O=Android, CN=Android Debug`, SHA-256 `4cd87433…3e707c88`; i.e. a local debug certificate, consistent with `releases/README.md` ("历史 Debug … 停止分发"). The same APK's manifest has `android:debuggable=true` and `android:allowBackup=true` (`aapt2 dump xmltree`), package `com.flash.app.native`. The committed keystore is a password-protected PKCS#12 blob and was not opened, so its own certificate fingerprint was not read.
- **Scenario:** anyone with read access to history recovers the keystore and passwords. Today no distributed build trusts that key, so the practical risk is that someone **reuses** it for a future release (it is still on every branch, including the Codex branches). Separately, a user who still has Alpha010 installed exposes their journal to anyone with USB access via `adb backup`/`run-as`, because the APK is debuggable.
- **Impact:** release-signing trust if the key is ever reused; journal confidentiality for remaining Alpha010 installs (outside the repo; already marked "停止分发").
- **Smallest corrective direction:** treat the committed key as burned: never use it for any release and record that in `android/README.md`/ROADMAP. History rewriting is a separate decision for the owner. Tell any remaining Alpha010 users to migrate (the release README already describes the path).
- **Codex relation:** *independent*.

### F-06 — LAN availability: one unauthenticated message ends a pairing session; the single connection slot is easy to hold; Android has no total deadline while waiting for the challenge

- **Severity:** Medium
- **Status:** CONFIRMED DEFECT (static)
- **Platforms:** all senders (a, b); Android (c)
- **Evidence:**
  - (a) `ERR PIN` kills the session with no prior challenge or authentication: Swift `LocalBackupTransfer.swift:353-357` (`finish(.failed)`), Kotlin `LocalBackupTransfer.kt:197,213-214` (`rejected` ⇒ `SESSION_FAILED`), ArkTS `LocalBackupTransfer.ets:251-255,210`.
  - (b) one connection at a time: Swift `:301`, ArkTS `:163`, Kotlin serial `accept` loop (`:152-159`). Holders are released by idle timers (15 s Swift/Kotlin, 10 s ArkTS) but each new byte resets them.
  - (c) Kotlin: `readLine(input, LINE_LIMIT)` (`:192`) runs under `soTimeout = 15 s` per `read()`; the 60 s session deadline is only evaluated between connections (`:149-152`); `transferDeadline` (`:183`) is only checked in `writeAnswer` (`:244`). A peer sending one byte every ~14 s can hold the handler for ≈ 63 bytes × 14 s ≈ 15 min, and `Sender.stop()` closes only the server socket (`:113-118`), not the active client socket. Swift and ArkTS cancel the active connection when the session ends.
  - (d) amplification: each connection may receive up to five full pipelined answers (`maxAttempts`), each up to 50 MiB, with no authentication (see F-01).
- **Scenario:** any host on the LAN sends `ERR PIN\n` (7 bytes) to a sender port; the sender's session ends with "配对已结束，请重新发起". Repeatable per session.
- **Impact:** trivial denial of service of the LAN transfer feature; (c) can keep an Android handler thread busy long after the UI says the session ended.
- **Smallest corrective direction:** accept `ERR PIN` only on an authenticated channel (or drop it from the protocol and rely on the sender's own timer); put one monotonic deadline around every read on every platform; close the active socket in `Sender.stop()`.
- **Codex relation:** *related to* LAN hardening; will naturally be rewritten if the protocol changes.

### F-07 — Launch work during the in-memory database fallback performs destructive side effects

- **Severity:** Medium
- **Status:** CONFIRMED DEFECT (static code path)
- **Platforms:** iOS, macOS
- **Evidence:** `FlashDatabase.swift:29-46` falls back to an in-memory container on *any* container error (including a failed migration), logging only with `print`. `ios/Flash/FlashApp.swift:54-72` and `macos/Flash/FlashApp.swift:62-82` then run the normal launch task without checking `assembly.didFallbackToMemory`: `WidgetSnapshot.refresh` (writes zero counts), `tasksOnly()` → `TaskReminderScheduler.rebuild(tasks)` which removes every pending reminder not in the (empty) desired set (`TaskReminderScheduler.swift:41-55`). `IdeaReminderCenter.refresh` (`ios/Flash/App/IdeaReminderCenter.swift:37-40`) reads `allIdeas()` = `[]` and calls `store.prune(keeping: [])` (`IdeaViewStateStore.swift:62-68`), which persists an empty viewed-set.
- **Scenario:** an upgrade makes the persistent store unopenable (migration bug, disk pressure, corrupt file). The app shows "临时内存模式" (once), but also silently cancels all of the user's task reminders and wipes the on-disk idea read-state. When the store becomes openable again, every idea shows as unread and a flood of idea reminders follows; task reminders only return at the next successful launch.
- **Rev. 2 addition — the fallback alert gives harmful advice:** `ios/Flash/App/AppState.swift` `:155-158` `checkDatabaseFallback` (identical text in `macos/Flash/App/AppState.swift:149-152`) says "…重启后数据可能丢失，建议尽快导出备份". In fallback mode the repository is the *empty in-memory* container, so "export now" produces a valid, strict v2 backup that contains only what was typed this session. If the user later restores it with 覆盖导入 after the real store reopens, they replace their real data with that near-empty backup. Re-verified: `IdeaReminderCenter.refresh` → `store.prune(keeping: [])` persists `{viewed: [], baseline: true}` (`IdeaViewStateStore.swift:62-76`), so the next healthy launch shows every idea as unread.
- **Impact:** user-visible state loss caused by a *recoverable* fault; compounds a stressful failure. The on-disk store itself is not modified, but the advice in the alert can lead the user to destroy it.
- **Smallest corrective direction:** skip reminder rebuild, widget refresh, and idea-state pruning while `didFallbackToMemory` is true; block export/share/LAN-send (or label them as "this session only") in fallback mode; surface the underlying error in the alert and offer retry (re-open) rather than only "restart".
- **Codex relation:** *independent*; touches launch code that startup-performance work may also edit.

### F-08 — HarmonyOS merge/overwrite rewrites tables from validated in-memory rows and deletes quarantined originals, contradicting the UI message

- **Severity:** Medium
- **Status:** CONFIRMED DEFECT (static)
- **Platforms:** HarmonyOS
- **Evidence:** `FlashStore.ets:262-292`: rows failing validation are excluded from `this.logs/emotions/tasks`, copied to a quarantine file *capped at 1 MiB* (`:38`, `:344-349`), and the warning says "隔离副本写入失败，原始内容仍保留在数据库中" (`:292`). `mergeAll` (`:766-788`) builds merged sets from `this.logs/emotions/tasks` and calls `replaceDatabase`, which runs `DELETE FROM` on all three tables (`:809-811`) and re-inserts only the validated rows. `replaceAll` and `clearAll` behave similarly (the latter intentionally). The quarantine file also expires after 30 days (`:41`).
- **Scenario:** an upgrade tightens a validator (or a future schema adds a rule); N existing rows become "validation-rejected" and disappear from the UI. The user then imports a backup with "merge" — the rejected rows are deleted from the database. If the quarantine copy exceeded 1 MiB or the 30 days passed, the data is gone.
- **Rev. 2 nuance:** while rejected rows remain in the database, `loadBusinessData` → `persistDatabaseRecovery` rewrites `quarantine/rdb-payloads.json` on every launch (`FlashStore.ets:471-487`, `writeQuarantineFile` with `TRUNC`), which refreshes its mtime, so the 30-day TTL in `cleanupQuarantine` (`:400-423`) does not run down while the originals exist. The TTL starts only after a merge/replace has deleted the originals, which is exactly when the copy becomes the only one. Separately, a stored row whose zone is outside the F-02 list is rejected here, so on HarmonyOS F-02 also hides existing tasks and makes them eligible for this deletion.
- **Impact:** irreversible loss of rows the app told the user were preserved. Amplified by F-02/F-05 if those cause rejections.
- **Smallest corrective direction:** make merge/replace operate row-wise (`INSERT OR REPLACE` of incoming rows; delete only ids known to the in-memory set), or refuse destructive operations while rejected rows exist and offer the recovery export first.
- **Codex relation:** *independent*.

### F-09 — Swift UUID check accepts trailing line terminators; other platforms and the reference validator reject

- **Severity:** Medium
- **Status:** CONFIRMED DEFECT (pattern probe executed; end-to-end import not executed)
- **Platforms:** iOS, macOS vs Android, HarmonyOS, `validate.cjs`
- **Evidence:** `BackupService.swift:214-215` (`^…$` via `NSRegularExpression`), `:660-662` (`firstMatch`). Probe output: `plain: true`, `trailing LF: true`, `trailing CRLF: true`, `trailing U+2028: true`. Kotlin uses `Regex.matches` on the whole input (`Backup.kt` `UUID_REGEX`), JS `$` (no `m` flag) matches only at the end, and Ajv's pattern is likewise strict. Used for `id` and `sourceLogId`.
- **Scenario:** a hand-edited or generated backup contains `"id": "<uuid>\n"`. Apple `parseStrict` accepts it, the record is stored, and later `exportStrictJSON` (same lax regex) re-emits it. Android/HarmonyOS then fail the entire strict import ("存在非法或重复记录") and the reference validator reports the file invalid. Ids containing newlines also reach logs/UI.
- **Impact:** contract drift, cross-platform interop failure, odd identity values. Needs a malformed/crafted source file.
- **Smallest corrective direction:** anchor with `\A…\z` (or compare `firstMatch` range to the whole string, as `normalizeISODate` already does); add `"…\n"` negative fixtures to `cases.json`.
- **Codex relation:** *independent*; small change in a file Codex is likely to edit.

### F-10 — Export and overwrite-in-place file handling can destroy or leak backups

- **Severity:** Medium
- **Status:** CONFIRMED (static) for (a)–(c); RISK for (d)
- **Platforms:** Android (a), HarmonyOS (b, c), Apple (d)
- **Evidence:**
  - (a) `SettingsViewModel.kt:100` `openOutputStream(target, "wt")` truncates the destination first; an I/O failure mid-write leaves a truncated file, and if the user chose an existing backup as the destination, the previous good backup is gone. The exception text is shown raw (`"导出失败：${it.message}"`).
  - (b) `BackupFiles.ets:35` opens the picker destination with `TRUNC`; on a short write it `unlink`s the destination (`:46`) — which deletes a pre-existing file the user chose to overwrite.
  - (c) `BackupFiles.ets:99-125` `exportToSharedDir` writes plaintext JSON into the shared Download directory (`Download/Flash/…`) with no expiry or cleanup, unlike the cache copies on Apple/Android (24 h).
  - (d) `BackupTransfer.swift:71-76`: the temp file is created with default permissions and tightened to `0600` afterwards; a crash between leaves `.flash-backup-*.tmp` in the destination folder with plaintext content (low).
- **Impact:** data loss on failed overwrite of an existing backup (Android, HarmonyOS); plaintext journal left in user-visible shared storage (HarmonyOS).
- **Smallest corrective direction:** write to a temp document/file, verify size/readback, then replace; for shared-storage export add an expiry/removal path or a clear UI warning plus a "delete exported copy" action.
- **Codex relation:** *independent*.

### F-11 — Reminder timing semantics differ per platform and none is verified under clock/timezone changes

- **Severity:** Medium
- **Status:** RISK / HYPOTHESIS (platform behaviour not observed)
- **Platforms:** all
- **Evidence:** Apple schedules `UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSinceNow)` (`TaskReminderScheduler.swift:67`) — a relative interval frozen at scheduling time; iOS also caps pending local notifications (documented platform limit of 64, not exercised by `rebuild`, which adds every desired request, `:49`). Android uses WorkManager `setInitialDelay` (`TaskReminderScheduler.kt:68`) — inexact and subject to Doze/standby buckets; no exact-alarm API. HarmonyOS converts the instant to **device-local calendar fields** (`TaskReminderScheduler.ets:80`), so a later timezone change moves the firing instant; rebuild only runs at launch, save, and import. `acceptance.md` step 8 expects "通知按绝对时刻触发" across timezone changes; no automated or device test covers it.
- **Impact:** late, early, or missing reminders after travel, manual clock changes, battery optimisation, or >64 pending reminders.
- **Test plan:** device matrix: (1) set reminder +5 min, change device timezone before it fires; (2) manual clock jump; (3) Android with battery saver / idle device; (4) 70 future reminders on iOS. Decide per platform whether inexactness is acceptable and document it.
- **Codex relation:** *independent*.

### F-12 — macOS has no notification delegate or action categories

- **Severity:** Medium
- **Status:** HYPOTHESIS (macOS foreground-notification behaviour not observed)
- **Platforms:** macOS (iOS has both)
- **Evidence:** `grep` for `UNUserNotificationCenter`/`registerCategories`/`willPresent` finds a delegate and category registration only in `ios/Flash/FlashApp.swift:38-40` and `ios/Flash/App/NotificationDelegate.swift`. The shared scheduler sets `categoryIdentifier` (`TaskReminderScheduler.swift:65`) for every platform. macOS is a menu-bar resident app (`AppDelegate.applicationShouldTerminateAfterLastWindowClosed → false`).
- **Impact (if the platform default applies):** reminders that fire while the Flash window is frontmost are not presented; "完成/稍后" actions never appear on macOS.
- **Test plan:** macOS: create a task with a reminder 1–2 min ahead, keep the main window frontmost, observe.
- **Codex relation:** *independent*.

### F-13 — CI does not exercise the platforms or configurations it is meant to protect

- **Severity:** Medium
- **Status:** CONFIRMED (workflow and scheme reading); whether the `xcode-27` runner exists is NOT VERIFIED
- **Platforms:** iOS, macOS, Android, HarmonyOS
- **Evidence:** `.github/workflows/backup-contract.yml`: four jobs (`:10,24,36,55`). The macOS job runs `xcodebuild test -scheme Flash` (`:61`); the `Flash` scheme's only testable is `FlashTests` (`macos/Flash.xcodeproj/xcshareddata/xcschemes/Flash.xcscheme`, 2 files, 13 `@Test`). iOS scheme: `FlashTests` only (4 files, 14 `@Test`) and no workflow job at all. The 25-file FlashKit test target (~194 `@Test`: `BackupContractTests`, `BackupServiceTests`, `FlashRepositoryTests`, `SchemaMigrationTests`, `LocalBackupTransferTests`, …) is run only by a manual `swift test`; no CI step calls it, and the Xcode schemes do not include it. Android CI runs `testDebugUnitTest` + `assembleDebugAndroidTest` and the emulator job; release/R8 (`isMinifyEnabled = true`, `android/app/build.gradle.kts:69`) is never built. HarmonyOS CI runs host tests only; no hvigor build, so the release obfuscation (F-05) is never exercised. `acceptance.md` describes the macOS job as covering contract/repository behaviour.
- **Impact:** F-02, F-03 and F-09 are all in code paths the CI does not run on Apple platforms; iOS regressions are invisible; release-only failures (R8, obfuscation) ship unseen.
- **Smallest corrective direction:** add a `swift test` job for `shared/FlashKit`, an iOS `build-for-testing` job (the `AGENTS.md` command already exists), an Android `assembleRelease`/R8 check with an ephemeral key, and (when feasible) an hvigor release build.
- **Codex relation:** *related*: hardening is only checkable on Apple platforms if these jobs exist; otherwise Codex's tests run locally only.

### F-14 — Import memory/element budgets are uneven across platforms (resource-exhaustion hypotheses)

- **Severity:** Medium
- **Status:** HYPOTHESIS (no measurement)
- **Platforms:** all (differently)
- **Evidence:** Swift has a 10 M-token budget (`BackupService.swift:212`) but the scanner copies the whole text into `[Unicode.Scalar]` (`:68`, 4 bytes/scalar) and builds a `String` per scalar for every string value (`:119`). Kotlin has no element budget in `StrictJson.kt`; `Backup.readJson` holds `ByteArrayOutputStream` + `toByteArray` + decoded `CharBuffer` + `String` (`Backup.kt`, `readJson`), and `parse`/`parseStrict` each call `json.toByteArray(UTF_8)` again just for the size check. ArkTS has no element budget in `StrictJSONScanner` and also re-encodes the full text for size checks (`BackupService.ets:227,267,352`). Receivers allocate `ByteArray(size)`/`Uint8Array(size)` up to 50 MiB after proof verification.
- **Failure scenario to test:** a valid-but-huge 50 MiB file (e.g. millions of tiny numbers in arrays, or one 50 MiB string) on a low-memory device; OOM/ANR on Android/HarmonyOS, long stalls on Swift (off-main but memory-heavy).
- **Test plan:** generate two fixtures (many tiny elements; one large string), run strict import under a memory profiler on one low-end Android, one iPhone, one HarmonyOS device; record peak RSS and time; no numbers are claimed here.
- **Codex relation:** *related* to the announced resource-limit work; likely overlapping edits in the scanners.

### F-15 — Main-thread and full-table work on write and import paths (performance hypotheses)

- **Severity:** Medium
- **Status:** HYPOTHESIS (no measurement)
- **Platforms:** iOS, macOS (Android/HarmonyOS differ, see below)
- **Evidence:** `BackupImportCoordinator.apply` is `@MainActor` and runs `replaceAll`/`mergeAll` synchronously (`BackupImportCoordinator.swift:75-88`); `SettingsScreen.currentSnapshot` maps all three tables on the main actor (`ios/.../SettingsScreen.swift:311-314`). Every successful `commit` triggers `WidgetSnapshot.refresh` → `widgetTodaySummary` → `tasksOnly()` full table mapping (`FlashRepository.swift:301,335`) and `WidgetCenter.reloadAllTimelines()` (`:431`), plus the root view's `allIdeas()` refresh (`IdeaReminderCenter.swift:37`). Multiple views hold unbounded `@Query` over all rows (`MemoryView`, `CalendarView`, `StatsView`, `LogFlowView`, macOS `HomeView`, iOS `ExploreScreen.swift:39`). No `#Index` on any model. Contrast: Android pushes filters/limits into SQL with indexes (Migration 3→4); HarmonyOS keeps all rows in memory (`FlashStore.ets` `this.logs/emotions/tasks`) and `mergeAll` rewrites all tables (F-08).
- **Test plan:** `PerfBaselineTests` already synthesises 10 k/5 k/2 k rows; add 100 k, measure main-thread hitches during import and during a single log add (Instruments hangs/signposts `StartupAssembly`, etc.), widget reload counts per minute of typing/editing, and memory with all tabs visited.
- **Codex relation:** *related* to the performance-hardening scope.

### F-24 — HarmonyOS reminder rebuild doubles the live reminder count before cancelling (new in rev. 2)

- **Severity:** Medium
- **Status:** RISK (the code path is confirmed statically; the per-application reminder quota is taken from the platform's reminderAgentManager documentation, about 30 valid reminders per app, and was NOT VERIFIED on a device)
- **Platforms:** HarmonyOS
- **Evidence:** `harmonyos/entry/src/main/ets/data/TaskReminderScheduler.ets:36-37` reads the existing task reminders. `:75-94` publishes a **new** reminder for every pending task (`publishReminder`), and only after the whole loop do `:95-97` cancel the previous set. Steady state with N pending reminders: the app briefly holds 2N valid reminders. Nothing caps or prioritises N. `rebuild` runs at launch, after save, and after import. Callers catch the failure and show a misleading message: "任务已保存，但系统提醒未启用" (`state/CalendarController.ets:206-211`) or "任务提醒恢复失败…" at launch (`state/AppController.ets:84-88`).
- **Scenario:** a user has ≥ 16 future task reminders. The next rebuild (any task save, import, or launch) passes the quota partway through the publish loop. `publishReminder` rejects, the rebuild throws before cancelling anything, and the reminders already published in this pass remain as duplicates. Every later rebuild fails at the same point. Reminders for the tasks after that point are never scheduled, and the user sees duplicate notifications for the others.
- **Test plan:** on a device or emulator, create 20 tasks with future reminders, save one more, and inspect `getAllValidReminders()` and the error path. Host test idea: give the `reminderAgentManager` fake a 30-entry quota and assert that rebuild with 20 pending tasks succeeds without duplicates.
- **Smallest corrective direction:** cancel-then-publish per task (or cancel all, then publish, accepting a short gap), and cap publication to the soonest K reminders within the quota, rescheduling the rest on later rebuilds. Surface "提醒数量已达系统上限" instead of a generic failure.
- **Codex relation:** *independent*.

### F-25 — HarmonyOS overwrite/merge/migration "transaction" mixes sync `beginTransaction()` with awaited async writes (new in rev. 2)

- **Severity:** Medium (potential data loss), **Status:** HYPOTHESIS (depends on ArkData RDB connection/transaction semantics that host tests fake and that were not observed on a device)
- **Platforms:** HarmonyOS
- **Evidence:** `harmonyos/entry/src/main/ets/data/FlashStore.ets:805-821` `replaceDatabase`: `database.beginTransaction()` (synchronous API) is followed by `await database.executeSql('DELETE FROM …')` ×3 and `await database.batchInsert(...)` in 5 000-row chunks (`:827-832`), then `database.commit()` / `rollBack()`. Every destructive bulk path goes through it: `replaceAll`, `replaceAllIfCurrent`, `mergeAll` (`:766-788`, a full-table rewrite, see F-08), `clearAll`, and the one-time Preferences→RDB migration (`:243`). The host loader fakes RDB (`harmonyos/tests/ets-loader.cjs`, "covers business behavior, not … native RDB behavior"), so no test shows whether the async statements run inside the transaction opened by the sync call. `targetSdkVersion` is `26.0.0` (`harmonyos/build-profile.json5`); the code does not use the transaction-object API.
- **Failure scenario (if the premise fails):** a merge import of a large backup hits an error in a later `batchInsert` (low storage, constraint, process kill). The three `DELETE`s have already committed outside the transaction and `rollBack()` has nothing to undo, so the user's tables are left empty or partial. Because `mergeAll` routes through the same full rewrite, an ordinary *merge* is exposed, not just overwrite.
- **Test plan:** on a device, inject a failure after the `DELETE`s (e.g. a deliberately invalid row in the third `batchInsert`) and check row counts after `rollBack()`; repeat while the app is killed mid-import.
- **Smallest corrective direction:** use the transaction API that binds async statements to one transaction (or the synchronous `executeSqlSync`/`batchInsertSync` family inside `beginTransaction`), and make `mergeAll` row-wise (see F-08) so a merge never deletes.
- **Codex relation:** *independent*; touches the same functions as F-08.

### F-16 — iOS root view depends on a non-observable `revision` counter

- **Severity:** Low · **Status:** HYPOTHESIS
- **Evidence:** `FlashRepository.revision` is a plain stored property of a non-`@Observable` class (`FlashRepository.swift:46`); `RootView.swift:67` uses `.onChange(of: repository?.revision ?? 0)` to recompute unread ideas, badge, reschedule, and widget unread count. Writes that happen without a root-view re-evaluation (App Intents `CaptureFlashIntent`, notification actions in `TaskReminderActions`) may not trigger the refresh until some observed state changes.
- **Impact:** stale badge/unread count/widget count after intent-driven captures.
- **Test plan:** run the "记一闪" shortcut, return to the app/widget, compare counts; same for the notification "完成".

### F-17 — Privacy surfaces (lock screen, drafts, at-rest, logging)

- **Severity:** Low · **Status:** RISK
- **Evidence:** task titles are notification bodies (`TaskReminderScheduler.swift:62`, Android `setContentText(title)` without a private-visibility public version `TaskReminderScheduler.kt:182`), and HarmonyOS shows up to 500 characters of task notes (`TaskReminderScheduler.ets:84`); lock-screen accessory widgets show the dominant-emotion emoji and counts (`TodayWidget.swift:177`) with no `privacySensitive`; the quick-capture draft is plaintext in `UserDefaults` (`QuickCaptureDraftStore.swift`); no explicit file-protection class/entitlement for the SwiftData store (platform default applies); cloud-backup policy differs (Android excludes everything via `data_extraction_rules.xml`; Apple uses defaults; HarmonyOS not configured/NOT VERIFIED); 46 `print(...)` sites log raw `Error` values (`grep print(` over `ios/ macos/ shared/FlashKit/Sources`), which for SwiftData/JSON errors can include record text and paths; Release builds keep them.
- **Smallest corrective direction:** decide a policy for lock-screen content (generic body unless unlocked), route diagnostics through `os.Logger` with `privacy: .private`, and document the at-rest/cloud-backup choice per platform.

### F-18 — Apple privacy manifests declare only UserDefaults

- **Severity:** Low · **Status:** HYPOTHESIS (App Store validation not run)
- **Evidence:** `ios/Flash/PrivacyInfo.xcprivacy` and `macos/Flash/PrivacyInfo.xcprivacy` list only `NSPrivacyAccessedAPICategoryUserDefaults`. Compiled-in code uses file-timestamp and size APIs (`BackupTransfer.swift` `contentModificationDateKey`; `BackupImportCoordinator.swift:43` `fileSizeKey`) and `statfs` (`BackupTransfer.swift` `isLocalVolume`), which Apple lists as required-reason categories (file timestamp, disk space).
- **Impact:** possible App Store Connect validation failure when iOS/Mac App Store distribution begins.
- **Test plan:** archive and validate the iOS build in Xcode Organizer.

### F-19 — LAN protocol deviations from `lan-handshake-v1.1.md`

- **Severity:** Low · **Status:** CONFIRMED (static)
- **Evidence:** the spec requires `size` to reject leading zeros; Swift does (`LocalBackupTransfer.swift:110`), Kotlin (`:53` `\d+`) and ArkTS (`:34` `[0-9]+`) accept `OK 007 …`. In the rejected-answer drain, Swift bounds `size` (`:798-799`) while Kotlin (`drainRejectedAnswer`, no upper bound) and ArkTS (`:441`) do not (bounded only by the 120 s cap). Kotlin `Discovery.onServiceLost` removes by name only (`:320`), so a spoofed same-name service disappearing removes the genuine entry. OK-header cap is 128 bytes vs the spec's 96 (documented as tolerated in the Swift comment). Rev. 2 additions: the HarmonyOS sender `return`s from its line loop right after starting an async `answer` (`LocalBackupTransfer.ets:242-249`), so any further lines in the same chunk (e.g. a pipelined `ERR PIN`) are not processed until another chunk arrives. A second `CHALLENGE` handled while the first answer's three `send` calls are still in flight can interleave two answers on the wire (honest receivers wait for the drain, so only crafted peers can trigger it). All three senders and the Kotlin receiver measure deadlines with wall-clock time (`System.currentTimeMillis()`, `Date()`), so a clock change during a session shortens or extends it.
- **Test idea:** add the spec-listed negative cases ("OK 007 …", "OK 123abc …") to every platform's receiver tests.

### F-20 — Android overwrite import resets idea read-state and the overwrite guard is not atomic

- **Severity:** Low · **Status:** CONFIRMED (static) · **Platforms:** Android
- **Evidence:** `LogDao.clearAll` (`DELETE FROM logs`, `Daos.kt`) cascades to `idea_view_state` via the foreign key (`Entities.kt` `IdeaViewStateEntity`), so after `replaceAll` every idea is "unviewed"; Apple/HarmonyOS preserve the viewed ids that still exist (`IdeaViewStateStore.prune`, `FlashStore.pruneIdeaViewState`). The staleness check in `SettingsViewModel.confirmImport` (`:295-322`) compares snapshots in one transaction and writes in another; Swift performs both on the main actor, HarmonyOS inside the write queue (`replaceAllIfCurrent`).
- **Impact:** a restore of the same data re-surfaces all ideas as unread; a concurrent write in the gap is overwritten.

### F-21 — Validation lives in different layers per platform; one invalid record can block all exports

- **Severity:** Low · **Status:** RISK
- **Evidence:** Android enforces `TextLimits` inside the repository (`FlashRepository.kt` `addLog`, `updateLog`); Swift `FlashRepository.addLog/updateLog/saveTask` accept any content/title and rely on each UI (`LogEditSheet`, `TaskEditorView`, `QuickCaptureCommit`); HarmonyOS relies on UI `maxLength` and silently truncates at the store (`FlashStore.ets:548` 10 000 chars; `:703-704` 50/2 000 vs the 100 000 contract limit). Because export is strict (F-02 mechanism), any record that violates the contract (oversized text from an older build, a future write path such as an intent or notification action that skips the UI check) makes **every** export fail with a generic message.
- **Smallest corrective direction:** enforce contract limits at the repository/store boundary on every platform; make export errors name the offending record.

### F-22 — Documentation that no longer matches the implementation

- **Severity:** Low · **Status:** CONFIRMED
- **Evidence:**
  1. `README.md` "两端格式一致、可互读" vs F-03.
  2. `docs/contracts/*` and `docs/flash-backup-*.md` never mention iOS, although iOS exports schema 2 and sends/receives over LAN.
  3. `docs/contracts/README.md` §3 says `UTC`/`Etc/*` are invalid; `canonical-timezones.json` and `validate.cjs:79-84` include `UTC`, `Etc/UTC` (F-02).
  4. `docs/contracts/acceptance.md` states the macOS CI job covers contract/repository behaviour; it runs 13 app-level tests (F-13); its test counts are labelled historical but the CI paragraph is not.
  5. `README.md` build section says "Xcode 26"; the workflow comment says Xcode 27 is required (`backup-contract.yml:56-57`).
  6. `AGENTS.md` describes `app/` as three native projects; `ios/` and `shared/FlashKit` exist and the iOS command is in the same file.
  7. `.superpowers/audit-2026-09-19/timezone-alignment-report.md` is tracked although `.superpowers/` is git-ignored, and describes the list as canonical IANA IDs.

### F-26 — Swift reminder rebuild can drop a reminder scheduled while it is suspended (new in rev. 2)

- **Severity:** Low · **Status:** RISK (actor-reentrancy reasoning from the code; not reproduced)
- **Platforms:** iOS, macOS
- **Evidence:** `shared/FlashKit/Sources/FlashCore/Data/TaskReminderScheduler.swift:41-55`. `rebuild(tasks)` builds `desired` from a snapshot taken by the caller (`ios/Flash/FlashApp.swift:61-64`, `BackupImportCoordinator.swift:91-95`), then suspends on `requestAuthorization` and on each `center.add`. Because `TaskReminderScheduler` is an `actor`, `schedule(newTask)` (`:27-35`) can run during those suspensions. Afterwards, `rebuild` removes every pending `flash-task-reminder-*` request whose identifier is not in its *old* `desired` set (`:50-54`), which includes the reminder just added for a task created after the snapshot.
- **Scenario:** right after launch (or right after confirming an import), while the rebuild is still adding requests, the user saves a new task with a reminder. The new reminder is added and then removed by the finishing rebuild, and does not return until the next rebuild.
- **Smallest corrective direction:** serialise rebuild against schedule/cancel (a generation counter checked before the stale sweep, or re-reading tasks inside the actor before removing), and add a test that interleaves `schedule` with a slow `rebuild`.

### F-27 — Android reminders fail silently at fire time and save errors misreport (new in rev. 2)

- **Severity:** Low · **Status:** CONFIRMED (static)
- **Platforms:** Android
- **Evidence:** `TaskReminderWorker.doWork` returns `Result.success()` without notifying when `POST_NOTIFICATIONS` is not granted or notifications are disabled (`android/.../data/reminder/TaskReminderScheduler.kt:160-165`). `schedule()` (`:45-56`) never checks `canNotify()`; only `rebuild()` does (`:89-91`). Android has no launch-time rebuild (no call site besides import/clear, `SettingsViewModel.kt:335,357`), so nothing re-surfaces the problem. In `ui/calendar/CalendarViewModel.kt:189-204` and `ui/navigation/FlashApp.kt:287-289` the task is persisted first and `schedule()` runs inside the same `runCatching`, so a scheduling exception shows "任务保存失败" although the task was saved.
- **Scenario:** a user who denied notification permission (or turned off the channel) keeps creating tasks with reminders; every reminder is accepted in the UI and silently never fires. Apple and HarmonyOS surface permission denial; Android does not.
- **Smallest corrective direction:** check `canNotify()` when saving a task with a reminder and show the same hint the other platforms show; separate "saved" from "reminder scheduled" in the result message.

### 3.1 Next-beta UI/UX preparation risks (observations only, no redesign proposed)

Grep-level counts at `e9a0aa6`; no device or accessibility-tool verification was done.

- **Hard-coded visual values.** Android has 152 `Color(0x…)` literals, 110 of them in `ui/theme/Theme.kt` and 24 in `glass/GlassTheme.kt` (centralised); outside the theme, `WelcomeScreen.kt` (3), `HomeScreen.kt` (2). Swift: 2 `Color(hex:)`, 1 `.font(.system(size:))`, 8 uses of `ScaledMetric`/`dynamicTypeSize`. HarmonyOS: 37 literal `fontSize(...)` calls and 14 elements with fixed heights below 44 (`.height(<44)`), so a token refresh needs more than one file there. Android also keeps two full style systems (MD3 and Glass) → every visual change has to be made twice.
- **Component coupling across platforms.** `shared/FlashKit/Sources/FlashDesign` is shared by iOS and macOS and contains `GlassCard`, `PlatformModifiers`, view-compute caches keyed by `FlashRepository.revision`; changing a shared component alters both Apple apps implicitly (this is also true for the data layer: a `FlashCore` change moves macOS and iOS together).
- **Dynamic Type / AX5.** One commit (`e9aea05`) addressed accessibility sizes on iOS; remaining fixed frames/`lineLimit(1)` (5 sites) and the single `minimumScaleFactor` were not exercised at AX5. Android has no recorded 2.0× font run (`docs/quality/device-matrix.md` lists it as untested). HarmonyOS large-font and screen-reader runs are deferred (no device).
- **VoiceOver/TalkBack equivalents.** Swift: 28 `accessibilityLabel`, 3 hint/value; Android: 25 `contentDescription` strings vs 13 `contentDescription = null` (need a pass to confirm the null ones are decorative — e.g. `HomeScreen.kt:244,333,384,397`, `SettingsScreen.kt:194,554,580`); HarmonyOS: 17 accessibility text/description uses. TalkBack and VoiceOver runs are recorded as "待完整操作".
- **Reduce Motion.** Apple: 39 reads of `accessibilityReduceMotion`; HarmonyOS: in-app switch because no system query exists; Android: 0 explicit references and 42 animation call sites (system animator scale may cover it — NOT VERIFIED).
- **Keyboard access.** macOS has shortcuts and focus handling (38 matches); iOS/Android/HarmonyOS keyboard navigation not reviewed.
- **Contrast.** Not measured on any platform; deep/glass backgrounds (`GlassBackground`, `Glass.kt`) are the places to check first.
- **Rollback readiness.** Tokens exist per platform but are duplicated three times (Swift `FlashTokens`, Kotlin `FlashTokens`/`Theme`, ArkTS `DesignTokens.ets`) with no shared source; a refresh that must be rolled back needs per-platform revert points.

---

---

## 4. Cross-platform consistency matrix

"✓" = present and matches the contract as read; entries are from source, not from devices.

| # | Capability / behaviour | iOS | macOS | Android | HarmonyOS | Notes / refs |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Backup section schema read | 1, 2 | 1, 2 | 1 only | 1 only | F-03 |
| 2 | Backup section schema written | 2 | 2 | 1 | 1 | `BackupService.swift:204`; `Backup.kt:40`; `BackupService.ets:219` |
| 3 | Strict import (`parseStrict`), recovery import | ✓ | ✓ | ✓ | ✓ | all reject unknown fields |
| 4 | Duplicate JSON key scan | ✓ | ✓ | ✓ (`StrictJson`) | ✓ (`StrictJSONScanner`) | |
| 5 | JSON element/token budget before parse | 10 M | 10 M | none | none | F-14 |
| 6 | UUID format check semantics | lax (trailing LF/CRLF/U+2028) | lax | strict | strict | F-09 |
| 7 | Time-zone whitelist | ICU-legacy list | same | same | same | F-02; creation uses raw device id on iOS/macOS/Android/HarmonyOS |
| 8 | Text-limit enforcement layer | UI + `QuickCaptureCommit` | UI + controller | repository | UI `maxLength` + silent store truncation | F-21 |
| 9 | LAN handshake v1.1 (receiver challenge, sender proof, payload MAC) | ✓ | ✓ | ✓ | ✓, but receiver misparses split delivery | B-1 still applies; F-23 |
| 10 | Receiver authenticated to sender | ✗ | ✗ | ✗ | ✗ | F-01 |
| 11 | `ERR PIN` accepted without prior auth | ✓ (bug) | ✓ | ✓ | ✓ | F-06 |
| 12 | `OK` size rejects leading zeros | ✓ | ✓ | ✗ | ✗ | F-19 |
| 13 | Drain size bounded in rejected answer | ✓ | ✓ | ✗ | ✗ | F-19 |
| 14 | Total/session deadline enforced on active connection | ✓ | ✓ | only between connections | ✓ (60 s timer closes) | F-06(c) |
| 15 | Overwrite import staleness check atomic with write | ✓ (MainActor) | ✓ | ✗ | ✓ (write queue) | F-20 |
| 16 | Idea read-state after overwrite import | preserved for surviving ids | n/a (no idea reminders) | reset (FK cascade) | preserved | F-20 |
| 17 | Behaviour when the DB cannot open | silent fallback to in-memory + alert | same | exception (no fallback) | store "not ready", writes rejected | F-07 |
| 18 | Quarantine of unreadable rows | ✗ | ✗ | ✗ | ✓ (file, 1 MiB, 30 d after originals are gone) | F-08 |
| 19 | Encryption at rest | platform default | platform default | none (private storage) | encrypted RDB (S1) | |
| 20 | Cloud-backup policy | defaults | defaults | excluded entirely | not configured / NOT VERIFIED | F-17 |
| 21 | Reminder mechanism | relative-interval local notification | same | WorkManager delay | reminderAgent calendar (local wall clock) | F-11 |
| 21a | Reminder quota handling | platform keeps soonest 64; rebuild replaces in place | same | none needed | publish-before-cancel doubles count; no cap | F-11, F-24 |
| 21b | Rebuild at launch | ✓ | ✓ | ✗ (WorkManager persistence only) | ✓ | F-27 |
| 21c | Notification permission denial surfaced | ✓ (save path hint) | ✓ | ✗ (silent at fire time) | ✓ ("系统提醒未启用") | F-27 |
| 21d | Rebuild serialised against single schedule/cancel | ✗ (actor reentrancy) | ✗ | ✓ for rebuild (`Mutex`), schedule unsynchronised | ✓ (promise queue) | F-26 |
| 22 | Reminder actions (完成/稍后) | ✓ | ✗ (no categories) | ✗ | ✗ | F-12 |
| 23 | Foreground notification presentation | delegate ✓ | no delegate | n/a | n/a | F-12 |
| 24 | Deep links | `capture`, `today`, `ideas` | `today` only | none | none | `AppState.swift` (ios) vs `FlashApp.swift` (macos) |
| 25 | App Intents / Shortcuts / Control Center | ✓ | ✗ | ✗ | ✗ | `ios/Flash/Intents` |
| 26 | Widgets / cards | WidgetKit (App Group ✓) | WidgetKit (App Group ✗ → inert) | ✗ | form card | `WidgetSnapshot.swift` header note |
| 27 | Idea-reminder push notifications | ✓ | ✗ | in-page only | in-page only | ROADMAP |
| 28 | Export file atomicity | `fileExporter` (system) | temp + `replaceItemAt` | `"wt"` truncate | `TRUNC` + unlink on short write | F-10 |
| 29 | Shared plaintext copies expire | cache, 24 h | cache, 24 h | cache, 24 h | share cache: not verified; Download dir: never | F-10 |
| 30 | Reduce-motion handling | environment | environment | system animator scale only (not verified) | in-app switch | ROADMAP; grep: 0 Android references |
| 31 | Release configuration in CI | ✗ | debug test only | ✗ (no R8 build) | ✗ (no hvigor build) | F-13 |
| 32 | Release signing | none | ad-hoc `CODE_SIGN_IDENTITY="-"` | env-driven (good); history leak F-04; distributed Alpha010 is debug-signed and debuggable | `signingConfigs: []` | `project.pbxproj`; `app/build.gradle.kts` |
| 33 | Bulk replace/merge atomicity | single `ModelContext.save` with rollback | same | Room `withTransaction` | sync `beginTransaction` around async writes (unverified) | F-25 |
| 34 | Merge semantics | upsert by id (row-wise) | same | upsert by id (row-wise) | full-table rewrite from validated memory | F-08, F-25 |
| 35 | Local Network / Bonjour declarations | `NSBonjourServices` + usage string ✓ | ✓ | `NEARBY_WIFI_DEVICES` + multicast lock ✓ | `INTERNET` only (mdns permission NOT VERIFIED) | `ios/FlashInfo.plist`, `macos/FlashInfo.plist`, `AndroidManifest.xml`, `module.json5` |

---

## 5. Test and CI gaps

### 5.1 CI (`.github/workflows/backup-contract.yml`)

- **No iOS job.** The branch under review is the iOS port; its `FlashTests` (14 `@Test`) are never run remotely.
- **FlashKit tests never run in CI** (≈194 `@Test` across 25 files) — they contain the real backup-contract, repository, migration, LAN and reminder tests. Local `swift test` only.
- **macOS job** runs `FlashTests` only (13 `@Test`: `AppStateTests`, `KeyChordTests`). The runner label `xcode-27` (`:58`) is non-standard; whether it exists and whether those jobs have actually run recently was not checked.
- **Android:** debug unit tests, androidTest assembly, and emulator tests at API 35 only. No `assembleRelease` (R8/minify), no lint, no dependency audit. Target/compile SDK is 36; the emulator job uses 35.
- **HarmonyOS:** host tests via TypeScript transpile with hand-written fakes (`harmonyos/tests/ets-loader.cjs`); no hvigor build, no obfuscated build, no linter run.
- **Contract:** Ajv-based validator and fixtures are good, but fixtures lack: non-Shanghai zones, `UTC`/`Etc/UTC` positive cases, UUID-with-newline negative, schema-2 expected-rejected cases for Android/ArkTS, and any fixture produced by an older app version.

### 5.2 Tests that bypass the real path or over-mock

- HarmonyOS store/controller tests run real `.ets` sources on Node with fakes for RDB, `fileIo`, `cryptoFramework`, `reminderAgentManager` (`ets-loader.cjs`). They cannot show native RDB transaction semantics (F-25) or ArkTS strictness; `acceptance.md` already says so. The `reminderAgentManager` fakes have no per-app quota (F-24). The fake `cryptoFramework` resolves on the microtask queue, and every LAN receiver test delivers the whole answer in one event, which is why F-23 is invisible to the suite.
- Android migration tests construct v1/v2 databases by hand because `schemas/…/1.json` and `2.json` were never exported (only `3.json`, `4.json` exist); the historical shape is therefore asserted by the test author's SQL, not by Room's exported schema.
- Swift LAN tests run real loopback sockets with real timing (`Thread.sleep(1.0)` for a 0.3 s idle limit, `LocalBackupTransferTests.swift:470`); `browserResolvesAdvertisingSender` uses real Bonjour. They are serialised (`.serialized`, `:265`) but depend on local network behaviour.
- `PerfBaselineTests.swift` appends to a fixed path `/tmp/flash-perf-baseline.txt` and asserts loose wall-clock bounds (`< 5 s`); `#if DEBUG` only.

### 5.3 Missing negative / migration / interruption / cross-version tests

- LAN: unauthenticated peer receives nothing (F-01); HarmonyOS receiver with proof and `OK` in separate synchronous events, and with the payload streamed in many events (F-23); `ERR PIN` before any challenge (F-06a); slow-drip on the Android *sender* (the Swift suite has a receiver slow-drip test, Android has none); leading-zero size; unbounded drain size (F-19).
- Data: timed task with `Asia/Ho_Chi_Minh`/`Europe/Kyiv`/`Etc/UTC` through every export path (F-02); id with trailing newline (F-09); record exceeding limits inserted via repository then exported (F-21).
- Lifecycle: launch in memory-fallback mode must not cancel reminders, prune state, or offer a full-looking export (F-07); HarmonyOS merge with pre-existing rejected rows (F-08); HarmonyOS rebuild with more than 15 pending reminders under a quota-enforcing fake (F-24); Swift `schedule` interleaved with a slow `rebuild` (F-26); Android save with notifications disabled (F-27).
- Atomicity: HarmonyOS `replaceDatabase` with a failure injected after the `DELETE`s, on a device (F-25).
- Migration: SwiftData V1→V2 is covered by two tests (`SchemaMigrationTests`); Room has v1→4, 2→4, 3→4; ArkTS has the Preferences→RDB migration test but no cross-version fixture. No test loads a store written by a *previous released app build*.
- Interruption: export failing mid-write over an existing file (Android, HarmonyOS) (F-10); app killed between `commit` and reminder rebuild.
- Clock/timezone: no test for reminder behaviour across timezone changes or DST (F-11).
- Cross-platform: `valid-schema2.json` is not consumed by Android or ArkTS suites; no end-to-end "Apple export → Android import" fixture.

### 5.4 Flakiness / parallelism

- `/tmp` shared file in `PerfBaselineTests`; loopback ports and Bonjour; `UserDefaults.standard` is not used by the tests I read (they inject suites). Xcode schemes run `parallelizable = YES` for `FlashTests`.

---

## 6. Ten highest-priority actions and their dependencies

| # | Action | Findings | Depends on / ordering notes |
| --- | --- | --- | --- |
| 1 | Redesign LAN authentication so the receiver is authenticated before any payload byte is released and "success" is an authenticated ack | F-01, B-1, F-06 | Must precede or be done together with 7. Defines the acceptance tests in §5.3. |
| 2 | Fix time-zone canonicalisation: alias map at creation, superset whitelist on read (accept both legacy and modern spellings, normalise to one), actionable export error, new fixtures, doc fix | F-02, F-22(3) | Shared contract files → coordinate with 3 and 8. Needed before any export-path performance work is measured. On HarmonyOS land it before or with 9 (rejected rows feed F-08). |
| 3 | Add CI: `swift test` for FlashKit, iOS `build-for-testing`, Android `assembleRelease`, optional hvigor release build | F-13 | Should land before 1, 2, 4 and 5 so their fixes can be checked remotely. Cheap and independent. |
| 4 | HarmonyOS receiver: buffer without parsing while proof/MAC verification is pending; add split-delivery tests | F-23 | Small and local. If 1 rewrites the protocol, carry the split-delivery tests into the new one; otherwise fix on the current protocol now, because it blocks HarmonyOS LAN acceptance testing. |
| 5 | Make Apple export interoperable (schema 1 when no schema-2 field is used) and plan real schema 2 on Android/ArkTS | F-03 | After 2 (same files); add schema-2 expected-rejected tests to Android/ArkTS until implemented. |
| 6 | HarmonyOS data path: make merge row-wise, refuse destructive replace while rejected rows exist, and verify (then fix) transaction binding with one device fault-injection run | F-08, F-25 | Do the device check for F-25 first: it decides whether `replaceDatabase` must move to a different transaction API. Merge-in-place removes most of the F-08 exposure on its own. |
| 7 | Gate launch side effects and export on `didFallbackToMemory`; fix the alert's "export now" advice | F-07 | Independent; small. |
| 8 | Put one monotonic deadline on every read; close the active socket on stop; accept `ERR PIN` only when authenticated; anchor the Swift UUID regex | F-06, F-19, F-09 | The LAN part folds into 1 if the protocol changes; the UUID part shares files with 2 and 5. |
| 9 | HarmonyOS reminders: cancel-then-publish and cap to the quota; verify release obfuscation with one release build | F-24, F-05 | The F-05 check is a prerequisite to any HarmonyOS release. F-24 needs one device/emulator run to confirm the quota. |
| 10 | Safe export writes (temp + verify + replace) on Android/HarmonyOS; decide shared-Download retention; treat the committed Android key as burned | F-10, F-04 | Independent. |

Next tier: F-11/F-12 device matrix for reminders, F-26/F-27 reminder consistency, F-14/F-15 measurements, F-17/F-18 privacy decisions, F-20/F-21 parity, F-22 docs.

---

## 7. What should block Codex's work vs what can proceed independently

This is a sequencing view of the *baseline*, not an evaluation of any branch.

**Settle (or at least agree on) before or alongside hardening work, because the fixes interact:**

- **F-01 / F-06 / B-1** — the protocol design must cover receiver authentication, success semantics, `ERR PIN`, and deadlines in one change. Fixing only the proof construction leaves F-01 open.
- **F-13** — without a FlashKit `swift test` job and an iOS build job, hardening in `shared/FlashKit` can only be verified locally.
- **F-02 / F-03 / F-09 / F-14** — all edit `BackupService`, `CanonicalTimeZones`, or the scanners, which resource-limit hardening will also touch. Agree an order (suggest: F-02 → F-09 → F-03, then F-14 scanner work) to avoid conflicting rewrites of the same functions and fixtures.
- **F-23** — the HarmonyOS receiver bug sits in `LocalBackupTransfer.ets`, the file LAN hardening rewrites. Whoever owns the LAN rewrite should own this fix, or agree that it lands first, so it is not fixed twice or lost in a rewrite. Until it is fixed, a failed HarmonyOS LAN receive says nothing about the new protocol.

**Independent; can proceed in parallel without affecting the hardening scope:** F-04, F-05, F-07, F-08, F-10, F-11, F-12, F-16, F-17, F-18, F-20, F-21, F-22, F-24, F-25, F-26, F-27, and all §3.1 UI/UX items. F-08 and F-25 touch the same HarmonyOS functions, so one owner should take both.

**Measure-only (no code change yet):** F-14, F-15, F-11, F-12, F-05, F-16, and the device checks behind F-24 (quota) and F-25 (transaction binding).

---

## 8. Areas reviewed where no material issue was found

- **PIN and nonce generation:** Swift `Int.random` (system CSPRNG), Kotlin `SecureRandom`, ArkTS `cryptoFramework` with rejection sampling to avoid modulo bias (`LocalBackupTransfer.ets:35-47`); nonces are fresh per challenge on all platforms.
- **Constant-time comparisons** for proof and payload MAC on all three stacks; strict regex/line shapes for `CHALLENGE`, proof, `OK`; payload MAC verified before parse on every receiver; receivers re-read the PIN per proof so correction during back-off works.
- **Receiver resource handling:** payload size bounded to 50 MiB before allocation and only after proof acceptance; 120 s transfer cap and idle timers on receivers.
- **Strict JSON handling:** BOM rejected, duplicate keys (including escaped spellings) detected, depth limited (128) on all three; unknown fields/sections rejected; booleans cannot masquerade as integers; ISO instants normalised to UTC milliseconds with truncation; real-calendar day validation.
- **Persistence atomicity:** Swift `commit` rolls back the context on any error and avoids model-wide delete in favour of per-instance deletes inside the transaction (`FlashRepository.swift:324-357`); Android `replaceAll`/`mergeAll`/`clearAll` and `exportSnapshot` run in Room transactions; HarmonyOS serialises writes through `enqueue` and wraps replace in an RDB transaction (whether that transaction actually covers the async statements is open, see F-25).
- **Database upgrade safety:** Room has no destructive-migration fallback and exports schemas 3 and 4; SwiftData uses a versioned schema and migration plan; none of the stores wipes data on failure to migrate.
- **Android platform hygiene:** `allowBackup=false` plus empty data-extraction and full-backup rules; FileProvider `exported=false` limited to `cache/shared-backups`; no cleartext-traffic configuration needed; release signing is env-only and the Gradle script fails fast without it; CI actions are pinned by commit SHA with `permissions: contents: read`; `npm ci --ignore-scripts`.
- **Deep links and intents:** deep-link parsing is a fixed host whitelist with an enum-validated `category` parameter; App Intents write via the same validated `QuickCaptureCommit` and return no stored content; notification actions only complete/snooze an existing task id.
- **Widget data minimisation:** the shared snapshot contains counts, a date and one emoji — no record text.
- **UI error surfacing for ordinary writes:** save/delete/favourite failures in `HomeView`, `LogFlowView`, `EmotionView`, `ExploreResultsView`, quick capture all surface an alert/inline message (the detail only goes to `print`, see F-17).
- **Rev. 2 checks with no issue found:** iOS file import wraps the read in `startAccessingSecurityScopedResource()` (`ios/Flash/UI/Settings/SettingsScreen.swift:221-222`); both Apple apps declare `NSBonjourServices` (`_flashbackup._tcp`) and `NSLocalNetworkUsageDescription` (`ios/FlashInfo.plist`, `macos/FlashInfo.plist`); Android DAOs use `@Upsert` rather than `REPLACE`, so merge and edit do not trigger the `idea_view_state` cascade (only `clearAll` does, F-20); the Apple overwrite-import staleness check and `replaceAll` run in one synchronous MainActor turn (`BackupImportCoordinator.swift:80-85`); the Swift receiver locks the PIN that passed the proof check for the MAC check (`LocalBackupTransfer.swift:809-811,753`); the HarmonyOS reminder `wantAgent` bundle name matches `AppScope/app.json5`.
- **Third-party dependencies:** Android uses mainstream AndroidX/Compose/Room/WorkManager/Haze; test-only `org.json`; the Node contract tools are dev-only (Ajv); HarmonyOS declares none. (Vulnerability scanning not run, see §9.)

---

## 9. Not verified (tooling, devices or evidence missing)

- Any device behaviour: Bonjour/NSD/mDNS on real networks, LAN transfer between devices, notification delivery/timing/presentation (F-11, F-12), widgets with real App Group signing, VoiceOver/TalkBack/HarmonyOS screen reader, low-storage and airplane-mode behaviour.
- F-01 and F-06 were confirmed by reading three implementations and their own tests, not by connecting a raw client to a running sender.
- F-23 was reproduced only against the host loader with Node-crypto fakes; how often real HarmonyOS socket events beat the `cryptoFramework` callback was not observed.
- F-24: the HarmonyOS per-app reminder quota is taken from platform documentation, not observed. F-25: ArkData transaction binding of async statements not observed. F-26: not reproduced.
- Which identifier a device returns from `TimeZone.current` / `ZoneId.systemDefault()` / `i18n.getTimeZone().getID()` for each region (F-02). Only Apple's *known* list on this Mac was diffed; `TimeZone(identifier: "Asia/Kolkata")` resolves on this Mac although it is not in the known list.
- F-05: no release HAP was built; the effect of the obfuscation rules on JSON keys is unknown.
- F-04: whether the repository is or was public. The committed keystore's own certificate was not read (it is password-protected and the leaked password was deliberately not used); revision 2 established only that the distributed APK uses a `CN=Android Debug` certificate.
- GitHub Actions: whether the four jobs currently run and pass, whether the `xcode-27` runner exists, branch-protection settings.
- Any dependency/vulnerability scan (SCA) — Compose BOM `2025.06.01`, AGP `8.11.1`, Kotlin `2.2.0`, Room `2.7.2`, WorkManager `2.10.1` are all pinned but their current advisory status was not checked.
- Apple App Store validation of privacy manifests (F-18); export-compliance (`ITSAppUsesNonExemptEncryption`) and entitlement behaviour of the shipped signing profiles.
- Measurements of any kind (memory, time, main-thread hangs, widget reload rate) — F-14, F-15 are hypotheses.
- HarmonyOS: module/permission behaviour of `mdns` (no explicit permission beyond `INTERNET` is declared), `allowBackup`/cloud-backup defaults, cache cleanup of `shareBackupFile` (file ends before the cleanup code was read).
- The full body of the shared SwiftUI views and the remaining Compose screens and ArkUI pages were not read line by line.
- Changelog: `AGENTS.md` requires workspace changes to be logged in `/Users/haydenjiang/Documents/flash-Alpha/CHANGELOG.md`. This report and `00-baseline.md` are untracked reviewer files under `app/docs/review/` and the changelog (outside the repo) was **not** edited, per the "save only under `app/docs/review/`" boundary. If the owner wants these logged, that is a one-line follow-up for them.
