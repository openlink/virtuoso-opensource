/*
 *  listmac.h
 *
 *  $Id$
 *
 *  List macros
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
 *  
*/

#define LISTINIT(e,f,r) \
	{ \
	  (e)->f = (e)->r = e; \
	}

#define LISTPUTAFTER(o,n,f,r) \
	{ \
	  (n)->f = (o)->f; \
	  (n)->r = (o); \
	  (o)->f->r = (n); \
	  (o)->f = (n); \
	}

#define LISTPUTBEFORE(o,n,f,r) \
	{ \
	  (n)->r = (o)->r; \
	  (n)->f = (o); \
	  (o)->r->f = (n); \
	  (o)->r = (n); \
	}

#define LISTDELETE(e,f,r) \
	{ \
	  (e)->f->r = (e)->r; \
	  (e)->r->f = (e)->f; \
	  (e)->r = (e)->f = e; \
	}
