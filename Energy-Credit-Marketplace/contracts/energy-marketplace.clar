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
      registration-date: stacks-block-height,
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
    (asserts! (> expiry-date stacks-block-height) err-invalid-amount)
    
    (try! (ft-mint? energy-credit amount caller))
    
    (map-set energy-credits credit-id {
      issuer: caller,
      owner: caller,
      energy-type: (get energy-type issuer-info),
      amount: amount,
      price-per-unit: price-per-unit,
      issue-date: stacks-block-height,
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

(define-public (list-credit-for-sale 
  (credit-id uint)
  (amount uint)
  (price-per-unit uint))
  (let ((caller tx-sender)
        (credit (unwrap! (map-get? energy-credits credit-id) err-not-found))
        (listing-id (var-get next-listing-id)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq caller (get owner credit)) err-unauthorized)
    (asserts! (>= (get amount credit) amount) err-insufficient-balance)
    (asserts! (> (get expiry-date credit) stacks-block-height) err-expired-credit)
    (asserts! (>= (ft-get-balance energy-credit caller) amount) err-insufficient-balance)
    (asserts! (> price-per-unit u0) err-invalid-price)
    
    (map-set marketplace-listings listing-id {
      seller: caller,
      credit-id: credit-id,
      amount: amount,
      price-per-unit: price-per-unit,
      listed-at: stacks-block-height,
      active: true,
      listing-type: "fixed"
    })
    
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)))

(define-public (create-credit-auction
  (credit-id uint)
  (amount uint)
  (starting-price uint)
  (auction-duration uint)
  (min-increment uint))
  (let ((caller tx-sender)
        (credit (unwrap! (map-get? energy-credits credit-id) err-not-found))
        (auction-id (var-get next-auction-id)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq caller (get owner credit)) err-unauthorized)
    (asserts! (>= (get amount credit) amount) err-insufficient-balance)
    (asserts! (> (get expiry-date credit) stacks-block-height) err-expired-credit)
    (asserts! (>= auction-duration (var-get min-auction-duration)) err-invalid-amount)
    
    (map-set credit-auctions auction-id {
      credit-id: credit-id,
      seller: caller,
      starting-price: starting-price,
      current-bid: u0,
      highest-bidder: none,
      auction-end: (+ stacks-block-height auction-duration),
      min-increment: min-increment,
      active: true
    })
    
    (var-set next-auction-id (+ auction-id u1))
    (ok auction-id)))

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let ((caller tx-sender)
        (auction (unwrap! (map-get? credit-auctions auction-id) err-not-found)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get active auction) err-auction-ended)
    (asserts! (< stacks-block-height (get auction-end auction)) err-auction-ended)
    (asserts! (>= (stx-get-balance caller) bid-amount) err-insufficient-balance)
    
    (let ((required-bid (if (is-eq (get current-bid auction) u0)
                          (get starting-price auction)
                          (+ (get current-bid auction) (get min-increment auction)))))
      (asserts! (>= bid-amount required-bid) err-bid-too-low)
      
      ;; Return funds to previous highest bidder
      (match (get highest-bidder auction)
        prev-bidder (try! (stx-transfer? (get current-bid auction) tx-sender prev-bidder))
        true)
      
      ;; Escrow new bid
      (try! (stx-transfer? bid-amount caller tx-sender))
      
      (map-set credit-auctions auction-id
        (merge auction {
          current-bid: bid-amount,
          highest-bidder: (some caller)
        }))
      
      (ok true))))

(define-public (purchase-energy-credit (listing-id uint) (amount uint))
  (let ((caller tx-sender)
        (listing (unwrap! (map-get? marketplace-listings listing-id) err-not-found))
        (credit (unwrap! (map-get? energy-credits (get credit-id listing)) err-not-found))
        (transaction-id (var-get next-transaction-id)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (get active listing) err-not-found)
    (asserts! (>= (get amount listing) amount) err-insufficient-balance)
    (asserts! (> (get expiry-date credit) stacks-block-height) err-expired-credit)
    
    (let ((total-cost (* amount (get price-per-unit listing)))
          (platform-fee (/ (* total-cost (var-get platform-fee-rate)) u10000))
          (seller-amount (- total-cost platform-fee)))
      (asserts! (>= (stx-get-balance caller) total-cost) err-insufficient-balance)
      
      (try! (stx-transfer? seller-amount caller (get seller listing)))
      (try! (stx-transfer? platform-fee caller contract-owner))
      (try! (ft-transfer? energy-credit amount (get seller listing) caller))
      
      ;; Record transaction
      (map-set credit-transactions transaction-id {
        from: (get seller listing),
        to: caller,
        credit-id: (get credit-id listing),
        amount: amount,
        price: (get price-per-unit listing),
        transaction-date: stacks-block-height,
        transaction-type: "purchase"
      })
      
      (var-set next-transaction-id (+ transaction-id u1))
      
      (if (is-eq amount (get amount listing))
        (map-set marketplace-listings listing-id
          (merge listing {active: false}))
        (map-set marketplace-listings listing-id
          (merge listing {amount: (- (get amount listing) amount)})))
      
      (ok true))))

(define-public (create-user-profile
  (name (string-ascii 64))
  (email (string-ascii 128))
  (carbon-footprint uint))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? user-profiles caller)) err-unauthorized)
    (ok (map-set user-profiles caller {
      name: name,
      email: email,
      carbon-footprint: carbon-footprint,
      credits-purchased: u0,
      credits-retired: u0,
      join-date: stacks-block-height,
      verified: false
    }))))

