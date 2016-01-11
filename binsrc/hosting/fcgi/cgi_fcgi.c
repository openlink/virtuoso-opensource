/*
 *  cgi_fcgi.c
 *
 *  $Id$
 *
 *  Virtuoso FastCGI hosting plugin fcgi iface
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "import_gate_virtuoso.h"
#include "hosting_fcgi.h"

#include <fastcgi.h>
#include <fcgios.h>
#include <fcgiapp.h>

#define VFC_TRACE
#ifdef VFC_TRACE
#define vfc_printf(x) printf x
#define dbg_dump_req(req) dbg_dump_req_impl (req)
#else
#define vfc_printf(x)
#define call_dbg_dump_req(req)
#endif

typedef enum { VFCS_ALLOCATED, VFCS_STARTED, VFCS_OPERATIONAL } vfcs_state_t;

static id_hash_t *vfc_server_hash = NULL;
static dk_mutex_t *vfc_server_mutex = NULL;

static int fcgi_n_servers = 1;
static char * fcgi_socket_path = "/home/ztashev/tmp";

typedef struct vfc_fcgi_srv_s
{
  vfcs_state_t state;
  dk_mutex_t *mtx;
  caddr_t uri;
  int n_servers;
  char bind_path [MAXPATHLEN];

  int next_req_id;
  dk_set_t requests;
} vfc_fcgi_srv_t;


typedef struct vfc_fcgi_req_s
{
  vfc_fcgi_srv_t *srv;
  int id;
  dk_session_t *ses;
  const char **env_array;
  int n_env_array;
  const char *body;
  int n_body;
  dk_session_t *err_ses, *out_ses;
  int exit_status;
  int done;

  /* request processing parts */
  int body_ofs;
  int out_head_ofs;
  FCGI_Header header;
  FCGI_Header out_head;
  FCGI_EndRequestBody er_body;
  int header_len;
  int body_len;
  int padding_len;
  int reading_end_request_body;
} vfc_fcgi_req_t;

#define VFC_REQ_DONE(req) \
  ((req)->done && !(req)->padding_len && (req)->body_ofs == (req)->n_body)

int
vfc_server_init (void)
{
  static volatile int server_initialized = 0;
  vfc_printf (("vfc_server_init\n"));

  if (server_initialized)
    return 1;

  vfc_server_hash = id_hash_allocate (30, sizeof (void *), sizeof (void *),
      strhash, strhashcmp);
  vfc_server_mutex = mutex_allocate ();
  server_initialized = 1;
  return 1;
}

static vfc_fcgi_srv_t *
vfc_fcgi_server_allocate (const char *base_uri, const char *bind_file, char *err, int max_len)
{
  vfc_fcgi_srv_t *srv = (vfc_fcgi_srv_t *) dk_alloc (sizeof (vfc_fcgi_srv_t));
  caddr_t md5_val = NULL;

  vfc_printf (("vfc_fcgi_server_allocate base_uri=[%s] bind_file=[%s]\n",
	base_uri,bind_file));
  memset (srv, 0, sizeof (vfc_fcgi_srv_t));
  srv->state = VFCS_ALLOCATED;
  srv->uri = box_dv_short_string (base_uri);
  srv->mtx = mutex_allocate ();
  srv->n_servers = fcgi_n_servers;
  if (!bind_file)
    md5_val = md5 (srv->uri);
  vfc_printf (("vfc_fcgi_server_allocate md5_val=[%s] \n", md5_val));
  snprintf (srv->bind_path, sizeof (srv->bind_path), "%s/%s",
      fcgi_socket_path, bind_file ? bind_file : md5_val);
  id_hash_set (vfc_server_hash, (caddr_t) &srv->uri, (caddr_t) &srv);
  dk_free_box (md5_val);
  vfc_printf (("vfc_fcgi_server_allocate ret =%p\n",
	srv));
  vfc_printf ((" 2 vfc_fcgi_server_allocate base_uri=[%s] bind_file=[%s]\n",
	base_uri,bind_file));
  return srv;
}


static short
getPort(const char * bindPath)
{
    short port = 0;
    char * p = strchr(bindPath, ':');

    if (p && *++p)
    {
        char buf[6];

        strncpy(buf, p, 6);
        buf[5] = '\0';

        port = (short) atoi(buf);
    }

    return port;
}

