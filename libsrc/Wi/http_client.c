/*
 *  http_client.c
 *
 *  $Id$
 *
 *  HTTP client for Virtuoso
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
 */

/*
 * A HTTP client that does HTTP authentication compliant with RFC2617
 *
 * TODO:
 * - Handle proxies and proxy authentication
 * - Add slots for generic reply handlers (1xx, 2xx, etc) that
 *   get invoked in case no specific handler is found for a HTTP reply
 *
 */


#include <stddef.h>

#include "Dk.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"

#include "multibyte.h"
#include "srvmultibyte.h"
#include "sqlbif.h"
#include "xml.h"
#include "libutil.h"
#include "security.h"
#include "statuslog.h"
#include "wifn.h"
#ifdef BIF_XML
#include "sqlpar.h"
#include "xmltree.h"
#endif

#if defined (PCTCP)
int last_errno;
# ifdef errno
#  undef errno
# endif
# define errno (last_errno = WSAGetLastError())
# define EMSGSIZE WSAEMSGSIZE
#endif

#include "http_client.h"
#include "http.h"
#include "xmlenc.h"

#define XML_VERSION		"1.0"

/*#define _USE_CACHED_SES from http.h */

#define FREE_BOX_IF(box) \
if (box) \
  { \
    dk_free_box (box); \
    box = NULL; \
  }

#define STANDARD_HANDLER(name, errcode, errmsg) \
int name (http_cli_ctx * ctx, caddr_t parm, caddr_t ret, caddr_t err) \
{ \
  dk_free_tree (ctx->hcctx_err); \
  ctx->hcctx_err = srv_make_new_error (errcode, "HC001", errmsg);\
  ctx->hcctx_state = HC_STATE_ERR_CLEANUP;\
  return HC_RET_ERR_ABORT;\
}

#ifdef MALLOC_DEBUG
#define ht_debug fprintf (stderr, "ABORT CAUGHT in fn. %s (%d)\n", __FILE__, __LINE__);
#else
#define ht_debug
#endif

#define CATCH_ABORT(fn, c, r) \
if (HC_RET_ERR_ABORT == (r = fn (c))) \
  { \
    ht_debug \
    return (HC_RET_ERR_ABORT); \
  }

#define F_ISSET(c, f) (c->hcctx_flags & f)
#define F_SET(c, f) (c->hcctx_flags |= f)
#define F_RESET(c, f) (c->hcctx_flags &= ~f)

int http_cli_error (http_cli_ctx * ctx, caddr_t errcode, caddr_t errmsg)
{
  ctx->hcctx_err = srv_make_new_error (errcode, "HC001", "%s", errmsg);
  ctx->hcctx_state = HC_STATE_ERR_CLEANUP;
  return HC_RET_ERR_ABORT;
}

char * http_cli_proxy_server = NULL;
char * http_cli_proxy_except = NULL;
dk_set_t http_cli_proxy_except_set = NULL;

int
http_cli_target_is_proxy_exception (char * host)
{
  if (!http_cli_proxy_except_set)
    return 0;
  DO_SET (caddr_t, ex, &http_cli_proxy_except_set)
    {
      if (DVC_MATCH == cmp_like (host, ex, default_collation, '\\', LIKE_ARG_CHAR, LIKE_ARG_CHAR))
	return 1;
    }
  END_DO_SET ();
  return 0;
}

int
http_cli_hook_dispatch (http_cli_ctx * ctx, int hook)
{
  if (!ctx->hcctx_hooks[hook])
    return 0;

  DO_SET (http_cli_handler_frame_t*, fm, &ctx->hcctx_hooks[hook])
    {
      if ((ctx->hcctx_hook_ret = (fm->fn)(ctx, fm->pm, fm->rt, fm->er)) == HC_RET_ERR_ABORT)
	break;
    }
  END_DO_SET ();
  return (ctx->hcctx_hook_ret);
}

int
http_cli_resp_evt_dispatch (http_cli_ctx * ctx, int http_resp)
{
  if (!ctx || !ctx->hcctx_resp_evts) return 0;
  DO_SET (http_resp_evt_q_t *, evt_q, &ctx->hcctx_resp_evts)
    {
      if (evt_q->hreq_http_resp == http_resp)
	{
	  DO_SET (http_cli_handler_frame_t*, fm, &evt_q->hreq_evt_q)
	    {
	      if ((ctx->hcctx_resp_evt_ret = (fm->fn)(ctx, fm->pm, fm->rt, fm->er))
		  == HC_RET_ERR_ABORT)
		break;
	    }
	  END_DO_SET ();
	  break;
	}
    }
  END_DO_SET ();
  return (ctx->hcctx_resp_evt_ret);
}

/* allocate and init a http client context, should be freed after use with http_cli_ctx_free */


http_cli_ctx *
http_cli_ctx_init (void)
{
  http_cli_ctx * ctx;
  ctx = (http_cli_ctx *) dk_alloc (sizeof (http_cli_ctx));
  memset (ctx, 0, sizeof (http_cli_ctx));
  ctx->hcctx_prv_req_hdrs = strses_allocate ();
  ctx->hcctx_pub_req_hdrs = strses_allocate ();
  ctx->hcctx_req_body = strses_allocate ();
  return ctx;
}

#define RELEASE(item) \
  if (item) \
    { \
      dk_free_box (item); \
      item = 0; \
    }

#define http_cli_target(ctx) (NULL != (ctx)->hcctx_proxy.hcp_proxy ? \
    (ctx)->hcctx_proxy.hcp_proxy : (ctx)->hcctx_host)

int
http_cli_ctx_free (http_cli_ctx * ctx)
{
  int i;
  int ret;

  if (!ctx) return 0;

  if ((ret = http_cli_hook_dispatch (ctx, HC_CTX_DESTRUCTOR)) == HC_RET_ERR_ABORT)
    {
      return (HC_RET_ERR_ABORT);
    }

  if (ctx->hcctx_resp_evts)
    {
      DO_SET (http_resp_evt_q_t *, evt_q2, &ctx->hcctx_resp_evts)
	{
	  if (evt_q2->hreq_evt_q)
	    {
	      DO_SET (http_cli_handler_frame_t *, hf, &evt_q2->hreq_evt_q)
		{
		  dk_free (hf, sizeof (http_cli_handler_frame_t));
		}
	      END_DO_SET();
	      dk_set_free (evt_q2->hreq_evt_q);
	    }
	  dk_free (evt_q2, sizeof (http_resp_evt_q_t));
	}
      END_DO_SET ();
      dk_set_free (ctx->hcctx_resp_evts);
    }
  for (i = 0;i < HTTP_CLI_NO_HOOKS; i++)
    if (ctx->hcctx_hooks[i])
      {
	DO_SET (http_cli_handler_frame_t *, hf, &ctx->hcctx_hooks[i])
	  {
	    dk_free (hf, sizeof (http_cli_handler_frame_t));
	  }
	END_DO_SET();
	dk_set_free (ctx->hcctx_hooks[i]);
      }

#ifndef _USE_CACHED_SES
  if (ctx->hcctx_http_out)
    {
      PrpcDisconnect (ctx->hcctx_http_out);
      PrpcSessionFree (ctx->hcctx_http_out);
    }
#else
  if (ctx->hcctx_http_out && (!ctx->hcctx_keep_alive ||
			      ctx->hcctx_err ||
			      !SESSTAT_ISSET (ctx->hcctx_http_out->dks_session, SST_OK)
#ifdef _SSL
			      || ctx->hcctx_ssl_ctx
#endif
			      || ctx->hcctx_proxy.hcp_socks_ver > 0
			      ))
    {
      PrpcDisconnect (ctx->hcctx_http_out);
      PrpcSessionFree (ctx->hcctx_http_out);
#ifdef _SSL
      SSL_CTX_free (ctx->hcctx_ssl_ctx);
#endif
    }
  else
    {
      if (ctx->hcctx_http_out)
	http_session_used (ctx->hcctx_http_out, http_cli_target (ctx), ctx->hcctx_peer_max_timeout);
    }
#endif

  dk_free_tree (ctx->hcctx_url);
  dk_free_tree (ctx->hcctx_host);
  dk_free_tree (ctx->hcctx_proxy.hcp_proxy);
  dk_free_tree (ctx->hcctx_proxy.hcp_user);
  dk_free_tree (ctx->hcctx_proxy.hcp_pass);
  dk_free_tree (ctx->hcctx_uri);
  dk_free_tree (ctx->hcctx_response);

  if (ctx->hcctx_resp_hdrs)
    {
      DO_SET (caddr_t, l, &ctx->hcctx_resp_hdrs)
	{
	  RELEASE (l);
	}
      END_DO_SET ();
    }

  dk_set_free (ctx->hcctx_resp_hdrs);
  ctx->hcctx_resp_hdrs = NULL;
  dk_free_tree ((box_t) ctx->hcctx_prv_req_hdrs);
  dk_free_tree ((box_t) ctx->hcctx_pub_req_hdrs);
  dk_free_tree ((box_t) ctx->hcctx_req_body);
  dk_free_tree (ctx->hcctx_resp_body);
  dk_free_tree ((box_t) ctx->hcctx_ua_id);

  dk_free_box (ctx->hcctx_realm);
  dk_free_box (ctx->hcctx_domain);
  dk_free_box (ctx->hcctx_nonce);
  dk_free_box (ctx->hcctx_cnonce);
  dk_free_box (ctx->hcctx_opaque);
  dk_free_box (ctx->hcctx_stale);
  dk_free_box (ctx->hcctx_qop);

  dk_free_tree (ctx->hcctx_err);

  dk_free (ctx, sizeof (http_cli_ctx));
  return 0;
}

HC_RET
http_cli_std_auth_destructor (http_cli_ctx * ctx,
			      caddr_t parm,
			      caddr_t ret_val,
			      caddr_t err)
{
  if (!ctx)
    return (HC_RET_ERR_ABORT);

  FREE_BOX_IF (ctx->hcctx_qop);
  FREE_BOX_IF (ctx->hcctx_nonce);
  FREE_BOX_IF (ctx->hcctx_cnonce);
  return (HC_RET_OK);
}

void
http_cli_push_hook (http_cli_ctx * ctx,
		    int hook,
		    http_cli_handler_frame_t * handler)
{
  DO_SET (http_cli_handler_frame_t *, hf, &ctx->hcctx_hooks[hook])
    {
      if (hf->fn == handler->fn)
	{
	  dk_free (handler, sizeof (http_cli_handler_frame_t));
	  return;
	}
    }
  END_DO_SET ();

  dk_set_push (&ctx->hcctx_hooks[hook], handler);
}

http_cli_handler_frame_t *
http_cli_make_handler_frame (http_cli_handler_fn fn,
			     caddr_t pm,
			     caddr_t ret,
			     caddr_t err_ret)
{
  http_cli_handler_frame_t * fm;

  fm = (http_cli_handler_frame_t *) dk_alloc (sizeof (http_cli_handler_frame_t));
  fm->fn = fn;
  fm->rt = ret;
  fm->er = err_ret;

  return (fm);
}

/* push a handler frame to response event que */

void
http_cli_push_resp_evt (http_cli_ctx * ctx,
			int http_resp,
			http_cli_handler_frame_t * evt)
{
  http_resp_evt_q_t * evt_q;

  if (ctx->hcctx_resp_evts)
    {
      DO_SET (http_resp_evt_q_t *, evt_q2, &ctx->hcctx_resp_evts)
	{
	  if (evt_q2->hreq_http_resp == http_resp)
	    {
	      dk_set_push (&evt_q2->hreq_evt_q, evt);
	      return;
	    }
	}
      END_DO_SET ();
    }

  evt_q = (http_resp_evt_q_t *) dk_alloc (sizeof (http_resp_evt_q_t));
  memset (evt_q, 0, sizeof (http_resp_evt_q_t));

  evt_q->hreq_http_resp = http_resp;
  dk_set_push (&evt_q->hreq_evt_q, evt);
  dk_set_push (&ctx->hcctx_resp_evts, evt_q);
}

