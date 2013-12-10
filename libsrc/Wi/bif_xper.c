/*
 *  bif_xper.c
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

#ifdef MALLOC_DEBUG
/*#define XMLPARSER_FEED_DEBUG*/
#endif

#include "libutil.h"
/* IvAn/ParseDTD/000721 system parser is wiped out
   #include <xmlparse.h> */

#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"

#include "Dk.h"
#include "bif_xper.h"
#include "xml.h"		/* IvAn/TextXmlIndex/000814 */
#include "bif_text.h"		/* IvAn/TextXperIndex/000814 */
#include "security.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif

#include "multibyte.h"
#include "xpathp_impl.h"

#undef DV_LONG_STRING		/* for safety */
#undef DV_SHORT_STRING		/* for safety */

typedef struct xper_ns_s
  {
    int xpns_depth;		/*!< Depth where it's located */
    caddr_t xpns_name;		/*!< Name of namespace */
    caddr_t xpns_uri;		/*!< URI provided as a 'value' of namespace */
    size_t xpns_pos;		/*!< Offset in a blob */
    size_t xpns_old_pos;	/*!< Offset in a source blob, for use in bif_xper_copy() */
  }
xper_ns_t;

/*! Property list for textual data */
typedef struct xper_textplist_s
  {
    int xptp_depth;		/*!< Depth where it's located */
    caddr_t xptp_lang_name;	/*!< Name of language as specified in xml:lang attribute */
    lang_handler_t *xptp_lang_handler;	/*!< Handler for language named in xptp_lang_name */
  }
xper_textplist_t;

/* IvAn/TextXperIndex/000815 Word counter added */
/* data structure for parser's callback functions */
typedef struct xper_ctx_s
  {
    buffer_desc_t *xpc_buf;
    it_cursor_t *xpc_itc;
    dk_set_t xpc_poss;		/*!< Stack of element positions */
    dk_set_t xpc_nss;		/*!< Stack of namespace attributes */
    dk_set_t xpc_textplists;	/*!< Stack of plists of texts */
    int xpc_depth;		/* current element depth */
    long xpc_et_pos;
    int xpc_tn_length1;		/* length of last open tag name */
    int xpc_tn_length2;		/* length of last close tag name */
    caddr_t xpc_pdir;
    xper_doc_t *xpc_doc;
    /*! \brief Parameter to manage word counting

       In some cases, two or more adjacent tags should share one word number.
       xpc_word_hider keeps the type of previous indexed item:
       XML_MKUP_STAG for opening tag,
       XML_MKUP_ETAG for closing tag,
       XML_MKUP_STRING for plain text with words.
       0 at the beginning of text.
     */
    char xpc_word_hider;
    wpos_t xpc_main_word_ctr;	/*!< counter of words scanned in main text */
    wpos_t xpc_attr_word_ctr;	/*!< counter of words scanned in attributes */
    /*! \brief Buffer for storing words which are not yet counted or indexed

       It is possible that one string value will be loaded into persistent XML by a
       sequence of calls of cb_character callback, so some words may be split
       between two or more calls. To process such words, an accumulating buffer has
       added, where a word can be concatenated from its parts. */
    utf8char *xpc_text_buf;
    /*! \brief Number of chars used in xpc_text_buf */
    int xpc_text_buf_use;
    /*! \brief Size of xpc_text_buf */
    int xpc_text_buf_size;
    caddr_t vt_batch;		/*!< batch of word indexing information, or NULL */
    int xpc_index_attrs;	/*!< Flags if attributes should be indexed */
    id_hash_t *xpc_id_dict;
    caddr_t xpc_src_filename;
    FILE *xpc_src_file;
    vxml_parser_t *xpc_parser;
    dk_set_t xpc_cut_chain;	/* Chain of boxes, which will be written into the copy */
    dk_set_t xpc_cut_namespaces;	/* All namespaces, listed in the cut */
  }
xper_ctx_t;

/* xpc_poss is used in such way:
 * it is a stack of positions.
 * when a start tag is encountered, first we look at the top position.
 * If that value is positive, than it is a position of the parent.
 * If it is negative, than absolute value is a position of the left sibling.
 * And if the stack is empty than we have a first start tag. (It should be root record.)
 * Than a position of current tag element will be
 * placed on the top of the stack. If top position value is negative then its value
 * will be replaced with new one (positive). In the other case new value will be
 * pushed on the stack.
 * When an end tag is encountered and if the top value is negative, we discard it
 * from the stack. Then we negate the top value, marking it as a closed.
 */

/* data structure for a start tag */
struct xper_stag_s
  {
    char type;
    const char *name;
    const char **xmlns_atts;
    int xmlns_atts_count;
    vxml_parser_attrdata_t *attrdata;
    int main_atts_count;
    long parent;
    long left;
    long position;		/* of the tag in a blob */
    int depth;
    dk_set_t *nss_ptr;
    dk_set_t *textplists_ptr;
    int recalc_wrs;
    int store_wrs;
    xe_word_ranges_t wrs;
    lang_handler_t *lh;
  };

typedef struct xper_stag_s xper_stag_t;

/*
 * Structure of start tag info in a blob:
 * 1    DV_XML_MARKUP
 * 4    size of the record
 * 1    type of markup XML_MKUP_XXX
 * X    name as a DV_X_STRING
 * 4    parent position
 * 4    left sibling
 * 4    right sibling
 * 4    first child
 * 4    end tag position
 * 4    word position of start tag
 * 4    word position of end tag
 * 1    children directory flag
 * 4    namespace (offset to value or 0)
 * 4    2 * number of attributes (no of names + no of values) (2 low-end bytes) | length of addons (2 high-end bytes)
 * X    [ optional ] addon bytes;
 * X    attribute 1 name as a DV_X_STRING
 * X    attribute 1 value as a DV_X_STRING
 * ...
 * X    attribute N name as a DV_X_STRING
 * X    attribute N value as a DV_X_STRING
 * XXXXXXXXXXXXXXX
 */

#define STR_NAME_OFF		6
#define STR_PARENT_OFF		(0 * 4)
#define STR_LEFT_SIBLING_OFF	(1 * 4)
#define STR_RIGHT_SIBLING_OFF	(2 * 4)
#define STR_FIRST_CHILD_OFF	(3 * 4)
#define STR_END_TAG_OFF		(4 * 4)
#define STR_START_WORD_OFF	(5 * 4)
#define STR_END_WORD_OFF	(6 * 4)
#define STR_NS_OFF		(7 * 4 + 1)
#define STR_ATTR_NO_OFF		(8 * 4 + 1)
#define STR_ADDON_OR_ATTR_OFF	(9 * 4 + 1)

#define XPER_ROOT_POS XPACK_PREFIX_LEN	/* position of " root" in resulting document's BLOB */
#define MIN_START_ROOT_RECORD_SZ	(STR_NAME_OFF + 7 /* = length of box " root" */ + STR_ADDON_OR_ATTR_OFF)
#define END_ROOT_RECORD_SZ	(STR_NAME_OFF + 7 /* = length of box " root" */)

#define GET_LOCAL_LH(ctx) ( \
  (NULL != ctx->xpc_textplists) ? \
  ((xper_textplist_t *)(ctx->xpc_textplists->data))->xptp_lang_handler : \
  ctx->xpc_doc->xd_default_lh )

/* increment step for page number directory */
#define AOP_STEP (PAGE_DATA_SZ / sizeof (dp_addr_t))

static caddr_t start_tag_record (xper_stag_t * d);
static caddr_t end_tag_record (const char *name);
static void xper_blob_append_data (xper_ctx_t * ctx, const char *data, size_t len);
static void set_long_in_blob (xper_ctx_t * ctx, long pos, long value);
static void xper_destroy_ctx (xper_ctx_t * ctx);
static void xper_blob_append_box (xper_ctx_t * ctx, caddr_t box);

static caddr_t xper_get_attribute (xper_entity_t * xpe, const char * name, int name_len);
static xml_entity_t *xp_reference (query_instance_t * qi, caddr_t base, caddr_t ref, xml_doc_t * from_doc, caddr_t * err_ret);
dtd_t *xp_get_addon_dtd (xml_entity_t * xe);
static caddr_t xp_build_expanded_name (xper_entity_t *xpe);

#ifdef XPER_DEBUG
#define xper_dbg_print(fmt) fprintf (stderr, fmt)
#define xper_dbg_print_1(fmt, arg) fprintf (stderr, fmt, arg)
#else
#define xper_dbg_print(fmt)
#define xper_dbg_print_1(fmt, arg)
#endif

#ifdef XPER_DEBUG
static long xper_entity_alloc_ctr = 0;
static long xper_entity_free_ctr = 0;
#endif

#define XPER_FREE_XPD(xpd) \
  do \
    { \
      if (NULL != (xpd)->xd_dtd) \
	dtd_release ((xpd)->xd_dtd); \
      dk_free_box ((caddr_t)(xpd->xd_id_dict)); \
      dk_free_box (xpd->xd_id_scan); \
      dk_free ((xpd), -1 /* not sizeof (xper_doc_t) because it may be doc made by lazy loader */); \
    } while (0)



/* size of DV_SHORT_STRING_SERIAL or DV_STRING
 * depending on the size of a string
 */
static size_t
dv_string_size (const char *s)
{
  size_t size = strlen (s);

  size += ((size > 255) ? 5 : 2);
  return size;
}

static long
full_dv_string_length (const unsigned char *s)
{
  if (DV_SHORT_STRING_SERIAL == *s)
    return s[1] + 2;
  else if (DV_STRING != *s && DV_ARRAY_OF_POINTER != *s)
    sqlr_new_error ("XE000", "XP9A1", "Error while accessing XML_PERSISTENT: invalid string type %d", *s);
  s++;
  return LONG_REF_NA (s) + 5;
}

static size_t
skip_string_length (unsigned char **ptr)
{
  size_t namelen;

  if (DV_STRING == **ptr || DV_ARRAY_OF_POINTER == **ptr)
    {
      namelen = LONG_REF_NA (*ptr + 1);
      *ptr += 5;
      return namelen;
    }
  if (DV_SHORT_STRING_SERIAL == **ptr)
    {
      namelen = (*ptr)[1];
      *ptr += 2;
      return namelen;
    }
  sqlr_new_error ("XE000", "XP9A2", "Error while accessing XML_PERSISTENT: invalid string type %d", **ptr);
  return 0;			/* Never reached */
}

char *
serialize_string (char *ptr, const char *s)
{
  size_t size = strlen (s);

  if (size > 255)
    {
      *ptr++ = (char) DV_STRING;
      LONG_SET_NA (ptr, size);
      ptr += 4;
    }
  else
    {
      *ptr++ = (char) DV_SHORT_STRING_SERIAL;
      *ptr++ = (unsigned char) size;
    }

  memcpy (ptr, s, size);
  return (ptr + size);
}

ptrlong
find_ns (const char *ns, size_t len, dk_set_t * nss_ptr)
{
  if (!nss_ptr)
    return 0;

  DO_SET (xper_ns_t *, ns_i, nss_ptr)
      if (strlen (ns_i->xpns_name) == len &&
      (0 == len || 0 == memcmp (ns, ns_i->xpns_name, len)))
    return ns_i->xpns_pos;
  END_DO_SET ();

  return 0;
}

static caddr_t
start_tag_record (xper_stag_t * d)
{
  caddr_t res;
  size_t size = 1 + STR_ADDON_OR_ATTR_OFF;	/* size of fixed-length data members */
  unsigned char *rec;
  char *colon;
  ptrlong nspos;
  ptrlong find_res;
  long att_word;
  ptrlong tmp;
  lang_handler_t *lh = d->lh;
  wpos_t total_attrs_word_count = 0;
  tag_attr_t *attr, *attr_start = d->attrdata->local_attrs;
  tag_attr_t *attr_end = attr_start + d->attrdata->local_attrs_count;
  nsdecl_t *nsd, *nsd_start = d->attrdata->local_nsdecls;
  nsdecl_t *nsd_end = nsd_start + d->attrdata->local_nsdecls_count;

  size += dv_string_size (d->name);

  if (d->store_wrs)
    size += (3 * 4);		/* 3 addon longs for attribute indexes */

  for (nsd = nsd_start; nsd < nsd_end; nsd++)
    {
      caddr_t attrname = ((uname___empty == nsd->nsd_prefix) ? uname_xmlns : box_sprintf(10 + box_length (nsd->nsd_prefix), "xmlns:%s", nsd->nsd_prefix));
      ccaddr_t uri = nsd->nsd_uri;
      ptrlong attrval_offs;
      xper_ns_t *ns_data;
      size += dv_string_size (attrname);
      attrval_offs = size;
      size += dv_string_size (uri);
      colon = strrchr (attrname, ':');
      ns_data = (xper_ns_t *) dk_alloc (sizeof (xper_ns_t));
      ns_data->xpns_name = box_copy (nsd->nsd_prefix);
      ns_data->xpns_depth = d->depth;
      ns_data->xpns_pos = d->position + attrval_offs + 5;
      dk_set_push (d->nss_ptr, ns_data);
      dk_free_box (attrname);
    }
  for (attr = attr_start; attr < attr_end; attr++)
        {
	  const char *attrname = attr->ta_raw_name.lm_memblock;
	  const char *attrvalue = attr->ta_value;
	  ptrlong attrval_offs;
	  size += dv_string_size (attrname);
	  attrval_offs = size;
	  size += dv_string_size (attrvalue);
	  colon = strrchr (attrname, ':');
	  if (('x' != attrname[0]) || ('m' != attrname[1]) || ('l' != attrname[2]))
	    {			/* Looks like plain attribute */
	      if (NULL != colon)
		size += 10;	/* attribute name with namespace */
	      continue;
	    }
	  if (0 == strcmp (attrname, "xml:lang"))
	    {
	      xper_textplist_t *textplist_data;
	      if (NULL != d->textplists_ptr[0])
		{		/* If we're already inside element with specified xml:lang */
		  xper_textplist_t *prev_plist = (xper_textplist_t *) d->textplists_ptr[0]->data;
		  if (0 == strcmp (attrvalue, prev_plist->xptp_lang_name))
		    continue;	/* redundant xml:lang may be ignored */
		  lh = lh_get_handler (attrvalue);
		  if (lh == prev_plist->xptp_lang_handler)
		    continue;	/* handler is common for both local and outer languages */
		}
	      else
		{
		  lh = lh_get_handler (attrvalue);
		}
	      textplist_data = (xper_textplist_t *) dk_alloc (sizeof (xper_textplist_t));
	      textplist_data->xptp_lang_name = box_string (attrvalue);
	      textplist_data->xptp_lang_handler = lh;
	      textplist_data->xptp_depth = d->depth;
	      dk_set_push (d->textplists_ptr, textplist_data);
	      continue;
	    }
        }

  if (d->recalc_wrs)
	{
	  for (attr = attr_start; attr < attr_end; attr++)
	    {
	      const char *attrvalue = attr->ta_value;
	      wpos_t word_count;
	      if (&lh__xany == lh)	/* Optimization for most common case */
		word_count = elh__xany__UTF8.elh_count_words (attrvalue, strlen (attrvalue), lh__xany.lh_is_vtb_word);
	      else
		word_count = lh_count_words (&eh__UTF8, lh, attrvalue, strlen (attrvalue), lh->lh_is_vtb_word);
	      total_attrs_word_count += 2 + word_count;
	    }
#ifndef SKIP_XMLNS_WORD_POS
	 for (nsd = nsd_start; nsd < nsd_end; nsd++)
	    {
	      ccaddr_t attrvalue = nsd->nsd_uri;
	      wpos_t word_count;
	      if (&lh__xany == lh)	/* Optimization for most common case */
		word_count = elh__xany__UTF8.elh_count_words (attrvalue, strlen (attrvalue), lh__xany.lh_is_vtb_word);
	      else
		word_count = lh_count_words (&eh__UTF8, lh, attrvalue, strlen (attrvalue), lh->lh_is_vtb_word);
	      total_attrs_word_count += 2 + word_count;
	    }
#endif
	}
  if (d->recalc_wrs)
    d->wrs.xewr_attr_this_end = d->wrs.xewr_attr_beg + total_attrs_word_count;

  /* now we have size of the record */

  res = dk_alloc_box_zero (size, DV_XML_MARKUP);

  rec = (unsigned char *) res;

  *rec++ = d->type;

  rec = (unsigned char *) serialize_string ((char *) rec, d->name);

  LONG_SET_NA (rec + STR_PARENT_OFF, d->parent);
  LONG_SET_NA (rec + STR_LEFT_SIBLING_OFF, d->left);
/* IvAn/TextXperIndex/000815 */
  LONG_SET_NA (rec + STR_START_WORD_OFF, d->wrs.xewr_main_beg);

  colon = strrchr (d->name, ':');
  nspos = find_ns (d->name, colon ? colon - d->name : 0, d->nss_ptr);
  if (nspos)
    LONG_SET_NA (rec + STR_NS_OFF, nspos);

  rec += STR_ATTR_NO_OFF;

  att_word = 2 * (d->attrdata->local_attrs_count + d->attrdata->local_nsdecls_count);
  if (d->store_wrs)
    {
      att_word |= ((3 * 4) << 16);	/* 2 low-end bytes for attr count | 2 high-end bytes for addon */
      LONG_SET_NA (rec, att_word);
      rec += 4;
      tmp = d->wrs.xewr_attr_beg;
      LONG_SET_NA (rec, tmp);
      rec += 4;
      tmp = d->wrs.xewr_attr_this_end;
      LONG_SET_NA (rec, tmp);
      rec += 4;
      tmp = d->wrs.xewr_attr_tree_end;
      LONG_SET_NA (rec, tmp);	/* may be filled later by cb_element_end */
      rec += 4;
    }
  else
    {
      LONG_SET_NA (rec, att_word);
      rec += 4;
    }
  /* attributes */
  for (nsd = nsd_start; nsd < nsd_end; nsd++)
    {
      caddr_t attrname = ((uname___empty == nsd->nsd_prefix) ? uname_xmlns : box_sprintf(10 + box_length (nsd->nsd_prefix), "xmlns:%s", nsd->nsd_prefix));
      ccaddr_t uri = nsd->nsd_uri;
      rec = (unsigned char *) serialize_string ((char *) rec, attrname);
      rec = (unsigned char *) serialize_string ((char *) rec, uri);
      dk_free_box (attrname);
    }
  for (attr = attr_start; attr < attr_end; attr++)
    {
      const char *attrname = attr->ta_raw_name.lm_memblock;
      const char *attrvalue = attr->ta_value;
      colon = 0;
      if (('x' != attrname[0]) || ('m' != attrname[1]) || ('l' != attrname[2]))
	colon = strrchr (attrname, ':');
      if (colon)
	{
	  *rec++ = DV_ARRAY_OF_POINTER;
	  nspos = dv_string_size (attrname) + 5;
	  LONG_SET_NA (rec, nspos);
	  rec += 4;

	  rec = (unsigned char *) serialize_string ((char *) rec, attrname);

	  *rec++ = DV_LONG_INT;
	  find_res = find_ns (attrname, colon - attrname, d->nss_ptr);
	  LONG_SET_NA (rec, find_res);
	  rec += 4;
	}
      else
	rec = (unsigned char *) serialize_string ((char *) rec, attrname);

      rec = (unsigned char *) serialize_string ((char *) rec, attrvalue);
    }
  if (rec != (unsigned char *) (res + size))
    GPF_T;
  return res;
}

caddr_t
end_tag_record (const char *name)
{
  size_t nlen = dv_string_size (name);
  caddr_t res = dk_alloc_box (nlen + 1, DV_XML_MARKUP);
  unsigned char *rec = (unsigned char *) res;

  *rec++ = XML_MKUP_ETAG;

  rec = (unsigned char *) serialize_string ((char *) rec, name);

  return res;
}

void xper_blob_log_page_to_dir (blob_handle_t *ctx_bh, size_t page_idx, dp_addr_t page_addr)
{
  if (NULL == ctx_bh->bh_pages)
    {
      ctx_bh->bh_pages = (dp_addr_t *) dk_alloc_box_zero ((BL_DPS_ON_ROW-1) * sizeof (dp_addr_t), DV_BIN);
      ctx_bh->bh_page_dir_complete = 1;
    }
  else
    {
      unsigned old_pages_bufsize = box_length (ctx_bh->bh_pages);
      unsigned old_n_pages = old_pages_bufsize / sizeof (dp_addr_t);
      if (old_n_pages <= page_idx)
	{
	  int new_n_pages = ((1 + old_n_pages / AOP_STEP) * AOP_STEP);
	  size_t new_dir_sz = new_n_pages * sizeof (dp_addr_t);
	  dp_addr_t *tmp = (dp_addr_t *) dk_alloc_box_zero (new_dir_sz, DV_BIN); /* not DV_ARRAY_OF_LONG */
	  memcpy (tmp, ctx_bh->bh_pages, old_pages_bufsize);
	  dk_free_box ((box_t) ctx_bh->bh_pages);
	  ctx_bh->bh_pages = tmp;
	}
    }
  ctx_bh->bh_pages[page_idx] = page_addr;
}

#ifndef PAGES_COUNT_FOR_DISKBYTES
#define PAGES_COUNT_FOR_DISKBYTES(diskbytes) (((unsigned)(diskbytes) + PAGE_DATA_SZ-1) / PAGE_DATA_SZ)
#endif

void xper_blob_truncate_dir_buf (blob_handle_t *bh)
{
  if (NULL != bh->bh_pages)
    {
      unsigned old_n_pages = box_length (bh->bh_pages) / sizeof (dp_addr_t);
      unsigned new_n_pages = PAGES_COUNT_FOR_DISKBYTES (bh->bh_length);
      if (old_n_pages > new_n_pages)
	{
	  size_t new_dir_sz = new_n_pages * sizeof (dp_addr_t);
	  dp_addr_t *tmp = (dp_addr_t *) dk_alloc_box_zero (new_dir_sz, DV_BIN); /* not DV_ARRAY_OF_LONG */
	  memcpy (tmp, bh->bh_pages, new_dir_sz);
	  dk_free_box ((box_t) bh->bh_pages);
	  bh->bh_pages = tmp;
	}
    }
}


void
xper_blob_append_data (xper_ctx_t * ctx, const char *data, size_t len)
{
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  size_t filled;
  buffer_desc_t *buf;
  size_t len1;
  ASSERT_OUTSIDE_MAP (ctx->xpc_itc->itc_tree, ctx->xpc_itc->itc_page);
  ITC_FAIL (ctx->xpc_itc)
  {
    filled = LONG_REF/*_NA*/ (ctx->xpc_buf->bd_buffer + DP_BLOB_LEN);
    while (len)
      {
	if (filled >= PAGE_DATA_SZ)
	  {
	    size_t old_n_pages = BL_N_PAGES(ctx_bh->bh_length); /* number of new pages is old_n_pages + 1 */
	    buf = it_new_page (ctx->xpc_itc->itc_tree, ctx->xpc_itc->itc_page,
		DPF_BLOB, 0, 0);
#ifdef DEBUG
	    if (0 == buf->bd_page)
	      GPF_T;
#endif
	    xper_blob_log_page_to_dir (ctx_bh, old_n_pages, buf->bd_page);
	    ITC_LEAVE_MAPS (ctx->xpc_itc);
	    if (!buf)
	      {
		xper_destroy_ctx (ctx);
		log_error ("Out of disk space for database");
		sqlr_new_error ("XE000", "XP9A7", "Out of disk space for database while parsing XML");
		return;
	      }
	    LONG_SET/*_NA*/ (ctx->xpc_buf->bd_buffer + DP_BLOB_LEN, PAGE_DATA_SZ);
	    LONG_SET/*_NA*/ (ctx->xpc_buf->bd_buffer + DP_OVERFLOW, buf->bd_page);
	    buf_set_dirty (ctx->xpc_buf);
	    page_leave_outside_map (ctx->xpc_buf);
	    ctx->xpc_buf = NULL;
	    ctx->xpc_buf = buf;
	    filled = 0;
	  }
	len1 = ((len <= PAGE_DATA_SZ - filled) ? len : PAGE_DATA_SZ - filled);
	memcpy (ctx->xpc_buf->bd_buffer + DP_DATA + filled, data, len1);
	filled += len1;
	ctx_bh->bh_diskbytes = ctx_bh->bh_length += len1;
	len -= len1;
	data += len1;
      }
    ITC_LEAVE_MAPS (ctx->xpc_itc);
  }
  ITC_FAILED
  {
    ITC_LEAVE_MAPS (ctx->xpc_itc);
    xper_destroy_ctx (ctx);
    log_error ("Out of disk space for database");
    sqlr_new_error ("XE000", "XP102", "ITC error while parsing XML");
  }
  END_FAIL (ctx->xpc_itc);
  LONG_SET/*_NA*/ (ctx->xpc_buf->bd_buffer + DP_OVERFLOW, 0);
  LONG_SET/*_NA*/ (ctx->xpc_buf->bd_buffer + DP_BLOB_LEN, (int32) filled);
}

void
xper_blob_append_box (xper_ctx_t * ctx, caddr_t box)
{
  unsigned char ccc[5];
  dtp_t tag;
  size_t len;
  tag = box_tag (box);
  len = box_length (box);
  ccc[0] = tag;
  if (DV_SHORT_STRING_SERIAL == tag)
    {
      ccc[1] = (unsigned char) len;
      xper_blob_append_data (ctx, (const char *) ccc, 2);
    }
  else
    {
      LONG_SET_NA (ccc + 1, len);
      xper_blob_append_data (ctx, (const char *) ccc, 5);
    }
  xper_blob_append_data (ctx, box, len);
}

void
blob_append_nchars (xper_ctx_t * ctx, const char *buf, size_t len)
{
  unsigned char ccc[5];
  dtp_t tag = ((len > 255) ? DV_STRING : DV_SHORT_STRING_SERIAL);
  ccc[0] = tag;
  if (DV_SHORT_STRING_SERIAL == tag)
    {
      ccc[1] = (unsigned char) len;
      xper_blob_append_data (ctx, (const char *) ccc, 2);
    }
  else
    {
      LONG_SET_NA (ccc + 1, len);
      xper_blob_append_data (ctx, (const char *) ccc, 5);
    }
  xper_blob_append_data (ctx, buf, len);
}

buffer_desc_t *
get_blob_page_for_read (it_cursor_t * itc, xper_doc_t * xpd, unsigned n)
{
  buffer_desc_t *buf;
  dp_addr_t nth_page;
  nth_page = xpd->xpd_bh->bh_pages[n];
  if (!page_wait_blob_access (itc, nth_page, &buf, PA_READ, xpd->xpd_bh, 1))
    longjmp_splice (itc->itc_fail_context, RST_ERROR);
  return buf;
}

buffer_desc_t *
get_blob_page_for_write (it_cursor_t * itc, xper_doc_t * xpd, unsigned n)
{
  buffer_desc_t *buf;
  dp_addr_t nth_page;
  nth_page = xpd->xpd_bh->bh_pages[n];
  if (!page_wait_blob_access (itc, nth_page, &buf, PA_WRITE, xpd->xpd_bh, 1))
    longjmp_splice (itc->itc_fail_context, RST_ERROR);
  return buf;
}

void
set_long_in_blob (xper_ctx_t * ctx, long pos, long value)
{
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  int last_page_no = (int) (ctx_bh->bh_length - 1) / PAGE_DATA_SZ;
  int begin_page_no = pos / PAGE_DATA_SZ;
  if (begin_page_no == last_page_no)
    {				/* all data are located on the current page */
      LONG_SET_NA (ctx->xpc_buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ,
	  value);
    }
  else
    {
      buffer_desc_t *buf = NULL;
      buf = get_blob_page_for_write (ctx->xpc_itc, ctx->xpc_doc, begin_page_no); /* the beginning is not on the current page */
      if (pos % PAGE_DATA_SZ + 4 <= PAGE_DATA_SZ)
	{
	  LONG_SET_NA (buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ, value);
	  buf_set_dirty (buf);
	  page_leave_outside_map (buf);
	}
      else
	{			/* the worst case - number is split between pages */
	  char cbuf[4];
	  int split = PAGE_DATA_SZ - pos % PAGE_DATA_SZ;	/* 0 < split < 4 */
	  int next_page_no = begin_page_no+1;
	  LONG_SET_NA (cbuf, value);
	  memcpy (buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ, cbuf, split);
	  buf_set_dirty (buf);
	  page_leave_outside_map (buf);
	  if (next_page_no == last_page_no)
	    {
	      memcpy (ctx->xpc_buf->bd_buffer + DP_DATA, cbuf + split, 4 - split);
	    }
	  else
	    {
	      buf = NULL;
	      buf = get_blob_page_for_write (ctx->xpc_itc, ctx->xpc_doc, next_page_no); /* the end is not on the current page */
	      memcpy (buf->bd_buffer + DP_DATA, cbuf + split, 4 - split);
	      buf_set_dirty (buf);
	      page_leave_outside_map (buf);
	    }
	}
    }
}

static void
count_buffered_words (xper_ctx_t * ctx)
{
  if (0 != ctx->xpc_text_buf_use)
    {
      lang_handler_t *lh = GET_LOCAL_LH (ctx);
      int ctr;
      if (&lh__xany == lh)	/* Optimization for most common case */
	ctr = elh__xany__UTF8.elh_count_words ((const char *) ctx->xpc_text_buf, ctx->xpc_text_buf_use, lh__xany.lh_is_vtb_word);
      else
	ctr = lh_count_words (&eh__UTF8, lh, (const char *) ctx->xpc_text_buf, ctx->xpc_text_buf_use, lh->lh_is_vtb_word);
      if (ctr > 0)
	{
	  if (XML_MKUP_ETAG == ctx->xpc_word_hider)
	    ctx->xpc_main_word_ctr--;
	  ctx->xpc_word_hider = XML_MKUP_TEXT;
	  ctx->xpc_main_word_ctr += ctr;
	}
      ctx->xpc_text_buf_use = 0;
    }
}

static void
cb_trace_start_tag (xper_ctx_t * ctx, xper_stag_t * data)
{
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  long pos = 0;
  if (ctx->xpc_poss)
    {
      pos = (long) (ptrlong) ctx->xpc_poss->data;
      ITC_FAIL (ctx->xpc_itc)
      {
	if (pos > 0)
	  {
	    /* first child */
	    set_long_in_blob (ctx, pos + ctx->xpc_tn_length1 +
		STR_NAME_OFF + STR_FIRST_CHILD_OFF,
		(long) ctx_bh->bh_length);
	    data->parent = pos;
	  }
	else
	  {
	    /* right sibling */
	    set_long_in_blob (ctx, -pos + ctx->xpc_tn_length2 +
		STR_NAME_OFF + STR_RIGHT_SIBLING_OFF,
		(long) ctx_bh->bh_length);
	    data->left = -pos;
	    data->parent =
		((ctx->xpc_poss->next) ? (long) (ptrlong) ctx->xpc_poss->next->data : 0);
	  }
	ITC_LEAVE_MAPS (ctx->xpc_itc);
      }
      ITC_FAILED
      {
	ITC_LEAVE_MAPS (ctx->xpc_itc);
	sqlr_new_error ("XE000", "XP9A9", "ITC error on writing persistent XML");
      }
      END_FAIL (ctx->xpc_itc);
    }

  ctx->xpc_tn_length1 = (int) dv_string_size (data->name);

  if (pos < 0)
    ctx->xpc_poss->data = (void *)((ptrlong)(ctx_bh->bh_length));
  else
    dk_set_push (&ctx->xpc_poss, (void *)((ptrlong)(ctx_bh->bh_length)));
}

void
cb_element_start (void *userdata, const char * name, vxml_parser_attrdata_t *attrdata)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  xper_stag_t data;
  caddr_t tmp_box;

/* IvAn/TextXperIndex/000815 Word counter added */
  ASSERT_OUTSIDE_MAP (ctx->xpc_itc->itc_tree, ctx->xpc_itc->itc_page); /* To ensure we had no chance to get deadlock inside the XML parser */
  count_buffered_words (ctx);
  ctx->xpc_word_hider = XML_MKUP_STAG;

  ++ctx->xpc_depth;

  memset (&data, 0, sizeof (data));
  data.type = XML_MKUP_STAG;
  data.name = name;

  data.attrdata = attrdata;
  data.nss_ptr = &ctx->xpc_nss;
  data.textplists_ptr = &ctx->xpc_textplists;
  data.position = (long) ctx_bh->bh_length;
  data.depth = ctx->xpc_depth;
  data.wrs.xewr_main_beg = ctx->xpc_main_word_ctr;
  data.wrs.xewr_attr_beg = ctx->xpc_attr_word_ctr;
  data.recalc_wrs = data.store_wrs = ctx->xpc_index_attrs;
  data.lh = GET_LOCAL_LH (ctx);
  cb_trace_start_tag (ctx, &data);
  tmp_box = start_tag_record (&data);
  ctx->xpc_attr_word_ctr = data.wrs.xewr_attr_this_end;
  xper_blob_append_box (ctx, tmp_box);
  dk_free_box (tmp_box);
}

static void
cb_trace_end_tag (xper_ctx_t * ctx, long curr_pos, const char * name)
{
  long pos = (long) (ptrlong) ctx->xpc_poss->data;

  if (pos < 0)
    {
      dk_set_pop (&ctx->xpc_poss);
      pos = (long) (ptrlong) ctx->xpc_poss->data;
    }

  ctx->xpc_poss->data = (void *) (ptrlong) -pos;

  ctx->xpc_tn_length2 = (int) dv_string_size (name);
  /* end tag */
  ITC_FAIL (ctx->xpc_itc)
  {
    set_long_in_blob (ctx, pos + ctx->xpc_tn_length2 +
	STR_NAME_OFF + STR_END_TAG_OFF,
	curr_pos);
/* IvAn/TextXperIndex/000815 Word counter added */
    set_long_in_blob (ctx, pos + ctx->xpc_tn_length2 +
	STR_NAME_OFF + STR_END_WORD_OFF,
	(long) ctx->xpc_main_word_ctr);
    if (ctx->xpc_index_attrs)
      {
	set_long_in_blob (ctx, pos + ctx->xpc_tn_length2 +
	    STR_NAME_OFF + STR_ADDON_OR_ATTR_OFF + (2 * 4),
	    (long) ctx->xpc_attr_word_ctr);
      }
    ITC_LEAVE_MAPS (ctx->xpc_itc);
  }
  ITC_FAILED
  {
    ITC_LEAVE_MAPS (ctx->xpc_itc);
    sqlr_new_error ("XE000", "XP9A9", "ITC error on writing persistent XML");
  }
  END_FAIL (ctx->xpc_itc);
}


