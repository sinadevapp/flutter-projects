# FitCoach — visual language

The reasoning behind `lib/core/theme/app_theme.dart`. Read this before
restyling a screen; the constraints here are decisions, not preferences.

The palette, type scale and component rules were drafted in **Stitch**
(project «FitCoach — Persian Fitness Coaching», design system «FitCoach Core»)
and then implemented here. Stitch proposes mockups; this file is what was
actually adopted, and where it deliberately differs.

---

## What this app is

A coach (مربی) and a student (شاگرد) share one device. Phase 1 is offline —
no accounts, no network, everything from a local database.

Two contexts drive every visual decision:

- **The coach** is managing several people's training at a desk or standing up,
  reading lists and numbers.
- **The student** is mid-workout, one free glance at the screen, possibly out
  of breath, possibly with sweaty hands.

The second is why nothing here is decorative.

---

## Direction (RTL) — the section that matters most

Persian is primary and the whole layout is right-to-left. English is supported
and must read correctly LTR.

**Build on logical edges — `start`/`end`, never `left`/`right`.** A layout that
only works mirrored is not finished. Flutter's `Directionality` handles this
automatically *if* the widgets use logical properties.

Three places where this is not automatic and needs care:

- **Chevrons.** `Icons.chevron_left` points at the *next* screen in RTL. This is
  correct and intentional — do not "fix" it to `chevron_right`.
- **Progress bars.** `LinearProgressIndicator` fills from the start edge, which
  is the right in a Persian locale. No extra work needed, and adding any would
  be wrong.
- **Back buttons.** The `AppBar` back affordance sits on the right in RTL.

---

## Numbers, dates, money

- **Persian digits** (۰۱۲۳۴۵۶۷۸۹) everywhere in `fa`. This is not optional
  polish: a Persian user reading `4` instead of `۴` is reading a foreign
  character.
  - `localizeNumber(locale, value)` for a count.
  - `NumberFormat` with the locale tag does it *and* the separator in one step —
    `fa` gives «۴۵٬۰۰۰» (Persian thousands mark), `en` gives `45,000`. Never
    convert digits afterwards; that leaves a Latin comma inside a Persian
    number.
- **Jalali dates** in Persian, Gregorian in English. A week starts **Saturday**
  in Persian, Monday in English — `startOfWeek(locale, date)`.
- **Money** goes through `formatToman()`. Prices here run into millions, so
  `2500000` raw is unreadable at a glance: it abbreviates above 100,000.
  Persian writes the scale as a separate word («۳۲۰ هزار»), English suffixes it
  (`320k`).

---

## Colour

| Role | Value | Use |
|---|---|---|
| Primary | `#0F766E` deep teal | Primary actions, active nav, progress fills |
| Live | `#EA580C` warm orange | **Only** a running state — the rest timer, the current set |
| Done | `#16A34A` green | **Only** completed states |
| Error | Material default | Destructive actions, failures |

Two rules that are easy to break by accident:

1. **Orange is scarce.** It marks "something is happening right now". The
   moment it appears on a normal button it stops carrying that meaning.
2. **Green is not decoration.** A completed set, a finished workout. Not a
   badge, not a heading.

Teal rather than blue because blue reads clinical (medical) and orange/red
reads aggressive (supplement branding). FitCoach sits between: a trustworthy
tool that takes the person's progress seriously.

---

## Type

**Vazirmatn**, bundled in `assets/fonts/` (SIL OFL 1.1, `OFL.txt`).

Bundled rather than fetched: the app is offline-first, and a font that arrives
late reflows every screen. Declared on the theme so no widget has to name it.

Line height runs **1.6×**. Persian ascenders and descenders are taller than
Latin's and look cramped at 1.2.

Four weights ship: 400, 500, 600, 700. Hierarchy comes from **weight and size,
not colour** — a quiet label in `onSurfaceVariant` above a loud value.

---

## Shape, spacing, depth

- **12px radius** on buttons, fields and cards (`AppTheme.radius`).
- **16px page padding** (`AppTheme.pagePadding`), mobile-first, single column.
- **8px rhythm** with a 4px base.
- **48px minimum touch target** (`AppTheme.minTouchTarget`). This is tapped with
  one thumb by someone out of breath.
- **Flat.** Elevation is 0 on cards and the app bar. Depth is surface tiers
  (white card on `#F8FAFC`) plus a 1px `#CBD5E1` border. A hard shadow reads as
  heavy and dated on a phone.

---

## Components

`lib/core/widgets/states.dart` holds the shared ones:

- **`EmptyState`** — icon, message, and a hint explaining *why* it is empty.
  Where the user can act, an action button; where they cannot (a student with no
  plan), a hint only. Never a bare "nothing here": it does not say whether the
  state is a problem or simply the beginning.
- **`ErrorState`** — a plain-language message and a retry. Never a raw exception
  string. A stack trace in the UI is a debugging aid, not something to read.
- **`MetricCard`** — the signature element. Quiet label above a large value.
  Numbers here are always localized by the caller.

Screens own their specific pieces: `RestTimerView`, `WorkoutSummaryView`,
`WeeklyVolumeChart`, `MovementVolumeChart`.

---

## Where this differs from the Stitch mockup

The generated mockup for the active-workout screen is the visual reference, but
two things in it were **not** adopted:

1. **It invented a weight field.** The mockup shows «وزن پیشنهادی / وزن قبلی»
   (suggested and previous weight) per set. FitCoach tracks **sets and reps
   only** — there is no weight column in the schema. Adding one to match a
   picture would be building a feature backwards from a mockup.
2. **It rendered at desktop width** (2560px) despite the mobile request. The
   implemented screen is phone-first, single column.

Everything else — the teal, the RTL progress bar, the large movement name, the
orange rest ring, the full-width primary button — is implemented as drawn.

---

## Generating the icon

The launcher icon is drawn in code (`lib/tool/app_icon.dart`), not committed as
an opaque binary, so a change to the brand teal can be followed in one line.

```bash
GENERATE_ICON=1 flutter test test/tool/generate_icon_test.dart   # writes the PNG
dart run flutter_launcher_icons                                   # platform icons
```

The generator lives under `test/` because `dart:ui` needs the Flutter engine
and `flutter test` is the way to get one without launching an app. It is
**skipped unless `GENERATE_ICON=1`**, because a normal test run must not write
files.
