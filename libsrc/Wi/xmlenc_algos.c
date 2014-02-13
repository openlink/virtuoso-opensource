/*
 *  xmlenc_algos.c
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif


#include "sqlnode.h"
#include "sqlbif.h"

#include "xml.h"
#include "xmlgen.h"
#include "xmltree.h"

#include "xml_ecm.h"

#include "soap.h"
#include "xmlenc.h"

#ifdef _SSL
#include <openssl/rsa.h>
#include <openssl/sha.h>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/hmac.h>

#include "xmlenc_test.h"

#ifdef DEBUG
long xenc_errs;
long xenc_asserts;

void xenc_assert_1(int term, char* file, long line)
{
  xenc_asserts++;
  if (!term)
    {
      rep_printf ("test no. %ld failed (%s %ld)\n", xenc_asserts-1, file, line);
      xenc_errs++;
    }
}
#endif /* DEBUG */

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

typedef struct xxx_algo_s
{
  char *xmlname;
  void *func;
} xxx_algo_t;

#define define_algo(name) \
typedef struct dsig_##name##_algo_s \
{ \
  char *	xmlname; \
  dsig_##name##_f	f; \
} dsig_##name##_algo_t \

define_algo (sign);
define_algo (verify);
define_algo (canon);
define_algo (canon_2);
define_algo (digest);
define_algo (transform);

typedef struct algo_store_s
{
  char *dat_name;
  id_hash_t *dat_hash;
} algo_store_t;

/* table must be sorted by first column */
static algo_store_t algo_stores[] = {
  {"canon", NULL},
  {"canon_2", NULL},
  {"digest", NULL},
  {"dsig", NULL},
  {"trans", NULL},
  {"verify", NULL}
};
#endif

static char base64_vec[] =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

int
xenc_encode_base64(char * input, char * output, size_t len)
{
  unsigned char	c;
  int  n = 0,
    i,
    count = 0,
    x = 0;
  size_t j = 0;
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
	output[x++] = base64_vec[enc[i]];
      n = 1;
      val = c;
      count += 4;
      if (count >= 70)
	{
#if 0
	  output[x++] = '\n';
#endif
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
	output[x++] = base64_vec[enc[i]];
    }

  return x;
}

static void
xenc_base64_store24(char ** d, char * c)
{
    *(*d)++=(c[0]<<2)+(c[1]>>4);
    *(*d)++=((c[1]<<4)&255)+(c[2]>>2);
    *(*d)++=((c[2]<<6)&255)+c[3];
}

int
xenc_decode_base64(char * src, char * end)
{
  char * start = src;
  char c0, c[4], s[4], *p;
  int i=0;
  char *d = src;

  if (!src || !*src || src == end)
    return 0;

  memset (s, 0, sizeof (s));
  while ((c0 = *src++) && src < end)
    {
      if ((p = strchr(base64_vec, c0)))
	{
	  s[i] = c0;
	  c[i] = (p - base64_vec) & 63;
	  if (i == 3)
	    {
	      xenc_base64_store24(&d, c);
	      if (s[2] == '=')
		{
		  d -= 2;
		  break;
		}
	      else if (s[3] == '=')
		{
		  d -= 1;
		  break;
		}
	      memset (s, 0, sizeof (s));
	      i = 0;
	    }
	  else
	    {
	      i++;
	    }
	} /* unknown symbols are ignored */
    }
  *d = 0;
  return(d - start);
}


#ifdef _SSL
static ptrlong algo_stores_len = sizeof (algo_stores) / sizeof (algo_store_t);

/* pre: name is name of algo store
   post: returns pointer to algo store
*/
static
algo_store_t * select_store (const char* name)
{
  ptrlong idx = ecm_find_name (name, algo_stores, algo_stores_len, sizeof (algo_store_t));
#ifdef DEBUG
  if (idx == -1)
    {
      char buf[512];
      snprintf (buf, sizeof (buf), "unknown store name %s", name);
      GPF_T1 (buf);
    }
#endif
  return algo_stores + idx;
}

/* pre: valid algo, xmln, name, valid func
   post:
	if xmln and name are unique - 1
	else - 0
*/

static
int add_algo_to_store (algo_store_t * s, const char * xmln, void * f)
{
  if (id_hash_get (s->dat_hash, (caddr_t) & xmln))
    return 0;
  else
    {
      NEW_VARZ (xxx_algo_t, item);
      item->xmlname = box_dv_short_string (xmln);
      item->func = f;

      id_hash_set (s->dat_hash, (caddr_t) & item->xmlname, (caddr_t) & item);
      return 1;
    }
}
/* pre: xmln - string, store - store pointer
   post: if algo in store, returns algo
	else GPF
*/

int dsig_digest_algo_create (const char* xmln, dsig_digest_f f)
{
  return add_algo_to_store (select_store ("digest"), xmln, (void *) f);
}

int dsig_sign_algo_create (const char * xmln, dsig_sign_f f)
{
  return add_algo_to_store (select_store ("dsig"), xmln, (void *) f);
}
int dsig_verify_algo_create (const char * xmln, dsig_verify_f f)
{
  return add_algo_to_store (select_store ("verify"), xmln, (void *) f);
}

int dsig_canon_algo_create (const char * xmln, dsig_canon_f f)
{
  return add_algo_to_store (select_store ("canon"), xmln, (void *) f);
}

int dsig_canon_2_algo_create (const char * xmln, dsig_canon_2_f f)
{
  return add_algo_to_store (select_store ("canon_2"), xmln, (void *) f);
}

int dsig_transform_algo_create (const char * xmln, dsig_transform_f f)
{
  return add_algo_to_store (select_store ("trans"), xmln, (void *) f);
}

int dsig_single_transform_algo (query_instance_t * qi, dk_session_t * ses_in, long len,
				dk_session_t * ses_out, caddr_t transform_data)
{
  char buf[1024];
  int read_b;
  int err = 0;
  int tot_l = 0;

  CATCH_READ_FAIL (ses_in)
  {
    while (len && !err)
      {
	  read_b = session_buffered_read (ses_in, buf, len > sizeof (buf) ? sizeof(buf) : len );

	CATCH_WRITE_FAIL (ses_out)
	{
	  session_buffered_write (ses_out, (char *) buf, read_b);
	}
	FAILED
	{
	  err = 1;
	}
	END_WRITE_FAIL (ses_out);
	len -= read_b;
	tot_l += read_b;
      }
  }
  FAILED
  {
  }
  END_READ_FAIL (ses_in);
  return tot_l;
}

#define ALGOS_PROTOTYPES

int xml_canon_exc_algo (dk_session_t * ses_in, long len, dk_session_t * ses_out)
{
#ifdef ALGOS_PROTOTYPES
  char buf[1024];
  int read_b;
  int err = 0;
  int tot_l = 0;

  CATCH_READ_FAIL (ses_in)
  {
    while (len && !err)
      {
	  read_b = session_buffered_read (ses_in, buf, len > sizeof (buf) ? sizeof(buf) : len );

	CATCH_WRITE_FAIL (ses_out)
	{
	  session_buffered_write (ses_out, (char *) buf, read_b);
	}
	FAILED
	{
	  err = 1;
	}
	END_WRITE_FAIL (ses_out);

	len -= read_b;
	tot_l += read_b;
      }
  }
  FAILED
  {
  }
  END_READ_FAIL (ses_in);
  return tot_l;
#else
#error "Canonicalization method is not implemented"
  return 0; /* keeps compiler happy */
#endif
}

int xml_c_build_ancessor_ns_link (caddr_t * doc_tree, caddr_t * select_tree,
    id_hash_t * nss, dk_set_t * parent_link)
{
  caddr_t *namespaces = xenc_get_namespaces (doc_tree, nss);
  int inx;
  dk_set_push (parent_link, namespaces);
  if (doc_tree == select_tree)
    return 1;
  DO_BOX (caddr_t *, child, inx, doc_tree)
  {
    if (!inx || DV_TYPE_OF (child) != DV_ARRAY_OF_POINTER)
      continue;
    if (!xml_c_build_ancessor_ns_link (child, select_tree, nss, parent_link))
      dk_set_pop (parent_link);
    else
      return 1;
  }
  END_DO_BOX;
  return 0;
}

static
int strcmp_1 (const void * n1, const void * n2)
{
  int ret;
  char *ns1 = ((char **) n1)[0];
  char *ns2 = ((char **) n2)[0];
  if (!ns1 && !ns2)
    return 0;
  if (!ns1)
    return -1;
  if (!ns2)
    return 1;

  ret = strcmp ((char *) ns1, (char *) ns2);

#ifdef DEBUG
  printf ("\n %s %s %d\n", ns1, ns2, ret);
#endif

  return ret;
}

void xml_c_namespaces_sort (caddr_t * namespaces)
{
  if (namespaces)
    qsort (namespaces, box_length (namespaces) / sizeof (caddr_t) / 2,
	sizeof (caddr_t) * 2, strcmp_1);
}

void xml_c_attributes_sort (caddr_t * tree)
{
  caddr_t *tag = ((caddr_t **) tree)[0] + 1;

  if (!XML_ELEMENT_ATTR_COUNT (tree))
    return;

  qsort (tag, XML_ELEMENT_ATTR_COUNT (tree), sizeof (caddr_t) * 2, strcmp_1);
}

typedef dk_set_t * xml_c_stack;

#define XML_C_BUSY_NS	(char*) 0x0000dead

/* we must protect our childs from taking namespace from here. */
void xml_c_mark_as_busy (xml_c_stack exc_list, caddr_t * exc_ns, int inx)
{
  caddr_t * curr_ns = (caddr_t*) exc_list[0]->data;
  caddr_t * new_curr_ns;
  if (exc_ns == curr_ns) /* our namespace */
    {
      if (exc_ns[inx] != XML_C_BUSY_NS)
	dk_free_box (exc_ns[inx]);
      exc_ns[inx] = XML_C_BUSY_NS;
      return;
    }
  /* create fake namespace declaration to protect childs
     from searching namespace prefix from ancestors */
  /* this namespace declaration is not in current namespace array
     (last in stack) since exc_ns != curr_ns */

  new_curr_ns = (caddr_t *) dk_alloc_box (curr_ns ? box_length (curr_ns) : 0 + 2 * sizeof (caddr_t),
			      DV_ARRAY_OF_POINTER);

  if (curr_ns)
    {
      memcpy (new_curr_ns, curr_ns, box_length (curr_ns));
      new_curr_ns[BOX_ELEMENTS(curr_ns)] = XML_C_BUSY_NS; /* prefix */
      new_curr_ns[BOX_ELEMENTS(curr_ns)+1] = box_copy (exc_ns[inx+1]); /* ns */
      dk_free_box ((box_t) curr_ns);
    }
  else
    {
      new_curr_ns[0] = XML_C_BUSY_NS;
      new_curr_ns[1] = box_copy (exc_ns[inx + 1]);
    }

  exc_list[0]->data = new_curr_ns;
}

int xml_c_get_namespace (caddr_t name, xml_c_stack exc_list, caddr_t * prefix, caddr_t * ns, int depth)
{
  char * ch = strrchr (name, ':');
  int len = ch - name;
  if (!ch || !len)
    return 0;

  DO_SET (caddr_t *, exc_ns, exc_list)
    {
      int inx;

      if (!exc_ns)
	continue;

      for (inx = 0; inx < BOX_ELEMENTS_INT (exc_ns); inx+=2)
  	{
	  if (!strncmp (name, exc_ns[inx + 1], len))
	    {
	      if (exc_ns[inx] == XML_C_BUSY_NS)
		return 0;
	      if (!exc_ns[inx])
		prefix[0] = 0;
	      else
		prefix[0] = box_dv_short_string (exc_ns[inx]);
	      ns[0] = box_dv_short_string (exc_ns[inx+1]);
	      xml_c_mark_as_busy (exc_list, exc_ns, inx);
	      return 1;
	    }
	}
    }
  END_DO_SET ();
  return 0;
}

