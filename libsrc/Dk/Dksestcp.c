/*
 *  Dksestcp.c
 *
 *  $Id$
 *
 *  TCP/IP sessions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#undef DBG_PRINTF

#include "Dk.h"
#include "Dksestcp.h"
#include "Dksestcpint.h"

int last_errno;
static int tcpdev_free (device_t * dev);
static int ses_control_all (session_t * ses);
static int tcpses_set_address (session_t * ses, char *addrinfo);
static int tcpses_listen (session_t * ses);
static int tcpses_accept (session_t * ses, session_t * new_ses);
static int tcpses_connect (session_t * ses);
static int tcpses_disconnect (session_t * ses);
static int tcpses_write (session_t * ses, char *buffer, int n_bytes);
static int tcpses_read (session_t * ses, char *buffer, int n_bytes);
static int tcpses_set_control (session_t * ses, int fld, char *p_value, int sz);
static int fill_fdset (int count, session_t ** sestable, fd_set * p_fdset);
static int test_eintr (session_t * ses, int retcode, int eno);
static int test_readblock (session_t * ses, int retcode, int eno);
static int test_writeblock (session_t * ses, int retcode, int eno);
static int test_timeout (session_t * ses, int retcode, int eno);
static int test_broken (session_t * ses, int retcode, int eno);
static void set_array_status (int count, session_t ** sesarr, int status);

static int fileses_write (session_t * ses, char *buffer, int n_bytes);
static int fileses_read (session_t * ses, char *buffer, int n_bytes);
int tcpses_select (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout);



#define TCP_CHECKVALUE     313			 /* Donald Duck registration number */

#define TCP_CHK(sesp)       \
	if ((sesp == NULL) || \
	    (sesp->ses_device->dev_check != TCP_CHECKVALUE)) \
	  { \
		dbg_printf_2 (("TCP_CHK : SER_ILLSESP")); \
		return (SER_ILLSESP); \
	  }


#define LISTEN_QLEN 50

#ifndef MAX
#define MAX(a, b)   ((a) > (b) ? (a) : (b))
#endif

#ifdef TCP_DEBUG
#define PRINT_DEBUG
#define LEVEL_VAR tcp_debug_level
#endif


/*##**********************************************************************
 *
 *              tcpdev_allocate
 *
 * Function used for allocating and initializing a new tcp device instance.
 * Use tcpdev_free for deallocating.
 *
 * Input params :        - none
 *
 * Output params:    - none
 *
 * Return value :    pointer to new session instance
 *
 * Limitations  :
 *
 * Globals used :    default controls
 */
device_t *
tcpdev_allocate ()
{
  device_t *dev = (device_t *) malloc (sizeof (device_t));
  devfuns_t *devfuns = (devfuns_t *) malloc (sizeof (devfuns_t));
  address_t *addr = (address_t *) malloc (sizeof (address_t));
  address_t *accepted_addr = (address_t *) malloc (sizeof (address_t));
  connection_t *con = (connection_t *) malloc (sizeof (connection_t));
  memset (con, 0, sizeof (*con));
  memset (accepted_addr, 0, sizeof (address_t));
  dbg_printf_1 (("tcpdev_allocate."));

  ss_assert (dev != NULL);
  ss_assert (devfuns != NULL);
  ss_assert (addr != NULL);
  ss_assert (con != NULL);

  /* Initialize pointers */
  dev->dev_address = addr;
  dev->dev_connection = con;
  dev->dev_funs = devfuns;
  dev->dev_accepted_address = accepted_addr;

  dev->dev_check = TCP_CHECKVALUE;

  /* Set tcpip methods */
  dev->dev_funs->dfp_allocate = tcpdev_allocate;
  dev->dev_funs->dfp_free = tcpdev_free;

  dev->dev_funs->dfp_set_address = tcpses_set_address;
  dev->dev_funs->dfp_listen = tcpses_listen;
  dev->dev_funs->dfp_accept = tcpses_accept;
  dev->dev_funs->dfp_connect = tcpses_connect;
  dev->dev_funs->dfp_disconnect = tcpses_disconnect;
  dev->dev_funs->dfp_read = tcpses_read;
  dev->dev_funs->dfp_write = tcpses_write;
  dev->dev_funs->dfp_set_control = tcpses_set_control;
  dev->dev_funs->dfp_get_control = NULL;

  return (dev);
}


/*##**********************************************************************
 *
 *              tcpdev_free
 *
 * Function for deallocating device instance after use.
 *
 * Input params :
 *
 *      ses     - device pointer returned by tcpdev_allocate
 *
 * Output params: - none
 *
 * Return value : SER_SUCC
 *                SER_ILLSESP
 *
 * Limitations  : Does not disconnect the session, use tcpses_disconnect
 *                before calling tcpdev_free
 *
 * Globals used : - none
 */