#ifndef WIN32
static char * const *
vfc_spawn_make_env (const char **env_array, int n_env_array)
{
  int inx;
  char ** env = (char **) malloc ((n_env_array / 2 + 1) * sizeof (char *));

  for (inx = 0; inx < n_env_array; inx += 2)
    {
      /* 2 for the eq and the null */
      env[inx / 2] = (char *) malloc (strlen (env_array[inx]) + strlen (env_array[inx + 1]) + 2);
      sprintf (env[inx / 2], "%s=%s", env_array[inx], env_array[inx + 1]);
    }
  env[n_env_array / 2] = NULL;
  return env;
}


/*
 *----------------------------------------------------------------------
 *
 * OS_SpawnChild --
 *
 *	Spawns a new FastCGI listener process.
 *
 * Results:
 *      0 if success, -1 if error.
 *
 * Side effects:
 *      Child process spawned.
 *
 *----------------------------------------------------------------------
 */
static int
vfc_OS_SpawnChild(char *appPath, int listenFd,
    const char **env_array, int n_env_array)
{
    int forkResult;

    forkResult = fork();
    if(forkResult < 0) {
        exit(errno);
    }

    if(forkResult == 0) {
        /*
         * Close STDIN unconditionally.  It's used by the parent
         * process for CGI communication.  The FastCGI applciation
         * will be replacing this with the FastCGI listenFd IF
         * STDIN_FILENO is the same as FCGI_LISTENSOCK_FILENO
         * (which it is on Unix).  Regardless, STDIN, STDOUT, and
         * STDERR will be closed as the FastCGI process uses a
         * multiplexed socket in their place.
         */
        close(STDIN_FILENO);

        /*
         * If the listenFd is already the value of FCGI_LISTENSOCK_FILENO
         * we're set.  If not, change it so the child knows where to
         * get the listen socket from.
         */
	vfc_printf (("after fork : listenFd=%d dup to %d appPath=[%s]\n",
	      listenFd, FCGI_LISTENSOCK_FILENO, appPath));
        if(listenFd != FCGI_LISTENSOCK_FILENO) {
            int rc = dup2(listenFd, FCGI_LISTENSOCK_FILENO);
	    vfc_printf (("after fork : dup returned %d\n", rc));
            close(listenFd);
        }

	close(STDOUT_FILENO);
	close(STDERR_FILENO);

        /*
	 * We're a child.  Exec the application.
	 */
	execle(appPath, appPath, NULL, vfc_spawn_make_env (env_array, n_env_array));
	exit(errno);
    }
    return 0;
}

#else

static LPVOID
vfc_spawn_make_env (const char **env_array, int n_env_array)
{
  char *ret, *ptr;
  int total_env_len, inx;

  /* total_env_len = 1 for the terminating null after all the envs */
  for (inx = 0, total_env_len = 1; inx < n_env_array; inx += 2)
    {
      /* 2 for the eq and the null */
      total_env_len += strlen (env_array[inx]) + strlen (env_array[inx + 1]) + 2;
    }
  ret = (char *)malloc (total_env_len);
  for (inx = 0, ptr = ret; inx < n_env_array; inx += 2)
    {
      sprintf (ptr, "%s=%s", env_array[inx], env_array[inx + 1]);
      /* after the terminating zero */
      ptr += strlen (ptr) + 1;
    }
  *ptr = 0;
  return (LPVOID) ret;
}


/*
 *----------------------------------------------------------------------
 *
 * OS_SpawnChild --
 *
 *	Spawns a new server listener process, and stores the information
 *      relating to the child in the supplied record.  A wait handler is
 *	registered on the child's completion.  This involves creating
 *        a process on NT and preparing a command line with the required
 *        state (currently a -childproc flag and the server socket to use
 *        for accepting connections).
 *
 * Results:
 *      0 if success, -1 if error.
 *
 * Side effects:
 *      Child process spawned.
 *
 *----------------------------------------------------------------------
 */
