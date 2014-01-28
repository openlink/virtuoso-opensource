/*
 *  Dksession.h
 *
 *  $Id$
 *
 *  Lower layer sessions
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

#ifndef _DKSESSION_H
#define _DKSESSION_H


/* Control parameters for a session */
typedef struct control_s control_t;

struct control_s
{
  int 			ctrl_blocking;		/* 1 if read/write blocking */
  timeout_t *		ctrl_timeout;		/* s+us value for read/write */
  int 			ctrl_msg_length;	/* max length of single message */
};

typedef struct strsestmpfile_s strsestmpfile_t;

typedef OFF_T (*ses_lseek_fn) (strsestmpfile_t *, OFF_T, int);
typedef size_t (*ses_read_fn) (strsestmpfile_t *, void *, size_t);
typedef size_t (*ses_wrt_fn) (strsestmpfile_t *, const void *, size_t);
typedef int (*ses_close_fn) (strsestmpfile_t *);

struct strsestmpfile_s
{
  int 			ses_max_blocks_in_mem;	/* max blocks in memory to use */
  int 			ses_max_blocks_init;
  int 			ses_file_descriptor;
  caddr_t 		ses_temp_file_name;
  OFF_T 		ses_fd_read;
  OFF_T 		ses_fd_fill;
  OFF_T 		ses_fd_fill_chars;
  OFF_T 		ses_fd_curr_char_pos;
  void *		ses_file_ctx;
  ses_lseek_fn		ses_lseek_func;
  ses_read_fn		ses_read_func;
  ses_wrt_fn		ses_wrt_func;
  ses_close_fn		ses_close_func;
  unsigned		ses_fd_is_stream:1;
};

/* General session object */
struct session_s
{
  /* internal info, TCPIP, NMP, ... */
  short 		ses_class;
  char 			ses_fduplex;		/* if set, use different status word for write ops */


  /* Return fields set by session_ functions */
  int 			ses_bytes_read;		/* updated by read */
  int 			ses_bytes_written;	/* updated by write */
  int 			ses_status;		/* single bit SST_ flags */
  int 			ses_w_status;		/* single bit SST_ flags for write is ses_fduplex is set */
  int 			ses_errno;
  int 			ses_w_errno;

  /* Properties set by session_set_control() */
  control_t *		ses_control;

  /* Device dependent part */
  device_t *		ses_device;

  /* This is reserved for two way link to struct of type dk_session_t. */
  void *		ses_client_data;

  int 			ses_reads;
  strsestmpfile_t *	ses_file;
};


/*
 *  Session status flags (ses_status)
 */
/* DANGER! sizeof(int) is processor dependent, so we just reserve 16 flags */
#define N_SSTBITS   		16
#define SSTBIT(n)   		(1 << ((n) % N_SSTBITS))

#define SST_OK                  SSTBIT(0)		   /* Previous operation successful */
#define SST_BLOCK_ON_WRITE      SSTBIT(1)		   /* Write would have blocked */
#define SST_BLOCK_ON_READ       SSTBIT(2)		   /* Read would have blocked */
#define SST_BROKEN_CONNECTION   SSTBIT(3)		   /* Remote party down / unreachable */
#define SST_TIMED_OUT           SSTBIT(4)		   /* Blocking oper timed out */
#define SST_NO_PARTNER          SSTBIT(5)		   /* No listener at given address */
#define SST_ADDR_USED           SSTBIT(6)		   /* Address used by another process */
#define SST_CONNECT_PENDING     SSTBIT(7)		   /* Client issued connect */
#define SST_INTERRUPTED         SSTBIT(8)		   /* oper interrupted by a signal */
#define SST_LISTENING           SSTBIT(9)		   /* this is a listening session */
#define SST_DISK_ERROR          SSTBIT(10)		   /* string session disk error when paging */

