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
	OAT.Tree.assign(div,dir,ext,reformat)
*/

OAT.Tree = {
	applyImage:function(elm,dir,name,ext) {
		if (OAT.Dom.isIE() && ext.toLowerCase() == "png") {
			var path = dir + "/Tree_"+name+"."+ext;
			elm.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='crop')";
		} else {
			elm.style.backgroundImage = OAT.Tree.imagePath(dir,name,ext);
		}
	},

	imagePath:function(dir, name, ext) {
		return "url("+dir+"/Tree_"+name+"."+ext+")";
	},

	assign:function(div,dir,ext,reformat,classNamePrefix) {
		var elm = $(div);
		OAT.Tree.recursiveWalk(elm,1,dir,ext,reformat,classNamePrefix);
	},
	
	recursiveWalk:function(node,depth,dir,ext,reformat,classNamePrefix) {
		if (node._Tree_signIcon) { node.removeChild(node._Tree_signIcon); node._Tree_signIcon = false; }
		if (node._Tree_treeIcon) { node.removeChild(node._Tree_treeIcon); node._Tree_treeIcon = false; }
		var temp = node.childNodes;
		var childNodes = [];
		for (var i=0;i<temp.length;i++) { childNodes.push(temp[i]); }
		var str = (node.tagName ? node.tagName : "");
		
		switch (str.toLowerCase()) {
			case "ul":
				var cName = classNamePrefix + "_ul_" + Math.ceil(depth/2);
				OAT.Dom.addClass(node,cName);
				var parent = node.parentNode;
				node.style.listStyleType = "none";
				node._Tree_toggle = function() {
					if (this._Tree_collapsed) { this._Tree_collapsed = 0; } else { this._Tree_collapsed = 1; }
					this._Tree_update();
				};
				node._Tree_update = function() {
					if (parent.tagName.toLowerCase() != "li") return;
					if (this._Tree_collapsed) {
						OAT.Dom.hide(this);
						OAT.Tree.applyImage(parent._Tree_signIcon,dir,"plus",ext);
						OAT.Tree.applyImage(parent._Tree_treeIcon,dir,"node-collapsed",ext);
					} else {
						OAT.Dom.show(this);
						OAT.Tree.applyImage(parent._Tree_signIcon,dir,"minus",ext);
						OAT.Tree.applyImage(parent._Tree_treeIcon,dir,"node-expanded",ext);
					}
				}
				if (parent.tagName.toLowerCase() == "li") {
					parent._Tree_treeIcon.style.cursor = "pointer";
					parent._Tree_signIcon.style.cursor = "pointer";
					OAT.Tree.applyImage(parent._Tree_signIcon,dir,"minus",ext);
					OAT.Tree.applyImage(parent._Tree_treeIcon,dir,"node-expanded",ext);
					var ref=function() { node._Tree_toggle(); }
					OAT.Dom.attach(parent._Tree_signIcon,"click",ref);
					OAT.Dom.attach(parent._Tree_treeIcon,"click",ref);
				}
				
				if (reformat) {
					if (depth > 1) {
						/* if specified, we collapse all deep levels */
						node._Tree_collapsed = 1;
						node._Tree_update();
					} else {
						node._Tree_collapsed = 0;
						node._Tree_update();
					}
				}
			break;
			
			case "li":
				var cName = classNamePrefix + "_li_" + Math.ceil(depth/2);
				OAT.Dom.addClass(node,cName);
				var tree = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
				tree.style.marginRight = "2px";
				OAT.Tree.applyImage(tree,dir,"leaf",ext);
				tree.style.backgroundRepeat = "no-repeat";
				var sign = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
				OAT.Tree.applyImage(sign,dir,"blank",ext);
				sign.style.backgroundRepeat = "no-repeat";
				node._Tree_treeIcon = tree;
				node._Tree_signIcon = sign;
				if (childNodes.length) {
					node.insertBefore(tree,childNodes[0]);
					node.insertBefore(sign,tree);
				} else {
					node.appendChild(sign);
					node.appendChild(tree);
				}
			break;
		}
		
		/* recursion */
		for (var i=0;i<childNodes.length;i++) {
			OAT.Tree.recursiveWalk(childNodes[i],depth+1,dir,ext,reformat,classNamePrefix);
		}
	}
}
OAT.Loader.pendingCount--;