void
cb_element_end (void *userdata, const char * name)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  caddr_t tmp_box;
  xper_ns_t *ns_i;
  xper_textplist_t *textplist_i;

/* IvAn/TextXperIndex/000815 Word counter added */
  ASSERT_OUTSIDE_MAP (ctx->xpc_itc->itc_tree, ctx->xpc_itc->itc_page); /* To ensure we had no chance to get deadlock inside the XML parser */
  count_buffered_words (ctx);
  if (XML_MKUP_ETAG != ctx->xpc_word_hider)
    {
      ctx->xpc_main_word_ctr += 1;
      ctx->xpc_word_hider = XML_MKUP_ETAG;
    }

  cb_trace_end_tag (ctx, (long) ctx_bh->bh_length, name);

  tmp_box = end_tag_record (name);
  xper_blob_append_box (ctx, tmp_box);
  dk_free_box (tmp_box);

  --ctx->xpc_depth;

  while (ctx->xpc_nss)
    {
      ns_i = (xper_ns_t *) (ctx->xpc_nss->data);
      if (ns_i->xpns_depth <= ctx->xpc_depth)
	break;
      dk_set_pop (&ctx->xpc_nss);
      dk_free_box (ns_i->xpns_name);
      dk_free (ns_i, sizeof (xper_ns_t));
    }
  while (ctx->xpc_textplists)
    {
      textplist_i = (xper_textplist_t *) (ctx->xpc_textplists->data);
      if (textplist_i->xptp_depth <= ctx->xpc_depth)
	break;
      dk_set_pop (&ctx->xpc_textplists);
      dk_free_box (textplist_i->xptp_lang_name);
      dk_free (textplist_i, sizeof (xper_textplist_t));
    }
}


void
cb_id (void *userdata, char * name)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  caddr_t boxed_name = box_dv_short_string (name);
  id_hash_t *dict = ctx->xpc_id_dict;
  ptrlong **id_hit, *lpath;
  if (NULL == dict)
    {
      ctx->xpc_id_dict = dict = (id_hash_t *) box_dv_dict_hashtable (509);
    }
  id_hit = (ptrlong **) id_hash_get (dict, (caddr_t) (&boxed_name));
  if (NULL != id_hit)
    {
      dk_free_box (boxed_name);
      return;
    }
/* Calculate a path to current element. */
  lpath = (ptrlong *)  dk_alloc_box (sizeof (ptrlong), DV_ARRAY_OF_LONG);
  lpath[0] = ((ctx->xpc_poss) ? (ptrlong) ctx->xpc_poss->data : 0);
/* Save the result. */
  id_hash_set (dict, (caddr_t) (&boxed_name), (caddr_t) (&lpath));
}


/* IvAn/TextXperIndex/000815 Word counter added */
void
cb_character (void *userdata, const char * s, size_t len)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  const char *s_frag_begin, *s_tail, *s_end;
  unichar uchr;
  int space_found;
  int frag_len, newbuf_len;
  utf8char *newbuf;
/* First, data should be stored inside blob. */
  if (len <= 255)
    {
      unsigned char ccc[2];
      ccc[0] = DV_SHORT_STRING_SERIAL;
      ccc[1] = (unsigned char) len;
      xper_blob_append_data (ctx, (const char *) ccc, 2);
    }
  else
    {
      unsigned char ccc[5];
      ccc[0] = DV_STRING;
      LONG_SET_NA (ccc + 1, len);
      xper_blob_append_data (ctx, (const char *) ccc, 5);
    }
  xper_blob_append_data (ctx, s, len);
/* Now blob looks fine, and we can process words */
  s_end = s + len;
  s_frag_begin = s_tail = s;
/* First, buffer may begin from incomplete char, such part should be skipped */
  while ((s_tail < s_end) && IS_UTF8_CHAR_CONT (s_tail[0]))
    s_tail++;
next_frag:
  for (;;)
    {
      uchr = eh_decode_char__UTF8 (&s_tail, s_end);
      if (uchr < 0)
	{
	  s_tail = s_end;
	  space_found = 0;
	  break;
	}
      if (unicode3_isspace (uchr))
	{
	  space_found = 1;
	  break;
	}
    }
  frag_len = (int) (s_tail - s_frag_begin);
  if (ctx->xpc_text_buf_use + frag_len > ctx->xpc_text_buf_size)
    {
      newbuf_len = ctx->xpc_text_buf_size;
      do
	{
	  newbuf_len *= 2;
	  newbuf_len |= 0x3FF;
	}
      while (ctx->xpc_text_buf_use + frag_len > newbuf_len);
      newbuf = (utf8char *) dk_alloc (newbuf_len);
      memcpy (newbuf, ctx->xpc_text_buf, ctx->xpc_text_buf_use);
      memcpy (newbuf + ctx->xpc_text_buf_use, s_frag_begin, frag_len);
      if (0 != ctx->xpc_text_buf_size)
	dk_free (ctx->xpc_text_buf, ctx->xpc_text_buf_size);
      ctx->xpc_text_buf = newbuf;
      ctx->xpc_text_buf_size = newbuf_len;
    }
  else
    {
      memcpy (ctx->xpc_text_buf + ctx->xpc_text_buf_use, s_frag_begin, frag_len);
    }
  ctx->xpc_text_buf_use += frag_len;
  if (space_found)
    {
      count_buffered_words (ctx);
      s_frag_begin = s_tail;
    }
  if (s_tail < s_end)
    goto next_frag;
}


/* IvAn/ParseDTD/000721 Structure of entity has changed */
void
cb_entity (void *userdata, const char * refname, size_t reflen, int isparam, const xml_def_4_entity_t * edef)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  xper_stag_t data;
  vxml_parser_attrdata_t attrdata;
  tag_attr_t ta;
  caddr_t tmp_box;
  char *uri;
  long my_pos;
  wpos_t tmp_index_attrs;

  count_buffered_words (ctx);
  /* No changes of \c ctx->xpc_word_hider here - entity ref is transparent for words counting. */

  memset (&data, 0, sizeof (data));
  memset (&attrdata, 0, sizeof (attrdata));
  data.attrdata = &attrdata;
  data.type = XML_MKUP_REF;
  data.name = box_dv_short_nchars (refname, reflen);
  uri = ((NULL != edef) ? edef->xd4e_systemId : NULL);
  if (NULL != uri)
    {
      ta.ta_raw_name.lm_memblock = "SYSTEM";
      ta.ta_raw_name.lm_length = 6;
      ta.ta_value = box_dv_short_string (uri);
      attrdata.local_attrs = &ta;
      attrdata.local_attrs_count = 1;
    }
  data.nss_ptr = &ctx->xpc_nss;
  data.textplists_ptr = &ctx->xpc_textplists;
  data.position = (long) ctx_bh->bh_length;
  data.depth = ctx->xpc_depth + 1;
  data.wrs.xewr_main_beg = ctx->xpc_main_word_ctr;
  data.recalc_wrs = data.store_wrs = 0;
  data.lh = NULL;		/* NULL is instead of GET_LOCAL_LH(ctx) to cause GPF on internal errors */
  cb_trace_start_tag (ctx, &data);
  my_pos = (long) ctx_bh->bh_length;
  tmp_box = start_tag_record (&data);
  xper_blob_append_box (ctx, tmp_box);
  tmp_index_attrs = ctx->xpc_index_attrs;
  ctx->xpc_index_attrs = 0;
  cb_trace_end_tag (ctx, my_pos, data.name);
  ctx->xpc_index_attrs = (int) tmp_index_attrs;

  dk_free_box (tmp_box);
  if (NULL != uri)
    dk_free_box (ta.ta_value);
  dk_free_box (( /*nonconst */ char *) (data.name));
}

void
cb_pi (void *userdata, const char * target, const char * pi_data)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
  xper_stag_t data;
  vxml_parser_attrdata_t attrdata;
  tag_attr_t ta;
  caddr_t tmp_box;
  long my_pos;
  wpos_t tmp_index_attrs;

  count_buffered_words (ctx);
  /* No changes of \c ctx->xpc_word_hider here - entity ref is transparent for words counting. */

  memset (&data, 0, sizeof (data));
  memset (&attrdata, 0, sizeof (attrdata));
  data.attrdata = &attrdata;
  data.type = XML_MKUP_PI;
  data.name = box_dv_short_string (target);
  if (NULL != pi_data)
    {
      ta.ta_raw_name.lm_memblock = "data";
      ta.ta_raw_name.lm_length = 4;
      ta.ta_value = box_dv_short_string (pi_data);
      attrdata.local_attrs = &ta;
      attrdata.local_attrs_count = 1;
    }
  data.nss_ptr = &ctx->xpc_nss;
  data.textplists_ptr = &ctx->xpc_textplists;
  data.position = (long) ctx_bh->bh_length;
  data.depth = ctx->xpc_depth + 1;
  data.wrs.xewr_main_beg = ctx->xpc_main_word_ctr;
  data.recalc_wrs = data.store_wrs = 0;
  data.lh = NULL;		/* NULL is instead of GET_LOCAL_LH(ctx) to cause GPF on internal errors */

  cb_trace_start_tag (ctx, &data);
  my_pos = (long) ctx_bh->bh_length;
  tmp_box = start_tag_record (&data);
  xper_blob_append_box (ctx, tmp_box);
  tmp_index_attrs = ctx->xpc_index_attrs;
  ctx->xpc_index_attrs = 0;
  cb_trace_end_tag (ctx, my_pos, target);
  ctx->xpc_index_attrs = (int) tmp_index_attrs;
  if (NULL != pi_data)
    dk_free_box (ta.ta_value);
  dk_free_box (tmp_box);
  dk_free_box (( /*nonconst */ char *) (data.name));
}


void
cb_comment (void *userdata, const char * text)
{
  xper_ctx_t *ctx = (xper_ctx_t *) userdata;
  size_t len = strlen (text);
  size_t fulllen;
  unsigned char hdr[11];

  count_buffered_words (ctx);

/* First, data should be stored inside blob. */
  if (len <= 255)
    {
      hdr[0] = DV_XML_MARKUP;
      fulllen = len + 3;
      LONG_SET_NA (hdr + 1, fulllen);
      hdr[5] = XML_MKUP_COMMENT;
      hdr[6] = DV_SHORT_STRING_SERIAL;
      hdr[7] = (unsigned char) len;
      xper_blob_append_data (ctx, (const char *) hdr, 8);
    }
  else
    {
      hdr[0] = DV_XML_MARKUP;
      fulllen = len + 6;
      LONG_SET_NA (hdr + 1, fulllen);
      hdr[5] = XML_MKUP_COMMENT;
      hdr[6] = DV_STRING;
      LONG_SET_NA (hdr + 7, len);
      xper_blob_append_data (ctx, (const char *) hdr, 11);
    }
  xper_blob_append_data (ctx, text, len);
}


int
dtd_get_buffer_length (dtd_t * dtd)
{
  ecm_el_idx_t el_idx, el_no;
  id_hash_t *dict;
  char **dict_key;
  xml_def_4_entity_t **dict_entity;
  id_hash_iterator_t dict_hit;
  int len = 0;

  if (NULL != dtd->ed_puburi)
    len += 1 + (int) dv_string_size ((char *) (dtd->ed_puburi));
  if (NULL != dtd->ed_sysuri)
    len += 1 + (int) dv_string_size ((char *) (dtd->ed_sysuri));

  el_no = dtd->ed_el_no;
  for (el_idx = 0; el_idx < el_no; el_idx++)
    {
      ecm_el_t *el = dtd->ed_els + el_idx;
      if (el->ee_has_id_attr)
	{
	  ecm_attr_idx_t key_idx = el->ee_id_attr_idx;
	  len +=
	      1 /* type byte */  +
	      (int) dv_string_size ((char *) (el->ee_name)) +
	      (int) dv_string_size ((char *) (el->ee_attrs[key_idx].da_name));
	}
    }
  /* GE's processing */
  dict = dtd->ed_generics;
  if (NULL != dict)
    {
      for (id_hash_iterator (&dict_hit, dict);
	  hit_next (&dict_hit, (char **) (&dict_key), (char **) (&dict_entity));
      /*no step */ )
	{
	  char type_byte;
	  if (NULL == dict_entity[0]->xd4e_systemId)
	    continue;
	  type_byte = ((NULL != dict_entity[0]->xd4e_publicId) ? 'G' : 'g');
	  len += 1 /* type_byte */  + (int) dv_string_size (dict_key[0]) +
		  (int) dv_string_size (dict_entity[0]->xd4e_systemId);
	  if ('G' == type_byte)
	    len += (int) dv_string_size (dict_entity[0]->xd4e_publicId);
	}
    }
  if (0 == len)
    len = -1;
  dtd->ed_xper_text_length = len;
  return len;
}

void dtd_save_str_to_buffer (unsigned char **tail_ptr, char *str)
{
  unsigned char *tail = tail_ptr[0];
  size_t len = strlen (str);
  dtp_t tag = ((len > 255) ? DV_STRING : DV_SHORT_STRING_SERIAL);
  (tail++)[0] = tag;
  if (DV_SHORT_STRING_SERIAL == tag)
    {
      (tail++)[0] = ((unsigned char)len);
    }
  else
    {
      LONG_SET_NA (tail, len);
      tail += 4;
    }
  memcpy (tail, str, len);
  tail_ptr[0] = tail + len;
}

void dtd_save_to_buffer (dtd_t *dtd, unsigned char *buf, size_t buf_len)
{
  unsigned char *tail = buf;
  ecm_el_idx_t el_idx, el_no;
  id_hash_t *dict;
  char **dict_key;
  xml_def_4_entity_t **dict_entity;
  id_hash_iterator_t dict_hit;
/* Exactly the same logic as in dtd_get_buffer_length... */
  if (NULL != dtd->ed_puburi)
    {
      (tail++)[0] = 'U';
      dtd_save_str_to_buffer (&tail, dtd->ed_puburi);
    }
  if (NULL != dtd->ed_sysuri)
    {
      (tail++)[0] = 'u';
      dtd_save_str_to_buffer (&tail, dtd->ed_sysuri);
    }

  el_no = dtd->ed_el_no;
  for (el_idx = 0; el_idx < el_no; el_idx++)
    {
      ecm_el_t *el = dtd->ed_els + el_idx;
      if (el->ee_has_id_attr)
	{
	  ecm_attr_idx_t key_idx = el->ee_id_attr_idx;
	  (tail++)[0] = 'k';
	  dtd_save_str_to_buffer (&tail, el->ee_name);
	  dtd_save_str_to_buffer (&tail, el->ee_attrs[key_idx].da_name);
	}
    }

  /* GE's processing */
  dict = dtd->ed_generics;
  if (NULL != dict)
    {
      for (id_hash_iterator (&dict_hit, dict);
	  hit_next (&dict_hit, (char **) (&dict_key), (char **) (&dict_entity));
      /*no step */ )
	{
	  unsigned char type_byte;
	  if (NULL == dict_entity[0]->xd4e_systemId)
	    continue;
	  type_byte = ((NULL != dict_entity[0]->xd4e_publicId) ? 'G' : 'g');
	  (tail++)[0] = type_byte;
	  dtd_save_str_to_buffer (&tail, dict_key[0]);
	  dtd_save_str_to_buffer (&tail, dict_entity[0]->xd4e_systemId);
	  if ('G' == type_byte)
	    dtd_save_str_to_buffer (&tail, dict_entity[0]->xd4e_publicId);
	}
    }
  if (tail != buf+buf_len)
    GPF_T;
}


int
blob_append_dtd (xper_ctx_t * ctx, dtd_t * dtd)
{
/* Uncomment this for debugging:  blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh; */
  unsigned char *buf;
  int len = 0;
  len = dtd->ed_xper_text_length;
  if (0 == len)
    len = dtd_get_buffer_length (dtd);
  if (0 >= len)
    return 0;
  if (len <= 255)
    {
      unsigned char ccc[2];
      ccc[0] = DV_SHORT_STRING_SERIAL;
      ccc[1] = len;
      xper_blob_append_data (ctx, (const char *) ccc, 2);
    }
  else
    {
      unsigned char ccc[5];
      ccc[0] = DV_STRING;
      LONG_SET_NA (ccc + 1, len);
      xper_blob_append_data (ctx, (const char *) ccc, 5);
    }
  buf = (unsigned char *) dk_alloc (len);
  dtd_save_to_buffer (dtd, buf, len);
  xper_blob_append_data (ctx, (char *)buf, len);
  dk_free (buf, len);
  return 1;
}


void
xper_destroy_ctx (xper_ctx_t * ctx)
{
  while (NULL != ctx->xpc_cut_chain)
    dk_free_box ((box_t) dk_set_pop (&(ctx->xpc_cut_chain)));
  while (NULL != ctx->xpc_cut_namespaces)
    {
      xper_ns_t *curr_ns = (xper_ns_t *) (dk_set_pop (&(ctx->xpc_cut_namespaces)));
      dk_free_box (curr_ns->xpns_uri);
      dk_free (curr_ns, -1);
    }
  if ((NULL != ctx->xpc_itc) && (NULL != ctx->xpc_buf))
    {
      buf_set_dirty (ctx->xpc_buf);
      page_leave_outside_map (ctx->xpc_buf); /* This should be done before blob_chain_delete() below */
    }
  if (NULL != ctx->xpc_doc)
    {
      blob_handle_t *ctx_bh = ctx->xpc_doc->xpd_bh;
      if (NULL != ctx_bh)
	{
	  xper_blob_truncate_dir_buf (ctx_bh);
	  blob_chain_delete (ctx->xpc_itc, (blob_layout_t *) blob_layout_from_handle_ctor (ctx_bh));
	  bh_free (ctx_bh);
	  ctx->xpc_doc->xpd_bh = NULL;
	}
      XPER_FREE_XPD (ctx->xpc_doc);
      ctx->xpc_doc = NULL;
    }
  if (NULL != ctx->xpc_itc)
    {
      itc_free (ctx->xpc_itc);
      ctx->xpc_itc = NULL;
    }
  dk_set_free (ctx->xpc_poss);
  ctx->xpc_poss = NULL;
  if (0 != ctx->xpc_text_buf_size)
    {
      dk_free (ctx->xpc_text_buf, ctx->xpc_text_buf_size);
      ctx->xpc_text_buf_size = 0;
    }
  if (NULL != ctx->xpc_src_file)
    {
      fclose (ctx->xpc_src_file);
      ctx->xpc_src_file = NULL;
    }
  if (NULL != ctx->xpc_parser)
    {
      VXmlParserDestroy (ctx->xpc_parser);
      ctx->xpc_parser = NULL;
    }
  if (NULL != ctx->xpc_src_filename)
    {
      dk_free_box (ctx->xpc_src_filename);
      ctx->xpc_src_filename = NULL;
    }
}

static caddr_t
 DBG_NAME (get_tag_data) (DBG_PARAMS xper_entity_t * xpe, volatile long pos)
{
  volatile int pn;
  it_cursor_t *tmp_itc;
  index_tree_t * it;
  buffer_desc_t *buf = NULL;
  size_t len;
  caddr_t volatile box = NULL;
  dtp_t dtp;
  size_t i;
  char cbuf[4];
  int split = -1;

  tmp_itc =
    itc_create (NULL, xpe->xe_doc.xd->xd_qi->qi_trx);
  it = xpe->xe_doc.xpd->xpd_bh->bh_it;
  if (NULL != it)
    {
      itc_from_it (tmp_itc, it);
    }
  else
    {
      dbe_key_t* xper_key = sch_id_to_key (wi_inst.wi_schema, KI_COLS);
      itc_from (tmp_itc, xper_key);
    }
  ITC_FAIL (tmp_itc)
  {
    pn = pos / PAGE_DATA_SZ;
    buf = get_blob_page_for_read (tmp_itc, xpe->xe_doc.xpd, pn);

    if (NULL != buf)
      dtp = *(unsigned char *) (buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ);
    else
      dtp = DV_UNKNOWN;
    if (DV_XML_MARKUP != dtp && DV_SHORT_STRING_SERIAL != dtp && DV_STRING != dtp)
      {
	if (NULL != buf)
	  {
	    page_leave_outside_map (buf);
	    buf = NULL;
	  }
	itc_free (tmp_itc);
	if (box)
	  dk_free_box (box);
	sqlr_new_error ("XE000", "XP9A4", "Error while accessing XML_PERSISTENT: invalid record type %d", dtp);
      }

    pos++;
    if (0 == pos % PAGE_DATA_SZ)
      {
	page_leave_outside_map (buf);
	buf = NULL;
	pn++;
	buf = get_blob_page_for_read (tmp_itc, xpe->xe_doc.xpd, pn);
	ITC_LEAVE_MAPS (tmp_itc);
      }

    if (DV_SHORT_STRING_SERIAL == dtp)
      {
	len = *(unsigned char *) (buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ);
	++pos;
      }
    else
      {
	split = PAGE_DATA_SZ - (pos % PAGE_DATA_SZ);
	if (split >= 4)
	  len = LONG_REF_NA (buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ);
	else
	  {			/* the worst case - number is split between pages */
	    memcpy (cbuf, buf->bd_buffer + DP_DATA + PAGE_DATA_SZ - split, split);
	    page_leave_outside_map (buf);
	    buf = NULL;
	    pn++;
	    buf = get_blob_page_for_read (tmp_itc, xpe->xe_doc.xpd, pn);
	    memcpy (cbuf + split, buf->bd_buffer + DP_DATA, 4 - split);
	    len = LONG_REF_NA (cbuf);
	  }
	pos += 4;
        if (0 == len)
	  GPF_T;
      }
    box = DBG_NAME (dk_alloc_box) (DBG_ARGS len, dtp);
    for (i = 0; i < len;)
      {
	size_t cpsz = ((PAGE_DATA_SZ - pos % PAGE_DATA_SZ < len - i) ?
	    PAGE_DATA_SZ - pos % PAGE_DATA_SZ :
	    len - i);

	if (0 == pos % PAGE_DATA_SZ)
	  {
	    page_leave_outside_map (buf);
	    buf = NULL;
	    buf = get_blob_page_for_read (tmp_itc, xpe->xe_doc.xpd, ++pn);
	  }

	memcpy (box + i, buf->bd_buffer + DP_DATA + pos % PAGE_DATA_SZ, cpsz);

	pos += (long) cpsz;
	i += cpsz;
      }
    page_leave_outside_map (buf);
    buf = NULL;
  }
  ITC_FAILED
  {
    if (NULL != buf)
      page_leave_outside_map (buf);
    itc_free (tmp_itc);
    if (box)
      dk_free_box (box);
    sqlr_new_error ("XE000", "XP9A5", "Error while accessing XML_PERSISTENT");
  }
  END_FAIL (tmp_itc);

  itc_free (tmp_itc);

  return box;
}


#ifdef MALLOC_DEBUG
#define get_tag_data(XPE,POS) dbg_get_tag_data (__FILE__, __LINE__, (XPE), (POS))
#endif


caddr_t
DBG_NAME(xper_get_namespace) (DBG_PARAMS xper_entity_t * xpe, long pos)
{
  caddr_t tmp, res;
  if (!pos)
    return NULL;

  /* TBD - namespace caching by pos */
  tmp = DBG_NAME(get_tag_data) (DBG_ARGS xpe, pos);
  res = box_dv_uname_nchars (tmp, box_length (tmp));
  dk_free_box (tmp);
  return res;
}

/* IvAn/XperTrav/000825 Function has rewritten to support all types of entities */
static void
fill_xper_entity (xper_entity_t * xpe, long pos)
{
  long len;
  unsigned char *ptr;
  caddr_t tmp_box;
  int namelen;
  dtp_t dtp;
  char *buf1, *buf2;
  long buf1len, buf1use, buf2len;

  tmp_box = get_tag_data (xpe, pos);
  xpe->xper_pos = pos;		/* moved here from get_tag_data */

  if (xpe->xper_name)
    dk_free_box (xpe->xper_name);
  xpe->xper_name = NULL;
  if (NULL != xpe->xper_text)
    dk_free_box (xpe->xper_text);
  xpe->xper_text = NULL;

  dtp = DV_TYPE_OF (tmp_box);
  len = box_length (tmp_box);

  if (DV_SHORT_STRING_SERIAL == dtp || DV_STRING == dtp)
    {
      xpe->xper_type = XML_MKUP_TEXT;
      buf1len = ((len > 900) ? 0x1000 : len);
      buf1 = (char *) dk_alloc (buf1len);
      buf1use = 0;
      do
	{
	  if (buf1use + len > buf1len)
	    {
	      buf2len = buf1len + len;
	      if (buf2len > 10000000)
		{
		  dk_free_box (tmp_box);
		  sqlr_new_error ("XE000", "XP9A9", "XML contains abnormally long text data");
		}
	      buf2len *= 2;
	      if (buf2len > 10000000)
		buf2len = 10000000;
	      buf2 = (char *) dk_alloc (buf2len);
	      memcpy (buf2, buf1, buf1use);
	      dk_free (buf1, buf1len);
	      buf1 = buf2;
	      buf1len = buf2len;
	    }
	  memcpy (buf1 + buf1use, tmp_box, len);
	  buf1use += len;
	  pos += len + ((DV_SHORT_STRING_SERIAL == dtp) ? 2 : 5);
	  dk_free_box (tmp_box);
	  tmp_box = get_tag_data (xpe, pos);
	  dtp = DV_TYPE_OF (tmp_box);
	  len = box_length (tmp_box);
	}
      while ((DV_SHORT_STRING_SERIAL == dtp) || (DV_STRING == dtp));
      xpe->xper_text = dk_alloc_box (buf1use, DV_STRING);
      memcpy (xpe->xper_text, buf1, buf1use);
      dk_free (buf1, buf1len);
      /* \c xpe->xper_parent and \c xpe->xper_left should be filled by caller */
      xpe->xper_right = ((XML_MKUP_ETAG == tmp_box[0]) ? 0 : pos);
      xpe->xper_end = 0;
      xpe->xper_first_child = 0;
      /* \c xpe->xper_start_word and \c xpe->xper_end_word should be filled by caller */
      xpe->xper_next_item = pos;
      dk_free_box (tmp_box);
      return;
    }

  ptr = (unsigned char *) tmp_box;
  xpe->xper_type = *ptr++;

  switch (xpe->xper_type)
    {
    case XML_MKUP_STAG:
    case XML_MKUP_PI:
    case XML_MKUP_REF:
      if (DV_STRING == ptr[0])
	{
	  namelen = LONG_REF_NA (ptr + 1);
	  ptr += 5;
	}
      else
	{
	  namelen = ptr[1];
	  ptr += 2;
	}
      xpe->xper_name = box_dv_uname_nchars ((char *)ptr, namelen);
      ptr += namelen;
      xpe->xper_parent = LONG_REF_NA (ptr + STR_PARENT_OFF);
      xpe->xper_left = LONG_REF_NA (ptr + STR_LEFT_SIBLING_OFF);
      xpe->xper_right = LONG_REF_NA (ptr + STR_RIGHT_SIBLING_OFF);
      xpe->xper_end = LONG_REF_NA (ptr + STR_END_TAG_OFF);
      xpe->xper_first_child = LONG_REF_NA (ptr + STR_FIRST_CHILD_OFF);
/* IvAn/TextXperIndex/000815 Word counter added */
      xpe->xper_start_word = LONG_REF_NA (ptr + STR_START_WORD_OFF);
      xpe->xper_end_word = LONG_REF_NA (ptr + STR_END_WORD_OFF);
      xpe->xper_ns_pos = LONG_REF_NA (ptr + STR_NS_OFF);
      xpe->xper_next_item = pos + 5 + len;
      break;
    case XML_MKUP_ETAG:
      if (DV_STRING == ptr[0])
	{
	  namelen = LONG_REF_NA (ptr + 1);
	  ptr += 5;
	}
      else
	{
	  namelen = ptr[1];
	  ptr += 2;
	}
      xpe->xper_name = box_dv_uname_nchars ((char *)ptr, namelen);
      xpe->xper_next_item = pos + 5 + len;
      break;
    case XML_MKUP_COMMENT:
      if (DV_STRING == ptr[0])
	{
	  namelen = LONG_REF_NA (ptr + 1);
	  ptr += 5;
	}
      else
	{
	  namelen = ptr[1];
	  ptr += 2;
	}
      xpe->xper_name = box_dv_short_nchars ((char *)ptr, namelen);
      pos += 5 + len;
      xpe->xper_next_item = pos;
      dk_free_box (tmp_box);
      tmp_box = get_tag_data (xpe, pos);
      dtp = DV_TYPE_OF (tmp_box);
      if ((DV_SHORT_STRING_SERIAL == dtp) || (DV_STRING == dtp) || (XML_MKUP_ETAG != tmp_box[0]))
	xpe->xper_right = pos;
      else
	xpe->xper_right = 0;
      break;
    default:
      dk_free_box (tmp_box);
      sqlr_new_error ("XE000", "XP9AA", "Persistent XML BLOB is invalid");
    }
  dk_free_box (tmp_box);
}


xml_entity_t *
xp_reference (query_instance_t * qi, caddr_t base, caddr_t ref,
    xml_doc_t * from_doc, caddr_t * err_ret)
{
  xper_entity_t *xpe;
  dtd_t **xpe_dtd_ptr;
  caddr_t str;
  caddr_t err = NULL;
  caddr_t path = xml_uri_resolve (qi, &err, base, ref, "UTF-8");
  xml_doc_t * top_doc = from_doc->xd_top_doc;
  if (err)
    {
      dk_free_box (path);
      if (NULL == err_ret)
	sqlr_resignal (err);
      err_ret[0] = err;
      return NULL;
    }

  DO_SET (xml_entity_t *, ref_ent, &top_doc->xd_referenced_entities)
  {
    if (NULL != ref_ent->xe_doc.xd->xd_uri
	&& 0 == strcmp (ref_ent->xe_doc.xpd->xd_uri, path))
      {
	dk_free_box (path);
	return ref_ent;
      }
  }
  END_DO_SET ();
  str = xml_uri_get (qi, &err, NULL, base, ref, XML_URI_ANY);
  if (DV_XML_ENTITY == DV_TYPE_OF (str))
    {
      xpe = (xper_entity_t *)str; /* This is actually not quite correct, it can be XmlTree but no XPER-specific things are used */
      goto xpe_is_ready; /* see below */
    }
  if (err)
    {
      dk_free_box (path);
      if (NULL == err_ret)
	sqlr_resignal (err);
      err_ret[0] = err;
      return NULL;
    }
  xpe = xper_entity (qi, str, NULL, GE_XML, path, NULL, server_default_lh, NULL, 0);
  xpe_dtd_ptr = &(xpe->xe_doc.xd->xd_dtd);
  if (NULL != from_doc->xd_dtd)
    {
      dtd_addref (from_doc->xd_dtd, 0);
      if (NULL != xpe_dtd_ptr[0])
	dtd_release (xpe_dtd_ptr[0]);
      xpe_dtd_ptr[0] = from_doc->xd_dtd;
      dk_free_box ((caddr_t) (xpe->xe_doc.xd->xd_id_dict));
      dk_free_box (xpe->xe_doc.xd->xd_id_scan);
      xpe->xe_doc.xd->xd_id_dict = NULL;
      xpe->xe_doc.xd->xd_id_scan = NULL;
    }

xpe_is_ready:
  XD_DOM_LOCK(xpe->xe_doc.xd);
  dk_set_push (&top_doc->xd_referenced_entities, (void *) xpe);
  xpe->xe_doc.xpd->xd_top_doc = top_doc;
  top_doc->xd_weight += xpe->xe_doc.xd->xd_weight;
  top_doc->xd_cost += xpe->xe_doc.xd->xd_cost;
  if (top_doc->xd_cost > XML_MAX_DOC_COST)
    top_doc->xd_cost = XML_MAX_DOC_COST;
  return ((xml_entity_t *) (xpe));
}

int
xp_element_name_test (xml_entity_t * xe, XT * node)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  caddr_t ns;
  size_t nslen, len;
  unsigned char *name, *colon;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (node))
    {
      switch ((ptrlong) node)
	{
	case XP_TEXT:
	  return XML_MKUP_TEXT == xpe->xper_type;
	case XP_COMMENT:
	  return XML_MKUP_COMMENT == xpe->xper_type;
	case XP_PI:
	  return XML_MKUP_PI == xpe->xper_type;
	case XP_NODE:
	  return 1;
	case XP_ELT:
	  return ((XML_MKUP_STAG == xpe->xper_type) && (XPER_ROOT_POS != xpe->xper_pos));
	case XP_ELT_OR_ROOT:
	  return (XML_MKUP_STAG == xpe->xper_type);
	}
      GPF_T;
      return 0;
    }
  if (XML_MKUP_STAG != xpe->xper_type)
    return 0;
  name = (unsigned char *) (xpe->xper_name);
  if (!name || (' ' == name[0]))
    return 0;
  if (!((XP_NAME_LOCAL == node->type) && (NULL == node->_.name_test.nsuri)))
    {
      long nspos;
      caddr_t tmp_box;
      unsigned char *tail;
      tmp_box = get_tag_data (xpe, xpe->xper_pos);
      tail = (unsigned char *) (tmp_box) + 1 + dv_string_size (xpe->xper_name) + STR_NS_OFF;
      nspos = LONG_REF_NA (tail);
      dk_free_box (tmp_box);
      if (0 == nspos)
        {
	  ns = NULL;
	  nslen = 0;
        }
      else
	{
	  ns = xper_get_namespace (xpe, nspos);
	  nslen = box_length_inline (ns) - 1;
          if (0 == nslen)
            ns = NULL;
	}
    }
  else
    {
      ns = NULL;
      nslen = 0;
    }
  if (XP_NAME_NSURI == node->type)
    {
      /* test is ns.* */
      if (!ns)
	goto ret0;
      if ((nslen == box_length (node->_.name_test.nsuri) - 1) &&
	  (0 == memcmp (ns, node->_.name_test.nsuri, nslen)) )
	goto ret1;
      else
	goto ret0;
    }
  len = box_length (name) - 1;
  colon = name + len;
  for (;;)
    {
      if (colon == name)
	{
	  colon = NULL;
	  break;
	}
      colon--;
      if (':' == colon[0])
	break;
    }
  if (colon)
    {
      len -= (colon - name) + 1;
      name = colon + 1;
    }
  if (NULL == node->_.name_test.nsuri)
    {
      /* test is name w/o ns */
      if (((size_t) (len) == box_length_inline (node->_.name_test.local) - 1) &&
	  (0 == memcmp (node->_.name_test.local, name, len)) )
	goto ret1;
      else
	goto ret0;
    }
  /* test with namespace */
  if (!ns)
    goto ret0;
  if (((size_t) (len) != box_length_inline (node->_.name_test.local) - 1) ||
    (0 != memcmp (node->_.name_test.local, name, len)) )
    goto ret0;
  if (XP_NAME_LOCAL == node->type)
    goto ret1;
  if ((nslen == box_length (node->_.name_test.nsuri) - 1) &&
    (0 == memcmp (ns, node->_.name_test.nsuri, nslen)) )
    goto ret1;
  goto ret0;
