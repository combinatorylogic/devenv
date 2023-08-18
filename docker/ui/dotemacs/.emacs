(require 'package)
(setq package-check-signature nil)
(setq cpp-mode-rtags nil) ; set to t to enable the old rtags-based setup

;; Comment/uncomment these two lines to enable/disable MELPA and MELPA Stable as desired
(add-to-list 'package-archives (cons "melpa" "https://melpa.org/packages/") t)
;;(add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
(package-initialize)


(setq save-abbrevs 'silently)
(fset 'insertPound "#")
(global-set-key (kbd "£") 'insertPound)



(require 'cl)
;; C-h v package-activated-list
(defvar my-packages
  '(elpy pyvenv 
    cmake-mode racket-mode
    cmake-ide
    dracula-theme
    flycheck
    py-autopep8
    blacken
    better-defaults
    magit dockerfile-mode
    clang-format
    ivy
    helm company
    yaml-mode gitlab-ci-mode realgud-lldb
    lsp-mode yasnippet lsp-treemacs helm-lsp
    projectile hydra flycheck company avy which-key helm-xref dap-mode
   )
  "A list of packages"
  )

; I'll just leave it here - how to get a list of installed packages, if you added
; some manually and now want to regenerate this .emacs file:
;;;;;;;;;;;;;;;;;;;;;
;(defun strip-duplicates (list)
;  (let ((new-list nil))
;    (while list
;      (when (and (car list) (not (member (car list) new-list)))
;        (setq new-list (cons (car list) new-list)))
;      (setq list (cdr list)))
;    (nreverse new-list)))
;
;(message "%s" (strip-duplicates package-activated-list))

(defun my-packages-installed-p ()
  (loop for p in my-packages
        when (not (package-installed-p p)) do (return nil)
        finally (return t)))
 
(unless (my-packages-installed-p)
  ;; check for new packages (package versions)
  (package-refresh-contents)
  ;; install the missing packages
  (dolist (p my-packages)
    (when (not (package-installed-p p))
      (package-install p))))


;; Handle OpenCL files
(setq auto-mode-alist (cons '("\.cl$" . c-mode) auto-mode-alist))


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(c++-indent-level 2)
 '(c-basic-offset 2)
 '(fill-column 80)
 '(indent-tabs-mode nil)
 '(package-check-signature nil)
 '(lsp-clients-clangd-args '("--header-insertion-decorators=0"
                             "--background-index"
                             "-j=4"
                             ))
 '(safe-local-variable-values
   '((eval progn
           (c-set-offset 'innamespace '0)
           (c-set-offset 'inline-open '0)))))


(require 'better-defaults)

(setq load-path
      (cons (expand-file-name "~/.emacs.d/site-lisp/") load-path))

(require 'cmake-mode)

(setq auto-mode-alist
	  (append
	   '(("CMakeLists\\.txt\\'" . cmake-mode))
	   '(("\\.cmake\\'" . cmake-mode))
	   auto-mode-alist))

(setq org-log-done t)


(load-theme 'deeper-blue t)


;; add ess
;(require 'ess-site)


(setq ring-bell-function 'ignore)

;;;
;(setq python-shell-interpreter "python3")

(setq elpy-rpc-python-command "/usr/bin/python3")
(setq python-shell-interpreter "/usr/bin/python3")
(elpy-enable)

(when (require 'flycheck nil t)
  (setq elpy-modules (delq 'elpy-module-flymake elpy-modules))
  (add-hook 'elpy-mode-hook 'flycheck-mode))
(add-hook 'after-init-hook 'global-company-mode)

(require 'py-autopep8)
(add-hook 'elpy-mode-hook 'py-autopep8-enable-on-save)


(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
'(default ((t (:family "fixed" :foundry "misc" :slant normal :weight normal :height 113 :width normal))))
 )

(defconst extra-init-dir
  (cond ((boundp 'extra-init-directory)
         extra-init-directory)
        (t "/workdir/dotemacs")))


(defun load-user-file (file)
  (interactive "f")
  "Load a file from extra init directory if it's available"
  (let ((fn (expand-file-name file extra-init-dir)))
    (message fn)
    (if (file-exists-p fn)
        (load-file fn))))

;; You can put your own init.el in /workdir/dotemacs, to override anything
;; in this immutable /root/.emacs
(load-user-file "init.el")

;rtags

(if cpp-mode-rtags
    (progn
      (require 'rtags)
      (require 'company)
      (require 'company-rtags)

      (setq rtags-completions-enabled t)
      (eval-after-load 'company
        '(add-to-list
          'company-backends 'company-rtags))
      (setq rtags-autostart-diagnostics t)
      (rtags-enable-standard-keybindings)
      (require 'helm-rtags)
      (setq rtags-use-helm t)
      (setq company-async-timeout 15)

      (cmake-ide-setup))
  (progn
    ;; sample `helm' configuration use https://github.com/emacs-helm/helm/ for details
    (helm-mode)
    (require 'helm-xref)
    (define-key global-map [remap find-file] #'helm-find-files)
    (define-key global-map [remap execute-extended-command] #'helm-M-x)
    (define-key global-map [remap switch-to-buffer] #'helm-mini)
    
    (which-key-mode)
    (add-hook 'c-mode-hook 'lsp)
    (add-hook 'c++-mode-hook 'lsp)
    (add-hook 'c-ts-mode-hook 'lsp)
    (add-hook 'c++-ts-mode-hook 'lsp)
    
    (setq gc-cons-threshold (* 100 1024 1024)
          read-process-output-max (* 1024 1024)
          treemacs-space-between-root-nodes nil
          company-idle-delay 0.0
          company-minimum-prefix-length 1
          lsp-idle-delay 0.1)  ;; clangd is fast
    
    (with-eval-after-load 'lsp-mode
      (add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration)
      (require 'dap-cpptools)
      (yas-global-mode))
    ))


;;; Remove the lines below if you want to disable tree-sitter


(add-to-list 'major-mode-remap-alist
             '(c-mode . c-ts-mode)
             )
(add-to-list 'major-mode-remap-alist
             '(python-mode . python-ts-mode)
             )
(add-to-list 'major-mode-remap-alist
             '(c++-mode . c++-ts-mode)
             )


(add-to-list
 'treesit-language-source-alist
 '(python "https://github.com/tree-sitter/tree-sitter-python.git"))
(add-to-list
 'treesit-language-source-alist
 '(cpp "https://github.com/tree-sitter/tree-sitter-cpp.git"))
(add-to-list
 'treesit-language-source-alist
 '(c "https://github.com/tree-sitter/tree-sitter-c.git"))

