
(in-package :openbookstore.models)

;; We have Mito *tables*
;; (BOOK PLACE PLACE-COPIES CONTACT CONTACT-COPIES BASKET BASKET-COPIES USER ROLE USER-ROLE ROLE-COPY SELL SOLD-CARDS SHELF PAYMENT-METHOD)

(djula:add-template-directory
 (asdf:system-relative-pathname "openbookstore" "src/web/"))

(defparameter *admin-index* (djula:compile-template* "mito-admin/templates/index.html"))
(defparameter *admin-table* (djula:compile-template* "mito-admin/templates/table.html"))
(defparameter *admin-record* (djula:compile-template* "mito-admin/templates/record.html"))

(defgeneric tables ()
  (:method ()
    *tables*))

(defgeneric render-index ()
  (:method ()
    (djula:render-template* *admin-index* nil
                            :tables (tables))))

(defgeneric render-table (table ) ;; &key (page 1) (page-size 200) (order-by :desc))
  (:method (table)
    (let ((records (mito:select-dao table (sxql:order-by (:desc :created-at))))
          (messages (bookshops.messages:get-message/status)))
      (log:info messages)
      (djula:render-template* *admin-table* nil
                              :messages messages
                              :table table
                              :tables (tables)
                              :records records)
      )))

(defgeneric render-record (table id)
  (:method (table id)
    (let* ((record (mito:find-dao table :id id))
           (raw (print-instance-slots record :stream nil))
           (fields (collect-slots-values record))
           (rendered-fields (COLLECT-RENDERED-SLOTS record)))
      (djula:render-template* *admin-record* nil
                              :raw raw
                              :fields fields
                              :rendered-fields rendered-fields
                              :table table
                              :tables (tables)
                              :record record)
      )))

(defgeneric render-field (