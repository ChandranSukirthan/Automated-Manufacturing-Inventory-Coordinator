# Manufacturing demo dataset

The local database was refreshed on 5 October 2026. Existing users, passwords,
roles and account settings were preserved byte-for-byte. Application migration
metadata was retained. Old OTPs, refresh sessions and cached AI workflow sessions
were cleared rather than replaced with fabricated authentication credentials.

The dataset represents a food-packaging manufacturer in Sri Lanka. It includes:

- Seven packaging categories and 12 materials, each with a declared unit.
- Twenty-five physical stock rolls with corresponding batches and QA records.
- Thirty days of consumption per material, reconciled to opening stock and receipts.
- Four active suppliers and 48 material quotes with prices, availability, pack sizes,
  minimum quantities, lead times and quality evidence.
- Six purchase orders covering draft, pending approval, approved, in transit,
  completed and rejected stages. Line totals agree with order totals.
- Three defects, one active quarantine and one released quarantine.
- Five machines, maintenance history and four material-linked production shifts.
- One completed historical demo workflow. New live AI requests use the regular
  application workflow; the historical example is not a resumable AI session.

Supplier emails and source URLs use the reserved `.example` domain. Payment and
approval history is explicitly synthetic. Seeding did not contact Stripe, SendGrid,
suppliers or an LLM and did not approve or pay any real order.

Both Kraft Paper Liner and the other materials have active supplier quotes. Low
stock examples are Water-based Flexographic Ink and High-barrier Pouch Film.
Printed Metallized OPP Film has one quarantined roll for the QA demonstration.

The reset script is `scripts/reset_demo_data.py`. It requires a verified local
backup before applying changes, resets identity sequences, checks nine consistency
invariants before committing and verifies that the users are unchanged.
Backups and the reset report are stored in the Git-ignored `.local-backups` folder.
