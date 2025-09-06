;; Property Tokenization Smart Contract
;; This contract handles the creation and management of tokenized real estate properties

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPERTY-NOT-FOUND (err u101))
(define-constant ERR-PROPERTY-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-INVALID-PROPERTY-TYPE (err u105))
(define-constant ERR-INVALID-ADDRESS (err u106))
(define-constant ERR-PROPERTY-INACTIVE (err u107))
(define-constant ERR-VALUATION-TOO-LOW (err u108))
(define-constant ERR-UNAUTHORIZED-APPRAISER (err u109))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var property-counter uint u0)
(define-data-var total-properties uint u0)
(define-data-var platform-fee uint u250) ;; 2.5% platform fee

;; Property data structure
(define-map properties
  { property-id: uint }
  {
    owner: principal,
    property-address: (string-ascii 200),
    total-value: uint,
    square-footage: uint,
    property-type: (string-ascii 50),
    total-tokens: uint,
    tokens-issued: uint,
    active: bool,
    created-at: uint,
    last-updated: uint
  }
)

;; Property valuation history
(define-map valuation-history
  { property-id: uint, valuation-id: uint }
  {
    appraiser: principal,
    old-value: uint,
    new-value: uint,
    timestamp: uint,
    reason: (string-ascii 200)
  }
)

;; Token holders for each property
(define-map property-tokens
  { property-id: uint, holder: principal }
  { token-balance: uint }
)

;; Authorized appraisers
(define-map authorized-appraisers
  { appraiser: principal }
  { authorized: bool, added-at: uint }
)

;; Property type validation
(define-map valid-property-types
  { property-type: (string-ascii 50) }
  { valid: bool }
)

;; Platform statistics
(define-map platform-stats
  { stat-name: (string-ascii 50) }
  { value: uint }
)

;; Initialize valid property types
(map-set valid-property-types { property-type: "Residential" } { valid: true })
(map-set valid-property-types { property-type: "Commercial" } { valid: true })
(map-set valid-property-types { property-type: "Industrial" } { valid: true })
(map-set valid-property-types { property-type: "Land" } { valid: true })
(map-set valid-property-types { property-type: "Mixed-Use" } { valid: true })

;; Initialize platform stats
(map-set platform-stats { stat-name: "total-value-tokenized" } { value: u0 })
(map-set platform-stats { stat-name: "total-tokens-issued" } { value: u0 })

;; Read-only functions
(define-read-only (get-property-info (property-id uint))
  (map-get? properties { property-id: property-id })
)

(define-read-only (get-property-tokens (property-id uint) (holder principal))
  (default-to
    { token-balance: u0 }
    (map-get? property-tokens { property-id: property-id, holder: holder })
  )
)

