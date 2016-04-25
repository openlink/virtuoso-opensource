/*
 *  $Id$
 *
 *  ODBC Mail Dropper
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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


#include <libutil.h>
#include <odbcinc.h>
#include <util/mpl.h>
#include "sysexits.h"		/* from sendmail sources */

#undef  XDEBUG			/* inhouse debugging */

#ifndef WIN32
# define WITH_SYSLOG
#endif

#ifdef WITH_SYSLOG
/* # include <syslog.h> */
# ifndef LOG_MAIL
#  define LOG_MAIL	(2<<3)	/* mail system */
# endif
#endif

/* qmail exit codes */
#define QM_ERR_SUCCESS	99	/* mail delivery done */
#define QM_ERR_HARD	100	/* permanent - mail delivery cannot be done */
#define QM_ERR_TEMP	111	/* temporary - should retry */

#define ismacrostart(x)	(isalnum(x) || x == '_')
#define ismacrocont(x)	(isalnum(x) || x == '_')

char *f_config = NULL;
char *f_sender = NULL;
char *f_local = NULL;
char *f_host = NULL;
char *f_mailer = NULL;
unsigned long log_stat;
int f_debug;
unsigned long log_stat;
void do_mailer (struct pgm_option *opt);

struct pgm_option options[] =
{
  {"config-file", 'c', ARG_STR, &f_config, "configuration file to use"},
  {"local", 'l', ARG_STR, &f_local, "local recipient (for sendmail mode only)"},
  {"host", 'h', ARG_STR, &f_host, "local host/domain (for sendmail mode only)"},
  {"sender", 's', ARG_STR, &f_sender, "envelope sender (for sendmail mode only)"},
  {"mailer", 'm', ARG_FUNC, (void *) do_mailer, "mailer in use"},
  {"debug", 0, ARG_NONE, &f_debug, "debug mode"},
  {0}
};

extern char version[];

struct pgm_info program_info =
{
  NULL,
  version,
  "",
  EXP_RESPONSE,
  options
};

enum
{
  MAILER_UNKNOWN,
  MAILER_SENDMAIL,		/* old sendmail */
  MAILER_QMAIL,			/* qmail */
  MAILER_COURIER,		/* courier */
  MAILER_OPLWIN32		/* only on win32: Paul's maildrop method */
				/* XXX under development XXX */
} mailer;

struct SKVPair;
typedef struct SKVPair TKVPair, *PKVPair;

struct SKVPair
  {
    char *	key;		/* Symbol to define */
    char *	value;		/* Value for this symbol */
    PKVPair	pNext;		/* Next definition in the llist */
  };


SQLHENV henv = SQL_NULL_HENV;
SQLHDBC hdbc = SQL_NULL_HDBC;
SQLHSTMT hstmt = SQL_NULL_HSTMT;
PCONFIG pcfg;
int connected;
PKVPair macros;

char *ExpandMacro (char *str);

/*
 *  For debugging purposes
 *  Note that this also gets into the bounced message
 */
void
Debug (char *fmt, ...)
{
  va_list ap;

  if (f_debug)
    {
      va_start (ap, fmt);
      logmsg_ap (LOG_DEBUG, NULL, 0, 1, fmt, ap);
      va_end (ap);
    }
}


/*
 *  Outputs an error message
 *  Note that this also gets into the bounced message
 */
void
Error (char *fmt, ...)
{
  va_list ap;

  va_start (ap, fmt);
  logmsg_ap (LOG_ERR, NULL, 0, 1, fmt, ap);
  va_end (ap);
}


/*
 *  Outputs a text the gets into a bounced message (if any)
 */
void
Bounce (char *fmt, ...)
{
  va_list ap;

  va_start (ap, fmt);
  vfprintf (stdout, fmt, ap);
  va_end (ap);
  fputc ('\n', stdout);
  fflush (stdout);
}


/*
 *  Outputs a series of lines from [Bounce]
 */
void
BounceText (char *szSection)
{
  Debug ("Bouncing with %s", szSection);

  cfg_rewind (pcfg);
  if (cfg_find (pcfg, "Bounce", szSection) != -1)
    {
      Bounce ("");
      do
	{
	  Bounce ("%s", ExpandMacro (pcfg->value));
	} while (cfg_nextentry (pcfg) == 0 && cfg_continue (pcfg));
    }
  else
    Bounce ("Failure: %s", szSection);
}


