/*
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

#include "uuencode_impl.h"
#include "sqlfn.h"

static unsigned char uu_enctab_native[0x40] = {
/* 0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 | */
  '`', '!', '"', '#', '$', '%', '&', '\'',
  '(', ')', '*', '+', ',', '-', '.', '/',
  '0', '1', '2', '3', '4', '5', '6', '7',
  '8', '9', ':', ';', '<', '=', '>', '?',
  '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
  'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
  'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W',
  'X', 'Y', 'Z', '[', '\\', ']', '^', '_'
};

static unsigned char uu_enctab_base64[0x40] = {
/* 0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 | */
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
  'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
  'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
  'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
  'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
  'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
  'w', 'x', 'y', 'z', '0', '1', '2', '3',
  '4', '5', '6', '7', '8', '9', '+', '/'
};

static unsigned char uu_enctab_xx[0x40] = {
/* 0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 | */
  '+', '-', '0', '1', '2', '3', '4', '5',
  '6', '7', '8', '9', 'A', 'B', 'C', 'D',
  'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
  'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
  'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b',
  'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
  'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r',
  's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
};

static unsigned char uu_enctab_binhex[0x40] = {
/* 0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 | */
  '!', '"', '#', '$', '%', '&', '\'', '(',
  ')', '*', '+', ',', '-', '0', '1', '2',
  '3', '4', '5', '6', '8', '9', '@', 'A',
  'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
  'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'R',
  'S', 'T', 'U', 'V', 'X', 'Y', 'Z', '[',
  '`', 'a', 'b', 'c', 'd', 'e', 'f', 'h',
  'i', 'j', 'k', 'l', 'm', 'p', 'q', 'r'
};

static int uu_xlat_native[0x100];	/*!< Invert of uu_enctab_native */
static int uu_xlat_base64[0x100];	/*!< Invert of uu_enctab_base64 */
static int uu_xlat_xx[0x100];		/*!< Invert of uu_enctab_xx */
static int uu_xlat_binhex[0x100];	/*!< Invert of uu_enctab_binhex */
static int uu_qp_enc_1st[0x100];	/*!< Right of two hexdigits of QP's encoding of the byte, '\0' if no need to encode */
static int uu_qp_enc_2nd[0x100];	/*!< Left of two hexdigits of QP's encoding of the byte, '\0' if no need to encode */
static int uu_hexval[0x100];		/*!< Value of hex digit */
static int uu_linelengths[0x40];	/*!< Translation of source length to encoded length */

#define UUNTABLES 6
/*______________________________________________________________________________________*/
/*					| Encoding index				*/
/*					| NO	| UU	| B64U	| B64M	| XX	| BH	*/
/*======================================|=======|=======|=======|=======|=======|=======*/
static int uu_bytesperline[UUNTABLES] = { 0	, 45	, 45	, 57	, 45	, 45	};
static int uu_paddings[UUNTABLES] =	{ 0	, '`'	, '='	, '='	, '+'	, ':'	};

static unsigned char *uu_enctabs[UUNTABLES] =
  /*!*/					{ NULL
  /*!*/						, uu_enctab_native
  /*!*/							, uu_enctab_base64
  /*!*/								, uu_enctab_base64
  /*!*/									, uu_enctab_xx
  /*!*/										, uu_enctab_binhex
  /*!*/											};
static int *uu_xlats[UUNTABLES] =
  /*!*/					{ NULL
  /*!*/						, uu_xlat_native
  /*!*/							, uu_xlat_base64
  /*!*/								, uu_xlat_base64
  /*!*/									, uu_xlat_xx
  /*!*/										, uu_xlat_binhex
  /*!*/											};
/*______________________________________|_______|_______|_______|_______|_______|_______*/


static int tables_initialized = 0;

void
uu_initialize_tables(void)
{
  int i, j;
  if (!tables_initialized)
    tables_initialized = 1;

  for (i = 0; i < 0x100; i++)
    uu_xlat_native[i] = uu_xlat_base64[i] = uu_xlat_xx[i] = uu_xlat_binhex[i] = uu_hexval[i] = -1;

  for (i = ' ', j = 0; i < ' ' + 0x40; i++, j++)
    uu_xlat_native[i] /* = uu_xlat_native[i+0x40] */  = j;
  for (i = '`', j = 0; i < '`' + 32; i++, j++)
    uu_xlat_native[i] = j;

  uu_xlat_native['`'] = uu_xlat_native[' '];
  uu_xlat_native['~'] = uu_xlat_native['^'];

  uu_linelengths[0] = 1;
  for (i = 1, j = 5; i <= 60; i += 3, j += 4)
    uu_linelengths[i] = uu_linelengths[i + 1] = uu_linelengths[i + 2] = j;

  for (i = 0; i < 0x40; i++)
    {
      uu_xlat_base64[ACAST (uu_enctab_base64[i])] = i;
      uu_xlat_xx[ACAST (uu_enctab_xx[i])] = i;
      uu_xlat_binhex[ACAST (uu_enctab_binhex[i])] = i;
    }

  for (i = 0; i < 0xA; i++)
    uu_hexval['0'+i] = i;
  for (i = 0xA; i <= 0xF; i++)
    uu_hexval['A'+i-0xA] = uu_hexval['a'+i-0xA] = i;


  for (i = 0; i < 0x100; i++)
    {
      if ((33 > i) || (126 < i) || ('=' == i))
	{
	  uu_qp_enc_1st[i] = "0123456789ABCDEF" [i >> 4];
	  uu_qp_enc_2nd[i] = "0123456789ABCDEF" [i & 0xF];
	}
      else
	{
	  uu_qp_enc_1st[i] = uu_qp_enc_2nd[i] = '\0';
	}
    }
}


