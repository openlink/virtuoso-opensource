/*
 * sqloinv.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#ifndef _SQLOINV_H
#define _SQLOINV_H

typedef struct sinv_map_s
{
  caddr_t   sinvm_name;
  unsigned  sinvm_flags;
  caddr_t * sinvm_inverse;
} sinv_map_t;

#define SINV_FLAG_ORDER_PRESERVING 1

#define IS_ORDER_PRESERVING(x) ((x)->sinvm_flags & SINV_FLAG_ORDER_PRESERVING)

void sinv_read_sql_inverses (const char * function_name,
    client_connection_t * cli);
void sqlo_inv_bif_int (void);

#endif /* _SQLOINV_H */
