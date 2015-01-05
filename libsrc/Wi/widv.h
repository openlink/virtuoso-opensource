/*
 *  widv.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

/*
  DTP's for WI
  120 - 140, 210 - 250 and 255.

  Changes 31.OCT.1997 by AK.

  Transferred these macro definitions for vector accessing and
  sprintfing from cliuti.c (if they are still there, its compilation
  will generate duplicate definition warnings.)
  Needs to be here, as they are also used by server module sqlbif.c
  (Maybe they and assorted function, vector_to_text (now in cliuti.c)
  should be instead in server/messages.h and maybe server/dkio.c
  so that these vector types would be printed in similar fashion also
  by dbg_obj_print (deep in diskit-modules of the server).

	  is_somekind_of_vector_type(type)
	  vectortype_matches_with_elemtype(vectype,elemtype)
	  get_prefixletter_of_vector(vectype)
	  get_sprintf_formatter_of_vector(vectype)
	  get_sprintf_formatter_of_elem(elem)
	  get_itemsize_of_vector(vectype)
	  get_vector_as(vec,vectype)
	  sprintf_vecitem(temp_ptr,sprintf_formatter,vec,vectype,inx)

	  Also the macro gen_aref(vec,inx,vtype,calling_fun)
	  for the needs of sqlbif.c

  Added also constants
   KUBL_TIME_HORA_CERO_YEAR
   KUBL_TIME_HORA_CERO_MONTH
   KUBL_TIME_HORA_CERO_DAYOFMONTH
  for generating timestamp's with only time-portion. In that case
  the date-portion will be 2000, January First.
  Note that we cannot use as the zero-point 1.Jan.1970
  because depending from the time-zone of the user certain hours
  will become inaccessible. E.g. in GMT+1 (Central European Time)
  01:00:00 would be earliest possible time to which time could be
  set. By using 2000-01-01 we do not get any problems of that kind.
*/

#ifndef _WIDV_H
#define _WIDV_H

#define DV_UNKNOWN	0 /* use only compile time */

#define DV_GAP1		121
#define DV_SHORT_GAP	122
#define DV_LONG_GAP	123

#define DV_BLOB		125
#define DV_BLOB_HANDLE	126
/* #define DV_SYMBOL	127 -- moved to Dkbox.h! */
#define DV_TIMESTAMP	128 /* special dtp. means col gets stamped */
#define DV_DATE		129
#define DV_OWNER	130 /* special dtp. means col with such row belongs to
				   given u_id */

#define DV_BLOB_BIN	131 /* DV_BLOB, but appears as SQL_LONGVARBINARY in
				   ODBC calls */

#define DV_BLOB_WIDE	132 /* DV_BLOB, but appears as SQL_WLONGVARCHAR in
				   ODBC calls */
#define DV_BLOB_WIDE_HANDLE	133 /* DV_BLOB_HANDLE, but for LONG NVARCHARs */

/* IvAn/DvBlobXper/001212 Special type for XPER storage will be added soon */

/* DV_BLOB, used for XPER, appears as SQL_LONGVARCHAR in ODBC calls */
#define DV_BLOB_XPER	134
/* DV_BLOB_HANDLE, but for DV_BLOB_XPER.
This type is visible only inside XPERs.
User-level object is of type DV_XML_ENTITY. */
#define DV_BLOB_XPER_HANDLE	135

/* For given dtp value DV_BLOB_XXX returns appropriate
   DV_BLOB_XXX_HANDLE dtp value.
   The idea is handle's dtp is one greater than blob's dtp for all
   except DV_BLOB_BIN blobs. */
#ifdef DEBUG
#define DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP(blob_dtp) \
  ((dtp_t)( \
    ((DV_BLOB_BIN == (blob_dtp)) ? ((dtp_t)DV_BLOB_HANDLE) : \
     (((DV_BLOB == (blob_dtp)) || \
       (DV_BLOB_WIDE == (blob_dtp)) || \
       (DV_BLOB_XPER == (blob_dtp)) ) ? \
      ((dtp_t)(blob_dtp)+1) : GPF_T ) ) ) )
