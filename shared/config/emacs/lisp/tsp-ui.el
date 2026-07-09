;;; tsp-ui.el --- UI defaults -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

(setq inhibit-startup-screen t)
(setq-default truncate-lines t)

(setq display-time-format "%H:%M"
      display-time-default-load-average nil
      display-time-interval 60)
(display-time-mode 1)

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

(use-package naysayer-theme
  :ensure t
  :config
  (load-theme 'naysayer t))

(provide 'tsp-ui)
;;; tsp-ui.el ends here
