;; library-server.scm --- library-server unit tests    -*- coding: utf-8 -*-
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
;; Library-server unit tests.
;;
;;; Code:

(define-module (tests library-server)
  #:use-module (srfi srfi-64)      ; Provide test suite
  #:use-module (glean common base-requests)
  #:use-module (glean common library-requests)
  #:use-module (glean library library-store)
  #:use-module (glean library server))

(define (server-dispatcher rq)
  ((@@  (glean library server) server-dispatcher) rq))

(test-begin "library-server")

(test-assert "Known Crownsets"
             (and (knowns? (server-dispatcher (request (knownq))))))
(test-assert "Set Detail"
             ;; Should also test for rootset results.
             (let* ((hash (car (car (knowns-list
                                     (server-dispatcher
                                      (request (knownq)))))))
                    (rs   (server-dispatcher
                           (request (detailq hash)))))
               (and (details? rs)
                    (list?    (details-list rs)))))

(test-end "library-server")

;;; discipline ends here