ret1:
  dk_free_box (ns);
  return 1;
ret0:
  dk_free_box (ns);
  return 0;
}


int
xp_ent_name_test (xml_entity_t * xe, XT * node)
{
  if (NULL != xe->xe_attr_name)
    return xt_node_test_match (node, xe->xe_attr_name);
  return xp_element_name_test (xe, node);
}

int
xper_node_test (xper_entity_t * xpe, long pos, XT * node)
{
  long len;
  unsigned char *ptr;
  caddr_t tmp_box;
  int namelen;
  int res;
  char type;
  long save;

  if ((XT *) XP_NODE == node)
    return 1;
  tmp_box = get_tag_data (xpe, pos);
  if (DV_XML_MARKUP != DV_TYPE_OF (tmp_box))
    {
      dk_free_box (tmp_box);
      return (((XT *) XP_TEXT == node) ? 1 : 0);
    }
  len = box_length (tmp_box);
  ptr = (unsigned char *) tmp_box;
  type = ptr[0];
  ++ptr;

  namelen = (int) skip_string_length (&ptr);

  switch (type)
    {
    case XML_MKUP_REF:
#ifdef DEBUG
      GPF_T;
#endif
      dk_free_box (tmp_box);
      return 0;
    case XML_MKUP_COMMENT:
      res = ((XP_COMMENT == (ptrlong)node) || (XP_NODE == (ptrlong)node));
      dk_free_box (tmp_box);
      return res;
    default:
      save = xpe->xper_pos;
      fill_xper_entity (xpe, pos);
      res = xp_ent_name_test ((xml_entity_t *) (xpe), node);
      fill_xper_entity (xpe, save);
      dk_free_box (tmp_box);
      return res;
    }
}

int
xp_ent_node_test (xml_entity_t * xe, XT * node)
{
  return xper_node_test ((xper_entity_t *) xe, ((xper_entity_t *) xe)->xper_pos, node);
}

caddr_t
bif_xml_persistent (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  caddr_t source = bif_arg (qst, args, 0, "xml_persistent");
  int argc = BOX_ELEMENTS (args);
  caddr_t path = ((argc > 1) ? bif_string_arg (qst, args, 1, "xml_persistent") : NULL);
  lang_handler_t *lh = ((argc > 2) ? lh_get_handler (bif_string_arg (qst, args, 2, "xml_persistent")) : server_default_lh);
  caddr_t dtd_config = ((argc > 3) ? bif_array_or_null_arg (qst, args, 3, "xml_persistent") : NULL);
  int index_attrs = ((argc > 4) ? (int) bif_long_arg (qst, args, 4, "xml_persistent") : 1);
  if (!cl_run_local_only)
    sqlr_new_error ("42000", "CLXML", "xml_persistent is deprecated in cluster.  Use xtree_doc instead.");
  res =
      (caddr_t) xper_entity ((query_instance_t *) QST_INSTANCE (qst), source,
      NULL, 0, box_copy (path), NULL, lh, dtd_config, index_attrs);
  return res;
}

caddr_t
bif_xper_doc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  caddr_t source = bif_arg (qst, args, 0, "xper_doc");
  int argc = BOX_ELEMENTS (args);
  int parser_mode = ((argc > 1) ? (int) bif_long_arg (qst, args, 1, "xper_doc") : 0);
  caddr_t path = ((argc > 2) ? bif_string_arg (qst, args, 2, "xper_doc") : NULL);
  caddr_t enc = ((argc > 3) ? bif_string_arg (qst, args, 3, "xper_doc") : NULL);
  lang_handler_t *lh = ((argc > 4) ? lh_get_handler (bif_string_arg (qst, args, 4, "xper_doc")) : server_default_lh);
  caddr_t dtd_config = ((argc > 5) ? bif_array_or_null_arg (qst, args, 5, "xper_doc") : NULL);
  int index_attrs = ((argc > 6) ? (int) bif_long_arg (qst, args, 6, "xper_doc") : 1);
  res =
      (caddr_t) xper_entity ((query_instance_t *) QST_INSTANCE (qst), source,
      NULL, parser_mode, box_copy (path), enc, lh, dtd_config, index_attrs);
  return res;
}


size_t
file_read (void *read_cd, char *buf, size_t bsize)
{
  FILE *file = (FILE *) read_cd;
  return fread (buf, 1, bsize, file);
}


#ifdef XMLPARSER_FEED_DEBUG
static FILE *feed_log = NULL;
#endif

void
dsfi_reset (dk_session_fwd_iter_t * iter, dk_session_t * ses)
{
  iter->dsfi_dorigin = ses;
  iter->dsfi_buffer = ses->dks_buffer_chain;
  iter->dsfi_offset = 0;
  if (ses->dks_session->ses_file->ses_file_descriptor)
    iter->dsfi_file_len = ses->dks_session->ses_file->ses_fd_fill_chars;
  else
    iter->dsfi_file_len = 0;
  iter->dsfi_file_offset = 0;
#ifdef XMLPARSER_FEED_DEBUG
  feed_log = fopen("feed_log", "wb");
#endif
}

extern long read_wides_from_utf8_file (dk_session_t *ses, long nchars, unsigned char *dest, int copy_as_utf8, unsigned char **dest_ptr_out);


size_t
dsfi_read (void *read_cd, char *buf, size_t bsize)
{
#ifdef XMLPARSER_FEED_DEBUG
  char *buf_orig = buf;
  size_t bsize_orig = bsize;
#endif
  dk_session_fwd_iter_t *iter = (dk_session_fwd_iter_t *) read_cd;
  size_t res = 0;
  size_t rest_len;
  dk_session_t *ses = iter->dsfi_dorigin;
  while (NULL != iter->dsfi_buffer)
    {
      rest_len = iter->dsfi_buffer->fill - iter->dsfi_offset;
      if (bsize <= rest_len)
	{
	  memcpy (buf, iter->dsfi_buffer->data + iter->dsfi_offset, bsize);
	  iter->dsfi_offset += bsize;
	  res += bsize;
	  goto done;
	}
      memcpy (buf, iter->dsfi_buffer->data + iter->dsfi_offset, rest_len);
      iter->dsfi_offset = 0;
      iter->dsfi_buffer = iter->dsfi_buffer->next;
      buf += rest_len;
      res += rest_len;
      bsize -= rest_len;
    }
  if (iter->dsfi_file_offset < iter->dsfi_file_len)
    {
      int readed;
      if (-1 == strf_lseek (ses->dks_session->ses_file, iter->dsfi_file_offset, SEEK_SET))
	{
	  log_error ("Can't seek in file %s", ses->dks_session->ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  goto done;
	}
      if (strses_is_utf8 (ses))
        {
          readed = read_wides_from_utf8_file (ses, bsize/sizeof (wchar_t), (utf8char *)buf, 0, NULL);
          if (readed < 0) /* log_error is called inside read_wides_from_utf8_file() */
            goto done;
          iter->dsfi_file_offset = strf_lseek (ses->dks_session->ses_file, 0L, SEEK_CUR);
          readed *= sizeof (wchar_t);
        }
      else
        {
	  readed = strf_read (ses->dks_session->ses_file, buf, MIN (bsize, iter->dsfi_file_len - iter->dsfi_file_offset));
	  if (readed == -1)
	    {
	      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	      log_error ("Can't read from file %s", ses->dks_session->ses_file->ses_temp_file_name);
	      goto done;
	    }
          iter->dsfi_file_offset += readed;
        }
      buf += readed;
      res += readed;
      bsize -= readed;
    }
  if (bsize == 0)
    goto done;
  rest_len = iter->dsfi_dorigin->dks_out_fill - iter->dsfi_offset;
  if (bsize > rest_len)
    bsize = rest_len;
  memcpy (buf, iter->dsfi_dorigin->dks_out_buffer + iter->dsfi_offset, bsize);
  iter->dsfi_offset += bsize;
  res += bsize;

done:
#ifdef XMLPARSER_FEED_DEBUG
  if (res > bsize_orig)
    GPF_T;
  if (buf + bsize > buf_orig + bsize_orig)
    GPF_T;
  if (0 == res)
    fclose (feed_log);
  else
    fwrite (buf_orig, res, 1, feed_log);
#endif
  return res;
}


void
bcfi_reset (bh_from_client_fwd_iter_t * iter, blob_handle_t *bh, client_connection_t *cli)
{
  iter->bcfi_bh = bh;
  iter->bcfi_cli = cli;
}


size_t
bcfi_read (void *read_cd, char *buf, size_t bsize)
{
  bh_from_client_fwd_iter_t *iter = (bh_from_client_fwd_iter_t *)read_cd;
  if ((BLOB_ALL_RECEIVED == iter->bcfi_bh->bh_all_received) ||
    (BLOB_NULL_RECEIVED == iter->bcfi_bh->bh_all_received) )
    return 0;
  return bh_get_data_from_user (iter->bcfi_bh, iter->bcfi_cli, (db_buf_t)buf, bsize);
}


extern void bcfi_abend (void *read_cd)
{
  caddr_t tmp_buf = dk_alloc (16 * 8192);
  while (0 != bcfi_read (read_cd, tmp_buf, 16 * 8192)) {}
}


void
bdfi_reset (bh_from_disk_fwd_iter_t * iter, blob_handle_t *bh, query_instance_t *qi)
{
  iter->bdfi_bh = bh;
  iter->bdfi_qi = qi;
  iter->bdfi_page_idx = 0;
  iter->bdfi_page_data_pos = 0;
  iter->bdfi_total_pos = 0;
}


size_t
bdfi_read (void *read_cd, char *tgtbuf, size_t bsize)
{
  bh_from_disk_fwd_iter_t *iter = (bh_from_disk_fwd_iter_t *)read_cd;
  it_cursor_t *tmp_itc;
  index_tree_t * it;
  buffer_desc_t *buf = NULL;
  size_t res = 0;
  if (iter->bdfi_total_pos >= iter->bdfi_bh->bh_diskbytes)
    return 0;
  tmp_itc = itc_create (NULL, iter->bdfi_qi->qi_trx);
  it = iter->bdfi_bh->bh_it;
  if (NULL != it)
    {
      itc_from_it (tmp_itc, it);
    }
  else
    {
      dbe_key_t* xper_key = sch_id_to_key (wi_inst.wi_schema, KI_COLS);
      itc_from (tmp_itc, xper_key);
    }
  ITC_FAIL (tmp_itc)
  {
    dp_addr_t nth_page;
    if (!iter->bdfi_bh->bh_page_dir_complete)
      blob_read_dir (tmp_itc, &iter->bdfi_bh->bh_pages, &iter->bdfi_bh->bh_page_dir_complete, iter->bdfi_bh->bh_dir_page, NULL);

get_more:
    nth_page = iter->bdfi_bh->bh_pages[iter->bdfi_page_idx];
    if (!page_wait_blob_access (tmp_itc, nth_page, &buf, PA_READ, iter->bdfi_bh, 1))
      {
        iter->bdfi_total_pos = iter->bdfi_bh->bh_diskbytes;
      }
    else
      {
        long len = LONG_REF (buf->bd_buffer + DP_BLOB_LEN);
        const char * oldstart = (char *)(buf->bd_buffer + DP_DATA + iter->bdfi_page_data_pos);
        if (DV_BLOB_WIDE_HANDLE == DV_TYPE_OF (iter->bdfi_bh))
          {
            const char * start = oldstart;
            int dec = eh_decode_buffer__UTF8 ((unichar *)tgtbuf, bsize / sizeof(unichar), &start, (const char *)(buf->bd_buffer + DP_DATA + len));
            if (dec < 0)
              {
	        log_info ("UTF-8 encoding error (%d) in wide-char blob dp = %d start = %d.", dec, nth_page, iter->bdfi_bh->bh_page);
	        iter->bdfi_total_pos = iter->bdfi_bh->bh_diskbytes;
	      }
            else
              {
	        iter->bdfi_page_data_pos += (start-oldstart);
		iter->bdfi_total_pos += (start-oldstart);
	        dec *= sizeof (unichar);
	        res += dec;
	        tgtbuf += dec;
	        bsize -= dec;
	      }
          }
        else
          {
	    size_t got = len - iter->bdfi_page_data_pos;
	    if (got > bsize)
	      got = bsize;
	    memcpy (tgtbuf, oldstart, got);
	    iter->bdfi_page_data_pos += got;
	    iter->bdfi_total_pos += got;
	    res += got;
	    tgtbuf += got;
	    bsize -= got;
          }
        if (iter->bdfi_page_data_pos == len)
          {
            iter->bdfi_page_idx++;
            iter->bdfi_page_data_pos = 0;
	  }
#ifdef DEBUG
        if (iter->bdfi_page_data_pos > len)
          GPF_T;
	if (iter->bdfi_total_pos > iter->bdfi_bh->bh_diskbytes)
          GPF_T;
#endif
      }
    if (NULL != buf)
      page_leave_outside_map (buf);
    buf = NULL;
    ITC_LEAVE_MAPS (tmp_itc);
    if (bsize && (iter->bdfi_total_pos < iter->bdfi_bh->bh_diskbytes))
      goto get_more; /* see above */
  }
  ITC_FAILED
  {
    if (NULL != buf)
      page_leave_outside_map (buf);
    itc_free (tmp_itc);
    sqlr_new_error ("XE000", "XP9A5", "Error while reading XML from BLOB");
  }
  END_FAIL (tmp_itc);
  itc_free (tmp_itc);
  return res;
}


int
str_looks_like_serialized_xml (caddr_t source)
{
  int slen = box_length (source);
  if (IS_WIDE_STRING_DTP (box_tag (source)))
    return XE_PLAIN_TEXT;
  if (0 == strncmp (source, XPACK_PREFIX, XPER_ROOT_POS))
    return XE_XPACK_SERIALIZATION;
  if ((slen >= XPER_ROOT_POS + MIN_START_ROOT_RECORD_SZ + END_ROOT_RECORD_SZ) &&
      (0 == strncmp (source, XPER_PREFIX, XPER_ROOT_POS)) &&
      (slen <= PAGE_DATA_SZ) )
    return XE_XPER_SERIALIZATION;
  if ((slen > 3) && (DV_ARRAY_OF_POINTER == ((dtp_t *)source)[0]) &&
    ((DV_LONG_INT == ((dtp_t *)source)[1]) || (DV_SHORT_INT == ((dtp_t *)source)[1])) )
    return XE_PLAIN_TEXT_OR_SERIALIZED_VECTOR;
  return XE_PLAIN_TEXT;
}


int
strses_looks_like_serialized_xml (dk_session_t *source)
{
  int slen = strses_length (source);
  char buf[XPER_ROOT_POS];
  strses_fragment_to_array (source, buf, 0, XPER_ROOT_POS);
  if (IS_WIDE_STRING_DTP (box_tag (source)))
    return XE_PLAIN_TEXT;
  if ((slen >= XPER_ROOT_POS) && (0 == memcmp (buf, XPACK_PREFIX, XPER_ROOT_POS)))
    return XE_XPACK_SERIALIZATION;
  if ((slen >= XPER_ROOT_POS + MIN_START_ROOT_RECORD_SZ + END_ROOT_RECORD_SZ) &&
      (0 == memcmp (buf, XPER_PREFIX, XPER_ROOT_POS)) &&
      (slen <= PAGE_DATA_SZ) )
    return XE_XPER_SERIALIZATION;
  if ((slen > 3) && (DV_ARRAY_OF_POINTER == ((dtp_t *)source)[0]) &&
    ((DV_LONG_INT == ((dtp_t *)source)[1]) || (DV_SHORT_INT == ((dtp_t *)source)[1])) )
    return XE_PLAIN_TEXT_OR_SERIALIZED_VECTOR;
  return XE_PLAIN_TEXT;
}


/* IvAn/TextXperIndex/000815 Special case for blob checking has turned into separate function */
int
blob_looks_like_serialized_xml (query_instance_t * qi, blob_handle_t * bh)
{
  volatile int res = 0;
  it_cursor_t *itc;
  buffer_desc_t *buf = NULL;
  unsigned char *ptr;

  xper_dbg_print ("Checking if a BLOB is a PERSISTENT XML.\n");

  if (DV_BLOB_XPER_HANDLE == box_tag (bh))
    return XE_XPER_SERIALIZATION;

  if (DV_BLOB_WIDE_HANDLE == box_tag (bh))
    return XE_PLAIN_TEXT;

  if (bh->bh_length < XPER_ROOT_POS)
    return XE_PLAIN_TEXT;

  itc = itc_create (NULL, qi->qi_trx);
  itc_from_it (itc, bh->bh_it);

  ITC_FAIL (itc)
  {
    if (!page_wait_blob_access (itc, bh->bh_page, &buf, PA_READ, bh, 1))
      {
	return XE_PLAIN_TEXT;
      }
    ptr = buf->bd_buffer + DP_DATA;
    if ((bh->bh_length >= XPER_ROOT_POS + MIN_START_ROOT_RECORD_SZ + END_ROOT_RECORD_SZ) &&
        (0 == strncmp ((const char *) ptr, XPER_PREFIX, XPER_ROOT_POS) &&
        DV_XML_MARKUP == ptr[XPER_ROOT_POS]) )
      res = XE_XPER_SERIALIZATION;
    else if (0 == strncmp ((const char *) ptr, XPACK_PREFIX, XPER_ROOT_POS))
      res = XE_XPACK_SERIALIZATION;
    else if ((bh->bh_length > 3) && (DV_ARRAY_OF_POINTER == ((dtp_t *)ptr)[0]) &&
      ((DV_LONG_INT == ((dtp_t *)ptr)[1]) || (DV_SHORT_INT == ((dtp_t *)ptr)[1])) )
      res = XE_PLAIN_TEXT_OR_SERIALIZED_VECTOR;
    else
      res = XE_PLAIN_TEXT;
    page_leave_outside_map (buf);
    buf = NULL;
    ITC_LEAVE_MAPS (itc);
  }
  ITC_FAILED
  {
    if (NULL != buf)
      page_leave_outside_map (buf);
    ITC_LEAVE_MAPS (itc);
    itc_free (itc);
    sqlr_new_error ("XE000", "XP9A6", "ITC error while checking persistent XML");
  }
  END_FAIL (itc);

  itc_free (itc);

  return res;
}

int
looks_like_serialized_xml (query_instance_t * qi, caddr_t source)
{
  dtp_t dtp_of_source = DV_TYPE_OF (source);
  if (DV_XML_ENTITY == dtp_of_source)
    return XE_ENTITY_READY;
  if (DV_STRINGP (source))
    return str_looks_like_serialized_xml (source);
  if (DV_STRING_SESSION == dtp_of_source)
    return strses_looks_like_serialized_xml ((dk_session_t *)source);
  if (IS_BLOB_HANDLE_DTP (dtp_of_source))
    return blob_looks_like_serialized_xml (qi, (blob_handle_t *) source);
  return XE_PLAIN_TEXT;
}


static void xper_get_blob_page_dir (xper_doc_t *xpd)
{
  it_cursor_t *tmp_itc;
  index_tree_t * it;
  blob_handle_t * bh = xpd->xpd_bh;
  if (bh->bh_page_dir_complete)
    return;
  tmp_itc =
    itc_create (NULL, xpd->xd_qi->qi_trx);
  it = xpd->xpd_bh->bh_it;
  if (NULL != it)
    {
      itc_from_it (tmp_itc, it);
    }
  else
    {
      dbe_key_t* xper_key = sch_id_to_key (wi_inst.wi_schema, KI_COLS);
      itc_from (tmp_itc, xper_key);
    }
  blob_read_dir (tmp_itc, &bh->bh_pages, &bh->bh_page_dir_complete, bh->bh_dir_page, NULL);
  itc_free (tmp_itc);
}

/* IvAn/TextXmlIndex/000814 Like bif_xml_tree, xper_entity should accept
   BLOBs with source XML like texts. */
xper_entity_t *
 DBG_NAME (xper_entity) (DBG_PARAMS query_instance_t * qi, caddr_t source_arg, caddr_t vt_batch,
    int is_html, caddr_t uri, caddr_t enc_name, lang_handler_t * lh, caddr_t dtd_config, int index_attrs)
{
  dtp_t dtp_of_source_arg = DV_TYPE_OF (source_arg);
  int source_sort = -1; /* An invalid value, just to kill the warning */
  bh_from_client_fwd_iter_t bcfi;
  bh_from_disk_fwd_iter_t bdfi;
  dk_session_fwd_iter_t dsfi;
  xml_read_func_t iter = NULL;
  xml_read_abend_func_t iter_abend = NULL;
  void *iter_data = NULL;
  xper_doc_t *xpd;
  buffer_desc_t *buf;
  xper_entity_t *xpe;
  volatile int rc = 1;
  caddr_t rc_msg = NULL;
  volatile s_size_t source_length = 0;
  vxml_parser_config_t config;
  xper_ctx_t context;
  volatile char source_type = '?';
  volatile int source_is_wide = 0;
  caddr_t tmp_box;
  xper_stag_t root_data;
  vxml_parser_attrdata_t root_attrdata;
  long pos;

  xpd = (xper_doc_t *) DK_ALLOC (sizeof (xper_doc_t));
  memset (xpd, 0, sizeof (xper_doc_t));
#ifdef MALLOC_DEBUG
  xpd->xd_dbg_file = (char *) file;
  xpd->xd_dbg_line = line;
#endif
  xpd->xd_qi = qi_top_qi (qi);
  xpd->xd_ref_count = 0;
  xpd->xd_default_lh = lh;

  memset (&context, 0, sizeof (context));

/* IvAn/DvBlobXper/001212 XPER support has changed */
  if (dtp_of_source_arg == DV_XML_ENTITY)
    {
      caddr_t original_uri;
      lang_handler_t *original_lh;
      if (XE_IS_TREE (source_arg))
	{
	  dk_free (xpd, sizeof (xper_doc_t));
	  dk_free_box (uri);
	  sqlr_new_error ("42000", "XE001",
	      "xml_persistent cannot convert XML tree entity (as argument 1) to XPER entity");
	}
      xper_dbg_print ("XPER here!\n");
      original_uri = ((xml_entity_t *) source_arg)->xe_doc.xd->xd_uri;
      original_lh = ((xml_entity_t *) source_arg)->xe_doc.xd->xd_default_lh;
      if (
	  (lh != original_lh) ||
	  strcmp (((NULL == uri) ? "" : uri), ((NULL == original_uri) ? "" : original_uri)))
	{			/* If base URI's differ, we should create new document to carry new path */
	  xpd->xpd_bh = (blob_handle_t *) box_copy_tree ((box_t) ((xml_entity_t *) source_arg)->xe_doc.xpd->xpd_bh);
	  xpd->xpd_state = XPD_PERSISTENT;
	  xpe = (xper_entity_t *) dk_alloc_box_zero (sizeof (xml_entity_un_t), DV_XML_ENTITY);
#ifdef XPER_DEBUG
	  xper_entity_alloc_ctr++;
#endif
	  xpe->_ = &xec_xper_xe;
	  xpe->xe_doc.xpd = xpd;
	  xpd->xd_top_doc = (xml_doc_t *) xpd;
	  xpd->xd_uri = uri;
	  xpd->xd_default_lh = lh;
	  xpd->xd_ref_count = 1;
	  fill_xper_entity (xpe, ((xper_entity_t *) source_arg)->xper_pos);
	}
      else
	{			/* If base URI's are equal for both source and the result, then plain entity copying is OK */
	  dk_free (xpd, sizeof (xper_doc_t));
	  dk_free_box (uri);
	  xpe = (xper_entity_t *) xp_copy ((xml_entity_t *) source_arg);
	}
      return xpe;
    }
#ifdef DV_BLOB_XPER_HANDLE
  if (dtp_of_source_arg == DV_BLOB_XPER_HANDLE)
    {
      blob_handle_t *bh = (blob_handle_t *) box_copy_tree (source_arg);
      xpd->xpd_bh = bh;
      xper_get_blob_page_dir (xpd);
      xpd->xpd_state = XPD_PERSISTENT;
      xper_dbg_print ("XPER BLOB handle here!\n");
      goto create_and_return_xpe;
    }
#endif
  if (dtp_of_source_arg == DV_BLOB_HANDLE)
    {
      blob_handle_t *bh = (blob_handle_t *)source_arg;
      source_sort = blob_looks_like_serialized_xml (qi, bh);
      if (XE_XPER_SERIALIZATION == source_sort)
	{
	  bh = (blob_handle_t *) box_copy_tree (source_arg);
	  xpd->xpd_bh = bh;
	  xper_get_blob_page_dir (xpd);
	  xpd->xpd_state = XPD_PERSISTENT;
	  xper_dbg_print ("BLOB handle here!\n");
	  goto create_and_return_xpe;
	}
      if (XE_XPACK_SERIALIZATION == source_sort)
        {
       	  dk_free_box (uri);
	  sqlr_new_error ("42000", "XE024",
	    "Unable to convert packed XML serialized data into an persistent XML entity" );
	}
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&bcfi, bh, qi->qi_client);
	  source_type = 'C';
	  iter = bcfi_read;
	  iter_abend = bcfi_abend;
	  iter_data = &bcfi;
	  source_is_wide = ((dtp_of_source_arg == DV_BLOB_WIDE_HANDLE) ? 1 : 0);
	  goto parse_source;
        }
      source_type = 'B';
      bdfi_reset (&bdfi, bh, qi);
      iter = bdfi_read;
      iter_data = &bdfi;
      goto parse_source;
    }
  if (dtp_of_source_arg == DV_BLOB_WIDE_HANDLE)
    {
      blob_handle_t *bh = (blob_handle_t *)source_arg;
      source_is_wide = 1;
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&bcfi, bh, qi->qi_client);
	  source_type = 'C';
	  iter = bcfi_read;
	  iter_abend = bcfi_abend;
	  iter_data = &bcfi;
	  source_is_wide = ((dtp_of_source_arg == DV_BLOB_WIDE_HANDLE) ? 1 : 0);
	  goto parse_source;
        }
      bdfi_reset (&bdfi, bh, qi);
      source_type = 'B';
      iter = bdfi_read;
      iter_data = &bdfi;
      goto parse_source;
    }
  if ((dtp_of_source_arg == DV_SHORT_STRING_SERIAL) ||
      (dtp_of_source_arg == DV_STRING) ||
      (dtp_of_source_arg == DV_C_STRING))
    {                             /* 01234567 */
      if (!strncasecmp (source_arg, "file://", 7))
        {
          sec_check_dba (qi, "<read XML from URL of type file://...>");
                 context.xpc_src_filename = file_native_name_from_iri_path_nchars (source_arg + 7, strlen (source_arg + 7));
          file_path_assert (context.xpc_src_filename, NULL, 1);
          xper_dbg_print_1 ("File '%s'\n", context.xpc_src_filename);
          context.xpc_src_file = fopen (context.xpc_src_filename, "rb");
          if (NULL == context.xpc_src_file)
            {
              caddr_t err = srv_make_new_error ("42000", "XP100", "Error opening file '%s'", context.xpc_src_filename);
              xper_destroy_ctx (&context);
              dk_free_box (uri);
              sqlr_resignal (err);
            }
        source_type = 'F';
	iter = file_read;
	iter_data = context.xpc_src_file;
        goto parse_source;
      }
      source_type = 'S';
      source_length = box_length (source_arg) - 1;
      goto parse_source;
    }
  if ((dtp_of_source_arg == DV_WIDE) ||
      (dtp_of_source_arg == DV_LONG_WIDE))
    {
      source_length = box_length (source_arg) - sizeof (wchar_t);
      source_type = 'S';
      source_is_wide = 1;
      goto parse_source;
    }
  if (dtp_of_source_arg == DV_STRING_SESSION)
    {
      dk_session_t *ses = (dk_session_t *) (source_arg);
      source_sort = strses_looks_like_serialized_xml (ses);
      if (XE_XPER_SERIALIZATION == source_sort)
        {
       	  dk_free_box (uri);
	  sqlr_new_error ("42000", "XE025",
	    "Unable to make a persistent XML entity from a string session that contains XPER data" );
	}
      if (XE_XPACK_SERIALIZATION == source_sort)
        {
       	  dk_free_box (uri);
	  sqlr_new_error ("42000", "XE026",
	    "Unable to make a persistent XML entity from a string session that contains packed XML serialized data" );
	}
      dsfi_reset (&dsfi, ses);
      source_type = 'D';
      iter = dsfi_read;
      iter_data = &dsfi;
      goto parse_source;
    }
  dk_free_box (uri);
  sqlr_new_error ("42000", "XE004",
      "xml_persistent needs a string, string session or BLOB as argument 1, not an arg of type %s (%d)",
      dv_type_title (dtp_of_source_arg), dtp_of_source_arg);

