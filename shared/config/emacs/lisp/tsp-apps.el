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
  :bind
  (("C-S-c C-S-c" . mc/edit-lines)
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
  (telega-notifications-mode 1))

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

(defun tsp/dashboard-start-telega ()
  "Start Telega in the background after startup."
  (when (and (not noninteractive)
             (not (and (fboundp 'telega-server-live-p)
                       (telega-server-live-p))))
    (save-window-excursion (telega))))

(defun tsp/dashboard-schedule-telega ()
  "Schedule Telega after Emacs becomes responsive."
  (when (not noninteractive)
    (run-with-idle-timer 2 nil #'tsp/dashboard-start-telega)))

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
  (emms-source-file-default-directory "~/pCloud/My Music/")
  (emms-browser-covers #'emms-browser-cache-thumbnail-async)
  (emms-volume-change-amount 5)
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-player-list '(emms-player-mpv))
  (require 'emms-info-native)
  (setq emms-info-functions '(emms-info-native))
  (setq emms-browser-info-title-format "%i%T. %t"
        emms-browser-playlist-info-title-format "%i%T. %t")
  (require 'emms-volume)
  (require 'emms-volume-mpv)
  (setq emms-volume-change-function 'emms-volume-mpv-change)
  (require 'emms-history)
  (emms-history-load)

  (defvar tsp/emms-library-refresh-timer nil)

  (defun tsp/emms-refresh-library (&optional quiet)
    "Rescan the music directory and refresh the EMMS browser.
When QUIET is non-nil, avoid status messages for automatic refreshes."
    (interactive)
    (let ((library (expand-file-name emms-source-file-default-directory)))
      (if (not (file-directory-p library))
          (unless quiet
            (message "EMMS library is not mounted: %s" library))
        (unless quiet
          (message "Refreshing EMMS library from %s..." library))
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
                     (emms-info-native track)))
                 emms-cache-db)
        (emms-cache-sync t)
        (let (print-length print-level)
          (emms-cache-save))
        (when (buffer-live-p emms-browser-buffer)
          (with-current-buffer emms-browser-buffer
            (emms-browse-by emms-browser-default-browse-type)))
        (unless quiet
          (message "EMMS library refresh complete")))))

  (when (timerp tsp/emms-library-refresh-timer)
    (cancel-timer tsp/emms-library-refresh-timer))
  (setq tsp/emms-library-refresh-timer
        (run-with-idle-timer 60 600 #'tsp/emms-refresh-library t))
  (emms-mode-line-mode 1)
  (emms-playing-time-mode 1))

(provide 'tsp-apps)
;;; tsp-apps.el ends here
