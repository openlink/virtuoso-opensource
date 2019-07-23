/*
 *  sqlintrp.h
 *
 *  $Id$
 *
 *  SQL Interpreter Run Time Data
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#ifndef _SQLINTRP_H
#define _SQLINTRP_H

typedef struct _cmpstruct {
  int      cmp_op;
  state_slot_t *   cmp_left;
  state_slot_t *   cmp_right;
  char             cmp_like_escape;
} bop_comparison_t;


#define CR_CLOSED 0
#define CR_INITIAL 1
#define CR_OPEN 2
#define CR_AT_END 3


typedef struct _subqpred {

  query_t *       subp_query;
  int             subp_type;
  int             subp_comparison;
  state_slot_t *	subp_left;
  state_slot_t *	subp_cl_run; /* for a multistate, array with a 1 at each set no for which the subp was evaluated */
  state_slot_t *	subp_cl_out; /* for multistate, an array with a 1 for each set where the subp had a result row */
  data_source_t *	subp_cl_clb;
  short		subp_cl_set_no_in_clb;
  code_node_t *		subp_cl_cn;
} subq_pred_t;


typedef int (* pred_func_t) (caddr_t * qst, void * comp);

typedef caddr_t (* ao_func_t) (caddr_t l, caddr_t r, caddr_t * qst, state_slot_t * target);


typedef long jmp_label_t;

#define INS_NOT_VALID		0 /* special flag to mark an invalid instruction */
#define IN_ARTM_FPTR		1
#define IN_PRED 		2
#define IN_JUMP 		3
#define IN_VRET			4
#define IN_LABEL 		5
#define IN_COMPARE 		6
#define INS_OPEN    		7
#define INS_FETCH   		8
#define INS_CLOSE   		9
#define INS_SUBQ    		10   /* call qr_exec on subq (e.g. searched delete/update/insert */
#define INS_QNODE   		11   /* call q node, e.g. insert - values, positioned delete/update */
#define INS_CALL    		12
#define INS_AREF    		13
#define INS_SET_AREF 		14
#define INS_CALL_IND 		15
#define INS_HANDLER		16
#define INS_HANDLER_END		17
#define INS_COMPOUND_START	18
#define INS_COMPOUND_END	19
#define INS_BREAKPOINT		20
#define IN_ARTM_PLUS 		21
#define IN_ARTM_MINUS		22
#define IN_ARTM_TIMES		23
#define IN_ARTM_DIV		24
#define IN_ARTM_IDENTITY	25
#define INS_CALL_BIF 26
#define IN_BRET 		27
#define IN_AGG 		28
#define INS_FOR_VECT	29
#define INS_MAX			30
#define INS_MIN			IN_ARTM_FPTR


#if 0
#define IS_INS_ARTM(x)	(((x) >= IN_ARTM_PLUS && (x) <= IN_ARTM_DIV) || (x) == IN_ARTM_COMON)
#endif
#define IS_INS_RET(x)	((x) == IN_BRET || (x) == IN_VRET)

struct instruction_s {
  union {
    struct {
      char		ins_type;
      short		func;
      state_slot_t *	result;
      state_slot_t *	left;
      state_slot_t *	right;
    } artm;
    struct {
      char		ins_type;
      char		op;
      state_slot_t *	result;
      state_slot_t *	arg;
      state_slot_t *	set_no;
      hash_area_t *	distinct;
    } agg;
    struct {
      char		ins_type;
      state_slot_t *	result;
      state_slot_t *	left;
      state_slot_t *	right;
      ao_func_t		func;
    } artm_fptr;
    struct {
      char		ins_type;
      short		succ;
      short		fail;
      short		unkn;
      short		end;
      ssl_index_t 	next_mask;
      pred_func_t	func;
      void *		cmp;
    } pred;
    struct {
      char		ins_type;
      unsigned char	op;
      short		succ;
      short		fail;
      short		unkn;
      short		end;
      ssl_index_t 	next_mask;
      short		func;
      state_slot_t *	left;
      state_slot_t *	right;
    } cmp;

