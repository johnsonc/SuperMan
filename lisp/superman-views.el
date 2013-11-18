;;; superman-views.el --- Superman views of project contents 

;; Copyright (C) 2012-2013 Thomas Alexander Gerds, Klaus Kaehler Holst

;; Authors: Thomas Alexander Gerds <tag@biostat.ku.dk>
;;          Klaus Kaehler Holst <kkho@biostat.ku.dk>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Code:

;;{{{ Variables

(defvar superman-column-separator 2 "Number of characters between columns")

(defvar superman-hl-line nil "Set to non-nil in order to
highlight the current line in superman views.")

(defvar superman-view-current-project nil "Buffer local project variable" )
(make-variable-buffer-local 'superman-view-current-project)

(defvar superman-view-marks nil "Marks for items in agenda.")
(make-variable-buffer-local 'superman-view-marks)



(defvar superman-mark-face 'bold  "Face name for marked entries in the view buffers.")

(defvar superman-cats '(("Meetings" . "Date")
			("Documents" . "FileName")
			("Data" . "DataFileName")
			("Notes" . "NoteDate")
			("Tasks" . "TaskDate")
			("Mail" . "EmailDate")
			("Bookmarks" . "BookmarkDate"))
  "Alist of the form ((cat.1 . term.1)(cat.2 . term.2) ...)  where cat.i
refers to the ith bloke in the project view and term.i identifies
headlines in the project index file to be shown in that bloke.")

(setq superman-views-delete-empty-cats t)
(setq superman-views-permanent-cats '("Documents"))
(setq superman-cat-headers
      '(("Documents" . superman-documents-view-header)))


(defvar superman-document-category-separator '32 "Symbol for separating categories in document views.
See `org-agenda-block-separator'. Set to '0 to get a funny line.
Can also be set to (string-to-char \"~\") with any string in place of ~.")

(defvar superman-finalize-cat-alist nil

  "List of functions and variables used to finalize superman-views.

Elements are of the form '(cat fun balls) where cat is the name
of the heading in which the function fun is applied with arguments given by
balls.

A ball is a special list:

 (key (\"width\" number) (\"fun\" trim-function) (\"args\" trim-argument-list) (\"face\" face-or-fun) (\"name\" string) (required t-or-nil))

Examples:

Column showing a property 

 (\"Prop\" (\"fun\" superman-trim-string) (\"width\" 17) (\"face\" font-lock-function-name-face) (\"name\" \"Prop\") (required nil))

Column showing the header

 (hdr (\"fun\" superman-trim-string) (\"name\" Description))

Column showing the todo-state 

 (todo (\"face\" superman-get-todo-face))

")

(setq superman-finalize-cat-alist
      '(("Documents" superman-document-balls)
	("Data" superman-data-balls)
	("Notes" superman-note-balls)
	("Mail" superman-mail-balls)
	("Tasks" superman-task-balls)
	("Bookmarks" superman-bookmark-balls)
	("Meetings" superman-meeting-balls)
	("GitFiles" superman-document-balls)))

;; (list "Description" "GitStatus" "LastCommit" "FileName"))
(defun superman-dont-trim (x len) x)
(setq superman-document-balls
      '((hdr ("width" 23) ("face" font-lock-function-name-face) ("name" "Description"))
	;; ("GitStatus" ("width" 10) ("face" superman-get-git-status-face))
	;; ("LastCommit" ("fun" superman-trim-date) ("face" font-lock-string-face))
	("FileName" ("fun" superman-dont-trim))))

(setq superman-default-balls
      '((todo ("width" 6) ("face" superman-get-todo-face))
	(hdr ("width" 23) ("face" font-lock-function-name-face))
	("Date" ("fun" superman-trim-date) ("face" font-lock-string-face))))

(setq superman-meeting-balls
      '((hdr ("width" 23) ("face" font-lock-function-name-face))
	("Date" ("fun" superman-trim-date) ("face" font-lock-string-face))
	("Participants" ("width" 23))))
(setq superman-note-balls
      '((todo ("width" 7) ("face" superman-get-todo-face))
	("NoteDate" ("fun" superman-trim-date) ("width" 13) ("face" font-lock-string-face))
	(hdr ("width" 49) ("face" font-lock-function-name-face))))
(setq superman-data-balls
      '(("CaptureDate" ("fun" superman-trim-date) ("width" 13) ("face" font-lock-string-face))
	(hdr ("width" 23) ("face" font-lock-function-name-face))
	("DataFileName" ("fun" superman-dont-trim))))
(setq superman-task-balls
      '((todo ("width" 7) ("face" superman-get-todo-face))
	("TaskDate" ("fun" superman-trim-date) ("width" 13) ("face" font-lock-string-face))
	(hdr ("width" 49) ("face" font-lock-function-name-face))))
(setq superman-bookmark-balls
      '(("BookmarkDate" ("fun" superman-trim-date) ("width" 13) ("face" font-lock-string-face))
	(hdr ("face" font-lock-function-name-face) ("name" "Description") ("width" 45))
	("Link" ("fun" superman-trim-link) ("width" 48) ("name" "Bookmark"))))
(setq superman-mail-balls
      '((todo ("width" 7) ("face" superman-get-todo-face))
	("EmailDate" ("fun" superman-trim-date) ("width" 13) ("face" font-lock-string-face))
	(hdr ("width" 23) ("face" font-lock-function-name-face))
	("Link" ("fun" superman-trim-bracketed-filename) ("width" 48))
	(attac ("Link" ("fun" superman-trim-bracketed-filename) ("width" full)))))

;;}}}
;;{{{ faces
;; FIXME
;;}}}
;;{{{ Trim stuff and frequently used funs

(defun superman-trim-string (str &rest args)
  "Trim string STR to a given length by either calling substring
or by adding whitespace characters. The length is stored in the first
element of the list ARGS. If length is a string which cannot be converted
to an integer then do not trim the string STR."
  (let* ((slen (length str))
	 (len (car args))
	 (numlen (cond
		  ((integerp len) len)
		  ((eq len 'full) "full")
		  ((stringp len)
		     (setq len (string-to-int len))
		     (if (< len 1) 13 len))
		  (t 13)))
	 (diff (unless (eq len 'full) (- numlen slen))))
    (if diff
	(if (> diff 0)
	    (concat str (make-string diff (string-to-char " ")))
	  (substring str 0 numlen))
      str)))

(defun superman-trim-link (link &rest args)
  ;;  Bracket links
  (if (string-match org-bracket-link-regexp link)
      (let* ((rawlink (org-match-string-no-properties 1 link))
	     (len (car args))
	     tlink)
	(if (match-end 3)
	    (setq tlink
		  (replace-match
		   (superman-trim-string
		    (org-match-string-no-properties 3 link) len)
		   t t link 3))
	  (setq tlink (org-make-link-string
		       rawlink
		       (superman-trim-string "link" len))))
	tlink)
    ;; plainlinks
    (let* ((len (car args)))
      (if (string-match org-link-re-with-space link)
	  (concat "[[" link "]["
		  (superman-trim-string link len) "]]")
	link))))

(defun superman-trim-bracketed-filename (file &rest args)
  ;;  Links to files
  (if (string-match org-bracket-link-regexp file)
      (let ((filename (org-match-string-no-properties 1 file))
	    (len (car args))
	    (match (match-end 3))
	    (match-string (org-match-string-no-properties 3 file))
	    trimmed-file-name)
	(if match
	    (setq trimmed-file-name
		  (replace-match
		   (superman-trim-string
		    match-string len)
		   t t file 3))
	  (setq trimmed-file-name
		(org-make-link-string
		 filename
		 (superman-trim-string
		  (file-name-nondirectory filename) len))))
	trimmed-file-name)
    (superman-trim-string file (car args))))

(defun superman-trim-filename (filename &rest args)
  ;;  raw filenames
  (let ((linkname (file-name-nondirectory filename))
	(len (car args)))
    (when (string= linkname "") ;; for directories show the mother
      (setq linkname (file-name-nondirectory (directory-file-name filename))))
    (org-make-link-string
     filename
     (superman-trim-string linkname len))))

(defun superman-get-git-status-face (str)
  (cond ((string-match "Committed" str ) 'font-lock-type-face)
	((string-match  "Modified" str) 'font-lock-warning-face)
	(t 'font-lock-comment-face)))

(defun superman-trim-date (date &optional len)
  (let ((len (if (stringp len) (length len) len))
	date-string)
    (if (< len 1) (setq len 13))
    (if (string-match org-ts-regexp0 date)
	(let* ((days (org-time-stamp-to-now date)))
	  (cond ((= days 0)
		 (setq date "today"))
		((= days 1)
		 (setq date "yesterday"))
		((> days 0)
		 (setq date (concat "in " (int-to-string days) " days")))
		(t (setq date (concat (int-to-string (abs days)) " days ago"))))
	  (setq date-string (superman-trim-string date len))
	  (put-text-property 0 (length date-string) 'sort-key (abs days) date-string))
      (setq date-string (superman-trim-string date len))
      (put-text-property 0 (length date-string) 'sort-key 0 date-string))
    date-string))

(defun superman-view-current-project (&optional no-error)
  "Identifies the project associated with the current view buffer
and sets the variable superman-view-current-project."
  (let* ((nick (get-text-property (point-min) 'nickname))
	(pro (when nick (assoc nick superman-project-alist))))
    (if pro
	(setq superman-view-current-project pro)
      (unless no-error
	(error "Malformed header of project view buffer: cannot identify project")))))

(defun superman-view-control (project)
  "Insert the git repository if project is git controlled
and the keybinding to initialize git control otherwise."
  (let* ((loc (get-text-property (point-min) 'git-dir))
	 (button (superman-make-button "Contrl:"
				       ;; 'superman-view-git-status
				       'superman-add-git-cycle
				       'superman-header-button-face
				       "Show git status"))
	 (control (if (superman-git-p loc)
		      (let ((git-dir-link (concat "[[" (abbreviate-file-name (superman-git-toplevel loc)) "]]")))
			(put-text-property 0 1 'superman-header-marker t git-dir-link)
			(concat "Git repository at "
				;;FIXME: would like to have current git status as well
				git-dir-link))
		    "not set. <> press `GI' to initialize git control")))
    ;; (put-text-property 0 (length "Contrl: ") 'face 'org-level-2 control)
    (put-text-property 0 1 'superman-header-marker t button)
    (concat button " " control)))

(defun superman-view-others (project)
  "Insert the names and emails of the others (if any)." 
  (let ((pro (or project (superman-view-current-project)))
	(others (superman-get-others pro)))
    (if others
	(let ((key
	       (superman-make-button
		"Others:"
		`(lambda ()
		   (interactive)
		   (superman-capture-others
		    ,(car pro)))
		'superman-header-button-face
		"Set names of collaborators")))
	  ;; (put-text-property 0 (length key) 'face 'org-level-2 key)
	  (put-text-property 0 1 'superman-header-marker t key)
	  (concat key " " others "\n"))
      "")))



(defun superman-current-cat ()
  (let ((cat-point (superman-cat-point)))
    (when cat-point
      (get-text-property cat-point 'cat))))

(defun superman-current-subcat ()
  (let* ((cat-pos (superman-cat-point))
	 (subcat-pos (superman-subcat-point))
	 (subp (and subcat-pos (> subcat-pos cat-pos))))
    (when cat-pos
      (get-text-property
       (if subp subcat-pos cat-pos)
       (if subp 'subcat 'cat)))))

(defun superman-current-subcat-pos ()
  (let* ((cat-pos (superman-cat-point))
	 (subcat-pos (superman-subcat-point))
	 (subp (and subcat-pos (> subcat-pos cat-pos))))
    (when cat-pos
      (if subp subcat-pos cat-pos))))

;;}}}
;;{{{ window configuration

(defun superman-view-read-config (project)
  (let (configs
	(case-fold-search t))
    (save-window-excursion
      (when (superman-goto-project project "Configuration" nil nil 'narrow nil)
	  (goto-char (point-min))
	  (while (outline-next-heading)
	    (let ((config (or (superman-get-property (point) "Config")
			      (cdr (assoc
				    (downcase
				     (or (org-get-heading t t) "Untitled"))
				     superman-config-alist))))
		  (hdr (or (org-get-heading t t) "NoHeading")))
	      (when config 
		(setq
		 configs
		 (append
		  configs
		  (list (cons hdr config)))))))
	  (widen)))
      configs))

;; (defun supermanual ()
;;   (interactive)
;;   (find-file superman-manual))
(defun supermanual (&optional project)
  (interactive)
  (find-file supermanual))

(defun superman-view-insert-project-buttons ()
  "Insert project buttons"
  (if (> (length superman-project-history) 1)
      (let* ((prev (car (reverse superman-project-history)))
	     (next (cadr superman-project-history))
	     (all-button (superman-make-button "Projects" 'superman 'superman-next-project-button-face "List of projects"))
	     (next-button (superman-make-button
			   next
			   `(lambda () (interactive) (superman-switch-to-project ,next))
			   'superman-next-project-button-face
			   (concat "Switch to project " next)))
	     (prev-button (superman-make-button
			   prev
			   `(lambda () (interactive) (superman-switch-to-project ,prev))
			   'superman-next-project-button-face
			   (concat "Switch to project " prev))))
	(put-text-property 0 1 'superman-header-marker t prev-button)
	(put-text-property 0 1 'superman-header-marker t next-button)
	(put-text-property 0 1 'superman-header-marker t all-button)
	(insert "\t\tPrev: " prev-button "\tNext: " next-button "\tAll:" all-button))
    (insert "\t\t" (superman-make-button "Projects" 'superman 'superman-next-project-button-face "List of projects"))))

(defvar superman-default-action-buttons '(("Document" . superman-capture-document)
		("Task" . superman-capture-task)
		("Note" . superman-capture-note)
		("Bookmark" . superman-capture-bookmark)
		("Meeting" . superman-capture-meeting)))

(defun superman-view-insert-action-buttons (&optional button-list no-newline)
  "Insert capture buttons. BUTTON-LIST is a alist of button labels and functions 
which there is a function `superman-capture-n'. If omitted, it is set to
  '((\"Document\" 'superman-capture-document)
    (\"Task\" 'superman-capture-task)
    (\"Note\" 'superman-capture-note)
    (\"Bookmark\" 'superman-capture-bookmark)
    (\"Meeting\" 'superman-capture-meeting))
"
  (let* ((title
	  (superman-make-button
	   "Action:"
	   'superman-capture-unison
	   'superman-header-button-face
	   "Action buttons"))
	 ;; (capture-alist superman-capture-alist)
	 (b-list
	  (or button-list superman-default-action-buttons))
	 (i 1))
    (while b-list
      (let* ((b (car b-list))
	     ;; (b-name (substring b 0 1))
	     (b-name (car b))
	     (b-tail (cdr b))
	     (fun (if (and (listp b-tail) (not (functionp b-tail))) (car b-tail) b-tail))
	     (cmd (cond ((functionp fun) fun)
			((stringp fun) (intern fun))
			;; (intern (concat "superman-capture-" (downcase b-name)))))
			(t 'superman-capture-item)))
	     (map (make-sparse-keymap)))
	(define-key map [mouse-2] `(lambda () (interactive) (,cmd)))
	(define-key map [return]  `(lambda () (interactive) (,cmd)))
	(define-key map [follow-link]  `(lambda () (interactive) (,cmd)))
	(when (= i 1)
	  (unless no-newline
	    (insert "\n"))
	  (insert title " "))
	(put-text-property
	 0 1
	 'superman-header-marker t b-name)
	(add-text-properties
	 0 (length b-name) 
	 (list
	  'button (list t)
	  'face 'superman-capture-button-face
	  'keymap map
	  'mouse-face 'highlight
	  'follow-link t
	  'help-echo (concat "capture " (downcase b-name)))
	 b-name)
	(insert "" b-name " "))
      (setq i (+ i 1) b-list (cdr b-list)))))

(defun superman-view-insert-config-buttons (project)
  "Insert window configuration buttons"
  (let* ((pro (or project superman-current-project
		  (superman-select-project)))
	 (title
	  (superman-make-button
	   "View-S:"
	   'superman-capture-config
	   'superman-header-button-face
	   "Capture current window configuration"))
	 (config-list (superman-view-read-config pro))
	 (title-marker 
	  (save-excursion
	    (superman-goto-project project "Configuration" nil nil 'narrow nil)
	    (goto-char (point-min))
	    (point-marker)))
	 (i 1))
    (put-text-property 0 (length title) 'superman-e-marker title-marker title)
    (put-text-property 0 1 'superman-header-marker t title)
    (while config-list
      (let* ((current-config (car config-list))
	     (config-name (car current-config))
	     (config-cmd (cdr current-config)))
	(when (= i 1)
	  (insert "\n")
	  (insert title " "))
	(put-text-property
	 0 1
	 'superman-header-marker t config-name)
	(insert "[" (superman-make-button config-name
					  `(lambda () (interactive)
					     (superman-switch-config nil nil ,config-cmd))
					  'font-lock-warning-face
					  config-cmd)
		"]  "))
      (setq i (+ i 1) config-list (cdr config-list)))))

;;}}}
;;{{{ unison
(defun superman-view-read-unison (project)
  (let (unisons)
    (save-window-excursion
      (when (superman-goto-project project "Configuration" nil nil t nil)
	;; (org-narrow-to-subtree)
	(goto-char (point-min))
	(while (re-search-forward ":UNISON:" nil t)
	  (org-back-to-heading t)
	  (let ((hdr (progn 
		       (looking-at org-complex-heading-regexp)
		       (or (match-string-no-properties 4) "Untitled")))
		(unison-cmd (superman-get-property (point) "UNISON")))
	    (when (string= unison-cmd "superman-unison-cmd")
	      (setq unison-cmd superman-unison-cmd))
	    (setq
	     unisons
	     (append
	      unisons
	      (list (cons hdr
			  (concat
			   unison-cmd
			   " "
			   (superman-get-property (point) "ROOT-1")
			   " "
			   (superman-get-property (point) "ROOT-2")
			   " "
			   (if (string= (superman-get-property (point) "SWITCHES") "default")
			       superman-unison-switches
			     (superman-get-property (point) "SWITCHES"))))))))
	  (outline-next-heading))
	(widen)))
    unisons))

(defun superman-view-insert-unison-buttons (project)
  "Insert unison buttons"
  (let* ((pro (or project superman-current-project
		  (superman-select-project)))
	 (title
	  (superman-make-button
	   "Unison:"
	   'superman-capture-unison
	   'superman-header-button-face
	   "Capture unison"
	   ))
	 (title-marker 
	  (save-excursion
	    (superman-goto-project project "Configuration" nil nil 'narrow nil)
	    (goto-char (point-min))
	    (point-marker)))
	 (unison-list (superman-view-read-unison pro))
	 (i 1))
    (put-text-property 0 (length title) 'superman-e-marker title-marker title)
    (put-text-property 0 1 'superman-header-marker t title)
    (while unison-list
      (let* ((current-unison (car unison-list))
	     (unison-name (car current-unison))
	     (unison-cmd (cdr current-unison)))
	(when (= i 1)
	  (insert "\n")
	  (insert title " "))
	(put-text-property
	 0 1
	 'superman-header-marker t unison-name)
	(insert "["
		(superman-make-button
		 unison-name 
		 `(lambda () (interactive)
		    (async-shell-command ,unison-cmd))
		 'font-lock-warning-face
		unison-name) "] "))
      (setq i (+ i 1) unison-list (cdr unison-list)))))

;;}}}
;;{{{ superman-buttons

;; (defun superman-call-button-function (button)
  ;; (interactive)
  ;; (callf (button-get button 'fun)))
  ;; (let ((win (get-buffer-window (button-get button 'buffer)))
	;; (cur-win (get-buffer-window (current-buffer))))
    ;; (select-window cur-win)
    ;; (if win
	;; (progn
	  ;; (select-window win)
	  ;; (goto-char (button-get button 'point)))))
  ;; (callf (button-get button 'fun)))

;; (insert (superman-make-button "bla" 'test))

(defun test ()
  (interactive)
  (message "hi" ))


;; (defun superman-with-point-at-mouse (event)
  ;; (set-buffer (window-buffer (posn-window event))
	      ;; (goto-char (posn-point event))
	      ;; (message (concat (buffer-name) (int-to-string (point))))))

(defun superman-make-button (string &optional fun face help)
  "Create a button with label STRING and FACE.
 If FUN is a function then it is bound to mouse-2 and RETURN events.  
 HELP is shown when the mouse over the button."
  (let ((map (make-sparse-keymap))
	;; (pfun `(lambda (&rest ignore) (funcall ',fun)))
	(help (or help "Superman-button")))
    (when (functionp fun)
      (define-key map [return] fun)
      (define-key map [mouse-2] `(lambda ()
				   (interactive)
				   ;; switch to the proper window/buffer
				   (let* ((pos last-command-event)
					  (posn (event-start pos)))
				     (with-current-buffer (window-buffer (posn-window posn))
				       (goto-char (posn-point posn))
				       (message (concat (buffer-name) (int-to-string (point))))
				       (funcall ',fun))))))
    ;; (when keys
    ;; (while keys
    ;; (define-key map (caar keys) (cdar keys))
    ;; (setq keys (cdr keys))))
    ;; (set-text-properties 0 (length string) nil string)
    (add-text-properties
     0 (length string) 
     (list
      'button (list t)
      ;; 'keymap (mouse-2 . push-button)
      ;; (13 . push-button))
      'category 'default-button
      'face (or face 'superman-default-button-face)
      'keymap map
      'superman-header-marker t
      ;; 'action fun
      ;; 'mouse-action pfun
      'mouse-face 'highlight
      'follow-link t
      'help-echo help)
     string)
    string))

  
;;}}}
;;{{{ git branches and remote

(defun superman-view-insert-git-branches (&optional dir)
  "Insert the git branch(es) if project is git controlled.
Translate the branch names into buttons."
  (let ((loc (or dir
		 (get-text-property (point-min) 'git-dir)))
	(view-buf (current-buffer)))
    (let* ((branch-list (delq nil (superman-git-branches loc)))
	   (current-branch (car branch-list))
	   (remote (car (member-if
			 (lambda (x)
			   (string-match "^remotes/" x)) branch-list)))
	   (other-branches (cdr branch-list))
	   (title "Branch:"))
      (when remote 
	;; (setq other-branches (delete remote other-branches)))
	(setq other-branches (delete-if (lambda (x) (string-match "remotes/" x)) other-branches)))
      (insert "\n")
      (put-text-property 0 (length title) 'face 'org-level-2 title)
      (put-text-property 0 (length title) 'superman-header-marker t title)
      (insert
       (superman-make-button
	title
	'superman-git-new-branch
	'superman-header-button-face
	"Create new git branch")
       " ")
      (put-text-property
       0 1
       'superman-header-marker t current-branch)
      (superman-make-button
       current-branch
       'superman-view-git-status
       'font-lock-warning-face
       "View git status")
      (insert "[" current-branch "]  ")
      (while other-branches
	(let* ((b (car other-branches))
	       (fun
		`(lambda ()
		   (interactive)
		   (superman-run-cmd
		    ,(concat "cd " loc "; "
			     superman-cmd-git " checkout " b "\n")
		    "*Superman-returns*"
		    nil
		    ,(buffer-name view-buf))))
	       (button
		(superman-make-button
		 b
		 fun
		 'font-lock-comment-face
		 "Checkout branch")))
	  (setq other-branches (cdr other-branches))
	  (put-text-property 0 1 'superman-header-marker t button)
	  (insert "[" button "]  ")))
      (when (> (length other-branches) 0)
	(let ((merge-string "-> merge"))
	  (put-text-property 0 1 'superman-header-marker t merge-string)	    
	  (insert (superman-make-button
		   merge-string
		   `(lambda () (interactive)
		      (superman-git-merge-branches ,loc))
		   'font-lock-type-face
		   "Merge two branches"))))
      (when remote
	(let* ((title "Remote:")
	       (svn-p (string-match "svn" remote))
	       (pull-string (if svn-p "rebase" "[pull]"))
	       (push-string (if svn-p "dcommit" "[push]"))
	       (pull-cmd (if svn-p "svn rebase" "pull"))
	       (push-cmd (if svn-p "svn dcommit" "push"))
	       (remote-cmd (if svn-p "svn fetch" "remote show origin")))
	  ;; git diff --name-status remotes/git-svn
	  (put-text-property 0 1 'superman-header-marker t title)
	  (put-text-property 0 1 'superman-header-marker t pull-string)
	  (put-text-property 0 1 'superman-header-marker t push-string)
	  (insert "\n"
		  (superman-make-button
		   title
		   `(lambda () (interactive) (superman-run-cmd
					      (concat "cd " ,loc ";" ,superman-cmd-git " " ,remote-cmd "\n")
					      "*Superman-returns*"
					      (concat "`" ,superman-cmd-git " " ,remote-cmd " run below \n" ,loc "' returns:\n\n")))
		   'superman-header-button-face
		   "Fetch origin of remote repository")
		  " "
		  (superman-make-button
		   pull-string
		   `(lambda () (interactive)
		      (superman-run-cmd (concat "cd " ,loc  ";" ,superman-cmd-git " " ,pull-cmd "\n")
					"*Superman-returns*"
					(concat "`" ,superman-cmd-git " " ,pull-cmd "' run below \n" ,loc "' returns:\n\n")))
		   'font-lock-type-face
		   "Pull changes from remote repository")
		  " "
		  (superman-make-button
		   push-string
		   `(lambda () (interactive)
		      (superman-run-cmd (concat "cd " ,loc  ";" ,superman-cmd-git " " ,push-cmd "\n")
					"*Superman-returns*"
					(concat "`" ,superman-cmd-git " " ,push-cmd "' run below \n" ,loc "' returns:\n\n")))
		   'font-lock-type-face
		   "Push changes to remote repository")))))))


;;}}}
;;{{{ Marking elements

(defun superman-toggle-mark (&optional on)
  "Toggle mark for item at point in project view.
If ON is non-nil keep mark for already marked items.
If DONT-MOVE is non-nil stay at item."
  (interactive)
  (when (get-text-property (point-at-bol) 'org-marker)
    (if (org-agenda-bulk-marked-p)
	(unless on (org-agenda-bulk-unmark))
      (org-agenda-bulk-mark))))

(defun superman-view-mark-all (&optional arg)
  (interactive "P")
  arg
  (save-excursion
    (save-restriction
      (org-narrow-to-subtree)
      (superman-loop 'superman-toggle-mark
		     (list (if arg nil 'on))))))

(defun superman-view-invert-marks (&optional arg)
  (interactive "P")
  arg
  (save-excursion
    (save-restriction
      (org-narrow-to-subtree)
      (superman-loop 'superman-toggle-mark
		     (list arg)))))



(defun superman-marked-p ()
  (org-agenda-bulk-marked-p))

;;}}}
;;{{{ Loops

(defun superman-loop (fun args &optional begin end marked)
  "Call function FUN on all items in the range BEGIN to END and return
the list of results.

If MARKED is non-nil run only on marked items."

  (let (loop-out
	(begin (or begin (point-min)))
	(end (or end (point-max)))
	next)
    (save-restriction
      (narrow-to-region begin end)
      (save-excursion
	(goto-char (point-min))
	(while (setq next (next-single-property-change
			   (point-at-eol) 'org-marker))
	  (goto-char next)
	  (when (or (not marked)
		    (superman-marked-p))
	    (setq loop-out
		  (append (list (apply fun args)) loop-out)))
	  (goto-char next)
	  (end-of-line))
	loop-out))))

(defun superman-count-items (&optional begin end)
  (let ((count 0) 
	(begin (or begin (point-min)))
	(end (or end (point-max))))
    (save-restriction
      (narrow-to-region begin end)
      (save-excursion
	(goto-char (point-min))
	(while (next-single-property-change
		(point-at-eol) 'org-marker)
	  (goto-char (next-single-property-change
		      (point-at-eol) 'org-marker))
	  ;; (when (or (not marked)
	  ;; (eq (get-text-property (point) (car marked)) (cadr marked)))
	  (setq count (+ 1 count)))
	count))))


(defun superman-structure-loop (fun args)
  "Loop over headings in a superman-views buffer."
  (save-excursion
    (widen)
    (goto-char (point-min))
    (while (outline-next-heading)
      (org-narrow-to-subtree)
      (apply fun args)
      (widen))))

;;}}}
;;{{{ Columns and balls

(defun superman-column-names (balls)
  (let ((cols (superman-format-column-names balls)))
    (put-text-property 0 (length cols) 'face 'font-lock-comment-face cols)
    (put-text-property 0 (length cols) 'column-names t cols)
    (put-text-property 0 (length cols) 'names (length cols) cols)
    cols))


(defun superman-format-column-names (balls)
  "Format column names NAMES according to balls, similar to
`superman-format-thing'.
Returns the formatted string with text-properties."
  (let ((column-names "")
	(column-widths (list 0))
	(copy-balls balls)
	(map (make-sparse-keymap)))
    (define-key map [mouse-2] 'superman-sort-section)
    (define-key map [return] 'superman-sort-section)
    ;; loop columns
    (while copy-balls
      (let* ((b (car copy-balls))
	     (col-name (cond ((cadr (assoc "name" b)))
			     ((stringp (car b)) (car b))
			     ((eq (car b) 'hdr) "Title")
			     ((eq (car b) 'todo) "Status")
			     ((eq (car b) 'priority) "Priority")
			     ((eq (car b) 'attac) " ")
			     ((eq (car b) 'org-hd-marker))
			     (symbol-name (cadr (assoc "fun" (cdr b))))))
	     name
	     sort-cmd)
	(setq name (superman-play-ball col-name
				       b
				       ;; (remq (assoc "fun" b) b)
				       'no-face))
	(setq sort-cmd (concat "sort-by-" name))
	;; make this name a button 
	(add-text-properties
	 superman-column-separator
	 (length name) 
	 (list
	  'button (list t)
	  'face 'font-lock-comment-face
	  'keymap map
	  'mouse-face 'highlight
	  'follow-link t
	  'help-echo sort-cmd)
	 name)
	(setq column-widths (append column-widths (list (length name))))
	(setq column-names (concat column-names name))
	(setq copy-balls (cdr copy-balls))))
    ;; text property: columns
    (put-text-property 0 (length column-names) 'columns column-widths column-names)
    column-names))


(defun superman-parse-props (&optional pom add-point with-heading)
  "Read properties at point or marker POM and return
them in an alist where the key is the name of the property
in lower case.

If ADD-POINT augment the list by an element
which holds the point of the heading."
  (org-with-point-at pom
    (save-excursion
      (let ((case-fold-search t)
	    (pblock (org-get-property-block))
	    props
	    (next 0))
	(when add-point
	  (setq props `(("point" ,(point)))))
	(when pblock
	  (narrow-to-region (car pblock) (cdr pblock))
	  (goto-char (point-min))
	  (while (= next 0)
	    (when (looking-at "^[ \t]*:\\([^:]+\\):[ \t]*\\(.*\\)[ \t]*$")
	      (setq props
		    (append
		     props
		     `((,(downcase (match-string-no-properties 1)) ,(match-string-no-properties 2))))
		    ))
	    (setq next (forward-line 1)))
	  (widen))
	(if (not with-heading)
	    props
	    (org-back-to-heading)
	    (looking-at org-complex-heading-regexp)
	    `(,(match-string-no-properties 4) ,props))))))


(defun superman-delete-balls (&optional pom)
  "Delete balls, i.e. column properties, at point or marker POM."
  (org-with-point-at pom
    (save-excursion
    (let ((case-fold-search t)
	  (beg (point))
	  (end (org-end-of-meta-data-and-drawers))
	  (kill-whole-line t)
	  balls)
      (save-excursion
	(goto-char beg)
	(when (re-search-forward "PROPERTIES" end t)
	  (while (re-search-forward "^[\t ]+:Ball[0-9]+:" end t)
	    (beginning-of-line)
	    (kill-line)
	    (goto-char (point-at-bol)))
	  balls))))))


(defun superman-string-to-thing (string &optional prefer-string prefer-symbol)
  "Convert STRING to either integer, string or symbol-name. If not an integer
and PREFER-SYMBOL is non-nil return symbol unless PREFER-STRING."
  (let (thing)
    (if (> (setq thing (string-to-int string)) 0)
	thing
      ;; either string or function
      (if prefer-string
	  (if (or (string= string "nil")
		  (string= string ""))
	      nil
	    string)
	(if (or (functionp (setq thing (intern string)))
		prefer-symbol)
	    thing
	  (if (or (string= string "nil")
		  (string= string ""))
	      nil
	    string))))))

(defun superman-distangle-ball (ball)
  (let* ((plist (split-string ball "[ \t]+:"))
         (prop (car plist))
	 (args
	  (mapcar
	   #'(lambda (x)
	      (let* ((pos (string-match "[ \t]" x))
		     (key (downcase (substring x 0 pos)))
		     (value (substring x (+ pos 1) (length x))))
		(cond ((string= (downcase key) "args")
		       `(,key ,(mapcar 'superman-string-to-thing (split-string value ","))))
		      ((string-match "^fun\\|face$" (downcase key))
		       ;; prefer symbol
		       `(,key ,(superman-string-to-thing value nil t)))
		      (t
		       ;; prefer string
		       `(,key ,(superman-string-to-thing value t nil))))))
	      (cdr plist))))
	 (when (string-match "^todo\\|hdr\\|index\\|org-hd-marker" prop)
	   (setq prop (intern prop)))
	 (append (list prop) args)))

(defun superman-save-balls ()
  "Save the columns (balls) in current category for future sessions."
  (interactive)
  (if (not superman-view-mode)
      (message "Can only save balls in superman-view-mode.")
    (let ((cat-point (superman-cat-point)))
      (if (not cat-point)
	  (message "Point is not inside a category.")
	(let* ((pom (get-text-property cat-point 'org-hd-marker))
	       (balls (get-text-property cat-point 'balls))
	       (i 1))
	  (superman-delete-balls pom)
	  (while balls
	    (org-entry-put
	     pom
	     (concat "Ball" (int-to-string i))
	     (superman-ball-to-string (car balls)))
	    (setq balls (cdr balls)
		  i (+ i 1))))
	(superman-view-save-index-buffer)
	(superman-redo)))))

(defun superman-thing-to-string (thing)
  (cond ((stringp thing) thing)
	((integerp thing) (int-to-string thing))
	((symbolp thing) (symbol-name thing))))

(defun superman-ball-to-string (ball)
  (let ((key (car ball))
	(args (cdr ball))
	bstring)
    (setq bstring (concat
		   (if (stringp key) 
		       key
		     (symbol-name key)) " "))
    (while args
      (setq bstring 
	    (concat bstring " :"
		    (nth 0 (car args))
		    " "
		    (superman-thing-to-string (nth 1 (car args)))))
	    (setq args (cdr args)))
      bstring))


(defun superman-ball-dimensions ()
  "Return column start, width and nth at (point)."
  (let* ((cols (cdr (get-text-property (point-at-bol) 'columns)))
	 (start 0)
	 width
	 (n 0)
	 (cc (current-column)))
    (when cols
      (while (> cc (+ start (car cols)))
	(setq n (+ 1 n))
	(setq start (+ start (car cols)))
	(setq cols (cdr cols)))
      (setq width (- (car cols) 1))
      (list start width n))))

;; (defun superman-get-ball-name ()

(defun superman-sort-section (&optional reverse)
  (interactive "P")
  (let* ((buffer-read-only nil)
	 (cc (current-column))
	 (pp (point-at-bol))
	 (col-start 0)
	 col-width
	 (sort-fold-case t) 
	 (cols (cdr (get-text-property (point-at-bol) 'columns)))
	 (n (get-text-property (superman-cat-point) 'n-items))
	 (pos (superman-current-subcat-pos))
	 next
	 beg
	 end)
    (when (and pos cols)
      (while (> cc (+ col-start (car cols)))
	(setq col-start (+ col-start (car cols)))
	(setq cols (cdr cols)))
      ;; the first x characters of each column are blank, 
      ;; where x is defined by superman-column-separator,
      ;; thus, we shift by superman-column-separator
      (setq col-start (+ superman-column-separator col-start))
      (setq col-width (- (car cols) superman-column-separator))
      (goto-char pos)
      (goto-char (next-single-property-change (point-at-eol) 'org-marker))
      (setq beg (point))
      ;; move to end of section
      (or (outline-next-heading)
	  (goto-char (point-max)))
      (goto-char (previous-single-property-change (point-at-eol) 'org-marker))
      (setq end (point))
      (narrow-to-region beg end)
      (goto-char (point-min))
      ;; sort by sort-key if any
      (if (get-text-property (+ (point) col-start) 'sort-key)
	  (let (key)
	    (if reverse 
		(let ((maxkey (apply 'max (superman-loop
					   #'(lambda (&rest args)
					       (get-text-property (+ (point) col-start) 'sort-key)) '(nil)))))
		  (goto-char (point-min))
		  (setq key (get-text-property (+ (point) col-start) 'sort-key))
		  (insert (int-to-string (+ (- maxkey key) 1)))
		  (while (re-search-forward "^" nil t)
		    (setq key (get-text-property (+ (point) col-start) 'sort-key))
		    (insert (int-to-string (+ (- maxkey key) 1)))))
	      (goto-char (point-min))
	      (setq key (get-text-property (+ (point) col-start) 'sort-key))
	      (insert (int-to-string key))
	      (while (re-search-forward "^" nil t)
		(setq key (get-text-property (+ (point) col-start) 'sort-key))
		(insert (int-to-string key))))
	    (sort-numeric-fields 0 (point-min) (point-max))
	    (goto-char (point-min))
	    (while (re-search-forward "^" nil t)
	      (delete-region (point)
			     (+ (point)
				(skip-chars-forward "[0-9]")))
	      (end-of-line)))
	;; sort using sort-subr
	(sort-subr reverse 'forward-line 'end-of-line
		   `(lambda () (forward-char ,col-start))
		   `(lambda () (forward-char ,col-width))))
      (widen)
      (goto-char pp)
      (forward-char (+ superman-column-separator col-start)))))
      

(defun superman-sort-by-status (a b)
  (let ((A  (substring-no-properties a 0 12))
	(B  (substring-no-properties b 0 12)))
    (if (string= A B) nil 
      (if (string-lessp A B)
	  1 -1))))

;;}}}
;;{{{ Project views

(defun superman-parse-cats (buffer level)
  "Parse headings with level LEVEL in buffer BUFFER. Return a list
with elements (heading-name props) where props is a list
with the heading's properties augmented by an element called \"point\"
which locates the heading in the buffer."
  (save-excursion
    (save-restriction
      (set-buffer buffer)
      (widen)
      (show-all)
      (goto-char (point-min))
      ;; move to first heading
      ;; with the correct level
      (while (and (not (and
			(looking-at org-complex-heading-regexp)
			(org-current-level)
			(= (org-current-level) level)))
		  (outline-next-heading)))
      (when (and (org-current-level) (= (org-current-level) level))
	(let ((cats `(,(superman-parse-props (point) 'p 'h)))
	      (cat-point (point)))
	  (while (progn (org-forward-heading-same-level 1)
			(> (point) cat-point))
	    (looking-at org-complex-heading-regexp)
	    (setq cat-point (point)
		  cats (append cats `(,(superman-parse-props cat-point 'p 'h)))))
	  cats)))))


(defun superman-view-project (&optional project)
  "Display the current project in a view buffer."
  (interactive)
  (let* ((pro (if (stringp project)
		  (assoc project superman-project-alist)
		(or project
		    superman-current-project
		    (superman-switch-to-project nil t))))
	 (loc (superman-project-home pro))
	 (gitp (superman-git-p loc))
	 (vbuf (concat "*Project[" (car pro) "]*"))
	 (index (superman-get-index pro))
	 (ibuf (or (get-file-buffer index)
		   (find-file index)))
	 (cats (delete-if
		#'(lambda (cat)
		    (string= "Configuration" (car cat)))
		(superman-parse-cats ibuf 1)))
	 ;; identify appropriate buttons
	 (buttons (save-excursion
		    (switch-to-buffer ibuf)
		    (goto-char (point-min))
		    (let ((b-string))
		      (when (re-search-forward ":CaptureButtons:" nil t)
			(setq b-string (superman-get-property (point) "CaptureButtons" nil))
			(if b-string (mapcar #'(lambda (x) (split-string x "|"))
					     (split-string (replace-regexp-in-string "[ \t]*" "" b-string) "," t)) "nil")))))
	 (font-lock-global-modes nil)
	 (org-startup-folded nil))
    ;; update git status
    ;; (when gitp
    ;; (switch-to-buffer ibuf)
    ;; (superman-view-git-update-status loc nil nil nil 'dont))
    (switch-to-buffer vbuf)
    (setq buffer-read-only nil)
    (erase-buffer)
    (org-mode)
    (font-lock-mode -1)
    (font-lock-default-function nil)
    ;; insert header, set text-properties and highlight
    (insert (superman-make-button
	     (concat "Project: " (car pro))
	     'superman-redo
	     'superman-project-button-face
	     "Refresh project view"))
    ;; (put-text-property (point-at-bol) (point-at-eol) 'face 'superman-project-button-face)
    (put-text-property (point-at-bol) (point-at-eol) 'redo-cmd `(superman-view-project ,(car pro)))
    (put-text-property (point-at-bol) (point-at-eol) 'git-dir (superman-git-toplevel loc))
    (put-text-property (point-at-bol) (point-at-eol) 'dir loc)
    (put-text-property (point-at-bol) (point-at-eol) 'nickname (car pro))
    (put-text-property (point-at-bol) (point-at-eol) 'index index)
    ;; link to previously selected projects
    (superman-view-insert-project-buttons)
    (insert (superman-project-view-header pro))
    (when gitp
      (superman-view-insert-git-branches loc))
    (superman-view-insert-config-buttons pro)
    (superman-view-insert-unison-buttons pro)
    ;; action buttons
    (unless (and (stringp buttons) (string= buttons "nil"))
      (superman-view-insert-action-buttons buttons))
    ;; loop over cats
    (goto-char (point-max))
    (insert "\n\n")
    (while cats
      (superman-format-cat (car cats) ibuf vbuf loc)
      (setq cats (cdr cats)))
    ;; leave index buffer widened
    (set-buffer ibuf)
    (widen)
    (show-all)
    (switch-to-buffer vbuf))
  (goto-char (point-min))
  ;; facings
  (save-excursion
    (while (or (org-activate-bracket-links (point-max)) (org-activate-plain-links (point-max)))
      (add-text-properties
       (match-beginning 0) (match-end 0)
       '(face org-link))))
  ;; default-dir
  (setq default-directory
	(superman-project-home
	 (superman-view-current-project)))
  ;; minor-mode
  (superman-view-mode-on)
  (setq buffer-read-only t))

(defun superman-redo-cat ()
  "Redo the current section in a superman view buffer."
  (let ((cat-point (point-at-bol))
	(cat (superman-parse-props
	      (get-text-property (point-at-bol) 'org-hd-marker)
	      'p 'h))
	(view-buf (current-buffer))
	(index-buf (marker-buffer (get-text-property (point-at-bol) 'org-hd-marker)))
	(loc (get-text-property (point-min) 'git-dir))
	(buffer-read-only nil))
    (org-cut-subtree)
    (superman-format-cat cat index-buf view-buf loc)
    (goto-char cat-point)))

(defun superman-format-cat (cat index-buf view-buf loc)
  "Format category CAT based on information in INDEX-BUF and write the result
to VIEW-BUF."
  (let* ((case-fold-search t)
	 (name (car cat))
	 (props (cadr cat))
	 (cat-balls (if props
			(delete nil
				(mapcar #'(lambda (x) (when (string-match "^Ball[0-9]+$" (car x))
							(superman-distangle-ball (cadr x)))) props))))
	 (gear (cdr (assoc name superman-finalize-cat-alist)))
	 (balls (or cat-balls (eval (nth 0 gear)) superman-default-balls))
	 (index-cat-point (cadr (assoc "point" props)))
	 (buttons (cadr (assoc "buttons" props)))
	 (git (assoc "git-cycle" props))
	 ;; (folded (cadr (assoc "startfolded") props))
	 (free (assoc "freetext" props))
	 (count 0)
	 index-marker
	 cat-head)
    ;; mark head of this category in view-buf
    (set-buffer view-buf)
    (setq view-cat-head (point))
    (when git (setq git (get-text-property (point-min) 'git-dir)))
    (cond
     ;; free text sections are put as they are
     (free
      (set-buffer index-buf)
      (widen)
      (goto-char index-cat-point)
      (setq index-marker (point-marker))
      (save-restriction
	(org-narrow-to-subtree)
	(let ((text
	       (buffer-substring
		(progn (org-end-of-meta-data-and-drawers)
		       (point))
		(point-max))))
	  (with-current-buffer view-buf
	    (superman-view-insert-section-name
	     (car cat)
	     0 balls
	     index-marker)
	    (insert text)))))
     ((and git (file-exists-p git))
      (with-current-buffer index-buf
	(setq index-marker (point-marker)))
      (set-buffer (get-buffer-create "*Git output*"))
      (erase-buffer)
      (insert "git-output")
      (put-text-property (point-at-bol) (point-at-eol) 'git-dir
			 (superman-git-toplevel loc))
      (insert "\n")
      (org-mode)
      ;; call git display cycle
      (superman-view-git-display-cycle
       view-buf git props
       view-cat-head index-buf index-cat-point
       name))
     (balls
      ;; create table view based on balls 
      ;; move to index-buf
      (let (countsub line)
	(set-buffer index-buf)
	(widen)
	(goto-char index-cat-point)
	(let* ((attac-balls (cdr (assoc 'attac balls))))
	  (org-narrow-to-subtree)
	  (goto-char (point-min))
	  (setq index-marker (point-marker))
	  ;; loop over items in cat
	  ;; format elements (if any and if wanted)
	  ;; region is narrowed to section
	  (while (outline-next-heading)
	    (cond ((eq (org-current-level) 2)
		   ;; sub-headings
		   (let ((subhdr (progn (looking-at org-complex-heading-regexp) (match-string-no-properties 4))))
		     (setq line (concat "*** " subhdr))
		     (put-text-property 0 (length line) 'subcat subhdr line)
		     (put-text-property 0 (length line) 'org-hd-marker (point-marker) line)
		     (put-text-property 0 (length line) 'face 'org-level-3 line)
		     (put-text-property 0 (length line) 'face 'superman-subheader-face line)
		     (put-text-property 0 (length line) 'display (concat "  ☆ " subhdr) line)
		     (with-current-buffer view-buf (setq countsub (append countsub (list `(0 ,(point))))))
		     (with-current-buffer view-buf (insert line " \n" ))
		     (end-of-line)))
		  ;; items
		  ((eq (org-current-level) 3)		       
		   (if countsub
		       (setf (car (car (last countsub))) (+ (car (car (last countsub))) 1)))
		   (setq count (+ count 1))
		   (setq line (superman-format-thing (copy-marker (point-at-bol)) balls))
		   (with-current-buffer view-buf
		     ;; (goto-char (point-max))
		     (insert line "\n")))
		  ;; attachments
		  ((and (eq (org-current-level) 4) attac-balls)
		   (setq line (superman-format-thing (copy-marker (point-at-bol)) attac-balls))
		   (with-current-buffer view-buf (insert line "\n"))))))
	(put-text-property (- (point-at-eol) 1) (point-at-eol) 'tail name)
	;; add counts in sub headings
	(set-buffer view-buf)
	(save-excursion 
	  (while countsub
	    (let ((tempsub (car countsub)))
	      (goto-char (nth 1 tempsub))
	      (put-text-property
	       (- (point-at-eol) 1) (point-at-eol) 'display
	       (concat " [" (int-to-string (car tempsub)) "]")))
	    (setq countsub (cdr countsub))))
	;; (widen)
	;; empty cats are not shown unless explicitly wanted
	(if (or (not (member cat superman-capture-alist))
		(member name superman-views-permanent-cats)
		(> count 0))
	    (progn 
	      ;; insert the section name
	      (set-buffer view-buf)
	      (goto-char view-cat-head)
	      (when (and
		     superman-empty-line-before-cat
		     (save-excursion (beginning-of-line 0)
				     (not (looking-at "^[ \t]*$"))))
		(insert "\n"))
	      (superman-view-insert-section-name name count balls index-marker)
	      ;; insert the column names
	      (when superman-empty-line-after-cat
		(insert "\n"))
	      (insert (superman-column-names balls))
	      (when buttons
		(beginning-of-line)
		(funcall (intern buttons))
		(insert "\n")))
	  (delete-region (point) (point-max))))))
    (goto-char (point-max))
    (widen)))
;; (when folded (hide-subtree))

(defun superman-view-insert-section-name (name count balls index-marker &optional fun)
      (let ((fun (or
		  fun
		  (cadr (assoc name superman-capture-alist))
		  'superman-capture-item)))
	(insert
	 (superman-make-button (concat "** " name) fun
		 'superman-capture-button-face
		 "Add new item")
		"\n"))
      (forward-line -1)
      (beginning-of-line)
      (put-text-property (point-at-bol) (point-at-eol) 'cat name)
      (put-text-property (point-at-bol) (point-at-eol) 'n-items count)
      (put-text-property (point-at-bol) (point-at-eol) 'balls balls)
      (put-text-property (point-at-bol) (point-at-eol) 'org-hd-marker index-marker)
      (put-text-property (point-at-bol) (point-at-eol) 'display (concat "★ " name))
      (end-of-line)
      (insert " [" (int-to-string count) "]\n"))

;;}}}
;;{{{ git-cycle views

(defvar superman-view-git-display-command-list
  '(("log"
     "log -n 5 --name-status --date=short --pretty=format:\"** %h\n:PROPERTIES:\n:Author: %an\n:Date: %cd\n:Message: %s\n:END:\n\""
     ((hdr ("width" 9) ("face" font-lock-function-name-face) ("name" "Version"))
      ("Author" ("width" 10) ("face" superman-get-git-status-face))
      ("Date" ("width" 13) ("fun" superman-trim-date) ("face" font-lock-string-face))
      ("Message" ("width" 63))))
    ("files"
     "ls-files --full-name"
     (("filename" ("width" 12) ("fun" superman-make-git-keyboard) ("name" "git-keyboard") ("face" "no-face"))
      (hdr ("width" 44) ("face" font-lock-function-name-face) ("name" "Filename"))
      ("Directory" ("width" 25) ("face" superman-subheader-face))
      ("Status" ("width" 9) ("face" superman-get-git-status-face)))
     superman-view-git-clean-git-ls-files+)
    ("untracked"
     "ls-files --full-name --others"
     (("filename" ("width" 12) ("fun" superman-make-git-keyboard) ("name" "git-keyboard") ("face" "no-face"))
      (hdr ("width" 44) ("face" font-lock-function-name-face) ("name" "Filename"))
      ("Directory" ("width" 25) ("face" superman-subheader-face))
      ("Status" ("width" 9) ("face" superman-get-git-status-face)))
     superman-view-git-clean-git-ls-files)
    ("modified"
     "ls-files --full-name -m"
     (("filename" ("width" 12) ("fun" superman-make-git-keyboard) ("name" "git-keyboard") ("face" "no-face"))
      (hdr ("width" 44) ("face" font-lock-function-name-face) ("name" "Filename"))
      ("Directory" ("width" 25) ("face" superman-subheader-face))
      ("Status" ("width" 9) ("face" superman-get-git-status-face)))
     superman-view-git-clean-git-ls-files+)
    ;; ("date"
    ;; "ls-files | while read file; do git log -n 1 --pretty=\"** $file\n:PROPERTIES:\n:COMMIT: %h\n:DATE: %ad\n:END:\n\" -- $file; done"
    ;; ((hdr ("width" 12) ("face" font-lock-function-name-face) ("name" "Filename"))
    ;; ("DATE" ("fun" superman-trim-date))
    ;; ("COMMIT" ("width" 18))))
    )
  "List of git-views. Each entry has 4 elements: (key git-switches balls cleanup), where key is a string
to identify the element, git-switches are the switches passed to git, balls are used to define the columns and
cleanup is a function which is called before superman plays the balls.")


(defun superman-git-kb-commit ()
  "Add and commit the file given by the filename property of the item at point."
  (interactive)
  (let* ((filename (superman-filename-at-point))
	 (file (file-name-nondirectory filename))
	 (dir (if filename (expand-file-name (file-name-directory filename))))
	 (fbuf (get-file-buffer file)))
    (when (and fbuf
	       (with-current-buffer fbuf (buffer-modified-p))
	       (y-or-n-p (concat "Save buffer " fbuf "?")))
      (with-current-buffer fbuf (save-buffer)))
    (superman-git-add (list file) dir 'commit nil)
    (superman-view-redo-line)))

(defun superman-git-kb-add ()
  "Add and commit the file given by the filename property of the item at point."
  (interactive)
  (let* ((filename (superman-filename-at-point))
	 (file (file-name-nondirectory filename))
	 (dir (if filename (expand-file-name (file-name-directory filename))))
	 ;; (cmd (concat "cd " dir ";" superman-cmd-git " add -f " file))
	 (fbuf (get-file-buffer file)))
    (when (and fbuf
	       (with-current-buffer fbuf (buffer-modified-p))
	       (y-or-n-p (concat "Save buffer " fbuf "?")))
      (with-current-buffer fbuf (save-buffer)))
    (superman-git-add (list file) dir nil nil)
    (superman-view-redo-line)))

;; (defun superman-git-kb-stash ()
  ;; "Add and commit the file given by the filename property of the item at point."
  ;; (interactive)
  ;; (let* ((filename (superman-filename-at-point))
	 ;; (file (file-name-nondirectory filename))
	 ;; (dir (if filename (expand-file-name (file-name-directory filename))))
	 ;; ;; (cmd (concat "cd " dir ";" superman-cmd-git " add -f " file))
	 ;; (fbuf (get-file-buffer file)))
    ;; (when (and fbuf
	       ;; (with-current-buffer fbuf (buffer-modified-p))
	       ;; (y-or-n-p (concat "Save buffer " fbuf "?")))
      ;; (with-current-buffer fbuf (save-buffer)))
    ;; (superman-view-redo-line)))

(defface superman-git-keyboard-face-d
  '((t (:inherit superman-default-button-face
		 :foreground "black"
		 :background "orange")))
  "Face used for git-diff."
  :group 'superman)
(defface superman-git-keyboard-face-a
  '((t (:inherit superman-default-button-face
		 :foreground "black"
		 :background "yellow")))
  "Face used for git-add."
  :group 'superman)

(defface superman-git-keyboard-face-c
  '((t (:inherit superman-default-button-face
		 :foreground "black"
		 :background "green")))
  "Face used for git-commit."
  :group 'superman)

(defface superman-git-keyboard-face-x
  '((t (:inherit superman-default-button-face
		 :foreground "white"
		 :background "black")))
  "Face used for git-rm."
  :group 'superman)

(defface superman-git-keyboard-face-s
  '((t (:inherit superman-default-button-face
		 :foreground "black"
		 :background "red")))
  "Face used for git-stash."
  :group 'superman)

(defun superman-make-git-keyboard (f &rest args)
  (if (string-match org-bracket-link-regexp f)
      (let ((diff (superman-make-button "d"
					'superman-view-git-diff-1
					'superman-git-keyboard-face-d
					"git diff"))
	    (add (superman-make-button "a"
				       'superman-git-add-at-point
				       'superman-git-keyboard-face-a
				       "git add"))
	    (commit (superman-make-button "c"
					  'superman-view-git-commit
					  'superman-git-keyboard-face-c
					  "git commit"))
	    (stash (superman-make-button "s"
					  'superman-view-git-stash
					  'superman-git-keyboard-face-s
					  "git commit"))
	    (delete (superman-make-button "x"
					  'superman-view-git-delete
					  'superman-git-keyboard-face-x
					  "git rm")))
	(concat diff " " add  " " delete " " stash  " " commit " " " " " "))
    ;; for the column name
    (superman-trim-string f (car args))))



;; (defun superman-make-git-diff-button (f &rest args)
  ;; (if (string-match org-bracket-link-regexp f)
      ;; (let ((bname (superman-trim-string "d@1" (car args))))
	;; (superman-make-button bname
			      ;; 'superman-view-git-diff-1
			      ;; 'superman-capture-button-face
			      ;; "git diff"))
    ;; ;; for the column name
    ;; (superman-trim-string f (car args))))

(defun superman-add-git-cycle ()
  (interactive)
  (save-window-excursion
    (find-file (get-text-property (point-min) 'index))
    (goto-char (point-min))
    (unless (re-search-forward ":git-cycle:" nil t)
      (goto-char (point-max))
      (insert "\n* Git repository\n:PROPERTIES:\n:git-cycle: "
	      (let ((sd (cdr superman-git-default-displays))
		    (dstring (car superman-git-default-displays)))
		(while sd
		  (setq dstring (concat dstring ", " (car sd))
			sd (cdr sd)))
		dstring)
	      "\n:git-display: modified\n:END:\n")
      (superman-redo)))
  (let ((ibuf (concat (buffer-name) " :Git-repos"))
	(git-dir (get-text-property (point-min) 'git-dir)))
    (if (get-buffer ibuf)
	(switch-to-buffer ibuf)
      (make-indirect-buffer (current-buffer) ibuf 'clone)
      (switch-to-buffer ibuf)
      (goto-char (next-single-property-change (point-min) 'git-repos))
      (org-narrow-to-subtree)
      (goto-char (point-min))
      (let ((buffer-read-only nil))
	(insert (superman-make-button
		 "Back to project (q)"
		 'superman-view-back)
		"\n")
	(put-text-property (point-min) (+ (point-min) (length "Back to project (q)")) 'git-dir git-dir)
	(superman-git-mode)
	))))


(defvar superman-git-mode-map (make-sparse-keymap)
  "Keymap used for `superman-git-mode' commands.")
   
(define-minor-mode superman-git-mode
     "Toggle superman git mode.
With argument ARG turn superman-git-mode on if ARG is positive, otherwise
turn it off.
                   
Enabling superman-git mode enables the git keyboard to control single files."
     :lighter " *SG*"
     :group 'org
     :keymap 'superman-git-mode-map)

(defun superman-git-mode-on ()
  (interactive)
  (when superman-hl-line (hl-line-mode 1))
  (superman-git-mode t))

(define-key superman-git-mode-map "q" 'superman-view-back)
(define-key superman-git-mode-map "c" 'superman-view-git-commit)
(define-key superman-git-mode-map "a" 'superman-view-git-add)
(define-key superman-git-mode-map "s" 'superman-view-git-stash)
(define-key superman-git-mode-map "x" 'superman-view-git-delete)
(define-key superman-git-mode-map "d" 'superman-view-git-diff)

(defun superman-view-back ()
  "Kill indirect buffer and return to project view."
  (interactive)
  (goto-char (point-min))
  (let ((buffer-read-only nil))
    (kill-line))
  (kill-buffer (current-buffer)))

(defvar superman-git-display-cycles nil
  "Keywords to match the elements in superman-view-git-display-command-list")
(make-variable-buffer-local 'superman-git-display-cycles)
(setq superman-git-display-cycles nil)

(setq superman-git-default-displays '("log" "modified" "files" "untracked"))

(defun superman-view-set-git-cycle (value)
  (org-with-point-at (get-text-property (point-at-bol) 'org-hd-marker)
    (org-set-property "git-display" value))
  (superman-redo-cat))

(defun superman-view-cycle-git-display ()
  "Cycles to the next value in `superman-git-display-cycles'.
This function should be bound to a key or button."
  (interactive)
  (let* ((pom (get-text-property (point-at-bol) 'org-hd-marker))
	 (cycles (split-string (or (superman-get-property pom "git-cycle")
				   superman-git-default-displays)
			       "[ \t]*,[ \t]*"))
	 (current (superman-get-property pom "git-display"))
	 (rest (member current cycles))
	 (next (if (> (length rest) 1) (cadr rest) (car cycles))))
    ;; (setq superman-git-display-cycles (append (cdr superman-git-display-cycles) (list (car superman-git-display-cycles))))
    (superman-view-set-git-cycle next)))


(defun superman-view-git-clean-git-ls-files ()
  (let* ((git-dir (get-text-property (point-min) 'git-dir)))
    (goto-char (point-min))
    (while (re-search-forward "^[^ \t\n]+" nil t)
      (let* ((ff (buffer-substring (point-at-bol) (point-at-eol)))
	     (dname (file-name-directory ff))
	     (fname (file-name-nondirectory ff))
	     (fullname (concat git-dir "/" ff))
	     (status "Untracked"))
	(replace-match
	 (concat "** "
		 fname
		 "\n:PROPERTIES:\n:STATUS: " status
		 "\n:Directory: " (cond (dname) (t "."))  
		 "\n:FILENAME: [[" fullname "]]\n:END:\n\n") 'fixed)))))

(defun superman-view-git-clean-git-ls-files+ ()
  (let* ((git-dir (get-text-property (point-min) 'git-dir))
	 (git-status
	  (shell-command-to-string
	   (concat "cd " dir ";" superman-cmd-git " status --porcelain ")))
	 (status-list
	  (mapcar (lambda (x)
		    (let ((index-status (substring-no-properties x 0 1))
			  (work-tree-status (substring-no-properties x 1 2))
			  (fname  (substring-no-properties x 3 (length x))))
		      (list fname index-status work-tree-status)))
		  (delete-if (lambda (x) (string= x "")) (split-string git-status "\n")))))
    (goto-char (point-min))
    (while (re-search-forward "^[^ \t\n]+" nil t)
      (let* ((ff (buffer-substring (point-at-bol) (point-at-eol)))
	     (dname (file-name-directory ff))
	     (fname (file-name-nondirectory ff))
	     (fullname (concat git-dir "/" ff))
	     (status (assoc ff status-list)))
	(replace-match
	 (concat "** "
		 fname
		 "\n:PROPERTIES:\n:STATUS: "
		 (cond ((not status) "Committed")
		       (t
			(let* ((X (or (nth 1 status) " "))
			       (Y (or (nth 2 status) " "))
			       (XY (concat X Y)))
			  (cond ((string= " M" XY)
				 "Modified")
				((string= "??" XY)
				 "Untracked")
				((string= " D" XY)
				 "Deleted")
				((string= " R" XY)
				 "Renamed")
				((string= " U" XY)
				 "Unmerged")
				((string= "AM" XY)
				 "Added")
				((string= "UU" XY)
				 "unmerged, both modified")
				((string= "DD" XY)
				 "unmerged, both deleted")
				((string= "AU" XY)
				 "unmerged, added by us")
				((string= "UD" XY)
				 "unmerged, deleted by them")
				((string= "UA" XY)
				 "unmerged, added by them")
				((string= "DU" XY)
				 "unmerged, deleted by us")
				((string= "AA" XY)
				 "unmerged, both added")
				(t "Unknown")))))
		 "\n:Directory: " (cond (dname) (t "."))  
		 "\n:FILENAME: [[" fullname "]]\n:END:\n\n"))))))

(defun superman-view-git-clean-git-status ()
  (let ((git-dir (get-text-property (point-min) 'git-dir)))
    (goto-char (point-min))
    (while (re-search-forward "^[ ]?\\([a-zA-Z]+\\) \\(.*\\)[ \t\n]?" nil t)
      (let* ((status (match-string-no-properties 1))
	     (long-fname (concat git-dir "/" (match-string-no-properties 2)))
	     (fname (file-name-nondirectory long-fname)))
	(replace-match
	 (concat "** "
		 fname
		 "\n:PROPERTIES:\n:STATUS: " (superman-status-label status)
		 "\n:FILENAME: [[" long-fname "]]\n:END:\n\n") 'fixed)))))
;; "--numstat "
;; "--name-status "

(defun superman-view-git-display-cycle (view-buf dir props view-point index-buf index-cat-point name)
  (let* ((cycles (split-string (cadr (assoc "git-cycle" props)) "[ \t]*,[ \t]*"))
	 (cycle (or (cadr (assoc "git-display" props)) (car cycles)))
	 (limit (cadr (assoc "limit" props)))
	 (rest (assoc cycle superman-view-git-display-command-list))
	 (balls (or (nth 2 rest) superman-default-balls))
	 (clean-up (nth 3 rest))
	 (cmd (concat "cd " dir ";" superman-cmd-git " " (nth 1 rest))))
    ;; for the first time ... 
    (unless superman-git-display-cycles (setq superman-git-display-cycles cycles))
    ;; limit on number of revisions
    (when limit
      (replace-regexp-in-string "-n [0-9]+ " (concat "-n " limit " ")))
    ;; insert the result of git command
    (insert (shell-command-to-string cmd))
    (goto-char (point-min))
    ;; clean-up if necessary
    (when clean-up (funcall clean-up))
    (goto-char (point-min))
    (while (outline-next-heading)
      (setq count (+ count 1))
      (setq line (superman-format-thing (copy-marker (point-at-bol)) balls))
      (with-current-buffer view-buf (insert line "\n")))
    (set-buffer view-buf)
    (when superman-empty-line-before-cat (insert "\n"))
    (goto-char view-point)
    ;; section names
    (when (and
	   superman-empty-line-before-cat
	   (save-excursion (beginning-of-line 0)
			   (not (looking-at "^[ \t]*$"))))
      (insert "\n"))
    (put-text-property 0 (length name) 'git-repos dir name) 
    (superman-view-insert-section-name
     name count balls
     ;; FIXME: it must be possible to construct the marker based on buf and point
     (with-current-buffer index-buf
       (widen)
       (goto-char index-cat-point) (point-marker))
     'superman-view-cycle-git-display)
    (end-of-line 0)
    (let ((cycle-strings cycles))
      (while cycle-strings
	(let ((cstring (car cycle-strings)))
	  (set-text-properties 0 (length cstring) nil cstring)
	  (insert " >> ")
	  (insert (superman-make-button
		   cstring
		   `(lambda () (interactive) (superman-view-set-git-cycle ,cstring))
		   (if (string= cycle cstring)
		       'superman-next-project-button-face nil)
		   (concat "Cycle display to git " cstring)))
	  (setq  cycle-strings (cdr cycle-strings)))))
    (forward-line 1)
    ;; insert the column names
    (when superman-empty-line-after-cat (insert "\n"))
    (insert (superman-column-names balls))))

(unless org-todo-keyword-faces
  (setq org-todo-keyword-faces
	(quote (("TODO" :foreground "red" :weight bold)
		("URGENT" :foreground "goldenrod1" :weight bold)
		("IN PROGRESS" :foreground "blue" :weight bold)
		("ACTIVE" :foreground "red" :weight bold)
		("WAITING" :foreground "purple" :weight bold)
		("PERMANENT" :foreground "SkyBlue3" :weight bold)
		("DONE" :foreground "forest green" :weight bold)
		("CANCELED" :foreground "slate grey" :weight bold)))))

;;}}}
;;{{{ Formatting items and column names

(defun superman-play-ball (thing ball &optional no-face)
  "Play BALL at THING which is a marker or an alist and return
a formatted string with faces."
  (let* ((raw-string
	  (cond ((markerp thing)
		 ;; thing is marker
		 (cond ((stringp (car ball)) ;; properties
			(superman-get-property thing (car ball) t))
		       ;; important:
		       ;; when introducing new special things 
		       ;; also adapt superman-distangle-ball
		       ((eq (car ball) 'org-hd-marker) ;; special: marker
			thing)
		       ((eq (car ball) 'hdr) ;; special: header
			(org-with-point-at thing 
			  (org-back-to-heading t)
			  (looking-at org-complex-heading-regexp)
			  (match-string 4)))
		       ((eq (car ball) 'todo) ;; special: todo state
			(org-with-point-at thing 
			  (org-back-to-heading t)
			  (and (looking-at org-todo-line-regexp)
			       (match-end 2) (match-string 2))))
		       ((eq (car ball) 'priority) ;; special: priority
			(org-with-point-at thing 
			  (org-back-to-heading t)
			  (looking-at org-complex-heading-regexp)
			  (match-string 3)))
		       ((eq (car ball) 'attac) ;; special: attachment
			nil)
		       ((eq (car ball) 'index) ;; special: index filename
			(file-name-sans-extension
			 (file-name-nondirectory
			  (buffer-file-name (current-buffer)))))
		       (t "--")))
		((stringp thing) thing)
		;; thing is alist
		((listp thing) (cdr (assoc (car ball) (cadr thing))))
		(t "--")))
	 (raw-string (if (or (not raw-string) (eq raw-string "")) "--" raw-string))
	 (fun (or (cadr (assoc "fun" (cdr ball))) 'superman-trim-string))
	 (width (or (cdr (assoc "width" (cdr ball))) (list 23)))
	 (args (cdr (assoc "args" (cdr ball))))
	 ;; (preserve-props (assoc "preserve" (cdr ball)))
	 (trim-args (nconc width args))
	 (trimmed-string
	  (concat "  " ;; column sep
		  (apply fun raw-string trim-args)))
	 (len (length trimmed-string))
	 (face (or (cadr (assoc "face" ball))
		   (unless (markerp raw-string)
		     (get-text-property 0 'face raw-string))))
	 (sort-key (get-text-property superman-column-separator 'sort-key trimmed-string)))
    ;; remove all existing text-properties
    ;; (unless preserve-props
    ;; (set-text-properties 0 len nil trimmed-string))
    (when sort-key (put-text-property 0 len 'sort-key sort-key trimmed-string))
    ;; FIXME: this needs documentation, i.e. that a ball ("face" "no-face") will avoid the face
    (unless (or no-face (stringp face)) 
      (when (and (not (facep face)) (functionp face)) ;; apply function to get face
	(setq face (funcall
		    face
		    (replace-regexp-in-string
		     "^[ \t\n]+\\|[ \t\n]+$" ""
		     raw-string))))
      (when (or (facep face) (listp face))
	(put-text-property 0 len 'face face trimmed-string)))
    ;; (put-text-property 0 (length trimmed-string) 'face face trimmed-string)))
    trimmed-string))

(defun superman-format-thing (thing balls &optional no-face)
  "Format THING according to balls. THING is either
a marker which points to a header in a buffer 
or an association list. 

Returns the formatted string with text-properties."
  (let ((item "")
	ilen
	(column-widths (list 0))
	(marker (cond ((markerp thing) thing)
		      ((cdr (assoc "marker" (cadr thing))))))
	(copy-balls balls))
    ;; loop columns
    (while copy-balls
      (let* ((b (car copy-balls))
	     (bstring (superman-play-ball thing b no-face)))
	(setq column-widths (append column-widths (list (length bstring))))
	(setq item (concat item bstring)))
      (setq copy-balls (cdr copy-balls)))
    (setq ilen (length item))
    ;; marker in index file
    (when marker
      (put-text-property 0 ilen 'org-hd-marker marker item)
      (put-text-property 0 ilen 'org-marker marker item))
    ;; add balls for redo
    ;; not done (balls are saved in category instead)
    ;; (put-text-property 0 ilen 'balls balls item)
    ;; text property: columns
    (put-text-property 0 ilen 'columns column-widths item)
    item))


(defun superman-project-view-header (pro)
  "Construct extra heading lines for project views."
  (let ((hdr  (concat "\n\n"
		      (superman-view-others pro)
		      (superman-view-control pro)
		      ;; (superman-view-branches pro)
		      ;; "\n"
		      ;; (superman-view-show-hot-keys)
		      )))
    hdr))


;; (defun superman-documents-view-header (pro)
  ;; "Construct extra heading lines for project views."
  ;; (let ((control (superman-view-control pro))
	;; (hotkeys (superman-view-hot-keys superman-view-documents-hot-keys)))
    ;; (concat "\n" control (insert "\n\n" hotkeys "\n\n"))) "\n" )

;;}}}
;;{{{ Moving (items) around

(defun superman-next-cat ()
  (interactive)
  (goto-char (or (next-single-property-change (point-at-eol)
					      'cat)
		 (point-max))))

(defun superman-cat-point (&optional pos)
  "Return point where current category defines text-properties."
  (if (get-text-property (or pos (point)) 'cat)
      (point)
    (let ((cat-head (previous-single-property-change (or pos (point)) 'cat)))
      (when cat-head
	(save-excursion
	  (goto-char cat-head)
	  (beginning-of-line)
	  (point))))))

(defun superman-subcat-point (&optional pos)
  "Return point where current subcategory defines text-properties."
  (let ((subcat-head (previous-single-property-change (or pos (point)) 'subcat)))
    (when subcat-head
      (save-excursion
	(goto-char subcat-head)
	(beginning-of-line)
	(point)))))

(defun superman-previous-cat ()
  "Move point to start of category"
  (interactive)
  (goto-char (or (superman-cat-point (max 1 (- (point-at-bol) 1))) (point-min))))

(defun superman-swap-balls (list pos)
  "Exchange list element at pos with that at pos + 1.
Starts counting at 0, thus

 (superman-swap-balls (list 1 2 3 4 5) 0)

yields

 (2 1 3 4 5).
If pos is negative place the first element at the
end of the list.

If pos exceeds the length of the list place last element at the
beginning of the list."
  (let ((len (length list))
	(newlist (copy-sequence list)))
    (cond ((< pos 0)
	   (nconc (cdr newlist) (list (car newlist))))
	  ((> pos (- len 2))
	   (nconc (list (nth (- len 1) newlist)) (butlast newlist 1)))
	  (t
	   (nconc (butlast newlist (- len pos))
	     (list (nth (+ pos 1) newlist))
	     (list (nth pos newlist))
	     (nthcdr (+ pos 2) newlist))))))
	     

(defun superman-change-balls (new-balls)
  "Exchange balls (column definitions) in this section."
  (let ((buffer-read-only nil)
	(cat-point (superman-cat-point)))
  (if cat-point
      (save-excursion
	(goto-char cat-point)
	(put-text-property (point-at-bol) (point-at-eol) 'balls new-balls))
    (message "Point is not inside a section"))))

(defun superman-compute-columns-start ()
  (let* ((cols (get-text-property (point-at-bol) 'columns))
	 (n (- (length cols) 1))
	 (cumcols (list 0))
	 (i 1))
    (while (< i n)
      (setq cumcols (nconc cumcols (list (+ (nth i cols) (nth (- i 1) cumcols)))))
      (setq i (+ i 1)))
    cumcols))

(defun superman-next-ball (&optional arg)
  "Move to ARGth next column."
  (interactive "p")
  (if (get-text-property (point-at-bol) 'columns)
      (let* ((current (nth 2 (superman-ball-dimensions)))
	     (colstart (superman-compute-columns-start))
	     (j (max 0 (min (- (length colstart) 1)
			    (+ current arg)))))
	(beginning-of-line)
	(forward-char (+ superman-column-separator ;; offset for whole line
			 (nth j colstart))))
     (right-char 1)))

(defun superman-previous-ball ()
  "Move to previous column."
  (interactive)
  (if (get-text-property (point-at-bol) 'columns)
      (superman-next-ball -1)
    (left-char 1)))
    
(defun superman-one-right (&optional left)
  "Move column to the right."
  (interactive "P")
  (if (get-text-property (point-at-bol) 'column-names)
      ;; swap columns
      (let* ((dim (superman-ball-dimensions))
	 (balls (get-text-property (superman-cat-point) 'balls))
	 (buffer-read-only nil)
	 (new-balls (superman-swap-balls balls
					 (if left (- (nth 2 dim) 1)
					   (nth 2 dim))))
	 (beg (previous-single-property-change (point-at-bol) 'cat))
	 (end (or (next-single-property-change (point-at-eol) 'cat) (point-max))))
	;; (message (concat "Len!: " (int-to-string (length superman-document-balls))))
    (save-excursion
      (superman-change-balls new-balls)
      (superman-refresh-cat new-balls)))
    ;; swap projects
      (if left
	  (superman-previous-project)
	(superman-next-project))))
    
(defun superman-one-left ()
  "Move column to the left."
  (interactive)
  (superman-one-right 1))

(defun superman-delete-ball ()
  "Delete current column. The column will still pop-up when the
view is refreshed, but can be totally removed
by calling `superman-save-balls' subsequently."
  (interactive)
  (let* ((dim (superman-ball-dimensions))
	 (balls (get-text-property (superman-cat-point) 'balls))
	 (buffer-read-only nil)
	 (new-balls (remove-if (lambda (x) t) balls :start (nth 2 dim) :count 1))
	 (beg (previous-single-property-change (point-at-bol) 'cat))
	 (end (or (next-single-property-change (point-at-eol) 'cat) (point-max))))
    (save-excursion
      (superman-change-balls new-balls)
      (superman-refresh-cat new-balls))))

(defun superman-new-ball ()
  "Add a new column to show a property of all items in the
current section."
  (interactive)
  (let* ((balls (copy-sequence (get-text-property (superman-cat-point) 'balls)))
	 (buffer-read-only nil)
	 (props (superman-view-property-keys))
	 (prop (completing-read "Property to show in new column (press tab see existing): "
				(mapcar (lambda (x) (list x)) props) nil nil))
	 (len (string-to-int (read-string "Column width: ")))
	 (new-ball `(,prop ("width" ,len)))
	 (new-balls (add-to-list 'balls new-ball))
	 (beg (previous-single-property-change (point-at-bol) 'cat))
	 (end (or (next-single-property-change (point-at-eol) 'cat) (point-max))))
    (save-excursion
      (superman-change-balls new-balls)
      (superman-save-balls)
      (superman-refresh-cat new-balls))))


(defun superman-tab (&optional arg)
  "Move to next button in the header and call `org-cycle' in the body of the project view."
  (interactive)
  (cond ((not (previous-single-property-change (point-at-eol) 'cat))
	 (let ((current (get-text-property (point) 'superman-header-marker))
	       (mark (next-single-property-change (point) 'superman-header-marker)))
	   (if mark (progn (goto-char mark)
			   (when current
			     (goto-char (next-single-property-change (point) 'superman-header-marker))))
	     (goto-char (next-single-property-change (point) 'cat)))))
	 (t (org-cycle arg))))

(defun superman-shifttab (&optional arg)
  "Move to previous button in the header and call `org-shifttab' in the body of the project view."
  (interactive)
  (cond
   ((eq (point) (point-min))
    (org-shifttab arg))
   ((not (previous-single-property-change (point-at-eol) 'cat))
    (let ((current (get-text-property (point) 'superman-header-marker))
	  (mark (previous-single-property-change
		 (point) 'superman-header-marker)))
      (if mark
	  (progn (goto-char (- mark 1))
		 (when current (goto-char  (previous-single-property-change
					    (point) 'superman-header-marker))))
	(goto-char (point-min)))))
   (t (org-shifttab arg))))

(defun superman-one-up (&optional down)
  "Move item in project view up or down."
  (interactive "P")
  (let* ((marker (org-get-at-bol 'org-hd-marker))
	 (catp (org-get-at-bol 'cat))
	 (org-support-shift-select t)
	 (curcat (when catp (superman-current-cat))))
    (when (or catp marker)
      (save-excursion
	(set-buffer (marker-buffer marker))
	(goto-char marker)
	(widen)
	(or (condition-case nil
		(if down
		    (org-move-subtree-down)
		  (org-move-subtree-up))
	      (error nil))
	    (if down
		(progn
		  (put-text-property (point-at-bol) (point-at-eol) 'current-item 1)
		  (outline-next-heading)
		  (if (< (nth 0 (org-heading-components)) 2)
		      (error "Cannot move item outside category"))
		  (put-text-property (point-at-bol) (point-at-eol) 'next-item 1)
		  (org-demote)
		  (goto-char (previous-single-property-change (point) 'current-item))
		  (org-move-subtree-down)
		  (goto-char (previous-single-property-change (point) 'next-item))
		  (org-promote))
	      (put-text-property (point-at-bol) (point-at-eol) 'current-item 1)
	      (outline-previous-heading)
	      (if (< (nth 0 (org-heading-components)) 2)
		  (error "Cannot move item outside category"))
	      (put-text-property (point-at-bol) (point-at-eol) 'next-item 1)
	      (org-demote)
	      (goto-char (next-single-property-change (point) 'current-item))
	      (org-move-subtree-up)
	      (goto-char (next-single-property-change (point) 'next-item))
	      (org-promote))))
      (superman-redo)
      (if catp
	  (progn 
	    (goto-char (point-min))
	    (re-search-forward curcat nil t)
	    (beginning-of-line))
	;; (goto-char (if down
	;; (next-single-property-change (point-at-eol) 'cat)
	;; (previous-single-property-change (point-at-bol) 'cat)))
	(forward-line (if down 1 -1))))))

(defun superman-one-down ()
  (interactive)
  (superman-one-up 1))

(defun superman-cut ()
  (interactive)
  (if superman-view-mode
      (let ((marker (org-get-at-bol 'org-hd-marker))
	    (buffer-read-only nil)
	    (kill-whole-line t))
	(when marker
	  (beginning-of-line)
	  (kill-line)
	  (save-excursion
	    (set-buffer (marker-buffer marker))
	    (widen)
	    (show-all)
	    (goto-char marker)
	    (org-cut-subtree))))
    (message "can only cut in superman-view-mode")))

(defun superman-paste ()
  (interactive)
  (if superman-view-mode
      (let ((marker (org-get-at-bol 'org-hd-marker)))
	(when marker
	  (save-excursion
	    (set-buffer (marker-buffer marker))
	    (widen)
	    (show-all)
	    (goto-char marker)
	    (org-paste-subtree)))
	(superman-redo))
    (message "can only paste in superman-view-mode")))

;;}}}
;;{{{ Edit items

(defun superman-view-property-keys ()
  "Get a list of all property keys in current section"
  (let ((cat-point (superman-cat-point)))
    (when cat-point
      (save-excursion
	(org-with-point-at (get-text-property cat-point 'org-hd-marker)
	  (save-restriction
	  (widen)
	  (show-all)
	  (org-narrow-to-subtree)
	  ;; do not show properties of the section
	  ;; heading
	  (outline-next-heading)
	  (narrow-to-region (point) (point-max))
	  (superman-property-keys)))))))


(defun superman-view-edit-item ()
  "Put item at point into capture mode"
  (interactive)
  (let* ((marker (org-get-at-bol 'org-hd-marker))
	 (catp  (org-get-at-bol 'cat))
	 (E-buf (generate-new-buffer-name "*Edit by SuperMan*"))
	 (scene (current-window-configuration))
	 (all-props (if (or (not marker) catp) nil (superman-view-property-keys)))
	 range
	 (cat-point (superman-cat-point))
	 (balls (when cat-point
		  (get-text-property (superman-cat-point) 'balls)))
	 prop
	 used-props)
    (if (not marker)
	(if (setq marker (org-get-at-bol 'superman-e-marker))
	    nil
	  (message "Nothing to edit here")))
    ;; add properties defined by balls to all-props
    (when marker
      (while balls
	(when (stringp (setq prop (caar balls)))
	  (add-to-list
	   'all-props
	   prop))
	(setq balls (cdr balls)))
      (set-buffer (marker-buffer marker))
      (goto-char marker)
      (widen)
      (show-all)
      (switch-to-buffer
       (make-indirect-buffer (marker-buffer marker) E-buf))
      ;; narrow to section
      (org-narrow-to-subtree)
      ;; narrow to item
      (when (and cat-point
		 (not catp)
		 ;; (not (superman-get-property (point-min) "freeText"))
		 (outline-next-heading))
	(narrow-to-region (point-min) (point)))
      (org-mode)
      (show-all)
      (delete-other-windows)
      (goto-char (point-min))
      (put-text-property (point) (point-at-eol) 'edit-point (point))
      (insert "### Superman edit this " (if catp "section" "item")
	      "\n# C-c C-c to save "
	      "\n# C-c C-q to quit without saving"
	      "\n### ---yeah #%*^#@!--------------"
	      "\n\n")
      (goto-char (point-min))
      (put-text-property (point) (point-at-eol) 'scene scene)
      (put-text-property (point) (point-at-eol) 'type 'edit)
      (unless catp
	(if (re-search-forward org-property-start-re nil t)
	    (progn
	      (setq range (org-get-property-block))
	      (goto-char (car range))
	      (while (re-search-forward
		      (org-re "^[ \t]*:\\([-[:alnum:]_]+\\):")
		      (cdr range) t)
		(put-text-property (point) (+ (point) 1) 'prop-marker (point))
		(add-to-list 'used-props (org-match-string-no-properties 1)))
	      (goto-char (cdr range))
	      (forward-line -1)
	      (end-of-line))
	  (outline-next-heading)
	  (end-of-line)
	  (insert "\n:PROPERTIES:\n:END:\n")
	  (forward-line -2)
	  (end-of-line))
	(while all-props
	  (when (not (member (car all-props) used-props))
	    (insert "\n:" (car all-props) ": ")
	    (put-text-property (- (point) 1) (point) 'prop-marker (point)))
	  (setq all-props (cdr all-props))))
    (goto-char (next-single-property-change (point-min) 'edit-point))
    (end-of-line)
    (superman-capture-mode))))

;;}}}
;;{{{ Switch between projects

(defvar superman-project-history nil
  "List of projects that were previously selected
 in the current emacs session.")

(defun superman-next-project (&optional backwards)
  "Switch to next project in `superman-project-history'"
  (interactive "P")
  (let* ((next (if backwards
		   (car (reverse superman-project-history))
		 (cadr superman-project-history))))
	 ;; (phist
	  ;; (member (car superman-current-project)
		  ;; (if backwards
		      ;; (reverse superman-project-history)
		    ;; superman-project-history)))
	 ;; (next (cadr phist)))
    (when next
    (superman-switch-to-project
     (assoc
      next
      superman-project-alist)))))

(defun superman-previous-project ()
  "Switch to previous project in `superman-project-history'."
  (interactive)
  (superman-next-project t))

;;}}}
;;{{{ View commands (including redo and git) 

(defun superman-redo ()
  "Refresh project view."
  (interactive)
  (let ((curline (progn
		   (beginning-of-line)
		   (count-lines 1 (point))))
	cmd)
    (setq cmd (get-text-property (point-min) 'redo-cmd))
    (eval cmd)
    (goto-line (+ 1 curline))))

(defun superman-refresh-cat (new-balls)
  "Refresh view of all lines in current category inclusive column names."
  (interactive)
  (let ((start (superman-cat-point))
	(kill-whole-line t)
	(end (or (next-single-property-change (point) 'cat) (point-max))))
    (if (not start)
	(message "Point is not in category.")
      (superman-loop 'superman-view-redo-line nil start end nil)
      (goto-char (next-single-property-change start 'names))
      (beginning-of-line)
      (kill-line)
      (insert (superman-column-names new-balls) "\n"))))

(defun superman-view-redo-line (&optional marker balls)
  (interactive)
  (let* ((buffer-read-only nil)
	 (marker (or marker (get-text-property (point-at-bol) 'org-hd-marker)))
	 (balls (or balls (get-text-property (superman-cat-point) 'balls))))
    (when (and marker (not (get-text-property (point-at-bol) 'cat))
	       (not (get-text-property (point-at-bol) 'subcat)))
      (beginning-of-line)
      (let ((newline (superman-format-thing marker balls))
	    (beg (previous-single-property-change (point-at-eol) 'org-hd-marker))
	    (end (next-single-property-change (point) 'org-hd-marker)))
	(delete-region beg end)
	(insert newline)
	;; (if (looking-at ".*")
	    ;; (replace-match newline))
	(beginning-of-line)
	(while (or (org-activate-bracket-links (point-at-eol)) (org-activate-plain-links (point-at-eol)))
	  (add-text-properties
	   (match-beginning 0) (match-end 0)
	   '(face org-link)))
	(beginning-of-line)))))


(defun superman-view-toggle-todo ()
  (interactive)
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (when marker
      (save-excursion
	(org-with-point-at marker
	  (org-todo)
	  (save-buffer)))
      (superman-view-redo-line marker))))


(defun superman-view-priority-up ()
  (interactive)
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (when marker
      (save-excursion
	(org-with-point-at marker
	  (org-priority-up)
	  (save-buffer)))
      (superman-view-redo-line marker))))

(defun superman-view-priority-down ()
  (interactive)
  (let ((marker (org-get-at-bol 'org-hd-marker)))
    (when marker
      (save-excursion
	(org-with-point-at marker
	  (org-priority-down)
	  (save-buffer)))
      (superman-view-redo-line marker))))



(defun superman-next-entry ()
  (interactive)
  (forward-line 1))

  ;; (cond ((or (get-text-property (point-at-bol) 'org-marker)
	     ;; (get-text-property (point-at-bol) 'columns))
	 ;; (forward-line 1))
	;; ;; ((get-text-property (point-at-bol) 'sub-cat)
	;; ((or (get-text-property (point-at-bol) 'cat)
	     ;; (get-text-property (point-at-bol) 'sub-cat))
	 ;; (let* ((start (point-at-bol))
		;; (stop (save-excursion
			;; (goto-char start)
			;; (org-forward-heading-same-level 1)
			;; (if (= (point) start) (point-max)
			  ;; (point))))
		;; (nextsubcat (or (next-single-property-change (point-at-eol) 'subcat) (point-max)))
		;; (nextcat (or (next-single-property-change (point-at-eol) 'cat) (point-max)))
		;; (closecat (min nextcat nextsubcat)))
	   ;; ;; check if current section is folded
	   ;; (if (overlays-in start closecat)
	       ;; (goto-char closecat))))))

(defun superman-previous-entry ()
 (interactive)
  (previous-line 1))
  ;; ;; check if current section is folded
  ;; (let* ((end (point-at-eol))
	;; (prevsubcat (or (previous-single-property-change (point-at-bol) 'subcat) (point-min)))
	;; (prevcat (or (previous-single-property-change (point-at-bol) 'cat) (point-min)))
	;; (closecat (max prevcat prevsubcat)))	
    ;; (if (overlays-in closecat end)
	;; (goto-char closecat)
      ;; (goto-char
       ;; (or (previous-single-property-change (point-at-bol) 'org-hd-marker)
	    ;; (point-min))))
    ;; (beginning-of-line)
    ;; ))

(defun superman-view-delete-entry (&optional dont-prompt dont-redo do-delete-file)
  "Delet entry at point. Prompt user unless DONT-PROMT is non-nil. Redo the view-buffer
unless DONT-REDO is non-nil.

If point is before the first category do nothing."
  (interactive)
  (when (or (previous-single-property-change (point-at-bol) 'cat)
	    (get-text-property (point) 'cat))
    (let* ((marker (org-get-at-bol 'org-hd-marker))
	   (scene (current-window-configuration))
	   (file (superman-filename-at-point t))
	   (regret nil))
      (unless dont-prompt
	(superman-view-index)
	(org-narrow-to-subtree)
	(setq regret (not (yes-or-no-p "Delete this entry?"))))
      (set-window-configuration scene)
      (unless regret
	(when file
	  (when (and do-delete-file
		     (yes-or-no-p
		      (concat "Delete file "
			      (file-name-nondirectory file))))
	    (if (string-match
		 (superman-get-property marker "GitStatus")
		 "Committed\\|Modified\\|Unknown")
		(shell-command (concat
				"cd "
				(file-name-directory file)
				";"
				superman-cmd-git " rm -f "
				(file-name-nondirectory file)))
	      (when (file-exists-p file)
		(delete-file file)))))
	(when marker
	  (save-excursion
	    (org-with-point-at marker (org-cut-subtree))))))
    (unless dont-redo (superman-redo))))

(defun superman-view-delete-all (&optional dont-prompt)
  (interactive)
  (let ((beg (previous-single-property-change (point) 'cat))
	(buffer-read-only nil)
	(end (or (next-single-property-change (point) 'cat)
		 (point-max))))
    (narrow-to-region beg end)
    (when (yes-or-no-p "Delete all the marked entries in this section? ")
      (superman-loop 'superman-view-delete-entry '(t t) beg end 'marked)
      (widen)
      (superman-redo))))


(defun superman-view-git-status ()
  "Show git status of current project."
  (interactive)
  (let ((git-dir
	 (get-text-property (point-min) 'git-dir)))
    (superman-git-status git-dir)))

(defun superman-view-git-diff ()
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
    (file (org-link-display-format (superman-get-property m "filename"))))
    (find-file file)
  (vc-diff file "HEAD")))

(defun superman-view-git-diff-1 ()
  (interactive)
  (let ((m (org-get-at-bol 'org-hd-marker)))
    (if m
	(let* ((file (org-link-display-format (superman-get-property m "filename")))
	      (loc (file-name-directory file)))
	  ;; (find-file file)
	  (superman-run-cmd (concat "cd " loc  ";" superman-cmd-git " diff HEAD^^ "
				    file  "\n")
			    "*Superman-returns*"
			    "Superman returns the result of git diff HEAD^^ :"
			    nil))
      (message "No file-name at point. Maybe point is not at mouse click."))))


(defun superman-view-git-version-diff ()
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
	 (file (org-link-display-format (superman-get-property m "filename"))))
    (async-shell-command (concat "cd " (file-name-directory file) "; " superman-cmd-git " difftool " (file-name-nondirectory file)))))
	;; (find-file file)
      ;; (vc-version-diff file "master" nil)))

(defun superman-view-git-ediff ()
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
    (file (org-link-display-format (superman-get-property m "filename"))))
    (find-file file)
    (vc-ediff file "HEAD")))


(defun superman-annotate-version (&optional version)
  (interactive)
  (font-lock-mode -1)
  (save-excursion
    (let ((version (or version (buffer-substring (point-at-bol)
						 (progn (goto-char (point-at-bol))
							(forward-word)
							(point)))))
	  (buffer-read-only nil))
      (goto-char (point-min))
      (while (re-search-forward version nil t)
	(put-text-property (point-at-bol) (+ (point-at-bol) (length version))
			   'face 'font-lock-warning-face)
	(put-text-property
	 (progn (skip-chars-forward "^\\)")
		(+ (point) 1))
	 (point-at-eol)
	 'face 'font-lock-warning-face)))))


(defun superman-view-git-annotate (&optional arg)
  "Annotate file"
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
	 (bufn)
    (file (org-link-display-format (superman-get-property m "filename"))))
    (save-window-excursion
      (find-file file)
    (vc-annotate (org-link-display-format file) "HEAD")
    (setq bufn (buffer-name)))
    (switch-to-buffer bufn)))

(defun superman-view-git-grep (&optional arg)
  (interactive)
  (let ((dir (get-text-property (point-min) 'git-dir)))
    (when dir
      (if arg
	(vc-git-grep (read-string "Grep: "))
	(vc-git-grep (read-string "Grep: ") "*" dir)))))

(defun superman-view-git-history (&optional arg)
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
	 (file
	  ;; (or (if m (file-name-directory (org-link-display-format (superman-get-property m "filename"))))
	  (or (if m (org-link-display-format (superman-get-property m "filename")))
	      (get-text-property (point-min) 'git-dir)
	      (buffer-file-name)))
	 (dir (if m (file-name-directory file) (file-name-as-directory file)))
	 (curdir default-directory)
	 (bufn (concat "*history: " file "*"))
	)
    (when dir
      ;; (vc-print-log-internal
      ;;  'Git
      ;;  (list dir)
      ;;  nil nil 2000)      
      ;; (message dir)
      (save-window-excursion
	;;(superman-view-index)
	(setq default-directory dir)
	(vc-git-print-log file bufn t nil (or arg superman-git-log-limit))
	)
      (setq default-directory curdir)
      (switch-to-buffer bufn)
      (vc-git-log-view-mode)
)))

(defun superman-view-index ()
  (interactive)
  (let* ((pom (cond ((org-get-at-bol 'org-hd-marker))
		    ((org-get-at-bol 'column-names)
		     (get-text-property (superman-cat-point)
					'org-hd-marker))
		    ((org-get-at-bol 'superman-e-marker))))
	 (ibuf (or (and pom (marker-buffer pom))
		   (get-file-buffer
		    (get-text-property (point-min) 'index))
		   (find-file
		    (get-text-property (point-min) 'index))))
	 (iwin (when ibuf (get-buffer-window ibuf nil))))
    (if (and ibuf iwin)
	(select-window (get-buffer-window ibuf nil))
      ;; FIXME this should be customizable
      (split-window-vertically)
      (other-window 1)
      (if ibuf (switch-to-buffer ibuf)
	(find-file index)))
    (show-all)
    (widen)
    (when pom (goto-char pom))))
    ;;(org-narrow-to-subtree)

(defun superman-view-file-list ()
  (interactive)
  (let ((pro (superman-view-current-project)))
    (split-window-vertically)
    (other-window 1)
    (superman-file-list pro)))

(defun superman-view-dired ()
  (interactive)
  (let* (
	 (m (org-get-at-bol 'org-hd-marker))
	 (dir 
	  (or (if m (file-name-directory (org-link-display-format (superman-get-property m "filename"))))
	      (get-text-property (point-min) 'git-dir)
	      (default-directory))))
    (find-file dir)))

(defun superman-view-git-init ()
  (interactive)
  (or (get-text-property (point-min) 'git-dir)
    (let ((pro (superman-view-current-project)))
      (superman-git-init-directory (concat (superman-get-location pro) (car pro)))
      (superman-redo))))

(defun superman-hot-return ()
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
	 (b (superman-current-cat))
	 f)
    (if (not m)
	(save-excursion
	  (beginning-of-line)
	  (cond ((looking-at "Others")
		 (superman-capture-others
		  (assoc (get-text-property (point-min) 'nickname)
			 superman-project-alist))
		 (superman-redo))
		(t (error "Nothing to do here"))))
      (org-with-point-at m
	(cond (superman-mode
	       (superman-return))
	      ((re-search-forward org-any-link-re (save-excursion
						    (outline-end-of-subtree)
						    (point))t)
	       (org-open-at-point)
	       (widen))
	      (t
	       (widen)
	       (show-all)
	       (org-narrow-to-subtree)
	       (switch-to-buffer (marker-buffer m))))))))

(defun superman-view-git-log (&optional arg)
  (interactive "p")
  (superman-git-log-at-point (or arg superman-git-log-limit)))

(defun superman-view-git-log-decorationonly (&optional arg)
  (interactive "p")
  (superman-git-log-decorationonly-at-point (or arg superman-git-search-limit)))

(defun superman-view-git-search (&optional arg)
  (interactive "p")
  (superman-git-search-at-point (or arg superman-git-search-limit)))

(defun superman-view-git-set-status (&optional save redo check)
  (interactive)
  (let ((file (superman-filename-at-point t))
	(pom  (org-get-at-bol 'org-hd-marker)))
    (when
	file
      (superman-git-set-status pom file nil))))
      ;; (when save (superman-view-save-index-buffer))
      ;; (when redo (superman-redo)))))

(defun superman-view-save-index-buffer ()
  (save-excursion
    (let ((ibuf (get-file-buffer
		 (get-text-property (point-min) 'index))))
      (when ibuf (set-buffer ibuf)
	    (save-buffer)))))

(defun superman-filename-with-pom (&optional noerror)
  "Return property `superman-filename-at-point' at point,
if it exists and add text-property org-hd-marker."
  (let* ((file-or-link
	  (superman-property-at-point
	   (superman-property 'filename) noerror))
	 filename)
    (if (not (stringp file-or-link))
	(unless noerror
	  (error "No proper(ty) FileName at point."))
      (setq filename (org-link-display-format file-or-link))
      (put-text-property 0 (length filename) 'org-hd-marker
			 (org-get-at-bol 'org-hd-marker) filename)
      filename)))


(defun superman-view-git-update-status-with-date (&optional beg end dont-redo)
  (interactive)
  (superman-view-git-update-status nil beg end t dont-redo))
  
(defun superman-view-set-status-at-point ()
  (let ((pom (get-text-property (point-at-bol) 'org-hd-marker))
	(file (superman-filename-at-point t)))
    (if (and pom file)
	;; (ignore-errors
	  (superman-git-set-status pom file nil))))
				     
(defun superman-view-git-update-status (&optional dir beg end with-date dont-redo)
  "Update git status below DIR for all registered entries within BEG and END.

If WITH-DATE is nil run only the status of files between BEG and END. This works by
comparing the file-list with the result of git status (called once).

If WITH-DATE is non-nil run uncondionally through all entries between BEG and END that have
a filename and update both the status and the date of the last change.
This comes at the cost of separate calls to git status for each file, which can be
lengthy on some systems."
  (interactive)
  (let ((case-fold-search t)
	(dir (or dir (get-text-property (point-min) 'git-dir))))
    (if (not dir)
	(message "Argument DIR is required in this case.")
      ;; (shell-command-to-string "cd ~/emacs-genome/; git ls-files | while read file; do git log -n 1 --pretty=\"Filename:  $file, commit: %h, date: %ad\" -- $file; done")
      (if with-date
	  (superman-loop
	   'superman-view-set-status-at-point nil beg end nil)
	;; quickly update by comparing file lists
	(let* ((git-status-list
		;; (if with-date
		;; (delete
		;; ""
		;; (split-string
		;; (shell-command-to-string
		;; (concat "cd " dir ";" superman-cmd-git " ls-files | while read file; do git log -n 1 --pretty=\"$file,%h,%ad\" -- $file; done"))
		;; "\n"))
		(delete
		 ""
		 (split-string
		  (shell-command-to-string
		   (concat "cd " dir ";" superman-cmd-git " ls-files --full-name")) "\n")))
	       ;; )
	       (git-status
		(shell-command-to-string
		 (concat "cd " dir ";" superman-cmd-git " status --porcelain ")))
	       (status-list
		(when (not (string= git-status ""))
		  (delq nil
			(mapcar (lambda (x)
				  (if (string= "" x) nil
				    (let ((el (split-string x " ")))
				      (cons (caddr el) (cadr el)))))
				(split-string git-status "\n")))))
	       file)
	  ;; update status for all entries 
	  ;; by comparing the filename (if any) against git-status-list
	  (save-excursion
	    (when superman-view-mode
	      (set-buffer
	       (get-file-buffer
		(get-text-property (point-min) 'index))))
	    (goto-char (or beg (point-min)))
	    (while (and (re-search-forward ":filename:" end t)
			(setq file (superman-filename-at-point 'noerror)))
	      (let* ((status
		      (if (member (file-relative-name file dir) git-status-list)
			  (superman-status-label
			   (or (cdr (assoc (file-relative-name file dir)
					   status-list)) "C"))
			(if (file-exists-p file)
			    "Untracked" "Nonexistent")))
		     (current-status
		      (superman-get-property (point) "GitStatus")))
		(unless (or (string= status "Untracked") (string= status current-status))
		  (org-entry-put (point) (superman-property 'gitstatus) status)
		  (when (or
			 (string= (downcase status) "modified")
			 (and (stringp current-status)
			      (string= (downcase current-status) "modified")))
		    (superman-git-set-status (point) file nil))))))))
      (unless dont-redo (superman-redo)))))


(defun superman-view-git-push (&optional project)
  (interactive)
  (let* ((dir (get-text-property (point-min) 'git-dir))
	 cmd)
    (when dir
      (superman-goto-shell)
      (insert  (concat "cd " dir ";" superman-cmd-git " push")))))


(defun superman-view-git-commit (&optional dont-redo)
  "Add and commit the file given by the filename property
of the item at point.

If dont-redo the agenda is not reversed."
  (interactive)
  (let* ((filename (superman-filename-at-point))
	 (file (file-name-nondirectory filename))
	 (dir (if filename (expand-file-name (file-name-directory filename))))
	 (fbuf (get-file-buffer file)))
    (when (and fbuf
	       (with-current-buffer fbuf (buffer-modified-p))
	       (y-or-n-p (concat "Save buffer " fbuf "?")))
      (with-current-buffer fbuf (save-buffer)))
    (superman-git-add (list file) dir 'commit nil)
    (superman-git-set-status (org-get-at-bol 'org-hd-marker) file nil)
    (superman-view-redo-line)))
;; (superman-view-git-set-status 'save (not dont-redo) nil)))

(defun superman-view-marked-files (&optional beg end)
  (delq nil (superman-loop
	     #'(lambda ()
		 (or (and (superman-marked-p)
			  (superman-filename-at-point
			   'no-error)))) nil beg end)))

(defun superman-check-if-saved-needed
   () (member
       (expand-file-name (buffer-file-name)) files))

(defun superman-view-git-commit-all (&optional commit dont-redo)
  (interactive)
  (let* ((dir (get-text-property (point-min) 'git-dir))
	 (files
	  (mapcar 'expand-file-name 
		  (superman-view-marked-files))))
    ;; prevent committing unsaved buffers
    (save-some-buffers nil 'superman-check-if-saved-needed)
    (when dir
      (superman-git-add
       files
       dir
       'commit nil)
      (superman-view-git-update-status dir nil nil nil)
      (unless dont-redo (superman-redo)))))

;;}}}
;;{{{ View-mode and hot-keys

(defvar superman-view-mode-map (make-sparse-keymap)
  "Keymap used for `superman-view-mode' commands.")
   
(define-minor-mode superman-view-mode
     "Toggle superman project view mode.
With argument ARG turn superman-view-mode on if ARG is positive, otherwise
turn it off.
                   
Enabling superman-view mode electrifies the column view for documents
for git and other actions like commit, history search and pretty log-view."
     :lighter " *S*-View"
     :group 'org
     :keymap 'superman-view-mode-map)

(defun superman-view-mode-on ()
  (interactive)
  (when superman-hl-line (hl-line-mode 1))
  (superman-view-mode t))


(defun superman-view-second-link ()
  (interactive)
  (let* ((m (org-get-at-bol 'org-hd-marker))
	 (b (superman-current-cat))
	 f)
    (if (not m)
	(error "Nothing to do here")
      (org-with-point-at m
	(cond (superman-mode
	       (superman-return))
	      ((re-search-forward org-any-link-re nil t)
	       (re-search-forward org-any-link-re nil t)
	       (org-open-at-point))
	      (t
	       (widen)
	       (show-all)
	       (org-narrow-to-subtree)
	       (switch-to-buffer (marker-buffer m))))))))
	      ;; ((superman-view-index)
	       ;; (org-narrow-to-subtree)))))))


(define-key superman-view-mode-map [return] 'superman-hot-return)
(define-key superman-view-mode-map [(meta left)] 'superman-one-left)
(define-key superman-view-mode-map [(meta right)] 'superman-one-right)
(define-key superman-view-mode-map [(meta up)] 'superman-one-up)
(define-key superman-view-mode-map [(meta down)] 'superman-one-down)
(define-key superman-view-mode-map [(meta return)] 'superman-view-second-link)

(define-key superman-view-mode-map [(right)] 'superman-next-ball)
(define-key superman-view-mode-map [(left)] 'superman-previous-ball)
(define-key superman-view-mode-map [(control down)] 'superman-next-cat)
(define-key superman-view-mode-map [(control up)] 'superman-previous-cat)
(define-key superman-view-mode-map [(control n)] 'superman-next-cat)
(define-key superman-view-mode-map [(control p)] 'superman-previous-cat)
(define-key superman-view-mode-map "n" 'superman-next-entry)
(define-key superman-view-mode-map "p" 'superman-previous-entry)

(define-key superman-view-mode-map [(tab)] 'superman-tab)
(define-key superman-view-mode-map [(shift tab)] 'superman-shifttab)
(define-key superman-view-mode-map [S-iso-lefttab] 'superman-shifttab)
(define-key superman-view-mode-map [(up)] 'superman-previous-entry)
(define-key superman-view-mode-map [(down)] 'superman-next-entry)
(define-key superman-view-mode-map [(shift up)] 'superman-view-priority-up)
(define-key superman-view-mode-map [(shift down)] 'superman-view-priority-down)
(define-key superman-view-mode-map "i" 'superman-view-index)
(define-key superman-view-mode-map "I" 'superman-view-invert-marks)
(define-key superman-view-mode-map "e" 'superman-view-edit-item)
(define-key superman-view-mode-map "f" 'superman-view-dired)
(define-key superman-view-mode-map "F" 'superman-view-file-list)
(define-key superman-view-mode-map "m" 'superman-toggle-mark)
(define-key superman-view-mode-map "M" 'superman-view-mark-all)
(define-key superman-view-mode-map "r" 'superman-view-redo-line)
(define-key superman-view-mode-map "t" 'superman-view-toggle-todo)
(define-key superman-view-mode-map "x" 'superman-view-delete-entry)
(define-key superman-view-mode-map "X" 'superman-view-delete-all)
(define-key superman-view-mode-map "N" 'superman-new-item)
(define-key superman-view-mode-map "Q" 'superman-unison)
(define-key superman-view-mode-map "R" 'superman-redo)
(define-key superman-view-mode-map "S" 'superman-sort-section)
(define-key superman-view-mode-map "V" 'superman-change-view)
(define-key superman-view-mode-map "!" 'superman-goto-shell)
(define-key superman-view-mode-map "?" 'supermanual)

(define-key superman-view-mode-map "Bn" 'superman-new-ball)
(define-key superman-view-mode-map "Bx" 'superman-delete-ball)
(define-key superman-view-mode-map "Bs" 'superman-save-balls)

;; Git control
(define-key superman-view-mode-map "GA" 'superman-add-git-cycle)
;; (define-key superman-view-mode-map "GM" 'superman-view-git-master-push-pull-and-return)
(define-key superman-view-mode-map "Ga" 'superman-view-git-annotate)
(define-key superman-view-mode-map "Gc" 'superman-view-git-commit)
(define-key superman-view-mode-map "GC" 'superman-view-git-commit-all)
(define-key superman-view-mode-map "Gd" 'superman-view-git-diff)
(define-key superman-view-mode-map "Gg" 'superman-view-git-grep)
(define-key superman-view-mode-map "Gh" 'superman-view-git-history)
(define-key superman-view-mode-map "GI" 'superman-view-git-init)
(define-key superman-view-mode-map "Gl" 'superman-view-git-log)
(define-key superman-view-mode-map "GL" 'superman-view-git-log-decorationonly)
(define-key superman-view-mode-map "GP" 'superman-git-push)
(define-key superman-view-mode-map "Gs" 'superman-view-git-status)
(define-key superman-view-mode-map "GS" 'superman-view-git-search)
(define-key superman-view-mode-map "Gu" 'superman-view-git-update-status)
(define-key superman-view-mode-map "GU" 'superman-view-git-update-status-with-date)
(define-key superman-view-mode-map "GBs" 'superman-git-checkout-branch)
(define-key superman-view-mode-map "GBn" 'superman-git-new-branch)
(define-key superman-view-mode-map "G=" 'superman-view-git-version-diff)




(defvar superman-capture-alist nil
  "List to find capture function. Elements have the form
 (\"heading\" function) e.g.  (\"Documents\" superman-capture-document).")

(setq superman-capture-alist
      '(("Documents" superman-capture-document)
	("GitFiles" superman-capture-document)
	("Notes" superman-capture-note)
	("Tasks" superman-capture-task)
	("Text" superman-capture-text)
	("Meetings" superman-capture-meeting)
	("Bookmarks" superman-capture-bookmark)))

(fset 'superman-new-item 'superman-capture-item)
(defun superman-capture-item ()
  "Add a new document, note, task or other item to a project. If called
from superman project view, assoc a capture function from `superman-capture-alist'.
If non exists create a new item based on balls and properties in current section. If point is
not in a section prompt for section first.
"
  (interactive)
  (let* ((pro (or (superman-view-current-project t)
		  (superman-select-project)))
	 (marker (get-text-property (point-at-bol) 'org-hd-marker))
	 (cat (or (superman-current-cat)
		  (completing-read
		   (concat "Choose category for new item in project " (car  pro) ": ")
		   (append
		    superman-capture-alist
		    (superman-parse-cats
		     (get-file-buffer
		      (superman-get-index pro)) 1)))))
	 (fun (assoc cat superman-capture-alist)))
    (unless superman-view-mode
      (superman-view-project pro)
      (goto-char (point-min))
      (re-search-forward cat nil t))
    (if fun (funcall (cadr fun) pro)
      (let* ((props (mapcar #'(lambda (x) (list x nil))
			    (superman-view-property-keys)))
	     (file (if (assoc "FileName" props)
		       (let ((dir (expand-file-name (concat (superman-get-location pro) (car pro)))))
			 (read-file-name (concat "Add document to " (car pro) ": ") (file-name-as-directory dir))))))
	(unless props
	  (setq props `(("CaptureDate" ,(format-time-string "<%Y-%m-%d %a %R>")))))
	(when file
	  (setq props (delete (assoc "FileName" props) props))
	  (setq props (append `(("FileName" ,(concat "[["  (abbreviate-file-name file) "]]")))
			      props)))
	(superman-capture-internal
	 pro
	 (or marker cat)
	 `("Item" ,props))))))

;;}}}
;;{{{ easy menu

(require 'easymenu)
(easy-menu-define superman-menu superman-view-mode-map "*S*"
  '("Superman"
    ["Refresh view" superman-redo t]
    ["New project" superman-new-project t]
    ["New item" superman-new-item t]
    ["Edit item" superman-view-edit-item t]
    ["Toggle todo" superman-view-toggle-todo t]
    ["Mark item" superman-toggle-mark t]
    ["Mark all" superman-view-mark-all t]
    ["Invert mark" superman-view-invert-marks t]
    ["Delete item" superman-view-delete-entry t]
    ["Delete marked" superman-view-delete-all t]
    ["Move item up" superman-one-up t]
    ["Move item down" superman-one-down t]
    ["Visit index buffer" superman-view-index t]
    ["Dired" superman-view-dired t]
    ["File list" superman-view-file-list t]
    ("Git"
     ["Git history" superman-view-git-history t]
     ["Git update" superman-view-git-update-status t]
     ["Git update last commit date" superman-view-git-update-status-with-date t]
     ["Git commit" superman-view-git-commit t]
     ["Git commit all" superman-view-git-commit-all t]
     ["Git log" superman-view-git-log t]
     ["Git log (tagged versions)" superman-view-git-log-decorationonly t]
     ["Git grep" superman-view-git-grep t]
     ["Git annotate" superman-view-git-annotate t]
     ["Git search (only in log mode)" superman-view-git-search t]
     ["Git file-list" superman-capture-git-section t]
     ;; ["Git push" superman-git-push t]
     ;; ["Git checkout branch" superman-git-checkout-branch t]
     ;; ["Git new branch" superman-git-new-branch t]
     ["Git init" superman-view-git-init t])
    ("Columns (balls)"
     ["New column" superman-new-ball t]
     ["Delete column" superman-delete-ball t]
     ["Move column left" superman-one-left t]
     ["Move column right" superman-one-right t])
    ["Shell" superman-goto-shell t]
    ["Unison" superman-unison t]
    ))

;;}}}

(provide 'superman-views)

;;; superman-views.el ends here
