/*
 *  iodbcinst.c
 *
 *  $Id$
 *
 *  Minimum set of ODBC Installer code to allow Virtuoso to edit odbc.ini
 *  udbc.ini and odbcinst.ini files
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
 */

/*
 * Just so the object file is not empty
 */
#if 0
static char _iodbcinst_version[] = "";
#endif

#if !defined (WIN32)

#include "odbcinc.h"
#include "libutil.h"
#include <pwd.h>

#if 0
#define Debug(X)	log_info X
#else
#define Debug(X)
#endif

/*
 *  Limits and Constants
 */
#define ERROR_NUM	 8
#define MAX_ENTRIES	 1024
#define INTERNAL_SECTIONS \
  "UDBC,ODBC,Communications,Protocol TCP,Protocol SPX,Protocol DECNET,Default"

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE 1
#endif



/*
 *  Global variables
 */
#if defined (UNIX_ODBC)
static PCONFIG cfg_odbc;
static PCONFIG cfg_odbcinst;
#else
static PCONFIG cfg_udbc;
#endif
static int _iodbcinst_initialized = 0;
static int configMode;


/*
 *  iODBCinst error code array and macros
 */
static DWORD ierror[ERROR_NUM] = {0};
static LPSTR errormsg[ERROR_NUM] = {0};
static SQLSMALLINT numerrors = -1;


#define CLEAR_ERROR() \
	numerrors = -1;

#define PUSH_ERROR(error) \
	if(numerrors < ERROR_NUM) \
	  { \
	    ierror[++numerrors] = (error); \
	    errormsg[numerrors] = NULL; \
	  }

#define POP_ERROR(error) \
	if(numerrors != -1) \
	  { \
	    errormsg[numerrors] = NULL; \
	    (error) = ierror[numerrors--]; \
	  }

#define IS_ERROR() \
	(numerrors != -1) ? 1 : 0


/*
 * ----------------------------------------------------------------------
 *  Internal functions
 * ----------------------------------------------------------------------
 */

static void
_iodbcinst_initialize (void)
{
  char *odbcini;
  char *udbcini;
  char *odbcinstini;
  char *ptr;
  char path[256];

  Debug (("_iodbcinst_initialize"));
  _iodbcinst_initialized = 1;

  /*
   *  Find out where odbc.ini resides
   *
   *  1. Check for ODBCINI environment and see if the file is accessible
   *  2. Check for HOME environment variable
   *  3. Check for home directory in /etc/passwd
   *  4. Try to use /etc/odbc.ini
   */
  if ((odbcini = getenv ("ODBCINI")) == NULL || access (odbcini, 4))
    {
      if ((ptr = getenv ("HOME")) == NULL);
      {
	ptr = (char *) getpwuid (getuid ());

	if (ptr != NULL)
	  ptr = ((struct passwd *) ptr)->pw_dir;
      }

      if (ptr != NULL)
	snprintf (path, sizeof (path), "%s/.odbc.ini", ptr);

      if (access (path, 4))
	odbcini = "/etc/odbc.ini";
      else
	odbcini = path;
    }

  /*
   *  Find out where odbcinst.ini resides
   *
   *  1. Check for ODBCINSTINI environment
   *  2. Use /etc/odbcinst.ini
   */
  if ((odbcinstini = getenv ("ODBCINSTINI")) == NULL)
    odbcinstini = "/etc/odbcinst.ini";

  /*
   *  Find out where udbc.ini resides
   *
   *  1. Check for UDBCINI environment
   *  2. Use /etc/udbc.ini
   */
  if ((udbcini = getenv ("UDBCINI")) == NULL)
    udbcini = "/etc/udbc.ini";

#if defined (UNIX_ODBC)
  /*
   *  Try to open the 2 ini files
   */
  if (cfg_init (&cfg_odbc, odbcini))
    log_error ("iodbcinst: Unable to open %s", odbcini);

  if (cfg_init (&cfg_odbcinst, odbcinstini))
    log_error ("iodbcinst: Unable to open %s", odbcinstini);
#else
  if (cfg_init (&cfg_udbc, udbcini))
    log_error ("iodbcinst: Unable to open %s", udbcini);
#endif
}


