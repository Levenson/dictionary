;; The MIT License (MIT)

;; Copyright (c) 2015 Aleksey Abramov <levenson@mmer.org>

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.


(require 'cl-lib)
(require 'dom)
(require 'url)

(defvar debug nil)

(defvar dictionary--url-thesaurus
  "http://www.thesaurus.com")

(defface dictionary--word-complexity
  '((((background dark)) :foreground "RosyBrown")
    (((background light)) :foreground "SlateGray"))
  "Face used for word complexity."
  :group 'dictionary--buffers-faces)


(defun dictionary--parse-mask (dom-item)
  "Parse `DOM-ITEM' and transform it to a string"
  (format "%s; %s"
	  (dom-text (dom-by-tag dom-item 'em))
	  (dom-text (dom-by-tag dom-item 'strong))))

(defun dictionary--parse-synonyms-0 (dom-block)
  "Extract and parse synonyms and antonyms `DOM-BLOCK' block and
return alist with candidates and its attributes."
  (flet ((parse-word (dom-block)
		     (cons (cons 'text (dom-text (dom-by-class dom-block "text")))
			   (dom-attributes (dom-by-tag dom-block 'a))))
	 ;; Parse synonyms & antonyms
	 (parse-nyms (dom-block)
		     (mapcar 'parse-word
			     (dom-by-tag dom-block 'li))))
    `((synonyms ,(parse-nyms (dom-by-class dom-block "relevancy-list")))
      (antonyms ,(parse-nyms (dom-by-class dom-block "container-info antonyms"))))))

(defun dictionary--browse-thesaurus (word)
  "Extract and parse thesaurus head and content of the `WORD' word."
  (let* ((dom (dictionary--html-content word  dictionary--url-thesaurus))
	 (div-head (dom-by-class dom "mask"))
	 (div-content (dom-by-id dom "content")))
    (values dom
	    (mapcar 'dictionary--parse-mask (dom-by-tag div-head 'li))
	    (dictionary--parse-synonyms-0 (dom-by-id div-content "synonyms-0")))))

(defun dictionary--html-content (word url)
  (let ((url-request-method "GET")
	(url-debug debug)
	(payload (concat "/browse/" (url-hexify-string (downcase word)))))
    (with-current-buffer
	(url-retrieve-synchronously (concat url payload))
      (goto-char (point-min))
      (message "Buffer: %S" (current-buffer))
      ;; Headers
      (forward-paragraph)
      ;; document
      (forward-line 2)
      (delete-region (point-min) (point))
      (libxml-parse-html-region (point-min) (point-max)))))

(defun dictionary--candidates-transformer (candidates)
  (cl-loop for candidate in (car candidates) collect
	   ;; candidate
	   (let ((class (if (cdr (assoc 'class candidate)) 0
			  (or (cdr (assoc 'data-complexity candidate)) 10))))
	     (mapconcat 'identity
			(list (propertize (format "%2s" class) 'face 'dictionary--word-complexity)
			      (cdr (assoc 'text candidate))) " "))))

(defun dictionary--candidates-transformer-not-found (candidates)
  (cl-loop for candidate in (car candidates) collect
	   (cdr (assoc 'text candidate))))

(defun dictionary--insert-word--at-point (str)
  (let ((begin (progn
		 (backward-word)
		 (point)))
	(end (progn
	       (forward-word)
	       (point))))
    (delete-region begin end))
  (insert (second (split-string str)))
  (let ((pos (cdr (bounds-of-thing-at-point 'symbol))))
    (when (and pos (< (point) pos))
      (push-mark pos t t))))


(defun dictionary--thesaurus-source-not-found (data)
  `(((name . "Did you mean?")
     (candidates . ,data)
     (candidate-transformer dictionary--candidates-transformer-not-found)
     (action . dictionary-helm-thesaurus-lookup))))
(defun dictionary--thesaurus-source-synonyms (data)
  `((name . "Synonyms")
    (candidates . ,data)
    (candidate-transformer dictionary--candidates-transformer)
    (action . (lambda (candidate)
		(with-helm-current-buffer
		  (dictionary--insert-word--at-point candidate))))))
(defun dictionary--thesaurus-source-antonyms (data)
  `((name . "Antonyms")
    (candidates . ,data)
    (candidate-transformer dictionary--candidates-transformer)
    (action . (lambda (candidate)
		(with-helm-current-buffer
		  (dictionary--insert-word--at-point candidate))))))

(defun dictionary--thesaurus-helm-source (word)
  (destructuring-bind (dom name data) (dictionary--browse-thesaurus word)
    (let ((result (dom-by-id dom "words-gallery-no-results"))
	  (syn (cdr (assoc 'synonyms data))))
      (if result
	  (dictionary--thesaurus-source-not-found syn)
	(let ((ant (cdr (assoc 'antonyms data))))
	  (list (dictionary--thesaurus-source-synonyms syn)
		(dictionary--thesaurus-source-antonyms ant)))))))

;;;###autoload
(defun dictionary-helm-thesaurus-lookup (word)
  (interactive (list
		(read-string (format "Word (%s): " (thing-at-point 'word))
			     nil nil (thing-at-point 'word))))
  (helm :sources (dictionary--thesaurus-helm-source word)
	:buffer "*helm dictionary*"))


(provide 'dictionary)
