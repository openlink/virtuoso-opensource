/*
 *  dtd.c
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

#include "langfunc.h"
#include "xmlparser_impl.h"
#include "xml_ecm.h"

#ifdef UNIT_DEBUG
#define dtd_dbg_printf(a) printf a
#else
#define dtd_dbg_printf(a)
#endif

#define SHOULD_BE_CHANGED_SUC 1;

#define DTD_NOTENOUGH_MEM "Not enough memory to store %s"

struct enum_type_tokens {
  const char *name;
  ptrlong   enum_id;
} enum_type_tokens[] = {
  { "NMTOKENS", ECM_AT_NMTOKENS },
  { "NMTOKEN", ECM_AT_NMTOKEN },
  { "ENTITIES", ECM_AT_ENTITIES },
  { "ENTITY", ECM_AT_ENTITY },
  { "IDREFS", ECM_AT_IDREFS },
  { "IDREF", ECM_AT_IDREF },
  { "CDATA", ECM_AT_CDATA } };


#define build_dtd_member_ptr(field)\
	(&((dtd_t*)NULL)->field - (id_hash_t**)NULL)
#define dtd_member_ptr(dtd, hash_offset)\
	((id_hash_t *)(*((dtd_t**)dtd + hash_offset)))

struct enum_hashed_types {
  ptrlong	enum_id;
  const char *	type_name;
  ptrdiff_t	hash_offset;
} enum_hashed_types[] = {
  { ECM_AT_ENTITIES, "ENTITY", build_dtd_member_ptr (ed_generics) },
  { ECM_AT_ENTITY, "ENTITY", build_dtd_member_ptr (ed_generics) },
  { ECM_AT_ENUM_NOTATIONS, "NOTATION", build_dtd_member_ptr (ed_notations) } };

ptrlong index_hashed_types[] = { -1,
				 -1,
				 2, /* ECM_AT_ENUM_NOTATIONS */
				 -1,
				 -1,
				 -1,
				 1, /* ENTITY */
				 0, /* ENTITIES */
				 -1,
				 -1 };



extern unsigned char ecm_utf8props[0x100];

#define ecm_isnamebegin(c) \
  ( ((c) & ~0xFF) ? (ecm_utf8props[(c)] & ECM_ISNAMEBEGIN) : \
    ((UCP_ALPHA | UCP_IDEO) & unichar_getprops((c))) )
#define ecm_isname(c) \
  ( ((c) & ~0xFF) ? (ecm_utf8props[(c)] & ECM_ISNAME) : \
    ((UCP_ALPHA | UCP_IDEO) & unichar_getprops((c))) )

#define FREE_NAMEBUF(lenmem) \
  dk_free_box((lenmem).lm_memblock);


int get_refentry (vxml_parser_t* parser, char* refname);

static int dtd_check_nmtokens (vxml_parser_t * parser, const char * vals);
static int dtd_check_nmtoken (vxml_parser_t * parser, const char * nmtoken);

/* parser->tmp contains name of element */
static int
dtd_parse_attlist (vxml_parser_t* parser, dtd_validator_t* validator)
{
  /* maximum 6 chars could be in encoded unichar */
  lenmem_t name_buffer;
  ptrlong el_idx;

  dtd_dbg_printf(("***DTD*** parse attlist..."));
  brcpy (&name_buffer , &parser->tmp.name );
  el_idx = ecm_find_name(name_buffer.lm_memblock,
			validator->dv_dtd->ed_els,
			validator->dv_dtd->ed_el_no,
			sizeof (ecm_el_t));
  if (ECM_MEM_NOT_FOUND == el_idx)
    {
      ptrlong mode = validator->dv_curr_config.dc_names_unordered ;
      if (XCFG_DISABLE != mode)
	{
	  xmlparser_logprintf (parser, mode, ECM_MESSAGE_LEN + name_buffer.lm_length,
			"Element <%s> is not declared", name_buffer.lm_memblock);
	  if (mode <= XCFG_ERROR) /* error or fatal */
	    {
	      FREE_NAMEBUF (name_buffer);
	      return 0;
	    }
	}
      el_idx = ecm_add_name (name_buffer.lm_memblock,
			   (void**) &validator->dv_dtd->ed_els,
			   &validator->dv_dtd->ed_el_no,
			   sizeof (ecm_el_t));
      validator->dv_dtd->ed_els[el_idx].ee_is_defbyatt = 1;
    }
  else
    FREE_NAMEBUF(name_buffer);
  if (ECM_MEM_UNIQ_ERROR != el_idx )
    {
      ecm_el_t* element = &validator->dv_dtd->ed_els[el_idx];
      /*      if (element->ee_attrs)
	{
	  xmlparser_logprintf (parser, XCFG_WARNING , ECM_MESSAGE_LEN + strlen(element->ee_name),
			"ATTLIST for element <%s> has been already declared",
			element->ee_name);
	  }; */
      /* parse attribute declarations */
      for (;;)
	{
	  ptrlong attr_index;
	  if (!test_ws (parser) || !get_att_name (parser))
	    {
	      if (test_char (parser, '>'))
		{
		  dtd_dbg_printf((" done\n"));
		  break;
		}
	      else
		{
		  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Unexpected char, should be '>'"); /* unexpected input */
		  return 0;
		};
	    }
	  /* encode attribute name */
	  brcpy (&name_buffer, &parser->tmp.name );
	  attr_index = ecm_add_name(name_buffer.lm_memblock,
				    (void**) &element->ee_attrs,
				    &element->ee_attrs_no,
				    sizeof(ecm_attr_t) );
	  if (ECM_MEM_UNIQ_ERROR == attr_index)
	    {
	      FREE_NAMEBUF(name_buffer);
	      /* ignore next attribite declaration */
	      if ( !test_ws (parser) ||
		   !get_att_type (parser) ||
		   !test_ws (parser) ||
		   !get_def_decl (parser) )
		{
		  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error in attribute declaration"); /* unexpected input */
		  return 0;
		}
	    }
	  else
	    {
	      ecm_attr_t* el_attr = &element->ee_attrs[attr_index];
	      dtd_dbg_printf((" %s", name_buffer.lm_memblock));

	      if ( !test_ws (parser) ||
		   !dtd_get_att_type (parser, element, attr_index, validator) )
		{
		  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error in attribute type"); /* unexpected input */
		  return 0;
		}
	      /* da_type is valid at this point */
	      if ( !test_ws (parser) ||
		   !dtd_get_def_decl (parser, el_attr, element) )
		{
		  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error in declaration of the default value of the attribute"); /* unexpected input */
		  return 0;
		};
	      if (!dtd_constraint_check(parser, element, attr_index) )
		{
		  /* error reporting have been already done */
		  return 0;
		}

	    }
	}
    }
  else
    {
      xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN+name_buffer.lm_length, DTD_NOTENOUGH_MEM , name_buffer.lm_memblock);
      dk_free(name_buffer.lm_memblock, name_buffer.lm_length);
      goto failed;
    }
  return 1;
failed:
  return 0;
}

/*
  <!ATTLIST S+NAME ATTRIBUTES...>
	      ^
  pointer-->--|
*/

int dtd_add_attlist_decl(dtd_validator_t* validator,  vxml_parser_t* parser)
{
  /*  if (test_string(parser, "<!ATTLIST"))
      { */
      test_ws(parser);
      if ( !get_att_name (parser)  ||
	   !dtd_parse_attlist(parser,validator) )
	{
	  return 0;
	};
      /*    }; */
  return 1;
}


