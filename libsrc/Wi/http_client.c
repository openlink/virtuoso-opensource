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
 *  Copyright (C) 1998-2006 OpenLink Software
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

#define XML_VERSION		"1.0"

/*#define _USE_CACHED_SES from http.h */

char* http_cli_meth[] = { "NONE", "GET",  "HEAD", "POST", "PUT" };

#define FREE_BOX_IF(box) \
if (box) \
  dk_free_box (box);

#define STANDARD_HANDLER(name, errcode, errmsg) \
int name (http_cli_ctx * ctx, caddr_t parm, caddr_t ret, caddr_t err) \
{ \
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

int
http_cli_hook_dispatch (http_cli_ctx * ctx, int hook)
{
  if (!ctx->hcctx_hooks[hook])
    return 0;

  DO_SET (http_cli_handler_frame_t*, fm, &ctx->hcctx_hooks[hook])
    {
      if ((ctx->hcctx_hook_ret = (fm->fn)(ctx, fm->pm, fm->rt, fm->er))
	  == HC_RET_ERR_ABORT)
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
	http_session_used (ctx->hcctx_http_out,
			   ((ctx->hcctx_proxy != NULL) ?
			    ctx->hcctx_proxy : ctx->hcctx_host),
			   ctx->hcctx_peer_max_timeout);
    }
#endif

  dk_free_tree (ctx->hcctx_url);
  dk_free_tree (ctx->hcctx_host);
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
      ctx->hcctx_ua_id = box_dv_short_string (ua_id);
    }
  return (HC_RET_OK);
}

caddr_t
http_cli_get_err (http_cli_ctx * ctx)
{
  return (ctx->hcctx_err);
}

/* XXX: TODO: proxies, proxy auth, http redirect */
#ifdef _SSL
int ssl_client_use_pkcs12 (SSL *ssl, char *pkcs12file, char *passwd, char * ca);
#endif

HC_RET
http_cli_connect (http_cli_ctx * ctx)
{
  http_cli_hook_dispatch (ctx, HC_HTTP_CONN_PRE);
#ifdef _USE_CACHED_SES
  if (!ctx->hcctx_no_cached)
    ctx->hcctx_http_out = http_cached_session (ctx->hcctx_host);
  else
    ctx->hcctx_http_out = NULL;
  if (ctx->hcctx_http_out)
    ctx->hcctx_http_out_cached = 1;
  else
#endif
    ctx->hcctx_http_out = http_dks_connect (ctx->hcctx_host, &ctx->hcctx_err);
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

	  ctx->hcctx_ssl_method = SSLv23_client_method();
	  ctx->hcctx_ssl_ctx = SSL_CTX_new (ctx->hcctx_ssl_method);
	  ctx->hcctx_ssl = SSL_new (ctx->hcctx_ssl_ctx);
	  SSL_set_fd (ctx->hcctx_ssl, dst);

	  if (pkcs12_file && 0 == atoi(pkcs12_file))
	    {
	      int session_id_context = 12;
	      if (!ssl_client_use_pkcs12 (ctx->hcctx_ssl, pkcs12_file, pass, NULL))
		{
		  ctx->hcctx_err = srv_make_new_error ("22023", "HTS02", "Invalid certificate file");
		  goto error_in_ssl;
		}

	      SSL_set_verify (ctx->hcctx_ssl,
		  SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE, NULL);
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
	      ctx->hcctx_err = srv_make_new_error ("08001", "HTS01", err1);
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
  if (ctx)
    ctx->hcctx_method = method;
  return (HC_RET_OK);
}

char*
http_cli_get_method_string (http_cli_ctx * ctx)
{
  return (http_cli_meth [ctx->hcctx_method]);
}

char*
http_cli_get_doc_str (http_cli_ctx * ctx)
{
  char* s = NULL;
  char* l;

  if (!strnicmp (ctx->hcctx_url, "http://", 7))
    s = ctx->hcctx_url + 7;
  else if (!strnicmp (ctx->hcctx_url, "https://", 8))
    s = ctx->hcctx_url + 8;

  if (s)
    {
      l = ctx->hcctx_url + box_length (ctx->hcctx_url);
      s = strchr (s, '/');
      if (!s || s == l)
	{
	  return ("/index.html");
	}
      else
	{
	  return (s);
	}
    }
  return (ctx->hcctx_url);
}

HC_RET
http_cli_add_req_hdr (http_cli_ctx * ctx, char* hdr)
{
  SES_PRINT (ctx->hcctx_pub_req_hdrs, hdr);
  return (HC_RET_OK);
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
      SES_PRINT (ctx->hcctx_http_out, http_cli_get_doc_str (ctx));
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
  if (!strnicmp ("Connection:", hdr, 11) && nc_strstr ((unsigned char *) hdr, (unsigned char *) "keep-alive"))
    {
      ctx->hcctx_keep_alive = 1;
      ctx->hcctx_close = 0;
      return (HC_RET_OK);
    }
  if (!strnicmp ("Content-Length:", hdr, 15))
    {
      ctx->hcctx_resp_content_length = atoi (hdr + 15);

      if (ctx->hcctx_resp_content_length < 0)
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC002", "Invalid content length in reply");
	  return (HC_RET_ERR_ABORT);
	}
      if (ctx->hcctx_resp_content_length > 1000000)
	{
	  ctx->hcctx_err = srv_make_new_error ("42000", "HC003", "Reply content too large");
	  return (HC_RET_ERR_ABORT);
	}
    }
  return (HC_RET_OK);
}


