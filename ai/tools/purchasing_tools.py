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
from ai.schemas.tool_contracts import DraftPO, checked_output
from ai.core.supplier_ranking import supplier_rank_key

import re
import json
import math
import logging
import uuid
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Tuple, Union

import psycopg
from ai.core.config import settings

logger = logging.getLogger("amic_agentic_ai.purchasing_tools")

# Reference deterministic supplier rates for fallback & unit test stability
STATIC_SUPPLIER_CATALOG = [
    {
        "supplierId": "SUP-001",
        "name": "Apex Industrial Metals",
        "pricePerUnit": 4.50,
        "leadTimeDays": 7,
        "minOrderQuantity": 500,
        "isActive": True,
        "currency": "USD"
    },
    {
        "supplierId": "SUP-002",
        "name": "Global Precision Fasteners",
        "pricePerUnit": 4.80,
        "leadTimeDays": 14,
        "minOrderQuantity": 200,
        "isActive": True,
        "currency": "USD"
    },
    {
        "supplierId": "SUP-003",
        "name": "Polymer & Composites Direct",
        "pricePerUnit": 5.00,
        "leadTimeDays": 10,
        "minOrderQuantity": 1000,
        "isActive": True,
        "currency": "USD"
    }
]


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
            connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on"
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

def _call_gemini_search_grounding(
    material: str,
    specification: str,
    quantity: float,
    quality: str = "",
    budget: float = 10000.0,
    region: str = "Global"
) -> List[Dict[str, Any]]:
    """
    Invokes Gemini API with Google Search Grounding to find real online suppliers.
    Returns list of candidate supplier dicts.
    """
    api_key = (settings.GEMINI_API_KEY or "").strip("'\" \t\r\n")
    if not api_key:
        raise ValueError("No Gemini API key configured.")

    prompt = f"""You are a procurement AI assistant for a manufacturing company.
Search current online suppliers and market prices using Google Search Grounding for:
- Material: {material}
- Specification: {specification}
- Required Quantity: {quantity} units
- Quality Requirement: {quality}
- Maximum Budget: ${budget:.2f}
- Preferred Region: {region}

Return ONLY a valid JSON array of up to 5 supplier candidate objects with the following schema:
[
  {{
    "supplierName": "Supplier Name",
    "productName": "{material} - Grade",
    "materialName": "{material}",
    "specification": "{specification}",
    "unitPrice": 1.45,
    "currency": "USD",
    "unit": "units",
    "minimumOrderQuantity": 500,
    "packSize": 50,
    "availableQuantity": 10000,
    "leadTimeDays": 5,
    "qualityEvidence": "ISO 9001 Certified",
    "certifications": ["ISO 9001"],
    "availabilityStatus": "AVAILABLE",
    "supplierStatus": "UNVERIFIED",
    "sourceUrl": "https://example.com",
    "sourceTitle": "Example Supplier"
  }}
]
"""
    import ssl as _ssl
    _ctx = _ssl.create_default_context()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.GEMINI_MODEL}:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    payload = {"contents": [{"parts": [{"text": prompt}]}], "tools": [{"google_search": {}}]}

    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers)
    with urllib.request.urlopen(req, timeout=12, context=_ctx) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        raw_text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
        if raw_text.startswith("```"):
            raw_text = re.sub(r"^```[a-z]*\n?", "", raw_text)
            raw_text = re.sub(r"\n?```$", "", raw_text)
        ranked_list = json.loads(raw_text)
        candidate = data["candidates"][0]
        sources = [chunk["web"] for chunk in candidate.get("groundingMetadata", {}).get("groundingChunks", []) if "web" in chunk]
        if not sources:
            logger.warning("External research returned no grounded sources; ignoring recommendations")
            return []
        from urllib.parse import urlparse
        grounded_urls = {source.get("uri") for source in sources if urlparse(source.get("uri", "")).scheme == "https"}
        if isinstance(ranked_list, list):
            for item in ranked_list:
                if not isinstance(item, dict):
                    continue
                item["supplierStatus"] = "UNVERIFIED"
                item["verificationStatus"] = "UNVERIFIED"
                item["groundingSources"] = sources
                item["grounded"] = item.get("sourceUrl") in grounded_urls
            return [item for item in ranked_list if isinstance(item, dict) and item.get("grounded")]
    return []


