/*
 *  xmlparser.c
 *
 *  $Id$
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

#include "xmlparser_impl.h"

#ifdef UNIT_DEBUG
#define xml_dbg_printf(a) printf a
#else
#define xml_dbg_printf(a)
#endif

typedef const char *xmlns_string_pair_t[2];

xmlns_string_pair_t xmlns_sys[] =
{
    {"sql",	MSSQL_NS_URI},
    {"xml",	XML_NS_URI},
    {"xs",	XMLSCHEMA_NS_URI}
};

const int xmlns_sys_no = (sizeof(xmlns_sys)/sizeof(xmlns_sys[0]));

encoding_handler_t *
find_encoding (vxml_parser_t *parser, char * enc_name)
{
  encoding_handler_t *eh = NULL;

  if (enc_name == NULL)
    goto end;

  if (parser->cfg.input_is_wide)
    {
      char wide_name[BUFSIZEOF__ENCODING_ID];
      strcpy (wide_name, "WIDE ");
      strncpy (wide_name+5, enc_name, BUFSIZEOF__ENCODING_ID-5);
      wide_name[BUFSIZEOF__ENCODING_ID-1] = '\0';
      eh = eh_get_handler ((char *)wide_name);
      if (NULL != eh)
	goto end;
      eh = eh_get_handler ((char *)enc_name);
      if (NULL != eh)
	return eh_wide_from_narrow (eh);
      if (parser->cfg.user_encoding_handler)
        {
	  eh = parser->cfg.user_encoding_handler (enc_name, 1);
          if (NULL != eh)
            goto end;
	  eh = parser->cfg.user_encoding_handler (enc_name, 0);
          if (NULL != eh)
	    return eh_wide_from_narrow (eh);
	}
    }
  else
    {
      eh = eh_get_handler ((char *)enc_name);
      if (NULL != eh)
	goto end;
     if (parser->cfg.user_encoding_handler)
       eh = parser->cfg.user_encoding_handler (enc_name, 0);
    }
end:
  return eh;
}


int xml_ns_2dict_add (xml_ns_2dict_t *xn2, nsdecl_t *ns)
{
  caddr_t prefix, uri;
  ptrlong prefix_idx, uri_idx;
  ptrlong size = xn2->xn2_size;
  prefix_idx = ecm_find_name (ns->nsd_prefix, xn2->xn2_prefix2uri, size, sizeof (xml_name_assoc_t));
  if (ECM_MEM_NOT_FOUND != prefix_idx)
    {
      if (strcmp (xn2->xn2_prefix2uri[prefix_idx].xna_value, ns->nsd_uri))
        return 0;
      return 1;
    }
  uri_idx = ecm_find_name (ns->nsd_uri, xn2->xn2_uri2prefix, size, sizeof (xml_name_assoc_t));
  if (ECM_MEM_NOT_FOUND != uri_idx)
    return 0; /* No strcmp here, case of duplicate definition is already checked above */
  prefix = box_copy (ns->nsd_prefix);
  uri = box_copy (ns->nsd_uri);
  prefix_idx = ecm_add_name (prefix, (void **)(&(xn2->xn2_prefix2uri)), &size, sizeof (xml_name_assoc_t));
  size--;
  uri_idx = ecm_add_name (uri, (void **)(&(xn2->xn2_uri2prefix)), &size, sizeof (xml_name_assoc_t));
  xn2->xn2_size = size;
  xn2->xn2_prefix2uri[prefix_idx].xna_key = xn2->xn2_uri2prefix[uri_idx].xna_value = prefix;
  xn2->xn2_uri2prefix[uri_idx].xna_key = xn2->xn2_prefix2uri[prefix_idx].xna_value = uri;
  return 1;
}

int
xml_ns_2dict_del (xml_ns_2dict_t *xn2, caddr_t pref)
{
  ptrlong prefix_idx, uri_idx;
  caddr_t old_prefix;
  caddr_t old_uri;
  prefix_idx = ecm_find_name (pref, xn2->xn2_prefix2uri, xn2->xn2_size, sizeof (xml_name_assoc_t));
  if (ECM_MEM_NOT_FOUND == prefix_idx)
    return 0;
  old_prefix = xn2->xn2_prefix2uri[prefix_idx].xna_key;
  old_uri = xn2->xn2_prefix2uri[prefix_idx].xna_value;
  uri_idx = ecm_find_name (old_uri, xn2->xn2_uri2prefix, xn2->xn2_size, sizeof (xml_name_assoc_t));
  if (ECM_MEM_NOT_FOUND == uri_idx)
    GPF_T;
  if (old_prefix != xn2->xn2_uri2prefix[uri_idx].xna_value)
    GPF_T;
  if (old_uri != xn2->xn2_uri2prefix[uri_idx].xna_key)
    GPF_T;
  ecm_delete_nth (prefix_idx, xn2->xn2_prefix2uri, &(xn2->xn2_size), sizeof (xml_name_assoc_t));
  xn2->xn2_size++;
  ecm_delete_nth (uri_idx, xn2->xn2_uri2prefix, &(xn2->xn2_size), sizeof (xml_name_assoc_t));
  dk_free_box (old_prefix);
  dk_free_box (old_uri);
  return 1;
}

int xml_ns_2dict_extend (xml_ns_2dict_t *dest, xml_ns_2dict_t *src)
{
  int res = 1;
  long src_idx;
  ptrlong src_count = src->xn2_size;
  if (0 == src_count)
    return res;
  for (src_idx = 0; src_idx < src_count; src_idx++)
    {
      xml_name_assoc_t *xna = src->xn2_prefix2uri + src_idx;
      caddr_t prefix = xna->xna_key;
      caddr_t uri = xna->xna_value;
      ptrlong prefix_idx, uri_idx;
      ptrlong size = dest->xn2_size;
      if ('\0' == prefix[0])
        continue;
      prefix_idx = ecm_find_name (prefix, dest->xn2_prefix2uri, size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != prefix_idx)
        {
	  if (strcmp (dest->xn2_prefix2uri[prefix_idx].xna_value, uri))
            res = 0;
          continue;
        }
      uri_idx = ecm_find_name (uri, dest->xn2_uri2prefix, size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != uri_idx)
        {
          res = 0; /* No strcmp here, case of duplicate definition is already checked above */
	  continue;
	}
      prefix_idx = ecm_add_name (prefix, (void **)(&(dest->xn2_prefix2uri)), &size, sizeof (xml_name_assoc_t));
      size--;
      uri_idx = ecm_add_name (uri, (void **)(&(dest->xn2_uri2prefix)), &size, sizeof (xml_name_assoc_t));
      dest->xn2_size = size;
      dest->xn2_prefix2uri[prefix_idx].xna_key = dest->xn2_uri2prefix[uri_idx].xna_value = box_copy (prefix);
      dest->xn2_uri2prefix[uri_idx].xna_key = dest->xn2_prefix2uri[prefix_idx].xna_value = box_copy (uri);
    }
  return res;
}


