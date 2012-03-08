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

#ifndef SOAP_H
#define SOAP_H


#define SOAP_TYPE_SCHEMA10 "urn:schemas-xmlsoap-org:soap.v1"
#define SOAP_TYPE_SCHEMA11 "http://schemas.xmlsoap.org/soap/envelope/"
#define SOAP_ENC_SCHEMA11 "http://schemas.xmlsoap.org/soap/encoding/"
#define SOAP_WSDL_SCHEMA11 "http://schemas.xmlsoap.org/wsdl/"
#define SOAP_DIME_SCHEMA "http://schemas.xmlsoap.org/ws/2002/04/dime/"
#define W3C_TYPE_SCHEMA_XSI "http://www.w3.org/1999/XMLSchema-instance"
#define W3C_TYPE_SCHEMA_XSD "http://www.w3.org/1999/XMLSchema"
#define W3C_2001_TYPE_SCHEMA_XSI "http://www.w3.org/2001/XMLSchema-instance"
#define W3C_2001_TYPE_SCHEMA_XSD "http://www.w3.org/2001/XMLSchema"
#define SOAP_ACTOR_FIRST "http://schemas.xmlsoap.org/soap/actor/next"
#define SOAP_CONTENT_TYPE_200204 "http://schemas.xmlsoap.org/ws/2002/04/content-type/"
#define SOAP_REF_SCH_200204	 "http://schemas.xmlsoap.org/ws/2002/04/reference/"

/* WSDL 2.0 NS */

#define SOAP_WSDL_SCHEMA20_NS 		"http://www.w3.org/ns/wsdl"

#define SOAP_WSDL_SCHEMA20 		"http://www.w3.org/2006/01/wsdl" /* must be SOAP_WSDL_SCHEMA20_NS */
#define SOAP_BINDING_TYPE_SOAP 		SOAP_WSDL_SCHEMA20_NS "/soap"
#define SOAP_BINDING_TYPE_HTTP 		SOAP_WSDL_SCHEMA20_NS "/http"
#define SOAP_11_VERSION 		"1.1"
#define SOAP_BINDING_PROTOCOL_HTTP 	"http://www.w3.org/2006/01/soap%d/bindings/HTTP/"
#define SOAP_WSDL20_PATTERN_INOUT  	SOAP_WSDL_SCHEMA20_NS "/in-out"
#define SOAP_WSDL20_PATTERN_IN  	SOAP_WSDL_SCHEMA20_NS "/in"
#define SOAP_WSDL20_RPC		  	SOAP_WSDL_SCHEMA20_NS "/rpc"

/* SOAP 1.2 NS */
#define SOAP_TYPE_SCHEMA12 	"http://www.w3.org/2003/05/soap-envelope"
#define SOAP_ENC_SCHEMA12	"http://www.w3.org/2003/05/soap-encoding"
#define SOAP_RPC_SCHEMA12	"http://www.w3.org/2003/05/soap-rpc"
#define SOAP_ROLE_NEXT		SOAP_TYPE_SCHEMA12"/role/next"
#define SOAP_ROLE_NONE		SOAP_TYPE_SCHEMA12"/role/none"
#define SOAP_ROLE_ULTIMATE	SOAP_TYPE_SCHEMA12"/role/ultimateReceiver"

#define MS_TYPE_SCHEMA "urn:schemas-microsoft-com:datatypes"
/*#define VIRTUOSO_TYPE_SCHEMA "urn:openlinksw-com:virtuoso"*/
#define BPEL4WS_PL_URI	"http://schemas.xmlsoap.org/ws/2003/05/partner-link/"

#define SOAP_URI(x) ((x) == 1  ? SOAP_TYPE_SCHEMA10 : \
    		     (x) == 11 ? SOAP_TYPE_SCHEMA11 : \
		     (x) == 12 ? SOAP_TYPE_SCHEMA12 : NULL)

#define SOAP_ENC(x) ((x) == 1  ? SOAP_TYPE_SCHEMA10 : \
    		     (x) == 11 ? SOAP_ENC_SCHEMA11 : \
		     (x) == 12 ? SOAP_ENC_SCHEMA12 : NULL)