static int
vfc_OS_SpawnChild(char *execPath, int listenFd,
    const char **env_array, int n_env_array)
{
  STARTUPINFO StartupInfo;
  PROCESS_INFORMATION pInfo;
  BOOL success;

  memset((void *)&StartupInfo, 0, sizeof(STARTUPINFO));
  StartupInfo.cb = sizeof (STARTUPINFO);
  StartupInfo.lpReserved = NULL;
  StartupInfo.lpReserved2 = NULL;
  StartupInfo.cbReserved2 = 0;
  StartupInfo.lpDesktop = NULL;

  /*
   * FastCGI on NT will set the listener pipe HANDLE in the stdin of
   * the new process.  The fact that there is a stdin and NULL handles
   * for stdout and stderr tells the FastCGI process that this is a
   * FastCGI process and not a CGI process.
   */
  StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  /*
   * XXX: Do I have to dup the handle before spawning the process or is
   *      it sufficient to use the handle as it's reference counted
   *      by NT anyway?
   */
  StartupInfo.hStdInput  = fdTable[listenFd].fid.fileHandle;
  StartupInfo.hStdOutput = INVALID_HANDLE_VALUE;
  StartupInfo.hStdError  = INVALID_HANDLE_VALUE;

  /*
   * Make the listener socket inheritable.
   */
  success = SetHandleInformation(StartupInfo.hStdInput, HANDLE_FLAG_INHERIT,
      TRUE);
  if(!success)
    {
      return -1;
    }

  /*
   * XXX: Might want to apply some specific security attributes to the
   *      processes.
   */
  success = CreateProcess(execPath,	/* LPCSTR address of module name */
      NULL,           /* LPCSTR address of command line */
      NULL,		/* Process security attributes */
      NULL,		/* Thread security attributes */
      TRUE,		/* Inheritable Handes inherited. */
      0,		/* DWORD creation flags  */
      vfc_spawn_make_env (env_array, n_env_array), /* environment */
      NULL,		/* Address of current directory name */
      &StartupInfo,   /* Address of STARTUPINFO  */
      &pInfo);	/* Address of PROCESS_INFORMATION   */
  if(success)
    {
      return 0;
    }
  else
    {
      return -1;
    }
}

#endif



static int
vfc_FCGI_Start(char *bindPath, char *appPath, int nServers, char *err, int max_len,
    const char **env_array, int n_env_array)
{
  int listenFd, i;
  dk_session_t *ses;
  vfc_printf (("vfc_FCGI_Start started\n"));
  vfc_printf (("vfc_FCGI_Start [%s] \n", bindPath));

  if(access(appPath, X_OK) == -1)
    {
      snprintf(err, max_len, "%s is not executable", appPath);
      return 0;
    }

  ses = dk_session_allocate (getPort (bindPath) ? SESCLASS_TCPIP : SESCLASS_UNIX);
  if (!ses)
    return 0;
  if (SER_SUCC != session_set_address (ses->dks_session, bindPath))
    {
      vfc_printf (("vfc_FCGI_Start wrong addr\n"));
      PrpcSessionFree (ses);
      return 0;
    }
  if (SER_SUCC != session_listen (ses->dks_session))
    {
      vfc_printf (("vfc_FCGI_Start can't listen\n"));
      session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      return 0;
    }
  listenFd = tcpses_get_fd (ses->dks_session);
  /*
   * Create the server processes
   */
  for(i = 0; i < nServers; i++)
    {
      if(vfc_OS_SpawnChild(appPath, listenFd, env_array, n_env_array) == -1)
	{
	  vfc_printf (("vfc_FCGI_Start can't spawn\n"));
	  snprintf(err, max_len, "Error spawning child %d : %d\n", i, (int) OS_Errno);
	}
    }

  close (listenFd);
  PrpcSessionFree (ses);
  vfc_printf (("vfc_FCGI_Start returns=1\n"));
  return 1;
}


#ifndef VFC_ASSERT
#define VFC_ASSERT(assertion) assert(assertion)
#endif

static FCGI_Header
vfc_MakeHeader(
        int type,
        int requestId,
        int contentLength,
        int paddingLength)
{
    FCGI_Header header;
    vfc_printf (("vfc_MakeHeader type=%d req_id=%d, clen=%d, plen=%d\n",
	  type,requestId,contentLength,paddingLength));
    VFC_ASSERT(contentLength >= 0 && contentLength <= FCGI_MAX_LENGTH);
    VFC_ASSERT(paddingLength >= 0 && paddingLength <= 0xff);
    header.version = FCGI_VERSION_1;
    header.type             = (unsigned char) type;
    header.requestIdB1      = (unsigned char) ((requestId     >> 8) & 0xff);
    header.requestIdB0      = (unsigned char) ((requestId         ) & 0xff);
    header.contentLengthB1  = (unsigned char) ((contentLength >> 8) & 0xff);
    header.contentLengthB0  = (unsigned char) ((contentLength     ) & 0xff);
    header.paddingLength    = (unsigned char) paddingLength;
    header.reserved         =  0;
    return header;
}