void
uu_encode_string_session_plaintext (caddr_t * out_sections, dk_session_t * input,
    int input_length, int uuenctype, int maxlinespersection)
{
  int max_length_of_section;
  unsigned char input_buf[4096];
  int input_len, remaining_input_length = input_length;
  int input_is_last;
  int input_pos;
  dk_set_t sections_set = NULL;
  unsigned char *out_section;
  unsigned char *out_section_end;
  unsigned char *out_tail;

  buffer_elt_t *input_elt;
  int offset_in_elt;

  max_length_of_section = maxlinespersection * (76+2);
  /* if even one section is surely longer than the worst input encoded, decrease input_bytes_per_section */
  if (max_length_of_section > (10 + 4*input_length))
    max_length_of_section = 10 + 4*input_length;

  offset_in_elt = 0;
  input_elt = input->dks_buffer_chain;
  input_is_last = 0;

  out_tail = out_section = (unsigned char *) dk_alloc_box (max_length_of_section+1, DV_SHORT_STRING);
  out_section_end = out_section + max_length_of_section;

start_next_elt:
  if (0 == remaining_input_length)
    goto input_finished;
  input_len = session_buffered_read (input, (char *) input_buf,
    ((sizeof (input_buf) < remaining_input_length) ? sizeof (input_buf) : remaining_input_length) );
  remaining_input_length -= input_len;
  for (input_pos = 0; input_pos < input_len; input_pos++)
    {
      unsigned char chr = input_buf[input_pos];
      if (out_tail >= out_section_end)
	{
	  out_tail[0] = '\0';
	  dk_set_push (&sections_set, out_section);
	  out_tail = out_section = (unsigned char *) dk_alloc_box (max_length_of_section+1, DV_SHORT_STRING);
	  out_section_end = out_section + max_length_of_section;
	}
      (out_tail++)[0] = chr;
    }
  goto start_next_elt;

input_finished:
  if (out_tail == out_section_end)
    {
      out_tail[0] = '\0';
      dk_set_push (&sections_set, out_section);
    }
  else
    {
      dk_set_push (&sections_set, box_dv_short_nchars ((char *)(out_section), out_tail-out_section));
      dk_free_box ((box_t) out_section);
    }
  out_sections[0] = list_to_array (dk_set_nreverse (sections_set));
}


void
uu_encode_string_session_mime_qp (caddr_t * out_sections, dk_session_t * input,
    int input_length, int uuenctype, int maxlinespersection)
{
  int max_length_of_section;
  unsigned char input_buf[4096];
  int input_len, remaining_input_length = input_length;
  int input_pos;
  dk_set_t sections_set = NULL;
  unsigned char *out_section;
  unsigned char *out_section_end;
  unsigned char *out_tail;
  int column = 0;

  max_length_of_section = maxlinespersection * (76+2);
  /* if even one section is surely longer than the worst input encoded, decrease input_bytes_per_section */
  if (max_length_of_section > (10 + 4*input_length))
    max_length_of_section = 10 + 4*input_length;

  out_tail = out_section = (unsigned char *) dk_alloc_box (max_length_of_section+1, DV_SHORT_STRING);
  out_section_end = out_section + max_length_of_section;

start_next_elt:
  if (0 == remaining_input_length)
    goto input_finished;
  input_len = session_buffered_read (input, (char *)input_buf,
    ((sizeof (input_buf) < remaining_input_length) ? sizeof (input_buf) : remaining_input_length) );
  remaining_input_length -= input_len;

  for (input_pos = 0; input_pos < input_len; input_pos++)
    {
      unsigned char chr = input_buf[input_pos];
      unsigned char enc_1st = uu_qp_enc_1st[chr];

try_output:
      if (!enc_1st)
	goto output_literal;
      switch (chr)
	{
	case ' ': case '\t':
          if ((input_pos+1) >= input_len)
	    goto output_encoded;
	  if ((ASCII_LF == input_buf[input_pos+1]) &&
	      (UUENCTYPE_MIME_QP_TXT == uuenctype) )
	    goto output_encoded;
	  goto output_literal;
	case ASCII_LF:
	  if (UUENCTYPE_MIME_QP_BIN == uuenctype)
	    goto output_encoded;
	  if ((out_tail+2) > out_section_end)
	    goto start_new_section;
	  (out_tail++)[0] = ASCII_CR;
	  (out_tail++)[0] = ASCII_LF;
	  column = 0;
	  continue;
	}
      /* by default, goto output_encoded: */

output_encoded:
      if ((out_tail+3) > out_section_end)
	goto start_new_section;
      if (73 <= column)
	goto output_soft_break;
      (out_tail++)[0] = '=';
      (out_tail++)[0] = enc_1st;
      (out_tail++)[0] = uu_qp_enc_2nd[chr];
      column += 3;
      continue;

output_literal:
      if ((out_tail+1) > out_section_end)
	goto start_new_section;
      if (75 <= column)
	goto output_soft_break;
      (out_tail++)[0] = chr;
      column++;
      continue;

output_soft_break:
      if ((out_tail+3) > out_section_end)
	goto start_new_section;
      (out_tail++)[0] = '=';
      (out_tail++)[0] = ASCII_CR;
      (out_tail++)[0] = ASCII_LF;
      column = 0;
      goto try_output;

start_new_section:
      if (out_tail == out_section_end)
	{
	  out_tail[0] = '\0';
	  dk_set_push (&sections_set, out_section);
	  out_tail = out_section = (unsigned char *) dk_alloc_box (max_length_of_section+1, DV_SHORT_STRING);
	  out_section_end = out_section + max_length_of_section;
	}
      else
	{
	  dk_set_push (&sections_set, box_dv_short_nchars ((char *)out_section, out_tail-out_section));
	  out_tail = out_section;
	}
      goto try_output;
    }
  goto start_next_elt;

input_finished:
  if (out_tail == out_section_end)
    {
      out_tail[0] = '\0';
      dk_set_push (&sections_set, out_section);
    }
  else
    {
      dk_set_push (&sections_set, box_dv_short_nchars ((char *)out_section, out_tail-out_section));
      dk_free_box ((box_t) out_section);
    }
  out_sections[0] = list_to_array (dk_set_nreverse (sections_set));
}


