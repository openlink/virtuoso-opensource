/*
 *  search_in.c
 *
 *  $Id$
 *
 *  Search
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#include "sqlnode.h"
#include "sqlfn.h"
#include "arith.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "sqlbif.h"
#include "srvstat.h"



#ifdef KEYCOMP

#define INTK_NN(offset, nth_param, lt, gt) \
  { \
    boxint n1, n2;					\
  dv2 = (db_buf_t) itc->itc_search_params[nth_param];	\
  cl = key->key_part_cls[offset]; \
  ROW_INT_COL (buf, row, rv, *cl, LONG_REF, n1); \
  n2 = unbox_inline (((caddr_t)dv2));		\
  if (n1 < n2) goto lt; \
  if (n1 > n2) goto gt; \
  }


#define INT64K_NN(offset, nth_param, lt, gt) \
  { \
    boxint n1, n2;					\
  dv2 = (db_buf_t) itc->itc_search_params[nth_param];	\
  cl = key->key_part_cls[offset]; \
  ROW_INT_COL (buf, row, rv, *cl, INT64_REF, n1); \
  n2 = unbox_inline (((caddr_t)dv2));		\
  if (n1 < n2) goto lt; \
  if (n1 > n2) goto gt; \
  }


#define STRK_NN(nth_var, nth_param, lt, gt) \
{ \
  unsigned short l1, l3, offset;		\
  int l2; \
  db_buf_t dv3; \
  cl = key->key_part_cls[nth_var]; \
  ROW_STR_COL (key, buf, row, cl, dv1, l1, dv3, l3, offset); \
  dv2 = (db_buf_t) itc->itc_search_params[nth_param]; \
  l2 = box_length_inline (dv2) - 1; \
  l1 = str_cmp_2 (dv1, dv2, dv3, l1, l2, l3, offset); \
if (DVC_LESS == l1) goto lt; \
if (DVC_GREATER == l1) goto gt; \
}


#define IRIK_NN(nth_key, nth_param, lt, gt) \
{ \
    iri_id_t i1, i2; \
    dv2 = (db_buf_t) itc->itc_search_params[nth_param];		\
  cl  = key->key_part_cls[nth_key]; \
    ROW_INT_COL (buf, row, rv, *cl, (iri_id_t) LONG_REF, i1); \
  i2 = unbox_iri_id (((caddr_t) dv2));				\
  if (i1 < i2) goto lt; \
  if (i1 > i2) goto gt; \
}


#define IRI64K_NN(nth_key, nth_param, lt, gt) \
{ \
    iri_id_t i1, i2; \
  cl  = key->key_part_cls[nth_key]; \
    dv2 = (db_buf_t) itc->itc_search_params[nth_param];		\
    ROW_INT_COL (buf, row, rv, *cl, (iri_id_t) INT64_REF, i1); \
  i2 = unbox_iri_id (((caddr_t) dv2));				\
  if (i1 < i2) goto lt; \
  if (i1 > i2) goto gt; \
}


#define ANYK_NN(nth_var, nth_param, lt, gt) \
{ \
  unsigned short l1, l3, offset; \
  db_buf_t dv3; \
  int res; \
  cl = key->key_part_cls[nth_var]; \
  ROW_STR_COL (key, buf, row, cl, dv1, l1, dv3, l3, offset); \
  dv2 = (db_buf_t) itc->itc_search_params[nth_param]; \
  l1 = dv_compare (dv1, dv2, NULL, offset);	\
  if (DVC_LESS & l1) goto lt; \
  if (DVC_GREATER & l1) goto gt; \
}



#define ROW_ANY1_COL(key, buf, row, kv, rv, cl, dv, offset)	\
{\
  db_buf_t __row2; \
  row_ver_t rv2;\
  key_ver_t kv2; \
  if ((cl)->cl_row_version_mask & rv)\
    {\
      unsigned short __irow2 = SHORT_REF (row + (cl)->cl_pos[rv]);	\
      __row2 = buf->bd_buffer + buf->bd_content_map->pm_entries[__irow2 & ROW_NO_MASK];	\
      rv2 = IE_ROW_VERSION (__row2); \
      kv2 = IE_KEY_VERSION (__row2); \
      offset = (__irow2 >> COL_OFFSET_SHIFT);\
      if (KV_LEAF_PTR == kv2) \
        dv = __row2 + key->key_key_var_start[rv2]; \
    else if (kv2 == key->key_version) \
        dv = __row2 + key->key_row_var_start[rv2]; \
      else \
        { \
          key = key->key_versions[kv2]; \
          dv = __row2 + key->key_row_var_start[rv2]; \
        } \
    }	  \
  else \
    { \
      offset = 0; \
      if (KV_LEAF_PTR == kv) \
        dv = row + key->key_key_var_start[rv]; \
      else if (kv == key->key_version) \
        dv = row + key->key_row_var_start[rv]; \
      else \
        { \
          key = key->key_versions[kv]; \
          dv = row + key->key_row_var_start[rv]; \
        } \
    } \
}


#define ANYK1_NN(nth_var, nth_param, lt, gt) \
{ \
  unsigned short offset; \
  int res; \
  cl = key->key_part_cls[nth_var]; \
  ROW_ANY1_COL (key, buf, row, kv, rv, cl, dv1, offset);	\
  dv2 = (db_buf_t) itc->itc_search_params[nth_param]; \
  res = dv_compare (dv1, dv2, NULL, offset);	\
  if (DVC_LESS & res) goto lt; \
  if (DVC_GREATER & res) goto gt; \
}


#define CMPF_HEADER(name) \
int cmpf_##name (buffer_desc_t * buf, int irow, it_cursor_t * itc) \
{ \
  db_buf_t dv1, dv2;				\
  db_buf_t row = itc->itc_row_data = BUF_ROW (buf, irow);		\
  dbe_key_t * key = itc->itc_insert_key; \
  dbe_col_loc_t * cl; \
  key_ver_t kv = IE_KEY_VERSION (row); \
  row_ver_t rv = IE_ROW_VERSION (row); \
  if (KV_LEFT_DUMMY == kv)	\
    return DVC_LESS; \
  if (key->key_version != kv) \
    key = key->key_versions[kv];

#define CMPF_END \
  return DVC_MATCH; \
  lt: return DVC_LESS; \
  gt: return DVC_GREATER; \
}


CMPF_HEADER (intn)
INTK_NN (0, 0, lt, gt)
CMPF_END

CMPF_HEADER (intn_intn)
INTK_NN (0, 0, lt, gt)
INTK_NN (1, 1, lt, gt)
CMPF_END


CMPF_HEADER (intn_intn_intn)
INTK_NN (0, 0, lt, gt)
INTK_NN (1, 1, lt, gt)
INTK_NN (2, 2, lt, gt)
CMPF_END


CMPF_HEADER (intn_intn_intn_intn)
INTK_NN (0, 0, lt, gt)
INTK_NN (1, 1, lt, gt)
INTK_NN (2, 2, lt, gt)
INTK_NN (3, 3, lt, gt)
CMPF_END




CMPF_HEADER (strn)
STRK_NN (0, 0, lt, gt)
CMPF_END


CMPF_HEADER (strn_intn)
STRK_NN (0, 0, lt, gt)
INTK_NN (1, 1, lt, gt)
CMPF_END



CMPF_HEADER (strn_intn_lte)
STRK_NN (0, 0, lt, gt)
INTK_NN (1, 1, match, gt)
	 match:
CMPF_END



CMPF_HEADER (irin_irin_anyn_irin)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, gt)
IRIK_NN (3, 3, lt, gt)
CMPF_END



CMPF_HEADER (irin_irin_anyn_irin_lte)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, gt)
IRIK_NN (3, 3, match, gt)
match:
CMPF_END


CMPF_HEADER (anyn_irin_irin_irin_lte)
ANYK1_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
IRIK_NN (2, 2, lt, gt)
IRIK_NN (3, 3, match, gt)
match:
CMPF_END


CMPF_HEADER (anyn_irin_irin_irin)
ANYK1_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
IRIK_NN (2, 2, lt, gt)
IRIK_NN (3, 3, lt, gt)
CMPF_END



CMPF_HEADER (irin_irin_anyn)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, gt)
CMPF_END



CMPF_HEADER (irin_irin_irin_anyn)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
IRIK_NN (2, 2, lt, gt)
ANYK1_NN (3, 3, lt, gt)
CMPF_END


CMPF_HEADER (irin_irin_irin)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
IRIK_NN (2, 2, lt, gt)
CMPF_END

CMPF_HEADER (irin_irin)
IRIK_NN (0, 0, lt, gt)
IRIK_NN (1, 1, lt, gt)
CMPF_END


CMPF_HEADER (irin)
IRIK_NN (0, 0, lt, gt)
CMPF_END




/* 64 bit versions of the above */

