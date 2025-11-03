(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_POLICY (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_POLICY_NOT_ACTIVE (err u103))
(define-constant ERR_POLICY_EXPIRED (err u104))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_NOT_ORACLE (err u106))
(define-constant ERR_INVALID_WEATHER_DATA (err u107))
(define-constant ERR_POLICY_NOT_FOUND (err u108))

(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var oracle-address (optional principal) none)
(define-data-var policy-counter uint u0)
(define-data-var total-premiums uint u0)
(define-data-var total-payouts uint u0)
(define-data-var base-premium-rate uint u100)

(define-map policies uint {
    farmer: principal,
    premium: uint,
    coverage: uint,
    crop-type: (string-ascii 50),
    location: (string-ascii 100),
    start-block: uint,
    end-block: uint,
    temperature-threshold-min: int,
    temperature-threshold-max: int,
    rainfall-threshold-min: uint,
    rainfall-threshold-max: uint,
    is-active: bool,
    is-claimed: bool
})

(define-map weather-data uint {
    location: (string-ascii 100),
    temperature: int,
    rainfall: uint,
    timestamp: uint,
    reporter: principal
})

(define-map farmer-policies principal (list 50 uint))
(define-map policy-claims uint { claimed-at: uint, payout-amount: uint })

(define-map location-risk-profiles (string-ascii 100) {
    total-policies: uint,
    total-claims: uint,
    avg-temperature: int,
    avg-rainfall: uint,
    risk-multiplier: uint
})

(define-public (set-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (ok (var-set oracle-address (some new-oracle)))
    )
)

(define-public (calculate-dynamic-premium 
    (location (string-ascii 100))
    (coverage uint)
    (duration-blocks uint))
    (let ((location-profile (default-to 
            { total-policies: u0, total-claims: u0, avg-temperature: 20, avg-rainfall: u500, risk-multiplier: u100 }
            (map-get? location-risk-profiles location)))
          (base-rate (var-get base-premium-rate))
          (coverage-factor (/ coverage u1000))
          (duration-factor (/ duration-blocks u144))
          (risk-factor (get risk-multiplier location-profile)))
        
        (let ((calculated-premium (* (* (* base-rate coverage-factor) duration-factor) risk-factor)))
            (ok (/ calculated-premium u10000))
        )
    )
)

(define-public (update-location-risk-profile
    (location (string-ascii 100))
    (temperature int)
    (rainfall uint))
    (let ((current-profile (default-to 
            { total-policies: u0, total-claims: u0, avg-temperature: 20, avg-rainfall: u500, risk-multiplier: u100 }
            (map-get? location-risk-profiles location))))
        
        (let ((total-policies-int (to-int (get total-policies current-profile)))
              (new-avg-temp (/ (+ (* (get avg-temperature current-profile) total-policies-int) temperature) 
                               (+ total-policies-int 1)))
              (new-avg-rain (/ (+ (* (to-int (get avg-rainfall current-profile)) (to-int (get total-policies current-profile))) (to-int rainfall)) 
                               (to-int (+ (get total-policies current-profile) u1))))
              (new-total-policies (+ (get total-policies current-profile) u1))
              (new-risk-multiplier (calculate-risk-multiplier new-avg-temp (to-uint new-avg-rain))))
            
            (map-set location-risk-profiles location {
                total-policies: new-total-policies,
                total-claims: (get total-claims current-profile),
                avg-temperature: new-avg-temp,
                avg-rainfall: (to-uint new-avg-rain),
                risk-multiplier: new-risk-multiplier
            })
            
            (ok true)
        )
    )
)

(define-private (calculate-risk-multiplier (avg-temp int) (avg-rainfall uint))
    (let ((temp-risk (if (or (< avg-temp 0) (> avg-temp 35)) u150 u100))
          (rain-risk (if (or (< avg-rainfall u200) (> avg-rainfall u800)) u120 u100)))
        (/ (* temp-risk rain-risk) u100)
    )
)

