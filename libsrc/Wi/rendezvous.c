/*
 *  rendezvous.c
 *
 *  $Id$
 *
 *  Rendezvous registration for Virtuoso
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif


#ifdef _RENDEZVOUS

#include "libutil.h"
#include "mDNSClientAPI.h"
#include "mDNSPlatformFunctions.h"
#include "rendezvous.h"

#ifdef unix
# include "mDNSPosix.h"
#elif defined (WIN32)
# include "mDNSWin32.h"
#else
# error Unsupported configuration
#endif

/* maximum length for a dsn string
 * do not increase - depends on rendezvous packet structure
 */
#define MAX_DSN_LENGTH	255

/* maximum # tags in a dsn */
#define MAX_DSN_TAGS	50

/* dsn_tag.validity */
#define DSN_TOOLONG	-2	/* inclusion would cause dsn to be too long */
#define DSN_INVALID	-1	/* invalid tag, excluded */
#define DSN_VALID	0	/* valid tag, included */
#define DSN_DONTCARE	1	/* unknown tag, included + warn msg */
#define DSN_OBSOLETE	2	/* obsolete tag, included + warn msg */

#undef RVDEBUG

#ifndef N_
#define N_(X) X
#endif

typedef struct
  {
    char *key;
    int validity;
    char *value;
  } dsn_tag;

typedef struct rv_service_s
  {
    ServiceRecordSet coreServ;
    struct rv_service_s *next;
    int serviceID;
    char *name;
  } rv_service;

typedef struct rv_ctx_s
  {
    mDNS dns;
    mDNS_PlatformSupport platform;
    rv_service *services;
    int gServiceID;

#ifdef unix
    /* semaphore to sync between main + aux threads */
    semaphore_t *start_sema;
    thread_t *thr;
    int have_thread;
    int stop;
    int fd[2];
#endif
  } rv_ctx;

/* global list of publications */
dk_set_t zeroconfig_entries = NULL;
extern int lite_mode;

/* global rendezvous context */
static rv_ctx *_rv = NULL;

/*
 *  important: keep this list in sorted order
 *
 *  the 2nd column is used to tell about DSN tags that may never
 *  be passed to a client - they are explicitly filtered out
 *
 *  the 3rd column is used for the replacement key (if any)
 *  to correct common mistakes
 */
static dsn_tag dsn_tags[] =
  {
    { "Address",	DSN_INVALID, 	NULL },
    { "Charset",	DSN_VALID, 	NULL },
    { "Database",	DSN_VALID, 	NULL },
    { "Daylight",	DSN_VALID, 	NULL },
    { "DB",		DSN_VALID,	"Database" },
    { "Description",	DSN_INVALID,	NULL },
    { "Driver",		DSN_INVALID,	NULL },
    { "DSN",		DSN_INVALID,	NULL },
    { "Encrypt",	DSN_INVALID,	NULL },
    { "Host",		DSN_INVALID,	NULL },
    { "LastUser",	DSN_VALID,	"UID" },
    { "NoLoginBox",	DSN_VALID,	NULL },
    { "Password",	DSN_VALID,	"PWD" },
    { "Persist",	DSN_VALID,	NULL },
    { "PWD",		DSN_VALID,	NULL },
    { "PWDClearText",	DSN_VALID,	NULL },
    { "UID",		DSN_VALID,	NULL },
    { "User",		DSN_VALID,	"UID" },
    { "UserID",		DSN_VALID,	"UID" },
    { "UserName",	DSN_VALID,	"UID" },
    { "ZeroConf",	DSN_INVALID,	NULL },
  };


static void
dsn_entry_validate (dsn_tag *key)
{
  dsn_tag *last = &dsn_tags[sizeof (dsn_tags) / sizeof (dsn_tag)];
  dsn_tag *base = dsn_tags;
  dsn_tag *tag;
  int res;

  key->validity = DSN_INVALID;

  if (key->key == NULL || key->key[0] == 0 || key->value == NULL)
    return;

  /* bsearch for tag */
  while (base < last)
    {
      tag = &base[(int) ((last - base) >> 1)];
      if ((res = stricmp (key->key, tag->key)) == 0)
	{
	  key->validity = tag->validity;
	  key->key = tag->value ? tag->value : tag->key;
	  return;
	}
      if (res < 0)
        last = tag;
      else
        base = tag + 1;
    }

  key->validity = DSN_DONTCARE;
}


