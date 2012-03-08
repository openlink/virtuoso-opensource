/*
 *  ncfg.c
 *
 *  $Id$
 *
 *  New Configuration File Management
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

#include "libutil.h"
#include <fcntl.h>

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

static PCFGENTRY _cfg_poolalloc (PCONFIG p, u_int count);
static int _cfg_parse (PCONFIG pconfig);
static int _cfg_freeent (PCFGENTRY e);
static int _cfg_freeimage (PCONFIG pconfig);
static int _cfg_copyent (PCFGENTRY dst, PCFGENTRY src);
static int _cfg_refresh (PCONFIG pconfig);
static int _cfg_storeentry ( PCONFIG pconfig, char *section, char *id,
    char *value, char *comment, int dynamic);

/*** READ MODULE ****/

#ifndef O_BINARY
#define O_BINARY 0
#endif


int
cfg_init (PCONFIG *ppconf, char *filename)
{
  return cfg_init2 (ppconf, filename, 0);
}


/*
 *  Initialize a configuration
 */
int
cfg_init2 (PCONFIG *ppconf, char *filename, int doCreate)
{
  PCONFIG pconfig;

  *ppconf = NULL;
  if ((pconfig = (PCONFIG) calloc (1, sizeof (TCONFIG))) == NULL)
    return -1;

  pconfig->fileName = strdup (filename);
  if (pconfig->fileName == NULL)
    {
      cfg_done (pconfig);
      return -1;
    }

  OPL_MUTEX_INIT (pconfig->mtx);

  /* If the file does not exist, try to create it */
  if (doCreate && access (pconfig->fileName, 0) == -1)
    {
      FILE *fd = fopen (filename, "a");
      if (fd)
        fclose (fd);
    }

  if (_cfg_refresh (pconfig) == -1)
    {
      cfg_done (pconfig);
      return -1;
    }
  *ppconf = pconfig;

  return 0;
}


/*
 *  Free all data associated with a configuration
 */
int
cfg_done (PCONFIG pconfig)
{
  if (pconfig)
    {
      _cfg_freeimage (pconfig);
      if (pconfig->fileName)
	free (pconfig->fileName);
      OPL_MUTEX_DONE (pconfig->mtx);
      free (pconfig);
    }

  return 0;
}


/*
 *  Free one config entry
 */
static int
_cfg_freeent (PCFGENTRY e)
{
  if (e->flags & CFE_MUST_FREE_SECTION)
    free (e->section);
  if (e->flags & CFE_MUST_FREE_ID)
    free (e->id);
  if (e->flags & CFE_MUST_FREE_VALUE)
    free (e->value);
  if (e->flags & CFE_MUST_FREE_COMMENT)
    free (e->comment);

  return 0;
}


/*
 *  Free the content specific data of a configuration
 */
static int
_cfg_freeimage (PCONFIG pconfig)
{
  char *saveName;
  OPL_MUTEX_DECLARE (saveMtx);

  PCFGENTRY e;
  u_int i;

  if (pconfig->image)
    free (pconfig->image);
  if (pconfig->entries)
    {
      e = pconfig->entries;
      for (i = 0; i < pconfig->numEntries; i++, e++)
	_cfg_freeent (e);
      free (pconfig->entries);
    }

  saveName = pconfig->fileName;
  saveMtx = pconfig->mtx;
  memset (pconfig, 0, sizeof (TCONFIG));
  pconfig->fileName = saveName;
  pconfig->mtx = saveMtx;

  return 0;
}


static int
_cfg_copyent (PCFGENTRY dst, PCFGENTRY src)
{
  memset (dst, 0, sizeof (TCFGENTRY));
  if (src->section)
    {
      dst->section = strdup (src->section);
      dst->flags |= CFE_MUST_FREE_SECTION;
    }
  if (src->id)
    {
      dst->id = strdup (src->id);
      dst->flags |= CFE_MUST_FREE_ID;
    }
  if (src->value)
    {
      dst->value = strdup (src->value);
      dst->flags |= CFE_MUST_FREE_VALUE;
    }
  if (src->comment)
    {
      dst->comment = strdup (src->comment);
      dst->flags |= CFE_MUST_FREE_COMMENT;
    }

  return 0;
}


/*
 *  This procedure reads an copy of the file into memory
 *  caching the content based on stat and MD5sum
 */