void
uu_encode_string_session (caddr_t * out_sections, dk_session_t * input,
    int uuenctype, int maxlinespersection)
{
  unsigned char *enctable = uu_enctabs[uuenctype];
  int padding_char = uu_paddings[uuenctype];
  int input_bytes_per_line = uu_bytesperline[uuenctype];
  int line_has_prefix = ((UUENCTYPE_NATIVE == uuenctype) || (UUENCTYPE_XX == uuenctype));
  int input_length, remaining_input_length;
  int input_bytes_per_section;
  int sections_count;
  int section_idx;
  buffer_elt_t *input_elt;
  int offset_in_elt;

  if (maxlinespersection < 10)
    maxlinespersection = 10;
  else if (maxlinespersection > 120000)
    maxlinespersection = 120000;
  remaining_input_length = input_length = strses_length (input);
  if (0 == input_length)
    {
      out_sections[0] = dk_alloc_box (0, DV_ARRAY_OF_POINTER);
      return;
    }

  switch (uuenctype)
    {
    case UUENCTYPE_PLAINTEXT:
      uu_encode_string_session_plaintext (out_sections, input, input_length, uuenctype, maxlinespersection);
      return;
    case UUENCTYPE_MIME_QP_TXT:
    case UUENCTYPE_MIME_QP_BIN:
      uu_encode_string_session_mime_qp (out_sections, input, input_length, uuenctype, maxlinespersection);
      return;
    }

  /* if even one section is much longer than input, decrease maxlinespersection */
  if ((input_bytes_per_line * maxlinespersection) > input_length)
    maxlinespersection =
	(input_length + input_bytes_per_line - 1) / input_bytes_per_line;

  input_bytes_per_section = input_bytes_per_line * maxlinespersection;

  sections_count = ((0 == input_length) ? 0 :
      ((input_length + input_bytes_per_section - 1) / input_bytes_per_section) );

  out_sections[0] =
      dk_alloc_box_zero (sections_count * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);

  offset_in_elt = 0;
  input_elt = input->dks_buffer_chain;

  for (section_idx = 0; section_idx < sections_count; section_idx++)
    {
      int lines_count;
      int line_idx;
      int input_bytes, output_bytes;
      unsigned char *out_section;
      unsigned char *out_tail;
      input_bytes = remaining_input_length;
      if (input_bytes > input_bytes_per_section)
	input_bytes = input_bytes_per_section;
      lines_count = (input_bytes + input_bytes_per_line - 1) / input_bytes_per_line;
      output_bytes = (lines_count * (line_has_prefix ? 2 : 1)) + (4 * ((input_bytes + 2) / 3));
      if ((UUENCTYPE_BINHEX == uuenctype) && (1 == (input_bytes % 3)))
	output_bytes--;
      out_tail = out_section = (unsigned char *) dk_alloc_box (output_bytes + 1, DV_SHORT_STRING);
      out_tail[output_bytes] = '\0';
      ((caddr_t *) (out_sections[0]))[section_idx] = (caddr_t) out_section;
      for (line_idx = 0; line_idx < lines_count; line_idx++)
	{
	  unsigned char line_buf[60];
	  unsigned char *line_tail;
	  int bytes_count;
          bytes_count = session_buffered_read (input, (char *) line_buf,
            ((input_bytes_per_line < remaining_input_length) ? input_bytes_per_line : remaining_input_length) );
          remaining_input_length -= bytes_count;
          line_tail = line_buf + bytes_count;

	  if (line_has_prefix)	/* Prefix byte of the input_line contains the length of input_line */
	    (out_tail++)[0] = enctable[bytes_count];

	  /* Complete input triples should be translated to complete output quads */
	  for (line_tail = line_buf; bytes_count >= 3;
	      bytes_count -= 3, line_tail += 3)
	    {
	      (out_tail++)[0] = enctable[line_tail[0] >> 2];
	      (out_tail++)[0] = enctable[((line_tail[0] & 0x03) << 4) | (line_tail[1] >> 4)];
	      (out_tail++)[0] = enctable[((line_tail[1] & 0x0f) << 2) | (line_tail[2] >> 6)];
	      (out_tail++)[0] = enctable[line_tail[2] & 0x3f];
	    }
	  /* Incomplete input triples should be translated to aligned output quads */
	  switch (bytes_count)
	    {
	    case 1:
	      (out_tail++)[0] = enctable[line_tail[0] >> 2];
	      (out_tail++)[0] = enctable[(line_tail[0] & 0x03) << 4];
	      (out_tail++)[0] = padding_char;
	      if (UUENCTYPE_BINHEX != uuenctype)
		(out_tail++)[0] = padding_char;
	      break;
	    case 2:
	      (out_tail++)[0] = enctable[line_tail[0] >> 2];
	      (out_tail++)[0] = enctable[((line_tail[0] & 0x03) << 4) | (line_tail[1] >> 4)];
	      (out_tail++)[0] = enctable[((line_tail[1] & 0x0f) << 2)];
	      (out_tail++)[0] = padding_char;
	      break;
	    }
	  /* Line is ended by newline */
	  (out_tail++)[0] = ASCII_LF;
	}
/*#ifdef DEBUG*/
      if ((out_tail - out_section) != output_bytes)
	GPF_T;
/*#endif*/
    }
}


void
uu_encode_string (caddr_t * out_sections, caddr_t input,
    int uuenctype, int maxlinespersection)
{
  dk_session_t *ses = strses_allocate ();
  CATCH_READ_FAIL (ses)
    {
      session_buffered_write (ses, input, box_length (input) - 1);
    }
  END_WRITE_FAIL (ses)
  uu_encode_string_session (out_sections, ses, uuenctype, maxlinespersection);
  strses_free (ses);
}