HC_RET
http_cli_negotiate_socks4 (dk_session_t * ses, char * in_host, char * name, char ** err_ret)
{
  unsigned char socksreq[270];
  int port, rc;
  unsigned short ip[4];
  char *pos, host[1000], ip_addr[50];
  int packetsize;

  pos = strchr (in_host, ':');
  if (pos)
    {
      memcpy (host, in_host, pos - in_host);
      port = atoi (pos + 1);
    }
  else
    {
      strcpy_ck (host, in_host);
      port = 80;
    }
  socksreq[0] = 4;
  socksreq[1] = 1; /* connect */
  *((unsigned short*)&socksreq[2]) = htons((unsigned short) port);
  srv_ip (ip_addr, sizeof (ip_addr), host);
  if (4 == sscanf(ip_addr, "%hu.%hu.%hu.%hu", &ip[0], &ip[1], &ip[2], &ip[3]))
    {
      socksreq[4] = (unsigned char)ip[0];
      socksreq[5] = (unsigned char)ip[1];
      socksreq[6] = (unsigned char)ip[2];
      socksreq[7] = (unsigned char)ip[3];
    }
  else
    {
      *err_ret = "Can not resolve target";
      return (HC_RET_ERR_ABORT);
    }

  packetsize = 9;
  socksreq[8] = 0; /* no name */
  if (name)
    {
      strncat ((char*)socksreq + 8, name, sizeof(socksreq) - 8 - 1);
      socksreq[sizeof (socksreq) - 1] = 0;
      packetsize = 9 + strlen ((char *) socksreq + 8);
    }

  CATCH_WRITE_FAIL (ses)
    {
      session_buffered_write (ses, (char *)socksreq, 9); /* no name */
      session_flush_1 (ses);
    }
  END_WRITE_FAIL (ses);

  CATCH_READ_FAIL (ses)
    {
      rc = service_read (ses, (char *)socksreq, 8, 1);
    }
  FAILED
    {
      *err_ret = "Can not read handshake response";
      return (HC_RET_ERR_ABORT);
    }
  END_READ_FAIL (ses);
  if (rc != 8 || socksreq[1] != 0x5a) /* either cannot read or access is not granted */
    {
      *err_ret = "Access is not granted";
      return (HC_RET_ERR_ABORT);
    }
  return (HC_RET_OK);
}

HC_RET
http_cli_negotiate_socks5 (dk_session_t * ses, char * in_host, char * user, char * pass, int resolve, char ** err_ret)
{
  unsigned char socksreq[600];
  int port, rc;
  unsigned short ip[4];
  char *pos, host[1000], ip_addr[50];
  int packetsize;

  pos = strchr (in_host, ':');
  if (pos)
    {
      memcpy (host, in_host, pos - in_host);
      port = atoi (pos + 1);
    }
  else
    {
      strcpy_ck (host, in_host);
      port = 80;
    }
  socksreq[0] = 5; /* version */
  socksreq[1] = (user ? 2 : 1); /* methods supported */
  socksreq[2] = 0; /* no auth */
  socksreq[3] = 2; /* uid/pwd */

  CATCH_WRITE_FAIL (ses)
    {
      session_buffered_write (ses, (char *)socksreq, (2 + (int)socksreq[1]));
      session_flush_1 (ses);
    }
  END_WRITE_FAIL(ses);

  CATCH_READ_FAIL (ses)
    {
      rc = service_read (ses, (char *) socksreq, 2, 1);
    }
  FAILED
    {
      *err_ret = "Can not read handshake response";
      return (HC_RET_ERR_ABORT);
    }
  END_READ_FAIL (ses);

  if (socksreq[0] != 5) /* invalid version */
    {
      *err_ret = "Invalid socks version";
      return (HC_RET_ERR_ABORT);
    }

  if (socksreq[1] == 2 && user && pass) /* uid/pwd handshake */
    {
      size_t uslen, pwlen;
      int len = 0;

      uslen = strlen (user);
      pwlen = strlen (pass);
      socksreq[len++] = 1;
      socksreq[len++] = (char) uslen;
      memcpy(socksreq + len, user, (int) uslen);
      len += uslen;
      socksreq[len++] = (char) pwlen;
      memcpy(socksreq + len, pass, (int) pwlen);
      len += pwlen;

      CATCH_WRITE_FAIL (ses)
	{
	  session_buffered_write (ses, (char *)socksreq, len);
	  session_flush_1 (ses);
	}
      END_WRITE_FAIL(ses);

      CATCH_READ_FAIL (ses)
	{
	  rc = service_read (ses, (char *) socksreq, 2, 1);
	}
      FAILED
	{
	  *err_ret = "Can not read handshake response";
	  return (HC_RET_ERR_ABORT);
	}
      END_READ_FAIL (ses);

      if (socksreq[1] != 0) /* invalid version */
	{
	  *err_ret = "User was rejected";
	  return (HC_RET_ERR_ABORT);
	}
    }
  else if (socksreq[1] != 0) /* authentication needs , but not supported by client */
    {
      *err_ret = "Authentication mode is not supported";
      return (HC_RET_ERR_ABORT);
    }

  /* ready to tell proxy where to connect */
  socksreq[0] = 5; /* version */
  socksreq[1] = 1; /* connect */
  socksreq[2] = 0;
  if (resolve)
    {
      int hostname_len = strlen (host);
      socksreq[3] = 3; /* dns name */
      packetsize = (size_t)(5 + hostname_len + 2);
      socksreq[4] = (char) hostname_len;
      memcpy(&socksreq[5], host, hostname_len);
      *((unsigned short*)&socksreq[hostname_len+5]) = htons((unsigned short)port);
    }
  else
    {
      packetsize = 10;
      socksreq[3] = 1; /* IPv4 follows, we lookup it locally */
      srv_ip (ip_addr, sizeof (ip_addr), host);
      if (4 == sscanf(ip_addr, "%hu.%hu.%hu.%hu", &ip[0], &ip[1], &ip[2], &ip[3]))
	{
	  socksreq[4] = (unsigned char)ip[0];
	  socksreq[5] = (unsigned char)ip[1];
	  socksreq[6] = (unsigned char)ip[2];
	  socksreq[7] = (unsigned char)ip[3];
	}
      else
	{
	  *err_ret = "Can not resolve target host name";
	  return (HC_RET_ERR_ABORT);
	}
      *((unsigned short*)&socksreq[8]) = htons((unsigned short)port);
    }

  CATCH_WRITE_FAIL (ses)
    {
      session_buffered_write (ses, (char *)socksreq, packetsize);
      session_flush_1 (ses);
    }
  END_WRITE_FAIL(ses);

  packetsize = 10;
  CATCH_READ_FAIL (ses)
    {
      rc = service_read (ses, (char *)socksreq, packetsize, 1);
      if (socksreq[0] != 5)
	{
	  *err_ret = "Invalid socks version";
	  return (HC_RET_ERR_ABORT);
	}
      if (socksreq[1] != 0) /* an error */
	{
	  *err_ret = "Socks handshake error";
	  return (HC_RET_ERR_ABORT);
	}

      if (socksreq[3] == 3) /* domain name */
	packetsize = 5 + (int)socksreq[4] + 2;
      else if (socksreq[3] == 4) /* IPv6 address */
	packetsize = 4 + 16 + 2;

      if (packetsize > 10) /* read the rest */
	{
	  packetsize -= 10;
	  rc = service_read (ses, (char *)&socksreq[10], packetsize, 1);
	}
    }
  FAILED
    {
      *err_ret = "Can not read handshake response";
      return (HC_RET_ERR_ABORT);
    }
  END_READ_FAIL (ses);
  return (HC_RET_OK);
}

HC_RET
http_cli_handle_socks_conn_post (http_cli_ctx * ctx, caddr_t parm, caddr_t ret_val, caddr_t err)
{
  char * err_ret = NULL;
  if (!ctx)
    return (HC_RET_ERR_ABORT);

  if (!ctx->hcctx_proxy.hcp_proxy || !ctx->hcctx_proxy.hcp_socks_ver || ctx->hcctx_http_out_cached)
    return (HC_RET_OK);

  if (ctx->hcctx_proxy.hcp_socks_ver == 4)
    {
      if (HC_RET_OK != http_cli_negotiate_socks4 (ctx->hcctx_http_out, ctx->hcctx_host, ctx->hcctx_proxy.hcp_user,  &err_ret))
	return http_cli_error (ctx, "HTCLI", err_ret);
    }
  else if (ctx->hcctx_proxy.hcp_socks_ver == 5)
    {
      if (HC_RET_OK != http_cli_negotiate_socks5 (ctx->hcctx_http_out, ctx->hcctx_host, ctx->hcctx_proxy.hcp_user, ctx->hcctx_proxy.hcp_pass,
	  ctx->hcctx_proxy.hcp_resolve, &err_ret))
	return http_cli_error (ctx, "HTCLI", err_ret);
    }
  else /* not supported proxy */
    {
      return http_cli_hook_dispatch (ctx, HC_HTTP_CONN_ERR);
    }
  return (HC_RET_OK);
}

#ifdef _SSL
HC_RET
http_cli_ssl_cert (http_cli_ctx * ctx, caddr_t val)
{
  if (!ctx)
    return (HC_RET_ERR_ABORT);

  ctx->hcctx_pkcs12_file = val;
  return (HC_RET_OK);
}

HC_RET
http_cli_ssl_cert_pass (http_cli_ctx * ctx, caddr_t val)
{
  if (!ctx)
    return (HC_RET_ERR_ABORT);

  ctx->hcctx_cert_pass = val;
  return (HC_RET_OK);
}

HC_RET
http_cli_ssl_ca_certs (http_cli_ctx * ctx, caddr_t val)
{
  if (!ctx)
    return (HC_RET_ERR_ABORT);

  ctx->hcctx_ca_certs = val;
  return (HC_RET_OK);
}
#endif

HC_RET
http_cli_set_auth (http_cli_ctx * ctx, caddr_t user, caddr_t pass)
{
  http_cli_handler_frame_t * revt;
  http_cli_handler_frame_t * dest;

  if (!ctx)
    return (HC_RET_ERR_ABORT);
  ctx->hcctx_user = user;
  ctx->hcctx_pass = pass;

  revt = http_cli_make_handler_frame (http_cli_std_handle_auth, NULL, NULL, NULL);
  dest = http_cli_make_handler_frame (http_cli_std_auth_destructor, NULL, NULL, NULL);
  http_cli_push_resp_evt (ctx, 401, revt);
  http_cli_push_hook (ctx, HC_CTX_DESTRUCTOR, dest);
  return (HC_RET_OK);
}

HC_RET
http_cli_set_http_10 (http_cli_ctx * ctx)
{
  if (!ctx)
    return (HC_RET_ERR_ABORT);
  ctx->hcctx_http_maj = 1;
  ctx->hcctx_http_min = 0;
  return (HC_RET_OK);
}

HC_RET
http_cli_set_http_11 (http_cli_ctx * ctx)
{
  if (!ctx)
    return (HC_RET_ERR_ABORT);
  ctx->hcctx_http_maj = 1;
  ctx->hcctx_http_min = 1;
  return (HC_RET_OK);
}

HC_RET
http_cli_set_authtype (http_cli_ctx * ctx, int authtype)
{
  if (ctx)
    ctx->hcctx_auth_type = authtype;
  return (HC_RET_OK);
}

HC_RET
http_cli_set_retries (http_cli_ctx * ctx, int retries)
{
  if (ctx)
    ctx->hcctx_retry_max = retries;
  return (HC_RET_OK);
}

HC_RET
http_cli_set_req_content_type (http_cli_ctx * ctx, caddr_t ctype)
{
  if (ctx)
    ctx->hcctx_req_ctype = ctype;
  return (HC_RET_OK);
}

