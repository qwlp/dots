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
   ("M-s r" . consult-ripgrep)
   ("M-s f" . consult-find)))

(use-package corfu
  :ensure t
  :demand t
  :init
  (setq corfu-cycle t
        corfu-auto t
        corfu-auto-prefix 2
        corfu-auto-delay 0.2)
  :config
  (global-corfu-mode))

(use-package which-key
  :ensure t
  :demand t
  :init
  (setq which-key-idle-delay 0.5)
  :config
  (which-key-mode))

(provide 'tsp-completion)
;;; tsp-completion.el ends here
