(defpackage bookshops-test
  (:shadow :search)
  (:use :cl
        :bookshops
        :prove)
  (:import-from :bookshops.models
                :book
                :make-book
                :save-book
                :title
                :isbn
                :quantity
                :find-by
                :make-place
                :save-place
                :default-place
                :add-to)
  (:import-from :bookshops-test.utils
                :with-empty-db))
(in-package :bookshops-test)

;; NOTE: To run this test file, execute `(asdf:test-system :bookshops)' in your Lisp.

(plan nil)

(subtest "Simple creation and access"
  (let ((book (make-instance 'book :title "Antigone")))
    (ok book "creation")
    (is (title book) "Antigone" "title access"))
  )

(defvar fixtures nil)

(defun fixtures-init ()
  (setf fixtures (list (make-book :title "test"
                                  :isbn "9782710381419"))))

(defvar *default-place* nil)

(defun fixtures-places ()
  (setf *default-place* (make-place "default place")))

(subtest "Creation and DB save"
  (fixtures-places)
  (with-empty-db
    (save-place *default-place*)
    (let ((bk (make-book :title "in-test")))
      (save-book bk)

      (is (quantity bk)
          1
          "The quantity is 1 after adding to the DB."))))

(subtest "Add a book that already exists"
  (fixtures-init)
  (fixtures-places)
  (with-empty-db
    (save-place *default-place*)
    (let* ((bk (first fixtures))
           (same-bk (make-book :title "different title"
                               :isbn (isbn bk))))
      (save-book bk)
      (save-book same-bk)
      (is (quantity (find-by :isbn (isbn bk)))
          2)
      )))

(subtest "Create a default place"
  (with-empty-db
    (is (type-of (default-place))
        'bookshops.models::place
        "we create a default place if there is none.")))

(subtest "Places"
  (fixtures-init)
  (fixtures-places)
  (with-empty-db
    ;; xxx Better fixtures, save the objects before.
    (save-place *default-place*)
    (save-book (first fixtures))
    (is (add-to *default-place* (first fixtures))
        2)))

(finalize)