HC_RET
http_cli_set_target_host (http_cli_ctx * ctx, caddr_t target)
{
  if (ctx)
    {
      RELEASE (ctx->hcctx_host);
      ctx->hcctx_host = box_string (target);
      if (http_cli_target_is_proxy_exception (ctx->hcctx_host))
	RELEASE (ctx->hcctx_proxy.hcp_proxy);
    }
  return (HC_RET_OK);
}

void
http_cli_set_proxy_auth (http_cli_proxy_t * proxy, char * target)
{
  char * pos = strrchr (target, '@');
  char buf [400];
  if (pos)
    {
      char * delim;
      strncpy (buf, target, pos - target);
      buf [pos - target] = 0;
      proxy->hcp_proxy = box_string (pos+1);
      delim = strchr (buf, ':');
      if (delim)
	{
	  *delim = 0;
	  delim ++;
	  proxy->hcp_pass = box_string (delim);
	}
      else
	proxy->hcp_pass = box_string ("");
      proxy->hcp_user = box_string (buf);
    }
  else
    proxy->hcp_proxy = box_string (target);
}

HC_RET
http_cli_set_proxy (http_cli_ctx * ctx, caddr_t target)
{
  if (ctx)
    {
      RELEASE (ctx->hcctx_proxy.hcp_proxy);
      ctx->hcctx_proxy.hcp_socks_ver = 0;
      if (0 == strnicmp (target, "socks4://", 9))
	{
	  http_cli_set_proxy_auth (&ctx->hcctx_proxy, target + 9);
	  ctx->hcctx_proxy.hcp_socks_ver = 4;
	}
      else if (0 == strnicmp (target, "socks5://", 9))
	{
	  http_cli_set_proxy_auth (&ctx->hcctx_proxy, target + 9);
	  ctx->hcctx_proxy.hcp_socks_ver = 5;
	}
      else if (0 == strnicmp (target, "socks5-host://", 14))
	{
	  http_cli_set_proxy_auth (&ctx->hcctx_proxy, target + 14);
	  ctx->hcctx_proxy.hcp_socks_ver = 5;
	  ctx->hcctx_proxy.hcp_resolve = 1;
	}
      else if (0 == strnicmp (target, "http://", 7))
	{
	  http_cli_set_proxy_auth (&ctx->hcctx_proxy, target + 7);
	}
      else if (strlen (target) > 0) /* an empty string means no proxy */
	ctx->hcctx_proxy.hcp_proxy = box_string (target);
    }
  return (HC_RET_OK);
}

HC_RET
http_cli_set_ua_id (http_cli_ctx * ctx, caddr_t ua_id)
{
  if (ctx)
    {
      if (ctx->hcctx_ua_id)
	{
	  dk_free_box (ctx->hcctx_ua_id);
	}
      ctx->hcctx_ua_id = ua_id ? box_dv_short_string (ua_id) : NULL;
    }
  return (HC_RET_OK);
}

caddr_t
http_cli_get_err (http_cli_ctx * ctx)
{
  caddr_t ret = ctx->hcctx_err;
  ctx->hcctx_err = NULL;
  return ret;
}


/* XXX: TODO: proxies, proxy auth, http redirect */
#ifdef _SSL
int ssl_client_use_pkcs12 (SSL *ssl, char *pkcs12file, char *passwd, char * ca);
int ssl_client_use_db_key (SSL * ssl, char *key, caddr_t * err_ret)
{
  char err_buf [1024];
  if (strstr (key, "db:") == key)
    {
      xenc_key_t * k;
      client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      user_t * saved_user;
      if (!cli)
	{
	  *err_ret = srv_make_new_error ("22023", "HTS03", "The certificate & key stored in database cannot be accessed.");
	  return -1;
	}
      saved_user = cli->cli_user;
      if (!cli->cli_user)
	cli->cli_user = sec_name_to_user ("dba");
      k = xenc_get_key_by_name (key + 3, 1);
      cli->cli_user = saved_user;
      if (!k || !k->xek_x509 || !k->xek_evp_private_key)
	{
	  *err_ret = srv_make_new_error ("22023", "HTS03", "Invalid stored key %s", key);
	  return -1;
	}
      if (SSL_use_certificate (ssl, k->xek_x509) <= 0)
	{
	  cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  *err_ret = srv_make_new_error ("22023", "HTS03", "Invalid X509 certificate %s : %s", key, err_buf);
	  return -1;
	}
      if (SSL_use_PrivateKey (ssl, k->xek_evp_private_key) <= 0)
	{
	  cli_ssl_get_error_string (err_buf, sizeof (err_buf));
	  *err_ret = srv_make_new_error ("22023", "HTS03", "Invalid X509 private key file %s : %s", key, err_buf);
	  return -1;
	}
      return 1;
    }
  return 0;
}
#endif

HC_RET
http_cli_connect (http_cli_ctx * ctx)
{
  http_cli_hook_dispatch (ctx, HC_HTTP_CONN_PRE);
  if (ctx->hcctx_http_out) /* if client do a retry the previous connection must be shut down */
    {
      PrpcDisconnect (ctx->hcctx_http_out);
      PrpcSessionFree (ctx->hcctx_http_out);
    }
  ctx->hcctx_http_out = NULL; /* at this point we have no connection, if there was previous retry it's shut'd */
#ifdef _USE_CACHED_SES
  if (!ctx->hcctx_no_cached) /* first we try to get from cache */
    ctx->hcctx_http_out = http_cached_session (http_cli_target (ctx));

  if (ctx->hcctx_http_out) /* if connection is from cache, flag it */
    ctx->hcctx_http_out_cached = 1;
  else
#endif
    ctx->hcctx_http_out = http_dks_connect (http_cli_target (ctx), &ctx->hcctx_err); /* in every other case we do new connect */
  if (ctx->hcctx_http_out == NULL)
    http_cli_hook_dispatch (ctx, HC_HTTP_CONN_ERR);
  else
    {
      ctx->hcctx_http_out->dks_read_block_timeout.to_sec = ctx->hcctx_timeout;
#ifdef _SSL
      if (ctx->hcctx_pkcs12_file)
	{
	  int ssl_err = 0;
	  int dst = tcpses_get_fd (ctx->hcctx_http_out->dks_session);
	  char * pkcs12_file = ctx->hcctx_pkcs12_file;
	  char * pass = ctx->hcctx_cert_pass;
	  timeout_t to = {100, 0};

	  ctx->hcctx_ssl_method = SSLv23_client_method();
	  ctx->hcctx_ssl_ctx = SSL_CTX_new (ctx->hcctx_ssl_method);
	  ctx->hcctx_ssl = SSL_new (ctx->hcctx_ssl_ctx);
	  if (ctx->hcctx_timeout > 0)
	    to.to_sec = ctx->hcctx_timeout;

#ifndef OPENSSL_NO_TLSEXT
	  {
	    char sni_host[1024];
	    char *p;

	    /* Remove :PORT from host */
	    strncpy (sni_host, ctx->hcctx_host, sizeof (sni_host));
	    sni_host[1023] = '\0';
	    if ((p = strrchr (sni_host, ':')) != NULL)
	      *p = '\0';

	    /* Set hostname in TLSext SNI */
	    if ((ssl_err = SSL_set_tlsext_host_name (ctx->hcctx_ssl, sni_host)) != 1)
	      {
		ctx->hcctx_err = srv_make_new_error ("22023", "HTS04", "Unable to set TLSext Server Name Indication");
		goto error_in_ssl;
	      }
	  }
#endif

	  session_set_control (ctx->hcctx_http_out->dks_session, SC_TIMEOUT, (char *)(&to), sizeof (timeout_t));
	  SSL_set_fd (ctx->hcctx_ssl, dst);

	  if (pkcs12_file && 0 == atoi(pkcs12_file))
	    {
	      int session_id_context = 12;
	      if (0 != ssl_client_use_db_key (ctx->hcctx_ssl, pkcs12_file, &(ctx->hcctx_err)))
		{
		  if (ctx->hcctx_err != NULL)
		    goto error_in_ssl;
		}
	      else if (!ssl_client_use_pkcs12 (ctx->hcctx_ssl, pkcs12_file, pass, ctx->hcctx_ca_certs))
		{
		  ctx->hcctx_err = srv_make_new_error ("22023", "HTS02", "Invalid certificate file");
		  goto error_in_ssl;
		}

	      if (ctx->hcctx_ssl_insecure)
		SSL_set_verify (ctx->hcctx_ssl, SSL_VERIFY_NONE, NULL);
	      else
		SSL_set_verify (ctx->hcctx_ssl, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, NULL);
	      SSL_set_verify_depth (ctx->hcctx_ssl, -1);
	      SSL_CTX_set_session_id_context(ctx->hcctx_ssl_ctx,
		  (const unsigned char *)&session_id_context, sizeof session_id_context);
	    }
	  ssl_err = SSL_connect (ctx->hcctx_ssl);
	  if (ssl_err != 1)
	    {
	      char err1[2048];
	      err1[0] = 0;
	      if (ERR_peek_error ())
		{
		  cli_ssl_get_error_string (err1, sizeof (err1));
		}
	      else
		strcpy_ck (err1, "Cannot connect via HTTPS");
	      ctx->hcctx_err = srv_make_new_error ("08001", "HTS01", "%s", err1);
	    }
	  else
	    tcpses_to_sslses (ctx->hcctx_http_out->dks_session, ctx->hcctx_ssl);
error_in_ssl:
	  if (ctx->hcctx_err)
	    {
	      SESSTAT_CLR (ctx->hcctx_http_out->dks_session, SST_OK);
	      SESSTAT_SET (ctx->hcctx_http_out->dks_session, SST_BROKEN_CONNECTION);
	      return (HC_RET_ERR_ABORT);
	    }
	}
#endif
      http_cli_hook_dispatch (ctx, HC_HTTP_CONN_POST);
    }
  return (ctx->hcctx_hook_ret);
}

HC_RET
http_cli_set_method (http_cli_ctx * ctx, int method)
{
  if (ctx && method > 0)
    ctx->hcctx_method = method;
  return (HC_RET_OK);
}

char*
http_cli_get_method_string (http_cli_ctx * ctx)
{
  return (http_get_method_string (ctx->hcctx_method));
}

char*
http_cli_get_doc_str (http_cli_ctx * ctx)
{
  char* s = NULL;

  if (NULL != ctx->hcctx_proxy.hcp_proxy && 0 == ctx->hcctx_proxy.hcp_socks_ver)
    return ctx->hcctx_url;

  if (!strnicmp (ctx->hcctx_url, "http://", 7))
    s = ctx->hcctx_url + 7;
  else if (!strnicmp (ctx->hcctx_url, "https://", 8))
    s = ctx->hcctx_url + 8;

  if (s)
    {
      s = strchr (s, '/');
      if (!s)
	{
	  return ("/");
	}
      else
	{
	  return (s);
	}
    }
  return (ctx->hcctx_url);
}

HC_RET
http_cli_add_req_hdr (http_cli_ctx * ctx, char* hdrin)
{
  caddr_t hdr = box_dv_short_string (hdrin);
  int len = box_length (hdr) - 1;
  char * tail = hdr + len - 1;
  while (*tail == 0x0A || *tail == 0x0D)
    *(tail--) = 0;
  if (strlen (hdr) > 0)
    {
      SES_PRINT (ctx->hcctx_pub_req_hdrs, hdr);
      SES_PRINT (ctx->hcctx_pub_req_hdrs, "\r\n");
    }
  dk_free_box (hdr);
  return (HC_RET_OK);
}

void
http_cli_print_patched_url (dk_session_t * ses, caddr_t url)
{
  int i;
  for (i = 0; i < strlen (url); i++)
    {
      if (url[i] == ' ')
	SES_PRINT (ses, "%20");
      else if (url[i] == '#')
	break;
      else
	session_buffered_write_char (url[i], ses);
    }
}

