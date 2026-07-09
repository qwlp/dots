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

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(add-to-list 'package-pinned-packages '(telega . "melpa"))
(package-initialize)

(unless (package-installed-p 'use-package)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(require 'tsp-core)
(require 'tsp-ui)
(require 'tsp-completion)
(require 'tsp-org)
(require 'tsp-apps)
(require 'tsp-prog)

;;; init.el ends here
