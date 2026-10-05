"""Localize identified synthetic demo finance records without resetting tables.

The factor is an illustrative demo pricing policy, NOT a live exchange rate.
Non-demo orders, users, receipts, audit history and foreign-currency payments stay intact.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import psycopg
from ai.core.config import settings
from scripts.reset_demo_data import user_digest


def apply(backup_dir):
    if settings.db_host not in ('localhost', '127.0.0.1'):
        raise RuntimeError('Only the configured local demonstration database is supported.')
    directory = Path(backup_dir).resolve()
    manifest = json.loads((directory / 'manifest.json').read_text())
    if manifest['database'] != settings.db_name or not (directory / 'database.dump').is_file():
        raise RuntimeError('A matching database backup is required.')
    with psycopg.connect(settings.database_url) as conn:
        before = user_digest(conn)
        if before[0] != manifest['users_digest']:
            raise RuntimeError('Users changed since the backup; prepare a fresh backup.')
        with conn.transaction():
            conn.execute('LOCK TABLE "PurchaseOrders", "OrderLines", "PaymentTransactions", "SupplierMaterialQuotes", "SupplierCandidates", "ProcurementRequests" IN SHARE ROW EXCLUSIVE MODE')
            ids = [row[0] for row in conn.execute('SELECT p."Id" FROM "PurchaseOrders" p WHERE NOT EXISTS (SELECT 1 FROM "PaymentTransactions" t WHERE t."PurchaseOrderId"=p."Id" AND t."TransactionId" NOT LIKE \'DEMO-PAYMENT-%\') AND "PoNumber" LIKE \'PO-DEMO-%\' AND upper("Currency")=\'USD\'').fetchall()]
            requests = [row[0] for row in conn.execute('SELECT "Id" FROM "ProcurementRequests" WHERE "GeneratedPurchaseOrderId" = ANY(%s)', (ids,)).fetchall()]
            changed_quotes = conn.execute('UPDATE "SupplierMaterialQuotes" SET "UnitPrice"="UnitPrice"*300, "Currency"=\'LKR\' WHERE upper("Currency")=\'USD\' AND "QualityEvidence" LIKE \'Demo specification:%\'').rowcount
            conn.execute('UPDATE "OrderLines" SET "UnitPrice"="UnitPrice"*300, "TotalPrice"="TotalPrice"*300 WHERE "PurchaseOrderId"=ANY(%s)', (ids,))
            conn.execute('UPDATE "PurchaseOrders" SET "TotalCost"="TotalCost"*300, "BudgetLimit"="BudgetLimit"*300, "ApprovalThreshold"="ApprovalThreshold"*300, "Currency"=\'LKR\' WHERE "Id"=ANY(%s)', (ids,))
            conn.execute('UPDATE "PaymentTransactions" SET "Amount"="Amount"*300, "Currency"=\'LKR\' WHERE "PurchaseOrderId"=ANY(%s) AND "TransactionId" LIKE \'DEMO-PAYMENT-%%\' AND upper("Currency")=\'USD\'', (ids,))
            conn.execute('UPDATE "SupplierCandidates" SET "UnitPrice"="UnitPrice"*300, "TotalCost"="TotalCost"*300, "Currency"=\'LKR\' WHERE "ProcurementRequestId"=ANY(%s) AND upper("Currency")=\'USD\'', (requests,))
            conn.execute('UPDATE "ProcurementRequests" SET "MaximumBudget"="MaximumBudget"*300, "PreferredRegion"=\'Sri Lanka\' WHERE "Id"=ANY(%s)', (requests,))
            if ids:
                # Outcomes explicitly marked as demo, not externally observed learning records.
                conn.execute('UPDATE "ProcurementOutcomes" SET "EstimatedPrice"="EstimatedPrice"*300, "FinalPrice"="FinalPrice"*300 WHERE "QualityEvidence" LIKE \'Demo receipt inspection%\'')
            # Currency-specific supplier metrics cannot add USD and LKR together.
            conn.execute('UPDATE "SupplierPerformances" sp SET "TotalSpending"=COALESCE((SELECT SUM(p."TotalCost") FROM "PurchaseOrders" p WHERE p."SupplierId"=sp."SupplierId" AND p."Currency"=\'LKR\' AND p."Status" NOT IN (\'Draft\',\'Rejected\')),0), "AverageOrderValue"=COALESCE((SELECT AVG(p."TotalCost") FROM "PurchaseOrders" p WHERE p."SupplierId"=sp."SupplierId" AND p."Currency"=\'LKR\' AND p."Status" NOT IN (\'Draft\',\'Rejected\')),0)')
            conn.execute('UPDATE "RawMaterials" SET "Category"=CASE "Category" WHEN \'Box Pouch\' THEN \'BoxPouch\' WHEN \'Biscuit Packaging\' THEN \'BiscuitPackaging\' WHEN \'Tea Bag\' THEN \'TeaBag\' WHEN \'Standard Roll\' THEN \'StandardRoll\' ELSE "Category" END')
            conn.execute('ALTER TABLE "PurchaseOrders" ALTER COLUMN "Currency" SET DEFAULT \'LKR\'')
            conn.execute('ALTER TABLE "PaymentTransactions" ALTER COLUMN "Currency" SET DEFAULT \'lkr\'')
            conn.execute('ALTER TABLE "SupplierCandidates" ALTER COLUMN "Currency" SET DEFAULT \'LKR\'')
            conn.execute('ALTER TABLE "PurchaseOrders" ALTER COLUMN "ApprovalThreshold" SET DEFAULT 1500000')
            version = conn.execute('SELECT "ProductVersion" FROM "__EFMigrationsHistory" ORDER BY "MigrationId" DESC LIMIT 1').fetchone()[0]
            conn.execute('INSERT INTO "__EFMigrationsHistory" ("MigrationId","ProductVersion") VALUES (%s,%s) ON CONFLICT DO NOTHING', ('20261005120000_DefaultSriLankanCurrency', version))
            assert user_digest(conn) == before, 'Users changed'
            assert conn.execute('SELECT COUNT(*) FROM "OrderLines" WHERE "PurchaseOrderId"=ANY(%s) AND "TotalPrice" != "Quantity"*"UnitPrice"', (ids,)).fetchone()[0] == 0
            assert conn.execute('SELECT COUNT(*) FROM "PurchaseOrders" p WHERE p."Id"=ANY(%s) AND p."TotalCost" != (SELECT SUM(l."TotalPrice") FROM "OrderLines" l WHERE l."PurchaseOrderId"=p."Id")', (ids,)).fetchone()[0] == 0
            assert conn.execute('SELECT COUNT(*) FROM "PaymentTransactions" t JOIN "PurchaseOrders" p ON p."Id"=t."PurchaseOrderId" WHERE p."Id"=ANY(%s) AND t."TransactionId" LIKE \'DEMO-PAYMENT-%%\' AND (t."Amount"!=p."TotalCost" OR upper(t."Currency")!=p."Currency")', (ids,)).fetchone()[0] == 0
        report = {'demo_orders_localized': len(ids), 'demo_quotes_localized': changed_quotes, 'users_preserved': before[1], 'currency': 'LKR', 'demo_price_factor': '300 (illustrative, not live FX)', 'remaining_foreign_orders': conn.execute('SELECT COUNT(*) FROM "PurchaseOrders" WHERE upper("Currency")!=\'LKR\'').fetchone()[0]}
    (directory / 'localization-report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--backup-dir', required=True)
    apply(parser.parse_args().backup_dir)
