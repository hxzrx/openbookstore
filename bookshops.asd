#|
  This file is a part of bookshops project.
|#

(require "asdf")  ;; for CI
(require "uiop")  ;; for CI?

(uiop:format! t "~&------- ASDF version: ~a~&" (asdf:asdf-version))
(uiop:format! t "~&------- UIOP version: ~a~&" uiop:*uiop-version*)

(asdf:defsystem "bookshops"
  :version "0.1.1"
  :author "vindarel"
  :license "GPL3"
  :description "Free software for bookshops."
  :homepage "https://gitlab.com/myopenbookstore/openbookstore/"
  :bug-tracker "https://gitlab.com/myopenbookstore/openbookstore/-/issues/"
  :source-control (:git "https://gitlab.com/myopenbookstore/openbookstore/")

  ;; Create .deb package.
  ;; :defsystem-depends-on ("linux-packaging")
  ;; :class "linux-packaging:deb"
  ;; :package-name "bookshops"

  :depends-on (
               ;; web client
               :dexador
               :plump
               :lquery
               :clss ;; might do with lquery only
               ;; DB
               :mito
               :mito-auth
               ;; readline
               :unix-opts
               :replic
               :cl-ansi-text
               :parse-number

               ;; utils
               :alexandria
               :can
               :str
               :local-time
               :local-time-duration
               :cl-ppcre
               :parse-float
               :serapeum
               :log4cl
               :trivial-backtrace

               :deploy ;; must be a build dependency, but we also use deployed-p checks in our code.
               :fiveam  ;; dep of dep for build, required by deploy??

               ;; cache
               :cacle

               ;; web app
               :hunchentoot
               :easy-routes
               :djula
               :cl-json
               :cl-slug

               :cl-i18n
               )

  :components ((:module "src/datasources"
                        :components
                        ((:file "dilicom")
                         (:file "dilicom-flat-text")
                         (:file "scraper-fr")))

               (:module "src"
                        :components
                        ;; stand-alone packages.
                        ((:file "parameters")
                         (:file "utils")
                         (:file "termp")
                         ;; they depend on the above.
                         (:file "packages")
                         (:file "authentication")
                         (:file "bookshops") ;; depends on src/web
                         (:file "database")))

               (:module "src/models"
                        :components
                        ((:file "shelves")
                         (:file "models")
                         (:file "models-utils")
                         (:file "baskets")
                         (:file "contacts")
                         (:file "sell")))

               ;; readline-based, terminal user-facing app (using REPLIC).
               (:module "src/terminal"
                        :components
                        ((:file "commands")
                         ;; relies on the above:
                         (:file "manager")))

               ;; One-off utility "scripts" to work on the DB.
               (:module "src/management"
                        :components
                        ((:file "management")))

               (:module "src/web"
                        :components
                        ((:file "package")
                         (:file "messages")
                         (:file "authentication")
                         (:file "search")
                         (:file "web")
                         (:file "api"))))

  ;; :build-operation "program-op"
  :entry-point "bookshops:run"
  :build-pathname "bookshops"

  ;; For a .deb (with the two lines above).
  ;; :build-operation "linux-packaging:build-op"

  ;; With Deploy, ship foreign libraries (and ignore libssl).
  :defsystem-depends-on (:deploy)  ;; (ql:quickload "deploy") before
  :build-operation "deploy-op"     ;; instead of "program-op"

  ;; :long-description
  ;; #.(read-file-string
  ;;    (subpathname *load-pathname* "README.md"))
  :in-order-to ((test-op (test-op "bookshops-test"))))


;; Don't ship libssl, rely on the target OS'.
#+linux (deploy:define-library cl+ssl::libssl :dont-deploy T)
#+linux (deploy:define-library cl+ssl::libcrypto :dont-deploy T)


;; Use compression: from 108M, 0.04s startup time to 24M, 0.37s.
#+sb-core-compression
(defmethod asdf:perform ((o asdf:image-op) (c asdf:system))
  (uiop:dump-image (asdf:output-file o c) :executable t :compression t))


(asdf:defsystem "bookshops/gui"
  :version "0.1.0"
  :author "vindarel"
  :license "GPL3"
  :depends-on (:bookshops
               :nodgui)
  :components ((:module "src/gui"
                :components
                ((:file "gui"))))

  :build-operation "program-op"
  :build-pathname "bookshops-gui"
  :entry-point "bookshops.gui:main"

  :description "Simple graphical user interface to manage one's books."
  ;; :long-description
  ;; #.(read-file-string
  ;;    (subpathname *load-pathname* "README.md"))
  :in-order-to ((test-op (test-op "bookshops-test"))))

;; Now ASDF wants to update itself and crashes.
;; On the target host, when we run the binary, yes. Damn!
;; Thanks again to Shinmera.
(deploy:define-hook (:deploy asdf) (directory)
  (declare (ignorable directory))
  #+asdf (asdf:clear-source-registry)
  #+asdf (defun asdf:upgrade-asdf () nil))