HC_RET
http_cli_send_req (http_cli_ctx * ctx)
{
  char req_tmp[256];

  http_cli_hook_dispatch (ctx, HC_HTTP_REQ_PRE);

  CATCH_WRITE_FAIL (ctx->hcctx_http_out)
    {
      SES_PRINT (ctx->hcctx_http_out, http_cli_get_method_string (ctx));
      SES_PRINT (ctx->hcctx_http_out, " ");
      http_cli_print_patched_url (ctx->hcctx_http_out, http_cli_get_doc_str (ctx));
      snprintf (req_tmp, sizeof (req_tmp),
	       " HTTP/%d.%d\r\n", ctx->hcctx_http_maj, ctx->hcctx_http_min);
      SES_PRINT (ctx->hcctx_http_out, req_tmp);
      http_cli_std_hdrs (ctx);
      strses_write_out (ctx->hcctx_pub_req_hdrs, ctx->hcctx_http_out);
      strses_write_out (ctx->hcctx_prv_req_hdrs, ctx->hcctx_http_out);
      snprintf (req_tmp, sizeof (req_tmp),
	       "Content-Length: " BOXINT_FMT "\r\n\r\n", strses_length (ctx->hcctx_req_body));
      SES_PRINT (ctx->hcctx_http_out, req_tmp);
      strses_write_out (ctx->hcctx_req_body, ctx->hcctx_http_out);
      session_flush_1 (ctx->hcctx_http_out);
    }
  FAILED
    {
      if (ctx->hcctx_http_out_cached)
	{
	  ctx->hcctx_http_out_cached = 0;
	  F_SET (ctx, (HC_F_RETRY|HC_F_REPLY_READ|HC_F_HDRS_READ));
	}
      else
	return (http_cli_hook_dispatch (ctx, HC_HTTP_WRITE_ERR));
    }
  END_WRITE_FAIL (ctx->hcctx_http_out);
  http_cli_hook_dispatch (ctx, HC_HTTP_REQ_POST);
  return (ctx->hcctx_hook_ret);
}

HC_RET
http_cli_read_resp (http_cli_ctx *ctx)
{
  if (F_ISSET (ctx, HC_F_REPLY_READ)) return (HC_RET_OK);

  CATCH_READ_FAIL (ctx->hcctx_http_out)
    {
      int num_chars = 0;
      char resp_tmp[4096];

      num_chars = dks_read_line (ctx->hcctx_http_out, resp_tmp, sizeof (resp_tmp));
      if (num_chars < 12 || strncmp (resp_tmp, "HTTP", 4))
	{
	  return (http_cli_hook_dispatch (ctx, HC_HTTP_RESP_MALF));
	}
      resp_tmp[num_chars] = 0;
      ctx->hcctx_response = box_string (resp_tmp);
      resp_tmp[12] = 0;
      ctx->hcctx_respcode = atoi (resp_tmp + 9);
      if (resp_tmp[7] == '0') /* HTTP/1.X */
	{
	  ctx->hcctx_close = 1;
	  ctx->hcctx_keep_alive = 0;
	}
      if (HC_RET_ERR_ABORT == http_cli_resp_evt_dispatch (ctx, ctx->hcctx_respcode))
	{
	  return (HC_RET_ERR_ABORT);
	}
    }
  FAILED
    {
      if (ctx->hcctx_http_out_cached)
	{
	  ctx->hcctx_http_out_cached = 0;
	  F_SET (ctx, (HC_F_RETRY|HC_F_HDRS_READ));
	}
      else
	return (http_cli_hook_dispatch (ctx, HC_HTTP_READ_ERR));
    }
  END_READ_FAIL (ctx->hcctx_http_out);

  F_SET (ctx, HC_F_REPLY_READ);
  return (ctx->hcctx_hook_ret);
}


/* XXX: Actually there could be any number of whitespace between hdr name and value.
        a proper parser would be a nice-to-have */

HC_RET
http_cli_parse_resp_hdr (http_cli_ctx * ctx, char* hdr, int num_chars)
{
  if (!strnicmp ("Transfer-Encoding:", hdr, 18)
      && nc_strstr ((unsigned char *) hdr, (unsigned char *) "chunked"))
    {
      ctx->hcctx_is_chunked = 1;
      return (HC_RET_OK);
    }
  if (!strnicmp ("Connection:", hdr, 11) && nc_strstr ((unsigned char *) hdr, (unsigned char *) "close"))
    {
      ctx->hcctx_keep_alive = 0;
      ctx->hcctx_close = 1;
      return (HC_RET_OK);
    }
  if (NULL != ctx->hcctx_proxy.hcp_proxy && !strnicmp ("Proxy-Connection:", hdr, 17)
      && nc_strstr ((unsigned char *) hdr, (unsigned char *) "close"))
    {
      ctx->hcctx_keep_alive = 0;
      ctx->hcctx_close = 1;
      return (HC_RET_OK);
    }
  if (!strnicmp ("Connection:", hdr, 11) && nc_strstr ((unsigned char *) hdr, (unsigned char *) "keep-alive"))
    {
      ctx->hcctx_keep_alive = 1;
      ctx->hcctx_close = 0;
      return (HC_RET_OK);
    }
  if (!strnicmp ("Content-Length:", hdr, 15))
    {
      ctx->hcctx_resp_content_length = atol (hdr + 15);
      ctx->hcctx_resp_content_len_recd = 1;

      if (ctx->hcctx_resp_content_length < 0)
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC002", "Invalid content length in reply");
	  return (HC_RET_ERR_ABORT);
	}
      if (ctx->hcctx_resp_content_length > 10000000L)
	{
#if 1
	  ctx->hcctx_resp_content_is_strses = (char) 1;
#else
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC003", "Reply content too large");
	  return (HC_RET_ERR_ABORT);
#endif
	}
    }
  if (!strnicmp ("Content-Encoding:", hdr, 17) && nc_strstr ((unsigned char *) hdr, (unsigned char *) "gzip"))
    {
      ctx->hcctx_is_gzip = 1;
      return (HC_RET_OK);
    }
  return (HC_RET_OK);
}


HC_RET
http_cli_read_resp_hdrs (http_cli_ctx * ctx)
{
  char read_buf[DKSES_IN_BUFFER_LENGTH];
  char resp_hdr_tmp[DKSES_IN_BUFFER_LENGTH];
  int resp_hdr_tmp_fill;
  int num_chars;

  if (F_ISSET (ctx, HC_F_HDRS_READ)) return (HC_RET_OK);

  *resp_hdr_tmp = 0;
  resp_hdr_tmp_fill = 0;

  CATCH_READ_FAIL (ctx->hcctx_http_out)
    {
      do
	{
	  num_chars = dks_read_line (ctx->hcctx_http_out,
				     read_buf,
				     sizeof (read_buf));

	  if (resp_hdr_tmp_fill != 0 &&
	      (*read_buf != ' ' && *read_buf != '\t')) /* read buffer not empty and not continuation */
	    {

	      if (http_cli_parse_resp_hdr (ctx, resp_hdr_tmp, num_chars) == HC_RET_ERR_ABORT)
		{
		  ctx->hcctx_state = HC_STATE_ERR_CLEANUP;
		  return (HC_RET_ERR_ABORT);
		}
	      dk_set_push (&ctx->hcctx_resp_hdrs, box_dv_short_string (resp_hdr_tmp));
	      *resp_hdr_tmp = 0;
	      resp_hdr_tmp_fill = 0;
	    }

	  if (resp_hdr_tmp_fill + num_chars >= sizeof (resp_hdr_tmp))
	    {
	      ctx->hcctx_err = srv_make_new_error ("42000", "HC004", "Reply header too large");
	      return (HC_RET_ERR_ABORT);
	    }
	  strncat_size_ck (resp_hdr_tmp+resp_hdr_tmp_fill, read_buf, num_chars,
	      (int)(sizeof (resp_hdr_tmp) - resp_hdr_tmp_fill)); /* concat buffer and go on */
	  resp_hdr_tmp_fill += num_chars;
	}
      while (num_chars > 2);
    }
  FAILED
    {
      http_cli_hook_dispatch (ctx, HC_HTTP_READ_ERR);
    }
  END_READ_FAIL (ctx->hcctx_http_out);

  F_SET (ctx, HC_F_HDRS_READ);
  return (ctx->hcctx_hook_ret);
}

caddr_t
http_cli_get_resp_hdr (http_cli_ctx * ctx, caddr_t hdr_match)
{
  int len = (int) strlen (hdr_match);
  char* idx = NULL;

  DO_SET (caddr_t, hdr, &ctx->hcctx_resp_hdrs)
    {
      if (!strnicmp (hdr_match, hdr, len))
	{
	  idx = strchr (hdr, ':');
	  return (skip_lwsp (idx, hdr + strlen (hdr)));
	}
    }
  END_DO_SET ();

  return (NULL);
}

static caddr_t *
http_cli_get_resp_headers (http_cli_ctx * ctx)
{
  dk_set_t hdrs = NULL;
  caddr_t * head;
  dk_set_push (&hdrs, box_dv_short_string (ctx->hcctx_response));
  DO_SET (caddr_t, line, &(ctx->hcctx_resp_hdrs))
    {
      dk_set_push (&hdrs, box_dv_short_string (line));
    }
  END_DO_SET();
  head = (caddr_t *)list_to_array (dk_set_nreverse (hdrs));
  return (head);
}

HC_RET
http_cli_read_resp_body (http_cli_ctx * ctx)
{
  int ret;
  dk_session_t * volatile content = NULL;
  int volatile signal_error = 1;

  if (F_ISSET (ctx, HC_F_BODY_READ)) return (HC_RET_OK);
  ctx->hcctx_state = HC_STATE_READ_RESP_BODY;

  if (!ctx->hcctx_resp_content_length && !ctx->hcctx_is_chunked && (!ctx->hcctx_close || ctx->hcctx_resp_content_len_recd))
    return (HC_RET_OK);

  if (ctx->hcctx_method == HC_METHOD_HEAD || ctx->hcctx_respcode == 304)
    return (HC_RET_OK);

  CATCH_READ_FAIL (ctx->hcctx_http_out)
    {
      if (ctx->hcctx_is_chunked)
	{
	  dk_free_tree (ctx->hcctx_resp_body);
	  ctx->hcctx_resp_body =
	    http_read_chunked_content (ctx->hcctx_http_out, &ctx->hcctx_err, ctx->hcctx_url, 1 /* allow string session to be returned */);
	  if (!ctx->hcctx_resp_body)
	    {
	      ret = http_cli_hook_dispatch (ctx, HC_HTTP_READ_ERR);
	      if (ret == HC_RET_ERR_ABORT)
		return (ret);
	    }
	  if (DV_STRING_SESSION == DV_TYPE_OF (ctx->hcctx_resp_body))
	    ctx->hcctx_resp_content_is_strses = (char) 1;
	}
      else if (!ctx->hcctx_resp_content_length && ctx->hcctx_close)
	{
	  /* read until connection is closed */
	  unsigned char c;
	  signal_error = 0;
	  content = strses_allocate ();
	  strses_enable_paging (content, http_ses_size);

	  for (;;)
	    {
	      c = session_buffered_read_char (ctx->hcctx_http_out);
	      session_buffered_write_char (c, content);
	    }
	}
      else
	{
	  dk_free_tree (ctx->hcctx_resp_body);

	  if (ctx->hcctx_resp_content_is_strses)
	    {
	      char tmp [4096];
	      long to_read = ctx->hcctx_resp_content_length, to_read_len = sizeof (tmp), readed = 0;
	      content = strses_allocate ();

	      strses_enable_paging (content, http_ses_size);
	      do
		{
		  if (to_read < to_read_len)
		    to_read_len = to_read;
		  readed = session_buffered_read (ctx->hcctx_http_out, tmp, to_read_len);
		  session_buffered_write (content, tmp, readed);
		  tcpses_check_disk_error (content, ctx->hcctx_qst, 1);
		  to_read -= readed;
		}
	      while (to_read > 0);
	    }
	  else
	    {
	      ctx->hcctx_resp_body =
		  dk_alloc_box (ctx->hcctx_resp_content_length + 1,
		      DV_SHORT_STRING);

	      ctx->hcctx_resp_body[ctx->hcctx_resp_content_length] = '\0';
	      session_buffered_read (ctx->hcctx_http_out,
		  ctx->hcctx_resp_body,
		  ctx->hcctx_resp_content_length);
	    }
	}
    }
  FAILED
    {
      if (signal_error)
	{
	  dk_free_tree (content);
	  content = NULL;
	  http_cli_hook_dispatch (ctx, HC_HTTP_READ_ERR);
	}
    }
  END_READ_FAIL (ctx->hcctx_http_out);
  if (content)
    {
      dk_free_tree (ctx->hcctx_resp_body);
      if (strses_length (content) > 10000000L)
	ctx->hcctx_resp_content_is_strses = (char) 1;
      if (ctx->hcctx_resp_content_is_strses)
	ctx->hcctx_resp_body = (caddr_t) content;
      else
	{
	  ctx->hcctx_resp_body = strses_string (content);
	  dk_free_box ((box_t) content);
	}
    }
  F_SET (ctx, HC_F_BODY_READ);
  return (ctx->hcctx_hook_ret);
}

