;;; tsp-apps.el --- Applications -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(use-package ghostel
  :ensure t
  :commands ghostel
  :init
  (setq ghostel-module-auto-install 'download)
  (setq-default ghostel-glyph-scale-floor 1.0))

(use-package multiple-cursors
  :ensure t
  :init
  (setq mc/list-file (tsp/emacs-state-file ".mc-lists.el"))
  :bind
  (("C-S-c C-S-c" . mc/edit-lines)
   ("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)
   ("C-'" . mc/skip-to-next-like-this)
   ("C-;" . mc/skip-to-previous-like-this)))

(use-package symbol-overlay
  :ensure t
  :bind
  (("M-i" . symbol-overlay-put)
   ("M-n" . symbol-overlay-switch-forward)
   ("M-p" . symbol-overlay-switch-backward)
   ("<f7>" . symbol-overlay-mode)
   ("<f8>" . symbol-overlay-remove-all)))

(use-package symbol-overlay-mc
  :ensure t
  :after symbol-overlay
  :bind
  (("M-a" . symbol-overlay-mc-mark-all)
   ("C-c n" . symbol-overlay-mc-mark-all)))

(use-package dired-x
  :ensure nil
  :after dired
  :hook (dired-mode . dired-omit-mode)
  :config
  (setq dired-omit-files (concat dired-omit-files "\\|^\\..+$")))

(use-package magit
  :ensure t
  :bind
  (("C-x g" . magit-status)
   ("C-x M-g" . magit-dispatch))
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-same-window-except-diff-v1))

(defun tsp/telega-khmer-string-p (string)
  "Return non-nil when STRING contains Khmer characters."
  (string-match-p "[ក-៿]" string))

(defun tsp/telega-rendered-string-width (string &optional from to)
  "Measure STRING using its rendered glyph width when it contains Khmer."
  (if (and (display-graphic-p)
           (tsp/telega-khmer-string-p
            (if (or from to) (substring string from to) string)))
      (telega-window-string-width string from to)
    (string-width string from to)))

(defun tsp/telega-glyph-boundaries (string)
  "Return a vector of grapheme boundaries in STRING."
  (let ((position 0)
        (boundaries (list 0)))
    (dolist (glyph (string-glyph-split string))
      (setq position (+ position (length glyph)))
      (push position boundaries))
    (vconcat (nreverse boundaries))))

(defun tsp/telega-fit-prefix-end (string boundaries max-width limit)
  "Return the longest grapheme-safe prefix of STRING within MAX-WIDTH.
Do not return a position beyond LIMIT."
  (let ((low 0)
        (high (1- (length boundaries)))
        (best 0))
    (while (<= low high)
      (let* ((middle (/ (+ low high) 2))
             (end (aref boundaries middle)))
        (if (or (> end limit)
                (> (tsp/telega-rendered-string-width string 0 end) max-width))
            (setq high (1- middle))
          (setq best end
                low (1+ middle)))))
    best))

(defun tsp/telega-fit-suffix-start (string boundaries max-width)
  "Return the earliest grapheme-safe suffix fitting within MAX-WIDTH."
  (let ((low 0)
        (high (1- (length boundaries)))
        (best (length string)))
    (while (<= low high)
      (let* ((middle (/ (+ low high) 2))
             (start (aref boundaries middle)))
        (if (<= (tsp/telega-rendered-string-width string start) max-width)
            (setq best start
                  high (1- middle))
          (setq low (1+ middle)))))
    best))

(defun tsp/telega-khmer-aware-eliding (original string properties)
  "Elide Khmer STRING by rendered grapheme width.
Call ORIGINAL for strings that do not contain Khmer."
  (if (not (tsp/telega-khmer-string-p string))
      (funcall original string properties)
    (let ((max-width (plist-get properties :max)))
      (if (or (not max-width)
              (<= (tsp/telega-rendered-string-width string) max-width))
          string
        (let* ((elide-string (or (plist-get properties :elide-string)
                                 telega-symbol-eliding))
               (elide-width (tsp/telega-rendered-string-width elide-string))
               (elide-position (or (plist-get properties :elide-position) 1))
               (available-width (max 0 (- max-width elide-width)))
               (trail-width (floor (* available-width
                                      (- 1 elide-position))))
               (boundaries (tsp/telega-glyph-boundaries string))
               (trail-start
                (tsp/telega-fit-suffix-start string boundaries trail-width))
               (actual-trail-width
                (tsp/telega-rendered-string-width string trail-start))
               (lead-width (max 0 (- available-width actual-trail-width)))
               (lead-end
                (tsp/telega-fit-prefix-end
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
  :ensure t
  :commands telega
  :init
  (setq telega-server-libs-prefix
        (expand-file-name "~/.local")
        telega-use-images t
        telega-emoji-use-images nil
        telega-symbol-width 1
        telega-open-file-function 'org-open-file)
  :config
  (unless (advice-member-p #'tsp/telega-khmer-aware-eliding
                           'telega-fmt-eval-eliding)
    (advice-add 'telega-fmt-eval-eliding
                :around #'tsp/telega-khmer-aware-eliding))
  (telega-notifications-mode 1))

(use-package exec-path-from-shell
  :ensure t
  :if (memq window-system '(mac ns x))
  :config
  (setq exec-path-from-shell-variables '("PATH" "MANPATH"))
  (exec-path-from-shell-initialize))

(use-package emms
  :ensure t
  :commands (emms emms-playlist-mode-go emms-browser emms-start emms-stop
                  emms-pause emms-next emms-previous)
  :bind (("C-c e g" . emms-playlist-mode-go)
         ("C-c e b" . emms-browser)
         ("C-c e s" . emms-start)
         ("C-c e x" . emms-stop)
         ("C-c e p" . emms-pause)
         ("C-c e n" . emms-next)
         ("C-c e r" . emms-previous))
  :init
  (setq emms-directory (tsp/emacs-state-file "emms/"))
  :custom
  (emms-directory (tsp/emacs-state-file "emms/"))
  (emms-source-file-default-directory "~/pCloud/My Music/")
  (emms-browser-covers #'emms-browser-cache-thumbnail-async)
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-player-list '(emms-player-mpv))
  (require 'emms-info-native)
  (setq emms-info-functions '(emms-info-native))
  (require 'emms-volume)
  (require 'emms-volume-mpv)
  (setq emms-volume-change-function 'emms-volume-mpv-change)
  (emms-mode-line-mode 1)
  (emms-playing-time-mode 1))

(provide 'tsp-apps)
;;; tsp-apps.el ends here