#else
#define DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP(blob_dtp) \
  ((dtp_t)( \
    ((DV_BLOB_BIN == (blob_dtp)) ? ((dtp_t)DV_BLOB_HANDLE) : \
     ((dtp_t)(blob_dtp)+1) ) ) )
#endif

/* For given dtp value DV_BLOB_XXX_HANDLE returns appropriate
   DV_BLOB_XXX dtp value. */
#ifdef DEBUG
#define DV_BLOB_DTP_FOR_BLOB_HANDLE_DTP(blob_handle_dtp) \
   ((dtp_t)( \
     ((DV_BLOB_HANDLE == (blob_handle_dtp)) || \
      (DV_BLOB_WIDE_HANDLE == (blob_handle_dtp)) || \
      (DV_BLOB_XPER_HANDLE == (blob_handle_dtp)) ) ? \
     ((dtp_t)(blob_handle_dtp)-1) : GPF_T ) )
#else
#define DV_BLOB_DTP_FOR_BLOB_HANDLE_DTP(blob_handle_dtp) \
   ((dtp_t)((blob_handle_dtp)-1))
#endif


/* For given dtp value DV_BLOB_XXX returns datatype to make long inline
   ("long" means longer than 255 bytes, to write length as 4 bytes) */
#define DV_LONG_STRING_DTP_FOR_BLOB_DTP(blob_dtp) \
  ((dtp_t)( \
    ((DV_BLOB == (blob_dtp)) ? DV_LONG_STRING : \
	((DV_BLOB_WIDE == (blob_dtp)) ? DV_LONG_WIDE : \
	 ((DV_BLOB_BIN == (blob_dtp)) ? DV_LONG_BIN : \
	  GPF_T ) ) ) ) )

#define DV_BLOB_INLINE_DTP(blob_dtp) \
   ((DV_BLOB == (blob_dtp)) ? DV_STRING : \
	((DV_BLOB_WIDE == (blob_dtp)) ? DV_WIDE : \
	 ((DV_BLOB_BIN == (blob_dtp)) ? DV_BIN : \
	  GPF_T ) ) )

#define DV_BLOB_DTP_FOR_INLINE_DTP(blob_dtp) \
   ((DV_STRING == (blob_dtp)) ? DV_BLOB : \
	((DV_WIDE == (blob_dtp)) ? DV_BLOB_WIDE : \
	 ((DV_BIN == (blob_dtp)) ? DV_BLOB_BIN : \
	  GPF_T ) ) )


#define SIZEOF_SYMBOL_FOR_BLOB_HANDLE_DTP(blob_handle_dtp) \
   ((DV_BLOB_WIDE_HANDLE == (dtp_t)(blob_handle_dtp)) ? sizeof(wchar_t) : sizeof(char))

/* IvAn/DvBlobXper/001212 **/


/* fields of DV_BLOB variants */
#define BL_CHAR_LEN 1
#define BL_BYTE_LEN 9
#define BL_KEY_ID 17
#define BL_FRAG_NO 21
#define BL_DP 25
#define BL_DPS_ON_ROW 16  /* consecutive dp's, last if !) 0 is the dp of the first full dir page */
#define BL_PAGE_DIR (BL_DP + 4 * BL_DPS_ON_ROW)
#define BL_TS (BL_PAGE_DIR + 4)
#define DV_BLOB_LEN ((int)(BL_TS + sizeof (dp_addr_t)))

#define BL_N_PAGES(bytes)  ((_RNDUP (((bytes) ? bytes : 1), PAGE_DATA_SZ)) / PAGE_DATA_SZ)


/* occurs in key layout when assigning places for offsets for ref to uncompressed value on other row. 2 bytes per field, laid out before rest */
#define DV_COMP_OFFSET 136

