---
title: GitHub Project структура — Whilly vNext (Forge)
type: project-spec
created: 2026-04-20
status: draft
related:
  - PLAN-OPENCODE-DOCKER.md
  - ROADMAP.md
  - ../../../Whilly_Requirements_v1.md
---

# GitHub Project: Whilly vNext (Forge)

> Структура GitHub Project (V2) для трекинга работ по `Whilly_Requirements_v1.md`.
> Создаётся через `scripts/create_vnext_project.sh` после `gh auth refresh -s project`.

---

## Project metadata

- **Owner:** `mshegolev` (user-owned project, viewable публично)
- **Title:** `Whilly vNext (Forge)`
- **Description:** GitHub Issue → Verified Change → Repair Loop → PR. Tracking the FR-1..FR-11 work.
- **Visibility:** public
- **Repository link:** `mshegolev/whilly-orchestrator`

---

## Custom fields

| Field | Type | Options |
|---|---|---|
| `Status` | single select | `Backlog`, `Ready`, `In Progress`, `In Review`, `Done`, `Blocked` |
| `Priority` | single select | `P0`, `P1`, `P2` |
| `Phase` | single select | `Phase 1 — Intake+Readiness`, `Phase 2 — Verifier+Repair`, `Phase 3 — PR Factory`, `Phase 4 — Demo+Polish`, `Existing` |
| `FR` | text | e.g. `FR-1`, `FR-3+FR-10` |
| `Estimate (h)` | number | hours |

---

## Items (24 items: 11 FR + 6 NFR + 7 housekeeping)

### Phase 1 — Intake + Readiness (P0, ≈ 8h)

