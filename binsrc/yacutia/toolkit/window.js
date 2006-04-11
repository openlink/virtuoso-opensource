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
	Window.create(element,state)
	Window.createMinimize(clicker,window)
	Window.createMaximize(clicker,window)
	Window.createToggle(clicker,window)
	Window.createClose(clicker,window)
	Window.MINIMIZED
	Window.MAXIMIZED
*/

var Window = {
	MINIMIZED:1,
	MAXIMIZED:2,
	
	create:function(element,state) {
		var elm = $(element);
		elm._Window_state = state;
		elm._Window_minimizeFunction = function(){};
		elm._Window_maximizeFunction = function(){};
		elm._Window_minimize = function() {
			elm._Window_state = Window.MINIMIZED;
			elm._Window_minimizeFunction();
		}
		elm._Window_maximize = function() {
			elm._Window_state = Window.MAXIMIZED;
			elm._Window_maximizeFunction();
		}
	},
	
	createMinimize:function(clicker,window) {
		var elm = $(clicker);
		elm.style.cursor = "pointer";
		var ref=function() {
			var win = $(window);
			win._Window_minimize();
		}
		Dom.attach(elm,"click",ref);
	},
	
	createMaximize:function(clicker,window) {
		var elm = $(clicker);
		elm.style.cursor = "pointer";
		var ref=function() {
			var win = $(window);
			win._Window_maximize();
		}
		Dom.attach(elm,"click",ref);
	},

	createToggle:function(clicker,window) {
		var elm = $(clicker);
		elm.style.cursor = "pointer";
		var ref=function() {
			var win = $(window);
			if (win._Window_state == Window.MINIMIZED) {
				win._Window_maximize();
			} else {
				win._Window_minimize();
			}
		}
		Dom.attach(elm,"click",ref);
	},
	
	createClose:function(clicker,window) {
		var elm = $(clicker);
		elm.style.cursor = "pointer";
		var ref=function() {
			var win = $(window);
			Dom.unlink(win);
		}
		Dom.attach(elm,"click",ref);
	}
}