#define DV_TIME		210
#define DV_DATETIME	211
#define DV_NUMERIC	219
#define DV_IGNORE 220 /* in SQLSetPos, means 'do not update' */
#define DV_DAE 221 /* SQL_DATA_AT_EXEC marker, non-serializable, client only */

#define DV_BIN 222
#define DV_LONG_BIN 223

#define DV_EXEC_CURSOR 224 /* in bif_execute - cursor type */

#define DV_TEXT_SEARCH 227  /* state of a pending text search */
#define DV_TEXT_BATCH 228
#define DV_XML_ENTITY 230
#define DV_XQI 231		/* XPATH query instance */
/* #define DV_XPATH_QUERY 232 Moved to Dk.h */
#define DV_XML_MARKUP	233

#define DV_PL_CURSOR 234  /* A PL Scrollable cursor type */

#define DV_XML_PARSER 235	/* XML parser (now unused) */
#define DV_XML_DTD 236		/* Storable XML DTD */
#define DV_XML_SCHEMA 237	/* Storable XML Schema */

#define DV_INDEX_TREE 137
#define DV_ITC 138
#define DV_GEO 238
#define DV_FIXED_STRING 240
#define DV_TINY_INT 241
#define DV_ANY 242

#define bnode_iri_ids_are_huge  (wi_inst.wi_master->dbs_stripe_unit != 1) /* stay compatible with some older 6 databases w/ 64 bits ids but bnodes starting at wrong place.  Temporary  */
#define min_bnode_iri_id() (bnode_iri_ids_are_huge ? MIN_64BIT_BNODE_IRI_ID : MIN_32BIT_BNODE_IRI_ID)
#define max_bnode_iri_id() (bnode_iri_ids_are_huge ? MAX_64BIT_BNODE_IRI_ID : MAX_32BIT_BNODE_IRI_ID)
#define min_named_bnode_iri_id() (bnode_iri_ids_are_huge ? MIN_64BIT_NAMED_BNODE_IRI_ID : MIN_32BIT_NAMED_BNODE_IRI_ID)


#define DV_IRI_ID 243
#define DV_IRI_ID_8 244

#define IS_IRI_DTP(dtp) (DV_IRI_ID == (dtp) || DV_IRI_ID_8 == (dtp))

#define DV_COMPOSITE 255 /* value important for free text, where long w/ high byte of 255 signifies composite key */

/* cluster data */
#define DV_CLRG 139
#define DV_CLOP 140

#define DV_OBJECT 254
/*#define DV_REFERENCE 206 Moved to Dk.h */
#define DV_SHORT_REF 205

#define DV_ROW_EXTENSION 239 /* appears only on a row after DV_DEPENDANT -
				marks that the dependant part of the row
				is in a blob.
				Never appears as a box tag.
			      */
#define DV_REXEC_CURSOR 240 /* the rexec cursor */

#define DV_CONNECTION 241 /* the connected TCP session  */
#define DV_FD      250 /* the open file handle, this to be deleted in future */
#define DV_ASYNC_QUEUE 245 /* async_queue_t */
#define DV_RI_ITERATOR 229

#define DT_LENGTH 10
#define DT_COMPARE_LENGTH 8


#define IS_GAP_DTP(dtp) \
  ((dtp) <= DV_LONG_GAP && (dtp) >= DV_GAP1)


/* IvAn/DvBlobXper/001212 Special type for XPER storage added */
#define IS_BLOB_DTP(dtp) \
  (DV_BLOB == (dtp) || DV_BLOB_BIN == (dtp) || \
  DV_BLOB_WIDE == (dtp) || DV_BLOB_XPER == (dtp) )

#define IS_UDT_DTP(dtp) \
  (DV_OBJECT == (dtp) || DV_REFERENCE == (dtp))