static
void xml_c_fill_exc_list_up (xml_c_stack exc_list, caddr_t * namespaces)
{
  caddr_t * namespaces_copy = (caddr_t *) box_copy_tree ((box_t) namespaces);
  dk_set_push (exc_list, namespaces_copy);
}

static
void xmlc_c_clean_exc_list_up (xml_c_stack exc_list)
{
  caddr_t * ns = (caddr_t*) dk_set_pop (exc_list);
  int inx;
  DO_BOX (caddr_t, name, inx, ns)
    {
      if (name == XML_C_BUSY_NS)
	continue;
      dk_free_box (name);
    }
  END_DO_BOX;
  dk_free_box ((box_t) ns);
}

static
caddr_t * xml_c_new_namespace (const char * prefix, const char * uri)
{
  caddr_t * namespaces = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  namespaces[0] = box_dv_short_string (prefix);
  namespaces[1] = box_dv_short_string (uri);
  return namespaces;
}

caddr_t * xml_c_namespaces_sort_2 (caddr_t * tree, xml_c_stack exc_list, int depth)
{
  caddr_t *tag = ((caddr_t **) tree)[0] + 1;
  caddr_t name = XML_ELEMENT_NAME (tree);
  caddr_t prefix;
  caddr_t ns;
  dk_set_t new_nss_set = 0;

  if ((xml_c_get_namespace (name, exc_list, &prefix, &ns, depth)))
    {
      dk_set_push (&new_nss_set, prefix);
      dk_set_push (&new_nss_set, ns);
    }

  if (XML_ELEMENT_ATTR_COUNT (tree))
    {
      int inx;
      for (inx = 0; (inx < BOX_ELEMENTS_INT (tree[0]) - 1); inx +=2)
	{
	  char * attr = tag[inx];
	  if (xml_c_get_namespace (attr, exc_list, &prefix, &ns, depth))
	    {
	      dk_set_push (&new_nss_set, prefix);
	      dk_set_push (&new_nss_set, ns);
	    }
	}
    }

  if (new_nss_set)
    {
      caddr_t * new_nss;
      new_nss_set = dk_set_nreverse (new_nss_set);
      new_nss = (caddr_t*) dk_set_to_array (new_nss_set);
      dk_set_free (new_nss_set);
      return new_nss;
    }
  return 0;
}

void
xml_c_nss_hash_add_item (id_hash_t * novo, id_hash_t * nss, caddr_t * tree, xml_c_stack exc_list, int depth)
{
  caddr_t *namespaces;
  int inx;

  if (!DV_TYPE_OF (tree) == DV_ARRAY_OF_POINTER)
    return;

  namespaces = xenc_get_namespaces (tree, nss);
  xml_c_namespaces_sort (namespaces);
  xml_c_attributes_sort (tree);

  if (exc_list)
    {
      caddr_t * new_namespaces = 0;
      xml_c_fill_exc_list_up (exc_list, namespaces);
      new_namespaces = xml_c_namespaces_sort_2 (tree, exc_list, depth);
      namespaces = new_namespaces;
    }
  else
    namespaces = (caddr_t *) box_copy_tree ((box_t) namespaces);

  if (namespaces)
    id_hash_set (novo, (caddr_t) (&tree), (caddr_t) (&namespaces));
  else
    id_hash_remove (novo, (caddr_t) (&tree));

  DO_BOX (caddr_t *, child, inx, tree)
  {
    if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
      xml_c_nss_hash_add_item (novo, nss, child, exc_list, depth + 1);
  }
  END_DO_BOX;
  if (exc_list)
    {
      xmlc_c_clean_exc_list_up (exc_list);
    }
}

void xml_c_nss_free (id_hash_t * nss)
{
  id_hash_iterator_t iter;
  caddr_t **tree;
  caddr_t **namespaces;

  for (id_hash_iterator (&iter, nss);
      hit_next (&iter, (char **) &(tree), (char **) &namespaces);
      /* */ )
    {
      if (namespaces)
	dk_free_tree ((box_t) namespaces[0]);
    }
  id_hash_free (nss);
}

id_hash_t * xml_c_nss_hash_create (caddr_t * select_tree, id_hash_t * nss,
    caddr_t * new_namespaces)
{
  id_hash_t * new_h = id_hash_allocate (31, sizeof (caddr_t*), sizeof (caddr_t*),
      voidptrhash, voidptrhashcmp);
  int inx;
  dk_set_t pexc_list = 0;

  if (!DV_TYPE_OF (select_tree) == DV_ARRAY_OF_POINTER)
    return new_h;

  xml_c_namespaces_sort (new_namespaces);
  xml_c_attributes_sort (select_tree);

  /* exc_list is always used, so exclusive canonicalization is used */
    {
      caddr_t * new_new_namespaces = 0;
      xml_c_fill_exc_list_up (&pexc_list, new_namespaces);
      new_new_namespaces = xml_c_namespaces_sort_2 (select_tree, &pexc_list, 0);
      dk_free_box (new_namespaces);
      new_namespaces = new_new_namespaces;
      xml_c_namespaces_sort (new_namespaces); /* XXX: this needed as MS.WSE used sorted prefixes */
    }

  if (new_namespaces)
    id_hash_set (new_h, (caddr_t) (&select_tree), (caddr_t) (&new_namespaces));
  else
    id_hash_remove (new_h, (caddr_t) (&select_tree));

  id_hash_set (new_h, (caddr_t) (&select_tree), (caddr_t) (&new_namespaces));

  DO_BOX (caddr_t *, child, inx, select_tree)
  {
    if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
      xml_c_nss_hash_add_item (new_h, nss, child, &pexc_list, 0);
  }
  END_DO_BOX;

  if (pexc_list)
    {
      xmlc_c_clean_exc_list_up (&pexc_list);
    }

  return new_h;
}

int xml_canonicalize (query_instance_t * qi, caddr_t * doc_tree, caddr_t * select_tree,
	id_hash_t * nss, dk_session_t * ses_out)
{
  dk_set_t parent_link = 0;
  int len = 0;
  caddr_t *new_namespaces;
  id_hash_t *new_hash;
  xml_doc_subst_t _xs;
  xml_doc_subst_t *xs = &_xs;
  char *text;
  int ok = 1;
  if (!xml_c_build_ancessor_ns_link (doc_tree, select_tree, nss, &parent_link))
    {
      dk_set_free (parent_link);
      return 0;
    }

  DO_SET (caddr_t *, a, &parent_link)
  {
    if (!a)
      continue;
    len += box_length (a);
  }
  END_DO_SET ();

  new_namespaces = (caddr_t *) dk_alloc_box (len, DV_ARRAY_OF_POINTER);
  len = 0;
  DO_SET (caddr_t *, a, &parent_link)
  {
    if (!a)
      continue;
    memcpy (new_namespaces + len, a, box_length (a));
    len += box_length (a) / sizeof (caddr_t);
  }
  END_DO_SET ();

  dk_set_free (parent_link);


  new_hash = xml_c_nss_hash_create (select_tree, nss, new_namespaces);

  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = xte_from_tree ((caddr_t) select_tree, qi);
  xs->xs_namespaces = new_hash;
  dk_set_push (&xs->xs_parent_link, xml_c_new_namespace ("xsd", "http://www.w3.org/2001/XMLSchema"));

  text = xml_doc_subst (xs);

  dk_free_tree ((box_t) dk_set_pop (&xs->xs_parent_link));
  dk_set_free (xs->xs_parent_link);

  CATCH_WRITE_FAIL (ses_out)
  {
    session_buffered_write (ses_out, text, box_length (text) - 1);
  }
  FAILED
  {
    ok = 0;
  }
  END_WRITE_FAIL (ses_out);

  dk_free_box (text);

#ifdef DEBUG
  /* This is to keep xte_tree_check() happy */
  xs->xs_doc->xe_doc.xtd->xtd_tree = list (1, list (1, uname__root));
#else
  xs->xs_doc->xe_doc.xtd->xtd_tree = 0;
#endif
  dk_free_box ((box_t) xs->xs_doc);

  xml_c_nss_free (new_hash);

  return ok;
}

caddr_t * xml_find_any_child (caddr_t * curr, const char * name, const char * uri)
{
  int NameLen = name ? strlen (name) : INT_MAX;
  int URILen = uri ? strlen (uri) : INT_MAX;
  int inx;
  DO_BOX (caddr_t *, child, inx, curr)
    {
      if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	{
	  caddr_t * ret;
	  char *szName = XML_ELEMENT_NAME (child);
	  char *szColon = strrchr (szName, ':');
	  if (!name && !uri)
	    return (child);
	  if (szColon && !uri)
	    goto internal_search;
	  else if (!szColon && uri)
	    goto internal_search;
	  else if (szColon && uri && ((URILen != (szColon - szName))
		|| strnicmp (szName, uri, MIN (szColon - szName, URILen))))
	    goto internal_search;
	  else if (szColon && name && strncmp (szColon + 1, name, NameLen))
	    goto internal_search;
	  else if (!szColon && name && strncmp (szName, name, NameLen))
	    goto internal_search;
	  return (child);
	internal_search:
	  ret = xml_find_any_child (child, name, uri);
	  if (ret) return ret;
	}
    }
  END_DO_BOX;
  return NULL;
}


int dsig_tr_enveloped_signature (query_instance_t * qi, dk_session_t * ses_in, long len,
	dk_session_t * ses_out, caddr_t transform_data)
{
  caddr_t xml_text = dk_alloc_box (len + 1, DV_STRING);
  caddr_t err_ret = 0;
  id_hash_t * nss = 0;
  int ret = 0;
  xml_doc_subst_t * xs;
  caddr_t * signature;
  caddr_t text;
  xml_tree_ent_t * xte;

  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, xml_text, len);
      xml_text [len] = 0;
    }
  FAILED
    {
      dk_free_box (xml_text);
      return 0;
    }
  END_READ_FAIL (ses_in);

  xte = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, xml_text, &err_ret, "UTF-8",
			lh_get_handler ("x-any"), &nss, 0);
  dk_free_box (xml_text);

  if (!xte)
    goto finish;

  /* support of both SOAP versions */
  signature = xml_find_any_child (xte->xte_current, "Signature", DSIG_URI);

  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = xte;
  xs->xs_namespaces = nss;
  xs->xs_discard = signature;

  text = xml_doc_subst (xs);

  xml_doc_subst_free (xs);

  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, text, box_length (text) - 1);
      ret = box_length (text) - 1;
    }
  FAILED
    {
    }
  END_WRITE_FAIL (ses_out);
  dk_free_box (text);


 finish:
  dk_free_tree (err_ret);
  dk_free_box ((box_t) xte);
  nss_free (nss);
  return ret;
}

int dsig_tr_canon_exc_algo  (query_instance_t * qi, dk_session_t * ses_in, long len,
	dk_session_t * ses_out,	caddr_t transform_data)
{
  caddr_t xml_text = NULL;
  caddr_t err_ret = 0;
  id_hash_t * nss = 0;
  char * id = (char *) transform_data;
  id_hash_t * id_cache = 0;
  int ret = 0;
  xml_tree_ent_t * xte;

  CATCH_READ_FAIL (ses_in)
    {
      xml_text = dk_alloc_box (len + 1, DV_STRING);
      session_buffered_read (ses_in, xml_text, len);
      xml_text [len] = 0;
    }
  FAILED
    {
      dk_free_box (xml_text);
      return 0;
    }
  END_READ_FAIL (ses_in);

  xte = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, xml_text, &err_ret, "UTF-8",
						  lh_get_handler ("x-any"), &nss, 0);

  dk_free_box (xml_text);

  if (id)
    {
      caddr_t ** curr;
      if (!xte)
	goto finish;
      xenc_build_ids_hash (xte->xte_current, &id_cache, 0);

      if (!id_cache)
	goto finish;

      curr = (caddr_t **) id_hash_get (id_cache, (char *) &id);
      if (!curr)
	goto finish;
      xte->xte_current = curr[0];
    }

  ret = xml_canonicalize (qi, xte->xe_doc.xtd->xtd_tree, xte->xte_current, nss, ses_out);

 finish:
  dk_free_tree (err_ret);
  if (id_cache)
    xenc_ids_hash_free (id_cache);
  nss_free(nss);
  return ret;
}

