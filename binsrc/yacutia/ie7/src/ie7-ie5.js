/*
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
 *  
*/
/*
	W3C compliance for Microsoft Internet Explorer

	this module forms part of IE7
	IE7 version 0.7.3 (alpha) 2004/09/18
	by Dean Edwards, 2004
*/

// block elements are "inline" according to IE5.0
//  so we'll force "layout"
if (isHTML) {
	HEADER += "address,blockquote,body,dd,div,dl,dt,fieldset,form,frame,"+
	"frameset,h1,h2,h3,h4,h5,h6,iframe,noframes,object,p,applet,center,"+
	"dir,hr,menu,pre{display:block;height:0cm}li,ol,ul{display:block}";
}

// array fixes
if (![].push) push = function(array, item) {
	array[array.length] = item;
	return array.length;
};
if (![].pop) pop = function(array) {
	var item = array[array.length - 1];
	array.length--;
	return item;
};

// fix String.replace
if("i".replace(/i/,function(){return""})){var a=String.prototype.replace,b=function(r,w){var m,n="",s=this;
while((m=r.exec(s))){n+=s.slice(0,m.index)+w(m[0],m[1],m[2],m[3],m[4]);s=s.slice(m.lastIndex)}return n+s};
String.prototype.replace=function(r,w){this.replace=(typeof w=="function")?b:a;return this.replace(r,w)}}
