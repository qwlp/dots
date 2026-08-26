;;; tsp-core.el --- Core defaults -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(unless (boundp 'tsp/emacs-state-directory)
  (defconst tsp/emacs-state-directory
    (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME")
                                   (expand-file-name "~/.local/state/")))
    "Directory for persistent Emacs state."))

(unless (boundp 'tsp/emacs-cache-directory)
  (defconst tsp/emacs-cache-directory
    (expand-file-name "emacs/" (or (getenv "XDG_CACHE_HOME")
                                   (expand-file-name "~/.cache/")))
    "Directory for generated Emacs cache files."))

(defun tsp/emacs-state-file (file)
  "Return FILE under `tsp/emacs-state-directory'."
  (expand-file-name file tsp/emacs-state-directory))

(defun tsp/emacs-cache-file (file)
  "Return FILE under `tsp/emacs-cache-directory'."
  (expand-file-name file tsp/emacs-cache-directory))

(dolist (directory (list tsp/emacs-state-directory
                         tsp/emacs-cache-directory
                         (tsp/emacs-state-file "auto-save-list/")
                         (tsp/emacs-state-file "emms/")
                         (tsp/emacs-state-file "eshell/")
                         (tsp/emacs-state-file "multisession/")
                         (tsp/emacs-state-file "transient/")
                         (tsp/emacs-state-file "url/")
                         (tsp/emacs-cache-file "backups/")
                         (tsp/emacs-cache-file "auto-save/")
                         (tsp/emacs-cache-file "tree-sitter/")))
  (make-directory directory t))

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache (tsp/emacs-cache-file "eln-cache/")))

(setq package-user-dir (tsp/emacs-state-file "elpa/")
      auto-save-list-file-prefix (tsp/emacs-state-file "auto-save-list/.saves-")
      project-list-file (tsp/emacs-state-file "projects")
      tramp-persistency-file-name (tsp/emacs-state-file "tramp")
      transient-levels-file (tsp/emacs-state-file "transient/levels.el")
      transient-values-file (tsp/emacs-state-file "transient/values.el")
      transient-history-file (tsp/emacs-state-file "transient/history.el")
      eshell-directory-name (tsp/emacs-state-file "eshell/")
      url-cookie-file (tsp/emacs-state-file "url/cookies")
      save-place-file (tsp/emacs-state-file "places")
      recentf-save-file (tsp/emacs-state-file "recentf")
      savehist-file (tsp/emacs-state-file "history")
      smex-save-file (tsp/emacs-state-file "smex-items")
      mc/list-file (tsp/emacs-state-file ".mc-lists.el")
      multisession-directory (tsp/emacs-state-file "multisession/"))

(setq gc-cons-threshold (* 64 1024 1024)
      read-process-output-max (* 1024 1024)
      process-adaptive-read-buffering nil
      bidi-inhibit-bpa t
      inhibit-compacting-font-caches t
      redisplay-skip-fontification-on-input t
      fast-but-imprecise-scrolling t
      scroll-error-top-bottom t)

(setq-default bidi-display-reordering t
              bidi-paragraph-direction nil
              cursor-in-non-selected-windows nil
              cursor-type 'box
              indent-tabs-mode nil
              tab-width 4)

(setq-default c-basic-offset 4)

;; Insert matching closing delimiters and skip over them when typed, except
;; for angle brackets, which are commonly comparison operators or Java
;; generic delimiters entered before their contents.
(defun tsp/electric-pair-inhibit-angle-brackets (char)
  "Prevent automatic pairing of angle brackets for CHAR."
  (or (eq char ?<)
      (electric-pair-default-inhibit char)))

(setq electric-pair-inhibit-predicate
      #'tsp/electric-pair-inhibit-angle-brackets
      ;; Typing an existing closing delimiter should move over it rather than
      ;; insert a duplicate.
      electric-pair-skip-self t
      ;; Do not treat a matching delimiter after whitespace as the delimiter
      ;; at point; this otherwise makes quotes jump across blank lines.
      electric-pair-skip-whitespace nil)

(electric-pair-mode 1)

;; Keep high-resolution trackpad and mouse-wheel scrolling pixel-precise.
;; `ultra-scroll' enables the built-in `pixel-scroll-precision-mode' itself.
(use-package ultra-scroll
  :init
  (setq scroll-conservatively 3
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))

