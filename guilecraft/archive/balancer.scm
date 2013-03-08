#! /usr/bin/guile -s

coding:utf-8
!#
  
;;; Commentary:
  
;;; Balancer provides the cache of eligible problem IDs
;;; to Generator. Generator then makes the final
;;; selection.
;;; Balancer maintains a rank for each possible question
;;; which provides the ground for selection: the lower the
;;; score, the more likely the question is picked.
;;; The rank is revised after every player attempt at solving
;;; the problem.
;;; When no ranking exists Balancer obtains the initial set
;;; of problem IDs from Library and assigns them a base rank.
    
;;; Code:

(define-module (guilecraft balancer)
  #:export (request-tags                ; used by Generator
            ranking-put)                ; used by Controller
  #:use-module (guilecraft controller)  ; for request-current-module
                                        ; No longer to be used: module name now passed as input to generator
  #:use-module (guilecraft file-server) ; for restore-balancer-data
                                        ; Not implemented yet
  #:use-module (guilecraft library))    ; for librarian 'provide-tags access

(define (request-tags module-list)
    "Initiate the rank table if necessary and call lowest-ranking-from-table to obtain a list of lowest ranking problems.
Request-tags needs a list of the modules currently played, and returns a list of the tags from those modules that score the lowest rank."
    (let ((local-list '()))
      (cond ((or (not (eq? local-list module-list))
                (eq? rank-table '()))
	     (begin
	       (populate-rank-table (librarian 'provide-tags module-list))
	       (lowest-ranking-from-table rank-table 0 5 (list))))
	    (else 
	     (lowest-ranking-from-table rank-table 0 5 (list))))))

(define (populate-rank-table tag-set)
  "Procedure which initially populates the rank-table. It is pure side-effect, and could be called by a hook.
  
  populate-rank-table requires the set of problem-IDs which it will populate the table with, as well as a default rank to assign them with.
  
  Improvements:
  - must be capable of restoring ranking across sessions -> data persistence
  - currently state-ful solution: either call it through a hook or implement a functional solution."
  (for-each (lambda (tag)      ; tag-set is split into its atoms: tags
              (set! rank-table
                    (acons tag 
                           100 
                           rank-table)))
            tag-set))

(define (lowest-ranking-from-table 
         rank-table          ; The state-based rank-table
         tag-reference       ; The reference of tag currently examined
         lowest-rank         ; The lowest rank so far
         lowest-ranking-tag-set) ; The tags with the lowest rank so far
  "Simple procedure to retrieve the question-IDs with the lowest rank from rank-table.
  
  Improvements:
  - Implement a way to keep track of the current lowest rank: eliminates the need for searching the entire table recursively — instead we simply search it for any problem-IDs matching the lowest score. We could then substitute the complicated cond below for a simple map lowest-ranking? rank-table."
  (if (= (length rank-table)
         tag-reference)
      lowest-ranking-tag-set
      (cond ((= (cdr (list-ref 
                      rank-table
                      tag-reference)) 
                lowest-rank)
             (lowest-ranking-from-table rank-table 
                                        (+ tag-reference 1)
                                        lowest-rank
                                        (append lowest-ranking-tag-set (list (car (list-ref rank-table tag-reference))))))
            ((< (cdr (list-ref 
                      rank-table 
                      tag-reference))
                lowest-rank)
             (lowest-ranking-from-table rank-table
                                        (+ tag-reference 1)
                                        (cdr (list-ref rank-table tag-reference))
                                        (list (car (list-ref rank-table tag-reference)))))
            (else (lowest-ranking-from-table rank-table
                                             (+ tag-reference 1)
                                             lowest-rank
                                             lowest-ranking-tag-set)))))

(define (ranking-put tag evaluation)
  "Procedure to update the current ranking of a given problem-ID on the basis of the evaluation of the player's answer to the challenge.
  
  ranking-put requires the problem-ID that it will update and the result of the evaluation, with which it modifies the rank. It returns evaluation, as this function serves purely for its side-effect.
  
  Improvements:
  - call ranking-put via a hook if I decide to use the state based approach: this would tidy the code.
  - do away with ranking-put after devising a functional solution to problem-ID ranking."
  (begin
    (assq-set! rank-table 
               tag 
               (calculate-new-rank (assq-ref rank-table tag)  ; assq-ref returns the value of tag
                                   evaluation))
    evaluation))

(define (calculate-new-rank rank-table-value evaluation)
  "The actual algorithm used to obtain a new rank.
  
  calculate-new-rank requires a the key of a value in the rank-table and the result of the evaluation of the player's answer, and returns the new ranking for that key in the rank-table."
  (cond (evaluation (+ rank-table-value 1))
        (else (- rank-table-value 1))))

(define rank-table (list))