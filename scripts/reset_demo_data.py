"""Explicit, transactional local demo reset. Preserves users and schema history.

Run --prepare to create and verify backups. Run --apply --backup-dir PATH only
after services are stopped. No payments, emails or AI workflows are executed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid5, NAMESPACE_URL

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import psycopg
from psycopg import sql
from ai.core.config import settings

NOW = datetime.now(timezone.utc).replace(hour=8, minute=0, second=0, microsecond=0)
DATA = {}
def uid(label): return uuid5(NAMESPACE_URL, 'amic-professional-demo/' + label)
def add(table, **values): DATA.setdefault(table, []).append(values)
def money(value): return Decimal(str(value)).quantize(Decimal('.01'))
def user_digest(conn):
    rows = conn.execute('SELECT row_to_json(u)::text FROM "Users" u ORDER BY "Id"').fetchall()
    return hashlib.sha256(json.dumps(rows).encode()).hexdigest(), len(rows)

def build_data(conn):
    users = dict(conn.execute('SELECT "Role", "Id" FROM "Users" WHERE "IsActive" ORDER BY "CreatedAt"').fetchall())
    worker = users.get('FloorWorker'); manager = users.get('SupplyChainManager')
    qa = users.get('QualityInspector'); admin = users.get('ITAdmin')
    employee = conn.execute('SELECT "EmployeeId" FROM "Users" WHERE "Id"=%s', (worker,)).fetchone()
    employee = employee[0] if employee and employee[0] else 'DEMO-FLOOR'
    packs = [('Box Pouch','BP','BoxPouch'), ('Biscuit Packaging','BIS','BiscuitPackaging'),
             ('Tea Bag','TB','TeaBag'), ('Bag','BAG','Bag'), ('Can','CAN','Can'),
             ('Bottle','BTL','Bottle'), ('Standard Roll','SR','StandardRoll')]
    for i,(name,code,_) in enumerate(packs,1): add('PackagingTypes',Id=i,Name=name,ShortCode=code,IsActive=True)
    # Current stock, safety threshold, actual daily consumption and unit price.
    materials = [
      ('BP-LAM-001','Laminated Barrier Film',1,'LAM','KG',640,180,18,4.5),
      ('BP-INK-001','Water-based Flexographic Ink',1,'INK','KG',60,90,3,8.4),
      ('BIS-MOP-001','Metallized OPP Film',2,'MOP','KG',780,220,20,3.8),
      ('BIS-INK-001','Food-safe Printing Ink',2,'INK','KG',110,75,2,9.2),
      ('TB-FIL-001','Heat-sealable Filter Paper',3,'FIL','ROLL',180,60,4,24),
      ('TB-THR-001','Cotton Tag Thread',3,'THR','SPOOL',90,45,2,6.8),
      ('BAG-LDP-001','Food-grade LDPE Film',4,'LDP','KG',480,160,12,2.6),
      ('CAN-TIN-001','Lacquered Tinplate Sheet',5,'TIN','SHEET',320,140,8,1.9),
      ('BTL-PET-001','Food-grade PET Preform',6,'PET','UNITS',2400,500,60,.18),
      ('SR-KRF-001','Kraft Paper Liner',7,'KRF','ROLL',125,50,2,18.5),
      ('BP-LAM-002','High-barrier Pouch Film',1,'LAM','KG',95,180,6,5.1),
      ('BIS-MOP-002','Printed Metallized OPP Film',2,'MOP','KG',510,220,10,4.2)]
    # Illustrative LKR demo pricing, not a current FX rate or market-price claim.
    materials = [(*m[:8], money(m[8] * 300)) for m in materials]
    for i,(sku,name,pid,code,unit,stock,minimum,daily,price) in enumerate(materials,1):
        add('RawMaterials',Id=i,SkuCode=sku,Name=name,Description=f'{name} for {packs[pid-1][0].lower()} production; approved packaging grade.',Category=packs[pid-1][2],UnitOfMeasure=unit,ReorderThreshold=minimum,CreatedAt=NOW-timedelta(days=90),UpdatedAt=NOW,MaterialCode=code,PackagingTypeId=pid)
        add('InventoryItems',Id=i,Sku=sku,Name=name,Category=packs[pid-1][2],StockLevel=stock,ReorderThreshold=minimum,PackagingTypeId=pid,RawMaterialId=i,SkuNumber=int(sku[-3:]))
        batch=f'BATCH-{NOW:%Y%m}-RM{i:02d}'
        add('Batches',Id=batch,ProductType=packs[pid-1][2])
        opening=stock+30*daily
        add('InventoryMovements',Id=i*100,RawMaterialId=i,RollIdentifier=f'ROLL-RM{i:02d}-A',TransactionType='OPENING',Quantity=opening,PreviousStock=0,NewStock=opening,Reason='Demo opening count reconciled to physical warehouse stock',CreatedAt=NOW-timedelta(days=31))
        for day in range(30):
            previous=opening-day*daily
            add('InventoryMovements',Id=i*100+day+1,RawMaterialId=i,RollIdentifier=f'ROLL-RM{i:02d}-A',TransactionType='CONSUMED',Quantity=daily,PreviousStock=previous,NewStock=previous-daily,Reason=f'Packaging shift material issue: {name}',CreatedAt=NOW-timedelta(days=29-day))
        for part in range(2):
            roll=f'ROLL-RM{i:02d}-{"AB"[part]}'
            quantity=stock//2 if part==0 else stock-stock//2
            initial=quantity+30*daily if part==0 else quantity
            quarantined=i==12 and part==1
            add('InventoryRolls',Id=i*2-1+part,RawMaterialId=i,BarcodeUrl='',RollIdentifier=roll,InitialQuantity=initial,CurrentQuantity=quantity,Status='Quarantined' if quarantined else 'In Stock',ReceivedDate=NOW-timedelta(days=31),CreatedAt=NOW-timedelta(days=31),UpdatedAt=NOW,BatchId=batch)
            add('QualityInventoryRolls',Id=roll,BatchId=batch,Status='Quarantined' if quarantined else 'Available')
        add('StockLevels',Id=i,RawMaterialId=i,TotalQuantity=stock,Notes='Reconciled physical count; quarantine remains excluded from production allocation.',RecordedAt=NOW)
        if stock<minimum:
            qty=max(500,minimum*2-stock)
            add('StockAlerts',Id=len(DATA.get('StockAlerts',[]))+1,Sku=sku,PackagingType=packs[pid-1][0],QuantityRequested=qty,WorkerId=employee,Status='Pending',Timestamp=NOW-timedelta(hours=1),MaterialId=i,MaterialName=name,CurrentStock=stock,RequiredQuantity=qty,SafetyStock=minimum,OpenPurchaseQuantity=0,NetDeficit=qty,Severity='Critical' if stock<=minimum/2 else 'Low',IsRead=False)
    suppliers=[('Ceylon Flexible Packaging','CFP','Colombo',4),('Lanka Industrial Materials','LIM','Gampaha',6),('Southern Paper & Packaging','SPP','Galle',5),('Apex Container Supplies','ACS','Kurunegala',7)]
    for i,(name,code,city,lead) in enumerate(suppliers,1):
        add('Suppliers',Id=i,Name=name,ContactEmail=f'orders@{code.lower()}.example',ContactPhone=f'+94 11 555 01{i:02d}',Address=f'{20+i*7} Industrial Estate Road, {city}, Sri Lanka',IsActive=True,CreatedAt=NOW-timedelta(days=180),UpdatedAt=NOW,LeadTimeDays=lead,PaymentTerms='Net 30',SupplierCode=f'SUP-{code}-001')
    for i,m in enumerate(materials,1):
        for sid in range(1,5):
            add('SupplierMaterialQuotes',Id=(i-1)*4+sid,SupplierId=sid,RawMaterialId=i,UnitPrice=money(m[8]*(1+(sid-1)*.06)),MinimumOrderQuantity=10 if m[4] in ('ROLL','SPOOL') else 100,PackSize=10 if m[4] in ('ROLL','SPOOL') else 25,AvailableQuantity=10000,LeadTimeDays=suppliers[sid-1][3],QualityEvidence='Demo specification: ISO 9001 quality process; food-contact material declaration and batch certificate available.',Currency='LKR',IsActive=True,UpdatedAt=NOW-timedelta(days=2))
    machine_specs=[('Pouch Form-Fill-Seal Line 01','Operational',360,500,'Hall A'),('Biscuit Flow Wrapper 02','Operational',210,400,'Hall B'),('Tea Bag Packing Line 03','Operational',480,500,'Hall C'),('Flexographic Printer 04','UnderMaintenance',515,500,'Print Room'),('Bottle Filling Line 05','Offline',120,600,'Hall D')]
    for i,(name,status,uptime,interval,location) in enumerate(machine_specs,1):
        add('Machines',Id=uid(f'machine-{i}'),Name=name,Status=status,UptimeHours=uptime,MaintenanceIntervalHours=interval,Location=location,CreatedAt=NOW-timedelta(days=365),UpdatedAt=NOW)
        add('MaintenanceLogs',Id=uid(f'service-{i}'),MachineId=uid(f'machine-{i}'),Description='Bearing inspection, lubrication and safety interlock test completed.' if i!=4 else 'Scheduled print-cylinder alignment and drive-bearing replacement in progress.',PerformedBy='Demo Maintenance Team',PerformedAt=NOW-timedelta(days=14 if i!=4 else 1),Type='Preventive' if i!=4 else 'Scheduled',CreatedAt=NOW-timedelta(days=14 if i!=4 else 1))
    for i,(mid,target,available,perunit,status,actual,days) in enumerate([(1,10000,640,.05,'Completed',9800,-2),(3,12000,780,.05,'Completed',11600,-1),(5,10000,180,.01,'Planned',0,1),(11,5000,95,.04,'Planned',0,2)],1):
        adjusted=min(target,int(available/ perunit))
        add('Shifts',Id=uid(f'shift-{i}'),Name=f'{materials[mid-1][1]} - {"Morning" if i%2 else "Afternoon"} Shift',MaterialSku=materials[mid-1][0],MachineId=uid(f'machine-{1 if mid in (1,11) else 2 if mid==3 else 3}'),MaterialPerUnit=Decimal(str(perunit)),ProductionTarget=target,AvailableMaterial=available,AdjustedOutput=adjusted,ActualOutput=min(actual,adjusted),Status=status,StartTime=NOW+timedelta(days=days),EndTime=NOW+timedelta(days=days,hours=8),CreatedAt=NOW-timedelta(days=7),UpdatedAt=NOW)
    defects=[(12,'B','HIGH','Edge delamination detected during incoming inspection; batch held for supplier disposition.','InReview'),(3,'A','MEDIUM','Print registration offset found on sample; rework and follow-up inspection completed.','Resolved'),(4,'A','LOW','Outer drum label was faded; identification label replaced.','Closed')]
    for i,(mid,part,severity,description,status) in enumerate(defects,1):
        roll=f'ROLL-RM{mid:02d}-{part}'
        add('DefectReports',Id=uid(f'defect-{i}'),BatchId=f'BATCH-{NOW:%Y%m}-RM{mid:02d}',ProductType=packs[materials[mid-1][2]-1][2],Severity=severity,Description=description,CreatedAt=NOW-timedelta(days=3+i),Status=status,ReportedByUserId=qa,AffectedInventoryJson=json.dumps([roll]),SkuCode=materials[mid-1][0])
        if i<=2: add('Quarantines',Id=uid(f'quarantine-{i}'),DefectReportId=uid(f'defect-{i}'),InventoryRollId=roll,Reason=description,Status='Active' if i==1 else 'Released',CreatedAt=NOW-timedelta(days=3+i),ReleasedAt=None if i==1 else NOW-timedelta(days=2))
    order_specs=[(1,1,400,'PendingApproval'),(10,3,100,'Draft'),(5,3,80,'Approved'),(7,2,300,'InTransit'),(9,4,1000,'Completed'),(8,4,200,'Rejected')]
    for i,(mid,sid,quantity,status) in enumerate(order_specs,1):
        price=money(materials[mid-1][8]*(1+(sid-1)*.06)); total=price*quantity
        approved=status in ('Approved','InTransit','Completed')
        created=NOW-timedelta(days=12 if status=='Completed' else 5)
        add('PurchaseOrders',Id=i,PoNumber=f'PO-DEMO-{NOW:%Y%m}-{i:04d}',SupplierId=sid,Status=status,Notes='Synthetic demonstration order; no external payment or email was made.',RejectionReason='Packaging specification revised before authorization.' if status=='Rejected' else None,TotalCost=total,BudgetLimit=3000000,ApprovalThreshold=1500000,RequiresApproval=True,ApprovedById=manager if approved else None,ApprovedAt=created+timedelta(days=1) if approved else None,CreatedAt=created,UpdatedAt=NOW,CreatedById=manager,Currency='LKR',TrackingStatus='Delivered' if status=='Completed' else 'InTransit' if status=='InTransit' else 'Pending',ExpectedDeliveryDate=NOW+timedelta(days=3) if status=='InTransit' else None,ActualDeliveryDate=NOW-timedelta(days=4) if status=='Completed' else None,TrackingNumber=f'DEMO-TRACK-{i:04d}' if status in ('InTransit','Completed') else None,DeliveryRemarks='Demo receipt verified against packing list.' if status=='Completed' else None,IsAcknowledgedByScm=approved,IsQualityVerified=status=='Completed',IsFinancialVerified=status in ('InTransit','Completed'),CompletedAt=NOW-timedelta(days=3) if status=='Completed' else None,StripePaymentStatus='succeeded' if status in ('InTransit','Completed') else None,EmailStatus='DemoRecorded' if status in ('InTransit','Completed') else None)
        add('OrderLines',Id=i,PurchaseOrderId=i,RawMaterialId=mid,Description=materials[mid-1][1],Quantity=quantity,UnitPrice=price,TotalPrice=total,CreatedAt=created,UpdatedAt=NOW)
        if approved or status=='Rejected': add('PurchaseOrderApprovals',Id=i,PurchaseOrderId=i,Action='Approve' if approved else 'Reject',UserId=manager,UserName='Demo Supply Chain Review',Notes='Synthetic approval history for demonstration.',Timestamp=created+timedelta(days=1))
        if status in ('InTransit','Completed'): add('PaymentTransactions',Id=i,PurchaseOrderId=i,TransactionId=f'DEMO-PAYMENT-{i:04d}',Amount=total,Currency='LKR',PaymentStatus='Succeeded',Timestamp=created+timedelta(days=2))
        if status=='Completed':
            roll='ROLL-PET-RECEIPT-001'; batch=f'BATCH-{NOW:%Y%m}-DELIVERY-001'
            # Transfer 1,000 units of PET stock into a received batch, keeping total stock unchanged.
            original=[r for r in DATA['InventoryRolls'] if r['RollIdentifier']=='ROLL-RM09-B'][0]
            original['InitialQuantity']-=1000; original['CurrentQuantity']-=1000
            add('Batches',Id=batch,ProductType='Bottle')
            add('InventoryRolls',Id=25,RawMaterialId=mid,BarcodeUrl='',RollIdentifier=roll,InitialQuantity=quantity,CurrentQuantity=quantity,Status='In Stock',ReceivedDate=NOW-timedelta(days=4),CreatedAt=NOW-timedelta(days=4),UpdatedAt=NOW,BatchId=batch)
            add('QualityInventoryRolls',Id=roll,BatchId=batch,Status='Available')
            add('GoodsReceipts',Id=uid('receipt-1'),PurchaseOrderId=i,OrderLineId=i,ReceiptKey='DEMO-RECEIPT-PET-001',RollIdentifier=roll,BatchId=batch,Quantity=quantity,ReceivedById=worker,ReceivedAt=NOW-timedelta(days=4))
            # Record receipt before consumption begins, rather than double-counting stock.
            opening_row=[r for r in DATA['InventoryMovements'] if r['RawMaterialId']==mid and r['TransactionType']=='OPENING'][0]
            opening_row['Quantity']-=quantity; opening_row['NewStock']-=quantity
            add('InventoryMovements',Id=mid*100+40,RawMaterialId=mid,RollIdentifier=roll,TransactionType='RECEIVED',Quantity=quantity,PreviousStock=opening_row['NewStock'],NewStock=opening_row['NewStock']+quantity,Reason='Demo completed PO receipt reconciled to stock ledger',CreatedAt=NOW-timedelta(days=31)+timedelta(hours=1))
            # Receipt timeline must agree with its goods receipt and physical roll.
            DATA['GoodsReceipts'][-1]['ReceivedAt']=NOW-timedelta(days=31)+timedelta(hours=1)
            DATA['InventoryRolls'][-1]['ReceivedDate']=DATA['GoodsReceipts'][-1]['ReceivedAt']
            DATA['InventoryRolls'][-1]['CreatedAt']=DATA['GoodsReceipts'][-1]['ReceivedAt']
            DATA['PurchaseOrders'][-1]['CreatedAt']=NOW-timedelta(days=40)
            DATA['PurchaseOrders'][-1]['ApprovedAt']=NOW-timedelta(days=39)
            DATA['PurchaseOrders'][-1]['ActualDeliveryDate']=DATA['GoodsReceipts'][-1]['ReceivedAt']
            DATA['PurchaseOrders'][-1]['CompletedAt']=NOW-timedelta(days=30)
            DATA['OrderLines'][-1]['CreatedAt']=NOW-timedelta(days=40)
            DATA['PurchaseOrderApprovals'][-1]['Timestamp']=NOW-timedelta(days=39)
            DATA['PaymentTransactions'][-1]['Timestamp']=NOW-timedelta(days=38)
    # A coherent recommendation example, with the same price as the linked PO.
    add('ProcurementRequests',Id=1,RawMaterialId=1,RequiredSpecification='Food-grade laminated barrier film',ProductionRequirement=860,CurrentStock=640,SafetyStock=180,ExistingOpenPoQuantity=0,CalculatedNetQuantity=400,MaximumBudget=3000000,RequiredByDate=NOW+timedelta(days=7),QualityRequirement='Food-contact declaration and batch certificate',PreferredRegion='Sri Lanka',Status='DraftPoCreated',WorkflowId='WF-DEMO-PROCUREMENT-001',MaterialName=materials[0][1],RecommendedSupplierId=1,GeneratedPurchaseOrderId=1,CreatedById=manager,CreatedAt=NOW-timedelta(days=5),UpdatedAt=NOW,Priority='Normal')
    DATA['PurchaseOrders'][0]['ProcurementRequestId']=1
    for sid in range(1,4):
        price=money(1350*(1+(sid-1)*.06))
        add('SupplierCandidates',Id=sid,ProcurementRequestId=1,SupplierId=sid,SupplierName=suppliers[sid-1][0],MaterialName=materials[0][1],UnitPrice=price,Currency='LKR',MinimumOrderQuantity=100,PackSize=25,LeadTimeDays=suppliers[sid-1][3],QualityEvidence='Demo food-contact declaration and ISO 9001 quality evidence',Availability='In Stock',SupplierStatus='Active',ConfidenceScore=Decimal('.95'),SourceUrl=f'https://{suppliers[sid-1][1].lower()}.example/catalogue',IsValidated=True,ValidationRemarks='Price, stock, currency and specification checks passed.',RecommendedOrderQuantity=400,TotalCost=price*400,CreatedAt=NOW-timedelta(days=5))
    add('ProcurementOutcomes',Id=1,Material=materials[8][1],RequestedQuantity=1000,RecommendedQuantity=1000,FinalOrderedQuantity=1000,RecommendedSupplier=suppliers[3][0],SelectedSupplier=suppliers[3][0],EstimatedPrice=float(DATA['PurchaseOrders'][4]['TotalCost']),FinalPrice=float(DATA['PurchaseOrders'][4]['TotalCost']),EstimatedLeadTime=7,ActualLeadTime=9,QualityEvidence='Demo receipt inspection passed.',SupplierVerification='Verified demo supplier',ManagerDecision='Approved',ProcurementSuccess=True,PaymentSuccess=True,DeliverySuccess=True,CreatedAt=NOW-timedelta(days=30))
    for sid in range(1,5):
        orders=[o for o in DATA['PurchaseOrders'] if o['SupplierId']==sid and o['Status'] not in ('Draft','Rejected')]
        total=sum(o['TotalCost'] for o in orders)
        add('SupplierPerformances',Id=sid,SupplierId=sid,OrderCount=len(orders),TotalSpending=total,AverageOrderValue=total/len(orders) if orders else 0,AverageLeadTime=9 if sid==4 else suppliers[sid-1][3],DeliveryPerformanceRate=100 if sid==4 else 0,RejectionRate=50 if sid==4 else 0,CalculatedAt=NOW)
    validations={'valid':True,'riskLevel':'LOW','reason':'Demo supplier, quantity, total, budget and quarantine checks passed.'}
    state={'workflow_id':'WF-DEMO-PROCUREMENT-001','objective':'Replenish 400 KG of laminated barrier film for next week production.','status':'WaitingForApproval','workflow_type':'Procurement','current_agent':'Human Approval','approval_status':'Pending','completed_steps':['Planner: Prepared replenishment plan','Data Extraction: Checked physical stock and 30-day consumption','Purchasing: Compared three active suppliers and prepared draft','Validation/Safety: Supplier, budget and quarantine checks passed'],'inventory_data':{'materialId':'BP-LAM-001','currentStock':640,'burnRate':18,'daysRemaining':640/18,'requiredQuantity':400},'validation_results':validations,'errors':[]}
    # Historical demo workflow is terminal; pending orders remain ordinary drafts.
    # This avoids presenting an invented AI session as a resumable live workflow.
    state.update(workflow_id='WF-DEMO-COMPLETED-001', objective='Replenish 1,000 PET preforms for beverage packaging.', status='Completed', current_agent='Execution', approval_status='Approved', final_outcome='Demo completed purchase and receipt; no external payment or email was made.')
    state['inventory_data']={'materialId':'BTL-PET-001','currentStock':2400,'burnRate':60,'daysRemaining':40,'requiredQuantity':1000}
    state['completed_steps'] += ['Human Approval: Demo manager authorization recorded','Execution: Demo receipt and inspection completed']
    DATA['ProcurementRequests'][0]['WorkflowId']=None
    add('AgentWorkflows',Id=uid('workflow-1'),WorkflowId=state['workflow_id'],Objective=state['objective'],CurrentAgent='Execution',Status='Completed',ApprovalStatus='Approved',StartedAt=NOW-timedelta(days=40),CompletedAt=NOW-timedelta(days=30),WorkflowType='Procurement',PurchaseOrderId=5,ValidationResults=json.dumps(validations),StateJson=json.dumps(state),FinalOutcome=state['final_outcome'])
    for i,(action,entity,entity_id,user) in enumerate([('Receive','PurchaseOrder','5',worker),('Quarantine','InventoryRoll','ROLL-RM12-B',qa),('Approve','PurchaseOrder','3',manager),('ScheduleMaintenance','Machine',str(uid('machine-4')),admin)],1):
        if user: add('AuditLogs',Id=uid(f'audit-{i}'),UserId=user,UserName='Demo operational history',Action=action,Entity=entity,EntityId=entity_id,Timestamp=NOW-timedelta(days=[31,4,4,1][i-1]),Success=True,IpAddress='127.0.0.1')
    return materials

def fill_rows(columns):
    for table,rows in DATA.items():
        for row in rows:
            for name,typ,nullable,default,identity in columns[table]:
                if name in row or default is not None or identity=='YES': continue
                if nullable=='YES': row[name]=None
                elif typ in ('text','varchar'): row[name]=''
                elif typ=='bool': row[name]=False
                elif typ in ('int4','int8','float8','numeric'): row[name]=0
                elif typ=='timestamptz': row[name]=NOW
                else: raise ValueError(f'Missing required field {table}.{name}')

def verify(conn, expected_digest):
    assert user_digest(conn)==expected_digest, 'Users changed: reset cancelled'
    checks={
      'stock matches physical rolls': 'SELECT COUNT(*) FROM "InventoryItems" i JOIN "RawMaterials" m ON m."SkuCode"=i."Sku" WHERE i."StockLevel" != (SELECT COALESCE(SUM(r."CurrentQuantity"),0) FROM "InventoryRolls" r WHERE r."RawMaterialId"=m."Id")',
      'stock snapshot matches catalogue': 'SELECT COUNT(*) FROM "StockLevels" s JOIN "InventoryItems" i ON i."RawMaterialId"=s."RawMaterialId" WHERE s."TotalQuantity" != i."StockLevel"',
      'order totals match lines': 'SELECT COUNT(*) FROM "PurchaseOrders" p WHERE p."TotalCost" != (SELECT COALESCE(SUM(l."TotalPrice"),0) FROM "OrderLines" l WHERE l."PurchaseOrderId"=p."Id")',
      'line price arithmetic': 'SELECT COUNT(*) FROM "OrderLines" WHERE "TotalPrice" != "Quantity"*"UnitPrice"',
      'active quote for every material': 'SELECT COUNT(*) FROM "RawMaterials" m WHERE NOT EXISTS(SELECT 1 FROM "SupplierMaterialQuotes" q JOIN "Suppliers" s ON s."Id"=q."SupplierId" WHERE q."RawMaterialId"=m."Id" AND q."IsActive" AND s."IsActive")',
      'quarantine agrees with physical stock': 'SELECT COUNT(*) FROM "Quarantines" q JOIN "InventoryRolls" r ON r."RollIdentifier"=q."InventoryRollId" JOIN "QualityInventoryRolls" qr ON qr."Id"=r."RollIdentifier" WHERE q."Status"=\'Active\' AND (r."Status"!=\'Quarantined\' OR qr."Status"!=\'Quarantined\')',
      'stock ledger balances': 'SELECT COUNT(*) FROM "InventoryItems" i WHERE i."StockLevel" != (SELECT COALESCE(SUM(CASE WHEN m."TransactionType"=\'CONSUMED\' THEN -m."Quantity" ELSE m."Quantity" END),0) FROM "InventoryMovements" m WHERE m."RawMaterialId"=i."RawMaterialId")',
      'nonnegative stock': 'SELECT COUNT(*) FROM "InventoryRolls" WHERE "CurrentQuantity"<0 OR "CurrentQuantity">"InitialQuantity"',
      'production limits': 'SELECT COUNT(*) FROM "Shifts" WHERE "AdjustedOutput">"ProductionTarget" OR "ActualOutput">"AdjustedOutput" OR "AdjustedOutput"*"MaterialPerUnit">"AvailableMaterial"',
    }
    for label,query in checks.items(): assert conn.execute(query).fetchone()[0]==0,label
    return list(checks)

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--prepare',action='store_true'); parser.add_argument('--apply',action='store_true'); parser.add_argument('--backup-dir'); args=parser.parse_args()
    if settings.db_host not in ('localhost','127.0.0.1'): raise RuntimeError('This script only resets the configured local database.')
    pg_bin=Path('C:/Program Files/PostgreSQL/18/bin')
    if args.prepare:
        directory=ROOT/'.local-backups'/datetime.now().strftime('demo-reset-%Y%m%d-%H%M%S'); directory.mkdir(parents=True)
        env={**os.environ,'PGPASSWORD':settings.db_password}
        subprocess.run([str(pg_bin/'pg_dump.exe'),'-h',settings.db_host,'-p',str(settings.db_port),'-U',settings.db_user,'-d',settings.db_name,'-Fc','-f',str(directory/'database.dump')],env=env,check=True,capture_output=True)
        subprocess.run([str(pg_bin/'pg_restore.exe'),'--list',str(directory/'database.dump')],check=True,capture_output=True)
        for source in (ROOT/'ai').glob('workflow*.sqlite3'):
            with sqlite3.connect(source) as original, sqlite3.connect(directory/source.name) as backup: original.backup(backup)
        with psycopg.connect(settings.database_url) as conn:
            digest,count=user_digest(conn)
            manifest={'database':settings.db_name,'users_digest':digest,'users_count':count,'created_at':datetime.now(timezone.utc).isoformat()}
            (directory/'manifest.json').write_text(json.dumps(manifest,indent=2))
        print(json.dumps({'backup_directory':str(directory),'users_preserved':count})); return
    if not args.apply or not args.backup_dir: raise RuntimeError('Create a verified backup with --prepare before applying.')
    directory=Path(args.backup_dir).resolve()
    if not directory.is_relative_to(ROOT/'.local-backups') or not (directory/'database.dump').exists(): raise RuntimeError('Verified local backup required.')
    manifest=json.loads((directory/'manifest.json').read_text())
    with psycopg.connect(settings.database_url) as conn:
        assert manifest['database']==settings.db_name
        expected=user_digest(conn); assert expected==(manifest['users_digest'],manifest['users_count']), 'Users changed since backup'
        # Existing application migration: add the missing optional shift associations.
        for field,typ in [('MaterialSku','text'),('MachineId','uuid'),('MaterialPerUnit','numeric')]:
            conn.execute(sql.SQL('ALTER TABLE "Shifts" ADD COLUMN IF NOT EXISTS {} {}').format(sql.Identifier(field),sql.SQL(typ)))
        columns={}
        for table,name,typ,nullable,default,identity in conn.execute("SELECT table_name,column_name,udt_name,is_nullable,column_default,is_identity FROM information_schema.columns WHERE table_schema='public' ORDER BY ordinal_position"):
            columns.setdefault(table,[]).append((name,typ,nullable,default,identity))
        build_data(conn); fill_rows(columns)
        targets=[t for t in columns if t not in ('Users','__EFMigrationsHistory')]
        conn.execute(sql.SQL('TRUNCATE {} RESTART IDENTITY').format(sql.SQL(',').join(sql.Identifier(t) for t in targets)))
        for table,rows in DATA.items():
            for row in rows:
                conn.execute(sql.SQL('INSERT INTO {} ({}) VALUES ({})').format(sql.Identifier(table),sql.SQL(',').join(map(sql.Identifier,row)),sql.SQL(',').join(sql.Placeholder() for _ in row)),list(row.values()))
        for table in targets:
            for name,typ,_,_,identity in columns[table]:
                if name=='Id' and typ in ('int4','int8'):
                    sequence=conn.execute('SELECT pg_get_serial_sequence(%s,%s)',(f'"{table}"',name)).fetchone()[0]
                    if sequence:
                        maximum=conn.execute(sql.SQL('SELECT MAX("Id") FROM {}').format(sql.Identifier(table))).fetchone()[0]
                        conn.execute('SELECT setval(%s,%s,%s)',(sequence,maximum or 1,maximum is not None))
        product_version=conn.execute('SELECT "ProductVersion" FROM "__EFMigrationsHistory" ORDER BY "MigrationId" DESC LIMIT 1').fetchone()[0]
        conn.execute('INSERT INTO "__EFMigrationsHistory" ("MigrationId","ProductVersion") VALUES (%s,%s) ON CONFLICT DO NOTHING',('20261005010000_AddShiftMaterialContext',product_version))
        checks=verify(conn,expected)
        counts={t:conn.execute(sql.SQL('SELECT COUNT(*) FROM {}').format(sql.Identifier(t))).fetchone()[0] for t in columns}
    for source in (ROOT/'ai').glob('workflow*.sqlite3'):
        with sqlite3.connect(source) as cached:
            tables=cached.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchall()
            for (table,) in tables: cached.execute('DELETE FROM "'+table.replace('"','""')+'"')
    report={'users_preserved':expected[1],'counts':counts,'consistency_checks':checks,'backup_directory':str(directory)}
    (directory/'reset-report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__': main()
