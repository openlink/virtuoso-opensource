/*
 *  Dkutil.h
 *
 *  $Id$
 *
 *  Helper functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#ifndef _DKUTIL_H
#define _DKUTIL_H

BEGIN_CPLUSPLUS

NORETURN int gpf_notice (const char *file, int line, const char *text);
void get_real_time (timeout_t * time_ret);
uint32 get_msec_real_time (void);
uint32 approx_msec_real_time (void);
void time_add (timeout_t * time1, timeout_t * time2);
int time_gt (timeout_t * time1, timeout_t * time2);

/* Dkmem.h */

void  memzero (void* ptr, int len);
void  memset_16 (void* ptr, unsigned char fill, int len);
void int_fill (int * ptr, int n, int len);
void int64_fill (int64 * ptr, int64 n, int len);
void int64_fill_nt (int64 * ptr, int64 n, int len);
void int_asc_fill (int * ptr, int len, int start);
void memcpy_16 (void * t, const void * s, size_t len);
void memcpy_16_nt (void * t, const void * s, size_t len);
void memmove_16 (void * t, const void * s, size_t len);
uint64 rdtsc(void);
void print_trace (void);

char * dk_cslentry (const char *list, int idx);


END_CPLUSPLUS
#endif
