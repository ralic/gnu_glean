;; config-utils.scm --- configuration file management -*- coding: utf-8 -*-
;;
;; Copyright (C) 2014 Alex Sassmannshausen  <alex.sassmannshausen@gmail.com>
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
;; A module providing component configuration and extensibility features.
;;
;; Primary uses are:
;; - when writing extensions, make-config, make-component, make-setting.
;; - when embedding components in a glean server, use component-node
;;
;;; Code:

(define-module (glean common config-utils)
  #:use-module (glean common utils)
  #:use-module (srfi srfi-9)
  #:export (
            ;; Config template manipulation
            make-config
            configuration?
            make-component
            make-setting
            config-target
            config-name
            config-contents
            config-write
            ensure-user-dirs
            ensure-config
            load-config
            ))

;;;;; Configuration File Management
;;;; <configuration>
;;; Configuration Records specify a component's configuration file.
;;; - NAME is its human-readible identifier.
;;; - TARGET is its location
;;; - CONTENTS are one or more <setting-elements>

(define-record-type <configuration>
  (make-config name target contents)
  configuration?
  (name     config-name     set-config-name)
  (target   config-target   set-config-target)
  (contents config-contents set-config-contents))

;;;; <setting-element>
;;; Setting-element Records identify individual settings within a
;;; <configuration>.
;;; - NAME: the setting's name. This should be a valid Guile variable name.
;;; - DEFAULT: the setting's value when the configuration file is created.
;;; - DOCSTRING: documentation (comments) for the setting.

(define-record-type <setting-element>
  (make-setting name default docstring)
  setting?
  (name      setting-name      set-setting-name)
  (default   setting-default   set-setting-default)
  (docstring setting-docstring set-setting-docstring))

(define* (config-write config)
  "Write CONFIG to disk, at CONFIG's target."
  (define (prep-setting value)
    (cond ((string? value)
           (string-append "\"" value "\""))
          ((symbol? value)
           (string-append "'" (symbol->string value)))
          ((list? value)
           (string-append "'" (object->string value)))
          (else value)))
  (define (setting-write setting)
    (let ((docstring (setting-docstring setting)))
      (if docstring
          (format #t ";; ~a\n(define ~a ~a)\n"
                  docstring
                  (setting-name setting)
                  (prep-setting (setting-default setting)))
          (format #t "(define ~a ~a)\n"
                  (setting-name setting)
                  (prep-setting (setting-default setting))))))

  (if (string? (config-target config))
      (with-output-to-file (config-target config)
        (lambda ()
          (if (config-name config)
              (format #t ";; ~a Configuration File\n\n"
                      (config-name config))
              (format #t "/* Custom code for the web client */"))
          (for-each setting-write (config-contents config))))
      (begin
        (format #t ";; ~a Configuration File\n\n"
                (config-name config))
        (for-each setting-write (config-contents config)))))

(define (ensure-user-dirs . dirs)
  "Recursively create every dir named in DIRS."
  (for-each mkdir-p dirs))

(define (ensure-config config)
  "Check CONFIG exists, creating it if it does not. Currently always returns
#t."
  (if (access? (config-target config) R_OK)
      (inform "The ~a configuration exists. [ok]~%" (config-name config))
      (begin
        (inform "~a configuration is being created... "
                (config-name config))
        (config-write config)
        (inform "[done]~%"))))

(define* (load-config config #:optional (mod-name '(glean config)))
  "Load CONFIG, an absolute path to a scheme file, in the context of the
'(glean config) module."
  ;; Parse optional root config-file
  (let ((config-module (resolve-module mod-name)))
    (save-module-excursion
     (lambda ()
       (set-current-module config-module)
       (inform "Loading ~s... " config)
       (primitive-load config)
       (inform "[done]~%")))))

;;; config-utils.scm ends here
