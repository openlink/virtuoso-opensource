/*
 *  $Id$
 *
 *  URLSIMU - Url simulator
 *
 *  This program can be used for testing www-server software. It reads from
 *  a file a server address and a list of url-lines. It then writes these
 *  url-lines to the address given and reads back the responses.
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#include <sys/types.h>


#include <signal.h>
#include <sys/types.h>
#include <Dk.h>
#include <libutil.h>
#include "timeacct.h"

#ifndef WIN32
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#define closesocket(fd) close(fd)
#else
#define sleep(x) Sleep((x)*1000)
#endif


#define BLEN 1024
#define MAX_URL_SIZE 4000

char vec[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

static void l_usage (char *fname);
static void l_handle_file (FILE * fp);
/*void make_connection (char *host, int port, int *s);*/
static void l_handle_url (char *host, int port, char *line, int repeat);
static void l_handle_post (char *host, int port, char *line, int repeat);
#define TRUE 1
#define FALSE 0
#define CR '\x0D'
#define LF '\x0A'

static timer_account_t url_times;
static timer_account_t global_times;
static int silent_mode;
static int store_to_file;
static int send_header_line;
static int pipeline = 0;
static int big_silent_mode;
static int no_sleep_mode = 0;
static long closevalue = 0;
static char *user;
static char *passwd;
static char buffer[512];
static char *szStart = buffer;
static char *szEnd = buffer;
static char *to_file;
static char *header_line;
static char *result_label;
static char *rec_file;
static long rc_timeout;

static int
sock_read_line (int fd, char *buf, int max)
{
  int inx = 0;
  char *szPtr = buf;
  int size, rc;
  do
    {
      if (szStart == szEnd)
	{
	  szStart = buffer;
#if defined (linux)
	read_again:
#endif
	  if (-1 == (rc = recv (fd, szStart, sizeof (buffer), 0)))
	    {
	      if (errno == EAGAIN && rc_timeout > 0)
		return -2;
#if defined (linux)
	      /* http://www.ussg.iu.edu/hypermail/linux/kernel/0006.3/0193.html */
	      if (errno == EPIPE)
		goto read_again;
#endif
	      return rc;
	    }
	  if (rc == 0)
	    {
	      return -1;
	    }
	  szEnd = szStart + rc;
	}
      if (szStart < szEnd)
	{
	  szPtr = szStart;
	  while (szPtr - szStart < max - 1 - inx && szPtr < szEnd
	      && *szPtr != LF)
	    szPtr++;
	  size = MIN (max - 1 - inx, szPtr - szStart);
	  if (szPtr < szEnd)
	    {
	      memcpy (buf + inx, szStart, size);
	      buf[inx + size] = 0;
	      szStart = szPtr + 1;
	      return (size + inx);
	    }
	  else
	    {
	      memcpy (buf + inx, szStart, size);
	      inx += size;
	      szStart = szPtr;
	    }
	}
    }
  while (1);
}

static void
encode_base64 (char *input, char *output)
{
  int c, n = 0, i, count = 0, j = 0, x = 0;
  long val = 0;
  char enc[4];

  for (j = 0; j < strlen (input); j++)
    {
      c = input[j];
      if (n++ <= 2)
	{
	  val <<= 8;
	  val += c;
	  continue;
	}

      for (i = 0; i < 4; i++)
	{
	  enc[i] = val & 63;
	  val >>= 6;
	}

      for (i = 3; i >= 0; i--)
	output[x++] = vec[(unsigned int) enc[i]];
      n = 1;
      count += 4;
      val = c;
    }
  if (n == 1)
    {
      val <<= 16;
      for (i = 0; i < 4; i++)
	{
	  enc[i] = val & 63;
	  val >>= 6;
	}
      enc[0] = enc[1] = 64;
    }
  if (n == 2)
    {
      val <<= 8;
      for (i = 0; i < 4; i++)
	{
	  enc[i] = val & 63;
	  val >>= 6;
	}
      enc[0] = 64;
    }
  if (n == 3)
    for (i = 0; i < 4; i++)
      {
	enc[i] = val & 63;
	val >>= 6;
      }
  if (n)
    {
      for (i = 3; i >= 0; i--)
	output[x++] = vec[(unsigned int) enc[i]];
    }
}