static void
vfc_FCGIUtil_BuildNameValueHeader(
    int nameLen,
    int valueLen,
    unsigned char *headerBuffPtr,
    int *headerLenPtr)
{
  unsigned char *startHeaderBuffPtr = headerBuffPtr;

  vfc_printf (("vfc_FCGIUtil_BuildNameValueHeader nameLen=%d valueLen=%d\n",
	nameLen,valueLen));
  VFC_ASSERT(nameLen >= 0);
  if (nameLen < 0x80)
    {
      *headerBuffPtr++ = (unsigned char) nameLen;
    }
  else
    {
      *headerBuffPtr++ = (unsigned char) ((nameLen >> 24) | 0x80);
      *headerBuffPtr++ = (unsigned char) (nameLen >> 16);
      *headerBuffPtr++ = (unsigned char) (nameLen >> 8);
      *headerBuffPtr++ = (unsigned char) nameLen;
    }
  VFC_ASSERT(valueLen >= 0);
  if (valueLen < 0x80)
    {
      *headerBuffPtr++ = (unsigned char) valueLen;
    }
  else
    {
      *headerBuffPtr++ = (unsigned char) ((valueLen >> 24) | 0x80);
      *headerBuffPtr++ = (unsigned char) (valueLen >> 16);
      *headerBuffPtr++ = (unsigned char) (valueLen >> 8);
      *headerBuffPtr++ = (unsigned char) valueLen;
    }
  *headerLenPtr = headerBuffPtr - startHeaderBuffPtr;
  vfc_printf (("vfc_FCGIUtil_BuildNameValueHeader headerLenPtr=%d\n",
	*headerLenPtr));
}


/*
 *----------------------------------------------------------------------
 *
 * vfc_MakeBeginRequestBody --
 *
 *      Constructs an FCGI_BeginRequestBody record.
 *
 *----------------------------------------------------------------------
 */
static FCGI_BeginRequestBody
vfc_MakeBeginRequestBody(
        int role,
        int keepConnection)
{
  FCGI_BeginRequestBody body;

  vfc_printf (("vfc_MakeBeginRequestBody role=%d keep=%d\n",
	role,keepConnection));
  VFC_ASSERT((role >> 16) == 0);
  body.roleB1 = (unsigned char) ((role >>  8) & 0xff);
  body.roleB0 = (unsigned char) (role         & 0xff);
  body.flags  = (unsigned char) ((keepConnection) ? FCGI_KEEP_CONN : 0);
  memset(body.reserved, 0, sizeof(body.reserved));
  return body;
}


static int
vfc_fcgi_server_start (vfc_fcgi_srv_t *srv, char *err, int max_len,
    const char **env_array, int n_env_array)
{
  vfc_printf (("vfc_fcgi_server_start srv=%p\n",
	srv));
  if (srv->state != VFCS_ALLOCATED)
    return 1;

  if (vfc_FCGI_Start (srv->bind_path, srv->uri, srv->n_servers, err, max_len,
	env_array, n_env_array))
    srv->state = VFCS_STARTED;
  else
    return 0;

  vfc_printf (("vfc_fcgi_server_start done\n"));
  return 1;
}

static dk_session_t *
vfc_fcgi_server_connect (vfc_fcgi_srv_t *srv, char *err, int max_len)
{
  int port;
  dk_session_t *ses;

  vfc_printf (("vfc_fcgi_server_connect srv=%p\n",
	srv));
  if (srv->state != VFCS_STARTED)
    return NULL;

  port = getPort (srv->bind_path);
  if (port)
    ses = dk_session_allocate (SESCLASS_TCPIP);
  else
    ses = dk_session_allocate (SESCLASS_UNIX);

  if (SER_SUCC != session_set_address (ses->dks_session, srv->bind_path))
    {
      snprintf (err, max_len, "Could not set the address %s", srv->bind_path);
      vfc_printf (("vfc_fcgi_server_connect wrong address\n"));
      PrpcSessionFree (ses);
      return NULL;
    }
  if (SER_SUCC != session_connect (ses->dks_session))
    {
      snprintf (err, max_len, "Could not connect to the address %s", srv->bind_path);
      vfc_printf (("vfc_fcgi_server_connect can't connect\n"));
      session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      return NULL;
    }

  srv->state = VFCS_OPERATIONAL;
  vfc_printf (("vfc_fcgi_server_connect done\n"));
  return ses;
}


/* searches/creates a FCGI server for the uri and connects to it if needed */
void *
vfc_find_fcgi_server (const char *base_uri, char *err, int max_len)
{
  vfc_fcgi_srv_t *srv = NULL, **ret;

  vfc_printf (("vfc_find_fcgi_server base_uri=[%s]\n", base_uri));
  mutex_enter (vfc_server_mutex);

  ret = (vfc_fcgi_srv_t **) id_hash_get (vfc_server_hash, (caddr_t) &base_uri);
  if (!ret)
    { /* dynamic ? fcgi server creation */
      srv = vfc_fcgi_server_allocate (base_uri, NULL, err, max_len);
    }
  else
    {
      srv = *ret;
    }

  mutex_leave (vfc_server_mutex);

  if (!srv)
    return NULL;

  vfc_printf (("vfc_find_fcgi_server srv=%p\n",
	srv));
  return srv;
}

