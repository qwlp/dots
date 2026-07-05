;;; init.el --- Personal Emacs config -*- lexical-binding: t; -*-

;;; Performance

(setq gc-cons-threshold (* 64 1024 1024)
     read-process-output-max (* 1024 1024)
      process-adaptive-read-buffering nil
      bidi-inhibit-bpa t
      inhibit-compacting-font-caches t
      redisplay-skip-fontification-on-input t
      fast-but-imprecise-scrolling t)

(setq-default bidi-display-reordering t
              bidi-paragraph-direction nil
              cursor-in-non-selected-windows nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024))))

;;; UI

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(setq inhibit-startup-screen t)
(setq-default truncate-lines t)
(setq next-line-add-newlines t)

;; Show a 24-hour clock in the mode line.
(setq display-time-format "%H:%M"
      display-time-default-load-average nil
      display-time-interval 60)
(display-time-mode 1)

;;; Custom

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(when (file-exists-p custom-file)
  (load custom-file))

(defconst my/script-fonts
  '((khmer . "Noto Sans Khmer")
    (thai . "Noto Sans Thai")
    (lao . "Noto Sans Lao")
    (burmese . "Noto Sans Myanmar")
    (arabic . "Noto Sans Arabic")
    (devanagari . "Noto Sans Devanagari")
    (bengali . "Noto Sans Bengali")
    (han . "Noto Sans CJK SC")
    (hangul . "Noto Sans CJK KR"))
  "Preferred fonts for scripts not covered by the default coding font.")

;; Noto Sans Khmer has substantially taller metrics than the default Fira
;; Code face.  Scale it to fit compact single-line interfaces such as Telega
;; without changing the size of Latin text or adding gaps between images.
(add-to-list 'face-font-rescale-alist '("Noto Sans Khmer" . 0.85))

