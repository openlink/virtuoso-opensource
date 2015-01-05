/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2015 OpenLink Software
 *
 *  See LICENSE file for details.
 */

/*
	t = new OAT.Tree(options);
	t.assign(listElm,collapse);
	t.delete();

	var node = t.tree.children[index]

	node.select()
	node.deselect()
	node.expand()
	node.collapse()
	node.getLabel()
	node.setLabel(newLabel)
	node.getValue()
	node.setValue(newValue)
	node.setImage(newImage)
	node.appendChild(oldNode, [index])
	node.deleteChild(oldNode)
	node.createChild(label, isNode, [index])

*/

OAT.TreeNode = function(li,ul,parent,root,value) {
	/* this.parent.ul == li.parentNode */
	var self = this;
	this.options = root.options;
	this.ul = ul; /* our child */
	this.li = li; /* our element */
	this.parent = parent;
	this.root = root;
	this.children = [];
	this.depth = -1;
	this.state = 1; /* 0 - collapsed, 1 - expanded */
	this.selected = 0;
	this.customImage = false;
	this.value = value; 	/* custom value */
	this._div = OAT.Dom.create("div"); /* our content */
	this._sign = false; /* +- image */
	this._icon = false; /* icon/checkbox */
	this._label = OAT.Dom.create("span"); /* label */
	this._gdElm = OAT.Dom.create("span"); /* icon+label */
	if (ul) { ul.style.listStyleType = "none"; }
	self._div.obj = self;
	this.hasEvents = false;
	this.gdMode = 0;

	/* create structure:
		<li>
			<div>
				<span>indent...</span>
				<img sign> (optional)
				<gdElm>
					<img icon> (optional)
					label...
				</gdElm>
			</div>
			<ul>...
		</li>
	*/
	if (self.li) {
		self.li.style.margin = "0px";
		self.li.style.padding = "0px";
		self.li.style.paddingLeft = "32px";
		self.li.style.textIndent = "-32px";
		var n = self.li.firstChild;
		while (n && n != self.ul) {
			var nn = n.nextSibling;
			self._label.appendChild(n);
			n = nn;
		}
		OAT.Dom.clear(self.li);
		OAT.Dom.append([self._gdElm,self._label],[self._div,self._gdElm],[self.li,self._div]);
		if (self.ul) {
			self.li.appendChild(self.ul);
		}
	}

	if (self.ul) { /* margin & padding */
		self.ul.style.margin = "0px";
		self.ul.style.padding = "0px";
		if (self.parent) { self.ul.style.marginLeft = "-16px"; }
	}

	if (self.options.checkboxMode && self.li) { /* checkboxes */
		self.checkbox = OAT.Dom.create("input",{verticalAlign:"middle"});
		self.checkbox.type = "checkbox";
		if (self.options.defaultCheck) {
			self.checkbox.checked = true;
			self.checkbox.__checked = "1";
		}
		if (self.checkbox.checked == self.options.checkNOI) {
			self.root.checkedNOI.push(self);
		}
		self._gdElm.insertBefore(self.checkbox,self._label); /* instead of icon */
	}

	if (self.li) { /* custom image */
		for (var i=0;i<self.li.attributes.length;i++) {
			var a = self.li.attributes[i];
			if (a.nodeName == "oat:treeimage") { self.customImage = a.nodeValue; }
		}
	}

	this.toggleCheck = function(event) {
		/* 1. toggle checkbox for all descendant nodes, 2. actualize checked list, 3. callback */
		if (self.checkbox.checked) {
			self.checkbox.__checked = "1";
			self.checkUp(true);
		} else {
			self.checkbox.__checked = "0";
		}
		if (self.ul) {
			var func = (self.checkbox.checked ? "checkAll" : "uncheckAll");
			self.walk(func);
		}

		self.root.checkedNOI = [];
		self.root.walk("updateNOI");

		self.options.checkCallback(self.root.checkedNOI);
	}

	this.updateNOI = function() {
		var ch = (self.checkbox.__checked == "1" || self.checkbox.checked);
		if (ch == self.options.checkNOI) { self.root.checkedNOI.push(self); }
	}

	this.checkAll = function() {
		self.checkbox.checked = true;
		self.checkbox.__checked = "1";
	}

	this.uncheckAll = function() {
		self.checkbox.checked = false;
		self.checkbox.__checked = "0";
	}

	this.checkUp = function(firstLevel) {
		if (self.checkbox.checked && !firstLevel) { return; }
		if (!firstLevel) {
			self.checkbox.checked = true;
			self.checkbox.__checked = "1";
		}
		if (self.parent && self.parent.li) { self.parent.checkUp(false); }
	}

	this.toggleState = function(event) {
		self.state ? self.collapse() : self.expand();
	}

	this.toggleSelect = function(event) {
		if (event.ctrlKey || (OAT.Browser.isMac && event.metaKey)) {
			if (self.selected) { self.deselect(); } else { self.select(); }
		} else {
			while (self.root.selectedNodes.length) { self.root.selectedNodes[0].deselect(); }
			self.select();
		}
	}

	this.select = function() {
		self.selected = 1;
		self.root.selectedNodes.push(self);
		OAT.Dom.addClass(self.li,"tree_li_selected");
		if (self.ul) { OAT.Dom.addClass(self.ul,"tree_ul_selected"); }
		self.updateStyle();
	}

	this.deselect = function() {
		self.selected = 0;
		var index = self.root.selectedNodes.indexOf(self);
		self.root.selectedNodes.splice(index,1);
		OAT.Dom.removeClass(self.li,"tree_li_selected");
		if (self.ul) { OAT.Dom.removeClass(self.ul,"tree_ul_selected"); }
		self.updateStyle();
	}

	this.firstSync = function(depth) {
		self.depth = depth;
		self.addDecorations();
		self.addEvents();
		self.updateStyle();
	}

	this.sync = function(depth) {
		self.removeEvents();
		self.removeDecorations();
		self.depth = depth;
		self.addDecorations();
		self.addEvents();
		self.updateStyle();
	}

	this.removeEvents = function() {
		if (!self.li) { return; }
		if (!self.hasEvents) { return; } /* nothing to remove */

		switch (self.options.onClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Event.detach(self._label,"click",self.toggleSelect);
					OAT.Event.detach(self._icon,"click",self.toggleSelect);
				}
			break;

			case "toggle":
				if (self.ul) {
					OAT.Event.detach(self._label,"click",self.toggleState);
					OAT.Event.detach(self._icon,"click",self.toggleState);
				}
			break;
		}

		switch (self.options.onClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Event.detach(self._label,"dblclick",self.toggleSelect);
					OAT.Event.detach(self._icon,"dblclick",self.toggleSelect);
				}
			break;

			case "toggle":
				if (self.ul) {
					OAT.Event.detach(self._label,"dblclick",self.toggleState);
					OAT.Event.detach(self._icon,"dblclick",self.toggleState);
				}
			break;
		}

		if (self.options.poorMode) { return; }

		if (self.ul) { OAT.Event.detach(self._sign,"click",self.toggleState); } /* +- sign */

		if (self.options.checkboxMode) { OAT.Event.detach(self.checkbox,"change",self.toggleCheck); }

		if (self.options.allowDrag) {
			self.root.gd.delTarget(self._gdElm);
			self.root.gd.delSource(self._gdElm);
		}
	}

	this.addEvents = function() {
		self.hasEvents = true;
		if (!self.li) { return; }

		switch (self.options.onClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Event.attach(self._label,"click",self.toggleSelect);
					OAT.Event.attach(self._icon,"click",self.toggleSelect);
				}
			break;

			case "toggle":
				if (self.ul) {
					OAT.Event.attach(self._label,"click",self.toggleState);
					OAT.Event.attach(self._icon,"click",self.toggleState);
				}
			break;
		}

		switch (self.options.onDblClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Event.attach(self._label,"dblclick",self.toggleSelect);
					OAT.Event.attach(self._icon,"dblclick",self.toggleSelect);
				}
			break;

			case "toggle":
				if (self.ul) {
					OAT.Event.attach(self._label,"dblclick",self.toggleState);
					OAT.Event.attach(self._icon,"dblclick",self.toggleState);
				}
			break;
		}

		if (self.options.poorMode) { return; }

		if (self.ul) { OAT.Event.attach(self._sign,"click",self.toggleState); } /* +- sign */

		/* if checkbox mode is used */
		if (self.options.checkboxMode) { OAT.Event.attach(self.checkbox,"change",self.toggleCheck); }

		if (!self.options.allowDrag) { return; }

		var procRef = function(elm) {}
		var backRef = function(target,x,y) { /* ghostdrag ended; some re-structuring? */
			var node = target.obj;
			/* ignore self2self drag, ancestor cannot be dragged to its children */
			var ancestTest = true;
			var curr = node
			while (curr) {
				if (curr == self) { ancestTest = false; }
				curr = curr.parent;
			}
			if (!ancestTest) { return; }

			/* analyze X coordinate: when above icon, then append, else reposition */
			var mode = node.gdMode;

			function isLast(n) {
				return (n.parent.children.indexOf(n) == n.parent.children.length-1);
			}

			if (mode == 1) {
				/* check appending after last node */
				while (node.parent && node.parent.parent && isLast(node)) { node = node.parent; }

				/* reposition after target */
				var index = node.parent.children.indexOf(node)+1;
				node.parent.appendChild(self,index);
			} else {
				/* append */
				node.appendChild(self);
				node.expand();
			}
		}
		if (self.options.allowDrag) {
			self.root.gd.addTarget(self._div);
			self.root.gd.addSource(self._gdElm,procRef,backRef);
		}
	}

	this.removeDecorations = function() {
		if (!self.li) { return; }
		if (self.options.poorMode) { return; }
		OAT.Dom.removeClass(self.li,"tree_li_"+self.depth);
		OAT.Dom.removeClass(self.li.parentNode,"tree_ul_"+self.depth);
		if (self._sign) {
			OAT.Dom.unlink(self._sign);
			self._sign = false;
		}
		if (self._icon) {
			OAT.Dom.unlink(self._icon);
			self._icon = false;
		}
	}

	this.addDecorations = function() {
		if (!self.li) { return; }

		OAT.Dom.addClass(self.li,"tree_li_"+self.depth);
		OAT.Dom.addClass(self.li.parentNode,"tree_ul_"+self.depth);

		if (self.options.poorMode) { return; }

		var sign = OAT.Dom.create("img",{width:self.options.size+"px",height:self.options.size+"px",verticalAlign:"middle"});

		self._div.insertBefore(sign,self._gdElm);

		if (self.options.checkboxMode) {
			var icon = false;
		} else {
			var icon = OAT.Dom.create("img",{width:self.options.size+"px",height:self.options.size+"px",verticalAlign:"middle"});
			icon.style.marginRight = "2px";
			self._gdElm.insertBefore(icon,self._label);
		}
		self._sign = sign;
		self._icon = icon;

		if (self.parent.children[self.parent.children.length-1] == self) { OAT.Dom.addClass(self.li,"tree_li_last"); }
	}

	this.setImage = function(newImage) {
		self.customImage = newImage;
		self.updateStyle();
	}

	this.expand = function(silent) {
		if (self.options.onlyOneOpened) {
			/* close all opened siblings */
			for (var i=0;i<self.parent.children.length;i++) {
				var sibl = self.parent.children[i];
				if (sibl.state) { sibl.collapse(); }
			}
		}
		self.state = 1;
		self.updateStyle();
		if (!silent) { OAT.MSG.send(self.root,"TREE_EXPAND",self); }
	}

	this.collapse = function() {
		/* check children for selection. if at lease one descendant is selected, select this node */
		if (self.options.ascendSelection) {
			var list = self.testForSelected();
			var willSelect = (list.length > 1 || (list.length == 1 && list[0] != self));
			for (var i=0;i<list.length;i++) if (list[i] != self) { list[i].deselect(); }
			if (!self.selected && willSelect) { self.select(); }
		}
		self.state = 0;
		self.updateStyle();
		OAT.MSG.send(self.root,"TREE_COLLAPSE",self);
	}

	this.testForSelected = function() {
		var selected = [];
		if (self.selected) { selected.push(self); }
		for (var i=0;i<self.children.length;i++) {
			selected.append(self.children[i].testForSelected());
		}
		return selected;
	}

	this.updateStyle = function() { /* adjust icon contents as needed */
		var signName = "blank";
		if (self.ul) { /* unless specified otherwise, all non-leaf nodes are expanded */
			if (self._icon) { self._icon.style.cursor = "pointer"; }
			if (self._sign) { self._sign.style.cursor = "pointer"; }
			if (self.state) {
				signName = "minus";
				OAT.Dom.show(self.ul);
				OAT.Dom.addClass(self.li,"tree_li_expanded");
				OAT.Dom.addClass(self.ul,"tree_ul_expanded");
				OAT.Dom.removeClass(self.li,"tree_li_collapsed");
				OAT.Dom.removeClass(self.ul,"tree_ul_collapsed");
			} else {
				signName = "plus";
				OAT.Dom.hide(self.ul);
				OAT.Dom.removeClass(self.li,"tree_li_expanded");
				OAT.Dom.removeClass(self.ul,"tree_ul_expanded");
				OAT.Dom.addClass(self.li,"tree_li_collapsed");
				OAT.Dom.addClass(self.ul,"tree_ul_collapsed");
			}
			if (self.selected) {
				var iconName = self.ul.getAttribute('expandedImg') ? self.ul.getAttribute('expandedImg') : "node-expanded";
			} else {
				var iconName = self.ul.getAttribute('collapsedImg') ? self.ul.getAttribute('collapsedImg') : "node-collapsed";
			}
		} else {
			var iconName = self.li.getAttribute('leafImg') ? self.li.getAttribute('leafImg') : "leaf";
			if (self._icon) { self._icon.style.cursor = ""; }
			if (self._sign) { self._sign.style.cursor = ""; }
		}

		if (self.customImage) {
			iconName = self.customImage;
		}

		self.applyImage(self._icon,iconName);
		self.applyImage(self._sign,signName);
		if (self.options.useDots && self.li) {
			var dots = (self.parent.children[self.parent.children.length-1] == self ? "dots-part" : "dots-full");
			self.applyBackground(self.li,dots);
			self.li.style.backgroundRepeat = (dots == "dots-full" ? "repeat-y" : "no-repeat");
			self.applyBackground(self._sign,"dots-horiz");
		}

	}

	this.walk = function(methodName,depth) {
		self[methodName](depth);
		for (var i=0;i<self.children.length;i++) {
			self.children[i].walk(methodName,depth+1);
		}
	}

	this.applyBackground = function(img,name) {
		if (!img) { return; }
		var o = self.options;
		var path = o.imagePath + "Tree_" + (o.imagePrefix=="" ? "" : o.imagePrefix+"_") + name + ".gif";
		img.style.backgroundImage = 'url("'+path+'")';
	}

	this.applyImage = function(img,name) {
		if (!img) { return; }
		var o = self.options;
		var sub = name.substr(name.length-4);
		if ( name.substr(0,1)=="/" || name.substr(0,5)=="http:" || name.substr(0.6)=="https:") {
			var path = name; /* absolute path, full filename */
		} else if (sub==".png" || sub==".gif" || sub==".jpg" || name.substr(name.length-5)==".jpeg") {
			var path = o.imagePath + name; /* relative path, full filename */
		} else  {
			var path = o.imagePath + "Tree_" + (o.imagePrefix=="" ? "" : o.imagePrefix+"_") + name + "." + o.ext; /* default path, generated filename */
		}
		var pathB = o.imagePath + "Blank.gif";
		OAT.Dom.imageSrc(img,path,pathB);
	}

	this.appendChild = function(oldNode,index,ignoreOldParent) {
		/* insert before node at position [index] */
		var idx = ( (index || index == 0) ? index : self.children.length);
		var oldParent = oldNode.parent;
		if (!ignoreOldParent) { var oldIdx = oldParent.children.indexOf(oldNode); }
		/* basic check */
		if (!self.ul) {
			self.ul = OAT.Dom.create("ul",{margin:"0px",padding:"0px"});
			self.li.appendChild(self.ul);
			self.ul.style.listStyleType = "none";
		}

		/* 1. DOM */
		if (self.children.length && idx < self.children.length) {
			var afterSibling = self.children[idx];
			self.ul.insertBefore(oldNode.li,afterSibling.li);
		} else {
			self.ul.appendChild(oldNode.li);
		}

		/* 2. JS structure */
		self.children.splice(idx,0,oldNode);
		if (!ignoreOldParent) {
			if (self == oldParent && idx <= oldIdx) { oldIdx++; }
			oldParent.children.splice(oldIdx,1);
		}
		oldNode.parent = self;

		/* remaining bits */
		self.root.walk("sync");
	}

	this.deleteChild = function(oldNode) {
		var index = self.children.indexOf(oldNode);
		if (index == -1) { return; }
		self.children.splice(index,1);
		OAT.Dom.unlink(oldNode.li);
	}

	this.createChild = function(label,isNode,index,value) {
		var li = OAT.Dom.create("li");
		var ul = false;
		if (isNode) {
			var ul = OAT.Dom.create("ul");
			li.appendChild(ul);
		}
		var child = new OAT.TreeNode(li,ul,self,self.root,value);
		child.setLabel(label);
		if (index === false) { index = undefined; }
		self.appendChild(child,index,true);
		return child;
	}

	this.setLabel = function(newLabel) { self._label.innerHTML = newLabel; }
	this.getLabel = function() { return self._label.innerHTML; }

	this.setValue = function(newValue) { self.value = newValue; }
	this.getValue = function() { return self.value; }

	this.removeSignal = function() {
		self.gdMode = 0;
		self._label.style.fontWeight = "normal";
		self._div.style.borderBottom = "none";
	}

	this.checkSignal = function() {
		var e = self.root.gdEvent;
		var pos = OAT.Dom.position(self._div);
		var dims = OAT.Dom.getWH(self._div);
		var epos = OAT.Event.position(e);

		var hit = 0;

		if (epos[0] > pos[0] && epos[0] < pos[0]+dims[0] &&
			epos[1] > pos[1] && epos[1] < pos[1]+dims[1]) {
			hit = 1;
		}

		if (!hit) {
			if (self.gdMode) { self.removeSignal(); }
			return;
		}

		/* check for gdElm over */
		var pos = OAT.Dom.position(self._gdElm);
		var dims = OAT.Dom.getWH(self._gdElm);
		if (epos[0] > pos[0] && epos[0] < pos[0]+dims[0] &&
			epos[1] > pos[1] && epos[1] < pos[1]+dims[1]) {
			hit = 2;
		}


		if (hit == 2 && self.ul) {
			self._label.style.fontWeight = "bold";
			self._div.style.borderBottom = "none";
			self.gdMode = 2;
		} else {
			self._label.style.fontWeight = "normal";
			self._div.style.borderBottom = "1px dotted #888";
			self.gdMode = 1;
		}

	}

	return self;
}