static int
SortFun (const void *p1, const void *p2)
{
  char **s1 = (char **) p1;
  char **s2 = (char **) p2;

  return stricmp (*s1, *s2);
}


static int
_iodbcinst_argv_to_buf (char **array, int num_elem,
    LPSTR lpszRetBuffer, int cbRetBuffer)
{
  int i, count;
  char *ptr;

  /*
   *  Sort the section names
   */
  if (num_elem > 1)
    qsort (array, num_elem, sizeof (char *), SortFun);

  /*
   *  Initialize the buffer
   */
  count = 0;
  ptr = lpszRetBuffer;
  memset (lpszRetBuffer, '\0', cbRetBuffer);

  /*
   *  Now copy the entries back into the buffer separated by a '\0'
   *  character.
   */
  for (i = 0; i < num_elem; i++)
    {
      int l;

      l = strlen (array[i]) + 1;

      /*
       *  Check if this name will fit into the buffer
       */
      if (count + l + 1 >= cbRetBuffer)
	break;

      memcpy (ptr, array[i], l);
      ptr = ptr + l;
      count = count + l;
    }

  return count;
}


static int
_iodbcinst_read_sections (PCONFIG pCfg,
    LPSTR lpszRetBuffer, int cbRetBuffer)
{
  int count = 0;
  char **array;
  int i, max_elem;

  Debug (("_iodbcinst_read_sections (%p, %p, %d)",
	  pCfg, lpszRetBuffer, cbRetBuffer));

  /*
   *  Initialize
   */
  i = 0, max_elem = 0;
  array = (char **) calloc (MAX_ENTRIES, sizeof (char *));
  if (array == NULL)
    {
      PUSH_ERROR (ODBC_ERROR_OUT_OF_MEM);
      return 0;
    }

  /*
   *  Read all section names into array
   */
  cfg_rewind (pCfg);
  while (i < MAX_ENTRIES && cfg_nextentry (pCfg) == 0)
    {
      if (cfg_section (pCfg) &&
#if !defined (UNIX_ODBC)
	  strindex (INTERNAL_SECTIONS, pCfg->section) == 0 &&
#endif
	  (array[i++] = strdup (pCfg->section)) == NULL)
	{
	  PUSH_ERROR (ODBC_ERROR_OUT_OF_MEM);
	  goto done;
	}
    }
  max_elem = i;

  /*
   *  Copy the information back into the buffer.
   */
  count = _iodbcinst_argv_to_buf (array, max_elem, lpszRetBuffer, cbRetBuffer);

done:
  if (array)
    {
      for (i = 0; i < max_elem; i++)
	if (array[i])
	  free (array[i]);
      free (array);
    }
  return count;
}


static int
_iodbcinst_read_keys (PCONFIG pCfg,
    LPSTR lpszSection, LPSTR lpszRetBuffer, int cbRetBuffer)
{
  int count = 0;
  char **array;
  int i, max_elem = 0;

  Debug (("_iodbcinst_read_keys (%p, %s, %p, %d)",
	  pCfg, lpszSection, lpszRetBuffer, cbRetBuffer));

  /*
   *  Initialize
   */
  i = 0, max_elem = 0;
  array = (char **) calloc (MAX_ENTRIES, sizeof (char *));

  if (array == NULL)
    {
      PUSH_ERROR (ODBC_ERROR_OUT_OF_MEM);
      return 0;
    }

  /*
   *  Find the section we are looking for
   */
  if (cfg_find (pCfg, lpszSection, NULL) != 0)
    {
      PUSH_ERROR (ODBC_ERROR_GENERAL_ERR);
      count = 0;
      goto done;
    }

  while (i < MAX_ENTRIES && cfg_nextentry (pCfg) == 0)
    {
      if (cfg_section (pCfg))
	break;
      array[i++] = strdup (pCfg->id);
    }
  max_elem = i;

  /*
   *  Copy the information back into the buffer.
   */
  count = _iodbcinst_argv_to_buf (array, max_elem, lpszRetBuffer, cbRetBuffer);

done:
  if (array)
    {
      for (i = 0; i < max_elem; i++)
	if (array[i])
	  free (array[i]);
      free (array);
    }
  return count;
}


/*
 * ----------------------------------------------------------------------
 *  External functions
 * ----------------------------------------------------------------------
 */