static int
_cfg_refresh (PCONFIG pconfig)
{
  digest_t digest;
  MD5_CTX md5ctx;
  struct stat sb;
  char *mem;
  int fd;

  if (pconfig == NULL || stat (pconfig->fileName, &sb) == -1)
    return -1;

  /*
   *  If our image is dirty, ignore all local changes
   *  and force a reread of the image, thus ignoring all mods
   */
  if (pconfig->dirty)
    _cfg_freeimage (pconfig);

  /*
   *  Check to see if our incore image is still valid
   */
  if (pconfig->image &&
      (size_t) sb.st_size == pconfig->size &&
      sb.st_mtime == pconfig->mtime)
    {
      return 0;
    }

  /*
   *  Now read the full image
   */
  if ((fd = open (pconfig->fileName, O_RDONLY|O_BINARY)) == -1)
    return -1;

  mem = (char *) malloc (sb.st_size + 1);
  if (mem == NULL || read (fd, mem, sb.st_size) != sb.st_size)
    {
      free (mem);
      close (fd);
      return -1;
    }
  mem[sb.st_size] = 0;

  close (fd);

  /*
   *  Check the MD5 sum to see if the file has changed
   */
  MD5Init (&md5ctx);
  MD5Update (&md5ctx, (unsigned char *) mem, (unsigned int) sb.st_size);
  MD5Final (digest, &md5ctx);

  if (!memcmp (digest, pconfig->digest, sizeof (digest_t)))
    {
      free (mem);
      return 0;
    }

  /*
   *  Store the new copy
   */
  _cfg_freeimage (pconfig);
  memcpy (pconfig->digest, digest, sizeof (digest_t));
  pconfig->image = mem;
  pconfig->size = sb.st_size;
  pconfig->mtime = sb.st_mtime;

  if (_cfg_parse (pconfig) == -1)
    {
      _cfg_freeimage (pconfig);
      return -1;
    }

  return 1;
}


int
cfg_refresh (PCONFIG pconfig)
{
  int rc;

  if (pconfig == NULL)
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc = _cfg_refresh (pconfig);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return rc;
}


#define iseolchar(C) (strchr ("\n\r\032", C) != NULL)
#define iswhite(C) (strchr ("\f\t ", C) != NULL)


static char *
_cfg_skipwhite (char *s)
{
  while (*s && iswhite (*s))
    s++;
  return s;
}


static int
_cfg_getline (char **pCp, char **pLinePtr)
{
  char *start;
  char *cp = *pCp;

  while (*cp && iseolchar (*cp))
    cp++;
  start = cp;
  if (pLinePtr)
    *pLinePtr = cp;

  while (*cp && !iseolchar (*cp))
    cp++;
  if (*cp)
    {
      *cp++ = 0;
      *pCp = cp;

      while (--cp >= start && iswhite (*cp))
	;
      cp[1] = 0;
    }
  else
    *pCp = cp;

  return *start ? 1 : 0;
}


/*
 *  Parse the in-memory copy of the configuration data
 */
static int
_cfg_parse (PCONFIG pconfig)
{
  char *imgPtr;
  char *endPtr;
  char *lp;
  int isContinue;
  int inString;
  char *section;
  char *id;
  char *value;
  char *comment;

  if (cfg_valid (pconfig))
    return 0;

  endPtr = pconfig->image + pconfig->size;
  for (imgPtr = pconfig->image; imgPtr < endPtr;)
    {
      if (!_cfg_getline (&imgPtr, &lp))
        continue;

      section = NULL;
      id = NULL;
      value = NULL;
      comment = NULL;

      /*
       *  Skip leading spaces
       */
      if (iswhite (*lp))
        {
	  lp = _cfg_skipwhite (lp);
	  isContinue = 1;
	}
      else
        isContinue = 0;

      /*
       *  Parse Section
       */
      if (*lp == '[')
        {
	  section = _cfg_skipwhite (lp + 1);
	  if ((lp = strchr (section, ']')) == NULL)
	    continue;
	  *lp++ = 0;
	  if (rtrim (section) == NULL)
	    {
	      section = NULL;
	      continue;
	    }
	  lp = _cfg_skipwhite (lp);
	}
      else if (*lp != ';')
        {
	  /* Try to parse
	   *   1. Key = Value
	   *   2. Value (iff isContinue)
	   */
	  if (!isContinue)
	    {
	      /* Parse `<Key> = ..' */
	      id = lp;
	      if ((lp = strchr (id, '=')) == NULL)
	        continue;
	      *lp++ = 0;
	      rtrim (id);
	      lp = _cfg_skipwhite (lp);
	    }

	  /* Parse value */
	  inString = 0;
	  value = lp;
	  while (*lp)
	    {
	      if (inString)
	        {
		  if (*lp == inString)
		    inString = 0;
		}
	      else if (*lp == '"' || *lp == '\'')
	        inString = *lp;
	      else if (*lp == ';' && iswhite (lp[-1]))
	        {
		  *lp = 0;
		  comment = lp + 1;
		  rtrim (value);
		  break;
		}
	      lp++;
	    }
	}

      /*
       *  Parse Comment
       */
      if (*lp == ';')
        comment = lp + 1;

      if (_cfg_storeentry (pconfig, section, id, value, comment, 0) == -1)
        {
	  pconfig->dirty = 1;
	  return -1;
	}
    }

  pconfig->flags |= CFG_VALID;

  return 0;
}


