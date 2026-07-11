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
  (require 'tsp-telega-font)
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
                  emms-pause emms-next emms-previous tsp/emms-refresh-library)
  :bind (("C-c e g" . emms-playlist-mode-go)
         ("C-c e b" . emms-browser)
         ("C-c e u" . tsp/emms-refresh-library)
         ("C-c e s" . emms-start)
         ("C-c e x" . emms-stop)
         ("C-c e p" . emms-pause)
         ("C-c e n" . emms-next)
         ("C-c e r" . emms-previous)
         ("C-c e +" . emms-volume-raise)
         ("C-c e -" . emms-volume-lower)
         ("C-c e R" . emms-toggle-repeat-playlist)
         ("C-c e S" . emms-shuffle))
  :init
  (setq emms-directory (tsp/emacs-state-file "emms/")
        emms-mode-line-format " [%s]"
        emms-show-format "Now playing: %s")
  :custom
  (emms-directory (tsp/emacs-state-file "emms/"))
  (emms-source-file-default-directory "~/pCloud/My Music/")
  (emms-browser-covers #'emms-browser-cache-thumbnail-async)
  (emms-volume-change-amount 5)
  :config
  (require 'emms-setup)
  (emms-all)
  (setq emms-player-list '(emms-player-mpv))
  (require 'emms-info-native)
  (setq emms-info-functions '(emms-info-native))
  (setq emms-browser-info-title-format "%i%T. %t"
        emms-browser-playlist-info-title-format "%i%T. %t")
  (require 'emms-volume)
  (require 'emms-volume-mpv)
  (setq emms-volume-change-function 'emms-volume-mpv-change)
  (require 'emms-history)
  (emms-history-load)

  (defvar tsp/emms-library-refresh-timer nil)

  (defun tsp/emms-refresh-library (&optional quiet)
    "Rescan the music directory and refresh the EMMS browser.
When QUIET is non-nil, avoid status messages for automatic refreshes."
    (interactive)
    (let ((library (expand-file-name emms-source-file-default-directory)))
      (if (not (file-directory-p library))
          (unless quiet
            (message "EMMS library is not mounted: %s" library))
        (unless quiet
          (message "Refreshing EMMS library from %s..." library))
        ;; Populate the cache without adding the entire library to the user's queue.
        (with-temp-buffer
          (setq emms-playlist-buffer-p t
                emms-playlist-insert-track-function
                #'emms-playlist-mode-insert-track)
          (let ((emms-playlist-buffer (current-buffer)))
            (emms-add-directory-tree library)))
        ;; Older cache files may contain the printer's truncation marker,
        ;; which hides properties appearing after it (notably track titles).
        (maphash (lambda (path track)
                   (setcdr track (delq (intern "...") (cdr track)))
                   (when (and (emms-track-file-p track)
                              (file-in-directory-p path library))
                     (emms-info-native track)))
                 emms-cache-db)
        (emms-cache-sync t)
        (let (print-length print-level)
          (emms-cache-save))
        (when (buffer-live-p emms-browser-buffer)
          (with-current-buffer emms-browser-buffer
            (emms-browse-by emms-browser-default-browse-type)))
        (unless quiet
          (message "EMMS library refresh complete")))))

  (when (timerp tsp/emms-library-refresh-timer)
    (cancel-timer tsp/emms-library-refresh-timer))
  (setq tsp/emms-library-refresh-timer
        (run-with-idle-timer 60 600 #'tsp/emms-refresh-library t))
  (emms-mode-line-mode 1)
  (emms-playing-time-mode 1))

(provide 'tsp-apps)
;;; tsp-apps.el ends here
