/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
*/

OAT.GraphSidebar = function(graph) {
	var self = this;
	self.graph = graph;

	this._other = "[unqualified]";
	this._domain = "domain";
	this._range = "range";
	this._indomain = "in-domain-of";
	this._inrange = "in-range-of";

	this.isClass = function(node) {
		for (var i=0;i<node.inEdges.length;i++) {
			var e = node.inEdges[i];
			if (e.name == "a" || e.name.match(/type$/i)) { return true; }
		} /* all inEdges */
		return false;
	}

	this.filterResources = function(treeSet,propertyName) { /* do something with a set of nodes to hide */
		var d = self.graph.data; /* default - mark everything as visible */
		for (var i=0;i<d.length;i++) {
			var n = d[i];
			n.visible[propertyName] = 1;
			for (var j=0;j<n.outEdges.length;j++) {
				var e = n.outEdges[j];
				e.visible[propertyName] = 1;
			}
		}

		for (var i=0;i<treeSet.length;i++) { /* analyze unchecked nodes */
			var node = treeSet[i];
			var depth = node.depth;
			var l = node.getLabel();
			switch (depth) {
				case 1: /* resources / classes */
					/* hide all */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						if (propertyName == "sidebar1") {
							n.visible[propertyName] = 0;
						} else {
							if (self.isClass(n)) { e.visible[propertyName] = 0; }
						} /* sidebar2 */
					}
				break;

				case 2: /* resource prefix */
					/* hide resources with this prefix */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						var regs = n.name.match("^(http://[^/]+/)(.*)");
						var head = (regs ? regs[1] : self._other);
						if (propertyName == "sidebar1" && head == l) { n.visible[propertyName] = 0; }
						if (propertyName == "sidebar2" && self.isClass(n) && head == l) { n.visible[propertyName] = 0; }
					}
				break;

				case 3: /* resource name */
					/* hide resources with this name */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						var parentl = node.parent.getLabel();
						var longname = (parentl == self._other ? l : parentl+l);
						if (n.name == longname) { n.visible[propertyName] = 0; }
					}
				break;

				case 4: /* in-domain-of / in-range-of */
					/* hide out/in edges for resource with this name */
					var l1 = node.parent.getLabel();
					var l2 = node.parent.parent.getLabel();
					var name = (l2 == self._other ? l1 : l2+l1);
					var res = false;
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						if (n.name == name) { res = n; }
					}
					var arr = (l == self._indomain ? res.outEdges : res.inEdges);
					for (var j=0;j<arr.length;j++) {
						arr[j].visible[propertyName] = 0;
					}
				break;

				case 5: /* predicate name */
					/* hide predicate from a resource */
					var l1 = node.parent.parent.getLabel();
					var l2 = node.parent.parent.parent.getLabel();
					var name = (l2 == self._other ? l1 : l2+l1);
					var res = false;
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						if (n.name == name) { res = n; }
					}
					var arr = (node.parent.getLabel() == self._indomain ? res.outEdges : res.inEdges);
					for (var j=0;j<arr.length;j++) {
						var e = arr[j];
						if (e.name == l) { e.visible[propertyName] = 0; }
					}
				break;

			} /* switch */
		} /* for all unselected nodes */

		self.graph.drawUpdate();
	}

	this.filterPredicates = function(treeSet) {
		var d = self.graph.data; /* default - mark everything as visible */
		for (var i=0;i<d.length;i++) {
			var n = d[i];
			n.visible.sidebar3 = 1;
			for (var j=0;j<n.outEdges.length;j++) {
				var e = n.outEdges[j];
				e.visible.sidebar3 = 1;
			}
		}

		for (var i=0;i<treeSet.length;i++) { /* analyze unchecked nodes */
			var node = treeSet[i];
			var depth = node.depth;
			var l = node.getLabel();
			switch (depth) {
				case 1: /* predicates */
					/* hide all predicates */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						for (var k=0;k<n.outEdges.length;k++) {
							var e = n.outEdges[k];
							e.visible.sidebar3 = 0;
						}
					}
				break;

				case 2: /* predicate name */
					/* hide predicates with this name */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						for (var k=0;k<n.outEdges.length;k++) {
							var e = n.outEdges[k];
							if (e.name == l) { e.visible.sidebar3 = 0; }
						}
					}
				break;

				case 3: /* domain/range */
					/* hide domain/range of predicate */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						var arr = (l == self._domain ? n.outEdges : n.inEdges);
						var predl = node.parent.getLabel();
						for (var k=0;k<arr.length;k++) {
							var e = arr[k];
							if (e.name == predl) { n.visible.sidebar3 = 0; }
						}
					}
				break;

				case 4: /* resource name */
					/* hide predicate with this resource */
					for (var j=0;j<d.length;j++) {
						var n = d[j];
						var arr = (node.parent.getLabel() == self._domain ? n.outEdges : n.inEdges);
						var predl = node.parent.parent.getLabel();
						for (var k=0;k<arr.length;k++) {
							var e = arr[k];
							if (e.name == predl && n.name == l) { n.visible.sidebar3 = 0; }
						}
					}
				break;

			} /* switch */
		} /* for all unselected nodes */

		self.graph.drawUpdate();
	}

	this.getResourcesObj = function() { /* return object containing all resources */
		var obj = {};
		var data = self.graph.data;
		for (var i=0;i<data.length;i++) {
			var v = data[i].name;
			var regs = v.match("^(http://[^/]+/)(.*)");
			if (!regs) { regs = [false,self._other,v];	}
			var head = regs[1];
			if (!(head in obj)) { obj[head] = []; }
			obj[head].push(regs[2]);
		}
		return obj;
	}

	this.getClassesObj = function() { /* return object containing all resources */
		var obj = {};
		var data = self.graph.data;
		for (var i=0;i<data.length;i++) {
			if (!(self.isClass(data[i]))) { continue; }
			var v = data[i].name;
			var regs = v.match("^(http://[^/]+/)(.*)");
			if (!regs) { regs = [false,self._other,v];	}
			var head = regs[1];
			if (!(head in obj)) { obj[head] = []; }
			obj[head].push(regs[2]);
		}
		return obj;
	}

	this.getPredicatesObj = function() { /* return object containing all predicates (with their domains & ranges) */
		var obj = {};
		var edges = self.graph.edges;
		for (var i=0;i<edges.length;i++) {
			var e = edges[i].name;
			var n1 = edges[i].vertex1.name;
			var n2 = edges[i].vertex2.name;
			if (!(e in obj)) { obj[e] = {domain:{},range:{}}; }
			var content = obj[e];
			if (!(n1 in content.domain)) { content.domain[n1] = true; }
			if (!(n2 in content.range)) { content.range[n2] = true; }
		}
		return obj;
	}

	this.createResourceDR = function(resource,type) { /* create a <li> containing domain/range of a resource */
		var obj = {};
		var res = false;
		for (var i=0;i<self.graph.data.length;i++) {
			var n = self.graph.data[i];
			if (n.name == resource) { res = n; }
		}
		if (!res) { alert("OAT.GraphsideBar.CreateResourceDR:\nConsistency error!"); }

		var arr = (type == 1 ? res.outEdges : res.inEdges);
		for (var i=0;i<arr.length;i++) {
			var name = arr[i].name;
			if (!(name in obj)) { obj[name] = true; }
		}

		var li = OAT.Dom.create("li");
		li.innerHTML = (type == 1 ? self._indomain : self._inrange);
		var ul = OAT.Dom.create("ul");
		li.appendChild(ul);
		for (var p in obj) {
			var li2 = OAT.Dom.create("li");
			li2.innerHTML = p;
			ul.appendChild(li2);
		}
		return li;
	}

	this.createPredicateDR = function(predicate,type) { /* create a <li> containing domain/range of a predicate */
		var li = OAT.Dom.create("li");
		li.innerHTML = (type == 1 ? self._domain : self._range);
		var ul = OAT.Dom.create("ul");
		li.appendChild(ul);
		var obj = (type == 1 ? predicate.domain : predicate.range);
		for (var p in obj) {
			var li2 = OAT.Dom.create("li");
			li2.innerHTML = p;
			ul.appendChild(li2);
		}
		return li;
	}

	this.createResources = function() { /* create Resources & Classes filtertrees */
		var topul_r = OAT.Dom.create("ul");
		var topul_c = OAT.Dom.create("ul");
		var topli_r = OAT.Dom.create("li");
		var topli_c = OAT.Dom.create("li");
		var vertexheader_r = OAT.Dom.create("strong");
		var vertexheader_c = OAT.Dom.create("strong");
		vertexheader_r.innerHTML = "Resources";
		vertexheader_c.innerHTML = "Classes";
		topli_r.appendChild(vertexheader_r);
		topli_c.appendChild(vertexheader_c);
		topul_r.appendChild(topli_r);
		topul_c.appendChild(topli_c);
		var vertexul_r = OAT.Dom.create("ul");
		var vertexul_c = OAT.Dom.create("ul");
		var ress_r = self.getResourcesObj();
		var ress_c = self.getClassesObj();
		for (var p in ress_r) {
			var li = OAT.Dom.create("li");
			li.innerHTML = p;
			vertexul_r.appendChild(li);
			var ul = OAT.Dom.create("ul");
			li.appendChild(ul);
			for (var i=0;i<ress_r[p].length;i++) {
				var li = OAT.Dom.create("li");
				var name = (p == self._other ? ress_r[p][i] : p + ress_r[p][i]);
				li.innerHTML = ress_r[p][i];
				var drul = OAT.Dom.create("ul");
				drul.appendChild(self.createResourceDR(name,1));
				drul.appendChild(self.createResourceDR(name,2));
				li.appendChild(drul);
				ul.appendChild(li);
			}
		}
		for (var p in ress_c) {
			var li = OAT.Dom.create("li");
			li.innerHTML = p;
			vertexul_c.appendChild(li);
			var ul = OAT.Dom.create("ul");
			li.appendChild(ul);
			for (var i=0;i<ress_c[p].length;i++) {
				var li = OAT.Dom.create("li");
				var name = (p == self._other ? ress_c[p][i] : p + ress_c[p][i]);
				li.innerHTML = ress_c[p][i];
				var drul = OAT.Dom.create("ul");
				drul.appendChild(self.createResourceDR(name,1));
				drul.appendChild(self.createResourceDR(name,2));
				li.appendChild(drul);
				ul.appendChild(li);
			}
		}
		topli_r.appendChild(vertexul_r);
		topli_c.appendChild(vertexul_c);
		self.div.appendChild(topul_r);
		self.div.appendChild(topul_c);
		var t = new OAT.Tree({
			imagePath:self.graph.options.imagePath,
			checkboxMode:true,
			checkNOI:false,
			checkCallback:function(treeSet) {
				self.filterResources(treeSet,"sidebar1");
			}
		});
		t.assign(topul_r,true);
		var t = new OAT.Tree({
			imagePath:self.graph.options.imagePath,
			checkboxMode:true,
			checkNOI:false,
			checkCallback:function(treeSet) {
				self.filterResources(treeSet,"sidebar2");
			}
		});
		t.assign(topul_c,true);
	}

	this.createPredicates = function() { /* create Predicates filtertree */
		var topul = OAT.Dom.create("ul");
		var topli = OAT.Dom.create("li");
		topul.appendChild(topli);
		var edgeheader = OAT.Dom.create("strong");
		edgeheader.innerHTML = "Predicates";
		topli.appendChild(edgeheader);
		var edgeul = OAT.Dom.create("ul");
		var preds = self.getPredicatesObj();
		for (var p in preds) {
			var li = OAT.Dom.create("li");
			li.innerHTML = p;
			var drul = OAT.Dom.create("ul");
			drul.appendChild(self.createPredicateDR(preds[p],1));
			drul.appendChild(self.createPredicateDR(preds[p],2));
			li.appendChild(drul);
			edgeul.appendChild(li);
		}
		topli.appendChild(edgeul);
		self.div.appendChild(topul);
		var t = new OAT.Tree({
			imagePath:self.graph.options.imagePath,
			checkboxMode:true,
			checkNOI:false,
			checkCallback:self.filterPredicates
		});
		t.assign(topul,true);
	}

	this.create = function(button) {
		self.div = OAT.Dom.create("div",{position:"absolute",left:"0px",top:"2px",width:"300px",height:"100%",overflow:"auto",className:"rdf_sidebar"});
		self.div.style.backgroundColor = "#fff";
		OAT.Style.set(self.div,{opacity:0.8});
		self.button = button;
		self.createResources();
		self.createPredicates();
	}

	this.toggle = function() {
		self.graph.options.sidebarShown = !self.graph.options.sidebarShown;
		if (self.graph.options.sidebarShown) {
			OAT.Dom.show(self.div);
			self.button.value = "Hide sidebar";
		} else {
			OAT.Dom.hide(self.div);
			self.button.value = "Show sidebar";
		}
	}
}
