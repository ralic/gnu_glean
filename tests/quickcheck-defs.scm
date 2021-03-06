;; quickcheck-defs.scm --- quickcheck definitions    -*- coding: utf-8 -*-
;;
;; Copyright (C) 2014 Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;;
;; Author: Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;; Created: 01 January 2014
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
;; Quickcheck is a property testing framework originally developed
;; for Haskell. Glean uses the portable scheme implementation of
;; Quickcheck created by IJP.
;;
;; This library defines generators specific to glean data-types
;; for use by quickcheck tests.
;;
;;; Code:

(define-module (tests quickcheck-defs)
  #:use-module (quickcheck quickcheck)
  #:use-module (ice-9 format)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-27)
  #:use-module (glean common comtools)
  #:use-module (glean lounge profiles)
  #:use-module (glean library lexp)
  #:use-module (glean library sets)
  #:use-module (glean lounge scorecards)
  #:use-module (glean common base-requests)
  #:use-module (glean common library-requests)
  #:use-module (glean common lounge-requests)
  #:export (
            $mk-rootset
            $mk-set
            $mk-discipline
            $mk-hashtree
            $mk-hashmap
            $question
            $solution
            $option
            $medii
            $prob
            $pred

            $profile
            
            $scorecard
            $empty-scorecard
            $mk-rootblob
            $mk-blob-list

            $request
            $response

            $aliveq
            $challq
            $challs
            $evalq
            $evals
            $acks
            $negs
            $unks
            $quitq

            $datum
            $record
            $simple-tagged-list
            $tagged-list
            quickname
            $short-list
            $short-assoc
            ))