void *
vfc_fcgi_request_create (void *_srv, char *err, int max_len,
    const char **options, int n_options,
    const char *params, int n_params)
{
  vfc_fcgi_srv_t *srv = (vfc_fcgi_srv_t *)_srv;
  vfc_fcgi_req_t *req = NULL;
  dk_session_t *ses;

  vfc_printf (("vfc_fcgi_request_create srv=%p\n",
	srv));
  mutex_enter (srv->mtx);

  if (!vfc_fcgi_server_start (srv, err, max_len, options, n_options))
    {
      mutex_leave (srv->mtx);
      vfc_printf (("vfc_fcgi_request_create srv=%p can't start\n",
	    srv));
      return NULL;
    }

  if (NULL == (ses = vfc_fcgi_server_connect (srv, err, max_len)))
    {
      mutex_leave (srv->mtx);
      vfc_printf (("vfc_fcgi_request_create srv=%p can't connect\n",
	    srv));
      return NULL;
    }

  req = dk_alloc (sizeof (vfc_fcgi_req_t));
  memset (req, 0, sizeof (vfc_fcgi_req_t));

  req->srv = srv;
  req->id = req->srv->next_req_id ++;
  req->ses = ses;
  req->env_array = options;
  req->n_env_array = n_options;
  req->body = params;
  req->n_body = n_params;
  req->out_ses = strses_allocate ();
  req->err_ses = strses_allocate ();
  req->out_head = vfc_MakeHeader(FCGI_STDIN, req->id, req->n_body, 0);

  dk_set_push (&req->srv->requests, req);
  mutex_leave (srv->mtx);

  vfc_printf (("vfc_fcgi_request_create srv=%p req=%p\n",
	srv, req));
  return req;
}


void
vfc_fcgi_request_free (void *_req)
{
  vfc_fcgi_req_t *req = (vfc_fcgi_req_t *)_req;

  vfc_printf (("vfc_fcgi_request_free req=%p\n",
	req));
  mutex_enter (req->srv->mtx);
  dk_set_delete (&req->srv->requests, req);
  mutex_leave (req->srv->mtx);

  dk_free_box (req->out_ses);
  dk_free_box (req->err_ses);

  dk_free (req, sizeof (vfc_fcgi_req_t));
}

static int
vfc_fcgi_request_send_envp (void *_req, char *err, int max_len,
    const char **options, int n_options)
{
  vfc_fcgi_req_t *req = (vfc_fcgi_req_t *) _req;
  int inx;
  FCGI_Header params_hdr;
  dk_session_t *ses = req->ses;

  vfc_printf (("vfc_fcgi_request_send_envp req=%p\n",
	req));
  session_flush_1 (ses);

  for (inx = 0; inx < n_options; inx += 2)
    {
      int header_len = 0;
      int name_len = strlen (options[inx]), value_len = strlen (options[inx + 1]);
      unsigned char header_buff[8];

      vfc_printf (("vfc_fcgi_request_send_envp req=%p sending [%s]=[%s]\n",
	    req, options[inx], options[inx + 1]));
      vfc_FCGIUtil_BuildNameValueHeader (
	  name_len, value_len,
          &(header_buff[0]),
          &header_len);
      session_buffered_write (ses, (char *) &header_buff[0], header_len);
      session_buffered_write (ses, options[inx], name_len);
      session_buffered_write (ses, options[inx + 1], value_len);
    }
  params_hdr = vfc_MakeHeader (FCGI_PARAMS, req->id, strses_length (ses), 0);

  session_buffered_write (req->ses, (char *) &params_hdr, sizeof (FCGI_Header));
  strses_write_out (ses, req->ses);

  /* make the eof record */
  params_hdr = vfc_MakeHeader (FCGI_PARAMS, req->id, 0, 0);
  session_buffered_write (req->ses, (char *) &params_hdr, sizeof (FCGI_Header));

  strses_flush (ses);
  vfc_printf (("vfc_fcgi_request_send_envp req=%p done\n",
	req));
  return 1;
}


