(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-listing-not-found (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-project-not-verified (err u105))
(define-constant err-credit-already-retired (err u106))
(define-constant err-invalid-price (err u107))
(define-constant err-cannot-buy-own-listing (err u108))
(define-constant err-certificate-not-found (err u109))
(define-constant err-invalid-certificate-data (err u110))
(define-constant err-lease-not-found (err u111))
(define-constant err-lease-not-expired (err u112))
(define-constant err-lease-already-active (err u113))
(define-constant err-invalid-lease-duration (err u114))
(define-constant err-cannot-lease-own-credits (err u115))

(define-fungible-token carbon-credit)

(define-map projects
    { project-id: uint }
    {
        owner: principal,
        name: (string-ascii 100),
        description: (string-ascii 500),
        location: (string-ascii 100),
        methodology: (string-ascii 100),
        verified: bool,
        total-credits: uint,
        available-credits: uint
    }
)

(define-map credit-details
    { credit-id: uint }
    {
        project-id: uint,
        owner: principal,
        vintage: uint,
        amount: uint,
        retired: bool,
        retirement-reason: (optional (string-ascii 200))
    }
)

(define-map marketplace-listings
    { listing-id: uint }
    {
        seller: principal,
        credit-id: uint,
        amount: uint,
        price-per-credit: uint,
        active: bool
    }
)

(define-map user-balances
    { user: principal, project-id: uint }
    uint
)

(define-map offset-certificates
    { certificate-id: uint }
    {
        issuer: principal,
        entity: principal,
        entity-name: (string-ascii 100),
        credits-retired: uint,
        project-ids: (list 10 uint),
        purpose: (string-ascii 200),
        timestamp: uint,
        verified: bool,
        certificate-hash: (buff 32)
    }
)

(define-map entity-offset-totals
    { entity: principal }
    {
        total-retired: uint,
        certificate-count: uint,
        verified-retired: uint
    }
)

(define-map lease-listings
    { lease-id: uint }
    {
        lessor: principal,
        credit-id: uint,
        amount: uint,
        lease-price: uint,
        lease-duration: uint,
        active: bool
    }
)

(define-map active-leases
    { lease-id: uint }
    {
        lessor: principal,
        lessee: principal,
        credit-id: uint,
        amount: uint,
        start-block: uint,
        end-block: uint,
        returned: bool
    }
)

(define-data-var next-project-id uint u1)
(define-data-var next-credit-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-certificate-id uint u1)
(define-data-var next-lease-id uint u1)

(define-read-only (get-contract-owner)
    contract-owner
)

(define-read-only (get-project (project-id uint))
    (map-get? projects { project-id: project-id })
)

(define-read-only (get-credit-details (credit-id uint))
    (map-get? credit-details { credit-id: credit-id })
)

(define-read-only (get-marketplace-listing (listing-id uint))
    (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-user-balance (user principal) (project-id uint))
    (default-to u0 (map-get? user-balances { user: user, project-id: project-id }))
)

(define-read-only (get-carbon-credit-balance (user principal))
    (ft-get-balance carbon-credit user)
)

(define-read-only (get-next-project-id)
    (var-get next-project-id)
)

(define-read-only (get-next-credit-id)
    (var-get next-credit-id)
)

(define-read-only (get-next-listing-id)
    (var-get next-listing-id)
)

(define-read-only (get-offset-certificate (certificate-id uint))
    (map-get? offset-certificates { certificate-id: certificate-id })
)

(define-read-only (get-entity-offset-totals (entity principal))
    (map-get? entity-offset-totals { entity: entity })
)

(define-read-only (get-next-certificate-id)
    (var-get next-certificate-id)
)

(define-read-only (get-lease-listing (lease-id uint))
    (map-get? lease-listings { lease-id: lease-id })
)

(define-read-only (get-active-lease (lease-id uint))
    (map-get? active-leases { lease-id: lease-id })
)

(define-read-only (get-next-lease-id)
    (var-get next-lease-id)
)

(define-read-only (check-lease-expired (lease-id uint))
    (match (map-get? active-leases { lease-id: lease-id })
        lease (>= stacks-block-height (get end-block lease))
        false
    )
)

(define-public (register-project (name (string-ascii 100)) (description (string-ascii 500)) (location (string-ascii 100)) (methodology (string-ascii 100)))
    (let ((project-id (var-get next-project-id)))
        (map-set projects
            { project-id: project-id }
            {
                owner: tx-sender,
                name: name,
                description: description,
                location: location,
                methodology: methodology,
                verified: false,
                total-credits: u0,
                available-credits: u0
            }
        )
        (var-set next-project-id (+ project-id u1))
        (ok project-id)
    )
)

(define-public (verify-project (project-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? projects { project-id: project-id })) err-listing-not-found)
        (let ((project (unwrap-panic (map-get? projects { project-id: project-id }))))
            (map-set projects
                { project-id: project-id }
                (merge project { verified: true })
            )
            (ok true)
        )
    )
)