static void
l_usage (char *fname)
{
  fprintf (stderr, "\nUrl simulator version 1.0\n");
  fprintf (stderr, "Use it for testing www-servers\n");
  fprintf (stderr, "See file urlsimu.doc for exact syntax of url-file\n\n");
  fprintf (stderr, "Usage: %s [-hsf] filename\n", fname);
  fprintf (stderr, "where\n");
  fprintf (stderr, " -f = forever\n");
  fprintf (stderr, " -h(-?) = this help\n");
  fprintf (stderr, " -s = silent mode\n");
  fprintf (stderr, " -S = BIG silence mode. Just the last execution times\n");
  fprintf (stderr, " -s n = number of requests to go into one connection\n");
  fprintf (stderr, " -P = when -c is specified make the requests in connection pipelined\n");
  fprintf (stderr, " -p = password \n");
  fprintf (stderr, " -u = user \n");
  fprintf (stderr, " -q n = max seconds to wait between connects \n");
  fprintf (stderr, " -t <filename> = store content to file (overwrite mode)\n");
  fprintf (stderr, " -l \"line\" = send http header line \n");
  fprintf (stderr, " -r \"label\" = Label for result total time\n");

}

static void
l_handle_file (FILE * fp)
{
  static int nth_url = 1;
  char line[MAX_URL_SIZE];
  char *post;
  int post_repeat = 1;
  int cursor = 0;
  char host[40], str_port[40];
  int port;
  const int POST = 0;
  const int GET = 1;
  const int ANY = 2;
  int STATE = -1;
  size_t size;

  fseek(fp, 0, SEEK_END);
  size = ftell(fp);
  fseek(fp, 0, SEEK_SET);

  if ((post = malloc (size + 1024)) == NULL)
    {
      fprintf (stderr, "File too big\n");
      exit(1);
    }

  if (fgets (line, sizeof (line), fp) != NULL)
    {
      sscanf (line, "%s %s", host, str_port);
      port = atoi (str_port);
    }
  else
    {
      fprintf (stderr, "File is empty\n");
      exit (1);
    }

  ta_init (&global_times, result_label ? result_label : "Total");
  while (!feof (fp))
    {
      if (fgets (line, sizeof (line), fp) != NULL)
	{
	  if (strstr (line, "ENDPOST"))
	    {
	      if (STATE == POST)
		{
		  /* Process allready saved up POST header */
		  l_handle_post (host, port, post, post_repeat);
		  post[0] = '\0';
		  cursor = 0;
		  STATE = ANY;
		}
	      continue;
	    }
	  if (strstr (line, "GET"))
	    {
	      post[0] = '\0';
	      cursor = 0;
	      STATE = GET;
	      {
		int repeat = 1;
		char *pos = line;
		char tmp[40];
		printf ("Process GET line.\n");
		/* Detect number of repetion (if possible) */
		pos = strchr (line, 'G');
		if (pos != line)
		  {
		    strncpy (tmp, line, pos - line);
		    repeat = atoi (tmp);
		    if (repeat == 0)
		      repeat = 1;
		  }
		fprintf (stdout, "%d %s\n", nth_url++, line + (pos - line));
		fflush (stdout);
		l_handle_url (host, port, line + (pos - line), repeat);
	      }
	      continue;
	    }
	  else if (strstr (line, "POST"))
	    {
	      /* Start reading POST header */
	      fprintf (stdout, "%d %s ...\n", nth_url++, line);
	      fflush (stdout);
	      STATE = POST;
	      post[0] = '\0';
	      cursor = 0;
	      post_repeat = 1;
	      {
		char *pos = line;
		char tmp[40];
		char tmp2[40];
		pos = strchr (line, 'P');
		if (pos != line)
		  {
		    strncpy (tmp, line, pos - line);
		    post_repeat = atoi (tmp);
		    if (post_repeat == 0)
		      post_repeat = 1;
		  }
		cursor += sprintf (post, "%s", line + (pos - line));
		if (port)
		  {
		    cursor +=
			sprintf (post + cursor, "Host: %s:%d\r\n", host,
			port);
		  }
		else
		  {
		    cursor += sprintf (post + cursor, "Host: %s\r\n", host);
		  }
		cursor +=
		    sprintf (post + cursor,
		    "User-Agent: urlsimu Version 0.1\r\n");
		if (rec_file)
		  cursor += sprintf (post + cursor, "X-Recording: %s\r\n", rec_file);

		if (user != NULL && passwd != NULL)
		  {
		    sprintf (tmp, "%s:%s", user, passwd);
		    encode_base64 (tmp, tmp2);
		    cursor +=
			sprintf (post + cursor, "Authorization: Basic %s\r\n",
			tmp2);
		  }
	      }
	      continue;
	    }
	  else
	    {
	      if (STATE == POST)
		{
		  /* Continue reading POST header */
		  cursor += sprintf (post + cursor, "%s", line);
		}
	      else
		{
		  /* All others commands */
		  post[0] = '\0';
		  cursor = 0;
		  {
		    int repeat;
		    char *tmp, *rline;
		    tmp = strtok (line, " ");
		    repeat = atoi (tmp);
		    rline = &line[strlen (tmp) + 1];
		    fprintf (stdout, "%d %s\n", nth_url++, rline);
		    fflush (stdout);
		    l_handle_url (host, port, rline, repeat);
		  }
		}
	      continue;
	    }
	}
    }
  free (post);
  ta_print_out (stdout, &global_times);
}

