/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
function rtbls_chg()
{
  // TODO: turn multiple into a single selection in unix-netscape
  return (0);
}

function dsns_chg(sel)
{

  //  Document.DSN.value =
  // TODO: turn multiple into a single selection in unix-netscape,
  // set DSN input value according to selection

  var i, _new, old;

  document.link_form.step.value = '';

  if (sel.selectedIndex == -1)
    {
      document.link_form.dsn.value = '';
      document.link_form.user.value = '';
      document.link_form.pass.value = '';
      return (0);
    }

  for (i = 0;i < sel.length;i++)
    {
      if (sel.options[i].selected)
	{
	  if (sel.options[i].text == document.link_form.dsn.value)
	    {
	      sel.options[i].selected = false;
	    }
	  else
	    {
	      document.link_form.dsn.value = sel.options[i].text;
	    }
	}
    }
  document.link_form.submit();
}

function tbls_chg(sel)
{
  var i;
  var j, len;

  i = sel.selectedIndex;
  j = sel.options[i].text.lastIndexOf('.');
  len = sel.options[i].text.length;
  document.link_form.dbtbl.value = sel.options[i].text.substring(j+1, len, len-j-1);
  return (0);

}

function def_keys_add(sel)
{
  var i;

  i = sel.selectedIndex;
  document.creat_key.colname_add.value = sel.options[i].text;
  document.creat_key.submit();
}

function def_keys_rmv(sel)
{
  var i;

  i = sel.selectedIndex;
  document.creat_key.colname_rmv.value = sel.options[i].text;
  document.creat_key.submit();
}
