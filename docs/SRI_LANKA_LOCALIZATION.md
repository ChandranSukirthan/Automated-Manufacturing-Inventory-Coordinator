# Sri Lankan configuration

New procurement requests, supplier quote defaults, draft orders and payments use LKR. Web and mobile money displays include the currency code, thousands separators and two decimal places. Explicit historical foreign currencies remain visible; financial summaries aggregate LKR records rather than combining currencies.

The current demonstration policy uses an LKR 6,000,000 default procurement budget and an LKR 1,500,000 approval threshold. These are configurable business settings, not regulatory thresholds. The demonstration seed uses an illustrative factor of 300 to produce consistent LKR prices, budgets and totals; this is not a live exchange rate. External quotes retain their actual currency and incompatible quotes cannot silently pass an LKR budget.

Sri Lanka is the default supplier search region. Local supplier contact examples use +94. Date displays use Asia/Colombo and day/month/year. Shift input converts Colombo time to UTC; database timestamps remain UTC. Quantity labels use material units instead of assuming every material is measured in kilograms.

## Existing local demonstration data

Before localizing an existing localhost database, prepare a backup with `ai/venv/Scripts/python.exe scripts/reset_demo_data.py --prepare`. Do not invoke that script's reset action to localize data. Then run `ai/venv/Scripts/python.exe scripts/localize_demo_data.py --backup-dir <prepared-backup-directory>`.

The localization script requires a matching PostgreSQL backup and manifest. It changes recognized demonstration records transactionally, preserves users, skips orders with recorded non-demo provider payments and verifies arithmetic. Repeating it does not convert already localized values again. The EF migration changes defaults for future records without rewriting historical payments. Backups and localization reports stay in the ignored `.local-backups` directory.

## Verification on 5 October 2026

- AI: 115 tests passed, including LKR handoffs and incompatible foreign quote rejection.
- Backend: 81 tests passed, including all-role CRUD contracts and PostgreSQL migration/receipt transaction checks.
- Web: 32 tests passed and production build succeeded.
- Mobile: 44 tests passed and Flutter analysis reported no issues.
- Backend build: zero warnings or errors.
- Actual local database: user preservation, order arithmetic, quote currency, payment consistency and packaging category checks passed.
- Authenticated API reads for all four roles passed. A read-only cooperative run using actual inventory, production, internal quotes and quality data selected an LKR 5,550 quote for 1,000 rolls, calculated LKR 5,550,000, passed validation and reached the manager approval decision. External market research was omitted for that check. It did not create an order or payment.

These checks do not constitute a new external payment, email delivery, cloud deployment or installed mobile release test. One previously settled USD order intentionally remains USD to match its provider transaction.
