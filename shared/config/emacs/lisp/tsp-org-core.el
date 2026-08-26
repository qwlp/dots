;;; tsp-org-core.el --- Org foundations and workflow helpers -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(defun tsp/org-mode-setup ()
  "Custom setup for Org mode."
  (setq fill-column 80
        ;; A single space after sentence-ending punctuation is a valid place
        ;; to wrap; otherwise filling moves the preceding sentence fragment.
        sentence-end-double-space nil
        ;; Keep hard wrapping, but avoid Org's context-aware parser on every
        ;; fill-triggering space.  Plain `do-auto-fill' is enough for prose.
        normal-auto-fill-function #'do-auto-fill)
  (electric-indent-local-mode -1)
  (auto-fill-mode 1)
  (display-fill-column-indicator-mode 1)
  ;; Clean up the formatter hook when reloading over an older configuration.
  (remove-hook 'before-save-hook #'tsp/org-format-java-blocks t)
  (add-hook 'post-self-insert-hook
            #'tsp/org-auto-expand-source-block nil t)
  (add-hook 'post-command-hook
            #'tsp/org--hide-image-preview-after-move nil t))

(defun tsp/org-redisplay-inline-images ()
  "Refresh inline images after evaluating an Org source block."
  (when (derived-mode-p 'org-mode)
    (org-redisplay-inline-images)))

(defconst tsp/org-source-language-aliases
  '(("el" . "emacs-lisp")
    ("py" . "python")
    ("sh" . "shell"))
  "Short names accepted by `tsp/org-expand-source-block'.")

(defconst tsp/org-auto-source-languages '("go" "java" "py")
  "Source block names expanded immediately after they are typed.")

(defun org-babel-edit-prep:java (_info)
  "Use two-space indentation while editing Java Org source blocks."
  (setq-local c-basic-offset 2
              java-ts-mode-indent-offset 2
              tab-width 2
              indent-tabs-mode nil))

(defun tsp/org-tab-dwim ()
  "Indent source code at point; otherwise perform normal Org cycling."
  (interactive)
  (if (org-in-src-block-p 'inside)
      (org-babel-do-in-edit-buffer
       (indent-according-to-mode))
    (org-cycle)))

(defun tsp/org-return-dwim ()
  "Insert an indented source line at point; otherwise perform Org Return."
  (interactive)
  (if (org-in-src-block-p 'inside)
      (org-babel-do-in-edit-buffer
       (if (eq (char-after) ?})
           (progn
             (newline)
             (indent-according-to-mode)
             (beginning-of-line)
             (open-line 1)
             (indent-according-to-mode))
         (newline-and-indent)))
    (org-return)))

(defun tsp/org-expand-source-block ()
  "Expand an indented `,LANGUAGE' at point into an Org source block.
Return non-nil when an expansion was performed, for `org-tab-first-hook'."
  (when (looking-back
         "^\\([[:blank:]]*\\),\\([[:alnum:]_+.-]+\\)"
         (line-beginning-position))
    (let* ((indent (match-string-no-properties 1))
           (short-name (match-string-no-properties 2))
           (language (or (cdr (assoc-string
                               short-name
                               tsp/org-source-language-aliases
                               t))
                         short-name)))
      (delete-region (line-beginning-position) (point))
      (insert indent "#+begin_src " language "\n"
              indent "\n"
              indent "#+end_src")
      (forward-line -1)
      (end-of-line)
      t)))

(defun tsp/org-auto-expand-source-block ()
  "Expand configured `,LANGUAGE' shortcuts without requiring Tab."
  (when (and (characterp last-command-event)
             (memq (char-syntax last-command-event) '(?w ?_))
             (looking-back
              (concat "^\\([[:blank:]]*\\),\\("
                      (regexp-opt tsp/org-auto-source-languages)
                      "\\)")
              (line-beginning-position)))
    (tsp/org-expand-source-block)))

(defconst tsp/org-directory
  (file-name-as-directory
   (expand-file-name (or (getenv "ORG_DIRECTORY") "~/org")))
  "Root directory for Org data.")

(defconst tsp/org-inbox-file (expand-file-name "inbox.org" tsp/org-directory))
(defconst tsp/org-tasks-file (expand-file-name "tasks.org" tsp/org-directory))
(defconst tsp/org-projects-file (expand-file-name "projects.org" tsp/org-directory))
(defconst tsp/org-calendar-file (expand-file-name "calendar.org" tsp/org-directory))
(defconst tsp/org-archive-directory (expand-file-name "archive/" tsp/org-directory))
(defconst tsp/org-assets-directory (expand-file-name "assets/" tsp/org-directory))
(defconst tsp/org-roam-directory (expand-file-name "roam/" tsp/org-directory))
(defconst tsp/org-roam-dailies-directory
  (expand-file-name "daily/" tsp/org-roam-directory))
(defconst tsp/org-roam-note-directories
  (mapcar (lambda (directory)
            (expand-file-name directory tsp/org-roam-directory))
          '("meetings/" "events/" "ideas/" "projects/" "references/"))
  "Directories used by typed Org-roam note captures.")

(defun tsp/org-open-project-directory ()
  "Open the inherited DIR link and show it in the frame's only window."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command must be used in an Org buffer"))
  (let ((directory-link (org-entry-get nil "DIR" t)))
    (unless directory-link
      (user-error "This heading has no DIR property"))
    (org-link-open-from-string directory-link)
    (delete-other-windows)))

(defun tsp/org-bootstrap-file (file title &rest headings)
  "Create FILE with TITLE and HEADINGS when it does not exist."
  (unless (file-exists-p file)
    (make-directory (file-name-directory file) t)
    (with-temp-file file
      (insert "#+title: " title "\n\n")
      (dolist (heading headings)
        (insert "* " heading "\n")))))

(defun tsp/org-bootstrap ()
  "Create the directories and core files used by the Org workflow."
  (dolist (directory (append (list tsp/org-directory tsp/org-archive-directory
                                   tsp/org-assets-directory
                                   tsp/org-roam-directory
                                   tsp/org-roam-dailies-directory)
                             tsp/org-roam-note-directories))
    (make-directory directory t))
  (tsp/org-bootstrap-file tsp/org-inbox-file "Inbox")
  (tsp/org-bootstrap-file tsp/org-tasks-file "Tasks"
                          "Actions" "Waiting" "Someday" "Habits")
  (tsp/org-bootstrap-file tsp/org-projects-file "Projects"
                          "Active" "Completed")
  (tsp/org-bootstrap-file tsp/org-calendar-file "Calendar" "Events"))

(tsp/org-bootstrap)

(defvar-local tsp/org-temporary-image-overlays nil
  "Image overlays belonging to the current temporary preview.")

(defvar-local tsp/org-temporary-image-bounds nil
  "Markers bounding the image link currently being previewed.")

(defun tsp/org--clear-temporary-image-preview ()
  "Remove the temporary image preview in the current buffer."
  (mapc (lambda (overlay)
          (when (overlayp overlay)
            (delete-overlay overlay)))
        tsp/org-temporary-image-overlays)
  (setq tsp/org-temporary-image-overlays nil)
  (when tsp/org-temporary-image-bounds
    (mapc (lambda (marker) (set-marker marker nil))
          tsp/org-temporary-image-bounds)
    (setq tsp/org-temporary-image-bounds nil)))

(defun tsp/org--hide-image-preview-after-move ()
  "Hide the temporary preview after point leaves its image link."
  (when tsp/org-temporary-image-bounds
    (let ((begin (marker-position (car tsp/org-temporary-image-bounds)))
          (end (marker-position (cadr tsp/org-temporary-image-bounds))))
      (unless (and begin end (<= begin (point)) (< (point) end))
        (tsp/org--clear-temporary-image-preview)))))

(defun tsp/org-preview-image-at-point ()
  "Temporarily display the Org image link at point.
The preview is removed as soon as point moves outside the link."
  (interactive)
  (let* ((link (org-element-lineage (org-element-context) '(link) t))
         (type (and link (org-element-property :type link)))
         (path (and link (org-element-property :path link))))
    (unless (and link
                 (member type '("file" "attachment"))
                 path
                 (string-match-p (image-file-name-regexp) path))
      (user-error "Point is not on an image link"))
    (tsp/org--clear-temporary-image-preview)
    (let ((begin (org-element-property :begin link))
          (end (org-element-property :end link)))
      (org-display-inline-images t t begin end)
      (setq tsp/org-temporary-image-overlays
            (seq-filter (lambda (overlay)
                          (overlay-get overlay 'org-image-overlay))
                        (overlays-in begin end))
            tsp/org-temporary-image-bounds
            (list (copy-marker begin) (copy-marker end t)))
      (unless tsp/org-temporary-image-overlays
        (setq tsp/org-temporary-image-bounds nil)
        (user-error "Could not display this image")))))

(defun tsp/org-delete-image-at-point ()
  "Trash the pasted image at point and remove its Org link.
For safety, only image files inside `tsp/org-assets-directory' are removed."
  (interactive)
  (let* ((link (org-element-lineage (org-element-context) '(link) t))
         (type (and link (org-element-property :type link)))
         (path (and link (org-element-property :path link)))
         (base (if buffer-file-name
                   (file-name-directory buffer-file-name)
                 tsp/org-directory))
         (file (and (equal type "file") path
                    (expand-file-name (org-link-unescape path) base))))
    (unless (and link file
                 (string-match-p (image-file-name-regexp) file))
      (user-error "Point is not on a local image link"))
    (unless (and (file-exists-p file)
                 (file-in-directory-p (file-truename file)
                                      (file-truename tsp/org-assets-directory)))
      (user-error "Refusing to delete an image outside %s"
                  tsp/org-assets-directory))
    (when (yes-or-no-p (format "Trash %s and remove its Org link? "
                               (file-name-nondirectory file)))
      (let ((begin (org-element-property :begin link))
            (end (- (org-element-property :end link)
                    (or (org-element-property :post-blank link) 0))))
        (tsp/org--clear-temporary-image-preview)
        (move-file-to-trash file)
        (delete-region begin end)
        (message "Moved %s to trash and removed its link"
                 (file-name-nondirectory file))))))

(defun tsp/org--clipboard-image-spec ()
  "Return a clipboard image command and extension, or signal a user error."
  (cond
   ((executable-find "wl-paste")
    (let ((types (with-temp-buffer
                   (when (zerop (call-process "wl-paste" nil t nil "--list-types"))
                     (buffer-string)))))
      (cond
       ((string-match-p "image/png" types)
        '("png" "wl-paste" "--no-newline" "--type" "image/png"))
       ((string-match-p "image/jpeg" types)
        '("jpg" "wl-paste" "--no-newline" "--type" "image/jpeg"))
       ((string-match-p "image/webp" types)
        '("webp" "wl-paste" "--no-newline" "--type" "image/webp"))
       ((string-match-p "image/gif" types)
        '("gif" "wl-paste" "--no-newline" "--type" "image/gif"))
       (t (user-error "The clipboard does not contain an image")))))
   ((executable-find "xclip")
    ;; Xclip returns a non-zero status when the requested image target is absent.
    (let ((target (seq-find
                   (lambda (candidate)
                     (with-temp-buffer
                       (zerop (call-process "xclip" nil t nil "-selection" "clipboard"
                                            "-t" (car candidate) "-o"))))
                   '(("image/png" . "png") ("image/jpeg" . "jpg")
                     ("image/webp" . "webp") ("image/gif" . "gif")))))
      (if target
          (list (cdr target) "xclip" "-selection" "clipboard"
                "-t" (car target) "-o")
        (user-error "The clipboard does not contain an image"))))
   ((executable-find "pngpaste") '("png" "pngpaste"))
   (t (user-error "Install wl-clipboard, xclip, or pngpaste to paste clipboard images"))))

(defun tsp/org-paste-clipboard-image ()
  "Save the clipboard image under `tsp/org-assets-directory' and insert its link."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command is only available in Org buffers"))
  (let* ((spec (tsp/org--clipboard-image-spec))
         (extension (car spec))
         (program (cadr spec))
         (arguments (cddr spec))
         (name (format-time-string "clipboard-%Y%m%d-%H%M%S-%3N"))
         (file (expand-file-name (concat name "." extension)
                                 tsp/org-assets-directory)))
    (make-directory tsp/org-assets-directory t)
    (if (string= program "pngpaste")
        (unless (zerop (call-process program nil nil nil file))
          (user-error "Could not read a PNG image from the clipboard"))
      (let ((coding-system-for-write 'binary))
        (with-temp-buffer
          (set-buffer-multibyte nil)
          (unless (zerop (apply #'call-process program nil t nil arguments))
            (user-error "Could not read an image from the clipboard"))
          (write-region (point-min) (point-max) file nil 'silent))))
    (let* ((base (if buffer-file-name
                     (file-name-directory buffer-file-name)
                   tsp/org-directory))
           (link (file-relative-name file base)))
      (insert (format "[[file:%s]]" link))
      (message "Saved clipboard image to %s" file))))

(defun tsp/org-project-p ()
  "Return non-nil when the current heading is an unfinished project."
  (and (member (org-get-todo-state) '("TODO" "NEXT" "DOING" "WAIT"))
       (member "project" (org-get-tags nil t))))

(defun tsp/org-agenda-skip-non-projects ()
  "Skip the current subtree unless it is an unfinished project."
  (unless (tsp/org-project-p)
    (or (outline-next-heading) (point-max))))

(defun tsp/org-open-dashboard ()
  "Open the main Org agenda dashboard."
  (interactive)
  (org-agenda nil "d"))

(defun tsp/org-open-dashboard-on-startup ()
  "Open the Org agenda dashboard after interactive startup."
  (when (and (not noninteractive) (not (daemonp)))
    (tsp/org-open-dashboard)))

(add-hook 'emacs-startup-hook #'tsp/org-open-dashboard-on-startup 99)

(defun tsp/org-clock-out-if-done ()
  "Clock out when the current clocked task enters a done state."
  (when (and (member org-state org-done-keywords)
             (org-clocking-p)
             (equal (marker-buffer org-clock-marker) (current-buffer)))
    (org-clock-out)))

(defvar tsp/org-project-refile-in-progress nil
  "Non-nil while automatically refiling a project after a state change.")

(defun tsp/org-project-parent-section ()
  "Return the top-level section containing the heading at point."
  (save-excursion
    (org-back-to-heading t)
    (while (org-up-heading-safe))
    (org-get-heading t t t t)))

(defun tsp/org-refile-project-for-state ()
  "Move projects between Active and Completed according to `org-state'."
  (when (and (not tsp/org-project-refile-in-progress)
             org-state
             buffer-file-name
             (file-equal-p buffer-file-name tsp/org-projects-file)
             (member "project" (org-get-tags nil t)))
    (let ((target (if (member org-state org-done-keywords)
                      "Completed"
                    "Active")))
      (unless (equal target (tsp/org-project-parent-section))
        (let ((target-position
               (save-excursion
                 (goto-char (point-min))
                 (org-find-exact-headline-in-buffer target))))
          (when target-position
            (let ((tsp/org-project-refile-in-progress t))
              (org-refile nil nil
                          (list target tsp/org-projects-file nil
                                target-position)))))))))

(provide 'tsp-org-core)
;;; tsp-org-core.el ends here
