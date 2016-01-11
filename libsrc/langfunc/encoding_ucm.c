/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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
 *  
*/
#include "langfunc.h"
#include "ucm.h"


/* Application data for UCM DBCS encoding are placed in the following manner:
   @0@ offset of the U2E bytecode ( = 4 + length of E2U bytecode )
   - E2U bytecode
   - U2E bytecode
 */

unichar eh_decode_char__ucm_dbcs (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  __constcharptr src_tail = src_begin_ptr[0];
  va_list tail;
  encoding_handler_t *my_eh;
  uint32 *my_ucm, *xlat, xval;
  if (src_tail >= src_buf_end)
    return UNICHAR_EOD;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_ucm = (uint32 *)(my_eh->eh_appdata);
  my_ucm += 1; /* ...to skip the offset of the U2E bytecode */
  xlat = my_ucm;
next_char:
  xval = xlat[(unsigned char)((src_tail++)[0])];
  if (!(xval & 0xFF000000))
    {
      src_begin_ptr[0] = src_tail;
      return xval;
    }
  if (0xFFFFFFFF == xval)
    return UNICHAR_BAD_ENCODING;
  xlat = my_ucm + ((xval & 0x00FFFFFF) * UBYTE_COUNT);
  if (src_tail < src_buf_end)
    goto next_char;
  return UNICHAR_NO_DATA; /* we have a partial char at the end */
}


char *eh_encode_char__ucm_dbcs (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  unsigned char *my_ucm, *xlat, *xval;
  uint32 jump, len;
  if (char_to_put & ~0x00FFFFFF)
    return tgt_buf;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_ucm = (unsigned char *)(my_eh->eh_appdata);
  my_ucm += sizeof(uint32); /* ...to skip the offset of the U2E bytecode */
  xlat = my_ucm;
  xval = xlat + (UCM_U2E_CMD_LEN * ((char_to_put & 0x00FF0000) >> 16));
  if (xval[0])
    goto xval_found;
  jump = (xval[1] << 16) | (xval[2] << 8) | xval[3];
  xlat = my_ucm + jump * (UBYTE_COUNT * UCM_U2E_CMD_LEN);
  xval = xlat + (UCM_U2E_CMD_LEN * ((char_to_put & 0x0000FF00) >> 8));
  if (xval[0])
    goto xval_found;
  jump = (xval[1] << 16) | (xval[2] << 8) | xval[3];
  xlat = my_ucm + jump * (UBYTE_COUNT * UCM_U2E_CMD_LEN);
  xval = xlat + (UCM_U2E_CMD_LEN * (char_to_put & 0x000000FF));
xval_found:
  len = xval[0];
  if ((tgt_buf + len) > tgt_buf_end)
    return (char *)UNICHAR_NO_ROOM;
  while (len--) (tgt_buf++)[0] = (++xval)[0];
  return tgt_buf;
}


