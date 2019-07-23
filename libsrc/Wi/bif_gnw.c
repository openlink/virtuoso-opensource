/*
 *  bif_gnw.c
 *
 *  $Id$
 *
 *  GNW specific extensions
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

#include "sqlnode.h"
#include "security.h"
#include "sqlbif.h"


static char *bif_aux_base64chars =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./";


char *crypt (const char *pw, const char *salt);


/* The lowermost bits come to the end now. */
static char *
bif_aux_encode_n_sextets_to_base64 (unsigned long int x, int n_sextets, char *dest_space)
{
  int i = 0;

  /* E.g. if n_sextets is 2, then leave only twelve lower bits
   * (2**12 = 4096, octal 07777 = 4095)
   */
  x &= ((1 << (6 * n_sextets)) - 1);

#ifdef OTHER_WAY_WOULD_BE_LIKE_THIS	/* That we do not use now. */
  while (i < n_sextets)
    {
      dest_space[i++] = bif_aux_base64chars[(x & 077)];		/* Index between 0 and 63 */
      x >>= 6;			/* Shift off six lowermost bits. */
    }
#else
  i = n_sextets;
  while (i)
    {
      dest_space[--i] = bif_aux_base64chars[(x & 077)];		/* Index between 0 and 63 */
      x >>= 6;			/* Shift off six lowermost bits. */
    }
#endif

  dest_space[n_sextets] = '\0';	/* Add terminating zero. */

  return (dest_space);
}


/* Calls Unix's one-directional passwd crypt. See man crypt
 * This one can be furthermore called with the second arg salt
 * specified as integer (only twelve lowest bits are significant (0 4095)
 * which is then converted to the required [a-zA-Z0-9./]*2 salt string
 * with the above bif_aux_encode_n_sextets_to_base64 function.
 */

#ifdef UNIX
static caddr_t
bif_crypt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str_to_be_crypted = bif_string_or_null_arg (qst, args, 0, "crypt");
  caddr_t salt = bif_arg (qst, args, 1, "crypt");
  caddr_t res;
  dtp_t salt_type = DV_TYPE_OF (salt);
  char *salt_str, *crypt_result;
  char salt_space[10];

  if (NULL == str_to_be_crypted)
    {
      return (NEW_DB_NULL);
    }
  if (DV_DB_NULL == salt_type)
    {
      return (NEW_DB_NULL);
    }

  if (is_some_sort_of_a_string (salt_type))
    {
      salt_str = salt;
    }
  else if (is_some_sort_of_an_integer (salt_type))
    {
      long salt_n = unbox (salt);
      salt_str = bif_aux_encode_n_sextets_to_base64 (salt_n, 2, salt_space);
    }
  else /* if (NOT is_some_sort_of_a_string (salt_type)) */
    {
      sqlr_new_error ("21S01", "SR096",
	  "Function crypt needs a string or integer as its second argument."
	  " Not an arg of type %s (%d)",
	  dv_type_title (salt_type), salt_type);
      salt_str = ""; /* make cc happy */
    }

  /* We borrow here time_mtx for other purposes, because crypt returns
   * a pointer to static string.
   */
  mutex_enter (time_mtx);
  crypt_result = crypt (str_to_be_crypted, salt_str);
  res = box_dv_short_string (crypt_result);
  mutex_leave (time_mtx);
  return (res);

}
#endif /* UNIX for bif_crypt */




/* Like bif_date_string but generates the date string as seen in GMT zone. */
static caddr_t
bif_datestringGMT (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (bif_date_string (qst, err_ret, args));
}


/*
 *  bif_decode_to_intvec  --  Coded by Antti Karttunen 8. August 1998
 *
 *  Takes three arguments: in in_string varchar,
 *                         in alphabet  varchar,
 *                         in out_width_in_bits integer
 *
 *  The first argument, in_string is the string of zero or more characters,
 *
 *  The second argument, alphabet, should be a string of 2^n (where n = 1 - 8),
 *  that is 2, 4, 8, 16, 32, 64, 128 or 256 distinct characters.
 *
 *  The in_string should contain only characters present in alphabet.
 *
 *  The third argument, out_width_in_bits is a number between 1 and 32,
 *  which specifies in how wide chunks the resulting bits should be stored
 *  into the resulting vector. If it is 1, then each element is an
 *  integer either 0 or 1, that is, a proper bit.
 *  If it is 8, then each element is a byte in range 0 - 255,
 *  and if it is 16, then they are words in range 0 - 65535,
 *  and with maximum. 32 they are longwords in range 0 - 4294967295
 *
 *  The alphabet is usually something like static char *bif_aux_base64chars
 *  presented in this module
 *  (i.e. 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./')
 *  that is appropriate for decoding uuencoded and encrypted strings,
 *  where each encoded character presents six bits. (log2(64) = 6)
 *
 */
