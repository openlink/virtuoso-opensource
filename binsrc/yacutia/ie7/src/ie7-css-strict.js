/*
	W3C compliance for Microsoft Internet Explorer

	this module forms part of IE7
	IE7 version 0.7.3 (alpha) 2004/09/18
	by Dean Edwards, 2004
*/
if (window.IE7) IE7.addModule("ie7-strict", function() {

// requires another module
if (!modules["ie7-css2"]) return;

// constants
var NONE = [], ID = /#/g, CLASS = /[:@\.]/g, TAG = /^\w|[\s>+~]\w/g;

IE7.parser.parse = function(cssText) {
	var DYNAMIC = new RegExp("(.*):(" + dynamicPseudoClasses + ")(.*)");
	function addRule(selector, cssText) {
		var match = selector.match(DYNAMIC);
		// dynamic style (hover/active/focus)
		if (match) new DynamicRule(selector, match[1], match[2], match[3], cssText);
		// static style
		else new Rule(selector, cssText);
	};

	// anonymous content
	cssText = cssText.replace(IE7.PseudoElement.ALL, IE7.PseudoElement.ID);

	// convert all selectors to ie7 classes
	var RULE = /([^\{]+)\{(\d+)\}/g, match;
	while (match = RULE.exec(cssText)) {
		addRule(match[1], match[2]);
		// fix for IE5.0
		if (appVersion < 5.5) cssText = cssText.slice(match.lastIndex);
	}

	// sort the classes by specificity
	IE7.classes.sort(Rule.compare);

	// return the new style sheet text
	return IE7.classes.join("\n");
};

// -----------------------------------------------------------------------
// IE7 rules (strict)
// -----------------------------------------------------------------------

// constructor
function Rule(selector, cssText) {
	// initialise object properties
	this.cssText = cssText;
	this.specificity = Rule.score(selector);
	// inheritance
	this.inherit = IE7.Class;
	this.inherit(selector);
};
// inheritance
Rule.prototype = new IE7.Class.ancestor;
Rule.prototype.toString = function() {
	return "." + this.name + "{" + this.cssText + "}";
};
// class methods
Rule.score = function(selector) {
	return (selector.match(ID)||NONE).length * 10000 +
	       (selector.match(CLASS)||NONE).length * 100 +
	       (selector.match(TAG)||NONE).length;
};
Rule.compare = function(rule1, rule2) {
	return rule1.specificity - rule2.specificity;
};

// constructor
function DynamicRule(selector, attach, dynamicPseudoClass, target, cssText) {
	// initialise object properties
	this.cssText = cssText;
	this.specificity = Rule.score(selector);
	// inheritance
	this.inherit = IE7.DynamicStyle;
	this.inherit(selector, attach, dynamicPseudoClass, target);
};
// inheritance
DynamicRule.prototype = new IE7.DynamicStyle.ancestor;
DynamicRule.prototype.toString = Rule.prototype.toString;
});
