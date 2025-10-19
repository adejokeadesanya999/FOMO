FOMO Reward Contract

Overview

The FOMO (Fear of Missing Out) Reward Contract is a Clarity smart contract that manages time-sensitive, limited-duration reward pools on the Stacks blockchain.
Participants must claim their rewards within a short time window (≈5 minutes / 30 blocks), or the unclaimed funds are redistributed—usually to the contract owner.
This design encourages quick engagement and simulates real-time “FOMO” reward behavior.

🔧 Core Features

Create Reward Pools:
The contract owner can create multiple reward pools, each with:

A total STX amount

A list of eligible users (up to 100)

Automatic per-user reward calculation

A creation block timestamp

An active state flag

Claim Rewards (Time-Sensitive):
Eligible users can claim their STX rewards within 30 blocks after pool creation.

Claims are individually tracked

Once a user claims, they cannot claim again

If a user misses the window, the claim fails with ERR_TIME_EXPIRED.

Redistribute Expired Funds:
When a pool’s claim window expires, unclaimed rewards can be reclaimed by the contract owner.

Automatically deactivates the pool

Redistributes unclaimed STX to the owner

Contract Funding:
Anyone can fund the contract with STX via fund-contract.
The internal balance is tracked with contract-balance.

View Functions:

get-pool-info: Retrieves pool details (participants, status, etc.)

get-contract-balance: Returns current available funds

get-time-remaining: Shows remaining blocks before claim window expires

can-claim: Checks if a specific user can still claim a reward

⚙️ Key Constants
Constant	Description	Default
CLAIM_WINDOW	Time window in blocks for claiming rewards	u30
ERR_NOT_AUTHORIZED	Error code for unauthorized action	u100
ERR_ALREADY_CLAIMED	Error code if user already claimed	u101
ERR_TIME_EXPIRED	Error code when claim period is over	u102
ERR_INSUFFICIENT_FUNDS	Error for not enough funds	u103
ERR_NOT_FOUND	Error for missing pool or entry	u104

📜 Function Summary

Public Functions

Function	Description
create-reward-pool(total-amount, eligible-users)	Creates a new reward pool; only contract owner can call.
claim-reward(pool-id)	Allows eligible users to claim rewards within the active window.
redistribute-expired-pool(pool-id)	Redistributes unclaimed funds after claim window expires.
fund-contract(amount)	Adds STX funds to the contract balance.

Read-Only Functions

Function	Description
get-pool-info(pool-id)	Returns details of a specific pool.
can-claim(pool-id, user)	Checks if a user can still claim.
get-contract-balance()	Returns total available contract balance.
get-time-remaining(pool-id)	Returns remaining blocks before pool expiration.

🚨 Security & Validation

Only the contract owner can create or redistribute pools.

Each pool is time-bound and auto-deactivated upon expiry.

Double-claiming is prevented with explicit claimed-users tracking.

STX transfers use safe stx-transfer? calls with try! for error handling.

Every state change is validated with asserts! to prevent invalid updates.

🧠 Usage Flow

Fund the contract using fund-contract(amount).

Create a reward pool using create-reward-pool(total, eligible-users).

Eligible users claim their STX via claim-reward(pool-id) within the block limit.

After expiry, the owner calls redistribute-expired-pool(pool-id) to recover unclaimed funds.

🧩 Example Workflow
;; Step 1: Fund the contract
(contract-call? .fomo-contract fund-contract u1000000)

;; Step 2: Create a reward pool for three users
(contract-call? .fomo-contract create-reward-pool
  u300000
  (list 'ST1ABC...' 'ST2DEF...' 'ST3GHI...')
)

;; Step 3: User claims within 30 blocks
(contract-call? .fomo-contract claim-reward u0)

;; Step 4: Owner reclaims unclaimed rewards after window
(contract-call? .fomo-contract redistribute-expired-pool u0)

🧾 License
This smart contract is open-sourced under the MIT License.