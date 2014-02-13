/*
 *  xqf.h
 *
 *  $Id$
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

#ifndef _XQF_H
#define _XQF_H

typedef void (*qpq_ctr_callback)(caddr_t *n, const char *str, int do_what);
typedef int (*qpq_rangecheck_callback)(caddr_t *n, int do_what);
typedef void (*qpq_oper_callback)(caddr_t *n, const char *arg1, const char *arg2, int do_what);
typedef void (*qpq_teroper_callback)(caddr_t *n, const char *arg1, const char *arg2, const char *arg3, int do_what);

typedef struct xqf_str_parser_desc_s
{
  const char *p_name;
  qpq_ctr_callback p_proc;
  qpq_rangecheck_callback p_rcheck;
  int p_opcode;
  dtp_t p_can_default;
  int p_rdf_boxed;
  dtp_t p_dest_dtp;
  const char *p_typed_bif_name;
  const char *p_sql_cast_type;
}
xqf_str_parser_desc_t;

extern xqf_str_parser_desc_t *xqf_str_parser_descs_ptr;
extern int xqf_str_parser_desc_count;

extern sql_tree_tmp * st_integer;
extern int dt_local_tz; /* defined in datesupp.c */
extern void xqf_init(void);

#endif /* _XQF_H */
