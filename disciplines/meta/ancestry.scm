;; ancestry.scm --- the meta ancestry file -*- coding: utf-8 -*-
;;
;; This file is part of Glean.
;;
;; Copyright (C) YEAR AUTHOR <EMAIL>
;; Created: DAY MONTH YEAR
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
;; This module defines meta 's ancestry file.
;;
;; This file is auto-generated by Glean maker.  It defines data structures
;; used by the module management processes.
;;
;; ancestry-trees: defines the relationship between the discipline as defined
;; in the library at the time that this discipline was created.  If this is a
;; new discipline, then the tree will not refer to a previous discipline: it
;; will simply by #f.
;;
;;; Code:

(define-module
  (glean disciplines meta ancestry)
  #:export
  (ancestry-trees))

(define ancestry-trees (const #f))

;;; ancestry.scm ends here
