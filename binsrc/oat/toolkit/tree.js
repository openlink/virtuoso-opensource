/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
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
	node.setImage(newImage)
	node.appendChild(oldNode, [index])
	node.deleteChild(oldNode)
	node.createChild(label, isNode, [index])
	
*/

OAT.TreeNode = function(li,ul,parent,root) {
	/* this.parent.ul == li.parentNode */
	var self = this;
	this.ul = ul;
	this.li = li;
	this.parent = parent;
	this.root = root;
	this.children = [];
	this.depth = -1;
	this.state = 1; /* 0 - collapsed, 1 - expanded */
	this.selected = 0;
	this.customImage = false;
	this.label = false;
	
	if (ul) { ul.style.listStyleType = "none"; }

	this.signIcon = false;
	this.treeIcon = false;
	this.options = root.options;
	this.gdElm = OAT.Dom.create("span");
	self.gdElm.obj = self;
	
	this.hasEvents = false;
	
	/* create SPAN as label */
	if (!self.li) {
		self.label = false;
	} else {
		self.label = self.li.firstChild;
		if (!self.label) { /* if no child nodes, create empty span */
			var span = OAT.Dom.create("span");
			self.li.appendChild(span);
			self.label = span;
		} else if (self.label.nodeType == 3) { /* if text node, encapsulate within a span */
			var span = OAT.Dom.create("span");
			self.label.parentNode.replaceChild(span,self.label);
			span.appendChild(self.label);
			self.label = span;
		} else if (self.label == self.ul) { /* if firstChild == ul, insert a span */
			var span = OAT.Dom.create("span");
			self.li.insertBefore(span,self.ul);
			self.label = span;
		}
		self.label.parentNode.replaceChild(self.gdElm,self.label);
		self.gdElm.appendChild(self.label);
	}

	if (self.options.checkboxMode && self.li) {
		self.checkbox = OAT.Dom.create("input");
		self.checkbox.type = "checkbox";
		if (self.options.defaultCheck) { 
			self.checkbox.checked = true; 
			self.checkbox.__checked = "1";
		}
		if (self.checkbox.checked == self.options.checkNOI) {
			self.root.checkedNOI.push(self);
		}
		self.li.insertBefore(self.checkbox,self.gdElm);
	}
	

	/* custom image? */
	if (self.li) {
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
		if (event.ctrlKey) {
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
		var index = self.root.selectedNodes.find(self);
		self.root.selectedNodes.splice(index,1);
		OAT.Dom.removeClass(self.li,"tree_li_selected");
		if (self.ul) { OAT.Dom.removeClass(self.ul,"tree_ul_selected"); }
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
		if (!self.hasEvents) { return; }
		
		switch (self.options.onClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Dom.detach(self.label,"click",self.toggleSelect);
					OAT.Dom.detach(self.treeIcon,"click",self.toggleSelect);
				}
			break;
			
			case "toggle":
				if (self.ul) {
					OAT.Dom.detach(self.label,"click",self.toggleState);
					OAT.Dom.detach(self.treeIcon,"click",self.toggleState);
				}
			break;
		}
		
		switch (self.options.onClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Dom.detach(self.label,"dblclick",self.toggleSelect);
					OAT.Dom.detach(self.treeIcon,"dblclick",self.toggleSelect);
				}
			break;
			
			case "toggle":
				if (self.ul) {
		OAT.Dom.detach(self.label,"dblclick",self.toggleState);
		OAT.Dom.detach(self.treeIcon,"dblclick",self.toggleState);
		}
			break;
		}
		
		if (self.options.poorMode) { return; }

		if (self.ul) { OAT.Dom.detach(self.signIcon,"click",self.toggleState); } /* +- sign */
		
		if (self.options.checkboxMode) { OAT.Dom.detach(self.checkbox,"change",self.toggleCheck); }
		
		if (self.options.allowDrag) {
			self.root.gd.delTarget(self.gdElm);
			self.root.gd.delSource(self.gdElm);
		}
	}
	
	this.checkGD = function(x,y) {
		var pos = OAT.Dom.position(self.gdElm);
		var dims = OAT.Dom.getWH(self.gdElm);
		return (y >= pos[1] && y <= pos[1]+dims[1]);
	}
	
	this.addEvents = function() {
		self.hasEvents = true;
		if (!self.li) { return; }
		
		switch (self.options.onClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Dom.attach(self.label,"click",self.toggleSelect);
					OAT.Dom.attach(self.treeIcon,"click",self.toggleSelect);
				}
			break;

			case "toggle":
		if (self.ul) {
					OAT.Dom.attach(self.label,"click",self.toggleState);
					OAT.Dom.attach(self.treeIcon,"click",self.toggleState);
				}
			break;
		}
		
		switch (self.options.onDblClick) {
			case "select":
				if (!self.options.poorMode) {
					OAT.Dom.attach(self.label,"dblclick",self.toggleSelect);
					OAT.Dom.attach(self.treeIcon,"dblclick",self.toggleSelect);
		}
			break;
		
			case "toggle":
				if (self.ul) {
					OAT.Dom.attach(self.label,"dblclick",self.toggleState);
					OAT.Dom.attach(self.treeIcon,"dblclick",self.toggleState);
			}
			break;
		}
		
		if (self.options.poorMode) { return; }

		if (self.ul) { OAT.Dom.attach(self.signIcon,"click",self.toggleState); } /* +- sign */
		
		/* if checkbox mode is used */
		if (self.options.checkboxMode) { OAT.Dom.attach(self.checkbox,"change",self.toggleCheck); }
		
		if (!self.options.allowDrag) { return; }
		
		var procRef = function(elm) {}
		var backRef = function(target,x,y) { /* ghostdrag ended; some re-structuring? */
			var t = target.obj;
			/* ignore self2self drag, ancestor cannot be dragged to its children */
			var ancestTest = true;
			var curr = t;
			while (curr) {
				if (curr == self) { ancestTest = false; }
				curr = curr.parent;
			}
			if (!ancestTest) { return; }

			/* analyze X coordinate: when above icon, then append, else reposition */
			var pos = OAT.Dom.position(t.treeIcon);
			var dims = OAT.Dom.getWH(t.treeIcon);
			if (x < pos[0] || x > pos[0]+dims[0] || !t.ul) {
				/* reposition */
				var index = t.parent.children.find(t);
				var myindex = self.parent.children.find(self);
				if (t.parent == self.parent && myindex+1 == index) { index++; } /* when moving last-1 to last */
				t.parent.appendChild(self,index);
			} else {
				/* append */
				t.appendChild(self);
				t.expand();
			}
		}
		if (self.options.allowDrag) {
			self.root.gd.addTarget(self.gdElm,self.checkGD);
			self.root.gd.addSource(self.gdElm,procRef,backRef);
		}
	}
	
	
	this.removeDecorations = function() {
		if (!self.li) { return; }
		if (self.options.poorMode) { return; }
		OAT.Dom.removeClass(self.li,"tree_li_"+self.depth);
		OAT.Dom.removeClass(self.li.parentNode,"tree_ul_"+self.depth);
		if (self.signIcon) {
			OAT.Dom.unlink(self.signIcon);
			self.signIcon = false;
		}
		if (self.treeIcon) {
			OAT.Dom.unlink(self.treeIcon);
			self.treeIcon = false;
		}
	}
	
	this.addDecorations = function() {
		if (!self.li) { return; }
		if (self.options.poorMode) { return; }
		
//		var sign = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
		var sign = OAT.Dom.create("img",{"width":"16px","height":"16px"});
		sign.style.backgroundRepeat = "no-repeat";
//		var tree = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
		var tree = OAT.Dom.create("img",{"width":"16px","height":"16px"});
		tree.style.marginRight = "2px";
		tree.style.backgroundRepeat = "no-repeat";

		var l = self.li;
		if (l.childNodes.length) {
			l.insertBefore(sign,l.childNodes[0]);
		} else {
			l.appendChild(sign);
		}
		
		if (self.options.checkboxMode) {
			tree = false;
		} else {	
			self.gdElm.insertBefore(tree,self.gdElm.firstChild);
		}
		self.signIcon = sign;
		self.treeIcon = tree;
		
		if (self.parent.children[self.parent.children.length-1] == self) { OAT.Dom.addClass(self.li,"tree_li_last"); }
	}
	
	this.setImage = function(newImage) {
		self.customImage = newImage;
		self.updateStyle();
	}
	
	this.expand = function() {
		OAT.MSG.send(self.root,OAT.MSG.TREE_EXPAND,self);
		if (self.options.onlyOneOpened) {
			/* close all opened siblings */
			for (var i=0;i<self.parent.children.length;i++) {
				var sibl = self.parent.children[i];
				if (sibl.state) { sibl.collapse(); }
			}
		}
		self.state = 1;
		self.updateStyle();
	}
	
	this.collapse = function() {
		OAT.MSG.send(self.root,OAT.MSG.TREE_COLLAPSE,self);
		/* check children for selection. if at lease one descendant is selected, select this node */
		var list = self.testForSelected();
		var willSelect = (list.length > 1 || (list.length == 1 && list[0] != self));
		for (var i=0;i<list.length;i++) if (list[i] != self) { list[i].deselect(); }
		if (!self.selected && willSelect) { self.select(); }
		self.state = 0;
		self.updateStyle();
	}
	
	this.testForSelected = function() {
		var selected = [];
		if (self.selected) { selected.push(self); }
		for (var i=0;i<self.children.length;i++) { 
			selected.append(self.children[i].testForSelected());
		}
		return selected;
	}
	
	this.updateStyle = function() {
		var treeName = "leaf";
		var signName = "blank";
		if (self.ul) { /* unless specified otherwise, all non-leaf nodes are expanded */
			if (self.treeIcon) { self.treeIcon.style.cursor = "pointer"; }
			if (self.signIcon) { self.signIcon.style.cursor = "pointer"; }
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
				treeName = "node-expanded";
			} else {
				treeName = "node-collapsed";
			}
		} else {
			if (self.treeIcon) { self.treeIcon.style.cursor = ""; }
			if (self.signIcon) { self.signIcon.style.cursor = ""; }
		}
		
		if (self.customImage) {
			treeName = self.customImage;
		}
		
		self.applyImage(self.treeIcon,treeName);
		self.applyImage(self.signIcon,signName);
		
	}
	
	this.walk = function(methodName,depth) {
		self[methodName](depth);
		for (var i=0;i<self.children.length;i++) {
			self.children[i].walk(methodName,depth+1);
		}
	}
	
	this.applyImage = function(img,name) {
		if (!img) { return; }
		var o = self.options;
		var path = o.imagePath + "/" + "Tree_" + (o.imagePrefix=="" ? "" : o.imagePrefix+"_") + name + "." + o.ext;
		var pathB = o.imagePath + "/Blank.gif";
		if (OAT.Dom.isIE() && o.ext.toLowerCase() == "png") {
			img.src = pathB;
			img.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='crop')";
		} else {
			img.src = path;
		}
	}
	
	this.appendChild = function(oldNode,index,ignoreOldParent) {
		/* insert before node at position [index] */
		var idx = ( (index || index == 0) ? index : self.children.length);
		var oldParent = oldNode.parent;
		if (!ignoreOldParent) { var oldIdx = oldParent.children.find(oldNode); }
		/* basic check */
		if (!self.ul) {
			self.ul = OAT.Dom.create("ul");
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
		oldNode.sync(self.depth+1);
		if (!ignoreOldParent) { oldParent.sync(oldParent.depth); }
		self.sync(self.depth);
	}
	
	this.deleteChild = function(oldNode) {
		var index = self.children.find(oldNode);
		if (index == -1) { return; }
		self.children.splice(index,1);
		OAT.Dom.unlink(oldNode.li);
	}
	
	this.createChild = function(label,isNode,index) {
		var li = OAT.Dom.create("li");
		var ul = false;
		if (isNode) { 
			var ul = OAT.Dom.create("ul");
			li.appendChild(ul);
		}
		var child = new OAT.TreeNode(li,ul,self,self.root);
		child.setLabel(label);
		self.appendChild(child,index,true);
		return child;
	}
	
	this.setLabel = function(newLabel) { self.label.innerHTML = newLabel; }
	this.getLabel = function() { return self.label.innerHTML; }

	return self;
}

OAT.Tree = function(optObj) {
	var self = this;
	this.options = {
		imagePath:"/DAV/JS/images",
		imagePrefix:"",
		ext:"png",
		onlyOneOpened:0,
		allowDrag:false,
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
	
	this.walk = function(methodName) { 
		for (var i=0;i<self.tree.children.length;i++) { 
			self.tree.children[i].walk(methodName,1); 
		} 
	}
	
	this.assign = function(listElm,collapse) {
		var ul = $(listElm);
		ul.style.listStyleType = "none";
		
		/* get a mirror of existing structure */
		self.tree = new OAT.TreeNode(false,ul,false,self);
		var list = ul.childNodes;
		for (var i=0;i<list.length;i++) {
			if (list[i].tagName && list[i].tagName.toLowerCase() == "li") { 
				var child = self.scanList(list[i],self.tree);
				self.tree.children.push(child); 
			}
		}
		
		self.walk("sync");
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
	
	this.clear = function() {
		self.walk("removeEvents");
		if (self.tree.ul) { OAT.Dom.unlink(self.tree.ul); }
	}

}
OAT.Loader.featureLoaded("tree");
