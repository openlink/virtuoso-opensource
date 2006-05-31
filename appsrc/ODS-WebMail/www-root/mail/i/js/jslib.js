/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2006 OpenLink Software
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

var isNav5, isNav4, isNav, isIE4, isIE5, isIE, isWin, isMac;
var visible, hidden;
isNav5 = isNav4 = isNav = isIE4 = isIE5 = isIE55 = isIE = isWin = isMac = false;

if (navigator.appName == "Netscape")
{
  isNav = true;
  if (parseInt(navigator.appVersion) == 4) isNav4 = true;
  if (parseInt(navigator.appVersion) == 5) isNav5 = true;
}
else if (navigator.appName == "Microsoft Internet Explorer")
{
  isIE = true;
  if (navigator.appVersion.indexOf("MSIE 5.5") != -1) isIE55 = true;
  if (navigator.appVersion.indexOf("MSIE 5") != -1) isIE5 = true;
  if (navigator.appVersion.indexOf("MSIE 4") != -1) isIE4 = true;
}

if (navigator.platform.indexOf("Win") != -1) isWin = true;
if (navigator.platform.indexOf("Mac") != -1) isMac = true;

  function CCA(CB){
    if (CB.checked)
      hL(CB);
    else
      dL(CB);
  };

  function hL(E){
    if (isIE5){
      while (E.tagName!="TR")
        {E=E.parentElement;}
    }else{
      return;
      while (E.tagName!="TR")
        {E=E.parentNode;}
    };
    E.className = "H";
  };

  function dL(E){
    if (isIE5){
      while (E.tagName!="TR")
        {E=E.parentElement;}
    }else{
      while (E.tagName!="TR")
        {E=E.parentNode;}
    };
    E.className = "";
  };


  //-------------------------------------------
  var Mem = Array();
  //-------------------------------------------
  // Line highlighting alias//
  //-------------------------------------------
  function LHi(theRow){
    if(theRow.style) {
      if(theRow.currentStyle){
        Mem['background'] = theRow.currentStyle.backgroundColor;
        theRow.style.background='#FFFFCC'
      }else{
        //Mem['background'] = theRow.style.backgroundColor;
      }

    }
  }

  //-------------------------------------------
  // Line highlighting alias//
  //-------------------------------------------
  function LHo(theRow){
    if (theRow.style) {
      if (theRow.currentStyle) {
        theRow.style.background=Mem['background']
      } else {
        //theRow.className = Mem['background'];
      }
    }
    //debug(theRow.currentStyle);
  }

  //<!--=======================================================================-->
	function debug(obj){
    s='';
    for(ob in obj){
        s += ob+'='+obj[ob]+'<br>\n';
    }
    document.write(s);
  }