    struct {
      char              ins_type;
      short 		label;
      short 		nesting_level;
    } label;
    struct {
      char		ins_type;
      state_slot_t *	value;
    } vret;
    struct {
      char		ins_type;
      char		bool_value;  /* true / false */
    } bret;
    struct {
      char		ins_type;
      query_t *		query;
      code_node_t *	cl_cn;
      state_slot_t *	cl_run; /* for multistate, array with a 1 for each set no for which the subq was evaluated */
      state_slot_t *	cl_out; /* for multistate, array with a 1 for each set for which the subq had a value */
      data_source_t *	cl_clb;
      short		cl_set_no_in_clb;
      state_slot_t *	scalar_ret; /* if vectored scalar subq called from scalar code, result here*/
    } subq;
    struct {
      char		ins_type;
      data_source_t *	node;
    } qnode;
    struct {
      char		ins_type;
      state_slot_t *	arr;
      state_slot_t *	inx;
      state_slot_t *	val;
    } aref;
    struct {
      char		ins_type;
      char		exclusive;
      query_t *		query;
      state_slot_t *	cursor;
    } open;
    struct {
      char		ins_type;
      ssl_index_t	row_ctr;
      query_t *		query;
      state_slot_t *	cursor;
      state_slot_t **	targets;
      state_slot_t *	set_no_ret;
    } fetch;
    struct {
      char		ins_type;
      state_slot_t *	cursor;
    } close;
    struct {
      char		ins_type;
      caddr_t		proc;
      state_slot_t *	ret;
      state_slot_t **	params;
      state_slot_t *	proc_ssl;
      caddr_t *		kwds;
      proc_name_t *	pn;
    } call;
    struct {
      char		ins_type;
      char		vectored;
      caddr_t		proc;
      state_slot_t *	ret;
      state_slot_t **	params;
      bif_t		bif;
    } bif;
    struct {
      char		ins_type;
      short		label;
      caddr_t		*states;
      state_slot_t      *throw_location;
      state_slot_t      *throw_nesting_level;
      state_slot_t      *state;
      state_slot_t      *message;
    } handler;
    struct {
      char		ins_type;
      char		type;
      state_slot_t *	throw_location;
      state_slot_t *	throw_nesting_level;
    } handler_end;
    struct {
      char		ins_type;
      short		line_no;
      short		l_line_no;
      short		skip;
      caddr_t		file_name;
    } compound_start;
    struct {
      char		ins_type;
      short		line_no;
      int		brk_set;
      dk_set_t		scope;
    } breakpoint;
    struct {
      char	ins_type;
      char	modify;
      state_slot_t **	in_vars;
      state_slot_t **	in_values;
      state_slot_t **	out_vars;
      state_slot_t **	out_values;
      code_vec_t	code;
    } for_vect;
  } _;
};

#define ins_type	_.artm.ins_type
extern unsigned char ins_lengths[];

/* for_vect.modify */
#define NO_VEC 2

#if 1
#define INSTR_ALIGN_UNIT (sizeof (void *))
#define ALIGN_INSTR(o) _RNDUP (o, INSTR_ALIGN_UNIT)
#define OFS_TO_BOFS(o) ((o) * INSTR_ALIGN_UNIT)
#define BOFS_TO_OFS(o) ((o) / INSTR_ALIGN_UNIT)
#else
/* #define INSTR_ALIGN_UNIT 1 */
#define ALIGN_INSTR(o) (o)
#define OFS_TO_BOFS(o) (o)
#define BOFS_TO_OFS(o) (o)
#endif

#ifndef NDEBUG
#define INS_LEN(ins_p) \
	( \
	  assert ((ins_p)->ins_type >= INS_MIN && (ins_p)->ins_type <= INS_MAX), \
	  ins_lengths[(int) ((ins_p)->ins_type)] \
	)
#else
#define INS_LEN(ins_p) \
	ins_lengths[(int) ((ins_p)->ins_type)]
#endif


#define DO_INSTR(v, ofs, arr) \
        { \
	  instruction_t *v; \
	  if (IS_BOX_POINTER (arr)) \
	    for (v = INSTR_ADD_OFS (arr, ofs); OFS_TO_BOFS (INSTR_OFS (v, arr)) < box_length (arr); \
		v = INSTR_NEXT (v)) \
	      { \

#define END_DO_INSTR \
	      } \
	}

#define INSTR_ADD_BOFS(ins_p, ofs) \
	((instruction_t *)(((caddr_t)(ins_p)) + (ofs)))

#define INSTR_ADD_OFS(ins_p, ofs) \
    	INSTR_ADD_BOFS (ins_p, OFS_TO_BOFS (ofs))

#define INSTR_OFS(ins_p, cv) \
	((short)BOFS_TO_OFS(((caddr_t)(ins_p)) - ((caddr_t)(cv))))

#define INSTR_NEXT(ins_p) \
        INSTR_ADD_BOFS (ins_p, INS_LEN (ins_p))


#define INS_QUERY(i) \
  (ins->ins_type == INS_SUBQ ? ins->_.subq.query : ((subq_pred_t*)(ins->_.pred.cmp))->subp_query)


int distinct_comp_func (caddr_t * qst, void * ha);

int bop_comp_func (caddr_t * qst, void * bop);



#define NEW_INSTR(inst, type, code) \
   t_NEW_VARZ (instruction_t, inst); \
  inst -> ins_type = type;         \
  t_set_push (code, (void*) inst);


