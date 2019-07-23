/*
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

extern HDBC hdbc;
extern HENV henv;



/* #define MINI */

#ifdef MINI

#define MAXITEMS      10000
#define CUST_PER_DIST 3000
#define DIST_PER_WARE 10
#define ORD_PER_DIST  300

#else

#define MAXITEMS      100000
#define CUST_PER_DIST 3000
#define DIST_PER_WARE 10
#define ORD_PER_DIST  3000

#endif

#ifndef NO_ARRAY_PARAMETERS
#define BATCH_SIZE 500
#else
#define BATCH_SIZE 1
#endif



extern SDWORD sql_timelen_array [];



#define LOCAL_STMT(stmt, text) \
  if (! stmt) { \
    INIT_STMT (hdbc, stmt, text); \
  }

#ifdef WIN32
#define dk_exit exit
#endif

long RandomNumber (long x, long y);
void MakeAddress  (char *str1, char *str2, char *city,
		   char *state,
		   char *zip);
int MakeAlphaString (int sz1, int sz2, char * str);
long random_i_id (void);
long random_c_id (void);
void Lastname (int num, char *name);


void run_test (int argc, char ** argv);
void run_timed_test (int argc, char **argv);

