/*
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
 *  
*/
#include "ucm.h"


ucm_block_t * ucmb_create (ucm_chain_t *chain, char fill_type, uint32 fill_ucode)
{
  ucm_block_t * res = (ucm_block_t *) dk_alloc (sizeof (ucm_block_t));
  int unibyte;
  memset (res, 0, sizeof (ucm_block_t));
  for (unibyte = 0; unibyte < UBYTE_COUNT; unibyte++)
    {
      res->ucmb_cases[unibyte].type = fill_type;
      res->ucmb_cases[unibyte]._.ucode = fill_ucode;
    }
  res->ucmb_uid = chain->ucmc_length;
  chain->ucmc_length += 1;
  if (NULL != chain->ucmc_last)
    chain->ucmc_last->ucmb_next = res;
  chain->ucmc_last = res;
  return res;
}


ucm_parser_t * ucmp_create (void)
{
  ucm_parser_t *ucmp = (ucm_parser_t *) dk_alloc (sizeof(ucm_parser_t));
  memset (ucmp, 0, sizeof (ucm_parser_t));
  ucmp->ucmp_u2e.ucmc_first = ucmb_create (&(ucmp->ucmp_u2e), UCMB_ERROR, (uint32)UCMB_DEFAULT_SUBST_CHAR);
  ucmp->ucmp_e2u.ucmc_first = ucmb_create (&(ucmp->ucmp_e2u), UCMB_ERROR, 0);
  ucmp->ucmp_subst.type = (uint32)UCMB_ERROR;
  ucmp->ucmp_subst._.script.length = 1;
  ucmp->ucmp_subst._.script.text[0] = UCMB_DEFAULT_SUBST_CHAR;
  return ucmp;
}


void ucmp_destroy (ucm_parser_t * ucmp)
{
  ucm_block_t *iter;
  iter = ucmp->ucmp_u2e.ucmc_first;
  while (NULL != iter)
    {
      ucm_block_t *next = iter->ucmb_next;
      dk_free (iter, sizeof (ucm_block_t));
      iter = next;
    }
  iter = ucmp->ucmp_e2u.ucmc_first;
  while (NULL != iter)
    {
      ucm_block_t *next = iter->ucmb_next;
      dk_free (iter, sizeof (ucm_block_t));
      iter = next;
    }
  dk_free (ucmp, sizeof (ucm_parser_t));
}

#ifdef _DEBUG
void _ucm_bp(void)
{
  static int a;
  a++;
}
#define UCMP_BP _ucm_bp()
#else
#define UCMP_BP
#endif

#define UCMP_ERROR_IF(test,report) \
  do { \
      if ((test)) \
        { UCMP_BP; ucmp->ucmp_error = (report); return; } \
    } while(0)


