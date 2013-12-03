/*
 *  http.h
 *
 *  $Id$
 *
 *  Definitions for HTTP server
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

#ifndef _HTTP_H
#define _HTTP_H

#include "Dk.h"
#include "Dk/Dksestcp.h"

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
#endif

#ifndef _WI_STRLIKE_H
#include "strlike.h"
#endif

#include "sqlnode.h"

#ifdef VIRTUAL_DIR
typedef struct ws_http_map_s
  {
    caddr_t 	hm_host;
    caddr_t 	hm_lhost;
    caddr_t	hm_p_path;
    caddr_t	hm_l_path;
    int		hm_is_dav;
    int 	hm_browseable;
    caddr_t	hm_def_page;
    caddr_t 	hm_sec;
    caddr_t	hm_realm;
    caddr_t	hm_afn;
    caddr_t	hm_pfn;
    caddr_t	hm_vsp_uid;
    caddr_t	hm_soap_uid;
    int		hm_ses_vars;
    caddr_t *   hm_soap_opts;
    caddr_t *	hm_auth_opts;
    caddr_t *	hm_opts;
    int 	hm_no_inherit;
    int		hm_xml_template;
    int		hm_executable;
    int		hm_exec_as_get;
    caddr_t 	hm_htkey;
    caddr_t     hm_url_rewrite_rule;
    int		hm_url_rewrite_keep_lpath;
    id_hash_t *	hm_cors;
    int 	hm_cors_restricted;
    caddr_t     hm_expiration_fn;
  } ws_http_map_t;
#endif

#define HTTP_MAX_METHOD 20

typedef struct ws_connection_s
  {
    dk_session_t * 	ws_session;
    int			ws_ses_trap;
    dk_session_t * 	ws_req_log;
    client_connection_t *ws_cli;
    dk_session_t * 	ws_strses;
    du_thread_t *	ws_thread;
    caddr_t		ws_req_line;
    caddr_t *		ws_lines;
    caddr_t *		ws_path;
    caddr_t *		ws_params;
    caddr_t *		ws_stream_params;
    dk_session_t *	ws_req_body;
    int 		ws_req_len;
    int			ws_method;
    char		ws_method_name[20];
    char 		ws_proto[20];
    int			ws_proto_no;
    caddr_t 		ws_header;
    caddr_t		ws_file;
    caddr_t		ws_path_string;
    caddr_t 		ws_resource;
    caddr_t		ws_status_line;
    int			ws_status_code;
    int			ws_try_pipeline;
#ifdef VIRTUAL_DIR
    caddr_t *		ws_p_path;
    caddr_t		ws_p_path_string;
    ws_http_map_t * 	ws_map;
#endif
#ifdef _IMSG
    int			ws_port;
#endif
#ifdef BIF_XML
    caddr_t		ws_xslt_url;
    caddr_t		ws_xslt_params;
    unsigned long 	ws_flushed;
#endif
    caddr_t		ws_client_ip;
    char 		ws_forward;
    wcharset_t *	ws_charset;
    int			ws_ignore_disconnect;
    caddr_t 		ws_store_in_cache;     /* the url to be cached */
    int			ws_proxy_request;
    OFF_T		ws_body_limit;
#ifdef _SSL
    SSL_CTX *		ws_ssl_ctx;
#endif
    char  		ws_options[HTTP_MAX_METHOD];
    char		ws_limited;
    char 		ws_thr_cache_clear;
  } ws_connection_t;

#define WS_CHARSET(ws, qst) \
        (ws ? ws->ws_charset : (qst ? QST_CHARSET (qst) : (wcharset_t *)(NULL)))

/* Cached proxy connections record */
typedef struct ws_cached_connection_s
  {
    caddr_t 		host;		/* target host:port value */
    dk_session_t * 	ses;		/* cached session */
    unsigned long	hit;		/* last hit in msecs */
    int			timeout; 	/* max keep-alive timeout value */
  } ws_cached_connection_t;

