;;; guile-ares-rs --- Asynchronous Reliable Extensible Sleek RPC Server
;;;
;;; Copyright © 2024 Nikita Domnitskii <nikita@domnitskii.me>
;;;
;;; This file is part of guile-ares-rs.
;;;
;;; guile-ares-rs is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; guile-ares-rs is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with guile-ares-rs.  If not, see <http://www.gnu.org/licenses/>.

(define-module (ares reflection metadata)
  #:use-module (ice-9 documentation)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-197)
  #:use-module (system vm debug)
  #:use-module (system vm program)
  #:export (get-arglists
            get-docstring
            get-source))

(define (pattern->argument-alist pattern)
  (let lp ((pattern pattern)
           (required '()))
    (match pattern
      (()
       `((required . ,(reverse required))
         (optional)
         (keyword)
         (allow-other-keys? . #f)
         (rest . #f)))
      ((? symbol? sym)
       `((required . ,(reverse required))
         (optional)
         (keyword)
         (allow-other-keys? . #f)
         (rest . ,sym)))
      (((? symbol? sym) . rest)
       (lp rest (cons sym required)))
      (_ #f))))

(define (stringify-arglist arglist)
  (define (stringify-arg arg)
    (match arg
      ((? symbol? arg) (symbol->string arg))
      (((? keyword? arg) . _) (symbol->string (keyword->symbol arg)))))

  (map (match-lambda
         ((k . v)
          (cons (symbol->string k)
                (cond
                 ((list? v) (list->vector (map stringify-arg v)))
                 ((symbol? v) (symbol->string v))
                 ((boolean? v) (if v "true" #()))
                 (else v)))))
       arglist))

(define (get-arglists var)
  "Return list of all arities for VAR."
  ;; NOTE: [Nikita Domnitskii, 2024-04-05] would be used for syntax-case
  ;; macros (anything else?)
  (define fallback-macro-signatures
    '(((required ...)
       (optional)
       (keyword)
       (allow-other-keys? . #f)
       (rest . #f))))

  (define (get-arglists* var)
    (cond
     ((macro? var)
      (or (chain-and
           var
           (macro-transformer _)
           (procedure-property _ 'patterns)
           (filter-map pattern->argument-alist _))
          fallback-macro-signatures))
     ((program? var)
      (program-arguments-alists var))
     (else #f)))

  (chain-and
   (get-arglists* var)
   (map stringify-arglist _)))

;; TODO: [Nikita Domnitskii, 2024-04-05] reimplement object-documentation
;; and split docstrings and description from documentation files to
;; separate functions
(define (get-docstring var)
  "Return docstring for VAR."
  (object-documentation var))

;; TODO: [Nikita Domnitskii, 2024-04-05] should be get-sources probably
(define (get-source var)
  "Return source object for VAR."
  (cond
   ((macro? var) (chain-and
                  (macro-transformer var)
                  (program-source _ 0)))
   ((program? var) (program-source var 0))
   (else #f)))
