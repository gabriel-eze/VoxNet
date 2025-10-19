;; Decentralized Social Media Platform - Optimized & Fixed Version
;; A censorship-resistant social platform with core features

;; ===== DATA STRUCTURES =====

;; User profiles
(define-map profile-registry
  { user-id: (string-ascii 64) }
  {
    principal: principal,
    username: (string-utf8 32),
    display-name: (string-utf8 64),
    bio: (string-utf8 256),
    avatar-url: (optional (string-utf8 256)),
    created-at: uint,
    follower-count: uint,
    following-count: uint,
    post-count: uint,
    verification-level: uint,
    moderation-status: (string-ascii 16),
    tip-enabled: bool,
    total-tips-received: uint
  }
)

;; User follows
(define-map follow-registry
  { follower: (string-ascii 64), following: (string-ascii 64) }
  { created-at: uint }
)

;; Content posts
(define-map post-registry
  { post-id: uint }
  {
    author: (string-ascii 64),
    content-hash: (buff 32),
    content: (string-utf8 1024),
    created-at: uint,
    parent-post-id: (optional uint),
    like-count: uint,
    reply-count: uint,
    visibility: (string-ascii 16),
    is-premium: bool,
    monetization-enabled: bool,
    tips-received: uint,
    moderation-status: (string-ascii 16)
  }
)

;; Post interactions
(define-map interaction-registry
  { post-id: uint, user-id: (string-ascii 64) }
  {
    liked: bool,
    bookmarked: bool,
    interacted-at: uint
  }
)

;; Notifications
(define-map notification-registry
  { notification-id: uint }
  {
    recipient: (string-ascii 64),
    sender: (optional (string-ascii 64)),
    notification-type: (string-ascii 16),
    related-post-id: (optional uint),
    created-at: uint,
    read: bool,
    content: (string-utf8 256)
  }
)

;; ===== VARIABLES =====

(define-data-var post-counter uint u1)
(define-data-var notification-counter uint u1)
(define-data-var fee-rate uint u200) ;; 2%
(define-data-var fee-collector principal tx-sender)
(define-data-var max-content-length uint u1024)
(define-data-var min-tip-threshold uint u1000000) ;; 1 STX minimum

;; ===== CONSTANTS =====

(define-constant ERR-MISSING (err u404))
(define-constant ERR-FORBIDDEN (err u401))
(define-constant ERR-BAD-PARAMS (err u400))
(define-constant ERR-DUPLICATE (err u409))
(define-constant ERR-DENIED (err u403))
(define-constant ERR-LOW-BALANCE (err u402))
(define-constant ERR-BAD-AMOUNT (err u422))

(define-constant MAX-USERNAME-LENGTH u32)
(define-constant MIN-USERNAME-LENGTH u3)
(define-constant MAX-USER-ID-LENGTH u64)
(define-constant MIN-USER-ID-LENGTH u3)
(define-constant MAX-BIO-LENGTH u256)
(define-constant MAX-DISPLAY-NAME-LENGTH u64)
(define-constant MAX-NOTIFICATION-CONTENT-LENGTH u256)

;; ===== VALIDATION FUNCTIONS =====

(define-private (validate-user-id (user-id (string-ascii 64)))
  (and 
    (>= (len user-id) MIN-USER-ID-LENGTH) 
    (<= (len user-id) MAX-USER-ID-LENGTH)
    (> (len user-id) u0)
  )
)

(define-private (validate-username (username (string-utf8 32)))
  (and 
    (>= (len username) MIN-USERNAME-LENGTH) 
    (<= (len username) MAX-USERNAME-LENGTH)
    (> (len username) u0)
  )
)

(define-private (validate-display-name (display-name (string-utf8 64)))
  (and 
    (> (len display-name) u0)
    (<= (len display-name) MAX-DISPLAY-NAME-LENGTH)
  )
)

(define-private (validate-bio (bio (string-utf8 256)))
  (<= (len bio) MAX-BIO-LENGTH)
)

(define-private (validate-visibility (visibility (string-ascii 16)))
  (or (is-eq visibility "public")
      (or (is-eq visibility "followers")
          (is-eq visibility "private")))
)

(define-private (validate-moderation-status (status (string-ascii 16)))
  (or (is-eq status "active")
      (or (is-eq status "suspended")
          (or (is-eq status "banned")
              (is-eq status "pending"))))
)

