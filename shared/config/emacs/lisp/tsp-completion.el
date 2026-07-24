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
  (("C-s" . avy-goto-char-timer)))

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
   ("M-g i" . consult-imenu)
   ("M-s g" . consult-grep)
   ("M-s f" . consult-find)))

;; fff.el uses the same native Rust search engine as fff.nvim.  Install its
;; native dependencies once with scripts/install-fff-el.sh.
(add-to-list 'load-path
             (expand-file-name "site-lisp/fff/" tsp/emacs-state-directory))

(use-package fff
  :ensure nil
  :commands (fff-find-file fff-grep fff-grep-fuzzy)
  :bind (("C-c f" . fff-find-file)
         ("C-c g" . fff-grep))
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
              (when-let ((match (string-match
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
                           (when-let ((path (plist-get candidate :path)))
                             (funcall open path)))))
          (funcall preview action buffer)
          (when-let ((window (and buffer (get-buffer-window buffer))))
            (with-selected-window window
              (widen)
              ;; File results have no line information.  In that case, leave
              ;; point alone so revisiting an existing buffer keeps its place.
              (when-let ((line (plist-get candidate :line)))
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
      (when-let ((choice
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

  (defun tsp/fff-pick-grep-with-preview (mode)
    (let ((lookup (make-hash-table :test 'equal)))
      (when-let ((choice
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
        ;; Keep manual completion available everywhere, but do not run every
        ;; buffer's CAPF from an idle timer.  In particular, Elisp completion
        ;; and the TAGS fallback can be expensive enough to block redisplay.
        corfu-auto nil
        corfu-auto-prefix 3
        corfu-auto-delay 0.35)
  :config
  (global-corfu-mode))

(defun tsp/corfu-enable-auto-completion ()
  "Enable automatic Corfu popups in inexpensive programming buffers."
  (unless (derived-mode-p 'emacs-lisp-mode 'lisp-interaction-mode)
    (setq-local corfu-auto t)))

(add-hook 'prog-mode-hook #'tsp/corfu-enable-auto-completion)

(use-package which-key
  :ensure t
  :demand t
  :init
  (setq which-key-idle-delay 0.5)
  :config
  (which-key-mode))

(provide 'tsp-completion)
;;; tsp-completion.el ends here