unsigned char *uu_decode_line (uu_ctx_t *ctx, unsigned char *target, unsigned char *source)
{
  int *xlat = uu_xlats[ctx->uuc_enctype];
  int padding_char = uu_paddings[ctx->uuc_enctype];
  int hexbits[4];
  int i, j, c, cc;

  switch (ctx->uuc_enctype)
    {
    /* UU and XX have prefix with the length of line thus they are always 4-bytes-aligned */
    case UUENCTYPE_NATIVE:
    case UUENCTYPE_XX:
      i = xlat[(source++)[0]];
      j = uu_linelengths[i] - 1;

      while (j > 0)
	{
	  c = xlat[(source++)[0]] << 2;
	  cc = xlat[(source++)[0]];
	  c |= (cc >> 4);
	  if (i-- > 0)
	    (target++)[0] = c;
	  cc <<= 4;
	  c = xlat[(source++)[0]];
	  cc |= (c >> 2);
	  if (i-- > 0)
	    (target++)[0] = cc;
	  c <<= 6;
	  c |= xlat[(source++)[0]];
	  if (i-- > 0)
	    (target++)[0] = c;
	  j -= 4;
	}
      goto eol_check;
    /* Base64 and BinHex have no prefix and may be wrapped */
    case UUENCTYPE_BASE64_UNIX:
    case UUENCTYPE_BASE64_WIDE:
    case UUENCTYPE_BINHEX:
      hexbits[2] = hexbits[3] = 0; /* To keep gcc 4.0 happy. */
      if (0 != ctx->uuc_trail_len)
	{
	  while (4 > ctx->uuc_trail_len)
	    {
	      if ((-1 != xlat[ACAST (source[0])]) || (padding_char == source[0]))
		return target;
	      ctx->uuc_trail[ctx->uuc_trail_len++] = (source++)[0];
	    }
	  ctx->uuc_trail_len = 0;
	  target = uu_decode_line (ctx, target, ctx->uuc_trail);
	}
      while (
	  (-1 != (hexbits[0] = xlat[ACAST (source[0])])) &&
	  (-1 != (hexbits[1] = xlat[ACAST (source[1])])) &&
	  (-1 != (hexbits[2] = xlat[ACAST (source[2])])) &&
	  (-1 != (hexbits[3] = xlat[ACAST (source[3])])) )
	{
	  (target++)[0] = (hexbits[0] << 2) | (hexbits[1] >> 4);
	  (target++)[0] = (hexbits[1] << 4) | (hexbits[2] >> 2);
	  (target++)[0] = (hexbits[2] << 6) | (hexbits[3]);
	  source += 4;
	}
      if ((-1 != hexbits[0]) && (-1 != hexbits[1]))
	{
	  if (padding_char == source[2])
	    {
	      (target++)[0] = (hexbits[0] << 2) | (hexbits[1] >> 4);
	      ctx->uuc_state = UUSTATE_FINISHED;
	      source += ((padding_char == source[3]) ? 4 : 3);
	      goto eol_check;
	    }
	  if ((-1 != hexbits[2]) && (padding_char == source[3]))
	    {
	      (target++)[0] = (hexbits[0] << 2) | (hexbits[1] >> 4);
	      (target++)[0] = (hexbits[1] << 4) | (hexbits[2] >> 2);
	      ctx->uuc_state = UUSTATE_FINISHED;
	      source += 4;
	      goto eol_check;
	    }
	}
      while (-1 != xlat[ACAST (source[0])])
	ctx->uuc_trail[ctx->uuc_trail_len++] = (source++)[0];
      goto eol_check;
    default:
      GPF_T;
    }
eol_check:
  for (;;)
    {
      switch ((source++)[0])
	{
	case '\0': case ASCII_CR: case ASCII_LF: goto eol_check_passed;
	case ' ': break;
	default:
	  if (UUENCTYPE_NATIVE == ctx->uuc_enctype)
	    {
	      ctx->uuc_bug_count += 1;
	      goto eol_check_passed;
	    }
	  ctx->uuc_errmsg = "Redundant data at the end of line";
	  return NULL;
	}
    }
eol_check_passed:
  return target;
}


int
uu_validate_encoding (unsigned char *ptr, int encoding, int *bh_is_after_colon, int *bug_count)
{
  int i = 0, j, len = 0, flag = 0;
  unsigned char *s = ptr;

  if ((s == NULL) || (s[0] & 0x80))
      return (0);		/* bad string */

  while (*s && *s != ASCII_CR && *s != ASCII_LF)
    {
      s++;
      len++;
      i++;
    }

  if (i == 0)
    return 0;

  switch (encoding)
    {
    case UUENCTYPE_NATIVE:
      goto _t_UU;
    case UUENCTYPE_XX:
      goto _t_XX;
    case UUENCTYPE_BASE64_UNIX:
    case UUENCTYPE_BASE64_WIDE:
      goto _t_B64;
    case UUENCTYPE_BINHEX:
      goto _t_Binhex;
    }

_t_Binhex:			/* Binhex Test */
  len = i;
  s = ptr;

  if (!(bh_is_after_colon[0]))
    {
      if (':' != s[0])
	{
	  if (encoding == UUENCTYPE_BINHEX)
	    return 0;
	  goto _t_B64;
	}
      s++;
      len--;
      bh_is_after_colon[0] = 1;
    }

  while (len && uu_xlat_binhex[ACAST (*s)] != -1)
    {
      len--;
      s++;
    }

  /* allow space characters at the end of the input_line if we are sure */
  /* that this is Binhex encoded data or the input_line was long enough */

  flag = (*s == ':') ? 0 : 1;

  if (*s == ':' && len > 0)
    {
      s++;
      len--;
    }
  if (((i >= 60 && len <= 10) || encoding) && *s == ' ')
    {
      while (len && *s == ' ')
	{
	  s++;
	  len--;
	}
    }

  /*
   * BinHex data shall have exactly 0x40 characters (except the last
   * input_line). We ignore everything with less than 40 (0x28) characters to
   * be flexible
   */

  if (len != 0 || (flag && i < 40))
    {
      if (encoding == UUENCTYPE_BINHEX)
	return 0;
      goto _t_B64;
    }

  bh_is_after_colon[0] = flag;

  return UUENCTYPE_BINHEX;

_t_B64:			/* Base64 Test */
  len = i;
  s = ptr;

  /*
   * Face it: there _are_ Base64 lines that are not a multiple of four
   * in length :-(
   *
   * if (len%4)
   *   goto _t_UU;
   */

  while (len--)
    {
      if ((-1 == uu_xlat_base64[ACAST (s[0])]) && ('=' != s[0]))
	{
	  /* allow space characters at the end of the input_line if we are sure */
	  /* that this is Base64 encoded data or the input_line was long enough */
	  if (((i >= 60 && len <= 10) || encoding) && *s++ == ' ')
	    {
	      while (*s == ' ' && len)
		s++;
	      if (len == 0)
		return ((UUENCTYPE_BASE64_WIDE == encoding) ? encoding : UUENCTYPE_BASE64_UNIX);
	    }
	  if (encoding == UUENCTYPE_BASE64_UNIX)
	    return 0;
	  goto _t_UU;
	}
      else if (*s == '=')
	{			/* special case at end */
	  /* if we know this is UUENCTYPE_BASE64, allow spaces at end of input_line */
	  s++;
	  if (*s == '=' && len >= 1)
	    {
	      len--;
	      s++;
	    }
	  if (encoding && len && *s == ' ')
	    {
	      while (len && *s == ' ')
		{
		  s++;
		  len--;
		}
	    }
	  if (len != 0)
	    {
	      if ((UUENCTYPE_BASE64_UNIX == encoding) || (UUENCTYPE_BASE64_WIDE == encoding))
		return 0;
	      goto _t_UU;
	    }
	  return ((UUENCTYPE_BASE64_WIDE == encoding) ? encoding : UUENCTYPE_BASE64_UNIX);
	}
      s++;
    }
  return ((UUENCTYPE_BASE64_WIDE == encoding) ? encoding : UUENCTYPE_BASE64_UNIX);

_t_UU:
  len = i;
  s = ptr;

  if (uu_xlat_native[ACAST (*s)] == -1)
    {				/* uutest */
      if (encoding == UUENCTYPE_NATIVE)
	return 0;
      goto _t_XX;
    }

  j = uu_linelengths[uu_xlat_native[ACAST (*s)]];

  if (len - 1 == j)		/* remove trailing character */
    len--;
  if (len != j)
    {
      switch (uu_xlat_native[ACAST (*s)] % 3)
	{
	case 1:
	  if (j - 2 == len)
	    j -= 2;
	  break;
	case 2:
	  if (j - 1 == len)
	    j -= 1;
	  break;
	}
    }

  /*
   * some encoders are broken with respect to encoding the last input_line of
   * a file and produce extraneous characters beyond the expected EOL
   * So were not too picky here about the last input_line, as long as it's longer
   * than necessary and shorter than the maximum
   * this tolerance broke the xxdecoding, because xxencoded data was
   * detected as being uuencoded :( so do not accept 'h' as first character
   * also, if the first character is lowercase, do not accept the input_line to
   * have space characters. the only encoder I've heard of which uses
   * lowercase characters at least accepts the special case of encoding
   * 0 as `. The strchr() shouldn't be too expensive here as it's only
   * evaluated if the first character is lowercase, which really shouldn't
   * be in uuencoded text.
   */
  if (len != j &&
      !(*ptr != 'M' && *ptr != 'h' && len > j && len <= uu_linelengths[uu_xlat_native['M']]))
    {
      if (encoding == UUENCTYPE_NATIVE)
	return 0;
      goto _t_XX;		/* bad length */
    }

  if (len != j || islower (*ptr))
    {
      /*
       * if we are not in a 'uuencoded' ctx->uuc_state, do not allow the input_line to have
       * space characters at all. if we know we _are_ decoding uuencoded
       * data, the rest of the input_line, beyond the length of encoded data, may
       * have spaces.
       */
      if (encoding != UUENCTYPE_NATIVE)
	if (strchr ((const char *) ptr, ' ') != NULL)
	  goto _t_XX;
      bug_count[0] += 1;
      len = j;
    }

  while (len--)
    {
      if (-1 == uu_xlat_native[ACAST (*s++)])
	{
	  if (encoding == UUENCTYPE_NATIVE)
	    return 0;
	  goto _t_XX;		/* bad code character */
	}
      if (*s == ' ' && bug_count[0])
	{
	  if (encoding == UUENCTYPE_NATIVE)
	    return 0;
	  goto _t_XX;		/* not semi, but illegal */
	}
    }
  return UUENCTYPE_NATIVE;	/* data is valid */

_t_XX:				/* XX Test */
  len = i;
  s = ptr;

  if (uu_xlat_xx[ACAST (*s)] == -1)
    return 0;

  j = uu_linelengths[uu_xlat_xx[ACAST (*s)]];	/* Same input_line length table as UUencoding */

  if (len - 1 == j)		/* remove trailing character */
    len--;
  if (len != j)
    switch (uu_xlat_native[ACAST (*s)] % 3)
      {
      case 1:
	if (j - 2 == len)
	  j -= 2;
	break;
      case 2:
	if (j - 1 == len)
	  j -= 1;
	break;
      }
  /*
   * some encoders are broken with respect to encoding the last input_line of
   * a file and produce extraneous characters beyond the expected EOL
   * So were not too picky here about the last input_line, as long as it's longer
   * than necessary and shorter than the maximum
   */
  if (len != j && !(*ptr != 'h' && len > j && len <= uu_linelengths[uu_xlat_native['h']]))
    return 0;			/* bad length */

  while (len--)
    {
      if (-1 == uu_xlat_xx[ACAST (*s++)])
	{
	  return 0;		/* bad code character */
	}
    }
  return UUENCTYPE_XX;		/* data is valid */
}

