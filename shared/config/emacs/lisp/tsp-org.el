;;; tsp-org.el --- Org configuration -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(defun tsp/org-mode-setup ()
  "Custom setup for Org mode."
  (setq fill-column 80)
  (auto-fill-mode 1)
  (display-fill-column-indicator-mode 1))

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
(defconst tsp/org-calendar-directory (tsp/emacs-state-file "org-gcal/"))
(defconst tsp/org-calendar-file
  (expand-file-name "calendar.org" tsp/org-calendar-directory))
(defconst tsp/org-archive-directory (expand-file-name "archive/" tsp/org-directory))
(defconst tsp/org-roam-directory (expand-file-name "roam/" tsp/org-directory))
(defconst tsp/org-roam-dailies-directory
  (expand-file-name "daily/" tsp/org-roam-directory))

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
  (dolist (directory (list tsp/org-directory tsp/org-calendar-directory
                           tsp/org-archive-directory
                           tsp/org-roam-directory tsp/org-roam-dailies-directory))
    (make-directory directory t))
  (tsp/org-bootstrap-file tsp/org-inbox-file "Inbox")
  (tsp/org-bootstrap-file tsp/org-tasks-file "Tasks"
                          "Actions" "Waiting" "Someday" "Habits")
  (tsp/org-bootstrap-file tsp/org-projects-file "Projects"
                          "Active" "Completed")
  (tsp/org-bootstrap-file tsp/org-calendar-file "Google Calendar"))

(tsp/org-bootstrap)

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
   ("C-c o g" . org-clock-goto))
  :hook
  ((org-mode . tsp/org-mode-setup)
   (org-babel-after-execute . tsp/org-redisplay-inline-images))
  :init
  (setq org-directory tsp/org-directory
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
        org-roam-completion-everywhere t
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

(defconst tsp/org-gcal-config-file
  (expand-file-name
   (or (getenv "ORG_GCAL_CONFIG") "org-gcal/config.el")
   (or (getenv "XDG_CONFIG_HOME") (expand-file-name "~/.config/")))
  "Machine-local configuration file for `org-gcal'.")

(defvar tsp/org-gcal-fetch-timer nil
  "Timer used to refresh Google Calendar events.")

(defun tsp/org-gcal-configured-p ()
  "Return non-nil when machine-local Google Calendar settings exist."
  (file-readable-p tsp/org-gcal-config-file))

(defun tsp/org-gcal-setup (credentials-file calendar-id)
  "Install CREDENTIALS-FILE and configure CALENDAR-ID for `org-gcal'."
  (interactive
   (list (read-file-name "Google OAuth client JSON: " nil nil t nil
                         (lambda (file)
                           (or (file-directory-p file)
                               (string-match-p "\\.json\\'" file))))
         (read-string "Google Calendar email/address: " user-mail-address)))
  (require 'json)
  (let* ((config-directory (file-name-directory tsp/org-gcal-config-file))
         (installed-credentials
          (expand-file-name "credentials.json" config-directory))
         (credentials (json-read-file credentials-file))
         (client (or (alist-get 'installed credentials)
                     (alist-get 'desktop credentials))))
    (unless client
      (user-error "No desktop OAuth client found in %s" credentials-file))
    (unless (and (alist-get 'client_id client)
                 (alist-get 'client_secret client))
      (user-error "OAuth client ID or secret is missing from %s"
                  credentials-file))
    (make-directory config-directory t)
    (copy-file credentials-file installed-credentials t)
    (set-file-modes installed-credentials #o600)
    (with-temp-file tsp/org-gcal-config-file
      (insert ";;; config.el --- Machine-local org-gcal settings -*- lexical-binding: t; -*-\n\n"
              "(require 'json)\n\n"
              "(let* ((credentials-file "
              (prin1-to-string installed-credentials)
              ")\n       (credentials (json-read-file credentials-file))\n"
              "       (client (or (alist-get 'installed credentials)\n"
              "                   (alist-get 'desktop credentials))))\n"
              "  (setq org-gcal-client-id (alist-get 'client_id client)\n"
              "        org-gcal-client-secret (alist-get 'client_secret client)\n"
              "        org-gcal-fetch-file-alist (list (cons "
              (prin1-to-string calendar-id)
              " tsp/org-calendar-file))))\n\n"
              ";;; config.el ends here\n"))
    (set-file-modes tsp/org-gcal-config-file #o600)
    (message "Google Calendar configured; press C-c o C to authorize and sync")))

(defun tsp/org-gcal-fetch (&optional quiet)
  "Fetch Google Calendar events into the local Agenda cache.
When QUIET is non-nil, suppress the missing-configuration error."
  (interactive)
  (if (not (tsp/org-gcal-configured-p))
      (unless quiet
        (user-error "Create %s first" tsp/org-gcal-config-file))
    (load tsp/org-gcal-config-file nil 'nomessage)
    (require 'org-gcal)
    (org-gcal-fetch)
    ;; `org-gcal-fetch' is asynchronous.  Refresh the dashboard after its
    ;; network request has had time to update the agenda file.
    (run-at-time 10 nil #'tsp/dashboard-refresh-if-visible)))

(defun tsp/org-gcal-start-fetch-timer ()
  "Fetch Google Calendar shortly after startup and every 30 minutes."
  (when (and (tsp/org-gcal-configured-p)
             ;; Desktop-launched Emacs does not necessarily inherit the Fish
             ;; environment.  Default to enabled; retain an environment switch
             ;; for machines where automatic fetching is undesirable.
             (not (member (downcase (or (getenv "ORG_GCAL_AUTO_FETCH") "1"))
                          '("0" "false" "no"))))
    (when (timerp tsp/org-gcal-fetch-timer)
      (cancel-timer tsp/org-gcal-fetch-timer))
    (setq tsp/org-gcal-fetch-timer
          (run-at-time 5 (* 30 60) #'tsp/org-gcal-fetch t))))

(use-package org-gcal
  :ensure t
  :commands (org-gcal-fetch tsp/org-gcal-fetch)
  :bind (("C-c o C" . tsp/org-gcal-fetch))
  :init
  (setq org-gcal-dir tsp/org-calendar-directory
        org-gcal-up-days 90
        org-gcal-down-days 365
        org-gcal-recurring-events-mode 'nested
        ;; The upstream auto-archiver aborts the whole sync when any managed
        ;; entry lacks a timestamp it recognizes.  Fetching does not require
        ;; archiving, so leave old-event cleanup to Org instead.
        org-gcal-auto-archive nil)
  (when (tsp/org-gcal-configured-p)
    (load tsp/org-gcal-config-file nil 'nomessage)))

(add-hook 'emacs-startup-hook #'tsp/org-gcal-start-fetch-timer)

(use-package verb
  :ensure t
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

(provide 'tsp-org)
;;; tsp-org.el ends here
