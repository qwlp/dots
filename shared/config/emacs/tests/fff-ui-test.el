;;; fff-ui-test.el --- Regression test for the FFF popup -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'fff)

(defvar tsp/fff-ui-test--observation nil)
(defvar tsp/fff-ui-test--cancel-observation nil)

(defun tsp/fff-ui-test--observe ()
  "Record where the active minibuffer input is visible, then leave it."
  (condition-case error-data
      (progn
        (redisplay t)
        (let* ((minibuffer-window (active-minibuffer-window))
             (popup (and minibuffer-window (window-frame minibuffer-window)))
             (candidate-window
              (and popup
                   (seq-find
                    (lambda (window)
                      (window-parameter window 'tsp/fff-candidates))
                    (window-list popup))))
             (preview-window
              (and popup
                   (seq-find
                    (lambda (window)
                      (window-parameter window 'tsp/fff-preview))
                    (window-list popup))))
             (input-position
              (and minibuffer-window
                   (with-current-buffer (window-buffer minibuffer-window)
                     (point))))
             (input
              (and minibuffer-window
                   (with-current-buffer (window-buffer minibuffer-window)
                     (minibuffer-contents-no-properties))))
             (input-views
              (cl-count-if
               #'identity
               (list (and input-position
                          (pos-visible-in-window-p input-position
                                                   minibuffer-window t))
                     (and input-position candidate-window
                          (pos-visible-in-window-p input-position
                                                   candidate-window t))))))
          (setq tsp/fff-ui-test--observation
                (list :input-views input-views
                      :input input
                      :minibuffer-pixels
                      (and minibuffer-window
                           (window-pixel-height minibuffer-window))
                      :candidate-size
                      (and candidate-window
                           (cons (window-pixel-width candidate-window)
                                 (window-pixel-height candidate-window)))
                      :preview-size
                      (and preview-window
                           (cons (window-pixel-width preview-window)
                                 (window-pixel-height preview-window)))
                      :minibuffer-selected
                      (eq minibuffer-window (selected-window))))
          (exit-minibuffer)))
    (error
     (setq tsp/fff-ui-test--observation (list :error error-data))
     (abort-recursive-edit))))

(ert-deftest tsp/fff-popup-shows-input-once ()
  "The FFF popup must not show its minibuffer input in two windows."
  (skip-unless (display-graphic-p))
  (setq tsp/fff-ui-test--observation nil)
  (run-at-time 0.5 nil #'tsp/fff-ui-test--observe)
  (condition-case error-data
      (tsp/fff-with-popup
       (lambda ()
         (minibuffer-with-setup-hook
             (lambda ()
               (setq unread-command-events
                     (append (string-to-list "needle")
                             unread-command-events)))
           (consult--read '("needle.org" "notes.org") :prompt "fff › "))))
    (quit nil)
    (error
     (setq tsp/fff-ui-test--observation
           (list :outer-error error-data))))
  (setq tsp/fff-ui-test--observation
        (append tsp/fff-ui-test--observation
                (list :candidate-buffer-after
                      (and-let* ((buffer (get-buffer " *fff-candidates*")))
                        (with-current-buffer buffer
                          (list (buffer-name) major-mode (buffer-size))))
                      :preview-buffer-after
                      (and-let* ((buffer (get-buffer " *fff-preview*")))
                        (with-current-buffer buffer
                          (list (buffer-name) major-mode (buffer-size))))
                      :child-frames-after
                      (cl-count-if
                       (lambda (frame) (frame-parameter frame 'parent-frame))
                       (frame-list)))))
  (ert-info ((format "FFF UI observation: %S"
                     tsp/fff-ui-test--observation))
    (should-not (plist-get tsp/fff-ui-test--observation :error))
    (should (equal "needle" (plist-get tsp/fff-ui-test--observation :input)))
    (should (= 1 (plist-get tsp/fff-ui-test--observation :input-views)))
    (should (plist-get tsp/fff-ui-test--observation :minibuffer-selected))
    (should (> (cdr (plist-get tsp/fff-ui-test--observation :candidate-size)) 100))
    (should (> (cdr (plist-get tsp/fff-ui-test--observation :preview-size)) 100))
    (should-not (plist-get tsp/fff-ui-test--observation
                           :candidate-buffer-after))
    (should-not (plist-get tsp/fff-ui-test--observation
                           :preview-buffer-after))
    (should (zerop (plist-get tsp/fff-ui-test--observation
                              :child-frames-after)))))

(defun tsp/fff-ui-test--select-candidates-and-quit ()
  "Move focus to the visible candidate pane and type C-g."
  (when-let* ((minibuffer-window (active-minibuffer-window))
              (popup (window-frame minibuffer-window))
              (candidate-window
               (seq-find
                (lambda (window)
                  (window-parameter window 'tsp/fff-candidates))
                (window-list popup))))
    (setq tsp/fff-ui-test--cancel-observation
          (list :quit-sent t
                :minibuffer-selected-before
                (eq minibuffer-window (selected-window))))
    (select-window candidate-window)
    (setq unread-command-events
          (cons ?\C-g unread-command-events))))

(defun tsp/fff-ui-test--cancel-watchdog ()
  "Record a popup which ignored C-g, then close its minibuffer."
  (setq tsp/fff-ui-test--cancel-observation
        (append tsp/fff-ui-test--cancel-observation
                (list :stuck-after-quit t)))
  (when-let* ((minibuffer-window (active-minibuffer-window)))
    (select-window minibuffer-window)
    (exit-minibuffer)))

(ert-deftest tsp/fff-popup-c-g-closes-from-visible-pane ()
  "C-g must close FFF even when the visible candidate pane has focus."
  (skip-unless (display-graphic-p))
  (setq tsp/fff-ui-test--cancel-observation nil)
  (let ((quit-timer
         (run-at-time 0.2 nil #'tsp/fff-ui-test--select-candidates-and-quit))
        (watchdog-timer
         (run-at-time 0.8 nil #'tsp/fff-ui-test--cancel-watchdog)))
    (unwind-protect
        (condition-case nil
            (tsp/fff-with-popup
             (lambda ()
               (consult--read '("notes.org" "chirp.go") :prompt "fff › ")))
          (quit nil))
      (cancel-timer quit-timer)
      (cancel-timer watchdog-timer)))
  (setq tsp/fff-ui-test--cancel-observation
        (append tsp/fff-ui-test--cancel-observation
                (list :child-frames-after
                      (cl-count-if
                       (lambda (frame) (frame-parameter frame 'parent-frame))
                       (frame-list)))))
  (ert-info ((format "FFF cancellation observation: %S"
                     tsp/fff-ui-test--cancel-observation))
    (should (plist-get tsp/fff-ui-test--cancel-observation :quit-sent))
    (should-not (plist-get tsp/fff-ui-test--cancel-observation
                           :stuck-after-quit))
    (should (zerop (plist-get tsp/fff-ui-test--cancel-observation
                              :child-frames-after)))))

(defun tsp/fff-ui-test-run ()
  "Run the FFF popup regression test and terminate Emacs."
  (let ((stats (ert-run-tests-batch "^tsp/fff-popup-")))
    (princ (format "input=%S cancel=%S unexpected=%s\n"
                   tsp/fff-ui-test--observation
                   tsp/fff-ui-test--cancel-observation
                   (ert-stats-completed-unexpected stats))
           'external-debugging-output)
    (kill-emacs (if (zerop (ert-stats-completed-unexpected stats)) 0 1))))

;;; fff-ui-test.el ends here
