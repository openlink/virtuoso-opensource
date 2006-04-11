/* This file is based on ctype.h from the GNU C Library.
   (The GNU C Library. Copyright (C) 1991,92,93,95,96,97,98,99 Free Software Foundation, Inc.)
   ctype.h is in turn based on ISO C99 Standard, subsection 7.4 'Character handling'.
   The only reason for using this file instead of ctype.h is maximum possible portability.
   It is proven by an experiment that some libraries have non-standard tables in ctype.c
*/

#ifndef	_LATIN1CTYPE_H
#define	_LATIN1CTYPE_H

extern const short latin1ctype_props[0x100];  /* Characteristics.  */
extern const unsigned char latin1ctype_tolower[0x100]; /* Case conversions.  */
extern const unsigned char latin1ctype_toupper[0x100]; /* Case conversions.  */

#define	latin1ctype(c, mask) \
  (latin1ctype_props[(unsigned char)(c)] & (mask))

#define latin1tolower(c) (latin1ctype_tolower[(unsigned char)(c)])
#define latin1toupper(c) (latin1ctype_toupper[(unsigned char)(c)])



/* Semantic values of bits in property table.
   Note that they differ from values of bits in POSIX tables. */
# define latin1isupper(c)	latin1ctype((c), 0000001) /* UPPERCASE.                    */
# define latin1islower(c)	latin1ctype((c), 0000002) /* lowercase.                    */
# define latin1isalpha(c)	latin1ctype((c), 0000004) /* Alphabetic.                   */
# define latin1isdigit(c)	latin1ctype((c), 0000010) /* Numeric.                      */
# define latin1isxdigit(c)	latin1ctype((c), 0000020) /* Hexadecimal numeric.          */
# define latin1isspace(c)	latin1ctype((c), 0000040) /* Whitespace.                   */
# define latin1isprint(c)	latin1ctype((c), 0000100) /* Printing.                     */
# define latin1isgraph(c)	latin1ctype((c), 0000200) /* Graphical.                    */
# define latin1isblank(c)	latin1ctype((c), 0001000) /* Blank (usually SPC and TAB).  */
# define latin1iscntrl(c)	latin1ctype((c), 0002000) /* Control character.            */
# define latin1ispunct(c)	latin1ctype((c), 0004000) /* Punctuation.                  */
# define latin1isalnum(c)	latin1ctype((c), 0010000) /* Alphanumeric.                 */

#endif /* latin1ctype.h  */
