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
#ifndef UCM_H
#define UCM_H
#include "langfunc.h"


/* Abbreviations:
   U2E refers to translation from Unicode to native encoding
   E2U refers to translation from native encoding to Unicode
*/

#define UBYTE_COUNT	0x100	/*!< Number of possible different values of a byte */
#define MAX_ENCLEN	3	/*!< Maximum allowed number of bytes in an encoding sequence of a unicode symbol */
#define UCM_U2E_CMD_LEN	4	/*!< Size of command in U2E bytecode buffer, must be max (4, 1+MAX_ENCLEN) */
#define MAX_QUALITY	5	/*!< Maximum allowed valie for quality of character encoding */

#define UCMB_121	'\0'	/*!< One-to-one correspondence quality, the best */
#define UCMB_ERROR	'\x40'	/*!< The selected byte is illegal in given context */
#define UCMB_JUMP	'\x80'	/*!< The selected byte is not the end of sequence, next byte should be taken in consideration */
#define UCMB_DEFAULT_SUBST_CHAR	'?'	/*!< Default character used when unicode symbol has no analog in the encoding */

#define UCMP_DBCS	0	/*!< Stateless double-byte, single-byte, or mixed encodings (DBCS), the default */
#define UCMP_SBCS	1	/*!< Single-byte encoding (SBCS) */
/*! Stateless multibyte encoding (MBCS) */
#if 0 
#define UCMP_MBCS	2		/* ... as it must be defined */
#else
#define UCMP_MBCS	UCMP_DBCS	/* ... but now we have no special support for MBCS so DBCS and MBCS are handler identically */
#endif
#define	UCMP_EBCDIC	3	/*!< Stateful double-byte, single-byte, or mixed encodings (EBCDIC_STATEFUL) */

/*!< Description of action assigned to particular byte of unicode or to a byte of native-encoded data */
struct ucm_datum_s
{
  char			type;	/*!< Type of action: encoding quality or UCMB_JUMP or UCMB_ERROR */
  union
    {
      struct ucm_block_s *	child;	/*!< When UCMB_JUMP == type, it specifies the block to be used for the next byte of source data */
      uint32			ucode;	/*!< In E2U, it specifies the unicode value of the sequence of bytes in native encoding, when type is an encoding quality */
      /*! In U2E, it specifies the native encoding text for the source Unicode value */
      struct ucm_datum_script_s	
	{
	  unsigned char		length;			/*!< Length of the encoding text, in bytes */
	  unsigned char		shift;			/*!< The number of shifted state where the character should be encoded */
	  unsigned char		text[MAX_ENCLEN];	/*!< The encoding text */
	} script;
    } _;
};

typedef struct ucm_datum_s  ucm_datum_t;



struct ucm_block_s
{
  ucm_datum_t		ucmb_cases[UBYTE_COUNT];
  uint32		ucmb_uid;
  struct ucm_block_s *	ucmb_next;
};

typedef struct ucm_block_s ucm_block_t;


struct ucm_chain_s
{
  ucm_block_t *	ucmc_first;
  ucm_block_t *	ucmc_last;
  int		ucmc_length;
};

typedef struct ucm_chain_s  ucm_chain_t;


struct ucm_parser_s
{
  uint32	ucmp_shift0_xlat[UBYTE_COUNT];	/*!< Forward translation table for single-byte (shift0) part of EBCDIC encoding, unused from other modes */
  ucm_chain_t 	ucmp_u2e;		/*!< Unichars-to-Encoded translation tree */
  ucm_chain_t 	ucmp_e2u;		/*!< Encoded-to-Unichars translation tree */
  ucm_datum_t   ucmp_subst;		/*!< The encoding sequence for all characters that are unknown to the encoding, according to "<subchar>" in UCM */
  int		ucmp_mode;		/*!< UCMB_DBCS, UCMB_SBCS, UCMB_MBCS or UCMB_EBCDIC, according to "<uconv_class>" in UCM */
  size_t	ucmp_minsize_shift0;	/*!< minimum length of one unichar's encoded value in shift0 encoding. */
  size_t	ucmp_minsize;		/*!< minimum length of one unichar's encoded value, to be used as \c eh_minsize. This will not add 1 to the length for SI/SO byte. */
  size_t	ucmp_maxsize;		/*!< maximum length of one unichar's encoded value, to be used as \c eh_maxsize. This may add 1 to the length for SI/SO byte. */
  int		ucmp_line_ctr;
  char *	ucmp_error;
};

typedef struct ucm_parser_s  ucm_parser_t;


extern ucm_block_t * ucmb_create (ucm_chain_t *chain, char fill_type, uint32 fill_ucode);
extern ucm_parser_t * ucmp_create (void);
extern void ucmp_destroy (ucm_parser_t * ucmp);
extern void ucmp_add_unichar (ucm_parser_t *ucmp, uint32 code, unsigned char *script_text, int script_length, int quality);
extern void ucmp_parse_hex (ucm_parser_t *ucmp, uint32 *code, char **tail_ptr);
extern void ucmp_parse_script (ucm_parser_t *ucmp, ucm_datum_t *datum, char **tail_ptr);
extern void ucmp_parse (ucm_parser_t *ucmp, char *text);
extern size_t ucmp_get_u2e_bytecode_size (ucm_parser_t *ucmp);
extern size_t ucmp_get_e2u_bytecode_size (ucm_parser_t *ucmp);
extern void ucmp_compile_u2e_bytecode (ucm_parser_t *ucmp, unsigned char *buf);
extern void ucmp_compile_e2u_bytecode (ucm_parser_t *ucmp, uint32 *buf);


#endif