(define-private (check-active (user-profile (tuple (principal principal) (username (string-utf8 32)) (display-name (string-utf8 64)) (bio (string-utf8 256)) (avatar-url (optional (string-utf8 256))) (created-at uint) (follower-count uint) (following-count uint) (post-count uint) (verification-level uint) (moderation-status (string-ascii 16)) (tip-enabled bool) (total-tips-received uint))))
  (is-eq (get moderation-status user-profile) "active")
)

(define-private (validate-content (content (string-utf8 1024)))
  (and 
    (> (len content) u0)
    (<= (len content) (var-get max-content-length))
  )
)

(define-private (validate-tip-amount (amount uint))
  (and 
    (> amount u0)
    (>= amount (var-get min-tip-threshold))
  )
)

(define-private (validate-notification-type (notification-type (string-ascii 16)))
  (or (is-eq notification-type "follow")
      (or (is-eq notification-type "like")
          (or (is-eq notification-type "reply")
              (or (is-eq notification-type "tip")
                  (is-eq notification-type "mention")))))
)

;; Helper function to safely create notification content
(define-private (format-notification (username (string-utf8 32)) (action (string-utf8 32)))
  (let ((base-msg (concat username action)))
    (if (<= (len base-msg) MAX-NOTIFICATION-CONTENT-LENGTH)
        base-msg
        (unwrap-panic (slice? base-msg u0 MAX-NOTIFICATION-CONTENT-LENGTH))
    )
  )
)

;; ===== CORE FUNCTIONS =====

;; Register a new user
(define-public (new-user
                (user-id (string-ascii 64))
                (username (string-utf8 32))
                (display-name (string-utf8 64))
                (bio (string-utf8 256))
                (avatar-url (optional (string-utf8 256))))
  (begin
    ;; Comprehensive input validation
    (asserts! (validate-user-id user-id) ERR-BAD-PARAMS)
    (asserts! (validate-username username) ERR-BAD-PARAMS)
    (asserts! (validate-display-name display-name) ERR-BAD-PARAMS)
    (asserts! (validate-bio bio) ERR-BAD-PARAMS)
    (asserts! (is-none (map-get? profile-registry { user-id: user-id })) ERR-DUPLICATE)
    
    ;; Validate avatar URL if provided
    (match avatar-url
      url (asserts! (<= (len url) u256) ERR-BAD-PARAMS)
      true
    )
    
    ;; Create user profile
    (map-set profile-registry
      { user-id: user-id }
      {
        principal: tx-sender,
        username: username,
        display-name: display-name,
        bio: bio,
        avatar-url: avatar-url,
        created-at: block-height,
        follower-count: u0,
        following-count: u0,
        post-count: u0,
        verification-level: u0,
        moderation-status: "active",
        tip-enabled: true,
        total-tips-received: u0
      }
    )
    
    (ok user-id)
  )
)

;; Update user profile
(define-public (edit-profile
                (user-id (string-ascii 64))
                (display-name (string-utf8 64))
                (bio (string-utf8 256))
                (avatar-url (optional (string-utf8 256))))
  (let ((profile (unwrap! (map-get? profile-registry { user-id: user-id }) ERR-MISSING)))
    ;; Authorization and validation checks
    (asserts! (is-eq tx-sender (get principal profile)) ERR-FORBIDDEN)
    (asserts! (check-active profile) ERR-DENIED)
    (asserts! (validate-display-name display-name) ERR-BAD-PARAMS)
    (asserts! (validate-bio bio) ERR-BAD-PARAMS)
    
    ;; Validate avatar URL if provided
    (match avatar-url
      url (asserts! (<= (len url) u256) ERR-BAD-PARAMS)
      true
    )
    
    (map-set profile-registry
      { user-id: user-id }
      (merge profile { 
        display-name: display-name,
        bio: bio,
        avatar-url: avatar-url
      })
    )
    
    (ok true)
  )
)

