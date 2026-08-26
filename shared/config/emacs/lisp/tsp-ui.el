;;; tsp-ui.el --- UI defaults -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(setq inhibit-startup-screen t)
(setq-default truncate-lines t)
(set-face-attribute 'default nil :font "LythMono Nerd Font 13")

(display-time-mode -1)
(display-battery-mode -1)
(when (fboundp 'winum-mode)
  (winum-mode -1))

(defun tsp/mode-line-tabs ()
  "Return numbered Emacs tabs for display in the mode line."
  (let ((tabs (funcall tab-bar-tabs-function))
        (number 0))
    (when (> (length tabs) 1)
      (concat
       " tabs: "
       (mapconcat
        (lambda (tab)
          (setq number (1+ number))
          (if (eq (car tab) 'current-tab)
              (propertize (format "[%d]" number) 'face 'mode-line-emphasis)
            (format "%d" number)))
        tabs
        " ")
       "  "))))

(defun tsp/mode-line-format-with-tabs (format)
  "Return a copy of mode-line FORMAT with numbered tabs at the left."
  (let* ((tabs-item '(:eval (tsp/mode-line-tabs)))
         (result (delete tabs-item (copy-tree format)))
         (left-edge (memq 'mode-line-front-space result)))
    (if left-edge
        (setcdr left-edge (cons tabs-item (cdr left-edge)))
      (push tabs-item result))
    result))

(defun tsp/install-mode-line-tabs ()
  "Install the numbered tab segment in the current buffer's mode line."
  (when (listp mode-line-format)
    (setq mode-line-format (tsp/mode-line-format-with-tabs mode-line-format))))

;; Remove the former right-side placement when reloading, update both future
;; and already-existing buffers, and preserve the segment across mode changes.
(setq global-mode-string
      (delete '(:eval (tsp/mode-line-tabs)) global-mode-string))
(setq-default mode-line-format
              (tsp/mode-line-format-with-tabs
               (default-value 'mode-line-format)))
(add-hook 'after-change-major-mode-hook #'tsp/install-mode-line-tabs)
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (tsp/install-mode-line-tabs)))

(use-package pulsar
  :custom
  (pulsar-delay 0.03)
  (pulsar-iterations 12)
  (pulsar-face 'pulsar-cyan)
  (pulsar-highlight-face 'pulsar-cyan)
  (pulsar-window-change-face 'pulsar-cyan)
  (pulsar-pulse-on-window-change t)
  :config
  (dolist (command '(tsp/scroll-up-and-center
                     tsp/scroll-down-and-center
                     better-jumper-jump-backward
                     better-jumper-jump-forward))
    (add-to-list 'pulsar-pulse-functions command))
  (pulsar-global-mode 1))

(defconst tsp/script-fonts
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

(add-to-list 'face-font-rescale-alist '("Noto Sans Khmer" . 0.85))

(defun tsp/configure-script-fonts (&optional frame)
  "Configure multilingual fallback fonts on FRAME."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (dolist (entry tsp/script-fonts)
        (let ((font (font-spec :family (cdr entry))))
          (when (find-font font)
            (set-fontset-font t (car entry) font nil 'prepend)))))))

(tsp/configure-script-fonts)
(add-hook 'after-make-frame-functions #'tsp/configure-script-fonts)

(add-to-list 'custom-theme-load-path
             (expand-file-name "themes/" user-emacs-directory))
(let* ((state-file (expand-file-name "~/.local/state/tsp-theme/name"))
       (desktop-theme (when (file-readable-p state-file)
                        (intern (string-trim
                                 (with-temp-buffer
                                   (insert-file-contents state-file)
                                   (buffer-string)))))))
  (load-theme (if (memq desktop-theme '(naysayer aamis gruber-tsoding ginger-bill))
                  desktop-theme
                'naysayer)
              t))

(provide 'tsp-ui)
;;; tsp-ui.el ends here