void
zeroconfig_reparse_dsn (zeroconfig_t *zc)
{
  dsn_tag tags[MAX_DSN_TAGS];
  char new_dsn[MAX_DSN_LENGTH + 1];
  dsn_tag *tag, *tag2;
  char *dsn;
  char *cp;
  int brlvl;
  int warned;
  size_t total_len;
  size_t len;

  dsn = zc->zc_dsn;

  /* unquote */
  if (dsn[0] == '"')
    {
      dsn++;
      len = strlen (dsn) - 1;
      if (dsn[len] == '"')
	dsn[len] = 0;
    }

  /* dissect */
  tag = tags;
  tag->key = dsn;
  tag->value = NULL;
  brlvl = 0;
  for (cp = dsn; *cp; cp++)
    {
      switch (*cp)
	{
	case ';':
	  if (brlvl == 0)
	    {
	      *cp = 0;
	      if (tag < &tags[MAX_DSN_TAGS])
		{
		  tag++;
		  tag->key = cp + 1;
		  tag->value = NULL;
		}
	      else
		cp--;
	    }
	  break;
	case '=':
	  if (brlvl == 0)
	    {
	      *cp = 0;
	      tag->value = cp + 1;
	    }
	  break;
	case '{':
	  brlvl++;
	  break;
	case '}':
	  brlvl--;
	  break;
	}
    }
  if (tag->key[0])
    tag++;

  /* check */
  for (tag2 = tags; tag2 < tag; tag2++)
    {
      dsn_entry_validate (tag2);
    }

  if (zc->zc_ssl && tag < &tag[MAX_DSN_TAGS])
    {
      tag->key = "Encrypt";
      tag->value = "1";
      tag->validity = DSN_VALID;
      tag++;
    }

  /* rewrite dsn */
  cp = new_dsn;
  total_len = 0;
  for (tag2 = tags; tag2 < tag; tag2++)
    {
      if (tag2->validity >= 0)
	{
	  len = strlen (tag2->key) + strlen (tag2->value) + 2;
	  if (total_len + len >= MAX_DSN_LENGTH)
	    tag2->validity = DSN_TOOLONG;
	  else
	    {
	      if (cp > new_dsn)
		*cp++ = ';';
	      cp = stpcpy (cp, tag2->key);
	      cp = stpcpy (cp, "=");
	      cp = stpcpy (cp, tag2->value);
	      total_len += len;
	    }
	}
    }
  *cp = 0;

  /* information */
  warned = 0;
  for (tag2 = tags; tag2 < tag; tag2++)
    {
      if (tag2->validity != DSN_VALID && !warned++)
	log (L_WARNING, "in the Zero Config publication for %s:", zc->zc_name);

      switch (tag2->validity)
	{
	case DSN_TOOLONG:
	  log (L_WARNING,
	      " the '%s' attribute exceeds the maximum allowed length",
	      tag2->key);
	  break;

	case DSN_INVALID:
	  if (tag2->key[0])
	    log (L_WARNING,
		" the '%s' attribute is not valid in this context",
		tag2->key);
	  break;

	case DSN_DONTCARE:
	  log (L_WARNING,
	      " the '%s' attribute was not recognized (probably incorrect)",
	      tag2->key);
	  break;

	case DSN_OBSOLETE:
	  log (L_WARNING,
	      " the '%s' attribute is obsolete",
	      tag2->key);
	  break;

	default:
	  break;
	}
    }

  dk_free_box (zc->zc_dsn);
  zc->zc_dsn = box_string (new_dsn);
  zc->zc_checked = 1;
}


