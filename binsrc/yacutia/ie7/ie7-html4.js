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
if(window.IE7)IE7.addModule("ie7-html4",function(){if(isHTML)HTMLFixes=new function(){var fixes=[];function fix(element){var fixedElement=document.createElement("<HTML:"+element.outerHTML.slice(1));if(element.outerHTML.slice(-2)!="/>"){var endTag="</"+element.tagName+">",nextSibling;while((nextSibling=element.nextSibling)&&nextSibling.outerHTML!=endTag){element.parentNode.removeChild(nextSibling);fixedElement.appendChild(nextSibling)}if(nextSibling)element.parentNode.removeChild(nextSibling)}element.parentNode.replaceChild(fixedElement,element);return fixedElement};this.add=function(){push(fixes,arguments)};this.apply=function(){try{if(appVersion>5)document.namespaces.add("HTML","http://www.w3.org/1999/xhtml")}catch(ignore){}finally{for(var i=0;i<fixes.length;i++){var elements=cssQuery(fixes[i][0]);for(var j=0;j<elements.length;j++)fixes[i][1](elements[j])}}};this.add("label",function(element){if(!element.htmlFor){var input=cssQuery("input,select,textarea",element)[0];if(input){if(!input.id)input.id=input.uniqueID;element.htmlFor=input.id}}});this.add("abbr",function(element){fix(element);delete cssCache[" abbr"]});this.add("button,input",function(element){if(element.tagName=="BUTTON"){var match=element.outerHTML.match(/ value="([^"]*)"/i);element.runtimeStyle.value=(match)?match[1]:""}if(element.type=="submit"){addEventHandler(element,"onclick",function(){element.runtimeStyle.clicked=true;setTimeout("document.all."+element.uniqueID+".runtimeStyle.clicked=false",1)})}});this.add("form",function(element){var UNSUCCESSFUL=/^(submit|reset|button)$/;addEventHandler(element,"onsubmit",function(){for(var i=0;i<element.length;i++){if(UNSUCCESSFUL.test(element[i].type)&&!element[i].disabled&&!element[i].runtimeStyle.clicked){element[i].disabled=true;setTimeout("document.all."+element[i].uniqueID+".disabled=false",1)}else if(element[i].tagName=="BUTTON"&&element[i].type=="submit"){setTimeout("document.all."+element[i].uniqueID+".value='"+element[i].value+"'",1);element[i].value=element[i].runtimeStyle.value}}})})}},true);