(defun my/configure-script-fonts (&optional frame)
  "Configure multilingual fallback fonts on FRAME."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (dolist (entry my/script-fonts)
        (let ((font (font-spec :family (cdr entry))))
          (when (find-font font)
            (set-fontset-font t (car entry) font nil 'prepend)))))))

(my/configure-script-fonts)
(add-hook 'after-make-frame-functions #'my/configure-script-fonts)

(defun my/reload-config ()
  "Reload the Emacs init file."
  (interactive)
  (load-file (or user-init-file
                 (expand-file-name "init.el" user-emacs-directory))))

(keymap-global-set "C-c r" #'my/reload-config)

;;; Packages

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
(setq-default c-basic-offset 4)

(global-so-long-mode 1)


;;; Org mode

;; Expensive visual features are enabled only for reasonably sized files.
;; Large outlines retain the cheap redisplay settings below.
(defconst my/org-visual-buffer-limit (* 512 1024))

(defun my/org-enable-visuals ()
  "Enable the pleasant but more expensive parts of Org in small buffers."
  (when (< (buffer-size) my/org-visual-buffer-limit)
    (setq-local org-hide-emphasis-markers t
                org-fontify-quote-and-verse-blocks t
                org-fontify-whole-heading-line t
                org-fontify-done-headline t
                org-src-fontify-natively t)
    (visual-line-mode 1)
    (org-superstar-mode 1)))

(defun my/org-redisplay-inline-images ()
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
  ((org-mode . my/org-enable-visuals)
   (org-babel-after-execute . my/org-redisplay-inline-images))
  :init
  ;; Keep large Org buffers cheap to redisplay.
  (setq org-startup-indented nil
        org-hide-leading-stars nil
        org-hide-emphasis-markers nil
        org-startup-folded 'show2levels
        org-cycle-separator-lines 0
        org-fontify-quote-and-verse-blocks nil
        org-fontify-whole-heading-line nil
        org-fontify-done-headline nil
        org-src-fontify-natively nil

        ;; Editing should follow the outline's structure and avoid accidental
        ;; edits in folded text.
        org-fold-catch-invisible-edits 'smart
        org-insert-heading-respect-content t
        org-M-RET-may-split-line '((default . nil))
        org-special-ctrl-a/e t
        org-special-ctrl-k t
        org-cycle-emulate-tab 'white
        org-src-tab-acts-natively t

        ;; Make common interactions require less ceremony.
        org-use-speed-commands t
        org-return-follows-link t
        org-list-allow-alphabetical t
        org-use-sub-superscripts '{}
        org-log-done 'time
        org-log-into-drawer t
        org-outline-path-complete-in-steps nil
        org-refile-use-outline-path 'file
        org-refile-use-cache t

        ;; Keep documents and exports readable by default.
        org-ellipsis " …"
        org-image-actual-width '(800)
        org-export-with-smart-quotes t)
  :config
  ;; Restore convenient "<s TAB" structure templates and add common source
  ;; block shortcuts.
  (require 'org-tempo)
  (dolist (template '(("el" . "src emacs-lisp")
                      ("py" . "src python")
                      ("sh" . "src shell")))
    (add-to-list 'org-structure-template-alist template)))

(use-package org-superstar
  :ensure t
  :after org
  :commands org-superstar-mode
  :config
  (setq org-superstar-headline-bullets-list '("◉" "○" "✸" "✿" "♦")
        org-superstar-special-todo-items t))

(use-package verb
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

;;; Shell

(setq shell-command-switch "-lc")

(use-package ghostel
  :commands ghostel
  :init
  ;; Use Ghostel's published native module instead of requiring Zig locally.
  (setq ghostel-module-auto-install 'download)
  ;; Preserve the natural size of taller multilingual fallback fonts.
  (setq-default ghostel-glyph-scale-floor 1.0))

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

;;; Media

(use-package ytr
  :vc (:url "https://github.com/xenodium/ytr"
       :rev :newest)
  :commands ytr
  :init (setq ytr-use-child-frame nil))

;;; Telegram

(defun my/telega-khmer-string-p (string)
  "Return non-nil when STRING contains Khmer characters."
  (string-match-p "[ក-៿]" string))

(defun my/telega-rendered-string-width (string &optional from to)
  "Measure STRING using its rendered glyph width when it contains Khmer."
  (if (and (display-graphic-p)
           (my/telega-khmer-string-p
            (if (or from to) (substring string from to) string)))
      (telega-window-string-width string from to)
    (string-width string from to)))

(defun my/telega-glyph-boundaries (string)
  "Return a vector of grapheme boundaries in STRING."
  (let ((position 0)
        (boundaries (list 0)))
    (dolist (glyph (string-glyph-split string))
      (setq position (+ position (length glyph)))
      (push position boundaries))
    (vconcat (nreverse boundaries))))

(defun my/telega-fit-prefix-end (string boundaries max-width limit)
  "Return the longest grapheme-safe prefix of STRING within MAX-WIDTH.
Do not return a position beyond LIMIT."
  (let ((low 0)
        (high (1- (length boundaries)))
        (best 0))
    (while (<= low high)
      (let* ((middle (/ (+ low high) 2))
             (end (aref boundaries middle)))
        (if (or (> end limit)
                (> (my/telega-rendered-string-width string 0 end) max-width))
            (setq high (1- middle))
          (setq best end
                low (1+ middle)))))
    best))

(defun my/telega-fit-suffix-start (string boundaries max-width)
  "Return the earliest grapheme-safe suffix fitting within MAX-WIDTH."
  (let ((low 0)
        (high (1- (length boundaries)))
        (best (length string)))
    (while (<= low high)
      (let* ((middle (/ (+ low high) 2))
             (start (aref boundaries middle)))
        (if (<= (my/telega-rendered-string-width string start) max-width)
            (setq best start
                  high (1- middle))
          (setq low (1+ middle)))))
    best))

(defun my/telega-khmer-aware-eliding (original string properties)
  "Elide Khmer STRING by rendered grapheme width.
Call ORIGINAL for strings that do not contain Khmer."
  (if (not (my/telega-khmer-string-p string))
      (funcall original string properties)
    (let ((max-width (plist-get properties :max)))
      (if (or (not max-width)
              (<= (my/telega-rendered-string-width string) max-width))
          string
        (let* ((elide-string (or (plist-get properties :elide-string)
                                 telega-symbol-eliding))
               (elide-width (my/telega-rendered-string-width elide-string))
               (elide-position (or (plist-get properties :elide-position) 1))
               (available-width (max 0 (- max-width elide-width)))
               (trail-width (floor (* available-width
                                      (- 1 elide-position))))
               (boundaries (my/telega-glyph-boundaries string))
               (trail-start
                (my/telega-fit-suffix-start string boundaries trail-width))
               (actual-trail-width
                (my/telega-rendered-string-width string trail-start))
               (lead-width (max 0 (- available-width actual-trail-width)))
               (lead-end
                (my/telega-fit-prefix-end
                 string boundaries lead-width trail-start)))
          (when (< lead-end trail-start)
            (add-text-properties
             lead-end trail-start
             (list 'display elide-string
                   'rear-nonsticky '(display)
                   'face (plist-get properties :face))
             string))
          string)))))

(use-package telega
  :commands telega
  :init
  (setq telega-server-libs-prefix
        (expand-file-name "~/.local")
        telega-use-images t
        telega-emoji-use-images nil
        telega-symbol-width 1)
  :config
  (unless (advice-member-p #'my/telega-khmer-aware-eliding
                           'telega-fmt-eval-eliding)
    (advice-add 'telega-fmt-eval-eliding
                :around #'my/telega-khmer-aware-eliding)))
(telega-notifications-mode 1)

;;; Exec from shell

(use-package exec-path-from-shell
  :ensure t
  :config
  (setq exec-path-from-shell-variables '("PATH" "MANPATH")) 
  (exec-path-from-shell-initialize))

;;; Languages

;; Native Tree-sitter grammars are compiled once on the first startup.
(defconst my/treesit-language-sources
  '((go "https://github.com/tree-sitter/tree-sitter-go")
    (gomod "https://github.com/camdencheek/tree-sitter-go-mod")
    (typst "https://github.com/uben0/tree-sitter-typst")))

(dolist (source my/treesit-language-sources)
  (add-to-list 'treesit-language-source-alist source))

(defun my/treesit-install-missing-grammars ()
  "Install configured Tree-sitter grammars that are not yet available."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p))
    (dolist (source my/treesit-language-sources)
      (let ((language (car source)))
        (unless (treesit-language-available-p language)
          (condition-case error-data
              (progn
                (message "Installing Tree-sitter grammar for %s..." language)
                (treesit-install-language-grammar language))
            (error
             (message "Could not install Tree-sitter grammar for %s: %s"
                      language (error-message-string error-data)))))))))

(add-hook 'emacs-startup-hook #'my/treesit-install-missing-grammars)

(use-package go-ts-mode
  :ensure nil
  :mode
  (("\\.go\\'" . go-ts-mode)
   ("/go\\.mod\\'" . go-mod-ts-mode))
  :hook
  ((go-ts-mode go-mod-ts-mode) . my/go-use-four-space-indentation)
  :init
  (defun my/go-use-four-space-indentation ()
    "Indent Go buffers with four spaces instead of Go mode's tabs."
    (setq-local indent-tabs-mode nil
                tab-width 4
                go-ts-mode-indent-offset 4)))

(use-package typst-ts-mode
  :mode ("\\.typ\\'" . typst-ts-mode))

(use-package odin-mode
  :vc (:url "https://github.com/mattt-b/odin-mode")
  :mode "\\.odin\\'")
