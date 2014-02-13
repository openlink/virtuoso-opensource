/*
 *  bif_ldapcli.c
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

#include "virtpwd.h"
#ifndef WIN95COMPAT
#include "Dk.h"
#include "sqlnode.h"
#include "http.h"
#include "multibyte.h"
#include "sqlbif.h"
#include "libutil.h"
#include <stdlib.h>
#endif
#ifndef NO_LDAP
#ifndef WIN95COMPAT

#ifdef WIN32

#define BERAPI
#define _WINBER_

#define ber_bvdup (CALLBACK *ber_bvdup)
#define ber_bvecfree (CALLBACK *ber_bvecfree)
#define ber_free (CALLBACK *ber_free)
#define ber_bvfree (CALLBACK *ber_bvfree)

#define LDAPAPI
#define _WINLDAP_
#define LdapGetLastError (CALLBACK *LdapGetLastError)
#define ldap_add_s (CALLBACK *ldap_add_s)
#define ldap_bind_s (CALLBACK *ldap_bind_s)
#define ldap_controls_free (CALLBACK *ldap_controls_free)
#define ldap_delete_ext (CALLBACK *ldap_delete_ext)
#define ldap_err2string (CALLBACK *ldap_err2string)
#define ldap_first_attribute (CALLBACK *ldap_first_attribute)
#define ldap_get_dn (CALLBACK *ldap_get_dn)
#define ldap_get_values_len (CALLBACK *ldap_get_values_len)
#define ldap_init (CALLBACK *ldap_init)
#define ldap_memfree (CALLBACK *ldap_memfree)
#define ldap_msgfree (CALLBACK *ldap_msgfree)
#define ldap_modify_s (CALLBACK *ldap_modify_s)
#define ldap_next_attribute (CALLBACK *ldap_next_attribute)
#define ldap_parse_extended_resultA (CALLBACK *ldap_parse_extended_resultA)
#define ldap_parse_reference (CALLBACK *ldap_parse_reference)
#define ldap_parse_result (CALLBACK *ldap_parse_result)
#define ldap_result (CALLBACK *ldap_result)
#define ldap_search_ext (CALLBACK *ldap_search_ext)
#define ldap_set_option (CALLBACK *ldap_set_option)
#define ldap_sslinit (CALLBACK *ldap_sslinit)
#define ldap_unbind (CALLBACK *ldap_unbind)
#define ldap_value_free (CALLBACK *ldap_value_free)

#endif


#ifdef WIN32
#include <winldap.h>
#include <WinBer.h>

#undef ber_bvdup
#undef ldap_init
#undef ldap_sslinit
#undef LdapGetLastError
#undef ldap_get_dn
#undef ldap_memfree
#undef ldap_first_attribute
#undef ldap_next_attribute
#undef ldap_get_values_len
#undef ber_bvecfree
#undef ber_free
#undef ldap_err2string
#undef ldap_value_free
#undef ldap_controls_free
#undef ldap_parse_reference
#undef ldap_parse_extended_resultA
#undef ber_bvfree
#undef ldap_msgfree
#undef ldap_set_option
#undef ldap_bind_s
#undef ldap_search_ext
#undef ldap_unbind
#undef ldap_delete_ext
#undef ldap_result
#undef ldap_parse_result
#undef ldap_add_s
#undef ldap_modify_s


#define LDAP_RES_SEARCH_REFERENCE LDAP_RES_REFERRAL
#define ber_int_t ULONG
#define LDAP_OPT_SUCCESS LDAP_SUCCESS
#define ldap_msgtype(lm) (lm->lm_msgtype)
#define ldap_msgid(lm) (lm->lm_msgid)
#define LDAP_PARSE_REFERENCE(a, b, c, d, e) ldap_parse_reference (a, b, c)
#else
#define LDAP_DEPRECATED 1	/* Enable deprecated prototypes openldap 2.3 */
#include <ldap.h>
#define LDAP_PARSE_REFERENCE(a, b, c, d, e) ldap_parse_reference (a, b, c, d, e)
#endif

#define LDAP_DEF_VERSION LDAP_VERSION3

#ifdef WIN32


