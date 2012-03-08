/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef _SUBSEQ_H
#define _SUBSEQ_H

#include "Dk.h"

typedef struct subseq_s
{
  caddr_t *ss_state;		/* boxed */
  caddr_t *ss_not_in_state;		/* boxed */
  caddr_t *ss_array;		/* boxed */
  int ss_in_state_num;
  int ss_out_state_num;
  int ss_iter_num;
}
subseq_t;

subseq_t *ss_iter_init (caddr_t * init_array, int in_num);
caddr_t *ss_iter_next (subseq_t * iter);
caddr_t *ss_not_in_seq (subseq_t * iter);
void ss_iter_free (subseq_t * ss_iter);

#endif