void
make_connection (char *host, int port, int *s)
{
  struct hostent *phe = NULL;
  struct sockaddr_in sin;
  int con_rc = 0, errn = 0;
  struct timeval timeout = {0,0};


  ta_enter (&url_times);
  /* initialize sockaddr_in structure */
  memset (&sin, 0, sizeof (sin));
  sin.sin_family = AF_INET;
  sin.sin_port = htons ((u_short) port);
  do
    {
      phe = gethostbyname (host);
    }
  while (phe == NULL && h_errno == TRY_AGAIN);
  if (phe != NULL)
    {
      memcpy (&sin.sin_addr, phe->h_addr, phe->h_length);
    }
  else
    {
      fprintf (stderr, "Cannot get hostname %s\n", host);
      exit (1);
    }


  do
    {
      /* create socket */
      if (*s)
	closesocket (*s);
      *s = socket (AF_INET, SOCK_STREAM, 0);
      if (*s < 0)
	{
	  fprintf (stderr, "Cannot create socket\n");
	  exit (1);

	}

      /* connect */
      con_rc = connect (*s, (struct sockaddr *) &sin, sizeof (sin));
      errn = errno;
      if (con_rc < 0 && errn == EAGAIN)
	{
	  closesocket (*s);
	  *s = 0;
#ifdef WIN32
	  Sleep (500);
#endif
	}
      else
	break;
    }
  while (con_rc < 0 && errn == EAGAIN);
  if (con_rc < 0)
    {
      fprintf (stderr, "Cannot connect, errno = %d\n", errn);
      perror ("");
      exit (1);
    }
  if (rc_timeout > 0)
    {
      timeout.tv_sec = rc_timeout;
#ifdef SO_RCVTIMEO
      con_rc = setsockopt (*s, SOL_SOCKET, SO_RCVTIMEO, (char *) &timeout, sizeof (timeout));
      if (con_rc < 0)
	perror ("error");
#endif
#ifdef SO_SNDTIMEO
      con_rc = setsockopt (*s, SOL_SOCKET, SO_SNDTIMEO, (char *) &timeout, sizeof (timeout));
      if (con_rc < 0)
	perror ("error");
#endif
    }
}

static int
file_len (FILE * fi)
{
  long startpos, endpos;
  fpos_t currpos;
  startpos = endpos = 0;
  fgetpos (fi, &currpos);
  fseek (fi, 0L, SEEK_SET);
  startpos = ftell (fi);
  fseek (fi, 0L, SEEK_END);
  endpos = ftell (fi);
  fsetpos (fi, &currpos);
  return endpos - startpos;
}

