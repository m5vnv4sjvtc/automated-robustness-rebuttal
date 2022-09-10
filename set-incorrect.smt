(declare-sort E)
(declare-datatypes () ((I (in1) (in2) (in3))))
(declare-sort V)
(declare-sort S)

(declare-datatypes () ((EventType (R) (W) (U) (F))))
(declare-datatypes () ((EventLabel (Rlx) (Rel) (Acq) (AcqRel))))
(declare-datatypes () ((MethodType (Add)(Mem))))
(declare-datatypes () ((FieldType (Default)(Val)(Next))))
(declare-datatypes () ((StmtType (E1t) (E2t) (E3t) (E4t) (D1t) (D2t) (D3t) (Bot))))

(declare-fun newloc (I) V)
(declare-fun etype (E) EventType)
(declare-fun elabel (E) EventLabel)
(declare-fun stype (E) StmtType)
(declare-fun loc (E) V)
(declare-fun field (E) FieldType)
(declare-fun rval (E) V)
(declare-fun wval (E) V)
(declare-fun mo (E E) Bool)
(declare-fun soE (E E) Bool)
(declare-fun hb (E E) Bool)
(declare-fun sw (E E) Bool)
(declare-fun fr (E E) Bool)
(declare-fun hbSC (E E) Bool)
(declare-fun rf (E E) Bool)

(declare-fun soI (I I) Bool)
(declare-fun sess (I) S)
(declare-fun argval (I) V)
(declare-fun retval (I) V)
(declare-fun itype (I) MethodType)

(declare-fun D1e (I) E)
(declare-fun D2e (I) E)
(declare-fun D3e (I) E)

(declare-fun E1e (I) E)
(declare-fun E2e (I) E)
(declare-fun E3e (I) E)
(declare-fun E4e (I) E)

(declare-fun valevent (I) E)

(define-fun isM ((e E) ) Bool
(or (= (etype e) W) (= (etype e) U))
)
(define-fun isR ((e E)) Bool
(or (= (etype e) U)(= (etype e) R))
)
(define-fun isBot ((e E)) Bool
(= (stype e) Bot)
  )
(define-fun sameloc ((e1 E) (e2 E)) Bool
(and (= (field e1) (field e2)) (= (loc e1) (loc e2)))
)
(define-fun sameses ((i1 I) (i2 I)) Bool
(= (sess i1) (sess i2))
)
(define-fun isAcq ((e E)) Bool
(or (= (elabel e) Acq)(= (elabel e) AcqRel))
)
(define-fun isRel ((e E)) Bool
(or (= (elabel e) Rel)(= (elabel e) AcqRel))
)

(declare-fun initval (V FieldType) V)
(declare-fun rfinit (E) Bool)

;Locations
(declare-const top V)

;Values
(declare-const zero V)
(declare-const EMPTY V)
(declare-const NULL V)

; If a read event reads a non-initial value, then there must a write event which writes that value.
(assert (forall ((e1 E) (e2 E)) (=>  (rf e1 e2) (and  (not (= (stype e1) Bot))(not (isBot e2)) (= (wval e1) (rval e2)) (sameloc e1 e2) (isM e1) (isR e2) ) )) )
(assert (forall ((e1 E) (e2 E)) (=> (rf e1 e2) (not (soE e2 e1))) ))
(assert (forall ((e1 E)) (exists ((e2 E)) (=> (and (isR e1) (= (stype e1) D2t) (not (isBot e1)) (not (= (rval e1) (initval (loc e1) (field e1))))) (and (isM e2)  (sameloc e1 e2) (= (wval e2) (rval e1)) (rf e2 e1) )  ) ) ))

; Define synchronizes-with
(assert (forall ((e1 E) (e2 E)) (=> (and (isM e1) (isR e2) (rf e1 e2) (isRel e1) (isAcq e2)) (sw e1 e2))))

