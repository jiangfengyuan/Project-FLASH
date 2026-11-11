# Flash engineering standards

> **Status: Proposed — not ratified.** Written 2026-11-11 against `main` `65c9212`, `feat/paper-writing` `5cc8823`, `fix/pr3-review-followups` `ad31e05` and PR #5 `claude/jolly-gates-5s78bx` `3b4d71e`. A rule becomes binding when the owner ratifies it. Only rules labelled **Enforced** are checked by CI today.

> **中文摘要**：本目录是 Flash 四端（Android、iOS、macOS、HarmonyOS）的统一工程规范草案，供人工开发者与 Claude Code、Codex、Kimi Code 等智能体共同遵守。当前状态为“提议，尚未批准”。只有标注 **Enforced** 的规则目前由 CI 实际检查；其余为人工检查项或待建设项。规范基于对 `main` 与三条未合并开发线的只读核查，未执行任何原生构建或真机测试。

## Documents

| Document | Scope | Rule prefix |
| --- | --- | --- |
| [ENGINEERING-STANDARDS.md](ENGINEERING-STANDARDS.md) | Principles, sources of truth, platform and toolchain compatibility, dependencies, versioning, owner decisions | `FS-GEN`, `FS-PLAT` |
| [CROSS-PLATFORM-ARCHITECTURE.md](CROSS-PLATFORM-ARCHITECTURE.md) | Layers, module boundaries, FlashKit, persistence and migrations, anti-divergence rules | `FS-ARCH` |
| [RESOURCE-NAMING.md](RESOURCE-NAMING.md) | Names for code, data, resources, icons, tokens, tests | `FS-NAME` |
| [LOCALIZATION-STANDARD.md](LOCALIZATION-STANDARD.md) | Catalog, keys, plurals, RTL, formatting, review, migration | `FS-L10N` |
| [SECURITY-AND-DATA-CONTRACT.md](SECURITY-AND-DATA-CONTRACT.md) | Threat model, storage, permissions, LAN, release blockers, backup contract | `FS-SEC`, `FS-DATA` |
| [BUILD-TEST-CI-STANDARD.md](BUILD-TEST-CI-STANDARD.md) | CI audit and target job graph, required checks, release gate | `FS-CI` |
| [MULTI-AGENT-WORKFLOW.md](MULTI-AGENT-WORKFLOW.md) | How humans and AI agents share the repository | `FS-AGENT` |
| [ADOPTION-ROADMAP.md](ADOPTION-ROADMAP.md) | Staged plan P0–P3 | — |
| [agent-instructions/](agent-instructions/) | Draft `AGENTS.md`, `CLAUDE.md`, `KIMI.md` adapters (not active) | — |

Read `ENGINEERING-STANDARDS.md` first. The others can be read independently.

## How to read a rule

Each rule has an identifier, a level, and an enforcement label:

```
FS-DATA-04  MUST  [Enforced]  Strict import rejects unknown fields and unknown sections.
```

**Level** (RFC 2119 sense):

| Level | Meaning |
| --- | --- |
| MUST | Required. A violation blocks merge or release unless an exception is approved. |
| SHOULD | Expected. Deviation needs a written reason in the PR. |
| MAY | Permitted option; stylistic or situational. |

**Enforcement** — what checks the rule today:

| Label | Meaning |
| --- | --- |
| Enforced | A CI job on `main` fails when the rule is broken. |
| Enforced-candidate | A check exists on an unmerged branch only. Named in the rule. |
| Manual | Checked by review or a checklist; no automation exists. |
| Planned | Needs tooling that does not exist yet. Listed in the roadmap. |

**Evidence** — where a statement about the current state comes from:

| Label | Meaning |
| --- | --- |
| Verified | Checked against source, Git history, CI run data, or a command run for this work. |
| Inherited | Taken from an earlier audit and not re-verified here. The audit and finding ID are cited. |
| Proposed | A policy introduced by these standards. |
| Undecided | Needs an owner decision. Listed as `OD-nn` in [ENGINEERING-STANDARDS.md §7](ENGINEERING-STANDARDS.md#7-owner-decisions). |

## Identifier namespaces

Earlier documents already use `F-nn`, `B-1` (independent review), `D-nn`, `X-nn`, `L-nn`, `A-/M-/I-/H-nn` (2026-11-11 review) and `ARCH-`, `DATA-`, `PERF-`, `CONTRACT-`, `REL-`, `TEST-` (September remediation plan). Standards rules use the `FS-` prefix so that none of these collide. Existing IDs are cited as written.

## Exceptions

1. An exception is requested in the PR description: rule ID, reason, scope, expiry condition.
2. MUST-level exceptions need owner approval recorded in the PR. SHOULD-level exceptions need reviewer agreement.
3. Exceptions to rules marked **release-blocking** in [SECURITY-AND-DATA-CONTRACT.md §6](SECURITY-AND-DATA-CONTRACT.md#6-release-blocking-criteria) can only be granted by the owner and must name the release they apply to.
4. A granted exception is listed in the release notes of the first release that contains it.

## Changing the standards

A change to a rule is a normal PR that touches only `docs/standards/`, states which rule IDs change, and is approved by the owner. Rule IDs are never reused; a withdrawn rule keeps its ID with the text "Withdrawn" and a reason.

## What these documents are based on

- Read-only inspection of the four refs above, plus `codex/ios-integrated-candidate` and PR #3.
- Existing audits: [`docs/review/2026-11-11-architecture-debt-risk.md`](../review/2026-11-11-architecture-debt-risk.md); `docs/review/01-codebase-baseline-review.md` (PR #3 and `feat/paper-writing`); `docs/hardening/*` (`feat/paper-writing`); [`docs/three-platform-refactoring-and-gap-remediation.md`](../three-platform-refactoring-and-gap-remediation.md); [`docs/contracts/`](../contracts/README.md).
- Executed for this work: contract and HarmonyOS host tests on `main`; `tools/i18n/generate.py --check` on `feat/paper-writing`; `git merge-tree` simulations; GitHub Actions run and job listings.
- **Not available:** Xcode, the Android SDK and Gradle network, DevEco Studio and hvigor, any emulator, simulator or device, any signing identity. No native build or test was run. The owner's workspace-level `AGENTS.md`, which the hardening documents refer to, is outside this repository and was not read.
