;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'color)

(defvar snow-flakes nil)

(defvar snow-amount 2)
(defvar snow-rate 0.09)
(defvar snow-timer nil)

(defgroup snow nil
  "Let it snow!"
  :group 'games)

(defface snow-face
  '((t :foreground "white"))
  "The face.")

(defvar snow-flake "*")

(defvar-local snow-string nil)

(cl-defstruct snowflake
  x y mass char overlay)

(defsubst clamp (min number max)
  "Return NUMBER clamped to between MIN and MAX, inclusive."
  (max min (min max number)))

(defsubst snowflake-color (mass)
  (let ((raw (/ (+ mass 155) 255)))
    (color-rgb-to-hex raw raw raw 2)))

(defun snowflake-get-flake (z)
  (propertize (pcase z
                ((pred (< 90)) (propertize "❄" 'face (list :foreground (snowflake-color z))))
                ((pred (< 50)) (propertize "*" 'face (list :foreground (snowflake-color z))))
                ((pred (< 10)) (propertize "." 'face'(list :foreground (snowflake-color z))))
                (_ (propertize "." 'face (list :foreground (snowflake-color z)))))))

(defun snow--update-buffer (buffer)
  (with-current-buffer buffer
    (let ((lines (window-text-height))
          (cols (window-width)))
      (setq snow-flakes
            (append snow-flakes
                    (cl-loop for i from 0 to (random snow-amount)
                             for x = (random cols)
                             for mass = (float (random 100))
                             for flake = (make-snowflake :x x :y 0 :mass mass :char (snowflake-get-flake mass))
                             do (snow-draw flake)
                             collect flake)))
      (setq snow-flakes
            (cl-loop for flake in snow-flakes
                     for new-flake = (progn
                                       ;; Calculate new flake position.
                                       (when (and (> (random 100) (snowflake-mass flake))
                                                  ;; Easiest way to just reduce the chance of X movement is to add another condition.
                                                  (> (random 3) 0))
                                         (cl-incf (snowflake-x flake) (pcase (random 2)
                                                                        (0 -1)
                                                                        (1 1)))
                                         (setf (snowflake-x flake) (clamp 0 (snowflake-x flake) (1- cols))))
                                       (when (> (random 100) (/ (- 100 (snowflake-mass flake)) 3))
                                         (cl-incf (snowflake-y flake)))
                                       (if (< (snowflake-y flake) (1- lines))
                                           (progn
                                             ;; Redraw flake
                                             (snow-draw flake)
                                             ;; Return moved flake
                                             flake)
                                         ;; Flake hit end of buffer: delete overlay.
                                         (delete-overlay (snowflake-overlay flake))))
                     when new-flake
                     collect new-flake)))
    (setq mode-line-format (format "%s flakes" (length snow-flakes)))))

(defun snow-draw (flake)
  (let ((pos (save-excursion
               (goto-char (point-min))
               (forward-line (snowflake-y flake))
               (forward-char (snowflake-x flake))
               (point))))
    (if (snowflake-overlay flake)
        (move-overlay (snowflake-overlay flake) pos (1+ pos))
      (setf (snowflake-overlay flake) (make-overlay pos (1+ pos)))
      (overlay-put (snowflake-overlay flake) 'display (snowflake-char flake)))))

(defun let-it-snow (&optional manual)
  (interactive "P")
  (with-current-buffer (get-buffer-create "*snow*")
    (if snow-timer
        (progn
          (cancel-timer snow-timer)
          (setq snow-timer nil))
      ;; Start
      (buffer-disable-undo)
      (setq-local cursor-type nil)
      (setq-local snow-string (propertize snow-flake 'face 'snow-face))
      (erase-buffer)
      (save-excursion
        (dotimes (_i (window-text-height))
          (insert (make-string (window-text-width) ? )
                  "\n"))
        (snow-insert-background :start-at -1))
      (goto-char (point-min))
      (setq snow-flakes nil)
      (use-local-map (make-sparse-keymap))
      (local-set-key (kbd "SPC") (lambda ()
                                   (interactive)
                                   (snow--update-buffer (current-buffer))))
      (unless manual
        (setq snow-timer
              (run-at-time nil snow-rate (apply-partially #'snow--update-buffer (current-buffer)))))
      (pop-to-buffer (current-buffer)))))

;;;; Overlay

(defcustom snow-background
  "
                                       __
                                     _|__|_             __
        /\\       /\\                   ('')            _|__|_
       /  \\     /  \\                <( . )>            ('')
       /  \\     /  \\               _(__.__)_  _   ,--<(  . )>
      /    \\   /    \\              |       |  )),`   (   .  )
       `||`     `||`               ==========='`       '--`-`          "
  "Background string."
  :type 'string)

(cl-defun snow-insert-background (&key (s snow-background) (start-at 0))
  (let* ((lines (split-string s "\n"))
         (height (length lines))
         (start-at (pcase start-at
                     (-1 (- (line-number-at-pos (point-max)) height 1))
                     (_ start-at))))
    (cl-assert (>= (line-number-at-pos (point-max)) height))
    (remove-overlays)
    (save-excursion
      (goto-char (point-min))
      (forward-line start-at)
      (cl-loop for line in lines
               do (progn
                    (setf (buffer-substring (point) (+ (point) (length line))) line)
                    (forward-line 1))))))
