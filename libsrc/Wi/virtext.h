/*
 *  virtext.h
 *
 *  $Id$
 *
 *  Virtuoso UDBC Client Extensions
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

#ifndef _VIRTEXT_H
#define _VIRTEXT_H

#define SQL_OID		21
#define SQL_BOX		22
#define SQL_C_BOX	SQL_BOX

/*
   SQL_MODE_READ_ONLY_PERMANENTLY
   When Connect Option SQL_ACCESS_MODE has been once set to
   this one, it cannot be anymore switched back to
   either SQL_MODE_READ_WRITE (0UL) or SQL_MODE_READ_ONLY (1UL).
   This can be used to implement for example surely
   read-only Web-sample-forms, which cannot be tweaked
   back to read-write mode by any means, or also to implement
   the read-only button of the setup-dialog of KUBL ODBC-driver
   (WIODBC.DLL) so that if checked, then all the connections done
   to that datasource will always be in this mode from the very
   beginning.
 */
#define SQL_MODE_READ_ONLY_PERMANENTLY 2UL

/*
   SQL_INDEX_OBJECT_ID is an extension to the set of defines
   SQL_TABLE_STAT (0)
   SQL_INDEX_CLUSTERED (1),
   SQL_INDEX_HASHED (2)
   SQL_INDEX_OTHER (3)
   returned by SQLStatistics (module sqlext.c) in its
   seventh, TYPE column.

   In the case where index is also OBJECT_ID index, the value
   of this (= 8) is added (or bit-ored if you think it that way)
   to the value that would be otherwise returned,
   e.g. it will be 8+1 = 9 for CLUSTERED OBJECT_ID indices,
   and 8+3= 11 for other kind of OBJECT_ID indices.
 */

#define SQL_INDEX_OBJECT_ID 8
#define SQL_INDEX_OBJECT_ID_STR "8"

/* SQLSetStmtOption extension */
#define SQL_TXN_TIMEOUT		5000
#define SQL_PREFETCH_SIZE	5001
#define SQL_UNIQUE_ROWS		5009

/* SQLSetConnectOption extension */
#define SQL_NO_CHAR_C_ESCAPE	5002
#define SQL_CHARSET		5003
#define SQL_APPLICATION_NAME	1051L
#define SQL_ENLIST_IN_VIRTTP    1060L
#define SQL_VIRTTP_ABORT        1061L
#define SQL_VIRTTP_COMMIT       1062L
#define SQL_ENCRYPT_CONNECTION  5004
#define SQL_SHUTDOWN_ON_CONNECT 5005
#define SQL_PWD_CLEARTEXT       5006
#define SQL_SERVER_CERT		5010
#define SQL_INPROCESS_CLIENT	5011

/* SQLColAttributes extension */
#define SQL_COLUMN_HIDDEN	5007
#ifdef SQL_COLUMN_KEY
#undef SQL_COLUMN_KEY
#endif
#define SQL_COLUMN_KEY		5008

#endif /* _VIRTEXT_H */
