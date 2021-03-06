(uiop:define-package :ga/ga-impl
    (:use :cl
          :ga/converter
          :ga/utils)
  (:nicknames :ga)
  (:export #:search-extremum-of-function))

(in-package :ga/ga-impl)

(declaim (optimize (safety 3)))

;; dynamic vars
(defvar *count-of-genes*)
(defvar *fn*)
(defvar *count-of-elits*)
(defvar *count-of-tournament-chs*)

;; CLOS: class of chromosome
(defclass chromosome ()
  ((genes
    :initarg :genes
    :type list
    :reader get-genes)
   (phenotype
    :initarg :phenotype
    :initform nil
    :type (or null number)
    :writer set-phenotype
    :reader get-phenotype)))

;; object printer
(defmethod print-object ((obj chromosome) stream)
  (print-unreadable-object
      (obj stream)
    (format stream "chromosome: phenotype - ~a, genes - ~{~a~^ ~}"
            (get-phenotype obj)
            (get-genes obj))))

;; generator
(defun generate-chromosome ()
  (make-instance 'chromosome
                 :genes (generate-genes)))

(defun generate-genes ()
  (loop :repeat *count-of-genes*
     :collect (float-number->bit-vector
               (random-from-range *x-min* *x-max*))))

(defun generate-population (count-of-pupulation)
  (loop :repeat count-of-pupulation
     :collect (generate-chromosome)))

;; ga process (search extremum of function)
(defun search-extremum-of-function (fn &key
                                         (count-of-elits 5)
                                         (size-of-population 500)
                                         x-min
                                         x-max
                                         (digit-capacity 16)
                                         (count-of-genes 10)
                                         (count-of-iterations 5000))
  (let* ((*count-of-elits* count-of-elits)
         (*count-of-tournament-chs* (- size-of-population
                                       *count-of-elits*))
         (*count-of-genes* count-of-genes)
         (*fn* fn)
         (*x-min* x-min)
         (*x-max* x-max)
         (*digit-capacity* digit-capacity)
         (init-population (generate-population size-of-population)))
    (loop :repeat count-of-iterations
       :for new-population = (calculate-phenotypes init-population)
       :then (progn
               (calculate-phenotypes new-population)
               (sort-population new-population))
       :do (setf new-population (selection-and-mutation new-population))
       :finally (return
                  (progn
                    (calculate-phenotypes new-population)
                    (car (sort-population new-population)))))))


;; population utils
(defun calculate-phenotypes (population)
  (mapc
   (lambda (ch)
     (set-phenotype
      (funcall *fn*
               (mapcar #'bit-vector->float-number
                       (get-genes ch)))
      ch))
   population)
  population)

(defun sort-population (population)
  (sort population #'< :key #'get-phenotype))

(defun init-population (n)
  (loop :repeat n :collect (generate-chromosome)))

;; crosovver operation
(defun two-point-crossover (population)
  (loop :repeat *count-of-tournament-chs*
     :do (let* ((i1 (random *count-of-tournament-chs*))
                (i2 (random *count-of-tournament-chs*))
                (res (crossover-sawp
                      (get-genes
                       (nth i1 population))
                      (get-genes
                       (nth i2 population)))))
           (setf (nth i1 population) (car res))
           (setf (nth i2 population) (cdr res))))
  population)

(defun crossover-sawp (genes-of-ch1 genes-of-ch2)
  (let* ((single-gen-1
          (concatenate-bit-vector-list genes-of-ch1))
         (single-gen-2
          (concatenate-bit-vector-list genes-of-ch2))
         (p1 (random (length single-gen-1)))
         (p2 (random-from-range (1+ p1) (length single-gen-1)))
         (new-single-gen-1 (concatenate-bit-vector-list
                            `(,(subseq single-gen-1 0 p1)
                               ,(subseq single-gen-2 p1 p2)
                               ,(subseq single-gen-1 p2))))
         (new-single-gen-2 (concatenate-bit-vector-list
                            `(,(subseq single-gen-2 0 p1)
                               ,(subseq single-gen-1 p1 p2)
                               ,(subseq single-gen-2 p2))))
         (new-genes-of-ch1 (split-bit-vector new-single-gen-1))
         (new-genes-of-ch2 (split-bit-vector new-single-gen-2)))
    (cons
     (make-instance
      'chromosome
      :genes new-genes-of-ch1)
     (make-instance
      'chromosome
      :genes new-genes-of-ch2))))

(defun concatenate-bit-vector-list (bit-vector-lst)
  (reduce
   (lambda (acc val)
     (concatenate 'bit-vector acc val))
   bit-vector-lst))

(defun split-bit-vector (bit-vector)
  (loop :for i :from *digit-capacity* :to (length bit-vector) :by *digit-capacity*
     :with j = 0
     :collect (prog1
                  (subseq bit-vector j i)
                (setf j i))))

;; selections and mutations
(defun selection-and-mutation (population)
  (append
   (elitism-selection population)
   (mutation
    (two-point-crossover
     (tournament-selection population)))))

;; selections
(defun elitism-selection (population)
  (subseq population 0 *count-of-elits*))

(defun tournament-selection (population)
  (let ((population (subseq population *count-of-elits*)))
    (loop :repeat *count-of-tournament-chs*
       :collect (let ((ch1 (nth (random (length population))
                                population))
                      (ch2 (nth (random (length population))
                                population)))
                  (if (<= (get-phenotype ch1)
                         (get-phenotype ch2))
                      ch1
                      ch2)))))

;; mutation
(defun mutation (population)
  (loop :for i :from 0 :to (1- (length population))
     :collect (make-instance
               'chromosome
               :genes (bits-mutation
                       (get-genes
                        (nth i population))))))

(defun calculate-mutation-probability ()
  (*
   (+ 10
      (/ 1
         *digit-capacity*))
   100))

(defun bits-mutation (bit-vector-list)
  (let ((mutation-prob (calculate-mutation-probability)))
    (mapcar
     (lambda (bit-vector)
       (coerce
        (loop :for bit :across bit-vector
           :collect (if (> mutation-prob (random 100))
                        (case bit
                          (1 0)
                          (0 1)
                          (t (error "unknown number: ~a" bit)))
                        bit))
        'bit-vector))
     bit-vector-list)))