/* XPER may not be inlined under any circumstances */
#define IS_INLINEABLE_BLOB_DTP(dtp) \
  (DV_BLOB == (dtp) || DV_BLOB_BIN == (dtp) \
  /* || DV_BLOB_WIDE == (dtp) || DV_BLOB_XPER == (dtp) */ )

/* Note that DV_BLOB_HANDLE is for both DV_BLOB and DV_BLOB_BIN */
#define IS_BLOB_HANDLE_DTP(dtp) \
  (DV_BLOB_HANDLE == (dtp) || \
  DV_BLOB_WIDE_HANDLE == (dtp) || DV_BLOB_XPER_HANDLE == (dtp) )

#define IS_STRING_CMP_DTP(dtp) \
  (DV_DATETIME == (dtp) || DV_DATE == (dtp) || DV_TIME == (dtp) || DV_TIMESTAMP == (dtp))

#define IS_WIDE_STRING_DTP(dtp) \
  (DV_WIDE == (dtp) || DV_LONG_WIDE == (dtp))

#define IS_BLOB_HANDLE(x) \
  (IS_BOX_POINTER (x) && IS_BLOB_HANDLE_DTP(box_tag (x)))

#define IS_DB_NULL(x) \
  (IS_BOX_POINTER(x) && box_tag (x) == DV_DB_NULL)

#define IS_INT_DTP(dtp) \
  (DV_LONG_INT == dtp || DV_SHORT_INT == dtp || DV_INT64 == dtp)


#define DV_STRINGP(q) \
  (IS_BOX_POINTER (q) && ((DV_STRING == box_tag (q)) || (DV_UNAME == box_tag (q))))

#define DV_WIDESTRINGP(q) \
  (IS_BOX_POINTER (q) && (DV_WIDE == box_tag (q) || DV_LONG_WIDE == box_tag (q)))



#define DV_LONG_INT_PREC 10
#define DV_STRING_PREC 24
#define DV_FLOAT_PREC 14
#define DV_DOUBLE_PREC 16
#define DV_TIMESTAMP_PREC 26

#define is_string_type(type)\
  ((DV_LONG_STRING == (type)))

#define is_somekind_of_vector_type(type)\
 (IS_NONLEAF_DTP(type) || \
  (DV_ARRAY_OF_LONG == (type)) || (DV_ARRAY_OF_DOUBLE == (type))\
  || (DV_ARRAY_OF_FLOAT == (type)) )

#define vectortype_matches_with_elemtype(vectype,elemtype)\
 ((DV_ARRAY_OF_LONG == (vectype)) ?\
	((DV_SHORT_INT == (elemtype)) || (DV_LONG_INT == (elemtype)))\
 : ((DV_ARRAY_OF_DOUBLE == (vectype)) ? (DV_DOUBLE_FLOAT == (elemtype))\
 : ((DV_ARRAY_OF_FLOAT == (vectype)) ? (DV_SINGLE_FLOAT == (elemtype))\
 : (((DV_LONG_STRING == (vectype))) ?\
	((DV_SHORT_INT == (elemtype)) || (DV_LONG_INT == (elemtype)))\
 : 1))))
/* Maybe with strings we should also check if elemtype is DV_CHARACTER,
   although I do not believe it's used with Kubl.
   The last else-part, 1, is for vectors of ordinary heterogeneous type
i.e. (DV_ARRAY_OF_POINTER==(vectype)) || (DV_LIST_OF_POINTER==(vectype)))
   that can contain any kind of items.
 */

#define get_prefixletter_of_vector(vectype)\
 ((DV_ARRAY_OF_LONG == (vectype)) ? "l" \
   : ((DV_ARRAY_OF_DOUBLE == (vectype)) ? "d" \
   : ((DV_ARRAY_OF_FLOAT == (vectype)) ? "f" \
   : ((DV_ARRAY_OF_XQVAL == (vectype)) ? "x" \
   : ""))))