void ucmp_add_unichar (ucm_parser_t *ucmp, uint32 code, unsigned char *script_text, int script_length, int quality)
{
  ucm_block_t * u2e;
  int unibyte;
  char shift = 0;
  char type;
  int script_idx;
  UCMP_ERROR_IF (code & ~0x00FFFFFF, "Unicode values greater than 0x00FFFFFF are not supported");
  UCMP_ERROR_IF (script_length <= 0, "The encoding sequence is empty");
  UCMP_ERROR_IF (script_length > MAX_ENCLEN, "The encoding sequence is too long");
  UCMP_ERROR_IF (quality > MAX_QUALITY, "The specified encoding quality level is not supported");
  if (UCMP_EBCDIC == ucmp->ucmp_mode)
    {
      shift = ((script_length == 1) ? 0 : 1);
    }
/* Step 1: storing u2e data */
  u2e = ucmp->ucmp_u2e.ucmc_first;
  unibyte = (code & 0x00FF0000) >> 16;
  if (UCMB_JUMP != u2e->ucmb_cases[unibyte].type)
    {
      ucm_block_t * next_u2e = ucmb_create (&(ucmp->ucmp_u2e), UCMB_ERROR, (uint32)UCMB_DEFAULT_SUBST_CHAR);
      u2e->ucmb_cases[unibyte].type = UCMB_JUMP;
      u2e->ucmb_cases[unibyte]._.child = next_u2e;
      u2e = next_u2e;
    }
  else
    u2e = u2e->ucmb_cases[unibyte]._.child;
  unibyte = (code & 0x0000FF00) >> 8;
  if (UCMB_JUMP != u2e->ucmb_cases[unibyte].type)
    {
      ucm_block_t * next_u2e = ucmb_create (&(ucmp->ucmp_u2e), UCMB_ERROR, (uint32)UCMB_DEFAULT_SUBST_CHAR);
      u2e->ucmb_cases[unibyte].type = UCMB_JUMP;
      u2e->ucmb_cases[unibyte]._.child = next_u2e;
      u2e = next_u2e;
    }
  else
    u2e = u2e->ucmb_cases[unibyte]._.child;
  unibyte = (code & 0x000000FF);
  u2e->ucmb_cases[unibyte].type = quality;
  memset(u2e->ucmb_cases[unibyte]._.script.text, 0, MAX_ENCLEN);
  memcpy(u2e->ucmb_cases[unibyte]._.script.text, script_text, script_length);
  u2e->ucmb_cases[unibyte]._.script.length = script_length;
  u2e->ucmb_cases[unibyte]._.script.shift = shift;
/* Step 2: storing e2u data */
  if ((UCMP_EBCDIC == ucmp->ucmp_mode) && (0 == shift))
    {
      UCMP_ERROR_IF ((1 != script_length), "Multibyte encoding sequences are not supported if they are in the initial state of an EBCDIC encoding");
      ucmp->ucmp_shift0_xlat[script_text[0]] = code;
    }
  else
    {
      ucm_block_t * e2u = ucmp->ucmp_e2u.ucmc_first;
      UCMP_ERROR_IF ((UCMP_EBCDIC == ucmp->ucmp_mode) && (!(code & ~0x7F)), "EBCDIC shift is not supported for ASCII characters (0x00 to 0x7F)");
      for (script_idx = 0; script_idx < script_length-1; script_idx++)
	{
	  ucm_block_t * next_e2u;
	  unibyte = script_text[script_idx];
	  type = e2u->ucmb_cases[unibyte].type;
	  if (UCMB_JUMP == type)
	    {
	      e2u = e2u->ucmb_cases[unibyte]._.child;
	      continue;
	    }
	  UCMP_ERROR_IF (UCMB_ERROR != type, "The encoding sequence for the character will never be found");
	  next_e2u = ucmb_create (&(ucmp->ucmp_e2u), UCMB_ERROR, (uint32)UCMB_DEFAULT_SUBST_CHAR);
	  e2u->ucmb_cases[unibyte].type = UCMB_JUMP;
	  e2u->ucmb_cases[unibyte]._.child = next_e2u;
	  e2u = next_e2u;
	}
      unibyte = script_text[script_length-1];
      type = e2u->ucmb_cases[unibyte].type;
      UCMP_ERROR_IF (UCMB_ERROR != type, "The encoding sequence for the character conflicts with one defined above");
      e2u->ucmb_cases[unibyte].type = quality;
      e2u->ucmb_cases[unibyte]._.ucode = code;
    }
}


void ucmp_parse_hex (ucm_parser_t *ucmp, uint32 *code, char **tail_ptr)
{
  char *tail = tail_ptr[0];
  uint32 acc;
  int length = 0;
  code[0] = acc = 0;
  for(;;)
    {
      switch (tail[0])
	{
	case '0': case '1': case '2': case '3': case '4':
	case '5': case '6': case '7': case '8': case '9':
	  acc *= 0x10; acc += (tail[0] - '0');
	  tail++; length++; break;
	case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
	  acc *= 0x10; acc += 0xA + (tail[0] - 'A');
	  tail++; length++; break;
	default:
	  tail_ptr[0] = tail;
	  UCMP_ERROR_IF (isalnum(tail[0]), "Syntax error: invalid hexadecimal digit");
	  goto hex_done;
	}
    }
hex_done:
  tail_ptr[0] = tail;
  UCMP_ERROR_IF (0 == length, "Syntax error: Hexadecimal digits expected but not found");
  UCMP_ERROR_IF (8 < length, "Syntax error: Hexadecimal is too long");
  code[0] = acc;
}