/* find string entry in enum_type_tokens array */
int test_atttype_string (vxml_parser_t* parser)
{
  size_t i;
  for (i=0; i<sizeof(enum_type_tokens)/sizeof(struct enum_type_tokens); i++)
    {
      if (test_string( parser, enum_type_tokens[i].name))
	{
	  parser->tmp.att_type = enum_type_tokens[i].enum_id;
	  return 1;
	};
    };
  return 0;
}


int dtd_get_att_type (vxml_parser_t* parser,
		      ecm_el_t* elem, ptrlong attr_index,
		      dtd_validator_t* validator)
{
  ecm_attr_t* attr = &elem->ee_attrs[attr_index];
  if (test_char (parser, '('))
    {	/* enumeration */
      attr->da_type = ECM_AT_ENUM_NAMES;
      for (;;)
	{
	  buf_ptr_t rem ;
	  test_ws (parser);
	  rem = parser->pptr;
	  if (!test_class_str (parser, XML_CLASS_NMCHAR))
	    {
	      xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error in enumeration: name expected"); /* unexpected input */
	      return 0;
	    }
	  else
	    {
	      buf_range_t type_range;
	      lenmem_t name_buffer;
	      type_range.beg = rem ;
	      type_range.end = parser->pptr ;
	      brcpy (&name_buffer, &type_range );
	      if ( (ECM_MEM_UNIQ_ERROR != ecm_add_name ( name_buffer.lm_memblock,
					 (void**) &(attr->da_values),
					 &attr->da_values_no,
					 sizeof (char *))) )
		{
		  test_ws (parser);
		  if (test_char (parser, ')'))
		    return 1;
		  if (!test_char (parser, '|'))
		    {
		      xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error in enumeration"); /* unexpected input */
		      return 0;
		    }
		}
	      else
		{
		  dk_free(name_buffer.lm_memblock,name_buffer.lm_length+1);
		  return 0;
		};
	    };
	};
      /* not reachable */
    }
  else
    {
      /* TokenizedType attribute */
      if (test_atttype_string (parser))
	{
	  attr->da_type = parser->tmp.att_type;
	  return 1;
	}
      if (test_string(parser,"ID"))
	{
	  if (!elem->ee_has_id_attr)
	    {
	      attr->da_type = ECM_AT_ID;
	      elem->ee_has_id_attr = 1;
	      return 1;
	    }
	  else
	    {
	      xmlparser_logprintf (parser, XCFG_ERROR, ECM_MESSAGE_LEN, "No element type may have more than one ID attribute specified. [VC: One ID per Element Type]");
	      return 0;
	    }
	}
      /* NOTATION attribute */
      else if (test_string (parser, "NOTATION"))
	{
	  attr->da_type = ECM_AT_ENUM_NOTATIONS ;

	  if (elem->ee_is_empty)
	    xmlparser_logprintf (parser, validator->dv_curr_config.dc_sgml, ECM_MESSAGE_LEN, "For compatibility, an attribute of type NOTATION must not be declared on an element declared EMPTY.  [VC: No Notation on Empty Element]");
	  if (elem->ee_has_notation)
	    xmlparser_logprintf (parser, validator->dv_curr_config.dc_vc_dtd, ECM_MESSAGE_LEN, "No element type may have more than one NOTATION attribute specified. [VC: One Notation Per Element Type]");
	  if (!test_ws (parser) ||
	      !test_char (parser, '('))
	    return 0;

	  for (;;)
	    {
	      test_ws (parser);
	      if (get_name (parser))
		{
		  lenmem_t name_buffer;
		  buf_range_t range = parser->tmp.name;
		  id_hash_t *dict;
		  xml_def_4_notation_t** notation;
		  brcpy (&name_buffer, &range);
		  dict = parser->validator.dv_dtd->ed_notations;
		  notation = ((NULL == dict) ? NULL : (xml_def_4_notation_t**)id_hash_get (dict,(caddr_t)&name_buffer.lm_memblock));
		  if (NULL != notation)
		    {
		      ptrlong val_index = ecm_add_name (name_buffer.lm_memblock,
						    (void**) &attr->da_values, &attr->da_values_no,
						    sizeof (char *) );
		      if (ECM_MEM_UNIQ_ERROR == val_index)
			{
			  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN,
					DTD_NOTENOUGH_MEM, name_buffer.lm_memblock );
			  FREE_NAMEBUF(name_buffer);
			  return 0;
			}
		      dtd_dbg_printf (("NOTATION ATTR ADDED: %s\n", name_buffer.lm_memblock));
		    }
		  else
		    {
		      xmlparser_logprintf (parser, validator->dv_curr_config.dc_vc_dtd, ECM_MESSAGE_LEN, "Undefined NOTATION name %s. [VC: Notation Attributes]", name_buffer.lm_memblock);
		      FREE_NAMEBUF(name_buffer);
		    }
		  elem->ee_has_notation = 1;
		  goto next_notation;
		}
	      xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error in NOTATION"); /* unexpected input */
	      return 0;
	    next_notation:
	      test_ws (parser);
	      if (test_char (parser, ')'))
		return 1;
	      if (!test_char (parser, '|'))
		{
		  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Syntax error: ')' or '|' expected"); /* unexpected input */
		  return 0;
		}
	    }
	}
    }
  return 0;
}

int
dtd_get_def_decl (vxml_parser_t * parser, ecm_attr_t* attr, ecm_el_t* el)
{
  if (test_string (parser, "#REQUIRED"))
    {
      attr->da_is_required = 1;
      el->ee_req_no++;
      return 1;
    }
  else if (test_string (parser, "#IMPLIED"))
    {
      attr->da_is_implied = 1;
      return 1;
    };

  if (test_string (parser, "#FIXED"))
    {
      attr->da_is_fixed = 1;
      if (!test_ws (parser))
	return 0;
    }
  if (get_value (parser,1))
    {
      caddr_t norm_value = dtd_normalize_attr_value (parser, &parser->tmp.value,attr->da_type);
      if (NULL != attr->da_values)
	{
	  /* search default value in da_values array */
	  ptrlong val_index = ecm_find_name (norm_value, attr->da_values, attr->da_values_no, sizeof (char *) );
	  attr->da_default.index = val_index;
	  dk_free_box (norm_value);
	}
      else
	{
	  attr->da_default.boxed_value = norm_value;
	}
      return 1;
    }
  return 0;
}

int dtd_constraint_check (vxml_parser_t* parser, ecm_el_t* elem, ptrlong attr_index)
{
  ecm_attr_t* attr = &elem->ee_attrs [attr_index];
  dtd_validator_t* validator = &parser->validator;
  ptrlong mode = validator->dv_curr_config.dc_attr_misformat;
  switch (attr->da_type)
    {
    case ECM_AT_ID:
      if ( !attr->da_is_required && !attr->da_is_implied )
	{
	  if (XCFG_DISABLE == mode)
	    return 1;
	  xmlparser_logprintf (parser, mode, ECM_MESSAGE_LEN, "ID attribute must be either #IMPLIED or #REQUIRED.  [VC: ID Attribute Default]");
	  return 0;
	}
      break;
    case ECM_AT_ENUM_NAMES:
    case ECM_AT_ENUM_NOTATIONS:
      if ( !attr->da_is_required &&
	   !attr->da_is_implied &&
	   (-1 == attr->da_default.index) )
	{
	  if (XCFG_DISABLE == mode)
	    return 1;
	  xmlparser_logprintf (parser, validator->dv_curr_config.dc_vc_dtd, ECM_MESSAGE_LEN, "Default value must be either from enumeration list or #REQUIRED or #IMPLIED [!!!]");
	  return 0;
	};
      break;
    case ECM_AT_NMTOKENS:
      if (attr->da_default.boxed_value)
	return dtd_check_nmtokens (parser, attr->da_default.boxed_value);
      break;
    case ECM_AT_NMTOKEN:
      if (attr->da_default.boxed_value)
	return dtd_check_nmtoken (parser, attr->da_default.boxed_value);
      break;
    };
  return 1;
}

