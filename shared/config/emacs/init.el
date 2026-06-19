
;; make emacs more clean
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)
(setq inhibit-startup-screen t)
(setq-default truncate-lines t)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(when (file-exists-p custom-file)
  (load custom-file))

;; remove backup files that i really dislike
(setq make-backup-files nil)

;; remove tabs, use spaces
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq c-basic-offset 4)

;; zshrc things
(setq shell-command-switch "-lc")

;; init pack repo
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(require 'use-package)

;; naysayer theme cause why not
(unless (package-installed-p 'naysayer-theme)
  (package-install 'naysayer-theme))

(load-theme 'naysayer t)


;; w consolas
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:font "Consolas 15")))))


(use-package multiple-cursors
  :ensure t
  :bind
  (("C-S-c C-S-c" . mc/edit-lines)
   ("C->"         . mc/mark-next-like-this-word)
   ("C-<"         . mc/mark-previous-like-this-word)
   ("C-c n"       . ar/mc-mark-all-symbol-overlays)
   ("C-c C-<"     . mc/mark-all-like-this)
   ("C-'"         . mc/skip-to-next-like-this)      ; Alternative easier-to-bind key
   ("C-;"         . mc/skip-to-previous-like-this))) ; Alternative easier-to-bind key

(use-package symbol-overlay
  :ensure t
  :bind (("M-i" . symbol-overlay-put)
         ("M-n" . symbol-overlay-switch-forward)
         ("M-p" . symbol-overlay-switch-backward)
         ("<f7>" . symbol-overlay-mode)
         ("<f8>" . symbol-overlay-remove-all)))

(use-package symbol-overlay-mc
  :ensure t
  :bind (("M-a" . symbol-overlay-mc-mark-all)))

;; make dired better
(use-package dired-x
  :after dired
  :demand t
  :config
  (setq dired-omit-files (concat dired-omit-files "\\|^\\..+$"))

  :hook (dired-mode . dired-omit-mode))

;; ido
(use-package ido
  :init
  (ido-mode 1)
  (ido-everywhere 1))

(use-package ido-completing-read+
  :ensure t
  :after ido
  :config
  (ido-ubiquitous-mode 1))

(use-package smex
  :ensure t
  :after ido
  :bind (("M-x" . smex)
	 ("C-c C-c M-x" . execute-extended-command))
  :init
  (smex-initialize))

;; the juicer that is magit
(use-package magit
  :ensure t
  :bind (("C-x g" . magit-status)
	 ("C-x M-g" . magit-dispatch))
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

;; epubing
(use-package nov
  :ensure t
  :init
  :mode ("\\.epub\\'" . nov-mode))

;; langs
(use-package go-mode
  :ensure t
  :mode "\\.go\\'")