parse_source:

  QR_RESET_CTX
  {
    dbe_key_t* xper_key;
    xpd->xpd_state = XPD_NEW;
    context.xpc_doc = xpd;
    xpd->xpd_bh = bh_alloc (DV_BLOB_XPER_HANDLE);
    context.xpc_itc = itc_create (NULL, qi->qi_trx);
    xper_key = sch_id_to_key (wi_inst.wi_schema, KI_COLS);
    itc_from (context.xpc_itc, xper_key);
    xpd->xpd_bh->bh_it = context.xpc_itc->itc_tree;
    context.xpc_index_attrs = index_attrs;
    context.xpc_attr_word_ctr = (index_attrs ? FIRST_ATTR_WORD_POS : 0);
    memset (&root_data, 0, sizeof (root_data));
    memset (&root_attrdata, 0, sizeof (root_attrdata));
/* IvAn/TextXperIndex/000815 To match xml tree format, "root" replaced with " root". */
    root_data.type = XML_MKUP_STAG;
    root_data.name = uname__root;
    root_data.lh = lh;
    root_data.wrs.xewr_main_beg = 0;
    root_data.wrs.xewr_attr_beg = FIRST_ATTR_WORD_POS;
    root_data.recalc_wrs = root_data.store_wrs = (int) context.xpc_attr_word_ctr;
    root_data.attrdata = &root_attrdata;

    ITC_FAIL (context.xpc_itc)
    {
      buf = it_new_page (context.xpc_itc->itc_tree, context.xpc_itc->itc_page,
	  DPF_BLOB, 0, 0);
      ITC_LEAVE_MAPS (context.xpc_itc);
      if (!buf)
	{
	  xper_destroy_ctx (&context);
	  dk_free_box (uri);
	  sqlr_new_error ("XE000", "XP9A7", "Error allocating a new blob page while parsing XML");
	}
      xpd->xpd_bh->bh_page = buf->bd_page;
      xper_blob_log_page_to_dir (xpd->xpd_bh, 0, buf->bd_page);
      context.xpc_buf = buf;
    }
    ITC_FAILED
    {
      ITC_LEAVE_MAPS (context.xpc_itc);
      xper_destroy_ctx (&context);
      dk_free_box (uri);
      sqlr_new_error ("XE000", "XP102", "ITC error while parsing XML");
    }
    END_FAIL (context.xpc_itc);
    if ('S' == source_type)
      source_sort = str_looks_like_serialized_xml (source_arg);
    if (('S' == source_type) && (XE_XPER_SERIALIZATION == source_sort))
      {				/* serialized blob content as a DV_X_STRING */
	source_length = box_length (source_arg);
	/* length of source is less then 2048 - so it always fit one page */
	memcpy (buf->bd_buffer + DP_DATA, source_arg, source_length);
	xpd->xpd_bh->bh_diskbytes = xpd->xpd_bh->bh_length = source_length;
	LONG_SET/*_NA*/ (buf->bd_buffer + DP_BLOB_LEN, (int32) source_length);
	LONG_SET/*_NA*/ (buf->bd_buffer + DP_OVERFLOW, 0);
	rc = 1;
      }
    else if (('S' == source_type) && (XE_XPACK_SERIALIZATION == source_sort))
      {				/* packed XML blob content as a DV_X_STRING */
	dk_free_box (uri);
	sqlr_new_error ("42000", "XE023", "Can not compose an XPER entity by deserialization of a packed XML");
      }
    else
      {				/* string is an XML document to parse */
	memcpy (buf->bd_buffer + DP_DATA, XPER_PREFIX, XPER_ROOT_POS);
	xpd->xpd_bh->bh_length = xpd->xpd_bh->bh_diskbytes = XPER_ROOT_POS;
	LONG_SET/*_NA*/ (buf->bd_buffer + DP_BLOB_LEN, XPER_ROOT_POS);
	LONG_SET/*_NA*/ (buf->bd_buffer + DP_OVERFLOW, 0);
	memset (&config, 0, sizeof (config));
	config.input_is_wide = source_is_wide;
	config.input_is_ge = is_html & GE_XML;
	config.input_is_html = is_html & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS);
	config.input_is_xslt = is_html & FINE_XSLT;
	config.user_encoding_handler = intl_find_user_charset;
	config.uri_resolver = (VXmlUriResolver)xml_uri_resolve_like_get;
	config.uri_reader = (VXmlUriReader)xml_uri_get;
	config.uri_appdata = qi;	/* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
        config.error_reporter = (VXmlErrorReporter)(sqlr_error);
	config.initial_src_enc_name = enc_name;
	config.dtd_config = dtd_config;
	config.uri = ((NULL == uri) ? uname___empty : uri);
	config.root_lang_handler = lh;
        if (file_read == iter)
          config.feed_buf_size = 0x10000;
	context.xpc_parser = VXmlParserCreate (&config);
	VXmlSetUserData (context.xpc_parser, &context);
	VXmlSetElementHandler (context.xpc_parser, cb_element_start, cb_element_end);
	VXmlSetIdHandler (context.xpc_parser, (VXmlIdHandler) cb_id);
	VXmlSetCharacterDataHandler (context.xpc_parser, cb_character);
	VXmlSetEntityRefHandler (context.xpc_parser, cb_entity);
	VXmlSetProcessingInstructionHandler (context.xpc_parser, cb_pi);
	VXmlSetCommentHandler (context.xpc_parser, cb_comment);
 /*
   VXmlSetDtdHandler (context.xpc_parser, (VXmlDtdHandler) cb_dtd);
 */
	/* start root tag */
	dk_set_push (&context.xpc_poss, (void *)((ptrlong)(xpd->xpd_bh->bh_length)));
	tmp_box = start_tag_record (&root_data);
	xper_blob_append_box (&context, tmp_box);
	dk_free_box (tmp_box);
/* IvAn/TextXperIndex/000815 Word counter added, "root" replaced with " root" */
	context.xpc_tn_length1 = 7 /*DV_SHORT_STR " root" */ ;
	if (iter)
	  VXmlParserInput (context.xpc_parser, iter, iter_data);
	rc = VXmlParse (context.xpc_parser, source_arg, source_length);
	if (!rc)
	  {
	    if (NULL != iter_abend)
	      {
	        iter_abend (iter_data);
	        iter_abend = NULL;
	      }
	    rc_msg = VXmlFullErrorMessage (context.xpc_parser);
	  }
	pos = (long) (ptrlong) context.xpc_poss->data;
	if (pos < 0)
	  {
	    dk_set_pop (&context.xpc_poss);
	    pos = (long) (ptrlong) context.xpc_poss->data;
	  }
	context.xpc_poss->data = (void *) (ptrlong) -pos;
	/* end root tag */
	if (XML_MKUP_ETAG != context.xpc_word_hider)
	  context.xpc_main_word_ctr += 1;
	ITC_FAIL (context.xpc_itc)
	{
/* IvAn/TextXperIndex/000815 Word counter added, "root" replaced with " root" */
	  set_long_in_blob (&context, XPER_ROOT_POS + 7 /*DV_SHORT_STR " root" */  +
	      STR_NAME_OFF + STR_END_TAG_OFF,
	      (long) xpd->xpd_bh->bh_length);
	  set_long_in_blob (&context, XPER_ROOT_POS + 7 /*DV_SHORT_STR " root" */  +
	      STR_NAME_OFF + STR_END_WORD_OFF,
	      (long) context.xpc_main_word_ctr);
	  if (context.xpc_index_attrs)
	    {
	      set_long_in_blob (&context, XPER_ROOT_POS + 7 /*DV_SHORT_STR " root" */  +
		  STR_NAME_OFF + STR_ADDON_OR_ATTR_OFF + (2 * 4),
		  (long) context.xpc_attr_word_ctr);
	    }
	  ITC_LEAVE_MAPS (context.xpc_itc);
	}
	ITC_FAILED
	{
	  ITC_LEAVE_MAPS (context.xpc_itc);
	  dk_free_box (uri);
	  sqlr_new_error ("XE000", "XP9A9", "ITC error on writing persistent XML");
	}
	END_FAIL (context.xpc_itc);
	tmp_box = end_tag_record (root_data.name);
	xper_blob_append_box (&context, tmp_box);
	dk_free_box (tmp_box);
	xpd->xd_weight = XML_XPER_DOC_WEIGHT;
	xpd->xd_cost = context.xpc_parser->input_cost;
	if (bcfi_read == iter) /* This input is not reproducible so the cost is infinite */
	  xpd->xd_cost = XML_MAX_DOC_COST;
/* Now it's time to get the dtd in our ownership */
	dtd_addref (context.xpc_parser->validator.dv_dtd, 0);
	if (NULL != xpd->xd_dtd)
	  dtd_release (xpd->xd_dtd);
	xpd->xd_dtd = context.xpc_parser->validator.dv_dtd;
	dk_free_box ((caddr_t) (xpd->xd_id_dict));
	dk_free_box (xpd->xd_id_scan);
	xpd->xd_id_dict = NULL;
	xpd->xd_id_scan = NULL;
/* Now we put dtd into blob, if there's something to put */
	if (0 < dtd_get_buffer_length (xpd->xd_dtd))
	  {
	    ITC_FAIL (context.xpc_itc)
	    {
	      set_long_in_blob (&context, XPER_ROOT_POS + 7 /*DV_SHORT_STR " root" */  +
		  STR_NAME_OFF + STR_NS_OFF,
		  (long) xpd->xpd_bh->bh_length);
	      ITC_LEAVE_MAPS (context.xpc_itc);
	    }
	    ITC_FAILED
	    {
	      ITC_LEAVE_MAPS (context.xpc_itc);
	      dk_free_box (uri);
	      sqlr_new_error ("XE000", "XP9A9", "ITC error on writing persistent XML");
	    }
	    END_FAIL (context.xpc_itc);
	    blob_append_dtd (&context, xpd->xd_dtd);
	  }
      }
    buf_set_dirty (context.xpc_buf);
    page_leave_outside_map (context.xpc_buf);
    context.xpc_buf = NULL;
    if (!rc)
      {
        dk_free_box (uri);
	sqlr_new_error ("42000", "XP101", "%.1500s", ((NULL == rc_msg) ? "Error parsing XML" : rc_msg));
      }
  }
  QR_RESET_CODE
  {
    du_thread_t *self = THREAD_CURRENT_THREAD;
    caddr_t err = thr_get_error_code (self);
    if (NULL != rc_msg)
      dk_free_box (rc_msg);
    if (NULL != iter_abend)
      {
        iter_abend (iter_data);
        iter_abend = NULL;
      }
    POP_QR_RESET;
    xper_destroy_ctx (&context);
    sqlr_resignal (err);
  }
  END_QR_RESET;

create_and_return_xpe:
  xpe = (xper_entity_t *) dk_alloc_box_zero (sizeof (xml_entity_un_t), DV_XML_ENTITY);
#ifdef XPER_DEBUG
  xper_entity_alloc_ctr++;
#endif
  xpe->_ = &xec_xper_xe;
  xpe->xe_doc.xpd = xpd;
  xpd->xd_top_doc = (xml_doc_t *) xpd;
  xpd->xd_uri = uri;
  xpd->xd_ref_count = 1;
  context.xpc_doc = NULL;	/* To prevent destruction in xper_destroy_ctx */
  xper_destroy_ctx (&context);
  xper_blob_truncate_dir_buf (xpd->xpd_bh);
  fill_xper_entity (xpe, XPER_ROOT_POS);
  return xpe;
}


xml_entity_t *
 DBG_NAME (xp_copy) (DBG_PARAMS xml_entity_t * xe)
{
  xper_entity_t *xpe;

  xper_dbg_print ("xp_copy\n");

  if (DV_XML_ENTITY != box_tag (xe))
    sqlr_new_error ("XE000", "XP9B1", "Attempt to copy a box with invalid tag.");

  xpe = (xper_entity_t *) dk_alloc_box (sizeof (xml_entity_un_t), DV_XML_ENTITY);
#ifdef XPER_DEBUG
  xper_entity_alloc_ctr++;
#endif
  memcpy (xpe, xe, sizeof (xml_entity_un_t));
  xpe->xper_name = box_copy (xpe->xper_name);
  if (NULL != xpe->xper_text)
    xpe->xper_text = box_copy (xpe->xper_text);
  xpe->xe_doc.xd->xd_ref_count++;
  if (NULL != xpe->xe_referer)
    xpe->xe_referer = xpe->xe_referer->_->xe_copy (xpe->xe_referer);
  if (NULL != xpe->xper_cut_ent)
    xpe->xper_cut_ent = (xper_entity_t *) xp_copy ((xml_entity_t *) (xpe->xper_cut_ent));
  if (NULL != xpe->xe_attr_name)
    xpe->xe_attr_name = box_copy_tree (xpe->xe_attr_name);
  return (xml_entity_t *) xpe;
}


xper_entity_t *
xper_copy_and_refill (xper_entity_t * src_xpe, long new_pos)
{
  xper_entity_t *res_xpe = (xper_entity_t *) dk_alloc_box (sizeof (xml_entity_un_t), DV_XML_ENTITY);
#ifdef XPER_DEBUG
  xper_entity_alloc_ctr++;
#endif
  memcpy (res_xpe, src_xpe, sizeof (xper_entity_t));
  res_xpe->xper_name = NULL;
  res_xpe->xper_text = NULL;
  res_xpe->xe_doc.xd->xd_ref_count++;
  if (NULL != res_xpe->xe_referer)
    res_xpe->xe_referer = res_xpe->xe_referer->_->xe_copy (res_xpe->xe_referer);
  res_xpe->xper_cut_pos = 0L;
  res_xpe->xper_cut_ent = NULL;
  fill_xper_entity (res_xpe, new_pos);
  return res_xpe;
}


lang_handler_t *
xper_find_lang_handler (xper_entity_t * xpe)
{
  if (XML_MKUP_STAG == xpe->xper_type)
    {
      caddr_t attrvalue = xper_get_attribute (xpe, "xml:lang", 8 /* == strlen("xml:lang") */ );
      if (NULL != attrvalue)
	{
/* lh_get_handler obtains UTF-8 string, but it's safe because all language
   names should be 7-bit, and any wider string will not match any name, anyway. */
	  lang_handler_t *res = lh_get_handler (attrvalue);
	  dk_free_box (attrvalue);
	  return res;
	}
    }
  if (0 == xpe->xper_parent)
    return server_default_lh;
  xpe = xper_copy_and_refill (xpe, xpe->xper_parent);
  for (;;)
    {
      if (XML_MKUP_STAG == xpe->xper_type)
	{
	  caddr_t attrvalue = xper_get_attribute (xpe, "xml:lang", 8 /* == strlen("xml:lang") */ );
	  if (NULL != attrvalue)
	    {
/* lh_get_handler obtains UTF-8 string, but it's safe because all language
   names should be 7-bit, and any wider string will not match any name, anyway. */
	      lang_handler_t *res = lh_get_handler (attrvalue);
	      dk_free_box (attrvalue);
	      dk_free_box ((box_t) xpe);
	      return res;
	    }
	}
      if ((XPER_ROOT_POS == xpe->xper_parent) || (0 == xpe->xper_parent))
	break;
      fill_xper_entity (xpe, xpe->xper_parent);
    }
  dk_free_box ((box_t) xpe);
  return server_default_lh;
}


int
xp_up (xml_entity_t * xe, XT * node, int up_flags)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  int rc;
  xper_dbg_print ("xp_parent\n");
/*
   Attributes are not children of its element.
   But the element is parent of its attributes.
   See XPATH, 5.3 "Attribute Nodes"
 */
  if (NULL != xe->xe_attr_name)
    {
/* If no sideway then element's name should match the test */
      if (!(up_flags & XE_UP_SIDEWAY) && !xp_element_name_test (xe, node))
	return XI_AT_END;
      dk_free_box (xe->xe_attr_name);
      xe->xe_attr_name = NULL;
      if (!(up_flags & XE_UP_SIDEWAY))
	return XI_RESULT;
      goto go_sideway;
    }
/* Top of the (sub)document */
  if ((0 == xpe->xper_parent) ||
      ((XPER_ROOT_POS == xpe->xper_parent) && (NULL != xpe->xe_referer)))
    {
      xml_entity_t *up = xpe->xe_referer;
      if ((NULL == up) || !(up_flags & XE_UP_MAY_TRANSIT))
	return XI_AT_END;
      /* No xpe->xe_doc.xtd->xd_ref_count++; before this destroy */
      xpe->xe_referer = NULL;
      xp_destroy ((xml_entity_t *) xpe);
#ifdef XPER_DEBUG
      xper_entity_free_ctr--;
#endif
      memcpy (xpe, up, sizeof (xml_entity_un_t));
      box_tag_modify (up, DV_ARRAY_OF_LONG);	/* do not call destructor, content still referenced due to copy *
						   * set tag to array, not string cause strings aligned differently */
      dk_free_box ((box_t) up);
      if (up_flags & XE_UP_SIDEWAY)
	goto go_sideway;
      if (up_flags & XE_UP_MAY_TRANSIT_ONCE)
	return XI_RESULT;
      return (xpe->_->xe_up ((xml_entity_t *) xpe, node, up_flags));
    }
/* Plain non-attribute entity */
  if (up_flags & XE_UP_SIDEWAY)
    {
      fill_xper_entity (xpe, xpe->xper_parent);
      goto go_sideway;
    }
  if (!xper_node_test (xpe, xpe->xper_parent, node))
    return XI_AT_END;
  fill_xper_entity (xpe, xpe->xper_parent);
  return XI_RESULT;

go_sideway:
/* in-place check or sideway go */
  if (up_flags & XE_UP_SIDEWAY_FWD)
    {
      if (up_flags & XE_UP_SIDEWAY_WR)
	rc = (xpe->_->xe_next_sibling_wr ((xml_entity_t *) xpe, node));
      else
	rc = (xpe->_->xe_next_sibling ((xml_entity_t *) xpe, node));
    }
  else
    {
      if (up_flags & XE_UP_SIDEWAY_WR)
	rc = (xpe->_->xe_prev_sibling_wr ((xml_entity_t *) xpe, node));
      else
	rc = (xpe->_->xe_prev_sibling ((xml_entity_t *) xpe, node));
    }
  return rc;
}


#define XE_NAME(xe) (xe->xe_doc.xd->xd_uri ? xe->xe_doc.xd->xd_uri : "<no URI>")


int
xp_down (xml_entity_t * xe, XT * node)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xml_entity_t *ref_copy, *old_back, *new_back, *refd;
  caddr_t rel_uri;
  char *sysid, *sysid_base_uri;
  if ((XML_MKUP_REF != xpe->xper_type) || (NULL != xpe->xe_attr_name))
    {
      if (!xp_ent_name_test ((xml_entity_t *) xpe, node))
	return XI_AT_END;
      return XI_RESULT;
    }
  old_back = xpe->xe_referer;
  rel_uri = xper_get_attribute (xpe, "SYSTEM", 6);
  sysid_base_uri = (char *) xe_get_sysid_base_uri ((xml_entity_t *) (xpe));
  if (NULL == rel_uri)
    {
      rel_uri = sysid = (char *) xe_get_sysid ((xml_entity_t *) (xpe), xpe->xper_name);
    }
  else
    sysid = NULL;
  if (NULL != rel_uri)
    {
      refd = xp_reference (xpe->xe_doc.xpd->xd_qi, sysid_base_uri, rel_uri, xpe->xe_doc.xd, NULL);
    }
  else
    {
      caddr_t err = NULL;
      refd = xp_reference (xpe->xe_doc.xpd->xd_qi, sysid_base_uri, xpe->xper_name, xpe->xe_doc.xd, &err);
      if (NULL == refd)
	{
	  dk_free_tree (err);
	  return XI_AT_END;
	}
    }
  xpe->xe_referer = NULL;
  new_back = xpe->_->xe_copy ((xml_entity_t *) xpe);
  new_back->xe_referer = old_back;
  xp_destroy ((xml_entity_t *) (xpe));
#ifdef XPER_DEBUG
  xper_entity_free_ctr--;
#endif
  ref_copy = refd->_->xe_copy ((xml_entity_t *) refd);
  memcpy (xpe, ref_copy, sizeof (xml_entity_un_t));
  box_tag_modify (ref_copy, DV_ARRAY_OF_LONG);	/* no recursive destr etc.
						 * the tag is not a string tag because of string alignment being to 16 whereas other boxes to 8 */
  dk_free_box ((box_t) ref_copy);
  if (sysid != rel_uri)
    dk_free_box (rel_uri);
  xpe->xe_referer = new_back;
  if (XI_RESULT == xpe->_->xe_first_child ((xml_entity_t *) xpe, node))
    return XI_RESULT;
  xpe->_->xe_up ((xml_entity_t *) xpe, (XT *) XP_NODE, (XE_UP_MAY_TRANSIT | XE_UP_MAY_TRANSIT_ONCE));
  return XI_AT_END;
}


int
xp_down_rev (xml_entity_t * xe, XT * node)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xml_entity_t *save_referer, *topmost;
  xml_entity_t *last_good = NULL;
  int res;
  if ((XML_MKUP_REF != xpe->xper_type) || (NULL != xpe->xe_attr_name))
    {
      if (!xp_ent_name_test ((xml_entity_t *) xpe, node))
	return XI_AT_END;
      return XI_RESULT;
    }
  if (XI_AT_END == xe->_->xe_down (xe, (XT *) XP_NODE))
    return XI_AT_END;
  /* This catch implements some tricky thing. We set xe_referer to
     prevent xe_next_sibling from running outside current subdocument:
     xe_up will not know that it's a subdocument (will think that it's a whole doc)
     Then we restore the status quo. */
  save_referer = xe->xe_referer;
  xe->xe_referer = NULL;
  QR_RESET_CTX
  {
    xml_entity_t *last_good = NULL;
    if (xe->_->xe_ent_name_test (xe, node))
      last_good = xe->_->xe_copy (xe);
    while (XI_RESULT == xe->_->xe_next_sibling (xe, node))
      {
	dk_free_tree ((box_t) last_good);
	last_good = xe->_->xe_copy (xe);
      }
    if ((NULL != last_good) && !xe->_->xe_is_same_as (xe, last_good))
      {
	/* No xpe->xe_doc.xtd->xd_ref_count++; before this destroy */
	/* No need in xe->xe_referer = NULL here because it's done above */
	xp_destroy ((xml_entity_t *) xpe);
#ifdef XPER_DEBUG
	xper_entity_free_ctr--;
#endif
	memcpy (xpe, last_good, sizeof (xml_entity_un_t));
	box_tag_modify (last_good, DV_ARRAY_OF_LONG);	/* do not call destructor, content still referenced due to copy *
							   * set tag to array, not string cause strings aligned differently */
	dk_free_box ((box_t) last_good);
      }
    else
      dk_free_tree ((box_t) last_good);
    res = (NULL != last_good) ? XI_RESULT : XI_AT_END;
    topmost = xe;
    while (NULL != topmost->xe_referer)
      topmost = topmost->xe_referer;
    topmost->xe_referer = save_referer;
  }
  QR_RESET_CODE
  {
    du_thread_t * self = THREAD_CURRENT_THREAD;
    caddr_t err = thr_get_error_code (self);
    POP_QR_RESET;
    dk_free_box ((caddr_t) last_good);
    topmost = xe;
    while (NULL != topmost->xe_referer)
      topmost = topmost->xe_referer;
    topmost->xe_referer = save_referer;
    sqlr_resignal (err);
    return XI_AT_END;		/* Never reached */
  }
  END_QR_RESET;
  if (XI_RESULT == res)
    return XI_RESULT;
  xe->_->xe_up (xe, (XT *) XP_NODE, (XE_UP_MAY_TRANSIT | XE_UP_MAY_TRANSIT_ONCE));
  return XI_AT_END;
}


int
xp_get_child_count_any (xml_entity_t * xe)
{
  int res = 0;
  int rc = xe->_->xe_first_child (xe, (XT *) XP_NODE);
  if (XI_RESULT != rc)
    return 0;
  res++;
  while (XI_RESULT == xe->_->xe_next_sibling (xe, (XT *) XP_NODE))
    res++;
  xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
  return res;
}


int
xp_next_sibling (xml_entity_t * xe, XT * node_test)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  caddr_t tmp_box;
  long save, save_parent, left;
  xper_dbg_print ("xp_next\n");
  if (NULL != xpe->xe_attr_name)
    return XI_AT_END;
  if (0 == xpe->xper_parent)
    return xp_up ((xml_entity_t *) xpe, node_test, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD));
  if (XML_MKUP_ETAG == xpe->xper_type)
    return XI_AT_END;
  save = xpe->xper_pos;
  save_parent = xpe->xper_parent;
  for (;;)
    {
      left = xpe->xper_pos;
      if (XML_MKUP_STAG == xpe->xper_type)
	{
	  save_parent = xpe->xper_parent;
	  fill_xper_entity (xpe, xpe->xper_end);
	}
      if (uname__root == xpe->xper_name)
	break;
      tmp_box = get_tag_data (xpe, xpe->xper_next_item);
      if (DV_XML_MARKUP == DV_TYPE_OF (tmp_box) && XML_MKUP_ETAG == tmp_box[0])
	{
	  dk_free_box (tmp_box);
	  break;
	}
      dk_free_box (tmp_box);
      fill_xper_entity (xpe, xpe->xper_next_item);
      xpe->xper_parent = save_parent;
      xpe->xper_left = left;
      if (XML_MKUP_TEXT == xpe->xper_type)
	xpe->xper_start_word++;
      if (XI_RESULT == xp_down ((xml_entity_t *) xpe, node_test))
	return XI_RESULT;
    }
  fill_xper_entity (xpe, save);
  if (XPER_ROOT_POS == xpe->xper_parent)
    return xp_up ((xml_entity_t *) xpe, node_test, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD));
  return XI_AT_END;
}


int
xp_next_sibling_wr (xml_entity_t * xe, XT * node_test)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xp_instance_t *xqi = xe->xe_doc.xd->xd_top_doc->xd_xqi;
  caddr_t tmp_box;
  long save, save_parent, left;
  xper_dbg_print ("xp_next\n");
  if (NULL != xpe->xe_attr_name)
    return XI_AT_END;
  if (0 == xpe->xper_parent)
    return xp_up ((xml_entity_t *) xpe, node_test, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD | XE_UP_SIDEWAY_WR));
  if (XML_MKUP_ETAG == xpe->xper_type)
    return XI_AT_END;
  save = xpe->xper_pos;
  save_parent = xpe->xper_parent;
  for (;;)
    {
      left = xpe->xper_pos;
      if (XML_MKUP_STAG == xpe->xper_type)
	{
	  save_parent = xpe->xper_parent;
	  fill_xper_entity (xpe, xpe->xper_end);
	}
      if (uname__root == xpe->xper_name)
	break;
      tmp_box = get_tag_data (xpe, xpe->xper_next_item);
      if (DV_XML_MARKUP == DV_TYPE_OF (tmp_box) && XML_MKUP_ETAG == tmp_box[0])
	{
	  dk_free_box (tmp_box);
	  break;
	}
      dk_free_box (tmp_box);
      fill_xper_entity (xpe, xpe->xper_next_item);
      xpe->xper_parent = save_parent;
      xpe->xper_left = left;
      if (!txs_is_hit_in (xqi->xqi_text_node, (caddr_t *) xqi->xqi_qi, (xml_entity_t *) (xpe)))
	continue;
      if (XI_RESULT == xp_down ((xml_entity_t *) xpe, node_test))
	return XI_RESULT;
    }
  fill_xper_entity (xpe, save);
  if (XPER_ROOT_POS == xpe->xper_parent)
    return xp_up ((xml_entity_t *) xpe, node_test, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD | XE_UP_SIDEWAY_WR));
  return XI_AT_END;
}


int
xp_first_child (xml_entity_t * xe, XT * node_test)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  caddr_t tmp_box;
  long save = xpe->xper_pos;
  long save_parent = xpe->xper_pos;
  long left;

  xper_dbg_print ("xp_first_child\n");
  if (NULL != xpe->xe_attr_name)
    return XI_AT_END;
  if (XML_MKUP_STAG != xpe->xper_type)
    return XI_AT_END;
  fill_xper_entity (xpe, xpe->xper_next_item);
  for (;;)
    {
      switch (xpe->xper_type)
	{
	case XML_MKUP_ETAG:
	  fill_xper_entity (xpe, save);
	  return XI_AT_END;
	case XML_MKUP_STAG:
	  break;
	case XML_MKUP_TEXT:
	  xpe->xper_start_word++;
	case XML_MKUP_COMMENT:
	  xpe->xper_parent = save;
	  xpe->xper_left = 0;
	  /* break; -- removed to avoid 'unreacheable end of loop' in AIX cc */
	}
      break;
    }
  if (XI_RESULT == xp_down ((xml_entity_t *) xpe, node_test))
    return XI_RESULT;

  for (;;)
    {
      left = xpe->xper_pos;
      if (XML_MKUP_STAG == xpe->xper_type)
	{
	  save_parent = xpe->xper_parent;
	  fill_xper_entity (xpe, xpe->xper_end);
	}
      if (uname__root == xpe->xper_name)
	break;
      tmp_box = get_tag_data (xpe, xpe->xper_next_item);
      if (DV_XML_MARKUP == DV_TYPE_OF (tmp_box) && XML_MKUP_ETAG == tmp_box[0])
	{
	  dk_free_box (tmp_box);
	  break;
	}
      dk_free_box (tmp_box);
      fill_xper_entity (xpe, xpe->xper_next_item);
      xpe->xper_parent = save_parent;
      xpe->xper_left = left;
      if (XI_RESULT == xp_down ((xml_entity_t *) xpe, node_test))
	return XI_RESULT;
    }
  fill_xper_entity (xpe, save);
  return XI_AT_END;
}

int
xp_child_count (xml_entity_t * xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  long save = xpe->xper_pos;
  int count;

  xper_dbg_print ("xp_child_count\n");

  if (!xpe->xper_first_child)
    return 0;

  fill_xper_entity (xpe, xpe->xper_first_child);

  for (count = 1; xpe->xper_right; ++count)
    fill_xper_entity (xpe, xpe->xper_right);

  fill_xper_entity (xpe, save);
  return count;
}


int
xp_go_left (xper_entity_t * xpe)
{
  if (!xpe->xper_left)
    return 0;
  if (xpe->xper_left < xpe->xper_pos)
    {
      fill_xper_entity (xpe, xpe->xper_left);
    }
  else
    {
      long save = xpe->xper_pos;
      long left = xpe->xper_left;
      for (;;)
	{
	  xpe->xper_left = (XPER_ROOT_POS - 1);
	  fill_xper_entity (xpe, xpe->xper_right);
	  if ((XPER_ROOT_POS - 1) != xpe->xper_left)
	    {
	      left = xpe->xper_left;
	      break;
	    }
	  if (XML_MKUP_ETAG == xpe->xper_type)
	    break;
	}
      if (!xpe->xper_left)
	{
	  if (!xpe->xper_parent)
	    return 0;
	  fill_xper_entity (xpe, xpe->xper_parent);
	}
      else
	{
	  fill_xper_entity (xpe, xpe->xper_left);
	}
      if (xpe->xper_next_item >= save)
	return 0;
      for (;;)
	{
	  left = xpe->xper_pos;
	  if (XML_MKUP_STAG == xpe->xper_type)
	    {
	      if (xpe->xper_end >= save)
		break;
	      fill_xper_entity (xpe, xpe->xper_end);
	      if (xpe->xper_next_item >= save)
	      {
		fill_xper_entity (xpe, left);
		break;
	      }
	      fill_xper_entity (xpe, xpe->xper_next_item);
	      if (xpe->xper_pos >= save)
		{
		  fill_xper_entity (xpe, left);
		  break;
		}
	      fill_xper_entity (xpe, xpe->xper_next_item);
	      continue;
	    }
	  if (xpe->xper_next_item >= save)
	    break;
	  fill_xper_entity (xpe, xpe->xper_next_item);
	  xpe->xper_left = left;
	}
    }
  return 1;
}


int
xp_prev_sibling (xml_entity_t * xe, XT * node_test)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  long save = xpe->xper_pos;

  xper_dbg_print ("xp_prev_sibling\n");

  if ((0 == xpe->xper_parent) || ((XPER_ROOT_POS == xpe->xper_parent) && (0 == xpe->xper_left)))
    return xp_up ((xml_entity_t *) xpe, node_test, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY /*| XE_UP_SIDEWAY_FWD */ ));
  if (0 == xpe->xper_left)
    return XI_AT_END;

  do
    {
      if (!xp_go_left (xpe))
	break;
      if (XI_RESULT == xp_down_rev ((xml_entity_t *) xpe, node_test))
	return XI_RESULT;
    }
  while (xpe->xper_left);

  fill_xper_entity (xpe, save);
  if (XPER_ROOT_POS == xpe->xper_parent)
    return xp_up ((xml_entity_t *) xpe, node_test, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY /*| XE_UP_SIDEWAY_FWD */ ));
  return XI_AT_END;
}


int
DBG_NAME(xp_attribute) (DBG_PARAMS xml_entity_t * xe, int start, XT * node, caddr_t * ret, caddr_t * name_ret)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  unsigned char *ptr, *tptr;
  caddr_t buf, ns;
  size_t len, num_word, atts_fill, addons;
  size_t inx;
  int nt_res;

  xper_dbg_print ("xp_attribute\n");

  if (XML_MKUP_STAG != xpe->xper_type)
    return XI_NO_ATTRIBUTE;

  buf = get_tag_data (xpe, xpe->xper_pos);
  len = box_length (buf);
  ptr = (unsigned char *) (buf + 1);
  ptr += full_dv_string_length (ptr);

  ptr += STR_ATTR_NO_OFF;
  num_word = LONG_REF_NA (ptr);
  ptr += 4;
  atts_fill = num_word & 0xFFFF;
  addons = ((unsigned long) (num_word)) >> 16;
  ptr += addons;

  if (-1 == start)
    start = 0;

  for (inx = 0; (int)(inx) < start * 2 && inx < atts_fill; inx++)
    ptr += full_dv_string_length (ptr);

  for (; inx + 1 < atts_fill; inx += 2)
    {
      int have_ns;
      unsigned char *local;
      size_t local_len;
      tptr = ptr;
      ns = NULL;

      if (DV_ARRAY_OF_POINTER == *ptr)
	{
	  have_ns = 1;
	  tptr += 5;
	  ns = xper_get_namespace (xpe, LONG_REF_NA (tptr + full_dv_string_length (tptr) + 1));
          if (uname___empty == ns)
            {
              ns = NULL;
	      have_ns = 0;
            }
	}
      else
	have_ns = 0;

      len = skip_string_length (&tptr);
      if (have_ns)
        {
          for (local = tptr + len; (local > tptr) && (':' != local[-1]); local--) /* empty body*/ ;
          local_len = tptr + len - local;
        }
      else
        {
          local = tptr;
          local_len = len;
        }
      if (!have_ns && !ST_P (node, XP_NAME_EXACT) && (local_len >= 5) && !memcmp (local, "xmlns", 5))
	nt_res = 0;
      else
        nt_res = xt_node_test_match_parts (node, (char *) local, local_len, ns);
      if (nt_res)
	{
	  if (name_ret)
	    {
	      if (ns)
		{
		  caddr_t qname;
		  BOX_DV_UNAME_COLONCONCAT4 (qname, ns, (char *)local, local_len);
		  XP_SET (name_ret, qname);
		  dk_free_box (ns);
		}
	      else
		{
		  XP_SET (name_ret, box_dv_uname_nchars ((char *) (tptr), len));
		}
	    }
	  if (ret)
	    {
	      ptr += full_dv_string_length (ptr);
	      len = skip_string_length (&ptr);
	      XP_SET (ret, box_dv_short_nchars ((const char *)ptr, len));
	    }
	  dk_free_box (buf);
	  return (int) (inx / 2 + 1);
	}
      if (ns)
	dk_free_box (ns);

      ptr += full_dv_string_length (ptr);
      ptr += full_dv_string_length (ptr);
    }

  dk_free_box (buf);
  return XI_NO_ATTRIBUTE;
}


caddr_t
xp_attrvalue (xml_entity_t * xe, caddr_t qname)
{
  caddr_t val = NULL;
  XT *test = xp_make_name_test_from_qname (NULL /* no xpp needed if qname is expanded */, qname, 1);
  xe->_->xe_attribute (xe, -1, test, &val, NULL);
  dk_free_tree ((caddr_t) test);
  return val;
}


caddr_t
xp_currattrvalue (xml_entity_t * xe)
{
  caddr_t val;
  caddr_t qname = xe->xe_attr_name;
  if (NULL == qname)
    GPF_T;
  val = xe->_->xe_attrvalue (xe, qname);
  if (NULL == val)
    GPF_T;
  return val;
}


size_t
xp_data_attribute_count (xml_entity_t * xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  unsigned char *ptr, *tptr;
  caddr_t buf;
  size_t len, num_word, atts_fill, addons;
  size_t inx, ctr;
  if (XML_MKUP_STAG != xpe->xper_type)
    return 0;
  buf = get_tag_data (xpe, xpe->xper_pos);
  len = box_length (buf);
  ptr = (unsigned char *) (buf + 1);
  ptr += full_dv_string_length (ptr);

  ptr += STR_ATTR_NO_OFF;
  num_word = LONG_REF_NA (ptr);
  ptr += 4;
  atts_fill = num_word & 0xFFFF;
  addons = ((unsigned long) (num_word)) >> 16;
  ptr += addons;

  for (ctr = inx = 0; inx + 1 < atts_fill; inx += 2)
    {
      tptr = ptr;

      if (DV_ARRAY_OF_POINTER == *ptr)
	ctr++;
      else
	{
	  len = skip_string_length (&tptr);
	  if ((5 > len) || memcmp (tptr, "xmlns", 5))
	    ctr++;
	}
      ptr += full_dv_string_length (ptr);
      ptr += full_dv_string_length (ptr);
    }
  dk_free_box (buf);
  return ctr;
}


static caddr_t
xper_get_attribute (xper_entity_t * xpe, const char * name, int name_len)
{
  unsigned char *ptr, *tptr;
  caddr_t buf;
  long len, num_word, atts_fill, addons;
  int inx;

  xper_dbg_print ("xper_get_attribute\n");

  switch (xpe->xper_type)
    {
    case XML_MKUP_ETAG:
    case XML_MKUP_COMMENT:
    case XML_MKUP_TEXT:
      return NULL;
    }

  buf = get_tag_data (xpe, xpe->xper_pos);
  len = box_length (buf);
  ptr = (unsigned char *) (buf + 1);
  ptr += full_dv_string_length (ptr);
  ptr += STR_ATTR_NO_OFF;
  num_word = LONG_REF_NA (ptr);
  ptr += 4;
  atts_fill = num_word & 0xFFFF;
  addons = ((unsigned long) (num_word)) >> 16;
  ptr += addons;
  for (inx = 0; inx + 1 < atts_fill; inx += 2)
    {
      tptr = ptr;

      if (DV_ARRAY_OF_POINTER == *ptr)
	{
	  tptr += 5;
	}

      len = (long) skip_string_length (&tptr);
      if ((name_len == len) && !memcmp (name, tptr, len))
	{
	  ptr += full_dv_string_length (ptr);
	  tptr = ptr;
	  len = (long) skip_string_length (&tptr);
	  ptr = (unsigned char *) dk_alloc_box (len + 1, DV_STRING);
	  memcpy (ptr, tptr, len);
	  ptr[len] = 0;
	  dk_free_box (buf);
	  return ((caddr_t) ptr);
	}

      ptr += full_dv_string_length (ptr);
      ptr += full_dv_string_length (ptr);
    }

  dk_free_box (buf);
  return NULL;
}


