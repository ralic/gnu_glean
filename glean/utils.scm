;;; glean --- Fast learning tool.         -*- coding: utf-8 -*-

;;;; Generic Utilities

;;; Copyright © 2012, 2013, 2014 Ludovic Courtès <ludo@gnu.org>,
;;; Alex Sassmannshausen <alex.sassmannshausen@gmail.com>

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 59 Temple Place - Suite 330        Fax:    +1-617-542-2652
;; Boston, MA  02111-1307,  USA       gnu@gnu.org

(define-module (glean utils)
  #:use-module (ice-9 match)
  #:use-module (rnrs records inspection)
  #:export (
            seq
            flatten
            mkdir-p
            clog
            llog
            gmsg
            rprinter
            relevant?
            display=>
            emit-usage
            emit-version
            ))

(define (display=> x) (format #t "~a\n" x) x)

(define (seq a b)
  "Return a list, counting upwards, from A to B (inclusive)."
  (define (helper curr result)
    (if (> curr b) (reverse result) (helper (1+ curr)
                                            (cons curr result))))
  (if (> a b) '() (helper 1 '())))

(define (flatten obj)
  (cond ((null? obj) '())
        ((not (pair? obj)) (list obj))
        (else
         (append (flatten (car obj))
                 (flatten (cdr obj))))))

(define (mkdir-p dir)
  "Create directory DIR and all its ancestors."
  (define absolute?
    (string-prefix? "/" dir))

  (define not-slash
    (char-set-complement (char-set #\/)))

  (let loop ((components (string-tokenize dir not-slash))
             (root       (if absolute?
                             ""
                             ".")))
    (match components
      ((head tail ...)
       (let ((path (string-append root "/" head)))
         (catch 'system-error
           (lambda ()
             (mkdir path)
             (loop tail path))
           (lambda args
             (if (= EEXIST (system-error-errno args))
                 (loop tail path)
                 (apply throw args))))))
      (() #t))))

(define (llog args)
  "Returns #undefined. Provide logic-warning log abstraction:
a gmsg call with ARGS defaulting to #:priority 1."
  (gmsg #:priority 1 args))

(define (clog args)
  "Returns #undefined. Provide communications-warning log abstraction:
a gmsg call with ARGS defaulting to #:priority 3."
  (gmsg #:priority 3 args))

(define (rprinter record)
  "Returns #f if RECORD is not a record, #t otherwise. Recursively
prints RECORD and its fields as a side-effect if #t."

  (if (record? record)
      (let* ((rtd (record-rtd record))
             (fields (vector->list (record-type-field-names rtd)))
             (length (length fields))
             (port (current-output-port)))

        (define (print-fields remaining index)
          (cond ((null? remaining)
                 #t)
                (else
                 (let ((field-value ((record-accessor rtd index)
                                     record)))
                   (cond ((record? field-value)
                          (format port "   ~a: ~a\n" (car remaining)
                                  field-value)
                          (rprinter field-value))
                         ((and (list? field-value)
                               (not (null? field-value))
                               (record? (car field-value)))
                          (for-each (lambda (arg)
                                      (rprinter arg))
                                    field-value))
                         (else
                          (format port "   ~a: ~a\n" (car remaining)
                                  field-value))))
                 (print-fields (cdr remaining) (1+ index)))))

        (format port "record: ~a\n" (record-type-name rtd))
        (print-fields fields 0)
        (format port ":end:\n"))
      #f))

(define* (gmsg #:key (priority 10) . args)
  "Provide a simple debugging message system. Prints ARGS with Format
if PRIORITY is lower than %DEBUG% set in config.scm."
  (let ((%debug% 10))
    (define (indent length)
      (define (i l s)
        (if (zero? l)
            s
            (i (1- l) (string-append " " s))))
      
      (if (zero? length)
          ""
          (i (1- length) " ")))
    (define (gm args format-string)
      (cond ((null? args) format-string)
            (else (gm (cdr args) (string-append format-string " ~S")))))
    (if (< priority %debug%)
        (let ((port (current-output-port)))
          (format port "~a* Debug:" (indent (1- priority)))
          (apply format port (gm args " ") args)
          (newline port)))))

(define* (relevant? priority #:key (%log-level% 'debug))
  (define (weigh rating)
    (cond ((eqv? rating 'critical)  0)
          ((eqv? rating 'important) 1)
          ((eqv? rating 'warning)   2)
          ((eqv? rating 'inform)    3)
          (else rating 4)))           ; 'debug
  (let ((urgency (weigh priority))
        (filter  (weigh %log-level%)))
    (<= urgency filter)))

(define (emit-version package-name version)
  "Output a version message and exit."
  (format #t
          "~a ~a
Copyright (C) 2014 Alex Sassmannshausen.
~a comes with ABSOLUTELY NO WARRANTY.
License: GNU AGPL version 3 or later <http://gnu.org/licenses/agpl.html>.
This is Free Software: you are free to change and redistribute it under the
terms of the above license.

For more information about these matters, see the file named COPYING.
"
          package-name version package-name))

(define (emit-usage command synopsis description options messages)
  "Return a usage message formatted in the following fashion:
Usage: COMMAND [--LONG-OPT | -SHORT-OPT]
               ...
  LONG-OPT:   MESSAGE
"
  (define (name-char-pair option)
    (match option
      ((name ('single-char char) value)
       (cons (symbol->string name) (make-string 1 char)))
      ((name . _)
       (list (symbol->string name)))
      (_ (error "USAGE -- Unexpected option:" option))))
  (define (info-line pair)
    (match pair
      ((name . ()) (string-append "[--" name "]"))
      ((name . char) (string-append "[--" name " | -" char "]"))
      (_ (error "USAGE -- Should be impossible:" pair))))
  (define (spaces length)
    (if (negative? length)
        (error "USAGE -- option name is too long!")
        (make-string length #\ )))
  
  (let ((pairs (map name-char-pair options)))
    (match (map info-line pairs)
      ((first . rest)
       (format #t "Usage:     ~a ~a\n" command first)
       (for-each (lambda (info)
                   (format #t "           ~a ~a\n"
                           (spaces (string-length command)) info))
                 rest)))
    (newline)
    (format #t "~a" synopsis)
    (newline)
    (for-each (lambda (pair message)
                (match pair
                  ((name . char)
                   (format #t "      ~a:~a~a\n"
                           name
                           (spaces (- 15 (string-length name)))
                           message))))
              pairs messages)
    (newline)
    (format #t "~a" description)
    (newline)))