/* Standard error handlers */

STANDARD_HANDLER (http_cli_handle_malfm_resp,
		  "HTCLI", "Malformed HTTP response")
STANDARD_HANDLER (http_cli_handle_write_err,
		  "HTCLI", "Write Error in HTTP Client")
STANDARD_HANDLER (http_cli_handle_read_err,
		  "HTCLI", "Read Error in HTTP Client")
STANDARD_HANDLER (http_cli_handle_timeout,
		  "HTCLI", "Timeout in HTTP Client")
STANDARD_HANDLER (http_cli_handle_conn_err,
		  "HTCLI", "Connection Error in HTTP Client")


static const char __tohex[] = "0123456789abcdef";

void
http_cli_calc_md5 (caddr_t str,
		   caddr_t digest_buf,
		   int len)
{
  MD5_CTX ctx;
  unsigned char digest[16];
  int inx;

  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  MD5Update (&ctx, str, len);
  MD5Final (digest, &ctx);

  for (inx = 0; inx < sizeof (digest); inx++)
    {
      unsigned c = (unsigned)digest[inx];
      digest_buf[inx * 2] = __tohex[0xf & (c >> 4)];
      digest_buf[inx * 2 + 1 ] = __tohex[c & 0xf];
    }
  digest_buf[sizeof (digest) * 2] = '\0';
}


caddr_t
http_cli_auth_new_cnonce (void)
{
  char tmp_buf[128];
  char enc_buf[64];
  long t;
  long x;

  memset (enc_buf, 0, sizeof (enc_buf));
  t = get_msec_real_time ();
  x = rand () * rand ();

  snprintf (tmp_buf, sizeof (tmp_buf), "%08ldMopolla kuuhun!%08ld", t, x);
  tmp_buf[32] = 0;
  encode_base64 (tmp_buf, enc_buf, (uint32) strlen (tmp_buf));
  return (box_string (enc_buf));
}

char*
http_cli_algorithm_string (int alg)
{
  switch (alg)
    {
    case HA_ALGORITHM_MD5:
      return ("MD5");
    case HA_ALGORITHM_MD5_SESS:
      return ("MD5-SESS");
    default:
      return ("Undefined digest algorithm");
    }
}

HC_RET
http_cli_calc_auth_digest (http_cli_ctx * ctx, caddr_t _p, caddr_t _r, caddr_t _e)
{
  char tmp_buf[2048];
  char digest_buf[33];
  char A1[33];
  char A2[33];

  int len;

  memset (tmp_buf, 0, sizeof (tmp_buf));
  memset (A1, 0, sizeof (A1));
  memset (A2, 0, sizeof (A2));

  ctx->hcctx_nc = 1;

  if (ctx->hcctx_qop)
    {
      if (!ctx->hcctx_cnonce)
	ctx->hcctx_cnonce = http_cli_auth_new_cnonce ();
    }

  if (ctx->hcctx_algorithm == HA_ALGORITHM_MD5_SESS)
    {
      len =
	box_length (ctx->hcctx_user) +
	box_length (ctx->hcctx_realm) +
	box_length (ctx->hcctx_pass) + 3;

      if (len >= sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC004", "Buffer overflow generating digest");
	  return (HC_RET_ERR_ABORT);
	}

      snprintf (tmp_buf, sizeof (tmp_buf),
	       "%s:%s:%s",
	       ctx->hcctx_user, ctx->hcctx_realm, ctx->hcctx_pass);

      http_cli_calc_md5 (tmp_buf, digest_buf, len);

      len = sizeof (digest_buf) +
	box_length (ctx->hcctx_nonce) +
	box_length (ctx->hcctx_cnonce);

      if (len > sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC005", "Buffer overflow generating digest (A1)");
	  return (HC_RET_ERR_ABORT);
	}
      snprintf (tmp_buf, sizeof (tmp_buf), "%s:%s:%s", digest_buf, ctx->hcctx_nonce, ctx->hcctx_cnonce);
    }
  else
    {
      len =
	box_length (ctx->hcctx_user) +
	box_length (ctx->hcctx_realm) +
	box_length (ctx->hcctx_pass) + 3;

      if (len > sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC006", "Buffer overflow generating digest (A1)");
	  return (HC_RET_ERR_ABORT);
	}
      snprintf (tmp_buf, sizeof (tmp_buf), "%s:%s:%s", ctx->hcctx_user, ctx->hcctx_realm, ctx->hcctx_pass);
    }

  http_cli_calc_md5 (tmp_buf, A1, (int) strlen (tmp_buf));

  if (!ctx->hcctx_qop || (ctx->hcctx_qop && stricmp (ctx->hcctx_qop, "auth-int")))
    {
      if ((strlen (http_cli_get_method_string (ctx)) + box_length (ctx->hcctx_uri) + 2)
	  > sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC007", "Buffer overflow generating digest (A2)");
	  return (HC_RET_ERR_ABORT);
	}
      snprintf (tmp_buf, sizeof (tmp_buf),
	       "%s:%s",
	       http_cli_get_method_string (ctx),
	       ctx->hcctx_uri);
    }
  else
    {
      if ((strlen (http_cli_get_method_string (ctx)) +
	   box_length (ctx->hcctx_uri) +
	   sizeof (digest_buf) + 3) > sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC008",
					   "Buffer overflow generating digest (A2)");
	  return (HC_RET_ERR_ABORT);
	}
      http_cli_calc_md5 ((char*)ctx->hcctx_req_body,
			 digest_buf,
			 box_length (ctx->hcctx_req_body));
      snprintf (tmp_buf, sizeof (tmp_buf),
	       "%s:%s:%s",
	       http_cli_get_method_string (ctx),
	       ctx->hcctx_uri,
	       digest_buf);
    }

  http_cli_calc_md5 (tmp_buf, A2, (int) strlen (tmp_buf));
  if (!ctx->hcctx_qop)
    {
      if ((sizeof (A1) + box_length (ctx->hcctx_nonce) + sizeof (A2) + 3)
	  > sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC009",
	      "Buffer overflow generating digest");
	  return (HC_RET_ERR_ABORT);
	}

      snprintf (tmp_buf, sizeof (tmp_buf), "%s:%s:%s", A1, ctx->hcctx_nonce, A2);
    }
  else
    {

      if ((box_length (ctx->hcctx_nonce) +
	   box_length (ctx->hcctx_cnonce) +
	   box_length (ctx->hcctx_qop) +
	   64 + 8 + 6) > sizeof (tmp_buf))
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC010",
	      "Buffer overflow generating digest");
	  return (HC_RET_ERR_ABORT);
	}
      snprintf (tmp_buf, sizeof (tmp_buf),
	       "%s:%s:%08x:%s:%s:%s",
	       A1, ctx->hcctx_nonce, ctx->hcctx_nc, ctx->hcctx_cnonce, ctx->hcctx_qop, A2);
    }

  http_cli_calc_md5 (tmp_buf, digest_buf, (int) strlen (tmp_buf));

  SES_PRINT (ctx->hcctx_prv_req_hdrs, "Authorization: Digest username=\"");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_user);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\", ");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "realm=\"");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_realm);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\", ");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "nonce=\"");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_nonce);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");

  SES_PRINT (ctx->hcctx_prv_req_hdrs, ", uri=\"");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_uri);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");

  SES_PRINT (ctx->hcctx_prv_req_hdrs, ", response=\"");
  SES_PRINT (ctx->hcctx_prv_req_hdrs, digest_buf);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");

  if (ctx->hcctx_qop)
    {
      SES_PRINT (ctx->hcctx_prv_req_hdrs, ", qop=\"");
      SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_qop);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");

      SES_PRINT (ctx->hcctx_prv_req_hdrs, ", cnonce=\"");
      SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_cnonce);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");

      SES_PRINT (ctx->hcctx_prv_req_hdrs, ", nc=\"00000001\"");
    }

  if (ctx->hcctx_opaque)
    {
      SES_PRINT (ctx->hcctx_prv_req_hdrs, ", opaque=\"");
      SES_PRINT (ctx->hcctx_prv_req_hdrs, ctx->hcctx_opaque);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");
    }

  if (ctx->hcctx_algorithm)
    {
      SES_PRINT (ctx->hcctx_prv_req_hdrs, ", algorithm=\"");
      SES_PRINT (ctx->hcctx_prv_req_hdrs,
		 http_cli_algorithm_string (ctx->hcctx_algorithm));
      SES_PRINT (ctx->hcctx_prv_req_hdrs, "\"");
    }
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\r\n");

  return (HC_RET_OK);
}

HC_RET
http_cli_calc_auth_basic (http_cli_ctx * ctx, caddr_t _p, caddr_t _r, caddr_t _e)
{
  char tmp_buf[1024];
  char enc_buf[2048];
  uint32 len;

  memset (enc_buf, 0, sizeof (enc_buf));
  len = strlen (ctx->hcctx_user) + strlen (ctx->hcctx_pass) + 1;

  if ((len+1) > sizeof (tmp_buf))
    {
      ctx->hcctx_err = srv_make_new_error ("42000", "HC011",
				       "Userid and Password combination too long");
      return (HC_RET_ERR_ABORT);
    }
  snprintf (tmp_buf, sizeof (tmp_buf), "%s:%s", ctx->hcctx_user, ctx->hcctx_pass);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "Authorization: Basic ");
  encode_base64 (tmp_buf, enc_buf, len);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, enc_buf);
  SES_PRINT (ctx->hcctx_prv_req_hdrs, "\r\n");
  return (HC_RET_OK);
}

caddr_t
http_cli_get_uri_from_url (char* url)
{
  char* st = 0;
  char* slash = 0;

  st = url;

  if (!strnicmp (url, "http://", 7))
    st = url + 7;
#ifdef _SSL
  else if (!strnicmp (url, "https://", 8))
    st = url + 8;
#endif

  slash = st;

  while (*slash != '/' && *slash != 0)
    slash++;
  /* if no path at all, then we use / as it always must be a path in request */
  return box_string ((*slash != 0 ? slash : "/"));
}

caddr_t
http_cli_get_host_from_url (char* url)
{
  char* st = 0;
  char* slash = 0;
  char host[1024];
  int is_https = 0;
  size_t host_len;

  st = url;

  if (!strnicmp (url, "http://", 7))
    st = url + 7;
#ifdef _SSL
  else if (!strnicmp (url, "https://", 8))
    {
      st = url + 8;
      is_https = 1;
    }
#endif

  slash = st;

  while (*slash != '/' && *slash != 0)
    slash++;

  host_len = MIN ((slash - st), (sizeof (host) - 1));
  memcpy (host, st, host_len);
  host[host_len] = 0;

  if (!strchr (host, ':') && is_https)
    {
      strcat_ck (host, ":443");
    }

  return (box_string (host));
}

