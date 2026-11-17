/* Test the actual sample cache key implementation with minimal allocator and cursor stubs. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef char *caddr_t;
typedef int64_t int64;
typedef struct node_s { caddr_t data; struct node_s *next; } *dk_set_t;
typedef struct spec_s {
  struct { int cl_col_id; } sp_cl;
  int sp_min_op, sp_max_op;
  struct spec_s *sp_next;
} search_spec_t;
typedef struct { int key_id; } sample_key_t;
typedef struct {
  sample_key_t *itc_insert_key;
  struct { search_spec_t *ksp_spec_array; } itc_key_spec;
  search_spec_t *itc_row_specs;
  int itc_search_par_fill;
  caddr_t itc_search_params[2];
} it_cursor_t;
#define DV_ARRAY_OF_POINTER 1
#define CMP_NONE 0

/* Represent the small integer test parameters with a low-bit tag. */
static caddr_t box_num(int64 value) { return (caddr_t)(intptr_t)(value * 2 + 1); }

/* Store array lengths to support recursive comparison and deallocation. */
static caddr_t dk_alloc_box(size_t size, int type) {
  size_t *box = malloc(sizeof(size_t) + size);
  assert(box && type == DV_ARRAY_OF_POINTER);
  *box = size / sizeof(caddr_t);
  return (caddr_t)(box + 1);
}

/* Immediate integers have no separately owned storage to copy. */
static caddr_t box_copy_tree(caddr_t value) { return value; }

/* Match the production set's head insertion order. */
static void dk_set_push(dk_set_t *set, caddr_t data) {
  dk_set_t node = malloc(sizeof(*node));
  assert(node);
  *node = (struct node_s){data, *set};
  *set = node;
}

/* Restore the original specification order. */
static dk_set_t dk_set_nreverse(dk_set_t set) {
  dk_set_t reversed = NULL;
  while (set) {
    dk_set_t next = set->next;
    set->next = reversed;
    reversed = set;
    set = next;
  }
  return reversed;
}

/* Convert the list to the production array layout and release its nodes. */
static caddr_t list_to_array(dk_set_t set) {
  size_t count = 0, index = 0;
  for (dk_set_t node = set; node; node = node->next) count++;
  caddr_t *array = (caddr_t *)dk_alloc_box(count * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
  while (set) {
    dk_set_t next = set->next;
    array[index++] = set->data;
    free(set);
    set = next;
  }
  return (caddr_t)array;
}

/* Compare complete cache keys rather than only parameter values or hashes. */
static int tree_equal(caddr_t left, caddr_t right) {
  if (((uintptr_t)left & 1) || ((uintptr_t)right & 1)) return left == right;
  size_t count = ((size_t *)left)[-1];
  if (count != ((size_t *)right)[-1]) return 0;
  for (size_t index = 0; index < count; index++)
    if (!tree_equal(((caddr_t *)left)[index], ((caddr_t *)right)[index])) return 0;
  return 1;
}

/* Release nested arrays so sanitizers can verify key ownership. */
static void tree_free(caddr_t box) {
  if ((uintptr_t)box & 1) return;
  size_t count = ((size_t *)box)[-1];
  for (size_t index = 0; index < count; index++) tree_free(((caddr_t *)box)[index]);
  free((size_t *)box - 1);
}

caddr_t
#include SAMPLE_CACHE_SOURCE

/* Equal values and operators must not hide different index boundaries or filter columns. */
int main(void) {
  sample_key_t index = {271};
  search_spec_t second = {{607}, 1, 0, NULL};
  search_spec_t first = {{608}, 1, 0, &second};
  it_cursor_t cursor = {&index, {&first}, NULL, 2, {box_num(10), box_num(20)}};
  caddr_t indexed = itc_sample_cache_key(&cursor);
  caddr_t repeated = itc_sample_cache_key(&cursor);
  assert(tree_equal(indexed, repeated));
  first.sp_next = NULL;
  cursor.itc_row_specs = &second;
  caddr_t filtered = itc_sample_cache_key(&cursor);
  assert(!tree_equal(indexed, filtered));
  second.sp_cl.cl_col_id = 606;
  caddr_t other_column = itc_sample_cache_key(&cursor);
  assert(!tree_equal(filtered, other_column));
  second.sp_min_op = 2;
  caddr_t range = itc_sample_cache_key(&cursor);
  assert(!tree_equal(other_column, range));
  tree_free(indexed);
  tree_free(repeated);
  tree_free(filtered);
  tree_free(other_column);
  tree_free(range);
  puts("PASS: sample cache keys distinguish index boundaries, columns and operators");
  return 0;
}
