/*
 *  arith.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#ifndef _WI_ARITH_H
#define _WI_ARITH_H

#include <math.h>
#include <float.h>

int n_coerce (caddr_t n1, caddr_t n2, dtp_t dtp1, dtp_t dtp2, dtp_t * out_dtp);

dtp_t dv_ext_to_num (dtp_t * place, caddr_t to);

int cmp_dv_box (caddr_t dv, caddr_t box);

int cmp_double (double x1, double x2, double epsilon);

extern int cmp_boxes (ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2);
extern int cmp_boxes_safe (ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2);
extern int bool_bop_boxes (int bop, ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2);

caddr_t box_add (ccaddr_t l, ccaddr_t r, caddr_t * qst, state_slot_t * target);
caddr_t box_sub (ccaddr_t l, ccaddr_t r, caddr_t * qst, state_slot_t * target);
caddr_t box_div (ccaddr_t l, ccaddr_t r, caddr_t * qst, state_slot_t * target);
caddr_t box_mpy (ccaddr_t l, ccaddr_t r, caddr_t * qst, state_slot_t * target);
caddr_t box_mod (ccaddr_t l, ccaddr_t r, caddr_t * qst, state_slot_t * target);
caddr_t box_identity (ccaddr_t arg, ccaddr_t ignore, caddr_t * qst, state_slot_t * target);

#ifndef _WI_STRLIKE_H
#include "strlike.h"
#endif

int numeric_compare_dvc (numeric_t x, numeric_t y);
int dv_num_compare (numeric_t dn1, numeric_t dn2, dtp_t dtp1, dtp_t dtp2);
#define MAX_INT_DOUBLE ((((int64)1) << 53) - 1)
#define MIN_INT_DOUBLE  (-(((int64)1)<<53) + 1)


#endif /* _WI_ARITH_H */