static int
tcpdev_free (device_t * dev)
{
  dbg_printf_1 (("tcpdev_free."));

  if ((dev == NULL) || (dev->dev_check != TCP_CHECKVALUE))
    {
      dbg_printf_2 (("SER_ILLSESP"));
      return (SER_ILLSESP);
    }

  free ((char *) dev->dev_address);
  free ((char *) dev->dev_connection);
  free ((char *) dev->dev_funs);
  free ((char *) dev->dev_accepted_address);

  /* Set the check-field anything but TCP_CHECKVALUE */
  dev->dev_check = TCP_CHECKVALUE - 9;

  free ((char *) dev);
  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              tcpses_set_addOBress
 *
 * Sets the address field of session according to the addrinfo
 *
 * Input params :
 *
 *      ses           -  session pointer
 *      addrinfo  -  format: <machine name><1313>
 *                              inetaddr    port
 *
 * Output params: the address of ses is changed
 *
 * Return value :
 *
 *      SER_SUCC     operation succeeded
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_ILLPRM   addrinfo could not be parsed as expected
 *
 * Limitations  : Only addrinfo containing dotted decimal address will do
 *
 *                In case there is a machine name given,
 *                it should be assigned somewhere in the addr structure.
 *                Now this is omitted.
 *
 * Globals used : - none
 */
char *
dk_parse_address (char *str)
{
  char *ret = str;
  while (*str)
    {
      if (*str == ':')
	*str = ' ';
      str++;
    };
  return ret;
}


static char addrinfo[256];

#define SEPARATOR " :"

int
alldigits (char *string)
{
  while (*string)
    {
      if (!isdigit (*string))
	return (0);
      else
	string++;
    }
  return 1;
}


#if defined (HPUX_10) && !defined (_XOPEN_SOURCE_EXTENDED)
extern int h_errno;
#endif

#if defined (WIN32)
#define in_addr_t	unsigned long
#endif

#ifndef INADDR_NONE
#define INADDR_NONE ((in_addr_t)(-1))
#endif

static int
tcpses_set_address (session_t * ses, char *addrinfo1)
{
  char *strs = NULL;
  saddrin_t *p_addr;		/* address information */
  char *p_name;
  unsigned short *p_port;	/* listening port number */
  int HostAndPort = 0;
  struct hostent *host = NULL;
  in_addr_t addr = INADDR_NONE;
#if defined (_REENTRANT)
  char buff[4096];
  int herrnop = 0;
  struct hostent ht;
# if defined (HPUX_10)
  struct hostent_data hted;
# endif
#endif
  init_tcpip ();
  strncpy (addrinfo, addrinfo1, sizeof (addrinfo));
  addrinfo[sizeof (addrinfo) - 1] = 0;


  TCP_CHK (ses);

  p_addr = &(ses->ses_device->dev_address->a_serveraddr.t);
  p_name = ses->ses_device->dev_address->a_hostname;
  p_port = (unsigned short *) &(ses->ses_device->dev_address->a_port);

  SESSTAT_CLR (ses, SST_OK);

  {
    char *stringplace;
    char localstring[256];
    strncpy (localstring, addrinfo, sizeof (localstring));
    localstring[sizeof (localstring) - 1] = 0;
    stringplace = strtok_r (localstring, SEPARATOR, &strs);
    if (stringplace != NULL)
      {
	if (alldigits (stringplace))
	  *p_port = atoi (stringplace);
	else
	  {
	    strncpy (p_name, stringplace, sizeof (ses->ses_device->dev_address->a_hostname));
	    p_name[sizeof (ses->ses_device->dev_address->a_hostname) - 1] = 0;
	    stringplace = strtok_r (NULL, SEPARATOR, &strs);
	    if (stringplace != NULL)
	      if (alldigits (stringplace))
		{
		  *p_port = atoi (stringplace);
		  HostAndPort = 1;
		}
	  }
      }
    else
      return (SER_FAIL);
  }

  if (HostAndPort)
    {
      if ((addr = inet_addr (p_name)) == INADDR_NONE)
	{
#if defined (_REENTRANT) && defined (linux)
	  gethostbyname_r (p_name, &ht, buff, sizeof (buff), &host, &herrnop);
#elif defined (_REENTRANT) && defined (SOLARIS)
	  host = gethostbyname_r (p_name, &ht, buff, sizeof (buff), &herrnop);
#elif defined (_REENTRANT) && defined (HPUX_10)
	  /* in HP-UX 10 these functions are MT-safe */
	  hted.current = NULL;
	  if (-1 != gethostbyname_r (p_name, &ht, &hted))
	    host = &ht;
#else
	  /*
	   * gethostbyname and gethostbyaddr is a threadsafe on AIX4.3
	   * HP-UX WindowsNT
	   */
	  host = gethostbyname (p_name);
#endif

	  if (!host)
	    {
#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS))
	      int status = herrnop;
#else
	      int status = h_errno;
#endif
	      log_error ("The function gethostbyname returned error %d for host \"%s\".\n", status, p_name);
	      SESSTAT_CLR (ses, SST_OK);
	      return (SER_FAIL);
	    }
	}
    }

  memset (p_addr, '\0', sizeof (saddrin_t));
  p_addr->sin_family = AF_INET;
  p_addr->sin_port = htons (*p_port);
  if (HostAndPort)
    {
      if (host)
	memcpy (&p_addr->sin_addr, host->h_addr, host->h_length);
      else
	memcpy (&p_addr->sin_addr, &addr, sizeof (addr));
    }
  else
    p_addr->sin_addr.s_addr = INADDR_ANY;

  SESSTAT_SET (ses, SST_OK);

  return (SER_SUCC);
}


void
tcpses_set_fd (session_t * ses, int fd)
{
  ses->ses_device->dev_funs->dfp_read = fileses_read;
  ses->ses_device->dev_funs->dfp_write = fileses_write;
  ses->ses_device->dev_connection->con_s = fd;
  ses->ses_device->dev_connection->con_is_file = 1;
}


int
tcpses_get_fd (session_t * ses)
{
  return (ses->ses_device->dev_connection->con_s);
}


int
tcpses_getsockname (session_t * ses, char *buf_out, int buf_out_len)
{
  int s = tcpses_get_fd (ses);
  char buf[150];

  buf[0] = 0;

  if (ses->ses_class == SESCLASS_TCPIP || ses->ses_class == SESCLASS_UDPIP)
    {
      struct sockaddr_in sa;
      socklen_t len = sizeof (sa);

      if (!getsockname (s, (struct sockaddr *) &sa, &len))
	{
	  unsigned char *addr = (unsigned char *) &sa.sin_addr;
	  snprintf (buf, sizeof (buf), "%d.%d.%d.%d:%u",
		addr[0], addr[1], addr[2], addr[3], ntohs (sa.sin_port));
	}
      else
	return -1;
    }
#ifdef COM_UNIXSOCK
  else if (ses->ses_class == SESCLASS_UNIX)
    {
      struct sockaddr_un sa;
      socklen_t len = sizeof (sa);

      if (!getsockname (s, (struct sockaddr *) &sa, &len))
	{
	  strncpy (buf, sa.sun_path, sizeof (buf));
	  buf[sizeof (buf) - 1] = 0;
	}
      else
	return -1;
    }
#endif
  else
    return -1;

  if (buf_out_len && buf_out)
    {
      strncpy (buf_out, buf, buf_out_len);
      buf[buf_out_len - 1] = 0;
    }
  return 0;
}


/*##**********************************************************************
 *
 *              tcpses_listen
 *
 * Starts the listening i.e. waiting for clients to connect.
 * Listening name (address) is taken from the session structure.
 * The mode of listening session is set according to current control fields
 * in session structure.
 *
 * Input params :
 *
 *      ses     -   session pointer
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_SYSCALL  listen() failed, check errno
 *      SER_NOREC    socket creation failed, maybe too many open sockets
 *      SER_CNTRL    control failed
 *      SER_ILLADDR  bind() failed, check errno
 *
 * Limitations  : Address (listening name) must be specified by
 *                set_address() before calling listen
 * Globals used :
 */

#if defined(WINNT) || defined(WINDOWS) || defined(PMN_MODS)
int reuse_address = 1;
#else
int reuse_address = 0;
#endif


void
tcpses_set_reuse_address (int f)
{
  reuse_address = f;
}


static int
tcpses_listen (session_t * ses)
{
  int s;
  int rc;
  saddrin_t *p_addr;
  dbg_printf_1 (("tcpses_listen."));
  init_tcpip ();
  TCP_CHK (ses);

  SESSTAT_CLR (ses, SST_OK);

  p_addr = &(ses->ses_device->dev_address->a_serveraddr.t);
  /* XXX TEMPORARY XXX */
  if ((s = (int) socket (AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0)
    {
      test_eintr (ses, s, errno);
      dbg_perror ("socket()");
      return (SER_NOREC);
    }

  if (reuse_address)
    {
      int f = 1;
      setsockopt (s, SOL_SOCKET, SO_REUSEADDR, (void *) &f, sizeof (f));
    }

  dbg_printf_2 (("Created socket %d", s));

  ses->ses_device->dev_connection->con_s = s;

  dbg_printf_2 (("Calling bind: s=%d, addr=%p, len=%d",
	s, &(ses->ses_device->dev_address->a_serveraddr.t), sizeof (saddrin_t)));

  rc = ses_control_all (ses);
  if (rc != SER_SUCC)
    {
      dbg_printf_2 (("SER_CNTRL"));
      return (SER_CNTRL);
    }

  if ((rc = bind (s,
	(struct sockaddr *) &(ses->ses_device->dev_address->a_serveraddr.t),
	sizeof (saddrin_t))) < 0)
    {
      test_eintr (ses, rc, errno);
      dbg_perror ("bind()");
      return (SER_ILLADDR);
    }

  dbg_printf_2 (("Calling listen: s=%d, qlen=%d", s, LISTEN_QLEN));

  if ((rc = listen (s, LISTEN_QLEN)) < 0)
    {
      test_eintr (ses, rc, errno);
      dbg_perror ("listen()");

#ifdef PCTCP
      if (errno != WSAEINPROGRESS)
#endif
	return (SER_SYSCALL);
    }

  dbg_printf_2 (("listen OK"));

  dbg_printf_2 (("setting status"));
  SESSTAT_SET (ses, SST_LISTENING);
  SESSTAT_SET (ses, SST_OK);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              tcpses_accept
 *
 * Listening session accepts a new connection by calling this function.
 * session_accept() should be called when the status of listening session
 * is SST_CONNECT_PENDING.
 * The mode of new accepted session is set according to current control
 * fields in session structure.
 *
 * Input params :
 *
 *      ses         - listening session pointer
 *
 * Output params: the status of ses and new_ses is updated
 *
 *      new_ses - pointer to new session to be
 *
 * Return value :
 *
 *      SER_SUCC
 *      SER_ILLSESP  illegal session pointer or not a listening session,
 *                   no action taken
 *      SER_SYSCALL  accept failed, check errno
 *      SER_CNTRL    control failed
 *
 * Limitations  : Works only for session that is already in
 *                listening state i.e. tcpses_listen is called
 *
 * Globals used : none
 */
static int
tcpses_accept (session_t * ses, session_t * new_ses)
{
  int rc;
  int new_socket;
  socklen_t addrlen = sizeof (saddr_t);

  dbg_printf_1 (("tcpses_accept."));

  TCP_CHK (ses);
  TCP_CHK (new_ses);

  if (!SESSTAT_ISSET (ses, SST_LISTENING))
    {
      /* If this is not a listening session,
         we should not do an accept */
      return (SER_ILLSESP);
    }

  SESSTAT_SET (new_ses, SST_BROKEN_CONNECTION);

  /* Clear the SST_OK fields first. If everything succeeds,
     set them again before returning */
  SESSTAT_CLR (ses, SST_OK);
  SESSTAT_CLR (new_ses, SST_OK);

  new_socket = (int) accept (ses->ses_device->dev_connection->con_s,
	(struct sockaddr *) &(new_ses->ses_device->dev_connection->con_clientaddr.t),
	&addrlen);

  if (new_socket < 0)
    {
      /* Something went wrong */
      dbg_perror ("accept()");
      test_eintr (ses, new_socket, errno);
      return (SER_SYSCALL);
    }

  new_ses->ses_device->dev_connection->con_s = new_socket;

  rc = ses_control_all (new_ses);
  if (rc != SER_SUCC)
    {
      dbg_printf_2 (("SER_CNTRL"));
      return (SER_CNTRL);
    }

  memcpy (new_ses->ses_device->dev_accepted_address, ses->ses_device->dev_address, sizeof (address_t));

  /* Mark new session as connected */
  SESSTAT_CLR (new_ses, SST_BROKEN_CONNECTION);
  SESSTAT_SET (new_ses, SST_OK);

  SESSTAT_CLR (ses, SST_CONNECT_PENDING);
  SESSTAT_SET (ses, SST_OK);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


int
tcpses_client_port (session_t * ses)
{
  if (ses->ses_class == SESCLASS_UNIX)
    return (unsigned short) -1;
  else
    return ntohs (ses->ses_device->dev_connection->con_clientaddr.t.sin_port);
}


void
tcpses_print_client_ip (session_t * ses, char *buf, int buf_len)
{
  if (ses->ses_class == SESCLASS_UNIX)
    {
      snprintf (buf, buf_len, "127.0.0.1");
    }
  else
    {
      struct sockaddr_in *psa = (struct sockaddr_in *) &(ses->ses_device->dev_connection->con_clientaddr.t);
      unsigned char *addr;
      addr = (unsigned char *) &(psa->sin_addr);
      snprintf (buf, buf_len, "%d.%d.%d.%d", addr[0], addr[1], addr[2], addr[3]);
    }
}


/*
  debug vars
 */


/*##**********************************************************************
 *
 *              tcpses_connect
 *
 * Connects allocated session to a previously specified server process.
 * The server can be specified by function tcpses_setaddr.
 * The mode of new connected session is set according to current control
 * fields in session structure.
 *
 * Input params :
 *
 *      ses     - session pointer
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC     connection established
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_SYSCALL  connect() failed, address was invalid or the server
 *                   process is down. Check errno
 *      SER_NOREC    socket creation failed, maybe too many open sockets
 *      SER_CNTRL    control failed
 *
 * Limitations  :
 *
 * Globals used : none
 */
static int
tcpses_connect (session_t * ses)
{
  saddrin_t *p_addr;		/* shortcut to address information */
  int s;
  int rc;

  dbg_printf_1 (("tcpses_connect."));
  init_tcpip ();
  TCP_CHK (ses);

  /* First, init status fields so that if something fails we
     can return immediately */

  SESSTAT_CLR (ses, SST_OK);
  SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
  SESSTAT_SET (ses, SST_NO_PARTNER);

  p_addr = &(ses->ses_device->dev_address->a_serveraddr.t);

  ses->ses_device->dev_connection->con_s = -1;

  /* Create a socket */
  if ((s = (int) socket (AF_INET, SOCK_STREAM, 0)) < 0)
    {
      test_eintr (ses, s, errno);
      dbg_perror ("socket()");
      return (SER_NOREC);
    }

  /* Connect to the server */
#ifdef ERESTARTSYS
  while ((rc = connect (s, (struct sockaddr *) p_addr, sizeof (saddrin_t))) < 0)
    {
      if (errno != SYS_EWBLK && errno != ERESTARTSYS)
	break;
    }
  if (rc < 0)
    {
#else
  if ((rc = connect (s, (struct sockaddr *) p_addr, sizeof (saddrin_t))) < 0)
    {
#endif
      test_eintr (ses, rc, errno);
      dbg_perror ("connect()");
      dbg_printf_2 (("SER_SYSCALL"));
      closesocket (s);
      return (SER_SYSCALL);
    }

  ses->ses_device->dev_connection->con_s = s;

  rc = ses_control_all (ses);
  if (rc != SER_SUCC)
    {
      dbg_printf_2 (("SER_CNTRL"));
      return (SER_CNTRL);
    }

  /* The connecting succeeded, now we set the status bits correctly */
  SESSTAT_SET (ses, SST_OK);
  SESSTAT_CLR (ses, SST_BROKEN_CONNECTION);
  SESSTAT_CLR (ses, SST_NO_PARTNER);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              tcpses_disconnect
 *
 * Breaks a connection.
 *
 * Input params :
 *
 *      ses     -
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC     connection closed successfully
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_SYSCALL  connection marked broken but some resources may not
 *                   have been fully deallocated
 *
 * Limitations  :
 *
 * Globals used :
 */
static int
tcpses_disconnect (session_t * ses)
{
  int rc;

  dbg_printf_1 (("tcpses_disconnect."));

  TCP_CHK (ses);

  SESSTAT_CLR (ses, SST_OK);

  /* Close the connected socket */
#ifdef PCTCP
  {
/*
    struct linger l = {1, 0};
    rc = setsockopt (ses->ses_device->dev_connection->con_s,
        SOL_SOCKET, SO_LINGER, (void *)&l, sizeof (struct linger));
*/
    rc = shutdown (ses->ses_device->dev_connection->con_s, 2);
  }
#endif

  rc = closesocket (ses->ses_device->dev_connection->con_s);
  ses->ses_device->dev_connection->con_s = -1;

  /* Whether close succeeded or not, the connection will be
     unusable after the following */

  SESSTAT_SET (ses, SST_BROKEN_CONNECTION);

  memset (ses->ses_device->dev_accepted_address, 0, sizeof (address_t));

  if (rc < 0)
    {
      dbg_perror ("close()");
      test_eintr (ses, rc, errno);
      dbg_printf_2 (("SER_SYSCALL"));
      return (SER_SYSCALL);
    }

  SESSTAT_SET (ses, SST_OK);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              tcpses_write
 *
 * Writes data to a connected socket.
 *
 * Input params :
 *
 *      ses         - session pointer
 *      buffer  - pointer to start of a memory block where data is
 *                to be copied
 *      n_bytes - size of the buf (in bytes)
 *
 * Output params:
 *      the ses_status is updated
 *      the ses_bytes_written is updated
 *
 * Return value : >0, number of bytes successfully written
 *               ==0, non-blocking write would have blocked
 *                <0, error code
 *
 * Limitations  :
 *
 * Globals used :
 */
int last_w_errno;
int
tcpses_get_last_w_errno ()
{
  return last_w_errno;
}


static int
tcpses_write (session_t * ses, char *buffer, int n_bytes)
{
  int flags = 0;		/* no flags used, one could use MSG_OOB  */
  int n_out;

  dbg_printf_1 (("tcpses_write."));

  TCP_CHK (ses);

  /* Set the OK flag here,
     test_ functions clear it if something goes wrong */
  SESSTAT_W_SET (ses, SST_OK);
  SESSTAT_W_CLR (ses, SST_BLOCK_ON_WRITE);

  n_out = send (ses->ses_device->dev_connection->con_s, buffer, n_bytes, flags);
#if defined (PCTCP) & !defined (WIN32)
  Yield ();
#endif
  dbg_printf_2 (("send() : n_out=%d.", n_out));
  ses->ses_w_errno = 0;
  if (n_out <= 0)
    {
      int eno = errno;
/*    printf ("write eno = %d\n", eno); */
      last_w_errno = eno;
      ses->ses_w_errno = eno;
      if (EINTR == eno)
	{
	  SESSTAT_W_CLR (ses, SST_OK);
	  SESSTAT_W_SET (ses, SST_INTERRUPTED);
	}
      else if (test_writeblock (ses, n_out, eno) == SER_SUCC)
	;
      else
	{
	  SESSTAT_W_SET (ses, SST_BROKEN_CONNECTION);
	  SESSTAT_W_CLR (ses, SST_OK);
	}
    }
  ses->ses_bytes_written = n_out;
  return (n_out);
}


/*##**********************************************************************
 *
 *              tcpses_read
 *
 * Reads data from a connected socket.
 *
 * Input params :
 *
 *      ses         - session pointer
 *      buffer  - pointer to start of a memory block where received data is
 *                to be copied
 *      n_bytes - size of the buf (in bytes)
 *
 * Output params:
 *      the ses_status is updated
 *      the ses_bytes_read is updated
 *
 * Return value : >0, number of bytes successfully read
 *               ==0, non-blocking read ended because no data was available
 *                <0, error code
 * Limitations  :
 *
 * Globals used :
 */
int last_r_errno;
int
tcpses_get_last_r_errno ()
{
  return last_r_errno;
}


static int
tcpses_read (session_t * ses, char *buffer, int n_bytes)
{
  int n_in;

  dbg_printf_1 (("tcpses_read."));

  TCP_CHK (ses);

  /* Set the OK flag here,
     test_ functions clear it if something goes wrong */
  ses->ses_status = 0;
  SESSTAT_SET (ses, SST_OK);

  if (ses->ses_reads)
    GPF_T;
  else
    ses->ses_reads = 1;
#ifdef AIX
  n_in = read (ses->ses_device->dev_connection->con_s, buffer, n_bytes);
#else
  n_in = recv (ses->ses_device->dev_connection->con_s, buffer, n_bytes, 0);
#endif
  ses->ses_reads = 0;

  dbg_printf_2 (("recv() : n_in=%d.", n_in));

  if (n_in <= 0)
    {
      int eno = errno;
/*    printf ("read eno = %d\n", eno); */

      last_r_errno = eno;
      if (test_eintr (ses, n_in, eno) == SER_SUCC)
	{
	  /* Tested for possible EINTR caused by task switch signal etc. */
	}
      else if (test_readblock (ses, n_in, eno) == SER_SUCC)
	{
	  /* ... or if non_blocking operation would have blocked */
	}
      else if (test_timeout (ses, n_in, eno) == SER_SUCC)
	{
	  /* ... or if blocking oper ended because of time-out */
	}
      else
	{
	  test_broken (ses, n_in, eno);
	}
    }
  ses->ses_bytes_read = n_in;
  return (n_in);
}


extern char *build_thread_model;	/* from Thread */


long read_block_usec;
long write_block_usec;

int
tcpses_is_read_ready (session_t * ses, timeout_t * to)
{
#ifndef FOR_GTK_TESTS
  int rc;
  struct timeval to_2;
  fd_set fds;
  int fd = ses->ses_device->dev_connection->con_s;
  if (to)
    {
      memset (&to_2, 0, sizeof (to_2));
      to_2.tv_sec = to->to_sec;
      to_2.tv_usec = to->to_usec;
    }

  if (ses->ses_device->dev_connection->con_is_file)
    return 1;

  if (fd < 0)					 /* the sequential read will throw exception */
    return SER_SUCC;

  FD_ZERO (&fds);
  FD_SET (fd, &fds);
#endif
  SESSTAT_CLR (ses, SST_TIMED_OUT);

#ifndef FOR_GTK_TESTS

  if (to &&
      to->to_sec == dks_fibers_blocking_read_default_to.to_sec &&
      to->to_usec == dks_fibers_blocking_read_default_to.to_usec)
    return SER_SUCC;

  if (ses->ses_reads)
    GPF_T;
  else
    ses->ses_reads = 1;

  rc = select (fd + 1, &fds, NULL, NULL, to ? &to_2 : NULL);
  ses->ses_reads = 0;
  if (!rc)
    {
      SESSTAT_SET (ses, SST_TIMED_OUT);
    }
  if (to)
    read_block_usec += (to->to_sec - to_2.tv_sec) * 1000000 + (to->to_usec - to_2.tv_usec);
#endif
  return SER_SUCC;
}


int
tcpses_is_write_ready (session_t * ses, timeout_t * to)
{
#ifndef FOR_GTK_TESTS
  int rc;
  struct timeval to_2;
  fd_set fds;
  int fd = ses->ses_device->dev_connection->con_s;
  if (to)
    {
      memset (&to_2, 0, sizeof (to_2));
      to_2.tv_sec = to->to_sec;
      to_2.tv_usec = to->to_usec;
    }

  if (ses->ses_device->dev_connection->con_is_file)
    return 1;

  if (fd < 0)					 /* the sequential read will throw exception */
    return SER_SUCC;

  FD_ZERO (&fds);
  FD_SET (fd, &fds);
#endif
  SESSTAT_W_CLR (ses, SST_TIMED_OUT);

#ifndef FOR_GTK_TESTS
  rc = select (fd + 1, NULL, &fds, NULL, to ? &to_2 : NULL);
  if (!rc)
    {
      SESSTAT_W_SET (ses, SST_TIMED_OUT);
    }
  if (to)
    write_block_usec += (to->to_sec - to_2.tv_sec) * 1000000 + (to->to_usec - to_2.tv_usec);
#endif
  return SER_SUCC;
}


static int
fileses_read (session_t * ses, char *buffer, int n_bytes)
{
  int n_in;

  /* Set the OK flag here, test_ functions clear it if something goes wrong */
  SESSTAT_SET (ses, SST_OK);
  SESSTAT_CLR (ses, SST_BROKEN_CONNECTION);
  SESSTAT_CLR (ses, SST_BLOCK_ON_READ);

  n_in = read (ses->ses_device->dev_connection->con_s, buffer, n_bytes);

  if (n_in <= 0)
    {
#ifdef DEBUG
      perror ("reading from a file");
#endif
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
      SESSTAT_CLR (ses, SST_OK);
    }

  ses->ses_bytes_read = n_in;
  return (n_in);
}


static int
fileses_write (session_t * ses, char *buffer, int n_bytes)
{
  int n_out;

  /* Set the OK flag here, test_ functions clear it if something goes wrong */
  SESSTAT_SET (ses, SST_OK);
  SESSTAT_CLR (ses, SST_BLOCK_ON_READ);
  SESSTAT_CLR (ses, SST_BROKEN_CONNECTION);

  n_out = write (ses->ses_device->dev_connection->con_s, buffer, n_bytes);

  if (n_out <= 0)
    {
#ifdef DEBUG
      perror ("writing from a file");
#endif
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
      SESSTAT_CLR (ses, SST_OK);
    }

  ses->ses_bytes_written = n_out;
  return (n_out);
}


#ifdef SUNRPC

#ifdef __cplusplus
extern "C" int _rpc_dtablesize ();
extern "C" fd_set svc_fdset;
#else
extern int _rpc_dtablesize ();
extern fd_set svc_fdset;
#endif

int sun_rpcs_pending = 0;

typedef void (*srpc_cb_t) ();

srpc_cb_t srpc_callback;


void
tcpses_set_sun_rpc_callback (srpc_cb_t f)
{
  srpc_callback = f;
}


void
svc_run_3 (timeout_t * to)
{
#ifdef FD_SETSIZE
  fd_set readfds;
#else
  int readfds;
#endif /* def FD_SETSIZE */
  struct timeval tv;

#ifndef AIX
  extern int errno;
#endif

#ifdef FD_SETSIZE
  readfds = svc_fdset;
#else
  readfds = svc_fds;
#endif /* def FD_SETSIZE */

  if (to != NULL)
    {
      tv.tv_sec = to->to_sec;
      tv.tv_usec = to->to_usec;
    }

  switch (select (_rpc_dtablesize (), &readfds, 0, 0, to == NULL ? NULL : &tv))
    {
    case -1:
      if (errno == SYS_EINTR)
	{
	  return;
	}
      perror ("svc_run: - select failed");
      return;

    case 0:
      return;

    default:
      svc_getreqset (&readfds);
    }
}


int
tcpses_add_sun_rpc_sockets (fd_set * reads)
{
  int n;
  int max_set = 0;
  int max = _rpc_dtablesize ();
  if (sun_rpcs_pending)
    return 0;
  for (n = 2; n < max; n++)
    {
      if (FD_ISSET (n, &svc_fdset))
	{
	  FD_SET (n, reads);
	  max_set = n;
	};
    };
  return max_set;
}


fd_set srpc_fd_set;


void
tcpses_process_sun_rpc_sockets (fd_set * all_fds)
{
  int n, any_sun;
  int max = _rpc_dtablesize ();
  FD_ZERO (&srpc_fd_set);
  any_sun = 0;
  for (n = 2; n < max; n++)
    {
      if (FD_ISSET (n, all_fds) && FD_ISSET (n, &svc_fdset))
	{
	  FD_SET (n, &srpc_fd_set);
	  any_sun = 1;
	};
      if (any_sun)
	{
	  srpc_callback ();
	}
    };
}


#else

#define tcpses_process_sun_rpc_sockets (q)
#define tcpses_add_sun_rpc_sockets (q)

#endif


/*##**********************************************************************
 *
 *              tcpses_select
 *
 *
 *
 * Input params :
 *
 *      ses_count  - number of session pointers in writes and reads arrays
 *      reads      - array of reading sessions to be inspected
 *      writes     - array of writing sessions to be inspected
 *      timeout    - pointer to timeout_t containing timeout value
 *                   If no time out is wanted, NULL should be passed
 * Output params:
 *
 * Return value : >0, number of criteria met
 *                <0, error code
 *                       SER_ILLSESP
 *                       SER_INTR       external interrupt
 *
 * Limitations  :  Does not yet support reads and writes array
 *                 to contain any other than TCPIP-sessions
 * Globals used :
 */
int
tcpses_select (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout)
{
  fd_set read_set;
  fd_set write_set;
  fd_set excep_set;
  struct timeval to;
  int i, n;
  int s = 0, s_max = 0;
  int rc;

  dbg_printf_1 (("tcpses_select, ses_count = %d.", ses_count));

  if (timeout != NULL)
    {
      to.tv_sec = timeout->to_sec;
      to.tv_usec = timeout->to_usec;
    }

  /* Copy socket descriptors of all sessions to corresponding
     fd_set structures.
     Keep max descriptor in s_max.
   */

  s_max = fill_fdset (ses_count, reads, &read_set);
  if (s_max < 0)
    {
      return (s_max);
    }

  s = fill_fdset (ses_count, writes, &write_set);
  if (s < 0)
    {
      return (s);
    }

  s_max = MAX (s, s_max);

  s = fill_fdset (ses_count, reads, &excep_set);
  if (s < 0)
    {
      return (s);
    }

  s_max = MAX (s, s_max);

  /* setting here all status fields to SST_BLOCK_ON_READ or
     SST_BLOCK_ON_WRITE */

  set_array_status (ses_count, reads, SST_BLOCK_ON_READ);
  set_array_status (ses_count, writes, SST_BLOCK_ON_WRITE);
  for (n = 0; n < ses_count; n++)
    {
      if (reads[n])
	SESSTAT_CLR (reads[n], SST_CONNECT_PENDING);
    };

  dbg_printf_2 (("Calling select..."));

#ifdef SUNRPC
  s = tcpses_add_sun_rpc_sockets (&read_set);
  s_max = MAX (s_max, s);
#endif
  rc = select (s_max + 1, &read_set, &write_set, &excep_set, timeout == NULL ? NULL : &to);

  dbg_printf_2 (("select() : rc=%d.", rc));
  switch (rc)
    {
    case -1:
      /* error? */
      if (errno == SYS_EINTR)
	{
	  /* Possible EINTR caused by task signal */
	  dbg_printf_2 (("Select ended by EINTR."));
	  set_array_status (ses_count, reads, SST_INTERRUPTED);
	  set_array_status (ses_count, writes, SST_INTERRUPTED);
	  return (SER_INTR);
	}
      else
	{
	  dbg_printf_2 (("Select ended with error."));
	  return (rc);
	}

    case 0:
      /* timeout */
      return (rc);

    default:
      /* rc equals number of criteria met,
         here we update all the session status values.
       */
#ifdef SUNRPC
      tcpses_process_sun_rpc_sockets (&read_set);
#endif
      dbg_printf_2 (("Updating sessions."));
      for (i = 0; i < ses_count; i++)
	{
	  if (reads[i] != NULL)
	    {
	      dbg_printf_2 (("i=%d", i));
	      s = reads[i]->ses_device->dev_connection->con_s;
	      dbg_printf_2 (("reads[i] : FD_ISSET=%d", FD_ISSET (s, &read_set)));

	      if (FD_ISSET (s, &read_set) || FD_ISSET (s, &excep_set))
		{
		  if (SESSTAT_ISSET (reads[i], SST_LISTENING))
		    {
		      SESSTAT_SET (reads[i], SST_CONNECT_PENDING);
		    }
		  else
		    {
		      SESSTAT_CLR (reads[i], SST_BLOCK_ON_READ);
		    }
		}
	    }

	  if (writes[i] != NULL)
	    {
	      s = writes[i]->ses_device->dev_connection->con_s;
	      dbg_printf_2 (("writes[i]: FD_ISSET=%d", FD_ISSET (s, &write_set)));
	      if (FD_ISSET (s, &write_set))
		{
		  SESSTAT_CLR (writes[i], SST_BLOCK_ON_WRITE);
		}
	      else
		{
		  SESSTAT_SET (writes[i], SST_BLOCK_ON_WRITE);
		}
	    }
	}

      return (rc);
    }
}


/*##**********************************************************************
 *
 *              tcpses_set_control
 *
 * Function to control session's properties
 *
 * Input params :
 *
 *      ses             - session pointer
 *      fieldtoset      - some session control (SC_ macro) value
 *      p_value     - pointer to memory area containing the option value.
 *      size        - must equal sizeof(*p_value)
 *
 *
 *      Value type depends on fieldtoset in the following way.
 *
 *      fieldtoset     value type   p_value
 *      ------------------------------------------------------------------
 *      SC_BLOCKING       int       1=Blocking mode, 0=Non-blocking mode
 *
 *      SC_TIMEOUT     timeout_t    timeout
 *
 *      SC_MSGLEN         int       for connectionless protocols:
 *                                    - max transaction (msg) length in bytes
 * 					(Currently not in use)
 *                                  for connection oriented protocols:
 *                                    - hint for lower levels to reserve big
 *                                      enough communication buffers to achieve
 *                                      maximum performance
 *					(0 = leave to OS)
 *
 * Output params: control fields of ses are updated
 *
 * Return value :
 *
 *      SER_SUCC
 *      SER_ILLPRM
 *
 * Limitations  : Current implementation has effect only on
 *                connected sessions because of the usage of fcntl()
 *                and setsockopt()
 * Globals used :
 */
static int
tcpses_set_control (session_t * ses, int fieldtoset, char *p_value, int size)
{
  int opt;
  int ctrl;
  int rc;
  timeout_t timeout;
  control_t *sescontrol = ses->ses_control;

  int s = ses->ses_device->dev_connection->con_s;

  dbg_printf_1 (("tcpses_control."));

  TCP_CHK (ses);

  switch (fieldtoset)
    {
    case SC_BLOCKING:

      /*
       * SC_BLOCKING ignored, because FTP PC/TCP
       * gets an exception 13 on call fcntl(s, F_GETFL, 0).
       * Why ? Dunno. Maybe there is a way around this ???
       */
      if (size != sizeof (sescontrol->ctrl_blocking))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy ((char *) &ctrl, p_value, size);
	  /* ctrl = *(int *)p_value; */
	};

      if (ctrl != 0)
	{
	  unsigned int dontblock = 0;
	  dbg_printf_2 (("Setting blocking flag (removing O_NDELAY)."));

#ifdef FIONBIO
# ifdef OS2
	  rc = ioctl (s, FIONBIO, (char *) &dontblock, sizeof (dontblock));
# else
	  rc = ioctlsocket (s, FIONBIO, &dontblock);
# endif
#else
	  /*
	   *  Can we turn off O_NONBLOCK somehow?
	   *  Just assume the socket is in blocking mode already...
	   */
	  rc = 0;
#endif
	}
      else
	{
	  unsigned int dontblock = 1;
	  dbg_printf_2 (("Removing blocking flag (setting O_NDELAY)."));
#ifdef FIONBIO
# ifdef OS2
	  rc = ioctl (s, FIONBIO, (char *) &dontblock, sizeof (dontblock));
# else
	  rc = ioctlsocket (s, FIONBIO, &dontblock);
# endif
#else
# ifdef O_NONBLOCK
	  rc = fcntl (s, F_SETFL, O_NONBLOCK);
# else
	  rc = fcntl (s, F_SETFL, FNDELAY);
# endif
#endif
	}
      if (rc < 0)
	return (SER_SYSCALL);
      sescontrol->ctrl_blocking = ctrl;
      rc = SER_SUCC;
      break;

    case SC_TIMEOUT:
      if (size != sizeof (timeout_t))
	{
	  dbg_printf_2 (("SER_ILLPRM"));
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy ((char *) &timeout, p_value, size);
	  /* timeout = ((timeout_t *)p_value)->to_usec; */
	}

      dbg_printf_2 (("Setting recv timeout to %ld.%ld.", timeout.to_sec, timeout.to_usec));
#ifdef SO_RCVTIMEO
      rc = setsockopt (s, SOL_SOCKET, SO_RCVTIMEO, (char *) &timeout, sizeof (timeout));
#endif
      /* opt = timeout; */
      dbg_printf_2 (("Setting send timeout to %ld.%ld.", timeout.to_sec, timeout.to_usec));
#ifdef SO_SNDTIMEO
      rc = setsockopt (s, SOL_SOCKET, SO_SNDTIMEO, (char *) &timeout, sizeof (timeout));
#endif
      *(sescontrol->ctrl_timeout) = *(timeout_t *) p_value;
#ifdef TCP_DEBUG
      {
	char buf[100];
	int buflen = 100;
	long *to = (long *) buf;
	rc = getsockopt (s, SOL_SOCKET, SO_RCVTIMEO, buf, &buflen);
	dbg_printf_2 (("getsockopt: rc=%d, timeout=%ld", rc, *to));
      }
#endif /* TCP_DEBUG */
      rc = SER_SUCC;
      break;

    case SC_MSGLEN:

      if (size != sizeof (sescontrol->ctrl_msg_length))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy ((char *) &opt, p_value, size);
	  /* opt = *(int *)p_value; */
	}
      if (opt > 0)
	{
	  dbg_printf_2 (("Setting recv bufsize to %d.", opt));
	  rc = setsockopt (s, SOL_SOCKET, SO_RCVBUF, (char *) &opt, sizeof (opt));

	  opt = *(int *) p_value;
	  dbg_printf_2 (("Setting send bufsize to %d.", opt));
	  rc = setsockopt (s, SOL_SOCKET, SO_SNDBUF, (char *) &opt, sizeof (opt));
	}
      sescontrol->ctrl_msg_length = *(int *) p_value;
      rc = SER_SUCC;
      break;

    default:
      rc = SER_ILLPRM;
    }

  dbg_printf_2 (("control: rc = %d", rc));
  return (rc);
}


/*##**********************************************************************
 *
 *              fill_fdset
 *
 * Adds socket descriptors of present elements in sestable to fd_set
 * structure referenced by p_fdset.
 *
 * Input params :
 *
 *      sestable        - array containing session structures
 *      count       - max number of elements in sestable array
 *      p_fdset     - pointer to fd_set structure
 *
 * Output params: -
 *
 * Return value : >= 0 : The biggest socket descriptor in p_fdset
 *                 < 0 : SER_ILLSESP, if an illegal session pointer found
 *
 * Limitations  : -
 *
 * Globals used : -
 */
static int
fill_fdset (int sescount, session_t ** sestable, fd_set * p_fdset)
{
  int i;
  int s, s_max = 0;
  int n_added = 0;

  dbg_printf_3 (("fill_fdset."));

  FD_ZERO (p_fdset);

  for (i = 0; (i < sescount); i++)
    {

      if (sestable[i] == NULL)
	continue;

      TCP_CHK (sestable[i]);

      s = sestable[i]->ses_device->dev_connection->con_s;
      FD_SET (s, p_fdset);
#ifdef TCP_DEBUG
      ss_assert (FD_ISSET (s, p_fdset));
#endif /* TCP_DEBUG */
      s_max = MAX (s, s_max);
      n_added++;
    }
  dbg_printf_4 (("n_added=%d, s_max=%d", n_added, s_max));
  return (s_max);
}


/*##**********************************************************************
 *
 *              test_eintr
 *
 * Test if the previous operation was interrupted by a signal.
 * If so, update the status of ses by setting the SST_INTERRUPTED
 * flag and clearing the SST_OK flag.
 *
 * Input params :
 *
 *      retcode - the return code of last system call
 *      eno         - errno after last system call
 *
 * Output params:
 *      ses         - session whose status is to be maintained
 *
 * Return value :
 *
 *      SER_SUCC    last system call was interrupted, ses updated
 *      SER_FAIL    no interrupt, ses not touched
 *
 * Limitations  : DANGER! Behavior of retcode-errno pair may not be the
 *                same in all operating systems
 * Globals used :
 */
static int
test_eintr (session_t * ses, int retcode, int eno)
{
  ses->ses_errno = eno;
  dbg_printf_3 (("test_eintr. rc=%d, eno=%d", retcode, eno));

  if (retcode == -1 && eno == SYS_EINTR)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_INTERRUPTED);
      dbg_printf_4 (("SER_SUCC."));
      return (SER_SUCC);
    }
  else
    {
      return (SER_FAIL);
    }
}


/*##**********************************************************************
 *
 *              test_readblock
 *
 * Test if the previous read operation would have blocked if the session
 * had not been in non-blocking mode.
 * If so, update the status of ses by setting the SST_BLOCK_ON_READ
 * flag and clearing the SST_OK flag.
 *
 * Input params :
 *
 *      retcode - the return code of last system call
 *      eno         - errno after last system call
 *
 * Output params:
 *      ses         - session whose status is to be maintained
 *
 * Return value :
 *
 *      SER_SUCC    last read would have blocked, ses updated
 *      SER_FAIL    no block, ses not touched
 *
 * Limitations  : DANGER! Behavior of retcode-errno pair may not be the
 *                same in all operating systems
 * Globals used :
 */
static int
test_readblock (session_t * ses, int retcode, int eno)
{
  dbg_printf_3 (("test_readblock. rc=%d, eno=%d", retcode, eno));

#if defined (PCTCP)
  if (retcode == -1 && (eno == WSAEWOULDBLOCK))
#elif defined (EWOULDBLOCK)
  if (retcode == -1 && (eno == EAGAIN || eno == EWOULDBLOCK))
#else
  if (retcode == -1 && (eno == EAGAIN))
#endif
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_BLOCK_ON_READ);
      dbg_printf_4 (("SER_SUCC."));
      return (SER_SUCC);
    }
  else
    {
      return (SER_FAIL);
    }
}


/*##**********************************************************************
 *
 *              test_writeblock
 *
 * Test if the previous write operation would have blocked if the session
 * had not been in non-blocking mode.
 * If so, update the status of ses by setting the SST_BLOCK_ON_WRITE
 * flag and clearing the SST_OK flag.
 *
 * Input params :
 *
 *      retcode - the return code of last system call
 *      eno         - errno after last system call
 *
 * Output params:
 *      ses         - session whose status is to be maintained
 *
 * Return value :
 *
 *      SER_SUCC    last write would have blocked, ses updated
 *      SER_FAIL    no block, ses not touched
 *
 * Limitations  : DANGER! Behavior of retcode-errno pair may not be the
 *                same in all operating systems
 * Globals used :
 */
static int
test_writeblock (session_t * ses, int retcode, int eno)
{
  dbg_printf_3 (("test_writeblock. rc=%d, eno=%d", retcode, eno));

#if defined (PCTCP)
  if (retcode == -1 && (eno == WSAEWOULDBLOCK))
#elif defined (EWOULDBLOCK)
  if (retcode == -1 && (eno == EAGAIN || eno == EWOULDBLOCK))
#else
  if (retcode == -1 && (eno == EAGAIN))
#endif
    {
      SESSTAT_W_CLR (ses, SST_OK);
      SESSTAT_W_SET (ses, SST_BLOCK_ON_WRITE);
      dbg_printf_4 (("SER_SUCC."));
      return (SER_SUCC);
    }
  else
    {
      return (SER_FAIL);
    }
}


/*##**********************************************************************
 *
 *              test_timeout
 *
 * Test if the previous read/write operation ended because it timed out.
 * If so, update the status of ses by setting the SST_TIMED_OUT
 * flag and clearing the SST_OK flag.
 *
 * Input params :
 *
 *      retcode - the return code of last system call
 *      eno         - errno after last system call
 *
 * Output params:
 *      ses         - session whose status is to be maintained
 *
 * Return value :
 *
 *      SER_SUCC    last operation timed out, ses updated
 *      SER_FAIL    no block, ses not touched
 *
 * Limitations  : DANGER! Behavior of retcode-errno pair may not be the
 *                same in all operating systems
 * Globals used :
 */
static int
test_timeout (session_t * ses, int retcode, int eno)
{
  dbg_printf_3 (("test_timeout. rc=%d, eno=%d", retcode, eno));

  if (retcode == 0 && eno == 0)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_TIMED_OUT);
      dbg_printf_4 (("SER_SUCC."));
      return (SER_SUCC);
    }
  else
    {
      return (SER_FAIL);
    }
}


