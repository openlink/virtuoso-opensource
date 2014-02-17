/*
 *  io_unix.c
 *
 *  $Id$
 *
 *  Unix specific I/O for fibers
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

#include "thread_int.h"

#ifdef EXPIRIMENTAL

#ifdef UNIX
#include <sys/socket.h>
#include <netinet/in.h>
#endif


/******************************************************************************
 *
 *  File I/O
 *
 ******************************************************************************/

void
io_init (void)
{
#ifndef WIN32
  signal (SIGPIPE, SIG_IGN);

#else
# undef EINTR
# undef EINVAL
# define EINTR		WSAEINTR
# define EINVAL		WSAEINVAL
# define EWOULDBLOCK	WSAEWOULDBLOCK
# define EISCONN	WSAEISCONN
# define EINPROGRESS	WSAEINPROGRESS
# define errno		WSAGetLastError ()
  WSADATA info;

  if (WSAStartup (0x101, &info) != 0)
    GPF_T1 ("WSAStartup() failed");
#endif
}


int
thread_nb_fd (int fd)
{
#ifdef WIN32
  DWORD dontblock = 1;
  return ioctlsocket (fd, FIONBIO, &dontblock);

#elif defined (FIONBIO)
  int dontblock = 1;
  return ioctl (fd, FIONBIO, &dontblock);

#elif defined (O_NONBLOCK)
  return fcntl (fd, F_SETFL, O_NONBLOCK);

#else
  return fcntl (fd, F_SETFL, FNDELAY);
#endif
}


int
thread_open (char *fname, int mode, int perms)
{
  int rc;

  if ((rc = open (fname, mode, perms)) == -1)
    thr_errno = errno;
  else
    {
      if (!_thread_sched_preempt)
	thread_nb_fd (rc);
      thr_errno = 0;
    }

  return rc;
}


int
thread_close (int fd)
{
  int rc;

  rc = close (fd);
  thr_errno = rc == -1 ? errno : 0;

  return rc;
}


ssize_t
thread_read (int fd, void *buffer, size_t length)
{
  ssize_t rc;
  fd_set rfds;

  for (;;)
    {
      if ((rc = read (fd, buffer, length)) == -1)
	{
	  switch (errno)
	    {
	    case EWOULDBLOCK:
	      FD_ZERO (&rfds);
	      FD_SET (fd, &rfds);
	      rc = thread_select (fd + 1, &rfds, NULL, NULL, TV_INFINITE);
	      if (rc == -1)
		break;
	      continue;
	    case EINTR:
	      continue;
	    default:
perror ("------------ READ"); /* XXX */
	      break;
	    }
	  thr_errno = errno;
	}
      else
	thr_errno = 0;
      break;
    }

  return rc;
}


ssize_t
thread_write (int fd, void *buffer, size_t length)
{
  ssize_t rc;
  fd_set wfds;

  for (;;)
    {
      if ((rc = write (fd, buffer, length)) == -1)
	{
	  switch (errno)
	    {
	    case EWOULDBLOCK:
	      FD_ZERO (&wfds);
	      FD_SET (fd, &wfds);
	      rc = thread_select (fd + 1, NULL, &wfds, NULL, TV_INFINITE);
	      if (rc == -1)
		break;
	      continue;
	    case EINTR:
	      continue;
	    default:
perror ("------------ WRITE"); /* XXX */
	      break;
	    }
	  thr_errno = errno;
	}
      else
	thr_errno = 0;
      break;
    }

  return rc;
}

/******************************************************************************
 *
 *  Socket I/O
 *
 ******************************************************************************/

int
thread_socket (int family, int type, int proto)
{
  int rc;

  if ((rc = socket (family, type, proto)) == -1)
    thr_errno = errno;
  else
    {
      thread_nb_fd (rc);
      thr_errno = 0;
    }

  return rc;
}


int
thread_closesocket (int sock)
{
  int rc;

  rc = close (sock);
  thr_errno = rc == -1 ? errno : 0;

  return rc;
}


