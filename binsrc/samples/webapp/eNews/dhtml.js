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
var isNav5, isNav4, isNav, isIE4, isIE5, isIE, isWin, isMac;
var visible, hidden;
isNav5 = isNav4 = isNav = isIE4 = isIE5 = isIE = isWin = isMac = false;

if (navigator.appName == "Netscape")
{
  isNav = true;
  if (parseInt(navigator.appVersion) == 4) isNav4 = true;
  if (parseInt(navigator.appVersion) == 5) isNav5 = true;
}
else if (navigator.appName == "Microsoft Internet Explorer")
{
  isIE = true;
  if (navigator.appVersion.indexOf("MSIE 4") != -1) isIE4 = true;
  if (navigator.appVersion.indexOf("MSIE 5") != -1) isIE5 = true;
  if (navigator.appVersion.indexOf("MSIE 6") != -1) isIE5 = true;
}

if (navigator.platform.indexOf("Win") != -1) isWin = true;
if (navigator.platform.indexOf("Mac") != -1) isMac = true;

visible = "visible";
hidden = "hidden";
if (isNav4)
{
  visible = "show";
  hidden = "hide";
}

function getNav4Layer(layerId, parent)
{
  var objLayer;
  var parentObj = (parent) ? parent : document;
  for (var i = 0; i < parentObj.layers.length && !objLayer; i ++)
  {
    if (parentObj.layers[i].id == layerId)
    {
      objLayer = parentObj.layers[i];
    }
    else
    {
      objLayer=getNav4Layer(layerId, parentObj.layers[i]);
    }
  }
  return objLayer;
}

function CSSObject(obj, doc)
{
  this.name = obj;
  if (isIE5 || isNav5)
  {
    this.elem = doc.getElementById(obj);
    this.css = this.elem.style;
  }
  else if (isIE4)
  {
    this.elem = doc.all[odj];
    this.css = this.elem.style;
  }
  else if (isNav4)
  {
    this.css = getNav4Layer(obj, doc);
    this.elem = this.css;
  }
}

function vertMoveByNav(y)
{
  this.css.top = parseInt(this.css.top) + y;
}

function horizontalMoveByNav(x)
{
  this.css.left = parseInt(this.css.left) + x;
}

function moveByNav(x, y)
{
  this.css.left = parseInt(this.css.left) + x;
  this.css.top = parseInt(this.css.top) + y;
}

function vertMoveByIE(y)
{
  this.css.pixelTop += y;
}

function horizontalMoveByIE(x)
{
  this.css.pixelLeft += x;
}

function moveByIE(x, y)
{
  this.css.pixelLeft += x;
  this.css.pixelTop += y;
}

function moveToNav(x, y)
{
  this.css.left = x;
  this.css.top = y;
}

function moveToIE(x, y)
{
  this.css.pixelLeft = x;
  this.css.pixelTop = y;
}

function rectNav(x, y, w, h)
{
  this.css.clip.top = y;
  this.css.clip.bottom = y + h;
  this.css.clip.left = x;
  this.css.clip.right = x + w;
}

function rectIE(x, y, w, h)
{
  this.css.clip = "rect(" + y + "px " + (x + w) + "px " + (y + h) + "px " + x + "px)";
}

if (isNav4)
{
  CSSObject.prototype.verticleMoveBy = vertMoveByNav;
  CSSObject.prototype.horizontalMoveBy = horizontalMoveByNav;
  CSSObject.prototype.moveBy = moveByNav;
  CSSObject.prototype.moveTo = moveToNav;
  CSSObject.prototype.clipRect = rectNav;
}

if (isIE4 || isIE5)
{
  CSSObject.prototype.verticleMoveBy = vertMoveByIE;
  CSSObject.prototype.horizontalMoveBy = horizontalMoveByIE;
  CSSObject.prototype.moveBy = moveByIE;
  CSSObject.prototype.moveTo = moveToIE;
}

if (isNav5)
{
  CSSObject.prototype.verticleMoveBy = vertMoveByNav;
  CSSObject.prototype.horizontalMoveBy = horizontalMoveByNav;
  CSSObject.prototype.moveBy = moveByNav;
  CSSObject.prototype.moveTo = moveToNav;
}


if (isIE4 || isIE5 || isNav5)
{
  CSSObject.prototype.clipRect = rectIE;
}

function HTMLWriteNav4(html)
{
  this.css.document.open();
  this.css.document.write(html);
  this.css.document.close();
}

function HTMLWriteIE5(html)
{
  this.elem.innerHTML = html;
}

function HTMLWriteNav5(html)
{
  var rng = document.createRange();
  rng.selectNodeContents(this.elem);
  rng.deleteContents();
  var htmlFrag = rng.createContextualFragment(html);
  this.elem.appendChild(htmlFrag);
}

if (isNav4) CSSObject.prototype.write = HTMLWriteNav4;
else if (isNav5) CSSObject.prototype.write = HTMLWriteNav5;
else if (isIE5 || (isIE4 && isWin))
  CSSObject.prototype.write = HTMLWriteIE5;
