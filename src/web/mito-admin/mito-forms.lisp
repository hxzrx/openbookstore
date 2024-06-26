
(in-package :mito-admin)


#|
Trying…

Find a Mito slot

(mito.class:find-slot-by-name 'book 'shelf)
#<MITO.DAO.COLUMN:DAO-TABLE-COLUMN-CLASS OPENBOOKSTORE.MODELS::SHELF>

(inspect *)

The object is a STANDARD-OBJECT of type MITO.DAO.COLUMN:DAO-TABLE-COLUMN-CLASS.
0. SOURCE: #S(SB-C:DEFINITION-SOURCE-LOCATION
              :NAMESTRING "/home/vince/projets/openbookstore/openbookstore/src/models/models.lisp"
              :INDICES 262185)
1. NAME: SHELF
2. INITFORM: NIL
3. INITFUNCTION: #<FUNCTION (LAMBDA (&REST REST)
                              :IN
                              "SYS:SRC;CODE;FUNUTILS.LISP") {5374305B}>
4. INITARGS: (:SHELF)
5. %TYPE: T
6. %DOCUMENTATION: "Shelf"
7. %CLASS: #<MITO.DAO.TABLE:DAO-TABLE-CLASS OPENBOOKSTORE.MODELS:BOOK>
8. READERS: (SHELF)
9. WRITERS: ((SETF SHELF))
10. ALLOCATION: :INSTANCE
11. ALLOCATION-CLASS: NIL
12. COL-TYPE: (OR :NULL SHELF)
13. REFERENCES: NIL
14. PRIMARY-KEY: NIL
15. GHOST: T
16. INFLATE: "unbound"
17. DEFLATE: "unbound"
>

List of slot names with normal MOP:

