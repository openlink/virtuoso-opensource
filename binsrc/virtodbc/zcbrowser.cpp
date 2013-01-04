/*
 *  zcbrowser.cpp
 *
 *  $Id$
 *
 *  Zero Config Browser (rendezvous)
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
 */

/*
 *  Implementation notes:
 *
 *  The locking mechanism used here was implemented because there can
 *  only be one TZCBrowser instance per process. This implementation uses
 *  references to the TZCPublication structure and an activation counter
 *  for StartBrowse.
 *  This ensures that multiple threads can look for ZC publications during
 *  their logon process.
 */

#include "w32util.h"
#include "zcbrowser.h"


static PTSTR
safe_dup (const char *str)
{
#ifndef UNICODE
  return str ? strdup (str) : NULL;

#else
  /* Our version of Rendezvous doesn't do unicode
   * maybe that'll change in the future, but we'll need to convert it for now
   */
  PTSTR copy;
  int len;

  if (!str)
    return NULL;

  len = MultiByteToWideChar (CP_ACP, NULL, str, -1, NULL, NULL);
  copy = (PTSTR) malloc (len * sizeof (TCHAR));
  if (copy)
    MultiByteToWideChar (CP_ACP, NULL, str, -1, copy, len);
  return copy;
#endif
}


static void
safe_free (PTSTR str)
{
  if (str)
    free (str);
}

#ifdef _RENDEZVOUS
void
DNSNetworkAddressToString (const DNSNetworkAddress *inAddr, PTSTR outString)
{
  unsigned int ip[4];

  ip[0] = (inAddr->u.ipv4.address >> 24) & 0xFF;
  ip[1] = (inAddr->u.ipv4.address >> 16) & 0xFF;
  ip[2] = (inAddr->u.ipv4.address >> 8) & 0xFF;
  ip[3] = (inAddr->u.ipv4.address >> 0) & 0xFF;

  if (inAddr->u.ipv4.port != kDNSPortInvalid)
    {
      _stprintf (outString, _T("%u.%u.%u.%u:%u"), ip[0], ip[1], ip[2], ip[3],
	  inAddr->u.ipv4.port);
    }
  else
    {
      _stprintf (outString, _T("%u.%u.%u.%u"), ip[0], ip[1], ip[2], ip[3]);
    }
}


static int
DNSNetworkAddressCompare (
    const DNSNetworkAddress *pAddr1,
    const DNSNetworkAddress *pAddr2)
{
  int i = -1;

  if (pAddr1->addressType == kDNSNetworkAddressTypeIPv4 &&
      pAddr2->addressType == kDNSNetworkAddressTypeIPv4)
    {
      i = pAddr1->u.ipv4.address - pAddr2->u.ipv4.address;
      if (i == 0)
        i = pAddr1->u.ipv4.port - pAddr2->u.ipv4.port;
    }

  return i;
}
#endif

TZCPublication::TZCPublication ()
{
  next = NULL;
  refCount = 1;
  szName = NULL;
  szType = NULL;
  szText = NULL;
  szDomain = NULL;
}


TZCPublication::~TZCPublication ()
{
  safe_free (szName);
  safe_free (szType);
  safe_free (szDomain);
  safe_free (szText);
}


void
TZCPublication::AddRef (void)
{
  InterlockedIncrement (&refCount);
}


void
TZCPublication::Unref (void)
{
  if (InterlockedDecrement (&refCount) == 0)
    delete this;
}


void
TZCBrowser::AddZCDomain (const char *szDomain)
{
#ifdef _RENDEZVOUS
  Lock ();
  if (m_activeCount == 0)
    {
      Unlock ();
      return;
    }
  m_bBrowsing = TRUE;
  Unlock ();
  DNSBrowserStartServiceSearch (
      m_DNS,
      kDNSBrowserFlagAutoResolve,
      OUR_RENDEZVOUS_TYPE,
      szDomain);
#endif
}


void
TZCBrowser::RegisterNotify (HWND hWnd, UINT uMsg, LPARAM lParam)
{
  TZCNotifier *p;

  p = new TZCNotifier;
  p->handle = hWnd;
  p->uMsg = uMsg;
  p->lParam = lParam;
  Lock ();
  p->next = m_pNotifiers;
  m_pNotifiers = p;
  Unlock ();
}


