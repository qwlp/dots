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

(use-package org
  :ensure nil
  :bind
  (("C-c a" . org-agenda)
   ("C-c c" . org-capture)
   ("C-c l" . org-store-link))
  :hook
  ((org-mode . tsp/org-mode-setup)
   (org-babel-after-execute . tsp/org-redisplay-inline-images))
  :init
  (setq org-startup-indented nil
        org-hide-leading-stars nil
        org-hide-emphasis-markers nil
        org-startup-folded 'show2levels
        org-cycle-separator-lines 0
        org-fontify-quote-and-verse-blocks nil
        org-fontify-whole-heading-line nil
        org-fontify-done-headline nil
        org-src-fontify-natively nil
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
        org-log-into-drawer t
        org-outline-path-complete-in-steps nil
        org-refile-use-outline-path 'file
        org-refile-use-cache t
        org-ellipsis " ..."
        org-image-actual-width '(800)
        org-export-with-smart-quotes t)
  :config
  (require 'org-tempo)
  (dolist (template '(("el" . "src emacs-lisp")
                      ("py" . "src python")
                      ("sh" . "src shell")))
    (add-to-list 'org-structure-template-alist template))
  (when (boundp 'org-file-apps-gnu)
    (setcdr (assq t org-file-apps-gnu) 'browse-url-xdg-open)))

(use-package verb
  :ensure t
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

(provide 'tsp-org)
;;; tsp-org.el ends here