char *
FindMacro (char *key, size_t keylen)
{
  PKVPair pMacro;
  char *copy;

  copy = malloc (keylen + 1);
  memcpy (copy, key, keylen);
  copy[keylen] = 0;
  for (pMacro = macros; pMacro; pMacro = pMacro->pNext)
    {
      if (!strcmp (pMacro->key, copy))
	{
	  free (copy);
	  return pMacro->value;
	}
    }

  /* warn about used, but not defined macro */
  Debug ("Macro ${%*.*s} is used, but hasn't been defined\n",
      keylen, keylen, key);

  /* prevent repetition of this warning */
  pMacro = malloc (sizeof (TKVPair));
  pMacro->key = copy;
  pMacro->value = strdup ("");
  pMacro->pNext = macros;
  macros = pMacro;

  return pMacro->value ? pMacro->value : "";
}


void
DefMacro (char *key, char *value)
{
  PKVPair pMacro;

  for (pMacro = macros; pMacro; pMacro = pMacro->pNext)
    {
      if (!strcmp (pMacro->key, key))
	{
	  free (pMacro->value);
	  pMacro->value = strdup (value);
	  return;
	}
    }

  pMacro = malloc (sizeof (TKVPair));
  pMacro->key = strdup (key);
  pMacro->value = value;
  pMacro->pNext = macros;
  macros = pMacro;
}


char *
_ExpandMacro (char *str, int *updated)
{
  char *p, *q, *copy;
  MPL pool;

  p = strchr (str, '$');
  mpl_init (&pool);
  *updated = 0;
  while (p)
    {
      mpl_grow (&pool, str, p - str);
      if (p[1] == '{' && ((q = strchr (p, '}')) != NULL))
	{
	  copy = FindMacro (p + 2, q - p - 2);
	  if (copy)
	    mpl_grow (&pool, copy, strlen (copy));
	  str = q + 1;
	  *updated = 1;
	}
      else if (ismacrostart (p[1]))
	{
	  for (q = p + 2; ismacrocont (*q); q++)
	    ;
	  copy = FindMacro (p + 1, q - p - 1);
	  if (copy)
	    mpl_grow (&pool, copy, strlen (copy));
	  str = q;
	  *updated = 1;
	}
      else
	{
	  mpl_1grow (&pool, '$');
	  str = p + 1;
	}
      p = strchr (str, '$');
    }
  mpl_grow (&pool, str, strlen (str));
  mpl_1grow (&pool, '\0');
  copy = strdup (mpl_finish (&pool));
  mpl_destroy (&pool);

  return copy;
}


char *
ExpandMacro (char *str)
{
  char *str1;
  int level;
  int updated;

  if (!str)
    return NULL;

  for (level = 0; level < 20; level++)
    {
      str1 = _ExpandMacro (str, &updated);
      if (level)
	free (str);
      str = str1;
      if (!updated)
	break;
    }
  if (level == 20)
    {
      Error ("Macro expansion recursion overflow");
      BounceText ("InternalError");
      terminate (EX_SOFTWARE);
    }

  return level ? str : strdup (str);
}


int
DB_Connect (char *dataSource)
{
  SQLSMALLINT buflen;
  SQLCHAR buf[257];

  Debug ("Connecting to %s", dataSource);

  if (SQLAllocEnv (&henv) != SQL_SUCCESS)
    return -1;

  if (SQLAllocConnect (henv, &hdbc) != SQL_SUCCESS)
    return -1;

  if (SQLDriverConnect (hdbc, 0, (UCHAR *) dataSource, SQL_NTS, buf,
	  sizeof (buf), &buflen, SQL_DRIVER_COMPLETE) == SQL_ERROR)
    return -1;

  connected = 1;

  if (SQLAllocStmt (hdbc, &hstmt) != SQL_SUCCESS)
    return -1;

  return 0;
}


