/*
 *  bif_kerberoscli.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifdef _KERBEROS

#include "Dk.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "http.h"

#include <krb5.h>
#include <gssapi/gssapi.h>
#include <gssapi/gssapi_generic.h>
#include <gssapi/gssapi_krb5.h>

krb5_error_code krb5_gen_replay_name(krb5_context context, krb5_address *address, char  *uniq, char ** string);

#ifndef WIN32
#include <netinet/in.h>
#include <netdb.h>
#endif

#define KRB_BUFF_SIZE 10000
#define KRB_TOK_SIZE 4000

typedef struct k5_data
{
    krb5_context ctx;
    krb5_ccache cc;
    krb5_principal me;
    char* name;
} k5_data_t
;


static void
k5_end(k5_data_t *k5, int mode)
{
  if (k5->name)
    krb5_free_unparsed_name(k5->ctx, k5->name);
  if (k5->me)
    krb5_free_principal(k5->ctx, k5->me);
  if (k5->cc && mode)
    krb5_cc_close(k5->ctx, k5->cc);
  if (k5->ctx)
    krb5_free_context(k5->ctx);
  memset(k5, 0, sizeof(*k5));
}

#define GSS_TRY(o, vc) if (GSS_S_COMPLETE != (o)) \
 		      srv_make_gss_error (maj_stat, min_stat, vc);

#define GSS_TRY1(o, vc)  { \
                           o; \
			   if (maj_stat != GSS_S_COMPLETE && maj_stat != GSS_S_CONTINUE_NEEDED) \
  		             srv_make_gss_error (maj_stat, min_stat, vc); \
			 }

static void
srv_make_gss_error(OM_uint32 maj_stat, OM_uint32 min_stat, char *virt_code)
{
	/* a lot of work just to report the error */
	OM_uint32 gmaj_stat, gmin_stat;
	gss_buffer_desc msg;
	char all_error_text[1024];
	OM_uint32 msg_ctx;

	msg_ctx = 0;
	strcpy_ck (all_error_text , "");

	while (!msg_ctx) {
		gmaj_stat = gss_display_status(&gmin_stat, maj_stat,
					       GSS_C_GSS_CODE,
					       GSS_C_NULL_OID,
					       &msg_ctx, &msg);
		if ((gmaj_stat == GSS_S_COMPLETE)||
		    (gmaj_stat == GSS_S_CONTINUE_NEEDED)) {
			strncat_ck (all_error_text, (char*)msg.value, 100);
			strcat_ck (all_error_text, " ");
			(void) gss_release_buffer(&gmin_stat, &msg);
		}
		if (gmaj_stat != GSS_S_CONTINUE_NEEDED)
			break;
	}
	msg_ctx = 0;
	while (!msg_ctx) {
		gmaj_stat = gss_display_status(&gmin_stat, min_stat,
					       GSS_C_MECH_CODE,
					       GSS_C_NULL_OID,
					       &msg_ctx, &msg);
		if ((gmaj_stat == GSS_S_COMPLETE)||
		    (gmaj_stat == GSS_S_CONTINUE_NEEDED)) {
			strncat_ck (all_error_text, (char*)msg.value, 100);
			strcat_ck (all_error_text, " ");
			(void) gss_release_buffer(&gmin_stat, &msg);
		}
		if (gmaj_stat != GSS_S_CONTINUE_NEEDED)
			break;
	}
	sqlr_new_error ("42000", virt_code, "%s", all_error_text);
}


static caddr_t
kerberos_client_auth (long my_gcontext, caddr_t my_tok, caddr_t server_tok, caddr_t service)
{
  OM_uint32 maj_stat, min_stat;
  gss_ctx_id_t gcontext;
  gss_name_t target_name;
  gss_OID mech_type;
  struct gss_channel_bindings_struct chan;
  gss_buffer_desc send_tok, recv_tok, *token_ptr;
  gss_buffer_desc temp_null_tok;
  int temp_test_int;
  caddr_t buf, buf2;
  uint32 len, len2, blen;
  dk_set_t ret = NULL;

  char temp_send_tok [KRB_TOK_SIZE];

  if (my_tok)
    {
      blen = box_length(my_tok);
      buf2 = dk_alloc_box(blen, DV_SHORT_STRING);
      memcpy (buf2, my_tok, blen);
      len2 = decode_base64(buf2, buf2 + blen);
      send_tok.value = buf2;
      send_tok.length = len2;

      temp_null_tok.value = service;
      temp_null_tok.length = strlen(service) + 1;

      maj_stat = gss_import_name(&min_stat, &temp_null_tok,
	  gss_nt_service_name, &target_name);

    }
  else
    {
      send_tok.value = service;
      send_tok.length = strlen(service) + 1;

      maj_stat = gss_import_name(&min_stat, &send_tok,
	  gss_nt_service_name, &target_name);
    }

  if (server_tok)
    {
      blen = box_length(server_tok);
      buf = dk_alloc_box(blen, DV_SHORT_STRING);
      memcpy (buf, server_tok, blen);
      len = decode_base64(buf, buf + blen);
      token_ptr = &recv_tok;
      recv_tok.value = buf;
      recv_tok.length = len;
    }
  else
    token_ptr = GSS_C_NO_BUFFER;

  gcontext = GSS_C_NO_CONTEXT;
  gcontext = (gss_ctx_id_t) my_gcontext;
  mech_type = GSS_C_NO_OID;
  memset((char *)&chan, 0, sizeof (chan));

  maj_stat = gss_init_sec_context(&min_stat, GSS_C_NO_CREDENTIAL,
	                          &gcontext,
	                          target_name,
	                          mech_type,
/*	                          GSS_C_MUTUAL_FLAG | GSS_C_REPLAY_FLAG | GSS_C_DELEG_FLAG,*/
	                          GSS_C_MUTUAL_FLAG | GSS_C_REPLAY_FLAG,
	                          0,
	                          &chan,     /* channel bindings */
	                          token_ptr,
	                          NULL,      /* ignore mech type */
	                          &send_tok,
	                          NULL,      /* ignore ret_flags */
	                          NULL);

  if (maj_stat != GSS_S_COMPLETE && maj_stat!=GSS_S_CONTINUE_NEEDED)
    {
      srv_make_gss_error(maj_stat, min_stat, "KRBXX");
    }

  memset((char *)&temp_send_tok, 0, sizeof (temp_send_tok));
  temp_test_int = encode_base64 ((char *) send_tok.value, temp_send_tok, send_tok.length);
  gss_release_buffer(&min_stat, &send_tok);

  dk_set_push (&ret, box_dv_short_string (temp_send_tok));
  dk_set_push (&ret, box_num ((long) gcontext));

  return list_to_array (dk_set_nreverse (ret));
}


