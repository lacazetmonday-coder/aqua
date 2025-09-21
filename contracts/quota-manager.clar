;; Quota Manager Contract
;; Manages water usage quotas, compliance monitoring, and violation tracking

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_PARAMS (err u400))
(define-constant ERR_QUOTA_EXCEEDED (err u403))
(define-constant ERR_EXPIRED_RIGHT (err u410))
(define-constant ERR_GEOGRAPHIC_VIOLATION (err u412))
(define-constant ERR_ALREADY_REPORTED (err u409))
(define-constant ERR_INACTIVE_RIGHT (err u405))

;; Define data variables
(define-data-var usage-report-nonce uint u0)
(define-data-var violation-nonce uint u0)
(define-data-var daily-usage-limit uint u100) ;; Default daily limit
(define-data-var geographic-tolerance uint u5)  ;; Default geographic tolerance

;; Usage tracking
(define-map daily-usage
  { token-id: uint, day: uint }
  { amount-used: uint, reports-count: uint }
)

;; Compliance violations
(define-map violations
  { violation-id: uint }
  {
    token-id: uint,
    violation-type: (string-ascii 64),
    amount-exceeded: uint,
    reported-by: principal,
    reported-at: uint,
    is-resolved: bool,
    penalty-amount: uint
  }
)

;; Usage reports
(define-map usage-reports
  { report-id: uint }
  {
    token-id: uint,
    amount-used: uint,
    location-x: uint,
    location-y: uint,
    reported-by: principal,
    reported-at: uint,
    is-verified: bool
  }
)

;; Authorized reporters (water meters, sensors, etc.)
(define-map authorized-reporters
  { reporter: principal }
  { is-active: bool, region: (string-ascii 64), reporter-type: (string-ascii 32) }
)

;; Compliance officers
(define-map compliance-officers
  { officer: principal }
  { is-active: bool, region: (string-ascii 64) }
)

;; Regional usage limits
(define-map regional-limits
  { region: (string-ascii 64) }
  { daily-limit: uint, seasonal-multiplier: uint }
)

;; Read-only functions

;; Get daily usage for a water right
(define-read-only (get-daily-usage (token-id uint) (day uint))
  (default-to 
    { amount-used: u0, reports-count: u0 }
    (map-get? daily-usage { token-id: token-id, day: day })
  )
)

;; Get usage report details
(define-read-only (get-usage-report (report-id uint))
  (map-get? usage-reports { report-id: report-id })
)

;; Get violation details
(define-read-only (get-violation (violation-id uint))
  (map-get? violations { violation-id: violation-id })
)

;; Check if reporter is authorized
(define-read-only (is-authorized-reporter (reporter principal))
  (match (map-get? authorized-reporters { reporter: reporter })
    reporter-data (get is-active reporter-data)
    false
  )
)

;; Check compliance status for a water right
(define-read-only (check-compliance-status (token-id uint))
  (let (
    (current-day (/ stacks-block-height u144)) ;; Approximation: ~144 blocks per day
    (today-usage (get-daily-usage token-id current-day))
    (amount-used (get amount-used today-usage))
    (daily-limit (var-get daily-usage-limit))
  )
    {
      is-compliant: (<= amount-used daily-limit),
      usage-today: amount-used,
      daily-limit: daily-limit,
      violation-amount: (if (> amount-used daily-limit) (- amount-used daily-limit) u0)
    }
  )
)

;; Calculate current day from block height
(define-read-only (get-current-day)
  (/ stacks-block-height u144)
)

;; Get total usage for a token across all time
(define-read-only (get-total-usage (token-id uint))
  ;; This would typically aggregate across all days, simplified for demo
  (let (
    (current-day (get-current-day))
    (today-usage (get-daily-usage token-id current-day))
  )
    (get amount-used today-usage)
  )
)

;; Public functions