#ifndef HIDE_CONFLICTING_IODBC_FUNCS

int INSTAPI
SQLGetPrivateProfileString (
    LPCSTR lpszSection,
    LPCSTR lpszEntry,
    LPCSTR lpszDefault,
    LPSTR lpszRetBuffer,
    int cbRetBuffer,
    LPCSTR lpszFilename)
{
  PCONFIG pCfg;
  char *ptr;

  Debug (("SQLGetPrivateProfileString('%s', '%s', '%s', %p, %d, '%s')",
	lpszSection, lpszEntry, lpszDefault, lpszRetBuffer, cbRetBuffer,
	lpszFilename));

  /*
   *  Initialize
   */
  if (!_iodbcinst_initialized)
    _iodbcinst_initialize ();

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

#if defined (UNIX_ODBC)
  /*
   *  Check which ini file to read
   */
  if (!stricmp (lpszFilename, "odbc.ini"))
    pCfg = cfg_odbc;
  else if (!stricmp (lpszFilename, "odbcinst.ini"))
    pCfg = cfg_odbcinst;
  else
    {
      PUSH_ERROR (ODBC_ERROR_GENERAL_ERR);
      return 0;
    }
#else
  /*
   *  UDBC fortunately uses only one file
   */
  pCfg = cfg_udbc;
#endif

  /*
   *  Make sure we use the most up-to-date content
   */
  cfg_refresh (pCfg);

  /*
   *  Check for special cases
   */
  if (lpszSection == NULL)
    {
      /*
       *  If the Section name is NULL then we retrieve all section names
       */
      return _iodbcinst_read_sections (pCfg, lpszRetBuffer, cbRetBuffer);
    }
  else if (lpszEntry == NULL)
    {
      /*
       *  If the Entry name is NULL we retrieve all keys within that section
       */
      return _iodbcinst_read_keys (pCfg, (LPSTR) lpszSection, lpszRetBuffer,
	cbRetBuffer);
    }

  /*
   *  Otherwise we just get the value for that Section/Entry combination
   */
  if (cfg_find (pCfg, (char *) lpszSection, (char *) lpszEntry))
    ptr = (char *) lpszDefault;
  else
    ptr = pCfg->value;

  /*
   *  Put the (default) value into the buffer if it will fit
   */
  if (ptr && strlen (ptr) < cbRetBuffer)
    {
      strcpy_size_ck (lpszRetBuffer, ptr, cbRetBuffer);
      return strlen (ptr);
    }

  /*
   *  If all else fails, just signal we returned 0 bytes into the buffer
   */
  return 0;
}

#endif

BOOL INSTAPI
SQLWritePrivateProfileString (
    LPCSTR lpszSection,
    LPCSTR lpszEntry,
    LPCSTR lpszString,
    LPCSTR lpszFilename)
{
  PCONFIG pCfg;

  Debug (("SQLWritePrivateProfileString ('%s', '%s', '%s', '%s')",
	  lpszSection, lpszEntry, lpszString, lpszFilename));

  if (!_iodbcinst_initialized)
    _iodbcinst_initialize ();

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

#if defined (UNIX_ODBC)
  /*
   *  Check which ini file to read
   */
  if (!stricmp (lpszFilename, "odbc.ini"))
    pCfg = cfg_odbc;
  else if (!stricmp (lpszFilename, "odbcinst.ini"))
    pCfg = cfg_odbcinst;
  else
    {
      PUSH_ERROR (ODBC_ERROR_GENERAL_ERR);
      return SQL_FALSE;
    }
#else
  /*
   *  UDBC fortunately uses only one file
   */
  pCfg = cfg_udbc;
#endif

  /*
   *  Write the entry into the correct file
   *
   *  If the String is NULL this will remove the entry from the section
   *  If the Entry is NULL this will remove the entire section
   */
  if (cfg_write (pCfg, (char *) lpszSection, (char *) lpszEntry, (char *) lpszString))
    {
      PUSH_ERROR (ODBC_ERROR_REQUEST_FAILED);
      return SQL_FALSE;
    }

  /*
   *  Commit the changes into the ini file
   */
  if (cfg_commit (pCfg))
    {
      PUSH_ERROR (ODBC_ERROR_REQUEST_FAILED);
      return SQL_FALSE;
    }

  /*
   *  All done
   */
  return SQL_TRUE;
}