void ucmp_parse_script (ucm_parser_t *ucmp, ucm_datum_t *datum, char **tail_ptr)
{
  char *tail = tail_ptr[0];
  while ((' ' == tail[0]) || ('\t' == tail[0])) tail++;
  datum->type = 0;
  datum->_.script.length = 0;
  UCMP_ERROR_IF ('\\' != tail[0], "Syntax error: no encoding sequence found");
  while ('\\' == tail[0])
    {
      uint32 code;
      tail++;
      UCMP_ERROR_IF ('x' != tail[0], "Syntax error: 'x' expected after '\\' in the encoding sequence");
      tail++;
      ucmp_parse_hex (ucmp, &code, &tail);
      UCMP_ERROR_IF (UBYTE_COUNT <= code, "Syntax error: byte value is too large after '\\' in the encoding sequence");
      UCMP_ERROR_IF (MAX_ENCLEN <= datum->_.script.length, "The resulting encoding sequence is too long");
      datum->_.script.text[datum->_.script.length++] = (char)code;
    }
  while ((' ' == tail[0]) || ('\t' == tail[0])) tail++;
  if ('|' == tail[0])
    {
      uint32 code;
      tail++;
      ucmp_parse_hex (ucmp, &code, &tail);
      UCMP_ERROR_IF (MAX_QUALITY < code, "The quality level value is too large after '|'");
      datum->type = (char)code;
    }
  while ((' ' == tail[0]) || ('\t' == tail[0])) tail++;
  UCMP_ERROR_IF (('\0' != tail[0]) && ('\r' != tail[0]) && ('\n' != tail[0]), "Syntax error: extra characters found after encoding sequence");
  tail_ptr[0] = tail;
}


void ucmp_parse (ucm_parser_t *ucmp, char *text)
{
  char *tail, *text_end;
  tail = text;
  text_end = text + strlen(text);

next_line:
  if (NULL != ucmp->ucmp_error)
    return;
  ucmp->ucmp_line_ctr++;

next_trash_char:
  switch (tail[0])
    {
      case '\0': case '\x1A': return;
      case ' ': case '\t': case '\r': tail++; goto next_trash_char;
      case '\n': tail++; goto next_line;
      case '#':
	goto ignore_rest_of_line;
      case '<':
	goto command_begin;
      default:
	goto markup_begin;
    }

ignore_rest_of_line:
  while (('\0' != tail[0]) && ('\x1A' != tail[0]) && ('\n' != tail[0])) tail++;
  goto next_line;

markup_begin:
  if (!strncmp (tail, "CHARMAP", 7)) goto ignore_rest_of_line;
  if (!strncmp (tail, "END", 3)) goto ignore_rest_of_line;
  UCMP_ERROR_IF (1, "Unknown keyword");

command_begin:
  tail++;
  if (!strncmp (tail, "uconv_class>", 12))
    {
      tail += 12;
      while ((' ' == tail[0]) || ('\t' == tail[0])) tail++;
      if (!strncmp (tail, "\"DBCS\"", 6))
	ucmp->ucmp_mode = UCMP_DBCS;
      else if (!strncmp (tail, "\"SBCS\"", 6))
	ucmp->ucmp_mode = UCMP_SBCS;
      else if (!strncmp (tail, "\"MBCS\"", 6))
	ucmp->ucmp_mode = UCMP_MBCS;
      else if (!strncmp (tail, "\"EBCDIC_STATEFUL\"", 6))
	ucmp->ucmp_mode = UCMP_EBCDIC;
      else UCMP_ERROR_IF (1, "Syntax error: name of encoding class expected after <uconv_class>");
      goto ignore_rest_of_line;
    }
  if (!strncmp (tail, "subchar>", 8))
    {
      tail += 8;
      ucmp_parse_script (ucmp, &(ucmp->ucmp_subst), &tail);
      goto next_line;
    }
  if ('U' == tail[0])
    {
      uint32 code;
      ucm_datum_t tmp_scr;
      tail++;
      ucmp_parse_hex (ucmp, &code, &tail);
      UCMP_ERROR_IF ('>' != tail[0], "Syntax error: no '>' at the end of '<U...' unicode notation");
      tail++;
      ucmp_parse_script (ucmp, &(tmp_scr), &tail);
      ucmp_add_unichar (ucmp, code, tmp_scr._.script.text, tmp_scr._.script.length, tmp_scr.type);
      goto next_line;
    }
  goto ignore_rest_of_line;
}


