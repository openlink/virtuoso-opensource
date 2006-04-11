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
	Instant.assign(something,callback)
*/

var Instant = {
	element:false,
	
	assign:function(something,callback) {
		/* assigned -> hide it, show when elm._Instant_show() is called */
		var elm = $(something);
		elm._Instant_show = function() {
			if (!Instant.element) { /* show only when hidden */
				Instant.element = elm;
				Dom.show(elm);
				Dom.attach(document,"mousedown",Instant.check);
			}
		}
		elm._Instant_hide = function() {
			Dom.hide(this);
			Instant.element = false;
			Dom.detach(document,"mousedown",Instant.check);
		}
		elm._Instant_hide();
		elm._Instant_callback = function(){};
		if (callback) { elm._Instant_callback = callback; }
	},
	
	check:function(event) {
		/* element shown, checking where user clicked */
		var node = Dom.source(event);
		/* walk up from the clicker. if we find instant element, then user clicked on it -> do nothing */
		do {
			if (node == Instant.element) { return; }
			node = node.parentNode;
		} while (node != document.body && node != document);
		Instant.element._Instant_callback();
		Instant.element._Instant_hide();
	}
}
