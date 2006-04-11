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
/* IE7 version 0.7.3 (alpha) 2004/09/18 */
if(window.IE7)IE7.addModule("ie7-strict",function(){if(!modules["ie7-css2"])return;var NONE=[],ID=/#/g,CLASS=/[:@\.]/g,TAG=/^\w|[\s>+~]\w/g;IE7.parser.parse=function(cssText){var DYNAMIC=new RegExp("(.*):("+dynamicPseudoClasses+")(.*)");function addRule(selector,cssText){var match=selector.match(DYNAMIC);if(match)new DynamicRule(selector,match[1],match[2],match[3],cssText);else new Rule(selector,cssText)};cssText=cssText.replace(IE7.PseudoElement.ALL,IE7.PseudoElement.ID);var RULE=/([^\{]+)\{(\d+)\}/g,match;while(match=RULE.exec(cssText)){addRule(match[1],match[2]);if(appVersion<5.5)cssText=cssText.slice(match.lastIndex)}IE7.classes.sort(Rule.compare);return IE7.classes.join("\n")};function Rule(selector,cssText){this.cssText=cssText;this.specificity=Rule.score(selector);this.inherit=IE7.Class;this.inherit(selector)};Rule.prototype=new IE7.Class.ancestor;Rule.prototype.toString=function(){return "."+this.name+"{"+this.cssText+"}"};Rule.score=function(selector){return(selector.match(ID)||NONE).length*10000+(selector.match(CLASS)||NONE).length*100+(selector.match(TAG)||NONE).length};Rule.compare=function(rule1,rule2){return rule1.specificity-rule2.specificity};function DynamicRule(selector,attach,dynamicPseudoClass,target,cssText){this.cssText=cssText;this.specificity=Rule.score(selector);this.inherit=IE7.DynamicStyle;this.inherit(selector,attach,dynamicPseudoClass,target)};DynamicRule.prototype=new IE7.DynamicStyle.ancestor;DynamicRule.prototype.toString=Rule.prototype.toString});
