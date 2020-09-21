(in-package :bookshops-web)

#|
Show the stock on a web page.
(in construction)

(connect)
then
(start-app)

and go to localhost:4242/stock/

In this file:
- custom Djula filters
- templates loading
- routes
- server start/stop

Dev helpers:
- adding ?raw=t on a URL (on a card page)
|#

(defvar *server* nil
  "Current instance of easy-acceptor.")

(defparameter *port* 4242)

;;; Djula filters.
(djula:def-filter :price (val)
  (format nil "~,2F" val))

(djula:def-filter :url (card)
  "Create a full URL to uniquely identify this card."
  (format nil "/~a/~a-~a"
          "card"                       ; this can be translated
          (mito:object-id card)
          ;; the slug won't actually be read back, only the id.
          (slug:slugify (models:title card))))

(djula:def-filter :quantity (card)
  (typecase card
    (models:book (models:quantity card))
    (models:place-copies (models:place-copy-quantity card))
    (t (or (access:access card :in-stock) 0))))

(djula:def-filter :name (obj)
  (format nil "~a" (models:name obj)))

(djula:def-filter :describe (card)
  (with-output-to-string (s)
    (describe card s)))

;;; stolen options read-from-string idea from the djula time filter
(djula:def-filter :quantity-style (quantity raw-options)
  (let ((options (read-from-string raw-options)))
    (cond ((= 0 quantity) (access:access options :zero))
          ((plusp quantity) (access:access options :positive))
          (t (access:access options :negative)))))

;;; Load templates.
(defparameter +base.html+ (djula:compile-template* "base.html"))
(defparameter +dashboard.html+ (djula:compile-template* "dashboard.html"))
(defparameter +search.html+ (djula:compile-template* "search.html"))
(defparameter +stock.html+ (djula:compile-template* "stock.html"))
(defparameter +card-page.html+ (djula:compile-template* "card-page.html"))
(defparameter +card-stock.html+ (djula:compile-template* "card-stock.html"))
(defparameter +card-create.html+ (djula:compile-template* "card-create.html"))

(defparameter +404.html+ (djula:compile-template* "404.html"))

;;; search
;;; TODO find somewhere better to put search functionatlity this.
(defvar *search-cache* (cacle:make-cache 5000 '%search-datasources :test 'equal
                                         :lifetime (* 24 3600)))

(defun %search-datasources (q)
  (declare (type string q))
  (cond
    ;; ISBN? Dilicom search.
    ((bookshops.utils:isbn-p q)
     (values (dilicom:search-books (list q)) 1))

    ;; Free search? Other datasources.
    ((not (str:blank? q))
     (values (fr:books q) 1))

    (t (values nil 1))))

(defun search-datasources (query)
  (cacle:with-cache-fetch res (*search-cache* query)
    (when res
      (bookshops.models::check-in-stock res))))

;;; Routes.
(bookshops.models:define-role-access home-route :view :visitor)
(defroute home-route ("/" :decorators ((@check-roles stock-route))) ()
  (render-template* +dashboard.html+ nil
                    :route "/"
                    :current-user (current-user)
                    :data (list :nb-titles (models:count-book)
                                :nb-books (models::total-quantities)
                                :nb-titles-negative (length
                                                     (models::negative-quantities)))))

(bookshops.models:define-role-access stock-route :view :visitor)
(defroute stock-route ("/stock" :decorators ((@check-roles stock-route)))
    (&get q)
  (let ((cards (cond
                 ((utils:isbn-p q)
                  (list (models:find-by :isbn q)))
                 (q
                  (models:find-book :query (bookshops.utils::asciify q)))
                 (t
                  ;; XXX: pagination
                  (listopia:take 50 (models:find-book))))))
    (render-template* +stock.html+ nil
                      :route "/stock"
                      :cards cards
                      :nb-results (length cards)
                      :q q
                      :data (list :nb-titles (bookshops.models:count-book)
                                  :nb-books (bookshops.models::total-quantities)
                                  :nb-titles-negative (length
                                                       (bookshops.models::negative-quantities))))))

(bookshops.models:define-role-access search-route :view :visitor)
(defroute search-route ("/search" :decorators ((@check-roles stock-route))) (&get q)
  (let ((cards (and q (search-datasources q))))
    (if cards
        (render-template* +search.html+ nil
                          :route "/search"
                          :q q
                          :cards cards
                          :nb-results (length cards)
                          :title (format nil "OpenBookstore - search: ~a" q))
        (render-template* +search.html+ nil
                          :route "/search"
                          :q q))))

