from ai.tools.purchasing_tools import create_draft_po
from ai.routes.workflow_routes import RunWorkflowRequest
from ai.tests.test_handoff_contracts import pipeline


def test_request_defaults_to_lkr_and_preserves_explicit_legacy_currency():
    assert RunWorkflowRequest(objective='Replenish film').currency == 'LKR'
    assert RunWorkflowRequest(objective='Legacy purchase', currency='USD').currency == 'USD'


def test_lkr_draft_amount_and_approval_threshold():
    draft = create_draft_po(supplier_id='SUP-1', material_id='RM-1', quantity=2000, unit_price=1350, total_amount=2700000)
    assert draft['currency'] == 'LKR'
    assert draft['totalAmount'] == 2700000
    assert draft['budgetThreshold'] == 1500000
    assert draft['requiresApproval'] is True
    assert draft['paymentStatus'] == 'UNPAID'
    assert draft['emailSent'] is False


def test_lkr_is_preserved_across_real_cooperating_nodes(pipeline):
    # The fixture runs real nodes with controlled external boundaries, not demo fallbacks.
    from ai.graph import workflow
    request, received, quote, _ = pipeline
    request['procurement_requirement'] = {'currency': 'LKR'}
    quote['currency'] = 'LKR'
    quote['unitPrice'] = 1350
    request['budget_limit'] = 100000
    result = workflow.run_workflow(**request)
    assert result['draft_po']['currency'] == 'LKR'
    assert result['draft_po']['totalAmount'] == 27000
    assert result['validation_results']['isValid'] is True
    assert result['requires_approval'] is True
    assert received['validation_node']['draft_po']['currency'] == 'LKR'


def test_foreign_quote_cannot_be_compared_to_an_lkr_budget(pipeline):
    from ai.graph import workflow
    request, _, quote, _ = pipeline
    quote['currency'] = 'USD'
    request['procurement_requirement'] = {'currency': 'LKR'}
    result = workflow.run_workflow(**request)
    assert result['requires_approval'] is False
    assert result['draft_po'] is None