#define FIND_DELIM(var,from,dflt,delim_chr) \
  if (NULL == (var = (unsigned char *)(strchr ((char *)(from), (delim_chr))))) \
    var = (dflt)

void
uu_decode_mime_qp (uu_ctx_t *ctx, caddr_t *out, caddr_t input)
{
  int input_len = box_length (input)-1;
  int boundary_len = ((NULL == ctx->uuc_boundary) ? 0 : box_length (ctx->uuc_boundary)-1);
  unsigned char *input_end = (unsigned char *)(input+input_len);
  unsigned char *input_tail = (unsigned char *)(input);
  unsigned char *decode_tail = (unsigned char *)(input); /* Decoded data is shorter than qp-ed, so we may decode in-place */
  unsigned char *first_cr, *first_lf;
  int append_lf = 1;
  FIND_DELIM (first_cr, input, input_end, ASCII_CR);
  FIND_DELIM (first_lf, input, input_end, ASCII_LF);
  ctx->uuc_boundary_status = -1;
  while (input_tail < input_end)
    {
      unsigned char *input_line = input_tail;
      unsigned char *input_line_end, *input_line_tail;
      if (first_cr < input_line)
	FIND_DELIM (first_cr, input_line, input_end, ASCII_CR);
      if (first_lf < input_line)
	FIND_DELIM (first_lf, input_line, input_end, ASCII_LF);
      input_line_end = ((first_cr < first_lf) ? first_cr : first_lf);
      if ((NULL != ctx->uuc_boundary) &&
	  ('-' == input_line[0]) &&
	  ('-' == input_line[1]) &&
	  (0 == strncmp ((const char *) (input_line + 2), ctx->uuc_boundary, boundary_len)) )
	{
	  ctx->uuc_boundary_status = (('-' == input_line[boundary_len + 2]) ? 1 : 0);
	  if (append_lf && (decode_tail > (unsigned char *)input))
	    decode_tail--;	/* Last CRLF is a part of boundary */
	  break;
	}
      append_lf = 1;
      input_line_tail = input_line;
      while (input_line_tail < input_line_end)
	{
	  int v1, v2;
	  if ('=' != input_line_tail[0])
	    {
	      (decode_tail++)[0] = (input_line_tail++)[0];
	      continue;
	    }
	  if ((0 <= (v1 = uu_hexval[input_line_tail[1]])) &&
	      (0 <= (v2 = uu_hexval[input_line_tail[2]])) )
	    {
	      (decode_tail++)[0] = (v1 << 4) | v2;
	      input_line_tail += 3;
	      continue;
	    }
	  if ((input_line_tail+3) > input_line_end)
	    {
	      append_lf = 0;
	      break;
	    }
	  ctx->uuc_errmsg = "Invalid '=' character in quoted-printable string";
	  return;
	}
      input_tail = input_line_end;
      if ((input_tail < input_end) &&
	  ((ASCII_CR == input_tail[0]) || (ASCII_LF == input_tail[0])) )
	{
	  input_tail++;
	  if ((input_tail < input_end) &&
	    ((ASCII_CR == input_tail[0]) || (ASCII_LF == input_tail[0])) &&
	    (input_tail[-1] != input_tail[0]) )
	  input_tail++;
	  if (append_lf)
	    (decode_tail++)[0] = ASCII_LF;
	}
 /* !!! Linefeeds should be added "between lines", not "after every line" !!! */
/*
      if (append_lf && (input_tail < input_end))
	(decode_tail++)[0] = ASCII_LF;
*/
    }
  out[0] = box_dv_short_nchars (input, (decode_tail - (unsigned char *)input));
  ctx->uuc_state = UUSTATE_FINISHED;
}