(define-public (mint-carbon-credits (project-id uint) (amount uint) (vintage uint))
    (begin
        (asserts! (is-some (map-get? projects { project-id: project-id })) err-listing-not-found)
        (let ((project (unwrap-panic (map-get? projects { project-id: project-id }))))
            (asserts! (is-eq tx-sender (get owner project)) err-not-token-owner)
            (asserts! (get verified project) err-project-not-verified)
            (asserts! (> amount u0) err-invalid-amount)
            (let ((credit-id (var-get next-credit-id)))
                (try! (ft-mint? carbon-credit amount tx-sender))
                (map-set credit-details
                    { credit-id: credit-id }
                    {
                        project-id: project-id,
                        owner: tx-sender,
                        vintage: vintage,
                        amount: amount,
                        retired: false,
                        retirement-reason: none
                    }
                )
                (map-set projects
                    { project-id: project-id }
                    (merge project {
                        total-credits: (+ (get total-credits project) amount),
                        available-credits: (+ (get available-credits project) amount)
                    })
                )
                (map-set user-balances
                    { user: tx-sender, project-id: project-id }
                    (+ (get-user-balance tx-sender project-id) amount)
                )
                (var-set next-credit-id (+ credit-id u1))
                (ok credit-id)
            )
        )
    )
)

