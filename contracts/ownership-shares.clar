;; Ownership Shares Smart Contract
;; This contract manages fractional ownership of tokenized properties

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PROPERTY-NOT-FOUND (err u201))
(define-constant ERR-INSUFFICIENT-SHARES (err u202))
(define-constant ERR-INVALID-AMOUNT (err u203))
(define-constant ERR-INVALID-PRICE (err u204))
(define-constant ERR-SHARES-NOT-FOR-SALE (err u205))
(define-constant ERR-CANNOT-BUY-OWN-SHARES (err u206))
(define-constant ERR-PROPERTY-INACTIVE (err u207))
(define-constant ERR-TRANSFER-RESTRICTED (err u208))
(define-constant ERR-INVALID-PERCENTAGE (err u209))
(define-constant ERR-SHAREHOLDER-NOT-FOUND (err u210))
(define-constant ERR-MARKETPLACE-INACTIVE (err u211))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u212))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var marketplace-active bool true)
(define-data-var transaction-fee uint u100) ;; 1% transaction fee
(define-data-var min-share-amount uint u1)
(define-data-var total-transactions uint u0)

;; Shareholder data structure
(define-map shareholders
  { property-id: uint, holder: principal }
  {
    shares-owned: uint,
    total-invested: uint,
    purchase-price: uint,
    acquired-at: uint,
    last-activity: uint,
    voting-power: uint,
    dividend-claimed: uint
  }
)

;; Share listing for marketplace
(define-map share-listings
  { property-id: uint, seller: principal }
  {
    shares-for-sale: uint,
    price-per-share: uint,
    listed-at: uint,
    active: bool,
    min-purchase: uint
  }
)

;; Property share registry
(define-map property-shares
  { property-id: uint }
  {
    total-shares: uint,
    shares-outstanding: uint,
    total-shareholders: uint,
    share-price: uint,
    last-trade-price: uint,
    trading-active: bool,
    created-at: uint
  }
)

;; Transaction history
(define-map transaction-history
  { transaction-id: uint }
  {
    property-id: uint,
    buyer: principal,
    seller: principal,
    shares-transferred: uint,
    price-per-share: uint,
    total-amount: uint,
    transaction-fee: uint,
    timestamp: uint,
    transaction-type: (string-ascii 50)
  }
)

;; Share transfer restrictions
(define-map transfer-restrictions
  { property-id: uint }
  {
    restricted: bool,
    whitelist-only: bool,
    min-holding-period: uint,
    max-ownership-percentage: uint
  }
)

;; Approved transfer addresses (whitelist)
(define-map approved-addresses
  { property-id: uint, address: principal }
  { approved: bool, approved-at: uint }
)

;; Dividend distribution tracking
(define-map dividend-distributions
  { property-id: uint, distribution-id: uint }
  {
    total-amount: uint,
    per-share-amount: uint,
    distribution-date: uint,
    claimed-amount: uint,
    eligible-shares: uint
  }
)

;; Read-only functions
(define-read-only (get-shareholder-info (property-id uint) (holder principal))
  (map-get? shareholders { property-id: property-id, holder: holder })
)

(define-read-only (get-shares-owned (property-id uint) (holder principal))
  (match (map-get? shareholders { property-id: property-id, holder: holder })
    shareholder-data (get shares-owned shareholder-data)
    u0
  )
)

(define-read-only (get-ownership-percentage (property-id uint) (holder principal))
  (let
    (
      (shares-owned (get-shares-owned property-id holder))
      (property-data (unwrap! (map-get? property-shares { property-id: property-id }) (err u0)))
      (total-shares (get total-shares property-data))
    )
    (if (> total-shares u0)
      (ok (/ (* shares-owned u10000) total-shares)) ;; Return percentage * 100 for precision
      (ok u0)
    )
  )
)

(define-read-only (get-property-shares-info (property-id uint))
  (map-get? property-shares { property-id: property-id })
)

(define-read-only (get-share-listing (property-id uint) (seller principal))
  (map-get? share-listings { property-id: property-id, seller: seller })
)

