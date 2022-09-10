# Automated Robustness Rebuttal Supplementary Material

In this document, we highlight a example where the robustness violation depends on the number of concurrent threads executing. Then we run that program through a model checker and our tool to demonstrate the violation.

## Data structure implementation

We present a simple set implementation realized as a sorted linked list. It has two operations `add` and `mem`, which adds elements to the set and checks membership respectively. As can be seen in the code follow, the `add` method follows the pattern of first searching for the correct place to insert the element, allocating a new node, pointing the next field of the new node to the successive node and then swinging the next of the previous node to the allocated node. The membership operation walks over the linked list to look for the elements. Note the access modes of the CAS operations. They are intentionally relaxed to demonstrate the robustness violation.

```c
void add(int v) {
	node_t* curr;
	node_t* next;
	node_t* new = malloc(sizeof(node_t));
	new->value = v;
	new->next = NULL;

	curr = atomic_load_explicit(&top, memory_order_acquire);

	while(true) {
		next = atomic_load_explicit(&(curr->next), memory_order_acquire);

		if(atomic_load_explicit(&(next->value), memory_order_acquire) == 1000) {
			/* reached end, try to add node */
			atomic_store_explicit(&(new->next), next, memory_order_release);
			if(atomic_compare_exchange_strong_explicit(&(curr->next), &next, new, memory_order_release, memory_order_relaxed))
				break;
		}

		if(v <= next->value) {
			atomic_store_explicit(&(new->next), next, memory_order_release);
			if(atomic_compare_exchange_strong_explicit(&(curr->next), &next, new, memory_order_release, memory_order_relaxed))
				break;
		}

		curr = next;
	}
}

bool mem(int v) {
	node_t* curr;

	curr = atomic_load_explicit(&top, memory_order_acquire);

	while(true) {
		if(curr->value == 1000) {
			/* reached end, exit */
			return false;
		}

		if(curr->value == v) {
			return true;
		}

		curr = atomic_load_explicit(&(curr->next), memory_order_acquire);
	}
}
```

We detail the test program. We create two thread functions, one for adding new elements to the set and one for checking membership. Then we launch 2 threads where one thread adds elements and one checks for membership. In another test case, we create 3 threads with one checking for membership and two checking the addition of elements. 

```
void* threadM1(void* param) {
	add(10);
	add(20);
	return NULL;
}

void* threadM2(void* param) {
	add(30);
	add(40);
	return NULL;
}

void* threadA(void* param) {
	printf("exec\n");
	printf("%d\n", mem(10));
	return NULL;
}
```

## Executing the model checker

When we run the model checker on this code with 2 threads, we observe this output - 

```
../../src/genmc -rc11 -wb -- main.c
exec
1
exec
0
No errors were detected.
Number of complete executions explored: 2
Total wall-clock time: 0.29s
```

Now when we run the model checker with 3 threads, we observe the following output -

```
../../src/genmc -rc11 -wb -- main.c
exec
1
exec
1
Error detected: Attempt to access non-allocated memory!
Event (3, 12) conflicts with event (1, 10) in graph:
<-1, 0> main:
        (0, 1): MALLOC  L.88
...
        (3, 12): Rsc (, 0) [BOTTOM] L.35

The allocating operation (malloc()) does not happen-before the memory access!
Number of complete executions explored: 1
Number of blocked executions seen: 1
Total wall-clock time: 0.30s
make: *** [Makefile:2: all] Error 42
```

As we can see there is a robustness violation, when we change the number of threads. Moreover this error does not occur when we change the access modes of the CAS operation to acquire-release.

## Executing our tool

We run the benchmark through our tool which generates SMT queries for the encodings to check the invariants. We try to find 2 events such that they are `hbSC` but not `hb`. Our tool reports a case where the robustness condition is violated. The encoding for the partial events generated to verify this case can be found in `set-incorrect.smt`. A sample encoding of one event can be seen below - 

```
(assert 
	(forall ((i I)) ; for a given invocation
	(=> (= (itype i) Add) ; if the invocation is Add
	(and (= (rval (E1e i)) (currd2 i)) ; read value is stored in a local variable currd2
	(= (stype (E1e i)) E1t)
	(= (loc (E1e i)) top) ; location of read is top
	(= (field (E1e i)) Default) ; read field is default
	(= (etype (E1e i)) R) ; event type if Read
	(= (elabel (E1e i)) Acq))))) ; event mode is Acquire
```

Now, when we run Z3 on this, it outputs a model. The model can be found in `output.model`. The robustness violation states that the CAS operations are totally ordered in the SC world, but not in the RC20 world. Thus, we present a snippet of the hbSC code - 

```
(define-fun hbSC ((x!0 E) (x!1 E)) Bool
	(or (and (= (k!2234 x!0) E!val!106) (= (k!2234 x!1) E!val!105))
	(and (= (k!2234 x!0) E!val!162) (= (k!2234 x!1) E!val!161))
	(and (= (k!2234 x!0) E!val!149) (= (k!2234 x!1) E!val!140))
	(and (= (k!2234 x!0) E!val!174) (= (k!2234 x!1) E!val!173))) ; E174 and E173 are in HBSC order
...
```

But `E174` and `E173` are not in the hb-relation. Moroever, we can see that `E174` and `E173` are the 2 CAS events in the invocations - 

```
(define-fun E4e ((x!0 I)) E
	(ite (= x!0 in3) E!val!0
	(ite (= x!0 in1) E!val!173 ; CAS event in Add invocation
	(ite (= x!0 in2) E!val!174 ; CAS event in Add invocation
	E!val!3))))
```

Thus, we see that our tool generates the necessary robustness violation.
