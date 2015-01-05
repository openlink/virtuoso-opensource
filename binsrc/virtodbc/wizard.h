/*
 *  wizard.h
 *
 *  $Id$
 *
 *  Wizard Dialogs
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#define MAX_PAGES	8

#include "dialog.h"

struct TWizard : TDialog
  {
    HWND m_hPageWnd[MAX_PAGES];
    HWND m_hFirstCtl[MAX_PAGES];
    HWND m_hBackBtn;
    HWND m_hNextBtn;
    HWND m_hCancelBtn;
    HWND m_hDefBtn;
    DWORD m_dwDefBtn;
    int m_iCurPage;
    int m_iNumPages;

    TWizard ();

    virtual BOOL OnInitDialog (void);
    virtual void OnCommand (DWORD dwCmd, LPARAM lParam) = 0;

    void SetDefaultButton (DWORD dwDefBtn);
    virtual void ValidatePage (void);
    virtual BOOL IsPageValid (void) = 0;

    static
#ifdef _WIN64
INT_PTR
#else
	BOOL CALLBACK
#endif
      WizChildProc (HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

  public:
    HWND AddPage (DWORD dwResId, DWORD dwFirstCtl = 0);
    void ChangePage (int iPage);
  };

