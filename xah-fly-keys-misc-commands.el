;; -*- coding: utf-8 -*-

(defun xah-next-user-buffer ()
  "Switch to the next user buffer.
 (buffer name does not start with “*”.)"
  (interactive)
  (next-buffer)
  (let ((i 0))
    (while (and (string-equal "*" (substring (buffer-name) 0 1)) (< i 20))
      (setq i (1+ i)) (next-buffer))))

(defun xah-previous-user-buffer ()
  "Switch to the previous user buffer.
 (buffer name does not start with “*”.)"
  (interactive)
  (previous-buffer)
  (let ((i 0))
    (while (and (string-equal "*" (substring (buffer-name) 0 1)) (< i 20))
      (setq i (1+ i)) (previous-buffer))))

(defun xah-next-emacs-buffer ()
  "Switch to the next emacs buffer.
 (buffer name that starts with “*”)"
  (interactive)
  (next-buffer)
  (let ((i 0))
    (while (and (not (string-equal "*" (substring (buffer-name) 0 1))) (< i 20))
      (setq i (1+ i)) (next-buffer))))

(defun xah-previous-emacs-buffer ()
  "Switch to the previous emacs buffer.
 (buffer name that starts with “*”)"
  (interactive)
  (previous-buffer)
  (let ((i 0))
    (while (and (not (string-equal "*" (substring (buffer-name) 0 1))) (< i 20))
      (setq i (1+ i)) (previous-buffer))))



(defvar xah-recently-closed-buffers nil "alist of recently closed buffers. Each element is (buffer name, file path). The max number to track is controlled by the variable `xah-recently-closed-buffers-max'.")

(defvar xah-recently-closed-buffers-max 40 "The maximum length for `xah-recently-closed-buffers'.")

(defun xah-close-current-buffer ()
  "Close the current buffer.

Similar to `kill-buffer', with the following addition:

• Prompt user to save if the buffer has been modified even if the buffer is not associated with a file.
• Make sure the buffer shown after closing is a user buffer.
• If the buffer is editing a source file in an org-mode file, prompt the user to save before closing.
• If the buffer is a file, add the path to the list `xah-recently-closed-buffers'.
• If it is the minibuffer, exit the minibuffer

A emacs buffer is one who's name starts with *.
Else it is a user buffer."
  (interactive)
  (let (ξemacs-buff-p
        (ξorg-p (string-match "^*Org Src" (buffer-name))))

    (setq ξemacs-buff-p (if (string-match "^*" (buffer-name)) t nil))

    (if (string= major-mode "minibuffer-inactive-mode")
        (minibuffer-keyboard-quit) ; if the buffer is minibuffer
      (progn
        ;; offer to save buffers that are non-empty and modified, even for non-file visiting buffer. (because kill-buffer does not offer to save buffers that are not associated with files)
        (when (and (buffer-modified-p)
                   (not ξemacs-buff-p)
                   (not (string-equal major-mode "dired-mode"))
                   (if (equal (buffer-file-name) nil)
                       (if (string-equal "" (save-restriction (widen) (buffer-string))) nil t)
                     t))
          (if (y-or-n-p (format "Buffer %s modified; Do you want to save? " (buffer-name)))
              (save-buffer)
            (set-buffer-modified-p nil)))
        (when (and (buffer-modified-p)
                   ξorg-p)
          (if (y-or-n-p (format "Buffer %s modified; Do you want to save? " (buffer-name)))
              (org-edit-src-save)
            (set-buffer-modified-p nil)))

        ;; save to a list of closed buffer
        (when (buffer-file-name)
          (setq xah-recently-closed-buffers
                (cons (cons (buffer-name) (buffer-file-name)) xah-recently-closed-buffers))
          (when (> (length xah-recently-closed-buffers) xah-recently-closed-buffers-max)
            (setq xah-recently-closed-buffers (butlast xah-recently-closed-buffers 1))))

        ;; close
        (kill-buffer (current-buffer))

        ;; if emacs buffer, switch to a user buffer
        (when (string-match "^*" (buffer-name))
          (next-buffer)
          (let ((i 0))
            (while (and (string-equal "*" (substring (buffer-name) 0 1)) (< i 20))
              (setq i (1+ i)) (next-buffer))))))))

(defun xah-open-last-closed ()
  "Open the last closed file."
  (interactive)
  (find-file (cdr (pop xah-recently-closed-buffers))))

(defun xah-open-recently-closed ()
  "Open recently closed file."
  (interactive)
  (find-file (ido-completing-read "open:" (mapcar (lambda (f) (cdr f)) xah-recently-closed-buffers))))

(defun xah-list-recently-closed ()
  "List recently closed file."
  (interactive)
  (let ((buf (generate-new-buffer "*recently closed*")))
    (switch-to-buffer buf)
    (mapc (lambda (f) (insert (cdr f) "\n"))
          xah-recently-closed-buffers)))