#define get_sprintf_formatter_of_vector(vectype)\
	 ((DV_ARRAY_OF_LONG == (vectype)) ? "%ld" \
   : ((DV_ARRAY_OF_DOUBLE == (vectype)) ? "%lf" \
   : ((DV_ARRAY_OF_FLOAT == (vectype)) ? "%f" \
   : "0x%08lx")))

/* This is only for heterogeneous vectors.
   When element is not box_pointer then we can be sure that it is a number
   contained "inline" in the element cell. (between -10000 and 10000).
   With DV_DB_NULL's we know that it is a SQL NULL.
   (DV_NULL is a different thing and should not occur.)
   All other things are printed as 8-byte hexadecimal integers.
   sprintf of the machine should not mind if extraneous arguments
   are present (when the formatter string is constant like "NULL").

   This may "call" macro DV_TYPE_OF and assorted macro box_tag
   multiple times, the fact which purists may not like, but which
   the optimizer, if it is upto any good, should handle somehow.
 */
#define get_sprintf_formatter_of_elem(elem)\
   ((!IS_BOX_POINTER(elem)) ? "%ld" \
 : ((DV_TYPE_OF(elem) == DV_NULL) ? "NIL" \
 : ((DV_TYPE_OF(elem) == DV_DB_NULL) ? "NULL" \
 : "0x%08lx")))

/*
  The last case is for DV_ARRAY_OF_POINTER and DV_LIST_OF_POINTER
  Currently vector_to_text cannot be called with ordinary heterogeneous
  vectors of any type, as the contents of e.g. string pointers contained
  in it might not be transferred from Kubl implicitly.
 */
#define get_itemsize_of_vector(vectype)\
	 ((is_string_type((vectype)) || (DV_UNAME == (vectype))) ? sizeof(char)\
   : ((DV_ARRAY_OF_LONG == (vectype)) ? sizeof(ptrlong)\
   : ((DV_ARRAY_OF_DOUBLE == (vectype)) ? sizeof(double)\
   : ((DV_ARRAY_OF_FLOAT == (vectype)) ? sizeof(float)\
   : ((DV_WIDE == (vectype) || DV_LONG_WIDE == (vectype)) ? sizeof(wchar_t)\
   : sizeof(caddr_t))))))


/* Of course MSVC does not want to compile this sucker without whining,
   because ternary-expression cannot return different types.
   Why not? Does it say so in the standard?
   IvAn//010728:
   Yes, it is the Standard.
   The type of ternary is the SCBT (smallest common base type) of
   a) type of "then" subexpression and b) type of "else" subexpression.
   Compiler adds implicit casts to SCBT if the type of subexpression is
   less common than target SCBT. If this implicit cast is too "far", or
   impossible, standard warning or error is reported.
   Compiler may not avoid this because every expression in C/C++ should
   have some exactly known type of value.
   Thus the macro is an exact equivalent of (void *)(vec).
   I've disabled this macro to prevent its use.
 */
#if 0
#define get_vector_as(vec,vectype)\
	 ((DV_ARRAY_OF_LONG == (vectype)) ? ((long *)(vec))\
   : ((DV_ARRAY_OF_DOUBLE == (vectype)) ? ((double *)(vec))\
   : ((DV_ARRAY_OF_FLOAT == (vectype)) ? ((float *)(vec))\
   : ((caddr_t)(vec)))))
#endif

/* So we use this one instead. All those sprintf's return same kind of
   result, an integer. */
#define sprintf_vecitem(temp_ptr, temp_ptr_size, sprintf_formatter,vec,vectype,inx)\
   ((DV_ARRAY_OF_LONG == (vectype)) ? \
	   snprintf(temp_ptr,temp_ptr_size,sprintf_formatter,(((ptrlong *)(vec))[inx]))\
 : ((DV_ARRAY_OF_DOUBLE == (vectype)) ? \
	   snprintf(temp_ptr,temp_ptr_size,sprintf_formatter,(((double *)(vec))[inx]))\
 : ((DV_ARRAY_OF_FLOAT == (vectype)) ? \
	   snprintf(temp_ptr,temp_ptr_size,sprintf_formatter,(((float *)(vec))[inx]))\
 : snprintf(temp_ptr,temp_ptr_size,get_sprintf_formatter_of_elem((((caddr_t *)(vec))[inx])),\
		   (ptrlong)(((caddr_t *)(vec))[inx])))))

