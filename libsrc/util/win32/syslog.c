/*
 *  syslog.c
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
 *  
*/

#include "libutil.h"

#ifdef WIN32
static HANDLE virt_err_log;
char *syslog_instance_name = "";

void
openlog (const char *ident, int option, int facility)
{
  if (!virt_err_log)
    virt_err_log = RegisterEventSource (NULL, ident);
}

void
syslog (int priority, const char *format, ...)
{
  WORD wType, category;
  char buffer[BUFSIZ];
  va_list ap;
  LPCTSTR strs[2] = { buffer, syslog_instance_name };

  if (!virt_err_log)
    return;

  switch (LOG_PRI (priority))
    {
      case LOG_EMERG: wType = EVENTLOG_ERROR_TYPE; category = 1; break;
      case LOG_ALERT: wType = EVENTLOG_ERROR_TYPE; category = 2; break;
      case LOG_CRIT: wType = EVENTLOG_ERROR_TYPE; category = 3; break;
      case LOG_ERR: wType = EVENTLOG_ERROR_TYPE; category = 4; break;
      case LOG_WARNING: wType = EVENTLOG_WARNING_TYPE; category = 5; break;
      case LOG_NOTICE: wType = EVENTLOG_INFORMATION_TYPE; category = 6; break;
      case LOG_INFO: wType = EVENTLOG_INFORMATION_TYPE; category = 7; break;
      case LOG_DEBUG: wType = EVENTLOG_INFORMATION_TYPE; category = 8; break;
      default: wType = EVENTLOG_INFORMATION_TYPE; category = 9; break;
    }

  va_start (ap, format);
#ifdef HAVE_VSNPRINTF
  vsnprintf (buffer, sizeof (buffer), format, ap);
#else
  vsprintf (buffer, format, ap);
#endif
  if (!ReportEvent (
	virt_err_log,
	wType,
	category,
	0x10,
	NULL,
	2,
	0,
	strs,
	NULL))
    return;
}

void
closelog (void)
{
  if (virt_err_log)
    if (DeregisterEventSource (virt_err_log))
      virt_err_log = (HANDLE) NULL;
}
#endif
