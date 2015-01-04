;; lexp.scm --- discipline identifiers    -*- coding: utf-8 -*-
;;
;; Copyright (C) 2014 Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;;
;; Author: Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;; Created: 26 December 2014
;;
;; This file is part of Glean.
;;
;; This program is free software: you can redistribute it and/or modify it
;; under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
;; License for more details.
;;
;; You should have received a copy of the GNU Affero General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; 
;;
;;; Code:

(define-module (glean library lexp)
  #:use-module (glean common utils)
  #:use-module (glean library sets)
  #:use-module (glean library library-store)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9 gnu)
  #:export     (lexp
                lexp?
                lexp-base
                lexp-rest
                lexp-full
                lexp-set-resolve
                lexp-set-member
                lexp-set-base
                discipline-tree
                discipline-tree->serialized
                discipline-serialized->tree
                discipline-serialized-tree
                discipline-ancestry-tree))


;;;; Section Heading 1
;;;
;;; Section Commentary 1

(define-immutable-record-type <lexp>
  (lexp-mecha-make base rest)
  lexp?
  (base lexp-base)
  (rest lexp-rest))

(define (lexp-make base-or-full . rest-or-null)
  "Return a lexp, an expression which can be used to retrieve a specific
discipline within a library using simple list syntax.  BASE-OR-FULL can be a
symbol, identifying the starting point for the lexp path, or a list containing
the entire lexp path as symbols.  REST-OR-NULL will be a list of symbols if
BASE-OR-FULL is a symbol, or null if it is a list.

Example:

 (lexp-make '(git init))

This lexp can resolve to the init set located in the git discipline."
  (cond ((symbol? base-or-full)         ; symbol(s)->lexp
         (match rest-or-null
           ((or () ((? symbol?) ...))
            (lexp-mecha-make base-or-full rest-or-null))
           (_ (error "LEXP-MAKE: Unexpected REST-OR-NULL pattern"
                     rest-or-null))))
        ((null? rest-or-null)           ; list->lexp
         (match base-or-full
           (((? symbol? base) . ((? symbol? rest) ...))
            (lexp-mecha-make base rest))
           (_ (error "LEXP-MAKE: Unexpected BASE-OR-FULL pattern"
                     base-or-full))))
        (else (error "LEXP-MAKE: Unexpected ingredient pattern."))))

;; syntactic sugar for lexps.
(define-syntax lexp
  (syntax-rules ()
    ((lex exp)
     (lexp-make 'exp))))

(define (lexp-full lxp)
  "Return the full lexp contained in LXP, as would have been provided when
generating it."
  (match lxp
    (($ <lexp> base rest)
     (cons base rest))))

(define (lexp-set-resolve set lxp)
  "Extract the set identified by the lexp LXP from SET, or a nothing value
with id 'lexp-unknown, and context SET and LXP."
  (define (resolve next-set next-lxp)
    (match next-lxp
      ;; LEXP matches this set, and no further recursion needed.
      (($ <lexp> (? (lambda (base) (eqv? base (set-id next-set)))) ())
       next-set)
      ;; LEXP matches this set and we should recurse if possible.
      (($ <lexp> (? (lambda (base) (eqv? base (set-id next-set))))
          (= lexp-make rest))
       (match (lexp-set-member next-set rest)
         ;; Recursion possible, recurse
         ((? set? mtch) (lexp-set-resolve mtch rest))
         ;; Rest of NEXT-LXP does not point to set in SET.
         (_ (nothing 'lexp-unknown `(,(set-id set) ,lxp)))))
      ;; NEXT-LXP's base does not match NEXT-SET id.
      (($ <lexp>) (nothing 'lexp-unknown `(,(set-id set) ,lxp)))))

  (if (and (set? set) (lexp? lxp))
      (resolve set lxp)
      (error "LEXP-SET-RESOLVE: Unexpected SET or LEXP:" set lxp)))

(define (lexp-set-member set lxp)
  "Return the set that is a child of SET which matches the base of LXP, or
#f."
  (if (or (rootset? set) (null? (set-contents set)))
      #f                                ; rootset or no children
      (match (fold (lambda (disc result)
                     (cond (result result)
                           ((eqv? (lexp-base lxp) (set-id disc)) disc)
                           (else #f)))
                   #f
                   (set-contents set))
        ;; We have found our matching set
        ((? set? mtch) mtch)
        ;; We were unable to find our matching set
        (_ #f))))

(define (lexp-set-base set)
  "Return the base-lexp for SET."
  (lexp-make (set-id set)))

(define (discipline-tree-base discipline node-id)
  "A higher-order function which, when provided with a DISCIPLINE and a
procedure identifying how to generate node-id's called NODE-ID, returns the
appropriate tree representation of discipline."
  (define (make-leaf id foundation)
    (cons (node-id id foundation) '()))

  (define (make-node id foundation children)
    (cons (node-id id foundation)
          (map (recurse-maker (cons id foundation)) children)))

  (define (recurse-maker lxp-foundation)
    (lambda (set)
      (cond ((rootset? set)
             (make-leaf (set-id set) lxp-foundation))
            (else
             (make-node (set-id set) lxp-foundation (set-contents set))))))

  (if (plain-module? discipline)
      ((recurse-maker '()) discipline)
      (error "DISCIPLINE-TREE: DISCIPLINE is not a discipline:"
             discipline)))

(define (discipline-serialized-tree discipline)
  "Return a tree representation of DISCIPLINE, where each component set is
replaced by a write friendly representation of the lexp identifying it.

Each entry is a pair: ((lexp path) . (list children))

Output should hence be:
 ((root) . (((root one) . '())
            ((root two) . ((root two-one . '())))))"
  (discipline-tree-base discipline
                        (lambda (id foundation)
                          (reverse (cons id foundation)))))

(define (discipline-tree->serialized lexp-tree)
  "Return a \"serialized\" version of LEXP-TREE, i.e. a version that can be
read as a plain list structure and which can be turned back into a full
lexp-tree using `discipline-serialized->tree.'"
  (match lexp-tree
    (((? lexp? lxp) . rest)
     (cons (lexp-full lxp)
           (map discipline-tree->serialized rest)))))

(define (discipline-serialized->tree serialized-tree)
  "Return a lexp-tree generated from the serialized lexp-tree
SERIALIZED-TREE.  This procedure is the counterpart to
`discipline-tree->serialized'."
  (match serialized-tree
    (((? list? full-lexp) . rest)
     (cons (lexp-make full-lexp)
           (map discipline-serialized->tree rest)))))

(define (discipline-tree discipline)
  "Return a tree representation of DISCIPLINE, where each component set is
replaced by the lexp identifying it.

Each entry is a pair: (lexp . (list children))

Output should hence be:
 (lexp . ((lexp . '())
          (lexp . ((lexp . '())))))"
  (discipline-tree-base discipline
                        (lambda (id foundation)
                          (lexp-make (reverse (cons id foundation))))))

(define (discipline-ancestry-tree discipline ancestor)
  "Return a tree providing a schema by which an ancestor lexp-tree could be
modified to the equivalent tree for discipline.

Ancestry trees always operate on serialized trees, as their primary function
relates to their being read/written to/from files and passed to the lounge.

Finally, the hashes we use here are shallow hashes: they capture changes to
the structure of the discipline and version changes.  The hashing procedure
that will be used is set-shallow-hash (a hash of the set's lexp, each direct
child lexp, and its version).  For now we use set-fullhash (in the long term
this is undesirable as it will force lounge updates on a far to frequent
basis).

The format is as follows:
 ((ancestor-hash . disc-hash) . ((ancestor-hash . disc-hash) ...))

The resulting tree may contain nothings of id 'lexp-unknown, if some lexp's in
DISCIPLINE did not resolve to sets in ANCESTOR."

  (define (node-id id foundation)
    (match (lexp-set-resolve discipline
                             (lexp-make (reverse (cons id foundation))))
      ((? (lambda (set) (and (set? set) (lexp? (set-lineage set)))) set)
       (cons (match (lexp-set-resolve ancestor (set-lineage set))
               ((? set? set) (set-fullhash set))
               (otherwise otherwise))
             (set-fullhash set)))
      ((? set? set)
       (cons #f (set-fullhash set)))
      (($ <nothing> 'lexp-unknown context)
       (nothing 'lexp-unknown context))
      (_ (error "DISCIPLINE-ANCESTRY-TREE: BUG: unexpected behaviour."))))

  (discipline-tree-base discipline node-id))

;;; lexp ends here