static caddr_t
kerberos_server_auth (caddr_t in_tok, caddr_t service_name)
{
  OM_uint32 accept_maj, accept_min, acquire_maj, acquire_min, maj_stat, min_stat;
  gss_ctx_id_t gcontext;
  gss_OID mech_type;
  struct gss_channel_bindings_struct chan;
  gss_buffer_desc *token_ptr;
  gss_buffer_desc tok;
  gss_cred_id_t server_creds;
  gss_cred_id_t deleg_creds;
  gss_name_t server_name;
  gss_buffer_desc name_buf;
  gss_buffer_desc out_tok;
  gss_name_t client;
  gss_OID mechid;
  char temp_out_tok [KRB_TOK_SIZE];
  int temp_test_int;
  OM_uint32 ret_flags;
  caddr_t buf;
  dk_set_t ret = NULL;
  uint32 len, blen;

  blen = box_length(in_tok);
  buf = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf, in_tok, blen);
  len = decode_base64(buf, buf + blen);
  tok.value = buf;
  tok.length = len;

  token_ptr = GSS_C_NO_BUFFER;
  mech_type = GSS_C_NO_OID;
  memset((char *)&chan, 0, sizeof (chan));

  name_buf.value = service_name;
  name_buf.length = strlen((char *) name_buf.value) + 1;

  maj_stat = gss_import_name(&min_stat, &name_buf,
      gss_nt_service_name,
      &server_name);

  gss_release_buffer(&min_stat, &name_buf);

  if (maj_stat != GSS_S_COMPLETE)
    {
      srv_make_gss_error(maj_stat, min_stat, "KRBXX");
      return 0;
    }

  acquire_maj = gss_acquire_cred(&acquire_min, server_name, 0,
      GSS_C_NULL_OID_SET, GSS_C_ACCEPT,
      &server_creds, NULL, NULL);

  if (acquire_maj != GSS_S_COMPLETE)
    {
      srv_make_gss_error(acquire_maj, acquire_min, "KRBXX");
      return 0;
    }

  gcontext = GSS_C_NO_CONTEXT;

  accept_maj = gss_accept_sec_context(&accept_min,
                                      &gcontext,
                                      server_creds,
                                      &tok,
                                      &chan,
                                      &client,
                                      &mechid,
                                      &out_tok,
                                      &ret_flags,
                                      NULL,
                                      &deleg_creds
                                      );

  if (accept_maj != GSS_S_COMPLETE)
    {
      srv_make_gss_error(accept_maj, accept_min, "KRBXX");
    }

  memset((char *)&temp_out_tok, 0, sizeof (temp_out_tok));
  temp_test_int = encode_base64 ((char *) out_tok.value, temp_out_tok, out_tok.length);
  gss_release_buffer(&min_stat, &out_tok);

  dk_set_push (&ret, box_dv_short_string (temp_out_tok));
  dk_set_push (&ret, box_num ((long) gcontext));

  return list_to_array (dk_set_nreverse (ret));
}


