/*
 *  http.c
 *
 *  $Id$
 *
 *  HTTP access to Virtuoso
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
 */

/* IvAn/VC6port/000725 Added to bypass compilation error */
#include <stddef.h>

#include "Dk.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "virtpwd.h"

#include "http.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "sqlbif.h"
#include "xml.h"
#include "libutil.h"
#include "security.h"
#include "statuslog.h"
#include "wifn.h"
#include "sqltype.h"
#include "datesupp.h"

#ifdef BIF_XML
#include "sqlpar.h"
#include "xmltree.h"
#include "soap.h"
#endif

#include "recovery.h"
#include "sqlver.h"
#include "xmlenc.h"

#ifdef WIN32
#include <windows.h>
#ifdef _MSC_VER
#define HAVE_DIRECT_H
#endif
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define PATH_MAX	 MAX_PATH
#else
#include <dirent.h>
#endif
#ifdef _SSL
#include "util/sslengine.h"
#endif

#define XML_VERSION		"1.0"

#define DKS_CLEAR_DEFAULT_READ_READY_ACTION(ses) SESSION_SCH_DATA (ses)->sio_default_read_ready_action = NULL

#ifndef WIN32
#define closesocket close
#endif

char *http_methods[] = { "NONE", "GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", /* HTTP/1.1 */
  			 "PROPFIND", "PROPPATCH", "COPY", "MOVE", "LOCK", "UNLOCK", "MKCOL",  /* WebDAV */
			 "MGET", "MPUT", "MDELETE", 	/* URIQA */
			 "REPORT", /* CalDAV */
			 "TRACE", NULL };
resource_t *ws_dbcs;
basket_t ws_queue;
dk_mutex_t * ws_queue_mtx;
dk_mutex_t * ws_http_log_mtx = NULL;
dk_mutex_t * ftp_log_mtx = NULL;
dk_mutex_t * http_acl_mtx = NULL;
int http_n_keep_alives;
caddr_t ws_default_charset_name = NULL;
wcharset_t * ws_default_charset = NULL;
caddr_t *localhost_names;
caddr_t *local_interfaces;
caddr_t dns_host_name;
caddr_t temp_aspx_dir;
char *www_maintenance_page = NULL;
char *http_proxy_address = NULL;

static id_hash_t * http_acls = NULL; /* ACL lists */
static id_hash_t * http_url_cache = NULL; /* WS cached URLs */

long http_ses_trap = 0;
int www_maintenance = 0;

#define MAINTENANCE (NULL != www_maintenance_page && (wi_inst.wi_is_checkpoint_pending || www_maintenance || cpt_is_global_lock (NULL)))

size_t dk_alloc_cache_total (void * cache);
void thr_alloc_cache_clear (thread_t * thr);

caddr_t
temp_aspx_dir_get (void)
{
  /* for outside executables */
  return temp_aspx_dir;
}

void
session_buffered_read_n (dk_session_t * ses, char *buf, int max, int *inx)
{
  while (1)
    {
      char c = session_buffered_read_char (ses);
      buf[*inx] = c;
      *inx = *inx + 1;
      if (*inx > max - 1)
	return;
    }
}


int
dks_read_line (dk_session_t * ses, char *buf, int max)
{
  int inx = 0;
  buf[0] = 0;

  for (;;)
    {
      char c = session_buffered_read_char (ses);
      if (inx < max - 1)
	buf[inx++] = c;
      if (c == 10)
	{
	  buf[inx] = 0;
	  return inx;
	}
    }
}

static int
ws_read_line (ws_connection_t *ws, char *buf, int max)
{
  if(http_ses_trap) {
    int res = dks_read_line (ws->ws_session, buf, max);
    if (ws->ws_ses_trap)
      session_buffered_write (ws->ws_req_log, buf, res);
    return res;
  }
  else {
    return dks_read_line (ws->ws_session, buf, max);
  }
}

int
char_hex_digit (char c)
{
  if (c >= '0' && c <= '9')
    return (c - '0');
  if (c >= 'a' && c <= 'f')
    return (10 + c - 'a');
  if (c >= 'A' && c <= 'F')
    return (10 + c - 'A');
  return 0;
}

static caddr_t
get_qualified_host_name (void)
{
  int inx;
  caddr_t qualified = NULL;
  DO_BOX (caddr_t, name, inx, localhost_names)
    {
      if (!qualified)
	qualified = name;
      if (NULL != strchr (name, '.'))
	{
	  qualified = name;
          break;
	}
    }
  END_DO_BOX;
  return qualified ? box_copy (qualified) : box_dv_short_string ("localhost");
}

char * ws_url_escapes = ";/?:@&=+ \"#%<>";

void ws_proc_error (ws_connection_t * ws, caddr_t err);
#ifdef _SSL
int ssl_port = 0;
void * tcpses_get_sslctx (session_t * ses);
void tcpses_set_sslctx (session_t * ses, void * ssl_ctx);
#endif

#ifdef _IMSG
int pop3_port = 0;
int nntp_port = 0;
int ftp_port = 0;
int ftp_server_timeout = 0;
#endif

#ifdef __MINGW32__
#define PATH_MAX MAX_PATH
#endif

FILE *ftp_log = NULL;
char ftp_log_name_str[PATH_MAX+1] = "";
char * ftp_log_name = ftp_log_name_str;
FILE *http_log = NULL;
char http_log_name_str[PATH_MAX+1] = "";
char * http_log_name = http_log_name_str;
struct tm *http_log_last_opened = NULL;

int enable_gzip = 0;
int http_ses_size = 0; /* init on viconfig */

#ifdef VIRTUAL_DIR
void ws_set_phy_path (ws_connection_t * ws, int dir, char * vsp_path);
#define IS_DAV_DOMAIN(ws, path1) (ws && ws->ws_map && ws->ws_map->hm_is_dav)
void pop_user_id (client_connection_t * cli);
caddr_t ws_get_packed_hf (ws_connection_t * ws, const char * fld, char * deflt);
#else
#define IS_DAV_DOMAIN(ws, path1) (dav_root != NULL && (!strcmp (path1, dav_root) || !strcmp ("/", dav_root)))
#define ws_get_packed_hf(ws,path1,deflt) NULL
#endif

caddr_t
ws_gethostbyaddr (const char * ip)
{
  struct hostent *host = NULL;
  unsigned long int addr;
#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS) || defined (HPUX_10))
  char buff [4096];
  int herrnop;
  struct hostent ht;
# if defined (HPUX_10)
  struct hostent_data hted;
# endif
#endif

  if ((int)(addr = inet_addr (ip)) == -1)
    return box_dv_short_string (ip);


#if defined (_REENTRANT) && defined (linux)
  gethostbyaddr_r ((char *)&addr, sizeof (addr), AF_INET, &ht, buff, sizeof (buff), &host, &herrnop);
#elif defined (_REENTRANT) && defined (SOLARIS)
  host = gethostbyaddr_r ((char *)&addr, sizeof (addr), AF_INET, &ht, buff, sizeof (buff), &herrnop);
#elif defined (_REENTRANT) && defined (HPUX_10)
  /* in HP-UX 10 these functions are MT-safe */
  hted.current = NULL;
  if (-1 != gethostbyaddr_r ((char *)&addr, sizeof (addr), AF_INET, &ht, &hted))
    host = &ht;
#else
  /* gethostbyname and gethostbyaddr is a threadsafe on AIX4.3 HP-UX WindowsNT */
  host = gethostbyaddr ((char *)&addr, sizeof (addr), AF_INET);
#endif

  if (!host)
    {
#if 0
#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS))
      int status = herrnop;
#else
      int status = h_errno;
#endif
#endif
      return box_dv_short_string (ip);
    }
  return box_dv_short_string (host->h_name);
}

#define ACL_HIT_RESTORE(hit) \
      if (hit) \
	{ \
	  hit->ah_count--; \
	}

#define ACL_CHECK_MPS	1
#define ACL_CHECK_HITS	2

static int http_acl_check_rate (ws_acl_t * elm, caddr_t name, int check_rate, int rw_flag, acl_hit_t ** hit_ret)
{
  int res;
  id_hash_t *loc_hash;

  if (!elm->ha_rate || !check_rate)
    return elm->ha_flag;
  else if (check_rate == ACL_CHECK_HITS)
    {
      acl_hit_t * hit, **place;
      int64 now;
      timeout_t tv;

      res = elm->ha_flag;
      get_real_time (&tv);
      now = ((int64)tv.to_sec * 1000000) + (int64) tv.to_usec;
      /*now = get_msec_real_time ();*/
      mutex_enter (http_acl_mtx);
      loc_hash = elm->ha_hits;
#ifdef DEBUG
      if (!loc_hash)
	GPF_T;
#endif
      place = (acl_hit_t **) id_hash_get (loc_hash, (caddr_t)&name);
      if (place)
	{
	  float rate;
	  float elapsed;

	  hit = *place;

	  elapsed = (float) (now - hit->ah_initial) / 1000000;
	  if (elapsed < 1) elapsed = 0.5;
	  rate = (float)((hit->ah_count + 1) / elapsed);
	  hit->ah_avg = rate;

	  if ((elapsed > 1) && rate > elm->ha_rate)
	    res = 1; /* deny */
	  else if (elapsed > 86400) /* reset stats once per 24h, but only when not denied */
	    memset (hit, 0, sizeof (acl_hit_t));
#ifdef DEBUG
	  fprintf (stderr, "http acl rate-limit elapsed: %f, count: %ld, rate: %f, avg: %f, rc=%d\n", elapsed, hit->ah_count, rate, hit->ah_avg, res);
#endif
	}
      else
	{
	  caddr_t new_name = box_copy (name);
	  hit = (acl_hit_t *) dk_alloc (sizeof (acl_hit_t));
	  memset (hit, 0, sizeof (acl_hit_t));
	  id_hash_set (loc_hash, (caddr_t) &new_name, (caddr_t) &hit);
	}
      if (!hit->ah_initial) hit->ah_initial = now;
      hit->ah_count ++;
      if (hit_ret)
	*hit_ret = hit;
      mutex_leave (http_acl_mtx);
    }
  else /* ACL_CHECK_MPS */
    {
      struct tm *tm;
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
      struct tm tm1;
#endif
      int32 now, * last;
      time_t now_t;
      long rate;

      time (&now_t);
      res = elm->ha_flag;
      rate = (long) (1 / elm->ha_rate);

      loc_hash = rw_flag ? elm->ha_cli_ip_r : elm->ha_cli_ip_w;

      if (!loc_hash)
	loc_hash = id_str_hash_create (101);

#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
      tm = localtime_r (&now_t, &tm1);
#else
      tm = localtime (&now_t);
#endif

      last = (int32 *) id_hash_get (loc_hash, (caddr_t)&name);
      now = tm->tm_hour * 60 * 60 + tm->tm_min * 60 + tm->tm_sec;

      if (last && (now-*last) > rate)
	res = 1;
      else
	res = -2; /* hit rate limit is reached */

      if (!last)
	{
	  caddr_t new_name = box_copy (name);
	  last = (int32 *) dk_alloc (sizeof (int32));
	  *last = now;
	  id_hash_set (loc_hash, (caddr_t) &new_name, (caddr_t) last);
	  res = 1;
	}
      else
	*last = now;
      if (rw_flag)
	elm->ha_cli_ip_r = loc_hash;
      else
	elm->ha_cli_ip_w = loc_hash;
    }
   return res;
}

static int
http_acl_match (caddr_t *alist, caddr_t name, ccaddr_t dst, int obj_id, int rw_flag, int check_rate, acl_hit_t ** hit, ws_connection_t * ws)
{
  int inx;
  DO_BOX (ws_acl_t *, elm, inx, alist)
    {
      if (name && DVC_MATCH == cmp_like (name, elm->ha_mask, NULL, 0, LIKE_ARG_CHAR, LIKE_ARG_CHAR))
	{
	  if (ws)
	    ws->ws_body_limit = elm->ha_limit;
	  if (dst == NULL && obj_id < 0 && rw_flag < 0)
	    return http_acl_check_rate (elm, name, check_rate, rw_flag, hit);
	  else if (dst != NULL && DVC_MATCH == cmp_like (dst, elm->ha_dest ? elm->ha_dest : "*", NULL, 0, LIKE_ARG_CHAR, LIKE_ARG_CHAR))
	    return http_acl_check_rate (elm, name, check_rate, rw_flag, hit);
	  else if (dst == NULL && elm->ha_obj == obj_id && rw_flag == elm->ha_rw)
	    return http_acl_check_rate (elm, name, check_rate, rw_flag, hit);
	}
    }
  END_DO_BOX;
  return -1; /* not found */
}

static int
ws_check_acl (ws_connection_t * ws, acl_hit_t ** hit)
{
  static char * szHttpAclName = "HTTP";
  caddr_t *list, **plist;
  int rc = 1; /* all enabled by default */

  plist = (caddr_t **) id_hash_get (http_acls, (caddr_t) &szHttpAclName);
  list = plist ? *plist : NULL;

  if (list)
    {
      char * vd = ws->ws_req_line ? strchr (ws->ws_req_line, '\x20') : NULL;
      while (vd && isspace (*vd))
	vd++;
      if (http_acl_match (list, ws->ws_client_ip, vd, -1, -1, ACL_CHECK_HITS, hit, ws) > 0) /* 1:deny */
	rc = 0;
    }
  return rc;
}

#define WS_PARAM_PUSH(parts, str) \
   do { \
     if (strses_length (str) < MIME_POST_LIMIT) \
       dk_set_push (parts, strses_string (str)); \
     else \
       { \
	 dk_session_t * par = strses_allocate (); \
	 strses_enable_paging (par, http_ses_size); \
	 strses_write_out (str, par); \
	 dk_set_push (parts, par); \
       } \
   } while (0)

caddr_t *
ws_read_post (dk_session_t * ses, int max,
	      dk_session_t * str, dk_session_t * cont)
{
  dk_set_t parts = NULL;
  char name[300];
  int inx = 0;
  int reading_name = 1;
  int bytes_read = 0;
  unsigned char ch = 0, ch2, ch3;

  strses_flush (str);
  for (;;)
    {
      if (!max || bytes_read < max)
	{
	  ch = session_buffered_read_char (ses);
	  session_buffered_write_char (ch, cont);
	  bytes_read++;
	}
      if (ch == '\n' || ch == '\r' || ch == ' ')
	{
	  if (reading_name)
	    {
	      name[inx] = 0; /*if only name of parameter is supplied */
	      dk_set_push (&parts, box_dv_short_string (name));
	      dk_set_push (&parts, box_dv_short_string(""));
	      inx = 0;
	    }
	  break;
	}
      if (max && bytes_read >= max)
	{
	  if (reading_name && ch == '=' && inx <= sizeof (name) - 1)
	    {
	      name[inx] = 0;
	      reading_name = 0;
	    }
	  else if (reading_name)
	    {
	      inx = 0;
	    }
	  else
	    {
	      session_buffered_write_char ((ch == '+' ? ' ' : ch) , str);
	    }
	  break;
	}
      if (reading_name)
	{
	  if (inx > sizeof (name) - 3)
	    break;
	  if (ch == '=')
	    {
	      name[inx] = 0;
	      reading_name = 0;
	    }
	  else if (ch == '&') /* only name appear */
	    {
	      name[inx] = 0;
	      dk_set_push (&parts, box_dv_short_string (name));
	      dk_set_push (&parts, box_dv_short_string(""));
	      inx = 0;
	    }
	  else if (inx < (sizeof (name) - 1))
	    {
	      if (ch == '%' && (!max || bytes_read + 2 <= max))
		{
		  int code = char_hex_digit(ch2 = session_buffered_read_char (ses)) * 16
		      + char_hex_digit (ch3 = session_buffered_read_char (ses));
		  name[inx++] = (unsigned char) code;
		  bytes_read += 2;
		  session_buffered_write_char (ch2, cont);
		  session_buffered_write_char (ch3, cont);
		}
	      else if (ch == '+')
		name [inx++] = ' ';
	      else
		name[inx++] = ch;
	    }
	}
      else
	{
	  if (ch == '&')
	    {
	      dk_set_push (&parts, box_dv_short_string (name));
	      WS_PARAM_PUSH (&parts, str);
	      strses_flush (str);
	      inx = 0;
	      reading_name = 1;
	    }
	  else if (ch == '%' && (!max || bytes_read + 2 <= max))
	    {
	      int code = char_hex_digit(ch2 = session_buffered_read_char (ses)) * 16
		+ char_hex_digit (ch3 = session_buffered_read_char (ses));
	      bytes_read += 2;
	      if (ch2 != 'u')
		{
		  session_buffered_write_char (code, str);
		  session_buffered_write_char (ch2, cont);
		  session_buffered_write_char (ch3, cont);
		}
	      else /* unicode escape sequence */
		{
		  char uc [5] = {0,0,0,0,0};
		  wchar_t wc;
		  unsigned char mbs[VIRT_MB_CUR_MAX];
		  virt_mbstate_t state;
		  size_t utf8_len;

		  /* check boundary */
		  if (max && bytes_read + 3 > max)
		    break;

		  uc[0] = ch3;
		  session_buffered_read (ses, &uc[1], 3);
		  bytes_read += 3;
		  if (1 == sscanf (uc, "%4X", &wc))
		    {
		      memset (&state, 0, sizeof (virt_mbstate_t));
		      if (-1 != (utf8_len = virt_wcrtomb (mbs, wc, &state)))
			session_buffered_write (str, (char *) mbs, utf8_len);
		    }
		  session_buffered_write_char (ch2, cont);
		  session_buffered_write (cont, (char *) uc, 4);
		}
	      if (max && bytes_read >= max)
		break;
	    }
	  else if (ch == '+')
	    {
	      session_buffered_write_char (' ', str);
	    }
	  else if (ch == '\n' || ch == '\r')
	    {
	      break;
	    }
	  else
	    {
	      session_buffered_write_char (ch, str);
	    }
	}
    }				/* for loop */

  if (inx)
    {
      dk_set_push (&parts, box_dv_short_string (name));
      WS_PARAM_PUSH (&parts, str);
      strses_flush (str);
    }
  else
    {
      if (max && bytes_read < max)
	{
	  char buf [4096];
	  int readed = 0;
	  int to_read_len = sizeof (buf);
	  int to_read = max - bytes_read;
	  do
	    {
	      if (to_read < to_read_len)
		to_read_len = to_read;
	      readed = session_buffered_read (ses, buf, to_read_len);
	      to_read -= readed;
	      if (readed > 0)
		session_buffered_write (cont, buf, readed);
	    }
	  while (to_read > 0);
	}
      dk_set_push (&parts, box_dv_short_string ("content"));
      WS_PARAM_PUSH (&parts, cont);
    }


  return ((caddr_t*) list_to_array (dk_set_nreverse(parts)));
}

static caddr_t *
ws_read_post_1 (ws_connection_t *ws, int max, dk_session_t * str)
{
  dk_session_t * cont = NULL;
  caddr_t * volatile ret = NULL;

  if (!max)
    return ((caddr_t*) list_to_array (NULL));

  cont = strses_allocate ();
  CATCH_READ_FAIL_S (ws->ws_session)
    {
      ret = ws_read_post (ws->ws_session, max, str, cont);
    }
  FAILED
    {
      if (http_ses_trap)
	{
	  if (ws->ws_ses_trap)
	    strses_write_out (cont, ws->ws_req_log);
	}
      dk_free_box ((box_t) cont);
      THROW_READ_FAIL_S (ws->ws_session);
    }
  END_READ_FAIL_S (ws->ws_session);
  if (http_ses_trap)
    {
      if (ws->ws_ses_trap)
	strses_write_out (cont, ws->ws_req_log);
    }
  dk_free_box ((box_t) cont);
  return ret;
}

void
ws_http_body_read (ws_connection_t * ws, dk_session_t **out)
{
  char buff[4096];
  int volatile to_read;
  int volatile to_read_len;
  int volatile readed;
  dk_session_t * volatile ses;

  if (!ws->ws_req_len)
    return;

  to_read = ws->ws_req_len;
  to_read_len = sizeof (buff);
  ses = strses_allocate ();
  strses_enable_paging (ses, http_ses_size);

  CATCH_READ_FAIL_S (ws->ws_session)
    {
      while (to_read > 0)
	{
	  if (to_read < to_read_len)
	    to_read_len = to_read;
	  readed = session_buffered_read (ws->ws_session, buff, to_read_len);

	  to_read -= readed;
	  if (readed > 0)
	    {
	      session_buffered_write (ses, buff, readed);
	      if (http_ses_trap && ws->ws_ses_trap)
		session_buffered_write (ws->ws_req_log, buff, readed);
	    }
	}
    }
  FAILED
    {
      strses_flush (ses);
      dk_free_box ((box_t) ses);
      ses = NULL;
      THROW_READ_FAIL_S (ws->ws_session);
    }
  END_READ_FAIL_S (ws->ws_session);
  ws->ws_req_len = 0;
  *out = ses;
}

caddr_t
box_line (char * line, int len)
{
  caddr_t box = dk_alloc_box (len + 1, DV_SHORT_STRING);
  memcpy (box, line, len);
  box[len] = 0;
  return box;
}

static caddr_t
ws_auth_get (ws_connection_t * ws)
{
  caddr_t auth = NULL;
  caddr_t res, p1;
  size_t len, blen;
  char *p2, *p3 = NULL;

  res = NULL;
  p1 = NULL;
  auth = ws_get_packed_hf (ws, "Authorization:", "");

  if (!auth)
    res = box_string ("- -");
  else if (0 == strncmp (auth, "Digest ", 7))
    {
      p2 = (char *) nc_strstr ((unsigned char *) (auth + 7), (unsigned char *) "username");
      if (p2)
	{
	  p1 = strtok_r (p2, "= \"", &p3);
	  p1 = strtok_r (NULL, "\" ,", &p3);
	  if (p1)
	    {
	      res = dk_alloc_box (strlen(p1) + 7 + 1, DV_SHORT_STRING);
	      snprintf (res, box_length (res), "Digest %s", p1);
	    }
	  else
	    res = box_string ("- -");
	}
    }
  else if (0 == strncmp (auth, "Basic ", 6))
    {
      blen = box_length(auth);
      if (blen > 7)
	{
	  p2 = auth + 6;
	  len = decode_base64(p2, auth + blen);
	  *(p2 + len) = 0;
	  p1 = strstr (p2, ":");
	  if (p1)
	    {
	      *p1 = 0;
	      res = dk_alloc_box ((p1 - p2) + 7, DV_SHORT_STRING);
	      snprintf (res, box_length (res), "Basic %s", p2);
	    }
	  else
	    res = box_string ("- -");
	}
    }

  dk_free_box (auth);

  /*
   * Make sure we return something
   */
  if (!res)
    res = box_string ("- -");

  return res;
}

static int
is_http_handler (char *name)
{
  char * dot = strrchr (name, '.'), szExtBuffer[100], proc_name[120];
  int inx;

  if (dot)
    name = dot + 1;
  for (inx = 0; inx < sizeof (szExtBuffer) - 1 && name[inx]; inx++)
    szExtBuffer[inx] = tolower (name[inx]);
  szExtBuffer[inx] = 0;
  snprintf (proc_name, sizeof (proc_name), "__http_handler_%s", szExtBuffer);
  sqlp_upcase (proc_name);
  if (bif_find (proc_name))
    return 1;

  snprintf (proc_name, sizeof (proc_name), "WS.WS.__http_handler_%s", szExtBuffer);
  if (sch_proc_def (isp_schema (NULL), proc_name))
    return 1;

  return 0;
}

#ifdef WIN32
#define DIR_SLASH	'\\'
#else
#define DIR_SLASH	'/'
#endif

char *
http_log_file_check (struct tm *now)
{
  int d, m, y;
  char *ptmp, *ext, new_name[PATH_MAX+1], tstamp[9], *sla;
  PCONFIG pcfgFile = NULL;

  if (!http_log_name_str[0])
    return NULL;

  if (!http_log_last_opened)
    {
      http_log_last_opened = (struct tm *) dk_alloc (sizeof (struct tm));
      memset (http_log_last_opened, 0, sizeof (struct tm));
      ext = strrchr (http_log_name, '.');
      sla = strrchr (http_log_name, DIR_SLASH);
      if (sla && ext && sla > ext)
	ext = NULL;
      ptmp = ext && ext > http_log_name ? (ext - 1) : http_log_name + strlen(http_log_name) - 1;
      while (ptmp > http_log_name)
	{
	  if (!isdigit (*ptmp))
	    {
	      ptmp++;
	      break;
	    }
	  ptmp--;
	}
      d = 0; m = 0; y = 0;
      sscanf (ptmp, "%02d%02d%04d", &d, &m, &y);
      if (d && m && y)
	{
	  http_log_last_opened->tm_year = y - 1900;
	  http_log_last_opened->tm_mday  = d;
	  http_log_last_opened->tm_mon = m - 1;
	}
    }

  if (http_log_last_opened->tm_mday != now->tm_mday ||
      http_log_last_opened->tm_mon  != now->tm_mon ||
      http_log_last_opened->tm_year != now->tm_year)
    {
      memcpy (http_log_last_opened, now, sizeof (struct tm));
      ext = strrchr (http_log_name, '.');
      sla = strrchr (http_log_name, DIR_SLASH);
      if (sla && ext && sla > ext)
	ext = NULL;
      ptmp = ext && ext > http_log_name ? (ext - 1) : http_log_name + strlen(http_log_name) - 1;
      while (ptmp > http_log_name)
	{
	  if (!isdigit (*ptmp))
	    {
	      ptmp++;
	      break;
	    }
	  ptmp--;
	}
      memset (new_name, 0, sizeof (new_name));
      /* http_log_name is ensured in cfg_setup to do not exceed PATH_MAX - 10 */
      strncpy (new_name, http_log_name, (size_t)(ptmp - http_log_name));
      snprintf (tstamp, sizeof (tstamp), "%02d%02d%02d", http_log_last_opened->tm_mday,
	  http_log_last_opened->tm_mon + 1,
	  http_log_last_opened->tm_year + 1900);
      strcat_ck (new_name, tstamp);
      if (ext)
	strcat_ck (new_name, ext);
      if (cfg_init2 (&pcfgFile, f_config_file, 1))
	goto error_end;
      if (cfg_write (pcfgFile, "HTTPServer", "HTTPLogFile", new_name) == -1 ||
	  cfg_commit (pcfgFile) == -1)
	goto error_end;
      cfg_done (pcfgFile);
      strcpy_ck (http_log_name_str, new_name);
      return http_log_name;
    }
error_end:
  return NULL;
}

static int
log_info_http (ws_connection_t * ws, const char * code, OFF_T len)
{
  char buf[4096];
  struct tm *tm;
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
  struct tm tm1;
#endif
  char * monday [] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  time_t now;
  int month, day, year;
  int http_resp_code = 0;
  caddr_t u_id = NULL;
  caddr_t referer = NULL;
  caddr_t user_agent = NULL;
  char * new_log = NULL;

  if (!http_log || !ws)
    return 0;

  if (code)
    sscanf (code, "%*s %i", &http_resp_code);

  referer = ws_get_packed_hf (ws, "Referer:", "");
  user_agent = ws_get_packed_hf (ws, "User-Agent:", "");

  buf[0] = 0;
  time (&now);
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
  tm = localtime_r (&now, &tm1);
#else
  tm = localtime (&now);
#endif
  month = tm->tm_mon + 1;
  day = tm->tm_mday;
  year = tm->tm_year + 1900;

  u_id = ws_auth_get (ws);

  snprintf (buf, sizeof (buf), "%s %s [%02d/%s/%04d:%02d:%02d:%02d %+05li] \"%.2000s%s\" %d " OFF_T_PRINTF_FMT " \"%.1000s\" \"%.500s\"\n",
      ws->ws_client_ip, u_id, (tm->tm_mday), monday [month - 1], year,
      tm->tm_hour, tm->tm_min, tm->tm_sec, (long) dt_local_tz/36*100,
      (ws->ws_req_line
#ifdef WM_ERROR
       && ws->ws_method != WM_ERROR
#endif
       ? ws->ws_req_line : "GET unspecified"),
      ws->ws_proto, http_resp_code, (OFF_T_PRINTF_DTP) len, referer ? referer : "", user_agent ? user_agent : "");

  dk_free_box (u_id);
  dk_free_box (referer);
  dk_free_box (user_agent);

  mutex_enter (ws_http_log_mtx);
  new_log = http_log_file_check (tm);
  if (new_log)
    {
      fflush (http_log);
      fclose (http_log);
      http_log = fopen (new_log, "a");
      if (!http_log)
	{
	  log_error ("Can't open new HTTP log file (%s)", new_log);
	  mutex_leave (ws_http_log_mtx);
	  return 0;
	}
    }
  fputs (buf, http_log);
  fflush (http_log);
  mutex_leave (ws_http_log_mtx);

  return 0;
}



caddr_t
ws_get_param (ws_connection_t * ws, char * name)
{
  int inx, len;
  if (!ws->ws_params)
    return NULL;
  len = BOX_ELEMENTS (ws->ws_params);
  for (inx = 0; inx < len; inx += 2)
    {
      if (0 == strcmp (ws->ws_params[inx], name))
	return (ws->ws_params[inx + 1]);
    }
  return NULL;
}


void
ws_set_path_string (ws_connection_t * ws, int dir)
{
  caddr_t * arr = ws->ws_path;
  int inx, n = BOX_ELEMENTS (arr);
  caddr_t res;
  int len = 0, fill = 0;
  for (inx = 0; inx < n; inx++)
    {
      /* no special case for http: needed, since no additional char added, just / is after http: */
      len += box_length (arr[inx]);
    }
  if (len > 0)
    res = dk_alloc_box (len + 1 + (dir ? 1 : 0), DV_SHORT_STRING);
  else
    res = box_dv_short_string ("/");
  for (inx = 0; inx < n; inx++)
    {
      int cpy = box_length (arr[inx]) - 1;
#ifdef VIRTUAL_DIR
      if (inx == 0 && 0 == stricmp (arr [inx], "http:"))
	{
	  memcpy (res + fill, arr[inx], cpy);
	  fill += cpy;
	  res[fill++] = '/';
	}
      else
	{
	  res[fill++] = '/';
	  memcpy (res + fill, arr[inx], cpy);
	  fill += cpy;
	}
#else
      res[fill++] = '/';
      memcpy (res + fill, arr[inx], cpy);
      fill += cpy;
#endif
    }
  if (len > 0)
    {
      if (dir)
	res [fill++] = '/';
      res[fill] = 0;
    }
  ws->ws_path_string = res;
}


static caddr_t *
ws_read_multipart_mime_post (ws_connection_t *ws, int *is_stream)
{
  dk_set_t ret_attrs = NULL;
  caddr_t *volatile ret_array = NULL;
  caddr_t volatile msg = NULL;
  caddr_t volatile ptr;
  volatile long msg_len = ws->ws_req_len, offset = 0, body_start_offset, body_end_offset;
  int inx, inx1;
  char szBoundry[1000];
  char szType[1000];
  caddr_t *parsed_msg = NULL;
  caddr_t *attrs = NULL, *parts = NULL;
  caddr_t *part_attrs, *part_body;
  caddr_t attr_prefix = box_dv_short_string ("attr-");

  if (ws->ws_req_len < MIME_POST_LIMIT)
    {
      DO_BOX (caddr_t, line, inx, ws->ws_lines)
	  if (inx)
	    msg_len += box_length (line) - 1;
      END_DO_BOX;

      ptr = msg = dk_alloc_box (msg_len + 3, DV_C_STRING);

      DO_BOX (caddr_t, line, inx, ws->ws_lines)
	  if (inx)
	    {
	      memcpy (ptr, line, box_length (line) - 1);
	      ptr += box_length (line) - 1;
	    }
      END_DO_BOX;

      *ptr++ = '\x0D';
      *ptr++ = '\x0A';

      CATCH_READ_FAIL_S (ws->ws_session)
	{
	  session_buffered_read (ws->ws_session, ptr, ws->ws_req_len);
	  if (http_ses_trap)
	    {
	      if (ws->ws_ses_trap)
		session_buffered_write (ws->ws_req_log, ptr, ws->ws_req_len);
	    }
	}
      FAILED
	{
	  dk_free_box (attr_prefix);
	  dk_free_box (msg);
	  THROW_READ_FAIL_S (ws->ws_session);
	}
      END_READ_FAIL_S (ws->ws_session);

      ptr[ws->ws_req_len] = 0;
      ws->ws_req_len = 0;

      inx = 1;
      *szType = 0;
      *szBoundry = 0;
      offset = get_mime_part (&inx, msg, msg_len, offset, szBoundry, szType, sizeof (szType), &parsed_msg, 0);
      if (offset == -1 || offset > 0)
	goto error;
      attrs = (caddr_t *)parsed_msg[0];
      parts = (caddr_t *)parsed_msg[2];
    }
  else
    {
      strses_flush (ws->ws_strses);
      *is_stream = 1;

      DO_BOX (caddr_t, line, inx, ws->ws_lines)
	{
	  if (inx)
	    {
	      msg_len += box_length (line) - 1;
	      session_buffered_write (ws->ws_strses, line, box_length (line) - 1);
	    }
	}
      END_DO_BOX;
      session_buffered_write (ws->ws_strses, "\x0D\x0A", 2);
      parsed_msg = (caddr_t *) mime_stream_get_part (1, ws->ws_session,
	  ws->ws_req_len, ws->ws_strses, msg_len + 2 - ws->ws_req_len);
      ws->ws_req_len = 0; /* the content have been read */
      if (parsed_msg)
	{
	  attrs = (caddr_t *) parsed_msg[0];
	  parts = (caddr_t *) parsed_msg[2];
	}
      strses_flush (ws->ws_strses);
    }
  DO_BOX (caddr_t *, part, inx, parts)
    {
      caddr_t part_name = NULL;
      char temp_name[150];

      part_attrs = (caddr_t *)part[0];
      part_body = (caddr_t *)part[1];

      for (inx1 = 0; part_attrs && inx1 < (int) BOX_ELEMENTS (part_attrs); inx1 += 2)
	{
	  if (!stricmp ("name", part_attrs[inx1]))
	    part_name = part_attrs[inx1 + 1];
	}
      if (!part_name)
	{
	  snprintf (temp_name, sizeof (temp_name), "mime_part%d", inx + 1);
	  part_name = temp_name;
	}

      if (!part_name || !part_body)
	{
	  dk_free_tree (list_to_array (ret_attrs));
	  ret_attrs = NULL;
	  goto error;
	}

      part_name = box_dv_short_string (part_name);
      dk_set_push (&ret_attrs, part_name);

      if (*is_stream)
	{
	  dk_set_push (&ret_attrs, part_body);
	  part[1] = NULL;
	}
      else
	{
	  body_start_offset = (long) unbox (part_body[0]);
	  body_end_offset = (long) unbox (part_body[1]);

	  dk_set_push (&ret_attrs,
	      box_varchar_string ((db_buf_t) (msg + body_start_offset),
		body_end_offset - body_start_offset,
		DV_SHORT_STRING));
	}

      dk_set_push (&ret_attrs, box_conc (attr_prefix, part_name));
      dk_set_push (&ret_attrs, box_copy_tree ((box_t) part_attrs));
    }
  END_DO_BOX;

  ret_array = (caddr_t *) list_to_array (dk_set_nreverse (ret_attrs));

error:
  dk_free_tree ((box_t) parsed_msg);
  dk_free_box (msg);
  dk_free_box (attr_prefix);
  return (ret_array);
}

void
ws_write_failed (ws_connection_t * ws)
{
  dk_session_t * ses = ws->ws_session;
  mutex_enter (ws_queue_mtx);
  ses->dks_to_close = 1;
  mutex_leave (ws_queue_mtx);
}

/* check request against server capabilities, e.g. expect header */
static int
ws_check_caps (ws_connection_t * ws)
{
  char *expect, *end;
  expect = ws_header_field (ws->ws_lines, "Expect:", NULL);
  if (!expect || !strlen (expect))
    return 1;
  end = expect + strlen (expect) - 1;
  while (isspace (*expect)) expect++;
  while (isspace (*end)) end--; end ++;
  /* 100 continue is supported */
  if ((end - expect) == 12 && 0 == strnicmp (expect, "100-continue", 12))
    return 1;
  ws_strses_reply (ws, "HTTP/1.1 417 Expectation Failed");
  return 0;
}

static void
ws_req_expect100 (ws_connection_t * ws)
{
  char *expect100;

  expect100 = ws_header_field (ws->ws_lines, "Expect:", NULL);
  if (!expect100)
    return;
  while (isspace (*expect100))
    expect100++;

  if (0 == strnicmp (expect100, "100-continue", 12))
    {
      CATCH_WRITE_FAIL (ws->ws_session)
	{
	  SES_PRINT (ws->ws_session, "HTTP/1.1 100 Continue\r\n\r\n");
	  session_flush_1 (ws->ws_session);
	}
      FAILED
	{
	  ws_write_failed (ws);
	}
      END_WRITE_FAIL (ws->ws_session);
    }
  return;
}

/*##**********************************************************
* This calls the URL rewrite PL/SQL function
* TODO: txn state check possibly need to retry
*************************************************************/
static int
ws_url_rewrite (ws_connection_t *ws)
{
#ifdef VIRTUAL_DIR
  static query_t * url_rewrite_qr = NULL;
  client_connection_t * cli = ws->ws_cli;
  query_t * proc;
  caddr_t err = NULL;
  int rc = LTE_OK, retc = 0;
  local_cursor_t * lc = NULL;

  if (!ws || !ws->ws_map || !ws->ws_map->hm_url_rewrite_rule || MAINTENANCE)
    return 0;

  if (!(proc = (query_t *)sch_name_to_object (wi_inst.wi_schema, sc_to_proc, "DB.DBA.HTTP_URLREWRITE", NULL, "dba", 0)))
    {
      err = srv_make_new_error ("42000", "HT058", "The stored procedure DB.DBA.HTTP_URLREWRITE does not exist");
      goto error_end;
    }
  if (!sec_user_has_group (G_ID_DBA, proc->qr_proc_owner))
    {
      err = srv_make_new_error ("42000", "HT059", "The stored procedure DB.DBA.HTTP_URLREWRITE is not property of DBA group");
      goto error_end;
    }
  if (proc->qr_to_recompile)
    {
      proc = qr_recompile (proc, &err);
      if (err)
	goto error_end;
    }
  if (!url_rewrite_qr)
    url_rewrite_qr = sql_compile_static ("DB.DBA.HTTP_URLREWRITE (?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);

  ws->ws_cli->cli_http_ses = ws->ws_strses;
  ws->ws_cli->cli_ws = ws;

  IN_TXN;
  lt_wait_checkpoint ();
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;

  err = qr_quick_exec (url_rewrite_qr, cli, NULL, &lc, 3,
      ":0", ws->ws_path_string, QRP_STR,
      ":1", ws->ws_map->hm_url_rewrite_rule, QRP_STR,
      ":2", NULL == ws->ws_params ? list (0)  : box_copy_tree (ws->ws_params), QRP_RAW  /* compatibility with old execution sequence */
      );

  if (!err && lc && DV_ARRAY_OF_POINTER == DV_TYPE_OF (lc->lc_proc_ret)
      && BOX_ELEMENTS ((caddr_t *)lc->lc_proc_ret) > 1)
    retc = (int) unbox (((caddr_t *)lc->lc_proc_ret)[1]);

  IN_TXN;
  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
    lt_rollback (cli->cli_trx, TRX_CONT);
  else
    rc = lt_commit (cli->cli_trx, TRX_CONT);
  CLI_NEXT_USER (cli);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;

error_end:
  if (err)
    dk_free_tree (err);
  if (lc)
    lc_free (lc);
  if (retc)
    {
      ws->ws_try_pipeline = 0;
      ws_strses_reply (ws, NULL);
    }

  /* an initial lookup in FS directory would set method in error if it's not a POST, GET or HEAD
     thus after we re-map, we need to set to unknown so DAV can process it
   */
  if (WM_ERROR == ws->ws_method && IS_DAV_DOMAIN(ws, ""))
    ws->ws_method = WM_UNKNOWN;
  return retc;
#endif
}

/* Request URL & parameters parsing
   performs the url rewrite
   the function returns :
   0 if processing must continue
   1 if a redirect done inside rewrite rules
 */
int
ws_path_and_params (ws_connection_t * ws)
{
  char ch, lc;
  dk_set_t paths = NULL;
  char name [PATH_ELT_MAX_CHARS];
  int n_fill = 0, is_dir = 0, rc = 0;
  char * proto;
  int inx, method_name_len, is_proxy_request, body_like_post;
  char * pmethod;
  char * path1;
  pmethod = strchr (ws->ws_req_line, '\x20');
  if (NULL == pmethod)
    {
#ifdef WM_ERROR
      ws->ws_method = WM_ERROR;
#else
      ws->ws_method = WM_UNKNOWN;
#endif
      ws->ws_method_name[0] = 0;
      return 0;
    }
  inx = (long) (pmethod - ws->ws_req_line + 1);
  method_name_len = MIN (sizeof (ws->ws_method_name) - 1, pmethod - ws->ws_req_line);
  strncpy (ws->ws_method_name, ws->ws_req_line, method_name_len);
  ws->ws_method_name [method_name_len] = '\0';
  ws->ws_method = WM_UNKNOWN; /* default catch-all */
  switch (method_name_len)
    {
    case 3:
      if (0 == memcmp (ws->ws_req_line, "GET", 3))
        ws->ws_method = WM_GET;
      break;
    case 4:
      if (0 == memcmp (ws->ws_req_line, "POST", 4))
        ws->ws_method = WM_POST;
      else if (0 == memcmp (ws->ws_req_line, "HEAD", 4))
        ws->ws_method = WM_HEAD;
      else if (0 == memcmp (ws->ws_req_line, "MGET", 4))
        ws->ws_method = WM_URIQA_MGET;
      else if (0 == memcmp (ws->ws_req_line, "MPUT", 4))
        ws->ws_method = WM_URIQA_MPUT;
      break;
    case 7:
      if (0 == memcmp (ws->ws_req_line, "MDELETE", 7))
        ws->ws_method = WM_URIQA_MDELETE;
      else if (0 == memcmp (ws->ws_req_line, "OPTIONS", 7))
        ws->ws_method = WM_OPTIONS;
      break;
    /* no default */
    }

  while ('\x20' == ws->ws_req_line[inx]) inx++;
  proto = ws->ws_req_line + inx;
  while ((unsigned char)(proto[0]) > 0x20) proto++;
  while ('\x20' == proto[0]) proto++;
  if (!strncmp (proto, "HTTP/", 5))
    {
      memcpy (ws->ws_proto, proto, 8);
    }
  else
    {
      strcpy_ck (ws->ws_proto, "HTTP/1.0");
    }
  proto[0] = '\0'; /* As requested by Mitko to preserve the behaviour of http_request_get ('QUERY_STRING') */

  ws->ws_proto_no = (ws->ws_proto[5] - '0') * 10 + (ws->ws_proto[7] - '0');
  if (ws->ws_proto_no > 10)
    tws_1_1_requests++;

  ws->ws_try_pipeline = (nc_strstr ((unsigned char *) ws_header_field (ws->ws_lines, "Connection:", ""),
	(unsigned char *) "Keep-Alive") ||
                          (ws->ws_proto_no > 10
			  && !nc_strstr ((unsigned char *) ws_header_field (ws->ws_lines, "Connection:", ""),
			    (unsigned char *) "close")));
#ifndef VIRTUAL_DIR
    {
      char *szSlashSlash = strstr (ws->ws_req_line + inx + 1, "://");
      if (szSlashSlash)
	inx = szSlashSlash - ws->ws_req_line + 2;
    }
#endif
/*    {
      char *szSlashSlash = strstr (ws->ws_req_line + inx + 1, "://");
      if (szSlashSlash)
	ws->ws_try_pipeline = (NULL !=
	    nc_strstr (ws_header_field (ws->ws_lines, "Proxy-Connection:", ""), "Keep-Alive"));
      else if (ws->ws_proto_no < 11)
	ws->ws_try_pipeline = (NULL !=
	    nc_strstr (ws_header_field (ws->ws_lines, "Connection:", ""), "Keep-Alive"));
    }*/
  n_fill = 0;
  ch = '\x0';
  for (;;)
    {
      lc = ch;
      ch = ws->ws_req_line[inx++];
      if (n_fill > sizeof (name) - 3)
	break;
      if (0 == ch || ' ' == ch || '\n' == ch || '\r' == ch || '\t' == ch
	  || ch == '?')
	break;
      if (ch == '/')
	{
	  if (n_fill > 1 || (n_fill == 1 && name[0] != '.'))
	    {
	      dk_set_push (&paths, (void*) box_line (name, n_fill));
	      n_fill = 0;
	    }
	}
      else if (ch == '%')
	{
	  name[n_fill++] = char_hex_digit (ws->ws_req_line[inx + 0]) * 16 /*1 and 2*/
	      + char_hex_digit (ws->ws_req_line[inx + 1]);
	  inx += 2;
	}
      else
	{
	  name[n_fill++] = ch;
	}
    }
  if (n_fill > 1 || (n_fill == 1 && name[0] != '.'))
    dk_set_push (&paths, box_line (name, n_fill));
  ws->ws_path = (caddr_t*) list_to_array (dk_set_nreverse (paths));
#ifdef DEBUG
  {
    int i;
    printf ("\n%s:%d ws->ws_path = (", __FILE__, __LINE__);
    for (i = 0; i < BOX_ELEMENTS (ws->ws_path); i++) printf (" '%s'", ws->ws_path[i]);
    printf (" )\n");
  }
#endif
  if (lc == '/' || (lc == '.' && n_fill == 1))
    is_dir = 1;
  ws->ws_resource = BOX_ELEMENTS (ws->ws_path) > 0 && !is_dir ? box_copy (ws->ws_path [BOX_ELEMENTS (ws->ws_path) - 1]) : NULL;

  ws_set_path_string (ws, is_dir);
#ifdef VIRTUAL_DIR
  if (0 != strnicmp (ws->ws_path_string, "http://", 7))
    ws_set_phy_path (ws, is_dir, NULL);
  else /* raw proxy request */
    ws->ws_p_path_string = box_copy (ws->ws_path_string);
#endif

  if (ch == '?')
    {
      dk_session_t tmp;
      scheduler_io_data_t sio;
      dk_session_t * cont = strses_allocate ();
      memset (&tmp, 0, sizeof (dk_session_t));
      memset (&sio, 0, sizeof (scheduler_io_data_t));
      tmp.dks_in_buffer = ws->ws_req_line + inx;
      tmp.dks_in_read = 0;
      tmp.dks_in_fill = (int) (strlen (ws->ws_req_line) - inx);
      SESSION_SCH_DATA (&tmp) = &sio;
      CATCH_READ_FAIL(&tmp)
	{
	  ws->ws_params = ws_read_post (&tmp, tmp.dks_in_fill, ws->ws_strses, cont);
	}
      END_READ_FAIL(&tmp);
      dk_free_box ((box_t) cont);
    }

  rc = ws_url_rewrite (ws);
  ws->ws_proxy_request = (ws->ws_p_path_string ? (0 == strnicmp (ws->ws_p_path_string, "http://", 7)) : 0);
  is_proxy_request = (ws->ws_p_path_string ?
      ((0 == strnicmp (ws->ws_p_path_string, "http://", 7)) ||
      (1 == is_http_handler (ws->ws_p_path_string))) : 0);

  ws->ws_req_len = atoi(ws_header_field(ws->ws_lines, "Content-Length:", "0"));
  if (ws->ws_req_len < 0)
    {
      ws->ws_req_len = 0;
      ws->ws_try_pipeline = 0;
    }
#ifdef VIRTUAL_DIR
  if (ws->ws_req_len && (IS_DAV_DOMAIN(ws, "") || ws->ws_method == WM_POST))
    ws_req_expect100 (ws);
#endif
  body_like_post = (ws->ws_method == WM_POST) /* || (ws->ws_method == WM_URIQA_MPUT) || (ws->ws_method == WM_URIQA_MDELETE) */ ;
  if (!is_proxy_request && body_like_post)
    {
      caddr_t *params = NULL;
      char *szContentType = ws_header_field (ws->ws_lines, "Content-type:",
	  "application/octet-stream");

      while (*szContentType && *szContentType <= '\x20')
	szContentType++;
      if (!strnicmp (szContentType, "multipart", 9))
	{
	  int is_stream = 0;
	  params = ws_read_multipart_mime_post (ws, &is_stream);
	  if (is_stream)
	    {
	      ws->ws_stream_params = params;
	      params = NULL;
	    }
	}
      else if (!strnicmp (szContentType, "application/x-www-form-urlencoded", 33))
	{
	  params = ws_read_post_1 (ws, ws->ws_req_len, ws->ws_strses);
	  ws->ws_req_len = 0;
	}
      if (NULL != params)
	{
	  if (NULL == ws->ws_params)
	    ws->ws_params = params;
	  else
	    {
	      caddr_t new_params = dk_alloc_box (box_length (ws->ws_params) + box_length (params), DV_ARRAY_OF_POINTER);
	      memcpy (new_params, ws->ws_params, box_length (ws->ws_params));
	      memcpy (new_params + box_length (ws->ws_params), params, box_length (params));
	      dk_free_box ((caddr_t)(ws->ws_params));
	      dk_free_box ((caddr_t) params);
	      ws->ws_params = (caddr_t *)(new_params);
	    }
	}
    }
  if (is_proxy_request && body_like_post)
    ws_http_body_read (ws, (dk_session_t **)(&ws->ws_stream_params));

  if (!ws->ws_params)
    ws->ws_params = (caddr_t*) list (0);
#ifdef VIRTUAL_DIR
  path1 = (ws->ws_p_path && BOX_ELEMENTS (ws->ws_p_path) )? ws->ws_p_path[0] : NULL;
#else
  path1 = (ws->ws_path && BOX_ELEMENTS (ws->ws_path) )? ws->ws_path[0] : NULL;
#endif
  if (!path1)
    path1 = "";
  if (IS_DAV_DOMAIN(ws, path1) && ws->ws_method != WM_HEAD && ws->ws_method != WM_OPTIONS)
    ws->ws_method = WM_UNKNOWN;
#if 1
  else if (ws->ws_method == WM_UNKNOWN)
    ws->ws_method = WM_ERROR;
#endif
  if (strcmp (ws->ws_method_name, "PUT") || !IS_DAV_DOMAIN(ws, path1))
    ws_http_body_read (ws, &ws->ws_req_body);
  return rc;
}

int
http_method_id (char * method)
{
  int inx, meth = 0;
  if (!method)
    return 0;
  for (inx = 1; NULL != http_methods[inx]; inx ++)
    {
      if (!stricmp (method, http_methods[inx]))
	{
	  meth = inx;
	  break;
	}
    }
  return meth;
}

void
http_set_default_options (ws_connection_t * ws)
{
  static char * defs[] = { "GET", "HEAD", "POST", "OPTIONS", NULL };
  int inx, m;
  memset (ws->ws_options, 0, sizeof (ws->ws_options));
  for (inx = 0; NULL != defs[inx]; inx ++)
    {
      m = http_method_id (defs[inx]);
      ws->ws_options [m] = '\x1';
    }
}

char *
http_get_method_string (int id)
{
  return http_methods [id];
}

void
http_options_print (ws_connection_t * ws, dk_session_t * ses)
{
  int inx, ndone = 0;
  for (inx = 1; NULL != http_methods[inx]; inx ++)
    {
      if (ws->ws_options[inx])
	{
	  if (ndone)
	    SES_PRINT (ses, ",");
	  SES_PRINT (ses, http_methods[inx]);
	  ndone++;
	}
    }
  if (0 == ndone)
    SES_PRINT (ses, "GET,HEAD,POST,OPTIONS");
}


long http_keep_hosting = 0;


void
ws_clear (ws_connection_t * ws, int error_cleanup)
{
  if (http_ses_trap)
    {
      dk_free_box ((box_t) ws->ws_req_log);
      ws->ws_ses_trap = http_ses_trap;
      if (ws->ws_ses_trap)
	ws->ws_req_log = strses_allocate ();
      else
	ws->ws_req_log = NULL;
    }
  if (!error_cleanup)
    {
      dk_free_tree ((box_t) ws->ws_lines);
      ws->ws_lines = NULL;

      if (ws->ws_cli && ws->ws_cli->cli_trx && ws->ws_cli->cli_trx->lt_is_excl)
	{
	  while (srv_have_global_lock (THREAD_CURRENT_THREAD))
	    srv_global_unlock (ws->ws_cli, ws->ws_cli->cli_trx);
	}

      client_connection_reset (ws->ws_cli);
      dk_free_box (ws->ws_client_ip);
      ws->ws_client_ip = NULL;
      ws->ws_forward = 0;
      dk_free_box (ws->ws_req_line);
      ws->ws_req_line = NULL;
      dk_free_box (ws->ws_path_string);
      ws->ws_path_string = NULL;
#ifdef VIRTUAL_DIR
      dk_free_tree ((box_t) ws->ws_p_path);
      ws->ws_p_path = NULL;
      dk_free_box (ws->ws_p_path_string);
      ws->ws_p_path_string = NULL;
#endif
      dk_free_tree ((box_t) ws->ws_path);
      ws->ws_path = NULL;
      dk_free_tree ((box_t) ws->ws_params);
      ws->ws_params = NULL;
      dk_free_tree ((box_t) ws->ws_resource);
      ws->ws_resource = NULL;
      ws->ws_in_error_handler = 0;
    }
  dk_free_tree ((box_t) ws->ws_stream_params);
  ws->ws_stream_params = NULL;
  dk_free_box (ws->ws_header);
  ws->ws_header = NULL;
  dk_free_box (ws->ws_file);
  ws->ws_file = NULL;
  dk_free_tree (ws->ws_status_line);
  ws->ws_status_line = NULL;
  ws->ws_status_code = 0;
  ws->ws_body_limit = 0;
  if (ws->ws_cli)
    {
      memset (&ws->ws_cli->cli_activity, 0, sizeof (db_activity_t));
      ws->ws_cli->cli_anytime_timeout_orig = ws->ws_cli->cli_anytime_timeout = 0;
    }
  if (!http_keep_hosting)
    hosting_clear_cli_attachments (ws->ws_cli, 0);

  ws->ws_charset = ws_default_charset;
  ws->ws_req_len = 0;
  if (ws->ws_req_body)
    {
      dk_free_tree (ws->ws_req_body);
      ws->ws_req_body = NULL;
    }
  ws->ws_map = NULL;
  ws->ws_ignore_disconnect = 0;
  dk_free_tree (ws->ws_store_in_cache);
  ws->ws_store_in_cache = NULL;
  ws->ws_proxy_request = 0;
  IN_TXN;
  ws->ws_limited = 0;
  LEAVE_TXN;
  http_set_default_options (ws);
#ifdef _SSL
  ws->ws_ssl_ctx = NULL;
#endif
}

char http_server_id_string_buf [1024];
char *http_server_id_string = NULL;
char *http_client_id_string = "Mozilla/4.0 (compatible; OpenLink Virtuoso)";

#define IS_CHUNKED_OUTPUT(ws) \
	((ws) && strses_is_ws_chunked_output ((ws)->ws_strses))

#define CHUNKED_STATE_CLEAR(ws) \
        strses_ws_chunked_state_reset ((ws)->ws_strses)

#define CHUNKED_STATE_SET(ws) \
        strses_ws_chunked_state_set ((ws)->ws_strses, (ws)->ws_session)

query_t *http_xslt_qr;

long http_print_warnings_in_output = 0;

#define HTTP_SET_STATUS_LINE(ws,s,when) if (!ws->ws_status_line) \
                                          ws->ws_status_line = box_dv_short_string (s); \
				        else if (when) \
					  { \
					    dk_free_tree (ws->ws_status_line); \
					    ws->ws_status_line = box_dv_short_string (s); \
					  } \
                                        if (ws->ws_status_line && strlen (ws->ws_status_line) > 9) \
					   sscanf (ws->ws_status_line + 9, "%3d", &ws->ws_status_code); \
                                        else \
					   ws->ws_status_code = 200


static caddr_t *
ws_split_ac_header (const caddr_t header)
{
  char *tmp, *tok_s = NULL, *tok;
  dk_set_t set = NULL;
  caddr_t string = box_dv_short_string (header);
  float q;
  tok = strtok_r (string, ",", &tok_s);
  while (tok)
    {
      char * sep;
      while (*tok && isspace (*tok))
	tok++;
      q = 1.0;
      sep = strchr (tok, ';');
      if (NULL != sep)
	{
	  char * eq = strchr (sep, '=');
	  if (eq)
	    q = atof (++eq);
          *sep = 0;
	  tmp = sep > tok ? sep - 1 : NULL;
	}
      else if (tok_s)
	tmp = tok_s - 2;
      else if (tok && strlen (tok) > 1)
	tmp = tok + strlen (tok) - 1;
      else
	tmp = NULL;
      while (tmp && tmp >= tok && isspace (*tmp))
	*(tmp--) = 0;
      if (*tok)
	{
	  dk_set_push (&set, box_dv_short_string (tok));
	  dk_set_push (&set, box_float (q));
	}
      tok = strtok_r (NULL, ",", &tok_s);
    }
  dk_free_box (string);
  return (caddr_t *)list_to_array (dk_set_nreverse (set));
}

static caddr_t *
ws_header_line_to_array (caddr_t string)
{
  int len;
  char buf [1000];
  dk_set_t lines = NULL;
  caddr_t * headers = NULL;
  dk_session_t * ses = NULL;

  ses = strses_allocate ();
  session_buffered_write (ses, string, box_length (string) - 1);
  CATCH_READ_FAIL (ses)
    {
      for (;;)
	{
	  len = dks_read_line (ses, buf, sizeof (buf));
	  if (0 != len)
	    dk_set_push (&lines, box_line (buf, len));
	}

    }
  END_READ_FAIL (ses);
  dk_free_box (ses);
  headers = (caddr_t *) list_to_array (dk_set_nreverse (lines));
  return headers;
}

static char *
ws_get_mime_variant (char * mime, char ** found)
{
  static char * compat[] = {"text/plain", "text/*", NULL, NULL}; /* for now text/plain only, can be added more */
  int inx;
  *found = NULL;
  for (inx = 0; NULL != compat[inx]; inx += 2)
    {
      if (!strcmp (compat[inx], mime))
	{
	  *found = compat[inx];
	  return compat[inx+1];
	}
    }
  return mime;
}


static const char *
ws_check_accept (ws_connection_t * ws, char * mime, const char * code, int check_only, OFF_T clen, const char * charset)
{
  static char *fmt =
      "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n"
      "<html><head>\n"
      "<title>406 Not Acceptable</title>\n"
      "</head><body>\n"
      "<h1>406 Not Acceptable</h1>\n"
      "<p>An appropriate representation of the requested resource %s could not be found on this server.</p>\n"
      "Available variant(s):\n"
      "<ul>\n"
      "<li><a href=\"%s\">%s</a> , type %s, charset %s</li>\n"
      "</ul>\n"
      "</body></html>\n";
  caddr_t accept;
  char buf [1000];
  caddr_t ctype = NULL, cenc = NULL;
  caddr_t * asked;
  char * match = NULL, * found = NULL;
  int inx;
  float maxq = 0;
  int ignore = (ws->ws_p_path_string ?
      ((0 == strnicmp (ws->ws_p_path_string, "http://", 7)) ||
      (1 == is_http_handler (ws->ws_p_path_string))) : 0);
  /*			    0123456789012*/
  if (ignore || 0 !=  strncmp (code, "HTTP/1.1 200", 12))
    return check_only ? NULL : code;
  accept = ws_mime_header_field (ws->ws_lines, "Accept", NULL, 1);
  if (!accept) /* consider it is everything, so we just skip the whole logic */
    return check_only ? NULL : code;

  if (!mime && ws->ws_header)
    {
      caddr_t * headers = ws_header_line_to_array (ws->ws_header);
      mime = ctype = ws_mime_header_field (headers, "Content-Type", NULL, 0);
      cenc = ws_mime_header_field (headers, "Content-Type", "charset", 0);
      if (NULL != cenc)
	charset = cenc;
      dk_free_tree (headers);
    }
  if (!mime)
    mime = "text/html";
  asked = ws_split_ac_header (accept);
  DO_BOX_FAST_STEP2 (caddr_t, p, caddr_t, q, inx, asked)
    {
      float qf = unbox_float (q);
      p = ws_get_mime_variant (p, &found);
      if (DVC_MATCH == cmp_like (mime, p, NULL, 0, LIKE_ARG_CHAR, LIKE_ARG_CHAR))
	{
	  if (qf > maxq)
	    {
	      match = p;
	      maxq = qf;
	    }
	}
    }
  END_DO_BOX;
  if (!match)
    {
      char * cname = ws->ws_resource ? ws->ws_resource : ( ws->ws_map && ws->ws_map->hm_def_page ? ws->ws_map->hm_def_page : "index.html");
      caddr_t tmpbuf;

      code = "HTTP/1.1 406 Unacceptable";
      dk_free_tree (ws->ws_header);
      snprintf (buf, sizeof (buf), "Alternates: {\"%s\" 1 {type %s} {charset %s} {length " OFF_T_PRINTF_FMT "}}\r\n",
	  cname, mime, charset, (OFF_T_PRINTF_DTP)clen);
      ws->ws_header = box_dv_short_string (buf);
      strses_flush (ws->ws_strses);
      tmpbuf = box_sprintf (1000, fmt, cname, cname, cname, mime, charset);
      session_buffered_write (ws->ws_strses, tmpbuf, strlen (tmpbuf));
      dk_free_box (tmpbuf);
      if (check_only)
	{
	  HTTP_SET_STATUS_LINE (ws, code, 1);
	}
      check_only = 0;
    }
  if (NULL != found && ws->ws_header && nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Type:") != NULL)
    {
      caddr_t * headers = ws_header_line_to_array (ws->ws_header);
      dk_session_t * ses = strses_allocate ();
      DO_BOX (caddr_t, h, inx, headers)
	{
	  if (nc_strstr ((unsigned char *) h, (unsigned char *) "Content-Type:") != NULL)
	    continue;
	  SES_PRINT (ses, h);
	}
      END_DO_BOX;
      SES_PRINT (ses, "Content-Type: "); SES_PRINT (ses, found); SES_PRINT (ses, "\r\n");
      dk_free_tree (ws->ws_header);
      ws->ws_header = strses_string (ses);
      dk_free_tree (headers);
      dk_free_box (ses);
    }
  dk_free_tree (ctype);
  dk_free_tree (cenc);
  dk_free_tree (asked);
  dk_free_tree (accept);
  return check_only ? NULL : code;
}

#define WS_CORS_STAR (caddr_t*)-1

static caddr_t *
ws_split_cors (caddr_t str)
{
  char *tok_s = NULL, *tok;
  dk_set_t acl_set_ptr = NULL;
  caddr_t acl_string = str ? box_dv_short_string (str) : NULL;
  if (NULL != acl_string)
    {
      tok_s = NULL;
      tok = strtok_r (acl_string, " ", &tok_s);
      while (tok)
	{
	  if (tok && strlen (tok) > 0)
	    {
	      if (!strcmp (tok, "*"))
		{
		  dk_free_tree (list_to_array (dk_set_nreverse (acl_set_ptr)));
		  dk_free_box (acl_string);
		  return WS_CORS_STAR;
		}
	      dk_set_push (&acl_set_ptr, box_dv_short_string (tok));
	    }
	  tok = strtok_r (NULL, " ", &tok_s);
	}
      dk_free_box (acl_string);
    }
  return (caddr_t *) list_to_array (dk_set_nreverse (acl_set_ptr));
}

static int
ws_cors_check (ws_connection_t * ws, char * buf, size_t buf_len)
{
#ifdef VIRTUAL_DIR
  caddr_t origin = ws_mime_header_field (ws->ws_lines, "Origin", NULL, 1);
  int rc = 0;
  if (origin && ws->ws_status_code < 500 && ws->ws_map && ws->ws_map->hm_cors)
    {
      caddr_t * orgs = ws_split_cors (origin), * place = NULL;
      int inx;
      if (ws->ws_map->hm_cors == (id_hash_t *) WS_CORS_STAR)
	rc = 1;
      else if (orgs != WS_CORS_STAR)
	{
	  DO_BOX (caddr_t, org, inx, orgs)
	    {
	      if (NULL != (place = (caddr_t *) id_hash_get_key (ws->ws_map->hm_cors, (caddr_t) & org)))
		{
		  rc = 1;
		  break;
		}
	    }
	  END_DO_BOX;
	}
      if (orgs != WS_CORS_STAR)
	dk_free_tree (orgs);
      if (rc)
	snprintf (buf, buf_len, "Access-Control-Allow-Origin: %s\r\n", place ? *place : "*");
    }
  dk_free_tree (origin);
  if (0 == rc && ws->ws_map && ws->ws_map->hm_cors_restricted)
    return 0;
#endif
  return 1;
}

void
ws_strses_reply (ws_connection_t * ws, const char * volatile code)
{
  char tmp[4000];
  const char * acode;
  caddr_t volatile accept_gz = NULL;
  volatile long len = strses_length (ws->ws_strses);
  int cnt_enc = WS_CE_NONE;
#ifdef BIF_XML
  caddr_t media_type = NULL, xsl_encoding = NULL;
  wcharset_t * volatile charset = ws->ws_charset;
  strses_chunked_out_t gzctx;

  if (ws->ws_xslt_url)
    {
      dk_session_t * strses = ws->ws_strses;
      client_connection_t * cli = ws->ws_cli;
      caddr_t url,
	  xslt_url = ws->ws_xslt_url, xslt_parms = ws->ws_xslt_params;
      caddr_t err = NULL, * exec_params = NULL;
      size_t current_url_len = strlen (http_port) + strlen (ws->ws_path_string) + 18;
      caddr_t current_url = dk_alloc_box (current_url_len, DV_SHORT_STRING);
      snprintf (current_url, current_url_len, "http://localhost:%s%s", http_port, ws->ws_path_string);
      url = current_url;

      if (!http_xslt_qr || http_xslt_qr->qr_to_recompile)
	err = srv_make_new_error ("42001", "HT004", "No DB.DBA.__HTTP_XSLT defined");
      if (!err)
	{
	  exec_params = (caddr_t *) dk_alloc_box (6 * 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  exec_params[0] = box_string ("_XML"); exec_params[1] = (caddr_t) &strses;
	  exec_params[2] = box_string ("DOC_URI"); exec_params[3] = (caddr_t) &url;
	  exec_params[4] = box_string ("XSLT_URI"); exec_params[5] = (caddr_t) &xslt_url;
	  exec_params[6] = box_string ("PARAMS"); exec_params[7] = (caddr_t) &xslt_parms;
	  exec_params[8] = box_string ("MEDIATYPE"); exec_params[9] = (caddr_t) &media_type;
	  exec_params[10] = box_string ("ENC"); exec_params[11] = (caddr_t) &xsl_encoding;
	  IN_TXN;
	  if (!cli->cli_trx->lt_threads)
	    lt_wait_checkpoint ();
	  lt_threads_set_inner (cli->cli_trx, 1);
	  LEAVE_TXN;
	  err = qr_exec (cli, http_xslt_qr, CALLER_LOCAL, NULL, NULL, NULL, exec_params, NULL, 1);
	  IN_TXN;
	  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
	    lt_rollback (cli->cli_trx, TRX_CONT);
	  else
	    lt_commit (cli->cli_trx, TRX_CONT);
	  lt_threads_set_inner (cli->cli_trx, 0);
	  LEAVE_TXN;
	  cli_set_slice (cli, NULL, QI_NO_SLICE, NULL);
	  dk_free_box ((box_t) exec_params);
	}
      if (err)
	{
	  char err_msg [300];
	  strcpy_ck (err_msg, "Error mapping the XSL-T stylesheet ");
	  strncat_ck (err_msg, ws->ws_xslt_url, 100);
	  strcat_ck (err_msg, " on ");
	  strncat_ck (err_msg, url, 100);
	  log_error ("%s : [%s] [%s]", err_msg,
	      ERR_STATE (err),
	      ERR_MESSAGE (err));

	  if (DV_STRINGP (ws->ws_status_line) &&
	      0 != strncmp (ws->ws_status_line, "HTTP/1.1 401", 12))
	    {
	      dk_free_tree (ws->ws_status_line);
	      ws->ws_status_line = NULL;
	      ws->ws_status_code = 0;
	    }
	  code = "HTTP/1.0 500 Internal Server Error";
	  ws_proc_error (ws, err);
	  dk_free_tree (err);
	}
      dk_free_tree (ws->ws_xslt_url);
      ws->ws_xslt_url = NULL;
      dk_free_tree (ws->ws_xslt_params);
      ws->ws_xslt_params = NULL;
      len = strses_length (ws->ws_strses);
      dk_free_box (current_url);
    }
#endif
  if (http_print_warnings_in_output)
    {
      dk_set_t warnings;

      warnings = sql_warnings_save (NULL);
      if (warnings)
	{
	  warnings = dk_set_nreverse (warnings);
	  while (warnings)
	    {
	      caddr_t warn = (caddr_t) dk_set_pop (&warnings);
	      SES_PRINT (ws->ws_strses,
		  "\n<br />"
		  " <b>Warning</b>: STATE:<b>");

	      dks_esc_write (ws->ws_strses, ERR_STATE (warn),
		  box_length (ERR_STATE (warn)) - 1,
		  WS_CHARSET (ws, NULL),
		  default_charset, DKS_ESC_PTEXT);

	      SES_PRINT (ws->ws_strses,
		  "</b> MESSAGE=<b>");

	      dks_esc_write (ws->ws_strses, ERR_MESSAGE (warn),
		  box_length (ERR_MESSAGE (warn)) - 1,
		  WS_CHARSET (ws, NULL),
		  default_charset, DKS_ESC_PTEXT);

	      SES_PRINT (ws->ws_strses,
		  "</b><br />\n");
	      dk_free_tree (warn);
	    }
	  len = strses_length (ws->ws_strses);
	}
    }
  if (ws->ws_status_line)
    code = ws->ws_status_line;
  acode = ws_check_accept (ws, media_type, code, 0, len, xsl_encoding ? xsl_encoding : CHARSET_NAME (charset, "ISO-8859-1"));
  if (acode != code)
    {
      len = strses_length (ws->ws_strses);
      code = acode;
    }

  accept_gz = ws_get_packed_hf (ws, "Accept-Encoding:", "");
  if (IS_CHUNKED_OUTPUT (ws))
    cnt_enc = WS_CE_CHUNKED;
  else if (enable_gzip && accept_gz && strstr (accept_gz, "gzip") && ws->ws_proto_no == 11)
    {
      cnt_enc = WS_CE_GZIP;
      ws->ws_try_pipeline = 0; /* browsers based on webkit workaround */
    }
  else if (ws->ws_method != WM_HEAD && ws->ws_body_limit > 0 && ws->ws_body_limit < len)
    {
      code = "HTTP/1.1 509 Bandwidth Limit Exceeded";
      HTTP_SET_STATUS_LINE (ws, code, 1);
      strses_flush (ws->ws_strses);
      ws_http_error (ws, "HTTP/1.1 509 Bandwidth Limit Exceeded", "Bandwidth Limit Exceeded", ws->ws_p_path_string, ws->ws_path_string);
      len = strses_length (ws->ws_strses);
    }

  if (0 != strncmp (code, "HTTP/1.1 2", 10) && 0 != strncmp (code, "HTTP/1.1 3", 10) && ws->ws_proto_no < 11)
    ws->ws_try_pipeline = 0;

  memset (&gzctx, 0, sizeof (strses_chunked_out_t));

  CATCH_WRITE_FAIL (ws->ws_session)
    {
      snprintf (tmp, sizeof (tmp), "%.1000s\r\nServer: %.1000s\r\n", code, http_server_id_string);
      SES_PRINT (ws->ws_session, tmp); /* server signature */
      if (ws->ws_status_code != 101)
	{
	  snprintf (tmp, sizeof (tmp), "Connection: %s\r\n", ws->ws_try_pipeline ? "Keep-Alive" : "close");
	  SES_PRINT (ws->ws_session, tmp);
	}
/*      fprintf (stdout, "\nREPLY-----\n%s", tmp); */
      /* mime type */
      if (ws->ws_status_code != 101 && (!ws->ws_header || (NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Type:"))))
	{
#ifdef BIF_XML
	  if (media_type)
	    {
	      SES_PRINT (ws->ws_session, "Content-Type: ");
	      SES_PRINT (ws->ws_session, media_type);
	      if (xsl_encoding)
		{
		  SES_PRINT (ws->ws_session, "; charset=");
		  SES_PRINT (ws->ws_session, xsl_encoding);
		}
	      else
		{
		  SES_PRINT (ws->ws_session, "; charset=");
		  SES_PRINT (ws->ws_session, CHARSET_NAME (charset, "ISO-8859-1"));
		}
	    }
	  else
#endif
	    {
	      SES_PRINT (ws->ws_session, "Content-Type: text/html; charset=");
	      SES_PRINT (ws->ws_session, CHARSET_NAME (charset, "ISO-8859-1"));
	    }
	  SES_PRINT (ws->ws_session, "\r\n");
	}

#ifdef BIF_XML
      dk_free_tree (media_type);
      dk_free_tree (xsl_encoding);
#endif

      if (ws->ws_method == WM_OPTIONS && ws->ws_status_code < 400 &&
	  (NULL == ws->ws_header || NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Allow:")))
	{
	  len = 0;
	  strses_flush (ws->ws_strses);
	  SES_PRINT (ws->ws_session, "Allow: ");
	  http_options_print (ws, ws->ws_session);
	  SES_PRINT (ws->ws_session, "\r\n");
	}

      /* timestamp */
      if (!ws->ws_header || NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Date:"))
	{
	  char dt [DT_LENGTH];
	  char last_modify[100];

	  dt_now (dt);
	  dt_to_rfc1123_string (dt, last_modify, sizeof (last_modify));
	  SES_PRINT (ws->ws_session, "Date: ");
	  SES_PRINT (ws->ws_session, last_modify);
	  SES_PRINT (ws->ws_session, "\r\n");
	}

      if (!ws->ws_header || NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Access-Control-Allow-Origin:"))
	{
	  tmp[0] = 0;
	  if (0 == ws_cors_check (ws, tmp, sizeof (tmp)))
	    {
	      strses_flush (ws->ws_strses);
	      len = strses_length (ws->ws_strses);
	    }
	  if (tmp[0] != 0)
	    SES_PRINT (ws->ws_session, tmp);
	}

      if (ws->ws_status_code != 101)
      SES_PRINT (ws->ws_session, "Accept-Ranges: bytes\r\n");

      if (ws->ws_header) /* user-defined headers */
	{
	  SES_PRINT (ws->ws_session, ws->ws_header);
	}
      if (cnt_enc == WS_CE_CHUNKED) /* chunked output */
	{
	  SES_PRINT (ws->ws_session, "Transfer-Encoding: chunked\r\n");
	}
      else if (cnt_enc == WS_CE_GZIP) /* gzip encoding */
	{
	  snprintf (tmp, sizeof (tmp), "Transfer-Encoding: chunked\r\nContent-Encoding: gzip\r\n");
	  SES_PRINT (ws->ws_session, tmp);
	}
      else if (ws->ws_status_code != 101 && (!ws->ws_header || (NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Length:")))) /* plain body */
	{
	  snprintf (tmp, sizeof (tmp), "Content-Length: %ld\r\n", len);
	  SES_PRINT (ws->ws_session, tmp);
	}

      SES_PRINT (ws->ws_session, "\r\n"); /* empty line */

      /* write body */
      if (ws->ws_method != WM_HEAD)
	{
	  if (cnt_enc == WS_CE_CHUNKED)
	    {
	      if (len > 0)
		{
		  snprintf (tmp, sizeof (tmp), "%lx\r\n", len);
		  SES_PRINT (ws->ws_session, tmp);
		  strses_write_out (ws->ws_strses, ws->ws_session);
		  SES_PRINT (ws->ws_session, "\r\n");
		  strses_flush (ws->ws_strses);
		}
	    }
	  else if (cnt_enc == WS_CE_GZIP)
	    {
	      strses_write_out_gz (ws->ws_strses, ws->ws_session, &gzctx);
	    }
	  else if (!ws->ws_header || (NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Length:")))
	    {
	      strses_write_out (ws->ws_strses, ws->ws_session);
	    }
	}
      session_flush_1 (ws->ws_session);
    }
  FAILED
    {
      if (NULL != gzctx.sc_buff)
	gz_stream_free (gzctx.sc_buff);
      ws_write_failed (ws);
    }
  END_WRITE_FAIL (ws->ws_session);
  log_info_http (ws, code, (gzctx.sc_bytes_sent ? gzctx.sc_bytes_sent : len));
  strses_flush (ws->ws_strses);
  dk_free_box (accept_gz);
}


void
ws_proc_error (ws_connection_t * ws, caddr_t err)
{
static char *fmt1 =
  "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">\n"
  "<html>\n"
  "  <head>\n"
  "    <title>Error %.5s</title>\n"
  "  </head>\n"
  "  <body>\n"
  "    <h3>Error %.5s</h3><pre>\n";
static char *fmt2 = "\n"
  "  </pre></body>\n"
  "</html>\n";

  if (0 != strncmp (ERR_STATE (err), "VSPRT", 5))
    {
      char *errmsg = ERR_MESSAGE (err);
      caddr_t tmp = box_sprintf (1000, fmt1, ERR_STATE (err), ERR_STATE (err));
      strses_flush (ws->ws_strses);
      session_buffered_write (ws->ws_strses, tmp, strlen (tmp));
      dk_free_box (tmp);
      dks_esc_write (ws->ws_strses, errmsg, box_length (errmsg) - 1, ws->ws_charset, default_charset, DKS_ESC_PTEXT);
      session_buffered_write (ws->ws_strses, fmt2, strlen (fmt2));
    }
}


void
ws_http_error (ws_connection_t * ws, const caddr_t code, const caddr_t message, const caddr_t uri, const caddr_t path)
{
static char *fmt1 =
  "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML//EN\">\n"
  "<html>\n"
  "  <head>\n"
  "    <title>Error %.100s</title>\n"
  "  </head>\n"
  "  <body>\n"
  "    <h3>Error %.100s</h3><pre>\n";
  caddr_t tmp = box_sprintf (1000, fmt1, code, code);
  strses_flush (ws->ws_strses);
  SES_PRINT (ws->ws_strses, tmp);
  dk_free_box (tmp);
  dks_esc_write (ws->ws_strses, message, strlen (message), ws->ws_charset, default_charset, DKS_ESC_PTEXT);

  SES_PRINT (ws->ws_strses, "    URI  = '");
  dks_esc_write (ws->ws_strses, uri, strlen (uri), ws->ws_charset, default_charset, DKS_ESC_PTEXT);
  SES_PRINT (ws->ws_strses, "'\n");
#ifdef DEBUG
  SES_PRINT (ws->ws_strses, "    PATH = '");
  dks_esc_write (ws->ws_strses, uri, strlen (uri), ws->ws_charset, default_charset, DKS_ESC_PTEXT);
  SES_PRINT (ws->ws_strses, "'\n");
#endif
  SES_PRINT (ws->ws_strses, "  </pre></body></html>\n");
}

#define REPLY_SENT "reply sent"

char * www_root = ".";


static int
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
http_if_modified_since (ws_connection_t *ws, const char *file_name, const char *hn)
#else
http_if_modified_since (ws_connection_t *ws, time_t mtime, const char *hn)
#endif
{
  char dt[DT_LENGTH];
  char dt_mtime[DT_LENGTH];
  caddr_t if_modified_since = NULL;
  int res = 1;

  if_modified_since = ws_get_packed_hf (ws, hn, "");

  if (if_modified_since && http_date_to_dt (if_modified_since, dt))
    {
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
      file_mtime_to_dt (file_name, dt_mtime);
#else
      time_t_to_dt (mtime, 0, dt_mtime);
#endif
      if (memcmp (dt, dt_mtime, DT_COMPARE_LENGTH) >=0)
	res = 0;
    }
  dk_free_tree (if_modified_since);

  return res;
}


static const char *
parse_off_t (const char *str, OFF_T *pres)
{
  *pres = 0;

  while (isdigit (*str))
    {
      *pres = (*pres) * 10 + (*str - '0');
      str++;
    }

  return str;
}


#define MAX_SUPPORTED_RANGES 50

static caddr_t
ws_get_ranges (ws_connection_t *ws, char *err_text, int err_text_max, volatile OFF_T size
    , OFF_T *ranges_in, int have_if_range)
{
  caddr_t range_hdr = NULL;
  OFF_T ranges_local [MAX_SUPPORTED_RANGES * 2];
  OFF_T *ranges = ranges_in ? ranges_in : &(ranges_local[0]);
  const char *ptr;
  int satisfiable = 0, n_ranges = 0;

  if (err_text_max > 0 && err_text)
    err_text[0] = 0;

  range_hdr = ws_get_packed_hf (ws, "Range:", NULL);
  if (!range_hdr)
    goto done;

  if (strncmp (range_hdr, "bytes=", sizeof ("bytes=") - 1))
    goto done;

  ptr = range_hdr + sizeof ("bytes=") - 1;

  while (*ptr)
    {
      int is_suffix = 0;
      OFF_T start = 0, end = size - 1;


      /* parse part */

      if (*ptr != '-')
	{ /* there is a starting offs */
	  ptr = parse_off_t (ptr, &start);
	}
      else /* suffix byte range spec */
	is_suffix = 1;

      if (*ptr != '-')
	{
	  n_ranges = 0;
	  goto done;
	}
      else
	ptr++;

      if (isdigit(*ptr))
	{
	  ptr = parse_off_t (ptr, &end);
	}

      if (*ptr == ',')
	ptr++;
      else if (*ptr)
	{
	  n_ranges = 0;
	  goto done;
	}

      /* analyze part */

      if (is_suffix)
	{ /* suffix byte range spec */
	  end = size - 1;
	  if (start > 0)
	    satisfiable = 1;
	  else if (start == 0)
	    { /* we do not allow zero length suffix specs */
	      n_ranges = 0;
	      goto done;
	    }
	  if (start > size)
	    start = 0;
	  else
	    start = size - start;
	}

      if (end < start)
	{
	  n_ranges = 0;
	  goto done;
	}
      if (end >= size)
	{
	  end = size - 1;
	}

      if (start < size)
	satisfiable = 1;

      /* TODO: for now do not support large files */
      if (start > LONG_MAX || end > LONG_MAX)
	{
	  n_ranges = 0;
	  goto done;
	}

      ranges [n_ranges * 2] = (ptrlong) start;
      ranges [n_ranges * 2 + 1] = (ptrlong) end;

      if (++n_ranges >= MAX_SUPPORTED_RANGES)
	{ /* limit the max ranges per header */
	  n_ranges = 0;
	  goto done;
	}
    }

done:
  dk_free_tree (range_hdr);
  if (n_ranges)
    {
      caddr_t res;
      if (!satisfiable)
	{
	  if (err_text && err_text_max > 0 && !have_if_range)
	    {
	      strncpy (err_text, "HTTP/1.1 416 Requested range not satisfiable", err_text_max);
	      err_text[err_text_max - 1] = 0;
	    }
	  return NULL;
	}
      if (!ranges_in)
	{
	  res = dk_alloc_box (n_ranges * 2 * sizeof (ptrlong), DV_ARRAY_OF_LONG);

	  if (sizeof (OFF_T) != sizeof (ptrlong))
	    { /* GK: downgrade the ranges array for passing to PL */
	      ptrlong len = n_ranges * 2, inx;
	      for (inx = 0; inx < len; inx ++)
		{
		  ((ptrlong *)res)[inx] = (ptrlong) ((OFF_T *)ranges)[inx];
		}
	    }
	  else
	    memcpy (res, ranges, n_ranges * 2 * sizeof (OFF_T));
	  return res;
	}
      else
	return (caddr_t) (ptrlong) n_ranges;
    }
  else
    return NULL;
}


static void
send_chunk (ws_connection_t *ws, int fd, OFF_T left)
{
  CHECK_WRITE_FAIL (ws->ws_session);
  while (left)
    {
      int rc;
      char buf[4096];
      int n = left > sizeof (buf) ? sizeof (buf) : (int) left;
      rc = read (fd, buf, n);
      if (rc < 0)
	break;
      session_buffered_write (ws->ws_session, buf, n);
      left -= n;
    }
}


static void
send_multipart_byteranges (ws_connection_t *ws, int fd,
    OFF_T *ranges, int n_ranges,
    const char *ctype, const char *head_beg, const char *etag,
    const char *last_modify, const char *date_now,
    const char *http_server_id_string, wcharset_t * volatile charset)
{
  int mp;
  char head[4000];

  snprintf (head, sizeof (head),
      "%s\r\n"
      "Content-Type: multipart/byteranges; boundary=THIS_STRING_SEPARATES\r\n"
      "Accept-Ranges: bytes\r\n"
      "ETag: %s\r\n"
      "Last-Modified: %s\r\n"
      "Date: %s\r\n"
      "Server: %.1000s\r\n"
      "Connection: %s\r\n"
      "\r\n"
      "--THIS_STRING_SEPARATES\r\n"
      ,
      head_beg,
      etag,
      last_modify,
      date_now,
      http_server_id_string,
      ws->ws_try_pipeline ? "Keep-Alive" : "close");
  SES_PRINT (ws->ws_session, head);
  fprintf (stdout, "Head_mp = %s\n", head);

  for (mp = 0; mp < n_ranges; mp++)
    {
      snprintf (head, sizeof (head),
	  "Content-Type: %s%s%s\r\n"
	  "Content-range: bytes " OFF_T_PRINTF_FMT "-" OFF_T_PRINTF_FMT "/" OFF_T_PRINTF_FMT "\r\n"
	  "\r\n",
	  ctype, charset ? "; charset=" : "", CHARSET_NAME (charset, ""),
	  (OFF_T_PRINTF_DTP) ranges[mp * 2],
	  (OFF_T_PRINTF_DTP) ranges[mp * 2 + 1],
	  (OFF_T_PRINTF_DTP) (ranges[mp * 2 + 1] - ranges [mp + 2] + 1)
	  );
      SES_PRINT (ws->ws_session, head);
      LSEEK (fd, ranges[mp * 2], SEEK_SET);
      send_chunk (ws, fd, ranges[mp * 2 + 1] - ranges [mp + 2] + 1);
      if (mp < n_ranges - 1)
	SES_PRINT (ws->ws_session, "--THIS_STRING_SEPARATES\r\n");
      else
	SES_PRINT (ws->ws_session, "--THIS_STRING_SEPARATES--\r\n");
    }
}


static caddr_t
bif_http_sys_parse_ranges_header (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *szMe = "http_sys_parse_ranges_header";
  query_instance_t *qi = (query_instance_t *)qst;
  char *if_range;
  ws_connection_t *ws = NULL;
  caddr_t ranges = NULL;

  ptrlong length;
  char err_text[200];

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("37000", "HT068", "http_sys_parse_ranges_header function outside of http context");
  else
    ws = qi->qi_client->cli_ws;

  length = bif_long_arg (qst, args, 0, szMe);
  if_range = ws_get_packed_hf (ws, "If-Range:", "");
  ranges = ws_get_ranges (ws, err_text, sizeof (err_text), length, NULL, if_range ? 1 : 0);

  if (err_text [0])
    {
      ws_http_error (ws, err_text, err_text, ws->ws_p_path_string, ws->ws_path_string);
      HTTP_SET_STATUS_LINE (ws, err_text, 1);
      dk_free_box (if_range);
      dk_free_tree (ranges);
      return box_num (0);
    }

  return ranges ? ranges : NEW_DB_NULL;
}

caddr_t
http_sys_find_best_accept_impl (caddr_t * qst, state_slot_t *ret_val_ssl, caddr_t accept_strg, caddr_t *supp, const char *szMe)
{
  if (NULL != accept_strg)
    {
      int supp_ctr, supp_count;
      supp_count = BOX_ELEMENTS (supp) / 2;
      for (supp_ctr = 0; supp_ctr < supp_count; supp_ctr++)
        {
          caddr_t mime, val;
          mime = supp [supp_ctr*2];
          val = supp [supp_ctr*2 + 1];
          if (DV_STRING != DV_TYPE_OF (mime))
            continue;
          if (NULL == strstr (accept_strg, mime))
            continue;
          if (NULL != ret_val_ssl)
            qst_set (qst, ret_val_ssl, box_copy_tree (val));
          return box_copy_tree (mime);
        }
    }
  if (NULL != ret_val_ssl)
    qst_set (qst, ret_val_ssl, NEW_DB_NULL);
  return NEW_DB_NULL;
}


static caddr_t
bif_http_sys_find_best_accept (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *szMe = "http_sys_find_best_accept";
  caddr_t accept_strg = bif_string_or_null_arg (qst, args, 0, szMe);
  caddr_t *supp = (caddr_t *)bif_array_arg (qst, args, 1, szMe);
  dtp_t supp_dtp = DV_TYPE_OF (supp);
  state_slot_t *ret_val_ssl = NULL;
  if (DV_ARRAY_OF_POINTER != supp_dtp)
    sqlr_new_error ("22023", "SR622",
      "Function %s needs an array as second argument, in a get_keyword() style, not an arg of type %s (%d)",
      szMe, dv_type_title (supp_dtp), supp_dtp );
  if (BOX_ELEMENTS(args) > 2)
    {
      ret_val_ssl = args[2];
      if (SSL_CONSTANT == ret_val_ssl->ssl_type)
        ret_val_ssl = NULL;
    }
  return http_sys_find_best_accept_impl (qst, ret_val_ssl, accept_strg, supp, szMe);
}

void
ws_file (ws_connection_t * ws)
{
  char path[1000];
  char head[4000];
  char head_beg[100];
  char etag[200];
  char err_text[200];
  char date_now[100];
  char last_modify[100];
  OFF_T volatile off;
  caddr_t etag_in = NULL;
  caddr_t fname = ws->ws_file;
  char *lfname = (char *) (ws->ws_path_string ? ws->ws_path_string : "/");
  char * ctype;
  int fd;
  STAT_T st;

  caddr_t box_date, md5_etag;
  wcharset_t * volatile charset = ws->ws_charset;
  OFF_T ranges[MAX_SUPPORTED_RANGES * 2];
  int n_ranges = 0;

  box_date = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  dt_now (box_date);
  dt_to_rfc1123_string (box_date, date_now, sizeof (date_now));
  dk_free_box (box_date);

  if (strstr (fname, ".."))
    {
      ws_http_error (ws, "HTTP/1.1 400 Path contains ..", "Path contains ..", lfname, "");
      HTTP_SET_STATUS_LINE (ws, "HTTP/1.1 400 Path contains ..", 0);
      return;
    }

  if (strlen (www_root) + strlen (fname) > sizeof (path) - 1)
    {
      ws_http_error (ws, "HTTP/1.1 400 Path too long", "Path too long", lfname, "");
      HTTP_SET_STATUS_LINE (ws, "HTTP/1.1 400 Path too long", 0);
      return;
    }

  snprintf (path, sizeof (path), "%s%s", www_root, fname);
  ctype = ws_file_ctype (fname);
  if ((fd = open (path, OPEN_FLAGS_RO)) < 0)
    {
      ws_http_error (ws, "HTTP/1.1 404 File not found", "The requested URL was not found", lfname, path);
      HTTP_SET_STATUS_LINE (ws, "HTTP/1.1 404 File not found", 0);
      return;
    }
  if (V_FSTAT (fd, &st) || 0 != (st.st_mode & S_IFDIR))
    {
      ws_http_error (ws, "HTTP/1.1 404 File not found", "The requested URL is not an ordinary resource", lfname, path);
      HTTP_SET_STATUS_LINE (ws, "HTTP/1.1 404 File not found", 0);
      close (fd);
      return;
    }

  off = LSEEK (fd, 0, SEEK_END);
  LSEEK (fd, 0, SEEK_SET);

  md5_etag = md5 (fname);
  snprintf (etag, sizeof (etag), "\"" OFF_T_PRINTF_FMT OFF_T_PRINTF_FMT "%s\"",
      (OFF_T_PRINTF_DTP) off, (OFF_T_PRINTF_DTP) st.st_mtime, md5_etag);
  dk_free_tree (md5_etag);

  if (ws->ws_method != WM_HEAD && ws->ws_method != WM_OPTIONS)
    {
      char *if_range = ws_get_packed_hf (ws, "If-Range:", "");

      err_text[0] = 0;
      n_ranges = (int) (ptrlong) ws_get_ranges (ws, err_text,
	  sizeof (err_text), off, &(ranges[0]), if_range ? 1 : 0);
      if (err_text [0])
	{
	  ws_http_error (ws, err_text, err_text, lfname, path);
	  HTTP_SET_STATUS_LINE (ws, err_text, 1);
	  close (fd);
	  dk_free_box (if_range);
	  return;
	}

      if (if_range && strcmp (if_range, etag) &&
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
	  http_if_modified_since (ws, path, "If-Range:")
#else
	  http_if_modified_since (ws, st.st_mtime, "If-Range:")
#endif
	  )
	n_ranges = 0;
      dk_free_box (if_range);
    }

  if (!n_ranges)
    etag_in = ws_get_packed_hf (ws, "If-None-Match:", "");


  if ((etag_in && !strcmp (etag_in, etag)) ||
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
      (!http_if_modified_since (ws, path, "If-Modified-Since:"))
#else
      (!http_if_modified_since (ws, st.st_mtime, "If-Modified-Since:"))
#endif
      )
    {
      strcpy_ck (head_beg, "HTTP/1.1 304 Not Modified");
      off = 0;
    }
  else if (n_ranges)
    strcpy_ck (head_beg, "HTTP/1.1 206 Partial content");
  else if (MAINTENANCE)
    strcpy_ck (head_beg, "HTTP/1.1 503 Service Temporarily Unavailable");
  else
    strcpy_ck (head_beg, "HTTP/1.1 200 OK");

  dk_free_box (etag_in);

  if (NULL != ws_check_accept (ws, ctype, head_beg, 1, off, CHARSET_NAME (charset, "ISO-8859-1")))
    {
      close (fd);
      return;
    }

  if (st.st_mtime > 0)
    {
      char dt [DT_LENGTH];
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
      file_mtime_to_dt (path, dt);
#else
      time_t_to_dt (st.st_mtime, 0, dt);
#endif
      dt_to_rfc1123_string (dt, last_modify, sizeof (last_modify));
    }
  else
    strcpy_ck (last_modify, date_now);

  if (ws->ws_method == WM_OPTIONS && ws->ws_status_code < 400)
    {
      off = 0;
      n_ranges = 0;
    }

  CATCH_WRITE_FAIL (ws->ws_session)
    {
      if (n_ranges > 1)
	send_multipart_byteranges (ws, fd, ranges, n_ranges,
	    ctype, head_beg, etag, last_modify, date_now,
	    http_server_id_string, charset);
      else
	{
	  char ranges_buffer[100];

	  ranges_buffer[0] = 0;
	  if (n_ranges == 1)
	    {
	      snprintf (ranges_buffer, sizeof (ranges_buffer),
		  "Content-Range: bytes " OFF_T_PRINTF_FMT "-" OFF_T_PRINTF_FMT "/" OFF_T_PRINTF_FMT "\r\n",
		  (OFF_T_PRINTF_DTP) ranges[0], (OFF_T_PRINTF_DTP) ranges[1], (OFF_T_PRINTF_DTP) off);
	      off = ranges[1] - ranges[0] + 1;
	    }

	  snprintf (head, sizeof (head),
	      "%s\r\n"
	      "Accept-Ranges: bytes\r\n"
	      "Content-Length: " OFF_T_PRINTF_FMT "\r\n"
	      "Content-Type: %s%s%s\r\n"
	      "ETag: %s\r\n"
	      "Last-Modified: %s\r\n"
	      "Date: %s\r\n"
	      "Server: %.1000s\r\n"
	      "Connection: %s\r\n"
	      "%s"
	      "%s"
	      "%s",
	      head_beg,
	      (OFF_T_PRINTF_DTP) off,
	      ctype, charset ? "; charset=" : "", CHARSET_NAME (charset, ""),
	      etag,
	      last_modify,
	      date_now,
	      http_server_id_string,
	      ws->ws_try_pipeline ? "Keep-Alive" : "close",
	      (MAINTENANCE) ? "Retry-After: 1800\r\n" : "",
	      ws->ws_header ? ws->ws_header : "",
	      ranges_buffer
	      );
	  SES_PRINT (ws->ws_session, head);
	  if (ws->ws_method == WM_OPTIONS && ws->ws_status_code < 400)
	    {
	      SES_PRINT (ws->ws_session, "Allow: ");
	      http_options_print (ws, ws->ws_session);
	      SES_PRINT (ws->ws_session, "\r\n");
	    }
	  SES_PRINT (ws->ws_session, "\r\n");
	}
      if (n_ranges == 1)
	LSEEK (fd, ranges[0], SEEK_SET);
      if (ws->ws_method != WM_HEAD && ws->ws_method != WM_OPTIONS)
	send_chunk (ws, fd, off);
      else if (ws->ws_method == WM_HEAD && !ws->ws_header)
	SES_PRINT (ws->ws_session, "\r\n");
      session_flush_1 (ws->ws_session);
    }
  FAILED
    {
      ws_write_failed (ws);
    }
  END_WRITE_FAIL (ws->ws_session);
  close (fd);
  log_info_http (ws, head_beg, off);
  HTTP_SET_STATUS_LINE (ws, REPLY_SENT, 1);
}


int
is_lwsp (char c)
{
  return((' ' == c || '\t' == c) ? 1 : 0);
}



#if 0
void
ws_check_in_server (dk_session_t * ses)
{
  mutex_enter (ws_queue_mtx);
  if (DKS_WS_DISCONNECTED == ses->dks_ws_status)
    {
      http_trace (("disconnect before check in %p\n", ses));
      http_n_keep_alives--; /*already counted in before ws_check_in */
      tws_disconnect_while_check_in++;
      mutex_leave (ws_queue_mtx);
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return;
    }
  if (DKS_WS_STARTED == ses->dks_ws_status)
    ses->dks_ws_status = DKS_WS_RUNNING;
  else
    tws_done_while_check_in++;
  http_trace (("checked in %p status=%d\n", ses, ses->dks_ws_status));
  add_to_served_sessions (ses);
  mutex_leave (ws_queue_mtx);
}


void
ws_check_in (dk_session_t * ses)
{
  PrpcSelfSignal ((self_signal_func) ws_check_in_server, (caddr_t) ses);
}


void
ws_start_cancel_check (ws_connection_t * ws)
{
  dk_session_t * ses = ws->ws_session;
  if (DKSESSTAT_ISSET (ses, SST_BROKEN_CONNECTION))
    return;
  if (DKS_WS_ACCEPTED == ses->dks_ws_status)
    {
      ses->dks_ws_status = DKS_WS_STARTED;
      ses->dks_ws_pending = (void*) ws;
      mutex_enter (ws_queue_mtx);
      http_n_keep_alives++;
      mutex_leave (ws_queue_mtx);
      SESSION_SCH_DATA (ses)->sio_default_read_ready_action = (io_action_func) ws_keep_alive_ready;
      http_trace (("check in %p for disconnect check\n", ses));
      ws_check_in (ses);
    }
}
#endif

static caddr_t con_dav_v_name = NULL, con_dav_v_null = NULL, con_dav_v_zero = NULL;

#define SET_SOAP_USER(ws)      if (ws->ws_map && ws->ws_map->hm_soap_uid)\
				 set_user_id (ws->ws_cli, ws->ws_map->hm_soap_uid, NULL);
#define SET_VSP_USER(ws)      if (ws->ws_map && ws->ws_map->hm_vsp_uid)\
				set_user_id (ws->ws_cli, ws->ws_map->hm_vsp_uid, NULL);


/*##**********************************************************
* Check if PL/SQL function supplied for post processing
* The name of function should be fully qualified
*************************************************************/
void
ws_post_process (ws_connection_t * ws)
{
#ifdef VIRTUAL_DIR
  static query_t * http_ppr_qr = NULL;
  caddr_t err = NULL, p_proc;
  client_connection_t * cli = ws->ws_cli;
  int rc = LTE_OK;
  query_t *proc;

  if (!http_ppr_qr)
    http_ppr_qr = sql_compile_static ("call (?) ()", bootstrap_cli, &err, SQLC_DEFAULT);
  if ((ws && !ws->ws_map) || (ws && ws->ws_map && !ws->ws_map->hm_pfn))
    return;
  if (ws->ws_map && IS_STRING_DTP (DV_TYPE_OF(ws->ws_map->hm_pfn)))
    p_proc = ws->ws_map->hm_pfn;
  else
    return;

  if (!(proc = sch_proc_def (wi_inst.wi_schema, p_proc)))
    return;
  if (proc->qr_to_recompile)
    {
      proc = qr_recompile (proc, &err);
      if (err)
	goto err_ret;
    }

  if (!sec_user_has_group (G_ID_DBA, proc->qr_proc_owner))
    return;

  p_proc = proc->qr_proc_name;

  IN_TXN;
  lt_wait_checkpoint ();
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;

  err = qr_quick_exec (http_ppr_qr, cli, NULL, NULL, 1,
      ":0", p_proc, QRP_STR);

  IN_TXN;
  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
    {
      /*log_info ("SQL ERROR in HTTP post process : State=[%s] Message=[%s]", ERR_STATE(err), ERR_MESSAGE(err));*/
      lt_rollback (cli->cli_trx, TRX_CONT);
    }
  else
    rc = lt_commit (cli->cli_trx, TRX_CONT);
  CLI_NEXT_USER (cli);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;
err_ret:
  if (err && err != (caddr_t)SQL_NO_DATA_FOUND)
    dk_free_tree (err);
#endif
}

#ifdef VIRTUAL_DIR
char *
ws_usr_qual (ws_connection_t * ws, int is_soap)
{
  user_t * usr;

  if (!is_soap &&
      (!ws || !ws->ws_map || !ws->ws_map->hm_vsp_uid || !IS_STRING_DTP (DV_TYPE_OF (ws->ws_map->hm_vsp_uid))))
    goto error_end;

  else if (is_soap &&
      (!ws || !ws->ws_map || !ws->ws_map->hm_soap_uid || !IS_STRING_DTP (DV_TYPE_OF (ws->ws_map->hm_soap_uid))))
    goto error_end;

  usr = sec_name_to_user (is_soap ? ws->ws_map->hm_soap_uid : ws->ws_map->hm_vsp_uid);
  if (usr && usr->usr_data)
    {
      char *loc = strstr (usr->usr_data, "Q ");
      if (loc)
	return (loc + 2);
    }

error_end:
    return "WS";
}
#endif

void
ws_connection_vars_clear (client_connection_t * cli)
{
  caddr_t *name, *val;
  id_hash_iterator_t it;
  if (!cli->cli_globals->ht_count) /* was if (!cli->cli_globals_dirty) ... but this is not quite correct */
    return;
  id_hash_iterator (&it, cli->cli_globals);
  while (hit_next (&it, (caddr_t *) &name, (caddr_t *) &val))
	{
	  dk_free_tree (*val);
	  dk_free_box (*name);
	}
  id_hash_clear (cli->cli_globals);
  cli->cli_globals_dirty = 0;
}

/*
When a VSP have an includes the dependency registry-setting will be a serialized array.
This serialized string must be an array with file names and time stamps,
if the includes removed the array will be empty.
*/
static int
ws_vsp_incl_changed (caddr_t dep)
{
  caddr_t * arr = NULL, ts = NULL;
  int i, l = 0;
  if (!DV_STRINGP(dep))
    return 1;
  arr = (caddr_t *) box_deserialize_string (dep, 0, 0);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr))
    goto err_end;
  l = BOX_ELEMENTS (arr);
  if (l % 2)
    goto err_end;
  for (i = 0; i < l; i += 2)
    {
      if (!DV_STRINGP (arr[i]))
	goto err_end;
      ts = file_stat (arr[i], 0);
      if (ts && DV_STRINGP(arr[i+1]) && strcmp (arr[i+1], ts))
	goto err_end;
      dk_free_box (ts); ts = NULL;
    }
  dk_free_tree ((box_t) arr);
  dk_free_box (ts);
  return 0;
err_end:
  dk_free_tree ((box_t) arr);
  dk_free_box (ts);
  return 1;
}

/*##**********************************************************
* Check if PL/SQL authentication function supplied
* then execute and expect non-zero return value
* After non-zero ret value continue with request processing
* Note: authentication function should accept realm as parameter
* No default function: if not exists - HTTP 401 code & SQL error
*************************************************************/
int
ws_auth_check (ws_connection_t * ws)
{
#ifdef VIRTUAL_DIR
  static query_t * http_auth_qr = NULL;
  caddr_t err = 0, auth_proc = NULL, auth_realm;
  local_cursor_t * lc = NULL;
  client_connection_t * cli = ws->ws_cli;
  int rc = LTE_OK, retc = 0;
  query_t * proc;
  user_t * saved_user = NULL;

  if (MAINTENANCE)
    return 1;

  if (!http_auth_qr)
    http_auth_qr = sql_compile_static ("call (?) (?)", bootstrap_cli, &err, SQLC_DEFAULT);

  if ((ws && !ws->ws_map) || (ws && ws->ws_map && !ws->ws_map->hm_afn))
    return 1;
  else if (!ws)
    return 0;

  if (ws->ws_map && IS_STRING_DTP (DV_TYPE_OF(ws->ws_map->hm_afn)))
    auth_proc = ws->ws_map->hm_afn;
  else
    return 1;

  if (ws->ws_map &&  IS_STRING_DTP (DV_TYPE_OF(ws->ws_map->hm_realm)))
    auth_realm = ws->ws_map->hm_realm;
  else
    auth_realm = (caddr_t) (ws->ws_map->hm_is_dav ? "virtuoso_dav" : "virtuoso_vsp");

  ws->ws_cli->cli_http_ses = ws->ws_strses;
  ws->ws_cli->cli_ws = ws;
  strses_flush (ws->ws_strses);

/*  if (!(proc = sch_proc_def (wi_inst.wi_schema, auth_proc)))*/
  if (!(proc = (query_t *)sch_name_to_object (wi_inst.wi_schema, sc_to_proc, auth_proc, NULL, "dba", 0)))
    {
      err = srv_make_new_error ("42000", "HT058", "The authentication procedure %s does not exist", auth_proc);
      goto error_end;
    }
  if (!sec_user_has_group (G_ID_DBA, proc->qr_proc_owner))
    {
      err = srv_make_new_error ("42000", "HT059", "The authentication procedure %s is not property of DBA group", auth_proc);
      goto error_end;
    }
  if (proc->qr_to_recompile)
    {
      proc = qr_recompile (proc, &err);
      if (err)
	goto error_end;
    }

  IN_TXN;
  lt_wait_checkpoint ();
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;

  saved_user = cli->cli_user;
  cli->cli_user = sec_name_to_user ("dba");
  err = qr_quick_exec (http_auth_qr, cli, NULL, &lc, 2,
      ":0", auth_proc, QRP_STR,
      ":1", auth_realm, QRP_STR);

  if (lc && DV_ARRAY_OF_POINTER == DV_TYPE_OF (lc->lc_proc_ret)
      && BOX_ELEMENTS ((caddr_t *)lc->lc_proc_ret) > 1)
    retc = (int) unbox (((caddr_t *)lc->lc_proc_ret)[1]);

  IN_TXN;
  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
    lt_rollback (cli->cli_trx, TRX_CONT);
  else
    rc = lt_commit (cli->cli_trx, TRX_CONT);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;

  if (rc != LTE_OK)
    {
      MAKE_TRX_ERROR (rc, err, LT_ERROR_DETAIL (cli->cli_trx));
    }

error_end:
  cli->cli_user = saved_user;
  if (err && err != (caddr_t)SQL_NO_DATA_FOUND)
    {
      /*log_info ("SQL ERROR in HTTP authentication : State=[%s] Message=[%s]", ERR_STATE(err), ERR_MESSAGE(err));*/
      ws_proc_error (ws, err);
      retc = 0;
    }

  if (err)
    dk_free_tree (err);
  if (lc)
    lc_free (lc);
  if (!retc)
    {
      ws->ws_try_pipeline = 0;
      ws_strses_reply (ws, "HTTP/1.1 401 Unauthorized");
    }
  return retc;
#else
  return 1;
#endif
}

static caddr_t
http_get_url_params (ws_connection_t * ws)
{
  char *qmark_pos = strchr (ws->ws_req_line, '?');
  if (qmark_pos)
    {
      char *end_ptr = qmark_pos + strlen (qmark_pos) - 1;

      while (isspace (*end_ptr))
	end_ptr--;
      return box_varchar_string ((db_buf_t) (qmark_pos), end_ptr - qmark_pos + 1, DV_STRING);
    }
  return NULL;
}

static void http_get_def_page (caddr_t fpath, caddr_t *ts2, caddr_t all_str, char *def_page, int def_page_len)
{
  char *tmp, *tok_s = NULL, *tok;
  caddr_t temp_def_page, temp_path = dk_alloc_box (strlen (fpath) + strlen (all_str) + 1, DV_STRING);
  caddr_t *temp_def_p;
  tok_s = NULL;
  temp_def_page = box_copy (all_str);
  temp_def_p = &temp_def_page;
  strncpy (def_page, "", def_page_len);
  tok = strtok_r (*temp_def_p, ";", &tok_s);
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
      snprintf (temp_path, box_length (temp_path), "%s%s", fpath, tok);
      *ts2 = file_stat (temp_path, 3);
      if (*ts2)
	{
	   strncpy (def_page, tok, def_page_len);
	   dk_free_box (temp_def_page);
	   dk_free_box (temp_path);
	   return;
	}
      tok = strtok_r (NULL, ";", &tok_s);
    }
  dk_free_box (temp_def_page);
  if (temp_path)
    dk_free_box (temp_path);
}

/*##**********************************************************
* This check if RDF data is asked and try to locate in the repository
*
*************************************************************/
int http_check_rdf_accept = 1;

static int
ws_check_rdf_accept (ws_connection_t *ws)
{
#ifdef VIRTUAL_DIR
  static query_t * qr = NULL;
  client_connection_t * cli = ws->ws_cli;
  query_t * proc;
  caddr_t err = NULL;
  int rc = LTE_OK, retc = 0;
  local_cursor_t * lc = NULL;
  char * accept;

  if (!http_check_rdf_accept || ws->ws_status_code != 404)
    return 0;
  accept = ws_header_field (ws->ws_lines, "Accept:", NULL);
  if (!ws || !ws->ws_map || !accept)
    return 0;
  if (NULL == strstr (accept, "application/rdf+xml") && NULL == strstr (accept, "text/rdf+n3") && NULL == strstr (accept, "text/turtle"))
    return 0;

  if (!(proc = (query_t *)sch_name_to_object (wi_inst.wi_schema, sc_to_proc, "DB.DBA.HTTP_RDF_ACCEPT", NULL, "dba", 0)))
    {
      err = srv_make_new_error ("42000", "HT058", "The stored procedure " "DB.DBA.HTTP_RDF_ACCEPT" " does not exist");
      goto error_end;
    }
  if (!sec_user_has_group (G_ID_DBA, proc->qr_proc_owner))
    {
      err = srv_make_new_error ("42000", "HT059", "The stored procedure " "DB.DBA.HTTP_RDF_ACCEPT" "is not property of DBA group");
      goto error_end;
    }
  if (proc->qr_to_recompile)
    {
      proc = qr_recompile (proc, &err);
      if (err)
	goto error_end;
    }
  if (!qr)
    qr = sql_compile_static ("DB.DBA.HTTP_RDF_ACCEPT (?, ?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);

  IN_TXN;
  lt_wait_checkpoint ();
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;

  err = qr_quick_exec (qr, cli, NULL, &lc, 4,
      ":0", ws->ws_path_string, QRP_STR,
      ":1", ws->ws_map->hm_l_path, QRP_STR,
      ":2", box_copy_tree (ws->ws_lines), QRP_RAW,
      ":3", (ptrlong) http_check_rdf_accept, QRP_INT
      );

  if (!err && lc && DV_ARRAY_OF_POINTER == DV_TYPE_OF (lc->lc_proc_ret)
      && BOX_ELEMENTS ((caddr_t *)lc->lc_proc_ret) > 1)
    retc = (int) unbox (((caddr_t *)lc->lc_proc_ret)[1]);

  IN_TXN;
  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
    lt_rollback (cli->cli_trx, TRX_CONT);
  else
    rc = lt_commit (cli->cli_trx, TRX_CONT);
  CLI_NEXT_USER (cli);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;

error_end:
  if (err && err != (caddr_t)SQL_NO_DATA_FOUND)
    {
      ws_proc_error (ws, err);
      retc = 1;
    }
  if (err)
    dk_free_tree (err);
  if (lc)
    lc_free (lc);
  return retc;
#endif
}

#define IS_DAV_METHOD(ws) (IS_DAV_DOMAIN(ws, "")  && 0 != strstr ("PROPFIND PROPPATCH LOCK UNLOCK COPY MOVE MKCOL", ws->ws_method_name))

int soap_get_opt_flag (caddr_t * opts, char *opt_name);

void
ws_request (ws_connection_t * ws)
{
  static query_t * http_call = NULL;

  char p_name [PATH_ELT_MAX_CHARS + 20];
  long start;
  char * path1;
  caddr_t err;
  int rc;
  int dav_method;
  client_connection_t * cli;
#ifdef BIF_XML
  caddr_t soap_method;
  int soap_version;
#endif
  int deflt, inln;
  int is_dsl, is_wsdl, is_vsmx, is_http_binding;
  int is_physical_soap, previous_http_status = 0;
  int is_soap_mime_att = 0;

request_do_again:
  start = 0;
  err = NULL;
  rc = LTE_OK;
  dav_method = 0;
  cli = ws->ws_cli;
#ifdef BIF_XML
  soap_method = NULL;
  soap_version = 1;
#endif
  deflt = 0;
  inln = 0;
  is_dsl = 0;
  is_wsdl = 0;
  is_vsmx = 0;
  is_http_binding = 0;
  is_physical_soap = 0;
  cli_set_start_times (cli);
  cli->cli_terminate_requested = 0;

  p_name[0] = 0;
  ws->ws_cli->cli_http_ses = ws->ws_strses;
  ws->ws_cli->cli_ws = ws;
  ws->ws_flushed = 0;
  ws->ws_ignore_disconnect = 0;
  CHUNKED_STATE_CLEAR (ws);

  if (MAINTENANCE)
    {
      int print_slash;
      size_t alen;
      caddr_t apage;
#ifdef _IMSG
      if (ws->ws_port > 0) /* if POP3, IMAP, NNTP or FTP just return */
	goto do_file;
#endif
      print_slash = (www_maintenance_page[0] != '/');
      alen = strlen (www_maintenance_page) + print_slash + 1;
      apage = dk_alloc_box (alen, DV_STRING);

      snprintf (apage, alen, "%s%s", (print_slash ? "/" : ""), www_maintenance_page);
      apage[alen-1] = '\0';
      ws->ws_file = apage;
      goto do_file;
    }

  /* all are set to NULL at the end of request;
   * connection_set (cli, con_dav_v_name, NULL);*/
  if (!http_call)
    {
      http_call = sql_compile_static ("call (?) (?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
    }
  strses_flush (ws->ws_strses);
  IN_TXN;
  if (!cli->cli_trx->lt_threads)
    lt_wait_checkpoint ();
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;


#ifdef _IMSG
  if (http_ses_trap &&
      (!pop3_port || ws->ws_port != pop3_port) &&
      (!nntp_port || ws->ws_port != nntp_port) &&
      (!ftp_port || ws->ws_port != ftp_port))
#else
  if (http_ses_trap)
#endif
    {
      /* --ches-- */
      char *uri_begin;
      char *last_slash;
      caddr_t save_history_name;
      caddr_t vdir = NULL;
      caddr_t err = NULL;
      /* Detect virtual dir directory */
      /* Assume first word is method name */
      if (!ws->ws_req_line)
	{
	  err = srv_make_new_error ("42000", "HTL01", "The request line is empty.");
	  goto rec_err_end;
	}
      uri_begin = strchr(ws->ws_req_line, ' ');
      if (NULL == uri_begin)
	{
	  err = srv_make_new_error ("42000", "HTL01", "The request line does not contain method name: %.1000s", ws->ws_req_line);
	  goto rec_err_end;
	}
      while (('\0' != uri_begin[0]) && strchr (" \t", uri_begin[0]))
	uri_begin++;
      vdir = box_dv_short_string (uri_begin);
      last_slash = strrchr(vdir, '/');
      if (NULL == last_slash)
	{
	  err = srv_make_new_error ("42000", "HTL01", "No virtual directory name found in the request line %.1000s", ws->ws_req_line);
	  dk_free_box (vdir);
	  goto rec_err_end;
	}
      /* Get special registry item value */
      IN_TXN;
      save_history_name = registry_get("__save_http_history");
      LEAVE_TXN;
      if ((DV_STRING == DV_TYPE_OF (save_history_name)) &&
	  ((0 == strncmp(vdir, save_history_name, (box_length (save_history_name) - 1)) &&
	    '/' == vdir[box_length(save_history_name) - 1]) || !strcmp (save_history_name, "/")))
	{
	  static query_t *stmt = NULL;
	  if (!stmt)
	    {
	      stmt = sql_compile ("DB.DBA.sys_save_http_history (?, ?)", ws->ws_cli, &err, SQLC_DEFAULT);
	      if (err)
		goto rec_err_end;
	    }

	  err = qr_quick_exec (stmt, ws->ws_cli, NULL, NULL, 2,
	      ":0", save_history_name, QRP_STR,
	      ":1", last_slash, QRP_STR);

	  IN_TXN;
	  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
	    lt_rollback (cli->cli_trx, TRX_CONT);
	  else
	    rc = lt_commit (cli->cli_trx, TRX_CONT);
	  lt_threads_set_inner (cli->cli_trx, 1);
	  LEAVE_TXN;
	  if (rc != LTE_OK)
	    {
	      MAKE_TRX_ERROR (rc, err, LT_ERROR_DETAIL (cli->cli_trx));
	    }
	}
      dk_free_box (save_history_name);
      dk_free_box (vdir);
rec_err_end:
      if (err && err != (caddr_t) SQL_NO_DATA_FOUND)
	{
	  log_warning("Error [%s] : %s", ERR_STATE(err), ERR_MESSAGE(err));
	  dk_free_tree(err);
	}
    }

#ifdef VIRTUAL_DIR
  path1 = (ws->ws_p_path && BOX_ELEMENTS (ws->ws_p_path) )? ws->ws_p_path[0] : NULL;
#else
  path1 = (ws->ws_path && BOX_ELEMENTS (ws->ws_path) )? ws->ws_path[0] : NULL;
#endif
  /* ws_start_cancel_check (ws); */
  if (!path1)
    path1 = "HTTP__DEFAULT";


  if (ws->ws_path_string && ws_cache_check (ws))
    {
      goto error_in_procedure;
    }


#ifdef BIF_XML
  is_physical_soap = (path1 && !strcmp (path1, "SOAP"));
  soap_method = ws_mime_header_field (ws->ws_lines, "SOAPMethodName", NULL, 0);
  if (!soap_method)
    {
      caddr_t ctype = ws_mime_header_field (ws->ws_lines, "Content-Type", NULL, 0);
      soap_method = ws_mime_header_field (ws->ws_lines, "SOAPAction", NULL, 0);
      if (soap_method)
	soap_version = 11;
      else if (ctype && !strcmp (ctype, SOAP_CTYPE_12)) /*application/soap+xml*/
	{
	  soap_method = ws_mime_header_field (ws->ws_lines, "Content-Type", "action", 0);
	  if (!soap_method) soap_method = box_dv_short_string ("");
	  soap_version = 12;
	}
      if (ctype && !strcmp (ctype, "Multipart/Related")) /* SwA */
	is_soap_mime_att = 1;
      dk_free_box (ctype);
    }
  if (soap_method && (is_physical_soap || is_soap_mime_att))
    {
      if (prof_on)
	{
	  start = get_msec_real_time ();
	  strncpy (p_name, soap_method ? soap_method : "SOAP", sizeof (p_name) - 1);
	  p_name[sizeof (p_name) - 1] = 0;
	}
      SET_SOAP_USER (ws);
      ws->ws_ignore_disconnect = 1;
      if (soap_get_opt_flag ((ws && ws->ws_map ? ws->ws_map->hm_soap_opts : NULL), "WS-RP") ||
	  soap_get_opt_flag ((ws && ws->ws_map ? ws->ws_map->hm_soap_opts : NULL), "WS-SEC"))
	{
	  deflt = 1;
	  strcpy_ck (p_name, "DB.DBA.WS_SOAP"); /* the SOAP PL wrapper,
						 this it to extend with WS-Routing, WS-Referral & WS-Security */
	  dk_free_box (soap_method);
	  soap_method = NULL;
	  goto vsmx_start;
	}
      err = ws_soap (ws, soap_version, soap_method); /* should take hp_soap_uid inside */
      dk_free_box (soap_method);
      soap_method = NULL;
    }
  else if (ws->ws_p_path &&
      (
      (BOX_ELEMENTS (ws->ws_p_path) == 2 &&
      !strcmp (ws->ws_p_path[0], "SOAP") &&
      ((is_dsl = !strcmp (ws->ws_p_path[1], "services.xml")) ||
       (is_wsdl = !strcmp (ws->ws_p_path[1], "services.wsdl")) ||
       (is_wsdl = !strncmp (ws->ws_p_path[1], "services20.", 11)) || /* .xml, .rdf, .n3 goes here */
       (is_vsmx = !strcmp (ws->ws_p_path[1], "services.vsmx")))) ||
      (BOX_ELEMENTS (ws->ws_p_path) > 2 &&
       !strcmp (ws->ws_p_path[0], "SOAP") &&
       (is_http_binding = !strcmp (ws->ws_p_path[1], "Http")))
      ))
    {
      SET_SOAP_USER (ws);
      if (is_dsl)
	err = ws_soap_sdl_services (ws);
      else if (is_wsdl)
	err = ws_soap_wsdl_services (ws, ws->ws_p_path[1]);
      else if (is_vsmx)
	{
	  deflt = 1;
	  strcpy_ck (p_name, "DB.DBA.SOAP_VSMX");
	  goto vsmx_start;
	}
      else if (is_http_binding)
	err = ws_soap_http (ws);
      else
	err = srv_make_new_error ("42000", "HT051", "Invalid SOAP URL");
    }
  else if (is_physical_soap &&
      soap_get_opt_flag ((ws && ws->ws_map ? ws->ws_map->hm_soap_opts : NULL), "XML-RPC"))
    {
      deflt = 1;
      strcpy_ck (p_name, "DB.DBA.XMLRPC_SERVER");
      goto vsmx_start;
    }
  else
#endif
    if (IS_DAV_DOMAIN(ws, path1) || WM_IS_URIQA(ws->ws_method))
    {
#ifdef BIF_XML
      if (prof_on)
	{
	  char * pmethod = NULL;
	  size_t method_len = 0;
	  pmethod = strchr (ws->ws_req_line, '\x20');
	  if (pmethod)
	    {
	      method_len = pmethod - ws->ws_req_line;
	      strncpy (p_name, ws->ws_req_line, method_len);
	      p_name [method_len] = 0;
	    }
	  start = get_msec_real_time ();
	}
run_in_dav:
      dav_method = 1;
      err = ws_dav (ws, http_call);
#endif
    }
  else
#ifdef WM_ERROR
    if (ws->ws_method != WM_ERROR)
#endif
    {
      if (!strstr (path1, "INLINEFILE"))
#ifdef VIRTUAL_DIR
	if (!ws->ws_proxy_request && ws->ws_p_path_string && box_length (ws->ws_p_path_string) < sizeof (p_name) - 10)
	  snprintf (p_name, sizeof (p_name), "%s.%s.%s", ws_usr_qual (ws, 0), WS_USER_NAME (ws),  ws->ws_p_path_string);
#else
	if (!ws->ws_proxy_request && ws->ws_path_string && box_length (ws->ws_path_string) < sizeof (p_name) - 10)
	  snprintf (p_name, sizeof (p_name), "WS.WS.%s", ws->ws_path_string);
#endif
	else
	  {
	    strcpy_ck (p_name, "WS.WS.DEFAULT");
	    deflt = 1;
	  }
      else
	{ /* the INLINEFILE handler */
	  caddr_t text = ws_get_param (ws, "VSP");
	  if (!text)
	    {
	      err = srv_make_new_error ("22023", "HT005", "No VSP parameter for /INLINEFILE");
	      goto error_in_procedure;
	    }

	  dk_free_box (ws->ws_path_string);
	  ws->ws_path_string = box_copy (text);
#ifdef VIRTUAL_DIR
	  dk_free_box (ws->ws_p_path_string); ws->ws_p_path_string = NULL;
	  dk_free_tree ((box_t) ws->ws_p_path); ws->ws_p_path = NULL; path1 = "";
	  ws_set_phy_path (ws, 0, text);
#endif
	  snprintf (p_name, sizeof (p_name), "%s.%s.%s", ws_usr_qual (ws, 0), WS_USER_NAME (ws), text);
	  inln = 1;
	  if (IS_DAV_DOMAIN(ws, path1))
	    goto run_in_dav;
	}
#ifdef VIRTUAL_DIR
      if (!deflt && !inln) /* virtual directories features dir index & default page */
	{
	  caddr_t ts_probe = NULL, dir_probe = NULL;
	  char *sl = NULL;
	  caddr_t fpath = dk_alloc_box (strlen (www_root) + strlen (ws->ws_p_path_string) +
	      ((ws->ws_map && ws->ws_map->hm_def_page) ? strlen (ws->ws_map->hm_def_page) : 0) + 1, DV_C_STRING);
	  snprintf (fpath, box_length (fpath), "%s%s", www_root, ws->ws_p_path_string);
	  ts_probe = file_stat (fpath, 3); /* is this a file */
	  dir_probe = file_stat (fpath, 0); /* is this a directory */
	  if (!ts_probe)
	    {
	      caddr_t ts2 = NULL;
	      char def_page [200];

	      def_page[0] = 0;
	      if (ws->ws_map && ws->ws_map->hm_def_page && dir_probe)
		{
		  int plen = ws->ws_path_string ? (int) strlen (ws->ws_path_string) : 0;
		  if (plen > 0 && ws->ws_path_string [plen - 1] != '/')
		    {
		      /* If the requested link is directory but no slash at the end - redirect it
		       otherwise all relative links will be broken */
		      caddr_t url_pars = http_get_url_params (ws);
		      int url_pars_len = url_pars ? box_length (url_pars) - 1 : 0;
		      caddr_t loc = dk_alloc_box_zero (plen + url_pars_len + 14, DV_LONG_STRING);
		      ws->ws_status_line = box_dv_short_string ("HTTP/1.1 301 Moved Permanently");
		      ws->ws_status_code = 301;
		      snprintf (loc, box_length (loc), "Location: %s/%s\r\n", ws->ws_path_string, url_pars ? url_pars : "");
		      ws->ws_header = loc;
		      dk_free_box (url_pars);
		      dk_free_box (dir_probe); dk_free_box (fpath);
		      goto error_in_procedure;
		    }

		  sl = strrchr (fpath, '/');
		  if (sl)
		    {
		      *(sl + 1) = 0;
		      http_get_def_page (fpath, &ts2, ws->ws_map->hm_def_page, def_page, sizeof (def_page));
		      strcat_box_ck (fpath, def_page);
		    }
		}
	      if (!ts2 && dir_probe && ws->ws_map && ws->ws_map->hm_browseable)
		{
		  strcpy_ck (p_name, "WS.WS.DIR_INDEX_XML");
		  deflt = 1;
		}
	      else
		{
		  dk_free_box (ws->ws_p_path_string);
		  ws->ws_p_path_string = box_dv_short_string (fpath + strlen (www_root));
		  /* change the logical path accordingly if default page is set */
		  if (ts2)
		    {
		      caddr_t l_path = dk_alloc_box (box_length (ws->ws_path_string) +
			  strlen (ws->ws_map->hm_def_page), DV_STRING);
		      if (0 != def_page[0])
			{
			  dk_free_box (ts2);
			  http_get_def_page (fpath, &ts2, ws->ws_map->hm_def_page, def_page, sizeof (def_page));
			}
		      snprintf (l_path, box_length (l_path), "%s%s", ws->ws_path_string, def_page);
		      dk_free_tree (ws->ws_path_string);
		      ws->ws_path_string = l_path;
		    }

		  deflt = 0;
#ifdef VIRTUAL_DIR
		  if (box_length (ws->ws_p_path_string) < sizeof (p_name) - 10)
		    snprintf (p_name, sizeof (p_name), "%s.%s.%s", ws_usr_qual (ws, 0), WS_USER_NAME (ws),  ws->ws_p_path_string);
#else
		  if (box_length (ws->ws_path_string) < sizeof (p_name) - 10)
		    snprintf (p_name, sizeof (p_name), "WS.WS.%s", ws->ws_path_string);
#endif
		  else
		    {
		      strcpy_ck (p_name, "WS.WS.DEFAULT");
		      deflt = 1;
		    }
		}
	      if (ts2)
		dk_free_box (ts2);
	    }
	  else
	    {
	      if (!ws->ws_map || !ws->ws_map->hm_vsp_uid)
		{
		  strcpy_ck (p_name, "WS.WS.DEFAULT");
		  deflt = 1;
		}
	    }
	  dk_free_box (ts_probe);
	  dk_free_box (dir_probe);
	  dk_free_box (fpath);
	}
#endif
      if (!sch_proc_def (isp_schema (NULL), p_name)
	  || !ws->ws_map
	  || !ws->ws_map->hm_vsp_uid)
	{
	  strcpy_ck (p_name, "WS.WS.DEFAULT");
	  deflt = 1;
	}
      else
	if (!deflt)
	  {
	    caddr_t ts;
	    caddr_t complete_name =
		dk_alloc_box (strlen (ws->ws_p_path_string) + strlen (www_root) + 2, DV_C_STRING);
	    caddr_t ts1, dep_name, dep = NULL;

	    dep_name = dk_alloc_box_zero (strlen (ws->ws_p_path_string) + MAX_NAME_LEN + 11, DV_C_STRING);
	    snprintf (dep_name, box_length (dep_name), "__depend_%.*s_%s", MAX_NAME_LEN, WS_USER_NAME (ws), ws->ws_p_path_string);

	    IN_TXN;
	    ts1 = registry_get (ws->ws_p_path_string);
	    dep = registry_get (dep_name);
	    LEAVE_TXN;
	    strcpy_box_ck (complete_name, www_root);
	    strcat_box_ck (complete_name, ws->ws_p_path_string);
	    ts = file_stat (complete_name, 0);
	    dk_free_box (complete_name);
	    dk_free_box (dep_name);
	    if ((ts && ts1 && strcmp (ts, ts1)) || !ts1 || !ts || (dep && ws_vsp_incl_changed (dep)))
	      {
		strcpy_ck (p_name, "WS.WS.DEFAULT");
		deflt = 1;
	      }
	    if (ts)
	      dk_free_box (ts);
	    if (ts1)
	      dk_free_box (ts1);
	    dk_free_box (dep);
	  }

vsmx_start:

#ifdef _IMSG
      if (pop3_port && ws->ws_port == pop3_port)
	strcpy_ck (p_name, "WS.WS.POP3_SRV");

      if (nntp_port && ws->ws_port == nntp_port)
	strcpy_ck (p_name, "WS.WS.NN_SRV");

      if (ftp_port && ws->ws_port == ftp_port)
	strcpy_ck (p_name, "WS.WS.FTP_SRV");
#endif

      if (!deflt)
	{
	  SET_VSP_USER (ws);
	}


      start = prof_on ? get_msec_real_time () : 0;
      if (DO_LOG(LOG_EXEC))
	{
	  LOG_GET;
	  log_info ("EXEC_3 %s %s Exec vsp %.*s", user, from, LOG_PRINT_STR_L, p_name[0] != 0 ? p_name :"");
	}

      err = qr_quick_exec (http_call, ws->ws_cli, NULL, NULL, 4,
			   ":0", p_name, QRP_STR,
			   ":1", box_copy_tree ((box_t) ws->ws_path), QRP_RAW,
			   ":2", ws->ws_params, QRP_RAW,
			   ":3", box_copy_tree ((box_t) ws->ws_lines), QRP_RAW);

      ws->ws_params = NULL;
    }
error_in_procedure:
  if (!err && cli_check_ws_terminate (cli))
    {
      err = srv_make_new_error ("42000", "HT062", "HTTP Client has forcibly disconnected");
    }

  if (NULL != ws->ws_store_in_cache)
    {
      ws_cache_store (ws, (NULL == err));
    }

  IN_TXN;
  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
  {
    /*log_info ("SQL ERROR in HTTP : State=[%s] Message=[%s]", ERR_STATE(err), ERR_MESSAGE(err));*/
    lt_rollback (cli->cli_trx, TRX_CONT);
  }
  else
    rc = lt_commit (cli->cli_trx, TRX_CONT);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;
  if (prof_on && start)
    prof_exec (NULL, p_name, get_msec_real_time () - start, PROF_EXEC | (err != NULL ? PROF_ERROR : 0));
  if (rc != LTE_OK)
    {
      MAKE_TRX_ERROR (rc, err, LT_ERROR_DETAIL (cli->cli_trx));
    }
  if (err && err != (caddr_t)SQL_NO_DATA_FOUND)
    {
      if (!ws->ws_status_line && 0 != strncmp (ERR_STATE (err), "VSPRT", 5))
	{
	  ws->ws_status_line = box_dv_short_string ("HTTP/1.1 500 Internal Server Error");
	  ws->ws_status_code = 500;
	}
      ws_proc_error (ws, err);
    }
#ifdef WM_ERROR
  else if (ws->ws_method == WM_ERROR && !ws->ws_status_line)
    {
      tws_bad_request++;
      ws->ws_status_line = box_dv_short_string ("HTTP/1.1 501 Method Not Implemented");
      ws->ws_status_code = 501;
      ws->ws_try_pipeline = 0;
    }
#endif
do_file:
  if (!ws->ws_flushed && ws->ws_file)
    ws_file (ws);

  /* 404 */
#ifdef VIRTUAL_DIR
  if (!previous_http_status && ws->ws_status_code > 399 && ws->ws_status_code < 999 && ws->ws_map)
    {
      char page_opt_name[3 + 5 + 1];
      char *text = NULL;

      if (THR_TMP_POOL)
	{
	  MP_DONE ();
	  log_error ("non-empty MP after %s", ws->ws_path_string ? ws->ws_path_string : "<no-url>");
	}
      THR_DBG_PAGE_CHECK;

      if (!ws_check_rdf_accept (ws) && !IS_DAV_METHOD (ws)) /* check if WebDAV */
	{
	  snprintf (page_opt_name, sizeof (page_opt_name), "%3d_page", ws->ws_status_code);
	  if (NULL != (text = ws_get_opt (ws->ws_map->hm_opts, page_opt_name, NULL)))
	    {
	      char *lpath = ws->ws_map->hm_l_path;
	      int lpath_len = (int) strlen (lpath);

	      previous_http_status = ws->ws_status_code;

	      ws_clear (ws, 1);
	      ws->ws_in_error_handler = 1;

	      dk_free_box (ws->ws_path_string);
	      if (text[0] != '/')
		{
		  ws->ws_path_string = dk_alloc_box (strlen (text) + lpath_len + 2, DV_SHORT_STRING);
		  if (lpath_len > 0 && lpath[lpath_len - 1] == '/')
		    snprintf (ws->ws_path_string, box_length (ws->ws_path_string), "%s%s", lpath, text);
		  else
		    snprintf (ws->ws_path_string, box_length (ws->ws_path_string), "%s/%s", lpath, text);
		}
	      else
		{
		  ws->ws_path_string = box_copy (text);
		}
	      dk_free_box (ws->ws_p_path_string); ws->ws_p_path_string = NULL;
	      dk_free_tree ((box_t) ws->ws_p_path); ws->ws_p_path = NULL; path1 = "";
	      ws_set_phy_path (ws, 0, ws->ws_path_string);

	      /*ws_connection_vars_clear (cli);*/
	      if (err && err != (caddr_t)SQL_NO_DATA_FOUND)
		{
		  ws->ws_params = (caddr_t *) list (4,
		      box_dv_short_string ("__SQL_STATE"), box_copy (ERR_STATE (err)),
		      box_dv_short_string ("__SQL_MESSAGE"), box_copy (ERR_MESSAGE (err)));
		}
	      else
		ws->ws_params = (caddr_t *) dk_alloc_box (0, DV_ARRAY_OF_POINTER);
	      strses_flush (ws->ws_strses);
	      goto request_do_again;
	    }
	}
    }
#endif

  if (!ws->ws_flushed || !IS_CHUNKED_OUTPUT (ws))
    ws_post_process (ws);

  if (ws->ws_flushed)
    {
      if (IS_CHUNKED_OUTPUT (ws))
	{
	  char tmp[20];
	  volatile int len = strses_length (ws->ws_strses);
	  CATCH_WRITE_FAIL (ws->ws_session)
	    {
	      if (len > 0)
		{
		  snprintf (tmp, sizeof (tmp), "%x\r\n", len);
		  SES_PRINT (ws->ws_session, tmp);
		  strses_write_out (ws->ws_strses, ws->ws_session);
		  SES_PRINT (ws->ws_session, "\r\n");
		}
	      SES_PRINT (ws->ws_session, "0\r\n\r\n");
	      session_flush_1 (ws->ws_session);
	    }
	  FAILED
	    {
	      ws_write_failed (ws);
	    }
	  END_WRITE_FAIL (ws->ws_session);
	  CHUNKED_STATE_CLEAR(ws);
	}

      strses_flush (ws->ws_strses);
    }
/* XXX: moved before post processing hook
  else if (ws->ws_file)
    ws_file (ws);
*/
  else if (! (ws->ws_status_line && strstr (ws->ws_status_line, REPLY_SENT)) &&
      dav_method && err && err != (caddr_t)SQL_NO_DATA_FOUND)
    ws_strses_reply (ws, "HTTP/1.1 500 Internal Server Error");
#ifdef _IMSG
  else if (! (ws->ws_status_line && strstr (ws->ws_status_line, REPLY_SENT)) &&
      ((!pop3_port || ws->ws_port != pop3_port) &&
       (!nntp_port || ws->ws_port != nntp_port) &&
       (!ftp_port || ws->ws_port != ftp_port)))
    ws_strses_reply (ws, "HTTP/1.1 200 OK");
#else
  else if (! (ws->ws_status_line && strstr (ws->ws_status_line, REPLY_SENT)))
    ws_strses_reply (ws, "HTTP/1.1 200 OK");
#endif
  pop_user_id (ws->ws_cli); /* set back original user id */

  if (THR_TMP_POOL)
    {
      MP_DONE ();
      log_error ("non-empty MP after %s", ws->ws_path_string ? ws->ws_path_string : "<no-url>");
    }
  THR_DBG_PAGE_CHECK;
  /* instead of connection_set (cli, con_dav_v_name, NULL);
   * we'll clear all connection settings if connection is dirty */
  ws_connection_vars_clear (cli);
  cli_free_dae (cli);

  dk_free_tree ((caddr_t) err);
  dk_free_tree ((box_t) ws->ws_lines);
  ws->ws_lines = NULL;
  dk_free_tree ((box_t) ws->ws_path);
  ws->ws_path = NULL;
  dk_free_box (soap_method);
}


caddr_t
http_client_ip (session_t * ses)
{
  char buf[16];
  tcpses_print_client_ip (ses, &(buf[0]), sizeof (buf));
  return (box_dv_short_string (buf));
}

extern db_activity_t http_activity;
#define IS_GATEWAY_PROXY(ws) (ws->ws_forward || \
    (http_proxy_address && (ws) && (ws)->ws_client_ip && !strcmp ((ws)->ws_client_ip, http_proxy_address)))

void
http_set_client_address (ws_connection_t * ws)
{
  caddr_t xfwd;
  if (!IS_GATEWAY_PROXY (ws))
    return;
  if (ws && ws->ws_lines && NULL != (xfwd = ws_mime_header_field (ws->ws_lines, "X-Forwarded-For", NULL, 1)))
    {
      dk_free_box (ws->ws_client_ip);
      ws->ws_client_ip = xfwd;
      ws->ws_forward = 1;
    }
}

void
ws_read_req (ws_connection_t * ws)
{
  char line [10000];
  timeout_t timeout;
  acl_hit_t * hit = NULL;
  dk_session_t * ses = ws->ws_session;
  ws_clear (ws, 0);
  ws->ws_client_ip = http_client_ip (ws->ws_session->dks_session);

  if (!_thread_sched_preempt)
    {
      timeout = dks_fibers_blocking_read_default_to;
      ses->dks_read_block_timeout = timeout;
    }

  if (SESSION_SCH_DATA (ws->ws_session)->sio_is_served != -1)
    GPF_T1 ("ws session should not be in the served pool when read");

  CATCH_READ_FAIL (ses)
    {
      int len;
      int len2;
      caddr_t lbuf = NULL;
      caddr_t lbuf2 = NULL;
      dk_set_t lines = NULL;

#ifdef _IMSG
      if ((!pop3_port || ws->ws_port != pop3_port)
	  && (!nntp_port || ws->ws_port != nntp_port)
	  && (!ftp_port || ws->ws_port != ftp_port))
	{
#endif
	  for (;;)
	    {
	      len = 0;
	      len = ws_read_line (ws, line, sizeof (line));
	      http_trace (("%s", line));
	      if (!ws->ws_req_line)
		{
		  if (len > 2)
		    {
		      ws->ws_req_line = box_line (line, len);
		      tws_requests++;
		    }
		  else
		    {
		      ws->ws_try_pipeline = 1;
		      goto end_req;
		      /*  continue; */
		    }
		}

	      if (len <= 2)
		break;
	      if (is_lwsp (*line) && lines != NULL)
		{
		  lbuf = (caddr_t) dk_set_pop (&lines);

		  len2 = box_length (lbuf)-3;
		  lbuf2 = dk_alloc_box (len+len2+1, DV_SHORT_STRING);

		  memcpy (lbuf2, lbuf, len2);
		  memcpy (lbuf2 + len2, line, len);
		  /* IvAn/DkAllocBoxZero/010106 Bug fixed: last element should be set to zero, not one-after-end */
		  lbuf2[len + len2] = '\0';

		  dk_set_push (&lines, lbuf2);
		  dk_free_box (lbuf);
		}
	      else
		{
		  dk_set_push (&lines, box_line (line, len));
		}
	    }
	  ws->ws_lines = (caddr_t*) list_to_array (dk_set_nreverse (lines));
	  http_set_client_address (ws);
	  if (0 == ws_check_acl (ws, &hit))
	    {
	      ws->ws_try_pipeline = 0;
	      ws_strses_reply (ws, hit ? "HTTP/1.1 509 Bandwidth Limit Exceeded" : "HTTP/1.1 403 Forbidden");
	      goto end_req;
	    }
	  if (0 == ws_check_caps (ws))
	    {
	      ws->ws_try_pipeline = 0;
	      goto end_req;
	    }
	  if (ws_path_and_params (ws))
	    goto end_req;
    if (0 == ws_check_acl (ws, &hit))
      {
        ws->ws_try_pipeline = 0;
        ws_strses_reply (ws, hit ? "HTTP/1.1 509 Bandwidth Limit Exceeded" : "HTTP/1.1 403 Forbidden");
        goto end_req;
      }
#ifdef _IMSG
	}
#endif
      if (ws_auth_check (ws))
	{
	  memset (&ws->ws_cli->cli_activity, 0, sizeof (db_activity_t));
	ws_request (ws);
	  cli_set_slice (ws->ws_cli, NULL, QI_NO_SLICE, NULL);
	  da_add (&http_activity, &ws->ws_cli->cli_activity);
	}
#ifdef _IMSG
      /* clear POP3, IMAP, NNTP & FTP port after work is done */
      ws->ws_port = 0;
#endif
    }
  FAILED
    {
      ACL_HIT_RESTORE (hit);
    }
  END_READ_FAIL (ws->ws_session);
end_req:
  ws_connection_vars_clear (ws->ws_cli); /* can have connection vars set from authentication hook */
}


int
ws_pipeline_ready (ws_connection_t * ws)
{
  timeout_t zero_timeout;
  if (ws->ws_session->dks_in_fill > ws->ws_session->dks_in_read)
    return 1;
  zero_timeout.to_sec = 0;
  zero_timeout.to_usec = 0;
  tcpses_is_read_ready (ws->ws_session->dks_session, &zero_timeout);
  if (SESSTAT_ISSET (ws->ws_session->dks_session, SST_TIMED_OUT))
    {
      SESSTAT_CLR (ws->ws_session->dks_session, SST_TIMED_OUT);
      return 0;
    }
  return 1;
}


int
ws_can_try_pipeline (ws_connection_t * ws)
{
  if (DKSESSTAT_ISSET (ws->ws_session, SST_OK)
      && !DKSESSTAT_ISSET (ws->ws_session, SST_BROKEN_CONNECTION))
    {
      if (ws->ws_try_pipeline)
	return 1;
    }
  return 0;
}


void
ws_switch_to_keep_alive (ws_connection_t * ws)
{
  dk_session_t * ses = ws->ws_session;
  mutex_enter (ws_queue_mtx);
  if (DKS_WS_RUNNING == ses->dks_ws_status)
    ws->ws_session->dks_ws_status = DKS_WS_KEEP_ALIVE;
  mutex_leave (ws_queue_mtx);
}


void
ws_serve_connection (ws_connection_t * ws)
{
  int n_consec = 0;
  int try_pipeline = 0;
  dk_session_t * volatile ses = ws->ws_session;

#ifdef _SSL
  if (ws->ws_ssl_ctx)
    {
      SSL_CTX * ssl_ctx = ws->ws_ssl_ctx;
      int dst = 0;
      int ssl_err = 0;
      timeout_t to = {100, 0};
      SSL * new_ssl = NULL;

      if (NULL != tcpses_get_ssl (ses->dks_session))
	sslses_to_tcpses (ses->dks_session);
      to = ses->dks_read_block_timeout;
      session_set_control (ses->dks_session, SC_TIMEOUT, (char *)(&to), sizeof (timeout_t));
      dst = tcpses_get_fd (ses->dks_session);
      new_ssl = SSL_new (ssl_ctx);
      SSL_set_fd (new_ssl, dst);
      ssl_err = SSL_accept (new_ssl);
      if (ssl_err == -1)
	{
	  ERR_print_errors_fp (stderr);
	  SSL_free (new_ssl);
	  ses->dks_ws_status = DKS_WS_DISCONNECTED;
	  goto check_state;
	}
      else
	{
	  SSL_set_verify_result(new_ssl, X509_V_OK);
	  tcpses_to_sslses (ses->dks_session, (void *)(new_ssl));
	}
    }
#endif

 next_input:
  ws->ws_cli->cli_http_ses = ws->ws_session;
  ws_read_req (ws);
  try_pipeline = ws_can_try_pipeline (ws);

check_state:
  mutex_enter (ws_queue_mtx);
  if (ses->dks_to_close)
    {
      try_pipeline = 0;
      if (DKS_WS_INPUT_PENDING == ses->dks_ws_status
	  || DKS_WS_ACCEPTED == ses->dks_ws_status)
	ses->dks_ws_status = DKS_WS_DISCONNECTED; /* this thread owns the connection and will drop it */
    }

  switch (ses->dks_ws_status)
    {
    case DKS_WS_STARTED:
      if (try_pipeline)
	ses->dks_ws_status = DKS_WS_KEEP_ALIVE;
      else
	ses->dks_ws_status = DKS_WS_DISCONNECTED;
      ses->dks_ws_pending = NULL;
      ws->ws_session = NULL;
      mutex_leave (ws_queue_mtx);
      break;
    case DKS_WS_RUNNING:
      {
	if (!try_pipeline)
	  ses->dks_last_used = get_msec_real_time () - 1000000;
	else
	  ses->dks_last_used = get_msec_real_time ();
	ses->dks_ws_status = DKS_WS_KEEP_ALIVE;
	ws->ws_session = NULL;
	ses->dks_ws_pending = NULL;
	mutex_leave (ws_queue_mtx);
	break;
      }
    case DKS_WS_INPUT_PENDING:
      {
	mutex_leave (ws_queue_mtx);
	n_consec++;
	ses->dks_ws_status = DKS_WS_ACCEPTED;
	ses->dks_ws_pending = NULL;
	goto next_input;
      }
    case DKS_WS_ACCEPTED:
      /* the session was not checked in to watch for disconnects.
      * check to see if can do immediate reuse and otherwise check in for keep alive if appropriate. */
      if (try_pipeline && ws_pipeline_ready (ws)
	  && n_consec < 10)
	{
	  mutex_leave (ws_queue_mtx);
	  tws_immediate_reuse++;
	  n_consec++;
	  goto next_input;
	}
      else if (try_pipeline && DKSESSTAT_ISSET (ses, SST_OK))
	{
	  http_n_keep_alives++;
	  ws->ws_session = NULL;
	  ses->dks_ws_status = DKS_WS_KEEP_ALIVE;
	  SESSION_SCH_DATA (ses)->sio_default_read_ready_action = (io_action_func) ws_keep_alive_ready;
	  http_trace (("check in %p for slow keep alive\n", ses));
	  tws_slow_keep_alives++;
	  ses->dks_ws_pending = NULL;
	  /* the last used should be set gt than 0 to be disconnected after time-out */
	  ses->dks_last_used = get_msec_real_time ();
	  mutex_leave (ws_queue_mtx);
	  PrpcCheckInAsync (ses);
	  break;
	}
      else
	{
	  mutex_leave (ws_queue_mtx);
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  ws->ws_session = NULL;
	  break;
	}

    case DKS_WS_DISCONNECTED:
      {
	/* this thread disconnects */
	mutex_leave (ws_queue_mtx);
	PrpcDisconnect (ses);
	PrpcSessionFree (ses);
	ws->ws_session = NULL;
	break;
      }

    case DKS_WS_FLUSHED:
      {
	/* the connection is already disconnected, just free it */
	mutex_leave (ws_queue_mtx);
	PrpcSessionFree (ses);
	ws->ws_session = NULL;
	break;
      }
    case DKS_WS_CACHED:
      {
	/* the connection is cached, disconnect & free will be in other thread */
	mutex_leave (ws_queue_mtx);
	mutex_enter (thread_mtx);
	ses->dks_n_threads--;
	if (ses->dks_waiting_http_recall_session)
	  {
	    semaphore_leave (ses->dks_waiting_http_recall_session->thr_sem);
	    ses->dks_waiting_http_recall_session = NULL;
	  }
	mutex_leave (thread_mtx);
	ws->ws_session = NULL;
	break;
      }
    }
  ws_clear (ws, 0);
}

#if defined (_SSL) || defined (_IMSG)
void
ws_inet_session_init (dk_session_t * accept, ws_connection_t * ws)
{
  int s_port = tcpses_get_port (accept->dks_session);
#ifdef _SSL
  SSL_CTX * ssl_ctx = (SSL_CTX *)tcpses_get_sslctx (accept->dks_session);

  if (ssl_ctx) /* We got a HTTPS connection, let do ssl_accept */
    ws->ws_ssl_ctx = ssl_ctx; /* we record the ssl ctx only, will do SSL_accept further */
  else if (NULL != tcpses_get_ssl (ws->ws_session->dks_session)) /* HTTP mode , hence clear R/W hooks */
    sslses_to_tcpses (ws->ws_session->dks_session);
#endif

#ifdef _IMSG
  if (s_port == pop3_port)
    {
      ws->ws_port = s_port;
      ws->ws_try_pipeline = 0;
    }
  else if (s_port == nntp_port)
    {
      ws->ws_port = s_port;
      ws->ws_try_pipeline = 0;
    }
  else if (s_port == ftp_port)
    {
      ws->ws_port = s_port;
      ws->ws_try_pipeline = 0;
      ws->ws_session->dks_read_block_timeout.to_sec = ftp_server_timeout;
    }
  else
    ws->ws_port = 0;
#endif
}
#endif

void ws_ready (dk_session_t * accept);
void ws_serve_client_connection (ws_connection_t * ws);

void
ws_init_func (ws_connection_t * ws)
{
  ws->ws_thread = THREAD_CURRENT_THREAD;
  semaphore_enter (ws->ws_thread->thr_sem);
  SET_THR_ATTR (ws->ws_thread, TA_IMMEDIATE_CLIENT, ws->ws_cli);
  sqlc_set_client (ws->ws_cli);
  ws->ws_cli->cli_trx->lt_thr = ws->ws_thread;
  for (;;)
    {
      dk_session_t * ses;
      http_trace (("serve connection ws %p ses %p\n", ws, ws->ws_session));
      if (ws->ws_session->dks_ws_status == DKS_WS_CLIENT)
	ws_serve_client_connection (ws);
      else
	ws_serve_connection (ws);
      mutex_enter (ws_queue_mtx);
      ses = (dk_session_t *) basket_get (&ws_queue);
      if (!ses)
	{
	  http_trace (("ws %p to sleep\n", ws));
	  if (ws->ws_thr_cache_clear)
	    {
	      ws->ws_thr_cache_clear = 0;
	      thr_alloc_cache_clear (ws->ws_thread);
	    }
	  resource_store (ws_dbcs, (void*) ws);
	  mutex_leave (ws_queue_mtx);
	  semaphore_enter (ws->ws_thread->thr_sem);
	  continue;
	}
      mutex_leave (ws_queue_mtx);
      if (DKSESSTAT_ISSET (ses, SST_LISTENING))
	{
	  if (!ws->ws_session)
	    ws->ws_session = dk_session_allocate (SESCLASS_TCPIP);
	  session_accept (ses->dks_session, ws->ws_session->dks_session);
	  ws->ws_session->dks_ws_status = DKS_WS_ACCEPTED;
#if defined (_SSL) || defined (_IMSG)
	  /* initialize ws stricture for ssl, pop3, imap, nntp & ftp service */
	  ws_inet_session_init (ses, ws);
#endif
	  http_trace (("connect from queue accept ws %p ses %p\n", ws, ws->ws_session));
	  tws_connections ++;
	  SESSION_SCH_DATA (ses)->sio_default_read_ready_action = (io_action_func) ws_ready;
	  PrpcCheckInAsync (ses);
	}
      else
	{
	  if (ws->ws_session)
	    {
	      http_trace (("free %p before ws reuse\n", ws->ws_session));
	      PrpcSessionFree (ws->ws_session);
	    }
	  ws->ws_session = ses;
	}
    }
}

void
ws_ready (dk_session_t * accept)
{
  int rc;
  ws_connection_t * ws;
  mutex_enter (ws_queue_mtx);
  while (http_n_keep_alives > http_max_keep_alives)
    {
      mutex_leave (ws_queue_mtx);
      tws_early_timeout++;
      http_timeout_keep_alives (1);
      if (http_n_keep_alives > http_max_keep_alives)
	return;
      /* timing out keep alives could fail because they were counted
       * before they were added to the served set.  Return to allow completing the check in of keep alives and kill them on next ggo */
      mutex_enter (ws_queue_mtx);
    }
  ws = (ws_connection_t *) resource_get (ws_dbcs);

  if (!ws)
    {
      tws_accept_queued++;
      DKS_CLEAR_DEFAULT_READ_READY_ACTION (accept);
      remove_from_served_sessions (accept);
      basket_add (&ws_queue, (void*) accept);
      mutex_leave (ws_queue_mtx);
    }
  else
    {
      mutex_leave (ws_queue_mtx);
      if (!ws->ws_session)
	ws->ws_session = dk_session_allocate (SESCLASS_TCPIP);
      rc = session_accept (accept->dks_session, ws->ws_session->dks_session);
      ws->ws_session->dks_ws_status = DKS_WS_ACCEPTED;
#if defined (_SSL) || defined (_IMSG)
      /* initialize ws stricture for ssl, pop3, imap, nntp & ftp service */
      ws_inet_session_init (accept, ws);
#endif
      http_trace (("accept ws %p ses %p\n", ws, ws->ws_session));
      tws_connections++;
      semaphore_leave (ws->ws_thread->thr_sem);
    }
}


void
ws_keep_alive_disconnected (dk_session_t * ses)
{
  mutex_enter (ws_queue_mtx);
  remove_from_served_sessions (ses);
  if (DKS_WS_KEEP_ALIVE == ses->dks_ws_status)
    {
      mutex_leave (ws_queue_mtx);
      http_trace (("eof on keep alive %p\n", ses));
      DKS_CLEAR_DEFAULT_READ_READY_ACTION (ses);
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return;
    }
  if (DKS_WS_RUNNING == ses->dks_ws_status)
    {
      ws_connection_t * ws = (ws_connection_t *) ses->dks_ws_pending;
      lock_trx_t * lt = ws->ws_cli->cli_trx;
      http_trace (("Async cancel of %p \n", ses));
      tws_cancel++;
      http_trace (("Cancel on served connection %p\n", ses));
      ses->dks_ws_status = DKS_WS_DISCONNECTED;
      mutex_leave (ws_queue_mtx);
      IN_TXN;
      CHECK_DK_MEM_RESERVE (lt);
      if (LT_PENDING == lt->lt_status
	  && lt->lt_threads > 0)
	{
	  lt->lt_error = LTE_SQL_ERROR;
	  LT_ERROR_DETAIL_SET (lt,
	      box_dv_short_string ("Async cancel on served connection"));
	  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
	}
      LEAVE_TXN;
    }
  else
    GPF_T1 ("http disconnect but bad dks_ws_status");
}


void
ws_keep_alive_ready (dk_session_t * ses)
{
  ws_connection_t * ws;
  if (SESSION_SCH_DATA (ses)->sio_is_served == -1)
    GPF_T;

  mutex_enter (ws_queue_mtx);
  http_n_keep_alives--;
  mutex_leave (ws_queue_mtx);

  if (ses->dks_to_close)
    {
      ws_keep_alive_disconnected (ses);
      return;
    }
/*
     sometimes the select returns ses fd is ready for reading, but sequential read waits for input,
     therefore this can't be done here as it would block all incoming connections. furthermore
     this should not be done if it is ssl connection as it will loose 1-st byte.
     anyway the ws_read_req follows, which will terminate request chain if connection is broken.
*/
#if 0
  CATCH_READ_FAIL (ses)
    {
      session_buffered_read_char (ses);
      ses->dks_in_read--;
    }
  FAILED
    {
      ws_keep_alive_disconnected (ses);
      return;
    }
  END_READ_FAIL (ses);
#endif
  mutex_enter (ws_queue_mtx);
  remove_from_served_sessions (ses);
  DKS_CLEAR_DEFAULT_READ_READY_ACTION (ses);
  if (DKS_WS_KEEP_ALIVE == ses->dks_ws_status)
    {
      ses->dks_ws_status = DKS_WS_ACCEPTED;
      ws = (ws_connection_t *) resource_get (ws_dbcs);
      if (!ws)
	{
	  tws_keep_alive_ready_queued++;
	  http_trace (("queue keep alive ready %p\n", ses));
	  basket_add (&ws_queue, (void*) ses);
	  mutex_leave (ws_queue_mtx);
	}
      else
	{
	  tws_slow_reuse++;
	  mutex_leave (ws_queue_mtx);
	  if (ws->ws_session)
	    {
	      http_trace (("free ses %p on keep alive ready\n", ws->ws_session));
	      PrpcSessionFree (ws->ws_session);
	    }
	  ws->ws_session = ses;
	  http_trace (("dispatch keep alive ws %p ses %p \n", ws, ws->ws_session));
	  semaphore_leave (ws->ws_thread->thr_sem);
	}
      return;
    }
  if (DKS_WS_RUNNING == ses->dks_ws_status)
    {
      tws_immediate_reuse++;
      ses->dks_ws_status = DKS_WS_INPUT_PENDING;
    }
  mutex_leave (ws_queue_mtx);
}


void
http_timeout_keep_alives (int must_kill)
{
  long now = get_msec_real_time ();
  long timeout = http_keep_alive_timeout * 1000;
  long oldest_used = 0;
  dk_session_t * oldest = NULL;
  int n_killed = 0;
  dk_set_t clients = PrpcListPeers ();
  DO_SET (dk_session_t *, ses, &clients)
    {
      if (SESSION_SCH_DATA (ses)->sio_default_read_ready_action
	  == (io_action_func) ws_keep_alive_ready
	  && ses->dks_last_used
	  && DKS_WS_KEEP_ALIVE == ses->dks_ws_status)
	{
	/* ruslan@openlinksw.com | 2001/07/24 */
	/* I have change positions of two following clauses */
	  if (!oldest_used || ses->dks_last_used < oldest_used)
	    {
	      oldest = ses;
	      oldest_used = ses->dks_last_used;
	    }
	  if (now - ses->dks_last_used > timeout)
	    {
	      http_trace (("timeout keep alive %p \n", ses));
	      DKS_CLEAR_DEFAULT_READ_READY_ACTION (ses);
	      remove_from_served_sessions (ses);
	      PrpcDisconnect (ses);
	      PrpcSessionFree (ses);
	      n_killed++;
	    }
	/* end */
	}
    }
  END_DO_SET ();
  dk_set_free (clients);
  if (must_kill && !n_killed && oldest)
    {
      http_trace (("premature timeout kill of %p \n", oldest));
      n_killed++;
      DKS_CLEAR_DEFAULT_READ_READY_ACTION (oldest);
      remove_from_served_sessions (oldest);
      PrpcDisconnect (oldest);
      PrpcSessionFree (oldest);
    }
  mutex_enter (ws_queue_mtx);
  http_n_keep_alives -= n_killed;
  mutex_leave (ws_queue_mtx);
}

void remove_old_cached_sessions ();

void
http_reaper (void)
{
  if (!ws_queue_mtx)
    return;  /* not initialized */
  http_timeout_keep_alives (0);
  remove_old_cached_sessions ();
}


ws_connection_t *
ws_new_connection (void)
{
  dk_session_t * ses = dk_session_allocate (SESCLASS_TCPIP);
  client_connection_t * cli = client_connection_create ();
  NEW_VARZ (ws_connection_t, ws);
  /*MI: the ses will be disconnected when closed,
        so there will reside a trash. Hence do not set it.
    cli->cli_session = ses;*/
  cli->cli_not_char_c_escape = cli_not_c_char_escape;
  cli->cli_utf8_execs = cli_utf8_execs;
  cli->cli_no_system_tables = cli_no_system_tables;
  IN_TXN;
  cli_set_new_trx (cli);
  LEAVE_TXN;
  ws->ws_cli = cli;
  ws->ws_session = ses;
  ws->ws_strses = strses_allocate ();
  strses_enable_paging (ws->ws_strses, http_ses_size);
  ws->ws_charset = ws_default_charset;
  return ws;
}



const char *xml_escapes[256];

#define XML_CHAR_ESCAPE(c,s) xml_escapes [c] = s;

const char *dav_escapes[256];

#define DAV_CHAR_ESCAPE(c,s) dav_escapes [c] = s;




dk_session_t *
http_session_arg (caddr_t * qst, state_slot_t ** args, int nth,
		  const char * func)
{
  dk_session_t * res = NULL;
  if (((int) BOX_ELEMENTS (args)) > nth)
    {
      caddr_t * conn = (caddr_t *) bif_arg (qst, args, nth, func);
      if (DV_STRING_SESSION == DV_TYPE_OF (conn))
	res = (dk_session_t *) conn;
      else if (DV_CONNECTION == DV_TYPE_OF (conn))
	res = (dk_session_t *) conn[0];
      else
	res = NULL;
    }
  if (!res)
    {
      query_instance_t * qi = (query_instance_t *) qst;
      if (!qi->qi_client->cli_http_ses)
	sqlr_new_error ("37000", "HT006", "http output function outside of http context and no stream specified: %s.", func);
      res = qi->qi_client->cli_ws->ws_session;
    }
  return res;
}


dk_session_t *
http_session_no_catch_arg (caddr_t * qst, state_slot_t ** args, int nth,
		  const char * func)
{
  dk_session_t * res = NULL;
  if (((int) BOX_ELEMENTS (args)) > nth)
    {
      caddr_t * conn = (caddr_t *) bif_arg (qst, args, nth, func);
      if (DV_STRING_SESSION == DV_TYPE_OF (conn))
	res = (dk_session_t *) conn;
      else
	res = NULL;
    }
  if (!res)
    {
      query_instance_t * qi = (query_instance_t *) qst;
      if (!qi->qi_client->cli_http_ses)
	sqlr_new_error ("37000", "HT069",
	    "http output function %s() outside of http context and no stream specified", func);
      res = qi->qi_client->cli_http_ses;
    }
  return res;
}


caddr_t
http_path_to_array (char * path, int mode)
{
  int n_fill, inx;
  unsigned char ch;
  char name [PATH_ELT_MAX_CHARS];
  dk_set_t paths = NULL;
  inx = 0;
  n_fill = 0;
  if (!path)
    return NULL;
  for (;;)
    {
      ch = path [inx++];
      if (n_fill > sizeof (name) - 3)
	break;
      if ((0 == ch || ' ' == ch || '\n' == ch || '\r' == ch || '\t' == ch
	  || ch == '?') && mode == 0)
	break;
      if (0 == ch  && mode == 1)
	break;
      if (ch == '/')
	{
	  if (n_fill > 1 || (n_fill == 1 && name[0] != '.'))
	    {
	      dk_set_push (&paths, (void*) box_line (name, n_fill));
	      n_fill = 0;
	    }
	}
      else if (ch == '%')
	{
	  name[n_fill++] = char_hex_digit (path [inx + 0]) * 16
	    + char_hex_digit (path [inx + 1]);
	  inx += 2;
	}
      else
	{
	  name[n_fill++] = ch;
	}
    }
  if (n_fill > 1 || (n_fill == 1 && name[0] != '.'))
    dk_set_push (&paths, box_line (name, n_fill));

  if (paths)
    return list_to_array (dk_set_nreverse (paths));
  else
    return NULL;
}


caddr_t
bif_http_result (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t string = bif_arg (qst, args, 0, "http");
  dk_session_t * out = http_session_no_catch_arg (qst, args, 1, "http");
  dtp_t dtp = DV_TYPE_OF (string);

  /* potentially long time when session is flushed or chunked, then should use io sect
     for now as almost we using to go to string session we keep it w/o io sect */
  /* IO_SECT (qst); */
  if (DV_DB_NULL == dtp)
    return NULL;
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING || dtp == DV_C_STRING || dtp == DV_BIN)
    session_buffered_write (out, string, box_length (string) - (IS_STRING_DTP (DV_TYPE_OF (string)) ? 1 : 0));
  else if (dtp == DV_BLOB_HANDLE)
    {
      blob_handle_t *bh = (blob_handle_t *)string;
      if (!bh->bh_length)
	{
	  if (bh->bh_ask_from_client)
	    sqlr_new_error ("22023", "HT007", "An interactive blob can't be passed as argument to http");
	  else
	    goto end;
	}
      bh->bh_current_page = bh->bh_page;
      bh->bh_position = 0;
      bh_write_out (qi->qi_trx, bh, out);
      bh->bh_current_page = bh->bh_page;
      bh->bh_position = 0;
    }
  else if (DV_STRING_SESSION == dtp)
    {
      strses_write_out ((dk_session_t *)(string), out);
    }
  else if (IS_WIDE_STRING_DTP (dtp))
    {
      caddr_t err_ret = NULL;
      char *res = box_cast_to (qst, string, dtp, DV_LONG_STRING, 0, 0, &err_ret);
      if (!err_ret)
        session_buffered_write (out, res, box_length (res) - 1);
      else
	sqlr_new_error ("22023", "HT007", "Incorrect wide string passed to http");
      dk_free_box (res);
    }
  else
    {
#ifdef DEBUG
      dbg_print_box (string, stdout);
#endif
    *err_ret = srv_make_new_error ("22023", "HT008", "http requires string, blob or string session as argument 1");
    }
 end: ;
  /* END_IO_SECT; */
  return 0;
}


static caddr_t
bif_http_login_failed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t * ws = qi->qi_client->cli_ws;
  dk_session_t *ses = NULL;
  if (BOX_ELEMENTS (args) > 0)
    {
      caddr_t *ses_box =  (caddr_t *) bif_arg (qst, args, 0, "http_login_failed");
      if (DV_CONNECTION == DV_TYPE_OF (ses_box))
	ses = (dk_session_t *) ses_box[0];
    }
  if (!ses && !ws)
    sqlr_new_error ("37000", "HT006", "http_login_failed outside of http context and no stream specified");
  ses = ws->ws_session;

  failed_login_from (ses);
  return NULL;
}

void
dks_sqlval_esc_write (caddr_t *qst, dk_session_t *out, caddr_t val, wcharset_t *tgt_charset, wcharset_t *src_charset, int dks_esc_mode)
{
  dtp_t dtp = DV_TYPE_OF (val);
  if (DV_STRINGP (val))
    {
      if (box_flags (val) & BF_UTF8) /* if string is in UTF-8 do not even try to use some default */
	src_charset = CHARSET_UTF8;
      dks_esc_write (out, val, box_length (val) - 1, tgt_charset, src_charset, dks_esc_mode);
    }
  else if (IS_WIDE_STRING_DTP (dtp))
    {
      dks_wide_esc_write (out, (wchar_t *)val, box_length (val) / sizeof (wchar_t) - 1, tgt_charset, dks_esc_mode);
    }
  else if (DV_BLOB_WIDE_HANDLE  == dtp)
    {
      query_instance_t * qi = (query_instance_t *) qst;
      caddr_t wstring = blob_to_string (qi->qi_trx, val);
	dks_wide_esc_write (out, (wchar_t *) wstring, box_length (wstring) / sizeof (wchar_t) - 1,
	  tgt_charset, dks_esc_mode);
      dk_free_box (wstring);
    }
#ifdef BIF_XML
  else if (DV_XML_ENTITY == dtp)
    {
      /* if xout_encoding is not set we will set to default */
      caddr_t old_enc = ((xml_entity_t *)val)->xe_doc.xd->xout_encoding;
      if (!old_enc) ((xml_entity_t *)val)->xe_doc.xd->xout_encoding = (caddr_t) (CHARSET_NAME (tgt_charset, NULL));
      ((xml_entity_t *)val)->_->xe_serialize ((xml_entity_t *)val, out);
      /*      xe_box_serialize (val, out); */
      ((xml_entity_t *)val)->xe_doc.xd->xout_encoding = old_enc;
    }
#endif
  else if (DV_ARRAY_OF_XQVAL == dtp)
    {
      int els = BOX_ELEMENTS(val);
      int ctr;
      for (ctr = 0; ctr < els; ctr++)
	dks_sqlval_esc_write (qst, out, ((caddr_t *)(val))[ctr], tgt_charset, src_charset, dks_esc_mode);
    }
  else if (DV_DB_NULL == dtp)
    {
      ; /* do nothing */
    }
  else
    {
      caddr_t string;
      static caddr_t varchar = NULL;
      if (!varchar)
	varchar = (caddr_t) list (3, (ptrlong)DV_LONG_STRING, 0, 0);

      string = box_cast (qst, val, (sql_tree_tmp*) varchar, dtp);
#ifdef DEBUG
      if (DV_STRING != DV_TYPE_OF (string))
        GPF_T1("cast to varchar failed: the result is not a varchar");
      if (0 == box_length (string))
        GPF_T1("cast to varchar failed: the resulting box is of size 0");
      if ('\0' != string[box_length (string) - 1])
        GPF_T1("cast to varchar failed: the resulting box has no trailing zero");
#endif
      dks_esc_write (out, string, box_length (string) - 1, tgt_charset, default_charset, dks_esc_mode);
      dk_free_box (string);
    }
}

void
http_value_esc (caddr_t *qst, dk_session_t *out, caddr_t val, char *tag, int dks_esc_mode)
{
  ws_connection_t * ws = ((query_instance_t *)qst)->qi_client->cli_ws;
  if (!DV_STRINGP (tag))
    tag = NULL;
  if (tag)
    {
      session_buffered_write_char ('<', out);
      session_buffered_write (out, tag, strlen (tag));
      session_buffered_write_char ('>', out);
    }
  dks_sqlval_esc_write (qst, out, val, WS_CHARSET (ws, qst), default_charset, dks_esc_mode);
  if (tag)
    {
      session_buffered_write (out, "</", 2);
      session_buffered_write (out, tag, strlen (tag));
      session_buffered_write_char ('>', out);
    }
}


caddr_t
bif_http_value_1 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, char *bifname, int dks_esc_mode)
{
  dk_session_t * out = http_session_no_catch_arg (qst, args, 2, bifname);
  caddr_t val = bif_arg (qst, args, 0, bifname);
  char * tag = BOX_ELEMENTS (args) > 1 ? bif_arg (qst, args, 1, bifname) : NULL;
  http_value_esc (qst, out, val, tag, dks_esc_mode);
  tcpses_check_disk_error (out, qst, 1);
  return NULL;
}


caddr_t
bif_http_value (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (bif_http_value_1 (qst, err_ret, args, "http_value", DKS_ESC_PTEXT));
}


caddr_t
bif_http_url (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (bif_http_value_1 (qst, err_ret, args, "http_url", DKS_ESC_URI));
}

caddr_t
bif_http_uri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (bif_http_value_1 (qst, err_ret, args, "http_uri", DKS_ESC_URI_RES));
}

caddr_t
bif_http_dav_url (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (bif_http_value_1 (qst, err_ret, args, "http_dav_url", DKS_ESC_DAV));
}

caddr_t
bif_http_xmlelement_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int is_empty, const char *bifname)
{
  ws_connection_t * ws = ((query_instance_t *)qst)->qi_client->cli_ws;
  caddr_t elt = bif_string_or_uname_arg (qst, args, 0, bifname);
  dk_session_t * out = http_session_no_catch_arg (qst, args, 1, bifname);
  int argctr, argcount = BOX_ELEMENTS (args), attr_printed = 0;
  session_buffered_write_char ('<', out);
  session_buffered_write (out, elt, box_length (elt)-1);
  for (argctr = 2; argctr < argcount; argctr += 2)
    {
      caddr_t attrname = bif_string_or_uname_arg (qst, args, argctr, bifname);
      caddr_t attrvalue = bif_arg (qst, args, argctr+1, bifname);
      if (DV_DB_NULL == DV_TYPE_OF (attrvalue))
        continue;
      session_buffered_write_char (' ', out);
      session_buffered_write (out, attrname, box_length (attrname)-1);
      session_buffered_write (out, "=\"", 2);
      dks_sqlval_esc_write (qst, out, attrvalue, WS_CHARSET (ws, qst), default_charset, DKS_ESC_DQATTR);
      session_buffered_write_char ('"', out);
      attr_printed++;
    }
  if ('?' == elt[0])
    {
      if (!is_empty)
        sqlr_new_error ("22023", "SR641", "%s() is only for only plain elements, not for processing instructions like <%.200s ...?>", bifname, elt);
      session_buffered_write_char ('?', out);
    }
  else
    {
      if (is_empty)
        session_buffered_write (out, " /", 2);
    }
  session_buffered_write_char ('>', out);
  return box_num (attr_printed);
}

caddr_t
bif_http_xmlelement_start (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_http_xmlelement_impl (qst, err_ret, args, 0, "http_xmlelement_start");
}

caddr_t
bif_http_xmlelement_empty (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_http_xmlelement_impl (qst, err_ret, args, 1, "http_xmlelement_empty");
}

caddr_t
bif_http_xmlelement_end (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t elt = bif_string_or_uname_arg (qst, args, 0, "http_xmlelement_end");
  dk_session_t * out = http_session_no_catch_arg (qst, args, 1, "http_xmlelement_end");
  session_buffered_write (out, "</", 2);
  session_buffered_write (out, elt, box_length (elt)-1);
  session_buffered_write_char ('>', out);
  return box_num (0);
}

caddr_t
bif_http_rewrite (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * out = http_session_no_catch_arg (qst, args, 0, "http_rewrite");
  if (DV_TYPE_OF (out) != DV_STRING_SESSION)
    sqlr_new_error ("22023", "HT070",
		"The HTTP output is not an STRING session in http_rewrite");
  strses_flush (out);
  return 0;
}

caddr_t
bif_http_enable_gz (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int _new = (int) bif_long_arg (qst, args, 0, "http_enable_gz");

  if (_new == 1 || _new == 0)
    enable_gzip = _new;

  return box_num (enable_gzip);
}

caddr_t
bif_http_header (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t new_hdr = bif_string_arg (qst, args, 0, "http_header");
  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("37000", "HT009", "XML output function allowed only inside HTTP request");
  dk_free_tree (qi->qi_client->cli_ws->ws_header); /*we must clear old value*/
  qi->qi_client->cli_ws->ws_header = box_copy (new_hdr);
  return 0;
}

/* implements a transparent Host header access */
caddr_t
bif_http_host (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t deflt = ((BOX_ELEMENTS (args) > 0) ? bif_arg (qst, args, 0, "http_host") : NULL);
  caddr_t host = NULL;
  ws_connection_t *ws = qi->qi_client->cli_ws;
  if (ws && ws->ws_lines)
    {
      if (NULL == (host = ws_mime_header_field (ws->ws_lines, "X-Forwarded-Host", NULL, 1)))
	host = ws_mime_header_field (ws->ws_lines, "Host", NULL, 1);
    }
  if (!host)
    host = box_copy (deflt);
  return host;
}

void
ws_lt_trace (lock_trx_t * lt)
{
  static char * fname = "http_trace.txt";
  dk_session_t * ses;
  int to_read, fd = -1;
  char buffer[4096];
  int64 len, ofs;

  ASSERT_IN_TXN;
  if (!lt || !lt->lt_client || !lt->lt_client->cli_ws || !lt->lt_client->cli_ws->ws_req_log)
    return;
  ses = lt->lt_client->cli_ws->ws_req_log;
  len = strses_length (ses), ofs = 0;
  fd = fd_open (fname, OPEN_FLAGS);
  if (fd < 0)
    {
      log_error ("Can not open ws trace file %s", fname);
      goto err;
    }
  if (LSEEK (fd, 0, SEEK_END) == -1)
    {
      log_error ("Can not seek in ws trace file %s", fname);
      goto err;
    }
  while (ofs < len)
    {
      int readed;
      to_read = MIN (sizeof (buffer), len - ofs);
      if (0 != (readed = strses_get_part (ses, buffer, ofs, to_read)))
	GPF_T;
      if (to_read != write (fd, buffer, to_read))
	{
	  log_error ("Can not write in ws trace file %s", fname);
	  goto err;
	}
      ofs += to_read;
    }
err:
  fd_close (fd, fname);
  return;
}

caddr_t
bif_http_pending_req (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t set = NULL;
  caddr_t * arr;
  ws_connection_t * ws;

  sec_check_dba ((query_instance_t *) qst, "http_pending_req");

  if (BOX_ELEMENTS (args) > 1)
    {
      query_instance_t * qi = (query_instance_t *) qst;
      ws = qi->qi_client->cli_ws;
      if (!ws)
	sqlr_new_error ("37000", "HT067",
	    "The http_pending_req with parameter function allowed only inside HTTP request.");
      return (caddr_t) list (3, box_copy (ws->ws_client_ip),
	  box_copy (ws->ws_path_string), box_num ((ptrlong)ws));
    }

  IN_TXN;
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_client && lt->lt_client->cli_ws && lt->lt_threads > 0)
	{
	  ws = lt->lt_client->cli_ws;
	  arr = (caddr_t *) list (3, box_copy (ws->ws_client_ip),
	      box_copy (ws->ws_path_string),
	      box_num ((ptrlong)ws));
	  dk_set_push (&set, (void *)arr);
	}
    }
  END_DO_SET ();
  LEAVE_TXN;
  return ((caddr_t) list_to_array (dk_set_nreverse (set)));
}

static void
http_kill_all ()
{
  dk_set_t killed = NULL;
  ws_connection_t * ws;
  IN_TXN;
again:
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_status == LT_PENDING && !dk_set_member (killed, (void*)lt) &&
	  (lt->lt_threads > 0 || lt_has_locks (lt)) && lt->lt_client && lt->lt_client->cli_ws)
	{
	  ws = lt->lt_client->cli_ws;
	  CHECK_DK_MEM_RESERVE (lt);
	  lt->lt_error = LTE_TIMEOUT;
	  dk_set_push (&killed, (void*) lt);
	  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
	  goto again;
	}
    }
  END_DO_SET ();
  dk_set_free (killed);
  LEAVE_TXN;
}

caddr_t
bif_http_lock (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pass = bif_string_arg (qst, args, 0, "http_lock");
  user_t * user = sec_name_to_user ("dba");

  if (strcmp (pass, user->usr_pass))
    sqlr_new_error ("22023", "HT042", "Invalid DBA credentials");
  sec_check_dba ((query_instance_t *) qst, "http_lock");

  if (!www_maintenance_page)
    sqlr_new_error ("22023", "HTERR", "The maintenance page is not specified, must have MaintenancePage setting in the HTTPServer section of the INI");

  if (!MAINTENANCE)
    {
      www_maintenance = 1;
      http_kill_all ();
    }
  else
    sqlr_new_error ("42000", "HTERR", "Cannot enter in maintenance mode when it is already entered");
  return NULL;
}

caddr_t
bif_http_unlock (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pass = bif_string_arg (qst, args, 0, "http_lock");
  user_t * user = sec_name_to_user ("dba");

  if (strcmp (pass, user->usr_pass))
    sqlr_new_error ("22023", "HT042", "Invalid DBA credentials");
  sec_check_dba ((query_instance_t *) qst, "http_unlock");
  if (MAINTENANCE)
    www_maintenance = 0;
  else
    sqlr_new_error ("42000", "HTERR", "Cannot leave maintenance mode when it is already left");
  return NULL;
}

caddr_t
bif_http_kill (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  ws_connection_t * ws;
  caddr_t ht_client = NULL, ht_path = NULL;
  void * ht_num = NULL;
  dk_set_t killed = NULL;

  sec_check_dba ((query_instance_t *) qst, "http_kill");

  if (BOX_ELEMENTS (args) > 1)
    {
      ht_client = bif_string_arg (qst, args, 0, "http_kill");
      ht_path = bif_string_arg (qst, args, 1, "http_kill");
    }
  if (BOX_ELEMENTS (args) > 2)
    ht_num = (void *)(ptrlong)(bif_long_arg (qst, args, 2, "http_kill"));

  IN_TXN;
again:
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt != qi->qi_trx &&  lt->lt_status == LT_PENDING && !dk_set_member (killed, (void*)lt) &&
	  (lt->lt_threads > 0 || lt_has_locks (lt)) && lt->lt_client && lt->lt_client->cli_ws)
	{
	  ws = lt->lt_client->cli_ws;
	  CHECK_DK_MEM_RESERVE (lt);
	  if (ws->ws_client_ip && ws->ws_path_string && ht_client && ht_path && (!ht_num || (ht_num == ws)))
	    {
	      if (!strcmp (ht_path, ws->ws_path_string) && !strcmp (ht_client, ws->ws_client_ip))
		{
		  lt->lt_error = LTE_TIMEOUT;
		  dk_set_push (&killed, (void*) lt);
		  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
		  goto again;
		}
	    }
	}
    }
  END_DO_SET ();
  dk_set_free (killed);
  LEAVE_TXN;
  return NULL;
}

int32 http_limited;

caddr_t
bif_http_limited (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  ws_connection_t * ws;
  volatile long limited = 0;

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT010", "This function is only allowed processing a HTTP request");
  ws = qi->qi_client->cli_ws;
  IN_TXN;
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if ((lt->lt_threads > 0 || lt_has_locks (lt)) && lt->lt_client && !lt->lt_client->cli_terminate_requested && 
	  lt->lt_client->cli_ws && lt->lt_client->cli_ws->ws_limited)
	limited ++;
    }
  END_DO_SET ();
  if (limited < http_limited)
    ws->ws_limited = 1; /* must be set inside txn mtx */
  LEAVE_TXN;

  if (limited >= http_limited)
    sqlr_new_error ("42000", "HTLIM", "The use of restricted HTTP threads is over the limit");
  return box_num (limited);
}

caddr_t
bif_http_header_get (caddr_t * qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;

  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT010", "This function is only allowed processing a HTTP request");
  if (qi->qi_client->cli_ws->ws_header)
    return box_copy (qi->qi_client->cli_ws->ws_header);
  else
    return dk_alloc_box (0, DV_DB_NULL);
}

caddr_t
bif_http_header_array_get (caddr_t * qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;

  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT010", "This function is only allowed processing a HTTP request");
  if (qi->qi_client->cli_ws->ws_header)
    return (caddr_t) ws_header_line_to_array (qi->qi_client->cli_ws->ws_header);
  else
    return (caddr_t) list (0);
}

caddr_t
bif_http_file(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT011", "http_file() output function allowed only inside HTTP request");
  dk_free_tree (qi->qi_client->cli_ws->ws_file); /*we must clear old value*/
  qi->qi_client->cli_ws->ws_file = box_copy (bif_string_arg (qst, args, 0, "http_file"));
  return NULL;
}

caddr_t
bif_http_request_status(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t new_stat = bif_string_arg (qst, args, 0, "http_request_status");
  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT012", "XML output function allowed only inside HTTP request");
  HTTP_SET_STATUS_LINE (qi->qi_client->cli_ws, new_stat, 1);
  return NULL;
}

static caddr_t
bif_http_request_status_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT012", "The http_request_status_get function allowed only inside HTTP request");
  if (qi->qi_client->cli_ws->ws_status_line)
    return box_copy (qi->qi_client->cli_ws->ws_status_line);
  return NEW_DB_NULL;
}

caddr_t
bif_http_root (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (box_dv_short_string (www_root));
}

caddr_t
bif_dav_root (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  if (!dav_root)
/* IvAn/XmlView/000810 If return NULL, what's about concat(dav_root(), something) ?
   I'd rather return default value
    return NULL; */
    return box_dv_short_string ("DAV");
  else
    return box_dv_short_string ((!strcmp (dav_root , "/")) ? "" : dav_root);
}

caddr_t
bif_http_path (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  /* IvAn/XmlView/000810 if() added to prevent crash */
  if(NULL==qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT013", "http_path() function allowed only inside HTTP request");
  return (box_dv_short_string (qi->qi_client->cli_ws->ws_path_string));
}

caddr_t
bif_http_internal_redirect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t new_path = bif_string_arg (qst, args, 0, "http_internal_redirect");
  caddr_t new_phy_path = NULL, new_url = NULL;
  caddr_t * parr;
  ws_connection_t * ws = qi->qi_client->cli_ws;
  int keep_lpath = 0;

  if (NULL == ws)
    sqlr_new_error ("42000", "HT067",
	"http_internal_redirect() function allowed only inside HTTP request");

  ws = qi->qi_client->cli_ws;

  if (BOX_ELEMENTS (args) > 3)
    keep_lpath = (int) bif_long_arg (qst, args, 3, "http_internal_redirect");

  if (!keep_lpath)
    {
      dk_free_tree (ws->ws_path_string);
      dk_free_tree (ws->ws_path);
      ws->ws_path_string = box_copy (new_path);
      parr = (caddr_t *) http_path_to_array (new_path, 1);
      ws->ws_path = ((NULL != parr) ? parr : (caddr_t *) list(0));
    }

  if (BOX_ELEMENTS (args) > 1)
    new_phy_path = bif_string_or_null_arg (qst, args, 1, "http_internal_redirect");

#ifdef VIRTUAL_DIR
  if (new_phy_path != NULL)
    {
      dk_free_tree (ws->ws_p_path_string);
      dk_free_tree (ws->ws_p_path);
      ws->ws_p_path_string = box_copy (new_phy_path);
      parr = (caddr_t *) http_path_to_array (new_phy_path, 1);
      ws->ws_p_path = ((NULL != parr) ? parr : (caddr_t *) list(0));
      ws->ws_proxy_request = (ws->ws_p_path_string ? (0 == strnicmp (ws->ws_p_path_string, "http://", 7)) : 0);
    }
#endif
  if (BOX_ELEMENTS (args) > 2)
    new_url = bif_string_or_null_arg (qst, args, 2, "http_internal_redirect");
  if (!keep_lpath && NULL != new_url && NULL != ws->ws_lines && BOX_ELEMENTS (ws->ws_lines) > 0)
    {
      caddr_t * lines = ws->ws_lines;
      caddr_t new_req = dk_alloc_box (box_length (new_url) + strlen (ws->ws_method_name) + strlen (ws->ws_proto) + 4,
	  DV_STRING);
      snprintf (new_req, box_length (new_req), "%s %s %s\r\n", ws->ws_method_name, new_url, ws->ws_proto);
      dk_free_box (lines[0]);
      lines[0] = new_req;
    }

  return (caddr_t) NULL;
}

/* Cached sessions for HTTP proxy */
dk_set_t ws_proxy_cache = NULL;
dk_mutex_t * ws_cache_mtx;

void
http_session_used (dk_session_t * ses, char * host, long peer_max_timeout)
{
  ws_cached_connection_t * proxy_cache = NULL;
  mutex_enter (ws_cache_mtx);
  if (!host || (((long) dk_set_length (ws_proxy_cache)) >= http_max_cached_proxy_connections))
    {
      mutex_leave (ws_cache_mtx);
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return;
    }
  proxy_cache = (ws_cached_connection_t *) dk_alloc (sizeof (ws_cached_connection_t));
  proxy_cache->host = box_dv_short_string (host);
  proxy_cache->ses = ses;
  proxy_cache->hit = get_msec_real_time ();
  proxy_cache->timeout = peer_max_timeout > 0 ? peer_max_timeout : http_proxy_connection_cache_timeout;

  dk_set_push (&ws_proxy_cache, (void *) proxy_cache);
  tws_cached_connections++;
  tws_cached_connections_in_use--;
  mutex_leave (ws_cache_mtx);
  http_trace (("session used -> host: %s ses: %p\n", host, ses));
}


dk_session_t *
http_cached_session (char * host)
{
  dk_session_t * ret = NULL;
  if (!host || !ws_proxy_cache)
    {
      if (!ws_proxy_cache)
	{
	  tws_cached_connection_miss++;
	  tws_cached_connections_in_use++;
	}
      return NULL;
    }
  mutex_enter (ws_cache_mtx);
  DO_SET (ws_cached_connection_t *, conn, &ws_proxy_cache)
    {
      if (0 == strcmp (host, (char *)(conn->host)))
	{
	  void * item = (void *) conn;
	  ret = conn->ses;
	  dk_free_box (conn->host);
	  dk_free (conn, sizeof (ws_cached_connection_t));
	  dk_set_delete (&ws_proxy_cache, item);
	  http_trace (("session found -> host: %s ses: %p\n", host, ret));
	  ret->dks_in_read = ret->dks_in_fill = 0;
	  tws_cached_connection_hits++;
	  tws_cached_connections_in_use++;
	  tws_cached_connections--;
	  mutex_leave (ws_cache_mtx);
	  return ret;
	}
    }
  END_DO_SET ();
  tws_cached_connection_miss++;
  mutex_leave (ws_cache_mtx);
  return NULL;
}

void
remove_old_cached_sessions (void)
{
  long now = get_msec_real_time ();
  if (!ws_proxy_cache)
    return;
  http_trace (("------ HTTP PROXY CACHED SESSIONS -----\n"));
  mutex_enter (ws_cache_mtx);
  DO_SET (ws_cached_connection_t *, conn, &ws_proxy_cache)
    {
      http_trace (("%s \t\t %p\n", (char *)(conn->host), conn->ses));
      if ((now - ((long) conn->hit)) >
	  MIN((http_proxy_connection_cache_timeout * 1000L), (conn->timeout * 1000L)))
	{
	  void * item = (void *) conn;
	  http_trace (("old session found -> host: %s ses: %p\n", (char *)(conn->host), conn->ses));
	  PrpcDisconnect (conn->ses);
	  PrpcSessionFree (conn->ses);
	  dk_free_box (conn->host);
	  dk_free (conn, sizeof (ws_cached_connection_t));
	  dk_set_delete (&ws_proxy_cache, item);
	  tws_cached_connections--;
	}
    }
  END_DO_SET ();
  mutex_leave (ws_cache_mtx);
  http_trace (("-------- END HTTP PROXY CACHE -------\n"));
}

dk_session_t *
http_dks_connect (char * host2, caddr_t * err_ret)
{
  int rc;
  dk_session_t * ses = NULL;
  timeout_t timeout;
  char host[1000];

  if (host2 && strlen (host2) > sizeof (host) + 4)
    {
      *err_ret = srv_make_new_error ("22023", "HT014", "Host name is too long");
      return NULL;
    }

  ses = dk_session_allocate (SESCLASS_TCPIP);

  strcpy_ck (host, host2);
  if (!strchr (host, ':'))
    strcat_ck (host, ":80");
  rc = session_set_address (ses->dks_session, host);
  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "HT015", "Cannot resolve host %s in http_get", host);
      return NULL;
    }
  rc = session_connect (ses->dks_session);

  if (!_thread_sched_preempt)
    {
      timeout = dks_fibers_blocking_read_default_to;
      ses->dks_read_block_timeout = timeout;
    }

  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "HT016", "Cannot connect to %.1000s in http_get", host);
      return NULL;
    }

  return ses;
}


#define SES_C_LENGTH(ses, len) \
{ \
  char xx[50]; \
  snprintf (xx, sizeof (xx), "Content-Length: " OFF_T_PRINTF_FMT "\r\n", (OFF_T_PRINTF_DTP) len); \
  SES_PRINT (ses, xx); \
}

void
http_write_req (dk_session_t * ses, char * host, caddr_t * head, caddr_t * body, dk_session_t * ent_ses)
{
  dk_session_t * volatile post_strses = NULL;
  volatile int len_done = 0;
  volatile long new_len = -1;
  char http_11_head [2048];
  int is_mp = body && BOX_ELEMENTS(body) > 0  && (0 == strcmp (body[0], "multipart"));
  char *szContentType = NULL;
  volatile int url_enc = 1;
  char *proto = NULL;

  szContentType= ws_header_field (head, "Content-Type:","");
  while (*szContentType && *szContentType <= '\x20')
    szContentType++;
  if (!strnicmp (szContentType, "multipart", 9)
      || !strnicmp (szContentType, "application/x-www-form-urlencoded", 33))
    url_enc = (ent_ses && body && BOX_ELEMENTS(body) > 0) ? 1 : 0;

  if (is_mp) /*if the first param is 'multipart' */
    new_len = box_length (body[1] - 1);
  else if ((!body || 0 == BOX_ELEMENTS (body)) && !ent_ses) /* if no body and no session */
    new_len = 0;
  else /* if it is not a multipart not empty body */
    {
      int inx, len = IS_BOX_POINTER(body) ? BOX_ELEMENTS (body) : 0;
      int first = 1;
      post_strses  = strses_allocate ();
      if (url_enc)
	{
	  proto = strstr (head [0], " HTTP/1.");
	  session_buffered_write (post_strses, head [0], proto - head [0]);
	  if (len > 0)
	    session_buffered_write_char ('?', post_strses);
	}
      for (inx = 0; inx < len; inx += 2)
	{
	  if (!first)
	    session_buffered_write_char ('&', post_strses);
	  first = 0;
	  dks_esc_write (post_strses, body[inx], box_length (body[inx]) - 1, default_charset, default_charset, DKS_ESC_URI);
	  session_buffered_write_char ('=', post_strses);
	  dks_esc_write (post_strses, body[inx + 1], box_length (body[inx + 1]) - 1, default_charset, default_charset, DKS_ESC_URI);
	}
      if (url_enc)
	{
	  session_buffered_write (post_strses, proto, 9);
	  session_buffered_write_char ('\r', post_strses);
	  session_buffered_write_char ('\n', post_strses);
	}

      if (ent_ses)
	{
	  if (!url_enc && post_strses)
	    {
	      strses_free (post_strses);
	      post_strses = NULL;
	    }
	  new_len = strses_length (ent_ses);
	}
      else if (!url_enc)
	new_len = strses_length (post_strses);
    }

  CATCH_WRITE_FAIL (ses)
    {
      int inx;

      if (url_enc && post_strses && body) /* if we have URL parameters given */
	strses_write_out (post_strses, ses);

      DO_BOX (char *, line, inx, head)
	{

	  if (inx == 0 && url_enc && post_strses && body) /* we have already sent the HTTP request method */
	    continue;

	  if (0 == strnicmp (line, "Connection:", 11) || 0 == strnicmp (line, "Host:", 5))
	    continue;

	  if (0 == strnicmp (line, "Content-Length:", 15))
	    {
	      SES_C_LENGTH (ses, new_len);
	      len_done = 1;
	      continue;
	    }

	  SES_PRINT (ses, line);

	}
      END_DO_BOX;

      if (!len_done && new_len > 0)
	SES_C_LENGTH (ses, new_len);

      snprintf (http_11_head, sizeof (http_11_head), "Connection: Keep-Alive\r\nHost: %s\r\n\r\n", host);
      SES_PRINT (ses, http_11_head);

      if ((body && !url_enc) || ent_ses)
	{
	  if (is_mp)
	    session_buffered_write (ses, body[1], box_length (body) - 1);
	  else if (ent_ses)
	    strses_write_out (ent_ses, ses);
	  else if (post_strses)
	    strses_write_out (post_strses, ses);

	}

      session_flush_1 (ses);
    }
  FAILED
    {
      if (post_strses)
	strses_free (post_strses);
    }
  END_WRITE_FAIL (ses);
}


dk_session_t *
http_request (char * host, caddr_t * req, caddr_t * body, caddr_t * err_ret,
	      caddr_t ** head_ret, dk_session_t * ent_ses)
{
  volatile int cached = 0;
  char line[4096];
  dk_set_t head = NULL;
  int rc;
  dk_session_t * volatile ses = http_cached_session (host);
  *err_ret = NULL;
  if (ses)
    cached = 1;
  else
    ses = http_dks_connect (host, err_ret);
  if (*err_ret)
    return NULL;
  http_write_req (ses, host, req, body, ent_ses);
  CATCH_READ_FAIL (ses)
    {
      do
	{
	  rc = dks_read_line (ses, line, sizeof (line));
	}
      while (0 != strncmp (line, "HTTP/1.", 7) || 0 == strncmp (line, "HTTP/1.1 100", 12));
      dk_set_push (&head, box_dv_short_string (line));
      for (;;)
	{
	  rc = dks_read_line (ses, line, sizeof (line));
	  if (rc <= 2)
	    break;
	  dk_set_push (&head, box_dv_short_string (line));
	}
      *head_ret = (caddr_t *) list_to_array (dk_set_nreverse (head));
    }
  FAILED
    {
      if (cached)
	{
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  dk_free_tree (list_to_array (head));
	  return (http_request (host, req, body, err_ret, head_ret, ent_ses));
	}
      else
	{
	  *err_ret = srv_make_new_error ("08006", "HT017", "Error in reading from HTTP server");
	}
    }
  END_READ_FAIL (ses);
  return ses;
}


void
http_proxy_header (ws_connection_t * ws, caddr_t * head, int len)
{
  int len_done = 0;
  int inx;
  DO_BOX (caddr_t, line, inx, head)
    {
      if (!strnicmp (line, "Content-Length:", 15))
	len_done = 1;
      else if (ws->ws_map && !strnicmp (line, "Location:", 9))
	{
	  char * location = line + 9;
	  char * ppath = ws->ws_map->hm_p_path;
	  char * lpath = ws->ws_map->hm_l_path;
	  while (*location && isspace (*location))
	    location++;
	  if (!strncmp(ppath, location, strlen (ppath)))
	    {
	      SES_PRINT (ws->ws_session, "Location: ");
	      SES_PRINT (ws->ws_session, lpath);
	      if (lpath[strlen(lpath)-1] != '/')
		SES_PRINT (ws->ws_session, "/");
	      SES_PRINT (ws->ws_session, location + strlen (ppath));
	      goto next_line;
	    }
	}
      SES_PRINT (ws->ws_session, line);
next_line:;
    }
  END_DO_BOX;
  if (!len_done && len > 0)
    {
      SES_C_LENGTH (ws->ws_session, len);
    }
  SES_PRINT (ws->ws_session, "\r\n");
}


int
dks_next_buffer (dk_session_t * ses)
{
  int bytes;
  CATCH_READ_FAIL (ses)
    {
      ses->dks_in_read = ses->dks_in_fill;
      session_buffered_read_char (ses);
      ses->dks_in_read = 0;
      bytes = ses->dks_in_fill;
    }
  FAILED
    {
      bytes = 0;
    }
  END_READ_FAIL (ses);
  return bytes;
}


void
http_proxy (ws_connection_t * ws, char * host, caddr_t * req, caddr_t * body, dk_session_t * ent_ses)
{
  volatile long len, plen;
  volatile int close = 0, error = 0;
  caddr_t err = NULL;
  caddr_t * head = NULL;
  volatile int chunked = 0;
  long peer_max_timeout = 0;
  char http_req_stat [1024];
  dk_session_t * volatile ses = http_request (host, req, body, &err, &head, ent_ses);
  if (err)
    sqlr_resignal (err);
  if (BOX_ELEMENTS (head) > 0)
    {
      strncpy (http_req_stat, head[0], sizeof (http_req_stat));
      http_req_stat[sizeof (http_req_stat) - 1] = 0;
    }
  else
    strcpy_ck (http_req_stat, "");
  len = ws_content_length (head);
  plen = len;
  if (strstr (head[0], "HTTP/1.0"))
    close = 1;
  else
    {
      char * connection = ws_header_field (head, "Connection:", "");
      while (*connection && *connection <= '\x20')
	connection++;
      close = 1;
      if (0 == strnicmp (connection, "close", 5))
	close = 1;
      if (0 == strnicmp (connection, "Keep-Alive", 10))
	{
	  char * keep_alive;
	  close = 0;
	  keep_alive = ws_header_field (head, "Keep-Alive:", "");
	  while (*keep_alive && *keep_alive <= '\x20')
	    keep_alive++;
	  keep_alive = strchr (keep_alive, '=');
	  if (keep_alive)
	    sscanf (keep_alive, "=%ld", &peer_max_timeout);
	}
      chunked = strstr (ws_header_field (head, "Transfer-Encoding:", ""), "chunked") != NULL;
    }

  CATCH_WRITE_FAIL (ws->ws_session)
    {
      http_proxy_header (ws, head, 0);
      if (strstr (req [0], "HEAD "))  /* If HEAD method do not send body */
	;
      else if (chunked) /* If have chunked encoding */
	{
	  char line [4096];
	  unsigned long icnk = 0;
	  unsigned long readed = 0;
	  CATCH_READ_FAIL (ses)
	    {
	      for (;;)
		{
		  readed = dks_read_line (ses, line, sizeof (line));
		  if (1 != sscanf (line,"%lx", (&icnk))) /* no chunk header */
		    break;
		  if (!icnk && readed) /* chunk trailer (last) */
		    break;
		  session_buffered_write (ws->ws_session, line, readed);
		  while (icnk > 0)
		    {
		      readed = MIN (icnk, sizeof (line));
		      session_buffered_read (ses, line, readed);
		      icnk -= readed;
		      session_buffered_write (ws->ws_session, line, readed);
		    }
		  readed = dks_read_line (ses, line, sizeof (line));
		  session_buffered_write (ws->ws_session, "\r\n", 2);
		  session_flush_1 (ws->ws_session);
		}
	    }
	  END_READ_FAIL (ses);
	  session_buffered_write (ws->ws_session, "0\r\n\r\n", 5); /* Write last zero chunk */
	  session_flush_1 (ws->ws_session);
	}
      else if (len > 0 || (close && len == -1)) /* If have content length or connection should be closed by peer */
	{
	  char tmp [4096], c;
	  int to_read = len, to_read_len = sizeof (tmp), readed = 0;

	  CATCH_READ_FAIL (ses)
	    {
	      do
		{
		  if (len > 0) /* Content-Length is given */
		    {
		      if (to_read < to_read_len)
			to_read_len = to_read;
		      readed = session_buffered_read (ses, tmp, to_read_len);
		      if (readed < 1)
			break;
		      session_buffered_write (ws->ws_session, tmp, readed);
		      session_flush_1 (ws->ws_session);
		      to_read -= readed;
		    }
		  else /* HTTP/1.0 goes here */
		    {
		      c = session_buffered_read_char (ses);
		      session_buffered_write_char (c, ws->ws_session);
		      readed++;
		      if (0 == (readed % sizeof (tmp)))
			session_flush_1 (ws->ws_session);
		    }
		}
	      while (close || to_read > 0);
	    }
	  END_READ_FAIL (ses);
	}
      session_flush_1 (ws->ws_session);
    }
  FAILED
    {
      error = 1;
    }
  END_WRITE_FAIL (ws->ws_session);
  dk_free_tree ((box_t) head);
  if (error)
    SESSTAT_SET (ws->ws_session->dks_session, SST_BROKEN_CONNECTION);
  if (close || error || !SESSTAT_ISSET (ses->dks_session, SST_OK))
    {
      ws->ws_try_pipeline = 0;
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
    }
  else
    http_session_used (ses, host, peer_max_timeout);

  log_info_http (ws, http_req_stat, (plen > 0 ? plen : 0));
  HTTP_SET_STATUS_LINE (ws, REPLY_SENT, 1);
}


#define ENC_B64_NAME "encode_base64"
#define DEC_B64_NAME "decode_base64"

char base64_vec[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
char base64url_vec[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_\0";

size_t
encode_base64_impl (char * input, char * output, size_t len, char * table)
{
  unsigned char	c;
  int  n = 0,
    i,
    count = 0,
    j = 0,
    x = 0;
  unsigned long	val = 0;
  unsigned char	enc[4];

  for (j=0 ; ((uint32) j) < len; j++)
    {
      c = input[j] ;
      if (n++ <= 2)
	{
	  val <<= 8;
	  val += c;
	  continue;
	}

      for (i = 0; i < 4; i++)
	{
	  enc[i] = (unsigned char) (val & 63);
	  val >>= 6;
	}

      for (i = 3; i >= 0; i--)
	output[x++] = table[enc[i]];
      n = 1;
      count += 4;
      val = c;
      if (count >= 70)
	{
	  output[x++] = '\r';
	  output[x++] = '\n';
	  count = 0;
	}
    }
  if (n == 1)
    {
      val <<= 16;
      for (i = 0; i < 4; i++)
	{
	  enc[i] = (unsigned char) (val & 63);
	  val >>= 6;
	}
      enc[0] = enc[1] = 64;
    }
  if (n == 2)
    {
      val <<= 8;
      for (i = 0; i < 4; i++)
	{
	  enc[i] = (unsigned char) (val & 63);
	  val >>= 6;
	}
      enc[0] = 64;
    }
  if (n == 3)
    for (i = 0; i < 4; i++)
      {
	enc[i] = (unsigned char) (val & 63);
	val >>= 6;
      }
  if (n)
    {
      for (i = 3; i >= 0; i--)
	output[x++] = table[enc[i]];
    }

  return x;
}


caddr_t
bif_encode_base64(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dest;
  caddr_t res;
  caddr_t src = bif_string_arg (qst, args, 0, ENC_B64_NAME);
  dtp_t dtp = DV_TYPE_OF (src);
  size_t len = box_length(src);

  if (IS_STRING_DTP(dtp) || dtp == DV_C_STRING)
    len--;

  if ((len * 2 + 1) > MAX_BOX_LENGTH)
    sqlr_new_error ("22023", "HT081", "The input string is too large");

  dest = dk_alloc_box(len * 2 + 1, DV_SHORT_STRING);
  len = encode_base64 ((char *)src, (char *)dest, len);
  *(dest+len) = 0;

  res = box_dv_short_string(dest);
  dk_free_box(dest);
  return(res);
}

caddr_t
bif_encode_base64url(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dest;
  caddr_t res;
  caddr_t src = bif_string_arg (qst, args, 0, ENC_B64_NAME);
  dtp_t dtp = DV_TYPE_OF (src);
  size_t len = box_length(src);

  if (IS_STRING_DTP(dtp) || dtp == DV_C_STRING)
    len--;

  if ((len * 2 + 1) > MAX_BOX_LENGTH)
    sqlr_new_error ("22023", "HT081", "The input string is too large");

  dest = dk_alloc_box(len * 2 + 1, DV_SHORT_STRING);
  len = encode_base64_impl ((char *)src, (char *)dest, len, B64_URL);
  *(dest+len) = 0;

  res = box_dv_short_string(dest);
  dk_free_box(dest);
  return(res);
}

static void
base64_store24(char ** d, char * c)
{
    *(*d)++=(c[0]<<2)+(c[1]>>4);
    *(*d)++=((c[1]<<4)&255)+(c[2]>>2);
    *(*d)++=((c[2]<<6)&255)+c[3];
}

size_t
decode_base64_impl (char * src, char * end, char * table)
{
    char * start = src;
    char c0, c[4], *p;
    size_t i=0;
    char *d=src;
    if (!src || !*src || src == end)
      return 0;
    while ((c0 = *src++) && src < end) {
	if (c0=='=')
	  break; /* a = symbol is end padding */
	if ((p=strchr(table, c0))) {
	  c[i++]=(char) (p-table);
	  if (i==4) {
	    base64_store24(&d, c);
	    i=0;
	  }
       } /* unknown symbols are ignored */
    }
    if (i>0) {
	for(;i<4;c[i++]=0)
	  ; /* will leave padding nulls - does not matter here */
       base64_store24(&d, c);
    }
    *d=0;
    if (*(d - 1) == 0) {
      if (*(d - 2) == 0)
	d -= 2;
      else
	d -= 1;
    }
    return (d - start);
}

caddr_t
bif_decode_base64(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t src = bif_string_arg (qst, args, 0, DEC_B64_NAME);
  caddr_t res, buf;
  size_t len, blen;

  blen = box_length(src);
  buf = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf, src, blen);

  len = decode_base64(buf, buf + blen);
  res = dk_alloc_box (len + 1, DV_SHORT_STRING);
  memcpy (res, buf, len);
  res[len] = 0;
  dk_free_box(buf);

  return (res);
}

caddr_t
bif_decode_base64url (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t src = bif_string_arg (qst, args, 0, DEC_B64_NAME);
  caddr_t res, buf;
  size_t len, blen;

  blen = box_length(src);
  buf = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf, src, blen);

  len = decode_base64_impl (buf, buf + blen, B64_URL);
  res = dk_alloc_box (len + 1, DV_SHORT_STRING);
  memcpy (res, buf, len);
  res[len] = 0;
  dk_free_box(buf);

  return (res);
}


dk_session_t *
http_connect (char * uri, caddr_t * err_ret, caddr_t ** head_ret, caddr_t method,
    caddr_t header, caddr_t body, caddr_t proxy, int strses_body)
{
  int rc, resp_readed = 0;
  dk_set_t head = NULL;
#ifndef _USE_CACHED_SES
  dk_session_t * ses = dk_session_allocate (SESCLASS_TCPIP);
#else
  dk_session_t * volatile ses = NULL;
  volatile int cached = 0;
#endif
  char req[0x1000];
  char host[1000];
  char * slash, * http_pos, *content_type;
  timeout_t timeout;
  char len_fld [128];
  char ua_fld [128];
  timeout.to_sec = 10;
  timeout.to_usec = 0;
  *err_ret = NULL;
  if (strlen (uri) > sizeof (req) - 100)
    {
      strcpy_ck (req, "URI is too long in http_get(): ");
      strncat_ck (req, uri , sizeof (req) - 40);
      *err_ret = srv_make_new_error ("22023", "HT018", "%s", req);
      return NULL;
    }
  if (proxy == NULL)
    {
      slash = strchr (uri, '/');
      if (!slash)
	slash = uri + strlen (uri);
      memcpy (host, uri, slash - uri);
      host[slash - uri] = 0;
    }
  else
    {
      http_pos = strstr (uri, "http://") + 7;
      slash = strchr (http_pos, '/');
      if (!slash)
	slash = http_pos + strlen (http_pos);
      memcpy (host, http_pos, slash - http_pos);
      host[slash - http_pos] = 0;
      slash = uri;
    }

  content_type = "";
  if (body != NULL)
    {
      long body_length = (strses_body ? strses_length ((dk_session_t *) body) : (long)(box_length (body) - 1));
      snprintf (len_fld, sizeof (len_fld), "Content-Length: %ld\r\n", body_length);
      if (method && !stricmp (method, "POST")
	  && (!header || !nc_strstr ((unsigned char *) header, (unsigned char *) "Content-Type:")))
	content_type = "Content-Type: application/x-www-form-urlencoded\r\n";
    }
  else
    strcpy_ck (len_fld, "");

  if (header && strlen(header) < 1)
    header = NULL;

  if ((NULL == header) || (header != NULL && NULL == nc_strstr ((unsigned char *) header, (unsigned char *) "User-Agent:")))
    snprintf (ua_fld, sizeof (ua_fld), "User-Agent: %s\r\n", http_client_id_string);
  else
    strcpy_ck (ua_fld, "");

snprintf (req, sizeof (req), "%s %s HTTP/1.1\r\n"
	      "Host: %s\r\n"
	      "%s"
#ifndef _USE_CACHED_SES
	      "Connection: close\r\n"
#else
	      "Connection: Keep-Alive\r\n"
#endif
	      "%s%s"
	      "%s"
	      "%s\r\n",
	      ((method != NULL) ? method : "GET"),
	      (slash && *slash != 0) ? slash : "/",
	      host,
	      ua_fld,
	      ((header != NULL) ? header : ""), ((header != NULL) ? "\r\n" : ""),
	      content_type,
	      len_fld);

http_trace (("HTTP Request : \n%s\n", req));

#ifndef _USE_CACHED_SES
  if (proxy == NULL)
    {
      if (!strchr (host, ':'))
	strcat_ck (host, ":80");
      rc = session_set_address (ses->dks_session, host);
    }
  else
    {
      if (!strchr (proxy, ':'))
	{
	  *err_ret = srv_make_new_error ("22023", "HT019", "Proxy must contain port number");
	  return NULL;
	}
      rc = session_set_address (ses->dks_session, proxy);
    }
  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "HT020", "Cannot resolve host in http_get %s", uri);
      return NULL;
    }
/*  session_set_control (ses->dks_session, SC_TIMEOUT, &timeout, sizeof (timeout_t));*/
  rc = session_connect (ses->dks_session);

  if (!_thread_sched_preempt)
    {
      timeout=dks_fibers_blocking_read_default_to;
      ses->dks_read_block_timeout = timeout;
    }
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "HT021", "Cannot connect in http_get %s", uri);
      return NULL;
    }
#else
    ses = http_cached_session (((proxy == NULL) ? host : proxy));
    if (ses)
      cached = 1;
    else
      {
	ses = http_dks_connect (((proxy == NULL) ? host : proxy), err_ret);
	if (*err_ret)
	  return NULL;
      }
#endif

  CATCH_WRITE_FAIL (ses)
    {
      session_buffered_write (ses, req, strlen (req));
      if (body != NULL)
	{
	  if (!strses_body)
	    session_buffered_write (ses, body, box_length (body) - 1);
	  else
	    strses_write_out ((dk_session_t *) body, ses);
	}
    }
#ifdef _USE_CACHED_SES
  FAILED
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      if (cached)
	{
	  return (http_connect (uri, err_ret, head_ret, method, header, body, proxy, strses_body));
	}
      else
	{
	  *err_ret = srv_make_new_error ("08007", "HT022", "Error in writing to the target HTTP server");
	  return NULL;
	}
    }
#endif
  END_WRITE_FAIL (ses);
  session_flush (ses);


  PROCESS_ALLOW_SCHEDULE();

  CATCH_READ_FAIL (ses)
    {
      int cont = 1, i;
      for (i=0;i<1024;i++)
	{
	  rc = dks_read_line (ses, req, sizeof (req));
	  if (!cont && rc <= 2)
	    break;
	  if (i==0 && !strncmp (req, "HTTP/1.1 100", 12))
	    cont = 1;
	  else if (!strncmp (req, "HTTP/1.", 7))
	    cont = 0;
	  if (!cont)
	    dk_set_push (&head, box_dv_short_string (req));
	}

      if (!cont)
	resp_readed = 1;

    }
#ifdef _USE_CACHED_SES
  FAILED
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      if (cached)
	{
	  return (http_connect (uri, err_ret, head_ret, method, header, body, proxy, strses_body));
	}
      else
	{
	  *err_ret = srv_make_new_error ("08006", "HT023", "Error in reading from target HTTP server");
	  return NULL;
	}
    }
#endif
  END_READ_FAIL (ses);
  if (!resp_readed)
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08006", "HT023", "Error in reading from target (no HTTP response supplied)");
      return NULL;
    }
  *head_ret = (caddr_t *) list_to_array (dk_set_nreverse (head));
  return ses;
}


long
ws_content_length (caddr_t * head)
{
  int inx;
  DO_BOX (caddr_t, line, inx, head)
    {
      if (0 == strnicmp (line, "Content-length:", 15))
	{
	  long ret = atoi (line + 15);
	  if (ret >= 0)
	    return ret;
	  else
	    return -1;
	}
    }
  END_DO_BOX;
  return -1;
}


char *
ws_header_field (caddr_t * head, const char * f, char * deflt)
{
  int inx;
  DO_BOX (caddr_t, line, inx, head)
    {
      if (0 == strnicmp (line, f, strlen (f)))
	return (line + strlen (f));
    }
  END_DO_BOX;
  return deflt;
}


caddr_t
ws_mime_header_field (caddr_t * head, char * f, char *subf, int initial_mode)
{
  int inx;
  dk_session_t *ses = NULL;
  DO_BOX (caddr_t, line, inx, head)
    {
      int rfc822 = initial_mode, offset = 0, override_to_mime = (subf ? 1 : 0);
      char szName[1024], szValue[1024*16];
      if (!DV_STRINGP (line))
	continue;
      while (0 <=  (offset =
	  mime_get_attr (
	    line,
	    (long) offset,
	    ':',
	    &rfc822,
	    &override_to_mime,
	    szName, sizeof (szName),
	    szValue, sizeof (szValue)
	  ))
	 )
	{
	  if (!stricmp (f, szName))
	    {
	      size_t len;
	      char *szPtr;

	      if (subf)
		{
		  while (-1 != (offset = mime_get_attr (line,
			  offset, '=', &rfc822, &override_to_mime, szName, sizeof (szName), szValue, sizeof (szValue))))
		    if (!stricmp (szName, subf))
		      break;
		  if (offset == -1)
		    return NULL;
		}

	      len = strlen (szValue);
	      if (len)
		{
		  szPtr = szValue + len - 1;
		  while (szPtr > szValue && isspace (*szPtr))
		    *szPtr-- = 0;
		  szPtr = szValue;
		  while (*szPtr && isspace (*szPtr))
		    szPtr++;
		}
	      else
		szPtr = szValue;
	      if (!ses)
	        {
		  ses = strses_allocate ();
		  session_buffered_write (ses, szValue, strlen (szValue));
	          /*return box_dv_short_string (szValue);*/
		}
	      else
		{
		  session_buffered_write (ses, ", ", 2);
		  session_buffered_write (ses, szValue, strlen (szValue));
		}
	    }
	}
    }
  END_DO_BOX;
  if (NULL != ses)
    {
      caddr_t ret = strses_string (ses);
      dk_free_box ((box_t) ses);
      return ret;
    }
  return NULL;
}

caddr_t
bif_http_proxy (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t host = bif_string_arg (qst, args, 0, "http_proxy");
  caddr_t * head = (caddr_t *) bif_array_arg (qst, args, 1, "http_proxy");
  caddr_t * body = (caddr_t *) bif_arg (qst, args, 2, "http_proxy");
  dk_session_t * ent_ses = NULL;
  int dtp = DV_TYPE_OF (body);

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT024", "http_proxy only allowed inside HTTP request");
  if (!http_proxy_enabled && !qi->qi_client->cli_ws->ws_map)
    sqlr_new_error ("42000", "HT025", "HTTP proxy function disabled.");

  if (dtp == DV_STRING_SESSION)
    {
      ent_ses = (dk_session_t *) body;
      body = NULL;
    }
  else if (dtp != DV_ARRAY_OF_POINTER && dtp != DV_DB_NULL)
    sqlr_new_error ("22023", "SR013",
	  "Function http_proxy needs an array as argument 3, "
	  "not an arg of type %s (%d)", dv_type_title (dtp), dtp);



  IO_SECT (qst);
  http_proxy (qi->qi_client->cli_ws, host, head, body, ent_ses);
  END_IO_SECT (err_ret);
  return 0;
}


caddr_t
http_read_chunked_content (dk_session_t *ses, caddr_t *err_ret, char *uri, int allow_ses)
{
  caddr_t res = NULL;
  dk_session_t *chunks = strses_allocate ();
  char line [4096];
  int icnk = 0;
  int readed = 0;
  strses_enable_paging (chunks, http_ses_size);
  CATCH_READ_FAIL (ses)
    {
      for (;;)
	{
	  readed = dks_read_line (ses, line, sizeof (line));
	  if (1 != sscanf (line,"%x", (unsigned *)(&icnk)))
	    break;
	  if (!icnk && readed)
	    {
	      readed = dks_read_line (ses, line, sizeof (line));
	      break;
	    }
	  while (icnk > 0)
	    {
	      readed = MIN (icnk, sizeof (line));
	      session_buffered_read (ses, line, readed);
	      icnk -= readed;
	      session_buffered_write (chunks, line, readed);
	      tcpses_check_disk_error (chunks, NULL, 1);
	    }
	  readed = dks_read_line (ses, line, sizeof (line));
	}
      session_flush_1 (chunks);
    }
  END_READ_FAIL (ses);
  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      if (err_ret)
	*err_ret = srv_make_new_error ("08006", "HT026", "Error in mid read in http_get %s", uri);
      else
	sqlr_new_error ("08006", "HT027", "Error in mid read in http_get %s", uri);
    }
  if (!STRSES_CAN_BE_STRING (chunks))
    {
      if (!allow_ses)
	{
	  if (err_ret)
	    *err_ret = STRSES_LENGTH_ERROR ("read_chunked_content");
	  else
	    sqlr_new_error ("22023", "HT028", "Content length exceeds 10Mb limit");
	  strses_free (chunks);
	  res = NULL;
	}
      else
	{
	  res = (caddr_t) chunks;
	}
    }
  else
    {
      res = strses_string (chunks);
      strses_free (chunks);
    }
  return res;
}

int32 http_enable_client_cache = 0;

caddr_t
http_client_cache_hash (caddr_t head, caddr_t body)
{
  caddr_t res;
  dk_session_t * ses = strses_allocate();
  ptrlong len;
  CATCH_WRITE_FAIL(ses)
    {
      if (head)
	{
	  len = box_length (head);
	  session_buffered_write (ses, head, len);
	}
      if (body)
	{
	  len = box_length (body);
	  session_buffered_write (ses, body, len);
	}
    }
  END_READ_FAIL (ses);
  if (strses_length (ses))
    res = md5_ses (ses);
  else
    res = box_dv_short_string ("");
  strses_free (ses);
  return res;
}

caddr_t
http_client_cache_get (query_instance_t * qi, caddr_t url, caddr_t header, caddr_t body, state_slot_t ** args, int arg_pos)
{
  static query_t * qr;
  local_cursor_t * lc;
  caddr_t err = NULL;
  caddr_t ret = NULL;

  if (!http_enable_client_cache)
    return NULL;

  if (!qr)
    qr = sql_compile_static ("select HCC_HEADER, HCC_BODY from DB.DBA.SYS_HTTP_CLIENT_CACHE "
	" where HCC_URI = ? and HCC_HASH = ?", qi->qi_client, &err, 0);
  if (err)
    {
      log_error ("Error compiling http cache retrieval statement : %s: %s",
	  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
      dk_free_tree (err);
      return NULL;
    }
  err = qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 2,
      ":0", url, QRP_STR,
      ":1", http_client_cache_hash (header, body), QRP_RAW);
  if (err)
    {
      log_error ("Error retrieving http client cache : %s: %s",
	  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
      dk_free_tree (err);
    }
  else
    {
      while (lc_next (lc))
	{
	  caddr_t body = lc_nth_col (lc, 1);
	  dtp_t dtp = DV_TYPE_OF (body);
	  if (BOX_ELEMENTS (args) > arg_pos && ssl_is_settable (args[arg_pos]))
	    {
	      caddr_t * head = (caddr_t *) lc_nth_col (lc, 0);
	      qst_set ((caddr_t *) qi, args[arg_pos], box_copy_tree (head));
	    }
	  if (IS_BLOB_HANDLE_DTP (dtp))
	    {
	      blob_handle_t * bh = (blob_handle_t *) body;
	      if (bh->bh_length > 10000000)
		ret = (caddr_t) blob_to_string_output (qi->qi_trx, body);
	      else
		ret = blob_to_string (qi->qi_trx, body);
	    }
	  else if (dtp == DV_BIN)
	    {
	      int len = box_length (body);
	      ret = dk_alloc_box (len + 1, DV_STRING);
	      memcpy (ret, body, len);
	      ret[len] = '\0';
	    }
	  else
	    ret = body ? box_copy (body) : NEW_DB_NULL;
	}
    }
  if (lc)
    lc_free (lc);
  return ret;
}

void
http_client_cache_register (query_instance_t * qi, caddr_t url, caddr_t header, caddr_t req_body, caddr_t * head, caddr_t body)
{
  static query_t * qr;
  caddr_t err = NULL;

  if (!body || !http_enable_client_cache)
    return;
  if (!qr)
    qr = sql_compile_static ("insert replacing DB.DBA.SYS_HTTP_CLIENT_CACHE (HCC_URI, HCC_HEADER, HCC_BODY, HCC_HASH) "
	"values (?,?,?,?)", qi->qi_client, &err, 0);
  if (err)
    {
      log_error ("Error compiling http cache register statement : %s: %s",
	  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
      dk_free_tree (err);
      err = NULL;
      return;
    }
  err = qr_rec_exec (qr, qi->qi_client, NULL, qi, NULL, 4,
      ":0", url, QRP_STR,
      ":1", box_copy_tree (head), QRP_RAW,
      ":2", body, QRP_STR,
      ":3", http_client_cache_hash (header, req_body), QRP_RAW);

  if (err)
    {
      log_error ("Error registering http client cache : %s: %s",
	  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
      dk_free_tree (err);
      err = NULL;
    }
}

caddr_t
bif_http_client_cache_enable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *) qst, "http_client_cache_enable");
  http_enable_client_cache = bif_long_arg (qst, args, 0, "http_client_cache_enable");
  return NULL;
}

#if 0
caddr_t
bif_http_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  volatile caddr_t res = NULL;
  caddr_t uri = bif_string_or_uname_arg (qst, args, 0, "http_get");
  caddr_t err = NULL;
  caddr_t * head = NULL;
  int to_free_head = 1;
  dk_session_t * volatile ses = NULL;
  char *http_pos;
  volatile long len ;
  int n_args = BOX_ELEMENTS (args), strses_body = 0;
  caddr_t method = NULL;
  caddr_t header = NULL;
  caddr_t body = NULL;
  caddr_t volatile proxy = NULL;
  char * trf_enc = NULL;
  char * cont_enc = NULL;
  int resp_code = 0, no_body = 0;
  char * code_pos = NULL;
#ifdef _USE_CACHED_SES
  volatile int close = 1;
  char host[1000];
  long peer_max_timeout = 0;
#endif

  if (n_args > 2)
    method = bif_string_or_uname_arg (qst, args, 2, "http_get");
  if (n_args > 3)
    header = bif_string_or_null_arg (qst, args, 3, "http_get");
  if (n_args > 4)
    {
      body = bif_arg (qst, args, 4, "http_get");
      if (DV_TYPE_OF (body) != DV_STRING_SESSION)
	body = bif_string_or_null_arg (qst, args, 4, "http_get");
      else
	strses_body = 1;
    }
#ifdef DEBUG
  printf("\nhttp_get(\"%s\", ...)\n", uri);
#endif
  if (NULL != (res = http_client_cache_get ((query_instance_t *)qst, uri, header, body, args, 1)))
    return res;

  IO_SECT (qst);
  if (!(http_pos = strstr (uri, "http://")))
    {
      char err_msg [1000];
      err_msg [0] = 0;
      strncat_ck (err_msg, uri, sizeof (err_msg) - 1);
      sqlr_new_error("22023", "HT028", "no http protocol identifier in http_get URI %s", err_msg);
    }
  else
    {
      char * uri1 = http_pos + 7;
      char * slash = NULL;
      size_t host_len;

      slash = strchr (uri1, '/');
      if (!slash)
	slash = uri1 + strlen (uri1);
      host_len = MIN ((slash - uri1), sizeof (host));
      memcpy (host, uri1, host_len);
      host [host_len] = 0;

      if (http_cli_proxy_server && !http_cli_target_is_proxy_exception (host))
	proxy = http_cli_proxy_server;

      if (n_args > 5)
	proxy = bif_string_or_null_arg (qst, args, 5, "http_get");

      if (proxy == NULL)
	ses = http_connect (http_pos + 7, &err, &head, method, header, body, proxy, strses_body);
      else
	ses = http_connect (http_pos, &err, &head, method, header, body, proxy, strses_body);
    }

  if (err)
    sqlr_resignal (err);
  if (!ses)
    sqlr_new_error ("08006", "HT029", "Misc. error in connection in http_get %s", uri);
  len = ws_content_length (head);
  trf_enc = ws_header_field (head, "Transfer-Encoding:", "");
  while (*trf_enc && *trf_enc <= '\x20')
    trf_enc++;
  cont_enc = ws_header_field (head, "Content-Encoding:", "");
  while (*cont_enc && *cont_enc <= '\x20')
    cont_enc++;
  /* method head take length w/o body */
  if (method != NULL)
    if (strstr (method, "HEAD"))
      {
	len = -1;
	no_body = 1;
      }

  if (!no_body && head)
    {
      code_pos = ws_header_field (head, "HTTP/1.", NULL);
      if (code_pos)
	{
	  code_pos ++;
	  while (*code_pos && *code_pos <= '\x20')
	    code_pos++;
	  sscanf (code_pos, "%d", &resp_code);
	  if (resp_code == 304 || resp_code == 204)
	    no_body = 1;
	}
    }

  /* read the body */
  if (len != -1) /* Content-Length: NNN */
    {
      dk_session_t *cnt = strses_allocate ();
      char tmp [4096];
      int to_read = len, to_read_len = sizeof (tmp), readed = 0;

      strses_enable_paging (cnt, http_ses_size);
      CATCH_READ_FAIL (ses)
	{
	  do
	    {
	      if (to_read < to_read_len)
		to_read_len = to_read;
	      readed = session_buffered_read (ses, tmp, to_read_len);
	      session_buffered_write (cnt, tmp, readed);
	      tcpses_check_disk_error (cnt, qst, 1);
	      to_read -= readed;
	    }
	  while (to_read > 0);
	}
      END_READ_FAIL (ses);

      if (!DKSESSTAT_ISSET (ses, SST_OK))
	{
	  if (DKSESSTAT_ISSET (ses, SST_TIMED_OUT))
	    err = srv_make_new_error ("08006", "HT030", "Timed out on read in http_get %s", uri);
	  else
	    err = srv_make_new_error ("08006", "HT030", "Error in mid read in http_get %s", uri);
	}
      if (!STRSES_CAN_BE_STRING (cnt))
	res = (caddr_t) cnt;
      else
	{
	  res = strses_string (cnt);
	  strses_free (cnt);
	}
    }
  else if (0 == strncmp ( trf_enc, "chunked", 7)) /* chunked encoding */
    res = http_read_chunked_content (ses, &err, uri, 1);
  else if (!no_body) /* no Content-Length and not chunked, HTTP/1.0 server response going here */
    {
      dk_session_t *cnt = strses_allocate ();
      char tmp [4096];
      int rd = 0;
      strses_enable_paging (cnt, http_ses_size);
      for (;;)
	{
	  rd = 0;
	  CATCH_READ_FAIL (ses)
	    {
	      session_buffered_read_n (ses, tmp, sizeof (tmp), &rd);
	    }
	  END_READ_FAIL (ses);
	  if (rd < 1)
	    break;
	  session_buffered_write (cnt, tmp, rd);
	  tcpses_check_disk_error (cnt, qst, 1);
	}
      session_flush_1 (cnt);
      if (!STRSES_CAN_BE_STRING (cnt))
	res = (caddr_t) cnt;
      else
	{
	  res = strses_string (cnt);
	  strses_free (cnt);
	}
    }
#ifndef _USE_CACHED_SES
  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
#else
  if (!err)
    {
      code_pos = NULL;
      if (head)
	code_pos = ws_header_field (head, "HTTP/1.", NULL);

      if (!code_pos || *code_pos == '0')
	close = 1;
      else
	{
	  char * connection = ws_header_field (head, "Connection:", "");
	  while (*connection && *connection <= '\x20')
	    connection++;
	  close = 0;
	  if (0 == strnicmp (connection, "close", 5))
	    close = 1;
	  if (0 == strnicmp (connection, "Keep-Alive", 10))
	    {
	      char * keep_alive;
	      close = 0;
	      keep_alive = ws_header_field (head, "Keep-Alive:", "");
	      while (*keep_alive && *keep_alive <= '\x20')
		keep_alive++;
	      keep_alive = strchr (keep_alive, '=');
	      if (keep_alive)
		sscanf (keep_alive, "=%ld", &peer_max_timeout);
	    }
	}
    }
  if (close || err || !SESSTAT_ISSET (ses->dks_session, SST_OK))
    {
      session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
    }
  else
    {
      http_session_used (ses, ((proxy != NULL) ? proxy : host),
			 peer_max_timeout);
    }
#endif
  *err_ret = err;
  if (BOX_ELEMENTS (args) > 1 && ssl_is_settable (args[1]))
    {
      qst_set (qst, args[1], (caddr_t) head);
      to_free_head = 0;
    }
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (res);
      res = NULL;
    }
  if (cont_enc && 0 == strncmp (cont_enc, "gzip", 4))
    {
      dk_session_t *out = strses_allocate ();
      strses_enable_paging (out, http_ses_size);
      zlib_box_gzip_uncompress (res, out, err_ret);
      dk_free_tree (res);
      if (!STRSES_CAN_BE_STRING (out))
	res = (caddr_t) out;
      else
	{
	  res = strses_string (out);
	  dk_free_box (out);
	}
    }
  http_client_cache_register ((query_instance_t *)qst, uri, header, body, head, res);
  if (to_free_head)
    dk_free_tree ((caddr_t) head);
  return res;
}
#endif


caddr_t
bif_string_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * ret = strses_allocate ();
  long fit_in_memory = 0;

  if (BOX_ELEMENTS (args) > 0)
    {
      fit_in_memory = (long) bif_long_arg (qst, args, 0, "string_output");
      strses_enable_paging (ret, fit_in_memory);
    }

  return ((caddr_t) ret);
}


caddr_t
bif_string_output_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t strses = bif_strses_arg (qst, args, 0, "string_output_flush");
  strses_flush ((dk_session_t *) strses);
  return (NULL);
}


caddr_t
bif_http_output_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * strses = http_session_no_catch_arg (qst, args, 0, "http_output_flush");
  if (DV_TYPE_OF (strses) != DV_STRING_SESSION)
    sqlr_new_error ("22023", "HT031",
		"The HTTP output is not an STRING session in http_output_flush");
  strses_flush ( strses);
  return (NULL);
}


caddr_t
bif_string_output_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t strses = bif_strses_arg (qst, args, 0, "string_output_string");
  if (!STRSES_CAN_BE_STRING ((dk_session_t *) strses))
    {
      *err_ret = STRSES_LENGTH_ERROR ("string_output_string");
      return NULL;
    }

  return (strses_string ((dk_session_t *) strses));
}

static caddr_t
bif_ses_read_line (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char buff[1024], *ptr;
  volatile int readed = 0, *pos_r, line_mode = 0;
  char binary_mode = 0;
  dk_session_t * volatile ses;
  dk_session_t * out = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  long to_throw = 1, at_error_return = 0;

  pos_r = &readed;

  if (BOX_ELEMENTS (args) > 2)
    {
      binary_mode = (char) bif_long_arg (qst, args, 2, "ses_read_line");
    }
  if (BOX_ELEMENTS (args) > 3)
    {
      line_mode = (int) bif_long_arg (qst, args, 3, "ses_read_line");
    }

  if (BOX_ELEMENTS (args) > 0)
    {
      ses = http_session_arg (qst, args, 0, "ses_read_line");
    }
  else
    {
      if (!qi->qi_client->cli_ws)
	sqlr_new_error ("42000", "HT032",
	    "ses_read_line with no argument defaults it direct to the raw client connection.\nAllowed only inside HTTP request");
      ses = qi->qi_client->cli_ws->ws_session;
    }

  if (BOX_ELEMENTS (args) > 1)
    {
      to_throw = (long) bif_long_arg (qst, args, 1, "ses_read_line");
    }

  IO_SECT (qst);
  CATCH_READ_FAIL (ses)
    {
      if (binary_mode)
	session_buffered_read_n (ses, buff, sizeof (buff), (int *) pos_r);
      else if (0 == line_mode)
	readed = dks_read_line (ses, buff, sizeof (buff));
      else
	{
	  out = strses_allocate ();
	  for (;;)
	    {
	      char c = session_buffered_read_char (ses);
	      session_buffered_write_char (c, out);
	      if (c == 10)
		break;
	    }
	}
    }
  FAILED
    {
      dk_free_box ((box_t) out);
      if (to_throw)
	*err_ret = srv_make_new_error ("08003", "HT033", "cannot read from session");
      if (!binary_mode)
	at_error_return = 1;
    }
  END_READ_FAIL (ses);
  END_IO_SECT (err_ret);

  if (!to_throw && *err_ret)
    {
      dk_free_tree (*err_ret);
      *err_ret = NULL;
    }
  if (at_error_return)
    return NULL;

  if (binary_mode)
    return box_dv_short_nchars (buff, readed);

  if (out)
    {
      caddr_t ret;
      if (!STRSES_CAN_BE_STRING (out))
	{
	  *err_ret = STRSES_LENGTH_ERROR ("ses_read_line");
	  ret = NULL;
	}
      else
	ret = strses_string (out);
      dk_free_box ((box_t) out);
      return ret;
    }
  if (0 == line_mode)
    {
      ptr = buff + readed - 1;
      while (ptr >=  buff && (*ptr == '\x0D' || *ptr == '\x0A'))
	*ptr-- = 0;
    }
  return box_dv_short_string (buff);
}


static caddr_t
bif_ses_read (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t volatile res;
  dk_session_t * volatile ses, * out;
  int volatile error = 0, ret_ses = 0;
  long n;
  char buff [4096];
  int readed = 0;
  volatile int to_read = 0;
  volatile int to_read_len = 0;

  ses = http_session_arg (qst, args, 0, "ses_read");
  n = bif_long_arg (qst, args, 1, "ses_read");
  if (BOX_ELEMENTS (args) > 2)
    ret_ses = bif_long_arg (qst, args, 2, "ses_read");


  if (n > 10000000 && 0 == ret_ses)
    sqlr_new_error ("22023", ".....", "string too long in ses_read");

  out = strses_allocate ();
  IO_SECT (qst);
  to_read = n;
  to_read_len = sizeof (buff);
  do
    {

      if (to_read < to_read_len)
	to_read_len = to_read;
      CATCH_READ_FAIL (ses)
	{
	  readed = session_buffered_read (ses, buff, to_read_len);
	}
      FAILED
	{
	  strses_flush (out);
	  dk_free_box ((box_t) out);
	  error = 1;
	  goto err_end;
	}
      END_READ_FAIL (ses);

      to_read -= readed;
      if (readed > 0)
	session_buffered_write (out, buff, readed);
    }
  while (to_read > 0);
err_end:
  END_IO_SECT (err_ret);
  if (error)
    return dk_alloc_box (0, DV_DB_NULL);
  else if (0 == ret_ses)
    {
      res = strses_string (out);
      dk_free_box ((box_t) out);
    }
  else
    res = (caddr_t) out;
  return res;
}


static caddr_t
bif_ses_can_read_char (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  dk_session_t * ses;

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT032",
	"ses_can_read_char with no argument defaults it direct to the raw client connection.\nAllowed only inside HTTP request");
  ses = qi->qi_client->cli_ws->ws_session;


  if (ses->dks_in_read < ses->dks_in_fill)
    return (box_num (ses->dks_in_fill-ses->dks_in_read));

  return NULL;
}


caddr_t
bif_http_request_header (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  int n_args = BOX_ELEMENTS (args);
  caddr_t *lines = (caddr_t *) ((n_args > 0) ?   bif_array_arg (qst, args, 0, "http_request_header") : NULL);
  caddr_t name = ((n_args > 1) ?   bif_string_arg (qst, args, 1, "http_request_header") : NULL);
  caddr_t attr_name = ((n_args > 2) ?   bif_string_or_null_arg (qst, args, 2, "http_request_header") : NULL);
  caddr_t deflt = ((n_args > 3) ? bif_arg (qst, args, 3, "http_request_header") : NULL);
  caddr_t ret = NULL;
  if (lines && DV_ARRAY_OF_POINTER != DV_TYPE_OF (lines))
    sqlr_new_error ("22023", "SR012", "Function http_request_header needs an array as argument 1, "
	"not an arg of type %s (%d)", dv_type_title (DV_TYPE_OF (lines)), DV_TYPE_OF (lines));
  if (qi->qi_client->cli_ws && !lines)
    {
      return box_copy_tree ((box_t) qi->qi_client->cli_ws->ws_lines);
    }
  else
    {
      if (lines)
	ret = ws_mime_header_field (lines, name, attr_name, 1);
      return (ret ? ret : box_copy (deflt));
    }
}


caddr_t
bif_http_request_header_full (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * szMe = "http_request_header_full";
  query_instance_t * qi = (query_instance_t *) qst;
  int n_args = BOX_ELEMENTS (args);
  caddr_t *lines = (caddr_t *) ((n_args > 0) ?   bif_array_arg (qst, args, 0, szMe) : NULL);
  caddr_t name = ((n_args > 1) ?   bif_string_arg (qst, args, 1, szMe) : NULL);
  caddr_t deflt = ((n_args > 2) ? bif_arg (qst, args, 2, szMe) : NULL);
  caddr_t ret = NULL;
  if (lines && DV_ARRAY_OF_POINTER != DV_TYPE_OF (lines))
    sqlr_new_error ("22023", "SR012", "Function %s needs an array as argument 1, "
	"not an arg of type %s (%d)", szMe, dv_type_title (DV_TYPE_OF (lines)), DV_TYPE_OF (lines));
  if (qi->qi_client->cli_ws && !lines)
    {
      return box_copy_tree ((box_t) qi->qi_client->cli_ws->ws_lines);
    }
  else
    {
      if (lines)
	{
	  int inx;
	  size_t len;
	  char *p, *q;
	  dk_session_t *ses = NULL;
	  DO_BOX (caddr_t, line, inx, lines)
	    {
	      if (!DV_STRINGP (line))
		continue;
	      p = strchr (line, ':');
	      len = p - line;
	      if (p && !strncasecmp (line, name, len) && !name[len])
		{
		  len = strlen (++p);
		  if (len)
		    {
		      q = p + len - 1;
		      while (q > p && isspace (*q))
			*q-- = 0;
		      q = p;
		      while (*q && isspace (*q))
			q++;
		    }
		  else
		    q = p;
		  if (!ses)
		    {
		      ses = strses_allocate ();
		      session_buffered_write (ses, q, strlen (q));
		    }
		  else
		    {
		      session_buffered_write (ses, ", ", 2);
		      session_buffered_write (ses, q, strlen (q));
		    }
		}
	    }
	  END_DO_BOX;
	  if (NULL != ses)
	    {
	      ret = strses_string (ses);
	      dk_free_box ((box_t) ses);
	    }
	}
      return (ret ? ret : box_copy (deflt));
    }
}


caddr_t
bif_http_param (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  int n_args = BOX_ELEMENTS (args);
  char * name = ((n_args > 0) ? bif_string_or_null_arg (qst, args, 0, "http_param") : NULL);
  if (qi->qi_client->cli_ws)
    {
      if (name)
	return box_copy_tree (ws_get_param (qi->qi_client->cli_ws, name));
      else
	return box_copy_tree ((box_t) qi->qi_client->cli_ws->ws_params);
    }
  return NULL;
}

caddr_t
bif_http_set_params (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  char * pars = bif_arg (qst, args, 0, "http_set_params");
  if (qi->qi_client->cli_ws)
    {
      int n_pars;
      if (!ARRAYP (pars))
	sqlr_new_error ("22023", "HTXXX", "An array is expected as parameter");
      n_pars = BOX_ELEMENTS (pars);
      if (0 != (n_pars % 2))
	sqlr_new_error ("22023", "HTXXX", "A name value pairs are expected as parameter");
      dk_free_tree (qi->qi_client->cli_ws->ws_params);
      qi->qi_client->cli_ws->ws_params = box_copy_tree (pars);
    }
  return NULL;
}

static void
ws_make_chunked (query_instance_t *qi, ws_connection_t *ws)
{
  if (ws->ws_xslt_url)
    sqlr_new_error ("42000", "HT063", "Chunked response and http_xslt not compatible");
  if (ws->ws_header &&
      NULL != nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Length:"))
    sqlr_new_error ("42000", "HT064", "Chunked response and Content-Length specified by http_header()");

  if (ws->ws_header &&
      NULL != nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Encoding:"))
    sqlr_new_error ("42000", "HT065", "Chunked response and Content-Encoding specified by http_header()");

  CHUNKED_STATE_SET (ws);
}


static caddr_t
bif_http_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  ws_connection_t *ws;
  int is_chunked = 0, try_chunked = 0, saved_try_pipeline;
  int go_direct = 0;
  const char *code;
  ptrlong res = 0;

  ws = qi->qi_client->cli_ws;
  if (!ws)
    sqlr_new_error ("42000", "HT034", "The http_flush not effective outside an VSP context");
  if (ws->ws_flushed && !IS_CHUNKED_OUTPUT (ws))
    sqlr_new_error ("42000", "HT035", "The http_flush already done");

  if (IS_CHUNKED_OUTPUT (ws))
    {
      volatile int len = strses_length (ws->ws_strses);
      CATCH_WRITE_FAIL (ws->ws_session)
	{
	  if (len > 0)
	    {
	      char tmp[20];
	      snprintf (tmp, sizeof (tmp), "%x\r\n", len);
	      SES_PRINT (ws->ws_session, tmp);
	      strses_write_out (ws->ws_strses, ws->ws_session);
	      SES_PRINT (ws->ws_session, "\r\n");
	      session_flush_1 (ws->ws_session);
	      strses_flush (ws->ws_strses);
	    }
	  res = 1;
	}
      FAILED
	{
	  if (!ws->ws_ignore_disconnect)
	    *err_ret = srv_make_new_error ("42000", "HT061", "Write to HTTP client output stream failed");
	}
      END_WRITE_FAIL (ws->ws_session);
      return box_num (res);
    }

  saved_try_pipeline = ws->ws_try_pipeline;

  if (BOX_ELEMENTS (args) > 0)
    {
      ptrlong arg = bif_long_arg (qst, args, 0, "http_flush");

      switch (arg)
	{
	  case 1 : try_chunked = 1; break;
          case 2 : go_direct = 1; break;
	}

      if (ws->ws_method != WM_HEAD && ws->ws_method != WM_OPTIONS && ws->ws_proto_no > 10)
	is_chunked = try_chunked;
    }

  code = "HTTP/1.1 200 OK";

  ws->ws_try_pipeline = 0;
  if (is_chunked)
    {
      ws_make_chunked (qi, ws);
      res = 1;
    }
  else if (try_chunked)
    {
      ws->ws_try_pipeline = saved_try_pipeline;
      return box_num (res);
    }

  if (go_direct)
    {
      if (ws->ws_xslt_url)
	sqlr_new_error ("42000", "HT071", "Direct output and http_xslt() not compatible");
      if (ws->ws_header && ws->ws_status_code != 101 &&
	  NULL == nc_strstr ((unsigned char *) ws->ws_header, (unsigned char *) "Content-Length:"))
	sqlr_new_error ("42000", "HT072", "Direct output requires Content-Length specified by http_header()");
    }

  ws_strses_reply (ws, code);
  ws->ws_flushed = 1;

  if (!is_chunked && !go_direct && !ws->ws_session->dks_to_close)
    {
      ws->ws_session->dks_ws_status = DKS_WS_FLUSHED;
      PrpcDisconnect (ws->ws_session);
    }

  if (go_direct && WM_HEAD != ws->ws_method && WM_OPTIONS != ws->ws_method)
    {
      caddr_t *res = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_CONNECTION);
      res[0] = (caddr_t) ws->ws_session;
      res[1] = 0;
      return (caddr_t) res;
    }
  return box_num (res);
}


caddr_t
bif_http_auth (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  char *auth;

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT036", "The http_auth not effective outside an VSP context");

  auth = ws_get_packed_hf (qi->qi_client->cli_ws, "Authorization:", "");
  return auth ? auth : box_dv_short_string ("");
}

caddr_t
bif_server_http_port (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_dv_short_string (http_port);
}


caddr_t
bif_server_https_port (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return https_port ? box_dv_short_string (https_port) : NEW_DB_NULL;
}


caddr_t
int_client_ip (query_instance_t * qi, long dns_name)
{
  caddr_t iaddr, ret;

  if (!qi->qi_client->cli_ws && !qi->qi_client->cli_session) /* via scheduler or some internal client */
    {
      if (dns_name)
	return box_dv_short_string ("localhost");
      else
	return box_dv_short_string ("127.0.0.1");
    }

  if (!qi->qi_client->cli_ws)
    iaddr = http_client_ip (qi->qi_client->cli_session->dks_session);
  else
    iaddr = qi->qi_client->cli_ws->ws_client_ip;

  if (dns_name)
    ret = ws_gethostbyaddr (iaddr);
  else
    ret = box_copy (iaddr);

  if (!qi->qi_client->cli_ws)
    dk_free_box (iaddr);

  return ret;
}


caddr_t
bif_http_client_ip (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  long dns_name = BOX_ELEMENTS (args) > 0 ? (long) bif_long_arg (qst, args, 0, "http_client_ip") : 0;
  return int_client_ip (qi, dns_name);
}


caddr_t
bif_sys_connected_server_address (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  char buf[100];
  session_t *ses;

  /* when running as internal client */
  if (!qi->qi_client->cli_ws && !qi->qi_client->cli_session)
    return NEW_DB_NULL;

  ses = qi->qi_client->cli_ws && qi->qi_client->cli_ws->ws_session ?
      qi->qi_client->cli_ws->ws_session->dks_session : qi->qi_client->cli_session->dks_session;

  if (!tcpses_getsockname (ses, buf, sizeof (buf)))
    {
#ifdef COM_UNIXSOCK
      if (BOX_ELEMENTS(args) &&
          1 == bif_long_arg (qst, args, 0, "sys_connected_server_address"))
        {
          int port;

          /* try to perform backward conversion for unix sockets*/
          if (!strncmp (buf, UNIXSOCK_ADD_ADDR, sizeof (UNIXSOCK_ADD_ADDR) - 1)
              && (port = atoi (buf + sizeof (UNIXSOCK_ADD_ADDR) - 1)))
            snprintf (buf, sizeof (buf), "localhost:%d", port);
        }
#endif
      return box_dv_short_string (buf);
    }
  sqlr_new_error ("08003", "HT038", "Server address not known");
  return NULL;
}


caddr_t
bif_http_xslt (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
#ifdef BIF_XML
  query_instance_t * qi = (query_instance_t *) qst;
  ws_connection_t *ws = qi->qi_client->cli_ws;
  caddr_t xslt_url = bif_string_or_null_arg (qst, args, 0, "http_xslt");
  caddr_t params = NULL;

  if (BOX_ELEMENTS (args) > 1)
    params = bif_array_or_null_arg (qst, args, 1, "http_xslt");

  if (!ws)
    sqlr_new_error ("42000", "HT039", "Not allowed to call the http_xslt in an non VSP context");

  dk_free_tree (ws->ws_xslt_url);
  ws->ws_xslt_url = xslt_url ? box_dv_short_string (xslt_url) : NULL;
  dk_free_tree (ws->ws_xslt_params);
  ws->ws_xslt_params = box_copy_tree (params);
#endif
  return NULL;
}

static char *ws_def_expand_includes =
"create procedure expand_includes (in path varchar, inout stream varchar, in level integer, in body varchar, inout st any) \n"
"{ \n"
"  declare curr_file, new_file_name varchar; \n"
"  declare include_inx, end_tag_inx integer; \n"
" \n"
"  end_tag_inx := 0; \n"
"   if (body is null) \n"
"     { \n"
"       declare _cur_path, _p_lines_top, _p_lines_bottom any; \n"
"       _cur_path := concat (http_root (), path); \n"
"       _p_lines_top := \'<?vsp \'; \n"
"       if (level > 0) _p_lines_top := concat (_p_lines_top, \'#line push\\n\'); \n"
"       _p_lines_top := concat (_p_lines_top, sprintf (\'#line 1 \"%s\"\\n?>\', _cur_path)); \n"
"       _p_lines_bottom := \'\'; \n"
"       if (level > 0) _p_lines_bottom := \'<?vsp #line pop\\n ?>\'; \n"
"       curr_file := concat (_p_lines_top, file_to_string (_cur_path), _p_lines_bottom); \n"
"       if (st is not null and isarray (st) and level > 0) { \n"
"         st := vector_concat (st, vector (_cur_path, file_stat (_cur_path)));"
"       } \n"
"     } \n"
"   else \n"
"     curr_file := body; \n"
" \n"
"  include_inx := strcasestr (curr_file, \'<?include\'); \n"
"  while (include_inx is not null) \n"
"    { \n"
"      if (level > 20) \n"
"	signal (\'37000\', sprintf (\'Max nesting level (20) reached when processing %s\', path), \'HT047\'); \n"
"      end_tag_inx := strstr (subseq (curr_file, include_inx, length (curr_file)), \'?>\'); \n"
" \n"
"      if (end_tag_inx is null) \n"
"	signal (\'37000\', sprintf (\'Unterminated include tag at offset %d in %s\', include_inx, path), \'HT048\'); \n"
"      end_tag_inx := end_tag_inx + include_inx; \n"
"      if (end_tag_inx - include_inx - 9 <= 0) \n"
"	signal (\'37000\',  \n"
"	    sprintf (\'An include tag at offset %d with no name or VSP end tag before an include tag in %s\',  \n"
"	      include_inx, path), \'HT049\'); \n"
" \n"
"      if (include_inx > 0) \n"
"	 http (subseq (curr_file, 0, include_inx), stream); \n"
" \n"
"      new_file_name := trim(subseq (curr_file, include_inx + 9, end_tag_inx)); \n"
" \n"
"      if (aref (new_file_name, 0) <> ascii(\'/\')) \n"
"	 expand_includes (concat (subseq (path, 0, strrchr(path, \'/\') + 1), new_file_name), stream, level + 1, NULL, st); \n"
"      else \n"
"	expand_includes (new_file_name, stream, level + 1, NULL, st); \n"
" \n"
"      if (end_tag_inx + 2 <= length (curr_file)) \n"
"	 curr_file := subseq (curr_file, end_tag_inx + 2, length (curr_file)); \n"
"      include_inx := strcasestr (curr_file, \'<?include\'); \n"
"    } \n"
"  if (length (curr_file) > 0) \n"
"    http (curr_file, stream); \n"
"} \n";

char * ws_def_1 =
"create procedure ws_proc_def (in path varchar)\n"
"{\n"
"  declare x, y, stat, msg varchar;\n"
"  declare str varchar;\n"
"  declare sti any;\n"
"  if (strstr (path, '..')) \n"
"    { \n"
"      http_request_status ('HTTP/1.1 400 Path contains ..'); \n"
"      return 0; \n"
"    } \n"
"  if ('no_vsp_recompile' = registry_get (path)) \n"
"    return 1; \n"
"  str := string_output (); \n"
" \n"
"  http (sprintf (\'create procedure \"%s\".\"%s\".\\\"\', http_map_get (\'vsp_qual\'), http_map_get (\'vsp_proc_owner\')), str); \n"
"  http (path, str); \n"
"  http (\'\\\" (in path varchar, in params any, in lines any) { if (length (params) < 1) params := __http_stream_params (); ?>\', str); \n"
"   \n"
"  sti := vector ();"
"  \n"
"  if (not isstring (file_stat (concat (http_root (), path)))) \n"
"    { \n"
"      http_rewrite (); http_file (path); \n"
"      return 0; \n"
"    }; \n"
"  expand_includes (path, str, 0, NULL, sti); \n"
"   \n"
"   \n"
"  http (\'<?vsp \n; }\', str); \n"
"  stat := '00000';\n"
"  str := string_output_string (str); \n"
/*"  dbg_printf ('$$$$\\n%s\\n####\\n', str); \n"*/
"  __set_user_id (http_map_get (\'vsp_uid\'), 0);\n"
"  declare warnings any;\n"
"  warnings := NULL; \n"
"  exec (str, stat, msg, vector (), 0, x, y, NULL, warnings);\n"
"  if (stat <> '00000')\n"
"    signal (stat, msg);\n"
"  if (warnings is not NULL) \n"
"    sql_warnings_resignal (warnings); \n"
"  registry_set (path, file_stat (concat (http_root (), path))); \n"
"   \n"
"  registry_set (concat (\'__depend_\', http_map_get (\'vsp_proc_owner\'), \'_\', path), serialize(sti)); \n"
"  \n"
"  return 1; \n"
"}";

char * ws_def_2_name = "WS.WS.DEFAULT";

char * ws_def_2 =
"create procedure WS.WS.\"DEFAULT\" (in path varchar, in params varchar, inout lines varchar)\n"
"{\n"
"  declare p1 varchar;\n"
"  declare p_len, slash integer;\n"
"  p1 := '';\n"
"  --dbg_obj_print (lines);\n"
"  if (__tag (path) = 193)\n"
"    p_len := length (path);\n"
"  else p_len := 0;\n"
#ifndef VIRTUAL_DIR
"  p1 := http_path ();\n"
#else
"  p1 := http_physical_path ();\n"
#endif
"  if (not isstring (p1))\n"
"    p1 := '';\n"
"  if (p1 = '' or p1 = '/') {\n"
"    http_file ('/index.html');\n"
"    return;\n"
"  }\n"
"  if (lower(p1) like 'http://%')\n"
"    {\n"
"      declare host, u, lpath varchar;\n"
"      u := aref (lines, 0); \n"
"      lpath := http_path(); \n"
"       \n"
"      if (p1 like '%/' and lpath not like '%/') \n"
"        {\n"
"          http_request_status ('HTTP/1.1 301 Moved Permanently');\n"
"          http_header (sprintf ('Location: %s/\\r\\n', lpath));\n"
"          return;\n"
"        }\n"
"      u := replace (u, lpath, p1, 1); \n"
/*"      dbg_obj_print ('proxy :', http_path(), p1); \n"*/
"      slash := strchr (subseq (p1, 8, length (p1)), '/');\n"
"      if (slash is null) \n"
"	{\n"
"	  slash := length (p1) - 7;\n"
"	}\n"
"      else\n"
"	{\n"
"	  slash := slash + 1;\n"
"	}\n"
"      host := substring (p1, 8, slash);\n"
"      u := replace (u, substring (p1, 1, slash+8), '/', 1); \n"
"      aset (lines, 0, u); \n"
/*"     dbg_obj_print ('proxy :', host, lines); \n"*/
"       if (not DB.DBA.HTTP_PROXY_ACCESS (host)) \n"
"	  signal (\'42000\', sprintf (\'Proxy access to %s denied due to access control\', host), \'HT059\'); \n"
"      http_proxy (host, lines, __http_stream_params ());\n"
"      return;\n"
"    }\n"
"  if (lower (p1) like '%.vsp' and isstring (http_map_get (\'vsp_uid\')))\n"
"    {\n"
"      if (ws_proc_def (p1))\n"
"	call (concat (sprintf ('%s.%s.', http_map_get (\'vsp_qual\'), http_map_get (\'vsp_proc_owner\')), p1)) (path, params, lines);\n"
"    }\n"
"  else if (lower (p1) like '%.vspx' and isstring (http_map_get (\'vsp_uid\')))\n"
"    {\n"
"      if (not isstring (file_stat (concat (http_root (), p1)))) \n"
"        { \n"
"          http_rewrite (); \n"
"          goto not_exist; \n"
"        }; \n"
"       vspx_dispatch (p1, path, params, lines); \n"
"    }\n"
"   else if (lower (p1) like \'%.vxml\' and isstring (http_map_get (\'vsp_uid\'))) \n"
"     { \n"
"       declare dot integer; \n"
"       declare p2, _xml, _xslt_uri, _doc_uri, ses, p3, stat, msg, result, ses2 varchar; \n"
"       dot := strrchr (p1, \'.\'); \n"
"       if (dot is null) \n"
" 	goto err_exit; \n"
"       p2 := concat (substring (p1, 1, dot), \'.vxsl\'); \n"
"       p3 := concat (substring (p1, 1, dot), \'.vsp\'); \n"
"       if (0 = file_stat (concat (http_root (), p2))) \n"
" 	goto err_exit; \n"
"       _doc_uri := concat (\'file://\', p1); \n"
"       _xslt_uri := WS.WS.EXPAND_URL (_doc_uri, p2); \n"
"       _xml := DB.DBA.XML_URI_GET (\'\', _doc_uri); \n"
"       result := xslt (_xslt_uri, xml_tree_doc (_xml, _doc_uri)); \n"
"       http_output_flush (); \n"
"       ses := string_output (); \n"
"       ses2 := string_output (); \n"
"       http_value (result, null, ses2); \n"
"       ses2 := string_output_string (ses2); \n"
"       http (sprintf (\'create procedure \"%s\".\"%s\".\\\"\', http_map_get (\'vsp_qual\'), http_map_get (\'vsp_proc_owner\')), ses); \n"
"       http (p3, ses); \n"
"       http (\'\" (in path varchar, in params varchar, in lines varchar) { ?>\', ses); \n"
"       declare vst any; \n"
"       vst := NULL; \n"
"       expand_includes (p3, ses, 0, ses2, vst); \n"
"       http (\'<?vsp }\', ses); \n"
"       stat := \'00000\'; \n"
"       ses := string_output_string (ses); \n"
"       __set_user_id (http_map_get (\'vsp_uid\'));\n"
"       declare warnings any;\n"
"       warnings := NULL; \n"
"       exec (ses, stat, msg, NULL, 0, NULL, NULL, NULL, warnings); \n"
"       if (stat <> \'00000\') \n"
"         signal (stat, msg); \n"
"       if (warnings is not NULL) \n"
"         sql_warnings_resignal (warnings); \n"
"       call (concat (sprintf ('%s.%s.', http_map_get (\'vsp_qual\'), http_map_get (\'vsp_proc_owner\')), p3)) (path, params, lines);\n"
"       return; \n"
"       err_exit: \n"
" 	http_file (p1); \n"
"     } \n"
"  else if (lower (p1) like '%.xml' and isstring (http_map_get (\'vsp_uid\')) and http_map_get (\'xml_templates\')) \n"
"     { \n"
"       if (not isstring (file_stat (concat (http_root (), p1)))) \n"
"         { \n"
"           http_rewrite (); \n"
"           goto not_exist; \n"
"         }; \n"
"       DB.DBA.__XML_TEMPLATE (path, params, lines);\n"
"     } \n"
"  else if (p_len = 1 and path[0] = 'services.wsil')\n"
"     { \n"
"       DB.DBA.SERVICES_WSIL (path, params, lines); \n"
"     } \n"
"  else if (lower (p1) not like '%.vsp' and lower (p1) not like '%.vspx')\n"
"    {\n"
"      declare fext varchar; \n"
"      declare is_exist, dot integer; \n"
"      is_exist := 0; \n"
"      if (not isstring (file_stat (concat (http_root (), p1))) and \n"
"         not (__proc_exists ('WS.WS.__http_handler_aspx', 1) is not null \n"
"              and (strstr (p1, '.asmx') is not null))) \n"
"        { \n"
"          http_rewrite (); \n"
"          goto not_exist; \n"
"        }; \n"
"      if (isstring (p1)) dot := strrchr (p1, '.'); \n"
"      if (dot is not null) { \n"
"        fext := DB.DBA.ws_get_ftext (p1, dot); \n"
"      } else \n"
"        fext := ''; \n"
"      if (__proc_exists (fext, 2)) \n"
"        is_exist := 1; \n"
"        else { \n"
"        fext := concat (\'WS.WS.\', fext); \n"
"        if (__proc_exists (fext, 1)) \n"
"          is_exist := 1; \n"
"        } \n"
"      if (is_exist) { \n"
"        declare hdl_mode, stream_params any; \n"
"        hdl_mode := NULL; \n"
"        stream_params := __http_stream_params (); \n"
"        if (isstring (http_map_get (\'vsp_uid\')))\n"
"          __set_user_id (http_map_get (\'vsp_uid\'));\n"
"        http (call (fext) (concat (http_root (), http_physical_path ()), stream_params, lines, hdl_mode)); \n"
"        if (isarray (hdl_mode) and length (hdl_mode) > 1) \n"
"          { \n"
"	     if (hdl_mode[0] <> '' and isstring (hdl_mode[0])) \n"
"	       http_request_status (hdl_mode[0]); \n"
"	     if (hdl_mode[1] <> '' and isstring (hdl_mode[1])) \n"
"	       http_header (hdl_mode[1]); \n"
"	   } \n"
"      } else { \n"
"   not_exist: \n"
"        http_body_read (); \n" /* just to be sure all content is read */
"        http_file (p1);\n"
"       } \n"
"    }\n"
"  else \n"
"    {\n"
"      http_request_status ('HTTP/1.1 403 Forbidden');\n"
"      http ('<HTML><BODY><H3>The requested active content cannot be displayed due to execution restriction</H3></BODY></HTML>'); \n"
"    }\n"
"}";

static char *ws_get_ftext =
"create procedure ws_get_ftext (in p1 varchar, in dot integer)\n"
"{\n"
"  if (__proc_exists ('WS.WS.__http_handler_aspx', 1) and (strstr (p1, '.asmx') is not null))\n"
"    return '__http_handler_aspx';\n"
"  else\n"
"    return concat ('__http_handler_', substring (p1, dot + 2, length (p1)));\n"
"}";


caddr_t *
box_tcpip_localhost_names (void)
{
  char szTemp[512];
  struct hostent *local;
  int nEntries = 1, inx = 0;
  caddr_t *_localhost_names;
#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS))
  char buff [4096];
  int herrnop;
  struct hostent ht;
#endif

  if (gethostname (szTemp, sizeof (szTemp)))
    strcpy_ck (szTemp, "localhost");
#if defined (_REENTRANT) && defined (linux)
  gethostbyname_r (szTemp, &ht, buff, sizeof (buff), &local, &herrnop);
#elif defined (_REENTRANT) && defined (SOLARIS)
  local = gethostbyname_r (szTemp, &ht, buff, sizeof (buff), &herrnop);
#else
  local = gethostbyname (szTemp);
#endif
  if (local)
    {
      if (local->h_aliases)
	{
	  while (local->h_aliases[nEntries - 1])
	    nEntries++;
	}
    }

  _localhost_names = (caddr_t *) dk_alloc_box (nEntries * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  _localhost_names[0] = box_string (local ? local->h_name : szTemp);

  if (local && local->h_aliases)
    for (inx = 0; local->h_aliases[inx]; inx++)
      _localhost_names[inx + 1] = box_string (local->h_aliases[inx]);
  return _localhost_names;
}

#ifdef VIRTUAL_DIR

id_hash_t * http_map;
id_hash_t * http_listeners;
id_hash_t * http_failed_listeners;
dk_mutex_t * http_listeners_mutex;
ws_http_map_t * http_default_map;
#if 0 /* not used */
caddr_t * all_host_names = NULL;
#endif
/*##********************************************************
* Add default port (:80) if not specified and copy input
* if input is *ini* copy http_port and return it
* if input is *sslini* copy https_port and return it
***********************************************************/
caddr_t
http_host_normalize_1 (caddr_t host, int to_ip, int def_port, int physical_port)
{
  char * sep;
  caddr_t host1, host2;
  int port = 0;
  char buf [6];

  if (!host)
    return NULL;

  if (!strcmp (host, "*ini*") && http_port)
    host2 = http_port;
  else if (!strcmp (host, "*sslini*") && https_port)
    host2 = https_port;
  else
    host2 = host;
  if (!host2)
    return NULL;

  host2 = box_string (host2);
  sep = strchr (host2, ':');
  if (sep) /* host:port notation */
    {
      *sep = 0;
      sep ++;
      port = atoi (sep);
    }
  else if (alldigits (host2)) /* just port numer  */
    {
      port = atoi (host2);
      host2[0] = 0;
    }
  /* else just host, default ports used, see next */

  if (port <= 0 || port >= 0xffff) /* non-numeric, bad port number, or no port given, then rollback to default  */
    port = def_port;

  if (physical_port && port != physical_port)
    port = physical_port;

  snprintf (buf, sizeof (buf), "%d", port);
  host1 = dk_alloc_box (strlen (host2) + strlen (buf) + 2, DV_SHORT_STRING);
  snprintf (host1, box_length (host1), "%s:%s", host2, buf);

  dk_free_box (host2);
  return host1;
}

caddr_t
http_host_normalize (caddr_t host, int to_ip)
{
  return http_host_normalize_1 (host, to_ip, 80, 0);
}

/*
   Internally all hosts should be represented as cname:nnn where nnn is port number.
   This function must be called with cname and listen interface e.g. 'localhost' and '0.0.0.0:8890'
*/
caddr_t
http_virtual_host_normalize (caddr_t _host, caddr_t lhost)
{
  char * sep;
  caddr_t host1, host2;
  caddr_t host;

  if (!_host || !lhost)
    return NULL;

  /* they are same, both are the default */
  if (!strcmp (_host, lhost))
    return http_host_normalize (_host, 0);

  host = box_copy (_host);
  sep = strchr (host, ':');
  if (sep)
    *sep = 0;

  if (!strcmp (lhost, "*ini*") && http_port)
    host2 = http_port;
  else if (!strcmp (lhost, "*sslini*") && https_port)
    host2 = https_port;
  else
    host2 = lhost;
  if (!host2)
    return NULL;

  sep = strchr (host2, ':');

  if (!sep && !alldigits (host2)) /* it listen on 80 on one of the NIC */
    {
      host1 = dk_alloc_box (strlen (host) + 4, DV_SHORT_STRING);
      snprintf (host1, box_length (host1), "%s:80", host2);
    }
  else if (!sep && alldigits (host2)) /* it listen on all interfaces */
    {
      host1 = dk_alloc_box (strlen (host2) + strlen (host) + 2, DV_SHORT_STRING);
      snprintf (host1, box_length (host1), "%s:%s", host, host2);
    }
  else /* it's non-default listener */
    {
      host1 = dk_alloc_box (strlen (sep) + strlen (host) + 1, DV_SHORT_STRING);
      snprintf (host1, box_length (host1), "%s%s", host, sep);
    }
  dk_free_box (host);
  return host1;
}


/*##********************************************************
* Add entry in HTTP virtual directories map hash
* takes 2 up to 12 parameters
* 1 - absolute logical path
* 2 - absolute physical path
* 3 - host alias (taken from Host: header field)
* 4 - listen host (witch host&port) listen for it
* 5 - is stored in WebDAV tables
* 6 - is directory browseable (if not specified default page or non existent page)
* 7 - default page (file name, can be VSP page)
* 8 - security method witch applied to the directory (0-none, 1-Digest, 2-SSL)
* 9 - realm
* 10 - authentication function (name)
* 11 - post process function
* 12 - uid for VSP execution
* 13 - uid for SOAP calls
* 14 - persistent session vars enabled
* 15 - SOAP options
* 16 - Authentication options
************************************************************/
caddr_t
bif_http_map_table (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t lpath = bif_string_arg (qst, args, 0, "http_map_table");
  caddr_t ppath = bif_string_arg (qst, args, 1, "http_map_table");
  caddr_t host = NULL, lhost = NULL, l_copy;
  caddr_t def_page = NULL, realm = NULL, fn = NULL, pfn = NULL, vsp_uid = NULL, soap_uid = NULL, sec = NULL;
  int nargs = BOX_ELEMENTS (args);
  caddr_t p_copy, l_host_default = NULL;
  ws_http_map_t * map;
  sec_check_dba ((query_instance_t *) qst, "http_map_table"); /* Virtual directory MUST be added only by DBA */

  p_copy = box_copy (ppath);
  map = (ws_http_map_t *) dk_alloc (sizeof (ws_http_map_t));
  memset (map, 0, sizeof (ws_http_map_t));

  if (nargs > 3)
    { /* virtual host or listen host */
      caddr_t virtual_host = bif_string_or_null_arg (qst, args, 2, "http_map_table");
      caddr_t listen_host  = bif_string_or_null_arg (qst, args, 3, "http_map_table");
      caddr_t vh;

      lhost = http_host_normalize (listen_host, 1);
      vh = http_virtual_host_normalize (virtual_host, listen_host);
      if (lhost && lhost[0] == ':' && vh && vh[0] == ':')
	{
	  host = box_dv_short_string ("*all*"); /*TODO: add all names for the host */
	  dk_free_box (vh); vh = NULL;
	}
      else
	host = vh;
      map->hm_host = box_copy (virtual_host);
      map->hm_lhost = box_copy (listen_host);
    }

  if (host && lhost)
    { /*if we have a host the key is //host/lhost/logical_path */
      l_copy = dk_alloc_box (box_length (lpath) + box_length (host) + box_length (lhost) + 1, DV_SHORT_STRING);
      snprintf (l_copy, box_length (l_copy), "//%s|%s%s", host, lhost, lpath);
      if (nargs > 17) /* we have is_default_host specified */
	{
	  caddr_t def_host = bif_arg (qst, args, 17, "http_map_table");
	  ptrlong is_default_host = 0;
	  dtp_t dtp = DV_TYPE_OF (def_host);

	  if (dtp == DV_LONG_INT || dtp == DV_SHORT_INT)
	    is_default_host = bif_long_arg (qst, args, 17, "http_map_table");

	  if (is_default_host)
	    {
	      l_host_default = dk_alloc_box (box_length (lpath) + (2 * box_length (lhost)) + 1, DV_SHORT_STRING);
	      snprintf (l_host_default, box_length (l_host_default), "//%s|%s%s", (lhost[0] == ':' ? "*all*" : lhost), lhost, lpath);
	    }
	}
      dk_free_box (host); dk_free_box (lhost);
    }
  else
    l_copy = box_copy (lpath);

  map->hm_p_path = p_copy;
  map->hm_l_path = box_copy (lpath);

  if (nargs > 4) /* store as dav */
    map->hm_is_dav = (int) bif_long_arg (qst, args, 4, "http_map_table");
  if (nargs > 5) /* browseable directory */
    map->hm_browseable =  (int) bif_long_arg (qst, args, 5, "http_map_table");
  if (nargs > 6) /* default page */
    def_page =  bif_string_or_null_arg (qst, args, 6, "http_map_table");
  map->hm_def_page = box_copy (def_page);
  if (nargs > 7) /* security method SSL/Digest Authentication for access */
    sec =  bif_string_or_null_arg (qst, args, 7, "http_map_table");
  map->hm_sec = box_copy (sec);
  if (nargs > 8) /* realm */
    realm =  bif_string_or_null_arg (qst, args, 8, "http_map_table");
  map->hm_realm = box_copy (realm);
  if (nargs > 10) /* post process function */
    pfn =  bif_string_or_null_arg (qst, args, 10, "http_map_table");
  map->hm_pfn = box_copy (pfn);
  if (nargs > 9) /* authentication function */
    fn =  bif_string_or_null_arg (qst, args, 9, "http_map_table");
  map->hm_afn = box_copy (fn);
  if (nargs > 11) /* uid for VSP execution */
    vsp_uid =  bif_string_or_null_arg (qst, args, 11, "http_map_table");
  map->hm_vsp_uid = box_copy (vsp_uid);
  if (nargs > 12) /* uid for SOAP execution */
    soap_uid =  bif_string_or_null_arg (qst, args, 12, "http_map_table");
  map->hm_soap_uid = box_copy (soap_uid);
  if (nargs > 13) /* persistent session variables  flag */
    map->hm_ses_vars =  (int) bif_long_arg (qst, args, 13, "http_map_table");
  if (nargs > 14)
    { /* SOAP options */
      caddr_t * opts = (caddr_t *) bif_array_or_null_arg (qst, args, 14, "http_map_table");
      map->hm_soap_opts =  (caddr_t *) box_copy_tree ((box_t) opts);
    }
  if (nargs > 15)
    { /* Authentication function options */
      caddr_t * opts = (caddr_t *) bif_array_or_null_arg (qst, args, 15, "http_map_table");
      map->hm_auth_opts =  (caddr_t *) box_copy_tree ((box_t) opts);
    }
  if (nargs > 16)
    { /* Global options */
      caddr_t * opts = (caddr_t *) bif_array_or_null_arg (qst, args, 16, "http_map_table");
      if (DV_TYPE_OF (opts) == DV_ARRAY_OF_POINTER)
	{
	  int i, nelm = BOX_ELEMENTS (opts);
	  for (i = 0; i < nelm && ((nelm % 2) == 0); i+=2)
	    {
	      if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"noinherit"))
		map->hm_no_inherit = 1;
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"xml_templates"))
		map->hm_xml_template = 1;
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"executable"))
		map->hm_executable = 1;
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"exec_as_get"))
		map->hm_exec_as_get = 1;
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"url_rewrite"))
		map->hm_url_rewrite_rule = box_copy_tree (opts[i+1]);
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"url_rewrite_keep_lpath"))
		map->hm_url_rewrite_keep_lpath = unbox (opts[i+1]);
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"cors_restricted"))
		map->hm_cors_restricted = unbox (opts[i+1]);
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"cors"))
		{
		  caddr_t * orgs = ws_split_cors (opts[i+1]);
		  id_hash_t * ht = NULL;
		  if (orgs)
		    {
		      if (orgs != WS_CORS_STAR)
			{
			  int inx;
			  ptrlong one = 1;
			  ht = id_str_hash_create (7);
			  DO_BOX (caddr_t, org, inx, orgs)
			    {
			      id_hash_set (ht, (caddr_t) & org, (caddr_t) & one);
			    }
			  END_DO_BOX;
			}
		      else
			ht = (id_hash_t *) orgs;
		    }
		  map->hm_cors = ht;
		}
	      else if (DV_STRINGP (opts[i]) && !stricmp (opts[i],"expiration_function"))
		map->hm_expiration_fn = box_copy_tree (opts[i+1]);
	    }
	  map->hm_opts = (caddr_t *) box_copy_tree ((box_t) opts);
	}
    }
  map->hm_htkey = box_copy_tree (l_copy);
  http_trace (("adding map for: %s %p\n", l_copy, map));
  id_hash_set (http_map, (caddr_t) & l_copy, (caddr_t) & map);
  if (l_host_default) /* if the current mapping is a default one */
    id_hash_set (http_map, (caddr_t) & l_host_default, (caddr_t) & map);
  return (box_num (0));
}

/*##********************************************************
* Remove hash entry for host/listen host/logical path
* the ws_http_map structure lives in memory to avoid
* GPFs in HTTP requests and decrease memory usage of
* client connections
* (otherwise structure should be copied for every connection)
************************************************************/

caddr_t
bif_http_map_del (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t lpath = bif_string_arg (qst, args, 0, "http_map_del");
  caddr_t l_copy = NULL, host = NULL, lhost = NULL;
  sec_check_dba ((query_instance_t *) qst, "http_map_del"); /* Virtual directory MUST be deleted only by DBA */
  if (BOX_ELEMENTS (args) > 2)
    { /* virtual host or listen host */
      caddr_t vh, virtual_host = bif_string_or_null_arg (qst, args, 1, "http_map_del");
      caddr_t listen_host = bif_string_or_null_arg (qst, args, 2, "http_map_del");
      lhost = http_host_normalize (listen_host, 1);
      vh = http_virtual_host_normalize (virtual_host, listen_host);
      if (lhost && lhost[0] == ':' && vh && vh[0] == ':')
	{
	  host = box_dv_short_string ("*all*"); /*TODO: add all names for the host */
	  dk_free_box (vh); vh = NULL;
	}
      else
	host = vh;
    }
  if (host && lhost)
    { /*if we have a host the key is //host/logical_path */
      l_copy = dk_alloc_box (box_length (lpath) + box_length (host) + box_length (lhost) + 1, DV_SHORT_STRING);
      snprintf (l_copy, box_length (l_copy), "//%s|%s%s", host, lhost, lpath);
    }
  else
    l_copy = box_copy (lpath);

  id_hash_remove (http_map, (caddr_t) & l_copy);
  dk_free_box (l_copy);
  dk_free_box (host);
  dk_free_box (lhost);
  return (box_num (0));
}

#ifdef _SSL
int
https_cert_verify_callback (int ok, void *_ctx)
{
  X509_STORE_CTX *ctx;
  SSL *ssl;
  X509 *xs;
  int errnum, verify, depth;
  int errdepth;
  char *cp, cp_buf[1024];
  char *cp2, cp2_buf[1024];
  SSL_CTX *ssl_ctx;
  uptrlong ap;

  ctx = (X509_STORE_CTX *) _ctx;
  ssl = (SSL *) X509_STORE_CTX_get_app_data (ctx);
  ssl_ctx = SSL_get_SSL_CTX (ssl);
  ap = (uptrlong) SSL_CTX_get_app_data (ssl_ctx);

  xs = X509_STORE_CTX_get_current_cert (ctx);
  errnum = X509_STORE_CTX_get_error (ctx);
  errdepth = X509_STORE_CTX_get_error_depth (ctx);

  cp = X509_NAME_oneline (X509_get_subject_name (xs), cp_buf, sizeof (cp_buf));
  cp2 = X509_NAME_oneline (X509_get_issuer_name (xs), cp2_buf, sizeof (cp2_buf));

  verify = (int) ((0xff000000 & ap) >> 24);
  depth = (int) (0xffffff & ap);

  if ((errnum == X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT
	|| errnum == X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN
	|| errnum == X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY
#if OPENSSL_VERSION_NUMBER >= 0x00905000
	  || errnum == X509_V_ERR_CERT_UNTRUSTED
#endif
	|| errnum == X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE)
      && verify == HTTPS_VERIFY_OPTIONAL_NO_CA )
    {
      SSL_set_verify_result (ssl, X509_V_OK);
      ok = 1;
    }

  if (!ok)
    {
      log_error ("HTTPS Certificate Verification: Error (%d): %s",
	  errnum, X509_verify_cert_error_string(errnum));
    }

  if (errdepth > depth)
    {
      log_error ("HTTPS Certificate Verification: Certificate Chain too long "
	  "(chain has %d certificates, but maximum allowed are only %ld)",
	  errdepth, depth);
      ok = 0;
    }
  return (ok);
}

int
https_ssl_verify_callback (int ok, void *_ctx)
{
  X509_STORE_CTX *ctx;
  SSL *ssl;
  X509 *xs;
  int errnum, verify, depth;
  int errdepth;
  char *cp, cp_buf[1024];
  char *cp2, cp2_buf[1024];
  uptrlong ap;

  ctx = (X509_STORE_CTX *)_ctx;
  ssl  = (SSL *)X509_STORE_CTX_get_app_data(ctx);
  ap = (uptrlong) SSL_get_app_data (ssl);

  xs       = X509_STORE_CTX_get_current_cert(ctx);
  errnum   = X509_STORE_CTX_get_error(ctx);
  errdepth = X509_STORE_CTX_get_error_depth(ctx);

  cp  = X509_NAME_oneline(X509_get_subject_name(xs), cp_buf, sizeof (cp_buf));
  cp2 = X509_NAME_oneline(X509_get_issuer_name(xs),  cp2_buf, sizeof (cp2_buf));

  verify = (int) ((0xff000000 & ap) >> 24);
  depth =  (int) (0xffffff & ap);

  if (( errnum == X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT
	|| errnum == X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN
	|| errnum == X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY
#if OPENSSL_VERSION_NUMBER >= 0x00905000
	|| errnum == X509_V_ERR_CERT_UNTRUSTED
#endif
	|| errnum == X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE)
      && verify == HTTPS_VERIFY_OPTIONAL_NO_CA )
    {
      SSL_set_verify_result(ssl, X509_V_OK);
      ok = 1;
    }

  if (!ok)
    {
      log_error ("HTTPS Certificate Verification: Error (%d): %s",
	  errnum, X509_verify_cert_error_string(errnum));
    }

  if (errdepth > depth)
    {
      log_error ("HTTPS Certificate Verification: Certificate Chain too long "
	  "(chain has %d certificates, but maximum allowed are only %ld)",
	  errdepth, depth);
      ok = 0;
    }
  return (ok);
}

int
ssl_server_set_certificate (SSL_CTX* ssl_ctx, char * cert_name, char * key_name, char * extra)
{
  char err_buf[1024];
  EVP_PKEY *pkey;
  X509 *x509;

  /* TODO create internal OpenSSL engine for this */
  if (strstr (cert_name, "db:") == cert_name || strstr (key_name, "db:") == key_name)
    {
      xenc_key_t *k;
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      user_t *saved_user;
      if (!cli)
	{
	  log_error ("SSL: The certificate and private key stored in the database cannot be accessed");
	  return 0;
	}
      if (strcmp (cert_name, key_name))
	{
	  log_error ("SSL: The certificate and private key stored in the database must have the same name");
	  return 0;
	}
      saved_user = cli->cli_user;
      if (!cli->cli_user)
	cli->cli_user = sec_name_to_user ("dba");
      k = xenc_get_key_by_name (key_name + 3, 1);
      cli->cli_user = saved_user;
      if (!k || !k->xek_x509 || !k->xek_evp_private_key)
	{
	  log_error ("SSL: The stored key '%s' is invalid", key_name);
	  return 0;
	}
      x509 = k->xek_x509;
      pkey = k->xek_evp_private_key;
    }
  else
    {
      if ((x509 = ssl_load_x509 (cert_name)) == NULL)
	{
	  cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  log_error ("SSL: Unable to load certificate '%s': %s", cert_name, err_buf);
	  return 0;
	}
      if ((pkey = ssl_load_privkey (key_name, NULL)) == NULL)
	{
	  cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  log_error ("SSL: Unable to load private key '%s': %s", key_name, err_buf);
	  return 0;
	}
    }
  if (SSL_CTX_use_certificate (ssl_ctx, x509) <= 0)
    {
      cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  log_error ("SSL: Unable to use certificate '%s': %s", cert_name, err_buf);
      return 0;
    }
  if (extra)
    {
      if (strstr (extra, "db:") == extra)
	{
	  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
	  char *tok_s = NULL, *tok;
	  caddr_t str = box_dv_short_string (extra + 3);
	  /* list of key from DB */
	  user_t * saved_user = cli->cli_user;
	  if (!cli->cli_user) cli->cli_user = sec_name_to_user ("dba");
	  tok = strtok_r (str, ",", &tok_s);
	  while (tok)
	    {
	      int r;
	      xenc_key_t * k;
	      k = xenc_get_key_by_name (tok, 1);
	      if (!k || !k->xek_x509)
		{
		  log_error ("SSL: The stored key '%s' can not be used as extra chain certificate", tok);
		  break;
		}
	      r = SSL_CTX_add_extra_chain_cert(ssl_ctx, k->xek_x509);
	      if (!r)
		{
		  log_error ("SSL: The stored certificate '%s' can not be used as extra chain certificate", tok);
		  break;
		}
	      CRYPTO_add(&k->xek_x509->references, 1, CRYPTO_LOCK_X509);
              tok = strtok_r (NULL, ",", &tok_s);
	    }
	  dk_free_box (str);
	  cli->cli_user = saved_user;
	}
      else /* single file */
	{
	  X509 *x = NULL;
	  BIO *in;
	  if ((in = BIO_new_file (extra, "r")) != NULL)
	    {
	      while ((x = PEM_read_bio_X509 (in, NULL, NULL, NULL)))
		{
		  int r;
		  r = SSL_CTX_add_extra_chain_cert(ssl_ctx, x);
		  if (!r)
		    {
		      log_error ("SSL: The certificate(s) from file '%s' can not be used as extra chain certificate(s)", extra);
		      X509_free (x);
		      break;
		    }
		}
	      BIO_free (in);
	    }
	}
    }
  if (SSL_CTX_use_PrivateKey (ssl_ctx, pkey) <= 0)
    {
      cli_ssl_get_error_string (err_buf, sizeof (err_buf));
      log_error ("SSL: Unable to use private key '%s': %s", key_name, err_buf);
      return 0;
    }
  return 1;
}

int
http_set_ssl_listen (dk_session_t * listening, caddr_t * https_opts)
{
  char err_buf[1024];
  SSL_CTX *ssl_ctx = NULL;
  const SSL_METHOD *ssl_meth = NULL;
  char *https_cvfile = NULL;
  char *cert = NULL, *extra = NULL;
  char *skey = NULL;
  long https_cvdepth = -1;
  int i, len, https_client_verify = -1;
  ssl_meth = SSLv23_server_method ();
  ssl_ctx = SSL_CTX_new ((SSL_METHOD *) ssl_meth);

  /* Initialize the parameters */
  len = BOX_ELEMENTS (https_opts);
  if (len % 2)
    {
      log_error ("HTTPS: Options must be an even length array.");
      goto err_exit;
    }

  for (i = 0; i < len; i += 2)
    {
      if (https_opts[i] && DV_STRINGP (https_opts[i]))
	{
	  if (!stricmp (https_opts[i], "https_cv") && DV_STRINGP (https_opts[i + 1]))	/* CA file */
	    https_cvfile = https_opts[i + 1];
	  else if (!stricmp (https_opts[i], "https_cert") && DV_STRINGP (https_opts[i + 1]))	/* x509 cert */
	    cert = https_opts[i + 1];
	  else if (!stricmp (https_opts [i], "https_certificate") && DV_STRINGP (https_opts [i + 1])) /* ALIAS x509 cert */
	    cert = https_opts [i + 1];
	  else if (!stricmp (https_opts[i], "https_key") && DV_STRINGP (https_opts[i + 1]))	/* private key */
	    skey = https_opts[i + 1];
	  else if (!stricmp (https_opts [i], "https_private_key") && DV_STRINGP (https_opts [i + 1]))  /* ALIAS private key */
	    skey = https_opts [i + 1];
	  else if (!stricmp (https_opts[i], "https_cv_depth"))	/* verification depth */
	    https_cvdepth = unbox (https_opts[i + 1]);
	  else if (!stricmp (https_opts[i], "https_verify"))	/* verify mode */
	    https_client_verify = unbox (https_opts[i + 1]);
	  else if (!stricmp (https_opts [i], "https_extra_chain_certificates") && DV_STRINGP (https_opts [i + 1]))  /* private key */
	    extra = https_opts [i + 1];
	}
    }

  if (https_client_verify < 0 && NULL != https_cvfile)	/* compatibility with existing definitions */
    https_client_verify = 1;

  if (!ssl_ctx)
    {
      cli_ssl_get_error_string (err_buf, sizeof (err_buf));
      log_error ("HTTPS: Error allocating SSL context: %s", err_buf);
      goto err_exit;
    }

  if (!ssl_server_set_certificate (ssl_ctx, cert, skey, extra))
    goto err_exit;

  if (https_cvfile)
    {
      if (!SSL_CTX_load_verify_locations (ssl_ctx, https_cvfile, NULL))
	{
	  cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  log_error ("HTTPS: Invalid X509 client CA file %s : %s", https_cvfile, err_buf);
	  goto err_exit;
	}
    }

  if (https_client_verify > 0)
    {
      int verify = SSL_VERIFY_NONE, session_id_context = srv_pid;
      uptrlong ap;

      if (HTTPS_VERIFY_REQUIRED == https_client_verify)
	verify |= SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE;
      if (HTTPS_VERIFY_OPTIONAL == https_client_verify || HTTPS_VERIFY_OPTIONAL_NO_CA == https_client_verify)
	verify |= SSL_VERIFY_PEER | SSL_VERIFY_CLIENT_ONCE;
      SSL_CTX_set_verify (ssl_ctx, verify, (int (*)(int, X509_STORE_CTX *)) https_cert_verify_callback);
      SSL_CTX_set_verify_depth (ssl_ctx, https_cvdepth);
      ap = ((0xff & https_client_verify) << 24) | (0xffffff & https_cvdepth);
      SSL_CTX_set_app_data (ssl_ctx, ap);
      SSL_CTX_set_session_id_context (ssl_ctx, (unsigned char *) &session_id_context, sizeof session_id_context);
    }

  if (https_cvfile)
    {
      int i = 0;
      STACK_OF (X509_NAME) * skCAList = SSL_load_client_CA_file (https_cvfile);

      SSL_CTX_set_client_CA_list (ssl_ctx, skCAList);
      skCAList = SSL_CTX_get_client_CA_list (ssl_ctx);

      if (sk_X509_NAME_num (skCAList) == 0)
	log_warning ("HTTPS: Client authentication requested but no CA known for verification");

      for (i = 0; i < sk_X509_NAME_num (skCAList); i++)
	{
	  char ca_buf[1024];
	  X509_NAME *ca_name = (X509_NAME *) sk_X509_NAME_value (skCAList, i);
	  if (X509_NAME_oneline (ca_name, ca_buf, sizeof (ca_buf)))
	    log_debug ("HTTPS: Using X509 Client CA %s", ca_buf);
	}
    }
  tcpses_set_sslctx (listening->dks_session, (void *) ssl_ctx);
  return 1;
err_exit:
  SSL_CTX_free (ssl_ctx);
  return 0;
}
#endif

/*##************************************
* Start new listening session (HTTP/HTTPS)
* if cannot start log error & return
****************************************/
dk_session_t *
http_listen (char * host, caddr_t * https_opts)
{
  dk_session_t *listening = NULL;
  int rc = 0;
  listening = dk_session_allocate (SESCLASS_TCPIP);
  ASSERT_IN_MTX (http_listeners_mutex);

  SESSION_SCH_DATA (listening)->sio_default_read_ready_action
      = (io_action_func) ws_ready;

  if (SER_SUCC != session_set_address (listening->dks_session, host))
    goto err_exit;

#ifdef _SSL
  if (https_opts)
    {
      if (!http_set_ssl_listen (listening, https_opts))
	goto err_exit;
    }
#endif

  rc = session_listen (listening->dks_session);

  if (!SESSTAT_ISSET (listening->dks_session, SST_LISTENING))
    {
      log_error ("Failed HTTP listen at %s code (%d).", host, rc);
      goto err_exit;
    };
  PrpcCheckIn (listening);
  return listening;

err_exit: /* All erroneous cases go here */
  PrpcSessionFree (listening);
  return NULL;
}

#define HS_LISTEN 0
#define HS_STOP_LISTEN 1
#define HS_SHOW_LISTEN 2

/*##**********************************************************
* Start or stop listening session
* available listening sessions contains in http_listeners hash
* takes 2 parameters
* 1 - host & port (default port is :80)
* 2 - 0-start 1-stop 2-test is listen
*************************************************************/
caddr_t
bif_http_listen_host (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t host = http_host_normalize (bif_string_arg (qst, args, 0, "http_listen_host"), 0);
  ptrlong stop = bif_long_arg (qst, args, 1, "http_listen_host");
  caddr_t * https_opts = BOX_ELEMENTS (args) > 2 ?
      (caddr_t *) bif_array_or_null_arg (qst, args, 2, "http_listen_host") : NULL;
  dk_session_t *listening = NULL;
  int rc = 0;
  dk_session_t **place = NULL;
  sec_check_dba ((query_instance_t *) qst, "http_listen_host");	/* listen hosts MUST be manipulated only by DBA */

  /* it's probably a vhost_define call during startup */
  if (!virtuoso_server_initialized)
    return box_num (-1);

#if 0
  {
    id_hash_iterator_t it;
    char **pk;
    dk_session_t **ptp;
    id_hash_iterator (&it, http_listeners);

    while (hit_next (&it, (caddr_t *) & pk, (caddr_t *) & ptp))
      {
	fprintf (stderr, "%s\n", *pk);
      }
  }
#endif
  if (stop)
    {
      mutex_enter (http_listeners_mutex);
      place = (dk_session_t **) id_hash_get (http_listeners, (caddr_t) & host);
      if (place && *place && stop & HS_STOP_LISTEN)
	{
	  caddr_t *key, old_key;
	  listening = *place;
	  http_trace (("stop listen on: %s %p\n", host, listening));
	  key = (caddr_t *) id_hash_get_key (http_listeners, (caddr_t) & host);
	  old_key = *key;
	  id_hash_remove (http_listeners, (caddr_t) & host);
	  if (old_key)
	    dk_free_box (old_key);
	  PrpcDisconnect (listening);
#ifdef _SSL
	  if (tcpses_get_sslctx (listening->dks_session))
	    SSL_CTX_free ((SSL_CTX *) tcpses_get_sslctx (listening->dks_session));
#endif
	  PrpcSessionFree (listening);
	}
      mutex_leave (http_listeners_mutex);
      if (place && *place && stop & HS_SHOW_LISTEN)
	rc = 1;
      dk_free_box (host);
    }
  else
    {
      mutex_enter (http_listeners_mutex);
      place = (dk_session_t **) id_hash_get (http_listeners, (caddr_t) & host);
      if (!place)
	{
	  listening = http_listen (host, https_opts);
	  if (listening)
	    {
	      http_trace (("start listen on: %s %p\n", host, listening));
	      id_hash_set (http_listeners, (caddr_t) & host, (caddr_t) & listening);
	      rc = 1;
	    }
	}
      else
	{
	  log_debug ("Trying to start already started listener on port %s", host);
	  dk_free_box (host);
	}
      mutex_leave (http_listeners_mutex);
    }
  return (box_num (rc));
}

/* IvAn/DkAllocBoxZero/010107 Runaway fixed (strcat with garbage in 1st argument) */
caddr_t
get_path_elms (caddr_t * paths, int nth, char * host, char * lhost)
{
  char ret [1000];
  int inx, n, len, frag_len, hlen = 0;
  int to_get;
  strcpy_ck (ret, "/");
  if (host && lhost && paths && 0 != stricmp (paths [0], "http:") && nth > 0)
    {
      hlen = (int) (strlen (host) + strlen (lhost));
      hlen += 3;
    }
  else if (host && lhost)
    snprintf (ret, sizeof (ret), "//%s|%s/", host, lhost);
  if (paths && nth > 0)
    {
      if (nth < (int) BOX_ELEMENTS (paths))
	to_get = nth;
      else
	to_get = BOX_ELEMENTS (paths);
      len = 0;
      for (n = 0; n < to_get; n++)
	{
	  frag_len = box_length (paths [n]);
	  if (len + 1 + hlen + frag_len > sizeof(ret))
	    {
	      to_get = n;
	      break;
	    }
	  len += frag_len;
	}
      if (0 != stricmp (paths [0], "http:") && !host)
	strcpy_ck (ret, "/");
      else if (host && lhost && 0 != stricmp (paths [0], "http:"))
	snprintf (ret, sizeof (ret), "//%s|%s/", host, lhost);
      else
	ret[0] = '\0';
      for (inx = 0; inx < to_get; inx++)
	{
	  if (inx > 0)
	    strcat_ck (ret, "/");
	  strcat_ck (ret, paths [inx]);
	  if (inx == 0 && 0 == stricmp (paths [inx], "http:"))
	    strcat_ck (ret, "/");
	}
    }
  return box_dv_short_string (ret);
}

/*##**********************************************************
* Find in HTTP map hash for most likely virtual path
* if found return physical location and set ws_map member
* to appropriate ws_http_map entry
* TODO: optimize if hash not available
*************************************************************/
caddr_t
get_http_map (ws_http_map_t ** ws_map, char * lpath, int dir, char * host, char * lhost)
{
  caddr_t * ret = NULL;
  ws_http_map_t ** last_match = NULL;
  int inx, len, elm, rlen, n;
  caddr_t res = NULL;
  caddr_t * paths = (caddr_t *) http_path_to_array (lpath, 0);
  caddr_t path_str;
  if (!ws_map)
    return NULL;
  *ws_map = NULL; /* first clear old map entry */
  if (paths)
    len = BOX_ELEMENTS (paths);
  else
    len = 0;
  inx = 0;
  elm = 0;
  do
    {
      path_str = get_path_elms (paths, inx++, host, lhost);
      last_match = (ws_http_map_t **) id_hash_get (http_map, (caddr_t) & path_str);
      http_trace (("trying w/h host hf: %s %p\n", path_str, last_match));
      if (last_match && *last_match)
	{
	  ret = &((*last_match)->hm_p_path);
	  *ws_map = *last_match;
	  elm = inx;
	}
      dk_free_box (path_str);
    }
  while (inx <= len);

  rlen = 0;

  if (ret)
      rlen += box_length (*ret);
  else
    {
      path_str =  get_path_elms (paths, len, NULL, NULL);
      rlen += box_length (path_str);
      if (dir && 0 != strcmp (path_str, "/"))
	rlen++;
      res = dk_alloc_box (rlen , DV_SHORT_STRING);
      strcpy_box_ck (res, path_str);
      if (dir && 0 != strcmp (res, "/"))
	strcat_box_ck (res, "/");
      dk_free_box (path_str);
    }
  if (ret != NULL && last_match == NULL && elm > 0 && !(*ws_map)->hm_no_inherit)
    {
      if (rlen > 1 && '/' == (*ret)[rlen - 2])
          rlen--;
      elm --;
      for (n = elm; n < len; n++)
	rlen += box_length (paths [n]);
      if (dir)
	rlen ++;
      res = dk_alloc_box (rlen , DV_SHORT_STRING);
      strcpy_box_ck (res, *ret);
      if (res [strlen (res) - 1] != '/')
	strcat_box_ck (res , "/");
      while (elm < len)
	{
	  strcat_box_ck (res, paths [elm]);
	  if ((elm < len - 1) /*|| ((elm == len - 1) && (lpath [strlen (lpath) - 1] == '/'))*/)
	    strcat_box_ck (res, "/");
	  elm++;
	}
      if (dir)
	strcat_box_ck (res, "/");
    }
  if (ret != NULL && (last_match != NULL || (*ws_map)->hm_no_inherit) && elm > 0)
    {
      res = dk_alloc_box (rlen , DV_SHORT_STRING);
      strcpy_box_ck (res, *ret);
    }
  dk_free_tree ((box_t) paths);
  return res;
}

/*##***********************************************************
* Return HTTP header field value w/o leading space and
* trailing \r\n
* Note: result should be freed
**************************************************************/
caddr_t
ws_get_packed_hf (ws_connection_t * ws, const char * fld, char * deflt)
{
  caddr_t ret, p1, val = ws_header_field (ws->ws_lines, fld, deflt);
  size_t len = 0;
  if (!val)
    return NULL;
  while (*val && isspace (*val))
    val++;
  len = strlen (val);
  p1 = val + len - 1;
  while (p1 > val && *p1 && (*p1 == '\x0D' || *p1 == '\x0A'))
    p1--;
  len = p1 - val + 1;
  if (len < 1)
    return NULL;
  ret = dk_alloc_box (len + 1, DV_SHORT_STRING);
  memcpy (ret, val, len);
  ret [len] = 0;
  return ret;
}

/*##****************************************************
* Set physical path string and http virtual map struct
*******************************************************/
void
ws_set_phy_path (ws_connection_t * ws, int dir, char * vsp_path)
{
  caddr_t lpath = NULL, ppath = NULL, host_hf = NULL, host = NULL;
  char listen_host [128];
  struct sockaddr_in sa;
  char nif[100]; /* network interface address */
  int s;
  int is_https = 0;
#ifdef _SSL
  SSL *ssl = NULL;
#endif
  socklen_t len = sizeof (sa);
  int port = 0;

  if (!ws)
    return;

  s = tcpses_get_fd (ws->ws_session->dks_session);
  if (!getsockname (s, (struct sockaddr *) &sa, &len))
    {
      unsigned char *addr = (unsigned char *) &sa.sin_addr;
      port = ntohs (sa.sin_port);
      snprintf (nif, sizeof (nif), "%d.%d.%d.%d:%u", addr[0], addr[1], addr[2], addr[3], port);
    }
  else
    nif[0] = 0;

#ifdef _SSL
  ssl = (SSL *) tcpses_get_ssl (ws->ws_session->dks_session);
  is_https = (NULL != ssl);
#endif

  tcpses_addr_info (ws->ws_session->dks_session, listen_host, sizeof (listen_host), 80, 1);
  /* was: host_hf = ws_get_packed_hf (ws, "Host:", listen_host);*/
  if (NULL == (host_hf = ws_mime_header_field (ws->ws_lines, "X-Forwarded-Host", NULL, 1)))
    host_hf = ws_mime_header_field (ws->ws_lines, "Host", NULL, 1);
  if (NULL == host_hf)
    host_hf = box_dv_short_string (listen_host);
  host = http_host_normalize_1 (host_hf, 0, (is_https ? 443 : 80), IS_GATEWAY_PROXY (ws) ? port : 0);
  http_trace (("host hf: %s, host nfo:, %s nif: %s\n", host, listen_host, nif));

  if (!vsp_path)
    {
      lpath = strchr (ws->ws_req_line, '\x20');
      while (lpath && *lpath && isspace (*lpath))
	lpath++;
    }
  else
    lpath = vsp_path;
  if (0 != nif[0])
    ppath = get_http_map (&(ws->ws_map), lpath, dir, host, nif); /* trying vhost & ip */
  if (NULL == ws->ws_map)
    {
      dk_free_box (ppath); ppath = NULL;
      ppath = get_http_map (&(ws->ws_map), lpath, dir, host, listen_host); /* try virtual host */
    }
  if (listen_host[0] == ':' && NULL == ws->ws_map)
    {
      dk_free_box (ppath); ppath = NULL;
      ppath = get_http_map (&(ws->ws_map), lpath, dir, "*all*", listen_host);
    }
  else if (listen_host[0] != ':' && NULL == ws->ws_map) /* try the default directory for listen NIF */
    {
      dk_free_box (ppath); ppath = NULL;
      ppath = get_http_map (&(ws->ws_map), lpath, dir, listen_host, listen_host);
    }
  ws->ws_p_path_string = ppath;
  ws->ws_p_path = (caddr_t *) http_path_to_array (ppath, 1);
  dk_free_box (host);
  dk_free_box (host_hf);
}

static caddr_t
ws_get_http_map (ws_connection_t * ws, int dir, caddr_t lpath, int set_map)
{
  caddr_t ppath = NULL, host_hf = NULL, host = NULL;
  char listen_host [128];
  struct sockaddr_in sa;
  char nif[100] = {0}; /* network interface address */
  int s;
  int is_https = 0;
#ifdef _SSL
  SSL *ssl = NULL;
#endif
  socklen_t len = sizeof (sa);
  ws_http_map_t * pmap = NULL;
  ws_http_map_t ** map = set_map ? &(ws->ws_map) : &pmap;
  int port = 0;

  if (!ws)
    return NULL;

  s = tcpses_get_fd (ws->ws_session->dks_session);
  if (!getsockname (s, (struct sockaddr *) &sa, &len))
    {
      unsigned char *addr = (unsigned char *) &sa.sin_addr;
      port = ntohs (sa.sin_port);
      snprintf (nif, sizeof (nif), "%d.%d.%d.%d:%u", addr[0], addr[1], addr[2], addr[3], port);
    }

  tcpses_addr_info (ws->ws_session->dks_session, listen_host, sizeof (listen_host), 80, 1);
  /* was : host_hf = ws_get_packed_hf (ws, "Host:", listen_host); */
  if (NULL == (host_hf = ws_mime_header_field (ws->ws_lines, "X-Forwarded-Host", NULL, 1)))
    host_hf = ws_mime_header_field (ws->ws_lines, "Host", NULL, 1);
  if (NULL == host_hf)
    host_hf = box_dv_short_string (listen_host);
#ifdef _SSL
  ssl = (SSL *) tcpses_get_ssl (ws->ws_session->dks_session);
  is_https = (NULL != ssl);
#endif
  host = http_host_normalize_1 (host_hf, 0, (is_https ? 443 : 80), IS_GATEWAY_PROXY (ws) ? port : 0);

  if (0 != nif[0])
    ppath = get_http_map (map, lpath, dir, host, nif); /* trying vhost & ip */
  if (NULL == *map)
    {
      dk_free_box (ppath); ppath = NULL;
      ppath = get_http_map (map, lpath, dir, host, listen_host); /* try virtual host */
    }
  if (listen_host[0] == ':' && NULL == *map)
    {
      dk_free_box (ppath); ppath = NULL;
      ppath = get_http_map (map, lpath, dir, "*all*", listen_host);
    }
  else if (listen_host[0] != ':' && NULL == *map) /* try the default directory for listen NIF */
    {
      dk_free_box (ppath); ppath = NULL;
      ppath = get_http_map (map, lpath, dir, listen_host, listen_host);
    }
  dk_free_box (host);
  dk_free_box (host_hf);
  return ppath;
}

static caddr_t
bif_http_physical_path_resolve (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t lpath = bif_string_arg (qst, args, 0, "http_physical_path_resolve");
  long is_dir = 0;

  if (qi->qi_client->cli_ws)
    {
      caddr_t ppath;
      int set_map = 0;
      if (lpath && box_length(lpath) > 1 && '/' == lpath [box_length(lpath) - 2])
	is_dir = 1;
      if (BOX_ELEMENTS (args) > 1)
	set_map = bif_long_arg (qst, args, 1, "http_physical_path_resolve");
      ppath = ws_get_http_map (qi->qi_client->cli_ws, is_dir ? 1 : 0, lpath, set_map);
      return ppath;
    }
  else
    return NEW_DB_NULL;
}



caddr_t
bif_http_physical_path (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  if (qi->qi_client->cli_ws)
    return (box_copy (qi->qi_client->cli_ws->ws_p_path_string));
  else
    return NULL;
}

caddr_t
bif_http_map_get (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t member = bif_string_arg (qst, args, 0, "http_map_get");
  ws_http_map_t * map = NULL;
  caddr_t res = NULL;

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT040", "http_map_get function outside of http context");

  map = qi->qi_client->cli_ws->ws_map ? qi->qi_client->cli_ws->ws_map : http_default_map;

  if (!strcmp (member, "vsp_uid"))
    res = box_copy (map->hm_vsp_uid);
  else if (!strcmp (member, "soap_uid"))
    res = box_copy (map->hm_soap_uid);
  else if (!strcmp (member, "persist_ses_vars"))
    res = box_num (map->hm_ses_vars);
  else if (!strcmp (member, "default_page"))
    res = box_copy (map->hm_def_page);
  else if (!strcmp (member, "browseable") || !strcmp (member, "browsable"))
    res = box_num (map->hm_browseable);
  else if (!strcmp (member, "xml_templates"))
    res = box_num (map->hm_xml_template);
  else if (!strcmp (member, "security_level"))
    res = box_copy (map->hm_sec);
  else if (!strcmp (member, "auth_opts"))
    res = box_copy_tree ((box_t) map->hm_auth_opts);
  else if (!strcmp (member, "soap_opts"))
    res = box_copy_tree ((box_t) map->hm_soap_opts);
  else if (!strcmp (member, "options"))
    res = box_copy_tree ((box_t) map->hm_opts);
  else if (!strcmp (member, "domain"))
    res = box_copy (map->hm_l_path);
  else if (!strcmp (member, "mounted"))
    res = box_copy (map->hm_p_path);
  else if (!strcmp (member, "vsp_qual"))
    res = box_dv_short_string (ws_usr_qual (qi->qi_client->cli_ws, 0));
  else if (!strcmp (member, "soap_qual"))
    res = box_dv_short_string (ws_usr_qual (qi->qi_client->cli_ws, 1));
  else if (!strcmp (member, "vsp_proc_owner"))
    res = box_dv_short_string (WS_USER_NAME (qi->qi_client->cli_ws));
  else if (!strcmp (member, "vhost"))
    res = box_copy (map->hm_host);
  else if (!strcmp (member, "lhost"))
    res = box_copy (map->hm_lhost);
  else if (!strcmp (member, "is_dav"))
    res = box_num (map->hm_is_dav);
  else if (!strcmp (member, "executable"))
    res = box_num (map->hm_executable);
  else if (!strcmp (member, "exec_as_get"))
    res = box_num (map->hm_exec_as_get);
  else if (!strcmp (member, "url_rewrite"))
    res = box_copy_tree ((box_t) map->hm_url_rewrite_rule);
  else if (!strcmp (member, "url_rewrite_keep_lpath"))
    res = box_num (map->hm_url_rewrite_keep_lpath);
  else if (!strcmp (member, "noinherit"))
    res = box_num (map->hm_no_inherit);
  else if (!strcmp (member, "expiration_function"))
    res = box_copy_tree ((box_t) map->hm_expiration_fn);
  return res;
}

static caddr_t
bif_http_request_get (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t cgi_var = bif_string_arg (qst, args, 0, "http_request_get");
  ws_connection_t *ws = qi->qi_client->cli_ws;
  if (!ws)
    sqlr_new_error ("42000", "HT040", "http_request_get function outside of http context");


  if (!strcmp (cgi_var, "SERVER_PROTOCOL"))
    {
      return box_dv_short_string (ws->ws_proto);
    }
  else if (!strcmp (cgi_var, "REQUEST_METHOD"))
    {
      return box_dv_short_string (ws->ws_method_name);
    }
/*  else if (!strcmp (cgi_var, "SCRIPT_NAME"))
    {
      if (ws->ws_path && BOX_ELEMENTS (ws->ws_path) > 0)
	return box_dv_short_string (ws->ws_path[BOX_ELEMENTS (ws->ws_path) - 1]);
    }*/
  else if (!strcmp (cgi_var, "QUERY_STRING"))
    {
      char *qmark_pos = strchr (ws->ws_req_line, '?');
      if (qmark_pos)
	{
	  char *end_ptr = qmark_pos + 1 + strlen (qmark_pos + 1) - 1;

	  while (isspace (*end_ptr))
	    end_ptr--;
	  return box_varchar_string ((db_buf_t) (qmark_pos + 1), end_ptr - qmark_pos, DV_STRING);
	}
    }
  else if (!strcmp (cgi_var, "REQUEST_URI"))
    {
      char *space_pos = strchr (ws->ws_req_line, ' ');
      if (space_pos)
	{
	  char *end_ptr = space_pos + 1 + strlen (space_pos + 1) - 1;

	  while (isspace (*end_ptr))
	    end_ptr--;
	  return box_varchar_string ((db_buf_t) (space_pos + 1), end_ptr - space_pos, DV_STRING);
	}
    }
  return box_dv_short_string ("");
}


/* HTTP listeners startup query */
#define q_listen "select HP_LISTEN_HOST, deserialize (HP_AUTH_OPTIONS), HP_SECURITY from DB.DBA.HTTP_PATH where HP_LISTEN_HOST is not null and HP_LISTEN_HOST <> server_http_port() and HP_LISTEN_HOST <> '*ini*' and HP_LISTEN_HOST <> '*sslini*'"

void
http_vhosts_init (void)
{
  caddr_t err = NULL;
  local_cursor_t *lc;
  query_t *qr = sql_compile (q_listen, bootstrap_cli, &err, SQLC_DEFAULT);
  dk_session_t *listening;
  ptrlong one = 1;

  if (NULL == qr)
    {
      log_error("Unable to compile SQL statement: %s", q_listen);
      return;
    }
  err = qr_exec (bootstrap_cli, qr, CALLER_LOCAL, NULL, NULL, &lc, NULL, NULL, 0);
  while (!err && lc_next (lc))
    {
      char * hp = lc_nth_col (lc, 0);
      caddr_t * opts = (caddr_t *) lc_nth_col (lc, 1);
      char * sec = lc_nth_col (lc, 2);
      caddr_t host = http_host_normalize (hp, 0);
      caddr_t has_it, tried;
      mutex_enter (http_listeners_mutex);
      has_it = id_hash_get (http_listeners, (caddr_t) & host);
      tried = id_hash_get (http_failed_listeners, (caddr_t) & host);
      if (!has_it && !tried)
	{
	  caddr_t * ssl_opts = NULL;
	  if (DV_STRINGP (sec) && 0 == stricmp (sec, "SSL") && ARRAYP (opts) && box_length (opts))
	    ssl_opts = opts;
	  listening = http_listen (host, ssl_opts);
	  if (listening)
	    {
	      id_hash_set (http_listeners, (caddr_t) & host, (caddr_t) &listening);
	      http_trace (("listen ses: %s %p\n", hp, listening));
	    }
	  else
	    {
	      id_hash_set (http_failed_listeners, (caddr_t) & host, (caddr_t)&one);
	    }
	}
      mutex_leave (http_listeners_mutex);
    }
  lc_free (lc);
  qr_free (qr);
  local_commit (bootstrap_cli);
  /* Initialize default http map struct */
  http_default_map = (ws_http_map_t *) dk_alloc (sizeof (ws_http_map_t));
  memset (http_default_map, '\x0', sizeof (ws_http_map_t));
  http_default_map->hm_host = box_dv_short_string (http_port);
  http_default_map->hm_lhost = box_dv_short_string (http_port);
  http_default_map->hm_p_path = box_dv_short_string ("/");
  http_default_map->hm_l_path = box_dv_short_string ("/");
  http_default_map->hm_vsp_uid = NULL;
  http_default_map->hm_soap_uid = NULL;
#if 0 /* not used */
  all_host_names = box_tcpip_localhost_names ();
#endif
}

#endif


caddr_t
bif_http_auth_verify (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  caddr_t * auth_vec 	= (caddr_t *) bif_strict_array_or_null_arg (qst, args, 0, "http_auth_verify");
  caddr_t username 	= bif_string_arg (qst, args, 1, "http_auth_verify");
  caddr_t realm 	= bif_string_arg (qst, args, 2, "http_auth_verify");
  caddr_t uri 		= bif_string_arg (qst, args, 3, "http_auth_verify");
  caddr_t nonce 	= bif_string_arg (qst, args, 4, "http_auth_verify");
  caddr_t nc 		= bif_string_arg (qst, args, 5, "http_auth_verify");
  caddr_t cnonce 	= bif_string_arg (qst, args, 6, "http_auth_verify");
  caddr_t qop 		= bif_string_arg (qst, args, 7, "http_auth_verify");
  caddr_t pass 		= bif_string_arg (qst, args, 8, "http_auth_verify");
  caddr_t authtype 	= auth_vec ? get_keyword_int (auth_vec, "authtype", "http_auth_verify") : NULL;
  caddr_t gen_resp = NULL, A1 = NULL, A2 = NULL, new_pass = NULL;

  if (!authtype)
    return box_num(0);

  sqlp_upcase (authtype);

  if (!pass[0] && box_length (pass) > 1)
    {
      new_pass = dk_alloc_box (box_length (pass) - 1, DV_SHORT_STRING);
      memcpy (new_pass, pass + 1, box_length (pass) - 1);
      xx_encrypt_passwd (new_pass, box_length (pass) - 2, username);
    }
  else
    new_pass = box_copy (pass);

  if (0 == strcmp (authtype, "BASIC"))
    {
      caddr_t pass1 = get_keyword_int (auth_vec, "pass", "http_auth_verify");
      if (pass1 && 0 == strcmp (new_pass, pass1))
	{
	  dk_free_box (new_pass);
	  dk_free_box (pass1);
	  dk_free_box (authtype);
	  return box_num(1);
	}
      dk_free_box (pass1);
    }
  else if (0 == strcmp (authtype, "DIGEST"))
    {
      dk_session_t * ses;
      caddr_t method = get_keyword_int (auth_vec, "method", "http_auth_verify");
      caddr_t response = get_keyword_int (auth_vec, "response", "http_auth_verify");

      if (!method || !response)
	{
	  dk_free_box (method); dk_free_box (response);
	  dk_free_box (new_pass);
	  dk_free_box (authtype);
	  return box_num(0);
	}

      ses = strses_allocate ();

      SES_PRINT (ses, username); SES_PRINT (ses, ":");
      SES_PRINT (ses, realm); SES_PRINT (ses, ":");
      SES_PRINT (ses, new_pass);
      A1 = md5_ses (ses);
      strses_flush (ses);
      SES_PRINT (ses, method); SES_PRINT (ses, ":"); SES_PRINT (ses, uri);
      A2 = md5_ses (ses);
      strses_flush (ses);
/*
      fprintf (stderr,
	  "       A1: %s\n"
	  "    nonce: %s\n"
	  "       nc: %s\n"
	  "   cnonce: %s\n"
	  "      qop: %s\n"
	  "       A2: %s\n", A1, nonce, nc, cnonce, qop, A2);
*/
      SES_PRINT (ses, A1); SES_PRINT (ses, ":");
      SES_PRINT (ses, nonce); SES_PRINT (ses, ":");
      if (strlen (qop) > 0)
	{
	  SES_PRINT (ses, nc); SES_PRINT (ses, ":");
	  SES_PRINT (ses, cnonce); SES_PRINT (ses, ":");
	  SES_PRINT (ses, qop); SES_PRINT (ses, ":");
        }
      SES_PRINT (ses, A2);
      dk_free_box (A1); dk_free_box (A2); dk_free_box (method); dk_free_box (new_pass); dk_free_box (authtype);
      authtype = NULL; new_pass = NULL;
      gen_resp = md5_ses (ses);
      dk_free_box ((box_t) ses);
/*      fprintf (stderr, " gen resp: %s\nuser resp:%s\n", gen_resp, response); */
      if (0 == strcmp (gen_resp, response))
	{
	  dk_free_box (gen_resp);
	  dk_free_box (response);
	  return box_num (1);
	}
      dk_free_box (gen_resp);
      dk_free_box (response);
    }
  dk_free_box (authtype);
  dk_free_box (new_pass);
  return box_num(0);
}

static caddr_t
bif_http_body_read (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t *ws = qi->qi_client->cli_ws;
  dk_session_t *ses;
  if (!ws)
    sqlr_new_error ("42000", "HT053", "Function http_body_read() not allowed outside http context");
  if ((0 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 0, "http_body_read"))
    {
      ses = strses_allocate ();
      ws_http_body_read (ws, &ses);
    }
  else if (ws->ws_req_body)
    {
      ses = ws->ws_req_body;
      ws->ws_req_body = NULL;
    }
  else
    ses = strses_allocate ();
  return (caddr_t) ses;
}


static caddr_t
bif_http_stream_params (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t *ws = NULL;
  caddr_t stream_params = NULL;

  if (!qi->qi_client->cli_ws)
    sqlr_new_error ("42000", "HT056", "Searching for POST stream parameters not allowed outside http context");
  ws = qi->qi_client->cli_ws;
  if (ws->ws_stream_params)
    {
      stream_params = (caddr_t) ws->ws_stream_params;
      ws->ws_stream_params = NULL;
    }
  else
    stream_params = dk_alloc_box (0, DV_ARRAY_OF_POINTER);
  return stream_params;
}

static caddr_t
bif_is_http_ctx (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  if (!qi->qi_client->cli_ws)
    return box_num(0);
  return box_num(1);
}

static caddr_t
bif_is_https_ctx (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  int is_https = 0;
  ws_connection_t *ws = qi->qi_client->cli_ws;
#ifdef _SSL
  SSL *ssl = NULL;
#endif

  if (!ws)
    return box_num(0);
#ifdef _SSL
  ssl = (SSL *) tcpses_get_ssl (ws->ws_session->dks_session);
  is_https = (NULL != ssl);
#endif
  return box_num(is_https ? 1 : 0);
}

static caddr_t
bif_http_is_flushed (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  if (qi->qi_client->cli_ws)
    return box_num(qi->qi_client->cli_ws->ws_flushed);
  return box_num(1);
}

static caddr_t
bif_https_renegotiate (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  char * me = "https_renegotiate";
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t *ws = qi->qi_client->cli_ws;
#ifdef _SSL
  SSL *ssl = NULL;
#endif

  if (!ws)
    return box_num (0);
#ifdef _SSL
  ssl = (SSL *) tcpses_get_ssl (ws->ws_session->dks_session);
  if (ssl)
    {
      int i, verify = SSL_VERIFY_NONE;
      uptrlong ap;
      static int s_server_auth_session_id_context;
      int https_client_verify = BOX_ELEMENTS (args) > 0 ? bif_long_arg (qst, args, 0, me) : HTTPS_VERIFY_OPTIONAL_NO_CA;
      int https_client_verify_depth = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, me) : 15;
      s_server_auth_session_id_context ++;

      if (https_client_verify < 0 || https_client_verify > HTTPS_VERIFY_OPTIONAL_NO_CA)
	sqlr_new_error ("22023", ".....", "The verify flag must be between 0 and 3");
      if (https_client_verify_depth <= 0)
	sqlr_new_error ("22023", ".....", "The verify depth must be greater than zero");

      ap = ((0xff & https_client_verify) << 24) | (0xffffff & https_client_verify_depth);

      if (HTTPS_VERIFY_REQUIRED == https_client_verify)
	verify |= SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
      if (HTTPS_VERIFY_OPTIONAL == https_client_verify || HTTPS_VERIFY_OPTIONAL_NO_CA == https_client_verify)
	verify |= SSL_VERIFY_PEER;

      SSL_set_verify (ssl, verify, (int (*)(int, X509_STORE_CTX *)) https_ssl_verify_callback);
      SSL_set_app_data (ssl, ap);
      SSL_set_session_id_context (ssl, (void*)&s_server_auth_session_id_context, sizeof(s_server_auth_session_id_context));
      i = SSL_renegotiate (ssl);
      if (i <= 0) sqlr_new_error ("42000", ".....", "SSL_renegotiate failed");
      i = SSL_do_handshake (ssl);
      if (i <= 0) sqlr_new_error ("42000", ".....", "SSL_do_handshake failed");
      ssl->state = SSL_ST_ACCEPT;
      i = SSL_do_handshake (ssl);
      if (i <= 0) sqlr_new_error ("42000", ".....", "SSL_do_handshake failed");
      if (SSL_get_peer_certificate (ssl))
	return box_num (1);
    }
#endif
  return box_num (0);
}

FILE *debug_log = NULL;

static caddr_t
bif_http_debug_log (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  caddr_t fname, fname_cvt;
  fname = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "http_debug_log");
  if (fname)
    {
      fname_cvt = file_native_name (fname);
      file_path_assert (fname_cvt, NULL, 1);
    }
  else
    fname_cvt = NULL;
  if (debug_log && fname_cvt)
    {
      sqlr_new_error ("42000", "FA041", "HTTP debug log is already being generated");
    }
  else if (!debug_log && fname_cvt)
    {
      debug_log = fopen (fname_cvt, "a");
      if (!debug_log)
	{
	  int errn = errno;
          caddr_t err = srv_make_new_error ("39000", "FA042", "Can't open debug log file '%.1000s', error : %s", fname_cvt, strerror (errn));
          dk_free_box (fname_cvt);
          sqlr_resignal (err);
	}
    }
  else if (debug_log && !fname_cvt)
    {
      mutex_enter (ws_http_log_mtx);
      fflush (debug_log);
      fclose (debug_log);
      debug_log = NULL;
      mutex_leave (ws_http_log_mtx);
    }
  dk_free_box (fname_cvt);
  return box_num(0);
}

static caddr_t
bif_http_dav_uid (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  return box_num (U_ID_DAV);
}

static caddr_t
bif_http_admin_gid (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  return box_num (U_ID_DAV_ADMIN_GROUP);
}

static caddr_t
bif_http_nobody_uid (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  return box_num (U_ID_NOBODY);
}

static caddr_t
bif_http_nogroup_gid (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  return box_num (U_ID_NOGROUP);
}

caddr_t
bif_http_escape (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * out = http_session_no_catch_arg (qst, args, 2, "http_escape");
  caddr_t text = bif_varchar_or_bin_arg (qst, args, 0, "http_escape");
  int mode = (int) bif_long_arg (qst, args, 1, "http_escape");
  wcharset_t *src_charset = (((BOX_ELEMENTS (args) >= 4) && bif_long_arg (qst, args, 3, "http_escape")) ? CHARSET_UTF8 : default_charset);
  wcharset_t *tgt_charset = (((BOX_ELEMENTS (args) < 5) || bif_long_arg (qst, args, 4, "http_escape")) ? CHARSET_UTF8 : default_charset);
  if (
    ((mode & 0xff) >= COUNTOF__DKS_ESC) ||
    (mode & ~0xff & ~(DKS_ESC_COMPAT_HTML | DKS_ESC_COMPAT_SOAP)) )
    {
      sqlr_new_error ("22023", "HT058",
        "Incorrect escaping mode (%d) is specified in parameter 2 of http_escape()", mode);
    }
  dks_esc_write (out, text, box_length(text)-1, tgt_charset, src_charset, mode);
  return NULL;
}

static int
acl_compare (const void *ileft, const void *iright)
{
  ws_acl_t * left =  (ws_acl_t*)(*(caddr_t *)ileft);
  ws_acl_t * right = (ws_acl_t*)(*(caddr_t *)iright);

  /* by order number */
  if (left->ha_order < right->ha_order)
    return -1;
  else if (left->ha_order > right->ha_order)
    return 1;

  /* if order is equal, allow gets precedence */
  if (left->ha_flag < right->ha_flag)
    return -1;
  if (left->ha_flag > right->ha_flag)
    return 1;

  return 0;
}

#define ACL_NEW(elm,ord,mask,flag,dst,obj,frw,rate,limit) \
ws_acl_t * elm = (ws_acl_t *) dk_alloc (sizeof (ws_acl_t)); \
{ \
  elm->ha_order = (ord); \
  elm->ha_mask = box_copy ((mask)); \
  elm->ha_flag = (flag); \
  elm->ha_dest = box_copy ((dst)); \
  elm->ha_obj = (obj); \
  elm->ha_rw = (frw); \
  elm->ha_rate = (rate); \
  elm->ha_cli_ip_w = NULL; \
  elm->ha_cli_ip_r = NULL; \
  elm->ha_hits = NULL; \
  elm->ha_limit = limit; \
  if (rate) { \
    elm->ha_hits = id_str_hash_create (101); \
    id_hash_set_rehash_pct (elm->ha_hits, 200); \
  } \
}

#define ACL_HT_FREE(ht) \
    if (ht) { \
      ptrlong *v; \
      caddr_t *k; \
      id_hash_iterator_t it; \
      id_hash_iterator (&it, ht); \
      while (hit_next (&it, (char **) &k, (char **) &v)) \
	{ \
	  dk_free_box (*k); \
	} \
      id_hash_free (ht); \
    } \

/*TODO: serialize a add/del */
static caddr_t
http_acl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int action, char * szMe)
{
#define ACL_ADD 0
#define ACL_DEL 1
#define ACL_GET 2
  caddr_t list_name = bif_string_arg (qst, args, 0, szMe);
  caddr_t *list, **plist;
  int rc = 0;

  sqlp_upcase (list_name);
  plist = (caddr_t **) id_hash_get (http_acls, (caddr_t) &list_name);
  list = plist ? *plist : NULL;

  switch (action)
    {
      case ACL_ADD:
	    {
	      int obj_is_null = 0, flag_rw_is_null = 0, limit_is_null = 0;
	      long order 	= (long) bif_long_arg (qst, args, 1, szMe);
	      caddr_t mask 	= bif_string_arg (qst, args, 2, szMe);
	      int flag 		= (int) bif_long_arg (qst, args, 3, szMe);
	      caddr_t dst 	= bif_string_or_null_arg (qst, args, 4, szMe);
	      long obj 		= (long) bif_long_or_null_arg (qst, args, 5, szMe, &obj_is_null);
	      int flag_rw 	= (int) bif_long_or_null_arg (qst, args, 6, szMe, &flag_rw_is_null);
	      float rate 	= BOX_ELEMENTS (args) > 7 ? bif_float_arg (qst, args, 7, szMe) : 0;
	      OFF_T limit 	= BOX_ELEMENTS (args) > 8 ? bif_long_or_null_arg (qst, args, 8, szMe, &limit_is_null) : 0;

	      int len = list ? BOX_ELEMENTS (list) : 0;
	      caddr_t *new_list = (caddr_t *) dk_alloc_box ((len + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      ACL_NEW (elm, order, mask, flag, dst, obj, flag_rw, rate, limit);

	      if (list)
		memcpy (new_list, list, sizeof (caddr_t) * len);

	      new_list[len] = (caddr_t) elm;
	      dk_free_box ((box_t) list);
	      if (plist)
		{
		  qsort (new_list, len+1, sizeof (caddr_t), acl_compare);
		  *plist = new_list;
		}
	      else
		{
		  caddr_t dlist_name = box_copy (list_name);
		  id_hash_set (http_acls, (caddr_t) &dlist_name, (caddr_t) &new_list);
		}
	      rc = flag;
	      break;
	    }
      case ACL_DEL:
	    {
	      long order 	= (long) bif_long_arg (qst, args, 1, szMe);
	      caddr_t mask 	= bif_string_arg (qst, args, 2, szMe);
	      int flag 		= (int) bif_long_arg (qst, args, 3, szMe);
	      int inx;
	      dk_set_t set = NULL;
	      caddr_t * new_list;

	      if (!list)
		break;

	      DO_BOX (ws_acl_t *, elm, inx, list)
		{
		  if (order != elm->ha_order || flag != elm->ha_flag || 0 != strcmp (mask, elm->ha_mask))
		     dk_set_push (&set, (void *) list[inx]);
		  else
		    {
		      list[inx] = NULL;
		      ACL_HT_FREE (elm->ha_cli_ip_r);
		      ACL_HT_FREE (elm->ha_cli_ip_w);
		      ACL_HT_FREE (elm->ha_hits);
		      dk_free (elm, sizeof (ws_acl_t));
		    }
		}
	      END_DO_BOX;

	      new_list = (caddr_t*) list_to_array (dk_set_nreverse(set));
              dk_free_box ((box_t) list);
 	      *plist = new_list;
	      rc = flag;
	      break;
	    }
      case ACL_GET:
	    {
	      int nargs = BOX_ELEMENTS (args);
	      caddr_t name = bif_string_arg (qst, args, 1, szMe);
	      caddr_t dst = nargs > 2 ? bif_string_or_null_arg (qst, args, 2, szMe) : NULL;
	      int obj_id = nargs > 3 ? (int) bif_long_arg (qst, args, 3, szMe) : -1;
	      int rw_flag = nargs > 4 ? (int) bif_long_arg (qst, args, 4, szMe) : -1;
	      int check_rate = nargs > 5 ? (int) bif_long_arg (qst, args, 5, szMe) : 0;

	      if (check_rate && check_rate != ACL_CHECK_MPS && check_rate != ACL_CHECK_HITS)
		sqlr_new_error ("22023", "HT080", "Check rate flag must be 0, 1 or 2");
	      rc =  http_acl_match (list, name, dst, obj_id, rw_flag, check_rate, NULL, NULL);
	      break;
	    }
      default:
	  sqlr_new_error ("22023", "HT060", "Unspecified operation supplied as first argument, must be 0, 1 or 2");
    }

  return box_num (rc);
}

static caddr_t
bif_http_acl_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return http_acl (qst, err_ret, args, ACL_ADD, "http_acl_set");
}

static caddr_t
bif_http_acl_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return http_acl (qst, err_ret, args, ACL_GET, "http_acl_get");
}

static caddr_t
bif_http_acl_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return http_acl (qst, err_ret, args, ACL_DEL, "http_acl_remove");
}

/* sqlprt.c */
void trset_start (caddr_t *qst);
void trset_printf (const char *str, ...);
void trset_end (void);

static void
http_acl_stats ()
{
  static char * szHttpAclName = "HTTP";
  caddr_t *alist, **plist;

  plist = (caddr_t **) id_hash_get (http_acls, (caddr_t) &szHttpAclName);
  alist = plist ? *plist : NULL;
  if (alist)
    {
      int inx;
      acl_hit_t * hit, **place;
      caddr_t *ip;
      id_hash_iterator_t it;

      DO_BOX (ws_acl_t *, elm, inx, alist)
	{
	  if (!elm->ha_rate || !elm->ha_hits)
	    continue;
	  id_hash_iterator (&it, elm->ha_hits);
	  while (hit_next (&it, (caddr_t *) &ip, (caddr_t *) &place))
	    {
	      hit = *place;
	      trset_printf ("%s : %f hits/sec.\n", *ip, hit->ah_avg);
	    }
	}
      END_DO_BOX;
    }
}

static caddr_t
bif_http_acl_stats (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  trset_start (qst);
  http_acl_stats ();
  trset_end ();
  return NULL;
}

static caddr_t
bif_sysacl_compose (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *src = bif_array_of_pointer_arg (qst, args, 0, "sysacl_compose");
  ptrlong maxperm = bif_long_range_arg (qst, args, 1, "sysacl_compose", 0, 0xff);
  caddr_t res;
  uint16 *gids;
  unsigned char *perms;
  int src_len, gid_ctr, ctr2, gid_count;
  src_len = BOX_ELEMENTS (src);
  if (src_len % 2)
    sqlr_new_error ("22023", "SA001", "The function sysacl_compose() expects get_keyword - style array of roles and permission bits as its argument)");
  gid_count = src_len/2;
  res = dk_alloc_box (gid_count * (sizeof (uint16) + 1) + 1, DV_STRING);
  gids = (uint16 *)res;
  perms = (unsigned char *)(res + gid_count * sizeof (uint16));
  for (gid_ctr = 0; gid_ctr < gid_count; gid_ctr++)
    {
      caddr_t src_grp = src [gid_ctr*2];
      dtp_t src_grp_dtp = DV_TYPE_OF (src_grp);
      caddr_t src_perm = src [gid_ctr*2 + 1];
      user_t *grp = NULL;
      boxint gid;
      boxint perm;
      if (DV_LONG_INT == src_grp_dtp)
        {
          grp = sec_id_to_user (unbox (src_grp));
          if (NULL == grp)
            {
              dk_free_box (res);
              sqlr_new_error ("22023", "SA002", "Unknown user or group id %ld", (long)unbox (src_grp));
            }
        }
      else if (DV_STRING == src_grp_dtp)
        {
          grp = sec_name_to_user (src_grp);
          if (NULL == grp)
            {
              dk_free_box (res);
              sqlr_new_error ("22023", "SA003", "Unknown user or group name \"%.200s\"", src_grp);
            }
        }
      else
        {
          dk_free_box (res);
          sqlr_new_error ("22023", "SA004", "User or group should be identified by name or integer id (U_NAME or U_ID from DB.DBA.SYS_USERS)");
        }
      gid = grp->usr_id;
      if (DV_LONG_INT != DV_TYPE_OF (src_perm))
        {
          dk_free_box (res);
          sqlr_new_error ("22023", "SA005", "Permissions for user or group should be integer");
        }
      perm = unbox (src_perm);
      if ((perm < 0) || (perm > maxperm))
        {
          dk_free_box (res);
          sqlr_new_error ("22023", "SA006", "Permission %ld is out of range of valid permisions (from 0 to %ld)", (long)perm, (long)maxperm);
        }
      for (ctr2 = 0; ctr2 < gid_ctr; ctr2++)
        {
          if (gids[ctr2] != gid)
            continue;
          dk_free_box (res);
          sqlr_new_error ("22023", "SA007", "User or group with id %ld is listed twice, in indicies %ld and %ld of the source vector", (long)gid, (long)(ctr2*2), (long)(gid_ctr*2));
        }
      gids[gid_ctr] = gid;
      perms[gid_ctr] = perm;
    }
/* Now bubble sort of the result */
  for (gid_ctr = gid_count; gid_ctr--; /* no step */)
    {
      for (ctr2 = 0; ctr2 < gid_ctr; ctr2++)
        {
          uint16 swap_gid;
          unsigned char swap_perm;
          if (gids[ctr2] < gids[ctr2+1])
            continue;
          swap_gid = gids[ctr2]; gids[ctr2] = gids[ctr2+1]; gids[ctr2+1] = swap_gid;
          swap_perm = perms[ctr2]; perms[ctr2] = perms[ctr2+1]; perms[ctr2+1] = swap_perm;
        }
    }
  perms[gid_count] = '\0'; /* Trailing zero of the string */
  return res;
}

static caddr_t
bif_sysacl_direct_bits_of_user (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t sysacl = bif_string_or_null_arg (qst, args, 0, "sysacl_direct_bits_of_user");
  user_t *user;
  oid_t uid;
  int gids_count;
  uint16 *gids_tail, *gids_end;
  if (NULL == sysacl)
    return box_num (0); /* to stay on safe side */
  if (1 < BOX_ELEMENTS (args))
    user = bif_user_t_arg (qst, args, 1, "sysacl_direct_bits_of_user", (USER_SHOULD_EXIST | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
  else
    user = ((query_instance_t *)qst)->qi_client->cli_user;
  uid = user->usr_id;
  gids_count = box_length (sysacl) - 1;
  if (gids_count % (sizeof (uint16) + 1))
    sqlr_new_error ("22023", "SA008", "Invalid sysacl string is passed to function sysacl_direct_bits_of_user()");
  gids_count = gids_count / (sizeof (uint16) + 1);
  gids_tail = (uint16 *)sysacl;
  gids_end = gids_tail + gids_count;
  while (gids_tail < gids_end)
    {
      if (gids_tail[0] < uid)
        gids_tail++;
      else if (gids_tail[0] > uid)
        break;
      else
        return box_num (((unsigned char *)gids_end)[gids_tail - (uint16 *)sysacl]);
    }
  return box_num (0);
}

static caddr_t
bif_sysacl_all_bits_of_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t sysacl = bif_string_or_null_arg (qst, args, 0, "sysacl_all_bits_of_tree");
  user_t *user;
  int res = 0, gids_count;
  uint16 *gids_tail, *gids_end;
  oid_t *flat_tail, *flat_end;
  if (NULL == sysacl)
    return box_num (0); /* to stay on safe side */
  if (1 < BOX_ELEMENTS (args))
    user = bif_user_t_arg (qst, args, 1, "sysacl_all_bits_of_tree", (USER_SHOULD_EXIST | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
  else
    user = ((query_instance_t *)qst)->qi_client->cli_user;
  if (0 == user->usr_flatten_g_ids_len)
    sec_usr_flatten_g_ids_refill (user);
  gids_count = box_length (sysacl) - 1;
  if (gids_count % (sizeof (uint16) + 1))
    sqlr_new_error ("22023", "SA008", "Invalid sysacl string is passed to function sysacl_all_bits_of_tree()");
  gids_count = gids_count / (sizeof (uint16) + 1);
  gids_tail = (uint16 *)sysacl;
  gids_end = gids_tail + gids_count;
  flat_tail = user->usr_flatten_g_ids;
  flat_end = flat_tail + user->usr_flatten_g_ids_len;
  while ((gids_tail < gids_end) && (flat_tail < flat_end))
    {
      if (gids_tail[0] < flat_tail[0])
        gids_tail++;
      else if (gids_tail[0] > flat_tail[0])
        flat_tail++;
      else
        {
          res |= ((unsigned char *)gids_end)[gids_tail - (uint16 *)sysacl];
          gids_tail++;
          flat_tail++;
        }
    }
  return box_num (res);
}

static int
sec_sysacl_bit1_of_tree (caddr_t sysacl, user_t *user)
{
  int gids_count;
  uint16 *gids_tail, *gids_end;
  oid_t *flat_tail, *flat_end;
  if (0 == user->usr_flatten_g_ids_len)
    sec_usr_flatten_g_ids_refill (user);
  gids_count = box_length (sysacl) - 1;
  if (gids_count % (sizeof (uint16) + 1))
    sqlr_new_error ("22023", "SA008", "Invalid sysacl string is passed to function sysacl_bit1_of_tree()");
  gids_count = gids_count / (sizeof (uint16) + 1);
  gids_tail = (uint16 *)sysacl;
  gids_end = gids_tail + gids_count;
  flat_tail = user->usr_flatten_g_ids;
  flat_end = flat_tail + user->usr_flatten_g_ids_len;
  while ((gids_tail < gids_end) && (flat_tail < flat_end))
    {
      if (gids_tail[0] < flat_tail[0])
        gids_tail++;
      else if (gids_tail[0] > flat_tail[0])
        flat_tail++;
      else
        {
          if (0x1 & ((unsigned char *)gids_end)[gids_tail - (uint16 *)sysacl])
            return 1;
          gids_tail++;
          flat_tail++;
        }
    }
  return 0;
}

static caddr_t
bif_sysacl_bit1_of_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t sysacl = bif_string_or_null_arg (qst, args, 0, "sysacl_bit1_of_tree");
  user_t *user;
  if (NULL == sysacl)
    return box_num (0); /* to stay on safe side */
  if (1 < BOX_ELEMENTS (args))
    user = bif_user_t_arg (qst, args, 1, "sysacl_bit1_of_tree", (USER_SHOULD_EXIST | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
  else
    user = ((query_instance_t *)qst)->qi_client->cli_user;
  return box_num (sec_sysacl_bit1_of_tree (sysacl, user));
}

void
bif_sysacl_bit1_of_tree_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  data_col_t * dc, *sysacl_arg, *user_arg = NULL;
  QNCAST (query_instance_t, qi, qst);
  db_buf_t set_mask = qi->qi_set_mask;
  int argcount, set, n_sets = qi->qi_n_sets, first_set = 0;
  state_slot_t * sysacl_ssl, *user_ssl;
  user_t *curr_user = NULL;

  if (!ret)
    return;
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  argcount = BOX_ELEMENTS (args);
  if (argcount < 1)
    sqlr_new_error ("42001", "VEC..", "Not enough arguments for sysacl_bit1_of_tree()");
  sysacl_ssl = args[0];
  sysacl_arg = QST_BOX (data_col_t *, qst, sysacl_ssl->ssl_index);
  if (argcount < 2)
    curr_user = ((query_instance_t *)qst)->qi_client->cli_user;
  else
    {
      user_ssl = args[1];
      if (SSL_VEC == user_ssl->ssl_type)
        user_arg = QST_BOX (data_col_t *, qst, user_ssl->ssl_index);
      else
        curr_user = bif_user_t_arg (qst, args, 1, "sysacl_bit1_of_tree", (USER_SHOULD_EXIST | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
    }
  DC_CHECK_LEN (dc, qi->qi_n_sets - 1);
  SET_LOOP
    {
      caddr_t sysacl = NULL, user_name_or_id = NULL;
      int sysacl_row_no, user_row_no;
      int bit1;
      if (SSL_REF == sysacl_ssl->ssl_type)
        sysacl_row_no = sslr_set_no (qst, sysacl_ssl, set);
      else
        sysacl_row_no = set;
      if (DCT_BOXES & sysacl_arg->dc_type)
        sysacl = ((caddr_t*)(sysacl_arg->dc_values))[sysacl_row_no];
      else if (DV_ANY == sysacl_arg->dc_dtp)
        {
          db_buf_t ser = ((db_buf_t*)(sysacl_arg->dc_values))[sysacl_row_no];
          if (DV_DB_NULL == ser[0])
            { bit1 = 0; goto ans_done; }
          sysacl = box_deserialize_string ((caddr_t)ser, 0, 0);
        }
      else
        {
          if (DC_IS_NULL (sysacl_arg, sysacl_row_no))
            { bit1 = 0; goto ans_done; }
        }
      if (DV_STRING != DV_TYPE_OF (sysacl))
        {
          if (DV_DB_NULL == DV_TYPE_OF (sysacl))
            { bit1 = 0; goto ans_done; }
          sqlr_new_error ("42001", "VEC..", "Wrong dadatype of sysacl");
        }
      if (NULL != user_arg)
        {
          if (SSL_REF == user_ssl->ssl_type)
            user_row_no = sslr_set_no (qst, user_ssl, set);
          else
            user_row_no = set;
          if (DCT_BOXES & user_arg->dc_type)
            user_name_or_id = ((caddr_t*)(user_arg->dc_values))[user_row_no];
          else if (DV_ANY == user_arg->dc_dtp)
            {
              db_buf_t ser = ((db_buf_t*)(user_arg->dc_values))[user_row_no];
              if (DV_DB_NULL == ser[0])
                { bit1 = 0; goto ans_done; }
              user_name_or_id = box_deserialize_string ((caddr_t)ser, 0, 0);
            }
          else
            {
              if (DC_IS_NULL (user_arg, user_row_no))
                { bit1 = 0; goto ans_done; }
              if (DV_LONG_INT == user_arg->dc_dtp)
                {
                  int64 i = ((int64*)(user_arg->dc_values))[user_row_no];
                  curr_user = sec_id_to_user (i);
                  bit1 = ((NULL == curr_user) ? 0 : sec_sysacl_bit1_of_tree (sysacl, curr_user));
                  goto ans_done;
                }
            }
          switch (DV_TYPE_OF (user_name_or_id))
            {
            case DV_LONG_INT: curr_user = sec_id_to_user (unbox (user_name_or_id)); break;
            case DV_STRING: curr_user = sec_name_to_user (user_name_or_id); break;
            default: bit1 = 0; goto ans_done;
            }
        }
      bit1 = sec_sysacl_bit1_of_tree (sysacl, curr_user);
ans_done:
      dc_set_long (dc, set, bit1);
    }
  END_SET_LOOP;
}

/*
   Caching of the dynamic resources
*/

#define NO_CADDR_T NULL

#define WS_NO_CACHE 0
#define WS_CACHE_HIT 1
#define WS_CACHE_STORE 2

int
ws_cache_check (ws_connection_t * ws)
{
  int rc = 0;
  caddr_t *place = NULL;
  static query_t * check_qr = NULL;
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  caddr_t url;

  if (!ws->ws_path)
    return WS_NO_CACHE;

  url = ws_soap_get_url (ws, 1);
  place = (caddr_t *)id_hash_get (http_url_cache, (caddr_t) &url);

  if (place)
    {
      caddr_t * pars = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

      if (!check_qr)
	check_qr = sql_compile_static ("WS.WS.HTTP_CACHE_CHECK (?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
      if (!check_qr)
	{
	  log_error ("No WS.WS.HTTP_CACHE_CHECK defined");
	  dk_free_box (url);
	  return WS_NO_CACHE;
	}
      if (check_qr->qr_to_recompile)
        check_qr = qr_recompile (check_qr, NULL);

      pars[0] = (caddr_t) box_copy (ws->ws_path_string);
      pars[1] = (caddr_t) box_copy_tree ((box_t) ws->ws_lines);
      pars[2] = (caddr_t) box_copy (*place);

      err = qr_exec (ws->ws_cli, check_qr, CALLER_LOCAL, NULL, NULL, &lc, pars, NULL, 0);
      dk_free_box ((box_t) pars);
      if (lc && DV_ARRAY_OF_POINTER == DV_TYPE_OF (lc->lc_proc_ret)
	  && BOX_ELEMENTS ((caddr_t *)lc->lc_proc_ret) > 1)
	rc = (int) unbox (((caddr_t *)lc->lc_proc_ret)[1]);

      if (!err && rc == WS_CACHE_STORE)
	{
	  ws->ws_store_in_cache = (caddr_t) box_copy (ws->ws_path_string);
	}

      if (lc)
	lc_free (lc);
      if (err)
	dk_free_tree (err);
    }
  dk_free_box (url);
  return (rc == WS_CACHE_HIT);
}

void
ws_cache_store (ws_connection_t * ws, int store)
{
  static query_t * store_qr = NULL;
  caddr_t err = NULL;
  caddr_t * pars = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);


  if (ws->ws_flushed || IS_CHUNKED_OUTPUT (ws) || (ws->ws_status_code && ws->ws_status_code != 200))
    store = 0;

  if (!store_qr)
    store_qr = sql_compile_static ("WS.WS.HTTP_CACHE_STORE (?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
  pars[0] = ws->ws_store_in_cache;
  ws->ws_store_in_cache = NULL;
  pars[1] = (caddr_t) box_num_nonull ((ptrlong) store);
  err = qr_exec (ws->ws_cli, store_qr, CALLER_LOCAL, NULL, NULL, NULL, pars, NULL, 0);
  dk_free_box ((box_t) pars);
  if (err)
    dk_free_tree (err);
}


static caddr_t
bif_http_url_cache_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * szMe = "http_url_cache_set";
  caddr_t url = bif_string_arg (qst, args, 0, szMe);
  caddr_t check = bif_string_arg (qst, args, 1, szMe);
  caddr_t *place = (caddr_t *)id_hash_get (http_url_cache, (caddr_t)&url);
  caddr_t check_copy = box_copy (check);
  if (place)
    {
      dk_free_box (*place);
      id_hash_set (http_url_cache, (caddr_t) &url, (caddr_t) &check_copy);
    }
  else
    {
      caddr_t url_copy = box_copy (url);
      id_hash_set (http_url_cache, (caddr_t) &url_copy, (caddr_t) &check_copy);
    }
  return NO_CADDR_T;
}

static caddr_t
bif_http_url_cache_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * szMe = "http_url_cache_get";
  caddr_t url = bif_string_arg (qst, args, 0, szMe);
  caddr_t *place = (caddr_t *)id_hash_get (http_url_cache, (caddr_t)&url);
  if (place)
    return box_copy (*place);
  return NEW_DB_NULL;
}

static caddr_t
bif_http_url_cache_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * szMe = "http_url_cache_remove";
  caddr_t url = bif_string_arg (qst, args, 0, szMe);
  caddr_t *place = (caddr_t *)id_hash_get (http_url_cache, (caddr_t)&url);
  if (place)
    {
      caddr_t *pkey = (caddr_t *)id_hash_get_key (http_url_cache, (caddr_t)&url);
      caddr_t key = *pkey, data = *place;
      id_hash_remove (http_url_cache, (char *)&url);
      dk_free_box (key);
      dk_free_box (data);
    }
  return NO_CADDR_T;
}

static void
http_init_acl_and_cache ()
{
  /* INIT the general HTTP ACL */
  http_acls = id_str_hash_create (101);
  http_url_cache = id_str_hash_create (101);
  ddl_sel_for_effect ("select count(*) from DB.DBA.HTTP_ACL where "
      "http_acl_set (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_DEST_IP, HA_OBJECT, HA_RW, HA_RATE, HA_LIMIT)");
  ddl_sel_for_effect ("select count(*) from WS.WS.SYS_CACHEABLE where http_url_cache_set (CA_URI, CA_CHECK)");
}


static caddr_t
bif_tcpip_gethostbyname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t host = bif_string_arg (qst, args, 0, "tcpip_gethostbyname");
  char ip_addr[50];

  srv_ip (ip_addr, sizeof (ip_addr), host);
  return box_dv_short_string (ip_addr);
}



static caddr_t
bif_tcpip_gethostbyaddr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ip_addr = bif_string_arg (qst, args, 0, "tcpip_gethostbyaddr");

  return ws_gethostbyaddr (ip_addr);
}

static caddr_t
bif_tcpip_local_interfaces (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_copy_tree (local_interfaces);
}

static caddr_t
bif_http_full_request (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong destructive = bif_long_arg (qst, args, 0, "http_full_request");
  query_instance_t *qi = (query_instance_t *)qst;
  if (!qi->qi_client->cli_ws || !qi->qi_client->cli_ws->ws_ses_trap)
    return NEW_DB_NULL;
  if (destructive)
    {
      dk_session_t *res = qi->qi_client->cli_ws->ws_req_log;
      qi->qi_client->cli_ws->ws_req_log = NULL;
      return (caddr_t) res;
    }
  if (!STRSES_CAN_BE_STRING (qi->qi_client->cli_ws->ws_req_log))
    {
      *err_ret = STRSES_LENGTH_ERROR ("http_full_request");
      return NULL;
    }
  else
    return strses_string (qi->qi_client->cli_ws->ws_req_log);
}

static caddr_t
bif_http_get_string_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ptrlong arg = BOX_ELEMENTS (args) > 0 ? bif_long_arg (qst, args, 0, "http_get_string_output") : 0;

  if (!qi->qi_client->cli_ws || !qi->qi_client->cli_ws->ws_strses)
    sqlr_new_error ("37000", "HT062", "http output function outside of http context : http_get_string_output");
  if (!arg)
    {
      if (!STRSES_CAN_BE_STRING (qi->qi_client->cli_ws->ws_strses))
	{
	  *err_ret = STRSES_LENGTH_ERROR ("http_get_string_output");
	  return NULL;
	}
      else
	return strses_string (qi->qi_client->cli_ws->ws_strses);
    }
  else
    {
      dk_session_t * ses = strses_allocate ();
      strses_enable_paging (ses, arg);
      strses_write_out (qi->qi_client->cli_ws->ws_strses, ses);
      return (caddr_t)ses;
    }
}

static caddr_t
bif_http_strses_memory_size (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (http_ses_size);
}

static caddr_t
bif_http_string_date (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rfc_date = bif_string_or_null_arg (qst, args, 0, "http_string_date");
  char temp[DT_LENGTH];
  caddr_t res;

  if (NULL == rfc_date)
    {
      if (2 > BOX_ELEMENTS (args))
        sqlr_new_error ("22007", "DT012", "HTTP string date is NULL and no default specified");
      return box_copy_tree (bif_arg (qst, args, 1, "http_string_date"));
    }
  memset (temp, 0, sizeof (temp));
  if (http_date_to_dt (rfc_date, temp))
    {
      res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
      memcpy (res, temp, DT_LENGTH);
      return (res);
    }
  if (3 > BOX_ELEMENTS (args))
    sqlr_new_error ("22007", "DT006", "Invalid HTTP string date: cannot convert '%.1000s' to datetime", rfc_date);
  return box_copy_tree (bif_arg (qst, args, 2, "http_string_date"));
}

#ifdef _IMSG
static caddr_t
bif_ftp_log (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t file_name = bif_string_arg (qst, args, 0, "__ftp_log");
  caddr_t command = bif_string_arg (qst, args, 1, "__ftp_log");
  caddr_t resp = bif_string_arg (qst, args, 2, "__ftp_log");
  caddr_t user = bif_string_arg (qst, args, 3, "__ftp_log");
  ptrlong len = bif_long_arg (qst, args, 4, "__ftp_log");

  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t iaddr, host_name;

  char buff[4096];
  struct tm *tm;
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
  struct tm tm1;
#endif
  char * monday [] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  time_t now;
  int month, day, year;
  char * new_log = NULL;

  buff[0] = 0;
  time (&now);
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
  tm = localtime_r (&now, &tm1);
#else
  tm = localtime (&now);
#endif
  month = tm->tm_mon + 1;
  day = tm->tm_mday;
  year = tm->tm_year + 1900;

  if (!qi->qi_client->cli_ws)
    iaddr = http_client_ip (qi->qi_client->cli_session->dks_session);
  else
    iaddr = qi->qi_client->cli_ws->ws_client_ip;

  host_name = ws_gethostbyaddr (iaddr);

  if (!qi->qi_client->cli_ws)
    dk_free_box (iaddr);

  snprintf (buff, sizeof (buff), "%s %s [%02d/%s/%04d:%02d:%02d:%02d %+05li] \"%.2000s\" %.3s %ld\n",
      host_name, user, (tm->tm_mday), monday [month - 1], year,
      tm->tm_hour, tm->tm_min, tm->tm_sec, (long) dt_local_tz/36*100,
      command, resp, len);

  dk_free_box (host_name);

  mutex_enter (ftp_log_mtx);

  if (strcmp (ftp_log_name, file_name) || !ftp_log_name || !ftp_log)
    {
      if (ftp_log)
	{
	  fflush (ftp_log);
	  fclose (ftp_log);
	}
      ftp_log = fopen (file_name, "a");
      if (!ftp_log)
	{
	  log_error ("Can't open new FTP log file (%s)", new_log);
	  mutex_leave (ftp_log_mtx);
	  return box_num (0);
	}
      strcpy_ck (ftp_log_name_str, file_name);
    }
  fputs (buff, ftp_log);
  fflush (ftp_log);

  mutex_leave (ftp_log_mtx);

  return box_num (1);
}
#endif

/*
 session keeping and reusing
 XXX: fix the error codes
 */
void
ws_serve_client_connection (ws_connection_t * ws)
{
  dk_session_t * ses = ws->ws_session;
  caddr_t * args = (caddr_t *) DKS_DB_DATA (ses);
  caddr_t p_name = args[0], cd = args[1], err = NULL, *conn;
  client_connection_t * cli = ws->ws_cli;
  static query_t * qr = NULL;
  query_t * proc;
  int rc = LTE_OK;

  http_trace (("ws_serve_client_connection ses=%p\n", ses));
  ws->ws_session = NULL;
  ws->ws_cli->cli_http_ses = ws->ws_session;
  ws_clear (ws, 0);
  ws->ws_ignore_disconnect = 1;

  if (!qr)
    qr = sql_compile_static ("call (?) (?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);

  if (err)
    goto err_end;

  if (!(proc = (query_t *)sch_name_to_object (wi_inst.wi_schema, sc_to_proc, p_name, NULL, "dba", 0)))
    goto err_end;

  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, &err);

  if (err)
    goto err_end;

  conn = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_CONNECTION);
  conn[0] = (caddr_t) ses;

  IN_TXN;
  if (!cli->cli_trx->lt_threads)
    lt_wait_checkpoint ();
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;

  err = qr_quick_exec (qr, cli, NULL, NULL, 3,
      ":0", p_name, QRP_STR,
      ":1", conn, QRP_RAW,
      ":2", cd, QRP_RAW);

  args[1] = NULL;
  IN_TXN;
  if (err && (err != (caddr_t) SQL_NO_DATA_FOUND))
    lt_rollback (cli->cli_trx, TRX_CONT);
  else
    rc = lt_commit (cli->cli_trx, TRX_CONT);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;

err_end:
  dk_free_tree ((box_t) args);
  if (err && err != (caddr_t)SQL_NO_DATA_FOUND)
    {
      dk_free_tree (err);
    }
  http_trace (("end ws_serve_client_connection ses=%p\n", ses));
  /* XXX: the ses is disconnected & freed inside dv_connection memhooks
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  */
  ws_connection_vars_clear (cli);
  ws->ws_session = NULL;
}

static void
http_on_message_input_ready (dk_session_t * ses)
{
  ws_connection_t * ws;

  if (SESSION_SCH_DATA (ses)->sio_is_served == -1)
    GPF_T;

  ses->dks_ws_status = DKS_WS_CLIENT;
  DKS_CLEAR_DEFAULT_READ_READY_ACTION (ses);
  remove_from_served_sessions (ses);

  mutex_enter (ws_queue_mtx);
  ws = (ws_connection_t *) resource_get (ws_dbcs);
  if (!ws)
    {
      basket_add (&ws_queue, (void*) ses);
      mutex_leave (ws_queue_mtx);
    }
  else
    {
      mutex_leave (ws_queue_mtx);
      ws->ws_session = ses;
      semaphore_leave (ws->ws_thread->thr_sem);
    }

}

static void
http_on_message_ses_dropped (dk_session_t * ses)
{
  if (DKSESSTAT_ISSET (ses, SST_NOT_OK))
    remove_from_served_sessions (ses);
}

static caddr_t
bif_http_on_message (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t *conn = (caddr_t *) bif_arg (qst, args, 0, "http_on_message");
  caddr_t func = bif_string_arg (qst, args, 1, "http_on_message");
  caddr_t cd = bif_arg (qst, args, 2, "http_on_message");
  dk_session_t * ses = NULL;
  ws_connection_t * ws = qi->qi_client->cli_ws;

  if (DV_CONNECTION == DV_TYPE_OF (conn))
    {
      ses = (dk_session_t *) conn[0];
      if (DKSESSTAT_ISSET (ses, SST_OK))
        conn[0] = NULL;
      else
	ses = NULL;
      mutex_enter (thread_mtx);
      if (ws && ses && ses == ws->ws_session)
	{
	  ws->ws_session->dks_ws_status = DKS_WS_CACHED;
	  ws->ws_session->dks_n_threads++;
	}
      mutex_leave (thread_mtx);
    }
  else if (ws && ws->ws_session)
    {
      /* We should mark the session so it will not be disconnected nor freed */
      if (ws->ws_flushed)
	sqlr_new_error ("42000", "HT000", "The client session is already flushed");
      mutex_enter (thread_mtx);
      ses = qi->qi_client->cli_ws->ws_session;
      ws->ws_session->dks_ws_status = DKS_WS_CACHED;
      ws->ws_session->dks_n_threads++;
      mutex_leave (thread_mtx);
    }

  if (ses == NULL)
    sqlr_new_error ("22023", "HT000", "The http_on_message expects an open connection as 1-st argument");
  http_trace (("http_on_message ses=%p\n", ses));
  DKS_DB_DATA (ses) = (client_connection_t *) list (2, box_copy (func), box_copy_tree (cd));
  PrpcSetPartnerDeadHook (ses, (io_action_func) http_on_message_ses_dropped);
  SESSION_SCH_DATA (ses)->sio_default_read_ready_action = (io_action_func) http_on_message_input_ready;
  PrpcCheckInAsync (ses);

  return NEW_DB_NULL;
}

dk_hash_t * ws_cli_sessions;
dk_mutex_t * ws_cli_mtx;

static caddr_t
bif_http_keep_session (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t * conn = (caddr_t *) bif_arg (qst, args, 0, "http_keep_session");
  long id = bif_long_arg (qst, args, 1, "http_keep_session");
  dk_session_t * ses = NULL;
  ws_connection_t * ws = qi->qi_client->cli_ws;

  if (DV_CONNECTION == DV_TYPE_OF (conn))
    {
      ses = (dk_session_t *) conn[0];
      if (DKSESSTAT_ISSET (ses, SST_OK))
        conn[0] = NULL;
      else
	ses = NULL;
    }
  else if (ws)
    {
      /* We should mark the session so it will not be disconnected nor freed */
      if (ws->ws_flushed)
	sqlr_new_error ("42000", "HT000", "The client session is already flushed");
      ses = qi->qi_client->cli_ws->ws_session;
      mutex_enter (thread_mtx);
      ws->ws_session->dks_ws_status = DKS_WS_CACHED;
      ws->ws_session->dks_n_threads++;
      ws->ws_flushed = 1;
      mutex_leave (thread_mtx);
    }

  if (ses == NULL)
    sqlr_new_error ("22023", "HT000", "The http_keep_session expects an open connection as 1-st argument");

  /* we have to check if this id exists to do not overlap existing one */
  mutex_enter (ws_cli_mtx);
  if (NULL == gethash ((void *) (ptrlong) id, ws_cli_sessions))
    sethash ((void *) (ptrlong) id, ws_cli_sessions, (void *) ses);
  else
    *err_ret = srv_make_new_error ("22023", "HT000", "The id specified already exists in the cache");
  mutex_leave (ws_cli_mtx);
  return NEW_DB_NULL;
}

static caddr_t
bif_http_recall_session (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  long id = bif_long_arg (qst, args, 0, "http_recall_session");
  dk_session_t * ses = NULL;
  caddr_t * ret = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_CONNECTION);
  ws_connection_t * ws = qi->qi_client->cli_ws;
  semaphore_t * volatile sem = NULL;

  mutex_enter (ws_cli_mtx);
  ses = (dk_session_t *) gethash ((void *) (ptrlong) id, ws_cli_sessions);
  remhash ((void *) (ptrlong) id, ws_cli_sessions);
  mutex_leave (ws_cli_mtx);

  ret[0] = (caddr_t) ses;
  ret[1] = (caddr_t) 1;

  if (ws && ses == ws->ws_session)
    {
      mutex_enter (thread_mtx);
      ses->dks_n_threads--;
      ws->ws_session->dks_ws_status = DKS_WS_ACCEPTED;
      ws->ws_flushed = 0;
      mutex_leave (thread_mtx);
      ret[1] = 0;
    }

  mutex_enter (thread_mtx);
  if (ses && ses->dks_n_threads > 0)
    {
      ses->dks_waiting_http_recall_session = THREAD_CURRENT_THREAD;
      sem = ses->dks_waiting_http_recall_session->thr_sem;
    }
  mutex_leave (thread_mtx);

  if (sem)
    {
      semaphore_enter (sem);
    }

  return (caddr_t)ret;
}

caddr_t
bif_http_current_charset (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t * ws = qi->qi_client->cli_ws;
  wcharset_t *charset = WS_CHARSET (ws, qst);
  return box_dv_short_string (CHARSET_NAME (charset, "ISO-8859-1"));
}


caddr_t
bif_http_status_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  int code = bif_long_arg (qst, args, 0, "http_status_set");
  caddr_t new_stat;
  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT012", "http_status_set function is allowed only inside HTTP request");
  new_stat = ws_http_error_header (code);
  HTTP_SET_STATUS_LINE (qi->qi_client->cli_ws, new_stat, 1);
  return new_stat;
}

caddr_t
bif_http_methods_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t * ws;
  int inx, m;
  if (!qi->qi_client->cli_http_ses)
    sqlr_new_error ("42000", "HT012", "http_methods_set function is allowed only inside HTTP request");
  ws = qi->qi_client->cli_ws;
  http_set_default_options (ws);
  for (inx = 0; inx < BOX_ELEMENTS (args); inx ++)
    {
      caddr_t v = bif_string_or_null_arg (qst, args, inx, "http_methods_set");
      m = http_method_id (v);
      ws->ws_options [m] = '\x1';
    }
  return NULL;
}

caddr_t *
box_tpcip_get_interfaces ()
{
  dk_set_t set = NULL;
#ifdef SIOCGIFCONF
#define MAX_IFS 32
  struct ifreq *ifrp;
  struct ifconf ifc;
  char buf[sizeof(struct ifreq)*MAX_IFS];
#endif
  int sockfd;
  struct sockaddr_in addr;
  int eno, len;
  char message[255];

  sockfd = socket(PF_INET,SOCK_DGRAM,0);
  if (sockfd < 0 )
    {
      eno = errno;
      tcpses_error_message (eno, message, sizeof (message));
      log_error ("Failed create socket to obtain network interfaces : %s", message);
    }

#ifdef SIOCGIFCONF
  memset (buf, 0, sizeof(buf));
  ifc.ifc_len = sizeof( buf );
  ifc.ifc_buf = (caddr_t)buf;

  if (ioctl(sockfd, SIOCGIFCONF, (caddr_t)&ifc) < 0)
    {
      eno = errno;
      tcpses_error_message (eno, message, sizeof (message));
      log_error ("Failed to get network interfaces : %s", message);
    }

  ifrp = ifc.ifc_req;
  for (len = ifc.ifc_len; len > 0; /* len -= sizeof (struct ifreq) calculated below */)
    {
      if (ifrp->ifr_addr.sa_family == AF_INET)
	{
	  memcpy (&addr, &(ifrp->ifr_addr), sizeof (struct sockaddr_in));
	  snprintf (message, sizeof (message), "%s", inet_ntoa(addr.sin_addr));
	  dk_set_push (&set, box_string (message));
	}
      /* The FreeBSD returns variable length */
#if defined (__FreeBSD__) || defined (__APPLE__)
      ifrp = (struct ifreq *)((char *)&(ifrp->ifr_addr) + ifrp->ifr_addr.sa_len);
      len -= ifrp->ifr_addr.sa_len;
#else
      ifrp++;
      len -= sizeof (struct ifreq);
#endif
    }
#elif defined (SIO_GET_INTERFACE_LIST)
    {
      INTERFACE_INFO buf[100];
      int len;
      DWORD cbBytesReturned;

      if (WSAIoctl (sockfd, SIO_GET_INTERFACE_LIST, NULL, 0, buf, sizeof(buf), &cbBytesReturned, NULL, NULL) == 0)
	{
	  for (len = 0; len < (int) (cbBytesReturned / sizeof (INTERFACE_INFO)); len++)
	    {
	      if ((buf[len].iiFlags & IFF_UP) && (buf[len].iiFlags & IFF_BROADCAST))
		{
		  unsigned char *pNetMask, *pBroad;
		  memcpy (&addr, &buf[len].iiAddress, sizeof (struct sockaddr_in));
		  snprintf (message, sizeof (message), "%s", inet_ntoa(addr.sin_addr));
		  dk_set_push (&set, box_string (message));
		}
	    }
	}
    }
#endif
  closesocket(sockfd);
  return (caddr_t *) list_to_array (dk_set_nreverse (set));
}

int
http_init_part_one ()
{
  XML_CHAR_ESCAPE ('<', "&lt;");
  XML_CHAR_ESCAPE ('>', "&gt;");
  XML_CHAR_ESCAPE ('&', "&amp;");
  XML_CHAR_ESCAPE ('"', "&quot;");
  XML_CHAR_ESCAPE (0, "");

  DAV_CHAR_ESCAPE ('<', "%3C");
  DAV_CHAR_ESCAPE ('>', "%3E");
  DAV_CHAR_ESCAPE ('&', "%26");
  DAV_CHAR_ESCAPE ('"', "%22");

  bif_define_ex ("http_auth", bif_http_auth, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_client_ip", bif_http_client_ip, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("sys_connected_server_address", bif_sys_connected_server_address, BMD_RET_TYPE, &bt_varchar, BMD_DONE);

  bif_define ("http_rewrite", bif_http_rewrite);
  bif_define ("http_enable_gz", bif_http_enable_gz);
  bif_define_ex ("http_header", bif_http_header, BMD_ALIAS, "http_response_header", BMD_DONE);
  bif_define ("http_host", bif_http_host);
  bif_define_ex ("http_header_get", bif_http_header_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_header_array_get", bif_http_header_array_get, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define ("http", bif_http_result);
  bif_define ("http_xmlelement_start", bif_http_xmlelement_start);
  bif_define ("http_xmlelement_empty", bif_http_xmlelement_empty);
  bif_define ("http_xmlelement_end", bif_http_xmlelement_end);
  bif_define ("http_value", bif_http_value);
  bif_define ("http_url", bif_http_url);
  bif_define ("http_uri", bif_http_uri);
  bif_define ("http_dav_url", bif_http_dav_url);
  bif_define ("http_escape", bif_http_escape);
  bif_define ("http_file", bif_http_file);
  bif_define ("http_proxy", bif_http_proxy);
  bif_define ("http_request_status", bif_http_request_status);
  bif_define_ex ("http_request_status_get", bif_http_request_status_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_typed (ENC_B64_NAME, bif_encode_base64, &bt_varchar);
  bif_define_typed (DEC_B64_NAME, bif_decode_base64, &bt_varchar);
  bif_define_ex ("encode_base64url", bif_encode_base64url, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("decode_base64url", bif_decode_base64url, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_root", bif_http_root, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("dav_root", bif_dav_root, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_path", bif_http_path, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("http_internal_redirect", bif_http_internal_redirect);
#if 0
  bif_define_ex ("http_get", bif_http_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
#endif
  bif_define_ex ("http_client_cache_enable", bif_http_client_cache_enable, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("string_output", bif_string_output, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("string_output_string", bif_string_output_string, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("string_output_flush", bif_string_output_flush);
  bif_define ("http_output_flush", bif_http_output_flush);
  bif_define_ex ("server_http_port", bif_server_http_port, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("server_https_port", bif_server_https_port, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("http_xslt", bif_http_xslt);
  bif_define_ex ("ses_read_line", bif_ses_read_line, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("ses_read", bif_ses_read, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("ses_can_read_char", bif_ses_can_read_char, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define("http_flush", bif_http_flush);
  bif_define ("http_pending_req", bif_http_pending_req);
  bif_define ("http_kill", bif_http_kill);
  bif_define ("http_limited", bif_http_limited);
  bif_define ("http_lock", bif_http_lock);
  bif_define ("http_unlock", bif_http_unlock);
  bif_define ("http_request_header", bif_http_request_header);
  bif_define ("http_request_header_full", bif_http_request_header_full);
  bif_define_ex ("http_param", bif_http_param, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_set_params", bif_http_set_params, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_body_read", bif_http_body_read, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("__http_stream_params", bif_http_stream_params, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("is_http_ctx", bif_is_http_ctx, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("is_https_ctx", bif_is_https_ctx, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_is_flushed", bif_http_is_flushed, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define ("https_renegotiate", bif_https_renegotiate);
  bif_define_ex ("http_debug_log", bif_http_debug_log, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define("http_login_failed", bif_http_login_failed);
#ifdef VIRTUAL_DIR
  bif_define_ex ("http_physical_path", bif_http_physical_path, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("http_map_table", bif_http_map_table);
  bif_define_ex ("http_map_del", bif_http_map_del, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_listen_host", bif_http_listen_host, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_map_get", bif_http_map_get, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_request_get", bif_http_request_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_physical_path_resolve", bif_http_physical_path_resolve, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
#endif
  bif_define_ex ("http_dav_uid", bif_http_dav_uid, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("http_admin_gid", bif_http_admin_gid, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("http_nobody_uid", bif_http_nobody_uid, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("http_nogroup_gid", bif_http_nogroup_gid, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("http_auth_verify", bif_http_auth_verify, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_acl_set", bif_http_acl_set, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_acl_get", bif_http_acl_get, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_acl_remove", bif_http_acl_remove, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_acl_stats", bif_http_acl_stats, BMD_RET_TYPE, &bt_any, BMD_DONE);

  bif_define_ex ("sysacl_compose", bif_sysacl_compose, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("sysacl_direct_bits_of_user", bif_sysacl_direct_bits_of_user, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("sysacl_all_bits_of_tree", bif_sysacl_all_bits_of_tree, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("sysacl_bit1_of_tree", bif_sysacl_bit1_of_tree, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_set_vectored (bif_sysacl_bit1_of_tree, bif_sysacl_bit1_of_tree_vec);

  bif_define ("http_url_cache_set", bif_http_url_cache_set);
  bif_define ("http_url_cache_get", bif_http_url_cache_get);
  bif_define ("http_url_cache_remove", bif_http_url_cache_remove);

  bif_define_ex ("tcpip_gethostbyname", bif_tcpip_gethostbyname, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("tcpip_gethostbyaddr", bif_tcpip_gethostbyaddr, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("tcpip_local_interfaces", bif_tcpip_local_interfaces, BMD_RET_TYPE, &bt_any, BMD_DONE);

  bif_define ("http_full_request", bif_http_full_request);
  bif_define ("http_get_string_output", bif_http_get_string_output);
  bif_define ("http_strses_memory_size", bif_http_strses_memory_size);
  bif_define ("http_string_date", bif_http_string_date); /* HTTP rfc date to datetime */
  bif_define ("http_sys_parse_ranges_header", bif_http_sys_parse_ranges_header);
  bif_define ("http_sys_find_best_accept", bif_http_sys_find_best_accept);
#ifdef _IMSG
  bif_define ("__ftp_log", bif_ftp_log);
#endif
  bif_define ("http_on_message", bif_http_on_message);
  bif_define ("http_keep_session", bif_http_keep_session);
  bif_define ("http_recall_session", bif_http_recall_session);
  bif_define ("http_current_charset", bif_http_current_charset);
  bif_define_ex ("http_status_set", bif_http_status_set, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_methods_set", bif_http_methods_set, BMD_RET_TYPE, &bt_any, BMD_DONE);
  ws_cli_sessions = hash_table_allocate (100);
  ws_cli_mtx = mutex_allocate ();
#ifdef VIRTUAL_DIR
  http_map = id_str_hash_create (101);
  http_listeners = id_str_hash_create (101);
  http_failed_listeners = id_str_hash_create (101);
  http_listeners_mutex = mutex_allocate ();
  mutex_option (http_listeners_mutex, "http_listeners_mutex", NULL, NULL);
#endif

  con_dav_v_name = box_dv_short_string ("DAVUserID");
  con_dav_v_null = dk_alloc_box (0, DV_DB_NULL);
  con_dav_v_zero = box_num (0);
  if (ws_default_charset_name)
    ws_default_charset = sch_name_to_charset (ws_default_charset_name);
  if (!ws_default_charset)
    {
      if (ws_default_charset_name && !strcmp (ws_default_charset_name, "UTF-8"))
	ws_default_charset = CHARSET_UTF8;
      else
	{
	  ws_default_charset = default_charset;
	  if (ws_default_charset_name)
	    log_error (
		"Default HTTP charset %.200s not defined."
		" Reverting to the default database charset",
		ws_default_charset_name);
	}
    }
  ws_queue_mtx = mutex_allocate ();
  ws_http_log_mtx = mutex_allocate (); /* for HTTP log writing */
  http_acl_mtx = mutex_allocate (); /* for HTTP log writing */
  ftp_log_mtx = mutex_allocate (); /* for FTP log writing */
  if (http_threads)
    ws_dbcs = resource_allocate (http_threads, NULL, NULL, NULL, NULL);

  http_max_keep_alives += http_threads; /* each thread may keep its connection in the select set to watch for async disconnect */
  ws_cache_mtx = mutex_allocate ();

  if (!http_server_id_string)
    {
      snprintf (http_server_id_string_buf, sizeof (http_server_id_string_buf),
	  "Virtuoso/%s (%s) %s%s%s", DBMS_SRV_VER, build_opsys_id, build_host_id,
	    build_special_server_model[0] ? " " : "",
	    build_special_server_model
	  );
      http_server_id_string = http_server_id_string_buf;
    }

  dns_host_name = get_qualified_host_name ();
  return 1;
}

dk_set_t ws_threads;

void
http_threads_allocate (int n_threads)
{
  int inx;
  for (inx = 0; inx < n_threads; inx++)
    {
      ws_connection_t * ws = ws_new_connection ();
      dk_thread_t *thr;

      thr = PrpcThreadAllocate ((init_func) ws_init_func, http_thread_sz,  ws);
      if (!thr)
	{
	  log_error ("Unable to create HTTP thread because of an OS system error. ");
	  sf_shutdown (sf_make_new_log_name (wi_inst.wi_master), NULL);
	}

      ws->ws_thread = thr->dkt_process;
      resource_store (ws_dbcs, (void*) ws);
      dk_set_push (&ws_threads, ws);
    }
}

void
ws_thr_cache_clear ()
{
#define WS_MIN_RC 1
  static void ** wst;
  ws_connection_t * ws;
  int i, n = 0;
  if (!http_threads)
    return;
  if (!wst)
    wst = (void **) malloc (http_threads * sizeof (void *));
  DO_SET (ws_connection_t *, ws, &ws_threads)
      ws->ws_thr_cache_clear = 1;
  END_DO_SET();
  if (ws_dbcs->rc_fill > WS_MIN_RC)
    {
      mutex_enter (ws_dbcs->rc_mtx);
      n = ws_dbcs->rc_fill;
      memcpy (wst, ws_dbcs->rc_items, n * sizeof (void*));
      ws_dbcs->rc_fill = WS_MIN_RC;
      mutex_leave (ws_dbcs->rc_mtx);
    }
  else
    return;
  for (i = WS_MIN_RC; i < n; i++)
    {
      ws = (ws_connection_t *) wst[i];
      thr_alloc_cache_clear (ws->ws_thread);
      ws->ws_thr_cache_clear = 0;
      resource_store (ws_dbcs, ws);
    }
}

size_t dk_alloc_cache_total (void * cache);

size_t
http_threads_mem_report ()
{
  size_t cache_fill = 0;
  DO_SET (ws_connection_t *, ws, &ws_threads)
    {
      cache_fill += dk_alloc_cache_total (ws->ws_thread->thr_alloc_cache);  
    }
  END_DO_SET();
  return cache_fill;
}

extern int cl_no_init;

int
http_init_part_two ()
{
  dk_session_t *listening;
#ifdef _SSL
  dk_session_t *ssl_listen = NULL;
#endif
#ifdef _IMSG
  dk_session_t *pop3_listen = NULL;
  dk_session_t *nntp_listen = NULL;
  dk_session_t *ftp_listen = NULL;
#endif
  if (cluster_enable && cl_no_init)
    return 1;

  if (lite_mode)
    return 1;

  ddl_std_proc (ws_def_expand_includes, 1);
  ddl_std_proc (ws_def_1, 1);
  ddl_std_proc (ws_get_ftext, 1);
  /* Do not override user defined default procedure */
  if (!sch_proc_def (wi_inst.wi_schema, ws_def_2_name))
    ddl_std_proc (ws_def_2, 1);
  ini_http_threads = http_threads;

  if (!local_interfaces)
    local_interfaces = box_tpcip_get_interfaces ();

  if (!localhost_names)
    localhost_names = box_tcpip_localhost_names ();

  if (!http_port)
    return 1;

  lt_enter(bootstrap_cli->cli_trx);

  http_init_acl_and_cache ();

#ifdef VIRTUAL_DIR
  ddl_sel_for_effect ("select count (*) from DB.DBA.HTTP_PATH where http_map_table (HP_LPATH, HP_PPATH, HP_HOST, HP_LISTEN_HOST, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT, HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS, deserialize (HP_SOAP_OPTIONS), deserialize (HP_AUTH_OPTIONS), deserialize (HP_OPTIONS), HP_IS_DEFAULT_HOST)");
#endif
  ddl_sel_for_effect ("SELECT count (*) FROM DB.DBA.SYS_SOAP_DATATYPES where "
      "__soap_dt_define(SDT_NAME, xslt ('http://local.virt/soap_sch', xtree_doc(SDT_SCH), vector ('udt_struct', case when isstring(SDT_UDT) then 1 else 0 end)), "
      "xtree_doc(SDT_SCH), SDT_TYPE, SDT_UDT)");

  ddl_sel_for_effect ("SELECT count (*) FROM DB.DBA.SYS_SOAP_UDT_PUB where "
      "__soap_udt_publish (SUP_HOST, SUP_LHOST, SUP_END_POINT, SUP_CLASS)");

  http_xslt_qr = sch_proc_def (isp_schema (NULL), "DB.DBA.__HTTP_XSLT");
  if (http_xslt_qr->qr_to_recompile)
    http_xslt_qr = qr_recompile (http_xslt_qr, NULL);

  listening = dk_session_allocate (SESCLASS_TCPIP);
  SESSION_SCH_DATA (listening)->sio_default_read_ready_action
    = (io_action_func) ws_ready;

  if (SER_SUCC != session_set_address (listening->dks_session, http_port))
    {
      log_error ("Failed setting the HTTP listen address at %s.", http_port);
      call_exit (-1);
    }

  session_listen (listening->dks_session);

  if (!SESSTAT_ISSET (listening->dks_session, SST_LISTENING))
    {
      log_error ("Failed HTTP listen at %s.", http_port);
      call_exit (-1);
    };

  log_info ("HTTP%s server online at %s", dav_root ? "/WebDAV" : "", http_port);

  /* SSL support */
#ifdef _SSL
  /*    CRYPTO_malloc_init();*/
  SSL_load_error_strings();
  SSLeay_add_ssl_algorithms();
  if (!https_key) /* when key & certificate are in same file */
    https_key = https_cert;
  if (https_port && https_cert && https_key)
    {
      char err_buf [1024];
      SSL_CTX* ssl_ctx = NULL;
      const SSL_METHOD *ssl_meth = NULL;
      ssl_meth = SSLv23_server_method();
      ssl_ctx = SSL_CTX_new ((SSL_METHOD *) ssl_meth);
      if (!ssl_ctx)
	{
	  cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  log_error ("HTTPS: Error allocating SSL context: %s", err_buf);
	  goto init_ssl_exit;
	}

      if (!ssl_server_set_certificate (ssl_ctx, https_cert, https_key, https_extra))
	goto init_ssl_exit;

      if (https_client_verify_file)
	{
	if (!SSL_CTX_load_verify_locations (ssl_ctx, https_client_verify_file, NULL))
	  {
	    cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	    log_error ("HTTPS: Invalid X509 client CA file %s : %s", https_client_verify_file, err_buf);
	      goto init_ssl_exit;
	  }
	}

      if (https_client_verify > 0)
	{
	  int verify = SSL_VERIFY_NONE, session_id_context = srv_pid;
	  uptrlong ap;

	  if (HTTPS_VERIFY_REQUIRED == https_client_verify)
	    verify |= SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE;
	  if (HTTPS_VERIFY_OPTIONAL == https_client_verify || HTTPS_VERIFY_OPTIONAL_NO_CA == https_client_verify)
	    verify |= SSL_VERIFY_PEER | SSL_VERIFY_CLIENT_ONCE;
	  SSL_CTX_set_verify (ssl_ctx, verify , (int (*)(int, X509_STORE_CTX *)) https_cert_verify_callback);
	  SSL_CTX_set_verify_depth (ssl_ctx, https_client_verify_depth);
	  ap = ((0xff & https_client_verify) << 24) | (0xffffff & https_client_verify_depth);
	  SSL_CTX_set_app_data (ssl_ctx, ap);
	  SSL_CTX_set_session_id_context(ssl_ctx, (unsigned char  *)&session_id_context, sizeof session_id_context);
	}

      if (https_client_verify_file)
	{
	  int i;
	  STACK_OF(X509_NAME) *skCAList = SSL_load_client_CA_file (https_client_verify_file);

	  SSL_CTX_set_client_CA_list (ssl_ctx, skCAList);
	  skCAList = SSL_CTX_get_client_CA_list (ssl_ctx);
	  if (sk_X509_NAME_num(skCAList) == 0)
	    log_warning ("HTTPS: Client authentication requested but no CA known for verification");

	  for (i = 0; i < sk_X509_NAME_num(skCAList); i++)
	    {
	      char ca_buf[1024];
	      X509_NAME *ca_name = (X509_NAME *) sk_X509_NAME_value (skCAList, i);
              if (X509_NAME_oneline (ca_name, ca_buf, sizeof (ca_buf)))
		log_debug ("HTTPS: Using X509 Client CA %s", ca_buf);
	    }
	}

      ssl_port = atoi (https_port);
      if (ssl_port <= 0)
	{
	  log_error ("HTTPS: SSL port is invalid");
	  goto init_ssl_exit;
	}
      ssl_listen = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_sslctx (ssl_listen->dks_session, (void *)ssl_ctx);
      SESSION_SCH_DATA (ssl_listen)->sio_default_read_ready_action = (io_action_func) ws_ready;

      if (SER_SUCC != session_set_address (ssl_listen->dks_session, https_port))
	{
	  log_error ("HTTPS: Failed setting listen address at %s", https_port);
	  goto init_ssl_exit;
	}

      session_listen (ssl_listen->dks_session);
      if (!SESSTAT_ISSET (ssl_listen->dks_session, SST_LISTENING))
	{
	  log_error ("HTTPS: Failed listen at %s", https_port);
	  goto init_ssl_exit;
	}

      log_info ("HTTPS server online at %s", https_port);

    init_ssl_exit:
      ;
    }
#endif

#ifdef _IMSG
  if (pop3_port)
    {
      char buff [20];
      snprintf (buff, sizeof (buff), "%d", pop3_port);
      pop3_listen = dk_session_allocate (SESCLASS_TCPIP);
      SESSION_SCH_DATA (pop3_listen)->sio_default_read_ready_action
	  = (io_action_func) ws_ready;

      if (SER_SUCC != session_set_address (pop3_listen->dks_session, buff))
	{
	  log_error ("Failed POP3 set address %d.", pop3_port);
	  PrpcSessionFree (pop3_listen);
	  pop3_listen = NULL;
	  pop3_port = 0;
	  /*call_exit (-1);*/
	}
      else
	{
	  session_listen (pop3_listen->dks_session);

	  if (!SESSTAT_ISSET (pop3_listen->dks_session, SST_LISTENING))
	    {
	      log_error ("Failed POP3 listen at %d.", pop3_port);
	      PrpcSessionFree (pop3_listen);
	      pop3_listen = NULL;
	      pop3_port = 0;
	      /*call_exit (-1);*/
	    }
	  else
	    log_info ("POP3 server online at %d", pop3_port);
	}
    }

  if (nntp_port)
    {
      char buff [20];
      snprintf (buff, sizeof (buff), "%d", nntp_port);
      nntp_listen = dk_session_allocate (SESCLASS_TCPIP);
      SESSION_SCH_DATA (nntp_listen)->sio_default_read_ready_action
	  = (io_action_func) ws_ready;

      if (SER_SUCC != session_set_address (nntp_listen->dks_session, buff))
	{
	  log_error ("Failed NNTP set address %d.", nntp_port);
	  PrpcSessionFree (nntp_listen);
	  nntp_listen = NULL;
	  nntp_port = 0;
	  /*call_exit (-1);*/
	}
      else
	{
	  session_listen (nntp_listen->dks_session);

	  if (!SESSTAT_ISSET (nntp_listen->dks_session, SST_LISTENING))
	    {
	      log_error ("Failed NNTP listen at %d.", nntp_port);
	      PrpcSessionFree (nntp_listen);
	      nntp_listen = NULL;
	      nntp_port = 0;
	      /*call_exit (-1);*/
	    }
	  else
	    log_info ("NNTP server online at %d", nntp_port);
	}
    }

  if (ftp_port)
    {
      char buff [20];
      snprintf (buff, sizeof (buff), "%d", ftp_port);
      ftp_listen = dk_session_allocate (SESCLASS_TCPIP);
      SESSION_SCH_DATA (ftp_listen)->sio_default_read_ready_action
	  = (io_action_func) ws_ready;

      if (SER_SUCC != session_set_address (ftp_listen->dks_session, buff))
	{
	  log_error ("Failed FTP set address %d.", ftp_port);
	  PrpcSessionFree (ftp_listen);
	  ftp_listen = NULL;
	  ftp_port = 0;
	  /*call_exit (-1);*/
	}
      else
	{
	  session_listen (ftp_listen->dks_session);

	  if (!SESSTAT_ISSET (ftp_listen->dks_session, SST_LISTENING))
	    {
	      log_error ("Failed FTP listen at %d.", ftp_port);
	      PrpcSessionFree (ftp_listen);
	      ftp_listen = NULL;
	      ftp_port = 0;
	      /*call_exit (-1);*/
	    }
	  else
	    log_info ("FTP server online at %d", ftp_port);
	}
    }
#endif

  http_threads_allocate (http_threads);
  if (!http_limited)
    http_limited = http_threads;

  PrpcCheckIn (listening);
  dks_housekeeping_session_count_change (1);
  /* SSL support */
#ifdef _SSL
  if (https_port && https_cert && https_key && ssl_listen)
    {
      PrpcCheckIn (ssl_listen);
      dks_housekeeping_session_count_change (1);
    }
#endif

#ifdef _IMSG
  if (pop3_port)
    {
      PrpcCheckIn (pop3_listen);
      dks_housekeeping_session_count_change (1);
    }
  if (nntp_port)
    {
      PrpcCheckIn (nntp_listen);
      dks_housekeeping_session_count_change (1);
    }
  if (ftp_port)
    {
      PrpcCheckIn (ftp_listen);
      dks_housekeeping_session_count_change (1);
    }
#endif

#ifdef VIRTUAL_DIR
  /* initialize additional HTTP listeners */
  http_vhosts_init ();
#endif

  if (CL_RUN_LOCAL == cl_run_local_only)
    bpel_init();

  /* last thing after server is up is to leave the bootstrap_cli trx */
  local_commit (bootstrap_cli);
  IN_TXN;
  lt_leave (bootstrap_cli->cli_trx);
  LEAVE_TXN;

  return 1;
}

static dk_session_t *
dks_cli_session (client_connection_t *cli)
{
  if (cli->cli_ws)
    return cli->cli_ws->ws_session;

  return cli->cli_session;
}

void
dks_client_ip (client_connection_t *cli, char *from, char *user, char *peer, int from_len, int user_len, int peer_len)
{
  dk_session_t *ses = NULL;

  if (!cli)
    {
      snprintf (from, from_len, "Internal");
      snprintf (user, user_len, "Internal");
      snprintf (peer, peer_len, "Internal");
      return;
    }

  ses = dks_cli_session (cli);

  if (DO_LOG(LOG_HUMAN_READ))
    snprintf (user, user_len, "%s", cli->cli_user && cli->cli_user->usr_name ? cli->cli_user->usr_name : "<DBA>");
  else
    snprintf (user, user_len, "%li", cli->cli_user && cli->cli_user->usr_id ? cli->cli_user->usr_id : 0);

  if (ses && ses->dks_peer_name && !cli->cli_is_log)
    snprintf (peer, peer_len, "%s", ses->dks_peer_name);
  else
    snprintf (peer, peer_len, "Internal");

  if (ses && ses->dks_session && !cli->cli_is_log)
    {
      tcpses_print_client_ip (ses->dks_session, from, from_len);
    }
  else
    snprintf (from, from_len, "Internal");

}


void
dks_client_port (client_connection_t *cli, char *port, int len)
{
  dk_session_t *ses = NULL;

  if (!cli)
    {
      snprintf (port, len, "Internal");
      return;
    }

  ses = dks_cli_session (cli);

  snprintf (port, len, "%d", tcpses_client_port (ses->dks_session));
}


int
is_internal_user (client_connection_t *cli)
{
  dk_session_t *ses = dks_cli_session (cli);

  if (ses && ses->dks_session)
    return 1;
  else
    return 0;
}


char * srv_http_port ()
{
   return http_port;
}


char * srv_www_root ()
{
   return www_root;
}


caddr_t srv_dns_host_name ()
{
   return dns_host_name;
}


#define HTTP_TERMINATE_CHECK_TIMEOUT 1000

int
cli_check_ws_terminate (client_connection_t *cli)
{
  if (cli->cli_ws &&
      cli->cli_ws->ws_flushed != 1 &&
      !cli->cli_ws->ws_ignore_disconnect)
    {
      if (!SESSTAT_ISSET (cli->cli_ws->ws_session->dks_session, SST_OK) ||
	  cli->cli_ws->ws_session->dks_to_close)
	return 1;
      else if (cli->cli_start_time &&
	  time_now_msec - cli->cli_start_time > HTTP_TERMINATE_CHECK_TIMEOUT &&
	  cli->cli_ws->ws_session->dks_in_fill < cli->cli_ws->ws_session->dks_in_length)
	{
	  ws_connection_t *ws = cli->cli_ws;
	  timeout_t to = { 0, 0 };

	  cli->cli_start_time = time_now_msec;

	  if (SER_SUCC == tcpses_is_read_ready (ws->ws_session->dks_session, &to))
	    {
	      if (SESSTAT_ISSET (ws->ws_session->dks_session, SST_TIMED_OUT))
		{
		  SESSTAT_CLR (ws->ws_session->dks_session, SST_TIMED_OUT);
		}
	      else
		{
		  int rc = session_read (ws->ws_session->dks_session,
		      ws->ws_session->dks_in_buffer + ws->ws_session->dks_in_fill,
		      ws->ws_session->dks_in_length - ws->ws_session->dks_in_fill);
		  if (rc == -1 || rc == 0 ||
		      SESSTAT_ISSET (ws->ws_session->dks_session, SST_BROKEN_CONNECTION))
		    return 1;
		  else
		    ws->ws_session->dks_in_fill += rc;
		}
	    }
	}
    }
  return 0;
}


void
soap_mime_tree_ctx (caddr_t ctype, caddr_t body, dk_set_t * set, caddr_t * err, int soap_version, dk_set_t hdrs)
{
  caddr_t data, id = NULL, type = NULL;
  dk_set_t tlist = NULL;
  caddr_t * my_list = NULL;
  char *start_b = NULL;
  int len;
  int rfc822 = 1;
  char buff [2000];
  char buff2 [20000];
  long offset = 0, body_start_offset, body_end_offset;
  char szBoundry[1000];
  char szType[1000];
  caddr_t **result = NULL;
  int inx = 0, inx1 = 0;
  caddr_t my_ctype = NULL;
  caddr_t *part_attrs, *part_body;
  caddr_t *attrs = NULL, *parts = NULL;
  dk_set_t ret_attrs = NULL;
  caddr_t attr_prefix = box_dv_short_string ("attr-");
  caddr_t * list_array = NULL;

  DO_SET (caddr_t *, line, &hdrs)
    {
      if (!strnicmp ("Content-Type:", (char *) unbox_ptrlong ((caddr_t)line), 13))
	my_ctype = box_copy ((caddr_t)line);
    }
  END_DO_SET();

  snprintf (buff, sizeof (buff), "%s", my_ctype);
  dk_set_push (&tlist, box_dv_short_string (buff));
  my_list = (caddr_t *) list_to_array (dk_set_nreverse (tlist));

  start_b = ws_mime_header_field (my_list, "Content-Type", "start", 0);

  snprintf (buff2, sizeof (buff2), "%s%s", buff, (char *) body);

  *szType = 0;
  *szBoundry = 0;

  body = box_dv_short_string (buff2);

  offset = get_mime_part (&rfc822, (char *) body, box_length (body) - 1, offset,
      szBoundry, szType, sizeof (szType), (caddr_t **) & result, 0);

  if (offset == -1 || offset > 0)
    goto error;

  attrs = (caddr_t *)result[0];
  parts = (caddr_t *)result[2];

  DO_BOX (caddr_t *, part, inx, parts)
    {
      caddr_t part_name = NULL;
      char temp_name[150];

      part_attrs = (caddr_t *)part[0];
      part_body = (caddr_t *)part[1];

      for (inx1 = 0; part_attrs && inx1 < (int) BOX_ELEMENTS (part_attrs); inx1 += 2)
	{
	  if (!stricmp ("name", part_attrs[inx1]))
	    part_name = part_attrs[inx1 + 1];
	}
      if (!part_name)
	{
	  snprintf (temp_name, sizeof (temp_name), "mime_part%d", inx + 1);
	  part_name = temp_name;
	}

      if (!part_name || !part_body)
	{
	  dk_free_tree (list_to_array (ret_attrs));
	  ret_attrs = NULL;
	  goto error;
	}

      part_name = box_dv_short_string (part_name);
      dk_set_push (&ret_attrs, part_name);

	  body_start_offset = (long) unbox (part_body[0]);
	  body_end_offset = (long) unbox (part_body[1]);

	  dk_set_push (&ret_attrs, box_varchar_string ((db_buf_t) (buff2 + body_start_offset),
		body_end_offset - body_start_offset,
		DV_SHORT_STRING));

      dk_set_push (&ret_attrs, box_conc (attr_prefix, part_name));
      dk_set_push (&ret_attrs, box_copy_tree ((box_t) part_attrs));
    }
  END_DO_BOX;

  list_array = (caddr_t *) list_to_array (dk_set_nreverse (ret_attrs));

  len = BOX_ELEMENTS (list_array);
  for (inx = 0; inx < len; inx += 4)
    {
      caddr_t * temp = (caddr_t *)(((caddr_t *)list_array)[inx+3]);
      int inx2;
      data = box_copy_tree (list_array[inx+1]);
      DO_BOX (caddr_t, line, inx2, temp)
	{
	  if (0 == strnicmp (line, "Content-ID", 10))
	    id = box_copy (temp[inx2+1]);
	  if (0 == strnicmp (line, "Content-Type", 12))
	    type = box_copy (temp[inx2+1]);
	}
      END_DO_BOX;
	  if (0 == strcmp ((char *)unbox_ptrlong(id), start_b))
	    dk_set_push (set, (void *) list (4, id, box_string (SOAP_URI(soap_version)), data, NULL));
	  else
	    {
	      caddr_t resid;
	      char buf[4096];
	      char * beg = id + 1;
	      id [strlen(id)-1] = 0;
	      snprintf (buf, sizeof (buf), "cid:%s", beg);
	      resid = dk_alloc_box (box_length (id) + 5, DV_SHORT_STRING);
	      memcpy (resid, id+1, box_length (id)-2);
	      dk_set_push (set, (void *) list (4, box_string (buf), type, data, NULL));
	    }
    }

error:
  return;
}

void
soap_mime_tree (ws_connection_t * ws, dk_set_t * set, caddr_t * err, int soap_version)
{
  caddr_t data, id = NULL, type = NULL;
  caddr_t * params = ws->ws_params;
  char *start_b = ws_mime_header_field (ws->ws_lines, "Content-Type", "start", 0);
  int inx, len;

  if (!params)
    return;

  len = BOX_ELEMENTS (params);
  for (inx = 0; inx < len; inx += 4)
    {
      caddr_t * temp = (caddr_t *)(((caddr_t *)params)[inx+3]);
      int inx2;
      data = box_copy_tree (params[inx+1]);
      DO_BOX (caddr_t, line, inx2, temp)
	{
	  if (0 == strnicmp (line, "Content-ID", 10))
	    id = box_copy (temp[inx2+1]);
	  if (0 == strnicmp (line, "Content-Type", 12))
	    type = box_copy (temp[inx2+1]);
	}
      END_DO_BOX;
      if (0 == strcmp ((char *)unbox_ptrlong(id), start_b))
	dk_set_push (set, (void *) list (4, id, box_string (SOAP_URI(soap_version)), data, NULL));
      else
	{
	  caddr_t resid;
	  char buf[4096];
	  char * beg = id + 1;
	  id [strlen(id)-1] = 0;
	  snprintf (buf, sizeof (buf), "cid:%s", beg);
	  resid = dk_alloc_box (box_length (id) + 5, DV_SHORT_STRING);
	  memcpy (resid, id+1, box_length (id)-2);
	  dk_set_push (set, (void *) list (4, box_string (buf), type, data, NULL));
	}
    }
}
