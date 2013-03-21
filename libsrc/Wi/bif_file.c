/*
 *  bif_file.c
 *
 *  $Id$
 *
 *  Bifs for file I/O
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#if defined (__APPLE__) && defined(SPOTLIGHT)
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#undef FAILED
#define _boolean
#endif

#include <stdio.h>
#include "sqlnode.h"
#include "sqlparext.h"
#include "security.h"
#include "sqlbif.h"

#ifdef __MINGW32__
#define P_tmpdir _P_tmpdir
#endif

#define UUID_T_DEFINED
#include "libutil.h"		/* needed by bif_cfg_* functions */
#include "statuslog.h"
#include <sys/stat.h>

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

#include <zlib.h>
#if MAX_MEM_LEVEL >= 8
#  define DEF_MEM_LEVEL 8
#else
#  define DEF_MEM_LEVEL  MAX_MEM_LEVEL
#endif

#include "srvmultibyte.h"

#define FS_MAX_STRING	(10L * 1024L * 1024L)	/* allow files up to 10 MB */

#ifdef WIN32
#include <windows.h>
#define HAVE_DIRECT_H
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define mkdir(p,m)	_mkdir (p)
#define FS_DIR_MODE	0777
#define PATH_MAX	 MAX_PATH
#define get_cwd(p,l)	_get_cwd (p,l)
#else
#include <dirent.h>
#define FS_DIR_MODE	 (S_IRWXU | S_IRWXG | S_IRWXO)
#endif

#include "datesupp.h"
#include "langfunc.h"

int i18n_wide_file_names = 0;
encoding_handler_t *i18n_volume_encoding = NULL;
encoding_handler_t *i18n_volume_emergency_encoding = NULL;


extern dk_session_t *http_session_arg (caddr_t * qst, state_slot_t ** args, int nth, const char * func);
extern dk_session_t *http_session_no_catch_arg (caddr_t * qst, state_slot_t ** args, int nth, const char * func);
extern int dks_read_line (dk_session_t * ses, char *buf, int max);

char *temp_ses_dir;		/* For viconfig.c */
char _srv_cwd[PATH_MAX + 1], *srv_cwd = _srv_cwd;
dk_set_t d_db_files = NULL;
dk_set_t a_dirs = NULL;
dk_set_t d_dirs = NULL;
dk_set_t safe_execs_set = NULL;
dk_set_t dba_execs_set = NULL;
static char www_abs_path[PATH_MAX + 1];	/* the max possible OS path */
int spotlight_integration;

char *rel_to_abs_path (char *p, const char *path, long len);

#ifdef WIN32
#define DIR_SEP '\\'
#define SINGLE_DOT "\\."
#define DOUBLE_DOT "\\.."
#define IS_DRIVE(p) (*(p+1) == ':')
#define BEGIN_WITH(a,b) (0 == strnicmp (a,b,strlen(b)))
#define STR_EQUAL(a,b) (0 == stricmp (a,b))
#else
#define DIR_SEP '/'
#define SINGLE_DOT "/."
#define DOUBLE_DOT "/.."
#define IS_DRIVE(p) 0
#define BEGIN_WITH(a,b) (0 == strncmp (a,b,strlen(b)))
#define STR_EQUAL(a,b) (0 == strcmp (a,b))
#endif

char *
virt_strerror (int eno)
{
#ifdef HAVE_STRERROR_R
  static char buf[BUFSIZ];
#ifdef STRERROR_R_CHAR_P
  if (NULL != strerror_r (eno, buf, sizeof (buf)))
#else
  if (0 == strerror_r (eno, buf, sizeof (buf)))
#endif
    return &(buf[0]);
  else
    return "";
#elif defined HAVE_SYS_ERRLIST
  if (eno < sys_nerr)
    return sys_errlist[eno];
  else
    return "";
#else
  return strerror (eno);
#endif
}

static dk_mutex_t *run_executable_mtx;

void
init_file_acl_set (char *acl_string1, dk_set_t * acl_set_ptr)
{
  char *tmp, *tok_s = NULL, *tok;
  char p[PATH_MAX + 1], *pp = p;	/* temp path (the max possible OS path) */
  caddr_t acl_string = acl_string1 ? box_dv_short_string (acl_string1) : NULL;	/* lets do a copy because strtok
										   will destroy the string */
  if (NULL != acl_string)
    {
      tok_s = NULL;
      tok = strtok_r (acl_string, ",", &tok_s);
      while (tok)
	{
	  while (*tok && isspace (*tok))
	    tok++;
	  if (tok_s)
	    tmp = tok_s - 2;
	  else if (tok && strlen (tok) > 1)
	    tmp = tok + strlen (tok) - 1;
	  else
	    tmp = NULL;
	  while (tmp && tmp >= tok && isspace (*tmp))
	    *(tmp--) = 0;
	  if (*tok)
	    {
#ifdef HAVE_DIRECT_H
	      char *sl;
	      for (sl = tok; *sl; sl++)
		{
		  if (*sl == '/')
		    *sl = '\\';
		}
#endif
	      pp = p;
	      if (rel_to_abs_path (pp, tok, sizeof (p)))
		dk_set_push (acl_set_ptr, box_dv_short_string (p));
	    }
	  tok = strtok_r (NULL, ",", &tok_s);
	}
      dk_free_box (acl_string);
    }
}

static void
get_tmp_dirs (char *p, int len)
{
#ifdef WIN32
  char *tmp = getenv ("TMP");
#else
  char *tmp = getenv ("TMPDIR");
#endif
  if (NULL != temp_dir)
    tmp = temp_dir;
  else if (NULL == tmp || strlen (tmp) < 1)
    tmp = P_tmpdir;
  strncpy (p, tmp, len);
  p[len] = 0;
}


void
acl_add_allowed_dir (char *dir)
{
  init_file_acl_set (dir, &a_dirs);
}

int acl_initilized = 0;

/* initialize file ACL & explicit deny for db files & make full path for WWW root */
void
init_server_cwd (void)
{
  size_t cwd_len = 0;
  _srv_cwd[0] = 0;
  getcwd (_srv_cwd, sizeof (_srv_cwd));
  cwd_len = strlen (_srv_cwd);
  if (cwd_len > 0 && _srv_cwd[cwd_len - 1] == DIR_SEP)
    _srv_cwd[cwd_len - 1] = 0;
}


void
init_file_acl (void)
{
  char *p_www_abs_path = www_abs_path;
  static char fdb[PATH_MAX + 1], *pfdb = fdb;
  char tmpdir[PATH_MAX + 1];
  id_hash_t * sys_files = wi_inst.wi_files;
  id_hash_iterator_t it;
  caddr_t *sys_name, *sys_file;

  get_tmp_dirs (tmpdir, sizeof (tmpdir) - 1);
  init_file_acl_set (tmpdir, &a_dirs);
  init_file_acl_set (allowed_dirs, &a_dirs);
#if 0
  DO_SET (char *, elm, &a_dirs)
    {
      fprintf (stderr, "%s\n", elm);
    }
  END_DO_SET ();
#endif
  init_file_acl_set (denied_dirs, &d_dirs);
  init_file_acl_set (safe_execs, &safe_execs_set);
  init_file_acl_set (dba_execs, &dba_execs_set);
  if (www_root)
    {
      memset (www_abs_path, 0, sizeof (www_abs_path));
#ifdef HAVE_DIRECT_H
      {
	char *fname_cvt, *fname_tail;
	size_t fname_cvt_len = strlen (www_root) + 1;
	fname_cvt = dk_alloc (fname_cvt_len);
	strcpy_size_ck (fname_cvt, www_root, fname_cvt_len);
	for (fname_tail = fname_cvt; fname_tail[0]; fname_tail++)
	  {
	    if ('/' == fname_tail[0])
	      fname_tail[0] = '\\';
	  }
	p_www_abs_path =
	    rel_to_abs_path (p_www_abs_path, fname_cvt,
	    sizeof (www_abs_path));
	dk_free (fname_cvt, fname_cvt_len);
      }
#else
      p_www_abs_path =
	  rel_to_abs_path (p_www_abs_path, www_root, sizeof (www_abs_path));
#endif

      if (p_www_abs_path)
	www_root = p_www_abs_path;	/* replace http server root w/h absolute path */
    }

  /* initialize explicitly denied db files */
  if (f_config_file)
    {
      rel_to_abs_path (pfdb, f_config_file, sizeof (fdb));	/* ini file */
      dk_set_push (&d_db_files, box_dv_short_string (fdb));
    }
  rel_to_abs_path (pfdb, "virtuoso.lic", sizeof (fdb));	/* license file */
  dk_set_push (&d_db_files, box_dv_short_string (fdb));
  /* log segments */
  if (sys_files) /* during backup restore, db is not open, therefore we skip this part */
    {
      id_hash_iterator (&it, sys_files);
      while (hit_next (&it, (char**) &sys_name, (char**) &sys_file))
	{
	  dk_set_push (&d_db_files, box_dv_short_string (*sys_name));
	}
    }
  acl_initilized = 1;
}


/* Convert relative file path to absolute beginning from server cwd
   if length (len) of allocated (p) is small than resulting path return null */
char *
rel_to_abs_path (char *p, const char *path, long len)
{
  char *fp = p, *sp = p, c = 0, c1 = 0, c2 = 0, c3 = 0;

  if (!p)
    return NULL;

  if (!path)			/* this cannot be done */
    {
      *sp = 0;
      return p;
    }

  if (*path == DIR_SEP || IS_DRIVE (path))	/* requested path is absolute */
    {
      if (strlen (path) < (size_t) len)
	strcpy_size_ck (p, path, len);
      else
	return NULL;
    }
  else
    {
      if (strlen (path) + strlen (srv_cwd) + 1 < (size_t) len)
	snprintf (p, len, "%s%c%s", srv_cwd, DIR_SEP, path);
      else
	return NULL;
    }

  /* if path not contains relative elements return it */
  if (!strstr (p, SINGLE_DOT) && !strstr (p, DOUBLE_DOT))
    return p;

  for (; *fp; fp++, sp++)	/* check for nested relative elements */
    {
      c3 = c2;
      c2 = c1;
      c1 = c;
      c = *fp;
      *sp = c;
      if (c == DIR_SEP && c1 == '.' && c2 == DIR_SEP)	/* like /./ */
	sp -= 2;
      else if (c == DIR_SEP && c1 == '.' && c2 == '.' && c3 == DIR_SEP)	/* like /../ */
	{
	  sp -= 4;
	  if (sp < p)		/* requested file is under root level */
	    return NULL;
	  while (sp > p && *sp != DIR_SEP)
	    sp--;
	}
    }
  /* remove trailing dots */
  if (c1 == DIR_SEP && c == '.')
    sp -= 2;
  else if (c2 == DIR_SEP && c1 == '.' && c == '.')
    {
      sp -= 4;
      if (sp < p)
	return NULL;
      while (sp > p && *sp != DIR_SEP)
	sp--;
    }
  *sp = 0;
  return p;
}

/* check is some db file  */
static int
is_db_file (char *f)
{
  if (!f)
    return 1;
  if (d_db_files)
    {
      DO_SET (caddr_t, line, &d_db_files)
        {
          if (STR_EQUAL (f, line))
            return 1;
        }
      END_DO_SET ();
    }
  return 0;
}

int
is_allowed (char *path)
{
  int rc = 0;
  caddr_t abs_path = NULL;

  if (!path)
    return 0;

  abs_path = dk_alloc_box (PATH_MAX + 1, DV_STRING);
  abs_path[0] = 0;
  if (!rel_to_abs_path (abs_path, path, box_length (abs_path) - 1))
    {
      rc = 0;
      goto ret;
    }


  /* explicitly deny any db file */
  if (is_db_file (abs_path))
    {
      rc = 0;
      goto ret;
    }

  /* allow any file under WWW root */
  if (www_root && BEGIN_WITH (abs_path, www_root) && !strstr (abs_path, ".."))
    {
      rc = 1;
      goto ret;
    }


  if (!*abs_path || !a_dirs)
    {
      rc = 0;
      goto ret;
    }
  /* check in allowed dirs */
  if (a_dirs)
    {
      DO_SET (caddr_t, line, &a_dirs)
        {
          if (BEGIN_WITH (abs_path, line))
            {
              rc = 1;
              break;
            }
        }
      END_DO_SET ();
    }
  /* check in denied dirs */
  if (d_dirs)
    {
      DO_SET (caddr_t, line, &d_dirs)
        {
          if (BEGIN_WITH (abs_path, line))
            {
              rc = 0;
              break;
            }
        }
      END_DO_SET ();
    }
ret:
  dk_free_box (abs_path);
  return rc;
}


void
file_path_assert (caddr_t fname_cvt, caddr_t *err_ret, int free_fname_cvt)
{
  caddr_t err = NULL;
  if (PATH_MAX < (box_length (fname_cvt) - 1))
    err = srv_make_new_error ("42000", "FA117",
      "File path '%.200s...' is too long (%ld chars), OS limit is %ld chars",
      fname_cvt, (long)(box_length (fname_cvt) - 1), (long)PATH_MAX);
  else if (!is_allowed (fname_cvt))
    err = srv_make_new_error ("42000", "FA003",
      "Access to '%.1000s' is denied due to access control in ini file",
    fname_cvt );
  if (NULL != err_ret)
    err_ret [0] = err;
  if (NULL == err)
    return;
  if (free_fname_cvt)
    dk_free_box (fname_cvt);
  if (NULL == err_ret)
    sqlr_resignal (err);
}


static caddr_t
bif_sys_unlink (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname, fname_cvt;
  caddr_t err = NULL;
  int retcode, errcode;

  sec_check_dba ((query_instance_t *) qst, "sys_unlink");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "sys_unlink");
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  retcode = unlink (fname_cvt);
  if (-1 == retcode)
    {
      errcode = errno;
      switch (errcode)
	{
#ifdef EACCES
	case EACCES:
	  err = srv_make_new_error ("42000", "SR426",
	      "Permission is denied for the file '%.1000s' in sys_unlink()",
	      fname_cvt );
          break;
#endif
#ifdef ENAMETOOLONG
	case ENAMETOOLONG:
	  err = srv_make_new_error ("42000", "SR427",
	      "Path name '%.1000s' too long in sys_unlink()", fname_cvt );
          break;
#endif
#ifdef ENOENT
	case ENOENT:
	  err = srv_make_new_error ("42000", "SR428",
	      "A directory component in '%.1000s' does not exist or is a dangling symbolic link in sys_unlink()",
	      fname_cvt );
          break;
#endif
#ifdef ENOTDIR
	case ENOTDIR:
	  err = srv_make_new_error ("42000", "SR429",
	      "A component used as a directory in '%.1000s' is not, in fact, a directory in sys_unlink()",
	      fname_cvt );
          break;
#endif
#ifdef EISDIR
	case EISDIR:
	  err = srv_make_new_error ("42000", "SR430",
	      "'%.1000s' refers to a directory in sys_unlink()", fname_cvt );
          break;
#endif
#ifdef ENOMEM
	case ENOMEM:
	  err = srv_make_new_error ("42000", "SR431",
	      "Insufficient kernel memory was available in sys_unlink() to process '%.1000s'", fname_cvt );
          break;
#endif
#ifdef EROFS
	case EROFS:
	  err = srv_make_new_error ("42000", "SR432",
	      "'%.1000s' refers to a file on a read-only filesystem in sys_unlink()",
	      fname_cvt );
          break;
#endif
#ifdef ELOOP
	case ELOOP:
	  err = srv_make_new_error ("42000", "SR433",
	      "Too many symbolic links were encountered in translating '%.1000s' in sys_unlink()",
	      fname_cvt);
          break;
#endif
#ifdef EIO
	case EIO:
	  err = srv_make_new_error ("42000", "SR434",
	      " An I/O error occurred in sys_unlink(), resource '%.1000s'", fname_cvt);
          break;
#endif
	}
      goto signal_error;
    }
  dk_free_box (fname_cvt);
  return box_num (retcode);

signal_error:
  dk_free_box (fname_cvt);
  sqlr_resignal (err);
  return NULL;
}

static caddr_t
bif_file_to_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname_cvt, res = NULL;
  OFF_T off, start_pos = 0;
  OFF_T bytes;
  caddr_t fname;
  int fd = -1;
  caddr_t err = NULL;
  sec_check_dba ((query_instance_t *) qst, "file_to_string");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "file_to_string");
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  fd = open (fname_cvt, OPEN_FLAGS_RO);
  if (fd < 0)
    {
      err = srv_make_new_error ("39000", "FA005", "Can't open file '%.1000s', error %d", fname_cvt,
	errno);
      goto signal_error;
    }

  off = LSEEK (fd, 0, SEEK_END);
  bytes = off;
  if (off == -1)
    {
      err = srv_make_new_error ("39000", "FA007", "Seek error in file '%.1000s', error %d",
	  fname_cvt, errno );
      goto signal_error;
    }
  if (BOX_ELEMENTS (args) > 1)
    {
      start_pos = (OFF_T) bif_long_arg (qst, args, 1, "file_to_string");
      if (start_pos > off)
	{
	  err = srv_make_new_error ("39000", "FA008", "Start offset %ld is out of range in file '%.1000s' of actual length %ld",
            (long)start_pos, fname_cvt, (long)off );
          goto signal_error;
	}
    }

  if (BOX_ELEMENTS (args) > 2)
    {
      bytes = (size_t) bif_long_arg (qst, args, 2, "file_to_string");
    }
  else if (start_pos > 0)
    {
      bytes = off - start_pos;
    }

  if (bytes > FS_MAX_STRING)
    {
      err = srv_make_new_error ("39000", "FA008",
        "File '%.1000s' too long, cannot return string content %ld chars long", fname_cvt, (long)bytes );
      goto signal_error;
    }

  LSEEK (fd, start_pos, SEEK_SET);

  if (NULL == (res = dk_try_alloc_box (bytes + 1, DV_LONG_STRING)))
    {
      close(fd);
      dk_free_box (fname_cvt);
      qi_signal_if_trx_error ((query_instance_t *)qst);
    }
  if (read (fd, res, bytes) != bytes)
    {
      dk_free_box (res);
      err = srv_make_new_error ("39000", "FA009",
        "Read from file '%.1000s' failed (%d)", fname_cvt, errno );
      goto signal_error;
    }
  res[bytes] = 0;

signal_error:
  if (-1 != fd)
    close (fd);
  dk_free_box (fname_cvt);
  if (NULL != err)
    sqlr_resignal (err);
  return res;
}


caddr_t
bif_server_root (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char abs_path[PATH_MAX + 1], *p_abs_path = abs_path;
  char *path = "";

  abs_path[0] = 0;
  if (!rel_to_abs_path (p_abs_path, path, sizeof (abs_path)))
    return 0;
  p_abs_path = abs_path;
  return (box_dv_short_string (abs_path));
}


void
set_ses_tmp_dir ()
{
  static char abs_path[PATH_MAX + 1], *p_abs_path = abs_path;
  abs_path[0] = 0;
  rel_to_abs_path (p_abs_path, temp_ses_dir ? temp_ses_dir : "",
      sizeof (abs_path));
  p_abs_path = abs_path;
  ses_tmp_dir = box_dv_short_string (abs_path);
}


static caddr_t
bif_file_to_string_session_impl (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args, int is_utf8, int ses_exists, const char *func_name)
{
  dk_session_t *res = NULL;
  caddr_t fname, fname_cvt, err = NULL;
  int fd = -1, argctr, from_is_set = 0, to_is_set = 0, argcount = BOX_ELEMENTS (args);
  int saved_errno;
  char buffer[0x8000];
  volatile OFF_T from, to, total = 0, need = 0, readed, next;
  STAT_T st;

  sec_check_dba ((query_instance_t *) qst, func_name);
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, func_name);
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  argctr = 1;
  if (ses_exists)
    res = http_session_no_catch_arg (qst, args, argctr++, func_name);
  if (argctr < argcount)
    {
      from = bif_long_arg (qst, args, argctr++, func_name);
      from_is_set = 1;
    }
  if (argctr < argcount)
    {
      to = bif_long_arg (qst, args, argctr++, func_name);
      to_is_set = 1;
    }
  if (-1 == V_STAT (fname_cvt, &st))
    {
      int eno = errno;
      err = srv_make_new_error ("42000", "FA112", "Can't stat file '%.1000s', error (%d) : %s",
        fname_cvt, eno, strerror (eno) );
      goto signal_error;
    }

  if (from_is_set)
    {
      if (from > st.st_size || from < 0)
	{
	  err = srv_make_new_error ("42000", "FA113",
	      "Invalid starting offset passed to %s('%.1000s'," OFF_T_PRINTF_FMT ",...),"
	      " file size is " OFF_T_PRINTF_FMT,
	      func_name, fname_cvt, (OFF_T_PRINTF_DTP) from, (OFF_T_PRINTF_DTP) st.st_size );
          goto signal_error;
	}
    }
  else
    from = 0;
  if (to_is_set)
    {
      /* to == -1 means read until EOF */
      if (to != -1 && (to > st.st_size || to < from))
	{
	  err = srv_make_new_error ("42000", "FA114",
	      "Invalid ending offset passed to %s('%.1000s',"
	      OFF_T_PRINTF_FMT "," OFF_T_PRINTF_FMT "), "
	      "file size is " OFF_T_PRINTF_FMT,
	      func_name, fname_cvt, (OFF_T_PRINTF_DTP) from, (OFF_T_PRINTF_DTP) to, (OFF_T_PRINTF_DTP) st.st_size );
          goto signal_error;
	}
    }
  else
    to = st.st_size;
  fd = open (fname, OPEN_FLAGS_RO);
  if (fd < 0)
    {
      int eno = errno;
      err = srv_make_new_error ("42000", "FA012", "Can't open file '%.1000s', error (%d) : %s", fname_cvt,
	  eno, strerror (eno) );
      goto signal_error;
    }

  if (!ses_exists)
    {
      res = strses_allocate ();
      strses_enable_paging (res, 1024 * 1024 * 10);
    }

  if ((0 != from) && (((OFF_T)-1) == LSEEK (fd, from, SEEK_SET)))
    {
      int eno = errno;
      strses_free (res);
      err = srv_make_new_error ("42000", "FA113",
	  "Can't seek to in file '%.1000s' seek to " OFF_T_PRINTF_FMT ", error (%d) : %s",
	  fname_cvt, (OFF_T_PRINTF_DTP)from, eno, strerror (eno) );
      goto signal_error;
    }
  if (to == -1)
    need = -1;
  else
    need = to - from;
  for (;;)
    {
      if (need == -1)
	{
	  next = sizeof (buffer);
	}
      else
	{
	  next = need - total;
	  if (sizeof (buffer) < next)
	    next = sizeof (buffer);
	  if (next <= 0)
	    break;
	}
      readed = read (fd, buffer, (unsigned) next);
      if (readed <= 0)
	break;
      total += readed;
      session_buffered_write (res, buffer, readed);
      if (DK_ALLOC_ON_RESERVE)
	{
	  strses_free (res);
	  close (fd);
	  qi_signal_if_trx_error ((query_instance_t *)qst);
	}
      if (need != -1 && total >= need)
	break;
    }
  if (readed == -1)
    {
      saved_errno = errno;
      strses_free (res);
      err = srv_make_new_error ("39000", "FA013", "Read from '%.1000s' failed (%d) : %s", fname_cvt,
	  saved_errno, strerror (saved_errno) );
      goto signal_error;
    }
  if (need != -1 && total != need)
    {
      strses_free (res);
      err = srv_make_new_error ("39000", "FA115",
	  "Read " OFF_T_PRINTF_FMT
	  " instead of " OFF_T_PRINTF_FMT " bytes from file '%.1000s'",
	  (OFF_T_PRINTF_DTP)total, (OFF_T_PRINTF_DTP)need, fname_cvt );
      goto signal_error;
    }
  close (fd);
  dk_free_box (fname_cvt);
  if (is_utf8)
    strses_set_utf8 (res, 1);
  if (ses_exists)
    return box_num (total);
  else
    return (caddr_t) res;

signal_error:
  if (-1 != fd)
    close (fd);
  dk_free_box (fname_cvt);
  sqlr_resignal (err);
  return NULL;
}


static caddr_t
bif_file_to_string_session (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  return bif_file_to_string_session_impl (qst, err_ret, args, 0, 0, "file_to_string_session");
}


static caddr_t
bif_file_to_string_session_utf8 (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  return bif_file_to_string_session_impl (qst, err_ret, args, 1, 0, "file_to_string_session_utf8");
}


static caddr_t
bif_file_append_to_string_session (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  return bif_file_to_string_session_impl (qst, err_ret, args, 0, 1, "file_append_to_string_session");
}


static caddr_t
bif_file_append_to_string_session_utf8 (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  return bif_file_to_string_session_impl (qst, err_ret, args, 1, 1, "file_append_to_string_session_utf8");
}

caddr_t
file_stat_int (caddr_t fname, int what)
{
  char dt[DT_LENGTH];
  char szTemp[100];
  caddr_t fname_cvt;
  int stat_res;
  STAT_T st;

  memset (dt, 0, sizeof (dt));
  fname_cvt = file_native_name (fname);
  stat_res = V_STAT (fname_cvt, &st);

  if (-1 == stat_res)
    {
      dk_free_box (fname_cvt);
      return NULL;
    }

  if ((what == 0) || (what == 3 && 0 == (st.st_mode & S_IFDIR)))
    {
#if defined (HAVE_DIRECT_H) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
      if (!file_mtime_to_dt (fname_cvt, dt))
	{
          dk_free_box (fname_cvt);
	  return NULL;
	}
#else
      if (st.st_mtime < 0)
	{
	  dk_free_box (fname_cvt);
	  return NULL;
	}
      time_t_to_dt (st.st_mtime, 0, dt);
#endif
      dt_to_string (dt, szTemp, sizeof (szTemp));
    }
  else if (what == 1)
    {
      snprintf (szTemp, sizeof(szTemp), OFF_T_PRINTF_FMT, (OFF_T_PRINTF_DTP) st.st_size);
    }
  else if (what == 2)
    {
      snprintf (szTemp, sizeof (szTemp), "%ld", (long)st.st_mode);
    }
  else if (what == 4)
    {
      dk_free_box (fname_cvt);
#ifdef WIN32
      return os_get_uname_by_fname (fname);
#else
      return os_get_uname_by_uid (st.st_uid);
#endif
    }
  else if (what == 5)
    {
      dk_free_box (fname_cvt);
#ifdef WIN32
      return os_get_gname_by_fname (fname);
#else
      return os_get_gname_by_gid (st.st_gid);
#endif
    }
  else
    {
      dk_free_box (fname_cvt);
      return NULL;
    }

  dk_free_box (fname_cvt);
  return box_dv_short_string (szTemp);
}

caddr_t
file_stat (const char *fname, int what)
{
  caddr_t boxed_fname = box_dv_short_string (fname);
  caddr_t res = file_stat_int (boxed_fname, what);
  dk_free_box (boxed_fname);
  return res;
}