/* The "prototype" for this macro is:
caddr_t gen_aref(caddr_t arr, long inx, dtp_t vectype, char *calling_fun)
sqlr_new_error is void, and should never return.
 */
#define gen_aref(vec,inx,vtype,calling_fun)\
   ((IS_NONLEAF_DTP(vtype)) ?\
	(box_copy_tree (((caddr_t*)(vec)) [(inx)]))\
 : ((DV_ARRAY_OF_LONG == (vtype)) ?\
	(box_num ( (((ptrlong *)(vec)) [(inx)])))\
 : ((DV_ARRAY_OF_DOUBLE == (vtype)) ?\
	(box_double (((double*)(vec)) [(inx)]))\
 : ((DV_ARRAY_OF_FLOAT == (vtype)) ? \
	(box_float (((float*)(vec)) [(inx)]))\
 : (((DV_LONG_STRING == (vtype)) || (DV_UNAME == (vtype))) ?\
	(box_num ( (((unsigned char *) (vec)) [(inx)])))\
 : ((DV_WIDE == (vtype) || DV_LONG_WIDE == (vtype)) ? \
	(box_num (((wchar_t*)(vec)) [(inx)]))\
 : ((DV_STRING_SESSION == (vtype)) ?\
	(box_num (strses_aref ((caddr_t)vec,inx)))\
 : ((sqlr_new_error ("22023", "SR000", "%s expects a vector, not an arg of type %d.",\
		   (calling_fun), (vtype))),((caddr_t) 0)) )))))))

