#! /usr/bin/guile -s

coding:utf-8
!#

(define-module (guilecraft file-server)
  #:export (get-from-file-server)
  #:use-module (sxml ssax))

(define (get-from-file-server what . who)
  "Exported function returning the contents of an xml guilecraft config file in sxml.

Requires a recognised target to fetch, as symbol from a list, and, depending on the target, a further argument that specifies the sub-location to fetch.

get-from-file-server returns the data requested or 'fail"
  (cond ((not (eqv? '() who))
         (resolve-path what who))
        ((symbol? what)
         (resolve-path what))
        (else (get-data what))))

(define (get-data uri)
  "requires uri to Guilecraft XML file, returns a list with the elements of that file."
  (xml->sxml (open-input-file uri)))

(define (put-on-file-server data what . who)
  "put-on-file-server stores DATA as WHAT on the filesystem. WHAT and WHO are used to determine the path of the xml file in which the data is to be stored.

Put-on-file-server is called for its side-effect. It returns 'success or 'fail.")

(define (resolve-path what . who)
"Generates the appropriate URI for get-data to import the file's XML as SXML.
"
  (cond ((eqv? what 'user-serv)
         "users/user-serv.xml")
        ((eqv? what 'statistics)
         "statistics/statistics.xml")
        ((not (eqv? '() who))
         (cond ((eqv? what 'module)
                (string-append "modules/" (symbol->string (car who)) "/module.xml"))
               ((eqv? what 'user-profile)
                (string-append "modules/" (symbol->string (car who)) "/user.xml"))
               (else 'who-but-not-what)))
        (else 'not-a-recognised-symbol)))