static caddr_t
bif_file_stat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname;
  caddr_t res;
  int what = 0;

  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "file_stat");
  if (BOX_ELEMENTS (args) > 1)
    what = (int) bif_long_arg (qst, args, 1, "file_stat");
  res = file_stat (fname, what);
  return res;
}


static caddr_t
bif_sys_mkdir (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname;
  long rc = -1, errn = 0;
  caddr_t fname_cvt;
  sec_check_dba ((query_instance_t *) qst, "sys_mkdir");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "sys_mkdir");
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  rc = mkdir (fname_cvt, FS_DIR_MODE);
  dk_free_box (fname_cvt);
  if (rc != 0)
    {
      errn = errno;
      if (BOX_ELEMENTS (args) > 1)
	{
	  if (ssl_is_settable (args[1]))
	    qst_set (qst, args[1],
		(caddr_t) box_dv_short_string (virt_strerror (errn)));
	}
      return box_num (errn);
    }
  return box_num (rc);
}


static int
make_path (const char *path, int istest)
{
  char *buf = box_string (path);
  char *p, *pp;
  int ret = 0;
  char cwd[PATH_MAX + 1];

  getcwd (cwd, PATH_MAX);
  buf = box_string (path);
  for (p = buf; NULL != p; p = pp)
    {
      pp = strpbrk (p, "\\/");
      if (NULL != pp)
	*pp++ = '\0';
      if (!istest)
	{
	  if ((!((0 == chdir (p)) || (0 == mkdir (p, FS_DIR_MODE)
			  && 0 == chdir (p)))))
	    {
	      ret = -1;
	      break;
	    }
	}
      else
	{
	  if (!(0 == chdir (p)))
	    {
	      ret = -1;
	      break;
	    }
	}
    }
  chdir (cwd);
  dk_free_box (buf);
  return ret;
}


static caddr_t
bif_sys_mkpath (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname, fname_cvt;
  long istest = 0;
  long rc = -1, errn = 0;
  sec_check_dba ((query_instance_t *) qst, "sys_mkpath");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "sys_mkpath");
  if (BOX_ELEMENTS (args) > 1)
    istest = (long) bif_long_arg (qst, args, 1, "sys_mkpath");
  if (0x1000 < box_length (fname))
    sqlr_new_error ("42000", "FA116",
      "Abnormally long path is passed as argument to sys_mkpath()" );
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  rc = make_path (fname_cvt, istest);
  if (rc != 0)
    {
      errn = errno;
      if (BOX_ELEMENTS (args) > 2)
	{
	  if (ssl_is_settable (args[1]))
	    qst_set (qst, args[1],
		(caddr_t) box_dv_short_string (virt_strerror (errn)));
	}
      rc = errn;
    }
  dk_free_box (fname_cvt);
  return box_num (rc);
}

#ifndef WIN32
#define DIRNAME(de)	 de->d_name
#define CHECKFH(df)	 (df != NULL)
#else
#define DIRNAME(de)	 de->cFileName
#define CHECKFH(df)	 (df != INVALID_HANDLE_VALUE)
#define S_IFLNK	 S_IFREG
#endif

int
str_compare (const void *s1, const void *s2)
{
  ccaddr_t sc1 = (caddr_t) * (caddr_t *) s1;
  ccaddr_t sc2 = (caddr_t) * (caddr_t *) s2;
  dtp_t sc1_dtp = DV_TYPE_OF (sc1);
  dtp_t sc2_dtp = DV_TYPE_OF (sc2);
  int sign;
  if (IS_STRING_DTP (sc1_dtp) && IS_STRING_DTP (sc2_dtp))
    return strcmp (sc1, sc2);
  if ((DV_WIDE == sc1_dtp) && (DV_WIDE == sc2_dtp))
    {
      int len1 = box_length (sc1);
      int len2 = box_length (sc2);
      int cmplen = (len1 < len2) ? len1 : len2;
      int res = memcmp (sc1, sc2, cmplen);
      if ((0 != res) || (len1 == len2))
        return res;
      return (len1 > len2) ? 1 : -1;
    }
  sign = 1;
  if (IS_STRING_DTP (sc1_dtp) && (DV_WIDE == sc2_dtp))
    {
      ccaddr_t swap_sc;
      dtp_t swap_sc_dtp;
      sign = -1;
      swap_sc = sc1; sc1 = sc2; sc2 = swap_sc;
      swap_sc_dtp = sc1_dtp; sc1_dtp = sc2_dtp; sc2_dtp = swap_sc_dtp;
    }
  if ((DV_WIDE == sc1_dtp) && IS_STRING_DTP (sc2_dtp))
    {
      const wchar_t *sc1_tail = (const wchar_t *)sc1;
      const wchar_t *sc1_end = sc1_tail +  ((box_length (sc1) / sizeof (wchar_t)) - 1);
      const char *sc2_tail = sc2;
      const char *sc2_end = sc2_tail + (box_length (sc2) - 1);
      int sc2_is_utf8 = ((DV_UNAME == sc2_dtp) || (BF_UTF8 == box_flags (sc2)));
      while ((sc1_tail < sc1_end) && (sc2_tail < sc2_end))
        {
          int c1 = (sc1_tail++)[0];
          int c2 = sc2_tail[0];
          if (sc2_is_utf8 && (c2 & ~0x7f))
            c2 = eh_decode_char__UTF8 (&sc2_tail, sc2_end);
          else
            sc2_tail++;
          if (c1 > c2) return sign;
          if (c1 < c2) return -sign;
        }
      if (sc1_tail < sc1_end) return sign;
      if (sc2_tail < sc2_end) return -sign;
      return 0;
    }
  GPF_T;
  return 0;
}


/* IvAn/WinFileNames/000815
   1. Descriptor's leaks has removed.
   2. Conversion added for slashes, to make applications more portable.
	  (The OS itself is usually OK by some drivers may be stymied.)
   */
caddr_t
bif_sys_dirlist (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname, fname_cvt;
  long files = 0, errn = 0;
  dk_set_t dir_list = NULL;
#ifndef WIN32
  DIR *df = 0;
  struct dirent *de;
  STAT_T st;
#else
  ptrlong rc = 0;
  WIN32_FIND_DATA fd, *de;
  HANDLE df;
  caddr_t fname_pattern;
  size_t fname_pattern_end;
#endif
  caddr_t lst = NULL;

  sec_check_dba ((query_instance_t *) qst, "sys_dirlist");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "sys_dirlist");
  if (BOX_ELEMENTS (args) > 1)
    files = (long) bif_long_arg (qst, args, 1, "sys_dirlist");
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
#ifndef WIN32
  df = opendir (fname_cvt);
#else
  fname_pattern_end = box_length (fname_cvt);
  while (0 == fname_cvt [fname_pattern_end - 1])
    fname_pattern_end--;
  fname_pattern = dk_alloc_box (fname_pattern_end + 3, DV_STRING);
  memcpy (fname_pattern, fname_cvt, fname_pattern_end);
  if ('\\' != fname_cvt [fname_pattern_end - 1])
    fname_pattern[fname_pattern_end++] = '\\';
  fname_pattern[fname_pattern_end++] = '*';
  fname_pattern[fname_pattern_end] = '\0';
  df = FindFirstFile (fname_pattern, &fd);
#endif
  if (CHECKFH (df))
    {
      do
	{
#ifndef WIN32
	  de = readdir (df);
#else
	  de = NULL;
	  if (rc == 0)
	    de = &fd;
#endif
	  if (de)
	    {
	      if (strlen (fname_cvt) + strlen (DIRNAME (de)) + 1 < PATH_MAX)
		{
                  int hit = 0;
                  caddr_t raw_name;
                  int make_wide_name;
#ifndef WIN32
                  char path [PATH_MAX];
		  snprintf (path, sizeof (path), "%s/%s", fname_cvt, DIRNAME (de));
		  V_STAT (path, &st);
		  if (((st.st_mode & S_IFMT) == S_IFDIR) && files == 0)
		    hit = 1; /* Different values of \c hit are solely for debugging purposes */
		  else if (((st.st_mode & S_IFMT) == S_IFREG) && files == 1)
		    hit = 2;
		  else if (((st.st_mode & S_IFMT) == S_IFLNK) && files == 2)
		    hit = 3;
		  else if (((st.st_mode & S_IFMT) != 0) && files == 3)
		    hit = 4;
#else
                  if (files == 0 && (FILE_ATTRIBUTE_DIRECTORY & de->dwFileAttributes) > 0)
		    hit = 5;
                  else if (files == 1 && (FILE_ATTRIBUTE_DIRECTORY & de->dwFileAttributes) == 0)
		    hit = 6;
                  else if (files == 3)
                    hit = 7;
#endif
                  if (!hit)
                    goto next_file;
                  raw_name = box_dv_short_string (DIRNAME (de));
                  make_wide_name = 0;
                  if (i18n_wide_file_names)
                    {
                      char *tail;
                      for (tail = raw_name; '\0' != tail[0]; tail++)
                        {
                          if ((tail[0] >= ' ') && (tail[0] < 0x7f))
                            continue;
                          make_wide_name = 1;
                          break;
                        }
                    }
                  if (make_wide_name)
                    {
                      int buflen = (box_length (raw_name) - 1) / i18n_volume_encoding->eh_minsize;
                      int state = 0;
                      wchar_t *buf = dk_alloc_box ((buflen+1) * sizeof (wchar_t), DV_WIDE);
                      wchar_t *wide_name;
                      const char *raw_tail = raw_name;
                      int res = i18n_volume_encoding->eh_decode_buffer_to_wchar (
                        buf, buflen, &raw_tail, raw_name + box_length (raw_name) - 1,
                        i18n_volume_encoding, state );
                      if (res < 0)
                        {
                          dk_free_box (raw_name);
                          goto next_file; /*!!! TBD Emergency encoding */
                        }
                      if (res < buflen-1)
                        {
                          wide_name = dk_alloc_box ((res+1) * sizeof (wchar_t), DV_WIDE);
                          memcpy (wide_name, buf, res * sizeof (wchar_t));
                          dk_free_box (buf);
                        }
                      else
                        wide_name = buf;
                      wide_name [res] = 0;
                      dk_set_push (&dir_list, wide_name);
                      dk_free_box (raw_name);
                    }
                  else
                    dk_set_push (&dir_list, raw_name);
		}
	      else
		{
/* This bug is possible only in UNIXes, because it requires the use of links,
   but WIN32 case added too, due to paranoia. */
#ifndef WIN32
		  closedir (df);
#else
		  FindClose (df);
#endif
		  *err_ret = srv_make_new_error ("39000", "FA019", "Path string is too long.");
		  goto error_end;
		}
	    }
next_file: ;
#ifdef WIN32
          rc = FindNextFile (df, &fd) ? 0 : 1;
#endif
	}
      while (de);
#ifndef WIN32
      closedir (df);
#else
      FindClose (df);
#endif
    }
  else
    {
      const char *err_msg;
#ifndef WIN32
      errn = errno;
      err_msg = virt_strerror (errn);
#else
      char msg_buf[200];
      DWORD dw = GetLastError();

      err_msg = &msg_buf[0];
      msg_buf[0] = 0;
      FormatMessage(
        FORMAT_MESSAGE_FROM_SYSTEM,
        NULL,
        dw,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPTSTR) &msg_buf[0], sizeof (msg_buf), NULL);
#endif
      if (BOX_ELEMENTS (args) > 2)
	{
	  if (ssl_is_settable (args[2]))
	    qst_set (qst, args[2],
		(caddr_t) box_dv_short_string (err_msg));
	}
      else
	{
	  *err_ret = srv_make_new_error ("39000", "FA020", "Unable to list files in '%.1000s': %s", fname_cvt, err_msg);
	  goto error_end;
	}
    }
  lst = list_to_array (dk_set_nreverse (dir_list));
  if (BOX_ELEMENTS (args) > 3 && bif_long_arg (qst, args, 3, "sys_dirlist") &&
      IS_BOX_POINTER (lst) && BOX_ELEMENTS (lst))
    qsort (lst, BOX_ELEMENTS (lst), sizeof (caddr_t), str_compare);
error_end:
  dk_free_box (fname_cvt);
#ifdef WIN32
  dk_free_box (fname_pattern);
#endif
  return lst;
}


caddr_t
file_native_name (caddr_t se_name)
{
  caddr_t volume_fname;
#ifdef HAVE_DIRECT_H
  char *fname_tail;
#endif
  switch (DV_TYPE_OF (se_name))
    {
    case DV_WIDE:
      {
	int wchars;
	int bufsize;
	caddr_t buf;
	char *buf_end, *end_of_dat;
	wchars = box_length (se_name) / sizeof (wchar_t) - 1;
	if (wchars > (PATH_MAX * 10))
	  wchars = PATH_MAX * 10;
	bufsize = wchars * i18n_volume_encoding->eh_maxsize;
	buf = dk_alloc_box (bufsize + 1, DV_STRING);
	buf_end = buf + bufsize;
	end_of_dat = i18n_volume_encoding->eh_encode_wchar_buffer (
	    ((const wchar_t *) se_name), ((const wchar_t *) se_name) + wchars, buf, buf_end, i18n_volume_encoding);
	if (end_of_dat == buf_end)
	  {
	    buf_end[0] = '\0';
	    volume_fname = buf;
	  }
	else
	  {
	    volume_fname = box_dv_short_nchars (buf, end_of_dat - buf);
	    dk_free_box (buf);
	  }
	break;
      }
    case DV_STRING:
      {
	long len = box_length (se_name) - 1;
	if (len > PATH_MAX * 30)
	  len = PATH_MAX * 30;
	volume_fname = box_dv_short_nchars (se_name, len);
	break;
      }
    case DV_UNAME:
      if (&eh__UTF8 == i18n_volume_encoding)
	{
	  long len = box_length (se_name) - 1;
	  if (len > PATH_MAX * 30)
	    len = PATH_MAX * 30;
	  volume_fname = box_dv_short_nchars (se_name, len);
	}
      else
	{
	  caddr_t se1, res;
	  long len = box_length (se_name) - 1;
	  if (len > PATH_MAX * 30)
	    len = PATH_MAX * 30;
	  se1 = box_utf8_as_wide_char (se_name, NULL, len, 0, DV_WIDE);
	  res = file_native_name (se1);
	  dk_free_box (se1);
	  return res;
	}
      break;
    default:
      {
	GPF_T1 ("Bad box type for file name");
	volume_fname = NULL;	/* to keep the compiler happy */
      }
    }
#ifdef HAVE_DIRECT_H
  for (fname_tail = volume_fname; fname_tail[0]; fname_tail++)
    {
      switch (fname_tail[0])
	{
	  /* case '|': fname_tail[0] = ':'; break; */
	case '/':
	  fname_tail[0] = '\\';
	  break;
	}
    }
  if ((fname_tail - 1) >= volume_fname && *(fname_tail - 1) == '\\')
    *(fname_tail - 1) = 0;
#endif
  dk_check_tree (volume_fname);
  return volume_fname;
}

caddr_t
file_native_name_from_iri_path_nchars (const char *iri_path, size_t iri_path_len)
{
  caddr_t fname;
#ifdef WIN32
  char *fname_ptr, *fname_end;
  if (iri_path_len >= _MAX_PATH)
    iri_path_len = _MAX_PATH-1;
  fname = box_dv_short_nchars (iri_path, iri_path_len);
  fname_end = fname + iri_path_len;
  for (fname_ptr = fname; fname_ptr < fname_end; fname_ptr++)
    {
      switch (fname_ptr[0])
        {
        case '|':
          fname_ptr[0] = ':';
          break;
        case '/':
          fname_ptr[0] = '\\';
          break;
        }
    }
#else
  fname = box_dv_short_nchars (iri_path, iri_path_len);
#endif
  return fname;
}


/* IvAn/WinFileNames/000815
   1. File descriptor's leaks has removed.
   2. Error handling extended by the case of "failed lseek".
   3. Conversion added for slashes, to make applications more portable.
	  (The OS itself is usually OK but some drivers may be stymied.)
   4. Check added for \c place parameter.
 */
static caddr_t
bif_string_to_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  OFF_T rc;
  int len;
  char *fname, *fname_cvt;
  char *string;
  ptrlong place;
  volatile int fd;
  int saved_errno;
  dtp_t string_dtp;
  caddr_t err = NULL;
  query_instance_t *qi = (query_instance_t *) qst;

  sec_check_dba ((query_instance_t *) qst, "string_to_file");

  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "string_to_file");
  string = bif_arg (qst, args, 1, "string_to_file");
  string_dtp = DV_TYPE_OF (string);
  place = bif_long_arg (qst, args, 2, "string_to_file");
  if (place < -2 /* i.e. (place<0) && (place != -1) */ )
    sqlr_new_error ("22003", "FA021",
	"Third argument of string_to_file function, should be nonnegative offset value, -1 or -2");

  if (!DV_STRINGP (string) && !DV_WIDESTRINGP (string) &&
      !IS_BLOB_HANDLE (string) && string_dtp != DV_C_STRING
      && string_dtp != DV_STRING_SESSION && string_dtp != DV_BIN)
    sqlr_new_error ("22023", "FA022",
	"Function string_to_file needs a string or blob or string_output as argument 2,"
	"not an arg of type %s (%d)", dv_type_title (string_dtp), string_dtp);

  if (box_length (fname) >= PATH_MAX * sizeof (wchar_t))
    {
      char buf[PATH_MAX + 4];
      memcpy (buf, fname, PATH_MAX);
      buf[PATH_MAX] = '\0';
      sqlr_new_error ("39000", "FA039",
	  "File name argument of string_to_file is too long (wrong argument order?): %s...", buf);
    }
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, &err, 0);
  if (NULL != err)
    goto signal_error;
  if (place == -2)
    {
      fd = fd_open (fname_cvt, OPEN_FLAGS | O_TRUNC);
      place = 0;
    }
  else
    fd = fd_open (fname_cvt, OPEN_FLAGS);

  if (fd < 0)
    {
      int errn = errno;
      err = srv_make_new_error ("39000", "FA006", "Can't open file '%.1000s', error : %s",
	  fname_cvt, virt_strerror (errn));
      goto signal_error;
    }

  if (place == -1)
    rc = LSEEK (fd, 0, SEEK_END);
  else
    rc = LSEEK (fd, place, SEEK_SET);

  if (rc == -1)
    {
      saved_errno = errno;
      fd_close (fd, fname);
      err = srv_make_new_error ("39000", "FA025",
	  "Seek error in file '%.1000s', error : %s", fname_cvt, virt_strerror (saved_errno));
      goto signal_error;
    }

  if (string_dtp == DV_STRING_SESSION)
    {
      char buffer[64000];
      int to_read;
      dk_session_t *ses = (dk_session_t *) string;
      int64 len = strses_length (ses), ofs = 0;
      while (ofs < len)
	{
	  int readed;
	  to_read = MIN (sizeof (buffer), len - ofs);
	  if (0 != (readed = strses_get_part (ses, buffer, ofs, to_read)))
	    GPF_T;
	  if (to_read != write (fd, buffer, to_read))
	    {
	      saved_errno = errno;
	      fd_close (fd, fname);
	      err = srv_make_new_error ("39000", "FA026", "Write to '%.1000s' failed (%s)",
		  fname_cvt, virt_strerror (saved_errno) );
              goto signal_error;
	    }
	  ofs += to_read;
	}
    }
  else if (IS_BLOB_HANDLE (string))
    {
      dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);
      volatile int failed = 0;
      tcpses_set_fd (ses->dks_session, fd);

      CATCH_WRITE_FAIL (ses)
	{
	  bh_write_out (qi->qi_trx, (blob_handle_t *) string, ses);
	}
      FAILED
	{
	  failed = 1;
	}
      END_WRITE_FAIL (ses);

      if (failed || SER_SUCC != session_flush (ses))
	{
	  PrpcSessionFree (ses);
	  err = srv_make_new_error ("39000", "FA027", "Write to '%.1000s' failed", fname_cvt);
          goto signal_error;
	}
      else
	PrpcSessionFree (ses);
    }
  else if (DV_WIDESTRINGP (string))
    {
      caddr_t utf8 =
	  box_wide_as_utf8_char (string,
	  box_length (string) / sizeof (wchar_t) - 1, DV_LONG_STRING);
      len = box_length (utf8) - 1;
      if (rc == -1 || (len && write (fd, utf8, len) != len))
	{
	  saved_errno = errno;
	  dk_free_box (utf8);
	  fd_close (fd, fname);
	  err = srv_make_new_error ("39000", "FA028", "Write to '%.1000s' failed (%s)", fname_cvt,
	      virt_strerror (saved_errno) );
          goto signal_error;
	}
      dk_free_box (utf8);
    }
  else
    {
      if (string_dtp != DV_BIN)
        len = box_length (string) - 1;
      else
	len = box_length (string);
      if (rc == -1 || (len && write (fd, string, len) != len))
	{
	  saved_errno = errno;
	  fd_close (fd, fname);
	  err = srv_make_new_error ("39000", "FA029", "Write to '%.1000s' failed (%s)", fname_cvt,
	      virt_strerror (saved_errno) );
          goto signal_error;
	}
    }
  fd_close (fd, fname);
  dk_free_box (fname_cvt);
  return 0;

signal_error:
  dk_free_box (fname_cvt);
  sqlr_resignal (err);
  return NULL;
}

caddr_t
bif_sys_dir_is_allowed (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  caddr_t fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "sys_dir_is_allowed");
  caddr_t fname_cvt = file_native_name (fname);
  int res = ((PATH_MAX >= (box_length (fname_cvt) - 1)) ? is_allowed (fname_cvt) : 0);
  dk_free_box (fname_cvt);
  return box_num (res);
}

static caddr_t
bif_file_delete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int rc = 0, silent;
  caddr_t fname, fname_cvt;
  sec_check_dba ((query_instance_t *) qst, "file_delete");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "file_delete");
  silent =
      BOX_ELEMENTS (args) > 1 ? (int) bif_long_arg (qst, args, 1,
      "file_delete") : 0;
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  rc = unlink (fname_cvt);
  if (rc == -1 && !silent)
    {
      int saved_errno = errno;
      caddr_t err = srv_make_new_error ("39000", "FA045", "Unlink of '%.1000s' failed (%s)",
        fname_cvt, virt_strerror (saved_errno) );
      dk_free_box (fname_cvt);
      sqlr_resignal (err);
    }
  dk_free_box (fname_cvt);
  return box_num (rc);
}

/*##
  Generates a system-dependent temporary file name,
  usually on UNIXes it's in $TMPDIR, /tmp or /var/tmp directory in that order.
  On Windows platforms almost depends of %TMP% environment variable.
  Note that this function does not open the file to check access!
*/
static caddr_t
bif_tmp_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fpref =
      BOX_ELEMENTS (args) > 0 ? bif_string_or_null_arg (qst, args, 0,
      "tmp_file_name") : NULL;
  caddr_t fsuff =
      BOX_ELEMENTS (args) > 1 ? bif_string_arg (qst, args, 1,
      "tmp_file_name") : NULL;
  caddr_t fname = NULL;
  char *tmp, *ppref = fpref;

  if (fpref && strlen (fpref) > 5)
    fpref[5] = 0;

#ifdef WIN32
  tmp = _tempnam (temp_dir, ppref);
#else
  tmp = tempnam (temp_dir, ppref);
#endif
  if (tmp)
    {
      if (fsuff)
	{
	  fname = dk_alloc_box (strlen (tmp) + strlen (fsuff) + 2, DV_STRING);
	  snprintf (fname, box_length (fname), "%s.%s", tmp, fsuff);
	}
      else
	fname = box_dv_short_string (tmp);
#if !defined(WIN32) && !defined(MALLOC_DEBUG)
      /*
       * XXX can't free() if MALLOC_DEBUG is defined
       */
      free (tmp);
#endif
    }
  else
    fname = NEW_DB_NULL;
  return fname;
}


/* returns engine's current ini file path as a short string */
/* if compiled in M2, needs an additional variable in chil.c */
static caddr_t
bif_virtuoso_ini_path (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_dv_short_string (f_config_file);
}


caddr_t
bif_cfg_section_count (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *pszPath;
  int nSections = 0;
  PCONFIG pcfgFile = NULL;

  pszPath = bif_string_arg (qst, args, 0, "cfg_section_count");

  if (cfg_init (&pcfgFile, pszPath))
    sqlr_new_error ("39000", "FA030", "Can't open file %s", pszPath);

  while (cfg_nextentry (pcfgFile) == 0)
    {
      if (cfg_section (pcfgFile))
	nSections++;
    }

  cfg_done (pcfgFile);

  return box_num (nSections);
}


/* returns the number of values in a section				*/
/* arguments :							  */
/*			  String FileName - the file to parse		 */
/*			  String Section  - the section to deal with	  */

caddr_t
bif_cfg_item_count (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *pszPath, *pszSection;
  int nItems = 0;
  int bAtSection = 0;
  PCONFIG pcfgFile = NULL;

  pszPath = bif_string_arg (qst, args, 0, "cfg_item_count");
  pszSection = bif_string_arg (qst, args, 1, "cfg_item_count");

  if (cfg_init (&pcfgFile, pszPath))
    sqlr_new_error ("39000", "FA031", "Can't open file %s", pszPath);

  while (cfg_nextentry (pcfgFile) == 0)
    {
      if (bAtSection)
	{
	  if (cfg_section (pcfgFile))
	    break;
	  else if (cfg_define (pcfgFile))
	    nItems++;
	}
      else if (cfg_section (pcfgFile) &&
	  !stricmp (pcfgFile->section, pszSection))
	bAtSection = 1;
    }

  cfg_done (pcfgFile);

  return box_num (nItems);
}


/* returns the name of the Nth section				  */
/* arguments :							  */
/*			  String FileName - the file to parse		 */
/*			  Integer SectionIndex - the section Index	*/

caddr_t
bif_cfg_section_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *pszPath;
  int nSections = 0;
  long nSectionIndex = 0;
  caddr_t pSectionName = NULL;
  PCONFIG pcfgFile = NULL;

  pszPath = bif_string_arg (qst, args, 0, "cfg_section_name");
  nSectionIndex = (long) bif_long_arg (qst, args, 1, "cfg_section_name");

  if (cfg_init (&pcfgFile, pszPath))
    sqlr_new_error ("39000", "FA032", "Can't open file %s", pszPath);

  while (cfg_nextentry (pcfgFile) == 0)
    {
      if (cfg_section (pcfgFile))
	{
	  if (nSectionIndex == nSections)
	    {
	      pSectionName = box_dv_short_string (pcfgFile->section);
	      break;
	    }
	  nSections++;
	}
    }
  cfg_done (pcfgFile);

  return pSectionName ? pSectionName : NEW_DB_NULL;
}


/* returns the name of the Nth setting in the selected section	  */
/* arguments :							  */
/*			  String FileName - the file to parse		 */
/*			  String SectionName - the section Index	  */
/*			  Integer ItemIndex - the item Index		  */

