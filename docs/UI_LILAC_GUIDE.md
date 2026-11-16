# Lilac and ivory interface

The Campus Facility Inspection Scheduler uses the two visual references supplied by the project owner as inspiration: a light/dark task dashboard and the Lilac / Flow component study. The layout, campus illustration and implementation were created for this application. No reference-image artwork is embedded in the app.

## Visual system

| Element | Light theme | Dark theme |
| --- | --- | --- |
| Canvas | Ivory `#FCFAF6` | Ink `#191A25` |
| Cards | Warm white `#FFFDFC` | `#242533` |
| Primary accent | Violet `#5B2DFF` | Lilac `#C8B4FF` |
| Soft panels | `#F1EBFC` | `#333047` |
| Main text | `#1F1F28` | `#F7F2FF` |

DM Serif Display supplies the headings; DM Sans supplies controls and body text. Both fonts are bundled locally under the SIL Open Font License. Their license files are in `frontend/assets/fonts/`. The app makes no runtime request to Google Fonts for these families.

Cards have rounded corners, subtle outlines and restrained shadows in light mode. Desktop navigation becomes a drawer below 1100 logical pixels. The profile/calendar column stacks below the main content when space is limited. The moon/sun button changes the entire app theme, including dialogs and existing forms. Theme choice lasts for the current app session.

## Working controls and data

- Facility search matches a name without case sensitivity, or an exact facility ID. Clear search restores the full loaded list without a new API request.
- Overview returns to the top; Facilities scrolls to the facility list.
- Supervisors see the existing daily compliance counts and their permitted finding alerts. The progress date and timezone come from the API.
- Inspectors see only their assigned inspection data. Daily counts and calendar dates use the browser's local time.
- Maintenance sees its delivered alerts. The supervisor/maintenance calendar shows due dates from accessible alerts; it is not a complete inspection-plan calendar.
- Calendar arrows change the month. Selecting a day filters the visible events. Today returns to the current date. Event cards open the existing inspection or alert screen.
- The progress ring uses actual completed/scheduled counts. An empty date shows a dash and a clear empty state; failed requests show unknown values with a retry action.
- New plan, My Inspections, Finding Alerts, Alerts & Compliance, sign-in and server sign-out retain their existing workflows and role checks.
- Signing out or expiring a session clears private dashboard activity. Backend authorization remains authoritative.
- The workflow guide explains the existing plan/inspect/follow-up routine. The dashboard does not add plan editing, finding closure, account provisioning or other unfinished workflows.

## Files to understand

| File | Responsibility |
| --- | --- |
| `frontend/lib/campus_theme.dart` | Palette, typography, light/dark components and shared empty states |
| `frontend/lib/campus_dashboard.dart` | Responsive layout, search, calendar and campus illustration |
| `frontend/lib/dashboard_data.dart` | Facility/activity models and reads from existing role-permitted endpoints |
| `frontend/lib/main.dart` | App theme choice, session lifecycle, secure client and navigation |
| `frontend/lib/sign_in_dialog.dart` | Sign-in form, errors and password visibility control |

## Run and verify

Use the [Week 14 setup guide](WEEK14_SETUP.md) for the existing Windows project and HTTPS configuration. Build the Flutter release with the documented HTTPS API URL, then serve it through Caddy at `https://localhost:8443`.

From `frontend`, run `flutter analyze` and `flutter test`. The UI revision has ten Flutter tests, including facility search/theme changes, role-permitted activity, calendar selection, clearing private activity on logout, and activity error/retry behavior. These complement the existing secure-client and sign-in/out checks.

Cloud browser checks exercise desktop, a 1024-pixel tablet viewport and a 390-pixel mobile viewport over CA-verified HTTPS. The screenshots use a fresh fictional cloud database; empty inspection and finding lists are genuine. Student Windows/Edge verification remains a separate recorded activity.

When updating the Week 14 report, record the exact new commit and use screenshots captured from that build. The earlier report and evidence for commit `410c884` remain a historical snapshot. They do not certify the appearance of this later UI revision.

## Font sources and acknowledgment

- [DM Sans source and license](https://github.com/google/fonts/tree/main/ofl/dmsans)
- [DM Serif Display source and license](https://github.com/google/fonts/tree/main/ofl/dmserifdisplay)

Codex assisted with the design adaptation, implementation and cloud validation. The student's own local tests and screenshots should be recorded separately in the contribution and evidence sections.