int eh_decode_buffer__ucm_dbcs (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  va_list tail;
  encoding_handler_t *my_eh;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__ucm_dbcs(src_begin_ptr, src_buf_end, my_eh);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  return res ? res : UNICHAR_BAD_ENCODING;
	default:
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer_to_wchar__ucm_dbcs (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  va_list tail;
  encoding_handler_t *my_eh;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__ucm_dbcs(src_begin_ptr, src_buf_end, my_eh);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  return res ? res : UNICHAR_BAD_ENCODING;
	default:
          if (curr & ~0xffffl)
            return UNICHAR_OUT_OF_WCHAR;
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


char *eh_encode_buffer__ucm_dbcs (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__ucm_dbcs (src_buf[0], tgt_buf, tgt_buf_end, my_eh);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__ucm_dbcs (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__ucm_dbcs (src_buf[0], tgt_buf, tgt_buf_end, my_eh);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


encoding_handler_t eh__ucm_dbcs_pattern = {
  NULL,
  1, MAX_ENCLEN, 0x0000, 0, NULL, NULL,
  eh_decode_char__ucm_dbcs,
  eh_decode_buffer__ucm_dbcs,
  eh_decode_buffer_to_wchar__ucm_dbcs,
  eh_encode_char__ucm_dbcs,
  eh_encode_buffer__ucm_dbcs,
  eh_encode_wchar_buffer__ucm_dbcs
};


/* Application data for UCM EBCDIC encoding are placed in the following manner:
   - offset of the U2E bytecode for ebcdic_0 ( = 4 + length of xlat table + length of E2U bytecode )
   - E2U single-byte xlat table
   - E2U bytecode
   - U2E bytecode

 */

unichar eh_decode_char__ucm_ebcdic (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  __constcharptr src_tail = src_begin_ptr[0];
  va_list tail;
  encoding_handler_t *my_eh;
  int *state_ptr;
  unsigned char uchr;
  uint32 *my_ucm, *xlat, xval;
  if (src_tail >= src_buf_end)
    return UNICHAR_EOD;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr =  va_arg (tail, int *);
  my_ucm = (uint32 *)(my_eh->eh_appdata);
  if (0 == state_ptr[0])
    goto state0;
  goto state1;

state0:
  uchr = (unsigned char)((src_tail++)[0]);
  if (0x0F == uchr)
    {
      state_ptr[0] = 1;
      src_begin_ptr[0] = src_tail;
      if (src_tail >= src_buf_end)
	return UNICHAR_EOD;
      goto state1;
    }
  xlat = my_ucm+1; /* ...to skip the offset of the U2E bytecode */
  xval = xlat[uchr];
  if (0xFFFFFFFF == xval)
    return UNICHAR_BAD_ENCODING;
  src_begin_ptr[0] = src_tail;
  return xval;

state1:

  xlat = my_ucm + 1 + UBYTE_COUNT;
next_char:
  uchr = (unsigned char)((src_tail++)[0]);
  if (0x0F == src_tail[0])
    {
      state_ptr[0] = 1;
      src_begin_ptr[0] = src_tail;
      if (src_tail >= src_buf_end)
	return UNICHAR_EOD;
      goto state1;
    }
  xval = xlat[uchr];
  if (!(xval & 0xFF000000))
    {
      src_begin_ptr[0] = src_tail;
      return xval;
    }
  if (0xFFFFFFFF == xval)
    return UNICHAR_BAD_ENCODING;
  xlat = my_ucm + ((xval & 0x00FFFFFF) * UBYTE_COUNT);
  if (src_tail < src_buf_end)
    goto next_char;
  return UNICHAR_NO_DATA; /* we have a partial char at the end */
}


char *eh_encode_char__ucm_ebcdic (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  unsigned char *my_ucm, *xlat, *xval;
  uint32 jump, len;
  if (char_to_put & ~0x00FFFFFF)
    return tgt_buf;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_ucm = (unsigned char *)(my_eh->eh_appdata);

  xlat = my_ucm + sizeof(uint32) + sizeof(uint32) * UBYTE_COUNT; /* ...to skip the offset of the U2E bytecode and singlechar xlat */
  xval = xlat + (UCM_U2E_CMD_LEN * ((char_to_put & 0x00FF0000) >> 16));
  if (xval[0])
    goto xval_found;
  jump = (xval[1] << 16) | (xval[2] << 8) | xval[3];
  xlat = my_ucm + jump * (UBYTE_COUNT * UCM_U2E_CMD_LEN);
  xval = xlat + (UCM_U2E_CMD_LEN * ((char_to_put & 0x0000FF00) >> 8));
  if (xval[0])
    goto xval_found;
  jump = (xval[1] << 16) | (xval[2] << 8) | xval[3];
  xlat = my_ucm + jump * (UBYTE_COUNT * UCM_U2E_CMD_LEN);
  xval = xlat + (UCM_U2E_CMD_LEN * (char_to_put & 0x000000FF));
xval_found:
  len = xval[0];
  if ((tgt_buf + len) > tgt_buf_end)
    return (char *)UNICHAR_NO_ROOM;
  while (len--) (tgt_buf++)[0] = (++xval)[0];
  return tgt_buf;
}


int eh_decode_buffer__ucm_ebcdic (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  va_list tail;
  encoding_handler_t *my_eh;
  int *state_ptr;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr =  va_arg (tail, int *);
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__ucm_ebcdic(src_begin_ptr, src_buf_end, my_eh, state_ptr);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  return res ? res : UNICHAR_BAD_ENCODING;
	default:
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer_to_wchar__ucm_ebcdic (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  va_list tail;
  encoding_handler_t *my_eh;
  int *state_ptr;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr =  va_arg (tail, int *);
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__ucm_ebcdic(src_begin_ptr, src_buf_end, my_eh, state_ptr);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  return res ? res : UNICHAR_BAD_ENCODING;
	default:
          if (curr & ~0xffffl)
            return UNICHAR_OUT_OF_WCHAR;
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}
    }
  return res;
}


char *
eh_encode_buffer__ucm_ebcdic (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  int *state_ptr;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr = va_arg (tail, int *);
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__ucm_ebcdic (src_buf[0], tgt_buf, tgt_buf_end, my_eh, state_ptr);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


char *
eh_encode_wchar_buffer__ucm_ebcdic (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  int *state_ptr;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr = va_arg (tail, int *);
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__ucm_ebcdic (src_buf[0], tgt_buf, tgt_buf_end, my_eh, state_ptr);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


encoding_handler_t eh__ucm_ebcdic_pattern = {
  NULL,
  1, MAX_ENCLEN, 0x0000, 0, NULL, NULL,
  eh_decode_char__ucm_ebcdic,
  eh_decode_buffer__ucm_ebcdic,
  eh_decode_buffer_to_wchar__ucm_ebcdic,
  eh_encode_char__ucm_ebcdic,
  eh_encode_buffer__ucm_ebcdic,
  eh_encode_wchar_buffer__ucm_ebcdic
};


encoding_handler_t * eh_create_ucm_handler (char *encoding_names, char *ucm_file_name,
  eh_ucm_log_callback *info_logger, eh_ucm_log_callback *error_logger )
{
  FILE *ucm_file;
  long ucm_file_len;
  char *ucm_file_text;
  ucm_parser_t *ucmp;
  ucm_file = fopen(ucm_file_name, "rb");
  if (NULL == ucm_file)
    {
      error_logger ("Unable to open UCM file '%s' for reading", ucm_file_name);
      return NULL;
    }
  fseek (ucm_file, 0, SEEK_END);
  ucm_file_len = ftell (ucm_file);
  fseek (ucm_file, 0, SEEK_SET);
  ucm_file_text = (char *) dk_alloc (ucm_file_len+1);
  if (!ucm_file_text || 1 != fread (ucm_file_text, ucm_file_len, 1, ucm_file))
    {
      fclose (ucm_file);
      error_logger ("Unable to read %ld bytes from UCM file '%s' for reading", ucm_file_len, ucm_file_name);
      if (ucm_file_text)
        dk_free (ucm_file_text, ucm_file_len+1);
      return NULL;
    }
  fclose (ucm_file);
  ucm_file_text[ucm_file_len] = '\0';
  ucmp = ucmp_create ();
  ucmp_parse (ucmp, ucm_file_text);
  if (NULL != ucmp->ucmp_error)
    {
      error_logger ("Error in UCM file '%s', line %d: %s", ucm_file_name, ucmp->ucmp_line_ctr, ucmp->ucmp_error);
      ucmp_destroy (ucmp);
      return NULL;
    }
  switch (ucmp->ucmp_mode)
    {
    case UCMP_DBCS:
      {
	encoding_handler_t *res;
	size_t u2e_size, e2u_size;
	unsigned char *bytecode_buf, *bytecode_tail;
	u2e_size = ucmp_get_u2e_bytecode_size (ucmp);
	e2u_size = ucmp_get_e2u_bytecode_size (ucmp);
	bytecode_tail = bytecode_buf = (unsigned char *) dk_alloc (sizeof(uint32) + e2u_size + u2e_size);
	((uint32 *)(bytecode_tail))[0] = (uint32) (sizeof(uint32) + e2u_size);
	bytecode_tail += sizeof (uint32);
	ucmp_compile_e2u_bytecode (ucmp, (uint32 *)bytecode_tail);
        bytecode_tail += e2u_size;
	ucmp_compile_u2e_bytecode (ucmp, bytecode_tail);
	ucmp_destroy (ucmp);
	res = eh_duplicate_handler (&eh__ucm_dbcs_pattern, encoding_names);
	res->eh_appdata = bytecode_buf;
	info_logger ("DBCS encoding '%s' is created using UCM file '%s'.", encoding_names, ucm_file_name);
	return res;
      }
    case UCMP_EBCDIC:
      {
	encoding_handler_t *res;
	size_t xlat_size, u2e_size, e2u_size;
	unsigned char *bytecode_buf, *bytecode_tail;
	xlat_size = sizeof(uint32) * UBYTE_COUNT;
	u2e_size = ucmp_get_u2e_bytecode_size (ucmp);
	e2u_size = ucmp_get_e2u_bytecode_size (ucmp);
	bytecode_tail = bytecode_buf = (unsigned char *) dk_alloc (sizeof(uint32) + xlat_size + e2u_size + u2e_size);
	((uint32 *)(bytecode_tail))[0] = (uint32) (sizeof(uint32) + xlat_size + e2u_size);
	bytecode_tail += sizeof (uint32);
	memcpy (bytecode_tail, ucmp->ucmp_shift0_xlat, xlat_size);
        bytecode_tail += xlat_size;
	ucmp_compile_e2u_bytecode (ucmp, (uint32 *)bytecode_tail);
        bytecode_tail += e2u_size;
	ucmp_compile_u2e_bytecode (ucmp, bytecode_tail);
	ucmp_destroy (ucmp);
	res = eh_duplicate_handler (&eh__ucm_ebcdic_pattern, encoding_names);
	res->eh_appdata = bytecode_buf;
	info_logger ("EBCDIC encoding '%s' is created using UCM file '%s'.", encoding_names, ucm_file_name);
	return res;
      }
    }
  return NULL;
}