BOOL INSTAPI
SQLSetConfigMode (SQLUSMALLINT wConfigMode)
{
  Debug (("SQLSetConfigMode (%d)", wConfigMode));

  if (!_iodbcinst_initialized)
    _iodbcinst_initialize();

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

  switch (wConfigMode)
    {
    case ODBC_BOTH_DSN:
    case ODBC_USER_DSN:
    case ODBC_SYSTEM_DSN:
      configMode = wConfigMode;
      break;

    default:
      PUSH_ERROR (ODBC_ERROR_INVALID_PARAM_SEQUENCE);
      return SQL_FALSE;
    };

  return SQL_TRUE;
}


BOOL INSTAPI
SQLWriteDSNToIni (LPCSTR lpszDSN, LPCSTR lpszDriver)
{
#if defined (UNIX_ODBC)
  char driver[1024];
#endif

  Debug (("SQLWriteDSNToIni ('%s', '%s')", lpszDSN, lpszDriver));

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

#if defined (UNIX_ODBC)
  /*
   *  Get the path to the driver from the odbcinst.ini file
   */
  SQLGetPrivateProfileString (lpszDriver,
	"Driver", "UNKNOWN", driver, sizeof (driver), "odbcinst.ini");

  /*
   *  Add the DSN entry to [ODBC Data Sources]
   */
  SQLWritePrivateProfileString (
	"ODBC Data Sources", lpszDSN, lpszDriver, "odbc.ini");

  /*
   *  Add a new section for this DSN and only fill in the DRIVER key
   *  The rest must be filled in by the application
   */
  SQLWritePrivateProfileString (
	lpszDSN, "DRIVER", driver, "odbc.ini");
#endif

  /*
   *  All done
   */
  return SQL_TRUE;
}


BOOL INSTAPI
SQLRemoveDSNFromIni (LPCSTR lpszDSN)
{
  Debug (("SQLRemoveDSNFromIni ('%s')", lpszDSN));

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

#if defined (UNIX_ODBC)
  /*
   *  First remove the entry in [ODBC Data Sources]
   */
  SQLWritePrivateProfileString ("ODBC Data Sources", lpszDSN, NULL, "odbc.ini");

  /*
   *  Then remove the entire DSN
   */
  SQLWritePrivateProfileString (lpszDSN, NULL, NULL, "odbc.ini");
#else
  /*
   *  Just remove the entire DSN
   */
  SQLWritePrivateProfileString (lpszDSN, NULL, NULL, "udbc.ini");
#endif

  return SQL_TRUE;
}


BOOL INSTAPI
SQLGetInstalledDrivers (LPSTR lpszBuf, WORD cbBufMax, WORD * pcbBufOut)
{
  int count;

  Debug (("SQLGetInstalledDrivers(%p, %d, %p)",
	lpszBuf, cbBufMax, pcbBufOut));

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

#if defined (UNIX_ODBC)
  /*
   *  Return the list of installed drivers
   */
  count = SQLGetPrivateProfileString (
	"ODBC Drivers", NULL, "", lpszBuf, cbBufMax, "odbcinst.ini");
#else
  strncpy (lpszBuf, "OpenLink Generic UDBC Driver", cbBufMax - 1);
  lpszBuf[cbBufMax - 1] = '\0';
  count = strlen (lpszBuf);
#endif

  /*
   *  Return the number of characters in the buffer
   */
  if (pcbBufOut)
    *pcbBufOut = count;

  /*
   *  If something goes wrong this function returns SQL_FALSE and the
   *  Virtuoso VSP page will show:
   *
   *		  This function not supported in current server version
   */
  return count ? SQL_TRUE : SQL_FALSE;
}


/*
 *  This is a stub for now
 */
BOOL INSTAPI
SQLWriteFileDSN (LPCSTR lpszFileName,
    LPCSTR lpszAppName, LPCSTR lpszKeyName, LPSTR lpszString)
{
  Debug (("SQLWriteFileDSN (%s, %s, %s, %s)",
	lpszFileName, lpszAppName, lpszKeyName, lpszString));

  /*
   *  Check input parameters
   */
  CLEAR_ERROR ();

  return SQL_FALSE;
}

#endif /* WIN32 */

