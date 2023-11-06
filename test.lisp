;;;; Tests
;;;; =====

(require "uiop")


;;; Test Definitions
;;; ----------------

(defparameter *pass* 0)
(defparameter *fail* 0)
(defvar *quit* nil)

(defun remove-directory (path)
  "Remove the specified directory tree from the file system."
  (uiop:delete-directory-tree (pathname path) :validate t
                                              :if-does-not-exist :ignore))

(defmacro test-case (name &body body)
  "Execute a test case and print pass or fail status."
  `(progn
     (remove-directory #p"test-tmp/")
     (ensure-directories-exist #p"test-tmp/")
     (let ((test-name (string-downcase ',name)))
       (format t "~&~a: " test-name)
       (handler-case (progn ,@body)
         (:no-error (c)
           (declare (ignore c))
           (incf *pass*)
           (format t "pass~%"))
         (error (c)
           (incf *fail*)
           (format t "FAIL~%")
           (format t "~&  ~a: error: ~a~%" test-name c)))
       (remove-directory #p"test-tmp/"))))

(defmacro test-case! (name &body body)
  "Execute a test case and error out on failure."
  `(progn
     (remove-directory #p"test-tmp/")
     (ensure-directories-exist #p"test-tmp/")
     (let ((test-name (string-downcase ',name)))
       (format t "~&~a: " test-name)
       ,@body
       (incf *pass*)
       (format t "pass!~%")
       (remove-directory #p"test-tmp/"))))

(defun test-done ()
  "Print test statistics."
  (format t "~&~%PASS: ~a~%" *pass*)
  (when (plusp *fail*)
    (format t "~&FAIL: ~a~%" *fail*))
  (when *quit*
    (format t "~&~%quitting ...~%~%")
    (uiop:quit (if (zerop *fail*) 0 1))))


;;; Begin Test Cases
;;; ----------------

(defvar *log-mode* nil)
(defvar *main-mode* nil)
(setf *log-mode* nil)
(setf *main-mode* nil)
(load "mathb.lisp")


;;; Test Mocks
;;; ----------

(defclass mock-request ()
  ((method :initarg :method :reader hunchentoot:request-method)
   (script-name :initarg :script-name :reader hunchentoot:script-name)))

(defun make-mock-request (method script-name)
  (make-instance 'mock-request :method method :script-name script-name))


;;; Test Cases for Reusable Definitions
;;; -----------------------------------

(test-case universal-time-string
  (string= (universal-time-string 0) "1900-01-01 00:00:00 +0000")
  (string= (universal-time-string 1) "1900-01-01 00:00:01 +0000")
  (string= (universal-time-string 86399) "1900-01-01 23:59:59 +0000")
  (string= (universal-time-string 86400) "1900-01-02 00:00:00 +0000")
  (string= (universal-time-string 86401) "1900-01-02 00:00:01 +0000")
  (string= (universal-time-string 3541622400) "2012-03-25 00:00:00 +0000"))

(test-case make-directory
  (make-directory "test-tmp/foo/bar/")
  (assert (directory-exists-p "test-tmp/foo/bar/")))

(test-case remove-directory
  (make-directory "test-tmp/foo/bar/")
  (assert (directory-exists-p "test-tmp/foo/bar/"))
  (remove-directory "test-tmp/foo/")
  (assert (not (directory-exists-p "test-tmp/foo/"))))

(test-case read-write-file-single-line
  (let ((text "foo"))
    (write-file "test-tmp/foo.txt" text)
    (assert (string= (read-file "test-tmp/foo.txt") text))))

(test-case read-write-file-multiple-lines
  (let ((text (format nil "foo~%bar~%baz~%")))
    (write-file "test-tmp/foo.txt" text)
    (assert (string= (read-file "test-tmp/foo.txt") text))))

(test-case read-write-file-nested-directories
  (write-file "test-tmp/foo/bar/baz/qux.txt" "foo")
  (assert (string= (read-file "test-tmp/foo/bar/baz/qux.txt") "foo")))

(test-case append-file-single-line
  (append-file "test-tmp/foo.txt" "foo")
  (assert (string= (read-file "test-tmp/foo.txt") "foo")))

(test-case append-file-multiple-lines
  (append-file "test-tmp/foo.txt" "foo")
  (append-file "test-tmp/foo.txt" (format nil "bar~%"))
  (append-file "test-tmp/foo.txt" "baz")
  (append-file "test-tmp/foo.txt" (format nil "qux~%"))
  (assert (string= (read-file "test-tmp/foo.txt")
                   (format nil "foobar~%bazqux~%"))))

(test-case append-file-nested-directories
  (append-file "test-tmp/foo/bar/baz/qux.txt" "foo")
  (append-file "test-tmp/foo/bar/baz/qux.txt" "bar")
  (assert (string= (read-file "test-tmp/foo/bar/baz/qux.txt") "foobar")))

(test-case write-log
  (write-log "~a, ~a" "hello" "world"))

(test-case string-starts-with
  ;; The formatting might be a bit grody, but at least adding more test cases is
  ;; trivial.
  (let ((startsWith (list (list "" "")
                          (list "foo" "foo" "foobar")))
        (doesNotStartWith (list (list "bazfoobar" "foo" "fo" "fox" "foO"))))

    (assert (every
      (lambda (m) (every
        (lambda (matchingWord)
          (string-starts-with (car m) matchingWord))
        (cdr m)))
      startsWith))

    (assert (every
      (lambda (d) (notany
        (lambda (nonMatchingWord)
          (string-starts-with (car d) nonMatchingWord))
        (cdr d)))
      doesNotStartWith))))

(test-case string-replace-single
  (let ((replaceEqualities (list
           (list "foo" "foo" "foo" "foo")
           (list "foo" "bar" "" "")
           (list "foo" "bar" "foo" "bar")
           (list "foo" "bar" "foofoo" "barbar")
           (list "foo" "bar" "foo foo" "bar bar"))))
    (assert (every
      (lambda (e)
        (string= (apply #'string-replace (subseq e 0 3)) (nth 3 e)))
      replaceEqualities))))

(test-case string-replace-multiple
  (assert (string= (string-replace "foo" "x" "foo:foo") "x:x"))
  (assert (string= (string-replace "foo" "x" "foo:foo:") "x:x:")))

(test-case string-trim-whitespace
  (assert (string= (string-trim-whitespace "") ""))
  (assert (string= (string-trim-whitespace " ") ""))
  (assert (string= (string-trim-whitespace " x  ") "x"))
  (assert (string= (string-trim-whitespace (format nil "~%x~%")) "x"))
  (assert (string= (string-trim-whitespace (format nil "x~a" #\Tab)) "x"))
  (assert (string= (string-trim-whitespace (format nil "x~a" #\Return)) "x"))
  (assert (string= (string-trim-whitespace (format nil "x~a" #\Newline)) "x")))

(test-case fix-lines
  (assert (string= (fix-lines (format nil "")) ""))
  (assert (string= (fix-lines (format nil "~c" #\Return)) ""))
  (assert (string= (fix-lines (format nil "~c~%" #\Return)) (format nil "~%")))
  (assert (string= (fix-lines (format nil "a~c" #\Return)) (format nil "a")))
  (assert (string= (fix-lines (format nil "foo~%")) (format nil "foo~%"))))

(test-case weekday-name
  (assert (string= (weekday-name 0) "Mon"))
  (assert (string= (weekday-name 1) "Tue"))
  (assert (string= (weekday-name 2) "Wed"))
  (assert (string= (weekday-name 3) "Thu"))
  (assert (string= (weekday-name 4) "Fri"))
  (assert (string= (weekday-name 5) "Sat"))
  (assert (string= (weekday-name 6) "Sun")))

(test-case month-name
  (assert (string= (month-name 1) "Jan"))
  (assert (string= (month-name 2) "Feb"))
  (assert (string= (month-name 3) "Mar"))
  (assert (string= (month-name 4) "Apr"))
  (assert (string= (month-name 5) "May"))
  (assert (string= (month-name 6) "Jun"))
  (assert (string= (month-name 7) "Jul"))
  (assert (string= (month-name 8) "Aug"))
  (assert (string= (month-name 9) "Sep"))
  (assert (string= (month-name 10) "Oct"))
  (assert (string= (month-name 11) "Nov"))
  (assert (string= (month-name 12) "Dec")))

(test-case decode-weekday-name
  (assert (string= (decode-weekday-name 2019 01 07) "Mon"))
  (assert (string= (decode-weekday-name 2019 03 05) "Tue"))
  (assert (string= (decode-weekday-name 2020 01 01) "Wed"))
  (assert (string= (decode-weekday-name 2020 02 27) "Thu"))
  (assert (string= (decode-weekday-name 2020 02 28) "Fri"))
  (assert (string= (decode-weekday-name 2020 02 29) "Sat"))
  (assert (string= (decode-weekday-name 2020 03 01) "Sun")))

(test-case simple-date
  (assert (string= (simple-date "2012-03-25 00:00:00 +0000")
                   "Sun, 25 Mar 2012 00:00 GMT"))
  (assert (string= (simple-date "2022-08-01 09:10:11 +0000")
                   "Mon, 01 Aug 2022 09:10 GMT")))

(test-case alist-get
  (assert (not (alist-get nil nil)))
  (assert (not (alist-get "a" nil)))
  (assert (not (alist-get "" '(("a" . "apple") ("b" . "ball")))))
  (assert (string= (alist-get "a" '(("a" . "apple") ("b" . "ball"))) "apple")))

(test-case lock-behaviour
  (assert (lock "test-tmp/"))
  (assert (not (lock "test-tmp/")))
  (unlock "test-tmp/")
  (assert (lock "test-tmp/"))
  (unlock "test-tmp/"))

(test-case lock-implementation
  (lock "test-tmp/")
  (assert (directory-exists-p "test-tmp/lock/"))
  (unlock "test-tmp/")
  (assert (not (directory-exists-p "test-tmp/lock/"))))


;;; Test Cases for Tool Definitions
;;; -------------------------------

(test-case home-request-p
  (assert (home-request-p (make-mock-request :get "/")))
  (assert (home-request-p (make-mock-request :head "/")))
  (assert (not (home-request-p (make-mock-request :post "/"))))
  (assert (not (home-request-p (make-mock-request :get "/foo"))))
  (assert (not (home-request-p (make-mock-request :head "/foo"))))
  (assert (not (home-request-p (make-mock-request :post "/foo")))))

(test-case meta-request-p
  (assert (meta-request-p (make-mock-request :get "/0")))
  (assert (meta-request-p (make-mock-request :head "/0")))
  (assert (not (meta-request-p (make-mock-request :post "/0"))))
  (assert (not (meta-request-p (make-mock-request :get "/"))))
  (assert (not (meta-request-p (make-mock-request :head "/"))))
  (assert (not (meta-request-p (make-mock-request :post "/"))))
  (assert (not (meta-request-p (make-mock-request :get "/-1"))))
  (assert (not (meta-request-p (make-mock-request :head "/-1"))))
  (assert (not (meta-request-p (make-mock-request :post "/-1"))))
  (assert (not (meta-request-p (make-mock-request :get "/123"))))
  (assert (not (meta-request-p (make-mock-request :post "/123"))))
  (assert (not (meta-request-p (make-mock-request :post "/123")))))

(test-case math-request-p
  (assert (math-request-p (make-mock-request :get "/1")))
  (assert (math-request-p (make-mock-request :head "/1")))
  (assert (math-request-p (make-mock-request :get "/123")))
  (assert (math-request-p (make-mock-request :head "/123")))
  (assert (not (math-request-p (make-mock-request :post "/123"))))
  (assert (not (math-request-p (make-mock-request :get "/"))))
  (assert (not (math-request-p (make-mock-request :head "/"))))
  (assert (not (math-request-p (make-mock-request :post "/"))))
  (assert (not (math-request-p (make-mock-request :get "/0"))))
  (assert (not (math-request-p (make-mock-request :head "/0"))))
  (assert (not (math-request-p (make-mock-request :post "/0"))))
  (assert (not (math-request-p (make-mock-request :get "/-1"))))
  (assert (not (math-request-p (make-mock-request :head "/-1"))))
  (assert (not (math-request-p (make-mock-request :post "/-1")))))

(test-case post-request-p
  (assert (not (post-request-p (make-mock-request :get "/"))))
  (assert (not (post-request-p (make-mock-request :head "/"))))
  (assert (post-request-p (make-mock-request :post "/")))
  (assert (not (post-request-p (make-mock-request :get "/foo"))))
  (assert (not (post-request-p (make-mock-request :head "/foo"))))
  (assert (not (post-request-p (make-mock-request :post "/foo")))))

(test-case slug-to-path
  (assert (string= (slug-to-path "/x/" 1) "/x/post/0/0/1.txt"))
  (assert (string= (slug-to-path "/x/" 12) "/x/post/0/0/12.txt"))
  (assert (string= (slug-to-path "/x/" 123) "/x/post/0/0/123.txt"))
  (assert (string= (slug-to-path "/x/" 1234) "/x/post/0/1/1234.txt"))
  (assert (string= (slug-to-path "/x/" 12345) "/x/post/0/12/12345.txt"))
  (assert (string= (slug-to-path "/x/" 123456) "/x/post/0/123/123456.txt"))
  (assert (string= (slug-to-path "/x/" 1234567) "/x/post/1/1234/1234567.txt"))
  (assert (string= (slug-to-path "/x/" 12345678) "/x/post/12/12345/12345678.txt")))

(test-case split-text
  (let ((text (format nil "foo~%~%")))
    (multiple-value-bind (head body) (split-text text)
      (assert (string= head (format nil "foo~%")))
      (assert (string= body (format nil "")))))
  (let ((text (format nil "foo~%~%bar")))
    (multiple-value-bind (head body) (split-text text)
      (assert (string= head (format nil "foo~%")))
      (assert (string= body (format nil "bar")))))
  (let ((text (format nil "foo~%~%bar~%")))
    (multiple-value-bind (head body) (split-text text)
      (assert (string= head (format nil "foo~%")))
      (assert (string= body (format nil "bar~%")))))
  (let ((text (format nil "foo~%~%~%bar~%")))
    (multiple-value-bind (head body) (split-text text)
      (assert (string= head (format nil "foo~%")))
      (assert (string= body (format nil "~%bar~%")))))
  (let ((text (format nil "foo~%bar~%baz~%~%quux~%quuz~%")))
    (multiple-value-bind (head body) (split-text text)
      (assert (string= head (format nil "foo~%bar~%baz~%")))
      (assert (string= body (format nil "quux~%quuz~%"))))))

(test-case parse-headers
  (assert (equal (parse-headers (format nil "a: apple~%"))
                 (list (cons "a" "apple"))))
  (assert (equal (parse-headers (format nil "a: apple~%b: ball~%"))
                 (list (cons "b" "ball") (cons "a" "apple"))))
  (assert (equal (parse-headers (format nil "a: apple~%b: ball~%"))
                 (list (cons "b" "ball") (cons "a" "apple"))))
  (assert (equal (parse-headers (format nil "a:~%"))
                 (list (cons "a" ""))))
  (assert (equal (parse-headers (format nil "a:~%b:~%c: cat~%"))
                 (list (cons "c" "cat") (cons "b" "") (cons "a" ""))))
  (assert (equal (parse-headers (format nil "a: ~%b: ~%c: cat~%"))
                 (list (cons "c" "cat") (cons "b" "") (cons "a" "")))))

(test-case parse-text
  (let ((text (format nil "Date: 2012-03-25 00:00:00 +0000~%~%Foo")))
    (multiple-value-bind (date title name body) (parse-text text)
      (assert (string= date "2012-03-25 00:00:00 +0000"))
      (assert (not title))
      (assert (not name))
      (assert (string= body "Foo"))))
  (let ((text "Date: 2012-03-25 00:00:00 +0000
Title: Hello World
Name: Alice

Foo
Bar"))
    (multiple-value-bind (date title name body) (parse-text text)
      (assert (string= date "2012-03-25 00:00:00 +0000"))
      (assert (string= title "Hello World"))
      (assert (string= name "Alice"))
      (assert (string= body (format nil "Foo~%Bar"))))))

(test-case increment-slug
  (assert (= (increment-slug "test-tmp/" 0) 1))
  (assert (= (increment-slug "test-tmp/" 0) 2))
  (assert (= (increment-slug "test-tmp/" 0) 3))
  (lock "test-tmp/")
  (assert (not (increment-slug "test-tmp/" 0)))
  (unlock "test-tmp/")
  (assert (= (increment-slug "test-tmp/" 0) 4))
  (assert (= (increment-slug "test-tmp/" 0) 5)))

(test-case increment-slug-protected
  (assert (= (increment-slug "test-tmp/" 0) 1))
  (assert (= (increment-slug "test-tmp/" 1) 2))
  (assert (not (increment-slug "test-tmp/" 3)))
  (assert (not (increment-slug "test-tmp/" 4)))
  (assert (= (increment-slug "test-tmp/" 2) 3)))

(test-case make-text
  (assert (string= (make-text "" "" "" "")
                   (format nil "Date:~%Title:~%Name:~%~%~%")))
  (assert (string= (make-text "date" "" "" "")
                   (format nil "Date: date~%Title:~%Name:~%~%~%")))
  (assert (string= (make-text "" "title" "" "")
                   (format nil "Date:~%Title: title~%Name:~%~%~%")))
  (assert (string= (make-text "" "" "name" "")
                   (format nil "Date:~%Title:~%Name: name~%~%~%")))
  (assert (string= (make-text "" "" "" "code")
                   (format nil "Date:~%Title:~%Name:~%~%code~%")))
  (assert (string= (make-text "date" "title" "name" "body")
                   (format nil "Date: date~%Title: title~%Name: name~%~%body~%"))))

(test-case set-flood-data
  (let ((x 0)
        (y (make-hash-table :test #'equal)))
    (set-flood-data "ip1" 1000 x y)
    (assert (= x 1000))
    (assert (= (gethash "ip1" y) 1000))))

(test-case improper-code-p
  (assert (not (improper-code-p nil "foo")))
  (assert (not (improper-code-p '(:expect ("foo")) "foo")))
  (assert (not (improper-code-p '(:expect ("foo" "bar")) "foo")))
  (assert (not (improper-code-p '(:expect ("foo" "bar")) "bar")))
  (assert (not (improper-code-p '(:expect ("foo" "bar")) "foobarbaz")))
  (assert (improper-code-p '(:expect ("bar")) "foo"))
  (assert (improper-code-p '(:expect ("bar" "baz")) "foo")))

(test-case dodgy-content-p
  (assert (not (dodgy-content-p nil "foo" "bar" "qux")))
  (assert (not (dodgy-content-p '(:block ("quux")) "foo" "bar" "qux")))
  (assert (not (dodgy-content-p '(:block ("bar")) "b" "a" "r")))
  (assert (dodgy-content-p '(:block ("foo")) "foo" "bar" "qux"))
  (assert (dodgy-content-p '(:block ("bar")) "foo" "bar" "qux"))
  (assert (dodgy-content-p '(:block ("qux")) "foo" "bar" "qux"))
  (assert (dodgy-content-p '(:block ("bar")) "foobarqux" "" ""))
  (assert (dodgy-content-p '(:block ("bar")) "" "foobarqux" ""))
  (assert (dodgy-content-p '(:block ("bar")) "" "" "foobarqux"))
  (assert (dodgy-content-p '(:block ("bar")) "" "" "foobarqux"))
  (assert (dodgy-content-p '(:block ("foo" "bar" "baz")) "foo" "" ""))
  (assert (dodgy-content-p '(:block ("foo" "bar" "baz")) "" "bar" ""))
  (assert (dodgy-content-p '(:block ("foo" "bar" "baz")) "" "" "baz"))
  (assert (dodgy-content-p '(:block ("foo" "bar" "baz")) "foobarbaz" "" ""))
  (assert (dodgy-content-p '(:block ("foo" "bar" "baz")) "" "foobarbaz" ""))
  (assert (dodgy-content-p '(:block ("foo" "bar" "baz")) "" "" "foobarbaz")))

(test-case dodgy-ip-p
  (assert (not (dodgy-ip-p nil "ip1")))
  (assert (not (dodgy-ip-p '(:ban nil) "ip1")))
  (assert (not (dodgy-ip-p '(:ban ("ip1$")) "ip12")))
  (assert (not (dodgy-ip-p '(:ban ("ip2")) "ip1")))
  (assert (not (dodgy-ip-p '(:ban ("ip2" "ip3")) "ip1")))
  (assert (not (dodgy-ip-p '(:ban ("ip1" "ip2")) "xip123")))
  (assert (string= (dodgy-ip-p '(:ban ("ip1")) "ip1") "ip1"))
  (assert (string= (dodgy-ip-p '(:ban ("ip1$")) "ip1") "ip1"))
  (assert (string= (dodgy-ip-p '(:ban ("ip1")) "ip12") "ip12"))
  (assert (string= (dodgy-ip-p '(:ban ("ip1")) "ip123") "ip123"))
  (assert (string= (dodgy-ip-p '(:ban ("ip1" "ip2" "ip3$")) "ip1") "ip1"))
  (assert (string= (dodgy-ip-p '(:ban ("ip1" "ip2" "ip3$")) "ip2") "ip2"))
  (assert (string= (dodgy-ip-p '(:ban ("ip1" "ip2" "ip3$")) "ip3") "ip3")))

(test-case client-flood-p-no-options
  (let ((table (make-hash-table :test #'equal)))
    (assert (not (client-flood-p nil "ip1" 1000 table)))))

(test-case client-flood-p-no-interval
  (let ((table (make-hash-table :test #'equal))
        (options '(:client-post-interval nil)))
    (assert (not (client-flood-p options "ip1" 1000 table)))))

(test-case client-flood-p-one-client
  (let ((table (make-hash-table :test #'equal))
        (options '(:client-post-interval 10)))
    (assert (not (client-flood-p options "ip1" 1000 table)))
    (setf (gethash "ip1" table) 1000)
    (assert (= (client-flood-p options "ip1" 1001 table) 9))
    (assert (= (client-flood-p options "ip1" 1005 table) 5))
    (assert (= (client-flood-p options "ip1" 1009 table) 1))
    (assert (not (client-flood-p options "ip1" 1010 table)))))

(test-case client-flood-p-two-clients
  (let ((table (make-hash-table :test #'equal))
        (options '(:client-post-interval 10)))
    (assert (not (client-flood-p options "ip1" 1000 table)))
    (assert (not (client-flood-p options "ip2" 1003 table)))
    (setf (gethash "ip1" table) 1000)
    (setf (gethash "ip2" table) 1003)
    (assert (= (client-flood-p options "ip1" 1001 table) 9))
    (assert (= (client-flood-p options "ip1" 1005 table) 5))
    (assert (= (client-flood-p options "ip1" 1009 table) 1))
    (assert (not (client-flood-p options "ip1" 1010 table)))
    (assert (= (client-flood-p options "ip2" 1001 table) 12))
    (assert (= (client-flood-p options "ip2" 1005 table) 8))
    (assert (= (client-flood-p options "ip2" 1009 table) 4))
    (assert (not (client-flood-p options "ip2" 1013 table)))))

(test-case reject-post-p-good
  (let ((x (write-to-string (calc-token 123))))
    (assert (not (reject-post-p nil "ip1" 0 "foo" "bar" "baz" x)))
    (assert (not (reject-post-p '(:block ("quux")) "ip1" 0 "foo" "bar" "baz" x)))))

(test-case reject-post-p-read-only
  (let ((x (write-to-string (calc-token 123))))
    (assert (string= (reject-post-p '(:read-only t) "ip1" 0 "foo" "bar" "baz" x)
                     "New posts have been disabled temporarily!"))))

(test-case reject-post-p-title-length
  (let ((x (write-to-string (calc-token 123)))
        (opt '(:min-title-length 2 :max-title-length 4)))
    (assert (not (reject-post-p nil "ip1" 0 "" "bar" "baz" x)))
    (assert (string= (reject-post-p opt "ip1" 0 "" "bar" "baz" x)
                     "Title must contain at least 2 characters!"))
    (assert (string= (reject-post-p opt "ip1" 0 "a" "bar" "baz" x)
                     "Title must contain at least 2 characters!"))
    (assert (not (reject-post-p opt "ip1" 0 "ab" "bar" "baz" x)))
    (assert (not (reject-post-p opt "ip1" 0 "abcd" "bar" "baz" x)))
    (assert (string= (reject-post-p opt "ip1" 0 "abcde" "bar" "baz" x)
                     "Title must not contain more than 4 characters!"))))

(test-case reject-post-p-name-length
  (let ((x (write-to-string (calc-token 123)))
        (opt '(:min-name-length 2 :max-name-length 4)))
    (assert (not (reject-post-p nil "ip1" 0 "foo" "" "baz" x)))
    (assert (string= (reject-post-p opt "ip1" 0 "foo" "" "baz" x)
                     "Name must contain at least 2 characters!"))
    (assert (string= (reject-post-p opt "ip1" 0 "foo" "a" "baz" x)
                     "Name must contain at least 2 characters!"))
    (assert (not (reject-post-p opt "ip1" 0 "foo" "ab" "baz" x)))
    (assert (not (reject-post-p opt "ip1" 0 "foo" "abcd" "baz" x)))
    (assert (string= (reject-post-p opt "ip1" 0 "foo" "abcde" "baz" x)
                     "Name must not contain more than 4 characters!"))))

(test-case reject-post-p-code-length
  (let ((x (write-to-string (calc-token 123)))
        (opt '(:min-code-length 2 :max-code-length 4)))
    (assert (string= (reject-post-p nil "ip1" 0 "foo" "bar" "" x)
                     "Code must contain at least 1 character!"))
    (assert (string= (reject-post-p opt "ip1" 0 "foo" "bar" "" x)
                     "Code must contain at least 2 characters!"))
    (assert (string= (reject-post-p opt "ip1" 0 "foo" "bar" "a" x)
                     "Code must contain at least 2 characters!"))
    (assert (not (reject-post-p opt "ip1" 0 "foo" "bar" "ab" x)))
    (assert (not (reject-post-p opt "ip1" 0 "foo" "bar" "abcd" x)))
    (assert (string= (reject-post-p opt "ip1" 0 "foo" "bar" "abcde" x)
                     "Code must not contain more than 4 characters!"))))

(test-case reject-post-p-title-has-line-break
  (let ((x (write-to-string (calc-token 123)))
        (err "Title must not contain newline!")
        (title))
    (setf title (format nil "foo~c" #\Return))
    (assert (string= (reject-post-p nil "ip1" 0 title "" "bar" x) err))
    (setf title (format nil "foo~c" #\Newline))
    (assert (string= (reject-post-p nil "ip1" 0 title "" "bar" x) err))))

(test-case reject-post-p-name-has-line-break
  (let ((x (write-to-string (calc-token 123)))
        (err "Name must not contain newline!")
        (name))
    (setf name (format nil "foo~c" #\Return))
    (assert (string= (reject-post-p nil "ip1" 0 "" name "bar" x) err))
    (setf name (format nil "foo~c" #\Newline))
    (assert (string= (reject-post-p nil "ip1" 0 "" name "bar" x) err))))

(test-case reject-post-p-expect
  (let ((x (write-to-string (calc-token 123))))
    (assert (string= (reject-post-p '(:expect ("foo")) "ip1" 0 "" "" "bar" x)
                     "Improper code!"))))

(test-case reject-post-p-block
  (let ((x (write-to-string (calc-token 123))))
    (assert (string= (reject-post-p '(:block ("xy")) "ip1" 0 "xy" "yz" "zx" x)
                     "Dodgy content!"))))

(test-case reject-post-p-ban
  (let ((x (write-to-string (calc-token 123))))
    (assert (string= (reject-post-p '(:ban ("ip1")) "ip1xy" 0 "xy" "yz" "zx" x)
                     "IP address ip1xy is banned!"))))

(test-case reject-post-p-client-post-interval
  (let ((options '(:client-post-interval 10))
        (x (write-to-string (calc-token 123)))
        (msg "Wait for ~a s before resubmitting!"))
    (assert (not (reject-post-p options "ip1" 1000 "foo" "bar" "baz" x)))
    (setf (gethash "ip1" *flood-table*) 1000)
    (assert (string= (reject-post-p options "ip1" 1000 "foo" "bar" "baz" x)
                     (format nil msg 10)))
    (assert (string= (reject-post-p options "ip1" 1001 "foo" "bar" "baz" x)
                     (format nil msg 9))))
  (clrhash *flood-table*))

;; End test cases.
(test-done)