static int
_cfg_storeentry (
    PCONFIG pconfig,
    char *section,
    char *id,
    char *value,
    char *comment,
    int dynamic)
{
  TCFGENTRY newentry;
  PCFGENTRY data;

  if ((data = _cfg_poolalloc (pconfig, 1)) == NULL)
    return -1;

  newentry.section = section;
  newentry.id = id;
  newentry.value = value;
  newentry.comment = comment;
  newentry.flags = 0;

  if (dynamic)
    _cfg_copyent (data, &newentry);
  else
    *data = newentry;

  return 0;
}


int
cfg_storeentry (
    PCONFIG pconfig,
    char *section,
    char *id,
    char *value,
    char *comment,
    int dynamic)
{
  int rc;

  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc = _cfg_storeentry (pconfig, section, id, value, comment, dynamic);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return rc;
}


static PCFGENTRY
_cfg_poolalloc (PCONFIG p, u_int count)
{
  PCFGENTRY newBase;
  u_int newMax;

  if (p->numEntries + count > p->maxEntries)
    {
      newMax = p->maxEntries ? count + p->maxEntries + p->maxEntries / 2
                        : count + 4096 / sizeof (TCFGENTRY);
      newBase = (PCFGENTRY) malloc (newMax * sizeof (TCFGENTRY));
      if (newBase == NULL)
        return NULL;
      if (p->entries)
        {
	  memcpy (newBase, p->entries, p->numEntries * sizeof (TCFGENTRY));
	  free (p->entries);
	}
      p->entries = newBase;
      p->maxEntries = newMax;
    }

  newBase = &p->entries[p->numEntries];
  p->numEntries += count;

  return newBase;
}


/*** COMPATIBILITY LAYER ***/

static void
_cfg_rewind (PCONFIG pconfig)
{
  pconfig->flags = CFG_VALID;
  pconfig->cursor = 0;
}


int
cfg_rewind (PCONFIG pconfig)
{
  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  _cfg_rewind (pconfig);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return 0;
}


/*
 *  returns:
 *	 0 success
 *	-1 no next entry
 *
 *	section	id	value	flags		meaning
 *	!0	0	!0	SECTION		[value]
 *	!0	!0	!0	DEFINE		id = value|id="value"|id='value'
 *	!0	0	!0	0		value
 *	0	0	0	EOF		end of file encountered
 */
static int
_cfg_nextentry (PCONFIG pconfig)
{
  PCFGENTRY e;

  if (!cfg_valid (pconfig) || cfg_eof (pconfig))
    return -1;

  pconfig->flags &= ~(CFG_TYPEMASK);
  pconfig->id = pconfig->value = NULL;

  while (1)
    {
      if (pconfig->cursor >= pconfig->numEntries)
	{
	  pconfig->flags |= CFG_EOF;
	  return -1;
	}
      e = &pconfig->entries[pconfig->cursor++];

      if (e->section)
	{
	  pconfig->section = e->section;
	  pconfig->flags |= CFG_SECTION;
	  return 0;
	}
      if (e->value)
	{
	  pconfig->value = e->value;
	  if (e->id)
	    {
	      pconfig->id = e->id;
	      pconfig->flags |= CFG_DEFINE;
	    }
	  else
	    pconfig->flags |= CFG_CONTINUE;
	  return 0;
	}
    }
}


