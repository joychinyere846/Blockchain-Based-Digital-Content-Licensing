;; License Template Contract
;; Manages standardized usage agreements

(define-data-var admin principal tx-sender)

;; License template structure
(define-map license-templates
  { template-id: uint }
  {
    name: (string-ascii 64),
    description: (string-ascii 256),
    duration: uint,
    price: uint,
    rights: (string-ascii 256),
    creator: principal,
    is-active: bool
  }
)

;; Track template count
(define-data-var template-count uint u0)

;; Error codes
(define-constant err-not-admin (err u100))
(define-constant err-template-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-template-exists (err u103))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

;; Create a new license template
(define-public (create-template
    (name (string-ascii 64))
    (description (string-ascii 256))
    (duration uint)
    (price uint)
    (rights (string-ascii 256)))
  (let ((template-id (var-get template-count)))
    (asserts! (is-none (map-get? license-templates { template-id: template-id })) err-template-exists)
    (map-set license-templates
      { template-id: template-id }
      {
        name: name,
        description: description,
        duration: duration,
        price: price,
        rights: rights,
        creator: tx-sender,
        is-active: true
      }
    )
    (var-set template-count (+ template-id u1))
    (ok template-id)))

;; Get template details
(define-read-only (get-template (template-id uint))
  (map-get? license-templates { template-id: template-id }))

;; Deactivate a template
(define-public (deactivate-template (template-id uint))
  (let ((template (map-get? license-templates { template-id: template-id })))
    (asserts! (is-some template) err-template-not-found)
    (asserts! (or (is-admin) (is-eq tx-sender (get creator (unwrap-panic template)))) err-unauthorized)
    (map-set license-templates
      { template-id: template-id }
      (merge (unwrap-panic template) { is-active: false })
    )
    (ok true)))

;; Reactivate a template
(define-public (reactivate-template (template-id uint))
  (let ((template (map-get? license-templates { template-id: template-id })))
    (asserts! (is-some template) err-template-not-found)
    (asserts! (or (is-admin) (is-eq tx-sender (get creator (unwrap-panic template)))) err-unauthorized)
    (map-set license-templates
      { template-id: template-id }
      (merge (unwrap-panic template) { is-active: true })
    )
    (ok true)))

;; Get total number of templates
(define-read-only (get-template-count)
  (var-get template-count))