void
uu_decode_plaintext (uu_ctx_t *ctx, caddr_t *out, caddr_t input)
{
  int input_len = box_length (input)-1;
  int boundary_len = ((NULL == ctx->uuc_boundary) ? 0 : box_length (ctx->uuc_boundary)-1);
  unsigned char *input_end = (unsigned char *)(input+input_len);
  unsigned char *input_tail = (unsigned char *)(input);
  unsigned char *decode_tail = (unsigned char *)(input); /* Decoded data is shorter than plaintext, so we may decode in-place */
  unsigned char *first_cr, *first_lf;
  FIND_DELIM (first_cr, input, input_end, ASCII_CR);
  FIND_DELIM (first_lf, input, input_end, ASCII_LF);
  ctx->uuc_boundary_status = -1;
  while (input_tail < input_end)
    {
      unsigned char *input_line = input_tail;
      unsigned char *input_line_end;
      int input_line_len;
      if (first_cr < input_line)
	FIND_DELIM (first_cr, input_line, input_end, ASCII_CR);
      if (first_lf < input_line)
	FIND_DELIM (first_lf, input_line, input_end, ASCII_LF);
      input_line_end = ((first_cr < first_lf) ? first_cr : first_lf);
      if ((NULL != ctx->uuc_boundary) &&
	  ('-' == input_line[0]) &&
	  ('-' == input_line[1]) &&
	  (0 == strncmp ((const char *) (input_line + 2), ctx->uuc_boundary, boundary_len)) )
	{
	  ctx->uuc_boundary_status = (('-' == input_line[boundary_len + 2]) ? 1 : 0);
	  if (decode_tail > (unsigned char *)input)
	    decode_tail--;	/* Last CRLF is a part of boundary */
	  break;
	}
      input_line_len = (int) (input_line_end - input_line);
      memmove (decode_tail, input_line, input_line_len);
      decode_tail += input_line_len;
      input_tail = input_line_end;
      if ((input_tail < input_end) &&
	  ((ASCII_CR == input_tail[0]) || (ASCII_LF == input_tail[0])) )
	{
	  input_tail++;
	  if ((input_tail < input_end) &&
	      ((ASCII_CR == input_tail[0]) || (ASCII_LF == input_tail[0])) &&
	      (input_tail[-1] != input_tail[0]) )
	    input_tail++;
	  (decode_tail++)[0] = ASCII_LF;
	}
/* !!! Linefeeds should be added "between lines", not "after every line" !!! */
/*
      if (input_tail < input_end)
        (decode_tail++)[0] = ASCII_LF;
*/
    }
  out[0] = box_dv_short_nchars (input, (decode_tail - (unsigned char *)input));
  ctx->uuc_state = UUSTATE_FINISHED;
}