/*##**********************************************************************
 *
 *              test_broken
 *
 * Tests if connection is broken (after read/write operation).
 * If so, update the status of ses by setting the SST_BROKEN_CONNECTION
 * flag and clearing the SST_OK flag.
 *
 * Input params :
 *      retcode - the return code of last system call
 *      eno         - errno after last system call
 *
 * Output params:
 *      ses         - session whose status is to be maintained
 *
 * Return value :
 *
 *      SER_SUCC    session's connection broken, ses updated
 *      SER_FAIL    no block, ses not touched
 *
 * Limitations  : Other possible situations causing< retcode to be negative
 *                must be checked first.
 * Globals used :
 */
static int
test_broken (session_t * ses, int retcode, int eno)
{
  dbg_printf_3 (("test_broken. rc=%d, eno=%d", retcode, eno));

  if (retcode == -1)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
      dbg_printf_4 (("SER_SUCC."));
      return (SER_SUCC);
    }
  else
    {
      return (SER_FAIL);
    }
}


/*##**********************************************************************
 *
 *              set_array_status
 *
 * Sets the status of all sessions in 'sesarr' to 'status'
 *
 */
static void
set_array_status (int count, session_t ** sesarr, int status)
{
  int i;

  dbg_printf_3 (("set_array_status."));
  for (i = 0; i < count; i++)
    {
      if (sesarr[i] != NULL)
	SESSTAT_SET (sesarr[i], status);
    }
}


