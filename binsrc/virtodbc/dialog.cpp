/*
 *  dialog.cpp
 *
 *  $Id$
 *
 *  Common dialog code
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
 */

#include "w32util.h"
#include "dialog.h"


#ifdef _WIN64
INT_PTR
#else
BOOL CALLBACK
#endif
TDialog::DlgProc (HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  TDialog *pWnd;

  pWnd = (TDialog *) GetWindowLongPtr (hWnd, GWLP_USERDATA);

  switch (uMsg)
    {
    case WM_INITDIALOG:
      pWnd = (TDialog *) lParam;
      pWnd->m_hWnd = hWnd;
      SetWindowLongPtr (hWnd, GWLP_USERDATA, (LONG_PTR) pWnd);
      return pWnd->OnInitDialog ();

    case WM_COMMAND:
      pWnd->OnCommand (wParam, lParam);
      return TRUE;

    default:
      if (pWnd)
	return pWnd->OnOtherMsg (uMsg, wParam, lParam);
    }

  return FALSE;
}


BOOL
TDialog::OnInitDialog (void)
{
  Center ();
  return TRUE;
}


void
TDialog::OnCommand (DWORD dwCmd, LPARAM lParam)
{
  switch (dwCmd)
    {
    case IDOK:
    case IDCANCEL:
      EndDialog (m_hWnd, dwCmd);
      break;
    }
}


BOOL
TDialog::OnOtherMsg (UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  return FALSE;
}


void
TDialog::Center (void)
{
  RECT rChild, rParent;
  int wChild, hChild, wParent, hParent;
  int wScreen, hScreen, xNew, yNew;
  HWND hWndParent;
  HDC hdc;

  if ((hWndParent = GetWindow (m_hWnd, GW_OWNER)) == NULL)
    hWndParent = GetDesktopWindow ();

  /* Get the Height and Width of the child window */
  GetWindowRect (m_hWnd, &rChild);
  wChild = rChild.right - rChild.left;
  hChild = rChild.bottom - rChild.top;

  /* Get the Height and Width of the parent window */
  GetWindowRect (hWndParent, &rParent);
  wParent = rParent.right - rParent.left;
  hParent = rParent.bottom - rParent.top;

  /* Get the display limits */
  hdc = GetDC (m_hWnd);
  wScreen = GetDeviceCaps (hdc, HORZRES);
  hScreen = GetDeviceCaps (hdc, VERTRES);
  ReleaseDC (m_hWnd, hdc);

  /* Calculate new X position, then adjust for screen */
  xNew = rParent.left + ((wParent - wChild) / 2);
  if (xNew < 0)
    xNew = 0;
  else if ((xNew + wChild) > wScreen)
    xNew = wScreen - wChild;

  /* Calculate new Y position, then adjust for screen */
  yNew = rParent.top + ((hParent - hChild) / 2);
  if (yNew < 0)
    yNew = 0;
  else if ((yNew + hChild) > hScreen)
    yNew = hScreen - hChild;

  /* Set it, and return */
  SetWindowPos (m_hWnd, NULL, xNew, yNew, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
}


DWORD
TDialog::RunModal (HINSTANCE hInstance, DWORD dwResId, HWND hParentWnd)
{
  m_hInstance = hInstance;

  return DialogBoxParam (hInstance,
      MAKEINTRESOURCE (dwResId),
      hParentWnd,
      DlgProc,
      (LPARAM) this);
}