caddr_t
bif_cfg_item_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *pszPath, *pszSection;
  int nItems = 0;
  int bAtSection = 0;
  long nItemIndex = 0;
  caddr_t pItemName = NULL;
  PCONFIG pcfgFile = NULL;

  pszPath = bif_string_arg (qst, args, 0, "cfg_item_name");
  pszSection = bif_string_arg (qst, args, 1, "cfg_item_name");
  nItemIndex = (long) bif_long_arg (qst, args, 2, "cfg_item_name");

  if (cfg_init (&pcfgFile, pszPath))
    sqlr_new_error ("39000", "FA033", "Can't open file %s", pszPath);

  while (cfg_nextentry (pcfgFile) == 0)
    {
      if (bAtSection)
	{
	  if (cfg_section (pcfgFile))
	    break;
	  if (cfg_define (pcfgFile))
	    {
	      if (nItems == nItemIndex)
		{
		  pItemName = box_dv_short_string (pcfgFile->id);
		  break;
		}
	      nItems++;
	    }
	}
      else if (cfg_section (pcfgFile) &&
	  !stricmp (pcfgFile->section, pszSection))
	bAtSection = 1;
    }

  cfg_done (pcfgFile);

  return pItemName ? pItemName : NEW_DB_NULL;
}


/* returns the value of the named setting in the selected section	   */
/* arguments :							  */
/*			  String FileName - the file to parse		 */
/*			  String SectionName - the section name	  */
/*			  String ItemName - the setting name		  */

caddr_t
bif_cfg_item_value (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *pszPath, *pszSection, *pszItemName;
  caddr_t pItemValue = NULL;
  PCONFIG pcfgFile = NULL;

  pszPath = bif_string_arg (qst, args, 0, "cfg_item_value");
  pszSection = bif_string_arg (qst, args, 1, "cfg_item_value");
  pszItemName = bif_string_arg (qst, args, 2, "cfg_item_value");

  if (cfg_init (&pcfgFile, pszPath))
    sqlr_new_error ("39000", "FA034", "Can't open file %s", pszPath);

  if (cfg_find (pcfgFile, pszSection, pszItemName) == 0)
    pItemValue = box_dv_short_string (pcfgFile->value);

  cfg_done (pcfgFile);

  return pItemValue ? pItemValue : NEW_DB_NULL;
}


static PCONFIG _bif_pconfig = NULL;

caddr_t
bif_virtuoso_ini_item_value (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *pszSection, *pszItemName;
  char *pItemValue = NULL;

  pszSection = bif_string_arg (qst, args, 0, "virtuoso_ini_item_value");
  pszItemName = bif_string_arg (qst, args, 1, "virtuoso_ini_item_value");

  if (!_bif_pconfig || cfg_refresh (_bif_pconfig) < 0)
    sqlr_new_error ("39000", "FA055", "Could not open %s ", f_config_file);

  if (cfg_find (_bif_pconfig, pszSection, pszItemName) == 0)
    pItemValue = box_dv_short_string (_bif_pconfig->value);

  return pItemValue ? pItemValue : NEW_DB_NULL;
}


/* sets the value of the named setting in the selected section	  */
/* arguments :							  */
/*			  String FileName - the file to parse		 */
/*			  String SectionName - the section Index	  */
/*			  String ItemName - the setting name		  */
/*			  String ItemValue - the setting value		*/

caddr_t
bif_cfg_write (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PCONFIG pcfgFile = NULL;
  char *pszPath, *pszSection, *pszItemName, *pszItemValue;

  sec_check_dba ((query_instance_t *) qst, "cfg_write");	/* allowed only for dba group */

  pszPath = bif_string_arg (qst, args, 0, "cfg_write");
  pszSection = bif_string_arg (qst, args, 1, "cfg_write");
  pszItemName = bif_string_arg (qst, args, 2, "cfg_write");
  pszItemValue = bif_string_arg (qst, args, 3, "cfg_write");

  if (cfg_init2 (&pcfgFile, pszPath, 1))
    sqlr_new_error ("39000", "FA035", "Can't open file %s", pszPath);

  if (!strlen (pszItemValue))
    pszItemValue = NULL;

  if (!strlen (pszItemName))
    pszItemName = NULL;

  if (!strlen (pszSection))
    pszSection = NULL;

  if (pszSection && pszItemName
      && STR_EQUAL (pszSection, "Parameters")
      && (STR_EQUAL (pszItemName, "DirsAllowed")
	  || STR_EQUAL (pszItemName, "DirsDenied")))
    sqlr_new_error ("42000", "FA036",
	"Allow & deny file ACL cannot be modified");

  if (pszSection && pszItemName
      && STR_EQUAL (pszSection, "Parameters")
      && (STR_EQUAL (pszItemName, "SafeExecutables")
	  || STR_EQUAL (pszItemName, "DbaExecutables")))
    sqlr_new_error ("42000", "FA038",
	"Lists of allowed executables cannot be modified");

  if (pszSection && pszItemName
      && STR_EQUAL (pszSection, "Parameters")
      && STR_EQUAL (pszItemName, "AllowOSCalls"))
    sqlr_new_error ("42000", "FA038", "The flag for enable/disable system call cannot be modified");

  if (cfg_write (pcfgFile, pszSection, pszItemName, pszItemValue) == -1 ||
      cfg_commit (pcfgFile) == -1)
    sqlr_new_error ("39000", "FA037", "Can't update %s", pszPath);

  cfg_done (pcfgFile);

  return 0;
}

/* UUIDs generator */
#define UUIDS_PER_TICK 1024

/*  64 bit data type */
#ifdef WIN32
#define unsigned64_t unsigned __int64
#elif SIZEOF_LONG_LONG == 8
#define unsigned64_t unsigned long long
#elif SIZEOF_LONG == 8
#define unsigned64_t unsigned long
#endif

#define UUID_STATE "uuid_state"

typedef unsigned64_t uuid_time_t;

typedef struct
{
  char nodeID[6];
} uuid_node_t;

#undef uuid_t
typedef struct _uuid_t
{
  uint32 time_low;
  uint16 time_mid;
  uint16 time_hi_and_version;
  unsigned char clock_seq_hi_and_reserved;
  unsigned char clock_seq_low;
  unsigned char node[6];
} detailed_uuid_t;
#define uuid_t detailed_uuid_t


/* data type for UUID generator persistent state */

typedef struct
{
  uuid_node_t node;		/* saved node ID */
  unsigned short cs;		/* saved clock sequence */
} uuid_state;

static void get_system_time (uuid_time_t * uuid_time);
static void get_random_info (unsigned char seed[16]);

/* format_uuid_v1 -- make a UUID from the timestamp, clockseq, and node ID */
static void
format_uuid_v1 (uuid_t * uuid, unsigned short clock_seq,
    uuid_time_t timestamp, uuid_node_t node)
{
  uuid->time_low = (unsigned long) (timestamp & 0xFFFFFFFF);
  uuid->time_mid = (unsigned short) ((timestamp >> 32) & 0xFFFF);
  uuid->time_hi_and_version = (unsigned short) ((timestamp >> 48) & 0x0FFF);
  uuid->time_hi_and_version |= (1 << 12);
  uuid->clock_seq_low = clock_seq & 0xFF;
  uuid->clock_seq_hi_and_reserved = (clock_seq & 0x3F00) >> 8;
  uuid->clock_seq_hi_and_reserved |= 0x80;
  memcpy (&uuid->node, &node, sizeof uuid->node);
}

static void
get_current_time (uuid_time_t * timestamp)
{
  uuid_time_t time_now;
  static uuid_time_t time_last;
  static unsigned short uuids_this_tick;
  static int inited = 0;

  if (!inited)
    {
      get_system_time (&time_last);
      uuids_this_tick = 0;
      inited = 1;
    }
  while (1)
    {
      get_system_time (&time_now);

      /* if clock reading changed since last UUID generated... */
      if (time_last != time_now)
	{
	  /* reset count of uuids gen'd with this clock reading */
	  time_last = time_now;
	  uuids_this_tick = 0;
	  break;
	};
      if (uuids_this_tick < UUIDS_PER_TICK)
	{
	  uuids_this_tick++;
	  break;
	};			/* going too fast for our clock; spin */
    };				/* add the count of uuids to low order bits of the clock reading */

  *timestamp = time_now + uuids_this_tick;
}

static unsigned short
true_random (void)
{
  uuid_time_t time_now;

  get_system_time (&time_now);
  time_now = time_now / UUIDS_PER_TICK;
  srand ((unsigned int) (((time_now >> 32) ^ time_now) & 0xffffffff));
  return rand ();
}

static void
get_pseudo_node_identifier (uuid_node_t * node)
{
  unsigned char seed[16];
  get_random_info (seed);
  seed[0] |= 0x80;
  memcpy (node, seed, sizeof (*node));
}

/* system dependent call to get the current system time.
   Returned as 100ns ticks since Oct 15, 1582, but resolution may be
   less than 100ns.  */
#ifdef WIN32
static void
get_system_time (uuid_time_t * uuid_time)
{
  ULARGE_INTEGER time;
  GetSystemTimeAsFileTime ((FILETIME *) & time);
  /* NT keeps time in FILETIME format which is 100ns ticks since
     Jan 1, 1601.  UUIDs use time in 100ns ticks since Oct 15, 1582.
     The difference is 17 Days in Oct + 30 (Nov) + 31 (Dec)
     + 18 years and 5 leap days.        */
  time.QuadPart += (unsigned __int64) (1000 * 1000 * 10)	/* seconds */
      * (unsigned __int64) (60 * 60 * 24)	/* days */
      * (unsigned __int64) (17 + 30 + 31 + 365 * 18 + 5);	/* # of days */
  *uuid_time = time.QuadPart;
}

static void
get_random_info (unsigned char seed[16])
{
  MD5_CTX c;
  struct
  {
    MEMORYSTATUS m;
    SYSTEM_INFO s;
    FILETIME t;
    LARGE_INTEGER pc;
    DWORD tc;
    DWORD l;
    char hostname[MAX_COMPUTERNAME_LENGTH + 1];
  } r;

  memset (&c, 0, sizeof (MD5_CTX));
  MD5Init (&c);			/* memory usage stats */
  GlobalMemoryStatus (&r.m);	/* random system stats */
  GetSystemInfo (&r.s);		/* 100ns resolution (nominally) time of day */
  GetSystemTimeAsFileTime (&r.t);	/* high resolution performance counter */
  QueryPerformanceCounter (&r.pc);	/* milliseconds since last boot */
  r.tc = GetTickCount ();
  r.l = MAX_COMPUTERNAME_LENGTH + 1;

  GetComputerName (r.hostname, &r.l);
  MD5Update (&c, (unsigned char *) &r, sizeof (r));
  MD5Final (seed, &c);
}

#else /* UNIX */
static void
get_system_time (uuid_time_t * uuid_time)
{
  struct timeval tp;
  gettimeofday (&tp, (struct timezone *) 0);
  /* Offset between UUID formatted times and Unix formatted times.
     UUID UTC base time is October 15, 1582.
     Unix base time is January 1, 1970.   */
  *uuid_time =
      ((uuid_time_t) (tp.tv_sec) * 10000000) +
      ((uuid_time_t) (tp.tv_usec) * 10) + 0x01B21DD213814000LL;
}

static void
get_random_info (unsigned char seed[16])
{
  MD5_CTX c;

  struct
  {
    pid_t pid;
    struct timeval t;
    char hostname[257];
  } r;

  memset (&c, 0, sizeof (MD5_CTX));
  MD5Init (&c);
  r.pid = getpid ();
  gettimeofday (&r.t, (struct timezone *) 0);
  gethostname (r.hostname, 256);
  MD5Update (&c, (unsigned char *) &r, sizeof (r));
  MD5Final (seed, &c);
}
#endif /* end system specific routines */
/* end UUIDs generator */

static uuid_state *ustate = NULL;

void
uuid_set (uuid_t * u)
{
  uuid_time_t timestamp;
  char p[200];

  if (!ustate)
    {
#if 1
      caddr_t saved_state;
      unsigned char node[sizeof (uuid_node_t)];
      ustate = (uuid_state *) dk_alloc (sizeof (uuid_state));
      IN_TXN;
      saved_state = registry_get (UUID_STATE);
      if (!saved_state)
	{
	  ustate->cs = true_random ();
	  get_pseudo_node_identifier (&ustate->node);
#ifdef VALGRIND
	  memset (node, 0, sizeof (node));
#endif
	  memcpy (node, &ustate->node, sizeof (uuid_node_t));
	  snprintf (p, sizeof (p), "%d %02X%02X%02X%02X%02X%02X", ustate->cs,
	      (unsigned)(node[0]), (unsigned)(node[1]), (unsigned)(node[2]),
	      (unsigned)(node[3]), (unsigned)(node[4]), (unsigned)(node[5]) );
	  registry_set (UUID_STATE, p);
	}
      else
	{
	  int cs;
	  unsigned n1[sizeof (uuid_node_t)];
	  sscanf (saved_state, "%d %02X%02X%02X%02X%02X%02X", &cs,
	      &n1[0], &n1[1], &n1[2], &n1[3], &n1[4], &n1[5]);
	  node[0] = n1[0];
	  node[1] = n1[1];
	  node[2] = n1[2];
	  node[3] = n1[3];
	  node[4] = n1[4];
	  node[5] = n1[5];
	  ustate->cs = cs;
	  memcpy (&ustate->node, node, sizeof (uuid_node_t));
	  dk_free_box (saved_state);
	}
      LEAVE_TXN;
#else
      ustate = dk_alloc (sizeof (uuid_state));
      ustate->cs = true_random ();
      get_pseudo_node_identifier (&ustate->node);
#endif
    }

  get_current_time (&timestamp);
  format_uuid_v1 (u, ustate->cs, timestamp, ustate->node);

  return;
}

void
uuid_str (char *p, int len)
{
  uuid_t u;

  memset (&u, 0, sizeof (uuid_t));
  uuid_set (&u);

  snprintf (p, len, "%08lX-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X",
      (unsigned long) u.time_low, u.time_mid, u.time_hi_and_version,
      u.clock_seq_hi_and_reserved, u.clock_seq_low,
      u.node[0], u.node[1], u.node[2], u.node[3], u.node[4], u.node[5]);
}

static caddr_t
bif_uuid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char p[200];
  uuid_str (p, sizeof (p));
  return box_dv_short_string (p);
}

static const char __tohex[] = "0123456789abcdef";
caddr_t
md5 (caddr_t str)
{
  int inx;
  caddr_t res;
  unsigned char digest[16];
  MD5_CTX ctx;

  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  MD5Update (&ctx, (unsigned char *) str, box_length (str) - 1);
  MD5Final (digest, &ctx);
  res = dk_alloc_box (sizeof (digest) * 2 + 1, DV_SHORT_STRING);
  for (inx = 0; inx < sizeof (digest); inx++)
    {
      unsigned c = (unsigned) digest[inx];
      res[inx * 2] = __tohex[0xf & (c >> 4)];
      res[inx * 2 + 1] = __tohex[c & 0xf];
/*was      sprintf (res + inx * 2, "%02x", (unsigned int) digest[inx]); */
    }
  res[sizeof (digest) * 2] = '\0';
  return res;
}

caddr_t
mdigest5 (caddr_t str)
{
  caddr_t res;
  MD5_CTX ctx;

  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  MD5Update (&ctx, (unsigned char *) str, box_length (str) - 1);
  res = dk_alloc_box (17, DV_SHORT_STRING);
  res[16] = '\0';
  MD5Final ((unsigned char *)res, &ctx);
  return res;
}

caddr_t
md5ctx_to_string (MD5_CTX * pctx)
{
  int inx;
  caddr_t res;
  res = dk_alloc_box (sizeof (MD5_CTX) * 2 + 1, DV_SHORT_STRING);
  for (inx = 0; inx < sizeof (MD5_CTX); inx++)
    {
      unsigned c = (unsigned) ((char *) pctx)[inx];
      res[inx * 2] = __tohex[0xf & (c >> 4)];
      res[inx * 2 + 1] = __tohex[c & 0xf];
    }
  res[sizeof (MD5_CTX) * 2] = '\0';
  return res;
}


int
string_to_md5ctx (MD5_CTX * pctx, caddr_t str)
{
  int inx;
  if (box_length (str) < sizeof (MD5_CTX) * 2)
    sqlr_new_error ("42000", "SR435",
	"Attempt to deserialize too short md5 context.");

  for (inx = 0; inx < sizeof (MD5_CTX); inx++)
    {
      int l1 = -1, l2 = -1;
      char *p;
      p = strchr (__tohex, str[inx * 2]);
      if (NULL != p)
	l1 = (int) (p - __tohex);
      p = strchr (__tohex, str[inx * 2 + 1]);
      if (NULL != p)
	l2 = (int) (p - __tohex);
      if (l1 < 0 || l2 < 0)
	sqlr_new_error ("42000", "SR436",
	    "Attempt to deserialize incorrect md5 context.");
      ((char *) pctx)[inx] = (l1 << 4) + l2;
    }
  return 0;
}

static caddr_t
bif_md5_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  MD5_CTX ctx;
  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  return md5ctx_to_string (&ctx);
}

void
md5_update_map (buffer_elt_t * buf, caddr_t arg)
{
  MD5_CTX *pctx = (MD5_CTX *) arg;
  MD5Update (pctx, (unsigned char *) buf->data, buf->fill);
}

static caddr_t
bif_md5_update (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  MD5_CTX ctx;
  caddr_t sctx = bif_string_arg (qst, args, 0, "md5_update");
  caddr_t str = bif_arg (qst, args, 1, "md5_update");
  dtp_t dtp = DV_TYPE_OF (str);
  if (DV_STRING == dtp)
    str = bif_string_arg (qst, args, 1, "md5_update");
  else
    str = bif_strses_arg (qst, args, 1, "md5_update");

  string_to_md5ctx (&ctx, sctx);
  if (DV_STRING == dtp)
    MD5Update (&ctx, (unsigned char *) str, box_length (str) - 1);
  else
    {
      dk_session_t * ses = (dk_session_t *) str;
      strses_map (ses, md5_update_map, (caddr_t) & ctx);
      strses_file_map (ses, md5_update_map, (caddr_t) & ctx);
      MD5Update (&ctx, (unsigned char *) ses->dks_out_buffer, ses->dks_out_fill);
    }
  return md5ctx_to_string (&ctx);
}

static caddr_t
bif_md5_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  caddr_t res;
  MD5_CTX ctx;
  unsigned char digest[MD5_SIZE];
  caddr_t sctx = bif_string_arg (qst, args, 0, "md5_final");
  int make_it_hex = 1;
  string_to_md5ctx (&ctx, sctx);
  if (BOX_ELEMENTS (args) > 1)
    make_it_hex = (int) bif_long_arg (qst, args, 1, "md5_final");
  if (make_it_hex)
    {
      MD5Final (digest, &ctx);
      res = dk_alloc_box (sizeof (digest) * 2 + 1, DV_SHORT_STRING);

      for (inx = 0; inx < sizeof (digest); inx++)
	{
	  unsigned c = (unsigned) digest[inx];
	  res[inx * 2] = __tohex[0xf & (c >> 4)];
	  res[inx * 2 + 1] = __tohex[c & 0xf];
	}
      res[sizeof (digest) * 2] = '\0';
    }
  else
    {
      res = dk_alloc_box (MD5_SIZE + 1, DV_SHORT_STRING);
      MD5Final ((unsigned char *) res, &ctx);
      res[MD5_SIZE] = 0;
    }
  return res;
}


caddr_t
md5_ses (dk_session_t * ses)
{
  int inx;
  caddr_t res;
  unsigned char digest[16];
  MD5_CTX ctx;

  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  strses_map (ses, md5_update_map, (caddr_t) & ctx);
  strses_file_map (ses, md5_update_map, (caddr_t) & ctx);
  MD5Update (&ctx, (unsigned char *) ses->dks_out_buffer, ses->dks_out_fill);
  MD5Final (digest, &ctx);

  res = dk_alloc_box (sizeof (digest) * 2 + 1, DV_SHORT_STRING);
  for (inx = 0; inx < sizeof (digest); inx++)
    {
      unsigned c = (unsigned) digest[inx];
      res[inx * 2] = __tohex[0xf & (c >> 4)];
      res[inx * 2 + 1] = __tohex[c & 0xf];
    }
  res[sizeof (digest) * 2] = '\0';
/* was:  for (inx = 0; inx < sizeof (digest); inx++)
    sprintf (res + inx * 2, "%02x", (unsigned int) digest[inx]); */

  return res;
}

static caddr_t
bif_md5 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t data = (caddr_t) bif_arg (qst, args, 0, "md5");
  dtp_t dtp = DV_TYPE_OF (data);
  if (DV_STRING_SESSION == dtp)
    {
      return md5_ses ((dk_session_t *) data);
    }
  else if (DV_BIN == DV_TYPE_OF (data))
    {
      dk_session_t * ses = strses_allocate();
      ptrlong len = box_length (data);
      caddr_t res;
      CATCH_WRITE_FAIL(ses)
	{
	  session_buffered_write (ses, data, len);
	}
      FAILED
	{
	  return NEW_DB_NULL;
	}
      END_READ_FAIL (ses);
      res = md5_ses (ses);
      strses_free (ses);
      return res;
    }
  else
    {
      caddr_t str = bif_string_or_uname_arg (qst, args, 0, "md5");
      return md5 (str);
    }
}

static caddr_t
bif_mdigest5 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_uname_arg (qst, args, 0, "mdigest5");
  return mdigest5 (str);
}

#define MOD_ADLER 65521
#define ADLER_MAX_BLOCK_LEN 5550
#define MOD_ADLER_WRAP(x) x = (x & 0xffff) | ((x >> 16) * (65536 - MOD_ADLER))

int
adler32_of_buffer (unsigned char *data, size_t len)
{
  unsigned lo = 1, hi = 0;
  while (len)
   {
      size_t block_len = ((len > ADLER_MAX_BLOCK_LEN) ? ADLER_MAX_BLOCK_LEN : len);
      len -= block_len;
      while (block_len--)
        {
          lo += (data++)[0];
          hi += lo;
        }
      MOD_ADLER_WRAP(lo);
      MOD_ADLER_WRAP(hi);
    }
  MOD_ADLER_WRAP(hi); /* hi grows obviously faster than lo so it needs one more wrap */
  if (lo >= MOD_ADLER)
    lo -= MOD_ADLER;
  if (hi >= MOD_ADLER)
    hi -= MOD_ADLER;
  return ((hi << 16) | lo);
}

static caddr_t
bif_adler32 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char *data = (unsigned char *) bif_string_arg (qst, args, 0, "adler32");
  size_t len = box_length (data) - 1;
  return box_num (adler32_of_buffer (data, len));
}

static caddr_t
bif_tridgell32 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char *data = (unsigned char *) bif_string_arg (qst, args, 0, "tridgell32");
  long make_num = ((1 < BOX_ELEMENTS (args)) ? bif_long_arg (qst, args, 1, "tridgell32") : 0);
  size_t len = box_length (data) - 1;
  unsigned lo = 0, hi = 0, res;
  unsigned char *tail, *end = data + len - 1;
  for (tail = data; tail < end; tail++)
   {
     lo += tail[0];
     hi += lo;
   }
  res = (hi << 16) | (lo & 0xFFFF);
  if (!make_num)
    {
      unsigned char *buf = (unsigned char *)dk_alloc_box (7, DV_STRING);
      buf[6] = '\0';
      buf[5] = 64 + (res & 0x3F);
      buf[4] = 64 + ((res >> 2) & 0x3F);
      buf[3] = 64 + ((res >> 8) & 0x3F);
      buf[2] = 64 + ((res >> 14) & 0x3F);
      buf[1] = 64 + ((res >> 20) & 0x3F);
      buf[0] = 64 + ((res >> 26) & 0x3F);
      return (void *)buf;
    }
  return box_num (res);
}

int32 do_os_calls = 0;
#ifdef WIN32
char *command_cmd = NULL;

static int
win32_system (char *cmd)
{
  caddr_t new_cmd =
      dk_alloc_box (strlen (command_cmd) + strlen (cmd) + 5, DV_SHORT_STRING);
  PROCESS_INFORMATION ps;
  STARTUPINFO si;
  BOOL bRet = FALSE;
  strcpy_box_ck (new_cmd, command_cmd);
  strcat_box_ck (new_cmd, " /C ");
  strcat_box_ck (new_cmd, cmd);
  ZeroMemory (&si, sizeof (si));
  ZeroMemory (&ps, sizeof (ps));
  si.cb = sizeof (si);
  if (!CreateProcess (command_cmd, new_cmd, NULL, NULL,	/* security attrs */
	  FALSE,		/* inherit handles */
	  CREATE_DEFAULT_ERROR_MODE | CREATE_NEW_CONSOLE,	/* flags */
	  NULL,			/* environment */
	  NULL,			/* current dir */
	  &si, &ps))
    {
      dk_free_box (new_cmd);
      return (-1);
    }
  dk_free_box (new_cmd);
  WaitForSingleObject (ps.hProcess, INFINITE);
  CloseHandle (ps.hProcess);
  CloseHandle (ps.hThread);
  return 0;
}

static void
win32_system_init ()
{
  if (do_os_calls)
    {
      command_cmd = getenv ("COMSPEC");
      if (!command_cmd)
	command_cmd = "COMMAND";
    }
}

#endif

static caddr_t
bif_system (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t cmd = bif_string_arg (qst, args, 0, "system");
  long nRetCode = -1;
  if (do_os_calls)
    {
      sec_check_dba ((query_instance_t *) qst, "system");
#ifdef WIN32
      nRetCode = win32_system (cmd);
#else
      nRetCode = system (cmd);
#endif
    }
  else
    sqlr_new_error ("42000", "SR092",
	"system call not allowed on this server");
  return box_num (nRetCode);
}

static caddr_t
bif_run_executable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t exe_name = bif_string_arg (qst, args, 0, "run_executable");
  int wait = (int) bif_long_arg (qst, args, 1, "run_executable");
  client_connection_t *cli = ((query_instance_t *) (qst))->qi_client;
#define MAXARGS 32
  char full_exe_name[PATH_MAX + 1];
  caddr_t exe_args[MAXARGS + 1];	/* "+1" is here because _spawnv will search for trailing NULL in arglist */
  int retcode;
#ifndef WIN32
  int errcode;
#endif
  int argc = BOX_ELEMENTS (args);
  int ctr;
  int safety = 0;
#ifndef WIN32
  pid_t child_pid;
  int status;