(define-public (create-policy 
    (premium uint)
    (coverage uint)
    (crop-type (string-ascii 50))
    (location (string-ascii 100))
    (duration-blocks uint)
    (temp-min int)
    (temp-max int)
    (rain-min uint)
    (rain-max uint))
    (let ((policy-id (+ (var-get policy-counter) u1))
          (current-block stacks-block-height)
          (end-block (+ stacks-block-height duration-blocks)))
        (asserts! (> premium u0) ERR_INVALID_POLICY)
        (asserts! (> coverage u0) ERR_INVALID_POLICY)
        (asserts! (> duration-blocks u0) ERR_INVALID_POLICY)
        (asserts! (>= (stx-get-balance tx-sender) premium) ERR_INSUFFICIENT_FUNDS)
        
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        
        (map-set policies policy-id {
            farmer: tx-sender,
            premium: premium,
            coverage: coverage,
            crop-type: crop-type,
            location: location,
            start-block: current-block,
            end-block: end-block,
            temperature-threshold-min: temp-min,
            temperature-threshold-max: temp-max,
            rainfall-threshold-min: rain-min,
            rainfall-threshold-max: rain-max,
            is-active: true,
            is-claimed: false
        })
        
        (var-set policy-counter policy-id)
        (var-set total-premiums (+ (var-get total-premiums) premium))
        
        (let ((ignore-result (update-location-risk-profile location 20 u500))
              (current-policies (default-to (list) (map-get? farmer-policies tx-sender))))
            (map-set farmer-policies tx-sender (unwrap! (as-max-len? (append current-policies policy-id) u50) ERR_INVALID_POLICY))
        )
        
        (ok policy-id)
    )
)

(define-public (submit-weather-data 
    (location (string-ascii 100))
    (temperature int)
    (rainfall uint))
    (let ((data-id (+ (var-get policy-counter) u1000)))
        (asserts! (is-some (var-get oracle-address)) ERR_NOT_ORACLE)
        (asserts! (is-eq tx-sender (unwrap-panic (var-get oracle-address))) ERR_NOT_ORACLE)
        
        (map-set weather-data data-id {
            location: location,
            temperature: temperature,
            rainfall: rainfall,
            timestamp: stacks-block-height,
            reporter: tx-sender
        })
        
        (ok data-id)
    )
)

(define-public (process-claim (policy-id uint))
    (let ((policy-data (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND))
          (current-block stacks-block-height))
        
        (asserts! (get is-active policy-data) ERR_POLICY_NOT_ACTIVE)
        (asserts! (not (get is-claimed policy-data)) ERR_ALREADY_CLAIMED)
        (asserts! (<= current-block (get end-block policy-data)) ERR_POLICY_EXPIRED)
        
        (let ((location (get location policy-data))
              (temp-min (get temperature-threshold-min policy-data))
              (temp-max (get temperature-threshold-max policy-data))
              (rain-min (get rainfall-threshold-min policy-data))
              (rain-max (get rainfall-threshold-max policy-data)))
            
            (match (find-weather-data-for-location location)
                weather-info
                (let ((trigger-condition (or
                    (< (get temperature weather-info) temp-min)
                    (> (get temperature weather-info) temp-max)
                    (< (get rainfall weather-info) rain-min)
                    (> (get rainfall weather-info) rain-max))))
                    
                    (if trigger-condition
                        (begin
                            (try! (as-contract (stx-transfer? (get coverage policy-data) tx-sender (get farmer policy-data))))
                            
                            (map-set policies policy-id
                                (merge policy-data { is-claimed: true }))
                            
                            (map-set policy-claims policy-id {
                                claimed-at: current-block,
                                payout-amount: (get coverage policy-data)
                            })
                            
                            (var-set total-payouts (+ (var-get total-payouts) (get coverage policy-data)))
                            
                            (let ((current-profile (default-to 
                                    { total-policies: u0, total-claims: u0, avg-temperature: 20, avg-rainfall: u500, risk-multiplier: u100 }
                                    (map-get? location-risk-profiles location))))
                                (map-set location-risk-profiles location
                                    (merge current-profile { total-claims: (+ (get total-claims current-profile) u1) }))
                            )
                            
                            (ok (get coverage policy-data))
                        )
                        (ok u0)
                    )
                )
                (ok u0)
            )
        )
    )
)

