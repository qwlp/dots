;;; tsp-core.el --- Core defaults -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(unless (boundp 'tsp/emacs-state-directory)
  (defconst tsp/emacs-state-directory
    (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME")
                                   (expand-file-name "~/.local/state/")))
    "Directory for persistent Emacs state."))

(unless (boundp 'tsp/emacs-cache-directory)
  (defconst tsp/emacs-cache-directory
    (expand-file-name "emacs/" (or (getenv "XDG_CACHE_HOME")
                                   (expand-file-name "~/.cache/")))
    "Directory for generated Emacs cache files."))

(defun tsp/emacs-state-file (file)
  "Return FILE under `tsp/emacs-state-directory'."
  (expand-file-name file tsp/emacs-state-directory))

(defun tsp/emacs-cache-file (file)
  "Return FILE under `tsp/emacs-cache-directory'."
  (expand-file-name file tsp/emacs-cache-directory))

(dolist (directory (list tsp/emacs-state-directory
                         tsp/emacs-cache-directory
                         (tsp/emacs-state-file "auto-save-list/")
                         (tsp/emacs-state-file "emms/")
                         (tsp/emacs-state-file "eshell/")
                         (tsp/emacs-state-file "multisession/")
                         (tsp/emacs-state-file "transient/")
                         (tsp/emacs-state-file "url/")
                         (tsp/emacs-cache-file "backups/")
                         (tsp/emacs-cache-file "auto-save/")
                         (tsp/emacs-cache-file "tree-sitter/")))
  (make-directory directory t))

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache (tsp/emacs-cache-file "eln-cache/")))

(setq package-user-dir (tsp/emacs-state-file "elpa/")
      auto-save-list-file-prefix (tsp/emacs-state-file "auto-save-list/.saves-")
      project-list-file (tsp/emacs-state-file "projects")
      tramp-persistency-file-name (tsp/emacs-state-file "tramp")
      transient-levels-file (tsp/emacs-state-file "transient/levels.el")
      transient-values-file (tsp/emacs-state-file "transient/values.el")
      transient-history-file (tsp/emacs-state-file "transient/history.el")
      eshell-directory-name (tsp/emacs-state-file "eshell/")
      url-cookie-file (tsp/emacs-state-file "url/cookies")
      save-place-file (tsp/emacs-state-file "places")
      recentf-save-file (tsp/emacs-state-file "recentf")
      savehist-file (tsp/emacs-state-file "history")
      smex-save-file (tsp/emacs-state-file "smex-items")
      mc/list-file (tsp/emacs-state-file ".mc-lists.el")
      multisession-directory (tsp/emacs-state-file "multisession/"))

(setq gc-cons-threshold (* 64 1024 1024)
      read-process-output-max (* 1024 1024)
      process-adaptive-read-buffering nil
      bidi-inhibit-bpa t
      inhibit-compacting-font-caches t
      redisplay-skip-fontification-on-input t
      fast-but-imprecise-scrolling t)

(setq-default bidi-display-reordering t
              bidi-paragraph-direction nil
              cursor-in-non-selected-windows nil
              indent-tabs-mode nil
              tab-width 4)

(setq-default c-basic-offset 4)

(defun tsp/scroll-up-and-center ()
  "Scroll forward and center point in the window."
  (interactive)
  (call-interactively #'scroll-up-command)
  (recenter))

(defun tsp/scroll-down-and-center ()
  "Scroll backward and center point in the window."
  (interactive)
  (call-interactively #'scroll-down-command)
  (recenter))

(keymap-global-set "C-v" #'tsp/scroll-up-and-center)
(keymap-global-set "M-v" #'tsp/scroll-down-and-center)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024))
            (message "Emacs loaded in %s with %d garbage collections."
                     (emacs-init-time)
                     gcs-done)))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(when (file-exists-p custom-file)
  (load custom-file))

(setq backup-directory-alist `(("." . ,(tsp/emacs-cache-file "backups/")))
      auto-save-file-name-transforms
      `((".*" ,(tsp/emacs-cache-file "auto-save/") t))
      create-lockfiles nil)

(setq shell-command-switch "-lc"
      next-line-add-newlines t)

(global-so-long-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)

(defun tsp/config-file (file)
  "Return FILE under `user-emacs-directory'."
  (expand-file-name file user-emacs-directory))

(defun tsp/tangle-config ()
  "Tangle the literate Emacs configuration."
  (interactive)
  (let ((config (tsp/config-file "config.org")))
    (when-let ((buffer (find-buffer-visiting config)))
      (with-current-buffer buffer
        (when (buffer-modified-p)
          (save-buffer))))
    (require 'org)
    (org-babel-tangle-file config)))

(defun tsp/reload-config ()
  "Tangle and reload the Emacs config.

This reloads the generated init file with `load' instead of relying on
`require', so already-loaded local modules are evaluated again in daemon
sessions."
  (interactive)
  (let ((init-file (or user-init-file (tsp/config-file "init.el"))))
    (tsp/tangle-config)
    (load init-file nil nil t)
    (force-mode-line-update t)
    (message "Reloaded Emacs config from %s" init-file)))

(keymap-global-set "C-c r" #'tsp/reload-config)

;; Emoji insertion: search by name for the common case, with the visual
;; browser and recently used emojis available on the same prefix.
(keymap-global-set "C-c i e" #'emoji-search)
(keymap-global-set "C-c i E" #'emoji-list)
(keymap-global-set "C-c i r" #'emoji-recent)

(provide 'tsp-core)
;;; tsp-core.el ends here
