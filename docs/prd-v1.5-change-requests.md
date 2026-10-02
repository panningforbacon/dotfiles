# PRD v1.5 change requests

| | |
| --- | --- |
| **Applies to** | `docs/prd.md` v1.4 |
| **Status** | Open. Approved CRs wait here until the PO merges them into the PRD as v1.5 (`docs/working-agreements.md` §6). |

---

## CR-19 — Phrasing rules for checks that are not managed items

- **Section:** §8.5, Rules
- **Proposed text (new rule):** "**Checks that are not managed items.** The phrasing rules in the status vocabulary describe managed items. A check with nothing to apply, such as a preflight check, states the fact it found: `OK` as `<value> — <verdict>`, for example `macOS: 27.0 — verified tier`. `FAIL` keeps its rule."
- **Reason:** The `OK` rule, `already <state> — skipping`, assumes an item that could have been changed. Preflight checks (FR-2.1, FR-2.2) change nothing, so the rule produces lines such as `macOS: already 27 — skipping`. Found while building the preflight story in sprint 1.
- **Status:** Approved by PO, 2026-10-02 · Not yet merged

---

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-10-02 | CR-19 drafted and approved. |
