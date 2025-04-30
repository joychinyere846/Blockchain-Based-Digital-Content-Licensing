;; Usage Tracking Contract
;; Monitors consumption of licensed content

(define-data-var admin principal tx-sender)

;; License structure
(define-map licenses
  { license-id: uint }
  {
    asset-id: uint,
    template-id: uint,
    licensee: principal,
    start-time: uint,
    end-time: uint,
    is-active: bool
  }
)

;; Usage tracking structure
(define-map usage-records
  { license-id: uint, record-id: uint }
  {
    timestamp: uint,
    action-type: (string-ascii 32),
    metadata: (string-ascii 256)
  }
)

;; Track license count and usage record counts
(define-data-var license-count uint u0)
(define-map usage-record-counts { license-id: uint } uint)

;; Error codes
(define-constant err-not-admin (err u100))
(define-constant err-license-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-license-expired (err u103))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Create a new license
(define-public (create-license
    (asset-id uint)
    (template-id uint)
    (licensee principal)
    (duration uint))
  (let
    (
      (license-id (var-get license-count))
      (start-time block-height)
      (end-time (+ block-height duration))
    )
    (map-set licenses
      { license-id: license-id }
      {
        asset-id: asset-id,
        template-id: template-id,
        licensee: licensee,
        start-time: start-time,
        end-time: end-time,
        is-active: true
      }
    )
    (var-set license-count (+ license-id u1))
    (map-set usage-record-counts { license-id: license-id } u0)
    (ok license-id)))

;; Record usage of licensed content
(define-public (record-usage
    (license-id uint)
    (action-type (string-ascii 32))
    (metadata (string-ascii 256)))
  (let
    (
      (license (map-get? licenses { license-id: license-id }))
      (record-count (default-to u0 (map-get? usage-record-counts { license-id: license-id })))
    )
    (asserts! (is-some license) err-license-not-found)
    (let ((license-data (unwrap-panic license)))
      (asserts! (is-eq tx-sender (get licensee license-data)) err-unauthorized)
      (asserts! (and (get is-active license-data) (<= block-height (get end-time license-data))) err-license-expired)

      (map-set usage-records
        { license-id: license-id, record-id: record-count }
        {
          timestamp: block-height,
          action-type: action-type,
          metadata: metadata
        }
      )
      (map-set usage-record-counts { license-id: license-id } (+ record-count u1))
      (ok record-count))))

;; Get license details
(define-read-only (get-license (license-id uint))
  (map-get? licenses { license-id: license-id }))

;; Get usage record
(define-read-only (get-usage-record (license-id uint) (record-id uint))
  (map-get? usage-records { license-id: license-id, record-id: record-id }))

;; Get usage record count for a license
(define-read-only (get-usage-record-count (license-id uint))
  (default-to u0 (map-get? usage-record-counts { license-id: license-id })))

;; Deactivate a license
(define-public (deactivate-license (license-id uint))
  (let ((license (map-get? licenses { license-id: license-id })))
    (asserts! (is-some license) err-license-not-found)
    (asserts! (or (is-admin) (is-eq tx-sender (get licensee (unwrap-panic license)))) err-unauthorized)
    (map-set licenses
      { license-id: license-id }
      (merge (unwrap-panic license) { is-active: false })
    )
    (ok true)))