int
DB_Disconnect (void)
{
  if (hstmt != SQL_NULL_HSTMT)
    SQLFreeStmt (hstmt, SQL_DROP);

  if (connected)
    SQLDisconnect (hdbc);

  if (hdbc != SQL_NULL_HDBC)
    SQLFreeConnect (hdbc);

  if (henv != SQL_NULL_HENV)
    SQLFreeEnv (henv);

  return 0;
}


int
DB_Errors (char *where)
{
  SQLCHAR buf[250];
  SQLCHAR sqlstate[15];

  BounceText ("DatabaseError");

  Error ("");
  Error ("%s failed:", where);

  /* Get statement errors */
  while (SQLError (henv, hdbc, hstmt, sqlstate, NULL,
		   buf, sizeof (buf), NULL) == SQL_SUCCESS)
    {
      Error ("%s", buf);
      Error ("SQLSTATE=%s", sqlstate);
    }

  /* Get connection errors */
  while (SQLError (henv, hdbc, SQL_NULL_HSTMT, sqlstate, NULL,
		   buf, sizeof (buf), NULL) == SQL_SUCCESS)
    {
      Error ("%s", buf);
      Error ("SQLSTATE=%s", sqlstate);
    }

  /* Get environmental errors */
  while (SQLError (henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, sqlstate, NULL,
		   buf, sizeof (buf), NULL) == SQL_SUCCESS)
    {
      Error ("%s", buf);
      Error ("SQLSTATE=%s", sqlstate);
    }

  if (hstmt != SQL_NULL_HSTMT)
    SQLFreeStmt (hstmt, SQL_CLOSE);

  return -1;
}


int
DB_VerifyRecipient (void)
{
  SQLSMALLINT iParno;
  SQLCHAR sqlData[256];
  SQLLEN lenSqlData;
  SQLSMALLINT numCols;
  SQLSMALLINT col;
  SQLRETURN rc;
  char szKey[10];
  char *sqlRequest;
  long retCode;
  int32 wantCode;
  int useRetCode;
  char *sz1;
  char *sz2;
  char *szRecipient;
  char *szDomain;

  szRecipient = FindMacro ("local", 5);
  szDomain = FindMacro ("domain", 6);

  Debug ("Looking up user %s in domain %s", szRecipient, szDomain);

  /* Get the query string to execute */
  if (cfg_getstring (pcfg, "Options", "Verify", &sqlRequest) == -1)
    return 0;

  sqlRequest = ExpandMacro (sqlRequest);
  Debug ("Verify: %s", sqlRequest);

  SQLFreeStmt (hstmt, SQL_UNBIND);

  retCode = wantCode = -100;
  useRetCode = 0;
  if (cfg_getlong (pcfg, "Options", "VerifyCheckReturn", &wantCode) == 0)
    {
      useRetCode = 1;
      sz1 = malloc (strlen (sqlRequest) + 10) ;
      sz2 = stpcpy (sz1, "{?=call ");
      sz2 = stpcpy (sz2, sqlRequest);
      strcpy (sz2, "}");
      sqlRequest = sz1;
    }

  if (SQLPrepare (hstmt, (SQLCHAR *) sqlRequest, SQL_NTS) == SQL_ERROR)
    {
      DB_Errors ("SQLPrepare");
      terminate (EX_CONFIG);	/* most likely */
    }

  /* do we need to check procedure return value? */
  iParno = 1;
  if (useRetCode)
    {
      /* Pass retCode as parameter #1 */
      if (SQLBindParameter (
	    hstmt,
	    iParno++,
	    SQL_PARAM_OUTPUT,
	    SQL_C_LONG,
	    SQL_INTEGER,
	    0,
	    0,
	    &retCode,
	    0,
	    NULL) == SQL_ERROR)
	{
	  DB_Errors ("SQLBindParameter1");
	  terminate (EX_SOFTWARE);
	}
    }

  if (SQLExecute (hstmt) == SQL_ERROR)
    {
      DB_Errors ("SQLExecute");
      terminate (EX_SOFTWARE);
    }

  if (useRetCode)
    {
      if (retCode != wantCode)
	{
	  SQLFreeStmt (hstmt, SQL_CLOSE);
	  Debug ("VerifyCheckReturn want=%d got=%d", wantCode, retCode);
	  return -1;
	}
    }
  else
    {
      /* Fetch a single row */
      rc = SQLFetch (hstmt);
      if (rc == SQL_SUCCESS)
	{
	  /* Define macros for each column in the result set */
	  rc = SQLNumResultCols (hstmt, &numCols);
	  if (rc == SQL_SUCCESS)
	    {
	      for (col = 1; col <= numCols; col++)
		{
		  rc = SQLGetData (
		      hstmt,
		      col,
		      SQL_C_CHAR,
		      sqlData,
		      sizeof (sqlData),
		      &lenSqlData);
		  if (rc != SQL_SUCCESS)
		    break;

		  sprintf (szKey, "%u", (unsigned int) col);
		  Debug ("$%s=%s\n", szKey, sqlData);
		  DefMacro (szKey, strdup (sqlData));
		}
	    }
	}
      else if (rc == SQL_NO_DATA_FOUND)
	{
	  Debug ("No data found");
	  SQLFreeStmt (hstmt, SQL_CLOSE);
	  return -1;
	}

      if (rc == SQL_ERROR)
	{
	  DB_Errors ("SQLFetch");
	  terminate (EX_SOFTWARE);
	}
    }

  SQLFreeStmt (hstmt, SQL_CLOSE);

  return 0;
}