#endif
  STAT_T st;


  if (2 + MAXARGS < argc)
    sqlr_new_error ("42000", "SR404",
	"Too many arguments for run_executable");
  memset (exe_args, 0, sizeof (exe_args));
  for (ctr = 2; ctr < argc; ctr++)
    exe_args[ctr - 1] = bif_string_arg (qst, args, ctr, "run_executable");
  if (NULL == rel_to_abs_path (full_exe_name, exe_name,
	  sizeof (full_exe_name)
#ifdef WIN32
	  - 4 /* sizeof (".exe" added below */
#endif
	  ))
    sqlr_new_error ("42000", "SR405",
	"Invalid executable name '%s' in run_executable()", exe_name);
  DO_SET (caddr_t, known_name, &safe_execs_set)
    {
      if (0 == strcmp (full_exe_name, known_name))
        {
          safety = 2;
          break;
        }
    }
  END_DO_SET ();
  if (0 == safety)
    {
      DO_SET (caddr_t, known_name, &dba_execs_set)
        {
          if (0 == strcmp (full_exe_name, known_name))
            {
              safety = 1;
              break;
            }
        }
      END_DO_SET ();
      if (0 == safety)
	sqlr_new_error ("42000", "SR406",
	    "Running of file '%s' is not allowed in run_executable().",
	    full_exe_name);
      if ((1 == safety) && (NULL != cli->cli_user)
	  && (0 == sec_user_has_group (0, cli->cli_user->usr_g_id)))
	sqlr_new_error ("42000", "SR407",
	    "Running of file '%s' is restricted to dba group.",
	    full_exe_name);
    }
#ifdef WIN32
  strcat_ck (full_exe_name, ".exe");
#endif
  if (-1 == V_STAT (full_exe_name, &st))
    {
      sqlr_new_error ("42000", "SR408",
	  "Required executable '%s' does not exist, error %d", full_exe_name,
	  errno);
    }
  exe_args[0] = full_exe_name;
#ifdef WIN32
#if 1
  {
    PROCESS_INFORMATION ps;
    STARTUPINFO si;
    int i;
    size_t len = 0;
    caddr_t new_cmd;

    argc = BOX_ELEMENTS (args);
    for (i = 0; i < argc - 1; i++)
      len += strlen (exe_args[i]) + 1;

    new_cmd = dk_alloc_box_zero (len + 1, DV_SHORT_STRING);
    for (i = 0; i < argc - 1; i++)
      {
	strcat_box_ck (new_cmd, exe_args[i]);
	if (i < argc - 2)
	  strcat_box_ck (new_cmd, " ");
      }
    ZeroMemory (&si, sizeof (si));
    ZeroMemory (&ps, sizeof (ps));
    si.cb = sizeof (si);
    if (!CreateProcess (NULL, new_cmd, NULL, NULL,	/* security attrs */
	    FALSE,		/* inherit handles */
	    CREATE_DEFAULT_ERROR_MODE | CREATE_NO_WINDOW,	/* flags */
	    NULL,		/* environment */
	    NULL,		/* current dir */
	    &si, &ps))
      {
	char buf[80];
	snprintf (buf, sizeof (buf), "Windows Last Error is %d", GetLastError ());
	dk_free_box (new_cmd);
	sqlr_new_error ("42000", "SR409", buf);
	return box_num (-1);
      }
    dk_free_box (new_cmd);
    if (wait)
      {

	WaitForSingleObject (ps.hProcess, INFINITE);
	GetExitCodeProcess (ps.hProcess, &retcode);
      }
    CloseHandle (ps.hProcess);
    CloseHandle (ps.hThread);
  }
#else
  retcode = _spawnv ((wait ? _P_WAIT : _P_NOWAIT), full_exe_name, exe_args);
  if (-1 == retcode)
    {
      errcode = errno;
      switch (errcode)
	{
	case E2BIG:
	  sqlr_new_error ("42000", "SR410",
	      "Argument list exceeds 1024 bytes in run_executable()");
	case EINVAL:
	  sqlr_new_error ("42000", "SR411",
	      "Mode argument is invalid for host OS in run_executable()");
	case ENOENT:
	  sqlr_new_error ("42000", "SR412",
	      "File or path '%s' is not found in run_executable()",
	      full_exe_name);
	case ENOEXEC:
	  sqlr_new_error ("42000", "SR413",
	      "Specified file '%s' is not executable or has invalid executable-file format in run_executable()",
	      full_exe_name);
	case ENOMEM:
	  sqlr_new_error ("42000", "SR414",
	      "Not enough memory is available to execute new process '%s' in run_executable()",
	      full_exe_name);
	default:
	  sqlr_new_error ("42000", "SR415",
	      "Generic error (%d/%s) in run_executable('%s',%d,...)", errcode,
	      virt_strerror (errcode), exe_name, wait);
	}
    }
#endif
#else
  mutex_enter (run_executable_mtx);
  child_pid = fork ();
  if (-1 == child_pid)
    {
      errcode = errno;
      mutex_leave (run_executable_mtx);
      switch (errcode)
	{
	case EAGAIN:
	case ENOMEM:
	  sqlr_new_error ("42000", "SR416",
	      "Not enough memory is available to execute new process '%s' in run_executable()",
	      full_exe_name);
	default:
	  sqlr_new_error ("42000", "SR417",
	      "Generic error (%d/%s) in run_executable('%s',%d,...)", errcode,
	      virt_strerror (errcode), exe_name, wait);
	}
    }
  if (0 == child_pid)
    {
      for (ctr = 3; ctr < 128; ctr++)
	close (ctr);
      retcode = execv (full_exe_name, exe_args);
      _exit (retcode);
    }
  for (;;)
    {
      if (!wait)
	{
	  retcode = status = 0;
	  break;
	}
      retcode = waitpid (child_pid, &status, 0);
      if ((-1 != retcode) || (EINTR != errno))
	break;
    }
  if (-1 == retcode)
    {
      errcode = errno;
      mutex_leave (run_executable_mtx);
      switch (errcode)
	{
	case EACCES:
	  sqlr_new_error ("42000", "SR418",
	      "Permission is denied for the file '%s' in run_executable()",
	      full_exe_name);
	case EPERM:
	  sqlr_new_error ("42000", "SR419",
	      "Permission is denied for the file '%s' due to SUID regulations in run_executable()",
	      full_exe_name);
	case E2BIG:
	  sqlr_new_error ("42000", "SR420",
	      "Argument list is too big in run_executable()");
	case EINVAL:
	  sqlr_new_error ("42000", "SR421",
	      "Mode argument is invalid for host OS in run_executable()");
	case ENOENT:
	  sqlr_new_error ("42000", "SR422",
	      "File or path '%s' is not found in run_executable()",
	      full_exe_name);
	case ENOEXEC:
	  sqlr_new_error ("42000", "SR423",
	      "Specified file '%s' is not executable or has invalid executable-file format in run_executable()",
	      full_exe_name);
	case ENOMEM:
	  sqlr_new_error ("42000", "SR424",
	      "Not enough memory is available to execute new process '%s' in run_executable()",
	      full_exe_name);
	default:
	  sqlr_new_error ("42000", "SR425",
	      "Generic error (%d/%s) in run_executable('%s',%d,...)", errcode,
	      virt_strerror (errcode), exe_name, wait);
	}
    }
  retcode = WIFEXITED (status) ? WEXITSTATUS (status) : -1;
  mutex_leave (run_executable_mtx);
#endif
  return box_num (retcode);
}

#include "libutil.h"
#define CR '\x0D'
#define LF '\x0A'
#define SPACE '\x20'
#define HTAB  '\x09'

#define iswhite_nts(x) (*(x) == SPACE || *(x) == HTAB)
#define isendline_nts(x) (*(x) && (*(x) == CR || *(x) == LF))
#define iswhite(x) ((((x) - szMessage - offset) < message_size) && iswhite_nts(x))
#define isendline(x) ((((x) - szMessage - offset) < message_size) && isendline_nts(x))

#define SKIP_SPACE(x) \
while (iswhite(x)) x++

static void *
mime_memmem (const void *haystack, size_t haystack_len,
    const void *needle, size_t needle_len)
{
  register const char *begin;
  register const char *last_possible =
      (const char *) haystack + haystack_len - needle_len - 2;

  if (haystack_len < needle_len)
    return NULL;

  if (needle_len == 0)
    return (void *) haystack;

  for (begin = (const char *) haystack; begin <= last_possible; ++begin)
    if (isendline_nts (begin) && begin[1] == '-' && begin[2] == '-' &&
	begin[3] == ((const char *) needle)[0] &&
	!memcmp ((const void *) &begin[4],
	    (const void *) ((const char *) needle + 1), needle_len - 1))
      return (void *) (begin + 3);

  return NULL;
}


static long
mime_get_line (char *szMessage, long message_size, long offset, char *_szDest,
    int max_len)
{
  char *szSrc = szMessage + offset, *szDest = _szDest;
  size_t line_len;

  *_szDest = 0;

  while (*szSrc)
    {
      if (*szSrc == CR)
	{			/* unfolding like RFC 822 */
	  line_len = szSrc - szMessage - offset;
	  szSrc++;
	  /* This was while, but it will unfold a CRLF 0xOA0XFF to 0xFF
	     and binary attachment will be broken */
	  if (szSrc - szMessage - offset < message_size && *(szSrc) == LF)
	    szSrc++;
	  if (!iswhite (szSrc) || !line_len)
	    break;
	}
      else if (*szSrc == LF)
	{			/* unfolding like RFC 822  but also for LFCR as for CRLF */
	  line_len = szSrc - szMessage - offset;
	  szSrc++;
	  /* This was while, but it will unfold a LFCR 0xOD0XFF to 0xFF
	     and binary attachment will be broken */
	  if (szSrc - szMessage - offset < message_size && *(szSrc) == CR)
	    szSrc++;
	  if (!iswhite (szSrc) || !line_len)
	    break;
	}
      if (szDest - _szDest < max_len - 1)
	*szDest++ = *szSrc++;
      else
	szSrc++;
    }

  if (szDest - _szDest < max_len)
    *szDest = 0;

  return (long) (szSrc - szMessage);
}


int
mime_get_attr (char *szMessage, long Offset, char szDelim, int *rfc822mode,
    int *override_to_mime, char *_szName, int max_name, char *_szValue,
    int max_value)
{
  char *szSrc = szMessage + Offset;
  char *szName = _szName, *szValue = _szValue;

  if (szName - _szName < max_name)
    *szName = 0;
  if (szValue - _szValue < max_value)
    *szValue = 0;

  if (!*rfc822mode || override_to_mime)	/* only if it's MIME field skip the leading separators and space */
    while (*szSrc && (iswhite_nts (szSrc) || isendline_nts (szSrc)
	    || *szSrc == ';'))
      szSrc++;

  /* get the name to the separator or white space */
  while (*szSrc && !iswhite_nts (szSrc) && *szSrc != szDelim)
    if (szName - _szName < max_name - 1)
      *szName++ = *szSrc++;
    else
      szSrc++;
  /* add the terminating null */
  if (szName - _szName < max_name)
    *szName = 0;

  /* The MIME fields in the RFC822 header are interpreted as such */
  if (szName - _szName && *rfc822mode)
    if (!strncasecmp (_szName, "Content-", 8))
      *override_to_mime = 1;

  /* skip the space till the separator */
  while (*szSrc && iswhite_nts (szSrc))
    szSrc++;

  /* check for that */
  if (*szSrc != szDelim)
    return -1;
  szSrc++;

  /* skip the space between separator and value */
  while (*szSrc && iswhite_nts (szSrc))
    szSrc++;

  /* get the value */
  if (*szSrc == '\"' && (!*rfc822mode || *override_to_mime))
    {				/* recognize quoted strings only in non rfc822 mode */
      szSrc++;
      while (*szSrc && *szSrc != '\"')
	if (szValue - _szValue < max_value - 1)
	  *szValue++ = *szSrc++;
	else
	  szSrc++;
      if (*szSrc != '\"')
	return -1;
      szSrc++;
    }
  else
    while (*szSrc && ((!*override_to_mime && *rfc822mode) || (!iswhite_nts (szSrc) && *szSrc != ';')))	/* recognize ; as separators only not in rfc822 mode */
      if (szValue - _szValue < max_value - 1)
	*szValue++ = *szSrc++;
      else
	szSrc++;

  /* the null terminator */
  if (szValue - _szValue < max_value)
    *szValue = 0;
  return (long) (szSrc - szMessage);
}


static long
mime_find_boundry (char *szMessage, long message_size, long offset,
    char *szBoundry, int *is_final)
{
  long nNewOffset = offset;
  char *szFound, *szTemp;
  int len_of_boundry = (int) strlen (szBoundry);

  *is_final = 0;
  do
    {
      szFound = (char *)
	  mime_memmem (szMessage + nNewOffset, message_size - nNewOffset,
	  szBoundry, len_of_boundry);
      if (!szFound)
	return -1;

      if (szFound[len_of_boundry] == '-' && szFound[len_of_boundry + 1] == '-'
	  && (!*(szFound + len_of_boundry + 2)
	      || iswhite (szFound + len_of_boundry + 2)
	      || isendline (szFound + len_of_boundry + 2)))
	{
	  *is_final = 1;
	  szTemp = szFound + len_of_boundry + 2;
	}
      else
	szTemp = szFound + len_of_boundry;
      while (iswhite (szTemp))
	szTemp++;
      if (!*szTemp || *szTemp == CR || *szTemp == LF)
	return (long) (szFound - szMessage - 2);
      else if (!*szTemp)
	return -1;
      nNewOffset += len_of_boundry;
    }
  while (1);
}

caddr_t
mime_parse_header (int *rfc822, caddr_t szMessage, long message_size, long offset)
{
  char szNewBoundry[1000], szHeaderLine[1000], szAttr[1000], szValue[1000];
  long newOffset = offset, tempOffset = 0, lineOffset;
  int new_mode = *rfc822;
  int override_to_mime = 0;
  dk_set_t attrs = NULL;
  caddr_t result = NULL;

  *szNewBoundry = 0;

  /* skip the empty lines if in RFC822 header */
  if (*rfc822)
    while ((iswhite (szMessage + newOffset) || isendline (szMessage + newOffset)) && newOffset < message_size)
      newOffset++;
  while (0 < (tempOffset = mime_get_line (szMessage, message_size, newOffset, szHeaderLine, 1000)))
    {
      newOffset = tempOffset;
      lineOffset = 0;
      if (strlen (szHeaderLine) < 2)
	break;
      override_to_mime = 0;

      lineOffset = mime_get_attr (szHeaderLine, 0, ':', rfc822, &override_to_mime, szAttr, 1000, szValue, 1000);
      if (lineOffset == -1)
	continue;
      dk_set_push (&attrs, (void *) box_dv_short_string (szAttr));
      dk_set_push (&attrs, (void *) box_dv_short_string (szValue));
      if (override_to_mime || !*rfc822)
	{
	  new_mode = 0;
	  while (-1 != (lineOffset = mime_get_attr (szHeaderLine, lineOffset, '=', rfc822, &override_to_mime, szAttr, 1000, szValue, 1000)))
	    {
	      dk_set_push (&attrs, (void *) box_dv_short_string (szAttr));
	      dk_set_push (&attrs, (void *) box_dv_short_string (szValue));
	    }
	}
    }
  if (attrs)
    result = list_to_array (dk_set_nreverse (attrs));
  return result;
}