;; Follow another user
(define-public (add-follow
                (follower-id (string-ascii 64))
                (following-id (string-ascii 64)))
  (let ((follower-profile (unwrap! (map-get? profile-registry { user-id: follower-id }) ERR-MISSING))
        (following-profile (unwrap! (map-get? profile-registry { user-id: following-id }) ERR-MISSING)))
    
    ;; Enhanced validation and authorization
    (asserts! (is-eq tx-sender (get principal follower-profile)) ERR-FORBIDDEN)
    (asserts! (not (is-eq follower-id following-id)) ERR-BAD-PARAMS)
    (asserts! (check-active follower-profile) ERR-DENIED)
    (asserts! (check-active following-profile) ERR-DENIED)
    (asserts! (is-none (map-get? follow-registry { follower: follower-id, following: following-id })) ERR-DUPLICATE)
    
    ;; Create follow relationship
    (map-set follow-registry
      { follower: follower-id, following: following-id }
      { created-at: block-height }
    )
    
    ;; Update counts
    (map-set profile-registry
      { user-id: following-id }
      (merge following-profile { follower-count: (+ (get follower-count following-profile) u1) })
    )
    
    (map-set profile-registry
      { user-id: follower-id }
      (merge follower-profile { following-count: (+ (get following-count follower-profile) u1) })
    )
    
    ;; Create notification with proper string handling
    (try! (emit-notification 
          following-id 
          (some follower-id)
          "follow" 
          none 
          (format-notification (get username follower-profile) u" followed you")))
    
    (ok true)
  )
)

;; Unfollow a user
(define-public (remove-follow
                (follower-id (string-ascii 64))
                (following-id (string-ascii 64)))
  (let ((follower-profile (unwrap! (map-get? profile-registry { user-id: follower-id }) ERR-MISSING))
        (following-profile (unwrap! (map-get? profile-registry { user-id: following-id }) ERR-MISSING)))
    
    (asserts! (is-eq tx-sender (get principal follower-profile)) ERR-FORBIDDEN)
    (asserts! (not (is-eq follower-id following-id)) ERR-BAD-PARAMS)
    (asserts! (is-some (map-get? follow-registry { follower: follower-id, following: following-id })) ERR-MISSING)
    
    ;; Remove follow relationship
    (map-delete follow-registry { follower: follower-id, following: following-id })
    
    ;; Update counts with underflow protection
    (map-set profile-registry
      { user-id: following-id }
      (merge following-profile { 
        follower-count: (if (> (get follower-count following-profile) u0)
                           (- (get follower-count following-profile) u1)
                           u0)
      })
    )
    
    (map-set profile-registry
      { user-id: follower-id }
      (merge follower-profile { 
        following-count: (if (> (get following-count follower-profile) u0)
                            (- (get following-count follower-profile) u1)
                            u0)
      })
    )
    
    (ok true)
  )
)

;; Create a new post
(define-public (new-post
                (author-id (string-ascii 64))
                (content (string-utf8 1024))
                (parent-post-id (optional uint))
                (visibility (string-ascii 16))
                (is-premium bool)
                (monetization-enabled bool))
  (let ((user-profile (unwrap! (map-get? profile-registry { user-id: author-id }) ERR-MISSING))
        (content-hash (sha256 (unwrap-panic (to-consensus-buff? content))))
        (post-id (var-get post-counter)))
    
    ;; Comprehensive validation
    (asserts! (is-eq tx-sender (get principal user-profile)) ERR-FORBIDDEN)
    (asserts! (check-active user-profile) ERR-DENIED)
    (asserts! (validate-content content) ERR-BAD-PARAMS)
    (asserts! (validate-visibility visibility) ERR-BAD-PARAMS)
    
    ;; Validate parent post if provided
    (match parent-post-id
      parent-id (let ((parent-post (unwrap! (map-get? post-registry { post-id: parent-id }) ERR-MISSING)))
                  (asserts! (is-eq (get moderation-status parent-post) "active") ERR-DENIED)
                  
                  ;; Update parent post reply count
                  (map-set post-registry
                    { post-id: parent-id }
                    (merge parent-post { reply-count: (+ (get reply-count parent-post) u1) })
                  )
                  
                  ;; Notify parent post author if different from current user
                  (if (not (is-eq (get author parent-post) author-id))
                      (begin
                        (try! (emit-notification 
                              (get author parent-post) 
                              (some author-id)
                              "reply" 
                              (some parent-id) 
                              (format-notification (get username user-profile) u" replied to your post")))
                        true)
                      true)
                )
      true
    )
    
    ;; Create the post
    (map-set post-registry
      { post-id: post-id }
      {
        author: author-id,
        content-hash: content-hash,
        content: content,
        created-at: block-height,
        parent-post-id: parent-post-id,
        like-count: u0,
        reply-count: u0,
        visibility: visibility,
        is-premium: is-premium,
        monetization-enabled: monetization-enabled,
        tips-received: u0,
        moderation-status: "active"
      }
    )
    
    ;; Update user's post count
    (map-set profile-registry
      { user-id: author-id }
      (merge user-profile { post-count: (+ (get post-count user-profile) u1) })
    )
    
    ;; Increment post ID counter
    (var-set post-counter (+ post-id u1))
    
    (ok post-id)
  )
)