void
DB_DeliverMessage (char *msgTxt, int32 msgLen)
{
  SQLSMALLINT iParno;
  char *sqlRequest;
  long retCode;
  int32 wantCode;
  int useRetCode;
  char *sz1;
  char *sz2;

  if (cfg_getstring (pcfg, "Options", "Deliver", &sqlRequest) == -1)
    {
      Error ("Missing Deliver statement in [Options]");
      BounceText ("InternalError");
      terminate (EX_CONFIG);
    }

  DefMacro ("message", "?");

  sqlRequest = ExpandMacro (sqlRequest);
  Debug ("Deliver: %s", sqlRequest);

  SQLFreeStmt (hstmt, SQL_UNBIND);

  retCode = wantCode = -100;
  useRetCode = 0;
  if (cfg_getlong (pcfg, "Options", "DeliverCheckReturn", &wantCode) == 0)
    {
      useRetCode = 1;
      sz1 = malloc (strlen (sqlRequest) + 10) ;
      sz2 = stpcpy (sz1, "{?=call ");
      sz2 = stpcpy (sz2, sqlRequest);
      strcpy (sz2, "}");
      sqlRequest = sz1;
    }

  if (SQLPrepare (hstmt, (SQLCHAR *) sqlRequest, SQL_NTS) == SQL_ERROR)
    {
      DB_Errors ("SQLPrepare");
      terminate (EX_CONFIG);	/* most likely */
    }

  iParno = 1;
  if (useRetCode)
    {
      /* Pass retCode as parameter #1 */
      if (SQLBindParameter (
	    hstmt,
	    iParno++,
	    SQL_PARAM_OUTPUT,
	    SQL_C_LONG,
	    SQL_INTEGER,
	    0,
	    0,
	    &retCode,
	    0,
	    NULL) == SQL_ERROR)
	{
	  DB_Errors ("SQLBindParameter1");
	  terminate (EX_SOFTWARE);
	}
    }

  /* Pass message as next parameter */
  if (SQLBindParameter (
	hstmt,
	iParno++,
	SQL_PARAM_INPUT,
	SQL_C_CHAR,
	SQL_LONGVARCHAR,
	msgLen,
	0,
	msgTxt,
	msgLen,
	NULL) == SQL_ERROR)
    {
      DB_Errors ("SQLBindParameter3");
      terminate (EX_SOFTWARE);
    }

  if (SQLExecute (hstmt) == SQL_ERROR)
    {
      DB_Errors ("SQLExecute");
      terminate (EX_SOFTWARE);
    }

  SQLFreeStmt (hstmt, SQL_CLOSE);

  if (useRetCode && (retCode != wantCode))
    {
      Debug ("DeliverCheckReturn want=%d got=%d", wantCode, retCode);
      BounceText ("UserUnknown");
      terminate (EX_NOUSER);
    }
}


