/*  syncobj.cpp
 *
 *  $Id$
 *
 *  Synchronization objects.
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

#include "headers.h"
#include "asserts.h"
#include "syncobj.h"

/**********************************************************************/
/* SyncObj                                                            */

#if DEBUG
long SyncObj::m_last_id = 0;
#endif

SyncObj::SyncObj()
{
#if DEBUG
  m_id = ++m_last_id;
#endif

  LOGCALL(("%s::SyncObj() %d\n", typeid(*this).name(), m_id));

  ::InitializeCriticalSection(&critical_section);
}

SyncObj::~SyncObj()
{
  LOGCALL(("%s::~SyncObj() %d\n", typeid(*this).name(), m_id));

  ::DeleteCriticalSection(&critical_section);
}

void
SyncObj::EnterCriticalSection()
{
  LOGCALL(("%s::EnterCriticalSection() %d\n", typeid(*this).name(), m_id));

  ::EnterCriticalSection(&critical_section);
}

void
SyncObj::LeaveCriticalSection()
{
  LOGCALL(("%s::LeaveCriticalSection() %d\n", typeid(*this).name(), m_id));

  ::LeaveCriticalSection(&critical_section);
}

/**********************************************************************/
/* CriticalSection                                                    */

void
CriticalSection::Enter()
{
  if (object == NULL)
    return;

  if (!entered)
    {
      entered = true;
      object->EnterCriticalSection();
    }
}

void
CriticalSection::Leave()
{
  if (object == NULL)
    return;

  if (entered)
    {
      entered = false;
      object->LeaveCriticalSection();
    }
}
