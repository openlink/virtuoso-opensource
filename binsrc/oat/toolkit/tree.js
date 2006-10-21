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
	OAT.Tree.assign(listElm,options)
*/

OAT.Tree = {
	assign:function(listElm,opts) {
		var options = {
			imagePath:"/DAV/JS/images",
			imagePrefix:"",
			ext:"gif",
			reformat:1,
			labelOpens:1,
			onlyOneOpened:0
		}
		for (var p in opts) { options[p] = opts[p]; }
		var elm = $(listElm);
		OAT.Tree.recursiveWalk(elm,1,options);
	},
	
	toggle:function(elm,options,ignore) {
		if (elm.tagName.toLowerCase() != "ul" || elm.parentNode.tagName.toLowerCase() != "li") { return; }
		elm._Tree_status++;
		if (elm._Tree_status == 2) { elm._Tree_status = 0; }
		OAT.Tree.update(elm,options);
		/* close other opened branches? */
		if (options.onlyOneOpened && !ignore) {
			var siblings = [];
			var all = elm.parentNode.parentNode.childNodes;
			for (var i=0;i<all.length;i++) {
				var li = all[i];
				if (li != elm.parentNode) { 
					/* sibling li */
					var ch = li.childNodes;
					for (var j=0;j<ch.length;j++) {
						var e = ch[j];
						if (e.tagName && e.tagName.toLowerCase() == "ul" && e._Tree_status) { OAT.Tree.toggle(e,options,true); }
					} /* for all uls */
				} /* if not this one */
			} /* for all sibling branches */
		} /* if only one opened */
	},
	
	update:function(elm,options) {
		var parent = elm.parentNode;
		OAT.Dom.removeClass(elm,"tree_expanded");
		OAT.Dom.removeClass(elm,"tree_collapsed");
		OAT.Dom.removeClass(parent,"tree_expanded");
		OAT.Dom.removeClass(parent,"tree_collapsed");
		if (elm._Tree_status) { 
			OAT.Dom.addClass(parent,"tree_expanded");
			OAT.Dom.addClass(elm,"tree_expanded");
			OAT.Dom.show(elm);
			OAT.Tree.applyImage(parent._Tree_signIcon,"minus",options);
			OAT.Tree.applyImage(parent._Tree_treeIcon,"node-collapsed",options);
		} else {
			OAT.Dom.addClass(parent,"tree_collapsed");
			OAT.Dom.addClass(elm,"tree_collapsed");
			OAT.Dom.hide(elm);
			OAT.Tree.applyImage(parent._Tree_signIcon,"plus",options);
			OAT.Tree.applyImage(parent._Tree_treeIcon,"node-collapsed",options);
		}
	},

	clear:function(elm) {
		if (elm._Tree_signIcon) { OAT.Dom.unlink(elm._Tree_signIcon); elm._Tree_signIcon = false; }
		if (elm._Tree_treeIcon) { OAT.Dom.unlink(elm._Tree_treeIcon); elm._Tree_treeIcon = false; }
		OAT.Dom.removeClass(elm,"tree_expanded");
		OAT.Dom.removeClass(elm,"tree_collapsed");
	},

	applyImage:function(elm,name,options) {
		var path = options.imagePath + "/" + "Tree_" + (options.imagePrefix=="" ? "" : options.imagePrefix+"_") + name + "." + options.ext;
		if (OAT.Dom.isIE() && options.ext.toLowerCase() == "png") {
			elm.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+path+"', sizingMethod='crop')";
		} else {
			elm.style.backgroundImage = "url("+path+")";
		}
	},
	
	recursiveWalk:function(node,depth,options) {
		OAT.Tree.clear(node);
		var temp = node.childNodes;
		var childNodes = [];
		for (var i=0;i<temp.length;i++) { childNodes.push(temp[i]); }
		var str = (node.tagName ? node.tagName : "");
		switch (str.toLowerCase()) {
			case "ul":
				var cName = "tree_level_" + Math.ceil(depth/2);
				OAT.Dom.addClass(node,cName);
				OAT.Dom.addClass(node,"tree_expanded");
				var parent = node.parentNode;
				node.style.listStyleType = "none";
				if (parent.tagName.toLowerCase() == "li") {
					parent._Tree_treeIcon.style.cursor = "pointer";
					parent._Tree_signIcon.style.cursor = "pointer";
					OAT.Tree.applyImage(parent._Tree_signIcon,"minus",options);
					OAT.Tree.applyImage(parent._Tree_treeIcon,"node-expanded",options);
					OAT.Dom.attach(parent._Tree_signIcon,"click",function(){OAT.Tree.toggle(node,options);});
					OAT.Dom.attach(parent._Tree_treeIcon,"click",function(){OAT.Tree.toggle(node,options);});
					/* if clicking label results in toggling... */
					var candidate = parent.childNodes[2];
					if (options.labelOpens && candidate != node && !OAT.Dom.isIE()) { /* ie doesn't allow onclick on text nodes */
						OAT.Dom.attach(candidate,"click",function(){OAT.Tree.toggle(node,options);});
				}
					if (!("_Tree_status" in node)) { node._Tree_status = 1; }
					if (options.reformat) {
					if (depth > 1) {
						/* if specified, we collapse all deep levels */
							node._Tree_status = 0;
					} else {
							node._Tree_status = 1;
						}
					}
					OAT.Tree.update(node,options);
				}
			break; /* ul */
			
			case "li":
				var cName = "tree_level_" + Math.ceil(depth/2);
				OAT.Dom.addClass(node,cName);
				var tree = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
				tree.style.marginRight = "2px";
				tree.style.backgroundRepeat = "no-repeat";
				OAT.Tree.applyImage(tree,"leaf",options);
				var sign = OAT.Dom.create("div",{"width":"16px","height":"16px","cssFloat":"left","styleFloat":"left"});
				sign.style.backgroundRepeat = "no-repeat";
				OAT.Tree.applyImage(sign,"blank",options);
				node._Tree_treeIcon = tree;
				node._Tree_signIcon = sign;
				if (childNodes.length) {
					node.insertBefore(tree,childNodes[0]);
					node.insertBefore(sign,tree);
				} else {
					node.appendChild(sign);
					node.appendChild(tree);
				}
			break; /* li */
		}
		
		/* recursion */
		for (var i=0;i<childNodes.length;i++) {
			OAT.Tree.recursiveWalk(childNodes[i],depth+1,options);
		}
	}
}
OAT.Loader.pendingCount--;