int dsig_tr_fake_uri (query_instance_t * qi, dk_session_t * ses_in, long len,
	dk_session_t * ses_out, caddr_t transform_data)
{
  caddr_t text = dk_alloc_box (len + 1, DV_STRING);
  id_hash_t * nss;
  xml_tree_ent_t * xte;
  char * id = (char *) transform_data;
  caddr_t ** curr;
  int ret = 0;
  xml_doc_subst_t * xs = 0;
  caddr_t ret_text = 0;
  caddr_t err_ret = 0;
  id_hash_t * id_cache = 0;


  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, text, len);
      text[len] = 0;
    }
  FAILED
    {
      END_READ_FAIL (ses_in);
      dk_free_box (text);
      return 0;
    }
  END_READ_FAIL (ses_in);

  xte = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, text, &err_ret, "UTF-8",
			lh_get_handler ("x-any"), &nss, 0);


  if (!xte)
    goto finish;

  xenc_build_ids_hash (xte->xte_current, &id_cache, 0);

  if (!id_cache)
    goto finish;

  curr = (caddr_t **) id_hash_get (id_cache, (char *) &id);
  if (!curr)
    goto finish;

#if 0
  xs = dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xml_c_build_ancessor_ns_link (xte->xe_doc.xtd->xtd_tree, curr[0], nss, &xs->xs_parent_link);
  xte->xte_current = curr[0];
  xs->xs_doc = xte;
  xs->xs_namespaces = nss;

  ret_text = xml_doc_subst (xs);
  xml_c_nss_free (nss);

  ret = 1;

  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, ret_text, box_length (ret_text) - 1);
    }
  FAILED
    {
      END_WRITE_FAIL (ses_out);
      goto finish;
    }
  END_WRITE_FAIL (ses_out);
#else
  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, text, box_length (text) - 1);
    }
  FAILED
    {
      END_WRITE_FAIL (ses_out);
      goto finish;
    }
  END_WRITE_FAIL (ses_out);
  ret = 1;
#endif


 finish:
#ifdef DEBUG
  if (!ret)
    breakpoint();
#endif
  dk_free_box (text);
  dk_free_tree (err_ret);
  dk_free_box (ret_text);
  dk_free_box ((box_t) xte);
  if (xs)
    {
      dk_set_free (xs->xs_parent_link);
      xml_doc_subst_free (xs);
    }
  if (id_cache)
    xenc_ids_hash_free (id_cache);
  nss_free (nss);
  return ret;
}


/* SHA1 ***********************************************************************/

/* digest */
int
dsig_sha1_digest (dk_session_t * ses_in, long len, caddr_t * digest_out)
{
  SHA_CTX ctx;
  unsigned char md[SHA_DIGEST_LENGTH];
  unsigned char buf[1];
  int i;
  int count = 0;

  SHA1_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA1_Update(&ctx,buf,(unsigned long)i);
	  count++;
#ifdef DEBUG
	  printf ("%c", buf[0]);
	  fflush (stdout);
#endif
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA1_Final(&(md[0]),&ctx);
  if (digest_out)
    {
      int len;
      char encoded_digest[SHA_DIGEST_LENGTH * 2];
      len = xenc_encode_base64 ((char *)md, encoded_digest, SHA_DIGEST_LENGTH);
      digest_out[0] = dk_alloc_box (len + 1, DV_STRING);
      memcpy (digest_out[0], encoded_digest, len);
      digest_out[0][len] = 0;
    }
  return 2 * SHA_DIGEST_LENGTH + 4 /* spaces */;
}

#ifdef SHA256_ENABLE
int
dsig_sha256_digest (dk_session_t * ses_in, long len, caddr_t * digest_out)
{
  SHA256_CTX ctx;
  unsigned char md[SHA256_DIGEST_LENGTH];
  unsigned char buf[1];
  int i;
  int count = 0;

  SHA256_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA256_Update(&ctx,buf,(unsigned long)i);
	  count++;
#ifdef DEBUG
	  printf ("%c", buf[0]);
	  fflush (stdout);
#endif
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA256_Final(&(md[0]),&ctx);
  if (digest_out)
    {
      int len;
      char encoded_digest[SHA256_DIGEST_LENGTH * 2];
      len = xenc_encode_base64 ((char *)md, encoded_digest, SHA256_DIGEST_LENGTH);
      digest_out[0] = dk_alloc_box (len + 1, DV_STRING);
      memcpy (digest_out[0], encoded_digest, len);
      digest_out[0][len] = 0;
    }
  return 2 * SHA256_DIGEST_LENGTH + 4 /* spaces */;
}

int
dsig_dh_sha256_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  return 0;
}

int
dsig_dh_sha256_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest)
{
  return 0;
}

int
dsig_hmac_sha256_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  unsigned char * data;
  HMAC_CTX ctx;
  unsigned char key_data[32 * 8];
  unsigned char md [SHA256_DIGEST_LENGTH + 1];
  unsigned char md64 [SHA256_DIGEST_LENGTH * 2 + 1];
  unsigned int hmac_len = 0;
  int key_len = 0;

  if (NULL == key)
    return 0;

  switch (key->xek_type)
    {
      case DSIG_KEY_3DES:
	  memcpy (key_data, key->ki.triple_des.k1, sizeof (des_cblock));
	  memcpy (key_data + 8, key->ki.triple_des.k2, sizeof (des_cblock));
	  memcpy (key_data + 16, key->ki.triple_des.k3, sizeof (des_cblock));
	  key_len = 3 * sizeof (des_cblock);
	  break;
#ifdef AES_ENC_ENABLE
      case DSIG_KEY_AES:
	  memcpy (key_data, key->ki.aes.k, key->ki.aes.bits / 8);
          key_len = key->ki.aes.bits / 8;
	  break;
#endif
      case DSIG_KEY_RAW:
	  if ((key->ki.raw.bits / 8) > sizeof (key_data))
	    return 0;
	  memcpy (key_data, key->ki.raw.k, key->ki.raw.bits / 8);
	  key_len = key->ki.raw.bits / 8;
	  break;
      default:
	  return 0;
    }


  data = (unsigned char *) dk_alloc_box (len, DV_C_STRING);
  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, (char *)data, len);
    }
  FAILED
    {
      dk_free_box ((box_t) data);
      return 0;
    }
  END_READ_FAIL (ses_in);

  HMAC_Init(&ctx, (void*) key_data , key_len, EVP_sha256 ());
  HMAC_Update(&ctx, data, len);
  HMAC_Final(&ctx, md, &hmac_len);
  HMAC_cleanup(&ctx);

  if (hmac_len != SHA256_DIGEST_LENGTH)
    GPF_T;

  md[SHA256_DIGEST_LENGTH] = 0;

  if (sign_out)
    {
      int l = xenc_encode_base64 ((char *)md, (char *)md64, SHA256_DIGEST_LENGTH);
      sign_out [0] = dk_alloc_box (l + 1, DV_STRING);
      memcpy (sign_out[0], md64, l);
      sign_out[0][l] = 0;
    }
  dk_free_box ((box_t) data);
  return SHA256_DIGEST_LENGTH;
}

int
dsig_hmac_sha256_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest)
{
  HMAC_CTX ctx;
  unsigned char * data;
  unsigned char key_data[3 * 8];
  unsigned char md [SHA256_DIGEST_LENGTH + 1];
  char md64 [SHA256_DIGEST_LENGTH * 2 + 1];
  unsigned int hmac_len = 0, len1;
  int key_len = 0;

  if (NULL == key)
    return 0;

  switch (key->xek_type)
    {
      case DSIG_KEY_3DES:
	  memcpy (key_data, key->ki.triple_des.k1, sizeof (des_cblock));
	  memcpy (key_data + 8, key->ki.triple_des.k2, sizeof (des_cblock));
	  memcpy (key_data + 16, key->ki.triple_des.k3, sizeof (des_cblock));
	  key_len = 3 * sizeof (des_cblock);
	  break;
#ifdef AES_ENC_ENABLE
      case DSIG_KEY_AES:
	  memcpy (key_data, key->ki.aes.k, key->ki.aes.bits / 8);
          key_len = key->ki.aes.bits / 8;
	  break;
#endif
      default:
	  return 0;
    }


  data = (unsigned char *) dk_alloc_box (len, DV_C_STRING);
  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, (char *)data, len);
    }
  FAILED
    {
      dk_free_box ((box_t) data);
      return 0;
    }
  END_READ_FAIL (ses_in);

  HMAC_Init(&ctx, (void*) key_data , key_len, EVP_sha256 ());
  HMAC_Update(&ctx, data, len);
  HMAC_Final(&ctx, md, &hmac_len);
  HMAC_cleanup(&ctx);
  dk_free_box ((box_t) data);

  len1 = xenc_encode_base64 ((char *)md, md64, hmac_len);
  md64[len1] = 0;

  if (!strcmp (digest, md64))
    return 1;
  return 0;
}
#endif

/* signature functions
   typedef int (*dsig_algo_f) (dk_session_t * ses_in, long len, dk_session_t * ses_out);
*/
int
dsig_dsa_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  SHA_CTX ctx;
  unsigned char md[SHA_DIGEST_LENGTH + 1];
  unsigned char buf[1];
  unsigned char sig[256];
  unsigned int siglen;
  int i;

  if (NULL == key)
    return 0;
  memset (md, 0, sizeof (md));
  SHA1_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA1_Update(&ctx,buf,(unsigned long)i);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA1_Final(&(md[0]),&ctx);

  DSA_sign(NID_sha1, md, SHA_DIGEST_LENGTH, sig, &siglen, key->ki.dsa.dsa_st);

  if (sign_out)
    {
      caddr_t encoded_out = dk_alloc_box_zero (siglen * 2 + 1, DV_STRING);
      len = xenc_encode_base64 ((char *)sig, encoded_out, siglen);
      sign_out[0] = dk_alloc_box_zero (len + 1, DV_STRING);
      memcpy (sign_out[0], encoded_out, len);
      dk_free_box (encoded_out);
    }
  return len;
}


int
dsig_dsa_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest)
{
  SHA_CTX ctx;
  unsigned char md[SHA_DIGEST_LENGTH + 1];
  unsigned char buf[1];
  int i;
  unsigned char sig[256];
  unsigned int siglen;

  if (NULL == key)
    return 0;

  siglen = box_length (digest) - 1;
  assert (siglen <= sizeof (sig));
  memcpy (sig, digest, siglen + 1);
  siglen = xenc_decode_base64 ((char *)sig, (char *)(sig + siglen + 1));

  memset (md, 0, sizeof (md));
  SHA1_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA1_Update(&ctx,buf,(unsigned long)i);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA1_Final(&(md[0]),&ctx);

  i = DSA_verify (NID_sha1, md, SHA_DIGEST_LENGTH, sig, siglen, key->ki.dsa.dsa_st);
  return i;
}

int
dsig_dh_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  return 0;
}

int
dsig_dh_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest)
{
  return 0;
}
/* signature functions
   typedef int (*dsig_algo_f) (dk_session_t * ses_in, long len, dk_session_t * ses_out);
*/
int
dsig_rsa_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  SHA_CTX ctx;
  unsigned char md[SHA_DIGEST_LENGTH + 1];
  unsigned char buf[1];
  unsigned char sig[256 + 1];
  unsigned int siglen;
  int i;

  if (NULL == key)
    return 0;

  if (key->xek_type != DSIG_KEY_RSA)
    return 0;

  if (!key->xek_private_rsa)
    return 0;

  memset (md, 0, sizeof (md));
  SHA1_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA1_Update(&ctx,buf,(unsigned long)i);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA1_Final(&(md[0]),&ctx);

  RSA_sign(NID_sha1, md, SHA_DIGEST_LENGTH, sig, &siglen, key->xek_private_rsa);
  sig[siglen] = 0;

  if (sign_out)
    {
      caddr_t encoded_out = dk_alloc_box_zero (siglen * 2 + 1, DV_STRING);
      len = xenc_encode_base64 ((char *)sig, encoded_out, siglen);
      sign_out[0] = dk_alloc_box_zero (len + 1, DV_STRING);
      memcpy (sign_out[0], encoded_out, len);
      dk_free_box (encoded_out);
    }
  return len;
}