#ifdef unix
static int
rendezvous_thread (void *arg)
{
  rv_ctx *ctx = (rv_ctx *) arg;
  int n;
  fd_set readfds;
  struct timeval timeout;
  int result;
  int wakeup;

#if defined (HAVE_PTHREAD_SIGMASK)
  sigset_t newset, oldset;

  /*
   *  This thread should not handle these signals
   */
  sigemptyset (&newset);
  sigaddset (&newset, SIGINT);
  sigaddset (&newset, SIGCHLD);
  sigaddset (&newset, SIGQUIT);
  sigaddset (&newset, SIGALRM);
  sigaddset (&newset, SIGTERM);
  pthread_sigmask (SIG_BLOCK, &newset, &oldset);
#endif

#ifdef RVDEBUG
  log (L_DEBUG, N_("ZeroConfig thread started"));
#endif

  ctx->have_thread = 1;
  semaphore_leave (ctx->start_sema);

  /* add read half of the wakeup pipe */
  wakeup = ctx->fd[0];

  mDNSPlatformLock (&ctx->dns);
  for (;;)
    {
      FD_ZERO (&readfds);

      timeout.tv_sec = 0x3FFFFFFF;
      timeout.tv_usec = 0;

      n = 0;
      FD_ZERO (&readfds);
      mDNSPosixGetFDSet (&ctx->dns, &n, &readfds, &timeout);
      if (ctx->stop && timeout.tv_sec > 1)
	break;

      FD_SET (wakeup, &readfds);
      if (n <= wakeup)
	n = wakeup + 1;

      mDNSPlatformUnlock (&ctx->dns);
      result = select (n, &readfds, NULL, NULL, &timeout);
      mDNSPlatformLock (&ctx->dns);

      if (result < 0)
	{
	  if (errno != EINTR)
	    break;
	  continue;
	}
      if (FD_ISSET (wakeup, &readfds))
	{
	  char c;
	  if (read (wakeup, &c, 1) != 1)
	    {
	      log (L_ERR, N_("ZeroConfig failure"));
	      break;
	    }
	  continue;
	}

      mDNSPosixProcessFDSet (&ctx->dns, result, &readfds);
    }
  mDNSPlatformUnlock (&ctx->dns);

#ifdef RVDEBUG
  log (L_DEBUG, N_("ZeroConfig thread stopped"));
#endif

  semaphore_leave (ctx->start_sema);
  ctx->have_thread = 0;

  return 0;
}


static void
notify_rendezvous_changed (rv_ctx *ctx)
{
  char c = 1;
  write (ctx->fd[1], &c, 1);
}

#else
# define notify_rendezvous_changed(X)
#endif


static void
RegistrationCallback (
    mDNS *const m,
    ServiceRecordSet *const thisRegistration,
    mStatus status)
{
  rv_service *thisServ;

  thisServ = (rv_service *) thisRegistration->Context;

  switch (status)
    {
    case mStatus_NoError:
      log (L_DEBUG, N_("ZeroConfig registration %s"), thisServ->name);
      break;

    case mStatus_NameConflict:
      log (L_WARNING, N_("** ZeroConfig name conflict on %s"), thisServ->name);
      break;

    case mStatus_MemFree:
#ifdef RVDEBUG
      log (L_DEBUG, N_("ZeroConfig revoke %s"), thisServ->name);
#endif
      dk_free_box (thisServ->name);
      dk_free (thisServ, sizeof (rv_service));
      break;

    default:
      log (L_ERR, N_("ZeroConfig registration %s failed (code %d)"),
	  thisServ->name, status);
      break;
    }
}


static int
rendezvous_register (
    void *arg,
    const char *serviceName,
    const char *serviceType,
    const char *domainName,
    const char *text,
    unsigned short portNumber)
{
  rv_ctx *ctx = (rv_ctx *) arg;
  mStatus status;
  mDNSOpaque16 port;
  domainlabel name;
  domainname type;
  domainname domain;
  size_t textLen;
  size_t maxTextLen;
  unsigned char dsnText[256];
  NEW_VARZ (rv_service, thisServ);

  thisServ->name = box_string (serviceName);
  status = mStatus_NoError;

  ConvertCStringToDomainLabel (serviceName, &name);
  ConvertCStringToDomainName (serviceType, &type);
  ConvertCStringToDomainName (domainName, &domain);
  port.b[0] = (portNumber >> 8) & 0x0FF;
  port.b[1] = (portNumber >> 0) & 0x0FF;;

  maxTextLen = sizeof (dsnText);
  textLen = strlen (text);
  if (textLen >= maxTextLen)
    {
      log (L_ERR,
      	  N_("the ZeroConfig registration for %s is too long (max. %d)"),
	  serviceName, (int) maxTextLen);
      textLen = maxTextLen - 1;
    }
  memcpy (&dsnText[1], text, textLen);
  dsnText[0] = (unsigned char) textLen;

  mDNSPlatformLock (&ctx->dns);
  status = mDNS_RegisterService (
      &ctx->dns, &thisServ->coreServ,
      &name, &type, &domain,
      NULL,
      port,
      dsnText, (unsigned short) textLen + 1,
      RegistrationCallback, thisServ);
  mDNSPlatformUnlock (&ctx->dns);

  if (status != mStatus_NoError)
    {
      dk_free_box (thisServ->name);
      dk_free (thisServ, sizeof (rv_service));
      return -1;
    }

  thisServ->serviceID = ctx->gServiceID;
  ctx->gServiceID += 1;

  thisServ->next = ctx->services;
  ctx->services = thisServ;

  return 0;
}


