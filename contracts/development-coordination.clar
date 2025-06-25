;; Development Coordination Contract
;; Coordinates product development activities and milestones

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_INPUT (err u302))
(define-constant ERR_ALREADY_EXISTS (err u303))
(define-constant ERR_INVALID_STATUS (err u304))

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var next-milestone-id uint u1)

;; Data Maps
(define-map projects
  { project-id: uint }
  {
    idea-id: uint,
    manager-id: uint,
    title: (string-ascii 100),
    status: (string-ascii 20),
    start-date: uint,
    target-completion: uint,
    actual-completion: uint,
    total-milestones: uint,
    completed-milestones: uint,
    budget-allocated: uint,
    budget-used: uint
  }
)

(define-map milestones
  { milestone-id: uint }
  {
    project-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    status: (string-ascii 20),
    target-date: uint,
    completion-date: uint,
    assigned-team: principal,
    deliverables: (string-ascii 200)
  }
)

(define-map project-milestones
  { project-id: uint, milestone-index: uint }
  { milestone-id: uint }
)

(define-map team-assignments
  { project-id: uint, team-member: principal }
  { role: (string-ascii 50), assignment-date: uint }
)

;; Public Functions

;; Create a new development project
(define-public (create-project
  (idea-id uint)
  (manager-id uint)
  (title (string-ascii 100))
  (target-completion uint)
  (budget-allocated uint))
  (let
    (
      (project-id (var-get next-project-id))
    )
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (> target-completion block-height) ERR_INVALID_INPUT)
    (asserts! (> budget-allocated u0) ERR_INVALID_INPUT)

    (map-set projects
      { project-id: project-id }
      {
        idea-id: idea-id,
        manager-id: manager-id,
        title: title,
        status: "planning",
        start-date: block-height,
        target-completion: target-completion,
        actual-completion: u0,
        total-milestones: u0,
        completed-milestones: u0,
        budget-allocated: budget-allocated,
        budget-used: u0
      }
    )

    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Add milestone to project
(define-public (add-milestone
  (project-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (target-date uint)
  (assigned-team principal)
  (deliverables (string-ascii 200)))
  (let
    (
      (milestone-id (var-get next-milestone-id))
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
      (milestone-index (get total-milestones project-data))
    )
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (> target-date block-height) ERR_INVALID_INPUT)

    (map-set milestones
      { milestone-id: milestone-id }
      {
        project-id: project-id,
        title: title,
        description: description,
        status: "pending",
        target-date: target-date,
        completion-date: u0,
        assigned-team: assigned-team,
        deliverables: deliverables
      }
    )

    (map-set project-milestones
      { project-id: project-id, milestone-index: milestone-index }
      { milestone-id: milestone-id }
    )

    (map-set projects
      { project-id: project-id }
      (merge project-data {
        total-milestones: (+ milestone-index u1)
      })
    )

    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Complete milestone
(define-public (complete-milestone (milestone-id uint))
  (let
    (
      (milestone-data (unwrap! (map-get? milestones { milestone-id: milestone-id }) ERR_NOT_FOUND))
      (project-id (get project-id milestone-data))
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq (get status milestone-data) "pending") ERR_INVALID_STATUS)

    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone-data {
        status: "completed",
        completion-date: block-height
      })
    )

    (map-set projects
      { project-id: project-id }
      (merge project-data {
        completed-milestones: (+ (get completed-milestones project-data) u1)
      })
    )

    (ok true)
  )
)

;; Update project status
(define-public (update-project-status (project-id uint) (new-status (string-ascii 20)))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set projects
      { project-id: project-id }
      (merge project-data {
        status: new-status,
        actual-completion: (if (is-eq new-status "completed") block-height (get actual-completion project-data))
      })
    )
    (ok true)
  )
)

;; Assign team member to project
(define-public (assign-team-member (project-id uint) (team-member principal) (role (string-ascii 50)))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len role) u0) ERR_INVALID_INPUT)

    (map-set team-assignments
      { project-id: project-id, team-member: team-member }
      { role: role, assignment-date: block-height }
    )
    (ok true)
  )
)

;; Update budget usage
(define-public (update-budget-usage (project-id uint) (amount-used uint))
  (let
    (
      (project-data (unwrap! (map-get? projects { project-id: project-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= amount-used (get budget-allocated project-data)) ERR_INVALID_INPUT)

    (map-set projects
      { project-id: project-id }
      (merge project-data { budget-used: amount-used })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

;; Get project milestone by index
(define-read-only (get-project-milestone (project-id uint) (milestone-index uint))
  (map-get? project-milestones { project-id: project-id, milestone-index: milestone-index })
)

;; Get team assignment
(define-read-only (get-team-assignment (project-id uint) (team-member principal))
  (map-get? team-assignments { project-id: project-id, team-member: team-member })
)

;; Get project progress percentage
(define-read-only (get-project-progress (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project-data
      (if (> (get total-milestones project-data) u0)
        (/ (* (get completed-milestones project-data) u100) (get total-milestones project-data))
        u0)
    u0
  )
)

;; Get total projects count
(define-read-only (get-total-projects)
  (- (var-get next-project-id) u1)
)
