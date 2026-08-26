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

;;; init.el ends here