vxml_parser_t *
VXmlParserCreate (vxml_parser_config_t *config)
{
  brick_t *buf;
  NEW_VARZ(vxml_parser_t, parser);
  xml_dbg_printf(("{XML Parser on '%s' ", (config->uri ? config->uri : "NULL URI")));
  memcpy (&(parser->cfg), config, sizeof (vxml_parser_config_t));
  if (NULL != parser->cfg.initial_src_enc_name)
    {
      if ('!' == parser->cfg.initial_src_enc_name[0])
        {
          parser->enc_flag = XML_EF_FORCE;
          parser->cfg.initial_src_enc_name += 1;
        }
      parser->src_eh = find_encoding (parser, (char *)(parser->cfg.initial_src_enc_name));
      parser->src_eh_state = 0; /* reset of encoding state on encoding change */
      if (parser->src_eh == NULL)
	xmlparser_logprintf (parser, XCFG_ERROR, 300, "The specified name '%.100s' of the default encoding of the XML source text is not supported", parser->cfg.initial_src_enc_name);
    }
  parser->feed_buf_size = config->feed_buf_size;
  parser->state = XML_ST_INITIAL;
  if (config->input_is_ge & GE_XML)
    parser->state |= XML_A_CHAR | XML_A_MISC;

  buf = dk_alloc (sizeof(brick_t));
  buf->beg = buf->data_begin = dk_alloc (BRICK_SIZE);
  buf->end = buf->beg + BRICK_SIZE;
  buf->data_owner = NULL;
  buf->data_refctr = 0;
  buf->prev = NULL;
  buf->next = NULL;

  parser->bptr.buf = parser->eptr.buf = parser->pptr.buf = buf;
  parser->bptr.ptr = parser->eptr.ptr = parser->pptr.ptr = buf->beg;

  parser->attrdata.all_nsdecls = parser->nsdecl_array;
  parser->attrdata.local_attrs = parser->tmp.attr_array;

  parser->curr_pos.line_num = parser->curr_pos.col_b_num = parser->curr_pos.col_c_num = 1;
  parser->curr_pos.origin_uri = config->uri;
  parser->last_main_pos.line_num = parser->last_main_pos.col_b_num = parser->last_main_pos.col_c_num = 1;
  parser->last_main_pos.origin_uri = config->uri;
  parser->curr_pos_ptr.buf = parser->pptr.buf;
  parser->curr_pos_ptr.ptr = parser->pptr.ptr;

  parser->includes = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t),
	strhash, strhashcmp);
  parser->ids = id_hash_allocate (251, sizeof (caddr_t), sizeof (caddr_t),
	strhash, strhashcmp);

  parser->validator.dv_dtd = dtd_alloc();
  dtd_addref (parser->validator.dv_dtd, 0);

  if (!xmlparser_configure (parser, parser->cfg.dtd_config, config))
    parser->cfg.dtd_config = NULL;

  switch (config->validation_mode)
    {
    case XML_DTD:
      VXmlSetElementHandler (parser, NULL, NULL);
      VXmlSetCharacterDataHandler (parser, NULL); /* Set char data handler to stub */
      break;
    case XML_SCHEMA:
      parser->processor.sp_schema = xs_alloc_schema();
      VXmlSetElementSchemaHandler (parser, NULL, NULL);
      VXmlSetCharacterSchemaDataHandler (parser, NULL);
      memcpy (&(parser->processor.sp_schema->sp_curr_config), &(parser->validator.dv_curr_config),
	  sizeof(dtd_config_t));
      break;
    default:
      GPF_T;
    }
  VXmlSetIdHandler (parser, (VXmlIdHandler)NULL);
  VXmlSetEntityRefHandler (parser, NULL);
  VXmlSetProcessingInstructionHandler (parser, NULL);
  VXmlSetCommentHandler (parser, NULL);

/*  VXmlSetDtdHandler (parser, NULL); */
  xml_pos_set (&(parser->bptr.buf->beg_pos), &(parser->last_main_pos));
  parser->inner_tag = parser->tag_stack_holder;
  return parser;
}

void
VXmlParserDestroy (vxml_parser_t * parser)
{
  id_hash_iterator_t dict_hit;		/*!< Iterator to zap dictionary */
  char **dict_key;			/*!< Current key to zap */
  lenmem_t **dict_include;		/*!< Current inclusion text to zap */
  ecm_id_t **id_ptr;
/* The following 'if' is for case when ParserDestroy is inside QR_RESET_CODE...END_QR_RESET and
  ParserCreate signals an error due to, e.g., bad encoding name */
  if (NULL == parser)
    return;
  validate_parser_bricks(parser);
  while (NULL != parser->eptr.buf)
    {
      brick_t *old = parser->eptr.buf;
      parser->eptr.buf = old->prev;
      if (NULL != old->data_begin)
	dk_free (old->data_begin, -1);
#ifdef UNIT_DEBUG
      printf ("Releasing a buffer element. %x\n", old);
#endif
      dk_free (old, sizeof (brick_t));
    }

  if (parser->feed_buf)
    dk_free (parser->feed_buf, -1);
  if (parser->uni_buf)
    dk_free (parser->uni_buf, -1);

  if (NULL != parser->tmp.flat_name.lm_memblock)
    dk_free (parser->tmp.flat_name.lm_memblock, -1);

  while (pop_tag(parser)) {}

  free_attr_array (parser);

/* parser->includes should be erased after params, to prevent access to freed data */
  for( id_hash_iterator(&dict_hit,parser->includes);
    hit_next (&dict_hit, (char **)(&dict_key), (char **)(&dict_include));
    /*no step*/ )
  {
    dk_free_box (dict_include[0]->lm_memblock);
    dk_free_box (dict_include[0]);
    dk_free_box (dict_key[0]);
  }
  id_hash_free (parser->includes);

  for( id_hash_iterator(&dict_hit,parser->ids);
    hit_next (&dict_hit, (char **)(&dict_key), (char **)(&id_ptr));
    /*no step*/ )
  {
    ecm_id_t* id = *id_ptr;
    if (!id->id_defined)
      { /* it is possible to create full logging, but now only first reference is reported */
	ecm_refid_logitem_t* refid = (ecm_refid_logitem_t*) basket_get (&id->id_log);
	if (refid)
	  dk_free (refid, sizeof (ecm_refid_logitem_t));
	free_refid_log (&id->id_log);
      };
    dk_free_box(*dict_key);
    dk_free (*id_ptr, sizeof (ecm_id_t));
  }
  id_hash_free(parser->ids);

  if (parser->tmp.dtd_puburi)
      dk_free_box(parser->tmp.dtd_puburi);
  if (parser->tmp.dtd_sysuri)
      dk_free_box(parser->tmp.dtd_sysuri);

  if (NULL != parser->validator.dv_root)
    dk_free (parser->validator.dv_root, -1);
  dtd_release(parser->validator.dv_dtd);

#if 0
  if (parser->tmp.tag_index)
    {
      long l = box_length (parser->tmp.tag_index);
      ptrlong *p = parser->tmp.tag_index;
      while (l)
	{
	  if (*p)
	    xs_clear_tag (*p, 1);
	  p++;
	  l-=sizeof (ptrlong);
	}
      dk_free_box (parser->tmp.tag_index);
    }
#endif
  xml_ns_2dict_clean (&(parser->ns_2dict));
  while (NULL != parser->msglog)
    dk_free_box (dk_set_pop (&(parser->msglog)));
  xs_clear_processor (&parser->processor);
  dk_free (parser, -1);
  xml_dbg_printf(("}\n"));

}

void
VXmlParserInput (vxml_parser_t * parser, xml_read_func_t f, void * read_cd)
{
  parser->feeder = f;
  parser->read_cd = read_cd;
}