;; Add authorized reporter
(define-public (add-reporter (reporter principal) (region (string-ascii 64)) (reporter-type (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-reporters
      { reporter: reporter }
      { is-active: true, region: region, reporter-type: reporter-type }
    )
    (ok true)
  )
)

;; Add compliance officer
(define-public (add-compliance-officer (officer principal) (region (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set compliance-officers
      { officer: officer }
      { is-active: true, region: region }
    )
    (ok true)
  )
)

;; Record water usage
(define-public (record-usage 
  (token-id uint) 
  (amount-used uint) 
  (location-x uint) 
  (location-y uint)
)
  (let (
    (report-id (+ (var-get usage-report-nonce) u1))
    (current-day (get-current-day))
    (current-usage (get-daily-usage token-id current-day))
    (new-total (+ (get amount-used current-usage) amount-used))
    (daily-limit (var-get daily-usage-limit))
  )
    ;; Verify reporter authorization
    (asserts! (is-authorized-reporter tx-sender) ERR_UNAUTHORIZED)
    
    ;; Validate parameters
    (asserts! (> amount-used u0) ERR_INVALID_PARAMS)
    
    ;; Check geographic bounds (simplified check)
    ;; In production, this would verify against the water right's location
    
    ;; Create usage report
    (map-set usage-reports
      { report-id: report-id }
      {
        token-id: token-id,
        amount-used: amount-used,
        location-x: location-x,
        location-y: location-y,
        reported-by: tx-sender,
        reported-at: stacks-block-height,
        is-verified: false
      }
    )
    
    ;; Update daily usage
    (map-set daily-usage
      { token-id: token-id, day: current-day }
      {
        amount-used: new-total,
        reports-count: (+ (get reports-count current-usage) u1)
      }
    )
    
    ;; Update nonce
    (var-set usage-report-nonce report-id)
    
    ;; Check for violations and create violation record if needed
    (if (> new-total daily-limit)
      (begin
        (unwrap-panic (create-violation token-id "daily-limit-exceeded" (- new-total daily-limit)))
        true
      )
      true
    )
    
    (ok report-id)
  )
)

;; Create violation record
(define-private (create-violation (token-id uint) (violation-type (string-ascii 64)) (amount-exceeded uint))
  (let (
    (violation-id (+ (var-get violation-nonce) u1))
    (penalty (calculate-penalty amount-exceeded))
  )
    (map-set violations
      { violation-id: violation-id }
      {
        token-id: token-id,
        violation-type: violation-type,
        amount-exceeded: amount-exceeded,
        reported-by: tx-sender,
        reported-at: stacks-block-height,
        is-resolved: false,
        penalty-amount: penalty
      }
    )
    
    (var-set violation-nonce violation-id)
    (ok violation-id)
  )
)

;; Calculate penalty amount based on violation severity
(define-private (calculate-penalty (amount-exceeded uint))
  ;; Simple penalty calculation: 10 STX per unit exceeded
  (* amount-exceeded u10000000) ;; 10 STX in microSTX
)

;; Verify usage report (compliance officers only)
(define-public (verify-usage-report (report-id uint) (is-valid bool))
  (let (
    (report-data (unwrap! (get-usage-report report-id) ERR_NOT_FOUND))
  )
    ;; Verify caller is compliance officer
    (asserts! (is-compliance-officer tx-sender) ERR_UNAUTHORIZED)
    
    ;; Update verification status
    (map-set usage-reports
      { report-id: report-id }
      (merge report-data { is-verified: is-valid })
    )
    
    (ok true)
  )
)

;; Check if caller is compliance officer
(define-private (is-compliance-officer (officer principal))
  (match (map-get? compliance-officers { officer: officer })
    officer-data (get is-active officer-data)
    false
  )
)

;; Resolve violation (compliance officers only)
(define-public (resolve-violation (violation-id uint) (resolution (string-ascii 256)))
  (let (
    (violation-data (unwrap! (get-violation violation-id) ERR_NOT_FOUND))
  )
    ;; Verify caller is compliance officer
    (asserts! (is-compliance-officer tx-sender) ERR_UNAUTHORIZED)
    
    ;; Verify not already resolved
    (asserts! (not (get is-resolved violation-data)) ERR_ALREADY_REPORTED)
    
    ;; Mark as resolved
    (map-set violations
      { violation-id: violation-id }
      (merge violation-data { is-resolved: true })
    )
    
    (ok true)
  )
)

;; Update daily usage limits
(define-public (set-daily-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> new-limit u0) ERR_INVALID_PARAMS)
    (var-set daily-usage-limit new-limit)
    (ok true)
  )
)

;; Set regional usage limits
(define-public (set-regional-limit (region (string-ascii 64)) (daily-limit uint) (seasonal-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> daily-limit u0) ERR_INVALID_PARAMS)
    (asserts! (> seasonal-multiplier u0) ERR_INVALID_PARAMS)
    
    (map-set regional-limits
      { region: region }
      { daily-limit: daily-limit, seasonal-multiplier: seasonal-multiplier }
    )
    
    (ok true)
  )
)

;; Report suspected violation (public reporting)
(define-public (report-violation (token-id uint) (violation-description (string-ascii 256)))
  (let (
    (violation-id (+ (var-get violation-nonce) u1))
  )
    (map-set violations
      { violation-id: violation-id }
      {
        token-id: token-id,
        violation-type: "public-report",
        amount-exceeded: u0,
        reported-by: tx-sender,
        reported-at: stacks-block-height,
        is-resolved: false,
        penalty-amount: u0
      }
    )
    
    (var-set violation-nonce violation-id)
    (ok violation-id)
  )
)

;; Get compliance summary for a water right
(define-public (get-compliance-summary (token-id uint))
  (let (
    (current-day (get-current-day))
    (today-usage (get-daily-usage token-id current-day))
    (compliance-status (check-compliance-status token-id))
  )
    (ok {
      token-id: token-id,
      current-day: current-day,
      daily-usage: (get amount-used today-usage),
      reports-today: (get reports-count today-usage),
      is-compliant: (get is-compliant compliance-status),
      violation-amount: (get violation-amount compliance-status)
    })
  )
)

;; Emergency quota adjustment (contract owner only)
(define-public (emergency-quota-adjustment (token-id uint) (adjustment-type (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Reset daily usage for emergency situations
    (let (
      (current-day (get-current-day))
    )
      (map-set daily-usage
        { token-id: token-id, day: current-day }
        { amount-used: u0, reports-count: u0 }
      )
    )
    
    (ok true)
  )
)