;;;;; Set Generators
(define* ($mk-rootset #:key problems)
  "Return a randomised set.  If PROBLEMS is a number, force $rootset to
produce this number of problems."
  (make-set ($symbol)                          ; id
            (($short-list $prob problems))     ; contents
            ($string) ($string)                ; name / version
            ($string) ($string)                ; synopsis / description
            (($short-list $string))            ; keywords
            ($string)                          ; creator
            (($short-list $medii))             ; attribution
            (($short-list $medii))             ; resources
            ($string)                          ; logo
            (($short-assoc $symbol $string)))) ; properties

(define* ($mk-set #:key children (depth 1))
  "Return a randomised set containing DEPTH levels of children.  The final
level consists of rootsets.  If CHILDREN is a number, force $mk-set to produce
child-sets with each CHILDREN of children."
  (make-set ($symbol)                                ; id
            (if (= depth 1)
                (($short-list (lambda ()
                                ($mk-rootset #:problems children))
                              children))
                (($short-list (lambda ()
                                ($mk-set #:children children
                                         #:depth (1- depth)))
                              children)))                 ; contents
            ($string) ($string)                      ; name / version
            ($string) ($string)                      ; synopsis / description
            (($short-list $string))                  ; keywords
            ($string)                                ; creator
            (($short-list $medii))                   ; attribution
            (($short-list $medii))                   ; resources
            ($string)                                ; logo
            (($short-assoc $symbol $string))))       ; properties

(define* ($mk-discipline #:key children (depth 1))
  "Return a randomised set containing DEPTH levels of children.  The final
level consists of rootsets.  If CHILDREN is a number, force $mk-set to produce
child-sets with each CHILDREN of children."
  (make-set ($symbol)                                ; id
            (if (= depth 1)
                (($short-list (lambda ()
                                ($mk-rootset #:problems children))
                              children))
                (($short-list (lambda ()
                                ($mk-set #:children children
                                         #:depth (1- depth)))
                              children)))                 ; contents
            ($string) ($string)                      ; name / version
            ($string) ($string)                      ; synopsis / description
            (($short-list $string))                  ; keywords
            ($string)                                ; creator
            (($short-list $medii))                   ; attribution
            (($short-list $medii))                   ; resources
            ($string)                                ; logo
            '((module . #t))))

(define* ($mk-hashtree #:optional (input $mk-set))
  "Return a randomised hashtree built of INPUT (should be $mk-set or
$mk-rootset)."
  ((@@ (glean library library-store) make-hashtree) (input) (lexp-make 'test)))

(define* ($mk-hashmap #:optional (num-trees 1) (input $mk-set))
  (($short-list (lambda () ($mk-hashtree input)) num-trees)))

;; FIXME: should randomly populate the media fields
(define ($medii)
  "Return a randomised media record."
  (media #:text ($string)))

(define ($prob)
  "Return a randomised problem."
  (apply problem ($question) ($solution) ($pred)
         (($short-list $option))))
;; FIXME: Should include $medii at random points
(define ($question)
  "Return a randomised question."
  (q ($string)))
(define ($solution)
  "Return a randomised solution."
  (s ($string)))
(define ($option)
  "Return a randomised option."
  (o ($string)))
(define ($pred)
  "Return a randomised predicate."
  (p (from-list (list eq? = eqv? equal?))))
;;

;;;;; Profile Generators
;; FIXME: There should be a good chance that active-module set-ids
;; coincide with scorecard mod-blobs.
(define ($profile)
  "Return a randomised profile."
  (let ((name ($string)))
    (make-profile name ($string) ($string)
                  (($short-list ($pair $symbol $symbol)))
                  ($scorecard))))

(define ($scorecard)
  "Return a randomised scorecard."
  (make-scorecard (($short-list $mk-rootblob))))
(define ($empty-scorecard)
  "Return an empty scorecard."
  (make-scorecard '()))

(define* ($mk-rootblob #:optional (parent '()))
  "Return a randomised blob with now children."
  (make-blob ($string)                          ; hash
             (if parent (list parent) '())      ; parent
             '()                                ; children
             ($small)                           ; score
             ($integer)                         ; counter
             (($short-assoc $symbol $string))   ; properties
             (($short-assoc $symbol $string))   ; effects
             (($short-list $symbol))            ; base-lexp
             ($string)))                        ; dag-hash

(define* ($mk-blob #:optional child_num (depth 1) (parent '()))
  "Return a randomised blob containing DEPTH levels of children.  The final
level consists of rootblobs.  If CHILD_NUM is a number, force $mk-blob to produce
child-blobs with each CHILD_NUM of children."
  (let ((id ($string)))
    (make-blob id                       ; id
               (if (and parent (not (null? parent)))
                   (list parent) '())   ; parent
               (cond ((< depth 1)
                      '())              ; children
                     ((= depth 1)
                      (($short-list (lambda ()
                                      ($mk-rootblob id))
                                    child_num)))
                     (else
                      (($short-list (lambda ()
                                      ($mk-blob child_num (1- depth) id))
                                    child_num))))
               ($small)                         ; score
               ($integer)                       ; counter
               (($short-assoc $symbol $string)) ; properties
               (($short-assoc $symbol $string)) ; effects
               (($short-list $symbol))          ; base-lexp
               ($string))))                     ; dag-hash


;;;;; Request Generators
(define ($unks)
  "Return a randomised unk-response."
  (unks ($datum)))
(define ($negs)
  "Return a randomised neg-response."
  (negs ($datum) ($symbol)))
(define ($acks)
  "Return a randomised ack-response."
  (acks ($datum)))

(define ($aliveq)
  "Return an $aliveq."
  (aliveq))

(define ($evalq)
  "Return a randomised eval-request."
  (evalq ($profile)))
(define ($evals)
  "Return a randomised eval-response."
  (evals ($profile) ($boolean)))
(define ($challq)
  "Return a randomised chall-request."
  (challq ($profile)))
(define ($challs)
  "Return a randomised chall-response."
  (challs ($profile) ($challenge)))

(define ($quitq)
  "Return a quit-request."
  (quitq))

;;;;; Extra Generators & Functions
(define* ($short-list generator #:optional num_problems)
  "Return a list with up to ten members of type returned by
GENERATOR."
  (lambda ()
    (build-list (if (number? num_problems) num_problems ($small))
                (lambda (_) (generator)))))
(define* ($short-assoc key-generator value-generator #:optional guarantee?)
  "Return an association list with up to ten members of type returned by
KEY-GENERATOR and VALUE-GENERATOR.  If GUARANTEE? then ensure the list
contains at least one entry."
  (lambda ()
    (let gen ()
      (let ((lst (($short-list ($pair key-generator value-generator)))))
        (if (and guarantee? (null? lst))
            (gen) lst)))))

(define (quickname name)
  "Return is undefined. Print quickcheck intro message and NAME."
  (simple-format #t "starting quickcheck: ~a" name)
  (newline))

;; FIXME: In addition, should randomly return: request, record as
;; original
(define ($datum)
  "Return a random instance of one of the data enumerated in the list."
  ((from-list (list $string $symbol $integer $profile))))

(define ($record)
  "Return a random record enumerated in the list."
  ((from-list (list $profile $scorecard $mk-set))))

;; (define ($simple-tagged-list)
;;   "Return a random simple record (without without nested records)."
;;   ((from-list (list (lambda () (record->list* ($mk-rootblob)))
;;                     (lambda () (record->list* ($id ($string))))))))

(define ($tagged-list)
  "Return a random record enumerated in the list."
  ((from-list (list (lambda ()
                      (record->list* ($profile)))
                    (lambda ()
                      (record->list* ($scorecard)))
                    (lambda ()
                      (record->list* ($mk-set)))))))

;;;;; Support Generators & Functions
;;;; This section contains library internal definitions that should
;;;; not normally be needed when writing quickcheck tests. These
;;;; functions are used by some of the generators in the rest of the
;;;; library.

;; FIXME: Challenge may well be an abstraction that includes agreed
;; instructions to the client on providing options etc.
(define ($challenge)
  "Return challenge abstraction datum."
  ($string))

(define ($small)
  "Return a integer up to value 10."
  (random-integer 10))

(define (from-list list)
  "Return a random member from LIST."
  (list-ref list (random-integer (length list))))

;; Straight copy from quickcheck.sls
(define (build-list size proc)
  (define (loop i l)
    (if (negative? i)
        l
        (loop (- i 1) (cons (proc i) l))))
  (loop (- size 1) '()))

;;; quickcheck-defs ends here