int
cfg_nextentry (PCONFIG pconfig)
{
  int rc;

  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc  = _cfg_nextentry (pconfig);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return rc;
}


static int
_cfg_find (PCONFIG pconfig, char *section, char *id)
{
  int atsection;

  atsection = 0;
  _cfg_rewind (pconfig);
  while (_cfg_nextentry (pconfig) == 0)
    {
      if (atsection)
	{
	  if (cfg_section (pconfig))
	    return -1;
	  else if (cfg_define (pconfig) && !stricmp (pconfig->id, id))
	    return 0;
	}
      else if (cfg_section (pconfig) && !stricmp (pconfig->section, section))
	{
	  if (id == NULL)
	    return 0;
	  atsection = 1;
	}
    }
  return -1;
}


int
cfg_find (PCONFIG pconfig, char *section, char *id)
{
  int rc;

  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc = _cfg_find (pconfig, section, id);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return rc;
}


static int
_cfg_merge (PCONFIG pconfig, PCONFIG psrc)
{
  PCFGENTRY e, ee, es, es2, ei;
  PCFGENTRY d, de, ds, ds2, di, di2;
  PCFGENTRY x;
  int delta;
  int numSrc;

  e = psrc->entries;
  ee = e + psrc->numEntries;
  while (e < ee)
    {
      /* locate es - next section in source */
      if (!e->section)
	{
	  e++;
	  continue;
	}
      es = e;

      /* locate es2 - next section after es */
      while (++e < ee)
	if (e->section)
	  break;
      es2 = e;

      /* preallocate worst-case. This ensures all pointers remain valid */
      _cfg_poolalloc (pconfig, (u_int) (es2 - es));
      pconfig->numEntries -= (u_int) (es2 - es);

      d = pconfig->entries;
      de = d + pconfig->numEntries;

      /* locate ds - start of corresponding section in target */
      for (ds = NULL; d < de; d++)
	if (d->section && !stricmp (d->section, es->section))
	  {
	    ds = d;
	    break;
	  }
      if (!ds)
	{
	  /* section not found - append all from source section */
	  x = _cfg_poolalloc (pconfig, (u_int) (es2 - es));
	  for (e = es; e < es2; e++)
	    _cfg_copyent (x++, e);
	  continue;
	}

      /* locate d - next section after ds */
      while (++d < de)
	if (d->section)
	  break;
      ds2 = d;

      /* process all entries in current source section */
      for (ei = es + 1; ei < es2;)
	{
	  /* locate ei - next id in source */
	  if (!ei->id)
	    {
	      ei++;
	      continue;
	    }

	  /* count # lines of it */
	  for (numSrc = 1; ei + numSrc < es2; numSrc++)
	    if (ei[numSrc].id)
	      break;

	  /* locate di - corresponding id in target */
	  for (di = ds + 1; di < ds2; di++)
	    if (di->id && !stricmp (di->id, ei->id))
	      break;

	  if (di == ds2)
	    {
	      /* not found */
	      di2 = di;
	      delta = numSrc;	/* # entries target grows */
	    }
	  else
	    {
	      /* found - find the # lines spawning it */
	      _cfg_freeent (di);
	      for (di2 = di + 1; di2 < ds2; di2++)
		if (di2->section || di2->id)
		  break;
		else
		  _cfg_freeent (di2);
	      delta = (int) (numSrc - (di2 - di));
	    }

	  _cfg_poolalloc (pconfig, delta);
	  memmove (di2 + delta, di2, (de - di2) * sizeof (TCFGENTRY));
	  while (numSrc--)
	    _cfg_copyent (di++, ei++);
	  de += delta;
	  ds2 += delta;
	}
    }
  pconfig->dirty = 1;

  return 0;
}


int
cfg_merge (PCONFIG pconfig, PCONFIG src)
{
  int rc;

  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc = _cfg_merge (pconfig, src);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return rc;
}


/*** WRITE MODULE ****/


/*
 *  Change the configuration
 *
 *  section id    value		action
 *  --------------------------------------------------------------------------
 *   value  value value		update '<entry>=<string>' in section <section>
 *   value  value NULL		delete '<entry>' from section <section>
 *   value  NULL  NULL		delete section <section>
 */
