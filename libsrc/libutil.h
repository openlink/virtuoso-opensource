/*
 *  libutil.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef _LIBUTIL_H
#define _LIBUTIL_H

#include "Dk.h"

#include "util/oplthr.h"
#include "util/ncfg.h"
#include "util/getopt.h"
#include "util/logmsg.h"
#include "util/setext.h"
#include "util/startup.h"
#include "util/strfuns.h"
#include "util/regexp.h"
#include "util/uuid.h"
#include "util/utf8funs.h"
#include "util/utalloc.h"
#ifdef IN_LIBUTIL
# define s_realloc	realloc
# define s_strdup(X)	strdup(X)
# define s_alloc	calloc
#endif

#ifdef WIN32
void EndNTApplication (void);
void StartNTApplication (void);
#include "util/win32/syslog.h"
#endif

BEGIN_CPLUSPLUS

void sec_login_digest (char *ses_name, char *user, char *pwd, unsigned char *digest);

END_CPLUSPLUS

#endif
