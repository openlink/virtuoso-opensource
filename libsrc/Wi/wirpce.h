/*
 *  wirpce.h
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

#ifndef _WIRPCE_H
#define _WIRPCE_H

extern service_desc_t s_sql_login;
extern service_desc_t s_sql_prepare;
extern service_desc_t s_sql_execute;
extern service_desc_t s_sql_fetch;
extern service_desc_t s_sql_transact;
extern service_desc_t s_sql_free_stmt;
extern service_desc_t s_get_data;
extern service_desc_t s_get_data_ac;

extern service_desc_t s_resync_acct;
extern service_desc_t s_resync_replay;
extern service_desc_t s_sql_extended_fetch;
extern service_desc_t s_sql_set_pos;
extern service_desc_t s_sql_tp_transact;

extern service_desc_t s_pl_debug;

#endif /* _WIRPCE_H */
