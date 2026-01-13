
# vUSD — Milestone 1 Design Notes (Accounting-First Prototype)

**Reference Issue:**  
https://github.com/bifrost-io/developers/issues/41

## 1. Scope and Intent

This implementation represents a **minimal, accounting-focused prototype** of the vUSD borrowing lifecycle.
The primary objective of Milestone 1 is to validate:

* Correct collateral custody
* Debt accounting
* Mint → repay → burn lifecycle correctness

Risk controls, liquidation sophistication, and user-facing UX are intentionally minimized to keep the scope aligned with an initial grant milestone.


## 2. Vault Model Assumptions

### 2.1 User-Scoped Accounting

* Collateral is tracked per user and per asset:

  ```solidity
    mapping(address => mapping(address => uint256)) public collateralBalances; // user -> asset -> amount
  ```
* Debt is tracked per user:

  ```solidity
    mapping(address => mapping(address => uint256)) public debtBalances; // user -> asset -> vUSD minted
  ```

**Assumption:**
Each user’s position is logically treated as a single borrowing account, even though multiple collateral assets can currently be deposited.

**Implication:**
This model simplifies early accounting but does not yet enforce strict “one vault per collateral type” isolation. Vault isolation and stricter invariants are deferred to later milestones.

## 3. Collateral Assets

### 3.1 Supported Assets

* Only **pre-approved ERC-20 collateral tokens** (vDOT, vETH) are expected to be used.
* The contract assumes:

  * ERC-20 compliance
  * No fee-on-transfer behavior
  * Standard `transferFrom` semantics

**Out of scope for Milestone 1:**

* Dynamic collateral onboarding
* Asset risk weighting
* Heterogeneous collateral risk profiles


## 4. Minting Assumptions

### 4.1 Accounting-First Minting

* Minting vUSD increases:

  * User debt
  * vUSD total supply
* No collateralisation ratio or loan-to-value checks are enforced in the current version.

**Assumption:**
Minting is exercised only within trusted or test-controlled environments during Milestone 1.

**Rationale:**
The purpose of minting at this stage is to validate:

* Correct debt increments
* Token mint correctness
* Lifecycle symmetry with repayment

Risk constraints are intentionally deferred to keep the prototype minimal.


## 5. Repayment and Burning

### 5.1 Burn-on-Repay Model

* Repayment requires the user to transfer vUSD to the contract
* Repaid vUSD is immediately burned
* User debt is reduced atomically

**Invariant Assumptions:**

* User debt cannot underflow
* Total vUSD supply always reflects outstanding system debt

This establishes a clean and auditable accounting invariant suitable for extension in later milestones.


## 6. Collateral Withdrawal Assumptions

### 6.1 Mechanical Withdrawal

* Users may unlock and withdraw collateral via `unlockCollateral`
* The function performs:

  * Balance reduction
  * ERC-20 transfer to user

**Assumption:**
Vault health is **not yet enforced** at this stage.

**Rationale:**
Collateral withdrawal is implemented as a mechanical primitive only. Health-gated withdrawals (CR enforcement) are deferred to subsequent iterations once oracle pricing and liquidation logic are introduced.


## 7. Oracle and Pricing Assumptions

### 7.1 Oracle Availability

* Price feeds are assumed to exist, but are not integrated in Milestone 1
* No pricing logic is currently executed on-chain

**Explicit Non-Goals for Milestone 1:**

* Oracle correctness
* Price manipulation resistance
* TWAP / fallback mechanisms

These are planned once core accounting correctness is validated.


## 8. Liquidation Assumptions

* No liquidation logic exists in the current implementation

**Assumption:**
Liquidations are intentionally excluded to avoid prematurely introducing:

* Economic complexity
* Game-theoretic assumptions
* Incentive design dependencies

A minimal liquidation path will be introduced only after collateralisation enforcement is in place.

## 9. Security and Trust Model

### 9.1 Trust Assumptions


### 9.2 Explicit Limitations

* Insolvent states are possible by design in this milestone
* No protection against malicious usage
* No MEV, oracle, or economic attack mitigations

These are known and documented limitations, not oversights.


## 10. Out-of-Scope Features (Confirmed)

The following are explicitly excluded from Milestone 1:

* Yield redistribution or rebasing
* Incentive mechanisms
* Stability pools
* Auctions or advanced liquidation
* User-facing UI beyond basic testing helpers


## 11. Forward Compatibility

The current design is intentionally structured to allow:

* Introduction of explicit vault structs
* Collateralisation ratio enforcement
* Oracle-based valuation
* Simple liquidation paths
* Incentivised system extensions

without breaking existing accounting invariants.


## 12. Summary

This milestone establishes a correct, minimal, and auditable accounting foundation for vUSD. All missing features are explicitly deferred by design, not omitted accidentally, and will be layered on incrementally in subsequent milestones.