#ifdef DEBUG
/*
  Encodes from UNICODE to UTF8 , if successful returns pointer to end of encoded name,
  name ends with '\0'
  if fails returns NULL;
*/
char* get_encoded_name (vxml_parser_t* parser, unichar* beg, unichar* end,
			   char** name, dtd_validator_t* validator)
{
  char* name_end;
  /* maximum 6 utf8chars encoded from 1 unichar */
  *name = dk_alloc( (beg - end) / sizeof(unichar)*6+1) ;
  dtd_dbg_printf(("get name: "));
  name_end = eh_encode_buffer__UTF8 (beg, end,
				     *name,
				     *name + (beg - end) / sizeof(unichar)*6+1) ;
  if (name_end)
    {
      *name_end = 0x00;
      dtd_dbg_printf(("%s done\n", *name));
    }
  else
    {
      xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Could not encode element from unicode to UTF8.");
      dk_free(*name, (beg-end)/sizeof(unichar)*6+1);
      *name = 0;
      dtd_dbg_printf(("failed\n"));
      return 0;
    };
  return name_end;
}
#endif /* DEBUG */

struct xhtml_ent_s { const char *entity; int encoded_symbol; const char *descr;};
extern const struct xhtml_ent_s * xhtml_ent_gperf (register const char *str, register unsigned int len);

unichar
dtd_char_ref (vxml_parser_t* parser, char* str, size_t sz)
{
  unichar res = 0;
  int flag = 1;
  char *tail = str;

  if ('#' == tail[0])
    {
      if (sz < 3) /* #z; */
	return -1;
      tail++;
      if (('x' == tail[0]) ||
	  (parser->cfg.input_is_html && ('X' == tail[0])))
	{
	  tail++;
	  for (;;)
	    {
	      char c = (tail++)[0];
	      if (c < 0)
		return c;

	      if (c >= '0' && c <= '9')
		res = (res << 4) + c - '0';	/* FIXME - overflow check */
	      else if (c >= 'a' && c <= 'f')
		res = (res << 4) + c - 'a' + 10;
	      else if (c >= 'A' && c <= 'F')
		res = (res << 4) + c - 'A' + 10;
	      else if (!flag && (c == ';' || parser->cfg.input_is_html))
		return res;
	      else
		{
		  xmlparser_logprintf (parser, XCFG_ERROR, 100, "Invalid character reference: ';' not found after '&#x...'");
		  return -1;
		}

	      flag = 0;
	    }
	}
      else
	{
	  for (;;)
	    {
	      char c = (tail++)[0];
	      if (c < 0)
		return c;

	      if (c >= '0' && c <= '9')
		res = res * 10 + c - '0';	/* FIXME - overflow check */
	      else if (!flag && (c == ';' || parser->cfg.input_is_html))
		return res;
	      else
		{
		  xmlparser_logprintf (parser, XCFG_ERROR, 100, "Invalid character reference: ';' not found after '&#...'");
		  return -1;
		}

	      flag = 0;
	    }
	}
    }
  if (parser->cfg.input_is_html)
    {
      const struct xhtml_ent_s *lookup_res;
      utf8char buf[10 + 1];
      utf8char c;
      size_t idx;
      for (idx = 0; idx < 10; idx++)
	{
	  if (idx >= sz)
	    return -1;
	  c = str[idx];
	  if ((c & ~0x7F) || !isalnum(c))
	    {
	      if (';' != c)
		return -1;
	      break;
	    }
	  buf[idx] = c;
	}
      buf[idx] = '\0';
      lookup_res = xhtml_ent_gperf ((char *)(buf), idx);
      if (NULL == lookup_res)
	return -1;
      return lookup_res->encoded_symbol;
    }
  switch (str[0])
    {
    case 'a':
      if ((sz >= 4) && !strncmp("amp;", str, 4))
	return '&';
      if ((sz >= 5) && !strncmp("apos;", str, 5))
	return '\'';
      return -1;
    case 'g':
      if ((sz >= 3) && !strncmp("gt;", str, 3))
	return '>';
      return -1;
    case 'l':
      if ((sz >= 3) && !strncmp("lt;", str, 3))
	return '<';
      return -1;
    case 'q':
      if ((sz >= 5) && !strncmp("quot;", str, 5))
	return '"';
      return -1;
    }
  return -1;
}

/* level=0	 do not remove leading and trailing wss,
		do not replace sequence of wss to one ws */
caddr_t
dtd_normalize_attr_val (vxml_parser_t* parser, const char* value, int level)
{
  lenmem_t tmp_buf;
  caddr_t buffer;
  size_t i;
  char *buf_tail;
  short state = 0; /* state 0 - eat blanks 1 - keep one, switch to 0 */
  tmp_buf.lm_memblock = (char*) value;
  tmp_buf.lm_length = strlen(value);
  buf_tail = buffer = dk_alloc_box (tmp_buf.lm_length + 1, DV_STRING);
  for (i=0; i < tmp_buf.lm_length; i++)
    {
      switch (tmp_buf.lm_memblock[i])
	{
	case 0x20:
	case 0x9:
	case 0xA:
	case 0xD:
	  switch (state)
	    {
	    case 0:
	      continue;
	    case 1:
	      (buf_tail++)[0] = 0x20;
	      if (level)
		state=0;
	      continue;
	    }
	  break;
	case '&': /* ref_char substitution */
	  {
	    unichar c = dtd_char_ref (parser, tmp_buf.lm_memblock + (i + 1), tmp_buf.lm_length - (i + 1));
	    if (c >= 0)
	      {
		while (';' != tmp_buf.lm_memblock[++i] && (i < tmp_buf.lm_length)) {}
/* Trick! The fact is used that &..; notation is longer than UTF8 encoding for all standard charrefs,
thus the length of output is no larger than the length if input. */
		buf_tail = eh_encode_char__UTF8 (c, buf_tail, buf_tail+MAX_UTF8_CHAR /* no need to pass the handler here */);
		break;
	      }
	  } /* fall to next case */
	default:
	  (buf_tail++)[0] = tmp_buf.lm_memblock[i];
	  state=1;
	}
    }
  /* check last char */
  if (level && (0 < tmp_buf.lm_length) &&
      (0x20 == tmp_buf.lm_memblock [ tmp_buf.lm_length - 1]))
    buf_tail--;
  (buf_tail/*++*/)[0] = 0x00;
  if (buf_tail == (buffer + tmp_buf.lm_length))
    return buffer;
  else
    {
      caddr_t res = box_dv_short_nchars (buffer, buf_tail - buffer);
      dk_free_box (buffer);
      return res;
    }
}