(define-public (cancel-policy (policy-id uint))
    (let ((policy-data (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get farmer policy-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active policy-data) ERR_POLICY_NOT_ACTIVE)
        (asserts! (not (get is-claimed policy-data)) ERR_ALREADY_CLAIMED)
        
        (map-set policies policy-id
            (merge policy-data { is-active: false }))
        
        (let ((refund (/ (get premium policy-data) u2)))
            (try! (as-contract (stx-transfer? refund tx-sender (get farmer policy-data))))
            (ok refund)
        )
    )
)

(define-public (extend-policy (policy-id uint) (additional-blocks uint) (additional-premium uint))
    (let ((policy-data (unwrap! (map-get? policies policy-id) ERR_POLICY_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get farmer policy-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active policy-data) ERR_POLICY_NOT_ACTIVE)
        (asserts! (not (get is-claimed policy-data)) ERR_ALREADY_CLAIMED)
        (asserts! (>= (stx-get-balance tx-sender) additional-premium) ERR_INSUFFICIENT_FUNDS)
        
        (try! (stx-transfer? additional-premium tx-sender (as-contract tx-sender)))
        
        (map-set policies policy-id
            (merge policy-data { 
                end-block: (+ (get end-block policy-data) additional-blocks),
                premium: (+ (get premium policy-data) additional-premium)
            }))
        
        (var-set total-premiums (+ (var-get total-premiums) additional-premium))
        
        (ok true)
    )
)

(define-public (withdraw-funds (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (>= (stx-get-balance (as-contract tx-sender)) amount) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
        (ok amount)
    )
)

(define-read-only (get-policy (policy-id uint))
    (map-get? policies policy-id)
)

(define-read-only (get-farmer-policies (farmer principal))
    (map-get? farmer-policies farmer)
)

(define-read-only (get-weather-data (data-id uint))
    (map-get? weather-data data-id)
)

(define-read-only (get-policy-claim (policy-id uint))
    (map-get? policy-claims policy-id)
)

(define-read-only (get-contract-stats)
    {
        total-policies: (var-get policy-counter),
        total-premiums: (var-get total-premiums),
        total-payouts: (var-get total-payouts),
        contract-balance: (stx-get-balance (as-contract tx-sender)),
        oracle: (var-get oracle-address)
    }
)

(define-read-only (get-location-risk-profile (location (string-ascii 100)))
    (map-get? location-risk-profiles location)
)

(define-read-only (get-premium-quote 
    (location (string-ascii 100))
    (coverage uint)
    (duration-blocks uint))
    (calculate-dynamic-premium location coverage duration-blocks)
)

(define-read-only (is-policy-eligible-for-payout (policy-id uint))
    (match (map-get? policies policy-id)
        policy-data
        (let ((location (get location policy-data))
              (temp-min (get temperature-threshold-min policy-data))
              (temp-max (get temperature-threshold-max policy-data))
              (rain-min (get rainfall-threshold-min policy-data))
              (rain-max (get rainfall-threshold-max policy-data)))
            
            (and 
                (get is-active policy-data)
                (not (get is-claimed policy-data))
                (<= stacks-block-height (get end-block policy-data))
                (match (find-weather-data-for-location location)
                    weather-info
                    (or
                        (< (get temperature weather-info) temp-min)
                        (> (get temperature weather-info) temp-max)
                        (< (get rainfall weather-info) rain-min)
                        (> (get rainfall weather-info) rain-max)
                    )
                    false
                )
            )
        )
        false
    )
)

(define-private (find-weather-data-for-location (location (string-ascii 100)))
    (let ((base-id (+ (var-get policy-counter) u1000)))
        (match (map-get? weather-data base-id) data-1
            (if (is-eq (get location data-1) location) (some data-1)
                (match (map-get? weather-data (+ base-id u1)) data-2
                    (if (is-eq (get location data-2) location) (some data-2)
                        (match (map-get? weather-data (+ base-id u2)) data-3
                            (if (is-eq (get location data-3) location) (some data-3) none)
                        none)) 
                none))
        none)
    )
)

(define-read-only (get-active-policies-count)
    (fold count-active-policies (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) u0)
)

(define-private (count-active-policies (policy-id uint) (count uint))
    (match (map-get? policies policy-id)
        policy-data
        (if (get is-active policy-data)
            (+ count u1)
            count
        )
        count
    )
)

(define-public (set-base-premium-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (> new-rate u0) ERR_INVALID_POLICY)
        (ok (var-set base-premium-rate new-rate))
    )
)

(define-read-only (get-base-premium-rate)
    (var-get base-premium-rate)
)