CMPF_HEADER (int64n)
INT64K_NN (0, 0, lt, gt)
CMPF_END

CMPF_HEADER (int64n_int64n)
INT64K_NN (0, 0, lt, gt)
INT64K_NN (1, 1, lt, gt)
CMPF_END


CMPF_HEADER (int64n_int64n_int64n)
INT64K_NN (0, 0, lt, gt)
INT64K_NN (1, 1, lt, gt)
INT64K_NN (2, 2, lt, gt)
CMPF_END


CMPF_HEADER (int64n_int64n_int64n_int64n)
INT64K_NN (0, 0, lt, gt)
INT64K_NN (1, 1, lt, gt)
INT64K_NN (2, 2, lt, gt)
INT64K_NN (3, 3, lt, gt)
CMPF_END



CMPF_HEADER (strn_int64n)
STRK_NN (0, 0, lt, gt)
INT64K_NN (1, 1, lt, gt)
CMPF_END



CMPF_HEADER (strn_int64n_lte)
STRK_NN (0, 0, lt, gt)
INT64K_NN (1, 1, match, gt)
	 match:
CMPF_END



CMPF_HEADER (iri64n_iri64n_anyn_iri64n)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, gt)
IRI64K_NN (3, 3, lt, gt)
CMPF_END



CMPF_HEADER (iri64n_iri64n_anyn_iri64n_lte)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, gt)
IRI64K_NN (3, 3, match, gt)
match:
CMPF_END


