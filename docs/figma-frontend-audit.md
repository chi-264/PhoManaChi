# Figma frontend documentation audit

Reviewed on November 5, 2026. Scope: the local `FigmaFrontEnd` export, principally
`src/App.tsx`, `src/index.css`, and its package manifest. This is a source-level
review; the web preview was not run and no screenshots, device measurements,
TalkBack results, or Android behavior were verified. No application code was changed.

## Verdict

**Partially aligned. Suitable as a visual reference for the Flutter redesign;
not sufficient as the complete design or implementation of the documented app.**

All major top-level destinations exist. The cards, accent colors, shared notices,
light/dark themes, and explicit browser limitations support the intended product.
However, many required feature workflows are represented only by empty states.
There are also specific interaction and accessibility problems that should be
corrected rather than copied into Flutter.

The export deliberately describes itself as a browser preview. Missing Android
APIs are therefore expected, not evidence that the intended native feature is
technically impossible. Distinguish two kinds of remaining work:

- **Design gaps:** missing screen structures, state variants, confirmations,
  navigation behavior, and readable mobile layouts.
- **Implementation/validation gaps:** Android API access, native enforcement,
  verified operations, lifecycle handling, and physical-device tests.

No percentage compliance score is assigned: a destination existing does not mean
its requirements or acceptance criteria have been satisfied.

## Documentation baseline

- `Documentations/PRDs/Product Requirements Document v.1.1.docx` (PRD).
- `Documentations/SATFs/System Architecture and Technical Feasibility Specification v.1.1.docx` (Architecture).
- `Documentations/UIUX Specifications and Screen Design Guidelines v.1.0.docx` (UI/UX).
- `Documentations/User Journeys and Interaction Flows v.1.0.docx` (Journeys).
- `Documentations/User Personas v.1.0.docx` (Personas).

PRD v1.0 and Architecture v1.0 are historical; their Kotlin/Compose-only approach
was superseded by v1.1. Shizuku is a post-MVP enhancement, not a prerequisite for
accepting the standard MVP.

## Findings to address before copying the design

### High: compact-phone layout and typography diverge from the specifications

