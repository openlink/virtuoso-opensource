/*
 *  $Id$
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
 */

function waLoadMenu (arr)
{
  var menu = new Menu
	(
	"root",
	400,
	23,
	"Verdana, Arial, Helvetica, sans-serif",
	11,
	"#000000",
	"#000000",
	"#FFFFFF",
	"#A4BFD5",
	"left",
	"middle",
	6,
	0,
	1000,
	-5,
	7,
	true,
	true,
	true,
	0,
	true,
	true
	);

  for (var i=0; i<arr.length; i=i+2)
    {
      if (arr[i+1] != null)
	menu.addMenuItem(arr[i], arr[i+1]);
      else
	menu.addMenuItem(arr[i]);
    }

  menu.hideOnMouseOut=true;
  menu.bgColor='#999999';
  menu.menuBorder=1;
  menu.menuLiteBgColor='#FFFFFF';
  menu.menuBorderBgColor='#99B3C5';
  menu.menuItemVAlign='center';
  return menu;
}

function mmLoadMenus()
{
  if (window.app_menu_odrive)
    return;

  window.app_menu_odrive = waLoadMenu (odrive_menu);
  window.app_menu_blog = waLoadMenu (blog_menu);
  window.app_menu_omail = waLoadMenu (omail_menu);
  window.app_menu_news = waLoadMenu (enews_menu);
  window.app_menu_wiki = waLoadMenu (wiki_menu);
  window.app_menu_gal =  waLoadMenu (gal_menu);
  window.menu_main = waLoadMenu ([ "Main menu", null ]);
  window.app_menu_home = waLoadMenu (home_menu);
  window.menu_main.writeMenus();

}


function mmFLoadMenus()
{

  if (window.fapp_menu_odrive)
    return;

  window.fapp_menu_odrive = waLoadMenu (fodrive_menu);
  window.fapp_menu_blog = waLoadMenu (fblog_menu);
  window.fapp_menu_omail = waLoadMenu (fomail_menu);
  window.fapp_menu_news = waLoadMenu (fenews_menu);
  window.fapp_menu_wiki = waLoadMenu (fwiki_menu);
  window.fapp_menu_gal = waLoadMenu (fgal_menu);
  window.menu_main = waLoadMenu ([ "Main menu", null ]);
  window.menu_main.writeMenus();
}

