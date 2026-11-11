# CLAUDE.md (draft — not active)

Claude Code adapter for Project Flash. The project rules are in `AGENTS.md` and `docs/standards/`; read `AGENTS.md` first and follow it in full. This file adds only what is specific to Claude Code.

@AGENTS.md

## Claude Code specifics

- **Cloud sessions are ephemeral.** The platform assigns a branch and the container is discarded when the session ends. Pushing is still an approval-gated action (FS-AGENT-20): if the task brief does not say whether to push to the assigned branch, ask once, explaining that unpushed commits will be lost.
- **Sub-agents count.** No more than two models from the same provider may be active on the project at once (FS-AGENT-05). Do not spawn sub-agents unless the owner asked for them, and count each one.
- **Plan first for anything that crosses platforms or touches the contract, storage, permissions or CI.** Present the plan and the list of files before editing.
- **No native toolchains in hosted sessions.** A hosted session usually has Node and Python only. Say so in the handoff; do not infer a native build or test result from a host test.
- **Reviews.** When acting as reviewer, work from commit hashes, write findings with stable IDs to a review document on your own branch, and do not edit the implementation under review (FS-AGENT-13).
- **Other branches.** Inspect them with read-only Git commands or a detached worktree outside the repository directory. Remove the worktree when done.
- **Pull requests.** Never open or update one unless asked.