typedef struct ws_acl_s
  {
    long 	ha_order;		/* ordinary position */
    caddr_t 	ha_mask; 		/* client address pattern */
    int		ha_flag;		/* deny/allow 1/0 */
    caddr_t 	ha_dest;		/* destination address pattern */
    long	ha_obj;			/* sublist item */
    int 	ha_rw;			/* sublist flag */
    float 	ha_rate;		/* rate speed */
    id_hash_t *	ha_cli_ip_r;		/* hash client IP'S reads*/
    id_hash_t *	ha_cli_ip_w;		/* hash client IP'S writes */
    id_hash_t * ha_hits;
    OFF_T	ha_limit;
  } ws_acl_t;

typedef struct acl_hit_s
  {
    int64 ah_initial; /* initial time */
    long ah_count;    /* hits since initial */
    float ah_avg;     /* for statistics */
  } acl_hit_t;

extern long tws_cached_connection_hits;
extern long tws_cached_connection_miss;
extern long tws_cached_connections_in_use;
extern long tws_cached_connections;
extern long  tws_bad_request;
#define WM_GET 1
#define WM_POST 2
#define WM_UNKNOWN 3
#define WM_ERROR 4 /* comment out this definition to stop sending 401 Bad request */
#define WM_HEAD 5
#define WM_OPTIONS 6

#define WM_URIQA_FIRST 100
#define WM_URIQA_MGET 100
#define WM_URIQA_MPUT 101
#define WM_URIQA_MDELETE 102
#define WM_URIQA_LAST 199

#define WM_IS_URIQA(opcode) ((WM_URIQA_FIRST <= (opcode)) && (WM_URIQA_LAST >= (opcode)))

#define PATH_ELT_MAX_CHARS 512

long ws_content_length (caddr_t * head);
char * ws_header_field (caddr_t * head, const char * f, char * deflt);
caddr_t ws_mime_header_field (caddr_t * head, char * f, char *subf, int initial_mode);
void ws_keep_alive_ready (dk_session_t * ses);
int http_method_id (char * method);
char * http_get_method_string (int id);



extern long tws_connections;
extern long tws_requests;
extern long tws_1_1_requests;

extern long tws_slow_keep_alives;
extern long tws_immediate_reuse;
extern long tws_slow_reuse;
extern long tws_accept_queued;
extern long tws_accept_requeued;
extern long tws_keep_alive_ready_queued;
extern long tws_early_timeout;
extern long tws_disconnect_while_check_in;
extern long tws_done_while_check_in;
extern long tws_cancel;

extern char * http_port;
extern char * https_port;
extern char * https_cert;
extern char * https_key;
extern char * https_extra;
extern int32 https_client_verify;
extern int32 https_client_verify_depth;
extern char * https_client_verify_file;
extern char * https_client_verify_crl_file;
extern int32 http_threads;
extern int32 ini_http_threads;
extern int32 http_keep_alive_timeout;
extern int32 http_max_keep_alives;
extern int32 http_max_cached_proxy_connections;
extern int32 http_proxy_connection_cache_timeout;
extern int32 http_thread_sz;
extern char * dav_root;
extern char * http_server_id_string;
extern char * www_maintenance_page;
extern char * http_proxy_address;

void http_timeout_keep_alives (int must_kill);
void ws_keep_alive_ready (dk_session_t * ses);
void ws_set_path_string (ws_connection_t * ws, int dir);
dk_session_t * http_dks_connect (char * host2, caddr_t * err_ret);
int dks_read_line (dk_session_t * ses, char *buf, int max);
caddr_t box_line (char * line, int len);
caddr_t int_client_ip (query_instance_t * qi, long dns_name);

caddr_t ws_soap (ws_connection_t * ws, int soap_version, caddr_t soap_method);
caddr_t ws_soap_http (ws_connection_t * ws);
caddr_t ws_soap_sdl_services (ws_connection_t *ws);
caddr_t ws_soap_wsdl_services (ws_connection_t *ws, caddr_t doc);
caddr_t ws_dav (ws_connection_t * ws, query_t * http_call);

