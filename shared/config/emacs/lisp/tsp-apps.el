;;; tsp-apps.el --- Applications -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(use-package ghostel
  :ensure t
  :commands ghostel
  :init
  (setq ghostel-module-auto-install 'download)
  (setq-default ghostel-glyph-scale-floor 1.0))

(defun tsp/change-inner-word ()
  "Kill the symbol or word at point, like Vim's `ciw'."
  (interactive)
  (if-let ((bounds (or (bounds-of-thing-at-point 'symbol)
                       (bounds-of-thing-at-point 'word))))
      (kill-region (car bounds) (cdr bounds))
    (user-error "Point is not on a word")))

(defun tsp/unescaped-delimiter-p (position)
  "Return non-nil when the delimiter at POSITION is not escaped."
  (save-excursion
    (goto-char position)
    (let ((backslashes 0))
      (while (eq (char-before) ?\\)
        (setq backslashes (1+ backslashes))
        (backward-char))
      (zerop (% backslashes 2)))))

(defun tsp/inner-quote-bounds ()
  "Return the bounds inside the nearest enclosing quote pair."
  (let ((origin (point))
        (pairs '((?\" . ?\") (?' . ?') (?` . ?`)
                 (?“ . ?”) (?‘ . ?’) (?« . ?»)
                 (?‹ . ?›) (?「 . ?」) (?『 . ?』)))
        best)
    (dolist (pair pairs best)
      (save-excursion
        (goto-char origin)
        (let (opening closing)
          (while (and (not opening)
                      (search-backward (char-to-string (car pair)) nil t))
            (when (tsp/unescaped-delimiter-p (point))
              (setq opening (point))))
          (when opening
            (goto-char origin)
            (while (and (not closing)
                        (search-forward (char-to-string (cdr pair)) nil t))
              (let ((position (1- (point))))
                (when (tsp/unescaped-delimiter-p position)
                  (setq closing position))))
            (when (and closing
                       (or (not best) (> opening (car best))))
              (setq best (cons (1+ opening) closing)))))))))

(defun tsp/change-inner-quotes ()
  "Kill text inside the nearest enclosing quote pair."
  (interactive)
  (if-let ((bounds (tsp/inner-quote-bounds)))
      (kill-region (car bounds) (cdr bounds))
    (user-error "Point is not inside quotes")))

(defun tsp/change-inner-brackets ()
  "Kill text inside the nearest enclosing parentheses or brackets."
  (interactive)
  (let* ((opening (if (memq (char-after) '(?\( ?\[ ?\{))
                      (point)
                    (nth 1 (syntax-ppss))))
         (closing (and opening (scan-sexps opening 1))))
    (if closing
        (kill-region (1+ opening) (1- closing))
      (user-error "Point is not inside brackets"))))

(define-prefix-command 'tsp/change-map)
(keymap-set tsp/change-map "w" #'tsp/change-inner-word)
(keymap-set tsp/change-map "q" #'tsp/change-inner-quotes)
(keymap-set tsp/change-map "b" #'tsp/change-inner-brackets)
(keymap-global-set "M-c" #'tsp/change-map)

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
  (("M-I" . symbol-overlay-put)
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

(defun tsp/dired-find-file-vertical-split ()
  "Open the file at point in a new split to the right."
  (interactive)
  (let ((file (dired-get-file-for-visit)))
    (select-window (split-window-right))
    (find-file file)))

(use-package dired-x
  :ensure nil
  :after dired
  :hook (dired-mode . dired-omit-mode)
  :bind (:map dired-mode-map
              ("|" . tsp/dired-find-file-vertical-split))
  :config
  (setq dired-omit-files (concat dired-omit-files "\\|^\\..+$")))

(use-package magit
  :ensure t
  :bind
  (("C-x g" . magit-status)
   ("C-x M-g" . magit-dispatch))
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

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
                          (recents . 5)
                          (projects . 5)))
  :config
  (setf (alist-get 'agenda dashboard-item-generators)
        #'tsp/dashboard-insert-agenda)
  (setf (alist-get 'projects dashboard-item-generators)
        #'tsp/dashboard-insert-org-projects)
  (dashboard-setup-startup-hook))

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

(add-hook 'emacs-startup-hook #'tsp/dashboard-open-on-startup 99)

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