void
VXmlSetUserData (vxml_parser_t * parser, void * ptr)
{
  INNER_HANDLERS->user_data = parser;
  OUTER_HANDLERS->user_data = ptr;
}

void
VXmlSetElementHandler (vxml_parser_t * parser,
		       VXmlStartElementHandler sh,
		       VXmlEndElementHandler eh)
{
  INNER_HANDLERS->start_element_handler = (VXmlStartElementHandler)dtd_start_element_handler;
  INNER_HANDLERS->end_element_handler = (VXmlEndElementHandler)dtd_end_element_handler;
  OUTER_HANDLERS->start_element_handler = sh;
  OUTER_HANDLERS->end_element_handler = eh;
}

void
VXmlSetIdHandler (vxml_parser_t * parser,
		       VXmlIdHandler h)
{
/* There's no inner handler for IDs */
  /* INNER_HANDLERS->id_handler = ...; */
  OUTER_HANDLERS->id_handler = h;
}

void
VXmlSetCommentHandler (vxml_parser_t * parser,
		       VXmlCommentHandler h)
{
  INNER_HANDLERS->comment_handler = (VXmlCommentHandler)dtd_comment_handler;
  OUTER_HANDLERS->comment_handler = h;
}

void
VXmlSetProcessingInstructionHandler (vxml_parser_t * parser,
		       VXmlProcessingInstructionHandler h)
{
  INNER_HANDLERS->pi_handler = (VXmlProcessingInstructionHandler)dtd_pi_handler;
  OUTER_HANDLERS->pi_handler = h;
}

static void
Null_XML_CharacterDataHandler(void * userData, const char * s, size_t len)
{
}


void
VXmlSetCharacterDataHandler (vxml_parser_t * parser,
			     VXmlCharacterDataHandler h)
{
  if (NULL==h)
    h = Null_XML_CharacterDataHandler;
  INNER_HANDLERS->char_data_handler = (VXmlCharacterDataHandler)dtd_char_data_handler;
  OUTER_HANDLERS->char_data_handler = h;
}


void
VXmlSetEntityRefHandler (vxml_parser_t * parser,
    VXmlEntityRefHandler h)
{
  INNER_HANDLERS->entity_ref_handler = (VXmlEntityRefHandler)dtd_entity_ref_handler;
  OUTER_HANDLERS->entity_ref_handler = h;
}


/*
void
VXmlSetDtdHandler (vxml_parser_t * parser,
		       VXmlDtdHandler h)
{
  INNER_HANDLERS->dtd_handler = (VXmlDtdHandler)dtd_dtd_handler;
  OUTER_HANDLERS->dtd_handler = h;
}
*/
void
VXmlSetFindUserEncoding (vxml_parser_t * parser, VXmlFindUserEncoding find)
{
  parser->cfg.user_encoding_handler = find;
}


