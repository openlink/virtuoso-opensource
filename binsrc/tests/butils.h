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

#define IS_ERR(stmt, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
 }

#define IF_ERR(stmt, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
 }

#define IF_ERR_GO(stmt, tag, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    goto tag; \
 }



#define IF_ERR_EXIT(stmt, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    exit (1); \
 }


#define IS_CERR(hdbc, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
 }

#define IF_CERR(hdbc, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
 }

#define IF_CERR_GO(hdbc, tag, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    goto tag; \
 }



#define IF_CERR_EXIT(hdbc, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    exit (1); \
 }

#define IF_EERR_EXIT(henv, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (henv, SQL_NULL_HDBC, SQL_NULL_HSTMT);  \
    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    exit (1); \
 }




void print_error (HSTMT e1, HSTMT e2, HSTMT e3);