(bookshops.models:define-role-access add-or-create-route :view :editor)
(defroute add-or-create-route ("/card/add-or-create/" :method :post
                                                      :decorators ((@check-roles stock-route)))
    (q title isbn cover-url publisher (updatep :parameter-type 'boolean
                                               :init-form t)
       (book-id :parameter-type 'string :init-form "")
       (referer-route :parameter-type 'string :init-form "/search"))
  (let* ((book
          (if (str:blank? book-id)
              (models:find-existing
               (models:make-book :title title :isbn isbn :cover-url cover-url
                          :publisher publisher)
                             :update updatep)
              (models:find-by :id book-id))))
    (models:save-book book)
    (render-template* +card-page.html+ nil
                      :q q
                      :card book
                      :referer-route referer-route
                      :places-copies
                      (bookshops.models::book-places-quantities book)
                      :places (bookshops.models:find-places))))

(defun redirect-to-search-result (route query book)
  (hunchentoot:redirect
   (format nil "~a~@[?q=~a~]#card~a" route
           (and (str:non-empty-string-p query) query)
           (mito:object-id book))))

(bookshops.models:define-role-access add-or-create-route :view :editor)
(defroute card-add-stock-route ("/card/add-stock/" :method :post
                                                   :decorators ((@check-roles stock-route)))
    (q place-id (quantity :parameter-type 'integer :init-form 0) isbn
       (referer-route :parameter-type 'string :init-form "/search"))
  (let ((card (models:find-by :isbn isbn))
        (place (models:find-place-by :id place-id)))
    (bookshops.models:add-to place card :quantity quantity)
    (redirect-to-search-result referer-route q card)))

(bookshops.models:define-role-access add-or-create-route :view :editor)
(defroute card-quick-add-route ("/card/quick-add-stock/" :method :post
                                                         :decorators ((@check-roles stock-route)))
    (q (quantity :parameter-type 'integer :init-form 1) title isbn cover-url publisher
       (updatep :parameter-type 'boolean :init-form t)
       (book-id :parameter-type 'string :init-form "")
       (referer-route :parameter-type 'string :init-form "/search"))
  (let ((book
         (if (str:blank? book-id)
             (models:find-existing
              (models:make-book :title title :isbn isbn :cover-url cover-url
                                :publisher publisher)
              :update updatep)
             (models:find-by :id book-id))))
    (models:save-book book)
    (bookshops.models:add-to (models:default-place) book :quantity quantity)
    (redirect-to-search-result referer-route q book)))

(bookshops.models:define-role-access add-or-create-route :view :visitor)
(defroute card-page ("/card/:slug" :decorators ((@check-roles stock-route)))
    (&get raw)
  "Show a card.

  If the URL parameter RAW is \"t\" (the string), then display the card object literally (with describe)."
  (let* ((card-id (ignore-errors
                    (parse-integer (first (str:split "-" slug)))))
         (card (when card-id
                 (models:find-by :id card-id))))
    (cond
      ((null card-id)
       (render-template* +404.html+ nil))
      (card
       (render-template* +card-stock.html+ nil
                         :messages nil
                         :route "/stock"
                         :card card
                         :places-copies (models::book-places-quantities card)
                         :raw raw))
      (t
       (render-template* +404.html+ nil)))))

(bookshops.models:define-role-access card-create-route :view :editor)
(defroute card-create-route ("/card/create" :method :get)
    ()
  (describe (hunchentoot:start-session) t) ;; XXX debug
  ;; (log:info (bookshops.messages::add-message "Hello message :)"))
  (render-template* +card-create.html+ nil
                    :messages/status (bookshops.messages:get-message/status)))

(defroute card-create/post-route ("/card/create" :method :post)
    ;; title is mandatory, the rest is optional.
    (title isbn price authors)
  (when (str:blankp title)
    (bookshops.messages::add-message "Please enter a title" :status :warning)
    (hunchentoot:redirect "/card/create"))
  ;XXX: handle more than one validation message.
  (when (not (bookshops.utils:isbn-p isbn))
    (bookshops.messages::add-message (format nil "This doesn't look like an ISBN: ~a" isbn) :status :warning)
    (hunchentoot:redirect "/card/create"))
  (handler-case
      (let ((book (models:make-book :title title
                                    :isbn (bookshops.utils:clean-isbn isbn)
                                    :authors authors
                                    :price (utils:ensure-float price))))
        (mito:save-dao book)
        (bookshops.messages:add-message "The book was created succesfully.")
        (hunchentoot:redirect "/card/create"))
    (error (c)
                                        ;XXX: 404 handled by hunchentoot
      (format *error-output* c))))

(defun start-app (&key (port *port*))
  (bookshops.models:connect)

  ;; fix a puri bug. puri:parse-uri "/login?referer-route=/stock?q=lisp" fails,
  ;; it doesn't like the last ?. See https://gitlab.common-lisp.net/clpm/puri/-/issues/2
  (setf puri::*strict-illegal-query-characters*
        (remove #\? puri::*strict-illegal-query-characters*))

  (setf *server* (make-instance 'easy-routes:routes-acceptor :port port))
  (hunchentoot:start *server*)
  (uiop:format! t "~&Application started on port ~a.~&" port))

(defun stop-app ()
  ;; disconnect db ?
  (hunchentoot:stop *server*))

(defun set-devel-profile ()
  "- interactive debugger"
  (setf hunchentoot:*catch-errors-p* nil))
