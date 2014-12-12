;; discipline.scm --- a test discipline    -*- coding: utf-8 -*-
;;
;; Copyright (C) 2014 Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;;
;; Author: Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;; Created: 06 June 2014
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
;; A discipline to help me test various aspects of discipline definition and
;; interaction.
;;
;;; Code:

(define-module (glean disciplines test discipline)
  #:use-module (glean library core-templates)
  #:export (test-module))

(define test-module
  (module
    'test
    #:name "A Test Module"
    #:version "0.1"
    #:keywords '("test" "simple" "open" "multiple-choice")
    #:synopsis "This is a bare skeleton of a module."
    #:description "The aim is to have a module that:
a) illustrates fields and their acceptable values;
b) provides a module with fields to be used by the unit tests."
    #:creator "Alex Sassmannshausen"
    #:attribution
    (list
     (media #:text "We did not need inspiration for this one"))
    #:resources
    (list
     (media #:text "But if you want to find out more, try:"
            #:books (list "The Glean Manual")))
    #:contents
    (list (set 'intro
               #:contents
               (list
                (problem (q "What is a good question?")
                         (s "This is not")
                         (o "This is not")
                         (o "This is")
                         (o "What is your favourite colour")
                         (p equal?))
                (problem (q "An open question should…")
                         (s "…have a single obvious solution")
                         ;; (s "…be written with clarity in mind")
                         (o "…have a single obvious solution")
                         (o "…be written with clarity in mind")
                         (o "…have multiple interprations")
                         (o "…use mystifying language")))))))

;;; discipline ends here
