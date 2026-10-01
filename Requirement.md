# Software Requirements Specification (SRS)
## Sales & Distribution Management App

**Version:** 2.0 (Workforce Referral & Multi-tier Distribution Update)
**Date:** September 2026
**Prepared for:** JP

---

## 1. Project Overview

A role-based, multi-tier inventory distribution and sales management application. The system tracks stock as it flows from supplier intake down through warehouse management, field sales managers, and salesmen, ultimately to customers.

**Key Architectural Distinction:**
- **Zero Customer Referral Policy:** Customers do NOT have any referral codes, bonuses, or referral policies.
- **Workforce Referral Network:** Referral policy is exclusively for internal staff (**Store Admin, Field Sales Manager (FSM), and Salesman**). Staff can refer other staff members into the sales tree.
- **Per-Bottle Downline Commission:** Referrers earn commission on every bottle sold by their downline referrals (e.g., ₹1.00 per bottle).
- **Super Admin Qualification Gate:** Referrers must meet a minimum sales quota themselves (e.g., sell at least 5 bottles/day) to unlock and receive downline commissions.
- **Strict Stock Intake & Multi-Tier Flow:** Store Manager receives intake -> Super Admin approves -> Stock added to warehouse -> Warehouse Manager distributes to FSMs -> FSM distributes to Salesmen -> Salesmen sell bottles.

### 1.1 Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Android & iOS) |
| Backend API | Node.js + Express |
| Database | Supabase (PostgreSQL) |
| Auth | Email Auth / Role-based Access Control |
| File/Image Storage | Supabase Storage (receipts, KYC documents) |

### 1.2 Goals

- Give each role a restricted view of the app based on permissions set by Super Admin.
- Track stock movement end-to-end: Supplier Intake → Store Admin → Super Admin Approval → Warehouse → FSM → Salesman → Customer.
- Allow direct sales at Store Admin and FSM levels too, without customer referral fields.
- Track distributor sales separately from retail sales.
- Enable the workforce referral program where staff earn per-bottle commissions for recruiting productive salesmen, governed strictly by Super Admin conditions and minimum sales quotas.

---

## 2. User Roles & Hierarchy

```
Super Admin
   │
   ▼
Store Admin (Warehouse Admin)
   │
   ▼
Field Sales Manager (FSM)
   │
   ▼
Salesman (e.g. Salesman A, B, C, D)
   │
   ▼
Customer (End consumer / Distributor - NO referral policy)
```

### 2.1 Role Creation & Referral Rule
- **Super Admin Governance:** Only Super Admin can approve user additions, set commission amounts per bottle, and configure qualification quota conditions.
- **Staff Referrals:** Salesman A refers Salesman B; Salesman B refers Salesman C; Salesman A refers Salesman D.
- **No Customer Referrals:** Customers do not have accounts, referral codes, or referral rewards.
- All monetary values in the system (product prices, discounts, per-bottle commission, minimum sales quota) are set **exclusively by Super Admin**.

---

## 3. Role-wise Functional Requirements

### 3.1 Super Admin
Full, unrestricted access to the system.

- Create/edit/deactivate users for all roles (Warehouse Admin, Field Sales Manager, Salesman, Customer)
- Define and edit role-based permissions (what each role can/cannot see or do)
- Set all product prices, discounts, and pricing tiers
- Set referral bonus amounts/rules
- View full inventory across all warehouses
- View complete stock movement history (warehouse → FSM → salesman → customer)
- View all sales transactions system-wide (by role, region, date range, product)
- Approve/reject stock transfer requests (optional, configurable)
- Generate reports: sales, stock, referral payouts, commissions, outstanding dues
- Manage product catalog (add/edit/remove products, categories, units, SKUs)
- Manage distributor accounts and distributor-specific pricing
- View audit logs of all actions taken by other roles

### 3.2 Warehouse Admin
Manages the central inventory and top-level distribution.

- Add stock into inventory (new stock intake, with supplier/batch/quantity/date details)
- View current warehouse stock levels
- Distribute stock to Field Sales Managers (create stock transfer records)
- Sell items directly to customers (direct warehouse sale)
- Sell stock to distributors (bulk sale, distributor-specific pricing set by Super Admin)
- View stock transfer history (outgoing to FSMs, sales made)
- View low-stock alerts
- Cannot set prices — pricing is pulled from Super Admin-configured product list
- Cannot create Field Sales Manager / Salesman accounts (Super Admin only)

