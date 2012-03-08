/*
 *  kvlist.h
 *
 *  $Id$
 *
 *  Key/Value pair matching for DSN parsing
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
 */

#ifndef _KVLIST_H
#define _KVLIST_H

#define NOT_FOUND	((TKVList::index_t) -1)

class TKVList
  {
  public:
    typedef unsigned int index_t;

    void		Empty (void);

    index_t		Find (LPCTSTR key);
    index_t		Define (LPCTSTR key, LPCTSTR value);
    void		Undefine (LPCTSTR key);

    index_t		Count (void);
    LPCTSTR 		Key (index_t index);
    LPCTSTR 		Value (index_t index);
    LPCTSTR 		Value (LPCTSTR key);
    int			Get (LPCTSTR key, PTSTR value, int maxlen);

    void		Merge (TKVList &l);
    void		ReadODBCIni (LPCTSTR section, LPCTSTR names);
    void		WriteODBCIni (LPCTSTR section, LPCTSTR names);
    void		ReadFileDSN (LPCTSTR filename, LPCTSTR names);
    void		WriteFileDSN (LPCTSTR filename, LPCTSTR names);

    void		FromDSN (LPCTSTR szIn);
    void		FromAttributes (LPCTSTR szIn);
    PTSTR		ToDSN (void);
    index_t		DSize (void);

    TKVList ();
    ~TKVList ();

  protected:
    struct TKVPair
      {
	PTSTR key;
	PTSTR value;
      };

    TKVPair *pairs;
    index_t numPairs;
    index_t maxPairs;
    index_t dsize;
  };

inline TKVList::index_t
TKVList::Count (void)
{
  return numPairs;
}


inline TKVList::index_t
TKVList::DSize (void)
{
  return dsize;
}


inline LPCTSTR
TKVList::Key (index_t index)
{
  return index < numPairs ? pairs[index].key : NULL;
}


inline LPCTSTR
TKVList::Value (index_t index)
{
  return index < numPairs ? pairs[index].value : NULL;
}


inline LPCTSTR
TKVList::Value (LPCTSTR key)
{
  index_t index = Find (key);
  return index < numPairs ? pairs[index].value : NULL;
}


inline int
TKVList::Get (LPCTSTR key, PTSTR value, int maxlen)
{
  index_t index = Find (key);
  LPCTSTR v;

  if (index < numPairs && (v = pairs[index].value) != NULL)
    {
      int len = _tcslen (v);
      if (len < maxlen)
        {
	  memcpy (value, v, len * sizeof (TCHAR));
	  value[len] = 0;
	  return len;
	}
    }

  value[0] = 0;
  return 0;
}


inline
TKVList::TKVList ()
{
  numPairs = 0;
  maxPairs = 0;
  pairs = NULL;
  dsize = 0;
}


inline
TKVList::~TKVList ()
{
  Empty ();
}
#endif