| # | Title | Body | FR | Priority | Status | Estimate | Notes |
|---|---|---|---|---|---|---|---|
| 1 | **CLI flag `--from-issue owner/repo#N`** | Add CLI parsing in `whilly/cli.py` to accept `--from-issue` and route to intake. Wire in `__main__`. | FR-1 | P0 | Backlog | 1h | Depends on PR #10 merge (cli.py touch) |
| 2 | **Module `whilly/intake_github.py` (alias of sources)** | Re-export `fetch_github_issues` as `intake_github.fetch_issue(owner_repo_n)`. Spec wording from v1.md. | FR-1 | P0 | In Review | 0.5h | Wraps existing `whilly/sources/github_issues.py` |
| 3 | **Task type classifier (bugfix/feature/refactor/unknown)** | Extend `issue_to_task` to set `task_type` based on labels (`bug` → bugfix, `enhancement`/`feature` → feature, `refactor` → refactor, else `unknown`). | FR-2 | P0 | Backlog | 1h | New field on `Task` dataclass |
| 4 | **Normalized issue spec — missing fields explicit** | Mark fields as `null`/empty if absent (don't invent). Add `confidence: float` slot. | FR-2 | P0 | Backlog | 1h | Schema doc update |
| 5 | **Module `whilly/readiness.py` (alias decision_gate + states)** | Add three states `ready`/`ready_with_assumptions`/`blocked`, return `missing_information: list[str]` and `assumptions: list[str]`. | FR-3 | P0 | Backlog | 2h | Builds on `whilly/decision_gate.py` |
| 6 | **Persist normalized spec + readiness report as artifacts** | Write `runs/<run_id>/issue_spec.json` and `runs/<run_id>/readiness.json`. | FR-2, FR-3, NFR-3 | P0 | Backlog | 1.5h | Reuse `reporter.py` |

### Phase 2 — Verifier + Repair (P0, ≈ 10h)

| # | Title | Body | FR | Priority | Status | Estimate | Notes |
|---|---|---|---|---|---|---|---|
| 7 | **Module `whilly/strategy.py` (4 strategies)** | `bugfix_repro_first`, `feature_plan_first`, `refactor_guarded`, `unknown_safe_mode`. Default mapping from task_type. | FR-4 | P0 | Backlog | 1.5h | New module |
| 8 | **Module `whilly/planner.py` (per-task scoped plan)** | Generate structured plan: problem summary, target modules, files to modify, validation plan, risks, stop conditions. | FR-5 | P0 | Backlog | 2h | Smaller than `prd_wizard.py`, per-task scope |
| 9 | **Repo profile loader (YAML)** | Parse `repo_profiles/<repo>.yaml`: `setup`, `verify`, `repair_verify`, `allowed_paths`, `forbidden_paths`. | FR-7, NFR-6 | P0 | Backlog | 1.5h | New file format |
| 10 | **Extend `whilly/verifier.py` for structured verdict** | Run `verify` commands from profile, capture exit codes + outputs, return `pass`/`repair`/`escalate` with failure taxonomy. | FR-7 | P0 | Backlog | 2h | Extends existing 152 LOC |
| 11 | **Module `whilly/repair.py`** | Parse failure bundle, generate repair prompt, run scoped fix, stop conditions (max 2-3, same-failure-twice, diff size, confidence). | FR-8 | P0 | Backlog | 2h | Extracts logic from `scripts/whilly_e2e_demo.py` (PR #11) |
| 12 | **Wire repair loop into main flow** | After failed verify → run repair → re-verify → escalate or pass. | FR-8 | P0 | Backlog | 1h | `cli.py` integration |

### Phase 3 — PR Factory (P0, ≈ 4h)

| # | Title | Body | FR | Priority | Status | Estimate | Notes |
|---|---|---|---|---|---|---|---|
| 13 | **Issue-linked branch naming** | `whilly/issue-{N}-{slug}`. Slug from issue title. | FR-9 | P0 | In Review | 0.5h | Extend `whilly/sinks/github_pr.py::_branch_name` |
| 14 | **PR body composition (what/why/validation/risks)** | Render PR body with all 4 sections from v1.md FR-9. | FR-9 | P0 | In Review | 1h | Extend `render_pr_body` |
| 15 | **Draft PR auto-decision logic** | Choose draft when readiness low confidence OR repair exhausted with partial value. | FR-10 | P0 | Backlog | 1h | New |
| 16 | **PR metadata persistence** | Write `runs/<run_id>/pr.json` with branch, title, url, draft. | FR-9, NFR-3 | P0 | Backlog | 0.5h | Reuse reporter |
| 17 | **`whilly/github_pr.py` re-export shim** | Aliasing for v1.md naming. | FR-9 | P0 | Backlog | 0.5h | Re-export from `sinks/github_pr.py` |

### Phase 4 — Demo + Polish (P1, ≈ 4h)

| # | Title | Body | FR | Priority | Status | Estimate | Notes |
|---|---|---|---|---|---|---|---|
| 18 | **Timeline events from v1.md FR-11 spec** | Add events `issue_ingested`, `task_normalized`, `readiness_checked`, `strategy_selected`, `plan_generated`, `verification_failed`, `repair_started`, `repair_finished`, `verification_passed`, `pr_created`, `blocked`/`escalated`. | FR-11 | P1 | Backlog | 1.5h | Extend `cli.py::_log_event` |
| 19 | **Dashboard timeline view** | Add hotkey to show event timeline for current run. | FR-11, NFR-3 | P1 | Backlog | 2h | `dashboard.py` extension |
| 20 | **Demo repo profile + seeded issues** | Pick demo repo, write `repo_profiles/<repo>.yaml`, seed 3-5 deterministic issues. | NFR-2 | P1 | Backlog | 2h | Could be `mshegolev/whilly-orchestrator` itself |
| 21 | **Demo script (3-min screencast plan)** | `docs/workshop/DEMO-SCRIPT.md` with cues. | NFR-2 | P1 | Backlog | 1h | Polished narrative |

### Cross-cutting & polish (P1-P2)

| # | Title | Body | FR | Priority | Status | Estimate | Notes |
|---|---|---|---|---|---|---|---|
| 22 | **ADR-017: draft PR vs auto-merge clarification** | Document that draft PR ≠ auto-merge violation; merge always human. | FR-10, BRD §10 D9 | P1 | Backlog | 0.5h | New ADR |
| 23 | **README + README-RU: vNext / Forge section** | Bilingual section explaining Issue→PR positioning. | docs | P2 | Backlog | 1h | Branding |
| 24 | **NFR-5 cost panel in dashboard** | Per-run cost breakdown, total budget consumption. | NFR-5 | P2 | Backlog | 1.5h | Already partial |

---

## Total estimate

| Phase | Items | Hours |
|---|---|---|
| Phase 1 — Intake + Readiness | 6 | ~8h |
| Phase 2 — Verifier + Repair | 6 | ~10h |
| Phase 3 — PR Factory | 5 | ~4h |
| Phase 4 — Demo + Polish | 4 | ~4h |
| Cross-cutting | 3 | ~3h |
| **Total** | **24** | **~29h** |

---

## Dependency map (high level)

```
PR #8 (workshop kit + gap pack)  ──┐
                                    ▼
PR #10 (OpenCode backend)         Phase 1 (#1-#6)
                                    ▼
                                  Phase 2 (#7-#12) ──┐
                                                     ▼
                                                  Phase 3 (#13-#17)
                                                     ▼
                                                  Phase 4 (#18-#21)
                                                     ▼
                                                  Cross-cutting (#22-#24)
```

---

## Reuse map (existing → vNext)

| Existing module | vNext usage |
|---|---|
| `whilly/sources/github_issues.py` (PR #8) | basis for `intake_github.py` (item #2) |
| `whilly/decision_gate.py` (PR #8) | basis for `readiness.py` (item #5) |
| `whilly/sinks/github_pr.py` (PR #8) | basis for branch+body+draft work (items #13, #14, #15, #17) |
| `whilly/verifier.py` (existing 152 LOC) | extend with profiles + structured verdict (item #10) |
| `scripts/whilly_e2e_demo.py` (PR #11) | extract repair logic into `repair.py` (item #11) |
| `whilly/agents/` (PR #10) | reused as backend for plan/repair agents |
| `whilly_logs/whilly_events.jsonl` | extend with v1.md event types (item #18) |

---

## Demo path (Phase 4)

Per v1.md §13 — bugfix with intentional first failure:

1. Whilly ingests issue (FR-1)
2. Readiness says ready (FR-3)
3. Strategy = bugfix_repro_first (FR-4)
4. Plan generated (FR-5)
5. First implementation attempt fails one test (FR-6 + FR-7)
6. Repair loop fixes null/empty-state logic (FR-8)
7. Verification passes (FR-7)
8. PR created (FR-9)
9. Timeline shows the entire sequence (FR-11)

---

**Status:** project spec ready · 2026-04-20 · awaits `gh auth refresh -s project` then `scripts/create_vnext_project.sh` execution.