(mapcar #'mopp:slot-definition-name slots)
(MITO.DAO.MIXIN::CREATED-AT MITO.DAO.MIXIN::UPDATED-AT MITO.DAO.MIXIN::SYNCED
 MITO.DAO.MIXIN::ID DATASOURCE DETAILS-URL TITLE TITLE-ASCII ISBN PRICE
 DATE-PUBLICATION PUBLISHER PUBLISHER-ASCII AUTHORS AUTHORS-ASCII SHELF
 SHELF-ID COVER-URL REVIEW)

List of Mito slots from those names:

(mapcar (^ (name) (mito.class:find-slot-by-name 'book name))
        '(MITO.DAO.MIXIN::ID title shelf))
(#<MITO.DAO.COLUMN:DAO-TABLE-COLUMN-CLASS MITO.DAO.MIXIN::ID>
 #<MITO.DAO.COLUMN:DAO-TABLE-COLUMN-CLASS OPENBOOKSTORE.MODELS:TITLE>
 #<MITO.DAO.COLUMN:DAO-TABLE-COLUMN-CLASS OPENBOOKSTORE.MODELS::SHELF>)

Mito column types:

(mapcar #'mito.class:table-column-type *)
;; (:BIGSERIAL (:VARCHAR 128) SHELF)

but not (or null shelf) ?

|#

(defclass form ()
  ((model
    :initarg :model
    :initform nil
    :accessor form-model
    :documentation "Class table symbol. Eg: 'book")
   (fields
    :initarg :fields
    :initform nil
    :accessor fields
    :documentation "List of field names to render in the form.")
   (input-fields
    :initform nil
    :documentation "Hash-table. See the `input-fields' method.")
   (exclude-fields
    :initarg :exclude-fields
    :initform nil
    :documentation "List of field names to exclude. Better use the `exclude-fields' method.")
   (search-fields
    :initargs :search-fields
    :initform '(title name)
    :accessor search-fields
    :documentation "List of fields to query when searching for records. Defaults to 'title and 'name, two often used field names. Overwrite them with the `search-fields' method.")
   (target
    :initarg :target
    :initform "/admin/:table/create"
    :documentation "The form URL POST target when creating a record.
      Allows a :table placeholder to be replaced by the model name. Use with `form-target'.")
   (view-record-target
    :initarg :view-target
    :initform "/admin/:table/:id"
    :documentation "The form URL POST target to view a record.
      Allows a :table and a :id placeholder. Use with `view-record-target'.")
   (edit-target
    :initarg :edit-target
    :initform "/admin/:table/:id/edit"
    :documentation "The form URL POST target when updating a record.
      Allows a :table and a :id placeholder. Use with `edit-form-target'.")

   (validators
    :initargs :validators
    :accessor validators
    :documentation "Hash-table: key (field symbol) to a validator function.")))

#+openbookstore
(defclass book-form (form)
  ())

#+openbookstore
(defclass place-form (form)
  ())

;; => automatically create a <table>-form class for all tables.

#+openbookstore
(defparameter book-form (make-instance 'book-form :model 'book))


(defparameter *template-select-input* (djula:compile-template* "includes/select.html"))

(defparameter *template-admin-create-record* (djula:compile-template* "create_or_edit.html"))

(defmethod initialize-instance :after ((obj form) &key)
  "Populate fields from the class name."
  (when (slot-boundp obj 'model)
    (with-slots (fields model) obj
      (setf fields
            ;; Use direct slots.
            ;; If we get all slot names, we get MITO.DAO.MIXIN::SYNCED and the like.
            ;;TODO: exclude -ID fields.
            ;;(mito.class:table-column-type (mito.class:find-slot-by-name 'book 'shelf-id))
            ;; SHELF
            ;; => it's a table, so exclude shelf-id.
            (mito-admin::class-direct-slot-names model)))))

(defgeneric exclude-fields (obj)
  (:documentation "Return a list of fields (symbols) to exclude from the form. This method can be overriden. See also the form object :exclude-fields slot.")
  (:method (obj)
    (list)))

#+openbookstore
(defmethod exclude-fields (book-form)
  "Return a list of field names (symbols) to exclude from the creation form."
  '(title-ascii
    publisher-ascii
    authors-ascii
    datasource
    ;; ongoing: handle relations
    ;; we need to exclude shelf, or we'll get an error on mito:insert-dao if the field is NIL.
    ;; shelf
    shelf-id
    shelf2-id
    ))

;; Do we want to get the search fields from a table name or a form class?
(defmethod search-fields (table)
  '(title name))

#+openbookstore
(defmethod search-fields ((form book-form))
  '(title))

#+openbookstore
(defmethod search-fields ((table (eql 'book)))
  '(title authors-ascii))

(defgeneric form-fields (form)
  (:documentation "Return a list of this form's fields, excluding the fields given in the constructor and in the `exclude-fields' method.")
  (:method (form)
    (with-slots (fields exclude-fields) form
      ;; set operations (set-difference) don't respect order.
      (loop for field in fields
            with exclude-list-1 = exclude-fields
            with exclude-list-2 = (exclude-fields form)
            unless (or (find field exclude-list-1)
                       (find field exclude-list-2))
              collect field))))

#+(or)
(assert (equal 0 (mismatch
                  (form-fields (make-instance 'book-form :model 'book))
                  '(COVER-URL SHELF-ID SHELF AUTHORS PUBLISHER DATE-PUBLICATION PRICE ISBN TITLE DETAILS-URL))))


;;;
;;; How best define the input types/widgets ?
;;;
(defgeneric input-fields (form)
  (:documentation "Define the fields' widgets. Return: a hash-table with key (field symbol name) and property list with keys: :widget, :validator…

  Widgets are: :textarea, :datetime-local… TBC

  Shall we infer the widgets more thoroughly?")
  (:method (form)
    (dict)))

(defun validate-ok (&optional it)
  (declare (ignorable it))
  (print "ok!"))

#+openbookstore
(defmethod input-fields ((form book-form))
  ;; Here we don't use another class to not bother with special :widget slots and a metaclass…
  (dict 'review (list :widget :textarea :validator #'validate-ok)
        'date-publication (list :widget :datetime-local)))

;; so, an "accessor":
(defun input-field-widget (form field)
  (access:accesses (input-fields form) field :widget))
#+(or)
(input-field-widget (make-form 'book) 'review)
;; :TEXTAREA


;; section: define forms.
;; That's a second way to define form inputs isn't it?
;; We added field-input first, but it's to render HTML.
(defgeneric render-widget (form field widget &key name record)
  (:documentation "Return HTML to render a widget given a form, a field name (symbol), a widget type (keyword).

  The user simply chooses the widget type and doesn't write HTML.

  NAME: the column type field (symbol). If \"shelf2\" refers to the \"shelf\" table, FIELD is \"shelf2\" and NAME must be \"shelf\".

  See also `field-input'.")
  (:method (form field widget &key name record)
    (case widget
      (:select
          (let ((objects (mito:select-dao field)))
            (log:info "caution: we expect ~a objects to have an ID and a NAME field" field)
            (djula:render-template* *template-select-input* nil
                                    :name (or name field)
                                    :options objects
                                    :record record
                                    :selected-option-id (ignore-errors
                                                         (mito:object-id (slot-value record field)))
                                    :empty-choice t
                                    :empty-choice-label (format nil "-- choose a ~a… --"
                                                                (str:downcase field))
                                    :label field
                                    :select-id (format nil "~a-select" (str:downcase field)))))
      (:textarea
       (format nil "<div class=\"field\">
<label class=\"label\"> ~a </label>
 <div class=\"control\">
  <textarea name=\"~a\" class=\"input\" rows=\"5\">
    ~a
  </textarea>
</div>
</div>" field field (if record (slot-value record field) "")))
      (:datetime-local
       (format nil "<div class=\"field\">
<label class=\"label\"> ~a </label>
 <div class=\"control\">
  <input type=\"datetime-local\" name=\"~a\" class=\"input\"> </input>
</div>
</div>" field field))
      (t
       (format nil "<div> todo for ~a </div>" field)))))

;;;
;;; end of input types/widgets experiment.
;;;


;;;
;;; section: let's continue and generate a form.
;;;

(defgeneric field-input (form field &key record errors value)
  (:documentation "Return HTML for this field. It's important to have a name=\"FIELD\" for each input, so that they appear in POST parameters.

  When a record is given, pre-fill the form inputs.

  When an errors list is given, show them.

  This is the method called by the form creation and edition. When we find a widget specified for a field, we call render-widget.

  A user can subclass this method and return HTML or just set the widget type and let the default rendering.")
  (:method (form field &key record errors value)
    (declare (ignorable form))
    (cond
      ((field-is-related-column (form-model form) field)
       (log:info "render column for ~a" field)
       (render-widget form (field-is-related-column (form-model form) field) :select
                      :name field
                      :record record))
      ((not (null (input-field-widget form field)))
       (render-widget form field (input-field-widget form field)
                      :record record))
      (t
       (format nil "<div class=\"field\">
         <label class=\"label\"> ~a </label>
         <div class=\"control\">
           <input name=\"~a\" class=\"input\" type=\"text\" ~a> </input>
         </div>
          ~a
        </div>"
               field
               field
               (cond
                 (record
                  (format nil "value=\"~a\"" (slot-value? record field)))
                 (value
                  (format nil "value=\"~a\"" value))
                 (t
                  ""))
               ;; XXX: use templates to render those fields. It gets messy with errors.
               (if errors
                   (with-output-to-string (s)
                     (loop for error in errors
                           do (format s "<p class=\"help is-danger\"> ~a </p>" error)))
                   "")
               )))))

;; We can override an input fields for a form & field name
;; by returning HTML.
#+openbookstore
(defmethod field-input ((form book-form) (field (eql 'shelf)) &key record errors value)
  (let ((shelves (mito:select-dao field)))
    (log:info record)
    (djula:render-template* *template-select-input* nil
                            :name field
                            :options shelves
                            :selected-option-id (ignore-errors
                                                 (mito:object-id (shelf record)))
                            :record record
                            :empty-choice t
                            :empty-choice-label "-- choose a shelf… --"
                            :label "select a shelf"
                            :select-id "shelf-select")))

(defun collect-slot-inputs (form fields &key record)
  (loop for field in fields
        collect (list :name field
                      :html (field-input form field :record record))))

(defun make-form (table)
  "From this table name, return a new form."
  ;; XXX: here, if the class <db model>-form (shelf-form) doesn't exist why not define
  ;; and create it?
  (make-instance (alexandria:symbolicate (str:upcase table) "-" 'form)
                 :model (alexandria:symbolicate (str:upcase table))))

(defmethod form-target ((obj form))
  "Format the POST URL.

  Replace the :table placeholder by the model name."
  (cond
    ((slot-boundp obj 'model)
     (with-slots (target model) obj
       (if (str:containsp ":table" target)
           (str:replace-all ":table" (str:downcase model) target)
           target)))
    (t
     "")))

(defmethod edit-form-target ((obj form) id)
  "Return the POST URL of the edit form.

  Replace the :table placeholder by the model name and the :id placeholder."
  (cond
    ((slot-boundp obj 'model)
     (with-slots (edit-target model) obj
       (cond
         ((str:containsp ":table" edit-target)
          (str:replace-using (list ":table" (str:downcase model)
                                   ":id" (string id))
                             edit-target))
         (t
          edit-target))))
    (t
     "")))

(defgeneric table-target (form)
  (:documentation "/admin/:table/ URL to view a list of records of this table. ")
  (:method (form)
    (str:concat "/admin/" (str:downcase (slot-value? form 'model)) "/")))

(defgeneric view-record-target (form id)
  (:documentation "/admin/:table/:id URL to view a record. ")
  (:method ((obj form) id)
    (cond
      ((slot-boundp obj 'model)
       (with-slots (view-record-target model) obj
         (cond
           ((str:containsp ":table" view-record-target)
            (str:replace-using (list ":table" (str:downcase model)
                                     ":id" (princ-to-string id))
                               view-record-target))
           (t
            view-record-target))))
      (t
       ""))))

;; Serve the form.
(defgeneric create-record (table)
  (:method (table)
    (let* ((form (make-form table))
           (fields (form-fields form))
           (inputs (collect-slot-inputs form fields)))
      (log:info form (form-target form))
      (djula:render-template* *template-admin-create-record* nil
                              :form form
                              :target (form-target form)
                              :fields fields
                              :inputs inputs
                              :table table
                              ;; global display
                              :tables (tables))
      )))

#|
Tryng out…

(defparameter params '(("NAME" . "new place")))

(cdr (assoc "NAME" params :test #'equal))

;; transform our "PARAM" names (strings) to symbols (to hopefully map our field names)
(defun params-symbols-alist (params)
 (loop for (key . val) in params
  collect (cons (alexandria:symbolicate key) val))
  )

(params-symbols-alist params)
;; ((NAME . "new place"))

(defun params-keywords-alist (params)
 (loop for (field . val) in params
  collect (cons (alexandria:make-keyword field) val))
  )
(params-keywords-alist (params-symbols-alist params))
((:NAME . "new place"))

(defun params-keywords (params)
 (params-keywords-alist (params-symbols-alist params)))


`(make-instance 'place ,@(alexandria:flatten '((:NAME . "new place"))))
(MAKE-INSTANCE 'PLACE :NAME "new place")

ok!
|#


;;;
;;; section: Save
;;;

(defparameter *catch-errors* nil
  "Set to T to not have the debugger on an error. We could use hunchentoot's *catch-errors*.")

(defun params-symbols-alist (params)
  "Transform this alist of strings to an alist of symbols."
  (loop for (field . val) in params
        collect (cons (alexandria:symbolicate (str:upcase field)) val)))

#+(or)
(params-symbols-alist '(("NAME" . "test")))
;; ((NAME . "test"))

(defun params-keywords-alist (params)
 (loop for (field . val) in params
       collect (cons (alexandria:make-keyword field) val)))

(defun params-keywords (params)
  (params-keywords-alist (params-symbols-alist params)))
#+(or)
(params-keywords '(("TITLE" . "test")))
;; ((:TITLE . "test"))

(defun cleanup-params-keywords (params-keywords)
  "Remove null values."
  (loop for (field . val) in params-keywords
        if (not (null val))
          collect (cons field val)))
#+(or)
(cleanup-params-keywords '((TEST . :yes) (FOO . NIL)))
;;((TEST . :YES))

(defun field-is-related-column (model field)
  "The Mito table-column-type of this field (symbol) is a DB table (listed in our *tables*).

  Return: field symbol or nil."
  ;; (let* ((slot (mito.class:find-slot-by-name 'book (alexandria:symbolicate (str:upcase field))))
  (let* ((slot (mito.class:find-slot-by-name model (alexandria:symbolicate (str:upcase field))))
         (column-type (and slot (mito.class:table-column-type slot))))
    (log:info slot column-type (tables))
    (find column-type (tables))))
#++
(field-is-related-column 'book 'shelf)
;; SHELF
#++
(assert
 ;; TODO: this was working with all symbols in the same package.
 ;; (alexandria:symbolicate 'cosmo-admin-demo::book)
 ;; => BOOK => we loose the package prefix.
 ;; but… the book creation form loads correctly O_o
 ;; Same for str:upcase.
 (equal
  (field-is-related-column 'cosmo-admin-demo::book 'cosmo-admin-demo::shelf)
  'SHELF))
#++
(field-is-related-column 'book 'title)
;; NIL

(defun replace-related-objects (table params)
  "If a parameter is a related column, find the object by its ID and put it in the PARAMS alist.
  Change the alist in place.

  This is done before the form validation.

  PARAMS: alist of keywords (string) and values.

  Return: params, modified."
  (loop for (field . val) in params
        ;; for slot = (mito.class:find-slot-by-name 'book (alexandria:symbolicate (str:upcase field)))
        for slot = (mito.class:find-slot-by-name table (alexandria:symbolicate (str:upcase field)))
        for col = (and slot (mito.class:table-column-type slot))
        for col-obj = nil
        if (find col (tables))
          do (if val
                 (progn
                   (setf col-obj (mito:find-dao col :id val))
                   (log:info "~a is a related column with value: ~s" field col-obj)
                   (if col-obj
                       (setf (cdr (assoc field params :test #'equal))
                             col-obj)
                       ;; when col-obj is NIL, remove field from list.
                       ;; Otherwise Mito tries to get the ID of an empty string.
                       (progn
                         (log:info "delete param ~a from the params list: it is a related object with no value." field)
                         (setf params (remove field params :test #'equal :key #'car)))))
                 ;; The shelf value from the form can be NIL and not ""
                 ;; (use cleanup-params-keywords to avoid).
                 (progn
                   (log:info "~a is NOT a related column: ~s" field col-obj)
                   (log:info "ignoring field with no value: " field)))
        else
          do
             (log:info "ignoring column ~a, not found in (tables)" col))
  params)

;TODO: test again with cosmo-admin-demo
#+test-openbookstore
(let ((params (replace-related-objects 'book '(("TITLE" . "test") ("SHELF" . "1")))))
  ;; => (("TITLE" . "test") ("SHELF" . #<SHELF 1 - Histoire>))
  (assert (not (equal (cdr (assoc "SHELF" params :test #'equal))
                      "1"))))

#+test-openbookstore
(let ((params (replace-related-objects 'book '(("TITLE" . "test") ("SHELF" . NIL)))))
  (assert params))

(defun merge-fields-and-params (fields params-alist)
  (loop for field in fields
        for field/value = (assoc field params-alist)
        if field/value
          collect field/value
        else
          collect `(,field . nil)))

;; ???: we dispatch on table (symbol), but we use a form object,
;; and we always create a new form object. Are the two useful?
(defgeneric save-record (table &key params record &allow-other-keys)
  (:documentation "Process POST paramaters, create or edit a new record or return a form with errors.

    Return a hash-table to tell the route what to do: render a template or redirect.")
  (:method (table &key params record &allow-other-keys)
    (log:info params)
    (setf params (replace-related-objects table params))
    (log:info "params with relations: ~a" params)

    (let* ((form (make-form table))
           (fields (form-fields form))
           (inputs (collect-slot-inputs form fields))
           (keywords (params-keywords params))
           (params-symbols-alist (params-symbols-alist params))
           ;; help preserve order? nope.
           (fields/values (merge-fields-and-params fields params-symbols-alist))
           (record-provided (and record))
           (model (slot-value form 'model))
           (errors nil))

      ;;ONGOING: form validation…
      ;; (multiple-value-bind (status errors)
      (multiple-value-bind (status inputs)
          ;; (validate-form form params-symbols-alist)
          (validate-collect-slot-inputs form fields/values)
        (unless status
          (log:info status errors)
          (return-from save-record
            (dict
             :status :error
             :render (list *template-admin-create-record* nil
                           ;; errors:
                           ;; :errors errors
                           :errors (list "Invalid form. Please fix the errors below.")
                           :form form
                           :target (form-target form)
                           :fields fields
                           :inputs inputs
                           :table table
                           ;; global display
                           :tables (tables))))
         ))

      ;; Create or update?
      (cond
        ;; Create object, unless we are editing one.
        ((null record)
         (handler-bind
             ((error (lambda (c)
                       ;; Return our error when in development mode,
                       ;; inside handler-bind so we have the full backtrace of what happened
                       ;; before this point.
                       (unless *catch-errors*
                         (error c))
                       (log:error "create or update record error: " c)
                       (push (format nil "~a" c) errors))))

           ;; produce:
           ;; (MAKE-INSTANCE 'BOOK :TITLE "new title")
           (setf record
                 (apply #'make-instance model
                        (alexandria:flatten
                         (cleanup-params-keywords keywords))))
           ))
        ;; Update
        (t
         (update-record-with-params record params-symbols-alist)))

      (when errors
        (return-from save-record
          (dict
           :status :error
           ;; list of keys to call djula:render-template*
           :render (list *template-admin-create-record* nil
                         ;; errors:
                         :form-errors errors
                         :form form
                         :target (form-target form)
                         :fields fields
                         :inputs inputs
                         :table table
                         ;; global display
                         :tables (tables)))))

      ;; Save record.
      (handler-case
          (progn
            (log:info "saving record in DB…" record)
            (if record-provided
                ;; save (update)
                (mito:save-dao record)
                ;; create new.
                (mito:insert-dao record)))
        (error (c)
          ;; dev
          (unless *catch-errors*
            (error c))
          (push (format nil "~a" c) errors)))
      (when errors
        (return-from save-record
          (dict
           :status :error
           :render (list *template-admin-create-record* nil
                         ;; errors:
                         :errors errors
                         :form form
                         :target (form-target form)
                         :fields fields
                         :inputs inputs
                         :table table
                         ;; global display
                         :tables (tables)))))

      ;; Success: redirect to the table view.
      (values
       (dict
        :status :success
        :redirect (if record
                      (view-record-target form (mito:object-id record))
                      (table-target form))
        ;; Use my messages.lisp helper?
        :successes (list "record created"))
       record)
      )))

#+(or)
(save-record 'place :params '(("NAME" . "new place test")))

#+(or)
(save-record 'book :params '(("TITLE" . "new book")))


#|
This fails:

(apply #'make-instance 'book (alexandria:flatten
                              (params-keywords '(("REVIEW" . "") ("COVER-URL" . "")
                                                 ("SHELF-ID" . "") ("SHELF" . "")
                                                 ("AUTHORS" . "") ("PUBLISHER" . "") ("DATE-PUBLICATION" . "")
                                                 ("PRICE" . "") ("ISBN" . "") ("TITLE" . "crud")
                                                 ("DETAILS-URL" . "")))))

(mito:insert-dao *)
=> error: mito.dao.mixin::ID missing from object

=> exclude relational columns for now.


Works:
(apply #'make-instance 'book (alexandria:flatten
                              (params-keywords '(("REVIEW" . "") ("COVER-URL" . "")
                                                 ;; ("SHELF-ID" . "")
                                                 ;; ("SHELF" . "")
                                                 ("AUTHORS" . "") ("PUBLISHER" . "") ("DATE-PUBLICATION" . "")
                                                 ("PRICE" . "") ("ISBN" . "") ("TITLE" . "crud")
                                                 ("DETAILS-URL" . "")))))

(mito:insert-dao *)

|#


;;;
;;; section: Edit
;;;
(defgeneric edit-record (table id)
  (:documentation "Edit record with a pre-filled form.")
  (:method (table id)
    (let* ((form (make-form table))
           (fields (form-fields form))
           (record (mito:find-dao table :id id))
           (inputs (collect-slot-inputs form fields :record record)))
      (log:info form (form-target form))
      (djula:render-template* *template-admin-create-record* nil
                              :form form
                              :target (edit-form-target form id)
                              :fields fields
                              :inputs inputs
                              :table table
                              ;; global display
                              :tables (tables)))))

(defgeneric update-record-with-params (record params)
  (:documentation "Update slots, don't save to DB.

   RECORD: DB object. PARAMS: alist with key (symbol), val.")
  (:method (record params)
    (loop for (key . val) in params
          unless (equal "ID" key)       ;; just in case.
          do (setf (slot-value record key) val))))

#+test-openbookstore
(let ((place (mito:find-dao 'place :id 2)))
  (loop for (key . val) in '((NAME . "test place"))
        do (setf (slot-value place key) val))
  (describe place)
  place)
