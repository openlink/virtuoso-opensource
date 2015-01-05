/*
 *  tst.c
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

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
/*#include <unistd.h>*/
#include "xmlparser.h"

char * buf;
int bsize;
FILE * f = 0;

/*#define XML_DEBUG*/
/* void *
dk_alloc (int sz)
{
  return malloc(sz);
}

void
dk_free (void * ptr, int sz)
{
  free (ptr);
}
*/
size_t
ff (void * read_cd, char * b, size_t len)
{
  int i;
  static int n = 1;

  if (f)
    return fread (b, 1, len, f);

  if (n)
    {
      n = 0;
      for (i = 0; i < bsize && i < len; i++)
	b[i] = buf[i];
      return i;
    }
  return 0;
}

xml_parser_t * parser;

void
start_element_handler (void * ud, const XML_Char * name, const XML_Char ** atts)
{
  size_t s, e;

#ifdef XML_DEBUG
  printf ("Start element '%s'\n", name);
#endif
  XML_ParsePosition (parser, &s, &e);

#ifdef XML_DEBUG
  for (; *atts; atts++)
    printf ("Atts: '%s'\n", *atts);

  printf ("Start pos = %d, end pos = %d\n", s, e);
#endif
}

void
end_element_handler (void * ud, const XML_Char * name)
{
  size_t s, e;
#ifdef XML_DEBUG
  printf ("End element '%s'\n", name);
#endif
  XML_ParsePosition (parser, &s, &e);
#ifdef XML_DEBUG
  printf ("Start pos = %d, end pos = %d\n", s, e);
#endif
}

void
cdh (void * ud, const XML_Char * data, int len)
{
#ifdef XML_DEBUG
  int i;
  printf ("Character data: '");
  for (i = 0; i < len; i++)
    putchar (data[i]);
  printf ("'\n");
#endif
}

/* IvAn/ParseDTD/000721 */
void
erh (void *ud, const XML_Char *refname, int reflen, int isparam, const xml_def_4_entity_t *edef)
{
#ifdef XML_DEBUG
  int i;
  printf ("Entity reference: '");
  for (i = 0; i < reflen; i++)
    putchar (refname[i]);
  printf ("' -> (P:'");
  for (i = 0; edef && edef->xd4e_publicId && edef->xd4e_publicId[i]; i++)
    putchar (edef->xd4e_publicId[i]);
  printf ("') (S:'");
  for (i = 0; edef && edef->xd4e_systemId && edef->xd4e_systemId[i]; i++)
    putchar (edef->xd4e_systemId[i]);
  printf (")'\n");
#endif
}

#if 0
int
main (int argc, char *argv[])
{
  char * bptr, * eptr;
  int i;
  int html_mode = 0;
  char * enc_name = 0;
  char * tenc_name = 0;

  for (;;)
    {
      i = getopt (argc, argv, "hf:e:t:");
      if (i == -1)
	break;

      switch (i)
	{
	case 'h':
	  html_mode = 1;
#ifdef UNIT_DEBUG
	  printf ("HTML mode!\n");
#endif
	  break;
	case 'e':
	  enc_name = optarg;
	  break;
	case 't':
	  tenc_name = optarg;
	  break;
	case 'f':
	  f = fopen (optarg, "r");
	  if (f)
	    break;

	  perror ("can't open file\n");
	  exit (2);
	default:
	  exit (-1);
	}
    }

  if (argc <= optind)
    {
      printf ("USAGE: %s 'STRING'\n", argv[0]);
      exit (-1);
    }

  /*
    dk_memory_initialize ();
    dk_alloc (1);
  */

  bptr = argv[1];
  eptr = bptr + strlen (bptr);

  bsize = argc - optind - 1;
  buf = malloc (bsize);
  for (i = optind + 1; i < bsize; i++)
    buf[i] = strtol (argv[i + 2], 0, 0);

  for (i = 0; i < 1; i++)
    {
      parser = XML_ParserCreate (tenc_name);

      printf ("sizeof (*parser) = %d\n", sizeof (*parser));

      XML_SetEntityEncoding (parser, enc_name);

      XML_ParserInput (parser, ff, 0);

      XML_SetElementHandler (parser, start_element_handler, end_element_handler);
      XML_SetCharacterDataHandler (parser, cdh);
      XML_SetEntityRefHandler (parser, erh);

      if (XML_Parse (parser, argv[optind], strlen (argv[optind]), 1))
	printf ("Successfully parsed!\n");
      else if (PM(err))
	printf ("ERROR %d: %s\n", PM(err), XML_ErrorString (PM(err)));

      XML_ParserFree (parser);
    }
  exit (0);
}
#endif