caddr_t http_read_chunked_content (dk_session_t *ses, caddr_t *err_ret, char *uri, int allow_ses);
/* use cached proxy connections in http_get and SOAP client */
#define _USE_CACHED_SES

#ifdef _USE_CACHED_SES
dk_session_t * http_cached_session (char * host);
void http_session_used (dk_session_t * ses, char * host, long peer_max_timeout);
#endif

void connection_set (client_connection_t *cli, caddr_t name, caddr_t val);


/* values of dks_ws_status */

#define DKS_WS_ACCEPTED 0 /* accepted, reading init request, not checked into the select yet */
#define DKS_WS_STARTED 1 	/* checked in for disconnect watch but not in select yet */
#define DKS_WS_RUNNING 2	/* there is a running thread associated with this session. The session is in the select to detect async cancellation */
#define DKS_WS_KEEP_ALIVE 3	/* the connection is waiting for next request, no computation active */
#define DKS_WS_INPUT_PENDING 4	/* there is a running ws and input has been detected and the session has been checked out of the select, to be read by the ws thread when it is done with current business */
#define DKS_WS_DISCONNECTED 5	/*  There is a running ws and an async cancellation by client has been detected. The connection is checked out of the select and the ws is expected to close it */
#define DKS_WS_FLUSHED	6
#define DKS_WS_CLIENT 7
#define DKS_WS_CACHED 8

#ifdef VIRTUAL_DIR
#define WS_USER_NAME(ws) (ws && ws->ws_map && \
    			  ws->ws_map->hm_vsp_uid && \
			  IS_STRING_DTP (DV_TYPE_OF (ws->ws_map->hm_vsp_uid)) && \
			  stricmp (ws->ws_map->hm_vsp_uid, "DBA") ? ws->ws_map->hm_vsp_uid : "WS")

#define WS_SOAP_NAME(ws) (ws && ws->ws_map && \
    			  ws->ws_map->hm_soap_uid && \
			  IS_STRING_DTP (DV_TYPE_OF (ws->ws_map->hm_soap_uid))  ? \
			  (strcmp (ws->ws_map->hm_soap_uid, "dba") ? ws->ws_map->hm_soap_uid : "DBA") : "SOAP")

char * ws_usr_qual (ws_connection_t * ws, int is_soap);
#else
#define WS_USER_NAME(ws) "WS"
#define WS_SOAP_NAME(ws) "SOAP"
#define ws_usr_qual(ws, is_soap)  "WS"
#endif

extern void dks_sqlval_esc_write (caddr_t *qst, dk_session_t *out, caddr_t val, wcharset_t *tgt_carset, wcharset_t *src_charset, int dks_esc_mode);
extern void http_value_esc (caddr_t *qst, dk_session_t *out, caddr_t val, char *tag, int dks_esc_mode);
#if 0
#define http_trace(a) do { printf ("HTTP trace: "); printf a; } while (0)
#else
#define http_trace(a)
#endif

extern dk_session_t *http_session_arg (caddr_t * qst, state_slot_t ** args, int nth, const char * func);
extern dk_session_t *http_session_no_catch_arg (caddr_t * qst, state_slot_t ** args, int nth, const char * func);

/* dks_esc.c */

/* The order of the values in this enumeration should match
the order of columns in dks_charclasses, file dks_esc.c */
#define DKS_ESC_NONE		0x00
#define DKS_ESC_PTEXT		0x01
#define DKS_ESC_SQATTR		0x02
#define DKS_ESC_DQATTR		0x03
#define DKS_ESC_COMMENT		0x04
#define DKS_ESC_CDATA		0x05
#define DKS_ESC_URI		0x06
#define DKS_ESC_DAV		0x07
#define DKS_ESC_URI_RES		0x08
#define DKS_ESC_URI_NRES	0x09
#define DKS_ESC_TTL_SQ		0x0A
#define DKS_ESC_TTL_DQ		0x0B
#define DKS_ESC_TTL_IRI		0x0C
#define DKS_ESC_JSWRITE_SQ	0x0D
#define DKS_ESC_JSWRITE_DQ	0x0E
#define COUNTOF__DKS_ESC	0x0F