; Total mo order between write events
(assert (forall ((e1 E) (e2 E)) (=> (and (isM e1) (isM e2) (sameloc e1 e2) (not (isBot e1)) (not (isBot e2)) (not (= e1 e2)) ) (or (mo e1 e2) (mo e2 e1))) ))
(assert (forall ((e1 E) (e2 E)) (=>  (mo e1 e2)  (not (mo e2 e1))) ))
(assert (forall ((e1 E) (e2 E)) (=> (mo e1 e2) (and (sameloc e1 e2) (isM e1) (isM e2) ) ) ))
(assert (forall ((e1 E) (e2 E) (e3 E)) (=> (and (mo e1 e2) (mo e2 e3))  (mo e1 e3)) ))

;CAS Semantics
(assert (forall ((e E) (e1 E) (e2 E)) (=> (and (= (etype e1) U) (= (etype e2) U)  (sameloc e1 e2) (rf e e1) (rf e e2)) (= e1 e2) ) ))

;hb order
(assert (forall ((e1 E) (e2 E)) (=> (sw e1 e2)  (hb e1 e2)) ))
(assert (forall ((e1 E) (e2 E)) (=> (soE e1 e2)  (hb e1 e2)) ))
; (assert (forall ((e1 E) (e2 E) (e3 E)) (=> (and (hb e1 e2) (hb e2 e3))  (hb e1 e3))))
(assert (forall ((e1 E) (e2 E)) (=>  (hb e1 e2)  (not (hb e2 e1))) ))
;(assert (forall ((e1 E) (e2 E)) (not (and (tot e1 e2) (ar e2 e1))) ))

;define fr,hbSC
(assert (forall ((e1 E) (e2 E) (e3 E)) (=> (and (rf e1 e2) (mo e1 e3))  (fr e2 e3)) ))
(assert (forall ((e1 E) (e2 E)) (=>  (fr e1 e2) (and  (not (= (stype e1) Bot))(not (isBot e2))  (sameloc e1 e2) (isR e1) (isM e2) ) )) )

(assert (forall ((e1 E) (e2 E)) (=> (rf e1 e2)  (hbSC e1 e2)) ))
(assert (forall ((e1 E) (e2 E)) (=> (fr e1 e2)  (hbSC e1 e2)) ))
(assert (forall ((e1 E) (e2 E)) (=> (mo e1 e2)  (hbSC e1 e2)) ))
(assert (forall ((e1 E) (e2 E)) (=> (hb e1 e2)  (hbSC e1 e2)) ))
(assert (forall ((e1 E) (e2 E)) (=> (soE e1 e2)  (hbSC e1 e2)) ))
; (assert (forall ((e1 E) (e2 E) (e3 E)) (=> (and (hbSC e1 e2) (hbSC e2 e3))  (hbSC e1 e3)) ))
(assert (forall ((e1 E) (e2 E)) (=>  (hbSC e1 e2)  (not (hbSC e2 e1))) ))

;Session Order on Events
(assert (forall ((e1 E) (e2 E)) (=>  (soE e1 e2)  (not (soE e2 e1))) ))
; (assert (forall ((e1 E) (e2 E) (e3 E)) (=> (and (soE e1 e2) (soE e2 e3))  (soE e1 e3)) ))

;Session Order on Invocations
(assert (forall ((i1 I) (i2 I)) (=> (and (sameses i1 i2) (not (= i1 i2))) (or (soI i1 i2) (soI i2 i1)) ) ))
(assert (forall ((i1 I) (i2 I)) (=>  (soI i1 i2)  (not (soI i2 i1))) ))
(assert (forall ((i1 I) (i2 I)) (=>  (soI i1 i2)  (sameses i1 i2)) ))
(assert (forall ((e1 I) (e2 I) (e3 I)) (=> (and (soI e1 e2) (soI e2 e3))  (soI e1 e3)) ))


(assert (not (= zero EMPTY)))

(assert (= (initval top Default) NULL ))
(assert (forall ((l V)) (= (initval l Next) NULL) ))
(assert (forall ((l V)) (= (initval l Val) zero) ))


(assert (forall((i I)) (not (= (argval i) EMPTY))))
(assert (forall((i I)) (not (= (argval i) zero))))
(assert (forall((i I)) (not (= (newloc i) NULL))))
(assert (forall ((i1 I) (i2 I)) (=> (= (newloc i1) (newloc i2)) (= i1 i2) ) ))