int
thread_bind (int sock, struct sockaddr *addr, int len)
{
  int rc;

  rc = bind (sock, addr, len);
  thr_errno = rc == -1 ? errno : 0;

  return rc;
}


int
thread_listen (int sock, int n)
{
  int rc;

  rc = listen (sock, n);
  thr_errno = rc == -1 ? errno : 0;

  return rc;
}


int
thread_connect (int sock, struct sockaddr *addr, int len)
{
  fd_set rfds;
  int did_sel = 0;
  int rc;

  for (;;)
    {
      if ((rc = connect (sock, addr, len)) == -1)
	{
	  switch (errno)
	    {
	    case EISCONN:
	    case EINVAL:
	      if (!did_sel)
		break;
	      thr_errno = 0;
	      return 0;
	    case EINPROGRESS:
	      thr_errno = 0;
	      return 0;
	    case EWOULDBLOCK:
	      FD_ZERO (&rfds);
	      FD_SET (sock, &rfds);
	      rc = thread_select (sock + 1, &rfds, NULL, NULL, TV_INFINITE);
	      if (rc == -1)
		break;
	      did_sel = 1;
	      continue;
	    case EINTR:
	      continue;
	    default:
perror ("------------ CONNECT"); /* XXX */
	      break;
	    }
	  thr_errno = errno;
	}
      else
	thr_errno = 0;
      break;
    }

  return rc;
}


int
thread_accept (int sock, struct sockaddr *addr, int *plen, TVAL timeout)
{
  fd_set rfds;
  int rc;

  for (;;)
    {
      if ((rc = accept (sock, addr, plen)) == -1)
	{
	  switch (errno)
	    {
	    case EWOULDBLOCK:
	      FD_ZERO (&rfds);
	      FD_SET (sock, &rfds);
	      rc = thread_select (sock + 1, &rfds, NULL, NULL, TV_INFINITE);
	      if (rc == -1)
		break;
	      continue;
	    case EINTR:
	      continue;
	    default:
perror ("------------ ACCEPT"); /* XXX */
	      break;
	    }
	  thr_errno = errno;
	}
      else
	{
	  thread_nb_fd (rc);
	  thr_errno = 0;
	}
      break;
    }

  return rc;
}


ssize_t
thread_send (int sock, void *buffer, size_t length, TVAL timeout)
{
  fd_set wfds;
  ssize_t rc;

  for (;;)
    {
      /* dk_debug_dump_data (stderr, "SEND", buffer, length); */
      if ((rc = send (sock, buffer, length, 0)) == -1)
	{
	  switch (errno)
	    {
	    case EWOULDBLOCK:
	      FD_ZERO (&wfds);
	      FD_SET (sock, &wfds);
	      rc = thread_select (sock + 1, NULL, &wfds, NULL, timeout);
	      if (rc == -1 || rc == 0)
		break;
	      continue;
	    case EINTR:
	      continue;
	    default:
perror ("------------ SEND"); /* XXX */
	      break;
	    }
	  thr_errno = errno;
	}
      else
	thr_errno = 0;
      break;
    }

  return rc;
}


ssize_t
thread_recv (int sock, void *buffer, size_t length, TVAL timeout)
{
  fd_set rfds;
  ssize_t rc;

  for (;;)
    {
      if ((rc = recv (sock, buffer, length, 0)) == -1)
	{
	  switch (errno)
	    {
	    case EWOULDBLOCK:
	      FD_ZERO (&rfds);
	      FD_SET (sock, &rfds);
	      rc = thread_select (sock + 1, &rfds, NULL, NULL, timeout);
	      if (rc == -1 || rc == 0)
		break;
	      continue;
	    case EINTR:
	      continue;
	    default:
perror ("------------ RECV"); /* XXX */
	      break;
	    }
	  thr_errno = errno;
	}
      else
	{
	  /* dk_debug_dump_data (stderr, "RECV", buffer, rc); */
	  thr_errno = 0;
	}
      break;
    }

  return rc;
}

#endif /* EXPIRIMENTAL */
