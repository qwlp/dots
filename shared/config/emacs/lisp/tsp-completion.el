;;; tsp-completion.el --- Completion and navigation -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(use-package vertico
  :ensure t
  :demand t
  :config
  (vertico-mode))

(use-package orderless
  :ensure t
  :init
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :ensure t
  :demand t
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  :config
  (marginalia-mode))

(defcustom tsp/project-search-roots
  '("~/codecrafter" "~/bootdev" "~/DMUC" "~/" "~/projects"
    "~/projects/t3project" "~/frontendmasters")
  "Directories whose immediate children are offered by `tsp/find-project'."
  :type '(repeat directory)
  :group 'convenience)

(defun tsp/project-candidates ()
  "Return the existing immediate subdirectories of project search roots."
  (let (projects)
    (dolist (root tsp/project-search-roots)
      (when-let* ((directory (and (file-directory-p root)
                                 (file-name-as-directory
                                  (expand-file-name root)))))
        (dolist (entry (directory-files directory t directory-files-no-dot-files-regexp))
          (when (file-directory-p entry)
            (push (file-name-as-directory entry) projects)))))
    (sort (delete-dups projects) #'string-lessp)))

(defun tsp/find-project ()
  "Fuzzily select a directory and create Dired and Ghostel project tabs.

The search locations mirror `~/.local/bin/tmux-sessionizer'.  Git and other
recognized projects are remembered by project.el.  The first tab opens the
directory in Dired and the second starts a fresh Ghostel terminal there."
  (interactive)
  (let* ((projects (tsp/project-candidates))
         (_ (unless projects (user-error "No project directories found")))
         (choices (mapcar (lambda (directory)
                            (cons (abbreviate-file-name
                                   (directory-file-name directory))
                                  directory))
                          projects))
         (selection (completing-read "Project: " choices nil t))
         (directory (cdr (assoc selection choices))))
    (when-let* ((project (project-current nil directory)))
      (project-remember-project project))
    ;; Reuse the current tab as tab 1 so the project tabs always have stable
    ;; M-1/M-2 positions, regardless of the tabs that existed beforehand.
    (tab-bar-close-other-tabs)
    (let ((default-directory directory))
      (delete-other-windows)
      (dired directory)
      (tab-bar-rename-tab "files")
      (tab-bar-new-tab)
      (tab-bar-rename-tab "terminal")
      ;; A universal prefix asks Ghostel for a fresh buffer instead of reusing
      ;; a terminal belonging to another project directory.
      (call-interactively #'ghostel))
    (tab-bar-select-tab 1)))

(keymap-global-set "C-c p" #'tsp/find-project)

(defun tsp/yank-from-kill-ring ()
  "Yank from the Emacs kill ring, ignoring the system clipboard."
  (interactive)
  (let ((select-enable-clipboard nil)
        (select-enable-primary nil))
    (yank)))

(defun tsp/clipboard-command-text (program &rest args)
  "Return clipboard text from PROGRAM called with ARGS."
  (when (executable-find program)
    (with-temp-buffer
      (when (zerop (apply #'call-process program nil t nil args))
        (buffer-string)))))

(defun tsp/system-clipboard-text ()
  "Return the current system clipboard text."
  (or (tsp/clipboard-command-text "wl-paste" "--no-newline")
      (tsp/clipboard-command-text "xclip" "-selection" "clipboard" "-out")
      (tsp/clipboard-command-text "xsel" "--clipboard" "--output")
      (tsp/clipboard-command-text "pbpaste")
      (and (fboundp 'gui-get-selection)
           (gui-get-selection 'CLIPBOARD 'UTF8_STRING))
      (and (fboundp 'gui-get-selection)
           (gui-get-selection 'CLIPBOARD 'STRING))
      (and (fboundp 'x-get-selection)
           (x-get-selection 'CLIPBOARD 'UTF8_STRING))
      (and (fboundp 'x-get-selection)
           (x-get-selection 'CLIPBOARD 'STRING))
      (user-error "No system clipboard text available")))

(defun tsp/yank-from-system-clipboard ()
  "Insert the current system clipboard text."
  (interactive)
  (push-mark)
  (insert-for-yank (tsp/system-clipboard-text)))

(defun tsp/consult-system-clipboard-yank-pop ()
  "Run `consult-yank-pop' using the current system clipboard text."
  (interactive)
  (let* ((text (tsp/system-clipboard-text))
         (kill-ring (list text))
         (kill-ring-yank-pointer kill-ring))
    (consult-yank-pop)))

(use-package avy
  :ensure t
  :custom
  (avy-timeout-seconds 0.2)
  (avy-all-windows nil)
  (avy-single-candidate-jump t)
  (avy-background t)
  (avy-style 'at-full)
  (avy-keys '(?a ?s ?d ?f ?j ?k ?l ?\; ?g ?h))
  :bind
  (("M-s" . avy-goto-word-0)))

(declare-function tsp/better-jumper-set-jump "tsp-completion")

(use-package better-jumper
  :ensure t
  :demand t
  :preface
  (require 'ring)
  :custom
  (better-jumper-context 'window)
  (better-jumper-add-jump-behavior 'replace)
  (better-jumper-max-length 200)
  :bind
  (("M-o" . better-jumper-jump-backward)
   ("M-i" . better-jumper-jump-forward))
  :config
  (better-jumper-mode 1)

  (defun tsp/better-jumper-set-jump (&rest _)
    "Record point before a command which may move somewhere else."
    (better-jumper-set-jump))

  ;; better-jumper deliberately leaves the definition of a jump to the user.
  ;; Record the origin of the navigation commands used in this config.
  (dolist (command '(avy-goto-word-0
                     consult-line
                     consult-goto-line
                     consult-imenu
                     consult-outline
                     fff--open-result
                     xref-find-definitions
                     xref-find-definitions-other-window))
    (advice-add command :before #'tsp/better-jumper-set-jump)))

(use-package consult
  :ensure t
  :bind
  (("C-S-s" . consult-line)
   ("C-y" . tsp/yank-from-kill-ring)
   ("C-S-y" . tsp/yank-from-system-clipboard)
   ("C-Y" . tsp/yank-from-system-clipboard)
   ("C-x b" . consult-buffer)
   ("C-c h" . consult-history)
   ("C-c m" . consult-mode-command)
   ("C-c k" . consult-kmacro)
   ("M-y" . consult-yank-pop)
   ("M-S-y" . tsp/consult-system-clipboard-yank-pop)
   ("M-Y" . tsp/consult-system-clipboard-yank-pop)
   ("M-g g" . consult-goto-line)
   ("M-g M-g" . consult-goto-line)
   ("M-g o" . consult-outline)
   ("M-g i" . consult-imenu)))

;; fff.el uses the same native Rust search engine as fff.nvim.  Install its
;; native dependencies once with scripts/install-fff-el.sh.
(add-to-list 'load-path
             (expand-file-name "site-lisp/fff/" tsp/emacs-state-directory))

(defun tsp/fff-query-at-point ()
  "Return the active region or symbol at point for an fff grep."
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (thing-at-point 'symbol t)))

(defun tsp/fff-grep-dwim (&optional empty)
  "Run fff grep, initially searching for the text at point.
With prefix argument EMPTY, start with an empty query."
  (interactive "P")
  (require 'fff)
  (fff--ensure-instance)
  (fff--pick-grep 'plain (unless empty (tsp/fff-query-at-point))))

(declare-function tsp/fff-highlight-match "tsp-completion")
(declare-function tsp/fff-preview-state "tsp-completion")
(declare-function tsp/fff-pick-file-with-preview "tsp-completion")
(declare-function tsp/fff-pick-grep-with-preview "tsp-completion")

(use-package fff
  :ensure nil
  :commands (fff-find-file fff-grep fff-grep-fuzzy)
  :bind (("C-c f" . fff-find-file)
         ("C-c g" . tsp/fff-grep-dwim))
  :init
  (setq fff-max-results 200
        fff-smart-case t
        fff-frecency-db-path
        (expand-file-name "fff/frecency" tsp/emacs-state-directory)
        fff-history-db-path
        (expand-file-name "fff/history" tsp/emacs-state-directory))
  :config
  (defun tsp/fff-highlight-match (string query mode)
    "Return STRING with QUERY matches highlighted according to MODE."
    (let ((result (copy-sequence string))
          (case-fold-search (and fff-smart-case
                                 (string= query (downcase query)))))
      (if (eq mode 'fuzzy)
          (let ((position 0))
            (dolist (character (string-to-list query))
              (when-let* ((match (string-match
                                 (regexp-quote (char-to-string character))
                                 result position)))
                (add-face-text-property match (1+ match)
                                        'consult-highlight-match nil result)
                (setq position (1+ match)))))
        (unless (string-empty-p query)
          (let ((regexp (regexp-quote query))
                (position 0))
            (while (string-match regexp result position)
              (add-face-text-property (match-beginning 0) (match-end 0)
                                      'consult-highlight-match nil result)
              (setq position (max (1+ (match-beginning 0)) (match-end 0)))))))
      result))

  (defun tsp/fff-preview-state (&optional mode)
    "Return a Consult state function which previews fff result plists."
    (let ((open (consult--temporary-files))
          (preview (consult--buffer-preview))
          overlays)
      (lambda (action candidate)
        (mapc #'delete-overlay overlays)
        (setq overlays nil)
        (unless candidate
          (funcall open))
        (let ((buffer (and candidate
                           (eq action 'preview)
                           (when-let* ((path (plist-get candidate :path)))
                             (funcall open path)))))
          (funcall preview action buffer)
          (when-let* ((window (and buffer (get-buffer-window buffer))))
            (with-selected-window window
              (widen)
              ;; File results have no line information.  In that case, leave
              ;; point alone so revisiting an existing buffer keeps its place.
              (when-let* ((line (plist-get candidate :line)))
                (goto-char (point-min))
                (forward-line (max 0 (1- line)))
                (move-to-column (max 0 (or (plist-get candidate :col) 0))))
              (when (and mode (not (string-empty-p fff--last-query)))
                (let ((case-fold-search (and fff-smart-case
                                             (string= fff--last-query
                                                      (downcase fff--last-query))))
                      (end (line-end-position)))
                  (save-excursion
                    (beginning-of-line)
                    (if (eq mode 'fuzzy)
                        (dolist (character (string-to-list fff--last-query))
                          (when (search-forward (char-to-string character) end t)
                            (let ((overlay (make-overlay (1- (point)) (point))))
                              (overlay-put overlay 'face 'consult-highlight-match)
                              (push overlay overlays))))
                      (while (search-forward fff--last-query end t)
                        (let ((overlay (make-overlay (match-beginning 0)
                                                     (match-end 0))))
                          (overlay-put overlay 'face 'consult-highlight-match)
                          (push overlay overlays)))))))
              (recenter)))))))

  ;; Upstream fff.el currently omits Consult's preview state.  Keep its native
  ;; candidate generation, but add file/line preview to both picker variants.
  (defun tsp/fff-pick-file-with-preview ()
    (let ((lookup (make-hash-table :test 'equal)))
      (when-let* ((choice
                  (consult--read
                   (consult--async-dynamic
                    (lambda (input)
                      (mapcar (lambda (item)
                                (let ((display (tsp/fff-highlight-match
                                                (car item) input 'fuzzy)))
                                  (puthash display (cdr item) lookup)
                                  display))
                              (fff--file-candidates input))))
                   :prompt "fff › " :sort nil :category 'file
                   :lookup (lambda (candidate _candidates _input _narrow)
                             (gethash candidate lookup))
                   :state (tsp/fff-preview-state))))
        (fff--open-result choice))))

  (defun tsp/fff-pick-grep-with-preview (mode &optional initial)
    (let ((consult-async-split-style 'none)
          (lookup (make-hash-table :test 'equal)))
      (when-let* ((choice
                  (consult--read
                   (consult--async-dynamic
                    (lambda (input)
                      (mapcar (lambda (item)
                                (let ((display (tsp/fff-highlight-match
                                                (car item) input mode)))
                                  (puthash display (cdr item) lookup)
                                  display))
                              (fff--grep-candidates input mode))))
                   :prompt (if (eq mode 'fuzzy)
                               "fff grep fuzzy › "
                             "fff grep › ")
                   :sort nil
                   :initial initial
                   :lookup (lambda (candidate _candidates _input _narrow)
                             (gethash candidate lookup))
                   :state (tsp/fff-preview-state mode))))
        (fff--open-result choice))))

  (advice-add 'fff--pick-file :override #'tsp/fff-pick-file-with-preview)
  (advice-add 'fff--pick-grep :override #'tsp/fff-pick-grep-with-preview))

(use-package corfu
  :ensure t
  :demand t
  :init
  (setq corfu-cycle t
        ;; Let Emacs' Completion Preview provide inline ghost text; Corfu is
        ;; available only when completion is invoked manually.
        corfu-preview-current nil
        ;; Keep manual completion available everywhere, but do not run every
        ;; buffer's CAPF from an idle timer.  In particular, Elisp completion
        ;; and the TAGS fallback can be expensive enough to block redisplay.
        corfu-auto nil
        corfu-auto-prefix 3
        corfu-auto-delay 0.35)
  :config
  (global-corfu-mode))

(use-package completion-preview
  :ensure nil
  :bind (:map completion-preview-active-mode-map
         ("C-." . completion-preview-insert))
  :custom
  (completion-preview-commands
   '(self-insert-command
     org-self-insert-command
     insert-char
     delete-backward-char
     backward-delete-char-untabify
     analyze-text-conversion
     completion-preview-complete))
  (completion-preview-minimum-symbol-length 3)
  (completion-preview-idle-delay nil)
  :custom-face
  (completion-preview ((t (:foreground "#607f7f"))))
  (completion-preview-common
   ((t (:inherit completion-preview :underline t))))
  (completion-preview-exact
   ((t (:inherit completion-preview-common :underline "#44b340")))))

(use-package cape
  :ensure t
  :commands cape-dabbrev
  :custom
  (cape-dabbrev-buffer-function #'current-buffer))

(defun tsp/enable-completion-preview ()
  "Enable dabbrev-backed inline completion in ordinary editable buffers."
  ;; Ensure reloading this configuration also closes and disables any Corfu
  ;; popup previously enabled buffer-locally.
  (setq-local corfu-auto nil)
  (if (or (minibufferp)
          buffer-read-only
          (derived-mode-p 'emacs-lisp-mode
                          'lisp-interaction-mode
                          'special-mode
                          'ghostel-mode))
      (completion-preview-mode -1)
    (add-hook 'completion-at-point-functions #'cape-dabbrev t t)
    (completion-preview-mode 1)))

(add-hook 'after-change-major-mode-hook #'tsp/enable-completion-preview)

;; `tsp/reload-config' does not rerun major-mode hooks in the current buffer.
(tsp/enable-completion-preview)

(use-package which-key
  :ensure t
  :demand t
  :init
  (setq which-key-idle-delay 0.5)
  :config
  (which-key-mode))

(provide 'tsp-completion)
;;; tsp-completion.el ends here