#pragma warning ( disable : 4113; disable : 4047 )
dk_mutex_t *ldap_handle_mutex = NULL;
static HMODULE ldap_module = NULL;
static int
ldap_load_ldap_dll ()
{

  ldap_module = LoadLibrary ("wldap32.dll");
  if (!ldap_module)
    return 0;

  ldap_init = GetProcAddress (ldap_module, "ldap_init");
  if (!ldap_init) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_sslinit = GetProcAddress (ldap_module, "ldap_sslinit");
  if (!ldap_sslinit) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  LdapGetLastError = GetProcAddress (ldap_module, "LdapGetLastError");
  if (!LdapGetLastError) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_get_dn = GetProcAddress (ldap_module, "ldap_get_dn");
  if (!ldap_get_dn) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_memfree = GetProcAddress (ldap_module, "ldap_memfree");
  if (!ldap_memfree) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_first_attribute = GetProcAddress (ldap_module, "ldap_first_attribute");
  if (!ldap_first_attribute) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_next_attribute = GetProcAddress (ldap_module, "ldap_next_attribute");
  if (!ldap_next_attribute) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_get_values_len = GetProcAddress (ldap_module, "ldap_get_values_len");
  if (!ldap_get_values_len) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_err2string = GetProcAddress (ldap_module, "ldap_err2string");
  if (!ldap_err2string) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_value_free = GetProcAddress (ldap_module, "ldap_value_free");
  if (!ldap_value_free) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_controls_free = GetProcAddress (ldap_module, "ldap_controls_free");
  if (!ldap_controls_free) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_parse_reference = GetProcAddress (ldap_module, "ldap_parse_reference");
  if (!ldap_parse_reference) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_parse_extended_resultA = GetProcAddress (ldap_module, "ldap_parse_extended_resultA");
  if (!ldap_parse_extended_resultA) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_msgfree = GetProcAddress (ldap_module, "ldap_msgfree");
  if (!ldap_msgfree) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_set_option = GetProcAddress (ldap_module, "ldap_set_option");
  if (!ldap_set_option) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_bind_s = GetProcAddress (ldap_module, "ldap_bind_s");
  if (!ldap_bind_s) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_search_ext = GetProcAddress (ldap_module, "ldap_search_ext");
  if (!ldap_search_ext) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_unbind = GetProcAddress (ldap_module, "ldap_unbind");
  if (!ldap_unbind) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_delete_ext = GetProcAddress (ldap_module, "ldap_delete_ext");
  if (!ldap_delete_ext) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_result = GetProcAddress (ldap_module, "ldap_result");
  if (!ldap_result) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_parse_result = GetProcAddress (ldap_module, "ldap_parse_result");
  if (!ldap_parse_result) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_add_s = GetProcAddress (ldap_module, "ldap_add_s");
  if (!ldap_add_s) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ldap_modify_s = GetProcAddress (ldap_module, "ldap_modify_s");
  if (!ldap_modify_s) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };

  ber_bvdup = GetProcAddress (ldap_module, "ber_bvdup");
  if (!ber_bvdup) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ber_bvecfree = GetProcAddress (ldap_module, "ber_bvecfree");
  if (!ber_bvecfree) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ber_free = GetProcAddress (ldap_module, "ber_free");
  if (!ber_free) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };
  ber_bvfree = GetProcAddress (ldap_module, "ber_bvfree");
  if (!ber_bvfree) { FreeLibrary (ldap_module); ldap_module = NULL; return 0; };

  return 1;
}

#pragma warning ( default : 4113; default : 4047 )
#define ldap_parse_extended_result ldap_parse_extended_resultA

static int
ldap_initialize (LDAP **ld, char * url)
{
  int rc = 0, is_ssl = 0;
  char *proto = NULL, *host = NULL;
  if (url && !strnicmp (url, "ldap://", 7))
    {
      proto = strchr (url + 7, '/');
      if (proto)
	*proto = 0;
      host = url + 7;
    }
  else if (url && !strnicmp (url, "ldaps://", 8))
    {
      proto = strchr (url + 8, '/');
      if (proto)
	*proto = 0;
      host = url + 8;
      is_ssl = 1;
    }
  else
    host = url;
  if (!is_ssl)
    *ld = ldap_init (host, LDAP_PORT);
  else
    *ld = ldap_sslinit (host, LDAP_SSL_PORT, 1);
  if (!*ld)
    rc = LdapGetLastError();
  return rc;
}

char *
ber_strdup(char *s)
{
  char *p;
  size_t len;

  if(s == NULL)
    return NULL;

  len = strlen(s) + 1;

  if ((p = malloc(len)) == NULL)
    return NULL;

  memcpy (p, s, len);
  return p;
}
#endif

caddr_t con_ldap_version_name = NULL;

static int
ldap_get_version (caddr_t * qst)
{
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  caddr_t *ret = (caddr_t *)id_hash_get (cli->cli_globals, (caddr_t) &con_ldap_version_name);
  int ver = LDAP_DEF_VERSION;
  if (ret && DV_LONG_INT == DV_TYPE_OF (*ret))
    {
      ver = unbox (*ret);
      if (ver < LDAP_VERSION_MIN || ver > LDAP_VERSION_MAX)
	ver = LDAP_DEF_VERSION;
    }
  return ver;
}