void
uu_decode_part (uu_ctx_t *ctx, caddr_t *out, caddr_t input)
{
  int orig_enctype = ctx->uuc_enctype;
  int input_len = box_length (input)-1;
  int boundary_len = ((NULL == ctx->uuc_boundary) ? 0 : box_length (ctx->uuc_boundary)-1);
  int bh_is_after_colon = 0;
  int check_res;
  unsigned char *input_end = (unsigned char *)(input+input_len);
  unsigned char *input_tail = (unsigned char *)(input);
  unsigned char *decode_tail = (unsigned char *)(input); /* Decoded data is shorter than plaintext, so we may decode in-place */
  unsigned char *first_cr, *first_lf;

  switch (ctx->uuc_enctype)
    {
    case UUENCTYPE_PLAINTEXT:
      uu_decode_plaintext (ctx, out, input);
      return;
    case UUENCTYPE_MIME_QP_TXT:
    case UUENCTYPE_MIME_QP_BIN:
      uu_decode_mime_qp (ctx, out, input);
      return;
    }

  FIND_DELIM (first_cr, input, input_end, ASCII_CR);
  FIND_DELIM (first_lf, input, input_end, ASCII_LF);
  ctx->uuc_boundary_status = -1;
  while ((input_tail < input_end) && (UUSTATE_FINISHED != ctx->uuc_state))
    {
      unsigned char *input_line = input_tail;
      unsigned char *input_line_end;
      if (first_cr < input_line)
	FIND_DELIM (first_cr, input_line, input_end, ASCII_CR);
      if (first_lf < input_line)
	FIND_DELIM (first_lf, input_line, input_end, ASCII_LF);
      input_line_end = ((first_cr < first_lf) ? first_cr : first_lf);
      input_tail = input_line_end+1;
      /* This is not fully correct, because it would be better to ignore
	 blank lines only in data section but it's safe enough. */
      if (input_line_end == input_line)
	{
	  /* Empty line terminates data encoded with prefixes.
	     If we have no length then we have no data. */
	  if ((UUENCTYPE_NATIVE == ctx->uuc_enctype) || (UUENCTYPE_XX == ctx->uuc_enctype))
	    {
	      if (UUSTATE_BODY == ctx->uuc_state)
		ctx->uuc_state = UUSTATE_END;
	    }
	  continue;
	}
      if ((NULL != ctx->uuc_boundary) &&
	  ('-' == input_line[0]) &&
	  ('-' == input_line[1]) &&
	  (0 == strncmp ((const char *) (input_line + 2), ctx->uuc_boundary, boundary_len)) )
	{
	  ctx->uuc_boundary_status = (('-' == input_line[boundary_len + 2]) ? 1 : 0);
	  continue;
	}
      switch (ctx->uuc_state)
	{
	case UUSTATE_BEGIN:
	  if (!strncmp ((const char *) input_line, "begin ", 6) ||
	      !strncmp ((const char *) input_line, "<pre>begin ", 11) ||
	      !strncmp ((const char *) input_line, "<PRE>begin ", 11) ||
	      !strncmp ((const char *) input_line, "<pre>BEGIN ", 11) ||
	      !strncmp ((const char *) input_line, "<PRE>BEGIN ", 11) )

	    {
	      ctx->uuc_state = UUSTATE_BODY;
	      continue;
	    }
	  check_res = uu_validate_encoding (input_line, ctx->uuc_enctype, &bh_is_after_colon, &(ctx->uuc_bug_count));
	  if ((':' == input_line[0]) && (UUENCTYPE_BINHEX == check_res))
	    {
	      if (check_res != ctx->uuc_enctype)
		{
		  if (UUENCTYPE_UNKNOWN == ctx->uuc_enctype)
		    {
		      ctx->uuc_enctype = UUENCTYPE_BINHEX;
		    }
		  else
		    {
		      ctx->uuc_errmsg = "BinHex-encoded data found instead of data in the specified encoding";
		      return;
		    }
		}
	      bh_is_after_colon = 0;
	      ctx->uuc_state = UUSTATE_BODY;
	      decode_tail = uu_decode_line (ctx, decode_tail, input_line+1);
	      if (ctx->uuc_errmsg)
		return;
	      continue;
	    }
	  if ((0 == check_res) && (UUENCTYPE_UNKNOWN != ctx->uuc_enctype))
	    {
	      check_res = uu_validate_encoding (input_line, 0, &bh_is_after_colon, &(ctx->uuc_bug_count));
	      if (check_res != ctx->uuc_enctype)
		{
		  ctx->uuc_errmsg = "The encoding specified is not the encoding actually applied to data";
		  return;
		}
	    }
	  if (0 == check_res)
	    continue;
	  if (UUENCTYPE_BASE64_UNIX == ctx->uuc_enctype)
	    ctx->uuc_enctype = UUENCTYPE_BASE64_WIDE;
	  if (UUENCTYPE_BASE64_UNIX == check_res)
	    check_res = UUENCTYPE_BASE64_WIDE;
	  if (check_res != ctx->uuc_enctype)
	    {
	      if (UUENCTYPE_UNKNOWN == ctx->uuc_enctype)
		{
		  ctx->uuc_enctype = check_res;
		}
	      else
		{
		  ctx->uuc_errmsg = "Invalid data format, probably wrong encoding is specified";
		  return;
		}
	    }
	  ctx->uuc_state = UUSTATE_BODY;
	  /* no break */
	case UUSTATE_BODY:
	case UUSTATE_END:
	  switch (ctx->uuc_enctype)
	    {
	    case UUENCTYPE_NATIVE:
	    case UUENCTYPE_XX:
	      if (!strncmp ((const char *) input_line, "end", 3))
		{
		  ctx->uuc_state = UUSTATE_FINISHED;
		  continue;
		}
	    if ((UUENCTYPE_NATIVE == ctx->uuc_enctype) && ctx->uuc_bug_count)
		{
		  if (1 < ctx->uuc_bug_count)
		    {
		      ctx->uuc_errmsg = "Poorly formatted UUencode line in the middle of data";
		      return;
		    }
		  ctx->uuc_bug_count += 1;
		}
	      break;
	    case UUENCTYPE_BASE64_UNIX:
	    case UUENCTYPE_BASE64_WIDE:
	      if (('-' == input_line[0]) && ('-' == input_line[1]))
		{
		  ctx->uuc_state = UUSTATE_FINISHED;
		  continue;
		}
	      break;
	    case UUENCTYPE_UNKNOWN:
	      ctx->uuc_errmsg = "Unable to detect encoding automatically";
	      return;
	    }
	  if (UUENCTYPE_UNKNOWN == orig_enctype)
	    {
	      check_res = uu_validate_encoding (input_line, ctx->uuc_enctype, &bh_is_after_colon, &(ctx->uuc_bug_count));
	      if (UUENCTYPE_UNKNOWN == check_res)
		{
		  ctx->uuc_errmsg = "Unable to detect encoding automatically, or corrupted data";
		  return;
		}
	    }
	  decode_tail = uu_decode_line (ctx, decode_tail, input_line);
	  if (ctx->uuc_errmsg)
	    return;
	  continue;
	default:
	  GPF_T;
	}
    }
  if (NULL == ctx->uuc_errmsg)
    out[0] = box_dv_short_nchars (input, (decode_tail - (unsigned char *)input));
}

int uudecode_base64(char * src, char * end)
{
  caddr_t input, out= NULL;
  size_t len;
  uu_ctx_t ctx;
  /* tables_initilized can be zero when
   * the only at startup, so it must be safe
   * to use global var here */
  if (!tables_initialized)
    uu_initialize_tables ();
  memset (&ctx, 0, sizeof (uu_ctx_t));
  ctx.uuc_boundary_status = -1;
  ctx.uuc_enctype = UUENCTYPE_BASE64_UNIX;
  ctx.uuc_state = UUSTATE_BEGIN;
  input = box_dv_short_nchars (src, end - src);
  out = NULL;
  uu_decode_part (&ctx, &out, input);
  dk_free_box (input);
  if ((NULL == out) || (NULL != ctx.uuc_errmsg))
    {
      dk_free_box (out);
      if (NULL == ctx.uuc_errmsg)
	ctx.uuc_errmsg = "generic syntax error";
      sqlr_new_error ("22003", "UUD02", "Data string contains errors [%s]", ctx.uuc_errmsg);
    }
  if (0 != ctx.uuc_trail_len)
    {
      dk_free_box (out);
      sqlr_new_error ("22003", "UUD03", "Encoded data ended prematurely");
    }
  if (UUSTATE_BEGIN == ctx.uuc_state)
    {
      dk_free_box (out);
      sqlr_new_error ("22003", "UUD04", "No data found to be decoded");
    }
  memcpy (src, out, box_length (out));
  len = box_length (out);
  dk_free_box (out);
  return len;
}


#if 0
/* NAMING CONVENTIONS!!! */
struct _uu_section {
  int uu_nl;
  int uu_out_bytes;
  int uu_bytes_on_line;
  int nl;
  int out_bytes;
  int bytes_on_line;
  caddr_t data;
};
typedef struct _uu_section uu_section_t;

