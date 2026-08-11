# Pantheon-IaC

Infrastructure-as-Code for the Pantheon homelab (Proxmox VE).

## Project context

The project notes — plans, decisions, host runbook, and current state — live in an external Obsidian vault, **not** in this repo. Read them before doing any work.

1. Read `PANTHEON_NOTES_PATH` from `.env` — the absolute path to the Pantheon project folder in the vault. The path contains spaces; always quote it in shell (`ls "$PANTHEON_NOTES_PATH"`).
2. **Load the latest implementation plan.** Look in `"$PANTHEON_NOTES_PATH/implementation_plans/"` and open the highest-versioned `vX.Y_implementation_plan.md` (e.g. `v0.2` over `v0.1`). That file is the plan to execute.
3. **Read its Progress ledger first** (the table near the end, mirrored in the frontmatter `current_phase` + `phaseN:` fields). It is the source of truth for how far the work has progressed and which phase to resume.
4. Then read, in order:
   - `"$PANTHEON_NOTES_PATH/overview.md"` — what Pantheon is, current state, key decisions.
   - `"$PANTHEON_NOTES_PATH/host-runbook.md"` — how the host was already built.
5. Follow the plan and the decisions recorded in the vault. When something is unclear or missing, ask.

After a phase's green gate passes, update that plan's Progress ledger (table row + `phaseN:`/`current_phase` frontmatter) so the next session resumes accurately.