int
initialize_src_eh (vxml_parser_t * parser)
{
  char *raw_text, *raw_text_end;
  int skip = 0;
  encoding_handler_t *saved_eh;
  int saved_eh_state;

  if (parser->cfg.input_is_wide)
    {
      if (parser->src_eh)
        return 1;			/* already initialized */
      parser->src_eh = &eh__WIDE_121;	/* No detection for other wide encodings, anyway :) */
      parser->src_eh_state = 0; /* reset of encoding state on encoding change */
      return 1;
    }

/* First of all, the parser should try to read BOM at least to skip any explicit BOM and prevent it from passing to the rest of parser */
  saved_eh = parser->src_eh;
  saved_eh_state = parser->src_eh_state;
  parser->src_eh = &eh__ISO8859_1;
  parser->src_eh_state = 0; /* reset of encoding state on encoding change */
  if (NULL == parser->feeder)
    {
      raw_text = parser->static_src_tail;
      raw_text_end = parser->static_src_end;
    }
  else
    {
      buf_ptr_t tmp = parser->pptr;
      get_one_xml_char (parser);
      parser->pptr = tmp;
      parser->feed_tail = parser->feed_buf;
      raw_text = parser->feed_buf;
      raw_text_end = parser->feed_end;
    }
  memset (&(parser->bom), 0, sizeof (parser->bom));
  do {
    if (raw_text_end < (raw_text+4))			  /* No room for BOMs */
      break;
    /* explicit BOMs */
    if (!memcmp (raw_text, "\x00\x00\xFE\xFF", 4))        /* UCS-4, big-endian machine (1234 order) */
      { parser->bom.byteorder = 0x1234; parser->bom.ucs4 = 'Y'; skip=parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\xFF\xFE\x00\x00", 4))        /* UCS-4, little-endian machine (4321 order) */
      { parser->bom.byteorder = 0x4321; parser->bom.ucs4 = 'Y'; skip=parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\x00\x00\xFF\xFE", 4))        /* UCS-4, UCS-4, unusual octet order (2143) */
      { parser->bom.byteorder = 0x2143; parser->bom.ucs4 = 'Y'; skip=parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\xFE\xFF\x00\x00", 4))        /* UCS-4, unusual octet order (3412) */
      { parser->bom.byteorder = 0x3412; parser->bom.ucs4 = 'Y'; skip=parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\xFE\xFF", 2))                /* UTF-16, big-endian */
      { parser->bom.byteorder = 0x1234; parser->bom.utf16 = 'Y'; skip=parser->bom.code_length=2; break; }
    if (!memcmp (raw_text, "\xFF\xFE", 2))                /* UTF-16, little-endian */
      { parser->bom.byteorder = 0x4321; parser->bom.utf16 = 'Y'; skip=parser->bom.code_length=2; break; }
    if (!memcmp (raw_text, "\xEF\xBB\xBF", 3))                /* UTF-8 */
      { parser->bom.utf8 = 'Y'; skip=parser->bom.code_length=3; break; }
    /* implicit BOMs */
    if (!memcmp (raw_text, "\x00\x00\x00\x3C", 4))        /* UCS-4, big-endian machine (1234 order) */
      { parser->bom.byteorder = 0x1234; parser->bom.ucs4 = 'y'; parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\x3C\x00\x00\x00", 4))        /* UCS-4, little-endian machine (4321 order) */
      { parser->bom.byteorder = 0x4321; parser->bom.ucs4 = 'y'; parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\x00\x00\x3C\x00", 4))        /* UCS-4, UCS-4, unusual octet order (2143) */
      { parser->bom.byteorder = 0x2143; parser->bom.ucs4 = 'y'; parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\x00\x3C\x00\x00", 4))        /* UCS-4, unusual octet order (3412) */
      { parser->bom.byteorder = 0x3412; parser->bom.ucs4 = 'y'; parser->bom.code_length=4; break; }
    if (!memcmp (raw_text, "\x00\x3C\x00\x3F", 4))        /* UTF-16, big-endian */
      { parser->bom.byteorder = 0x1234; parser->bom.utf16 = 'y'; parser->bom.code_length=2; break; }
    if (!memcmp (raw_text, "\x3C\x00\x3F\x00", 4))        /* UTF-16, little-endian */
      { parser->bom.byteorder = 0x4321; parser->bom.utf16 = 'Y'; parser->bom.code_length=2; break; }
    if (!memcmp (raw_text, "\x3C\x3F\x78\x6D", 4))        /* UTF-8, ASCII, ISO-8859-x etc. */
      { parser->bom.utf8 = 'y'; parser->bom.code_length=1; break; }
    if (!memcmp (raw_text, "\x4C\x6F\xA7\x94", 4))        /* some sort of EBCDIC */
      { parser->bom.ebcdic = 'Y'; parser->bom.code_length=1; break; }
    } while (0);
  if (skip)
    {
      parser->bom.exact_mark = 'Y';
      while (skip-- > 0) get_one_xml_char (parser);
    }
/* Now the BOM is skipped and it is possible to either exit with saved eh or go set encoding */
  if (saved_eh)
    {
      parser->src_eh = saved_eh;
      parser->src_eh_state = saved_eh_state;
      return 1;			/* already initialized */
    }
  do {
    if (parser->bom.utf16)
      {
        parser->src_eh = ((0x1234 == parser->bom.byteorder) ? &eh__UTF16BE : &eh__UTF16LE);
        break;
      }
    if (parser->bom.ucs4)
      {
        switch (parser->bom.byteorder)
          {
          case 0x1234: parser->src_eh = &eh__UCS4BE; break;
          case 0x4321: parser->src_eh = &eh__UCS4LE; break;
          default:
            xmlparser_logprintf (parser, XCFG_ERROR, 100, "Encoding error: UCS-4 data found, but the specified byteorder is not supported by the XML parser.");
            return 0;
          }
        break;
      }
    if ('Y' == parser->bom.utf8)
      {
        parser->src_eh = &eh__UTF8;
        break;
      }
    if (parser->bom.ebcdic)
      {
        xmlparser_logprintf (parser, XCFG_ERROR, 100, "Encoding error: EBCDIC data found, but EBCDIC is not supported by the XML parser.");
        return 0;
      }
    } while (0);
  if ((0 == parser->bom.code_length) || ('y' == parser->bom.utf8)) /* No marks or an ambiguity UTF-8 vs LATIN-1. */
    parser->src_eh = (parser->cfg.input_is_html ? &eh__ISO8859_1 : &eh__UTF8_QR);
  parser->src_eh_state = 0; /* reset of encoding state on encoding change */
  return 1;
}


int xml_tok_states [5][5] =
  {
    /* initial state */	{ 1, 2, 3, 4, 5 },
    /* after PI */	{ -1,2, 3, 4, 5 },
    /* after commments*/{ -1,2, 3, 4, 5 },
    /* after DTD */	{ 3, 3,-1, 4, 5 },
    /* after start tag*/{ -1,-1,-1,-1,5 }
  };

static int xml_tok_stat (xml_tok_type_t tok)
{
  switch (tok)
    {
    case XML_TOK_START_TAG:
      return 3;
    case XML_TOK_END_TAG:
    case XML_TOK_EMPTY_TAG:
      return 4;
    case XML_TOK_COMMENT:
      return 1;
    case XML_TOK_PI:
      return 0;
    case XML_TOK_DTD:
      return 2;
    default:
      return -1;
    }
}


int
VXmlParse (vxml_parser_t * parser, char * data, s_size_t data_size)
{
  xml_tok_type_t tok = XML_TOK_INVALID;
  int curr_st = 0;
  int depth = 1;
  int first_elem = 1;
  xml_pos_set (&(parser->bptr.buf->beg_pos), &(parser->last_main_pos));
  parser->static_src_tail = parser->static_src = data;
  parser->static_src_end = data + data_size;
  parser->input_weight = data_size / 16;
  parser->input_cost = 1000 + data_size / 16;

  if (parser->feeder != NULL)
    {
      if (0 == parser->feed_buf_size)
        parser->feed_buf_size = 0x2000;
      parser->feed_tail = parser->feed_end = parser->feed_buf = dk_alloc (parser->feed_buf_size);
    }
  else
    { /* parser->feed_buf_size is needed even if (NULL == parser->feeder) befause it is used in calculating the size of parser->uni_buf */
      if (0 == parser->feed_buf_size)
        parser->feed_buf_size = MIN (data_size + 2, 0x2000);
    }
  parser->uni_tail = parser->uni_end = parser->uni_buf = dk_alloc (6 * (BRICK_SIZE + parser->feed_buf_size));

  if (!initialize_src_eh (parser))
    return 0;

  if (XCFG_ENABLE == parser->validator.dv_curr_config.dc_xs_decl)
    VXmlAddSchemaDeclarationCallbacks (parser);

  for (;;)
    {
      if ((0 != parser->msglog_ctrs[XCFG_FATAL]) && (DEAD_HTML != parser->cfg.input_is_html))
	break;
      tok = get_token (parser);
      if (tok <= XML_TOK_ERROR)
	break;
      if ((0 != parser->msglog_ctrs[XCFG_FATAL]) && (DEAD_HTML != parser->cfg.input_is_html))
	break;
      advance_ptr (parser);
      /* rus 23/10/02 SGMLism - very first token must be xml pi */
      if ((XCFG_DISABLE != parser->validator.dv_curr_config.dc_sgml) && first_elem)
	{
	  first_elem = 0;
	  /* we could not distinct XML PI and other PI yet */
	  if (tok != XML_TOK_PI)
	    {
	      xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_sgml, 300,
			     "XML PI instruction must be very first token for SGML compatibility" );
	    }
	}
      if (tok == XML_TOK_END_TAG)
	depth--;
      if (!depth)
	{
	  int tok_st = xml_tok_stat (tok);
	  if (tok_st != -1)
	    {
	      if (curr_st == 5)
		{
		error1:
		  xmlparser_logprintf (parser, XCFG_FATAL, 1024, "Generic fatal error; XML parser can't continue due to previous error(s)");
		  return 0;
		}
	      curr_st = xml_tok_states [curr_st][tok_st];
	      if (curr_st == -1)
		goto error1;
	    }
	}
      if (tok == XML_TOK_START_TAG)
	depth++;
    }
  validate_parser_bricks(parser);
  if (tok != XML_TOK_FINISH)
    {
      if (DEAD_HTML != parser->cfg.input_is_html)
        return 0;
    }

  while (parser->inner_tag != parser->tag_stack_holder)
    {
      opened_tag_t * tag = parser->inner_tag;
      if ((DEAD_HTML != parser->cfg.input_is_html) &&
	((NULL == tag->ot_descr) || !tag->ot_descr->htmltd_is_closing_optional) )
	{
	  char *expected = tag->ot_name.lm_memblock;
	  xmlparser_logprintf (parser, XCFG_FATAL, 200 + strlen (expected),
	            "End of source text reached but no closing tag has been found for tag '%s' at line %d column %d",
	            expected, tag->ot_pos.line_num, tag->ot_pos.col_c_num );
	  
	  return 0;
	}
      if (parser->masters.end_element_handler)
	parser->masters.end_element_handler (parser->masters.user_data, (char *)tag->ot_name.lm_memblock);
      pop_tag (parser);
    }

  if (!parser->cfg.input_is_html && !parser->cfg.input_is_ge && !(parser->state & XML_ST_NOT_EMPTY))
    {
      xmlparser_logprintf (parser, XCFG_FATAL, 100, "End of source text reached but no root element found");
      return 0;
    }
  return 1;
}


caddr_t xmlparser_log_place_context (struct vxml_parser_s *parser)
{
  buf_ptr_t pptr_save, curr_pos_ptr_save;
  xml_pos_t curr_pos_save, last_main_pos_save;
  int ctr;
#ifdef DEBUG
  if (0 > parser->curr_pos.line_num)
    GPF_T;
#endif
  validate_parser_bricks(parser);
  pptr_save = parser->pptr;
  curr_pos_ptr_save = parser->curr_pos_ptr;
  xml_pos_set (&curr_pos_save, &(parser->curr_pos));
  xml_pos_set (&last_main_pos_save, &(parser->last_main_pos));
  for(ctr = 0; ctr < MAX_CONTEXT_ALL; ctr++)
    {
      unichar c;
      c = get_tok_char (parser);
      if (c <= 0)
        break;
    }
  parser->pptr = pptr_save;
  parser->curr_pos_ptr = curr_pos_ptr_save;
  xml_pos_set (&(parser->curr_pos), &curr_pos_save);
  xml_pos_set (&(parser->last_main_pos), &last_main_pos_save);
  return VXmlErrorContext(parser);
}

int xmlparser_log_place (struct vxml_parser_s *parser)
{
  const char *src;
  int res = 0;
  src = parser->curr_pos.origin_uri;
  if (NULL == src)
    src = parser->cfg.uri;
  if (0 < parser->curr_pos.line_num)
    {
      if ((NULL != src) && ('\0' != src[0]))
        res = xmlparser_logprintf (parser, XCFG_DETAILS, 100+strlen(src), "at line %d column %d of '%s'",
          parser->curr_pos.line_num, parser->curr_pos.col_c_num, src );
      else
        res = xmlparser_logprintf (parser, XCFG_DETAILS, 100+strlen(src), "at line %d column %d of source text",
          parser->curr_pos.line_num, parser->curr_pos.col_c_num);
    }
  else
    if ((NULL != src) && ('\0' != src[0]))
      res = xmlparser_logprintf (parser, XCFG_DETAILS, 100+strlen(src), "in '%s'", src );
  if ((0 <= parser->curr_pos.line_num) && (XCFG_ENABLE == parser->validator.dv_curr_config.dc_error_context))
    {
      caddr_t ctx = xmlparser_log_place_context (parser);
      res = res && xmlparser_logprintf (parser, XCFG_DETAILS, box_length (ctx), "%s", ctx);
      dk_free_box (ctx);
    }
  return res;
}

/*
void
VXmlParsePosition (vxml_parser_t * parser, size_t * start_pos, size_t * end_pos)
{
  *start_pos = parser->e_pos.start;
  *end_pos = parser->e_pos.end;
}
*/

int
VXmlGetCurrentLineNumber (vxml_parser_t * parser)
{
  return parser->curr_pos.line_num;
}

int
VXmlGetOuterLineNumber (vxml_parser_t * parser)
{
  if (parser->eptr.buf != parser->pptr.buf)
    return parser->pptr.buf->next->beg_pos.line_num;
  return parser->curr_pos.line_num;
}

int
VXmlGetCurrentColumnNumber (vxml_parser_t * parser)
{
  return parser->curr_pos.col_c_num;
}

int
VXmlGetCurrentByteNumber (vxml_parser_t * parser)
{
  return parser->curr_pos.col_b_num;
}

const char *
VXmlGetCurrentFileName (vxml_parser_t * parser)
{
  const char *res = parser->curr_pos.origin_uri;
  if (NULL != res)
    return res;
  res = parser->cfg.uri;
  if (NULL != res)
    return res;
  return "(unknown origin)";
}


const char *
VXmlGetOuterFileName (vxml_parser_t * parser)
{
  const char *res;
  if (parser->eptr.buf != parser->pptr.buf)
    res = parser->pptr.buf->next->beg_pos.origin_uri;
  else
    res = parser->curr_pos.origin_uri;
  if (NULL != res)
    return res;
  res = parser->cfg.uri;
  if (NULL != res)
    return res;
  return "(unknown origin)";
}


static char relative_char(vxml_parser_t * parser, buf_ptr_t pos, int offset)
{
  char res;
  while (offset >= (int)(pos.buf->end-pos.ptr))
    {
      if(parser->eptr.buf == pos.buf)
	return 0;
      offset -= (int)(pos.buf->end-pos.ptr);
      pos.buf = pos.buf->next;
      pos.ptr = pos.buf->beg;
    }
  while (offset < (int)(pos.buf->beg-pos.ptr))
    {
      if(parser->bptr.buf == pos.buf)
	return 0;
      offset -= (int)(pos.buf->beg-pos.ptr);
      pos.buf = pos.buf->prev;
      pos.ptr = pos.buf->end-1;
    }
  if ((pos.buf == parser->eptr.buf) && ((pos.ptr+offset) >= parser->eptr.ptr))
    return 0;
  res = pos.ptr[offset];
  return res ? res : 0xff;
}

caddr_t VXmlErrorContext (vxml_parser_t * parser)
{
  char buf[CONTEXT_BUF_LENGTH];
  VXmlErrorContext2 (buf, parser);
  return box_dv_short_string (buf);
}

char *VXmlErrorContext2(char* buffer, vxml_parser_t * parser)
{
  buf_ptr_t pos = parser->pptr;
  int err_col;
  int offset;
  char ch;
  int ctr;
  char *tail = buffer;

  for(offset=0; (offset > (-MAX_CONTEXT_LEFT)); offset--)
    {
      ch = relative_char(parser, pos, offset-1);
      if ((0 == ch) || ('\n' == ch) || ('\r' == ch))
	break;
    }
  err_col = -offset;
  for (ctr=0; ctr<err_col; ctr++)
    {
      ch = relative_char(parser, pos, ctr-err_col);
      (tail++)[0] = (('\t' == ch) ? ' ' : ch);
    }
  for(offset=0; (offset < (MAX_CONTEXT_ALL-err_col)); offset++)
    {
      ch = relative_char(parser, pos, offset);
      if ((0 == ch) || ('\n' == ch) || ('\r' == ch))
	break;
      (tail++)[0] = (('\t' == ch) ? ' ' : ch);
    }
  (tail++)[0] = '\n';
  for (ctr=0; ctr<err_col; ctr++)
    {
      (tail++)[0] = '-';
    }
  strcpy(tail,"^");
  return tail+1;
}


caddr_t VXmlFullErrorMessage (vxml_parser_t * parser)
{
  dk_set_t lastdetail = NULL;
  dk_set_t iter;
  dk_set_t first_error = NULL;
  dk_set_t lastdetail_of_first_error = NULL;

  iter = parser->msglog;
  while (iter)
    {
      unsigned errlevel = (unsigned)(uptrlong)(iter->data);
      switch (errlevel)
        {
        case XCFG_DETAILS:
          if (NULL == lastdetail)
            lastdetail = iter;
          break;
        case XCFG_ERROR: case XCFG_FATAL:
          if (NULL == lastdetail)
            lastdetail = iter;
          iter = iter->next->next;
          first_error = iter;
          lastdetail_of_first_error = lastdetail;
          lastdetail = NULL;
          continue;
        default:
          lastdetail = NULL;
        }
      iter = iter->next->next;
    }
  if (NULL != lastdetail_of_first_error)
    return xmlparser_log_section_to_string (lastdetail_of_first_error, first_error, "XML parser detected an error:");
  return box_dv_short_string ("");
}


caddr_t VXmlValidationLog (vxml_parser_t * parser)
{
  return xmlparser_log_section_to_string (parser->msglog, NULL, "");
}


ccaddr_t VXmlFindNamespaceUriByPrefix (vxml_parser_t * parser, ccaddr_t prefix)
{
  int ctr = parser->attrdata.all_nsdecls_count;
  if (NULL != prefix)
    {
      size_t prefix_sz = box_length (prefix);
      while (ctr--)
	{
          nsdecl_t *nsd = parser->nsdecl_array + ctr;
	  if (box_length (nsd->nsd_prefix) == prefix_sz && !memcmp (nsd->nsd_prefix, prefix, prefix_sz))
	    return nsd->nsd_uri;
        }
    }
  else
    {
      while (ctr--)
	{
          nsdecl_t *nsd = parser->nsdecl_array + ctr;
	  if (uname___empty == nsd->nsd_prefix)
            {
              caddr_t uri = nsd->nsd_uri;
              return (('\0' == uri[0]) ? NULL : uri);
            }
        }
    }
  return NULL;
}


ccaddr_t VXmlFindNamespacePrefixByUri (vxml_parser_t * parser, ccaddr_t uri)
{
  int ctr = parser->attrdata.all_nsdecls_count;
  size_t uri_sz = box_length (uri);
  while (ctr--)
    {
      nsdecl_t *nsd = parser->nsdecl_array + ctr;
      if ((uri_sz == box_length (nsd->nsd_uri)) && !memcmp (nsd->nsd_uri, uri, uri_sz))
	return nsd->nsd_prefix;
    }
  return NULL;
}


void VXmlFindNamespaceUriByQName (vxml_parser_t * parser, const char *qname, int is_attr, lenmem_t *uri_ret)
{
  char *colon = strrchr (qname, ':');
  int ctr;
  if (XML_SOURCE_TYPE_XTREE_DOC == parser->cfg.input_source_type)
    {
      if (NULL != colon)
        {
          uri_ret->lm_length = colon - qname;
          uri_ret->lm_memblock = (char *)qname;
        }
      else
        {
          uri_ret->lm_length = 0;
          uri_ret->lm_memblock = NULL;
        }
      return;
    }
  ctr = parser->attrdata.all_nsdecls_count;
  if (NULL != colon)
    {
      size_t prefix_sz = colon + 1 - qname;
      while (ctr--)
	{
	  nsdecl_t *nsd = parser->nsdecl_array + ctr;
	  if ((box_length (nsd->nsd_prefix) != prefix_sz) ||
	    memcmp (qname, nsd->nsd_prefix, prefix_sz - 1) )
	  continue;
	  uri_ret->lm_length = box_length (nsd->nsd_uri) - 1;
	  uri_ret->lm_memblock = nsd->nsd_uri;
	  return;
	}
    }
  else
    {
      if (is_attr)
        {
          uri_ret->lm_length = 0;
          uri_ret->lm_memblock = NULL;
	  return;
	}
      while (ctr--)
	{
	  nsdecl_t *nsd = parser->nsdecl_array + ctr;
	  if (uname___empty != nsd->nsd_prefix)
	    continue;
          if ('\0' == nsd->nsd_uri[0])
            break;
	  uri_ret->lm_length = box_length (nsd->nsd_uri) - 1;
	  uri_ret->lm_memblock = nsd->nsd_uri;
	  return;
	}
    }
  uri_ret->lm_length = 0;
  uri_ret->lm_memblock = NULL;
  return;
}


#ifdef MALLOC_DEBUG
#undef VXmlFindExpandedNameByQName
#endif
caddr_t DBG_NAME(VXmlFindExpandedNameByQName) (DBG_PARAMS vxml_parser_t * parser, const char *qname, int is_attr)
{
  char *colon;
  int ctr;
  if (XML_SOURCE_TYPE_XTREE_DOC == parser->cfg.input_source_type)
    return DBG_NAME(box_dv_short_string) (DBG_ARGS qname);
  colon = strrchr (qname, ':');
  ctr = parser->attrdata.all_nsdecls_count;
  if (NULL != colon)
    {
      size_t prefix_sz = colon + 1 - qname;
      while (ctr--)
	{
	  nsdecl_t *nsd = parser->nsdecl_array + ctr;
	  if ((box_length (nsd->nsd_prefix) == prefix_sz) &&
	    !memcmp (qname, nsd->nsd_prefix, prefix_sz - 1) )
	    {
	      size_t uri_sz = box_length (nsd->nsd_uri);
	      caddr_t res = DBG_NAME(dk_alloc_box) (DBG_ARGS uri_sz + strlen (colon), DV_SHORT_STRING);
	      memcpy (res, nsd->nsd_uri, uri_sz - 1);
	      strcpy (res + uri_sz - 1, colon);
	      return res;
	    }
	}
    }
  else
    {
      if (is_attr)
	return DBG_NAME(box_dv_short_string) (DBG_ARGS qname);
      while (ctr--)
	{
	  nsdecl_t *nsd = parser->nsdecl_array + ctr;
	  if (uname___empty == nsd->nsd_prefix)
	    {
              caddr_t res;
	      size_t uri_sz;
              if ('\0' == nsd->nsd_uri[0])
                break;
              uri_sz = box_length (nsd->nsd_uri);
	      res = DBG_NAME(dk_alloc_box) (DBG_ARGS uri_sz + strlen (qname) + 1, DV_SHORT_STRING);
	      memcpy (res, nsd->nsd_uri, uri_sz - 1);
	      res [uri_sz - 1] = ':';
	      strcpy (res + uri_sz, qname);
	      return res;
	    }
	}
    }
  return DBG_NAME(box_dv_short_string) (DBG_ARGS qname);
}
#ifdef MALLOC_DEBUG
#define VXmlFindExpandedNameByQName(p,q,a) dbg_VXmlFindExpandedNameByQName (__FILE__, __LINE__, (p), (q), (a))
#endif


int VXmlExpandedNameEqualsQName (vxml_parser_t * parser, const char * expanded_name,
				 const char * qname, int is_attr)
{
  caddr_t exp_qname = VXmlFindExpandedNameByQName (parser, qname, is_attr);
  int res = strcmp (exp_qname, expanded_name) ? 0 : 1;
  dk_free_box (exp_qname);
  return res;
}


const xml_def_4_notation_t *VXmlGetNotation (vxml_parser_t * parser, const char *refname)
{
  id_hash_t *dict;
  xml_def_4_notation_t *res;
  dict = parser->validator.dv_dtd->ed_notations;
  if (NULL == dict)
    res = NULL;
  else
    {
      caddr_t hash_val = id_hash_get (dict, (caddr_t)(&refname));
      res = ((NULL == hash_val) ? NULL : ((xml_def_4_notation_t **)(void **)(hash_val))[0]);
    }
  return res;
}

const xml_def_4_entity_t *VXmlGetParameterEntity (vxml_parser_t * parser, const char *refname)
{
  id_hash_t *dict;
  xml_def_4_entity_t *res;
  dict = parser->validator.dv_dtd->ed_params;
  if (NULL == dict)
    res = NULL;
  else
    {
      caddr_t hash_val = id_hash_get (dict, (caddr_t)(&refname));
      res = ((NULL == hash_val) ? NULL : ((xml_def_4_entity_t **)(void **)(hash_val))[0]);
    }
  return res;
}

const xml_def_4_entity_t *VXmlGetGenericEntity (vxml_parser_t * parser, const char *refname)
{
  id_hash_t *dict;
  xml_def_4_entity_t *res;
  dict = parser->validator.dv_dtd->ed_generics;
  if (NULL == dict)
    res = NULL;
  else
    {
      caddr_t hash_val = id_hash_get (dict, (caddr_t)(&refname));
      res = ((NULL == hash_val) ? NULL : ((xml_def_4_entity_t **)(void **)(hash_val))[0]);
    }
  return res;
}

/* IvAn/ParseDTD/999721 **/

const char *concat_full_name (const char *ns, const char *name)
{
  if ((NULL != ns) && (NULL == strrchr (name, ':')))
    {
      size_t nslen = strlen (ns);
      size_t namelen = strlen (name);
      char *res = dk_alloc_box (nslen+namelen+2, DV_SHORT_STRING);
      memcpy (res, ns, nslen);
      res[nslen] = ':';
      memcpy (res + nslen + 1, name, namelen);
      res[nslen+namelen+1] = '\0';
      return res;
    }
  return name;
}


void dtd_start_element_handler (vxml_parser_t* parser, const char * name, vxml_parser_attrdata_t *attrdata)
{
  ptrlong fsa_cfg = parser->validator.dv_curr_config.dc_fsa;
  ptrlong attr_mode = parser->validator.dv_curr_config.dc_attr_unknown;
  if (((XCFG_DISABLE != fsa_cfg) || (XCFG_DISABLE != attr_mode)) && (parser->validator.dv_depth < ECM_MAX_DEPTH-1))
    {
      dtd_astate_t *newstate = parser->validator.dv_stack + parser->validator.dv_depth;
      dtd_t * dtd = parser->validator.dv_dtd;
      ptrlong nameidx;
      nameidx = ecm_find_name (name, dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t));
      if (nameidx < 0)
	{
	  nameidx = ECM_EL_UNKNOWN;
	  newstate->da_el = NULL;
	  newstate->da_state = ECM_ST_ERROR;
	  if (dtd->ed_is_filled)
	    {
	      xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (name),
		"Element name <%s> is not listed in the DTD", name);
	    }
	}
      else
	{
	  ecm_el_t *el = dtd->ed_els + nameidx;
	  newstate->da_el = el;
	  newstate->da_state = ((el->ee_is_empty) ? ECM_ST_EMPTY :
	    ((el->ee_is_any) ? ECM_ST_ANY : ECM_ST_START) );
	}

/* Attribute constraints checking */
      if ((nameidx >= 0) && (XCFG_DISABLE != attr_mode))
	{
	  ecm_el_t* el = dtd->ed_els + nameidx;
	  if (XCFG_DISABLE != attr_mode)
	    {
	      int req_no = 0;
	      tag_attr_t *attr = attrdata->local_attrs;
	      tag_attr_t *attr_end = attr + attrdata->local_attrs_count;
	      for (/* no init*/; attr < attr_end; attr++)
		{
		  
		  char *attrname = attr->ta_raw_name.lm_memblock;
		  ptrlong attridx;
/* The following is not correct. E.g. xml:lang is not reflected by DTD too.
		      if (('x' == aptr[0][0]) && ('m' == aptr[0][1]) && ('l' == aptr[0][2]) &&
			  ('n' == aptr[0][3]) && ('s' == aptr[0][4]))
The correct version compares only reserved characters:
*/
		  attridx = ecm_find_name (attrname, el->ee_attrs, el->ee_attrs_no, sizeof (ecm_attr_t));
		  if (-1 == attridx)
		    {
		      if (('x' == attrname[0]) && ('m' == attrname[1]) && ('l' == attrname[2]))
		        continue;
		      xmlparser_logprintf (parser, attr_mode, ECM_MESSAGE_LEN + strlen (attrname) + strlen (el->ee_name),
			"Attribute name '%s' is not allowed by the DTD grammar of element <%s>",
			attrname, el->ee_name );
		      continue;
		    };
		  if (el->ee_attrs[attridx].da_is_required)
		    req_no++;
		  /* check attribute type and value, report errors */
		  dtd_check_attribute (parser, attr->ta_value, el->ee_attrs + attridx);
		}
	      if (req_no < el->ee_req_no)
		xmlparser_logprintf (parser, attr_mode, ECM_MESSAGE_LEN + strlen (el->ee_name),
		  "Not all required attributes are defined for element <%s>. [VC: Required Attribute]", el->ee_name);
	    }
	}
/* FSA processing for previous or top level */
      if (XCFG_DISABLE != fsa_cfg)
	{
      if (parser->validator.dv_depth == 0)
	{
	      char *root = parser->validator.dv_root;
	      if ((NULL != root) && strcmp (root, name))
		{
		  xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (name) + strlen (parser->validator.dv_root),
		  "Top level element name <%s> does not match name <%s> in DTD header. [VC: Root Element Type]",
		  name, parser->validator.dv_root );
		}
	    }
	  else
	    {
	      ecm_st_idx_t curidx = newstate[-1].da_state;
	      switch (curidx)
		{
		case ECM_ST_ERROR:
		  break;	/* Error already reported, nothing to check */
		case ECM_ST_ANY:
		  break;	/* No restrictions, nothing to check */
		case ECM_ST_EMPTY:
		  xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (newstate[-1].da_el->ee_name),
		    "Sub-elements are not allowed in element <%s> declared EMPTY in the DTD grammar",
		    newstate[-1].da_el->ee_name );
		  break;
		default:
		  {
		    ecm_st_t *st = newstate[-1].da_el->ee_states + curidx;
		    ecm_st_idx_t newidx;
		    if (NULL == st)
	    	      {
			char *outername = newstate[-1].da_el->ee_name;
		        xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (outername),
		          "Internal parser error in handling PCDATA in element <%s>",
		        outername );
			break;
		      }
		    newidx = st->es_nexts[ECM_EL_OFFSET + nameidx];
		    if (ECM_ST_ERROR == newidx)
		      {
			char *outername = newstate[-1].da_el->ee_name;
			if (xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (name) + strlen (outername),
			    "Element <%s> does not match expected DTD grammar of element <%s>",
			    name, outername ) )
			  xmlparser_logprintf_grammar (parser, newstate[-1].da_el );
		      }
		    newstate[-1].da_state = newidx;
		  }
		}
	    }
	}
    }

  if (NULL != parser->slaves.start_element_handler)
    (parser->slaves.start_element_handler)(parser->slaves.user_data, name, attrdata);

  parser->validator.dv_depth += 1;
}


