;;; init.el --- Personal Emacs config -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from config.org. Edit that file instead.

(add-to-list 'load-path (expand-file-name "lisp/" user-emacs-directory))

(defconst tsp/emacs-state-directory
  (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME")
                                 (expand-file-name "~/.local/state/")))
  "Directory for persistent Emacs state.")

(setq package-user-dir (expand-file-name "elpa/" tsp/emacs-state-directory))

(require 'package)
(require 'treesit)

(defconst tsp/treesit-grammar-directory
  (expand-file-name
   "tree-sitter/"
   (if (boundp 'tsp/emacs-cache-directory)
       tsp/emacs-cache-directory
     (expand-file-name "emacs/" (or (getenv "XDG_CACHE_HOME")
                                     (expand-file-name "~/.cache/")))))
  "Directory for compiled Tree-sitter grammars.")
(add-to-list 'treesit-extra-load-path tsp/treesit-grammar-directory)

;; Optional integrations in third-party packages are guarded with `fboundp',
;; but the native compiler cannot prove that they will exist at run time.
(setq byte-compile-warnings '(not unresolved))

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(load "tsp-core")
(load "tsp-ui")
(load "tsp-completion")
(load "tsp-org-core")
(load "tsp-org-export")
(load "tsp-org")
(load "tsp-org-roam")
(load "tsp-apps")
(load "tsp-prog")

;; The desktop follows Omarchy; the laptop follows its Quickshell theme state.
;; Detect the integration rather than a hostname so this config remains
;; portable after reinstalls or machine renames.
(defconst tsp/omarchy-available-p
  (file-readable-p "/usr/share/omarchy-emacs/config/omarchy.el"))

(add-to-list 'custom-theme-load-path
             (expand-file-name "themes/" user-emacs-directory))

(if tsp/omarchy-available-p
    (progn
      (load (expand-file-name "omarchy" user-emacs-directory))

      ;; Naysayer has a deliberately sparse Emacs-specific mapping, so prefer
      ;; its native theme whenever Omarchy selects the matching desktop theme.
      (defun tsp/apply-naysayer-theme-for-omarchy (&rest _)
        "Use the native Naysayer Emacs theme when Omarchy selects Naysayer."
        (when (and (file-readable-p omarchy-theme-name-file)
                   (string= (string-trim
                             (with-temp-buffer
                               (insert-file-contents omarchy-theme-name-file)
                               (buffer-string)))
                            "naysayer"))
          (mapc #'disable-theme custom-enabled-themes)
          (load-theme 'naysayer t)))

      (advice-add 'omarchy-apply-theme :after
                  #'tsp/apply-naysayer-theme-for-omarchy)
      (tsp/apply-naysayer-theme-for-omarchy))
  (let* ((state-file (expand-file-name "~/.local/state/tsp-theme/name"))
         (laptop-theme
          (when (file-readable-p state-file)
            (intern (string-trim
                     (with-temp-buffer
                       (insert-file-contents state-file)
                       (buffer-string)))))))
    (load-theme (if (memq laptop-theme
                          '(naysayer aamis gruber-tsoding ginger-bill))
                    laptop-theme
                  'naysayer)
                t)))

;; Keep each machine's preferred font across newly created frames.
(defconst tsp/default-font
  (if tsp/omarchy-available-p
      "LythMono Nerd Font 12"
    "IosevkaTerm Nerd Font 13"))

(defun tsp/apply-default-font (&optional frame)
  "Apply `tsp/default-font' to FRAME, or to every graphical frame."
  (if frame
      (when (display-graphic-p frame)
        (set-frame-font tsp/default-font nil (list frame)))
    (set-face-attribute 'default nil :font tsp/default-font)
    (dolist (live-frame (frame-list))
      (when (display-graphic-p live-frame)
        (set-frame-font tsp/default-font nil (list live-frame)))))
  (setf (alist-get 'font default-frame-alist) tsp/default-font))

(when tsp/omarchy-available-p
  (advice-add 'omarchy-apply-font :after
              (lambda (&rest _) (tsp/apply-default-font))))
(add-hook 'after-make-frame-functions #'tsp/apply-default-font)
(tsp/apply-default-font)

;;; init.el ends here