#ifdef XDEBUG
void
dump_environ (int argc, char **argv)
{
  extern char **environ;
  FILE *fd = fopen ("/root/env.out", "a");
  int i;
  if (fd)
    {
      char where[1200];
      where[0] = 0;
      getcwd (where, sizeof (where));
      fprintf (fd, "UID / EUID : %d %d\n", getuid (), geteuid ());
      fprintf (fd, "CWD        : %s\n", where);
      fprintf (fd, "Sender     : %s\n", f_sender);
      fprintf (fd, "Local      : %s\n", f_local);
      fprintf (fd, "Host       : %s\n", f_host);
      for (i = optind; i < argc; i++)
	fprintf (fd, "Argv[%d]   : %s\n", i, argv[i]);
      fprintf (fd, "Environment:\n");
      for (i = 0; environ[i]; i++)
	fprintf (fd, "%s\n", environ[i]);
      fclose (fd);
    }
}
#endif


void
terminate (int n)
{
  if (n == EX_OK)
    Debug ("++ TERMINATE SUCCESS ++");
  else
    Debug ("** TERMINATE FAILURE (%d) **", n);

  /* Make sure we don't exit with unknown error codes */
  if (n != EX_OK && (n < EX__BASE || n > EX__MAX))
    n = EX_SOFTWARE;

  /* Only qmail doesn't follow sysexits.h */
  if (mailer == MAILER_QMAIL)
    {
      switch (n)
	{
	case EX_OK:
	  n = QM_ERR_SUCCESS;
	  break;
	case EX_TEMPFAIL:	/* retried by sendmail */
	case EX_OSERR:		/* retried by sendmail */
	case EX_IOERR:		/* retried by sendmail */
	  n = QM_ERR_TEMP;
	  break;
	default:
	  n = QM_ERR_HARD;
	  break;
	}
    }

  exit (n);
}


int
PasteEnv (MPL *pPool, char *env)
{
  char *envLine;

  if ((envLine = getenv (env)) == NULL)
    return -1;

  mpl_grow (pPool, envLine, strlen (envLine));
  return 0;
}


void
MailTo (void)
{
  char *mailLOCAL;
  char *mailDOMAIN;
  char *mailSENDER;
  char *rmPrefix;

  if (f_local == NULL)
    {
      Error ("Recipient not specified");
      BounceText ("InternalError");
      terminate (EX_CONFIG);
    }

  mailLOCAL = strdup (f_local);
  mailDOMAIN = strdup (f_host ? f_host : "");
  mailSENDER = strdup (f_sender ? f_sender : "");

  /* Make lowercase */
  strlwr (mailLOCAL);
  strlwr (mailDOMAIN);

  /* Remove (qmail) prefixes like "myname-" in myname-touser */
  if (cfg_getstring (pcfg, "Options", "RemovePrefix", &rmPrefix) == 0)
    {
      size_t len = strlen (rmPrefix);
      if (!strnicmp (mailLOCAL, rmPrefix, len))
	mailLOCAL += len;
    }

  DefMacro ("local", mailLOCAL);
  DefMacro ("domain", mailDOMAIN);
  DefMacro ("sender", mailSENDER);
}


void
MailHeaders (MPL *mailPool)
{
  int32 ufl;
  char *s1;
  char *s2;

  switch (mailer)
    {
    case MAILER_QMAIL:
    case MAILER_COURIER:
      /*
       *  These environment variables contain crucial information for delivery,
       *  so prepend them to the mail message.
       */
      if (cfg_getlong (pcfg, "Options", "UnixFromLine", &ufl) == 0 &&
	  ufl != 0 &&
          PasteEnv (mailPool, "UFLINE") == -1)		/* From x@y <date> */
	{
	  goto bad_env;
	}

      if (PasteEnv (mailPool, "DTLINE") == -1 ||	/* Delivered-To: ... */
	  PasteEnv (mailPool, "RPLINE") == -1)		/* Return-Path: ... */
	{
	bad_env:
	  Error ("Bad environment");
	  BounceText ("InternalError");
	  terminate (EX_SOFTWARE);
	}
      break;

    case MAILER_OPLWIN32:
      if ((s2 = getenv ("RECIPIENT")) != NULL)
	{
	  s1 = "Delivered-To: ";
	  mpl_grow (mailPool, s1, strlen (s1));
	  mpl_grow (mailPool, s2, strlen (s2));
	  mpl_grow (mailPool, "\r\n", 2);
	}
      break;

    case MAILER_SENDMAIL:
    default:
      /* TODO should I insert Delivered-To: here? */
      break;
    }
}


