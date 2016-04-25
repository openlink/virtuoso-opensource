/*
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
 *  
*/
//
//  Common javascript utilities
//

// when submitting from  javascript, the onsubmit event won't get fired 
// unless done explicitly.

function
util_form_submit(fm)
{
  if (fm.onsubmit())
    fm.submit();
}

//
// Get the debug window
//

function
util_dbg_win ()
{
  return window.open ('','dbgwin', 'toolbar=no, status=no');
}

//
// show elements of a dom node like a form
//

function 
util_dbg_show_elems (fm)
{
  var txt;
  var w;
  
  w = util_dbg_win ();
  w.document.write ('<h1>Elements of ' + 
                    fm.name + ' (' + 
                    fm.elements.length.toString() + 
                    ')</h1>');

  w.document.write ('<table class="dbgtbl">');

  for (i = 0;i < fm.elements.length;i++)
    w.document.write ('<tr>' + util_dbg_td (i) +
                      util_dbg_td (fm.elements[i].name) + '</tr>');

  w.document.write ('</table>');
}

function
util_dbg_td (val)
{
  return '<td class="dbgtblcell">' + val.toString() + '</td>';
}