char*
next_delim (char* str, char* last)
{
  char* s = str;

  while (s < last &&
         *s != ' ' &&
	 *s != '\t' &&
	 *s != '=' &&
	 *s != '"' &&
	 *s != ';')
    s++;
  return s;
}

char*
skip_lwsp (char* str, char* last)
{
  char* s = str;

  while (s < last && (*s == ' ' || *s == '\t'))
    s++;
  return s;
}

char*
skip_attr (char* str, char* last)
{
  char* s = str;

  while (s < last &&
	 *s != ' ' &&
	 *s != '\t')
    s++;

  return s;
}

char*
strnchr (char* str, char c, size_t len)
{
  char* s = str;
  size_t n = 0;

  while (1)
    {
      if (*s != c)
	{
	  if (n > len) return NULL;
	  s++;
	}
      else
	{
	  return s;
	}
    }
}

#define BOX_VAL(p, s, e, b) \
if (e - s < sizeof (b)) \
  { \
    strncpy (b, s, e - s); \
    *(b + (e - s)) = 0; \
    if (p) dk_free_box (p); \
    p = box_string (b); \
  } \
else \
  { \
    srv_make_new_error ("42000", "HC012", "Authentication challenge attribute too long"); \
    return (HC_RET_ERR_ABORT); \
  }


/* Pick the last of the strongest authentication schemes offered */

HC_RET
http_cli_parse_authorize_headers (http_cli_ctx * ctx)
{
  char* s;
  char* e;
  char* last;
  char tmp_buf[1024];
  int found;

  DO_SET (caddr_t, hdr, &ctx->hcctx_resp_hdrs)
    {
      if (!strnicmp ("WWW-Authenticate:", hdr, 17))
	{
	  last = hdr + box_length (hdr) - 3;
	  s = hdr + 17;
	  s = skip_lwsp (s, last);

	  if (!strnicmp ("Digest", s, 6))
	    {
	      ctx->hcctx_auth_type = HC_AUTH_DIGEST;
	    }
	  if (!strnicmp ("Basic", s, 5))
	    {
	      if (HC_AUTH_DIGEST != ctx->hcctx_auth_type)
		ctx->hcctx_auth_type = HC_AUTH_BASIC;
	    }
	  s = next_delim (s, last);
	  s = skip_lwsp (s, last);
	  while (s < last)
	    {
	      found = 0;
	      if (!strnicmp ("Realm=\"", s, 7))
		{
		  found = 1;
		  s += 7;
		  e = strnchr (s, '"', last - s);
		  BOX_VAL (ctx->hcctx_realm, s, e, tmp_buf);
		  s = e + 1;
		}
	      if (!strnicmp ("Domain=\"", s, 8))
		{
		  found = 1;
		  s += 8;
		  e = strnchr (s, '"', last - s);
		  BOX_VAL (ctx->hcctx_domain, s, e, tmp_buf);
		  s = e + 1;
		}
	      if (!strnicmp ("Nonce=\"", s, 7))
		{
		  found = 1;
		  s += 7;
		  e = strnchr (s, '"', last - s);
		  BOX_VAL (ctx->hcctx_nonce, s, e, tmp_buf);
		  s = e + 1;
		}
	      if (!strnicmp ("Opaque=\"", s, 8))
		{
		  found = 1;
		  s += 8;
		  e = strnchr (s, '"', last - s);
		  BOX_VAL (ctx->hcctx_opaque, s, e, tmp_buf);
		  s = e + 1;
		}
	      if (!strnicmp ("Stale=\"", s, 7))
		{
		  found = 1;
		  s += 7;
		  e = strnchr (s, '"', last - s);
		  BOX_VAL (ctx->hcctx_stale, s, e, tmp_buf);
		  s = e + 1;
		}
	      if (!strnicmp ("qop=\"", s, 5))
		{
		  found = 1;
		  s += 5;
		  e = strnchr (s, '"', last - s);
		  BOX_VAL (ctx->hcctx_qop, s, e, tmp_buf);
		  s = e + 1;
		}
	      if (!strnicmp ("Algorithm=\"", s, 11))
		{
		  found = 1;
		  s += 11;
		  e = strnchr (s, '"', last - s);
		  if (!stricmp (s, "MD5-sess"))
		    ctx->hcctx_algorithm = HA_ALGORITHM_MD5_SESS;
		  else
		    ctx->hcctx_algorithm = HA_ALGORITHM_MD5;
		  s = e + 1;
		}
	      if (!found)
		{
		  s = skip_attr (s, last);
		}
	      if (*s == ',') s++;
	      s = skip_lwsp (s, last);
	    }
	}
    }
  END_DO_SET ();

  if (!ctx->hcctx_auth_type)
    {
      ctx->hcctx_err = srv_make_new_error ("42000", "HC013", "Cannot parse authentication challenge");
      return (HC_RET_ERR_ABORT);
    }
  return (HC_RET_OK);
}

HC_RET
http_cli_std_handle_redir (http_cli_ctx * ctx, caddr_t parm, caddr_t ret_val, caddr_t err_ret)
{
  int ret;
  char *s = NULL, *last;
  caddr_t url, loc, err = NULL;
  CATCH_ABORT (http_cli_read_resp_hdrs, ctx, ret);
  CATCH_ABORT (http_cli_read_resp_body, ctx, ret);

  if (!ctx->hcctx_redirects)
    {
      ctx->hcctx_err = srv_make_new_error ("42000", "HC013", "Max redirects reached");
      return (HC_RET_ERR_ABORT);
    }

  DO_SET (caddr_t, hdr, &ctx->hcctx_resp_hdrs)
    {
      if (!strnicmp ("Location:", hdr, 9))
	{
	  last = hdr + box_length (hdr) - 2;
	  s = hdr + 10;
	  s = skip_lwsp (s, last);
	  while (last[0] == 0xd || last[0] == 0xa || last[0] == ' ')
	    {
	      last[0] = 0;
	      last--;
	    }
	  break;
	}
    }
  END_DO_SET ();

  if (!s)
    {
      ctx->hcctx_err = srv_make_new_error ("42000", "HC013", "Cannot parse location header");
      return (HC_RET_ERR_ABORT);
    }
  loc = box_string (s);
  url = rfc1808_expand_uri (ctx->hcctx_url, loc, "UTF-8", 1, "UTF-8", "UTF-8", &err);
  if (err)
    {
      ctx->hcctx_err = err;
      return (HC_RET_ERR_ABORT);
    }
  if (url == ctx->hcctx_url)
    url = box_copy (ctx->hcctx_url);
  if (url != loc)
    dk_free_box (loc);
  RELEASE (ctx->hcctx_host);
  RELEASE (ctx->hcctx_uri);
  RELEASE (ctx->hcctx_url);
  ctx->hcctx_url = url;
  ctx->hcctx_host = http_cli_get_host_from_url (url);
  ctx->hcctx_uri = http_cli_get_uri_from_url (url);
#ifdef _SSL
  if (!strnicmp (url, "https://", 8) && !ctx->hcctx_pkcs12_file)
    {
      http_cli_ssl_cert (ctx, (caddr_t)"1");
      ctx->hcctx_ssl_insecure = '\1';
      RELEASE (ctx->hcctx_proxy.hcp_proxy);
    }
  else if (!strnicmp (url, "http://", 7))
    {
      ctx->hcctx_pkcs12_file = NULL;
    }
#endif
  ctx->hcctx_redirects --;
  ctx->hcctx_retry_count = 0;
  F_SET (ctx, HC_F_RETRY);
  return (HC_RET_RETRY);
}

HC_RET
http_cli_std_handle_auth (http_cli_ctx * ctx, caddr_t parm, caddr_t ret_val, caddr_t err)
{
  int ret;
  http_cli_handler_frame_t * handler;

  if (!ctx->hcctx_user)
    {
      ctx->hcctx_err =
	srv_make_new_error ("42000", "HC014",
			"Authorization required and no credentials available");
      return (HC_RET_ERR_ABORT);
    }

  CATCH_ABORT (http_cli_read_resp_hdrs, ctx, ret);
  CATCH_ABORT (http_cli_parse_authorize_headers, ctx, ret);

  switch (ctx->hcctx_auth_type)
    {
    case 1:
      {
	handler = http_cli_make_handler_frame (http_cli_calc_auth_digest,
					       NULL, NULL, NULL);
	break;
      }
    case 2:
      {
	handler = http_cli_make_handler_frame (http_cli_calc_auth_basic,
					       NULL, NULL, NULL);
	break;
      }
    default:
      {
	ctx->hcctx_err =
	  srv_make_new_error ("42000", "HC015",
			  "Cannot understand authorization challenge");
	return (HC_RET_ERR_ABORT);
      }
    }
  http_cli_push_hook (ctx, HC_HTTP_REQ_PRE, handler);
  F_SET (ctx, HC_F_RETRY);
  return (HC_RET_RETRY);
}

http_cli_ctx *
http_cli_std_init (char * url, caddr_t * qst)
{
  http_cli_ctx * ctx;
  http_cli_handler_frame_t * h;

  ctx = http_cli_ctx_init ();

  ctx->hcctx_http_maj = 1;
  ctx->hcctx_http_min = 1;
  ctx->hcctx_keep_alive = 1;
  ctx->hcctx_timeout = 100;
  ctx->hcctx_qst = qst;

  ctx->hcctx_url = box_string (url);
  ctx->hcctx_method = HC_METHOD_GET;
  ctx->hcctx_host = http_cli_get_host_from_url (url);
  ctx->hcctx_uri = http_cli_get_uri_from_url (url);

  if (http_cli_proxy_server && !http_cli_target_is_proxy_exception (ctx->hcctx_host))
    http_cli_set_proxy (ctx, http_cli_proxy_server);

  h = http_cli_make_handler_frame (http_cli_handle_malfm_resp, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_RESP_MALF, h);

  h = http_cli_make_handler_frame (http_cli_handle_read_err, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_READ_ERR, h);

  h = http_cli_make_handler_frame (http_cli_handle_write_err, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_WRITE_ERR, h);

  h = http_cli_make_handler_frame (http_cli_handle_conn_err, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_CONN_ERR, h);

  h = http_cli_make_handler_frame (http_cli_handle_socks_conn_post, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_CONN_POST, h);

  return (ctx);
}

void
http_cli_get_canonic_host (http_cli_ctx * ctx, char * host, size_t len)
{
  char * sep = NULL;
  int port = 0;
  strcpy_size_ck (host, ctx->hcctx_host, len);
  sep = strrchr (host, ':');
  if (!sep)
    return;
  port = atoi (sep + 1);
#ifdef _SSL
  if (80 == port && !ctx->hcctx_pkcs12_file)
    *sep = 0;
  else if (443 == port && ctx->hcctx_pkcs12_file)
    *sep = 0;
#else
  if (80 == port)
    *sep = 0;
#endif
}

