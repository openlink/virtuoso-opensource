/*
 *  OpenLink Generic OLE DB Provider
 *
 *  asserts.h
 *
 *  $Id$
 *
 *  Assertion Routines
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
 *  
*/

#ifndef _ASSERTS_H_
#define _ASSERTS_H_

//-----------------------------------------------------------------------------
// Debugging macros
//-----------------------------------------------------------------------------

// Ensure "DEBUG" is set if "_DEBUG" is set.
#ifdef _DEBUG
# ifndef DEBUG
#  define DEBUG 1
# endif
#else
# ifndef DEBUG
#  define DEBUG 0
# endif
#endif

// Ensure no previous versions of our macros.
#ifdef  assert
# undef assert
#endif
#ifdef  Assert
# undef Assert
#endif
#ifdef  ASSERT
# undef ASSERT
#endif
#ifdef  TRACE
# undef TRACE
#endif
#ifdef  LOGCALL
# undef LOGCALL
#endif

#if DEBUG

//-----------------------------------------------------------------------------
// Global function prototypes -- helper stuff
//-----------------------------------------------------------------------------

// The assert and trace macros below calls these.
void OLEDB_Assert(LPSTR expression, LPSTR filename, long linenum);
void OLEDB_Trace(const char *szPath, int iLine, const char *format, ...);
void OLEDB_Log(const char *format, ...);
void OLEDB_LogFlat(const char *format, ...);

LPSTR StringFromPropID(REFIID riid, DBPROPID propID);
LPSTR StringFromGuid(REFIID riid);
LPSTR StringFromVariant(const VARIANT& v);

class LogIndent
{
public:

  static int iNesting;

  LogIndent()
  {
    iNesting++;
  }

  ~LogIndent()
  {
    iNesting--;
    clear();
  }

  LPSTR
  StringFromPropID(REFIID riid, DBPROPID propID)
  {
    LPSTR string = ::StringFromPropID(riid, propID);
    return insert(string);
  }

  LPSTR
  StringFromGuid(REFIID rguid)
  {
    LPSTR string = ::StringFromGuid(rguid);
    return insert(string);
  }

  LPSTR StringFromVariant(const VARIANT* variant);

private:

  LPSTR
  insert(LPSTR string)
  {
    LPSTR duplicate = strdup(string);
    if (duplicate == NULL)
      return "?";
    strings.push_front(duplicate);
    return duplicate;
  }

  void
  clear()
  {
    while(!strings.empty())
      {
	LPSTR string = strings.front();
	free(string);
	strings.pop_front();
      }
  }

  std::list<LPSTR> strings;
};

#define assert(x) { if ( ! (x) ) OLEDB_Assert( #x, __FILE__, __LINE__ ); }
#define Assert(x) assert(x)
#define ASSERT(x) assert(x)
#define VERIFY(x) assert(x)
#define TRACE(x)  OLEDB_Trace##x
#define LOG(x)  OLEDB_Log##x
#define LOGFLAT(x)  OLEDB_LogFlat##x
#define LOGCALL(x)  class LogIndent xyzTemp; OLEDB_Log##x
#define STRINGFROMPROPID(x) xyzTemp.StringFromPropID(x)
#define STRINGFROMGUID(x) xyzTemp.StringFromGuid(x)
#define STRINGFROMVARIANT(x) xyzTemp.StringFromVariant(x)
#define DEBUGCODE(p) p

#else // DEBUG

#define assert(x)  ((void)0)
#define Assert(x)  ((void)0)
#define ASSERT(x)  ((void)0)
#define VERIFY(x)  ((void)(x))
#define TRACE(x)
#define LOG(x)
#define LOGFLAT(x)
#define LOGCALL(x)
#define STRINGFROMPROPID(x)
#define STRINGFROMGUID(x)
#define STRINGFROMVARIANT(x)
#define DEBUGCODE(p)

#endif // DEBUG

#endif