caddr_t
dtd_normalize_attr_value (vxml_parser_t* parser, buf_range_t* range, ptrlong attr_type)
{
  /* this function is subject of change in the future for speeding up */
  lenmem_t tmp_buf;
  caddr_t res;
  brcpy (&tmp_buf, range);
  if (tmp_buf.lm_length)
    {
      res = dtd_normalize_attr_val (parser, tmp_buf.lm_memblock, ECM_AT_CDATA != attr_type);
      FREE_NAMEBUF (tmp_buf);
      return res;
    }
  else
    {
      dk_free(tmp_buf.lm_memblock, tmp_buf.lm_length + 1);
      return box_dv_short_nchars ("", 0);
    }
}

int
dtd_get_content_def (vxml_parser_t * parser, ecm_el_t* element)
{
  buf_range_t gram;
  gram.beg = parser->pptr;
  if (get_content_def (parser))
    {
      lenmem_t grammar_buf;
      gram.end = parser->pptr;
      brcpy (&grammar_buf, &gram);
      if (NULL != element->ee_grammar)
	dk_free_box (element->ee_grammar);
      element->ee_grammar = grammar_buf.lm_memblock;
      return 1;
    }
  return 0;
}


int
dtd_add_element_decl (dtd_validator_t* validator, vxml_parser_t * parser)
{
  ptrlong el_index;

  if (!get_name (parser) ||
      !test_ws (parser))
    return 0;
  else
    {
      lenmem_t name_buf;
      brcpy (&name_buf, &parser->tmp.name);
      dtd_dbg_printf (("element declaration %s..", name_buf.lm_memblock));
      el_index = ecm_find_name (name_buf.lm_memblock,
			    (void *) validator->dv_dtd->ed_els,
			    validator->dv_dtd->ed_el_no, sizeof (ecm_el_t));
      /* rus 09/10/02 forward element define by <ATTLIST...> */
      if (ECM_MEM_NOT_FOUND == el_index)
	{
	  el_index = ecm_add_name (name_buf.lm_memblock,
			    (void **) &validator->dv_dtd->ed_els,
			    &validator->dv_dtd->ed_el_no, sizeof (ecm_el_t));
	}
      else
	{
	  if (0 == validator->dv_dtd->ed_els[el_index].ee_is_defbyatt)
	    {
	      xmlparser_logprintf (parser, validator->dv_curr_config.dc_vc_dtd, ECM_MESSAGE_LEN + name_buf.lm_length,
		"Element <%s> has been declared already. [VC: Unique Element Type Declaration]", name_buf.lm_memblock );
	      FREE_NAMEBUF(name_buf);
	      replace_entity (parser);
	      if (
		!test_string (parser, "EMPTY") &&
		!test_string (parser, "ANY") &&
		!get_content_def (parser) )
		return 0;
	      test_ws (parser);
	      dtd_dbg_printf ((" not done"));
	      return test_char (parser, '>');
	    }
	  validator->dv_dtd->ed_els[el_index].ee_is_defbyatt = 0;
	  FREE_NAMEBUF(name_buf);
	}
    }
  replace_entity (parser);
  if (test_string (parser, "EMPTY"))
    {
      /* TBD - empty element processing */
      validator->dv_dtd->ed_els[el_index].ee_is_empty = 1;
    }
  else if (test_string (parser, "ANY"))
    {
      /* TBD - ANY element processing */
      validator->dv_dtd->ed_els[el_index].ee_is_any = 1;
    }
  else if (!dtd_get_content_def (parser, &validator->dv_dtd->ed_els[el_index]))
    return 0;

  test_ws (parser);
  dtd_dbg_printf ((" done"));
  return test_char (parser, '>');
}


static char default_get_include[1] = "\0";

int get_include (vxml_parser_t *parser, const char *base, const char *ref, lenmem_t *res_text, xml_pos_t *res_pos)
{
  ptrlong mode = parser->validator.dv_curr_config.dc_include;
  ptrlong trace = parser->validator.dv_curr_config.dc_trace_loading;
  char *err = NULL, *path, *newtext = &(default_get_include[0]);
  lenmem_t **cached_text_ptr;
  lenmem_t *cached_text;
  dtp_t text_dtp;
  res_text->lm_memblock = newtext;
  res_text->lm_length = 0;
  res_pos->origin_uri = NULL;
  res_pos->origin_ent = NULL;
  res_pos->line_num = res_pos->col_b_num = res_pos->col_c_num = 0;
  if (XCFG_DISABLE == mode)
    {
      if (XCFG_DISABLE != trace)
	xmlparser_logprintf (parser, XCFG_DETAILS, 100+strlen(base)+strlen(ref),
	  "Loading skipped from reference URI '%s' with base URI '%s', as configured by DTD validation options.", ref, base );
      return 0;
    }
  path = parser->cfg.uri_resolver (parser->cfg.uri_appdata, &err, base, ref, "UTF-8");
  if (err)
    {
      if (xmlparser_logprintf (parser, mode, 100+strlen(base)+strlen(ref),
	  "Unable to resolve reference URI '%s' with base URI '%s'", ref, base ) )
        xmlparser_logprintf (parser, XCFG_DETAILS, strlen(((char **)err)[1])+strlen(((char **)err)[2]), "[%s]: %s", ((char **)err)[1], ((char **)err)[2] );
      return 0;
    }
  cached_text_ptr = (lenmem_t **)id_hash_get (parser->includes, (caddr_t)(&path));
  if (NULL != cached_text_ptr)
    {
      caddr_t key_ptr;
      cached_text = cached_text_ptr[0];
      res_text->lm_memblock = cached_text->lm_memblock;
      res_text->lm_length = cached_text->lm_length;
      res_pos->line_num = res_pos->col_b_num = res_pos->col_c_num = 1;
      res_pos->origin_ent = NULL;
      key_ptr = id_hash_get_key_by_place (parser->includes, cached_text_ptr);
      res_pos->origin_uri = ((caddr_t *)key_ptr)[0];
      dk_free_box (path);
      return 1;
    }
  newtext = parser->cfg.uri_reader(parser->cfg.uri_appdata, &err, NULL, base, ref, 1);
  if (err)
    {
      struct xml_iter_syspath_s* syspath_iter = xml_iter_system_path();
      char* syspath;
      do
	{
	  syspath = xml_iter_syspath_hitnext(syspath_iter);
	  if (syspath)
	    newtext = parser->cfg.uri_reader(parser->cfg.uri_appdata, &err, NULL, syspath, ref, 1);
	  else
	    break;
	} while (err);
      xml_free_iter_system_path(syspath_iter);
      if (syspath)
	goto succ;
      if (xmlparser_logprintf (parser, mode | XCFG_NOLOGPLACE, 100+strlen(path),
	  "Unable to read document from URI '%s'", path ) &&
        xmlparser_logprintf (parser, XCFG_DETAILS, strlen(((char **)err)[1])+strlen(((char **)err)[2]), "[%s]: %s", ((char **)err)[1], ((char **)err)[2] ) &&
        xmlparser_logprintf (parser, XCFG_DETAILS, 100+strlen(path)+strlen(base)+strlen(ref),
	  "URI '%s' constructed from reference URI '%s' with base URI '%s'", path, ref, base ) )
        xmlparser_log_place (parser);
      return 0;
    }
succ:
  text_dtp = box_tag(newtext);
  cached_text = dk_alloc_box (sizeof (lenmem_t), DV_ARRAY_OF_LONG);
  cached_text->lm_memblock = res_text->lm_memblock = newtext;
  cached_text->lm_length = res_text->lm_length =
    box_length (newtext) -
      (((DV_SHORT_STRING == (text_dtp)) || (DV_LONG_STRING == (text_dtp))) ?
	1 :
 	sizeof (wchar_t) );
  id_hash_set(parser->includes, (caddr_t)(&path), (caddr_t)(&cached_text));
  res_pos->line_num = res_pos->col_b_num = res_pos->col_c_num = 1;
  res_pos->origin_ent = NULL;
  res_pos->origin_uri = path;
  parser->input_weight += 1 + (res_text->lm_length / 16);
  parser->input_cost += 2 + (res_text->lm_length / 16);
  if (XML_MAX_DOC_COST < parser->input_cost)
    parser->input_cost = XML_MAX_DOC_COST;
  
  if (XCFG_DISABLE != trace)
    xmlparser_logprintf (parser, XCFG_OK, 100+strlen(path)+strlen(base)+strlen(ref),
      "%d bytes loaded from URI '%s' constructed from reference URI '%s' with base URI '%s'", res_text->lm_length, path, ref, base );
  return 1;
}

