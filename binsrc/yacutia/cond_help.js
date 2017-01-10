/*
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
 *
 */

// -*- java -*- Emacs majick!
//
// Primitive toggle for help viewport and buttons
// DOM Level 2 Core required
//

function vm_help_toggle ()
{
  var elems = document.getElementsByName('help_viewport');
  var i;
  for (i = 0; i < elems.length; i++)
    {
      elems.item(i).style.display = elems.item(i).style.display ? '' : 'none';
    }
    elems = document.getElementsByName('help_toggle');

    var i;
    for (i = 0;i < elems.length;i++)
      {
	if (elems.item(i).value == 'Help')
	  elems.item(i).value = 'Hide help';
	else
	  elems.item(i).value = 'Help';
      }
}

function blah2 ()
{
    alert ('blah2');
}

function vm_help_toggle_popup (title)
{
  var i, h_win, vp_list, vp_copy;

// if (!yacutia_help_popup)
//	  {
// 	    yacutia_help_popup.close;
//	    return;
//   }
//
// Write initial document
//

  h_win = window.open ("",
                       'yacutia_help_popup',
                       'scrollbars,resizable,width=640,height=400');
  h_win.document.write ('<?xml version="1.0" encoding="utf-8"?>\n');
  h_win.document.write ('<!doctype html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"');
  h_win.document.write (' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n');
  h_win.document.write ('<html>\n');
  h_win.document.write ('  <head>\n    <title>\n');
  h_win.document.write ('      Virtuoso Conductor Help\n');
  h_win.document.write ('    </title>\n');
  h_win.document.write ('    <link rel="stylesheet" href="cond_help.css" type="text/css"/>\n')
  h_win.document.write ('  </head>\n');
  h_win.document.write ('  <body></body>\n');
  h_win.document.write ('</html>\n');
  h_win.document.close ();

  //
  // Find help_wiewport contents and append to document body of popup
  //

  vp_list = document.getElementsByName ('help_viewport');
  for (i = 0; i < vp_list.length; i++)
    {
      vp_copy = vp_list[i].cloneNode (true);
      h_win.document.body.appendChild (vp_copy);
      vp_copy.style.display = vp_copy.style.display ? '' : 'none';
    }
}