#define DKS_ESC_COMPAT_HTML	0x100
#define DKS_ESC_COMPAT_SOAP	0x200

extern unsigned char dks_esc_char_props[0x100];
typedef unsigned char dks_charclass_props_t[COUNTOF__DKS_ESC];
extern dks_charclass_props_t dks_charclasses['R'+1-'>'];
#define DKS_ESC_CHARCLASS_ACTION(wc,mode) (dks_charclasses[((wc & ~0xff) ? 0 : (dks_esc_char_props[wc] - '>'))][mode])

#define isdatechar(c) (('\0' != (c)) && (NULL != strchr ("0123456789 GMTZ:-", (c))))
#define isfloatchar(c) (('\0' != (c)) && (NULL != strchr ("0123456789eE+-.", (c))))
/* This was: #define isplainURIchar(c) (('\0' != (c)) && ('/' != (c)) && ('?' != (c)) && ('=' != (c)) && ('#' != (c))) */
#define isplainURIchar(c) ('\0' == DKS_ESC_CHARCLASS_ACTION((unsigned)(c), DKS_ESC_URI))

extern void
dks_esc_write (dk_session_t * ses, const char * str, size_t len,
  wcharset_t * tgt_charset, wcharset_t * src_charset, int dks_esc_mode);

extern void
dks_wide_esc_write (dk_session_t * ses, wchar_t * wstr, int len,
  wcharset_t * tgt_charset, int dks_esc_mode);

caddr_t ws_get_opt (caddr_t * opts, char *opt_name, char * def);

void session_buffered_read_n (dk_session_t * ses, char *buf, int max, int *inx);

extern char base64_vec[];
extern char base64url_vec[];
#define B64_CANON base64_vec
#define B64_URL base64url_vec

size_t decode_base64_impl (char * src, char * end, char * table);
size_t encode_base64_impl (char * input, char * output, size_t len, char * table);
#define decode_base64(src,end) decode_base64_impl ((src), (end), B64_CANON)
#define encode_base64(input,output,len) encode_base64_impl ((input), (output), (len), B64_CANON)

void ws_strses_reply (ws_connection_t * ws, const char * volatile code);
void ws_write_failed (ws_connection_t * ws);
int ws_cache_check (ws_connection_t * ws);
void ws_cache_store (ws_connection_t * ws, int store);

extern FILE *debug_log;
extern dk_mutex_t * ws_http_log_mtx;

extern int http_ses_size;
extern caddr_t dns_host_name;
void http_threads_allocate (int http_threads);
caddr_t ws_soap_get_url (ws_connection_t *ws, int full_path);
caddr_t ws_http_error_header (int code);
caddr_t http_client_cache_get (query_instance_t * qi, caddr_t url, caddr_t header, caddr_t body, state_slot_t ** args, int arg_pos);
void http_client_cache_register (query_instance_t * qi, caddr_t url, caddr_t header, caddr_t req_body, caddr_t * head, caddr_t body);
void zlib_box_gzip_uncompress (caddr_t src, dk_session_t * out, caddr_t * err_ret);

extern caddr_t http_sys_find_best_accept_impl (caddr_t * qst, state_slot_t *ret_val_ssl, caddr_t accept_strg, caddr_t *supp, const char *fname);
void ws_http_error (ws_connection_t * ws, const caddr_t code, const caddr_t message, const caddr_t uri, const caddr_t path);


#ifdef _SSL
typedef enum {
  	HTTPS_VERIFY_NONE = 0,
	HTTPS_VERIFY_REQUIRED = 1,
	HTTPS_VERIFY_OPTIONAL = 2,
	HTTPS_VERIFY_OPTIONAL_NO_CA = 3
} https_verify_t;

#endif
extern char * http_cli_proxy_server;
int http_cli_target_is_proxy_exception (char *);
void ws_http_body_read (ws_connection_t * ws, dk_session_t **out);

#define WS_CE_NONE 1
#define WS_CE_CHUNKED 2
#define WS_CE_GZIP 3

#endif /* _HTTP_H */