#ifdef WIN32
/* exec doesn't work properly here */
void
my_exec (char *szProg, char *szCmdLine)
{
  PROCESS_INFORMATION processInformation;
  SECURITY_ATTRIBUTES attr;
  STARTUPINFO startupInfo;
  HANDLE hProc;
  HANDLE hRd;
  HANDLE hWr;
  BOOL bFailed;
  DWORD dwExitCode;

  /* Security descriptor that grants inheritance */
  attr.lpSecurityDescriptor = NULL;
  attr.nLength = sizeof (attr);
  attr.bInheritHandle = TRUE;

  /* Set startup info */
  memset (&startupInfo, 0, sizeof (startupInfo));
  startupInfo.cb = sizeof (startupInfo);
  startupInfo.dwFlags = STARTF_USESTDHANDLES;

  /* Make our stdio handles inheritable */
  hProc = GetCurrentProcess ();

  hRd = GetStdHandle (STD_INPUT_HANDLE);
  DuplicateHandle (
      hProc, hRd,
      hProc, &startupInfo.hStdInput,
      0, TRUE, DUPLICATE_SAME_ACCESS);

  hWr = GetStdHandle (STD_OUTPUT_HANDLE);
  DuplicateHandle (
      hProc, hWr,
      hProc, &startupInfo.hStdOutput,
      0, TRUE, DUPLICATE_SAME_ACCESS);

  startupInfo.hStdError = startupInfo.hStdOutput;

  memset (&processInformation, 0, sizeof (processInformation));

  bFailed = !CreateProcess (
      szProg,			// application name
      szCmdLine,		// command line
      NULL,			// security attributes
      NULL,			// thread attributes
      TRUE,			// inherit handles
      CREATE_SUSPENDED,		// want to close all our handles first
      NULL,			// environment
      NULL,			// current directory
      &startupInfo,
      &processInformation);

  /* Check for CreateProcess failure */
  if (bFailed)
    {
      CloseHandle (startupInfo.hStdInput);
      CloseHandle (startupInfo.hStdOutput);
      Error ("CreateProcess failed (%d)", GetLastError ());
      return;
    }

  /*
   *  It may be prudent to delay the reading child until we've
   *  closed our stdio handles. Haven't seen this going wrong yet, but ...
   */
  CloseHandle (startupInfo.hStdInput);
  CloseHandle (startupInfo.hStdOutput);
  CloseHandle (hRd);
  if (!f_debug)
    CloseHandle (hWr);
  ResumeThread (processInformation.hThread);

  /* Wait for child to exit - mailer will kill us eventually */
  if (WaitForSingleObject (processInformation.hProcess, INFINITE)
      == WAIT_OBJECT_0)
    {
      if (GetExitCodeProcess (processInformation.hProcess, &dwExitCode))
	{
	  CloseHandle (processInformation.hProcess);
	  CloseHandle (processInformation.hThread);
	  ExitProcess (dwExitCode);
	}
    }

  /* Some other failure */
  TerminateProcess (processInformation.hProcess, 1);
  CloseHandle (processInformation.hProcess);
  CloseHandle (processInformation.hThread);
}
#endif



/*
 *  If the user isn't in the database, attempt delivery to
 *  an external program, if desired.
 *  Could be used to forward to vdeliver for instance
 */
void
FallbackDeliver (void)
{
  char *szDeliverProg;
  char **av;
  int ac;

  if (cfg_getstring (pcfg, "Options", "Fallback", &szDeliverProg) == 0)
    {
      if (build_argv_from_string (szDeliverProg, &ac, &av) == 0)
	{
	  DB_Disconnect ();		/* disconnect from database */
	  szDeliverProg = ExpandMacro (szDeliverProg);
	  Debug ("Fallback delivery with %s", szDeliverProg);
#ifdef WIN32
	  my_exec (av[0], szDeliverProg);
#else
	  execvp (av[0], av);
	  switch (errno)
	    {
	    case ENOENT:
	    case EPERM:
	    case EACCES:
	      Debug ("exec failed (%m)");
	      break; /* silently ignore this -> user unknown */

	    default:
	      /* let's hope we just ran out of resources - retry */
	      Error ("exec failed (%m)");
	      terminate (EX_IOERR);
	    }
#endif
	}
    }
}