Evidence: [CSS metric grid](../FigmaFrontEnd/src/index.css#L83),
[mobile overrides](../FigmaFrontEnd/src/index.css#L295),
[mobile metric captions](../FigmaFrontEnd/src/index.css#L327), and
[mobile navigation](../FigmaFrontEnd/src/index.css#L349).

The metric grid remains three columns on compact phones; quick actions remain
in two columns. Mobile captions/statuses use 7 px text, with other labels at
8–11 px. UI/UX §15.1 explicitly calls for single-column layouts on smaller screens;
§§3.3 and 16 require readable Material typography and text scaling. This also
works against the everyday and older-device personas.

Source color calculations show metric captions `#99a2b0` on white at approximately
2.58:1 contrast and light badges `#8e98a9` on `#f7f8fa` at approximately 2.74:1.
Some sidebar text retains hardcoded light-theme colors in dark mode: `#687486`
on the dark surface `#1a2332` is approximately 3.33:1. These are color-pair
calculations, not a rendered accessibility certification.

For Flutter: use a single column at compact widths, Material text styles,
scalable labels, semantic colors with stronger contrast, and wrapping content.
Test large text and both themes on the target phones. Do not translate the
web's pixel sizes directly into Flutter text sizes.

### High: refresh reports checks that it never executes

Evidence: [refresh handler](../FigmaFrontEnd/src/App.tsx#L319),
[displayed timestamp](../FigmaFrontEnd/src/App.tsx#L558), and
[diagnostics claim](../FigmaFrontEnd/src/App.tsx#L1113).

Refresh waits 600 ms, updates a timestamp, and displays “Capabilities checked.”
It does not query Android, re-read browser battery state, or evaluate capabilities.
The timestamp initially comes from component initialization, not a measurement.
The diagnostics copy also says checks happen on opening or refreshing the app.

This conflicts with PRD FR-005/FR-050, UI/UX §§2.1 and 13.1, and Journey J-02.
A preview should say the native capability check is unavailable. In Flutter,
connect refresh to the repository/native resolver and date each actual reading;
use separate timestamps if measurements and capability checks differ. Keep
successful readings visible when a different metric fails.

### High: key workflows have no complete screen/state designs

Evidence: [storage review](../FigmaFrontEnd/src/App.tsx#L759),
[process empty state](../FigmaFrontEnd/src/App.tsx#L940),
[application empty state](../FigmaFrontEnd/src/App.tsx#L985), and
[review-removal dialog](../FigmaFrontEnd/src/App.tsx#L1377).

Storage has a real user-selected-file analysis flow, but no device-deletion
confirmation, Android authorization stage, or cleanup result report. Application
Manager has no inventory, search/filter, app details, settings shortcut, or
uninstall outcome design. Process Manager has no populated supported-data view,
record details, sorting/filtering, supported-action controls, protection reason,
or verified/unverified result design. Estimated used RAM is also absent.

These gaps concern PRD FR-007–FR-031, UI/UX §§6–8 and 13, and Journeys J-03–J-07.
The unavailable states are appropriate for the browser, but they are not enough
to specify how an available native feature should work. Add those screen and
state variants without fabricating live processes or enabling unsupported actions.

The “Remove from review” dialog is correctly labeled and does not delete files.
It must remain distinct from the future native deletion confirmation.

### Medium: navigation does not implement the required back/More behavior

Evidence: [navigation handler](../FigmaFrontEnd/src/App.tsx#L314) and
[mobile destinations](../FigmaFrontEnd/src/App.tsx#L1324).

Navigation changes a React state value rather than maintaining route history.
There is no implemented in-app back stack or detail-screen back behavior. “More”
opens a floating menu; it is not a page value, so `page === label` can never select
that destination. Battery, Settings, and other secondary pages consequently have
no selected parent destination in the mobile bar. Mobile buttons also lack the
selected-state semantics used by the desktop navigation.

UI/UX §§4.1–4.4 and Journey §13 require predictable back behavior and a More screen.
The Flutter recreation should use go_router with retained tab branches, a genuine
More destination, stable identifiers for details, and appropriate selected semantics.
React's shared file/filter state does survive navigation within this session; that
positive behavior should be retained.

### Medium: duplicate review lacks groups and retain-copy context

Evidence: [scan algorithm](../FigmaFrontEnd/src/App.tsx#L329),
[duplicate filter](../FigmaFrontEnd/src/App.tsx#L366), and
[file rows](../FigmaFrontEnd/src/App.tsx#L889).

SHA-256 comparison is genuine and is stronger than filename matching. However,
the scanner hashes every selected file in full without first grouping by size.
It stores only a duplicate boolean; the first member of each matching group is
not flagged, and the duplicate filter hides that first copy. Users cannot open
a matching group, compare all copies, or see which copy they intend to retain.
Location information is absent, although browser access may limit it.

PRD FR-010, Architecture §9.3, and Journey J-04 require staged detection and a
matching-group review. Flutter should keep stable file/group identities, display
all members and accessible location/size information, and keep at least one copy
unselected by default. Native deletion must verify each selected target's identity.
The current preview deletes no originals, so this is a missing future workflow,
not an observed destructive operation.

### Medium: scan failure and cancellation states omit useful outcomes

Evidence: [scan loop and final state](../FigmaFrontEnd/src/App.tsx#L329),
[cancel action](../FigmaFrontEnd/src/App.tsx#L826), and
[empty state](../FigmaFrontEnd/src/App.tsx#L870).

The failure count is discarded after selecting a status label. Even if every
file fails, the status becomes Partially Completed and the empty view invites
another scan without explaining the failures. There is no failed-file count,
reason, or retry guidance. Cancel invalidates the result generation but does
not abort the current full-file read/hash; results accumulated locally are not
published. The input can therefore keep consuming resources after cancellation.

PRD FR-014, UI/UX §§7.5 and 13, and Journey J-03 require explicit failures,
skipped/partial results, and safe cancellation. Use identified cancellable jobs,
chunked/background file work, truthful counts, and Failed when no requested work
succeeds. Avoid loading an entire large video into memory solely to hash it.

The button says “Choose more files,” but `scan()` clears the previous results.
Either append and recompute groups or label this as a replacement scan.

### Medium: settings and capability UX are mostly static

Evidence: [theme/session state](../FigmaFrontEnd/src/App.tsx#L232),
[permissions](../FigmaFrontEnd/src/App.tsx#L1119),
[settings](../FigmaFrontEnd/src/App.tsx#L1201), and
[manufacturer screen](../FigmaFrontEnd/src/App.tsx#L1063).

Theme selection is session-only. Monitoring is descriptive text, not a refresh
preference or optional sampling control. Capability/permission statuses are fixed
preview values with no revoked/denied/service-disconnected recovery variants.
Manufacturer Tools offers useful manual guidance, but has no verified-available
utility launch state or launch-failure/fallback action design.

PRD FR-032–FR-038/FR-049–FR-053, UI/UX §§10–11 and 14, and Journeys J-08/J-09
require these states. In Flutter, keep SharedPreferencesAsync persistence, drive
controls from current native capabilities, and recheck on resume. Diagnostics
should include structured, non-sensitive operation errors and recovery actions.
Optional history/sampling controls should only be enabled when implemented.

Advanced access being disabled is appropriate for the MVP. Its future authorized,
service-stopped, and permission-revoked states belong to the post-MVP design.

### Low: preview/decorative details need product-specific adaptation

Evidence: [device hero](../FigmaFrontEnd/src/App.tsx#L530),
[web labels](../FigmaFrontEnd/src/App.tsx#L484),
[version](../FigmaFrontEnd/src/App.tsx#L1275), and
[font import](../FigmaFrontEnd/src/index.css#L1).

The 260 px mobile hero and privacy/marketing sections occupy space that could
show the actual model and resource readings. The phone illustration is decorative,
not required by the documents. Favor a concise real-device summary for the native
app. Remove browser-connection instructions, workspace breadcrumbs, and web-preview
labels from the Android product flow. Read version information from the application.

The Google Fonts import makes a network request; the browser has a fallback font,
so this alone does not prove that core operations fail offline. For a fully local
Flutter experience, use system typography or bundle any licensed font assets.

## Coverage matrix

“Partial” means some visual structure or behavior exists; it is not acceptance.

| Area | Documentation | Export coverage | Work required for the documented Flutter app |
| --- | --- | --- | --- |
| Dashboard | FR-001–FR-006; UI/UX §5; J-01/J-02 | Partial: summary, metric cards, shortcuts, unavailable labels | Actual manufacturer/model/build; total/available storage and physical RAM; real refresh/loading/error/partial-data states |
| Storage access and categories | FR-007–FR-009; UI/UX §§7.1–7.3; J-03 | Partial: local file picker, MIME categories, large-file filter, search/selection | MediaStore/SAF, device storage overview, per-category counts/sizes, sorting, permission outcomes, Downloads/other handling |
| Duplicates | FR-010; Architecture §9.3; J-04 | Partial: SHA-256 and a duplicate filter | Size prefiltering, matching groups, retain-copy context, identity checks, bounded-memory hashing |
| Deletion/reporting | FR-011–FR-014; UI/UX §§7.4–7.7; J-03 | Not implemented: removing review entries is deliberately separate | Native confirmation/authorization, per-file verification, deleted/skipped/failed counts, confirmed bytes versus observed free-space change |
| Application Manager | FR-015–FR-020; UI/UX §8; J-05 | Empty/unavailable design only | Visible inventory, filtering, details, settings/uninstall actions, canceled/unverified results, visibility explanation |
| Process Manager | FR-021–FR-031; UI/UX §6; J-06/J-07 | Partial: RAM cards and accurate restriction notice | Estimated used RAM, measured timestamps/sources, supported-data/details views, sorting, supported actions, protection and operation-result states |
| Manufacturer tools | FR-032–FR-038; UI/UX §10; J-08/J-09 | Partial: compatibility fields and manual guidance | Verified available/absent/failed profiles, native launch/fallback actions, resume refresh, physical-device validation |
| Battery | FR-039–FR-042; UI/UX §9 | Partial: real browser reading, temperature/voltage/health placeholders, units | Android battery source; full/charging/discharging states, power source, measured timestamps, lifecycle handling and errors |
| Advanced access | FR-043–FR-048; UI/UX §11.2; J-10 | Disabled/unavailable preview | Acceptable MVP boundary; later add authorized capabilities, confirmation, protected targets, and disconnect/revocation handling |
| Settings/diagnostics | FR-049–FR-053; UI/UX §11 | Partial: theme choice, fixed statuses, clear-review action | Persistence, actual permission/capability resolution, recovery guidance, implemented monitoring preferences and safe diagnostics |
| Navigation | UI/UX §4; Journeys §13 | Partial: named destinations and retained session data | Material 3 NavigationBar, real More screen/selection, go_router, detail back stack, resume refresh |
| Accessibility/responsiveness | UI/UX §§3, 15–16; all personas | Partial: labels, focus outlines, dialog focus handling, 48 px overrides, reduced motion, bottom safe-area padding | Larger text, stronger contrast, compact single-column layout, dark-theme validation, TalkBack/large-text tests |
| Architecture/privacy | PRD §7; Architecture §§1–7, 12 | React/Vite reference with local analysis; not the required native app | Flutter/Riverpod/repositories/Pigeon/Kotlin; native safety checks; bundled/local typography and offline validation |
| Acceptance/testing | PRD §10; UI/UX §§18–19; Architecture §15 | No test suite declared in the export's package manifest | Flutter/widget/native/integration tests, permission and lifecycle cases, both physical devices; compilation alone is insufficient |

## What should be retained

- Blue primary accent, restrained card styling, rounded surfaces, and consistent icons.
- Resource overview and direct maintenance shortcuts.
- Explicit unavailable/source labels instead of invented measurements.
- No simulated process inventory, fabricated CPU/RAM data, or fake cleanup success.
- User-selected file access and real content hashing.
- Confirmation that distinguishes removing review entries from deleting originals.
- Disabled privileged actions and a useful standard-mode experience.
- Shared notice/badge/empty-state concepts, theme choices, focus styling,
  reduced-motion handling, and the existing touch-target improvements.

## Flutter recreation direction

1. Translate the visual language into Material 3 components and semantic theme
   tokens; retain the existing Kotlin readings and SharedPreferencesAsync themes.
2. Make compact Android layouts the baseline. Show a concise device summary,
   readable single-column resource cards, quick actions, and five primary tabs.
3. Define all feature screen variants: available, loading, empty, denied,
   unsupported, failed, partially completed, canceled, and requested/unverified.
   Only expose a state when supported by actual feature behavior.
4. Add app/process details, duplicate groups, deletion/operation confirmations,
   and result sheets; connect them through go_router and Riverpod controllers.
5. Expand typed Pigeon repositories/native services per milestone. Enforce file,
   permission, capability, and process safety rules again in Kotlin.
6. Test text scaling, dark contrast, tab/back behavior, permission revocation,
   native errors, scan cancellation, and truthful outcomes before device validation.

The visual direction can be reused, with these corrections. The documentation
does not require this exact artwork or web typography. A Flutter recreation
should preserve its identity while implementing the specified Android workflows.
