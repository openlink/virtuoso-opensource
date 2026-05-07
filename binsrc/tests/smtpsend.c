/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
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
 */

#ifdef WIN32
#  include <winsock2.h>
#  include <ws2tcpip.h>
#  include <windows.h>
#  pragma comment(lib, "ws2_32.lib")
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include <ctype.h>
#include <sys/stat.h>
#include <errno.h>
#include <stdarg.h>

#ifndef WIN32
#  include <unistd.h>
#  include <sys/socket.h>
#  include <netinet/in.h>
#  include <arpa/inet.h>
#  include <sys/types.h>
#  include <netdb.h>
#  include <signal.h>

#  define closesocket(x)		close(x)
#endif

#define TRUE 1
#define FALSE 0

int fd;

void
make_connection (const char *host, int port, int *s)
{
  struct addrinfo hints = { 0 };
  struct addrinfo *res = NULL;
  struct addrinfo *p = NULL;
  char port_str[8];
  int rc;
  int sock = -1;

  snprintf (port_str, sizeof (port_str), "%d", port);

  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;

#if defined(AI_ADDRCONFIG)
  hints.ai_flags |= AI_ADDRCONFIG;
#endif

  if ((rc = getaddrinfo (host, port_str, &hints, &res)) != 0)
    {
      fprintf (stderr, "Cannot resolve host \"%s\": %s\n", host, gai_strerror (rc));
      exit (1);
    }

  for (p = res; p != NULL; p = p->ai_next)
    {
      char addr_str[INET6_ADDRSTRLEN] = "<unknown>";

      if (p->ai_family == AF_INET)
	inet_ntop (AF_INET, &((struct sockaddr_in *) p->ai_addr)->sin_addr, addr_str, sizeof (addr_str));
      else if (p->ai_family == AF_INET6)
	inet_ntop (AF_INET6, &((struct sockaddr_in6 *) p->ai_addr)->sin6_addr, addr_str, sizeof (addr_str));

      if ((sock = socket (p->ai_family, p->ai_socktype, p->ai_protocol)) < 0)
	{
	  fprintf (stderr, "Cannot create socket for %s, trying next...\n", addr_str);
	  continue;
	}

      if (connect (sock, p->ai_addr, (socklen_t) p->ai_addrlen) == 0)
	break;			/* success */

      /* Connection failed — close and try the next address */
      fprintf (stderr, "Cannot connect to %s:%d, trying next...\n", addr_str, port);
      closesocket (sock);
      sock = -1;
    }

  freeaddrinfo (res);

  if (sock < 0)
    {
      fprintf (stderr, "Cannot connect to \"%s\" port %d\n", host, port);
      exit (1);
    }

  *s = sock;
}

int
read_resp (FILE *in)
{
  char buf[4096];
  int rc;
  rc = recv (fd, buf, sizeof (buf), 0);
  if (rc <= 0)
    {
      perror ("recv");
      return rc;
    }
  buf[rc] = 0;
  fprintf (in, "%s", buf);
  return rc;
}

int
send_buf (char *fmt, ...)
{
  char buf[10000];
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
  WORD wVersionRequired = MAKEWORD (2, 2);

  if (WSAStartup (mVersionRequired, &wsaData) != 0)
    {
      printf ("*** FAILED: Windows sockets unable to initialize\n");
      exit (1);
    }
#endif

  if (argc < 3)
    exit (1);

#ifndef WIN32
  signal (SIGPIPE, SIG_IGN);
#endif

  make_connection (argv[1], atoi (argv[2]), &fd);

  if (0 > read_resp (stdout))
    exit (3);
  if (SendMailFile (stdin))
    return 0;
  else
    exit (2);
}