int entity_compile_repl (vxml_parser_t *parser, xml_def_4_entity_t *newdef)
{
  lenmem_t raw_text;
  lenmem_t recoded_text;
  xml_pos_t include_pos;
  int lt_gt_balance, lpar_rpar_balance;
  char *tail;
  const char *local_base_uri;
  int get_include_res;
  if (NULL == newdef->xd4e_systemId)
    {
      if (NULL == newdef->xd4e_literalVal)
	return 0;
      raw_text.lm_memblock = newdef->xd4e_literalVal;
      raw_text.lm_length = strlen (newdef->xd4e_literalVal);
      recoded_text.lm_length = raw_text.lm_length;
      recoded_text.lm_memblock = dk_alloc_box (raw_text.lm_length+1, DV_SHORT_STRING);
      recoded_text.lm_memblock[raw_text.lm_length] = '\0';
      memcpy (recoded_text.lm_memblock, raw_text.lm_memblock, raw_text.lm_length);
      xml_pos_set (&(newdef->xd4e_val_pos), &(newdef->xd4e_defn_pos));
      goto check_brace_balance;
    }
  local_base_uri = newdef->xd4e_defn_pos.origin_uri;
  if (NULL == local_base_uri)
    local_base_uri = parser->cfg.uri;
  get_include_res = get_include (parser, local_base_uri, newdef->xd4e_systemId, &raw_text, &include_pos);
  if (!get_include_res)
    {
      if ((XCFG_DISABLE != parser->validator.dv_curr_config.dc_include) && (XCFG_IGNORE != parser->validator.dv_curr_config.dc_include))
	return 0;
      newdef->xd4e_may_be_in_ecm = 0;
      newdef->xd4e_may_be_in_mkup = 0;
      newdef->xd4e_repl.lm_memblock = (char *)("");
      newdef->xd4e_repl.lm_length = 0;
    }
  /* recoding */
  {
    encoding_handler_t *body_eh = &eh__UTF8_QR;
    int state = 0;
    const char *src_begin = raw_text.lm_memblock;
    unichar tmp_cells = (unichar) ((20 + raw_text.lm_length) / body_eh->eh_minsize);
    int tmp_len = sizeof(unichar) * tmp_cells;
    unichar *tmp = (unichar *)dk_alloc (tmp_len);
    int decode_res = body_eh->eh_decode_buffer (tmp, tmp_cells, &src_begin, raw_text.lm_memblock+raw_text.lm_length, body_eh, &state);
    int tmp2_len;
    char *tmp2, *tmp2_tail;
    if (decode_res < 0)
      decode_res = 0;
    tmp2_len = MAX_UTF8_CHAR * tmp_cells + 1;
    tmp2 = (char *)dk_alloc (tmp2_len);
    tmp2_tail = eh_encode_buffer__UTF8 (tmp, tmp+decode_res, tmp2, tmp2+tmp2_len);
    dk_free (tmp, tmp_len);
    recoded_text.lm_length = tmp2_tail - tmp2;
    recoded_text.lm_memblock = box_dv_short_nchars (tmp2, recoded_text.lm_length);
    dk_free (tmp2, tmp2_len);
  }
  xml_pos_set (&(newdef->xd4e_val_pos), &include_pos);

check_brace_balance:

  lt_gt_balance = lpar_rpar_balance = 0;
  tail = recoded_text.lm_memblock;
  for (;;)
    {
      switch (tail[0])
	{
	case '\0':
	  if (0 != lt_gt_balance)
	    newdef->xd4e_may_be_in_mkup = 0;
	  if (0 != lpar_rpar_balance)
	    newdef->xd4e_may_be_in_ecm = 0;
	  goto finished;
	case '<':
	  lt_gt_balance++;
	  tail++;
	  break;
	case '>':
	  lt_gt_balance--;
	  if (lt_gt_balance < 0)
	    newdef->xd4e_may_be_in_mkup = 0;
	  tail++;
	  break;
	case '(':
	  lpar_rpar_balance++;
	  tail++;
	  break;
	case ')':
	  lpar_rpar_balance--;
	  if (lpar_rpar_balance < 0)
	    newdef->xd4e_may_be_in_ecm = 0;
	  tail++;
	  break;
	default:
	  tail++;
	}
    }

finished:
  newdef->xd4e_repl.lm_memblock = recoded_text.lm_memblock;
  newdef->xd4e_repl.lm_length = recoded_text.lm_length;
  return 1;
}


void insert_buffer (vxml_parser_t* parser, buf_ptr_t* cut_begin, buf_ptr_t* cut_end, lenmem_t* ins, xml_pos_t *ins_beg_pos, xml_pos_t *end_pos)
{
  brick_t *orig = cut_begin->buf;
  brick_t *ins_brick = dk_alloc (sizeof (brick_t));
  int boundary_in_cut = (orig != cut_end->buf);
  brick_t *tail_cont = (boundary_in_cut ? cut_end->buf : dk_alloc (sizeof (brick_t)));
  validate_parser_bricks(parser);
  xml_pos_set (&(ins_brick->beg_pos), ins_beg_pos);
  ins_brick->beg = ins->lm_memblock;
  ins_brick->end = ins->lm_memblock + ins->lm_length;
  ins_brick->data_begin = NULL;
  ins_brick->data_owner = NULL;
  ins_brick->data_refctr = 0;
  ins_brick->prev = orig;
  ins_brick->next = tail_cont;

  xml_pos_set (&(tail_cont->beg_pos), end_pos);
  tail_cont->prev = ins_brick;
  tail_cont->beg = cut_end->ptr;
  if (!boundary_in_cut)
    {
      brick_t *tail_owner = cut_end->buf;
      if (NULL == tail_owner->data_begin)
	tail_owner = tail_owner->data_owner;
      tail_cont->end = orig->end;
      tail_cont->data_begin = NULL;
      tail_cont->data_refctr = 0;
      tail_cont->data_owner = tail_owner;
      if (NULL != tail_owner)
	tail_cont->data_owner->data_refctr += 1;
      tail_cont->next = orig->next;
      if (NULL != orig->next)
	orig->next->prev = tail_cont;
    }
  if (parser->eptr.buf == cut_end->buf)
    parser->eptr.buf = tail_cont;
  orig->next = ins_brick;
  orig->end = cut_begin->ptr;
  cut_end[0] = cut_begin[0];
}

