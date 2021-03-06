;; discipline.scm --- the meta discipline -*- coding: utf-8 -*-
;;
;; This file is part of Glean.
;;
;; Copyright (C) 2014 Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;;
;; Author: Alex Sassmannshausen <alex.sassmannshausen@gmail.com>
;; Created: 06 June 2014
;;
;; Glean is free software; you can redistribute it and/or modify it under the
;; terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 3 of the License, or (at your option) any later
;; version.
;;
;; Glean is distributed in the hope that it will be useful, but WITHOUT ANY
;; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License along
;; with glean; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 59 Temple Place - Suite 330        Fax:    +1-617-542-2652
;; Boston, MA  02111-1307,  USA       gnu@gnu.org

;;; Commentary:
;;
;; A discipline aiming to show inter-discipline dependence and linking.
;;
;;; Code:

(define-module
  (glean disciplines meta discipline)
  #:use-module
  (glean disciplines meta ancestry)
  #:use-module
  (glean library core-templates)
  #:export
  (meta))

(define meta
  (module
      'meta
      #:ancestry (ancestry-trees)
      #:name "Meta: Git and Test combined"
      #:version "0.1"
      #:keywords '("test" "recursion")
      #:synopsis "Learn to use meta"
      #:description "Long Description: background on git, introductory text"
      #:creator "Alex Sassmannshausen"
      #:attribution (list (media #:text "Git man pages & website"))
      #:contents `(,git-module ,test-module)
      #:resources (list (media #:urls '("http://www.git-scm.com")))))

;;; discipline.scm ends here
