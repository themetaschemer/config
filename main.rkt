#lang racket

(require syntax/parse)
;;------------------------------------------------------------------------
;; The  define-config-param macro
;;------------------------------------------------------------------------
;; Config params are things that are parameters that are read-in from
;; config files.
;; The config names themselves are module independent, but the
;; parameter access functions generated using this macro are
;; respect module boundaries.
;;
;; There are 4 cases of use:
;;
;; Basic: (define-config-param foo)
;;   This allows a value for foo to be specified in the local.cfg.
;;   (foo) will return the value of the config param.
;;   This config param cannot be set.
;;   The default value for the param will be #f, unless
;;   a #:default-value is provided.
;;
;; Modified update function: #:on-repeat repeat-fn
;;   When a config param can be repeated in the cfg file,
;;   it must accumulate the new values in a list.
;;   This is supported by allowing an update function to
;;   be provided. The update function is called upon
;;   the value in the config file and the return value
;;   is then bound to the parameter.
;;
;; A config parameter can be set to #:required.
;;   when that happens, the reader will give an error
;;   if the config parameter is not present.
;;
;; syntax:
;; (define-config-param name
;;    [#:path]
;;    [(#:required OR #:default-value v)]
;;    [#:on-repeat repeat-fn])



(define uninitialized '__uninitialized__)

(define-syntax (define-config-param x)
  (syntax-case x ()
    ((_ name args ...)
     (parse-args #'(args ...)
       (param-transformer #'name)))))

(define-for-syntax (param-value-expr required? default-value-expr)
  (cond
    (required? #'(uninitialized))
    (default-value-expr #`(#,default-value-expr))
    (else #'())))

(define-for-syntax (param-transformer name)
  (λ (path? required? default-value-expr repeat-fn-expr)
    #`(begin
        (add-config-name
         '#,name
         #,@(param-value-expr required? default-value-expr))
        (define (#,name . #,(if repeat-fn-expr #'vs #'()))
          #,(repeat-fn-body name repeat-fn-expr required? path?)))))

(define-for-syntax (repeat-fn-body name repeat-fn-expr required? path?)
  (cond
    (repeat-fn-expr
     #`(cond
         ((null? vs) (get-config-name-value
                      '#,name
                      #,(if required? #''required #'#f)
                      #,(if path? #''path #'#f)))
         (else ((lookup-config-name '#,name)
                (#,repeat-fn-expr (car vs))))))
    (else
     #`(get-config-name-value
        '#,name
        #,(if required? #''required #'#f)
        #,(if path? #''path #'#f)))))

(define-syntax (define-config-path x)
  (syntax-case x ()
    ((_ args ...)
     #'(define-config-param args ... #:path))))

(define-for-syntax (parse-args all-args receiver)
  (let loop ([args all-args]
             [path? #f]
             [required? #f]
             [default-value-expr #f]
             [repeat-fn-expr #f])
    (syntax-case args ()
      (() (receiver path? required? default-value-expr repeat-fn-expr))
      ((#:path rest ...)
       (loop #'(rest ...) #t required? default-value-expr repeat-fn-expr))
      ((#:required rest ...)
       (loop #'(rest ...) path? #t default-value-expr repeat-fn-expr))
      ((#:default-value v rest ...)
       (loop #'(rest ...) path? required? #'v repeat-fn-expr))
      ((#:on-repeat ufn rest ...)
       (loop #'(rest ...) path? required? default-value-expr #'ufn))
      (_ (error 'define-config-param
                "Bad argument syntax: [~a, ~a:~a]~a~%"
                (syntax-source all-args)
                (syntax-line all-args)
                (syntax-column args)
                (syntax->datum all-args))))))

;;----------------------------------------------------------------------------------------------------
;; The underlying implementation
;;----------------------------------------------------------------------------------------------------

;;----------------------------------------------------------------------------------------------------
;; We first read in the config file into a temporary hash-table
;; When parameters are encountered as they are loaded, new parameters are appropriately
;; added the main lookup table.
;;----------------------------------------------------------------------------------------------------

(define config-complete (make-parameter #f))

;; These are all the parameters and their corresponding values.

(define valid-config-names (make-parameter (make-hash)))

;; Register a valid configuration name.
(define (add-config-name name [value uninitialized])
  ;; only if it does not already exist.
  (when (not (lookup-config-name name))
        (dict-set! (valid-config-names) name (make-parameter value))
        ;; We force a re-reading of the config because the last time the
        ;; config was read may have been before this config name is defined.
        (refresh-config-table)))

;; Look up the parameter. It returns a parameter function which allows values to be set.

(define (lookup-config-name name) (dict-ref (valid-config-names) name #f))

;; Get the value of a config param.

(define (get-config-name-value name [required? #f] [path? #f])
  (let ([v (lookup-param-value name path?)])

    ;; If v is uninitialized, it may be that we have
    ;; encountered the param after we read in the config file.
    ;; So, let's refresh it.
    (when (equal? v uninitialized)
      (refresh-config-table))

    ;; Now we read it again.
    (let ((v (lookup-param-value name path?)))
      (cond
       [(and required? (equal? v uninitialized))
        (error name
          "This required configuration parameter was not found. Please make sure it exists in your local.cfg in ~a."
          (current-directory))]
       ;; Value is uninitialized and not required. Return #f.
       [(and (not required?) (equal? v uninitialized)) #f]
       [else v]))))

(define (lookup-param-value name path?)
  (let ((v ((lookup-config-name name))))
    (cond
     ((and (string? v) path?)
      (path->string (simple-form-path (expand-user-path v))))
     ((and (list? v) path?)
      (map (λ (s) (path->string (simple-form-path (expand-user-path s)))) v))
     (else v))))

;;----------------------------------------------------------------------------------------------------
;; This table holds all the values defined in the config file. They are not
;; necessarily available for use.
;;----------------------------------------------------------------------------------------------------

;; These are the raw pairs read in from the files
(define config-pairs (make-parameter '()))

(define (read-config-from-pairs pairs)
  (config-pairs pairs)
  (let ([table (make-hash)])
    (for ([name-value pairs])
      (let* ((name (car name-value))
             (value (cadr name-value))
             (param-fn (lookup-config-name name)))
        (when param-fn
          (param-fn (pre-process-value value)))))))

(define (pre-process-value value)
  (match value
    (`(getenv ,env-var) (or (getenv env-var)
                            (error 'config "Config environment variable: ~a not found" env-var)))
    (else value)))


(define (refresh-config-table)
  (read-config-from-pairs (config-pairs)))

(define (load-config-if-needed)
  (when (null? (config-pairs))
    (read-config-pairs)
    (refresh-config-table)))

(define (read-config-pairs [fname #f])
  (let ([local-config-file (local-config-file-name fname)])
    (when (file-exists? local-config-file)
          (let* ([port (open-input-file local-config-file)]
                 [pairs (for/list ([rib (in-port read port)])
                          (match rib
                            [`(,name ,value) rib]
                            [else (close-input-port port)
                                  (error 'read-config "Syntax error in config file. Must only be (name value) pairs")]))])
            (close-input-port port)
            (config-pairs pairs)))))

(define (read-config fname)
  (read-config-pairs fname)
  (refresh-config-table))

;; The file from which to read the table.
(define (local-config-file-name [fname #f])
  (let ([env-path (getenv "CONFIG_LOCAL_CFG")])
    (cond
     [fname fname]
     [(and env-path (relative-path? env-path))
      (build-path (current-directory) env-path)]
     [env-path env-path]
     [else (build-path (current-directory) "local.cfg")])))

;; This is mainly used for testing.
(define-syntax (with-config x)
  (syntax-case x ()
    ((_ ((name value) ...) body ...)
     (with-syntax (((prior ...) (generate-temporaries #'(name ...))))
       #'(let ((name (lookup-config-name 'name)) ...)
           (let ((prior (or (and name (name))
                            (error "~a is not a valid config-param" 'name)))...)
             (dynamic-wind
                 (λ () (begin (name value) ...))
                 (λ () body ...)
                 (λ () (begin (name prior) ...)))))))))

(include "test/test.rkt")

(provide
 define-config-param
 define-config-path
 read-config
 local-config-file-name
 with-config)