long
get_mime_part (int *rfc822, caddr_t szMessage, long message_size, long offset,
    char *szBoundry, char *szType, size_t max_szType,
    caddr_t ** _result, long to_add)
{
  char szNewBoundry[1000], szHeaderLine[1000], szAttr[1000], szValue[1000];
#ifdef DEBUG
  char chTemp;
#endif
  long newOffset = offset, tempOffset = 0, lineOffset;
  long body_start, body_end, next_body_start;
  int new_mode = *rfc822;
  int override_to_mime = 0;
  int body_is_mime = 0;
  dk_set_t attrs = NULL, multiparts = NULL;
  caddr_t *body = NULL;
  caddr_t *result;

  *szNewBoundry = 0;
  result =
      (caddr_t *) dk_alloc_box_zero (3 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  *_result = result;

  /* skip the empty lines if in RFC822 header */
  if (*rfc822)
    while ((iswhite (szMessage + newOffset)
	    || isendline (szMessage + newOffset)) && newOffset < message_size)
      newOffset++;
  /* the header */
#ifdef DEBUG
  if (*rfc822)
    {
      dbg_printf (("\n\n----------RFC822 HEADER----------\n"));
    }
  else
    {
      dbg_printf (("\n\n----------MIME PART HEADER----------\n"));
    }
#endif
  while (0 < (tempOffset =
	  mime_get_line (szMessage, message_size, newOffset, szHeaderLine,
	      1000)))
    {
      newOffset = tempOffset;
      lineOffset = 0;
      if (strlen (szHeaderLine) < 2)
	break;
      override_to_mime = 0;

      lineOffset =
	  mime_get_attr (szHeaderLine, 0, ':', rfc822, &override_to_mime,
	  szAttr, 1000, szValue, 1000);
      if (lineOffset == -1)
	continue;
      dbg_printf (("Name : [%s]\nValue=[%s]\n", szAttr, szValue));
      dk_set_push (&attrs, (void *) box_dv_short_string (szAttr));
      dk_set_push (&attrs, (void *) box_dv_short_string (szValue));
      if (override_to_mime || !*rfc822)
	{
	  new_mode = 0;
	  if (!strcasecmp (szAttr, "Content-Type"))
	    {
	      strcpy_size_ck (szType, szValue, max_szType);
	      dbg_printf (("Content type found : %s\n", szType));
	    }
	  dbg_printf (("Attrs : "));
	  while (-1 != (lineOffset =
		  mime_get_attr (szHeaderLine, lineOffset, '=', rfc822,
		      &override_to_mime, szAttr, 1000, szValue, 1000)))
	    {
	      if (!strcasecmp (szAttr, "boundary"))
		{
		  strcpy_ck (szNewBoundry, szValue);
		  dbg_printf (("Boundary found : %s\n", szBoundry));
		}
	      dbg_printf (("[%s]=[%s] ", szAttr, szValue));
	      dk_set_push (&attrs, (void *) box_dv_short_string (szAttr));
	      dk_set_push (&attrs, (void *) box_dv_short_string (szValue));
	    }
	  dbg_printf (("\n"));
	}
    }
  if (attrs)
    {
      result[0] = list_to_array (dk_set_nreverse (attrs));
      attrs = NULL;
    }
#ifdef DEBUG
  if (*rfc822)
    {
      dbg_printf (("\n\n----------RFC822 HEADER END ----------\n"));
    }
  else
    {
      dbg_printf (("\n\n----------MIME PART HEADER END ----------\n"));
    }
#endif
  if (tempOffset < 0)
    return -1;

  if (!strcasecmp (szType, "message/rfc822"))
    {
      body_is_mime = 1;
      new_mode = 0;
    }

  body =
      (caddr_t *) dk_alloc_box_zero (4 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  result[1] = (caddr_t) body;
  body_start = newOffset;
  body[0] = box_num (to_add + body_start);

  if (!new_mode)
    {				/* the MIME multipart ends on an boundary */
      /* get the body of the message */
      char *szBoundryUsed = *szNewBoundry ? szNewBoundry : szBoundry;
      if (*szBoundryUsed)
	{			/* within multipart */
	  int is_final = 0;
	  next_body_start = body_end =
	      mime_find_boundry (szMessage, message_size, body_start - 1,
	      szBoundryUsed, &is_final);
	  if (body_end < 1 || szMessage[body_end - 1] != LF)
	    return -1;
	  body_end--;

	  while (body_end > 0 && szMessage[body_end - 1] == CR)
	    body_end--;
#ifdef DEBUG
	  chTemp = szMessage[body_end];
	  szMessage[body_end] = 0;
#endif
	  dbg_printf (("\n----- MIME BODY -----\n"));
	  body[1] = box_num (to_add + body_end);
	  if (body_is_mime)
	    {			/* a body of a message is mime as well */
	      long body_mime_offset = 0;
	      int body_rfc822 = 1;
	      char szBodyBoundry[1000];
	      char szBodyType[1000];
	      caddr_t *body_result = NULL;

	      *szBodyBoundry = 0;
	      *szBodyType = 0;
	      body_mime_offset = get_mime_part (&body_rfc822,
		  szMessage + body_start,
		  body_end - body_start,
		  body_mime_offset,
		  szBodyBoundry,
		  szBodyType, sizeof (szBodyType), &body_result, to_add + body_start);

	      if (body_mime_offset == -1
		  || body_start - body_mime_offset > body_end
		  || body_mime_offset > 0)
		{
#ifdef DEBUG
		  szMessage[body_end] = chTemp;
#endif
		  dk_free_tree ((box_t) body_result);
		  body_result = NULL;
		  return -1;
		}
	      body_mime_offset = -1 * body_mime_offset;
	      body[2] = (caddr_t) body_result;
	      if (body_start + body_mime_offset < body_end)
		{
		  caddr_t *after_array =
		      (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t),
		      DV_ARRAY_OF_POINTER);
		  /* this is a RFC822 encapsulated into MIME body, witch itself has
		     MIME structure and after it's end there is some by the constructor
		     of the encapsulating MIME message. So We'll make it a new type */
		  body[3] = (caddr_t) after_array;
		  after_array[0] =
		      box_num (to_add + body_start + body_mime_offset);
		  after_array[1] = box_num (to_add + body_end);
		  dbg_printf (
		      ("\n---- TEXT IN THE RFC822 MESSAGE AFTER THE MIME MESSAGE IN IT ----\n%s",
			  szMessage + body_start + body_mime_offset));
		  dbg_printf (
		      ("\n---- END TEXT IN THE RFC822 MESSAGE AFTER THE MIME MESSAGE IN IT ----\n"));
#ifdef DEBUG
		  szMessage[body_end] = chTemp;
#endif
		}
#ifdef DEBUG
	      else
		{
		  szMessage[body_end] = chTemp;
		}
#endif
	    }
#ifdef DEBUG
	  else
	    {
	      dbg_printf (("%s\n", szMessage + body_start));
	      szMessage[body_end] = chTemp;
	    }
#endif
	  tempOffset =
	      mime_get_line (szMessage, message_size, next_body_start,
	      szHeaderLine, 1000);
	  if (tempOffset < 0)
	    return -1;
	  dbg_printf (("\n----- MIME BODY END -----\n"));

	  /* now if it's a nested multipart message */
	  if (!strncasecmp (szType, "multipart", 9))
	    {			/* the beginning of multipart message */
	      int newRFC822 = 0;
	      char szNewType[1000];
	      caddr_t *part_result;
	      if (!*szNewBoundry)
		return -1;
	      dbg_printf (("\n----- MULTIPARTS starting -----\n"));
	      do
		{
		  if (strstr (szType, "digest"))
		    {
		      /* newRFC822 = 1; */
		      strcpy_ck (szNewType, "message/rfc822");
		    }
		  else
		    *szNewType = 0;

		  dbg_printf (("\n----- MULTIPARTS PART START -----\n"));
		  tempOffset = get_mime_part (&newRFC822, szMessage,
		      message_size, tempOffset, szNewBoundry, szNewType, sizeof (szNewType),
		      &part_result, to_add);
		  dbg_printf (("\n----- MULTIPARTS PART END -----\n"));
		  if (part_result)
		    {
		      if (tempOffset == -1)
			dk_free_tree ((box_t) part_result);
		      else
			{
			  dk_set_push (&multiparts, (void *) part_result);
			  /* When embedded multipart finish, we
			     have to check whether current multipart is also finished.
			     Otherwise last boundry end never get's readed properly
			   */
			  if (NULL != part_result[2])
			    {
			      long new_body_start = (-1) * tempOffset;
			      tempOffset =
				  mime_find_boundry (szMessage, message_size,
				  new_body_start - 1, szNewBoundry,
				  &is_final);
			      if (is_final)
				break;
			    }
			}
		    }
		}
	      while (tempOffset > 0);
	      result[2] = list_to_array (dk_set_nreverse (multiparts));
	      multiparts = NULL;
	      if (tempOffset == -1)
		return -1;
	      dbg_printf (("\n----- MULTIPARTS end -----\n"));
	    }
	  *rfc822 = new_mode;
	  return (is_final ? (-1) * tempOffset : tempOffset);
	}
    }
  /* an RFC 822 message or a single mime message outside multiparts */
#ifdef DEBUG
  if (*rfc822)
    dbg_printf (
	("\n----- RFC822 BODY -----\n%s\n----- RFC822 BODY END -----\n",
	    szMessage + body_start));
  else
    dbg_printf (
	("\n----- MIME SINGLE BODY -----\n%s\n----- MIME SINGLE BODY END -----\n",
	    szMessage + body_start));
#endif
  body[1] = box_num (to_add + message_size - 1);
  *rfc822 = new_mode;
  return (-1 * message_size);
}

/* the "Stream mime parser".
   It currently isn't recursive.
   Suites well for multipart/form-data
*/
#define s_iswhite(x) ((x) == SPACE || (x) == HTAB)
#define s_isendline(x) ((x) && ((x) == CR || (x) == LF))
#define GET_CHAR(c,ses,c_before,rb_inx)  \
  { \
    if (c_before[rb_inx]) \
      c = c_before[rb_inx++]; \
    else \
      { \
	(*chars_read)++; \
	c = session_buffered_read_char (ses); \
      } \
  }

static long
mime_stream_get_line (dk_session_t * ses, long max_size, long *chars_read,
    char *_szDest, int max_len, char *c_before, char *c_after, size_t max_c_after)
{
  char c = 0, *szDest = _szDest;
  long line_len = 0;
  int cb_inx = 0, cb_len = (int) strlen (c_before);

  if (_szDest)
    *_szDest = 0;

  while (*chars_read - (cb_len - cb_inx) < max_size)
    {
      GET_CHAR (c, ses, c_before, cb_inx);
      if (c == CR)
	{			/* unfolding like RFC 822 */
	  GET_CHAR (c, ses, c_before, cb_inx);
	  while (*chars_read - (cb_len - cb_inx) < max_size && c == LF)
	    GET_CHAR (c, ses, c_before, cb_inx);
	  if (!s_iswhite (c) || !line_len)
	    break;
	}
      else if (c == LF)
	{			/* unfolding like RFC 822  but also for LFCR as for CRLF */
	  GET_CHAR (c, ses, c_before, cb_inx);
	  while (*chars_read - (cb_len - cb_inx) < max_size && c == CR)
	    GET_CHAR (c, ses, c_before, cb_inx);
	  if (!s_iswhite (c) || !line_len)
	    break;
	}
      line_len++;
      if (_szDest && szDest - _szDest < max_len - 1)
	*szDest++ = c;
    }

  if (_szDest && szDest - _szDest < max_len)
    *szDest = 0;
  strcpy_size_ck (c_after, c_before + cb_inx, max_c_after);
  if (max_c_after - 1 > (size_t) (cb_len - cb_inx))
    c_after[cb_len - cb_inx] = c;
  if (max_c_after - 1 > (size_t) (cb_len - cb_inx + 1))
    c_after[cb_len - cb_inx + 1] = 0;

  return line_len;
}


static int
mime_stream_read_to_boundry (dk_session_t * ses, long max_size,
    long *chars_read, char *szBoundry, dk_session_t * out, char *c_before,
    char *c_after, size_t max_c_after)
{
  char *ptr = szBoundry;
  int len_of_boundry = (int) strlen (szBoundry);
  caddr_t buffer = (caddr_t) dk_alloc (len_of_boundry + 4), buf_ptr;
  register int c;
  register int state = 0;
  int cb_inx = 0, cb_len = (int) strlen (c_before);
  int is_final = 0;

  buf_ptr = buffer;
  while (*chars_read - (cb_len - cb_inx) < max_size - 3)
    {
      GET_CHAR (c, ses, c_before, cb_inx);
    again:
      if (!state && c == CR)
	{
	  buf_ptr = buffer;
	  state = 1;
	}
      else if (state < 2)
	{
	  if (c == LF)
	    {
	      if (state < 1)
		{
		  buf_ptr = buffer;
		  *buf_ptr++ = 0;
		}
	      state = 2;
	    }
	  else
	    {
	      if (state == 1)
		{
		  session_buffered_write_char (CR, out);
		  state = 0;
		  goto again;
		}
	      else
		state = 0;
	    }
	}
      else if (state > 1 && state < 4)
	{
	  if (c == '-')
	    {
	      state++;
	      if (state == 4)
		ptr = szBoundry;
	    }
	  else
	    {
	      if (buffer[0] == 0 && buffer[1] == LF)
		session_buffered_write (out, buffer + 1,
		    (int) (buf_ptr - buffer - 1));
	      else
		session_buffered_write (out, buffer, buf_ptr - buffer);
	      state = 0;
	      goto again;
	    }
	}
      else if (state >= 4 && state < len_of_boundry + 4)
	{
	  if (c == *ptr++)
	    {
	      state++;
	      if (state == len_of_boundry + 4)
		{
		  *buf_ptr++ = c;
		  break;
		}
	    }
	  else
	    {
	      if (buffer[0] == 0 && buffer[1] == LF)
		session_buffered_write (out, buffer + 1,
		    (int) (buf_ptr - buffer - 1));
	      else
		session_buffered_write (out, buffer, buf_ptr - buffer);
	      state = 0;
	      goto again;
	    }
	}
      if (state)
	*buf_ptr++ = c;
      else
	session_buffered_write_char (c, out);
    }
  strcpy_size_ck (c_after, c_before + cb_inx, max_c_after);
  if (state < len_of_boundry + 4 && buf_ptr > buffer)
    {
      if (state > 1 && buffer[0] == 0 && buffer[1] == LF)
	session_buffered_write (out, buffer + 1, buf_ptr - buffer - 1);
      else
	session_buffered_write (out, buffer, buf_ptr - buffer);
    }
  else
    {
      if (*chars_read - (cb_len - cb_inx) >= max_size - 3)
	{
	  dk_free (buffer, len_of_boundry + 3);
	  return -1;
	}
      GET_CHAR (c, ses, c_before, cb_inx);
      if (c == '-')
	{
	  GET_CHAR (c, ses, c_before, cb_inx);
	  if (c == '-')
	    {
	      GET_CHAR (c, ses, c_before, cb_inx);
	      if (s_iswhite (c) || s_isendline (c))
		{
		  is_final = 1;
		}
	      else
		{
		  if (max_c_after - 1 > (size_t) (cb_len - cb_inx))
		    c_after[cb_len - cb_inx] = c;
		  cb_len ++;
		}
	    }
	  if (!is_final)
	    {
	      if (max_c_after - 1 > (size_t) (cb_len - cb_inx))
		c_after[cb_len - cb_inx] = c;
	      cb_len ++;
	    }
	}
      if (!is_final)
	{
	  if (max_c_after - 1 > (size_t) (cb_len - cb_inx))
	    c_after[cb_len - cb_inx] = c;
	  cb_len ++;

	  if (max_c_after - 1 > (size_t) (cb_len - cb_inx))
	    c_after[cb_len - cb_inx] = 0;
	  cb_len ++;
	}
    }

  dk_free (buffer, len_of_boundry + 4);
  return state == len_of_boundry + 4 ? is_final + 1 : 0;
}


static caddr_t
mime_stream_get_header (dk_session_t * ses, long max_size, long *chars_read,
    char *szType, size_t max_szType, int rfc822, int *new_mode,
    char *szNewBoundry, size_t max_szNewBoundry,
    char *c_before, char *c_after, size_t max_c_after)
{
  char szHeaderLine[1000], szAttr[1000], szValue[1000];
  dk_set_t attrs = NULL;
  int override_to_mime = 0;
  int cb_len = (int) strlen (c_before);
  char *_c_before = c_before, *_c_after = c_after, *p_tmp;
  int lineOffset;

  while (*chars_read - cb_len < max_size)
    {
      if (0 >= mime_stream_get_line (ses, max_size, chars_read, szHeaderLine,
	      sizeof (szHeaderLine), _c_before, _c_after, max_c_after))
	break;
      if (strlen (szHeaderLine) < 2)
	break;
      p_tmp = _c_before;
      _c_before = _c_after;
      _c_after = p_tmp;
      cb_len = (int) strlen (_c_before);
      override_to_mime = 0;

      lineOffset =
	  mime_get_attr (szHeaderLine, 0, ':', &rfc822, &override_to_mime,
	  szAttr, 1000, szValue, 1000);
      if (lineOffset == -1)
	continue;
      dk_set_push (&attrs, (void *) box_dv_short_string (szAttr));
      dk_set_push (&attrs, (void *) box_dv_short_string (szValue));
      if (override_to_mime || !rfc822)
	{
	  if (new_mode)
	    *new_mode = 0;
	  if (!strcasecmp (szAttr, "Content-Type"))
	    {
	      if (szType)
		strcpy_size_ck (szType, szValue, max_szType);
	    }
	  while (-1 != (lineOffset =
		  mime_get_attr (szHeaderLine, lineOffset, '=', &rfc822,
		      &override_to_mime, szAttr, 1000, szValue, 1000)))
	    {
	      if (!strcasecmp (szAttr, "boundary"))
		{
		  if (szNewBoundry)
		    strcpy_size_ck (szNewBoundry, szValue, max_szNewBoundry);
		}
	      dk_set_push (&attrs, (void *) box_dv_short_string (szAttr));
	      dk_set_push (&attrs, (void *) box_dv_short_string (szValue));
	    }
	}
    }

  if (_c_after != c_after)
    strcpy_size_ck (c_after, _c_after, max_c_after);
  if (attrs)
    {
      return list_to_array (dk_set_nreverse (attrs));
    }
  else
    return NULL;
}


caddr_t
mime_stream_get_part (int rfc822, dk_session_t * ses, long max_size,
    dk_session_t * header_ses, long header_size)
{
  long _chars_read = 0, *chars_read = &_chars_read;
  char szNewBoundry[1000];
  char szType[1000];
  int new_mode = rfc822;
  int body_is_mime = 0, c_cnt;
  dk_set_t multiparts = NULL;
  caddr_t *result;
  char c_before[5], c_after[5];
  dk_session_t *subses = NULL;

  c_before[0] = c_after[0] = 0;
  c_cnt = 0;
  *szNewBoundry = 0;
  result =
      (caddr_t *) dk_alloc_box_zero (3 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  result[1] = (caddr_t) (subses = strses_allocate ());

  CATCH_READ_FAIL (header_ses)
    {
      /* the header */
      result[0] = mime_stream_get_header (header_ses, header_size, chars_read,
          szType, sizeof (szType), rfc822, &new_mode, szNewBoundry, sizeof (szNewBoundry),
	  c_before, c_after, sizeof (c_after));
      strcpy_ck (c_before, c_after);
    }
  FAILED
    {
      dk_free_tree ((box_t) result);
      result = NULL;
    }
  END_READ_FAIL (header_ses);
  if (!result)
    return NULL;
  *chars_read = 0;
  CATCH_READ_FAIL_S (ses)
    {
      if (!strcasecmp (szType, "message/rfc822"))
	{
	  body_is_mime = 1;
	  new_mode = 0;
	}

      if (!new_mode)
	{				/* the MIME multipart ends on an boundary */
	  /* get the body of the message */
	  if (*szNewBoundry)
	    {			/* within multipart */
	      int is_final = 0;
	      if (0 == (is_final =
		    mime_stream_read_to_boundry (ses, max_size, chars_read,
		      szNewBoundry, subses, c_before, c_after, sizeof (c_after))))
		{
		  dk_free_tree ((box_t) result);
		  result = NULL;
		  goto done;
		}
	      is_final--;
	      if (strses_length (subses) < MIME_SESSION_LIMIT)
		{
		  result[1] = strses_string (subses);
		  strses_free (subses);
		  subses = NULL;
		}
	      strcpy_ck (c_before, c_after);
#if 0
	      if (body_is_mime)
		{			/* a body of a message is mime as well */

		}
#endif
	      if (!is_final)
		{
		  mime_stream_get_line (ses, max_size, chars_read, NULL, 0,
		      c_before, c_after, sizeof (c_after));
		  strcpy_ck (c_before, c_after);
		}

	      /* now if it's a nested multipart message */
	      if (!strncasecmp (szType, "multipart", 9))
		{			/* the beginning of multipart message */
		  if (!*szNewBoundry)
		    {
		      dk_free_tree ((box_t) result);
		      result = NULL;
		      goto done;
		    }
		  while (!is_final)
		    {
		      dk_session_t *part_subses;
		      caddr_t *part_result = (caddr_t *)
			  dk_alloc_box_zero (3 * sizeof (caddr_t),
			      DV_ARRAY_OF_POINTER);
		      char szNewType[1000];

		      if (strstr (szType, "digest"))
			{
			  /* newRFC822 = 1; */
			  strcpy_ck (szNewType, "message/rfc822");
			}
		      else
			*szNewType = 0;

		      part_result[0] =
			  mime_stream_get_header (ses, max_size, chars_read,
			      NULL, 0, 0, NULL, NULL, 0, c_before, c_after, sizeof (c_after));
		      strcpy_ck (c_before, c_after);
		      part_result[1] = (caddr_t) (part_subses =
			  strses_allocate ());
		      if (0 == (is_final =
			    mime_stream_read_to_boundry (ses, max_size,
			      chars_read, szNewBoundry, part_subses,
			      c_before, c_after, sizeof (c_after))))
			{
			  dk_free_tree ((box_t) part_result);
			  part_result = NULL;
			  continue;
			}
		      is_final--;
		      strcpy_ck (c_before, c_after);
		      if (strses_length (part_subses) < MIME_SESSION_LIMIT)
			{
			  part_result[1] = strses_string (part_subses);
			  strses_free (part_subses);
			  part_subses = NULL;
			}
		      if (!is_final)
			{
			  mime_stream_get_line (ses, max_size, chars_read, NULL,
			      0, c_before, c_after, sizeof (c_after));
			  strcpy_ck (c_before, c_after);
			}
		      if (part_result)
			{
			  dk_set_push (&multiparts, (void *) part_result);
			}
		    }
		  result[2] = list_to_array (dk_set_nreverse (multiparts));
		  multiparts = NULL;
		}
	      goto done;
	    }
	}
      /* an RFC 822 message or a single mime message outside multiparts */
      while (max_size > *chars_read)
	{
	  char chunk[DKSES_OUT_BUFFER_LENGTH];
	  int to_read = MIN (DKSES_OUT_BUFFER_LENGTH, max_size - *chars_read);
	  session_buffered_read (ses, chunk, to_read);
	  session_buffered_write (subses, chunk, to_read);
	  *chars_read += to_read;
	}
      if (strses_length (subses) < MIME_SESSION_LIMIT)
	{
	  result[1] = strses_string (subses);
	  strses_free (subses);
	  subses = NULL;
	}
done:
      multiparts = NULL;
    }
  FAILED
    {
      dk_free_tree ((box_t) result);
      result = NULL;
      THROW_READ_FAIL_S (ses);
    }
  END_READ_FAIL_S (ses);
  return (caddr_t) result;
}


static caddr_t
bif_mime_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long Offset = 0;
  char *szMessage = bif_string_arg (qst, args, 0, "bif_mime_tree");
  char szBoundry[1000];
  char szType[1000];
  int rfc822 = 1;
  caddr_t **result = NULL;

  if (BOX_ELEMENTS (args) > 1)
    rfc822 = (int) bif_long_arg (qst, args, 1, "bif_mime_tree");

  *szType = 0;
  *szBoundry = 0;
  Offset =
      get_mime_part (&rfc822, szMessage, box_length (szMessage) - 1, Offset,
      szBoundry, szType, sizeof (szType), (caddr_t **) & result, 0);

  if (Offset == -1 || Offset > 0)
    {
      dk_free_tree ((box_t) result);
      result = NULL;
    }
  else if ((uint32) (-1 * Offset) < box_length (szMessage) - 1)
    {
      Offset = -1 * Offset;
      if (result && result[1])
	{
	  caddr_t *after_array = (caddr_t *)
	      dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  result[1][3] = (caddr_t) after_array;
	  after_array[0] = box_num (Offset);
	  after_array[1] = box_num (box_length (szMessage) - 1);
	}
    }
  return (caddr_t) result;
}

static caddr_t
bif_mime_header (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMessage = bif_string_arg (qst, args, 0, "mime_header");
  int rfc822 = 1;
  caddr_t result = NULL;

  if (BOX_ELEMENTS (args) > 1)
    rfc822 = (int) bif_long_arg (qst, args, 1, "mime_header");

  result = mime_parse_header (&rfc822, szMessage, box_length (szMessage) - 1, 0);
  return result ? result : NEW_DB_NULL;
}

static caddr_t 
bif_mime_tree_ses (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *ses = (dk_session_t *) bif_strses_arg (qst, args, 0, "mime_tree");
  int rfc822 = 1;
  caddr_t result = NULL;

  if (BOX_ELEMENTS (args) > 1)
    rfc822 = (int) bif_long_arg (qst, args, 1, "mime_tree");
  result = mime_stream_get_part (rfc822, ses, strses_length (ses), ses, strses_length (ses));
  return result;
}

static voidpf
zlib_dk_alloc (voidpf opaque, uInt items, uInt size)
{
  return (voidpf) dk_alloc_box (((size_t) items) * ((size_t) size),
      DV_LONG_STRING);
}


static void
zlib_dk_free (voidpf opaque, voidpf address)
{
  dk_free_box ((box_t) address);
}


#define ZLIB_INIT_DK_STREAM(zs) \
{ \
  memset (&zs, 0, sizeof (z_stream)); \
  zs.zalloc = zlib_dk_alloc; \
  zs.zfree = zlib_dk_free; \
}


caddr_t
zlib_box_compress (caddr_t src, caddr_t * err_ret)
{
  dtp_t src_dtp = DV_TYPE_OF (src);
  uLongf src_size = box_length (src) - (IS_STRING_DTP (src_dtp) ? 1 : 0);
  uLongf dest_size = (uLongf) (src_size * 1.01 + 20);
  uLongf dest_size_ret;
  caddr_t dest;
  caddr_t dest_tmp = (caddr_t) dk_alloc ((uint32) dest_size);
  char *err_msg;
  int rc;
  if (src_size & 0xff000000 || dest_size & 0xff000000)	/* sign error causes overflow */
    {
      *err_ret =
	  srv_make_new_error ("22026", "SR102",
	  "Error in compressing (invalid input)");
      return NULL;
    }
  dest_size_ret = dest_size;
  rc = compress2 ((Bytef *) dest_tmp, &dest_size_ret, (const Bytef *) src,
      src_size, Z_DEFAULT_COMPRESSION);
  if (Z_OK == rc)
    {
      dest = dk_alloc_box (dest_size_ret + 1, DV_LONG_STRING);
      dest[dest_size_ret] = 0;
      memcpy (dest, dest_tmp, dest_size_ret);
      dk_free (dest_tmp, dest_size);
      return dest;
    }
  dk_free (dest_tmp, dest_size);
  if (err_ret)
    {
      char *state = "22000";
      switch (rc)
	{
	case Z_MEM_ERROR:
	  err_msg = "Error in compressing (not enough memory)";
	  state = "22005";
	  break;
	case Z_BUF_ERROR:
	  err_msg =
	      "Error in compressing (not enough room in the output buffer)";
	  state = "22026";
	  break;
	case Z_STREAM_ERROR:
	  err_msg =
	      "Error in compressing (compression level parameter is invalid)";
	  state = "22003";
	  break;
	default:
	  err_msg = "Error in compressing";
	  state = "22000";
	  break;
	}
      *err_ret = srv_make_new_error (state, "SR103", "%s", err_msg);
    }
  return NULL;
}

void
zlib_box_uncompress (caddr_t src, dk_session_t * out, caddr_t * err_ret)
{
  z_stream zs;
  int rc;
  char szBuffer[DKSES_OUT_BUFFER_LENGTH];

  ZLIB_INIT_DK_STREAM (zs);
  inflateInit (&zs);
  zs.next_in = (Bytef *) src;
  zs.avail_in = box_length (src) - 1;

  do
    {
      zs.next_out = (Bytef *) szBuffer;
      zs.avail_out = sizeof (szBuffer);
      rc = inflate (&zs, Z_NO_FLUSH);
      if (rc != Z_OK && rc != Z_STREAM_END)
	{
	  if (err_ret)
	    *err_ret =
		srv_make_new_error ("22025", "SR104",
		"Error in decompressing");
	  break;
	}
      if (sizeof (szBuffer) - zs.avail_out > 0)
	session_buffered_write (out, szBuffer,
	    sizeof (szBuffer) - zs.avail_out);
    }
  while (rc != Z_STREAM_END);
  inflateEnd (&zs);
}

void
zlib_blob_uncompress (lock_trx_t *lt, blob_handle_t *bh, dk_session_t * out, caddr_t * err_ret)
{
  z_stream zs;
  int rc;
  char szBuffer[DKSES_OUT_BUFFER_LENGTH];
  size_t bytes = bh->bh_length;
  long fill = 0;
  dp_addr_t start;
  buffer_desc_t *buf;
  long from_byte, bytes_filled, bytes_on_page;
  it_cursor_t *tmp_itc;
  bh->bh_current_page = bh->bh_page;
  bh->bh_position = 0;
  if (!bytes)
    return;
  ZLIB_INIT_DK_STREAM (zs);
  inflateInit (&zs);
  bh_fetch_dir (lt, bh);
  bh_read_ahead (lt, bh, 0, (unsigned) bh->bh_length);
  start = bh->bh_current_page;
  buf = NULL;
  from_byte = bh->bh_position;
  bytes_filled = 0;
  tmp_itc = itc_create (NULL, lt);
  itc_from_it (tmp_itc, bh->bh_it);
  while (start)
    {
      long len, next;
#ifdef DBG_BLOB_PAGES_ACCOUNT
      if (is_reg)
	db_dbg_account_add_page (start);
#endif
      if (!page_wait_blob_access (tmp_itc, start, &buf, PA_READ, bh, 1))
        break;
      len = LONG_REF (buf->bd_buffer + DP_BLOB_LEN);
      bytes_on_page = len - from_byte;
      if (bytes_on_page)
	{
	  /* dbg_printf (("Read blob page %ld, %ld bytes.\n", start,
	     bytes_on_page)); */
          zs.next_in = (Bytef *)(buf->bd_buffer + DP_DATA + from_byte);
          zs.avail_in = bytes_on_page;
          do
            {
              zs.next_out = (Bytef *) szBuffer;
              zs.avail_out = sizeof (szBuffer);
              rc = inflate (&zs, Z_NO_FLUSH);
              if (rc != Z_OK && rc != Z_STREAM_END)
                {
                  if (err_ret)
                    *err_ret = srv_make_new_error ("22025", "SR104", "Error in decompressing of blob, page %ld", (long)start);
                  next = 0;
                  goto next_is_set; /* see below */
                }
              if (sizeof (szBuffer) - zs.avail_out > 0)
                session_buffered_write (out, szBuffer,
                sizeof (szBuffer) - zs.avail_out );
            } while (rc != Z_STREAM_END);
	  bytes_filled += bytes_on_page;
	  from_byte += bytes_on_page;
	}
      next = LONG_REF (buf->bd_buffer + DP_OVERFLOW);
next_is_set:
      if (start == bh->bh_page)
	{
	  dp_addr_t t = LONG_REF (buf->bd_buffer + DP_BLOB_DIR);
	  if (bh->bh_dir_page && t != bh->bh_dir_page)
	    log_info ("Mismatch in directory page ID %d(%x) vs %d(%x).",
		t, t, bh->bh_dir_page, bh->bh_dir_page);
	  bh->bh_dir_page = t;
	}
      ITC_IN_KNOWN_MAP (tmp_itc, buf->bd_page);
      page_leave_inner (buf);
      ITC_LEAVE_MAP_NC (tmp_itc);
      bh->bh_current_page = next;
      bh->bh_position = 0;
      from_byte = 0;
      start = next;
    }
  itc_free (tmp_itc);

  bh->bh_current_page = bh->bh_page;
  bh->bh_position = 0;

  if (bytes_filled != bytes)
    goto stub_for_corrupted_blob;	/* see below */
  return;

/* If blob handle references to a field of deleted row, or in case of internal error, we should return empty string */
stub_for_corrupted_blob:
  log_info ("Attempt to convert invalid blob to string_output at page %d, %ld bytes expected, %ld retrieved%s",
    bh->bh_page, bytes, fill,
    ((0 == fill) ? "; it may be access to deleted page." : "") );
  inflateEnd (&zs);
}

static int
zget_byte (z_stream * stream)
{
  if (stream->avail_in == 0)
    return EOF;
  stream->avail_in--;
  return *(stream->next_in)++;
}

static void
zcheck_header (z_stream * stream, caddr_t * err_ret)
{
#define ASCII_FLAG   0x01 /* bit 0 set: file probably ascii text */
#define HEAD_CRC     0x02 /* bit 1 set: header CRC present */
#define EXTRA_FIELD  0x04 /* bit 2 set: extra field present */
#define ORIG_NAME    0x08 /* bit 3 set: original file name present */
#define COMMENT      0x10 /* bit 4 set: file comment present */
#define RESERVED     0xE0 /* bits 5..7: reserved */
  int method; /* method byte */
  int flags;  /* flags byte */
  unsigned int len;
  int c;

  if (stream->next_in[0] != 0x1f || stream->next_in[1] != 0x8b)
    {
      if (err_ret)
	*err_ret = srv_make_new_error ("22025", "SR104", "Error in header, gz magic number not found");
      return;
    }
  stream->avail_in -= 2;
  stream->next_in += 2;

  /* Check the rest of the gzip header */
  method = zget_byte(stream);
  flags = zget_byte(stream);
  if (method != Z_DEFLATED || (flags & RESERVED) != 0)
    {
      if (err_ret)
	*err_ret = srv_make_new_error ("22025", "SR104", "Error in header, gz method unknown");
      return;
    }

  /* Discard time, xflags and OS code: */
  for (len = 0; len < 6; len++) (void) zget_byte(stream);

  if ((flags & EXTRA_FIELD) != 0)
    { /* skip the extra field */
      len  =  (unsigned int)zget_byte(stream);
      len += ((unsigned int)zget_byte(stream))<<8;
      /* len is garbage if EOF but the loop below will quit anyway */
      while (len-- != 0 && zget_byte(stream) != EOF) ;
    }
  if ((flags & ORIG_NAME) != 0)
    { /* skip the original file name */
      while ((c = zget_byte(stream)) != 0 && c != EOF) ;
    }
  if ((flags & COMMENT) != 0)
    {   /* skip the .gz file comment */
      while ((c = zget_byte(stream)) != 0 && c != EOF) ;
    }
  if ((flags & HEAD_CRC) != 0)
    {  /* skip the header crc */
      for (len = 0; len < 2; len++) (void)zget_byte(stream);
    }
}

void
zlib_box_gzip_uncompress (caddr_t src, dk_session_t * out, caddr_t * err_ret)
{
  z_stream zs;
  int rc;
  char szBuffer[DKSES_OUT_BUFFER_LENGTH];

  ZLIB_INIT_DK_STREAM (zs);
  inflateInit2 (&zs, -MAX_WBITS);
  zs.next_in = (Bytef *) src;
  zs.avail_in = box_length (src) - 1;
  zcheck_header (&zs, err_ret);
  if (err_ret && *err_ret)
    {
      inflateEnd (&zs);
      return;
    }
  do
    {
      zs.next_out = (Bytef *) szBuffer;
      zs.avail_out = sizeof (szBuffer);
      rc = inflate (&zs, Z_NO_FLUSH);
      if (rc != Z_OK && rc != Z_STREAM_END)
	{
	  if (err_ret)
	    *err_ret =
		srv_make_new_error ("22025", "SR104",
		"Error in decompressing");
	  break;
	}
      if (sizeof (szBuffer) - zs.avail_out > 0)
	session_buffered_write (out, szBuffer,
	    sizeof (szBuffer) - zs.avail_out);
    }
  while (rc != Z_STREAM_END);
  inflateEnd (&zs);
}

void
zlib_strses_gzip_uncompress (dk_session_t * ses, dk_session_t * out, caddr_t *err_ret)
{
  z_stream zs;
  int rc, started = 0;
  char out_buffer[DKSES_OUT_BUFFER_LENGTH];
  char in_buffer[DKSES_OUT_BUFFER_LENGTH];
  long ofs = 0, unread_bytes;

  ZLIB_INIT_DK_STREAM (zs);
  inflateInit2 (&zs, -MAX_WBITS);
  while (sizeof (in_buffer) > (unread_bytes = strses_get_part (ses, in_buffer, ofs, sizeof (in_buffer))))
    {
      ofs += sizeof (in_buffer) - unread_bytes;

      if (out)
	session_flush_1 (out);

      zs.next_in = (Bytef *) in_buffer;
      zs.avail_in = sizeof (in_buffer) - unread_bytes;
      if (!started)
	{
	  zcheck_header (&zs, err_ret);
	  if (err_ret && *err_ret)
	    {
	      inflateEnd (&zs);
	      return;
	    }
	  started = 1;
	}
      do
	{
	  zs.next_out = (Bytef *) out_buffer;
	  zs.avail_out = sizeof (out_buffer);
	  rc = inflate (&zs, Z_NO_FLUSH);
	  if (rc != Z_OK && rc != Z_STREAM_END)
	    goto error;

	  if (sizeof (out_buffer) - zs.avail_out > 0 && out)
	    session_buffered_write (out, out_buffer, sizeof (out_buffer) - zs.avail_out);
	}
      while (zs.avail_in && rc != Z_STREAM_END);
    }
  zs.next_in = (Bytef *) in_buffer;
  zs.avail_in = 0;
  zs.next_out = (Bytef *) out_buffer;
  zs.avail_out = sizeof (out_buffer);
  rc = inflate (&zs, Z_FINISH);
  if (rc != Z_OK && rc != Z_STREAM_END)
    goto error;
  if (sizeof (out_buffer) - zs.avail_out > 0 && out)
    session_buffered_write (out, out_buffer, sizeof (out_buffer) - zs.avail_out);

error:
  inflateEnd (&zs);
  if (rc != Z_OK && rc != Z_STREAM_END)
    *err_ret = srv_make_new_error ("22000", "SR093", "Error in de-compressing");
  return;
}


long
strses_write_out_compressed (dk_session_t * ses, dk_session_t * out)
{
  z_stream zs;
  int rc;
  unsigned long out_len;
  char out_buffer[DKSES_OUT_BUFFER_LENGTH];
  char in_buffer[DKSES_OUT_BUFFER_LENGTH];
  long ofs = 0, unread_bytes;

  ZLIB_INIT_DK_STREAM (zs);
  deflateInit (&zs, Z_DEFAULT_COMPRESSION);
  while (sizeof (in_buffer) > (unread_bytes =
	  strses_get_part (ses, in_buffer, ofs, sizeof (in_buffer))))
    {
      ofs += sizeof (in_buffer) - unread_bytes;

      if (out)
	session_flush_1 (out);

      zs.next_in = (Bytef *) in_buffer;
      zs.avail_in = sizeof (in_buffer) - unread_bytes;
      do
	{
	  zs.next_out = (Bytef *) out_buffer;
	  zs.avail_out = sizeof (out_buffer);
	  rc = deflate (&zs, Z_NO_FLUSH);
	  if (rc != Z_OK && rc != Z_STREAM_END)
	    goto error;

	  if (sizeof (out_buffer) - zs.avail_out > 0 && out)
	    session_buffered_write (out, out_buffer,
		sizeof (out_buffer) - zs.avail_out);
	}
      while (zs.avail_in);
    }
  zs.next_in = (Bytef *) in_buffer;
  zs.avail_in = 0;
  zs.next_out = (Bytef *) out_buffer;
  zs.avail_out = sizeof (out_buffer);
  rc = deflate (&zs, Z_FINISH);
  if (rc != Z_OK && rc != Z_STREAM_END)
    goto error;
  if (sizeof (out_buffer) - zs.avail_out > 0 && out)
    session_buffered_write (out, out_buffer,
	sizeof (out_buffer) - zs.avail_out);

error:
  out_len = zs.total_out;
  deflateEnd (&zs);
  if (rc != Z_OK && rc != Z_STREAM_END)
    sqlr_new_error ("22000", "SR093", "Error in compressing");
  return out_len;
}


static caddr_t
bif_gz_compress (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "gz_compress";
  caddr_t src = bif_string_arg (qst, args, 0, szMe);
  return zlib_box_compress (src, err_ret);
}


static caddr_t
bif_string_output_gz_compress (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  static char *szMe = "string_output_gz_compress";
  dk_session_t *ses = (dk_session_t *) bif_arg (qst, args, 0, szMe);
  dk_session_t *out = (dk_session_t *) bif_arg (qst, args, 1, szMe);
  dtp_t ses_dtp = DV_TYPE_OF (ses), out_dtp = DV_TYPE_OF (out);

  if (DV_STRING_SESSION != ses_dtp)
    sqlr_new_error ("22023", "SR094",
	"%s needs a string_output as a first argument, not an argument of type %s (%d)",
	szMe, dv_type_title (ses_dtp), ses_dtp);

  if (DV_STRING_SESSION != out_dtp)
    out = NULL;
  return box_num (strses_write_out_compressed (ses, out));
}


static caddr_t
bif_gz_uncompress (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "gz_uncompress";
  caddr_t src = bif_string_arg (qst, args, 0, szMe);
  dk_session_t *out = (dk_session_t *) bif_arg (qst, args, 1, szMe);

  dtp_t out_dtp = DV_TYPE_OF (out);

  if (DV_STRING_SESSION != out_dtp)
    sqlr_new_error ("22023", "SR095",
	"gz_uncompress needs a string_output as a second argument,"
	" not an argument of type %s (%d)", dv_type_title (out_dtp), out_dtp);
  zlib_box_uncompress (src, out, err_ret);
  return NULL;
}

extern int http_ses_size;

static caddr_t
bif_gzip_uncompress (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "gzip_uncompress";
  caddr_t src = bif_arg (qst, args, 0, szMe);
  dk_session_t *out;
  dtp_t dtp = DV_TYPE_OF (src);

  if (DV_STRING_SESSION != dtp && !DV_STRINGP (src))
    sqlr_new_error ("22023", "SR095",
	"%s needs a string_output or string as a first argument,"
	" not an argument of type %s (%d)", szMe, dv_type_title (dtp), dtp);
  out = strses_allocate ();
  strses_enable_paging (out, http_ses_size);

  if (DV_STRING_SESSION != dtp)
    zlib_box_gzip_uncompress (src, out, err_ret);
  else
    zlib_strses_gzip_uncompress ((dk_session_t *) src, out, err_ret);
  return (caddr_t) out;
}

static caddr_t
bif_gz_compress_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "gz_compress_file";
  caddr_t fname = bif_string_arg (qst, args, 0, szMe);
  caddr_t dname = bif_string_arg (qst, args, 1, szMe);
  gzFile gz_fd = NULL;
  int fd = 0;
  caddr_t fname_cvt, dname_cvt;
  int readed = 0;
  char buffer [0x8000];
  caddr_t err = NULL;

  sec_check_dba ((query_instance_t *) qst, szMe);

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  dname_cvt = file_native_name (dname);
  file_path_assert (fname_cvt, &err, 1);
  if (NULL != err)
    {
      dk_free_box (dname_cvt);
      sqlr_resignal (err);
    }

  fd = fd_open (fname_cvt, OPEN_FLAGS_RO);
  if (fd < 0)
    {
      int errn = errno;
      dk_free_box (dname_cvt);
      dk_free_box (fname_cvt);
      sqlr_new_error ("39000", "FA049", "Can't open file %s, error : %s",
	  fname, virt_strerror (errn));
    }
  LSEEK (fd, 0, SEEK_SET);
  gz_fd = gzopen (dname_cvt, "w");
  if (!gz_fd)
    {
      dk_free_box (dname_cvt);
      dk_free_box (fname_cvt);
      sqlr_new_error ("39000", "FA050", "Can't open compressed file %s", dname);
    }

  for (;;)
    {
      readed = read (fd, buffer, sizeof (buffer));
      if (readed > 0)
	gzwrite (gz_fd, buffer, readed);
      else
	break;
    }

  gzclose (gz_fd);
  close(fd);

  dk_free_box (dname_cvt);
  dk_free_box (fname_cvt);
  return NULL;
}

