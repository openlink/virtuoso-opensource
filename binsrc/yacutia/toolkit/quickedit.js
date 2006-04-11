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
	QuickEdit.assign(something,type,options)
	QuickEdit.STRING
	QuickEdit.SELECT
*/


var QuickEdit = {
	STRING:1,
	SELECT:2,

	assign:function(something,type,options) {
		var elm = $(something);
		elm._QuickEdit_edit_type = type;
		if (options) { elm._QuickEdit_edit_options = options; }
		var ref = function() {
			QuickEdit.edit(elm);
		}
		Dom.attach(elm,"click",ref);
	},
	
	edit:function(elm) {
		switch (elm._QuickEdit_edit_type) {
			case QuickEdit.STRING:
				/* create inputbox */
				var newelm = Dom.create("input");
				newelm.setAttribute("type","text");
				var content = elm.innerHTML;
				newelm.setAttribute("size",content.length+1);
				newelm.value = content;
			break;
			case QuickEdit.SELECT:
				/* create select */
				var newelm = Dom.create("select");
				var options = [];
				if (elm._QuickEdit_edit_options) { options = elm._QuickEdit_edit_options; }
				var content = elm.innerHTML;
				var index = -1;
				for (var i=0;i<options.length;i++) {
					Dom.option(options[i],options[i],newelm);
					if (content == options[i]) { index = i; }
				}
				if (index == -1) {
					Dom.option(content,content,newelm);
					newelm.selectedIndex = i;
				} else { newelm.selectedIndex = index;	}
			break;
		} /* switch */
		
		/* insert into hierarchy */
		elm.parentNode.replaceChild(newelm,elm);
		var callback = function() {
			QuickEdit.revert(newelm,elm);
		}
		Instant.assign(newelm,callback);
		newelm._Instant_show();
		newelm.focus();
	},
	
	revert:function(elm,oldelm) {
		oldelm.innerHTML = elm.value;
		elm.parentNode.replaceChild(oldelm,elm);
	}
}
