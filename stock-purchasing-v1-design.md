# Credo Business Intelligence V1
## Stock and Purchasing Intelligence

Status: development draft. Not approved for production deployment.

## Objective
Give informal merchants a simple, reliable record of stock on hand, purchases, stock reductions and physical counts. Convert those records into useful operating insights. This capability supports Credo's trust infrastructure; it is not a lending product.

## V1 merchant workflow
1. Create a stock item with a name, category, unit and minimum stock threshold.
2. Record an opening count when the item is first introduced.
3. Record each purchase with quantity, total cost, date and optional supplier name.
4. Record stock leaving the business using a specific reason: sale, usage, waste, damage, complimentary or internal use.
5. Enter a physical count when stock is checked.
6. Review current balance, low-stock warnings, purchase history and consumption trends.

## Accounting rule
Expected balance = opening quantity + purchases - recorded reductions + count corrections.

A reduction is not automatically a sale. Sale, usage, waste, damage, complimentary and internal use remain separate movement types. A physical count is evidence of actual stock at a point in time; a difference is recorded as a count correction rather than silently overwriting history.

## Data model
- inventory_items: business-owned catalogue and minimum stock threshold.
- purchase_records: purchase event, quantity, cost, supplier name and date.
- stock_movements: append-only quantity ledger.
- stock_snapshots: physical count and system-expected quantity at count time.
- stock_balances: read-only derived view of current quantity and low-stock status.

Every stock record is scoped to businesses.id. Composite foreign keys prevent a record for one business from referencing another business's item.

## Initial insights
- Current stock and low-stock status.
- Purchase history and spend by item.
- Recorded reductions by reason.
- Average daily/weekly recorded consumption when sufficient dated records exist.
- Items with repeated stockouts or frequent count variances, only when enough history exists.

Insights must distinguish observed data from estimates. No demand prediction or supplier savings claim should be made from insufficient data.

## Explicitly deferred
Supplier discounts, bulk buying, shared delivery, supplier marketplace, local demand intelligence, automated payment acceptance, receipt OCR and AI demand forecasts. These require comparable data, partner arrangements or additional validation.

## Security and implementation boundary
- No production database changes in this development phase.
- No real merchant records in test fixtures.
- The existing app's admin PIN/localStorage gate is not merchant authentication and must not be reused as a security boundary.
- A merchant portal must derive business access from authenticated membership on the server. Never trust a business ID supplied by an unauthenticated client.
- RLS must be tested for cross-business isolation, including views and RPCs.
- Ledger records must not be editable or deletable by merchants after posting.
- A purchase and its stock movement must be committed atomically.
- A physical count must calculate its expected quantity on the server and post any variance as a ledger movement.

## Integration strategy
The current repository is a single-file React application loaded from CDN scripts. Keep index.html unchanged until the database contract, authentication model and UI integration are separately reviewed. Add the merchant interface as a controlled module and integrate only after compatibility and security checks.

## Release gates
1. Confirm actual production schema and helper-function definitions using a verified backup or isolated development database.
2. Run migrations against a disposable copy, not production.
3. Execute SQL and RLS tests, including concurrent updates and cross-business access.
4. Verify authenticated merchant identity and business membership.
5. Review mobile usability and accessibility.
6. Obtain explicit approval before any production migration or deployment.
