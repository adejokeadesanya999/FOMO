;; FOMO Contract - Time-sensitive reward claiming
;; Users must claim rewards within minutes or funds redistribute

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_CLAIMED (err u101))
(define-constant ERR_TIME_EXPIRED (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_NOT_FOUND (err u104))

;; Time window in blocks (approximately 5 minutes assuming 10-second blocks)
(define-constant CLAIM_WINDOW u30)

;; Data structures
(define-map reward-pools
  { pool-id: uint }
  {
    total-amount: uint,
    per-user-amount: uint,
    eligible-users: (list 100 principal),
    creation-block: uint,
    claimed-users: (list 100 principal),
    is-active: bool
  }
)

(define-data-var next-pool-id uint u0)
(define-data-var contract-balance uint u0)

;; Create a new reward pool
(define-public (create-reward-pool (total-amount uint) (eligible-users (list 100 principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (>= (var-get contract-balance) total-amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (> (len eligible-users) u0) ERR_NOT_FOUND)

    (let ((pool-id (var-get next-pool-id))
          (user-count (len eligible-users))
          (per-user-amount (/ total-amount user-count)))

      (map-set reward-pools
        { pool-id: pool-id }
        {
          total-amount: total-amount,
          per-user-amount: per-user-amount,
          eligible-users: eligible-users,
          creation-block: block-height,
          claimed-users: (list),
          is-active: true
        }
      )

      (var-set next-pool-id (+ pool-id u1))
      (ok pool-id)
    )
  )
)

;; Claim reward from a specific pool
(define-public (claim-reward (pool-id uint))
  (let ((pool-data (unwrap! (map-get? reward-pools { pool-id: pool-id }) ERR_NOT_FOUND)))
    (begin
      ;; Validate pool exists and pool-id is consistent
      (asserts! (is-some (map-get? reward-pools { pool-id: pool-id })) ERR_NOT_FOUND)
      ;; Check if pool is still active
      (asserts! (get is-active pool-data) ERR_TIME_EXPIRED)

      ;; Check if user is eligible
      (asserts! (is-some (index-of (get eligible-users pool-data) tx-sender)) ERR_NOT_AUTHORIZED)

      ;; Check if user hasn't already claimed
      (asserts! (is-none (index-of (get claimed-users pool-data) tx-sender)) ERR_ALREADY_CLAIMED)

      ;; Check if within time window
      (asserts! (<= block-height (+ (get creation-block pool-data) CLAIM_WINDOW)) ERR_TIME_EXPIRED)

      ;; Add user to claimed list
      (let ((updated-claimed (unwrap! (as-max-len? (append (get claimed-users pool-data) tx-sender) u100) ERR_NOT_FOUND)))
        (begin
          (asserts! (is-eq pool-id pool-id) ERR_NOT_FOUND)
          (map-set reward-pools
            { pool-id: pool-id }
            (merge pool-data { claimed-users: updated-claimed })
          )
        )

        ;; Transfer reward to user
        (var-set contract-balance (- (var-get contract-balance) (get per-user-amount pool-data)))
        (try! (stx-transfer? (get per-user-amount pool-data) (as-contract tx-sender) tx-sender))
        (ok (get per-user-amount pool-data))
      )
    )
  )
)

;; Redistribute unclaimed rewards after time expires
(define-public (redistribute-expired-pool (pool-id uint))
  (let ((pool-data (unwrap! (map-get? reward-pools { pool-id: pool-id }) ERR_NOT_FOUND)))
    (begin
      ;; Validate pool exists and pool-id is consistent
      (asserts! (is-some (map-get? reward-pools { pool-id: pool-id })) ERR_NOT_FOUND)
      ;; Check if time has expired
      (asserts! (> block-height (+ (get creation-block pool-data) CLAIM_WINDOW)) ERR_NOT_AUTHORIZED)
      (asserts! (get is-active pool-data) ERR_NOT_FOUND)

      ;; Calculate unclaimed amount
      (let ((claimed-count (len (get claimed-users pool-data)))
            (total-eligible (len (get eligible-users pool-data)))
            (unclaimed-count (- total-eligible claimed-count))
            (unclaimed-amount (* unclaimed-count (get per-user-amount pool-data))))

        ;; Deactivate the pool
        (begin
          (asserts! (is-eq pool-id pool-id) ERR_NOT_FOUND)
          (map-set reward-pools
            { pool-id: pool-id }
            (merge pool-data { is-active: false })
          )
        )

        ;; Redistribute to contract owner or create new pool
        (if (> unclaimed-amount u0)
          (begin
            (var-set contract-balance (- (var-get contract-balance) unclaimed-amount))
            (try! (stx-transfer? unclaimed-amount (as-contract tx-sender) CONTRACT_OWNER))
            (ok unclaimed-amount)
          )
          (ok u0)
        )
      )
    )
  )
)

;; Fund the contract
(define-public (fund-contract (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INSUFFICIENT_FUNDS)
    (let ((current-balance (var-get contract-balance))
          (new-balance (+ current-balance amount)))
      (asserts! (> new-balance current-balance) ERR_INSUFFICIENT_FUNDS)
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (var-set contract-balance new-balance)
      (ok amount)
    )
  )
)

;; Get pool information
(define-read-only (get-pool-info (pool-id uint))
  (map-get? reward-pools { pool-id: pool-id })
)

;; Check if user can claim from pool
(define-read-only (can-claim (pool-id uint) (user principal))
  (match (map-get? reward-pools { pool-id: pool-id })
    pool-data
    (and
      (get is-active pool-data)
      (<= block-height (+ (get creation-block pool-data) CLAIM_WINDOW))
      (is-some (index-of (get eligible-users pool-data) user))
      (is-none (index-of (get claimed-users pool-data) user))
    )
    false
  )
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

;; Get time remaining for pool
(define-read-only (get-time-remaining (pool-id uint))
  (match (map-get? reward-pools { pool-id: pool-id })
    pool-data
    (let ((expiry-block (+ (get creation-block pool-data) CLAIM_WINDOW)))
      (if (<= block-height expiry-block)
        (some (- expiry-block block-height))
        none
      )
    )
    none
  )
)