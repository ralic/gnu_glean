;;; guilecraft --- Fast learning tool.         -*- coding: utf-8 -*-

;;;; Sets

;;; copyright etc. & license.

;;; Sets are recursive records used to group problems and other sets
;;; together for use in Guilecraft.
;;;
;;; Sets are a means of grouping problems together under a
;;; tag. Guilecraft uses the tag to measure progress against a
;;; discipline, and will select a "random" question from the
;;; algorithmically determined highest priority set.
;;;
;;; Alternatively, sets can contain other sets — a way to group sets
;;; of problems in meta-groups: modules if you will.

;;;; Documentation
;;;
;;; (SET id
;;;      [information]
;;;      [problem …]
;;;      [set …]) -> set-type
;;; (SET? <object>) -> boolean
;;; (SET-ID <set>) -> set-id
;;; (SET-INFO <set>) -> set-information
;;; (SET-)

;;;;; Set Operations

;;;;; Primitive Operations

;;;;; Module Definition
(define-module (guilecraft data-types gsets)
;;  #:use-module (srfi srfi-9)
  #:use-module (rnrs records syntactic)
  #:export (
	    set
	    set?
	    set-id
	    set-contents
	    set-info
	    set-name
	    set-version
	    set-synopsis
	    set-description
	    set-creator
	    set-attribution
	    set-resources

	    problem
	    problem?
	    problem-q
	    problem-s
	    problem-o
	    problem-p

	    q
	    q?
	    q-text
	    q-media

	    s
	    s?
	    s-text
	    s-media

	    o
	    o?
	    o-text
	    o-media

	    media
	    media?
	    media-urls
	    media-books
	    media-images
	    media-videos
	    media-audio
	    ))

;;;;; Set Structure

(define-record-type (gset set set?)
  (fields id contents info)
  (protocol
   (lambda (new)
     (lambda* (id #:key (contents #f) (name #f) (version #f)
		  (synopsis #f) (description #f) (creator #f)
		  (attribution #f) (resources #f))

	      (new id 
		   (if (list? contents) contents (list contents))
		   name
		   version
		   synopsis
		   description
		   creator
		   (if (list? attribution)
		       attribution
		       (list attribution))
		   (if (list? resources)
		       resources
		       (list resources)))))))

(define-record-type (problm problem problem?)
  (fields q s o p)
  (protocol
   (lambda (new)
     (lambda* (#:key (q #f) (s #f) (o #f) (p 'equal?))
	      (new q s o p)))))

(define-record-type (question q q?)
  (fields text media)
  (protocol
   (lambda (new)
     (lambda* (text #:key (media #f))
	      (new text media)))))

(define-record-type (question s s?)
  (fields text media)
  (protocol
   (lambda (new)
     (lambda* (text #:key (media #f))
	      (new text media)))))

(define-record-type (question o o?)
  (fields text media)
  (protocol
   (lambda (new)
     (lambda* (text #:key (media #f))
	      (new text media)))))

(define-record-type (medium media media?)
  (fields urls books images videos audio)
  (protocol
   (lambda (new)
     (lambda* (#:key (urls #f) (books #f) (images #f) (videos #f)
		     (audio #f))
	      (new urls books images videos audio)))))
