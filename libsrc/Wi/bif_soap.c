/*
 *  bif_soap.c
 *
 *  $Id$
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
#include <ctype.h>
#include <limits.h>

#include "Dk.h"
#include "Dk/Dksestcp.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "http.h"
#include "sqlbif.h"
#include "xml.h"
#include "xmltree.h"
#include "libutil.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "security.h"
#include "bif_text.h"
#include "statuslog.h"
#include "http_client.h"
#include "sqltype.h"
#include "datesupp.h"

#include "soap.h"
#ifdef _SSL
#include "xmlenc.h"
#else
#define WSS_DSIG_URI	"http://www.w3.org/2000/09/xmldsig#"
#define WSS_XENC_URI	"http://www.w3.org/2001/04/xmlenc#"
#define WSS_WSS_URI	"http://schemas.xmlsoap.org/ws/2002/07/secext"
#define WSS_WSU_URI 	"http://schemas.xmlsoap.org/ws/2002/07/utility"
#endif

#ifdef SOAP_USES_TYPES
#error "soaptypes build option is no longer needed in $HOME/Makeconfig"
#endif

#define SOAP_USES_TYPES ((soap_version) >= 11 && (!ctx || !ctx->def_enc))

#define WSP_URI		"http://schemas.xmlsoap.org/ws/2002/12/policy"
#define WSRM_URI 	"http://schemas.xmlsoap.org/ws/2003/03/rm"
#define WSA_URI 	"http://schemas.xmlsoap.org/ws/2003/03/addressing"
#define WSA_URI_200403 	"http://schemas.xmlsoap.org/ws/2004/03/addressing"

#define _USE_CACHED_SES

#define UDDI_NS "urn:uddi-org:api"
#define UDDI_OPERATOR_ID "UDDI_operator"
#define UDDI_DEFAULT_OPERATOR "OpenLink Virtuoso"

#define ADD_CUSTOM_SCH 2
#define ADD_ALL_SCH    1

#define MAX_SOAP_PORTS 3
static int soap_ports [MAX_SOAP_PORTS] = {0, SOAP_MSG_LITERAL, SOAP_MSG_HTTP}; /* Needs to be in sync with above */


#define SOAP_VOID_TYPE "__VOID__"
#define SOAP_ANY_TYPE  "__ANY__"
#define SOAP_XML_TYPE  "__XML__"


static char *uddi_errors[] = {
  "10500", "E_fatalError",
  "10110", "E_authTokenExpired",
  "10120", "E_authTokenRequired",
  "10160", "E_accountLimitExceeded",
  "10400", "E_busy",
  "20100", "E_categorizationNotAllowed",
  "10210", "E_invalidKeyPassed",
  "20000", "E_invalidCategory",
  "10220", "E_invalidURLPassed",
  "10310", "E_keyRetired",
  "10060", "E_languageError",
  "10020", "E_nameTooLong",
  "10130", "E_operatorMismatch",
  "00000", "E_success",
  "10030", "E_tooManyOptions",
  "10040", "E_unrecognizedVersion",
  "10150", "E_unknownUser",
  "10050", "E_unsupported",
  "10140", "E_userMismatch",
   NULL  , NULL};

typedef struct soap_ctx_s
  {
    int    	soap_version;  	/* use the SOAP version  1.0 eq. 10 */
    int    	add_schema;    	/* add schema namespace to the elements */
    int    	add_type;      	/* add the schema dt to the elements */
    const char 	*req_resp_namespace;    /* request/response namespace */
    int    	dks_esc_compat;	/* 0 or DKS_ESC_COMPAT_SOAP flag for dks_esc_write */
    int    	literal;       	/* encoding type */
    int    	wrapped;	/* doc/lit style */
    int    	element_form;  	/* qualified or not */
    int    	def_enc;	/* default style for encoding */
    dk_set_t 	ns;          	/* namespaces used */
    dk_set_t 	types_set;   	/* used in RPC encoding to keep the namespaces */
    dk_set_t 	ns_set;      	/* namespaces declarations for response  */
    caddr_t * 	attachments; 	/* input attachments */
    dk_set_t 	o_attachments; 	/* output attachments */
    int    	attr;	  	/* true if printing an attribute */
    caddr_t *	opts;
    int 	faults;
    int 	con_encoding;	/* NONE, DIME or MIME */
    int 	raw_attachments;
    int 	must_understand;
    char * 	soap_actor;
    caddr_t 	error_message;
    caddr_t * 	custom_schema;
    caddr_t  	role_url;
    int  	is_router;
    caddr_t *   not_understood;
    caddr_t *	qst;
    client_connection_t * cli;
#ifdef _SSL
    wsse_ser_ctx_t wsse_ctx;
    int		is_wsse;
#endif
  } soap_ctx_t;

typedef struct soap_call_ctx_s
  {
    int              sc_version;       /* soap version */
    int              sc_debug_mode;
    caddr_t *        sc_debug_out;
    int              sc_use_dime;
    int              sc_use_mime;
    int 	     sc_use_xmlrpc;   /* make XMLRPC call instead of SOAP */
    int   	     sc_out_all;
    int	             sc_return_fault;
    int	             sc_return_req;
    caddr_t *        sc_dl_mode;
    long             sc_dl_val;
    int 	     sc_wss_security;      /* 0 - none, 1 - wss */
    caddr_t 	     sc_wss_key;       /* key instance */
    caddr_t 	     sc_wss_template;  /* security template */
    caddr_t 	     sc_wss_ns;
    char *           sc_soap_action;
    char *           sc_method_uri;    /* method uri */
    char *           sc_method_name;   /* method name */
    caddr_t *        sc_params;
    caddr_t *        sc_header_params;
    soap_ctx_t *     sc_ser_ctx;       /* soap serialization context */
    http_cli_ctx *   sc_http_client;   /* http client context */
    dk_session_t *   sc_soap_out;      /* envelope building grounds */
    client_connection_t * sc_client;
  } soap_call_ctx_t;

typedef struct soap_wsdl_ns_s
  {
    caddr_t 	ns_uri;
    char    	ns_pref[10];
    dk_set_t 	ns_types;
    dk_set_t 	ns_elms;
    dk_set_t 	ns_imports;
    int      	ns_imported;
  } soap_wsdl_ns_t;

typedef struct soap_wsdl_type_s
  {
    caddr_t type_name;
    soap_wsdl_ns_t * type_ns;
    int type_is_elem;
    sql_class_t *type_udt;
    sql_type_t type_sqt;
  } soap_wsdl_type_t;

static id_hash_t * ht_soap_dt;
static id_hash_t * ht_soap_elt;
static id_hash_t * ht_soap_attr;
static id_hash_t * ht_soap_udt;
static id_hash_t * ht_soap_sup; /* SOAP UDT Published */

char * http_soap_client_id_string = "Virtuoso Soap Client";

#define HT_SOAP(i) (((i) > 0) ? ht_soap_elt : (((i) < 0) ? ht_soap_attr : ht_soap_dt))

#define PRINT_SPACE_B(ses, n)	{ \
  char __tmp[200]; \
  int __i = n > 0 ? (n - 1) * 2 : 0; \
  memset (__tmp, ' ', sizeof(__tmp)); \
  __tmp[__i%(sizeof(__tmp)-1)] = 0; \
  SES_PRINT(ses, __tmp); \
  }

#define SOAP_TAG_DT_CPX_CNT  W3C_2001_TYPE_SCHEMA_XSD ":complexContent"
#define SOAP_TAG_DT_RESTRICT W3C_2001_TYPE_SCHEMA_XSD ":restriction"
#define SOAP_TAG_DT_EXTENSION W3C_2001_TYPE_SCHEMA_XSD ":extension"
#define SOAP_TAG_DT_ELEMENT  W3C_2001_TYPE_SCHEMA_XSD ":element"
#define SOAP_TAG_DT_ATTR     W3C_2001_TYPE_SCHEMA_XSD ":attribute"
#define SOAP_ATTR_DT_ARRAY   SOAP_ENC_SCHEMA11 ":Array"
#define SOAP_ATTR_DT_STRUCT  SOAP_ENC_SCHEMA11 ":Struct"
#define soap_print_q_name(o,n,types_set) soap_print_q_name_1(o,n,0,"s:",types_set)
#define wsdl_print_q_name(o,n,types_set) soap_print_q_name_1(o,n,1,"s:",types_set)


static caddr_t soap_box_xml_entity_validating_1 (caddr_t *entity, caddr_t *err_ret, caddr_t type_ref, int elem, soap_ctx_t * ctx, sql_type_t * sqt);
#define soap_box_xml_entity_validating(entity, err_ret, type_ref, elem, ctx) \
  soap_box_xml_entity_validating_1 (entity, err_ret, type_ref, elem, ctx, NULL)

static void soap_print_box_validating (caddr_t box, const char * tag, dk_session_t *ses,
    caddr_t *err_ret, caddr_t type_ref, soap_ctx_t * ctx, int elem, int qualified, sql_type_t * check_sqt);
static int soap_print_xml_entity (caddr_t box, dk_session_t *ses, client_connection_t * cli);
static const char * xml_find_soapenc_attribute (caddr_t *entity, const char *name);
static void soap_udt_print_schema_fragment (sql_class_t *udt, dk_session_t *out, dk_set_t *types_set, int sp, soap_ctx_t *ctx);
static caddr_t *soap_xml_params_to_array (query_t *proc_qry, caddr_t *method,
    caddr_t *err_ret, caddr_t *call_text, caddr_t headers, caddr_t lines, soap_ctx_t * ctx, caddr_t *xml_tree);
static caddr_t soap_sqt_to_soap_type (sql_type_t *sqt, caddr_t soap_type, caddr_t * opts,
    const char * op_name, const char * fld_name);
static caddr_t * xml_find_schema_child (caddr_t *entity, const char *name, int nth);
static int soap_type_exists (caddr_t name, int elem);
void soap_mime_tree (ws_connection_t * ws, dk_set_t * set, caddr_t * err, int soap_version);
void soap_dime_tree (caddr_t body, dk_set_t * set, caddr_t * err);
static void soap_print_schema_fragment (caddr_t type_name, sql_type_t * sqt, dk_session_t *out, dk_set_t *types_set, int sp, soap_ctx_t *ctx);
void soap_mime_tree_ctx (caddr_t ctype, caddr_t body, dk_set_t * set, caddr_t * err, int soap_version, dk_set_t hdrs);

#define XML_ELEMENT_NAME(x) \
  ((char *)( ((x) && DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && ((caddr_t *)(x))[0] && ((caddr_t **)(x))[0][0]) ? ((caddr_t **)(x))[0][0] : NULL))

#define XML_ELEMENT_ATTR_COUNT(x) \
    ( \
      ( \
	(x) && \
	DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && \
	((caddr_t *)x)[0] && \
	DV_TYPE_OF (((caddr_t *)x)[0]) == DV_ARRAY_OF_POINTER \
      ) \
      ? \
      (BOX_ELEMENTS (((caddr_t *)x)[0]) - 1) / 2 \
      : \
      0 \
    )

#define XML_ELEMENT_ATTR_NAME(x, n) \
    ( \
      XML_ELEMENT_ATTR_COUNT(x) >= n \
      ? \
      ((caddr_t **)x)[0][n * 2 + 1] \
      : \
      NULL \
    )

#define XML_ELEMENT_ATTR_VALUE(x, n) \
    ( \
      XML_ELEMENT_ATTR_COUNT(x) >= n \
      ? \
      ((caddr_t **)x)[0][n * 2 + 2] \
      : \
      NULL \
    )

#define XML_ELEMENT_CHILD(x, n) \
  ( ((x) && DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && BOX_ELEMENTS (x) > (n + 1) && \
     ((caddr_t *)(x))[n + 1]) ? \
       ((caddr_t **)(x))[n + 1] : \
       NULL)

query_instance_t soap_fake_top_qi;

void
ses_sprintf (dk_session_t *ses, const char *fmt, ...)
{
  char buf[PAGE_SZ];
  int len;
  va_list list;
  va_start (list, fmt);
  len = vsnprintf (buf, sizeof (buf), fmt, list);
  va_end (list);
  SES_PRINT (ses, buf);
}

static caddr_t
ws_uddi_error (dk_session_t * ses, char *state, char *message, int soap_version)
{
  char tmp[4096];
  char * uddi_error = NULL, * uddi_code = uddi_errors[0];
  int ix = 0;
  caddr_t uddi_operator = NULL;
  strses_flush (ses);

  for (ix = 0, uddi_code = uddi_errors[0]; state && uddi_code;
      uddi_code = uddi_errors[ix], uddi_error = uddi_errors [ix+1], ix+=2)
    {
      if (!strcmp (uddi_code, state))
	  break;
    }

  if (!uddi_error)
    {
      uddi_error = uddi_errors[1];
      uddi_code = uddi_errors[0];
    }

  IN_TXN;
  uddi_operator = registry_get (UDDI_OPERATOR_ID);
  LEAVE_TXN;

  snprintf (tmp, sizeof (tmp),
      "<Envelope xmlns:SOAP=\"%s\">"
	      "<Body>"
		"<Fault>"
		  "<faultcode>Client</faultcode>"
	          "<faultstring>Client Error</faultstring>"
		  "<detail>"
		  "<dispositionReport generic=\"1.0\" operator=\"%s\" xmlns=\"\">"
		  "<result errno=\"%s\">"
		   "<errInfo errCode=\"%s\">"
		   "%s"
		   "</errInfo>"
		  "</result>"
		  "</dispositionReport>"
		  "</detail>"
	        "</Fault>"
	      "</Body>"
      "</Envelope>",
     SOAP_URI(soap_version),
     uddi_operator ? uddi_operator : UDDI_DEFAULT_OPERATOR,
     uddi_code,
     uddi_error,
     message);

  dk_free_box (uddi_operator);

  /*fprintf (stderr, "UDDI_ERROR: >\n %s\n", tmp);*/
  session_buffered_write (ses, tmp, strlen (tmp));
  return srv_make_new_error ("VSPRT", "SP001", "%s", message);
}


void mime_c_compose (soap_call_ctx_t ctx, caddr_t * input)
{
   static query_t * mime_call = NULL;
   local_cursor_t * lc = NULL;
   caddr_t replay = NULL, arg = NULL, hdr = NULL, err = NULL;

   if (!mime_call)
     mime_call = sql_compile_static ("DB.DBA.WS_MIME_RESP_C (?)", bootstrap_cli, &err, SQLC_DEFAULT);

   arg = box_copy_tree ((box_t) input);

   err = qr_quick_exec (mime_call, ctx.sc_client, NULL, &lc, 1,
       ":0", arg, QRP_RAW);

   if (err)
     srv_make_new_error ("42000", "SP035", "The Soap client MIME compose FAILED.");

   if (lc)
     {
       if (IS_BOX_POINTER (lc->lc_proc_ret))
	 {
	   caddr_t *proc_ret = (caddr_t *)lc->lc_proc_ret;
	   int nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);
	   if (nProcRet > 1)
	     {
	       caddr_t temp;
	       temp = proc_ret[1];
	       replay = ((caddr_t*)(temp))[0];
	       hdr = ((caddr_t*)(temp))[1];
	     }
	 }
     }

    SES_PRINT (ctx.sc_soap_out, replay);
    http_cli_set_req_content_type (ctx.sc_http_client, hdr);
}


void mime_compose (ws_connection_t * ws, caddr_t * input)
{
   static query_t * mime_call = NULL;
   local_cursor_t * lc = NULL;
   caddr_t replay = NULL, arg = NULL, hdr = NULL, err = NULL;

   if (!mime_call)
     mime_call = sql_compile_static ("DB.DBA.WS_MIME_RESP (?)", ws->ws_cli, &err, SQLC_DEFAULT);

   arg = box_copy_tree ((box_t) input);

   err = qr_quick_exec (mime_call, ws->ws_cli, NULL, &lc, 1,
       ":0", arg, QRP_RAW);

   if (err)
     {
       srv_make_new_error ("42000", "SP034", "The Soap MIME compose FAILED.");
       return;
     }

   if (lc)
     {
       if (IS_BOX_POINTER (lc->lc_proc_ret))
	 {
	   caddr_t *proc_ret = (caddr_t *)lc->lc_proc_ret;
	   int nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);
	   if (nProcRet > 1)
	     {
	       caddr_t temp;
	       temp = proc_ret[1];
	       replay = ((caddr_t*)(temp))[0];
	       hdr = ((caddr_t*)(temp))[1];
	     }
	 }
     }

   CATCH_WRITE_FAIL (ws->ws_session)
     {
       SES_PRINT (ws->ws_strses, replay);
       ws->ws_header = box_dv_short_string (hdr);
       session_flush_1 (ws->ws_strses);
       ws_strses_reply (ws, "HTTP/1.1 200 OK");
     }
   FAILED
     {
       ws_write_failed (ws);
     }
   END_WRITE_FAIL (ws->ws_session);
}

/* SOAP 1.1 error codes for faultcode element */
static const char *
soap_11_error (char * code, int strict)
{
  char c = code ? code[0] : 0;
  if (c == '3')
    return "SOAP:Client";
  else if (c == '4')
    return "SOAP:Server";
  else if (c == '1')
    return "SOAP:VersionMismatch";
  else if (c == '2')
    return "SOAP:MustUnderstand";
  return (strict ? "SOAP:Server" : code);
}

#define E_VER 1
#define E_UND 2
#define E_ENC 3
#define E_SND 4
#define E_RCV 5

#define ES_NO_PROC 1
#define ES_BAD_ARG 2

char *soap12_errors [] = {
"Receiver",
"VersionMismatch", 	/*1XX*/
"MustUnderstand",  	/*2XX*/
"Sender", 		/*3XX*/
"Receiver",		/*4XX*/
"DataEncodingUnknown"   /*5XX*/
};

char *soap12_sub_errors [] = {
  NULL,
  "rpc:ProcedureNotPresent", 	/*31X*/
  "rpc:BadArguments",	 	/*32X*/
  "enc:MissingID",
  "enc:DuplicateID",
  "enc:UntypedValue"
};


static caddr_t
ws_soap12_error (dk_session_t *ses, char *code, char *state, char *message, int *http_resp_code, soap_ctx_t * ctx)
{
  char tmp [4095];
  char errhdr [4095] = {0};
  int len = code ? (int) strlen (code) : 0;
  int mcode = (len > 0 ? code[0] : '3') - '0';
  int scode = (len > 1 ? code[1] : '0') - '0';
  char * code1 = soap12_errors[mcode], *code2 = soap12_sub_errors[scode];

  if (http_resp_code)
    {
      switch (mcode)
	{
	  case 3:
	      *http_resp_code = 400;
	      break;
	  default:
	      *http_resp_code = 500;
	}
    }

  if (mcode == 2 && ctx && ctx->not_understood)
    {
      char * name = XML_ELEMENT_NAME(ctx->not_understood);
      char * ns = name;
      char *colon = strrchr (name, ':');
      int off_c = (int) (colon - name);

      if (!colon)
	off_c = 0;
      else
	name = ++colon;

      snprintf (errhdr, sizeof (errhdr),
	 "<env:Header>"
	 "<env:NotUnderstood qname='nu:%s' xmlns:nu='%*.*s' />"
	 "</env:Header>", name, off_c, off_c, ns);
    }

  snprintf (tmp, sizeof (tmp),
      "<env:Envelope xmlns:env='%s' xmlns:rpc='%s' xmlns:enc='%s'>"
      "%s"
      "<env:Body>"
      "<env:Fault>"
      "<env:Code>"
        "<env:Value>env:%s</env:Value>"
        "%s%s%s"
      "</env:Code>"
      "<env:Reason><env:Text xml:lang='%s'>[Virtuoso SOAP server] ",
      SOAP_TYPE_SCHEMA12, SOAP_RPC_SCHEMA12, SOAP_ENC_SCHEMA12, errhdr,
      code1,
      code2 ? "<env:Subcode><env:Value>" : "",
      code2 ? code2 : "",
      code2 ? "</env:Value></env:Subcode>" : "",
      server_default_language_name);
  SES_PRINT (ses, tmp);

  dks_esc_write (ses, message, strlen (message), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);

  snprintf (tmp, sizeof (tmp),"</env:Text></env:Reason>"
      "</env:Fault>"
      "</env:Body>"
      "</env:Envelope>");
  SES_PRINT (ses, tmp);

  return srv_make_new_error ("VSPRT", "SP002", "%s", message);
}

static caddr_t
ws_soap_error (dk_session_t *ses, char *code, char *state, char *message,
    		int soap_version, int uddi, int *http_resp_code, soap_ctx_t * ctx)
{
  char tmp[1000];
  const char *code1 = soap_version == 1 ? code : soap_11_error (code, 1);
  strses_flush (ses);

  if (uddi)
    return ws_uddi_error (ses,state,message,soap_version);

  if (soap_version == 12)
    return ws_soap12_error (ses, code, state, message, http_resp_code, ctx);

  if (soap_version > 1 && http_resp_code)
    *http_resp_code = 500;

  snprintf (tmp, sizeof (tmp),
      "<SOAP:Envelope xmlns:SOAP=\"%s\">"
      "<SOAP:Body>"
      "<SOAP:Fault>"
      "<faultcode>%s</faultcode>"
      "<faultstring>[Virtuoso SOAP server] ",
      SOAP_URI(soap_version), code1);
  session_buffered_write (ses, tmp, strlen (tmp));
  dks_esc_write (ses, message, strlen (message), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
  snprintf (tmp, sizeof (tmp),"</faultstring>%s%s%s"
      "</SOAP:Fault>"
      "</SOAP:Body>"
      "</SOAP:Envelope>",
      (soap_version == 1 ? "<runcode>" : "<detail />"),
      (soap_version == 1 ? state : ""),
      (soap_version == 1 ? "</runcode>" : ""));
  session_buffered_write (ses, tmp, strlen (tmp));
  return srv_make_new_error ("VSPRT", "SP003", "%s", message);
}

static caddr_t
bif_soap_make_error (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t code = bif_string_arg (qst, args, 0, "soap_make_error");
  caddr_t state = bif_string_arg (qst, args, 1, "soap_make_error");
  caddr_t message = bif_string_arg (qst, args, 2, "soap_make_error");
  caddr_t err = NULL;
  int soap_version = 11, uddi = 0;
  dk_session_t *ses = NULL;

  if (BOX_ELEMENTS (args) > 3)
    soap_version = (int) bif_long_arg (qst, args, 3, "soap_make_error");
  if (BOX_ELEMENTS (args) > 4)
    uddi = (int) bif_long_arg (qst, args, 4, "soap_make_error");
  ses = strses_allocate ();
  err = ws_soap_error (ses, code, state, message, soap_version, uddi, NULL, NULL);
  dk_free_tree (err);
  if (!STRSES_CAN_BE_STRING (ses))
    {
      err = NULL;
      *err_ret = STRSES_LENGTH_ERROR ("soap_make_error");
    }
  else
    err = strses_string (ses);
  strses_free (ses);
  return err;
}

#define IS_COMPLEX_SQT(sqt) ((sqt).sqt_class || (sqt).sqt_dtp == DV_ARRAY_OF_POINTER)
#define IS_UDT_SQTP(sqt) ((sqt) && (sqt)->sqt_class)
#define IS_ARRAY_SQTP(sqt) ((sqt) && (sqt)->sqt_dtp == DV_ARRAY_OF_POINTER)
#define IS_UDT_XMLTYPE_SQT(sqt) (IS_UDT_SQTP(sqt) && (sqt)->sqt_class->scl_name && !stricmp ((sqt)->sqt_class->scl_name, "DB.DBA.XMLType"))

#define SOAP_OPT(nm, proc, inx, deflt)  soap_get_option (proc, (inx), SOAP_OPT_##nm, (deflt))
#define SOAP_PRINT(nm, out, proc, inx, deflt) { \
					         const char * value = SOAP_OPT(nm, proc, (inx), (deflt)); \
						 SES_PRINT (out, value); \
					      }

static const char *
soap_get_option (query_t * proc, int inx, const char *opt_name, const char * deflt)
{
  caddr_t *options = inx >= 0 ? (caddr_t *)proc->qr_parm_soap_opts [inx] : proc->qr_proc_soap_opts;
  int ix;

  DO_BOX (caddr_t, elm, ix, options)
    {
      if (!strcmp (elm, opt_name))
	{
	  return options[ix+1];
	}
      ix++;
    }
  END_DO_BOX;

  return deflt;
}


static const char *
extract_last_xml_name_part (const char *szFullName)
{
  if (szFullName)
    {
      char *szLastColon = strrchr (szFullName, ':');
      return szLastColon ? szLastColon + 1 : szFullName;
    }
  else
    return "";
}


static int
xml_is_space (caddr_t xml)
{
  if (xml && DV_TYPE_OF (xml) != DV_ARRAY_OF_POINTER)
    {
      char *ptr = (char *)xml;
      while (*ptr)
	if (!isspace (*ptr++))
	  return 0;
    }
  else if (xml)
    return 0;
  return 1;
}

static caddr_t
xml_element_nonspace_child (caddr_t xml, int n)
{
  if (xml && DV_TYPE_OF (xml) == DV_ARRAY_OF_POINTER)
    {
      int i;
      DO_BOX (caddr_t, child, i, ((caddr_t *)xml))
	{
	  if (i)
	    {
	      if (!xml_is_space (child))
		{
		  if (!n)
		    return child;
		  else
		    n--;
		}
	    }
	}
      END_DO_BOX;
    }
  return NULL;
}


char *
xml_find_attribute (caddr_t *entity, const char *szName, const char *szURI)
{
  int inx, uri_len = szURI ? (int) strlen (szURI) : 0;
  caddr_t *attrs;

  if (!entity || DV_TYPE_OF (entity) != DV_ARRAY_OF_POINTER)
    return NULL;

  attrs = (caddr_t *) entity[0];
  DO_BOX (caddr_t, attr, inx, attrs)
    {
      if (inx > 0 && (inx - 1) % 2 == 0 && inx < (int) BOX_ELEMENTS (attrs))
	if ((!uri_len && !strcmp (extract_last_xml_name_part (attr), szName)) ||
	    (uri_len && attr && !strncmp (attr, szURI, uri_len) && !strcmp (attr + uri_len + 1, szName)))
	return (char *) attrs[inx + 1];
    }
  END_DO_BOX;
  return NULL;
}


caddr_t *
xml_find_child (caddr_t *entity, const char *szSearchName, const char *szURI, int nth, int *start_inx)
{
  int NameLen = szSearchName ? (int) strlen (szSearchName) : INT_MAX;
  int URILen = szURI ? (int) strlen (szURI) : INT_MAX;
  int inx, cnt = 0;
  DO_BOX (caddr_t *, child, inx, entity)
    {
      if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	{
	  const char *szName = XML_ELEMENT_NAME (child);
	  const char *szColon = strrchr (szName, ':');
	  if (!szSearchName && !szURI && cnt++ == nth)
	    return (child);
	  if (szColon && !szURI)
	    continue;
	  else if (!szColon && szURI)
	    continue;
	  else if (szColon && szURI && ((URILen != (szColon - szName))
		|| strnicmp (szName, szURI, MIN (szColon - szName, URILen))))
	    continue;
	  else if (szColon && szSearchName && strncmp (szColon + 1, szSearchName, NameLen))
	    continue;
	  else if (!szColon && szSearchName && strncmp (szName, szSearchName, NameLen))
	    continue;
	  else if (cnt++ == nth)
	    return (child);
	}
    }
  END_DO_BOX;
  return NULL;
}

caddr_t *
xml_find_one_child (caddr_t *entity, char *szSearchName, char **szURIs, int nth, int *start_inx)
{
  char **urls = szURIs;
  caddr_t * rc = NULL;
  for (; urls[0]; urls++)
    {
      rc = xml_find_child (entity, szSearchName, urls[0], nth, start_inx);
      if (rc)
	break;
    }
  return rc;
}

int
is_in_urls (char **szURIs, const char *uri, int * idx)
{
  char **urls = szURIs;
  int i;
  for (i = 0; uri && urls[0]; urls++, i++)
    {
      if (!strcmp (urls[0], uri))
	{
	  if (idx) *idx = i;
	  return 1;
	}
    }
  return 0;
}

static caddr_t *
xml_find_exact_child (caddr_t *entity, char *search_fqname, int nth)
{
  int inx, cnt = 0;
  DO_BOX (caddr_t *, child, inx, entity)
    {
      if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	{
	  char *name = XML_ELEMENT_NAME (child);
	  if ((!search_fqname || !strcmp (name, search_fqname)) && cnt++ == nth)
	    return (child);
	}
    }
  END_DO_BOX;
  return NULL;
}


static caddr_t *
xml_find_child_by_entity_name (caddr_t *entity, char *search_fqname, int nth)
{
  /*
     this finds a child in the incoming request by it's name (from the type def).
     When the typedef is not prefixed it assumes EVERY element that has the same name
     (even if prefixed). This logic should have to be changed when we have types prefixed
   */
  int inx, cnt = 0;
  char *colon = search_fqname ? strrchr (search_fqname, ':') : NULL;
  char *match_name = search_fqname;

  DO_BOX (caddr_t *, child, inx, entity)
    {
      if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	{
	  const char *name = XML_ELEMENT_NAME (child);
	  const char *elt_match_name = name;

	  if (!colon && elt_match_name)
	    elt_match_name = extract_last_xml_name_part (elt_match_name);
	  if ((!match_name || !strcmp (elt_match_name, match_name)) && cnt++ == nth)
	    return (child);
	}
    }
  END_DO_BOX;
  return NULL;
}

static int
xml_is_in_ns (const char *name, const char *ns)
{
  char *colon = strrchr (name, ':');
  int ns_len = (int) strlen (ns);

  if (!colon || colon - name < ns_len || strncmp (name, ns, ns_len))
    return 0;
  else
    return 1;
}

#define xml_is_in_schema_ns(name) \
	(xml_is_in_ns (name, W3C_2001_TYPE_SCHEMA_XSD) || xml_is_in_ns (name, W3C_TYPE_SCHEMA_XSD))

#define xml_is_in_soapenc_ns(name) \
	(xml_is_in_ns (name, SOAP_ENC_SCHEMA11) || xml_is_in_ns (name, SOAP_ENC_SCHEMA12))

#define xml_is_in_virt_ns(name) \
	xml_is_in_ns (name, "services.wsdl")

#define xml_is_sch_qname_attr(name) \
        (!strcmp (name, "base") || \
	 !strcmp (name, "type") || \
	 !strcmp (name, "ref"))

#define xml_is_soap_qname_attr(name) \
        (!strcmp (name, "arrayType") || \
	 !strcmp (name, "itemType"))

#define xml_is_wsdl_qname_attr(name) \
        (!strcmp (name, "arrayType") || \
	 !strcmp (name, "type") || \
	 !strcmp (name, "message") || \
	 !strcmp (name, "binding") || \
	 !strcmp (name, "element"))

static dtp_t
soap_type_to_dtp (const char *szType1, int mode)
{
  const char *szType = szType1;
  if (szType1 && (xml_is_in_schema_ns (szType1) || xml_is_in_soapenc_ns (szType1)))
    {
      szType = extract_last_xml_name_part (szType1);
    }

  if (!szType)
    return 0;
  else if (!strcmp (szType, "int") ||
      !strcmp (szType, "integer") ||
      !strcmp (szType, "short") ||
      !strcmp (szType, "long") ||
      !strcmp (szType, "unsignedLong") ||
      !strcmp (szType, "unsignedInt") ||
      !strcmp (szType, "i1") ||
      !strcmp (szType, "i2") ||
      !strcmp (szType, "i4") ||
      !strcmp (szType, "ui1") ||
      !strcmp (szType, "ui2") ||
      !strcmp (szType, "ui4"))
    return DV_LONG_INT;
  else if (!strcmp (szType, "double") ||
      !strcmp (szType, "r4") ||
      !strcmp (szType, "r8") ||
      !strcmp (szType, "fixed.14,4"))
    return DV_DOUBLE_FLOAT;
  else if (!strcmp (szType, "float"))
    return DV_SINGLE_FLOAT;
  else if (!strcmp (szType, "number") ||
      !strcmp (szType, "numeric") ||
      !strcmp (szType, "decimal"))
    return DV_NUMERIC;
  else if (!strcmp (szType, "timeInstant") ||
      !strcmp (szType, "date") ||
      !strcmp (szType, "time") ||
      !strcmp (szType, "dateTime") ||
      !strcmp (szType, "dateTime.tz"))
    return DV_DATETIME;
  else if (!strcmp (szType, "boolean"))
    return DV_SHORT_INT;
  else if (!strcmp (szType, "string") ||
      !strcmp (szType, "Name") ||
      !strcmp (szType, "NCName") ||
      !strcmp (szType, "ID") ||
      !strcmp (szType, "token") ||
      !strcmp (szType, "QName") ||
      !strcmp (szType, "ENTITY") ||
      !strcmp (szType, "anyURI"))
    return DV_SHORT_STRING;
  else if (!strcmp (szType, "base64Binary") || !strcmp (szType, "base64"))
    return mode ? DV_BIN : DV_LONG_STRING;
  else if (!strcmp (szType, "hexBinary"))
    return DV_LONG_STRING;
  else if (!strcmp (szType, "duration"))
    return DV_SHORT_STRING;
  else
    return 0;
}


static char *
dtp_to_soap_type (dtp_t dtp)
{
  switch (dtp)
    {
      case DV_SHORT_INT:
      case DV_LONG_INT:
	  return "int";


      case DV_ARRAY_OF_POINTER:
      case DV_LIST_OF_POINTER:
      case DV_ARRAY_OF_XQVAL:
      case DV_ARRAY_OF_LONG:
      case DV_ARRAY_OF_DOUBLE:
      case DV_ARRAY_OF_FLOAT:
      case DV_STRING:
      case DV_SYMBOL:
      case DV_WIDE:
      case DV_LONG_WIDE:
      case DV_BLOB:
      case DV_BLOB_WIDE:
      default:
	  return "string";

      case DV_SINGLE_FLOAT:
	  return "float";

      case DV_DOUBLE_FLOAT:
	  return "double";

      case DV_NUMERIC:
	  return "decimal";

      case DV_DATETIME:
      case DV_TIME:
      case DV_DATE:
	  return "dateTime";

      case DV_BLOB_BIN:
      case DV_LONG_BIN:
      case DV_BIN:
	  return "base64Binary";
      /* Note: we cannot map the hexBinary as we do not have a separate dv
	  return "hexBinary"; */
    }
}

static caddr_t xml_find_schema_instance_attribute (caddr_t *entity, const char *name);

/* This is to handle various type of interpretation of xsl:nil */
static int
xml_find_schema_instance_nil_attribute (caddr_t *entity)
{
  caddr_t is_null = xml_find_schema_instance_attribute (entity, "nil");
  if (!is_null)
    is_null = xml_find_schema_instance_attribute (entity, "null");
  if (is_null)
    {
      if (atoi(is_null) > 0)
	return 1;
      else if (!stricmp (is_null, "true"))
	return 1;
    }
  return 0;
}

static int
xml_get_boolean (char * entity)
{
  if (entity)
    {
      if (!strcmp (entity, "1") || !strcmp (entity, "true"))
	return 1;
      else if (!strcmp (entity, "0") || !strcmp (entity, "false"))
	return 0;
      return -1;
    }
  return 0;
}

static void
ws_soap_check_async (client_connection_t * cli, query_t *qr, dk_session_t *ses, int soap_version)
{
  char tmp[1000];
  ws_connection_t *ws = cli->cli_ws;
  int async = (int) unbox ((box_t) SOAP_OPT (ONEWAY, qr, -1, 0));

  if (!async || !ws || ws->ws_flushed)
    return;

  strses_flush (ses);
  snprintf (tmp, sizeof (tmp),
      "<SOAP:Envelope xmlns:SOAP=\"%s\">"
      "<SOAP:Body />"
      "</SOAP:Envelope>",
      SOAP_URI(soap_version));
  session_buffered_write (ses, tmp, strlen (tmp));

  if (DO_LOG(LOG_SOAP))
    {
      LOG_GET;
      log_info ("SOAP_5 %s %s %s: %.*s", user, from, peer, LOG_PRINT_SOAP_STR_L, tmp);
    }

  ws_strses_reply (ws, "HTTP/1.1 200 OK");
  ws->ws_flushed = 1;

  if (!ws->ws_session->dks_to_close)
    {
      ws->ws_session->dks_ws_status = DKS_WS_FLUSHED;
      PrpcDisconnect (ws->ws_session);
    }
}


static caddr_t
soap_box_xml_entity (caddr_t *entity, caddr_t *err_ret, dtp_t proposed_type, int soap_version)
{
  dtp_t type;
  caddr_t ret = NULL;
  char *szTag = NULL, *szOpeningBrace;
  const char *szEntityName = NULL, *szArrayType = NULL, *szType = NULL, *szNodeType = NULL, *szArraySize = NULL;
  int inx, is_array = 1, ent_count = 0, ent_inx = 0;
  dk_set_t child_set = NULL;
  const char *szTypeBuffer = NULL;

  if (!entity)
    return box_cast (NULL, NULL, NULL, DV_DB_NULL);


  type = DV_TYPE_OF (entity);

  if (type != DV_ARRAY_OF_POINTER)
    {
      caddr_t wide = box_utf8_as_wide_char ((caddr_t) entity, NULL, box_length (entity) - 1, 0, DV_WIDE);
      if (!proposed_type)
	return wide;
      else
	{
	  if (proposed_type == DV_SHORT_INT)
	    {
	      if (!strcmp ((caddr_t) entity, "yes") || !strcmp ((caddr_t) entity, "1") ||
		  !strcmp ((caddr_t) entity, "true"))
		ret = box_num (1);
	      else
		ret = box_num_nonull (0);
	    }
	  else if (proposed_type == DV_DATETIME)
	    {
              caddr_t err_msg = NULL;
              ret = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	      iso8601_string_to_datetime_dt ((caddr_t) entity, ret, &err_msg);
              if (NULL != err_msg)
		{
                  dk_free_box (ret);
                  dk_free_box (err_msg);
		  return wide;
		}
	    }
	  else if (proposed_type == DV_BIN)
	    {
	      caddr_t tmp = box_copy ((caddr_t) entity);
	      size_t len, blen = box_length (tmp);
	      len = decode_base64(tmp, tmp + blen);
	      ret = dk_alloc_box (len, DV_BIN);
	      memcpy (ret, tmp, len);
	      dk_free_box(tmp);
	    }
	  else
	    {
	      ret = box_cast_to (NULL, wide, DV_WIDE, proposed_type,
		  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err_ret);
	      /* special case, NULL must be 0 when integer expected */
	      if (!ret && proposed_type == DV_LONG_INT)
		ret = box_num_nonull (0);
	    }
	  dk_free_box (wide);
          if (*err_ret)
	    return NULL;
	  return ret;
	}
    }

  if (BOX_ELEMENTS (entity) == 1)
    {
      if (ARRAYP(entity[0]) && soap_version >= 11)
	{
	  if (xml_find_schema_instance_nil_attribute (entity))
	    return dk_alloc_box (0, DV_DB_NULL);
	  else if (IS_STRING_DTP (proposed_type))
	    return box_dv_short_string ("");
	  else if (IS_WIDE_STRING_DTP (proposed_type))
	    {
	      caddr_t wide_ret = dk_alloc_box (sizeof(wchar_t), DV_WIDE);
	      wide_ret [0] = L'\0';
	      return wide_ret;
	    }
	}
      return box_cast (NULL, NULL, NULL, DV_DB_NULL);
    }

  szEntityName = extract_last_xml_name_part (XML_ELEMENT_NAME (entity));
  szArrayType = xml_find_attribute (entity, "arrayType", SOAP_ENC (soap_version));
  if (!szArrayType)
    szType = szArrayType = xml_find_attribute (entity, "type", W3C_TYPE_SCHEMA_XSI);
  if (!szArrayType)
    szType = szArrayType = xml_find_attribute (entity, "type", W3C_2001_TYPE_SCHEMA_XSI);
  if (!szArrayType)
    szType = szArrayType = xml_find_attribute (entity, "dt", MS_TYPE_SCHEMA);

  if (soap_version == 12)
    {
      szNodeType = xml_find_attribute (entity, "nodeType", SOAP_ENC (soap_version));
      szArraySize = xml_find_attribute (entity, "arraySize", SOAP_ENC (soap_version));
    }

  if (szArrayType)
    {
      szType = szArrayType = extract_last_xml_name_part (szArrayType);
      szOpeningBrace = strchr (szArrayType, '[');
      if (szOpeningBrace)
	{
	  if (strchr (szOpeningBrace, ','))
	    {
	      if (err_ret)
		*err_ret = srv_make_new_error ("42000", "SP004", "Multidimensional arrays not supported");
	      return NULL;
	    }
	  else if (soap_version < 11)
	    {
	      *szOpeningBrace = 0;
	      szTag = box_dv_short_string (szArrayType);
	      *szOpeningBrace = '[';
	    }
	  szTypeBuffer = szArrayType = box_dv_short_string (szArrayType);
	  szOpeningBrace = strchr (szArrayType, '[');
	  *szOpeningBrace = 0;
	}
      else
	{
	  szArrayType = NULL;
	  if (soap_version < 11)
	    szTag = box_dv_short_string (szArrayType);
	}
    }
  else if (!strncmp (szEntityName, "ArrayOf", 7))
    {
      szArrayType = szEntityName;
      szTag = box_dv_short_string (szEntityName + 7);
    }
  else if ((szNodeType && !strcmp (szNodeType, "array")) || szArraySize)
    {
      szArrayType = xml_find_attribute (entity, "itemType", SOAP_ENC (soap_version));
      if (szArrayType)
	{
	  szType = szArrayType = extract_last_xml_name_part (szArrayType);
	}
    }
  else
    {
      szArrayType = NULL;
      szTag = NULL;
      is_array = 0;
    }

  if (BOX_ELEMENTS (entity) == 2 &&
      DV_TYPE_OF (XML_ELEMENT_CHILD (entity, 0)) != DV_ARRAY_OF_POINTER)
    { /* single entity with value */
      if (!proposed_type)
	proposed_type = soap_type_to_dtp (szArrayType ? szArrayType : szType, 1);
      if (!proposed_type)
	proposed_type = DV_SHORT_STRING;
      ret = soap_box_xml_entity ((caddr_t *) entity[1], err_ret, proposed_type, soap_version);
      dk_free_box (szTag);
      dk_free_box ((box_t) szTypeBuffer);
      return ret;
    }

  DO_BOX (caddr_t *, child, inx, entity)
    {
      if (inx > 0 && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	{
	  const char *elt_name = XML_ELEMENT_NAME (child);
	  if (!szTag)
	    szTag = box_dv_short_string (XML_ELEMENT_NAME (child));
	  if (elt_name && strcmp (elt_name, szTag))
	    is_array = 0;
	  ent_count ++;
	  ent_inx = inx;
	}
    }
  END_DO_BOX;

  if (!is_array && soap_version >= 11)
    {
      dk_set_push (&child_set, dk_alloc_box (0, DV_COMPOSITE));
      dk_set_push (&child_set, box_dv_short_string (XML_ELEMENT_NAME (entity)));
      proposed_type = 0;
    }
  else
    {
      if (szArrayType)
	{
	  proposed_type = soap_type_to_dtp (szArrayType, 1);
	}
      else
	proposed_type = 0;
    }
  DO_BOX (caddr_t *, child, inx, entity)
    {
      if (inx > 0 && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	{
	  if (!is_array && soap_version >= 11)
	      dk_set_push (&child_set, box_dv_short_string (XML_ELEMENT_NAME (child)));
	  dk_set_push (&child_set, soap_box_xml_entity (child, err_ret, proposed_type, soap_version));
	  if (*err_ret)
	    break;
	}
    }
  END_DO_BOX;

  dk_free_box (szTag);
  dk_free_box ((box_t) szTypeBuffer);
  if (*err_ret)
    {
      dk_free_tree (list_to_array (child_set));
      return NULL;
    }
  else
    {
      child_set = dk_set_nreverse (child_set);
      if (is_array)
	{
	  if (proposed_type == DV_LONG_INT)
	    {
	      ptrlong * ret = (ptrlong *) dk_alloc_box (dk_set_length (child_set) * sizeof (ptrlong), DV_ARRAY_OF_LONG);
	      int inx = 0;
	      DO_SET (caddr_t, elt, &child_set)
		{
		  ret[inx++] = unbox (elt);
		}
	      END_DO_SET ();
	      dk_free_tree (list_to_array (child_set));
	      return (caddr_t) ret;
	    }
	  else if (proposed_type == DV_DOUBLE_FLOAT)
	    {
	      double * ret = (double *) dk_alloc_box (dk_set_length (child_set) * sizeof (double), DV_ARRAY_OF_DOUBLE);
	      int inx = 0;
	      DO_SET (caddr_t, elt, &child_set)
		{
		  ret[inx++] = unbox_double (elt);
		}
	      END_DO_SET ();
	      dk_free_tree (list_to_array (child_set));
	      return (caddr_t) ret;
	    }
	  else if (proposed_type == DV_SINGLE_FLOAT)
	    {
	      float * ret = (float *) dk_alloc_box (dk_set_length (child_set) * sizeof (float), DV_ARRAY_OF_FLOAT);
	      int inx = 0;
	      DO_SET (caddr_t, elt, &child_set)
		{
		  ret[inx++] = unbox_float (elt);
		}
	      END_DO_SET ();
	      dk_free_tree (list_to_array (child_set));
	      return (caddr_t) ret;
	    }
	}
      return list_to_array (child_set);
    }
}

static caddr_t
soap_print_box (caddr_t object, dk_session_t *out, const char *tag, int soap_version,
    		const char * h_namespace, dtp_t obj_type, soap_ctx_t * ctx)
{
  char temp[256];
  int tag_len = tag ? (int) strlen (tag) : 0;
  size_t n, length = 0;
  dtp_t dtp = DV_TYPE_OF (object);

#ifdef MALLOC_DEBUG
  if (!ctx || ctx->soap_version != soap_version)
    GPF_T;
#endif

  if (object == NULL && DV_LONG_INT != obj_type)
    return NULL;

  if (tag && dtp != DV_XML_ENTITY && dtp != DV_OBJECT && dtp != DV_REFERENCE)
    {
      session_buffered_write_char ('<', out);
      if (h_namespace)
	SES_PRINT (out, "h:");
      session_buffered_write (out, tag, tag_len);
      if (h_namespace)
	{
	  SES_PRINT (out, " xmlns:h='");
	  SES_PRINT (out, h_namespace);
	  SES_PRINT (out, "'");
	}
    }

  if (!IS_BOX_POINTER (object))
    {
      if (SOAP_USES_TYPES)
	SES_PRINT(out, " xsi:type=\"xsd:int\" dt:dt=\"int\"");

      snprintf (temp, sizeof (temp), ">%ld", (long) (ptrlong) object);
      SES_PRINT (out, temp);
    }
  else if (DV_TYPE_OF (object) == DV_ARRAY_OF_POINTER &&
      BOX_ELEMENTS (object) == 2 &&
      DV_TYPE_OF (((caddr_t *)object)[0]) == DV_COMPOSITE &&
      DV_TYPE_OF (((caddr_t *)object)[1]) == DV_LONG_INT)
    {
      if (SOAP_USES_TYPES)
	SES_PRINT (out, " xsi:type=\"xsd:boolean\" dt:dt=\"boolean\"");

      snprintf (temp, sizeof (temp), ">%ld", (long) unbox (((caddr_t *)object)[1]));
      SES_PRINT (out, temp);
    }
  else
    {
      switch (dtp)
	{
	case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
	  {
	    length = box_length (object) / sizeof (caddr_t);
	    if (length > 2 && (length % 2) == 0 && DV_TYPE_OF (((caddr_t *)object)[0]) == DV_COMPOSITE)
	      {
		/* that is an structure */
		session_buffered_write_char ('>', out);
		for (n = 2; n < length; n += 2)
		  {
		    caddr_t name = ((caddr_t *) object)[n];
		    caddr_t elt = ((caddr_t *) object)[n + 1];
		    caddr_t err;
		    err = soap_print_box (elt, out, name, soap_version, NULL, 0, ctx);
		    if (err)
		      return err;
		  }
	      }
	    else
	      {
		/* that is an array */
		int is_string = 1;
		DO_BOX (caddr_t, elt, n, ((caddr_t *)object))
		  {
		    if (!DV_STRINGP (elt) && !DV_WIDESTRINGP (elt))
		      is_string = 0;
		  }
		END_DO_BOX;

		if (is_string)
		  {
		    /* a string array */
		    if (SOAP_USES_TYPES)
		      {
			if (soap_version == 11)
			  snprintf (temp, sizeof (temp),
			      " SOAP-ENC:arrayType='xsd:string[%ld]' xsi:type=\"SOAP-ENC:Array\">", (long)length);
			else if (soap_version == 12)
			  snprintf (temp, sizeof (temp), " SOAP-ENC:arraySize='%ld' SOAP-ENC:nodeType='array' SOAP-ENC:itemType='xsd:string'>", (long)length);
			else
			  snprintf (temp, sizeof (temp),
			      " xsi:type=\"xsd:string[%ld]\" SOAP:arrayType=\"string[%ld]\">",
			      (long)length, (long)length);
			SES_PRINT (out, temp);
		      }
		    else
		      session_buffered_write_char ('>', out);
		    DO_BOX (caddr_t, elt, n, ((caddr_t *)object))
		      {
			int was_wide = DV_WIDESTRINGP (elt);
			if (was_wide)
			  elt = box_wide_as_utf8_char (elt, wcslen((wchar_t *)elt), DV_LONG_STRING);
			SES_PRINT (out, "<item>");
			if (elt)
			  dks_esc_write (out, elt, strlen (elt), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
			SES_PRINT (out, "</item>");
			if (was_wide)
			  dk_free_box (elt);
		      }
		    END_DO_BOX
		  }
		else
		  {
		    /* mixed content array */
		    if (SOAP_USES_TYPES)
		      {
			if (soap_version == 11)
			  snprintf (temp, sizeof (temp),
			      " SOAP-ENC:arrayType='ur-type[%ld]' xsi:type=\"SOAP-ENC:Array\">", (long)length);
			else if (soap_version == 12)
			  snprintf (temp, sizeof (temp), " SOAP-ENC:arraySize='%ld' SOAP-ENC:nodeType='array'>", (long)length);
			else
			  snprintf (temp, sizeof (temp),
			      " xsi:type=\"xsd:variant[%ld]\" SOAP:arrayType=\"item[%ld]\">",
			      (long)length, (long)length);
			SES_PRINT (out, temp);
		      }
		    else
		      session_buffered_write_char ('>', out);
		    for (n = 0; n < length; n++)
		      {
			caddr_t elt = ((caddr_t *) object)[n];
			caddr_t err;
			err = soap_print_box (elt, out, soap_version >= 11 ? "item" : "variant",
			    soap_version, NULL, (elt ? 0 : DV_LONG_INT), ctx);
			if (err)
			  return err;
		      }
		  }
	      }
	    break;
	  }

	case DV_ARRAY_OF_LONG:
	  {
	    length = box_length (object) / sizeof (ptrlong);
	    if (SOAP_USES_TYPES)
	      {
		if (soap_version == 11)
		  snprintf (temp, sizeof (temp),
		      " xsi:type=\"xsd:int[%ld]\" SOAP-ENC:arrayType=\"xsd:int[%ld]\">",
		      (long)length, (long)length);
		else if (soap_version == 12)
		  snprintf (temp, sizeof (temp),
		      " SOAP-ENC:arraySize='%ld' SOAP-ENC:nodeType='array' SOAP-ENC:itemType='xsd:int'>",
		      (long)length);
		else
		  snprintf (temp, sizeof (temp),
		      " xsi:type=\"xsd:int[%ld]\" SOAP:arrayType=\"xsd:int[%ld]\">",
		      (long)length, (long)length);
		SES_PRINT (out, temp);
	      }
	    else
	      session_buffered_write_char ('>', out);
	    for (n = 0; n < length; n++)
	      {
		SES_PRINT (out, "<item>");
		snprintf (temp, sizeof (temp), "%ld", (long) ((ptrlong *) object)[n]);
		SES_PRINT (out, temp);
		SES_PRINT (out, "</item>");
	      }
	    break;
	  }

	case DV_ARRAY_OF_DOUBLE:
	  {
	    length = box_length (object) / sizeof (double);
	    if (SOAP_USES_TYPES)
	      {
		if (soap_version == 11)
		  snprintf (temp, sizeof (temp),
		      " xsi:type=\"xsd:double[%ld]\" SOAP-ENC:arrayType=\"xsd:double[%ld]\">", (long)length, (long)length);
		else if (soap_version == 12)
		  snprintf (temp, sizeof (temp),
		      " SOAP-ENC:arraySize='%ld' SOAP-ENC:nodeType='array' SOAP-ENC:itemType='xsd:double'>",
		      (long)length);
		else
		  snprintf (temp, sizeof (temp),
		      " xsi:type=\"xsd:double[%ld]\" SOAP:arrayType=\"xsd:double[%ld]\">", (long)length, (long)length);
		SES_PRINT (out, temp);
	      }
	    else
	      session_buffered_write_char ('>', out);
	    for (n = 0; n < length; n++)
	      {
		SES_PRINT (out, "<item>");
		snprintf (temp, sizeof (temp), "%f", ((double *) object)[n]);
		SES_PRINT (out, temp);
		SES_PRINT (out, "</item>");
	      }
	    break;
	  }

	case DV_ARRAY_OF_FLOAT:
	  {
	    length = box_length (object) / sizeof (float);
	    if (SOAP_USES_TYPES)
	      {
		if (soap_version == 11)
		  snprintf (temp, sizeof (temp), " xsi:type=\"xsd:float[%ld]\" SOAP-ENC:arrayType=\"xsd:float[%ld]\">", (long)length, (long)length);
		else if (soap_version == 12)
		  snprintf (temp, sizeof (temp),
		      " SOAP-ENC:arraySize='%ld' SOAP-ENC:nodeType='array' SOAP-ENC:itemType='xsd:float'>",
		      (long)length);
		else
		  snprintf (temp, sizeof (temp), " xsi:type=\"xsd:float[%ld]\" SOAP:arrayType=\"xsd:float[%ld]\">", (long)length, (long)length);
		SES_PRINT (out, temp);
	      }
	    else
	      session_buffered_write_char ('>', out);
	    for (n = 0; n < length; n++)
	      {
		  SES_PRINT (out, "<item>");
		snprintf (temp, sizeof (temp), "%f", ((float *) object)[n]);
		SES_PRINT (out, temp);
		SES_PRINT (out, "</item>");
	      }
	    break;
	  }

	case DV_LONG_INT:
	  if (SOAP_USES_TYPES)
	    snprintf (temp, sizeof (temp), " xsi:type=\"xsd:int\" dt:dt=\"int\">" BOXINT_FMT, unbox (object));
	  else
	    snprintf (temp, sizeof (temp), ">" BOXINT_FMT, unbox (object));
	  SES_PRINT (out, temp);
	  break;

	case DV_STRING:
	case DV_SYMBOL:
	    {
	      if (SOAP_USES_TYPES)
		SES_PRINT (out, " xsi:type=\"xsd:string\" dt:dt=\"string\">");
	      else
		session_buffered_write_char ('>', out);
	      dks_esc_write (out, object, strlen (object), CHARSET_UTF8, default_charset, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
	    }
	    break;

	case DV_SINGLE_FLOAT:
	    if (SOAP_USES_TYPES)
	      snprintf (temp, sizeof (temp), " xsi:type=\"xsd:float\" dt:dt=\"float\">%f", *(float *) object);
	    else
	      snprintf (temp, sizeof (temp), ">%f", *(float *) object);
	  SES_PRINT (out, temp);
	  break;

	case DV_DOUBLE_FLOAT:
	   if (SOAP_USES_TYPES)
	     snprintf (temp, sizeof (temp), " xsi:type=\"xsd:double\" dt:dt=\"double\">%f", *(double *) object);
	   else
	     snprintf (temp, sizeof (temp), ">%f", *(double *) object);
	  SES_PRINT (out, temp);
	  break;
	case DV_OBJECT:
	case DV_REFERENCE:
	  {
	    soap_ctx_t local_ctx;
	    caddr_t err = NULL;
	    memset (&local_ctx, 0, sizeof (soap_ctx_t));
	    local_ctx.add_type = 1;
	    local_ctx.qst = ctx->qst;
	    local_ctx.soap_version = ctx->soap_version;
	    local_ctx.cli = ctx->cli;
	    soap_print_box_validating (object, tag, out, &err, NULL, &local_ctx, 0, 1, NULL);
	    if (err)
	      return err;
	  }
	break;

	case DV_DB_NULL:
	  if (SOAP_USES_TYPES)
	    SES_PRINT (out, soap_version == 1 ? " xsi:null=\"1\"/>" : " xsi:nil=\"1\"/>");
	  else
	    SES_PRINT (out, "/>");
	  return NULL;
	  break;

	case DV_NUMERIC:
	  numeric_to_string ((numeric_t) object, temp, sizeof (temp));
	  if (SOAP_USES_TYPES)
	    SES_PRINT (out, " xsi:type =\"xsd:decimal\" dt:dt=\"number\">");
	  else
	    session_buffered_write_char ('>', out);
	  SES_PRINT (out, temp);
	  break;

	case DV_DATETIME:
	  if (SOAP_USES_TYPES)
	    {
	      if (soap_version > 1)
		SES_PRINT (out, " xsi:type=\"xsd:dateTime\" dt:dt=\"dateTime\">");
	      else
		SES_PRINT (out, " xsi:type=\"xsd:timeInstant\" dt:dt=\"dateTime\">");
	    }
	  else
	    session_buffered_write_char ('>', out);
	  dt_to_iso8601_string (object, temp, sizeof (temp));
	  SES_PRINT (out, temp);
	  break;

	case DV_WIDE: case DV_LONG_WIDE:
	    {
	      caddr_t utf8;
	      length = wcslen ((wchar_t *) object);
	      utf8 = box_wide_as_utf8_char (object, length, DV_SHORT_STRING);
	      if (SOAP_USES_TYPES)
		SES_PRINT (out, " xsi:type=\"xsd:string\" dt:dt=\"string\">");
	      else
		session_buffered_write_char ('>', out);
	      if (utf8)
		dks_esc_write (out, utf8, strlen (utf8), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
	      dk_free_box (utf8);
	      break;
	    }
	case DV_BIN:
	   {
	     caddr_t src = (caddr_t) object, dest;
	     size_t len = box_length(src);

	     if (SOAP_USES_TYPES)
	       SES_PRINT (out, " xsi:type=\"xsd:base64Binary\">");
	     else
	       session_buffered_write_char ('>', out);

	     dest = dk_alloc_box(len * 2 + 1, DV_SHORT_STRING);
	     len = encode_base64 ((char *)src, (char *)dest, len);
	     *(dest+len) = 0;
	     SES_PRINT (out, dest);
	     dk_free_box (dest);

	     break;
	   }
	case DV_XML_ENTITY:
	    {
              xml_entity_t *ent = (xml_entity_t *)object;
              if (!XE_IS_TREE (ent))
	        return srv_make_new_error ("42000", "SP038", "SOAP can not print persistent XML entity in the result, only XML trees are supported.");
              ent->xe_doc.xd->xd_qi = &soap_fake_top_qi;
	      ent->_->xe_serialize (ent, out);
	      break;
	    }
/*        case DV_STRING_SESSION:
	    {
              caddr_t val = strses_string ((dk_session_t *) object);
	      fprintf (stderr, "XML response : \n%s\n", val);
	      SES_PRINT (out, val);
	      dk_free_box (val);
	      break;
	    }*/

	default:
	  {
	    return srv_make_new_error ("42000", "SP005", "Unknown result type");
	  }
	}
    }
  if (tag && dtp != DV_XML_ENTITY && dtp != DV_OBJECT && dtp != DV_REFERENCE)
    {
      SES_PRINT (out, "</");
      if (h_namespace)
	SES_PRINT (out, "h:");
      session_buffered_write (out, tag, tag_len);
      session_buffered_write_char ('>', out);
    }
  return NULL;
}

static void soap_wsdl_schema_push (dk_set_t * ns_set, dk_set_t * types_set, char * name, int element, int import,
    sql_type_t *sqt, soap_ctx_t *ctx);
static caddr_t xml_find_schema_attribute (caddr_t *entity, const char *name);

static void
soap_find_depend_types (caddr_t * tree, dk_set_t * ns_set, dk_set_t * types_set, int element,
    soap_wsdl_ns_t * current_ns, soap_ctx_t *ctx)
{
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int inx = 0, len = BOX_ELEMENTS (tree);
      char * tag = XML_ELEMENT_NAME(tree);
      if (!strcmp (tag, SOAP_TAG_DT_ELEMENT) || !strcmp (tag, SOAP_TAG_DT_ATTR))
	{
	  caddr_t type = xml_find_schema_attribute (tree, "type");
	  caddr_t derived = NULL;
	  char * colon = type ? strrchr (type, ':') : NULL;
	  int elm = 0;
	  if (!type)
	    {
              type = xml_find_schema_attribute (tree, "ref"); /* element reference */
	      colon = type ? strrchr (type, ':') : NULL;
	      if (!strcmp (tag, SOAP_TAG_DT_ATTR))
		{
		  if (colon && (0 == strncmp (type, SOAP_ENC_SCHEMA11, strlen (SOAP_ENC_SCHEMA11))
			|| 0 == strncmp (type, SOAP_REF_SCH_200204, strlen (SOAP_REF_SCH_200204))))
		    {
		      /* do not import soap encoding and ref schemas */
		      colon = NULL;
		      type = NULL;
		    }
		  else
		    elm = -1;
		}
	      else
		elm = 1;
	    }
	  derived = xml_find_schema_attribute (tree, "namespace"); /* derived from type */
	  if (colon &&
	      0 != strncmp (type, W3C_2001_TYPE_SCHEMA_XSD, strlen (W3C_2001_TYPE_SCHEMA_XSD)) &&
	      ((colon - type) != strlen (current_ns->ns_uri) ||
	       strncmp (current_ns->ns_uri, type, (size_t)(colon - type))))
	    {
	      int found = 0;
	      caddr_t import = dk_alloc_box_zero ((colon - type) + 1, DV_SHORT_STRING);
	      memcpy (import, type, (colon - type));
	      DO_SET (caddr_t, import1, &(current_ns->ns_imports))
		{
		  if (!strcmp (import1, import))
		    {
		      found = 1;
		      break;
		    }
		}
	      END_DO_SET ();
	      if (!found)
		dk_set_push (&(current_ns->ns_imports), (void *)import);
	      else
		dk_free_box (import);
	    }
	  if (type)
	    soap_wsdl_schema_push (ns_set, types_set, type, elm, 1, NULL, ctx);
	  if (derived)
	    soap_wsdl_schema_push (ns_set, types_set, derived, 0, 1, NULL, ctx);
	}
      for (inx = 1; inx < len; inx++)
	{
	  soap_find_depend_types ((caddr_t *) tree[inx], ns_set, types_set, element, current_ns, ctx);
	}
    }
}

static void
soap_enc_ns_push (caddr_t * tree, soap_wsdl_ns_t * current_ns)
{
  caddr_t * type = xml_find_schema_child (tree, "complexContent", 0);
  caddr_t * restriction;
  caddr_t base;
  int found = 0;

  restriction = type ? xml_find_schema_child (type, "restriction", 0) : NULL;

  if (!restriction && type)
    restriction = xml_find_schema_child (type, "extension", 0);

  base = restriction ? xml_find_schema_attribute (restriction, "base") : NULL;

  if (base && !strcmp (base, SOAP_ATTR_DT_ARRAY))
    {
      DO_SET (caddr_t, import, &(current_ns->ns_imports))
	{
	  if (!strcmp (import, SOAP_ENC_SCHEMA11))
	    {
	      found = 1;
	      break;
	    }
	}
      END_DO_SET ();
      if (!found)
	dk_set_push (&(current_ns->ns_imports), (void *)box_dv_short_string (SOAP_ENC_SCHEMA11));
    }
}

static void
soap_wsdl_ns_decl (dk_set_t * ns_set, const char * tns, const char * ns_pref)
{
  int i = 0, already_defined = 0;
  soap_wsdl_ns_t * ns;

  DO_SET (soap_wsdl_ns_t *, elm, ns_set)
    {
      if (!strcmp (elm->ns_uri, tns))
	{
	  if (!ns_pref || !strcmp (elm->ns_pref, ns_pref))
	    return;
	}
      else if (ns_pref && !strcmp (elm->ns_pref, ns_pref))
	{
	  already_defined = 1;
	}
      i++;
    }
  END_DO_SET ();

  ns = (soap_wsdl_ns_t *) dk_alloc (sizeof(soap_wsdl_ns_t));
  memset(ns, 0, sizeof(soap_wsdl_ns_t));
  ns->ns_uri = box_dv_short_string(tns);
  if (ns_pref && !already_defined)
    strcpy_ck (ns->ns_pref, ns_pref);
  else
    snprintf (ns->ns_pref, sizeof (ns->ns_pref), "ns%d", i);
  dk_set_push (ns_set, (void *) ns);
}

static void
soap_wsdl_schema_push (dk_set_t * ns_set, dk_set_t * types_set, char * name, int element, int import,
    sql_type_t *sqt, soap_ctx_t *ctx)
{
  caddr_t ns = name ? box_dv_short_string (name) : NULL;
  char * colon = ns ? strrchr (ns, ':') : NULL;
  int i = 0;
  soap_wsdl_ns_t * tns = NULL;
  soap_wsdl_type_t * type = NULL;
  sql_class_t *udt = sqt ? sqt->sqt_class : NULL;

  if (!name || !colon ||
      0 == strncmp (name,
	W3C_2001_TYPE_SCHEMA_XSD ,
	strlen (W3C_2001_TYPE_SCHEMA_XSD))) /* not prefixed types are valid, and treated as of XSD */
    goto end_find;

  *colon = 0;

  DO_SET (soap_wsdl_ns_t *, elm, ns_set)
    {
      if (!strcmp (elm->ns_uri, ns))
	{
	  tns = elm;
	  if (!import && tns->ns_imported) /* if it's already but imported, unmark it */
	    tns->ns_imported = import;
	  break;
	}
      i++;
    }
  END_DO_SET ();

  if (!tns)
    {
      tns = (soap_wsdl_ns_t *) dk_alloc (sizeof(soap_wsdl_ns_t));
      memset(tns, 0, sizeof(soap_wsdl_ns_t));
      tns->ns_uri = box_dv_short_string(ns);
      tns->ns_imported = import;

      if (0 == strcmp (ns, WSP_URI))
	strcpy_ck (tns->ns_pref, "wsp");
      else if (0 == strcmp (ns, WSA_URI))
	strcpy_ck (tns->ns_pref, "wsa");
      else if (0 == strcmp (ns, WSA_URI_200403))
	strcpy_ck (tns->ns_pref, "wsa1");
      else if (0 == strcmp (ns, WSRM_URI))
	strcpy_ck (tns->ns_pref, "wsrm");
#ifdef _SSL
      else if (0 == strcmp (ns, WSU_URI(&(ctx->wsse_ctx))))
	strcpy_ck (tns->ns_pref, "wsu");
      else if (0 == strcmp (ns, WSSE_URI(&(ctx->wsse_ctx))))
	strcpy_ck (tns->ns_pref, "wsse");
#endif
      else
        snprintf (tns->ns_pref, sizeof (tns->ns_pref), "ns%d", i);

      dk_set_push (ns_set, (void *) tns);
    }

  DO_SET (soap_wsdl_type_t *, elm, types_set)
    {
      if (!strcmp (elm->type_name, name) && elm->type_is_elem == element)
	goto end_find;
    }
  END_DO_SET ();

  if (!type)
    {
      caddr_t name2 = box_dv_short_string (name);
      caddr_t *place = (caddr_t *)id_hash_get (HT_SOAP(element), (caddr_t)&name2);
      type = (soap_wsdl_type_t *) dk_alloc (sizeof(soap_wsdl_type_t));
      type->type_name = name2;
      type->type_ns = tns;
      type->type_is_elem = element;
      type->type_udt = udt;
      if (sqt)
        memcpy (&(type->type_sqt), sqt, sizeof (sql_type_t));
      dk_set_push (types_set, (void *) type);
      if (place && *place) /* let's scan for dependencies from other types */
	{
	  caddr_t * tree1 = (caddr_t *) (element ? ((caddr_t *)(*place))[1] : ((caddr_t *)(*place))[0]);
/*
	  if (element)
	    soap_find_depend_types ((caddr_t *)((caddr_t *)(*place))[1], ns_set, types_set, element, tns, ctx);
	  else
	    soap_find_depend_types ((caddr_t *)((caddr_t *)(*place))[0], ns_set, types_set, element, tns, ctx);
*/

	  soap_find_depend_types (tree1, ns_set, types_set, element, tns, ctx);
	  if (!import && !element)
	    soap_enc_ns_push (tree1, tns);

	}
      if (udt)
	{
	  int inx;
	  DO_BOX (sql_field_t *, fld, inx, udt->scl_member_map)
	    {
	      if (IS_COMPLEX_SQT (fld->sfl_sqt))
		{
		  caddr_t scl_soap_type =
		      soap_sqt_to_soap_type (&(fld->sfl_sqt), fld->sfl_soap_type, ctx->opts,
			  udt->scl_name_only, fld->sfl_name);

		  soap_wsdl_schema_push (ns_set, types_set, scl_soap_type, element,
		      import, &(fld->sfl_sqt), ctx);
		  dk_free_box (scl_soap_type);
		}
	    }
	  END_DO_BOX;
	}
      else if (sqt && sqt->sqt_tree)
	{
	  sql_type_t sqt1;
	  ddl_type_to_sqt (&sqt1, sqt->sqt_tree);
	  if (IS_COMPLEX_SQT (sqt1))
	    {
	      const char * nc_type_name = extract_last_xml_name_part (name);
	      caddr_t soap_type_name =
		  soap_sqt_to_soap_type (&(sqt1), NULL, ctx->opts, nc_type_name, "item");

	      soap_wsdl_schema_push (ns_set, types_set, soap_type_name, element, import, &(sqt1), ctx);
	      dk_free_box (soap_type_name);
	    }
	}
      dk_set_push (&(tns->ns_types), (void *) type);
    }
end_find:
  dk_free_box (ns);
}

static void
soap_wsdl_schema_free (dk_set_t * ns_set, dk_set_t * types_set)
{
  soap_wsdl_ns_t * tns = NULL;
  soap_wsdl_type_t * type = NULL;

  while (NULL != (tns = (soap_wsdl_ns_t *) dk_set_pop (ns_set)))
    {
      dk_free_box (tns->ns_uri);
      dk_set_free (tns->ns_types);
      dk_free_tree (list_to_array (dk_set_nreverse (tns->ns_imports)));
      dk_free (tns, sizeof (soap_wsdl_ns_t));
    }

  while (NULL != (type = (soap_wsdl_type_t *) dk_set_pop (types_set)))
    {
      dk_free_box (type->type_name);
      dk_free (type, sizeof (soap_wsdl_type_t));
    }
}

static int
soap_wsdl_ns_exists (dk_set_t * ns_set, char * ns)
{
  if (!ns)
    return 0;
  DO_SET (soap_wsdl_ns_t *, elm, ns_set)
    {
      if (!strcmp (elm->ns_uri, ns))
	  return 1;
    }
  END_DO_SET ();
  return 0;
}

static char *
soap_wsdl_get_ns_prefix (dk_set_t * ns_set, const char * ns)
{
  if (!ns)
    return NULL;
  DO_SET (soap_wsdl_ns_t *, elm, ns_set)
    {
      if (!strcmp (elm->ns_uri, ns))
	  return elm->ns_pref;
    }
  END_DO_SET ();
  return NULL;
}

static void
soap_wsdl_print_ns_decl (dk_session_t * out, dk_set_t * ns_set, char * import)
{
  DO_SET (soap_wsdl_ns_t *, elm, ns_set)
    {
#if 0
      if ((!import && !elm->ns_imported) ||
	  (import && !strcmp (elm->ns_uri, import)))
#endif
	{
	  if (import)
	    SES_PRINT (out, "\t");
	  SES_PRINT (out, " xmlns:");
	  SES_PRINT (out, elm->ns_pref);
	  SES_PRINT (out, "=\"");
	  SES_PRINT (out, elm->ns_uri);
	  SES_PRINT (out, "\"\n");
	}
    }
  END_DO_SET ();
}


#ifdef VIRTUAL_DIR
#define SOAP_SERVICE_NAME 	"ServiceName"
#define SOAP_NS 		"Namespace"
#define SOAP_DT_SCH 		"SchemaNS"
#define SOAP_HDR_NS 		"HeaderNS"
#define SOAP_FAULT_NS 		"FaultNS"
#define SOAP_ACTION 		"MethodInSoapAction"
#define SOAP_ESCAPES 		"CR-escape"
#define SOAP_DIME_ENC 		"DIME-ENC"
#define SOAP_MIME_ENC 		"MIME-ENC"
#define SOAP_DEF_ENC_OPT  	"Use"
#define SOAP_ROUTER		"router"
#define SOAP_ROLE  		"role"
#define SOAP_WSSE		"WS-SEC"
#define SOAP_PLINK		"GeneratePartnerLink"

caddr_t
ws_get_opt (caddr_t * opts, char *opt_name, char * def)
{
  unsigned int inx;
  for (inx = 0; inx < (ARRAYP(opts) ? BOX_ELEMENTS(opts) : 0); inx += 2)
    {
       if (DV_STRINGP (opts [inx]) && DV_STRINGP (opts [inx+1])
	   && !strcmp (opts [inx], opt_name))
	 {
	   return opts [inx+1];
	 }
    }
  return def;
}

#define ws_soap_get_opt(opts,opt_name,def) ws_get_opt (opts,opt_name,def)

int
soap_get_opt_flag (caddr_t * opts, char *opt_name)
{
  char * opt = ws_soap_get_opt (opts, opt_name, "no");
  switch (opt[0])
    {
      case 'Y':
      case 'y':
	  return 1;
      default:
	  return 0;
    }
}

static caddr_t
ws_soap_service_name (ws_connection_t *ws, char * opt_name, char * def)
{
  caddr_t * opts = ws && ws->ws_map ? ws->ws_map->hm_soap_opts : NULL;
  return ws_soap_get_opt (opts, opt_name, def);
}

#define SERVICE_NAME(ws) \
  ws_soap_service_name (ws, SOAP_SERVICE_NAME, (ws)->ws_p_path[0])
#define SERVICE_SCHEMA_NAME(ws) \
  ws_soap_service_name (ws, SOAP_NS, "http://openlinksw.com/virtuoso/soap/schema")
#define SOAP_OPTIONS(ws) \
  (ws && ws->ws_map ? ws->ws_map->hm_soap_opts : NULL)
#define SOAP_TYPES_SCH(o) ws_soap_get_opt(o, SOAP_DT_SCH, "services.wsdl")
#define SOAP_PRINT_ACTION(o) ws_soap_get_opt(o, SOAP_ACTION, "yes")
#define SOAP_SCH_ELEM_QUAL(o) ws_soap_get_opt(o, "elementFormDefault", NULL)
#define SOAP_HEADER_NAMESPACE(o) ws_soap_get_opt(o, SOAP_HDR_NS, NULL)
#define SOAP_USE_ESCAPES(o) ws_soap_get_opt(o, SOAP_ESCAPES, NULL)
#define SOAP_FAULT_NAMESPACE(o) ws_soap_get_opt(o, SOAP_FAULT_NS, NULL)
#define SOAP_DEF_ENC(o) (0 == strcmp (ws_soap_get_opt(o, SOAP_DEF_ENC_OPT, "encoded"), "literal") ? \
    			(SOAP_MSG_LITERALW|SOAP_MSG_LITERAL) : 0)
#else
#define SERVICE_NAME(ws) \
  ((ws)->ws_p_path[0])
#define SERVICE_SCHEMA_NAME(ws) \
    "http://openlinksw.com/virtuoso/soap/schema"
#define SOAP_OPTIONS(ws) NULL
#define SOAP_TYPES_SCH(o)  "services.wsdl"
#define SOAP_PRINT_ACTION(o) "yes"
#define SOAP_SCH_ELEM_QUAL(o)  NULL
#define SOAP_HEADER_NAMESPACE(o) NULL
#define SOAP_USE_ESCAPES(o)  NULL
#define SOAP_FAULT_NAMESPACE(o) NULL
#define SOAP_DEF_ENC(o) 0
#endif

#define IS_SOAP_SERVICE_PARAM(s) \
        (!stricmp(s, "ws_soap_headers") || \
	 !stricmp(s, "ws_http_headers") || \
	 !stricmp(s, "ws_soap_attachments") || \
	 !stricmp(s, "all_params_xml") || \
	 !stricmp(s, "ws_soap_request") || \
	 !stricmp(s, "ws_xmla_xsd") || \
	 !stricmp(s, "SELF") || \
	 !stricmp(s, "uddi_req"))

static caddr_t
soap_sqt_to_soap_type (sql_type_t *sqt, caddr_t soap_type, caddr_t * opts,
    const char * op_name, const char * fld_name)
{
  caddr_t ret;
  caddr_t ns_to_be = SOAP_TYPES_SCH (opts);
  if (soap_type)
    return box_dv_short_string (soap_type);

  if (!sqt->sqt_class && !(sqt->sqt_tree && fld_name && op_name))
    return box_dv_short_string (dtp_to_soap_type (sqt->sqt_dtp));

  if (sqt->sqt_class && sqt->sqt_class->scl_soap_type)
    return box_dv_short_string (sqt->sqt_class->scl_soap_type);

  if (sqt->sqt_class)
    {
      ret = dk_alloc_box (strlen (sqt->sqt_class->scl_name_only) + strlen (ns_to_be) + 2, DV_STRING);
      snprintf (ret, box_length (ret), "%s:%s", ns_to_be, sqt->sqt_class->scl_name_only);
    }
  else /* sqt_tree ; checked earlier */
    {
      ret = dk_alloc_box (strlen (fld_name) + strlen (ns_to_be) + strlen (op_name) + 5, DV_STRING);
      snprintf (ret, box_length (ret), "%s:%s_%s_t", ns_to_be, op_name, fld_name);
    }
  return ret;
}


static caddr_t *
soap_xml_params_to_array (query_t *proc_qry, caddr_t *method,
    caddr_t *err_ret, caddr_t *call_text, caddr_t headers, caddr_t lines, soap_ctx_t * ctx,
    caddr_t *xml_tree)
{
  int npars = dk_set_length (proc_qry->qr_parms);
  int n_set = 0, n_parm = 0;
  caddr_t *params = NULL;
  int inx = 0, inx1;
  char tmp[20];
  char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN], m[MAX_QUAL_NAME_LEN] = {0};
  int literal = (proc_qry->qr_proc_place & SOAP_MSG_LITERAL);
  char * operation_name = n;
  dbe_schema_t *sc = isp_schema (NULL);
  sql_class_t * udt = NULL;
  sql_method_t *mtd = NULL;

  if (proc_qry->qr_udt_mtd_info && DV_TYPE_OF (proc_qry->qr_udt_mtd_info[0]) == DV_LONG_INT)
    {
      ptrlong mtd_id  = unbox (proc_qry->qr_udt_mtd_info[0]);
      ptrlong mtd_index = unbox (proc_qry->qr_udt_mtd_info[1]);
      udt = sch_id_to_type (sc, (long) mtd_id);

      if (!udt || mtd_index < 0 || !udt->scl_method_map || mtd_index > UDT_N_METHODS (udt))
	{
          *err_ret = srv_make_new_error ("37000", "SP006", "Invalid class for the method definition");
	  goto error_end;
	}

      mtd = &(udt->scl_methods[mtd_index]);

      if (!mtd || mtd->scm_type == UDT_METHOD_CONSTRUCTOR)
	{
          *err_ret = srv_make_new_error ("37000", "SP007", "No such method defined.");
	  goto error_end;
	}

      snprintf (m, sizeof (m), "%s\"%s\"", (mtd->scm_type != UDT_METHOD_STATIC ? "()." : "::"), mtd->scm_name);
      if (mtd->scm_type == UDT_METHOD_INSTANCE) /* SELF is not counted */
        npars--;
    }

  params = (caddr_t *) dk_alloc_box_zero (2 * npars * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  ctx->raw_attachments = (proc_qry->qr_proc_place & SOAP_MSG_IN);
  if (!ctx->raw_attachments)
    ctx->raw_attachments = (proc_qry->qr_proc_place & SOAP_MMSG_IN);
  if (!udt)
    sch_split_name ("WS", proc_qry->qr_proc_name, q, o, n);
  else
    sch_split_name ("WS", udt->scl_name, q, o, n);

  *call_text = dk_alloc_box_zero (strlen (q) + strlen (o) + strlen (n) + strlen (m) + 12 + 12 + npars * 2,
      DV_SHORT_STRING);

  if (!udt)
    snprintf (*call_text, box_length (*call_text), "\"%s\".\"%s\".\"%s\"(", q, o, n);
  else
    snprintf (*call_text, box_length (*call_text), "METHOD CALL \"%s\".\"%s\".\"%s\"%s(", q, o, n, m);


  DO_SET (state_slot_t *, proc_param, &proc_qry->qr_parms)
    {
      dtp_t param_type = proc_param->ssl_dtp;
      char *param_name = proc_param->ssl_name;
      int parm_enc = literal;

      if (param_name && udt && mtd && mtd->scm_type == UDT_METHOD_INSTANCE && !strnicmp ("SELF", param_name, 4))
	{
	  n_parm += 1;
	  continue;
	}

      snprintf (tmp, sizeof (tmp), ":%d", inx / 2);
      strcat_box_ck (*call_text, "?,");
      params[inx++] = box_string (tmp);
      if (param_name && !strnicmp ("ws_soap_headers", param_name, 15))
	{
	  params[inx] = box_copy_tree (headers);
	  n_set++;
	}
      else if (param_name && !strnicmp ("ws_http_headers", param_name, 15))
	{
	  params[inx] = box_copy_tree (lines);
	  n_set++;
	}
      else if (param_name && !strnicmp ("ws_soap_attachments", param_name, 19))
	{
	  params[inx] = ctx->attachments ? box_copy_tree ((box_t) ctx->attachments) : NEW_DB_NULL;
	  n_set++;
	}
      else if (param_name &&
	  (!strnicmp ("uddi_req", param_name, 8) ||
	   !strnicmp ("all_params_xml", param_name, 14)))
	{
	  caddr_t *tree = (caddr_t *)dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  tree[0] = list (1, uname__root);
	  tree[1] = box_copy_tree ((box_t) method);
	  params[inx] = (caddr_t)tree;
	  n_set++;
	}
      else if (param_name && !strnicmp ("ws_soap_request", param_name, 15))
	{
	  params[inx] = box_copy_tree ((caddr_t)xml_tree);
	  n_set++;
	}
      else if (proc_param->ssl_type == SSL_REF_PARAMETER_OUT)
	{
	  params[inx] = dk_alloc_box (0, DV_DB_NULL);
	  n_set++;
	  if (IS_SOAP_MSG_FAULT (proc_qry->qr_parm_place[n_parm]) && ctx->soap_version > 1)
	    ctx->faults++;
	}
      else if (IS_SOAP_MSG_HEADER (proc_qry->qr_parm_place[n_parm]) && ctx->soap_version > 1)
	{
	  int is_set = 0;
	  params[inx] = NULL;
	  DO_BOX (caddr_t *, xml_param, inx1, (caddr_t *)headers)
	    {
	      if (inx1 > 0 && DV_TYPE_OF (xml_param) == DV_ARRAY_OF_POINTER)
		{
		  caddr_t role = xml_find_attribute (xml_param, "role", SOAP_TYPE_SCHEMA12);
		  char *szName = XML_ELEMENT_NAME (xml_param);
		  char *szFullName = szName;
		  char *colon = strrchr (szName, ':');
		  const char * use = SOAP_OPT (USE, proc_qry, n_parm, NULL);
		  SOAP_USE (use, parm_enc, literal);

		  if (ctx->soap_version == 12 && !role)
		    role = SOAP_ROLE_ULTIMATE;

		  if (role && !strcmp (role, SOAP_ROLE_NONE))
		    continue;

		  if (role)
		    {
		      /* router MUST not be ultimate */
		      if (ctx->is_router && !strcmp (role, SOAP_ROLE_ULTIMATE))
			continue;
		      /* if not is next, ultimate or self, then this is not for this node */
		      if (strcmp (role, SOAP_ROLE_NEXT) &&
			  strcmp (role, SOAP_ROLE_ULTIMATE) &&
			  (!ctx->role_url || strcmp (role, ctx->role_url))
			  )
			continue;
		    }

		  if (colon)
		    szName = colon + 1;
		  if (!stricmp (szName, param_name) ||
		       (parm_enc && !strcmp (szFullName, proc_qry->qr_parm_alt_types[n_parm]))
		     )
		    {
		      if (proc_qry->qr_parm_alt_types[n_parm])
			params[inx] = soap_box_xml_entity_validating_1 (xml_param, err_ret,
			    proc_qry->qr_parm_alt_types[n_parm], parm_enc, ctx,
			    &(proc_param->ssl_sqt));
		      else if (IS_COMPLEX_SQT (proc_param->ssl_sqt))
			params[inx] = soap_box_xml_entity_validating_1 (xml_param, err_ret,
			    "", parm_enc, ctx,
			    &(proc_param->ssl_sqt));
		      else
			params[inx] = soap_box_xml_entity (xml_param, err_ret, param_type, ctx->soap_version);
		      if (!*err_ret)
			{
			  is_set = 1;
			  n_set++;
			}
		      break;
		    }
		}
	    }
	  END_DO_BOX;

	  if (!is_set)
	    {
	      params[inx] = dk_alloc_box (0, DV_DB_NULL);
	      n_set++;
	    }

	  if (*err_ret)
	    break;
	}
      else
	{
	  int is_set = 0;
	  params[inx] = NULL;
	  DO_BOX (caddr_t *, xml_param, inx1, method)
	    {
	      if (inx1 > 0 && DV_TYPE_OF (xml_param) == DV_ARRAY_OF_POINTER)
		{
		  char *szFullName = XML_ELEMENT_NAME (xml_param);
		  char *colon = strrchr (szFullName, ':');
		  char *szName = szFullName;

		  if (colon)
		    {
		      szName = colon + 1;
#if 0
		      if (proc_qry->qr_parm_alt_types[n_parm] &&
			  strncmp (proc_qry->qr_parm_alt_types[n_parm], szFullName,
			    colon - szFullName))
			break;
#endif
		    }
		  if (!stricmp (szName, param_name) ||
		      ((SOAP_MSG_LITERAL & proc_qry->qr_proc_place) &&
		        proc_qry->qr_parm_alt_types[n_parm] &&
		        !strcmp (proc_qry->qr_parm_alt_types[n_parm], szFullName)))
		    {
	              if (IS_SOAP_MSG_SET (proc_qry->qr_parm_place[n_parm], SOAP_MSG_XML))
			{
			  caddr_t *tree = (caddr_t *)dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
			  tree[0] = list (1, uname__root);
			  tree[1] = box_copy_tree ((box_t) xml_param);
			  params[inx] = (caddr_t)tree;
			}
		      else if (proc_qry->qr_parm_alt_types[n_parm])
			params[inx] = soap_box_xml_entity_validating_1 (xml_param, err_ret,
			    proc_qry->qr_parm_alt_types[n_parm], literal, ctx,
			    &(proc_param->ssl_sqt));
		      else if (IS_COMPLEX_SQT (proc_param->ssl_sqt))
			params[inx] = soap_box_xml_entity_validating_1 (xml_param, err_ret,
			    "", literal, ctx,
			    &(proc_param->ssl_sqt));
		      else
			params[inx] = soap_box_xml_entity (xml_param, err_ret, param_type, ctx->soap_version);
		      if (!*err_ret)
			{
			  n_set++;
			  is_set = 1;
			}
		      break;
		    }
		}
	    }
	  END_DO_BOX;

	  if (!is_set && !*err_ret && proc_qry->qr_parm_default && proc_qry->qr_parm_default[n_parm])
	    {
	      params[inx] = box_copy_tree (proc_qry->qr_parm_default[n_parm]);
	      n_set++;
	    }

	  if (*err_ret)
	    break;
	}
      if (proc_qry->qr_parm_alt_types[n_parm])
	soap_wsdl_schema_push (&(ctx->ns_set), &(ctx->types_set), proc_qry->qr_parm_alt_types[n_parm],
	    parm_enc, 0, NULL, ctx);
      else if (IS_COMPLEX_SQT (proc_param->ssl_sqt))
	{
	  caddr_t scl_soap_type = soap_sqt_to_soap_type (&(proc_param->ssl_sqt), NULL,
	      ctx->opts, operation_name, proc_param->ssl_name);
	  soap_wsdl_schema_push (&(ctx->ns_set), &(ctx->types_set), scl_soap_type,
	      parm_enc, 0, &(proc_param->ssl_sqt), ctx);
	  dk_free_box (scl_soap_type);
	}
      inx++;
      n_parm += 1;
    }
  END_DO_SET ();

  if (proc_qry->qr_proc_alt_ret_type)
    soap_wsdl_schema_push (&(ctx->ns_set), &(ctx->types_set), proc_qry->qr_proc_alt_ret_type,
	literal, 0, NULL, ctx);

  if (n_set < npars && !*err_ret)
    *err_ret = srv_make_new_error ("37000", "SP008", "Not enough input parameters in a SOAP request");

error_end:
  if (*err_ret)
    {
      dk_free_tree ((box_t) params);
      dk_free_box (*call_text);
      *call_text = NULL;
      params = NULL;
    }
  else
    (*call_text)[strlen(*call_text) - (n_set ? 1 : 0)] = ')';
  return params;
}

static int
soap_check_headers (query_t *proc_qry, caddr_t *headers, int soap_version,
    		    caddr_t lines, soap_ctx_t * ctx, caddr_t *err_ret, dk_session_t * ses)
{
  int n_parm, inx1;
  caddr_t * opts = ctx->opts;
  char * header_ns = SOAP_HEADER_NAMESPACE(opts);
  int literal = (proc_qry->qr_proc_place & SOAP_MSG_LITERAL);
  int parm_enc = literal;

  if (soap_version < 11)
    return 1;

  DO_BOX (caddr_t *, xml_param, inx1, headers)
    {
      if (inx1 > 0 && DV_TYPE_OF (xml_param) == DV_ARRAY_OF_POINTER)
	{
	  int found = 0, must_understand;
	  caddr_t szMustUnderstand = xml_find_attribute (xml_param, "mustUnderstand", SOAP_URI (soap_version));
	  caddr_t actor = xml_find_attribute (xml_param, "actor", SOAP_TYPE_SCHEMA11);
	  caddr_t role = xml_find_attribute (xml_param, "role", SOAP_TYPE_SCHEMA12);
	  char *szName = XML_ELEMENT_NAME (xml_param);
	  char *szFullName = szName;
	  char *colon = strrchr (szName, ':');

	  must_understand = xml_get_boolean (szMustUnderstand);

	  if (must_understand < 0)
	    {
	      *err_ret = ws_soap_error (ses, "300", "22023", "env:mustUnderstand value is not boolean",
		  			soap_version, 0, NULL, ctx);
	      return 0;
	    }

	  /* "none" means no role; should not be processed */
	  if (role && !strcmp (role, SOAP_ROLE_NONE))
	    continue;

	  if (colon)
	    {
	      szName = colon + 1;
	    }
	  n_parm = 0;
	  DO_SET (state_slot_t *, proc_param, &proc_qry->qr_parms)
	    {
	      char *param_name = proc_param->ssl_name;
	      const char * use = SOAP_OPT (USE, proc_qry, n_parm, NULL);
	      const char * ns = SOAP_OPT (REQ_NS, proc_qry, n_parm, header_ns);
	      SOAP_USE (use, parm_enc, literal);

	      if (IS_SOAP_MSG_HEADER (proc_qry->qr_parm_place[n_parm]) &&
		  (!stricmp (szName, param_name) ||
		   (parm_enc && !strcmp (szFullName, proc_qry->qr_parm_alt_types[n_parm]))
		   )
		  )
		{
		  /* check NS here if present */
		  if (colon && ns && colon > szFullName && strncmp (ns, szFullName, (size_t)(colon - szFullName)))
		    {
		      *err_ret = ws_soap_error (ses, "300", "22023", "Invalid header request namespace.",
			  soap_version, 0, NULL, ctx);
		      goto invalid_ns;
		    }

		  found = 1;
		  break;
		}
	      n_parm++;
	    }
	  END_DO_SET ();
invalid_ns:
	  if (!found && must_understand)
	    {
	      if (soap_version <= 11 && (!actor || !strcmp (actor, SOAP_ACTOR_FIRST)))
	        return 0;
	      else if (soap_version == 12 &&
		  	(!role ||
			 !strcmp (role, SOAP_ROLE_ULTIMATE) ||
			 !strcmp (role, SOAP_ROLE_NEXT) ||
			 (ctx->role_url && !strcmp (role, ctx->role_url))
			)
		      )
		{
		  ctx->not_understood = xml_param;
		  return 0;
		}
	    }
	}
    }
  END_DO_BOX;
  return 1;
}

static int
proc_is_granted (query_t * proc, oid_t group, oid_t user)
{
  dk_hash_t *ht = proc->qr_proc_grants;
  if (ht)
    {
      if (sec_user_is_in_hash (ht, group, -1) ||
          sec_user_is_in_hash (ht, user, -1))
	return 1;
    }
  if (QR_IS_MODULE_PROC (proc))
    return proc_is_granted (proc->qr_module, group, user);
  return 0;
}

/* Collect all QRs suitable for
   given endpoint
 */
int sec_udt_check (sql_class_t * udt, oid_t group, oid_t user, int op);

static dk_set_t
get_granted_qrs (client_connection_t * cli, query_t * module, char * qpref, size_t qpref_len)
{
  dk_set_t set = NULL;
  user_t * user = cli->cli_user;
  dbe_schema_t *sc = isp_schema (NULL);
  caddr_t err_sql = NULL;
  id_casemode_hash_iterator_t it;
  query_t **ptp;
  ws_connection_t *ws = cli->cli_ws;

  if (!cli || !cli->cli_user)
    return NULL;

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);
  while (id_casemode_hit_next (&it, (caddr_t *) & ptp))
    {
      query_t *proc = *ptp;

      if (!proc
	  || (module && proc->qr_module != module)
	  || !sec_proc_check (proc, user->usr_g_id, user->usr_id))
	continue;

      if ((!qpref || strnicmp (proc->qr_proc_name, qpref, qpref_len)) &&
	  !proc_is_granted (proc, cli->cli_user->usr_g_id, cli->cli_user->usr_id))
	continue;

      if (proc->qr_to_recompile)
	{
	  proc = qr_recompile (proc, &err_sql);
	  if (err_sql)
	    {
	      dk_free_tree (err_sql);
	      err_sql = NULL;
	      continue;
	    }
	}
      dk_set_push (&set, (void*)proc);
    }

  if (ws && ws->ws_map)
    {
      caddr_t htkey = ws->ws_map->hm_htkey;
      id_hash_t **ht = (id_hash_t **) id_hash_get (ht_soap_sup, (caddr_t) & htkey);
      caddr_t ** ptp, **key;
      id_hash_iterator_t it;

      if (ht)
	{
	  id_hash_iterator (&it, *ht);
	  while (hit_next (&it, (caddr_t *) & key, (caddr_t *) & ptp))
	    {
	      caddr_t udt_name = (caddr_t)*key;
	      query_t * proc;
	      sql_class_t * udt = sch_name_to_type (isp_schema (NULL), udt_name);
	      int inx;

	      if (!udt || !sec_udt_check (udt, cli->cli_user->usr_g_id, cli->cli_user->usr_id, GR_EXECUTE))
		continue;
	      DO_BOX (sql_method_t *, mtd, inx, udt->scl_method_map)
		{
		  proc = mtd->scm_qr;
		  if (mtd->scm_type != UDT_METHOD_CONSTRUCTOR && NULL != proc)
		    dk_set_push (&set, (void*)proc);
		}
	      END_DO_BOX;
	    }
	}
    }
  return set;
}

static query_t *
proc_find_in_grants (char * name, dk_set_t * qrs, char * soap_action)
{
  query_t *res = NULL;
  char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  int found = 0, exact = 0;

  if (!name)
    return NULL;

  DO_SET (query_t *, proc, qrs)
    {
      const char * action, *op_name;
      action = SOAP_OPT (ACTION, proc, -1, NULL);
      op_name = SOAP_OPT (OPERATION, proc, -1, NULL);
      sch_split_name ("", proc->qr_proc_name, q, o, n);

      if (soap_action && soap_action[0] != 0)
	{
	  if ((op_name && !strcmp (op_name, name)) || !strcmp (n, name))
	    {
	      if (action && !strcmp (action, soap_action))
		{
		  res = proc;
		  exact++;
		  found++;
		}
	      else
		{
		  if (!found)
		    res = proc;
		  found++;
		}
	    }
	}
      else
	{
	  if ((op_name && !strcmp (op_name, name)) || !strcmp (n, name))
	    {
	      if (!found)
		res = proc;
	      found++;
	    }
	}
    }
  END_DO_SET()

  if (found <= 1 || exact == 1) /* exact one match; OK */
    return res;
  else
    return NULL; /* too many with same name; error */
}

static caddr_t
xml_find_global_attribute (caddr_t *entity, const char *szName, const char *szURI)
{
  caddr_t attr = NULL;
  dtp_t dtp = DV_TYPE_OF (entity);
  attr = xml_find_attribute (entity, szName, szURI);
  if (attr)
    return attr;
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int inx = 0, len = BOX_ELEMENTS (entity);
      for (inx = 1; inx < len; inx++)
	{
	  attr = xml_find_global_attribute ((caddr_t *) entity[inx], szName, szURI);
	  if (attr)
	    return attr;
	}
    }
  return NULL;
}

static char *
soap_get_run_time_schema (soap_ctx_t * ctx, const char * tgt_name, caddr_t *schema_tree)
{
  int inx;
  const char * colon = strrchr (tgt_name, ':');
  size_t offs = colon ? colon - tgt_name : 0;
  caddr_t * sch = ctx->custom_schema;

  if (!sch)
    goto err_end;
  if (!colon)
    colon = tgt_name;
  else
    colon++;

  DO_BOX(caddr_t *, elm, inx, sch)
    {
      xml_tree_ent_t *xe;
      caddr_t * schema;
      caddr_t type_name, tns;
      const char *elt_name;
      if (DV_XML_ENTITY != DV_TYPE_OF (elm))
	continue;
      xe = (xml_tree_ent_t *) elm;
      if (!(ARRAYP(xe->xte_current) && BOX_ELEMENTS(xe->xte_current) > 1))
	continue;
      schema = (caddr_t *)(xe->xte_current[1]);
      elt_name = XML_ELEMENT_NAME (schema);
      if (elt_name && !strcmp (elt_name, SOAP_TAG_DT_ELEMENT))
	continue;
      type_name = xml_find_schema_attribute (schema, "name");
      tns = xml_find_schema_attribute (schema, "targetNamespace");
      if (type_name && !strcmp (type_name, colon) &&
	  (!tns || !offs || !strncmp (tns, tgt_name, offs)))
	{
	  if (schema_tree)
	    {
	      *schema_tree = (caddr_t)schema;
	      ctx->req_resp_namespace = tns;
	    }
	  return type_name;
	}

    }
  END_DO_BOX;
err_end:
  if (schema_tree)
    *schema_tree = NULL;
  return NULL;
}

static void
soap_raw_attachments (soap_ctx_t * ctx, caddr_t box)
{
  int inx;
  if (!ARRAYP (box))
    return;
  DO_BOX(caddr_t, elm, inx, (caddr_t *)box)
    {
      if (ARRAYP(elm) && BOX_ELEMENTS (elm) > 2)
	{
	  dk_set_push (&ctx->o_attachments, (void*)box_copy_tree (elm));
	}
    }
  END_DO_BOX;
}

static caddr_t
soap_find_doc_literal (caddr_t *body, caddr_t *header, dk_set_t * qrs, const char * qual, const char * owner, caddr_t *opts, int *use_literal)
{
  char * operation_name, q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  int ix, found = 0, inx, distance = 0, conflicts = 0, pref_len;
  char qpref [MAX_QUAL_NAME_LEN];
  caddr_t best_match = NULL;

  snprintf (qpref, sizeof (qpref), "%s.%s.", qual, owner);
  pref_len = (int) strlen (qpref);

  DO_SET (query_t *, proc, qrs)
    {
      int in_body, in_header, is_def_oper;

      if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	operation_name = proc->qr_proc_name + pref_len;
      else
	{
          sch_split_name (qual, proc->qr_proc_name, q, o, n);
	  operation_name = n;
	}
      if ((proc->qr_proc_place & SOAP_MSG_LITERAL) != SOAP_MSG_LITERAL)
	continue;

      is_def_oper = (int) unbox ((box_t) SOAP_OPT (DEFAULT_OPER, proc, -1, 0));
      ix = 0; inx = 0; found = 0; in_body = 0, in_header = 0;
      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	{
	  caddr_t custom_type = proc->qr_parm_alt_types[inx];
	  caddr_t place = proc->qr_parm_place[inx];
	  caddr_t def = proc->qr_parm_default ? proc->qr_parm_default[inx] : NULL;

	  if (custom_type && ssl->ssl_type != SSL_REF_PARAMETER_OUT &&
	      !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	      !IS_SOAP_MSG_FAULT(place))
	    {
	      caddr_t * xml_param;
	      if (IS_SOAP_MSG_HEADER (place))
		{
		  if (NULL != (xml_param = xml_find_exact_child (header, custom_type, 0)))
		    in_header ++;
		}
	      else
		{
		  if (NULL != (xml_param = xml_find_exact_child (body, custom_type, 0)))
		    in_body ++;
		}

	      if (xml_param || (IS_SOAP_MSG_HEADER (place) && def))
		found++;

	      ix++;
	    }
	  inx++;
	}
      END_DO_SET ();
      if (found == ix)
	{
	  int matched = in_body + in_header;
	  int have_in_body = (NULL != xml_find_child (body, NULL, NULL, in_body++, 0));
	  int have_in_header = (NULL != xml_find_child (header, NULL, NULL, in_header++, 0));

          /*fprintf (stderr, "%s in_body=%d in_header=%d have_in_body=%d have_in_header=%d\n", operation_name, in_body-1, in_header-1, have_in_body, have_in_header);*/

	  if (found == matched && !have_in_body && !have_in_header)
	    {
	      /*fprintf (stderr , "exact match\n");*/
	      conflicts = 0;
	      *use_literal = 1;
	      dk_free_tree (best_match);
	      return box_dv_short_string (operation_name); /* must be freed */
	    }
	  else if (found && !best_match && is_def_oper)
	    {
	      /*fprintf (stderr , "default operation\n");*/
	      best_match = box_dv_short_string (operation_name);
	    }
	  else if ((!distance || distance < matched) && !have_in_body)
	    {
	      /*fprintf (stderr , "new best found\n");*/
	      conflicts = 0;
	      dk_free_tree (best_match);
	      best_match = box_dv_short_string (operation_name);
	      distance = matched;
	    }
	  else if (distance && distance == matched)
	    {
	      conflicts ++;
	    }
	}
    }
  END_DO_SET ()

  if (NULL != best_match)
    *use_literal = 1;
  /*fprintf (stderr, "best is returned: %s dist:%d\n", best_match, distance);*/
  if (!conflicts)
    return best_match;
  else
    {
      /*fprintf (stderr, "Conflicting rpc found\n");*/
      dk_free_tree (best_match);
      return NULL;
    }
}

caddr_t con_soap_fault_name = NULL;
caddr_t con_soap_blob_limit_name = NULL;

static caddr_t
con_soap_get (client_connection_t * cli, caddr_t name)
{
  caddr_t *ret = (caddr_t *)id_hash_get (cli->cli_globals, (caddr_t) &name);
  if (ret && DV_DB_NULL != DV_TYPE_OF (*ret))
    return *ret;
  return NULL;
}

static int
soap12_custom_error (dk_session_t * ses, client_connection_t * cli, soap_ctx_t * ctx,
    query_t * proc_qry, local_cursor_t * lc,
    caddr_t * fault_err, int * http_resp_code, caddr_t * err_ret)
{
  char tmp [4095];
  caddr_t *proc_ret = (caddr_t *)lc->lc_proc_ret;
  int nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);
  int inx = 2;
  int ix = 0;
  caddr_t message = BOX_ELEMENTS (fault_err) > 1 ? fault_err[1] : NULL;
  const char *code = (BOX_ELEMENTS (fault_err) && alldigits (fault_err[0]) ? fault_err[0] : "400");
  int len = code ? (int) strlen (code) : 0;
  int mcode = (len > 0 ? code[0] : '3') - '0';
  int scode = (len > 1 ? code[1] : '0') - '0';
  char * code1 = soap12_errors[0], *code2 = soap12_sub_errors[0];

  if (mcode >= 0 && mcode < (sizeof (soap12_errors) / sizeof (char*)))
    code1 = soap12_errors[mcode];

  if (scode >= 0 && scode < (sizeof (soap12_sub_errors) / sizeof (char*)))
    code2 = soap12_sub_errors[scode];


  snprintf (tmp, sizeof (tmp),
      "\n<SOAP:Fault xmlns:rpc='%s' xmlns:enc='%s'>"
      "\n  <SOAP:Code>"
      "\n    <SOAP:Value>SOAP:%s</SOAP:Value>"
      "%s%s%s"
      "\n  </SOAP:Code>"
      "\n<SOAP:Reason>"
      "\n<SOAP:Text xml:lang='%s'>",
      SOAP_RPC_SCHEMA12, SOAP_ENC_SCHEMA12,
      code1,
      code2 ? "\n<SOAP:Subcode>\n<SOAP:Value>" : "",
      code2 ? code2 : "",
      code2 ? "</SOAP:Value>\n</SOAP:Subcode>" : "",
      server_default_language_name);

  SES_PRINT (ses, tmp);

  if (message && DV_STRINGP (message))
    {
      dks_esc_write (ses, message, strlen (message),
	  CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
    }
  else
    SES_PRINT (ses, "[Virtuoso SOAP server] Unknown Error");

  SES_PRINT (ses, "</SOAP:Text>\n</SOAP:Reason>\n<SOAP:Detail>");

  DO_SET (state_slot_t *, parm, &proc_qry->qr_parms)
    {
      if (parm && IS_SSL_REF_PARAMETER (parm->ssl_type) && inx < nProcRet &&
	  IS_SOAP_MSG_FAULT (proc_qry->qr_parm_place[ix]) &&
	  DV_DB_NULL != DV_TYPE_OF (proc_ret[inx]))
	{
	  if (soap_print_xml_entity (proc_ret[inx], ses, cli))
	    ;
	  else if (proc_qry->qr_parm_alt_types[ix])
	    {
	      const char * use = SOAP_OPT (USE, proc_qry, ix, NULL);
	      int parm_enc, save_literal = ctx->literal;

	      SOAP_USE (use, parm_enc, ctx->literal);
	      ctx->add_schema = 0;
	      ctx->add_type = (parm_enc ? 0 : 1);
	      ctx->literal = parm_enc;
	      ctx->req_resp_namespace = SOAP_OPT (RESP_NS, proc_qry, ix, SOAP_FAULT_NAMESPACE(ctx->opts));
	      soap_print_box_validating (proc_ret[inx],
		  SOAP_OPT (PART_NAME, proc_qry, ix, parm->ssl_name),
		  ses, err_ret, proc_qry->qr_parm_alt_types[ix], ctx, parm_enc, 1,
		  &(parm->ssl_sqt));
	      ctx->literal = save_literal;
	    }

	  if (*err_ret)
	    return 0;
	}
      inx++;
      ix++;
    }
  END_DO_SET();
  SES_PRINT (ses, "\n</SOAP:Detail>\n</SOAP:Fault>\n");
  return 1;
}


static int
soap_custom_error (dk_session_t * ses, client_connection_t * cli, soap_ctx_t * ctx,
    query_t * proc_qry, local_cursor_t * lc,
    caddr_t * fault_err, int * http_resp_code, caddr_t * err_ret)
{
  caddr_t *proc_ret = (caddr_t *)lc->lc_proc_ret;
  int nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);
  int inx = 2;
  int ix = 0, found = 0;
  caddr_t message = BOX_ELEMENTS (fault_err) > 1 ? fault_err[1] : NULL;
  const char *code = BOX_ELEMENTS (fault_err) ? soap_11_error (fault_err[0], 0) : soap_11_error ("400", 1);

  DO_SET (state_slot_t *, parm, &proc_qry->qr_parms)
    {
      if (parm && IS_SSL_REF_PARAMETER (parm->ssl_type) && inx < nProcRet &&
	  IS_SOAP_MSG_FAULT (proc_qry->qr_parm_place[ix]) &&
	  DV_DB_NULL != DV_TYPE_OF (proc_ret[inx]))
	{
	  if (!found)
	    {
	      SES_PRINT (ses, "<SOAP:Fault>");
	      SES_PRINT (ses, "<faultcode>");
	      SES_PRINT (ses, code);
	      SES_PRINT (ses, "</faultcode>");
	      SES_PRINT (ses, "<faultstring>");
	      if (message && DV_STRINGP (message))
		{
		  dks_esc_write (ses, message, strlen (message),
		      CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
		}
	      else
		SES_PRINT (ses, "[Virtuoso SOAP server] Unknown Error");
	      SES_PRINT (ses, "</faultstring><detail>");
	      found = 1;
	    }
	  if (soap_print_xml_entity (proc_ret[inx], ses, cli))
	    ;
	  else if (proc_qry->qr_parm_alt_types[ix])
	    {
	      const char * use = SOAP_OPT (USE, proc_qry, ix, NULL);
	      int parm_enc, save_literal = ctx->literal;

	      SOAP_USE (use, parm_enc, ctx->literal);
	      ctx->add_schema = 0;
	      ctx->add_type = (parm_enc ? 0 : 1);
	      ctx->literal = parm_enc;
	      ctx->req_resp_namespace = SOAP_OPT (RESP_NS, proc_qry, ix, SOAP_FAULT_NAMESPACE(ctx->opts));
	      soap_print_box_validating (proc_ret[inx],
		  SOAP_OPT (PART_NAME, proc_qry, ix, parm->ssl_name),
		  ses, err_ret, proc_qry->qr_parm_alt_types[ix], ctx, parm_enc, 1,
		  &(parm->ssl_sqt));
	      ctx->literal = save_literal;
	    }

	  if (*err_ret)
	    return 0;
	}
      inx++;
      ix++;
    }
  END_DO_SET();
  if (found)
    {
      SES_PRINT (ses, "</detail></SOAP:Fault>");
      return 1;
    }
  return 0;
}

void
soap_serialize_header (dk_session_t * ses, client_connection_t * cli, query_t * proc_qry,
    local_cursor_t * lc, soap_ctx_t * ctx, caddr_t * err, int uddi, int * http_resp_code)
{
  caddr_t *proc_ret;
  int nProcRet;
  int inx = 2;
  int ix = 0, hdr_end = 0;
  int use_literal = ctx->literal;
  caddr_t * opts = ctx->opts;

  if (!IS_BOX_POINTER (lc->lc_proc_ret) || *err)  /* print the header */
    return;

  proc_ret = (caddr_t *)lc->lc_proc_ret;
  nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);

  /* get custom schema if any defined */
  DO_SET (state_slot_t *, parm, &proc_qry->qr_parms)
    {
      if (!strcmp(parm->ssl_name, "ws_xmla_xsd"))
	{
	  ctx->custom_schema = (caddr_t *)proc_ret[inx];
	  break;
	}
      inx ++;
    }
  END_DO_SET();

  inx = 2;
  DO_SET (state_slot_t *, parm, &proc_qry->qr_parms)
    {
      if (parm && IS_SSL_REF_PARAMETER (parm->ssl_type) && inx < nProcRet &&
	  IS_SOAP_MSG_HEADER (proc_qry->qr_parm_place[ix]) &&
	  DV_DB_NULL != DV_TYPE_OF (proc_ret[inx]))
	{
	  caddr_t err_ret = NULL;
	  if (!hdr_end)
	    SES_PRINT (ses, "<SOAP:Header>");
	  if (soap_print_xml_entity (proc_ret[inx], ses, cli))
	    ;
	  else if (proc_qry->qr_parm_alt_types[ix])
	    {
	      const char * use = SOAP_OPT (USE, proc_qry, ix, NULL);
	      int parm_enc, save_literal = ctx->literal;

	      SOAP_USE (use, parm_enc, use_literal);
	      ctx->add_schema = 0;
	      ctx->add_type = (parm_enc ? 0 : 1);
	      ctx->literal = parm_enc;
	      ctx->req_resp_namespace =
		  SOAP_OPT (RESP_NS, proc_qry, ix, SOAP_HEADER_NAMESPACE (opts));
	      soap_print_box_validating (proc_ret[inx],
		  SOAP_OPT (PART_NAME, proc_qry, ix, parm->ssl_name),
		  ses, &err_ret, proc_qry->qr_parm_alt_types[ix], ctx,
		  parm_enc, 1, &(parm->ssl_sqt));
	      ctx->literal = save_literal;
	    }

	  if (err_ret)
	    {
	      dk_free_tree (*err);
	      *err = ws_soap_error (ses, "400",
		  ERR_STATE (err_ret), ERR_MESSAGE (err_ret), ctx->soap_version, uddi, http_resp_code, ctx);
	      dk_free_tree (err_ret);
	      return;
	    }
	  hdr_end = 1;
	}
      inx++;
      ix++;
    }
  END_DO_SET();
  if (hdr_end)
    SES_PRINT (ses, "</SOAP:Header>");
}

int
soap_serialize_fault (dk_session_t * ses, client_connection_t * cli, query_t * proc_qry, local_cursor_t * lc,
    soap_ctx_t * ctx, caddr_t * err, int uddi, int * http_resp_code)
{
  caddr_t * fault_err = (caddr_t *) con_soap_get (cli, con_soap_fault_name);
  int fault = 0;
  caddr_t err_ret = NULL;

  if (!ARRAYP (fault_err) || !IS_BOX_POINTER (lc->lc_proc_ret) || *err)
    return fault;

  if (ctx->soap_version == 12)
    fault = soap12_custom_error (ses, cli, ctx, proc_qry, lc, fault_err, http_resp_code, &err_ret);
  else
    fault = soap_custom_error (ses, cli, ctx, proc_qry, lc, fault_err, http_resp_code, &err_ret);

  if (err_ret)
    {
      dk_free_tree (*err);
      *err = ws_soap_error (ses, "400",
	  ERR_STATE (err_ret), ERR_MESSAGE (err_ret),
	  ctx->soap_version, uddi, http_resp_code, ctx);
    }
  return fault;
}

void
soap_serialize_parameters (dk_session_t * ses, client_connection_t * cli, query_t * proc_qry, local_cursor_t * lc,
    soap_ctx_t * ctx, caddr_t * err, int uddi, int * http_resp_code, const char * szMethod, const char *szMethodURI)
{
  caddr_t *proc_ret;
  int nProcRet;
  int inx = 2, ix, use_literal = ctx->literal;

  if (!IS_BOX_POINTER (lc->lc_proc_ret) || *err)
    return;

  proc_ret = (caddr_t *)lc->lc_proc_ret;
  nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);

  if (nProcRet > 1)
    {
      /* In case of XML entity do not put a tags */
      caddr_t ret_val = proc_ret[1];
      dtp_t dtp = DV_TYPE_OF (ret_val);
      int is_xml = (dtp == DV_XML_ENTITY);

      if (!uddi || is_xml)
	{
	  char ret_elt_name [MAX_NAME_LEN * 2];
	  char * dot = strchr (szMethod, '.');
          sql_type_t sqt;

	  ddl_type_to_sqt (&sqt, (caddr_t *)proc_qry->qr_proc_ret_type);
	  snprintf (ret_elt_name, sizeof (ret_elt_name), "%sReturn", dot ? dot + 1 : szMethod);
	  if (soap_print_xml_entity (ret_val, ses, cli))
	    ;
	  else if (!proc_qry->qr_proc_alt_ret_type &&
	      DV_TYPE_OF (ret_val) != DV_OBJECT &&
	      DV_TYPE_OF (ret_val) != DV_REFERENCE &&
	      !IS_COMPLEX_SQT(sqt)
	      )
	    {
	      caddr_t err_ret = NULL;
	      ptrlong *rtype = (ptrlong *)proc_qry->qr_proc_ret_type;
	      dtp_t ret_dtp = rtype ? (dtp_t) rtype[0] : 0;

	      if (!use_literal && ctx->soap_version == 12 &&
		  (ret_val != NULL || DV_LONG_INT == ret_dtp)
		 )
		SES_PRINT (ses, "<SOAP-RPC:result>CallReturn</SOAP-RPC:result>");

	      err_ret = soap_print_box (ret_val, ses,
		  is_xml ? NULL : (use_literal ? ret_elt_name : "CallReturn"),
		  ctx->soap_version, (use_literal ? szMethodURI : NULL), ret_dtp, ctx);
	      if (err_ret)
	        {
		  *err = ws_soap_error (ses, "400",
		      ERR_STATE (err_ret), ERR_MESSAGE (err_ret), ctx->soap_version, uddi, http_resp_code, ctx);
		  dk_free_tree (err_ret);
	        }
	    }
	  else
	    {
	      caddr_t err_ret = NULL;
	      const char * tag_name = (is_xml ? NULL : (use_literal ? ret_elt_name : "CallReturn"));
	      caddr_t type_name;

	      tag_name = SOAP_OPT (PART_NAME, proc_qry, -1, tag_name);
	      if (!ctx->custom_schema)
		type_name = proc_qry->qr_proc_alt_ret_type;
	      else
		{ /* when run-time schema is used the encoding like doc/literal */
		  type_name = soap_get_run_time_schema (ctx, tag_name, NULL);
		  ctx->literal = 1;
		}

	      ctx->add_schema = 0;
	      ctx->add_type = (use_literal || ctx->custom_schema || IS_SOAP_RPCLIT(ctx->def_enc) ? 0 : 1);
	      ctx->req_resp_namespace = NULL;

	      if (!use_literal && !ctx->def_enc &&
		  ctx->soap_version == 12 && 0 != stricmp (type_name, SOAP_VOID_TYPE))
		SES_PRINT (ses, "<SOAP-RPC:result>CallReturn</SOAP-RPC:result>");

	      soap_print_box_validating (ret_val, tag_name, ses, &err_ret,
		  type_name, ctx, use_literal, 1, &sqt);

	      if (err_ret)
		{
		  *err = ws_soap_error (ses, "400",
		      ERR_STATE (err_ret), ERR_MESSAGE (err_ret), ctx->soap_version, uddi, http_resp_code, ctx);
		  dk_free_tree (err_ret);
		}
	    }
	}
      else if (uddi && IS_STRING_DTP (dtp))
	SES_PRINT (ses, ret_val);
    }

  if (*err) return;

  ix = 0;
  DO_SET (state_slot_t *, parm, &proc_qry->qr_parms)
    {
      if (parm && IS_SSL_REF_PARAMETER (parm->ssl_type) && inx < nProcRet &&
	  !IS_SOAP_MSG_SPECIAL (proc_qry->qr_parm_place[ix]))
	{
	  caddr_t err_ret = NULL;
	  if (soap_print_xml_entity (proc_ret[inx], ses, cli))
	    ;
	  else if (parm->ssl_name && !strnicmp ("ws_soap_attachments", parm->ssl_name, 19))
	    {
	      /* this is a raw attachments data */
	      soap_raw_attachments (ctx, proc_ret[inx]);
	    }
	  else if (parm->ssl_name && IS_SOAP_SERVICE_PARAM (parm->ssl_name))
	    {
	      /* dummy */;
	    }
	  else if (proc_qry->qr_parm_alt_types[ix] ||
	      DV_TYPE_OF (proc_ret[inx]) == DV_OBJECT ||
	      DV_TYPE_OF (proc_ret[inx]) == DV_REFERENCE ||
	      IS_COMPLEX_SQT (parm->ssl_sqt))
	    {
	      ctx->add_schema = 0;
	      ctx->add_type = (use_literal || IS_SOAP_RPCLIT(ctx->def_enc) ? 0 : 1);
	      ctx->req_resp_namespace = NULL;

	      soap_print_box_validating (proc_ret[inx],
		  SOAP_OPT (PART_NAME, proc_qry, ix, parm->ssl_name),
		  ses, &err_ret, proc_qry->qr_parm_alt_types[ix], ctx, use_literal,
		  1, &(parm->ssl_sqt));
	    }
	  else
	    soap_print_box (proc_ret[inx], ses, parm->ssl_name, ctx->soap_version,
		(use_literal ? szMethodURI : NULL), parm->ssl_dtp, ctx);
	  if (err_ret)
	    {
	      dk_free_tree (*err);
	      *err = ws_soap_error (ses, "400",
		  ERR_STATE (err_ret), ERR_MESSAGE (err_ret), ctx->soap_version, uddi, http_resp_code, ctx);
	      break;
	    }
	}
      inx++;
      ix++;
    }
  END_DO_SET();

  if (*err) return;

  if (proc_qry->qr_proc_place & SOAP_MSG_OUT)
    ctx->con_encoding = WS_ENC_DIME;

  if (proc_qry->qr_proc_place & SOAP_MMSG_OUT)
    ctx->con_encoding = WS_ENC_MIME;
}

void
soap_serialize_body (dk_session_t * ses, client_connection_t * cli, query_t * proc_qry, local_cursor_t * lc,
    soap_ctx_t * ctx, caddr_t * err, int uddi, int * http_resp_code, const char * szMethod, const char *szMethodURI)
{
  int use_literal = ctx->literal;
  if (*err) return;

  if (!uddi && !use_literal)
    {
      if (szMethodURI && !(IS_SOAP_RPCLIT(ctx->def_enc) && ctx->element_form))
	SES_PRINT (ses, "<cli:");
      else
	SES_PRINT (ses, "<");
      SES_PRINT (ses, szMethod);
      SES_PRINT (ses, "Response");

      if (szMethodURI)
	{
	  if (IS_SOAP_RPCLIT(ctx->def_enc) && ctx->element_form)
	    SES_PRINT (ses, " xmlns='");
	  else
	    SES_PRINT (ses, " xmlns:cli='");
	  SOAP_PRINT (RESP_NS, ses, proc_qry, -1, szMethodURI);
	  SES_PRINT (ses, "'");
	}

      if (!use_literal && !ctx->def_enc && ctx->soap_version == 12)
	SES_PRINT (ses, " SOAP:encodingStyle='" SOAP_ENC_SCHEMA12 "'");
      SES_PRINT (ses, ">");
    }

  /* OUTPUT */
  soap_serialize_parameters (ses, cli, proc_qry, lc, ctx, err, uddi, http_resp_code, szMethod, szMethodURI);

  if (*err) return;

  if (!uddi && !use_literal)
    {
      if (szMethodURI && !(IS_SOAP_RPCLIT(ctx->def_enc) && ctx->element_form))
	SES_PRINT (ses, "</cli:");
      else
	SES_PRINT (ses, "</");
      SES_PRINT (ses, szMethod);
      SES_PRINT (ses, "Response>");
    }
}

void uuid_str (char *p, int len);

void
soap_serialize_envelope (dk_session_t * ses, client_connection_t * cli, query_t * qr, local_cursor_t * lc,
    soap_ctx_t * ctx, char * schema_ns, int uddi, int * http_resp_code, caddr_t * err,
    char * szMethod, const char * szMethodURI)
{
  if (!uddi)
    {
      if (ctx->soap_version == 1)
	SES_PRINT (ses,
	    "<?xml version='1.0'?>\n"
	    "<SOAP:Envelope "
	    "xmlns:SOAP=\"" SOAP_TYPE_SCHEMA10 "\" "
	    "xmlns:xsi=\"" W3C_TYPE_SCHEMA_XSI "\" "
	    "xmlns:xsd=\"" W3C_TYPE_SCHEMA_XSD "\" "
	    "xmlns:dt=\"" MS_TYPE_SCHEMA "\" "
	    ">");
      else
	SES_PRINT (ses,
	    "<?xml version='1.0'?>\n"
	    "<SOAP:Envelope ");
      if (!ctx->literal && !ctx->def_enc && ctx->soap_version <= 11)
	SES_PRINT (ses, "SOAP:encodingStyle=\"" SOAP_ENC_SCHEMA11 "\"\n ");

      if (ctx->soap_version <= 11)
	SES_PRINT (ses,  "xmlns:SOAP=\"" SOAP_TYPE_SCHEMA11 "\"\n "
	    "xmlns:SOAP-ENC=\"" SOAP_ENC_SCHEMA11 "\"\n ");
      else if (ctx->soap_version == 12)
	SES_PRINT (ses,  "xmlns:SOAP=\"" SOAP_TYPE_SCHEMA12 "\"\n "
	    "xmlns:SOAP-ENC=\"" SOAP_ENC_SCHEMA12 "\"\n "
	    "xmlns:SOAP-RPC=\"" SOAP_RPC_SCHEMA12 "\"\n "
	    );

      SES_PRINT (ses,
	  "xmlns:xsi=\"" W3C_2001_TYPE_SCHEMA_XSI "\"\n "
	  "xmlns:xsd=\"" W3C_2001_TYPE_SCHEMA_XSD "\"\n "
	  "xmlns:dt=\"" MS_TYPE_SCHEMA "\"\n "
	  "xmlns:ref=\"" SOAP_REF_SCH_200204 "\"\n "
	  );
#if 0
      SES_PRINT (ses,
	  "xmlns:ds=\"" WSS_DSIG_URI "\" \n " 	/* WSS NS decl */
	  "xmlns:xenc=\"" WSS_XENC_URI "\"\n "
	  );
      if (!soap_wsdl_ns_exists (&(ctx->ns_set), WSS_WSS_URI))
	SES_PRINT (ses, "xmlns:wsse=\"" WSS_WSS_URI "\"\n ");
#endif

      soap_wsdl_print_ns_decl (ses, &(ctx->ns_set), NULL);
      SES_PRINT (ses, "xmlns:wsdl='");
      SES_PRINT (ses, schema_ns);
      SES_PRINT (ses, "' >\n");
    }
  else
    {   /* UDDI v1.0 header */
      SES_PRINT (ses,
	  "<?xml version='1.0'?>\n"
	  "<Envelope "
	  "SOAP:encodingType=\"" SOAP_ENC_SCHEMA11 "\" "
	  "xmlns:SOAP=\"" SOAP_TYPE_SCHEMA11 "\" "
	  "xmlns:xsi=\"" W3C_TYPE_SCHEMA_XSI "\" "
	  "xmlns:xsd=\"" W3C_TYPE_SCHEMA_XSD "\" "
	  "xmlns:dt=\"" MS_TYPE_SCHEMA "\" "
	  "xmlns=\"" SOAP_TYPE_SCHEMA11 "\" "
	  ">");
    }

  soap_serialize_header (ses, cli, qr, lc, ctx, err, uddi, http_resp_code);

  if (*err) return;

  if (!uddi)
    {
      SES_PRINT (ses, "<SOAP:Body");
#ifdef _SSL
      if (ctx->is_wsse)
	{
          char p [200], tmp [400];
	  char * ns = soap_wsdl_get_ns_prefix (&(ctx->ns_set), WSU_URI(&(ctx->wsse_ctx)));

	  uuid_str (p, sizeof (p));
	  snprintf (tmp, sizeof (tmp), " %s%sId=\"Id-%s\"", ns ? ns : "", ns ? ":" : "", p);
	  SES_PRINT (ses, tmp);
        }
#endif
      SES_PRINT (ses, ">");
    }
  else
    SES_PRINT (ses, "<Body>");

  if (!soap_serialize_fault (ses, cli, qr, lc, ctx, err, uddi, http_resp_code))
    soap_serialize_body (ses, cli, qr, lc, ctx, err, uddi, http_resp_code, szMethod, szMethodURI);

  if (*err) return;

  if(!uddi)
    SES_PRINT (ses, "</SOAP:Body>");
  else
    SES_PRINT (ses, "</Body>");

  if(!uddi)
    SES_PRINT (ses, "</SOAP:Envelope>");
  else
    SES_PRINT (ses, "</Envelope>");
}

caddr_t
soap_serialize (dk_session_t * ses, client_connection_t * cli, query_t * qr, local_cursor_t * lc,
    soap_ctx_t * ctx, char * schema_ns, int uddi, int * http_resp_code, char * szMethod, const char * szMethodURI)
{
  caddr_t err = NULL;
#ifdef _SSL
  if (ctx->is_wsse)
    {
      soap_wsdl_ns_decl (&(ctx->ns_set), WSS_DSIG_URI, "ds");
      soap_wsdl_ns_decl (&(ctx->ns_set), WSS_XENC_URI, "xenc");
      soap_wsdl_ns_decl (&(ctx->ns_set), WSSE_URI(&(ctx->wsse_ctx)), "wsse");
      soap_wsdl_ns_decl (&(ctx->ns_set), WSU_URI(&(ctx->wsse_ctx)), "wssu");
    }
#endif
  soap_serialize_envelope (ses, cli, qr, lc, ctx, schema_ns, uddi, http_resp_code, &err, szMethod, szMethodURI);
  return err;
}

caddr_t
soap_server (int soap_version, caddr_t method_fld, dk_session_t *ses, caddr_t *xml_tree,
    caddr_t usr_qual, const char *usr_own, caddr_t lines, client_connection_t *cli, int *uddi_action,
    caddr_t *procedure_mappings, char *schema_ns, caddr_t * opts, caddr_t * attachs, int * is_dime,
    caddr_t *qst, int * http_resp_code)
{
  caddr_t err = NULL, err_sql = NULL, soap_action = box_dv_short_string (method_fld);
  char * volatile szMethod = NULL, szFullProcName[2048];
  char *szMethodURI = NULL;
  char *szMethodURIBuffer = NULL;
  char *soap_escapes = SOAP_USE_ESCAPES(opts);
  char *ns = ws_soap_get_opt (opts, SOAP_NS, NULL); /* The namespace of the request as per WSDL */
  char *element_form_default = SOAP_SCH_ELEM_QUAL (opts);
  int use_literal = 0;
  char qpref [MAX_QUAL_NAME_LEN];
  int qpref_len;
  dk_set_t qrs = NULL;
  soap_ctx_t ctx;

  ctx.qst = qst;
  *uddi_action = 0;

  /* Set context for SOAP serialization */
  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.soap_version = soap_version;
  ctx.dks_esc_compat = ((soap_escapes && (soap_escapes[0] == 'y' || soap_escapes[0] == 'Y')) ? DKS_ESC_COMPAT_SOAP/*USE_CR_ESCAPES*/ : 0 /*1*/);
  ctx.attachments = (caddr_t *)(*attachs);
  ctx.def_enc = SOAP_DEF_ENC(opts);
  if (element_form_default && !strcmp (element_form_default, "qualified"))
    ctx.element_form = 1;
  ctx.opts = opts;
  ctx.role_url = ws_soap_get_opt (opts, SOAP_ROLE, NULL);
  ctx.is_router = soap_get_opt_flag (opts, SOAP_ROUTER);
  dk_set_push (&ctx.o_attachments, NULL);
  connection_set (cli, con_soap_fault_name, NULL); /* reset the custom SOAP:Fault handler */
  connection_set (cli, con_soap_blob_limit_name, NULL); /* reset the custom SOAP:Fault handler */
  ctx.cli = cli;

#ifdef _SSL
  ctx.is_wsse = soap_get_opt_flag (opts, SOAP_WSSE);
  xenc_set_serialization_ctx ((caddr_t) opts, &(ctx.wsse_ctx));
#endif


  if (soap_version < 1 || soap_version > 12)
    {
      err = ws_soap_error (ses, "300", "37000",
	"Unsupported SOAP version", 11, *uddi_action, http_resp_code, &ctx);
    }

  if (!method_fld)
    err = ws_soap_error (ses, "300", "37000",
	"No SOAPMethodName or SOAPAction for the SOAP request", soap_version, *uddi_action, http_resp_code, &ctx);
  else
    {
      if (NULL != (szMethod = strchr (method_fld, '#')))
	{
	  szMethodURI = method_fld;
	  *szMethod++ = 0;
	}
      else
	szMethodURI = ns;
    }

  if (!err)
    {
      caddr_t * volatile envelope = NULL;
      caddr_t * volatile headers = NULL;
      caddr_t * volatile method = NULL;
      caddr_t * volatile body = NULL;
      caddr_t * volatile call_params = NULL;
      query_t *proc_qry = NULL;
      query_t * volatile call_qry = NULL;
      local_cursor_t * lc = NULL;
      caddr_t call_text = NULL;
      const char *encodingStyle = NULL;
      const char *_soap_enc = NULL;

      xml_expand_refs (xml_tree, &err);
      /* check error */
      if (err)
	{
	  if (soap_version < 12 || (is_dime && *is_dime))
	    {
	      dk_free_tree (err);
	      err = NULL;
	    }
	  else
	    {
	      caddr_t err1;
	      err1 = ws_soap_error (ses, "330", ERR_STATE (err), ERR_MESSAGE (err), soap_version, *uddi_action, http_resp_code, &ctx);
	      dk_free_tree (err);
	      err = err1;
	      goto end;
	    }
	}

      if (!(envelope = xml_find_child (xml_tree, "Envelope", SOAP_URI (soap_version), 0, NULL)))
	{
	  caddr_t *envelope = xml_find_exact_child (xml_tree, NULL, 0);
	  char * envelope_tag = XML_ELEMENT_NAME(envelope);
	  if (envelope_tag &&
	      !strcmp (extract_last_xml_name_part (envelope_tag), "Envelope"))
	    {
	      err = ws_soap_error (ses, "100", "37000", "Wrong version",
		  soap_version, *uddi_action, http_resp_code, &ctx);
	    }
	  else
	    {
	      err = ws_soap_error (ses, "300", "37000", "Invalid SOAP request",
		  soap_version, *uddi_action, http_resp_code, &ctx);
	    }
	  goto end;
	}

      if (!(body = xml_find_child (envelope, "Body", SOAP_URI (soap_version), 0, NULL)))
	{
	  err = ws_soap_error (ses, "300", "37000", "The SOAP Request does not have a Body",
	      soap_version, *uddi_action, http_resp_code, &ctx);
	  goto end;
	}


      headers = xml_find_child (envelope, "Header", SOAP_URI (soap_version), 0, NULL);

      method = xml_find_child (body, szMethod, szMethodURI, 0, NULL);

      encodingStyle = xml_find_global_attribute (body, "encodingStyle", SOAP_URI (soap_version));
      if (!encodingStyle)
        encodingStyle = xml_find_global_attribute (xml_tree, "encodingStyle", SOAP_URI (soap_version));

      /* it's a literal and option to force as RPC-like */
      if (!encodingStyle && ctx.def_enc == (SOAP_MSG_LITERALW|SOAP_MSG_LITERAL))
	{
	  encodingStyle = SOAP_ENC (soap_version);
	  szMethod = NULL;
	}

      /* if encodingStyle != SOAP_ENC in 1.2 error */
      _soap_enc = SOAP_ENC (soap_version);
      if (ctx.soap_version == 12 && encodingStyle && _soap_enc && 0 != strcmp (encodingStyle, _soap_enc))
	{
	  if (0 != strcmp (encodingStyle, SOAP_TYPE_SCHEMA12 "/encoding/none"))
	    {
	      err = ws_soap_error (ses, "500", "37000", "Unknown Data Encoding Style",
		  soap_version, *uddi_action, http_resp_code, &ctx);
	      goto end;
	    }
	}

      snprintf (qpref, sizeof (qpref), "%s.%s.", usr_qual, usr_own);
      qpref_len = (int) strlen (qpref);
      qrs = get_granted_qrs (cli, NULL, qpref, qpref_len);

      if (ctx.soap_version > 1 &&
	  (!encodingStyle ||
	   (encodingStyle && _soap_enc && 0 != strcmp (encodingStyle, _soap_enc))))
	{ /* if an encoding style <> from RPC use doc/literal
	     XXX: if szMethod is supplied then try mapping procedure directly */
	  szMethod = soap_find_doc_literal (body, headers, &qrs, usr_qual, usr_own, opts, &use_literal);
	  szMethodURI = SOAP_TYPES_SCH(opts);
	}
      else if (!method)
	{
	  method = xml_find_child (body, szMethod, NULL, 0, NULL);
	  if (method)
	    szMethodURI = NULL;
	}

      if (method && !szMethod)
	{
	  szMethod = method_fld = XML_ELEMENT_NAME (method);
	  if (NULL != (szMethod = strrchr (method_fld, ':')))
	    {
	      szMethodURIBuffer = szMethodURI = box_dv_short_string (method_fld);
	      szMethod = strrchr (szMethodURIBuffer, ':');
	      *szMethod++ = 0;
	      if (!strncmp (szMethodURI, UDDI_NS, strlen (UDDI_NS)))
		*uddi_action = 1;
	    }
	  else
	    {
	      szMethodURI = NULL;
	      szMethod = method_fld;
	    }
	}

      ctx.literal = use_literal; /* set the Doc/Literal flag */

      szFullProcName[0] = 0;
      if (szMethod && IS_BOX_POINTER (procedure_mappings) &&
	  (DV_TYPE_OF (procedure_mappings) == DV_ARRAY_OF_POINTER || DV_STRINGP (procedure_mappings)))
	{
	  int inx;
	  caddr_t item = NULL;
	  if (DV_STRINGP (procedure_mappings))
	    {
	      dbe_schema_t *sc = /*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema;
	      query_t *mod = NULL;
	      caddr_t full_name = sch_full_module_name (sc, (char *) procedure_mappings,
		  cli_qual (cli), CLI_OWNER (cli));
	      if (full_name)
		mod = sch_module_def (sc, full_name);
	      if (mod)
		{
		  char proc_name[MAX_NAME_LEN * 4 + 4];
		  strcpy_ck (proc_name, mod->qr_proc_name);
		  strcat_ck (proc_name, ".");
		  strncat_ck (proc_name, szMethod, MAX_NAME_LEN);
		  full_name = sch_full_proc_name (sc, proc_name, cli_qual (cli), CLI_OWNER (cli));
		  if (full_name)
		    strncpy (szFullProcName, full_name, sizeof (szFullProcName));
		}
	    }
	  else
	    {
	      if (szMethodURI)
		{
		  item = dk_alloc_box (strlen (szMethodURI) + strlen (szMethod) + 2, DV_SHORT_STRING);
		  snprintf (item, box_length (item), "%s:%s", szMethodURI, szMethod);
		}
	      else
		item = box_dv_short_string (szMethod);
	      inx = find_index_to_vector (item, (caddr_t) procedure_mappings,
		  BOX_ELEMENTS (procedure_mappings),
		  DV_ARRAY_OF_POINTER, 0, 2, "soap_server");
	      if (inx != 0)
		strncpy (szFullProcName, procedure_mappings[inx], sizeof (szFullProcName));
	    }
	  dk_free_box (item);
	}

      if (!szFullProcName[0])
	{
	  if (!*uddi_action)
	    {
	      if (szMethod)
		snprintf (szFullProcName, sizeof (szFullProcName), "%s.%s.%s", usr_qual, usr_own, szMethod);
	      else /* will make error below */
		snprintf (szFullProcName, sizeof (szFullProcName), "%s.%s.(null)", usr_qual, usr_own);
	      if (CM_UPPER == case_mode)
		sqlp_upcase (szFullProcName);
	    }
	  else
	    {
	      snprintf (szFullProcName, sizeof (szFullProcName), "UDDI.DBA.UDDI_%s", szMethod);
	      sqlp_upcase (szFullProcName);
	    }
	}

      if (!cli->cli_user)
	{
	  err = ws_soap_error (ses, "300", "37000", "No execute permissions to the domain",
	      soap_version, *uddi_action, http_resp_code, &ctx);
	  goto end;
	}

      if (!(proc_qry = sch_proc_def (wi_inst.wi_schema, szFullProcName)))
	{
	  if (!(proc_qry = proc_find_in_grants (szMethod, &qrs, soap_action)))
	    {
	      err = ws_soap_error (ses, "310", "37000", "There is no such procedure",
		  soap_version, *uddi_action, http_resp_code, &ctx);
	      goto end;
	    }
	}

      if (proc_qry->qr_to_recompile) /* get recompilation */
	proc_qry = qr_recompile (proc_qry, &err_sql);

      if (err_sql)
	{
	  err = ws_soap_error (ses, "300", ERR_STATE(err_sql), ERR_MESSAGE(err_sql), soap_version, *uddi_action, http_resp_code, &ctx);
	  dk_free_tree (err_sql);
	  goto end;
	}

#if 0
      if (IS_REMOTE_ROUTINE_QR (proc_qry))
	{
	  /* FIXME: */
	  err = ws_soap_error (ses, "300", "37000", "Attached procedures not available from SOAP",
	      soap_version, *uddi_action);
	  goto end;
	}
#endif
      if (!soap_check_headers (proc_qry, (caddr_t *)headers, soap_version, lines, &ctx, &err, ses))
	{
	  if (!err)
	    err = ws_soap_error (ses, "200", "37000", "Header not understood",
		soap_version, *uddi_action, http_resp_code, &ctx);
	  else
	    *http_resp_code = 400;
	  goto end;
	}

      call_params = soap_xml_params_to_array (proc_qry, use_literal ? body : method, &err, &call_text,
	  (caddr_t) headers, lines, &ctx, xml_tree);

      /* bad incoming parameters */
      if (err)
	{
	  caddr_t err1;
	  err1 = ws_soap_error (ses, "320", ERR_STATE (err), ERR_MESSAGE (err), soap_version, *uddi_action, http_resp_code, &ctx);
	  dk_free_tree (err);
	  err = err1;
	  goto end;
	}

      if (!err)
	{
	  call_qry = sql_compile (call_text, cli, &err, SQLC_DEFAULT);
	  dk_free_box (call_text);
	}
      if (!err)
	{
	  ws_soap_check_async (cli, proc_qry, ses, soap_version);
	  err = qr_exec (cli, call_qry, CALLER_LOCAL, NULL, NULL,
	      &lc, call_params, NULL, 1);
	  dk_free_box ((box_t) call_params);
	  while (lc_next (lc));
	}
      else
	{
	  dk_free_tree ((box_t) call_params);
	  call_params = NULL;
	}

      if (err && err != (caddr_t) SQL_NO_DATA_FOUND)
	{
	  caddr_t err1;
	  err1 = ws_soap_error (ses, "400", ERR_STATE (err), ERR_MESSAGE (err), soap_version, *uddi_action, http_resp_code, &ctx);
	  dk_free_tree (err);
	  err = err1;
	}
      else if (lc)
	{
	  err = soap_serialize (ses, cli, proc_qry, lc, &ctx,
	      schema_ns, *uddi_action, http_resp_code, szMethod, szMethodURI);
	}
      if (lc)
	lc_free (lc);
      qr_free (call_qry);
    }

end:
  if (use_literal)
    dk_free_box (szMethod);
  dk_free_box (szMethodURIBuffer);
  dk_free_box (soap_action);
  soap_wsdl_schema_free (&(ctx.ns_set), &(ctx.types_set));
  dk_free_tree (*attachs);
  *attachs = list_to_array (dk_set_nreverse (ctx.o_attachments));
  if (is_dime)
    *is_dime = ctx.con_encoding;
  dk_set_free (qrs);
  return err;
}

caddr_t
ws_http_error_header (int code)
{
  char * ret;
  char tmp[512];
  switch (code)
    {
      case 100: ret = "Continue"; break;
      case 101: ret = "Switching Protocols"; break;
      case 200: ret = "OK"; break;
      case 201: ret = "Created"; break;
      case 202: ret = "Accepted"; break;
      case 203: ret = "Non-Authoritative Information"; break;
      case 204: ret = "No Content"; break;
      case 205: ret = "Reset Content"; break;
      case 206: ret = "Partial Content"; break;
      case 300: ret = "Multiple Choices"; break;
      case 301: ret = "Moved Permanently"; break;
      case 302: ret = "Found"; break;
      case 303: ret = "See Other"; break;
      case 304: ret = "Not Modified"; break;
      case 305: ret = "Use Proxy"; break;
      case 306: ret = "(Unused)"; break;
      case 307: ret = "Temporary Redirect"; break;
      case 400: ret = "Bad Request"; break;
      case 401: ret = "Unauthorized"; break;
      case 402: ret = "Payment Required"; break;
      case 403: ret = "Forbidden"; break;
      case 404: ret = "Not Found"; break;
      case 405: ret = "Method Not Allowed"; break;
      case 406: ret = "Not Acceptable"; break;
      case 407: ret = "Proxy Authentication Required"; break;
      case 408: ret = "Request Timeout"; break;
      case 409: ret = "Conflict"; break;
      case 410: ret = "Gone"; break;
      case 411: ret = "Length Required"; break;
      case 412: ret = "Precondition Failed"; break;
      case 413: ret = "Request Entity Too Large"; break;
      case 414: ret = "Request-URI Too Long"; break;
      case 415: ret = "Unsupported Media Type"; break;
      case 416: ret = "Requested Range Not Satisfiable"; break;
      case 417: ret = "Expectation Failed"; break;
      case 428: ret = "Precondition Required"; break;
      case 429: ret = "Too Many Requests"; break;
      case 431: ret = "Request Header Fields Too Large"; break;
      case 500: ret = "Internal Server Error"; break;
      case 501: ret = "Not Implemented"; break;
      case 502: ret = "Bad Gateway"; break;
      case 503: ret = "Service Unavailable"; break;
      case 504: ret = "Gateway Timeout"; break;
      case 505: ret = "HTTP Version Not Supported"; break;
      case 509: ret = "Bandwidth Limit Exceeded"; break;
      case 511: ret = "Network Authentication Required"; break;
      default:
		code = 500;
		ret = "Internal Server Error";
    }
  snprintf (tmp, sizeof (tmp), "HTTP/1.1 %d %s", code, ret);
  return box_dv_short_string (tmp);
}

caddr_t
ws_soap (ws_connection_t * ws, int soap_version, caddr_t method_fld)
{
  caddr_t type_fld = ws_mime_header_field (ws->ws_lines, "Content-Type", NULL, 0);
  caddr_t enc = ws_mime_header_field (ws->ws_lines, "Content-Type", "charset", 0);
  caddr_t req_xml = NULL;
  caddr_t * volatile xml_tree = NULL;
  caddr_t err = NULL;
  int uddi_action = 0, con_content_enc = WS_ENC_NONE;
  int req_len = ws->ws_req_len, http_resp_code = 200;
  char * schema_ns;
  caddr_t *opts, **dime_msgs = NULL;
/*  if (!err && (!type_fld || stricmp (type_fld, "text/xml")))
    err = ws_soap_error (ws, "300", "37000", "Incorrect type for a SOAP request", soap_version, uddi_action);
*/
  if (ws->ws_req_body)
    {
      req_xml = strses_string (ws->ws_req_body);
      ws->ws_req_body = NULL;
    }
  else if (!ws->ws_params)
    {
      err = ws_soap_error (ws->ws_strses, "300", "SOAPS", "Can\'t read the SOAP request",
	  soap_version, uddi_action, &http_resp_code, NULL);
      goto end;
    }

  if (type_fld)
    {
      if (0 == stricmp (type_fld, "application/dime"))
	con_content_enc = WS_ENC_DIME;
      else if (0 == stricmp (type_fld, "Multipart/Related"))
	con_content_enc = WS_ENC_MIME;
      else
	con_content_enc = WS_ENC_NONE;

      /* the request is DIME or MIME encoded */
      if (con_content_enc != WS_ENC_NONE)
	{
	  dk_set_t parts = NULL;
	  con_content_enc == WS_ENC_DIME ?
	      soap_dime_tree (req_xml, &parts, &err) : soap_mime_tree (ws, &parts, &err, soap_version);
	  if (!err)
	    {
	      const char *_soap_uri = SOAP_URI(soap_version);
	      dime_msgs = (caddr_t **) list_to_array (dk_set_nreverse (parts));
	      if (BOX_ELEMENTS (dime_msgs) > 0 && dime_msgs[0][1] && _soap_uri &&
		  0 == strcmp (dime_msgs[0][1], _soap_uri))
		{
		  dk_free_box (req_xml);
		  req_xml = dime_msgs[0][2];
		  dime_msgs[0][2] = NULL;
		  dk_free_tree (ws->ws_params);
		  ws->ws_params = (caddr_t *) dk_alloc_box (0, DV_ARRAY_OF_POINTER);
		}
	      else
		{
		  err = ws_soap_error (ws->ws_strses, "300", "SOAPS", "Wrong format of DIME encoded SOAP message",
		      soap_version, uddi_action, &http_resp_code, NULL);
		}
	    }
	}
    }

  if (!err)
    {
      if (NULL == req_xml)
	{
	  err = ws_soap_error (ws->ws_strses, "300", "SOAPS", "Can\'t read the SOAP request",
	      soap_version, uddi_action, &http_resp_code, NULL);
	  goto end;
	}
      /* In the following call of xml_make_tree() query_instance_t * is not needed: req_xml is non-BLOB. */
      if (DO_LOG(LOG_SOAP))
	{
	  client_connection_t *cli = ws->ws_cli;
	  LOG_GET;
	  log_info ("SOAP_0 %s %s %s %i : %*.*s", user, from, peer, req_len,
	      LOG_PRINT_SOAP_STR_L, LOG_PRINT_SOAP_STR_L, req_xml);
	}
#if 0
      /*dbg_print_box (ws->ws_lines, stderr);*/
      fprintf (stderr, "\nSOAP_REQ: %s\n", req_xml);
      if (0)
	{
	  FILE * fo = fopen ("wss.xml", "w");
	  fprintf (fo, "%s", req_xml);
	  fclose (fo);
	}
#endif
      xml_tree = (caddr_t *) xml_make_tree (NULL, req_xml, &err, enc, server_default_lh, NULL /* no DTD */);
    }
  dk_free_box (req_xml);
  if (err)
    {
      caddr_t err1 = ws_soap_error (ws->ws_strses, "300", ERR_STATE (err), ERR_MESSAGE(err),
	  soap_version, uddi_action, &http_resp_code, NULL);
      dk_free_tree (err);
      err = err1;
      goto end;
    }
  opts = SOAP_OPTIONS(ws);
  schema_ns = SOAP_TYPES_SCH (opts);
  err = soap_server (soap_version, method_fld, ws->ws_strses, xml_tree,
      ws_usr_qual (ws, 1), WS_SOAP_NAME (ws), (caddr_t) ws->ws_lines, ws->ws_cli, &uddi_action,
      NULL, schema_ns, opts, (caddr_t *) &dime_msgs, &con_content_enc, (caddr_t *) CALLER_LOCAL,
      &http_resp_code);
  if (!ws->ws_flushed && DO_LOG(LOG_SOAP))
    {
      client_connection_t *cli = ws->ws_cli;
      LOG_GET;
      log_info ("SOAP_1 %s %s %s %i %s : %*.*s", user, from, peer, ws->ws_strses->dks_out_length, method_fld,
	  ws->ws_strses->dks_out_fill > LOG_PRINT_SOAP_STR_L ? LOG_PRINT_SOAP_STR_L : ws->ws_strses->dks_out_fill,
	  ws->ws_strses->dks_out_fill > LOG_PRINT_SOAP_STR_L ? LOG_PRINT_SOAP_STR_L : ws->ws_strses->dks_out_fill,
	  ws->ws_strses->dks_out_buffer);
    }
#if 0
  fprintf (stderr, "\nSOAP_RESP: %*.*s\n", ws->ws_strses->dks_out_fill, ws->ws_strses->dks_out_fill, ws->ws_strses->dks_out_buffer);
#endif
end:
  if (err && !ws->ws_status_line && soap_version > 1)
    {
      if (http_resp_code != 200)
	{
	  ws->ws_status_line = ws_http_error_header (http_resp_code);
	  ws->ws_status_code = http_resp_code;
	}
      else
	{
	  ws->ws_status_line = box_dv_short_string ("HTTP/1.1 500 Internal Server Error");
	  ws->ws_status_code = 500;
	}
    }

  if (con_content_enc == WS_ENC_DIME && dime_msgs)
    {
      if (!STRSES_CAN_BE_STRING (ws->ws_strses))
	{
	  err = STRSES_LENGTH_ERROR ("SOAP server (DIME)");
	}
      else
	{
	  caddr_t soap_resp = strses_string (ws->ws_strses);
	  caddr_t *first = (caddr_t*)list (3, box_dv_short_string (""), box_dv_short_string (SOAP_URI (soap_version)), soap_resp);
	  strses_flush (ws->ws_strses);
	  dime_msgs[0] = first;
	  dime_compose (ws->ws_strses, (caddr_t *)dime_msgs, &err);
	}
    }
  if (con_content_enc == WS_ENC_MIME && dime_msgs)
    {
      if (!STRSES_CAN_BE_STRING (ws->ws_strses))
	{
	  err = STRSES_LENGTH_ERROR ("SOAP server (MIME)");
	}
      else
	{
	  caddr_t soap_resp = strses_string (ws->ws_strses);
	  caddr_t *first = (caddr_t*)list (3, box_dv_short_string (""), box_dv_short_string (SOAP_URI (soap_version)), soap_resp);
	  strses_flush (ws->ws_strses);
	  dime_msgs[0] = first;
	  mime_compose (ws, (caddr_t *)dime_msgs);
	}
    }
  if (con_content_enc == WS_ENC_DIME)
    ws->ws_header = box_dv_short_string ("Content-Type: application/dime\r\n");
  else if (soap_version <= 11)
    ws->ws_header = box_dv_short_string ("Content-Type: text/xml; charset=\"utf-8\"\r\n");
  else if (soap_version == 12)
    ws->ws_header = box_dv_short_string ("Content-Type: " SOAP_CTYPE_12 "; charset=\"utf-8\"\r\n");
  dk_free_tree ((box_t) dime_msgs);
  dk_free_tree ((box_t) xml_tree);
  dk_free_box (type_fld);
  dk_free_box (enc);
  return err;
}


static caddr_t
bif_soap_server (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  xml_tree_ent_t *ent = bif_tree_ent_arg (qst, args, 0, "soap_server");
  caddr_t soap_method = "";
  int soap_version = 11;
  caddr_t lines = NULL;
  int uddi_action = 0, con_content_enc = WS_ENC_NONE, http_resp_code = 200;
  dk_session_t *ses = NULL;
  caddr_t err = NULL;
  caddr_t *procedure_mappings = NULL;
  caddr_t *opts = NULL, *attachs = NULL;
  char * schema_ns;

  if (BOX_ELEMENTS (args) > 1)
    soap_method = bif_string_or_null_arg (qst, args, 1, "soap_server");
  if (BOX_ELEMENTS (args) > 2)
    lines = bif_array_or_null_arg (qst, args, 2, "soap_server");
  if (BOX_ELEMENTS (args) > 3)
    soap_version = (int) bif_long_arg (qst, args, 3, "soap_server");
  if (BOX_ELEMENTS (args) > 4)
    procedure_mappings = (caddr_t *) bif_array_or_null_arg (qst, args, 4, "soap_server");
  if (BOX_ELEMENTS (args) > 5)
    opts = (caddr_t *) bif_array_or_null_arg (qst, args, 5, "soap_server");
  if (!opts && qi->qi_client->cli_ws)
    opts = SOAP_OPTIONS (qi->qi_client->cli_ws);

  if (BOX_ELEMENTS (args) > 6) /* attachments if available */
    {
      attachs = (caddr_t *) box_copy_tree (bif_array_or_null_arg (qst, args, 6, "soap_server"));
      if (NULL != attachs)
        con_content_enc = WS_ENC_DIME; /*XXX: for now only DIME is supported */
    }

  schema_ns = SOAP_TYPES_SCH (opts);

  ses = strses_allocate ();
  err = soap_server (soap_version, soap_method, ses, ent->xte_current,
      qi->qi_client->cli_qualifier, CLI_OWNER (qi->qi_client),
      lines, qi->qi_client, &uddi_action, procedure_mappings, schema_ns, opts,
      (caddr_t *)&attachs, &con_content_enc, qst, &http_resp_code);
#if 0
  fprintf (stderr, "\nSOAP_RESP_1: %*.*s\n", ses->dks_out_fill, ses->dks_out_fill, ses->dks_out_buffer);
#endif
  if (err)
    {
      dk_free_tree ((box_t) attachs);
      strses_free (ses);
      sqlr_resignal (err);
    }
  if (BOX_ELEMENTS (args) > 6 && ssl_is_settable (args[6]))
    {
      if (con_content_enc == WS_ENC_DIME && attachs)
	qst_set (qst, args[6], (caddr_t) box_copy_tree ((box_t) attachs));
      else
	qst_set (qst, args[6], NEW_DB_NULL);
    }
  dk_free_tree ((box_t) attachs);
  if (!STRSES_CAN_BE_STRING (ses))
    {
      *err_ret = STRSES_LENGTH_ERROR ("soap_server");
      err = NULL;
    }
  else
    err = strses_string (ses);
  strses_free (ses);
  return err;
}


static caddr_t
bif_soap_find_xml_attribute (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_find_xml_attribute";
  caddr_t *entity = (caddr_t *) bif_array_arg (qst, args, 0, szMe);
  caddr_t name = bif_string_arg (qst, args, 1, szMe);
  caddr_t uri = NULL;
  char *ret = NULL;

  if (BOX_ELEMENTS (args) > 2)
    uri = bif_string_arg (qst, args, 2, szMe);
  ret = xml_find_attribute (entity, name, uri);

  return box_dv_short_string (ret);
}


static caddr_t
bif_soap_box_xml_entity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_box_xml_entity";
  caddr_t entity1 = bif_arg (qst, args, 0, szMe);
  caddr_t value_for_type = bif_arg (qst, args, 1, szMe);
  int soap_version = 1;
  char *ret = NULL;
  dtp_t proposed_type = DV_TYPE_OF (value_for_type), dtp = DV_TYPE_OF (entity1);
  caddr_t * entity = NULL;

  if (BOX_ELEMENTS (args) > 2)
    soap_version = (int) bif_long_arg (qst, args, 2, szMe);

  if (dtp == DV_ARRAY_OF_POINTER)
    entity = (caddr_t *) entity1;
  else if (dtp == DV_XML_ENTITY)
    {
      xml_tree_ent_t *ent = (xml_tree_ent_t *) entity1;
      entity = ent->xte_current;
    }
  else
    {
      sqlr_new_error ("22023", "SR012",
	  "Function %s needs a string or an array as argument %d, "
	  "not an arg of type %s (%d)",
	  szMe, 1, dv_type_title (dtp), dtp);
    }


  if (proposed_type == DV_DB_NULL)
    proposed_type = 0;
  ret = soap_box_xml_entity (entity, err_ret, proposed_type, soap_version);
  return ret;
}


static caddr_t
bif_soap_box_structure (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_box_structure";
  long elems = BOX_ELEMENTS (args), inx;
  caddr_t *ret;
  if ((elems % 2) > 0)
    sqlr_new_error ("22023", "SP030",
	"Invalid number of args supplied to soap_box_structure. The argument count should be even");
  if (!elems)
    return dk_alloc_box (0, DV_DB_NULL);
  else
    {
      ret = (caddr_t *) dk_alloc_box_zero ((elems + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      ret[0] = dk_alloc_box (0, DV_COMPOSITE);
      ret[1] = box_dv_short_string ("<soap_box_structure>");
      for (inx = 0; inx < elems; inx += 2)
	{
	  caddr_t name = bif_string_arg (qst, args, inx, szMe);
	  caddr_t val = bif_arg (qst, args, inx + 1, szMe);
	  ret[inx + 2] = box_copy (name);
	  ret[inx + 3] = box_copy_tree (val);
	}
      return (caddr_t) ret;
    }
}


static caddr_t
bif_soap_boolean (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_boolean";
  ptrlong val = bif_long_arg (qst, args, 0, szMe);

  return list (2, dk_alloc_box (0, DV_COMPOSITE), box_num_nonull (val));
}


static caddr_t
bif_soap_print_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  char *szMe = "soap_print_box";
  int n_args = BOX_ELEMENTS (args);
  caddr_t object = bif_arg (qst, args, 0, szMe);
  caddr_t tag = bif_string_arg (qst, args, 1, szMe);
  dk_session_t *out = strses_allocate ();
  caddr_t ret = NULL;
  char temp[256];

  if (n_args > 2 && DV_TYPE_OF (object) == DV_DATETIME)
    {
      ptrlong enc_type = bif_long_arg (qst, args, 2, szMe);
      switch (enc_type)
	{
	  case 0:
	    dt_to_iso8601_string (object, temp, sizeof (temp));
	    session_buffered_write (out, temp, strlen (temp));
	    break;
	  case 1:
	    dt_to_rfc1123_string (object, temp, sizeof (temp));
	    session_buffered_write (out, temp, strlen (temp));
	    break;
	  case 2:
	    dt_to_ms_string (object, temp, sizeof (temp));
	    session_buffered_write (out, temp, strlen (temp));
	    break;
	  default:
	    break;
	}
    }
  else
    {
      int soap_version = 1;
      soap_ctx_t ctx;
      if (n_args > 2)
	soap_version = (int) bif_long_arg (qst, args, 2, szMe);
      if (soap_version != 1 && soap_version != 11)
	sqlr_new_error ("42000", "SP031", "Invalid SOAP version %d", soap_version);
      memset (&ctx, 0, sizeof (soap_ctx_t));
      ctx.soap_version = soap_version;
      ctx.qst = qst;
      ctx.cli = qi->qi_client;
      *err_ret = soap_print_box (object, out, tag, soap_version, NULL, 0, &ctx);
    }
  if (!*err_ret)
    {
      if (!STRSES_CAN_BE_STRING (out))
	{
	  ret = NULL;
	  *err_ret = STRSES_LENGTH_ERROR ("soap_print_box");
	}
      else
	ret = strses_string (out);
    }
  strses_free (out);
  return ret;
}

#ifdef _SSL
int ssl_client_use_pkcs12 (SSL *ssl, char *pkcs12file, char *passwd, char * ca);
#endif

static caddr_t
bif_soap_call (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_call";
  caddr_t szHost = bif_string_arg (qst, args, 0, szMe);
  caddr_t szURL = bif_string_arg (qst, args, 1, szMe);
  caddr_t szMethodURI = bif_string_or_null_arg (qst, args, 2, szMe);
  caddr_t szMethodName = bif_string_arg (qst, args, 3, szMe);
  caddr_t *params = (caddr_t *) bif_array_or_null_arg (qst, args, 4, szMe);
  volatile int soap_version = 1, dl_val = 0;
  dk_session_t *out = strses_allocate ();
  dk_session_t * volatile http_out;
  int i, rc, use_ssl = 0, ns_contains = 0, keep_alive = 1;
  char szTmp[4096], szEncoding[30];
  volatile caddr_t content = NULL;
  caddr_t *** volatile xml_tree = NULL;
  caddr_t * volatile envelope = NULL;
  caddr_t * volatile body = NULL;
  caddr_t * volatile header = NULL;
  caddr_t * volatile fault = NULL;
  caddr_t * volatile dl_mode = NULL;
  caddr_t * volatile xml_tree1;
  caddr_t err = NULL;
  volatile int debug_mode = 0;
  caddr_t *volatile debug_out = NULL;
  caddr_t pkcs12_file = NULL, pass = NULL, szSOAPAction = NULL;
  int large_content = 0, use_dime = 0;
#ifdef _USE_CACHED_SES
  int cached = 0;
#endif
#ifdef _SSL
  SSL * ssl = NULL;
  SSL_CTX* ssl_ctx = NULL;
  SSL_METHOD *ssl_meth = NULL;
#endif
  soap_ctx_t ctx;
  query_instance_t *qi = (query_instance_t *) qst;

  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.qst = qst;
  ctx.cli = qi->qi_client;

  if (BOX_ELEMENTS (args) > 5)
    {
      soap_version = (int) bif_long_arg (qst, args, 5, szMe);
      if (soap_version < 0)
	{
	  debug_mode = 1;
	  debug_out = (caddr_t *) dk_alloc_box_zero (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  soap_version = soap_version * -1;
	}
    }

  if (BOX_ELEMENTS (args) > 6)
    {
      pkcs12_file = bif_string_or_null_arg (qst, args, 6, szMe);
      if (pkcs12_file)
	use_ssl = 1;
      if (BOX_ELEMENTS (args) > 7)
	pass = bif_string_or_null_arg (qst, args, 7, szMe);

    }

  if (BOX_ELEMENTS (args) > 8)
    szSOAPAction = bif_string_or_null_arg (qst, args, 8, szMe);

  if (BOX_ELEMENTS (args) > 9)
    {
      dl_val = (int) bif_long_arg (qst, args, 9, szMe);

      if (dl_val & 2)
	{
	  dl_mode = (caddr_t *) dk_alloc_box_zero (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	}

      if (dl_val & 1)
	{
	  ctx.literal = 1;
	}

      if (dl_val & 8)
	use_dime = 1;
    }

  if (szMethodURI && !strncmp (szMethodURI, szMethodName, strlen (szMethodURI)) && soap_version > 1)
    {
      szMethodName = szMethodName + strlen (szMethodURI);
      ns_contains = 1;
    }

  /* set the context of SOAP serialization */
  ctx.soap_version = soap_version;
  ctx.dks_esc_compat = DKS_ESC_COMPAT_SOAP /*USE_CR_ESCAPE*/;

  for (i = 0; params && BOX_ELEMENTS (params) > 0 && i < (int) (BOX_ELEMENTS (params) - 1); i+= 2)
    {
      caddr_t szParamName = params[i];
      dtp_t name_dtp = DV_TYPE_OF (szParamName);
      if (DV_ARRAY_OF_POINTER == name_dtp)
	{
/*	  caddr_t par_name = ((caddr_t *) szParamName)[0];*/
          caddr_t par_type = ((caddr_t *) szParamName)[1];
	  soap_wsdl_schema_push (&(ctx.ns_set), &(ctx.types_set), par_type, ctx.literal, 0, NULL /* XXX: gogo: check */, &ctx);
	}
    }

  if (soap_version == 1)
    SES_PRINT (out,
	"<?xml version='1.0' ?>\n"
	"<SOAP:Envelope\n"
	" xmlns:xsi='" W3C_TYPE_SCHEMA_XSI "'\n"
	" xmlns:xsd='" W3C_TYPE_SCHEMA_XSD "'\n"
	" xmlns:SOAP='" SOAP_TYPE_SCHEMA10 "'\n"
	" xmlns:dt='" MS_TYPE_SCHEMA "'>"
	"<SOAP:Body>");
  else if (soap_version == 11)
    {
      SES_PRINT (out,
	  "<?xml version='1.0' ?>\n"
	  "<SOAP:Envelope\n");
      if (!ctx.literal)
	SES_PRINT (out, " SOAP:encodingType='" SOAP_ENC_SCHEMA11 "'\n");

      SES_PRINT (out, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'\n"
	  " xmlns:xsd='" W3C_2001_TYPE_SCHEMA_XSD "'\n"
	  " xmlns:SOAP='" SOAP_TYPE_SCHEMA11 "'\n"
	  " xmlns:SOAP-ENC=\"" SOAP_ENC_SCHEMA11 "\" ");

      soap_wsdl_print_ns_decl (out, &(ctx.ns_set), NULL);

      SES_PRINT (out, " xmlns:dt='" MS_TYPE_SCHEMA "'>"
	  "<SOAP:Body>");
    }
  else
    sqlr_new_error ("37000", "SP032", "Unknown SOAP version : %d", soap_version);

  if (ctx.literal != 1)
    {
      if (szMethodURI)
	SES_PRINT (out, "\n<cli:");
      else
	SES_PRINT (out, "\n<");
      session_buffered_write (out, szMethodName, strlen (szMethodName));
      if (soap_version == 11)
	SES_PRINT (out, " SOAP:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/'");
      if (szMethodURI)
	{
	  SES_PRINT (out, " xmlns:cli='");
	  SES_PRINT (out, szMethodURI);
	  SES_PRINT (out, "' >\n");
	}
      else
	SES_PRINT (out, ">\n");
    }

  for (i = 0; params && BOX_ELEMENTS (params) > 0 && i < (int) (BOX_ELEMENTS (params) - 1); i+= 2)
    {
      caddr_t szParamName = params[i];
      caddr_t param_value = params[i + 1];
      dtp_t name_dtp = DV_TYPE_OF (szParamName);
#if 0
      dtp_t value_dtp = DV_TYPE_OF (param_value);
      if (value_dtp == DV_DB_NULL)
	param_value = NULL;
#endif
      if (!szParamName)
	{
	  err = srv_make_new_error ("42000", "SP009",
	      "SOAP Parameters array invalid in call to %s#%s ",
	      szMethodURI ? szMethodURI : "", szMethodName);
	  goto end;
	}
      if ((!IS_STRING_DTP (name_dtp) && DV_ARRAY_OF_POINTER != name_dtp)
	  || (DV_ARRAY_OF_POINTER == name_dtp && BOX_ELEMENTS(szParamName) != 2))
	{
	  err = srv_make_new_error ("42000", "SP010",
	      "SOAP Parameter name %d should be string in call to %s#%s",
	      i / 2, szMethodURI ? szMethodURI : "", szMethodName);
	  goto end;
	}
      if (DV_ARRAY_OF_POINTER == name_dtp)
	{
	  caddr_t par_name = ((caddr_t *) szParamName)[0];
          caddr_t par_type = ((caddr_t *) szParamName)[1];
	  if (!IS_STRING_DTP (DV_TYPE_OF (par_name)) || !IS_STRING_DTP (DV_TYPE_OF (par_type)))
	    {
	      err = srv_make_new_error ("42000", "SP011",
		  "SOAP Parameter name reference %d should be array of "
		  "name and SOAP type as strings in call to %s#%s",
		  i / 2, szMethodURI ? szMethodURI : "", szMethodName);
	      goto end;
	    }
	  ctx.add_schema = ADD_CUSTOM_SCH;
	  ctx.add_type = 1;
	  ctx.req_resp_namespace = NULL;
	  ctx.add_type = ctx.literal ? 0 : 1;
	  soap_print_box_validating (param_value, par_name, out, &err, par_type, &ctx, ctx.literal, ctx.literal, NULL);
	  if (err)
	    break;
	}
      else if (DV_OBJECT == DV_TYPE_OF (param_value) || DV_REFERENCE == DV_TYPE_OF (param_value))
	{
	  ctx.add_schema = ADD_CUSTOM_SCH;
	  ctx.add_type = 1;
	  ctx.req_resp_namespace = NULL;
	  ctx.add_type = ctx.literal ? 0 : 1;
	  soap_print_box_validating (param_value, szParamName, out, &err, "", &ctx, ctx.literal, ctx.literal, NULL);
	  if (err)
	    break;
	}
      else if (NULL != (err = soap_print_box (param_value, out, szParamName, soap_version, NULL, 0, &ctx))
	  		&& ctx.literal)
	break;
    }
  if (!err)
    {
      if (!ctx.literal)
	{
	  if (szMethodURI)
	    SES_PRINT (out, "</cli:");
	  else
	    SES_PRINT (out, "</");
	  SES_PRINT (out, szMethodName);
	  SES_PRINT (out, ">");
	}
  SES_PRINT (out, "</SOAP:Body></SOAP:Envelope>");

  if (use_dime)
    {
      caddr_t data = strses_string (out);
      caddr_t dime_arr = list (1,
	  list (3, box_dv_short_string(""), box_dv_short_string (SOAP_TYPE_SCHEMA11), data));
      dk_free_box((box_t) out);
      out = strses_allocate ();
      dime_compose (out, (caddr_t *)dime_arr, &err);
      dk_free_tree (dime_arr);
    }

      /* use cached session if available */
#ifndef _USE_CACHED_SES
      http_out = http_dks_connect (szHost, &err);
#else
reconnect:
      http_out = http_cached_session (szHost);
      if (http_out)
	cached = 1;
      else
	http_out = http_dks_connect (szHost, &err);
#endif
      /*then we will set the SSL context*/
#ifdef _SSL
      if (!err && use_ssl)
	{
	  int ssl_err = 0;
	  int dst = tcpses_get_fd (http_out->dks_session);

	  ssl_meth = SSLv23_client_method();
	  ssl_ctx = SSL_CTX_new (ssl_meth);

	  ssl = SSL_new (ssl_ctx);
	  SSL_set_fd (ssl, dst);
	  if (pkcs12_file && 0 == atoi(pkcs12_file))
	    {
	      int session_id_context = 12;
	      if (!ssl_client_use_pkcs12 (ssl, pkcs12_file, pass, NULL))
		{
		  err = srv_make_new_error ("22023", "HTS02", "Invalid certificate file");
		  goto error_in_ssl;
		}

	      SSL_set_verify (ssl,
		  SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE, NULL);
	      SSL_set_verify_depth (ssl, -1);
	      SSL_CTX_set_session_id_context(ssl_ctx,
		  (unsigned char *)&session_id_context, sizeof session_id_context);
	    }
	  ssl_err = SSL_connect (ssl);
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
	      err = srv_make_new_error ("08001", "HTS01", "%s", err1);
	    }
	  else
	    tcpses_to_sslses (http_out->dks_session, ssl);
error_in_ssl:
	  if (err)
	    {
	      SESSTAT_CLR (http_out->dks_session, SST_OK);
	      SESSTAT_SET (http_out->dks_session, SST_BROKEN_CONNECTION);
	      PrpcDisconnect (http_out);
	      PrpcSessionFree (http_out);
	    }
	}
#endif
    }
  if (err)
    {
      goto end;
    }


  if (soap_version == 1)
      snprintf (szTmp, sizeof (szTmp),
#ifndef _USE_CACHED_SES
	  "POST %s HTTP/1.0\r\n"
#else
	  "POST %s HTTP/1.1\r\n"
#endif
	  "Content-Type: text/xml\r\n"
#ifndef _USE_CACHED_SES
	  "Connection: close\r\n"
#else
	  "Connection: Keep-Alive\r\n"
#endif
	  "User-Agent: VirtuosoSOAP\r\n"
	  "Host: %s\r\n"
	  "SOAPMethodName: %s#%s\r\n"
	  "Content-Length: " BOXINT_FMT "\r\n\r\n",
	  szURL, szHost, szMethodURI ? szMethodURI : "", szMethodName, strses_length (out));
  else if (soap_version == 11)
      snprintf (szTmp, sizeof (szTmp),
#ifndef _USE_CACHED_SES
	  "POST %s HTTP/1.0\r\n"
#else
	  "POST %s HTTP/1.1\r\n"
#endif
	  "Content-Type: %s\r\n"
#ifndef _USE_CACHED_SES
	  "Connection: close\r\n"
#else
	  "Connection: Keep-Alive\r\n"
#endif
	  "User-Agent: VirtuosoSOAP\r\n"
	  "Host: %s\r\n"
	  "SOAPAction: %s%s%s\r\n"
	  "Content-Length: " BOXINT_FMT "\r\n\r\n",
	  szURL,
	  use_dime ? "application/dime" : "text/xml; charset=\"utf-8\"",
	  szHost,
	  !szSOAPAction && szMethodURI ? szMethodURI : "",
	  szSOAPAction || ns_contains  ? "" : "#",
	  szSOAPAction ? szSOAPAction : szMethodName ,
	  strses_length (out));
  else
    goto end;


#if 0
  fprintf (stderr, "\nSOAP_CLI_REQ: \n%s%*.*s\n", szTmp, out->dks_out_fill, out->dks_out_fill, out->dks_out_buffer);
#endif

  CATCH_WRITE_FAIL (http_out)
    {
      SES_PRINT (http_out, szTmp);
      if (debug_mode)
	{
	  size_t head_len = strlen (szTmp);
	  size_t req_len = strses_length (out);
	  debug_out[1] = dk_alloc_box (head_len + req_len + 1, DV_LONG_STRING);
	  memcpy (debug_out[1], szTmp, head_len);
	  strses_to_array (out, debug_out[1] + head_len);
	  debug_out[1][req_len + head_len] = 0;
	}
      if (dl_mode)
	{
	  int req_len = strses_length (out);
	  dl_mode[1] = dk_alloc_box (req_len + 1, DV_LONG_STRING);
	  strses_to_array (out, dl_mode[1]);
	  dl_mode[1][req_len] = 0;
	}
      strses_write_out (out, http_out);
      session_flush_1 (http_out);
    }
  FAILED
    {
      err = srv_make_new_error ("42000", "SP012",
	  "Can\'t send a request to the SOAP server");
      soap_wsdl_schema_free (&(ctx.ns_set), &(ctx.types_set));
    }
  END_WRITE_FAIL (http_out);

/* dbg_print_box (dl_mode, stderr); */

  if (err)
    {
      PrpcDisconnect (http_out);
      PrpcSessionFree (http_out);
      goto end;
    }

  /* dbg_print_box (dl_mode, stderr); */
  szEncoding[0] = 0;
  CATCH_READ_FAIL (http_out)
    {
      int response  = 0;
      int content_length;
      int is_chunked = 0;
      rc = dks_read_line (http_out, szTmp, sizeof (szTmp));
      if (rc < 12 || strncmp (szTmp, "HTTP", 4))
	{
	  PrpcDisconnect (http_out);
	  PrpcSessionFree (http_out);
	  err = srv_make_new_error ("42000", "SP013",
	      "Not well formed HTTP SOAP reply for call of %s#%s",
	      szMethodURI ? szMethodURI : "", szMethodName);
	  goto end;
	}
      szTmp[12] = 0;
      response  = atoi (szTmp + 9);
      if (response  == 100)
	{
	  do
	    {
	      rc = dks_read_line (http_out, szTmp, sizeof (szTmp));
	      if (!strncmp (szTmp, "HTTP", 4))
		{
		  szTmp[12] = 0;
		  response  = atoi (szTmp + 9);
		}
	    }
	  while (response  < 200);
	}
      if (response  > 200 && soap_version == 1)
	{
	  char szErr[4], szState[256];
	  PrpcDisconnect (http_out);
	  PrpcSessionFree (http_out);
	  strcpy_ck (szErr, szTmp + 9);
	  strncpy (szState, szTmp + 13, 255);
	  szState[255] = 0;
	  err = srv_make_new_error ("42000", "SP014",
	      "HTTP error in SOAP reply for call of %s#%s : %s %s",
	      szMethodURI ? szMethodURI : "", szMethodName, szErr, szState);
	  goto end;
	}
      for (;;)
	{
	  rc = dks_read_line (http_out, szTmp, sizeof (szTmp));
	  if (rc <= 2)
	    break;
	  if (!strnicmp ("Content-Type: ", szTmp, 14))
	    {
	      char *enc = strchr (szTmp, ';'), *enc1 = szEncoding;
	      if (enc)
		{
		  enc++;
		  while (isspace (*enc))
		    enc++;
		}
	      if (enc && strncmp (enc, "charset", 7) && strncmp (enc, "CHARSET", 7))
		enc = NULL;
	      if (enc)
	        {
		  while (isspace (*enc))
		    enc++;
		  if ('=' != enc[0])
		    enc = NULL;
		}
	      if (enc)
		{
		  enc++;
		  while (!isspace (*enc) && enc1 < (szEncoding + sizeof (szEncoding) - 2))
		    {
		      *enc1++ = toupper (*enc++);
		    }
		  *enc1 = 0;
		}
	      if (NULL != nc_strstr ((unsigned char *) szTmp, (unsigned char *) "application/dime"))
		use_dime = 1;
	      else
		use_dime = 0;
	    }
	  else if (!strnicmp ("Content-Length: ", szTmp, 16))
	    {
	      content_length = atoi (szTmp + 16);
	      /* IvAn/NoiseProtection/010106 Check added for content-length */
	      if ((content_length >= 0) && (content_length <= 10000000))
		{
		  content = dk_alloc_box (content_length + 1, DV_SHORT_STRING);
		  content[content_length] = '\0';
		}
	      else if (content_length > 10000000)
		large_content = 1;
	      /* ... else we have invalid content_length value and will emit an error */
	    }
	  else if (!strnicmp ("Transfer-Encoding: chunked", szTmp, 26))
	    is_chunked = 1;
	  else if (!strnicmp ("Connection:", szTmp, 11) &&
                   nc_strstr ((unsigned char *) szTmp, (unsigned char *) "close"))
	    keep_alive = 0;
	}
      if (is_chunked)
	content = http_read_chunked_content (http_out, &err, szURL, 0);
      if (!content)
	{
	  PrpcDisconnect (http_out);
	  PrpcSessionFree (http_out);
	  if (!large_content)
	    {
	      err = srv_make_new_error ("42000", "SP015",
		  "No (valid) Content-Length field in HTTP SOAP reply for call of %s#%s",
		  szMethodURI ? szMethodURI : "", szMethodName);
	    }
	  else
	    {
	      err = srv_make_new_error ("42000", "SP016",
		  "Content length in HTTP SOAP reply is too large for call of %s#%s",
		  szMethodURI ? szMethodURI : "", szMethodName);
	    }
	  goto end;
	}
      else if (!is_chunked)
	session_buffered_read (http_out, content, box_length (content) - 1);
    }
  FAILED
    {
      err = srv_make_new_error ("42000", "SP017", "Can\'t read the SOAP server response");
      soap_wsdl_schema_free (&(ctx.ns_set), &(ctx.types_set));
    }
  END_READ_FAIL (http_out);
#ifndef _USE_CACHED_SES
  PrpcDisconnect (http_out);
  PrpcSessionFree (http_out);
#else
  if (use_ssl || err || !SESSTAT_ISSET (http_out->dks_session, SST_OK) || !keep_alive)
    {
      int is_broken = SESSTAT_ISSET (http_out->dks_session, SST_BROKEN_CONNECTION);
      PrpcDisconnect (http_out);
      PrpcSessionFree (http_out);
      if (is_broken && cached && err)
	{
	  cached = 0;
	  dk_free_tree (err); err = NULL;
	  dk_free_tree (content); content = NULL;
	  goto reconnect;
	}
    }
  else
    http_session_used (http_out, szHost, 0);
#endif
  if (!err)
    {
      if (debug_mode)
	{
	  debug_out[2] = box_dv_short_string (content);
	}
      if (dl_mode)
	{
	  dl_mode[2] = box_dv_short_string (content);
	}
      if (use_dime)
	{
	  caddr_t **dm = NULL;
	  dk_set_t set = NULL;
	  soap_dime_tree (content, &set, &err);
	  dm = (caddr_t **)list_to_array (dk_set_nreverse (set));
	  if (BOX_ELEMENTS (dm) > 0 && dm[0][1] && 0 == strcmp (dm[0][1], SOAP_TYPE_SCHEMA11))
	    {
	      dk_free_box (content);
	      content = dm[0][2];
	      dm[0][2] = NULL;
	    }
	  dk_free_tree ((box_t) dm);
	}

      xml_tree = (caddr_t ***) xml_make_tree ((query_instance_t *)qst, content, &err,
	  szEncoding[0] ? szEncoding : 0, server_default_lh, NULL /* no DTD */);
      if (!err)
	{
	  xml_expand_refs ((caddr_t *)xml_tree, &err);
	  if (soap_version < 12 && err)
	    {
	      dk_free_tree (err);
	      err = NULL;
	    }
	}
      xml_tree1 = (caddr_t *) xml_tree;
    }
  dk_free_box (content);
  if (err)
    goto end;
  if (!(envelope = xml_find_child (xml_tree1, "Envelope", SOAP_URI (soap_version), 0, NULL)))
    {
      err = srv_make_new_error ("42000", "SP018",
	  "Not well formed SOAP request in call of %s#%s",
	  szMethodURI ? szMethodURI : "", szMethodName);
      dk_free_tree ((box_t) xml_tree);
      goto end;
    }

  if (!(body = xml_find_child (envelope, "Body", SOAP_URI (soap_version), 0, NULL)))
    {
      err = srv_make_new_error ("42000", "SP019",
	  "No Body section in a SOAP reply to %s#%s",
	  szMethodURI ? szMethodURI : "", szMethodName);
      dk_free_tree ((box_t) xml_tree);
      goto end;
    }
  header = xml_find_child (envelope, "Header", SOAP_URI (soap_version), 0, NULL);

  if (NULL != (fault = xml_find_child (body, "Fault", SOAP_URI (soap_version), 0, NULL)))
    {
      char *szFaultCode = (char *)xml_find_child (fault, "faultcode", NULL, 0, NULL);
      char *szFaultString = (char *)xml_find_child (fault, "faultstring", NULL, 0, NULL);
      char *szRunCode = (char *)xml_find_child (fault, "runcode", NULL, 0, NULL);

      szFaultCode = (char *) (szFaultCode ? XML_ELEMENT_CHILD (((caddr_t *)szFaultCode), 0) : NULL);
      szFaultString = (char *) (szFaultString ? XML_ELEMENT_CHILD (((caddr_t *)szFaultString), 0) : NULL);
      szRunCode = (char *) (szRunCode ? XML_ELEMENT_CHILD (((caddr_t *)szRunCode), 0) : NULL);

      err = srv_make_new_error ("42000", "SP020",
	  "SOAP error %s calling %s : [%s] %s",
	  szFaultCode ? szFaultCode : "with unreported code",
	  szMethodName,
	  szRunCode ? szRunCode : "<no runcode>",
	  szFaultString ? szFaultString : "unreported error");
      dk_free_tree ((box_t) xml_tree);
    }
  else
    {
      caddr_t ret = box_copy_tree (xml_element_nonspace_child ((caddr_t) body, 0));
      DO_BOX (caddr_t, headerPart, i, header)
	{
	  if (i > 0 && BOX_ELEMENTS (headerPart) == 2 &&
	      DV_TYPE_OF (headerPart) == DV_ARRAY_OF_POINTER &&
	      !strcmp ("returnCode", extract_last_xml_name_part (XML_ELEMENT_NAME (headerPart))))
	    {
	      char *value = (char *) XML_ELEMENT_CHILD (headerPart, 0);
	      if (value && DV_TYPE_OF (value) != DV_ARRAY_OF_POINTER)
		err = (caddr_t ) (ptrlong) atoi (value);
	    }
	}
      END_DO_BOX;
      dk_free_tree ((box_t) xml_tree);
      if (debug_mode)
	{
	  debug_out[0] = ret;
	  ret = (caddr_t) debug_out;
	}
      if (dl_mode)
	{
	  dl_mode[0] = ret;
          dl_mode[3] = NULL;
	  ret = (caddr_t) dl_mode;
	}
#ifdef _SSL
      SSL_CTX_free (ssl_ctx);
#endif
      soap_wsdl_schema_free (&(ctx.ns_set), &(ctx.types_set));
      strses_free (out);
      return ret;
    }
end:
  soap_wsdl_schema_free (&(ctx.ns_set), &(ctx.types_set));
  strses_free (out);

  if (dl_mode)
    {
      dl_mode[3] = err;
      return (caddr_t) dl_mode;
    }

#ifdef _SSL
  SSL_CTX_free (ssl_ctx);
#endif

  if (err)
    {
      if (BOX_ELEMENTS (args) < 6 || !ssl_is_settable (args[5]))
	{
	  dk_free_tree ((box_t) debug_out);
	  sqlr_resignal (err);
	}
      qst_set (qst, args[5], err);
    }
  return (caddr_t) debug_out;
}

int
soap_call_schema_prep (soap_ctx_t * ctx, caddr_t * params, int headers)
{
  caddr_t param_name;
  dtp_t param_name_dtp;
  caddr_t param_type;
  int i;

  ctx->dks_esc_compat = DKS_ESC_COMPAT_SOAP /*USE_CR_ESCAPE*/;

  for (i = 0;
       params && BOX_ELEMENTS (params) > 0 &&
	 i < (int) (BOX_ELEMENTS (params) -1);
       i+= 2)
    {
      param_name = params[i];
      param_name_dtp = DV_TYPE_OF (param_name);
      if (DV_ARRAY_OF_POINTER == param_name_dtp && BOX_ELEMENTS (param_name) > 1)
	{
	  int elem = (ctx->literal && (!ctx->wrapped || headers)) ? 1 : 0;

	  param_type = ((caddr_t *) param_name)[1];
	  if (soap_type_exists (param_type, 1) && !soap_type_exists (param_type, 0))
	    elem = 1;

	  soap_wsdl_schema_push (&(ctx->ns_set),
				 &(ctx->types_set),
				 param_type,
				 elem,
				 0, NULL, ctx);
	}
    }
  return (HC_RET_OK);
}

int
soap_call_write_params (soap_call_ctx_t * ctx,
			caddr_t * err_ret, int header)
{
  caddr_t * params =  (0 == header  ? ctx->sc_params : ctx->sc_header_params);
  caddr_t param_name, param_value;
  dtp_t param_name_dtp, param_value_dtp;
  int i;

  for (i = 0; params && BOX_ELEMENTS (params) > 0 && i < (int) (BOX_ELEMENTS (params) - 1); i+= 2)
    {
      param_name = params[i];
      param_value = params[i + 1];
      param_name_dtp = DV_TYPE_OF (param_name);
      param_value_dtp = DV_TYPE_OF (param_value);

      if (!param_name)
	{
	  *err_ret = srv_make_new_error ("42000", "SP021",
	      "SOAP Parameters array invalid in call to %s#%s ",
		   ctx->sc_method_uri ? ctx->sc_method_uri : "", ctx->sc_method_name);
	  return (HC_RET_ERR_ABORT);
	}
      if ((!IS_STRING_DTP (param_name_dtp) && DV_ARRAY_OF_POINTER != param_name_dtp)
	  || (DV_ARRAY_OF_POINTER == param_name_dtp && BOX_ELEMENTS (param_name) < 2))
	{
	  *err_ret = srv_make_new_error ("42000", "SP022",
	      "SOAP Parameter name %d should be string in call to %s#%s",
	      i / 2, ctx->sc_method_uri ? ctx->sc_method_uri : "", ctx->sc_method_name);
	  return (HC_RET_ERR_ABORT);
	}
      if (DV_ARRAY_OF_POINTER == param_name_dtp)
	{
	  caddr_t par_name = ((caddr_t *) param_name)[0];
          caddr_t par_type = ((caddr_t *) param_name)[1];
	  int must_understand = (int) (header && BOX_ELEMENTS (param_name) > 2 ? unbox(((caddr_t *) param_name)[2]) : 0);
	  caddr_t actor = header && BOX_ELEMENTS (param_name) > 3 ? ((caddr_t *) param_name)[3] : NULL;
	  int save_literal = 0;

	  if (!IS_STRING_DTP (DV_TYPE_OF (par_name)) || !IS_STRING_DTP (DV_TYPE_OF (par_type)))
	    {
	      *err_ret = srv_make_new_error ("42000", "SP023",
		  "SOAP Parameter name reference %d should be array of name "
		  "and SOAP type as strings in call to %s#%s",
		  i / 2, ctx->sc_method_uri ? ctx->sc_method_uri : "", ctx->sc_method_name);
	      return (HC_RET_ERR_ABORT);
	    }
	  /*try to resolve elements*/
	  save_literal = ctx->sc_ser_ctx->literal;
	  if (soap_type_exists (par_type, 1) && !soap_type_exists (par_type, 0))
	    ctx->sc_ser_ctx->literal = 1;

	  ctx->sc_ser_ctx->add_schema = ADD_CUSTOM_SCH;
	  ctx->sc_ser_ctx->req_resp_namespace = NULL;
	  ctx->sc_ser_ctx->add_type = ctx->sc_ser_ctx->literal ? 0 : 1;
	  /* these are in SOAP Header */
	  ctx->sc_ser_ctx->must_understand = header ? must_understand : 0;
	  ctx->sc_ser_ctx->soap_actor = header ? actor : NULL;

	  soap_print_box_validating (param_value,
				     par_name,
				     ctx->sc_soap_out,
				     err_ret,
				     par_type,
				     ctx->sc_ser_ctx,
				     (ctx->sc_ser_ctx->literal && (!ctx->sc_ser_ctx->wrapped || header)) ? 1 : 0,
				     ctx->sc_ser_ctx->literal, NULL);
	  ctx->sc_ser_ctx->literal = save_literal;
	  if (*err_ret)
	    return (HC_RET_ERR_ABORT);
	}
      else if (NULL != (*err_ret = soap_print_box (param_value,
						  ctx->sc_soap_out,
						  param_name,
						  ctx->sc_ser_ctx->soap_version,
						  NULL, param_value_dtp, ctx->sc_ser_ctx)) && ctx->sc_ser_ctx->literal)
	return (HC_RET_ERR_ABORT);
    }
  return (HC_RET_OK);
}

static void
soap_call_make_header (soap_call_ctx_t * ctx, caddr_t * _err_ret)
{
  if (!ctx->sc_wss_security && !ctx->sc_header_params)
    return;
  else if (ctx->sc_wss_security && !ctx->sc_header_params)
    {
      SES_PRINT (ctx->sc_soap_out, "<SOAP:Header />"); /* to be extended with rp, wss etc. */
      return;
    }
  SES_PRINT (ctx->sc_soap_out, "<SOAP:Header>");
  soap_call_write_params (ctx, _err_ret, 1);
  SES_PRINT (ctx->sc_soap_out, "</SOAP:Header>");
}


int
soap_call_make_body (soap_call_ctx_t * ctx,
		     caddr_t * _err_ret)
{
  int literal = ctx->sc_ser_ctx->literal, wrapped = ctx->sc_ser_ctx->wrapped;
  int element_form = ctx->sc_ser_ctx->element_form;

  SES_PRINT (ctx->sc_soap_out, "<SOAP:Body");
#ifdef _SSL
  if (ctx->sc_wss_security)
    {
      char p [200], tmp[400];
      char * ns = soap_wsdl_get_ns_prefix (&(ctx->sc_ser_ctx->ns_set), WSU_URI(&(ctx->sc_ser_ctx->wsse_ctx)));

      uuid_str (p, sizeof (p));
      snprintf (tmp, sizeof (tmp), " %s%sId=\"Id-%s\"", ns ? ns : "", ns ? ":" : "", p);
      SES_PRINT (ctx->sc_soap_out, tmp);
    }
#endif
  SES_PRINT (ctx->sc_soap_out, ">");

  if (!literal || wrapped)
    {
      if (ctx->sc_method_uri && (!literal || !element_form))
	SES_PRINT (ctx->sc_soap_out, "\n<cli:");
      else
	SES_PRINT (ctx->sc_soap_out, "\n<");
      session_buffered_write (ctx->sc_soap_out,
			      ctx->sc_method_name,
			      strlen (ctx->sc_method_name));

      if (ctx->sc_ser_ctx->soap_version == 12 && !literal)
	{
	  SES_PRINT (ctx->sc_soap_out, " SOAP:encodingStyle='" SOAP_ENC_SCHEMA12 "'");
	}

      if (ctx->sc_method_uri)
	{
	  SES_PRINT (ctx->sc_soap_out, ((literal && element_form) ? " xmlns='" : " xmlns:cli='"));
	  SES_PRINT (ctx->sc_soap_out, ctx->sc_method_uri);
	  SES_PRINT (ctx->sc_soap_out, "' >");
	  dk_set_push (&ctx->sc_ser_ctx->ns, box_dv_short_string (literal ? "" : "cli"));
	}
      else
	SES_PRINT (ctx->sc_soap_out, ">");
    }

  soap_call_write_params (ctx, _err_ret, 0);

  if (*_err_ret)
    return (HC_RET_ERR_ABORT);

  if (!literal || wrapped)
    {
      if (ctx->sc_method_uri)
	{
	  caddr_t elm = (caddr_t) dk_set_pop (&ctx->sc_ser_ctx->ns);
	  dk_free_box (elm);
	}

      if (ctx->sc_method_uri && (!literal || !element_form))
	SES_PRINT (ctx->sc_soap_out, "</cli:");
      else
	SES_PRINT (ctx->sc_soap_out, "</");
      SES_PRINT (ctx->sc_soap_out, ctx->sc_method_name);
      SES_PRINT (ctx->sc_soap_out, ">");
    }

  SES_PRINT (ctx->sc_soap_out, "</SOAP:Body>");
  return (HC_RET_OK);
}

dk_session_t *
soap_call_make_envelope (soap_call_ctx_t * ctx,
			 caddr_t * _err_ret)
{
  if (ctx->sc_ser_ctx->soap_version == 1)
    SES_PRINT (ctx->sc_soap_out,
	"<?xml version='1.0' ?>\n"
	"<SOAP:Envelope\n"
	" xmlns:xsi='" W3C_TYPE_SCHEMA_XSI "'\n"
	" xmlns:xsd='" W3C_TYPE_SCHEMA_XSD "'\n"
	" xmlns:SOAP='" SOAP_TYPE_SCHEMA10 "'\n"
	" xmlns:dt='" MS_TYPE_SCHEMA "'>");
  else if (ctx->sc_ser_ctx->soap_version == 11)
    {
      SES_PRINT (ctx->sc_soap_out,
		 "<?xml version='1.0' ?>\n"
		 "<SOAP:Envelope\n");
      if (!ctx->sc_ser_ctx->literal)
	SES_PRINT (ctx->sc_soap_out, " SOAP:encodingType='" SOAP_ENC_SCHEMA11 "'\n");

      if (ctx->sc_ser_ctx->soap_version == 11 && !ctx->sc_ser_ctx->literal)
	SES_PRINT (ctx->sc_soap_out,
		   " SOAP:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/'\n");

      SES_PRINT (ctx->sc_soap_out,
	  	 " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'\n"
		 " xmlns:xsd=\"" W3C_2001_TYPE_SCHEMA_XSD "\" \n"
		 " xmlns:SOAP=\"" SOAP_TYPE_SCHEMA11 "\" \n"
		 " xmlns:SOAP-ENC=\"" SOAP_ENC_SCHEMA11 "\" \n" );
      SES_PRINT (ctx->sc_soap_out, " xmlns:ref=\"" SOAP_REF_SCH_200204 "\" \n");

      soap_wsdl_print_ns_decl (ctx->sc_soap_out, &(ctx->sc_ser_ctx->ns_set), NULL);

      SES_PRINT (ctx->sc_soap_out, " xmlns:dt='" MS_TYPE_SCHEMA "'>");
    }
  else if (ctx->sc_ser_ctx->soap_version == 12)
    {
      SES_PRINT (ctx->sc_soap_out,
		 "<?xml version='1.0' ?>\n"
		 "<SOAP:Envelope\n");
      SES_PRINT (ctx->sc_soap_out,
	  	 " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'\n"
		 " xmlns:xsd='" W3C_2001_TYPE_SCHEMA_XSD "' \n"
		 " xmlns:SOAP='" SOAP_TYPE_SCHEMA12 "' \n"
		 " xmlns:SOAP-ENC='" SOAP_ENC_SCHEMA12 "' \n" );
      soap_wsdl_print_ns_decl (ctx->sc_soap_out, &(ctx->sc_ser_ctx->ns_set), NULL);
      SES_PRINT(ctx->sc_soap_out, " xmlns:dt='" MS_TYPE_SCHEMA "'>");
    }
  else
    sqlr_new_error ("37000", "SP033", "Unknown SOAP version : %d", ctx->sc_ser_ctx->soap_version);

  soap_call_make_header (ctx, _err_ret);

  soap_call_make_body (ctx, _err_ret);

  if (*_err_ret)
    {
      return (NULL);
    }

  SES_PRINT (ctx->sc_soap_out, "</SOAP:Envelope>");
  return (HC_RET_OK);
}

/*HC_RET
soap_cli_pre_req_handler (http_cli_ctx * ctx, caddr_t parms, caddr_t ret)
{
  parms
}

HC_RET
soap_cli_pre_req_handler (http_cli_ctx * ctx, caddr_t parms, caddr_t ret)
{

}
*/
HC_RET
soap_xmlrpc2soap (soap_call_ctx_t * ctx, caddr_t * err_ret)
{
  static query_t *qr;
  caddr_t * pars = NULL;
  caddr_t body = NULL;

  if (!qr)
    {
      qr = sch_proc_def (isp_schema (NULL), "DB.DBA.XMLRPC2SOAP");
      if (qr->qr_to_recompile)
	qr = qr_recompile (qr, NULL);
    }

  if (!qr)
    {
      *err_ret = srv_make_new_error ("42001", "HT004", "No XMLRPC to SOAP filter defined");
      return (HC_RET_ERR_ABORT);
    }

  pars = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  pars[0] = box_string ("BODY");
  body = ctx->sc_http_client->hcctx_resp_body;
  pars [1] = (caddr_t) &body;

  *err_ret = qr_exec (ctx->sc_client, qr, CALLER_LOCAL, NULL, NULL, NULL, pars, NULL, 1);

  if (!*err_ret)
    ctx->sc_http_client->hcctx_resp_body = body;
  else
    {
      dk_free_tree (body);
      ctx->sc_http_client->hcctx_resp_body = NULL;
    }

  dk_free_box ((box_t) pars);
  return (HC_RET_OK);
}

#ifdef MALLOC_DEBUG
#define SOAP_CLI_DEBUG
#undef SOAP_CLI_DEBUG
#endif

caddr_t
soap_call_parse_reply (soap_call_ctx_t * ctx, caddr_t * qst, caddr_t * err, caddr_t * skeys)
{
  caddr_t *** volatile xml_tree = NULL;
  caddr_t * volatile envelope = NULL;
  caddr_t * volatile body = NULL;
  caddr_t * volatile header = NULL;
  caddr_t * volatile fault = NULL;
  caddr_t * volatile xml_tree1 = NULL;
  char encoding[1024];
  char * ctype = NULL;
  char * fault_code = NULL;
  char * fault_str = NULL;
  char * run_code = NULL;
  caddr_t resp_body = NULL;
  int dime_enc = 0;
  int mime_enc = 0;

  encoding[0] = 0;

  ctype = http_cli_get_resp_hdr (ctx->sc_http_client, "Content-Type: ");
  resp_body = ctx->sc_http_client->hcctx_resp_body;

#if defined(SOAP_CLI_DEBUG)
  if (!ctype || NULL == nc_strstr (ctype, "application/dime"))
    fprintf (stderr, "RESP:\n%s\n", resp_body ? resp_body : "");
#endif
  if (DO_LOG(LOG_SOAP_CLI))
    {
      client_connection_t *cli = ctx->sc_client;
      LOG_GET;
      log_info ("SOAP_3 %s %s %s : %*.*s", user, from, peer,
	  LOG_PRINT_SOAP_STR_L, LOG_PRINT_SOAP_STR_L, resp_body ? resp_body : "");
    }

  if (ctx->sc_http_client->hcctx_respcode > 399 &&
      (ctx->sc_use_xmlrpc ||
	!(ctx->sc_ser_ctx->soap_version > 1 && ctx->sc_http_client->hcctx_respcode == 500) /* SOAP 1.1 fault in 500 */
       )
      )
    {
      if (ctx->sc_http_client->hcctx_response && strlen (ctx->sc_http_client->hcctx_response) > 9)
	{
	  char err_string[100], *ptr;
	  strncpy (err_string, ctx->sc_http_client->hcctx_response + 9, sizeof (err_string) - 1);
	  err_string[99] = 0;

	  ptr = err_string + strlen (err_string);
	  while (ptr > err_string && isspace (ptr[-1]))
	    ptr --;
	  *ptr = 0;

	  *err = srv_make_new_error ("42000", "HT073", "HTTP error (%.100s) received",
	      err_string);
	}
      else
	*err = srv_make_new_error ("42000", "HT074", "HTTP error (%d) received",
	    ctx->sc_http_client->hcctx_respcode);
      if (ctx->sc_dl_mode) /* set the response into debug nfo */
	{
	  ctx->sc_dl_mode[2] = box_copy_tree (resp_body);
	}
      return NULL;
    }
  if (!resp_body)
    {
      *err = srv_make_new_error ("42000", "SP024", "No body");
      return (caddr_t) NULL;
    }

  if (ctype)
    {
      char *enc = strchr (ctype, ';'), *enc1 = encoding;
      if (enc)
	{
	  enc++;
	  while (isspace (*enc))
	    enc++;
	}
      if (enc && strncmp (enc, "charset", 7) && strncmp (enc, "CHARSET", 7))
	enc = NULL;
      if (enc)
	enc = strchr (enc + 1, '=');
      if (enc)
	{
	  enc++;
	  while (isspace (*enc) || *enc == '\"')
	    enc++;
	}
      if (enc)
	{
	  while (!isspace (*enc) && *enc != '\"')
	    {
	      *enc1++ = toupper (*enc++);
	    }
	  *enc1 = 0;
	}
      if (NULL != nc_strstr ((unsigned char *) ctype, (unsigned char *) "Multipart/Related"))
	mime_enc = 1;
      if (NULL != nc_strstr ((unsigned char *) ctype, (unsigned char *) "application/dime"))
	dime_enc = 1;
      if (mime_enc || dime_enc)
	{
	  caddr_t **dm = NULL;
	  dk_set_t set = NULL;
	  const char *_soap_uri;
	  if (mime_enc)
	    soap_mime_tree_ctx (ctx->sc_http_client->hcctx_req_ctype, ctx->sc_http_client->hcctx_resp_body,
		&set, err, ctx->sc_ser_ctx->soap_version, ctx->sc_http_client->hcctx_resp_hdrs);
	  else
	    soap_dime_tree (resp_body, &set, err);
	  dm = (caddr_t **)list_to_array (dk_set_nreverse (set));
	  _soap_uri = SOAP_URI(ctx->sc_ser_ctx->soap_version);
	  if (BOX_ELEMENTS (dm) > 0 && dm[0][1] && 0 == strcmp (dm[0][1], _soap_uri))
	    {
	      resp_body = dm[0][2];
	      dm[0][2] = NULL;
	      dime_enc = 1;
	    }
	  if (ctx->sc_dl_mode)
	    {
	      ctx->sc_dl_mode[4] = (caddr_t) dm; /* add attachments if any */
	    }
	  else
	    dk_free_tree ((box_t) dm);
	}
    }

  if (ctx->sc_dl_mode) /* set the input debug nfo */
    {
      ctx->sc_dl_mode[2] = box_copy_tree (resp_body);
    }
#ifdef _SSL
  if (ctx->sc_wss_security)
    {
      caddr_t decoded;
      /* now we'll try to decode & verify signature if exists */
      if (NULL != (decoded = xmlenc_decrypt_soap (qst, resp_body, ctx->sc_ser_ctx->soap_version, 6,
	  (encoding[0] ? encoding : "UTF-8"), server_default_lh, err, (caddr_t *)ctx->sc_wss_ns, skeys)))
	  {
	    dk_free_tree (ctx->sc_http_client->hcctx_resp_body);
	    ctx->sc_http_client->hcctx_resp_body = resp_body = decoded;
	  }

      if (*err)
	{
	  if (!ctx->sc_dl_mode)
	    return NULL;
	  else
	    {
	      dk_free_tree (*err);
	      *err = NULL;
	    }
	}

    }
#endif
  if (ctx->sc_use_xmlrpc) /* XMLRPC response */
    {
      soap_xmlrpc2soap (ctx, err);
      if (*err)
	return NULL;
      resp_body = ctx->sc_http_client->hcctx_resp_body;
    }

  xml_tree = (caddr_t ***) xml_make_tree ((query_instance_t *)qst,
					  resp_body, err,
					  encoding[0] ? encoding : 0,
					  server_default_lh, NULL /* no DTD */);
  if (!*err)
    {
      xml_expand_refs ((caddr_t *)xml_tree, err);
      if ((ctx->sc_ser_ctx->soap_version < 12 || dime_enc) && *err)
	{
	  dk_free_tree (*err);
	  *err = NULL;
	}
    }

  xml_tree1 = (caddr_t *) xml_tree;

  if (*err)
    {
      dk_free_tree ((box_t) xml_tree);
      return (caddr_t)NULL;
    }

  if (! (envelope = xml_find_child (xml_tree1, "Envelope",
				    SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL)))
    {
      *err = srv_make_new_error ("42000", "SP025",
	  "Not well formed SOAP request in call of %s#%s",
	  ctx->sc_method_uri ? ctx->sc_method_uri : "", ctx->sc_method_name);
      dk_free_tree ((box_t) xml_tree);
      return NULL;
    }

  if (!(body = xml_find_child (envelope, "Body", SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL)))
    {
      *err = srv_make_new_error ("42000", "SP026",
	  "No Body section in a SOAP reply to %s#%s",
	  ctx->sc_method_uri ? ctx->sc_method_uri : "", ctx->sc_method_name);
      dk_free_tree ((box_t) xml_tree);
      return NULL;
    }
  header = xml_find_child (envelope, "Header", SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL);

  if (!ctx->sc_return_fault && !ctx->sc_dl_mode &&
      NULL != (fault = xml_find_child (body, "Fault", SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL)))
    {
      if (ctx->sc_ser_ctx->soap_version == 12)
	{
	  caddr_t *ptr1, *ptr2;
	  ptr1 = xml_find_child (fault, "Code",
	      				SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL);
	  ptr2 = xml_find_child (fault, "Reason",
	      				SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL);
	  fault_code = (char *)xml_find_child (ptr1, "Value",
	      				SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL);
	  fault_str = (char *)xml_find_child (ptr2, "Text",
	      				SOAP_URI (ctx->sc_ser_ctx->soap_version), 0, NULL);
	}
      else
	{
	  fault_code = (char *)xml_find_child (fault, "faultcode", NULL, 0, NULL);
	  fault_str = (char *)xml_find_child (fault, "faultstring", NULL, 0, NULL);
	  run_code = (char *)xml_find_child (fault, "runcode", NULL, 0, NULL);
	}

      fault_code = (char *) (fault_code ? XML_ELEMENT_CHILD (((caddr_t *)fault_code), 0) : NULL);
      fault_str = (char *) (fault_str ? XML_ELEMENT_CHILD (((caddr_t *)fault_str), 0) : NULL);
      run_code = (char *) (run_code ? XML_ELEMENT_CHILD (((caddr_t *)run_code), 0) : NULL);

      *err = srv_make_new_error ("42000", "SP027",
	  "SOAP error %s calling %s :%s%s%s %s",
	  fault_code ? fault_code : "with unreported code",
	  ctx->sc_method_name,
	  run_code ? " [" : "",
	  run_code ? run_code : "",
	  run_code ? "]" : "",
	  fault_str ? fault_str : "unreported error");

      dk_free_tree ((box_t) xml_tree);
    }
  else
    {
      int inx = 0;
      caddr_t ret = NULL;

      if (ctx->sc_out_all)
	ret = box_copy_tree (xml_element_nonspace_child ((caddr_t) xml_tree, 0));
      else
	ret = box_copy_tree (xml_element_nonspace_child ((caddr_t) body, 0));
#if 0
      if (NULL == ret)
        GPF_T;
#endif
      DO_BOX (caddr_t, headerPart, inx, header)
	{
	  if (inx > 0 && BOX_ELEMENTS (headerPart) == 2 &&
	      DV_TYPE_OF (headerPart) == DV_ARRAY_OF_POINTER &&
	      !strcmp ("returnCode", extract_last_xml_name_part (XML_ELEMENT_NAME (headerPart))))
	    {
	      char *value = (char *) XML_ELEMENT_CHILD (headerPart, 0);
	      if (value && DV_TYPE_OF (value) != DV_ARRAY_OF_POINTER)
		*err = (caddr_t) (ptrlong) atoi (value);
	    }
	}
      END_DO_BOX;
      dk_free_tree ((box_t) xml_tree);
      if (ctx->sc_dl_mode)
	{
	  ctx->sc_dl_mode[0] = ret;
          ctx->sc_dl_mode[3] = NULL;
	  ret = (caddr_t) ctx->sc_dl_mode;
	}
      soap_wsdl_schema_free (&(ctx->sc_ser_ctx->ns_set), &(ctx->sc_ser_ctx->types_set));
      return ret;
    }
  return ((caddr_t)NULL);
}

#if 0
static void
soap_print_types (dk_set_t * types_set)
{
  DO_SET (soap_wsdl_type_t *, elm, types_set)
    {
      fprintf (stderr, ">>> %s %d\n", elm->type_name, elm->type_is_elem);
    }
  END_DO_SET();
}
#endif

HC_RET
soap_call_prep (soap_call_ctx_t * ctx, caddr_t * err_ret)
{
#ifdef _SSL
  if (ctx->sc_wss_security)
    {
      wsse_ser_ctx_t sctx;

      memset (&sctx, 0, sizeof (wsse_ser_ctx_t));
      xenc_set_serialization_ctx (ctx->sc_wss_ns, &sctx); /* XXX: duplicate */
      xenc_set_serialization_ctx (ctx->sc_wss_ns, &(ctx->sc_ser_ctx->wsse_ctx));
      soap_wsdl_ns_decl (&(ctx->sc_ser_ctx->ns_set), WSS_DSIG_URI, "ds");
      soap_wsdl_ns_decl (&(ctx->sc_ser_ctx->ns_set), WSS_XENC_URI, "xenc");
      soap_wsdl_ns_decl (&(ctx->sc_ser_ctx->ns_set), WSSE_URI(&sctx), "wsse");
      soap_wsdl_ns_decl (&(ctx->sc_ser_ctx->ns_set), WSU_URI(&sctx), "wssu");
    }
#endif
  soap_call_schema_prep (ctx->sc_ser_ctx, ctx->sc_params, 0);
  soap_call_schema_prep (ctx->sc_ser_ctx, ctx->sc_header_params, 1);
#if 0
  soap_print_types (&(ctx->sc_ser_ctx->types_set));
#endif
  soap_call_make_envelope (ctx, err_ret);
  return (HC_RET_OK);
}

HC_RET
soap_call_prep_wss (soap_call_ctx_t * ctx, caddr_t * err_ret)
{
#ifdef _SSL
  static query_t *qr = NULL;
  caddr_t * pars = NULL;
  dk_session_t * body = NULL;
  caddr_t keyi = NULL, _template = NULL, sign, ns = NULL;

  if (!qr)
    {
      qr = sch_proc_def (isp_schema (NULL), "DB.DBA.SOAP_CLIENT_WSS");
      if (qr->qr_to_recompile)
	qr = qr_recompile (qr, NULL);
    }

  if (!qr)
    {
      *err_ret = srv_make_new_error ("42001", "HT004", "No DB.DBA.SOAP_CLIENT_WSS defined");
      return (HC_RET_ERR_ABORT);
    }

  pars = (caddr_t *) dk_alloc_box (5 * 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  pars[0] = box_string ("BODY"); pars[2] = box_string ("KEYI");
  pars[4] = box_string ("TEMPLATE"); pars[6] = box_string ("SIGN");
  pars[8] = box_string ("NS");

  body = ctx->sc_soap_out; keyi = ctx->sc_wss_key;
  _template = ctx->sc_wss_template; sign = box_num (ctx->sc_wss_security);
  ns = ctx->sc_wss_ns;

  pars [1] = (caddr_t) &body; pars [3] = (caddr_t) &keyi;
  pars [5] = (caddr_t) &_template; pars [7] = (caddr_t) &sign;
  pars [9] = (caddr_t) &ns;

  *err_ret = qr_exec (ctx->sc_client, qr, CALLER_LOCAL, NULL, NULL, NULL, pars, NULL, 1);

  dk_free_box ((box_t) pars); dk_free_box (sign);
#endif
  return (HC_RET_OK);
}


HC_RET
soap_call2xmlrpc (soap_call_ctx_t * ctx, caddr_t * err_ret)
{
  static query_t *qr;
  caddr_t * pars = NULL;
  dk_session_t * body = NULL;

  if (!qr)
    {
      qr = sch_proc_def (isp_schema (NULL), "DB.DBA.SOAP2XMLRPC");
      if (qr->qr_to_recompile)
	qr = qr_recompile (qr, NULL);
    }

  if (!qr)
    {
      *err_ret = srv_make_new_error ("42001", "HT004", "No SOAP to XMLRPC filter defined");
      return (HC_RET_ERR_ABORT);
    }

  pars = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  pars[0] = box_string ("BODY");
  body = ctx->sc_soap_out;
  pars [1] = (caddr_t) &body;

  *err_ret = qr_exec (ctx->sc_client, qr, CALLER_LOCAL, NULL, NULL, NULL, pars, NULL, 1);

  dk_free_box ((box_t) pars);
  return (HC_RET_OK);
}

/****************************************
 Invoke a SOAP service via HTTP

 Parameters:
 1 - host & port
 2 - endpoint URL
 3 - method URI
 4 - method name
 5 - parameters array
 6 - SOAP version
 7 - PKCS12 certificate for SSL/TLS connection (string '1' means no client certificate)
 8 - password for certificate PK unlocking
 9 - SOAPAction value
 10 - Bit mask flags
      0x1 - literal style encoding
      0x2 - Wire dumps
      0x4 - wrapped literal style
      0x8 - DIME encoding
      0x10 - element form for literal style
      0x20 - XML-RPC filter on
      0x40 - return SOAP Envelope instead of SOAP Body
      0x80 - return fault messages, do not signal
 11 - HTTP auth user name
 12 - HTTP auth user password
 13 - WS-Security flag
 14 - Encryption key
 15 - XML Signature template
 16 - SOAP Header parameters
 17 - custom HTTP headers
 18 - OneWay/AsyncCall bitmask 1 - OneWay ; 2 - Do only request and return connection
 19 - WS-Security WS-Utility schemas
 20 (out) - Open client connection output (applicable with AsyncCall only)
 21 - Connection timeout in seconds
 22 (out) - WS-Security : keys used for decryption
 ***************************************/

caddr_t
bif_soap_call_new (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char* me = "soap_call";
  caddr_t err = NULL;
  int ns_contains = 0;
  ptrlong one_way = 0, send_only_req = 0;
  caddr_t ret = NULL, skeys = NULL;
  char hdr_tmp[1024];
  char ctype_tmp[1024];
  query_instance_t *qi = (query_instance_t *) qst;
  soap_ctx_t ssc;
  soap_call_ctx_t ctx;

  memset (&ctx, 0, sizeof (soap_call_ctx_t));
  memset (&ssc, 0, sizeof (soap_ctx_t));

  ctx.sc_client = qi->qi_client;
  ssc.qst = qst;
  ssc.cli = qi->qi_client;
  ctx.sc_ser_ctx = &ssc;
  ssc.dks_esc_compat = DKS_ESC_COMPAT_SOAP /*USE_CR_ESCAPE*/;
  dk_set_push (&ssc.o_attachments, NULL); /* put one empty element for body */

  ctx.sc_soap_out = strses_allocate();
  ctx.sc_method_uri = bif_string_or_null_arg (qst, args, 2, me);
  ctx.sc_method_name = bif_string_arg (qst, args, 3, me);
  ctx.sc_params = (caddr_t *) bif_array_or_null_arg (qst, args, 4, me);

  ctx.sc_http_client = http_cli_std_init (bif_string_arg (qst, args, 1, me), qst);

#ifndef _USE_CACHED_SES
  http_cli_set_http_10 (ctx.sc_http_client);
#else
  http_cli_set_http_11 (ctx.sc_http_client);
#endif /* _USE_CACHED_SES */


  if (!ctx.sc_http_client)
    {
      sqlr_new_error ("42000", "SP028", "Cannot initialize http client");
    }

  http_cli_set_target_host (ctx.sc_http_client, bif_string_arg (qst, args, 0, me));
  http_cli_set_ua_id (ctx.sc_http_client, http_soap_client_id_string);
  http_cli_set_req_content_type (ctx.sc_http_client, (caddr_t)"text/xml");
  http_cli_set_method (ctx.sc_http_client, HC_METHOD_POST);
  http_cli_set_retries (ctx.sc_http_client, 3);

  if (BOX_ELEMENTS (args) > 5)
    {
      ssc.soap_version = (int) bif_long_arg (qst, args, 5, me);
      if (ssc.soap_version < 0) /* debug mode, compat style */
	{
	  ctx.sc_debug_mode = 1;
	  ctx.sc_dl_mode = (caddr_t *) dk_alloc_box_zero (5 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  ssc.soap_version = ssc.soap_version * -1;
	}
    }

  if (BOX_ELEMENTS (args) > 8)
    ctx.sc_soap_action = bif_string_or_null_arg (qst, args, 8, me);

  if (BOX_ELEMENTS (args) > 9)
    {
      ctx.sc_dl_val = (long) bif_long_arg (qst, args, 9, me);

      if (ctx.sc_dl_val & 2 && !ctx.sc_dl_mode) /* trace debug mode */
	{
	  ctx.sc_dl_mode = (caddr_t *) dk_alloc_box_zero (5 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	}
      /*
        the return should have following structure:
	offset
	     0 - parsed response
	     1 - outgoing message
	     2 - incoming message
	     3 - error if exists
	     4 - attachments if any
       */

      if (ctx.sc_dl_val & 1) /* encoding style doc/lit */
	ssc.literal = 1;

      if (ctx.sc_dl_val & 4) /* parameters style for doc/lit wrapped */
	ssc.wrapped = 1;

      if (ctx.sc_dl_val & 0x10) /* element form for parameters style of doc/lit wrapped */
	ssc.element_form = 1;

      if (ctx.sc_dl_val & 8) /* use DIME encoding */
	ctx.sc_use_dime = 1;

      if (ctx.sc_dl_val & 0x20) /* make XMLRPC request */
	{
	  if (ssc.soap_version == 11)
	    ctx.sc_use_xmlrpc = 1;
	  else /* XXX: check WSS/DIME/literal etc. are not compatible with XMLRPC filters */
	    sqlr_new_error ("22023", "SC001", "XMLRPC filters are supported for SOAP 1.1 only");
	}

      if (ctx.sc_dl_val & 0x40) /* outgoing parse message */
	ctx.sc_out_all = 1;

      if (ctx.sc_dl_val & 0x80)
	ctx.sc_return_fault = 1;

      if (ctx.sc_dl_val & 0x100)
	ctx.sc_return_req = 1;

      if (ctx.sc_dl_val & 0x200)
	ctx.sc_use_mime = 1;
    }

/* Set http client to authorize */

  if (BOX_ELEMENTS (args) > 10)
    {
      caddr_t user = bif_string_or_null_arg (qst, args, 10, me);
      caddr_t pass = bif_string_or_null_arg (qst, args, 11, me);

      if (user && pass)
        http_cli_init_std_auth (ctx.sc_http_client, user, pass);
    }

  if (BOX_ELEMENTS (args) > 12)
    {
      int sec = (int) bif_long_arg (qst, args, 12, me);
      caddr_t key = bif_arg (qst, args, 13, me);
      caddr_t templ = bif_string_or_null_arg (qst, args, 14, me);
      ctx.sc_wss_security = sec;
      if (ctx.sc_wss_security && ssc.soap_version != 11)
	{
	  sqlr_new_error ("22023", "SC002", "WSSecurity filters are supported for SOAP 1.1 only");
	}
      if (sec)
	{
	  ctx.sc_wss_key = box_copy_tree (key);
	  ctx.sc_wss_template = templ ? templ : NEW_DB_NULL;
        }
      if (BOX_ELEMENTS (args) > 18) /* WS-Security/WS-Utility/OASIS schemas for wsse&wsu */
	{
	  caddr_t wss_sch = bif_strict_array_or_null_arg (qst, args, 18, me);
	  ctx.sc_wss_ns = wss_sch ? box_copy_tree (wss_sch) : NEW_DB_NULL;
	}
      else
	ctx.sc_wss_ns = NEW_DB_NULL;
    }

  if (BOX_ELEMENTS (args) > 15)
    {
      ctx.sc_header_params = (caddr_t *) bif_array_or_null_arg (qst, args, 15, me);
    }

#if _SSL
  if (BOX_ELEMENTS (args) > 6 && !ctx.sc_wss_security)
    {
      http_cli_ssl_cert (ctx.sc_http_client, bif_string_or_null_arg (qst, args, 6, me));
      if (BOX_ELEMENTS (args) > 7)
	http_cli_ssl_cert_pass (ctx.sc_http_client, bif_string_or_null_arg (qst, args, 7, me));
    }
#endif /* _SSL */

  if (ctx.sc_method_uri && !strncmp (ctx.sc_method_uri,
				     ctx.sc_method_name,
				     strlen (ctx.sc_method_uri)) && ssc.soap_version > 1)
    {
      ctx.sc_method_name = ctx.sc_method_name + strlen (ctx.sc_method_uri);
      ns_contains = 1;
    }

  if (ssc.soap_version == 1)
    {
      http_cli_set_req_content_type (ctx.sc_http_client, (caddr_t) "text/xml");
      snprintf (hdr_tmp, sizeof (hdr_tmp), "SOAPMethodName: %s#%s\r\n",
	     ctx.sc_method_uri ? ctx.sc_method_uri : "",
	     ctx.sc_method_name);
    }
  if (ssc.soap_version == 11)
    {
      http_cli_set_req_content_type (ctx.sc_http_client,
				     ctx.sc_use_dime ? (caddr_t) "application/dime" : (caddr_t) "text/xml; charset=utf-8");
      snprintf (hdr_tmp, sizeof (hdr_tmp), "SOAPAction: %s%s%s\r\n",
	       !ctx.sc_soap_action && ctx.sc_method_uri ? ctx.sc_method_uri : "",
	       ctx.sc_soap_action || ns_contains  ? "" : "#",
	       ctx.sc_soap_action ? ctx.sc_soap_action : ctx.sc_method_name);
    }
  if (ssc.soap_version == 12)
    {
      if (ctx.sc_use_dime)
        strcpy_ck (ctype_tmp, "application/dime");
      else if (ctx.sc_soap_action)
	snprintf (ctype_tmp, sizeof (ctype_tmp), SOAP_CTYPE_12 "; charset=\"utf-8\"; action=%s", ctx.sc_soap_action);
      else
	strcpy_ck (ctype_tmp, SOAP_CTYPE_12 "; charset=\"utf-8\"");
      http_cli_set_req_content_type (ctx.sc_http_client, ctype_tmp);
      hdr_tmp [0] = 0;
    }

  if (!ctx.sc_use_xmlrpc)
    http_cli_add_req_hdr (ctx.sc_http_client, hdr_tmp);

  if (BOX_ELEMENTS (args) > 16)
    {
      caddr_t http_hdr = bif_string_or_null_arg (qst, args, 16, me);
      if (http_hdr)
	http_cli_add_req_hdr (ctx.sc_http_client, http_hdr);
    }

  if (BOX_ELEMENTS (args) > 17)
    {
      one_way = bif_long_arg (qst, args, 17, me);
      send_only_req = one_way & 0x2;
      one_way &= 0x1;
    }

  if (BOX_ELEMENTS (args) > 20)
    {
      uint32 time_out = (uint32) bif_long_arg (qst, args, 20, me);
      ctx.sc_http_client->hcctx_timeout = time_out;
    }

  soap_call_prep (&ctx, &err);

#if defined(SOAP_CLI_DEBUG)
    {
      caddr_t envel;
      envel = strses_string (ctx.sc_soap_out);
      fprintf (stderr, "REQ:\n%s\n", envel);
      dk_free_tree (envel);
    }
#endif
  if (DO_LOG(LOG_SOAP_CLI))
    {
      client_connection_t *cli = ctx.sc_client;
      dk_session_t * ses = ctx.sc_soap_out;
      LOG_GET;
      log_info ("SOAP_2 %s %s %s : %*.*s", user, from, peer,
	  ses->dks_out_fill > LOG_PRINT_SOAP_STR_L ? LOG_PRINT_SOAP_STR_L : ses->dks_out_fill,
	  ses->dks_out_fill > LOG_PRINT_SOAP_STR_L ? LOG_PRINT_SOAP_STR_L : ses->dks_out_fill,
	  ses->dks_out_buffer);
    }

  if (ctx.sc_wss_security)
    soap_call_prep_wss (&ctx, &err);

#if defined(SOAP_CLI_DEBUG)
    {
      caddr_t envel;
      envel = strses_string (ctx.sc_soap_out);
      fprintf (stderr, "REQ:\n%s\n", envel);
      dk_free_tree (envel);
    }
#endif

  if (ctx.sc_use_xmlrpc)
    soap_call2xmlrpc (&ctx, &err);

  if (ctx.sc_dl_mode) /* add the debug info */
    ctx.sc_dl_mode[1] = strses_string (ctx.sc_soap_out);

  if (!err && ctx.sc_use_dime)
    {
      caddr_t data = strses_string (ctx.sc_soap_out);
      caddr_t req = list (3, box_dv_short_string(""), box_dv_short_string (SOAP_URI(ssc.soap_version)), data);
      caddr_t * dime_arr = (caddr_t *)list_to_array (dk_set_nreverse (ssc.o_attachments));

      dime_arr[0] = req;

      strses_flush (ctx.sc_soap_out);
      dime_compose (ctx.sc_soap_out, (caddr_t *)dime_arr, &err);
      dk_free_tree ((box_t) dime_arr);
    }
  else if (!err && ctx.sc_use_mime)
    {
      caddr_t data = strses_string (ctx.sc_soap_out);
      caddr_t req = list (3, box_dv_short_string(""), box_dv_short_string (SOAP_URI(ssc.soap_version)), data);
      caddr_t * dime_arr = (caddr_t *)list_to_array (dk_set_nreverse (ssc.o_attachments));

      dime_arr[0] = req;

      strses_flush (ctx.sc_soap_out);
      mime_c_compose (ctx, (caddr_t *)dime_arr);
      dk_free_tree ((box_t) dime_arr);
    }
   else
    dk_free_tree (list_to_array (dk_set_nreverse (ssc.o_attachments)));

  if (!err)
    {
      volatile int parse_reply = 0;
      IO_SECT(qst);
      strses_write_out (ctx.sc_soap_out, ctx.sc_http_client->hcctx_req_body);
      if (ctx.sc_return_req)
	{
	  ret = strses_string (ctx.sc_soap_out);
	}
      else if (send_only_req) /* send the request, and return the connection */
	{
	  ctx.sc_http_client->hcctx_keep_alive = 0;
	  ctx.sc_http_client->hcctx_no_cached = 1;
	  if (HC_RET_ERR_ABORT == http_cli_send_request (ctx.sc_http_client))
	    err = http_cli_get_err (ctx.sc_http_client);
	  else
	    {
	      if (BOX_ELEMENTS (args) > 19 && ssl_is_settable (args[19]))
		{
		  caddr_t * conn = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_CONNECTION);
		  conn [0] = (caddr_t) ctx.sc_http_client->hcctx_http_out;
		  ctx.sc_http_client->hcctx_http_out = NULL;
		  qst_set (qst, args[19], (caddr_t) conn);
		}
	      ret = NEW_DB_NULL;
	    }
	}
      else if (HC_RET_ERR_ABORT == http_cli_main (ctx.sc_http_client))
	err = http_cli_get_err (ctx.sc_http_client);
      else if (one_way && (!ctx.sc_http_client->hcctx_resp_body || !*ctx.sc_http_client->hcctx_resp_body))
	ret = NEW_DB_NULL;
      else
	parse_reply = 1;
      END_IO_SECT (err_ret);
      if (parse_reply)
	ret = soap_call_parse_reply (&ctx, qst, &err, &skeys);
    }

   if (ctx.sc_use_mime)
    {
      dk_free_box (ctx.sc_http_client->hcctx_host);
      ctx.sc_http_client->hcctx_host = NULL;
    }

  http_cli_ctx_free (ctx.sc_http_client);

  strses_free (ctx.sc_soap_out);
  dk_free_tree (ctx.sc_wss_ns);
  soap_wsdl_schema_free (&(ctx.sc_ser_ctx->ns_set), &(ctx.sc_ser_ctx->types_set));

  if (!err && BOX_ELEMENTS (args) > 21 && ssl_is_settable (args[21]))
    qst_set (qst, args[21], skeys ? skeys : NEW_DB_NULL);
  else
    dk_free_tree (skeys);

  if (err)
    {
      if (ctx.sc_dl_mode && ctx.sc_debug_mode)
	{
	  ctx.sc_dl_mode[3] = err;
	  ret = (caddr_t) ctx.sc_dl_mode;
	}
      else
	{
	  dk_free_tree ((box_t) ctx.sc_dl_mode);
	  sqlr_resignal (err);
        }
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return (ret);
}

caddr_t
bif_soap_receive (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char* me = "soap_receive";
  caddr_t err = NULL, skeys = NULL;
  caddr_t ret = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  soap_ctx_t ssc;
  soap_call_ctx_t ctx;
  caddr_t * conn = (caddr_t *) bif_arg (qst, args, 0, me);
  dk_session_t * ses = NULL;
  IO_SECT(qst);

  memset (&ctx, 0, sizeof (soap_call_ctx_t));
  memset (&ssc, 0, sizeof (soap_ctx_t));

  ctx.sc_client = qi->qi_client;
  ssc.qst = qst;
  ssc.cli = qi->qi_client;
  ctx.sc_ser_ctx = &ssc;
  ssc.dks_esc_compat = DKS_ESC_COMPAT_SOAP;

  ssc.soap_version = (int) bif_long_arg (qst, args, 1, me);

  if (BOX_ELEMENTS (args) > 2)
    {
      ctx.sc_dl_val = (long) bif_long_arg (qst, args, 2, me);

      if (ctx.sc_dl_val & 8) /* use DIME encoding */
	ctx.sc_use_dime = 1;

      if (ctx.sc_dl_val & 0x20) /* make XMLRPC request */
	{
	  if (ssc.soap_version == 11)
	    ctx.sc_use_xmlrpc = 1;
	  else
	    sqlr_new_error ("22023", "SC001", "XMLRPC filters are supported for SOAP 1.1 only");
	}

      if (ctx.sc_dl_val & 0x40) /* outgoing parse message */
	ctx.sc_out_all = 1;

      if (ctx.sc_dl_val & 0x80)
	ctx.sc_return_fault = 1;
    }

  ctx.sc_http_client = http_cli_std_init ("", qst);
  ctx.sc_wss_security = 1;

#ifndef _USE_CACHED_SES
  http_cli_set_http_10 (ctx.sc_http_client);
#else
  http_cli_set_http_11 (ctx.sc_http_client);
#endif /* _USE_CACHED_SES */

  if (!ctx.sc_http_client)
    {
      sqlr_new_error ("42000", "SP028", "Cannot initialize http client");
    }

  if (DV_CONNECTION == DV_TYPE_OF (conn))
    {
      ses = (dk_session_t *) conn[0];
      if (DKSESSTAT_ISSET (ses, SST_OK))
	conn[0] = NULL;
      else
	ses = NULL;
    }

  if (ses == NULL)
    err = srv_make_new_error ("22023", "SP000", "The soap_receive expects an open connection as 1-st argument");
  else
    {
      ctx.sc_http_client->hcctx_http_out = ses;
      ctx.sc_http_client->hcctx_keep_alive = 0;

      if (HC_RET_ERR_ABORT == http_cli_read_response (ctx.sc_http_client))
	err = http_cli_get_err (ctx.sc_http_client);
      else
	ret = soap_call_parse_reply (&ctx, qst, &err, &skeys);
    }

  http_cli_ctx_free (ctx.sc_http_client);

  if (!err && BOX_ELEMENTS (args) > 3 && ssl_is_settable (args[3]))
    qst_set (qst, args[3], skeys ? skeys : NEW_DB_NULL);
  else
    dk_free_tree (skeys);

  if (err)
    {
      sqlr_resignal (err);
    }

  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return (ret);
}


caddr_t
ws_soap_get_url (ws_connection_t *ws, int full_path)
{
  char szHostBuffer[512], *szHost = NULL;
  int inx, len;
  dk_session_t *out = strses_allocate ();
  caddr_t res;
  int is_https = 0;
#ifdef _SSL
  SSL *ssl = (SSL *) tcpses_get_ssl (ws->ws_session->dks_session);
  is_https = (NULL != ssl);
#endif

  if (!(szHost = ws_mime_header_field (ws->ws_lines, "Host", NULL, 0)))
    {
      struct sockaddr_in sa;
      socklen_t len = sizeof (sa);
      if (!getsockname (tcpses_get_fd (ws->ws_session->dks_session), (struct sockaddr *)&sa, &len))
	{
#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS))
	  char buff [4096];
	  int herrnop;
	  struct hostent ht;
#endif
	  struct hostent *host = NULL;
#if defined (_REENTRANT) && defined (linux)
	  gethostbyaddr_r ((char *)&sa.sin_addr, sizeof (sa.sin_addr), AF_INET, &ht, buff, sizeof (buff), &host, &herrnop);
#elif defined (_REENTRANT) && defined (SOLARIS)
	    host = gethostbyaddr_r ((char *)&sa.sin_addr, sizeof (sa.sin_addr), AF_INET, &ht, buff, sizeof (buff), &herrnop);
#else
	    host = gethostbyaddr ((char *)&sa.sin_addr, sizeof (sa.sin_addr), AF_INET);
#endif
	  if (host)
	    {
	      snprintf (szHostBuffer, sizeof (szHostBuffer), "%s:%u", host->h_name, ntohs (sa.sin_port));
	      szHost = szHostBuffer;
	    }
	}
    }
  if (szHost)
    {
      if (is_https)
       SES_PRINT (out, "https:");
      else if (full_path)
       SES_PRINT (out, "http:");
      SES_PRINT (out, "//");
      SES_PRINT (out, szHost);
      if (!strchr (szHost, ':'))
	{
	  struct sockaddr_in sa;
	  socklen_t len = sizeof (sa);
	  char szPort[10];
	  if (!getsockname (tcpses_get_fd (ws->ws_session->dks_session), (struct sockaddr *)&sa, &len))
	    {
	      uint16 port = ntohs (sa.sin_port);
	      if ((is_https && port != 443) || (!is_https && port != 80))
		{
		  snprintf (szPort, sizeof (szPort), ":%u", port);
	          SES_PRINT (out, szPort);
	        }
	    }
	}
      if (szHost != szHostBuffer)
	dk_free_box (szHost);
    }
  len = BOX_ELEMENTS_0 (ws->ws_path);
  if (!full_path)
    len --;
  DO_BOX (char *, path_elem, inx, ws->ws_path)
    {
      if (inx < len)
	{
	  session_buffered_write_char ('/', out);
	  SES_PRINT (out, path_elem);
	}
    }
  END_DO_BOX;
  res = strses_string (out);
  strses_free (out);
  return res;
}

static char *
soap_wsdl_ns_prefix (char * name, dk_set_t * types_set, char * def, int * is_elem)
{
  char * sep = strrchr (name, ':');
  char * br  = strchr (name, '[');
  char * ret = def;
  int try_elem = is_elem ? *is_elem : -1;
  if (sep && types_set)
    {
      DO_SET (soap_wsdl_type_t *, elm, types_set)
	{
	  if ((br && br > name && !strncmp (elm->type_name, name, (size_t)(br - name))) ||
             (!strcmp (elm->type_name, name)))
	    {
	      if (try_elem >= 0)
		{
		  *is_elem = elm->type_is_elem;
		  if (try_elem != elm->type_is_elem)
		    {
		      ret = elm->type_ns->ns_pref;
		      continue;
		    }
		}
	      return elm->type_ns->ns_pref;
	    }
	}
      END_DO_SET();
    }
  return ret;
}

static void
soap_print_q_name_1 (dk_session_t * out, char * name, int xsd_print, char *this_ns, dk_set_t * types_set)
{
  char * sep = strrchr (name, ':');
  char * br  = strchr (name, '[');

  if (!strcmp (name, SOAP_ANY_TYPE) || !strcmp (name, SOAP_XML_TYPE))
    {
      SES_PRINT (out, xsd_print ? "xsd:string" : "string");
      return;
    }

  if (sep && types_set)
    {
      DO_SET (soap_wsdl_type_t *, elm, types_set)
	{
	  if ((br && br > name && !strncmp (elm->type_name, name, (size_t)(br - name))) ||
             (!strcmp (elm->type_name, name)))
	    {
	      SES_PRINT (out, elm->type_ns->ns_pref);
	      SES_PRINT (out, ":");
	      goto print_name;
	    }
	}
      END_DO_SET();
    }

  if (sep && 0 == strncmp (name, SOAP_ENC_SCHEMA11, (size_t)(sep - name)))
    SES_PRINT (out, "soapenc:");
  else if (sep && 0 == strncmp (name, "services.wsdl", (size_t)(sep - name)))
    SES_PRINT (out, this_ns); /* can be tns: or s: depending of place */
  else if (sep && 0 == strncmp (name, SOAP_WSDL_SCHEMA11, (size_t)(sep - name)))
    SES_PRINT (out, "wsdl:");
  else if (xsd_print && sep && 0 == strncmp (name, W3C_2001_TYPE_SCHEMA_XSD, (size_t)(sep - name)))
    SES_PRINT (out, "xsd:");
  else if (sep && 0 == strncmp (name, SOAP_CONTENT_TYPE_200204, (size_t)(sep - name)))
    SES_PRINT (out, "content:");
  else if (sep && 0 == strncmp (name, SOAP_REF_SCH_200204, (size_t)(sep - name)))
    SES_PRINT (out, "ref:");

print_name:
  if (sep)
    SES_PRINT (out, sep + 1);
  else
    SES_PRINT (out, name);
}


static void
soap_sch_start_tag (caddr_t *tag, dk_session_t * out, int child, char **type, dk_set_t * types_set)
{
  caddr_t name = tag[0];
  int inx, len = BOX_ELEMENTS (tag);
  SES_PRINT (out, "<");
  soap_print_q_name (out, name, types_set);
  for (inx = 1; inx < len; inx+=2)
    {
      if (!strcmp (name, SOAP_TAG_DT_ELEMENT) && !strcmp (tag[inx], "type"))
	*type = tag[inx+1];
      if (' ' == tag[inx][0] || !strcmp (tag[inx], "targetNamespace"))
	continue;
      SES_PRINT (out, " ");
      soap_print_q_name (out, tag[inx], types_set);
      SES_PRINT (out, "=\"");
      soap_print_q_name (out, tag[inx+1], types_set);
      SES_PRINT (out, "\"");
    }
  if (child)
    SES_PRINT (out, ">\n");
  else
    SES_PRINT (out, "/>\n");
}

static void
soap_sch_end_tag (caddr_t *tag, dk_session_t * out, int child, dk_set_t * types_set)
{
  caddr_t name = tag[0];
  if (!child)
    return;
  SES_PRINT (out, "</");
  soap_print_q_name (out, name, types_set);
  SES_PRINT (out, ">\n");
}

static int
soap_dt_is_struct (caddr_t *tree1)
{
  int inx, len;
  caddr_t *tree = (caddr_t *)(tree1[0]);

  if (!strcmp (tree[0], SOAP_TAG_DT_CPX_CNT) && BOX_ELEMENTS(tree1) > 1 && ARRAYP(tree1[1])
      && BOX_ELEMENTS(tree1[1]) > 0 && ARRAYP (((caddr_t *)tree1[1])[0]))
    tree = (caddr_t *)(((caddr_t *)tree1[1])[0]);

  if (!strcmp (tree[0], SOAP_TAG_DT_RESTRICT) || !strcmp (tree[0], SOAP_TAG_DT_EXTENSION))
    {
      len = BOX_ELEMENTS (tree);
      for (inx = 1; inx < len; inx += 2)
	{
	  if (!strcmp (tree[inx], "base") && !strcmp (tree [inx+1], SOAP_ATTR_DT_STRUCT))
	    return 1;
	}
    }
  return 0;
}


static void
soap_sch_serialize (caddr_t *tree, dk_session_t * out, int sp, char **type, dk_set_t * types_set)
{
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int inx = 0, len = BOX_ELEMENTS (tree);
      int is_struct = soap_dt_is_struct (tree);
      if (uname__comment == XML_ELEMENT_NAME(tree))
	return;
      if (!is_struct)
	{
	  sp+=2;
#if 0
	  if (!strcmp (XML_ELEMENT_NAME(tree), SOAP_TAG_DT_ATTR))
	    {
	      caddr_t ref = xml_find_schema_attribute (tree, "ref");
	      if (ref && !strcmp (ref, SOAP_ENC_SCHEMA11 ":arrayType"))
		{
		  PRINT_SPACE_B (out, sp);
		  SES_PRINT(out,"<attributeGroup ref=\"soapenc:commonAttributes\"/>\n");
		  PRINT_SPACE_B (out, sp);
		  SES_PRINT(out,"<attribute ref=\"soapenc:offset\" />\n");
		}
	    }
#endif
	  PRINT_SPACE_B (out, sp);
	  soap_sch_start_tag ((caddr_t *)tree[0], out, len - 1, type, types_set);
	}
      for (inx = 1; inx < len; inx++)
	{
	  soap_sch_serialize ((caddr_t *) tree[inx], out, sp, type, types_set);
	}

#if 0
      if (!is_struct && !strcmp (((caddr_t **)tree)[0][0], SOAP_TAG_DT_ATTR))
	{
	  if (type && *type)
	    {
	      PRINT_SPACE_B (out, sp);
	      SES_PRINT (out,"<attribute ref=\"soapenc:arrayType\" wsdl:arrayType=\"");
	      soap_print_q_name (out, *type);
	      SES_PRINT (out,"[]\"/>\n");
	    }
	}
#endif

      if (!is_struct)
	{
	  if (len > 1)
	    PRINT_SPACE_B (out, sp);
	  soap_sch_end_tag ((caddr_t *)tree[0], out, len - 1, types_set);
	}
    }
}

/*#define SOAP_HASH_DBG*/

#ifdef SOAP_HASH_DBG
static void
soap_print_types_hash (int what)
{
  char **pk;
  caddr_t ** ptp;
  id_hash_iterator_t it;
  id_hash_iterator (&it, HT_SOAP (what));
  while (hit_next (&it, (caddr_t *) & pk, (caddr_t *) & ptp))
    {
      fprintf (stderr, "%s\n", *pk);
    }
}
static caddr_t
bif_print_types_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int what = bif_long_arg (qst, args, 0, "print_types_hash");
  soap_print_types_hash (what);
  return 0;
}
#endif

static void
soap_wsdl_find_schemas (dk_set_t * ns_set, dk_set_t * types_set, dk_set_t * procs_set, soap_ctx_t *ctx,
    const char * qpref, size_t pref_len, char * qual)
{
  char * operation_name, q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];

  /* Find in procedures what types are referenced */
  DO_SET (query_t *, proc, procs_set)
    {
      char * custom_type = NULL;
      int ix, literal;
      if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	operation_name = proc->qr_proc_name + pref_len;
      else
	{
          sch_split_name (qual, proc->qr_proc_name, q, o, n);
	  operation_name = n;
	}
      ix = 0;
      literal = (SOAP_MSG_LITERAL & proc->qr_proc_place);
      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	{
	  int param_enc;
	  const char * use = (IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]) ? SOAP_OPT (USE, proc, ix, NULL) : NULL);

	  SOAP_USE (use, param_enc, literal);

	  custom_type = proc->qr_parm_alt_types[ix];
	  if (custom_type
	      && 0 != strncmp (custom_type, W3C_2001_TYPE_SCHEMA_XSD , strlen (W3C_2001_TYPE_SCHEMA_XSD)))
	    soap_wsdl_schema_push (ns_set, types_set, custom_type, param_enc, 0, NULL, ctx);
	  else if (IS_COMPLEX_SQT (ssl->ssl_sqt))
	    {
	      char *scl_soap_type = soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx->opts, operation_name, ssl->ssl_name);
	      soap_wsdl_schema_push (ns_set, types_set, scl_soap_type, param_enc, 0, &(ssl->ssl_sqt), ctx);
	      dk_free_box (scl_soap_type);
	    }
	  ix++;
	}
      END_DO_SET ();
      /* return type */
      custom_type = proc->qr_proc_alt_ret_type;
      if (custom_type && DV_STRINGP(custom_type) && 0 != stricmp(custom_type, SOAP_VOID_TYPE)
	  && 0 != strncmp (custom_type, W3C_2001_TYPE_SCHEMA_XSD , strlen (W3C_2001_TYPE_SCHEMA_XSD)))
	soap_wsdl_schema_push (ns_set, types_set, custom_type, (SOAP_MSG_LITERAL & proc->qr_proc_place), 0, NULL, ctx);
      else if (proc->qr_proc_ret_type)
	{
	  sql_type_t sqt;
	  ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
	  if (IS_COMPLEX_SQT (sqt))
	    {
	      char * scl_soap_type = soap_sqt_to_soap_type (&(sqt), NULL, ctx->opts, operation_name, "Response");
	      soap_wsdl_schema_push (ns_set, types_set, scl_soap_type, (SOAP_MSG_LITERAL & proc->qr_proc_place),
		  0, &(sqt), ctx);
	      dk_free_box (scl_soap_type);
	    }
	}
    }
  END_DO_SET ()
}

/* XSD generation for RPC-like literal encoding */
static void
soap_print_dl_schema (dk_session_t * out, dk_set_t * proc_set,
                       char *qpref, size_t pref_len, caddr_t qual, int sch_elm_qual,
		       soap_ctx_t *ctx, dk_set_t * types_set, dk_set_t * ns_set, char * tns,
		       int dl_flag, int type_mask)
{
  char * operation_name, q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  int out_pars = 0;

  if (dl_flag != (SOAP_MSG_LITERALW | SOAP_MSG_LITERAL) || !tns)
    return;

  /* Find in procedures what types are referenced */
  DO_SET (query_t *, proc, proc_set)
    {
      char * custom_type = NULL;
      int ix = 0;

      if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	operation_name = proc->qr_proc_name + pref_len;
      else
	{
          sch_split_name (qual, proc->qr_proc_name, q, o, n);
	  operation_name = n;
	}

      if (type_mask & proc->qr_proc_place)
	continue;
      /* input message */
      SES_PRINT (out, "\t<element name=\""); SES_PRINT (out, operation_name); SES_PRINT (out, "\" >\n");
      SES_PRINT (out, "\t  <complexType>\n");
      SES_PRINT (out, "\t    <sequence>\n");
      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	{
	  if (ssl->ssl_type != SSL_REF_PARAMETER_OUT &&
	      !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	      !IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
	    {
	      custom_type = proc->qr_parm_alt_types[ix];
	      SES_PRINT (out,"\t\t <element minOccurs='1' maxOccurs='1' name='");
	      SOAP_PRINT(PART_NAME, out, proc, ix, ssl->ssl_name)
	      SES_PRINT (out, "' type='");
	      if (!custom_type)
		{
		  if (IS_COMPLEX_SQT (ssl->ssl_sqt))
		    {
		      caddr_t type_name = soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx->opts, operation_name, ssl->ssl_name);
		      wsdl_print_q_name (out, type_name, types_set);
		      dk_free_box (type_name);
		    }
		  else
		    {
		      SES_PRINT (out, "xsd:");
		      SES_PRINT (out, dtp_to_soap_type (ssl->ssl_dtp));
		    }
		}
	      else
		wsdl_print_q_name (out, custom_type, types_set);
	      SES_PRINT (out, "' />\n");
	    }
	  else if (IS_SSL_REF_PARAMETER (ssl->ssl_type) &&
	      !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	      !IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
	    {
	      out_pars++;
	    }
	  ix++;
	}
      END_DO_SET ();
      SES_PRINT (out, "\t    </sequence>\n");
      SES_PRINT (out, "\t  </complexType>\n");
      SES_PRINT (out, "\t</element>\n");
      /* output message */
      SES_PRINT (out, "\t<element name=\""); SES_PRINT (out, operation_name);

      /* no out params, just */
      if (0 == out_pars && proc->qr_proc_ret_type)
	{
	  sql_type_t sqt;
	  ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
	  if (IS_UDT_XMLTYPE_SQT(&sqt))
	    {
	      caddr_t type_name
		  = soap_sqt_to_soap_type (&(sqt), NULL, ctx->opts, operation_name, "Response");
	      SES_PRINT (out, "Response\" type='");
	      wsdl_print_q_name (out, type_name, types_set);
	      dk_free_box (type_name);
	      SES_PRINT (out, "'>");
	      goto skip_out_pars;
	    }
	}

      SES_PRINT (out, "Response\" >\n");
      SES_PRINT (out, "\t  <complexType>\n");
      SES_PRINT (out, "\t    <all>\n");
      ix = 0;
      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	{
	  if (IS_SSL_REF_PARAMETER (ssl->ssl_type) &&
	      !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	      !IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
	    {
	      custom_type = proc->qr_parm_alt_types[ix];
	      SES_PRINT (out,"\t\t <element minOccurs='1' maxOccurs='1' name='");
	      SOAP_PRINT(PART_NAME, out, proc, ix, ssl->ssl_name)
	      SES_PRINT (out, "' type='");
	      if (!custom_type)
		{
		  if (IS_COMPLEX_SQT (ssl->ssl_sqt))
		    {
		      caddr_t type_name = soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx->opts, operation_name, ssl->ssl_name);
		      wsdl_print_q_name (out, type_name, types_set);
		      dk_free_box (type_name);
		    }
		  else
		    {
		      SES_PRINT (out, "xsd:");
		      SES_PRINT (out, dtp_to_soap_type (ssl->ssl_dtp));
		    }
		}
	      else
		wsdl_print_q_name (out, custom_type, types_set);
	      SES_PRINT (out, "' />\n");
	    }
	  ix++;
	}
      END_DO_SET ();
      /* return; special case */
      custom_type = proc->qr_proc_alt_ret_type;
      if (proc->qr_proc_place & SOAP_MSG_HTTP)
	custom_type = NULL;

      if (custom_type && DV_STRINGP(custom_type)
	  && !stricmp(custom_type, SOAP_VOID_TYPE)
	  && proc->qr_proc_ret_type)
	{
	  sql_type_t sqt;
	  ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
	  if (IS_UDT_XMLTYPE_SQT(&sqt))
	    custom_type = NULL;
	}

      if (!custom_type || (DV_STRINGP(custom_type) && 0 != stricmp(custom_type, SOAP_VOID_TYPE)))
	{
	  SES_PRINT (out,"\t\t <element minOccurs='1' maxOccurs='1' name='");
	  SOAP_PRINT (PART_NAME, out, proc, -1, "CallReturn");
	  SES_PRINT (out, "' type='");
	  if (!custom_type)
	    {
	      if (proc->qr_proc_ret_type)
		{
		  sql_type_t sqt;
		  ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
		  if (IS_COMPLEX_SQT (sqt))
		    {
		      caddr_t type_name
			  = soap_sqt_to_soap_type (&(sqt), NULL, ctx->opts, operation_name, "Response");
		      wsdl_print_q_name (out, type_name, types_set);
		      dk_free_box (type_name);
		    }
		  else
		    {
		      SES_PRINT (out, "xsd:");
		      SES_PRINT (out, dtp_to_soap_type (sqt.sqt_dtp));
		    }
		}
	      else
		SES_PRINT (out, "xsd:string");
	    }
	  else
	    wsdl_print_q_name (out, custom_type, types_set);
	  SES_PRINT (out, "' />\n");
	}
      SES_PRINT (out, "\t    </all>\n");
      SES_PRINT (out, "\t  </complexType>\n\t");
skip_out_pars:
      SES_PRINT (out, "</element>\n");
    }
  END_DO_SET ()
}

static int
soap_print_schema (dk_session_t * out, dk_set_t * proc_set, char *qpref, size_t pref_len,
    caddr_t qual, dk_set_t * ns_set, dk_set_t * types_set, int sch_elm_qual, soap_ctx_t *ctx,
    char * wsdl_ns, int dl_flag, int type_mask)
{
  int rc = 0;
  char *type;
  char * def_ns = SOAP_TYPES_SCH (ctx->opts);

  SES_PRINT (out, "\n\t<types>\n");

  DO_SET (soap_wsdl_ns_t *, elm, ns_set)
    {
      ses_sprintf (out, "\t<schema targetNamespace=\"%s\"\n\t xmlns=\"%s\"\n", elm->ns_uri, W3C_2001_TYPE_SCHEMA_XSD);
#if 0
      DO_SET (caddr_t, import, &(elm->ns_imports))
	{
	  soap_wsdl_print_ns_decl (out, ns_set, import);
	}
      END_DO_SET ();
#endif
      ses_sprintf (out, "\t xmlns:wsdl=\"%s\"", wsdl_ns ? wsdl_ns :  SOAP_WSDL_SCHEMA11);
      if (sch_elm_qual)
	SES_PRINT (out, " elementFormDefault=\"qualified\"");
      SES_PRINT (out, " >\n");

      DO_SET (caddr_t, import, &(elm->ns_imports))
	{
	  SES_PRINT (out, "\t<import namespace='");
	  SES_PRINT (out, import);
	  SES_PRINT (out, "' />\n");
	}
      END_DO_SET ();

      DO_SET (soap_wsdl_type_t *, dt_type, &(elm->ns_types))
	{
	  caddr_t *place;
	  if (dt_type->type_is_elem)
	    continue;
	  if (dt_type->type_udt)
	    {
	      soap_udt_print_schema_fragment (dt_type->type_udt, out, types_set, 4, ctx);
	      continue;
	    }
	  else if (dt_type->type_sqt.sqt_dtp == DV_ARRAY_OF_POINTER)
	    {
	      soap_print_schema_fragment (dt_type->type_name, &(dt_type->type_sqt), out, types_set, 4, ctx);
	      continue;
	    }
	  place = (caddr_t *)id_hash_get (HT_SOAP(dt_type->type_is_elem), (caddr_t)&(dt_type->type_name));
	  type = NULL;
	  if (place && *place)
	    soap_sch_serialize ((caddr_t *)((caddr_t *)(*place))[1], out, 4, &type, types_set);
	  else
	    {
	      SES_PRINT (out, "\t<!-- Can't find definition for the type: '" );
	      SES_PRINT (out, dt_type->type_name);
	      SES_PRINT (out, "' -->\n");
	    }
	}
      END_DO_SET ();
      /*XXX: only for test, delete it and remove continue above */
      DO_SET (soap_wsdl_type_t *, dt_type, &(elm->ns_types))
	{
	  caddr_t *place;
	  if (!dt_type->type_is_elem)
	    continue;
	  place = (caddr_t *)id_hash_get (HT_SOAP(dt_type->type_is_elem), (caddr_t)&(dt_type->type_name));
	  type = NULL;
	  if (place && *place)
	    soap_sch_serialize ((caddr_t *)((caddr_t *)(*place))[1], out, 4, &type, types_set);
	  else
	    {
	      SES_PRINT (out, "\t<!-- Can't find definition for the type: '" );
	      SES_PRINT (out, dt_type->type_name);
	      SES_PRINT (out, "' -->\n");
	    }
	}
      END_DO_SET ();

      if (def_ns && !strcmp (def_ns, elm->ns_uri))
	soap_print_dl_schema (out, proc_set, qpref, pref_len, qual, sch_elm_qual, ctx,
	    types_set, ns_set, elm->ns_uri, dl_flag, type_mask);


      SES_PRINT (out, "\t</schema>\n");
    }
  END_DO_SET ();


  SES_PRINT (out, "\t</types>\n");
  return rc;
}


caddr_t
soap_sdl_services (dk_session_t *out, query_t *module, const char *qual, const char *owner,
    const char * service_name, client_connection_t *cli, caddr_t url)
{
  dbe_schema_t *sc = /*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema;
  id_casemode_hash_iterator_t it;
  query_t **ptp;
  char qpref [MAX_QUAL_NAME_LEN];
  size_t pref_len;
  dk_session_t *schema_ses = strses_allocate();

  if (module)
    snprintf (qpref, sizeof (qpref), "%s.%s.%s.", qual, owner, strrchr (module->qr_proc_name, '.') + 1);
  else
    snprintf (qpref, sizeof (qpref), "%s.%s.", qual, owner);
  pref_len = strlen (qpref);

  /* the soap init section */
  SES_PRINT (out,
      "<?xml version='1.0'?>\n"
      "<serviceDescription\n"
      " name='Virtuoso");
  SES_PRINT (out, service_name);
  SES_PRINT (out,
      "'\n"
      " xmlns:dt='http://www.w3.org/2001/XMLSchema'\n"
      " xmlns:svc ='services.xml'\n"
      " xmlns:ss ='#Virtuoso");
  SES_PRINT (out, service_name);
  SES_PRINT (out,
			    "Schema'>\n"
      "\n"
      "\t<import namespace='#Virtuoso");
  SES_PRINT (out, service_name);
  SES_PRINT (out,
					   "Schema'\n"
      "\t location='#Virtuoso");
  SES_PRINT (out, service_name);
  SES_PRINT (out,
			       "Schema'/>\n"
      "\n"
      "\t<soap xmlns='urn:schemas-xmlsoap-org:soap-sdl-2000-01-25'>\n"
      "\t\t<service>\n");

  /* the schema section */
  SES_PRINT (schema_ses,
      "\t<ss:schema\n"
      "\t id='Virtuoso");
  SES_PRINT (out, service_name);
  SES_PRINT (schema_ses,
		      "Schema'\n"
      "\t targetNamespace='services.xml'\n"
      "\t xmlns:dt='http://www.w3.org/2001/XMLSchema'\n"
      "\t xmlns='http://www.w3.org/2001/XMLSchema'>\n");

  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);

  while (id_casemode_hit_next (&it, (caddr_t *) & ptp))
    {
      query_t *proc = *ptp;
      if (!proc
	  || !cli->cli_user
	  || (module && proc->qr_module != module)
	  || !sec_proc_check (proc, cli->cli_user->usr_g_id, cli->cli_user->usr_id))
	continue;
      if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	{
	  /* the soap section */
	  SES_PRINT (out, "\t\t\t<requestResponse name='");
	  SES_PRINT (out, proc->qr_proc_name + pref_len);
	  SES_PRINT (out, "'>\n\t\t\t\t<request ref='ss:");
	  SES_PRINT (out, proc->qr_proc_name + pref_len);
	  SES_PRINT (out, "'/>\n\t\t\t\t<response ref='ss:");
	  SES_PRINT (out, proc->qr_proc_name + pref_len);
	  SES_PRINT (out, "Response'/>\n\t\t\t\t<parameterorder>");

	  /* the schema section - request type */
	  SES_PRINT (schema_ses, "\t\t<element name='");
	  SES_PRINT (schema_ses, proc->qr_proc_name + pref_len);
	  if (dk_set_length (proc->qr_parms))
	    {
	      SES_PRINT (schema_ses, "'>\n\t\t\t<type>\n");
	      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
		{
		  if (ssl->ssl_type != SSL_REF_PARAMETER_OUT)
		    {
		      SES_PRINT (schema_ses, "\t\t\t\t<element name='");
		      SES_PRINT (schema_ses, ssl->ssl_name);
		      SES_PRINT (schema_ses, "' type='dt:");
		      SES_PRINT (schema_ses, dtp_to_soap_type (ssl->ssl_dtp));
		      SES_PRINT (schema_ses, "'/>\n");
		    }
		}
	      END_DO_SET ();
	      SES_PRINT (schema_ses, "\t\t\t</type>\n\t\t</element>\n");
	    }
	  else
	    SES_PRINT (schema_ses, "'/>\n");

	  /* the schema section - response  type */
	  SES_PRINT (schema_ses, "\t\t<element name='");
	  SES_PRINT (schema_ses, proc->qr_proc_name + pref_len);
	  SES_PRINT (schema_ses, "Response'>\n\t\t\t<type>\n");
	  /* parameters */
	  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	    {
	      /* the soap section */
	      SES_PRINT (out, ssl->ssl_name);
	      session_buffered_write_char (' ', out);

	      if (IS_SSL_REF_PARAMETER (ssl->ssl_type))
		{
		  /* the schema section */
		  SES_PRINT (schema_ses, "\t\t\t\t<element name='");
		  SES_PRINT (schema_ses, ssl->ssl_name);
		  SES_PRINT (schema_ses, "' type='dt:");
		  SES_PRINT (schema_ses, dtp_to_soap_type (ssl->ssl_dtp));
		  SES_PRINT (schema_ses, "'/>\n");
		}
	    }
	  END_DO_SET ();

	  /* the soap section */
	  SES_PRINT (out, "CallReturn</parameterorder>\n\t\t\t</requestResponse>\n");

	  /* the schema section */
	  SES_PRINT (schema_ses, "\t\t\t\t<element name='CallReturn' type='dt:");
	  if (proc->qr_proc_ret_type)
	    {
	      ptrlong *rtype = (ptrlong *) proc->qr_proc_ret_type;
	      SES_PRINT (schema_ses, dtp_to_soap_type ((dtp_t) rtype[0]));
	    }
	  else
	      SES_PRINT (schema_ses, "string");
	  SES_PRINT (schema_ses, "'/>\n\t\t\t</type>\n\t\t</element>\n");

	}
    }
  /* soap section */
  SES_PRINT (out,
      "\t\t\t<addresses>\n\t\t\t\t<location url='");
  if (strnicmp (url, "http", 4))
    SES_PRINT (out, "http:");
  SES_PRINT (out, url);
  SES_PRINT (out,
      "' />\n\t\t\t</addresses>\n"
      "\t\t</service>\n"
      "\t</soap>\n"
      );

  /* schema section */
  strses_write_out (schema_ses, out);
  SES_PRINT (out,
      "\t</ss:schema>\n"
      "</serviceDescription>");
  return NULL;
}


caddr_t
ws_soap_sdl_services (ws_connection_t *ws)
{
  caddr_t url = ws_soap_get_url (ws, 0);
  caddr_t res = soap_sdl_services (ws->ws_strses, NULL, ws_usr_qual (ws, 1), WS_SOAP_NAME (ws),
      SERVICE_NAME (ws), ws->ws_cli, url);
  dk_free_box (url);
  ws->ws_header = box_dv_short_string ("Content-Type: text/xml\r\n");
  return res;
}


static caddr_t
bif_soap_sdl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t module = bif_string_arg (qst, args, 0, "soap_sdl");
  char service_name[MAX_QUAL_NAME_LEN];
  caddr_t url = NULL;
  query_instance_t *qi = (query_instance_t *)qst;
  dbe_schema_t *sc = isp_schema (qi->qi_space);
  dk_session_t *out;
  caddr_t name = NULL;
  query_t *mod = NULL;
  char mq[MAX_NAME_LEN], mo[MAX_NAME_LEN], mn[MAX_NAME_LEN * 2 + 2];
  caddr_t res;
  size_t inx, len;

  name = sch_full_module_name (sc, module, cli_qual (qi->qi_client),
      CLI_OWNER  (qi->qi_client));
  if (name)
    mod = sch_module_def (sc, name);
  if (!mod)
    sqlr_new_error ("37000", "SR315", "Invalid module name");
  strcpy_ck (service_name, mod->qr_proc_name);
  len = strlen (service_name);
  for (inx = 0; inx < len; inx++)
    {
      if (!isalnum (service_name[inx]))
	service_name[inx] = '_';
      else
	service_name[inx] = toupper (service_name[inx]);
    }
  sch_split_name (NULL, mod->qr_proc_name, mq, mo, mn);
  if (BOX_ELEMENTS (args) > 1)
    url = bif_string_arg (qst, args, 1, "soap_sdl");
  else if (qi->qi_client->cli_ws)
    url = ws_soap_get_url (qi->qi_client->cli_ws, 0);
  else
    sqlr_new_error ("37000", "SR316", "No URL specified & soap_sdl called outside HTTP context");

  out = strses_allocate ();
  soap_sdl_services (out, mod, mq, mo, service_name, qi->qi_client, url);
  res = strses_string (out);
  strses_free (out);
  return res;
}

static void
wsdl_http_oper (dk_session_t * out, char * oper, query_t * proc)
{
  char * enc = proc->qr_proc_alt_ret_type;
  SES_PRINT (out, "\t\t<operation name=\"");
  SES_PRINT (out, oper);
  SES_PRINT (out, "\">\n");
  SES_PRINT (out,   "\t\t\t<http:operation location=\"/");
  SES_PRINT (out, oper);
  SES_PRINT (out, "\"/>\n"
      "\t\t\t<input>\n"
      "\t\t\t\t<http:urlEncoded/>\n"
      "\t\t\t</input>\n"
      "\t\t\t<output>\n"
      "\t\t\t\t<mime:content type=\"");
  SES_PRINT (out, enc ? enc : "application/octet-stream");
  SES_PRINT (out, "\"/>\n"
      "\t\t\t</output>\n"
      "\t\t</operation>\n");
}

static void
soap_wsdl_print_ext_messages (query_t * proc, char * operation_name,
    dk_session_t * out, long literal_1, dk_set_t * types_set, int ext)
{
  int ix = 0;
  char * custom_type = NULL;

  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
    {
      if (!IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	  IS_SOAP_MSG_SET (proc->qr_parm_place[ix], ext) &&
	  (IS_SSL_REF_PARAMETER (ssl->ssl_type) || ssl->ssl_type == SSL_PARAMETER))
	{
	  const char * use = SOAP_OPT (USE, proc, ix, NULL);
	  int literal;

	  SOAP_USE (use, literal, literal_1);
#if 0
	  if (!found)
	    SES_PRINT (out, "\t<!-- extension messages -->\n");
#endif
	  custom_type = proc->qr_parm_alt_types[ix];
	  if (literal && !custom_type)
	    {
	      SES_PRINT (out, "<!-- an definition of Doc/Literal encoded message has no data type -->");
	      continue;
	    }
	  SES_PRINT (out, "\t<message name=\"");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, ssl->ssl_name);
	  SES_PRINT (out, "\">\n\t\t<part name=\"");
	  SOAP_PRINT (PART_NAME, out, proc, ix, ssl->ssl_name)
	  if (!literal)
	    SES_PRINT (out, "\" type=\"");
	  else
	    SES_PRINT (out, "\" element=\"");
	  if (!custom_type)
	    {
	      SES_PRINT (out, "xsd:");
	      SES_PRINT (out, dtp_to_soap_type (ssl->ssl_dtp));
	    }
	  else
	    wsdl_print_q_name (out, custom_type, types_set);
	  SES_PRINT (out, "\" />\n");
	  SES_PRINT (out, "\t</message>\n");
	}
      ix++;
    }
  END_DO_SET ();
}

static void
soap_wsdl_print_extensions (query_t * proc, char * operation_name, dk_session_t * out,
    char * header_ns, int binding_1, int ext, char what)
{
  int ix = 0, found = 0;
  const char * szExt = (ext == SOAP_MSG_HEADER ? "header" : "fault");

  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
    {
      if (!IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	  IS_SOAP_MSG_SET(proc->qr_parm_place[ix], ext) &&
	   (ssl->ssl_type == SSL_REF_PARAMETER || ssl->ssl_type == what)
	  )
	{
	  const char * use = SOAP_OPT (USE, proc, ix, NULL);
	  int binding;

	  SOAP_USE (use, binding, binding_1);

	  if (ext == SOAP_MSG_FAULT)
	    {
	      SES_PRINT (out, "\t\t\t<fault name=\"");
              SES_PRINT (out, operation_name);
	      SES_PRINT (out, ssl->ssl_name);
	      SES_PRINT (out, "\">\n");
	    }

	  SES_PRINT (out, "\t\t\t\t<soap:");
	  SES_PRINT (out, szExt);
	  if (ext == SOAP_MSG_FAULT)
	    {
	      SES_PRINT (out, " name=\"");
              SES_PRINT (out, operation_name);
	      SES_PRINT (out, ssl->ssl_name);
	      SES_PRINT (out, "\"");
	    }
	  SES_PRINT (out, " use=\"");
	  SES_PRINT (out, binding ? "literal" : "encoded");
	  SES_PRINT (out, "\" message=\"tns:");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, ssl->ssl_name);
	  SES_PRINT (out, "\" part=\"");
	  SOAP_PRINT(PART_NAME, out, proc, ix, ssl->ssl_name)
	  if (header_ns && !binding)
	    {
	      SES_PRINT (out, "\" namespace=\"");
	      if (what == SSL_PARAMETER)
		SOAP_PRINT (REQ_NS, out, proc, ix, header_ns)
	      else
		SOAP_PRINT (RESP_NS, out, proc, ix, header_ns)
	    }
	  if (!binding)
	    SES_PRINT (out,
		"\" encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/");
	  SES_PRINT (out, "\" />\n");
	  if (ext == SOAP_MSG_FAULT)
	    SES_PRINT (out, "\t\t\t</fault>\n");
	  found ++;
	}
      ix++;
    }
  END_DO_SET();
}

static void
soap_wsdl_print_faults (query_t * proc, char * operation_name, dk_session_t * out)
{
  int ix = 0;

  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
    {
      if (!IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	  IS_SOAP_MSG_FAULT (proc->qr_parm_place[ix]) &&
	  IS_SSL_REF_PARAMETER (ssl->ssl_type))
	{
	  SES_PRINT (out, "\t\t\t<fault name=\"");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, ssl->ssl_name);
	  SES_PRINT (out, "\" message=\"tns:");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, ssl->ssl_name);
	  SES_PRINT (out, "\" />\n");
	}
      ix++;
    }
  END_DO_SET();
}


caddr_t
soap_wsdl_services (dk_session_t *out, query_t *module, caddr_t qual, const char * owner, caddr_t module_name,
    caddr_t service_name, caddr_t service_schema_name, client_connection_t *cli, caddr_t url, caddr_t * opts,
    query_instance_t *qi)
{
  char qpref [MAX_QUAL_NAME_LEN], *prt_action, *element_form_default;
  int ix, mime_enabled = 0, dime_enabled = 0, https = 0, async, make_plink;
  size_t pref_len;
  char * operation_name, q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  char *header_ns = SOAP_HEADER_NAMESPACE(opts);
  long literal, docs = 0, rpcs = 0, inx = 0, wrapped, sch_elm_qual = 0;
  dk_set_t ns_set = NULL, types_set = NULL;
  char * def_ns = SOAP_TYPES_SCH (opts);
  soap_ctx_t ctx;
  dk_set_t proc_set = NULL;

  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.opts = opts;
  ctx.qst = (caddr_t *)qi;

  if (module_name)
    snprintf (qpref, sizeof (qpref), "%s.%s.%s.", qual, owner, module_name);
  else
    snprintf (qpref, sizeof (qpref), "%s.%s.", qual, owner);
  pref_len = strlen (qpref);

  proc_set = get_granted_qrs (cli, module, qpref, pref_len);

  element_form_default = SOAP_SCH_ELEM_QUAL (opts);
  if (element_form_default && !strcmp (element_form_default, "qualified"))
    sch_elm_qual = 1;
  prt_action = SOAP_PRINT_ACTION (opts);
  dime_enabled = soap_get_opt_flag (opts, SOAP_DIME_ENC);
  mime_enabled = soap_get_opt_flag (opts, SOAP_MIME_ENC);
  ctx.def_enc = SOAP_DEF_ENC(opts);
  make_plink = soap_get_opt_flag (opts, SOAP_PLINK);

  /* collect XSDs; qr_recompile inside if needed */
  soap_wsdl_find_schemas (&ns_set, &types_set, &proc_set, &ctx, qpref, pref_len, qual);
  ns_set = dk_set_nreverse (ns_set);

  if (ctx.def_enc && !soap_wsdl_ns_exists (&ns_set, def_ns))
    {
      soap_wsdl_ns_decl (&ns_set, def_ns, NULL);
    }

  /* header */
  SES_PRINT (out,
      "<?xml version=\"1.0\"?>\n"
      "<definitions\n"
      " xmlns:xsd=\""     W3C_2001_TYPE_SCHEMA_XSD  "\"\n"
      " xmlns:http=\""    SOAP_WSDL_SCHEMA11 "http/\"\n"
      " xmlns:mime=\""    SOAP_WSDL_SCHEMA11 "mime/\" \n"
      " xmlns:soap=\""    SOAP_WSDL_SCHEMA11 "soap/\"\n"
      "	xmlns:dime=\""    SOAP_DIME_SCHEMA "wsdl/\"\n"
      "	xmlns:wsdl=\""    SOAP_WSDL_SCHEMA11 "\"\n"
      " xmlns:soapenc=\"" SOAP_ENC_SCHEMA11 "\" \n"
      " xmlns:content=\"" SOAP_CONTENT_TYPE_200204 "\" \n"
      " xmlns:ref=\"" 	  SOAP_REF_SCH_200204  "\" \n"
      " xmlns:plt=\"" 	  BPEL4WS_PL_URI "\" \n"
      );

  soap_wsdl_print_ns_decl (out, &ns_set, NULL);

  if (ctx.def_enc)
    {
      SES_PRINT (out, " xmlns:dl=\"");
      SES_PRINT (out, SOAP_TYPES_SCH (opts));
      SES_PRINT (out, "\" \n");
    }

  SES_PRINT (out," xmlns:tns=\"");
  if (strnicmp (url, "http", 4))
    SES_PRINT (out, "http:");
  SES_PRINT (out, url);
  SES_PRINT (out, "/services.wsdl\"\n");
  SES_PRINT (out, " targetNamespace=\"");
  if (strnicmp (url, "http", 4))
    SES_PRINT (out, "http:");
  SES_PRINT (out, url);
  SES_PRINT (out, "/services.wsdl\"\n" " name=\"");
  if (service_name && service_name[0])
    SES_PRINT (out, service_name);
  else
    SES_PRINT (out, "Virtuoso");
  SES_PRINT (out, "\" xmlns=\"" SOAP_WSDL_SCHEMA11 "\">\n");

  soap_print_schema (out, &proc_set, qpref, pref_len, qual, &ns_set, &types_set, sch_elm_qual, &ctx, NULL,
      ctx.def_enc, (SOAP_MSG_LITERAL|SOAP_MSG_LITERALW|SOAP_MSG_HTTP));

  /* messages */
  DO_SET (query_t *, proc, &proc_set)
    {
      char * custom_type = NULL;

      if (qi && qi->qi_query && qi->qi_query == proc)
	continue;
      if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	operation_name = proc->qr_proc_name + pref_len;
      else
	{
          sch_split_name (qual, proc->qr_proc_name, q, o, n);
	  operation_name = n;
	}
      /* input message */
      SES_PRINT (out, "\t<message name=\"");
      SES_PRINT (out, operation_name);
      SES_PRINT (out, "Request\">\n");
      literal = (SOAP_MSG_LITERAL & proc->qr_proc_place);
      wrapped = (SOAP_MSG_LITERALW & proc->qr_proc_place);
      if (0 != (SOAP_MSG_HTTP & proc->qr_proc_place))
	https++;
      else if (literal)
	docs++;
      else if (ctx.def_enc)
	{
	  SES_PRINT (out, "\t\t<part element=\"dl:");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, "\" name=\"parameters\" />\n");
	  docs++;
	  goto input_message_end;
	}
      else
        rpcs++;
      ix = 0;
      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	{
	  if (ssl->ssl_type != SSL_REF_PARAMETER_OUT &&
	      !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	      !IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
	    {
	      caddr_t udt_custom_type = NULL;
	      custom_type = proc->qr_parm_alt_types[ix];
	      if (!custom_type && IS_COMPLEX_SQT (ssl->ssl_sqt))
		{
		  udt_custom_type = custom_type =
		      soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx.opts, operation_name, ssl->ssl_name);
		}

	      if (literal && !custom_type)
		SES_PRINT (out, "<!-- an input parameter of Doc/Literal encoded operation has no data type -->");
	      else
		{
		  SES_PRINT (out, "\t\t<part ");
		  if (!literal)
		    {
		      SES_PRINT (out, "name=\"");
		      SES_PRINT (out, ssl->ssl_name);
		      SES_PRINT (out, "\" type=\"");
		      if (!custom_type)
			{
			  SES_PRINT (out, "xsd:");
			  SES_PRINT (out, dtp_to_soap_type (ssl->ssl_dtp));
			}
		      else
			wsdl_print_q_name (out, custom_type, &types_set);
		    }
		  else
		    {
		      SES_PRINT (out, "element=\"");
		      wsdl_print_q_name (out, custom_type, &types_set);
		      SES_PRINT (out, "\" name=\"");
		      SES_PRINT (out, wrapped ? "parameters" : ssl->ssl_name);
		    }
		  SES_PRINT (out, "\" />\n");
		}
	      dk_free_box (udt_custom_type);
	    }
	  ix++;
	}
      END_DO_SET ();
input_message_end:
      SES_PRINT (out, "\t</message>\n");

      /* output message */
      SES_PRINT (out, "\t<message name=\"");
      SES_PRINT (out, operation_name);
      SES_PRINT (out, "Response\">\n");
      if (ctx.def_enc)
	{
	  SES_PRINT (out, "\t\t<part element=\"dl:");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, "Response\" name=\"parameters\" />\n");
	  goto output_message_end;
	}
      ix = 0;
      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	{
	  if (IS_SSL_REF_PARAMETER (ssl->ssl_type) &&
	      !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
	      !IS_SOAP_MSG_SPECIAL (proc->qr_parm_place[ix]))
	    {
	      caddr_t udt_custom_type = NULL;
	      custom_type = proc->qr_parm_alt_types[ix];
	      if (!custom_type && IS_COMPLEX_SQT (ssl->ssl_sqt))
		{
		  udt_custom_type = custom_type =
		      soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx.opts, operation_name, ssl->ssl_name);
		}
	      if (literal && !custom_type)
		SES_PRINT (out, "<!-- an output parameter of Doc/Literal encoded operation has no data type -->");
	      else
		{
		  SES_PRINT (out, "\t\t<part ");
		  if (!literal)
		    {
		      SES_PRINT (out, "name=\"");
		      SES_PRINT (out, ssl->ssl_name);
		      SES_PRINT (out, "\" type=\"");
		      if (!custom_type)
			{
			  SES_PRINT (out, "xsd:");
			  SES_PRINT (out, dtp_to_soap_type (ssl->ssl_dtp));
			}
		      else
			wsdl_print_q_name (out, custom_type, &types_set);
		    }
		  else
		    {
		      SES_PRINT (out, "element=\"");
		      wsdl_print_q_name (out, custom_type, &types_set);
		      SES_PRINT (out, "\" name=\"");
		      SES_PRINT (out, wrapped ? "parameters" : ssl->ssl_name);
		    }
		  SES_PRINT (out, "\" />\n");
		}
	      dk_free_box (udt_custom_type);
	    }
	  ix++;
	}
      END_DO_SET ();
      custom_type = proc->qr_proc_alt_ret_type;
      if (proc->qr_proc_place & SOAP_MSG_HTTP)
	custom_type = NULL;

      if (custom_type && DV_STRINGP(custom_type)
	  && !stricmp(custom_type, SOAP_VOID_TYPE)
	  && proc->qr_proc_ret_type)
	{
	  sql_type_t sqt;
	  ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
	  if (IS_UDT_XMLTYPE_SQT(&sqt))
	    custom_type = NULL;
	}

      /* if return is not a void one */
      if (!custom_type || (DV_STRINGP(custom_type) && 0 != stricmp(custom_type, SOAP_VOID_TYPE)))
	{
	  if (!literal)
	    {
	      SES_PRINT (out, "\t\t<part name=\"");
	      SOAP_PRINT (PART_NAME, out, proc, -1, "CallReturn");
	      SES_PRINT (out, "\" type=\"");

	      if (custom_type)
		wsdl_print_q_name (out, custom_type, &types_set);
	      else if (proc->qr_proc_ret_type)
		{
		  sql_type_t sqt;
		  ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
		  if (IS_COMPLEX_SQT (sqt))
		    {
		      caddr_t type_name =
			  soap_sqt_to_soap_type (&(sqt), NULL, ctx.opts, operation_name, "Response");
		      wsdl_print_q_name (out, type_name, &types_set);
		      dk_free_box (type_name);
		    }
		  else
		    {
		      SES_PRINT (out, "xsd:");
		      SES_PRINT (out, dtp_to_soap_type (sqt.sqt_dtp));
		    }
		}
	      else
		SES_PRINT (out, "xsd:string");
	      SES_PRINT (out, "\" />\n");
	    }
	  else
	    {
	      if (literal && !custom_type)
		SES_PRINT (out, "<!-- return value of Doc/Literal encoded operation has no data type -->");
	      else
		{
		  SES_PRINT (out, "\t\t<part element=\"");
		  wsdl_print_q_name (out, custom_type, &types_set);
		  SES_PRINT (out, wrapped ? "\" name=\"parameters" : "\" name=\"");
		  if (!wrapped)
		    SOAP_PRINT (PART_NAME, out, proc, -1, "CallReturn");
		  SES_PRINT (out, "\" />\n");
		}
	    }
	}
output_message_end:
      SES_PRINT (out, "\t</message>\n");

      /* messages in header */
      soap_wsdl_print_ext_messages (proc, operation_name, out, literal, &types_set, SOAP_MSG_HEADER);
      /* fault messages */
      soap_wsdl_print_ext_messages (proc, operation_name, out, literal, &types_set, SOAP_MSG_FAULT);
    }
  END_DO_SET ()


  /* portType */
  for (inx = 0; inx < MAX_SOAP_PORTS; inx++)
    {
      int bt = soap_ports[inx];
      if (!bt && !rpcs)
	continue;
      else if (bt == SOAP_MSG_LITERAL && !docs)
	continue;
      else if (bt == SOAP_MSG_HTTP && !https)
	continue;

      SES_PRINT (out,
	  "\t<portType name=\"");
      SES_PRINT (out, service_name);

      if (bt == SOAP_MSG_LITERAL)
	SES_PRINT (out, "DocLiteral");
      else if (bt == SOAP_MSG_HTTP)
	SES_PRINT (out, "HttpGet");

      SES_PRINT (out,
	  "PortType\">\n");

      DO_SET (query_t *, proc, &proc_set)
	{
	  if (qi && qi->qi_query && qi->qi_query == proc)
	    continue;

	  if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	    operation_name = proc->qr_proc_name + pref_len;
	  else
	    {
	      sch_split_name (qual, proc->qr_proc_name, q, o, n);
	      operation_name = n;
	    }
	  literal = (SOAP_MSG_LITERAL & (proc->qr_proc_place | ctx.def_enc));
	  wrapped = (SOAP_MSG_LITERALW & (proc->qr_proc_place | ctx.def_enc));
	  async = (int) unbox ((box_t) SOAP_OPT (ONEWAY, proc, -1, 0));

	  if (0 != (proc->qr_proc_place & SOAP_MSG_HTTP))
	    {
	      if (bt != SOAP_MSG_HTTP)
		continue;
	    }
	  else if ((literal & SOAP_MSG_LITERAL) != bt) /* ensure Rpc/DocLit*/
	    continue;
	  else if (!literal && bt)
	    continue;

	  SES_PRINT (out,
	      "\t\t<operation name=\"");
	  SES_PRINT (out, operation_name);
	  if (!wrapped && proc->qr_parms)
	    {
	      int nxt_parm = 0;
	      ix = 0;
	      DO_SET (state_slot_t *, ssl, &proc->qr_parms)
		{
		  if (!IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
		      !IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
		    {
		      if (!nxt_parm)
			SES_PRINT (out, "\" parameterOrder=\"");
		      else
			SES_PRINT (out, " ");
		      SES_PRINT (out, ssl->ssl_name);
		      nxt_parm++;
		    }
		  ix++;
		}
	      END_DO_SET ();
	    }
	  SES_PRINT (out, "\">\n"
	      "\t\t\t<input message=\"tns:");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, "Request\"");
	  if (literal)
	    {
	      SES_PRINT (out, " name=\"");
	      SES_PRINT (out, operation_name);
	      SES_PRINT (out, "Request\"");
	    }
	  SES_PRINT (out, " />\n");
	  if (!async)
	    {
	      SES_PRINT (out, "\t\t\t<output message=\"tns:");

	      SES_PRINT (out, operation_name);
	      SES_PRINT (out, "Response\"");
	      if (literal)
		{
		  SES_PRINT (out, " name=\"");
		  SES_PRINT (out, operation_name);
		  SES_PRINT (out, "Response\"");
		}
	      SES_PRINT (out, " />\n");
	    }
	  /* fault messages */
	  soap_wsdl_print_faults (proc, operation_name, out);
	  SES_PRINT (out, "\t\t</operation>\n");
	}
      END_DO_SET ()
      SES_PRINT (out, "\t</portType>\n");
    }

  /* bindings */

  for (inx = 0; inx < MAX_SOAP_PORTS; inx++)
    {
      int bt = soap_ports[inx];
      if (!bt && !rpcs)
	continue;
      else if (bt == SOAP_MSG_LITERAL && !docs)
	continue;
      else if (bt == SOAP_MSG_HTTP && !https)
	continue;

      SES_PRINT (out,
	  "\t<binding name=\"");
      SES_PRINT (out, service_name);

      if (bt == SOAP_MSG_LITERAL)
	SES_PRINT (out, "DocLiteral");
      else if (bt == SOAP_MSG_HTTP)
	SES_PRINT (out, "HttpGet");

      SES_PRINT (out,
	  "Binding\" type=\"tns:");
      SES_PRINT (out, service_name);

      if (bt == SOAP_MSG_LITERAL)
	SES_PRINT (out, "DocLiteral");
      else if (bt == SOAP_MSG_HTTP)
	SES_PRINT (out, "HttpGet");

      SES_PRINT (out, "PortType\">\n");

      if (bt != SOAP_MSG_HTTP)
	{
	  SES_PRINT (out, "\t\t<soap:binding style=\"");
	  SES_PRINT (out, bt ? "document" : "rpc");
	  SES_PRINT (out, "\" transport=\"http://schemas.xmlsoap.org/soap/http\" />\n");
	}
      else
        SES_PRINT (out, "\t\t<http:binding verb='GET' />\n");

      DO_SET (query_t *, proc, &proc_set)
	{
	  caddr_t desc = NULL;
	  if (qi && qi->qi_query && qi->qi_query == proc)
	    continue;

	  if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	    operation_name = proc->qr_proc_name + pref_len;
	  else
	    {
	      sch_split_name (qual, proc->qr_proc_name, q, o, n);
	      operation_name = n;
	    }

	  literal = (proc->qr_proc_place | ctx.def_enc);
	  async = (int) unbox ((box_t) SOAP_OPT (ONEWAY, proc, -1, 0));


	  if (0 != (literal & SOAP_MSG_HTTP)) /* After that test, all types are SOAP */
	    {
	      if (bt == SOAP_MSG_HTTP)
		wsdl_http_oper (out, operation_name, proc);
	      continue;
	    }

	  if ((literal & SOAP_MSG_LITERAL) != bt) /* ensure Rpc/DocLit*/
	    continue;

	  SES_PRINT (out,
	      "\t\t<operation name=\"");
	  SES_PRINT (out, operation_name);
	  SES_PRINT (out, "\">\n");

          if (proc->qr_text && NULL != (desc = regexp_match_01 ("--##.*", proc->qr_text, 0)))
	    {
	      char * msg = desc + 4;
	      SES_PRINT (out, "\t\t\t<documentation>");
	      dks_esc_write (out, msg, strlen (msg),
		  CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
	      SES_PRINT (out, "</documentation>\n");
	      dk_free_tree (desc);
	    }

	   SES_PRINT (out, "\t\t\t<soap:operation soapAction=\"");
	    {
	      const char * soapAction = SOAP_OPT (ACTION, proc, -1, NULL);

	      if (soapAction)
		SES_PRINT (out, soapAction);
	      else
		{
		  if ((prt_action && prt_action[0] != 'e' && prt_action[0] != 'E' &&
			prt_action[0] != 'o' && prt_action[0] != 'O') || !prt_action)
		    SES_PRINT (out, service_schema_name);
		  if ((prt_action && ( prt_action[0] == 'y' || prt_action[0] == 'Y' ||
			  prt_action[0] == 'o' || prt_action[0] == 'O')) || !prt_action)
		    {
		      SES_PRINT (out,
			  "#");
		      SES_PRINT (out, operation_name);
		    }
		}
	    }

	  if (bt)
	    SES_PRINT (out, "\" style=\"document");
	  SES_PRINT (out,
	      "\" />\n"
	      "\t\t\t<input");
	  if (bt)
	    {
	      SES_PRINT (out, " name=\"");
	      SES_PRINT (out, operation_name);
	      SES_PRINT (out, "Request\"");
	    }
	  SES_PRINT(out, ">\n");

          if (dime_enabled || (proc->qr_proc_place & SOAP_MSG_IN))
            SES_PRINT (out, "\t\t\t\t<dime:message layout='" SOAP_DIME_SCHEMA
	       	"closed-layout' wsdl:required='true'/>\n");

          if (mime_enabled || (proc->qr_proc_place & SOAP_MMSG_IN))
            SES_PRINT (out, "\n\t\t\t\t<mime:multipartRelated>\n\t\t\t\t<mime:part>");

          SES_PRINT(out, "\t\t\t\t<soap:body use=\"");
	  SES_PRINT (out, bt ? "literal" :  "encoded");
	  if (strlen (service_schema_name) && !bt)
	    {
	      SES_PRINT (out, "\" namespace=\"");
	      SOAP_PRINT (REQ_NS, out, proc, -1, service_schema_name);
	    }
	  if (!bt)
	    SES_PRINT (out, "\" encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/");
	  SES_PRINT (out, "\" />\n");
	  /* the input header messages */
	  soap_wsdl_print_extensions (proc, operation_name, out, header_ns, bt,
	      SOAP_MSG_HEADER, SSL_PARAMETER);

          if (mime_enabled || (proc->qr_proc_place & SOAP_MMSG_IN))
            SES_PRINT (out, "\n\t\t\t\t</mime:part>\n\t\t\t\t<mime:part>\n\t\t\t\t<mime:content type=\"application/octetstream\" />\n\t\t\t\t</mime:part>\n\t\t\t\t</mime:multipartRelated>");

	  SES_PRINT (out, "\t\t\t</input>\n");
	  if (!async)
	    {
	      SES_PRINT (out, "\t\t\t<output");
	      if (bt)
		{
		  SES_PRINT (out, " name=\"");
		  SES_PRINT (out, operation_name);
		  SES_PRINT (out, "Response\"");
		}
	      SES_PRINT (out, ">\n");

	      if (dime_enabled || (proc->qr_proc_place & SOAP_MSG_OUT))
		SES_PRINT (out, "\t\t\t\t<dime:message layout='" SOAP_DIME_SCHEMA
		    "closed-layout' wsdl:required='true'/>\n");

	      if (mime_enabled || (proc->qr_proc_place & SOAP_MMSG_OUT))
		SES_PRINT (out, "\n\t\t\t\t<mime:multipartRelated>\n\t\t\t\t<mime:part>");

	      SES_PRINT (out, "\t\t\t\t<soap:body use=\"");
	      SES_PRINT (out, bt ? "literal" :  "encoded");
	      if (strlen (service_schema_name) && !bt)
		{
		  SES_PRINT (out, "\" namespace=\"");
		  SOAP_PRINT (RESP_NS, out, proc, -1, service_schema_name);
		}
	      if (!bt)
		SES_PRINT (out, "\" encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/");
	      SES_PRINT (out, "\" />\n");

	      /* the output extension messages */
	      soap_wsdl_print_extensions (proc, operation_name, out, header_ns, bt,
		  SOAP_MSG_HEADER, SSL_REF_PARAMETER_OUT);

	      if (mime_enabled || (proc->qr_proc_place & SOAP_MMSG_OUT))
		SES_PRINT (out, "\n\t\t\t\t</mime:part>\n\t\t\t\t<mime:part>\n\t\t\t\t<mime:content type=\"application/octetstream\" />\n\t\t\t\t</mime:part>\n\t\t\t\t</mime:multipartRelated>");

	      SES_PRINT (out, "\t\t\t</output>\n");
	    }

	  soap_wsdl_print_extensions (proc, operation_name, out, SOAP_FAULT_NAMESPACE(opts), bt,
	      SOAP_MSG_FAULT, SSL_REF_PARAMETER_OUT);

	  SES_PRINT (out, "\t\t</operation>\n");
	}
      END_DO_SET ()
      SES_PRINT (out,
	  "\t</binding>\n");
    }

  /* definitions services */
  SES_PRINT (out, "\t<service name=\"");
  if (service_name && service_name[0])
    SES_PRINT (out, service_name);
  else
    SES_PRINT (out, "Virtuoso");
  SES_PRINT (out,
      "\">\n"
      "\t\t<documentation>Virtuoso SOAP services</documentation>\n");
  for (inx = 0; inx < MAX_SOAP_PORTS; inx++)
    {
      int bt = soap_ports[inx];
      if (!bt && !rpcs)
	continue;
      else if (bt == SOAP_MSG_LITERAL && !docs)
	continue;
      else if (bt == SOAP_MSG_HTTP && !https)
	continue;

      SES_PRINT (out, "\t\t<port name=\"");
      SES_PRINT (out, service_name);

      if (bt == SOAP_MSG_LITERAL)
	SES_PRINT (out, "DocLiteral");
      else if (bt == SOAP_MSG_HTTP)
	SES_PRINT (out, "HttpGet");

      SES_PRINT (out,
	  "Port\" binding=\"tns:");
      SES_PRINT (out, service_name);

      if (bt == SOAP_MSG_LITERAL)
	SES_PRINT (out, "DocLiteral");
      else if (bt == SOAP_MSG_HTTP)
	SES_PRINT (out, "HttpGet");

      SES_PRINT (out, "Binding\">\n");

      if (bt != SOAP_MSG_HTTP)
	{
	  SES_PRINT (out, "\t\t\t<soap:address location=\"");
	  if (strnicmp (url, "http", 4))
	    SES_PRINT (out, "http:");
	  SES_PRINT (out, url);
	  SES_PRINT (out,
	      "\" />\n");
	}
      else
	{
	  SES_PRINT (out, "\t\t\t<http:address location=\"");
	  if (strnicmp (url, "http", 4))
	    SES_PRINT (out, "http:");
	  SES_PRINT (out, url);
	  SES_PRINT (out,
	      "/Http\" />\n");
	}

      SES_PRINT(out, "\t\t</port>\n");
    }
  SES_PRINT (out, "\t</service>\n");

  if (make_plink)
    {
      SES_PRINT (out, "\t<plt:partnerLinkType name='"); SES_PRINT (out, service_name);  SES_PRINT (out, "'>\n");
      SES_PRINT (out, "\t\t<plt:role name='"); SES_PRINT (out, service_name); SES_PRINT (out, "Provider'>\n");
      if (rpcs && docs)
	SES_PRINT (out, "\t\t\t<!-- Warning : the WSDL contains more than one port type -->\n");
      SES_PRINT (out, "\t\t\t<plt:portType name='tns:");
      SES_PRINT (out, service_name);
      if (docs && !rpcs)
	SES_PRINT (out, "DocLiteral");
      SES_PRINT (out, "PortType'/>\n");
      SES_PRINT (out, "\t\t</plt:role>\n");
      SES_PRINT (out, "\t</plt:partnerLinkType>\n");
    }

  SES_PRINT (out, "</definitions>\n");

  soap_wsdl_schema_free (&ns_set, &types_set);
  dk_set_free (proc_set);

  return NULL;
}

static void
soap_wsdl20_rpc_sig (dk_session_t *out, query_t *proc)
{
  int ix = 0;
  caddr_t custom_type;
  sql_type_t sqt;
  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
    {
      if (IS_SOAP_SERVICE_PARAM(ssl->ssl_name) || IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
	continue;
      SES_PRINT (out, ssl->ssl_name);
      switch (ssl->ssl_type)
	{
          case SSL_REF_PARAMETER_OUT:
	      SES_PRINT (out, " #out ");
	      break;
          case SSL_REF_PARAMETER:
	      SES_PRINT (out, " #in-out ");
	      break;
	  default:
	      SES_PRINT (out, " #in ");
	}
      ix++;
    }
  END_DO_SET ();
  custom_type = proc->qr_proc_alt_ret_type;
  if (proc->qr_proc_place & SOAP_MSG_HTTP)
    custom_type = NULL;

  if (custom_type)
    {
      ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
      if (IS_UDT_XMLTYPE_SQT(&sqt))
	custom_type = NULL;
    }

  /* if return is not a void one */
  if (!custom_type || (DV_STRINGP(custom_type) && 0 != stricmp(custom_type, SOAP_VOID_TYPE)))
    {
      SOAP_PRINT (PART_NAME, out, proc, -1, "CallReturn");
      SES_PRINT (out, " #return");
    }
}

caddr_t
soap_wsdl20_services (dk_session_t *out, query_t *module, caddr_t qual, const char * owner, caddr_t module_name,
    caddr_t service_name, caddr_t service_schema_name, client_connection_t *cli, caddr_t url1, caddr_t * opts,
    query_instance_t *qi)
{
  char qpref [MAX_QUAL_NAME_LEN], *prt_action, *element_form_default;
  int inx, ix, mime_enabled = 0, dime_enabled = 0, async, make_plink;
  size_t pref_len;
  char * operation_name, q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  long literal, docs = 0, sch_elm_qual = 0;
  dk_set_t ns_set = NULL, types_set = NULL;
  char * def_ns = SOAP_TYPES_SCH (opts);
  soap_ctx_t ctx;
  /* positions in the tmp_set array */
#define SOAP_INTERFACE 0
#define HTTP_INTERFACE 1
  dk_set_t proc_set = NULL, http_set = NULL, *tmp_set[2];
  caddr_t desc;
  char * svc_name = service_name && service_name[0] ? service_name : "Virtuoso";
  char url[PAGE_SZ];

  tmp_set[0] = &proc_set;
  tmp_set[1] = &http_set;
  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.opts = opts;
  ctx.qst = (caddr_t *)qi;

  if (module_name)
    snprintf (qpref, sizeof (qpref), "%s.%s.%s.", qual, owner, module_name);
  else
    snprintf (qpref, sizeof (qpref), "%s.%s.", qual, owner);
  pref_len = strlen (qpref);

  proc_set = get_granted_qrs (cli, module, qpref, pref_len);

  element_form_default = SOAP_SCH_ELEM_QUAL (opts);
  if (element_form_default && !strcmp (element_form_default, "qualified"))
    sch_elm_qual = 1;
  prt_action = SOAP_PRINT_ACTION (opts);
  dime_enabled = soap_get_opt_flag (opts, SOAP_DIME_ENC);
  mime_enabled = soap_get_opt_flag (opts, SOAP_MIME_ENC);
  ctx.def_enc = SOAP_DEF_ENC(opts);
  make_plink = soap_get_opt_flag (opts, SOAP_PLINK);

  /* collect XSDs; qr_recompile inside if needed */
  soap_wsdl_find_schemas (&ns_set, &types_set, &proc_set, &ctx, qpref, pref_len, qual);
  ns_set = dk_set_nreverse (ns_set);

  if (!soap_wsdl_ns_exists (&ns_set, def_ns))
    soap_wsdl_ns_decl (&ns_set, def_ns, NULL);

  if (strnicmp (url1, "http", 4))
    strcpy_ck (url, "http:");
  strcat_ck (url, url1);

  /* header */
  SES_PRINT (out,
      "<?xml version=\"1.0\"?>\n"
      "<description \n"
      " xmlns:xsd=\""     W3C_2001_TYPE_SCHEMA_XSD "\" \n"
      " xmlns:wsdl=\""    SOAP_WSDL_SCHEMA20 "\" \n"
      " xmlns:wsoap='"    SOAP_BINDING_TYPE_SOAP "' \n"
      " xmlns:whttp='"    SOAP_BINDING_TYPE_HTTP "' \n"
      " xmlns:wrpc='"	  SOAP_WSDL20_RPC "' \n"
      " xmlns:soapenc=\"" SOAP_ENC_SCHEMA11 "\" \n"
      );

  soap_wsdl_print_ns_decl (out, &ns_set, NULL);

  ses_sprintf (out, " xmlns:dl=\"%s\" \n", SOAP_TYPES_SCH (opts));

  ses_sprintf (out,
      " xmlns:tns=\"%s/services.wsdl\"\n targetNamespace=\"%s/services.wsdl\"\n xmlns=\"" SOAP_WSDL_SCHEMA20 "\">\n",
      url, url);

  /* we override the default encoding for virtual directory as wsdl2 also needs element declarations for RPC */
  soap_print_schema (out, &proc_set, qpref, pref_len, qual, &ns_set, &types_set, sch_elm_qual, &ctx,
      SOAP_WSDL_SCHEMA20, SOAP_MSG_DOC, SOAP_MSG_DOC);

  DO_SET (query_t *, proc, &proc_set)
    {
      if (qi && qi->qi_query && qi->qi_query == proc)
	continue;
      if (SOAP_MSG_HTTP & proc->qr_proc_place)
	{
	  dk_set_push (&http_set, (void *)proc);
	  dk_set_delete (&proc_set, (void *)proc);
	}
    }
  END_DO_SET ();

  for (inx = SOAP_INTERFACE; inx <= HTTP_INTERFACE; inx ++)
    {
      dk_set_t * set = tmp_set[inx];
      /* interface */
      if (!*set || !dk_set_length (*set))
	continue;
      ses_sprintf (out, "\t<interface name=\"%s%sInterface\">\n", svc_name, inx == HTTP_INTERFACE ? "Http" : "Soap");
      DO_SET (query_t *, proc, set)
	{
	  char * custom_type = NULL;

	  if (qi && qi->qi_query && qi->qi_query == proc)
	    continue;
	  if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	    operation_name = proc->qr_proc_name + pref_len;
	  else
	    {
	      sch_split_name (qual, proc->qr_proc_name, q, o, n);
	      operation_name = n;
	    }
	  /* input message */
	  literal = ((SOAP_MSG_LITERAL|SOAP_MSG_LITERALW) & proc->qr_proc_place);
	  async = (int) unbox ((box_t) SOAP_OPT (ONEWAY, proc, -1, 0));

	  /* Don't do old styles */
	  ses_sprintf (out, "\t\t<operation name=\"%s\" pattern='" SOAP_WSDL20_PATTERN_INOUT "'", operation_name);
	  if (!literal && !ctx.def_enc)
	    {
	      SES_PRINT (out, "\n\t\t\t style=\"" SOAP_WSDL20_RPC "\" ");
	      SES_PRINT (out, "\n\t\t\t wrpc:signature=\"");
	      soap_wsdl20_rpc_sig (out, proc);
	      SES_PRINT (out, "\"");
	    }
	  SES_PRINT (out, ">\n");
	  if (proc->qr_text && NULL != (desc = regexp_match_01 ("--##.*", proc->qr_text, 0)))
	    {
	      char * msg = desc + 4;
	      SES_PRINT (out, "\t\t\t<documentation>");
	      dks_esc_write (out, msg, strlen (msg),
		  CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT | DKS_ESC_COMPAT_SOAP);
	      SES_PRINT (out, "</documentation>\n");
	      dk_free_tree (desc);
	    }

	  if (!literal)
	    {
	      ses_sprintf (out, "\t\t\t<input messageLabel='In' element=\"dl:%s\"/>\n", operation_name);
	      docs++;
	      goto input_message_end;
	    }

	  ix = 0;
	  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	    {
	      if (ssl->ssl_type != SSL_REF_PARAMETER_OUT &&
		  !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
		  !IS_SOAP_MSG_SPECIAL(proc->qr_parm_place[ix]))
		{
		  caddr_t udt_custom_type = NULL;
		  custom_type = proc->qr_parm_alt_types[ix];
		  if (!custom_type && IS_COMPLEX_SQT (ssl->ssl_sqt))
		    {
		      udt_custom_type = custom_type =
			  soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx.opts, operation_name, ssl->ssl_name);
		    }

		  if (!custom_type)
		    SES_PRINT (out, "<!-- an input parameter of Doc/Literal encoded operation has no data type -->");
		  else
		    {
		      SES_PRINT (out, "\t\t\t<input messageLabel='In' element=\"");
		      wsdl_print_q_name (out, custom_type, &types_set);
		      SES_PRINT (out, "\" />\n");
		    }
		  dk_free_box (udt_custom_type);
		}
	      ix++;
	    }
	  END_DO_SET ();
input_message_end:

	  /* output message */
	  if (!literal)
	    {
	      ses_sprintf  (out, "\t\t\t<output messageLabel='Out' element=\"dl:%sResponse\" />\n", operation_name);
	      goto output_message_end;
	    }
	  ix = 0;
	  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
	    {
	      if (IS_SSL_REF_PARAMETER (ssl->ssl_type) &&
		  !IS_SOAP_SERVICE_PARAM(ssl->ssl_name) &&
		  !IS_SOAP_MSG_SPECIAL (proc->qr_parm_place[ix]))
		{
		  caddr_t udt_custom_type = NULL;
		  custom_type = proc->qr_parm_alt_types[ix];
		  if (!custom_type && IS_COMPLEX_SQT (ssl->ssl_sqt))
		    {
		      udt_custom_type = custom_type =
			  soap_sqt_to_soap_type (&(ssl->ssl_sqt), NULL, ctx.opts, operation_name, ssl->ssl_name);
		    }
		  if (!custom_type)
		    SES_PRINT (out, "<!-- an output parameter of Doc/Literal encoded operation has no data type -->");
		  else
		    {
		      SES_PRINT (out, "\t\t\t<output messageLabel='Out' element=\"");
		      wsdl_print_q_name (out, custom_type, &types_set);
		      SES_PRINT (out, "\" />\n");
		    }
		  dk_free_box (udt_custom_type);
		}
	      ix++;
	    }
	  END_DO_SET ();
	  custom_type = proc->qr_proc_alt_ret_type;
	  if (proc->qr_proc_place & SOAP_MSG_HTTP)
	    custom_type = NULL;

	  if (custom_type && DV_STRINGP(custom_type)
	      && !stricmp(custom_type, SOAP_VOID_TYPE)
	      && proc->qr_proc_ret_type)
	    {
	      sql_type_t sqt;
	      ddl_type_to_sqt (&sqt, (caddr_t *) proc->qr_proc_ret_type);
	      if (IS_UDT_XMLTYPE_SQT(&sqt))
		custom_type = NULL;
	    }

	  /* if return is not a void one */
	  if ((DV_STRINGP(custom_type) && 0 != stricmp(custom_type, SOAP_VOID_TYPE)))
	    {
	      SES_PRINT (out, "\t\t\t<output element='");
	      wsdl_print_q_name (out, custom_type, &types_set);
	      SES_PRINT (out, "' />\n");
	    }
output_message_end:
	  SES_PRINT (out, "\t\t</operation>\n");
	}
      END_DO_SET () /* end interface */
	  SES_PRINT (out, "\t</interface>\n");
    }

  /* bindings */
  for (inx = 11; dk_set_length (proc_set) && inx <= 12; inx++)
    {
      int soap_major = inx/10, soap_minor = inx % 10;
      ses_sprintf (out, "\t<binding name='%sSoap%dBinding' \n\t\tinterface='tns:%sSoapInterface' \n\t\ttype='%s' "
	  "\n\t\twsoap:version='%d.%d' \n\t\twsoap:protocol='" SOAP_BINDING_PROTOCOL_HTTP "'>\n",
	  svc_name, inx, svc_name, SOAP_BINDING_TYPE_SOAP, soap_major, soap_minor, inx);
      DO_SET (query_t *, proc, &proc_set)
	{
	  const char * soapAction;
	  if (qi && qi->qi_query && qi->qi_query == proc)
	    continue;

	  if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	    operation_name = proc->qr_proc_name + pref_len;
	  else
	    {
	      sch_split_name (qual, proc->qr_proc_name, q, o, n);
	      operation_name = n;
	    }
	  soapAction = SOAP_OPT (ACTION, proc, -1, NULL);
	  if (!soapAction)
	    {
	      char buf[PAGE_SZ];
	      buf[0] = '\x0';
	      /* operation in soapAction option is !'empty' && !'only' */
	      if ((prt_action && tolower (prt_action[0]) != 'e' && tolower (prt_action[0]) != 'o') || !prt_action)
		snprintf (buf, sizeof (buf), "%s", service_schema_name);
	      /* operation in soapAction option is 'yes' || 'only' */
	      if ((prt_action && (tolower (prt_action[0]) == 'y' || tolower (prt_action[0]) == 'o')) || !prt_action)
		{
		  strcat_ck (buf, "#");
		  strcat_ck (buf, operation_name);
		}
	      soapAction = buf;
	    }
	  ses_sprintf (out, "\t\t<operation ref='tns:%s' wsoap:soapAction='%s'/>\n", operation_name, soapAction);

	}
      END_DO_SET ();
      SES_PRINT (out, "\t</binding>\n");
    }

  if (dk_set_length (http_set))
    {
      ses_sprintf (out, "\t<binding name='%sHttpBinding' \n\t\tinterface='tns:%sHttpInterface' "
	  "\n\t\ttype='%s' whttp:methodDefault='GET'>\n",
	  svc_name, svc_name, SOAP_BINDING_TYPE_HTTP);
      DO_SET (query_t *, proc, &http_set)
	{
	  if (qi && qi->qi_query && qi->qi_query == proc)
	    continue;

	  if (!strnicmp (proc->qr_proc_name, qpref, pref_len))
	    operation_name = proc->qr_proc_name + pref_len;
	  else
	    {
	      sch_split_name (qual, proc->qr_proc_name, q, o, n);
	      operation_name = n;
	    }
	  ses_sprintf (out, "\t\t<operation ref='tns:%s' whttp:location='%s' />\n", operation_name, operation_name);

	}
      END_DO_SET ();
      SES_PRINT (out, "\t</binding>\n");
    }

  /* services */
  ses_sprintf (out, "\t<service name='%sService'>\n", svc_name);
  if (dk_set_length (proc_set))
    {
      ses_sprintf (out, "\t\t<endpoint name='%sSoap11Endpoint' binding='tns:%sSoap11Binding' address='%s'/>\n",
	  svc_name, svc_name, url);
      ses_sprintf (out, "\t\t<endpoint name='%sSoap12Endpoint' binding='tns:%sSoap12Binding' address='%s'/>\n",
	  svc_name, svc_name, url);
    }
  if (dk_set_length (http_set))
    {
      ses_sprintf (out, "\t\t<endpoint name='%sHttpEndpoint' binding='tns:%sHttpBinding' address='%s/Http'/>\n",
	  svc_name, svc_name, url);
    }
  SES_PRINT (out, "\t</service>\n");
  SES_PRINT (out, "</description>\n");
  soap_wsdl_schema_free (&ns_set, &types_set);
  dk_set_free (proc_set);
  dk_set_free (http_set);
  return NULL;
}


caddr_t
ws_soap_wsdl_services (ws_connection_t *ws, caddr_t doc)
{
  caddr_t url = ws_soap_get_url (ws, 0);
  caddr_t res;
  ws->ws_charset = CHARSET_UTF8;
  if (doc && !strncmp (doc, "services20.", 11))
    {
      res = soap_wsdl20_services (ws->ws_strses, NULL, ws_usr_qual (ws, 1), WS_SOAP_NAME (ws), NULL,
	  SERVICE_NAME (ws), SERVICE_SCHEMA_NAME (ws), ws->ws_cli, url, SOAP_OPTIONS(ws), NULL);
      ws->ws_header = box_dv_short_string ("Cache-Control: no-cache, must-revalidate\r\n"
	  "Pragma: no-cache\r\nExpires: -1\r\nContent-Type: application/wsdl+xml\r\n");
      if (!strcmp (doc, "services20.rdf"))
	ws->ws_xslt_url = box_dv_short_string ("http://local.virt/wsdl2rdf");
    }
  else
    {
      res = soap_wsdl_services (ws->ws_strses, NULL, ws_usr_qual (ws, 1), WS_SOAP_NAME (ws), NULL,
	  SERVICE_NAME (ws), SERVICE_SCHEMA_NAME (ws), ws->ws_cli, url, SOAP_OPTIONS(ws), NULL);
      ws->ws_header = box_dv_short_string ("Cache-Control: no-cache, must-revalidate\r\n"
	  "Pragma: no-cache\r\nExpires: -1\r\nContent-Type: text/xml\r\n");
    }
  dk_free_box (url);
  return res;
}

static caddr_t
bif_soap_current_url (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ws_connection_t *ws = qi->qi_client->cli_ws;
  if (!ws || !ws->ws_lines)
    return NEW_DB_NULL;
  return ws_soap_get_url (ws, 1);
}

static caddr_t
bif_dv_to_soap_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int dtp = (dtp_t) bif_long_arg (qst, args, 0, "dv_to_soap_type");
  return box_dv_short_string (dtp_to_soap_type (dtp));
}


static caddr_t
bif_soap_wsdl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t module;
  char service_name[MAX_QUAL_NAME_LEN];
  caddr_t url = NULL, ns = NULL, *soap_opts = NULL;
  query_instance_t *qi = (query_instance_t *)qst;
  dbe_schema_t *sc = isp_schema (qi->qi_space);
  dk_session_t *out;
  caddr_t name = NULL;
  query_t *mod = NULL;
  char mq[MAX_NAME_LEN], mo[MAX_NAME_LEN], mn[MAX_NAME_LEN * 2 + 2];
  caddr_t res;
  size_t inx, len;

  if (qi->qi_client->cli_ws && !BOX_ELEMENTS (args))
    {
      ws_connection_t *ws = qi->qi_client->cli_ws;
      url = ws_soap_get_url (ws, 0);
      out = strses_allocate ();
      soap_wsdl_services (out, NULL, ws_usr_qual (ws, 1), WS_SOAP_NAME (ws), NULL,
	  SERVICE_NAME (ws), SERVICE_SCHEMA_NAME (ws), ws->ws_cli, url, SOAP_OPTIONS(ws), qi);
      dk_free_box (url);
      res = strses_string (out);
      strses_free (out);
      return res;
    }

  module = bif_string_arg (qst, args, 0, "soap_wsdl");

  name = sch_full_module_name (sc, module, cli_qual (qi->qi_client),
      CLI_OWNER  (qi->qi_client));
  if (name)
    mod = sch_module_def (sc, name);
  if (!mod)
    sqlr_new_error ("37000", "SR317", "Invalid module name in soap_wsdl");
  strcpy_ck (service_name, mod->qr_proc_name);
  len = strlen (service_name);
  for (inx = 0; inx < len; inx++)
    {
      if (!isalnum (service_name[inx]))
	service_name[inx] = '_';
      else
	service_name[inx] = service_name[inx];
    }
  sch_split_name (NULL, mod->qr_proc_name, mq, mo, mn);

  if (BOX_ELEMENTS (args) > 1)
    url = bif_string_arg (qst, args, 1, "soap_wsdl");
  else if (qi->qi_client->cli_ws)
    url = ws_soap_get_url (qi->qi_client->cli_ws, 0);
  else
    sqlr_new_error ("37000", "SR318", "No URL specified & soap_wsdl called outside HTTP context");

  if (BOX_ELEMENTS (args) > 2)
    ns = bif_string_arg (qst, args, 2, "soap_wsdl");
  else if (qi->qi_client->cli_ws)
    ns = SERVICE_SCHEMA_NAME (qi->qi_client->cli_ws);
  else
    sqlr_new_error ("37000", "SR318", "No NS specified & soap_wsdl called outside HTTP context");

  if (BOX_ELEMENTS (args) > 3)
    soap_opts = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 3, "soap_wsdl");
  else if (qi->qi_client->cli_ws)
    soap_opts = SOAP_OPTIONS (qi->qi_client->cli_ws);

  out = strses_allocate ();
  soap_wsdl_services (out, mod, mq, mo, mn, service_name, ns, qi->qi_client, url, soap_opts, qi);
  res = strses_string (out);
  strses_free (out);
  return res;
}


/* SOAP restricted schema validator code */
static caddr_t
xml_find_schema_instance_attribute (caddr_t *entity, const char *name)
{
  caddr_t val = xml_find_attribute (entity, name, W3C_2001_TYPE_SCHEMA_XSI);
  if (!val)
    val = xml_find_attribute (entity, name, W3C_TYPE_SCHEMA_XSI);
  if (!val)
    {
      caddr_t ent_name = XML_ELEMENT_NAME (entity);
      if (ent_name && (
	    !strncmp (ent_name, W3C_2001_TYPE_SCHEMA_XSI, strlen (W3C_2001_TYPE_SCHEMA_XSI)) ||
	    !strncmp (ent_name, W3C_TYPE_SCHEMA_XSI, strlen (W3C_TYPE_SCHEMA_XSI))))
	val = xml_find_attribute (entity, name, NULL);
    }
  return val;
}

static caddr_t
xml_find_schema_attribute (caddr_t *entity, const char *name)
{
  caddr_t val = xml_find_attribute (entity, name, W3C_2001_TYPE_SCHEMA_XSD);
  if (!val)
    val = xml_find_attribute (entity, name, W3C_TYPE_SCHEMA_XSD);
  if (!val)
    {
      caddr_t ent_name = XML_ELEMENT_NAME (entity);
      if (ent_name && (
	    !strncmp (ent_name, W3C_2001_TYPE_SCHEMA_XSD, strlen (W3C_2001_TYPE_SCHEMA_XSD)) ||
	    !strncmp (ent_name, W3C_TYPE_SCHEMA_XSD, strlen (W3C_TYPE_SCHEMA_XSD))))
	val = xml_find_attribute (entity, name, NULL);
    }
  return val;
}

static caddr_t
xml_find_wsdl_attribute (caddr_t *entity, char *name)
{
  caddr_t val = xml_find_attribute (entity, name, SOAP_WSDL_SCHEMA11);
  return val;
}

static const char *
xml_find_soapenc_attribute (caddr_t *entity, const char *name)
{
  caddr_t val = xml_find_attribute (entity, name, SOAP_ENC_SCHEMA11);
  if (val)
    return extract_last_xml_name_part (val);
  return NULL;
}

/*XXX: make alias of the above */
static const char *
xml_find_soapenc12_attribute (caddr_t *entity, const char *name)
{
  caddr_t val = xml_find_attribute (entity, name, SOAP_ENC_SCHEMA12);
  if (val)
    return extract_last_xml_name_part (val);
  return NULL;
}


static caddr_t *
xml_find_schema_child (caddr_t *entity, const char *name, int nth)
{
  caddr_t *val = xml_find_child (entity, name, W3C_2001_TYPE_SCHEMA_XSD, nth, NULL);
  if (!val)
    val = xml_find_child (entity, name, W3C_TYPE_SCHEMA_XSD, nth, NULL);
  return val;
}



int
xml_is_sch_qname (char *tag, char *attr)
{
  if (attr && xml_is_in_schema_ns (attr))
    {
      const char *type_name = extract_last_xml_name_part (attr);
      if (xml_is_sch_qname_attr (type_name))
	return 1;
    }
  else if (tag && xml_is_in_schema_ns (tag))
    {
      if (attr && xml_is_sch_qname_attr (attr))
	return 1;
      else if (attr && xml_is_in_ns (attr, SOAP_WSDL_SCHEMA11))
	{
	  const char *type_name = extract_last_xml_name_part (attr);
	  if (xml_is_wsdl_qname_attr (type_name))
	    return 1;
	}
    }
  return 0;
}

int
xml_is_soap_qname (char *tag, char *attr)
{
  if (attr && xml_is_in_soapenc_ns (attr))
    {
      const char *type_name = extract_last_xml_name_part (attr);
      if (xml_is_soap_qname_attr (type_name))
	return 1;
    }
  else if (tag && xml_is_in_soapenc_ns (tag))
    {
      if (attr && xml_is_soap_qname_attr (attr))
	return 1;
    }
  return 0;
}

int
xml_is_wsdl_qname (char *tag, char *attr)
{
  if (tag && xml_is_in_ns (tag, SOAP_WSDL_SCHEMA11))
    {
      const char *type_name = extract_last_xml_name_part (attr);
      if (attr && xml_is_wsdl_qname_attr (type_name))
	return 1;
    }
  return 0;
}

static caddr_t
soap_find_attachment (caddr_t * entity, soap_ctx_t * ctx, int * conv)
{
  int inx;
  caddr_t id = NULL;
  *conv = 0;
  if (!ctx || !entity || !ctx->attachments)
    return NULL;
  if (NULL == (id = xml_find_attribute (entity, "href", NULL)))
    {
      if (NULL == (id = xml_find_attribute (entity, "location", SOAP_REF_SCH_200204)))
	return NULL;
    }

  if (id[0] == '#')
    id++;

  DO_BOX (caddr_t *, elm, inx, ctx->attachments)
    {
      char * temp = NULL;
      if (BOX_ELEMENTS (elm) < 3)
	continue;
      temp = elm[0];
      if (0 == strncmp (temp, "cid:", 4))
	  temp = temp + 4;
      if (0 == strcmp ((char *)unbox_ptrlong (id), temp))
	{
	  if (ctx->raw_attachments) /* no further processing, all is returned to proc */
	    return box_copy_tree ((box_t) elm);

	  if (0 == strnicmp (elm[1], "text/", 5))
	    *conv = 1;
	  return elm[2];
	}
    }
  END_DO_BOX;
  return NULL;
}

static int
soap_type_exists (caddr_t name, int elem)
{
  caddr_t *place = NULL;
  if (name)
    place = (caddr_t *)id_hash_get (HT_SOAP(elem), (caddr_t) &name);
  if (place)
    return 1;
  return 0;
}

static void
soap_box_xev_get_type (char *elem_type, dtp_t *proposed_type, caddr_t *schema_tree, int elem, int ref_type, int allow_b64)
{
  *schema_tree = NULL;
  if (proposed_type)
    *proposed_type = 0;
  if (!elem_type)
    return;
  /* SOAP-ENC defines same types as XSD */
  if (xml_is_in_schema_ns (elem_type) || xml_is_in_soapenc_ns (elem_type) || !strrchr(elem_type, ':'))
    {
      const char *type_name = extract_last_xml_name_part (elem_type);
      if (proposed_type)
	*proposed_type = soap_type_to_dtp (type_name, allow_b64);
    }
#if 0
  else if (xml_is_in_virt_ns (elem_type))
    {
      char *type_name = extract_last_xml_name_part (elem_type);
      caddr_t *place = (caddr_t *)id_hash_get (HT_SOAP(0), (caddr_t) &type_name);
      *schema_tree = place ? ((caddr_t *)(*place))[0] : NULL;
    }
  else if (!xml_is_in_virt_ns (elem_type))
#endif
  else
    {
      caddr_t *place = (caddr_t *)id_hash_get (HT_SOAP(elem), (caddr_t) &elem_type);
      const char *elt_name;
      *schema_tree = place ? ((caddr_t *)(*place))[0] : NULL;
      /* if it's Doc/Literal encoded parameter */
      if (!ref_type && *schema_tree && NULL != (elt_name = XML_ELEMENT_NAME (*schema_tree)) &&
	  !strcmp(elt_name, SOAP_TAG_DT_ELEMENT))
	{
	  caddr_t type = xml_find_schema_attribute ((caddr_t *)(*schema_tree), "type");
	  place = NULL;
	  if (type)
	    place = (caddr_t *)id_hash_get (HT_SOAP(0), (caddr_t) &type);
	  *schema_tree = place ? ((caddr_t *)(*place))[0] : NULL;
	  if (!place && type && (NULL == strrchr (type, ':') || xml_is_in_schema_ns (type)))
	    {
	      const char *type_name = extract_last_xml_name_part (type);
	      if (proposed_type)
		*proposed_type = soap_type_to_dtp (type_name, allow_b64);
	    }
	}
    }
}

#define IS_MULTIDIM_ARR(s,v) ((v) <= 11 ? \
    				(NULL != s && NULL != strchr (s,',') && NULL != strchr (s, '[')) : \
				(NULL != s && NULL != strchr (s,' ')))

static int
soap_multi_arr_cmp_offset (const char * offs, dk_set_t *lev)
{
  int ix = 0;
  long i;
  if (!offs || offs[0] != '[')
    return 1;
  offs++;
  DO_SET (ptrlong *, elm, lev)
    {
      i = 0;
      while (ix && *offs)
	{
	  if (*offs == ',')
	    {
	      offs++;
	      break;
	    }
	  offs++;
	}
      /*TODO: add error if end of offsets reached w/o matching char*/
      if (1 != sscanf (offs, "%ld", &i))
	i = 0;
      if (i != *elm)
	return 0;
      ix++;
    }
  END_DO_SET ();
  return 1;
}

static caddr_t
soap_box_xml_entity_multi_dim_arr (caddr_t *entity, caddr_t a_name, caddr_t a_type, caddr_t *err_ret,
    long n_max, long *inx, const char *delim, dk_set_t *lev, soap_ctx_t * ctx)
{
  caddr_t *ret = NULL, *elem_entity;
  long n_elm = (delim ? atoi (delim) : 0), ix;
  if (ctx->soap_version <= 11)
    delim = strchr (delim, ',');
  else
    delim = strchr (delim, ' ');
  if (delim) delim++;
  if (n_elm > 0)
    {
      ret = (caddr_t *) dk_alloc_box_zero (n_elm * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (ix = 0; ix < n_elm; ix++)
	{
	  dk_set_push (lev, (void *)&ix);
	  if (delim)
	    {
	      ret[ix] = soap_box_xml_entity_multi_dim_arr (entity, a_name, a_type, err_ret,
		  n_max, inx, delim, lev, ctx);
	    }
	  else
	    {
	      const char * offs = NULL;
	      elem_entity = xml_find_exact_child (entity, a_name, (*inx)++);
	      if (*inx > n_max)
		goto error;
	      if (elem_entity)
		{
		  offs = xml_find_soapenc_attribute (elem_entity, "position");
		  *lev = dk_set_nreverse (*lev);
		  if (soap_multi_arr_cmp_offset (offs, lev))
		    ret[ix] = soap_box_xml_entity_validating (elem_entity, err_ret, a_type, 0, ctx);
		  else
		    {
		      ret[ix] = NEW_DB_NULL;
		      (*inx)--;
		    }
		  *lev = dk_set_nreverse (*lev);
		}
	    }
	  dk_set_pop (lev);
	}
    }
  return (caddr_t) ret;
error:
  dk_free_tree ((box_t) ret);
  return NULL;
}


static caddr_t *
soap_box_attrs_validating (caddr_t *entity, caddr_t *extension, soap_ctx_t * ctx)
{
  caddr_t *e_attr_ptr;
  int attr_inx = 0;
  dk_set_t attrs = NULL;

  e_attr_ptr = xml_find_schema_child (extension, "attribute", attr_inx ++);
  while (e_attr_ptr)
    {
      const char * attr_name;
      caddr_t attr_type;
      caddr_t attr_use;
      caddr_t attr_value;
      caddr_t attr_ref = xml_find_schema_attribute (e_attr_ptr, "ref");

      if (attr_ref)
	{
	  soap_box_xev_get_type (attr_ref, NULL, (caddr_t *) &e_attr_ptr, -1, 1, 0);
	}

      attr_name = extract_last_xml_name_part (xml_find_schema_attribute (e_attr_ptr, "name"));
      attr_type = xml_find_schema_attribute (e_attr_ptr, "type");
      attr_use = xml_find_schema_attribute (e_attr_ptr, "use");

      if (!attr_use)
	attr_use = "optional";
      attr_value = xml_find_attribute (entity, attr_name, NULL);
      if (!strcmp (attr_use, "required") && !attr_value)
	goto attr_error;
      else if (!strcmp (attr_use, "prohibited") && attr_value)
	goto attr_error;
      if (attr_value)
	{
	  caddr_t err_ret = NULL;
	  attr_value =
	      soap_box_xml_entity_validating (
		  (caddr_t *) attr_value,
		  &err_ret,
		  attr_type, 0, ctx);
	  if (err_ret)
	    {
	      dk_free_tree (err_ret);
	      goto attr_error;
	    }
	  dk_set_push (&attrs, box_dv_short_string (attr_name));
	  dk_set_push (&attrs, attr_value);
	}
      e_attr_ptr = xml_find_schema_child (extension, "attribute", attr_inx ++);
    }
  return (caddr_t *) list_to_array (dk_set_nreverse (attrs));

attr_error:
  dk_free_tree (list_to_array (attrs));
  return NULL;
}

static int
xev_is_extension_to (char * type_ref, char * target_type, int elem)
{
  caddr_t *schema_tree;
  dtp_t proposed_type;
  caddr_t *e_ptr;
  soap_box_xev_get_type (type_ref, &proposed_type, (caddr_t *) &schema_tree, elem, 0, 0);
  if (NULL != (e_ptr = xml_find_schema_child (schema_tree, "complexContent", 0)))
    {
      caddr_t type_base;
      caddr_t *extension;

      if (NULL == (extension = xml_find_schema_child (e_ptr, "extension", 0)))
	{
	  if (NULL == (extension = xml_find_schema_child (e_ptr, "restriction", 0)))
	    goto error;
	}
      e_ptr = extension;
      type_base = xml_find_schema_attribute (e_ptr, "base");
      if (type_base)
	{
	  if (!strcmp (type_base, target_type))
	    return 1;
	  else
	    return xev_is_extension_to (type_base, target_type, elem);
	}
    }
error:
  return 0;
}

static int
soap_box_enum_validate (caddr_t *entity, caddr_t box, caddr_t *extension, soap_ctx_t * ctx)
{
  caddr_t * e_restr = extension, *e_ptr;
  caddr_t value, cmp_value;
  int inx = 0;
  if (entity && (!ARRAYP (entity) || BOX_ELEMENTS (entity) != 2))
    return 1;
  if (box)
    {
      caddr_t err = NULL;
      value = box_cast_to (NULL, box, DV_TYPE_OF (box), DV_STRING,
	       NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
      if (err)
	{
	  ctx->error_message = err;
	  return 0;
	}
    }
  else
    value = entity[1];
  e_ptr = xml_find_schema_child (e_restr, "enumeration", inx++);
  while (e_ptr)
    {
      cmp_value = xml_find_schema_attribute (e_ptr, "value");
      if (value && cmp_value && !strcmp (cmp_value, value))
	{
	  if (box)
	    dk_free_box (value);
	  return 1;
	}
      e_ptr = xml_find_schema_child (e_restr, "enumeration", inx++);
    }
  if (box)
    dk_free_box (value);
  return 0;
}

#define SOAP_VALIDATE_ERROR(msg) { \
  				   if (!ctx->error_message) \
	    		             ctx->error_message = srv_make_new_error msg; \
				   goto error; \
				 }
#define SOAP_VALIDATE_ERROR_2(msg,box_to_free) { \
  				   if (!ctx->error_message) \
	    		             ctx->error_message = srv_make_new_error msg; \
                                   dk_free_box (box_to_free); \
				   goto error; \
				 }

static caddr_t *
soap_box_next_ext_type (caddr_t * type_ref, caddr_t * err_ret, soap_ctx_t * ctx)
{
  caddr_t *schema_tree;
  dtp_t proposed_type;
  caddr_t *e_ptr;
  if (!type_ref || !*type_ref || !strcmp (*type_ref, SOAP_ENC_SCHEMA11 ":Struct"))
    return NULL;
  soap_box_xev_get_type (*type_ref, &proposed_type, (caddr_t *) &schema_tree, 0, 0, 0);
  if (!schema_tree)
    SOAP_VALIDATE_ERROR (("22023", "SV076", "Can't find schema definition for type '%s'", *type_ref));
  if (NULL != (e_ptr = xml_find_schema_child (schema_tree, "complexContent", 0)))
    {
      caddr_t *extension;

      if (NULL == (extension = xml_find_schema_child (e_ptr, "extension", 0)))
	{
	  if (NULL == (extension = xml_find_schema_child (e_ptr, "restriction", 0)))
	    SOAP_VALIDATE_ERROR (("22023", "SV078", "The type '%s' is derived by extension or restriction, but no such base type", *type_ref));
	}
      e_ptr = extension;
      *type_ref = xml_find_schema_attribute (e_ptr, "base");
      return e_ptr;
    }
error:
   if (!*err_ret)
     {
       if (!ctx->error_message)
	 *err_ret = srv_make_new_error ("22023", "SV030",
	     "Can't validate according to the parameter schema %s", *type_ref);
       else
	 {
	   *err_ret = ctx->error_message;
	   ctx->error_message = NULL;
	 }
     }
  return NULL;
}

static caddr_t
soap_box_xml_entity_validating_1 (caddr_t *entity, caddr_t *err_ret, caddr_t type_ref, int elem,
    soap_ctx_t * ctx, sql_type_t * sqt)
{
   caddr_t type_name;
   caddr_t *e_ptr;
   caddr_t *schema_tree;
   dtp_t proposed_type;
   caddr_t ret = NULL;
   dk_set_t ret_set = NULL;
   caddr_t elt_type;
   sql_class_t *udt = sqt ? sqt->sqt_class : NULL;

   if (type_ref && !strcmp (type_ref, SOAP_XML_TYPE)) /* if raw XML is used */
     {
       caddr_t tree_copy = list (2, list (1, uname__root), box_copy_tree ((box_t) entity));
       return tree_copy;
     }

   if (xml_find_schema_instance_nil_attribute (entity)) /* it's a null */
     return dk_alloc_box (0, DV_DB_NULL);

   /* it can be of ANY type and this overrides the inferred type */
   if (NULL != (elt_type = xml_find_schema_attribute (entity, "type")))
     type_ref = elt_type;

   if (type_ref && !strcmp (type_ref, SOAP_ANY_TYPE) && BOX_ELEMENTS (entity) == 1) /* empty element of ANY type */
     return NULL;

   /* if not RPC style used */
   if (type_ref && !strcmp (type_ref, SOAP_ANY_TYPE)
       && !elt_type && NULL != (elt_type = xml_find_schema_instance_attribute (entity, "type")))
     {
       if (!xml_is_in_soapenc_ns (elt_type))
         type_ref = elt_type;
     }

   soap_box_xev_get_type (type_ref, &proposed_type, (caddr_t *) &schema_tree, elem, 0, 0);
   if (!proposed_type && !schema_tree && !udt && !IS_ARRAY_SQTP (sqt))
     SOAP_VALIDATE_ERROR (("22023", "SV001", "Can't find schema definition for type '%s'", type_ref));

   type_name = xml_find_schema_attribute (schema_tree, "name");

   if (type_name && ARRAYP (schema_tree) && BOX_ELEMENTS (schema_tree) == 1 &&
       ARRAYP (entity) && BOX_ELEMENTS (entity) == 1) /* an empty element */
     return dk_alloc_box (0, DV_DB_NULL);

   if (NULL != (e_ptr = xml_find_schema_child (schema_tree, "complexContent", 0)))
     {
       caddr_t type_base;
       caddr_t *extension;
       int has_attrs = 0;

       extension = xml_find_schema_child (e_ptr, "restriction", 0);
       if (!extension)
	 {
	   extension = xml_find_schema_child (e_ptr, "extension", 0);
	   if (extension && NULL != xml_find_schema_child (extension, "attribute", 0))
	     has_attrs = 1;
	   /*XXX: check this:
	     else if (XML_ELEMENT_ATTR_COUNT (entity))
	     SOAP_VALIDATE_ERROR (("22023", "SV002", "The type '%s' is derived by extension, but an attribute is supplied", type_ref));*/
	 }

       e_ptr = extension;
       type_base = xml_find_schema_attribute (e_ptr, "base");

       if (type_base && (!strcmp (type_base, SOAP_ENC_SCHEMA11 ":Struct")
	     || xev_is_extension_to (type_base, SOAP_ENC_SCHEMA11 ":Struct", 0)))
	 {
	   int inx = 0, is_choice;
	   caddr_t *e_seq, choice;

	   /* structure */
	   dk_set_push (&ret_set, dk_alloc_box (0, DV_COMPOSITE));
	   if (has_attrs)
	     {
	       caddr_t *attrs = soap_box_attrs_validating (entity, extension, ctx);
	       if (!attrs)
	         SOAP_VALIDATE_ERROR (("22023", "SV003", "The type '%s' requires an attribute", type_ref))
	       else
		 dk_set_push (&ret_set, attrs);
	     }
	   else
	     dk_set_push (&ret_set, box_dv_short_string (type_name));

	   do
	     {
	       int inx1;
	       inx1 = 0;

	       choice = xml_find_schema_attribute (e_ptr, "choice");
	       is_choice = choice ? atoi (choice) : 0;

	       if (*err_ret) /* ensure error handling on second, etc. loops */
		 goto error;

	       e_seq = xml_find_schema_child (e_ptr, "sequence", 0);
	       e_ptr = xml_find_schema_child (e_seq, "element", inx1 ++);

	       /* it's a struct with at least one member, but no incoming data (like <a />) */
	       if (e_ptr && BOX_ELEMENTS (entity) == 1)
		 return NEW_DB_NULL;

	       while (e_ptr)
		 {
		   caddr_t elem_name, elem_type, a_ref;
		   caddr_t *elem_entity;
		   caddr_t ret_elem, a_max, a_min;
		   long n_max = 0, nth;

		   a_min = xml_find_schema_attribute (e_ptr, "minOccurs");
		   a_max = xml_find_schema_attribute (e_ptr, "maxOccurs");

		   if (NULL != (a_ref = xml_find_schema_attribute (e_ptr, "ref")))
		     /* there can be reference to another element */
		     {
		       e_ptr = NULL;
		       soap_box_xev_get_type (a_ref, NULL, (caddr_t *) &e_ptr, 1, 1, 0);
		     }
		   elem_name = xml_find_schema_attribute (e_ptr, "name");
		   elem_type = xml_find_schema_attribute (e_ptr, "type");

		   if (!elem_type)
		     SOAP_VALIDATE_ERROR (("22023", "SV004", "Child (%s) of type '%s' have no XSD type assigned",
			   (elem_name ? elem_name : "unknown"), type_ref));

		   if (!a_max)
		     n_max = 1;
		   else if (!strcmp (a_max, "unbounded"))
		     n_max = LONG_MAX;
		   else
		     n_max = atol (a_max);

		   nth = 0;

		   do
		     {
		       /* if no explicit nillable = false make it null */
		       elem_entity = xml_find_child_by_entity_name (entity, elem_name, nth++);
		       if (!elem_entity /* || xml_find_child_by_entity_name (entity, elem_name, 1)*/)
			 {
			   if (nth > 1)
			     break;
			   else
			     ret_elem = is_choice ? NULL : NEW_DB_NULL;
			 }
		       else
			 ret_elem = soap_box_xml_entity_validating (elem_entity, err_ret, elem_type, 0, ctx);

		       if (*err_ret)
			 goto error;

		       if (NULL != ret_elem)
			 {
			   dk_set_push (&ret_set, box_dv_short_string (extract_last_xml_name_part (elem_name)));
			   dk_set_push (&ret_set, ret_elem);
			 }
		     }
		   while (elem_entity);

		   e_ptr = xml_find_schema_child (e_seq, "element", inx1++);
		 }
	       inx += inx1;
	     }
	   while (NULL != (e_ptr = soap_box_next_ext_type (&type_base, err_ret, ctx)));

/*XXX:	   if (ent_child_inx != inx)
	     goto error;
*/
	   if (!udt_soap_struct_to_udi (
		 (caddr_t *) id_hash_get (ht_soap_udt, (caddr_t) &type_ref),
		 &ret_set, &ret, err_ret))
	     goto error;
	 }
       else if (type_base && !strcmp (type_base, SOAP_ENC_SCHEMA11 ":Array"))
	 { /* array */
	   caddr_t a_min, a_max, a_type, a_name, a_ref;
	   long n_min, n_max, inx = 0;
	   caddr_t *elem_entity = NULL;
	   caddr_t ret_elem = NULL;
	   const char *wsdl_type = NULL;

	   e_ptr = xml_find_schema_child (e_ptr, "sequence", 0);
	   if (!e_ptr) /* no sequence */
	     SOAP_VALIDATE_ERROR (("22023", "SV005", "An array of type '%s' have no child elements defined", type_ref));

	   e_ptr = xml_find_schema_child (e_ptr, "element", 0);
	   if (!e_ptr && elem && BOX_ELEMENTS (entity) == 1) /* empty element */
	     return list (0);

	   a_min = xml_find_schema_attribute (e_ptr, "minOccurs");
	   a_max = xml_find_schema_attribute (e_ptr, "maxOccurs");

	   if (NULL != (a_ref = xml_find_schema_attribute (e_ptr, "ref")))
	     /* there can be reference to another element */
	     {
               e_ptr = NULL;
 	       soap_box_xev_get_type (a_ref, NULL, (caddr_t *) &e_ptr, 1, 1, 0);
	     }

	   a_name = xml_find_schema_attribute (e_ptr, "name");
	   a_type = xml_find_schema_attribute (e_ptr, "type");
	   if (ctx->soap_version <= 11)
	     wsdl_type = xml_find_soapenc_attribute (entity, "arrayType");
	   else if (ctx->soap_version == 12)
	     wsdl_type = xml_find_soapenc12_attribute (entity, "arraySize");

	   if (!a_name || !a_type || !a_min || !a_max)
	     SOAP_VALIDATE_ERROR (("22023", "SV006", "The type '%s' have no name, type or range specified", type_ref));
	   n_min = atol (a_min);
	   if (!strcmp (a_max, "unbounded"))
	     n_max = LONG_MAX;
	   else
	     n_max = atol (a_max);
#if 1 /* it can be with ANY name */
	   a_name = NULL;
#endif
	   if (!IS_MULTIDIM_ARR (wsdl_type, ctx->soap_version))
	     {
	       if (BOX_ELEMENTS (entity) == 1 || (BOX_ELEMENTS (entity) == 2 && !ARRAYP (entity[1])))
		 {
		   ret = dk_alloc_box (0, DV_ARRAY_OF_POINTER);
		   inx = 1;
		 }
	       else
		 {
		   long ix = 0, max_items = 0;
		   char *openb = wsdl_type ? strchr (wsdl_type, '[') : NULL;
		   if (openb && 1 != sscanf (openb, "[%ld]", &max_items))
		     max_items = 0;
		   elem_entity = xml_find_exact_child (entity, a_name, inx++);
		   while (elem_entity || (max_items > 0 && max_items > ix))
		     { /* support for offsets is here */
		       const char *offset = xml_find_soapenc_attribute (elem_entity, "position");
		       long off = -1;
		       if (offset && 1 != sscanf (offset, "[%ld]", &off))
			 off = -1;
		       if (ix >= n_max)
			 SOAP_VALIDATE_ERROR (("22023", "SV007", "Maximum number (%ld) of elements of array '%s' is reached, but there is more data", n_max, type_ref));
		       if ((!elem_entity && max_items > ix) || (off >= 0 && ix != off))
			 ret_elem = dk_alloc_box (0, DV_DB_NULL);
		       else if (elem_entity)
			 {
			   ret_elem = soap_box_xml_entity_validating (elem_entity, err_ret, a_type, 0, ctx);
			   elem_entity = xml_find_exact_child (entity, a_name, inx++);
			 }
		       if (*err_ret)
			 goto error;
		       dk_set_push (&ret_set, ret_elem);
		       ix++;
		     }
		   if (ix > inx) /* adjust the counter */
		     inx = ix;
		 }
	     }
	   else
	     {  /*loop in nested arrays*/
	       const char *brace;
	       dk_set_t lev = NULL;
	       if (ctx->soap_version <= 11)
		 {
		   brace = strchr (wsdl_type, '[');
		   brace++;
		 }
	       else
		 brace = wsdl_type;
	       ret = soap_box_xml_entity_multi_dim_arr (entity, a_name, a_type, err_ret,
		   n_max, &inx, brace, &lev, ctx);
	     }
	   if (inx - 1 < n_min)
	     SOAP_VALIDATE_ERROR (("22023", "SV008", "Minimum number (%ld) of elements of array '%s' is not reached", n_min, type_ref));
	   if (has_attrs)
	     {
	       caddr_t *attrs = soap_box_attrs_validating (entity, extension, ctx);
	       if (!attrs)
	         SOAP_VALIDATE_ERROR (("22023", "SV009", "The type '%s' should have an attribute, but it's not given", type_ref))
	       else
		 dk_set_push (&ret_set, attrs);
	     }
	 }
       else
	 SOAP_VALIDATE_ERROR (("22023", "SV010", "An unsupported type '%s' is specified (%s)",
	       type_ref, type_base ? type_base : "unspecified"))
     }
   else if (NULL != (e_ptr = xml_find_schema_child (schema_tree, "simpleContent", 0)))
     { /* support for simpleType/extension */
       caddr_t type_base, ret_elem, media_type = NULL , enumeration = NULL;
       caddr_t *extension, *restriction;
       int has_attrs = 0, n_enum = 0;

       extension = xml_find_schema_child (e_ptr, "extension", 0);
       if (extension)
	 has_attrs = 1;
       else
	 {
	   extension = xml_find_schema_child (e_ptr, "restriction", 0);
	   enumeration = xml_find_schema_attribute (extension, "enumeration");
	   n_enum = enumeration ? atoi (enumeration) : 0;
	   restriction = extension;
	 }

       if (!extension && XML_ELEMENT_ATTR_COUNT (entity))
	 SOAP_VALIDATE_ERROR (("22023", "SV011", "The type '%s' is not derived by extension, but an attribute is supplied", type_ref));

       e_ptr = extension;
       type_base = xml_find_schema_attribute (e_ptr, "base");

       e_ptr = xml_find_schema_child (e_ptr, "annotation", 0);
       if (e_ptr)
	 e_ptr = xml_find_schema_child (e_ptr, "appinfo", 0);
       if (e_ptr)
	 {
	   e_ptr = xml_find_child (e_ptr, "mediaType", SOAP_CONTENT_TYPE_200204, 0, NULL);
           media_type = xml_find_attribute (e_ptr, "value", NULL);
	 }

       if (ARRAYP (entity) && BOX_ELEMENTS (entity) == 1 && media_type)
	 {
	   int try_convert;
	   caddr_t attachment = soap_find_attachment (entity, ctx, &try_convert);
	   if (attachment)
	     {
	       if (!try_convert)
		 return box_copy (attachment);

	       ret_elem = soap_box_xml_entity_validating ((caddr_t *) attachment, err_ret, type_base, 0, ctx);

	       if (*err_ret)
		 goto error;

	       return ret_elem;
	     }
	   else
	     SOAP_VALIDATE_ERROR (("22023", "SV012", "The type '%s' requires an attachment", type_ref))
	 }


       dk_set_push (&ret_set, dk_alloc_box (0, DV_COMPOSITE));
       if (has_attrs)
	 {
	   caddr_t *attrs = soap_box_attrs_validating (entity, extension, ctx);
	   if (!attrs)
	     SOAP_VALIDATE_ERROR (("22023", "SV014", "The type '%s' requires an attribute", type_ref))
	   else
	     dk_set_push (&ret_set, attrs);
	 }
       else
	 dk_set_push (&ret_set, box_dv_short_string (type_name));

       if (n_enum && !soap_box_enum_validate (entity, NULL, extension, ctx))
	 SOAP_VALIDATE_ERROR (("22023", "SV064", "Bad value of enumeration '%s'", type_ref))

       ret_elem = soap_box_xml_entity_validating (entity, err_ret, type_base, 0, ctx);

       if (*err_ret)
	 goto error;

       dk_set_push (&ret_set, ret_elem);
     }
   else if (udt)
     {
       int inx;
       if (!udt->scl_member_map)
	 SOAP_VALIDATE_ERROR (("22023", "SV015", "The type '%s' requires at least one child ", type_ref));
       DO_BOX (sql_field_t *, fld, inx, udt->scl_member_map)
	 {
	   caddr_t soap_fld_name;
	   caddr_t value;
	   caddr_t *elem_entity;

	   soap_fld_name = fld->sfl_soap_name ? fld->sfl_soap_name : fld->sfl_name;

	   if (!stricmp (udt->scl_name, "DB.DBA.XMLType") && !strcmp (fld->sfl_name, "xt_ent"))
	     {
	       xml_tree_ent_t * xte;
	       elem_entity = (caddr_t*) xml_element_nonspace_child ((caddr_t) entity, 0);
	       value = soap_box_xml_entity_validating_1 (elem_entity, err_ret, SOAP_XML_TYPE, 0, ctx, NULL);
	       xte = xte_from_tree (value, &soap_fake_top_qi);
	       if (*err_ret)
		 goto error;
	       dk_set_push (&ret_set, box_dv_short_string (extract_last_xml_name_part (soap_fld_name)));
	       dk_set_push (&ret_set, xte);
	     }
	   else
	     {
	       elem_entity = xml_find_child_by_entity_name (entity, soap_fld_name, 0);
	       if (xml_find_child_by_entity_name (entity, soap_fld_name, 1))
		 SOAP_VALIDATE_ERROR (("22023", "SV074", "The type '%s' requires definition of '%s'", type_ref, soap_fld_name));
	       if (elem_entity)
		 {
		   caddr_t soap_fld_type;
		   soap_fld_type = soap_sqt_to_soap_type (&(fld->sfl_sqt), fld->sfl_soap_type, ctx->opts, NULL, NULL);
		   value = soap_box_xml_entity_validating_1 (elem_entity, err_ret, soap_fld_type,
		       0, ctx, &(fld->sfl_sqt));
		   dk_free_tree (soap_fld_type);
		   if (*err_ret)
		     goto error;
		   dk_set_push (&ret_set, box_dv_short_string (extract_last_xml_name_part (soap_fld_name)));
		   dk_set_push (&ret_set, value);
		 }
	     }
	 }
       END_DO_BOX;
       if (!udt_soap_struct_to_udi (&udt->scl_name, &ret_set, &ret, err_ret))
	 goto error;
     }
   else if (IS_ARRAY_SQTP (sqt))
     {
       long n_max = sqt->sqt_precision, inx = 0;
       caddr_t *elem_entity;
       sql_type_t a_sqt;
       char * a_name = NULL;
       caddr_t a_type = NULL;
       long ix = 0, max_items = (n_max == ARRAY_MAX ? 0 : n_max);
       caddr_t ret_elem = NULL;

       ddl_type_to_sqt (&a_sqt, sqt->sqt_tree);
       if (!IS_COMPLEX_SQT(a_sqt))
	 a_type = soap_sqt_to_soap_type (&(a_sqt), NULL, ctx->opts, NULL, NULL);
       elem_entity = xml_find_exact_child (entity, a_name, inx++);
       while (elem_entity || (max_items > 0 && max_items > ix))
	 {
	   const char * offset = xml_find_soapenc_attribute (elem_entity, "position");
	   long off = -1;
	   if (offset && 1 != sscanf (offset, "[%ld]", &off))
	     off = -1;
	   if (ix >= n_max)
	     SOAP_VALIDATE_ERROR (("22023", "SV070", "Maximum number (%ld) of elements of array is reached, but there is more data", n_max));
	   if ((!elem_entity && max_items > ix) || (off >= 0 && ix != off))
	     ret_elem = dk_alloc_box (0, DV_DB_NULL);
	   else if (elem_entity)
	     {
	       ret_elem = soap_box_xml_entity_validating_1 (elem_entity, err_ret, a_type, 0, ctx, &a_sqt);
	       elem_entity = xml_find_exact_child (entity, a_name, inx++);
	     }
	   if (*err_ret)
	     goto error;
	   dk_set_push (&ret_set, ret_elem);
	   ix++;
	 }
     }
   else
     {
       /* scalar type */
       caddr_t value;
       if (!proposed_type || schema_tree)
	 SOAP_VALIDATE_ERROR (("22023", "SV016", "Can't find definition of type '%s'", type_ref));

       if (DV_TYPE_OF (entity) == DV_ARRAY_OF_POINTER)
	 {
	   if (BOX_ELEMENTS (entity) == 1)
	     {
	       int try_convert;
	       caddr_t attachment = soap_find_attachment (entity, ctx, &try_convert);
	       /* we'll return what we found */
	       if (attachment)
		 {
		   if (!try_convert)
		     return box_copy (attachment);
		   value = attachment;
		   goto convert_value;
		 }

	       if (IS_STRING_DTP (proposed_type))
		 return box_dv_short_string ("");
	       else if (IS_WIDE_STRING_DTP (proposed_type))
		 {
		   caddr_t wide_ret = dk_alloc_box (sizeof(wchar_t), DV_WIDE);
		   wide_ret [0] = L'\0';
		   return wide_ret;
		 }
	       return box_cast (NULL, NULL, NULL, DV_DB_NULL);
	     }


	   if (xml_find_child (entity, NULL, NULL, 0, NULL) || BOX_ELEMENTS (entity) != 2)
	     SOAP_VALIDATE_ERROR (("22023", "SV017", "Can't find value for type '%s'", type_ref));
	   value = entity[1];
	 }
       else
	 {
	   value = (caddr_t) entity;
	   if (!value)
	     SOAP_VALIDATE_ERROR (("22023", "SV018", "Can't find value for type '%s'", type_ref));
	 }
convert_value:
       if (proposed_type == DV_SHORT_INT)
	 { /*FIXME: the value if all are digits must be converted to a number */
	   if (!strcmp ((caddr_t) value, "yes") || !strcmp ((caddr_t) value, "1") ||
	       !strcmp ((caddr_t) value, "true"))
	     ret = box_num (1);
	   else if (!strcmp ((caddr_t) value, "no") || !strcmp ((caddr_t) value, "0") ||
	       !strcmp ((caddr_t) value, "false"))
	     ret = box_num_nonull (0);
	   else
	     SOAP_VALIDATE_ERROR (("22023", "SV019", "Value for type '%s' must be true or false", type_ref))
	 }
       else if (proposed_type == DV_DATETIME)
	 {
           caddr_t err_msg = NULL;
	   ret = dk_alloc_box (DT_LENGTH, DV_DATETIME);
           iso8601_string_to_datetime_dt ((caddr_t) value, ret, &err_msg);
           if (NULL != err_msg)
             {
               dk_free_box (ret);
	       SOAP_VALIDATE_ERROR_2 (("22023", "SV020", "Value for type '%s' can't be converted: %.500s", type_ref, err_msg), err_msg);
             }
	 }
       else if (proposed_type == DV_BIN)
	 {
	   caddr_t tmp = box_copy ((caddr_t) value);
	   size_t len, blen = box_length (tmp);
	   len = decode_base64(tmp, tmp + blen);
	   ret = dk_alloc_box (len, DV_BIN);
	   memcpy (ret, tmp, len);
	   dk_free_box(tmp);
	 }
       else
	 {
	   caddr_t wide = box_utf8_as_wide_char (value, NULL, box_length (value) - 1, 0, DV_WIDE);
	   /* Special cases for datatypes:
	      float is mapped to double to increase the precision,
	      string is mapped to the nvarchar for wide characters support */
	   if (proposed_type == DV_SINGLE_FLOAT)
	     proposed_type = DV_DOUBLE_FLOAT;
	   else if (DV_SHORT_STRING == proposed_type)
	     proposed_type = DV_WIDE;
	   ret = box_cast_to (NULL, wide, DV_WIDE, proposed_type,
	       NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err_ret);
	   dk_free_box (wide);
	   if (*err_ret)
	     goto error;
	   /* special case, NULL w/o error must be 0 */
	   if (!ret && proposed_type == DV_LONG_INT)
	     ret = box_num_nonull (0);
	 }
     }

   if (ret_set)
     {
       if (!ret)
	 {
	   ret = list_to_array (dk_set_nreverse (ret_set));
	   ret_set = NULL;
	 }
       else
	 SOAP_VALIDATE_ERROR (("22023", "SV021", "Unknown error"))
     }
   return ret;

error:
   dk_free_tree (ret);
   dk_free_tree (list_to_array (ret_set));
   if (!*err_ret)
     {
       if (!ctx->error_message)
	 *err_ret = srv_make_new_error ("22023", "SV022",
	     "The XML does not validate according to the parameter schema %s", type_ref);
       else
	 {
	   *err_ret = ctx->error_message;
	   ctx->error_message = NULL;
	 }
     }
   return NULL;
}


static caddr_t
bif_soap_box_xml_entity_validating (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_box_xml_entity_validating";
  caddr_t *entity_1 = (caddr_t *) bif_arg (qst, args, 0, szMe);
  caddr_t type_name = bif_string_arg (qst, args, 1, szMe);
  char *ret = NULL;
  ptrlong elem = 0;
  caddr_t *entity = NULL;
  soap_ctx_t ctx;
  sql_class_t *udt = NULL;
  sql_type_t sqt;
  query_instance_t *qi = (query_instance_t *) qst;

  if (DV_XML_ENTITY == DV_TYPE_OF (entity_1))
    {
      xml_tree_ent_t *xe = (xml_tree_ent_t*) entity_1;
      if (!XE_IS_TREE(xe))
	{
	  *err_ret = srv_make_new_error ("22023", "SV080", "Function '%s' can process only XML tree entities, not e.g. XPER entities", szMe);
	  return NULL;
	}
      if (XTE_HAS_PARENT(xe))
	entity = (caddr_t *)(xe->xte_current);
      else
	{ /* Search for data inside the root */
	  size_t idx;
	  for (idx = 1; idx < BOX_ELEMENTS(xe->xte_current); idx++)
	    {
	      caddr_t *candidate = (caddr_t *)(xe->xte_current[idx]);
	      if (!ARRAYP (candidate))
		continue;
	      if (' ' == XTE_HEAD_NAME (XTE_HEAD (candidate))[0])
		continue;
	      if (NULL == entity)
		{
		  entity = candidate;
		  continue;
		}
	      if (ARRAYP (entity))
		{
		  *err_ret = srv_make_new_error ("22023", "SV067", "The XML fragment is not a valid XML document: it contains more than one top level element");
		  return NULL;
		}
	    }
	  if (NULL == entity)
	    {
	      *err_ret = srv_make_new_error ("22023", "SV068", "The XML fragment is not a valid XML document: it does not contain top level element");
	      return NULL;
	    }
 	}
   }

  memset (&sqt, 0, sizeof (sql_type_t));

  /* fallback to old behaviour */
  if (!entity)
    entity = (caddr_t *) bif_array_arg (qst, args, 0, szMe);

  if (BOX_ELEMENTS (args) > 2)
    elem = bif_long_arg (qst, args, 2, szMe);
  if (BOX_ELEMENTS (args) > 3)
    {
      udt = bif_udt_arg (qst, args, 3, szMe);
      sqt.sqt_class = udt;
      sqt.sqt_dtp = DV_OBJECT;
    }

  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.soap_version = 11;
  ctx.dks_esc_compat = 0 /*1*/;
  ctx.req_resp_namespace = NULL;
  ctx.qst = qst;
  ctx.cli = qi->qi_client;



  if (uname__root == XML_ELEMENT_NAME (entity))
    {
      caddr_t *entity_1 = xml_find_exact_child (entity, NULL, 0);
      if (entity_1 && !xml_find_exact_child (entity, NULL, 1))
	entity = entity_1;
    }
  ret = soap_box_xml_entity_validating_1 (entity, err_ret, type_name, (int) elem, &ctx, &sqt);
  return ret;
}

#define SES_PRINT_CHAR(ses, c) session_buffered_write_char (c, ses)


static long
soap_box_mda_size (caddr_t box, char *delim, caddr_t *err_ret, char * dim, int dim_len, soap_ctx_t * ctx)
{
  long size = delim ? atoi (delim) : 0;
  long child;
  char tmp[10];
  if (!ARRAYP(box)
      || (ARRAYP(box) && size > 0 && size != BOX_ELEMENTS (box))
      || (!size && ARRAYP(box) && ! BOX_ELEMENTS (box)))
    return -1;
  if (!size)
    size = BOX_ELEMENTS (box);
  delim = strchr (delim, ',');
  if (delim) delim++;
  snprintf (tmp, sizeof (tmp), "%ld%s", size, delim ? (ctx->soap_version <= 11 ? "," : " ") : "");
  strncat_size_ck (dim, tmp, dim_len - strlen (dim) - 1, dim_len);
  if (delim)
    {
      child = soap_box_mda_size (((caddr_t *)box)[0], delim, err_ret, dim, dim_len, ctx);
      if (child > 0)
	size *= child;
      else
	size = -1;
    }
  return size;
}

static void
soap_box_array_to_mda (caddr_t box, caddr_t *new_box, char *delim, char *dim, int dim_len, caddr_t *err_ret, long *ix, soap_ctx_t * ctx)
{
  long inx, len, target_size;
  if (!*new_box)
    {
      long n_elm = soap_box_mda_size (box, delim, err_ret, dim, dim_len, ctx);
      if (n_elm < 0)
	return;
      *new_box = dk_alloc_box (n_elm * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    }
  target_size = BOX_ELEMENTS (*new_box);
  len = BOX_ELEMENTS (box);
  delim = strchr (delim, ',');
  if (delim) delim++;
  for (inx = 0; inx < len; inx++)
    {
      if (delim)
	soap_box_array_to_mda (((caddr_t *)box)[inx], new_box, delim, dim, dim_len, err_ret, ix, ctx);
      else
	{
	  if (target_size - 1 < *ix)
	    {
	      dk_free_box (*new_box);
	      *new_box = NULL;
	      return;
	    }
	  ((caddr_t *)(*new_box))[(*ix)++] = ((caddr_t *)box)[inx];
	}
    }
}

static int
soap_print_scalar_value (dtp_t proposed_type, caddr_t value, dk_session_t *ses, soap_ctx_t * ctx, caddr_t *err_ret)
{
/*  int use_escapes = ctx->use_escapes;*/
  if (proposed_type == DV_SHORT_INT)
    {
      if (DV_TYPE_OF (value) == DV_LONG_INT || DV_TYPE_OF (value) ==  DV_SHORT_INT)
	{
	  if (unbox (value) == 1)
	    SES_PRINT (ses, "1"); /*was yes & no*/
	  else if (unbox (value) == 0)
	    SES_PRINT (ses, "0");
	  else
	    SOAP_VALIDATE_ERROR (("22023", "SV052", "Value for xsi:boolean must be integer of 0 or 1"));
	}
      else
	{
	  if (DV_TYPE_OF (value) != DV_ARRAY_OF_POINTER ||
	      BOX_ELEMENTS (value) != 2 ||
	      DV_TYPE_OF (((caddr_t *)value)[0]) != DV_COMPOSITE ||
	      DV_TYPE_OF (((caddr_t *)value)[1]) != DV_LONG_INT)
	    SOAP_VALIDATE_ERROR (("22023", "SV054", "Value for xsi:boolean must be soap_boolean"));
	  if (unbox (((caddr_t *)value)[1]) == 1)
	    SES_PRINT (ses, "1"); /*was yes & no*/
	  else if (unbox (((caddr_t *)value)[1]) == 0)
	    SES_PRINT (ses, "0");
	  else
	    SOAP_VALIDATE_ERROR (("22023", "SV053", "Value for xsi:boolean must be soap_boolean of 0 or 1"));
	}
    }
  else if (proposed_type == DV_DATETIME)
    {
      char temp[100];
      if (DV_TYPE_OF (value) != DV_DATETIME)
	SOAP_VALIDATE_ERROR (("22023", "SV056", "Value for xsi:dateTime must be of datetime PL type"));
      dt_to_iso8601_string (value, temp, sizeof (temp));
      SES_PRINT (ses, temp);
    }
  else if (proposed_type == DV_SINGLE_FLOAT
      || proposed_type == DV_DOUBLE_FLOAT)
    {
      char tmp[500];
      if (DV_TYPE_OF (value) == DV_SINGLE_FLOAT)
	snprintf (tmp, sizeof (tmp), "%.16g", unbox_float (value));
      else if (DV_TYPE_OF (value) == DV_DOUBLE_FLOAT)
	snprintf (tmp, sizeof (tmp), "%.16g", unbox_double (value));
      else if (DV_TYPE_OF (value) == DV_NUMERIC)
	numeric_to_string ((numeric_t) value, tmp, sizeof (tmp));
      else
	goto error;
      if (!stricmp(tmp, "nan"))
	strcpy_ck (tmp, "NaN");
      else if (!stricmp(tmp, "inf"))
	strcpy_ck (tmp, "INF");
      else if (!stricmp(tmp, "-inf"))
	strcpy_ck (tmp, "-INF");
      SES_PRINT (ses, tmp);
    }
  else if (proposed_type == DV_BIN)
    {
      caddr_t src, dest, bh_src = NULL;
      size_t len;


      if (DV_TYPE_OF (value) != DV_BIN && !DV_STRINGP (value) && !DV_WIDESTRINGP (value) && !IS_BLOB_HANDLE_DTP (DV_TYPE_OF (value)))
	SOAP_VALIDATE_ERROR (("22023", "SV092", "Non expected type of PL value : (%d) expected (%d)",
	      DV_TYPE_OF (value), proposed_type));

      if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (value)))
	{
	  blob_handle_t * bh = (blob_handle_t *) value;
	  char in_buf[3*4096], out_buf[(6*4096)+1];
	  int readed, to_read, to_read_len;
	  dk_session_t * bh_ses;
	  boxint limit = unbox(con_soap_get (ctx->cli, con_soap_blob_limit_name));

	  if (bh->bh_length > MIME_POST_LIMIT && !limit)
	    SOAP_VALIDATE_ERROR (("22023", "SV089", "Blob longer than maximum string length not allowed"));

	  if (limit < 0 || limit >= MIME_POST_LIMIT)
	    SOAP_VALIDATE_ERROR (("22023", "SV089", "Invalid Blob limit supplied"));

	  if (bh->bh_ask_from_client)
	    SOAP_VALIDATE_ERROR (("22023", "SV091", "BLOB submitted by client as SQL_DATA_AT_EXEC cannot be converted into anything."));
	  if (limit > 0 && limit < bh->bh_length)
	    {
	      bh_src = blob_subseq (ctx->cli->cli_trx, value, 0, limit);
	      src = bh_src;
	      goto do_string;
	    }

	  bh_ses = strses_allocate ();
	  strses_enable_paging (bh_ses, http_ses_size);
	  to_read = bh_write_out (ctx->cli->cli_trx, bh, bh_ses);
	  to_read_len = sizeof (in_buf);
	  do
	    {
	      if (to_read < to_read_len)
		to_read_len = to_read;
	      CATCH_READ_FAIL (bh_ses)
		{
		  readed = session_buffered_read (bh_ses, in_buf, to_read_len);
		}
	      FAILED
		{
		   dk_free_box ((box_t) bh_ses);
		   SOAP_VALIDATE_ERROR (("22023", "SV092", "Cannot encode a BLOB as base64 binary."));
		}
	      END_READ_FAIL (bh_ses);
	      to_read -= readed;
	      if (readed > 0)
		{
		  len = xenc_encode_base64 ((char *)in_buf, (char *)out_buf, readed);
		  out_buf [len] = 0;
		  SES_PRINT (ses, out_buf);
		}
	    }
	  while (to_read > 0);
	  dk_free_box ((box_t) bh_ses);
	}
      else
	{
	   src = (caddr_t) value;
do_string:
	   len = box_length(src);

	   if (DV_TYPE_OF (value) != DV_BIN)
	     len--;

	   if (((len*2)+1) >= MIME_POST_LIMIT)
	     {
	       SOAP_VALIDATE_ERROR (("22023", "SV089", "Too long string value"));
	     }

	   dest = dk_alloc_box (len * 2 + 1, DV_SHORT_STRING);
	   len = xenc_encode_base64 ((char *)src, (char *)dest, len);
	   *(dest+len) = 0;
	   SES_PRINT (ses, dest);
	   dk_free_box (dest);
	}
      dk_free_box (bh_src);
    }
  else
    {
      caddr_t wide;
      caddr_t bh_result = NULL;
      if ((DV_STRINGP (value) || DV_WIDESTRINGP (value)))
	{
	  if (!(IS_STRING_DTP (proposed_type) || IS_WIDE_STRING_DTP (proposed_type)))
	    SOAP_VALIDATE_ERROR (("22023", "SV057", "Non expected string value"));
	}
      else if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (value)))
	{
	  blob_handle_t * bh = (blob_handle_t *) value;

	  if (!(IS_STRING_DTP (proposed_type) || IS_WIDE_STRING_DTP (proposed_type)))
	    SOAP_VALIDATE_ERROR (("22023", "SV090", "Non expected string value"));

	  if (bh->bh_length > MIME_POST_LIMIT)
	    SOAP_VALIDATE_ERROR (("22023", "SV089", "Blob longer than maximum string length not allowed"));

	  if (bh->bh_ask_from_client)
	    SOAP_VALIDATE_ERROR (("22023", "SV091", "BLOB submitted by client as SQL_DATA_AT_EXEC cannot be converted into anything."));
	  bh_result = blob_to_string (ctx->cli->cli_trx, value);
	  value = bh_result;
	}
      else if (proposed_type != DV_TYPE_OF (value))
	SOAP_VALIDATE_ERROR (("22023", "SV058", "Non expected type of PL value : (%d) expected (%d)",
	      DV_TYPE_OF (value), proposed_type));
      wide = box_cast_to (NULL, value, DV_TYPE_OF (value), DV_WIDE,
	  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err_ret);
      if (*err_ret)
	{
	  dk_free_box (bh_result);
	  goto error;
	}
      if (wide)
	{
	  dks_wide_esc_write (ses, (wchar_t *)wide, box_length (wide) / sizeof (wchar_t) - 1, CHARSET_UTF8, DKS_ESC_PTEXT | (ctx->dks_esc_compat));
	  dk_free_box (wide);
	}
      dk_free_box (bh_result);
    }
  return 1;
error:
   if (err_ret && !*err_ret && ctx->error_message)
     {
       *err_ret = ctx->error_message;
       ctx->error_message = NULL;
     }
  return 0;
}

static int
soap_print_attrs_validating (caddr_t *box, caddr_t *extension, dk_session_t *ses, soap_ctx_t * ctx, caddr_t *err_ret)
{
  caddr_t *e_attr_ptr;
  int attr_inx = 0;
  dk_set_t attrs = NULL;
  dk_set_t local_ns = NULL;

  ctx->attr = 1; /* printing an attribute */

  e_attr_ptr = xml_find_schema_child (extension, "attribute", attr_inx ++);
  while (e_attr_ptr)
    {
      int attr_val_inx = 0;
      caddr_t attr_name;
      caddr_t attr_type;
      caddr_t attr_use;
      caddr_t attr_ref = xml_find_schema_attribute (e_attr_ptr, "ref");
      caddr_t attr_value;
      caddr_t attr_box_name = NULL;
      char * attr_ns = NULL;
      caddr_t tns = NULL;

      if (attr_ref)
	{
	  int i = 0;
	  soap_wsdl_ns_t * ns;
	  soap_box_xev_get_type (attr_ref, NULL, (caddr_t *) &e_attr_ptr, -1, 1, 0);
	  if (!e_attr_ptr)
	    SOAP_VALIDATE_ERROR (("22023", "SV069", "A reference to attribute '%s' was not found", attr_ref))
	  tns = xml_find_schema_attribute (e_attr_ptr, "targetNamespace");
	  if (tns)
	    {
	      DO_SET (soap_wsdl_ns_t *, elm, &(ctx->ns_set))
		{
		  if (!strcmp (elm->ns_uri, tns))
		    {
		      attr_ns = elm->ns_pref;
		      tns = NULL;
		      break;
		    }
		  i++;
		}
	      END_DO_SET ();

	      if (!attr_ns)
		{
		  ns = (soap_wsdl_ns_t *) dk_alloc (sizeof(soap_wsdl_ns_t));
		  memset(ns, 0, sizeof(soap_wsdl_ns_t));
		  ns->ns_uri = box_dv_short_string(tns);
		  snprintf (ns->ns_pref, sizeof (ns->ns_pref), "ns%d", i);
		  dk_set_push (&(ctx->ns_set), (void *) ns);
		  dk_set_push (&local_ns, (void *) ns);
		  attr_ns = ns->ns_pref;
		}
	    }
	}

      attr_name = xml_find_schema_attribute (e_attr_ptr, "name");
      attr_type = xml_find_schema_attribute (e_attr_ptr, "type");
      attr_use = xml_find_schema_attribute (e_attr_ptr, "use");

      if (!attr_use)
	attr_use = "optional";
      if (DV_TYPE_OF (box) == DV_ARRAY_OF_POINTER)
	{
	  attr_box_name = box_dv_short_string (extract_last_xml_name_part (attr_name));
	  attr_val_inx = find_index_to_vector (attr_box_name, (caddr_t) box, BOX_ELEMENTS (box),
	      DV_ARRAY_OF_POINTER, 0, 2, "soap_print_box_validating");
	  dk_free_box (attr_box_name);
	}
      if (!strcmp (attr_use, "required") && !attr_val_inx)
	SOAP_VALIDATE_ERROR (("22023", "SV060", "A required attribute '%s' can't be found", attr_name))
      else if (!strcmp (attr_use, "prohibited") && attr_val_inx)
	SOAP_VALIDATE_ERROR (("22023", "SV061", "A prohibited attribute '%s' was found", attr_name))
      if (attr_val_inx)
	{
	  caddr_t schema_tree = NULL;
	  dtp_t proposed_type = 0;
	  soap_box_xev_get_type (attr_type, &proposed_type, (caddr_t *) &schema_tree, 0, 0, 0);

	  if (!proposed_type && !schema_tree)
	    SOAP_VALIDATE_ERROR (("22023", "SV062", "Can't find type mapping of an attribute '%s' of type '%s'", attr_name, attr_type))

          if (schema_tree)
            {
	      caddr_t new_schema_tree = NULL;
	      caddr_t *e_ptr = xml_find_schema_child ((caddr_t *) schema_tree, "simpleContent", 0);
	      caddr_t type_base;

	      if (NULL == e_ptr)
	        SOAP_VALIDATE_ERROR (("22023", "SV081", "Can't find type mapping of an attribute '%s' of type '%s'", attr_name, attr_type))

	      e_ptr = xml_find_schema_child (e_ptr, "restriction", 0);

	      if (NULL == e_ptr)
	        SOAP_VALIDATE_ERROR (("22023", "SV082", "An attribute '%s' of type '%s' must be based on restriction", attr_name, attr_type))

	      type_base = xml_find_schema_attribute (e_ptr, "base");

	      if (NULL == type_base)
	        SOAP_VALIDATE_ERROR (("22023", "SV083", "Cannot resolve base type of attribute '%s' of type '%s', based on restriction", attr_name, attr_type))

	      soap_box_xev_get_type (type_base, &proposed_type, (caddr_t *) &new_schema_tree, 0, 0, 0);

	      if (!proposed_type)
	        SOAP_VALIDATE_ERROR (("22023", "SV084", "Can't find type mapping of the base type for an attribute '%s' of type '%s'", attr_name, attr_type))
            }

	  if (schema_tree)
	    {
	      caddr_t new_box = box[attr_val_inx];
	      if (DV_TYPE_OF (new_box) == DV_DB_NULL)
		attr_value = box[attr_val_inx];
	      else if (ARRAYP (new_box)
		  	&& BOX_ELEMENTS (new_box) == 3
			&& DV_TYPE_OF (((caddr_t *)new_box)[0]) == DV_COMPOSITE
			&& DV_STRINGP (((caddr_t **)new_box)[1])
		      )
		attr_value = (caddr_t)((caddr_t **)new_box)[2];
	      else
	       SOAP_VALIDATE_ERROR (("22023", "SV085", "Cannot map PL value to type %s", attr_type))
	    }
	  else
	    attr_value = box[attr_val_inx];

	  if (DV_TYPE_OF (attr_value) == DV_DB_NULL)
	    SOAP_VALIDATE_ERROR (("22023", "SV063", "Value for attribute '%s' of type '%s' can't be DB_NULL", attr_name, attr_type))
	  SES_PRINT (ses, " ");
	  if (attr_ns)
	    {
	      if (tns)
		{
		  SES_PRINT (ses, "xmlns:");
		  SES_PRINT (ses, attr_ns);
		  SES_PRINT (ses, "='");
		  SES_PRINT (ses, tns);
		  SES_PRINT (ses, "' ");
		}

	      SES_PRINT (ses, attr_ns);
	      SES_PRINT (ses, ":");
	    }
	  SES_PRINT (ses, attr_name);
	  SES_PRINT (ses, "='");
	  if (!soap_print_scalar_value (proposed_type, attr_value, ses, ctx, err_ret))
	    goto error;
	  SES_PRINT (ses, "' ");
	}
      e_attr_ptr = xml_find_schema_child (extension, "attribute", attr_inx ++);
    }
  ctx->attr = 0;
  DO_SET (soap_wsdl_ns_t *, elm, &local_ns)
    {
      dk_set_delete (&(ctx->ns_set), (void *) elm);
      dk_free_box (elm->ns_uri);
      dk_free (elm, sizeof (soap_wsdl_ns_t));
    }
  END_DO_SET();
  dk_set_free (local_ns);
  return 1;

error:
   if (err_ret && !*err_ret && ctx->error_message)
     {
       *err_ret = ctx->error_message;
       ctx->error_message = NULL;
     }
  ctx->attr = 0;
  dk_free_tree (list_to_array (attrs));
  dk_set_free (local_ns); /* the namespace will be freed in global context */
  return 0;
}

static int
soap_print_xml_entity (caddr_t box, dk_session_t *ses, client_connection_t * cli)
{
  if (DV_TYPE_OF (box) == DV_XML_ENTITY)
    {
      /*XXX: the Qi issue must be fixed */
      xml_entity_t * xte = (xml_entity_t *)box;
      wcharset_t *charset = cli->cli_charset;
      query_instance_t *qi = xte->xe_doc.xd->xd_qi, qi_void;

      memset (&qi_void, 0, sizeof (query_instance_t));
      qi_void.qi_client = cli;
      cli->cli_charset = CHARSET_UTF8;
      xte->xe_doc.xd->xd_qi = &qi_void;
      xte->xe_doc.xtd->xout_omit_xml_declaration = 1;
      (xte)->_->xe_serialize (xte, ses);
      xte->xe_doc.xd->xd_qi = qi;
      cli->cli_charset = charset;
      return 1;
    }
  return 0;
}

static void soap_ensure_xmlns (dk_session_t * out, caddr_t val, soap_ctx_t * ctx)
{
  char * sep = val ? strrchr (val, ':') : NULL;
  char * ns;
  caddr_t tns;
  if (!val || !sep)
    return;
  tns = box_dv_short_nchars (val, (sep - val));
  ns = soap_wsdl_get_ns_prefix (&(ctx->ns_set), tns);
  if (!ns)
    {
      SES_PRINT (out, " xmlns:qn='");
      SES_PRINT (out, tns);
      SES_PRINT (out, "'");
    }
  dk_free_box (tns);
}

static int
soap_print_qname_val (dk_session_t * out, dtp_t proposed_type, caddr_t val, soap_ctx_t * ctx, caddr_t * err_ret)
{
  char * sep;

  if (!val)
    return 1;

  if (!DV_STRINGP (val) && !DV_WIDESTRINGP (val))
    SOAP_VALIDATE_ERROR (("22023", "SV087", "Non expected QName value"));

  sep = strrchr (val, ':');
  if (!sep)
    {
      if (!soap_print_scalar_value (proposed_type, val, out, ctx, err_ret))
	SOAP_VALIDATE_ERROR (("22023", "SV088", "Non expected QName value"));
    }
  else
    {
      caddr_t tns = box_dv_short_nchars (val, (sep - val));
      char *ns = soap_wsdl_get_ns_prefix (&(ctx->ns_set), tns);

      if (ns)
	{
	  SES_PRINT (out, ns);
	}
      else
	{
	  SES_PRINT (out, "qn");
	}
      SES_PRINT (out, sep);
      dk_free_box (tns);
    }

  return 1;

error:
   if (err_ret && !*err_ret && ctx->error_message)
     {
       *err_ret = ctx->error_message;
       ctx->error_message = NULL;
     }
  return 0;
}

static int
soap_check_xsd_restriction (caddr_t * restriction, caddr_t box, soap_ctx_t *ctx)
{
  return 1;
}

static int
soap_same_ns (const char * str1, const char * str2)
{
  char * p1, * p2;
  if (!str1 || !str2 || !(p1 = strrchr (str1, ':')) || !(p2 = strrchr (str2, ':')))
    return 0;
  if ((p1 - str1) != (p2 - str2))
    return 0;
  if (!strncmp (str1, str2, p1 - str1))
    return 1;
  return 0;
}

static void
soap_print_tag (const char * tag, dk_session_t *ses, caddr_t type_ref, soap_ctx_t * ctx, int closing_1,
    int elem, int qualified, caddr_t ref_type)
{
  int closing = (0 == closing_1 ? 0 : 1);
  int short_form = (closing_1 < 0 ? 1 : 0);

  if (!closing)
    SES_PRINT_CHAR (ses, '<');
  else if (short_form)
    SES_PRINT (ses, " />");
  else
    SES_PRINT (ses, "</");

  if (short_form && (!closing || !ctx->literal || !qualified))
    return;

  if (!ctx->literal) /* RPC encoded */
    {
      if (ctx->req_resp_namespace && qualified)
	SES_PRINT (ses, "h:");
      SES_PRINT (ses, tag);
      if (ctx->req_resp_namespace && !closing && qualified)
	{
	  SES_PRINT (ses, " xmlns:h='");
	  SES_PRINT (ses, ctx->req_resp_namespace);
	  SES_PRINT (ses, "'");
	}
    }
  else
    {
      if (!qualified)
        SES_PRINT (ses, tag);
      else
	{
	  char *colon = strrchr (type_ref, ':');
	  int is_elem = elem, is_ref_elem = 1; /* ref always is element */
	  char *ns = soap_wsdl_ns_prefix (type_ref, &(ctx->types_set), NULL, &is_elem);
	  char *ns_ref = ref_type ? soap_wsdl_ns_prefix (ref_type, &(ctx->types_set), NULL, &is_ref_elem) : NULL;
	  caddr_t elem_def = NULL;
	  char *top_ns;

	  if (ns && closing)
	    {
	      /*pop & delete*/
	      caddr_t elm = (caddr_t) dk_set_pop (&ctx->ns);
	      dk_free_box (elm);
	      if (is_elem)
		{
		  elm = (caddr_t) dk_set_pop (&ctx->ns);
		  dk_free_box (elm);
		}
	      if (ns_ref)
		{
		  elm = (caddr_t) dk_set_pop (&ctx->ns);
		  dk_free_box (elm);
		}
	    }

	  if (short_form) /* tag was closed */
	    return;

	  top_ns = ctx->ns ? (char *)(ctx->ns->data) : NULL;

	  if (ns && !closing)
	    {
	      char *ns1 = NULL;
	      dk_set_push (&ctx->ns, box_dv_short_string (ns));
	      if (is_elem) /* push NS for child, type of element */
		{
		  soap_box_xev_get_type (type_ref, NULL, &elem_def, 1, 1, 0);
		  if (elem_def)
		    {
		      int chil_is_elem = 0;
		      caddr_t chil_type = xml_find_schema_attribute ((caddr_t *)(elem_def), "type");
		      ns1 = soap_wsdl_ns_prefix (chil_type, &(ctx->types_set), NULL, &chil_is_elem);
		    }
		  if (!ns1)
		    ns1 = ns;
		  dk_set_push (&ctx->ns, box_dv_short_string (ns1));
		}
	      if (ns_ref)
		{
		  dk_set_push (&ctx->ns, box_dv_short_string (ns_ref));
		}
	    }

	  if (top_ns)
	    {
	      if (strlen (top_ns))
		{
		  SES_PRINT (ses, top_ns);
		  SES_PRINT (ses, ":");
		}
	    }
	  else if (ns)
	    {
	      SES_PRINT (ses, ns);
	      SES_PRINT (ses, ":");
	    }

	  if (is_elem && colon)
	    SES_PRINT (ses, colon + 1);
	  else
	    SES_PRINT (ses, tag);

	  if (!ns && !top_ns && !closing && ctx->custom_schema && ctx->req_resp_namespace)
	    {
	      SES_PRINT (ses, " xmlns=\"");
	      SES_PRINT (ses, ctx->req_resp_namespace);
	      SES_PRINT (ses, "\"");
	      ctx->req_resp_namespace = NULL;
	    }
	}
    }

  if (ctx->must_understand)
    {
      SES_PRINT (ses, " SOAP:mustUnderstand='1'");
      ctx->must_understand = 0;
    }

  if (NULL != ctx->soap_actor)
    {
      SES_PRINT (ses, " SOAP:actor='");
      SES_PRINT (ses, ctx->soap_actor);
      SES_PRINT (ses, "'");
      ctx->soap_actor = NULL;
    }

  if (closing)
    SES_PRINT_CHAR (ses, '>');
}

static void
soap_print_box_validating (caddr_t box, const char * tag, dk_session_t *ses,
    caddr_t *err_ret, caddr_t type_ref, soap_ctx_t * ctx, int elem, int qualified, sql_type_t * check_sqt)
{
   caddr_t type_name;
   caddr_t *e_ptr;
   caddr_t *schema_tree = NULL, new_box = NULL;
   dtp_t proposed_type;
   char temp[1024];
   int is_in_schema;
   sql_class_t *check_udt = check_sqt ? check_sqt->sqt_class : NULL;
   sql_class_t *udt = NULL;
   caddr_t udi_ref = NULL;
   caddr_t udi = NULL;
   int allow_b64 = 0;

   if (ctx->soap_version < 1 || ctx->soap_version > 12)
     SOAP_VALIDATE_ERROR (("22023", "SV000", "Unsupported SOAP version %d", ctx->soap_version))

   if (DV_STRINGP(type_ref))
     {
       /* void type , simply return , no action */
       if (0 == stricmp (type_ref, SOAP_VOID_TYPE))
	 return;
       else if (soap_get_run_time_schema (ctx, type_ref, (caddr_t *)&schema_tree))
	 { /* run-time schema type is used and it's included in the result */
	   if (DV_TYPE_OF(box) == DV_XML_ENTITY)
	     {
	       *err_ret = soap_print_box (box, ses, NULL, ctx->soap_version, NULL, 0, ctx);
	       return;
	     }
	 }
       else if (0 == stricmp (type_ref, SOAP_ANY_TYPE)) /* any type, revert to old serializer */
	 {
	   dtp_t dtp = DV_TYPE_OF(box);
	   soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
	   /* TBD: make more consistent the below, not lay on the logic under cover
	      in this cases the soap_print_box do not print the closing >
	    */
	   if (dtp == DV_XML_ENTITY || dtp == DV_OBJECT || dtp == DV_REFERENCE)
             SES_PRINT (ses, ">");
	   *err_ret = soap_print_box (box, ses, NULL, ctx->soap_version, NULL, 0, ctx);
	   if (DV_TYPE_OF(box) != DV_DB_NULL) /* tag is closed in soap_print_box */
	     soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, NULL);
	   return;
	 }
       else if (type_ref && !strcmp (type_ref, SOAP_XML_TYPE)) /* any element, raw XML */
	 {
	   if (DV_TYPE_OF(box) == DV_XML_ENTITY)
	     *err_ret = soap_print_box (box, ses, NULL, ctx->soap_version, NULL, 0, ctx);
	   else
	     *err_ret =
		 srv_make_new_error ("22023", "SV073", "PL value should be an XML entity, when type is any");
	   return;
	 }
     }

   if (DV_TYPE_OF (box) == DV_OBJECT)
     {
       udi = box;
       udt = UDT_I_CLASS (udi);
     }
   else if (DV_TYPE_OF (box) == DV_REFERENCE)
     {
       udi_ref = box;
       udi = udo_find_object_by_ref (udi_ref);
       udt = UDT_I_CLASS (udi);
     }
   if (udt)
     {
       if (check_udt)
	 {
	   if (!udt_instance_of (udt, check_udt))
	     SOAP_VALIDATE_ERROR (("22023", "SV024", "The PL value (instance of '%s') is not an instance of '%s'",
		   udt->scl_name, check_udt->scl_name));
	 }
     }
   else
     {
       if (check_udt)
	 {
	   if (DV_TYPE_OF (box) != DV_DB_NULL)
	     SOAP_VALIDATE_ERROR (("22023", "SV025", "The PL value (%s) is not an instance of the user defined type '%s'", dv_type_title (DV_TYPE_OF (box)), check_udt->scl_name))
	   else
	     {
	       sql_type_t sqt;
	       sqt.sqt_class = check_udt;
	       type_name = type_ref = soap_sqt_to_soap_type (&sqt, check_udt->scl_soap_type, ctx->opts, NULL, NULL);
	       soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
#if 1
	       if (ctx->add_type)
		 {
		   snprintf (temp, sizeof (temp), " xsi:type='%s:%s'",
		       soap_wsdl_ns_prefix (type_ref, &(ctx->types_set), "wsdl", NULL),
		       extract_last_xml_name_part (type_name));
		   SES_PRINT (ses, temp);
		   if (ADD_CUSTOM_SCH == ctx->add_schema && type_ref)
		     {
		       char *colon = strrchr (type_ref, ':');
		       int off_c = (int)(colon - type_ref);
		       if (colon && off_c > 0)
			 {
			   snprintf (temp, sizeof (temp), " xmlns:wsdl='%*.*s'", off_c, off_c, type_ref);
			   SES_PRINT (ses, temp);
			 }
		     }
		   else if (ADD_ALL_SCH == ctx->add_schema)
		     {
		       SES_PRINT (ses, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'");
		       SES_PRINT (ses, " xmlns:wsdl='services.wsdl'");
		     }
		 }
#endif
	       SES_PRINT (ses, (ctx->soap_version == 1 ? " xsi:null='1'" : " xsi:nil='1'"));
	       soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
	       dk_free_box (type_name);
	       return;
	     }
	 }
     }

   /* binary and blobs cannot be produced by encode_base64, hence if result
      is expected to be b64 then we allow to set proposed type to DV_BIN
      which makes the encoding as b64 explicit */
   if (DV_TYPE_OF (box) == DV_BIN || IS_BLOB_HANDLE_DTP (DV_TYPE_OF (box)))
     allow_b64 = 1;

   if (!schema_tree || !ctx->custom_schema)
     soap_box_xev_get_type (type_ref, &proposed_type, (caddr_t *) &schema_tree, elem, 0, allow_b64);

   if ((!proposed_type && !schema_tree && !check_udt && !udt && !IS_ARRAY_SQTP(check_sqt)) || *err_ret)
     SOAP_VALIDATE_ERROR (("22023", "SV026", "Can't find schema definition for type '%s'", type_ref));

   type_name = xml_find_schema_attribute (schema_tree, "name");

   if (type_name && ARRAYP (schema_tree) && BOX_ELEMENTS (schema_tree) == 1) /* an empty element */
     {
       soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
       soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
       return;
     }

   if (NULL != (e_ptr = xml_find_schema_child (schema_tree, "complexContent", 0)))
     {
       caddr_t type_base;
       int elem_inx;
       int has_attrs = 0;
       caddr_t *extension;

       extension = xml_find_schema_child (e_ptr, "restriction", 0);
       if (!extension)
	 {
	   extension = xml_find_schema_child (e_ptr, "extension", 0);
	   if (extension && NULL != xml_find_schema_child (extension, "attribute", 0))
	     has_attrs = 1;
	 }
       e_ptr = extension;
       type_base = xml_find_schema_attribute (e_ptr, "base");

       if (type_base && (!strcmp (type_base, SOAP_ENC_SCHEMA11 ":Struct")
	     || xev_is_extension_to (type_base, SOAP_ENC_SCHEMA11 ":Struct", 0)))
	 { /* structure */
	   int inx = 0, is_choice = 0;
	   if (!tag)
	     SOAP_VALIDATE_ERROR (("22023", "SV027", "No element name given for an object of type '%s'", type_ref));
	   if (!type_name)
	     SOAP_VALIDATE_ERROR (("22023", "SV028", "Can't resolve name of type '%s'", type_ref));

	   soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);

	   if (DV_TYPE_OF (box) == DV_DB_NULL)
	     SES_PRINT (ses, (ctx->soap_version == 1 ? " xsi:null='1'" : " xsi:nil='1'"));
	   if (ctx->add_type)
	     {
	       if (ctx->soap_version <= 11)
		 {
		   snprintf (temp, sizeof (temp), " xsi:type='%s:%s'",
		       soap_wsdl_ns_prefix (type_ref, &(ctx->types_set), "wsdl", NULL),
		       extract_last_xml_name_part (type_name));
		 }
	       else if (ctx->soap_version == 12)
		 {
		   snprintf (temp, sizeof (temp), " xsi:type='%s:%s' SOAP-ENC:nodeType='struct'",
		       soap_wsdl_ns_prefix (type_ref, &(ctx->types_set), "wsdl", NULL),
		       extract_last_xml_name_part (type_name));
		 }
	       SES_PRINT (ses, temp);
	       if (ADD_CUSTOM_SCH == ctx->add_schema && type_ref)
		 {
		   char *colon = strrchr (type_ref, ':');
		   int off_c = (int) (colon - type_ref);
		   if (colon && off_c > 0)
		     {
		       snprintf (temp, sizeof (temp), " xmlns:wsdl='%*.*s'", off_c, off_c, type_ref);
		       SES_PRINT (ses, temp);
		     }
		 }
	       else if (ADD_ALL_SCH == ctx->add_schema)
		 {
		   SES_PRINT (ses, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'");
		   SES_PRINT (ses, " xmlns:wsdl='services.wsdl'");
		 }
	     }
	   if (DV_TYPE_OF (box) != DV_DB_NULL)
	     {
	       caddr_t *e_seq;
	       int n_opt = 0;

	       if (!udt && ((DV_TYPE_OF (box) != DV_ARRAY_OF_POINTER ||
		   BOX_ELEMENTS (box) % 2 != 0 ||
		   BOX_ELEMENTS (box) < 2 ||
		   (
		    BOX_ELEMENTS (box) > 2 &&
		    DV_TYPE_OF (((caddr_t *)box)[0]) != DV_COMPOSITE
		   )
		  )))
	        SOAP_VALIDATE_ERROR (("22023", "SV075",
		      "PL value for type '%s' needs an soap_struct array as instance", type_ref));

	       if (has_attrs)
		 {
		   if (udt || !soap_print_attrs_validating (((caddr_t **)box)[1], extension, ses,
			 ctx, err_ret))
		     goto error;
		 }
	       else if (!udt)
		 {
		   if (!DV_STRINGP (((caddr_t **)box)[1]))
	             SOAP_VALIDATE_ERROR (("22023", "SV029",
			   "PL value for type '%s' needs second element to be the name of type", type_ref));
		 }
	       SES_PRINT_CHAR (ses, '>');

	       do
		 {
		   int inx1, n_more;
		   caddr_t choice;
		   inx1 = 0; n_more = 0;

		   choice = xml_find_schema_attribute (e_ptr, "choice");
		   is_choice = choice ? atoi (choice) : 0;

		   if (*err_ret) /* ensure error handling on second, etc. loops */
		     goto error;

		   e_seq = xml_find_schema_child (e_ptr, "sequence", 0);
		   e_ptr = xml_find_schema_child (e_seq, "element", inx1++);
		   while (e_ptr)
		     {
		       sql_class_t *fld_udt = NULL;
		       sql_type_t *fld_sqt = NULL;
		       caddr_t elem_name = NULL, elem_type = NULL, elem_form = NULL, elem_ns = NULL;
		       caddr_t elem_entity = NULL;
		       caddr_t elem_box_name = NULL;
		       caddr_t a_nil, a_min, a_ref, a_max;
		       long n_nil, n_min, n_max, elem_qual;

		       /* occurrence indicators and nillable are to local declaration,
			not in the reference */
		       a_min = xml_find_schema_attribute (e_ptr, "minOccurs");
		       a_max = xml_find_schema_attribute (e_ptr, "maxOccurs");
		       a_nil = xml_find_schema_attribute (e_ptr, "nillable");

		       if (NULL != (a_ref = xml_find_schema_attribute (e_ptr, "ref")))
			 /* there can be reference to another element */
			 {
			   int is_elem = 1;
			   char * ns = soap_wsdl_ns_prefix (a_ref, &(ctx->types_set), NULL, &is_elem);
			   e_ptr = NULL;
			   soap_box_xev_get_type (a_ref, NULL, (caddr_t *) &e_ptr, 1, 1, 0);
			   if (!ns)
			     SOAP_VALIDATE_ERROR (("22023", "SV066",
			       "Can't resolve namespace of element '%s' of ref '%s'", elem_name, a_ref));
			   dk_set_push (&ctx->ns, box_dv_short_string (ns));
			 }
		       if (NULL != (elem_ns = xml_find_schema_attribute (e_ptr, "namespace")))
			 {
			   int is_elem = 0;
			   char * ns = soap_wsdl_ns_prefix (elem_ns, &(ctx->types_set), NULL, &is_elem);
			   if (!ns && !soap_same_ns (type_ref, elem_ns))
			     SOAP_VALIDATE_ERROR (("22023", "SV086",
			       "Can't resolve namespace of element '%s' of derived type '%s'", elem_name, elem_ns));
			   dk_set_push (&ctx->ns, box_dv_short_string (ns));
			 }
		       elem_name = xml_find_schema_attribute (e_ptr, "name");
		       elem_type = xml_find_schema_attribute (e_ptr, "type");
		       elem_form = xml_find_schema_attribute (e_ptr, "form");
		       elem_qual = qualified & (elem_form ? 0 != strcmp (elem_form, "unqualified") :
			   (ctx->literal ? 1 : 0));

		       if (!elem_type)
			 SOAP_VALIDATE_ERROR (("22023", "SV031",
			       "Can't resolve type of element '%s' of type '%s'", elem_name, type_ref));

		       n_nil = a_nil ? atoi (a_nil) : 0;
		       n_min = a_min ? atoi (a_min) : 1;

		       if (!a_max)
			 n_max = 1;
		       else if (!strcmp (a_max, "unbounded"))
			 n_max = LONG_MAX;
		       else
			 n_max = atol (a_max);

		       elem_box_name = box_dv_short_string (extract_last_xml_name_part (elem_name));
		       if (!udt)
			 {
			   elem_inx = find_index_to_vector (elem_box_name, box, BOX_ELEMENTS (box),
			       DV_ARRAY_OF_POINTER, 0, 2, "soap_print_box_validating");

			   if (elem_inx == 0 && (is_choice || 0 == n_min))
			     {
			       /* if element is not in the result */
			       dk_free_tree (elem_box_name);
			       n_opt ++;
			       goto next_loop;
			     }

			   elem_entity = ((caddr_t *)box)[elem_inx];
			   if (elem_inx == 0 /* elements can be in any order in the structure!
			       || find_index_to_vector (elem_box_name, box, BOX_ELEMENTS (box),
				 DV_ARRAY_OF_POINTER, elem_inx, 2, "soap_print_box_validating") */)
			     {
			       dk_free_tree (elem_box_name);
			       SOAP_VALIDATE_ERROR (("22023", "SV032",
				     "Can't resolve value of element '%s' of type '%s'", elem_name, type_ref));
			     }
			 }
		       else
			 {
			   sql_field_t *fld = NULL;
			   elem_inx = udt_find_field (udt->scl_member_map, elem_box_name);
			   if (elem_inx == -1)
			     {
			       dk_free_tree (elem_box_name);
			       SOAP_VALIDATE_ERROR (("22023", "SV033",
				     "Can't resolve value of element '%s' of type '%s'",
				     elem_name, udt->scl_name));
			     }
			   fld = udt->scl_member_map[elem_inx];
			   fld_udt = fld->sfl_sqt.sqt_class;
			   fld_sqt = &(fld->sfl_sqt);
			   QR_RESET_CTX
			     {
			       elem_entity = udt_member_observer (NULL, udi, fld, elem_inx);
			     }
			   QR_RESET_CODE
			     {
			       POP_QR_RESET;
			       dk_free_tree (elem_entity);
			       *err_ret = thr_get_error_code (THREAD_CURRENT_THREAD);
			       goto error;
			     }
			   END_QR_RESET;
			 }

		       /* skip printing of NULLs when element is not nillable and can be omitted */
		       if (0 == n_min && 0 == n_nil && DV_TYPE_OF (elem_entity) == DV_DB_NULL)
			 ;
		       else if (n_min > 0 && 0 == n_nil && DV_TYPE_OF (elem_entity) == DV_DB_NULL)
			 {
			   soap_print_tag (elem_name, ses, elem_type, ctx, 0,  0, elem_qual, NULL);
			   soap_print_tag (elem_name, ses, elem_type, ctx, -1, 0, elem_qual, NULL);
			 }
		       else
			 {
			   do /* we can have more than one element with same name */
			     {
			       soap_print_box_validating (elem_entity, elem_name, ses, err_ret, elem_type,
				   ctx, 0, elem_qual, fld_sqt);

			       if (!udt && n_max > 1)
				 {
				   elem_inx = find_index_to_vector (elem_box_name, box, BOX_ELEMENTS (box),
				       DV_ARRAY_OF_POINTER, ++elem_inx, 2, "soap_print_box_validating");
				   if (elem_inx)
				     {
				       elem_entity = ((caddr_t *)box)[elem_inx];
				       n_more++;
				       n_max--;
				     }
				 }
			       else
				 elem_inx = 0;
			     }
			   while (!*err_ret && !udt && elem_inx);
			 }

		       dk_free_tree (elem_box_name);

		       if (udt)
			 dk_free_tree (elem_entity);
		       if (*err_ret)
			 goto error;
next_loop:
		       if (elem_ns)
			 {
			   caddr_t elm = (caddr_t) dk_set_pop (&ctx->ns);
			   dk_free_box (elm);
			 }
		       if (a_ref)
			 {
			   caddr_t elm = (caddr_t) dk_set_pop (&ctx->ns);
			   dk_free_box (elm);
			 }
		       e_ptr = xml_find_schema_child (e_seq, "element", inx1++);
		     }
		   inx += (inx1 + n_more);
		 }
	       while (NULL != (e_ptr = soap_box_next_ext_type (&type_base, err_ret, ctx)));

	       if (!udt && (inx - n_opt) != (BOX_ELEMENTS (box) / 2) && !is_choice)
	         SOAP_VALIDATE_ERROR (("22023", "SV034", "Un resolved values of type '%s'", type_ref));

	       soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, NULL);
	     }
	   else
	     soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
	 }
       else if (type_base && !strcmp (type_base, SOAP_ENC_SCHEMA11 ":Array"))
	 { /* array */
	   caddr_t a_min, a_max, a_type, a_name, a_ref = NULL;
	   long n_min, n_max, inx = 0;
	   caddr_t elem_entity = NULL, *e_ptr1 = e_ptr, wsdl_type = NULL, ref = NULL;
	   char dim[1024];
	   caddr_t elem_form;
	   int elem_qual;

	   e_ptr = xml_find_schema_child (e_ptr, "sequence", 0);

	   if (!e_ptr) /* no sequence in definition */
	     SOAP_VALIDATE_ERROR (("22023", "SV035", "Can't resolve definition of type '%s'", type_ref));

	   e_ptr = xml_find_schema_child (e_ptr, "element", 0);

	   if (!e_ptr && elem && ARRAYP (box) && BOX_ELEMENTS (box) == 0) /* empty element */
	     {
	       soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
	       soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
	       return;
	     }

	   /* occurrence indicators are to the element */
	   a_min = xml_find_schema_attribute (e_ptr, "minOccurs");
	   a_max = xml_find_schema_attribute (e_ptr, "maxOccurs");

	   if (NULL != (a_ref = xml_find_schema_attribute (e_ptr, "ref")))
	     /* there can be reference to another element */
	     {
               e_ptr = NULL;
 	       soap_box_xev_get_type (a_ref, NULL, (caddr_t *) &e_ptr, 1, 1, 0);
	     }

	   elem_form = xml_find_schema_attribute (e_ptr, "form");
	   a_name = xml_find_schema_attribute (e_ptr, "name");
	   a_type = xml_find_schema_attribute (e_ptr, "type");
	   elem_qual = qualified & (elem_form ? 0 != strcmp (elem_form, "unqualified") :
	       (ctx->literal ? 1 : 0));

           /* looking for WSDL type */
	   e_ptr1 = xml_find_schema_child (e_ptr1, "attribute", 0);
	   dim[0] = 0;
	   if (NULL != (ref = xml_find_schema_attribute (e_ptr1, "ref")))
	     {
	       if (!strcmp (ref, SOAP_ENC_SCHEMA11 ":arrayType"))
		 wsdl_type = xml_find_wsdl_attribute (e_ptr1, "arrayType");
	       if (IS_MULTIDIM_ARR (wsdl_type, 11) && ARRAYP(box) && BOX_ELEMENTS(box) > 0)
		 {
		   char *delim = strchr(wsdl_type, '[');
		   long ix = 0;
		   if (ctx->soap_version <= 11)
		     strcpy_ck (dim, "[");
		   soap_box_array_to_mda (box, &new_box, ++delim, dim, sizeof (dim), err_ret, &ix, ctx);
		   if (ctx->soap_version <= 11)
		     strcat_ck (dim, "]");
		   if (!new_box || (ARRAYP (new_box) && BOX_ELEMENTS(new_box) != ix))
		     SOAP_VALIDATE_ERROR (("22023", "SV036", "Error mapping multi-dimensional array of type '%s'", type_ref));
		   box = new_box;
		 }
	     }

	   if (!a_name || !a_type || !a_min || !a_max)
	     SOAP_VALIDATE_ERROR (("22023", "SV037", "No ranges, item name, or item type is defined for an array of type '%s'", type_ref));
	   n_min = atol (a_min);
	   if (!strcmp (a_max, "unbounded"))
	     n_max = LONG_MAX;
	   else
	     n_max = atol (a_max);
	   if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (box) && DV_TYPE_OF (box) != DV_DB_NULL)
	     SOAP_VALIDATE_ERROR (("22023", "SV038", "An array or null expected as PL value of type '%s', not '%s'", type_ref, dv_type_title (DV_TYPE_OF (box))));

	   if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (box)
	       && (BOX_ELEMENTS (box) < (unsigned) n_min || BOX_ELEMENTS (box) > (unsigned) n_max))
	     SOAP_VALIDATE_ERROR (("22023", "SV039", "An array of type '%s' with min=%ld and max=%ld expected", type_ref, n_min, n_max));

	   soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, a_ref);

	   ctx->add_type = ctx->literal ? ctx->add_type : 1;
	   if (DV_TYPE_OF (box) == DV_DB_NULL)
	     {
	       SES_PRINT (ses, (ctx->soap_version == 1 ? " xsi:null='1'" : " xsi:nil='1'"));
	       if (0 == dim[0] && ctx->soap_version <= 11)
		 strcpy_ck (dim, "[]");
	     }
	   if (ctx->add_type)
	     {
	       is_in_schema = xml_is_in_schema_ns (a_type) || !strrchr (a_type, ':');

	       if (ctx->soap_version <= 11)
		 {
		   /* if there is a dimensions, let have print they */
		   if (0 == dim[0])
		     snprintf (dim, sizeof (dim), "[%ld]", BOX_ELEMENTS (box));
	           snprintf (temp, sizeof (temp), " xsi:type='SOAP-ENC:Array' SOAP-ENC:arrayType='%s:%s%s'",
		     is_in_schema ? "xsd" : (soap_wsdl_ns_prefix (a_type, &(ctx->types_set), "wsdl", NULL)),
		     extract_last_xml_name_part (a_type), dim);
		 }
	       else if (ctx->soap_version == 12)
		 {
		   /* if there is a dimensions, let have print they */
		   if (0 == dim[0])
		     snprintf (dim, sizeof (dim), "%ld", BOX_ELEMENTS (box));
	           snprintf (temp, sizeof (temp),
		       " SOAP-ENC:arraySize='%s' SOAP-ENC:nodeType='array' SOAP-ENC:itemType='%s:%s'",
		       dim,
		       (is_in_schema ? "xsd" : (soap_wsdl_ns_prefix (a_type, &(ctx->types_set), "wsdl", NULL))),
		       extract_last_xml_name_part (a_type));
		 }
	       SES_PRINT (ses, temp);
	       if (ADD_CUSTOM_SCH == ctx->add_schema && type_ref)
		 {
		   char *colon = strrchr (type_ref, ':');
		   int off_c = (int) (colon - type_ref);
		   if (colon && off_c > 0)
		     {
		       snprintf (temp, sizeof (temp), " xmlns:wsdl='%*.*s'", off_c, off_c, type_ref);
		       SES_PRINT (ses, temp);
		     }
		 }
	       else if (ADD_ALL_SCH == ctx->add_schema)
		 {
		   SES_PRINT (ses, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'");
		   SES_PRINT (ses, " xmlns:SOAP-ENC='" SOAP_ENC_SCHEMA11 "'");
		   if (is_in_schema)
		     SES_PRINT (ses, " xmlns:xsd='" W3C_2001_TYPE_SCHEMA_XSD "'");
		   else
		     SES_PRINT (ses, " xmlns:wsdl='services.wsdl'");
		 }
	     }

	   if (DV_TYPE_OF (box) != DV_DB_NULL)
	     {
	       SES_PRINT_CHAR (ses, '>');

	       if (BOX_ELEMENTS (box) > (unsigned) inx)
		 elem_entity = ((caddr_t *)box)[inx++];
	       else
		 elem_entity = NULL;
	       while (elem_entity)
		 { /* XXX: add support for offsets here */
		   soap_ctx_t ctxn;
		   if ((inx - 1) > n_max)
	             SOAP_VALIDATE_ERROR (("22023", "SV077", "Upper limit (%ld) of %s exceeded", n_max, type_ref));
		   if (DV_TYPE_OF (elem_entity) == DV_COMPOSITE)
	             SOAP_VALIDATE_ERROR (("22023", "SV079", "Can't map soap_struct to array of type %s", type_ref));

		   /* Preserve the context */
		   memcpy (&ctxn, ctx, sizeof (soap_ctx_t));
		   ctxn.add_type = 0;
		   ctxn.req_resp_namespace = NULL;
		   ctxn.qst = ctx->qst;

		   soap_print_box_validating (elem_entity, a_name, ses, err_ret, a_type, &ctxn, 0, elem_qual, NULL);
		   ctx->o_attachments = ctxn.o_attachments; /* restore attachments */

		   if (*err_ret)
		     goto error;
		   if (BOX_ELEMENTS (box) > (unsigned) inx)
		     elem_entity = ((caddr_t *)box)[inx++];
		   else
		     elem_entity = NULL;
		 }
	       soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, a_ref);
	     }
	   else
	     soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, a_ref);
	 }
       else
	 SOAP_VALIDATE_ERROR (("22023", "SV042", "Unsupported type %s", type_ref))
     }
   else if (NULL != (e_ptr = xml_find_schema_child (schema_tree, "simpleContent", 0)))
     { /* support for simpleType/extension */
       caddr_t type_base, media_type = NULL, *restriction = NULL, enumeration;
       int has_attrs = 0, n_enum = 0;
       caddr_t *extension;
       dtp_t value_type = 0;

       extension = xml_find_schema_child (e_ptr, "extension", 0);
       if (extension)
	 has_attrs = 1;
       else
	 {
	   extension = xml_find_schema_child (e_ptr, "restriction", 0);
	   enumeration = xml_find_schema_attribute (extension, "enumeration");
	   n_enum = enumeration ? atoi (enumeration) : 0;
	   restriction = extension; /* if it's restriction, preserve the place to check further */
	 }
       e_ptr = extension;
       type_base = xml_find_schema_attribute (e_ptr, "base");

       e_ptr = xml_find_schema_child (e_ptr, "annotation", 0);
       if (e_ptr)
	 e_ptr = xml_find_schema_child (e_ptr, "appinfo", 0);
       if (e_ptr)
	 {
	   e_ptr = xml_find_child (e_ptr, "mediaType", SOAP_CONTENT_TYPE_200204, 0, NULL);
           media_type = xml_find_attribute (e_ptr, "value", NULL);
	 }

       if (!tag)
	 SOAP_VALIDATE_ERROR (("22023", "SV043", "No element name supplied for type %s", type_ref))
       if (!type_name)
	 SOAP_VALIDATE_ERROR (("22023", "SV044", "Cannot resolve name of type %s", type_ref))

       soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
       if (DV_TYPE_OF (box) == DV_DB_NULL)
	 {
	   SES_PRINT (ses, (ctx->soap_version == 1 ? " xsi:null='1'" : " xsi:nil='1'"));
	   soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
	 }
       else if (media_type && ARRAYP (box))
	 {
	   /*it's attachment */
	   caddr_t id = ((caddr_t *)box)[0];
	   SES_PRINT (ses, ctx->literal ? " ref:location='" : " href='");
	   SES_PRINT (ses, id);
	   SES_PRINT (ses, "'");
	   soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
	   dk_set_push (&ctx->o_attachments, (void *)box_copy_tree (box));
	 }
       else
	 {
	   if (DV_TYPE_OF (box) != DV_ARRAY_OF_POINTER ||
	       BOX_ELEMENTS (box) != 3 || (BOX_ELEMENTS (box) == 3 &&
		 DV_TYPE_OF (((caddr_t *)box)[0]) != DV_COMPOSITE))
	     SOAP_VALIDATE_ERROR (("22023", "SV045", "Cannot map PL value to type %s", type_ref))

		 if (has_attrs)
		   {
		     if (!soap_print_attrs_validating (((caddr_t **)box)[1], extension, ses,
			   ctx, err_ret))
		       SOAP_VALIDATE_ERROR (("22023", "SV047", "Cannot map PL value to attributes of type %s",
			     type_ref));
		   }
		 else
		   if (!DV_STRINGP (((caddr_t **)box)[1]))
		     SOAP_VALIDATE_ERROR (("22023", "SV046", "Cannot map PL value to type %s", type_ref));

	   if (IS_QNAME (type_base))
	     soap_ensure_xmlns (ses, (caddr_t)((caddr_t **)box)[2], ctx);

	   SES_PRINT_CHAR (ses, '>');

	   if (!soap_check_xsd_restriction (restriction, (caddr_t)((caddr_t **)box)[2], ctx))
	     SOAP_VALIDATE_ERROR (("22023", "SV055", "Wrong PL value for type %s", type_ref));
	   if (n_enum && !soap_box_enum_validate (NULL, (caddr_t)((caddr_t **)box)[2], extension, ctx))
	     SOAP_VALIDATE_ERROR (("22023", "SV065", "Bad PL value for enumeration '%s'", type_ref))
	   /* print the value */
	   value_type = soap_type_to_dtp (type_base, 0);
	   if (IS_QNAME (type_base))
	     {
	       if (!soap_print_qname_val (ses, value_type, (caddr_t)((caddr_t **)box)[2], ctx, err_ret))
		 goto error;
	     }
	   else if (!value_type ||
	       !soap_print_scalar_value (value_type, (caddr_t)((caddr_t **)box)[2],
		 ses, ctx, err_ret))
	     SOAP_VALIDATE_ERROR (("22023", "SV048", "Cannot map PL value to type %s", type_ref));
	   soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, NULL);
	 }
     }
   else if (udt)
     {
       sql_type_t sqt;
       sqt.sqt_class = udt;

       new_box = type_name = type_ref = soap_sqt_to_soap_type (&sqt, udt->scl_soap_type, ctx->opts, NULL, NULL);
       if (!IS_UDT_XMLTYPE_SQT (&sqt))
	 {
	   soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
	   if (ctx->add_type)
	     {
	       snprintf (temp, sizeof (temp), " xsi:type='%s:%s'",
		   soap_wsdl_ns_prefix (type_ref, &(ctx->types_set), "wsdl", NULL),
		   extract_last_xml_name_part (type_name));
	       SES_PRINT (ses, temp);
	       if (ADD_CUSTOM_SCH == ctx->add_schema && type_ref)
		 {
		   char *colon = strrchr (type_ref, ':');
		   int off_c = (int) (colon - type_ref);
		   if (colon && off_c > 0)
		     {
		       snprintf (temp, sizeof (temp), " xmlns:wsdl='%*.*s'", off_c, off_c, type_ref);
		       SES_PRINT (ses, temp);
		     }
		 }
	       else if (ADD_ALL_SCH == ctx->add_schema)
		 {
		   SES_PRINT (ses, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'");
		   SES_PRINT (ses, " xmlns:wsdl='services.wsdl'");
		 }
	     }
	   SES_PRINT_CHAR (ses, '>');
	 }
       if (!udt->scl_member_map)
	 SOAP_VALIDATE_ERROR (("22023", "SV049", "Cannot find any member for user defined type %s", udt->scl_name));

       QR_RESET_CTX
	 {
	   int inx;
	   int elem_qual = qualified & (ctx->literal ? 1 : 0);
	   DO_BOX (sql_field_t *, fld, inx, udt->scl_member_map)
	     {
	       caddr_t soap_fld_name;
	       caddr_t soap_fld_type;
	       caddr_t value;

	       soap_fld_name = fld->sfl_soap_name ? fld->sfl_soap_name : fld->sfl_name;
	       soap_fld_type = soap_sqt_to_soap_type (&(fld->sfl_sqt), fld->sfl_soap_type, ctx->opts, NULL, NULL);
	       value = udt_member_observer (NULL, udi, udt->scl_member_map[inx], inx);
	       if (!IS_UDT_XMLTYPE_SQT (&sqt))
	         soap_print_box_validating (value, soap_fld_name, ses, err_ret, soap_fld_type, ctx, 0, elem_qual, &(fld->sfl_sqt));
	       else if (!strcmp (fld->sfl_name, "xt_ent"))
		 {
		   caddr_t szSOAP_XML_TYPE = box_dv_short_string (SOAP_XML_TYPE);
		   soap_print_box_validating (value, soap_fld_name, ses, err_ret, szSOAP_XML_TYPE, ctx, 0, elem_qual, &(fld->sfl_sqt));
		   dk_free_box (szSOAP_XML_TYPE);
		 }
	       dk_free_tree (value);
	       dk_free_tree (soap_fld_type);
	       if (*err_ret)
		 {
		   POP_QR_RESET;
		   goto error;
		 }
	     }
	   END_DO_BOX;
	 }
       QR_RESET_CODE
	 {
	   POP_QR_RESET;
	   *err_ret = thr_get_error_code (THREAD_CURRENT_THREAD);
	   goto error;
	 }
       END_QR_RESET;
       if (!IS_UDT_XMLTYPE_SQT (&sqt))
         soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, NULL);
     }
   else if (IS_ARRAY_SQTP (check_sqt))
     {
       long n_min = 0, n_max = check_sqt->sqt_precision, inx = 0;
       caddr_t elem_entity;
       sql_type_t sqt;
       char * a_name = "item";
       caddr_t a_type = NULL;
       int elem_qual = qualified & (ctx->literal ? 1 : 0);
       char dim [256] = {0};

       ddl_type_to_sqt (&sqt, check_sqt->sqt_tree);
       if (DV_ANY == sqt.sqt_dtp)
	 new_box = a_type = box_dv_short_string (SOAP_ANY_TYPE);
       else
	 new_box = a_type = soap_sqt_to_soap_type (&sqt, NULL, ctx->opts, NULL, NULL);

       if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (box) && DV_TYPE_OF (box) != DV_DB_NULL)
	 SOAP_VALIDATE_ERROR (("22023", "SV071", "An array or null expected as PL value of type '%s', not '%s'", a_type, dv_type_title (DV_TYPE_OF (box))));

       if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (box)
	   && (BOX_ELEMENTS (box) < (unsigned) n_min || BOX_ELEMENTS (box) > (unsigned) n_max))
	 SOAP_VALIDATE_ERROR (("22023", "SV072", "An array of type '%s' with min=%ld and max=%ld expected", a_type, n_min, n_max));

       soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);
       if (ctx->add_type)
	 {
	   is_in_schema = xml_is_in_schema_ns (a_type) || !strrchr (a_type, ':');

	   if (ctx->soap_version <= 11)
	     {
	       /* if there is a dimensions, let have print they */
	       snprintf (dim, sizeof (dim), "[%ld]", BOX_ELEMENTS (box));
	       snprintf (temp, sizeof (temp), " xsi:type='SOAP-ENC:Array' SOAP-ENC:arrayType='%s:%s%s'",
		   is_in_schema ? "xsd" : (soap_wsdl_ns_prefix (a_type, &(ctx->types_set), "wsdl", NULL)),
		   extract_last_xml_name_part (a_type), dim);
	     }
	   else if (ctx->soap_version == 12)
	     {
	       /* if there is a dimensions, let have print they */
	       snprintf (dim, sizeof (dim), "%ld", BOX_ELEMENTS (box));
	       snprintf (temp, sizeof (temp),
		   " SOAP-ENC:arraySize='%s' SOAP-ENC:nodeType='array' SOAP-ENC:itemType='%s:%s'",
		   dim,
		   (is_in_schema ? "xsd" : (soap_wsdl_ns_prefix (a_type, &(ctx->types_set), "wsdl", NULL))),
		   extract_last_xml_name_part (a_type));
	     }
	   SES_PRINT (ses, temp);
	   if (ADD_CUSTOM_SCH == ctx->add_schema && type_ref)
	     {
	       char *colon = strrchr (type_ref, ':');
	       int off_c = (int) (colon - type_ref);
	       if (colon && off_c > 0)
		 {
		   snprintf (temp, sizeof (temp), " xmlns:wsdl='%*.*s'", off_c, off_c, type_ref);
		   SES_PRINT (ses, temp);
		 }
	     }
	   else if (ADD_ALL_SCH == ctx->add_schema)
	     {
	       SES_PRINT (ses, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'");
	       SES_PRINT (ses, " xmlns:SOAP-ENC='" SOAP_ENC_SCHEMA11 "'");
	       if (is_in_schema)
		 SES_PRINT (ses, " xmlns:xsd='" W3C_2001_TYPE_SCHEMA_XSD "'");
	       else
		 SES_PRINT (ses, " xmlns:wsdl='services.wsdl'");
	     }
	 }
       SES_PRINT_CHAR (ses, '>');

       if (BOX_ELEMENTS (box) > (unsigned) inx)
	 elem_entity = ((caddr_t *)box)[inx++];
       else
	 elem_entity = NULL;

       while (elem_entity)
	 {
	   soap_ctx_t ctxn;
	   if ((inx - 1) > n_max)
	     SOAP_VALIDATE_ERROR (("22023", "SV040", "Upper limit (%ld) of %s exceeded", n_max, type_ref));
	   if (DV_TYPE_OF (elem_entity) == DV_COMPOSITE)
	     SOAP_VALIDATE_ERROR (("22023", "SV041", "Can't map soap_struct to array of type %s", type_ref));

	   /* Preserve the context */
	   memcpy (&ctxn, ctx, sizeof (soap_ctx_t));
	   ctxn.add_type = 0;
	   ctxn.req_resp_namespace = NULL;
	   ctxn.qst = ctx->qst;

	   soap_print_box_validating (elem_entity, a_name, ses, err_ret, a_type, &ctxn, 0, elem_qual, &sqt);
	   ctx->o_attachments = ctxn.o_attachments; /* restore attachments */

	   if (*err_ret)
	     goto error;
	   if (BOX_ELEMENTS (box) > (unsigned) inx)
	     elem_entity = ((caddr_t *)box)[inx++];
	   else
	     elem_entity = NULL;
	 }
       soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, NULL);
     }
   else
     { /* scalar type */
       caddr_t value = box;
       if (!proposed_type || schema_tree)
	 SOAP_VALIDATE_ERROR (("22023", "SV050", "Cannot resolve type mapping for type %s", type_ref));
       if (!tag)
	 SOAP_VALIDATE_ERROR (("22023", "SV051", "No element name supplied for type %s", type_ref));

       soap_print_tag (tag, ses, type_ref, ctx, 0, elem, qualified, NULL);

       if (DV_TYPE_OF (box) == DV_DB_NULL)
	 SES_PRINT (ses, (ctx->soap_version == 1 ? " xsi:null='1'" : " xsi:nil='1'"));
       else
         {
	   if (proposed_type == DV_LONG_STRING
	       && ARRAYP (value) && BOX_ELEMENTS (value) == 3 && DV_STRINGP (((caddr_t *)value)[0]))
	     {
	       /*it's attachment */
	       caddr_t id = ((caddr_t *)value)[0];
	       SES_PRINT (ses, ctx->literal ? " ref:location='" : " href='");
	       SES_PRINT (ses, id);
	       SES_PRINT (ses, "'");
	       soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
	       dk_set_push (&ctx->o_attachments, (void *)box_copy_tree (value));
	       goto skip_value;
	     }
	 }

       if (ctx->add_type)
	 {
	   snprintf (temp, sizeof (temp), " xsi:type='xsd:%s'", extract_last_xml_name_part (type_ref));
	   SES_PRINT (ses, temp);
	   if (ADD_ALL_SCH == ctx->add_schema)
	     {
	       SES_PRINT (ses, " xmlns:xsi='" W3C_2001_TYPE_SCHEMA_XSI "'");
	       SES_PRINT (ses, " xmlns:xsd='" W3C_2001_TYPE_SCHEMA_XSD "'");
	     }
	 }

       if (DV_TYPE_OF (box) != DV_DB_NULL)
	 {
	   if (IS_QNAME (type_ref))
	     soap_ensure_xmlns (ses, value, ctx);
	   SES_PRINT_CHAR (ses, '>');
	   if (IS_QNAME (type_ref))
	     {
	       if (!soap_print_qname_val (ses, proposed_type, value, ctx, err_ret))
		 goto error;
	     }
	   else if (!soap_print_scalar_value (proposed_type, value, ses, ctx, err_ret))
	     goto error;
	   soap_print_tag (tag, ses, type_ref, ctx, 1, elem, qualified, NULL);
	 }
       else
	 soap_print_tag (tag, ses, type_ref, ctx, -1, elem, qualified, NULL);
     }
skip_value:
   dk_free_box (new_box);
   return;

error:
   if (!*err_ret)
     {
       if (!ctx->error_message)
	 *err_ret = srv_make_new_error ("22023", "SV023",
	     "The PL value does not validate according to the parameter schema %s", type_ref);
       else
	 {
	   *err_ret = ctx->error_message;
	   ctx->error_message = NULL;
	 }
     }
   dk_free_box (new_box);
}


static caddr_t
bif_soap_print_box_validating (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *szMe = "soap_print_box_validating";
  caddr_t box = bif_arg (qst, args, 0, szMe);
  caddr_t tag = bif_string_arg (qst, args, 1, szMe);
  caddr_t type_name = bif_string_arg (qst, args, 2, szMe);
  int schema = 1, type = 1, literal = 0;
  dk_session_t *out = strses_allocate ();
  caddr_t ret = NULL;
  soap_ctx_t ctx;
  sql_class_t *udt = NULL;
  sql_type_t sqt;
  query_instance_t *qi = (query_instance_t *) qst;

  if (BOX_ELEMENTS (args) > 3)
    schema = (int) bif_long_arg (qst, args, 3, szMe);
  if (BOX_ELEMENTS (args) > 4)
    type = (int) bif_long_arg (qst, args, 4, szMe);
  if (BOX_ELEMENTS (args) > 5)
    udt = bif_udt_arg (qst, args, 5, szMe);

  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.soap_version = 11;
  ctx.dks_esc_compat = 0 /*1*/;
  ctx.req_resp_namespace = NULL;
  ctx.add_type = type;
  ctx.add_schema = schema;
  ctx.literal = literal;
  ctx.qst = qst;
  ctx.cli = qi->qi_client;

  memset (&sqt, 0, sizeof (sql_type_t));
  if (udt)
    {
      char *scl_soap_type;

      sqt.sqt_dtp = DV_OBJECT;
      sqt.sqt_class = udt;
      scl_soap_type = soap_sqt_to_soap_type (&sqt, udt->scl_soap_type, ctx.opts, NULL, NULL);
      soap_wsdl_schema_push (&(ctx.ns_set), &(ctx.types_set), udt->scl_soap_type, 0, 0, &sqt, &ctx);
      dk_free_box (scl_soap_type);
    }
  soap_print_box_validating (box, tag, out, err_ret, type_name, &ctx, literal, 1, &sqt);
  if (!*err_ret)
    ret = strses_string (out);
  strses_free (out);
  return ret;
}


static caddr_t
bif_soap_dt_define (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dt = bif_string_arg (qst, args, 0, "__soap_dt_define");
  xml_tree_ent_t *xe = (xml_tree_ent_t*) bif_arg (qst, args, 1, "__soap_dt_define");
  xml_tree_ent_t *xe1 = BOX_ELEMENTS(args) > 2 ?
      (xml_tree_ent_t*) bif_arg (qst, args, 2, "__soap_dt_define") : NULL;
  int is_null;
  int is_elm = BOX_ELEMENTS(args) > 3 ? (int) bif_long_or_null_arg (qst, args, 3, "__soap_dt_define", &is_null) : 0;
  caddr_t udt_name = BOX_ELEMENTS(args) > 4 ? bif_string_or_null_arg (qst, args, 4, "__soap_dt_define") : NULL;
  caddr_t *place = (caddr_t*) id_hash_get (HT_SOAP(is_elm), (caddr_t) &dt);
  caddr_t *udt_place = NULL;
  caddr_t * xml_tree = NULL, * xml_org_tree = NULL;

  if (DV_XML_ENTITY == DV_TYPE_OF(xe) && ARRAYP(xe->xte_current) && BOX_ELEMENTS(xe->xte_current) > 1)
    xml_tree = (caddr_t *)(xe->xte_current[1]);

  if (DV_XML_ENTITY == DV_TYPE_OF(xe1) && ARRAYP(xe1->xte_current) && BOX_ELEMENTS(xe1->xte_current) > 1)
    xml_org_tree = (caddr_t *)(xe1->xte_current[1]);

#if 0 /*DELME: we need to specify some time the target of the element */
  if (is_elm && udt_name)
    sqlr_new_error ("22023", "UD001", "User defined type specified for an element");
#endif

  if (udt_name)
    udt_place = (caddr_t*) id_hash_get (ht_soap_udt, (caddr_t) &dt);
  if (xml_tree)
    { /* new type definition */
      if (udt_name)
	{
	  if (udt_place && *udt_place)
	    {
	      dk_free_box (*udt_place);
	      *udt_place = box_dv_short_string (udt_name);
	    }
	  else
	    {
	      caddr_t dt1 = box_dv_short_string (dt);
	      caddr_t udt_name_copy = box_dv_short_string (udt_name);
	      id_hash_set (ht_soap_udt, (caddr_t) &dt1, (caddr_t) &udt_name_copy);
	    }
	}

      if (place && *place)
	{
	  dk_free_tree (*place);
	  *place = list (2, box_copy_tree ((box_t) xml_tree),
	      (xml_org_tree ? box_copy_tree ((box_t) xml_org_tree) : box_copy_tree ((box_t) xml_tree)));
	}
      else
	{
	  caddr_t dt1 = box_dv_short_string (dt);
	  caddr_t xml1 = list (2, box_copy_tree ((box_t) xml_tree),
	      (xml_org_tree ? box_copy_tree ((box_t) xml_org_tree) : box_copy_tree ((box_t) xml_tree)));
	  id_hash_set (HT_SOAP(is_elm), (caddr_t) &dt1, (caddr_t) &xml1);
	}
    }
  else
    { /* type removal */
      if (place && *place)
	{
	  caddr_t * key = (caddr_t *) id_hash_get_key (HT_SOAP(is_elm), (caddr_t) &dt);
	  dk_free_tree (*key);
	  dk_free_tree (*place);
 	  id_hash_remove (HT_SOAP(is_elm), (caddr_t) &dt);
	}
      if (udt_name && udt_place && *udt_place)
	{
	  caddr_t * key = (caddr_t *) id_hash_get_key (ht_soap_udt, (caddr_t) &dt);
	  dk_free_tree (*key);
	  dk_free_tree (*place);
 	  id_hash_remove (ht_soap_udt, (caddr_t) &dt);
	}
    }
  return (box_num (0));
}

#if 0
static caddr_t
bif_soap_operation (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t name = bif_string_arg (qst, args, 0, "soap_operation");
  query_t * qr = proc_find_in_grants (name, qi->qi_client);
  if (!qr)
    return NEW_DB_NULL;
  return box_dv_short_string (qr->qr_proc_name);
}
#endif

static caddr_t *
soap_http_params (query_t *qr, caddr_t * in_params, caddr_t * text, caddr_t * err, soap_ctx_t * ctx)
{
  int npars = dk_set_length (qr->qr_parms);
  caddr_t *params = (caddr_t *) dk_alloc_box_zero (2 * npars * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  int inx = 0, inx1, inx2 = 0;
  int n_set = 0;

  sch_split_name ("WS", qr->qr_proc_name, q, o, n);
  *text = dk_alloc_box_zero (strlen (q) + strlen (o) + strlen (n) + 12 + npars * 2, DV_SHORT_STRING);
  snprintf (*text, box_length (*text), "\"%s\".\"%s\".\"%s\"(", q, o, n);

  DO_SET (state_slot_t *, proc_param, &qr->qr_parms)
    {
      dtp_t param_type = proc_param->ssl_dtp;
      char *param_name = proc_param->ssl_name, tmp[10];
      int parm_enc = ctx->literal;
      const char * use = SOAP_OPT (USE, qr, inx2, NULL);
      SOAP_USE (use, parm_enc, ctx->literal);

      snprintf (tmp, sizeof (tmp), ":%d", inx / 2);
      strcat_box_ck (*text, "?,");
      params[inx++] = box_string (tmp);

      if (proc_param->ssl_type == SSL_REF_PARAMETER_OUT)
	{
	  params[inx] = dk_alloc_box (0, DV_DB_NULL);
	  n_set++;
	}
      else
	{
	  params[inx] = NULL;
	  DO_BOX (caddr_t, param, inx1, in_params)
	    {
	      if (!strcmp (param, param_name))
		{
		  dtp_t val_dtp = DV_TYPE_OF (in_params[inx1+1]);
		  caddr_t strval = box_cast_to (NULL, in_params[inx1+1], val_dtp, param_type,
		      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err);
		  if (!*err)
 		    params[inx] = strval;
		  else
		    goto end;
		  n_set++;
		  break;
		}
	      inx1++;
	    }
	  END_DO_BOX;
	  if (NULL == params[inx] && qr->qr_parm_default && qr->qr_parm_default[inx2])
	    {
	      params[inx] = box_copy_tree (qr->qr_parm_default[inx2]);
	      n_set++;
	    }
	}

      if (qr->qr_parm_alt_types[inx2])
	soap_wsdl_schema_push (&(ctx->ns_set), &(ctx->types_set), qr->qr_parm_alt_types[inx2],
	    parm_enc, 0, NULL, ctx);

      inx++;
      inx2++;
    }
  END_DO_SET();

  if (qr->qr_proc_alt_ret_type)
    soap_wsdl_schema_push (&(ctx->ns_set), &(ctx->types_set), qr->qr_proc_alt_ret_type,
	ctx->literal, 0, NULL, ctx);

  if (n_set < npars && !*err)
    *err = srv_make_new_error ("37000", "SP029", "Not enough input parameters in the request");
  else
    (*text)[strlen(*text) - (n_set ? 1 : 0)] = ')';
end:
  return params;
}

#define SOAP_HTTP

caddr_t
ws_soap_http (ws_connection_t * ws)
{
  caddr_t *path = ws->ws_p_path, *params = ws->ws_params;
  char *szMethod = BOX_ELEMENTS (path) > 2 ? path[2] : NULL;
  char szFullProcName[2048], *usr_qual, mime_type[1024];
  const char *usr_own;
  client_connection_t *cli = ws->ws_cli;
  query_t *qr = NULL;
  caddr_t err = NULL, *pars, text;
  dk_session_t *ses = ws->ws_strses;
  wcharset_t *volatile charset = ws->ws_charset;
  int is_http = 0;

  soap_ctx_t ctx;
  int http_resp_code = 200;
  caddr_t *opts = SOAP_OPTIONS (ws);
  char *soap_escapes = SOAP_USE_ESCAPES (opts);
  char *schema_ns = SOAP_TYPES_SCH (opts);
  dk_set_t qrs = NULL;

  /* Set context for SOAP serialization */
  memset (&ctx, 0, sizeof (soap_ctx_t));
  ctx.soap_version = atoi (ws_soap_get_opt (opts, "HttpSOAPVersion", "11"));
  ctx.dks_esc_compat = ((soap_escapes && tolower (soap_escapes[0]) == 'y') ?
      DKS_ESC_COMPAT_SOAP: 0);
  ctx.def_enc = SOAP_DEF_ENC (opts);
  ctx.opts = opts;
  ctx.role_url = ws_soap_get_opt (opts, SOAP_ROLE, NULL);
  ctx.is_router = soap_get_opt_flag (opts, SOAP_ROUTER);
  ctx.cli = cli;
  connection_set (cli, con_soap_fault_name, NULL);
  connection_set (cli, con_soap_blob_limit_name, NULL);

  if (!szMethod)
    {
      err = srv_make_new_error ("22023", "SOH01", "No operation specified in SOAP call");
      goto end;
    }
  if (!cli->cli_user)
    {
      err = srv_make_new_error ("37000", "SOH02", "No execute permissions to the domain");
      goto end;
    }
  usr_qual = ws_usr_qual (ws, 1);
  usr_own = WS_SOAP_NAME (ws);
  snprintf (szFullProcName, sizeof (szFullProcName), "%s.%s.%s", usr_qual, usr_own, szMethod);
  if (CM_UPPER == case_mode)
    sqlp_upcase (szFullProcName);
  if (!(qr = sch_proc_def (wi_inst.wi_schema, szFullProcName)))
    {
      qrs = get_granted_qrs (cli, NULL, NULL, 0);
      if (!(qr = proc_find_in_grants (szMethod, &qrs, NULL)))
	{
	  err = srv_make_new_error ("37000", "SOH03", "There is no such procedure");
	  goto end;
	}
    }
  if (qr->qr_to_recompile)
    {
      qr = qr_recompile (qr, &err);
      if (NULL != err)
	goto end;
    }

  is_http = (qr->qr_proc_place & SOAP_MSG_HTTP);

#ifndef SOAP_HTTP
  if (!is_http)
    {
      err = srv_make_new_error ("37000", "SOH04", "There is no such procedure");
      goto end;
    }
#endif

  if (!ws->ws_header)
    {
      if (is_http)		/* we should do this only when no error */
	{
	  snprintf (mime_type, sizeof (mime_type), "Content-Type: %s; charset=\"%s\"\r\n",
	      qr->qr_proc_alt_ret_type, CHARSET_NAME (charset, "ISO-8859-1"));
	  ws->ws_header = box_dv_short_string (mime_type);
	}
#ifdef SOAP_HTTP
      else
	{
	  snprintf (mime_type, sizeof (mime_type), "Content-Type: text/xml; charset=\"%s\"\r\n", CHARSET_NAME (charset, "ISO-8859-1"));
	  ws->ws_header = box_dv_short_string (mime_type);
	}
#endif
    }
  ctx.literal = (SOAP_MSG_LITERAL & qr->qr_proc_place);
  pars = soap_http_params (qr, params, &text, &err, &ctx);
  if (err)
    {
      dk_free_tree ((box_t) pars);
      dk_free_box (text);
#ifdef SOAP_HTTP
      if (!is_http)
	{
	  caddr_t err1;
	  err1 = ws_soap_error (ses, "320", ERR_STATE (err), ERR_MESSAGE (err), ctx.soap_version, 0,
	      &http_resp_code, &ctx);
	  dk_free_tree (err);
	  err = err1;
	}
#endif
      goto end;
    }

  {
    query_t *volatile call_qry = NULL;
    local_cursor_t *lc = NULL;

    call_qry = sql_compile (text, cli, &err, SQLC_DEFAULT);
    dk_free_box (text);
    if (err)
      {
	dk_free_tree ((box_t) pars);
	goto end;
      }
      err = qr_exec (cli, call_qry, CALLER_LOCAL, NULL, NULL,
	  &lc, pars, NULL, 1);
    dk_free_box ((box_t) pars);
    while (lc_next (lc));
    if (err)
      {
	if (lc)
	  lc_free (lc);
	qr_free (call_qry);
#ifdef SOAP_HTTP
	if (!is_http)
	  {
	    caddr_t err1;
	      err1 = ws_soap_error (ses, "400", ERR_STATE (err), ERR_MESSAGE (err), ctx.soap_version, 0,
		  &http_resp_code, &ctx);
	    dk_free_tree (err);
	    err = err1;
	  }
#endif
	goto end;
      }
    if (lc)
      {
	if (IS_BOX_POINTER (lc->lc_proc_ret))
	  {
#ifdef SOAP_HTTP
	    if (!is_http)
	      err = soap_serialize (ses, cli, qr, lc, &ctx,
		  schema_ns, 0, &http_resp_code, szMethod, SOAP_OPT (RESP_NS, qr, -1, NULL));
	    else
#endif
	      {
		caddr_t *proc_ret = (caddr_t *) lc->lc_proc_ret;
		int nProcRet = BOX_ELEMENTS (lc->lc_proc_ret);

		if (nProcRet > 1)
		  {
		    caddr_t ret_val = proc_ret[1];
		    dtp_t dtp = DV_TYPE_OF (ret_val);
		    if (soap_print_xml_entity (ret_val, ses, cli))
		      ;
		    else
		      {
			caddr_t strval = box_cast_to (NULL, ret_val, dtp, DV_SHORT_STRING,
			    NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
			if (!err && strval)
			  {
			    if (DV_STRINGP (strval))
			      SES_PRINT (ses, strval);
			    dk_free_box (strval);
			  }
		      }
		  }
	      }
	  }
      }
    if (lc)
      lc_free (lc);
    qr_free (call_qry);
  }

end:
  if (err && http_resp_code != 200)
    {
      ws->ws_status_line = ws_http_error_header (http_resp_code);
      ws->ws_status_code = http_resp_code;
    }
  dk_free_tree ((box_t) ws->ws_params);
  ws->ws_params = NULL;
  soap_wsdl_schema_free (&(ctx.ns_set), &(ctx.types_set));
  dk_set_free (qrs);
  return err;
}

static void
soap_print_schema_fragment (caddr_t type_name, sql_type_t * sqt, dk_session_t *out,
    dk_set_t *types_set, int sp, soap_ctx_t *ctx)
{
  const char * name = extract_last_xml_name_part (type_name);
  long nmax = sqt->sqt_precision;
  char tmp [256];
  caddr_t ctype_name = NULL;

  sp += 2; PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "<complexType name='");
  SES_PRINT (out, name);
  SES_PRINT (out, "'>\n");
  if (!ctx->def_enc)
    {
      sp += 2; PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "<complexContent>\n");
      sp += 2; PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "<restriction base='soapenc:Array'>\n");
    }
  sp += 2; PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "<sequence>\n");
  sp += 2;
  PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "<element name='item' type='");
  if (sqt->sqt_tree)
    {
      sql_type_t sqt1;

      ddl_type_to_sqt (&sqt1, sqt->sqt_tree);
      ctype_name = soap_sqt_to_soap_type (&(sqt1), NULL, ctx->opts, name, "item");
      wsdl_print_q_name (out, ctype_name, types_set);
    }
  else
    {
      SES_PRINT (out, "xsd:");
      SES_PRINT (out, dtp_to_soap_type (sqt->sqt_dtp));
    }
  SES_PRINT (out, "' minOccurs='0' maxOccurs='");
  if (nmax >= ARRAY_MAX)
    strcpy_ck (tmp, "unbounded");
  else
    snprintf (tmp, sizeof (tmp), "%ld", nmax);
  SES_PRINT (out, tmp);
  SES_PRINT (out, "' nillable='true' />\n");
  sp -= 2;
  PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "</sequence>\n");
  if (!ctx->def_enc)
    {
      PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "<attributeGroup ref='soapenc:commonAttributes'/>\n");
      PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "<attribute ref='soapenc:arrayType' wsdl:arrayType='");
      if (ctype_name)
	wsdl_print_q_name (out, ctype_name, types_set);
      else
	SES_PRINT (out, dtp_to_soap_type (sqt->sqt_dtp));
      SES_PRINT (out, "[]'/>\n");
      sp -= 2; PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "</restriction>\n");
      sp -= 2; PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "</complexContent>\n");
    }
  sp -= 2;
  PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "</complexType>\n");
  dk_free_box (ctype_name);
}

static void
soap_udt_print_schema_fragment (sql_class_t *udt, dk_session_t *out, dk_set_t *types_set, int sp, soap_ctx_t *ctx)
{
  sql_type_t sqt;
  char *udt_soap_name;
  const char *udt_soap_nc_name;
  int inx;

  sqt.sqt_class = udt;
  udt_soap_name = soap_sqt_to_soap_type (&sqt, udt->scl_soap_type, ctx->opts, NULL, NULL);
  udt_soap_nc_name = extract_last_xml_name_part (udt_soap_name);
  sp += 2;
  PRINT_SPACE_B (out, sp);

  SES_PRINT (out, "<complexType name='");
  SES_PRINT (out, udt_soap_nc_name);
  dk_free_box (udt_soap_name);
  if (!udt->scl_member_map || !BOX_ELEMENTS (udt->scl_member_map))
    {
      SES_PRINT (out, "'/>\n");
      return;
    }
  else
    SES_PRINT (out, "'>\n");
  sp += 2;
  PRINT_SPACE_B (out, sp);

  if (IS_UDT_XMLTYPE_SQT(&sqt))
    {
      SES_PRINT (out, "<sequence>\n");
      PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "  <any namespace='##any' processContents='lax' maxOccurs='unbounded'/>\n");
      PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "</sequence>\n");
      PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "<anyAttribute namespace='##any' processContents='lax' />\n");
      goto end_decl;
    }

  SES_PRINT (out, "<all>\n");
  sp += 2;
  DO_BOX (sql_field_t *, fld, inx, udt->scl_member_map)
    {
      char *soap_fld_type = soap_sqt_to_soap_type (&(fld->sfl_sqt), fld->sfl_soap_type, ctx->opts, udt->scl_name_only, fld->sfl_name);
      char *soap_fld_name = fld->sfl_soap_name ? fld->sfl_soap_name : fld->sfl_name;

      PRINT_SPACE_B (out, sp);
      SES_PRINT (out, "<element name='");
      SES_PRINT (out, soap_fld_name);
      SES_PRINT (out, "' type='");
      wsdl_print_q_name (out, soap_fld_type, types_set);
      SES_PRINT (out, "' nillable='true'/>\n");
      dk_free_box (soap_fld_type);
    }
  END_DO_BOX;
  sp -= 2;
  PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "</all>\n");
end_decl:
  sp -= 2;
  PRINT_SPACE_B (out, sp);
  SES_PRINT (out, "</complexType>\n");
}

caddr_t http_host_normalize (caddr_t host, int to_ip); /* from http.c */

static caddr_t
bif_soap_udt_publish (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * szMe = "soap_udt_publish";
  sql_class_t * udt = bif_udt_arg (qst, args, 3, szMe);
  caddr_t vh = http_host_normalize (bif_string_arg (qst, args, 0, szMe), 0);
  caddr_t lhost = http_host_normalize (bif_string_arg (qst, args, 1, szMe), 1);
  caddr_t lpath = bif_string_arg (qst, args, 2, szMe);
  id_hash_t ** place;
  ptrlong one = 1;
  caddr_t host, endp;

  if (lhost[0] == ':' && vh[0] == ':')
    {
      host = box_dv_short_string ("*all*");
      dk_free_box (vh); vh = NULL;
    }
  else
    host = vh;

  endp = dk_alloc_box (box_length (lpath) + box_length (host) + box_length (lhost) + 1, DV_SHORT_STRING);
  snprintf (endp, box_length (endp), "//%s|%s%s", host, lhost, lpath);

  place = (id_hash_t **) id_hash_get (ht_soap_sup, (caddr_t) &endp);
  if (!place)
    {
      caddr_t endp_cpy = box_copy (endp);
      caddr_t udt_name = box_copy (udt->scl_name);
      id_hash_t * ht = id_str_hash_create (10);

      id_hash_set (ht, (caddr_t)&udt_name, (caddr_t)&one);
      id_hash_set (ht_soap_sup, (caddr_t)&endp_cpy, (caddr_t)&ht);
    }
  else if (NULL == id_hash_get (*place, (caddr_t)&udt->scl_name))
    {
      id_hash_t * ht = *place;
      caddr_t udt_name = box_copy (udt->scl_name);

      id_hash_set (ht, (caddr_t)&udt_name, (caddr_t)&one);
    }
  dk_free_box (host);
  dk_free_box (lhost);
  dk_free_box (endp);
  return box_num(0);
}

static caddr_t
bif_soap_udt_unpublish (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * szMe = "soap_udt_unpublish";
  caddr_t vh = http_host_normalize (bif_string_arg (qst, args, 0, szMe), 0);
  caddr_t lhost = http_host_normalize (bif_string_arg (qst, args, 1, szMe), 1);
  caddr_t lpath = bif_string_arg (qst, args, 2, szMe);
  caddr_t udt_name = bif_string_arg (qst, args, 3, szMe);
  id_hash_t ** place;
  caddr_t host, endp;

  if (lhost[0] == ':' && vh[0] == ':')
    {
      host = box_dv_short_string ("*all*");
      dk_free_box (vh); vh = NULL;
    }
  else
    host = vh;

  endp = dk_alloc_box (box_length (lpath) + box_length (host) + box_length (lhost) + 1, DV_SHORT_STRING);
  snprintf (endp, box_length (endp), "//%s|%s%s", host, lhost, lpath);

  place = (id_hash_t **) id_hash_get (ht_soap_sup, (caddr_t) &endp);

  if (place)
    {
      id_hash_t * ht = *place;
      sql_class_t * udt = sch_name_to_type (isp_schema (NULL), udt_name);
      if (udt)
        id_hash_remove (ht, (caddr_t)&udt->scl_name);
      else
        id_hash_remove (ht, (caddr_t)&udt_name);
    }

  dk_free_box (host);
  dk_free_box (lhost);
  dk_free_box (endp);

  return box_num(0);
}


void
bif_soap_init (void)
{
  soap_fake_top_qi.qi_client = bootstrap_cli;
  ht_soap_dt = id_str_hash_create (101);
  ht_soap_elt = id_str_hash_create (101);
  ht_soap_attr = id_str_hash_create (101);
  ht_soap_udt = id_str_hash_create (101);
  ht_soap_sup = id_str_hash_create (101);
  con_soap_fault_name = box_dv_short_string ("SOAPFault");
  con_soap_blob_limit_name = box_dv_short_string ("SOAPBlobLimit");
  bif_define_ex ("soap_find_xml_attribute", bif_soap_find_xml_attribute, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("soap_print_box", bif_soap_print_box, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("soap_print_box_validating", bif_soap_print_box_validating, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("soap_box_xml_entity", bif_soap_box_xml_entity);
  bif_define ("soap_box_xml_entity_validating", bif_soap_box_xml_entity_validating);
  bif_define ("soap_call", bif_soap_call);
  bif_define ("soap_call_new", bif_soap_call_new);
  bif_define ("soap_receive", bif_soap_receive);
  bif_define ("soap_server", bif_soap_server);
  bif_define ("soap_box_structure", bif_soap_box_structure);
  bif_define ("soap_boolean", bif_soap_boolean);
  bif_define_ex ("soap_make_error", bif_soap_make_error, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("soap_sdl", bif_soap_sdl, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("soap_wsdl", bif_soap_wsdl, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("soap_current_url", bif_soap_current_url, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("dv_to_soap_type", bif_dv_to_soap_type, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("__soap_dt_define", bif_soap_dt_define);
  bif_define ("__soap_udt_publish", bif_soap_udt_publish);
  bif_define ("__soap_udt_unpublish", bif_soap_udt_unpublish);
#ifdef SOAP_HASH_DBG
  bif_define ("soap_print_types_hash", bif_print_types_hash);
#endif
}