#ifdef VFC_TRACE
static void
dbg_dump_req_impl (vfc_fcgi_req_t *req)
{
  vfc_printf (("dbg_dump_req req=%p\n", req));
  vfc_printf (("\tbody_ofs=%d\n", req->body_ofs));
  vfc_printf (("\tout_head_ofs=%d\n", req->out_head_ofs));
  vfc_printf (("\theader_len=%d\n", req->header_len));
  vfc_printf (("\tbody_len=%d\n", req->body_len));
  vfc_printf (("\tpadding_len=%d\n", req->padding_len));
  vfc_printf (("\treading_end_request_body=%d\n", req->reading_end_request_body));
  vfc_printf (("\t\n"));
  vfc_printf (("\tn_body=%d\n", req->n_body));
  vfc_printf (("\tdone=%d\n", req->done));
  vfc_printf (("\texit_status=%d\n", req->exit_status));
  vfc_printf (("\tsoh=%d\n", sizeof (req->out_head)));
  vfc_printf (("\tsob=%d\n", sizeof (req->er_body)));
}
#endif

static int
vfc_fcgi_request_do_io (vfc_fcgi_req_t *req, char *err, int max_len)
{
  int readed = 0;
  const char *write_buf = NULL;
  int write_len = 0, written = 0;

  /*dbg_dump_req (req);*/
  /* the write part */
  if (req->out_head_ofs < sizeof (req->out_head))
    { /* we must send a header for the data or a terminating one */
      write_buf = ((char *)&req->out_head) + req->out_head_ofs;
      write_len = sizeof (req->out_head) - req->out_head_ofs;
    }
  else if (req->body_ofs < req->n_body)
    { /* we have sent the header, now the data if any */
      write_buf = req->body + req->body_ofs;
      write_len = req->n_body - req->body_ofs;
    }

  if (write_len)
    {
      written = session_write (req->ses->dks_session, (char *) write_buf, write_len);
      vfc_printf (("vfc_fcgi_request_do_io req=%p writing %d: [%.*s] : wrote=%d\n",
	    req, write_len, write_len, write_buf, written));
    }
  else
    { /* no write : just wait for data to become available */
      int blocking = 1;
      if (session_set_control (req->ses->dks_session, SC_BLOCKING, (char *) &blocking, sizeof (blocking)))
	{
	  vfc_printf (("vfc_fcgi_request_do_io req=%p no more to write : error going blocking\n",
		req));
	  SET_ERR ("Cannot set the pipe to the worker function in blocking mode");
	  return -1;
	}
    }
  if (written < 0)
    {
      if (!SESSTAT_ISSET (req->ses->dks_session, SST_BLOCK_ON_WRITE))
	{
	  snprintf (err, max_len, "Error writing to the worker session : [%d] %s",
	      tcpses_get_last_w_errno(), sys_errlist[tcpses_get_last_w_errno()]);
	  vfc_printf (("vfc_fcgi_request_do_io req=%p error write [%d]=[%s]\n",
		req, tcpses_get_last_w_errno(), sys_errlist[tcpses_get_last_w_errno()]));
	  return -1;
	}
      else
	written = 0;
    }
  else if (written > 0)
    {
      if (req->out_head_ofs < sizeof (req->out_head))
	{ /* we must send a header for the data */
	  req->out_head_ofs += written;
	}
      else if (req->body_ofs < req->n_body)
	{ /* we have sent the header, now the data if any */
	  req->body_ofs += written;
	  if (req->body_ofs == written)
	    { /* done with the data : now make the termination header */
	      vfc_printf (("vfc_fcgi_request_do_io req=%p done with the data, make end header\n",
		    req));
	      req->out_head = vfc_MakeHeader(FCGI_STDIN, req->id, 0, 0);
	      req->out_head_ofs = 0;
	    }
	}
    }

  /* the read part */
  if (req->header_len < sizeof (req->header) && !req->done)
    {
      readed = session_read (req->ses->dks_session,
	  ((char *)&req->header) + req->header_len, sizeof (req->header) - req->header_len);
      if (readed < 0)
	{
	  if (!SESSTAT_ISSET (req->ses->dks_session, SST_BLOCK_ON_READ))
	    {
	      snprintf (err, max_len, "Error reading the FastCGI header from the worker session [%d]=[%s]",
		  tcpses_get_last_r_errno(), sys_errlist[tcpses_get_last_r_errno()]);
	      vfc_printf (("vfc_fcgi_request_do_io req=%p error header_read [%d]=[%s]\n",
		    req, tcpses_get_last_r_errno(), sys_errlist[tcpses_get_last_r_errno()]));
	      return -1;
	    }
	  else
	    readed = 0;
	}
      else if (readed > 0)
	{
	  vfc_printf (("vfc_fcgi_request_do_io req=%p head_read %d bytes readed=%d\n",
		req, sizeof (req->header) - req->header_len, readed));
	  req->header_len += readed;
	}

      if (req->header_len == sizeof (req->header))
	{
	  vfc_printf (("vfc_fcgi_request_do_io req=%p have a header ready\n",
		req));
	  if(req->header.version != FCGI_VERSION_1)
	    {
	      SET_ERR ("Unsipported version of the FastCGI protocol");
	      vfc_printf (("vfc_fcgi_request_do_io req=%p read unsup version\n",
		    req));
	      return FCGX_UNSUPPORTED_VERSION;
	    }
	  if ((req->header.requestIdB1 << 8) + req->header.requestIdB0 != req->id)
	    {
	      snprintf (err, max_len,
		  "FastFCI protocol error : unexpeced request ID : expecting %d, got %d",
		  req->id, (int) ((req->header.requestIdB1 << 8) + req->header.requestIdB0));
	      vfc_printf (("vfc_fcgi_request_do_io req=%p wrong seq %d, must be %d\n",
		    req, (int) ((req->header.requestIdB1 << 8) + req->header.requestIdB0), req->id));
	      return FCGX_PROTOCOL_ERROR;
	    }

	  req->body_len = (req->header.contentLengthB1 << 8) + req->header.contentLengthB0;
	  if (req->body_len < 0)
	    {
	      SET_ERR ("FastFCI protocol error : body len cannot be negative");
	      return FCGX_PROTOCOL_ERROR;
	    }
	  req->padding_len = req->header.paddingLength;
	  if (req->padding_len < 0)
	    {
	      SET_ERR ("FastFCI protocol error : padding len cannot be negative");
	      return FCGX_PROTOCOL_ERROR;
	    }
	  vfc_printf (("vfc_fcgi_request_do_io req=%p blen=%d plen=%d\n",
		req, req->body_len, req->padding_len));
	}
    }
  else if (req->body_len || req->padding_len)
    {
      char buffer[8192];
      int to_read;

      to_read = req->body_len ? req->body_len : req->padding_len;
      readed = 0;
      if (to_read)
	{
	  if (sizeof (buffer) < to_read)
	    to_read = sizeof (buffer);
	  readed = session_read (req->ses->dks_session, buffer, to_read);
	}
      if (readed < 0)
	{
	  if (!SESSTAT_ISSET (req->ses->dks_session, SST_BLOCK_ON_READ))
	    {
	      snprintf (err, max_len, "Error reading the FastCGI body from the worker session [%d]=[%s]",
		  tcpses_get_last_r_errno(), sys_errlist[tcpses_get_last_r_errno()]);
	      vfc_printf (("vfc_fcgi_request_do_io req=%p error body_read [%d]=[%s]\n",
		    req, tcpses_get_last_r_errno(), sys_errlist[tcpses_get_last_r_errno()]));
	      return -1;
	    }
	  else
	    readed = 0;
	}
      else if (readed > 0)
	{
	  vfc_printf (("vfc_fcgi_request_do_io req=%p body_read %d readed=%d\n",
		req, to_read, readed));
	}

      vfc_printf (("vfc_fcgi_request_do_io req=%p header.type=%d\n",
	    req, req->header.type));
      switch (req->header.type)
	{
	  case FCGI_STDOUT:
	  case FCGI_STDERR:
	      if (readed > 0 && req->body_len)
		{
		  vfc_printf (("vfc_fcgi_request_do_io req=%p write to %s=%d\n",
			req, req->header.type == FCGI_STDOUT ? "out" : "err", readed));
		  session_buffered_write (
		      req->header.type == FCGI_STDOUT ? req->out_ses : req->err_ses,
		      buffer, readed);
		}
	      break;

	  case FCGI_END_REQUEST:
	      if (!req->reading_end_request_body)
		{
		  if (req->body_len != sizeof (req->er_body))
		    {
		      snprintf (err, max_len,
			  "FastFCI protocol error : Wrong size for FCGI_END_REQUEST: expecting %d, got %d",
			  sizeof (req->er_body), req->body_len);
		      return FCGX_PROTOCOL_ERROR;
		    }
		  vfc_printf (("vfc_fcgi_request_do_io req=%p read_end_req_body=1\n",
			req));
		  req->reading_end_request_body = 1;
		}

	      if (readed > 0 && req->body_len > 0)
		{
		  memcpy (
		      ((char *)&req->er_body) + sizeof (req->er_body) - req->body_len,
		      buffer,
		      readed);
		  if ((req->body_len - readed) == 0)
		    {
		      req->exit_status = (req->er_body.appStatusB3 << 24)
			  + (req->er_body.appStatusB2 << 16)
			  + (req->er_body.appStatusB1 <<  8)
			  + (req->er_body.appStatusB0      );
		      req->done = 1;
		      vfc_printf (("vfc_fcgi_request_do_io req=%p read_end_req_body done\n",
			    req));
		    }
		}
	      break;

	  case FCGI_GET_VALUES_RESULT:
	  case FCGI_UNKNOWN_TYPE:
	  default:
	      SET_ERR ("FastCGI protocol error : unexpected header type");
	      return FCGX_PROTOCOL_ERROR;
	}
      if (readed > 0)
	{
	  if (req->body_len)
	    req->body_len -= readed;
	  else if (req->padding_len)
	    req->padding_len -= readed;
	}
      if (!req->body_len && !req->padding_len)
	{ /* package done : reset for the next one */
	  vfc_printf (("vfc_fcgi_request_do_io req=%p pack done\n",
		req));
	  req->header_len = 0;
	}
    }
  return 0;
}


