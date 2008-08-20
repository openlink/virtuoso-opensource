
var CompatVersion="0.082305.0";function _VERegisterNamespaces()
{for(var i=0;i<arguments.length;i++)
{var astrParts=arguments[i].split(".")
var root=window;for(var j=0;j<astrParts.length;j++)
{if(!root[astrParts[j]])
{root[astrParts[j]]=new Object();}
root=root[astrParts[j]];}}}
_VERegisterNamespaces("Web.Browser","Web.Debug.Performance");if(!Web.Debug.Enabled)
{Web.Debug.Enabled=false;Web.Debug.Assert=Web.Debug.Trace=function(){};Web.Debug.Performance.Start=function()
{this.End=function(){}
return this}}
Web.Browser._isMozilla=(typeof document.implementation!='undefined')&&(typeof document.implementation.createDocument!='undefined')&&(typeof HTMLDocument!='undefined');Web.Browser.isMozilla=function()
{return Web.Browser._isMozilla;}
Web.Browser._Private=function(){}
Web.Browser._Private.CreatePopup=function()
{var obj=new Object();obj.document=document.createDocumentFragment();obj.document.body=obj.document.appendChild(document.createElement("div"));obj.document.close=obj.document.open=function(){};obj.document.write=function(v)
{obj.document.body.innerHTML+=v;}
obj.show=function(x,y,width,height,offset)
{if(!offset)offset=document.body;var offsetLoc=Web.Dom.GetLocation(offset);obj.document.body.style.cssText="z-index:100;position:absolute;margin:0px;padding:0px;top:{0}px;left:{1}px;width:{2}px;height:{3}px;background:white".format(y+offsetLoc.top,x+offsetLoc.left,width,height);var r=document.body.appendChild(obj.document.body);document.addEventListener("mousedown",doHide,true)
r.onclicktemp=obj.document.onclick;r.onclick=doClick
function doHide(ev)
{if(!obj.document.body.contains(ev.target))
{ev.stopPropagation()
r.removeNode();}
document.removeEventListener("mousedown",doHide,true);}
function doClick(ev)
{if(this.onclicktemp)
this.onclicktemp()
r.removeNode();}}
return obj;}
Web.Browser._Private.MozillaFilterMethods=new Array("addAmbient","addCone","addPoint","apply","changeColor","changeStrength","clear","moveLight")
Web.Browser._Private.MozillaFilterEventMethods=new Array("play","stop");Web.Browser._Private.MozillaFilterSub=function()
{var privFilter=Web.Browser._Private;for(var i=0;i<privFilter.MozillaFilterMethods.length;i++)
this[privFilter.MozillaFilterMethods[i]]=doblank;for(var i=0;i<privFilter.MozillaFilterEventMethods.length;i++)
this[privFilter.MozillaFilterEventMethods[i]]=doevent;function doblank(){}
function doevent()
{if(this.onfilterchange)this.onfilterchange();}
return this;}
Web.Browser.AttachMozillaCompatibility=function(w)
{w.CollectGarbage=function(){};function EstablishMode()
{var el=w.document.getElementsByName("Web.moz-custom");if(el.length>0)
Web.Browser.MozillaCompatMode=el[0].getAttribute("content").toLowerCase()=="enabled";else
Web.Browser.MozillaCompatMode=false;}
EstablishMode();function GenWindowEvent(e){window.event=e;}
Web.Browser.Button={LEFT:0,RIGHT:2,MIDDLE:1};function Map(el,mozillaType,callback)
{var strMozillaType=mozillaType.slice(2);if(strMozillaType=="mousewheel"&&typeof window.onmousewheel==="undefined")
{strMozillaType="DOMMouseScroll";}
if(strMozillaType!="mouseenter"&&strMozillaType!="mouseleave")
{el.addEventListener(strMozillaType,GenWindowEvent,true);}
else
{el.addEventListener("mouseover",GenWindowEvent,true);el.addEventListener("mouseout",GenWindowEvent,true);el.addEventListener("mouseover",CheckEnter,false);el.addEventListener("mouseout",CheckLeave,false);}
el.addEventListener(strMozillaType,callback,false);}
function CheckEnter()
{if(!this.contains(window.event.fromElement))
{var oEvent=document.createEvent("MouseEvents");oEvent.initEvent("mouseenter",false,false);this.dispatchEvent(oEvent)}}
function CheckLeave()
{if(!this.contains(window.event.toElement))
{var oEvent=document.createEvent("MouseEvents");oEvent.initEvent("mouseleave",false,false);this.dispatchEvent(oEvent)}}
function RemoveMap(el,mozillaType,callback)
{var strMozillaType=mozillaType.slice(2)
if(strMozillaType=="mousewheel"&&typeof window.onmousewheel==="undefined")
{strMozillaType="DOMMouseScroll";}
el.removeEventListener(strMozillaType,callback,false);}
function GetNonTextNode(n)
{try
{while(n&&n.nodeType!=1)n=n.parentNode;}
catch(ex)
{n=null;}
return n;}
var elementProto=w.Element.prototype;var htmlProto=w.HTMLDocument.prototype;var eventProto=w.Event.prototype;var cssProto=w.CSSStyleDeclaration.prototype;var docProto=w.Document.prototype;w.attachEvent=w.HTMLDocument.prototype.attachEvent=w.HTMLElement.prototype.attachEvent=function(type,callback){Map(this,type,callback);}
w.detachEvent=w.HTMLDocument.prototype.detachEvent=w.HTMLElement.prototype.detachEvent=function(type,callback){RemoveMap(this,type,callback);}
w.createPopup=Web.Browser._Private.CreatePopup;docProto.__proto__={get xml(){return(new XMLSerializer()).serializeToString(this);},__proto__:docProto.__proto__}
w.Document.prototype.scripts=document.getElementsByTagName("script");w.Document.prototype.selection=new Object();w.Document.prototype.selection.clear=function(){};w.Document.prototype.selection.createRange=function(){return window.getSelection().getRangeAt(0);}
w.XMLDocument.prototype.transformNodeToObject=function(p_objXsl)
{var objXslProcessor=new XSLTProcessor();objXslProcessor.importStylesheet(p_objXsl);var ownerDocument=document.implementation.createDocument("","",null);return objXslProcessor.transformToFragment(this,ownerDocument);}
w.HTMLElement.prototype.removeNode=function(b)
{return this.parentNode.removeChild(this)}
w.HTMLElement.prototype.contains=function(el)
{while(el!=null&&el!=this)
el=el.parentElement;return(el!=null)};function CurrentStyle(el)
{var PropertyList=new Array("Top","Left","Right","Bottom");var cs=document.defaultView.getComputedStyle(el,null);for(var i=0;i<PropertyList.length;i++)
{var p=PropertyList[i]
this["border"+p+"Width"]=cs.getPropertyValue("border-"+p+"-width")
this["margin"+p]=cs.getPropertyValue("margin-"+p)
this["padding"+p]=cs.getPropertyValue("padding-"+p)}
this["position"]=cs.getPropertyValue("position");this["height"]=cs.getPropertyValue("height");this["width"]=cs.getPropertyValue("width");this["zIndex"]=cs.getPropertyValue("z-index");return this;}
w.HTMLElement.prototype.filters=Web.Browser._Private.MozillaFilterSub();var m_Capturing=false;var root=document.getElementsByTagName("HTML")[0];function CaptureMouse(ev)
{if(m_Capturing)
{ev.preventDefault();ev.returnValue=false;document.removeEventListener("mousemove",CaptureMouse,true);var oEvent=document.createEvent("MouseEvents");oEvent.initMouseEvent(ev.type,ev.bubbles,ev.cancelable,ev.view,ev.detail,ev.screenX,ev.screenY,ev.clientX,ev.clientY,ev.ctrlKey,ev.altKey,ev.shiftKey,ev.metaKey,ev.button,ev.relatedTarget);oEvent._FixOffset=GetNonTextNode(ev.srcElement);if(oEvent._FixOffset==root)
oEvent._FixOffset=document.body;m_Capturing.dispatchEvent(oEvent);oEvent._FixOffset=null;document.addEventListener("mousemove",CaptureMouse,true);ev.stopPropagation();}}
function ReleaseMouse(ev)
{if(m_Capturing)
{document.removeEventListener("mouseup",ReleaseMouse,true);document.removeEventListener("mousemove",CaptureMouse,true);var eventCanBubble=ev.bubbles;var eventIsCancelable=ev.cancelable;if(ev.type=="mouseup")
{eventCanBubble=false;eventIsCancelable=false;}
var oEvent=document.createEvent("MouseEvents");oEvent.initMouseEvent(ev.type,eventCanBubble,eventIsCancelable,ev.view,ev.detail,ev.screenX,ev.screenY,ev.clientX,ev.clientY,ev.ctrlKey,ev.altKey,ev.shiftKey,ev.metaKey,ev.button,ev.relatedTarget);oEvent._FixOffset=GetNonTextNode(ev.srcElement);if(oEvent._FixOffset==root)
oEvent._FixOffset=document.body;m_Capturing.dispatchEvent(oEvent);oEvent._FixOffset=null;m_Capturing=null;ev.stopPropagation();ev.preventDefault();}}
function StopEvent(ev)
{ev.stopPropagation();ev.preventDefault();}
function ValidateButton(ev)
{if(ev.button!=0)
ev.stopPropagation();}
w.document.addEventListener("click",ValidateButton,true)
w.HTMLElement.prototype.setCapture=function(ev)
{m_Capturing=this;document.addEventListener("mousemove",CaptureMouse,true);document.addEventListener("mouseover",StopEvent,true);document.addEventListener("mouseout",StopEvent,true);document.addEventListener("mouseenter",StopEvent,true);document.addEventListener("mouseleave",StopEvent,true);document.addEventListener("mouseup",ReleaseMouse,true);};w.HTMLElement.prototype.releaseCapture=function()
{m_Capturing=null;document.removeEventListener("mousemove",CaptureMouse,true);document.removeEventListener("mouseover",StopEvent,true);document.removeEventListener("mouseout",StopEvent,true);document.removeEventListener("mouseenter",StopEvent,true);document.removeEventListener("mouseleave",StopEvent,true);document.removeEventListener("mouseup",ReleaseMouse,true);};w.HTMLElement.prototype.insertAdjacentElement=function(sWhere,oElement)
{switch(sWhere.toLowerCase())
{case"beforebegin":this.parentNode.insertBefore(oElement,this);break;case"beforeend":this.appendChild(oElement);break;case"afterbegin":this.insertBefore(oElement,this.firstChild);break;case"afterend":if(this.nextSibling)
this.parentNode.insertBefore(oElement,this.nextSibling);else
this.parentNode.appendChild(oElement);break;default:throw"Invalid Argument";break;}}
function parseFilter(v)
{v=v.replace(" ","");var matchString="DXImageTransform.Microsoft.Alpha(opacity=";var opacityIndex=v.indexOf(matchString)
if(opacityIndex>0)
{var close=v.indexOf(")",opacityIndex);if(close==-1)
close=v.indexOf(",",opacityIndex);return("."+v.substring(opacityIndex+matchString.length,close));}
else
return"";}
cssProto.__proto__={get pixelLeft(){return parseInt(this.left)||0;},set pixelLeft(v){this.left=v+"px";},get pixelHeight(){return parseInt(this.height)||0;},set pixelHeight(v){this.height=v+"px";},get pixelTop(){return parseInt(this.top)||0;},set pixelTop(v){this.top=v+"px";},get pixelWidth(){return parseInt(this.width)||0;},set pixelWidth(v){this.width=v+"px";},set filter(v){this.opacity=parseFilter(v)},get cssText(){var s="";for(var j=0;j<this.cssRules.length;j++)
s+=this.cssRules[j].cssText;return s;},__proto__:cssProto.__proto__}
elementProto.__proto__={get parentElement(){return GetNonTextNode(this.parentNode)},set onfilterchange(v){this.filters.onfilterchange=v},get onfilterchange(){return this.filters.onfilterchange},get innerText(){try
{return this.textContent}
catch(ex)
{var str="";for(var i=0;i<this.childNodes.length;i++)
{if(this.childNodes[i].nodeType==3)
str+=this.childNodes[i].textContent;}
return str;}},set innerText(v){var n=document.createTextNode(v);this.innerHTML="";this.appendChild(n);},get currentStyle(){return new CurrentStyle(this)},get text(){return this.textContent},__proto__:elementProto.__proto__}
function selectSingleNode(d,v,c)
{v+="[1]";var nl=selectNodes(d,v,c);if(nl.length>0)
return nl[0];else
return null;}
function selectNodes(d,v,c)
{var oResult=d.evaluate(v,c,d.createNSResolver(d.documentElement),XPathResult.ORDERED_NODE_SNAPSHOT_TYPE,null);var nodeList=new Array();for(i=0;i<oResult.snapshotLength;i++)
nodeList.push(oResult.snapshotItem(i));return nodeList;}
w.XMLDocument.prototype.selectNodes=function(v)
{return selectNodes(this,v,this);};w.Element.prototype.selectNodes=function(v)
{var scope=this.ownerDocument;if(scope.selectNodes)
return selectNodes(scope,v,this);else
return null;};w.XMLDocument.prototype.selectSingleNode=function(v)
{return selectSingleNode(this,v,null);};w.Element.prototype.selectSingleNode=function(v)
{var scope=this.ownerDocument;if(scope.selectSingleNode)
return selectSingleNode(scope,v,this);else
return null;};function QuickLoc(el)
{var c={x:0,y:0};while(el){c.x+=el.offsetLeft;c.y+=el.offsetTop;el=el.offsetParent;}
return c;}
eventProto.__proto__={get srcElement(){var n=this._FixOffset;if(!n){n=GetNonTextNode(this.target)};return n;},set cancelBubble(v){if(v)this.stopPropagation()},get offsetX(){return window.pageXOffset+this.clientX-((this._FixOffset)?QuickLoc(this._FixOffset).x:QuickLoc(this.srcElement).x);},get offsetY(){return window.pageYOffset+this.clientY-((this._FixOffset)?QuickLoc(this._FixOffset).y:QuickLoc(this.srcElement).y);},get x(){return this.offsetX},get y(){return this.offsetY},set returnValue(v){if(!v){this.preventDefault()};this.cancelDefault=v;return v},get returnValue(){return this.cancelDefault},get fromElement(){var n;if(this.type=="mouseover")
n=this.relatedTarget;else if(this.type=="mouseout")
n=this.target;return GetNonTextNode(n);},get toElement(){var n=null;var ex;try
{if(this.type=="mouseout")
n=this.relatedTarget;else if(this.type=="mouseover")
n=this.target;}
catch(ex){}
return GetNonTextNode(n);},__proto__:eventProto.__proto__};}
Web.Browser._Private.MozillaModal=function(sURL,oArguments,sFeatures,fnCallback)
{if(!sFeatures)sFeatures="";sFeatures=sFeatures.removeSpaces();var featureList=sFeatures.split(",");sFeatures="";var bCenter=bNoCenter=false;var w=h=0;for(var i=0;i<featureList.length;i++)
{var feature=featureList[i].split(":");var k=feature[0].toLowerCase();var v=feature[1];switch(k)
{case"dialogheight":s+="height="+v;w=v;break;case"dialogwidth":s+="width="+v;h=v;break;case"dialogtop":s+="top="+v;bNoCenter=true;break;case"dialogleft":s+="left="+v;bNoCenter=true;break;case"resizable":s+="resizable="+v;break;case"status":s+="status="+v;break;case"center":bCenter=true;break;}
if(k!="center")s+=",";}
if(bCenter&&(!bNoCenter)&&Web.Conversion)
{if(w!=0)w=Web.Conversion.CoerceInt(w);else w=300;if(h!=0)h=Web.Conversion.CoerceInt(h);else h=300;if(w!=""||h!="")
{s+="screenX="+((screen.availHeight-h)/2)+",";s+="screenY="+((screen.availWidth-w)/2);}}
var mWin=window.open(sURL,"",s);Web.Browser._Private.MozillaCompat(mWin);mWin.dialogArguments=oArguments;resetModal=function(ev)
{if(mWin&&!mWin.closed)
{ev.stopPropagation();mWin.focus()}}
var rValue="";grabReturn=function()
{if(mWin&&!mWin.closed)
{rValue=mWin.returnValue;setTimeout(CheckClose,0);}}
CheckClose=function()
{if(mWin.closed)
{if(fnCallback)
fnCallback(rValue);window.removeEventListener("focus",resetModal,true);}}
hookEvents=function()
{mWin.onunload=grabReturn;window.addEventListener("focus",resetModal,true);}
setTimeout(hookEvents,0)}
if(Web.Browser.isMozilla())
{Web.Browser.AttachMozillaCompatibility(window);}
OAT.Loader.featureLoaded("atlascompat");