(define-read-only (get-transaction-history (transaction-id uint))
  (map-get? transaction-history { transaction-id: transaction-id })
)

(define-read-only (get-transfer-restrictions (property-id uint))
  (map-get? transfer-restrictions { property-id: property-id })
)

(define-read-only (is-approved-address (property-id uint) (address principal))
  (match (map-get? approved-addresses { property-id: property-id, address: address })
    approval-data (get approved approval-data)
    false
  )
)

(define-read-only (get-dividend-info (property-id uint) (distribution-id uint))
  (map-get? dividend-distributions { property-id: property-id, distribution-id: distribution-id })
)

(define-read-only (get-marketplace-status)
  (ok (var-get marketplace-active))
)

(define-read-only (get-transaction-fee)
  (ok (var-get transaction-fee))
)

(define-read-only (get-total-transactions)
  (ok (var-get total-transactions))
)

;; Public functions
(define-public (initialize-property-shares
  (property-id uint)
  (total-shares uint)
  (initial-price uint)
)
  (let
    (
      (current-time block-height)
    )
    (asserts! (> total-shares u0) ERR-INVALID-AMOUNT)
    (asserts! (> initial-price u0) ERR-INVALID-PRICE)
    (asserts! (is-none (map-get? property-shares { property-id: property-id })) ERR-PROPERTY-NOT-FOUND)
    
    ;; Initialize property share registry
    (map-set property-shares
      { property-id: property-id }
      {
        total-shares: total-shares,
        shares-outstanding: u0,
        total-shareholders: u0,
        share-price: initial-price,
        last-trade-price: initial-price,
        trading-active: true,
        created-at: current-time
      }
    )
    
    ;; Set default transfer restrictions
    (map-set transfer-restrictions
      { property-id: property-id }
      {
        restricted: false,
        whitelist-only: false,
        min-holding-period: u0,
        max-ownership-percentage: u5000 ;; 50% max ownership
      }
    )
    
    (print {
      event: "property-shares-initialized",
      property-id: property-id,
      total-shares: total-shares,
      initial-price: initial-price
    })
    
    (ok true)
  )
)

