;;; glean --- fast learning tool.         -*- coding: utf-8 -*-

;;;; Profile Server

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
;;; The Profile Server manages authentication, user profiles (both
;;; in-game and profile persistence) and user scorecards.
;;;
;;; It uses the server communication framework defined in base-server,
;;; implements a profile server specific dispatcher, and the logic for
;;; carrying out the functionality implied through the requests it
;;; receives.

;;;; Documentation:
;;; FIXME: Write documentation

;;; Code:

(define-module (glean profile-server)
  #:use-module (glean base-server)
  #:use-module (glean comtools)
  #:use-module (glean config)
  #:use-module (glean data-types base-requests)
  #:use-module (glean data-types profile-requests)
  #:use-module (glean data-types gprofiles)
  #:use-module (glean data-types scorecards)
  #:use-module (glean lounge-store)
  #:use-module (glean monads)
  #:use-module (glean utils)
  #:use-module (ice-9 rdelim)
  #:use-module (rnrs exceptions)
  #:use-module (srfi srfi-26)
  #:export (profile-server))

;;;;; Profile Server Dispatch Logic
;;;; Define the actual profile server and the server-dispatcher used
;;;; by it.
(define (profile-server profile-socket-file)
  "Launch a profile-server."
  (the-server profile-socket-file server-dispatcher))

(define (server-dispatcher request)
  "Interprets client requests, and passes additional information for
handling to request handler."

  (cond ((eof-object? request)
         #f)
        ((request? request)
         (let* ((rq (rq-content request))
                (re (guard (err
                            (err
                             (begin
                               (clog err)
                               (format #t
                                       "Error in dispatcher: ~a.\n"
                                       err)
                               (negs rq err))))
                           (cond ((aliveq?  rq) (acks rq))
                                 ((quitq?   rq) (acks rq))
                                 ((echoq?   rq)
                                  (process-echoq rq))
                                 ((chauthq? rq)
                                  (process-chauthq rq))
                                 ((evauthq? rq)
                                  (process-evauthq rq))
                                 ((authq?   rq)
                                  (process-authq rq))
                                 ((viewq?   rq)
                                  (process-viewq rq))
                                 ((set!q?   rq)
                                  (process-set!q rq))
                                 ((regq?    rq)
                                  (process-regq rq))
                                 ((delq?    rq)
                                  (process-delq rq))
                                 (else (unks rq))))))
           (if (nothing? re)
               (negs rq (nothing-id re))
               re)))
        (else (unks request))))

;;;;; Server Response Creation
;;;; Functions that provide request specific parsing and response
;;;; skeletons.
(define (process-echoq rq)
  "Return an echos, containing a new token, the profile's profile
server, module server and the message contained in RQ."
  (let ((token (echoq-token rq)))
    (cond ((not (token? token))
           (raise '(process-echoq invalid-token)))
          (else
           ((mlet* lounge-monad
                   ((new-token  (authenticate token))
                    (lng        (fetch-lounge))
                    (profile -> (profile-from-token new-token lng)))
                   (echos new-token
                          (profile-prof-server profile)
                          (profile-mod-server profile)
                          (echoq-message rq))) %lounge-dir%)))))

(define (process-authq rq)
  (let ((name   (authq-name     rq))
        (passwd (authq-password rq)))
    (cond ((not (string? name))
           (raise '(process-authq invalid-username)))
          ((not (string? passwd))
           (raise '(process-authq invalid-password)))
          (else
           ((mlet* lounge-monad
                   ((new-tk     (login (profile-hash name passwd)))
                    (lng        (fetch-lounge))
                    (profile -> (profile-from-token new-tk lng)))
                   (auths new-tk
                          (profile-prof-server profile)
                          (profile-mod-server profile)))
            %lounge-dir%)))))

(define (process-chauthq rq)
  "Return a chauths, containing a new token and the next hash/counter
pair. Return a set!s informing that scorecard and active-modules are
out of sync if they are."
  (let ((token (chauthq-token rq)))
    (cond ((not (token? token))
           (raise '(process-chauthq invalid-token)))
          (else
           ((mlet* lounge-monad
                   ((new-tk            (authenticate token))
                    (lng               (fetch-lounge))
                    (hash/counter-pair (scorecard-next new-tk lng)))
                   (cond ((pair? hash/counter-pair)
                          (chauths new-tk (car hash/counter-pair)
                                   (cdr hash/counter-pair)))
                         ((not hash/counter-pair)
                          (set!s new-tk 'active-modules '()))
                         (else
                          (set!s new-tk 'scorecard
                                 hash/counter-pair))))
            %lounge-dir%)))))

(define (process-evauthq rq)
  (let ((token (evauthq-token rq))
        (result (evauthq-result rq)))
    (cond ((not (token? token))
           (raise '(process-avauthq invalid-token)))
          ((not (boolean? result))
           (raise '(process-evauthq invalid-result)))
          (else
           ((mlet*
             lounge-monad
             ((new-tk     (authenticate token))
              (lng        (fetch-lounge))
              (diff       (scorecard-diff new-tk result lng))
              (profile (update-lounge diff %lounge-persist%)))
             (auths new-tk
                    (profile-prof-server profile)
                    (profile-mod-server  profile))) %lounge-dir%)))))

(define (process-regq rq)
  "Return a regq, containing a new token, the profile's profile
server, module server, a nothing value, or raise an error."
  (let ((name    (regq-name        rq))
        (passwd  (regq-password    rq))
        (lounge  (regq-prof-server rq))
        (library (regq-mod-server  rq)))
    (cond ((not (string? name))
           (raise '(process-regq invalid-username)))
          ((not (string? passwd))
           (raise '(process-regq invalid-passwd)))
          ((not (string? lounge))
           (raise '(process-regq invalid-mod-server)))
          ((not (string? library))
           (raise '(process-regq invalid-prof-server)))
          (else
           ((mlet* lounge-monad
                   ((lng       (fetch-lounge))
                    (diff      (register-profile name passwd
                                                 lounge library lng))
                    (ignore    (update-lounge diff %lounge-persist%))
                    (new-token (login (profile-hash name passwd))))
                   (auths new-token lounge library)) %lounge-dir%)))))

(define (process-viewq rq)
  "Return a views, a lounge response containing a new token, and the
profile details of the profile identified by the token contained in RQ
if RQ parses correctly. Otherwise raise a an error."
  (let ((token (viewq-token rq)))
    (if (token? token)
        ((mlet* lounge-monad
                ((new-tk  (authenticate token))
                 (lng     (fetch-lounge))
                 (details (view-profile new-tk lng)))
                (views new-tk details)) %lounge-dir%)
        (raise '(process-viewq invalid-token)))))

(define (process-set!q rq)
  (let ((token (set!q-token rq))
        (field (set!q-field rq))
        (value (set!q-value rq)))
    (cond ((not (symbol? field))
           (raise '(process-set!q invalid-field)))
          ((not (token? token))
           (raise '(process-set!q invalid-token)))
          ;; Validate value:
          ((and (eqv? field 'mod-server) ; mod-server
                (not (string? value)))
           (raise '(process-set!q invalid-mod-server)))
          ((and (eqv? field 'prof-server) ; prof-server
                (not (string? value)))
           (raise '(process-set!q invalid-prof-server)))
          ((and (eqv? field 'name)      ; name
                (or (not (pair? value))
                    (not (string? (car value)))
                    (not (string? (cdr value)))))
           (raise '(process-set!q invalid-name-password)))
          ((and (eqv? field 'password)
                (not (string? value)))
           (raise '(process-set!q invalid-password)))
          ;; Validate value: new hashmap->scorecard.
          ;; FIXME: needs to be more rigorous
          ((and (eqv? field 'scorecard) ; scorecard
                (not (list? value)))
           (raise '(process-set!q invalid-hashmap)))
          ;; Validate value: new active-modules.
          ((and (eqv? field 'active-modules) ; active-modules
                (not (list? value))
                (if (eqv? (car value) 'negate)
                    (not (parse-active-modules (cdr value)))
                    (not (parse-active-modules value))))
           (raise '(process-set!q invalid-active-modules)))
          (else
           ((mlet* lounge-monad
                   ((tmp-tk  (authenticate token))
                    (lng     (fetch-lounge))
                    (diff    (modify-profile tmp-tk field value lng))
                    (profile (update-lounge diff %lounge-persist%))
                    (sc-diff -> (missing-blobs profile))
                    (ignore2 (purge-profile tmp-tk))
                    (new-tk  (login (cadr diff))))
                   (if (null? sc-diff)
                       (auths new-tk
                              (profile-prof-server profile)
                              (profile-mod-server  profile))
                       (set!s new-tk 'scorecard sc-diff)))
            %lounge-dir%)))))

(define (process-delq rq)
  (let ((tk (delq-token rq)))
    (if (token? (delq-token rq))
        ((mlet* lounge-monad
                ((new-tk  (authenticate tk))
                 (lng     (fetch-lounge))
                 (diff    (delete-profile new-tk lng))
                 (ignore  (update-lounge diff %lounge-persist%))
                 (ignore2 (purge-profile tk)))
                (acks rq)) %lounge-dir%)
        (raise '(process-delq invalid-token)))))