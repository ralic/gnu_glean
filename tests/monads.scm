;; monads.scm --- tests for monads    -*- coding: utf-8 -*-
;;
;; Copyright (C) 2014 Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;;
;; Author: Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;; Created: 15 November 2014
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
;; Unit tests for monads.
;;
;; Source-file: glean/common/monads.scm
;;
;;; Code:

(define-module (tests monads)
  #:use-module (glean common monads)
  #:use-module (glean common utils)
  #:use-module (srfi srfi-64)
  )


;;;; Tests

(test-begin "monads")
;;; Test whether `mlogger' indeed switches on and off, depending on `logger',
;;; and whether `mlogger' handles bogus messages.
(parameterize ((logger (const #t)))
  (test-assert "mlogger-on"
    ((mlogger symbol? (const #t)) 'message 'log-level)))
(parameterize ((logger (const #f)))
  (test-assert "mlogger-off"
    (not ((mlogger boolean? (const #t)) 'message 'log-level))))
(test-end)

;;; monads ends here