size_t ucmp_get_u2e_bytecode_size (ucm_parser_t *ucmp)
{
  return ucmp->ucmp_u2e.ucmc_length * UBYTE_COUNT * UCM_U2E_CMD_LEN;
}


size_t ucmp_get_e2u_bytecode_size (ucm_parser_t *ucmp)
{
  return ucmp->ucmp_u2e.ucmc_length * UBYTE_COUNT * sizeof(uint32);
}


void ucmp_compile_u2e_bytecode (ucm_parser_t *ucmp, unsigned char *buf)
{
  unsigned char *tail = buf;
  ucm_block_t *u2e = ucmp->ucmp_u2e.ucmc_first;
  while (NULL != u2e)
    {
      int unibyte = 0;
      for (unibyte = 0; unibyte < UBYTE_COUNT; unibyte++)
	{
	  char type = u2e->ucmb_cases[unibyte].type;
	  uint32 uid;
	  switch (type)
	    {
	    case UCMB_ERROR:
	      tail[0] = ucmp->ucmp_subst._.script.length;
	      memcpy (tail+1, ucmp->ucmp_subst._.script.text, MAX_ENCLEN);
	      break;
	    case UCMB_JUMP:
	      uid = u2e->ucmb_cases[unibyte]._.child->ucmb_uid;
	      tail[0] = '\0';
	      tail[1] = (unsigned char) ((uid & 0x00FF0000) >> 16);
	      tail[2] = (unsigned char) ((uid & 0x0000FF00) >> 8);
	      tail[3] = (unsigned char) (uid & 0x000000FF);
	      break;
	    default:
	      tail[0] = u2e->ucmb_cases[unibyte]._.script.length;
	      memcpy (tail+1, u2e->ucmb_cases[unibyte]._.script.text, MAX_ENCLEN);
	      break;
	    }
	  tail += UCM_U2E_CMD_LEN;
	}
      u2e = u2e->ucmb_next;
    }
}


void ucmp_compile_e2u_bytecode (ucm_parser_t *ucmp, uint32 *buf)
{
  uint32 *tail = buf;
  ucm_block_t *e2u = ucmp->ucmp_e2u.ucmc_first;
  while (NULL != e2u)
    {
      int unibyte = 0;
      for (unibyte = 0; unibyte < UBYTE_COUNT; unibyte++)
	{
	  char type = e2u->ucmb_cases[unibyte].type;
	  uint32 uid;
	  switch (type)
	    {
	    case UCMB_ERROR:
	      tail[0] = 0xFFFFFFFF;
	      break;
	    case UCMB_JUMP:
	      uid = e2u->ucmb_cases[unibyte]._.child->ucmb_uid;
	      tail[0] = 0xFF000000 | uid;
	      break;
	    default:
	      tail[0] = e2u->ucmb_cases[unibyte]._.ucode;
	      break;
	    }
	  tail++;
	}
      e2u = e2u->ucmb_next;
    }
}