static void
addmodifyop(LDAPMod ****pmodsp,	int modop, char *attr, struct berval *val)
{
  LDAPMod **pmods;
  int i, j;

  pmods = **pmodsp;
  modop |= LDAP_MOD_BVALUES;

  i = 0;
  if (pmods != NULL)
    {
      for ( ; pmods[i] != NULL; ++i)
	{
	  if (strcasecmp( pmods[i]->mod_type, attr) == 0 &&
	      pmods[i]->mod_op == modop)
	    break;
	}
    }

  if (pmods == NULL || pmods[i] == NULL)
    {
      if ((pmods = (LDAPMod **)realloc(pmods, (i + 2) *
	      sizeof(LDAPMod *))) == NULL)
	perror("realloc");

      **pmodsp = pmods;
      pmods[i + 1] = NULL;

      pmods[i] = (LDAPMod *) calloc (1, sizeof(LDAPMod));
      if (pmods[i] == NULL)
	perror("calloc");

      pmods[i]->mod_op = modop;
      pmods[i]->mod_type = ber_strdup(attr);
      if (pmods[i]->mod_type == NULL)
	perror("strdup");
    }

  if (val != NULL)
    {
      j = 0;
      if (pmods[i]->mod_bvalues != NULL)
	{
	for ( ; pmods[i]->mod_bvalues[j] != NULL; ++j)
	  {
	    /* Empty */;
	  }
      }

      pmods[i]->mod_bvalues =
	  (struct berval **) realloc (pmods[i]->mod_bvalues,
	  (j + 2) * sizeof (struct berval *));
      if (pmods[i]->mod_bvalues == NULL )
	perror("ber_realloc");

      pmods[i]->mod_bvalues[j + 1] = NULL;
      pmods[i]->mod_bvalues[j] = ber_bvdup(val);
      if (pmods[i]->mod_bvalues[j] == NULL)
	perror("ber_bvdup");
    }
}

/* TODO: in all erroneous cases MUST free the allocated memory */
static void
print_entry (LDAP *ld, LDAPMessage *entry, int attrsonly, dk_set_t * s)
{
  char *a, *dn;
  int i;
  BerElement *ber = NULL;
  struct berval	**bvals;
  dk_set_t p = NULL;
  dk_set_t vr = NULL;

  dn = ldap_get_dn (ld, entry);
  dk_set_push (&p, box_dv_short_string ("dn"));
  dk_set_push (&p, box_dv_short_string (dn));
  ldap_memfree (dn);

  for (a = ldap_first_attribute (ld, entry, &ber); a != NULL;
      a = ldap_next_attribute (ld, entry, ber))
    {
      dk_set_push (&p, box_dv_short_string (a));
      if ((bvals = ldap_get_values_len( ld, entry, a)) != NULL)
	{
	  for (i = 0; bvals[i] != NULL; i++)
	    {
	      if (bvals[i]->bv_len)
		{
		  caddr_t v =
		      dk_alloc_box (bvals[i]->bv_len * sizeof (char) + 1,
		      DV_LONG_STRING);
		  v [bvals[i]->bv_len] = 0;
		  memcpy (v, bvals[i]->bv_val, bvals[i]->bv_len);
		  dk_set_push (&vr, v);
		}
	      else
		dk_set_push (&vr, NEW_DB_NULL);
	    }
	  dk_set_push (&p, list_to_array (dk_set_nreverse (vr)));
	  vr = NULL;
	  ber_bvecfree (bvals);
	}
      else
	dk_set_push (&p, NEW_DB_NULL);
    }

  if (ber != NULL)
    ber_free (ber, 0);

  if (p)
    dk_set_push (s, list_to_array (dk_set_nreverse (p)));
}

static void
print_result (LDAP *ld, LDAPMessage *result, dk_set_t * s)
{
  int rc, err;
  char *matcheddn = NULL;
  char *text = NULL;
  char **refs = NULL;
  LDAPControl **ctrls = NULL;
  char err_m [2048];

  rc = ldap_parse_result (ld, result, &err, &matcheddn, &text, &refs, &ctrls,
      0);
  if (rc != LDAP_SUCCESS)
    sqlr_new_error ("39000", "LD001", "Failed to parse LDAP result response");

  dk_set_push (s, box_dv_short_string ("error"));
  snprintf (err_m, sizeof (err_m), "%d", err);
  dk_set_push (s, box_dv_short_string (err_m));
  dk_set_push (s, box_dv_short_string ("error message"));
  snprintf (err_m, sizeof (err_m), "%s", ldap_err2string(err));
  dk_set_push (s, box_dv_short_string (err_m));

  if (matcheddn && *matcheddn)
    {
      dk_set_push (s, box_dv_short_string ("matched_dn"));
      dk_set_push (s, box_dv_short_string (matcheddn));
      ldap_memfree (matcheddn);
    }


  if (text && *text)
    {
      dk_set_push (s, box_dv_short_string ("text"));
      dk_set_push (s, box_dv_short_string (text));
      ldap_memfree (text);
    }

  if (refs)
    {
      int i;
      dk_set_t rf = NULL;
      dk_set_push (s, box_dv_short_string ("refs"));
      for (i=0; refs[i] != NULL; i++)
	dk_set_push (&rf, box_dv_short_string (refs[i]));
      ldap_value_free (refs);
      dk_set_push (s, list_to_array (dk_set_nreverse (rf)));
    }

  if (ctrls)
    ldap_controls_free (ctrls);
  return;
}