#define SST_NOT_OK 		(SST_BROKEN_CONNECTION|SST_TIMED_OUT|SST_NO_PARTNER|SST_ADDR_USED)
/* Do not use:
    if (! DKSESSTAT_ISSET ( future -> ft_server, SST_OK))
   Use instead:
    if (DKSESSTAT_ISSET ( future -> ft_server, SST_NOT_OK))
   Because SST_OK might not be updated correctly in all situations!
   (Which caused previously a lot of cut result set bugs with Linux).
 */



/*
 *  Macros for setting, clearing and testing session status flags
 */
#define SESSTAT_SET(ses, stat)     	((ses)->ses_status |= stat)
#define SESSTAT_CLR(ses, stat) 		((ses)->ses_status &= ~stat)
#define SESSTAT_ISSET(ses, stat)	((ses)->ses_status & stat)


#define SESSTAT_W_SET(ses, stat) \
  ((ses)->ses_fduplex ? ((ses)->ses_w_status |= stat) : SESSTAT_SET (ses, stat))

#define SESSTAT_W_CLR(ses, stat) \
  ((ses)->ses_fduplex ?  ((ses)->ses_w_status &= ~stat) : SESSTAT_CLR (ses, stat))

#define SESSTAT_W_ISSET(ses, stat) \
  ((ses)->ses_fduplex ? ((ses)->ses_w_status & stat) : SESSTAT_ISSET(ses, stat))


/*
 *  Return codes of session functions
 */
#define SER_SUCC     		0		   /* Operation succeeded */
#define SER_FAIL    		-1		   /* Operation failed, reason unspecified */
#define SER_ILLPRM		-2		   /* illegal parameter */
#define SER_ILLSESP		-3		   /* illegal session pointer */
#define SER_SYSCALL		-4		   /* System call failed */
#define SER_NOREC		-5		   /* no resources available */
#define SER_ILLADDR		-6		   /* illegal address specified */
#define SER_MSGSIZE		-7		   /* message was too long to be sent at once */
#define SER_CNTRL		-8		   /* mode controlling failed */
#define SER_ILLCL		-9		   /* unrecognized session class */
#define SER_INTR		-10		   /* external interrupt or signal */
#define SER_NOSUP		-11		   /* operation is not supported */

/*
 * Macros for specifying wanted action to session_control()
 */
#define SC_BLOCKING		1
#define SC_TIMEOUT		2
#define SC_MSGLEN		3

/* Macros defining default values for session's control fields */

#define SDC_BLOCKING    	1		   /* 1=yes, 0=no */
#define SDC_TIMEOUT     	{0, 0}		   /* sec, usec   */
#define SDC_MSGLEN      	0		   /* 0 = leave to OS */


/*
 *  Session functions
 */
session_t *session_allocate (int sesclass);
int session_free (session_t * ses);
EXE_EXPORT (int, session_set_address, (session_t * ses, char *addrinfo));
EXE_EXPORT (int, session_listen, (session_t * ses));
EXE_EXPORT (int, session_accept, (session_t * ses, session_t * new_ses));
EXE_EXPORT (int, session_connect, (session_t * ses));
EXE_EXPORT (int, session_disconnect, (session_t * ses));
EXE_EXPORT (int, session_write, (session_t * ses, char *buffer, int n_bytes));
EXE_EXPORT (int, session_read, (session_t * ses, char *buffer, int n_bytes));
EXE_EXPORT (int, session_select, (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout));
EXE_EXPORT (int, session_set_control, (session_t * ses, int field, char *p_value, int size));
int session_get_control (session_t * ses, int field, char *p_value, int size);
int session_set_default_control (int field, char *p_value, int size);
int session_get_default_control (int field, char *p_value, int size);

int utf8_align_memcpy (void *dst, const void *src, size_t len, size_t * pnwc, int *space_exausted);
OFF_T strf_lseek (strsestmpfile_t * sesfile, OFF_T offset, int whence);
size_t strf_read (strsestmpfile_t * sesfile, void *buf, size_t nbyte);

int fileses_read (session_t * ses, char *buffer, int n_bytes);
int tcpses_read (session_t * ses, char *buffer, int n_bytes);


#endif
