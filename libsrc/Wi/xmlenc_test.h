/*
 *  xmlenc_test.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

void breakpoint(void);
void trset_start (caddr_t * qst);
void trset_printf (const char *str, ...);
void trset_end ();

#define rep_printf	trset_printf

void xenc_test_begin();
void xenc_test_end();
int xenc_test_processing();
void xenc_assert_1(int term, char* file, long line);

#define xenc_assert(term) xenc_assert_1(term, __FILE__, __LINE__)

void xenc_asserts_print_report(FILE * stream);

extern long xenc_errs;
extern long xenc_asserts;
extern long is_test_processing;


