/*
 *  kvlist.cpp
 *
 *  $Id$
 *
 *  Key/Value pair matching for DSN parsing
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
 */

#include "w32util.h"
#include "kvlist.h"


#define MAXPAIRS	100


TKVList::index_t
TKVList::Find (LPCTSTR key)
{
  index_t i;

  for (i = 0; i < numPairs; i++)
    if (!_tcsicmp (pairs[i].key, key))
      return i;

  return NOT_FOUND;
}


TKVList::index_t
TKVList::Define (LPCTSTR key, LPCTSTR value)
{
  index_t pos;

  if (key == NULL)
    return NOT_FOUND;

  pos = Find (key);
  if (pos != NOT_FOUND)
    {
      if (pairs[pos].value)
        {
	  dsize -= 1 + _tcslen (pairs[pos].value);
          free (pairs[pos].value);
	}
      goto set_it;
    }

  if (numPairs + 1 >= maxPairs)
    {
      TKVPair *newPairs = (TKVPair *) malloc ((maxPairs + 20) * sizeof (TKVPair));
      if (newPairs == NULL)
        return NOT_FOUND;
      memset (newPairs, 0, (maxPairs + 20) * sizeof (TKVPair));
      memcpy (newPairs, pairs, numPairs * sizeof (TKVPair));
      if (pairs)
        free (pairs);
      pairs = newPairs;
      maxPairs += 20;
    }
  pos = numPairs++;
  pairs[pos].key = _tcsdup (key);
  dsize += 1 + _tcslen (key);

set_it:
  if (value)
    {
      pairs[pos].value = _tcsdup (value);
      dsize += 1 + _tcslen (value);
    }
  else
    pairs[pos].value = NULL;

  return pos;
}


void
TKVList::Undefine (LPCTSTR key)
{
  index_t pos;
  TKVPair *p;

  if ((pos = Find (key)) == NOT_FOUND)
    return;

  p = &pairs[pos];
  dsize -= 1 + _tcslen (p->key);
  free (p->key);
  if (p->value)
    {
      dsize -= 1 + _tcslen (p->value);
      free (p->value);
    }

  memcpy (p, p + 1, (--numPairs - pos) * sizeof (TKVPair));
}


void
TKVList::Merge (TKVList &l)
{
  index_t i;

  for (i = 0; i < l.Count (); i++)
     Define (l.Key (i), l.Value (i));
}


void
TKVList::ReadODBCIni (LPCTSTR section, LPCTSTR names)
{
  TCHAR value[512];
  LPCTSTR key;

  for (key = names; *key; key += _tcslen (key) + 1)
    {
      SQLGetPrivateProfileString (section, key, _T(" "), value,
	  NUMCHARS (value), _T("odbc.ini"));
      if (_tcscmp (value, _T(" ")))
	Define (key, value);
    }
}


void
TKVList::WriteODBCIni (LPCTSTR section, LPCTSTR names)
{
  LPCTSTR key;

  for (key = names; *key; key += _tcslen (key) + 1)
    {
      SQLWritePrivateProfileString (section,
	  key, Value (key), _T("odbc.ini"));
    }
}


void
TKVList::ReadFileDSN (LPCTSTR filename, LPCTSTR names)
{
  TCHAR value[512];
  LPCTSTR key;
  WORD len;

  for (key = names; *key; key += _tcslen (key) + 1)
    {
      value[0] = 0;
      if (SQLReadFileDSN (filename, _T("ODBC"), key, value,
	  NUMCHARS (value), &len))
	{
	  Define (key, value);
	}
    }
}


void
TKVList::WriteFileDSN (LPCTSTR filename, LPCTSTR names)
{
  LPCTSTR key;

  for (key = names; *key; key += _tcslen (key) + 1)
    SQLWriteFileDSN (filename, _T("ODBC"), key, Value (key));
}


void
TKVList::FromDSN (LPCTSTR szIn)
{
  TCHAR *index[MAXPAIRS];
  TCHAR *dsn;
  TCHAR *cp;
  int count;
  int i;
  TCHAR *tok;

  if ((dsn = _tcsdup (szIn)) == NULL)
    return;

  count = 0;
  int found = 0;
  int br = 0;
  for (tok = cp = dsn; *cp != 0 && count < MAXPAIRS; cp++)
    switch (*cp)
      {
      case ';':		// found token
	if (br == 0)
	  {
	    *cp = 0;
	    index[count++] = tok;
	    tok = cp + 1;
	  }
	break;
      case '{':
	br++;
	break;
      case '}':
	br--;
	break;
      }
  if (tok < cp && *cp == 0 && count < MAXPAIRS)
    {
      index[count++] = tok;
    }

  for (i = 0; i < count; i++)
    {
      LPCTSTR key = index[i];
      PTSTR value;

      if ((value = (PTSTR)_tcschr (key, '=')) != NULL)
	{
	  *value = 0;
	  value++;
	}
      Define (key, value);
    }

  free (dsn);
}


PTSTR
TKVList::ToDSN (void)
{
  index_t i;
  PTSTR base;
  PTSTR cp;
  PTSTR s;

  cp = base = (PTSTR) malloc (dsize * sizeof (TCHAR));
  if (base != NULL)
    {
      for (i = 0; i < numPairs; i++)
        {
          for (s = pairs[i].key; *cp = *s++; cp++)
            ;
          if ((s = pairs[i].value) != NULL)
            {
	      *cp++ = '=';
	      for (; *cp = *s++; cp++)
		;
	    }
	  if (i < numPairs - 1)
	    *cp++ = ';';
	}
    }

  return base;
}

void
TKVList::FromAttributes (LPCTSTR szIn)
{
  LPCTSTR cp;
  LPCTSTR tok;
  TCHAR keyBuf[128];
  TCHAR valueBuf[128];
  int count = 0;

  if ( *szIn != 0)
    {
      tok = cp = szIn;
      do
        {
          cp++;
          if (*cp == 0) //found token
            {
              LPCTSTR cp2 = _tcschr (tok, '=');
              if (cp2)
                {
                  _tcsncpy (keyBuf, tok, cp2 - tok);
                  keyBuf[cp2 - tok] = 0;
                  tok = cp2 + 1;
                  _tcscpy (valueBuf, tok);
                  Define (keyBuf, valueBuf);
                  count++;
                }
              tok = cp + 1;
            }
        }
      while ( !(*cp == 0 && *(cp + 1) == 0) && count < MAXPAIRS);
    }
}

void
TKVList::Empty (void)
{
  index_t i;

  for (i = 0; i < numPairs; i++)
    {
      free (pairs[i].key);
      if (pairs[i].value)
        free (pairs[i].value);
    }

  if (pairs)
    free (pairs);

  maxPairs = 0;
  numPairs = 0;
  dsize = 0;
  pairs = NULL;
}