static caddr_t
bif_kerberos_get_tgt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  struct k5_data k5;
  krb5_error_code code = 0;
  krb5_creds my_creds;
  krb5_get_init_creds_opt options;
  krb5_deltat lifetime = 0, rlife = 0;
  long forwardable = 0, proxiable = 0;

  krb5_ticket *my_tiket;
  char temp_base_enc [KRB_BUFF_SIZE];
  caddr_t ret, lifetime_in = NULL, rlife_in = NULL;

  caddr_t principal_name = bif_string_arg (qst, args, 0, "kerberos_get_tgt");
  caddr_t krb_password = bif_string_arg (qst, args, 1, "kerberos_get_tgt");

  if (BOX_ELEMENTS (args) > 2)
    {
      lifetime_in = bif_string_arg (qst, args, 2, "kerberos_get_tgt");

      code = krb5_string_to_deltat(lifetime_in, &lifetime);
      if (code != 0 || lifetime == 0)
	{
	  sqlr_new_error ("42000", "xxxxx", "while convert lifetime");
	}
    }

  if (BOX_ELEMENTS (args) > 3)
    {
      rlife_in = bif_string_arg (qst, args, 3, "kerberos_get_tgt");

      code = krb5_string_to_deltat(rlife_in, &rlife);
      if (code != 0 || rlife == 0)
	{
	  sqlr_new_error ("42000", "xxxxx", "while convert renewable lifetime");
	}
    }

  if (BOX_ELEMENTS (args) > 4)
    forwardable = bif_long_arg (qst, args, 3, "kerberos_get_tgt");

  if (BOX_ELEMENTS (args) > 5)
    proxiable = bif_long_arg (qst, args, 3, "kerberos_get_tgt");

  if (krb5_init_context(&k5.ctx))
    {
       sqlr_new_error ("42000", "KB001", "while initializing Kerberos 5 library");
    }

  if ((code = krb5_cc_default(k5.ctx, &k5.cc)))
    {
      sqlr_new_error ("42000", "KB002", "while getting default cache");
    }

  if ((code = krb5_parse_name(k5.ctx, principal_name, &k5.me)))
    {
      sqlr_new_error ("42000", "KB003",  "when parsing name %s", principal_name);
    }

  if (krb5_unparse_name(k5.ctx, k5.me, &k5.name))
    {
      sqlr_new_error ("42000", "KB004", "when unparsing name");
    }

  krb5_get_init_creds_opt_init(&options);
  memset(&my_creds, 0, sizeof(my_creds));

  if (lifetime)
    krb5_get_init_creds_opt_set_tkt_life(&options, lifetime);

  if (rlife)
    krb5_get_init_creds_opt_set_renew_life(&options, rlife);

  if (forwardable)
    krb5_get_init_creds_opt_set_forwardable(&options, 1);
  else
    krb5_get_init_creds_opt_set_forwardable(&options, 0);

  if (proxiable)
    krb5_get_init_creds_opt_set_proxiable(&options, 1);
  else
    krb5_get_init_creds_opt_set_proxiable(&options, 0);

  krb5_get_init_creds_opt_set_address_list(&options, NULL);

  /*code = krb5_get_init_creds_keytab(k5.ctx, &my_creds, k5.me,
      keytab, 0, NULL, &options);*/

  krb5_get_init_creds_password(k5.ctx, &my_creds, k5.me, krb_password,
                               NULL, 0, 0, NULL, &options);

  code = krb5_decode_ticket(&my_creds.ticket, &my_tiket);

  memset(&temp_base_enc, 0, sizeof(temp_base_enc));
  encode_base64 (my_creds.ticket.data, temp_base_enc, my_creds.ticket.length);

  ret = box_dv_short_string (temp_base_enc);

  if (krb5_cc_initialize(k5.ctx, k5.cc, k5.me))
    {
      sqlr_new_error ("42000", "KB005", "when initializing credential cache (ccache)");
    }

  if (!my_creds.server)
    {
       sqlr_new_error ("42000", "KB006", "wrong password");
    }

  if (krb5_cc_store_cred(k5.ctx, k5.cc, &my_creds))
    {
       sqlr_new_error ("42000", "KB007", "while storing credentials");
    }

  k5_end(&k5, 1);

  return ret;
}


static caddr_t
bif_kerberos_destroy_tiket (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  struct k5_data k5;
  krb5_error_code code = 0;
  caddr_t principal_name = NULL;


  if (BOX_ELEMENTS (args) > 0)
    principal_name = bif_string_arg (qst, args, 0, "kerberos_destroy_tiket");

  memset(&k5, 0, sizeof(k5));

  if (krb5_init_context(&k5.ctx))
    {
       sqlr_new_error ("42000", "KB008", "while initializing Kerberos 5 library");
    }

  if (principal_name)
    {
      if (krb5_cc_resolve (k5.ctx, principal_name, &k5.cc))
	sqlr_new_error ("42000", "KB009", "while getting %s credential cache (ccache)", principal_name);
    }
  else
    {
      if ((code = krb5_cc_default(k5.ctx, &k5.cc)))
	sqlr_new_error ("42000", "KB010", "while getting default credential cache (ccache)");
    }

  if (krb5_cc_destroy (k5.ctx, k5.cc))
      sqlr_new_error ("42000", "KB011", "while getting remove credential cache (ccache)");

  k5_end(&k5, 0);

  return box_num (1);
}