(define-public (verify-user (user principal))
  (let ((profile (unwrap! (map-get? user-profiles user) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set user-profiles user
      (merge profile {verified: true})))))

(define-public (transfer-credit (recipient principal) (amount uint))
  (let ((caller tx-sender)
        (transaction-id (var-get next-transaction-id)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (>= (ft-get-balance energy-credit caller) amount) err-insufficient-balance)
    
    (try! (ft-transfer? energy-credit amount caller recipient))
    
    ;; Record transaction
    (map-set credit-transactions transaction-id {
      from: caller,
      to: recipient,
      credit-id: u0, ;; General transfer, not tied to specific credit
      amount: amount,
      price: u0,
      transaction-date: stacks-block-height,
      transaction-type: "transfer"
    })
    
    (var-set next-transaction-id (+ transaction-id u1))
    (ok true)))

(define-public (retire-credit (amount uint))
  (let ((caller tx-sender)
        (profile (map-get? user-profiles caller))
        (transaction-id (var-get next-transaction-id)))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (>= (ft-get-balance energy-credit caller) amount) err-insufficient-balance)
    
    (try! (ft-burn? energy-credit amount caller))
    
    ;; Update user profile if exists
    (match profile
      user-data (map-set user-profiles caller
        (merge user-data {credits-retired: (+ (get credits-retired user-data) amount)}))
      true)
    
    ;; Record retirement transaction
    (map-set credit-transactions transaction-id {
      from: caller,
      to: caller,
      credit-id: u0,
      amount: amount,
      price: u0,
      transaction-date: stacks-block-height,
      transaction-type: "retirement"
    })
    
    (var-set next-transaction-id (+ transaction-id u1))
    (ok amount))) ;; Return the amount retired

;; Fixed batch retirement function
(define-public (batch-retire-credits (amounts (list 10 uint)))
  (let ((caller tx-sender))
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (fold check-and-retire amounts (ok u0))))

;; Fixed helper function with matching return type
(define-private (check-and-retire (amount uint) (previous (response uint uint)))
  (match previous
    success (retire-credit amount)
    error (err error)))

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)))

(define-public (update-platform-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)))

(define-public (finalize-auction (auction-id uint))
  (let ((auction (unwrap! (map-get? credit-auctions auction-id) err-not-found)))
    (asserts! (get active auction) err-auction-ended)
    (asserts! (>= stacks-block-height (get auction-end auction)) err-auction-ended)
    
    (match (get highest-bidder auction)
      winner (begin
        (try! (ft-transfer? energy-credit (get credit-id auction) (get seller auction) winner))
        (try! (stx-transfer? (get current-bid auction) tx-sender (get seller auction)))
        (map-set credit-auctions auction-id (merge auction {active: false}))
        (ok (some winner)))
      (begin
        (map-set credit-auctions auction-id (merge auction {active: false}))
        (ok none)))))

(define-read-only (get-issuer-info (issuer principal))
  (map-get? credit-issuers issuer))

(define-read-only (get-credit-info (credit-id uint))
  (map-get? energy-credits credit-id))

(define-read-only (get-listing-info (listing-id uint))
  (map-get? marketplace-listings listing-id))

(define-read-only (get-auction-info (auction-id uint))
  (map-get? credit-auctions auction-id))

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles user))

(define-read-only (get-transaction-info (transaction-id uint))
  (map-get? credit-transactions transaction-id))

(define-read-only (get-user-credit-balance (user principal))
  (ft-get-balance energy-credit user))

(define-read-only (get-total-supply)
  (ft-get-supply energy-credit))

(define-read-only (get-contract-status)
  {
    paused: (var-get contract-paused),
    platform-fee-rate: (var-get platform-fee-rate),
    next-credit-id: (var-get next-credit-id),
    next-listing-id: (var-get next-listing-id),
    next-auction-id: (var-get next-auction-id),
    total-transactions: (var-get next-transaction-id)
  })

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000))

(define-read-only (is-credit-expired (credit-id uint))
  (match (map-get? energy-credits credit-id)
    credit (> stacks-block-height (get expiry-date credit))
    false))

(define-read-only (get-active-listings-by-seller (seller principal))
  (let ((listings (list)))
    ;; This would need to be implemented with a more complex iteration
    ;; for a production contract, but shows the concept
    (ok u0)))

(define-read-only (get-carbon-impact (user principal))
  (match (map-get? user-profiles user)
    profile {
      carbon-footprint: (get carbon-footprint profile),
      credits-retired: (get credits-retired profile),
      net-impact: (if (>= (get credits-retired profile) (get carbon-footprint profile))
                    (- (get credits-retired profile) (get carbon-footprint profile))
                    u0)
    }
    {carbon-footprint: u0, credits-retired: u0, net-impact: u0}))