static int
send_request (int fd, char *tmp, int i1, int requests_to_send, int tmp_len)
{
  char file_to_put[128];
  char method[20];
  char *fdelim = NULL, *sdelim = NULL, *content = NULL;
  FILE *fput = NULL;
  int flen;
  char header_len[128];

  file_to_put[0] = 0;
  method[0] = 0;
  flen = 0;
  strncpy (method, tmp, strchr (tmp, '\x20') - tmp);
  method[(int) (strchr (tmp, '\x20') - tmp)] = 0;
  if (strstr (method, "PUT"))
    {
      fdelim = strchr (tmp, '\x20');
      sdelim = strstr (tmp, "HTTP/");
      if (fdelim && sdelim && sdelim > fdelim)
	{
	  strncpy (file_to_put, fdelim, (int) (sdelim - fdelim));
	  file_to_put[(int) (sdelim - fdelim)] = 0;
	}
      fdelim = strrchr (file_to_put, '/');
      if (fdelim)
	{
	  sprintf (file_to_put, "%s", fdelim + 1);
	  if (strchr (file_to_put, '\x20') > file_to_put)
	    file_to_put[(int) (strchr (file_to_put, '\x20') - file_to_put)] =
		0;
	}
      else
	file_to_put[0] = 0;
    }
  if (0 != file_to_put[0] && strstr (method, "PUT"))
    {
      fput = fopen (file_to_put, "rb");
      if (!fput)
	fprintf (stderr, "Cannot open: %s", file_to_put);
      if (fput)
	{
	  flen = file_len (fput);
	  if (flen > 0)
	    {
	      content = NULL;
	      /* content = dk_alloc_box (flen + 1, DV_LONG_STRING);
	         content [flen] = 0;
	         fread (content, flen, 1, fput); */
	      sprintf (header_len, "\r\nContent-Length: %d", flen);
	    }
	  /*fclose (fput); */
	}
    }
  if (silent_mode == FALSE && big_silent_mode == FALSE)
    {
      printf ("\n------- REQUEST\n%s", tmp);
      if (flen > 0)
	printf ("\r\nContent-Length: %d", flen);
    }
  if (-1 == send (fd, tmp, tmp_len, 0))
    goto do_it_again;
  if (flen > 0)
    if (-1 == send (fd, header_len, strlen (header_len), 0))
      goto do_it_again;
  if (send_header_line == TRUE && header_line != NULL)
    {
      if (silent_mode == FALSE && big_silent_mode == FALSE)
	printf ("\r\n%s", header_line);
      if (-1 == send (fd, "\r\n", 2, 0))
	goto do_it_again;
      if (-1 == send (fd, header_line, strlen (header_line), 0))
	goto do_it_again;
    }
  if (closevalue)
    {
      if (i1 < requests_to_send - 1)
	{
	  if (silent_mode == FALSE && big_silent_mode == FALSE)
	    printf ("\nConnection: Keep-Alive\n\n------- END REQUEST\n");
	  if (-1 == send (fd, "\r\nConnection: Keep-Alive\r\n\r\n", 28, 0))
	    goto do_it_again;
	}
      else
	{
	  if (silent_mode == FALSE && big_silent_mode == FALSE)
	    printf ("\nConnection: Close\n\n------- END REQUEST\n");
	  if (-1 == send (fd, "\r\nConnection: Close\r\n\r\n", 23, 0))
	    goto do_it_again;
	}
    }
  else
    {
      if (silent_mode == FALSE && big_silent_mode == FALSE)
	printf ("\n\n------- END REQUEST\n");
      if (-1 == send (fd, "\r\n\r\n", 4, 0))
	goto do_it_again;
    }
  if (flen > 0 && fput)
    {
      char buf[2048];
      int in_size = 0, total_bytes = 0;
      for (;;)
	{
	  in_size = fread (buf, 1, sizeof (buf), fput);
	  total_bytes += in_size;
	  /*fprintf (stderr, "bytes left: %d %d\n", total_bytes, flen); */
	  if (in_size < 1)
	    break;
	  if (-1 == send (fd, buf, in_size, 0))
	    goto do_it_again;
	}
      fclose (fput);
      fput = NULL;
    }
  if (content)
    {
      dk_free_box (content);
      content = NULL;
    }
  return 0;
do_it_again:
  if (fput)
    fclose (fput);
  fput = NULL;
  if (content)
    {
      dk_free_box (content);
      content = NULL;
    }
  return -1;
}