caddr_t *xp_copy_to_xte_head (xml_entity_t *xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  unsigned char *ptr, *tptr;
  caddr_t buf;
  long len, num_word, atts_fill, addons;
  int inx, res_len;
  int res_fill = 1;
  caddr_t *res = NULL;
  caddr_t qname;
  xper_dbg_print ("xp_copy_to_xte_head\n");
  switch (xpe->xper_type)
    {
    case XML_MKUP_ETAG:
      sqlr_new_error ("37000", "XI028", "Corrupted persistent XML entity.");
    case XML_MKUP_TEXT:
      {
	caddr_t box = get_tag_data (xpe, xpe->xper_pos);
	long pos;
	dk_session_t *ses = strses_allocate ();
	pos = xpe->xper_pos;
	for (;;)
	  {
	    session_buffered_write (ses, box, box_length (box));
	    pos += box_length (box) + ((DV_SHORT_STRING_SERIAL == box_tag (box)) ? 2 : 5);
	    dk_free_box (box);
	    box = get_tag_data (xpe, pos);
	    if ((DV_STRING != box_tag (box)) && (DV_SHORT_STRING_SERIAL != box_tag (box)))
	      break;
	  }
	dk_free_box (box);
	if (strses_length (ses) > 10000000)
	  sqlr_new_error ("42000", "XE005", "String value is longer than 10000000 bytes: source fragment of persistent XML is too large and can not be placed into XMLTree.");
	res = (caddr_t *)strses_string (ses);
	strses_free (ses);
	return res;
      }
    case XML_MKUP_COMMENT:
      if (box_length (xpe->xper_name) > 1)
        return (caddr_t *)list (2, list (1, uname__comment), box_copy (xpe->xper_name));
      return (caddr_t *)list (1, list (1, uname__comment));
    case XML_MKUP_PI:
    case XML_MKUP_REF:
      res_fill = 3;
      break;
    }
  buf = get_tag_data (xpe, xpe->xper_pos);
  len = box_length (buf);
  ptr = (unsigned char *) (buf + 1);
  ptr += full_dv_string_length (ptr);
  ptr += STR_ATTR_NO_OFF;
  num_word = LONG_REF_NA (ptr);
  ptr += 4;
  atts_fill = num_word & 0xFFFF;
  res_len = res_fill + atts_fill;
  res = (caddr_t *)dk_alloc_box (res_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if ((0 == xpe->xper_ns_pos) || (' ' == xpe->xper_name[0]))
    qname = box_copy (xpe->xper_name);
  else
    qname = xp_build_expanded_name (xpe);
  switch (xpe->xper_type)
    {
      case XML_MKUP_PI:
	res[0] = uname__pi;
	res[1] = uname__bang_name;
        res[2] = qname;
        break;
      case XML_MKUP_REF:
	res[0] = uname__ref;
	res[1] = uname__bang_name;
        res[2] = qname;
        break;
      default:
        res[0] = qname;
        break;
    }
  addons = ((unsigned long) (num_word)) >> 16;
  ptr += addons;
  for (inx = 0; inx + 1 < atts_fill; inx += 2)
    {
      caddr_t ns = NULL;
      tptr = ptr;
      if (DV_ARRAY_OF_POINTER == *ptr)
	{
	  tptr += 5;
	  ns = xper_get_namespace (xpe, LONG_REF_NA (tptr + full_dv_string_length (tptr) + 1));
          if (uname___empty == ns)
            ns = NULL;
	}
      len = (long) skip_string_length (&tptr);
      if ((5 > len) || memcmp (tptr, "xmlns", 5))
	{
	  if (NULL == ns)
	    res[res_fill++] = box_dv_uname_nchars ((char *)tptr, len);
	  else
	    {
              unsigned char *localname = tptr+len;
	      int locallen;
	      char *qname;
              while ((localname > tptr) && (':' != localname[-1])) localname--;
	      locallen = (int) ((tptr+len) - localname);
	      BOX_DV_UNAME_COLONCONCAT4 (qname, ns, (char *)localname, locallen);
	      res[res_fill++] = qname;
	      dk_free_box (ns);
	    }
	  ptr += full_dv_string_length (ptr);
	  len = (long) skip_string_length (&ptr);
	  res[res_fill++] = box_dv_short_nchars ((char *)ptr, len);
	  ptr += len;
	}
      else
	{
          ptr += full_dv_string_length (ptr);
	  ptr += full_dv_string_length (ptr);
	}
    }
  dk_free_box (buf);
  if (res_len == res_fill)
    return res;
  else
    {
      int newresboxlen = res_fill * sizeof(caddr_t);
      caddr_t *newres = (caddr_t *)dk_alloc_box (newresboxlen, DV_ARRAY_OF_POINTER);
      memcpy (newres, res, newresboxlen);
      dk_free_box ((box_t) res);
      return newres;
    }
}


caddr_t *xp_copy_to_xte_subtree (xml_entity_t *xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  unsigned char *ptr, *tptr;
  caddr_t buf;
  long len, num_word, atts_fill, addons;
  int inx, res_len;
  int res_fill = 1;
  caddr_t *res = NULL;
  dk_set_t children = NULL;
  caddr_t qname;
  xper_dbg_print ("xp_copy_to_xte_subtree\n");
  switch (xpe->xper_type)
    {
    case XML_MKUP_ETAG:
      sqlr_new_error ("37000", "XI028", "corrupted persistent XML entity detected.");
    case XML_MKUP_COMMENT:
      if (box_length (xpe->xper_name) > 1)
        return (caddr_t *)list (2, list (1, uname__comment), box_copy (xpe->xper_name));
      return (caddr_t *)list (1, list (1, uname__comment));
    case XML_MKUP_TEXT:
      {
	caddr_t box = get_tag_data (xpe, xpe->xper_pos);
	long pos;
	dk_session_t *ses = strses_allocate ();
	pos = xpe->xper_pos;
	for (;;)
	  {
	    session_buffered_write (ses, box, box_length (box));
	    pos += box_length (box) + ((DV_SHORT_STRING_SERIAL == box_tag (box)) ? 2 : 5);
	    dk_free_box (box);
	    box = get_tag_data (xpe, pos);
	    if ((DV_STRING != box_tag (box)) && (DV_SHORT_STRING_SERIAL != box_tag (box)))
	      break;
	  }
	dk_free_box (box);
	if (strses_length (ses) > 10000000)
	  sqlr_new_error ("42000", "XE005", "String value is longer than 10000000 bytes: source fragment of persistent XML is too large and can not be placed into XMLTree.");
	res = (caddr_t *)strses_string (ses);
	strses_free (ses);
	return res;
      }
    case XML_MKUP_PI:
    case XML_MKUP_REF:
      res_fill = 3;
      break;
    }
  buf = get_tag_data (xpe, xpe->xper_pos);
  len = box_length (buf);
  ptr = (unsigned char *) (buf + 1);
  ptr += full_dv_string_length (ptr);
  ptr += STR_ATTR_NO_OFF;
  num_word = LONG_REF_NA (ptr);
  ptr += 4;
  atts_fill = num_word & 0xFFFF;
  res_len = res_fill + atts_fill;
  res = (caddr_t *)dk_alloc_box (res_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if ((0 == xpe->xper_ns_pos) || (' ' == xpe->xper_name[0]))
    qname = box_copy (xpe->xper_name);
  else
    qname = xp_build_expanded_name (xpe);
  switch (xpe->xper_type)
    {
      case XML_MKUP_PI:
	res[0] = uname__pi;
	res[1] = uname__bang_name;
        res[2] = qname;
        break;
      case XML_MKUP_REF:
	res[0] = uname__ref;
	res[1] = uname__bang_name;
        res[2] = qname;
        break;
      default:
        res[0] = qname;
        break;
    }
  addons = ((unsigned long) (num_word)) >> 16;
  ptr += addons;
  for (inx = 0; inx + 1 < atts_fill; inx += 2)
    {
      caddr_t ns = NULL;
      tptr = ptr;
      if (DV_ARRAY_OF_POINTER == *ptr)
	{
	  tptr += 5;
	  ns = xper_get_namespace (xpe, LONG_REF_NA (tptr + full_dv_string_length (tptr) + 1));
          if (uname___empty == ns)
            ns = NULL;
	}
      len = (long) skip_string_length (&tptr);
      if ((5 > len) || memcmp (tptr, "xmlns", 5))
	{
	  if (NULL == ns)
	    res[res_fill++] = box_dv_uname_nchars ((char *)tptr, len);
	  else
	    {
              unsigned char *localname = tptr+len;
	      int locallen;
	      char *qname;
              while ((localname > tptr) && (':' != localname[-1])) localname--;
	      locallen = (int) ((tptr+len) - localname);
	      BOX_DV_UNAME_COLONCONCAT4 (qname, ns, (char *)localname, locallen);
	      res[res_fill++] = qname;
	      dk_free_box (ns);
	    }
	  ptr += full_dv_string_length (ptr);
	  len = (long) skip_string_length (&ptr);
	  res[res_fill++] = box_dv_short_nchars ((char *)ptr, len);
	  ptr += len;
	}
      else
	{
          ptr += full_dv_string_length (ptr);
	  ptr += full_dv_string_length (ptr);
	}
    }
  dk_free_box (buf);
  if (XML_MKUP_PI == xpe->xper_type)
    {
      if ((res_fill > 2) && (!strcmp (res[res_fill - 2], "data")))
        {
	  dk_set_push (&children, res[res_fill - 1]);
	  dk_free_box (res[res_len - 2]);
	  res_fill -= 2;
	}
    }
  if (XML_MKUP_STAG == xpe->xper_type)
    {
      long save = xpe->xper_pos;
      for (;;)
	{
	  fill_xper_entity (xpe, xpe->xper_next_item);
	  if (XML_MKUP_ETAG == xpe->xper_type)
	    break;
	  dk_set_push (&children, xp_copy_to_xte_subtree ((xml_entity_t *)xpe));
	  if (XML_MKUP_STAG == xpe->xper_type)
	    fill_xper_entity (xpe, xpe->xper_end);
	}
      fill_xper_entity (xpe, save);
    }
  if (res_len != res_fill)
    {
      int newresboxlen = res_fill * sizeof(caddr_t);
      caddr_t *newres = (caddr_t *)dk_alloc_box (newresboxlen, DV_ARRAY_OF_POINTER);
      memcpy (newres, res, newresboxlen);
      dk_free_box ((box_t) res);
      res = newres;
    }
  children = dk_set_nreverse (children);
  dk_set_push (&children, (void *)res);
  return (caddr_t *)list_to_array (children);
}


caddr_t ** xp_copy_to_xte_forest (xml_entity_t *xe)
{
  GPF_T;
  return NULL;
}


void xp_emulate_input (xml_entity_t *xe, struct vxml_parser_s *parser)
{
  sqlr_error ("42000", "Unable to pass persistent XML data to the XML validator.");
}


caddr_t xp_find_expanded_name_by_qname (xml_entity_t *xe, const char *qname, int use_default)
{
#if 0
  sqlr_error ("42000", "Unable to convert a qname to expanded name using persistent XML data as context; functions like expand-qname() are for XML Tree documents only");
#else
  return NULL;
#endif
}


dk_set_t xp_namespace_scope (xml_entity_t *xe, int use_default)
{
#if 0
  sqlr_error ("42000", "Unable to collect namespace data from persistent XML.");
#else
  return NULL;
#endif
}

/*
   int
   xp_equal (xml_entity_t * xe1, xml_entity_t * xe2)
   {
   xper_entity_t *xpe1 = (xper_entity_t *) xe1;
   xper_entity_t *xpe2 = (xper_entity_t *) xe2;

   xper_dbg_print ("xp_equal\n");

   if (xpe1->_ != xpe2->_ || xpe1->xe_doc.xd != xpe2->xe_doc.xd ||
   xpe1->xper_pos != xpe2->xper_pos)
   return 0;

   return 1;
   }
 */


int
xp_is_same_as (const xml_entity_t * this_xe, const xml_entity_t * that_xe)
{
  if (XE_IS_PERSISTENT (that_xe))
    {
      const xper_entity_t *this_xpe = (const xper_entity_t *) (this_xe);
      const xper_entity_t *that_xpe = (const xper_entity_t *) (that_xe);
      if (this_xpe->xe_doc.xpd != that_xpe->xe_doc.xpd)
	return 0;
      if (this_xpe->xper_pos != that_xpe->xper_pos)
	return 0;
      if (this_xpe->xe_attr_name != that_xpe->xe_attr_name)
	return 0;
      return 1;
    }
  return 0;
}


static caddr_t xp_build_expanded_name (xper_entity_t *xpe)
{
  char *name;
  caddr_t ns;
  size_t len;
  caddr_t exp_name;
  size_t nslen;
  size_t local_len;
  char *colon;
  name = xpe->xper_name;
  ns = xper_get_namespace (xpe, xpe->xper_ns_pos);
  len = box_length (name)-1;
  if (uname___empty == ns)
    return box_copy (name);
  nslen = box_length (ns);
  colon = name + len;
  while ((colon > name) && (colon[-1] != ':')) colon--;
  local_len = (name + len) - colon;
  BOX_DV_UNAME_COLONCONCAT4 (exp_name, ns, colon, local_len);
  dk_free_box (ns);
  return exp_name;
}


static caddr_t
xp_element_name (xml_entity_t * xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xper_dbg_print ("xp_element_name\n");
  switch (xpe->xper_type)
    {
    case XML_MKUP_TEXT:
      return uname__txt;
    case XML_MKUP_COMMENT:
      return uname__comment;
    case XML_MKUP_REF:
      return uname__ref;
    case XML_MKUP_PI:
      return uname__pi;
    default:
      if ((0 == xpe->xper_ns_pos) || (' ' == xpe->xper_name[0]))
	{
	  caddr_t res = box_copy (xpe->xper_name);
	  return res;
	}
      return xp_build_expanded_name (xpe);
    }
}


static caddr_t
xp_ent_name (xml_entity_t * xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xper_dbg_print ("xp_node_name\n");
  if (xe->xe_attr_name)
    return box_copy (xe->xe_attr_name);
  switch (xpe->xper_type)
    {
    case XML_MKUP_TEXT:
      return uname___empty;
    case XML_MKUP_COMMENT:
      return uname___empty;
    case XML_MKUP_REF:
      return box_copy (xpe->xper_name);
    case XML_MKUP_PI:
      return box_copy (xpe->xper_name);
    default:
      if ((0 == xpe->xper_ns_pos) || (' ' == xpe->xper_name[0]))
	return box_copy (xpe->xper_name);
      return xp_build_expanded_name (xpe);
    }
}


void
write_escaped (dk_session_t * ses, unsigned char *ptr, int len, wcharset_t *charset)
{
  unsigned char *end = ptr+len;
  for (/* no init*/; ptr < end; ptr++)
    {
      switch (*ptr)
	{
	case '<':
	  SES_PRINT (ses, "&lt;");
	  break;
	case '>':
	  SES_PRINT (ses, "&gt;");
	  break;
	case '&':
	  SES_PRINT (ses, "&amp;");
	  break;
	case '\'':
	  SES_PRINT (ses, "&#39;");
	  break;
	case '"':
	  SES_PRINT (ses, "&quot;");
	  break;
	case ' ':
	case '\r':
	case '\n':
	case '\t':
	  session_buffered_write_char (*ptr, ses);
	  break;
	default:
	  if (((charset != CHARSET_UTF8) && (0x7F <= *ptr)) || (0x20 > *ptr))
	    {
	      unichar uni = eh_decode_char__UTF8 ((__constcharptr *)&ptr, (char *)end);
	      unsigned char encoded_uni =
		((NULL != charset) ?
		  (unsigned char)((ptrlong) gethash ((void *) (ptrlong) uni, charset->chrs_ht)) :
		  (unsigned char)((uni & ~0xFF) ? 0 : uni) );
	      ptr--; /* to compensate the 'ptr++' in for */
	      if (0x20 > encoded_uni)
		{
		  char tmp[32];
		  snprintf (tmp, sizeof (tmp), "&#%d;", (int)(uni));
		  SES_PRINT (ses, tmp);
		}
	      else
		  session_buffered_write_char ((char)(encoded_uni), ses);
	    }
	  else
	    session_buffered_write_char (*ptr, ses);
	}
    }
}

void
write_escaped_attvalue (dk_session_t * ses, unsigned char *ptr, int len, wcharset_t *charset)
{
  unsigned char *end = ptr+len;
  for (/* no init*/; ptr < end; ptr++)
    {
      switch (*ptr)
	{
	case '<':
	  SES_PRINT (ses, "&lt;");
	  break;
	case '>':
	  SES_PRINT (ses, "&gt;");
	  break;
	case '&':
	  SES_PRINT (ses, "&amp;");
	  break;
/* Disabled due to Bug3166
	case '\'':
	  SES_PRINT (ses, "&#39;");
*/
	  break;
	case '"':
	  SES_PRINT (ses, "&quot;");
	  break;
	default:
	  if ((charset != CHARSET_UTF8) && ((0x7F <= *ptr) || (0x20 > *ptr)))
	    {
	      unichar uni = eh_decode_char__UTF8 ((__constcharptr *)&ptr, (char *)end);
	      unsigned char encoded_uni =
		((NULL != charset) ?
		  (unsigned char)((ptrlong) gethash ((void *) (ptrlong) uni, charset->chrs_ht)) :
		  (unsigned char)((uni & ~0xFF) ? 0 : uni) );
	      ptr--; /* to compensate the 'ptr++' in for */
	      if (0x20 > encoded_uni)
		{
		  char tmp[32];
		  snprintf (tmp, sizeof (tmp), "&#%d;", (int)(uni));
		  SES_PRINT (ses, tmp);
		}
	      else
		  session_buffered_write_char ((char)(encoded_uni), ses);
	    }
	  else
	    session_buffered_write_char (*ptr, ses);
	}
    }
}

void
write_escaped_comment (dk_session_t * ses, unsigned char *ptr, int len, wcharset_t *charset)
{
  unsigned char *begin = ptr;
  unsigned char *end = ptr+len;
  for (/* no init*/; ptr < end; ptr++)
    {
      if (('>' == *ptr) && (ptr > begin + 1) && ('-' == ptr[-1]) && ('-' == ptr[-2]))
	SES_PRINT (ses, "&gt;");
      else
	{
	  if ((charset != CHARSET_UTF8) && ((0x7F <= *ptr) || (0x20 > *ptr)))
	    {
	      unichar uni = eh_decode_char__UTF8 ((__constcharptr *)&ptr, (char *)end);
	      unsigned char encoded_uni =
		((NULL != charset) ?
		  (unsigned char)((ptrlong) gethash ((void *) (ptrlong) uni, charset->chrs_ht)) :
		  (unsigned char)((uni & ~0xFF) ? 0 : uni) );
	      ptr--; /* to compensate the 'ptr++' in for */
	      if (0 == encoded_uni)
		{
		  char tmp[32];
		  snprintf (tmp, sizeof (tmp), "&#%d;", (int)(uni));
		  SES_PRINT (ses, tmp);
		}
	      else
		  session_buffered_write_char ((char)(encoded_uni), ses);
	    }
	  else
	    session_buffered_write_char (*ptr, ses);
	}
    }
}

void
write_escaped_pitext (dk_session_t * ses, unsigned char *ptr, int len, wcharset_t *charset)
{
#ifdef XPER_DEBUG
  unsigned char *begin = ptr;
#endif
  unsigned char *end = ptr+len;
  for (/* no init*/; ptr < end; ptr++)
    {
      if ((charset != CHARSET_UTF8) && ((0x7F <= *ptr) || (0x20 > *ptr)))
	{
	  unichar uni = eh_decode_char__UTF8 ((__constcharptr *)&ptr, (char *)end);
	  unsigned char encoded_uni =
	    ((NULL != charset) ?
	      (unsigned char)((ptrlong) gethash ((void *) (ptrlong) uni, charset->chrs_ht)) :
	      (unsigned char)((uni & ~0xFF) ? 0 : uni) );
	  ptr--; /* to compensate the 'ptr++' in for */
	  if (0 == encoded_uni)
	    {
	      char tmp[32];
	      snprintf (tmp, sizeof (tmp), "&#%d;", (int)(uni));
	      SES_PRINT (ses, tmp);
	    }
	  else
	    session_buffered_write_char ((char)(encoded_uni), ses);
	}
      else
	session_buffered_write_char (*ptr, ses);
    }
}

void
DBG_NAME(xp_string_value) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp)
{
#ifdef XPER_DEBUG
  wcharset_t *charset = QST_CHARSET (xe->xe_doc.xd->xd_qi);
#endif
  xper_entity_t *xpe = (xper_entity_t *) xe;
  caddr_t box = NULL;
  long pos;
  long epos;
  unsigned char *ptr;
  int type;
  int namelen;
  long num_word, atts_fill, addons, alen;
  dk_session_t *ses = strses_allocate ();
  switch (xpe->xper_type)
    {
    case XML_MKUP_COMMENT:
      session_buffered_write (ses, xpe->xper_name, box_length (xpe->xper_name) - 1);
      goto done;
    case XML_MKUP_PI:
      {
	long len, num_word, atts_fill, addons;
	box = get_tag_data (xpe, xpe->xper_pos);
	len = box_length (box);
	ptr = (unsigned char *) (box + 1);
	ptr += full_dv_string_length (ptr);
	ptr += STR_ATTR_NO_OFF;
	num_word = LONG_REF_NA (ptr);
	ptr += 4;
	atts_fill = num_word & 0xFFFF;
	addons = ((unsigned long) (num_word)) >> 16;
	ptr += addons;
	for (; atts_fill > 1; atts_fill -= 2)
	  {
	    namelen = (int) skip_string_length (&ptr);
	    ptr += namelen;
	    alen = (long) skip_string_length (&ptr);
	    session_buffered_write (ses, (const char *) ptr, alen);
	    ptr += alen;
	  }
	goto done;
      }
    }
  box = get_tag_data (xpe, xpe->xper_pos);
  xper_dbg_print ("xp_string_value\n");

  if (DV_XML_MARKUP == box_tag (box))
    {
      epos = xpe->xper_end;
      for (pos = xpe->xper_pos + box_length (box) + 5; pos < epos; /* no step */)
	{
#if 0
	  long box_pos = pos;
#endif
	  dk_free_box (box);
	  box = get_tag_data (xpe, pos);
	  pos += box_length (box) + ((DV_SHORT_STRING_SERIAL == box_tag (box)) ? 2 : 5);
	  if ((DV_STRING == box_tag (box)) || (DV_SHORT_STRING_SERIAL == box_tag (box)))
	    session_buffered_write (ses, box, box_length (box));
	  else
	    {
	      ptr = (unsigned char *) box;
	      type = *ptr++;
	      namelen = (int) skip_string_length (&ptr);
	      switch (type)
		{
		case XML_MKUP_PI:
		  ptr += namelen + STR_ATTR_NO_OFF;
		  num_word = LONG_REF_NA (ptr);
		  ptr += 4;
		  atts_fill = num_word & 0xFFFF;
		  addons = ((unsigned long) (num_word)) >> 16;
		  ptr += addons;
		  for (; atts_fill > 1; atts_fill -= 2)
		    {
		      namelen = (int) skip_string_length (&ptr);
		      ptr += namelen;
		      alen = (long) skip_string_length (&ptr);
		      session_buffered_write (ses, (const char *) ptr, alen);
		      ptr += alen;
		    }
		  break;
#if 0
/* TBD: references should be extended and converted to string, but probably with disabled signaling of errors. */
		case XML_MKUP_REF:
		  {
		    xper_entity_t *ref_xpe = (xper_entity_t *)xe->_->xe_copy (xe);
		    fill_xper_entity (ref_xpe, box_pos);
		    if (XI_RESULT == xp_down ((xml_entity_t *) ref_xpe, (XT *) XP_NODE))
		      {
		        caddr_t ref_val = NULL;
/* There's no transit allowed in the following line, thus it climbs up to the root of the referenced doc */
			ref_xpe->_->xe_up ((xml_entity_t *) ref_xpe, (XT *) XP_NODE, 0);
		        ref_xpe->_->xe_string_value ((xml_entity_t *) ref_xpe, &ref_val, DV_STRING);
		        session_buffered_write (ses, ref_val, box_length (ref_val) - 1);
		      }
		    dk_free_box (ref_xpe);
		    break;
		  }
#endif
		case XML_MKUP_COMMENT:
		  session_buffered_write (ses, (const char *) ptr, namelen);
		  break;
	      }
	    }
	}
      goto done;
    }
  if ((DV_STRING == box_tag (box)) || (DV_SHORT_STRING_SERIAL == box_tag (box)))
    {
      long box_pos = pos = xpe->xper_pos;
      for (;;)
	{
	  session_buffered_write (ses, box, box_length (box));
	  box_pos = pos;
	  pos += box_length (box) + ((DV_SHORT_STRING_SERIAL == box_tag (box)) ? 2 : 5);
	  dk_free_box (box);
	  box = get_tag_data (xpe, pos);
	  if ((DV_STRING == box_tag (box)) || (DV_SHORT_STRING_SERIAL == box_tag (box)))
	    continue;
#if 0
/* TBD: support for strings that starts in one subdocument and continues in a nested reference */
	  if (box[0] == XML_MKUP_REF)
	    {
	      xper_entity_t *ref_xpe = (xper_entity_t *)xe->_->xe_copy (xe);
	      fill_xper_entity (ref_xpe, box_pos);
	      if (XI_RESULT == xp_down ((xml_entity_t *) ref_xpe, (XT *) XP_NODE))
		{
		  caddr_t ref_val = NULL;
		  ref_xpe->_.xe_string_value ((xml_entity_t *) ref_xpe, &ref_val, DV_STRING);
		  session_buffered_write (ses, ref_val, box_length (ref_val) - 1);
		}
	      dk_free_box (ref_xpe);
	      continue;
	    }
#endif
	  break;
	}
      goto done;
    }
done:
  dk_free_box (box);
  if (strses_length (ses) > 10000000)
    sqlr_new_error ("42000", "XE005", "String value is longer than 10000000 bytes: source fragment of persistent XML is too large.");
  box = DBG_NAME(strses_string) (DBG_ARGS ses);
  strses_free (ses);
  if (DV_NUMERIC == dtp)
    {
      caddr_t val = xp_box_number (box);
      XP_SET (ret, val);
      dk_free_box (box);
      return;
    }
  XP_SET (ret, box);
}

int
xp_string_value_is_nonempty (xml_entity_t * xe)
{
#ifdef XPER_DEBUG
  wcharset_t *charset = QST_CHARSET (xe->xe_doc.xd->xd_qi);
#endif
  xper_entity_t *xpe = (xper_entity_t *) xe;
  caddr_t box = NULL;
  long pos;
  long epos;
  unsigned char *ptr;
  int type;
  int namelen;
  long num_word, atts_fill, addons, alen;
  switch (xpe->xper_type)
    {
    case XML_MKUP_COMMENT:
      return (1 < box_length (xpe->xper_name));
    case XML_MKUP_PI:
      {
	long len, num_word, atts_fill, addons;
	box = get_tag_data (xpe, xpe->xper_pos);
	len = box_length (box);
	ptr = (unsigned char *) (box + 1);
	ptr += full_dv_string_length (ptr);
	ptr += STR_ATTR_NO_OFF;
	num_word = LONG_REF_NA (ptr);
	ptr += 4;
	atts_fill = num_word & 0xFFFF;
	addons = ((unsigned long) (num_word)) >> 16;
	ptr += addons;
	for (; atts_fill > 1; atts_fill -= 2)
	  {
	    namelen = (int) skip_string_length (&ptr);
	    ptr += namelen;
	    alen = (long) skip_string_length (&ptr);
	    if (alen)
	      return 1;
	    ptr += alen;
	  }
	return 0;
      }
    }
  box = get_tag_data (xpe, xpe->xper_pos);
  xper_dbg_print ("xp_string_value\n");

  if (DV_XML_MARKUP == box_tag (box))
    {
      epos = xpe->xper_end;
      for (pos = xpe->xper_pos + box_length (box) + 5; pos < epos; /* no step */)
	{
#if 0
	  long box_pos = pos;
#endif
	  dk_free_box (box);
	  box = get_tag_data (xpe, pos);
	  pos += box_length (box) + ((DV_SHORT_STRING_SERIAL == box_tag (box)) ? 2 : 5);
	  if ((DV_STRING == box_tag (box)) || (DV_SHORT_STRING_SERIAL == box_tag (box)))
	    {
	      if (box_length (box))
	        return 1;
	    }
	  else
	    {
	      ptr = (unsigned char *) box;
	      type = *ptr++;
	      namelen = (int) skip_string_length (&ptr);
	      switch (type)
		{
		case XML_MKUP_PI:
		  ptr += namelen + STR_ATTR_NO_OFF;
		  num_word = LONG_REF_NA (ptr);
		  ptr += 4;
		  atts_fill = num_word & 0xFFFF;
		  addons = ((unsigned long) (num_word)) >> 16;
		  ptr += addons;
		  for (; atts_fill > 1; atts_fill -= 2)
		    {
		      namelen = (int) skip_string_length (&ptr);
		      ptr += namelen;
		      alen = (long) skip_string_length (&ptr);
		      if (alen)
			return 1;
		      ptr += alen;
		    }
		  break;
#if 0
/* TBD: references should be extended and converted to string, but probably with disabled signaling of errors. */
		case XML_MKUP_REF:
		  {
		    xper_entity_t *ref_xpe = (xper_entity_t *)xe->_->xe_copy (xe);
		    fill_xper_entity (ref_xpe, box_pos);
		    if (XI_RESULT == xp_down ((xml_entity_t *) ref_xpe, (XT *) XP_NODE))
		      {
		        caddr_t ref_val = NULL;
/* There's no transit allowed in the following line, thus it climbs up to the root of the referenced doc */
			ref_xpe->_->xe_up ((xml_entity_t *) ref_xpe, (XT *) XP_NODE, 0);
		        ref_xpe->_->xe_string_value ((xml_entity_t *) ref_xpe, &ref_val, DV_STRING);
		        session_buffered_write (ses, ref_val, box_length (ref_val) - 1);
		      }
		    dk_free_box (ref_xpe);
		    break;
		  }
#endif
		case XML_MKUP_COMMENT:
		  if (namelen)
		    return 1;
		  break;
	      }
	    }
	}
      return 0;
    }
  if ((DV_STRING == box_tag (box)) || (DV_SHORT_STRING_SERIAL == box_tag (box)))
    {
      long box_pos = pos = xpe->xper_pos;
      for (;;)
	{
	  if (box_length (box))
	    return 1;
	  box_pos = pos;
	  pos += box_length (box) + ((DV_SHORT_STRING_SERIAL == box_tag (box)) ? 2 : 5);
	  dk_free_box (box);
	  box = get_tag_data (xpe, pos);
	  if ((DV_STRING == box_tag (box)) || (DV_SHORT_STRING_SERIAL == box_tag (box)))
	    continue;
#if 0
/* TBD: support for strings that starts in one subdocument and continues in a nested reference */
	  if (box[0] == XML_MKUP_REF)
	    {
	      xper_entity_t *ref_xpe = (xper_entity_t *)xe->_->xe_copy (xe);
	      fill_xper_entity (ref_xpe, box_pos);
	      if (XI_RESULT == xp_down ((xml_entity_t *) ref_xpe, (XT *) XP_NODE))
		{
		  caddr_t ref_val = NULL;
		  ref_xpe->_.xe_string_value ((xml_entity_t *) ref_xpe, &ref_val, DV_STRING);
		  session_buffered_write (ses, ref_val, box_length (ref_val) - 1);
		}
	      dk_free_box (ref_xpe);
	      continue;
	    }
#endif
	  break;
	}
      return 0;
    }
  return 0;
}


struct ns_def_s
{
  caddr_t nsd_prefix;		/*!< prefix assigned to a namespace */
  caddr_t nsd_strg;		/*!< namespace string itself */
  ptrlong nsd_pos;		/*!< position of namespace string */
  ptrlong nsd_depth;		/*!< nesting level where the definition is found, negative for undefined */
};

typedef struct ns_def_s ns_def_t;

#define NSD_FILL(nsd,prefix,strg,pos,depth) \
  nsd->nsd_prefix = (prefix); \
  nsd->nsd_strg = (strg); \
  nsd->nsd_pos = (pos); \
  nsd->nsd_depth = (depth)

#define NSD_FREE(nsd) \
  dk_free_box (nsd->nsd_prefix); \
  dk_free_box (nsd->nsd_strg); \
  dk_free_box ((caddr_t)(nsd));

dk_set_t
xp_create_ns_dict (xper_entity_t * xpe)
{
  long pos = xpe->xper_pos;
  caddr_t box = NULL;
  unsigned char *ptr, *avalue, *colon, *name_end, *ns_pos_field;
  long ns_pos;
  int depth = 0;
  int type;
  int namelen, anmlen;
  long num_word, atts_fill, addons, alen;
  int dtp;
  dk_set_t outer_items = NULL;
  dk_set_t inner_items = NULL;
  dk_set_t new_items = NULL;
  ns_def_t *new_def;
  caddr_t error = NULL;

before_element:

  box = get_tag_data (xpe, pos);
  ptr = (unsigned char *) box;
  dtp = box_tag (box);
  switch (dtp)
    {
    case DV_XML_MARKUP:
      type = *ptr++;
      namelen = (int) skip_string_length (&ptr);
      switch (type)
	{
	case XML_MKUP_STAG:
/* Start tag: processing of name */
	  ns_pos_field = ptr + namelen + STR_NS_OFF;
	  ns_pos = LONG_REF_NA (ns_pos_field);
	  if ((0 < ns_pos) && (XPER_ROOT_POS != pos))
	    {
	      for (colon = ptr, name_end = ptr + namelen; /* no check */ ; colon++)
		{
		  if (colon >= name_end)
		    {
		      colon = ptr;
		      break;
		    }
		  if (colon[0] == ':')
		    break;
		}
	      colon[0] = '\0';
	      DO_SET (ns_def_t *, def, &outer_items)
	      {
		if (!strcmp (def->nsd_prefix, (const char *) ptr))
		  goto after_tag_new_def;	/* see below */
	      }
	      END_DO_SET ()
		  DO_SET (ns_def_t *, def, &inner_items)
	      {
		if (!strcmp (def->nsd_prefix, (const char *) ptr))
		  goto after_tag_new_def;	/* see below */
	      }
	      END_DO_SET ()
		  new_def = (ns_def_t *) dk_alloc_box (sizeof (ns_def_t), DV_ARRAY_OF_LONG);
	      NSD_FILL (new_def, box_string ((char *) ptr), NULL, ns_pos, -1);
	      dk_set_push (&new_items, new_def);
	    }
	after_tag_new_def:
/* Start tag: Processing of attributes */
	  ptr += namelen + STR_ATTR_NO_OFF;
	  num_word = LONG_REF_NA (ptr);
	  ptr += 4;
	  atts_fill = num_word & 0xFFFF;
	  addons = ((unsigned long) (num_word)) >> 16;
	  ptr += addons;

	  for (; atts_fill > 1; atts_fill -= 2)		/* loop by attributes */
	    {
	      int adtp = *ptr;
	      alen = (long) skip_string_length (&ptr);
	      avalue = ptr + alen;
	      switch (adtp)
		{
		case DV_ARRAY_OF_POINTER:	/* name with namespace */
		  anmlen = (int) skip_string_length (&ptr);
		  for (colon = ptr, name_end = ptr + anmlen; colon < name_end; colon++)
		    {
		      if (colon[0] != ':')
			continue;
		      colon[0] = '\0';
		      DO_SET (ns_def_t *, def, &new_items)
		      {
			if (!strcmp (def->nsd_prefix, (const char *) ptr))
			  goto after_attr_new_def;	/* see below */
		      }
		      END_DO_SET ()
		      DO_SET (ns_def_t *, def, &outer_items)
		      {
			if (!strcmp (def->nsd_prefix, (const char *) ptr))
			  goto after_attr_new_def;	/* see below */
		      }
		      END_DO_SET ()
			  DO_SET (ns_def_t *, def, &inner_items)
		      {
			if (!strcmp (def->nsd_prefix, (const char *) ptr))
			  goto after_attr_new_def;	/* see below */
		      }
		      END_DO_SET ()
		      ns_pos_field = ptr + anmlen + 1;
		      ns_pos = LONG_REF_NA (ns_pos_field);
		      new_def = (ns_def_t *) dk_alloc_box (sizeof (ns_def_t), DV_ARRAY_OF_LONG);
		      NSD_FILL (new_def, box_string ((char *) ptr), NULL, ns_pos, -1);
		      dk_set_push (&new_items, new_def);
		    after_attr_new_def:
		      break;
		    }
		  break;
		case DV_STRING:
		case DV_SHORT_STRING_SERIAL:
		  if (strncmp ((const char *) ptr, "xmlns", 5 /* = strlen("xmlns") */ ))
		    break;
		  if (':' == ptr[5]) /* declaration of explicit prefix */
		    {
		      new_def = (ns_def_t *) dk_alloc_box (sizeof (ns_def_t), DV_ARRAY_OF_LONG);
		      NSD_FILL (new_def,
			  box_dv_short_nchars ((const char *) ptr + 6, alen - 6),	/* rest of attribute name is a prefix */
			  NULL,
			  pos + (avalue - (unsigned char *) (box)),	/* position of attribute value in BLOB is a position of namespace */
			  depth);
		      dk_set_push (&inner_items, new_def);
		    }
		  else if (5 == alen) /* declaration of implicit prefix */
		    {
		      new_def = (ns_def_t *) dk_alloc_box (sizeof (ns_def_t), DV_ARRAY_OF_LONG);
		      NSD_FILL (new_def,
			  box_string (""),	/* no prefix */
			  NULL,
			  pos + (avalue - (unsigned char *) (box)),	/* position of attribute value in BLOB is a position of namespace */
			  depth);
		      dk_set_push (&inner_items, new_def);
		    }
		  break;
		default:
		  error = srv_make_new_error ("42000", "XM006",
		      "Error while serializing XML_PERSISTENT: invalid box tag");
		  goto emit_error;
		}
	      ptr = avalue;	/* skip attribute name */
	      alen = (long) skip_string_length (&ptr);
	      ptr += alen;	/* skip attribute value */
	    }			/* end of loop by attributes */
/* Start tag: sorting of new items: removal of inner items and storing of outer */
	  for (;;)
	    {
	    before_check_new_item:
	      if (NULL == new_items)
		break;
	      new_def = (ns_def_t *) dk_set_pop (&new_items);
	      DO_SET (ns_def_t *, def, &outer_items)
		{
		  if (!strcmp (def->nsd_prefix, new_def->nsd_prefix))
		    {
		      NSD_FREE (new_def);
		      goto before_check_new_item;	/* see above */
		    }
		}
	      END_DO_SET ()
	      DO_SET (ns_def_t *, def, &inner_items)
		{
		  if (!strcmp (def->nsd_prefix, new_def->nsd_prefix))
		    {
		      NSD_FREE (new_def);
		      goto before_check_new_item;	/* see above */
		    }
		}
	      END_DO_SET ()
	      dk_set_push (&outer_items, new_def);
	    }
	  depth++;
	  break;
	case XML_MKUP_ETAG:
	  depth--;
	  while (NULL != inner_items)
	    {
	      ns_def_t *itm = ((ns_def_t *) (inner_items->data));
	      if (itm->nsd_depth < depth)
		break;
	      NSD_FREE (itm);
	      dk_set_pop (&inner_items);
	    }
	  break;
	case XML_MKUP_PI:
	case XML_MKUP_REF:
	case XML_MKUP_COMMENT:
	  break;
	default:
	  error = srv_make_new_error ("42000", "XM007",
	      "Error while serializing XML_PERSISTENT: invalid markup type");
	  goto emit_error;
	}
      break;
    case DV_SHORT_STRING_SERIAL:
    case DV_STRING:
      break;
    default:
      error = srv_make_new_error ("42000", "XM008",
	  "Error while serializing XML_PERSISTENT: invalid box tag");
      goto emit_error;
    }
  pos += ((DV_SHORT_STRING_SERIAL == dtp) ? 2 : 5);
  pos += box_length (box);
  dk_free_box (box);
  if (pos <= xpe->xper_end)
    goto before_element;	/* see above */
  return outer_items;
emit_error:
  if (NULL != box)
    dk_free_box (box);
  DO_SET (ns_def_t *, def, &new_items)
  {
    NSD_FREE (def);
  }
  END_DO_SET ()
  dk_set_free (new_items);
  DO_SET (ns_def_t *, def, &inner_items)
  {
    NSD_FREE (def);
  }
  END_DO_SET ()
  dk_set_free (inner_items);
  DO_SET (ns_def_t *, def, &outer_items)
  {
    NSD_FREE (def);
  }
  END_DO_SET ()
  dk_set_free (outer_items);
  sqlr_resignal (error);
  return NULL;			/* never reached */
}

long
xp_serialize_element (xper_entity_t * xpe, long pos, dk_session_t * ses, dk_set_t * outer_ns_dict, wcharset_t *charset)
{
  caddr_t box = get_tag_data (xpe, pos);
  unsigned char *ptr = (unsigned char *) box;
  int type;
  int namelen;
  long num_word, atts_fill, addons, alen, end_pos;
  int dtp = box_tag (box);
  pos += ((DV_SHORT_STRING_SERIAL == dtp) ? 2 : 5);
  pos += box_length (box);
  switch (dtp)
    {
    case DV_XML_MARKUP:
      type = *ptr++;

      namelen = (int) skip_string_length (&ptr);

      switch (type)
	{
	case XML_MKUP_STAG:
	  if (' ' == ptr[0])
	    break;
	  session_buffered_write_char ('<', ses);
	  write_escaped (ses, ptr, namelen, charset);
	  /* Now it's time to imprint all items from additional dictionary */
	  if (outer_ns_dict[0])
	    {
	      DO_SET (ns_def_t *, def, outer_ns_dict)
	      {
		if (NULL != def->nsd_strg)
		  {
		    SES_PRINT (ses, " xmlns");
		    if ('\0' != def->nsd_prefix[0])
		      {
			session_buffered_write_char (':', ses);
			write_escaped (ses, (unsigned char *) def->nsd_prefix,
					(int) strlen (def->nsd_prefix), charset);
		      }
		    SES_PRINT (ses, "=\"");
		    write_escaped_attvalue (ses, (unsigned char *) def->nsd_strg, box_length (def->nsd_strg) - 1, charset);
		    session_buffered_write_char ('"', ses);
		  }
		NSD_FREE (def);
	      }
	      END_DO_SET ()
	      dk_set_free (outer_ns_dict[0]);
	      outer_ns_dict[0] = NULL;
	    }
	  ptr += namelen + STR_END_TAG_OFF;
	  end_pos = LONG_REF_NA (ptr);
	  ptr += (STR_ATTR_NO_OFF - STR_END_TAG_OFF);
	  num_word = LONG_REF_NA (ptr);
	  ptr += 4;
	  atts_fill = num_word & 0xFFFF;
	  addons = ((unsigned long) (num_word)) >> 16;
	  ptr += addons;
	  for (; atts_fill > 1; atts_fill -= 2)
	    {
	      int adtp = *ptr;

	      session_buffered_write_char (' ', ses);
	      alen = (long) skip_string_length (&ptr);
	      if (DV_ARRAY_OF_POINTER == adtp)
		{
		  char *rem = (char *) ptr;
		  int anmlen = (int) skip_string_length (&ptr);
		  write_escaped (ses, ptr, anmlen, charset);
		  ptr = (unsigned char *) rem;
		}
	      else
		write_escaped (ses, ptr, alen, charset);

	      ptr += alen;

	      SES_PRINT (ses, "=\"");
	      alen = (long) skip_string_length (&ptr);
	      write_escaped_attvalue (ses, ptr, alen, charset);
	      session_buffered_write_char ('"', ses);
	      ptr += alen;
	    }
	  if (pos == end_pos)
	    {
	      SES_PRINT (ses, " /");
	      dk_free_box (box);
	      box = get_tag_data (xpe, pos);
	      dtp = box_tag (box);
	      pos += ((DV_SHORT_STRING_SERIAL == dtp) ? 2 : 5);
	      pos += box_length (box);
	    }
	  session_buffered_write_char ('>', ses);
	  break;
	case XML_MKUP_ETAG:
	  if (' ' == ptr[0])
	    break;
	  SES_PRINT (ses, "</");
	  write_escaped (ses, ptr, namelen, charset);
	  session_buffered_write_char ('>', ses);
	  break;
	case XML_MKUP_PI:
	  SES_PRINT (ses, "<?");
	  write_escaped (ses, ptr, namelen, charset);
	  ptr += namelen + STR_ATTR_NO_OFF;
	  num_word = LONG_REF_NA (ptr);
	  ptr += 4;
	  atts_fill = num_word & 0xFFFF;
	  addons = ((unsigned long) (num_word)) >> 16;
	  ptr += addons;
	  for (; atts_fill > 1; atts_fill -= 2)
	    {
	      namelen = (int) skip_string_length (&ptr);
	      ptr += namelen;
	      alen = (long) skip_string_length (&ptr);
	      session_buffered_write_char (' ', ses);
	      write_escaped_pitext (ses, ptr, alen, charset);
	      ptr += alen;
	    }
	  SES_PRINT (ses, "?>");
	  break;
	case XML_MKUP_REF:
	  session_buffered_write_char ('&', ses);
	  write_escaped (ses, ptr, namelen, charset);
	  session_buffered_write_char (';', ses);
	  break;
	case XML_MKUP_COMMENT:
	  SES_PRINT (ses, "<!--");
	  write_escaped_comment (ses, ptr, namelen, charset);
	  SES_PRINT (ses, "-->");
	  break;
	default:
	  dk_free_box (box);
	  sqlr_new_error ("XE000", "XP9B2", "Error while serializing XML_PERSISTENT: invalid markup type %d", xpe->xper_type);
	}
      break;
    case DV_STRING: case DV_SHORT_STRING_SERIAL:
      write_escaped (ses, (unsigned char *) box, box_length (box), charset);
      break;
    default:
      dk_free_box (box);
      sqlr_new_error ("XE000", "XP9B3", "Error while serializing XML_PERSISTENT: invalid box tag %d", dtp);
      break;
    }
  dk_free_box (box);
  return pos;
}

void
xp_serialize (xml_entity_t * xe, dk_session_t * ses)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  wcharset_t * charset = NULL;
  dk_set_t dict = NULL;
  long pos = xpe->xper_pos;
  xper_dbg_print ("xp_serialize\n");
  charset = wcharset_by_name_or_dflt (xe->xe_doc.xtd->xout_encoding, xe->xe_doc.xd->xd_qi);
  if (XML_MKUP_STAG != xpe->xper_type)
    {
      pos = xp_serialize_element (xpe, pos, ses, &dict, charset);
      return;
    }

  dict = xp_create_ns_dict (xpe);	/*dict = NULL; */
  DO_SET (ns_def_t *, def, &dict)
  {
    def->nsd_strg = xper_get_namespace (xpe, (long) def->nsd_pos);
  }
  END_DO_SET ()

  while (pos <= xpe->xper_end)
    {
      pos = xp_serialize_element (xpe, pos, ses, &dict, charset);
    }
  DO_SET (ns_def_t *, def, &dict)
  {
    NSD_FREE (def);
  }
  END_DO_SET ()
      dk_set_free (dict);
}