(define-public (transfer-credits (recipient principal) (amount uint) (credit-id uint))
    (begin
        (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
        (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
            (asserts! (is-eq tx-sender (get owner credit)) err-not-token-owner)
            (asserts! (not (get retired credit)) err-credit-already-retired)
            (asserts! (<= amount (get amount credit)) err-insufficient-balance)
            (asserts! (>= (ft-get-balance carbon-credit tx-sender) amount) err-insufficient-balance)
            (try! (ft-transfer? carbon-credit amount tx-sender recipient))
            (let ((project-id (get project-id credit))
                  (sender-balance (get-user-balance tx-sender project-id))
                  (recipient-balance (get-user-balance recipient project-id)))
                (map-set user-balances
                    { user: tx-sender, project-id: project-id }
                    (- sender-balance amount)
                )
                (map-set user-balances
                    { user: recipient, project-id: project-id }
                    (+ recipient-balance amount)
                )
                (if (is-eq amount (get amount credit))
                    (begin
                        (map-set credit-details
                            { credit-id: credit-id }
                            (merge credit { owner: recipient })
                        )
                        (ok true)
                    )
                    (let ((new-credit-id (var-get next-credit-id)))
                        (map-set credit-details
                            { credit-id: credit-id }
                            (merge credit { amount: (- (get amount credit) amount) })
                        )
                        (map-set credit-details
                            { credit-id: new-credit-id }
                            (merge credit { 
                                owner: recipient,
                                amount: amount
                            })
                        )
                        (var-set next-credit-id (+ new-credit-id u1))
                        (ok true)
                        )
                        )
                        )
                        )
                        )
                        )
 
 (define-public (register-carbon-offset (entity principal) (entity-name (string-ascii 100)) (credits-retired uint) (project-ids (list 10 uint)) (purpose (string-ascii 200)))
     (begin
         (asserts! (> credits-retired u0) err-invalid-amount)
         (asserts! (> (len entity-name) u0) err-invalid-certificate-data)
         (asserts! (> (len purpose) u0) err-invalid-certificate-data)
         (let ((certificate-id (var-get next-certificate-id))
               (certificate-hash (keccak256 (concat (concat (concat (unwrap-panic (to-consensus-buff? certificate-id)) (unwrap-panic (to-consensus-buff? entity))) (unwrap-panic (to-consensus-buff? credits-retired))) (unwrap-panic (to-consensus-buff? stacks-block-height))))))
             (map-set offset-certificates
                 { certificate-id: certificate-id }
                 {
                     issuer: tx-sender,
                     entity: entity,
                     entity-name: entity-name,
                     credits-retired: credits-retired,
                     project-ids: project-ids,
                     purpose: purpose,
                     timestamp: stacks-block-height,
                     verified: false,
                     certificate-hash: certificate-hash
                 }
             )
             (let ((current-totals (default-to { total-retired: u0, certificate-count: u0, verified-retired: u0 } (map-get? entity-offset-totals { entity: entity }))))
                 (map-set entity-offset-totals
                     { entity: entity }
                     {
                         total-retired: (+ (get total-retired current-totals) credits-retired),
                         certificate-count: (+ (get certificate-count current-totals) u1),
                         verified-retired: (get verified-retired current-totals)
                     }
                 )
                 (var-set next-certificate-id (+ certificate-id u1))
                 (ok certificate-id)
             )
         )
     )
 )
 
 (define-public (verify-offset-certificate (certificate-id uint))
     (begin
         (asserts! (is-eq tx-sender contract-owner) err-owner-only)
         (asserts! (is-some (map-get? offset-certificates { certificate-id: certificate-id })) err-certificate-not-found)
         (let ((certificate (unwrap-panic (map-get? offset-certificates { certificate-id: certificate-id }))))
             (asserts! (not (get verified certificate)) err-invalid-certificate-data)
             (let ((entity (get entity certificate))
                   (credits-retired (get credits-retired certificate))
                   (current-totals (default-to { total-retired: u0, certificate-count: u0, verified-retired: u0 } (map-get? entity-offset-totals { entity: entity }))))
                 (map-set offset-certificates
                     { certificate-id: certificate-id }
                     (merge certificate { verified: true })
                 )
                 (map-set entity-offset-totals
                     { entity: entity }
                     (merge current-totals { verified-retired: (+ (get verified-retired current-totals) credits-retired) })
                 )
                 (ok true)
             )
         )
     )
 )
 
 (define-public (update-offset-purpose (certificate-id uint) (new-purpose (string-ascii 200)))
     (begin
         (asserts! (is-some (map-get? offset-certificates { certificate-id: certificate-id })) err-certificate-not-found)
         (let ((certificate (unwrap-panic (map-get? offset-certificates { certificate-id: certificate-id }))))
             (asserts! (is-eq tx-sender (get issuer certificate)) err-not-token-owner)
             (asserts! (not (get verified certificate)) err-invalid-certificate-data)
             (asserts! (> (len new-purpose) u0) err-invalid-certificate-data)
             (map-set offset-certificates
                 { certificate-id: certificate-id }
                 (merge certificate { purpose: new-purpose })
             )
             (ok true)
         )
     )
 )
 
 (define-read-only (verify-carbon-neutrality (entity principal) (required-credits uint))
     (let ((totals (map-get? entity-offset-totals { entity: entity })))
         (match totals
             entity-totals (>= (get verified-retired entity-totals) required-credits)
             false
         )
     )
 )
 
 (define-read-only (get-certificate-verification-hash (certificate-id uint))
     (match (map-get? offset-certificates { certificate-id: certificate-id })
         certificate (some (get certificate-hash certificate))
         none
     )
 )

(define-public (create-lease-listing (credit-id uint) (amount uint) (lease-price uint) (lease-duration uint))
    (begin
        (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
        (asserts! (> lease-duration u0) err-invalid-lease-duration)
        (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
            (asserts! (is-eq tx-sender (get owner credit)) err-not-token-owner)
            (asserts! (not (get retired credit)) err-credit-already-retired)
            (asserts! (<= amount (get amount credit)) err-insufficient-balance)
            (asserts! (> lease-price u0) err-invalid-price)
            (asserts! (> amount u0) err-invalid-amount)
            (let ((lease-id (var-get next-lease-id)))
                (map-set lease-listings
                    { lease-id: lease-id }
                    {
                        lessor: tx-sender,
                        credit-id: credit-id,
                        amount: amount,
                        lease-price: lease-price,
                        lease-duration: lease-duration,
                        active: true
                    }
                )
                (var-set next-lease-id (+ lease-id u1))
                (ok lease-id)
            )
        )
    )
)

(define-public (lease-credits (lease-id uint))
    (begin
        (asserts! (is-some (map-get? lease-listings { lease-id: lease-id })) err-lease-not-found)
        (asserts! (is-none (map-get? active-leases { lease-id: lease-id })) err-lease-already-active)
        (let ((listing (unwrap-panic (map-get? lease-listings { lease-id: lease-id }))))
            (asserts! (get active listing) err-lease-not-found)
            (asserts! (not (is-eq tx-sender (get lessor listing))) err-cannot-lease-own-credits)
            (let ((lessor (get lessor listing))
                  (credit-id (get credit-id listing))
                  (amount (get amount listing))
                  (lease-price (get lease-price listing))
                  (lease-duration (get lease-duration listing)))
                (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
                (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
                    (asserts! (is-eq lessor (get owner credit)) err-not-token-owner)
                    (asserts! (not (get retired credit)) err-credit-already-retired)
                    (asserts! (<= amount (get amount credit)) err-insufficient-balance)
                    (try! (stx-transfer? lease-price tx-sender lessor))
                    (try! (ft-transfer? carbon-credit amount lessor tx-sender))
                    (let ((project-id (get project-id credit))
                          (lessor-balance (get-user-balance lessor project-id))
                          (lessee-balance (get-user-balance tx-sender project-id)))
                        (map-set user-balances
                            { user: lessor, project-id: project-id }
                            (- lessor-balance amount)
                        )
                        (map-set user-balances
                            { user: tx-sender, project-id: project-id }
                            (+ lessee-balance amount)
                        )
                        (map-set active-leases
                            { lease-id: lease-id }
                            {
                                lessor: lessor,
                                lessee: tx-sender,
                                credit-id: credit-id,
                                amount: amount,
                                start-block: stacks-block-height,
                                end-block: (+ stacks-block-height lease-duration),
                                returned: false
                            }
                        )
                        (map-set lease-listings
                            { lease-id: lease-id }
                            (merge listing { active: false })
                        )
                        (ok true)
                    )
                )
            )
        )
    )
)

(define-public (return-leased-credits (lease-id uint))
    (begin
        (asserts! (is-some (map-get? active-leases { lease-id: lease-id })) err-lease-not-found)
        (let ((lease (unwrap-panic (map-get? active-leases { lease-id: lease-id }))))
            (asserts! (not (get returned lease)) err-invalid-amount)
            (asserts! (>= stacks-block-height (get end-block lease)) err-lease-not-expired)
            (let ((lessor (get lessor lease))
                  (lessee (get lessee lease))
                  (credit-id (get credit-id lease))
                  (amount (get amount lease)))
                (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
                (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
                    (try! (ft-transfer? carbon-credit amount lessee lessor))
                    (let ((project-id (get project-id credit))
                          (lessor-balance (get-user-balance lessor project-id))
                          (lessee-balance (get-user-balance lessee project-id)))
                        (map-set user-balances
                            { user: lessee, project-id: project-id }
                            (- lessee-balance amount)
                        )
                        (map-set user-balances
                            { user: lessor, project-id: project-id }
                            (+ lessor-balance amount)
                        )
                        (map-set active-leases
                            { lease-id: lease-id }
                            (merge lease { returned: true })
                        )
                        (ok true)
                    )
                )
            )
        )
    )
)

(define-public (cancel-lease-listing (lease-id uint))
    (begin
        (asserts! (is-some (map-get? lease-listings { lease-id: lease-id })) err-lease-not-found)
        (asserts! (is-none (map-get? active-leases { lease-id: lease-id })) err-lease-already-active)
        (let ((listing (unwrap-panic (map-get? lease-listings { lease-id: lease-id }))))
            (asserts! (is-eq tx-sender (get lessor listing)) err-not-token-owner)
            (asserts! (get active listing) err-lease-not-found)
            (map-set lease-listings
                { lease-id: lease-id }
                (merge listing { active: false })
            )
            (ok true)
        )
    )
)

(define-public (create-listing (credit-id uint) (amount uint) (price-per-credit uint))
    (begin
        (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
        (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
            (asserts! (is-eq tx-sender (get owner credit)) err-not-token-owner)
            (asserts! (not (get retired credit)) err-credit-already-retired)
            (asserts! (<= amount (get amount credit)) err-insufficient-balance)
            (asserts! (> price-per-credit u0) err-invalid-price)
            (asserts! (> amount u0) err-invalid-amount)
            (let ((listing-id (var-get next-listing-id)))
                (map-set marketplace-listings
                    { listing-id: listing-id }
                    {
                        seller: tx-sender,
                        credit-id: credit-id,
                        amount: amount,
                        price-per-credit: price-per-credit,
                        active: true
                    }
                )
                (var-set next-listing-id (+ listing-id u1))
                (ok listing-id)
            )
        )
    )
)

(define-public (buy-credits (listing-id uint))
    (begin
        (asserts! (is-some (map-get? marketplace-listings { listing-id: listing-id })) err-listing-not-found)
        (let ((listing (unwrap-panic (map-get? marketplace-listings { listing-id: listing-id }))))
            (asserts! (get active listing) err-listing-not-found)
            (asserts! (not (is-eq tx-sender (get seller listing))) err-cannot-buy-own-listing)
            (let ((total-price (* (get amount listing) (get price-per-credit listing)))
                  (seller (get seller listing))
                  (credit-id (get credit-id listing))
                  (amount (get amount listing)))
                (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
                (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
                    (asserts! (is-eq seller (get owner credit)) err-not-token-owner)
                    (asserts! (not (get retired credit)) err-credit-already-retired)
                    (asserts! (<= amount (get amount credit)) err-insufficient-balance)
                    (try! (stx-transfer? total-price tx-sender seller))
                    (try! (ft-transfer? carbon-credit amount seller tx-sender))
                    (let ((project-id (get project-id credit))
                          (seller-balance (get-user-balance seller project-id))
                          (buyer-balance (get-user-balance tx-sender project-id)))
                        (map-set user-balances
                            { user: seller, project-id: project-id }
                            (- seller-balance amount)
                        )
                        (map-set user-balances
                            { user: tx-sender, project-id: project-id }
                            (+ buyer-balance amount)
                        )
                        (map-set marketplace-listings
                            { listing-id: listing-id }
                            (merge listing { active: false })
                        )
                        (if (is-eq amount (get amount credit))
                            (begin
                                (map-set credit-details
                                    { credit-id: credit-id }
                                    (merge credit { owner: tx-sender })
                                )
                                (ok true)
                            )
                            (let ((new-credit-id (var-get next-credit-id)))
                                (map-set credit-details
                                    { credit-id: credit-id }
                                    (merge credit { amount: (- (get amount credit) amount) })
                                )
                                (map-set credit-details
                                    { credit-id: new-credit-id }
                                    (merge credit { 
                                        owner: tx-sender,
                                        amount: amount
                                    })
                                )
                                (var-set next-credit-id (+ new-credit-id u1))
                                (ok true)
                            )
                        )
                    )
                )
            )
        )
    )
)

(define-public (cancel-listing (listing-id uint))
    (begin
        (asserts! (is-some (map-get? marketplace-listings { listing-id: listing-id })) err-listing-not-found)
        (let ((listing (unwrap-panic (map-get? marketplace-listings { listing-id: listing-id }))))
            (asserts! (is-eq tx-sender (get seller listing)) err-not-token-owner)
            (asserts! (get active listing) err-listing-not-found)
            (map-set marketplace-listings
                { listing-id: listing-id }
                (merge listing { active: false })
            )
            (ok true)
        )
    )
)

(define-public (retire-credits (credit-id uint) (amount uint) (reason (string-ascii 200)))
    (begin
        (asserts! (is-some (map-get? credit-details { credit-id: credit-id })) err-listing-not-found)
        (let ((credit (unwrap-panic (map-get? credit-details { credit-id: credit-id }))))
            (asserts! (is-eq tx-sender (get owner credit)) err-not-token-owner)
            (asserts! (not (get retired credit)) err-credit-already-retired)
            (asserts! (<= amount (get amount credit)) err-insufficient-balance)
            (asserts! (>= (ft-get-balance carbon-credit tx-sender) amount) err-insufficient-balance)
            (try! (ft-burn? carbon-credit amount tx-sender))
            (let ((project-id (get project-id credit))
                  (user-balance (get-user-balance tx-sender project-id)))
                (map-set user-balances
                    { user: tx-sender, project-id: project-id }
                    (- user-balance amount)
                )
                (let ((project-option (map-get? projects { project-id: project-id })))
                    (if (is-some project-option)
                        (let ((project (unwrap-panic project-option)))
                            (map-set projects
                                { project-id: project-id }
                                (merge project { 
                                    available-credits: (- (get available-credits project) amount)
                                })
                            )
                        )
                        true
                    )
                )
                (if (is-eq amount (get amount credit))
                    (begin
                        (map-set credit-details
                            { credit-id: credit-id }
                            (merge credit { 
                                retired: true,
                                retirement-reason: (some reason)
                            })
                        )
                        (ok true)
                    )
                    (let ((new-credit-id (var-get next-credit-id)))
                        (map-set credit-details
                            { credit-id: credit-id }
                            (merge credit { amount: (- (get amount credit) amount) })
                        )
                        (map-set credit-details
                            { credit-id: new-credit-id }
                            (merge credit { 
                                amount: amount,
                                retired: true,
                                retirement-reason: (some reason)
                            })
                        )
                        (var-set next-credit-id (+ new-credit-id u1))
                        (ok true)
                    )
                )
            )
        )
    )
)
