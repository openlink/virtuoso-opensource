/*
 *  wirpc.c
 *
 *  $Id$
 *
 *  Global RPC call hooks
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

#include "Dk.h"

SERVICE_4 (s_sql_login, _sqlc, "SCON", DA_FUTURE_REQUEST,
	DV_LONG_INT,		/* return type */
	DV_C_STRING, 		1,
	DV_SHORT_STRING, 	1,
	DV_C_STRING, 		1,
	DV_ARRAY_OF_POINTER, 	1);	/* params */

SERVICE_4 (s_sql_prepare, _sprep, "PREP", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_SHORT_STRING,	0,
	DV_SHORT_STRING,	0,
	DV_LONG_INT,		1,
	DV_ARRAY_OF_LONG,	1);

SERVICE_6 (s_sql_execute, _sexec, "EXEC", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_SHORT_STRING,	0,/* id */
	DV_SHORT_STRING,	1,/* text */
	DV_SHORT_STRING,	1,/* cursor name */
	DV_ARRAY_OF_POINTER,	0,/* params */
	DV_ARRAY_OF_POINTER,	1,/* current ofs */
	DV_ARRAY_OF_LONG,	1);/* options */

SERVICE_2 (s_sql_fetch, sftc, "FTCH", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_SHORT_STRING,	0,
	DV_LONG_INT,		1);

SERVICE_2 (s_sql_transact, _strx, "TRXC", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_LONG_INT,		1,
	DV_LONG_INT,		1); /* currently not used */

SERVICE_2 (s_sql_free_stmt, _frst, "FRST", DA_FUTURE_REQUEST,
	DV_LONG_INT,		/* return type */
	DV_SHORT_STRING,	0,
	DV_LONG_INT,		1);

SERVICE_5 (s_get_data, _sgbt, "GETD", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_SHORT_STRING,	0,/* stmt */
	DV_LONG_INT,		1,/* current_of */
	DV_LONG_INT,		1,/* nth_col */
	DV_LONG_INT,		1,/* how_much */
	DV_LONG_INT,		1);/* from_byte */

SERVICE_9 (s_get_data_ac , _sgbt2, "GETDA", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_LONG_INT,		1,/* page no */
	DV_LONG_INT,		1,/* how_much */
	DV_LONG_INT,		1,/* pos_in_page */
	DV_LONG_INT,		1,/* key_id */
	DV_LONG_INT,		1,/* frag_no */
	DV_LONG_INT,		1,/* page dir 1st page */
	DV_LONG_STRING,		1,/* the array of page nos */
	DV_LONG_INT,		1,/* is_wide or is_bin ? */
	DV_LONG_INT,            1);/* blob timestamp */


/* Replication */

SERVICE_5 (s_resync_acct, _sra, "RSNC", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_C_STRING,		0,/* account */
	DV_LONG_INT,		1,/* level */
	DV_SHORT_STRING,	0,/* subscriber name */
	DV_C_STRING,		0,/* uid, auth hash */
	DV_SHORT_STRING,	0);

SERVICE_4 (s_resync_replay, _srl, "RSRP", DA_FUTURE_REQUEST,
	DV_LONG_INT,	        /* return type */
	DV_SHORT_STRING,	0,/* account */
	DV_SHORT_STRING,	0,/* subscriber name */
	DV_SHORT_STRING,	0,/* uid, auth hash */
	DV_SHORT_STRING,        0);

SERVICE_6 (s_sql_extended_fetch, _extf, "EXTF", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,	/* return type */
	DV_C_STRING,		0,
	DV_LONG_INT,		1,
	DV_LONG_INT,		1,
	DV_LONG_INT,		1,
	DV_LONG_INT,		1,
	0,			1); /* bookmark - make it unknown as it's sometimes DV_ARRAY_OF_POINTER, sometimes DV_INT */
SERVICE_2 (s_sql_tp_transact, _tp, "TPTRX", DA_FUTURE_REQUEST,
	DV_SEND_NO_ANSWER,
	DV_LONG_INT,		1,
	DV_STRING,		1);

/* PL debugger */

SERVICE_2 (s_pl_debug, _pld, "PLDBG", DA_FUTURE_REQUEST,
	DV_LONG_INT,	/* return type */
	DV_C_STRING,		1,
	DV_C_STRING,		1);
