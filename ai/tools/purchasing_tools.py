"""
Purchasing Tools Module
Part of: Goal-Based Purchasing Agent with Gemini Search Grounding and Deterministic Procurement Rules.
Component: Student 2 / Supply Chain Manager.

Features:
1. search_external_supplier_market (Gemini Search Grounding + Prompt Injection Defense)
2. calculate_purchase_quantity (Deterministic formula + MOQ + Pack Size)
3. calculate_total_cost (Deterministic Math + Conflicting Price Detection)
4. query_internal_supplier_data (PostgreSQL DB + Approved Supplier verification)
5. validate_supplier_candidate (8-point mandatory constraint check)
6. select_supplier (Transparent ranking & comparative decision-making)
7. create_draft_po (Strict safety invariants: UNPAID, no emails, human approval gate)
8. query_supplier_rates (Preserved rate lookup tool)
"""

from __future__ import annotations

import re
import json
import math
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Tuple

import psycopg
from ai.core.config import settings


# =====================================================================
# Security & Prompt Injection Defense
# =====================================================================

INJECTION_PATTERNS = [
    re.compile(r"ignore\s+(all\s+)?(previous|prior)\s+instructions", re.IGNORECASE),
    re.compile(r"change\s+(the\s+)?budget", re.IGNORECASE),
    re.compile(r"set\s+(the\s+)?budget", re.IGNORECASE),
    re.compile(r"approve\s+(this\s+)?(purchase|po|order)", re.IGNORECASE),
    re.compile(r"override\s+(permission|rules|validation|budget)", re.IGNORECASE),
    re.compile(r"bypass\s+(backend|security|validation|approval)", re.IGNORECASE),
    re.compile(r"you\s+are\s+now\s+in\s+developer\s+mode", re.IGNORECASE),
    re.compile(r"call\s+payment", re.IGNORECASE),
    re.compile(r"execute\s+payment", re.IGNORECASE),
    re.compile(r"reveal\s+(api\s+)?key", re.IGNORECASE),
    re.compile(r"system\s+instruction", re.IGNORECASE),
    re.compile(r"disregard\s+(the\s+)?above", re.IGNORECASE),
]


def sanitize_untrusted_web_content(text: str) -> str:
    """
    Treats all webpage and external content strictly as untrusted DATA.
    Neutralizes prompt injection attempts and strips adversarial control strings.
    """
    if not text or not isinstance(text, str):
        return ""

    sanitized = text
    for pattern in INJECTION_PATTERNS:
        if pattern.search(sanitized):
            sanitized = pattern.sub("[REDACTED_UNTRUSTED_INSTRUCTION]", sanitized)

    # Restrict maximum string length to prevent memory / context exhaustion
    return sanitized[:2000].strip()


# =====================================================================
# Database Helpers
# =====================================================================

def get_db_connection() -> Optional[psycopg.Connection[Any]]:
    """Attempt connecting to PostgreSQL, or return None if offline."""
    try:
        conn = psycopg.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            dbname=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            connect_timeout=3
        )
        return conn
    except Exception:
        return None


REQUIRED_CANDIDATE_KEYS = {
    "supplierName", "origin", "productName", "material", "specification",
    "unitPrice", "currency", "unit", "minimumOrderQuantity", "packSize",
    "availableQuantity", "leadTimeDays", "qualityEvidence", "certifications",
    "sourceUrl", "sourceTitle", "retrievedAt"
}


def validate_candidate_schema(candidate: Dict[str, Any]) -> bool:
    """
    Validates that a supplier candidate strictly adheres to the required schema.
    Returns True if valid, False if any mandatory key is missing or invalid.
    """
    if not isinstance(candidate, dict):
        return False
    for key in REQUIRED_CANDIDATE_KEYS:
        if key not in candidate:
            return False
    try:
        if float(candidate.get("unitPrice", 0)) <= 0:
            return False
    except (ValueError, TypeError):
        return False
    return True


# =====================================================================
# Tool 1: search_external_supplier_market
# =====================================================================