CMPF_HEADER (iri64n_iri64n_anyn_gt_lt)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, m1)
m1:
ANYK1_NN (2, 3, match, gt)
match:
CMPF_END


CMPF_HEADER (iri64n_iri64n_lte)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, match, gt)
match:
CMPF_END


CMPF_HEADER (iri64n_anyn_iri64n_iri64n_lte)
IRI64K_NN (0, 0, lt, gt)
ANYK1_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
IRI64K_NN (3, 3, match, gt)
match:
CMPF_END


CMPF_HEADER (iri64n_anyn_iri64n)
IRI64K_NN (0, 0, lt, gt)
ANYK1_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
CMPF_END



CMPF_HEADER (anyn_iri64n_iri64n_iri64n_lte)
ANYK1_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
IRI64K_NN (3, 3, match, gt)
match:
CMPF_END


CMPF_HEADER (anyn_iri64n_iri64n_iri64n)
ANYK1_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
IRI64K_NN (3, 3, lt, gt)
CMPF_END


CMPF_HEADER (anyn_iri64n_iri64n)
ANYK1_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
CMPF_END


CMPF_HEADER (anyn_iri64n)
ANYK1_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
CMPF_END


CMPF_HEADER (anyn)
ANYK1_NN (0, 0, lt, gt)
CMPF_END


CMPF_HEADER (iri64n_iri64n_anyn)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
ANYK1_NN (2, 2, lt, gt)
CMPF_END



CMPF_HEADER (iri64n_iri64n_iri64n_anyn)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
ANYK1_NN (3, 3, lt, gt)
CMPF_END


CMPF_HEADER (iri64n_iri64n_iri64n)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
IRI64K_NN (2, 2, lt, gt)
CMPF_END

CMPF_HEADER (iri64n_iri64n)
IRI64K_NN (0, 0, lt, gt)
IRI64K_NN (1, 1, lt, gt)
CMPF_END


CMPF_HEADER (iri64n)
IRI64K_NN (0, 0, lt, gt)
CMPF_END




dk_set_t cfd_list = NULL;

#define NOMORE 99 /*sentinel value distinct from CMP_xx */




void
ksp_cmp_func (key_spec_t * ksp, unsigned char * nth)
{
  int n = 0;
  search_spec_t * sp = ksp->ksp_spec_array;
  int all_eq = 1;
  DO_SET (cmp_func_desc_t *, cfd, &cfd_list)
    {
      int pinx;
      search_spec_t * sps = sp;
      cmp_desc_t * desc = cfd->cfd_compares;
      for (pinx = 0; desc[pinx].cmd_min_op != NOMORE; pinx++)
	{
	  if (!sps || sps->sp_is_reverse || sps->sp_collation)
	    goto next_func;
	  if (CMP_EQ != sps->sp_min_op)
	    all_eq = 0;
	  if (desc[pinx].cmd_min_op != sps->sp_min_op
	      || desc[pinx].cmd_max_op != sps->sp_max_op
	      || desc[pinx].cmd_dtp != sps->sp_cl.cl_sqt.sqt_dtp
	      || desc[pinx].cmd_non_null != sps->sp_cl.cl_sqt.sqt_non_null)
	    goto next_func;
	  sps = sps->sp_next;

	}
      if (!sps)
	{
	  ksp->ksp_key_cmp = cfd->cfd_func;
	  if (nth)
	    *nth = n + 1;
	  return;
	}
    next_func: ;
      n++;
    }
  END_DO_SET();
  ksp->ksp_key_cmp = NULL;
  if (nth)
    *nth = 0;
}