static int
send_post_request (int fd, char *tmp, int i1, int requests_to_send,
    int tmp_len)
{

  if (silent_mode == FALSE && big_silent_mode == FALSE)
    {
      printf ("\n------- REQUEST\n%s", tmp);
    }
  if (send (fd, tmp, tmp_len, 0) == -1)
    goto do_it_again;


  if (closevalue)
    {
      if (i1 < requests_to_send - 1)
	{
	  if (silent_mode == FALSE && big_silent_mode == FALSE)
	    printf ("\nConnection: Keep-Alive\n\n------- END REQUEST\n");
	  if (-1 == send (fd, "\r\nConnection: Keep-Alive\r\n\r\n", 28, 0))
	    goto do_it_again;
	}
      else
	{
	  if (silent_mode == FALSE && big_silent_mode == FALSE)
	    printf ("\nConnection: Close\n\n------- END REQUEST\n");
	  if (-1 == send (fd, "\r\nConnection: Close\r\n\r\n", 23, 0))
	    goto do_it_again;
	}
    }
  else
    {
      if (silent_mode == FALSE && big_silent_mode == FALSE)
	printf ("\n\n------- END REQUEST\n");
      if (-1 == send (fd, "\r\n\r\n", 4, 0))
	goto do_it_again;
    }
  return 0;
do_it_again:
  return -1;
}