/*##**********************************************************************
 *
 *              ses_control_all
 *
 * Takes all current control values of ses in effect
 *
 */
static int
ses_control_all (session_t * ses)
{
  int rc = 0;

  dbg_printf_3 (("ses_control_all."));

  rc = session_set_control (ses, SC_BLOCKING,
	(char *) &(ses->ses_control->ctrl_blocking),
	sizeof (ses->ses_control->ctrl_blocking));

  rc |= session_set_control (ses, SC_TIMEOUT,
	(char *) (ses->ses_control->ctrl_timeout),
	sizeof (timeout_t));

  rc |= session_set_control (ses, SC_MSGLEN,
	(char *) &(ses->ses_control->ctrl_msg_length),
	sizeof (ses->ses_control->ctrl_msg_length));

  dbg_printf_4 (("%d", rc));

  return (rc);
}


#ifdef PCTCP
int
init_pctcp ()
{
  WORD wVersionRequested;
  WSADATA wsaData;
  int err;

  wVersionRequested = (1 << 8) + 1;
  err = WSAStartup (wVersionRequested, &wsaData);
  if (err != 0)
    {
      /* Tell the user that we couldn't find a usable winsock.dll. */
      return err;
    }

  /* Confirm that the Windows Sockets DLL supports 1.1.
   * Note that if the DLL supports versions greater
   * than 1.1 in addition to 1.1, it will still return
   * 1.1 in wVersion since that is the version we requested.
   */
  if (LOBYTE (wsaData.wVersion) != 1 || HIBYTE (wsaData.wVersion) != 1)
    {
      /* Tell the user that we couldn't find a usable winsock.dll. */
      WSACleanup ();
      return WSAVERNOTSUPPORTED;
    }

  /* The Windows Sockets DLL is acceptable.  Proceed.  */
  if (LOBYTE (wVersionRequested) < 1 ||
      (LOBYTE (wVersionRequested) == 1 && HIBYTE (wVersionRequested) < 1))
    {
      return WSAVERNOTSUPPORTED;
    }

  /*WSASetBlockingHook ((FARPROC) Yield); */
  return 0;
}
#endif

