/*
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include <ctype.h>
#ifndef WIN32
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <netdb.h>
#include <signal.h>
#else
#include <winsock.h>
#endif

#include <sys/stat.h>
#include <errno.h>
#include <stdarg.h>

#define TRUE 1
#define FALSE 0

int fd;

void
make_connection (char *host, int port, int *s)
{
  struct hostent *phe;
  struct sockaddr_in sin;


  /* initilize sockaddr_in structure */
  memset (&sin, 0, sizeof (sin));
  sin.sin_family = AF_INET;
  sin.sin_port = htons ((u_short) port);

  if ((phe = gethostbyname (host)) != NULL)
    {
      memcpy (&sin.sin_addr, phe->h_addr, phe->h_length);
    }
  else
    {
      fprintf (stderr, "Cannot get hostname %s\n", host);
      exit (1);
    }


/* create socket */
  *s = socket (PF_INET, SOCK_STREAM, 0);
  if (*s < 0)
    {
      fprintf (stderr, "Cannot create socket\n");
      exit (1);

    }

/* connect */
  if (connect (*s, (struct sockaddr *) &sin, sizeof (sin)) < 0)
    {
      fprintf (stderr, "Cannot connect, errno = %d\n", errno);
      perror ("");
      exit (1);

    }
}

int
read_resp (FILE * in)
{
  char buf [4096];
  int rc;
  rc = recv (fd, buf, sizeof (buf), 0);
  if (rc <= 0)
    {
      perror ("recv");
      return rc;
    }
  buf [rc] = 0;
  fprintf (in, "%s", buf);
  return rc;
}

int
send_buf (char * fmt, ...)
{
  char buf [10000];
  va_list list;
  int rc;

  va_start (list, fmt);
  vsprintf (buf, fmt, list);
  rc = send (fd, buf, strlen (buf), 0);
  if (rc < 0)
    {
      perror ("send");
      va_end (list);
      return rc;
    }
  va_end (list);
  return rc;
}


int
strnicmp (const char *s1, const char *s2, size_t n)
{
  int cmp;

  while (*s1 && n)
    {
      n--;
      if ((cmp = toupper (*s1) - toupper (*s2)) != 0)
	return cmp;
      s1++;
      s2++;
    }
  if (n)
    return (*s2) ? -1 : 0;
  return 0;
}


int
SendMailFile (FILE *in)
{
  char szBuffer[513];
  int _read_resp = 1;

  while (!feof (in))
    {
      int buf_len;
      if (!fgets (szBuffer, sizeof (szBuffer), in))
	continue;
      buf_len = strlen (szBuffer);
      while (buf_len > 0 && isspace (szBuffer[buf_len - 1]))
	{
	  szBuffer[buf_len - 1] = 0;
	  buf_len--;
	}
      fprintf (stdout, "%s\n", szBuffer);
      if (0 == strnicmp (szBuffer, "DATA", 4))
	{
	  if (0 > send_buf ("%s\r\n", szBuffer))
	    goto error;
	  if (0 > read_resp (stdout))
	    goto error;

	  _read_resp = 0;
	}
      else if (0 == strcmp (szBuffer, "."))
	{
	  if (0 > send_buf ("%s\r\n", szBuffer))
	    goto error;
	  if (0 > read_resp (stdout))
	    goto error;
	  _read_resp = 1;
	}
      else
	{
	  if (0 > send_buf ("%s\r\n", szBuffer))
	    goto error;
	  if (_read_resp)
	    if (0 > read_resp (stdout))
	      goto error;
	};
    };
  return TRUE;
error:
  return FALSE;
}


int
main (int argc, char *argv[])
{
#ifdef WIN32
  WSADATA wsaData;
  WORD wVersionRequired = (1 << 8) + 1;
#endif
  if (argc < 3)
    exit (1);
#ifndef WIN32
  signal (SIGPIPE, SIG_IGN);
#else
  if (WSAStartup (wVersionRequired, &wsaData))
    {
      printf ("*** FAILED: Windows sockets unable to initialize\n");
      exit (1);
    }
#endif
  make_connection (argv[1], atoi (argv[2]), &fd);
  if (0 > read_resp (stdout))
    exit (3);
  if (SendMailFile (stdin))
    return 0;
  else
    exit (2);
}
