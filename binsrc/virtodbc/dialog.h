/*
 *  dialog.h
 *
 *  $Id$
 *
 *  Common dialog code
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

#ifndef _DIALOG_H
#define _DIALOG_H

struct TDialog
  {
    HINSTANCE m_hInstance;
    HWND m_hWnd;

    static
#ifdef _WIN64
INT_PTR
#else
	BOOL CALLBACK
#endif
      DlgProc (HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

    virtual void OnCommand (DWORD dwCmd, LPARAM lParam);
    virtual BOOL OnInitDialog (void);
    virtual BOOL OnOtherMsg (UINT uMsg, WPARAM wParam, LPARAM lParam);
    void Center (void);
    DWORD RunModal (HINSTANCE hInstance, DWORD dwResId, HWND hParentWnd);
  };

#endif