static int
chk_QP_string ( caddr_t str, int len, dk_set_t *secs, int maxlines, int breakline )
{
  int i, c;
  uu_section_t *cs;
  if (NULL == *secs)
    {
      cs = dk_alloc_box_zero (sizeof (*cs), DV_CUSTOM);
      dk_set_push (secs, cs);
    }
  else
    cs = (uu_section_t *)(*secs)->data;
  for (i=0;i<len;i++)
    {
      c = str[i];
      if (breakline && c != '\n')
	{
	  cs->uu_out_bytes+=3;
	  cs->uu_bytes_on_line+=3;
	  breakline = 0;
	}
      if (cs->uu_bytes_on_line >= 74)
	{
	  cs->uu_nl++;
	  cs->uu_out_bytes+=3;
	  cs->uu_bytes_on_line = 0;
	  if (cs->uu_nl>=maxlines)
	    {
	      cs = dk_alloc_box_zero (sizeof (*cs), DV_CUSTOM);
	      dk_set_push (secs, cs);
	    }
	}
      if ((c >= 33 && c <= 60) || (c >= 62 && c <= 126) || 9 == c || 32 == c)
	{
	  cs->uu_out_bytes++;
	  cs->uu_bytes_on_line++;
	  breakline = 0;
	}
      else if (c = '\r')
	{
	  breakline = 1;
	}
      else if (breakline && '\n'== c)
	{
	  if (cs->uu_bytes_on_line < (74-1))
	    {
	      cs->uu_bytes_on_line += 2;
	      cs->uu_out_bytes += 2;
	      breakline = 0;
	    }
	  else
	    {
	      i--;
	      cs->uu_bytes_on_line = 74;
	    }
	}
      else
	{
	  if (cs->uu_bytes_on_line < (74-3))
	    {
	      cs->uu_bytes_on_line += 3;
	      cs->uu_out_bytes += 3;
	      breakline = 0;
	    }
	  else
	    {
	      i--;
	      cs->uu_bytes_on_line = 74;
	    }
	}
    }
  return breakline;
}

static int
fin_chk_QP_string (dk_set_t secs, int breakline )
{
  uu_section_t *cs;
  cs = (uu_section_t *)secs->data;
  if (breakline)
    cs->uu_bytes_on_line++;
  if (cs->uu_bytes_on_line)
    cs->uu_nl++;
  cs->uu_bytes_on_line = 0;
  return 0;
}

static int
do_QP_string ( caddr_t str, int len, uu_section_t **secs, int *idx, int maxlines, int breakline )
{
  static char *pps = "0123456789ABCDEF";
  int i, c;
  uu_section_t *cs;
  cs = secs[*idx];
  if (NULL == cs->data)
    {
      cs->data = dk_alloc_box (cs->uu_out_bytes + 1, DV_LONG_STRING);
      cs->data [cs->uu_out_bytes] = '\0';
    }
  for (i=0;i<len;i++)
    {
      assert (cs->out_bytes <= cs->uu_out_bytes);
      assert (cs->nl <= cs->uu_nl);

      c = str[i];
      if (breakline && c != '\n')
	{
	  cs->data[cs->out_bytes++] = '=';
	  cs->data[cs->out_bytes++] = '0';
	  cs->data[cs->out_bytes++] = 'D';
	  cs->bytes_on_line += 3;
	  breakline = 0;
	}
      if (cs->bytes_on_line >= 74)
	{
	  cs->nl++;
	  cs->data[cs->out_bytes++] = '=';
	  cs->data[cs->out_bytes++] = '\r';
	  cs->data[cs->out_bytes++] = '\n';
	  cs->bytes_on_line = 0;
	  if (cs->nl>=maxlines)
	    {
	      (*idx)++;
	      cs = secs[*idx];
	      cs->data = dk_alloc_box(cs->uu_out_bytes + 1, DV_SHORT_STRING);
	      cs->data[cs->uu_out_bytes] = '\0';
	    }
	}
      if ((c >= 33 && c <= 60) || (c >= 62 && c <= 126) || 9 == c || 32 == c)
	{
	  cs->data[cs->out_bytes++] = c;
	  cs->bytes_on_line++;
	  breakline = 0;
	}
      else if ('\r' == c)
	{
	  breakline = 1;
	}
      else if (breakline && '\n'== c)
	{
	  if (cs->bytes_on_line < (74-1))
	    {
	      cs->data[cs->out_bytes++] = '\r';
	      cs->data[cs->out_bytes++] = '\n';
	      cs->bytes_on_line += 2;
	      breakline = 0;
	    }
	  else
	    {
	      i--;
	      cs->bytes_on_line = 74;
	    }
	}
      else
	{
	  if (cs->bytes_on_line < (74-3))
	    {
	      cs->data[cs->out_bytes++] = '=';
	      cs->data[cs->out_bytes++] = pps[0x0f & (c>>4)];
	      cs->data[cs->out_bytes++] = pps[0x0f & c];
	      cs->bytes_on_line += 3;
	      breakline = 0;
	    }
	  else
	    {
	      i--;
	      cs->bytes_on_line = 74;
	    }
	}
    }
  return breakline;
}

void
uu_encode_QP_string_session (caddr_t * out_sections, dk_session_t * input,
    int uuenctype, int maxlinespersection)
{
  int padding_char = 0;
  int input_length, output_length;
  int input_bytes_per_section;
  int sections_count;
  int section_idx;
  buffer_elt_t *input_elt;
  int offset_in_elt;
  dk_set_t sections = NULL;
  int breakline = 0;
  caddr_t out_section;
  uu_section_t **usecs;
  int i, n;

  if (maxlinespersection < 10)
    maxlinespersection = 10;
  else if (maxlinespersection > 120000)
    maxlinespersection = 120000;

  input_length = input->dks_out_fill;
  breakline = chk_QP_string (input->dks_out_buffer, input->dks_out_fill, &sections, maxlinespersection, 0);
  for (input_elt = input->dks_buffer_chain; NULL != input_elt;
      input_elt = input_elt->next)
    {
      input_length += input_elt->fill;
      breakline = chk_QP_string (input_elt->data, input_elt->fill, &sections, maxlinespersection, breakline);
    }
  if (0 == input_length)
    {
      dk_set_free (sections);
      out_sections[0] = dk_alloc_box (0, DV_ARRAY_OF_POINTER);
      return;
    }

  fin_chk_QP_string (sections, breakline);
  sections = dk_set_nreverse (sections);
  usecs = (uu_section_t **)dk_set_to_array (sections);


  section_idx = 0;
  breakline = do_QP_string (input->dks_out_buffer, input->dks_out_fill, usecs, &section_idx, maxlinespersection, 0);
  for (input_elt = input->dks_buffer_chain; NULL != input_elt;
      input_elt = input_elt->next)
    {
      breakline = do_QP_string (input_elt->data, input_elt->fill, usecs, &section_idx, maxlinespersection, breakline);
    }
  n = dk_set_length (sections);
  out_sections[0] =
      dk_alloc_box_zero (n * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  for (i=0;i<n;i++)
    {
      ((caddr_t *) (out_sections[0]))[i] = (caddr_t) usecs[i]->data;
    }
  dk_set_free (sections);
  dk_free_box (usecs);
}


#endif