(define-public (buy-shares (property-id uint) (shares-amount uint) (max-price-per-share uint))
  (let
    (
      (property-data (unwrap! (map-get? property-shares { property-id: property-id }) ERR-PROPERTY-NOT-FOUND))
      (current-shareholder (default-to
        { shares-owned: u0, total-invested: u0, purchase-price: u0, acquired-at: u0, last-activity: u0, voting-power: u0, dividend-claimed: u0 }
        (map-get? shareholders { property-id: property-id, holder: tx-sender })
      ))
      (current-time block-height)
      (share-price (get share-price property-data))
      (total-cost (* shares-amount share-price))
      (fee-amount (/ (* total-cost (var-get transaction-fee)) u10000))
      (new-shares-outstanding (+ (get shares-outstanding property-data) shares-amount))
      (current-ownership-percentage (unwrap-panic (get-ownership-percentage property-id tx-sender)))
      (new-ownership-percentage (/ (* (+ (get shares-owned current-shareholder) shares-amount) u10000) (get total-shares property-data)))
      (restrictions (default-to
        { restricted: false, whitelist-only: false, min-holding-period: u0, max-ownership-percentage: u5000 }
        (map-get? transfer-restrictions { property-id: property-id })
      ))
    )
    (asserts! (var-get marketplace-active) ERR-MARKETPLACE-INACTIVE)
    (asserts! (get trading-active property-data) ERR-PROPERTY-INACTIVE)
    (asserts! (> shares-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= share-price max-price-per-share) ERR-INVALID-PRICE)
    (asserts! (<= new-shares-outstanding (get total-shares property-data)) ERR-INSUFFICIENT-SHARES)
    (asserts! (<= new-ownership-percentage (get max-ownership-percentage restrictions)) ERR-INVALID-PERCENTAGE)
    
    ;; Check whitelist if required
    (if (get whitelist-only restrictions)
      (asserts! (is-approved-address property-id tx-sender) ERR-NOT-AUTHORIZED)
      true
    )
    
    ;; Update property shares data
    (map-set property-shares
      { property-id: property-id }
      (merge property-data {
        shares-outstanding: new-shares-outstanding,
        last-trade-price: share-price,
        total-shareholders: (if (is-eq (get shares-owned current-shareholder) u0)
          (+ (get total-shareholders property-data) u1)
          (get total-shareholders property-data)
        )
      })
    )
    
    ;; Update or create shareholder record
    (map-set shareholders
      { property-id: property-id, holder: tx-sender }
      {
        shares-owned: (+ (get shares-owned current-shareholder) shares-amount),
        total-invested: (+ (get total-invested current-shareholder) total-cost),
        purchase-price: (if (is-eq (get shares-owned current-shareholder) u0)
          share-price
          (/ (+ (get total-invested current-shareholder) total-cost) (+ (get shares-owned current-shareholder) shares-amount))
        ),
        acquired-at: (if (is-eq (get shares-owned current-shareholder) u0) current-time (get acquired-at current-shareholder)),
        last-activity: current-time,
        voting-power: (+ (get shares-owned current-shareholder) shares-amount),
        dividend-claimed: (get dividend-claimed current-shareholder)
      }
    )
    
    ;; Record transaction
    (let ((transaction-id (+ (var-get total-transactions) u1)))
      (map-set transaction-history
        { transaction-id: transaction-id }
        {
          property-id: property-id,
          buyer: tx-sender,
          seller: (var-get contract-owner), ;; Initial sale from contract
          shares-transferred: shares-amount,
          price-per-share: share-price,
          total-amount: total-cost,
          transaction-fee: fee-amount,
          timestamp: current-time,
          transaction-type: "primary-purchase"
        }
      )
      (var-set total-transactions transaction-id)
    )
    
    (print {
      event: "shares-purchased",
      property-id: property-id,
      buyer: tx-sender,
      shares-amount: shares-amount,
      total-cost: total-cost,
      fee: fee-amount
    })
    
    (ok true)
  )
)

(define-public (list-shares-for-sale
  (property-id uint)
  (shares-amount uint)
  (price-per-share uint)
  (min-purchase uint)
)
  (let
    (
      (shareholder-data (unwrap! (map-get? shareholders { property-id: property-id, holder: tx-sender }) ERR-SHAREHOLDER-NOT-FOUND))
      (current-time block-height)
      (restrictions (default-to
        { restricted: false, whitelist-only: false, min-holding-period: u0, max-ownership-percentage: u5000 }
        (map-get? transfer-restrictions { property-id: property-id })
      ))
    )
    (asserts! (var-get marketplace-active) ERR-MARKETPLACE-INACTIVE)
    (asserts! (not (get restricted restrictions)) ERR-TRANSFER-RESTRICTED)
    (asserts! (>= (get shares-owned shareholder-data) shares-amount) ERR-INSUFFICIENT-SHARES)
    (asserts! (> price-per-share u0) ERR-INVALID-PRICE)
    (asserts! (> shares-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (- current-time (get acquired-at shareholder-data)) (get min-holding-period restrictions)) ERR-TRANSFER-RESTRICTED)
    
    ;; Create or update share listing
    (map-set share-listings
      { property-id: property-id, seller: tx-sender }
      {
        shares-for-sale: shares-amount,
        price-per-share: price-per-share,
        listed-at: current-time,
        active: true,
        min-purchase: min-purchase
      }
    )
    
    (print {
      event: "shares-listed-for-sale",
      property-id: property-id,
      seller: tx-sender,
      shares-amount: shares-amount,
      price-per-share: price-per-share
    })
    
    (ok true)
  )
)