int
dsig_rsa_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest_base64)
{
  SHA_CTX ctx;
  unsigned char md[SHA_DIGEST_LENGTH + 1];
  unsigned char buf[1];
  int i;
  unsigned char * sig;
  unsigned int siglen;

  if (NULL == key)
    return 0;


#if 0
  memcpy (sig, digest_base64, box_length (digest_base64));
  siglen = decode_base64 (digest, digest + box_length (digest_base64) - 1);
#else
  siglen = box_length (digest_base64);
  sig = (unsigned char *) dk_alloc_box_zero (siglen, DV_BIN);
  memcpy (sig, digest_base64, siglen);
  siglen = xenc_decode_base64 ((char *)sig, (char *)(sig + siglen));
#endif

  memset (md, 0, sizeof (md));
  SHA1_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA1_Update(&ctx,buf,(unsigned long)i);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA1_Final(&(md[0]),&ctx);

  i = RSA_verify (NID_sha1, md, SHA_DIGEST_LENGTH, sig, siglen, key->xek_rsa);

  dk_free_box ((box_t) sig);

  return i;
}

#ifdef SHA256_ENABLE
int
dsig_rsa_sha256_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  SHA256_CTX ctx;
  unsigned char md[SHA256_DIGEST_LENGTH + 1];
  unsigned char buf[1];
  unsigned char sig[256 + 1];
  unsigned int siglen;
  int i;

  if (NULL == key)
    return 0;

  if (key->xek_type != DSIG_KEY_RSA)
    return 0;

  if (!key->xek_private_rsa)
    return 0;

  memset (md, 0, sizeof (md));
  SHA256_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA256_Update(&ctx,buf,(unsigned long)i);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA256_Final(&(md[0]),&ctx);

  RSA_sign (NID_sha256, md, SHA256_DIGEST_LENGTH, sig, &siglen, key->xek_private_rsa);
  sig[siglen] = 0;

  if (sign_out)
    {
      caddr_t encoded_out = dk_alloc_box_zero (siglen * 2 + 1, DV_STRING);
      len = xenc_encode_base64 ((char *)sig, encoded_out, siglen);
      sign_out[0] = dk_alloc_box_zero (len + 1, DV_STRING);
      memcpy (sign_out[0], encoded_out, len);
      dk_free_box (encoded_out);
    }
  return len;
}

int
dsig_rsa_sha256_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest_base64)
{
  SHA256_CTX ctx;
  unsigned char md[SHA256_DIGEST_LENGTH + 1];
  unsigned char buf[1];
  int i;
  unsigned char * sig;
  unsigned int siglen;

  if (NULL == key)
    return 0;


  siglen = box_length (digest_base64);
  sig = (unsigned char *) dk_alloc_box_zero (siglen, DV_BIN);
  memcpy (sig, digest_base64, siglen);
  siglen = xenc_decode_base64 ((char *)sig, (char *)(sig + siglen));

  memset (md, 0, sizeof (md));
  SHA256_Init(&ctx);

  CATCH_READ_FAIL (ses_in)
    {
      for (;;)
	{
          i = session_buffered_read (ses_in, (char *)buf, 1);
	  if (i <= 0) break;
	  SHA256_Update(&ctx,buf,(unsigned long)i);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses_in);

  SHA256_Final(&(md[0]),&ctx);

  i = RSA_verify (NID_sha256, md, SHA256_DIGEST_LENGTH, sig, siglen, key->xek_rsa);

  dk_free_box ((box_t) sig);

  return i;
}
#endif

int
dsig_hmac_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out)
{
  unsigned char * data;
  HMAC_CTX ctx;
  unsigned char key_data[32 * 8];
  unsigned char md [SHA_DIGEST_LENGTH + 1];
  unsigned char md64 [SHA_DIGEST_LENGTH * 2 + 1];
  unsigned int hmac_len = 0;
  int key_len = 0;

  if (NULL == key)
    return 0;

  switch (key->xek_type)
    {
      case DSIG_KEY_3DES:
	  memcpy (key_data, key->ki.triple_des.k1, sizeof (des_cblock));
	  memcpy (key_data + 8, key->ki.triple_des.k2, sizeof (des_cblock));
	  memcpy (key_data + 16, key->ki.triple_des.k3, sizeof (des_cblock));
	  key_len = 3 * sizeof (des_cblock);
	  break;
#ifdef AES_ENC_ENABLE
      case DSIG_KEY_AES:
	  memcpy (key_data, key->ki.aes.k, key->ki.aes.bits / 8);
          key_len = key->ki.aes.bits / 8;
	  break;
#endif
      case DSIG_KEY_RAW:
	  if ((key->ki.raw.bits / 8) > sizeof (key_data))
	    return 0;
	  memcpy (key_data, key->ki.raw.k, key->ki.raw.bits / 8);
	  key_len = key->ki.raw.bits / 8;
	  break;
      default:
	  return 0;
    }


  data = (unsigned char *) dk_alloc_box (len, DV_C_STRING);
  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, (char *)data, len);
    }
  FAILED
    {
      dk_free_box ((box_t) data);
      return 0;
    }
  END_READ_FAIL (ses_in);

  HMAC_Init(&ctx, (void*) key_data , key_len, EVP_sha1 ());
  HMAC_Update(&ctx, data, len);
  HMAC_Final(&ctx, md, &hmac_len);
  HMAC_cleanup(&ctx);

  if (hmac_len != SHA_DIGEST_LENGTH)
    GPF_T;

  md[SHA_DIGEST_LENGTH] = 0;

  if (sign_out)
    {
      int l = xenc_encode_base64 ((char *)md, (char *)md64, SHA_DIGEST_LENGTH);
      sign_out [0] = dk_alloc_box (l + 1, DV_STRING);
      memcpy (sign_out[0], md64, l);
      sign_out[0][l] = 0;
    }
  dk_free_box ((box_t) data);
  return SHA_DIGEST_LENGTH;
}

int
dsig_hmac_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest)
{
  HMAC_CTX ctx;
  unsigned char * data;
  unsigned char key_data[3 * 8];
  unsigned char md [SHA_DIGEST_LENGTH + 1];
  char md64 [SHA_DIGEST_LENGTH * 2 + 1];
  unsigned int hmac_len = 0, len1;
  int key_len = 0;

  if (NULL == key)
    return 0;

  switch (key->xek_type)
    {
      case DSIG_KEY_3DES:
	  memcpy (key_data, key->ki.triple_des.k1, sizeof (des_cblock));
	  memcpy (key_data + 8, key->ki.triple_des.k2, sizeof (des_cblock));
	  memcpy (key_data + 16, key->ki.triple_des.k3, sizeof (des_cblock));
	  key_len = 3 * sizeof (des_cblock);
	  break;
#ifdef AES_ENC_ENABLE
      case DSIG_KEY_AES:
	  memcpy (key_data, key->ki.aes.k, key->ki.aes.bits / 8);
          key_len = key->ki.aes.bits / 8;
	  break;
#endif
      default:
	  return 0;
    }


  data = (unsigned char *) dk_alloc_box (len, DV_C_STRING);
  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, (char *)data, len);
    }
  FAILED
    {
      dk_free_box ((box_t) data);
      return 0;
    }
  END_READ_FAIL (ses_in);

  HMAC_Init(&ctx, (void*) key_data , key_len, EVP_sha1 ());
  HMAC_Update(&ctx, data, len);
  HMAC_Final(&ctx, md, &hmac_len);
  HMAC_cleanup(&ctx);
  dk_free_box ((box_t) data);

  len1 = xenc_encode_base64 ((char *)md, md64, hmac_len);
  md64[len1] = 0;

  if (!strcmp (digest, md64))
    return 1;
  return 0;
}

caddr_t xenc_alloc_cbc_box (long len, size_t block_size, dtp_t t1)
{
  size_t buffer_len = len;
  int nblocks;
  int last_block_size = buffer_len % block_size;
  unsigned char npads = (unsigned char ) (block_size - last_block_size);
  caddr_t box;

  nblocks = buffer_len / block_size + 1;
  buffer_len = nblocks * block_size;

  box = dk_alloc_box (buffer_len, t1);
  /* write last byte according http://www.w3.org/TR/xmlenc-core/#sec-Alg-Block */
  box[nblocks * block_size - 1] = (unsigned char) npads;

  return box;
}

int xenc_write_cbc_buffer (unsigned char* buf, long len, dk_session_t * out)
{
  unsigned char npadds;
  if (!len)
    return 0;

  npadds = buf [len-1];

  len -= npadds;

  CATCH_WRITE_FAIL (out)
    {
      session_buffered_write (out, (char *)buf, len);
    }
  FAILED
    {
      return 0;
    }
  END_WRITE_FAIL (out);
  return len;
}

#ifdef AES_ENC_ENABLE
int xenc_aes_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t)
{
  caddr_t text = xenc_alloc_cbc_box (seslen, sizeof (char) * AES_BLOCK_SIZE, DV_STRING);
  caddr_t outbuf;
  int outlen;
  caddr_t outbuf_beg;
  int len;
  caddr_t encoded_out;
  EVP_CIPHER_CTX ctx;
  unsigned char * ivec = &key->ki.aes.iv[0];

  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, text, seslen);
    }
  FAILED
    {
      dk_free_box (text);
      xenc_report_error (t, 500, XENC_ENC_ERR, "could not read input data");
    }
  END_READ_FAIL (ses_in);

#if 1
  EVP_CIPHER_CTX_init(&ctx);
  outbuf_beg = dk_alloc_box (box_length (text) + 16, DV_BIN);
  memcpy (outbuf_beg, ivec, 16);
  outbuf = outbuf_beg + 16;

  switch (key->ki.aes.bits)
    {
    case 128:
      EVP_EncryptInit_ex(&ctx, EVP_aes_128_cbc(), NULL, key->ki.aes.k, ivec);
      break;
    case 192:
      EVP_EncryptInit_ex(&ctx, EVP_aes_192_cbc(), NULL, key->ki.aes.k, ivec);
      break;
    case 256:
      EVP_EncryptInit_ex(&ctx, EVP_aes_256_cbc(), NULL, key->ki.aes.k, ivec);
      break;
    default:
      GPF_T1 ("Unsupported key size");
    }
  if(!EVP_EncryptUpdate(&ctx, (unsigned char *)outbuf, &outlen, (unsigned char *)text, box_length (text)))
    {
      EVP_CIPHER_CTX_cleanup(&ctx);
      dk_free_box (text);
      dk_free_box (outbuf_beg);
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES encryption internal error #2");
    }
  /* if(!EVP_EncryptFinal_ex(&ctx, outbuf + outlen, &tmplen))
    {
      EVP_CIPHER_CTX_cleanup(&ctx);
      dk_free_box (text);
      dk_free_box (outbuf_beg);
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES encryption internal error #3");
      } */
  /* outlen += tmplen; */
  EVP_CIPHER_CTX_cleanup(&ctx);

#else
  outbuf_beg = dk_alloc_box (box_length (text) + 16 /* iv */, DV_BIN);
  memcpy (outbuf_beg, ivec, 16);
  outbuf = outbuf_beg + 16;

  AES_set_encrypt_key(key->ki.aes.k, key->ki.aes.bits, &aes_schedule);
  AES_cbc_encrypt(text, outbuf, box_length (text), &aes_schedule,
		  (unsigned char *) key->ki.aes.iv, AES_ENCRYPT);