(defun xah-open-in-external-app (&optional φfile)
  "Open the current φfile or dired marked files in external app.

The app is chosen from your OS's preference."
  (interactive)
  (let ( ξdoIt
         (ξfileList
          (cond
           ((string-equal major-mode "dired-mode") (dired-get-marked-files))
           ((not φfile) (list (buffer-file-name)))
           (φfile (list φfile)))))

    (setq ξdoIt (if (<= (length ξfileList) 5)
                    t
                  (y-or-n-p "Open more than 5 files? ")))

    (when ξdoIt
      (cond
       ((string-equal system-type "windows-nt")
        (mapc (lambda (fPath) (w32-shell-execute "open" (replace-regexp-in-string "/" "\\" fPath t t))) ξfileList))
       ((string-equal system-type "darwin")
        (mapc (lambda (fPath) (shell-command (format "open \"%s\"" fPath)))  ξfileList))
       ((string-equal system-type "gnu/linux")
        (mapc (lambda (fPath) (let ((process-connection-type nil)) (start-process "" nil "xdg-open" fPath))) ξfileList))))))

(defun xah-open-in-desktop ()
  "Show current file in desktop (OS's file manager)."
  (interactive)
  (cond
   ((string-equal system-type "windows-nt")
    (w32-shell-execute "explore" (replace-regexp-in-string "/" "\\" default-directory t t)))
   ((string-equal system-type "darwin") (shell-command "open ."))
   ((string-equal system-type "gnu/linux")
    (let ((process-connection-type nil)) (start-process "" nil "xdg-open" "."))
    ;; (shell-command "xdg-open .") ;; 2013-02-10 this sometimes froze emacs till the folder is closed. ⁖ with nautilus
    )))

(defun xah-new-empty-buffer ()
  "Open a new empty buffer."
  (interactive)
  (let ((buf (generate-new-buffer "untitled")))
    (switch-to-buffer buf)
    (funcall (and initial-major-mode))
    (setq buffer-offer-save t)))
;; note: emacs won't offer to save a buffer that's
;; not associated with a file,
;; even if buffer-modified-p is true.
;; One work around is to define your own my-kill-buffer function
;; that wraps around kill-buffer, and check on the buffer modification
;; status to offer save
;; This custome kill buffer is close-current-buffer.

(defun xah-open-file-at-cursor ()
  "Open the file path under cursor.
If there is text selection, uses the text selection for path.
If the path starts with “http://”, open the URL in browser.
Input path can be {relative, full path, URL}.
Path may have a trailing “:‹n›” that indicates line number. If so, jump to that line number.
If path does not have a file extention, automatically try with “.el” for elisp files.
This command is similar to `find-file-at-point' but without prompting for confirmation.

URL `http://ergoemacs.org/emacs/emacs_open_file_path_fast.html'"
  (interactive)
  (let ((ξpath (if (use-region-p)
                   (buffer-substring-no-properties (region-beginning) (region-end))
                 (let (p0 p1 p2)
                   (setq p0 (point))
                   ;; chars that are likely to be delimiters of full path, e.g. space, tabs, brakets.
                   (skip-chars-backward "^  \"\t\n'|()[]{}<>〔〕“”〈〉《》【】〖〗«»‹›·。\\`")
                   (setq p1 (point))
                   (goto-char p0)
                   (skip-chars-forward "^  \"\t\n'|()[]{}<>〔〕“”〈〉《》【】〖〗«»‹›·。\\'")
                   (setq p2 (point))
                   (goto-char p0)
                   (buffer-substring-no-properties p1 p2)))))
    (if (string-match-p "\\`https?://" ξpath)
        (browse-url ξpath)
      (progn ; not starting “http://”
        (if (string-match "^\\`\\(.+?\\):\\([0-9]+\\)\\'" ξpath)
            (progn
              (let (
                    (ξfpath (match-string 1 ξpath))
                    (ξline-num (string-to-number (match-string 2 ξpath))))
                (if (file-exists-p ξfpath)
                    (progn
                      (find-file ξfpath)
                      (goto-char 1)
                      (forward-line (1- ξline-num)))
                  (progn
                    (when (y-or-n-p (format "file doesn't exist: 「%s」. Create?" ξfpath))
                      (find-file ξfpath))))))
          (progn
            (if (file-exists-p ξpath)
                (find-file ξpath)
              (if (file-exists-p (concat ξpath ".el"))
                  (find-file (concat ξpath ".el"))
                (when (y-or-n-p (format "file doesn't exist: 「%s」. Create?" ξpath))
                  (find-file ξpath ))))))))))