OAT.Tree = function(optObj) {
	var self = this;
	this.options = {
		imagePath:OAT.Preferences.imagePath,
		imagePrefix:"",
		ext:"png",
		onlyOneOpened:0,
		size:16,
		allowDrag:false,
		ascendSelection:true,
		useDots:true,
		onClick:"select", /* select|toggle|false */
		onDblClick:"toggle", /* select|toggle|false */

		poorMode:false, /* performance increase */

		checkboxMode:false, /* checkboxes instead of filders */
		defaultCheck:true, /* checkboxes checked by default? */
		checkNOI:true, /* Nodes Of Interest: true == checked, false == unchecked */
		checkCallback:function(){}
	}
	this.tree = false; /* data structure */
	this.selectedNodes = [];
	this.checkedNOI = [];

	this.gd = new OAT.GhostDrag();

	for (var p in optObj) { self.options[p] = optObj[p]; }

	this.dragging = false;

	this.gdStart = function() {
		self.dragging = true;
	}

	this.gdEnd = function() {
		self.dragging = false;
		self.walk("removeSignal");
	}

	this.gdMove = function(event) {
		if (!self.dragging) { return; }
		self.gdEvent = event;
		self.walk("checkSignal")
	}

	this.walk = function(methodName) {
		for (var i=0;i<self.tree.children.length;i++) {
			self.tree.children[i].walk(methodName,1);
		}
	}

	this.assign = function(listElm,collapse) {
		var ul = $(listElm);
		ul.style.listStyleType = "none";

		if (self.options.allowDrag) {
			OAT.MSG.attach(self.gd,"GD_START",self.gdStart);
			OAT.MSG.attach(self.gd,"GD_END",self.gdEnd);
			OAT.MSG.attach(self.gd,"GD_ABORT",self.gdEnd);
			OAT.Event.attach(document,"mousemove",self.gdMove);
		}

		/* get a mirror of existing structure */
		self.tree = new OAT.TreeNode(false,ul,false,self,false);
		var list = ul.childNodes;
		for (var i=0;i<list.length;i++) {
			if (list[i].tagName && list[i].tagName.toLowerCase() == "li") {
				var child = self.scanList(list[i],self.tree);
				self.tree.children.push(child);
			}
		}
		self.walk("firstSync");
		if (collapse) { self.walk("collapse"); }
	}

	this.scanList = function(node,parent) {
		/* find child ul if exists */
		var candidate = false;
		for (var i=0;i<node.childNodes.length;i++) {
			var c = node.childNodes[i];
			if (!candidate && c.tagName && c.tagName.toLowerCase() == "ul") { candidate = c; }
		}

		var obj = new OAT.TreeNode(node,candidate,parent,self);
		if (!candidate) { return obj; }

		var list = candidate.childNodes;
		for (var i=0;i<list.length;i++) {
			if (list[i].tagName && list[i].tagName.toLowerCase() == "li") {
				var child = self.scanList(list[i],obj);
				obj.children.push(child);
			}
		}
		return obj;
	}
}
