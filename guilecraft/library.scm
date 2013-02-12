#! /usr/bin/guile -s

coding:utf-8
!#

;;; Commentary:

;; library handles all in-game module data. 
;; Library stores in-game module and level data, 
;; - requests information from fs handler on load
;; - pushes information to fs handler for writing
;; Is asked for info by question evaluator, weighting 
;; system question generator.

;;; Code:

(define-module (guilecraft library)
  #:export (librarian          ;used by Balancer, Generator, Evaluator
            )
  #:use-module (guilecraft data-types)
  #:use-module (guilecraft file-server)) ; currently not used

(define (librarian command . parameters)
  "Scans an incoming request for @var{command} and invokes the correct procedure to resolve it.

@var{parameters} must be:
- a tag, if the command is 'provide-question or 'provide-solution
- a module, if the command is 'build-library.

'provide-tags is a thunk that simply returns all tags currently providing a stream within the library."
					; Simple dispatcher
					; First, are tags requested?
  (cond ((provide-tags? command)
         (retrieve-current-tag-set))
					; Is a question requested?
        ((provide-question? command) 
         (retrieve-current-question parameter))
					; Is a solution requested?
        ((provide-solution? command)
         (retrieve-current-solution))
					; Does the library exist yet?
					; (Should normally only be invoked upon launch)
        ((build-library? command)
         (build-library parameter))
					; Command not found
        (else #f)))

(define (retrieve-current-tag-set)
    '())

;; Predicates used by librarian:
(define (provide-level? subject)
  (eqv? 'provide-level subject))
(define (provide-tags? subject)
  (eqv? 'provide-tags subject))
(define (provide-question? subject)
  (eqv? 'provide-question subject))
(define (provide-solution? subject)
  (eqv? 'provide-solution subject))
(define (build-library? subject)
  (eqv? 'build-library subject))

(define (request-problem-ID-set mylist)
  "Procedure used by Balancer to obtain the initial list of problem-IDs in use for the duration of this session. This list needs to be refreshed when a different module or level is chosen.
GAP IN LOGIC.
problem-IDs are simply the index to the list of problems in the problems holder problems below."
  (create-list-ID-set (length mylist) 0 (list)))

(define (create-list-ID-set list-length counter problem-ID-set)
  (cond ((= counter list-length)
         problem-ID-set)
        ((create-list-ID-set list-length
                              (+ counter 1)
                              (append problem-ID-set (list counter))))))

(define (request-question problem-ID)
  "Procedure used by Generator to obtain the question to ask the player after selecting one.
List of suitable problem-IDs will have been provided to Generator by Balancer."
  (question (list-ref problems problem-ID)))

(define (request-solution problem-ID)
  "Procedure used by Evaluator to obtain the solution to the problem posed to the player after the player has attempted to answer thus.
problem-ID is provided by Generator to Evaluator upon request, after which Evaluator requests the solution from Library."
  (solution (list-ref problems problem-ID)))

(define (stream-element-selector target-element state stream) 
  "Pick an @var{target-element} that is a member of a @var{stream}.
Target element is essentially the index reference for the desired element of the stream."
  (if (= state target-element)
      (stream-car stream)
      (stream-element-selector target-element (+ state 1) (stream-cdr stream))))