static caddr_t
bif_kerberos_free_context (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{

  long gcontext = bif_long_arg (qst, args, 0, "kerberos_free_context");

  /* XXX TO DO ADD VALIDATE OF CONTEXT XXX */
  krb5_free_context ((gss_ctx_id_t) gcontext);

  return box_num (1);
}


static caddr_t
kerberos_encrypt_tst (long mode, char *message, char *hostname, char *service)
{
  struct servent *serv;
  struct hostent *host;
  char *cp;
  char full_hname[MAXHOSTNAMELEN];
  struct sockaddr_in s_sock;		/* server address */
  struct sockaddr_in c_sock;		/* client address */

  short port = 0;  /* XXX TODO GET FROM SESSION XXX */

  krb5_error_code retval;
  krb5_data packet, inbuf;
  krb5_ccache ccdef;
  krb5_address addr; /*portlocal_addr; XXX Need later */
  krb5_rcache rcache;
  krb5_data rcache_name;

  krb5_context context;
  krb5_auth_context auth_context = NULL;

  dk_set_t ret = NULL;
  char temp_out_tok [KRB_TOK_SIZE];
  int temp_test_int;

  if (krb5_init_context(&context))
    {
      sqlr_new_error ("42000", "KRBXX", "while initializing Kerberos 5 library");
    }


  /* Look up server host */
  if ((host = gethostbyname(hostname)) == (struct hostent *) 0)
    {
      sqlr_new_error ("42000", "KRBXX", "%s: unknown host", hostname);
    }

  strncpy(full_hname, host->h_name, sizeof(full_hname)-1);
  full_hname[sizeof(full_hname)-1] = '\0';

  for (cp = full_hname; *cp; cp++)
    if (isupper(*cp))
      *cp = tolower(*cp);

  (void) memset((char *)&s_sock, 0, sizeof(s_sock));
  memcpy((char *)&s_sock.sin_addr, host->h_addr, sizeof(s_sock.sin_addr));
  s_sock.sin_family = AF_INET;

  if (port == 0)
    s_sock.sin_port = serv->s_port;
  else
    s_sock.sin_port = htons(port);

  memset((char *)&c_sock, 0, sizeof(c_sock));
  c_sock.sin_family = AF_INET;

  /* Bind it to set the address; kernel will fill in port # */
  /* XXX TODO FILL REAL c_sock */
  /*
     if (bind(sock, (struct sockaddr *)&c_sock, sizeof(c_sock)) < 0) {
     com_err(progname, errno, "while binding datagram socket");
     exit(1);
     }
   */

  inbuf.data = hostname;
  inbuf.length = strlen(hostname);

  /* Get credentials for server */
  if ((retval = krb5_cc_default(context, &ccdef)))
    {
      sqlr_new_error ("42000", "KRBXX", "while getting default credential cache (ccache)");
    }

  if ((retval = krb5_mk_req(context, &auth_context, 0, service, full_hname,
	  &inbuf, ccdef, &packet)))
    {
      sqlr_new_error ("42000", "KRBXX", "while preparing AP_REQ");
    }

  /* "connect" the datagram socket; this is necessary to get a local address
     properly bound for getsockname() below. */
  /* XXX TODO FILL REAL c_sock */

  memset((char *)&s_sock, 0, sizeof(s_sock));
  /*  if (connect(sock, (struct sockaddr *)&s_sock, sizeof(s_sock)) == -1) {
      com_err(progname, errno, "while connecting to server");
      exit(1);
      }*/

  memset((char *)&temp_out_tok, 0, sizeof (temp_out_tok));
  temp_test_int = encode_base64 (packet.data, temp_out_tok, packet.length);
  dk_set_push (&ret, box_dv_short_string (temp_out_tok));

  krb5_free_data_contents(context, &packet);

  /* PREPARE KRB_SAFE MESSAGE */

  /* Get my address */
  /* XXX TODO FILL REAL c_sock */
  memset((char *) &c_sock, 0, sizeof(c_sock));
  /*
     i = sizeof(c_sock);
     if (getsockname(sock, (struct sockaddr *)&c_sock, &i) < 0) {
     com_err(progname, errno, "while getting socket name");
     exit(1);
     }*/

  addr.addrtype = ADDRTYPE_IPPORT;
  addr.length = sizeof(c_sock.sin_port);
  addr.contents = (krb5_octet *)&c_sock.sin_port;
  if ((retval = krb5_auth_con_setports(context, auth_context,
	  &addr, NULL)))
    {
      sqlr_new_error ("42000", "KRBXX", "while setting local port");
    }

  addr.addrtype = ADDRTYPE_INET;
  addr.length = sizeof(c_sock.sin_addr);
  addr.contents = (krb5_octet *)&c_sock.sin_addr;
  if ((retval = krb5_auth_con_setaddrs(context, auth_context,
	  &addr, NULL)))
    {
      sqlr_new_error ("42000", "KRBXX", "while setting local addr");
    }

  /*
     if ((retval = krb5_gen_portaddr(context, &addr, (krb5_pointer) &c_sock.sin_port,
     &portlocal_addr)))
     {
     sqlr_new_error ("42000", "KRBXX", "while generating port address");
     }
   */

  rcache_name.length = strlen(full_hname);
  rcache_name.data = full_hname;

  if ((retval = krb5_get_server_rcache(context, &rcache_name, &rcache)))
    {
      sqlr_new_error ("42000", "KRBXX", "while getting server rcache");
    }

  krb5_auth_con_setrcache(context, auth_context, rcache);

  /* Make the safe message */
  inbuf.data = message;
  inbuf.length = strlen(message);

  if (mode)
    retval = krb5_mk_priv(context, auth_context, &inbuf, &packet, NULL);
  else
    retval = krb5_mk_safe(context, auth_context, &inbuf, &packet, NULL);

  if (retval)
    {
      sqlr_new_error ("42000", "KRBXX", "while making KRB_SAFE message");
    }

  memset((char *)&temp_out_tok, 0, sizeof (temp_out_tok));
  temp_test_int = encode_base64 (packet.data, temp_out_tok, packet.length);
  dk_set_push (&ret, box_dv_short_string (temp_out_tok));

  krb5_free_data_contents(context, &packet);

  krb5_auth_con_free(context, auth_context);
  krb5_free_context(context);

  return list_to_array (dk_set_nreverse (ret));
}


static caddr_t
kerberos_decrypt_tst (int mode, caddr_t auth_tok, caddr_t mess_tok, caddr_t service)
{

  /*  struct servent *serv;
      struct hostent *host;*/
  struct sockaddr_in s_sock;		/* server's address */
  struct sockaddr_in c_sock;		/* client's address */

  krb5_keytab keytab = NULL;
  krb5_error_code retval;
  krb5_data packet, message;
  krb5_principal sprinc;
  krb5_context context;
  krb5_auth_context auth_context = NULL;
  krb5_address addr;
  krb5_ticket *ticket = NULL;
  caddr_t buf_auth, buf_mess, ret;
  uint32 len_auth, len_mess, blen;

  blen = box_length(auth_tok);
  buf_auth = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf_auth, auth_tok, blen);
  len_auth = decode_base64(buf_auth, buf_auth + blen);

  blen = box_length(mess_tok);
  buf_mess = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf_mess, mess_tok, blen);
  len_mess = decode_base64(buf_mess, buf_mess + blen);

  if (krb5_init_context(&context))
    {
      sqlr_new_error ("42000", "KRBXX", "while initializing Kerberos 5 library");
    }

  if ((retval = krb5_sname_to_principal(context, NULL, service,
	  KRB5_NT_SRV_HST, &sprinc)))
    {
      sqlr_new_error ("42000", "KRBXX", "while generating service name %s", service);
    }

  /* Set up server address */
  memset((char *)&s_sock, 0, sizeof(s_sock));
  s_sock.sin_family = AF_INET;

  /* Look up service
     if (port == 0) {
     s_sock.sin_port = serv->s_port;
     } else {
     s_sock.sin_port = htons(port);
     }

     if (gethostname(full_hname, sizeof(full_hname)) < 0)
     {
     sqlr_new_error ("42000", "KRBXX", "while gethostname");
     }

     if ((host = gethostbyname(full_hname)) == (struct hostent *)0)
     {
     fprintf(stderr, "%s: host unknown\n", full_hname);
     exit(1);
     }
     memcpy((char *)&s_sock.sin_addr, host->h_addr, sizeof(s_sock.sin_addr));*/

  /* Open socket
     if ((sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0)
     {
     sqlr_new_error ("42000", "KRBXX", "opening datagram socket");
     }
   */
  /* Let the socket be reused right away
     (void) setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char *)&on,
     sizeof(on));*/

  /* Bind the socket
     if (bind(sock, (struct sockaddr *)&s_sock, sizeof(s_sock)))
     {
     sqlr_new_error ("42000", "KRBXX", "binding datagram socket");
     }*/

  /* GET KRB_AP_REQ MESSAGE */

  /* use "recvfrom" so we know client's address
     i = sizeof(struct sockaddr_in);
     if ((i = recvfrom(sock, (char *)pktbuf, sizeof(pktbuf), flags,
     (struct sockaddr *)&c_sock, &i)) < 0) {
     perror("receiving datagram");
     exit(1);
     }
   */

  packet.length = len_auth;
  packet.data = (krb5_pointer) buf_auth;

  /* Check authentication info */
  if ((retval = krb5_rd_req(context, &auth_context, &packet,
	  sprinc, keytab, NULL, &ticket)))
    {
      sqlr_new_error ("42000", "KRBXX", "while check authentication info");
    }

  /* Set foreign_addr for rd_safe() and rd_priv() */
  memset((char *)&c_sock, 0, sizeof(c_sock));
  addr.addrtype = ADDRTYPE_INET;
  addr.length = sizeof(c_sock.sin_addr);
  addr.contents = (krb5_octet *)&c_sock.sin_addr;

  if ((retval = krb5_auth_con_setaddrs(context, auth_context,
	  NULL, &addr)))
    {
      sqlr_new_error ("42000", "KRBXX", "while setting foreign addr");
    }

  memset((char *)&c_sock, 0, sizeof(c_sock));
  addr.addrtype = ADDRTYPE_IPPORT;
  addr.length = sizeof(c_sock.sin_port);
  addr.contents = (krb5_octet *)&c_sock.sin_port;

  if ((retval = krb5_auth_con_setports(context, auth_context, NULL, &addr)))
    {
      sqlr_new_error ("42000", "KRBXX", "while setting foreign port");
    }

  packet.length = len_mess;
  packet.data = (krb5_pointer) buf_mess;

  if (mode)
    retval = krb5_rd_priv(context, auth_context, &packet, &message, NULL);
  else
    retval = krb5_rd_safe(context, auth_context, &packet, &message, NULL);

  if (retval)
    {
      sqlr_new_error ("42000", "KRBXX", "while verifying message");
    }

  ret = box_dv_short_string (message.data);

  krb5_auth_con_free(context, auth_context);
  krb5_free_context(context);

  return ret;
}


