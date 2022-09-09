#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <pthread.h>
#include <assert.h>

typedef struct node {
	_Atomic(unsigned int) value;
	_Atomic(struct node*) next;
} node_t;

_Atomic(node_t*) end;
_Atomic(node_t*) top;

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
			if(atomic_compare_exchange_strong_explicit(&(curr->next), &next, new, memory_order_release, memory_order_acquire))
				break;
		}

		if(v <= next->value) {
			atomic_store_explicit(&(new->next), next, memory_order_release);
			if(atomic_compare_exchange_strong_explicit(&(curr->next), &next, new, memory_order_release, memory_order_acquire))
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

int main() {

	/* local variables */
	pthread_t t1, t2, t3;
	node_t *n1, *n2;

	/* initialize node */
	n1 = malloc(sizeof(node_t));
	n2 = malloc(sizeof(node_t));
	atomic_init(&(n1->value), 0);
	atomic_init(&(n2->value), 1000);
	atomic_init(&(n1->next), n2);
	atomic_init(&(n2->next), NULL);
	atomic_init(&top, n1);
	atomic_init(&end, n2);

	/* reader thread */
	pthread_create(&t1, NULL, threadM1, NULL);

	/* writer thread */
	pthread_create(&t2, NULL, threadA, NULL);

	/* write thread */
	pthread_create(&t3, NULL, threadM2, NULL);
	
	pthread_join(t1, NULL);
	pthread_join(t2, NULL);
	pthread_join(t3, NULL);
	
	return 0;
}