static caddr_t
bif_gz_uncompress_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "gz_uncompress_file";
  caddr_t dname = bif_string_arg (qst, args, 0, szMe);
  caddr_t fname = bif_string_arg (qst, args, 1, szMe);
  gzFile gz_fd = NULL;
  int fd = 0;
  caddr_t fname_cvt, dname_cvt;
  int readed = 0;
  char buffer [0x8000];
  caddr_t err = NULL;

  sec_check_dba ((query_instance_t *) qst, szMe);

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  dname_cvt = file_native_name (dname);
  file_path_assert (fname_cvt, &err, 1);
  if (NULL != err)
    {
      dk_free_box (dname_cvt);
      sqlr_resignal (err);
    }
  fd = fd_open (fname_cvt, OPEN_FLAGS | O_TRUNC);
  if (fd < 0)
    {
      int errn = errno;
      dk_free_box (dname_cvt);
      dk_free_box (fname_cvt);
      sqlr_new_error ("39000", "FA053", "Can't open file %s, error : %s",
	  fname, virt_strerror (errn));
    }
  gz_fd = gzopen (dname_cvt, "r");
  if (!gz_fd)
    {
      dk_free_box (dname_cvt);
      dk_free_box (fname_cvt);
      sqlr_new_error ("39000", "FA054", "Can't open compressed file %s", dname);
    }

  for (;;)
    {
      readed = gzread (gz_fd, buffer, sizeof (buffer));
      if (readed > 0)
        write (fd, buffer, readed);
      else
	break;
    }

  gzclose (gz_fd);
  close(fd);

  dk_free_box (dname_cvt);
  dk_free_box (fname_cvt);

  return NULL;
}

caddr_t
get_message_header_field (char *szMessage, long message_size,
    caddr_t szHeaderFld)
{
  char szHeaderLine[1000], szAttr[1000], szValue[1000];
#ifdef DEBUG
  char chTemp;
#endif
  long offset = 0;
  long newOffset = 0, tempOffset = 0, lineOffset;
  int new_mode = 1;
  int override_to_mime = 0;
  caddr_t result = NULL;
  memset (szValue, '\x0', sizeof (szValue));
  /* skip the empty lines if in RFC822 header */
  while ((iswhite (szMessage + newOffset)
	  || isendline (szMessage + newOffset)) && newOffset < message_size)
    newOffset++;
  /* the header */
#ifdef DEBUG
  dbg_printf (("\n\n----------HEADER----------\n"));
#endif
  while (0 < (tempOffset =
	  mime_get_line (szMessage, message_size, newOffset, szHeaderLine,
	      1000)))
    {
      newOffset = tempOffset;
      lineOffset = 0;
      if (strlen (szHeaderLine) < 2)
	break;
      override_to_mime = 0;

      lineOffset =
	  mime_get_attr (szHeaderLine, 0, ':', &new_mode, &override_to_mime,
	  szAttr, 1000, szValue, 1000);
      if (lineOffset == -1)
	continue;
      dbg_printf (("Name : [%s]\nValue=[%s]\n", szAttr, szValue));
      if (0 == strnicmp (szAttr, szHeaderFld, box_length (szHeaderFld) - 1))
	{
	  result = (caddr_t) box_dv_short_string (szValue);
	  break;
	}
    }
#ifdef DEBUG
  dbg_printf (("\n\n----------HEADER END ----------\n"));
#endif
  if (!result)
    result = (caddr_t) box_dv_short_string ("");
  return result;
}

caddr_t
bif_get_mailmsg_hf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  volatile caddr_t res = NULL;
  long message_size = 0;
  caddr_t message = bif_string_arg (qst, args, 0, "mail_header");
  caddr_t hf = bif_string_arg (qst, args, 1, "mail_header");
  message_size = box_length (message) - 1;
  res = get_message_header_field (message, message_size, hf);
  return res;
}


id_hash_t *http_ext_to_mime_type = NULL;


char *
ws_file_ctype (char *name)
{
  char **ft, *dot = strrchr (name, '.'), szExtBuffer[20], *szPtr =
      szExtBuffer;
  int inx;
  if (http_ext_to_mime_type)
    {
      if (dot)
	name = dot + 1;
      for (inx = 0; inx < sizeof (szExtBuffer) - 1 && name[inx]; inx++)
	szExtBuffer[inx] = tolower (name[inx]);
      szExtBuffer[inx] = 0;
      ft = (char **) id_hash_get (http_ext_to_mime_type, (caddr_t) & szPtr);
      if (ft)
	return *ft;
    }
  return "application/octet-stream";
}


static caddr_t
bif_http_mime_type_add (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  char *szMe = "http_mime_type_add", *ptr;
  caddr_t ext = bif_string_arg (qst, args, 0, szMe);
  caddr_t mime_type = bif_string_or_null_arg (qst, args, 1, szMe);

  if (!http_ext_to_mime_type)
    {
      http_ext_to_mime_type = id_str_hash_create (101);
    }
  if (mime_type)
    {
      ext = box_dv_short_string (ext);
      for (ptr = (char *) ext; *ptr; ptr++)
	*ptr = tolower (*ptr);
      mime_type = box_dv_short_string (mime_type);
      id_hash_set (http_ext_to_mime_type,
	  (caddr_t) & ext, (caddr_t) & mime_type);
    }
  else
    id_hash_remove (http_ext_to_mime_type, (caddr_t) & ext);
  return NULL;
}


static caddr_t
bif_http_mime_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "http_mime_type";
  caddr_t ext = bif_string_arg (qst, args, 0, szMe);
  char *mime_type = ws_file_ctype (ext);

  return box_dv_short_string (mime_type);
}

#define Z_BUFSIZE 4096

typedef struct gz_stream
{
  z_stream stream;
  int z_err;			/* error code for last stream operation */
  Byte *inbuf;			/* input buffer */
  Byte *outbuf;			/* output buffer */
  uLong crc;			/* crc32 of uncompressed data */
  long startpos;		/* start of compressed data in file (header skipped) */
} gz_stream;


int
gz_s_free (gz_stream *s)
{
  int err = Z_OK;

  if (!s)
    return Z_STREAM_ERROR;

  if (s->stream.state != NULL)
    {
      err = deflateEnd (&(s->stream));
    }

  if (s->inbuf)
    dk_free (s->inbuf, -1);
  if (s->outbuf)
    dk_free (s->outbuf, -1);
  if (s)
    dk_free (s, -1);
  return err;
}

int
gz_stream_free (void * s)
{
  return gz_s_free ((gz_stream *)s);
}

int
do_flush_ses (gzFile file, int flush, dk_session_t *ses_out)
{
  uInt len;
  int done = 0;
  char temp[20];
  gz_stream *s = (gz_stream *) file;

  s->stream.avail_in = 0;	/* should be zero already anyway */

  for (;;)
    {
      len = Z_BUFSIZE - s->stream.avail_out;

      if (len != 0)
	{
	  snprintf (temp, sizeof (temp), "%x\r\n", len);
	  session_buffered_write (ses_out, temp, strlen (temp));
	  session_buffered_write (ses_out, (const char *) s->outbuf, len);
	  session_buffered_write (ses_out, "\r\n", 2);
	  s->stream.next_out = s->outbuf;
	  s->stream.avail_out = Z_BUFSIZE;
	}
      if (done)
	break;
      s->z_err = deflate (&(s->stream), flush);
      if (len == 0 && s->z_err == Z_BUF_ERROR)
	s->z_err = Z_OK;
      done = (s->stream.avail_out != 0 || s->z_err == Z_STREAM_END);

      if (s->z_err != Z_OK && s->z_err != Z_STREAM_END)
	break;
    }
  return s->z_err == Z_STREAM_END ? Z_OK : s->z_err;
}


static void
gzclose_ses (strses_chunked_out_t * outd)
{
  int n, err;
  uLong x;
  char temp[8];
  dk_session_t * ses_out = outd->sc_out;
  gz_stream *s = (gz_stream *) outd->sc_buff;

  if (s == NULL)
    return;

  err = do_flush_ses (s, Z_FINISH, ses_out);
  if (err != Z_OK)
    {
      gz_s_free (s);
      outd->sc_buff = NULL;
      return;
    }

  session_buffered_write (ses_out, "8\r\n", 3);

  x = s->crc;
  for (n = 0; n < 4; n++)
    {
      snprintf (temp, sizeof (temp), "%c", (int) (x & 0xff));
      session_buffered_write (ses_out, temp, 1);
      x >>= 8;
    }
  x = s->stream.total_in;
  for (n = 0; n < 4; n++)
    {
      snprintf (temp, sizeof (temp), "%c", (int) (x & 0xff));
      session_buffered_write (ses_out, temp, 1);
      x >>= 8;
    }

  session_buffered_write (ses_out, "\r\n0\r\n\r\n", 7);
  gz_s_free (s);
  outd->sc_buff = NULL;
  return;
}

static void
gz_write_head (dk_session_t * ses_out)
{
  char temp[16];
  snprintf (temp, sizeof (temp), "a\r\n%c%c%c%c%c%c%c%c%c%c\r\n",
      0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 3);
  session_buffered_write (ses_out, temp, 15);
}

static gzFile
gz_init_ses (dk_session_t * ses_out)
{
  int err;
  int level = Z_DEFAULT_COMPRESSION;
  int strategy = Z_DEFAULT_STRATEGY;
  gz_stream *s;

  s = (gz_stream *) dk_alloc (sizeof (gz_stream));

  if (!s)
    return Z_NULL;

  ZLIB_INIT_DK_STREAM (s->stream);
  s->stream.opaque = (voidpf) 0;
  s->stream.next_in = s->inbuf = Z_NULL;
  s->stream.next_out = s->outbuf = Z_NULL;
  s->stream.avail_in = s->stream.avail_out = 0;
  s->z_err = Z_OK;
  s->crc = crc32 (0L, Z_NULL, 0);
  level = 6;

  err = deflateInit2 (&(s->stream), level,
      Z_DEFLATED, -MAX_WBITS, DEF_MEM_LEVEL, strategy);

  s->stream.next_out = s->outbuf = (Byte *) dk_alloc (Z_BUFSIZE);
  if (err != Z_OK || s->outbuf == Z_NULL)
    {
      gz_s_free (s);
      return (gzFile) Z_NULL;
    }
  s->stream.avail_out = Z_BUFSIZE;

  s->startpos = 10L;

  return (gzFile) s;
}


static int
gzwrite_ses (strses_chunked_out_t * outd, const voidp buf, unsigned len)
{
  int len_buff;
  char temp[20];
  dk_session_t * ses_out = outd->sc_out;
  gz_stream *s = (gz_stream *) outd->sc_buff;

  s->stream.next_in = (Bytef *) buf;
  s->stream.avail_in = len;

  while (s->stream.avail_in != 0)
    {
      if (s->stream.avail_out == 0)
	{
	  s->stream.next_out = s->outbuf;
	  len_buff = Z_BUFSIZE;
	  snprintf (temp, sizeof (temp), "%x\r\n", len_buff);
	  session_buffered_write (ses_out, temp, strlen (temp));
	  session_buffered_write (ses_out, (const char *) s->outbuf, len_buff);
	  session_buffered_write (ses_out, "\r\n", 2);
	  session_flush_1 (ses_out);
	  s->stream.avail_out = Z_BUFSIZE;
	}
      s->z_err = deflate (&(s->stream), Z_NO_FLUSH);
      if (s->z_err != Z_OK)
	break;
    }
  s->crc = crc32 (s->crc, (const Bytef *) buf, len);

  return (int) (len - s->stream.avail_in);
}



static void
strses_chunked_out_buf (buffer_elt_t * buf, caddr_t arg)
{
  strses_chunked_out_t *outd = (strses_chunked_out_t *) arg;
  session_flush_1 (outd->sc_out);
  gzwrite_ses (outd, buf->data, (unsigned) buf->fill);
}


void
strses_write_out_gz (dk_session_t * ses, dk_session_t * out, strses_chunked_out_t * outd)
{
  OFF_T start;

  outd->sc_buff = gz_init_ses (out);
  outd->sc_out = out;
  session_flush_1 (out);
  start = out->dks_bytes_sent;
  gz_write_head (out);
  strses_map (ses, strses_chunked_out_buf, (caddr_t)outd);
  strses_file_map (ses, strses_chunked_out_buf, (caddr_t)outd);
  gzwrite_ses (outd, ses->dks_out_buffer, (unsigned) ses->dks_out_fill);
  gzclose_ses (outd); /* free of the stream and set outd->sc_buff to null as next flush on output may jump outside with dead memory in outd members */
  session_flush_1 (out);
  outd->sc_bytes_sent = out->dks_bytes_sent - start;
}

/*##**********************************************
 * An equivalent of the sleep UNIX command
 * takes a number of seconds to sleep current thread execution
 ************************************************/
int
virtuoso_sleep (long secs, long tms)
{
  int rc = 0;
#if !defined (WIN32)
  struct timeval tv;

  tv.tv_sec = secs;
  tv.tv_usec = tms;
  /* UNIX sleep() will sleep the current process until signal not arrived,
     so we make a fake select for read operation on stdout */
  rc = select (0, NULL, NULL, NULL, &tv);
#else
  /* The Windows Sleep suspends current thread execution */
  Sleep (secs * 1000 + tms / 1000);
#endif
  return rc;
}


static caddr_t
bif_sleep (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  double _tim = bif_double_arg (qst, args, 0, "sleep");
  long t = (long) _tim, tms;
  caddr_t ret = NULL;
  IO_SECT (qst);

  tms = (long) ((_tim - t) * 1000000.0);
  ret = box_num (virtuoso_sleep (t, tms));
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

#define DIME_MAKE16B(c, len, ind) { \
  			             c[0] = (dtp_t) (((len >> 8) & 0x1f) | (ind << 5)); \
			 	     c[1] = (dtp_t) (len & 0xff); \
                                  }

#define DIME_MAKE32B(c, len)      { \
				     c[0] = (dtp_t) ((len >> 24) & 0xff); \
				     c[1] = (dtp_t) ((len >> 16) & 0xff); \
				     c[2] = (dtp_t) ((len >> 8) & 0xff); \
				     c[3] = (dtp_t) (len & 0xff); \
				  }

#define DIME_PADDING 4
#define DIME_ALIGN(x) _RNDUP((x), DIME_PADDING)
#define DIME_PAD_LEN(x) (DIME_ALIGN(x) - x)
#define SES_WRITE_PADDED(ses, x, len) 	{ \
					  session_buffered_write (ses, x, len); \
					  padl = DIME_PAD_LEN (len); \
					  session_buffered_write (ses, (const char *) pad, padl); \
  				      	}

#define DIME_MIDDLE_CHUNK(f) (0 == (f & DIME_FIRST_CF) && (0 != (f & DIME_CF) || 0 != (f & DIME_LAST_CF)))

static int
dime_tnf (char *type, int len, int ind)
{
  caddr_t regex;
  if (DIME_MIDDLE_CHUNK (ind))
    return TNF_UNCHANGED;
  if (NULL != (regex =
	  regexp_match_01 ("[A-Za-z]+[A-Za-z0-9\\+\\.-]*:.*", type, 0)))
    {
      dk_free_box (regex);
      return TNF_URI;
    }
  else if (NULL != (regex =
	  regexp_match_01 ("[A-Za-z-]+/[A-Za-z-]+(;.*)?", type, 0)))
    {
      dk_free_box (regex);
      return TNF_MTYPE;
    }
  else if (!strlen (type) && len == 0)
    return TNF_NONE;
  return TNF_UNKNOWN;
}

/*
                                     1  1  1  1  1  1
       0  1  2  3  4  5  6  7  8  9  0  1  2  3  4  5
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     |MB|ME|CF|              ID_LENGTH               |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     |   TNF  |             TYPE_LENGTH              |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     |                  DATA_LENGTH                  |
     |                                               |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     |                  ID + PADDING                 /
     /                                               |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     |                 TYPE + PADDING                /
     /                                               |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
     |                                               /
     /                 DATA + PADDING                /
     /                                               |
     +--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
*/

#ifdef DIME_V1
static void
dime_compose_1 (dk_session_t * ses, caddr_t msg, char *id, char *type,
    int ind)
{
  uint32 len = box_length (msg) - 1;
  uint16 idlen = (uint16) ((id
	  && !DIME_MIDDLE_CHUNK (ind)) ? strlen (id) : 0);
  uint16 tlen = (uint16) ((type
	  && !DIME_MIDDLE_CHUNK (ind)) ? strlen (type) : 0);
  int tnf;
  dtp_t c[4], pad[32];
  int padl;

  memset (pad, 0, sizeof (pad));
  DIME_MAKE16B (c, idlen, (ind & 0x0f));
  session_buffered_write (ses, c, 2);

  tnf = dime_tnf (type, (len + tlen), ind);

  if (!tlen || tnf == TNF_UNKNOWN)
    {
      type = "";
      tlen = 0;
    }
  if (!idlen)
    id = "";

  DIME_MAKE16B (c, tlen, tnf);
  session_buffered_write (ses, c, 2);

  DIME_MAKE32B (c, len);
  session_buffered_write (ses, c, 4);

  SES_WRITE_PADDED (ses, id, idlen);	/* id, type & data must be padded to 4b */
  SES_WRITE_PADDED (ses, type, tlen);
  SES_WRITE_PADDED (ses, msg, len);
}
#endif

/* draft-nielsen-dime-02 */

/*
      VERSION = 0x01
      RESRVD  = 0x00

      0                   1                   2                   3
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |         |M|M|C|       |       |                               |
     | VERSION |B|E|F| TYPE_T| RESRVD|         OPTIONS_LENGTH        |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |            ID_LENGTH          |           TYPE_LENGTH         |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                          DATA_LENGTH                          |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               /
     /                     OPTIONS + PADDING                         /
     /                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               /
     /                          ID + PADDING                         /
     /                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               /
     /                        TYPE + PADDING                         /
     /                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               /
     /                        DATA + PADDING                         /
     /                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/

#define DIME_MAKE_H_V2(c,ind,tnf) { \
  			             c[0] = (dtp_t) ((0x01<<3) | (ind & 0x7)); \
			 	     c[1] = (dtp_t) ((tnf<<4) & 0x0f); \
                                   }

#define DIME_MAKE16B_V2(c, n) { \
  			        c[0] = (dtp_t) (n >> 8); \
			        c[1] = (dtp_t) (n & 0xff); \
                              }

/* XXX: OPTIONS are unhandled for now */
static void
dime_compose_2 (dk_session_t * ses, caddr_t msg, char *id, char *type,
    int ind)
{
  uint32 len = box_length (msg) - 1;
  uint16 idlen = (uint16) ((id
	  && !DIME_MIDDLE_CHUNK (ind)) ? strlen (id) : 0);
  uint16 tlen = (uint16) ((type
	  && !DIME_MIDDLE_CHUNK (ind)) ? strlen (type) : 0);
  uint16 opt_len = (uint16) 0;
  int tnf;
  dtp_t c[4], pad[32];
  int padl;

  memset (pad, 0, sizeof (pad));

  tnf = dime_tnf (type, (len + tlen), ind);

  DIME_MAKE_H_V2 (c, ind, tnf);	/* version, flags, TNF and reserved */
  session_buffered_write (ses, (const char *) c, 2);

  DIME_MAKE16B_V2 (c, opt_len);	/* options length, 0 for now */
  session_buffered_write (ses, (const char *) c, 2);

  if (!tlen || tnf == TNF_UNKNOWN)
    {
      type = "";
      tlen = 0;
    }

  if (!idlen)
    id = "";

  DIME_MAKE16B_V2 (c, idlen);
  session_buffered_write (ses, (const char *) c, 2);

  DIME_MAKE16B_V2 (c, tlen);
  session_buffered_write (ses, (const char *) c, 2);

  DIME_MAKE32B (c, len);
  session_buffered_write (ses, (const char *) c, 4);

  SES_WRITE_PADDED (ses, "", 0);	/* options must be here */

  SES_WRITE_PADDED (ses, id, idlen);	/* id, type & data must be padded to 4b */
  SES_WRITE_PADDED (ses, type, tlen);
  SES_WRITE_PADDED (ses, msg, len);
}

