# Working agreements

| | |
| --- | --- |
| **Status** | Charter v1.0 — **accepted** by PO, 2026-09-29 |
| **Roles from sprint 1 on** | **Tech lead and repo owner:** the stakeholder. Reviews, commits, pushes, merges. **Developer:** Claude. Writes and explains code in a chat session that sees only the Project files. **PO:** the stakeholder, for scope and priority. |

## 1. Per-story Definition of Done

A story is done when all of the following hold. Spikes and chores use the items marked with *.

- [ ] Every acceptance criterion in the issue is checked off.*
- [ ] `scripts/check` passes: `zsh -n` on every script and the full fixture test suite (CR-7).*
- [ ] New parsers of system-command output have fixture tests (ADR-0004).
- [ ] The live sequence on the Mac passed (ADR-0004):
  1. `bin/provision --check` changes nothing and reports the expected `DIFF` lines;
  2. `bin/provision` converges;
  3. a second `bin/provision` makes no changes other than upstream releases (M3).
- [ ] Every new output line goes through `log` and follows §8.5 as amended by CR-18 (FR-15.4), or falls under the Homebrew exception (CR-10).
- [ ] No secrets or personal identifiers in code, fixtures or commit messages (NFR-3).*
- [ ] Docs updated where behavior or a decision changed: README, `docs/architecture.md`, or an ADR (a new ADR if a decision was reversed).*
- [ ] Merged to `main` through a pull request that closes the issue; `main` is runnable afterwards.*

## 2. Branching

- **`main` is always runnable.** Nothing is committed to it directly.
- One short-lived branch per issue, named `<issue-number>-<short-slug>`, e.g. `7-logging-library`.
- Merge with **squash**, so each issue lands on `main` as one commit, and delete the branch afterwards.

## 3. Commit messages

[Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <summary in the imperative, under 72 characters>

<optional body: why, not what>

Refs #7
```

- **Types:** `feat` (new behavior), `fix`, `docs`, `test`, `refactor`, `chore`, `spike`.
- **Scope:** the module or library, e.g. `log`, `converge`, `preflight`, `bootstrap`.
- **Example:** `feat(log): add compact settings line with dot-padding`

## 4. Working an issue, start to close (by hand)

No automation: every step below is done in the GitHub web page or with plain `git` (DEC-32). The walkthrough for *creating* issues is in `docs/backlog/sprint-01.md`.

**The lifecycle of one issue**

| # | Where | What you do | What GitHub shows |
| --- | --- | --- | --- |
| 1 | Issue page | **Pick it.** Assign it to yourself (side panel → **Assignees**). One issue in progress at a time. | Your avatar on the issue, in the milestone list |
| 2 | Terminal | **Branch.** `git switch -c 7-logging-library` from an up-to-date `main`. | Nothing yet |
| 3 | Terminal | **Commit.** Each commit message ends with `Refs #7` (§3). | After pushing: each commit appears on issue #7's timeline |
| 4 | Terminal | **Push.** `git push -u origin 7-logging-library` | A yellow "Compare & pull request" banner on the repo page |
| 5 | Repo page | **Open a pull request.** Click the banner. Title: the issue's title. Description: what changed, how you tested it, and a final line `Closes #7`. | The PR appears in the issue's side panel under **Development** |
| 6 | PR page | **Review.** Read the diff in the **Files changed** tab against §5's checklist. Tick the issue's acceptance-criteria checkboxes as you confirm each one. | Checkbox progress on the issue (for example "4 of 6") |
| 7 | PR page | **Merge.** Choose **Squash and merge**, then **Delete branch**. | The PR shows as merged; **issue #7 closes automatically**; the milestone's progress bar moves |
| 8 | Terminal | **Tidy up.** `git switch main && git pull && git branch -d 7-logging-library` | — |

**Linking vs. closing**

- **Linking.** Writing `#7` anywhere in a commit message or pull request shows that commit or PR on issue #7's timeline. `Refs #7` is the deliberate form.
- **Closing.** A **closing keyword** (`Closes`, `Fixes` or `Resolves`, followed by `#7`) in a **pull request description** closes issue #7 when the pull request merges into `main`. The same keyword in a commit message pushed to `main` also closes it.
- **Rule:** commits say `Refs #n`; the pull request says `Closes #n`. The issue then closes exactly when its work lands, and never earlier.

**Other situations**

- **Spike finished.** Same flow; the pull request contains only the findings file and any fixtures.
- **Work turned out bigger than the issue.** Don't grow the issue. Finish what it asks, then open a new issue for the rest and mention the original (`Follow-up to #7`).
- **Found a bug while working on something else.** Open a new issue right away, label it, and leave it in the backlog. Don't fix it on the current branch.
- **Issue no longer needed.** Close it with **Close as not planned**, plus a one-line comment explaining why.
- **Discussion.** Use the issue's comment box for decisions made mid-story, so the reasoning stays attached to the work.

## 5. Code review in the development phase

1. The tech lead opens a development chat and names one issue.
2. The developer (Claude) states a short plan, then writes the code with explanations, following the Project's `docs/` as the source of truth. The developer flags any conflict with an ADR instead of silently deviating.
3. The tech lead creates the branch, applies the code, runs `scripts/check` and the live sequence (§1), and commits.
4. The tech lead opens a pull request (§4) and reviews its diff on GitHub against this checklist:
   - Does it do only what the issue asks? No scope creep.
   - Does every system change sit inside an apply function (architecture §5)?
   - Do scripts use `#!/bin/zsh -f`, and do functions start with `emulate -L zsh` (ADR-0002)?
   - Do settings lines stay unevaluated, never passed to `eval` (ADR-0006)?
   - Is every output line produced through `log` (ADR-0009)?
   - Do comments explain *why*, not *what*?
5. Findings go back to the developer chat. The tech lead merges when the checklist and the DoD pass.
6. **After merging,** the tech lead uploads changed `docs/` files to the Project, so the next development chat sees current decisions.

## 6. How changes flow

| Change | Owner | How |
| --- | --- | --- |
| **What** we build (a PRD requirement) | PO | Add a CR to the change-request file with section, proposed text and reason. The PO approves or rejects it. Approved CRs are merged into the PRD in one commit that bumps its version and adds a changelog row. |
| **How** we build it (a technical decision) | Tech lead | Write a new ADR. A reversed decision gets a new ADR that supersedes the old one; the old ADR's status becomes "Superseded by ADR-NNNN". ADRs are never rewritten after acceptance. |
| **Order** of work | PO | Edit `docs/release-plan.md` and move issues between milestones. |
| **A story's details** | Tech lead | Edit the issue on GitHub. Acceptance criteria must still trace to FR IDs. |

If a development chat discovers that a requirement is wrong or impossible, it stops and raises a CR. It does not work around the requirement.

## 7. Sprint rhythm

- A sprint starts when the PO confirms its milestone's issues are ready.
- A sprint ends when its milestone is at 100% and the PO has run the result on the Mac.
- The next sprint's issues are written only then. They are refined from the candidate stories in the release plan, written as a new `docs/backlog/sprint-NN.md`, and created by hand, as in sprint 1.

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 0.1 | 2026-09-28 | First draft. |
| 1.0 | 2026-09-28 | No content changes; version aligned with the charter. |
| 0.2 | 2026-09-28 | §4 rewritten as a manual issue lifecycle (DEC-32); `gh` automation removed. |