void
ksp_nth_cmp_func (key_spec_t * ksp, char nth)
{
  if (!nth)
    ksp->ksp_key_cmp = NULL;
  else
    {
      cmp_func_desc_t * cfd = (cmp_func_desc_t *) dk_set_nth (cfd_list, nth - 1);
      if (!cfd) GPF_T1 ("Bad inline key comp id");
      ksp->ksp_key_cmp = cfd->cfd_func;
    }
}


void
sp_add_func (key_cmp_t f, cmp_desc_t c[])
{
  NEW_VARZ (cmp_func_desc_t, cfd);
  cfd->cfd_func = f;
  cfd->cfd_compares = c;
  dk_set_push (&cfd_list, (void*) cfd);
}


#define SPF(f) \
{ \
  key_cmp_t __f = cmpf_##f; \
  static cmp_desc_t __a [] = {

#define SPF_END \
  ,{NOMORE, 0, 0, 0}};				\
  sp_add_func (__f, __a); }



void
search_inline_init ()
{
  static cmp_desc_t  intn_p[] = {{CMP_EQ, CMP_NONE, DV_LONG_INT, 1}, {NOMORE, 0, 0, 0}};
  static cmp_desc_t strn_p [] = {{CMP_EQ, CMP_NONE, DV_STRING, 1}, {NOMORE, 0, 0, 0}};
  /*return;*/
  sp_add_func (cmpf_intn, intn_p);
  sp_add_func (cmpf_strn, strn_p);
  SPF (irin_irin_anyn_irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;
  SPF (irin_irin_anyn_irin_lte)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID, 1}
  SPF_END;
  SPF (anyn_irin_irin_irin_lte)
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID, 1}
  SPF_END;
  SPF (anyn_irin_irin_irin)
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;


  SPF (irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;
  SPF (irin_irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;

  SPF (irin_irin_irin)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1}
  SPF_END;
  SPF (irin_irin_irin_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
  {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (irin_irin_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (intn_intn)
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;

  SPF (intn_intn_intn)
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;

  SPF (intn_intn_intn_intn)
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;

  SPF (strn_intn)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_EQ, CMP_NONE, DV_LONG_INT, 1}
  SPF_END;
  SPF (strn_intn_lte)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_NONE, CMP_LTE, DV_LONG_INT, 1}
  SPF_END;

/* 64 bit declarations */

  SPF (iri64n_iri64n_anyn_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (iri64n_anyn_iri64n_iri64n_lte)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (iri64n_anyn_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (iri64n_iri64n_anyn_gt_lt)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_GT, CMP_LT, DV_ANY, 1}
  SPF_END;

  SPF (iri64n_iri64n_anyn_iri64n_lte)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (iri64n_iri64n_lte)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID_8, 1}
  SPF_END;


  SPF (anyn_iri64n_iri64n_iri64n_lte)
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_NONE, CMP_LTE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (anyn_iri64n_iri64n_iri64n)
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (anyn_iri64n_iri64n)
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (anyn_iri64n)
    {CMP_EQ, CMP_NONE, DV_ANY, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (anyn)
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (iri64n_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;

  SPF (iri64n_iri64n_iri64n)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1}
  SPF_END;
  SPF (iri64n_iri64n_iri64n_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
  {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (iri64n_iri64n_anyn)
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_IRI_ID_8, 1},
    {CMP_EQ, CMP_NONE, DV_ANY, 1}
  SPF_END;

  SPF (int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;


  SPF (int64n_int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;

  SPF (int64n_int64n_int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;

  SPF (int64n_int64n_int64n_int64n)
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;

  SPF (strn_int64n)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_EQ, CMP_NONE, DV_INT64, 1}
  SPF_END;
  SPF (strn_int64n_lte)
    {CMP_EQ, CMP_NONE, DV_STRING, 1},
    {CMP_NONE, CMP_LTE, DV_INT64, 1}
  SPF_END;


}

#else

void
ksp_cmp_func (key_spec_t * ksp, char * nth)
{
  ksp->ksp_key_cmp = NULL;
}


void
ksp_nth_cmp_func (key_spec_t * ksp, char nth)
{
  ksp->ksp_cmp_func = NULL;
}


void
search_inline_init ()
{
}


#endif


