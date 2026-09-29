# PocketDay

A Flutter Android app with a red-and-white Money Manager-inspired interface for everyday spending and savings in Malaysian ringgit (MYR / RM) and Singapore dollars (SGD / S$).

## Features

- Record income and expenses with a date, category, currency, and description.
- Separate MYR and SGD balances; never add different currencies together.
- Daily date-grouped activity, a tappable calendar, weekly totals, monthly summaries, and an all-time view.
- Income/expense category donut charts with percentage legends and transaction drill-down.
- Cash, Bank, and E-wallet recording and balance summaries.
- Combined account, category, transaction-type, currency, and search filters; confirmed deletion.
- Savings pots with targets, progress, custom contributions, and quick RM 2 / S$2 contributions.
- Bidirectional MYR/SGD conversion with online rates, manual refresh, automatic refresh every 15 minutes while open, and refresh on returning to the app.
- Local persistence for transactions, savings, and the last successful exchange rate.
- Responsive Material 3 interface for phones and larger screens.

## Exchange-rate accuracy

Uses https://api.frankfurter.dev/v2/rate/SGD/MYR (documentation: https://frankfurter.dev/). Frankfurter provides **daily reference rates, not real-time trading quotes**. The app displays the source date, last fetch time, and cached/offline status. Conversions are estimates, not bank offers. No placeholder exchange rate is supplied when the network is unavailable.

True tick-by-tick pricing remains outside this version. It requires a suitable licensed provider and a backend to protect its API credentials. Refreshing a daily source more often does not turn it into a real-time feed.

## Run (PowerShell, from this folder)

```powershell
flutter pub get
flutter devices
flutter run
```

Connect an Android phone with USB debugging enabled, or launch an Android emulator before `flutter run`.

## Verify and build

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

The installable development APK is `build/app/outputs/flutter-apk/app-debug.apk` after a successful build. This is a development app; production signing and a final application ID must be configured before a Play Store release.

## Storage and boundaries

Transactions use integer cents. Currency conversion is a display estimate and never rewrites recorded amounts. Savings pots record money the user manually sets aside; they do not move bank funds or subtract from the recorded transaction balance.

Records are stored locally using SharedPreferences. No financial entries are sent to the exchange-rate provider; only the currency pair is requested. This version has no cloud sync, encryption layer, export/restore flow, or bank connection. Uninstalling or clearing app data can remove records. It is a personal-tracking prototype, not a banking ledger; durable database storage and tested backup/restore are recommended before relying on it as the only copy of financial records.

## Structure

```text
lib/
  main.dart                  # Startup and local storage initialization
  app.dart                   # MaterialApp configuration
  screens/
    home_screen.dart         # Navigation, savings, converter, entry forms
    ledger_screen.dart       # Transactions, calendar, statistics, accounts
  models/
    entry.dart               # Transaction model and JSON serialization
    goal.dart                # Savings goal model and JSON serialization
  store/
    pocket_store.dart        # App state, persistence, exchange-rate fetching
  theme/
    app_colors.dart          # Shared color palette
    app_theme.dart           # Material theme
  widgets/
    spending_pie.dart        # Reusable category chart painter
  utils/
    money.dart               # Currency symbols, formatting, cent parsing
    entry_filters.dart       # Date, currency, search, and account filtering
  constants/
    accounts.dart            # Supported account types
```

Screens depend on the store and models. Models contain no UI or storage dependencies. Shared formatting and filtering stay in utilities. Tests under `test/` cover money validation, persistence, exchange rates, filtering, and phone interactions.

The supplied Money Manager image was used as product inspiration. PocketDay uses its own interface and branding.