int
http_cli_std_hdrs (http_cli_ctx * ctx)
{
  char hdr_tmp[2048];

  if (ctx->hcctx_http_maj >= 1 && ctx->hcctx_http_min >= 1)
    {
      char host[1024];
      http_cli_get_canonic_host (ctx, host, sizeof (host));
      snprintf (hdr_tmp, sizeof (hdr_tmp), "Host: %s\r\n", host);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, hdr_tmp);
      if (ctx->hcctx_keep_alive)
	{
	  snprintf (hdr_tmp, sizeof (hdr_tmp), "Connection: Keep-Alive\r\n");
	  SES_PRINT (ctx->hcctx_prv_req_hdrs, hdr_tmp);
	  if (ctx->hcctx_proxy.hcp_proxy)
	    {
	      snprintf (hdr_tmp, sizeof (hdr_tmp), "Proxy-Connection: Keep-Alive\r\n");
	      SES_PRINT (ctx->hcctx_prv_req_hdrs, hdr_tmp);
	    }
	}
      else
	{
	  snprintf (hdr_tmp, sizeof (hdr_tmp), "Connection: close\r\n");
	  SES_PRINT (ctx->hcctx_prv_req_hdrs, hdr_tmp);
	}
    }

  if (ctx->hcctx_ua_id)
    {
      snprintf (hdr_tmp, sizeof (hdr_tmp), "User-Agent: %s\r\n", ctx->hcctx_ua_id);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, hdr_tmp);
    }
  if (ctx->hcctx_req_ctype)
    {
      snprintf (hdr_tmp, sizeof (hdr_tmp), "Content-Type: %s\r\n", ctx->hcctx_req_ctype);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, hdr_tmp);
    }
  if (NULL != ctx->hcctx_proxy.hcp_user && 0 == ctx->hcctx_proxy.hcp_socks_ver)
    {
      char enc_buf [2048];
      uint32 len;
      snprintf (hdr_tmp, sizeof (hdr_tmp), "%s:%s", ctx->hcctx_proxy.hcp_user, ctx->hcctx_proxy.hcp_pass);
      len = strlen (hdr_tmp) + 1;
      SES_PRINT (ctx->hcctx_prv_req_hdrs, "Proxy-Authorization: Basic ");
      encode_base64 (hdr_tmp, enc_buf, len);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, enc_buf);
      SES_PRINT (ctx->hcctx_prv_req_hdrs, "\r\n");
    }
  return (HC_RET_OK);
}

HC_RET
http_cli_req_init (http_cli_ctx * ctx)
{
  if (F_ISSET (ctx, HC_F_RETRY))
    {
      F_RESET (ctx, HC_F_RETRY);
      F_RESET (ctx, HC_F_ABORT);
      RELEASE (ctx->hcctx_resp_body);
      F_RESET (ctx, HC_F_BODY_READ);
      RELEASE (ctx->hcctx_response);
      F_RESET (ctx, HC_F_REPLY_READ);

      if (ctx->hcctx_resp_hdrs)
	{
	  DO_SET (caddr_t, l, &ctx->hcctx_resp_hdrs)
	    {
	      RELEASE (l);
	    }
	  END_DO_SET ();
	}

      dk_set_free (ctx->hcctx_resp_hdrs);
      ctx->hcctx_resp_hdrs = NULL;

      F_RESET (ctx, HC_F_HDRS_READ);

      strses_flush (ctx->hcctx_prv_req_hdrs);

      ctx->hcctx_is_chunked = 0;
      ctx->hcctx_respcode = 0;
      ctx->hcctx_resp_content_length = 0;
      ctx->hcctx_resp_content_len_recd = 0;
    }
  return (HC_RET_OK);
}

static void
http_cli_resp_reset (http_cli_ctx * ctx)
{
  if (!F_ISSET (ctx, HC_F_REPLY_READ)) return;

  RELEASE (ctx->hcctx_resp_body);
  F_RESET (ctx, HC_F_BODY_READ);
  RELEASE (ctx->hcctx_response);
  F_RESET (ctx, HC_F_REPLY_READ);

  if (ctx->hcctx_resp_hdrs)
    {
      DO_SET (caddr_t, l, &ctx->hcctx_resp_hdrs)
	{
	  RELEASE (l);
	}
      END_DO_SET ();
    }

  dk_set_free (ctx->hcctx_resp_hdrs);
  ctx->hcctx_resp_hdrs = NULL;

  F_RESET (ctx, HC_F_HDRS_READ);

  strses_flush (ctx->hcctx_prv_req_hdrs);

  ctx->hcctx_is_chunked = 0;
  ctx->hcctx_respcode = 0;
  ctx->hcctx_resp_content_length = 0;
  ctx->hcctx_resp_content_len_recd = 0;
}

HC_RET
http_cli_send_request_1 (http_cli_ctx * ctx, int connect)
{
  int ret = HC_RET_OK;

  do
    {
      http_cli_req_init (ctx);
      if (connect)
	{
          CATCH_ABORT (http_cli_connect, ctx, ret);
	}
      ctx->hcctx_req_start_time = get_msec_real_time ();
      CATCH_ABORT (http_cli_send_req, ctx, ret);
    }
  while (F_ISSET (ctx, HC_F_RETRY) &&
	 !ctx->hcctx_err &&
	 ctx->hcctx_retry_count++ <= ctx->hcctx_retry_max);

  return (ret);
}

HC_RET
http_cli_read_response (http_cli_ctx * ctx)
{
  int ret = HC_RET_OK;

  http_cli_req_init (ctx);

  do
    {
      if (!F_ISSET (ctx, HC_F_RETRY))
	http_cli_resp_reset (ctx);
      CATCH_ABORT (http_cli_read_resp, ctx, ret);
      CATCH_ABORT (http_cli_read_resp_hdrs, ctx, ret);
    }
  while (F_ISSET (ctx, HC_F_HDRS_READ) && ctx->hcctx_respcode == 100);
  CATCH_ABORT (http_cli_read_resp_body, ctx, ret);

  return (ret);
}


HC_RET
http_cli_send_request (http_cli_ctx * ctx)
{
  return http_cli_send_request_1 (ctx, 1);
}


HC_RET
http_cli_main (http_cli_ctx * ctx)
{
  int ret = HC_RET_OK;

  do
    {
      http_cli_req_init (ctx);

      CATCH_ABORT (http_cli_connect, ctx, ret);

      ctx->hcctx_req_start_time = get_msec_real_time ();

      CATCH_ABORT (http_cli_send_req, ctx, ret);
      do
	{
	  if (!F_ISSET (ctx, HC_F_RETRY))
	    http_cli_resp_reset (ctx);
	  CATCH_ABORT (http_cli_read_resp, ctx, ret);
	  CATCH_ABORT (http_cli_read_resp_hdrs, ctx, ret);
	}
      while (F_ISSET (ctx, HC_F_HDRS_READ) && ctx->hcctx_respcode == 100);
    }
  while (F_ISSET (ctx, HC_F_RETRY) &&
	 !ctx->hcctx_err &&
	 ctx->hcctx_retry_count++ <= ctx->hcctx_retry_max);

  CATCH_ABORT (http_cli_read_resp_body, ctx, ret);

  return (ret);
}

HC_RET
http_cli_init_std_auth (http_cli_ctx* ctx, caddr_t user, caddr_t pass)
{
  ctx->hcctx_user = user;
  ctx->hcctx_pass = pass;
  http_cli_push_resp_evt (ctx,
			  401,
			  http_cli_make_handler_frame (http_cli_std_handle_auth,
						       NULL, NULL, NULL));
  return (HC_RET_OK);
}

HC_RET
http_cli_init_std_redir (http_cli_ctx* ctx, int r)
{
  http_cli_push_resp_evt (ctx, 301, http_cli_make_handler_frame (http_cli_std_handle_redir, NULL, NULL, NULL));
  http_cli_push_resp_evt (ctx, 302, http_cli_make_handler_frame (http_cli_std_handle_redir, NULL, NULL, NULL));
  http_cli_push_resp_evt (ctx, 303, http_cli_make_handler_frame (http_cli_std_handle_redir, NULL, NULL, NULL));
  ctx->hcctx_redirects = r;
  return (HC_RET_OK);
}

/*
   http_client
   parameters:

   1. url
   2. user
   3. password
   4. HTTP method
   5. request HTTP headers
   6. request body
   7. certificate
   8. pk password
   9. response HTTP headers
   10. timeout
   11. proxy
   12. ca bundle
   13. insecure option
   14. ret argument index in args ssls
   15. how many redirects to follow
In bif_http_client_impl, arguments qst, err_ret, args and me are traditional
All arguments except the URL can be db NULLs in bif call, NULL pointers in _impl call.
*/

caddr_t
bif_http_client_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, char * me,
    caddr_t url, caddr_t uid, caddr_t pwd, caddr_t method, caddr_t http_hdr, caddr_t body,
    caddr_t cert, caddr_t pk_pass, uint32 time_out, int time_out_is_null, caddr_t proxy, caddr_t ca_certs, int insecure,
    int ret_arg_index,
    int follow_redirects)
{
  http_cli_ctx * ctx;
  char* ua_id = http_client_id_string;
  caddr_t ret = NULL;
  caddr_t _err_ret;
  int meth = HC_METHOD_GET;
  dk_set_t hdrs = NULL;
  caddr_t *head = NULL;
  int to_free_head = 1;
  dtp_t dtp;
  long start_dt;


  ctx = http_cli_std_init (url, qst);
  ctx->hcctx_method = HC_METHOD_GET;

  if (uid && pwd)
    http_cli_init_std_auth (ctx, uid, pwd);
  if (follow_redirects)
    http_cli_init_std_redir (ctx, follow_redirects);

  if (method)
    {
      meth = http_method_id (method);
      http_cli_set_method (ctx, meth);
    }

  if (http_hdr)
    {
      if (NULL != nc_strstr ((unsigned char *) http_hdr, (unsigned char *) "User-Agent:")) /* we already have ua id in headers */
	ua_id = NULL;
      http_cli_add_req_hdr (ctx, http_hdr);
    }

  http_cli_set_ua_id (ctx, ua_id);
  dtp = DV_TYPE_OF (body);
  if (body && dtp != DV_DB_NULL)
    {
      if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING || dtp == DV_C_STRING)
	{
	  session_buffered_write (ctx->hcctx_req_body, body, box_length (body) - 1);
	}
      else if (DV_STRING_SESSION == dtp)
	{
	  strses_write_out ((dk_session_t *) body, ctx->hcctx_req_body);
	}
      else
	{
	  sqlr_new_error ("22023", "SR005", "Function %s needs a string or NULL as argument %d, "
	      "not an arg of type %s (%d)", me, 6, dv_type_title (dtp), dtp);
	}
      if (meth == HC_METHOD_POST && (!http_hdr ||
	    !nc_strstr ((unsigned char *) http_hdr, (unsigned char *) "Content-Type:")))
	http_cli_set_req_content_type (ctx, (caddr_t)"application/x-www-form-urlencoded");
    }
#ifdef _SSL
  if (NULL != cert)
    {
      http_cli_ssl_cert (ctx, cert);
      http_cli_ssl_cert_pass (ctx, pk_pass);
      http_cli_ssl_ca_certs (ctx, ca_certs);
      ctx->hcctx_ssl_insecure = (char) insecure;
      RELEASE (ctx->hcctx_proxy.hcp_proxy);
    }
  else if (!strnicmp (url, "https://", 8))
    {
      http_cli_ssl_cert (ctx, (caddr_t)"1");
      ctx->hcctx_ssl_insecure = (char) insecure;
      RELEASE (ctx->hcctx_proxy.hcp_proxy);
    }
#endif
  if (!time_out_is_null) /* timeout */
    {
      ctx->hcctx_timeout = time_out;
    }
  if (proxy != NULL)
    http_cli_set_proxy (ctx, proxy);

  if (NULL != (ret = http_client_cache_get ((query_instance_t *)qst, url, http_hdr, body, args, ret_arg_index)))
    {
      http_cli_ctx_free (ctx);
      return ret;
    }

  IO_SECT(qst);

#ifdef DEBUG
  fprintf (stderr, "bif_http_client: State: %d\n", ctx->hcctx_state);
#endif
  start_dt = get_msec_real_time ();
  if (!http_cli_main (ctx))
    ret = box_copy_tree (ctx->hcctx_resp_body);
  if (NULL == ret)
    ret = box_dv_short_string ("");

  if (prof_on)
    prof_exec (NULL, "http_client", get_msec_real_time () - start_dt, 1);

#ifdef DEBUG
  fprintf (stderr, "bif_http_client: State: %d\n", ctx->hcctx_state);

  fprintf (stderr, "bif_http_client: Releasing the client context\n");