void
TZCBrowser::RegisterNotify (HANDLE hEvent)
{
  RegisterNotify ((HWND) hEvent, 0, 0);
}


void
TZCBrowser::UnregisterNotify (HANDLE h)
{
  TZCNotifier *p, *q, *n;

  q = NULL;
  Lock ();
  for (p = m_pNotifiers; p; p = n)
    {
      n = p->next;
      /* Compare the item keys */
      if (p->handle == h)
	{
	  if (q)
	    q->next = n;
	  else
	    m_pNotifiers = n;
	  delete p;
	}
      else
	q = p;
    }
  Unlock ();
}


void
TZCBrowser::DoNotify (void)
{
  TZCNotifier *p;

  Lock ();
  for (p = m_pNotifiers; p; p = p->next)
    {
      if (p->uMsg)
	PostMessage ((HWND) p->handle, p->uMsg, 0, p->lParam);
      else
	SetEvent (p->handle);
    }
  Unlock ();
}


/*
 *  Add an item to the listview.
 *  Removes duplicates and also takes care of updating aux. information.
 */
void
TZCBrowser::AddZCPublication (TZCPublication *pItem)
{
  TZCPublication *p, *q;

  /* Validate the entry */
  if (!pItem->szName || !pItem->szType)
    {
    skip_it:
      delete pItem;
      return;
    }
#ifdef _RENDEZVOUS
  if (pItem->eventType == kDNSBrowserEventTypeResolved &&
      (!pItem->szDomain || !pItem->szText))
    goto skip_it;

  /* Walk over all items in the list */
  Lock ();
  q = NULL;
  for (p = m_pItems; p; p = p->next)
    {
      /* Compare the item keys */
      if (!DNSNetworkAddressCompare (&p->interfaceAddr, &pItem->interfaceAddr) &&
	  !_tcscmp (p->szName, pItem->szName) &&
	  !_tcscmp (p->szType, pItem->szType) &&
	  !_tcscmp (p->szDomain, pItem->szDomain))
	{
	  /* Update/replace existing item */
	  pItem->next = p->next;
	  if (q)
	    q->next = pItem;
	  else
	    m_pItems = pItem;
	  p->Unref ();
	  Unlock ();
	  return;
	}
      q = p;
    }

  /* Add new item */
  pItem->next = m_pItems;
  m_pItems = pItem;
  Unlock ();
#endif
}

#ifdef _RENDEZVOUS
/*
 *  This is the callback procedure that gets invoked from the browser
 *  thread. It wraps up all event information and posts it to the
 *  browser's dialog window.
 */
static void
BrowserCallBack (
    void *inContext,
    DNSBrowserRef inRef,
    DNSStatus inStatusCode,
    const DNSBrowserEvent * inEvent)
{
  TZCBrowser *pBrowser = (TZCBrowser *) inContext;
  TZCPublication *pItem;

  switch (inEvent->type)
    {
    /* Domains */
    case kDNSBrowserEventTypeAddDomain:
    case kDNSBrowserEventTypeAddDefaultDomain:
      /* When we learn about a new domain, start browsing it */
      pBrowser->AddZCDomain (inEvent->data.addDomain.domain);
      break;

    /* Services */
    case kDNSBrowserEventTypeAddService:
      /* wait until it's resolved */
      break;

    /* Resolves */
    case kDNSBrowserEventTypeResolved:
      /* Only handle registrations for our types */
      if (!inEvent->data.resolved ||
	  !inEvent->data.resolved->type ||
	  strcmp (inEvent->data.resolved->type, OUR_RENDEZVOUS_TYPE))
	break;
      pItem = new TZCPublication;
      pItem->szName = safe_dup (inEvent->data.resolved->name);
      pItem->szType = safe_dup (inEvent->data.resolved->type);
      pItem->szDomain = safe_dup (inEvent->data.resolved->domain);
#ifdef _RENDEZVOUS
      pItem->eventType = inEvent->type;
      pItem->address = inEvent->data.resolved->address;
      pItem->interfaceAddr = inEvent->data.resolved->interfaceAddr;
#endif
      pItem->szText = safe_dup (inEvent->data.resolved->textRecord);
      pBrowser->AddZCPublication (pItem);
      pBrowser->DoNotify ();
      break;

    case kDNSBrowserEventTypeRemoveService:
      /* When we discover a change in service for our type, update the list
       * ok, I store deleted entries too - much simpler than deleting them
       */
      if (!inEvent->data.addService.type ||
	  strcmp (inEvent->data.addService.type, OUR_RENDEZVOUS_TYPE))
	break;
      pItem = new TZCPublication;
      pItem->szName = safe_dup (inEvent->data.addService.name);
      pItem->szType = safe_dup (inEvent->data.addService.type);
      pItem->szDomain = safe_dup (inEvent->data.addService.domain);
#ifdef _RENDEZVOUS
      pItem->eventType = inEvent->type;
      pItem->interfaceAddr = inEvent->data.addService.interfaceAddr;
#endif
      pBrowser->AddZCPublication (pItem);
      break;
    }
}
#endif