void dtd_end_element_handler (vxml_parser_t* parser, const char * name)
{
  ptrlong fsa_cfg = parser->validator.dv_curr_config.dc_fsa;
  if ((XCFG_DISABLE != fsa_cfg) && (parser->validator.dv_depth < ECM_MAX_DEPTH))
    {
      dtd_astate_t *currstate = parser->validator.dv_stack + parser->validator.dv_depth - 1;
      ecm_st_idx_t curidx;
/* FSA processing for current level */
      curidx = currstate->da_state;
      switch (curidx)
	{
	case ECM_ST_ERROR:
	  break;	/* Error already reported, nothing to check */
	case ECM_ST_ANY:
	  break;	/* No restrictions, nothing to check */
	case ECM_ST_EMPTY:
	  break;	/* Yes, end is only expected thing for EMPTY */
	default:
	  {
	    ecm_st_t *st = currstate->da_el->ee_states + curidx;
	    ecm_st_idx_t newidx;
	    if (NULL == st)
	      {
	        xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (currstate->da_el->ee_name),
	          "Internal parser error in handling end of element <%s>",
	        currstate->da_el->ee_name );
		break;
	      }
	    newidx = st->es_nexts[ECM_EL_OFFSET + ECM_EL_EOS];
	    if (ECM_ST_ERROR == newidx)
	      {
		char *elname = currstate->da_el->ee_name;
		if (xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (elname),
		    "Ending tag is not allowed here by the DTD grammar of element <%s>", elname ) )
		  xmlparser_logprintf_grammar (parser, currstate->da_el);
	      }
	  }
	}
    }
  parser->validator.dv_depth -= 1;
  if ((!parser->validator.dv_depth) &&
      (XCFG_DISABLE != parser->validator.dv_curr_config.dc_id_dupe) && (parser->validator.dv_dtd->ed_is_filled))
    { /* check for unresolved IDREFS */
      dtd_check_ids(parser);
    }
  if (NULL != parser->slaves.end_element_handler)
    (parser->slaves.end_element_handler)(parser->slaves.user_data,name);
}