static void
l_handle_url (char *host, int port, char *line, int repeat)
{
  char tmp[MAX_URL_SIZE], *sztmp;
  char wrk_buf1[512], wrk_buf2[512];
  dk_set_t head = NULL;
  int fd = 0;
  int rc, i;
  long buflen = 0;
  int nHttpVer = 0, pipeline_loop, tmp_len;
  int i1, requests_to_send, to_reconnect = 0;
  long content_length = 0;
  FILE *f_to_file = NULL;
  char s_port[10];

  ta_init (&url_times, "Url Times");
  ta_enter (&global_times);
  *tmp = 0;
  *wrk_buf2 = 0;
  strcat (tmp, line);
  if (user != NULL && passwd != NULL)
    {
      sprintf (wrk_buf1, "%s:%s", user, passwd);
      encode_base64 (wrk_buf1, wrk_buf2);
      strcat (tmp, "Authorization: Basic ");
      strcat (tmp, wrk_buf2);
      strcat (tmp, "\n");
    }
  rc = strlen (tmp) - 1;
  while (rc > 0 && (tmp[rc] == '\x0A' || tmp[rc] == '\x0D'))
    tmp[rc--] = 0;

  sztmp = strstr (tmp, "HTTP/1.");
  if (sztmp)
    {
      nHttpVer = sztmp[7] - '0';
      if (closevalue)
	sztmp[7] = '1';
    }
  else
    strcat (tmp, "HTTP/1.1");

  if (!closevalue && nHttpVer)
    strcat (tmp, "\r\nConnection: Close");
  strcat (tmp, "\r\nUser-Agent: urlsimu Version 0.1");
  strcat (tmp, "\r\nHost: ");
  strcat (tmp, host);
  if (port)
    {
      sprintf (s_port, ":%d", port);
      strcat (tmp, s_port);
    }
  if (rec_file)
    {
      strcat (tmp, "\r\nX-Recording: ");
      strcat (tmp, rec_file);
    }
  tmp_len = strlen (tmp);

  requests_to_send = closevalue ? closevalue : 1;

  for (i = 0; i < repeat; i += requests_to_send)
    {
      to_reconnect = 0;
      if (i + requests_to_send > repeat)
	requests_to_send = repeat - i;


      if (!to_reconnect)
	make_connection (host, port, &fd);

      pipeline_loop = pipeline ? 1 : 0;
      do
	{
	  for (i1 = 0; i1 < requests_to_send; i1++)
	    {
	      content_length = 0;
	    do_it_again:
	      if (to_reconnect)
		{
		  if (pipeline)
		    i1--;
		  pipeline_loop = pipeline ? 1 : 0;
		  to_reconnect = 0;
		  closesocket (fd);
		  fd = 0;
		  ta_leave (&url_times);
		  make_connection (host, port, &fd);
		}

	      if (pipeline_loop == 1 || !pipeline)
		{
		  /* send the request */
		  if (-1 == send_request (fd, tmp, i1, requests_to_send,
			  tmp_len))
		    {
		      to_reconnect = 1;
		      goto do_it_again;
		    }
		  if (port == 25)
		    exit (0);
		}
	      if (!pipeline_loop)
		{
		  to_reconnect = 0;
		  /* listen to response */
		  for (;;)
		    {
		      rc = sock_read_line (fd, wrk_buf1, sizeof (wrk_buf1));
		      if (rc == -1)
			{
			  to_reconnect = 1;
			  goto do_it_again;
			}
		      if (rc <= 2)
			break;
		      if (!strnicmp ("Content-Length:", wrk_buf1, 15))
			content_length = atol (wrk_buf1 + 15);
		      if (!strnicmp ("Connection: Close", wrk_buf1, 17))
			to_reconnect = 1;
		      if (silent_mode == FALSE && big_silent_mode == FALSE)
			dk_set_push (&head, box_dv_short_string (wrk_buf1));
		    }

		  head = dk_set_nreverse (head);
		  /* show response */
		  if (store_to_file == TRUE && f_to_file == NULL)
		    f_to_file = fopen (to_file, "wb");
		  buflen = 0;
		  DO_SET (char *, line, &head)
		  {
		    if (silent_mode == FALSE && big_silent_mode == FALSE)
		      {
			printf ("%s\n", line);
			buflen += strlen (line);
		      }
		    dk_free_box (line);
		  }
		  END_DO_SET ();
		  dk_set_free (head);
		  head = NULL;
		  if (content_length > 0)
		    {
		      if (silent_mode == FALSE && big_silent_mode == FALSE)
			printf ("\n---BODY (%ld) bytes \n\n", content_length);
		      if (szEnd > szStart)
			{	/* there is a remains in the buffer */
			  int len =
			      MIN (MIN (sizeof (wrk_buf1) - 1,
				  content_length), szEnd - szStart);
			  memcpy (wrk_buf1, szStart, len);
			  content_length -= len;
			  szStart += len;
			  if (silent_mode == FALSE
			      && big_silent_mode == FALSE)
			    {
			      wrk_buf1[len] = 0;
			      if (store_to_file == FALSE)
				printf ("%s", wrk_buf1);
			      else
				fwrite (wrk_buf1, len, 1, f_to_file);
			    }
			}
		      while (content_length > 0)
			{
			  if (-1 != (rc =
				  recv (fd, wrk_buf1,
				      MIN (sizeof (wrk_buf1) - 1,
					  content_length), 0)))
			    {
			      if (silent_mode == FALSE
				  && big_silent_mode == FALSE)
				{
				  wrk_buf1[rc] = 0;
				  if (store_to_file == FALSE)
				    printf ("%s", wrk_buf1);
				  else
				    fwrite (wrk_buf1, rc, 1, f_to_file);
				}
			      content_length -= rc;
			    }
			  else
			    {
			      to_reconnect = 1;
			      goto do_it_again;
			    }
			}
		      if (silent_mode == FALSE && big_silent_mode == FALSE)
			printf ("\n---END BODY\n\n");
		    }
		}
	    }
	  pipeline_loop--;
	}
      while (pipeline_loop >= 0);

      if (f_to_file)
	{
	  fclose (f_to_file);
	  f_to_file = NULL;
	}
      closesocket (fd);
      fd = 0;
      ta_leave (&url_times);
      if (silent_mode == FALSE && big_silent_mode == FALSE)
	printf ("\nbuflen = %ld\n", buflen);
      if (big_silent_mode == FALSE)
	ta_print_out (stdout, &url_times);
      if (no_sleep_mode)
	sleep (rnd () % no_sleep_mode);
    }
  printf ("\n");
  ta_leave (&global_times);
  ta_print_out (stdout, &url_times);
}

