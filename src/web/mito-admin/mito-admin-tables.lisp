
(in-package :openbookstore.models)

;; We have Mito *tables*
;; (BOOK PLACE PLACE-COPIES CONTACT CONTACT-COPIES BASKET BASKET-COPIES USER ROLE USER-ROLE ROLE-COPY SELL SOLD-CARDS SHELF PAYMENT-METHOD)

(djula:add-template-directory
 (asdf:system-relative-pathname "openbookstore" "src/web/"))

(defparameter *admin-index* (djula:compile-template* "mito-admin/templates/index.html"))
(defparameter *admin-table* (djula:compile-template* "mito-admin/templates/table.html"))
(defparameter *admin-record* (djula:compile-template* "mito-admin/templates/record.html"))

;;; We might want a admin-page class and instances, to set parameters:
;;; - show the search input on the table view?
;;; - action buttons (to do)
;;; - more settings.

(defgeneric tables ()
  (:method ()
    *tables*))

(defgeneric render-index ()
  (:method ()
    (djula:render-template* *admin-index* nil
                            :tables (tables))))

(defgeneric render-table (table &key records search-value) ;; &key (page 1) (page-size 200) (order-by :desc))
  (:method (table &key (records nil records-provided-p) search-value)
    (let ((records (if records-provided-p
                       records
                       (mito:select-dao table (sxql:order-by (:desc :created-at)))))
          (messages (bookshops.messages:get-message/status)))
      (log:info messages)
      (djula:render-template* *admin-table* nil
                              :messages messages
                              :table table
                              :search-value search-value
                              :tables (tables)
                              :records records))))

(defgeneric render-record (table id)
  ;; TODO: see related column (book shelf)
  (:method (table id)
    (let* ((form (make-form table))
           (record (mito:find-dao table :id id))
           (raw (print-instance-slots record :stream nil))
           ;; (fields (collect-slots-values record))
           ;;TODO: we want to see created-at
           (fields/values (collect-fields-values record (form-fields form)))
           ;; (rendered-fields (collect-rendered-slots record)))
           (rendered-fields/values
             (collect-rendered-fields-values record (form-fields form))))
      (djula:render-template* *admin-record* nil
                              :raw raw
                              ;; :fields fields
                              :fields fields/values
                              ;; :rendered-fields rendered-fields
                              :rendered-fields rendered-fields/values
                              :table table
                              :tables (tables)
                              :record record)
      )))