int
vfc_fcgi_request_process (void *_req, char *err, int max_len)
{
  vfc_fcgi_req_t *req = (vfc_fcgi_req_t *) _req;
  FCGI_BeginRequestRecord begin_record;
  int rc, blocking;

  vfc_printf (("vfc_fcgi_request_process req=%p\n",
	req));
  CATCH_WRITE_FAIL (req->ses)
    {
      begin_record.header = vfc_MakeHeader(FCGI_BEGIN_REQUEST, req->id,
	  sizeof(begin_record.body), 0);
      begin_record.body = vfc_MakeBeginRequestBody(FCGI_RESPONDER, FALSE);
      session_buffered_write (req->ses, (char *) &begin_record, sizeof (begin_record));

      if (!vfc_fcgi_request_send_envp (req, err, max_len, req->env_array, req->n_env_array))
	{
	  END_WRITE_FAIL (req->ses);
	  return 0;
	}

      session_flush (req->out_ses);
      session_flush (req->ses);

    }
  FAILED
    {
      SET_ERR ("Error writing to the worker session");
      return -1;
    }
  END_WRITE_FAIL (req->ses);
  vfc_printf (("vfc_fcgi_request_process req=%p head sent\n",
	req));

  blocking = 0;
  if (session_set_control (req->ses->dks_session, SC_BLOCKING, (char *) &blocking, sizeof (blocking)))
    {
      SET_ERR ("Cannot set the pipe to the worker function in non-blocking mode");
      return 0;
    }

  do
    {
      rc = vfc_fcgi_request_do_io (req, err, max_len);
    }
  while (!rc && !VFC_REQ_DONE (req));
  vfc_printf (("vfc_fcgi_request_process req=%p finished\n",
	req));

  blocking = 1;
  session_set_control (req->ses->dks_session, SC_BLOCKING, (char *) &blocking, sizeof (blocking));

  return rc == 0 ? 1 : 0;
}


