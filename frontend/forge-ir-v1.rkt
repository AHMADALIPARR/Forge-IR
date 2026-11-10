Copyright (C) 2026 ERRANT DIGITAL INSTITUTE OF TECHNOLOGY (SEIT NGO) % SNAPKITTY COLLECTIVE
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Commercial
// See LICENSE-AGPL and LICENSE-COMMERCIAL in this repository for license terms.

```racket

#lang racket/base

(provide
  (struct-out forge-module)
  (struct-out forge-function)
  (struct-out forge-instruction)
  forge-ir-v1->bytes
  validate-forge-module)

(struct forge-module (id functions) #:transparent)
(struct forge-function (id argument-count register-count instructions) #:transparent)
(struct forge-instruction (opcode operands) #:transparent)

(define (fail who message . fields)
  (raise-arguments-error who message fields))

(define (natural? n)
  (and (exact-integer? n) (>= n 0)))

(define (signed-integer? n)
  (exact-integer? n))

(define (check-register who register register-count)
  (unless (and (natural? register) (< register register-count))
    (fail who "register index outside declared register range"
          "register" register
          "register-count" register-count)))

(define (validate-instruction instruction register-count)
  (define opcode (forge-instruction-opcode instruction))
  (define operands (forge-instruction-operands instruction))

  (define (arity! expected)
    (unless (= (length operands) expected)
      (fail 'validate-forge-module
            "incorrect instruction operand count"
            "opcode" opcode
            "expected" expected
            "actual" (length operands))))

  (define (registers! indices)
    (for ([index (in-list indices)])
      (check-register 'validate-forge-module index register-count)))

  (case opcode
    [(CONST)
     (arity! 2)
     (registers! (list (first operands)))
     (unless (signed-integer? (second operands))
       (fail 'validate-forge-module "CONST requires a signed integer"))]

    [(MOVE)
     (arity! 2)
     (registers! operands)]

    [(ADD SUB MUL)
     (arity! 3)
     (registers! operands)]

    [(RETURN)
     (arity! 1)
     (registers! operands)]

    [else
     (fail 'validate-forge-module "unsupported opcode" "opcode" opcode)]))

(define (validate-function function)
  (define argc (forge-function-argument-count function))
  (define regc (forge-function-register-count function))
  (define instructions (forge-function-instructions function))

  (unless (natural? (forge-function-id function))
    (fail 'validate-forge-module "function ID must be nonnegative"))

  (unless (and (natural? argc) (natural? regc) (<= argc regc))
    (fail 'validate-forge-module "invalid function register declaration"
          "arguments" argc
          "registers" regc))

  (unless (and (list? instructions) (pair? instructions))
    (fail 'validate-forge-module "function must contain instructions"))

  (for ([instruction (in-list instructions)])
    (validate-instruction instruction regc))

  (unless (eq? (forge-instruction-opcode (last instructions)) 'RETURN)
    (fail 'validate-forge-module "function must end with RETURN"))

  (when (ormap
         (lambda (instruction)
           (eq? (forge-instruction-opcode instruction) 'RETURN))
         (drop-right instructions 1))
    (fail 'validate-forge-module "RETURN may only appear as final instruction")))

(define (validate-forge-module module)
  (unless (natural? (forge-module-id module))
    (fail 'validate-forge-module "module ID must be nonnegative"))

  (define functions (forge-module-functions module))

  (unless (list? functions)
    (fail 'validate-forge-module "functions must be a list"))

  (define ids (map forge-function-id functions))

  (unless (= (length ids) (length (remove-duplicates ids)))
    (fail 'validate-forge-module "duplicate function ID"))

  (unless (equal? ids (sort ids <))
    (fail 'validate-forge-module "functions must be sorted by ID"))

  (for ([function (in-list functions)])
    (validate-function function))

  module)

(define (canonical-integer n)
  (unless (exact-integer? n)
    (error 'canonical-integer "non-integer operand"))
  (number->string n))

(define (instruction->line instruction)
  (string-join
   (cons (symbol->string (forge-instruction-opcode instruction))
         (map canonical-integer (forge-instruction-operands instruction)))
   " "))

(define (function->lines function)
  (append
   (list
    (string-join
     (list "FUNC"
           (canonical-integer (forge-function-id function))
           (canonical-integer (forge-function-argument-count function))
           (canonical-integer (forge-function-register-count function)))
     " "))
   (map instruction->line (forge-function-instructions function))
   (list "ENDFUNC")))

(define (module->string module)
  (string-join
   (append
    (list "FORGE-IR 1"
          (string-append "MODULE " (canonical-integer (forge-module-id module))))
    (append-map function->lines (forge-module-functions module))
    (list "ENDMODULE"))
   "\n"))

(define (forge-ir-v1->bytes module)
  (validate-forge-module module)
  (string->bytes/utf-8 (string-append (module->string module) "\n")))
```
