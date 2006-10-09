/*
 *  sparql_qm.c
 *
 *  $Id$
 *
 *  Quad map description language extension for SPARQL
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
 */

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlparext.h"
#include "bif_text.h"
#include "xmlparser.h"
#include "xmltree.h"
#include "numeric.h"
#include "sqlcmps.h"
#include "sparql.h"
#include "sparql2sql.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif


void
spar_qm_clean_locals (sparp_t *sparp)
{
  dk_set_t *locptr = &(sparp->sparp_env->spare_qm_locals);
  for (;;)
    {
      if (NULL == locptr[0])
        spar_internal_error (sparp, "spar_qm_clean_locals(): stack underflow");
      if (NULL == locptr[0]->data)
        break;
      locptr[0] = locptr[0]->next->next;
    }
}

void
spar_qm_push_bookmark (sparp_t *sparp)
{
  dk_set_t *locptr = &(sparp->sparp_env->spare_qm_locals);
  t_set_push (locptr, NULL);
}

void
spar_qm_pop_bookmark (sparp_t *sparp)
{
  dk_set_t *locptr = &(sparp->sparp_env->spare_qm_locals);
  for (;;)
    {
      if (NULL == locptr[0])
        spar_internal_error (sparp, "spar_qm_pop_bookmark(): stack underflow");
      if (NULL == locptr[0]->data)
        break;
      locptr[0] = locptr[0]->next->next;
    }
  locptr[0] = locptr[0]->next;
}

void
spar_qm_push_local (sparp_t *sparp, int key, SPART *value, int can_overwrite)
{
  dk_set_t *locptr = &(sparp->sparp_env->spare_qm_locals);
  SPART *old_value = spar_qm_get_local (sparp, key, 0);
  if ((!can_overwrite) && (NULL != old_value) && (old_value != value))
    spar_error (sparp, "%s: Can't redefine the '%s' property of quad mapping",
      spar_source_place (sparp, NULL), spart_dump_opname (key, 0) );
  t_set_push (locptr, value);
  t_set_push (locptr, (caddr_t)((ptrlong)key));
}

SPART *
spar_qm_get_local (sparp_t *sparp, int key, int error_if_missing)
{
  dk_set_t iter = sparp->sparp_env->spare_qm_locals;
  SPART *res = NULL;
  while (NULL != iter)
    {
      if (key == (ptrlong)(iter->data))
        {
          res = iter->next->data;
          break;
        }
      if (NULL == iter->data)
        iter = iter->next;
      else
        iter = iter->next->next;
    }
  if ((NULL == res) && error_if_missing)
    spar_error (sparp, "%s: The '%s' property is not defined",
      spar_source_place (sparp, NULL), spart_dump_opname (key, 0) );
  return res;
}

void spar_qm_pop_key (sparp_t *sparp, int key_to_pop)
{
  dk_set_t *locptr = &(sparp->sparp_env->spare_qm_locals);
  for (;;)
    {
      if (NULL == locptr[0])
        spar_internal_error (sparp, "spar_qm_pop_key(): stack underflow");
      if (NULL == locptr[0]->data)
        spar_internal_error (sparp, "spar_qm_pop_key(): no key to pop above bookmark");
      if (key_to_pop == (ptrlong)(locptr[0]->data))
        break;
      locptr[0] = locptr[0]->next->next;
    }
  locptr[0] = locptr[0]->next->next;
}

caddr_t
spar_make_iri_from_template (sparp_t *sparp, caddr_t tmpl)
{
/*!!!TBD: replace this stub with something complete */
  caddr_t cmd;
/*                     0         1         2*/
/*                     012345678901234567890*/
  cmd = strstr (tmpl, "^{URIQADefaultHost}^");
  if (NULL != cmd)
    {
      char buf[500];
      char *tail = buf;
      caddr_t subst;
      memcpy (buf, tmpl, cmd-tmpl);
      tail += cmd-tmpl;
      IN_TXN;
      subst = registry_get ("URIQADefaultHost");
      LEAVE_TXN;
      if (NULL == subst)
        spar_error (sparp, "%s: Unable to use ^{URIQADefaultHost}^ in IRI template if DefaultHost is not specified in [URIQA] section of Virtuoso config",
          spar_source_place (sparp, NULL) );
      strcpy (tail, subst);
      tail += strlen (subst);
      dk_free_box (subst);
      strcpy (tail, cmd+20);
      return t_box_dv_uname_string (buf);
    }
  return t_box_dv_uname_string (tmpl);
}

SPART *
spar_make_qm_sql (sparp_t *sparp, const char *fname, SPART **fixed, SPART **named)
{
  if (NULL != named)
    {
      int ctr, len;
      len = BOX_ELEMENTS (named);
      if (0 != (len % 2))
        spar_internal_error (sparp, "Invalid list of named parameters for quad map SQL statement: bad length");
      for (ctr = 0; ctr < len; ctr += 2)
        {
          if (DV_UNAME != DV_TYPE_OF (named [ctr]))
            spar_internal_error (sparp, "Invalid list of named parameters for quad map SQL statement: bad keyword type");
        }
    }
  if (NULL == strchr (fname, '.'))
    {
      if (NULL != named)
        spar_internal_error (sparp, "Attempt to pass a list of named parameters to BIF in quad map SQL statement");
    }
  return spartlist (sparp, 4, SPAR_QM_SQL, t_box_dv_uname_string (fname), fixed, named);
}

