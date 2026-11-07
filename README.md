# Centsible — make cents of every peso

Flutter front-end, **first draft**, running entirely on mock data. Built from the
*Centsible — Mobile App Plan* doc and the 13-screen *Centsible — App Prototype* canvas.

## Run

```bash
flutter pub get
flutter run            # Android / iOS / Chrome
flutter test           # cash-math tests
```

On the sign-in screen:

- **Continue with Google** opens the seeded account with `Household Budget` full of data.
- **Create an account** walks through email sign-up → Verify email → Onboarding, which creates a new, empty book.

The mock clock is fixed at **Sat, Nov 7, 2026** (`MockSeed.today`), so labels like "due in 5 days" match the prototype.

## Architecture (MVVM, per the plan)

```
View (screens)  →  ViewModel (Riverpod Notifier / derived Provider)  →  Repository (Notifier)  →  mock seed
```

```
lib/
  app/          theme (M3 light/dark + AppColors), go_router + auth redirect, bottom-nav shell
  core/         money (int minor units), dates, keypad calculator, shared widgets
  data/
    models/     user, book/member/invitation, wallet, category, entry/attachment
    mock/       mock_seed.dart — deterministic data
    repositories/  in-memory Notifiers that stand in for Drift tables + Firebase Auth
  domain/       cash_calculator.dart — the dashboard rules (pure, unit-tested)
  features/     auth · dashboard · entries · accruals · wallets · books · settings
```

The repositories hold their state the way Drift's `watch()` streams will later. To go
live, replace the repository bodies (Drift, dio/retrofit, firebase_auth) and leave the
ViewModels and screens as they are.

## Screens → routes

| # | Screen | Route |
|---|--------|-------|
| 1 | Sign in / Sign up | `/sign-in` |
| 2 | Verify email | `/verify-email` |
| 3 | Onboarding | `/onboarding` |
| 4 | Dashboard | `/home` |
| 5 | New / edit entry | `/entries/new`, `/entries/:id/edit` |
| 6 | Entries | `/entries` |
| 7 | Entry detail | `/entries/:id` |
| 8 | Receivables & payables | `/accruals` |
| 9 | Wallets | `/wallets` |
| 10 | Card detail | `/wallets/:id` |
| 11 | Books & members | `/books` |
| 12 | Categories | `/books/categories` |
| 13 | Account settings | `/account` |

## Not in this draft

Real auth, Drift persistence, sync/outbox, file picking (the attachment pickers are mocked),
cross-currency transfers (the To-wallet list only shows wallets in the From wallet's currency),
codegen (freezed/riverpod_generator), and the `decimal` package (money is stored as `int` minor units).