TZCBrowser::TZCBrowser ()
{
  InitializeCriticalSection (&m_csLock);

  m_activeCount = 0;
  m_bBrowsing = FALSE;
  m_pItems = NULL;
  m_bInitDone = FALSE;
}


TZCBrowser::~TZCBrowser ()
{
  if (m_bInitDone)
    {
#ifdef _RENDEZVOUS
      StopBrowse ();
#endif
      FreeItems ();
#ifdef _RENDEZVOUS
      DNSBrowserRelease (m_DNS, 0);
      DNSServicesFinalize ();
#endif
    }
  DeleteCriticalSection (&m_csLock);
}

#ifdef _RENDEZVOUS
void
TZCBrowser::StartBrowse (void)
{
  /* start looking for domains */
  Lock ();
  if (m_activeCount++ == 0)
    {
      if (!m_bInitDone)
	{
	  m_bInitDone = TRUE;
	  Unlock ();
	  DNSServicesInitialize (0, 512);
	  DNSBrowserCreate (0, BrowserCallBack, this, &m_DNS);
	}
      else
	Unlock ();
      DNSBrowserStartDomainSearch (m_DNS, 0);
    }
  else
    Unlock ();
}


void
TZCBrowser::StopBrowse (void)
{
  /* Stop the helper thread */
  Lock ();
  if ((!m_activeCount || --m_activeCount == 0) && m_bBrowsing)
    {
      m_bBrowsing = FALSE;
      Unlock ();
      DNSBrowserStopServiceSearch (m_DNS, 0);
    }
  else
    Unlock ();
}
#endif

void
TZCBrowser::FreeItems (void)
{
  TZCPublication *p, *q;
  TZCNotifier *n, *o;

  for (p = m_pItems; p; p = q)
    {
      q = p->next;
      p->Unref ();
    }
  m_pItems = NULL;

  for (n = m_pNotifiers; n; n = o)
    {
      o = n->next;
      delete n;
    }
  m_pNotifiers = NULL;
}


TZCPublication *
TZCBrowser::Resolve (LPCTSTR szServer, DWORD dwTimeout)
{
  TZCPublication *p, *pResolved;
  HANDLE hEvent;

  if (dwTimeout)
    {
      if ((hEvent = CreateEvent (NULL, FALSE, FALSE, NULL)) == NULL)
	return NULL;
      RegisterNotify (hEvent);
    }
  else
    hEvent = NULL;

  pResolved = NULL;
#ifdef _RENDEZVOUS
  StartBrowse ();
  for (;;)
    {
      Lock ();
      for (p = m_pItems; p; p = p->next)
	{
	  if (p->eventType == kDNSBrowserEventTypeResolved &&
	      !_tcsicmp (p->szName, szServer))
	    {
	      pResolved = p;
	      pResolved->AddRef ();
	      break;
	    }
	}
      Unlock ();

      if (pResolved ||
	  hEvent == NULL ||
          WaitForSingleObject (hEvent, dwTimeout) != WAIT_OBJECT_0)
	{
	  break;
	}
    }
  if (hEvent)
    {
      UnregisterNotify (hEvent);
      CloseHandle (hEvent);
    }
  StopBrowse ();
#endif
  return pResolved;
}


#ifdef TEST_ZCBROWSER
int
main ()
{
  TZCBrowser browser;
  TZCPublication *p;
  TCHAR szIP[60];

  if ((p = browser.Resolve ("Linux Virtuoso", 1000)) != NULL)
    {
      DNSNetworkAddressToString (&p->address, szIP);
      _putts (szIP);
    }
}
#endif
