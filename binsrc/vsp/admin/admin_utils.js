/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
function confirm_a_drop (btn)
{
  return confirm ('Are you sure you want to drop the subscription and the local data');
}

function selectAllCheckboxes (form, btn)
{
  var i;
  for (i =0; i < form.elements.length; i++)
    {
      var contr = form.elements[i];
      if (contr != null && contr.type == "checkbox")
	{
	  contr.focus();
	  if (btn.value == 'Select All')
	    contr.checked = true;
	  else
            contr.checked = false;
	}
    }
  if (btn.value == 'Select All')
    btn.value = 'Unselect All';
  else
    btn.value = 'Select All';
  btn.focus();
}

