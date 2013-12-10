/*
 *  zcbrowsercombo.cpp
 *
 *  $Id$
 *
 *  ZeroConfig Browser Combo
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

#include "w32util.h"
#include "zcbrowsercombo.h"

/* This is a free running rendezvous browser */
TZCBrowser _zcbrowser;

TZCBrowserCombo::TZCBrowserCombo ()
{
  m_pResolvedZC = NULL;
  m_hMsgWnd = NULL;
#ifdef _RENDEZVOUS
  _zcbrowser.StartBrowse ();
#endif
}


TZCBrowserCombo::~TZCBrowserCombo ()
{
  if (m_pResolvedZC)
    m_pResolvedZC->Unref ();
  Clear ();
  if (m_hMsgWnd)
    _zcbrowser.UnregisterNotify (m_hMsgWnd);
#ifdef _RENDEZVOUS
  _zcbrowser.StopBrowse ();
#endif
}


void
TZCBrowserCombo::Attach (HWND hMsgWnd, HWND hOwnerWnd, DWORD dwResId, int len)
{
  TComboCtl::Attach (hOwnerWnd, dwResId, len);
  m_hMsgWnd = hMsgWnd;
  _zcbrowser.RegisterNotify (m_hMsgWnd, WM_ZCNOTIFY, (LPARAM) this);
}


/*
 *  Erases the content of the zeroconfig combo
 *  This is special code, because the combo holds references
 *  to ZCPublications that must be freed
 */
void
TZCBrowserCombo::Clear (void)
{
  TZCPublication *p;
  LPTSTR szValue;
  int iIndex;
  int iItems;

  szValue = Text ();
  iItems = Count ();
  for (iIndex = 0; iIndex < iItems; iIndex++)
    {
      p = (TZCPublication *) Data (iIndex);
      if (p && p != (TZCPublication *) CB_ERR)
	p->Unref ();
    }
  TComboCtl::Clear ();
  Text (szValue);
}


/*
 *  Called when the combo opens
 *  Shows all entries found so far
 */
void
TZCBrowserCombo::OnCbnDropDown (void)
{
  TZCPublication *p;
  TCHAR szText[512]; /* rendezvous doesn't use unicode */
  TCHAR szIP[60];
  int iIndex;

  Clear ();

#ifdef _RENDEZVOUS
  /* Add Items */
  _zcbrowser.Lock ();
  for (p = _zcbrowser.m_pItems; p; p = p->next)
    {
      if (p->eventType == kDNSBrowserEventTypeResolved)
	{
	  DNSNetworkAddressToString (&p->address, szIP);
	  _stprintf (szText, _T("%s (%s)"), p->szName, szIP);
	  iIndex = AddString (szText);
	  if (Data (iIndex, p) != CB_ERR)
	    p->AddRef ();
	}
    }
  _zcbrowser.Unlock ();
#endif
}


/*
 *  Called when the combo closes
 *  If the user selected another ZC dsn, use that now
 */
void
TZCBrowserCombo::OnCbnCloseUp (void)
{
  TZCPublication *p;
  int iIndex;

  if ((iIndex = CurSel ()) != CB_ERR)
    {
      if ((p = (TZCPublication *) Data (iIndex)) != NULL)
	{
	  p->AddRef ();
	  DidResolve (p);
	  p->Unref ();
	}
    }
}


/*
 *  Invalidates the remembered ZC association
 *  Called when the user types something in the combo
 *  This forces a re-resolve of the typed name
 */
void
TZCBrowserCombo::OnCbnEditChange (void)
{
  /* invalidate resolved publication */
  if (m_pResolvedZC)
    {
      m_pResolvedZC->Unref ();
      m_pResolvedZC = NULL;
    }
  TryResolve ();
}


void
TZCBrowserCombo::TryResolve (void)
{
  TZCPublication *p;
  LPTSTR szServer;

  if (m_pResolvedZC == NULL)
    {
      szServer = Text ();
      /* not a normal server name? */
      if (_tcschr (szServer, ':') == NULL)
	{
	  /* look it up in the publications found so far */
	  if ((p = _zcbrowser.Resolve (szServer, 0)) != NULL)
	    {
	      DidResolve (p);
	    }
	}
    }
}


void
TZCBrowserCombo::DidResolve (TZCPublication *p)
{
  if (m_pResolvedZC)
    m_pResolvedZC->Unref ();
  m_pResolvedZC = p;

  if (p)
    {
      p->AddRef ();
      Clear ();
      CurSel (AddString (p->szName));
    }
  SendMessage (m_hMsgWnd, WM_ZCRESOLVED, 0, 0);
}


BOOL
TZCBrowserCombo::IsResolved (void)
{
  return m_pResolvedZC != NULL;
}


LPCTSTR
TZCBrowserCombo::GetHost (void)
{
#ifdef _RENDEZVOUS
  if (m_pResolvedZC)
    {
      DNSNetworkAddressToString (&m_pResolvedZC->address, m_szText);
      return m_szText;
    }
#endif
  Text ();
  return _tcschr (m_szText, ':') ? m_szText : NULL;
}


LPCTSTR
TZCBrowserCombo::GetName (void)
{
  return m_pResolvedZC ? m_pResolvedZC->szName : NULL;
}


LPCTSTR
TZCBrowserCombo::GetDSN (void)
{
  return m_pResolvedZC ? m_pResolvedZC->szText : NULL;
}