(declare-fun currd (I) V)
(declare-fun currv (I) V)
(declare-fun currn (I) V)

(assert (forall ((i I)) (=> (= (itype i) Mem) (and (= (rval (D1e i)) (currd i))
(= (stype (D1e i)) D1t) (= (loc (D1e i)) top) (= (field (D1e i)) Default) (= (etype (D1e i)) R) (= (elabel (D1e i)) Acq)))))

(assert (forall ((i I)) (=> (and (= (itype i) Mem) (not (= (currd i) NULL)))
(and (= (rval (D2e i)) (currv i)) (= (stype (D2e i)) D2t) (= (loc (D2e i))
(currd i)) (= (field (D2e i)) Val) (= (etype (D2e i)) R) (= (elabel (D2e i)) Acq) (soE (D1e i) (D2e i))))))

(assert (forall ((i I)) (=> (and (= (itype i) Mem) (not (= (currd i) NULL)))
(and (= (rval (D3e i)) (currn i)) (= (stype (D3e i)) D3t) (= (loc (D3e i))
(currd i)) (= (field (D3e i)) Next) (= (etype (D3e i)) R) (= (elabel (D3e i))
Acq) (soE (D2e i) (D3e i)) ) ) ))

(declare-const botevent E)
(assert (= (stype botevent) Bot ))

(assert (forall ((i I)) (=> (= (itype i) Add) (= (D1e i) botevent))))
(assert (forall ((i I)) (=> (= (itype i) Add) (= (D2e i) botevent))))
(assert (forall ((i I)) (=> (= (itype i) Add) (= (D3e i) botevent))))

(assert (forall ((i I)) (=> (= (itype i) Mem) (= (E1e i) botevent))))
(assert (forall ((i I)) (=> (= (itype i) Mem) (= (E2e i) botevent))))
(assert (forall ((i I)) (=> (= (itype i) Mem) (= (E3e i) botevent))))
(assert (forall ((i I)) (=> (= (itype i) Mem) (= (E4e i) botevent))))

(declare-fun currd2 (I) V)
(declare-fun currv2 (I) V)
(declare-fun currn2 (I) V)
(declare-fun curro2 (I) V)

(assert (forall ((i I)) (=> (= (itype i) Add) (and (= (rval (E1e i)) (currd2 i))
(= (stype (E1e i)) E1t) (= (loc (E1e i)) top) (= (field (E1e i)) Default) (= (etype (E1e i)) R) (= (elabel (E1e i)) Acq)))))

(assert (forall ((i I)) (=> (= (itype i) Add) (soE (E1e i) (E2e i)))))

(assert (forall ((i I)) (=> (and (= (itype i) Add) (not (= (currd2 i) NULL)))
(and (= (rval (E2e i)) (currn2 i)) (= (stype (E2e i)) E2t) (= (loc (E2e i))
(currd2 i)) (= (field (E2e i)) Next) (= (etype (E2e i)) R) (= (elabel (E2e i))
Acq)))))

(assert (forall ((i I)) (=> (= (itype i) Add) (soE (E2e i) (E3e i)))))
(assert (forall ((i I)) (=> (= (itype i) Add) (and (= (etype (E3e i)) W) (=
(elabel (E3e i)) Rel)  (= (loc (E3e i)) (newloc i)) (= (stype (E3e i)) E3t) (=
(field (E3e i)) Next) (= (wval (E3e i)) (currn2 i)) ) ) ))

(assert (forall ((i I)) (=> (= (itype i) Add) (soE (E3e i) (E4e i)))))
(assert (forall ((i I)) (=> (= (itype i) Add) (and (= (etype (E4e i)) U) (=
(elabel (E4e i)) Rel) (= (stype (E4e i)) E4t)
(= (field (E4e i)) Next) (= (rval (E4e i)) (curro2 i)) (= (wval (E4e i)) (newloc i))))))

(assert (forall ((e1 E) (e2 E)) (=> (hbSC e1 e2) (not (hb e1 e2)))))

(check-sat)
(get-model)
