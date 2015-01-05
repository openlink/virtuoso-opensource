/*
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

#ifndef _UUENCODE_IMPL_H
#define _UUENCODE_IMPL_H

#include "Dk.h"

#define UUENCTYPE_UNKNOWN	(0)	/*!< The search for encoding is in progress */
#define UUENCTYPE_NATIVE	(1)	/*!< UUencoded data */
#define UUENCTYPE_BASE64_UNIX	(2)	/*!< Base64 data as produced by UNIX uuencode -m call */
#define UUENCTYPE_BASE64_WIDE	(3)	/*!< Base64 data with large length of data strings */
#define UUENCTYPE_XX		(4)	/*!< XXencoded data */
#define UUENCTYPE_BINHEX	(5)	/*!< Binhex encoded data */
#define UUENCTYPE_PLAINTEXT	(10)	/*!< Plain-Text */
#define UUENCTYPE_MIME_QP_TXT	(11)	/*!< Quoted-Printable MIME, for text documents (CRLF as hard break) */
#define UUENCTYPE_MIME_QP_BIN	(12)	/*!< Quoted-Printable MIME, for binaries (CRLF as =0D=0A) */

#define ASCII_CR		0x0d	/* \r */
#define ASCII_LF		0x0a	/* \n */

#define CTE_UUENC	"x-uuencode"
#define CTE_XXENC	"x-xxencode"
#define CTE_BINHEX	"x-binhex"

#define CTE_TYPE(y)	(((y)==UUENCTYPE_BASE64) ? "Base64"  : \
			 ((y)==UUENCTYPE_NATIVE) ? CTE_UUENC : \
			 ((y)==UUENCTYPE_XX) ? CTE_XXENC : \
			 ((y)==UUENCTYPE_BINHEX) ? CTE_BINHEX : "x-oops")

#ifndef ACAST
#define ACAST(s)	((int)(unsigned char)(s))
#endif

struct uu_ctx_s
{
  int		uuc_state;
  int		uuc_enctype;
  int		uuc_boundary_status;
  caddr_t	uuc_boundary;
  caddr_t	uuc_errmsg;
  int		uuc_bug_count;
  int		uuc_trail_len;
  unsigned char	uuc_trail[5];
};

#define UUSTATE_BEGIN		(1)
#define UUSTATE_BODY		(2)
#define UUSTATE_END		(3)
#define UUSTATE_FINISHED	(4)

typedef struct uu_ctx_s uu_ctx_t;

/*! \brief Initializes internal translation tables.
Should be called once before any use of UU functionality */
extern void uu_initialize_tables(void);

/*! Creates an array of sections with encoded text of \c input, no more than
\c maxlinespersection lines in every section
(so every section will contain about <CODE>80*maxlinespersection</CODE> bytes),
using encoding \c uuenctype.
Only UUENCTYPE_NATIVE, UUENCTYPE_XX and UUENCTYPE_BASE64 are supported.
\c maxlinespersection should be positive and less than 120000. */
void uu_encode_string_session (caddr_t * out_sections, dk_session_t * input,
    int uuenctype, int maxlinespersection);

/*! Creates an array of sections with encoded text of \c input, no more than
\c maxlinespersection lines in every section
(so every section will contain about <CODE>80*maxlinespersection</CODE> bytes),
using encoding \c uuenctype.
Only UUENCTYPE_NATIVE, UUENCTYPE_XX and UUENCTYPE_BASE64 are supported.
\c maxlinespersection should be positive and less than 120000. */
void
uu_encode_string (caddr_t * out_sections, caddr_t input,
    int uuenctype, int maxlinespersection);

/*! Returns type of string's encoding.
\c enctype is UUENCTYPE_UNKNOWN if we are still searching for encoded data,
otherwise it's current type. If UUENCTYPE_UNKNOWN, the check is more strict. */
int uu_validate_encoding (unsigned char *ptr, int encoding, int *bhflag, int *is_semi_legal);

/*! Type of function which decodes \c input string,
returning new box with decoded context as \c out[0].
It changes \c ctx to reflect the final status of decoding and
maybe to save error message. */
typedef void uu_decode_t (uu_ctx_t *ctx, caddr_t *out, caddr_t input);

extern uu_decode_t uu_decode_mime_qp;
extern uu_decode_t uu_decode_plaintext;
extern uu_decode_t uu_decode_part;

#endif /* _UUENCODE_IMPL_H */