#define DV_TYPE_TITLE(type) \
 (((type) == DV_GAP1) ? \
    "GAP1" : \
  ((type) == DV_SHORT_GAP) ? \
    "SHORT_GAP" : \
  ((type) == DV_LONG_GAP) ? \
    "LONG_GAP" : \
  ((type) == DV_BLOB) ? \
    "LONG VARCHAR" : \
  ((type) == DV_BLOB_BIN) ? /* 131 */ \
    "LONG VARBINARY" : \
  ((type) == DV_BLOB_WIDE) ? \
    "LONG NVARCHAR" : \
  ((type) == DV_BLOB_HANDLE) ? /* 126 */ \
    "BLOB_HANDLE" : \
  ((type) == DV_BLOB_WIDE_HANDLE) ? /* 133 */ \
    "BLOB_WIDE_HANDLE" : \
  ((type) == DV_BLOB_XPER) ? /* 134 */ \
    "BLOB_WIDE_HANDLE" : \
  ((type) == DV_BLOB_XPER_HANDLE) ? /* 135 */ \
    "BLOB_XPER_HANDLE" : \
  ((type) == DV_SYMBOL) /* 127 */ ? \
    "SYMBOL" : \
  ((type) == DV_TIMESTAMP) /* 128 */ ? \
    "TIMESTAMP" : \
  ((type) == DV_DATE) /* 129 */ ? \
    "DATE" : \
  ((type) == DV_TIME) ? \
    "TIME" : \
  ((type) == DV_DATETIME) ? \
    "DATETIME" : \
  ((type) == DV_OWNER) /* 130 */ ? \
    "OWNER" : \
  ((type) == DV_NULL) /* 180 */ ? \
    "NIL" : \
  ((type) == DV_STRING) /* 182 */ ? \
    "VARCHAR" : \
  ((type) == DV_BIN) ? \
    ("VARBINARY") : \
  ((type) == DV_C_STRING) /* 183 */ ? \
    "C_STRING" : \
  ((type) == DV_C_SHORT) /* 184 */ ? \
    "C_SHORT" : \
  ((type) == DV_STRING_SESSION) /* 185 */ ? \
    "STRING_SESSION" : \
  ((type) == DV_SHORT_CONT_STRING) /* 186 */ ? \
    "SHORT_CONT_STRING" : \
  ((type) == DV_LONG_CONT_STRING) /* 187 */ ? \
    "LONG_CONT_STRING" : \
  ((type) == DV_SHORT_INT) /* 188 */ ? \
    "SMALLINT" : \
  ((type) == DV_LONG_INT) /* 189 */ ? \
    "INTEGER" : \
  ((type) == DV_SINGLE_FLOAT) /* 190 */ ? \
    "REAL" : \
  ((type) == DV_DOUBLE_FLOAT) /* 191 */ ? \
    "DOUBLE PRECISION" : \
  ((type) == DV_CHARACTER) /* 192 */ ? \
    "CHARACTER" : \
  ((type) == DV_ARRAY_OF_POINTER) /* 193 */ ? \
    "ARRAY_OF_POINTER" : \
  ((type) == DV_ARRAY_OF_LONG) /* 194 */ ? \
    "ARRAY_OF_LONG" : \
  ((type) == DV_ARRAY_OF_DOUBLE) /* 195 */ ? \
    "ARRAY_OF_DOUBLE" : \
  ((type) == DV_LIST_OF_POINTER) /* 196 */ ? \
    "LIST_OF_POINTER" : \
  ((type) == DV_OBJECT_AND_CLASS) /* 197 */ ? \
    "OBJECT_AND_CLASS" : \
  ((type) == DV_OBJECT_REFERENCE) /* 198 */ ? \
    "OBJECT_REFERENCE" : \
  ((type) == DV_DELETED) /* 199 */ ? \
    "DELETED" : \
  ((type) == DV_MEMBER_POINTER) /* 200 */ ? \
    "MEMBER_POINTER" : \
  ((type) == DV_C_INT) /* 201 */ ? \
    "C_INT" : \
  ((type) == DV_ARRAY_OF_FLOAT) /* 202 */ ? \
    "ARRAY_OF_FLOAT" : \
  ((type) == DV_CUSTOM) /* 203 */ ? \
    "CUSTOM" : \
  ((type) == DV_DB_NULL) /* 204 */ ? \
    "DB_NULL" : \
  ((type) == DV_BOX_FLAGS) /* 207 */ ? \
    "box_flags" : \
  ((type) == DV_ARRAY_OF_XQVAL) ? \
    "ARRAY_OF_XQVAL" : \
  ((type) == DV_NUMERIC) ? \
    "DECIMAL" : \
  ((type) == DV_WIDE)  /* 225 */ ? \
    "NVARCHAR" : \
  ((type) == DV_LONG_WIDE)   /* 226 */ ? \
    "NVARCHAR" : \
  ((type) == DV_XML_ENTITY) /* 230 */ ? \
    "XML_ENTITY" : \
  ((type) == DV_PL_CURSOR) /* 234 */ ? \
    "PL_CURSOR" : \
  ((type) == DV_XML_DTD) /* 236 */ ? \
    "XML_DTD" : \
  ((type) == DV_OBJECT) /* 254 */ ? \
    "INSTANCE" : \
  ((type) == DV_ANY) ? \
    "ANY" : \
  ((type) == DV_REFERENCE) ? \
    "UDT_REFERENCE" : \
  ((type) == DV_IRI_ID) ? "IRI_ID" : \
  ((type) == DV_IRI_ID_8) ? "IRI_ID" : \
  ((type) == DV_INT64) ? "BIGINT" : \
  ((type) == DV_UNAME) ? "UNAME" : \
  ((type) == DV_RDF) ? "rdf" : \
  ((type) == DV_GEO) ? "geometry" : \
  "UNK_DV_TYPE" )
#endif /* _WIDV_H */

