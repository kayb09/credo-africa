# Stock and Purchasing V1: Verification Plan

Status: test plan only. No production tests have been run.

## Functional cases
1. Create an item with a positive opening count.
2. Reject zero or negative opening quantity.
3. Record a purchase and verify exactly one matching positive ledger movement.
4. Reject a purchase with a missing item, invalid quantity or negative cost.
5. Record a sale and verify the balance decreases.
6. Record usage, waste, damage, complimentary and internal use as distinct reasons.
7. Reject a zero movement and reject a movement whose sign conflicts with its type.
8. Record a physical count equal to expected quantity and verify no correction movement is created.
9. Record a physical count above or below expected quantity and verify one signed count-correction movement is created.
10. Verify a purchase cannot be posted twice through a retry or duplicate request.
11. Verify movement history remains append-only for merchant roles.
12. Verify low-stock status is based on current balance and the item's configured minimum.

## Tenant isolation cases
1. Merchant A can read only items, purchases, movements, snapshots and balances belonging to Business A.
2. Merchant A cannot insert a row for Business B.
3. Merchant A cannot reference Business B's inventory item from a purchase or movement.
4. Merchant A cannot read Business B data through the stock_balances view.
5. An unauthenticated/anon request cannot read or write stock tables.
6. An admin can access only the scope explicitly granted by the reviewed admin policy.
7. RPC execution cannot be used to bypass business membership checks.

## Integrity and concurrency cases
1. Two simultaneous purchases for the same item both post once and produce the correct balance.
2. A physical count concurrent with a purchase produces a deterministic, auditable result.
3. A failed purchase transaction leaves neither a purchase row nor a stock movement.
4. A failed count transaction leaves neither a snapshot nor a correction movement.
5. Replaying a request does not duplicate ledger entries.

## Required evidence before release
- Exact database schema and function definitions from the isolated development database.
- Migration execution output and rollback/recovery procedure.
- SQL test output, including RLS tests executed under distinct authenticated users.
- Evidence that the view uses invoker security and that RPCs enforce membership.
- UI tests on mobile and desktop.
- A written approval before production deployment.

Do not describe a test as passed unless it has actually been executed and its output retained.