static caddr_t
bif_decode_to_intvec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t in_string = bif_string_or_null_arg (qst, args, 0, "decode_to_intvec");
  caddr_t alphabet = bif_string_arg (qst, args, 1, "decode_to_intvec");
  long out_width_in_bits = bif_long_arg (qst, args, 2, "decode_to_intvec");
  caddr_t vec;			/* The resulting vector of integers. */
  int orig_alphalen, alphalen, in_width_in_bits, string_len;
  int bits_total, vec_len;
  int i, j, k, l;
  unsigned int in_bits, high_bit_mask;
  unsigned long int out_bits;

  orig_alphalen = alphalen = box_length (alphabet) - 1;
  in_width_in_bits = 0;

  if (alphalen < 2)
    {
      goto invalid_alphabet;
    }

  while (0 == (alphalen & 1))	/* Shift as long as bit-0 stays zero. */
    {
      alphalen >>= 1;		/* Shift right once. */
      in_width_in_bits++;
    }

  if (alphalen > 1)		/* There are more than one 1-bits present in alphalen? */
    {
    invalid_alphabet:
      sqlr_new_error ("21S01", "GN001",
	  "Function decode_to_intvec needs an alphabet string of length 2, 4, 8, 16, 32, 64, 128 or 256 as its second argument "
	  "not a string of length %d", orig_alphalen);
    }

  if ((out_width_in_bits < 1) || (out_width_in_bits > 32))
    {
      sqlr_new_error ("21S01", "GN002",
	  "Function decode_to_intvec needs as its third argument "
	  "an integer between 1 - 32");
    }

  if (NULL == in_string)
    {
      return (NEW_DB_NULL);
    }
  string_len = box_length (in_string) - 1;

  bits_total = (string_len * in_width_in_bits);

  vec_len = bits_total / out_width_in_bits;
  if (bits_total % out_width_in_bits)	/* If does not divide exactly, */
    {
      vec_len++;
    }				/* then add one to result vec's length. */

  vec = dk_alloc_box ((vec_len * sizeof (ptrlong)), DV_ARRAY_OF_LONG);

  i = j = 0;
  high_bit_mask = (1 << (in_width_in_bits - 1));
  /* 1 -> 1, 2 -> 2, 3 -> 4, 4 -> 8, 5 -> 16, 6 -> 32, 7 -> 64, 8 -> 128 */
  out_bits = l = 0;

  while (i < string_len)
    {
      char *ptr_to_string = strchr (alphabet, ((unsigned char *) in_string)[i++]);

      if (ptr_to_string)
	{
	  in_bits = (ptr_to_string - alphabet);
	}
      else
	{
	  in_bits = 0;
	}			/* The letter was not found from alphabet */

      /* This order is used now, from bit-(in_width_in_bits-1) to bit-0. */
      for (k = 0; (k < in_width_in_bits); k++, in_bits <<= 1, out_bits <<= 1)
	{
	  out_bits |= ((in_bits & high_bit_mask) ? 1 : 0);
	  if (++l == out_width_in_bits)
	    {
	      ((ptrlong *) vec)[j++] = out_bits;
	      out_bits = l = 0;
	    }
	}
    }

  /* If there are still some bits to output?
   * I.e. the remainder (bits_total%out_width_in_bits) is not zero.
   * then put the last batch of out_bits as the last element of the output vector
   */
  if (l != 0)
    {
      ((ptrlong *) vec)[j] = out_bits;
    }

  return (vec);			/* Return the resulting vector. */
}

void
bif_gnw_init (void)
{
  bif_define_typed ("datestringGMT", bif_datestringGMT, & bt_varchar);
  bif_define_typed ("decode_to_intvec", bif_decode_to_intvec, & bt_any);

#ifdef UNIX
  bif_define_typed ("unix_crypt", bif_crypt, & bt_varchar);
#endif
}
