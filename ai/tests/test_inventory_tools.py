import unittest
from ai.tools.inventory_tools import (
    get_inventory_levels,
    query_inventory_history,
    calculate_burn_rate,
    detect_low_stock,
)
from ai.graph import run_data_extraction_workflow
from ai.persistence import workflow_repo


class TestInventoryToolsGoldenCases(unittest.TestCase):
    """
    Test suite verifying the 4 allow-listed inventory tools,
    golden test cases, safe failure handling, and Data Extraction output.
    """

    def setUp(self):
        workflow_repo.clear()

    # ── GOLDEN CASES ──────────────────────────────────────────────────────────

    def test_golden_case_1_days_remaining(self):
        """
        GOLDEN CASE 1:
        Input: Stock = 350, Burn rate = 80
        Expected: Days remaining = 4.375 (350 / 80 = 4.375)
        """
        result = detect_low_stock.invoke({
            "currentStock": 350.0,
            "minimumStock": 200.0,
            "burnRate": 80.0,
            "supplierLeadTime": 3.0,
            "materialId": "RM001"
        })
        self.assertEqual(result["materialId"], "RM001")
        self.assertAlmostEqual(result["daysRemaining"], 4.375, places=3)
        self.assertTrue(result["lowStock"])

    def test_golden_case_2_low_stock_detection(self):
        """
        GOLDEN CASE 2:
        Input: Stock = 50, Minimum = 200
        Expected: Low stock = true
        """
        result = detect_low_stock.invoke({
            "currentStock": 50.0,
            "minimumStock": 200.0,
            "burnRate": 80.0,
            "supplierLeadTime": 3.0,
            "materialId": "RM001"
        })
        self.assertTrue(result["lowStock"])
        self.assertEqual(result["severity"], "CRITICAL")

    def test_golden_case_3_zero_burn_rate_safe_failure(self):
        """
        GOLDEN CASE 3:
        Input: Burn rate = 0
        Expected: No division error, safe output returned.
        """
        try:
            result = detect_low_stock.invoke({
                "currentStock": 350.0,
                "minimumStock": 200.0,
                "burnRate": 0.0,
                "supplierLeadTime": 3.0,
                "materialId": "RM001"
            })
            self.assertIsNotNone(result)
            self.assertEqual(result["daysRemaining"], 999.0)
            # Since stock 350 > min 200 and burn rate 0, lowStock is false
            self.assertFalse(result["lowStock"])
        except ZeroDivisionError:
            self.fail("detect_low_stock raised ZeroDivisionError on burnRate = 0!")

    # ── TOOL SPECIFIC UNIT TESTS ──────────────────────────────────────────────

    def test_tool_1_get_inventory_levels(self):
        """TOOL 1: Verify get_inventory_levels returns structured data."""
        result = get_inventory_levels.invoke({"materialId": "RM001"})
        self.assertIn("materialId", result)
        self.assertIn("currentStock", result)
        self.assertIn("minimumStock", result)
        self.assertIn("maximumStock", result)
        self.assertEqual(result["currentStock"], 350.0)
        self.assertEqual(result["minimumStock"], 200.0)
        self.assertEqual(result["maximumStock"], 1000.0)

    def test_tool_2_query_inventory_history(self):
        """TOOL 2: Verify query_inventory_history returns historical consumption."""
        result = query_inventory_history.invoke({"materialId": "RM001", "periodDays": 7})
        self.assertEqual(result["materialId"], "RM001")
        self.assertEqual(result["periodDays"], 7)
        self.assertEqual(result["consumption"], 560.0)

    def test_tool_3_calculate_burn_rate(self):
        """TOOL 3: Verify calculate_burn_rate returns daily rate."""
        result = calculate_burn_rate.invoke({
            "consumption": 560.0,
            "periodDays": 7,
            "materialId": "RM001"
        })
        self.assertEqual(result["materialId"], "RM001")
        self.assertEqual(result["burnRate"], 80.0)

    def test_tool_3_division_by_zero_safe_failure(self):
        """TOOL 3 SAFE FAILURE: Verify periodDays <= 0 does not raise ZeroDivisionError."""
        try:
            result = calculate_burn_rate.invoke({
                "consumption": 560.0,
                "periodDays": 0,
                "materialId": "RM001"
            })
            self.assertEqual(result["burnRate"], 0.0)
        except ZeroDivisionError:
            self.fail("calculate_burn_rate raised ZeroDivisionError on periodDays = 0!")

    # ── DATA EXTRACTION AGENT OUTPUT SPECIFICATION ───────────────────────────

    def test_data_extraction_agent_structured_result(self):
        """
        Verify Data Extraction Agent produces exact required schema:
        {
          "materialId": "RM001",
          "currentStock": 350,
          "burnRate": 80,
          "daysRemaining": 4.37,
          "lowStock": true,
          "requiredQuantity": 2000
        }
        """
        state = run_data_extraction_workflow("RM001")
        extraction = state.get("data_extraction_result")

        self.assertIsNotNone(extraction, "Data extraction result must be present in state.")
        self.assertEqual(extraction["materialId"], "RM001")
        self.assertEqual(extraction["currentStock"], 350.0)
        self.assertEqual(extraction["burnRate"], 80.0)
        self.assertAlmostEqual(extraction["daysRemaining"], 4.375, places=2)
        self.assertTrue(extraction["lowStock"])
        self.assertEqual(extraction["requiredQuantity"], 2000.0)

        # Check tool execution summary is recorded
        summary = state.get("tool_execution_summary")
        self.assertGreaterEqual(len(summary), 4)
        tool_names = [s["tool"] for s in summary]
        self.assertIn("get_inventory_levels", tool_names)
        self.assertIn("query_inventory_history", tool_names)
        self.assertIn("calculate_burn_rate", tool_names)
        self.assertIn("detect_low_stock", tool_names)

    # ── PERSISTENCE & SECURITY SPECIFICATION ─────────────────────────────────

    def test_persistence_stores_sanitized_record_without_chain_of_thought(self):
        """Verify workflow persistence stores required metadata without hidden chain-of-thought."""
        state = run_data_extraction_workflow("RM001", "WF-TEST-001")
        saved = workflow_repo.save_workflow(state)

        # Verify permitted fields
        self.assertEqual(saved["workflowId"], "WF-TEST-001")
        self.assertIn("inventoryResult", saved)
        self.assertIn("toolExecutionSummary", saved)
        self.assertIn("lowStockResult", saved)
        self.assertIn("timestamps", saved)
        self.assertIn("errors", saved)

        # CRITICAL: Chain-of-thought and raw message objects MUST NOT be stored
        self.assertNotIn("messages", saved)
        self.assertNotIn("raw_reasoning", saved)
        self.assertNotIn("chain_of_thought", saved)
        self.assertNotIn("db_password", saved)
        self.assertNotIn("apiKey", saved)


if __name__ == "__main__":
    unittest.main()