caddr_t
vfc_fcgi_request_get_output (void *_req, char **head_ret)
{
  caddr_t out, ret;
  char *head_sep;
  int head_sep_len;

  vfc_fcgi_req_t *req = (vfc_fcgi_req_t *) _req;

  out = strses_string (req->out_ses);

  vfc_printf (("vfc_fcgi_request_get_output req=%p out=[%s]\n",
	req, out));

  head_sep = strstr (out, "\n\r\n\r");
  head_sep_len = 4;
  if (!head_sep)
    {
      head_sep = strstr (out, "\n\n");
      head_sep_len = 2;
    }
  if (!head_sep)
    {
      *head_ret = NULL;
      vfc_printf (("vfc_fcgi_request_get_output req=%p no head sep\n",
	    req));
      return out;
    }
  ret = box_dv_short_string (head_sep + head_sep_len);
  *head_ret = dk_alloc_box (head_sep - out + 1, DV_STRING);
  strncpy (*head_ret, out, head_sep - out);
  dk_free_box (out);
  vfc_printf (("vfc_fcgi_request_get_output req=%p head=[%s] ret=[%s]\n",
	req, *head_ret, ret));
  return (ret);
}


caddr_t
vfc_fcgi_request_get_diag (void *_req)
{
  vfc_fcgi_req_t *req = (vfc_fcgi_req_t *) _req;
  caddr_t ret;

  ret = strses_string (req->err_ses);
  vfc_printf (("vfc_fcgi_request_get_diag req=%p diag_ret=[%s]\n",
	req, ret));
  return ret;
}

