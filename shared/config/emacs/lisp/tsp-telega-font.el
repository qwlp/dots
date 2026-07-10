;;; tsp-telega-font.el --- Telega font fixes -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(defvar telega-symbol-eliding)
(declare-function telega-window-string-width "telega-util")

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

(provide 'tsp-telega-font)
;;; tsp-telega-font.el ends here