static void
register_services (rv_ctx *ctx)
{
  DO_SET (zeroconfig_t *, zc, &zeroconfig_entries)
    {
      if (!zc->zc_checked)
	zeroconfig_reparse_dsn (zc);
      if (zc->zc_checked)
	rendezvous_register (ctx,
	    zc->zc_name, "_virtuoso._tcp.", "local.", zc->zc_dsn, zc->zc_port);
    }
  END_DO_SET ();

  notify_rendezvous_changed (ctx);
}


int
reinit_rendezvous (void)
{
  rv_ctx *ctx = _rv;
  rv_service *thisServ;

  /* shutdown current registrations */
  mDNSPlatformLock (&ctx->dns);
  for (thisServ = ctx->services; thisServ; thisServ = thisServ->next)
    {
      mDNS_DeregisterService (&ctx->dns, &thisServ->coreServ);
      /*
       *  Note: we do not free thisServ here - rendezvous core
       *  still has references to it
       */
    }
  mDNSPlatformUnlock (&ctx->dns);
  ctx->services = NULL;

  register_services (ctx);

  return 0;
}


int
start_rendezvous (void)
{
  rv_ctx *ctx;
  mStatus status;

  /* Because the zc entries do not change when the server is started,
   * do not start the zc thread if there are no entries.
   * If future plans dictate to use reinit_rendezvous, remove this test
   */
  if (!zeroconfig_entries || lite_mode)
    return 0;

  ctx = (rv_ctx *) dk_alloc (sizeof (rv_ctx));
  memset (ctx, 0, sizeof (rv_ctx));
  ctx->gServiceID = 1;

#ifdef WIN32
  ctx->platform.advertise = mDNS_Init_AdvertiseLocalAddresses;
#endif

  status = mDNS_Init (
      &ctx->dns,
      &ctx->platform,
      mDNS_Init_NoCache,
      mDNS_Init_ZeroCacheSize,
      mDNS_Init_AdvertiseLocalAddresses,
      mDNS_Init_NoInitCallback,
      mDNS_Init_NoInitCallbackContext);

  if (status != mStatus_NoError)
    {
      dk_free (ctx, sizeof (rv_ctx));
      return -1;
    }

#ifdef unix
  /* Create a helper thread for RendezVous */
  if (pipe (ctx->fd) == -1)
    {
      dk_free (ctx, sizeof (rv_ctx));
      return -1;
    }
  ctx->start_sema = semaphore_allocate (0);
  ctx->thr = thread_create (rendezvous_thread, 0, ctx);
  semaphore_enter (ctx->start_sema);
#endif

  register_services (ctx);

  _rv = ctx;
  return 0;
}


int
stop_rendezvous (void)
{
  rv_ctx *ctx = _rv;

  if (!ctx)
    return -1;

  /* mDNS_Close sometimes hangs if there are no registered names */
  if (zeroconfig_entries)
    mDNS_Close (&ctx->dns);

#ifdef unix
  if (ctx->have_thread)
    {
      /* stop the thread + wait for it */
      ctx->stop = 1;
      notify_rendezvous_changed (ctx);
      semaphore_enter (ctx->start_sema);
    }
  semaphore_free (ctx->start_sema);
  close (ctx->fd[0]);
  close (ctx->fd[1]);
#endif

  dk_free (ctx, sizeof (rv_ctx));
  _rv = NULL;

  return 0;
}
#endif