static void
kerberos_get_tiket_info (caddr_t auth_tok, caddr_t service, dk_set_t *ret)
{
  char *cp;
  krb5_keytab keytab = NULL;
  krb5_error_code retval;
  krb5_data packet;
  krb5_principal sprinc;
  krb5_context context;
  krb5_auth_context auth_context = NULL;
  krb5_ticket *ticket = NULL;
  krb5_keyblock *keyblock;
  caddr_t buf_auth;
  uint32 len_auth, blen;
  char temp_out_tok [KRB_TOK_SIZE];

  blen = box_length(auth_tok);
  buf_auth = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf_auth, auth_tok, blen);
  len_auth = decode_base64(buf_auth, buf_auth + blen);

  if (krb5_init_context(&context))
    {
      sqlr_new_error ("42000", "KRBXX", "while initializing Kerberos 5 library");
    }

  if ((retval = krb5_sname_to_principal(context, NULL, service,
	  KRB5_NT_SRV_HST, &sprinc)))
    {
      sqlr_new_error ("42000", "KRBXX", "while generating service name %s", service);
    }

  packet.length = len_auth;
  packet.data = (krb5_pointer) buf_auth;

  /* Check authentication info */
  if (krb5_rd_req(context, &auth_context, &packet,
	  sprinc, keytab, NULL, &ticket))
    {
      sqlr_new_error ("42000", "KRBXX", "while check authentication info");
    }

  if (krb5_unparse_name(context, ticket->server, &cp))
    {
      sqlr_new_error ("42000", "KRBXX", "while unparsing server name");
    }
  dk_set_push (ret, box_dv_short_string ("__server"));
  dk_set_push (ret, box_dv_short_string (cp));

  if (krb5_unparse_name(context, ticket->enc_part2->client, &cp))
    {
      sqlr_new_error ("42000", "KRBXX", "while unparsing client name");
    }

  if (krb5_auth_con_getkey (context, auth_context, &keyblock))
    {
      sqlr_new_error ("42000", "KRBXX", "while get service key");
    }

  dk_set_push (ret, box_dv_short_string ("__client"));
  dk_set_push (ret, box_dv_short_string (cp));

  dk_set_push (ret, box_dv_short_string ("__starttime"));
  dk_set_push (ret, box_num (ticket->enc_part2->times.starttime));

  dk_set_push (ret, box_dv_short_string ("__endtime"));
  dk_set_push (ret, box_num (ticket->enc_part2->times.endtime));

  dk_set_push (ret, box_dv_short_string ("__authtime"));
  dk_set_push (ret, box_num (ticket->enc_part2->times.authtime));

  memset((char *)&temp_out_tok, 0, sizeof (temp_out_tok));
  encode_base64 (keyblock->contents, temp_out_tok, keyblock->length);
  dk_set_push (ret, box_dv_short_string ("__sesionkey"));
  dk_set_push (ret, box_dv_short_string (temp_out_tok));

  krb5_auth_con_free(context, auth_context);
  krb5_free_context(context);
}


