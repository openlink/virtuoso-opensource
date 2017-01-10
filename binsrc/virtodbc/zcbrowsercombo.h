/*
 *  zcbrowsercombo.h
 *
 *  $Id$
 *
 *  ZeroConfig Browser Combo
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
 */

#ifndef _ZCBROWSERCOMBO_H
#define _ZCBROWSERCOMBO_H

#include "winctl.h"
#include "zcbrowser.h"

#define WM_ZCNOTIFY	(WM_USER + 100)
#define WM_ZCRESOLVED	(WM_USER + 101)

struct TZCBrowserCombo : TComboCtl
  {
    TZCPublication *m_pResolvedZC;
    HWND m_hMsgWnd;

    TZCBrowserCombo ();
    ~TZCBrowserCombo ();

    void Clear (void);
    void OnCbnEditChange (void);
    void OnCbnDropDown (void);
    void OnCbnCloseUp (void);
    void TryResolve (void);
    void DidResolve (TZCPublication *p);

    void Attach (HWND hMsgWnd, HWND hOwnerWnd, DWORD dwResId, int len);

    BOOL IsResolved (void);
    LPCTSTR GetHost (void);
    LPCTSTR GetName (void);
    LPCTSTR GetDSN (void);
  };

extern TZCBrowser _zcbrowser;

#endif