static void
l_handle_post (char *host, int port, char *post, int repeat)
{
  char *sztmp;
  char wrk_buf1[512];
  dk_set_t head = NULL;
  int fd = 0;
  int rc, i;
  long buflen = 0;
  int nHttpVer = 0, pipeline_loop;
  int i1, requests_to_send, to_reconnect = 0;
  long content_length = 0;
  FILE *f_to_file = NULL;

  ta_init (&url_times, "Url Times");
  ta_enter (&global_times);

  /* Find out HTTP version (HTTP version mark is mantadory in input file) */
  sztmp = strstr (post, "HTTP/1.");
  if (sztmp)
    {
      nHttpVer = sztmp[7] - '0';
    }
  requests_to_send = closevalue ? closevalue : 1;


  for (i = 0; i < repeat; i += requests_to_send)
    {
      to_reconnect = 0;
      if (i + requests_to_send > repeat)
	{
	  requests_to_send = repeat - i;
	}
      if (!to_reconnect)
	{
	  make_connection (host, port, &fd);
	}
      pipeline_loop = pipeline ? 1 : 0;
      do
	{
	  for (i1 = 0; i1 < requests_to_send; i1++)
	    {
	      content_length = 0;
	    do_it_again:
	      if (to_reconnect)
		{
		  if (pipeline)
		    i1--;
		  pipeline_loop = pipeline ? 1 : 0;
		  to_reconnect = 0;
		  closesocket (fd);
		  fd = 0;
		  ta_leave (&url_times);
		  make_connection (host, port, &fd);
		}
	      if (pipeline_loop == 1 || !pipeline)
		{
		  /* send the post request */
		  if (send_post_request (fd, post, i1, requests_to_send,
			  strlen (post)) == -1)
		    {
		      to_reconnect = 1;
		      goto do_it_again;
		    }
		  if (port == 25)
		    exit (0);
		}
	      if (!pipeline_loop)
		{
		  to_reconnect = 0;
		  /* listen to response */
		  for (;;)
		    {
		      rc = sock_read_line (fd, wrk_buf1, sizeof (wrk_buf1));
		      if (rc == -1)
			{
			  to_reconnect = 1;
			  goto do_it_again;
			}
		      if (rc <= 2)
			break;
		      if (!strnicmp ("Content-Length:", wrk_buf1, 15))
			content_length = atol (wrk_buf1 + 15);
		      if (!strnicmp ("Connection: Close", wrk_buf1, 17))
			to_reconnect = 1;
		      if (silent_mode == FALSE && big_silent_mode == FALSE)
			dk_set_push (&head, box_dv_short_string (wrk_buf1));
		    }

		  head = dk_set_nreverse (head);
		  /* show response */
		  if (store_to_file == TRUE && f_to_file == NULL)
		    f_to_file = fopen (to_file, "wb");
		  buflen = 0;
		  DO_SET (char *, line, &head)
		  {
		    if (silent_mode == FALSE && big_silent_mode == FALSE)
		      {
			printf ("%s\n", line);
			buflen += strlen (line);
		      }
		    dk_free_box (line);
		  }
		  END_DO_SET ();
		  dk_set_free (head);
		  head = NULL;
		  if (content_length > 0)
		    {
		      if (silent_mode == FALSE && big_silent_mode == FALSE)
			printf ("\n---BODY (%ld) bytes \n\n", content_length);
		      if (szEnd > szStart)
			{	/* there is a remains in the buffer */
			  int len =
			      MIN (MIN (sizeof (wrk_buf1) - 1,
				  content_length), szEnd - szStart);
			  memcpy (wrk_buf1, szStart, len);
			  content_length -= len;
			  szStart += len;
			  if (silent_mode == FALSE
			      && big_silent_mode == FALSE)
			    {
			      wrk_buf1[len] = 0;
			      if (store_to_file == FALSE)
				printf ("%s", wrk_buf1);
			      else
				fwrite (wrk_buf1, len, 1, f_to_file);
			    }
			}
		      while (content_length > 0)
			{
			  if (-1 != (rc =
				  recv (fd, wrk_buf1,
				      MIN (sizeof (wrk_buf1) - 1,
					  content_length), 0)))
			    {
			      if (silent_mode == FALSE
				  && big_silent_mode == FALSE)
				{
				  wrk_buf1[rc] = 0;
				  if (store_to_file == FALSE)
				    printf ("%s", wrk_buf1);
				  else
				    fwrite (wrk_buf1, rc, 1, f_to_file);
				}
			      content_length -= rc;
			    }
			  else
			    {
			      to_reconnect = 1;
			      goto do_it_again;
			    }
			}
		      if (silent_mode == FALSE && big_silent_mode == FALSE)
			printf ("\n---END BODY\n\n");
		    }
		}
	    }
	  pipeline_loop--;
	}
      while (pipeline_loop >= 0);

      if (f_to_file)
	{
	  fclose (f_to_file);
	  f_to_file = NULL;
	}
      closesocket (fd);
      fd = 0;
      ta_leave (&url_times);
      if (silent_mode == FALSE && big_silent_mode == FALSE)
	printf ("\nbuflen = %ld\n", buflen);
      if (big_silent_mode == FALSE)
	ta_print_out (stdout, &url_times);
      if (no_sleep_mode)
	sleep (rnd () % no_sleep_mode);
    }
  printf ("\n");
  ta_leave (&global_times);
  ta_print_out (stdout, &url_times);
}

