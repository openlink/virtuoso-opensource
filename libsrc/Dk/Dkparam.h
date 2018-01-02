/*
 *  Dkparam.h
 *
 *  $Id$
 *
 *  Global parameters
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef _DKPARAM_H
#define _DKPARAM_H

#define MAX_NESTED_FUTURES		20
#define MAX_INTERRUPTS			20
#define MAX_THREADS			4096			   /* 512 */
#define MAX_SESSIONS			FD_SETSIZE		   /* 500 */
#define MAX_FUTURE_ARGUMENTS		10
#define MAX_FUTURE_THREADS		12
#define FUTURE_THREAD_SIZE		(35000 * sizeof (void *))
#define MAX_CACHED_MALLOC_SIZE		4104

#define DKSES_IN_BUFFER_LENGTH		(4096 * 8)
#define DKSES_OUT_BUFFER_LENGTH		(4096 * 8)

#define ATOMIC_TIMEOUT			2

#endif
