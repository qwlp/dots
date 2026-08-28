;;; tsp-prog.el --- Programming modes -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(require 'treesit)
(require 'ansi-color)

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
    (java "https://github.com/tree-sitter/tree-sitter-java")
    (markdown "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
              :source-dir "tree-sitter-markdown/src")
    (markdown-inline "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
                     :source-dir "tree-sitter-markdown-inline/src")
    (typst "https://github.com/uben0/tree-sitter-typst"))
  "Tree-sitter grammars managed by this config.")

(dolist (source tsp/treesit-language-sources)
  (add-to-list 'treesit-language-source-alist source))

(setq treesit-auto-install-grammar 'always)
(customize-set-variable
 'treesit-enabled-modes
 '(c-ts-mode c++-ts-mode go-ts-mode go-mod-ts-mode java-ts-mode
   markdown-ts-mode))

(defun tsp/markdown-in-unfillable-block-p ()
  "Return non-nil when point is in Markdown code or a pipe table."
  (let ((node (treesit-node-at (max (point-min) (1- (point))) 'markdown))
        found)
    (while (and node (not found))
      (when (member (treesit-node-type node)
                    '("fenced_code_block" "indented_code_block" "pipe_table"))
        (setq found t))
      (setq node (treesit-node-parent node)))
    found))

(defun tsp/markdown-auto-fill ()
  "Auto-fill Markdown prose, but never code blocks or pipe tables."
  (unless (tsp/markdown-in-unfillable-block-p)
    ;; Auto Fill does not need Markdown's structural paragraph motion.  Using
    ;; the generic motion also handles a brand-new file with no final newline.
    (let ((fill-forward-paragraph-function #'forward-paragraph))
      (do-auto-fill))))

(defun tsp/markdown-expand-source-block ()
  "Expand an indented `,LANGUAGE' at point into a fenced code block."
  (when (and (not (tsp/markdown-in-unfillable-block-p))
             (looking-back
              "^\\([[:blank:]]*\\),\\([[:alnum:]_+.-]+\\)"
              (line-beginning-position)))
    (let* ((indent (match-string-no-properties 1))
           (short-name (match-string-no-properties 2))
           (language (or (cdr (assoc-string
                               short-name
                               tsp/org-source-language-aliases
                               t))
                         short-name)))
      (delete-region (line-beginning-position) (point))
      (insert indent "```" language "\n"
              indent "\n"
              indent "```")
      (forward-line -1)
      (end-of-line)
      t)))

(defun tsp/markdown-auto-expand-source-block ()
  "Expand configured `,LANGUAGE' shortcuts without requiring Tab."
  (when (and (characterp last-command-event)
             (memq (char-syntax last-command-event) '(?w ?_))
             (looking-back
              (concat "^\\([[:blank:]]*\\),\\("
                      (regexp-opt tsp/org-auto-source-languages)
                      "\\)")
              (line-beginning-position)))
    (tsp/markdown-expand-source-block)))

(defun tsp/markdown-setup-buffer ()
  "Hard-wrap Markdown prose at 80 columns, leaving code blocks alone."
  (setq-local fill-column 80
              sentence-end-double-space nil
              normal-auto-fill-function #'tsp/markdown-auto-fill)
  (auto-fill-mode 1)
  (display-fill-column-indicator-mode 1)
  (add-hook 'post-self-insert-hook
            #'tsp/markdown-auto-expand-source-block nil t))

(defun tsp/markdown--next-image-file (assets-directory stem extension)
  "Return the next numbered image path for STEM in ASSETS-DIRECTORY."
  (let ((regexp (format "\\`%s\\([0-9]+\\)\\.[^.]+\\'"
                        (regexp-quote stem)))
        (next-number 0))
    (when (file-directory-p assets-directory)
      (dolist (name (directory-files assets-directory nil nil t))
        (when (string-match regexp name)
          (setq next-number
                (max next-number (1+ (string-to-number (match-string 1 name))))))))
    (expand-file-name (format "%s%d.%s" stem next-number extension)
                      assets-directory)))

(defun tsp/markdown-paste-clipboard-image ()
  "Save the clipboard image beside this Markdown file and insert its link."
  (interactive)
  (unless (and (derived-mode-p 'markdown-ts-mode) buffer-file-name)
    (user-error "Save this Markdown buffer before pasting an image"))
  (let* ((spec (tsp/org--clipboard-image-spec))
         (extension (car spec))
         (program (cadr spec))
         (arguments (cddr spec))
         (base-directory (file-name-directory buffer-file-name))
         (assets-directory (expand-file-name "assets/" base-directory))
         (stem (file-name-base buffer-file-name))
         (file (tsp/markdown--next-image-file
                assets-directory stem extension)))
    (make-directory assets-directory t)
    (if (string= program "pngpaste")
        (unless (zerop (call-process program nil nil nil file))
          (user-error "Could not read a PNG image from the clipboard"))
      (let ((coding-system-for-write 'binary))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (unless (zerop (apply #'call-process program nil t nil arguments))
            (user-error "Could not read an image from the clipboard"))
          (write-region (point-min) (point-max) file nil 'silent))))
    (insert (format "![](./assets/%s)" (file-name-nondirectory file)))
    (message "Saved clipboard image to %s" file)))

(use-package markdown-ts-mode
  :ensure nil
  :mode ("\\.md\\'" "\\.markdown\\'")
  :bind (:map markdown-ts-mode-map
              ("C-c C-v" . tsp/markdown-paste-clipboard-image))
  :hook (markdown-ts-mode . tsp/markdown-setup-buffer)
  :config
  (dolist (face-height '((markdown-ts-heading-1 . 1.40)
                         (markdown-ts-heading-2 . 1.30)
                         (markdown-ts-heading-3 . 1.20)
                         (markdown-ts-heading-4 . 1.15)
                         (markdown-ts-heading-5 . 1.10)
                         (markdown-ts-heading-6 . 1.05)))
    (set-face-attribute (car face-height) nil
                        :height (cdr face-height)
                        :weight 'bold)))

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
  (setq-local
   treesit-simple-indent-override-rules
   '((go ((parent-is "statement_list")
          tsp/treesit-grand-parent-bol
          go-ts-mode-indent-offset))))
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
              (replace-region-contents (point-min) (point-max)
                                       (lambda () formatted))
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

(defvar tsp/org-export-fontifying-code nil
  "Non-nil while Org is preparing a source block for HTML export.")

(defun tsp/enable-indent-bars-after-major-mode ()
  "Enable indentation bars after a programming mode finishes initializing."
  (when (and (derived-mode-p 'prog-mode)
             (not tsp/org-export-fontifying-code))
    (indent-bars-mode 1)))

(add-hook 'after-change-major-mode-hook
          #'tsp/enable-indent-bars-after-major-mode)

(defun tsp/org-html-fontify-code-without-indent-bars (original code language)
  "Call ORIGINAL for CODE and LANGUAGE without exported indentation guides."
  (let ((tsp/org-export-fontifying-code t))
    (funcall original code language)))

(with-eval-after-load 'ox-html
  (advice-add 'org-html-fontify-code :around
              #'tsp/org-html-fontify-code-without-indent-bars))

(use-package c-ts-mode
  :ensure nil)

(defun tsp/java-ts-incomplete-loop-block-p (_node parent _bol)
  "Return non-nil when PARENT is the block after an incomplete loop header.

Tree-sitter parses `for() {' as an error followed by a generic block while
the header is being typed.  Recognize that temporary tree so indentation
continues to behave like a loop body."
  (and parent
       (string= (treesit-node-type parent) "block")
       (save-excursion
         (goto-char (treesit-node-start parent))
         (beginning-of-line)
         (re-search-forward
          "\\_<\\(?:for\\|while\\)\\_>\\s-*()\\s-*{"
          (line-end-position) t))))

(defun tsp/java-setup-buffer ()
  "Keep Java indentation stable while incomplete loop headers are edited."
  (setq-local
   treesit-simple-indent-override-rules
   '((java ((and (node-is "}") tsp/java-ts-incomplete-loop-block-p)
            parent-bol 0)
           (tsp/java-ts-incomplete-loop-block-p
            parent-bol java-ts-mode-indent-offset)))))

(use-package java-ts-mode
  :ensure nil
  :hook (java-ts-mode . tsp/java-setup-buffer))

(use-package go-ts-mode
  :ensure nil
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