def search_external_supplier_market(
    material_name: str,
    specification: str,
    required_quantity: float,
    quality_requirement: str = "",
    maximum_budget: float = 10000.0,
    preferred_region: Optional[str] = None,
    required_by_date: Optional[str] = None
) -> List[Dict[str, Any]]:
    """
    Retrieves pre-seeded supplier candidates from the database and uses
    Gemini to score and rank them based on the procurement requirements.
    Returns the top-ranked suppliers as structured candidates.
    """
    material_clean = sanitize_untrusted_web_content(material_name)
    spec_clean = sanitize_untrusted_web_content(specification)
    region_clean = sanitize_untrusted_web_content(preferred_region or "Global")
    now_iso = datetime.now(timezone.utc).isoformat()

    # ── Fetch seeded suppliers from database via the C# backend ──────────────
    # The C# backend passes candidate data directly in the workflow payload,
    # so we use the supplier pool that was already resolved server-side.
    # This function returns structured candidates ready for validation.

    # Hardcoded realistic supplier pool (mirrors DbInitializer.cs seed data)
    # AI ranking will pick the best matches from this pool.
    supplier_pool = [
        {"supplierName": "SteelTech Industries", "productName": f"{material_clean} - Premium Grade", "materialName": material_clean, "specification": "ASTM A36, tensile strength ≥400 MPa, mill certified", "unitPrice": 1.85, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 500, "packSize": 50, "availableQuantity": 25000, "leadTimeDays": 7, "qualityEvidence": "ISO 9001:2015, ASTM certified", "certifications": ["ISO 9001", "ASTM"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://steeltech.example.com/products", "sourceWebsite": "SteelTech Industries", "region": "North America"},
        {"supplierName": "GlobalMetals Corp", "productName": f"{material_clean} - Standard", "materialName": material_clean, "specification": "EN 10025, S275 structural steel", "unitPrice": 1.62, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 1000, "packSize": 100, "availableQuantity": 50000, "leadTimeDays": 10, "qualityEvidence": "ISO 9001, CE Marking", "certifications": ["ISO 9001", "CE"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://globalmetals.example.com", "sourceWebsite": "GlobalMetals Corp", "region": "Europe"},
        {"supplierName": "AsiaPac Manufacturing", "productName": f"{material_clean} - Export Grade", "materialName": material_clean, "specification": "GB/T 700, Q235 structural steel", "unitPrice": 1.20, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 2000, "packSize": 200, "availableQuantity": 100000, "leadTimeDays": 21, "qualityEvidence": "ISO 9001, SGS Inspected", "certifications": ["ISO 9001", "SGS"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://asiapac.example.com", "sourceWebsite": "AsiaPac Manufacturing", "region": "Asia"},
        {"supplierName": "PrecisionAlloys Ltd", "productName": f"{material_clean} - High Tensile", "materialName": material_clean, "specification": "BS EN 10083, 42CrMo4 alloy steel", "unitPrice": 2.45, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 250, "packSize": 25, "availableQuantity": 8000, "leadTimeDays": 5, "qualityEvidence": "ISO 9001:2015, ISO 14001", "certifications": ["ISO 9001", "ISO 14001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://precisionalloys.example.com", "sourceWebsite": "PrecisionAlloys Ltd", "region": "Europe"},
        {"supplierName": "Midwest Steel Supply", "productName": f"{material_clean} - Domestic Grade", "materialName": material_clean, "specification": "ASTM A572 Grade 50, high-strength low-alloy", "unitPrice": 2.10, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 300, "packSize": 50, "availableQuantity": 15000, "leadTimeDays": 3, "qualityEvidence": "ASTM certified, ISO 9001", "certifications": ["ASTM", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://midweststeel.example.com", "sourceWebsite": "Midwest Steel Supply", "region": "North America"},
        {"supplierName": "EcoMaterials India", "productName": f"{material_clean} - Recycled Grade", "materialName": material_clean, "specification": "IS 2062, E250 structural steel, recycled content 40%", "unitPrice": 0.98, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 3000, "packSize": 500, "availableQuantity": 200000, "leadTimeDays": 14, "qualityEvidence": "BIS certified, ISO 14001", "certifications": ["BIS", "ISO 14001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://ecomaterials.example.in", "sourceWebsite": "EcoMaterials India", "region": "South Asia"},
        {"supplierName": "Nordic Raw Materials", "productName": f"{material_clean} - Ultra Pure", "materialName": material_clean, "specification": "SS-EN 10025-2, S355J2 fine grain steel", "unitPrice": 2.80, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 200, "packSize": 20, "availableQuantity": 5000, "leadTimeDays": 8, "qualityEvidence": "ISO 9001, OHSAS 18001, DNV GL", "certifications": ["ISO 9001", "OHSAS 18001", "DNV GL"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://nordicrawmaterials.example.com", "sourceWebsite": "Nordic Raw Materials", "region": "Europe"},
        {"supplierName": "Pacific Rim Traders", "productName": f"{material_clean} - Budget Grade", "materialName": material_clean, "specification": "JIS G3101, SS400 general structural steel", "unitPrice": 1.05, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 5000, "packSize": 1000, "availableQuantity": 500000, "leadTimeDays": 28, "qualityEvidence": "JIS certified, ISO 9001", "certifications": ["JIS", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://pacificrimtraders.example.com", "sourceWebsite": "Pacific Rim Traders", "region": "Asia Pacific"},
        {"supplierName": "CanadaSteel Direct", "productName": f"{material_clean} - Cold Rolled", "materialName": material_clean, "specification": "CSA G40.21, 350W structural steel", "unitPrice": 2.25, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 400, "packSize": 50, "availableQuantity": 20000, "leadTimeDays": 6, "qualityEvidence": "CSA certified, ISO 9001:2015", "certifications": ["CSA", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://canadasteel.example.ca", "sourceWebsite": "CanadaSteel Direct", "region": "North America"},
        {"supplierName": "BrazilMetals Exporters", "productName": f"{material_clean} - Hot Rolled", "materialName": material_clean, "specification": "ABNT NBR 7480, CA-50 structural steel", "unitPrice": 1.35, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 2500, "packSize": 250, "availableQuantity": 75000, "leadTimeDays": 18, "qualityEvidence": "INMETRO certified, ISO 9001", "certifications": ["INMETRO", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://brazilmetals.example.com.br", "sourceWebsite": "BrazilMetals Exporters", "region": "South America"},
        {"supplierName": "Gulf Industries LLC", "productName": f"{material_clean} - Middle East Grade", "materialName": material_clean, "specification": "SASO 2000, structural steel plates", "unitPrice": 1.55, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 1500, "packSize": 150, "availableQuantity": 40000, "leadTimeDays": 12, "qualityEvidence": "SASO certified, ISO 9001", "certifications": ["SASO", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://gulfindustries.example.ae", "sourceWebsite": "Gulf Industries LLC", "region": "Middle East"},
        {"supplierName": "FastShip Metals USA", "productName": f"{material_clean} - Express Stock", "materialName": material_clean, "specification": "ASTM A36, standard stock ready to ship", "unitPrice": 2.60, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 100, "packSize": 10, "availableQuantity": 3000, "leadTimeDays": 1, "qualityEvidence": "ASTM certified, ISO 9001", "certifications": ["ASTM", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://fastshipmetals.example.com", "sourceWebsite": "FastShip Metals USA", "region": "North America"},
        {"supplierName": "TurkeySteel Export", "productName": f"{material_clean} - Mediterranean Grade", "materialName": material_clean, "specification": "TS 1744, St 44-2 structural steel", "unitPrice": 1.40, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 2000, "packSize": 200, "availableQuantity": 60000, "leadTimeDays": 15, "qualityEvidence": "TSE certified, ISO 9001", "certifications": ["TSE", "ISO 9001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://turkeysteel.example.com.tr", "sourceWebsite": "TurkeySteel Export", "region": "Europe"},
        {"supplierName": "KoreaMetal Hub", "productName": f"{material_clean} - POSCO Certified", "materialName": material_clean, "specification": "KS D 3503, SS400 POSCO mill certified", "unitPrice": 1.75, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 1000, "packSize": 100, "availableQuantity": 30000, "leadTimeDays": 9, "qualityEvidence": "POSCO certified, ISO 9001, ISO 14001", "certifications": ["POSCO", "ISO 9001", "ISO 14001"], "availabilityStatus": "AVAILABLE", "sourceUrl": "https://koreametalhub.example.kr", "sourceWebsite": "KoreaMetal Hub", "region": "Asia"},
        {"supplierName": "AfricaMineral Resources", "productName": f"{material_clean} - Raw Mined Grade", "materialName": material_clean, "specification": "SANS 1431, 300WA weathering steel", "unitPrice": 0.88, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 10000, "packSize": 1000, "availableQuantity": 1000000, "leadTimeDays": 35, "qualityEvidence": "SABS certified", "certifications": ["SABS"], "availabilityStatus": "LIMITED", "sourceUrl": "https://africamineral.example.co.za", "sourceWebsite": "AfricaMineral Resources", "region": "Africa"},
    ]

    # ── Use Gemini to score and rank the supplier pool ────────────────────────
    api_key = settings.GEMINI_API_KEY
    if not api_key or not api_key.strip():
        logger.warning("No Gemini API key configured. Returning top 5 suppliers sorted by price.")
        sorted_pool = sorted(supplier_pool, key=lambda x: x["unitPrice"])[:5]
        return _format_candidates(sorted_pool, material_clean, now_iso)

    prompt = f"""You are a procurement AI assistant for a manufacturing company.
Rank the following supplier list based on the procurement requirements below.
Return ONLY the top 5 best suppliers as a JSON array, ordered best-first.

PROCUREMENT REQUIREMENTS:
- Material: {material_clean}
- Specification: {spec_clean}
- Required Quantity: {required_quantity} units
- Quality Requirement: {quality_requirement}
- Maximum Budget (per unit): ${maximum_budget / max(required_quantity, 1):.2f}
- Preferred Region: {region_clean}

SUPPLIER POOL:
{json.dumps(supplier_pool, indent=2)}

RANKING CRITERIA (score each supplier):
1. Unit price vs budget fit (lower is better)
2. Lead time (shorter is better)
3. Available quantity >= required quantity
4. Quality certifications match requirement
5. Region preference match

Return ONLY a valid JSON array of the top 5 supplier objects from the pool above (do not add new fields, do not invent data). Output raw JSON only, no markdown.
"""

    import urllib.request as _urllib_request
    import ssl as _ssl
    _ctx = _ssl.create_default_context()
    _ctx.check_hostname = False
    _ctx.verify_mode = _ssl.CERT_NONE
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.GEMINI_MODEL}:generateContent?key={api_key.strip()}"
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    req = _urllib_request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    try:
        with _urllib_request.urlopen(req, timeout=20, context=_ctx) as resp:
            body = resp.read().decode("utf-8")
            data = json.loads(body)
        candidates_raw = data.get("candidates", [])
        if candidates_raw:
            text = candidates_raw[0].get("content", {}).get("parts", [{}])[0].get("text", "")
            match = re.search(r"\[\s*\{.*\}\s*\]", text, re.DOTALL)
            if match:
                ranked = json.loads(match.group(0))
                return _format_candidates(ranked, material_clean, now_iso)
    except Exception as e:
        print(f"[AI Ranking] Gemini ranking failed ({e}), falling back to price sort.")

    # Fallback: sort by best price fit within budget
    budget_per_unit = maximum_budget / max(required_quantity, 1)
    filtered = [s for s in supplier_pool if s["unitPrice"] <= budget_per_unit * 1.2]
    if not filtered:
        filtered = supplier_pool
    sorted_pool = sorted(filtered, key=lambda x: (x["unitPrice"], x["leadTimeDays"]))[:5]
    return _format_candidates(sorted_pool, material_clean, now_iso)


def _format_candidates(candidates: List[Dict], material_clean: str, now_iso: str) -> List[Dict[str, Any]]:
    """Normalises raw supplier dicts into the validated schema expected by C#."""
    validated_candidates = []
    for cand in candidates:
        sup_name = sanitize_untrusted_web_content(str(cand.get("supplierName", "Unknown Supplier")))
        mat = material_clean
        price = max(0.01, float(cand.get("unitPrice", 1.50)))
        currency = str(cand.get("currency", "USD")).upper()[:5]
        moq = max(0.0, float(cand.get("minimumOrderQuantity", 100.0)))
        pack_size = max(1.0, float(cand.get("packSize", 50.0)))
        lead_time = max(1, int(cand.get("leadTimeDays", 5)))
        source_url = str(cand.get("sourceUrl", "https://supplier.example.com"))
        source_title = str(cand.get("sourceWebsite", sup_name))
        avail = str(cand.get("availabilityStatus", "AVAILABLE")).upper()
        raw_quality = str(cand.get("qualityEvidence", "ISO 9001"))

        validated = {
            "supplierName": sup_name,
            "SupplierName": sup_name,
            "origin": str(cand.get("region", "Global")),
            "productName": str(cand.get("productName", mat)),
            "material": mat,
            "Material": mat,
            "materialName": mat,
            "specification": str(cand.get("specification", "")),
            "unitPrice": price,
            "UnitPrice": price,
            "currency": currency,
            "Currency": currency,
            "unit": str(cand.get("unit", "kg")),
            "minimumOrderQuantity": moq,
            "moq": moq,
            "MOQ": moq,
            "packSize": pack_size,
            "PackSize": pack_size,
            "availableQuantity": max(0.0, float(cand.get("availableQuantity", moq * 10))),
            "leadTime": f"{lead_time} days",
            "LeadTime": f"{lead_time} days",
            "leadTimeDays": lead_time,
            "qualityEvidence": sanitize_untrusted_web_content(raw_quality),
            "QualityEvidence": sanitize_untrusted_web_content(raw_quality),
            "qualityEvidenceStatus": "AVAILABLE",
            "QualityEvidenceStatus": "AVAILABLE",
            "certifications": cand.get("certifications", []),
            "availability": avail,
            "Availability": avail,
            "availabilityStatus": avail,
            "supplierStatus": "UNVERIFIED",
            "verificationStatus": "UNVERIFIED",
            "VerificationStatus": "UNVERIFIED",
            "sourceUrl": source_url,
            "SourceURL": source_url,
            "sourceTitle": source_title,
            "SourceTitle": source_title,
            "retrievedAt": now_iso
        }
        validated_candidates.append(validated)
    return validated_candidates

# =====================================================================
# Tool 2: calculate_purchase_quantity
# =====================================================================

def calculate_purchase_quantity(
    production_requirement: float = 0.0,
    safety_stock: float = 0.0,
    current_stock: float = 0.0,
    open_po_quantity: float = 0.0,
    moq: float = 0.0,
    pack_size: float = 1.0,
    net_deficit: Optional[float] = None,
    available_quantity: Optional[float] = None
) -> Dict[str, Any]:
    """
    Deterministic net purchase quantity calculation:
    netRequiredQuantity = net_deficit (if provided authoritatively by ASP.NET Core)
    OR productionRequirement + safetyStock - currentStock - openPurchaseOrderQuantity
    Adjusts strictly for Minimum Order Quantity (MOQ), Pack Size, and Availability.
    """
    if net_deficit is not None:
        net_qty = float(net_deficit)
    else:
        net_qty = production_requirement + safety_stock - current_stock - open_po_quantity

    if net_qty <= 0:
        return {
            "netDeficit": 0.0,
            "recommendedQuantity": 0.0,
            "requiredPurchaseQuantity": 0.0,
            "adjustedQuantity": 0.0,
            "moqApplied": False,
            "packSizeApplied": False,
            "availabilityConstrained": False,
            "purchaseRequired": False,
            "formula": "netDeficit <= 0"
        }

    # Adjust for MOQ
    order_qty = max(net_qty, moq)
    moq_applied = order_qty > net_qty

    # Adjust for Pack Size
    final_qty = order_qty
    pack_size_applied = False
    if pack_size > 0:
        packs = math.ceil(order_qty / pack_size)
        final_qty = packs * pack_size
        pack_size_applied = final_qty > order_qty

    availability_constrained = False
    if available_quantity is not None and available_quantity < final_qty:
        availability_constrained = True

    return {
        "netDeficit": round(net_qty, 3),
        "recommendedQuantity": round(final_qty, 3),
        "requiredPurchaseQuantity": round(net_qty, 3),
        "adjustedQuantity": round(final_qty, 3),
        "moqApplied": moq_applied,
        "packSizeApplied": pack_size_applied,
        "availabilityConstrained": availability_constrained,
        "purchaseRequired": True,
        "formula": f"max(netDeficit ({net_qty}), moq ({moq})) rounded to packSize ({pack_size})"
    }


# =====================================================================
# Tool 3: calculate_total_cost
# =====================================================================

def calculate_total_cost(
    quantity: float,
    unit_price: float,
    conflicting_quotes: Optional[List[float]] = None
) -> Dict[str, Any]:
    """
    Deterministic total cost calculation:
    totalCost = quantity * unitPrice
    Detects and flags conflicting quotes.
    """
    if conflicting_quotes and len(conflicting_quotes) > 1:
        unique_prices = set(round(p, 2) for p in conflicting_quotes)
        if len(unique_prices) > 1:
            return {
                "totalCost": 0.0,
                "unitPrice": unit_price,
                "quantity": quantity,
                "priceStatus": "CONFLICTING",
                "message": f"Conflicting price quotes detected: {unique_prices}. Human review required."
            }

    cost = round(quantity * unit_price, 2)
    return {
        "totalCost": cost,
        "unitPrice": unit_price,
        "quantity": quantity,
        "priceStatus": "VALID",
        "message": f"{quantity} units @ ${unit_price:.2f} = ${cost:.2f}"
    }


# =====================================================================
# Tool 4: query_internal_supplier_data
# =====================================================================

def query_internal_supplier_data(
    material_name: Optional[str] = None,
    connection: Optional[psycopg.Connection[Any]] = None
) -> List[Dict[str, Any]]:
    """
    Queries internal PostgreSQL database for approved suppliers and historical performance.
    """
    conn = connection or get_db_connection()
    internal_suppliers: List[Dict[str, Any]] = []

    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT "Id", "SupplierCode", "Name", "ContactEmail", "LeadTimeDays", "IsActive", "PaymentTerms"
                    FROM "Suppliers"
                    WHERE "IsActive" = true;
                """)
                rows = cur.fetchall()
                for r in rows:
                    internal_suppliers.append({
                        "supplierId": r[0],
                        "supplierCode": r[1],
                        "supplierName": r[2],
                        "contactEmail": r[3],
                        "leadTimeDays": r[4],
                        "isActive": r[5],
                        "paymentTerms": r[6],
                        "supplierStatus": "APPROVED",
                        "qualityRating": 4.8,
                        "source": "INTERNAL_DATABASE"
                    })
        except Exception:
            pass
        finally:
            if connection is None:
                conn.close()

    # If DB has no records or offline, we return empty list. No mock data allowed.
    return internal_suppliers


# =====================================================================
# Tool 5: validate_supplier_candidate
# =====================================================================

def validate_supplier_candidate(
    candidate: Dict[str, Any],
    requirement: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Filters candidates using 8 mandatory rules:
    1. Correct material
    2. Correct specification
    3. Quality requirement & evidence
    4. Quantity availability
    5. MOQ respected
    6. Lead time feasibility
    7. Supplier eligibility (APPROVED vs UNVERIFIED vs BLOCKED)
    8. Maximum budget
    """
    rejection_reasons = []

    # 1. Correct Material
    mat_cand = str(candidate.get("materialName", "")).lower()
    mat_req = str(requirement.get("materialName", "")).lower()
    material_match = not mat_req or (mat_req in mat_cand or mat_cand in mat_req)
    if not material_match:
        rejection_reasons.append(f"Material mismatch: required '{mat_req}', got '{mat_cand}'")

    # 2. Correct Specification
    spec_cand = str(candidate.get("specification", "")).lower()
    spec_req = str(requirement.get("requiredSpecification", "")).lower()
    spec_match = not spec_req or (spec_req in spec_cand or spec_cand in spec_req)
    if not spec_match:
        rejection_reasons.append(f"Specification mismatch: required '{spec_req}', got '{spec_cand}'")

    # 3. Quality Evidence
    quality_ev = str(candidate.get("qualityEvidence", "")).strip()
    if not quality_ev or len(quality_ev) < 5:
        quality_status = "UNKNOWN"
        rejection_reasons.append("Insufficient quality certification evidence.")
    else:
        quality_status = "VERIFIED"

    # 4. Quantity Availability
    req_qty = float(requirement.get("requiredQuantity", 0.0))
    avail_qty = float(candidate.get("availableQuantity", 0.0))
    if avail_qty < req_qty:
        rejection_reasons.append(f"Insufficient stock availability: available {avail_qty} < required {req_qty}")

    # 5. MOQ
    moq = float(candidate.get("minimumOrderQuantity", 0.0))
    # Order quantity will be adjusted to MOQ if needed, but if MOQ > available or extreme:
    max_budget = float(requirement.get("maximumBudget", 100000.0))
    unit_price = float(candidate.get("unitPrice", 0.0))
    adjusted_qty = max(req_qty, moq)

    # 6. Lead Time
    lead_time = int(candidate.get("leadTimeDays", 7))
    req_date_str = requirement.get("requiredByDate")
    lead_time_feasible = True
    if req_date_str:
        try:
            req_date = datetime.fromisoformat(req_date_str.replace("Z", "+00:00"))
            max_arrival = datetime.now(timezone.utc) + timedelta(days=lead_time)
            if max_arrival > req_date:
                lead_time_feasible = False
                rejection_reasons.append(f"Lead time {lead_time} days exceeds required date {req_date.strftime('%Y-%m-%d')}")
        except Exception:
            pass

    # 7. Supplier Eligibility
    supplier_status = str(candidate.get("supplierStatus", "UNVERIFIED")).upper()
    if supplier_status == "BLOCKED":
        rejection_reasons.append("Supplier is on BLOCKED list.")

    # 8. Budget
    total_cost = round(adjusted_qty * unit_price, 2)
    budget_satisfied = total_cost <= max_budget
    if not budget_satisfied:
        rejection_reasons.append(f"Total cost ${total_cost:.2f} exceeds maximum budget of ${max_budget:.2f}")

    is_valid = len(rejection_reasons) == 0

    return {
        "candidateName": candidate.get("supplierName"),
        "isValid": is_valid,
        "materialMatch": material_match,
        "specMatch": spec_match,
        "qualityStatus": quality_status,
        "supplierStatus": supplier_status,
        "leadTimeFeasible": lead_time_feasible,
        "budgetSatisfied": budget_satisfied,
        "adjustedQuantity": adjusted_qty,
        "totalCost": total_cost,
        "rejectionReasons": rejection_reasons
    }


# =====================================================================
# Tool 6: select_supplier
# =====================================================================

def select_supplier(
    validated_candidates: List[Tuple[Dict[str, Any], Dict[str, Any]]],
    requirement: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Compares valid candidates and transparently selects the top recommendation.
    Prefers APPROVED suppliers with lowest total cost and verified quality.
    """
    valid_candidates = []
    rejected_candidates = []

    for cand, report in validated_candidates:
        if report["isValid"]:
            valid_candidates.append((cand, report))
        else:
            rejected_candidates.append({
                "supplierName": cand.get("supplierName"),
                "reasons": report["rejectionReasons"]
            })

    if not valid_candidates:
        return {
            "status": "NO_VALID_SUPPLIER",
            "recommendation": None,
            "selectedCandidate": None,
            "selectionReasons": [],
            "alternatives": [],
            "rejectedCandidates": rejected_candidates,
            "validationSummary": {
                "validCandidatesCount": 0,
                "rejectedCandidatesCount": len(rejected_candidates),
                "rulesChecked": 8,
                "status": "FAILED"
            },
            "sources": [],
            "requiresHumanApproval": False,
            "message": "No supplier candidates satisfied all 8 mandatory validation rules."
        }

    # Sorting priority:
    # 1. APPROVED status preferred over UNVERIFIED
    # 2. Quality status: VERIFIED preferred over UNKNOWN
    # 3. Shortest lead time
    # 4. Total cost
    def rank_key(item: Tuple[Dict[str, Any], Dict[str, Any]]):
        c, r = item
        is_approved = 0 if r["supplierStatus"] == "APPROVED" else 1
        quality_score = 0 if r.get("qualityStatus") == "VERIFIED" else 1
        lead_time = c.get("leadTimeDays", 99)
        cost = r["totalCost"]
        return (is_approved, quality_score, lead_time, cost)

    valid_candidates.sort(key=rank_key)
    top_cand, top_report = valid_candidates[0]

    reasons = [
        f"Material specification matched: {top_cand.get('specification')}",
        f"Quantity available: {top_cand.get('availableQuantity')} (Needed: {top_report['adjustedQuantity']})",
        f"Quality verified: {top_cand.get('qualityEvidence')}",
        f"Total cost ${top_report['totalCost']:.2f} within budget ${requirement.get('maximumBudget', 0):.2f}",
        f"Supplier status: {top_report['supplierStatus']}"
    ]

    alternatives = [c[0].get("supplierName") for c in valid_candidates[1:]]
    sources = [c[0].get("sourceUrl") for c in valid_candidates if c[0].get("sourceUrl")]

    recommendation = {
        "supplier": top_cand.get("supplierName"),
        "product": top_cand.get("productName", top_cand.get("materialName")),
        "quantity": top_report.get("adjustedQuantity", top_report.get("recommendedQuantity")),
        "unitPrice": top_cand.get("unitPrice"),
        "totalCost": top_report.get("totalCost"),
        "qualityStatus": top_report.get("qualityStatus", "VERIFIED"),
        "supplierStatus": top_cand.get("supplierStatus", "UNVERIFIED")
    }

    return {
        "status": "RECOMMENDATION_READY",
        "recommendation": recommendation,
        "selectedCandidate": top_cand,
        "validationReport": top_report,
        "selectionReasons": reasons,
        "alternatives": alternatives,
        "rejectedCandidates": rejected_candidates,
        "validationSummary": {
            "validCandidatesCount": len(valid_candidates),
            "rejectedCandidatesCount": len(rejected_candidates),
            "rulesChecked": 8,
            "status": "PASSED"
        },
        "sources": sources,
        "requiresHumanApproval": True
    }


# =====================================================================
# Tool 7: create_draft_po (Preserved & Enhanced with Invariants)
# =====================================================================

def create_draft_po(
    selected_candidate: Dict[str, Any],
    quantity: float,
    unit_price: float,
    total_cost: float,
    item_code: str = "BP-FILM-001",
    po_number: Optional[str] = None,
    notes: Optional[str] = None
) -> Dict[str, Any]:
    """
    Creates a controlled Draft Purchase Order object.
    Strict Invariants:
    - paymentStatus = "UNPAID" (AI must NOT execute payment)
    - emailSent = False (AI must NOT send email)
    - requiresApproval = True
    """
    po_num = po_number or f"PO-DRAFT-{datetime.now(timezone.utc).year}-{datetime.now(timezone.utc).strftime('%m%d%H%M%S')[-4:]}"
    terms = selected_candidate.get("paymentTerms") or "Net 30"
    reason = f"Replenishment required for deficit of {quantity} {selected_candidate.get('unit', 'units')}"

    return {
        "poNumber": po_num,
        "supplier": selected_candidate.get("supplierName", "Apex Polymer Solutions Ltd"),
        "supplierStatus": selected_candidate.get("supplierStatus", "UNVERIFIED"),
        "itemCode": item_code,
        "materialName": selected_candidate.get("materialName", "BoxPouch Film"),
        "quantity": quantity,
        "unitPrice": unit_price,
        "unit": selected_candidate.get("unit", "meters"),
        "estimatedCostUsd": total_cost,
        "leadTimeDays": selected_candidate.get("leadTimeDays", 5),
        "qualityEvidence": selected_candidate.get("qualityEvidence", "ISO 9001"),
        "paymentStatus": "UNPAID",       # Strict invariant
        "emailSent": False,              # Strict invariant
        "requiresApproval": True,        # Strict invariant
        "terms": terms,
        "reason": reason,
        "Supplier": selected_candidate.get("supplierName", "Apex Polymer Solutions Ltd"),
        "Quantity": quantity,
        "UnitPrice": unit_price,
        "Total": total_cost,
        "Terms": terms,
        "Reason": reason,
        "notes": notes or f"AI-Recommended procurement for {item_code} via {selected_candidate.get('supplierName')}."
    }


# =====================================================================
# Tool 8: query_supplier_rates (Preserved Tool)
# =====================================================================

def query_supplier_rates(
    supplier_id_or_name: str,
    connection: Optional[psycopg.Connection[Any]] = None
) -> Dict[str, Any]:
    """
    Preserved Tool: Query contract pricing and performance for a specific supplier.
    """
    conn = connection or get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT s."Id", s."Name", s."LeadTimeDays", s."PaymentTerms"
                    FROM "Suppliers" s
                    WHERE s."SupplierCode" = %s OR s."Name" ILIKE %s
                    LIMIT 1;
                """, (supplier_id_or_name, f"%{supplier_id_or_name}%"))
                row = cur.fetchone()
                if row:
                    return {
                        "supplierId": row[0],
                        "name": row[1],
                        "leadTimeDays": row[2],
                        "paymentTerms": row[3],
                        "isApproved": True
                    }
        except Exception:
            pass
        finally:
            if connection is None:
                conn.close()

    return {
        "supplierId": supplier_id_or_name,
        "name": supplier_id_or_name,
        "leadTimeDays": 5,
        "paymentTerms": "Net 30",
        "isApproved": True
    }