static int
_cfg_write (PCONFIG pconfig, char *section, char *id, char *value)
{
  PCFGENTRY e, e2, eSect;
  size_t idx;
  int i;

  if (section == NULL)
    return -1;

  /* find the section */
  e = pconfig->entries;
  i = pconfig->numEntries;
  eSect = 0;
  while (i--)
    {
      if (e->section && !stricmp (e->section, section))
        {
	  eSect = e;
	  break;
	}
      e++;
    }

  /* did we find the section? */
  if (!eSect)
    {
      /* check for delete operation on a nonexisting section */
      if (!id || !value)
        return 0;

      /* add section first */
      if (_cfg_storeentry (pconfig, section, NULL, NULL, NULL, 1) == -1 ||
          _cfg_storeentry (pconfig, NULL, id, value, NULL, 1) == -1)
	return -1;

      pconfig->dirty = 1;
      return 0;
    }

  /* ok - we have found the section - let's see what we need to do */

  if (id)
    {
      if (value)
	{
	  /* add / update a key */
	  while (i--)
	    {
	      e++;
	      /* break on next section */
	      if (e->section)
	        {
		  /* insert new entry before e */
		  idx = e - pconfig->entries;
		  if (_cfg_poolalloc (pconfig, 1) == NULL)
		    return -1;
		  e = &pconfig->entries[idx];
		  memmove (e + 1, e,
		      (pconfig->numEntries - idx - 1) * sizeof (TCFGENTRY));
		  e->section = NULL;
		  e->id = strdup (id);
		  e->value = strdup (value);
		  e->comment = NULL;
		  if (e->id == NULL || e->value == NULL)
		    return -1;
		  e->flags = CFE_MUST_FREE_ID | CFE_MUST_FREE_VALUE;
		  pconfig->dirty = 1;
		  return 0;
		}
	      if (e->id && !stricmp (e->id, id))
	        {
		  /* found key - do update */
		  if (e->value && (e->flags & CFE_MUST_FREE_VALUE))
		    {
		      e->flags &= ~CFE_MUST_FREE_VALUE;
		      free (e->value);
		    }
		  pconfig->dirty = 1;
		  if ((e->value = strdup (value)) == NULL)
		    return -1;
		  e->flags |= CFE_MUST_FREE_VALUE;
		  return 0;
		}
	    }

	  /* last section in file - add new entry */
	  if (_cfg_storeentry (pconfig, NULL, id, value, NULL, 1) == -1)
	    return -1;
	  pconfig->dirty = 1;
	  return 0;
	}
      else
	{
	  /* delete a key */
	  while (i--)
	    {
	      e++;
	      /* break on next section */
	      if (e->section)
	        return 0; /* not found */

	      if (e->id && !stricmp (e->id, id))
	        {
		  /* found key - do delete */
		  eSect = e;
		  e++;
		  goto doDelete;
		}
	    }
	  /* key not found - that' ok */
	  return 0;
	}
    }
  else
    {
      /* delete entire section */

      /* find e : next section */
      while (i--)
	{
	  e++;
	  /* break on next section */
	  if (e->section)
	    break;
	}
      if (i < 0)
        e++;

      /* move up e while comment */
      e2 = e - 1;
      while (e2->comment && !e2->section && !e2->id && !e2->value
	     && (iswhite (e2->comment[0]) || e2->comment[0] == ';'))
	e2--;
      e = e2 + 1;

    doDelete:
      /* move up eSect while comment */
      e2 = eSect - 1;
      while (e2->comment && !e2->section && !e2->id && !e2->value
	     && (iswhite (e2->comment[0]) || e2->comment[0] == ';'))
	e2--;
      eSect = e2 + 1;

      /* delete everything between eSect .. e */
      for (e2 = eSect; e2 < e; e2++)
	_cfg_freeent (e2);
      idx = e - pconfig->entries;
      memmove (eSect, e, (pconfig->numEntries - idx) * sizeof (TCFGENTRY));
      pconfig->numEntries -= (u_int) (e - eSect);
      pconfig->dirty = 1;
    }

  return 0;
}


int
cfg_write (PCONFIG pconfig, char *section, char *id, char *value)
{
  int rc;

  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc = _cfg_write (pconfig, section, id, value);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return rc;
}


