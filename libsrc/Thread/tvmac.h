/*
 *  tvmac.c
 *
 *  $Id$
 *
 *  Macros for time structure manipulation
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
 *  
*/

#ifndef _TVMAC_H
#define _TVMAC_H

#if 1
#define TV_RES		1000
#define	TV_ZERO(t)	(t = 0)
#define TV_ISINF(t)	(t == TV_INFINITE)
#define	TV_ISZERO(t)	(t == 0)
#define	TV_XLTY(x,y)	(x < y)
#define	TV_XADDY(z,x,y)	z = x + y
#define	TV_XSUBY(z,x,y)	z = x - y

#else

#define TV_RES		1000000
#define	TV_ZERO(t)	(t.tv_sec = t.tv_usec = 0)
#define	TV_ISZERO(t)	(t.tv_sec == 0 && t.tv_usec == 0)
#define TV_ISINF(t)	(t.tv_sec == -1 && t.tv_usec == -1)
#define	TV_XLTY(x, y) \
	(x.tv_sec < y.tv_sec || \
	(x.tv_sec == y.tv_sec && x.tv_usec < y.tv_usec))
#define	TV_XADDY(z, x, y) \
	if ((z.tv_usec = x.tv_usec + y.tv_usec) < TV_RES) { \
		z.tv_sec = x.tv_sec + y.tv_sec; \
	} else { \
		z.tv_usec -= TV_RES; \
		z.tv_sec = x.tv_sec + y.tv_sec + 1; \
	}
#define	TV_XSUBY(z, x, y) \
	if (x.tv_usec >= y.tv_usec) { \
		z.tv_sec = x.tv_sec - y.tv_sec; \
		z.tv_usec = x.tv_usec - y.tv_usec; \
	} else { \
		z.tv_sec = x.tv_sec - y.tv_sec - 1; \
		z.tv_usec = x.tv_usec + TV_RES - y.tv_usec; \
	}
#endif

#endif
