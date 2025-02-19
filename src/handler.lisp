(in-package :cl-user)
(defpackage clack.handler
  (:use :cl)
  (:import-from :clack.util
                :find-handler)
  (:import-from :bordeaux-threads
                :threadp
                :make-thread
                :thread-alive-p
                :destroy-thread)
  (:import-from :usocket)
  (:export :run
           :stop))
(in-package :clack.handler)

(defstruct handler
  server
  swank-port
  acceptor)

(defun run (app server &rest args
                &key (address nil address-specified-p) use-thread
                  (swank-interface "127.0.0.1") swank-port
                &allow-other-keys)
  (let ((handler-package (find-handler server))
        (bt:*default-special-bindings* `((*standard-output* . ,*standard-output*)
                                         (*error-output* . ,*error-output*)
                                         ,@bt:*default-special-bindings*)))
    (flet ((run-server ()
             (when swank-port
               (swank:create-server :interface swank-interface :port swank-port :dont-close t))
             (apply (intern #.(string '#:run) handler-package)
                    app
                    :allow-other-keys t
                    (append
                      (and address-specified-p
                           (list :address
                                 (usocket:host-to-hostname
                                   (usocket:get-host-by-name address))))
                      args))))
      (make-handler
        :server server
        :swank-port swank-port
        :acceptor (if use-thread
                      (bt:make-thread #'run-server
                                      :name (format nil "clack-handler-~(~A~)" server)
                                      :initial-bindings
                                      `((bt:*default-special-bindings* . ',bt:*default-special-bindings*)
                                        ,@bt:*default-special-bindings*))
                      (run-server))))))

(defun stop (handler)
  (let ((acceptor (handler-acceptor handler))
        (swank-port (handler-swank-port handler)))
    (if (bt:threadp acceptor)
        (progn
          (when (bt:thread-alive-p acceptor)
            (bt:destroy-thread acceptor))
          (sleep 0.5))
        (let ((package (find-handler (handler-server handler))))
          (funcall (intern #.(string '#:stop) package) acceptor)))
    (when swank-port
      (swank:stop-server swank-port))
    t))
