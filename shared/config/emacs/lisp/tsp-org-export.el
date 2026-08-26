;;; tsp-org-export.el --- Org HTML export -*- lexical-binding: t; -*-
;;; Code:

;; This file is tangled from ../config.org. Edit that file instead.

(use-package htmlize
  :defer t)

(defconst tsp/org-html-style
  "<style>
:root {
  color-scheme: light;
  --page: #f6f7fb;
  --paper: #ffffff;
  --text: #172033;
  --muted: #667085;
  --accent: #087f8c;
  --accent-soft: #e7f6f7;
  --border: #dfe3eb;
  --code: #101827;
  --code-text: #e8edf6;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  padding: 3rem 1.25rem 5rem;
  background: var(--paper);
  color: var(--text);
  font: 17px/1.72 \"Karmina\", Georgia, Cambria, \"Times New Roman\", serif;
}
#content {
  max-width: 1100px;
  margin: 0 auto;
  padding: clamp(2rem, 5vw, 4.5rem);
}
h1, h2, h3, h4, h5, h6 {
  color: #101828;
  font-family: \"Karmina\", Georgia, Cambria, \"Times New Roman\", serif;
  line-height: 1.25;
}
h1 { margin-top: 0; font-size: clamp(2.2rem, 5vw, 3.2rem); }
h2 {
  margin-top: 2.8em;
  padding-bottom: .35em;
  border-bottom: 1px solid var(--border);
  font-size: 1.75rem;
}
h3 { margin-top: 2.2em; font-size: 1.35rem; }
p {
  width: 100%;
  margin: 1.15em 0;
  text-align: justify;
  text-justify: inter-word;
  hyphens: auto;
}
ul, ol { width: 100%; }
a { color: var(--accent); text-decoration-thickness: .08em; text-underline-offset: .16em; }
a:hover { color: #055f69; }
#table-of-contents {
  margin: 2rem 0 3rem;
  padding: 0;
}
#table-of-contents h2 {
  margin: 0 0 .8rem;
  padding: 0;
  border: 0;
  color: var(--text);
  font-size: 1.25rem;
  font-weight: 600;
}
#table-of-contents ul { margin: .2rem 0; padding-left: 1.4rem; }
#table-of-contents > div > ul { padding-left: 1.2rem; columns: 1; }
#table-of-contents li { margin: .15rem 0; }
#table-of-contents a { color: var(--text); text-decoration: none; }
#table-of-contents a:hover { color: var(--accent); text-decoration: underline; }
pre, code, kbd, samp {
  font-family: \"LythMono Nerd Font\", \"Iosevka\", \"JetBrains Mono\", ui-monospace, monospace;
}
code {
  padding: .12em .35em;
  border-radius: 5px;
  background: #edf1f6;
  font-size: .9em;
}
pre {
  width: 100%;
  max-width: 100%;
  margin: 1.6rem 0;
  padding: 1.4rem 1.55rem;
  overflow-x: auto;
  background: var(--code);
  color: var(--code-text);
  border: 1px solid #243047;
  font-size: 1rem;
  line-height: 1.65;
  tab-size: 4;
}
pre code { padding: 0; background: transparent; }
blockquote {
  margin: 1.8rem 0;
  padding: .25rem 1.25rem;
  color: #475467;
  border-left: 4px solid #98a2b3;
}
table { width: 100%; margin: 1.8rem 0; border-collapse: collapse; font-family: ui-sans-serif, system-ui, sans-serif; font-size: .94rem; }
th { background: #f1f4f8; text-align: left; }
th, td { padding: .7rem .85rem; border: 1px solid var(--border); }
img {
  display: block;
  width: 100%;
  max-width: 100%;
  height: auto;
}
.figure, .figure p { width: 100%; }
.title { margin-bottom: .25rem; }
.subtitle, .author, .date { color: var(--muted); font-family: ui-sans-serif, system-ui, sans-serif; }
.org-src-container { margin: 1.6rem 0; }
.org-src-container pre { margin: 0; }
#postamble { max-width: 1100px; margin: 1.5rem auto 0; color: var(--muted); text-align: center; font: .82rem/1.5 ui-sans-serif, system-ui, sans-serif; }
@media (max-width: 700px) {
  body { padding: 0; background: var(--paper); font-size: 16px; }
  #content { padding: 2rem 1.2rem 4rem; }
  #table-of-contents > div > ul { columns: 1; }
  pre { margin-left: -.4rem; margin-right: -.4rem; padding: 1rem; }
}
</style>"
  "Custom stylesheet included in standalone Org HTML exports.")

(defcustom tsp/org-export-directory
  (expand-file-name "exports/" tsp/org-directory)
  "Directory for ordinary Org export output.
Org publishing projects with an explicit publishing directory are unaffected."
  :type 'directory
  :group 'org-export)

(defun tsp/org-export-output-file-in-export-directory
    (original extension &optional subtreep publishing-directory)
  "Place ordinary export output from ORIGINAL in the export directory.
EXTENSION, SUBTREEP, and PUBLISHING-DIRECTORY are the arguments accepted by
`org-export-output-file-name'.  Preserve explicit publishing destinations."
  (let ((output (funcall original extension subtreep publishing-directory)))
    (if publishing-directory
        output
      (make-directory tsp/org-export-directory t)
      (expand-file-name (file-name-nondirectory output)
                        tsp/org-export-directory))))

(defun tsp/org-html-copy-local-image (output backend info)
  "Copy a local image in exported link OUTPUT and return its rewritten HTML.
BACKEND and INFO describe the current export.  Images are collected beneath
the export directory so moving HTML output away from its Org source does not
break them."
  (if (not (org-export-derived-backend-p backend 'html))
      output
    (replace-regexp-in-string
     "<img\\([^>]*?\\)src=\"\\([^\"]+\\)\""
     (lambda (match)
       (let* ((attributes (match-string 1 match))
              (url (match-string 2 match))
              (decoded (url-unhex-string
                        (string-remove-prefix "file://" url)))
              (input-file (plist-get info :input-file))
              (source (and (not (string-match-p "\\`\\(?:https?\\|data\\):" url))
                           (expand-file-name decoded
                                             (and input-file
                                                  (file-name-directory input-file))))))
         (if (not (and source
                       (file-regular-p source)
                       (string-match-p (image-file-name-regexp) source)))
             match
           (let* ((asset-directory
                   (expand-file-name "assets/" tsp/org-export-directory))
                  (name (file-name-nondirectory source))
                  (destination (expand-file-name name asset-directory)))
             (make-directory asset-directory t)
             (copy-file source destination t)
             (format "<img%ssrc=\"assets/%s\""
                     attributes
                     (url-hexify-string name))))))
     output t t)))

(advice-add 'org-export-output-file-name :around
            #'tsp/org-export-output-file-in-export-directory)

(provide 'tsp-org-export)
;;; tsp-org-export.el ends here