#endif

  encoded_out = dk_alloc_box (box_length (outbuf_beg) * 2 + 1, DV_STRING);
  len = xenc_encode_base64 (outbuf_beg, encoded_out, box_length (outbuf_beg));
  dk_free_box (outbuf_beg);

  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, encoded_out, len);
    }
  FAILED
    {
      dk_free_box (encoded_out);
      xenc_report_error (t, 500, XENC_ENC_ERR, "could not write result data");
    }
  END_WRITE_FAIL (ses_out);

  dk_free_box (encoded_out);
  return 1;
}

int xenc_aes_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t)
{
  caddr_t text;
  caddr_t text_beg = text = dk_alloc_box (seslen + 1, DV_BIN);
  int len;
  unsigned char ivec [EVP_MAX_IV_LENGTH];
  int outlen;
  AES_KEY aes_schedule;

  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, text, seslen);
      text[seslen] = 0;
    }
  FAILED
    {
      dk_free_box (text_beg);
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES decryption internal error #1");
    }
  END_READ_FAIL (ses_in);

  len = xenc_decode_base64 (text, text + seslen + 1);

  if (len < 16)
    {
      dk_free_box (text_beg);
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES decryption internal error #3");
    }
  memcpy (ivec, text, 16);
  memcpy (&key->ki.aes.iv, &ivec, 16);
  text += 16;

#if 0
  EVP_CIPHER_CTX_init(&ctx);
  switch (key->ki.aes.bits)
    {
    case 128:
      EVP_DecryptInit_ex(&ctx, EVP_aes_128_cbc(), NULL, key->ki.aes.k, ivec);
      break;
    case 192:
      EVP_DecryptInit_ex(&ctx, EVP_aes_192_cbc(), NULL, key->ki.aes.k, ivec);
      break;
    case 256:
      EVP_DecryptInit_ex(&ctx, EVP_aes_256_cbc(), NULL, key->ki.aes.k, ivec);
      break;
    default:
      GPF_T1 ("unsupported key size");
    }
  outbuf = dk_alloc_box (len + EVP_MAX_BLOCK_LENGTH, DV_STRING);

  if(!EVP_DecryptUpdate(&ctx, outbuf, &outlen, text, len - 16))
    {
      EVP_CIPHER_CTX_cleanup(&ctx);
      dk_free_box (text_beg);
      dk_free_box (outbuf);
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES decryption internal error #2");
    }
  if(!EVP_DecryptFinal_ex (&ctx, outbuf + outlen, &tmplen))
    {
      unsigned long err = ERR_get_error();
      char buf [120];
      EVP_CIPHER_CTX_cleanup(&ctx);
      dk_free_box (text_beg);
      dk_free_box (outbuf);
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES decryption internal error %s",
			 ERR_error_string (err, buf));
    }
  outlen += tmplen;
  EVP_CIPHER_CTX_cleanup(&ctx);
#else
  AES_set_decrypt_key(key->ki.aes.k, key->ki.aes.bits, &aes_schedule);
  outlen = len - 16;
  AES_cbc_encrypt((const unsigned char *) text, (unsigned char *) text,
                  outlen, &aes_schedule,
		  (unsigned char *) key->ki.aes.iv, AES_DECRYPT);
#endif

  if (!xenc_write_cbc_buffer ((unsigned char *)text, outlen, ses_out))
    {
      dk_free_box (text_beg);
      /* dk_free_box (outbuf); */
      xenc_report_error (t, 500, XENC_ENC_ERR, "AES decryption internal error #4");
    }
#if 0
  dk_free_box (outbuf);
#endif
  return 1;
}
#endif
int
xenc_dsa_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			xenc_key_t * key, xenc_try_block_t * t)
{
  if (t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "DSA is for signatures only and is not an encryption algorithm");
  return 0;
}

int
xenc_dsa_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			xenc_key_t * key, xenc_try_block_t * t)
{
  if (t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "DSA is for signatures only and is not an encryption algorithm");
  return 0;
}

int
xenc_dh_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			xenc_key_t * key, xenc_try_block_t * t)
{
  if (t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "DH is for signatures only and is not an encryption algorithm");
  return 0;
}

int
xenc_dh_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			xenc_key_t * key, xenc_try_block_t * t)
{
  if (t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "DH is for signatures only and is not an encryption algorithm");
  return 0;
}

int
xenc_rsa_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			xenc_key_t * key, xenc_try_block_t * t)
{
  char * buf;
  char * out_buf = NULL;
  int tot_l = 0;
  int len;
  int keysize;
  dk_session_t * ses_out;
  caddr_t out = 0;
  caddr_t out1 = 0;


  if (!seslen)
    return 0;
  if (seslen != 16 &&
      seslen != 24 &&
      seslen != 32)
    return 0;

  keysize = RSA_size(key->ki.rsa.rsa_st);
  if (keysize < 26)
    return 0;

  ses_out = strses_allocate ();

  buf = dk_alloc_box (seslen * 2, DV_BIN);

  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, buf, seslen);
    }
  FAILED
    {
      goto end;
    }
  END_READ_FAIL (ses_in);

  out_buf = dk_alloc_box_zero (keysize, DV_BIN);

  tot_l = len = RSA_public_encrypt(seslen, (unsigned char *)buf, (unsigned char *)out_buf, key->ki.rsa.rsa_st, key->ki.rsa.pad);

  out = dk_alloc_box_zero ( len * 2 + 1, DV_BIN);
  len = xenc_encode_base64 (out_buf, out, len);

  CATCH_WRITE_FAIL (ses_out_base64)
    {
      session_buffered_write (ses_out_base64, out, len);
    }
  FAILED
    {
      tot_l = 0;
      goto end;
    }
  END_WRITE_FAIL (ses_out);

 end:
  dk_free_box (buf);
  dk_free_box (out_buf);
  dk_free_box (out);
  dk_free_box (out1);
  strses_free (ses_out);

  if (!tot_l && t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "could not make RSA encryption");

  return tot_l;
}


int
xenc_rsa_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			xenc_key_t * key, xenc_try_block_t * t)
{
  char * buf;
  char * out_buf = 0;
  int err = 1;
  int len = 0;
  int keysize;
  RSA * rsa = key->xek_private_rsa;

  if (!seslen)
    {
      xenc_report_error (t, 500, XENC_ENC_ERR, "could not make RSA decryption [empty input stream]");
      return 0;
    }

  if (key->xek_type != DSIG_KEY_RSA)
    {
      xenc_report_error (t, 500 + strlen (key->xek_name), XENC_ENC_ERR, "could not make RSA decryption [key %s is not RSA]", key->xek_name);
      return 0;
    }
  if (!rsa ||
      !rsa->p ||
      !rsa->q)
    {
      if (key->xek_x509_KI)
	key = xenc_get_key_by_keyidentifier (key->xek_x509_KI, 1);
      if (key && key->xek_private_rsa)
	{
	  rsa = key->xek_private_rsa;
	  goto cont;
	}
      xenc_report_error (t, 500 + strlen (key->xek_name), XENC_ENC_ERR, "could not make RSA decryption [key %s is not RSA private]", key->xek_name);
      return 0;
    }
 cont:
  keysize = RSA_size(rsa);

  buf = dk_alloc_box_zero (seslen + 1, DV_STRING);

  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, buf, seslen);
    }
  FAILED
    {
      goto end;
    }
  END_READ_FAIL (ses_in);

  len = xenc_decode_base64 (buf, buf + seslen + 1);
  if (!len)
    goto end;
  if (len != keysize)
    goto end;

  out_buf = dk_alloc_box_zero (keysize + 1, DV_STRING);

  len = RSA_private_decrypt (len, (unsigned char *)buf, (unsigned char *)out_buf, rsa, key->ki.rsa.pad);

  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, out_buf, len);
      err = 0;
    }
  FAILED
    {
      goto end;
    }
  END_WRITE_FAIL (ses_out);

 end:
  dk_free_box (buf);
  dk_free_box (out_buf);

  if (err && t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "could not make RSA encryption");

  return len;
}

#ifdef _KERBEROS
caddr_t
krb_seal (gss_ctx_id_t context, caddr_t in_buf_cont);

int xenc_kerberos_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			     xenc_key_t * key, xenc_try_block_t * t)
{
  caddr_t in_buf = 0;
  caddr_t ret_buf = 0;
  int err = 1;
  if (key->xek_type != DSIG_KEY_KERBEROS)
    GPF_T;

  in_buf = dk_alloc_box (seslen + 1, DV_STRING);
  CATCH_READ_FAIL (ses_in)
    {
      session_buffered_read (ses_in, in_buf, seslen);
      in_buf[seslen] = 0;
    }
  FAILED
    {
      goto end;
    }
  END_READ_FAIL (ses_in);

  ret_buf = krb_seal (key->ki.kerb.context, in_buf);
  if (!ret_buf)
    goto end;

  CATCH_WRITE_FAIL (ses_out_base64)
    {
      session_buffered_write (ses_out_base64, ret_buf, box_length (ret_buf) - 1);
    }
  FAILED
    {
      goto end;
    }
  END_WRITE_FAIL (ses_out_base64);

  err = 0;
 end:
  dk_free_box (in_buf);
  dk_free_box (ret_buf);
  if (err)
    xenc_report_error (t, 500 + strlen (key->xek_name), XENC_ENC_ERR,
		     "could not encrypt by kerberos key %s", key->xek_name);
  return 0;
}
#endif

static const char des3_magic[]="Salted__";

#define DES_BLOCK_LEN	8
int xenc_des3_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out_base64,
			   xenc_key_t * key, xenc_try_block_t * t)
{
  char buf[DES_BLOCK_LEN + 1];
  char out_buf[DES_BLOCK_LEN + 1];
  int read_b = 0;
  int tot_l = 0;
  dk_session_t * ses_out;
  caddr_t buffer;
  caddr_t buffer_base64;
  long len;
  unsigned char iv [DES_BLOCK_LEN];
  unsigned char * _iv = &iv[0];
  int blocks, total_blocks = 0, total_len;

#ifdef _KERBEROS
  if (key->xek_type == DSIG_KEY_KERBEROS)
    return xenc_kerberos_encryptor (ses_in, seslen, ses_out_base64, key, t);
  else
#endif
    if (key->xek_type != DSIG_KEY_3DES)
    GPF_T;

  memcpy (_iv, (unsigned char *) key->ki.triple_des.iv, sizeof (key->ki.triple_des.iv));

  if (!seslen)
    return 0;

  ses_out = strses_allocate ();
  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, (const char *) _iv, 8);
    }
  FAILED
    {
      tot_l = 0;
      goto end;
    }
  END_WRITE_FAIL (ses_out);

  tot_l += 8;
  blocks = seslen / DES_BLOCK_LEN;
  total_blocks = 1;

  while (blocks >= 0)
    {
      CATCH_READ_FAIL (ses_in)
	{
	  memset (buf, 22, DES_BLOCK_LEN);
	  if (blocks)
	    read_b = DES_BLOCK_LEN;
	  else
	    read_b = seslen % DES_BLOCK_LEN;
	  if (read_b)
	    session_buffered_read (ses_in, buf, read_b);
	}
      FAILED
	{
        }
      END_READ_FAIL (ses_in);

      tot_l += read_b;

      if (!blocks)
	{
	  memset (buf + read_b, DES_BLOCK_LEN - read_b, DES_BLOCK_LEN - read_b);
	  /*	  buf[DES_BLOCK_LEN - 1] = DES_BLOCK_LEN - read_b; */
	}


      des_ede3_cbc_encrypt ((const unsigned char *)buf,
		(unsigned char *)out_buf,
		(long)DES_BLOCK_LEN,
		key->ki.triple_des.ks1,
		key->ki.triple_des.ks2,
		key->ki.triple_des.ks3,
		(des_cblock*) _iv,
		DES_ENCRYPT);
      total_blocks++;

      CATCH_WRITE_FAIL (ses_out)
	{
	  session_buffered_write (ses_out, (char *)out_buf, DES_BLOCK_LEN);
	}
      FAILED
	{
          tot_l = 0;
	  goto end;
	}
      END_WRITE_FAIL (ses_out);
      blocks--;
    }
 end:

  if (!tot_l && t)
    {
      strses_free (ses_out);
      xenc_report_error (t, 500, XENC_ENC_ERR, "could not make triple-des encryption");
    }

  total_len = total_blocks * DES_BLOCK_LEN;

  buffer = strses_string (ses_out);
  buffer_base64 = dk_alloc_box (total_len * 2 + 1, DV_STRING);
  strses_free (ses_out);

  len = xenc_encode_base64 (buffer, buffer_base64, total_len);

  CATCH_WRITE_FAIL (ses_out_base64)
    {
      session_buffered_write (ses_out_base64, buffer_base64, len);
    }
  FAILED
    {
      tot_l = 0;
      END_WRITE_FAIL (ses_out_base64);
    }
  END_WRITE_FAIL (ses_out_base64);

  dk_free_box (buffer);
  dk_free_box (buffer_base64);

  if (!tot_l && t)
    {
      xenc_report_error (t, 500, XENC_ENC_ERR, "could not make triple-des encryption");
    }

  return tot_l;
}

