/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2017 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.QuickEdit.assign(something,type,options)
	OAT.QuickEdit.STRING
	OAT.QuickEdit.SELECT
*/


OAT.QuickEdit = {
	STRING:1,
	SELECT:2,

	assign:function(something,type,options) {
		var elm = $(something);
		elm._QuickEdit_edit_type = type;
		if (options) { elm._QuickEdit_edit_options = options; }
		var ref = function() {
			OAT.QuickEdit.edit(elm);
		}
		OAT.Event.attach(elm,"click",ref);
	},

	edit:function(elm) {
		switch (elm._QuickEdit_edit_type) {
			case OAT.QuickEdit.STRING:
				/* create inputbox */
				var newelm = OAT.Dom.create("input");
				newelm.setAttribute("type","text");
				var content = elm.innerHTML;
				newelm.setAttribute("size",content.length+1);
				newelm.value = content;
			break;
			case OAT.QuickEdit.SELECT:
				/* create select */
				var newelm = OAT.Dom.create("select");
				var options = [];
				if (elm._QuickEdit_edit_options) { options = elm._QuickEdit_edit_options; }
				var content = elm.innerHTML;
				var index = -1;
				for (var i=0;i<options.length;i++) {
					OAT.Dom.option(options[i],options[i],newelm);
					if (content == options[i]) { index = i; }
				}
				if (index == -1) {
					OAT.Dom.option(content,content,newelm);
					newelm.selectedIndex = i;
				} else { newelm.selectedIndex = index;	}
			break;
		} /* switch */

		/* insert into hierarchy */
		elm.parentNode.replaceChild(newelm,elm);
		var callback = function() {
			OAT.QuickEdit.revert(newelm,elm);
		}
		OAT.Instant.assign(newelm,callback);
		newelm._Instant_show();
		newelm.focus();
	},

	revert:function(elm,oldelm) {
		oldelm.innerHTML = elm.value;
		elm.parentNode.replaceChild(oldelm,elm);
	}
}