#endif

  _err_ret = http_cli_get_err (ctx);

  if (_err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
      http_cli_ctx_free (ctx);
      sqlr_resignal (_err_ret);
    }

  dk_set_push (&hdrs, box_dv_short_string (ctx->hcctx_response));
  DO_SET (caddr_t, line, &(ctx->hcctx_resp_hdrs))
    {
      dk_set_push (&hdrs, box_dv_short_string (line));
    }
  END_DO_SET();
  head = (caddr_t *)list_to_array (dk_set_nreverse (hdrs));

  if (BOX_ELEMENTS_0 (args) > ret_arg_index && ssl_is_settable (args[ret_arg_index]))
    {
      qst_set (qst, args[ret_arg_index], (caddr_t) head);
      to_free_head = 0;
    }

  if (ctx->hcctx_is_gzip && DV_STRINGP (ret) && box_length (ret) > 2)
    {
      dk_session_t *out = strses_allocate ();
      strses_enable_paging (out, http_ses_size);
      zlib_box_gzip_uncompress (ret, out, err_ret);
      dk_free_tree (ret);
      if (!STRSES_CAN_BE_STRING (out))
	ret = (caddr_t) out;
      else
	{
	  ret = strses_string (out);
	  dk_free_box (out);
	}
    }

  http_cli_ctx_free (ctx);
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  http_client_cache_register ((query_instance_t *)qst, url, http_hdr, body, head, ret);
  if (to_free_head)
    dk_free_tree ((caddr_t) head);
  return (ret);
}


caddr_t
bif_http_client (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char* me = "http_client";
  caddr_t url = bif_string_arg (qst, args, 0, me);
  caddr_t uid = NULL, pwd = NULL;
  caddr_t http_hdr = NULL, body = NULL, method = NULL;
  uint32 time_out = 0;
  int time_out_is_null = 1, insecure = 0, follow_redirects = 0;
  caddr_t cert = NULL, pk_pass = NULL;
  caddr_t proxy = NULL, ca_certs = NULL;

  if (BOX_ELEMENTS (args) > 1)
    {
      uid = bif_string_or_null_arg (qst, args, 1, me);
      pwd = bif_string_or_null_arg (qst, args, 2, me);
    }
  if (BOX_ELEMENTS (args) > 3)
    method = bif_string_or_null_arg (qst, args, 3, me);
  if (BOX_ELEMENTS (args) > 4)
    http_hdr = bif_string_or_null_arg (qst, args, 4, me);
  if (BOX_ELEMENTS (args) > 5)
    {
      dtp_t dtp;
      body = bif_arg (qst, args, 5, me);
      dtp = DV_TYPE_OF (body);
      if (dtp != DV_DB_NULL && dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING && dtp != DV_C_STRING && DV_STRING_SESSION != dtp)
	{
	  sqlr_new_error ("22023", "SR005", "Function %s needs a string or NULL as argument %d, "
	      "not an arg of type %s (%d)", me, 6, dv_type_title (dtp), dtp);
	}
    }
#ifdef _SSL
  if (BOX_ELEMENTS (args) > 6)
    {
      cert = bif_string_or_null_arg (qst, args, 6, me);
      if (BOX_ELEMENTS (args) > 7)
	pk_pass = bif_string_or_null_arg (qst, args, 7, me);
    }
#endif
  if (BOX_ELEMENTS (args) > 9) /* timeout */
    {
      time_out = (uint32) bif_long_or_null_arg (qst, args, 9, me, &time_out_is_null);
    }
  if (BOX_ELEMENTS (args) > 10) /* proxy server */
    {
      proxy = bif_string_or_null_arg (qst, args, 10, me);
    }
  if (BOX_ELEMENTS (args) > 11) /* ca certs */
    {
      ca_certs = bif_string_or_null_arg (qst, args, 11, me);
    }
  if (BOX_ELEMENTS (args) > 12) /* ca certs */
    {
      int insecure_is_null = 0;
      insecure = (int) bif_long_or_null_arg (qst, args, 12, me, &insecure_is_null);
    }
  if (BOX_ELEMENTS (args) > 13) /* follow redirects */
    {
      int dummy = 0;
      follow_redirects = (int) bif_long_or_null_arg (qst, args, 13, me, &dummy);
    }
  return bif_http_client_impl (qst, err_ret, args, me, url, uid, pwd, method, http_hdr, body, cert, pk_pass, time_out, time_out_is_null, proxy, ca_certs, insecure, 8, follow_redirects);
}

caddr_t
bif_http_pipeline (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t reqs = NULL; /* requests */
  dk_set_t ress = NULL; /* responses */
  char* me = "http_pipeline";
  caddr_t * urls = (caddr_t *)bif_array_or_null_arg (qst, args, 0, me);
  caddr_t ret = NULL;
  caddr_t _err_ret = NULL;
  int meth = HC_METHOD_GET;
  int inx, len;
  caddr_t * ents = NULL;
  caddr_t * http_hdr_arr = NULL;
  dk_session_t * ses = NULL;
  caddr_t host = NULL;

  if (BOX_ELEMENTS (args) > 1)
    {
      caddr_t method = bif_string_or_null_arg (qst, args, 1, me);
      if (method)
	{
	  meth = http_method_id (method);
	}
    }
  if (BOX_ELEMENTS (args) > 2)
    http_hdr_arr = (caddr_t *) bif_array_or_null_arg (qst, args, 2, me);
  if (BOX_ELEMENTS (args) > 3)
    {
      ents = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 3, me);
      if (ARRAYP (ents) && ARRAYP (urls) && BOX_ELEMENTS (ents) != BOX_ELEMENTS (urls))
	sqlr_new_error ("22023", "HTC01", "Entities must be same number as URLs");
    }
  if (!ARRAYP (ents) && !ARRAYP (urls))
    sqlr_new_error ("22023", "HTC01", "Either URLs or entities must be an array");

  len = ARRAYP (urls) ? BOX_ELEMENTS (urls) : BOX_ELEMENTS (ents);

  for (inx = 0; inx < len; inx ++)
    {
      http_cli_ctx * ctx;
      caddr_t url = ARRAYP (urls) ? urls[inx] : (caddr_t) urls;
      caddr_t http_hdr = ARRAYP (http_hdr_arr) ? http_hdr_arr[inx] : (caddr_t) http_hdr_arr;

      if (!DV_STRINGP (url))
	{
	  *err_ret = srv_make_new_error ("22023", "HTC03", "URLs must be array of strings or single string");
	  goto error_ret;
	}

      if (http_hdr && !DV_STRINGP (http_hdr) && DV_DB_NULL != DV_TYPE_OF (http_hdr))
	{
	  *err_ret = srv_make_new_error ("22023", "HTC03", "Headers must be array of strings or single string");
	  goto error_ret;
	}

      ctx = http_cli_std_init (url, qst);
      http_cli_set_ua_id (ctx, http_client_id_string);
      http_cli_set_method (ctx, meth);
      if (DV_STRINGP (http_hdr) && box_length (http_hdr) > 1)
	http_cli_add_req_hdr (ctx, http_hdr);

      if (ents && ARRAYP(ents))
	{
	  caddr_t body = ents[inx];
	  if (!DV_STRINGP (body))
	    {
	      *err_ret = srv_make_new_error ("22023", "HTC03", "Entities must be array of strings or null");
	      goto error_ret;
	    }
	  session_buffered_write (ctx->hcctx_req_body, body, box_length (body) - 1);
	  if (meth == HC_METHOD_POST && (!http_hdr ||
		!nc_strstr ((unsigned char *) http_hdr, (unsigned char *) "Content-Type:")))
	    http_cli_set_req_content_type (ctx, (caddr_t)"application/x-www-form-urlencoded");
	}
      if (!host)
	host = ctx->hcctx_host;
      else if (0 != strcmp (host, ctx->hcctx_host))
	{
	  *err_ret = srv_make_new_error ("22023", "HTC02", "The pipeline requests must be to same host");
	  goto error_ret;
	}
      dk_set_push (&reqs, ctx);
    }
  if (!host) /* pipeline post, but no data at all */
    return list (0);

  reqs = dk_set_nreverse (reqs);

  IO_SECT(qst);
  ses = http_dks_connect (host, &_err_ret);
  if (_err_ret)
    sqlr_resignal (_err_ret);

  DO_SET (http_cli_ctx *, ctx, &reqs)
    {
      ctx->hcctx_http_out = ses;
      http_cli_send_request_1 (ctx, 0);
      _err_ret = http_cli_get_err (ctx);
      if (_err_ret)
	{
	  sqlr_resignal (_err_ret);
	}
    }
  END_DO_SET ();
  DO_SET (http_cli_ctx *, ctx, &reqs)
    {
      caddr_t resp;
      caddr_t hdr;
      resp = NULL;
      if (!http_cli_read_response (ctx))
	{
	  if (ctx->hcctx_resp_body)
	    resp = box_copy_tree (ctx->hcctx_resp_body);
	  else
	    resp = NEW_DB_NULL;
	}
      hdr = (caddr_t) http_cli_get_resp_headers (ctx);
      dk_set_push (&ress, list (2, resp, hdr));
      _err_ret = http_cli_get_err (ctx);
      if (_err_ret)
	{
	  dk_free_tree (list_to_array (dk_set_nreverse (ress)));
	  ress = NULL;
	  sqlr_resignal (_err_ret);
	}
    }
  END_DO_SET ();
  END_IO_SECT (err_ret);
error_ret:
  if (ses)
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
    }
  DO_SET (http_cli_ctx *, ctx, &reqs)
    {
      ctx->hcctx_http_out = NULL;
      http_cli_ctx_free (ctx);
    }
  END_DO_SET ();
  dk_set_free (reqs);
  ret = list_to_array (dk_set_nreverse (ress));
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return (ret);
}

static void
init_acl_set (char *acl_string1, dk_set_t * acl_set_ptr)
{
  char *tmp, *tok_s = NULL, *tok;
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
	      dk_set_push (acl_set_ptr, box_dv_short_string (tok));
	    }
	  tok = strtok_r (NULL, ",", &tok_s);
	}
      dk_free_box (acl_string);
    }
}

/*
   HTTP client
   http_get
   1 - URL
   2 - variable to return response headers
   3 - HTTP method string
   4 - request header line(s)
   5 - request body
   6 - proxy address
   7 - number of HTTP redirects to follow
   8 - time-out (seconds)
*/

caddr_t
bif_http_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "http_get";
  caddr_t uri = bif_string_or_uname_arg (qst, args, 0, me);
  int n_args = BOX_ELEMENTS (args), follow_redirects = 0, to_is_null = 1;
  caddr_t method = NULL;
  caddr_t header = NULL;
  caddr_t body = NULL;
  caddr_t volatile proxy = NULL;
  uint32 to = 0;

  if (n_args > 2)
    method = bif_string_or_uname_arg (qst, args, 2, me);
  if (n_args > 3)
    header = bif_string_or_null_arg (qst, args, 3, me);
  if (n_args > 4)
    {
      dtp_t dtp;
      body = bif_arg (qst, args, 4, me);
      dtp = DV_TYPE_OF (body);
      if (dtp != DV_DB_NULL && dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING && dtp != DV_C_STRING && DV_STRING_SESSION != dtp)
	{
	  sqlr_new_error ("22023", "SR005", "Function %s needs a string or NULL as argument %d, "
	      "not an arg of type %s (%d)", me, 6, dv_type_title (dtp), dtp);
	}
    }
  if (n_args > 5)
    proxy = bif_string_or_null_arg (qst, args, 5, me);
  if (n_args > 6) /* follow redirects */
    {
      int dummy = 0;
      follow_redirects = (int) bif_long_or_null_arg (qst, args, 6, me, &dummy);
    }
  if (n_args > 7) /* time-out */
    to = (uint32) bif_long_or_null_arg (qst, args, 7, me, &to_is_null);
  return bif_http_client_impl (qst, err_ret, args, me, uri, NULL, NULL, method, header, body, NULL, NULL, to, to_is_null, proxy, NULL, 0, 1, follow_redirects);
}

void
bif_http_client_init (void)
{
  init_acl_set (http_cli_proxy_except, &http_cli_proxy_except_set);
  bif_define_ex ("http_client_internal", bif_http_client, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("http_pipeline", bif_http_pipeline, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("http_get", bif_http_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
}