#if 0
int xenc_des3_decryptor (dk_session_t * ses_in_base64, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t)
{
  int read_b;
  int len, failed=0;
  char buf[DES_BLOCK_LEN + 1];
  char out_buf[DES_BLOCK_LEN + 1];
  char *text, *text_beg;
  dk_session_t *ses_in;
  long text_len;
  des_cblock iv;

  if (!seslen)
    return 0;

  text_beg = text = dk_alloc_box_zero (seslen + 1, DV_STRING);

  CATCH_READ_FAIL (ses_in_base64)
    {
      session_buffered_read (ses_in_base64, text, seslen);
      text [seslen] = 0;
    }
  FAILED
    {
      dk_free_box (text_beg);
      return 0;
    }
  END_READ_FAIL (ses_in_base64);

  text_len = xenc_decode_base64 (text, text + seslen + 1);
  memcpy (iv, text, 8);
  text += 8;

  ses_in = strses_allocate();
  ses_in->dks_in_buffer = text;
  ses_in->dks_in_fill = text_len - 8;
  ses_in->dks_in_read = 0;

  CATCH_READ_FAIL (ses_in)
    {
      read_b  = session_buffered_read (ses_in, buf, DES_BLOCK_LEN);
    }
  FAILED
    {
      END_READ_FAIL (ses_in);
      dk_free_box (text_beg);
      strses_free (ses_in);
      return 0;
    }
  END_READ_FAIL (ses_in);
  for (;!failed;)
    {
      des_ede3_cbc_encrypt ((const unsigned char *)buf,
	(unsigned char *)out_buf,
	(long)DES_BLOCK_LEN,
	key->ki.triple_des.ks1,
	key->ki.triple_des.ks2,
	key->ki.triple_des.ks3,
	&iv,
	DES_DECRYPT);
      CATCH_READ_FAIL (ses_in)
	{
	  read_b  = session_buffered_read (ses_in, buf, DES_BLOCK_LEN);
	}
      FAILED
	{
	  failed = 1;
	}
      END_READ_FAIL (ses_in);
      len = out_buf[DES_BLOCK_LEN - 1];
      if (failed && (len < 0 || len > DES_BLOCK_LEN))
	{
	  dk_free_box (text_beg);
	  strses_free (ses_in);
	  return 0;
	}

      CATCH_WRITE_FAIL (ses_out)
	{
	  session_buffered_write (ses_out, (char *)out_buf, DES_BLOCK_LEN - ((failed)?(out_buf[DES_BLOCK_LEN-1]):0));
	}
      FAILED
	{
	  END_WRITE_FAIL (ses_out);
	  dk_free_box (text_beg);
	  strses_free (ses_in);
	  return 0;
	}
      END_WRITE_FAIL (ses_out);
    }

  dk_free_box (text_beg);
  strses_free (ses_in);

  return strses_length (ses_out);
}
#else
int xenc_des3_decryptor (dk_session_t * ses_in_base64, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t)
{
  int len;
  char buf[DES_BLOCK_LEN + 1];
  char out_buf[DES_BLOCK_LEN + 1];
  char *text, *text_beg;
  long text_len;
  des_cblock iv;
  int blocks;

  if (!seslen)
    return 0;

  text_beg = text = dk_alloc_box (seslen + 1, DV_STRING);

  CATCH_READ_FAIL (ses_in_base64)
    {
      session_buffered_read (ses_in_base64, text, seslen);
      text [seslen] = 0;
    }
  FAILED
    {
      dk_free_box (text_beg);
      return 0;
    }
  END_READ_FAIL (ses_in_base64);

  text_len = xenc_decode_base64 (text, text + seslen + 1);
  memcpy (iv, text, DES_BLOCK_LEN);
  text += DES_BLOCK_LEN;

  blocks = (text_len - DES_BLOCK_LEN)/DES_BLOCK_LEN;
  if (blocks < 1)
    {
      dk_free_box (text_beg);
      return 0;
    }

  while (blocks--)
    {
      memcpy (buf, text, DES_BLOCK_LEN);
      text += DES_BLOCK_LEN;

      des_ede3_cbc_encrypt ((const unsigned char *)buf,
	(unsigned char *)out_buf,
	(long)DES_BLOCK_LEN,
	key->ki.triple_des.ks1,
	key->ki.triple_des.ks2,
	key->ki.triple_des.ks3,
	&iv,
	DES_DECRYPT);

      if (!blocks) /* last block */
	{
	  len = DES_BLOCK_LEN - out_buf[DES_BLOCK_LEN - 1];
	  if ((len < 0) || (len > DES_BLOCK_LEN - 1))
	    {
	      dk_free_box (text_beg);
	      return 0;
	    }
	}
      else
	len = DES_BLOCK_LEN;

      if (len)
	{
	  CATCH_WRITE_FAIL (ses_out)
	    {
	      session_buffered_write (ses_out, (char *)out_buf, len);
	    }
	  FAILED
	    {
	      END_WRITE_FAIL (ses_out);
	      dk_free_box (text_beg);
	      return 0;
	    }
	  END_WRITE_FAIL (ses_out);
	}
    }

  dk_free_box (text_beg);

  return strses_length (ses_out);
}
#endif

int xenc_signature_wrapper (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t)
{
  return 0;
}
int xenc_signature_wrapper_1 (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t)
{
  return 0;
}

#ifdef DEBUG
/* tests */

void xenc_alloc_cbc_box_test()
{
  caddr_t text1 = xenc_alloc_cbc_box (3, sizeof (char) * 8, DV_STRING);
  caddr_t text2 = xenc_alloc_cbc_box (8, sizeof (char) * 8, DV_STRING);

  xenc_assert (text1[7] == 5);
  xenc_assert (text2[15] == 8);

  dk_free_box (text1);
  dk_free_box (text2);
}

void xenc_aes_enctest_1 (const char * data)
{
#ifdef AES_ENC_ENABLE
  unsigned char key_data[16] = "0123456789ABCDEF";
  xenc_key_t * k = xenc_key_aes_create ("aes_k128", 128, (unsigned char *) key_data);
  dk_session_t *in, *out;
  xenc_try_block_t t;

  memcpy (k->ki.aes.k, key_data, 16);
  in = strses_allocate ();
  out = strses_allocate ();

  in->dks_in_buffer = (unsigned char *) data;
  in->dks_in_fill = strlen (data);
  in->dks_in_read = 0;

  XENC_TRY (&t)
    {
      xenc_aes_encryptor (in, in->dks_in_fill, out, k, &t);
      strses_flush (in);

      xenc_aes_decryptor (out, strses_length (out), in, k, &t);
    }
  FAILED
    {
      xenc_assert (0);
      rep_printf ("[%ld] %s\n", t.xtb_err_code, t.xtb_err_buffer);
      ERR_print_errors_fp (stdout);
      dk_free_box (t.xtb_err_buffer);
    }
  XENC_TRY_END (&t);

  strses_free (out);
  strses_free (in);
  xenc_key_remove (k, 1);
#endif
}

void xenc_aes_enctest ()
{
  xenc_aes_enctest_1 ("hello world!");
  xenc_aes_enctest_1 ("hello world!sdjkflksdfjlksjdflksjdlfkjsdlfjksldfk lsdfkjsdlfk");
  xenc_aes_enctest_1 ("The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client side SOAP extension attributes in the proxy. The Importers will also inspect the WSDL file for the relevant WS-Security headers and will remove the automatically handled and created SoapHeaders on the client side from the generated proxy, because the client-side proxy will handle these headers internally.");
  xenc_aes_enctest_1 ("The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client");
  xenc_aes_enctest_1 ("The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known");
  xenc_aes_enctest_1 ("The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client side SOAP extension attributes in the proxy. The Importers will also inspect the WSDL file for the relevant WS-Security headers and will remove the automatically handled and created SoapHeaders on the client side from the generated proxy, because the client-side proxy will handle these headers internally. The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client side SOAP extension attributes in the proxy. The Importers will also inspect the WSDL file for the relevant WS-Security headers and will remove the automatically handled and created SoapHeaders on the client side from the generated proxy, because the client-side proxy will handle these headers internally.");
}

long is_test_processing;



void xenc_test_begin()
{
  xenc_errs = 0;
  xenc_asserts = 0;
  is_test_processing = 1;
}

int xenc_test_processing ()
{
  return is_test_processing;
}

void xenc_test_end()
{
  is_test_processing = 0;
}


void xenc_asserts_print_report(FILE * stream)
{
  rep_printf ("report: %ld tests, %ld failed\n", xenc_asserts, xenc_errs);
  fprintf (stream, "report: %ld test, %ld failed\n", xenc_asserts, xenc_errs);
  fflush (stream);
}


/* digest test funcs */
int dsig_test_digest_1 (dk_session_t * ses, long len, caddr_t * out) {  return 0;}
int dsig_test_digest_2 (dk_session_t * ses, long len, caddr_t * out) {  return 0;}
int dsig_test_digest_3 (dk_session_t * ses, long len, caddr_t * out) {  return 0;}
int dsig_test_digest_4 (dk_session_t * ses, long len, caddr_t * out){  return 0;}
int dsig_test_digest_5 (dk_session_t * ses, long len, caddr_t * out){  return 0;}
/* trans test func */
int dsig_test_trans_1 (query_instance_t * qi, dk_session_t * ses, long len, dk_session_t * ses_out, caddr_t tr_data){  return 0;}
int dsig_test_trans_2 (query_instance_t * qi, dk_session_t * ses, long len, dk_session_t * ses_out, caddr_t tr_data){  return 0;}
int dsig_test_trans_3 (query_instance_t * qi, dk_session_t * ses, long len, dk_session_t * ses_out, caddr_t tr_data){  return 0;}
int dsig_test_trans_4 (query_instance_t * qi, dk_session_t * ses, long len, dk_session_t * ses_out, caddr_t tr_data){  return 0;}
int dsig_test_trans_5 (query_instance_t * qi, dk_session_t * ses, long len, dk_session_t * ses_out, caddr_t tr_data){  return 0;}
/* dsig */
int dsig_test_sign_1 (dk_session_t * ses, long len, xenc_key_t * key, caddr_t * out){  return 0;}
int dsig_test_sign_2 (dk_session_t * ses, long len, xenc_key_t * key, caddr_t * out){  return 0;}
int dsig_test_sign_3 (dk_session_t * ses, long len, xenc_key_t * key, caddr_t * out){  return 0;}
int dsig_test_sign_4 (dk_session_t * ses, long len, xenc_key_t * key, caddr_t * out){  return 0;}
int dsig_test_sign_5 (dk_session_t * ses, long len, xenc_key_t * key, caddr_t * out){  return 0;}
/* canon */
int dsig_test_canon_1 (dk_session_t * in, long len, dk_session_t * out){  return 0;}
int dsig_test_canon_2 (dk_session_t * in, long len, dk_session_t * out){  return 0;}
int dsig_test_canon_3 (dk_session_t * in, long len, dk_session_t * out){  return 0;}
int dsig_test_canon_4 (dk_session_t * in, long len, dk_session_t * out){  return 0;}
int dsig_test_canon_5 (dk_session_t * in, long len, dk_session_t * out){  return 0;}

