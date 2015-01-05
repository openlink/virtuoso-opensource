/*
 *  winctl.h
 *
 *  $Id$
 *
 *  Win32 controls
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

#ifndef _WINCTL_H
#define _WINCTL_H

struct TCtl
  {
    HWND m_hCtl;
    DWORD m_dwResId;

    TCtl () : m_hCtl(0) {}
    void Attach (HWND hWnd, DWORD dwResId)
      { m_dwResId = dwResId;
	m_hCtl = GetDlgItem (hWnd, dwResId); }
    void Enable (BOOL bEnable)
      { EnableWindow (m_hCtl, bEnable); }
    void Show (BOOL bShow)
      { ShowWindow (m_hCtl, bShow ? SW_SHOW : SW_HIDE); }
    void SetFocus ()
      { ::SetFocus (m_hCtl); }
  };

struct TCheckCtl : TCtl
  {
    void Check (BOOL bCheck)
      { SendMessage (m_hCtl, BM_SETCHECK,
	  bCheck ? BST_CHECKED : BST_UNCHECKED, 0); }
    BOOL Checked (void)
      { return SendMessage (m_hCtl, BM_GETCHECK, 0, 0) != BST_UNCHECKED; }
  };

struct TTextCtl : TCtl
  {
    LPTSTR m_szText;
    DWORD m_dwLen;

    TTextCtl () : m_szText(0) {}
    ~TTextCtl ()
      { if (m_szText) delete[] m_szText; }
    void Attach (HWND hWnd, DWORD dwResId, int len);
    int TextLength (void)
      { return GetWindowTextLength (m_hCtl); }
    LPTSTR Text (void)
      {
	GetWindowText (m_hCtl, m_szText, m_dwLen);
	return m_szText;
      }
    void Text (LPCTSTR szText)
      { SetWindowText (m_hCtl, szText); }
  };

struct TEditCtl : TTextCtl
  {
    void Attach (HWND hWnd, DWORD dwResId, int len)
      { TTextCtl::Attach (hWnd, dwResId, len);
        SendMessage (m_hCtl, EM_LIMITTEXT, len, 0); }
    void ReadOnly (BOOL bOn)
      { SendMessage (m_hCtl, EM_SETREADONLY, bOn, 0); }
  };

struct TComboCtl : TTextCtl
{
  void Attach (HWND hWnd, DWORD dwResId, int len)
    { TTextCtl::Attach (hWnd, dwResId, len);
      SendMessage (m_hCtl, CB_SETEXTENDEDUI, TRUE, 0);
      SendMessage (m_hCtl, CB_LIMITTEXT, len, 0); }
  int AddString (LPTSTR str)
    { return (int) SendMessage (m_hCtl, CB_ADDSTRING, 0, (LPARAM) str); }
  int Find (LPTSTR str)
    { return (int) SendMessage (m_hCtl, CB_FINDSTRING, -1, (LPARAM) str); }
  int FindExact (LPTSTR str)
    { return SendMessage (m_hCtl, CB_FINDSTRINGEXACT, -1, (LPARAM) str); }
  void Clear (void)
    { SendMessage (m_hCtl, CB_RESETCONTENT, 0, 0); }
  int Count (void)
    { return (int) SendMessage (m_hCtl, CB_GETCOUNT, 0, 0); }
  int CurSel (void)
    { return (int) SendMessage (m_hCtl, CB_GETCURSEL, 0, 0); }
  int CurSel (int index)
    { return (int) SendMessage (m_hCtl, CB_SETCURSEL, index, 0); }
  void *Data (int index)
    { return (void *) SendMessage (m_hCtl, CB_GETITEMDATA, index, 0); }
  int Data (int index, void *data)
    { return (int) SendMessage (m_hCtl, CB_SETITEMDATA, index, (LPARAM) data); }
};

#endif