HC_RET
http_cli_read_resp_hdrs (http_cli_ctx * ctx)
{
  char read_buf[4096];
  char resp_hdr_tmp[4096];
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

HC_RET
http_cli_read_resp_body (http_cli_ctx * ctx)
{
  int ret;
  dk_session_t * volatile content = NULL;

  ctx->hcctx_state = HC_STATE_READ_RESP_BODY;

  if (!ctx->hcctx_resp_content_length && !ctx->hcctx_is_chunked && !ctx->hcctx_close)
    return (HC_RET_OK);

  if (ctx->hcctx_method == HC_METHOD_HEAD)
    return (HC_RET_OK);

  CATCH_READ_FAIL (ctx->hcctx_http_out)
    {
      if (ctx->hcctx_is_chunked)
	{
	  dk_free_tree (ctx->hcctx_resp_body);
	  ctx->hcctx_resp_body =
	    http_read_chunked_content (ctx->hcctx_http_out,
				       &ctx->hcctx_err,
				       ctx->hcctx_url, 0);
	  if (!ctx->hcctx_resp_body)
	    {
	      ret = http_cli_hook_dispatch (ctx, HC_HTTP_READ_ERR);
	      if (ret == HC_RET_ERR_ABORT)
		return (ret);
	    }
	}
      else if (!ctx->hcctx_resp_content_length && ctx->hcctx_close)
	{
	  /* read until connection is closed */
	  unsigned char c;
	  content = strses_allocate ();

	  for (;;)
	    {
	      c = session_buffered_read_char (ctx->hcctx_http_out);
	      session_buffered_write_char (c, content);
	    }
	}
      else
	{
	  dk_free_tree (ctx->hcctx_resp_body);
	  ctx->hcctx_resp_body =
	    dk_alloc_box (ctx->hcctx_resp_content_length + 1,
			  DV_SHORT_STRING);

	  ctx->hcctx_resp_body[ctx->hcctx_resp_content_length] = '\0';
	  session_buffered_read (ctx->hcctx_http_out,
				 ctx->hcctx_resp_body,
				 ctx->hcctx_resp_content_length);
	}
    }
  FAILED
    {
      if (!content)
	http_cli_hook_dispatch (ctx, HC_HTTP_READ_ERR);
    }
  END_READ_FAIL (ctx->hcctx_http_out);
  if (content)
    {
      dk_free_tree (ctx->hcctx_resp_body);
      ctx->hcctx_resp_body = strses_string (content);
      dk_free_box ((box_t) content);
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
  len = box_length (ctx->hcctx_user) + box_length (ctx->hcctx_pass) + 1;

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

  return box_string (slash);
}

caddr_t
http_cli_get_host_from_url (char* url)
{
  char* st = 0;
  char* slash = 0;
  char host[1024];
  int is_https = 0;

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

  memcpy (host, st, slash - st);
  host[slash - st] = 0;

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
http_cli_std_init (char * url)
{
  http_cli_ctx * ctx;
  http_cli_handler_frame_t * h;

  ctx = http_cli_ctx_init ();

  ctx->hcctx_http_maj = 1;
  ctx->hcctx_http_min = 1;
  ctx->hcctx_keep_alive = 1;
  ctx->hcctx_timeout = 100;

  ctx->hcctx_url = box_string (url);
  ctx->hcctx_method = HC_METHOD_GET;
  ctx->hcctx_host = http_cli_get_host_from_url (url);
  ctx->hcctx_uri = http_cli_get_uri_from_url (url);

  h = http_cli_make_handler_frame (http_cli_handle_malfm_resp, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_RESP_MALF, h);

  h = http_cli_make_handler_frame (http_cli_handle_read_err, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_READ_ERR, h);

  h = http_cli_make_handler_frame (http_cli_handle_write_err, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_WRITE_ERR, h);

  h = http_cli_make_handler_frame (http_cli_handle_conn_err, NULL, NULL, NULL);
  http_cli_push_hook (ctx, HC_HTTP_CONN_ERR, h);

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
  if (80 == port && !ctx->hcctx_pkcs12_file)
    *sep = 0;
  else if (443 == port && ctx->hcctx_pkcs12_file)
    *sep = 0;
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
}

HC_RET
http_cli_send_request (http_cli_ctx * ctx)
{
  int ret = HC_RET_OK;

  do
    {
      http_cli_req_init (ctx);
      CATCH_ABORT (http_cli_connect, ctx, ret);
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


caddr_t
bif_http_client (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  http_cli_ctx * ctx;

  char* me = "http_client";
  caddr_t url = bif_string_arg (qst, args, 0, me);

  char* ua_id = http_client_id_string/*"Frobbozz dingafier v.6.66"*/;
  caddr_t ret = NULL;
  caddr_t _err_ret;
  int meth = HC_METHOD_GET;
  caddr_t http_hdr = NULL;
  caddr_t body = NULL;
  dk_set_t hdrs = NULL;
  caddr_t *head = NULL;
  int to_free_head = 1;


  ctx = http_cli_std_init (url);
  ctx->hcctx_method = HC_METHOD_GET;
  http_cli_set_ua_id (ctx, ua_id);

  if (BOX_ELEMENTS (args) > 1)
    {
      caddr_t uid = bif_string_or_null_arg (qst, args, 1, me);
      caddr_t pwd = bif_string_or_null_arg (qst, args, 2, me);
      if (uid && pwd)
	http_cli_init_std_auth (ctx, uid, pwd);
    }

  if (BOX_ELEMENTS (args) > 3)
    {
      caddr_t method = bif_string_or_null_arg (qst, args, 3, me);
      if (method)
	{
	  if (!stricmp (method, "GET"))
	    meth = HC_METHOD_GET;
	  else if (!stricmp (method, "POST"))
	    meth = HC_METHOD_POST;
	  else if (!stricmp (method, "HEAD"))
	    meth = HC_METHOD_HEAD;
	  else if (!stricmp (method, "PUT"))
	    meth = HC_METHOD_PUT;
	  http_cli_set_method (ctx, meth);
	}
    }
  if (BOX_ELEMENTS (args) > 4)
    {
      http_hdr = bif_string_or_null_arg (qst, args, 4, me);
      if (http_hdr)
        http_cli_add_req_hdr (ctx, http_hdr);
    }
  if (BOX_ELEMENTS (args) > 5)
    {
      body = bif_string_or_null_arg (qst, args, 5, me);
      if (body)
	{
	  session_buffered_write (ctx->hcctx_req_body, body, box_length (body) - 1);
	  if (meth == HC_METHOD_POST && (!http_hdr ||
              !nc_strstr ((unsigned char *) http_hdr, (unsigned char *) "Content-Type:")))
	    http_cli_set_req_content_type (ctx, (caddr_t)"application/x-www-form-urlencoded");
	}
    }
#ifdef _SSL
  if (BOX_ELEMENTS (args) > 6)
    {
      caddr_t cert = bif_string_or_null_arg (qst, args, 6, me);
      http_cli_ssl_cert (ctx, cert);
      if (BOX_ELEMENTS (args) > 7)
	http_cli_ssl_cert_pass (ctx, bif_string_or_null_arg (qst, args, 7, me));
    }
  else if (!strnicmp (url, "https://", 8))
    {
      http_cli_ssl_cert (ctx, (caddr_t)"1");
    }
#endif
  if (BOX_ELEMENTS (args) > 9)
    {
      int isnull = 0;
      uint32 time_out = (uint32) bif_long_or_null_arg (qst, args, 9, me, &isnull);
      if (!isnull)
        ctx->hcctx_timeout = time_out;
    }

  if (NULL != (ret = http_client_cache_get ((query_instance_t *)qst, url, http_hdr, body, args, 8)))
    return ret;  

  IO_SECT(qst);

#ifdef DEBUG
  fprintf (stderr, "bif_http_client: State: %d\n", ctx->hcctx_state);
#endif

  if (!http_cli_main (ctx))
    ret = box_copy_tree (ctx->hcctx_resp_body);

#ifdef DEBUG
  fprintf (stderr, "bif_http_client: State: %d\n", ctx->hcctx_state);

  fprintf (stderr, "bif_http_client: Releasing the client context\n");
#endif

  _err_ret = http_cli_get_err (ctx);

  if (_err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
      _err_ret = box_copy_tree (_err_ret);
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

  if (BOX_ELEMENTS (args) > 8 && ssl_is_settable (args[8]))
    {
      qst_set (qst, args[8], (caddr_t) head);
      to_free_head = 0;
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

void
bif_http_client_init (void)
{
  bif_define_typed ("http_client_internal", bif_http_client, &bt_varchar);
}
