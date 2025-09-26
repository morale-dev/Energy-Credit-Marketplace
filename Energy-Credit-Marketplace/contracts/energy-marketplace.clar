;; Energy Credit Marketplace
;; Tokenized renewable energy credit trading with advanced features

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-expired-credit (err u105))
(define-constant err-invalid-price (err u106))
(define-constant err-auction-ended (err u107))
(define-constant err-bid-too-low (err u108))
(define-constant err-contract-paused (err u109))
(define-constant err-invalid-certificate (err u110))

(define-fungible-token energy-credit)

(define-map credit-issuers
  principal
  {
    name: (string-ascii 64),
    energy-type: (string-ascii 32),
    verified: bool,
    total-issued: uint,
    registration-date: uint,
    reputation-score: uint,
    country: (string-ascii 32),
    certification: (string-ascii 64)
  })

(define-map energy-credits
  uint
  {
    issuer: principal,
    owner: principal,
    energy-type: (string-ascii 32),
    amount: uint,
    price-per-unit: uint,
    issue-date: uint,
    expiry-date: uint,
    location: (string-ascii 128),
    verified: bool,
    carbon-offset: uint,
    certificate-hash: (string-ascii 64)
  })

(define-map marketplace-listings
  uint
  {
    seller: principal,
    credit-id: uint,
    amount: uint,
    price-per-unit: uint,
    listed-at: uint,
    active: bool,
    listing-type: (string-ascii 16) ;; "fixed" or "auction"
  })

(define-map credit-auctions
  uint
  {
    credit-id: uint,
    seller: principal,
    starting-price: uint,
    current-bid: uint,
    highest-bidder: (optional principal),
    auction-end: uint,
    min-increment: uint,
    active: bool
  })

(define-map user-profiles
  principal
  {
    name: (string-ascii 64),
    email: (string-ascii 128),
    carbon-footprint: uint,
    credits-purchased: uint,
    credits-retired: uint,
    join-date: uint,
    verified: bool
  })

(define-map credit-transactions
  uint
  {
    from: principal,
    to: principal,
    credit-id: uint,
    amount: uint,
    price: uint,
    transaction-date: uint,
    transaction-type: (string-ascii 32)
  })

(define-data-var next-credit-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-auction-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var min-auction-duration uint u1440) ;; 1440 blocks (~1 day)

(define-public (register-as-issuer 
  (name (string-ascii 64))
  (energy-type (string-ascii 32))
  (country (string-ascii 32))
  (certification (string-ascii 64)))
  (let ((caller tx-sender))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-none (map-get? credit-issuers caller)) err-unauthorized)
    (ok (map-set credit-issuers caller {
      name: name,
      energy-type: energy-type,
      verified: false,
      total-issued: u0,
      registration-date: block-height,
      reputation-score: u100,
      country: country,
      certification: certification
    }))))

(define-public (verify-issuer (issuer principal))
  (let ((issuer-info (unwrap! (map-get? credit-issuers issuer) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set credit-issuers issuer
      (merge issuer-info {verified: true})))))

(define-public (update-issuer-reputation (issuer principal) (new-score uint))
  (let ((issuer-info (unwrap! (map-get? credit-issuers issuer) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set credit-issuers issuer
      (merge issuer-info {reputation-score: new-score})))))

(define-public (issue-energy-credit 
  (amount uint)
  (price-per-unit uint)
  (expiry-date uint)
  (location (string-ascii 128))
  (carbon-offset uint)
  (certificate-hash (string-ascii 64)))
  (let ((caller tx-sender)
        (credit-id (var-get next-credit-id))
        (issuer-info (unwrap! (map-get? credit-issuers caller) err-not-found)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get verified issuer-info) err-unauthorized)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> expiry-date block-height) err-invalid-amount)
    
    (try! (ft-mint? energy-credit amount caller))
    
    (map-set energy-credits credit-id {
      issuer: caller,
      owner: caller,
      energy-type: (get energy-type issuer-info),
      amount: amount,
      price-per-unit: price-per-unit,
      issue-date: block-height,
      expiry-date: expiry-date,
      location: location,
      verified: true,
      carbon-offset: carbon-offset,
      certificate-hash: certificate-hash
    })
    
    (map-set credit-issuers caller
      (merge issuer-info {total-issued: (+ (get total-issued issuer-info) amount)}))
    
    (var-set next-credit-id (+ credit-id u1))
    (ok credit-id)))
