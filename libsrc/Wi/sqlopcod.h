/*
 *  sqlopcod.h
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

#ifndef _SQLOPCOD_H
#define _SQLOPCOD_H

#define OP_SHUTDOWN		(long)300
#define OP_CHECKPOINT		(long)301
#define OP_BACKUP		(long)302
#define OP_CHECK		(long)303
#define OP_SYNC_REPL		(long)304
#define OP_DISC_REPL		(long)305
#define OP_LOG_ON		(long)306
#define OP_LOG_OFF		(long)307

#define OP_STORE_PROC		(long)400
#define OP_STORE_TRIGGER	(long)401
#define OP_STORE_VIEW		(long)403
#define OP_DROP_TRIGGER		(long)404
#define OP_STORE_METHOD		(long)405

#define ORDER_ASC	1
#define ORDER_DESC	2

#define TRIG_UPDATE	TB_RLS_U
#define TRIG_INSERT	TB_RLS_I
#define TRIG_DELETE	TB_RLS_D

#define TRIG_BEFORE	0
#define TRIG_AFTER	1
#define TRIG_INSTEAD	2

#endif /* _SQLOPCOD_H */