void xenc_test_a ()
{
  xenc_assert(dsig_digest_algo_create ("dsig#test1", dsig_test_digest_1));
  xenc_assert(dsig_digest_algo_create ("dsig#test2", dsig_test_digest_2));
  xenc_assert(dsig_digest_algo_create ("dsig#test3", dsig_test_digest_3));
  xenc_assert(dsig_digest_algo_create ("dsig#test4", dsig_test_digest_4));
  xenc_assert(dsig_digest_algo_create ("dsig#test5", dsig_test_digest_5));

  xenc_assert(!dsig_digest_algo_create ("dsig#test1", dsig_test_digest_1));
  xenc_assert(!dsig_digest_algo_create ("dsig#test2", dsig_test_digest_2));
  xenc_assert(!dsig_digest_algo_create ("dsig#test3", dsig_test_digest_3));
  xenc_assert(!dsig_digest_algo_create ("dsig#test4", dsig_test_digest_4));
  xenc_assert(!dsig_digest_algo_create ("dsig#test5", dsig_test_digest_5));

  xenc_assert(dsig_digest_f_get("dsig#test1",0)==dsig_test_digest_1);
  xenc_assert(dsig_digest_f_get("dsig#test2",0)==dsig_test_digest_2);
  xenc_assert(dsig_digest_f_get("dsig#test3",0)==dsig_test_digest_3);
  xenc_assert(dsig_digest_f_get("dsig#test4",0)==dsig_test_digest_4);
  xenc_assert(dsig_digest_f_get("dsig#test5",0)==dsig_test_digest_5);

/* canon */
  xenc_assert(dsig_canon_algo_create ("dsig_canon#test1", dsig_test_canon_1));
  xenc_assert(dsig_canon_algo_create ("dsig_canon#test2", dsig_test_canon_2));
  xenc_assert(dsig_canon_algo_create ("dsig_canon#test3", dsig_test_canon_3));
  xenc_assert(dsig_canon_algo_create ("dsig_canon#test4", dsig_test_canon_4));
  xenc_assert(dsig_canon_algo_create ("dsig_canon#test5", dsig_test_canon_5));

  xenc_assert(!dsig_canon_algo_create ("dsig_canon#test1", dsig_test_canon_1));
  xenc_assert(!dsig_canon_algo_create ("dsig_canon#test2", dsig_test_canon_2));
  xenc_assert(!dsig_canon_algo_create ("dsig_canon#test3", dsig_test_canon_3));
  xenc_assert(!dsig_canon_algo_create ("dsig_canon#test4", dsig_test_canon_4));
  xenc_assert(!dsig_canon_algo_create ("dsig_canon#test5", dsig_test_canon_5));

  xenc_assert(dsig_canon_f_get ("dsig_canon#test1",0) ==  dsig_test_canon_1) ;
  xenc_assert(dsig_canon_f_get ("dsig_canon#test2",0) ==  dsig_test_canon_2) ;
  xenc_assert(dsig_canon_f_get ("dsig_canon#test3",0) ==  dsig_test_canon_3);
  xenc_assert(dsig_canon_f_get ("dsig_canon#test4",0) ==  dsig_test_canon_4);
  xenc_assert(dsig_canon_f_get ("dsig_canon#test5",0) ==  dsig_test_canon_5);

  /* trans */
  xenc_assert(dsig_transform_algo_create ("dsig_transform#test1", dsig_test_trans_1));
  xenc_assert(dsig_transform_algo_create ("dsig_transform#test2", dsig_test_trans_2));
  xenc_assert(dsig_transform_algo_create ("dsig_transform#test3", dsig_test_trans_3));
  xenc_assert(dsig_transform_algo_create ("dsig_transform#test4", dsig_test_trans_4));
  xenc_assert(dsig_transform_algo_create ("dsig_transform#test5", dsig_test_trans_5));

  xenc_assert(!dsig_transform_algo_create ("dsig_transform#test1", dsig_test_trans_1));
  xenc_assert(!dsig_transform_algo_create ("dsig_transform#test2", dsig_test_trans_2));
  xenc_assert(!dsig_transform_algo_create ("dsig_transform#test3", dsig_test_trans_3));
  xenc_assert(!dsig_transform_algo_create ("dsig_transform#test4", dsig_test_trans_4));
  xenc_assert(!dsig_transform_algo_create ("dsig_transform#test5", dsig_test_trans_5));

  xenc_assert(dsig_transform_f_get ("dsig_transform#test1",0) ==  dsig_test_trans_1);
  xenc_assert(dsig_transform_f_get ("dsig_transform#test2",0) ==  dsig_test_trans_2);
  xenc_assert(dsig_transform_f_get ("dsig_transform#test3",0) ==  dsig_test_trans_3);
  xenc_assert(dsig_transform_f_get ("dsig_transform#test4",0) ==  dsig_test_trans_4);
  xenc_assert(dsig_transform_f_get ("dsig_transform#test5",0) ==  dsig_test_trans_5);

  /* dsig */
  xenc_assert(dsig_sign_algo_create ("dsig_signature#test1", dsig_test_sign_1));
  xenc_assert(dsig_sign_algo_create ("dsig_signature#test2", dsig_test_sign_2));
  xenc_assert(dsig_sign_algo_create ("dsig_signature#test3", dsig_test_sign_3));
  xenc_assert(dsig_sign_algo_create ("dsig_signature#test4", dsig_test_sign_4));
  xenc_assert(dsig_sign_algo_create ("dsig_signature#test5", dsig_test_sign_5));

  xenc_assert(!dsig_sign_algo_create ("dsig_signature#test1", dsig_test_sign_1));
  xenc_assert(!dsig_sign_algo_create ("dsig_signature#test2", dsig_test_sign_2));
  xenc_assert(!dsig_sign_algo_create ("dsig_signature#test3", dsig_test_sign_3));
  xenc_assert(!dsig_sign_algo_create ("dsig_signature#test4", dsig_test_sign_4));
  xenc_assert(!dsig_sign_algo_create ("dsig_signature#test5", dsig_test_sign_5));

  xenc_assert(dsig_sign_f_get ("dsig_signature#test1",0) == dsig_test_sign_1);
  xenc_assert(dsig_sign_f_get ("dsig_signature#test2",0) == dsig_test_sign_2);
  xenc_assert(dsig_sign_f_get ("dsig_signature#test3",0) == dsig_test_sign_3);
  xenc_assert(dsig_sign_f_get ("dsig_signature#test4",0) == dsig_test_sign_4);
  xenc_assert(dsig_sign_f_get ("dsig_signature#test5",0) == dsig_test_sign_5);


  xenc_asserts_print_report (stderr);
}

static char soap_msg[] =
"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
"<S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\"\n"
"            xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"\n"
"            xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/04/secext\" \n"
"            xmlns:xenc=\"http://www.w3.org/2001/04/xmlenc#\">\n"
"   <S:Header>\n"
"      <wsse:Security>\n"
"         <xenc:EncryptedKey>\n"
"             <xenc:EncryptionMethod Algorithm=\n"
"                        \"http://www.w3.org/2001/04/xmlenc#rsa-1_5\"/>\n"
"             <ds:KeyInfo>\n"
"               <ds:KeyName>CN=Hiroshi Maruyama, C=JP</ds:KeyName>\n"
"             </ds:KeyInfo>\n"
"             <xenc:CipherData Id=\"Id-CD\">\n"
"                <xenc:CipherValue>d2FpbmdvbGRfE0lm4byV0...\n"
"                </xenc:CipherValue>\n"
"             </xenc:CipherData>\n"
"             <xenc:ReferenceList>\n"
"                 <xenc:DataReference URI=\"#enc1\"/>\n"
"             </xenc:ReferenceList>\n"
"         </xenc:EncryptedKey>\n"
"         <ds:Signature>\n"
"            <ds:SignedInfo>\n"
"               <ds:CanonicalizationMethod\n"
"                  Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/>\n"
"               <ds:SignatureMethod \n"
"               Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/>\n"
"               <ds:Reference>\n"
"                  <ds:Transforms>\n"
"                     <ds:Transform \n"
"			Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/>\n"
"                     <ds:Transform \n"
"                  Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/>\n"
"                  </ds:Transforms>\n"
"                  <ds:DigestMethod \n"
"                   Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/>\n"
"                  <ds:DigestValue>LyLsF094hPi4wPU...\n"
"                   </ds:DigestValue>\n"
"               </ds:Reference>\n"
"            </ds:SignedInfo>\n"
"            <ds:SignatureValue>\n"
"                     Hp1ZkmFZ/2kQLXDJbchm5gK...\n"
"            </ds:SignatureValue>\n"
"         </ds:Signature>\n"
"      </wsse:Security>\n"
"   </S:Header>\n"
"   <S:Body>\n"
"      <xenc:EncryptedData \n"
"                  Type=\"http://www.w3.org/2001/04/xmlenc#Element\"\n"
"                  Id=\"enc1\">\n"
"         <xenc:EncryptionMethod         \n"
"              Algorithm=\"http://www.w3.org/2001/04/xmlenc#3des-cbc\"/>\n"
"         <xenc:CipherData>\n"
"            <xenc:CipherValue>d2FpbmdvbGRfE0lm4byV0...\n"
"            </xenc:CipherValue>\n"
"         </xenc:CipherData>\n"
"      </xenc:EncryptedData>\n"
"   </S:Body>\n"
"</S:Envelope>\n";
void dsig_transform_test (query_instance_t *qi, dsig_transform_f tr, const char *tr_name,
			 const char *msg_result, caddr_t tr_data)
{
  dk_session_t * in = strses_allocate ();
  dk_session_t * out = strses_allocate ();
  char * result;

  in->dks_in_buffer = (char*) soap_msg;
  in->dks_in_fill = sizeof (soap_msg) - 1;
  in->dks_in_read = 0;

  xenc_assert ( tr (qi, in, sizeof (soap_msg) - 1, out, tr_data));

  result = strses_string (out);
  if (strcmp (result, msg_result))
    {
      char * pos = 0;
      char * prev_pos = result;
      xenc_assert (0);
      rep_printf ("%s transform failed:\n", tr_name);
      rep_printf ("***%s***\n", result);
      pos = strchr (result, '\n');
      while (pos)
	{
	  int len = pos - prev_pos;
	  int offset = prev_pos - result;

	  if (strncmp (prev_pos, msg_result + offset, len))
	    {
	      pos[0] = 0;
	      rep_printf ("near %s\n", prev_pos);
	      break;
	    }
	  prev_pos = pos + 1;
	  pos = strchr (pos + 1, '\n');
	}
      pos = result;
      while (pos[0])
	{
	  int offset = pos - result;
	  if (pos[0] != msg_result[offset])
	    rep_printf ("offset: %d\n", offset);
	  pos++;
	}
    }
  dk_free_box (result);
  strses_free (in);
  strses_free (out);
}

