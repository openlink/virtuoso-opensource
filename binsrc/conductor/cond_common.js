/*
 *  $Id$
 *
 *  Common (Java/ECMA)Script utilities for Yacutia
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
 */

// Toggle control enabled

function y_tg_enabled (c_id)
{
  var c = document.getElementById (c_id);

  if (c)
    if (c.disabled && c.disabled == true)
      c.disabled = false;
    else
      c.disabled = true;
}

function selectAllCheckboxes (form, btn)
{
  for (var i = 0; i < form.elements.length; i++) {
    var contr = form.elements[i];
    if ((contr != null) && (contr.type == "checkbox")) {
      contr.focus();
      contr.checked = (btn.value == 'Select All')
    }
  }
  btn.value = (btn.value == 'Select All')? 'Unselect All':'Select All';
  btn.focus();
}

function dsns_chg(sel)
{
  var i, _new, old;
  if (sel.selectedIndex == -1)
  {
    document.link_form.dsn.value = '';
    document.link_form.uid.value = '';
    document.link_form.pwd.value = '';
    return (0);
  }
  for (i = 0; i < sel.length; i++)
  {
    if (sel.options[i].selected)
    {
      if (sel.options[i].text == document.link_form.dsn.value)
        sel.options[i].selected = false;
      else
        document.link_form.dsn.value = sel.options[i].text;
    }
  }
}

function destinationChange(obj, changes) {
  function destinationChangeInternal(actions) {
    if (!obj)
      return;

    if (actions.hide) {
      var a = actions.hide;
      for ( var i = 0; i < a.length; i++)
        OAT.Dom.hide(a[i]);
    }
    if (actions.show) {
      var a = actions.show;
      for ( var i = 0; i < a.length; i++)
        OAT.Dom.show(a[i]);
    }
    if (actions.clear) {
      var a = actions.clear;
      for ( var i = 0; i < a.length; i++) {
        var o = $(a[i])
        if (o && o.value)
          o.value = '';
      }
    }
    if (actions.exec) {
      var a = actions.exec;
      for ( var i = 0; i < a.length; i++) {
        a[i](obj);
      }
    }
  }
  if (!changes)
    return;

  if (obj.checked && changes.checked)
    destinationChangeInternal(changes.checked);

  if (!obj.checked && changes.unchecked)
    destinationChangeInternal(changes.unchecked);
}
