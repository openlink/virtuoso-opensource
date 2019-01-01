/*
 *  xmlres.h
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

#ifndef _XMLRES_H
#define _XMLRES_H

/*! \brief Name used in DTD of XML view */
struct xv_dtd_id_s
{
  char *xdi_name;		/*!< \brief Pointer to xj_col_t::xc_xml_name or xv_join_elt_s */
  dk_set_t xdi_elements;	/*!< \brief All xv_join_elt_s *, where id is used as xj_element */
  dk_set_t xdi_attributes;	/*!< \brief All xv_join_elt_s *, where id is used as xj_cols[..]->xc_xml_name */
  int xdi_used_as_element;	/*!< \brief Non-zero if name is used somewhere as element tag */
  int xdi_mixed_content;	/*!< \brief Non-zero if element with such name may contain #PCDATA */
  int xdi_is_masked;		/*!< \brief Non-zero if element is masked */
};

typedef struct xv_dtd_id_s xv_dtd_id_t;

struct xv_dtd_builder_s
{
  char *xd_view_name;		/*!< \brief Name of view, whose DTD is under construction */
  char *xd_top_el_name;		/*!< \brief Name of topmost element in XML output, may be NULL if not defined */
  dk_set_t xd_dict;		/*!< \brief Set of all unique XML identifiers, stored as xv_dtd_id_t */
  dk_hash_t *xd_dict_lookup;	/*!< \brief For each id in xd_dict, it contains its xv_dtd_id_t * */
  long xd_output_len;		/*!< \brief Limit of resulting DTD length, for alloc of buffer */
  int xd_countof_names;		/*!< \brief Limit of number of names, for allocs of masks' arrays */
 };

typedef struct xv_dtd_builder_s xv_dtd_builder_t;

/*! \brief Internal data for DTD/schema builder */
struct xv_schema_builder_s
{
  dbe_schema_t *xs_dd;		/*!< \brief Data Dictionary Schema to retrieve type information about columns */
  char *xs_view_name;		/*!< \brief Name of view, whose schema is under construction */
  char *xs_top_el_name;		/*!< \brief Name of topmost element in XML output, may be NULL if not defined */
  long xs_output_len;		/*!< \brief Limit of resulting schema length, for alloc of buffer */
  id_hash_t *xs_typenames;	/*!< \brief Table of all used names, to prevent collisions */
};

typedef struct xv_schema_builder_s xv_schema_builder_t;

/*! \brief Data to produce xsd:type record */
struct xv_schema_xsdtype_s
{
  const char *xsd_type;		/*! \brief Pointer to static string with type name, or \c NULL for default */
  const char *xsd_comment;	/*! \brief Pointer to static string with comment or \c NULL if no comment needed */
  int xsd_maxLength;		/*! \brief Maximal length, or -1 if undefined */
  int xsd_precision;		/*! \brief Precision, or -1 if undefined */
  int xsd_scale;		/*! \brief Scale, or -1 if undefined */
  int xsd_may_be_null;		/*! \brief Flag if value may be null */
  int xsd_directives;		/*! \brief BitOR of format and schema directives */
};

typedef struct xv_schema_xsdtype_s xv_schema_xsdtype_t;


typedef struct xre_col_s
{
  long		xrc_no;
  caddr_t	xrc_name;
  long		xrc_format;
  xv_schema_xsdtype_t *xrc_xsdtype; /*! \brief Type information, stored in box of type DV_STRING */
} xre_col_t;


typedef struct xr_element_s
{
  long		xre_tag_no;
  caddr_t	xre_element;
  xre_col_t **	xre_cols;
} xr_element_t;


typedef struct xres_state_t
{
  int		xr_mode;
  xr_element_t **	xr_elements;
  dk_set_t	xr_open; /* innermost first */
  caddr_t *	xr_row;
} xr_state_t;

#endif /* _XMLRES_H */
