;;; tsp-org.el --- Org package and task workflow -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(dolist (binding '(("C-c a" . org-agenda)
                   ("C-c A" . tsp/org-open-dashboard)
                   ("C-c d" . tsp/org-open-dashboard)
                   ("C-c c" . org-capture)
                   ("C-c l" . org-store-link)
                   ("C-c o i" . org-clock-in)
                   ("C-c o o" . org-clock-out)
                   ("C-c o g" . org-clock-goto)
                   ("C-c o p" . tsp/org-open-project-directory)))
  (keymap-global-set (car binding) (cdr binding)))

(use-package org
  :ensure nil
  :demand t
  :bind
  (:map org-mode-map
   ("TAB" . tsp/org-tab-dwim)
   ("<tab>" . tsp/org-tab-dwim)
   ("RET" . tsp/org-return-dwim)
   ("<return>" . tsp/org-return-dwim)
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
        ;; Let language modes own source indentation instead of adding Org's
        ;; own offset on top of their configured indentation.
        org-src-content-indentation 0
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
        org-html-head tsp/org-html-style
        org-html-head-include-default-style nil
        org-html-htmlize-output-type 'inline-css
        org-html-validation-link nil
        org-clock-persist 'history
        org-clock-persist-file (tsp/emacs-state-file "org-clock-save.el")
        org-clock-in-resume t
        org-clock-out-remove-zero-time-clocks t
        org-clock-report-include-clocking-task t
        org-habit-show-habits-only-for-today nil)
  :config
  (require 'org-habit)
  (require 'org-clock)
  (add-to-list 'org-src-lang-modes '("go" . go-ts))
  (add-to-list 'org-src-lang-modes '("java" . java-ts))
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t)
     (java . t)))
  (org-clock-persistence-insinuate)
  (add-hook 'org-after-todo-state-change-hook #'tsp/org-clock-out-if-done)
  (add-hook 'org-after-todo-state-change-hook
            #'tsp/org-refile-project-for-state)
  (add-hook 'org-export-filter-link-functions #'tsp/org-html-copy-local-image)
  (add-hook 'org-tab-first-hook #'tsp/org-expand-source-block)
  (when (boundp 'org-file-apps-gnu)
    (setcdr (assq t org-file-apps-gnu) 'browse-url-xdg-open)))

(provide 'tsp-org)
;;; tsp-org.el ends here