void
OpenConfig (char *argv0)
{
  struct stat sb;

  /* Get default configuration file */
  if (f_config == NULL)
    f_config = strdup (setext (argv0, "ini", EXT_SET));

  /* Check the config file */
  if (stat (f_config, &sb) == -1)
    {
    cfg_not_found:
      Error ("Cannot open configuration file %s", f_config);
      BounceText ("InternalError");	/* don't try to look this up */
      terminate (EX_OSFILE);
    }

  /* Check type & permissions */
  if ((sb.st_mode & S_IFMT) != S_IFREG)
    {
      Error ("Invalid configuration file %s", f_config);
      BounceText ("InternalError");		/* don't try to look this up */
      terminate (EX_CONFIG);
    }

  /* Open the configuration file */
  if (cfg_init (&pcfg, f_config) == -1)
    goto cfg_not_found;

#ifndef WIN32
  /* Should NOT be world-writable */
  if (sb.st_mode & 022)
    {
      Error ("Bad permissions on %s", f_config);
      BounceText ("InternalError");
      terminate (EX_TEMPFAIL);
    }
#endif
}


void
OpenLog (void)
{
  LOG *stderr_log;

  /* Set up Error stream */
  stderr_log = log_open_fp (stderr, LOG_ERR, L_MASK_ALL, 0);
  log_set_level (stderr_log, f_debug ? LOG_DEBUG : LOG_ERR);

#ifdef WITH_SYSLOG
  switch (mailer)
    {
    case MAILER_SENDMAIL:
      log_open_syslog (MYNAME, 0, LOG_MAIL, f_debug ? LOG_DEBUG : LOG_ERR,
	  L_MASK_ALL, 0);
      break;
      /* qmail & courier log all stdout/stderr through splogger */
    default:
      break;
    }
#endif
}


void
NewEnvironment (void)
{
  if (cfg_find (pcfg, "Environment", NULL) == 0)
    {
      while (cfg_nextentry (pcfg) == 0)
	{
	  if (cfg_section (pcfg))
	    break;
	  if (cfg_define (pcfg))
	    {
#ifdef XDEBUG
	      Debug ("Set %s=%s", pcfg->id, pcfg->value);
#endif
	      make_env (pcfg->id, pcfg->value);
	    }
	}
    }

  if (f_local)
    make_env ("LOCAL", f_local);
  else
    f_local = getenv ("LOCAL");

  if (f_host)
    make_env ("HOST", f_host);
  else
    f_host = getenv ("HOST");

  if (f_sender)
    make_env ("SENDER", f_sender);
  else
    f_sender = getenv ("SENDER");
}


void
do_mailer (struct pgm_option *opt)
{
  if (!strcmp (optarg, "sendmail"))
    mailer = MAILER_SENDMAIL;
  else if (!strcmp (optarg, "exim"))
    mailer = MAILER_SENDMAIL;
  else if (!strcmp (optarg, "qmail"))
    mailer = MAILER_QMAIL;
  else if (!strcmp (optarg, "courier"))
    mailer = MAILER_COURIER;
#ifdef WIN32
  else if (!strcmp (optarg, "win32"))
    mailer = MAILER_OPLWIN32;
#endif
  else
    usage ();
}


void
usage (void)
{
  default_usage ();
  fprintf (stderr, "\nMailer types supported:\n");
#ifdef WIN32
  fprintf (stderr, "  -m win32 (default, needs -l)\n");
  fprintf (stderr, "  -m sendmail (needs -l)\n");
#else
  fprintf (stderr, "  -m sendmail (default, needs -l)\n");
#endif
  fprintf (stderr, "  -m exim (same as -m sendmail)\n");
  fprintf (stderr, "  -m qmail\n");
  fprintf (stderr, "  -m courier\n");
  terminate (EX_USAGE);
}