SPART *
spar_make_vector_qm_sql (sparp_t *sparp, SPART **fixed)
{
  return spar_make_qm_sql (sparp, "vector", fixed, NULL);
}

SPART *
spar_make_topmost_qm_sql (sparp_t *sparp)
{
  dk_set_t *acc_ptr = &(sparp->sparp_env->spare_acc_qm_sqls);
  t_set_push (acc_ptr,
    spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_APPLY_CHANGES",
      (SPART **)t_list (2,
        spar_make_vector_qm_sql (sparp, 
          (SPART **)t_revlist_to_array (sparp->sparp_env->spare_qm_deleted)),
        spar_make_vector_qm_sql (sparp, 
          (SPART **)t_revlist_to_array (sparp->sparp_env->spare_qm_affected_jso_iris)) ),
      NULL ) );
  return spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_CHANGE",
    (SPART **)t_list (1,
      spar_make_vector_qm_sql (sparp, 
        (SPART **)t_revlist_to_array (acc_ptr[0]) ) ),
    NULL );
}

SPART *
spar_qm_make_mapping_impl (sparp_t *sparp, int is_real, caddr_t qm_id, caddr_t options)
{
  caddr_t storage_name = sparp->sparp_env->spare_storage_name;
  caddr_t raw_id = (caddr_t) spar_qm_get_local (sparp, CREATE_L, 0);
  SPART * parent_id = spar_qm_get_local (sparp, _LBRA, 0);
  SPART * graph = spar_qm_get_local (sparp, GRAPH_L, is_real);
  SPART * subject = spar_qm_get_local (sparp, SUBJECT_L, is_real);
  SPART * predicate = spar_qm_get_local (sparp, PREDICATE_L, is_real);
  SPART * object = spar_qm_get_local (sparp, OBJECT_L, is_real);
  SPART * where_cond = spar_qm_get_local (sparp, WHERE_L, 0);
  SPART * exclusive = (SPART *)get_keyword_int ((caddr_t *)options, t_box_dv_uname_string ("EXCLUSIVE"), "(SPARQL compiler)");
  SPART * order = (SPART *)get_keyword_int ((caddr_t *)options, t_box_dv_uname_string ("ORDER"), "(SPARQL compiler)");
  if (NULL != qm_id)
    {
      if ((NULL != raw_id) && strcmp (qm_id, raw_id))
        spar_error (sparp, "The declaration of quad mapping contains two identifiers for the mapping: CREATE <id1> AS ... AS <id2>");
      raw_id = qm_id;
    }
  if (NULL == raw_id)
    {
      caddr_t key = (caddr_t)t_list (9,
        storage_name, raw_id, parent_id,
#if 0
        ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (graph)) ? graph[0] : graph),
        ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (subject)) ? subject[0] : subject),
        ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (predicate)) ? predicate[0] : predicate),
        ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (object)) ? object[0] : object),
#else
        graph, subject, predicate, object,
#endif
        /* no where_cond -- intentionally */ exclusive, order );
      caddr_t md5 = box_md5 (key);
      int i, md5len = box_length (md5) - 1;
      caddr_t md5enc = t_alloc_box ((2 * md5len) + 1, DV_STRING);
      for (i = 0; i < md5len; i++)
        {
          md5enc [i*2] = "0123456789abcdef"[((unsigned char *)(md5))[i] >> 4];
          md5enc [i*2+1] = "0123456789abcdef"[((unsigned char *)(md5))[i] & 0xf];
        }
      md5enc [md5len * 2] = '\0';
      qm_id = t_box_sprintf (50, "sys:qm-%s", md5enc);
      spar_qm_push_local (sparp, CREATE_L, (SPART *)qm_id, 1);
    }
  else
    qm_id = raw_id;
  if ((NULL != where_cond) && (!is_real))
    spar_internal_error (sparp, "spar_qm_make_mapping_impl(): where cond in empty qm");
  return spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_DEFINE_MAPPING",
      (SPART **)t_list (10, 
	storage_name	, raw_id	, qm_id		, parent_id	,
	graph		, subject	, predicate	, object	,
	box_num_nonull (is_real), where_cond ),
      (SPART **)options );
}

SPART *
spar_qm_make_empty_mapping (sparp_t *sparp, caddr_t qm_id, caddr_t options)
{
  return spar_qm_make_mapping_impl (sparp, 0, qm_id, options);
}

SPART *spar_qm_make_real_mapping (sparp_t *sparp, caddr_t qm_id, caddr_t options)
{
  return spar_qm_make_mapping_impl (sparp, 1, qm_id, options);
}
