;;; tsp-org-roam.el --- Org-roam and Org applications -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(global-set-key (kbd "C-c o d") #'org-roam-dailies-goto-today)
(global-set-key (kbd "C-c o D") #'org-roam-dailies-capture-today)

(defvar tsp/org-related-event-marker nil
  "Marker for the event awaiting a related Org-roam capture.")

(defvar tsp/org-related-note-id nil
  "ID of the Org-roam note awaiting capture.")

(defvar tsp/org-related-note-title nil
  "Title of the Org-roam note awaiting capture.")

(defun tsp/org-roam-related-note-finalize ()
  "Link the captured Org-roam note from its originating calendar event."
  (unwind-protect
      (progn
        (when (and (markerp tsp/org-related-event-marker)
                   (marker-buffer tsp/org-related-event-marker))
          (org-with-point-at tsp/org-related-event-marker
            (org-entry-put
             nil "RELATED_NOTE"
             (org-link-make-string (concat "id:" tsp/org-related-note-id)
                                   tsp/org-related-note-title))
            (save-buffer)))
        (org-roam-capture--finalize-find-file))
    (setq tsp/org-related-event-marker nil
          tsp/org-related-note-id nil
          tsp/org-related-note-title nil)))

(defun tsp/org-roam-note-from-event ()
  "Create or visit a typed Org-roam note related to the event at point."
  (interactive)
  (catch 'tsp/org-roam-note-from-event
  (require 'org-id)
  (require 'org-roam)
  (require 'org-roam-capture)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command must be used from an Org calendar event"))
  (org-back-to-heading t)
  (unless (org-entry-get nil "TIMESTAMP")
    (user-error "The heading at point has no event timestamp"))
  (let ((related (org-entry-get nil "RELATED_NOTE")))
    (when (and related (string-match "\\[\\[id:\\([^]]+\\)\\]" related))
      (if-let* ((node (org-roam-node-from-id (match-string 1 related))))
          (progn
            (org-roam-node-visit node)
            (throw 'tsp/org-roam-note-from-event nil))
        (user-error "The event's related note is missing from Org-roam"))))
  (let* ((event-marker (copy-marker (point)))
         (event-title (org-get-heading t t t t))
         (event-id (org-id-get-create))
         (event-time (org-entry-get nil "TIMESTAMP"))
         (event-date
          (condition-case nil
              (format-time-string "%Y-%m-%d" (org-time-string-to-time event-time))
            (error "")))
         (location (or (org-entry-get nil "LOCATION") ""))
         (types
          '((?m "Meeting" "meeting" "meetings/"
                "* Attendees\n\n- \n\n* Agenda\n\n- \n\n* Notes\n\n* Decisions\n\n* Follow-ups\n\n- [ ] ")
            (?e "Event" "event" "events/"
                "* Expectations\n\n* Observations\n\n* People and references\n\n* Outcome\n\n* Follow-ups\n\n- [ ] ")
            (?i "Idea" "idea" "ideas/"
                "* Motivation\n\n* Idea\n\n* Possible approaches\n\n* Next experiment\n")
            (?n "General" "note" ""
                "* Notes\n\n")
            (?p "Project" "project" "projects/"
                "* Outcome\n\n* Context\n\n* Notes\n\n* Links\n\n")
            (?r "Reference" "reference" "references/"
                "* Summary\n\n* Source\n\n* Notes\n\n")))
         (choice (read-char-choice
                  "Note type: [m]eeting [e]vent [i]dea [n]general [p]roject [r]eference: "
                  (mapcar #'car types)))
         (type (assq choice types))
         (default-title (if (string-empty-p event-date)
                            event-title
                          (format "%s — %s" event-title event-date)))
         (note-title (read-string "Note title: " default-title))
         (note-id (org-id-new))
         (body (concat "* Calendar event\n${event-link}\n"
                       (unless (string-empty-p location)
                         "Location: ${location}\n")
                       "\n" (nth 4 type) "%?"))
         (template
          `((,(char-to-string choice) ,(nth 1 type) plain ,body
             :target
             (file+head ,(concat (nth 3 type) "%<%Y%m%d%H%M%S>-${slug}.org")
                        ,(concat "#+title: ${title}\n#+filetags: :"
                                 (nth 2 type) ":\n"))
             :unnarrowed t))))
    (save-buffer)
    (setq tsp/org-related-event-marker event-marker
          tsp/org-related-note-id note-id
          tsp/org-related-note-title note-title)
    (org-roam-capture-
     :node (org-roam-node-create :id note-id :title note-title)
     :info (list :event-link
                 (org-link-make-string (concat "id:" event-id) event-title)
                 :location location)
     :templates template
     :props '(:finalize tsp/org-roam-related-note-finalize)))))

(global-set-key (kbd "C-c o N") #'tsp/org-roam-note-from-event)

(use-package org-roam
  :ensure t
  :after org
  :commands (org-roam-buffer-toggle org-roam-node-find org-roam-node-insert
             org-roam-dailies-goto-today org-roam-dailies-capture-today)
  :bind (("C-c o f" . org-roam-node-find)
         ("C-c o n" . org-roam-node-insert)
         ("C-c o b" . org-roam-buffer-toggle))
  :init
  (setq org-roam-directory tsp/org-roam-directory
        org-roam-db-location (tsp/emacs-state-file "org-roam.db")
        org-roam-dailies-directory "daily/"
        org-roam-completion-everywhere nil
        org-roam-capture-templates
        '(("n" "Note" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+date: %U\n")
           :unnarrowed t)
          ("p" "Person" plain "* Notes\n%?"
           :target (file+head "people/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+filetags: :person:\n")
           :unnarrowed t)
          ("r" "Reference" plain "* Summary\n%?\n\n* Source\n%^{Source}"
           :target (file+head "references/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+filetags: :reference:\n")
           :unnarrowed t)
          ("P" "Project note" plain "* Outcome\n%?\n\n* Notes\n\n* Links\n"
           :target (file+head "projects/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+filetags: :project:\n")
           :unnarrowed t))
        org-roam-dailies-capture-templates
        '(("d" "Daily dashboard" entry "* %<%H:%M> %?"
           :target
           (file+head "%<%Y-%m-%d>.org"
                      "#+title: %<%A, %Y-%m-%d>\n\n* Morning plan\n- [ ] Review the agenda\n- [ ] Choose three outcomes\n  1. \n  2. \n  3. \n\n* Log\n\n* Meetings\n\n* End-of-day review\n- [ ] Process the inbox\n- [ ] Update or reschedule open tasks\n- [ ] Link durable notes\n- [ ] Record wins and lessons\n"))))
  :config
  (org-roam-db-autosync-mode 1))

(use-package verb
  :ensure t
  :after org
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

(provide 'tsp-org-roam)
;;; tsp-org-roam.el ends here