void dtd_check_ids(vxml_parser_t* parser)
{
  char** id_name;
  ecm_id_t** idptr;
  id_hash_iterator_t iter;
  id_hash_iterator (&iter, parser->ids);
  while (hit_next (&iter, (caddr_t*) &id_name, (caddr_t*) &idptr))
    {
      ecm_id_t* id = *idptr;
      if (!id->id_defined)
        { /* it is possible to create full logging, but now only first reference is reported */
	  ecm_refid_logitem_t* refid = (ecm_refid_logitem_t*) basket_get (&id->id_log);
	  if (refid)
	    {
	      const char* filename = ((NULL != refid->li_filename) ? refid->li_filename : parser->cfg.uri);
	      ptrlong dupe_mode = parser->validator.dv_curr_config.dc_id_dupe | XCFG_NOLOGPLACE;
	      ptrlong len = ECM_MESSAGE_LEN + strlen(*id_name) + ((NULL == filename) ? 0 : strlen (filename));
	      if (refid->li_line_no < 0)
	        {
		  if ((NULL == filename) || ('\0' == filename[0]))
		    xmlparser_logprintf (parser, dupe_mode, len,
		       "Unresolved ID '%s'", *id_name);
		  else
		    xmlparser_logprintf (parser, dupe_mode, len,
		      "Unresolved ID '%s' in '%s'", *id_name, filename );
	        }
	      else
	        {
		  if ((NULL == filename) || ('\0' == filename[0]))
		    xmlparser_logprintf (parser, dupe_mode, len,
		      "Unresolved ID '%s' at line %d of source text", *id_name,
		      refid->li_line_no );
		  else
		    xmlparser_logprintf (parser, dupe_mode, len,
		      "Unresolved ID '%s' at line %d of '%s'", *id_name,
		      refid->li_line_no, filename );
		}
	      dk_free (refid, sizeof (ecm_refid_logitem_t));
	    }
        }
    }
}