void
dsig_tr_enveloped_signature_test (query_instance_t * qi)
{
  dsig_transform_test (qi, dsig_tr_enveloped_signature, "Enveloped Signature",
		      "<S:Envelope xmlns:S=\"http://schemas.xmlsoap.org/soap/envelope/\""
		      " xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\""
		      " xmlns:wsse=\"http://schemas.xmlsoap.org/ws/2002/04/secext\""
		      " xmlns:xenc=\"http://www.w3.org/2001/04/xmlenc#\">\n"
		      "   <S:Header>\n"
		      "      <wsse:Security>\n"
		      "         <xenc:EncryptedKey>\n"
		      "             <xenc:EncryptionMethod Algorithm=\"http://www.w3.org/2001/04/xmlenc#rsa-1_5\"></xenc:EncryptionMethod>\n"
		      "             <ds:KeyInfo>\n"
		      "               <ds:KeyName>CN=Hiroshi Maruyama, C=JP</ds:KeyName>\n"
		      "             </ds:KeyInfo>\n"
		      "             <xenc:CipherData Id=\"Id-CD\">\n"
		      "                <xenc:CipherValue>d2FpbmdvbGRfE0lm4byV0...\n"
		      "                </xenc:CipherValue>\n"
		      "             </xenc:CipherData>\n"
		      "             <xenc:ReferenceList>\n"
		      "                 <xenc:DataReference URI=\"#enc1\"></xenc:DataReference>\n"
		      "             </xenc:ReferenceList>\n"
		      "         </xenc:EncryptedKey>\n"
		      "         \n"
		      "      </wsse:Security>\n"
		      "   </S:Header>\n"
		      "   <S:Body>\n"
		      "      <xenc:EncryptedData Type=\"http://www.w3.org/2001/04/xmlenc#Element\" Id=\"enc1\">\n"
		      "         <xenc:EncryptionMethod Algorithm=\"http://www.w3.org/2001/04/xmlenc#3des-cbc\"></xenc:EncryptionMethod>\n"
		      "         <xenc:CipherData>\n"
		      "            <xenc:CipherValue>d2FpbmdvbGRfE0lm4byV0...\n"
		      "            </xenc:CipherValue>\n"
		      "         </xenc:CipherData>\n"
		      "      </xenc:EncryptedData>\n"
		      "   </S:Body>\n"
		      "</S:Envelope>", 0);
#if 0
  dsig_transform_test (qi, dsig_tr_fake_uri, "FAKE Uri Transform",
		       "<xenc:CipherData Id=\"Id-CD\">\n"
		       "                <xenc:CipherValue>d2FpbmdvbGRfE0lm4byV0...\n"
		       "                </xenc:CipherValue>\n"
		       "             </xenc:CipherData>",
		       box_dv_short_string ("#Id-CD"));
#endif


}

void dsig_sha1_digest_test()
{
  char msg[] = "What is Hot in the World of DivX(tm) Video This Week: Sherlock Holmes, In Other News, and Skin Mania Now Sent to Over 1.7 Million DivX Fans Worldwide!";
  dk_session_t * in = strses_allocate ();
  char digest_etalon_1 [] =
    {0xf7,0xae,0xec,0x74,0x7e,0x36,0x90,0xcb,0x21,0xb9,0xa0,0xe7,0x71,0x53,0x7a,0x9c,0x16,0x45,0x28,0x20};
  char digest_etalon[sizeof (digest_etalon_1) * 2];
  /*  "967sdH42kMshuaDncVN6nBZFKCB07K73y5A2fueg8" */
  caddr_t digest;
  int len;
  len = xenc_encode_base64 (digest_etalon_1, digest_etalon, sizeof (digest_etalon_1));
  digest_etalon[len] = 0;

  in->dks_in_buffer = msg;
  in->dks_in_fill = sizeof (msg) - 1;
  in->dks_in_read = 0;

  xenc_assert (dsig_sha1_digest (in, sizeof (msg) -1, &digest));

  if (!digest ||
      strcmp (digest, digest_etalon))
    {
      xenc_assert (0);
      rep_printf ("resulting digest is     : %s\n", digest);
      rep_printf ("resulting digest must be: %s\n", digest_etalon);
    }
  dk_free_box (digest);
}

void dsig_dsa_sha1_sign_test()
{
  char msg[] = "What is Hot in the World of DivX(tm) Video This Week: Sherlock Holmes, In Other News, and Skin Mania Now Sent to Over 1.7 Million DivX Fans Worldwide!";
  dk_session_t * in = strses_allocate ();
  caddr_t digest;

  in->dks_in_buffer = msg;
  in->dks_in_fill = sizeof (msg) - 1;
  in->dks_in_read = 0;

  __xenc_key_dsa_init ("virtdev4@localhost", 1, 512);

  xenc_assert (dsig_dsa_sha1_digest (in, sizeof (msg) -1, xenc_get_key_by_name ("virtdev4@localhost", 1), &digest));

  in->dks_in_fill = sizeof (msg) - 1;
  in->dks_in_read = 0;

  xenc_assert (dsig_dsa_sha1_verify (in, sizeof (msg) -1, xenc_get_key_by_name ("virtdev4@localhost", 1), digest));

  dk_free_box (digest);
}

int __xenc_key_rsa_init (char *name);
void dsig_rsa_sha1_sign_test()
{
  char msg[] = "What is Hot in the World of DivX(tm) Video This Week: Sherlock Holmes, In Other News, and Skin Mania Now Sent to Over 1.7 Million DivX Fans Worldwide!";
  dk_session_t * in = strses_allocate ();
  caddr_t digest;

  in->dks_in_buffer = msg;
  in->dks_in_fill = sizeof (msg) - 1;
  in->dks_in_read = 0;

  __xenc_key_rsa_init ("virtdev5@localhost");

  xenc_assert (dsig_rsa_sha1_digest (in, sizeof (msg) -1, xenc_get_key_by_name ("virtdev5@localhost", 1), &digest));

  in->dks_in_fill = sizeof (msg) - 1;
  in->dks_in_read = 0;

  xenc_assert (dsig_rsa_sha1_verify (in, sizeof (msg) -1, xenc_get_key_by_name ("virtdev5@localhost", 1), digest));
  dk_free_box (digest);
}

#endif

/* P_SHA-1 Algorithm */
#define psha1_seed(ctx)   ((ctx)->A+20)
#define psha1_secret(ctx) ((ctx)->A+20+(ctx)->seed_len)

P_SHA1_CTX *
P_SHA1_init (const char *secret, int secret_len, const char *seed, int seed_len)
{
  int l = sizeof (P_SHA1_CTX) + secret_len + seed_len;
  P_SHA1_CTX *ctx = (P_SHA1_CTX *) dk_alloc (l);

  if (!ctx)
    return NULL;

  ctx->seed_len = seed_len;
  ctx->secret_len = secret_len;
  memcpy (psha1_seed (ctx), seed, seed_len);
  memcpy (psha1_secret (ctx), secret, secret_len);
  /* Compute A(1) := HMAC_SHA1(secret, seed) */
  HMAC(EVP_sha1(), secret, secret_len,
      (const unsigned char *) seed, seed_len, (unsigned char *) ctx->A, NULL);
  return ctx;
}

void
P_SHA1_block(P_SHA1_CTX *ctx, char *dst)
{
  /* Compute P_SHA1(n) := HMAC_SHA1(secret, A(n)+seed) */
  HMAC(EVP_sha1(), psha1_secret(ctx), ctx->secret_len,
      (const unsigned char *) ctx->A, sizeof(ctx->A)+ctx->seed_len,
       (unsigned char *)dst, NULL);
  /* Compute A(n+1) := HMAC_SHA1(secret, A(n)) */
  /* Note: it is allowed to pass the same memory range as input and
     output parameter to HMAC(), since it is implemented as HMAC_Update()
     (reading) followed by HMAC_Final() (writing).
     This is for OpenSSL 0.9.6 but I doubt that will change. */
  HMAC(EVP_sha1(), psha1_secret(ctx), ctx->secret_len,
      (const unsigned char *) ctx->A, sizeof(ctx->A),
      (unsigned char *) ctx->A, NULL);
}

void
P_SHA1_free(P_SHA1_CTX *ctx)
{
  int l;
  if (!ctx) return;
  l = sizeof (P_SHA1_CTX) + ctx->seed_len + ctx->secret_len;
  memset (ctx, 0, l);
  dk_free (ctx, l);
}

/* templates */

#define generate_algo_accessor(type, store_name) \
dsig_##type##_f dsig_##type##_f_get (const char * xmln, xenc_try_block_t * t) \
{ \
  dsig_##type##_algo_t ** algo;\
  if (!xmln) xmln = "[unknown]";\
  algo = (dsig_##type##_algo_t **) \
    id_hash_get (select_store( store_name )->dat_hash, (caddr_t) & xmln); \
  if (!algo) \
     xenc_report_error (t, 300 + strlen (xmln), XENC_UNKNOWN_ALGO_ERR, "Unknown algorithm %s", xmln); \
  return algo ? algo[0]->f : NULL; \
}

generate_algo_accessor (sign, "dsig")
generate_algo_accessor (verify, "verify")
generate_algo_accessor (canon, "canon")
generate_algo_accessor (canon_2, "canon_2")
generate_algo_accessor (digest, "digest")
generate_algo_accessor (transform, "trans")


void algo_stores_init ()
{
  ptrlong idx;

#ifdef DEBUG
  log_info ("algo_stores_init()");
#endif


  for (idx = 0; idx < algo_stores_len; idx++)
    {
      (algo_stores + idx)->dat_hash = id_hash_allocate (31, sizeof (char*), sizeof (xxx_algo_t), strhash, strhashcmp);
    }

#if 1
  dsig_transform_algo_create ("http://localhost#str", dsig_single_transform_algo);
  dsig_canon_algo_create (XML_CANON_EXC_ALGO, xml_canon_exc_algo);
  dsig_canon_algo_create (XML_CANON_EXC_20010315_ALGO, xml_canon_exc_algo);
  dsig_canon_2_algo_create (XML_CANON_EXC_ALGO, xml_canonicalize);
  dsig_canon_2_algo_create (XML_CANON_EXC_20010315_ALGO, xml_canonicalize);

  dsig_sign_algo_create (DSIG_DSA_SHA1_ALGO, dsig_dsa_sha1_digest);

  dsig_transform_algo_create (DSIG_ENVELOPED_SIGNATURE_ALGO, dsig_tr_enveloped_signature);
  dsig_transform_algo_create (DSIG_FAKE_URI_TRANSFORM_ALGO, dsig_tr_fake_uri);

  /* Canonicalization algorithms MUST be transforms also */
  dsig_transform_algo_create (XML_CANON_EXC_ALGO, dsig_tr_canon_exc_algo);
#endif
}

void dsig_sec_init ()
{
#ifdef DEBUG
  log_info ("dsig_sec_init()");
#endif
  dsig_digest_algo_create (DSIG_SHA1_ALGO, dsig_sha1_digest);

  dsig_sign_algo_create (DSIG_DSA_SHA1_ALGO, dsig_dsa_sha1_digest);
  dsig_sign_algo_create (DSIG_RSA_SHA1_ALGO, dsig_rsa_sha1_digest);
  dsig_sign_algo_create (DSIG_HMAC_SHA1_ALGO, dsig_hmac_sha1_digest);
  dsig_sign_algo_create ("hmac-sha1", dsig_hmac_sha1_digest); /* alias */

  dsig_verify_algo_create (DSIG_DSA_SHA1_ALGO, dsig_dsa_sha1_verify);
  dsig_verify_algo_create (DSIG_RSA_SHA1_ALGO, dsig_rsa_sha1_verify);
  dsig_verify_algo_create (DSIG_HMAC_SHA1_ALGO, dsig_hmac_sha1_verify);

#ifdef SHA256_ENABLE
  dsig_sign_algo_create (DSIG_RSA_SHA256_ALGO, dsig_rsa_sha256_digest);
  dsig_verify_algo_create (DSIG_RSA_SHA256_ALGO, dsig_rsa_sha256_verify);
  dsig_digest_algo_create (DSIG_SHA256_ALGO, dsig_sha256_digest);
  dsig_sign_algo_create (DSIG_HMAC_SHA256_ALGO, dsig_hmac_sha256_digest);
  dsig_sign_algo_create ("hmac-sha256", dsig_hmac_sha256_digest); /* alias */
  dsig_verify_algo_create (DSIG_HMAC_SHA256_ALGO, dsig_hmac_sha256_verify);
#endif

  xenc_algorithms_create (DSIG_HMAC_SHA1_ALGO, "hmac sha1 algorithm",
			  xenc_signature_wrapper,
			  xenc_signature_wrapper_1,
			  DSIG_KEY_KERBEROS);


#ifdef DEBUG
  log_info ("dsig_sec_init() end");
#endif
}




#endif /* _SSL */