unsigned int
tcpses_get_port (session_t * ses)
{
  if (ses->ses_class == SESCLASS_UNIX)
    {
      return (unsigned int) -1;
    }
  else
    {
      unsigned short *p = (unsigned short *) &(ses->ses_device->dev_address->a_port);
      return (unsigned int) (*p);
    }
}


unsigned int
tcpses_get_accepted_port (session_t * ses)
{
  if (ses->ses_class == SESCLASS_UNIX)
    {
      return (unsigned int) -1;
    }
  else
    {
      unsigned short *p = (unsigned short *) &(ses->ses_device->dev_accepted_address->a_port);
      return (unsigned int) (*p);
    }
}


/*##**********************************************************************
 *
 *             tcpses_host_info
 *
 * print in buf hostname & port from accepted connection
 * return port number
 * from - 1 from listening session / 0 - from accepted session
 */
int
tcpses_addr_info (session_t * ses, char *buf, size_t max_buf, int deflt, int from)
{
/*  unsigned char ip [sizeof (unsigned long)];*/
  unsigned long h;
  char *hn;
  unsigned short *p1 = NULL;
  unsigned short int p = 0;
  if (!ses || !ses->ses_device || !ses->ses_device->dev_accepted_address)
    return 0;
  if (ses->ses_class == SESCLASS_UNIX)
    return 0;
  if (from)
    {
      h = ntohl (ses->ses_device->dev_accepted_address->a_serveraddr.t.sin_addr.s_addr);
      hn = ses->ses_device->dev_accepted_address->a_hostname;
      p1 = (unsigned short *) &(ses->ses_device->dev_accepted_address->a_port);
    }
  else
    {
      h = ntohl (ses->ses_device->dev_address->a_serveraddr.t.sin_addr.s_addr);
      hn = ses->ses_device->dev_address->a_hostname;
      p1 = (unsigned short *) &(ses->ses_device->dev_address->a_port);
    }

  if (p1)
    p = *p1;

  if (!p && deflt)
    p = deflt;
  if (buf && h && p)
    {
/*      memcpy (&(ip[0]), (unsigned char *)&h, sizeof (unsigned long));
      snprintf (buf, max_buf, "%u.%u.%u.%u:%d", ip[3], ip[2], ip[1], ip[0], p);*/
      snprintf (buf, max_buf, "%s:%d", hn, p);
    }
  else if (buf && p)
    snprintf (buf, max_buf, ":%d", p);
  return (int) (p);
}


