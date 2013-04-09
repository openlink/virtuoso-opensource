/*
 *  srvstat.h
 *
 *  $Id$
 *
 *  stats collection
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

#ifndef _SRVSTAT_H
#define _SRVSTAT_H
#include "Dk.h"

/* disk.c */
extern long disk_reads;
extern long disk_releases;
extern long read_cum_time;
extern long disk_writes;
extern int64 bp_replace_age;
extern int32 bp_replace_count;
extern char *db_version_string;

/* search.c */
extern long ra_count;
extern long ra_pages;

/* gate.c */
extern long second_reads;
extern long in_while_read;

/*lock.c */
extern long lock_killed_by_force;
extern long lock_deadlocks;
extern long lock_2r1w_deadlocks;
extern long lock_waits;
extern long lock_enters;
extern long lock_leaves;

/* neodisk.c */
extern long busy_pre_image_scrap;
extern long atomic_cp_msecs;

/* sqlsrv.c */
extern long srv_connect_ctr;
extern long srv_max_clients;

/* srvstat.c */
extern char *product_version_string (void);
extern time_t st_started_since;
extern long st_sys_ram;

extern long first_id;

EXE_EXPORT (caddr_t, sys_stat_impl, (const char *name));

#endif /* _SRVSTAT_H */
