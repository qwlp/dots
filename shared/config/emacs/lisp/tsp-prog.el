;;; tsp-prog.el --- Programming modes -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(require 'treesit nil t)
(require 'ansi-color)

(defvar treesit-language-source-alist nil)
(defvar treesit-extra-load-path nil)

;; Save modified buffers automatically before compiling instead of prompting.
(setq compilation-ask-about-save nil)

;; Compilation commands often emit terminal color escapes.  Interpret them
;; before font-lock sees the output instead of displaying them as ^[[...m.
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

(defun tsp/compile-and-focus ()
  "Run `compile' and select its compilation buffer."
  (interactive)
  (pop-to-buffer (call-interactively #'compile)))

(defun tsp/recompile-and-focus ()
  "Run `recompile' and select its compilation buffer."
  (interactive)
  (pop-to-buffer (call-interactively #'recompile)))

(keymap-global-set "C-c b c" #'tsp/compile-and-focus)
(keymap-global-set "C-c b r" #'tsp/recompile-and-focus)

(defconst tsp/treesit-language-sources
  '((c "https://github.com/tree-sitter/tree-sitter-c")
    (cpp "https://github.com/tree-sitter/tree-sitter-cpp")
    (go "https://github.com/tree-sitter/tree-sitter-go")
    (gomod "https://github.com/camdencheek/tree-sitter-go-mod")
    (jai "https://github.com/constantitus/tree-sitter-jai")
    (typst "https://github.com/uben0/tree-sitter-typst"))
  "Tree-sitter grammars managed by this config.")

(dolist (source tsp/treesit-language-sources)
  (add-to-list 'treesit-language-source-alist source))

(defconst tsp/treesit-grammar-directory
  (tsp/emacs-cache-file "tree-sitter/")
  "Directory for compiled Tree-sitter grammars.")

(add-to-list 'treesit-extra-load-path tsp/treesit-grammar-directory)

(defun tsp/treesit-install-missing-grammars ()
  "Install configured Tree-sitter grammars that are not yet available."
  (interactive)
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p))
    (dolist (source tsp/treesit-language-sources)
      (let ((language (car source)))
        (unless (treesit-language-available-p language)
          (condition-case error-data
              (progn
                (message "Installing Tree-sitter grammar for %s..." language)
                (treesit-install-language-grammar
                 language tsp/treesit-grammar-directory))
            (error
             (message "Could not install Tree-sitter grammar for %s: %s"
                      language (error-message-string error-data)))))))))

(defun tsp/treesit-grand-parent-bol (_node parent &rest _)
  "Return the first non-whitespace position on PARENT's parent line."
  (save-excursion
    (goto-char (treesit-node-start (treesit-node-parent parent)))
    (back-to-indentation)
    (point)))

(defun tsp/go-setup-buffer ()
  "Configure canonical indentation and formatting for a Go buffer."
  (setq-local indent-tabs-mode t
              tab-width 4
              go-ts-mode-indent-offset 4
              tab-always-indent t)
  ;; Emacs 30's Go rules omit nodes directly inside a statement_list, so a
  ;; statement starting in column zero cannot be indented with Tab.
  (setq-local treesit-simple-indent-rules
              (copy-tree treesit-simple-indent-rules))
  (push '((parent-is "statement_list")
          tsp/treesit-grand-parent-bol
          go-ts-mode-indent-offset)
        (alist-get 'go treesit-simple-indent-rules))
  ;; Bind both terminal and graphical Tab events buffer-locally.  This also
  ;; keeps completion keymaps from turning Tab into a completion-only command.
  (local-set-key (kbd "TAB") #'indent-for-tab-command)
  (local-set-key (kbd "<tab>") #'indent-for-tab-command)
  (add-hook 'before-save-hook #'tsp/gofmt-buffer nil t))

(defun tsp/gofmt-buffer ()
  "Format the current buffer using the gofmt executable."
  (let ((formatted (generate-new-buffer " *gofmt output*"))
        (errors (make-temp-file "gofmt-errors-")))
    (unwind-protect
        (let ((status (call-process-region
                       (point-min) (point-max) "gofmt" nil
                       (list formatted errors) nil)))
          (if (zerop status)
              (replace-buffer-contents formatted)
            (user-error "gofmt failed: %s"
                        (with-temp-buffer
                          (insert-file-contents errors)
                          (string-trim (buffer-string))))))
      (kill-buffer formatted)
      (delete-file errors))))

;; Font-lock plus stipples keeps indentation guides cheap: no overlays,
;; tree-sitter queries, current-scope tracking, or work on blank lines.
(use-package indent-bars
  :commands indent-bars-mode
  :custom
  (indent-bars-prefer-character t)
  (indent-bars-no-stipple-char ?│)
  (indent-bars-color '(default :blend 0.28))
  (indent-bars-color-by-depth nil)
  (indent-bars-display-on-blank-lines nil)
  (indent-bars-highlight-current-depth nil)
  (indent-bars-treesit-support nil))

(defun tsp/enable-indent-bars-after-major-mode ()
  "Enable indentation bars after a programming mode finishes initializing."
  (when (derived-mode-p 'prog-mode)
    (indent-bars-mode 1)))

(add-hook 'after-change-major-mode-hook
          #'tsp/enable-indent-bars-after-major-mode)

(use-package c-ts-mode
  :ensure nil
  :mode ("\\.c\\'" . c-ts-mode))

(add-to-list 'major-mode-remap-alist '(c-mode . c-ts-mode))

(use-package go-ts-mode
  :ensure nil
  :mode
  (("\\.go\\'" . go-ts-mode)
   ("/go\\.mod\\'" . go-mod-ts-mode))
  :hook
  (go-ts-mode . tsp/go-setup-buffer))

(use-package typst-ts-mode
  :ensure t
  :mode ("\\.typ\\'" . typst-ts-mode))

(use-package odin-mode
  :ensure t
  :vc (:url "https://github.com/mattt-b/odin-mode")
  :mode "\\.odin\\'")

(use-package jai-ts-mode
  :vc (:url "https://github.com/cpoile/jai-ts-mode")
  :mode "\\.jai\\'")

(provide 'tsp-prog)
;;; tsp-prog.el ends here
