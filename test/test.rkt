(module+ test
  (require rackunit)
  (define-config-param test-simple)
  (define-config-param test-simple-path #:path)
  (define-config-param test-simple-required #:required)
  (define-config-param test-simple-default #:default-value 33)
  (define-config-param test-simple-update #:on-repeat (λ (new-value) new-value))
  (define-config-param test-simple-path-required #:path #:required)
  (define-config-param test-simple-path-default #:path #:default-value "/tmp")
  (define-config-param test-simple-required-path #:required #:path)
  (define-config-param test-simple-default-path #:default-value "/tmp" #:path)
  (define-config-path test-simple-path-required-update #:required #:on-repeat (λ (new-value) new-value))
  (define-config-path test-simple-path-default-update #:default-value "/tmp" #:on-repeat (λ (new-value) new-value))
  (define-config-path test-simple-update-required-path #:on-repeat (λ (new-value) new-value) #:required)
  (define-config-path test-simple-update-default-path #:on-repeat (λ (new-value) new-value) #:default-value '("/tmp/../foo" "/tmp/bar/../../bar"))
  (define-config-param test-env)

  ;; Testing simple parameters
  (define basic-param-pairs
    '((test-simple "foo")))

  (config-pairs basic-param-pairs)

  (check-equal? (test-simple) "foo")

  (check-equal? (test-simple-default) 33)
  (check-equal? (test-simple-path-default) "/tmp")
  (check-equal? (test-simple-default-path) "/tmp")
  (check-equal? (test-simple-path-default-update) "/tmp")
  (check-equal? (test-simple-update-default-path)
                (list (path->string (simplify-path "/tmp/../foo"))
                      (path->string (simplify-path "/tmp/bar/../../bar"))))


  ;; In this config, the required parameters should all throw not-found exceptions
  (check-exn #rx"parameter was not found" test-simple-required)
  (check-exn #rx"parameter was not found" test-simple-path-required)
  (check-exn #rx"parameter was not found" test-simple-required-path)
  (check-exn #rx"parameter was not found" test-simple-path-required-update)
  (check-exn #rx"parameter was not found" test-simple-update-required-path)

  ;; Now we set their values in the config
  (define required-params-defined-pairs
    '((test-simple-required "test-simple-required value")
      (test-simple-path-required "/test-simple-path-required/value")
      (test-simple-required-path "/test-simple-required-path/value")
      (test-simple-path-required-update "/test-simple-path-required-update/value")
      (test-simple-update-required-path "/test-simple-update-required-path/value")))

  (config-pairs required-params-defined-pairs)

  (check-equal? (test-simple-required) "test-simple-required value")
  (check-equal? (test-simple-path-required) "/test-simple-path-required/value")
  (check-equal? (test-simple-required-path) "/test-simple-required-path/value")
  (check-equal? (test-simple-path-required-update) "/test-simple-path-required-update/value")
  (check-equal? (test-simple-update-required-path) "/test-simple-update-required-path/value")

  (define env-param-pairs
    `((test-env (getenv "TEST_CONFIG_VAR"))))

  (putenv "TEST_CONFIG_VAR" "TheConfigurator")
  (read-config-from-pairs env-param-pairs)

  (check-equal? (test-env) "TheConfigurator")

  ;; Testing required parameters simple case
  (define required-param-pairs
    '((test-simple-required "foo")))
  )