static void
ldap_print_sresult (LDAP *ld, dk_set_t * s)
{
  LDAPMessage *msg = NULL;

  while (ldap_result (ld, LDAP_RES_ANY, 0 ? LDAP_MSG_ALL : LDAP_MSG_ONE, NULL, &msg) > 0)
    {
      if (msg)
	{
	  switch (ldap_msgtype (msg))
	    {
	      case LDAP_RES_SEARCH_ENTRY:
		    { /* 'entry', (<dn>, <attr>, <value>, ...) */
		      dk_set_push (s, box_dv_short_string ("entry"));
		      print_entry (ld, msg, 0, s);
		    }
		  break;

	      case LDAP_RES_SEARCH_REFERENCE:
		    { /* 'reference', (<ref>, ...) */
		      char **refs = NULL;
		      LDAPControl **ctrls = NULL;
		      int rc, i;
		      dk_set_t p = NULL;
		      rc = LDAP_PARSE_REFERENCE (ld, msg, &refs, &ctrls, 0);
		      dk_set_push (s, box_dv_short_string ("reference"));
		      if (rc != LDAP_SUCCESS)
			sqlr_new_error ("39000", "LD002",
			    "Failed to parse LDAP reference response");
		      if (refs)
			{
			  for (i=0; refs[i] != NULL; i++)
			    dk_set_push (&p, box_dv_short_string (refs[i]));
			  ldap_value_free (refs);
			}
		      else
			dk_set_push (&p, NEW_DB_NULL);

		      dk_set_push (s, list_to_array (dk_set_nreverse (p)));

		      if (ctrls)
			ldap_controls_free (ctrls);
		    }
		  break;

#ifndef WIN32
	      case LDAP_RES_EXTENDED:
		    { /* 'extended', (<oid>, <data>, ('error', <val>, 'error message', <val>, 'matched_dn', <val>, 'text', <val>, <references> ...) */
		      char *retoid = NULL;
		      struct berval *retdata = NULL;
		      int rc;
		      dk_set_t p = NULL;
		      rc = ldap_parse_extended_result (ld, msg, &retoid, &retdata, 0);
		      dk_set_push (s, box_dv_short_string ("extended"));
		      if (rc != LDAP_SUCCESS)
			sqlr_new_error ("39000", "LD003",
			    "Failed to parse LDAP extended result");
		      dk_set_push (&p,
			  retoid ? box_dv_short_string (retoid) : NEW_DB_NULL);
		      ldap_memfree (retoid);
		      if (retdata)
			{
			  caddr_t v = dk_alloc_box (retdata->bv_len, DV_LONG_STRING);
			  memcpy (v, retdata->bv_val, retdata->bv_len);
			  dk_set_push (&p, v);
			  ber_bvfree (retdata);
			}
		      else
			dk_set_push (&p, NEW_DB_NULL);
		      print_result (ld, msg, &p);
		      dk_set_push (s, list_to_array (dk_set_nreverse (p)));
		    }
		  if (ldap_msgid (msg) == 0)
		    goto done;
		  break;
#ifdef LDAP_RES_EXTENDED_PARTIAL
	      case LDAP_RES_EXTENDED_PARTIAL:
		    { /* 'partial', (<oid>, <data>) */
		      char *retoid = NULL;
		      struct berval *retdata = NULL;
		      LDAPControl **ctrls = NULL;
		      int rc;
		      dk_set_t p = NULL;
		      rc = ldap_parse_extended_partial (ld, msg, &retoid, &retdata,
			  &ctrls, 0);
		      dk_set_push (s, box_dv_short_string ("partial"));
		      if (rc != LDAP_SUCCESS)
			sqlr_new_error ("39000", "LD004",
			    "Failed to parse LDAP extended partial result");
		      dk_set_push (&p,
			  retoid ? box_dv_short_string (retoid) : NEW_DB_NULL);
		      ldap_memfree (retoid);
		      if (retdata)
			{
			  caddr_t v = dk_alloc_box (retdata->bv_len, DV_LONG_STRING);
			  memcpy (v, retdata->bv_val, retdata->bv_len);
			  dk_set_push (&p, v);
			  ber_bvfree (retdata);
			}
		      else
			dk_set_push (&p, NEW_DB_NULL);
		      print_result (ld, msg, &p);
		      dk_set_push (s, list_to_array (dk_set_nreverse (p)));
		      if (ctrls)
			ldap_controls_free (ctrls);
		    }
		  break;
#endif
#endif
	      case LDAP_RES_SEARCH_RESULT:
		    { /* 'result' ('error', <val>, 'error message', <val>, 'matched_dn', <val>, 'text', <val>, <references> ...) */
		      dk_set_t p = NULL;
		      dk_set_push (s, box_dv_short_string ("result"));
		      print_result (ld, msg, &p);
		      dk_set_push (s, list_to_array (dk_set_nreverse (p)));
		    }
		  goto done;
	    }
	}
      else
	{
	  sqlr_new_error ("39000", "LD009",
	      "Failed to parse LDAP response");
	}
    }
done:
  if (msg)
    ldap_msgfree (msg);
  return;
}