(define-read-only (get-total-tokens (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property-data (ok (get total-tokens property-data))
    ERR-PROPERTY-NOT-FOUND
  )
)

(define-read-only (get-tokens-issued (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property-data (ok (get tokens-issued property-data))
    ERR-PROPERTY-NOT-FOUND
  )
)

(define-read-only (get-property-value (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property-data (ok (get total-value property-data))
    ERR-PROPERTY-NOT-FOUND
  )
)

(define-read-only (is-property-active (property-id uint))
  (match (map-get? properties { property-id: property-id })
    property-data (ok (get active property-data))
    ERR-PROPERTY-NOT-FOUND
  )
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-property-counter)
  (ok (var-get property-counter))
)

(define-read-only (get-platform-fee)
  (ok (var-get platform-fee))
)

(define-read-only (is-authorized-appraiser (appraiser principal))
  (match (map-get? authorized-appraisers { appraiser: appraiser })
    appraiser-data (get authorized appraiser-data)
    false
  )
)

(define-read-only (is-valid-property-type (property-type (string-ascii 50)))
  (match (map-get? valid-property-types { property-type: property-type })
    type-data (get valid type-data)
    false
  )
)

(define-read-only (get-valuation-history (property-id uint) (valuation-id uint))
  (map-get? valuation-history { property-id: property-id, valuation-id: valuation-id })
)

(define-read-only (get-platform-stat (stat-name (string-ascii 50)))
  (match (map-get? platform-stats { stat-name: stat-name })
    stat-data (ok (get value stat-data))
    (ok u0)
  )
)

;; Public functions
(define-public (tokenize-property
  (property-address (string-ascii 200))
  (total-value uint)
  (square-footage uint)
  (property-type (string-ascii 50))
  (total-tokens uint)
)
  (let
    (
      (property-id (+ (var-get property-counter) u1))
      (current-time block-height)
    )
    (asserts! (> total-value u0) ERR-INVALID-AMOUNT)
    (asserts! (> square-footage u0) ERR-INVALID-AMOUNT)
    (asserts! (> total-tokens u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len property-address) u0) ERR-INVALID-ADDRESS)
    (asserts! (is-valid-property-type property-type) ERR-INVALID-PROPERTY-TYPE)
    
    ;; Create the property record
    (map-set properties
      { property-id: property-id }
      {
        owner: tx-sender,
        property-address: property-address,
        total-value: total-value,
        square-footage: square-footage,
        property-type: property-type,
        total-tokens: total-tokens,
        tokens-issued: u0,
        active: true,
        created-at: current-time,
        last-updated: current-time
      }
    )
    
    ;; Update counters and stats
    (var-set property-counter property-id)
    (var-set total-properties (+ (var-get total-properties) u1))
    
    ;; Update platform statistics
    (let ((current-total-value (unwrap-panic (get-platform-stat "total-value-tokenized"))))
      (map-set platform-stats 
        { stat-name: "total-value-tokenized" }
        { value: (+ current-total-value total-value) }
      )
    )
    
    (print {
      event: "property-tokenized",
      property-id: property-id,
      owner: tx-sender,
      total-value: total-value,
      total-tokens: total-tokens
    })
    
    (ok property-id)
  )
)

(define-public (issue-tokens (property-id uint) (recipient principal) (token-amount uint))
  (let
    (
      (property-data (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (current-tokens-issued (get tokens-issued property-data))
      (total-tokens (get total-tokens property-data))
      (current-balance (get token-balance (get-property-tokens property-id recipient)))
    )
    (asserts! (is-eq tx-sender (get owner property-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active property-data) ERR-PROPERTY-INACTIVE)
    (asserts! (> token-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ current-tokens-issued token-amount) total-tokens) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update property tokens issued
    (map-set properties
      { property-id: property-id }
      (merge property-data { tokens-issued: (+ current-tokens-issued token-amount) })
    )
    
    ;; Update recipient's token balance
    (map-set property-tokens
      { property-id: property-id, holder: recipient }
      { token-balance: (+ current-balance token-amount) }
    )
    
    ;; Update platform statistics
    (let ((current-total-tokens (unwrap-panic (get-platform-stat "total-tokens-issued"))))
      (map-set platform-stats 
        { stat-name: "total-tokens-issued" }
        { value: (+ current-total-tokens token-amount) }
      )
    )
    
    (print {
      event: "tokens-issued",
      property-id: property-id,
      recipient: recipient,
      amount: token-amount
    })
    
    (ok true)
  )
)

(define-public (update-property-value (property-id uint) (new-value uint) (reason (string-ascii 200)))
  (let
    (
      (property-data (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (old-value (get total-value property-data))
      (current-time block-height)
      (valuation-id (+ property-id (* current-time u1000)))
    )
    (asserts! (or 
      (is-eq tx-sender (get owner property-data))
      (is-authorized-appraiser tx-sender)
    ) ERR-NOT-AUTHORIZED)
    (asserts! (> new-value u0) ERR-VALUATION-TOO-LOW)
    (asserts! (get active property-data) ERR-PROPERTY-INACTIVE)
    
    ;; Update property value and timestamp
    (map-set properties
      { property-id: property-id }
      (merge property-data { 
        total-value: new-value,
        last-updated: current-time 
      })
    )
    
    ;; Record valuation history
    (map-set valuation-history
      { property-id: property-id, valuation-id: valuation-id }
      {
        appraiser: tx-sender,
        old-value: old-value,
        new-value: new-value,
        timestamp: current-time,
        reason: reason
      }
    )
    
    (print {
      event: "property-revalued",
      property-id: property-id,
      old-value: old-value,
      new-value: new-value,
      appraiser: tx-sender
    })
    
    (ok true)
  )
)

(define-public (deactivate-property (property-id uint))
  (let
    (
      (property-data (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner property-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active property-data) ERR-PROPERTY-INACTIVE)
    
    ;; Deactivate property
    (map-set properties
      { property-id: property-id }
      (merge property-data { active: false })
    )
    
    (print {
      event: "property-deactivated",
      property-id: property-id,
      owner: tx-sender
    })
    
    (ok true)
  )
)

(define-public (authorize-appraiser (appraiser principal))
  (let
    (
      (current-time block-height)
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (map-set authorized-appraisers
      { appraiser: appraiser }
      { authorized: true, added-at: current-time }
    )
    
    (print {
      event: "appraiser-authorized",
      appraiser: appraiser,
      authorized-by: tx-sender
    })
    
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT) ;; Max 10% fee
    
    (var-set platform-fee new-fee)
    
    (print {
      event: "platform-fee-updated",
      old-fee: (var-get platform-fee),
      new-fee: new-fee
    })
    
    (ok true)
  )
)

(define-public (transfer-ownership (property-id uint) (new-owner principal))
  (let
    (
      (property-data (unwrap! (map-get? properties { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner property-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get active property-data) ERR-PROPERTY-INACTIVE)
    
    ;; Transfer ownership
    (map-set properties
      { property-id: property-id }
      (merge property-data { owner: new-owner })
    )
    
    (print {
      event: "property-ownership-transferred",
      property-id: property-id,
      old-owner: tx-sender,
      new-owner: new-owner
    })
    
    (ok true)
  )
)


;; title: property-tokenization
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