struct xper_vtbf_env_s
{
  long xve_closing_pos;		/*!< Position of closing tag where this environment will end */
  caddr_t xve_vtb_name;		/*!< Tag name to be indexed, in form '<'[ns_uri]':'localname */
  lang_handler_t *xve_outer_lh;	/*!< Language outside the environment */
  struct xper_vtbf_env_s *xve_outer;	/*!< Pointer to outer (ascendant) environment, or NULL */
};

typedef struct xper_vtbf_env_s xper_vtbf_env_t;

/* IvAn/TextXperIndex/000815 Persistent XML support functions added */
const char *
xper_elements_vtb_feed (xper_entity_t * xpe, vt_batch_t * vtb, lh_word_callback_t * cbk, lang_handler_t * root_lh, caddr_t * textbufptr)
{
  caddr_t box;
  unsigned char *ptr, *start_tag_longs, *start_attrs, *start_name;
  char type;
  int namelen, vallen, wordlen;
  long num_word, atts_fill, atts_ctr, addons;
  int dtp;
  const char *errmsg = NULL;
  long curr_el_pos = XPER_ROOT_POS;	/* position of current element in document BLOB */
  long ns_pos;
  caddr_t ns_uri;
  xe_word_ranges_t predicted;
  wpos_t old_word_pos;
  char word_hider = 0;
  const unsigned char *s_frag_begin;
  unsigned char *box_end;
  unsigned char *newbuf;
  int space_found, text_buf_use, text_buf_size, newbuf_len, frag_len;
  long el_length;
  unichar uchr;
  lang_handler_t *active_lang = root_lh;
  lang_handler_t *new_lang;
  caddr_t vtb_name;
  xper_vtbf_env_t *env_stack = NULL;
  if (curr_el_pos > xpe->xper_end)
    return NULL;
  if ((0 != vtb->vtb_word_pos) || (FIRST_ATTR_WORD_POS != vtb->vtb_attr_word_pos))
    return "vt_batch_feed cannot index XPER data as part of compound text";
  text_buf_use = 0;
  text_buf_size = box_length (textbufptr[0]);
  goto first_element;
next_element:
  if (curr_el_pos > xpe->xper_end)
    goto done;
  dk_free_box (box);
first_element:
  box = get_tag_data (xpe, curr_el_pos);
  dtp = box_tag (box);
  ptr = (unsigned char *) box;
  curr_el_pos += ((DV_SHORT_STRING_SERIAL == dtp) ? 2 : 5);
  el_length = box_length (box);
  curr_el_pos += el_length;
  switch (dtp)
    {
    case DV_STRING: case DV_SHORT_STRING_SERIAL:
      s_frag_begin = ptr;
      old_word_pos = vtb->vtb_word_pos;
      box_end = (unsigned char *) box + el_length;
      while ((ptr < box_end) && IS_UTF8_CHAR_CONT (ptr[0]))
	ptr++;
    next_frag:
      for (;;)
	{
	  uchr = eh_decode_char__UTF8 ((__constcharptr *) (&ptr), (const char *) box_end);
	  if (uchr < 0)
	    {
	      ptr = (unsigned char *) box_end;
	      space_found = 0;
	      break;
	    }
	  if (unicode3_isspace (uchr))
	    {
	      space_found = 1;
	      break;
	    }
	}
      frag_len = (int) (ptr - s_frag_begin);
      if (text_buf_use + frag_len > text_buf_size)
	{
	  newbuf_len = text_buf_size;
	  do
	    {
	      newbuf_len *= 2;
	      newbuf_len |= 0x3FF;
	    }
	  while (text_buf_use + frag_len > newbuf_len);
	  newbuf = (unsigned char *) dk_alloc_box (newbuf_len, DV_STRING);
	  memcpy (newbuf, textbufptr[0], text_buf_use);
	  memcpy (newbuf + text_buf_use, s_frag_begin, frag_len);
	  dk_free_box (textbufptr[0]);
	  textbufptr[0] = (caddr_t) newbuf;
	  text_buf_size = newbuf_len;
	}
      else
	{
	  memcpy (textbufptr[0] + text_buf_use, s_frag_begin, frag_len);
	}
      text_buf_use += frag_len;
      if (space_found)
	{
	  int res;
	  res = lh_iterate_patched_words (
	      &eh__UTF8, active_lang,
	      textbufptr[0], text_buf_use,
	      active_lang->lh_is_vtb_word, active_lang->lh_normalize_word,
	      cbk, vtb);
	  if (res < 0)
	    {
	      errmsg = "corrupted text entity (UTF-8 encoding error)";
	      goto done;
	    }
	  text_buf_use = 0;
	}
      s_frag_begin = ptr;
      if (ptr < box_end)
	goto next_frag;
      if (vtb->vtb_word_pos != old_word_pos)	/* some words are indexed */
	word_hider = XML_MKUP_TEXT;
      goto next_element;
      break;
    case DV_XML_MARKUP:
      break;
    default:
      errmsg = "corrupted XPER data (invalid box tag)";
      goto done;
    }
  /* If we're not at string element, we should flush \c tmp buffer */
  if (text_buf_use)
    {
      int res;
      old_word_pos = vtb->vtb_word_pos;
      res = lh_iterate_patched_words (
	  &eh__UTF8, active_lang,
	  textbufptr[0], text_buf_use,
	  active_lang->lh_is_vtb_word, active_lang->lh_normalize_word,
	  cbk, vtb);
      if (res < 0)
	{
	  errmsg = "corrupted text entity (UTF-8 encoding error)";
	  goto done;
	}
      text_buf_use = 0;
      if (vtb->vtb_word_pos != old_word_pos)	/* some words are indexed */
	word_hider = XML_MKUP_TEXT;
    }
  /* Now we're at markup byte */
  type = *ptr++;
  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
  start_name = ptr;
  switch (type)
    {
    case XML_MKUP_STAG:
      if (namelen > (XML_MAX_EXP_NAME - 2))
	{
	  errmsg = "tag name is too long";
	  goto done;
	}
      if ((XML_MKUP_ETAG != word_hider) && (vtb->vtb_word_pos > 0))
	vtb->vtb_word_pos--;
      word_hider = XML_MKUP_STAG;
      ptr += namelen;
      start_tag_longs = ptr;
      ptr += STR_NS_OFF;
      ns_pos = LONG_REF_NA (ptr);
      if ((0 != ns_pos) && (' ' != start_name[0]))
	{
	  unsigned char *tail, *local;
	  uint32 ns_uri_len, local_len;
	  ns_uri = xper_get_namespace (xpe, ns_pos);
	  ns_uri_len = box_length (ns_uri) - 1;
          if (0 == ns_uri_len)
            goto no_box_in_env_stack; /* see below */
	  local = start_name + namelen;
	  while ((local > start_name) && (':' != local[-1]))
	    local--;
	  local_len = (uint32) (start_name + namelen - local);
	  wordlen = ns_uri_len + local_len + 2;
	  vtb_name = dk_alloc_box (wordlen + 1, DV_STRING);
	  tail = (unsigned char *) vtb_name;
	  (tail++)[0] = '<';
	  memcpy (tail, ns_uri, ns_uri_len);
	  tail += ns_uri_len;
	  (tail++)[0] = ':';
	  memcpy (tail, local, local_len);
	  tail += local_len;
	  tail[0] = '\0';
	  dk_free_box (ns_uri);
	  cbk ((const utf8char *) vtb_name, wordlen, vtb);
          goto cbk_for_start_tag_done; /* see below */
        }

no_box_in_env_stack:
      vtb_name = NULL;	/* No need to create separate box and store it in env's stack */
      textbufptr[0][0] = '<';
      memcpy (textbufptr[0] + 1, start_name, namelen);
      wordlen = 1 + namelen;
      textbufptr[0][wordlen] = '\0';
      cbk ((const utf8char *) textbufptr[0], wordlen, vtb);

cbk_for_start_tag_done:
      ptr = start_tag_longs + STR_ATTR_NO_OFF;
      num_word = LONG_REF_NA (ptr);
      ptr += 4;
      atts_fill = num_word & 0xFFFF;
      addons = ((unsigned long) (num_word)) >> 16;
      if (3 * 4 <= addons)
	predicted.xewr_attr_beg = LONG_REF_NA (ptr);
      else
	predicted.xewr_attr_beg = vtb->vtb_attr_word_pos;
      ptr += addons;
      start_attrs = ptr;
      predicted.xewr_main_beg = LONG_REF_NA (start_tag_longs + STR_START_WORD_OFF);
/* predicted.xewr_main_beg has "+1" because we've just indexed tag name */
      if (((predicted.xewr_main_beg + 1) != vtb->vtb_word_pos) || (predicted.xewr_attr_beg != vtb->vtb_attr_word_pos))
	{
	  errmsg = "word numbering has corrupted, please check language settings for text index";
	  goto done;
	}
      new_lang = active_lang;
      for (atts_ctr = atts_fill; atts_ctr > 1; atts_ctr -= 2)
	{
	  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	  if ((8 /* == strlen("xml:lang") */  == namelen) && (0 == memcmp (ptr, "xml:lang", 8)))
	    {
	      char buf[XML_MAX_EXP_NAME];
	      ptr += 8;
	      namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	      if (namelen > (XML_MAX_EXP_NAME - 2))
		{
		  errmsg = "name of language in xml:lang attribute value is too long";
		  goto done;
		}
	      memcpy (buf, ptr, namelen);
	      buf[namelen] = '\0';
	      new_lang = lh_get_handler (buf);
	      break;
	    }
	  ptr += namelen;
	  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	  ptr += namelen;
	}
      if ((NULL != vtb_name) || (new_lang != active_lang))
	{
	  xper_vtbf_env_t *res = (xper_vtbf_env_t *) dk_alloc (sizeof (xper_vtbf_env_t));
	  res->xve_closing_pos = LONG_REF_NA (start_tag_longs + STR_END_TAG_OFF);
	  res->xve_vtb_name = vtb_name;
	  res->xve_outer_lh = active_lang;
	  res->xve_outer = env_stack;
	  env_stack = res;
	}
      active_lang = new_lang;

      if (0 != atts_fill)
	{
	  wpos_t saved_pos = vtb->vtb_word_pos;
	  wpos_t attr_poss[2];
	  ptr = start_attrs;
	  attr_poss[0] = vtb->vtb_attr_word_pos;
	  vtb->vtb_word_pos = attr_poss[0];
	  for (atts_ctr = atts_fill; atts_ctr > 1; atts_ctr -= 2)
	    {
	      int index_this_attr = 1;
	      utf8char buf[XML_MAX_EXP_NAME];
	      unsigned char adtp = *ptr;
	      namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	      start_name = ptr;
	      ptr += namelen;
	      if (DV_ARRAY_OF_POINTER == adtp)
		{
		  namelen = (int) skip_string_length ((unsigned char **) (&start_name));
		  ns_pos = LONG_REF_NA (start_name + namelen + 1);
		  ns_uri = xper_get_namespace (xpe, ns_pos);
                  if (uname___empty == ns_uri)
                    ns_pos = 0;
		}
	      else
		ns_pos = 0;
	      if (0 != ns_pos)
		{
		  unsigned char *tail, *local;
		  uint32 ns_uri_len, local_len;
		  ns_uri_len = box_length (ns_uri) - 1;
		  local = start_name + namelen;
		  while ((local > start_name) && (':' != local[-1]))
		    local--;
		  local_len = (uint32) (start_name + namelen - local);
		  wordlen = ns_uri_len + local_len + 2;
		  if (wordlen > (XML_MAX_EXP_NAME - 2))
		    {
		      errmsg = "URI-qualified name of attribute is too long";
		      dk_free_box (ns_uri);
		      goto done;
		    }
		  tail = buf + 1;
		  memcpy (tail, ns_uri, ns_uri_len);
		  tail += ns_uri_len;
		  (tail++)[0] = ':';
		  memcpy (tail, local, local_len);
		  tail += local_len;
		  tail[0] = '\0';
		  dk_free_box (ns_uri);
		}
	      else
		{
		  if (namelen > (XML_MAX_EXP_NAME - 2))
		    {
		      errmsg = "name of attribute is too long";
		      goto done;
		    }
		  if ((namelen < 5) || memcmp (start_name, "xmlns", 5))
		    {
		      wordlen = namelen + 1;
		      memcpy (buf + 1, start_name, namelen);
		      buf[wordlen] = '\0';
		    }
		  else
		    index_this_attr = 0;
		}
	      if (index_this_attr)
	        {
		  buf[0] = '{';
		  cbk (buf, wordlen, vtb);
		  vallen = (int) skip_string_length ((unsigned char **) (&ptr));
		  lh_iterate_patched_words (
		    &eh__UTF8, active_lang,
		    (char *) ptr, vallen,
		    active_lang->lh_is_vtb_word, active_lang->lh_normalize_word,
		    cbk, vtb );
		  ptr += vallen;
		  buf[0] = '}';
		  cbk (buf, wordlen, vtb);
		}
	      else
	        {
		  wpos_t word_count;
		  vallen = (int) skip_string_length ((unsigned char **) (&ptr));
#ifndef SKIP_XMLNS_WORD_POS
		  if (&lh__xany == active_lang)	/* Optimization for most common case */
		    word_count = elh__xany__UTF8.elh_count_words ((char *) ptr, vallen, lh__xany.lh_is_vtb_word);
		  else
		    word_count = lh_count_words (&eh__UTF8, active_lang, (char *) ptr, vallen, active_lang->lh_is_vtb_word);
		  vtb->vtb_word_pos += 2 + word_count;
#endif
		  ptr += vallen;
		}
	    }
	  attr_poss[1] = vtb->vtb_attr_word_pos = vtb->vtb_word_pos;
	  vtb->vtb_word_pos = saved_pos;
	}
      break;
    case XML_MKUP_ETAG:
      if (namelen > (XML_MAX_EXP_NAME - 2))
	{
	  errmsg = "closing tag name is too long";
	  goto done;
	}
      vtb_name = NULL;
      while ((NULL != env_stack) && (curr_el_pos > env_stack->xve_closing_pos))
	{
	  xper_vtbf_env_t *outer = env_stack->xve_outer;
	  vtb_name = env_stack->xve_vtb_name;
	  active_lang = env_stack->xve_outer_lh;
	  dk_free (env_stack, -1);
	  env_stack = outer;
	}
      if (NULL != vtb_name)
	{
	  vtb_name[0] = '/';
	  cbk ((const utf8char *) vtb_name, box_length (vtb_name) - 1, vtb);
	  dk_free_box (vtb_name);
	}
      else
	{
	  textbufptr[0][0] = '/';
	  memcpy (textbufptr[0] + 1, start_name, namelen);
	  wordlen = 1 + namelen;
	  textbufptr[0][wordlen] = '\0';
	  cbk ((const utf8char *) textbufptr[0], wordlen, vtb);
	}
      vtb->vtb_word_pos--;
      word_hider = XML_MKUP_ETAG;
      break;
    case XML_MKUP_COMMENT:
    case XML_MKUP_REF:
    case XML_MKUP_PI:
      break;
    default:
      errmsg = "invalid markup type";
      goto done;
    }
  goto next_element;
done:
  dk_free_box (box);
  return errmsg;
}

void
xper_blob_vtb_feed (query_instance_t * qi, blob_handle_t * xper_blob, vt_batch_t * vtb, lh_word_callback_t * cbk, lang_handler_t * lh, caddr_t * textbufptr)
{
  xper_entity_t *xpe;		/* temporary entity to traverse document */
  const char *errmsg;
  xpe = xper_entity (qi, (caddr_t) xper_blob, NULL, 0, NULL /* no path */ , NULL /* no encoding */ , lh, NULL /* DTD config */, 0);
  errmsg = xper_elements_vtb_feed (xpe, vtb, cbk, lh, textbufptr);
  dk_free_tree ((box_t) xpe);
  if (NULL != errmsg)
    sqlr_new_error ("XE000", "XP9B3", "Error while indexing persistent XML blob: %.1000s", errmsg);
}


void
xper_str_vtb_feed (query_instance_t * qi, caddr_t xper_str, vt_batch_t * vtb, lh_word_callback_t * cbk, lang_handler_t * lh, caddr_t * textbufptr)
{
  xper_entity_t *xpe;		/* temporary entity to traverse document */
  const char *errmsg;
  xpe = xper_entity (qi, xper_str, NULL, 0, NULL /* no path */ , NULL /* no encoding */ , lh, NULL /* DTD config */, 0);
  errmsg = xper_elements_vtb_feed (xpe, vtb, cbk, lh, textbufptr);
  dk_free_tree ((box_t) xpe);
  if (NULL != errmsg)
    sqlr_new_error ("XE000", "XP9B3", "Error while indexing persistent XML string: %.1000s", errmsg);
}


void
xp_destroy (xml_entity_t * xe)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xper_dbg_print ("xp_destroy\n");
#ifdef MALLOC_DEBUG
  if (xpe->xe_doc.xd->xd_top_doc)
    {
      dk_set_t refs = xpe->xe_doc.xd->xd_top_doc->xd_referenced_entities;
      DO_SET (xml_entity_t *, ref_ent, &refs)
      {
	dk_alloc_box_assert (ref_ent);
	if (ref_ent == xe)
	  GPF_T1 ("attempt of destroying of an referenced entity");
      }
      END_DO_SET ();
    }
#endif
  dk_free_box ((box_t) xpe->xe_referer);
  if (0 >= --xpe->xe_doc.xd->xd_ref_count)
    {
      xper_doc_t *xpd = xpe->xe_doc.xpd;
#if 0 /* This is no longer valid because document cache can release the last entity on the document
and the document will stay locked in that time */
#ifdef DEBUG
      if (0 != xpd->xd_dom_lock_count)
        GPF_T1("attempt of destroying of a DOM-locked entity");
#endif
#endif
      if (XPD_PERSISTENT != xpe->xe_doc.xpd->xpd_state)
	{
	  it_cursor_t aitc;
	  it_cursor_t *itc = &aitc;
	  ITC_INIT (itc, xpd->xd_qi->qi_space, xpd->xd_qi->qi_trx);
	  blob_chain_delete (itc, (blob_layout_t *) blob_layout_from_handle_ctor (xpd->xpd_bh));
	}
      bh_free (xpd->xpd_bh);
      dk_free_box (xpd->xd_uri);
      DO_SET (xml_entity_t *, refd, &xpd->xd_referenced_entities)
      {
        XD_DOM_RELEASE(refd->xe_doc.xd);
#ifdef MALLOC_DEBUG
	refd->xe_doc.xd->xd_top_doc = NULL;
#endif
	dk_free_box ((caddr_t) refd);
      }
      END_DO_SET ();
      dk_set_free (xpd->xd_referenced_entities);
/*
      DO_SET (xml_entity_t *, refd, &xpd->xd_referenced_documents)
      {
	XD_DOM_RELEASE(refd->xe_doc.xd);
	dk_free_box ((caddr_t) refd);
      }
      END_DO_SET ();
      dk_set_free (xpd->xd_referenced_documents);
*/
      XPER_FREE_XPD (xpd);
    }
  if (NULL != xpe->xper_name)
    dk_free_box (xpe->xper_name);
/* IvAn/XperTrav/000825 Textual data added */
  if (NULL != xpe->xper_text)
    dk_free_box (xpe->xper_text);
  if (NULL != xpe->xper_cut_ent)
    dk_free_box ((box_t) xpe->xper_cut_ent);
  if (NULL != xpe->xe_attr_name)
    dk_free_tree (xpe->xe_attr_name);
#ifdef XPER_DEBUG
  xper_entity_free_ctr++;
#endif
}

void
xp_word_range (xml_entity_t * xe, wpos_t * start, wpos_t * end)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  start[0] = xpe->xper_start_word;
  end[0] = xpe->xper_end_word;
}


