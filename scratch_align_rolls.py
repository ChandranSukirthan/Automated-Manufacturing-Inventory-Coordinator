import psycopg
from ai.core.config import settings

def main():
    with psycopg.connect(
        host=settings.DB_HOST,
        port=settings.DB_PORT,
        dbname=settings.DB_NAME,
        user=settings.DB_USER,
        password=settings.DB_PASSWORD,
        autocommit=True
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                ALTER TABLE "InventoryRolls"
                ADD COLUMN IF NOT EXISTS "RollIdentifier" VARCHAR(100),
                ADD COLUMN IF NOT EXISTS "BarcodeUrl" TEXT,
                ADD COLUMN IF NOT EXISTS "RawMaterialId" INTEGER DEFAULT 4,
                ADD COLUMN IF NOT EXISTS "InitialQuantity" NUMERIC DEFAULT 500,
                ADD COLUMN IF NOT EXISTS "CurrentQuantity" NUMERIC DEFAULT 450,
                ADD COLUMN IF NOT EXISTS "ReceivedDate" TIMESTAMPTZ DEFAULT NOW(),
                ADD COLUMN IF NOT EXISTS "CreatedAt" TIMESTAMPTZ DEFAULT NOW(),
                ADD COLUMN IF NOT EXISTS "UpdatedAt" TIMESTAMPTZ DEFAULT NOW();
            """)
            cur.execute("""
                UPDATE "InventoryRolls"
                SET "RollIdentifier" = "Id",
                    "BarcodeUrl" = 'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=' || "Id",
                    "RawMaterialId" = CASE 
                        WHEN "Id" IN ('ROLL-001', 'ROLL-002') THEN 4
                        WHEN "Id" IN ('ROLL-003', 'ROLL-004') THEN 5
                        ELSE 6
                    END
                WHERE "RollIdentifier" IS NULL OR "RollIdentifier" = '';
            """)
            print("Successfully updated InventoryRolls schema and aligned with Student 1 & 3!")

if __name__ == "__main__":
    main()

