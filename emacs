;; Turn on versioning and store all backups in a single directory
;; (debug-on-entry 'package-initialize)

(setq version-control t)              ; Numbered backups.
(setq backup-directory-alist          ; Backup directory
      `(("." . "~/tmp/emacsbak")))
(setq delete-old-versions t)

(require 'package)
(add-to-list 'package-archives
             '("melpa" . "http://melpa.org/packages/") t)
(when (< emacs-major-version 24)
  ;; For important compatibility libraries like cl-lib
  (add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/")))

;; wtf - I have 2 installs of 27.0.50 and one requires package-initialize
;; and the other complains it is redundant.
(unless package--initialized
  (package-initialize))

;;(swift-mode :repo "chrisbarrett/swift-mode" :fetcher github)

;; ===== Set standard indent ====
(setq standard-indent 4)        ;; 4 normally

;; C Mode Preferences
(defun my-c-mode-common-hook ()
 ;; my customizations for all of c-mode, c++-mode, objc-mode, java-mode
 (c-set-offset 'substatement-open 0)
 ;; other customizations can go here

 (setq c++-tab-always-indent t)
 (setq c-default-style "bsd")
 (setq c-basic-offset 4)                  ;; Default is 2

 (setq indent-tabs-mode t)  ; use spaces only if nil
 )

(add-hook 'c-mode-common-hook 'my-c-mode-common-hook)

;; ========== Enable Line and Column Numbering ==========
;; Show line-number in the mode line
(line-number-mode 1)

;; == Enable xterm mouse handling by default
(xterm-mouse-mode t)
(defun up-slightly () (interactive) (scroll-up 5))
(defun down-slightly () (interactive) (scroll-down 5))
(global-set-key (kbd "<mouse-4>") 'down-slightly)
(global-set-key (kbd "<mouse-5>") 'up-slightly)
;;(mouse-sel-mode t)
;;(defun track-mouse (arg))

(setq load-path
   (append (list "~/.local/lisp") load-path))

;; Show column-number in the mode line
(column-number-mode 1)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(column-number-mode t)
 '(custom-safe-themes
   '("708113858da6cb804b680583df66755e58fdcf4e906eec34ae891175d5c83a19" default))
 '(default-frame-alist
    '((tool-bar-lines . 1)
      (menu-bar-lines . 1)
      (right-fringe)
      (left-fringe)
      (width . 120)
      (height . 50)))
 '(gud-gdb-command-name "gdb --annotate=1")
 '(inhibit-startup-screen t)
 '(large-file-warning-threshold nil)
 '(package-selected-packages '(json-mode dracula-theme))
 '(safe-local-variable-values '((sh-basic-offset . 4) (sh-indent-comment . t))))

(load-theme 'dracula t)
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(font-lock-comment-face ((t (:foreground "#8882ee")))))

(defun on-after-init ()
  (unless (display-graphic-p (selected-frame))
    (if (> (display-planes) 8) ;; >8 is true color terminal. 256 color or less, don't set it at all ignoring theme
      (set-face-background 'default "#1C1D28" (selected-frame))
      (set-face-background 'default "unspecified-bg" (selected-frame)))))

(add-hook 'window-setup-hook 'on-after-init)

;; Install hook check to see if file is binary
(defun buffer-binary-p (&optional buffer)
  "Return whether BUFFER or the current buffer is binary.

A binary buffer is defined as containing at least on null byte in the first 4K.

Returns either nil, or the position of the first null byte."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (search-forward (string ?\x00) 4096 t 1))))

(defun hexl-if-binary ()
  "If `hexl-mode' is not already active, and the current buffer
is binary, activate `hexl-mode'."
  (interactive)
  (unless (eq major-mode 'hexl-mode)
    (when (buffer-binary-p)
      (hexl-mode))))

(defun what-face (pos)
  (interactive "d")
  (let((face (or (get-char-property pos 'face)
		 (get-char-property pos 'read-cf-name) )))
            (message " Face: %s" (or face "(no face!)")) ))

(add-hook 'find-file-hooks 'hexl-if-binary)

(global-set-key (kbd "C-x <pause>") 'save-buffers-kill-emacs)