/* IvAn/TextXperIndex/000815 Persistent XML support functions added */
static const char *
xper_attr_word_count (xper_entity_t * xpe)
{
  caddr_t box;
  unsigned char *ptr, *start_tag_longs, *start_attrs, *start_name;
  char type;
  int namelen, vallen;
  long num_word, atts_fill, atts_ctr, addons;
  int dtp;
  const char *errmsg = NULL;
  long curr_el_pos = XPER_ROOT_POS;	/* position of current element in document BLOB */
  ptrlong key_pos;		/* position of element whose attributes are now under processing */
  wpos_t attr_beg = FIRST_ATTR_WORD_POS;
  wpos_t attr_word_count;
  wpos_t *pos_stack_top;
  long el_length;
  xper_doc_t *xpd = xpe->xe_doc.xpd;
  lang_handler_t *active_lang = xpd->xd_default_lh;
  dk_set_t lang_handler_stack = NULL;
  dk_set_t lang_scope_stack = NULL;
  dk_set_t pos_stack = NULL;
  if (curr_el_pos > xpe->xper_end)
    return NULL;
  goto first_element;
next_element:
  if (curr_el_pos > xpe->xper_end)
    goto done;
  dk_free_box (box);
first_element:
  key_pos = curr_el_pos;
  box = get_tag_data (xpe, (long) key_pos);
  dtp = box_tag (box);
  ptr = (unsigned char *) box;
  curr_el_pos += ((DV_SHORT_STRING_SERIAL == dtp) ? 2 : 5);
  el_length = box_length (box);
  curr_el_pos += el_length;
  switch (box_tag (box))
    {
    case DV_STRING: case DV_SHORT_STRING_SERIAL:
      goto next_element;
    case DV_XML_MARKUP:
      break;
    default:
      errmsg = "invalid box tag";
      goto done;
    }
  /* Now we're at markup byte */
  type = *ptr++;
  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
  switch (type)
    {
    case XML_MKUP_STAG:
      ptr += namelen;
      start_tag_longs = ptr;
      ptr += STR_ATTR_NO_OFF;
      num_word = LONG_REF_NA (ptr);
      ptr += 4;
      atts_fill = num_word & 0xFFFF;
      addons = ((unsigned long) (num_word)) >> 16;
      ptr += addons;
      start_attrs = ptr;
      for (atts_ctr = atts_fill; atts_ctr > 1; atts_ctr -= 2)
	{
	  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	  if ((8 /* == strlen("xml:lang") */  == namelen) && (0 == memcmp (ptr, "xml:lang", 8)))
	    {
	      char buf[XML_MAX_EXP_NAME];
	      lang_handler_t *new_lang;
	      ptr += 8;
	      namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	      if (namelen > (XML_MAX_EXP_NAME - 2))
		{
		  errmsg = "name of language in xml:lang attribute value is too long";
		  goto done;
		}
	      memcpy (buf, ptr, namelen);
	      buf[namelen] = '\0';
	      new_lang = lh_get_handler (buf);
	      if (new_lang != active_lang)
		{
		  long end_of_element = LONG_REF_NA (start_tag_longs + STR_END_TAG_OFF);
		  dk_set_push (&lang_scope_stack, (void *) (ptrlong) (end_of_element));
		  dk_set_push (&lang_handler_stack, (void *) (active_lang));
		  active_lang = new_lang;
		}
	      ptr += namelen;
	      continue;
	    }
	  ptr += namelen;
	  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	  ptr += namelen;
	}
      ptr = start_attrs;
      attr_word_count = 0;
      for (atts_ctr = atts_fill; atts_ctr > 1; atts_ctr -= 2)
	{
	  attr_word_count += 2;
	  namelen = (int) skip_string_length ((unsigned char **) (&ptr));
	  start_name = ptr;
	  ptr += namelen;
	  vallen = (int) skip_string_length ((unsigned char **) (&ptr));
	  attr_word_count += lh_count_words (&eh__UTF8, active_lang, (char *) ptr, vallen, active_lang->lh_is_vtb_word);
	  ptr += vallen;
	}
      pos_stack_top = (wpos_t *) dk_alloc (3 * sizeof (wpos_t));
      pos_stack_top[2] = key_pos;
      pos_stack_top[0] = attr_beg;
      attr_beg += attr_word_count;
      pos_stack_top[1] = attr_beg;
      dk_set_push (&pos_stack, pos_stack_top);
      break;
    case XML_MKUP_ETAG:
      while ((NULL != lang_scope_stack) && (curr_el_pos > (ptrlong) (lang_scope_stack->data)))
	{
	  dk_set_pop (&lang_scope_stack);
	  active_lang = (lang_handler_t *) (dk_set_pop (&lang_handler_stack));
	}
      pos_stack_top = (wpos_t *) dk_set_pop (&pos_stack);
      key_pos = pos_stack_top[2];
      pos_stack_top[2] = attr_beg;
      id_hash_set (xpd->xpd_wrs, (caddr_t) & key_pos, (caddr_t) pos_stack_top);
      dk_free (pos_stack_top, 3 * sizeof (wpos_t));
      break;
    case XML_MKUP_COMMENT:
    case XML_MKUP_REF:
    case XML_MKUP_PI:
      break;
    default:
      errmsg = "invalid markup type";
      goto done;
    }
  goto next_element;
done:
  dk_free_box (box);
  return errmsg;
}


void
xp_attr_word_range (xml_entity_t * xe, wpos_t * start, wpos_t * this_end, wpos_t * tree_end)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  xper_doc_t *xpd = xpe->xe_doc.xpd;
  if (XML_MKUP_STAG == xpe->xper_type)
    {
      ptrlong key_pos = xpe->xper_pos;
      if (NULL != xpd->xpd_wrs)
	{
	  wpos_t *res = (wpos_t *) id_hash_get (xpd->xpd_wrs, (caddr_t) & key_pos);
	  if (NULL == res)
	    goto fail;
	  start[0] = res[0];
	  this_end[0] = res[1];
	  tree_end[0] = res[2];
	  return;
	}
      else
	{
	  caddr_t box = get_tag_data (xpe, (long) key_pos);
	  size_t namelen;
	  unsigned char *ptr = (unsigned char *) (box + 1);
	  unsigned long num_word, addon;
	  namelen = skip_string_length (&ptr);
	  ptr += namelen + STR_ATTR_NO_OFF;
	  num_word = LONG_REF_NA (ptr);
	  addon = (num_word) >> 16;
	  if ((3 * 4) <= addon)
	    {
	      ptr += 4;
	      start[0] = LONG_REF_NA (ptr);
	      ptr += 4;
	      this_end[0] = LONG_REF_NA (ptr);
	      ptr += 4;
	      tree_end[0] = LONG_REF_NA (ptr);
	      dk_free_box (box);
	      return;
	    }
	  dk_free_box (box);
	  xpd->xpd_wrs = id_hash_allocate (1021, sizeof (void *), 3 * sizeof (wpos_t), voidptrhash, voidptrhashcmp);
	  xper_attr_word_count (xpe);
	}
    }
fail:
  start[0] = -1;
  this_end[0] = -1;
  tree_end[0] = -1;
}


int
xp_get_logical_path (xml_entity_t * xe, dk_set_t * path)
{
  xper_entity_t *xpe = (xper_entity_t *) xe;
  if (0 != xpe->xper_parent)
    {
      xper_entity_t *parent_iter = (xper_entity_t *) (box_copy ((box_t) xpe));
      int ppos;
      for (;;)
	{
	  dk_set_push (path, (void *) (ptrlong) (parent_iter->xper_pos));
	  ppos = parent_iter->xper_parent;
	  if (0 == ppos)
	    break;
	  fill_xper_entity (parent_iter, ppos);
	}
      dk_free_box ((box_t) parent_iter);
    }
  if (NULL != xpe->xe_referer)
    return xpe->xe_referer->_->xe_get_logical_path (xpe->xe_referer, path);
  dk_set_push (path, xpe->xe_doc.xpd);	/* There's no xe->xe_doc.xtd->xd_ref_count += 1 here. It's done intentionally. */
  return 1;
}


xml_entity_t *
xp_deref_id (xml_entity_t * xe, const char *idbegin, size_t idlength)
{
  return NULL;
}


xml_entity_t *
xp_follow_path (xml_entity_t * xe, ptrlong * path, size_t path_depth)
{
  return xe;
}


void dtd_load_from_buffer (dtd_t *res, caddr_t dtd_string)
{
  size_t len;
  unsigned char *end = (unsigned char *) (dtd_string + box_length (dtd_string));
  unsigned char *tail = (unsigned char *) (dtd_string);
  char *el_name, *attr_name;	/* ... to read key (ID) attributes' definitions, type 'k' */
  ecm_el_idx_t el_idx;
  ecm_el_t *el;
  ecm_attr_idx_t attr_idx;
  ecm_attr_t *attr;
  char *entname, *sysid, *pubid;	/* ... to read generic entities, types 'g' and 'G' */
  id_hash_t **dictptr, *dict;
  xml_def_4_entity_t *newdef;
  unsigned char type_byte;

#define DIG_NAME(name) do {\
  len = skip_string_length (&tail); \
  name = (char *) dk_alloc (len+1); \
  memcpy (name, tail, len); \
  name[len] = '\0'; \
  tail += len; } while (0)

#define DIG_URI(name) do {\
  len = skip_string_length (&tail); \
  name = box_dv_short_nchars ((char *)tail, len); \
  tail += len; } while (0)

again:
  if (tail > end)
    GPF_T;
  if (tail == end)
    return;
  type_byte = tail[0];
/* This switch is for compatibility with future versions.
   If somebody (i.e. me, of course) will add more types, they will be read fine
   while they will consist of type byte and sequence of strings */
  switch (type_byte)
    {
    case 'U':
      tail++;
      DIG_URI (res->ed_puburi);
      break;
    case 'u':
      tail++;
      DIG_URI (res->ed_sysuri);
      break;
    case 'k':
      tail++;
      DIG_NAME (el_name);	/* Reading of name of element */
      DIG_NAME (attr_name);	/* Reading of name of element's ID attribute */
      el_idx = ecm_map_name (el_name, (void **)&(res->ed_els), &(res->ed_el_no), sizeof (ecm_el_t));
      el = res->ed_els + el_idx;
      attr_idx = ecm_map_name (attr_name, (void **)&(el->ee_attrs), &(el->ee_attrs_no), sizeof (ecm_attr_t));
      attr = el->ee_attrs + attr_idx;
      attr->da_type = ECM_AT_ID;
      el->ee_has_id_attr = 1;
      el->ee_id_attr_idx = attr_idx;
      break;
    case 'G':
    case 'g':
      tail++;
      DIG_URI (entname);	/* Reading of name of entity */
      DIG_URI (sysid);	/* Reading of SYSTEM URI of the entity */
      /* Reading of PUBLIC name of the entity */
      if ('g' == type_byte)
	pubid = NULL;
      else
	DIG_URI (pubid);
      dictptr = &(res->ed_generics);
      if (NULL == dictptr[0])
	dictptr[0] = id_hash_allocate (251, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
      dict = dictptr[0];
      newdef = (xml_def_4_entity_t *) dk_alloc (sizeof (xml_def_4_entity_t));
      memset (newdef, 0, sizeof (xml_def_4_entity_t));
      newdef->xd4e_publicId = pubid;
      newdef->xd4e_systemId = sysid;
      id_hash_set (dict, (caddr_t) (&entname), (caddr_t) (&newdef));
      break;
    default:
      tail++;
      /* no break */
    case DV_STRING:
      len = skip_string_length (&tail);
      tail += len;
    }
  goto again;
}


int dtd_insert_soft (dtd_t *tgt, dtd_t *src)
{
  size_t len;
  ecm_el_idx_t src_el_idx, src_el_no;
  id_hash_t *src_dict;
  int id_attrs_changed = 0;

#define COPY_NAME(to,from) do { \
  len = strlen((from)); \
  (to) = (char *) dk_alloc (len+1); \
  memcpy ((to), (from), len); \
  (to)[len] = '\0'; } while (0)

  if ((NULL == src) || (NULL == tgt))
    return 0;

  src_el_no = src->ed_el_no;
  for (src_el_idx = 0; src_el_idx < src_el_no; src_el_idx++)
    {
      ecm_el_t *src_el = src->ed_els + src_el_idx;
      ecm_el_t *tgt_el;
      ecm_attr_t *tgt_attr;
      ecm_attr_idx_t key_idx, tgt_attr_idx;
      ecm_el_idx_t tgt_el_idx;
      char *src_attrname;
      if (!src_el->ee_has_id_attr)
        continue;
      tgt_el_idx = ecm_find_name (src_el->ee_name, tgt->ed_els, tgt->ed_el_no, sizeof (ecm_el_t));
      if (ECM_MEM_NOT_FOUND == tgt_el_idx)
        {
          char *tgt_elname;
          COPY_NAME (tgt_elname, src_el->ee_name);
	  tgt_el_idx = ecm_map_name (tgt_elname, (void **)&(tgt->ed_els), &(tgt->ed_el_no), sizeof (ecm_el_t));
	}
      tgt_el = tgt->ed_els + tgt_el_idx;
      if (tgt_el->ee_has_id_attr)
        continue;
      key_idx = src_el->ee_id_attr_idx;
      src_attrname = src_el->ee_attrs[key_idx].da_name;
      tgt_attr_idx = ecm_find_name (src_attrname, tgt_el->ee_attrs, tgt_el->ee_attrs_no, sizeof (ecm_attr_t));
      if (ECM_MEM_NOT_FOUND == tgt_attr_idx)
        {
          char *tgt_attrname;
          COPY_NAME (tgt_attrname, src_attrname);
	  tgt_attr_idx = ecm_map_name (tgt_attrname, (void **)&(tgt_el->ee_attrs), &(tgt_el->ee_attrs_no), sizeof (ecm_attr_t));
	}
      tgt_attr = tgt_el->ee_attrs + tgt_attr_idx;
      tgt_attr->da_type = ECM_AT_ID;
      tgt_el->ee_has_id_attr = 1;
      tgt_el->ee_id_attr_idx = tgt_attr_idx;
      id_attrs_changed = 1;
    }
  src_dict = src->ed_generics;
  if (NULL != src_dict)
    {
      id_hash_t *tgt_dict = tgt->ed_generics;
      id_hash_iterator_t src_dict_hit;
      char **src_dict_key_ptr, *tgt_dict_key;
      xml_def_4_entity_t **src_ent_ptr, *tgt_ent;
      if (NULL == tgt_dict)
	tgt_dict = tgt->ed_generics = id_hash_allocate (251, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
      for (id_hash_iterator (&src_dict_hit, src_dict);
	  hit_next (&src_dict_hit, (char **) (&src_dict_key_ptr), (char **) (&src_ent_ptr));
      /*no step */ )
	{
	  xml_def_4_entity_t **tgt_hit = (xml_def_4_entity_t **)id_hash_get (tgt_dict, (caddr_t)(src_dict_key_ptr));
	  if (NULL != tgt_hit)
	    continue;
	  tgt_ent = (xml_def_4_entity_t *) dk_alloc (sizeof (xml_def_4_entity_t));
	  memset (tgt_ent, 0, sizeof (xml_def_4_entity_t));
	  if (src_ent_ptr[0]->xd4e_literalVal)
	    tgt_ent->xd4e_literalVal = box_dv_short_string (src_ent_ptr[0]->xd4e_literalVal);
	  if (src_ent_ptr[0]->xd4e_publicId)
	    tgt_ent->xd4e_publicId = box_dv_short_string (src_ent_ptr[0]->xd4e_publicId);
	  if (src_ent_ptr[0]->xd4e_systemId)
	    tgt_ent->xd4e_systemId = box_dv_short_string (src_ent_ptr[0]->xd4e_systemId);
          tgt_dict_key = box_dv_short_string (src_dict_key_ptr[0]);
	  id_hash_set (tgt_dict, (caddr_t) (&tgt_dict_key), (caddr_t) (&tgt_ent));
	}
    }
  return id_attrs_changed;
}


dtd_t *
xp_get_addon_dtd (xml_entity_t * xe)
{
  dtd_t *res = NULL;
  xper_entity_t *xpe = (xper_entity_t *) xe;
  caddr_t root_tag_data = get_tag_data (xpe, XPER_ROOT_POS);
  caddr_t root_ns_rec = root_tag_data + 1 /* not STR_NAME_OFF */  + 7 /*DV_SHORT_STR " root" */  + STR_NS_OFF;
  long dtd_pos = LONG_REF_NA (root_ns_rec);
  dk_free_box (root_tag_data);
  if (0 != dtd_pos)
    {
      caddr_t dtd_string = get_tag_data (xpe, dtd_pos);
      res = xe->xe_doc.xpd->xd_dtd = dtd_alloc ();
      dtd_load_from_buffer (res, dtd_string);
      dk_free_box (dtd_string);
      xe_insert_external_dtd (xe);
    }
  return res;
}


const char *
xp_get_sysid (xml_entity_t * xe, const char *ref_name)
{
  xper_entity_t *xpe = (xper_entity_t *) (xe);
  dtd_t **xpe_dtd_ptr = &(xpe->xe_doc.xd->xd_top_doc->xd_dtd);
  dtd_t *xpe_dtd;
  xe_insert_external_dtd (xe);
  if (NULL == xpe_dtd_ptr[0])
    {				/* Try to process an alternate DTD origin, e.g. read something from XPER BLOB */
      dtd_t *addon_dtd = xp_get_addon_dtd ((xml_entity_t *) (xpe));
      if (NULL != addon_dtd)
	{
	  dtd_addref (addon_dtd, 0);
	  xpe_dtd_ptr[0] = addon_dtd;
	}
      else
	{
	  xpe_dtd_ptr[0] = dtd_alloc ();
	  dtd_addref (xpe_dtd_ptr[0], 0);
	}
    }
  xpe_dtd = xpe_dtd_ptr[0];
  if (NULL != xpe_dtd)
    {
      id_hash_t *dict = xpe_dtd->ed_generics;
      if (NULL != dict)
	{
	  caddr_t hash_val = id_hash_get (dict, (caddr_t) (&ref_name));
	  if (NULL != hash_val)
	    {
	      xml_def_4_entity_t *edef = ((xml_def_4_entity_t **) (void **) (hash_val))[0];
	      return edef->xd4e_systemId;
	    }
	}
    }
  xpe_dtd = xpe->xe_doc.xd->xd_top_doc->xd_dtd;
  if (NULL != xpe_dtd)
    {
      id_hash_t *dict = xpe_dtd->ed_generics;
      if (NULL != dict)
	{
	  caddr_t hash_val = id_hash_get (dict, (caddr_t) (&ref_name));
	  if (NULL != hash_val)
	    {
	      xml_def_4_entity_t *edef = ((xml_def_4_entity_t **) (void **) (hash_val))[0];
	      return edef->xd4e_systemId;
	    }
	}
    }
  return NULL;
}


/*! \brief Calculates position in cut, based on difference between source and cut.
   The result will be additionally saved in res4_ADJUST_POS */
#define ADJUST_POS(p, if_less_than) \
  (res4_ADJUST_POS = (p), \
   res4_ADJUST_POS = ( \
    (res4_ADJUST_POS < src_start_pos) ? \
    (if_less_than) : \
    (tgt_start_pos + (res4_ADJUST_POS - src_start_pos)) \
    ) )

/*! \brief Reads position item at given \c offset from \c src_box_tail,
   call ADJUST_POS for it and stores the adjusted value back */
#define TRANSLATE_POS(offset, if_less_than) \
  (ptr4_TRANSLATE = src_box_tail+(offset), \
   ADJUST_POS(LONG_REF_NA(ptr4_TRANSLATE), (if_less_than)), \
   LONG_SET_NA(ptr4_TRANSLATE, res4_ADJUST_POS) )

/*! \brief Stores a constant at given \c offset from \c src_box_tail */
#define TRANSLATE_TO_CONST(offset, value) \
  (ptr4_TRANSLATE = src_box_tail+(offset), \
   res4_TRANSLATE = (value), \
   LONG_SET_NA(ptr4_TRANSLATE, res4_TRANSLATE) )

/*! \brief Reads main text's word number at given \c offset from \c src_box_tail,
   shifts it to new base and stores the changed value back */
#define TRANSLATE_MAIN_WORD_NO(offset) \
  (ptr4_TRANSLATE = src_box_tail+(offset), \
   res4_TRANSLATE = LONG_REF_NA(ptr4_TRANSLATE)-src_main_start_word, \
   LONG_SET_NA(ptr4_TRANSLATE, res4_TRANSLATE) )

/*! \brief Reads attribute text's word number at given \c offset from \c src_box_tail,
   shifts it to new base and stores the changed value back */
#define TRANSLATE_ATTR_WORD_NO(offset) \
  (ptr4_TRANSLATE = src_box_tail+(offset), \
   res4_TRANSLATE = LONG_REF_NA(ptr4_TRANSLATE)-src_attr_start_word+FIRST_ATTR_WORD_POS, \
   LONG_SET_NA(ptr4_TRANSLATE, res4_TRANSLATE) )

static size_t
register_ns (volatile long *volatile end_of_cut_pos, dk_set_t * namespaces, size_t old_ns_pos, xper_entity_t * src_xpe)
{
  xper_ns_t *new_ns;
  dtp_t str_type;
  DO_SET (xper_ns_t *, ns_i, namespaces)
      if (ns_i->xpns_old_pos == old_ns_pos)
    return ns_i->xpns_pos;
  END_DO_SET ();
  /* Now we're sure that the given old_ns_pos was never provided before */
  new_ns = (xper_ns_t *) dk_alloc (sizeof (xper_ns_t));
  memset (new_ns, 0, sizeof (xper_ns_t));
  new_ns->xpns_uri = get_tag_data (src_xpe, (long) old_ns_pos);
  new_ns->xpns_old_pos = old_ns_pos;
  new_ns->xpns_pos = end_of_cut_pos[0];
  str_type = box_tag (new_ns->xpns_uri);
  end_of_cut_pos[0] += ((DV_SHORT_STRING_SERIAL == str_type) ? 2 : 5);
  end_of_cut_pos[0] += box_length (new_ns->xpns_uri);
  dk_set_push (namespaces, new_ns);
  return new_ns->xpns_pos;
}

static void
translate_attributes (volatile long *volatile end_of_cut_pos, dk_set_t * namespaces, unsigned char *src_box_tail, xper_entity_t * src_xpe)
{
  long num_word, addons, no_of_attrs;
  long old_ns_pos;
  size_t attr_len;
  unsigned char *ptr4_TRANSLATE;	/* Temporary for TRANSLATE_XXX macros */
  long res4_TRANSLATE;		/* Temporary for TRANSLATE_WORD_NO macro */
  dtp_t attr_box_type;

  src_box_tail += STR_ATTR_NO_OFF;
  num_word = LONG_REF_NA (src_box_tail);
  src_box_tail += 4;
  no_of_attrs = num_word & 0xFFFF;
  addons = ((unsigned long) (num_word)) >> 16;
  src_box_tail += addons;
  while (no_of_attrs >= 2)
    {
      attr_box_type = src_box_tail[0];
      attr_len = skip_string_length (&src_box_tail);
      if (DV_ARRAY_OF_POINTER == attr_box_type)
	{
	  src_box_tail += attr_len - 4;
	  old_ns_pos = LONG_REF_NA (src_box_tail);
	  if (old_ns_pos)
	    {
	      TRANSLATE_TO_CONST (0,
		  (long) register_ns (end_of_cut_pos, namespaces, old_ns_pos, src_xpe));
	    }
	  src_box_tail += 4;
	}
      else
	src_box_tail += attr_len;
      attr_len = skip_string_length (&src_box_tail);
      src_box_tail += attr_len;
      no_of_attrs -= 2;
    }
}


xper_entity_t *
 DBG_NAME (xper_cut_xper) (DBG_PARAMS query_instance_t * volatile qi, xper_entity_t * src_xpe)
{
  xper_doc_t *tgt_xpd;		/* New document */
  buffer_desc_t *buf;		/* Buffer for new document */
  xper_entity_t *tgt_xpe;	/* Resulting entity */
  xper_ctx_t context;		/* Context of creation of new document */
  caddr_t src_box;		/* Current box from source document */
  size_t src_box_length;	/* box_length(src_box) */
  volatile long src_start_pos;	/* The first position of \src_box, equal to \c xpe_src->pos */
  long src_curr_pos;		/* Position of \src_box, growth from \c src_start_pos to \c src_end_pos */
  dtp_t src_box_type;		/* Type of \c src_box (DV_LONG/SHORT_STRING, DV_XML_MARKUP) */
  unsigned char *src_box_tail;	/* Pointer to past-the-end of name in \c src_box */
  long src_main_start_word;	/* Starting main text's word number in \c xpe_src, ending on will be in context.xpc_main_word_ctr */
  volatile long src_attr_start_word;	/* Starting attribute text's word number in \c xpe_src, ending on will be in context.xpc_attr_word_ctr */
  volatile long src_end_pos;	/* The last in-range position for beginning of some \c src_box */
  volatile long tgt_start_pos;	/* Starting pos in resulting document's BLOB */
  volatile long tgt_end_pos;	/* Current ending pos of resulting document's BLOB */
  long old_ns_pos;		/* Namespace position in old (=source) document */
  char mkup_type;		/* XML_MKUP_XXX value for \c src_box */
  long res4_ADJUST_POS;		/* Temporary for ADJUST_POS macro */
  unsigned char *ptr4_TRANSLATE;	/* Temporary for TRANSLATE_XXX macros */
  long res4_TRANSLATE;		/* Temporary for TRANSLATE_WORD_NO macro */
  caddr_t volatile root_box;	/* Temporary box for root start and end tags */
  xper_ns_t *curr_ns;		/* Current namespace to write */
  long num_word;		/* Mix of number of attributes and size of addon */
  long addons;			/* Length of addon */
  dbe_key_t* xper_key;
  unsigned char *tmp_tail;
  xper_stag_t root_data;
  vxml_parser_attrdata_t root_attrdata;
  dtd_t **src_dtd_ptr;		/* Pointer to the pointer to DTD in source document */
  xper_dbg_print ("xper_cut_xper\n");
  /* If this function was called for this entity with the same value of \c xper_pos, then we may have
     cached value, and we can return its copy without re-calculation */
  if (src_xpe->xper_cut_pos == src_xpe->xper_pos)
    return (xper_entity_t *) (xp_copy ((xml_entity_t *) (src_xpe->xper_cut_ent)));
  /* If the entity is " root", then just copy it */
  if (XPER_ROOT_POS == src_xpe->xper_pos)
    return (xper_entity_t *) (xp_copy ((xml_entity_t *) (src_xpe)));
  /* If the entity is the only child of " root", then just copy it */
  do
    {
      size_t p1, p2;
      if (
	  (XPER_ROOT_POS + MIN_START_ROOT_RECORD_SZ != src_xpe->xper_pos) &&
	  (XPER_ROOT_POS + MIN_START_ROOT_RECORD_SZ + (3 * 4) != src_xpe->xper_pos))
	break;
      if (src_xpe->xper_type != XML_MKUP_STAG)
	break;
      p1 = (src_xpe->xe_doc.xpd->xpd_bh->bh_length - END_ROOT_RECORD_SZ);
      p2 = src_xpe->xper_end + (1 + 4 + 1) + dv_string_size (src_xpe->xper_name);
      if (p1 == p2)
        return (xper_entity_t *) (xp_copy ((xml_entity_t *) (src_xpe)));
    } while (0);
  src_dtd_ptr = &(src_xpe->xe_doc.xd->xd_dtd);
  if (NULL == src_dtd_ptr[0])
    {				/* Try to process an alternate DTD origin, e.g. read something from XPER BLOB */
      dtd_t *addon_dtd = xp_get_addon_dtd ((xml_entity_t *) (src_xpe));
      if (NULL != addon_dtd)
	{
	  dtd_addref (addon_dtd, 0);
	  src_dtd_ptr[0] = addon_dtd;
	}
      else
	{
	  src_dtd_ptr[0] = dtd_alloc ();
	  dtd_addref (src_dtd_ptr[0], 0);
	}
    }
  memset (&context, 0, sizeof (context));
  tgt_xpd = (xper_doc_t *) dk_alloc (sizeof (xper_doc_t));
  memset (tgt_xpd, 0, sizeof (xper_doc_t));
#ifdef MALLOC_DEBUG
  tgt_xpd->xd_dbg_file = (char *) file;
  tgt_xpd->xd_dbg_line = line;
#endif
  tgt_xpd->xpd_state = XPD_NEW;
  /* If qi is not provided, then use one from source. */
  if (NULL == qi)
    tgt_xpd->xd_qi = qi = src_xpe->xe_doc.xpd->xd_qi;
  else
    tgt_xpd->xd_qi = qi_top_qi (qi);
  tgt_xpd->xd_ref_count = 0;
  memset (&context, 0, sizeof (context));
  context.xpc_doc = tgt_xpd;
  QR_RESET_CTX
  {
/* Phase 1. Data should be read and translated */
    memset (&root_data, 0, sizeof (root_data));
    memset (&root_attrdata, 0, sizeof (root_attrdata));
    root_data.type = XML_MKUP_STAG;
    root_data.name = uname__root;
    root_data.lh = xper_find_lang_handler (src_xpe);
    root_data.attrdata = &root_attrdata;
    src_start_pos = src_xpe->xper_pos;
    src_main_start_word = 0;	/* Just to remove 'used uninitialized' warning */
    old_ns_pos = -1;		/* Just to remove 'used uninitialized' warning */
    src_curr_pos = src_start_pos;
/* There are two different cases: character data and any other stuff. If only
   one character data box should be stored, we should count words in it.
   Otherwise it's enough to copy box "as is" and adjust all positions and word
   counts without thinking about correctness of them. */
    if (XML_MKUP_TEXT != src_xpe->xper_type)
      {
	src_box = get_tag_data (src_xpe, src_curr_pos);
	src_box_type = box_tag (src_box);
	mkup_type = src_box[0];
	switch (mkup_type)
	  {
	  case XML_MKUP_STAG:
	  case XML_MKUP_REF:
	  case XML_MKUP_PI:
	    src_box_tail = (unsigned char *) (src_box + 1);
	    if (DV_STRING == *src_box_tail)
	      src_box_tail += 5 + LONG_REF_NA (src_box_tail + 1);
	    else
	      src_box_tail += 2 + (src_box_tail[1]);
	    tmp_tail = src_box_tail;
/* In these cases starting tag structure may contain addons with attribute indexing data */
	    num_word = LONG_REF_NA (src_box_tail + STR_ATTR_NO_OFF);
	    addons = ((unsigned long) (num_word)) >> 16;
	    if ((3 * 4) <= addons)
	      {
		src_attr_start_word = LONG_REF_NA (src_box_tail + STR_ADDON_OR_ATTR_OFF);
		root_data.wrs.xewr_attr_beg = FIRST_ATTR_WORD_POS;
		root_data.wrs.xewr_attr_this_end = FIRST_ATTR_WORD_POS + LONG_REF_NA (src_box_tail + STR_ADDON_OR_ATTR_OFF + (1 * 4)) - src_attr_start_word;
		root_data.wrs.xewr_attr_tree_end = FIRST_ATTR_WORD_POS + LONG_REF_NA (src_box_tail + STR_ADDON_OR_ATTR_OFF + (2 * 4)) - src_attr_start_word;
		context.xpc_attr_word_ctr = root_data.wrs.xewr_attr_tree_end;
		root_data.recalc_wrs = 0;
		root_data.store_wrs = 1;
	      }
	    else
	      {
		context.xpc_attr_word_ctr = 0;
		root_data.recalc_wrs = 0;
		root_data.store_wrs = 0;
	      }
	    root_box = start_tag_record (&root_data);
	    dk_set_push (&context.xpc_cut_chain, root_box);
	    tgt_start_pos = XPER_ROOT_POS + 5 + box_length (root_box);
	    src_box_tail = (unsigned char *) (root_box + 1 + 7) /*DV_SHORT_STR " root" */ ;
	    TRANSLATE_TO_CONST (STR_FIRST_CHILD_OFF, ADJUST_POS (src_curr_pos, 0));
	    src_box_tail = tmp_tail;
	    src_end_pos = LONG_REF_NA (src_box_tail + STR_END_TAG_OFF);
	    tgt_end_pos = (long) (
		tgt_start_pos +	/* Ordinary data will be started at tgt_start_pos */
		(src_end_pos - src_start_pos) +		/* space before closing tag */
		5 +		/* space for box header of closing tag */
		(src_box_tail - (unsigned char *) (src_box)) +	/* space for the body of closing tag */
		(1 + 4 + 1 + 7 /*DV_SHORT_STR " root" */ )	/* space for closing " root" tag */
		);
	    src_main_start_word = LONG_REF_NA (src_box_tail + STR_START_WORD_OFF);
	    context.xpc_main_word_ctr = LONG_REF_NA (src_box_tail + STR_END_WORD_OFF) - src_main_start_word;
/* This value of word counter will not be used until writing of closing tag for " root" */
	    TRANSLATE_TO_CONST (STR_PARENT_OFF, XPER_ROOT_POS);
	    TRANSLATE_TO_CONST (STR_LEFT_SIBLING_OFF, 0);
	    TRANSLATE_TO_CONST (STR_RIGHT_SIBLING_OFF, 0);
	    TRANSLATE_POS (STR_FIRST_CHILD_OFF, 0);
	    TRANSLATE_POS (STR_END_TAG_OFF, 0);
	    TRANSLATE_TO_CONST (STR_START_WORD_OFF, 0);
	    TRANSLATE_MAIN_WORD_NO (STR_END_WORD_OFF);
	    if ((3 * 4) <= addons)
	      {
		TRANSLATE_ATTR_WORD_NO (STR_ADDON_OR_ATTR_OFF);
		TRANSLATE_ATTR_WORD_NO (STR_ADDON_OR_ATTR_OFF + (4 * 1));
		TRANSLATE_ATTR_WORD_NO (STR_ADDON_OR_ATTR_OFF + (4 * 2));
	      }
	    old_ns_pos = LONG_REF_NA (src_box_tail + STR_NS_OFF);
	    if (old_ns_pos)
	      {
		TRANSLATE_TO_CONST (STR_NS_OFF,
		    (long) register_ns (&tgt_end_pos, &context.xpc_cut_namespaces, old_ns_pos, src_xpe));
	      }
	    translate_attributes (&tgt_end_pos, &context.xpc_cut_namespaces, src_box_tail, src_xpe);
	    break;
	  case XML_MKUP_ETAG:
	  case XML_MKUP_TEXT:
	  case XML_MKUP_COMMENT:
	    root_data.wrs.xewr_attr_beg = FIRST_ATTR_WORD_POS;
	    root_data.wrs.xewr_attr_this_end = FIRST_ATTR_WORD_POS;
	    root_data.wrs.xewr_attr_tree_end = FIRST_ATTR_WORD_POS;
	    root_data.recalc_wrs = 0;
	    root_data.store_wrs = 1;
	    root_box = start_tag_record (&root_data);
	    dk_set_push (&context.xpc_cut_chain, root_box);
	    tgt_start_pos = XPER_ROOT_POS + 5 + box_length (root_box);
	    src_end_pos = src_start_pos;
	    break;
	  default:
	    sqlr_new_error ("XE000", "XP9B4", "Error while indexing cutting XML: invalid markup tag");
	  }
	dk_set_push (&context.xpc_cut_chain, src_box);
	src_curr_pos += ((DV_SHORT_STRING_SERIAL == src_box_type) ? 2 : 5);
	src_curr_pos += box_length (src_box);
	while (src_curr_pos <= src_end_pos)
	  {
	    src_box = get_tag_data (src_xpe, src_curr_pos);
	    src_box_type = box_tag (src_box);
	    src_curr_pos += ((DV_SHORT_STRING_SERIAL == src_box_type) ? 2 : 5);
	    src_curr_pos += box_length (src_box);
	    mkup_type = ((DV_XML_MARKUP != src_box_type) ? XML_MKUP_TEXT : src_box[0]);
	    switch (mkup_type)
	      {
	      case XML_MKUP_STAG:
	      case XML_MKUP_REF:
	      case XML_MKUP_PI:
		src_box_tail = (unsigned char *) (src_box + 1);
		if (DV_STRING == *src_box_tail)
		  src_box_tail += 5 + LONG_REF_NA (src_box_tail + 1);
		else
		  src_box_tail += 2 + (src_box_tail[1]);
		TRANSLATE_POS (STR_PARENT_OFF, XPER_ROOT_POS);
		TRANSLATE_POS (STR_LEFT_SIBLING_OFF, 0);
		TRANSLATE_POS (STR_RIGHT_SIBLING_OFF, 0);
		TRANSLATE_POS (STR_FIRST_CHILD_OFF, 0);
		TRANSLATE_POS (STR_END_TAG_OFF, 0);
		TRANSLATE_MAIN_WORD_NO (STR_START_WORD_OFF);
		TRANSLATE_MAIN_WORD_NO (STR_END_WORD_OFF);
		num_word = LONG_REF_NA (src_box_tail + STR_ATTR_NO_OFF);
		addons = ((unsigned long) (num_word)) >> 16;
		if ((3 * 4) <= addons)
		  {
		    TRANSLATE_ATTR_WORD_NO (STR_ADDON_OR_ATTR_OFF);
		    TRANSLATE_ATTR_WORD_NO (STR_ADDON_OR_ATTR_OFF + (4 * 1));
		    TRANSLATE_ATTR_WORD_NO (STR_ADDON_OR_ATTR_OFF + (4 * 2));
		  }
		old_ns_pos = LONG_REF_NA (src_box_tail + STR_NS_OFF);
		if (old_ns_pos)
		  {
		    TRANSLATE_TO_CONST (STR_NS_OFF,
			(long) register_ns (&tgt_end_pos, &context.xpc_cut_namespaces, old_ns_pos, src_xpe));
		  }
		translate_attributes (&tgt_end_pos, &context.xpc_cut_namespaces, src_box_tail, src_xpe);
		/*TRANSLATE_POS(STR_NS_OFF, 0); */
		break;
	      case XML_MKUP_ETAG:
	      case XML_MKUP_COMMENT:
	      case XML_MKUP_TEXT:
		break;
	      default:
		sqlr_new_error ("XE000", "XP9B4", "Error while cutting XML: invalid markup tag");
	      }
	    dk_set_push (&context.xpc_cut_chain, src_box);
	  }
      }
    else
      {
	root_data.wrs.xewr_attr_beg = FIRST_ATTR_WORD_POS;
	root_data.wrs.xewr_attr_this_end = FIRST_ATTR_WORD_POS;
	root_data.wrs.xewr_attr_tree_end = FIRST_ATTR_WORD_POS;
	root_data.recalc_wrs = 0;
	root_data.store_wrs = 1;
	root_box = start_tag_record (&root_data);
	dk_set_push (&context.xpc_cut_chain, root_box);
	tgt_start_pos = XPER_ROOT_POS + 5 + box_length (root_box);
	src_main_start_word = 0;
	src_box = box_copy (src_xpe->xper_text);
/*      src_curr_pos = src_xpe->xper_next_item; */
	src_box_length = box_length (src_box);
	if (255 < src_box_length)
	  {
	    box_tag_modify (src_box, DV_STRING);
	    src_curr_pos += (long) (5 + src_box_length);
	  }
	else
	  {
	    box_tag_modify (src_box, DV_SHORT_STRING_SERIAL);
	    src_curr_pos += (long) (2 + src_box_length);
	  }
	if (&lh__xany == root_data.lh)	/* Optimization for most common case */
	  context.xpc_main_word_ctr = elh__xany__UTF8.elh_count_words (src_box, box_length (src_box), lh__xany.lh_is_vtb_word);
	else
	  context.xpc_main_word_ctr = lh_count_words (&eh__UTF8, root_data.lh, src_box, box_length (src_box), root_data.lh->lh_is_vtb_word);
	dk_set_push (&context.xpc_cut_chain, src_box);
      }
    src_box_tail = (unsigned char *) (root_box + 1 + 7) /*DV_SHORT_STR " root" */ ;
    TRANSLATE_TO_CONST (STR_END_TAG_OFF, ADJUST_POS (src_curr_pos, 0));
    TRANSLATE_TO_CONST (STR_END_WORD_OFF, (long) context.xpc_main_word_ctr);
    dk_set_push (&context.xpc_cut_chain, end_tag_record (root_data.name));
/* Phase 2. Data should be written */
    tgt_xpd->xpd_state = XPD_NEW;
    tgt_xpd->xpd_bh = bh_alloc (DV_BLOB_XPER_HANDLE);
    context.xpc_itc = itc_create (NULL, qi->qi_trx);
    xper_key = sch_id_to_key (wi_inst.wi_schema, KI_COLS);
    itc_from (context.xpc_itc, xper_key);
    tgt_xpd->xpd_bh->bh_it = context.xpc_itc->itc_tree;
    ITC_FAIL (context.xpc_itc)
    {
      buf = it_new_page (context.xpc_itc->itc_tree, context.xpc_itc->itc_page,
	  DPF_BLOB, 0, 0);
      ITC_LEAVE_MAPS (context.xpc_itc);
      if (!buf)
	{
	  xper_destroy_ctx (&context);
	  sqlr_new_error ("XE000", "XP9A7", "Error allocating a new blob page while cutting XML");
	}
      tgt_xpd->xpd_bh->bh_page = buf->bd_page;
      xper_blob_log_page_to_dir (tgt_xpd->xpd_bh, 0, buf->bd_page);
      context.xpc_buf = buf;
    }
    ITC_FAILED
    {
      ITC_LEAVE_MAPS (context.xpc_itc);
      xper_destroy_ctx (&context);
      sqlr_new_error ("XE000", "XP102", "ITC error while cutting XML");
    }
    END_FAIL (context.xpc_itc);
    memcpy (buf->bd_buffer + DP_DATA, XPER_PREFIX, XPER_ROOT_POS);
    tgt_xpd->xpd_bh->bh_length = tgt_xpd->xpd_bh->bh_diskbytes = XPER_ROOT_POS;
    LONG_SET/*_NA*/ (buf->bd_buffer + DP_BLOB_LEN, XPER_ROOT_POS);
    LONG_SET/*_NA*/ (buf->bd_buffer + DP_OVERFLOW, 0);
    /* Writing boxes with main data, including root tags */
    context.xpc_cut_chain = dk_set_nreverse (context.xpc_cut_chain);
    while (NULL != context.xpc_cut_chain)
      {
	src_box = (caddr_t) (dk_set_pop (&context.xpc_cut_chain));
	xper_blob_append_box (&context, src_box);
	dk_free_box (src_box);
      }
    context.xpc_cut_namespaces = dk_set_nreverse (context.xpc_cut_namespaces);
    while (NULL != context.xpc_cut_namespaces)
      {
	curr_ns = (xper_ns_t *) (dk_set_pop (&context.xpc_cut_namespaces));
	if (tgt_xpd->xpd_bh->bh_length != curr_ns->xpns_pos)
	  sqlr_new_error ("XE000", "XP9B4", "Error while cutting XML: internal error in namespace handler");
	xper_blob_append_box (&context, curr_ns->xpns_uri);
	dk_free_box (curr_ns->xpns_uri);
	dk_free (curr_ns, -1);
      }
/* Now we put dtd into blob, if there's something to put */
    ITC_FAIL (context.xpc_itc)
    {
      if (0 < dtd_get_buffer_length (src_dtd_ptr[0]))
	{
	  set_long_in_blob (&context, XPER_ROOT_POS + 7 /*DV_SHORT_STR " root" */  +
	      STR_NAME_OFF + STR_NS_OFF,
	      (long) tgt_xpd->xpd_bh->bh_length);
	  blob_append_dtd (&context, src_dtd_ptr[0]);
	}
      buf_set_dirty (context.xpc_buf);
      page_leave_outside_map (context.xpc_buf);
      context.xpc_buf = NULL;
    }
    ITC_FAILED
    {
      ITC_LEAVE_MAPS (context.xpc_itc);
      xper_destroy_ctx (&context);
      sqlr_new_error ("XE000", "XP102", "ITC error while cutting XML");
    }
    END_FAIL (context.xpc_itc);
/* Phase 2 completed */
  }
  QR_RESET_CODE
  {
    du_thread_t *self = THREAD_CURRENT_THREAD;
    caddr_t err = thr_get_error_code (self);
    xper_destroy_ctx (&context);
    POP_QR_RESET;
    sqlr_resignal (err);
  }
  END_QR_RESET;
  tgt_xpe = (xper_entity_t *) dk_alloc_box_zero (sizeof (xml_entity_un_t), DV_XML_ENTITY);
#ifdef XPER_DEBUG
  xper_entity_alloc_ctr++;
#endif
  tgt_xpe->_ = &xec_xper_xe;
  tgt_xpe->xe_doc.xpd = tgt_xpd;
  tgt_xpd->xd_top_doc = (xml_doc_t *) tgt_xpd;
  tgt_xpd->xd_uri = box_copy_tree (src_xpe->xe_doc.xpd->xd_uri);
  tgt_xpd->xd_ref_count = 1;
  tgt_xpd->xd_weight = XML_XPER_DOC_WEIGHT;
  tgt_xpd->xd_cost = XML_MAX_DOC_COST;
  context.xpc_doc = NULL;	/* To prevent destruction in xper_destroy_ctx(). */
  xper_destroy_ctx (&context);
  xper_blob_truncate_dir_buf (tgt_xpd->xpd_bh);
  if (NULL != src_xpe->xper_cut_ent)
    dk_free_box ((box_t) src_xpe->xper_cut_ent);
  src_xpe->xper_cut_pos = src_start_pos;
  src_xpe->xper_cut_ent = tgt_xpe;
/* Now it's time to get the dtd in target's ownership */
  dtd_addref (src_dtd_ptr[0], 0);
  tgt_xpd->xd_dtd = src_dtd_ptr[0];
  return (xper_entity_t *) xp_copy ((xml_entity_t *) tgt_xpe);
}