void
tcpses_error_message (int saved_errno, char *msgbuf, int size)
{
#ifndef PCTCP
  int msg_len;
#endif

  if (!msgbuf || size < 1)
    return;
#ifdef PCTCP
  switch (saved_errno)
    {
    case WSAEACCES:
      strncpy (msgbuf, "Permission denied", size - 1);
      break;

    case WSAEADDRINUSE:
      strncpy (msgbuf, "Address already in use", size - 1);
      break;

    case WSAEADDRNOTAVAIL:
      strncpy (msgbuf, "Cannot assign requested address", size - 1);
      break;

    case WSAEAFNOSUPPORT:
      strncpy (msgbuf, "Address family not supported by protocol family", size - 1);
      break;

    case WSAEALREADY:
      strncpy (msgbuf, "Operation already in progress", size - 1);
      break;

    case WSAECONNABORTED:
      strncpy (msgbuf, "Software caused connection error", size - 1);
      break;

    case WSAECONNREFUSED:
      strncpy (msgbuf, "Connection refused", size - 1);
      break;

    case WSAECONNRESET:
      strncpy (msgbuf, "Connection reset by peer", size - 1);
      break;

    case WSAEDESTADDRREQ:
      strncpy (msgbuf, "Destination address required", size - 1);
      break;

    case WSAEFAULT:
      strncpy (msgbuf, "Bad address", size - 1);
      break;

    case WSAEHOSTDOWN:
      strncpy (msgbuf, "Host is down", size - 1);
      break;

    case WSAEINPROGRESS:
      strncpy (msgbuf, "Operation now in progress", size - 1);
      break;

    case WSAEINTR:
      strncpy (msgbuf, "Interrupted function call", size - 1);
      break;

    case WSAEINVAL:
      strncpy (msgbuf, "Invalid argument", size - 1);
      break;

    case WSAEISCONN:
      strncpy (msgbuf, "Socket already connected", size - 1);
      break;

    case WSAEMFILE:
      strncpy (msgbuf, "Too many open files", size - 1);
      break;

    case WSAEMSGSIZE:
      strncpy (msgbuf, "Message too long", size - 1);
      break;

    case WSAENETDOWN:
      strncpy (msgbuf, "Network is down", size - 1);
      break;

    case WSAENETRESET:
      strncpy (msgbuf, "Network dropped connection on reset", size - 1);
      break;

    case WSAENETUNREACH:
      strncpy (msgbuf, "Network is unreachable", size - 1);
      break;

    case WSAENOBUFS:
      strncpy (msgbuf, "No buffer space available", size - 1);
      break;

    case WSAENOPROTOOPT:
      strncpy (msgbuf, "Bad protocol option", size - 1);
      break;

    case WSAENOTCONN:
      strncpy (msgbuf, "Socket is not connected", size - 1);
      break;

    case WSAENOTSOCK:
      strncpy (msgbuf, "Socket operation on nonsocket", size - 1);
      break;

    case WSAEOPNOTSUPP:
      strncpy (msgbuf, "Operation not supported", size - 1);
      break;

    case WSAEPFNOSUPPORT:
      strncpy (msgbuf, "Protocol family not supported", size - 1);
      break;

    case WSAEPROCLIM:
      strncpy (msgbuf, "Too many processes", size - 1);
      break;

    case WSAEPROTONOSUPPORT:
      strncpy (msgbuf, "Protocol not supported", size - 1);
      break;

    case WSAEPROTOTYPE:
      strncpy (msgbuf, "Protocol wrong type for socket", size - 1);
      break;

    case WSAESHUTDOWN:
      strncpy (msgbuf, "Cannot send after socket shutdown", size - 1);
      break;

    case WSAESOCKTNOSUPPORT:
      strncpy (msgbuf, "Socket type not supported", size - 1);
      break;

    case WSAETIMEDOUT:
      strncpy (msgbuf, "Connection timed out", size - 1);
      break;

    case WSATYPE_NOT_FOUND:
      strncpy (msgbuf, "Class type not found", size - 1);
      break;

    case WSAEWOULDBLOCK:
      strncpy (msgbuf, "Resource temporarily unavailable", size - 1);
      break;

    case WSAHOST_NOT_FOUND:
      strncpy (msgbuf, "Host not found", size - 1);
      break;

    case WSA_INVALID_HANDLE:
      strncpy (msgbuf, "Specified event object handle is invalid", size - 1);
      break;

    case WSA_INVALID_PARAMETER:
      strncpy (msgbuf, "One or more parameters are invalid", size - 1);
      break;

    case WSA_IO_INCOMPLETE:
      strncpy (msgbuf, "Overlapped I/O event object not in signaled state", size - 1);
      break;

    case WSA_IO_PENDING:
      strncpy (msgbuf, "Overlapped operations will complete later", size - 1);
      break;

    case WSA_NOT_ENOUGH_MEMORY:
      strncpy (msgbuf, "Insufficient memory available", size - 1);
      break;

    case WSANOTINITIALISED:
      strncpy (msgbuf, "Successful WSAStartup not yet performed", size - 1);
      break;

    case WSANO_DATA:
      strncpy (msgbuf, "Valid name, no data record of requested type", size - 1);
      break;

    case WSANO_RECOVERY:
      strncpy (msgbuf, "This is a nonrecoverable error", size - 1);
      break;

    case WSASYSCALLFAILURE:
      strncpy (msgbuf, "System call failure", size - 1);
      break;

    case WSASYSNOTREADY:
      strncpy (msgbuf, "Network subsystem is unavailable", size - 1);
      break;

    case WSATRY_AGAIN:
      strncpy (msgbuf, "Non-authoritative host not found", size - 1);
      break;

    case WSAVERNOTSUPPORTED:
      strncpy (msgbuf, "Winsock.dll version out of range", size - 1);
      break;

    case WSAEDISCON:
      strncpy (msgbuf, "Graceful shutdown in progress", size - 1);
      break;

    case WSA_OPERATION_ABORTED:
      strncpy (msgbuf, "Overlapped operation aborted", size - 1);
      break;

    default:
      msgbuf[0] = 0;
    }
  msgbuf[size - 1] = 0;
#else
  msg_len = strlen (strerror (saved_errno));
  if (!msgbuf || size < 1)
    return;
  if (msg_len > size - 1)
    msg_len = size - 1;
  if (msg_len > 0)
    memcpy (msgbuf, strerror (saved_errno), msg_len);
  msgbuf[msg_len] = 0;
#endif
}