caddr_t * xml_find_child (caddr_t *entity, const char *szSearchName, const char *szURI, int nth, int *start_inx);
caddr_t * xml_find_one_child (caddr_t *entity, char *szSearchName, char **szURIs, int nth, int *start_inx);
int is_in_urls (char **szURIs, const char *uri, int *idx);

#define WS_ENC_NONE 0
#define WS_ENC_DIME 1
#define WS_ENC_MIME 2

#define ARRAY_MAX 0x7fffffff

/* DIME encapsulation */
#define SOAP_MSG_IN	(long)0x400
#define SOAP_MSG_OUT	(long)0x800
#define SOAP_MSG_INOUT	(long)0xC00

/* MIME encapsulation */
#define SOAP_MMSG_IN	(long)0x100
#define SOAP_MMSG_OUT	(long)0x200
#define SOAP_MMSG_INOUT	(long)0x300

#define SOAP_MSG_HEADER  	0x01   /* an parameter is in a SOAP:Header  */
#define SOAP_MSG_LITERAL 	0x02   /* the method is document/literal encoded */
#define SOAP_MSG_XML     	0x04   /* the parameter is RAW XML passed to the procedure */
#define SOAP_MSG_LITERALW 	0x08   /* the method is document/literal encoded, like RPC one */
#define SOAP_MSG_HTTP		0x10   /* the method have HTTP/GET/POST disposition */
#define SOAP_MSG_FAULT		0x20   /* an parameter is exposed to soap:fault */
#define SOAP_MSG_DOC		(SOAP_MSG_LITERAL|SOAP_MSG_LITERALW) /* document */

#define IS_SOAP_RPCLIT(f)	((f)&SOAP_MSG_LITERALW)
#define IS_SOAP_LIT(f)		((f)&SOAP_MSG_LITERAL && !((f)&SOAP_MSG_LITERALW))

#define IS_SOAP_MSG_HEADER(x) ((unbox(x) & 0xFF) & SOAP_MSG_HEADER)
#define IS_SOAP_MSG_FAULT(x) ((unbox(x) & 0xFF) & SOAP_MSG_FAULT)
#define IS_SOAP_MSG_SPECIAL(x) (SOAP_MSG_HEADER == (unbox(x) & SOAP_MSG_HEADER) \
    || SOAP_MSG_FAULT == (unbox(x) & SOAP_MSG_FAULT))
#define IS_SOAP_MSG_SET(x,m) ((m) == (unbox(x) & 0xFF))

/* supported SOAP options to the procedure */
#define SOAP_OPT_MSG_NAME 	"MessageName"
#define SOAP_OPT_PART_NAME 	"PartName"
#define SOAP_OPT_REQ_NS   	"RequestNamespace"
#define SOAP_OPT_RESP_NS  	"ResponseNamespace"
#define SOAP_OPT_ACTION		"soapAction"
#define SOAP_OPT_PARAM_STYLE	"ParameterStyle"
#define SOAP_OPT_REQ_ELEM_NAME	"RequestElementName"
#define SOAP_OPT_RESP_ELEM_NAME	"ResponseElementName"
#define SOAP_OPT_USE		"Use"
#define SOAP_OPT_BINDING    	"Binding"
#define SOAP_OPT_ONEWAY		"OneWay"
#define SOAP_OPT_OPERATION	"Operation"
#define SOAP_OPT_DEFAULT_OPER	"DefaultOperation"
/* to be extended */

#define SOAP_USE(enc, flag, deflt) flag = deflt; \
    				   if (enc) { \
                                     if (!strcmp (enc, "literal")) \
				       flag = 1; \
				     else if (!strcmp (enc, "encoded")) \
				       flag = 0; \
				   }

#define SOAP_CTYPE_12 "application/soap+xml"
#define SOAP_CTYPE_11 "text/xml"

#define IS_QNAME(tp) (NULL != (tp) && 0 == strcmp ((tp), W3C_2001_TYPE_SCHEMA_XSD":QName"))

#endif
