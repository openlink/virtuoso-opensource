/*
 *  wizard.cpp
 *
 *  $Id$
 *
 *  Wizard Dialogs
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
 */

#include "w32util.h"
#include "wizard.h"
#include "resource.h"


TWizard::TWizard ()
{
  m_iNumPages = 0;
  m_iCurPage = -1;
  m_hDefBtn = NULL;
  m_dwDefBtn = 0;
}


BOOL
TWizard::OnInitDialog (void)
{
  BOOL bRC;

  bRC = TDialog::OnInitDialog ();
  m_hBackBtn = GetDlgItem (m_hWnd, IDC_BACKBTN);
  m_hNextBtn = GetDlgItem (m_hWnd, IDC_NEXTBTN);
  m_hCancelBtn = GetDlgItem (m_hWnd, IDCANCEL);

  return bRC;
}


HWND
TWizard::AddPage (DWORD dwResId, DWORD dwFirstCtl)
{
  HWND hChildDlg;
  HWND hOwnerWnd;
  HWND hCtl;
  POINT tl;
  RECT rc;
  DWORD dwStyle;

  if (m_iNumPages + 1 >= MAX_PAGES)
    return NULL;

  /* Load the child pane */
  hChildDlg = CreateDialog (m_hInstance, MAKEINTRESOURCE (dwResId),
      m_hWnd, WizChildProc);
  if (hChildDlg == NULL)
    return NULL;
  m_hPageWnd[m_iNumPages] = hChildDlg;

  /* Set the ID so we can access it with GetDlgItem */
  SetWindowLongPtr (hChildDlg, GWLP_ID, dwResId);

  /* Reparent, so it gets destroyed automatically */
  SetParent (hChildDlg, m_hWnd);

  /* Reset some of it's styles */
  dwStyle = GetWindowLongPtr (hChildDlg, GWL_STYLE);
  dwStyle &= ~(WS_CAPTION | WS_VISIBLE);
  SetWindowLongPtr (hChildDlg, GWL_STYLE, dwStyle);

  /* The placeholder determines it's size */
  hOwnerWnd = GetDlgItem (m_hWnd, IDC_PLACEHOLDER);
  GetWindowRect (hOwnerWnd, &rc);
  tl.x = rc.left;
  tl.y = rc.top;
  ScreenToClient (m_hWnd, &tl);

  /* Position the child right after the (invisible) placeholder */
  SetWindowPos (hChildDlg, hOwnerWnd, tl.x, tl.y,
      rc.right - rc.left, rc.bottom - rc.top, SWP_HIDEWINDOW);

  /* Locate first child that has WS_TABSTOP set */
  if (dwFirstCtl == 0)
    {
      m_hFirstCtl[m_iNumPages] = NULL;
      for (hCtl = GetTopWindow (hChildDlg);
	  hCtl;
	  hCtl = GetNextWindow (hCtl, GW_HWNDNEXT))
	{
	  dwStyle = GetWindowLongPtr (hCtl, GWL_STYLE);
	  if (dwStyle & WS_TABSTOP)
	    {
	      m_hFirstCtl[m_iNumPages] = hCtl;
	      break;
	    }
	}
    }
  else
    m_hFirstCtl[m_iNumPages] = GetDlgItem (hChildDlg, dwFirstCtl);

  m_iNumPages++;

  return hChildDlg;
}


void
TWizard::SetDefaultButton (DWORD dwDefBtn)
{
  if (dwDefBtn != m_dwDefBtn)
    {
      if (m_hDefBtn)
	SendMessage (m_hDefBtn, BM_SETSTYLE, BS_PUSHBUTTON, TRUE);

      SendMessage (m_hWnd, DM_SETDEFID, dwDefBtn, 0);
      m_hDefBtn = GetDlgItem (m_hWnd, dwDefBtn);
      m_dwDefBtn = dwDefBtn;
    }
}


void
TWizard::ChangePage (int iPage)
{
  TCHAR szText[32];

  if (iPage < 0 || iPage >= m_iNumPages)
    return;

  /* Back button valid in page > 0 */
  EnableWindow (m_hBackBtn, iPage > 0);

  /* Next -> Finish on last page */
  LoadString (m_hInstance,
      iPage + 1 < m_iNumPages ? IDS_NEXT : IDS_FINISH,
      szText, NUMCHARS (szText));
  SetWindowText (m_hNextBtn, szText);

  /* Hide previous */
  if (m_iCurPage != -1)
    ShowWindow (m_hPageWnd[m_iCurPage], SW_HIDE);

  /* Show new current window */
  ShowWindow (m_hPageWnd[iPage], SW_SHOW);

  /* Focus first control */
  SetFocus (m_hFirstCtl[iPage]);

  /* Correct shadow on Back button */
  if (iPage < m_iCurPage)
    {
      SendMessage (m_hBackBtn, BM_SETSTYLE, BS_PUSHBUTTON, TRUE);
      SendMessage (m_hDefBtn, BM_SETSTYLE, BS_DEFPUSHBUTTON, TRUE);
    }

  m_iCurPage = iPage;
  ValidatePage ();
}


void
TWizard::ValidatePage (void)
{
  HWND hFocusWnd = GetFocus ();
  if (IsPageValid ())
    {
      SetDefaultButton (IDC_NEXTBTN);
      EnableWindow (m_hNextBtn, TRUE);
    }
  else
    {
      EnableWindow (m_hNextBtn, FALSE);
      if (m_iCurPage == 0)
	SetDefaultButton (IDCANCEL);
      else
	SetDefaultButton (IDC_BACKBTN);
    }
  SetFocus (hFocusWnd);
}


#ifdef _WIN64
INT_PTR
#else
BOOL CALLBACK
#endif
TWizard::WizChildProc (HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  switch (uMsg)
    {
    case WM_INITDIALOG:
      return TRUE;

    case WM_COMMAND:
      return SendMessage (GetParent (hWnd), uMsg, wParam, (LPARAM) hWnd);

    default:
      return FALSE;
    }
}