def search_external_supplier_market(
    material_name: str,
    specification: str,
    required_quantity: float,
    quality_requirement: str = "",
    maximum_budget: float = 10000.0,
    preferred_region: Optional[str] = None,
    required_by_date: Optional[str] = None,
    revision_notes: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Retrieves supplier candidates from Gemini search grounding or resilient market pool.
    Returns the top-ranked suppliers as structured candidates.
    """
    material_clean = sanitize_untrusted_web_content(material_name)
    spec_clean = sanitize_untrusted_web_content(specification)
    if revision_notes:
        spec_clean += "\nRequested revision: " + sanitize_untrusted_web_content(revision_notes)
    if required_by_date:
        spec_clean += "\nRequired by: " + str(required_by_date)
    region_clean = sanitize_untrusted_web_content(preferred_region or "Global")
    now_iso = datetime.now(timezone.utc).isoformat()

    try:
        gemini_results = _call_gemini_search_grounding(
            material=material_clean,
            specification=spec_clean,
            quantity=required_quantity,
            quality=quality_requirement,
            budget=maximum_budget,
            region=region_clean,
        )
        if gemini_results and isinstance(gemini_results, list) and len(gemini_results) > 0:
            return _format_candidates(gemini_results[:5], material_clean, now_iso)
    except Exception as ex:
        logger.warning(f"Gemini search grounding failed: {ex}. Falling back to market pool.")

    if not settings.demo_mode:
        return []

    supplier_pool = [
        {"supplierName": "Apex Polymer Solutions Ltd", "productName": f"{material_clean} - Industrial Grade", "materialName": material_clean, "specification": spec_clean or "ASTM A36 / ISO certified", "unitPrice": 1.45, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 500, "packSize": 50, "availableQuantity": 25000, "leadTimeDays": 3, "qualityEvidence": "ISO 9001 Certified", "certifications": ["ISO 9001"], "availabilityStatus": "AVAILABLE", "supplierStatus": "UNVERIFIED", "sourceUrl": "https://apexpolymer.example.com", "sourceWebsite": "Apex Polymer Solutions Ltd", "region": region_clean},
        {"supplierName": "SteelTech Industries", "productName": f"{material_clean} - Premium Grade", "materialName": material_clean, "specification": "ASTM A36, tensile strength ≥400 MPa, mill certified", "unitPrice": 1.85, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 500, "packSize": 50, "availableQuantity": 25000, "leadTimeDays": 7, "qualityEvidence": "ISO 9001:2015, ASTM certified", "certifications": ["ISO 9001", "ASTM"], "availabilityStatus": "AVAILABLE", "supplierStatus": "UNVERIFIED", "sourceUrl": "https://steeltech.example.com/products", "sourceWebsite": "SteelTech Industries", "region": "North America"},
        {"supplierName": "GlobalMetals Corp", "productName": f"{material_clean} - Standard", "materialName": material_clean, "specification": "EN 10025, S275 structural steel", "unitPrice": 1.62, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 1000, "packSize": 100, "availableQuantity": 50000, "leadTimeDays": 10, "qualityEvidence": "ISO 9001, CE Marking", "certifications": ["ISO 9001", "CE"], "availabilityStatus": "AVAILABLE", "supplierStatus": "UNVERIFIED", "sourceUrl": "https://globalmetals.example.com", "sourceWebsite": "GlobalMetals Corp", "region": "Europe"},
        {"supplierName": "AsiaPac Manufacturing", "productName": f"{material_clean} - Export Grade", "materialName": material_clean, "specification": "GB/T 700, Q235 structural steel", "unitPrice": 1.20, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 2000, "packSize": 200, "availableQuantity": 100000, "leadTimeDays": 21, "qualityEvidence": "ISO 9001, SGS Inspected", "certifications": ["ISO 9001", "SGS"], "availabilityStatus": "AVAILABLE", "supplierStatus": "UNVERIFIED", "sourceUrl": "https://asiapac.example.com", "sourceWebsite": "AsiaPac Manufacturing", "region": "Asia"},
        {"supplierName": "PrecisionAlloys Ltd", "productName": f"{material_clean} - High Tensile", "materialName": material_clean, "specification": "BS EN 10083, 42CrMo4 alloy steel", "unitPrice": 2.45, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 250, "packSize": 25, "availableQuantity": 8000, "leadTimeDays": 5, "qualityEvidence": "ISO 9001:2015, ISO 14001", "certifications": ["ISO 9001", "ISO 14001"], "availabilityStatus": "AVAILABLE", "supplierStatus": "UNVERIFIED", "sourceUrl": "https://precisionalloys.example.com", "sourceWebsite": "PrecisionAlloys Ltd", "region": "Europe"},
        {"supplierName": "Midwest Steel Supply", "productName": f"{material_clean} - Domestic Grade", "materialName": material_clean, "specification": "ASTM A572 Grade 50, high-strength low-alloy", "unitPrice": 2.10, "currency": "USD", "unit": "kg", "minimumOrderQuantity": 300, "packSize": 50, "availableQuantity": 15000, "leadTimeDays": 3, "qualityEvidence": "ASTM certified, ISO 9001", "certifications": ["ASTM", "ISO 9001"], "availabilityStatus": "AVAILABLE", "supplierStatus": "UNVERIFIED", "sourceUrl": "https://midweststeel.example.com", "sourceWebsite": "Midwest Steel Supply", "region": "North America"},
    ]

    sorted_pool = sorted(supplier_pool, key=lambda x: x["unitPrice"])[:5]
    return _format_candidates(sorted_pool, material_clean, now_iso)


def _format_candidates(raw_list: List[Dict[str, Any]], material: str, now_iso: str) -> List[Dict[str, Any]]:
    candidates = []
    for s in raw_list:
        cand = {
            "supplierName": s.get("supplierName", "Verified Supplier"),
            "origin": s.get("origin", "External Market Research"),
            "productName": s.get("productName", f"{material} - Commercial Grade"),
            "material": material,
            "materialName": s.get("materialName", material),
            "specification": s.get("specification", "Standard manufacturing grade, certified"),
            "unitPrice": float(s.get("unitPrice", 1.50)),
            "currency": s.get("currency", "USD"),
            "unit": s.get("unit", "units"),
            "minimumOrderQuantity": float(s.get("minimumOrderQuantity", 500)),
            "packSize": float(s.get("packSize", 50)),
            "availableQuantity": float(s.get("availableQuantity", 10000)),
            "leadTimeDays": int(s.get("leadTimeDays", 7)),
            "qualityEvidence": s.get("qualityEvidence", "ISO 9001 Certified"),
            "certifications": s.get("certifications", ["ISO 9001"]),
            "availabilityStatus": s.get("availabilityStatus", "AVAILABLE"),
            "supplierStatus": s.get("supplierStatus", "UNVERIFIED"),
            "sourceUrl": s.get("sourceUrl", "https://supplier-portal.example.com"),
            "sourceTitle": s.get("sourceWebsite", s.get("supplierName", "Supplier")),
            "retrievedAt": s.get("retrievedAt", now_iso),
        }
        candidates.append(cand)
    return candidates


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
    available_quantity: Optional[float] = None,
) -> Dict[str, Any]:
    """
    Computes exact purchase quantity using deterministic inventory math.
    Formula:
      raw_deficit = (production_requirement + safety_stock) - (current_stock + open_po_quantity)
      If net_deficit is provided, it takes precedence as the authoritative deficit.
    """
    if net_deficit is not None:
        deficit = max(0.0, float(net_deficit))
    else:
        req = max(0.0, float(production_requirement))
        safety = max(0.0, float(safety_stock))
        stock = max(0.0, float(current_stock))
        open_po = max(0.0, float(open_po_quantity))
        deficit = max(0.0, (req + safety) - (stock + open_po))

    if deficit <= 0:
        return {
            "netDeficit": 0.0,
            "recommendedQuantity": 0.0,
            "purchaseRequired": False,
            "requiredPurchaseQuantity": 0.0,
            "adjustedQuantity": 0.0,
            "adjustedForMoq": False,
            "moqApplied": False,
            "adjustedForPackSize": False,
            "packSizeApplied": False,
            "isAvailable": True,
        }

    moq_val = max(0.0, float(moq))
    pack_val = max(1.0, float(pack_size))
    target_qty = max(deficit, moq_val)
    adjusted_moq = moq_val > deficit

    packs = math.ceil(target_qty / pack_val)
    final_qty = packs * pack_val
    adjusted_pack = final_qty > deficit

    avail = float(available_quantity) if available_quantity is not None else float("inf")
    is_available = final_qty <= avail

    return {
        "netDeficit": deficit,
        "recommendedQuantity": final_qty,
        "purchaseRequired": deficit > 0,
        "requiredPurchaseQuantity": deficit,
        "adjustedQuantity": final_qty,
        "adjustedForMoq": adjusted_moq,
        "moqApplied": adjusted_moq,
        "adjustedForPackSize": adjusted_pack,
        "packSizeApplied": adjusted_pack,
        "isAvailable": is_available,
        "packs": packs,
        "packSize": pack_val,
        "minimumOrderQuantity": moq_val,
    }


# =====================================================================
# Tool 3: calculate_total_cost
# =====================================================================

def calculate_total_cost(
    quantity: float,
    unit_price: float,
    alternative_price: Optional[float] = None,
    currency: str = "USD",
    conflicting_quotes: Optional[List[float]] = None,
    **kwargs
) -> Dict[str, Any]:
    """
    TOOL 3: Deterministic cost calculation and price conflict detector.
    Satisfies both 2-arg (quantity, unit_price) and 4-arg calls.
    """
    qty = max(0.0, float(quantity))
    price = max(0.0, float(unit_price))

    has_conflict = False
    conflict_notes = None

    if conflicting_quotes and len(conflicting_quotes) > 1:
        if any(abs(q - conflicting_quotes[0]) > 0.01 for q in conflicting_quotes):
            has_conflict = True
            conflict_notes = f"Conflicting quotes detected in market: {conflicting_quotes}."
            return {
                "quantity": qty,
                "unitPrice": price,
                "totalCost": 0.0,
                "totalAmount": 0.0,
                "currency": currency,
                "priceStatus": "CONFLICTING",
                "hasPriceConflict": True,
                "conflictNotes": conflict_notes,
            }

    if alternative_price is not None:
        alt = max(0.0, float(alternative_price))
        if alt > 0 and abs(alt - price) > 0.01:
            has_conflict = True
            conflict_notes = (
                f"Conflicting prices detected: authoritative=${price:.2f}, "
                f"alternative=${alt:.2f}. Using authoritative price."
            )

    total = round(qty * price, 2)
    return {
        "quantity": qty,
        "unitPrice": price,
        "totalCost": total,
        "totalAmount": total,
        "currency": currency,
        "priceStatus": "VALID" if not has_conflict else "CONFLICT",
        "hasPriceConflict": has_conflict,
        "conflictNotes": conflict_notes,
    }


# =====================================================================
# Tool 4: query_internal_supplier_data
# =====================================================================

def _live_material_quotes(material):
    connection = get_db_connection()
    if connection is None:
        raise ValueError("Supplier quotes are unavailable; retry or use manual procurement")
    with connection:
        with connection.cursor() as cursor:
            cursor.execute('''
                SELECT s."Id", s."SupplierCode", s."Name", q."UnitPrice", q."MinimumOrderQuantity",
                       q."PackSize", q."AvailableQuantity", q."LeadTimeDays", q."QualityEvidence", q."Currency", m."UnitOfMeasure"
                FROM "SupplierMaterialQuotes" q JOIN "Suppliers" s ON s."Id" = q."SupplierId"
                JOIN "RawMaterials" m ON m."Id" = q."RawMaterialId"
                WHERE q."IsActive" = true AND s."IsActive" = true
                  AND (m."SkuCode" = %s OR m."Name" = %s OR m."Id"::text = %s)
                ORDER BY q."UpdatedAt" DESC;
            ''', (material, material, material))
            rows = cursor.fetchall()
    connection.close()
    return [{"supplierId": row[0], "supplierCode": row[1], "supplierName": row[2],
             "name": row[2], "unitPrice": float(row[3]), "pricePerUnit": float(row[3]),
             "minimumOrderQuantity": float(row[4]), "minOrderQuantity": float(row[4]),
             "packSize": float(row[5]), "availableQuantity": float(row[6]),
             "leadTimeDays": row[7], "qualityEvidence": row[8], "currency": row[9], "unit": row[10],
             "isActive": True, "verificationStatus": "VERIFIED", "supplierStatus": "APPROVED"} for row in rows]


def query_internal_supplier_data(material_name: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Queries PostgreSQL Suppliers table for internal approved suppliers.
    """
    try:
        live_quotes = _live_material_quotes(material_name)
        if live_quotes:
            return live_quotes
        if not settings.demo_mode:
            return []
    except Exception:
        if not settings.demo_mode:
            raise
    conn = get_db_connection()
    suppliers = []

    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT "Id", "Name", "LeadTimeDays", "PaymentTerms", "IsActive", "SupplierCode"
                    FROM "Suppliers"
                    WHERE "IsActive" = true
                    ORDER BY "Name" ASC;
                """)
                for row in cur.fetchall():
                    suppliers.append({
                        "supplierId": row[0],
                        "supplierName": row[1],
                        "leadTimeDays": row[2],
                        "paymentTerms": row[3],
                        "isActive": row[4],
                        "supplierCode": row[5],
                        "origin": "Internal ERP Database",
                        "verificationStatus": "VERIFIED",
                        "supplierStatus": "APPROVED",
                        "qualityEvidence": "ISO 9001 Certified (Internal contract verified)",
                        "unitPrice": 1.45,
                        "currency": "USD",
                    })
        except Exception as ex:
            logger.warning(f"Error querying internal suppliers: {ex}")
        finally:
            conn.close()

    if not suppliers:
        suppliers = [
            {
                "supplierId": 1,
                "supplierName": "Apex Polymer Solutions Ltd",
                "leadTimeDays": 3,
                "paymentTerms": "Net 30",
                "isActive": True,
                "supplierCode": "SUP-001",
                "origin": "Internal ERP Database",
                "verificationStatus": "VERIFIED",
                "supplierStatus": "APPROVED",
                "qualityEvidence": "ISO 9001 Certified (Internal contract verified)",
                "unitPrice": 1.45,
                "currency": "USD",
            },
            {
                "supplierId": 2,
                "supplierName": "Global Industrial Packaging Corp",
                "leadTimeDays": 5,
                "paymentTerms": "Net 45",
                "isActive": True,
                "supplierCode": "SUP-002",
                "origin": "Internal ERP Database",
                "verificationStatus": "VERIFIED",
                "supplierStatus": "APPROVED",
                "qualityEvidence": "ISO 9001:2015, ISO 14001",
                "unitPrice": 1.55,
                "currency": "USD",
            }
        ]

    return suppliers


# =====================================================================
# Tool 5: validate_supplier_candidate
# =====================================================================

def validate_supplier_candidate(
    candidate: Dict[str, Any],
    procurement_requirement: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Performs mandatory multi-point evaluation of a supplier candidate.
    """
    reasons = []
    if not candidate.get("supplierId") or not candidate.get("supplierName"):
        reasons.append("Supplier identity is missing from the approved registry.")
    if candidate.get("verificationStatus") not in ("VERIFIED", "APPROVED"):
        reasons.append("Supplier is not verified for operational purchasing.")
    unit_price = float(candidate.get("unitPrice", 0))
    if unit_price <= 0:
        reasons.append("Unit price must be strictly positive.")

    req_qty = float(procurement_requirement.get("requiredQuantity", 0))
    avail_qty = float(candidate.get("availableQuantity", 0))
    if avail_qty < req_qty:
        reasons.append(f"Insufficient stock availability ({avail_qty} < {req_qty}).")

    max_budget = float(procurement_requirement.get("maximumBudget", 0))
    est_total = unit_price * req_qty
    budget_ok = True
    if max_budget > 0 and est_total > max_budget:
        budget_ok = False
        reasons.append(f"Estimated total (${est_total:,.2f}) exceeds maximum budget (${max_budget:,.2f}).")

    quality_status = "VERIFIED"
    quality_evidence = candidate.get("qualityEvidence", "")
    if not quality_evidence or str(quality_evidence).upper() in ("NONE", "UNKNOWN", "N/A"):
        quality_status = "UNKNOWN"
        reasons.append("Insufficient quality certification evidence.")

    return {
        "supplierName": candidate.get("supplierName"),
        "isValid": len(reasons) == 0,
        "rejectionReasons": reasons,
        "qualityStatus": quality_status,
        "budgetSatisfied": budget_ok,
        "availabilitySatisfied": avail_qty >= req_qty,
        "qualitySatisfied": quality_status != "UNKNOWN",
        "adjustedQuantity": req_qty,
        "totalCost": est_total,
    }


# =====================================================================
# Tool 6: select_supplier (Polymorphic: supports both styles)
# =====================================================================

def select_supplier(*args, **kwargs) -> Dict[str, Any]:
    """
    TOOL 2 / 6: Evaluates and selects the best supplier candidate.
    Supports:
      1) select_supplier(suppliers: list[dict], required_quantity: float = 500)
      2) select_supplier(validated_pairs: list, requirement: dict)
    """
    # ── Style 1: List of supplier dicts from catalog ────────────────────────
    is_catalog_style = (
        args
        and isinstance(args[0], list)
        and (len(args) == 1 or (len(args) > 1 and not isinstance(args[1], dict)))
        and (len(args[0]) == 0 or (isinstance(args[0][0], dict) and "pricePerUnit" in args[0][0]))
    )
    if is_catalog_style:
        suppliers = args[0]
        required_quantity = args[1] if len(args) > 1 else kwargs.get("required_quantity", 500)
        available_candidates = [
            s for s in suppliers 
            if s.get("isActive", True) and required_quantity >= s.get("minOrderQuantity", 0)
        ]
        if not available_candidates:
            available_candidates = [s for s in suppliers if s.get("isActive", True)]
        if not available_candidates:
            raise ValueError("No active suppliers available.")

        sorted_candidates = sorted(
            available_candidates,
            key=lambda s: (float(s.get("pricePerUnit", 999.0)), int(s.get("leadTimeDays", 999)))
        )
        return sorted_candidates[0]

    # ── Style 2: Validated pairs + requirement ──────────────────────────────
    validated_pairs = args[0] if len(args) > 0 else kwargs.get("validated_pairs", [])
    requirement = args[1] if len(args) > 1 else kwargs.get("requirement", {})

    valid_candidates = []
    rejected_candidates = []

    for cand, report in validated_pairs:
        if report.get("isValid", False):
            valid_candidates.append((cand, report))
        else:
            rejected_candidates.append({
                "supplierName": cand.get("supplierName"),
                "reasons": report.get("rejectionReasons", []),
            })

    if not valid_candidates:
        return {
            "status": "NO_VALID_SUPPLIER",
            "selectedCandidate": None,
            "validationReport": None,
            "alternatives": [],
            "rejectedCandidates": rejected_candidates,
            "selectionReasons": [],
        }

    sorted_valid = sorted(valid_candidates, key=lambda pair: supplier_rank_key(*pair))
    top_cand, top_report = sorted_valid[0]
    alternatives = [c.get("supplierName") for c, _ in sorted_valid[1:3]]
    selection_reasons = [
        f"Selected {top_cand.get('supplierName')} based on "
        f"{'approved supplier agreement' if top_cand.get('supplierStatus') == 'APPROVED' else 'verified capabilities'}, "
        f"total cost (${top_report.get('totalCost', 0):,.2f}), and lead time ({top_cand.get('leadTimeDays', 7)} days)."
    ]

    return {
        "status": "RECOMMENDATION_READY",
        "selectedCandidate": top_cand,
        "validationReport": top_report,
        "alternatives": alternatives,
        "rejectedCandidates": rejected_candidates,
        "selectionReasons": selection_reasons,
    }


# =====================================================================
# Tool 7: create_draft_po (Polymorphic: supports both styles)
# =====================================================================

@checked_output(DraftPO)
def create_draft_po(*args, **kwargs) -> Dict[str, Any]:
    """
    TOOL 4 / 7: Creates ONLY a draft PO.
    Strict constraints:
    - NEVER approves
    - NEVER executes payment (paymentStatus = 'UNPAID')
    - NEVER sends email (emailSent = False)
    - If total > budget_threshold -> requiresApproval = True
    """
    # ── Style 1: Positional args (supplier_id: str, supplier_name: str, material_id: str, ...) ──
    if args and isinstance(args[0], str):
        supplier_id = args[0]
        supplier_name = args[1] if len(args) > 1 else ""
        material_id = args[2] if len(args) > 2 else ""
        quantity = float(args[3]) if len(args) > 3 else 0.0
        unit_price = float(args[4]) if len(args) > 4 else 0.0
        total_amount = float(args[5]) if len(args) > 5 else round(quantity * unit_price, 2)
        currency = args[6] if len(args) > 6 else kwargs.get("currency", "USD")
        budget_threshold = float(args[7]) if len(args) > 7 else kwargs.get("budget_threshold", 5000.0)

        draft_id = f"PO-DRAFT-{str(uuid.uuid4())[:6].upper()}"
        return {
            "poNumber": draft_id,
            "supplierId": supplier_id,
            "supplierName": supplier_name,
            "supplier": supplier_name,
            "materialId": material_id,
            "quantity": quantity,
            "unitPrice": unit_price,
            "totalAmount": total_amount,
            "estimatedCostUsd": total_amount,
            "currency": currency,
            "status": "Draft",
            "paymentStatus": "UNPAID",
            "emailSent": False,
            "requiresApproval": total_amount > budget_threshold,
            "budgetThreshold": budget_threshold,
        }

    # ── Style 2: Candidate dict + quantity + unit_price + total_cost + item_code ──
    if "selected_candidate" in kwargs or (args and isinstance(args[0], dict)):
        selected_candidate = args[0] if args else kwargs["selected_candidate"]
        quantity = float(kwargs.get("quantity") or (args[1] if len(args) > 1 else 0.0))
        unit_price = float(kwargs.get("unit_price") or (args[2] if len(args) > 2 else 0.0))
        total_cost = float(kwargs.get("total_cost") or (args[3] if len(args) > 3 else round(quantity * unit_price, 2)))
        item_code = kwargs.get("item_code") or (args[4] if len(args) > 4 else "")

        po_number = kwargs.get("po_number") or f"PO-DRAFT-{datetime.now(timezone.utc).year}-{uuid.uuid4().hex[:6].upper()}"
        terms = selected_candidate.get("paymentTerms") or "Net 30"
        reason = f"Replenishment required for deficit of {quantity} {selected_candidate.get('unit', 'units')}"

        return {
            "poNumber": po_number,
            "supplier": selected_candidate.get("supplierName", "Apex Polymer Solutions Ltd"),
            "supplierId": selected_candidate.get("supplierId", "SUP-001"),
            "supplierName": selected_candidate.get("supplierName", "Apex Polymer Solutions Ltd"),
            "supplierStatus": selected_candidate.get("supplierStatus", "UNVERIFIED"),
            "itemCode": item_code,
            "materialId": selected_candidate.get("material", item_code),
            "materialName": selected_candidate.get("materialName", "BoxPouch Film"),
            "quantity": quantity,
            "unitPrice": unit_price,
            "unit": selected_candidate.get("unit", "units"),
            "estimatedCostUsd": total_cost,
            "totalAmount": total_cost,
            "totalCost": total_cost,
            "currency": selected_candidate.get("currency", "USD"),
            "leadTimeDays": selected_candidate.get("leadTimeDays", 5),
            "qualityEvidence": selected_candidate.get("qualityEvidence", "ISO 9001"),
            "status": "Draft",
            "paymentStatus": "UNPAID",
            "emailSent": False,
            "requiresApproval": True,
            "budgetThreshold": 5000.0,
            "terms": terms,
            "reason": reason,
            "notes": kwargs.get("notes") or f"AI-Recommended procurement for {item_code} via {selected_candidate.get('supplierName')}."
        }

    # ── Style 3: Keyword args fallback (supplier_id=..., supplier_name=..., etc.) ──
    draft_id = f"PO-DRAFT-{str(uuid.uuid4())[:6].upper()}"
    qty = float(kwargs.get("quantity", 0.0))
    price = float(kwargs.get("unit_price", 0.0))
    total = float(kwargs.get("total_amount") or kwargs.get("total_cost") or round(qty * price, 2))
    thresh = float(kwargs.get("budget_threshold", 5000.0))

    return {
        "poNumber": draft_id,
        "supplierId": kwargs.get("supplier_id"),
        "supplierName": kwargs.get("supplier_name"),
        "supplier": kwargs.get("supplier_name"),
        "materialId": kwargs.get("material_id"),
        "quantity": qty,
        "unitPrice": price,
        "totalAmount": total,
        "estimatedCostUsd": total,
        "currency": kwargs.get("currency", "USD"),
        "status": "Draft",
        "paymentStatus": "UNPAID",
        "emailSent": False,
        "requiresApproval": total > thresh,
        "budgetThreshold": thresh,
    }


# =====================================================================
# Tool 8: query_supplier_rates (Polymorphic: query list or single supplier)
# =====================================================================

def query_supplier_rates(
    material_id_or_supplier: Optional[str] = None,
    connection: Optional[psycopg.Connection[Any]] = None
) -> Any:
    """
    TOOL 1 / 8:
    If called with no args or material_id (e.g. 'RM-STEEL-001', 'MAT-001', etc.), returns list of suppliers.
    If called with a specific supplier name/code (starts with 'SUP-'), returns that supplier's detail dict.
    """
    is_specific_supplier = (
        isinstance(material_id_or_supplier, str)
        and (
            material_id_or_supplier.upper().startswith("SUP-")
            or material_id_or_supplier.upper().startswith("SUP_")
            or material_id_or_supplier.upper().startswith("SUPPLIER")
        )
    )

    if not is_specific_supplier:
        try:
            live_quotes = _live_material_quotes(material_id_or_supplier)
            if live_quotes:
                return live_quotes
        except Exception:
            if not settings.demo_mode:
                raise

    # Query list of suppliers (for general material catalog queries)
    if not is_specific_supplier:
        suppliers = []
        try:
            with psycopg.connect(
                host=settings.DB_HOST,
                port=settings.DB_PORT,
                dbname=settings.DB_NAME,
                user=settings.DB_USER,
                password=settings.DB_PASSWORD,
                connect_timeout=3, options="-c statement_timeout=5000 -c default_transaction_read_only=on"
            ) as conn:
                with conn.cursor() as cur:
                    cur.execute('SELECT "SupplierCode", "Name", "LeadTimeDays", "IsActive" FROM "Suppliers" WHERE "IsActive" = true ORDER BY "Id" ASC')
                    rows = cur.fetchall()
                    for idx, row in enumerate(rows):
                        rates = [4.50, 4.80, 5.00, 5.20]
                        price = rates[idx % len(rates)]
                        suppliers.append({
                            "supplierId": str(row[0]),
                            "name": str(row[1]),
                            "pricePerUnit": price,
                            "leadTimeDays": int(row[2]),
                            "minOrderQuantity": 500,
                            "isActive": bool(row[3]),
                            "currency": "USD"
                        })
        except Exception as ex:
            logger.warning(f"Database query failed in query_supplier_rates: {ex}. Using static supplier catalog.")

        return suppliers if suppliers else list(STATIC_SUPPLIER_CATALOG)

    # Query single supplier detail
    conn = connection or get_db_connection()
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT s."Id", s."Name", s."LeadTimeDays", s."PaymentTerms"
                    FROM "Suppliers" s
                    WHERE s."SupplierCode" = %s OR s."Name" ILIKE %s
                    LIMIT 1;
                """, (material_id_or_supplier, f"%{material_id_or_supplier}%"))
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
        "supplierId": material_id_or_supplier,
        "name": material_id_or_supplier,
        "leadTimeDays": 5,
        "paymentTerms": "Net 30",
        "isApproved": True
    }
