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
	OAT.Keyboard.add(key, downCallback, upCallback, group, id, obj)
	OAT.Keyboard.disable(group)
	OAT.Keyboard.enable(group)
*/

OAT.Keyboard = {
	groups:{},
	objects:[],
	disabled:[], /* groups */

	check:function(event,target) {
		/* TODO: detect which tab is active */
		var list = [];
		for (var p in OAT.Keyboard.groups) {
			var index = OAT.Keyboard.disabled.indexOf(p);
			if (index == -1) { list.append(OAT.Keyboard.groups[p]); } /* only non-disabled groups */
		}
		/***/

		for (var i=0;i<list.length;i++) {
			var ko = list[i];
			if (ko.target == target) {
				if (ko.keyCode == event.keyCode &&
					ko.ctrlKey == event.ctrlKey &&
					ko.altKey == event.altKey &&
					ko.shiftKey == event.shiftKey) {
						if (ko.downCallback && event.type == "keydown") { ko.downCallback(); }
						if (ko.upCallback && event.type == "keyup") { ko.upCallback(); }
					} /* if right key */
			} /* if right target */
		} /* for all managed keycodes */
	}, /* OAT.Keyboard.check() */

	add:function(key, downCallback, upCallback, group, id, obj) {
		var o = (obj ? $(obj) : document); /* cannot attach to window due to ie */
		var g = (group ? group : 0);
		var index = OAT.Keyboard.objects.indexOf(o);
		if (index == -1) {
			OAT.Keyboard.objects.push(o);
			OAT.Event.attach(o,"keydown",function(event){OAT.Keyboard.check(event,o);});
			OAT.Event.attach(o,"keyup",function(event){OAT.Keyboard.check(event,o);});
		}
		if (!(g in OAT.Keyboard.groups)) { OAT.Keyboard.groups[g] = []; }

		var keyObj = {
			downCallback:downCallback,
			upCallback:upCallback,
			id:id,
			target:o,
			ctrlKey:0,
			altKey:0,
			shiftKey:0,
			keyCode:0
		};
		var parts = key.toLowerCase().split("-");
		for (var i=0;i<parts.length;i++) {
			var p = parts[i];
			if (p == "ctrl") { keyObj.ctrlKey = 1; } else
			if (p == "alt") { keyObj.altKey = 1; } else
			if (p == "shift") { keyObj.shiftKey = 1; } else {
				if (p in OAT.Keyboard.conversion) {
					keyObj.keyCode = OAT.Keyboard.conversion[p];
				} else { alert("OAT.Keyboard.add:\nUnknown key '"+p+"'"); }
			}
		}
		OAT.Keyboard.groups[g].push(keyObj);
	}, /* OAT.Keyboard.add() */

	save:function(){},

	load:function(){},

	disable:function(group){
		var index = OAT.Keyboard.disabled.indexOf(group);
		if (index == -1) { OAT.Keyboard.disabled.push(group); }
	},

	enable:function(group){
		var index = OAT.Keyboard.disabled.indexOf(group);
		if (index != -1) { OAT.Keyboard.disabled.splice(index,1); }
	},

	conversion:{
		"f1":112, "f2":113, "f3":114, "f4":115, "f5":116, "f6":117, "f7":118,
		"f8":119, "f9":120, "f10":121, "f11":122, "f12":123,
		"left":37, "up":38, "right":39, "bottom":40, "~":192,
		"insert":45, "delete":46, "home":36, "end":35, "pageup":33, "pagedown":34,
		"num1":97, "num2":98, "num3":99, "num4":100, "num5":101,
		"num6":102, "num7":103, "num8":104, "num9":105,
		"num0":96, "num.":110, "num+":107, "num-":109,
		"num*":106, "num/":111, "/":191, ".":190, ",":188,
		"[":219, "]":221, "\\":220, ";":59, "'":222,
		"a":65, "b":66, "c":67, "d":68, "e":69, "f":70,
		"g":71 ,"h":72, "i":73, "j":74, "k":75, "l":76,
		"m":77 ,"n":78, "o":79, "p":80, "q":81, "r":82,
		"s":83 ,"t":84, "u":85, "v":86, "w":87, "x":88,
		"y":89 ,"z":90, "0":48, "1":49, "2":50, "3":51,
		"4":52, "5":53, "6":54, "7":55, "8":56, "9":57,
		"esc":27,"return":13,"enter":13

	}
}
