/*  syncobj.h
 *
 *  $Id$
 *
 *  Synchronization objects.
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
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

#ifndef SYNCOBJ_H
#define SYNCOBJ_H

/*
 * Mutual exclusion synchronization object.
 */
class SyncObj
{
public:

  SyncObj();
  ~SyncObj();

  void EnterCriticalSection();
  void LeaveCriticalSection();

private:

#if DEBUG
  long m_id;
  static long m_last_id;
#endif

  CRITICAL_SECTION critical_section;

  // forbid copying
  SyncObj(const SyncObj&);
  SyncObj& operator=(const SyncObj&);
};

/*
 * An utility class to be used jointly with a SyncObj.  The only good
 * of it is that it calls Leave() on the respective sync object in the
 * destructor.  So it comes in handy when used as an automatic variable
 * in functions that require mutual exclusion.
 *
 * Example:
 *
 * SyncObj obj;
 *
 * void f1()
 * {
 *   CriticalSection cs(obj);
 *   ...
 * }
 *
 * An explicit call to the Leave() method allows to release the sync
 * object before the end of the containing block (it might be desired
 * for the sake of efficiency). The Enter() method allows to reacquire
 * the sync object later on.
 *
 * void f2()
 * {
 *   CriticalSection cs(obj);
 *   ...
 *   cs.Leave();
 *   ...
 * }
 *
 */
class CriticalSection
{
public:

  CriticalSection(SyncObj *obj)
    : entered(false), object(obj)
  {
    Enter();
  }

  ~CriticalSection()
  {
    Leave();
  }

  void Enter();
  void Leave();

private:

  bool entered;
  SyncObj *object;
};


class NotReentrantObj
{
public:

  NotReentrantObj()
  {
    m_iEntranceCnt = 0;
  }

  bool
  EnterNotReentrantObj()
  {
    LONG iEntranceCnt = InterlockedIncrement(&m_iEntranceCnt);
    return (iEntranceCnt == 0);
  }

  void
  LeaveNotReentrantObj()
  {
    InterlockedDecrement(&m_iEntranceCnt);
  }

private:

  LONG m_iEntranceCnt;
};


class EntranceChecker
{
public:

  EntranceChecker(NotReentrantObj* pObj)
  {
    m_pObj = pObj;
    if (m_pObj != NULL)
      m_fCanEnter = m_pObj->EnterNotReentrantObj();
  }

  ~EntranceChecker()
  {
    if (m_pObj != NULL)
      m_pObj->LeaveNotReentrantObj();
  }

  bool
  CanEnter()
  {
    return m_fCanEnter;
  }

private:

  bool m_fCanEnter;
  NotReentrantObj* m_pObj;
};


#endif