void
soap_dime_tree (caddr_t body, dk_set_t * set, caddr_t * err)
{
  caddr_t data = NULL, id = NULL, type = NULL, opts = NULL;
  uint32 len, dlen, ilen, tlen, opt_len, to_read, to_read_len, readed;
  int padl, inx, flag, tnf, ver;
  dk_session_t ses, *chunks = NULL;
  scheduler_io_data_t sio;
  dtp_t dimeh[12];
  char pad[32];
  len = box_length (body);
  memset (&ses, 0, sizeof (dk_session_t));
  memset (&sio, 0, sizeof (scheduler_io_data_t));
  SESSION_SCH_DATA (&ses) = &sio;
  ses.dks_in_buffer = body;
  ses.dks_in_fill = len - 1;

  CATCH_READ_FAIL (&ses)
    {
      for (inx = 0;; inx++)
	{
	  session_buffered_read (&ses, (char *) dimeh, sizeof (dimeh));

	  ver = (int) (dimeh[0] >> 3);
	  flag = (int) (dimeh[0] & 0x7);
	  tnf = (int) (dimeh[1] >> 4);

	  opt_len = (uint32) ((dimeh[2] << 8) | dimeh[3]);	/* options len */

	  ilen = (uint32) ((dimeh[4] << 8) | dimeh[5]);
	  tlen = (uint32) ((dimeh[6] << 8) | dimeh[7]);
	  dlen =
	      (uint32) ((dimeh[8] << 24) | (dimeh[9] << 16) | (dimeh[10] << 8) |
			dimeh[11]);

	  /*	  fprintf (stderr, "DIME rec: f:(%X) tnf(%X) , i(%d) t(%d), d(%d)\n", flag, tnf, ilen, tlen, dlen);*/

	  if (tnf > TNF_NONE)	/* draft-dime section 3.2.5 */
	    tnf = TNF_UNKNOWN;

	  if (ver != 0x01)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM09", "Wrong DIME Version");
	      break;
	    }

	  if (!inx && 0 == (flag & DIME_MB))
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM01",
		      "The DIME message do not have MB flag in first record");
	      break;
	    }

	  if (ilen > MIME_POST_LIMIT || tlen > MIME_POST_LIMIT
	      || dlen > MIME_POST_LIMIT)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM02",
		      "The decoded DIME message part is limited to a 10Mb");
	      break;
	    }

	  if (0 != (flag & DIME_CF) && 0 != (flag & DIME_ME))
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM04",
		      "The last DIME message chunk must not have CF flag");
	      break;
	    }

	  if (chunks && ilen > 0 && tlen > 0)
	    {
	      *err = srv_make_new_error ("22023", "DIM05",
		  "The middle DIME message chunks must not have id and type");
	      break;
	    }

	  if (tnf == TNF_UNKNOWN && tlen > 0)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM06",
		      "The TNF Unknown requires type to be empty");
	      break;
	    }

	  if (tnf == TNF_NONE && (tlen != 0 || dlen != 0))
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM07",
		      "The TNF None requires type and data to be empty");
	      break;
	    }

	  if (chunks && tnf != TNF_UNCHANGED)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM07",
		      "The TNF Unchanged requires on middle and last chunks");
	      break;
	    }


	  if (!chunks)
	    {
	      id = dk_alloc_box_zero (ilen + 1, DV_STRING);
	      type = dk_alloc_box_zero (tlen + 1, DV_STRING);
	      opts = dk_alloc_box_zero (opt_len + 1, DV_STRING);
	    }

	  if (0 != (flag & DIME_CF) && !chunks)
	    chunks = strses_allocate ();
	  else if (!chunks)
	    data = dk_alloc_box_zero (dlen + 1, DV_STRING);

	  if (opt_len > 0)
	    session_buffered_read (&ses, opts, opt_len);
	  if (0 != (padl = DIME_PAD_LEN (opt_len)))
	    session_buffered_read (&ses, pad, padl);

	  if (ilen > 0)
	    session_buffered_read (&ses, id, ilen);
	  if (0 != (padl = DIME_PAD_LEN (ilen)))
	    session_buffered_read (&ses, pad, padl);

	  if (tlen > 0)
	    session_buffered_read (&ses, type, tlen);
	  if (0 != (padl = DIME_PAD_LEN (tlen)))
	    session_buffered_read (&ses, pad, padl);

	  if (!chunks)
	    session_buffered_read (&ses, data, dlen);
	  else
	    {
	      /* read the chunk data */
	      to_read = dlen;
	      to_read_len = sizeof (pad);
	      do
		{
		  if (to_read < to_read_len)
		    to_read_len = to_read;
		  readed = session_buffered_read (&ses, pad, to_read_len);
		  to_read -= readed;
		  if (readed > 0)
		    session_buffered_write (chunks, pad, readed);
		}
	      while (to_read > 0);
	    }
	  if (0 != (padl = DIME_PAD_LEN (dlen)))
	    session_buffered_read (&ses, pad, padl);

	  if (!chunks)
	    dk_set_push (set, (void *) list (4, id, type, data, opts));
	  else if (chunks && 0 == (flag & DIME_CF))
	    {
	      if (!STRSES_CAN_BE_STRING (chunks))
		{
		  *err = STRSES_LENGTH_ERROR ("dime_tree");
		  break;
		}
	      data = strses_string (chunks);
	      dk_free_box ((box_t) chunks);
	      chunks = NULL;
	      dk_set_push (set, (void *) list (4, id, type, data, opts));
	    }

	  if (ses.dks_in_fill == ses.dks_in_read)
	    {
	      if (0 == (flag & DIME_ME))
		*err =
		    srv_make_new_error ("22023", "DIM03",
			"The DIME do not have ME flag in last record");
	      break;
	    }
	}
    }
  END_READ_FAIL (&ses);
  dk_free_box ((box_t) chunks);
}

void
dime_compose (dk_session_t * ses, caddr_t * input, caddr_t * err)
{
  caddr_t msg, id, type;
  int offs = 0, prevf = 0, inx, len = input ? BOX_ELEMENTS (input) : 0;
  DO_BOX (caddr_t *, elm, inx, input)
    {
      prevf = offs;
      if (len == 1)
        offs = (DIME_MB | DIME_ME);
      else if (inx == (len - 1))
        offs = DIME_ME;
      else if (!inx)
        offs = DIME_MB;
      else
        offs = DIME_NA;
      if (!ARRAYP (elm) || BOX_ELEMENTS (elm) < 3 ||
          !DV_STRINGP (elm[0]) || !DV_STRINGP (elm[1]) || !DV_STRINGP (elm[2]))
        {
          *err = srv_make_new_error ("22023", "SR014",
              "Function dime_compose needs an array of string arrays as argument 1");
          return;
        }
      if (BOX_ELEMENTS (elm) > 3 && unbox (elm[3]) > 0)
        {
          if (0 == (offs & DIME_ME))
            {
              offs |= DIME_CF;
              if (0 == (prevf & DIME_CF))
                offs |= DIME_FIRST_CF;
            }
          else if (0 != (prevf & DIME_CF))
            offs |= DIME_LAST_CF;
        }
      else if (0 != (prevf & DIME_CF))
        offs |= DIME_LAST_CF;

      msg = elm[2];
      id = elm[0];
      type = elm[1];
      dime_compose_2 (ses, msg, id, type, offs);
    }
  END_DO_BOX;
}

static caddr_t
bif_dime_compose (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *input =
      (caddr_t *) bif_strict_array_or_null_arg (qst, args, 0, "dime_compose");
  dk_session_t *ses = strses_allocate ();
  caddr_t err = NULL, res;

  if (!input)
    sqlr_new_error ("22023", "SR014",
	"Function dime_compose needs an array as argument 1, "
	"not an arg of type DB_NULL (204)");

  dime_compose (ses, input, &err);
  if (err)
    {
      dk_free_box ((box_t) ses);
      sqlr_resignal (err);
    }

  if (!STRSES_CAN_BE_STRING (ses))
    {
      *err_ret = STRSES_LENGTH_ERROR ("dime_compose");
      res = NULL;
    }
  else
    res = strses_string (ses);
  dk_free_box ((box_t) ses);
  return res;
}

void
dime_tree_1 (caddr_t body, dk_set_t * set, caddr_t * err)
{
  caddr_t data = NULL, id = NULL, type = NULL;
  uint32 len, dlen, ilen, tlen, to_read, to_read_len, readed;
  int padl, inx, flag, tnf;
  dk_session_t ses, *chunks = NULL;
  scheduler_io_data_t sio;
  dtp_t dimeh[8];
  char pad[32];
  len = box_length (body);
  memset (&ses, 0, sizeof (dk_session_t));
  memset (&sio, 0, sizeof (scheduler_io_data_t));
  SESSION_SCH_DATA (&ses) = &sio;
  ses.dks_in_buffer = body;
  ses.dks_in_fill = len - 1;

  CATCH_READ_FAIL (&ses)
    {
      for (inx = 0;; inx++)
	{
	  session_buffered_read (&ses, (char *) dimeh, sizeof (dimeh));
	  ilen = (uint32) (((dimeh[0] & 0x1f) << 8) | dimeh[1]);
	  tlen = (uint32) (((dimeh[2] & 0x1f) << 8) | dimeh[3]);
	  dlen =
	      (uint32) ((dimeh[4] << 24) | (dimeh[5] << 16) | (dimeh[6] << 8) |
			dimeh[7]);
	  flag = (int) (dimeh[0] >> 5);
	  tnf = (int) (dimeh[2] >> 5);

	  /*	  fprintf (stderr, "DIME rec: f:(%X) tnf(%X) , i(%d) t(%d), d(%d)\n", flag, tnf, ilen, tlen, dlen);*/

	  if (tnf > TNF_NONE)	/* draft-dime section 3.2.5 */
	    tnf = TNF_UNKNOWN;

	  if (!inx && 0 == (flag & DIME_MB))
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM01",
		      "The DIME message do not have MB flag in first record");
	      break;
	    }

	  if (ilen > MIME_POST_LIMIT || tlen > MIME_POST_LIMIT
	      || dlen > MIME_POST_LIMIT)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM02",
		      "The decoded DIME message part is limited to a 10Mb");
	      break;
	    }

	  if (0 != (flag & DIME_CF) && 0 != (flag & DIME_ME))
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM04",
		      "The last DIME message chunk must not have CF flag");
	      break;
	    }

	  if (chunks && ilen > 0 && tlen > 0)
	    {
	      *err = srv_make_new_error ("22023", "DIM05",
		  "The middle DIME message chunks must not have id and type");
	      break;
	    }

	  if (tnf == TNF_UNKNOWN && tlen > 0)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM06",
		      "The TNF Unknown requires type to be empty");
	      break;
	    }

	  if (tnf == TNF_NONE && (tlen != 0 || dlen != 0))
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM07",
		      "The TNF None requires type and data to be empty");
	      break;
	    }

	  if (chunks && tnf != TNF_UNCHANGED)
	    {
	      *err =
		  srv_make_new_error ("22023", "DIM07",
		      "The TNF Unchanged requires on middle and last chunks");
	      break;
	    }


	  if (!chunks)
	    {
	      id = dk_alloc_box_zero (ilen + 1, DV_STRING);
	      type = dk_alloc_box_zero (tlen + 1, DV_STRING);
	    }

	  if (0 != (flag & DIME_CF) && !chunks)
	    chunks = strses_allocate ();
	  else if (!chunks)
	    data = dk_alloc_box_zero (dlen + 1, DV_STRING);

	  if (ilen > 0)
	    session_buffered_read (&ses, id, ilen);
	  if (0 != (padl = DIME_PAD_LEN (ilen)))
	    session_buffered_read (&ses, pad, padl);

	  if (tlen > 0)
	    session_buffered_read (&ses, type, tlen);
	  if (0 != (padl = DIME_PAD_LEN (tlen)))
	    session_buffered_read (&ses, pad, padl);

	  if (!chunks)
	    session_buffered_read (&ses, data, dlen);
	  else
	    {
	      /* read the chunk data */
	      to_read = dlen;
	      to_read_len = sizeof (pad);
	      do
		{
		  if (to_read < to_read_len)
		    to_read_len = to_read;
		  readed = session_buffered_read (&ses, pad, to_read_len);
		  to_read -= readed;
		  if (readed > 0)
		    session_buffered_write (chunks, pad, readed);
		}
	      while (to_read > 0);
	    }
	  if (0 != (padl = DIME_PAD_LEN (dlen)))
	    session_buffered_read (&ses, pad, padl);

	  if (!chunks)
	    dk_set_push (set, (void *) list (3, id, type, data));
	  else if (chunks && 0 == (flag & DIME_CF))
	    {
	      if (!STRSES_CAN_BE_STRING (chunks))
		{
		  *err = STRSES_LENGTH_ERROR ("dime_tree");
		  data = NULL;
		}
	      else
		data = strses_string (chunks);
	      dk_free_box ((box_t) chunks);
	      chunks = NULL;
	      dk_set_push (set, (void *) list (3, id, type, data));
	    }

	  if (ses.dks_in_fill == ses.dks_in_read)
	    {
	      if (0 == (flag & DIME_ME))
		*err =
		    srv_make_new_error ("22023", "DIM03",
			"The DIME do not have ME flag in last record");
	      break;
	    }
	}
    }
  END_READ_FAIL (&ses);
  dk_free_box ((box_t) chunks);
}

static caddr_t
bif_dime_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t body = bif_string_arg (qst, args, 0, "dime_tree");
  dk_set_t parts = NULL;
  caddr_t err = NULL;
  soap_dime_tree (body, &parts, &err);
  if (err)
    {
      dk_free_tree (list_to_array (dk_set_nreverse (parts)));
      sqlr_resignal (err);
    }
  return list_to_array (dk_set_nreverse (parts));
}

static int
get_mode_string (caddr_t user_str, int set)
{
  int i = 0;
  LOG_STR_D;

  for (i = 0; i < LOG_STR_L; i += 1)
    {
      if (!stricmp (user_str, str[i]))	/* XXX CASE !!! XXX */
	{
	  if (set)
	    log_stat |= 1 << i;
	  else
	    log_stat &= ~(1 << i);
	  return 1;
	}
    }

  return 0;
}


void
set_ini_trace_option ()
{
  char *tmp, *tok_s = NULL, *tok;
  tok_s = NULL;
  tok = strtok_r (init_trace, ",", &tok_s);
  while (tok)
    {
      while (*tok && isspace (*tok))
	tok++;
      if (tok_s)
	tmp = tok_s - 2;
      else if (tok && strlen (tok) > 1)
	tmp = tok + strlen (tok) - 1;
      else
	tmp = NULL;
      while (tmp && tmp >= tok && isspace (*tmp))
	*(tmp--) = 0;
      if (!get_mode_string (tok, 1))
	{
	  log_info ("%s is not valid TraceOn option", tok);
	}
      tok = strtok_r (NULL, ",", &tok_s);
    }
}


caddr_t
bif_trace_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t list = NULL;
  int i = 0;
  char temp[32];
  LOG_STR_D;

  sec_check_dba ((query_instance_t *) qst, "trace_status");

  for (i = 1; i < LOG_STR_L; i += 1)
    {
      strcpy_ck (temp, str[i]);
      dk_set_push (&list, box_dv_short_string (temp));

      if (log_stat & (1 << i))
	strcpy_ck (temp, "on");
      else
	strcpy_ck (temp, "off");

      dk_set_push (&list, box_dv_short_string (temp));

    }

  return list_to_array (dk_set_nreverse (list));
}


caddr_t
bif_trace_on (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t mode;
  long n_args = BOX_ELEMENTS (args);
  int res = 0;

  sec_check_dba ((query_instance_t *) qst, "trace_on");

  if (!n_args)
    {
      log_stat = -1;		/* XXX All traces XXX */
      return NULL;
    }

  while (n_args)
    {
      mode = bif_string_arg (qst, args, n_args - 1, "trace_on");
      res = get_mode_string (mode, 1);

      if (!res)
	{
	  *err_ret =
	      srv_make_new_error ("22005", "SR322",
	      " %s is not valid trace_on option", mode);
	  return NULL;
	}

      n_args = n_args - 1;
    }

  return box_num (res);
}


caddr_t
bif_trace_off (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t mode;
  long n_args = BOX_ELEMENTS (args);
  int res = 0;

  sec_check_dba ((query_instance_t *) qst, "trace_off");

  if (!n_args)
    {
      log_stat = 0;
      return NULL;
    }

  while (n_args)
    {
      mode = bif_string_arg (qst, args, n_args - 1, "trace_on");
      res = get_mode_string (mode, 0);

      if (!res)
	{
	  *err_ret =
	      srv_make_new_error ("22005", "SR323",
	      " %s is not valid trace_off option", mode);
	  return NULL;
	}

      n_args = n_args - 1;
    }

  return box_num (res);
}


#if 0 && defined (WIN32)
static caddr_t
bif_malloc_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long times = bif_long_arg (qst, args, 0, "malloc_test");
  long size = bif_long_arg (qst, args, 1, "malloc_test");
  long inx;
  void **array = (void **) malloc (times * sizeof (void *));
  memset (array, 0, times * sizeof (void *));

  for (inx = 0; inx < times; inx++)
    array[inx] = malloc (size);

  for (inx = 0; inx < times; inx++)
    free (array[inx]);
  free (array);
  return NULL;
}

static caddr_t
bif_heap_compact (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  HANDLE ph = GetProcessHeap ();
  HeapCompact (ph, 0);
  return NULL;
}
#endif

static caddr_t
bif_log_message (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /*long level = bif_long_arg (qst, args, 0, "log_message"); */
  caddr_t msg = bif_string_arg (qst, args, 0, "log_message");

  sec_check_dba ((query_instance_t *) qst, "log_message");
#ifdef DEBUG
  log_info ("PL LOG: %.20000s", msg);
#else
  log_info ("PL LOG: %.200s", msg);
#endif
  return NULL;
}

/*#define HAVE_BIF_GPF 1*/
#ifdef HAVE_BIF_GPF
static caddr_t
bif_gpf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *) qst, "__gpf");

  GPF_T;
  return NULL;
}
#endif

#if defined (__APPLE__) && defined(SPOTLIGHT)
/* --------------------------------------- */
/* CoreFoundation objects to virtuoso type */
/* --------------------------------------- */


static caddr_t
core_foundation_to_virt (CFTypeRef * source)
{
  CFTypeID typeid;
  typeid = CFGetTypeID(*source);

  if (typeid == CFArrayGetTypeID())
      {
	int i;
	dk_set_t list_ret = NULL;
	CFIndex attr_count;
	attr_count = CFArrayGetCount (* source);
	for (i = 0; i < attr_count; i++)
	  {
	    CFTypeRef item_cf;
	    item_cf = CFArrayGetValueAtIndex(*source, i);
	    dk_set_push (&list_ret, core_foundation_to_virt (&item_cf));
	  }
	return list_to_array (dk_set_nreverse (list_ret));
      }
  else if (typeid == CFStringGetTypeID())
    {
	char buffer[1024];
        CFStringGetCString (*source, buffer, sizeof (buffer), CFStringGetSystemEncoding());
	return box_dv_short_string (buffer);
    }
  else if (typeid == CFBooleanGetTypeID())
    {
      return box_num ((long)CFBooleanGetValue(*source));
    }
  else if (typeid == CFNumberGetTypeID())
    {
      double d;
      CFNumberGetValue(*source, kCFNumberDoubleType, &d);
      return box_double (d);
    }
  else if (typeid == CFDateGetTypeID())
    {
      long abs_time;
      TIMESTAMP_STRUCT ts;
      caddr_t res;

      ts.year = 2001;
      ts.month = 1;
      ts.day = 1;
      ts.hour = 0;
      ts.minute = 0;
      ts.second = 0;
      ts.fraction = 0;

      abs_time = (long) CFDateGetAbsoluteTime (*source);

      ts_add (&ts, abs_time, "second");

      res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
      timestamp_struct_to_dt (&ts, res);
      return res;
    }
  if (typeid == CFDictionaryGetTypeID())
    return NEW_DB_NULL;

  return box_num (0);
}

static caddr_t
bif_spotlight_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (spotlight_integration);
}

static caddr_t
bif_spotlight_metadata (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int i = 0;
  caddr_t f_name = bif_string_arg (qst, args, 0, "spotlight_metadata");
  CFStringRef path = NULL;

  sec_check_dba ((query_instance_t *) qst, "spotlight_metadata");

  if (!spotlight_integration)
    return NEW_DB_NULL;

  path = CFStringCreateWithCString((CFAllocatorRef)NULL, f_name, kCFStringEncodingASCII);

  caddr_t ret = NULL;
  dk_set_t list_r = NULL;
  MDItemRef item = NULL;
  CFArrayRef attr_names;
  CFTypeRef val;
  CFIndex attr_count;

  item = MDItemCreate(kCFAllocatorDefault, path);

  if (!item)
    {
      *err_ret = srv_make_new_error ("39000", "FA046", "Can't open file %s", f_name);
      return NULL;
    }

  attr_names = MDItemCopyAttributeNames (item);

  attr_count = attr_names ? CFArrayGetCount (attr_names) : 0;

  for (i = 0; i < attr_count; i++)
    {
	CFStringRef attr_name = (CFStringRef)CFArrayGetValueAtIndex (attr_names, i);
 	val = MDItemCopyAttribute (item, attr_name);
	dk_set_push (&list_r, list (2,
	      core_foundation_to_virt ((CFTypeRef *)&attr_name),
	      core_foundation_to_virt (&val)));
    }

  ret = list_to_array (dk_set_nreverse (list_r));
  return ret;
}
#endif

caddr_t
bif_vector_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t in_vector, out_vector;
  int inx;
  in_vector = bif_strict_array_or_null_arg (qst, args, 0, "__vector_sort");
  if (in_vector == NULL || in_vector == NEW_DB_NULL)
    return NEW_DB_NULL;
  DO_BOX (caddr_t, line, inx, ((caddr_t *) in_vector))
    {
      dtp_t dtp;
      dtp = DV_TYPE_OF (line);

      if (dtp != DV_SHORT_STRING)
	sqlr_new_error ("22023", "SR482",
	    "Function vector_sort() needs a vector of strings as the first argument, but the vector contains %s (%d)", dv_type_title (dtp), dtp);
    }
  END_DO_BOX;
  out_vector = box_copy_tree (in_vector);
  qsort (out_vector, BOX_ELEMENTS (out_vector), sizeof (caddr_t), str_compare);
  return out_vector;
}

int
filep_destroy (caddr_t fdi)
{
  int fd = (int) *(boxint *) fdi;
  if (fd > 0)
    fd_close (fd, NULL);
  return 0;
}

caddr_t
bif_file_rlc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fdi = bif_arg (qst, args, 0, "file_rlc");
  volatile int fd;
  sec_check_dba ((query_instance_t *) qst, "file_rlc");
  if (DV_TYPE_OF (fdi) != DV_FD)
    sqlr_new_error ("22023", "SSSSS", "The argument of file_rlc must be an valid file pointer");
  fd = (int) *(boxint *) fdi;
  if (fd < 0)
    sqlr_new_error ("22023", "SSSSS", "The file pointer is already closed");
  fd_close (fd, NULL);
  *(boxint *) fdi = (boxint) -1;
  return box_num (1);
}

caddr_t
bif_file_rlo (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname = bif_string_arg (qst, args, 0, "file_rlo");
  caddr_t *ret;
  volatile int fd;
#ifdef HAVE_DIRECT_H
  char *fname_cvt, *fname_tail;
  size_t fname_cvt_len;
#endif

  sec_check_dba ((query_instance_t *) qst, "file_rlo");

#ifdef HAVE_DIRECT_H
  fname_cvt_len = strlen (fname) + 1;
  fname_cvt = dk_alloc (fname_cvt_len);
  strcpy_size_ck (fname_cvt, fname, fname_cvt_len);
  for (fname_tail = fname_cvt; fname_tail[0]; fname_tail++)
    {
      if ('/' == fname_tail[0])
	fname_tail[0] = '\\';
    }
  if (!is_allowed (fname_cvt))
    {
      dk_free (fname_cvt, fname_cvt_len);
      sqlr_new_error ("42000", "FA003",
	  "Access to %s is denied due to access control in ini file", fname);
    }

  fd = fd_open (fname_cvt, OPEN_FLAGS_RO);
  dk_free (fname_cvt, fname_cvt_len);
#else
  if (!is_allowed (fname))
    sqlr_new_error ("42000", "FA004",
	"Access to %s is denied due to access control in ini file", fname);

  fd = fd_open (fname, OPEN_FLAGS_RO);
#endif

  if (fd < 0)
    {
      int errn = errno;
      sqlr_new_error ("39000", "FA003", "Can't open file %s, error : %s",
	  fname, virt_strerror (errn));
    }

  ret = (caddr_t *) dk_alloc_box (sizeof (boxint), DV_FD);
  *(boxint *) ret = (boxint) fd;

  return (caddr_t) ret;
}

int
ses_read_line_unbuffered (dk_session_t * ses, char *buf, int max, char * state)
{
  int inx = 0;
  buf[0] = 0;

  for (;;)
    {
      char c, pc = *state;
      service_read (ses, &c, 1, 1);
      if (0 == inx && pc == 13 && c == 10)
	continue;
      if (inx < max - 1)
	buf[inx++] = c;
      if (c == 10 || c == 13)
	{
	  *state = c;
	  buf[inx-1] = 0;
	  return inx;
	}
    }
}

caddr_t
bif_file_rl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fdi = bif_arg (qst, args, 0, "file_rl");
  long inx = (long) bif_long_arg (qst, args, 1, "file_rl");
  long max_len = BOX_ELEMENTS (args) > 2 ? (long) bif_long_arg (qst, args, 2, "file_rl") : 80*1024;
  caddr_t str;
  volatile int fd;
  dk_set_t line = NULL;
  caddr_t ret = NULL;
  dk_session_t *file_in;

  sec_check_dba ((query_instance_t *) qst, "file_rl");

  if (DV_TYPE_OF (fdi) != DV_FD)
    sqlr_new_error ("22023", "SSSSS", "The argument of file_rl must be an valid file pointer");

  fd = *(boxint *) fdi;
  if (fd < 0)
    sqlr_new_error ("22023", "SSSSS", "The file pointer is already closed");

  if (max_len <= 0 || max_len > 1000000)
    sqlr_new_error ("22023", "SSSSS", "The max length of line could not be less than 1 and over 1mb");

  str = dk_alloc_box (max_len, DV_STRING);
  str[0]=0;

  file_in = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (file_in->dks_session, fd);
  CATCH_READ_FAIL (file_in)
    {
      char state = '\0';
      OFF_T pos;
      do
	{
	  ses_read_line_unbuffered (file_in, str, max_len, &state);
	  if (str[0])
	    dk_set_push (&line, box_dv_short_string (str));
	  str[0]=0;
	  inx--;
	}
      while (inx);
      if (state == 13) /* after so many reads we look for last LF, if no LF, we restore position */
	{
	  char c;
          pos = LSEEK (fd, 0L, SEEK_CUR);
	  service_read (file_in, &c, 1, 1);
	  if (c != 10)
	    LSEEK (fd, pos, SEEK_SET);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (file_in);
  PrpcSessionFree (file_in);
  dk_free_box (str);
  ret = list_to_array (dk_set_nreverse (line));
  return ret;
}

caddr_t
bif_file_open (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname = bif_string_arg (qst, args, 0, "file_open");
  dk_session_t * ses = strses_allocate ();
  caddr_t fname_cvt, err = NULL;
  int fd = 0;
  OFF_T off;
  strsestmpfile_t * sesfile;

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, &err, 0);
  if (NULL != err)
    goto signal_error;
  fd = fd_open (fname_cvt, OPEN_FLAGS_RO);

  if (fd < 0)
    {
      int errn = errno;
      err = srv_make_new_error ("39000", "FA006", "Can't open file '%.1000s', error : %s",
	  fname_cvt, virt_strerror (errn));
      goto signal_error;
    }

  off = LSEEK (fd, 0, SEEK_END);
  if (off == -1)
    {
      int saved_errno = errno;
      fd_close (fd, fname);
      err = srv_make_new_error ("39000", "FA025",
	  "Seek error in file '%.1000s', error : %s", fname_cvt, virt_strerror (saved_errno));
      goto signal_error;
    }
  LSEEK (fd, 0, SEEK_SET);
  strses_enable_paging (ses, DKSES_IN_BUFFER_LENGTH);
  sesfile = ses->dks_session->ses_file;
  sesfile->ses_file_descriptor = fd;
  sesfile->ses_fd_fill = sesfile->ses_fd_fill_chars = off;
  dk_free_box (fname_cvt);
  return (caddr_t) ses;
signal_error:
  /* cleanup */
  dk_free_box (fname_cvt);
  dk_free_box ((caddr_t) ses);
  sqlr_resignal (err);
  return NULL;
}

