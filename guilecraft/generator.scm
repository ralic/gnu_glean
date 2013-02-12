#! /usr/bin/guile -s

coding:utf-8
!#
;;; Commentary:

;;; Generator picks lowest ranking (weighting supplied by 
;;; balancer) question from available problem IDs 
;;; (supplied by library), or picks random if multiple 
;;; lowest ranks. Returns question & meta info to UI.
;;; Stores Problem-ID for query by Evaluator.

;;; Code:

(define-module (guilecraft generator)
    #:export (compile-question)         ; by Controller
    #:use-module (guilecraft balancer)  ; for request-tags
    #:use-module (guilecraft library)   ; for request-question
)

(define (compile-question)
    "Procedure which algorithmically returns one question.

No input is necessary for this activity."
    (request-question              ;from Library
     (select-tag                        ;from Here
      (request-tags)			;from Balancer
      )))


(define (select-tag tag-list)
  "Select exactly one tag from a list of tags.
  
  Input is normally a list of tags retrieved from the Balancer. Returns a single symbol that is a tag, normally used to activate a stream in the Library."
    (car tag-list))