static caddr_t
bif_kerberos_server_auth (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t in_tok = bif_string_arg (qst, args, 0, "kerberos_server_auth");
  caddr_t service_name = bif_string_arg (qst, args, 1, "kerberos_server_auth");

  return kerberos_server_auth (in_tok, service_name);
}


static caddr_t
bif_kerberos_client_auth (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long my_gcontext = bif_long_arg (qst, args, 0, "kerberos_client_auth");
  caddr_t my_tok = bif_string_or_null_arg (qst, args, 1, "kerberos_client_auth");
  caddr_t server_tok = bif_string_or_null_arg (qst, args, 2, "kerberos_client_auth");
  caddr_t service = bif_string_or_null_arg (qst, args, 3, "kerberos_client_auth");

  return kerberos_client_auth (my_gcontext, my_tok, server_tok, service);
}


static caddr_t
bif_kerberos_get_tiket_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t auth_tok = bif_string_or_null_arg (qst, args, 0, "kerberos_decrypt_tst");
  caddr_t service = bif_string_or_null_arg (qst, args, 1, "kerberos_decrypt_tst");

  dk_set_t ret = NULL;

  kerberos_get_tiket_info (auth_tok, service, &ret);

  return list_to_array (dk_set_nreverse (ret));
}


static caddr_t
bif_kerberos_encrypt_tst (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* 0 - save; 1 - encr */
  long mode = bif_long_arg (qst, args, 0, "kerberos_encrypt_tst");
  caddr_t message = bif_string_or_null_arg (qst, args, 1, "kerberos_encrypt_tst");
  caddr_t hostname = bif_string_or_null_arg (qst, args, 2, "kerberos_encrypt_tst");
  caddr_t service = bif_string_or_null_arg (qst, args, 3, "kerberos_encrypt_tst");

  return kerberos_encrypt_tst (mode, message, hostname, service);
}


static caddr_t
bif_kerberos_decrypt_tst (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long mode = bif_long_arg (qst, args, 0, "kerberos_decrypt_tst");
  caddr_t auth_tok = bif_string_or_null_arg (qst, args, 1, "kerberos_decrypt_tst");
  caddr_t mess_tok = bif_string_or_null_arg (qst, args, 2, "kerberos_decrypt_tst");
  caddr_t service = bif_string_or_null_arg (qst, args, 3, "kerberos_decrypt_tst");

  return kerberos_decrypt_tst (mode, auth_tok, mess_tok, service);
}

void
print_token (gss_buffer_t tok)
{
#if 0
  int i;
  unsigned char *p = tok->value;

  for (i=0; i < tok->length; i++, p++)
    {
      fprintf(stderr, "%02x ", *p);
      if ((i % 16) == 15)
	{
	  fprintf(stderr, "\n");
	}
    }
  fprintf(stderr, "\n");
#endif
}

caddr_t
krb_unseal (gss_ctx_id_t context, caddr_t in_buf_cont)
{
  OM_uint32 maj_stat, min_stat;
  gss_buffer_desc in_buf, out_buf;
  caddr_t ret, buf;
  uint32 len, blen;
  int conf_state;

  blen = box_length(in_buf_cont);
  buf = dk_alloc_box(blen, DV_SHORT_STRING);
  memcpy (buf, in_buf_cont, blen);
  len = decode_base64(buf, buf + blen);

  in_buf.value = buf;
  in_buf.length = len;

  GSS_TRY (maj_stat = gss_unwrap(&min_stat, context,
      		        &in_buf,  &out_buf, &conf_state, NULL), "KRBXX");

  ret = box_dv_short_string (out_buf.value);
  gss_release_buffer(&min_stat, &out_buf);

  return ret;
}

caddr_t
krb_seal (gss_ctx_id_t context, caddr_t in_buf_cont)
{
  OM_uint32 maj_stat, min_stat;
  gss_buffer_desc in_buf, out_buf;
  char temp_out_buf [KRB_BUFF_SIZE];
  int conf_state, temp_test_int;

  in_buf.value = in_buf_cont;
  in_buf.length = strlen(in_buf_cont) + 1;

  GSS_TRY (maj_stat = gss_wrap(&min_stat, context, 0,
      		      GSS_C_QOP_DEFAULT,
		      &in_buf, &conf_state, &out_buf), "KRBXX");

  memset((char *)&temp_out_buf, 0, sizeof (temp_out_buf));
  temp_test_int = encode_base64 (out_buf.value, temp_out_buf, out_buf.length);

  gss_release_buffer(&min_stat, &out_buf);

  return box_dv_short_string (temp_out_buf);
}



/*##
  this function starts talk with a service,
  service_name, desired service
  context, output, to be used in seal & unseal
  tkt, output, base64 encoded TGS to be sent to service
 */