#ifdef _SSL

/* SSL support */
static int
sslses_read (session_t * ses, char *buffer, int n_bytes)
{
  int n_in;
  if (ses->ses_class == SESCLASS_UNIX)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
      return 0;
    }
  ses->ses_status = 0;
  SESSTAT_SET (ses, SST_OK);
  n_in = SSL_read ((SSL *) (ses->ses_device->dev_connection->ssl), buffer, n_bytes);
  if (n_in <= 0)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
    }
  ses->ses_bytes_read = n_in;
  return (n_in);
}


static int
sslses_write (session_t * ses, char *buffer, int n_bytes)
{
  int n_out;
  if (ses->ses_class == SESCLASS_UNIX)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
      return 0;
    }
  SESSTAT_SET (ses, SST_OK);
  SESSTAT_CLR (ses, SST_BLOCK_ON_WRITE);
  n_out = SSL_write ((SSL *) (ses->ses_device->dev_connection->ssl), buffer, n_bytes);
  if (n_out <= 0)
    {
      SESSTAT_CLR (ses, SST_OK);
      SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
    }
  ses->ses_bytes_written = n_out;
  return (n_out);
}


static int
ssldev_free (device_t * dev)
{
  dbg_printf_1 (("tcpdev_free."));

  if ((dev == NULL) || (dev->dev_check != TCP_CHECKVALUE))
    {
      dbg_printf_2 (("SER_ILLSESP"));
      return (SER_ILLSESP);
    }

  SSL_free ((SSL *) dev->dev_connection->ssl);
  free ((char *) dev->dev_address);
  free ((char *) dev->dev_connection);
  free ((char *) dev->dev_funs);
  free ((char *) dev->dev_accepted_address);

  /* Set the check-field anything but TCP_CHECKVALUE */
  dev->dev_check = TCP_CHECKVALUE - 9;

  free ((char *) dev);
  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


caddr_t
tcpses_get_ssl (session_t * ses)
{
  return ((caddr_t) (ses->ses_device->dev_connection->ssl));
}


void *
tcpses_get_sslctx (session_t * ses)
{
  if (ses && ses->ses_device && ses->ses_device->dev_connection)
    return ((ses->ses_device->dev_connection->ssl_ctx));
  return NULL;
}


void
tcpses_set_sslctx (session_t * ses, void *ssl_ctx)
{
  if (ses->ses_class == SESCLASS_UNIX)
    return;
  if (ses && ses->ses_device && ses->ses_device->dev_connection)
    ses->ses_device->dev_connection->ssl_ctx = ssl_ctx;
  return;
}


void
sslses_to_tcpses (session_t * ses)
{
  if (ses->ses_class == SESCLASS_UNIX)
    return;
  if (ses->ses_device->dev_connection->ssl)
    SSL_free ((SSL *) (ses->ses_device->dev_connection->ssl));
  ses->ses_device->dev_funs->dfp_read = tcpses_read;
  ses->ses_device->dev_funs->dfp_write = tcpses_write;
  ses->ses_device->dev_funs->dfp_free = tcpdev_free;
  ses->ses_device->dev_connection->ssl = NULL;
  ses->ses_device->dev_connection->ssl_ctx = NULL;
}


void
tcpses_to_sslses (session_t * ses, void *s_ssl)
{
  if (ses->ses_class == SESCLASS_UNIX)
    return;
  ses->ses_device->dev_funs->dfp_read = sslses_read;
  ses->ses_device->dev_funs->dfp_write = sslses_write;
  ses->ses_device->dev_funs->dfp_free = ssldev_free;
  ses->ses_device->dev_connection->ssl = (SSL *) s_ssl;
}


/* END SSL support*/
#endif


#ifdef COM_UNIXSOCK
static int
unixses_listen (session_t * ses)
{
  int s;
  int rc;
  address_t *uaddr;
  struct sockaddr_un *p_addr;
  dbg_printf_1 (("unixses_listen."));

  SESSTAT_CLR (ses, SST_OK);

  uaddr = ses->ses_device->dev_address;
  p_addr = &(uaddr->a_serveraddr.u);

  unlink (p_addr->sun_path);
  if ((s = socket (AF_UNIX, SOCK_STREAM, 0)) < 0)
    {
      test_eintr (ses, s, errno);
      dbg_perror ("socket()");
      return (SER_NOREC);
    }

  dbg_printf_2 (("Created unix socket %d", s));

  ses->ses_device->dev_connection->con_s = s;

  dbg_printf_2 (("Calling bind: s=%d, addr=%s, len=%d", s, p_addr->sun_path, sizeof (saddrun_t)));

  rc = ses_control_all (ses);
  if (rc != SER_SUCC)
    {
      dbg_printf_2 (("SER_CNTRL"));
      return (SER_CNTRL);
    }

  if ((rc = bind (s, (saddr_t *) p_addr, sizeof (saddrun_t))) < 0)
    {

      test_eintr (ses, rc, errno);
      dbg_perror ("bind()");
      return (SER_ILLADDR);
    }

  dbg_printf_2 (("Calling listen: s=%d, qlen=%d", s, LISTEN_QLEN));

  if ((rc = listen (s, LISTEN_QLEN)) < 0)
    {
      test_eintr (ses, rc, errno);
      dbg_perror ("listen()");

#ifdef PCTCP
      if (errno != WSAEINPROGRESS)
#endif
	return (SER_SYSCALL);
    }

  dbg_printf_2 (("listen OK"));

  dbg_printf_2 (("setting status"));
  SESSTAT_SET (ses, SST_LISTENING);
  SESSTAT_SET (ses, SST_OK);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


static int
unixses_set_address (session_t * ses, char *addrinfo1)
{
  saddrun_t *p_addr;		/* address information */
  address_t *uaddr;

  uaddr = ses->ses_device->dev_address;
  p_addr = &(uaddr->a_serveraddr.u);
  SESSTAT_CLR (ses, SST_OK);

  memset (p_addr, '\0', sizeof (saddrun_t));
  p_addr->sun_family = AF_UNIX;
  strncpy (p_addr->sun_path, addrinfo1, sizeof (p_addr->sun_path));
  p_addr->sun_path[sizeof (p_addr->sun_path) - 1] = 0;
  SESSTAT_SET (ses, SST_OK);
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              unixses_accept
 *
 * Listening session accepts a new connection by calling this function.
 * session_accept() should be called when the status of listening session
 * is SST_CONNECT_PENDING.
 * The mode of new accepted session is set according to current control
 * fields in session structure.
 *
 * Input params :
 *
 *      ses         - listening session pointer
 *
 * Output params: the status of ses and new_ses is updated
 *
 *      new_ses - pointer to new session to be
 *
 * Return value :
 *
 *      SER_SUCC
 *      SER_ILLSESP  illegal session pointer or not a listening session,
 *                   no action taken
 *      SER_SYSCALL  accept failed, check errno
 *      SER_CNTRL    control failed
 *
 * Limitations  : Works only for session that is already in
 *                listening state i.e. tcpses_listen is called
 *
 * Globals used : none
 */
static int
unixses_accept (session_t * ses, session_t * new_ses)
{
  int rc;
  int new_socket;
  socklen_t addrlen = sizeof (saddrun_t);

  dbg_printf_1 (("unixses_accept."));

  TCP_CHK (ses);
  TCP_CHK (new_ses);

  if (!SESSTAT_ISSET (ses, SST_LISTENING))
    {
      /* If this is not a listening session,
         we should not do an accept */
      return (SER_ILLSESP);
    }

  SESSTAT_SET (new_ses, SST_BROKEN_CONNECTION);

  /* Clear the SST_OK fields first. If everything succeeds,
     set them again before returning */
  SESSTAT_CLR (ses, SST_OK);
  SESSTAT_CLR (new_ses, SST_OK);

  new_socket = accept (ses->ses_device->dev_connection->con_s,
	(struct sockaddr *) &(new_ses->ses_device->dev_connection->con_clientaddr.u),
	&addrlen);

  if (new_socket < 0)
    {
      /* Something went wrong */
      dbg_perror ("accept()");
      test_eintr (ses, new_socket, errno);
      return (SER_SYSCALL);
    }

  new_ses->ses_device->dev_connection->con_s = new_socket;

  rc = ses_control_all (new_ses);
  if (rc != SER_SUCC)
    {
      dbg_printf_2 (("SER_CNTRL"));
      return (SER_CNTRL);
    }

  memcpy (new_ses->ses_device->dev_accepted_address, ses->ses_device->dev_address, sizeof (address_t));

  /* Mark new session as connected */
  SESSTAT_CLR (new_ses, SST_BROKEN_CONNECTION);
  SESSTAT_SET (new_ses, SST_OK);

  SESSTAT_CLR (ses, SST_CONNECT_PENDING);
  SESSTAT_SET (ses, SST_OK);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              unixses_connect
 *
 * Connects allocated session to a previously specified server process.
 * The server can be specified by function tcpses_setaddr.
 * The mode of new connected session is set according to current control
 * fields in session structure.
 *
 * Input params :
 *
 *      ses     - session pointer
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC     connection established
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_SYSCALL  connect() failed, address was invalid or the server
 *                   process is down. Check errno
 *      SER_NOREC    socket creation failed, maybe too many open sockets
 *      SER_CNTRL    control failed
 *
 * Limitations  :
 *
 * Globals used : none
 */
static int
unixses_connect (session_t * ses)
{
  address_t *uaddr;
  saddrun_t *p_addr;		/* shortcut to address information */
  int s;
  int rc;

  dbg_printf_1 (("unixses_connect."));

  /* First, init status fields so that if something fails we
     can return immediately */

  SESSTAT_CLR (ses, SST_OK);
  SESSTAT_SET (ses, SST_BROKEN_CONNECTION);
  SESSTAT_SET (ses, SST_NO_PARTNER);


  uaddr = ses->ses_device->dev_address;
  p_addr = &(uaddr->a_serveraddr.u);

  /* Create a socket */
  if ((s = socket (AF_UNIX, SOCK_STREAM, 0)) < 0)
    {
      test_eintr (ses, s, errno);
      dbg_perror ("socket()");
      return (SER_NOREC);
    }

  ses->ses_device->dev_connection->con_s = -1;

  /* Connect to the server */
#ifdef ERESTARTSYS
  while ((rc = connect (s, (struct sockaddr *) p_addr, sizeof (saddrun_t))) < 0)
    {
      if (errno != SYS_EWBLK && errno != ERESTARTSYS)
	break;
    }
  if (rc < 0)
    {
#else
  if ((rc = connect (s, (struct sockaddr *) p_addr, sizeof (struct sockaddr_un))) < 0)
    {
#endif
      test_eintr (ses, rc, errno);
      dbg_perror ("connect()");
      dbg_printf_2 (("SER_SYSCALL"));
      closesocket (s);
      return (SER_SYSCALL);
    }

  ses->ses_device->dev_connection->con_s = s;

  rc = ses_control_all (ses);
  if (rc != SER_SUCC)
    {
      dbg_printf_2 (("SER_CNTRL"));
      return (SER_CNTRL);
    }

  /* The connecting succeeded, now we set the status bits correctly */
  SESSTAT_SET (ses, SST_OK);
  SESSTAT_CLR (ses, SST_BROKEN_CONNECTION);
  SESSTAT_CLR (ses, SST_NO_PARTNER);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              unixses_disconnect
 *
 * Breaks a connection.
 *
 * Input params :
 *
 *      ses     -
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC     connection closed successfully
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_SYSCALL  connection marked broken but some resources may not
 *                   have been fully deallocated
 *
 * Limitations  :
 *
 * Globals used :
 */
static int
unixses_disconnect (session_t * ses)
{
  int rc;
  address_t *uaddr;
  saddrun_t *p_addr;		/* shortcut to address information */

  dbg_printf_1 (("unixses_disconnect."));

  SESSTAT_CLR (ses, SST_OK);

  uaddr = ses->ses_device->dev_address;
  p_addr = &(uaddr->a_serveraddr.u);

  /* Close the connected socket */
  rc = closesocket (ses->ses_device->dev_connection->con_s);
  ses->ses_device->dev_connection->con_s = -1;

  /* Whether close succeeded or not, the connection will be
     unusable after the following */

  SESSTAT_SET (ses, SST_BROKEN_CONNECTION);

  /* unlink the socket file if listening socket is closing */
  if (SESSTAT_ISSET (ses, SST_LISTENING))
    unlink (p_addr->sun_path);

  memset (ses->ses_device->dev_accepted_address, 0, sizeof (address_t));

  if (rc < 0)
    {
      dbg_perror ("close()");
      test_eintr (ses, rc, errno);
      dbg_printf_2 (("SER_SYSCALL"));
      return (SER_SYSCALL);
    }

  SESSTAT_SET (ses, SST_OK);

  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              unixdev_free
 *
 * Function for deallocating device instance after use.
 *
 * Input params :
 *
 *      ses     - device pointer returned by tcpdev_allocate
 *
 * Output params: - none
 *
 * Return value : SER_SUCC
 *                SER_ILLSESP
 *
 * Limitations  : Does not disconnect the session, use tcpses_disconnect
 *                before calling tcpdev_free
 *
 * Globals used : - none
 */
static int
unixdev_free (device_t * dev)
{
  dbg_printf_1 (("unixdev_free."));

  if ((dev == NULL) || (dev->dev_check != TCP_CHECKVALUE))
    {
      dbg_printf_2 (("SER_ILLSESP"));
      return (SER_ILLSESP);
    }

  free ((char *) dev->dev_address);
  free ((char *) dev->dev_connection);
  free ((char *) dev->dev_funs);
  free ((char *) dev->dev_accepted_address);

  /* Set the check-field anything but TCP_CHECKVALUE */
  dev->dev_check = TCP_CHECKVALUE - 9;

  free ((char *) dev);
  dbg_printf_2 (("SER_SUCC."));
  return (SER_SUCC);
}


/*##**********************************************************************
 *
 *              unixdev_allocate
 *
 * Function used for allocating and initializing a new unix sockets device instance.
 * Use unixdev_free for deallocating.
 *
 * Input params :        - none
 *
 * Output params:    - none
 *
 * Return value :    pointer to new session instance
 *
 * Limitations  :
 *
 * Globals used :    default controls
 */
device_t *
unixdev_allocate ()
{
  device_t *dev = (device_t *) malloc (sizeof (device_t));
  devfuns_t *devfuns = (devfuns_t *) malloc (sizeof (devfuns_t));
  address_t *addr = (address_t *) malloc (sizeof (address_t));
  address_t *accepted_addr = (address_t *) malloc (sizeof (address_t));
  connection_t *con = (connection_t *) malloc (sizeof (connection_t));
  memset (con, 0, sizeof (*con));
  memset (accepted_addr, 0, sizeof (address_t));
  dbg_printf_1 (("unixdev_allocate."));

  ss_assert (dev != NULL);
  ss_assert (devfuns != NULL);
  ss_assert (addr != NULL);
  ss_assert (con != NULL);

  /* Initialize pointers */
  dev->dev_address = (address_t *) addr;
  dev->dev_connection = con;
  dev->dev_funs = devfuns;
  dev->dev_accepted_address = (address_t *) accepted_addr;

  dev->dev_check = TCP_CHECKVALUE;

  /* Set tcpip methods */
  dev->dev_funs->dfp_allocate = unixdev_allocate;
  dev->dev_funs->dfp_free = unixdev_free;

  dev->dev_funs->dfp_set_address = unixses_set_address;
  dev->dev_funs->dfp_listen = unixses_listen;
  dev->dev_funs->dfp_accept = unixses_accept;
  dev->dev_funs->dfp_connect = unixses_connect;
  dev->dev_funs->dfp_disconnect = unixses_disconnect;
  dev->dev_funs->dfp_read = tcpses_read;
  dev->dev_funs->dfp_write = tcpses_write;
  dev->dev_funs->dfp_set_control = tcpses_set_control;
  dev->dev_funs->dfp_get_control = NULL;

  return (dev);
}


dk_session_t *
tcpses_make_unix_session (char *address)
{
  dk_session_t *session = NULL;
  char temp[100];
  int port = 0, rc;

  if (alldigits (address))
    port = atoi (address);
  else if (!strncmp (address, "localhost:", sizeof ("localhost:") - 1))
    port = atoi (strchr (address, ':') + 1);

  if (port)
    {
      snprintf (temp, sizeof (temp), UNIXSOCK_ADD_ADDR "%d", port);
      session = dk_session_allocate (SESCLASS_UNIX);
      PrpcSessionResetTimeout (session);
      rc = session_set_address (session->dks_session, temp);
      if (rc != SER_SUCC)
	{
	  PrpcSessionFree (session);
	  session = NULL;
	}
    }
  return session;
}


#else
dk_session_t *
tcpses_make_unix_session (char *address)
{
  return NULL;
}
#endif
