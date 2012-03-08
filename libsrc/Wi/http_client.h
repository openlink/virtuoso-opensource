/*
 *  $Id$
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
 */

#ifndef __HTTP_CLIENT_H__
#define __HTTP_CLIENT_H__

#ifdef _SSL
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/pkcs12.h>
#include <openssl/safestack.h>
#include <openssl/bio.h>
#include <openssl/asn1.h>
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

#ifndef _WI_STRLIKE_H
#include "strlike.h"
#endif


#define HC_AUTH_DIGEST 1	/* Digest */
#define HC_AUTH_BASIC  2	/* Basic */

/* Hook dispatch queues */
/*
 * TODO:
 * Add separate hooks for transfer encoding/decoding
 *
 *
*/
#define HTTP_CLI_NO_HOOKS 11

#define HC_HTTP_TO         0
#define HC_HTTP_ERROR      1
#define HC_HTTP_CONN_PRE   2
#define HC_HTTP_CONN_ERR   3
#define HC_HTTP_CONN_POST  4
#define HC_HTTP_REQ_PRE    5
#define HC_HTTP_REQ_POST   6
#define HC_HTTP_RESP_MALF  7
#define HC_HTTP_READ_ERR   8
#define HC_HTTP_WRITE_ERR  9

#define HC_CTX_DESTRUCTOR 10 /* context destructor hook */

/* Hook/event handler return values */

#define HC_RET_RETRY      1 /* Retry connection */
#define HC_RET_OK         0
#define HC_RET_ERR_CONT  -1 /* Continue hook function dispatch */
#define HC_RET_ERR_ABORT -2 /* Abort hook function dispatch */

/* Flags */

#define HC_F_ABORT      (uint32)0x0001
#define HC_F_RETRY      (uint32)0x0002
#define HC_F_CONNECTED  (uint32)0x0010
#define HC_F_REQ_SENT   (uint32)0x0020
#define HC_F_REPLY_READ (uint32)0x0040
#define HC_F_HDRS_READ  (uint32)0x0080
#define HC_F_BODY_READ  (uint32)0x0100

/* States */

#define HC_STATE_INIT 1
#define HC_STATE_REQ_SENT 2
#define HC_STATE_READ_RESP 3
#define HC_STATE_READ_RESP_HDRS 5
#define HC_STATE_READ_RESP_BODY 6
#define HC_STATE_ERR_CLEANUP 666

/* event handler queue for HTTP replies */

typedef struct http_resp_evt_q_s
{
  int hreq_http_resp;
  dk_set_t hreq_evt_q;
} http_resp_evt_q_t;

/* offsets from http_methods described in http.c */
#define HC_METHOD_NONE 0
#define HC_METHOD_GET  1
#define HC_METHOD_HEAD 2
#define HC_METHOD_POST 3
#define HC_METHOD_PUT  4
#define HC_METHOD_DELETE 5
#define HC_METHOD_OPTIONS 6

/* WebDAV methods */
#define HC_METHOD_PROPFIND 	7
#define HC_METHOD_PROPPATCH 	8
#define HC_METHOD_COPY 		9
#define HC_METHOD_MOVE 		10
#define HC_METHOD_LOCK 		11
#define HC_METHOD_UNLOCK 	12
#define HC_METHOD_MKCOL 	13

#define HA_ALGORITHM_MD5      1
#define HA_ALGORITHM_MD5_SESS 2

#define HA_QOP_NONE     0
#define HA_QOP_AUTH     1
#define HA_QOP_AUTH_INT 2

typedef struct http_cli_proxy_s
{
  caddr_t hcp_proxy;
  int 	  hcp_socks_ver;
  int 	  hcp_resolve;
  caddr_t hcp_user;
  caddr_t hcp_pass;
} http_cli_proxy_t;

/* HTTP Client context */

typedef struct http_cli_ctx_s
{
  int               hcctx_state;
  uint32            hcctx_flags;
  int               hcctx_auth_type; /* 1 - DIGEST, 2 - BASIC */
  int               hcctx_nc;
  int               hcctx_http_maj;
  int               hcctx_http_min;
  int               hcctx_respcode;
  int               hcctx_is_chunked;
  int               hcctx_is_gzip;
  int               hcctx_keep_alive;
  int               hcctx_close;
  int               hcctx_retry_count;
  int               hcctx_retry_max;
  int               hcctx_method;
  int               hcctx_algorithm;
  long              hcctx_req_start_time;
  long              hcctx_req_time_msec;
  long              hcctx_peer_max_timeout;
  int 		    hcctx_no_cached;
  uint32 	    hcctx_timeout;
  caddr_t           hcctx_digest_uri;
  caddr_t           hcctx_qop;
  caddr_t           hcctx_ua_id;
  caddr_t           hcctx_host;
  caddr_t           hcctx_domain;
  caddr_t           hcctx_realm;
  caddr_t           hcctx_nonce;
  caddr_t           hcctx_cnonce;
  caddr_t           hcctx_opaque;
  caddr_t           hcctx_stale;
  caddr_t           hcctx_user;
  caddr_t           hcctx_pass;
  caddr_t           hcctx_url;
  caddr_t           hcctx_uri;
  caddr_t           hcctx_err;
  http_cli_proxy_t  hcctx_proxy;
  caddr_t           hcctx_req_ctype;
  int               hcctx_http_out_cached;
  dk_session_t *    hcctx_http_out;
  dk_session_t *    hcctx_pub_req_hdrs;
  dk_session_t *    hcctx_prv_req_hdrs;
  dk_session_t *    hcctx_req_body;
  char		    hcctx_resp_content_is_strses;
  char		    hcctx_resp_content_len_recd;
  long              hcctx_resp_content_length;
  caddr_t           hcctx_response;
  dk_set_t          hcctx_resp_hdrs;
  caddr_t           hcctx_resp_body;
#ifdef _SSL
  SSL *             hcctx_ssl;
  SSL_CTX *         hcctx_ssl_ctx;
  SSL_METHOD *      hcctx_ssl_method;
  caddr_t           hcctx_pkcs12_file;
  caddr_t           hcctx_cert_pass;
  caddr_t           hcctx_ca_certs;
  char 		    hcctx_ssl_insecure;
#endif
  dk_set_t          hcctx_resp_evts;                 /* HTTP Resp evt queues */
  int               hcctx_resp_evt_ret;
  dk_set_t          hcctx_hooks [HTTP_CLI_NO_HOOKS]; /* hook dispatch queues */
  int               hcctx_hook_ret;
  caddr_t *	    hcctx_qst;
  int 		    hcctx_redirects;
} http_cli_ctx;


