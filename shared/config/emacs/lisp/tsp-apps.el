;;; tsp-apps.el --- Applications -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(use-package ghostel
  :ensure t
  :commands ghostel
  :init
  (setq ghostel-module-auto-install 'download)
  (setq-default ghostel-glyph-scale-floor 1.0))

(use-package multiple-cursors
  :ensure t
  :init
  (setq mc/list-file (tsp/emacs-state-file ".mc-lists.el"))
  (with-eval-after-load 'org
    ;; Org's local map shadows the global multiple-cursors bindings.
    ;; Keep the displaced Org commands available on nearby keys.
    (define-key org-mode-map (kbd "C-c M-<") #'org-promote-subtree)
    (define-key org-mode-map (kbd "C-c M-'") #'org-cycle-agenda-files)
    (define-key org-mode-map (kbd "C-c C-<") #'mc/mark-all-like-this)
    (define-key org-mode-map (kbd "C-'") #'mc/skip-to-next-like-this))
  :config
  (mc/load-lists)
  (setq mc/cmds-to-run-once
        (delq 'org-self-insert-command mc/cmds-to-run-once))
  (add-to-list 'mc/cmds-to-run-for-all 'org-self-insert-command)
  (dolist (command '(mc/vertical-align mc/vertical-align-with-space))
    (setq mc/cmds-to-run-for-all
          (delq command mc/cmds-to-run-for-all))
    (add-to-list 'mc/cmds-to-run-once command))
  :bind
  (("C-c v" . mc/vertical-align-with-space)
   ("C-S-c C-S-c" . mc/edit-lines)
   ("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   ("C-'" . mc/skip-to-next-like-this)
   ("C-;" . mc/skip-to-previous-like-this)))

(use-package symbol-overlay
  :ensure t
  :bind
  (("M-i" . symbol-overlay-put)
   ("M-n" . symbol-overlay-switch-forward)
   ("M-p" . symbol-overlay-switch-backward)
   ("<f7>" . symbol-overlay-mode)
   ("<f8>" . symbol-overlay-remove-all)))

(use-package symbol-overlay-mc
  :ensure t
  :after symbol-overlay
  :bind
  (("M-a" . symbol-overlay-mc-mark-all)
   ("C-c n" . symbol-overlay-mc-mark-all)))

(use-package dired-x
  :ensure nil
  :after dired
  :hook (dired-mode . dired-omit-mode)
  :config
  (setq dired-omit-files (concat dired-omit-files "\\|^\\..+$")))

(use-package magit
  :ensure t
  :bind
  (("C-x g" . magit-status)
   ("C-x M-g" . magit-dispatch))
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(use-package telega
  :ensure t
  :commands telega
  :init
  (setq telega-server-libs-prefix
        (expand-file-name "~/.local")
        telega-use-images t
        telega-root-show-avatars nil
        telega-user-show-avatars nil
        telega-chat-show-avatars nil
        telega-completions-username-show-avatars nil
        telega-emoji-use-images nil
        telega-symbol-width 1
        telega-open-file-function 'org-open-file)
  :config
  (require 'tsp-telega-font)
  (unless (advice-member-p #'tsp/telega-khmer-aware-eliding
                           'telega-fmt-eval-eliding)
    (advice-add 'telega-fmt-eval-eliding
                :around #'tsp/telega-khmer-aware-eliding))
  (unless (advice-member-p #'tsp/telega-notification-valid-message
                           'telega-notifications--chat-msg0)
    (advice-add 'telega-notifications--chat-msg0
                :around #'tsp/telega-notification-valid-message))
  (unless (advice-member-p #'tsp/telega-location-live-for-compatible
                           'telega-msg-location-live-for)
    (advice-add 'telega-msg-location-live-for
                :around #'tsp/telega-location-live-for-compatible))
  (dolist (handler '(telega--on-updateChatActiveStories
                     telega--on-updateChatLastMessage
                     telega--on-updateChatPosition))
    (unless (advice-member-p #'tsp/telega-ignore-early-chat-update handler)
      (advice-add handler :around #'tsp/telega-ignore-early-chat-update)))
  (keymap-set telega-chat-mode-map "C-c C-v"
              #'tsp/telega-chatbuf-attach-clipboard)
  (keymap-set telega-msg-button-map "C" #'tsp/telega-copy-image)
  (keymap-set telega-msg-button-map "E" #'tsp/telega-open-externally)
  (keymap-set telega-msg-button-map "F" #'tsp/telega-reveal-in-nautilus)
  (telega-notifications-mode 1))

(defconst tsp/telega-clipboard-image-types
  '(("image/png" . "png")
    ("image/jpeg" . "jpg")
    ("image/webp" . "webp")
    ("image/gif" . "gif"))
  "Supported clipboard image MIME types and filename extensions.")

(defun tsp/telega--clipboard-image-spec ()
  "Return the Wayland clipboard image MIME type and extension."
  (with-temp-buffer
    (unless (zerop (call-process "wl-paste" nil t nil "--list-types"))
      (user-error "Could not inspect the Wayland clipboard"))
    (let ((types (split-string (buffer-string) "[\n\r]+" t)))
      (or (seq-find (lambda (spec) (member (car spec) types))
                    tsp/telega-clipboard-image-types)
          (user-error "The clipboard does not contain a supported image")))))

(defun tsp/telega-chatbuf-attach-clipboard (as-file-p)
  "Attach a clipboard image to the current Telega chat.
With a prefix argument AS-FILE-P, attach it as a document."
  (interactive "P")
  (if (not (executable-find "wl-paste"))
      (telega-chatbuf-attach-clipboard as-file-p)
    (pcase-let* ((`(,mime . ,extension)
                  (tsp/telega--clipboard-image-spec))
                 (file (telega-temp-name "clipboard-"
                                         (concat "." extension))))
      (with-temp-buffer
        (set-buffer-multibyte nil)
        (unless (zerop (call-process "wl-paste" nil t nil
                                     "--no-newline" "--type" mime))
          (user-error "Could not read the clipboard image"))
        (let ((coding-system-for-write 'binary))
          (write-region (point-min) (point-max) file nil 'quiet)))
      (telega-chatbuf-attach-media file (when as-file-p 'preview)))))

(defun tsp/telega--with-message-file (msg action description)
  "Run ACTION with MSG's local file, downloading it when necessary.
DESCRIPTION names the operation in progress messages."
  (unless msg
    (user-error "Point is not on a Telega message"))
  (let ((file (telega-msg--content-file msg)))
    (unless file
      (user-error "This message has no associated file"))
    (unless (or (telega-file--downloaded-p file)
                (telega-file--downloading-p file)
                (telega-file--can-download-p file))
      (user-error "The message file cannot be downloaded"))
    (unless (telega-file--downloaded-p file)
      (message "Telega: downloading file to %s..." description))
    (telega-file--download file
      :priority 32
      :update-callback
      (lambda (downloaded-file)
        (telega-msg-redisplay msg)
        (when (telega-file--downloaded-p downloaded-file)
          (let ((path (telega--tl-get downloaded-file :local :path)))
            (unless (and path (file-exists-p path))
              (user-error "Telega downloaded the file but no local path exists"))
            (funcall action path)))))))

(defun tsp/telega--file-mime-type (file)
  "Return FILE's MIME type using the system `file' utility."
  (unless (executable-find "file")
    (user-error "Install the `file' utility to detect image types"))
  (with-temp-buffer
    (unless (zerop (call-process "file" nil t nil
                                 "--brief" "--mime-type" "--" file))
      (user-error "Could not determine the downloaded file's MIME type"))
    (string-trim (buffer-string))))

(defun tsp/telega-copy-image (msg)
  "Copy the image belonging to Telega message MSG to the clipboard."
  (interactive (list (telega-msg-for-interactive)))
  (unless (executable-find "wl-copy")
    (user-error "Install wl-clipboard to copy images"))
  (tsp/telega--with-message-file
   msg
   (lambda (file)
     (let ((mime (tsp/telega--file-mime-type file)))
       (unless (string-prefix-p "image/" mime)
         (user-error "This message's file is not an image"))
       ;; Cursor Clip records PNG selections but ignores a selection that only
       ;; offers image/jpeg.  Normalize other image formats so the image is
       ;; both pasteable and visible in the Mod+V clipboard history.
       (let ((clipboard-file file)
             (temporary-p nil))
         (unless (string= mime "image/png")
           (unless (executable-find "magick")
             (user-error "Install ImageMagick to copy non-PNG images"))
           (setq clipboard-file (telega-temp-name "clipboard-copy-" ".png")
                 temporary-p t)
           (unless (zerop (call-process "magick" nil nil nil
                                        file clipboard-file))
             (user-error "Could not convert the image to PNG")))
         (unwind-protect
             (unless (zerop (call-process "wl-copy" clipboard-file nil nil
                                          "--type" "image/png"))
               (user-error "Could not copy the image to the clipboard"))
           (when (and temporary-p (file-exists-p clipboard-file))
             (delete-file clipboard-file)))
         (message "Copied Telega image to the clipboard as PNG"))))
   "copy it to the clipboard"))

(defun tsp/telega-open-externally (msg)
  "Open the file belonging to Telega message MSG using `xdg-open'."
  (interactive (list (telega-msg-for-interactive)))
  (unless (executable-find "xdg-open")
    (user-error "Could not find xdg-open"))
  (tsp/telega--with-message-file
   msg
   (lambda (file)
     (start-process "telega-xdg-open" nil "xdg-open" file)
     (message "Opened %s externally" (file-name-nondirectory file)))
   "open it externally"))

(defun tsp/telega-reveal-in-nautilus (msg)
  "Reveal the file belonging to Telega message MSG in Nautilus."
  (interactive (list (telega-msg-for-interactive)))
  (unless (executable-find "nautilus")
    (user-error "Could not find Nautilus"))
  (tsp/telega--with-message-file
   msg
   (lambda (file)
     (start-process "telega-nautilus" nil "nautilus" "--select" file)
     (message "Revealed %s in Nautilus" (file-name-nondirectory file)))
   "reveal it in Nautilus"))

(defun tsp/telega-ignore-early-chat-update (original event)
  "Ignore EVENT until its chat has been added to telega's local cache."
  (let* ((active-stories (plist-get event :active_stories))
         (chat-id (or (plist-get event :chat_id)
                      (plist-get active-stories :chat_id))))
    (when (and chat-id (telega-chat-get chat-id 'offline))
      (funcall original event))))

(defun tsp/telega-location-live-for-compatible (original msg)
  "Handle ordinary locations from TDLib versions with no live fields."
  (let* ((content (plist-get msg :content))
         (live-period (plist-get content :live_period))
         (expires-in (plist-get content :expires_in)))
    (when (and (numberp live-period) (numberp expires-in))
      (funcall original msg))))

(defun tsp/telega-notification-valid-message (original msg &rest args)
  "Call ORIGINAL for MSG only when it has valid Telegram identifiers."
  (when (and (integerp (plist-get msg :id))
             (integerp (plist-get msg :chat_id)))
    (apply original msg args)))

(defun tsp/telega-dashboard-chat-insert (chat)
  "Insert a lightweight one-line dashboard entry for CHAT."
  (let ((unread (plist-get chat :unread_count)))
    (insert (telega-chat-title chat))
    (when (and (integerp unread) (> unread 0))
      (insert (propertize (format "  %d unread" unread)
                          'face 'font-lock-warning-face)))))

(defun tsp/dashboard-jump-to-telega-chats ()
  "Move point to the Telega chats dashboard section."
  (interactive)
  (goto-char (point-min))
  (when (search-forward "Telega Chats:" nil t)
    (forward-line 1)
    (back-to-indentation)))

(defun tsp/dashboard-insert-telega-chats (list-size)
  "Insert up to LIST-SIZE recent Telega chats into the dashboard."
  (dashboard-insert-heading "Telega Chats:"
                            (dashboard-get-shortcut 'telega-chats))
  (if (not (and (fboundp 'telega-server-live-p)
                (telega-server-live-p)))
      (insert (propertize "\n    Telega is starting…"
                          'face 'dashboard-no-items-face))
    (dolist (chat
             (seq-take
              (seq-sort
               (lambda (chat-a chat-b)
                 (> (or (plist-get (plist-get chat-a :last_message) :date) 0)
                    (or (plist-get (plist-get chat-b :last_message) :date) 0)))
               (copy-sequence
                (telega-filter-chats (telega-chats-list))))
              list-size))
      (insert "\n    ")
      (telega-button--insert 'telega-chat chat
        :inserter #'tsp/telega-dashboard-chat-insert)))
  nil)

(defun tsp/dashboard-insert-agenda (list-size)
  "Insert Org agenda items, limited to LIST-SIZE."
  (require 'org-agenda)
  (let ((items (dashboard-agenda--sorted-agenda)))
    (dashboard-insert-section
     "Agenda for the coming week:"
     items list-size 'agenda (dashboard-get-shortcut 'agenda)
     `(lambda (&rest _)
        (let ((file (get-text-property 0 'dashboard-agenda-file ,el))
              (point (get-text-property 0 'dashboard-agenda-loc ,el)))
          (find-file file)
          (goto-char point)))
     (format "%s" el))))

(defun tsp/dashboard-org-projects ()
  "Return unfinished Org projects from `org-agenda-files'."
  (require 'org)
  (let (projects)
    (org-map-entries
     (lambda ()
       (when (tsp/org-project-p)
         (push (propertize (org-get-heading t t t t)
                           'tsp/org-project-marker (copy-marker (point)))
               projects)))
     "+project/-DONE-CANCELLED-SOMEDAY" 'agenda)
    (nreverse projects)))

(defun tsp/dashboard-insert-org-projects (list-size)
  "Insert up to LIST-SIZE unfinished projects from the Org agenda."
  (dashboard-insert-section
   "Projects:"
   (tsp/dashboard-org-projects)
   list-size 'projects (dashboard-get-shortcut 'projects)
   `(lambda (&rest _)
      (let ((marker (get-text-property 0 'tsp/org-project-marker ,el)))
        (when (marker-buffer marker)
          (pop-to-buffer-same-window (marker-buffer marker))
          (goto-char marker)
          (org-show-context))))
   (format "%s" el)))

(use-package dashboard
  :ensure t
  :demand t
  :bind (("C-c d" . tsp/dashboard-open))
  :init
  (setq dashboard-startup-banner 'logo
        dashboard-image-banner-max-height 96
        dashboard-banner-logo-title "Welcome back"
        dashboard-center-content t
        dashboard-vertically-center-content nil
        dashboard-set-heading-icons nil
        dashboard-set-file-icons nil
        dashboard-show-shortcuts t
        dashboard-agenda-time-string-format "%Y-%m-%d %H:%M"
        dashboard-items '((agenda . 7)
                          (telega-chats . 6)
                          (recents . 5)
                          (projects . 5)))
  :config
  (setf (alist-get 'agenda dashboard-item-generators)
        #'tsp/dashboard-insert-agenda)
  (setf (alist-get 'projects dashboard-item-generators)
        #'tsp/dashboard-insert-org-projects)
  (add-to-list 'dashboard-item-generators
               '(telega-chats . tsp/dashboard-insert-telega-chats))
  (add-to-list 'dashboard-item-shortcuts '(telega-chats . "t"))
  (keymap-set dashboard-mode-map "t" #'tsp/dashboard-jump-to-telega-chats)
  (dashboard-setup-startup-hook))

(defun tsp/dashboard-refresh-after-telega ()
  "Refresh the dashboard once Telega has actually fetched its chats."
  (tsp/dashboard-refresh-if-visible))

(defun tsp/dashboard-refresh-if-visible ()
  "Refresh the dashboard when it already exists."
  (when-let* ((buffer (get-buffer "*dashboard*")))
    ;; `dashboard-refresh-buffer' aliases the interactive `dashboard-open' and
    ;; can make widget navigation fail when called by a timer.  Re-render the
    ;; existing buffer directly without changing the selected buffer or point.
    (when (fboundp 'dashboard-insert-startupify-lists)
      (with-current-buffer buffer
        (dashboard-insert-startupify-lists t)))))

(defun tsp/dashboard-start-telega (&optional frame)
  "Start Telega in the background on graphical FRAME."
  (when (and (not noninteractive)
             (frame-live-p frame)
             (display-graphic-p frame)
             (not (and (fboundp 'telega-server-live-p)
                       (telega-server-live-p))))
    ;; Telega calculates and caches image sizes while constructing its buffers.
    ;; In a daemon, ensure that happens with the client frame selected.
    (with-selected-frame frame
      (save-window-excursion (telega)))))

(defun tsp/dashboard-schedule-telega (&optional frame)
  "Schedule Telega after graphical FRAME becomes responsive."
  (let ((frame (or frame (selected-frame))))
    (when (and (not noninteractive) (display-graphic-p frame))
      (run-with-idle-timer 2 nil #'tsp/dashboard-start-telega frame))))

(defun tsp/dashboard-open ()
  "Open a freshly rendered dashboard, including after its buffer was killed."
  (interactive)
  (when-let ((buffer (get-buffer "*dashboard*")))
    ;; Do not use `with-current-buffer' here: when this command is invoked
    ;; from the dashboard, killing BUFFER would leave the unwind code trying
    ;; to restore a current buffer that no longer exists.
    (when (provided-mode-derived-p (buffer-local-value 'major-mode buffer)
                                   'dashboard-mode)
      (kill-buffer buffer)))
  (dashboard-open))

(defun tsp/dashboard-open-on-startup ()
  "Open the dashboard after other startup buffer changes have finished."
  (when (and (not noninteractive) (not (daemonp)))
    (tsp/dashboard-open)))

(defun tsp/dashboard-initialize-client-frame (&optional _frame)
  "Initialize dashboard services for a newly created daemon client frame."
  (when (daemonp)
    (tsp/dashboard-schedule-telega)))

(add-hook 'emacs-startup-hook #'tsp/dashboard-open-on-startup 99)
(add-hook 'emacs-startup-hook #'tsp/dashboard-schedule-telega 90)
(add-hook 'server-after-make-frame-hook #'tsp/dashboard-initialize-client-frame)
(add-hook 'telega-chats-fetched-hook #'tsp/dashboard-refresh-after-telega)

(use-package exec-path-from-shell
  :ensure t
  :if (memq window-system '(mac ns x))
  :config
  (setq exec-path-from-shell-variables '("PATH" "MANPATH"))
  (exec-path-from-shell-initialize))

(use-package emms
  :ensure t
  :commands (emms emms-playlist-mode-go emms-browser emms-start emms-stop
                  emms-pause emms-next emms-previous tsp/emms-refresh-library)
  :bind (("C-c e g" . emms-playlist-mode-go)
         ("C-c e b" . emms-browser)
         ("C-c e u" . tsp/emms-refresh-library)
         ("C-c e s" . emms-start)
         ("C-c e x" . emms-stop)
         ("C-c e p" . emms-pause)
         ("C-c e n" . emms-next)
         ("C-c e r" . emms-previous)
         ("C-c e +" . emms-volume-raise)
         ("C-c e -" . emms-volume-lower)
         ("C-c e R" . emms-toggle-repeat-playlist)
         ("C-c e S" . emms-shuffle))
  :init
  (setq emms-directory (tsp/emacs-state-file "emms/")
        emms-mode-line-format " [%s]"
        emms-show-format "Now playing: %s")
  :custom
  (emms-directory (tsp/emacs-state-file "emms/"))
  (emms-source-file-default-directory "~/Music/")
  (emms-browser-covers #'emms-browser-cache-thumbnail-async)
  (emms-playing-time-display-format " [%s]")
  (emms-volume-change-amount 5)
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-player-list '(emms-player-mpv))
  (require 'emms-info-native)
  (setq emms-info-functions '(emms-info-native))
  (require 'emms-browser)

  (defcustom tsp/emms-mode-line-cover-height 16
    "Height in pixels of the EMMS cover shown in the mode line."
    :type 'integer
    :group 'emms)

  (defun tsp/emms-mode-line-cover ()
    "Return the current track's cover art for the mode line."
    (let* ((track (emms-playlist-current-selected-track))
           (description (and track (emms-track-description track)))
           (artist (and track (emms-track-get track 'info-artist)))
           (title (and track (emms-track-get track 'info-title)))
           (album (and track (emms-track-get track 'info-album)))
           (label (cond
                   ((and artist title) (format "%s - %s" artist title))
                   (title title)
                   (description description)
                   (t "Unknown track")))
           (help (if album
                     (format "%s — %s" album description)
                   description))
           (path (and track (emms-track-file-p track)
                      (emms-track-name track)))
           (cover (and path (display-graphic-p)
                       (ignore-errors
                         (emms-browser-get-cover-from-path path 'small))))
           (image (and cover
                       (ignore-errors
                         (create-image cover nil nil
                                       :height tsp/emms-mode-line-cover-height
                                       :ascent 'center)))))
      (concat
       " "
       (propertize (if image " " "♫")
                   'display image
                   'help-echo help
                   'mouse-face 'mode-line-highlight)
       " "
       (propertize label 'help-echo help))))

  (setq emms-mode-line-mode-line-function #'tsp/emms-mode-line-cover)

  (setq emms-browser-info-title-format "%i%T. %t"
        emms-browser-playlist-info-title-format "%i%T. %t")
  (require 'emms-volume)
  (require 'emms-volume-mpv)
  (setq emms-volume-change-function 'emms-volume-mpv-change)
  (require 'emms-history)

  (defvar tsp/emms-history-loaded-p nil
    "Non-nil after EMMS history has been restored in this session.")

  (unless tsp/emms-history-loaded-p
    (emms-history-load)
    (setq tsp/emms-history-loaded-p t))

  (defun tsp/emms-playlist-fingerprint (buffer)
    "Return the ordered track identity list for playlist BUFFER."
    (with-current-buffer buffer
      (save-restriction
        (widen)
        (mapcar (lambda (track)
                  (cons (emms-track-type track)
                        (emms-track-name track)))
                (emms-playlist-tracks-in-region
                 (point-min) (point-max))))))

  (defun tsp/emms-deduplicate-playlists ()
    "Kill duplicate EMMS playlists while preserving distinct queues.

The active playlist is always retained.  Two playlists are duplicates when
their ordered track types and names are identical.  Return the number of
playlist buffers removed."
    (interactive)
    (let* ((active emms-playlist-buffer)
           (buffers (emms-playlist-buffer-list))
           (buffers (if (memq active buffers)
                        (cons active (delq active buffers))
                      buffers))
           (seen (make-hash-table :test #'equal))
           (removed 0))
      (dolist (buffer buffers)
        (when (buffer-live-p buffer)
          (let ((fingerprint (tsp/emms-playlist-fingerprint buffer)))
            (if (gethash fingerprint seen)
                (when (kill-buffer buffer)
                  (setq removed (1+ removed)))
              (puthash fingerprint buffer seen)))))
      ;; Rebuild the registry instead of destructively pruning it while its
      ;; buffers' kill hooks may also be changing the same list.
      (setq emms-playlist-buffers
            (seq-filter #'buffer-live-p emms-playlist-buffers))
      (when (called-interactively-p 'interactive)
        (message "Removed %d duplicate EMMS playlist%s"
                 removed (if (= removed 1) "" "s")))
      removed))

  (defun tsp/emms-refresh-library ()
    "Rescan the music directory and refresh the EMMS browser."
    (interactive)
    (let ((library (expand-file-name emms-source-file-default-directory)))
      (if (not (file-directory-p library))
          (message "EMMS library is not mounted: %s" library)
        (message "Refreshing EMMS library from %s..." library)
        ;; Populate the cache without adding the entire library to the user's queue.
        (with-temp-buffer
          (setq emms-playlist-buffer-p t
                emms-playlist-insert-track-function
                #'emms-playlist-mode-insert-track)
          (let ((emms-playlist-buffer (current-buffer)))
            (emms-add-directory-tree library)))
        ;; Older cache files may contain the printer's truncation marker,
        ;; which hides properties appearing after it (notably track titles).
        (maphash (lambda (path track)
                   (setcdr track (delq (intern "...") (cdr track)))
                   (when (and (emms-track-file-p track)
                              (file-in-directory-p path library))
                     ;; Native readers only overwrite tags they find, so clear
                     ;; optional values that may have been removed from a file.
                     (emms-track-set track 'info-discnumber nil)
                     (emms-info-native track)))
                 emms-cache-db)
        (emms-cache-sync t)
        (let (print-length print-level)
          (emms-cache-save))
        (when (buffer-live-p emms-browser-buffer)
          (with-current-buffer emms-browser-buffer
            (emms-browse-by emms-browser-default-browse-type)))
        (message "EMMS library refresh complete"))))

  ;; Cancel the old automatic refresh timer when reloading this config in an
  ;; existing Emacs session.
  (when (and (boundp 'tsp/emms-library-refresh-timer)
             (timerp tsp/emms-library-refresh-timer))
    (cancel-timer tsp/emms-library-refresh-timer)
    (makunbound 'tsp/emms-library-refresh-timer))
  (emms-mode-line-mode 1)
  (emms-playing-time-mode 1))

(provide 'tsp-apps)
;;; tsp-apps.el ends here