;; Like a post
(define-public (add-like
                (user-id (string-ascii 64))
                (post-id uint))
  (let ((user-profile (unwrap! (map-get? profile-registry { user-id: user-id }) ERR-MISSING))
        (post (unwrap! (map-get? post-registry { post-id: post-id }) ERR-MISSING))
        (interaction (map-get? interaction-registry { post-id: post-id, user-id: user-id })))
    
    (asserts! (is-eq tx-sender (get principal user-profile)) ERR-FORBIDDEN)
    (asserts! (check-active user-profile) ERR-DENIED)
    (asserts! (is-eq (get moderation-status post) "active") ERR-DENIED)
    (asserts! (not (is-eq (get author post) user-id)) ERR-BAD-PARAMS) ;; Can't like own post
    
    ;; Handle interaction
    (match interaction
      existing-interaction 
        (begin
          (asserts! (not (get liked existing-interaction)) ERR-DUPLICATE)
          (map-set interaction-registry
            { post-id: post-id, user-id: user-id }
            (merge existing-interaction { liked: true, interacted-at: block-height })
          )
        )
      (map-set interaction-registry
        { post-id: post-id, user-id: user-id }
        { liked: true, bookmarked: false, interacted-at: block-height }
      )
    )
    
    ;; Update post like count
    (map-set post-registry
      { post-id: post-id }
      (merge post { like-count: (+ (get like-count post) u1) })
    )
    
    ;; Create notification for post author
    (try! (emit-notification 
          (get author post) 
          (some user-id)
          "like" 
          (some post-id) 
          (format-notification (get username user-profile) u" liked your post")))
    
    (ok true)
  )
)

;; Unlike a post
(define-public (remove-like
                (user-id (string-ascii 64))
                (post-id uint))
  (let ((user-profile (unwrap! (map-get? profile-registry { user-id: user-id }) ERR-MISSING))
        (post (unwrap! (map-get? post-registry { post-id: post-id }) ERR-MISSING))
        (interaction (unwrap! (map-get? interaction-registry { post-id: post-id, user-id: user-id }) ERR-MISSING)))
    
    (asserts! (is-eq tx-sender (get principal user-profile)) ERR-FORBIDDEN)
    (asserts! (get liked interaction) ERR-BAD-PARAMS)
    
    ;; Update interaction
    (map-set interaction-registry
      { post-id: post-id, user-id: user-id }
      (merge interaction { liked: false, interacted-at: block-height })
    )
    
    ;; Update post like count with underflow protection
    (map-set post-registry
      { post-id: post-id }
      (merge post { 
        like-count: (if (> (get like-count post) u0)
                       (- (get like-count post) u1)
                       u0)
      })
    )
    
    (ok true)
  )
)

;; Send a tip for content
(define-public (transfer-tip
                (tipper-id (string-ascii 64))
                (recipient-id (string-ascii 64))
                (post-id (optional uint))
                (amount uint))
  (let ((tipper-profile (unwrap! (map-get? profile-registry { user-id: tipper-id }) ERR-MISSING))
        (recipient-profile (unwrap! (map-get? profile-registry { user-id: recipient-id }) ERR-MISSING)))
    
    ;; Enhanced tip validation
    (asserts! (is-eq tx-sender (get principal tipper-profile)) ERR-FORBIDDEN)
    (asserts! (check-active tipper-profile) ERR-DENIED)
    (asserts! (check-active recipient-profile) ERR-DENIED)
    (asserts! (get tip-enabled recipient-profile) ERR-DENIED)
    (asserts! (not (is-eq tipper-id recipient-id)) ERR-BAD-PARAMS)
    (asserts! (validate-tip-amount amount) ERR-BAD-AMOUNT)
    
    ;; Check if sender has sufficient balance
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR-LOW-BALANCE)
    
    ;; Validate post if provided
    (match post-id
      pid (let ((post (unwrap! (map-get? post-registry { post-id: pid }) ERR-MISSING)))
            (asserts! (is-eq (get author post) recipient-id) ERR-BAD-PARAMS)
            (asserts! (get monetization-enabled post) ERR-DENIED)
            (asserts! (is-eq (get moderation-status post) "active") ERR-DENIED)
            
            ;; Update post tips
            (map-set post-registry
              { post-id: pid }
              (merge post { tips-received: (+ (get tips-received post) amount) })
            )
          )
      true
    )
    
    ;; Process payment with proper fee calculation
    (let ((platform-fee (/ (* amount (var-get fee-rate)) u10000))
          (recipient-amount (- amount platform-fee)))
      
      (asserts! (> recipient-amount u0) ERR-BAD-AMOUNT)
      
      ;; Transfer tip to contract first
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      
      ;; Transfer platform fee
      (if (> platform-fee u0)
          (as-contract (try! (stx-transfer? platform-fee tx-sender (var-get fee-collector))))
          true)
      
      ;; Transfer recipient amount
      (as-contract (try! (stx-transfer? recipient-amount tx-sender (get principal recipient-profile))))
      
      ;; Update recipient's total tips
      (map-set profile-registry
        { user-id: recipient-id }
        (merge recipient-profile { total-tips-received: (+ (get total-tips-received recipient-profile) amount) })
      )
      
      ;; Create notification
      (try! (emit-notification 
            recipient-id 
            (some tipper-id)
            "tip" 
            post-id 
            (format-notification (get username tipper-profile) u" sent you a tip")))
      
      (ok recipient-amount)
    )
  )
)

