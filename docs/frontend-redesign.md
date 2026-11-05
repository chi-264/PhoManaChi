# Flutter frontend redesign

The Flutter interface now uses the visual direction from `FigmaFrontEnd` with the
corrections identified in [the source audit](figma-frontend-audit.md). The React
export remains reference material; the Android application renders native Flutter
widgets and keeps the existing typed Kotlin system-reading integration.

## Delivered

- Blue primary accents, rounded cards, tinted resource icons, a compact device
  summary, maintenance shortcuts, and a consistent light/dark visual system.
- Material typography, no remote font request, and stronger semantic text colors.
- A single column on compact phones; adaptive cards and a sidebar on wide screens.
  Layouts grow with their content and support larger system text.
- Five primary destinations. Battery, diagnostics, permissions, advanced access,
  settings, and About are nested under More. Secondary pages keep More selected
  and provide a Back action. The router is scoped to the Riverpod container.
- Shared page headings, resource cards, notices, status badges, navigation tiles,
  detail cards, and unavailable-feature views.
- Real system values for RAM, storage, and battery. Used memory/storage and bar
  fractions reject inconsistent inputs; invalid battery percentages stay unavailable.
- Manual refresh reads the repository and waits for its response. Observation
  timestamps come from the native snapshot. There are no simulated capability checks.
- Navigation and unimplemented-feature explanations remain accessible when the
  Android snapshot fails. Individual native read failures remain separate notices.
- Light/dark/system preferences are saved using SharedPreferencesAsync. Theme
  choice is reflected directly by the settings controls, with retry guidance for
  read failures and an error message if saving fails.

## Deliberate remaining scope

The original frontend milestone redesigned the existing application foundation.
The subsequent [app-management milestone](app-management.md) adds visible inventory,
app details, supported uninstall, and live capability states. Remaining work includes
file scanning/deletion, detailed process records
or control, manufacturer activity launching, or Shizuku. Their screens explain
what is available and what has not been implemented. The storage screen describes
the future confirmed-cleanup sequence without exposing an inactive destructive flow.

Those features still need the complete detail, permission, confirmation, result,
and recovery workflows listed in the audit. In particular, no fake process rows,
duplicate groups, cleanup summaries, installed applications, or advanced-capability
results have been inserted to make the screens look populated. The application
is not being claimed to satisfy the full PRD yet.

## Verification and previews

Frontend checks exercise real repository refresh calls, resume refresh, More/back
navigation, navigation during native failure, theme selection, invalid measurements,
compact 320 px layouts at 2× text in both themes, wide layout, and semantic color
contrast targets. Tests load fonts from the installed Flutter SDK for realistic
text layout; no test font is added as a runtime dependency.

To regenerate preview images:

```sh
flutter test --no-pub --dart-define=CAPTURE_PREVIEWS=true
```

The screenshots in `build/previews/` use **test fixture readings**, not measurements
from a physical phone. They show the dashboard at compact light/dark widths and
at a wide width. Physical-device rendering, TalkBack behavior, and real readings
still require testing on the target Realme and TECNO phones.

Run `flutter analyze --no-pub`, `flutter test --no-pub`, and
`flutter build apk --debug --no-pub` for the normal checks. The debug APK is written
to `build/app/outputs/flutter-apk/app-debug.apk`. See the task result for the final
verification status of this revision.