caddr_t
bif_getenv (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t var = bif_string_arg (qst, args, 0, "getenv");
  char * res = NULL;
  sec_check_dba ((query_instance_t *)qst, "getenv");
  res = getenv (var);
  return res ? box_dv_short_string (res) : NEW_DB_NULL;
}

/* hooks for operating on gz stram via string session */

OFF_T
zlib_lseek (strsestmpfile_t * sesfile, OFF_T offset, int whence)
{
  return gzseek (sesfile->ses_file_ctx, offset, whence);
}

size_t
zlib_read (strsestmpfile_t * sesfile, void *buf, size_t nbyte)
{
  return gzread (sesfile->ses_file_ctx, buf, nbyte);
}

static size_t
zlib_write (strsestmpfile_t * sesfile, const void *buf, size_t nbyte)
{
  return -1; /* write is not supported in gz stream for now */
}

int
zlib_close (strsestmpfile_t * sesfile)
{
  return gzclose (sesfile->ses_file_ctx); /* this must close the fd passed earlier to gzdopen  */
}

caddr_t
bif_gz_file_open (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname = bif_string_arg (qst, args, 0, "gz_file_open");
  dk_session_t * ses = strses_allocate ();
  caddr_t fname_cvt, err = NULL;
  int fd = 0;
  OFF_T off;
  strsestmpfile_t * sesfile;

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, &err, 0);
  if (NULL != err)
    goto signal_error;
  fd = fd_open (fname_cvt, OPEN_FLAGS_RO);

  if (fd < 0)
    {
      int errn = errno;
      err = srv_make_new_error ("39000", "FA006", "Can't open file '%.1000s', error : %s",
	  fname_cvt, virt_strerror (errn));
      goto signal_error;
    }

  off = LSEEK (fd, 0, SEEK_END);
  if (off == -1)
    {
      int saved_errno = errno;
      fd_close (fd, fname);
      err = srv_make_new_error ("39000", "FA025",
	  "Seek error in file '%.1000s', error : %s", fname_cvt, virt_strerror (saved_errno));
      goto signal_error;
    }
  LSEEK (fd, 0, SEEK_SET);
  strses_enable_paging (ses, DKSES_IN_BUFFER_LENGTH);
  sesfile = ses->dks_session->ses_file;
  sesfile->ses_file_descriptor = -1;

  sesfile->ses_lseek_func = zlib_lseek;
  sesfile->ses_read_func = zlib_read;
  sesfile->ses_wrt_func = zlib_write;
  sesfile->ses_close_func = zlib_close;

  sesfile->ses_fd_fill = sesfile->ses_fd_fill_chars = INT64_MAX;
  sesfile->ses_file_ctx = gzdopen (fd, "r");
  sesfile->ses_fd_is_stream = 1;

  dk_free_box (fname_cvt);
  return (caddr_t) ses;
signal_error:
  /* cleanup */
  dk_free_box (fname_cvt);
  dk_free_box ((caddr_t) ses);
  sqlr_resignal (err);
  return NULL;
}


#if defined(__APPLE__) || defined(__FreeBSD__)
#define fseeko64 fseeko
#define ftello64 ftello
#define fopen64  fopen
#endif

#include "zlib/contrib/minizip/unzip.h"
#include "zlib/contrib/minizip/ioapi.h"
#include "zlib/contrib/minizip/ioapi.c"
#include "zlib/contrib/minizip/unzip.c"

static caddr_t
bif_unzip_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "unzip_file";
  caddr_t fname = bif_string_arg (qst, args, 0, szMe);
  caddr_t zname = bif_string_arg (qst, args, 1, szMe);
  caddr_t fname_cvt;
  char buffer [0x8000];
  caddr_t err = NULL;
  unzFile uf = NULL;
  dk_session_t * ses = NULL;
  int rc = 0;

  sec_check_dba ((query_instance_t *) qst, szMe);

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, &err, 1);
  if (NULL != err)
    {
      dk_free_box (fname_cvt);
      sqlr_resignal (err);
    }
  uf = unzOpen (fname);
  if (unzLocateFile (uf, zname, 0) != UNZ_OK)
    {
      *err_ret = srv_make_new_error ("37000", "ZIP01", "Can not locate the file in archive");
      goto err_end;
    }

  rc = unzOpenCurrentFilePassword (uf, NULL /* password */);
  if (rc != UNZ_OK)
    {
      *err_ret = srv_make_new_error ("37000", "ZIP02", "Can not open file from archive");
      goto err_end;
    }

  ses = strses_allocate ();
  strses_enable_paging (ses, http_ses_size);

  do
    {
      rc = unzReadCurrentFile (uf, buffer, sizeof (buffer));
      if (rc < 0)
	break;
      if (rc > 0)
	{
	  session_buffered_write (ses, buffer, rc);
	}
    }
  while (rc > 0);

err_end:
  unzClose (uf);
  dk_free_box (fname_cvt);
  return (caddr_t) ses;
}


/**
   an entry in result consist of:
   1. file name incl. path
   2. uncompressed size
   3. compressed size
   4. original file date
 */
static caddr_t
bif_unzip_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "unzip_list";
  caddr_t fname = bif_string_arg (qst, args, 0, szMe);
  unzFile uf;
  uint32 i;
  unz_global_info gi;
  caddr_t fname_cvt;
  caddr_t err = NULL;
  int rc = 0;
  dk_set_t set = NULL;

  sec_check_dba ((query_instance_t *) qst, szMe);

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, &err, 1);
  if (NULL != err)
    {
      dk_free_box (fname_cvt);
      sqlr_resignal (err);
    }
  uf = unzOpen (fname);
  if (!uf)
    {
      *err_ret = srv_make_new_error ("37000", "ZIP03", "Can not open archive");
      goto err_end;
    }
  rc = unzGetGlobalInfo (uf, &gi);
  if (rc != UNZ_OK)
    {
      *err_ret = srv_make_new_error ("37000", "ZIP04", "error %d with zipfile in unzGetGlobalInfo", rc);
      goto err_end;
    }
  for (i = 0; i < gi.number_entry; i++)
    {
      char filename_inzip[PATH_MAX + 1];
      unz_file_info file_info;
      TIMESTAMP_STRUCT ts;
      caddr_t dt;

      rc = unzGetCurrentFileInfo (uf, &file_info, filename_inzip, sizeof (filename_inzip), NULL, 0, NULL, 0);
      if (rc != UNZ_OK)
	{
	  *err_ret = srv_make_new_error ("37000", "ZIP05", "error %d with zipfile in unzGetCurrentFileInfo", rc);
	  break;
	}
      /* convert tmu_date to DV_DATETIME */
      dt = dk_alloc_box (DT_LENGTH, DV_DATETIME);
      ts.year = file_info.tmu_date.tm_year;
      ts.month = file_info.tmu_date.tm_mon;
      ts.day = file_info.tmu_date.tm_mday;
      ts.hour = file_info.tmu_date.tm_hour;
      ts.minute = file_info.tmu_date.tm_min;
      ts.second	= file_info.tmu_date.tm_sec;
      ts.fraction = 0;
      timestamp_struct_to_dt (&ts, dt);
      dk_set_push (&set, list (4, box_dv_short_string (filename_inzip),
	    box_num (file_info.uncompressed_size), box_num (file_info.compressed_size), dt));
      if ((i+1) < gi.number_entry)
	{
	  rc = unzGoToNextFile (uf);
	  if (rc != UNZ_OK)
	    {
	      *err_ret = srv_make_new_error ("37000", "ZIP06", "error %d with zipfile in unzGoToNextFile", rc);
	      break;
	    }
	}
    }

err_end:
  unzClose (uf);
  dk_free_box (fname_cvt);
  return (caddr_t) list_to_array (dk_set_nreverse (set));
}

/* tiny CSV parser */
#define CSV_DELIM 		','
#define CSV_QUOTE		'\"'

#define CSV_ROW_NOT_STARTED 	0
#define CSV_FIELD_NOT_STARTED	1
#define CSV_FIELD_STARTED	2
#define CSV_FIELD_MAY_END	3

#define CSV_FIELD(set,ses) \
    do \
	{ \
	  dk_set_push (&set, csv_field (ses, mode)); \
	  strses_flush (ses); \
	  quoted = 0; \
	  state = CSV_FIELD_NOT_STARTED; \
	} \
    while (0)

#define CSV_CHAR(c,ses) \
    do \
	{ \
	  char * tail = eh_encode_char__UTF8 (c, utf8char, utf8char + sizeof (utf8char)); \
	  session_buffered_write (ses, utf8char, tail - utf8char); \
	} \
    while (0)

/* CSV errors */
#define CSV_OK 		0
#define CSV_ERR_QUOTE 	1
#define CSV_ERR_ESC	2
#define CSV_ERR_UNK 	3
#define CSV_ERR_END 	4

/* CSV mode */
#define CSV_STRICT	1
#define CSV_LAX		2

static caddr_t
csv_field (dk_session_t * ses, int mode)
{
  caddr_t regex, ret = NULL, str = strses_string (ses);
  if (mode == CSV_LAX && !strcmp (str, "NULL"))
    {
      ret = NEW_DB_NULL;
    }
  else if (NULL != (regex = regexp_match_01 ("^[\\+\\-]?[0-9]+\\.[0-9]*$", str, 0)))
    {
      float d = 0;
      sscanf (str, "%f", &d);
      ret = box_float (d);
      dk_free_box (str);
      dk_free_box (regex);
    }
  else if (NULL != (regex = regexp_match_01 ("^[\\+\\-]?[0-9]+$", str, 0)))
    {
      ret = box_num (atol (str));
      dk_free_box (str);
      dk_free_box (regex);
    }
  else
    {
      if (0 != str[0])
      ret = str;
      else
	{
	  dk_free_box (str);
	  ret = NEW_DB_NULL;
	}
    }
  return ret;
}

static unichar
get_uchar_from_session (dk_session_t * in, encoding_handler_t * eh)
{
  unichar c = UNICHAR_EOD;
  char buf [MAX_ENCODED_CHAR];
  int readed = 0;
  do
    {
      const char * ptr = &(buf[0]);
      if ((readed + eh->eh_minsize) > MAX_ENCODED_CHAR)
	return UNICHAR_BAD_ENCODING;
      readed += session_buffered_read (in, buf + readed, eh->eh_minsize);
      c = eh->eh_decode_char (&ptr, buf + readed);
    }
  while (c == UNICHAR_NO_DATA);
  return c;
}

caddr_t
bif_get_csv_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *in = (dk_session_t *) bif_strses_arg (qst, args, 0, "get_csv_row");
  dk_set_t row = NULL;
  dk_session_t *fl;
  caddr_t res = NULL;
  int quoted = 0, error = CSV_OK, mode = CSV_STRICT, signal_error = 0;
  unsigned char state = CSV_ROW_NOT_STARTED, delim = CSV_DELIM, quote = CSV_QUOTE;
  unichar c;
  char utf8char[MAX_UTF8_CHAR];
  encoding_handler_t *eh = &eh__ISO8859_1;
  if (BOX_ELEMENTS (args) > 1)
    {
      caddr_t ch = bif_string_or_null_arg (qst, args, 1, "get_csv_row");
      delim = ch && ch[0] ? ch[0] : CSV_DELIM;
    }
  if (BOX_ELEMENTS (args) > 2)
    {
      caddr_t ch = bif_string_or_null_arg (qst, args, 2, "get_csv_row");
      quote = ch && ch[0] ? ch[0] : CSV_QUOTE;
    }
  if (BOX_ELEMENTS (args) > 3)
    {
      caddr_t enc = bif_string_or_null_arg (qst, args, 3, "get_csv_row");
      if (enc && enc[0])
	eh = eh_get_handler (enc);
      if (NULL == eh)
	sqlr_new_error ("42000", "CSV01", "Invalid encoding name '%s' is specified", enc);
    }
  if (BOX_ELEMENTS (args) > 4)
    {
      int is_null_f = 0;
      long f = bif_long_or_null_arg (qst, args, 4, "get_csv_row", &is_null_f);
      signal_error = f & 0x04;
      f &= 0x03;
      if (!is_null_f && f != CSV_LAX && f != CSV_STRICT)
	sqlr_new_error ("22023", "CSV03", "CSV parsing mode flag must be strict:1 or relaxing:2");
      mode = f;
    }
  fl = strses_allocate ();
  CATCH_READ_FAIL (in)
  {
    while (CSV_OK == error)
      {
	c = get_uchar_from_session (in, eh);
	if (UNICHAR_BAD_ENCODING == c)
	  {
	    *err_ret = srv_make_new_error ("42000", "CSV02", "Invalid character encoding");
	    error = CSV_ERR_UNK;
	    goto end;
	  }
	switch (state)
	  {
	  case CSV_ROW_NOT_STARTED:
	  case CSV_FIELD_NOT_STARTED:
	    {
	      if (delim != c && (c == 0x20 || c == 0x09 || c == 0xfeff))	/* space or BOM at the start */
		continue;
	      else if (c == 0x0d || c == 0x0a)
		{
		  if (state == CSV_ROW_NOT_STARTED)	/* skip empty lines */
		    continue;
		  else
		    {
		      CSV_FIELD (row, fl);
		      goto end;	/* row end */
		    }
		}
	      else if (c == delim)
		{
		  CSV_FIELD (row, fl);
		}
	      else if (c == quote)
		{
		  state = CSV_FIELD_STARTED;
		  quoted = 1;
		}
	      else
		{
		  CSV_CHAR (c, fl);
		  state = CSV_FIELD_STARTED;
		  quoted = 0;
		}
	    }
	    break;
	  case CSV_FIELD_STARTED:
	    {
	      if (c == quote)
		{
		  if (quoted)
		    {
		      CSV_CHAR (c, fl);
		      state = CSV_FIELD_MAY_END;
		    }
		  else
		    {
		      if (CSV_STRICT == mode)
			{
			  error = CSV_ERR_ESC;
			  break;
			}
		      CSV_CHAR (c, fl);
		    }
		}
	      else if (c == delim)
		{
		  if (quoted)
		    CSV_CHAR (c, fl);
		  else
		    CSV_FIELD (row, fl);
		}
	      else if (c == 0x0d || c == 0x0a)
		{
		  if (quoted)
		    CSV_CHAR (c, fl);
		  else
		    {
		      CSV_FIELD (row, fl);
		      goto end;	/* row end */
		    }
		}
	      else
		{
		  CSV_CHAR (c, fl);
		}
	    }
	    break;
	  case CSV_FIELD_MAY_END:
	    {
	      if (c == quote)
		{
		  /* skip, double quote */
		  state = CSV_FIELD_STARTED;
		}
	      else if (c == delim)
		{
		  fl->dks_out_fill--;
		  CSV_FIELD (row, fl);
		}
	      else if (c == 0x0d || c == 0x0a)
		{
		  fl->dks_out_fill--;
		  CSV_FIELD (row, fl);
		  goto end;	/* row end */
		}
	      else
		{
		  /* char after closing quote */
		  if (CSV_STRICT == mode)
		    {
		      error = CSV_ERR_ESC;
		      break;
		    }
		  CSV_CHAR (c, fl);
		  quoted = 0;
		}
	    }
	    break;
	  default:		/* an error */
	    error = CSV_ERR_UNK;
	    break;
	  }
      }
  }
  FAILED
  {
    if (CSV_ROW_NOT_STARTED == state)	/* when no one char can be read */
      error = CSV_ERR_END;
  }
  END_READ_FAIL (in);
  if (state == CSV_FIELD_STARTED)	/* case when no cr/lf at the end of file */
    {
      CSV_FIELD (row, fl);
    }
  else if (state == CSV_FIELD_MAY_END)
    {
      fl->dks_out_fill--;
      CSV_FIELD (row, fl);
    }
end:
  if (CSV_OK == error)
    res = list_to_array (dk_set_nreverse (row));
  else
    {
      dk_free_tree (list_to_array (dk_set_nreverse (row)));
      if (signal_error)
	*err_ret = srv_make_new_error ("37000", "CSV04", "Error parsing CSV row, error code: %d", error);
    }
  dk_free_box (fl);
  return res;
}

caddr_t
bif_get_plaintext_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * ses = (dk_session_t *) bif_strses_arg (qst, args, 0, "get_plaintext_row");
  char buf_on_stack[4096];
  char *buf = buf_on_stack;
  int buf_size = sizeof (buf_on_stack);
  char *buf_end = buf + buf_size;
  char *buf_tail = buf;
  char *read_begin, *eol = NULL;
  caddr_t res = NULL;
  int buf_is_allocated = 0;
  int buf_add_len, new_buf_size;
  char *new_buf;
  char c;
  CATCH_READ_FAIL (ses)
    {
/* First, full scan of buffered in hope that the whole line is in session buffer already */
      read_begin = ses->dks_in_buffer + ses->dks_in_read;
      eol = (char *)memchr (read_begin, '\n', ses->dks_in_fill - ses->dks_in_read);
      if (NULL != eol)
        {
          res = box_dv_short_nchars (read_begin, eol - read_begin);
          ses->dks_in_read = eol + 1 - ses->dks_in_buffer;
          goto res_done; /* see below */
        }
/* Now we know that the '\n' is not in buffer so an extra copying is unavoidable */
  buf_add_len = ses->dks_in_fill - ses->dks_in_read;
add_portion_to_buf:
  if (buf_tail + buf_add_len + 1 > buf_end)
    {
      new_buf_size = (buf_end + buf_add_len + 1 - buf) * 2;
      new_buf = (char *)dk_alloc (new_buf_size);
      memcpy (new_buf, buf, buf_tail - buf);
      buf_end = new_buf + new_buf_size;
      buf_tail = new_buf + (buf_tail - buf);
      if (buf_is_allocated)
        dk_free (buf, buf_size);
      buf = new_buf;
      buf_size = new_buf_size;
      buf_is_allocated = 1;
    }
  memcpy (buf_tail, ses->dks_in_buffer + ses->dks_in_read, buf_add_len);
  buf_tail += buf_add_len;
  ses->dks_in_read += buf_add_len;
  if (NULL != eol)
    {
      res = box_dv_short_nchars (buf, (buf_tail - 1) - buf); /* -1 because eol is not included into the result */
      goto res_done; /* see below */
    }
  session_buffered_read (ses, &c, 1);
  if ('\n' == c)
    {
      res = box_dv_short_nchars (buf, buf_tail - buf); /* eol is not in the buffer */
      goto res_done; /* see below */
    }
  (buf_tail++)[0] = c;
  read_begin = ses->dks_in_buffer + ses->dks_in_read;
  eol = (char *)memchr (read_begin, '\n', ses->dks_in_fill - ses->dks_in_read);
  if (NULL != eol)
    {
      buf_add_len = (eol + 1) - read_begin;
      goto add_portion_to_buf; /* see above */
    }
  buf_add_len = ses->dks_in_fill - ses->dks_in_read;
  goto add_portion_to_buf; /* see above */
res_done: ;
    }
  FAILED
    {
    }
  END_READ_FAIL (ses);
  if (buf_is_allocated)
    dk_free (buf, buf_size);
  if (NULL == res)
    return NEW_DB_NULL;
  return res;
}

void
bif_file_init (void)
{
  run_executable_mtx = mutex_allocate ();
  bif_define ("string_to_file", bif_string_to_file);
  bif_define_typed ("server_root", bif_server_root, &bt_varchar);
  bif_define_typed ("file_to_string", bif_file_to_string, &bt_varchar);
  bif_define_typed ("file_to_string_output", bif_file_to_string_session, &bt_any);
  bif_define_typed ("file_to_string_output_utf8", bif_file_to_string_session_utf8, &bt_any);
  bif_define_typed ("file_append_to_string_output", bif_file_append_to_string_session, &bt_integer);
  bif_define_typed ("file_append_to_string_output_utf8", bif_file_append_to_string_session_utf8, &bt_integer);
  bif_define_typed ("virtuoso_ini_path", bif_virtuoso_ini_path, &bt_varchar);
  bif_define_typed ("virtuoso_ini_item_value", bif_virtuoso_ini_item_value, &bt_varchar);
  bif_define_typed ("cfg_section_count", bif_cfg_section_count, &bt_integer);
  bif_define_typed ("cfg_item_count", bif_cfg_item_count, &bt_integer);
  bif_define_typed ("cfg_section_name", bif_cfg_section_name, &bt_varchar);
  bif_define_typed ("cfg_item_name", bif_cfg_item_name, &bt_varchar);
  bif_define_typed ("cfg_item_value", bif_cfg_item_value, &bt_varchar);
  bif_define ("cfg_write", bif_cfg_write);
  bif_define_typed ("adler32", bif_adler32, &bt_integer);
  bif_define ("tridgell32", bif_tridgell32);
  bif_define_typed ("mdigest5", bif_mdigest5, &bt_varchar);
  bif_define_typed ("md5", bif_md5, &bt_varchar);
  bif_define_typed ("md5_init", bif_md5_init, &bt_varchar);
  bif_define_typed ("md5_update", bif_md5_update, &bt_varchar);
  bif_define_typed ("md5_final", bif_md5_final, &bt_varchar);
  bif_define_typed ("__vector_sort", bif_vector_sort, &bt_any);
  bif_define ("uuid", bif_uuid);
  bif_define ("rdf_struuid_impl", bif_uuid);
  bif_define ("dime_compose", bif_dime_compose);
  bif_define ("dime_tree", bif_dime_tree);
  bif_define_typed ("file_stat", bif_file_stat, &bt_any);
  if (do_os_calls)
    bif_define_typed ("system", bif_system, &bt_integer);
  bif_define_typed ("run_executable", bif_run_executable, &bt_integer);
  bif_define_typed ("mime_tree", bif_mime_tree, &bt_any);
  bif_define_typed ("mime_header", bif_mime_header, &bt_any);
  bif_define_typed ("mime_tree_ses", bif_mime_tree_ses, &bt_any);
  bif_define_typed ("gz_compress", bif_gz_compress, &bt_varchar);
  bif_define_typed ("string_output_gz_compress",
      bif_string_output_gz_compress, &bt_integer);
  bif_define ("gz_uncompress", bif_gz_uncompress);
  bif_define ("gzip_uncompress", bif_gzip_uncompress);
  bif_define_typed ("gz_compress_file", bif_gz_compress_file, &bt_integer);
  bif_define_typed ("gz_uncompress_file", bif_gz_uncompress_file, &bt_integer);
  bif_define ("unzip_file", bif_unzip_file);
  bif_define ("unzip_list", bif_unzip_list);
  bif_define_typed ("sys_unlink", bif_sys_unlink, &bt_integer);
  bif_define_typed ("sys_mkdir", bif_sys_mkdir, &bt_integer);
  bif_define_typed ("sys_mkpath", bif_sys_mkpath, &bt_integer);
  bif_define_typed ("mail_header", bif_get_mailmsg_hf, &bt_varchar);
  bif_define_typed ("sys_dirlist", bif_sys_dirlist, &bt_any);
  bif_define_typed ("file_delete", bif_file_delete, &bt_any);
  bif_define_typed ("tmp_file_name", bif_tmp_file, &bt_varchar);
  bif_define ("http_mime_type_add", bif_http_mime_type_add);
  bif_define_typed ("http_mime_type", bif_http_mime_type, &bt_varchar);
  bif_define_typed ("delay", bif_sleep, &bt_integer);
  bif_set_uses_index (bif_sleep); /* is io sect, means can't hold a page wired */
  bif_define_typed ("trace_on", bif_trace_on, &bt_any);
  bif_define_typed ("trace_status", bif_trace_status, &bt_any);
  bif_define_typed ("trace_off", bif_trace_off, &bt_any);
  bif_define ("log_message", bif_log_message);
  bif_define_typed ("sys_dir_is_allowed", bif_sys_dir_is_allowed,
      &bt_integer);
  /* aliases of sys_... bifs */
  bif_define_typed ("file_unlink", bif_sys_unlink, &bt_integer);
  bif_define_typed ("file_mkdir", bif_sys_mkdir, &bt_integer);
  bif_define_typed ("file_mkpath", bif_sys_mkpath, &bt_integer);
  bif_define_typed ("file_dirlist", bif_sys_dirlist, &bt_any);
  bif_define_typed ("file_rl", bif_file_rl, &bt_any);
  bif_define_typed ("file_rlo", bif_file_rlo, &bt_any);
  bif_define_typed ("file_rlc", bif_file_rlc, &bt_any);
  bif_define_typed ("file_open", bif_file_open, &bt_any);
  bif_define_typed ("gz_file_open", bif_gz_file_open, &bt_any);
  bif_define_typed ("get_csv_row", bif_get_csv_row, &bt_any);
  bif_define_typed ("get_plaintext_row", bif_get_plaintext_row, &bt_any);
  bif_define_typed ("getenv", bif_getenv, &bt_varchar);
#ifdef HAVE_BIF_GPF
  bif_define ("__gpf", bif_gpf);
#endif
  init_file_acl ();
#ifdef WIN32
  win32_system_init ();
#if 0
  bif_define ("malloc_test", bif_malloc_test);
  bif_define ("heap_compact", bif_heap_compact);
#endif
#endif
#if defined (__APPLE__) && defined(SPOTLIGHT)
  bif_define_typed ("spotlight_metadata", bif_spotlight_metadata, &bt_any);
  bif_define_typed ("spotlight_status", bif_spotlight_status, &bt_any);
  init_file_acl_set ("/usr/bin/mdimport", &dba_execs_set);
#endif
  set_ses_tmp_dir ();

  cfg_init (&_bif_pconfig, f_config_file);

  dk_mem_hooks(DV_FD, box_non_copiable, (box_destr_f) filep_destroy, 0);
}
