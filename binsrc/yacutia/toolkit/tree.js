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
	Tree.assign(div,dir,ext,reformat)
*/

var Tree = {
	imagePath:function(dir, name, ext) {
		return "url("+dir+"/Tree_"+name+"."+ext+")";
	},

	assign:function(div,dir,ext,reformat) {
		var elm = $(div);
		Tree.recursiveWalk(elm,1,dir,ext,reformat);
	},
	
	recursiveWalk:function(node,depth,dir,ext,reformat) {
		if (node._Tree_signIcon) { node.removeChild(node._Tree_signIcon); node._Tree_signIcon = false; }
		if (node._Tree_treeIcon) { node.removeChild(node._Tree_treeIcon); node._Tree_treeIcon = false; }
		var temp = node.childNodes;
		var childNodes = [];
		for (var i=0;i<temp.length;i++) { childNodes[childNodes.length] = temp[i]; }
		var str = (node.tagName ? node.tagName : "");
		
		switch (str.toLowerCase()) {
			case "ul":
				var parent = node.parentNode;
				node.style.listStyleType = "none";
				node._Tree_toggle = function() {
					if (this._Tree_collapsed) { this._Tree_collapsed = 0; } else { this._Tree_collapsed = 1; }
					this._Tree_update();
				};
				node._Tree_update = function() {
					if (parent.tagName.toLowerCase() != "li") return;
					if (this._Tree_collapsed) {
						this.style.display = "none";
						parent._Tree_signIcon.style.backgroundImage = Tree.imagePath(dir,"plus",ext);
					} else {
						this.style.display = "block";
						parent._Tree_signIcon.style.backgroundImage = Tree.imagePath(dir,"minus",ext);
					}
				}
				if (parent.tagName.toLowerCase() == "li") {
					parent._Tree_signIcon.style.cursor = "pointer";
					parent._Tree_treeIcon.style.backgroundImage = Tree.imagePath(dir,"node",ext);
					parent._Tree_signIcon.style.backgroundImage = Tree.imagePath(dir,"minus",ext);
					var ref=function() { node._Tree_toggle(); }
					Dom.attach(parent._Tree_signIcon,"click",ref);
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
				var tree = Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
				tree.style.marginRight = "2px";
				tree.style.backgroundImage = Tree.imagePath(dir,"leaf",ext);
				tree.style.backgroundRepeat = "no-repeat";
				var sign = Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
				sign.style.backgroundImage = Tree.imagePath(dir,"blank",ext);
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
			Tree.recursiveWalk(childNodes[i],depth+1,dir,ext,reformat);
		}
	}
}
