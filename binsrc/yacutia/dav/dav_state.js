/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
var DAVSTATE = new Object();

DAVSTATE.writeCookie = function (name, value, hours)
{
  if (hours) {
    var date = new Date ();
    date.setTime (date.getTime () + (hours * 60 * 60 * 1000));
    var expires = "; expires=" + date.toGMTString ();
  } else {
    var expires = "";
  }
  document.cookie = name + "=" + value + expires + "; path=/";
}

DAVSTATE.readCookie = function (name)
{
  var cookiesArr = document.cookie.split (';');
  for (var i = 0; i < cookiesArr.length; i++) {
    cookiesArr[i] = cookiesArr[i].trim();
    if (cookiesArr[i].indexOf (name+'=') == 0)
      return cookiesArr[i].substring (name.length + 1, cookiesArr[i].length);
  }
  return false;
}

DAVSTATE.writeState = function ()
{
  DAVSTATE.writeCookie('DAVSTATE_State', escape(OAT.JSON.stringify(DAVSTATE.state)), 1);
}

DAVSTATE.readState = function ()
{
  function initState(state)
  {
    if (!state) {
      var state = new Object();
      state.column = 'column_#1';
      state.direction = 'asc';
    }
    return state;
  }

  // load cookie data
  var s = DAVSTATE.readCookie('DAVSTATE_State');
  if (s) {
    try {
      s = OAT.JSON.parse(unescape(s));
    } catch (e) { s = null; }
    s = initState(s);
  } else {
    s = initState();
  }
  DAVSTATE.state = s;
}