int
main (int argc, char **argv)
{
  SQLCHAR dataSource[512];
  int32 port;
  char *szDSN;
  char *szHOST;
  char *szUID;
  char *szPWD;
  MPL mailPool;
  int32 mailSize;
  int32 mailSizeMax;
  char *mailMesg;
  char *mailDebug;


  initialize_program (&argc, &argv);

#ifdef WIN32
  mailer = (mailer == MAILER_UNKNOWN) ? MAILER_OPLWIN32 : mailer;
  setmode (0, O_BINARY);
  setmode (1, O_BINARY);
  setmode (2, O_BINARY);
#else
  mailer = (mailer == MAILER_UNKNOWN) ? MAILER_SENDMAIL : mailer;
#endif

  OpenLog ();

  OpenConfig (argv[0]);

  NewEnvironment ();

#ifdef XDEBUG
  if (f_debug)
    {
      int32 exitCode;

      dump_environ (argc, argv);

      /* Testing behaviour with various exit codes */
      if (cfg_getlong (pcfg, "Options", "DebugExit", &exitCode) == 0)
	exit (exitCode);
    }
#endif

  /* Retrieve the database connect parameters */
  if (cfg_getstring (pcfg, "Options", "DSN", &szDSN) == -1)
    {
      if (cfg_getstring (pcfg, "Options", "HOST", &szHOST) == -1)
	szHOST = "localhost";
      if (cfg_getstring (pcfg, "Options", "UID", &szUID) == -1)
	szUID = "dba";
      if (cfg_getstring (pcfg, "Options", "PWD", &szPWD) == -1)
	szPWD = "dba";
      if (cfg_getlong (pcfg, "Options", "PORT", &port) == -1 ||
	  port < 1 || port > 65534)
	port = 1111;

      sprintf ((char *) dataSource, "DSN=noname;HOST=%s:%u;UID=%s;PWD=%s",
	  szHOST, (unsigned int) port, szUID, szPWD);
      szDSN = (char *) dataSource;
    }

  /* Figure out recipient */
  MailTo ();

  /* Connect to DBMS */
  if (DB_Connect (szDSN) != 0)
    {
      DB_Errors ("DB_Connect");
      /* terminate (EX_UNAVAILABLE); */
      terminate (EX_TEMPFAIL);
    }

  /* Verify the recipient */
  if (DB_VerifyRecipient () == -1)
    {
      /* user not found */
      FallbackDeliver ();
      BounceText ("UserUnknown");
      terminate (EX_NOUSER);
    }

  /* Construct the posted message into memory pool */
  mpl_init (&mailPool);

  /* Prepend delivered-to etc. headers */
  MailHeaders (&mailPool);

  /* Read the message from stdin - making sure it's not too long */
  if (cfg_getlong (pcfg, "Options", "MaxMessageSize", &mailSizeMax) == -1 ||
      mailSizeMax < 0)
    {
      mailSizeMax = 0;
    }
  mailSize = 0;
  for (;;)
    {
      char buffer[8192];
      size_t len;

      errno = 0;
      len = fread (buffer, 1, sizeof (buffer), stdin);
      if (errno)
	{
	  Error ("Read failure");
	  BounceText ("InternalError");
	  terminate (EX_IOERR);
	}
      if (len == 0)
	break;
      mpl_grow (&mailPool, (memptr_t) buffer, (memsz_t) len);
      mailSize += (int32) len;
      if (mailSizeMax && mailSize > mailSizeMax)
	{
	  Debug ("Message is too long (%ld)", (long) mailSize);
	  BounceText ("TooLong");
	  terminate (EX_NOPERM);
	}
    }

  /* Terminate & get the message */
  mpl_1grow (&mailPool, 0);
  mailSize = (int32) mpl_object_size (&mailPool) - 1;
  mailMesg = (char *) mpl_finish (&mailPool);

  /* Write a copy for debugging purposes, if desired */
  if (cfg_getstring (pcfg, "Options", "MailDebug", &mailDebug) == 0)
    {
      FILE *fd = fopen (mailDebug, "ab");
      if (fd)
	{
	  fwrite (mailMesg, 1, mailSize, fd);
	  fclose (fd);
	}
    }

  /* Now execute the record-insert code */
  DB_DeliverMessage (mailMesg, mailSize);

  /* All done */
  DB_Disconnect ();
  terminate (EX_OK);

  return 0; /* keep cc happy */
}