typedef int HC_RET;

typedef HC_RET (*http_cli_handler_fn)(http_cli_ctx *,
				      caddr_t params,
				      caddr_t ret_val,
				      caddr_t err_ret);

/*
 * event handler frame
 * fn - function pointer
 * pm - address of params to the handler
 * rt - address of return value
 * er - error return
 *
 *
*/

typedef struct http_cli_handler_frame_s
{
  http_cli_handler_fn fn;
  caddr_t pm;
  caddr_t rt;
  caddr_t er;
} http_cli_handler_frame_t;

HC_RET http_cli_hook_dispatch (http_cli_ctx *, int);
HC_RET http_cli_resp_evt_dispatch (http_cli_ctx *, int);
http_cli_ctx * http_cli_ctx_init (void);
HC_RET http_cli_ctx_free (http_cli_ctx *);
void http_cli_inst_hook (http_cli_ctx *, int, http_cli_handler_frame_t *);
void http_cli_push_resp_evt (http_cli_ctx *, int, http_cli_handler_frame_t *);
char* http_cli_get_method_string (http_cli_ctx *);
char* http_cli_get_resp_hdr (http_cli_ctx *, char *);
HC_RET http_cli_connect (http_cli_ctx *);
HC_RET http_cli_send_req (http_cli_ctx *);
HC_RET http_cli_read_resp (http_cli_ctx *);
HC_RET http_cli_parse_resp_hdr (http_cli_ctx *, char*, int);
HC_RET http_cli_read_resp_hdrs (http_cli_ctx *);
HC_RET http_cli_read_resp_body (http_cli_ctx *);
void http_cli_calc_md5 (caddr_t, caddr_t, int);
caddr_t http_cli_auth_new_cnonce (void);
HC_RET http_cli_init_std_auth (http_cli_ctx *, caddr_t, caddr_t);
HC_RET http_cli_calc_auth_digest (http_cli_ctx *, caddr_t, caddr_t, caddr_t);
HC_RET http_cli_calc_auth_basic (http_cli_ctx *, caddr_t, caddr_t, caddr_t);
char* next_delim (char*, char*);
char* skip_attr (char*, char*);
char* skip_lwsp (char*, char*);
char* str_end (char*, char*);
HC_RET http_cli_parse_authorize_headers (http_cli_ctx *);
HC_RET http_cli_std_handle_auth (http_cli_ctx *, caddr_t, caddr_t, caddr_t);
http_cli_ctx *http_cli_std_init (char *, caddr_t *);
HC_RET http_cli_std_hdrs (http_cli_ctx *);
HC_RET http_cli_add_req_hdr (http_cli_ctx *, char *);
HC_RET http_cli_main (http_cli_ctx *);
HC_RET http_cli_send_request (http_cli_ctx *);
HC_RET http_cli_read_response (http_cli_ctx *);
HC_RET http_cli_set_http_10 (http_cli_ctx *);
HC_RET http_cli_set_http_11 (http_cli_ctx *);
HC_RET http_cli_set_auth (http_cli_ctx *, caddr_t, caddr_t);
HC_RET http_cli_set_target_host (http_cli_ctx *, caddr_t);
HC_RET http_cli_set_req_content_type (http_cli_ctx *, caddr_t);
HC_RET http_cli_set_retries (http_cli_ctx *, int);
HC_RET http_cli_set_ua_id (http_cli_ctx *, caddr_t);
HC_RET http_cli_set_authtype (http_cli_ctx *, int);
HC_RET http_cli_set_method (http_cli_ctx *, int);
caddr_t http_cli_get_err (http_cli_ctx *);
HC_RET http_cli_ssl_cert (http_cli_ctx *, caddr_t);
HC_RET http_cli_ssl_cert_pass (http_cli_ctx *, caddr_t);
int http_cli_target_is_proxy_exception (char *);

#endif /* __HTTP_CLIENT_H__ */
