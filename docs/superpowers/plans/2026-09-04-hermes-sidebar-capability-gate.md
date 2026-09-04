# Hermes Sidebar Navigation Capability Gate

> **For agentic workers:** Use `executing-plans` serially in the current session;
> no subagents. This is the prerequisite capability gate, not authorization for
> a Hermes core implementation or an installed-app replacement.

**Goal:** Determine whether the approved sidebar navigation can be implemented
through the installed Hermes public desktop-plugin interface.

**Architecture:** Keep all navigation metadata inside Hermes. Companion sends
fixed process-targeted keys; firmware sends directions and displays fixed labels.
Reject a plugin implementation that needs private imports, DOM scraping or a
second session list independent of the real sidebar.

**Tech Stack:** macOS bundle metadata, read-only Electron ASAR inspection,
Hermes desktop TypeScript source and plugin SDK.

## Constraints

- Spec: `../specs/2026-09-04-hermes-sidebar-navigation-design.md`.
- No app/configuration changes, plugin installation, re-signing, launch of a
  second Hermes instance, firmware upload, GitHub push or merge in this gate.
- Read application code and version metadata, not user configuration, session
  databases, transcripts, credentials or UI contents.
- Installed artifacts and nearby source checkouts are separate evidence layers.
- Source inspection and package inspection are not executed navigation tests.

## Task 1: Resolve installed version

- [x] Query `com.nousresearch.hermes` through NSWorkspace without activating it.
- [x] Read only bundle version metadata: version/build `0.17.0`.
- [x] Independently read the packaged ASAR `package.json` version: `0.17.0`.

The sandbox could not resolve the bundle; the approved read-only host query
succeeded. No app was installed, activated or restarted for this check.
Machine-specific locations are omitted from this tracked record.

## Task 2: Check public plugin capability

- [x] Inspect only packaged application JavaScript as text; do not execute it.
- [x] Locate the SDK host state object in the installed renderer bundle.
- [x] Compare with the nearby desktop source checkout at
  `df4b3733baa5534bec1e6e888e5ba86a0a6f9c3b`.
- [x] Check built-in action metadata and the session next/previous handler.

The installed SDK object exposes active/focused session and owner, connection,
profile, usage, cwd, gateway and viewport state. It does not expose an ordered
sidebar project model. The nearby source has the same relevant public shape.
This does not assert full byte-for-byte correspondence between the checkout
and the installed bundle, nor that every loaded plugin was inventoried.

The following source locations establish the implementation boundary:

| Source file in Hermes | Observed responsibility |
| --- | --- |
| `apps/desktop/src/lib/keybinds/actions.ts` | Built-in session next/previous and contributed keybind registry |
| `apps/desktop/src/app/hooks/use-keybinds.ts` | Focused-zone Tab cycling with fallback session switcher |
| `apps/desktop/src/sdk/index.ts` | Public host state and session opening; no ordered project sidebar interface found |
| `apps/desktop/src/app/chat/sidebar/index.tsx` | Builds filtered/manual-order project view; hydrates entered-project lanes |
| `apps/desktop/src/app/chat/sidebar/projects/model.ts` | Project sorting, manual-order overlay and limited preview counts |
| `apps/desktop/src/store/projects.ts` | Internal `enterProject`, `goToProject`, `fetchProjectSessions` |

The sidebar overview has limited previews, and entered projects hydrate their
lanes lazily. A plugin that walks currently loaded recent sessions would not
meet the required complete project/session navigation. An active-project sort
can also alter order after navigation, reinforcing the approved snapshot rule.

**Gate result: NOT SATISFIED for a public-plugin-only implementation.**
Do not implement a workaround using private imports, generic session RPCs,
browser DOM access, database inspection or repeated Control-Tab events.
No synthetic integration result is claimed: the required public interface was
not established, so such a test would invent the missing integration boundary.

## Task 3: Proposed next scope, requiring approval

- [ ] Authorize an isolated Hermes source worktree and synthetic-data tests only.
- [ ] Read that checkout's repository instructions before editing it.
- [ ] Prepare the complete TDD implementation plan against its pinned baseline.
- [ ] Implement and review the three core navigation commands in isolation.
- [ ] Separately approve installation after keyboard and test-environment proof.

Recommended minimum extension: add native previous-sidebar-session,
next-sidebar-session and next-project commands that reuse the sidebar's own
model and existing navigation lifecycle. Keep next-target calculation in a
small pure module and asynchronous navigation in a separate controller; test
with synthetic project/session IDs only. Do not add a general-purpose SDK
bridge or plugin if native commands suffice.

Likely source touchpoints for that separate plan are the existing sidebar
model, `use-keybinds.ts`, keybind metadata/localized labels, and their tests.
The plan must resolve lazy loading, canonical order, reveal/scroll behavior,
draft safety and cancellation before implementation; this gate report is not
a substitute for that code-level plan.

Only after Hermes keyboard navigation is proven should AgentBezel update
`WorkspaceAppProfile.swift`, `SuperEngineeringKeyEmitter.swift`, corresponding
tests, and the HERMES right-hand renderer label from NEW to PROJECT. Current
SUPER/Codex mappings, installed Companion and pending center-UI artifacts stay
unchanged until their own implementation/installation steps.

This next scope is materially different from granting internal navigation
metadata access. It must not be inferred from that earlier permission.

## Outcome

Completed: version verification, packaged SDK inspection and source boundary
analysis. Waiting: explicit permission to modify isolated Hermes source.
No implementation, synthetic integration, package build, device flash or
physical navigation acceptance was performed in this gate.
