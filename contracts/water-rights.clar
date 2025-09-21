;; Water Rights NFT Contract
;; Manages water rights as Non-Fungible Tokens with quota and geographic restrictions

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_TOKEN (err u405))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_PARAMS (err u400))
(define-constant ERR_EXPIRED (err u410))
(define-constant ERR_INSUFFICIENT_QUOTA (err u411))
(define-constant ERR_GEOGRAPHIC_VIOLATION (err u412))

;; Define data variables
(define-data-var token-id-nonce uint u0)
(define-data-var contract-uri (optional (string-ascii 256)) none)

;; NFT trait implementation
(define-non-fungible-token water-right uint)

;; Water right data structure
(define-map water-rights
  { token-id: uint }
  {
    quota-amount: uint,
    used-amount: uint,
    location-x: uint,
    location-y: uint,
    valid-from: uint,
    valid-until: uint,
    usage-type: (string-ascii 32),
    issuer: principal,
    transfer-count: uint,
    is-active: bool
  }
)

;; Authority permissions
(define-map authorities
  { authority: principal }
  { can-mint: bool, can-revoke: bool, region: (string-ascii 64) }
)

;; Token metadata
(define-map token-metadata
  { token-id: uint }
  {
    name: (string-ascii 256),
    description: (string-ascii 512),
    image: (optional (string-ascii 256))
  }
)

;; Read-only functions

;; Get the last token ID
(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce))
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (ok (var-get contract-uri))
)

;; Get owner of token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? water-right token-id))
)

;; Get water right details
(define-read-only (get-water-right (token-id uint))
  (map-get? water-rights { token-id: token-id })
)

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata { token-id: token-id })
)

;; Check if authority can mint
(define-read-only (is-authorized-authority (authority principal))
  (match (map-get? authorities { authority: authority })
    auth-data (get can-mint auth-data)
    false
  )
)

;; Calculate remaining quota
(define-read-only (get-remaining-quota (token-id uint))
  (match (get-water-right token-id)
    right-data 
    (let (
      (quota (get quota-amount right-data))
      (used (get used-amount right-data))
    )
      (ok (- quota used))
    )
    (err ERR_NOT_FOUND)
  )
)

;; Check if water right is valid (not expired)
(define-read-only (is-valid-period (token-id uint))
  (match (get-water-right token-id)
    right-data
    (let (
      (current-time stacks-block-height)
      (valid-from (get valid-from right-data))
      (valid-until (get valid-until right-data))
    )
      (and (>= current-time valid-from) (<= current-time valid-until))
    )
    false
  )
)

;; Check geographic bounds
(define-read-only (is-within-bounds (token-id uint) (x uint) (y uint) (tolerance uint))
  (match (get-water-right token-id)
    right-data
    (let (
      (right-x (get location-x right-data))
      (right-y (get location-y right-data))
      (x-diff (if (>= x right-x) (- x right-x) (- right-x x)))
      (y-diff (if (>= y right-y) (- y right-y) (- right-y y)))
    )
      (and (<= x-diff tolerance) (<= y-diff tolerance))
    )
    false
  )
)

;; Public functions