int
main (int argc, char *argv[])
{
  FILE *fp;
  char *prog_name = argv[0];
  char *fname;
  int c;
  extern int optind;
  extern char *optarg;
  int forever = FALSE;
#ifdef WIN32
  WSADATA wsaData;
  WORD wVersionRequired = (1 << 8) + 1;
#endif

  silent_mode = FALSE;
  big_silent_mode = FALSE;
  store_to_file = FALSE;
  send_header_line = FALSE;
#ifndef WIN32
  signal (SIGPIPE, SIG_IGN);
#else
  if (WSAStartup (wVersionRequired, &wsaData))
    {
      printf ("*** FAILED: Windows sockets unable to initialize\n");
      exit (1);
    }
#endif
  while ((c = getopt (argc, argv, "u:p:fhc:sSq:Pt:l:r:x:T:")) != EOF)
    {
      switch (c)
	{
	case 'c':
	  closevalue = atoi (optarg);
	  break;

	case 'P':
	  pipeline = TRUE;
	  if (!closevalue)
	    closevalue = 1;
	  break;

	case 'p':
	  passwd = optarg;
	  break;

	case 'q':
	  no_sleep_mode = atoi (optarg);
	  break;

	case 'f':
	  forever = TRUE;
	  break;

	case 'h':
	  l_usage (prog_name);
	  exit (0);

	case 's':
	  silent_mode = TRUE;
	  break;

	case 'u':
	  user = optarg;
	  break;

	case 'S':
	  big_silent_mode = TRUE;
	  break;

	case 't':
	  store_to_file = TRUE;
	  to_file = optarg;
	  break;

	case 'T':
	  rc_timeout = atol (optarg);
	  break;

	case 'r':
	  result_label = optarg;
	  break;

	case 'l':
	  send_header_line = TRUE;
	  header_line = optarg;
	  break;

	case 'x':
	  rec_file = optarg;
	  break;

	case '?':
	  l_usage (prog_name);
	  exit (0);
	  break;
	}
    }

  if (argc == 1)
    {
      l_usage (prog_name);
      fprintf (stderr, "Reading from stdin\n");
      fp = stdin;
      l_handle_file (fp);
    }
  else
    {
      int oldoptind = optind;
      while (1)
	{
	  optind = oldoptind;
	  for (; optind < argc; optind++)
	    {
	      fname = argv[optind];

	      if ((fp = fopen (fname, "r")) == NULL)
		{
		  fprintf (stderr, "Cannot open file:%s\n", fname);
		  exit (1);
		}

	      l_handle_file (fp);
	      fclose (fp);
	    }			/* for */

	  if (forever == FALSE)
	    break;
	}			/* while */
    }				/* else */

  return (0);
}