(defun tsp/scroll-up-and-center ()
  "Scroll forward and center point in the window."
  (interactive)
  (call-interactively #'scroll-up-command)
  (recenter))

(defun tsp/scroll-down-and-center ()
  "Scroll backward and center point in the window.
Move to the beginning of the buffer if scrolling makes no progress."
  (interactive)
  (let ((old-point (point))
        (old-window-start (window-start)))
    (call-interactively #'scroll-down-command)
    (recenter)
    (when (and (= (point) old-point)
               (= (window-start) old-window-start))
      (goto-char (point-min))
      (recenter))))

(keymap-global-set "C-v" #'tsp/scroll-up-and-center)
(keymap-global-set "M-v" #'tsp/scroll-down-and-center)

(defun tsp/line-bounds ()
  "Return the bounds and line count of the current line or active region.

The returned list is (BEG END COUNT).  When the region ends at the
beginning of a line, that line is not included."
  (let* ((regionp (use-region-p))
         (start (if regionp (region-beginning) (point)))
         (finish (if regionp (region-end) (point)))
         (beg (save-excursion
                (goto-char start)
                (line-beginning-position)))
         (end (save-excursion
                (goto-char finish)
                (unless (and regionp (> finish start) (bolp))
                  (forward-line 1))
                (point))))
    (list beg end (max 1 (count-lines beg end)))))

(defun tsp/move-lines (direction)
  "Move the current line or active region one line in DIRECTION.

DIRECTION must be -1 to move up or 1 to move down.  Point and an active
region keep their positions within the moved text."
  (let* ((regionp (use-region-p))
         (bounds (tsp/line-bounds))
         (beg (nth 0 bounds))
         (end (nth 1 bounds))
         (line-count (nth 2 bounds))
         (point-offset (- (point) beg))
         (mark-offset (and regionp (- (mark) beg)))
         (missing-final-newline
          (and (> (point-max) (point-min))
               (/= (char-before (point-max)) ?\n)))
         new-beg)
    (atomic-change-group
      ;; Giving the final line a temporary terminator lets `transpose-regions'
      ;; treat every line uniformly.  Remove it again after the swap.
      (when missing-final-newline
        (let ((old-max (point-max)))
          (save-excursion
            (goto-char old-max)
            (insert "\n"))
          (when (= end old-max)
            (setq end (1+ end)))))
      (pcase direction
        (-1
         (when (= beg (point-min))
           (user-error "Already at the first line"))
         (let ((previous-beg (save-excursion
                               (goto-char beg)
                               (forward-line -1)
                               (point))))
           (transpose-regions previous-beg beg beg end)
           (setq new-beg previous-beg)))
        (1
         (when (= end (point-max))
           (user-error "Already at the last line"))
         (let ((next-end (save-excursion
                           (goto-char end)
                           (forward-line 1)
                           (point))))
           (transpose-regions beg end end next-end)
           (setq new-beg (+ beg (- next-end end)))))
        (_ (error "Invalid line movement direction: %S" direction)))
      (when missing-final-newline
        (save-excursion
          (goto-char (point-max))
          (delete-char -1))))
    (let ((new-end (save-excursion
                     (goto-char new-beg)
                     (forward-line line-count)
                     (point))))
      (goto-char (+ new-beg (min point-offset (- new-end new-beg))))
      (when regionp
        (set-mark (+ new-beg (min mark-offset (- new-end new-beg))))
        (setq deactivate-mark nil)))))

(defun tsp/move-lines-up ()
  "Move the current line or active region up by one line."
  (interactive)
  (tsp/move-lines -1))

(defun tsp/move-lines-down ()
  "Move the current line or active region down by one line."
  (interactive)
  (tsp/move-lines 1))

(defun tsp/duplicate-line-above ()
  "Duplicate the current line above it, keeping point on the new line."
  (interactive)
  (let* ((beg (line-beginning-position))
         (text (buffer-substring beg (line-end-position)))
         (offset (- (point) beg)))
    (goto-char beg)
    (insert text "\n")
    (goto-char (+ beg (min offset (length text))))))

;; Keep line editing under a dedicated user prefix so mode-specific editing
;; keys (especially Org's Meta-arrow bindings) remain untouched.
(defvar-keymap tsp/line-edit-map
  :doc "Keymap for lightweight line editing commands."
  "d" #'duplicate-dwim
  "l" #'duplicate-line
  "p" #'tsp/move-lines-up
  "n" #'tsp/move-lines-down
  "<up>" #'tsp/move-lines-up
  "<down>" #'tsp/move-lines-down)

;; Remove the former binding when reloading an existing Emacs session.
(when (eq (keymap-global-lookup "C-c L") tsp/line-edit-map)
  (keymap-global-unset "C-c L"))

(keymap-global-set "C-c s" tsp/line-edit-map)

;; Remove the former Super bindings when reloading an existing session.
(when (eq (keymap-global-lookup "s-n") #'tsp/move-lines-down)
  (keymap-global-unset "s-n"))
(when (eq (keymap-global-lookup "s-p") #'tsp/move-lines-up)
  (keymap-global-unset "s-p"))

;; Hold Alt+Shift and tap n/p repeatedly.  Control-n/p retain normal line
;; navigation.
(keymap-global-set "M-N" #'tsp/move-lines-down)
(keymap-global-set "M-P" #'tsp/move-lines-up)

;; Duplicate below with Control+Shift+j and above with Control+Shift+k.
(when (eq (keymap-global-lookup "C-S-d") #'duplicate-line)
  (keymap-global-unset "C-S-d"))
(when (eq (keymap-global-lookup "C-S-i") #'tsp/duplicate-line-above)
  (keymap-global-unset "C-S-i"))
(keymap-global-set "C-S-j" #'duplicate-line)
(keymap-global-set "C-S-k" #'tsp/duplicate-line-above)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist tsp/startup-file-name-handler-alist
                  gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)
            (message "Emacs loaded in %s with %d garbage collections."
                     (emacs-init-time)
                     gcs-done)))

;; Keep Customize's generated output out of the source-controlled config.
;; Intentional settings belong in this literate configuration instead.
(setq custom-file (tsp/emacs-state-file "custom.el"))

(setq backup-directory-alist `(("." . ,(tsp/emacs-cache-file "backups/")))
      auto-save-file-name-transforms
      `((".*" ,(tsp/emacs-cache-file "auto-save/") t))
      create-lockfiles nil)

(setq shell-command-switch "-lc"
      next-line-add-newlines t)

(global-so-long-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)

(defun tsp/config-file (file)
  "Return FILE under `user-emacs-directory'."
  (expand-file-name file user-emacs-directory))

(defun tsp/tangle-config ()
  "Tangle the literate Emacs configuration."
  (interactive)
  (let ((config (tsp/config-file "config.org")))
    (when-let ((buffer (find-buffer-visiting config)))
      (with-current-buffer buffer
        (when (buffer-modified-p)
          (save-buffer))))
    (require 'org)
    (org-babel-tangle-file config)))

(defvar tsp/reloading-config-p nil
  "Non-nil while the literate configuration is being reloaded.")

(defun tsp/reload-config ()
  "Tangle and reload the config in the current Emacs process.

In a daemon session this updates the server and redraws every attached client
frame.  Early-init settings are intentionally not reevaluated because they are
only meaningful while the Emacs process is starting."
  (interactive)
  (when tsp/reloading-config-p
    (user-error "The Emacs configuration is already being reloaded"))
  (let ((init-file (or user-init-file (tsp/config-file "init.el")))
        (started-at (current-time))
        (tsp/reloading-config-p t))
    (condition-case error-data
        (progn
          ;; Loading the UI module recalculates theme faces.  Do not show the
          ;; short-lived default face state between those calculations.
          (let ((inhibit-redisplay t))
            (tsp/tangle-config)
            (load init-file nil nil t)
            (dolist (frame (frame-list))
              (when (frame-live-p frame)
                (with-selected-frame frame
                  (when (fboundp 'tsp/configure-script-fonts)
                    (tsp/configure-script-fonts frame))
                  (force-mode-line-update t)))))
          ;; Force pending updates without clearing every frame first.  A full
          ;; `redraw-display' briefly exposes the frame's white backing surface
          ;; on some compositors.
          (redisplay t)
          (message "Reloaded Emacs config in %.2fs%s"
                   (float-time (time-subtract (current-time) started-at))
                   (if (daemonp) " for all daemon frames" "")))
      (error
       (redisplay t)
       (message "Config reload failed: %s" (error-message-string error-data))
       (signal (car error-data) (cdr error-data))))))

(keymap-global-set "C-c r" #'tsp/reload-config)

;; Emoji insertion: search by name for the common case, with the visual
;; browser and recently used emojis available on the same prefix.
(keymap-global-set "C-c i e" #'emoji-search)
(keymap-global-set "C-c i E" #'emoji-list)
(keymap-global-set "C-c i r" #'emoji-recent)

;; Window layout history, project tabs, and temporary popups.
(winner-mode 1)
(setq tab-bar-show nil)
(tab-bar-mode 1)
(tab-bar-history-mode 1)

;; Keep tmux-style navigation ahead of major and minor mode bindings.  Binding
;; `tab-bar-select-tab' directly lets it infer the tab number from the digit.
(defvar tsp/navigation-keys-mode t)
(defvar tsp/navigation-keys-mode-map
  (let ((map (make-sparse-keymap)))
    (dolist (digit '(1 2 3 4 5 6 7 8 9))
      (define-key map (kbd (format "M-%d" digit)) #'tab-bar-select-tab))
    (define-key map (kbd "M-h") #'windmove-left)
    (define-key map (kbd "M-l") #'windmove-right)
    map))
(define-key tsp/navigation-keys-mode-map (kbd "C-S-t") #'tab-bar-new-tab)
(define-key tsp/navigation-keys-mode-map (kbd "M-S-q") #'tab-bar-close-tab)
(define-key tsp/navigation-keys-mode-map (kbd "M-Q") #'tab-bar-close-tab)

(defvar tsp/navigation-keys-emulation-alist
  `((tsp/navigation-keys-mode . ,tsp/navigation-keys-mode-map)))

(defun tsp/prioritize-navigation-keys ()
  "Keep tab and window navigation ahead of terminal emulation maps."
  ;; Delete the older literal entry too, so reloading upgrades this setting
  ;; without requiring an Emacs restart.
  (setq emulation-mode-map-alists
        (delete tsp/navigation-keys-emulation-alist
                emulation-mode-map-alists))
  (setq emulation-mode-map-alists
        (cons 'tsp/navigation-keys-emulation-alist
              (delete 'tsp/navigation-keys-emulation-alist
                      emulation-mode-map-alists))))

(tsp/prioritize-navigation-keys)
(with-eval-after-load 'ghostel
  (tsp/prioritize-navigation-keys))

;; Match Kitty's pane-management keys.
(keymap-global-set "M-V" #'split-window-right)
(keymap-global-set "M-M" #'split-window-below)
(keymap-global-set "M-W" #'delete-window)

;; Match Sublime Text's one- and two-column layouts.  Bind both the shifted
;; digit events and their translated punctuation forms for GUI and terminal
;; compatibility.
(defun tsp/window-layout-one-column ()
  "Show only the selected window."
  (interactive)
  (delete-other-windows))

(defun tsp/window-layout-two-columns ()
  "Reset the frame to two side-by-side windows."
  (interactive)
  (delete-other-windows)
  (split-window-right))

(dolist (key '("M-S-1" "M-!"))
  (keymap-global-set key #'tsp/window-layout-one-column))
(dolist (key '("M-S-2" "M-@"))
  (keymap-global-set key #'tsp/window-layout-two-columns))

(use-package popper
  :ensure t
  :bind
  (("C-`" . popper-toggle)
   ("C-M-`" . popper-cycle))
  :custom
  (popper-reference-buffers
   '("\\*Messages\\*"
     "\\*Warnings\\*"
     "\\*Help\\*"
     "\\*Async Shell Command\\*"
     "\\*Shell Command Output\\*"
     help-mode
     compilation-mode
     shell-mode
     eshell-mode
     term-mode
     vterm-mode))
  :config
  (popper-mode 1)
  (popper-echo-mode 1))

(provide 'tsp-core)
;;; tsp-core.el ends here
