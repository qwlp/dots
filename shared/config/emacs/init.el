;;; init.el --- Personal Emacs config -*- lexical-binding: t; -*-

;;; UI

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(setq inhibit-startup-screen t)
(setq-default truncate-lines t)

;;; Custom

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(when (file-exists-p custom-file)
  (load custom-file))

;;; Files

;; Keep editing safety files out of project directories.
(let ((backup-dir (expand-file-name "backups/" user-emacs-directory))
      (auto-save-dir (expand-file-name "auto-save/" user-emacs-directory)))
  (make-directory backup-dir t)
  (make-directory auto-save-dir t)
  (setq backup-directory-alist `(("." . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,auto-save-dir t))
        create-lockfiles nil))

;;; Editing

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq c-basic-offset 4)

;;; Shell

(setq shell-command-switch "-lc")

;;; Packages

(require 'package)

(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;;; Theme

(use-package naysayer-theme
  :config
  (load-theme 'naysayer t))

;;; Editing Packages

(use-package multiple-cursors
  :bind
  (("C-S-c C-S-c" . mc/edit-lines)
   ("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   ("C-'" . mc/skip-to-next-like-this)
   ("C-;" . mc/skip-to-previous-like-this)))

(use-package symbol-overlay
  :bind
  (("M-i" . symbol-overlay-put)
   ("M-n" . symbol-overlay-switch-forward)
   ("M-p" . symbol-overlay-switch-backward)
   ("<f7>" . symbol-overlay-mode)
   ("<f8>" . symbol-overlay-remove-all)))

(use-package symbol-overlay-mc
  :after symbol-overlay
  :bind
  (("M-a" . symbol-overlay-mc-mark-all)
   ("C-c n" . symbol-overlay-mc-mark-all)))

;;; Dired

(use-package dired-x
  :ensure nil
  :after dired
  :demand t
  :hook (dired-mode . dired-omit-mode)
  :config
  (setq dired-omit-files (concat dired-omit-files "\\|^\\..+$")))

;;; Completion

(use-package ido
  :ensure nil
  :init
  (ido-mode 1)
  (ido-everywhere 1))

(use-package ido-completing-read+
  :after ido
  :config
  (ido-ubiquitous-mode 1))

(use-package smex
  :after ido
  :bind
  (("M-x" . smex)
   ("C-c C-c M-x" . execute-extended-command))
  :init
  (smex-initialize))

;;; Git

(use-package magit
  :bind
  (("C-x g" . magit-status)
   ("C-x M-g" . magit-dispatch))
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;;; Readers

(use-package nov
  :mode ("\\.epub\\'" . nov-mode))

;;; Exec from shell

(use-package exec-path-from-shell
  :ensure t
  :config
  (setq exec-path-from-shell-variables '("PATH" "MANPATH")) 
  (exec-path-from-shell-initialize))

;;; Languages

(use-package go-mode
  :mode "\\.go\\'")
