# Storage analysis and reviewed cleanup (0.4.0 / build 4)

Storage is a native Android workflow behind a versioned Pigeon interface. Flutter
renders the scan and explicit review; Android owns source URIs, opaque IDs, scope,
identity checks, expiring review tokens, authorization, deletion, and verification.
Core file processing stays on the phone. Opening Storage does not request access.

## Access and coverage

- **Choose folder:** Android's Storage Access Framework tree picker. Only files
  under the granted tree are enumerated. Android restricts locations such as
  Android/data and Android/obb; the service also excludes those paths and Phone
  Manager's own Android/media path. Directories are never cleanup targets.
- **Choose files:** Android's document picker with multiple selection. Files stay
  inside the temporary URI grants. Non-document, virtual, partial, read-only, or
  incompletely identified provider records cannot become deletion targets.
- **Scan media library:** contextual read permissions and MediaStore image/video/
  audio collections. Android 13 uses per-category permissions; Android 14 selected
  photos/videos are limited coverage. Denied collections and provider failures
  produce warnings. No all-files permission or private app-data access is used.
- Picker cancellation and fully denied media permission retain the previous scan.
  Revoked access cannot authorize cleanup: proofs and deletion-time checks fail.
- Results and URI grants are session-only; no persistable URI grant is taken.
  Process restart requires choosing access again. Forget scan results clears the
  in-memory inventory and rescan scope, without deleting files. It preserves the
  last cleanup result. Android manages the lifetime of temporary grants.

The inventory is bounded to 5,000 files, 1,000 directories, and depth 32. Reaching a
limit or encountering provider errors makes coverage partial. Folder/provider
warnings are counts of observations, not estimates of missing files. A provider
can block an I/O call despite cancellation; stopping finishes at a safe boundary.

References: [document access](https://developer.android.com/training/data-storage/shared/documents-files),
[shared media access](https://developer.android.com/training/data-storage/shared/media).

## Analysis

Categories are images, videos, audio, documents, archives, APKs, and other files.
Search matches file names and displayed locations; category, large-file (100 MiB),
and duplicate-group filters combine. Sorting supports size, name, and modification
time. Unknown sizes remain unknown and do not contribute to byte totals.

Size is the first duplicate prefilter. Only same-size files with usable identity
metadata are compared using streamed SHA-256 with a 64 KiB buffer. Exact byte count,
metadata before/after hashing, and cancellation are checked. Failed comparisons
never produce a duplicate group. Matching groups represent the observed content
at scan time; names and size alone never prove duplication. Unknown metadata or
unreadable files mean duplicate detection may be incomplete.

Scans have native job IDs and phases. Replaced scan IDs clear Flutter selection.
Canceled/failed scans display read-only results. Cancellation never starts cleanup.
Progress and results refresh only in the foreground; background scanning is not
promised and Android may end the process. There is no automatic resume.

## Review and deletion

1. Select individual eligible files, at most 100 per review. Selection is preserved
   across UI filters; the selected count and bytes include hidden selections.
   There is no automatic selection. Every known duplicate group must retain at
   least one unselected, verifiable copy.
2. **Review selected files** asks Android to validate the job and exact file IDs,
   hash selected content, and verify at least one retained copy for each affected
   duplicate group. Flutter receives a native single-use token valid for 10 minutes
   measured by the monotonic clock. The review lists exact files, locations, and
   logical bytes. Preparing a review cannot delete files.
3. **Delete reviewed files** is the explicit permanent-deletion confirmation.
   Cancel review discards the token. Repeated confirmation cannot reuse it.
4. For MediaStore files, Android 11+ requests write authorization for those URIs.
   This deliberately uses `createWriteRequest` rather than automatic deletion on
   approval, so identity/content/retained-copy checks can run after the prompt.
   Android 10 uses recoverable authorization and rechecks before retrying;
   Android 9 requests legacy write permission only at this confirmed step.
   SAF files require a granted write URI and the provider's supports-delete flag.
5. Before each delete, Android rechecks access, scanned identity and reviewed SHA-256,
   plus the retained duplicate copy. Changed targets are skipped. Native delete
   APIs act only on stored, reviewed URIs; Dart cannot pass a deletion URI or path.
6. A deletion counts only when the provider returns success **and** a follow-up
   query finds no file. A lost permission or ambiguous cursor is not absence.
   Uncertain results are unverified and contribute zero confirmed deleted bytes.
   Stop requests do not undo already completed deletions. Remaining unattempted
   targets receive per-file skipped/failed outcomes as appropriate.

Android provider APIs do not offer an atomic compare-hash-and-delete operation.
Another app/provider can change content between the final check and deletion;
these safeguards reduce that race but cannot guarantee its absence. This workflow
is permanent deletion, not a recycle bin or app-cache cleaner. Use disposable
fixtures for initial device validation.

References: [MediaStore authorization](https://developer.android.com/reference/android/provider/MediaStore),
[document deletion](https://developer.android.com/reference/android/provider/DocumentsContract#deleteDocument(android.content.ContentResolver,%20android.net.Uri)).

## Results and interruption

Reports distinguish requested, confirmed deleted, skipped, failed, and unverified
files, with per-file names/messages. Confirmed deleted logical bytes are separate
from observed internal data-volume free bytes before/after. The signed free-space
change can be negative or unavailable and need not match scope deletion: other
apps, external volumes, provider behavior, and filesystem allocation affect it.

Only cleanup outcome metadata is persisted locally (names, opaque IDs, counts,
bytes, times); file URIs, content, and review tokens are not persisted. If Android
ends the process during cleanup, the last recorded confirmations are retained and
unrecorded outcomes become unverified. Nothing retries automatically. A fresh scan
is required before a second cleanup attempt, including after cancellation/failure.

## Physical-device acceptance (pending)

Use a disposable folder with unique files, known duplicate content under different
names, same-size different-content files, a file larger than 100 MiB, and a nested
subfolder on Realme 5i and TECNO Spark 30 5G. Record OS/API and provider for each:

- Picker cancel, read-only access, media deny/partial grant/revoke, narrow scope,
  unreadable item, empty folder, scan cancellation and limit notices.
- Search/sort/categories and exact duplicate groups; keep-copy rule across filters.
- Review/cancel without mutation; change a target and retained copy after review;
  revoke access; expire a review; confirm once; decline Android authorization.
- Actual provider deletion and post-query absence, per-file outcomes, logical
  bytes vs internal free-space change, and required rescan before retry.
- Background/resume, process termination during scan/cleanup, no automatic retry,
  restored interrupted report, large text, TalkBack, and light/dark layouts.
- Install the signed v0.4.0 update over the public v0.3.0 build through App updates.

Automated policy/UI checks and APK compilation cannot certify OEM/provider runtime
behavior. See implementation-status.md for recorded checks on this milestone.