(define-public (buy-listed-shares
  (property-id uint)
  (seller principal)
  (shares-amount uint)
  (max-price-per-share uint)
)
  (let
    (
      (listing-data (unwrap! (map-get? share-listings { property-id: property-id, seller: seller }) ERR-SHARES-NOT-FOR-SALE))
      (seller-data (unwrap! (map-get? shareholders { property-id: property-id, holder: seller }) ERR-SHAREHOLDER-NOT-FOUND))
      (buyer-data (default-to
        { shares-owned: u0, total-invested: u0, purchase-price: u0, acquired-at: u0, last-activity: u0, voting-power: u0, dividend-claimed: u0 }
        (map-get? shareholders { property-id: property-id, holder: tx-sender })
      ))
      (current-time block-height)
      (price-per-share (get price-per-share listing-data))
      (total-cost (* shares-amount price-per-share))
      (fee-amount (/ (* total-cost (var-get transaction-fee)) u10000))
      (seller-proceeds (- total-cost fee-amount))
    )
    (asserts! (var-get marketplace-active) ERR-MARKETPLACE-INACTIVE)
    (asserts! (get active listing-data) ERR-SHARES-NOT-FOR-SALE)
    (asserts! (not (is-eq tx-sender seller)) ERR-CANNOT-BUY-OWN-SHARES)
    (asserts! (>= (get shares-for-sale listing-data) shares-amount) ERR-INSUFFICIENT-SHARES)
    (asserts! (<= price-per-share max-price-per-share) ERR-INVALID-PRICE)
    (asserts! (>= shares-amount (get min-purchase listing-data)) ERR-INVALID-AMOUNT)
    
    ;; Update seller's shares
    (map-set shareholders
      { property-id: property-id, holder: seller }
      (merge seller-data {
        shares-owned: (- (get shares-owned seller-data) shares-amount),
        last-activity: current-time
      })
    )
    
    ;; Update buyer's shares
    (map-set shareholders
      { property-id: property-id, holder: tx-sender }
      {
        shares-owned: (+ (get shares-owned buyer-data) shares-amount),
        total-invested: (+ (get total-invested buyer-data) total-cost),
        purchase-price: (if (is-eq (get shares-owned buyer-data) u0)
          price-per-share
          (/ (+ (get total-invested buyer-data) total-cost) (+ (get shares-owned buyer-data) shares-amount))
        ),
        acquired-at: (if (is-eq (get shares-owned buyer-data) u0) current-time (get acquired-at buyer-data)),
        last-activity: current-time,
        voting-power: (+ (get shares-owned buyer-data) shares-amount),
        dividend-claimed: (get dividend-claimed buyer-data)
      }
    )
    
    ;; Update or remove listing
    (let ((remaining-shares (- (get shares-for-sale listing-data) shares-amount)))
      (if (is-eq remaining-shares u0)
        (map-set share-listings
          { property-id: property-id, seller: seller }
          (merge listing-data { active: false })
        )
        (map-set share-listings
          { property-id: property-id, seller: seller }
          (merge listing-data { shares-for-sale: remaining-shares })
        )
      )
    )
    
    ;; Record transaction
    (let ((transaction-id (+ (var-get total-transactions) u1)))
      (map-set transaction-history
        { transaction-id: transaction-id }
        {
          property-id: property-id,
          buyer: tx-sender,
          seller: seller,
          shares-transferred: shares-amount,
          price-per-share: price-per-share,
          total-amount: total-cost,
          transaction-fee: fee-amount,
          timestamp: current-time,
          transaction-type: "secondary-sale"
        }
      )
      (var-set total-transactions transaction-id)
    )
    
    (print {
      event: "shares-sold",
      property-id: property-id,
      buyer: tx-sender,
      seller: seller,
      shares-amount: shares-amount,
      total-cost: total-cost,
      seller-proceeds: seller-proceeds
    })
    
    (ok true)
  )
)

