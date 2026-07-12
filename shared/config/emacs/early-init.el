;;; early-init.el --- Early startup settings -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from config.org. Edit that file instead.

(defconst tsp/emacs-state-directory
  (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME")
                                 (expand-file-name "~/.local/state/")))
  "Directory for persistent Emacs state.")

(defconst tsp/emacs-cache-directory
  (expand-file-name "emacs/" (or (getenv "XDG_CACHE_HOME")
                                 (expand-file-name "~/.cache/")))
  "Directory for generated Emacs cache files.")

(setq package-user-dir (expand-file-name "elpa/" tsp/emacs-state-directory)
      auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" tsp/emacs-state-directory))

;; Minimize GC and regexp work while the configuration is loading.  Restore
;; normal values from `emacs-startup-hook' so long-running sessions are not
;; affected.
(defvar tsp/startup-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil
      gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "eln-cache/" tsp/emacs-cache-directory)))

(setq package-enable-at-startup nil
      frame-inhibit-implied-resize t)

;;; early-init.el ends here