### 3.3 Field Sales Manager (FSM)
Middle layer — receives stock from warehouse, distributes to salesmen, and can sell directly.

- Receive stock transferred from Warehouse Admin (accept/confirm receipt)
- View stock currently held (their own "mini-inventory")
- Distribute/allocate stock to individual Salesmen under them
- Sell items directly to customers (direct FSM-level sale)
- View stock transfer history (received from warehouse, distributed to salesmen, direct sales)
- View performance of salesmen under their supervision (sales made, stock remaining)
- Cannot set prices or referral bonuses
- Cannot create/manage Warehouse Admin or other FSM accounts

### 3.4 Salesman
Field-level role, closest to the end customer.

- View stock allocated to them by their Field Sales Manager
- Sell items to any type of customer (retail, walk-in, referred customer, etc.)
- Record sales transactions (product, quantity, amount, customer details, payment mode)
- View their own sales history and remaining stock
- Add new customers (name, contact, address) at point of sale
- Capture referral code (if a customer was referred by someone) at time of sale/customer onboarding
- Cannot distribute stock to other salesmen
- Cannot set prices or discounts beyond what Super Admin has configured

### 3.5 Customer (End User / Distributor)
Direct buyers in the system.
- **NO Referral Policy:** Customers do NOT have referral codes or bonuses.
- Purchases recorded against them (by Store Admin, FSM, or Salesman).
- Distributors are a distinct customer sub-type with separate bulk pricing (set by Super Admin).

---

## 4. Multi-Tier Stock Movement & Approval Flow

The stock flows through four verified tiers with strict accountability:

```
[Supplier]
    │ (Intake logging: e.g. 100 bottles)
    ▼
[Store Admin (Warehouse Admin)]
    │ (Awaiting Verification)
    ▼
[Super Admin Approval] ──► Verified stock added to Warehouse Inventory
    │
    ▼ (Distribution: e.g. 40 bottles each to 2 FSMs)
[Field Sales Managers (FSM 1 & FSM 2)]
    │
    ▼ (Distribution: e.g. 10 bottles each to 4 Salesmen)
[Salesmen (A, B, C, D)]
    │
    ▼ (Sales recording: e.g. 10 bottles sold to customers)
[Customers (Retail / Bulk Distributors)]
```

### 4.1 Stock Transfer Rules
1. **Intake Approval:** When Store Admin receives stock from supplier (e.g. 100 bottles), it is logged as pending until Super Admin verifies and approves the batch. Only then is it credited to warehouse stock.
2. **Warehouse to FSM:** Store Admin distributes approved warehouse stock to Field Sales Managers.
3. **FSM to Salesman:** FSM distributes their mini-inventory to assigned Salesmen.
4. **Salesman:** Sells directly to customers. Salesmen CANNOT transfer stock to other salesmen.

---

## 5. Workforce Referral & Commission System (Store Admin, FSM & Salesman)

### 5.1 Workforce Referral Hierarchy Concept
Referrals operate strictly within the internal sales workforce (Store Admin, FSM, Salesman):
- **Salesman A** is the first salesman.
- **A refers B** -> B joins as salesman (`A -> B`).
- **B refers C** -> C joins as salesman (`B -> C`).
- **A refers D** -> D joins as salesman (`A -> D`).

**Hierarchy Tree:**
```
       Salesman A
      ┌────┴────┐
      ▼         ▼
  Salesman B  Salesman D
      │
      ▼
  Salesman C
```

### 5.2 Direct Referrer Commission Rule
When a referred salesman sells bottles, their **direct referrer** earns a per-bottle commission (configured by Super Admin):
- **Rate Example:** ₹1.00 per bottle sold.
- **When B sells 10 bottles:** A earns ₹10 (10 × ₹1).
- **When C sells 10 bottles:** B earns ₹10 (10 × ₹1).
- **When D sells 10 bottles:** A earns ₹10 (10 × ₹1).
- Total earned for **A**: ₹20 (from B and D).
- Total earned for **B**: ₹10 (from C).

