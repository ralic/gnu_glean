;;; guilecraft --- fast learning tool.         -*- coding: utf-8 -*-

;;;; Module Server

;; Copyright (C) 2008, 2010, 2012 Alex Sassmannshausen

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

;;; Commentary:
;;;
;;; The Module Server manages known guilecraft modules and
;;; module-hash-maps. It also provide challenge access and evaluation
;;; functionality.
;;;
;;; It uses the server communication framework defined in base-server,
;;; implements a module server specific dispatcher, and the logic for
;;; carrying out the functionality implied through the requests it
;;; receives.

;;;; Documentation:
;;; 
;;; The Module Server works as follows:
;;;
;;; Hashmaps Introduced:
;;; 
;;; The profile server does not know anything about modules: it
;;; retains an abstract idea the progress of a player by associating
;;; progress with a form of UUID. This UUID is known as a sethash. The
;;; profile server is capable of mapping a given sethash to a specific
;;; set. It is also capable of generating a sethash for any given
;;; set. 
;;; 
;;; Sethashes:
;;; 
;;; Sethashes need to be sufficiently long to avoid hash collisions
;;; between sets that may have the same id. This allows the profile
;;; server to store progress in sets in a flat list. There are 2
;;; special types of sethashes: roothashes (root-sethashes) and
;;; crownhashes (crown-sethashes). The former designate a sethash
;;; referring to a set at the bottom of a set-hierarchy (i.e. it's a
;;; set containing only problems rather than further sets). Roothashes
;;; will be converted in the profile server to root-blobhashes: a
;;; blobhash with no entries in its 'children' field (blobhashes
;;; contain a player's progress for a given set). Conversely, a
;;; crownhash will be converted to a crown-blobhash, a blobhash
;;; containing no entries in its 'parents' field. The module server
;;; has no concept of hashes as deep as a blobhash: sethashes are
;;; plain strings. As a result sethashes do not tell its user whether
;;; they are a roothash or crownhash.
;;;
;;; Hashpaths:
;;;
;;; It is necessary for the profile server to know whether a sethash,
;;; out of which it will construct a blobhash, is a roothash, a
;;; crownhash or an ordinary sethash. More than that, the profile
;;; server must know the position of a given sethash in a module's set
;;; hierarchy. Without this information it would be unable to properly
;;; populate the parents and children fields of the resulting
;;; blobhashes. Without the latter in turn it could not effectively
;;; treat a fundamentally hierarchical data set like guilecraft
;;; modules as a flat list. To this end the module servers provide the
;;; initial information about a given module's sethashes in the form
;;; of a hashpath.  A hashpath is a hierarchy of nested pairs, or a
;;; tree. The car of each hashpath is the sethash for a module's
;;; crownset. The cdr contains a list of its child nodes. Each child
;;; node in turn is a pair consisting of a (car) sethash and (cdr)
;;; list of child nodes.
;;; 
;;; Hashmaps Revisited:
;;;
;;; Finally, a hashmap is a list containing one or more hashpaths. It
;;; is generated by the module server in response to a hashmap
;;; request, which provides a list of module IDs. The module server
;;; converts these IDs into a hashmap, one hashpath per module ID.

;;; Code:

(define-module (guilecraft module-server)
  #:use-module (guilecraft base-server)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-26)
  #:use-module (guilecraft base32)
  #:use-module (guilecraft gmodule-manager)
  #:use-module (guilecraft problem-type-manager)
  #:use-module (guilecraft data-types base-requests)
  #:use-module (guilecraft data-types module-requests)
  #:use-module (guilecraft data-types profile-requests)
  #:use-module (guilecraft data-types gprofiles)
  #:use-module (guilecraft data-types sets)
  #:use-module (guilecraft data-types scorecards)
  #:use-module (guilecraft comtools)
  #:use-module (guilecraft gset-ops)
  #:use-module (guilecraft utils)
  #:use-module (guilecraft store)
  #:use-module (guilecraft gmodule-manager)
  #:use-module (rnrs)
  #:export (module-server))

;;;;; Module Server Dispatch Logic
;;;; Define the actual module server and the server-dispatcher used
;;;; by it.
(define (module-server module-socket-file)
  (store-modules)
  (the-server module-socket-file server-dispatcher))

(define (server-dispatcher request)
  "Interprets client requests, and passes additional information for
handling to request handler."

  (cond ((eof-object? request)
         #f)

        ((request? request)
         (let ((rq (rq-content request)))
           (guard (err ((or (eqv? err 'no-profile)
                            (eqv? err 'no-modules)
                            (eqv? err 'invalid-token)
                            (eqv? err 'invalid-auth-server)
                            (eqv? err 'invalid-set-ids)
                            (eqv? err 'invalid-answer)
                            (eqv? err 'invalid-counter)
                            (eqv? err 'invalid-blobhash))
                        (begin (clog err)
                               (negs rq err)))
                       ((equal? err '(exchange (server system-error)))
                        (begin (clog err)
                               (negs rq 'offline-auth-server)))
                       ((eqv? err 'false-result)
                        (begin (llog err)
                               (assertion-violation
                                'challenge-provider
                                "We were returned a false chall result!"
                                err))))

                  (cond ((aliveq? rq)
                         (acks rq))
                        ((challq? rq)
                         (challenge-provider rq))
                        ((evalq? rq)
                         (eval-provider rq))
                        ((known-modq? rq)
                         (known-mod-provider rq))
                        ((sethashesq? rq)
                         (sethashes-provider rq))
                        ((hashmapq? rq)
                         (hashmap-provider rq))
                        ((quitq? rq)
                         (acks rq))
                        (else (unks rq))))))

        (else (unks request))))
;;;;; Server Response Creation
;;;; Functions that provide request specific parsing and response
;;;; skeletons.
(define (challenge-provider rq)
  (define (new-challenge problem)
    "Return the challenge located in the set identified by BLOBHASH and
COUNTER, or raise 'invalid-set."
    (problem-q problem))

  (let ((bh (challq-hash rq))
        (c (challq-counter rq)))
    (cond ((not (blobhash? bh))
           (raise 'invalid-blobhash))
          ((not (number? c))
           (raise 'invalid-counter))
          (else (challs (new-challenge (fetch-problem bh c)))))))

(define (fetch-problem blobhash counter)
    (let* ((set (find-hash-set blobhash))
           (problems (set-contents set))
           (num-of-problems (length problems)))
      (list-ref problems (modulo counter num-of-problems))))

(define (eval-provider rq)
  (define (eval-answer problem answer)
    "Return the evaluation of ANSWER with respect to BLOBHASH and
COUNTER, or raise 'invalid-set."
    (evaluate problem answer))
  (define (evaluate problem answer)
    "Return the evaluation result of ANSWER with respect to PROBLEM."
    (equal? (s-text (problem-s problem)) answer))
  (define (fetch-solution problem)
    (problem-s problem))

  (let ((bh (evalq-hash rq))
        (c (evalq-counter rq))
        (answer (evalq-answer rq)))
    (cond ((not (blobhash? bh))
           (raise 'invalid-blobhash))
          ((not (number? c))
           (raise 'invalid-counter))
          ((not (string? answer))
           (raise 'invalid-answer))
          (else
           (let ((problem (fetch-problem bh c)))
             (evals (eval-answer problem answer)
                    (fetch-solution problem)))))))

(define (known-mod-provider rq)
  (let ((token (known-modq-token rq)))
    (known-mods token (list-known-modules))))

(define (hashmap-provider rq)
  (let ((set-ids (hashmapq-ids rq)))
    (if (not (list? set-ids))
        (raise 'invalid-set-ids)
        (hashmaps (generate-hashmap set-ids)))))

(define (sethashes-provider rq)
  (let ((set-ids (sethashesq-set-ids rq)))
    (if (not (list? set-ids))
        (raise 'invalid-set-ids)
        (sethashess (map (lambda (set-id)
                           (if (get-module set-id)
                               (cons set-id (make-set-hash set-id))
                               (cons set-id #f)))
                         set-ids)))))

;;;;; Module Management
;;;; Define the functions used to provide the functionality defined
;;;; above.

;;;; Operating on the Module Store
(define (get-module set-id)
  "Wrapper around module-manager's set-id->set: it tries returning the
module harder by triggering a reload of the modules if the module
identified by SET-ID cannot be found."
  (let ((module (set-id->set set-id)))
    (if module
        module
        (begin
          (store-modules)
          (set-id->set set-id)))))

(define (make-set-hash set-id)
  (string->symbol
   (bytevector->base32-string
    (string->utf8 (symbol->string set-id)))))

(define (hash set parent-ids)
  "Returns a blobhash. A blobhash is not just a hash of the set-id,
but a hash of the set-id appended by all parent-ids, to guarantee
uniqueness of the blobhash." 
  (make-set-hash
   (fold-left symbol-append (set-id set) parent-ids)))

;;;;; Hashmap generation
;;;; First retrieve a tree of each module identified by blobhashes,
;;;; then turn each id in the tree into a blobhash.
(define (generate-hashmap id-pairs)
  "Return a hashmap, built off of the list of ID-PAIRS. If it's
empty, raise a warning."
  (define (hashmap sets)
    (map (hashtraverser-maker '()) sets))

  (define (hashtraverser-maker parent-ids)
    "Return a hashraverser specific PARENT-IDs."
    (lambda (set)
      "Return a set-hashmap, a list containing lists of blobhashes for
each set and it's children that this hashtraverser is passed."
      (cond ((not set)
             '())
            ; If set contains further sets, recurse!
            ((set? (car (set-contents set)))
             (let ((h (hash set parent-ids)))
               (cons h
                     ;; Parent-ids contains parent-ids in reverse order!
                     (map (hashtraverser-maker (cons (set-id set)
                                                     parent-ids))
                          (set-contents set)))))
            ; If set does not contain further sets, then we're done.
            (else
             (let ((h (hash set parent-ids)))
               (cons h '()))))))

  (hashmap (map (lambda (id-pair) (get-module (car id-pair))) id-pairs)))

(define (find-hash-set blobhash)
  "Return the set identified by BLOBHASH, or raise an error."

  (define (find-set blobhash stored-modules)
    "Return set who's blobhash matches BLOBHASH, starting on the
assumption that the list of sets STORED-MODULES are crownsets."
    (fold-left (moduletraverser-maker '() blobhash) #f stored-modules))

  (define (moduletraverser-maker parent-ids target)
    "Return a moduletraverser made for descendants of PARENT-IDS,
searching for TARGET."
    (lambda (found? set)
      "Return SET if its blobhash (built with PARENT-IDS) matches
TARGET, found? if it is not #f (it is then assumed to be TARGET's
set), or else #f."
      (cond (found? found?) ; Return found? if not #f
            ((not set) #f) ; Return #f if set is #f
            ;; If set contains further sets, recurse: it can't
            ;; possibly be TARGET: that must be a rootset!
            ((set? (car (set-contents set)))
             ;; Due to cons below, PARENT-IDS contains parent-ids in
             ;; reverse order!
             (fold-left (moduletraverser-maker (cons (set-id set)
                                                     parent-ids)
                                               target)
                        found?
                        (set-contents set)))
            ;; If SET does not contain further sets, and it's blobhash
            ;; is equivalent to TARGET, then we've found TARGET!
            ((eqv? (hash set parent-ids) target) set)
            ;; Else we must continue looking.
            (else #f))))

  (find-set blobhash (stored-modules)))