#undef ADJUST_POS
#undef TRANSLATE_POS
#undef TRANSLATE_WORD_NO


static xml_entity_t *
 DBG_NAME (xp_cut) (DBG_PARAMS xml_entity_t * xe, query_instance_t * qi)
{
  xper_entity_t *res;
  res = DBG_NAME (xper_cut_xper) (DBG_ARGS qi, (xper_entity_t *) xe);
  fill_xper_entity (res, XPER_ROOT_POS);
  if (((xper_entity_t *) xe)->xper_pos != XPER_ROOT_POS)
    fill_xper_entity (res, res->xper_next_item);
  if (NULL != xe->xe_attr_name)
    res->xe_attr_name = box_copy (xe->xe_attr_name);
  return (xml_entity_t *) (res);
}


static xml_entity_t *DBG_NAME (xp_clone) (DBG_PARAMS xml_entity_t * xe, query_instance_t * qi)
{
  sqlr_new_error ("42000", "XE022", "Persistent XML entity is not supported by this function");
  return NULL;
}


caddr_t
bif_xper_cut (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xper_entity_t *res;
  caddr_t source = bif_arg (qst, args, 0, "xml_persistent");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE007", "Persistent XML entity expected as argument 1 of function xper_cut()");
  res = xper_cut_xper ((query_instance_t *) QST_INSTANCE (qst), (xper_entity_t *) source);
  fill_xper_entity (res, XPER_ROOT_POS);
  if (((xper_entity_t *) source)->xper_pos != XPER_ROOT_POS)
    fill_xper_entity (res, res->xper_next_item);
  return (caddr_t) res;
}

caddr_t
bif_xper_right_sibling (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xper_entity_t *xpe, *res;
  caddr_t source = bif_arg (qst, args, 0, "xper_right_sibling");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE008", "Persistent XML entity expected as argument 1 of function xper_right_sibling()");
  xpe = (xper_entity_t *) source;
  if (xpe->xper_right == 0)
    return NULL;
  res = (xper_entity_t *) xp_copy ((xml_entity_t *) (xpe));
  fill_xper_entity (res, xpe->xper_right);
  return (caddr_t) (res);
}

caddr_t
bif_xper_left_sibling (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xper_entity_t *xpe, *res;
  caddr_t source = bif_arg (qst, args, 0, "xper_left_sibling");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE009", "Persistent XML entity expected as argument 1 of function xper_right_sibling()");
  xpe = (xper_entity_t *) source;
  if (xpe->xper_left == 0)
    return NULL;
  res = (xper_entity_t *) xp_copy ((xml_entity_t *) (xpe));
  if (!xp_go_left (res))
    {
      dk_free_box ((box_t) res);
      return NULL;
    }
  return (caddr_t) (res);
}

caddr_t
bif_xper_parent (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xper_entity_t *xpe, *res;
  caddr_t source = bif_arg (qst, args, 0, "xper_parent");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE010", "Persistent XML entity expected as argument 1 of function xper_parent()");
  xpe = (xper_entity_t *) source;
  if (xpe->xper_parent == 0)
    return NULL;
  res = (xper_entity_t *) xp_copy ((xml_entity_t *) (xpe));
  fill_xper_entity (res, xpe->xper_parent);
  return (caddr_t) (res);
}

caddr_t
bif_xper_root_entity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xper_entity_t *res;
  caddr_t source = bif_arg (qst, args, 0, "xper_root_entity");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE011", "Persistent XML entity expected as argument 1 of function xper_root_entity()");
  res = (xper_entity_t *) xp_copy ((xml_entity_t *) (source));
  fill_xper_entity (res, XPER_ROOT_POS);
  return (caddr_t) (res);
}

caddr_t
bif_xper_locate_words (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xper_entity_t *xpe, *res, *iter;
  int n_args = BOX_ELEMENTS (args);
  caddr_t source = bif_arg (qst, args, 0, "xper_locate_words");
  long start_word = (long) bif_long_arg (qst, args, 1, "xper_locate_words");
  long end_word = (long) ((n_args > 2) ? bif_long_arg (qst, args, 2, "xper_locate_words") : start_word);
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE012", "Persistent XML entity expected as argument 1 of function xper_locate_words()");
  if (end_word < start_word)
    sqlr_new_error ("42000", "XE013", "In call of function xper_locate_words(), value of argument 3 is greater than of argument 2");
  xpe = (xper_entity_t *) (source);
  if (XML_MKUP_STAG != xpe->xper_type)
    return NULL;
  if ((xpe->xper_start_word > start_word) || (xpe->xper_end_word < end_word))
    return NULL;
  res = (xper_entity_t *) xp_copy ((xml_entity_t *) xpe);
  iter = (xper_entity_t *) xp_copy ((xml_entity_t *) res);
  for (;;)
    {
      if (iter->xper_start_word > end_word)	/* We're too far to the right. */
	break;
      if (iter->xper_end_word < start_word)	/* We're too far to the left. */
	{
	  if (!iter->xper_right)
	    break;
	  fill_xper_entity (iter, iter->xper_right);
	  continue;
	}
      if ((iter->xper_start_word <= start_word) && (iter->xper_end_word >= end_word))	/* We're above the place */
	{
	  if (XML_MKUP_STAG != iter->xper_type)		/* Place is busy with non-tag entity */
	    break;
	  if (!iter->xper_first_child)	/* No way to bury in depth */
	    {
	      dk_free_box ((box_t) res);
	      return (caddr_t) (iter);
	    }
	  dk_free_box ((box_t) res);
	  res = (xper_entity_t *) xp_copy ((xml_entity_t *) iter);
	  fill_xper_entity (iter, iter->xper_first_child);
	  continue;
	}
      /* Interval of words may cover more than one tag. Let's move one child right to clarify */
      if (!iter->xper_right)
	break;
      fill_xper_entity (iter, iter->xper_right);
    }
  dk_free_box ((box_t) iter);
  return (caddr_t) (res);
}

caddr_t
bif_xper_tell (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t source = bif_arg (qst, args, 0, "xper_tell");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE014", "Persistent XML entity expected as argument 1 of function xper_tell()");
  return box_num (((xper_entity_t *) (source))->xper_pos);
}

caddr_t
bif_xper_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t source = bif_arg (qst, args, 0, "xper_length");
  if ((DV_XML_ENTITY != DV_TYPE_OF (source)) || !XE_IS_PERSISTENT (source))
    sqlr_new_error ("42000", "XE015", "Persistent XML entity expected as argument 1 of function xper_length()");
  return box_num (((xper_entity_t *) (source))->xe_doc.xpd->xpd_bh->bh_length);
}

/* IvAn/XperUpdate/000804 Function xp_log_update added */
void
xp_log_update (xml_entity_t * xe, dk_session_t * log)
{
  xper_entity_t *xpe_c = xper_cut_xper (NULL, (xper_entity_t *) xe);
  blob_handle_t *bh = (xpe_c->xe_doc.xpd->xpd_bh);
  /* The following dirty trick with bh_ask_from_client stuffing is possible
     because xp_log_update will be called only inside mutex-ed part of
     log_update() */
  int from_c = bh->bh_ask_from_client;
  xper_dbg_print ("xp_log_update\n");
  bh->bh_ask_from_client = 1;
  print_object (bh, log, NULL, NULL);
  bh->bh_ask_from_client = from_c;
  dk_free_box ((box_t) xpe_c);
}


static dk_mutex_t *dtd_refctr_mtx;

#ifdef dtd_addref
#undef dtd_addref
#endif
void
dtd_addref (dtd_t * dtd, int make_global)
{
  if (make_global || dtd->ed_is_global)
    mutex_enter (dtd_refctr_mtx);
  if (make_global)
    dtd->ed_is_global = make_global;
  dtd->ed_refctr++;
  if (dtd->ed_is_global)
    mutex_leave (dtd_refctr_mtx);
}

#ifdef dtd_release
#undef dtd_release
#endif
int
dtd_release (dtd_t * dtd)
{
  int dtd_is_global = dtd->ed_is_global;
  int dtd_refctr;
  if (dtd_is_global)
    mutex_enter (dtd_refctr_mtx);
  dtd_refctr = --(dtd->ed_refctr);
  if (dtd_is_global)
    mutex_leave (dtd_refctr_mtx);
  if (0 > dtd_refctr)
    GPF_T;
  if (0 != dtd_refctr)
    return 0;
  dtd_free (dtd);
  return 1;
}


int
xml_dtd_destroy (caddr_t box)
{
  dtd_release (((dtd_t **) box)[0]);
  return 0;
}


caddr_t
xml_dtd_copy (caddr_t box)
{
  dtd_t **newres;
  dtd_addref (((dtd_t **) box)[0], 0);
  newres = (dtd_t **) dk_alloc_box (sizeof (dtd_t *), DV_XML_DTD);
  newres[0] = ((dtd_t **) box)[0];
  return (caddr_t) newres;
}


caddr_t
bif_dtd_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t *entity = bif_entity_arg (qst, args, 0, "dtd_get");
  dtd_t **entity_dtd_ptr;
  entity_dtd_ptr = &(entity->xe_doc.xd->xd_dtd);
  if (NULL == entity_dtd_ptr[0])
    {				/* Try to process an alternate DTD origin, e.g. read something from XPER BLOB */
      dtd_t *addon_dtd = ((xml_entity_t *) (entity))->_->xe_get_addon_dtd ((xml_entity_t *) (entity));
      if (NULL != addon_dtd)
	{
	  dtd_addref (addon_dtd, 0);
	  entity_dtd_ptr[0] = addon_dtd;
	}
    }
  if (NULL == entity_dtd_ptr[0])
    return NEW_DB_NULL;
  return xml_dtd_copy ((caddr_t) (entity_dtd_ptr));
}


caddr_t
bif_dtd_attach (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t *entity = bif_entity_arg (qst, args, 0, "dtd_attach");
  caddr_t dtd_box = bif_arg (qst, args, 1, "dtd_attach");
  dtd_t **entity_dtd_ptr;
  entity_dtd_ptr = &(entity->xe_doc.xd->xd_dtd);
  switch (DV_TYPE_OF (dtd_box))
    {
    case DV_XML_DTD:
      dtd_addref (((dtd_t **) dtd_box)[0], 0);
      if (NULL != entity_dtd_ptr[0])
	dtd_release (entity_dtd_ptr[0]);
      entity_dtd_ptr[0] = ((dtd_t **) dtd_box)[0];
      break;
    case DV_DB_NULL:
      /* We cannot simply set entity_dtd_ptr[0] to NULL because bif_dtd_get or similar function may "remember" addon dtd. */
      if (NULL != entity_dtd_ptr[0])
	dtd_release (entity_dtd_ptr[0]);
      entity_dtd_ptr[0] = dtd_alloc ();
      dtd_addref (entity_dtd_ptr[0], 0);
      break;
    default:
      sqlr_new_error ("42000", "XE018", "XML DTD object or NULL expected as argument 2 of function dtd_attach()");
      break;
    }
  return NULL;			/* never reached */
}


caddr_t
bif_dtd_list_elements (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dtd_box = bif_arg (qst, args, 0, "dtd_list_elements");
  switch (DV_TYPE_OF (dtd_box))
    {
    case DV_XML_DTD:
      {
	ecm_el_idx_t el_ctr;
	dtd_t *dtd = ((dtd_t **) dtd_box)[0];
	caddr_t res = dk_alloc_box (dtd->ed_el_no * sizeof (ptrlong), DV_ARRAY_OF_POINTER);
	for (el_ctr = 0; el_ctr < dtd->ed_el_no; el_ctr++)
	  ((ptrlong **) (res))[el_ctr] = (ptrlong *) box_dv_short_string (dtd->ed_els[el_ctr].ee_name);
	return res;
      }
    case DV_DB_NULL:
      return dk_alloc_box (0, DV_ARRAY_OF_POINTER);
      break;
    default:
      sqlr_new_error ("42000", "XE019", "XML DTD object or NULL expected as argument 1 of function dtd_list_elements()");
      break;
    }
  return NULL;			/* never reached */
}


caddr_t
bif_dtd_get_id_attr_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dtd_box = bif_arg (qst, args, 0, "dtd_get_id_attr_name");
  caddr_t el_name = bif_string_arg (qst, args, 1, "dtd_get_id_attr_name");
  switch (DV_TYPE_OF (dtd_box))
    {
    case DV_XML_DTD:
      {
	dtd_t *dtd = ((dtd_t **) dtd_box)[0];
	ecm_el_idx_t el_idx = ecm_find_name (el_name, dtd->ed_els, dtd->ed_el_no, sizeof (dtd->ed_els[0]));
	ecm_el_t *el_descr;
	ecm_attr_t *id_attr_descr;
	if (el_idx < 0)
	  return NEW_DB_NULL;
	el_descr = dtd->ed_els + el_idx;
	if (!el_descr->ee_has_id_attr)
	  return NEW_DB_NULL;
	id_attr_descr = el_descr->ee_attrs + el_descr->ee_id_attr_idx;
	return box_dv_short_string (id_attr_descr->da_name);
      }
      break;
    case DV_DB_NULL:
      return NEW_DB_NULL;
      break;
    default:
      sqlr_new_error ("42000", "XE020", "XML DTD object or NULL expected as argument 1 of function dtd_list_elements()");
      break;
    }
  return NULL;			/* never reached */
}


caddr_t
bif_dtd_get_attr_default (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dtd_box = bif_arg (qst, args, 0, "dtd_get_attr_default");
  caddr_t el_name = bif_string_arg (qst, args, 1, "dtd_get_attr_default");
  caddr_t attr_name = bif_string_arg (qst, args, 2, "dtd_get_attr_default");
  switch (DV_TYPE_OF (dtd_box))
    {
    case DV_XML_DTD:
      {
	dtd_t *dtd = ((dtd_t **) dtd_box)[0];
	ecm_el_idx_t el_idx;
	ecm_el_t *el;
	ecm_attr_idx_t attr_idx;
	ecm_attr_t *attr;
	char *default_value;
	el_idx = ecm_find_name (el_name, dtd->ed_els, dtd->ed_el_no, sizeof (dtd->ed_els[0]));
	if (el_idx < 0)
	  return NEW_DB_NULL;
	el = dtd->ed_els + el_idx;
	attr_idx = ecm_find_name (attr_name, el->ee_attrs, el->ee_attrs_no, sizeof (el->ee_attrs[0]));
	if (attr_idx < 0)
	  return NEW_DB_NULL;
	attr = el->ee_attrs + attr_idx;
	default_value = ((NULL == attr->da_values) ?
	    attr->da_default.boxed_value :
	    ((attr->da_default.index < 0) ? NULL : attr->da_values[attr->da_default.index]));
	return ((NULL == default_value) ? NULL : box_dv_short_string (default_value));
      }
      break;
    case DV_DB_NULL:
      return NEW_DB_NULL;
      break;
    default:
      sqlr_new_error ("42000", "XE021", "XML DTD object or NULL expected as argument 1 of function dtd_get_attr_default()");
      break;
    }
  return NULL;			/* never reached */
}


static const char *attribute_type_name[] =
{
  /* ECM_AT_CDATA               0 */ "CDATA",
  /* ECM_AT_ENUM_NAMES          1 */ "<!-- NAMES -->",
  /* ECM_AT_ENUM_NOTATIONS      2 */ "<!-- NOTATIONS -->",
  /* ECM_AT_ID                  3 */ "ID",
  /* ECM_AT_IDREF               4 */ "IDREF",
  /* ECM_AT_IDREFS              5 */ "IDREFS",
  /* ECM_AT_ENTITY              6 */ "ENTITY",
  /* ECM_AT_ENTITIES            7 */ "ENTITIES",
  /* ECM_AT_NMTOKEN             8 */ "NMTOKEN",
  /* ECM_AT_NMTOKENS            9 */ "NMTOKENS"};


void
dtd_serialize (dtd_t * dtd, dk_session_t * ses)
{
  ecm_el_idx_t el_ctr;
  ecm_attr_idx_t attr_ctr;
  for (el_ctr = dtd->ed_el_no; el_ctr--; /*no step */ )
    {
      ecm_el_t *el = dtd->ed_els + el_ctr;
      session_buffered_write (ses, "<!ELEMENT ", 10);
      session_buffered_write (ses, el->ee_name, strlen (el->ee_name));
      session_buffered_write_char ('\t', ses);
      if (NULL != el->ee_grammar)
	session_buffered_write (ses, el->ee_grammar, strlen (el->ee_grammar));
      else
	session_buffered_write (ses, "ANY", 3);
      session_buffered_write (ses, ">\n", 2);
      if (NULL != el->ee_errmsg)
	{
	  session_buffered_write (ses, "<!-- ", 5);
	  session_buffered_write (ses, el->ee_errmsg, strlen (el->ee_errmsg));
	  session_buffered_write (ses, " -->", 4);
	}
    }
  for (el_ctr = dtd->ed_el_no; el_ctr--; /*no step */ )
    {
      ecm_el_t *el = dtd->ed_els + el_ctr;
      session_buffered_write (ses, "<!ATTLIST ", 10);
      session_buffered_write (ses, el->ee_name, strlen (el->ee_name));
      for (attr_ctr = el->ee_attrs_no; attr_ctr--; /*no step */ )
	{
#if 000
	  ptrlong ctr;
#endif
	  ecm_attr_t *attr = el->ee_attrs + attr_ctr;
	  const char *attrtype = attribute_type_name[attr->da_type];
	  session_buffered_write (ses, "\n  ", 3);
	  session_buffered_write (ses, attr->da_name, strlen (attr->da_name));
	  session_buffered_write_char ('\t', ses);
	  session_buffered_write (ses, attrtype, strlen (attrtype));
#if 000
	  for (ctr = attr->da_values_no; ctr--; /* no step */ )
	    dk_free (attr->da_values[ctr], -1);
	  if (NULL == attr->da_values)
	    {
	      if (NULL != attr->da_default.ptr)
		dk_free (attr->da_default.ptr, -1);
	    }
	  else
	    dk_free_box (attr->da_values);
#endif
	}
      session_buffered_write (ses, "\n  >\n", 5);
    }
}


int
dtd_ses_write_func (void *obj, dk_session_t * ses)
{
  dtd_t *dtd = ((dtd_t **) obj)[0];
  dk_session_t *strses = strses_allocate ();
  dtd_serialize (dtd, strses);
  session_buffered_write_char (DV_STRING, ses);
  print_long (strses_length (strses), ses);
  strses_write_out (strses, ses);
  strses_free (strses);
  return 1;
}


xe_class_t xec_xper_xe;


void
bif_xper_init (void)
{
  dtd_refctr_mtx = mutex_allocate ();
  dk_mem_hooks (DV_XML_DTD, xml_dtd_copy, xml_dtd_destroy, 0);
  PrpcSetWriter (DV_XML_DTD, (ses_write_func) dtd_ses_write_func);
#ifdef MALLOC_DEBUG
  xec_xper_xe.dbg_xe_copy = dbg_xp_copy;
  xec_xper_xe.dbg_xe_cut = dbg_xp_cut;
  xec_xper_xe.dbg_xe_clone = dbg_xp_clone;
  xec_xper_xe.dbg_xe_attribute = dbg_xp_attribute;
  xec_xper_xe.dbg_xe_string_value = dbg_xp_string_value;
#else
  xec_xper_xe.xe_cut = xp_cut;
  xec_xper_xe.xe_copy = xp_copy;
  xec_xper_xe.xe_clone = xp_clone;
  xec_xper_xe.xe_attribute = xp_attribute;
  xec_xper_xe.xe_string_value = xp_string_value;
#endif
  xec_xper_xe.xe_string_value_is_nonempty = xp_string_value_is_nonempty;
  xec_xper_xe.xe_first_child = xp_first_child;
  xec_xper_xe.xe_last_child = NULL;	/* Not implemented and no need */
  xec_xper_xe.xe_get_child_count_any = xp_get_child_count_any;
  xec_xper_xe.xe_next_sibling = xp_next_sibling;
/* IvAn/SmartXContains/001025 WR-optimized iteration function added */
  xec_xper_xe.xe_next_sibling_wr = xp_next_sibling_wr;
  xec_xper_xe.xe_prev_sibling = xp_prev_sibling;
  xec_xper_xe.xe_prev_sibling_wr = xp_prev_sibling;	/* No optimization written because this axis is rare thing */
  xec_xper_xe.xe_element_name = xp_element_name;
  xec_xper_xe.xe_ent_name = xp_ent_name;
  xec_xper_xe.xe_is_same_as = xp_is_same_as;
  xec_xper_xe.xe_destroy = xp_destroy;
  xec_xper_xe.xe_serialize = xp_serialize;
  xec_xper_xe.xe_attrvalue = xp_attrvalue;
  xec_xper_xe.xe_currattrvalue = xp_currattrvalue;
  xec_xper_xe.xe_data_attribute_count = xp_data_attribute_count;
  xec_xper_xe.xe_up = xp_up;
  xec_xper_xe.xe_down = xp_down;
  xec_xper_xe.xe_down_rev = xp_down_rev;
  xec_xper_xe.xe_word_range = xp_word_range;
  xec_xper_xe.xe_attr_word_range = xp_attr_word_range;
/* IvAn/XperUpdate/000804
   For trees, log update uses plain serialization.
   For Xper, special handler is needed: it's necessary to record only the blob itself. */
  xec_xper_xe.xe_log_update = xp_log_update;
  xec_xper_xe.xe_get_logical_path = xp_get_logical_path;
  xec_xper_xe.xe_get_addon_dtd = xp_get_addon_dtd;
  xec_xper_xe.xe_get_sysid = xp_get_sysid;
  xec_xper_xe.xe_element_name_test = xp_element_name_test;
  xec_xper_xe.xe_ent_name_test = xp_ent_name_test;
  xec_xper_xe.xe_ent_node_test = xp_ent_node_test;
  xec_xper_xe.xe_deref_id = xp_deref_id;
  xec_xper_xe.xe_follow_path = xp_follow_path;
  xec_xper_xe.xe_copy_to_xte_head = xp_copy_to_xte_head;
  xec_xper_xe.xe_copy_to_xte_subtree = xp_copy_to_xte_subtree;
  xec_xper_xe.xe_copy_to_xte_forest = xp_copy_to_xte_forest;
  xec_xper_xe.xe_emulate_input = xp_emulate_input;
  xec_xper_xe.xe_reference = xp_reference;
  xec_xper_xe.xe_find_expanded_name_by_qname = xp_find_expanded_name_by_qname;
  xec_xper_xe.xe_namespace_scope = xp_namespace_scope;

  bif_define ("xml_persistent", bif_xml_persistent);
  bif_set_uses_index (bif_xml_persistent);
  bif_define ("xper_doc", bif_xper_doc);
  bif_set_uses_index (bif_xper_doc);
  bif_define ("xper_cut", bif_xper_cut);
  bif_define ("xper_right_sibling", bif_xper_right_sibling);
  bif_define ("xper_left_sibling", bif_xper_left_sibling);
  bif_define ("xper_parent", bif_xper_parent);
  bif_define ("xper_root_entity", bif_xper_root_entity);
  bif_define ("xper_locate_words", bif_xper_locate_words);
  bif_define ("xper_tell", bif_xper_tell);
  bif_define ("xper_length", bif_xper_length);
  bif_define ("dtd_get", bif_dtd_get);
  bif_set_uses_index (bif_dtd_get);
  bif_define ("dtd_attach", bif_dtd_attach);
  bif_define ("dtd_list_elements", bif_dtd_list_elements);
  bif_define ("dtd_get_id_attr_name", bif_dtd_get_id_attr_name);
  bif_define ("dtd_get_attr_default", bif_dtd_get_attr_default);
}
