;;; tsp-org.el --- Org configuration -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(defun tsp/org-mode-setup ()
  "Custom setup for Org mode."
  (setq fill-column 80
        ;; Keep hard wrapping, but avoid Org's context-aware parser on every
        ;; fill-triggering space.  Plain `do-auto-fill' is enough for prose.
        normal-auto-fill-function #'do-auto-fill)
  (electric-indent-local-mode -1)
  (auto-fill-mode 1)
  (display-fill-column-indicator-mode 1)
  (add-hook 'post-command-hook
            #'tsp/org--hide-image-preview-after-move nil t))

(defun tsp/org-redisplay-inline-images ()
  "Refresh inline images after evaluating an Org source block."
  (when (derived-mode-p 'org-mode)
    (org-redisplay-inline-images)))

(defconst tsp/org-directory
  (file-name-as-directory
   (expand-file-name (or (getenv "ORG_DIRECTORY") "~/org")))
  "Root directory for Org data.")

(defconst tsp/org-inbox-file (expand-file-name "inbox.org" tsp/org-directory))
(defconst tsp/org-tasks-file (expand-file-name "tasks.org" tsp/org-directory))
(defconst tsp/org-projects-file (expand-file-name "projects.org" tsp/org-directory))
(defconst tsp/org-calendar-file (expand-file-name "calendar.org" tsp/org-directory))
(defconst tsp/org-archive-directory (expand-file-name "archive/" tsp/org-directory))
(defconst tsp/org-assets-directory (expand-file-name "assets/" tsp/org-directory))
(defconst tsp/org-roam-directory (expand-file-name "roam/" tsp/org-directory))
(defconst tsp/org-roam-dailies-directory
  (expand-file-name "daily/" tsp/org-roam-directory))
(defconst tsp/org-roam-note-directories
  (mapcar (lambda (directory)
            (expand-file-name directory tsp/org-roam-directory))
          '("meetings/" "events/" "ideas/" "projects/" "references/"))
  "Directories used by typed Org-roam note captures.")

(defun tsp/org-bootstrap-file (file title &rest headings)
  "Create FILE with TITLE and HEADINGS when it does not exist."
  (unless (file-exists-p file)
    (make-directory (file-name-directory file) t)
    (with-temp-file file
      (insert "#+title: " title "\n\n")
      (dolist (heading headings)
        (insert "* " heading "\n")))))

(defun tsp/org-bootstrap ()
  "Create the directories and core files used by the Org workflow."
  (dolist (directory (append (list tsp/org-directory tsp/org-archive-directory
                                   tsp/org-assets-directory
                                   tsp/org-roam-directory
                                   tsp/org-roam-dailies-directory)
                             tsp/org-roam-note-directories))
    (make-directory directory t))
  (tsp/org-bootstrap-file tsp/org-inbox-file "Inbox")
  (tsp/org-bootstrap-file tsp/org-tasks-file "Tasks"
                          "Actions" "Waiting" "Someday" "Habits")
  (tsp/org-bootstrap-file tsp/org-projects-file "Projects"
                          "Active" "Completed")
  (tsp/org-bootstrap-file tsp/org-calendar-file "Calendar" "Events"))

(tsp/org-bootstrap)

(defvar-local tsp/org-temporary-image-overlays nil
  "Image overlays belonging to the current temporary preview.")

(defvar-local tsp/org-temporary-image-bounds nil
  "Markers bounding the image link currently being previewed.")

(defun tsp/org--clear-temporary-image-preview ()
  "Remove the temporary image preview in the current buffer."
  (mapc (lambda (overlay)
          (when (overlayp overlay)
            (delete-overlay overlay)))
        tsp/org-temporary-image-overlays)
  (setq tsp/org-temporary-image-overlays nil)
  (when tsp/org-temporary-image-bounds
    (mapc (lambda (marker) (set-marker marker nil))
          tsp/org-temporary-image-bounds)
    (setq tsp/org-temporary-image-bounds nil)))

(defun tsp/org--hide-image-preview-after-move ()
  "Hide the temporary preview after point leaves its image link."
  (when tsp/org-temporary-image-bounds
    (let ((begin (marker-position (car tsp/org-temporary-image-bounds)))
          (end (marker-position (cadr tsp/org-temporary-image-bounds))))
      (unless (and begin end (<= begin (point)) (< (point) end))
        (tsp/org--clear-temporary-image-preview)))))

(defun tsp/org-preview-image-at-point ()
  "Temporarily display the Org image link at point.
The preview is removed as soon as point moves outside the link."
  (interactive)
  (let* ((link (org-element-lineage (org-element-context) '(link) t))
         (type (and link (org-element-property :type link)))
         (path (and link (org-element-property :path link))))
    (unless (and link
                 (member type '("file" "attachment"))
                 path
                 (string-match-p (image-file-name-regexp) path))
      (user-error "Point is not on an image link"))
    (tsp/org--clear-temporary-image-preview)
    (let ((begin (org-element-property :begin link))
          (end (org-element-property :end link)))
      (org-display-inline-images t t begin end)
      (setq tsp/org-temporary-image-overlays
            (seq-filter (lambda (overlay)
                          (overlay-get overlay 'org-image-overlay))
                        (overlays-in begin end))
            tsp/org-temporary-image-bounds
            (list (copy-marker begin) (copy-marker end t)))
      (unless tsp/org-temporary-image-overlays
        (setq tsp/org-temporary-image-bounds nil)
        (user-error "Could not display this image")))))

(defun tsp/org-delete-image-at-point ()
  "Trash the pasted image at point and remove its Org link.
For safety, only image files inside `tsp/org-assets-directory' are removed."
  (interactive)
  (let* ((link (org-element-lineage (org-element-context) '(link) t))
         (type (and link (org-element-property :type link)))
         (path (and link (org-element-property :path link)))
         (base (if buffer-file-name
                   (file-name-directory buffer-file-name)
                 tsp/org-directory))
         (file (and (equal type "file") path
                    (expand-file-name (org-link-unescape path) base))))
    (unless (and link file
                 (string-match-p (image-file-name-regexp) file))
      (user-error "Point is not on a local image link"))
    (unless (and (file-exists-p file)
                 (file-in-directory-p (file-truename file)
                                      (file-truename tsp/org-assets-directory)))
      (user-error "Refusing to delete an image outside %s"
                  tsp/org-assets-directory))
    (when (yes-or-no-p (format "Trash %s and remove its Org link? "
                               (file-name-nondirectory file)))
      (let ((begin (org-element-property :begin link))
            (end (- (org-element-property :end link)
                    (or (org-element-property :post-blank link) 0))))
        (tsp/org--clear-temporary-image-preview)
        (move-file-to-trash file)
        (delete-region begin end)
        (message "Moved %s to trash and removed its link"
                 (file-name-nondirectory file))))))

(defun tsp/org--clipboard-image-spec ()
  "Return a clipboard image command and extension, or signal a user error."
  (cond
   ((executable-find "wl-paste")
    (let ((types (with-temp-buffer
                   (when (zerop (call-process "wl-paste" nil t nil "--list-types"))
                     (buffer-string)))))
      (cond
       ((string-match-p "image/png" types)
        '("png" "wl-paste" "--no-newline" "--type" "image/png"))
       ((string-match-p "image/jpeg" types)
        '("jpg" "wl-paste" "--no-newline" "--type" "image/jpeg"))
       ((string-match-p "image/webp" types)
        '("webp" "wl-paste" "--no-newline" "--type" "image/webp"))
       ((string-match-p "image/gif" types)
        '("gif" "wl-paste" "--no-newline" "--type" "image/gif"))
       (t (user-error "The clipboard does not contain an image")))))
   ((executable-find "xclip")
    ;; Xclip returns a non-zero status when the requested image target is absent.
    (let ((target (seq-find
                   (lambda (candidate)
                     (with-temp-buffer
                       (zerop (call-process "xclip" nil t nil "-selection" "clipboard"
                                            "-t" (car candidate) "-o"))))
                   '(("image/png" . "png") ("image/jpeg" . "jpg")
                     ("image/webp" . "webp") ("image/gif" . "gif")))))
      (if target
          (list (cdr target) "xclip" "-selection" "clipboard"
                "-t" (car target) "-o")
        (user-error "The clipboard does not contain an image"))))
   ((executable-find "pngpaste") '("png" "pngpaste"))
   (t (user-error "Install wl-clipboard, xclip, or pngpaste to paste clipboard images"))))

(defun tsp/org-paste-clipboard-image ()
  "Save the clipboard image under `tsp/org-assets-directory' and insert its link."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command is only available in Org buffers"))
  (let* ((spec (tsp/org--clipboard-image-spec))
         (extension (car spec))
         (program (cadr spec))
         (arguments (cddr spec))
         (name (format-time-string "clipboard-%Y%m%d-%H%M%S-%3N"))
         (file (expand-file-name (concat name "." extension)
                                 tsp/org-assets-directory)))
    (make-directory tsp/org-assets-directory t)
    (if (string= program "pngpaste")
        (unless (zerop (call-process program nil nil nil file))
          (user-error "Could not read a PNG image from the clipboard"))
      (let ((coding-system-for-write 'binary))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (unless (zerop (apply #'call-process program nil t nil arguments))
            (user-error "Could not read an image from the clipboard"))
          (write-region (point-min) (point-max) file nil 'silent))))
    (let* ((base (if buffer-file-name
                     (file-name-directory buffer-file-name)
                   tsp/org-directory))
           (link (file-relative-name file base)))
      (insert (format "[[file:%s]]" link))
      (message "Saved clipboard image to %s" file))))

(defvar tsp/org-git-sync-running nil
  "Non-nil while an Org Git synchronization is running.")

(defvar tsp/org-git-sync-process nil
  "Background process used for startup Org synchronization.")

(defvar tsp/org-git-sync-timer nil
  "Idle timer used for periodic Org synchronization.")

(defun tsp/org-save-buffers ()
  "Save modified file buffers belonging to `tsp/org-directory'."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and buffer-file-name
                 (buffer-modified-p)
                 (file-in-directory-p buffer-file-name tsp/org-directory))
        (save-buffer)))))

(defconst tsp/org-webdav-sync-service "org-webdav-sync.service"
  "Systemd user service that synchronizes the Org directory.")

(defun tsp/org-webdav-sync-on-startup ()
  "Queue an Org WebDAV synchronization without delaying startup."
  (when (executable-find "systemctl")
    (start-process "org-webdav-sync-startup" nil
                   "systemctl" "--user" "start" "--no-block"
                   tsp/org-webdav-sync-service)))

(defun tsp/org-webdav-sync-on-shutdown ()
  "Save Org buffers and queue a final WebDAV synchronization."
  (tsp/org-save-buffers)
  (when (executable-find "systemctl")
    (unless (= 0 (call-process "systemctl" nil nil nil
                               "--user" "start" "--no-block"
                               tsp/org-webdav-sync-service))
      (message "Final Org WebDAV sync failed to start"))))

(add-hook 'emacs-startup-hook #'tsp/org-webdav-sync-on-startup)
(add-hook 'kill-emacs-hook #'tsp/org-webdav-sync-on-shutdown)

(defun tsp/org-git-run (&rest arguments)
  "Run Git with ARGUMENTS in `tsp/org-directory'.
Return a cons containing the exit status and command output."
  (with-temp-buffer
    (let ((default-directory tsp/org-directory))
      (cons (apply #'process-file "git" nil t nil arguments)
            (string-trim (buffer-string))))))

(defun tsp/org-git-sync (&optional quiet)
  "Commit, rebase, and push the Org repository.
When QUIET is non-nil, only report failures.  Conflicts and network errors are
left untouched for manual recovery."
  (interactive)
  (when (process-live-p tsp/org-git-sync-process)
    (delete-process tsp/org-git-sync-process)
    (setq tsp/org-git-sync-process nil))
  (unless tsp/org-git-sync-running
    (let ((tsp/org-git-sync-running t))
      (tsp/org-save-buffers)
      (if (not (file-directory-p (expand-file-name ".git" tsp/org-directory)))
          (unless quiet
            (message "Org Git sync skipped: %s is not a repository"
                     tsp/org-directory))
        (let* ((status (tsp/org-git-run "status" "--porcelain"))
               (dirty (not (string-empty-p (cdr status))))
               failure)
          (when (/= (car status) 0)
            (setq failure (cdr status)))
          (when (and dirty (not failure))
            (pcase-let ((`(,add-status . ,add-output)
                         (tsp/org-git-run "add" "--all")))
              (if (/= add-status 0)
                  (setq failure add-output)
                (pcase-let ((`(,commit-status . ,commit-output)
                             (tsp/org-git-run
                              "commit" "-m"
                              (format-time-string "Org sync: %Y-%m-%d %H:%M"))))
                  (when (/= commit-status 0)
                    (setq failure commit-output))))))
          (unless failure
            (pcase-let ((`(,pull-status . ,pull-output)
                         (tsp/org-git-run "pull" "--rebase")))
              (when (/= pull-status 0)
                (setq failure pull-output))))
          (unless failure
            (pcase-let ((`(,push-status . ,push-output)
                         (tsp/org-git-run "push")))
              (when (/= push-status 0)
                (setq failure push-output))))
          (if failure
              (display-warning
               'tsp-org
               (format "Org Git sync failed; files were preserved:\n%s" failure)
               :warning)
            (unless quiet
              (message "Org Git sync complete"))))))))

(defun tsp/org-git-sync-async ()
  "Synchronize the Org repository without blocking Emacs."
  (interactive)
  (tsp/org-save-buffers)
  (if (not (file-directory-p (expand-file-name ".git" tsp/org-directory)))
      (message "Org Git sync skipped: %s is not a repository" tsp/org-directory)
    (unless (process-live-p tsp/org-git-sync-process)
      (let* ((default-directory tsp/org-directory)
             (buffer (get-buffer-create " *Org Git Sync*"))
             (commit-message
              (shell-quote-argument
               (format-time-string "Org sync: %Y-%m-%d %H:%M")))
             (command
              (string-join
               (list "git add --all"
                     (format (concat "if ! git diff --cached --quiet; then "
                                     "git commit -m %s; fi")
                             commit-message)
                     "git pull --rebase"
                     "git push")
               " && ")))
        (with-current-buffer buffer
          (erase-buffer))
        (setq tsp/org-git-sync-process
              (make-process
               :name "org-git-sync"
               :buffer buffer
               :command (list "/bin/bash" "-lc" command)
               :noquery t
               :sentinel
               (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (setq tsp/org-git-sync-process nil)
                   (if (= (process-exit-status process) 0)
                       (kill-buffer (process-buffer process))
                     (display-warning
                      'tsp-org
                      (format
                       "Background Org Git sync failed; see %s"
                       (buffer-name (process-buffer process)))
                      :warning))))))))))

(defun tsp/org-git-sync-on-startup ()
  "Start Org synchronization and schedule later syncs during idle time."
  (tsp/org-git-sync-async)
  (when (timerp tsp/org-git-sync-timer)
    (cancel-timer tsp/org-git-sync-timer))
  (setq tsp/org-git-sync-timer
        (run-with-idle-timer (* 15 60) t #'tsp/org-git-sync-async)))

(defun tsp/org-git-sync-cancel-timer ()
  "Cancel periodic Org synchronization without starting a final sync."
  (when (timerp tsp/org-git-sync-timer)
    (cancel-timer tsp/org-git-sync-timer)
    (setq tsp/org-git-sync-timer nil)))

(defun tsp/org-project-p ()
  "Return non-nil when the current heading is an unfinished project."
  (and (member (org-get-todo-state) '("TODO" "NEXT" "DOING" "WAIT"))
       (member "project" (org-get-tags nil t))))

(defun tsp/org-agenda-skip-non-projects ()
  "Skip the current subtree unless it is an unfinished project."
  (unless (tsp/org-project-p)
    (or (outline-next-heading) (point-max))))

(defun tsp/org-open-dashboard ()
  "Open the main Org agenda dashboard."
  (interactive)
  (org-agenda nil "d"))

(defun tsp/org-clock-out-if-done ()
  "Clock out when the current clocked task enters a done state."
  (when (and (member org-state org-done-keywords)
             (org-clocking-p)
             (equal (marker-buffer org-clock-marker) (current-buffer)))
    (org-clock-out)))

(use-package org
  :ensure nil
  :bind
  (("C-c a" . org-agenda)
   ("C-c A" . tsp/org-open-dashboard)
   ("C-c c" . org-capture)
   ("C-c l" . org-store-link)
   ("C-c o i" . org-clock-in)
   ("C-c o o" . org-clock-out)
   ("C-c o g" . org-clock-goto)
   :map org-mode-map
   ("C-c C-v" . tsp/org-paste-clipboard-image)
   ("C-c C-p" . tsp/org-preview-image-at-point)
   ("C-c C-x i" . tsp/org-delete-image-at-point))
  :hook
  ((org-mode . tsp/org-mode-setup)
   (org-babel-after-execute . tsp/org-redisplay-inline-images))
  :init
  (setq org-directory tsp/org-directory
        org-startup-with-inline-images nil
        org-image-actual-width 600
        org-default-notes-file tsp/org-inbox-file
        org-agenda-files (list tsp/org-inbox-file tsp/org-tasks-file
                               tsp/org-projects-file tsp/org-calendar-file)
        org-archive-location
        (concat tsp/org-archive-directory "%s_archive::datetree/")
        org-attach-id-dir (expand-file-name "attachments/" tsp/org-directory)
        org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n!)" "DOING(g!)" "WAIT(w@/!)" "SOMEDAY(s@)"
                    "|" "DONE(d!)" "CANCELLED(c@)"))
        org-todo-keyword-faces
        '(("NEXT" . success) ("DOING" . warning) ("WAIT" . font-lock-constant-face)
          ("SOMEDAY" . shadow) ("CANCELLED" . shadow))
        org-tag-alist '((:startgroup) ("@home" . ?h) ("@work" . ?w)
                        ("@computer" . ?c) ("@errand" . ?e) (:endgroup)
                        ("project" . ?p) ("idea" . ?i) ("meeting" . ?m))
        org-stuck-projects '("+project/-DONE-CANCELLED" ("NEXT" "DOING") nil "")
        org-enforce-todo-dependencies t
        org-enforce-todo-checkbox-dependencies t
        org-refile-targets `((,tsp/org-tasks-file :maxlevel . 2)
                             (,tsp/org-projects-file :maxlevel . 3)
                             (,tsp/org-inbox-file :maxlevel . 1))
        org-capture-templates
        `(("t" "Inbox task" entry (file ,tsp/org-inbox-file)
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i" :empty-lines 1)
          ("s" "Scheduled task" entry (file ,tsp/org-inbox-file)
           "* TODO %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i" :empty-lines 1)
          ("i" "Idea" entry (file ,tsp/org-inbox-file)
           "* %? :idea:\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i" :empty-lines 1)
          ("l" "Link" entry (file ,tsp/org-inbox-file)
           "* %?\n%a\nCaptured: %U\n%i" :empty-lines 1)
          ("e" "Event" entry (file+headline ,tsp/org-calendar-file "Events")
           "* %^{Event}\n:PROPERTIES:\n:ID: %(org-id-new)\n:LOCATION: %^{Location}\n:CREATED: %U\n:END:\n%^T\n\n%?"
           :empty-lines 1)
          ("m" "Meeting" entry (file+olp+datetree ,tsp/org-projects-file)
           "* %^{Meeting} :meeting:\n%U\n\n** Notes\n%?\n\n** NEXT Follow-ups\n" :clock-in t :clock-resume t)
          ("j" "Journal" entry (file+olp+datetree ,tsp/org-inbox-file)
           "* %U %?\n%i" :tree-type day)
          ("h" "Habit" entry (file+headline ,tsp/org-tasks-file "Habits")
           "* TODO %?\nSCHEDULED: %^t\n:PROPERTIES:\n:STYLE: habit\n:CREATED: %U\n:END:\n" :empty-lines 1)
          ("p" "Project" entry (file+headline ,tsp/org-projects-file "Active")
           "* TODO %^{Outcome} :project:\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n** NEXT %?\n" :empty-lines 1))
        org-agenda-custom-commands
        '(("d" "Dashboard"
           ((agenda "" ((org-agenda-span 1) (org-agenda-start-day nil)
                         (org-agenda-overriding-header "Today")))
            (todo "DOING" ((org-agenda-overriding-header "In progress")))
            (todo "NEXT" ((org-agenda-overriding-header "Next actions")))
            (tags-todo "+DEADLINE<\"<today>\""
                       ((org-agenda-overriding-header "Overdue")))
            (todo "WAIT" ((org-agenda-overriding-header "Waiting")))
            (tags-todo "+project"
                       ((org-agenda-overriding-header "Projects")
                        (org-agenda-skip-function #'tsp/org-agenda-skip-non-projects)))))
          ("w" "Weekly review"
           ((agenda "" ((org-agenda-span 7) (org-agenda-start-on-weekday 1)))
            (stuck "")
            (todo "WAIT") (todo "SOMEDAY")
            (tags-todo "+project")))
          ("p" "Projects" tags-todo "+project/-DONE-CANCELLED"))
        org-startup-indented nil
        org-hide-leading-stars nil
        org-hide-emphasis-markers nil
        org-startup-folded 'show2levels
        org-cycle-separator-lines 0
        org-fontify-quote-and-verse-blocks nil
        org-fontify-whole-heading-line nil
        org-fontify-done-headline nil
        org-src-fontify-natively t
        org-fold-catch-invisible-edits 'smart
        org-insert-heading-respect-content t
        org-M-RET-may-split-line '((default . nil))
        org-special-ctrl-a/e t
        org-special-ctrl-k t
        org-cycle-emulate-tab 'white
        org-src-tab-acts-natively t
        org-use-speed-commands t
        org-return-follows-link t
        org-list-allow-alphabetical t
        org-use-sub-superscripts '{}
        org-log-done 'time
        org-log-reschedule 'time
        org-log-redeadline 'time
        org-log-into-drawer t
        org-outline-path-complete-in-steps nil
        org-refile-use-outline-path 'file
        org-refile-use-cache t
        org-ellipsis " ..."
        org-image-actual-width '(800)
        org-export-with-smart-quotes t
        org-clock-persist 'history
        org-clock-persist-file (tsp/emacs-state-file "org-clock-save.el")
        org-clock-in-resume t
        org-clock-out-remove-zero-time-clocks t
        org-clock-report-include-clocking-task t
        org-habit-show-habits-only-for-today nil)
  :config
  (require 'org-habit)
  (require 'org-clock)
  (org-clock-persistence-insinuate)
  (add-hook 'org-after-todo-state-change-hook #'tsp/org-clock-out-if-done)
  (require 'org-tempo)
  (dolist (template '(("el" . "src emacs-lisp")
                      ("py" . "src python")
                      ("sh" . "src shell")))
    (add-to-list 'org-structure-template-alist template))
  (when (boundp 'org-file-apps-gnu)
    (setcdr (assq t org-file-apps-gnu) 'browse-url-xdg-open)))

(global-set-key (kbd "C-c o d") #'org-roam-dailies-goto-today)
(global-set-key (kbd "C-c o D") #'org-roam-dailies-capture-today)

(defvar tsp/org-related-event-marker nil
  "Marker for the event awaiting a related Org-roam capture.")

(defvar tsp/org-related-note-id nil
  "ID of the Org-roam note awaiting capture.")

(defvar tsp/org-related-note-title nil
  "Title of the Org-roam note awaiting capture.")

(defun tsp/org-roam-related-note-finalize ()
  "Link the captured Org-roam note from its originating calendar event."
  (unwind-protect
      (progn
        (when (and (markerp tsp/org-related-event-marker)
                   (marker-buffer tsp/org-related-event-marker))
          (org-with-point-at tsp/org-related-event-marker
            (org-entry-put
             nil "RELATED_NOTE"
             (org-link-make-string (concat "id:" tsp/org-related-note-id)
                                   tsp/org-related-note-title))
            (save-buffer)))
        (org-roam-capture--finalize-find-file))
    (setq tsp/org-related-event-marker nil
          tsp/org-related-note-id nil
          tsp/org-related-note-title nil)))

(defun tsp/org-roam-note-from-event ()
  "Create or visit a typed Org-roam note related to the event at point."
  (interactive)
  (catch 'tsp/org-roam-note-from-event
  (require 'org-id)
  (require 'org-roam)
  (require 'org-roam-capture)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command must be used from an Org calendar event"))
  (org-back-to-heading t)
  (unless (org-entry-get nil "TIMESTAMP")
    (user-error "The heading at point has no event timestamp"))
  (let ((related (org-entry-get nil "RELATED_NOTE")))
    (when (and related (string-match "\\[\\[id:\\([^]]+\\)\\]" related))
      (if-let* ((node (org-roam-node-from-id (match-string 1 related))))
          (progn
            (org-roam-node-visit node)
            (throw 'tsp/org-roam-note-from-event nil))
        (user-error "The event's related note is missing from Org-roam"))))
  (let* ((event-marker (copy-marker (point)))
         (event-title (org-get-heading t t t t))
         (event-id (org-id-get-create))
         (event-time (org-entry-get nil "TIMESTAMP"))
         (event-date
          (condition-case nil
              (format-time-string "%Y-%m-%d" (org-time-string-to-time event-time))
            (error "")))
         (location (or (org-entry-get nil "LOCATION") ""))
         (types
          '((?m "Meeting" "meeting" "meetings/"
                "* Attendees\n\n- \n\n* Agenda\n\n- \n\n* Notes\n\n* Decisions\n\n* Follow-ups\n\n- [ ] ")
            (?e "Event" "event" "events/"
                "* Expectations\n\n* Observations\n\n* People and references\n\n* Outcome\n\n* Follow-ups\n\n- [ ] ")
            (?i "Idea" "idea" "ideas/"
                "* Motivation\n\n* Idea\n\n* Possible approaches\n\n* Next experiment\n")
            (?n "General" "note" ""
                "* Notes\n\n")
            (?p "Project" "project" "projects/"
                "* Outcome\n\n* Context\n\n* Notes\n\n* Links\n\n")
            (?r "Reference" "reference" "references/"
                "* Summary\n\n* Source\n\n* Notes\n\n")))
         (choice (read-char-choice
                  "Note type: [m]eeting [e]vent [i]dea [n]general [p]roject [r]eference: "
                  (mapcar #'car types)))
         (type (assq choice types))
         (default-title (if (string-empty-p event-date)
                            event-title
                          (format "%s — %s" event-title event-date)))
         (note-title (read-string "Note title: " default-title))
         (note-id (org-id-new))
         (body (concat "* Calendar event\n${event-link}\n"
                       (unless (string-empty-p location)
                         "Location: ${location}\n")
                       "\n" (nth 4 type) "%?"))
         (template
          `((,(char-to-string choice) ,(nth 1 type) plain ,body
             :target
             (file+head ,(concat (nth 3 type) "%<%Y%m%d%H%M%S>-${slug}.org")
                        ,(concat "#+title: ${title}\n#+filetags: :"
                                 (nth 2 type) ":\n"))
             :unnarrowed t))))
    (save-buffer)
    (setq tsp/org-related-event-marker event-marker
          tsp/org-related-note-id note-id
          tsp/org-related-note-title note-title)
    (org-roam-capture-
     :node (org-roam-node-create :id note-id :title note-title)
     :info (list :event-link
                 (org-link-make-string (concat "id:" event-id) event-title)
                 :location location)
     :templates template
     :props '(:finalize tsp/org-roam-related-note-finalize)))))

(global-set-key (kbd "C-c o N") #'tsp/org-roam-note-from-event)

(use-package org-roam
  :ensure t
  :after org
  :commands (org-roam-buffer-toggle org-roam-node-find org-roam-node-insert
             org-roam-dailies-goto-today org-roam-dailies-capture-today)
  :bind (("C-c o f" . org-roam-node-find)
         ("C-c o n" . org-roam-node-insert)
         ("C-c o b" . org-roam-buffer-toggle))
  :init
  (setq org-roam-directory tsp/org-roam-directory
        org-roam-db-location (tsp/emacs-state-file "org-roam.db")
        org-roam-dailies-directory "daily/"
        org-roam-completion-everywhere nil
        org-roam-capture-templates
        '(("n" "Note" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+date: %U\n")
           :unnarrowed t)
          ("p" "Person" plain "* Notes\n%?"
           :target (file+head "people/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+filetags: :person:\n")
           :unnarrowed t)
          ("r" "Reference" plain "* Summary\n%?\n\n* Source\n%^{Source}"
           :target (file+head "references/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+filetags: :reference:\n")
           :unnarrowed t)
          ("P" "Project note" plain "* Outcome\n%?\n\n* Notes\n\n* Links\n"
           :target (file+head "projects/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+filetags: :project:\n")
           :unnarrowed t))
        org-roam-dailies-capture-templates
        '(("d" "Daily dashboard" entry "* %<%H:%M> %?"
           :target
           (file+head "%<%Y-%m-%d>.org"
                      "#+title: %<%A, %Y-%m-%d>\n\n* Morning plan\n- [ ] Review the agenda\n- [ ] Choose three outcomes\n  1. \n  2. \n  3. \n\n* Log\n\n* Meetings\n\n* End-of-day review\n- [ ] Process the inbox\n- [ ] Update or reschedule open tasks\n- [ ] Link durable notes\n- [ ] Record wins and lessons\n"))))
  :config
  (org-roam-db-autosync-mode 1))

(use-package verb
  :ensure t
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

(provide 'tsp-org)
;;; tsp-org.el ends here