(defun xah-open-file-path-under-cursor ()
  "Open the file path under cursor.
If there is text selection, use the text selection for path.
If path starts with “http://”, launch browser vistiting that URL, or open the corresponding file, if it's xah site.

Input path can be {relative, full path, URL}. See: `xahsite-web-path-to-filepath' for types of paths supported."
  (interactive)
  (let (
        (ξs
         (xah-remove-uri-fragment
          (if (use-region-p)
              (buffer-substring-no-properties (region-beginning) (region-end))
            (let (p0 p1 p2)
              (setq p0 (point))
              ;; chars that are likely to be delimiters of full path, e.g. space, tabs, brakets.
              (skip-chars-backward "^  \"\t\n'|()[]{}<>〔〕“”〈〉《》【】〖〗«»‹›·。\\`")
              (setq p1 (point))
              (goto-char p0)
              (skip-chars-forward "^  \"\t\n'|()[]{}<>〔〕“”〈〉《》【】〖〗«»‹›·。\\'")
              (setq p2 (point))
              (goto-char p0)
              (buffer-substring-no-properties p1 p2)))))
        fPath )

    (if (string-equal ξs "")
        (progn (message "No path under cursor"))
      (progn

        ;; convenience. if the input string start with a xah domain name, make it a url string
        (setq ξp
              (cond
               ((string-match "\\`//" ξs ) (concat "http:" ξs)) ; relative http protocol, used in css
               ((string-match "\\`ergoemacs\\.org" ξs ) (concat "http://" ξs))
               ((string-match "\\`wordyenglish\\.com" ξs ) (concat "http://" ξs))
               ((string-match "\\`xaharts\\.org" ξs ) (concat "http://" ξs))
               ((string-match "\\`xahlee\\.info" ξs ) (concat "http://" ξs))
               ((string-match "\\`xahlee\\.org" ξs ) (concat "http://" ξs))
               ((string-match "\\`xahmusic\\.org" ξs ) (concat "http://" ξs))
               ((string-match "\\`xahporn\\.org" ξs ) (concat "http://" ξs))
               ((string-match "\\`xahsl\\.org" ξs ) (concat "http://" ξs))
               (t ξs)))

        (if (string-match-p "\\`https?://" ξp)
            (if (xahsite-url-is-xah-website-p ξp)
                (let ((ξfp (xahsite-url-to-filepath ξp )))
                  (if (file-exists-p ξfp)
                      (find-file ξfp)
                    (when (y-or-n-p (format "file doesn't exist: 「%s」. Create?" ξfp)) (find-file ξfp))))
              (browse-url ξp))
          (progn ; not starting “http://”
            (let ((ξfff (xahsite-web-path-to-filepath ξp default-directory)))
              (if (file-exists-p ξfff)
                  (progn (find-file ξfff))
                (if (file-exists-p (concat ξfff ".el"))
                    (progn (find-file (concat ξfff ".el")))
                  (when (y-or-n-p (format "file doesn't exist: 「%s」. Create?" ξfff)) (find-file ξfff )))))))))))

(defun xah-open-file-from-clipboard ()
  "Open the file path from OS's clipboard.
The clipboard should contain a file path or url to xah site. Open that file in emacs."
  (interactive)
  (let (
        (ξs
         (with-temp-buffer
           (yank)
           (buffer-string)))
        fpath
        )

    (if (string-match-p "\\`http://" ξs)
        (progn
          (setq fpath (xahsite-url-to-filepath ξs "addFileName"))
          (if (file-exists-p fpath)
              (progn (find-file fpath))
            (progn (error "file doesn't exist 「%s」" fpath))))
      (progn ; not starting “http://”
        (setq ξs (xah-remove-uri-fragment ξs))
        (setq fpath (xahsite-web-path-to-filepath ξs default-directory))
        (if (file-exists-p fpath)
            (progn (find-file fpath))
          (progn (user-error "file doesn't exist 「%s」" fpath)))))))

(defun xah-browse-url-at-point ()
"Switch to web browser and load the URL at cursor position.
This code is designed to work on Mac OS X only.

If the cursor is on a URL, visit it
http://mathforum.org/library/topics/conic_g/
for certain domain, use particular browser.

If the cursor is on like one of the following
 /somedir/somefile.html or
~/web/somedir/somefile.html
use FireFox to visit it as local file (construct the proper URL)."
 (interactive)
 (let ((myStr (elt (get-selection-or-unit 'url) 0) ))
 (setq myStr (replace-regexp-in-string "&amp;" "&" myStr))

   ;; on Mac, map specific links to particular browser
   ;; (cond
   ;;  ((string-match "flickr.com/" myStr) (shell-command (concat "open -a safari " "\"" myStr "\"")))
   ;;  ((string-match "blogspot.com/" myStr) (shell-command (concat "open -a safari " "\"" myStr "\"")))
   ;;  ((string-match "livejournal.com/" myStr) (shell-command (concat "open -a safari " "\"" myStr "\"")))
   ;;  ((string-match "yahoo.com/" myStr) (shell-command (concat "open -a safari " "\"" myStr "\"")))
   ;;  (t (browse-url myStr)))

   (browse-url myStr)
   ))