;; Add or update authority
(define-public (set-authority (authority principal) (can-mint bool) (can-revoke bool) (region (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorities
      { authority: authority }
      { can-mint: can-mint, can-revoke: can-revoke, region: region }
    )
    (ok true)
  )
)

;; Mint new water right NFT
(define-public (mint-water-right 
  (recipient principal)
  (quota-amount uint)
  (location-x uint)
  (location-y uint)
  (valid-from uint)
  (valid-until uint)
  (usage-type (string-ascii 32))
  (name (string-ascii 256))
  (description (string-ascii 512))
)
  (let (
    (token-id (+ (var-get token-id-nonce) u1))
  )
    ;; Verify authority
    (asserts! (is-authorized-authority tx-sender) ERR_UNAUTHORIZED)
    
    ;; Validate parameters
    (asserts! (> quota-amount u0) ERR_INVALID_PARAMS)
    (asserts! (> valid-until valid-from) ERR_INVALID_PARAMS)
    (asserts! (> valid-until stacks-block-height) ERR_INVALID_PARAMS)
    
    ;; Mint the NFT
    (try! (nft-mint? water-right token-id recipient))
    
    ;; Store water right data
    (map-set water-rights
      { token-id: token-id }
      {
        quota-amount: quota-amount,
        used-amount: u0,
        location-x: location-x,
        location-y: location-y,
        valid-from: valid-from,
        valid-until: valid-until,
        usage-type: usage-type,
        issuer: tx-sender,
        transfer-count: u0,
        is-active: true
      }
    )
    
    ;; Store metadata
    (map-set token-metadata
      { token-id: token-id }
      {
        name: name,
        description: description,
        image: none
      }
    )
    
    ;; Update nonce
    (var-set token-id-nonce token-id)
    
    (ok token-id)
  )
)

;; Transfer water right
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let (
    (right-data (unwrap! (get-water-right token-id) ERR_NOT_FOUND))
  )
    ;; Verify ownership
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    
    ;; Verify token is active
    (asserts! (get is-active right-data) ERR_INVALID_TOKEN)
    
    ;; Verify not expired
    (asserts! (is-valid-period token-id) ERR_EXPIRED)
    
    ;; Execute transfer
    (try! (nft-transfer? water-right token-id sender recipient))
    
    ;; Update transfer count
    (map-set water-rights
      { token-id: token-id }
      (merge right-data { transfer-count: (+ (get transfer-count right-data) u1) })
    )
    
    (ok true)
  )
)

;; Burn water right (permanent destruction)
(define-public (burn (token-id uint))
  (let (
    (owner (unwrap! (nft-get-owner? water-right token-id) ERR_NOT_FOUND))
    (right-data (unwrap! (get-water-right token-id) ERR_NOT_FOUND))
  )
    ;; Only owner or issuer can burn
    (asserts! (or (is-eq tx-sender owner) 
                  (is-eq tx-sender (get issuer right-data))) ERR_UNAUTHORIZED)
    
    ;; Burn the NFT
    (try! (nft-burn? water-right token-id owner))
    
    ;; Deactivate the water right
    (map-set water-rights
      { token-id: token-id }
      (merge right-data { is-active: false })
    )
    
    (ok true)
  )
)

;; Record water usage (can only be called by quota-manager)
(define-public (record-usage (token-id uint) (amount uint))
  (let (
    (right-data (unwrap! (get-water-right token-id) ERR_NOT_FOUND))
    (new-used-amount (+ (get used-amount right-data) amount))
  )
    ;; Verify quota manager is calling (simplified - in production would verify contract address)
    (asserts! (is-eq contract-caller tx-sender) ERR_UNAUTHORIZED)
    
    ;; Verify not exceeding quota
    (asserts! (<= new-used-amount (get quota-amount right-data)) ERR_INSUFFICIENT_QUOTA)
    
    ;; Verify token is active and valid
    (asserts! (get is-active right-data) ERR_INVALID_TOKEN)
    (asserts! (is-valid-period token-id) ERR_EXPIRED)
    
    ;; Update usage
    (map-set water-rights
      { token-id: token-id }
      (merge right-data { used-amount: new-used-amount })
    )
    
    (ok true)
  )
)

;; Update token metadata (only by owner)
(define-public (update-metadata (token-id uint) (name (string-ascii 256)) (description (string-ascii 512)))
  (let (
    (owner (unwrap! (nft-get-owner? water-right token-id) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    
    (map-set token-metadata
      { token-id: token-id }
      {
        name: name,
        description: description,
        image: none
      }
    )
    
    (ok true)
  )
)

;; Set contract URI (only contract owner)
(define-public (set-contract-uri (uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-uri (some uri))
    (ok true)
  )
)

;; Emergency pause/unpause water right (only issuer or contract owner)
(define-public (toggle-water-right-status (token-id uint))
  (let (
    (right-data (unwrap! (get-water-right token-id) ERR_NOT_FOUND))
  )
    ;; Only issuer or contract owner can toggle
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get issuer right-data))) ERR_UNAUTHORIZED)
    
    (map-set water-rights
      { token-id: token-id }
      (merge right-data { is-active: (not (get is-active right-data)) })
    )
    
    (ok true)
  )
)