(define-public (transfer-shares
  (property-id uint)
  (recipient principal)
  (shares-amount uint)
)
  (let
    (
      (sender-data (unwrap! (map-get? shareholders { property-id: property-id, holder: tx-sender }) ERR-SHAREHOLDER-NOT-FOUND))
      (recipient-data (default-to
        { shares-owned: u0, total-invested: u0, purchase-price: u0, acquired-at: u0, last-activity: u0, voting-power: u0, dividend-claimed: u0 }
        (map-get? shareholders { property-id: property-id, holder: recipient })
      ))
      (current-time block-height)
      (restrictions (default-to
        { restricted: false, whitelist-only: false, min-holding-period: u0, max-ownership-percentage: u5000 }
        (map-get? transfer-restrictions { property-id: property-id })
      ))
    )
    (asserts! (not (get restricted restrictions)) ERR-TRANSFER-RESTRICTED)
    (asserts! (>= (get shares-owned sender-data) shares-amount) ERR-INSUFFICIENT-SHARES)
    (asserts! (> shares-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq tx-sender recipient)) ERR-CANNOT-BUY-OWN-SHARES)
    (asserts! (>= (- current-time (get acquired-at sender-data)) (get min-holding-period restrictions)) ERR-TRANSFER-RESTRICTED)
    
    ;; Check whitelist for recipient if required
    (if (get whitelist-only restrictions)
      (asserts! (is-approved-address property-id recipient) ERR-NOT-AUTHORIZED)
      true
    )
    
    ;; Update sender's shares
    (map-set shareholders
      { property-id: property-id, holder: tx-sender }
      (merge sender-data {
        shares-owned: (- (get shares-owned sender-data) shares-amount),
        last-activity: current-time
      })
    )
    
    ;; Update recipient's shares
    (map-set shareholders
      { property-id: property-id, holder: recipient }
      {
        shares-owned: (+ (get shares-owned recipient-data) shares-amount),
        total-invested: (get total-invested recipient-data),
        purchase-price: (get purchase-price recipient-data),
        acquired-at: (if (is-eq (get shares-owned recipient-data) u0) current-time (get acquired-at recipient-data)),
        last-activity: current-time,
        voting-power: (+ (get shares-owned recipient-data) shares-amount),
        dividend-claimed: (get dividend-claimed recipient-data)
      }
    )
    
    ;; Record transaction
    (let ((transaction-id (+ (var-get total-transactions) u1)))
      (map-set transaction-history
        { transaction-id: transaction-id }
        {
          property-id: property-id,
          buyer: recipient,
          seller: tx-sender,
          shares-transferred: shares-amount,
          price-per-share: u0,
          total-amount: u0,
          transaction-fee: u0,
          timestamp: current-time,
          transaction-type: "transfer"
        }
      )
      (var-set total-transactions transaction-id)
    )
    
    (print {
      event: "shares-transferred",
      property-id: property-id,
      from: tx-sender,
      to: recipient,
      shares-amount: shares-amount
    })
    
    (ok true)
  )
)

(define-public (set-transfer-restrictions
  (property-id uint)
  (restricted bool)
  (whitelist-only bool)
  (min-holding-period uint)
  (max-ownership-percentage uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= max-ownership-percentage u10000) ERR-INVALID-PERCENTAGE)
    
    (map-set transfer-restrictions
      { property-id: property-id }
      {
        restricted: restricted,
        whitelist-only: whitelist-only,
        min-holding-period: min-holding-period,
        max-ownership-percentage: max-ownership-percentage
      }
    )
    
    (print {
      event: "transfer-restrictions-updated",
      property-id: property-id,
      restricted: restricted,
      whitelist-only: whitelist-only
    })
    
    (ok true)
  )
)

(define-public (approve-address (property-id uint) (address principal))
  (let
    (
      (current-time block-height)
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (map-set approved-addresses
      { property-id: property-id, address: address }
      { approved: true, approved-at: current-time }
    )
    
    (print {
      event: "address-approved",
      property-id: property-id,
      address: address
    })
    
    (ok true)
  )
)

(define-public (toggle-marketplace (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (var-set marketplace-active active)
    
    (print {
      event: "marketplace-toggled",
      active: active
    })
    
    (ok true)
  )
)


;; title: ownership-shares
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

