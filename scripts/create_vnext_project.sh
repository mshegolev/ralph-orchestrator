#!/usr/bin/env bash
# Create the "Whilly vNext (Forge)" GitHub Project (V2) and seed all 24 items
# from docs/workshop/PROJECT-VNEXT-STRUCTURE.md.
#
# Prereqs (one-time):
#   gh auth refresh -s project    # adds 'project' scope to your gh token
#
# Usage:
#   scripts/create_vnext_project.sh                # creates project, exits with project number
#   scripts/create_vnext_project.sh --dry-run      # prints commands, doesn't mutate
#
# Idempotency: if a project with the same title already exists for the owner,
# the script reuses it instead of creating a duplicate.

set -euo pipefail

OWNER="${OWNER:-mshegolev}"
TITLE="${TITLE:-Whilly vNext (Forge)}"
DRY_RUN=""

if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ]; then
    DRY_RUN="echo [dry-run] "
fi

# Strip env tokens — gh prefers keyring auth.
unset GITHUB_TOKEN GH_TOKEN || true

# ── 0. Auth check ──────────────────────────────────────────────────────────
if ! gh auth status >/dev/null 2>&1; then
    echo "✗ gh not authenticated. Run: gh auth login"
    exit 1
fi
if ! gh project list --owner "$OWNER" >/dev/null 2>&1; then
    echo "✗ gh token missing 'project' scope."
    echo "   Run: gh auth refresh -s project"
    exit 1
fi

# ── 1. Find or create project ──────────────────────────────────────────────
echo "Looking up project '$TITLE' for owner '$OWNER'..."
EXISTING_NUM=$(gh project list --owner "$OWNER" --format json --limit 100 \
    | jq -r --arg t "$TITLE" '.projects[] | select(.title==$t) | .number' | head -1)

if [ -n "$EXISTING_NUM" ]; then
    PROJECT_NUM="$EXISTING_NUM"
    echo "  ✓ Project exists, reusing #$PROJECT_NUM"
else
    if [ -n "$DRY_RUN" ]; then
        ${DRY_RUN}gh project create --owner "$OWNER" --title "$TITLE"
        PROJECT_NUM="<NEW>"
    else
        PROJECT_NUM=$(gh project create --owner "$OWNER" --title "$TITLE" --format json \
            | jq -r '.number')
        echo "  ✓ Created project #$PROJECT_NUM"
    fi
fi

# ── 2. Custom fields ──────────────────────────────────────────────────────
# 'Status' is a built-in field on every V2 project (Todo/In Progress/Done by default).
# We add Priority, Phase, FR, Estimate.
echo "Ensuring custom fields..."

ensure_field() {
    local name="$1" type="$2" options="$3"
    local existing
    existing=$(gh project field-list "$PROJECT_NUM" --owner "$OWNER" --format json 2>/dev/null \
        | jq -r --arg n "$name" '.fields[] | select(.name==$n) | .id' | head -1)
    if [ -n "$existing" ]; then
        echo "  · field '$name' exists, skipping"
        return
    fi
    if [ "$type" = "single_select" ]; then
        ${DRY_RUN}gh project field-create "$PROJECT_NUM" --owner "$OWNER" \
            --name "$name" --data-type SINGLE_SELECT --single-select-options "$options"
    else
        ${DRY_RUN}gh project field-create "$PROJECT_NUM" --owner "$OWNER" \
            --name "$name" --data-type "$type"
    fi
}

ensure_field "Priority" single_select "P0,P1,P2"
ensure_field "Phase" single_select "Phase 1 — Intake+Readiness,Phase 2 — Verifier+Repair,Phase 3 — PR Factory,Phase 4 — Demo+Polish,Cross-cutting"
ensure_field "FR" TEXT ""
ensure_field "Estimate (h)" NUMBER ""

# ── 3. Seed items ─────────────────────────────────────────────────────────
echo "Seeding items..."

create_item() {
    local title="$1" body="$2"
    ${DRY_RUN}gh project item-create "$PROJECT_NUM" --owner "$OWNER" \
        --title "$title" --body "$body" >/dev/null
    echo "  · $title"
}

# Phase 1 — Intake + Readiness
create_item "[FR-1] CLI flag --from-issue owner/repo#N" \
    "Wire \`--from-issue\` parsing in whilly/cli.py + __main__. Routes to intake_github. P0, ~1h."