static int
_cfg_digestprintf (MD5_CTX *pMd5, FILE *fd, char *fmt, ...)
{
  char buf[4096];
  va_list ap;
  size_t length;
  int retValue;

  va_start (ap, fmt);
  vsprintf (buf, fmt, ap);
  length = strlen (buf);
  retValue = fwrite (buf, 1, length, fd) == length ? 0 : -1;
  MD5Update (pMd5, (unsigned char *) buf, (unsigned int) length);
  return retValue;
}


/*
 *  Write a formatted copy of the configuration to a file
 *
 *  This assumes that the inifile has already been parsed
 */
static void
_cfg_outputformatted (PCONFIG pconfig, FILE *fd)
{
  PCFGENTRY e = pconfig->entries;
  int i = pconfig->numEntries;
  int m = 0;
  int j, l;
  int skip = 0;
  MD5_CTX md5ctx;

  MD5Init (&md5ctx);
  while (i--)
    {
      if (e->section)
	{
	  /* Add extra line before section, unless comment block found */
	  if (skip)
	    _cfg_digestprintf (&md5ctx, fd, "\n");

	  _cfg_digestprintf (&md5ctx, fd, "[%s]", e->section);
	  if (e->comment)
	    _cfg_digestprintf (&md5ctx, fd, "\t;%s", e->comment);

	  /* Calculate m, which is the length of the longest key */
	  m = 0;
	  for (j = 1; j <= i; j++)
	    {
	      if (e[j].section)
		break;
	      if (e[j].id && (l = (int) strlen (e[j].id)) > m)
		m = l;
	    }

	  /* Add an extra lf next time around */
	  skip = 1;
	}
      /*
       *  Key = value
       */
      else if (e->id && e->value)
	{
	  if (m)
	    _cfg_digestprintf (&md5ctx, fd, "%-*.*s = %s", m, m, e->id,
	        e->value);
	  else
	    _cfg_digestprintf (&md5ctx, fd, "%s = %s", e->id, e->value);
	  if (e->comment)
	    _cfg_digestprintf (&md5ctx, fd, "\t;%s", e->comment);
	}
      /*
       *  Value only (continuation)
       */
      else if (e->value)
	{
	  _cfg_digestprintf (&md5ctx, fd, "  %s", e->value);
	  if (e->comment)
	    _cfg_digestprintf (&md5ctx, fd, "\t;%s", e->comment);
	}
      /*
       *  Comment only - check if we need an extra lf
       *
       *  1. Comment before section gets an extra blank line before
       *     the comment starts.
       *
       *          previousEntry = value
       *          <<< INSERT BLANK LINE HERE >>>
       *          ; Comment Block
       *          ; Sticks to section below
       *          [new section]
       *
       *  2. Exception on 1. for commented out definitions:
       *     (Immediate nonwhitespace after ;)
       *          [some section]
       *          v1 = 1
       *          ;v2 = 2   << NO EXTRA LINE >>
       *          v3 = 3
       *
       *  3. Exception on 2. for ;; which certainly is a section comment
       *          [some section]
       *          definitions
       *          <<< INSERT BLANK LINE HERE >>>
       *          ;; block comment
       *          [new section]
       */
      else if (e->comment)
	{
	  if (skip && (iswhite (e->comment[0]) || e->comment[0] == ';'))
	    {
	      for (j = 1; j <= i; j++)
		{
		  if (e[j].section)
		    {
		      _cfg_digestprintf (&md5ctx, fd, "\n");
		      skip = 0;
		      break;
		    }
		  if (e[j].id || e[j].value)
		    break;
		}
	    }
	  _cfg_digestprintf (&md5ctx, fd, ";%s", e->comment);
	}
      _cfg_digestprintf (&md5ctx, fd, "\n");
      e++;
    }
  MD5Final (pconfig->digest, &md5ctx);
}


/*
 *  Write the changed file back
 */
static int
_cfg_commit (PCONFIG pconfig)
{
  FILE *fd;

  if (pconfig->dirty)
    {
      if ((fd = fopen (pconfig->fileName, "w")) == NULL)
	return -1;

      _cfg_outputformatted (pconfig, fd);

      fclose (fd);

      pconfig->dirty = 0;
    }

  return 0;
}


int
cfg_commit (PCONFIG pconfig)
{
  int rc;

  if (!cfg_valid (pconfig))
    return -1;

  OPL_MUTEX_LOCK (pconfig->mtx);
  rc = _cfg_commit (pconfig);
  OPL_MUTEX_UNLOCK (pconfig->mtx);

  return 0;
}