### 5.3 Super Admin Qualification Gate (Conditions Policy)
To prevent passive earning without personal productivity, the Super Admin can enforce a **Minimum Sales Quota Condition**:
- **Condition:** For Referrer A to earn commission from downlines B and D, **Referrer A must also sell a minimum quantity of bottles** (e.g., at least 5 bottles/day or per cycle).
- **Status Lifecycle:**
  - If B sells 10 bottles but A has not yet met the quota: The ₹10 commission is marked as `quota_pending` / `locked`.
  - Once A reaches the required minimum quantity (e.g., sells ≥ 5 bottles): All pending commissions automatically unlock into `unlocked` / available for payout!
- **100% Super Admin Controlled:**
  - Super Admin sets the commission amount per bottle (₹).
  - Super Admin sets the minimum sales quota (number of bottles).
  - Super Admin can toggle the qualification condition ON or OFF at any time.
  - Super Admin views the complete Workforce Referral Tree and manages commission payouts.

---

## 6. Role-Based Access Control (RBAC) Matrix

| Feature | Super Admin | Warehouse Admin | Field Sales Manager | Salesman |
|---|:---:|:---:|:---:|:---:|
| Create users (any role) | ✅ | ❌ | ❌ | ❌ |
| Set prices / bonuses | ✅ | ❌ | ❌ | ❌ |
| Add stock to warehouse | ✅ | ✅ | ❌ | ❌ |
| Transfer stock to FSM | ✅ | ✅ | ❌ | ❌ |
| Transfer stock to Salesman | ✅ | ❌ | ✅ | ❌ |
| Sell to customer directly | ✅ | ✅ | ✅ | ✅ |
| Sell to distributor | ✅ | ✅ | ❌ | ❌ |
| View own stock/sales | ✅ | ✅ | ✅ | ✅ |
| View all system data | ✅ | ❌ | ❌ | ❌ |
| Manage referral bonuses | ✅ | ❌ | ❌ | ❌ |
| View referral status | ✅ | View only | View only | View only |

---

## 7. High-Level Database Entities (Supabase/PostgreSQL)

- `users` (id, name, role, phone, email, warehouse_id, parent_id [reports to], referrer_id [referred by staff member], status)
- `products` (id, name, sku, unit, base_price, category, min_stock_alert)
- `stocks` (id, owner_id [warehouse/FSM/salesman], product_id, quantity, updated_at)
- `stock_inward_requests` (id, warehouse_id, product_id, quantity, receipt_url, status [pending/approved/rejected], requested_by, approved_by)
- `stock_transfers` (id, from_id, to_id, product_id, quantity, status, created_at)
- `sales` (id, warehouse_id, salesman_id, customer_id, customer_type, product_id, quantity, amount, payment_method, created_at)
- `customers` (id, name, phone, email, customer_type [retail/distributor], created_by)
- `workforce_referral_rules` (id, commission_per_bottle, min_sales_quota, is_quota_condition_active, is_active, eligible_roles, updated_at)
- `workforce_referral_commissions` (id, referrer_id, referee_id, sale_id, bottles_sold, rate_per_bottle, commission_amount, status [unlocked/quota_pending/paid], paid_at, created_at)
- `roles_permissions` (role, permission_key, is_allowed) — dynamic RBAC managed by Super Admin
- `audit_logs` (id, user_id, user_name, action, entity_name, entity_id, details, timestamp)

---

## 8. Non-Functional Requirements

- **Security:** Strict role-based permissions preventing unauthorized stock movement, price tampering, or self-approval.
- **Audit trail:** All stock movements, sales, and referral commission triggers are logged and traceable.
- **Reliability:** Dual-mode architecture (Live Supabase database connection with seamless fallback to in-memory state).
- **Responsiveness:** Real-time quota calculation and instant UI status badges for qualification gates.

---

## 9. Clarified Business Rules

1. **Customer Referrals:** Explicitly deactivated. Customers are buyers only; no referral bonuses or codes apply to customers.
2. **Workforce Referrals:** Exclusively for Store Admin, Field Sales Managers (FSM), and Salesmen.
3. **Commission Basis:** Earned per bottle sold by directly referred downline personnel (e.g. ₹1 per bottle).
4. **Qualification Condition:** Managed by Super Admin. Requires referrer to sell a minimum quantity of bottles (e.g. 5 bottles) before downline commission is unlocked for payout.
5. **Stock Flow:** Supplier -> Store Admin Inward Request -> Super Admin Verification & Approval -> Central Warehouse -> FSM Mini-Depot -> Salesman Allocated Stock -> Customer Sale.

---

*End of Document*
