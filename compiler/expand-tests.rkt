#lang racket/base
(require rackunit racket/file racket/runtime-path racket/string "expand.rkt")

(define-runtime-path here ".")
(define fixture (file->string (build-path here "../tests/fixtures/multiply.forge")))
(define expected (file->bytes (build-path here "../tests/fixtures/multiply.fir")))
(check-equal? (forge-source->ir fixture) expected)

(check-exn exn:fail?
  (lambda ()
    (forge-source->ir
     (string-replace fixture "ASSERT RESULT EQUALS 96" "ASSERT RESULT EQUALS 95"))))

(check-exn exn:fail?
  (lambda ()
    (forge-source->ir
     (string-replace fixture "a TIMES b INTO RESULT" "a PLUS b INTO RESULT"))))

(displayln "Racket FORGE expansion tests passed")