int insert_external_dtd(vxml_parser_t* parser)
{
  lenmem_t uri_repl;
  xml_pos_t repl_pos;
  buf_ptr_t rem = parser->pptr;
  const char *local_base_uri = rem.buf->beg_pos.origin_uri;
#if 0  
  int local_base_uri_is_tmp = 0;
#endif
  int get_include_res=0;
  static const char* system_path = NULL;
  
  if (NULL == system_path)
    system_path = box_dv_short_string ("file://system/");
  if (NULL == local_base_uri)
    local_base_uri = parser->cfg.uri;
#if 0
  else
    {
      char *rightslash = strrchr (local_base_uri, '/');
      if (NULL != rightslash)
	{
	  local_base_uri = box_dv_short_nchars (local_base_uri, rightslash-local_base_uri);
	  local_base_uri_is_tmp = 1;
	}
    }
#endif
  get_include_res = get_include(parser, local_base_uri, parser->tmp.dtd_sysuri, &uri_repl, &repl_pos);
  if (!get_include_res)
    get_include_res = get_include(parser, system_path, parser->tmp.dtd_sysuri, &uri_repl, &repl_pos);
#if 0  
  if (local_base_uri_is_tmp)
    dk_free_box (local_base_uri);
#endif
  if (get_include_res)
    {
      buf_ptr_t end_uri = parser->pptr;
      insert_buffer (parser, &rem, &end_uri, &uri_repl, &repl_pos, &(parser->curr_pos));
      parser->curr_pos_ptr = parser->pptr = rem;
      validate_parser_bricks(parser);
      parser->tmp.dtd_loaded_from_uri = 1;
      return 1;
    }
  parser->pptr = rem;
  if ((XCFG_DISABLE != parser->validator.dv_curr_config.dc_include) && (XCFG_IGNORE != parser->validator.dv_curr_config.dc_include))
    return 0;
  return 1;
}

static char xmlschema_system_dtd [] =
"<!DOCTYPE %sschema SYSTEM \"XMLSchema.dtd\" ["
"	<!ENTITY %% p \"%s\">"
"	<!ENTITY %% s \"%s\">"
"]>";
/* This string contains 2 '%%' and 3 '%s' -- 8 unprintable chars. */
#define xmlschema_system_dtd_pure_strlen (strlen (xmlschema_system_dtd) - 8)

int insert_external_xmlschema_dtd (vxml_parser_t * parser)
{
  lenmem_t text;
  const char * p = parser->cfg.auto_load_xmlschema_dtd_p;
  const char * s = parser->cfg.auto_load_xmlschema_dtd_s;
  buf_ptr_t rem;
  buf_ptr_t end_uri;
  xml_pos_t repl_pos;

  xml_pos_set (&repl_pos, &parser->curr_pos);

  if (NULL == p) p = "";
  if (NULL == s) s = "";
  text.lm_length = xmlschema_system_dtd_pure_strlen + (2 * strlen (p)) + strlen (s);
  text.lm_memblock = dk_alloc_box (text.lm_length + 1, DV_STRING);

  sprintf (text.lm_memblock, xmlschema_system_dtd, p, p, s);

  rem = parser->pptr;
  end_uri = parser->pptr;
  insert_buffer (parser, &rem, &end_uri, &text, &repl_pos, &(parser->curr_pos));
  rem.buf->next->data_begin = text.lm_memblock;
  parser->curr_pos_ptr = parser->pptr = rem;
  validate_parser_bricks(parser);
  return 1;
}

int replace_entity (vxml_parser_t* parser)
{
  int res = 0;
  buf_ptr_t rem = parser->pptr;
  if (!test_char(parser, '%'))
    return res;
  if (replace_entity_common (parser, 0 /* = not GE */, 0, rem, 1))
    {
      parser->curr_pos_ptr = parser->pptr = rem;
#ifdef DEBUG
       validate_parser_bricks(parser);
#endif
      res = 1;
    }
  parser->pptr = rem;
  return res;
}

#if 0
int replace_entity_rec (vxml_parser_t* parser)
{
  buf_ptr_t rem=parser->pptr;
  if (!test_char(parser, '%'))
    return 0;
  if (replace_entity_common (parser, 0 /* = not GE */, 0, rem, 1))
    {
      unichar c;
      buf_ptr_t repl_buf;
      buf_ptr_t rem_buf;
      parser->curr_pos_ptr = parser->pptr = rem;
      rem_buf = parser->pptr;
      c = get_tok_char (parser);
      repl_buf = parser->pptr;
      while (repl_buf.buf == parser->pptr.buf)
	{
	  buf_ptr_t rem_buf_1 = parser->pptr;
	  if (c == '%' ||
	      c == '&')
	    {
	      if (replace_entity_common (parser, c == '&', 0, rem_buf, 0))
		parser->curr_pos_ptr = parser->pptr = rem_buf;
	    }
	  rem_buf = parser->pptr;
	  c = get_tok_char (parser);
	  if (c < 0)
	    goto ret;
	}
      parser->curr_pos_ptr = parser->pptr = rem;
#ifdef DEBUG
      validate_parser_bricks(parser);
#endif
      return 1;
    };
 ret:
  parser->pptr = rem;
  return 0;
}
#endif

int replace_entity_common (vxml_parser_t* parser, int is_ge, xml_def_4_entity_t* repl, buf_ptr_t rem, int log_syntax_error)
{
  id_hash_t* hash;
  buf_ptr_t name_beg;
  dtd_dbg_printf(("\nreplace entity..."));
  if (parser->entity_nesting >= MAX_ENTITY_NESTING_DEPTH)
    {
      if (log_syntax_error)
        xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Too many entities inside names of other entities"); /* unexpected input */
      return 0;
    }
  parser->entity_nesting++;
  hash = (is_ge ?
    parser->validator.dv_dtd->ed_generics :
    parser->validator.dv_dtd->ed_params );
  name_beg = parser->pptr;
  if ((is_ge && test_char (parser, '#')) ||
      (test_class_str(parser, XML_CLASS_NMSTART)))
    {
      if (FINE_XML == parser->cfg.input_is_html)
        test_class_str(parser, XML_CLASS_NMCHAR) ;
      else
        test_class_str_noentity (parser, XML_CLASS_NMCHAR);
      if ( test_char (parser, ';') )
	{
	  lenmem_t name_buf;
	  buf_range_t name_range;
	  xml_def_4_entity_t **ent_repl;
	  unichar c;
	  name_range.beg = name_beg;
	  name_range.end = parser->pptr;
	  brcpy (&name_buf, &name_range);
	  c = is_ge ? dtd_char_ref(parser, name_buf.lm_memblock, name_buf.lm_length) : -1;
	  parser->entity_nesting--;
	  if (-1 != c)
	    {
/* Trick! The fact is used that &..; notation is longer than UTF8 encoding for all standard charrefs,
thus the length of output is no larger than the length if input. */
	      char *tail = eh_encode_char__UTF8 (c, name_buf.lm_memblock, name_buf.lm_memblock + name_buf.lm_length /* no need to pass the handler here */);
	      tail[0] = '\0';
	      name_buf.lm_length = (tail - name_buf.lm_memblock);
	      insert_buffer (parser, &rem, &parser->pptr, &name_buf, &(parser->curr_pos), &(parser->curr_pos));
	      rem.buf->next->data_begin = name_buf.lm_memblock;
	      return 1;
	    };
	  if (NULL == hash)
	    {
	      FREE_NAMEBUF(name_buf);
	      return 0;
	    }
	  dtd_dbg_printf ((" name=%s", name_buf.lm_memblock));

	  name_buf.lm_memblock[name_buf.lm_length-1] = '\0';
	  if (!repl)
	    {
	      ent_repl = (xml_def_4_entity_t**) id_hash_get (hash, (caddr_t) (&name_buf.lm_memblock) );
	    }
	  else
	    ent_repl = &repl;
	  if ((NULL != ent_repl) && (NULL != ent_repl[0]))
	    {
	      dtd_dbg_printf ((" repl=%s<<<<\n", ent_repl[0]->xd4e_repl.lm_memblock));
	      FREE_NAMEBUF(name_buf);
	      insert_buffer (parser, &rem, &parser->pptr, &(ent_repl[0]->xd4e_repl), &(ent_repl[0]->xd4e_val_pos), &(parser->curr_pos));
	      return 1;
	    }
	  else
	    {
	      if (log_syntax_error)
		xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_vc_data, ECM_MESSAGE_LEN + strlen(name_buf.lm_memblock),
		"Could not resolve entity reference '%s'", name_buf.lm_memblock);
	      FREE_NAMEBUF(name_buf);
	      return 0;
	    }
	}

    }
  parser->entity_nesting--;
  if ((NULL != parser->inner_tag) && (NULL != parser->inner_tag->ot_descr) && parser->inner_tag->ot_descr->htmltd_is_script)
    return 0;
  if (log_syntax_error)
    xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN, "Invalid reference"); /* unexpected input */
  return 0;
}