int subq_comp_func (caddr_t * qst, void * subp);


long sqlc_new_label (sql_comp_t * sc);
void cv_label (dk_set_t * code, jmp_label_t label);
void cv_jump (dk_set_t * code, jmp_label_t label);
void cv_open (dk_set_t * code, subq_compilation_t * sqc, ST ** opts);
void cv_fetch (dk_set_t * code, subq_compilation_t *sqc, state_slot_t ** targets);
void cv_close (dk_set_t * code, state_slot_t * cr_ssl);
state_slot_t * cv_subq (dk_set_t * code, subq_compilation_t * sqc, sql_comp_t * sc);
state_slot_t *  cv_subq_qr (sql_comp_t * sc, dk_set_t * code, query_t * qr);
void cv_qnode (dk_set_t * code, data_source_t * mode);
void cv_bret (dk_set_t * code, int val);
void cv_vret (dk_set_t * code, state_slot_t * ssl);
void cv_call (dk_set_t * code, state_slot_t * fun_exp, caddr_t name, state_slot_t * ret, state_slot_t ** params);
void cv_bif_call (dk_set_t * code, bif_t bif, caddr_t name, state_slot_t * ret, state_slot_t ** params);
void cv_handler (dk_set_t * code, caddr_t *states, long label, state_slot_t *throw_loc,
    state_slot_t *nest, state_slot_t *sql_state, state_slot_t *sql_message);
void cv_handler_end (dk_set_t * code, long type, state_slot_t *throw_loc, state_slot_t *nest);
#define CV_CALL_PROC_TABLE ((state_slot_t *) -1L)
#define CV_CALL_VOID ((state_slot_t *) -2L)
#define IS_REAL_SSL(x) ((x) != CV_CALL_PROC_TABLE && (x) != CV_CALL_VOID)
/* use as ret ssl when calling for result set as proc table. The fun_exp will be the ts*  */
void cv_call_set_type (sql_comp_t * sc, instruction_t * ins, query_t *qr);

void cv_aref (dk_set_t * code, state_slot_t * ret, state_slot_t * arr, state_slot_t * inx, state_slot_t * val);

void cv_artm_set_type (instruction_t * ins);

void cv_artm (dk_set_t * code, ao_func_t f, state_slot_t * res,
	      state_slot_t * l, state_slot_t * r);
void cv_agg (dk_set_t * code, int op, state_slot_t * res,
	     state_slot_t * arg, state_slot_t * set_no, void * distinct, sql_comp_t * sc);
void cv_compare (dk_set_t * code, int bop,
     state_slot_t * l, state_slot_t * r, jmp_label_t succ, jmp_label_t fail, jmp_label_t unkn);

void sqlc_call_exp (sql_comp_t * sc, dk_set_t * code, state_slot_t * ret, ST * tree);

char *artm_func_to_text (ao_func_t ao);
const char *ammsc_name (int c);
const char * bop_text (int bop);
extern const char *cmp_op_text (int cmp);


void cv_distinct (dk_set_t * code,
		 state_slot_t * data, sql_comp_t * sc, jmp_label_t succ, jmp_label_t fail);
void cv_bop_params (state_slot_t * l, state_slot_t * r, const char *op);

#if 0
ao_func_t bop_to_artm_func (int bop);
#else
char bop_to_artm_code (int bop);
#endif

caddr_t subq_next (query_t * subq, caddr_t * inst, int cr_state);
void subq_init (query_t * subq, caddr_t * inst);

void ins_call (instruction_t * ins, caddr_t * qst, code_vec_t code_vec);
void ks_check_params_changed (it_cursor_t * itc, key_source_t * ks, caddr_t * state);
int exists_pred_func (caddr_t * qst, subq_pred_t * subp);
int  ins_cl_exists (subq_pred_t * subp, caddr_t * inst);
int ins_cl_subq (instruction_t * ins, caddr_t * inst);



typedef void (*ins_dc_artm_t) (instruction_t * ins, caddr_t * inst);
typedef int (*ins_dc_cmp_1_t) (instruction_t * ins, caddr_t * inst);
typedef int (*ins_dc_cmp_t) (instruction_t * ins, caddr_t * inst, db_buf_t bits);

extern ins_dc_artm_t dc_artm_funcs[20];
extern ins_dc_artm_t dc_artm_1_funcs[20];
extern ins_dc_cmp_t dc_cmp_funcs[10];
extern ins_dc_cmp_1_t dc_cmp_1_funcs[10];

typedef struct typed_ins_s
{
  char		ti_ins_type;
  sql_type_t	ti_sqt1;
  sql_type_t	ti_sqt2;
  sql_type_t	ti_res_sqt;
  short		ti_inx;
} typed_ins_t;



#endif /* _SQLINTRP_H */