;; Mark notification as read
(define-public (read-notification
                (user-id (string-ascii 64))
                (notification-id uint))
  (let ((user-profile (unwrap! (map-get? profile-registry { user-id: user-id }) ERR-MISSING))
        (notification (unwrap! (map-get? notification-registry { notification-id: notification-id }) ERR-MISSING)))
    
    (asserts! (is-eq tx-sender (get principal user-profile)) ERR-FORBIDDEN)
    (asserts! (is-eq (get recipient notification) user-id) ERR-FORBIDDEN)
    
    (map-set notification-registry
      { notification-id: notification-id }
      (merge notification { read: true })
    )
    
    (ok true)
  )
)

;; Create a notification
(define-private (emit-notification
                (recipient (string-ascii 64))
                (sender (optional (string-ascii 64)))
                (notification-type (string-ascii 16))
                (related-post-id (optional uint))
                (content (string-utf8 256)))
  (let ((notification-id (var-get notification-counter)))
    
    ;; Validate inputs
    (asserts! (validate-notification-type notification-type) ERR-BAD-PARAMS)
    (asserts! (<= (len content) MAX-NOTIFICATION-CONTENT-LENGTH) ERR-BAD-PARAMS)
    
    (map-set notification-registry
      { notification-id: notification-id }
      {
        recipient: recipient,
        sender: sender,
        notification-type: notification-type,
        related-post-id: related-post-id,
        created-at: block-height,
        read: false,
        content: content
      }
    )
    
    (var-set notification-counter (+ notification-id u1))
    (ok notification-id)
  )
)

;; ===== ADMIN FUNCTIONS =====

(define-public (set-fee-rate (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get fee-collector)) ERR-FORBIDDEN)
    (asserts! (<= new-fee u1000) ERR-BAD-PARAMS) ;; Max 10%
    (var-set fee-rate new-fee)
    (ok true)
  )
)

(define-public (set-min-tip (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get fee-collector)) ERR-FORBIDDEN)
    (asserts! (> new-amount u0) ERR-BAD-PARAMS)
    (var-set min-tip-threshold new-amount)
    (ok true)
  )
)

;; ===== READ-ONLY FUNCTIONS =====

(define-read-only (fetch-profile (user-id (string-ascii 64)))
  (ok (unwrap! (map-get? profile-registry { user-id: user-id }) ERR-MISSING))
)

(define-read-only (fetch-post (post-id uint))
  (ok (unwrap! (map-get? post-registry { post-id: post-id }) ERR-MISSING))
)

(define-read-only (check-following (follower-id (string-ascii 64)) (following-id (string-ascii 64)))
  (is-some (map-get? follow-registry { follower: follower-id, following: following-id }))
)

(define-read-only (fetch-interaction (user-id (string-ascii 64)) (post-id uint))
  (ok (default-to 
        { liked: false, bookmarked: false, interacted-at: u0 }
        (map-get? interaction-registry { post-id: post-id, user-id: user-id })
      ))
)

(define-read-only (fetch-notification (notification-id uint))
  (ok (unwrap! (map-get? notification-registry { notification-id: notification-id }) ERR-MISSING))
)

(define-read-only (fetch-post-counter)
  (var-get post-counter)
)

(define-read-only (fetch-notification-counter)
  (var-get notification-counter)
)

(define-read-only (fetch-fee-rate)
  (var-get fee-rate)
)

(define-read-only (fetch-min-tip)
  (var-get min-tip-threshold)
)

(define-read-only (fetch-balance)
  (stx-get-balance (as-contract tx-sender))
)