Copyright (C) 2026 ERRANT DIGITAL INSTITUTE OF TECHNOLOGY (SEIT NGO) % SNAPKITTY COLLECTIVE
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Commercial
// See LICENSE-AGPL and LICENSE-COMMERCIAL in this repository for license terms.

#lang racket/base

(define-values (toks diags) (lex-source "MODULE Arithmetic\nTYPE\n Word = UNSIGNED 64\n"))
(check-equal? diags '())
(check-eq? (tok-type (list-ref toks 0)) 'MODULE)
(check-equal? (tok-lexeme (list-ref toks 1)) "Arithmetic")
(check-eq? (tok-type (list-ref toks 2)) 'TYPE)
(check-equal? (tok-lexeme (list-ref toks 3)) "Word")
(check-eq? (tok-type (list-ref toks 4)) 'EQSIGN)
(check-eq? (tok-type (list-ref toks 5)) 'UNSIGNED)
(check-eq? (tok-type (list-ref toks 6)) 'NUMBER)
(check-equal? (tok-lexeme (list-ref toks 6)) "64")
(check-eq? (tok-type (list-ref toks 7)) 'EOF)
(check-equal? (tok-line (list-ref toks 5)) 3)

;; keywords are case-sensitive uppercase; Result is an identifier
(define-values (t2 d2) (lex-source "Result RESULT"))
(check-equal? d2 '())
(check-eq? (tok-type (list-ref t2 0)) 'IDENT)
(check-eq? (tok-type (list-ref t2 1)) 'RESULT)

;; comments and unknown characters
(define-values (t3 d3) (lex-source "LET x BE 1 # trailing comment\n"))
(check-equal? d3 '())
(check-eq? (tok-type (list-ref t3 0)) 'LET)
(define-values (t4 d4) (lex-source "LET x BE @"))
(check-true (pair? d4))

#lang racket/base
(require rackunit "../syntax/lexer.rkt" "../syntax/parser.rkt" "../syntax/ast.rkt")

(define src
  "MODULE Arithmetic\nTYPE\n Word = UNSIGNED 64\n\nFUNCTOR Multiply\n ACCEPT Word a\n ACCEPT Word b\n RETURN Word\n EXECUTE\n a TIMES b INTO RESULT\n END\n PROVE\n RESULT EQUALS a TIMES b\n END\nEND\n\nPROGRAM Main\n LET x BE 12\n INVOKE Multiply WITH x, 12\n ASSERT RESULT EQUALS 96\nEND\n")

#lang racket/base
(require rackunit "../syntax/lexer.rkt" "../syntax/parser.rkt" "../syntax/ast.rkt" "../compiler/semantic.rkt")

(define (run src)
  (define-values (toks ld) (lex-source src))
  (define-values (ast pd) (parse-tokens toks))
  (check-equal? ld '())
  (check-equal? pd '())
  (define-values (info diags) (analyze-program ast))
  diags)

(check-equal? (run good-src) '())
(check-true (pair? (run "MODULE M\nPROGRAM Main\n ASSERT RESULT EQUALS 1\nEND\n")))
(check-true (pair? (run "MODULE M\nPROGRAM Main\n INVOKE Nope WITH 1\nEND\n")))

#lang racket/base
(require rackunit "../syntax/lexer.rkt" "../syntax/parser.rkt" "../compiler/semantic.rkt" "../compiler/ir.rkt")

(define src "...arithmetic...")
(define-values (toks ld) (lex-source src))
(define-values (ast pd) (parse-tokens toks))
(define-values (info sd) (analyze-program ast))
(check-equal? ld '()) (check-equal? pd '()) (check-equal? sd '())
(define ir (generate-ir ast info))
(check-equal? (list-ref ir 1) '(version 1))
(check-equal? (list-ref ir 2) '(module Arithmetic))
(define f (find (lambda (x) (and (pair? x) (eq? (car x) 'functor))) ir))
(check-equal? (list-ref f 1) 'Multiply)

#lang racket/base
(require rackunit "../compiler/lower.rkt" "../syntax/lexer.rkt" "../syntax/parser.rkt" "../compiler/semantic.rkt" "../compiler/ir.rkt")

(define ir ...)
(define instrs (lower-ir ir))
(check-true (pair? instrs))
(for ([i instrs]) (check-true (pair? (stack-effect i))))

(define (find-sec tag f)
  (cond
    [(null? f) #f]
    [(and (pair? (car f)) (eq? (caar f) tag)) (car f)]
    [else (find-sec tag (cdr f))]))

(define functors (filter (lambda (x) (and (pair? x) (eq? (car x) 'functor))) (cdr ir)))

(define (find-tag tag xs)
  (cond [(null? xs) #f] [(and (pair? (car xs)) (eq? (caar xs) tag)) (car xs)] [else (find-tag tag (cdr xs))]))

(define (lower-ir ir)
  (define functors (filter (lambda (x) (and (pair? x) (eq? (car x) 'functor))) (cdr ir)))
  (define prog (find-tag 'program (cdr ir)))
  (define execs
    (apply append
           (for/list ([f functors])
             (define ex (find-tag 'exec f))
             (apply append (map lower-stmt (cdr ex))))))
  (define main (apply append (map lower-stmt (cdr prog))))
  (append execs main))

#lang racket/base
(require "test-lexer.rkt" "test-parser.rkt" "test-semantic.rkt" "test-ir.rkt" "test-lower.rkt")
(displayln "FORGE: all compiler tests passed")

#lang racket/base
(require racket/pretty)
(require "syntax/tokens.rkt" "syntax/lexer.rkt" "syntax/parser.rkt"
         "syntax/ast.rkt" "syntax/diagnostics.rkt"
         "compiler/semantic.rkt" "compiler/ir.rkt")

(define (report-and-exit src diags)
  (for ([d diags]) (displayln (error->string d src)))
  (exit 1))

(define (main args)
  (define file #f)
  (define dump 'ir)
  (let loop ([a args])
    (cond
      [(null? a) (void)]
      [(and (pair? (cdr a)) (equal? (car a) "--dump"))
       (set! dump (string->symbol (cadr a)))
       (loop (cddr a))]
      [(string-prefix? (car a) "--dump=")
       (set! dump (string->symbol (substring (car a) 7)))
       (loop (cdr a))]
      [else (set! file (car a)) (loop (cdr a))]))
  (unless file
    (displayln "usage: racket forge.rkt FILE.forge [--dump tokens|ast|ir]")
    (exit 2))
  (define src (file->string file))
  (define-values (toks lex-diags) (lex-source src))
  (unless (null? lex-diags) (report-and-exit file lex-diags))
  (cond
    [(eq? dump 'tokens)
     (for ([t toks]) (displayln (token-dump-line t)))]
    [else
     (define-values (ast parse-diags) (parse-tokens toks))
     (unless (null? parse-diags) (report-and-exit file parse-diags))
     (cond
       [(eq? dump 'ast)
        (displayln (pretty-format (ast->sexpr ast) #\:mode 'write))]
       [else
        (define-values (info sem-diags) (analyze-program ast))
        (unless (null? sem-diags) (report-and-exit file sem-diags))
        (displayln (pretty-format (generate-ir ast info) #\:mode 'write))])]))

(main (vector->list (current-command-line-arguments)))

(define (parse-arith)
  (define start (peek))
  (let ([l (parse-term)])
    (and l
         (let loop ([l l])
           (define tt (tok-type (peek)))
           (cond
             [(memq tt '(PLUS MINUS))
              (advance!)
              (let ([r (parse-term)])
                (and r (loop (Bin tt l r (loc-of start)))))]
             [else l])))))

(define (parse-factor)
  (define t (peek))
  (define tt (tok-type t))
  (cond
    [(eq? tt 'NUMBER) (advance!) (Num (string->number (tok-lexeme t)) (loc-of t))]
    [(eq? tt 'IDENT) (advance!) (Ref (string->symbol (tok-lexeme t)) (loc-of t))]
    [(eq? tt 'RESULT) (advance!) (ResultRef (loc-of t))]
    [(eq? tt 'LPAREN)
     (advance!)
     (let ([e (parse-expr)])
       (and e
            (let ([rp (check 'RPAREN "expected ')'")])
              (and rp e))))]
    [else (fail! "expected an expression") #f]))

(define (parse-functor)
  (define start (peek))
  (let ([kw (check 'FUNCTOR "expected FUNCTOR")]
        [name (check 'IDENT "expected functor name after FUNCTOR")])
    (and kw name
         (let ([params (parse-accepts)])
           (and params
                (let ([has-ret (eq? (tok-type (peek)) 'RETURN)])
                  (let ([ret (if has-ret (begin (advance!) (parse-type)) #f)])
                    (and (or (not has-ret) ret)
                         (let ([ex (check 'EXECUTE "expected EXECUTE after functor signature")])
                           (and ex
                                (let ([body (parse-stmts)])
                                  (and body
                                       (let ([prove (parse-prove)])
                                         (and prove
                                              (let ([end-tok (check 'END "expected END to close FUNCTOR")])
                                                (and end-tok
                                                     (Functor (string->symbol (tok-lexeme name))
                                                              params ret body prove
                                                              (loc-of start)))))))))))))))))
