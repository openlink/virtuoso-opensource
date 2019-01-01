/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2019 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.Bindings.bindString(input,object,property)
	OAT.Bindings.bindBool(input,object,property)
	OAT.Bindings.bindSelect(input,object,property)
	OAT.Bindings.bindCombo(input,object,property)
	OAT.Bindings.bindColor(input,object,property)
*/

OAT.Bindings = {
	bindString:function(input,object,property) {
		var callback = function(event) {
			object[property] = $v(input);
		}
		OAT.Event.attach(input,"keyup",callback);
	},

	bindBool:function(input,object,property) {
		var callback = function(event) {
			object[property] = (input.checked ? "1" : "0");
		}
		OAT.Event.attach(input,"change",callback);
	},

	bindSelect:function(input,object,property) {
		var callback = function(event) {
			object[property] = $v(input);
		}
		OAT.Event.attach(input,"change",callback);
	},

	bindCombo:function(input,object,property) {
		var callback = function(event) {
			object[property] = $v(input);
		}
		input.onchange = callback;
	},

	bindColor:function(input,object,property) {
		var c = new OAT.Color();
		var callback = function(event) {
			var colorRef = function(color) { object[property] = color; input.style.backgroundColor = color;}
			var coords = OAT.Dom.position(input);
			c.pick(coords[0]-150,coords[1],colorRef);
		}
		OAT.Event.attach(input,"click",callback);
	}
}