int dtd_add_include_section (struct vxml_parser_s* parser)
{
  buf_ptr_t rem = parser->pptr;
  replace_entity (parser);
  if (test_string (parser, "INCLUDE"))
    {
      /* include section */
      test_ws (parser);
      if (test_char (parser, '[' ))
	return 1;
    }
  parser->pptr = rem;
  return 0;
}

int dtd_add_ignore_section (struct vxml_parser_s* parser)
{
  buf_ptr_t rem = parser->pptr;
  replace_entity (parser);
  if (test_string (parser, "IGNORE"))
    {
      /* ignore section */
      test_ws (parser);
      if (test_char (parser, '[' ))
	{
	  int bobcount = 1;
	  while (1)
	    {
	      if (test_string (parser, "<!["))
		{
		  bobcount++;
		  continue;
		}
	      if (test_string (parser, "]]>" ))
		{
		  bobcount--;
		  if (bobcount == 0)
		    return 1;
		}
	      else
		{
		  /* end of file detection */
		  if (0 > get_tok_char (parser))
		    {
		      return 0;
		    };
		};
	    };
	}
    }
  parser->pptr = rem;
  return 0;
}

#ifdef UNIT_DEBUG
void buffer_dump (FILE* fp, vxml_parser_t* parser)
{
  brick_t* br = parser->bptr.buf ;
  fprintf (fp, "****************************begin dumping...:\n");
  fprintf (fp, "**current buffer %p pointer %p\n", parser->pptr.buf, parser->pptr.ptr );
  while (br)
    {
      char* i = br->beg;
      int count = -1;
      fprintf (fp, "**buffer %p \n**content:\n", br );
      while (--count && (i!=br->end))
	{
	  fprintf (fp, "%c", *i);
	  i++;
	}
      br = br->next;
    }
  fprintf (fp, "**********************************************end dumping...:\n");
  fprintf (fp, "**end buffer %p pointer %p\n", parser->eptr.buf, parser->eptr.ptr );
  fprintf (fp, "**content:\n%s\n", parser->eptr.buf->beg );
  return;
}
#endif

void
free_refid_log (basket_t* refid_log)
{
  ecm_refid_logitem_t* refid = (ecm_refid_logitem_t*) basket_get (refid_log);
  while(refid)
    {
      dk_free (refid, sizeof (ecm_refid_logitem_t));
      refid = (ecm_refid_logitem_t*) basket_get (refid_log);
    }
}

/* rus 07/10/02 xml conformance test bug ibm56i01.xml */
int dtd_check_id_value (char * val, char * val_end)
{
  const xml_char_range_t * cl_nms_ptr = XML_CLASS_NMSTART;
  const xml_char_range_t * cl_nm_ptr = XML_CLASS_NMCHAR;
  const xml_char_range_t * cl_ptr = cl_nms_ptr;
  int c;
  char * valptr = val;

  while (valptr != val_end)
    {
      c = eh_decode_char__UTF8 ((const char **)&valptr, val_end);

      if (c < 0)
	return 0;

      for (;;)
	{
	  if (c < cl_ptr->start)
	    return 0;
	  if (c <= cl_ptr->end)
	    break;
	  cl_ptr++;
	  if (cl_ptr->start < 0)
	    return 0;
	}
      cl_ptr = cl_nm_ptr;
    }
  return 1;
}

/* rus 22/10/02 nmtoken production check */
static
int dtd_check_nmtokens (vxml_parser_t * parser, const char *vals)
{
  int ret = 0;
  char* idrefs = box_string (vals);
  char* idrefs_iter = idrefs ;
  char* idref = strtok_r (idrefs," ", (char**) &idrefs_iter);
  while (idref)
    {
      ret = dtd_check_nmtoken (0, idref);
      if (!ret)
	break;
      idref = strtok_r(NULL, " ", (char**) &idrefs_iter);
    }
  dk_free_box (idrefs);
  if (!ret)
    {
      xmlparser_logprintf (parser, XCFG_WARNING, ECM_MESSAGE_LEN,
		     "NMTOKENS attribute constraint failed" );
    }
  return ret;
}


static
int dtd_check_nmtoken (vxml_parser_t * parser, const char *nmtoken)
{
  int c;
  const char * valptr = nmtoken;
  const char * val_end;
  if (NULL == nmtoken)
    return 1;
  val_end = nmtoken + utf8len (nmtoken);
  while (valptr != val_end)
    {
      const xml_char_range_t * cl_ptr = XML_CLASS_NMCHAR;
      c = eh_decode_char__UTF8 ((const char **)&valptr, val_end);

      if (c < 0)
	goto failed;

      for (;;)
	{
	  if (c < cl_ptr->start)
	    goto failed;
	  if (c <= cl_ptr->end)
	    break;
	  cl_ptr++;
	  if (cl_ptr->start < 0)
	    goto failed;
	}
    }
  return 1;
 failed:
  if (parser)
    {
      xmlparser_logprintf (parser, XCFG_WARNING, ECM_MESSAGE_LEN,
		     "NMTOKEN attribute constraint failed" );
    }
  return 0;
}