void
krb_init_ctx (char * service_name, gss_ctx_id_t * context, caddr_t * tkt)
{
  gss_buffer_desc send_tok, *token_ptr;
  gss_name_t target_name;
  OM_uint32 maj_stat, min_stat;
  gss_OID oid = GSS_C_NULL_OID;
  OM_uint32 ret_flags;
  gss_cred_id_t creds;

  send_tok.value = service_name;
  send_tok.length = strlen(service_name) + 1;

  GSS_TRY (maj_stat = gss_import_name(&min_stat, &send_tok,
      (gss_OID) gss_nt_service_name, &target_name), "42000");

  print_token (&send_tok);

  token_ptr = GSS_C_NO_BUFFER;
  *context = GSS_C_NO_CONTEXT;

  GSS_TRY (maj_stat = gss_acquire_cred (&min_stat, GSS_C_NO_NAME, 0,
      GSS_C_NULL_OID_SET, GSS_C_INITIATE,
      &creds, NULL, NULL), "42000");

  GSS_TRY1 (maj_stat = gss_init_sec_context(&min_stat,
                                 creds /*GSS_C_NO_CREDENTIAL*/,
                                 context,
                                 target_name,
                                 oid,
                                 GSS_C_SEQUENCE_FLAG|GSS_C_REPLAY_FLAG|GSS_C_TRANS_FLAG /*| GSS_C_MUTUAL_FLAG*/,
                                 0,
                                 NULL,   /* no channel bindings */
                                 token_ptr,
                                 NULL,   /* ignore mech type */
                                 &send_tok,
                                 &ret_flags,
                                 NULL),
      "42000");  /* ignore time_rec */

  print_token (&send_tok);
  *tkt = dk_alloc_box_zero ((send_tok.length * 2) + 1, DV_STRING);
  encode_base64 (send_tok.value, *tkt, send_tok.length);
}

/*##
  This function starts talk on server side,
  service_name is a name of this service
  tkt, in token from client, needs to be decoded first !!
  out, context hdl, to be used in unseal & brothers
 */
void
krb_init_srv_ctx (caddr_t service_name, caddr_t tkt, gss_ctx_id_t * context)
{
  gss_buffer_desc name_buf;
  gss_name_t server_name;
  OM_uint32 maj_stat, min_stat;
  gss_cred_id_t server_creds;

  gss_buffer_desc rec_tkt, send_tok;
  gss_name_t client;
  gss_OID doid;
  OM_uint32 ret_flags;

  rec_tkt.length = box_length (tkt) - 1;
  rec_tkt.value = box_copy (tkt);

  name_buf.value = box_copy (service_name);
  name_buf.length = strlen (name_buf.value) + 1;

  GSS_TRY (maj_stat = gss_import_name (&min_stat, &name_buf, (gss_OID) gss_nt_service_name, &server_name),
      "42000");

  GSS_TRY (maj_stat = gss_acquire_cred (&min_stat, server_name, 0,
      GSS_C_NULL_OID_SET, GSS_C_ACCEPT,
      &server_creds, NULL, NULL), "42000");

  *context = GSS_C_NO_CONTEXT;

  GSS_TRY (maj_stat =
      gss_accept_sec_context(&min_stat,
	  context,
	  server_creds,
	  &rec_tkt,
	  GSS_C_NO_CHANNEL_BINDINGS,
	  &client,
	  &doid,
	  &send_tok,
	  &ret_flags,
	  NULL, 	/* ignore time_rec */
	  NULL), "42000"); 	/* ignore del_cred_handle */

  gss_release_name(&min_stat, &server_name);

}


#define _GSS_TRY(o, vc) if (GSS_S_COMPLETE != (o)) \
			return -1;

/*
  copy of previous procedure,
  the difference is that this one does not throw errors,
  but returns error code -1
*/
int
_krb_init_srv_ctx (caddr_t service_name, caddr_t tkt, gss_ctx_id_t * context)
{
  gss_buffer_desc name_buf;
  gss_name_t server_name;
  OM_uint32 maj_stat, min_stat;
  gss_cred_id_t server_creds;

  gss_buffer_desc rec_tkt, send_tok;
  gss_name_t client;
  gss_OID doid;
  OM_uint32 ret_flags;

  rec_tkt.length = box_length (tkt) - 1;
  rec_tkt.value = box_copy (tkt);

  name_buf.value = box_copy (service_name);
  name_buf.length = strlen (name_buf.value) + 1;

  _GSS_TRY (maj_stat = gss_import_name (&min_stat, &name_buf, (gss_OID) gss_nt_service_name, &server_name),
      "42000");

  _GSS_TRY (maj_stat = gss_acquire_cred (&min_stat, server_name, 0,
      GSS_C_NULL_OID_SET, GSS_C_ACCEPT,
      &server_creds, NULL, NULL), "42000");

  *context = GSS_C_NO_CONTEXT;

  _GSS_TRY (maj_stat =
      gss_accept_sec_context(&min_stat,
	  context,
	  server_creds,
	  &rec_tkt,
	  GSS_C_NO_CHANNEL_BINDINGS,
	  &client,
	  &doid,
	  &send_tok,
	  &ret_flags,
	  NULL, 	/* ignore time_rec */
	  NULL), "42000"); 	/* ignore del_cred_handle */

  gss_release_name(&min_stat, &server_name);

  return 0;
}


static caddr_t
bif_krb_init_ctx (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "krb_init_ctx";
  caddr_t service_name = bif_string_arg (qst, args, 0, me);
  gss_ctx_id_t context;
  caddr_t tkt = NULL;

  krb_init_ctx (service_name, &context, &tkt);

  return list (2, box_num ((ptrlong)(void*)context), tkt);

}