static caddr_t
bif_ldap_search (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  LDAP *ld = NULL;
  int version = ldap_get_version (qst), rc;
  static struct berval passwd = { 0, NULL };
  int authmethod = LDAP_AUTH_SIMPLE;
  int scope = LDAP_SCOPE_SUBTREE; /*LDAP_SCOPE_BASE,LDAP_SCOPE_ONELEVEL*/
  ber_int_t msgid;
  caddr_t ldapuri = bif_string_arg (qst, args, 0, "ldap_search");
  long tls = bif_long_arg (qst, args, 1, "ldap_search");
  caddr_t base = bif_string_arg (qst, args, 2, "ldap_search");
  caddr_t filter = bif_string_arg (qst, args, 3, "ldap_search");
  caddr_t who = bif_string_or_null_arg (qst, args, 4, "ldap_search");
  dk_set_t s = NULL;
  caddr_t * ret;
  caddr_t alloced_passwd = NULL;
  int is_null;
#if !defined (WIN32)
  struct timeval tv;
  long secs = 0;
#endif
  /* version */
  if (BOX_ELEMENTS (args) > 6)
    {
      long ver;
      ver = bif_long_or_null_arg (qst, args, 6, "ldap_search", &is_null);
      if (!is_null && ver >= LDAP_VERSION_MIN && ver <= LDAP_VERSION_MAX)
	version = ver;
    }
#if !defined (WIN32)
  if (BOX_ELEMENTS (args) > 7)
    {
      secs = bif_long_or_null_arg (qst, args, 7, "ldap_search", &is_null);
      if (secs > 0)
	{
	  tv.tv_sec = secs;
	  tv.tv_usec = 0;
	}
    }
#endif


#ifdef WIN32
  if (!ldap_module)
    {
      mutex_enter (ldap_handle_mutex);
      if (!ldap_module && !ldap_load_ldap_dll ())
	{
	  mutex_leave (ldap_handle_mutex);
	  sqlr_new_error ("2E000", "LD020",
	      "Failed to load the wldap32.dll");
	}
      mutex_leave (ldap_handle_mutex);
    }
#endif
  if ((rc = ldap_initialize(&ld, ldapuri)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD005",
	"Failed to initialize LDAP connection: %s (%d)", ldap_err2string (rc),
	rc);

  if ((rc =
	  ldap_set_option (ld, LDAP_OPT_PROTOCOL_VERSION,
	      &version)) != LDAP_OPT_SUCCESS)
    sqlr_new_error ("2E000", "LD006",
	"Failed to set LDAP version option: %s (%d)", ldap_err2string (rc),
	rc);

#if !defined (WIN32)
  if (secs > 0 && (rc = ldap_set_option (ld, LDAP_OPT_NETWORK_TIMEOUT, &tv)) != LDAP_OPT_SUCCESS)
    sqlr_new_error ("2E000", "LD006", "Failed to set LDAP version option: %s (%d)", ldap_err2string (rc), rc);
#endif

#ifndef WIN32
  if (tls && (rc = ldap_start_tls_s (ld, NULL, NULL)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD016", "Failed to start TLS: %s (%d)",
	ldap_err2string (rc), rc);
#endif

  if (who)
    {
      passwd.bv_val = bif_string_arg (qst, args, 5, "ldap_search");
      if (passwd.bv_val &&  passwd.bv_val[0] == 0 && box_length (passwd.bv_val) > 1)
	{
	  alloced_passwd = dk_alloc_box (box_length (passwd.bv_val) - 1,  DV_SHORT_STRING);
	  memcpy (alloced_passwd, passwd.bv_val + 1, box_length (passwd.bv_val) - 1);
	  xx_encrypt_passwd (alloced_passwd, box_length (passwd.bv_val) - 2, who);
	  passwd.bv_val = alloced_passwd;
	}
      passwd.bv_len = box_length (passwd.bv_val) - 1;
    }

  if ((rc = ldap_bind_s(ld, who, passwd.bv_val, authmethod)) != LDAP_SUCCESS)
    {
      dk_free_box (alloced_passwd);
      sqlr_new_error ("28000", "LD007",
	  "Failed to bind synchronous LDAP connection: %s (%d)",
	  ldap_err2string (rc), rc);
    }
  dk_free_box (alloced_passwd);

  /* perform the search attr & attrs_only skipped */
  if (ldap_search_ext (ld, base, scope, filter, NULL, 0,
      NULL, NULL, NULL, 0, &msgid) != LDAP_SUCCESS)
    sqlr_new_error ("42000", "LD008", "Failed to search");

  ldap_print_sresult (ld, &s);

  ldap_unbind (ld);
  ret = (caddr_t *) list_to_array (dk_set_nreverse (s));
  return (caddr_t)ret;

}

caddr_t
bif_ldap_delete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  LDAP *ld = NULL;
  int version = ldap_get_version (qst);
  static struct berval passwd = { 0, NULL };
  int authmethod = LDAP_AUTH_SIMPLE;
  caddr_t ldapuri = bif_string_arg (qst, args, 0, "ldap_delete");
  long tls = bif_long_arg (qst, args, 1, "ldap_delete");
  caddr_t dn = bif_string_arg (qst, args, 2, "ldap_delete");
  caddr_t who = bif_string_or_null_arg (qst, args, 3, "ldap_delete");
  char *matcheddn = NULL, *text = NULL, **refs = NULL;
  int id, rc, code;
  LDAPMessage *res;
  caddr_t alloced_passwd = NULL;

  if (who)
    {
      passwd.bv_val = bif_string_arg (qst, args, 4, "ldap_delete");
      passwd.bv_len = box_length (passwd.bv_val) - 1;
    }

#ifdef WIN32
  if (!ldap_module)
    {
      mutex_enter (ldap_handle_mutex);
      if (!ldap_module && !ldap_load_ldap_dll ())
	{
	  mutex_leave (ldap_handle_mutex);
	  sqlr_new_error ("2E000", "LD020",
	      "Failed to load the wldap32.dll");
	}
      mutex_leave (ldap_handle_mutex);
    }
#endif
  if ((rc = ldap_initialize(&ld, ldapuri)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD005",
	"Failed to initialize LDAP connection: %s (%d)", ldap_err2string (rc),
	rc);

  if ((rc =
	  ldap_set_option (ld, LDAP_OPT_PROTOCOL_VERSION,
	      &version)) != LDAP_OPT_SUCCESS)
    sqlr_new_error ("2E000", "LD006",
	"Failed to set LDAP version option: %s (%d)", ldap_err2string (rc),
	rc);

#ifndef WIN32
  if (tls && (rc = ldap_start_tls_s (ld, NULL, NULL)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD016", "Failed to start TLS: %s (%d)",
	ldap_err2string (rc), rc);
#endif

  if (who)
    {
      passwd.bv_val = bif_string_arg (qst, args, 4, "ldap_delete");
      if (passwd.bv_val &&  passwd.bv_val[0] == 0 && box_length (passwd.bv_val) > 1)
	{
	  alloced_passwd = dk_alloc_box (box_length (passwd.bv_val) - 1,  DV_SHORT_STRING);
	  memcpy (alloced_passwd, passwd.bv_val + 1, box_length (passwd.bv_val) - 1);
	  xx_encrypt_passwd (alloced_passwd, box_length (passwd.bv_val) - 2, who);
	  passwd.bv_val = alloced_passwd;
	}
      passwd.bv_len = box_length (passwd.bv_val) - 1;
    }

  if ((rc = ldap_bind_s(ld, who, passwd.bv_val, authmethod)) != LDAP_SUCCESS)
    {
      dk_free_box (alloced_passwd);
      sqlr_new_error ("28000", "LD007",
	  "Failed to bind synchronous LDAP connection: %s (%d)",
	  ldap_err2string (rc), rc);
    }
  dk_free_box (alloced_passwd);

  /* perform the delete */
  if ((rc = ldap_delete_ext( ld, dn, NULL, NULL, &id)) != LDAP_SUCCESS)
    sqlr_new_error ("39000", "LD012",
	"Failed to delete the DN entry: %d (%s)", rc, ldap_err2string (rc));

  rc = ldap_result( ld, LDAP_RES_ANY, LDAP_MSG_ALL, NULL, &res);

  if (res)
    {
      rc = ldap_parse_result( ld, res, &code, &matcheddn, &text, &refs, NULL, 1 );
      ldap_memfree (text);
      ldap_memfree (matcheddn);
      ldap_value_free (refs);
    }
  else
    {
      sqlr_new_error ("39000", "LD009",
	  "Failed to parse LDAP response");
    }

  ldap_unbind (ld);
  return box_num (code);
}

static int
arr_to_pmod (caddr_t * arr, char **dn, int modop, LDAPMod ***pmods)
{
  int i;
  struct berval val;
  long len = BOX_ELEMENTS (arr);

  for (i=0; i<len; i+=2)
    {
      if (!stricmp ((char*)arr[i], "dn"))
	{
	  if (IS_STRING_DTP (DV_TYPE_OF (arr[i+1])))
	    *dn = arr[i+1];
	  continue;
	}
      if (IS_STRING_DTP (DV_TYPE_OF (arr[i+1])))
	{
	  val.bv_len = box_length (arr[i+1]) - 1;
	  val.bv_val = arr[i+1];
	}
      else if (DV_TYPE_OF (arr[i + 1]) == DV_ARRAY_OF_POINTER)
	  {
	    int j, l;
	    caddr_t * v = (caddr_t *) arr[i+1];
	    l = BOX_ELEMENTS (v);
	    for (j=0;j<l;j++)
	      {
		if (IS_STRING_DTP (DV_TYPE_OF (v[j])))
		  {
		    val.bv_len = box_length (v[j]) - 1;
		    val.bv_val = v[j];
		  }
		addmodifyop(&pmods, modop, arr[i], &val);
	      }
	    continue;
	  }
	else
	  addmodifyop(&pmods, modop, arr[i], &val);
    }
  return 0;
}

static caddr_t
bif_ldap_add (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  LDAP *ld = NULL;
  int version = ldap_get_version (qst), rc;
  static struct berval passwd = { 0, NULL };
  int authmethod = LDAP_AUTH_SIMPLE;
  caddr_t ldapuri = bif_string_arg (qst, args, 0, "ldap_add");
  long tls = bif_long_arg (qst, args, 1, "ldap_add");
  caddr_t * arr = (caddr_t *) bif_array_arg (qst, args, 2, "ldap_add");
  caddr_t who = bif_string_or_null_arg (qst, args, 3, "ldap_add");
  int modop = LDAP_MOD_ADD;
  LDAPMod **pmods = NULL;
  char *dn = NULL;
  caddr_t alloced_passwd = NULL;

#ifdef WIN32
  if (!ldap_module)
    {
      mutex_enter (ldap_handle_mutex);
      if (!ldap_module && !ldap_load_ldap_dll ())
	{
	  mutex_leave (ldap_handle_mutex);
	  sqlr_new_error ("2E000", "LD020",
	      "Failed to load the wldap32.dll");
	}
      mutex_leave (ldap_handle_mutex);
    }
#endif
  if ((rc = ldap_initialize(&ld, ldapuri)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD005",
	"Failed to initialize LDAP connection: %s (%d)", ldap_err2string (rc),
	rc);

  if ((rc =
	  ldap_set_option (ld, LDAP_OPT_PROTOCOL_VERSION,
	      &version)) != LDAP_OPT_SUCCESS)
    sqlr_new_error ("2E000", "LD006",
	"Failed to set LDAP version option: %s (%d)", ldap_err2string (rc),
	rc);

#ifndef WIN32
  if (tls && (rc = ldap_start_tls_s (ld, NULL, NULL)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD016", "Failed to start TLS: %s (%d)",
	ldap_err2string (rc), rc);
#endif

  if (who)
    {
      passwd.bv_val = bif_string_arg (qst, args, 4, "ldap_add");
      if (passwd.bv_val &&  passwd.bv_val[0] == 0 && box_length (passwd.bv_val) > 1)
	{
	  alloced_passwd = dk_alloc_box (box_length (passwd.bv_val) - 1,  DV_SHORT_STRING);
	  memcpy (alloced_passwd, passwd.bv_val + 1, box_length (passwd.bv_val) - 1);
	  xx_encrypt_passwd (alloced_passwd, box_length (passwd.bv_val) - 2, who);
	  passwd.bv_val = alloced_passwd;
	}
      passwd.bv_len = box_length (passwd.bv_val) - 1;
    }

  if ((rc = ldap_bind_s(ld, who, passwd.bv_val, authmethod)) != LDAP_SUCCESS)
    {
      dk_free_box (alloced_passwd);
      sqlr_new_error ("28000", "LD007",
	  "Failed to bind synchronous LDAP connection: %s (%d)",
	  ldap_err2string (rc), rc);
    }
  dk_free_box (alloced_passwd);

  if (DV_TYPE_OF (arr) == DV_ARRAY_OF_POINTER)
      arr_to_pmod (arr, &dn, modop, &pmods);

  if (!dn)
    sqlr_new_error ("2E000","LD004","The DN must be supplied");

  rc = ldap_add_s (ld, dn, pmods);

  if ( pmods != NULL )
#ifdef WIN32
  ldap_value_free ((void **)pmods);
#else
  ber_memfree ((void **) pmods);
#endif

  if (rc != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD004", "Failed to add err=%i (%s)", rc,
	ldap_err2string (rc));

  ldap_unbind (ld);
  return box_num (rc);
}


static caddr_t
bif_ldap_modify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  LDAP *ld = NULL;
  int version = ldap_get_version (qst), rc;
  static struct berval passwd = { 0, NULL };
  int authmethod = LDAP_AUTH_SIMPLE;
  caddr_t ldapuri = bif_string_arg (qst, args, 0, "ldap_modify");
  long tls = bif_long_arg (qst, args, 1, "ldap_modify");
  caddr_t * arr = (caddr_t *) bif_array_arg (qst, args, 2, "ldap_modify");
  caddr_t who = bif_string_or_null_arg (qst, args, 3, "ldap_modify");
  int modop = LDAP_MOD_ADD;
  LDAPMod **pmods = NULL;
  char *dn = NULL;
  caddr_t alloced_passwd = NULL;

#ifdef WIN32
  if (!ldap_module)
    {
      mutex_enter (ldap_handle_mutex);
      if (!ldap_module && !ldap_load_ldap_dll ())
	{
	  mutex_leave (ldap_handle_mutex);
	  sqlr_new_error ("2E000", "LD020",
	      "Failed to load the wldap32.dll");
	}
      mutex_leave (ldap_handle_mutex);
    }
#endif
  if ((rc = ldap_initialize(&ld, ldapuri)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD005",
	"Failed to initialize LDAP connection: %s (%d)", ldap_err2string (rc),
	rc);

  if ((rc =
	  ldap_set_option (ld, LDAP_OPT_PROTOCOL_VERSION,
	      &version)) != LDAP_OPT_SUCCESS)
    sqlr_new_error ("2E000", "LD006",
	"Failed to set LDAP version option: %s (%d)", ldap_err2string (rc),
	rc);

#ifndef WIN32
  if (tls && (rc = ldap_start_tls_s (ld, NULL, NULL)) != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD016", "Failed to start TLS: %s (%d)",
	ldap_err2string (rc), rc);
#endif

  if (who)
    {
      passwd.bv_val = bif_string_arg (qst, args, 4, "ldap_modify");
      if (passwd.bv_val &&  passwd.bv_val[0] == 0 && box_length (passwd.bv_val) > 1)
	{
	  alloced_passwd = dk_alloc_box (box_length (passwd.bv_val) - 1,  DV_SHORT_STRING);
	  memcpy (alloced_passwd, passwd.bv_val + 1, box_length (passwd.bv_val) - 1);
	  xx_encrypt_passwd (alloced_passwd, box_length (passwd.bv_val) - 2, who);
	  passwd.bv_val = alloced_passwd;
	}
      passwd.bv_len = box_length (passwd.bv_val) - 1;
    }

  if ((rc = ldap_bind_s(ld, who, passwd.bv_val, authmethod)) != LDAP_SUCCESS)
    {
      dk_free_box (alloced_passwd);
      sqlr_new_error ("28000", "LD007",
	  "Failed to bind synchronous LDAP connection: %s (%d)",
	  ldap_err2string (rc), rc);
    }
  dk_free_box (alloced_passwd);
  if (DV_TYPE_OF (arr) == DV_ARRAY_OF_POINTER)
      arr_to_pmod (arr, &dn, modop, &pmods);

  if (!dn)
    sqlr_new_error ("2E000","LD004","The DN must be supplied");

  rc = ldap_modify_s (ld, dn, pmods);

  if ( pmods != NULL )
#ifdef WIN32
  ldap_value_free ((void **)pmods);
#else
  ber_memfree ((void **) pmods);
#endif

  if (rc != LDAP_SUCCESS)
    sqlr_new_error ("2E000", "LD004", "Failed to modify err=%i (%s)", rc,
	ldap_err2string (rc));

  ldap_unbind (ld);
  return box_num (rc);
}

#endif

void
bif_ldapcli_init (void)
{
#ifndef WIN95COMPAT
#ifdef WIN32
  ldap_handle_mutex = mutex_allocate ();
#endif
  con_ldap_version_name = box_dv_short_string ("LDAP_VERSION");
  bif_define ("ldap_search", bif_ldap_search);
  bif_define ("ldap_delete", bif_ldap_delete);
  bif_define_typed ("ldap_add",    bif_ldap_add, &bt_varchar);
  bif_define_typed ("ldap_modify", bif_ldap_modify, &bt_varchar);
#endif
}

#else /*ndef NO_LDAP */
#ifndef WIN95COMPAT
static caddr_t
bif_ldap_modify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

static caddr_t
bif_ldap_search (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

static caddr_t
bif_ldap_add (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

static caddr_t
bif_ldap_delete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}
#endif

void
bif_ldapcli_init (void)
{
#ifndef WIN95COMPAT
  bif_define ("ldap_search", bif_ldap_search);
  bif_define ("ldap_delete", bif_ldap_delete);
  bif_define_typed ("ldap_add",    bif_ldap_add, &bt_varchar);
  bif_define_typed ("ldap_modify", bif_ldap_modify, &bt_varchar);
#endif
}
#endif /* ndef NO_LDAP */
