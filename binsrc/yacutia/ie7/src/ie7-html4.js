/*
	W3C compliance for Microsoft Internet Explorer

	this module forms part of IE7
	IE7 version 0.7.3 (alpha) 2004/09/18
	by Dean Edwards, 2004
*/

/* other fixes may be loaded by external modules in the format:

  if (HTMLFixes) HTMLFixes.add(selector, fix);

  where:
  selector: string used to match a set of elements
  fix: function that receives the element to to be fixed as its only parameter
*/
if (window.IE7) IE7.addModule("ie7-html4", function() {

	// fix broken HTML tags

if (isHTML) HTMLFixes = new function() {
	var fixes = []; // private

	function fix(element) {
		// remove the broken tags and replace with <HTML:tagName/>
		var fixedElement = document.createElement("<HTML:" + element.outerHTML.slice(1));
	//# fixedElement.mergeAttributes(element, false);
		if (element.outerHTML.slice(-2) != "/>") {
			// remove child nodes and copy them to the new element
			var endTag = "</"+ element.tagName + ">", nextSibling;
			while ((nextSibling = element.nextSibling) && nextSibling.outerHTML != endTag) {
				element.parentNode.removeChild(nextSibling);
				fixedElement.appendChild(nextSibling);
			}
			// remove the closing tag
			if (nextSibling) element.parentNode.removeChild(nextSibling);
		}
		// replace the broken tag with the namespaced version
		element.parentNode.replaceChild(fixedElement, element);
		return fixedElement;
	};

	this.add = function() {
		push(fixes, arguments);
	};

	this.apply = function() {
	try {
		// create the namespace used to declare our fixed <abbr/> tag.
		//  strangely, this throws an error if there is no <abbr/> tag present!?
		if (appVersion > 5) document.namespaces.add("HTML", "http://www.w3.org/1999/xhtml");

	} catch (ignore) {
		// explorer confuses me.
		// we can create a namespace when the <abbr/>
		//  tag is present, otherwise error!
		//  this kind of suits me but it's still weird.
	} finally {
		// apply all fixes
		for (var i = 0; i < fixes.length; i++) {
			var elements = cssQuery(fixes[i][0]);
			for (var j = 0; j < elements.length; j++) fixes[i][1](elements[j]);
		}
	}};

	// associate <label> elements with an input element
	this.add("label", function(element) {
		if (!element.htmlFor) {
			var input = cssQuery("input,select,textarea", element)[0];
			if (input) {
				if (!input.id) input.id = input.uniqueID;
				element.htmlFor = input.id;
			}
		}
	});

	// provide support for the <abbr> tag for html documents
	//  this is a proper fix, it preserves the dom structure and
	//  <abbr> elements report the correct tagName & namespace prefix
	this.add("abbr", function(element) {
		fix(element);
		// don't cache broken <abbr> tags
		delete cssCache[" abbr"];
	});

	// a couple of <button> fixes
	this.add("button,input", function(element) {
		if (element.tagName == "BUTTON") {
			// IE bug means that innerText is submitted instead of "value"
			var match = element.outerHTML.match(/ value="([^"]*)"/i);
			element.runtimeStyle.value = (match) ? match[1] : "";
		}
		// flag the button/input that was used to submit the form
		if (element.type == "submit") {
			addEventHandler(element, "onclick", function() {
				element.runtimeStyle.clicked = true;
				setTimeout("document.all." + element.uniqueID + ".runtimeStyle.clicked=false", 1);
			});
		}
	});

	// only submit successful controls
	this.add("form", function(element) {
		var UNSUCCESSFUL = /^(submit|reset|button)$/;
		addEventHandler(element, "onsubmit", function() {
			for (var i = 0; i < element.length; i++) {
				if (UNSUCCESSFUL.test(element[i].type) && !element[i].disabled && !element[i].runtimeStyle.clicked) {
					element[i].disabled = true;
					setTimeout("document.all." + element[i].uniqueID + ".disabled=false", 1);
				} else if (element[i].tagName == "BUTTON" && element[i].type == "submit") {
					setTimeout("document.all." + element[i].uniqueID + ".value='" + element[i].value + "'", 1);
					element[i].value = element[i].runtimeStyle.value;
				}
			}
		});
	});
}}, true);