int
dtd_check_attribute (vxml_parser_t* parser, const char* value, struct ecm_attr_s* attr)
{
  dtd_config_t* conf = &parser->validator.dv_curr_config;
  caddr_t norm_val;
  int ret = 0;
  ptrlong mode = parser->validator.dv_curr_config.dc_attr_misformat;
  dtd_dbg_printf (("dtd_check_attribute ()"));
  if (XCFG_DISABLE == mode)
    return 1;
  if (ECM_AT_CDATA == attr->da_type)
    {
      if (!attr->da_is_fixed)
        return 1;
      norm_val = dtd_normalize_attr_val (parser, value, 0);
    }
  else
    norm_val = dtd_normalize_attr_val (parser, value, 1);
  switch (attr->da_type)
    {
      /* hashed types */
    case ECM_AT_ENTITIES:
    case ECM_AT_ENTITY:
    case ECM_AT_ENUM_NOTATIONS:
      {
	char* names = box_string (norm_val);
	char* names_iter = names ;
	char* name = strtok_r (names, " ", (char**) &names_iter);
	ret = 1;
	while (name)
	  {
	    id_hash_t* hash =  dtd_member_ptr (parser->validator.dv_dtd,
					       enum_hashed_types[index_hashed_types[attr->da_type]].hash_offset);
	    void* objdef = ( NULL == hash ) ? NULL : id_hash_get ( hash,  (caddr_t) &name);
	    if (!objdef)
	      {
		xmlparser_logprintf (parser, mode, ECM_MESSAGE_LEN + box_length (norm_val),
		  "Undefined %s '%s'", enum_hashed_types[index_hashed_types[attr->da_type]].type_name, name );
		ret = 0;
		break;
	      }
	    else
	      name = strtok_r (NULL, " ", (char**) &names_iter);
	  }
	dk_free_box (names);
      }
      if (!ret ||
	  (ECM_AT_ENUM_NOTATIONS != attr->da_type))
	break;
      ret = 0;
    case ECM_AT_ENUM_NAMES:
      if (attr->da_values_no)
	{
	  ptrlong validx = ecm_find_name (norm_val, attr->da_values, attr->da_values_no, sizeof (char*));
	  if (-1 == validx)
	    {
	      xmlparser_logprintf (parser, mode, ECM_MESSAGE_LEN + box_length (norm_val),
		"Unexpected item name '%s'", norm_val );
	      break;
	    }
	  ret = 1;
	};
      break;
    case ECM_AT_ID:
      /* rus 07/10/02 xml conformance test bug ibm56i01.xml */
      if (!dtd_check_id_value (norm_val, norm_val + box_length (norm_val) - 1))
	{
	  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN + box_length (norm_val),
		       "ID's value '%s' contains unallowed symlbols", norm_val );
	  break;
	}
      if (XCFG_DISABLE != conf->dc_id_dupe)
	{
	  ecm_id_t* id = (ecm_id_t*) ecm_try_add_name (norm_val, parser->ids, sizeof (ecm_id_t));
	  if (id->id_defined)
	    {
	      xmlparser_logprintf (parser, conf->dc_id_dupe, ECM_MESSAGE_LEN + box_length (norm_val),
		"ID '%s' has been used already.  [VC: ID]", norm_val );
	      break;
	    }
	  else
	    {
	      id->id_defined = 1;
	      /* ID is defined, log is not needed */
	      free_refid_log (&id->id_log);
	    }
	  ret = 1;
	}
      if ((XCFG_DISABLE != conf->dc_id_cache) && (NULL != parser->/*masters*/slaves.id_handler))
	  {
	    parser->/*masters*/slaves.id_handler (parser->/*masters*/slaves.user_data, norm_val);
	  }
      break;
    case ECM_AT_IDREFS:
      if (XCFG_DISABLE != conf->dc_idref_dangling)
	{
	  char* idrefs = box_string (norm_val);
	  char* idrefs_iter = idrefs ;
	  char* idref = strtok_r (idrefs," ", (char**) &idrefs_iter);
	  ret = 1;
	  while (idref)
	    {
	      if (!get_refentry (parser, idref))
		{
		  ret = 0;
		  break;
		}
	      else
		idref = strtok_r(NULL, " ", (char**) &idrefs_iter);
	    }
	  dk_free_box (idrefs);
	  if (!ret)
	    {
		xmlparser_logprintf (parser, conf->dc_idref_dangling, ECM_MESSAGE_LEN,
		  "IDREFS attribute constraint failed" );
	    }
	}
      break;
    case ECM_AT_IDREF:
      if ((XCFG_DISABLE == conf->dc_idref_dangling) ||
	  get_refentry (parser, norm_val))
	ret = 1;
      break;
    case ECM_AT_NMTOKENS:
      ret = dtd_check_nmtokens (parser, norm_val);
      break;
    case ECM_AT_NMTOKEN:
      ret = dtd_check_nmtoken (parser, norm_val);
      break;
    case ECM_AT_CDATA:
      ret = 1;
      break; /* no constraints, skip */
    default: /* */
#if 1
      GPF_T1 ("Unsupported attribute type");
#else
      ;
#endif
    }

  if (attr->da_is_fixed)
    {
      char* fixed_val;
      if (attr->da_values_no)
	fixed_val = (char*) attr->da_values[attr->da_default.index];
      else
	fixed_val = attr->da_default.boxed_value;
      if (strcmp (fixed_val, norm_val))
	xmlparser_logprintf (parser, mode, ECM_MESSAGE_LEN + box_length (norm_val) + strlen(fixed_val),
	  "Unexpected attribute value '%s', must be '%s'. [VC: Fixed Attribute Default]", norm_val, fixed_val);
      else
	ret = 1;
    }
  dk_free_box (norm_val);
  return ret;
}


int get_refentry (vxml_parser_t* parser, char* refname)
{
  ecm_id_t* id = (ecm_id_t*) ecm_try_add_name (refname, parser->ids, sizeof (ecm_id_t));
  /* ID could be defined later, add to idrefs log which will be processed later */
  if (!id->id_defined)
    {
      ecm_refid_logitem_t* logrefid = dk_alloc (sizeof(ecm_refid_logitem_t));
      logrefid->li_filename = parser->curr_pos.origin_uri;
      logrefid->li_line_no = parser->curr_pos.line_num;

      basket_add (&id->id_log,logrefid);
    };
  /* else ID is defined, everything is OK */
  return 1;
}

#define DTD_ENT_MAX_NAMESIZ	255
#define DTD_ENTITY_MAX_INCL	100

/* internal states */
#define DTD_ENT_START		0
#define DTD_ENT_NAME		1

/* returns -1 if error exsits */
int check_entity_recursiveness (vxml_parser_t* parser, const char* entityname, int level, const char* currentname)
{
  if(!parser->validator.dv_dtd->ed_generics)
    return -1;
  if (level++ > DTD_ENTITY_MAX_INCL)
    {
      xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN+strlen(currentname),
		     "Maximum depth reached while processing entity <%s>, possible recursive reference",
		     currentname);
      return -1;
    }
  else
    {
      xml_def_4_entity_t** ent_repl = (xml_def_4_entity_t**) id_hash_get (parser->validator.dv_dtd->ed_generics,
									  (caddr_t) (&entityname) );
      size_t repl_c;
      char* repl_ptr;
      size_t name_c = 0;
      char name[DTD_ENT_MAX_NAMESIZ+1];
      int repl_st = DTD_ENT_START;
      if (!ent_repl)
	{
/*
	  xmlparser_logprintf (parser, XCFG_FATAL, ECM_MESSAGE_LEN+strlen(entityname),
			 "Unresolved entity <%s> found", entityname);
	  return -1;
*/
	  return 0;
	}
      repl_ptr = ent_repl[0]->xd4e_repl.lm_memblock;
      for (repl_c = 0; repl_c < ent_repl[0]->xd4e_repl.lm_length; repl_c++)
	{
	  switch (repl_st)
	    {
	    case DTD_ENT_NAME:
	      if (repl_ptr[repl_c] == ';')
		{
		  repl_st = DTD_ENT_START;
		  name[name_c] = 0;
		  if (-1 == check_entity_recursiveness(parser, name, level, currentname))
		    return -1;
		}
	      else
		{
		  if (name_c >= DTD_ENT_MAX_NAMESIZ)
		    {
		      name_c = 0;
		      repl_st = DTD_ENT_START;
		    }
		  else
		    name[name_c++]=repl_ptr[repl_c];
		}
	      break;
	    case DTD_ENT_START:
	      if (repl_ptr[repl_c] == '&')
		{
		  repl_st = DTD_ENT_NAME;
		  name_c = 0;
		}
	      break;
	    }
	}
      return 0;
    }
}