void dtd_char_data_handler (vxml_parser_t* parser, const char * s, int len )
{
  ptrlong fsa_cfg = parser->validator.dv_curr_config.dc_fsa;
  ptrlong fsabadws_cfg = parser->validator.dv_curr_config.dc_fsa_bad_ws;
  if (XCFG_DISABLE == fsabadws_cfg)
    fsabadws_cfg = fsa_cfg;
  if ((XCFG_DISABLE != fsa_cfg) && (parser->validator.dv_depth < ECM_MAX_DEPTH) && (parser->validator.dv_depth > 0))
    {
      int wsonly = 1, ctr;
      dtd_astate_t *currstate = parser->validator.dv_stack + parser->validator.dv_depth - 1;
      ecm_st_idx_t curidx;
/* FSA processing for current level */
      curidx = currstate->da_state;
      switch (curidx)
	{
	case ECM_ST_ERROR:
	  break;	/* Error already reported, nothing to check */
	case ECM_ST_ANY:
	  break;	/* No restrictions, nothing to check */
	case ECM_ST_EMPTY:
	  for (ctr = len; ctr--; /*no step*/)
	    {
	      char c = s[ctr];
	      switch(c)
		{
		case ' ': case '\r': case '\n': case '\t':
		  continue;
		default:
		  wsonly = 0;
		}
	      break;
	    }
	  if (wsonly)
	    {
	      if (XCFG_IGNORE != fsabadws_cfg)
		xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (currstate->da_el->ee_name),
		  "Whitespace chars are not allowed in element <%s> declared EMPTY in the DTD grammar",
		  currstate->da_el->ee_name );
	    }
	  else
	    xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (currstate->da_el->ee_name),
	      "PCDATA are not allowed in element <%s> declared EMPTY in the DTD grammar",
	      currstate->da_el->ee_name );
	  break;
	default:
	  {
	    ecm_st_t *st = currstate->da_el->ee_states + curidx;
	    ecm_st_idx_t newidx;
	    if (NULL == st)
	      {
	        xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (currstate->da_el->ee_name),
	          "Internal parser error in handling PCDATA in element <%s>",
	        currstate->da_el->ee_name );
		break;
	      }
	    newidx = st->es_nexts[ECM_EL_OFFSET + ECM_EL_PCDATA];
	    if (ECM_ST_ERROR == newidx)
	      {
		char *name = currstate->da_el->ee_name;
		 for (ctr = len; ctr--; /*no step*/)
		   {
		     char c = s[ctr];
		     switch(c)
		       {
			case ' ': case '\r': case '\n': case '\t':
			  continue;
			default:
			  wsonly = 0;
			}
		      break;
		    }
		if (wsonly)
		  {
		    if (XCFG_IGNORE == fsabadws_cfg)
		      newidx = curidx;			/* Rollback to masquerade error */
		    else
		      xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (name),
			"Whitespace chars are not allowed here by the DTD grammar of element <%s>",
			name );
		  }
		else
		  xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (name),
		    "PCDATA are not allowed by the DTD grammar of element <%s>", name );
	      }
	    currstate->da_state = newidx;
	  }
	}
    }
  if (NULL != parser->slaves.char_data_handler)
    (parser->slaves.char_data_handler)(parser->slaves.user_data, s, len);
}


dtd_t *VXmlGetDtd(vxml_parser_t * parser)
{
  return parser->validator.dv_dtd;
}


#define DTD_STUB(__func,__args_decl,__args) \
 void dtd_##__func __args_decl \
 { \
   xml_dbg_printf (("invoking file %s line %d\n", __FILE__, __LINE__)); \
   if (NULL != parser->slaves.__func) \
     parser->slaves.__func __args ; \
 }

DTD_STUB(comment_handler,
  (vxml_parser_t* parser, const char * text),
  (parser->slaves.user_data,text))

DTD_STUB(entity_ref_handler,
  (vxml_parser_t* parser, const char *refname, int reflen, int isparam, const xml_def_4_entity_t *edef),
  (parser->slaves.user_data,refname,reflen,isparam,edef))

DTD_STUB(pi_handler,
  (vxml_parser_t* parser, const char * target, const char * data),
  (parser->slaves.user_data,target,data))

/*
DTD_STUB(dtd_handler,
  (vxml_parser_t* parser, struct dtd_s *dtd),
  (parser->slaves.user_data,dtd));
*/
