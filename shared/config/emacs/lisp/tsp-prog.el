;;; tsp-prog.el --- Programming modes -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(require 'treesit nil t)

(defvar treesit-language-source-alist nil)
(defvar treesit-extra-load-path nil)

(defconst tsp/treesit-language-sources
  '((go "https://github.com/tree-sitter/tree-sitter-go")
    (gomod "https://github.com/camdencheek/tree-sitter-go-mod")
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

(defun tsp/go-use-four-space-indentation ()
  "Indent Go buffers with four spaces instead of Go mode's tabs."
  (setq-local indent-tabs-mode nil
              tab-width 4
              go-ts-mode-indent-offset 4))

(use-package go-ts-mode
  :ensure nil
  :mode
  (("\\.go\\'" . go-ts-mode)
   ("/go\\.mod\\'" . go-mod-ts-mode))
  :hook
  ((go-ts-mode go-mod-ts-mode) . tsp/go-use-four-space-indentation))

(use-package typst-ts-mode
  :ensure t
  :mode ("\\.typ\\'" . typst-ts-mode))

(use-package odin-mode
  :ensure t
  :vc (:url "https://github.com/mattt-b/odin-mode")
  :mode "\\.odin\\'")

(provide 'tsp-prog)
;;; tsp-prog.el ends here