create_item "[FR-1] Module whilly/intake_github.py (alias of sources)" \
    "Re-export fetch_github_issues as intake_github.fetch_issue(owner_repo_n). P0, ~0.5h."
create_item "[FR-2] Task type classifier (bugfix/feature/refactor/unknown)" \
    "Extend issue_to_task to set task_type from labels. P0, ~1h."
create_item "[FR-2] Normalized issue spec — missing fields explicit" \
    "Mark fields null/empty when absent. Add confidence float slot. P0, ~1h."
create_item "[FR-3] Module whilly/readiness.py (alias decision_gate + states)" \
    "Three states: ready / ready_with_assumptions / blocked + missing_information + assumptions lists. P0, ~2h."
create_item "[FR-2/3/NFR-3] Persist normalized spec + readiness as run artifacts" \
    "Write runs/<run_id>/issue_spec.json and readiness.json. P0, ~1.5h."

# Phase 2 — Verifier + Repair
create_item "[FR-4] Module whilly/strategy.py (4 strategies)" \
    "bugfix_repro_first / feature_plan_first / refactor_guarded / unknown_safe_mode. P0, ~1.5h."
create_item "[FR-5] Module whilly/planner.py (per-task scoped plan)" \
    "Structured plan: problem summary, target modules, files, validation, risks, stop conditions. P0, ~2h."
create_item "[FR-7/NFR-6] Repo profile loader (YAML)" \
    "Parse repo_profiles/<repo>.yaml: setup, verify, repair_verify, allowed_paths, forbidden_paths. P0, ~1.5h."
create_item "[FR-7] Extend whilly/verifier.py for structured verdict" \
    "Run verify cmds from profile, return pass/repair/escalate + failure taxonomy. P0, ~2h."
create_item "[FR-8] Module whilly/repair.py" \
    "Failure parsing, scoped repair prompt, stop conditions. Extract from scripts/whilly_e2e_demo.py. P0, ~2h."
create_item "[FR-8] Wire repair loop into main flow (cli.py)" \
    "After verify fail → repair → re-verify → escalate or pass. P0, ~1h."

# Phase 3 — PR Factory
create_item "[FR-9] Issue-linked branch naming whilly/issue-{N}-{slug}" \
    "Extend whilly/sinks/github_pr.py::_branch_name. P0, ~0.5h."
create_item "[FR-9] PR body composition (what/why/validation/risks)" \
    "Render with all 4 sections per v1.md FR-9. Extend render_pr_body. P0, ~1h."
create_item "[FR-10] Draft PR auto-decision logic" \
    "Choose draft on low confidence OR repair-exhausted. P0, ~1h."
create_item "[FR-9/NFR-3] PR metadata persistence" \
    "Write runs/<run_id>/pr.json. P0, ~0.5h."
create_item "[FR-9] whilly/github_pr.py re-export shim" \
    "Aliasing for v1.md naming. P0, ~0.5h."

# Phase 4 — Demo + Polish
create_item "[FR-11] Timeline events from v1.md spec" \
    "Add issue_ingested, task_normalized, readiness_checked, strategy_selected, plan_generated, verification_failed, repair_started, repair_finished, verification_passed, pr_created, blocked/escalated. P1, ~1.5h."
create_item "[FR-11/NFR-3] Dashboard timeline view" \
    "Hotkey to show event timeline for current run. P1, ~2h."
create_item "[NFR-2] Demo repo profile + seeded issues" \
    "Pick demo repo, write repo_profiles/<repo>.yaml, seed 3-5 deterministic issues. P1, ~2h."
create_item "[NFR-2] Demo script (3-min screencast plan)" \
    "docs/workshop/DEMO-SCRIPT.md with cues. P1, ~1h."

# Cross-cutting
create_item "[ADR-017] Draft PR vs auto-merge clarification" \
    "Document that draft PR ≠ auto-merge violation; merge always human. P1, ~0.5h."
create_item "[docs] README + README-RU vNext / Forge section" \
    "Bilingual section explaining Issue→PR positioning. P2, ~1h."
create_item "[NFR-5] Cost panel in dashboard" \
    "Per-run cost breakdown, total budget consumption. P2, ~1.5h."

echo ""
echo "✓ Project ready."
echo "  https://github.com/users/$OWNER/projects/$PROJECT_NUM"
