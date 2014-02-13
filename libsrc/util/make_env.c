/*
 *  make_env.c
 *
 *  $Id$
 *
 *  Add a variable to the environment
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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

#include "libutil.h"

#if defined (HAVE_SETENV)

int
make_env (const char *id, const char *value)
{
  return setenv (id, value, 1);
}

#elif !defined (VMS)

#ifdef WIN32
_CRTIMP extern char **environ;
#elif !defined (__WATCOMC__)
extern char **environ;
#endif

static int localEnv = 0;


int
make_env (const char *id, const char *value)
{
  char newBuf[1024];
  char **newEnviron;
  u_int numEntries;
  size_t size;
  char **ep;
  char *p;

  /*
   *  Make sure we have a local copy of the environment
   *  in case we want to free something in the old environment
   *  which is not safe on all operating systems
   */
  if (!localEnv)
    {
      numEntries = 0;
      for (ep = environ; ep && *ep != NULL; ++ep, numEntries++)
        ;
      newEnviron = (char **) calloc (numEntries + 1, sizeof (char *));
      if (newEnviron == NULL)
	return -1;

      numEntries = 0;
      for (ep = environ; ep && *ep != NULL; ++ep, numEntries++)
        if ((newEnviron[numEntries] = strdup (environ[numEntries])) == NULL)
	  return -1;

      environ = newEnviron;
      localEnv = 1;
    }

  /*
   *  Search for identifier in the environment
   */
  size = strlen (id);
  numEntries = 0;
  for (ep = environ; ep && *ep != NULL; ++ep, numEntries++)
    {
#if defined(WIN32)
      if (!strnicmp (*ep, id, size)
#else
      if (!strncmp (*ep, id, size)
#endif
          && (*ep)[size] == '=')
	{
          break;
	}
    }

  /*
   *  Remove the variable from the environment if
   *  value unspecified
   */
  if (value == NULL || value[0] == '\0')
    {
      if (ep && *ep)
	{
	  free (*ep);
	  for ( ; ep[1]; ep++)
	    ep[0] = ep[1];
	  *ep = NULL;
	}
      return 0;
    }

  /*
   *  Construct a new environment variable
   */
  p = stpcpy (newBuf, id);
  *p++ = '=';
  strncpy (p, value, sizeof (newBuf) - size - 1);

  if (ep == NULL || *ep == NULL)
    {
      newEnviron = (char **) calloc (numEntries + 2, sizeof (char *));
      if (newEnviron == NULL)
	return -1;
      memcpy (newEnviron, environ, numEntries * sizeof (char *));
      ep = &newEnviron[numEntries];
      free (environ);
      environ = newEnviron;
    }
  else
    free (*ep);

  return ((*ep = strdup (newBuf)) == NULL) ? -1 : 0;
}

#else /* VMS version */

#include descrip
#include lnmdef
#include <vms/syscalls.h>

/*
 *  make_env, VMS version: use logical names in LNM$PROCESS
 *
 *  A small piece of intelligence: if the logical name ends in 
 *  '.]', it is created with the attribute LNM$M_CONCEALED.
 */
int
make_env (const char *id, const char *value)
{
  item_list_3_type crlnm_items[3];
  $DESCRIPTOR (tabnam, "LNM$PROCESS_TABLE");
  struct dsc$descriptor lognam;
  unsigned status;
  unsigned long attributes = LNM$M_CONCEALED;
  int i = 0, len;

  len = strlen (value);
  if (len > 2)
    {
      if (value[len - 2] == '.' && value[len - 1] == ']')
        {
          log (L_DEBUG, "Creating logical \"%s\" with concealed attributes", id);
          ITM3ALL (crlnm_items[i], sizeof (attributes), LNM$_ATTRIBUTES, 
              &attributes, 0);
          i++;
        }
    }
  ITM3ALL (crlnm_items[i], len, LNM$_STRING, value, 0); i++;
  ITM3ALL (crlnm_items[i], 0, 0, 0, 0);
  SET_DSC (lognam, id);

  log (L_DEBUG, "Setting logical \"%s\" to \"%s\"", id, value ? value : NULL);
  
  status = sys$crelnm (0, &tabnam, &lognam, 0, crlnm_items);
  if (!VMSOK (status))
    {
      log (L_WARNING, "Could not create logical name \"%s\"", id);
      log (L_WARNING, "VMS error = %d", status);
      return -1;
    }

  return 0;
}

#endif /* VMS version */

#ifdef TEST

void
listenv (void)
{
  char **ep;

  printf ("Environment:\n");

  for (ep = environ; ep && *ep; ep++)
    printf ("%u: [%s]\n", (u_int)(ep - environ) + 1, *ep);
}


int
main (int argc, char **argv)
{
  listenv ();
  for (--argc, ++argv; argc >= 2; argc -= 2, argv += 2)
    {
      if (make_env (argv[0], argv[1]))
	puts ("** make_env failed **");
      listenv ();
    }
  return 0;
}
#endif