static caddr_t
bif_krb_inquire_ctx (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "krb_inquire_ctx";
  caddr_t _context = (caddr_t) bif_long_arg (qst, args, 0, me);
  long type = bif_long_arg (qst, args, 1, me);
  gss_name_t src_name, targ_name;
  gss_buffer_desc    sname, tname;
  OM_uint32          lifetime;
  gss_OID            mechanism, name_type;
  int                is_local;
  int                is_open;
  OM_uint32          context_flags;
  OM_uint32 maj_stat, min_stat;
  gss_buffer_desc mech;
  gss_ctx_id_t context = (gss_ctx_id_t) unbox(_context);
  caddr_t ret;

#if 0
  ctx_tok.value = box_copy (_context);
  ctx_tok.length = box_length (_context) - 1;

  GSS_TRY (maj_stat = gss_import_sec_context (&min_stat, &ctx_tok, &context), "42000");
#endif

  GSS_TRY(maj_stat = gss_inquire_context(&min_stat, context,
	&src_name, &targ_name, &lifetime,
	&mechanism, &context_flags,
	&is_local,
	&is_open), "42000");

  GSS_TRY(maj_stat = gss_display_name(&min_stat, src_name, &sname,
	&name_type), "42000");

  GSS_TRY (maj_stat = gss_display_name(&min_stat, targ_name, &tname,
	(gss_OID *) NULL), "42000");

  GSS_TRY (maj_stat = gss_oid_to_str (&min_stat, mechanism, &mech), "42000");

#if 1
  fprintf(stderr, "\"%.*s\" to \"%.*s\", lifetime %d, flags %x, %s, %s mech: %.*s\n",
      (int) sname.length, (char *) sname.value,
      (int) tname.length, (char *) tname.value, lifetime,
      context_flags,
      (is_local) ? "locally initiated" : "remotely initiated",
      (is_open) ? "open" : "closed", (int) mech.length, (char*) mech.value);
#endif

  ret = NULL;
  switch (type)
    {
      case 1: /* flags */
	    {
	      ret = box_num (context_flags);
	      break;
	    }
      case 2: /* Source */
	    {
	      ret = box_line ((char *)sname.value, (int)sname.length);
	      break;
	    }
      case 3: /* Target */
	    {
	      ret = box_line ((char *)tname.value, (int)tname.length);
	      break;
	    }
      case 4: /* time-to-live */
	    {
	      ret = box_num (lifetime);
	      break;
	    }
      case 5: /* local/remote */
	    {
	      ret = box_num (is_local);
	      break;
	    }
      default:
	  sqlr_new_error ("22023", "KRBXX", "Invalid ticket info index %ld", type);
    }



  (void) gss_release_name(&min_stat, &src_name);
  (void) gss_release_name(&min_stat, &targ_name);
  (void) gss_release_buffer(&min_stat, &sname);
  (void) gss_release_buffer(&min_stat, &tname);

  return ret ? ret : dk_alloc_box (0, DV_DB_NULL);
}

static caddr_t
bif_krb_init_srv_ctx (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "krb_init_srv_ctx";
  caddr_t service_name = bif_string_arg (qst, args, 0, me);
  caddr_t tkt = bif_string_arg (qst, args, 1, me);
  gss_ctx_id_t context;

  krb_init_srv_ctx (service_name, tkt, &context);

  return box_num ((ptrlong)(void*)context);
}

static caddr_t
bif_kerberos_seal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long my_gcontext = bif_long_arg (qst, args, 0, "kerberos_seal");
  caddr_t in_buf_cont = bif_string_or_null_arg (qst, args, 1, "kerberos_seal");

  return krb_seal ((gss_ctx_id_t) my_gcontext, in_buf_cont);
}


static caddr_t
bif_kerberos_unseal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long my_gcontext = bif_long_arg (qst, args, 0, "kerberos_unseal");
  caddr_t in_buf_cont = bif_string_arg (qst, args, 1, "kerberos_unseal");

  return krb_unseal ((gss_ctx_id_t) my_gcontext, in_buf_cont);
}



static caddr_t
bif_krb_free_context (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long _context = bif_long_arg (qst, args, 0, "krb_free_context");
  gss_ctx_id_t context = (gss_ctx_id_t) _context;
  OM_uint32 maj_stat, min_stat;

  GSS_TRY (maj_stat = gss_delete_sec_context (&min_stat, context, GSS_C_NO_BUFFER /* both should call free*/ ),
      "42000");

  return box_num (1);
}


void
bif_kerberos_init (void)
{
  /* TGT */
  bif_define_ex ("kerberos_get_tgt", bif_kerberos_get_tgt, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_destroy_tiket", bif_kerberos_destroy_tiket, BMD_RET_TYPE, &bt_varchar, BMD_DONE);

  /* old-style auth using GSS API */
  bif_define_ex ("kerberos_client_auth", bif_kerberos_client_auth, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_server_auth", bif_kerberos_server_auth, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_seal", bif_kerberos_seal, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_unseal", bif_kerberos_unseal, BMD_RET_TYPE, &bt_varchar, BMD_DONE);

  /* krb5 API */
  bif_define_ex ("kerberos_encrypt_tst", bif_kerberos_encrypt_tst, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_decrypt_tst", bif_kerberos_decrypt_tst, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_get_tiket_info", bif_kerberos_get_tiket_info, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("kerberos_free_context", bif_kerberos_free_context, BMD_RET_TYPE, &bt_varchar, BMD_DONE);

  /* GSS API  */
  bif_define ("krb_init_ctx", bif_krb_init_ctx);
  bif_define ("krb_inquire_ctx", bif_krb_inquire_ctx);
  bif_define ("krb_init_srv_ctx", bif_krb_init_srv_ctx);
  bif_define ("krb_free_ctx", bif_krb_free_context);

  /* An alias for both seal & unseal */
  bif_define ("krb_seal", bif_kerberos_seal);
  bif_define ("krb_unseal", bif_kerberos_unseal);
}
#endif
