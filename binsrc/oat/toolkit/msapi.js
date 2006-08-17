/* v3 + pendingCount + typeof(footer) */
var L_invalidinvoketarget_text="Invalid invoke target specified.";var L_invaliddirections_text="Invalid argument passed; both start and end must be present.";var L_invalidpageindex_text="Invalid search results page index is passed.";var L_invalidelement_text="Invalid element id; unable to find the element in the document body.";var L_noheadelement_text="Head element is missing for the current document; cannot initialize the API framework.";var L_noserviceurl_text="Either a service url or script url is required to create VENetwork instance.";var L_noscripturl_text="Invalid script source url is assigned; cannot download the assigned script.";var L_nostylesurl_text="Invalid style source url is assigned; cannot attach the assigned styles.";var L_invalidwhatwhere_text="Invalid what/where parameters; either 'what' or 'where' must be present.";var L_notinitialized_text="Map is not loaded; cannot perform this operation.";var L_noroute_text="Cannot calculate route at this point; try again later.";var L_invalidpushpin_text="Invalid pushpin instance.";var L_invalidpushpinid_text="Invalid pushpin id; either id is empty or another pushpin already exists with that id.";var L_invalidpolylineid_text="Invalid polyline id; either id is empty or another polyline already exists with that id.";var L_invalidargument_text="Invalid argument; input argument '%1' is not a valid '%2' value.";var L_invalidlayerid_text="Invalid layer id; either id is empty or another layer already exists with that id.";var L_invalidlayertype_text="Invalid layer type.";var L_invalidlayersource_text="Invalid layer source; either layer is empty or does not exist.";var L_Help_Text="Help";var L_ErrorServerBusy_Text="The server is currently busy. Try again later.";var L_error_text="Error";var L_close_text="close";var L_what_text="What";var L_where_text="Where";var L_find_text="Find";var L_selectlocation_text="Select a location";var L_Start_Text="Start";var L_End_Text="End";var L_DirectionsGetDirections_Text="Get directions";var L_loading_text=".. Loading ..";var L_arriveat_text="Arrive at";var L_startat_text="Start at";var L_step_text="Step %1 of %2";var L_DirectionsStep_Text="Step";var L_CollectionManagerViewerDefaultTitle_Text="Shared Collection";var L_CollectionManagerUnsavedCollectionTitle_Text="Unsaved Collection";var L_DashboardRoad_Text="Road";var L_DashboardAerial_Text="Aerial";var L_DashboardBirdsEye_Text="Bird's eye";var L_DashboardBirdsEyeText_Text="See this location in bird's eye view.";var L_DashboardShowLabels_Text="Show labels";var L_ObliqueZoomBarSelectZoom_Text="Choose the zoom level";var L_ObliqueCompassSelectDirection_Text="Change the direction of the view";var L_ObliqueSelectorSelectThumbnail_Text="Choose a thumbnail to display an image from the surrounding area";var L_ObliqueModeImageNotAvailable_Text="Bird's eye images are not available for this area.";var L_ScaleBarMiles_Text="miles";var L_ScaleBarKilometers_Text="km";var L_ScaleBarMeters_Text="m";var L_ScaleBarYards_Text="yds";var L_MapControlNavteq_Text="&copy; 2006 NAVTEQ";var L_MapControlImageCourtesyOfNASA_Text="Image courtesy of NASA";var L_MapControlHarrisCorp_Text="&copy; Harris Corp, Earthstar Geographics LLC";var L_MapControlImageCourtesyOfUSGS_Text="Image courtesy of USGS";var L_MapControlImageCourtesyOfPictometry_Text="&copy; 2005 Pictometry International Corp.";var L_MapControlImageCourtesyOfEarthData_Text="&copy; EarthData";var L_MapControlImageCourtesyOfGetmapping_Text="&copy; Getmapping plc";var L_MapControlImageCourtesyOfAND_Text="&copy; AND";var L_MapControlImageCourtesyOfBlom_Text="&copy; 2006 Blom";var L_MapCopyrightMicrosoft="&copy; 2006 Microsoft Corporation";var L_MapControlPlatformName_Text="Virtual Earth";RegisterNamespaces("MapControl");MapControl.Features=new function(){
    this.PlatformName=L_MapControlPlatformName_Text;this.Copyright=new function(){
        this.Navteq=L_MapControlNavteq_Text;this.ImageCourtesyOfNASA=L_MapControlImageCourtesyOfNASA_Text;this.HarrisCorp=L_MapControlHarrisCorp_Text;this.ImageCourtesyOfUSGS=L_MapControlImageCourtesyOfUSGS_Text;this.ImageCourtesyOfPictometry=L_MapControlImageCourtesyOfPictometry_Text;
    }
    ();this.Image=new function(){
        this.PoweredLogo="i/logo_powered_by.png";
    }
    ();this.MapStyle=new function(){
        this.Road=true;this.Aerial=true;this.Hybrid=true;this.BirdsEye=true;
    }
    ();this.BirdsEyeAtZoomLevel=10;this.ScaleBarKilometers=false;
}
();var windowWidth=0;var windowHeight=0;var scrollbarWidth=null;function GetWindowWidth(){
    var width=0;if(typeof window.innerWidth=="number")width=window.innerWidth;else{
        if(document.documentElement&&document.documentElement.clientWidth)width=document.documentElement.clientWidth;else{
            if(document.body&&document.body.clientWidth)width=document.body.clientWidth;
        }
        
    }
    if(!width||width<100)width=100;return width;
}
function GetWindowHeight(){
    var height=0;if(typeof window.innerHeight=="number")height=window.innerHeight;else{
        if(document.documentElement&&document.documentElement.clientHeight)height=document.documentElement.clientHeight;else{
            if(document.body&&document.body.clientHeight)height=document.body.clientHeight;
        }
        
    }
    if(!height||height<100)height=100;return height;
}
function GetScrollbarWidth(){
    if(scrollbarWidth)return scrollbarWidth;if(navigator.userAgent.indexOf("IE")>=0){
        var div=document.createElement("div");var sbWidth=null;div.style.visible="hidden";div.style.overflowY="scroll";div.style.position="absolute";div.style.width=0;document.body.insertAdjacentElement("afterBegin",div);sbWidth=div.offsetWidth;div.parentNode.removeChild(div);if(!sbWidth)sbWidth=16;scrollbarWidth=sbWidth;return sbWidth;
    }
    else return 0;
}
function GetUrlPrefix(){
    var lastfslash=window.location.pathname.lastIndexOf("/");var hosturl=window.location.protocol+"//"+window.location.hostname+window.location.pathname.substring(0,lastfslash+1);return hosturl;
}
function GetUrlParameterString(){
    var urlParameterString=window.location.search;if(urlParameterString.length==0||urlParameterString.indexOf("?")==-1)return "";return urlParameterString.substr(urlParameterString.indexOf("?")+1);
}
function CheckWipExistence(){
    var parameterString=GetUrlParameterString();if(parameterString!=""&&parameterString.indexOf("wip=")>-1)return true;return false;
}
function GetUrlParameters(){
    var parameters=new Array();var urlParameterString=GetUrlParameterString();if(!urlParameterString)return parameters;var parameterStrings=urlParameterString.split("&");for(var i=0;i<parameterStrings.length;i++){
        var parameterParts=parameterStrings[i].split("=");if(parameterParts.length==2&&parameterParts[0]&&parameterParts[1]){
            parameters.push(unescape(parameterParts[0]));parameters.push(unescape(parameterParts[1]));
        }
        
    }
    return parameters;
}
function ParseShiftKeyForLinks(e){
    if(e.shiftKey)return false;return true;
}
function GetEvent(e){
    return e?e:window.event;
}
function CancelEvent(e){
    e.cancelBubble=true;
}
function IgnoreEvent(e){
    e=GetEvent(e);CancelEvent(e);return false;
}
function GetMouseX(e){
    var posX=0;if(e.pageX)posX=e.pageX;else{
        if(e.clientX){
            if(document.documentElement&&document.documentElement.scrollLeft)posX=e.clientX+document.documentElement.scrollLeft;else{
                if(document.body)posX=e.clientX+document.body.scrollLeft;
            }
            
        }
        
    }
    return posX;
}
function GetMouseY(e){
    var posY=0;if(e.pageY)posY=e.pageY;else{
        if(e.clientY){
            if(document.documentElement&&document.documentElement.scrollTop)posY=e.clientY+document.documentElement.scrollTop;else{
                if(document.body)posY=e.clientY+document.body.scrollTop;
            }
            
        }
        
    }
    return posY;
}
function GetMouseScrollDelta(e){
    if(e.wheelDelta)return e.wheelDelta;else{
        if(e.detail)return -e.detail;
    }
    return 0;
}
function GetTarget(e){
    if(!e)e=window.event;var t=null;if(e.srcElement)t=e.srcElement;else{
        if(e.target)t=e.target;
    }
    if(t&&t.nodeType){
        if(t.nodeType==3)t=targ.parentNode;
    }
    return t;
}
function GetLeftPosition(b){
    var offsetTrail=b;var offsetLeft=0;while(offsetTrail){
        offsetLeft+=offsetTrail.offsetLeft;offsetTrail=offsetTrail.offsetParent;
    }
    if(navigator.userAgent.indexOf("Mac")!=-1&&typeof document.body.leftMargin!="undefined")offsetLeft+=document.body.leftMargin;return offsetLeft;
}
function GetTopPosition(c){
    var offsetTrail=c;var offsetTop=0;while(offsetTrail){
        offsetTop+=offsetTrail.offsetTop;offsetTrail=offsetTrail.offsetParent;
    }
    if(navigator.userAgent.indexOf("Mac")!=-1&&typeof document.body.topMargin!="undefined")offsetTop+=document.body.topMargin;return offsetTop;
}
function MathFloor(x){
    return Math.floor(x);
}
function MathCeil(x){
    return Math.ceil(x);
}
function MathMax(x,y){
    return Math.max(x,y);
}
function MathMin(x,y){
    return Math.min(x,y);
}
function MathAbs(x){
    return Math.abs(x);
}
function MathRound(x){
    return Math.round(x);
}
function DegToRad(d){
    return d*Math.PI/180;
}
function RadToDeg(r){
    return r*180/Math.PI;
}
function MatrixMultiply(a,b){
    if(!a||!b||a[0].length!=b.length)return;var height=a.length;var width=b[0].length;var result=new Array(height);var z=b.length;for(var i=0;i<height;i++){
        result[i]=new Array(width);for(var j=0;j<width;j++){
            result[i][j]=0;for(var k=0;k<z;k++){
                result[i][j]+=a[i][k]*b[k][j];
            }
            
        }
        
    }
    return result;
}
function RegisterNamespaces(){
    for(var i=0;i<arguments.length;i++){
        var astrParts=arguments[i].split(".");var root=window;for(var j=0;j<astrParts.length;j++){
            if(!root[astrParts[j]])root[astrParts[j]]=new Object();root=root[astrParts[j]];
        }
        
    }
    
}
var L_GraphicsInitError_Text="Your Web browser does not support SVG or VML. Some graphics features may not function properly.";RegisterNamespaces("Msn.Drawing");Msn.Drawing.Exception=function(e){
    this.message=e;this.name="Msn.Drawing.Exception";
}
;Msn.Drawing.Exception.prototype.toString=function(){
    return this.name+": "+this.message;
}
;Msn.Drawing.Graphic=function(){
    
}
;Msn.Drawing.Graphic.CreateGraphic=function(g){
    if(document.all)return new Msn.Drawing.VMLGraphic(g);else{
        var major=0;var minor=0;var versionRegex=new RegExp("Firefox/(.*)");var match=versionRegex.exec(navigator.userAgent);if(match[1]){
            var versionNumbers=match[1].split(".");if(versionNumbers){
                major=versionNumbers[0];minor=versionNumbers[1];if(parseInt(major)>0&&parseInt(minor)>=5)return new Msn.Drawing.SVGGraphic(g);
            }
            
        }
        throw new Msn.Drawing.Exception(L_GraphicsInitError_Text);
    }
    
}
;Msn.Drawing.Point=function(x,y){
    this.x=x?x:0;this.y=y?y:0;
}
;Msn.Drawing.Point.prototype.toString=function(){
    return this.x+","+this.y;
}
;Msn.Drawing.PolyLine=function(h){
    this.id=0;this.points=h?h:new Array();this.AddPoint=function(j){
        this.points.push(j);
    }
    ;
}
;Msn.Drawing.PolyLine.prototype.toString=function(){
    return this.points.join(" ");
}
;Msn.Drawing.Stroke=function(){
    this.width=1;this.linecap="round";this.opacity=1;this.linejoin="miter";this.color=new Msn.Drawing.Color(255,255,255,1);
}
;Msn.Drawing.Color=function(r,g,b,a){
    this.R=r?r:0;this.G=g?g:0;this.B=b?b:0;this.A=a?a:1;this.ToHexString=function(){
        return "#"+Number(this.R).toString(16)+(this.R<16?"0":"")+Number(this.G).toString(16)+(this.G<16?"0":"")+Number(this.B).toString(16)+(this.B<16?"0":"");
    }
    ;
}
;Msn.Drawing.VMLGraphic=function(k){
    var graphicsElm=k;var color=new Msn.Drawing.Color(255,0,0,1);var stroke=new Msn.Drawing.Stroke();var zIndex=1;var parentLeft=k.offsetLeft;var parentTop=k.offsetTop;k.unselectable="on";var currentShapes=new Array();this.DrawPolyline=function(l){
        var element=null;element=document.createElement("v:polyline");element.id=l.id;element.unselectable="on";element.style.position="absolute";element.points=l.points.join(" ");element.style.zIndex=zIndex;element.filled="false";graphicsElm.appendChild(element);if(stroke){
            var strokeElm=document.createElement("v:stroke");strokeElm.unselectable="on";strokeElm.setAttribute("weight",stroke.width);strokeElm.setAttribute("joinstyle",stroke.linejoin);strokeElm.setAttribute("color",stroke.color.ToHexString());strokeElm.setAttribute("endcap",stroke.linecap);strokeElm.setAttribute("opacity",stroke.color.A.toString());element.appendChild(strokeElm);
        }
        currentShapes.push(element);
    }
    ;this.SetColor=function(m){
        color=m;
    }
    ;this.SetStroke=function(n){
        stroke=n;
    }
    ;this.SetZIndex=function(o){
        zIndex=o;
    }
    ;this.Clear=function(){
        var currentShape=null;while(currentShape=currentShapes.pop()){
            graphicsElm.removeChild(currentShape);currentShape=null;
        }
        
    }
    ;this.Destroy=function(){
        this.Clear();graphicsElm=null;
    }
    ;
}
;Msn.Drawing.SVGGraphic=function(p){
    var divElm=document.createElement("div");divElm.id="svgCanvas";divElm.style.position="absolute";var graphicsElm=null;var zIndex=1;divElm.style.top=p.offsetTop+"px";divElm.style.left=p.offsetLeft+"px";p.appendChild(divElm);var currentShapes=new Array();var color=new Msn.Drawing.Color(255,0,0,1);var stroke=new Msn.Drawing.Stroke();divElm.style.width="0px";divElm.style.height="0px";graphicsElm=document.createElementNS("http://www.w3.org/2000/svg","svg");graphicsElm.setAttribute("height","100%");graphicsElm.setAttribute("width","100%");divElm.appendChild(graphicsElm);function q(){
        var startSearchNode=p;while(startSearchNode&&startSearchNode.offsetWidth==0){
            startSearchNode=startSearchNode.parentNode;
        }
        divElm.style.position="absolute";divElm.style.width=startSearchNode.offsetWidth+"px";divElm.style.height=startSearchNode.offsetHeight+"px";
    }
    function r(s){
        if(!s||!s.points||s.points.length<2)return;var points=s.points;var pointsLen=points.length;var minX=0;var maxX=0;var minY=0;var maxY=0;var maxWidth=0;var maxHeight=0;minX=Math.min(points[0].x,points[1].x);maxX=Math.max(points[0].x,points[1].x);minY=Math.min(points[0].y,points[1].y);maxY=Math.max(points[0].y,points[1].y);maxWidth=Math.max(maxX-minX,maxWidth);maxHeight=Math.max(maxY-minX,maxHeight);for(var i=2;i<pointsLen;++i){
            minX=Math.min(points[i].x,minX);maxX=Math.max(points[i].x,maxX);minY=Math.min(points[i].y,minY);maxY=Math.max(points[i].y,maxY);maxWidth=Math.max(maxX-minX,maxWidth);maxHeight=Math.max(maxY-minY,maxHeight);
        }
        divElm.style.top=minY+"px";divElm.style.left=minX+"px";divElm.style.width=maxWidth+"px";divElm.style.height=maxHeight+"px";graphicsElm.setAttribute("width",maxWidth+"");graphicsElm.setAttribute("height",maxHeight+"");for(var i=0;i<pointsLen;++i){
            points[i].x-=minX;points[i].y-=minY;
        }
        
    }
    this.DrawPolyline=function(t){
        r(t);var line=document.createElementNS("http://www.w3.org/2000/svg","polyline");line.setAttribute("points",t.toString());line.setAttribute("fill","none");line.setAttribute("id",t.id);if(stroke){
            line.setAttribute("stroke",stroke.color.ToHexString());line.setAttribute("stroke-width",stroke.width);line.setAttribute("stroke-opacity",stroke.color.A);
        }
        graphicsElm.appendChild(line);currentShapes.push(line);
    }
    ;this.SetColor=function(u){
        color=u;
    }
    ;this.SetStroke=function(v){
        stroke=v;
    }
    ;this.SetZIndex=function(w){
        zIndex=w;divElm.style.zIndex=zIndex;
    }
    ;this.Destroy=function(){
        this.Clear();
    }
    ;this.Clear=function(){
        var currentShape=null;while(currentShape=currentShapes.pop()){
            graphicsElm.removeChild(currentShape);currentShape=null;
        }
        
    }
    ;
}
;RegisterNamespaces("Msn.VE");Msn.VE.Marketization=new function(){
    this.IsEnabled=function(featureValue){
        if(featureValue==undefined)throw new VEException("Msn.VE.Marketization.IsEnabled","err_invalidfeature","Specified feature is invalid.");return featureValue;
    }
    ;
}
();function VEException(x,y,z){
    this.source=x;this.name=y;this.message=z;
}
VEException.prototype.Name=this.name;VEException.prototype.Source=this.source;VEException.prototype.Message=this.message;var Microsoft;if(!Microsoft)Microsoft={
    
}
;if(!Microsoft.Web)Microsoft.Web={
    
}
;if(!Microsoft.Web.UI)Microsoft.Web.UI={
    
}
;Microsoft.Web.UI.IEGlyphStates={
    "Unselected":"-unselected","Hover":"-hover","Pressed":"-pressed"
}
;Microsoft.Web.UI.IEGlyph=function(A,B){
    var ui=Microsoft.Web.UI;var m_elem;var m_stateHover;var m_statePressed;var m_defaultClass;C();function C(){
        m_elem=document.createElement("div");if(A)m_elem.id=A;m_defaultClass=B||"ieglyph";m_stateHover=m_defaultClass+ui.IEGlyphStates.Hover;m_statePressed=m_defaultClass+ui.IEGlyphStates.Pressed;m_elem.className=m_defaultClass;if(!document.all)return;m_elem.attachEvent("onmouseover",F);m_elem.attachEvent("onmousedown",G);m_elem.attachEvent("onmouseup",F);m_elem.attachEvent("onmouseout",H);window.attachEvent("onunload",E);
    }
    this.getElement=function(){
        return m_elem;
    }
    ;this.setContent=function(D){
        m_elem.innerHTML=D;
    }
    ;function E(){
        m_elem.detachEvent("onmouseover",F);m_elem.detachEvent("onmousedown",G);m_elem.detachEvent("onmouseup",F);m_elem.detachEvent("onmouseout",H);m_elem=null;m_stateHover=null;m_statePressed=null;m_defaultClass=null;
    }
    function F(){
        H();I(m_stateHover);
    }
    function G(){
        I(m_statePressed);
    }
    function H(){
        K(m_stateHover);K(m_statePressed);
    }
    function I(J){
        m_elem.className+=" "+J;
    }
    function K(L){
        var regex=new RegExp(" "+L,"g");m_elem.className=m_elem.className.replace(regex,"");
    }
    
}
;RegisterNamespaces("Msn.VE");Msn.VE.PushPinTypes={
    "Default":0,"SearchResult":1,"Annotation":2,"Direction":3,"DirectionTemp":4,"TrafficLight":5,"TrafficOthers":6,"YouAreHere":7
}
;Msn.VE.MapControl=function(M,N){
    var offsetMeters=20971520;var baseMetersPerPixel=163840;var buffer=0;var animatedMovementEnabled=true;var zoomTotalSteps=6;var keyboardPanSpeed=15;var panToLatLongSpeed=15;var earthRadius=6378137;var earthCircumference=earthRadius*2*Math.PI;var projectionOffset=earthCircumference*0.5;var minZoom=1;var maxZoom=19;var emptyTile="http://virtualearth.msn.com/i/spacer.gif";var minLatitude=-85;var maxLatitude=85;var minLongitude=-180;var maxLongitude=180;var tileSize=256;var generations=new Object();var kbInputZIndex=0;var containerZIndex=0;var mapZIndex=1;var swapZIndex=1;var baseZIndex=2;var debugZIndex=3;var baseZIndex=11;var topZIndex=20;var p_this=this;var roadStyle="r";var hybridStyle="h";var aerialStyle="a";var obliqueStyle="o";var currentView=new Msn.VE.MapView();var preferredView=new Msn.VE.MapView();var previousZoomLevel=1;var previousMapStyle=null;var lastOrthoZoomLevel=15;var lastOrthoMapStyle=roadStyle;var x=0;var y=0;var width=0;var height=0;var currentTilesList=new Array();var oldTilesList=null;var trafficAvailable=false;var layerTileList=new Array();var originX=0;var originY=0;var offsetX=0;var offsetY=0;var tileViewportX1=0;var tileViewportY1=0;var tileViewportX2=0;var tileViewportY2=0;var tileViewportWidth=0;var tileViewportHeight=0;var dragging=false;var keyboardPan=false;var lastMouseX=0;var lastMouseY=0;var zooming=false;var zoomCounter=0;var panning=false;var panCounter=0;var panningX=0;var panningY=0;var panLatitude=null;var panLongitude=null;var pushpins=new Array();var lines=new Array();var map=document.createElement("div");var keyboard=document.createElement("input");keyboard.id="wl_ve_mapInput";var logo=null;var scaleBar=null;var copyright=null;var dashboardContainer=null;var dashboard=null;var boxTool=null;var panTool=null;var currentTool=null;var orthoMode=null;var obliqueMode=null;var currentMode=null;var currentBounds=null;var eventTable=new Array();var debug=false;var graphicCanvas=null;this.Init=function(){
        generations[roadStyle]=22;generations[aerialStyle]=22;generations[hybridStyle]=22;generations[obliqueStyle]=24;orthoMode=new nl();orthoMode.Init();if(N.obliqueEnabled&&N.obliqueUrl){
            obliqueMode=new pk();obliqueMode.Init(N.obliqueUrl);
        }
        O();map.className="Map";map.style.zIndex=mapZIndex;M.appendChild(map);keyboard.className="KeyboardInput";M.appendChild(keyboard);if(!N.fixedView){
            boxTool=new Jl();boxTool.Init();panTool=new Sl();panTool.Init();currentTool=panTool;M.attachEvent("onmousedown",eg);M.attachEvent("onmouseup",hg);M.attachEvent("onmousemove",gg);M.attachEvent("onmousewheel",kg);M.attachEvent("ondblclick",jg);M.attachEvent("oncontextmenu",lg);keyboard.attachEvent("onkeydown",Wc);keyboard.attachEvent("onkeyup",Xc);keyboard.attachEvent("onblur",Nb);if(window.addEventListener&&navigator.product&&navigator.product=="Gecko")M.addEventListener("DOMMouseScroll",kg,false);buffer=tileSize;
        }
        if(N.buffer!=undefined&&N.buffer!=null)buffer=N.buffer;if(N.latitude&&N.longitude&&N.zoomlevel&&N.mapstyle)try{
            var initialView=new Msn.VE.MapView();initialView.SetMapStyle(ab(N.mapstyle),N.obliqueSceneId);initialView.SetZoomLevel(eval(N.zoomlevel));initialView.SetCenterLatLong(new Msn.VE.LatLong(eval(N.latitude),eval(N.longitude)));Jj(initialView);
        }
        catch(ex){
            S();
        }
        else S();if(!N.disableLogo){
            logo=new Ze(M);logo.Init();
        }
        copyright=new xc(M);copyright.Init();copyright.Update();if(N.showScaleBar){
            scaleBar=new xh(M);scaleBar.Init();Mc("onendzoom",scaleBar.Update);Mc("onendcontinuouspan",scaleBar.Update);Mc("onresize",scaleBar.Reposition);
        }
        if(N.showDashboard)P(N.dashboardX,N.dashboardY,N.dashboardSize,N.dashboardId);if(obliqueMode&&currentMode!=obliqueMode)obliqueMode.UpdateAvailability();try{
            graphicCanvas=Msn.Drawing.Graphic.CreateGraphic(map);graphicCanvas.SetZIndex(17);
        }
        catch(e){
            
        }
        
    }
    ;this.GetDashboard=function(){
        return dashboard;
    }
    ;this.Destroy=function(){
        if(!N.fixedView){
            M.detachEvent("onmousedown",eg);M.detachEvent("onmouseup",hg);M.detachEvent("onmousemove",gg);M.detachEvent("onmousewheel",kg);M.detachEvent("ondblclick",jg);M.detachEvent("oncontextmenu",lg);keyboard.detachEvent("onkeydown",Wc);keyboard.detachEvent("onkeyup",Xc);keyboard.detachEvent("onblur",Nb);
        }
        if(currentTilesList!=null){
            Th(currentTilesList);currentTilesList=null;
        }
        this.RemoveTrafficLayer();while(pushpins.length){
            pushpins.pop().Destroy();
        }
        pushpins=null;me();if(dashboard){
            dashboard.Destroy();dashboard=null;
        }
        if(dashboardContainer){
            dashboardContainer.detachEvent("onmousedown",IgnoreEvent);dashboardContainer.detachEvent("onmouseup",IgnoreEvent);dashboardContainer.detachEvent("onmousemove",IgnoreEvent);dashboardContainer.detachEvent("onmousewheel",IgnoreEvent);dashboardContainer.detachEvent("ondblclick",IgnoreEvent);dashboardContainer.detachEvent("oncontextmenu",IgnoreEvent);dashboardContainer.detachEvent("onkeydown",IgnoreEvent);dashboardContainer.detachEvent("onkeyup",IgnoreEvent);M.removeChild(dashboardContainer);dashboardContainer=null;
        }
        if(scaleBar){
            Pc("onendzoom",scaleBar.Update);Pc("onendcontinuouspan",scaleBar.Update);Pc("onresize",scaleBar.Reposition);scaleBar.Destroy();scaleBar=null;
        }
        if(logo){
            logo.Destroy();logo=null;
        }
        if(copyright){
            copyright.Destroy();copyright=null;
        }
        if(orthoMode){
            orthoMode.Destroy();orthoMode=null;
        }
        if(obliqueMode){
            obliqueMode.Destroy();obliqueMode=null;
        }
        if(boxTool){
            boxTool.Destroy();boxTool=null;
        }
        if(panTool){
            panTool.Destroy();panTool=null;
        }
        if(graphicCanvas)graphicCanvas.Destroy();Vc();M=p_this=null;
    }
    ;function O(){
        x=GetLeftPosition(M);y=GetTopPosition(M);width=M.offsetWidth;height=M.offsetHeight;
    }
    function P(x,y,Q,R){
        if(!Q)Q=Msn.VE.DashboardSize.Normal;if(Q==Msn.VE.DashboardSize.Tiny)Q=Msn.VE.DashboardSize.Small;dashboardContainer=document.createElement("div");if(R==null||typeof R=="undefined")R="dashboard";dashboardContainer.id=R;M.appendChild(dashboardContainer);dashboardContainer.className="Dashboard Dashboard_"+Q;dashboardContainer.style.top=y+"px";dashboardContainer.style.left=x+"px";dashboardContainer.attachEvent("onmousedown",IgnoreEvent);dashboardContainer.attachEvent("onmouseup",IgnoreEvent);dashboardContainer.attachEvent("onmousemove",IgnoreEvent);dashboardContainer.attachEvent("onmousewheel",IgnoreEvent);dashboardContainer.attachEvent("ondblclick",IgnoreEvent);dashboardContainer.attachEvent("oncontextmenu",IgnoreEvent);dashboardContainer.attachEvent("onkeydown",IgnoreEvent);dashboardContainer.attachEvent("onkeyup",IgnoreEvent);dashboard=new Msn.VE.Dashboard(dashboardContainer,p_this,Q);dashboard.Init();
    }
    function S(){
        var view=new Msn.VE.MapView();view.SetCenterLatLong(new Msn.VE.LatLong(0,0));view.SetZoomLevel(1);view.SetMapStyle(roadStyle);Jj(view);
    }
    function T(U,V){
        var view=preferredView.MakeCopy();view.SetCenterLatLong(new Msn.VE.LatLong(U,V));Jj(view);
    }
    function W(X,Y,Z){
        var view=currentView.MakeCopy();view.SetMapStyle(ab(X),Y,Z);if(currentView.mapStyle!=X){
            if(X==obliqueStyle){
                view.SetZoomLevel(1);lastOrthoZoomLevel=currentView.zoomLevel;lastOrthoMapStyle=currentView.mapStyle;
            }
            else{
                if(currentView.mapStyle==obliqueStyle)view.SetZoomLevel(lastOrthoZoomLevel);
            }
            
        }
        view.latlong.latitude=currentView.latlong.latitude;view.latlong.longitude=currentView.latlong.longitude;Jj(view);
    }
    function ab(bb){
        if(bb==aerialStyle||bb==hybridStyle||bb==obliqueStyle)return bb;else return roadStyle;
    }
    function cb(){
        if(currentView!=null&&currentView!="undefined"&&currentView.latlong!=null&&currentView.latlong!="undefined"&&currentView.latlong.latitude!=null&&currentView.latlong.latitude!="undefined")return currentView.latlong.latitude;return null;
    }
    function eb(){
        if(currentView!=null&&currentView!="undefined"&&currentView.latlong!=null&&currentView.latlong!="undefined"&&currentView.latlong.longitude!=null&&currentView.latlong.longitude!="undefined")return currentView.latlong.longitude;return null;
    }
    function gb(hb){
        currentView.latlong=currentMode.PixelToLatLong(currentView.center,currentView.zoomLevel);if(hb)preferredView.Copy(currentView);if(obliqueMode)obliqueMode.UpdateAvailability();
    }
    function jb(y){
        var pixel=new Msn.VE.Pixel(originX+offsetX+width/2,originY+offsetY+y);var latlong=currentMode.PixelToLatLong(pixel,currentView.zoomLevel);if(!latlong)return null;return latlong.latitude;
    }
    function kb(x){
        var pixel=new Msn.VE.Pixel(originX+offsetX+x,originY+offsetY+height/2);var latlong=currentMode.PixelToLatLong(pixel,currentView.zoomLevel);if(!latlong)return null;return latlong.longitude;
    }
    function lb(mb){
        var latlong=new Msn.VE.LatLong(mb,currentView.center.longitude);var pixel=currentMode.LatLongToPixel(latlong,currentView.zoomLevel);if(!pixel)return null;return MathRound(pixel.y-originY-offsetY);
    }
    function nb(ob){
        var latlong=new Msn.VE.LatLong(currentView.center.latitude,ob);var pixel=currentMode.LatLongToPixel(latlong,currentView.zoomLevel);if(!pixel)return null;return MathRound(pixel.x-originX-offsetX);
    }
    function pb(qb){
        var pixel=currentMode.LatLongToPixel(qb,currentView.zoomLevel);pixel.x-=(originX+offsetX);pixel.y-=(originY+offsetY);return pixel;
    }
    function rb(sb){
        var adjPixel=new Msn.VE.Pixel(sb.x+originX+offsetX,sb.y+originY+offsetY);var latlong=currentMode.PixelToLatLong(adjPixel,currentView.zoomLevel);
		return latlong;
    }
    function tb(){
        return currentView.zoomLevel;
    }
    function ub(){
        return currentView.mapStyle;
    }
    function vb(wb,xb){
        if(!wb)wb=currentView.latlong.latitude;if(!xb)xb=currentView.zoomLevel;return Math.cos(DegToRad(wb))*currentMode.MetersPerPixel(xb);
    }
    function yb(w,h){
        var width;var height;if(!w||w<=0)width="100%";else width=w+"px";if(!h||h<=0)height="100%";else height=h+"px";M.style.width=width;M.style.height=height;O();zg(currentView);copyright.Reposition();scaleBar.Reposition();if(logo)logo.Reposition();Sc("onresize");
    }
    function zb(){
        return obliqueMode?obliqueMode.IsAvailable():false;
    }
    function Ab(){
        return obliqueMode?obliqueMode.GetScene():null;
    }
    function Bb(Cb){
        animatedMovementEnabled=Cb;
    }
    function Db(){
        return animatedMovementEnabled;
    }
    function Eb(Fb){
        if(obliqueMode)W(obliqueStyle,Fb,null);
    }
    function Gb(Hb){
        if(obliqueMode)W(obliqueStyle,null,Hb);
    }
    function Ib(d){
        debug=d;for(var i=0;i<currentTilesList.length;i++){
            currentTilesList[i].Debug(d);
        }
        
    }
    function Jb(Kb,Lb){
        copyright.SetOffset(Kb,Lb);scaleBar.SetOffset(Kb,Lb);
    }
    function Mb(){
        keyboard.focus();
    }
    function Nb(){
        if(panning&&keyboardPan)vg();
    }
    function Ob(Pb,Qb){
        Rb(Pb,Qb,0,0);
    }
    function Rb(Sb,Tb,Ub,Vb){
        if(Tb!=null&&Tb!="undefined"){
            Ub=Wb(Ub,width,Sb.center.x-width/2,Sb.zoomLevel,Tb.z1,Tb.x1,Tb.x2);Vb=Wb(Vb,height,Sb.center.y-height/2,Sb.zoomLevel,Tb.z1,Tb.y1,Tb.y2);Sb.SetCenter(new Msn.VE.Pixel(Sb.center.x+Ub,Sb.center.y+Vb));
        }
        
    }
    function Wb(Xb,Yb,Zb,ac,bc,cc,ec){
        var min=tileSize*cc*Math.pow(2,ac-bc);var max=tileSize*ec*Math.pow(2,ac-bc);if(Yb>max-min)return (max-min-Yb)/2-Zb+min;else{
            if(Zb+Xb<min)return min-Zb;else{
                if(Zb+Yb+Xb>max)return max-Zb-Yb;
            }
            
        }
        return Xb;
    }
    function gc(hc,jc,kc,lc,mc,nc){
        this.MinZoomLevel=hc;this.MaxZoomLevel=jc;this.MinLatitude=kc;this.MinLongitude=lc;this.MaxLatitude=mc;this.MaxLongitude=nc;
    }
    gc.prototype.IsMatch=function(oc,pc,qc){
        var isMatch=false;if(oc>=this.MinZoomLevel&&oc<=this.MaxZoomLevel&&(pc>=this.MinLatitude&&pc<=this.MaxLatitude)&&(qc>=this.MinLongitude&&qc<=this.MaxLongitude))isMatch=true;return isMatch;
    }
    ;function rc(){
        var m_tableKeys=new Array();m_tableKeys[Msn.VE.MapStyle.Oblique]=[L_MapControlImageCourtesyOfPictometry_Text,L_MapControlImageCourtesyOfBlom_Text];m_tableKeys[Msn.VE.MapStyle.Road]=[L_MapControlNavteq_Text,L_MapControlImageCourtesyOfAND_Text];m_tableKeys[Msn.VE.MapStyle.Aerial]=[L_MapControlImageCourtesyOfNASA_Text,L_MapControlHarrisCorp_Text,L_MapControlImageCourtesyOfUSGS_Text,L_MapControlImageCourtesyOfEarthData_Text,L_MapControlImageCourtesyOfGetmapping_Text];var m_table=new Array();m_table[Msn.VE.MapStyle.Oblique]=new Array();m_table[Msn.VE.MapStyle.Oblique][L_MapControlImageCourtesyOfPictometry_Text]=new Array();m_table[Msn.VE.MapStyle.Oblique][L_MapControlImageCourtesyOfBlom_Text]=new Array();m_table[Msn.VE.MapStyle.Road]=new Array();m_table[Msn.VE.MapStyle.Road][L_MapControlNavteq_Text]=new Array();m_table[Msn.VE.MapStyle.Road][L_MapControlImageCourtesyOfAND_Text]=new Array();m_table[Msn.VE.MapStyle.Aerial]=new Array();m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfNASA_Text]=new Array();m_table[Msn.VE.MapStyle.Aerial][L_MapControlHarrisCorp_Text]=new Array();m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfUSGS_Text]=new Array();m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfEarthData_Text]=new Array();m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfGetmapping_Text]=new Array();m_table[Msn.VE.MapStyle.Oblique][L_MapControlImageCourtesyOfPictometry_Text].push(new gc(1,20,24,-125,49,-66));m_table[Msn.VE.MapStyle.Oblique][L_MapControlImageCourtesyOfBlom_Text].push(new gc(1,20,49,-11,60,2));m_table[Msn.VE.MapStyle.Road][L_MapControlNavteq_Text].push(new gc(1,9,-90,-180,90,180));m_table[Msn.VE.MapStyle.Road][L_MapControlNavteq_Text].push(new gc(10,19,16,-180,90,-50));m_table[Msn.VE.MapStyle.Road][L_MapControlNavteq_Text].push(new gc(10,19,27,-32,40,-13));m_table[Msn.VE.MapStyle.Road][L_MapControlNavteq_Text].push(new gc(10,19,35,-11,72,20));m_table[Msn.VE.MapStyle.Road][L_MapControlNavteq_Text].push(new gc(10,19,21,20,72,32));m_table[Msn.VE.MapStyle.Road][L_MapControlImageCourtesyOfAND_Text].push(new gc(10,19,-90,-180,90,180));m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfNASA_Text].push(new gc(1,8,-90,-180,90,180));m_table[Msn.VE.MapStyle.Aerial][L_MapControlHarrisCorp_Text].push(new gc(9,13,-90,-180,90,180));m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfUSGS_Text].push(new gc(14,19,17.99,-150.11,61.39,-65.57));m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfEarthData_Text].push(new gc(14,19,21.25,-158.3,21.72,-157.64));m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfEarthData_Text].push(new gc(14,19,39.99,-80.53,40.87,-79.43));m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfEarthData_Text].push(new gc(14,19,34.86,-90.27,35.39,-89.6));m_table[Msn.VE.MapStyle.Aerial][L_MapControlImageCourtesyOfGetmapping_Text].push(new gc(14,19,49.94,-6.35,58.71,1.78));this.CreditsFor=function(sc,tc,uc,vc){
            var credits=new Array();if(sc!="undefined"&&sc!=null&&typeof m_tableKeys[sc]!="undefined"&&m_tableKeys[sc]!=null){
                var numKeys=m_tableKeys[sc].length;for(var k=0;k<numKeys;++k){
                    var key=m_tableKeys[sc][k];var keyArray=m_table[sc][key];var numEntries=keyArray.length;for(var i=0;i<numEntries;++i){
                        if(keyArray[i].IsMatch(tc,uc,vc)){
                            credits.push(key);break;
                        }
                        
                    }
                    
                }
                
            }
            return credits;
        }
        ;this.CreditsForView=function(wc){
            var copyrightCredits=new Array();copyrightCredits.push(L_MapCopyrightMicrosoft);if(wc.mapStyle==Msn.VE.MapStyle.Hybrid){
                copyrightCredits=copyrightCredits.concat(this.CreditsFor(Msn.VE.MapStyle.Road,wc.zoomLevel,wc.latlong.latitude,wc.latlong.longitude));copyrightCredits=copyrightCredits.concat(this.CreditsFor(Msn.VE.MapStyle.Aerial,wc.zoomLevel,wc.latlong.latitude,wc.latlong.longitude));
            }
            else copyrightCredits=copyrightCredits.concat(this.CreditsFor(wc.mapStyle,wc.zoomLevel,wc.latlong.latitude,wc.latlong.longitude));return copyrightCredits;
        }
        ;
    }
    var g_sVECopyrightTable=new rc();function xc(yc){
        var bg=document.createElement("div");var fg=document.createElement("div");var copyrightHeight=13;var xOffset=0;var yOffset=0;this.Init=function(){
            bg.className="Copyright CopyrightBackground";fg.className="Copyright CopyrightForeground";zc();yc.appendChild(bg);yc.appendChild(fg);
        }
        ;this.Destroy=function(){
            yc.removeChild(bg);yc.removeChild(fg);bg=fg=null;
        }
        ;function zc(){
            bg.style.top=height-copyrightHeight-3-yOffset-(copyrightHeight<=13?4:0)+"px";bg.style.height=copyrightHeight+"px";bg.style.right="9px";bg.style.display="block";fg.style.top=height-copyrightHeight-3-1-yOffset-(copyrightHeight<=13?4:0)+"px";fg.style.height=copyrightHeight+"px";fg.style.right="10px";fg.style.display="block";
        }
        function Ac(){
            var credits=g_sVECopyrightTable.CreditsForView(currentView);var copyrightString="";for(var i=0;i<credits.length;++i){
                if(i>0){
                    if(i==2)copyrightString+="<br/>";else copyrightString+="&nbsp;&nbsp;";
                }
                copyrightString+=credits[i];
            }
            if(credits.length<=2)copyrightHeight=13;else copyrightHeight=21;bg.innerHTML=copyrightString;fg.innerHTML=copyrightString;zc();
        }
        function Bc(Cc,Dc){
            xOffset=Cc;yOffset=Dc;zc();
        }
        this.Reposition=zc;this.Update=Ac;this.SetOffset=Bc;
    }
    function Ec(Fc,Gc,Hc){
        this.view=Fc;this.oblique=Gc;this.error=Hc;
    }
    function Ic(Jc,Kc,Lc){
        var view=currentView.MakeCopy();if(Jc!=undefined){
            if(Msn.VE.API!=null){
                var veLatLongFactory=new VELatLongFactory(new VELatLongFactorySpecFromMapView(view));view.LatLong=veLatLongFactory.CreateVELatLong(Jc.latitude,Jc.longitude);
            }
            else view.latlong=Jc;
        }
        if(Kc!=undefined)view.zoomLevel=Kc;if(Lc==undefined)Lc="";var oblique=null;if(obliqueMode)oblique=obliqueMode.GetEventInfo();return new Ec(view,oblique,Lc);
    }
    function Mc(Nc,Oc){
        var eventList=eventTable[Nc];if(!eventList){
            eventList=new Array();eventTable[Nc]=eventList;
        }
        for(var i=0;i<eventList.length;i++){
            if(eventList[i]==Oc)return true;
        }
        eventList.push(Oc);
    }
    function Pc(Qc,Rc){
        var eventList=eventTable[Qc];if(!eventList)return;for(var i=0;i<eventList.length;i++){
            if(eventList[i]==Rc)eventList.splice(i,1);
        }
        
    }
    function Sc(Tc,Uc){
        var eventList=eventTable[Tc];if(!eventList)return;if(!Uc)Uc=Ic();for(var i=0;i<eventList.length;i++){
            eventList[i](Uc);
        }
        
    }
    function Vc(){
        while(eventTable.length){
            var eventList=eventTable.pop();while(eventList.length){
                eventList.pop();
            }
            eventList=null;
        }
        eventTable=null;
    }
    function Wc(e){
        e=GetEvent(e);var s=keyboardPanSpeed;var x=panningX;var y=panningY;switch(e.keyCode){
            case 9:case 18:if(panning&&keyboardPan)vg();return true;case 37:x=-s;break;case 38:y=-s;break;case 39:x=s;break;case 40:y=s;break;case 107:case 187:case 61:case 43:x=0;y=0;jk();break;case 109:case 189:x=0;y=0;kk();break;case 65:x=0;y=0;W(aerialStyle);break;case 72:x=0;y=0;W(hybridStyle);break;case 82:case 86:x=0;y=0;W(roadStyle);break;case 66:case 79:x=0;y=0;W(obliqueStyle);break;default:return false;
        }
        if(x||y)pg(x,y,null,true);return false;
    }
    function Xc(e){
        e=GetEvent(e);var x=panningX;var y=panningY;switch(e.keyCode){
            case 37:x=0;break;case 38:y=0;break;case 39:x=0;break;case 40:y=0;break;default:return false;
        }
        pg(x,y,null,true);return false;
    }
    var northLatitude=0;var southLatitude=0;var westLongitude=0;var eastLongitude=0;function Yc(Zc,ae,be,ce,ee,ge,he,je){
        if(Zc==null||ae==null||be==null||he==null||je==null)return null;var regionHeap=new Array();for(var i=0;i<he.length;i++){
            regionHeap.push(qe(he[i],0,he[i].length-1));
        }
        var line=new ue();line.Init(Zc,ae,be,ce,ee,ge,regionHeap,je);lines.push(line);return line;
    }
    function ke(le){
        for(var i=0;i<lines.length;i++){
            var line=lines[i];if(line.id==le){
                lines.splice(i,1);line.Destroy();return;
            }
            
        }
        
    }
    function me(){
        while(lines.length>0){
            lines.pop().Destroy();
        }
        
    }
    function ne(){
        for(var i=0;i<lines.length;i++){
            lines[i].StartLine();lines[i].Show();
        }
        
    }
    function oe(){
        for(var i=0;i<lines.length;i++){
            lines[i].Hide();
        }
        
    }
    function pe(){
        for(var i=0;i<lines.length;i++){
            lines[i].UpdateLine();
        }
        
    }
    function qe(re,se,te){
        var numberOfRegions=te-se+1;if(numberOfRegions<1)return null;else{
            if(numberOfRegions==1)return re[se];
        }
        var leftRegion=null;var rightRegion=null;if(numberOfRegions==2){
            leftRegion=re[se];rightRegion=re[te];
        }
        else{
            var i=Math.round((se+te)/2);leftRegion=qe(re,se,i);rightRegion=qe(re,i+1,te);
        }
        if(leftRegion!=null&&rightRegion!=null){
            var left=leftRegion.boundingRectangle;var right=rightRegion.boundingRectangle;var northLatitude=left[0].latitude>right[0].latitude?left[0].latitude:right[0].latitude;var eastLongitude=left[0].longitude>right[0].longitude?left[0].longitude:right[0].longitude;var southLatitude=left[1].latitude<right[1].latitude?left[1].latitude:right[1].latitude;var westLongitude=left[1].longitude<right[1].longitude?left[1].longitude:right[1].longitude;var combinedBoundingRectangle=[new Msn.VE.LatLong(northLatitude,eastLongitude),new Msn.VE.LatLong(southLatitude,westLongitude)];return new Msn.VE.LineRegion(combinedBoundingRectangle,null,[leftRegion,rightRegion]);
        }
        else{
            if(leftRegion!=null)return leftRegion;else{
                if(rightRegion!=null)return rightRegion;
            }
            
        }
        return null;
    }
    function ue(){
        var defaultLineWeight=5;var defaultLineColor=new Msn.Drawing.Color(0,169,235,0.7);var routeStroke=new Msn.Drawing.Stroke();var defaultLineZIndex=4;var element=null;var elementId="";var visible=true;var strokeweight="";var strokecolor="";var zIndex=0;var startLatitude=0;var startLongitude=0;var endLatitude=0;var endLongitude=0;var latitudes=null;var longitudes=null;var lineRegions=null;var zoomLevelsForGeneralizedLines=null;var startIndex=0;var endIndex=0;var lastRedrawView=null;function ve(we,xe,ye,ze,Ae,Be,Ce,De){
            if(!ze)ze=defaultLineWeight;if(!Ae)Ae=defaultLineColor;if(!Be)Be=defaultZIndex;this.id=we;elementId=we;strokeweight=ze+"pt";strokecolor=Ae;zIndex=Be;latitudes=xe;longitudes=ye;zoomLevelsForGeneralizedLines=De;lineRegions=Ce;startLatitude=latitudes[0];startLongitude=longitudes[0];endLatitude=latitudes[latitudes.length-1];endLongitude=longitudes[longitudes.length-1];lastRedrawView=currentView.MakeCopy();routeStroke.color=defaultLineColor;routeStroke.width=ze;Ke();
        }
        function Ee(){
            Fe();latitudes=longitudes=lineRegions=element=lastRedrawView=null;
        }
        function Fe(){
            graphicCanvas.Clear();
        }
        function Ge(){
            if(!visible){
                He();return;
            }
            if(element)element.style.display="block";
        }
        function He(){
            if(element)element.style.display="none";
        }
        function Ie(Je){
            visible=Je;if(!visible)He();
        }
        function Ke(){
            Me();Ne();lastRedrawView.Copy(currentView);
        }
        function Le(){
            if(currentView.zoomLevel==lastRedrawView.zoomLevel&&MathAbs((currentView.center.x-lastRedrawView.center.x)/width)<0.25&&MathAbs((currentView.center.y-lastRedrawView.center.y)/height)<0.25)return;Me();Ne();lastRedrawView=currentView.MakeCopy();
        }
        function Me(){
            var bufferHeight=height<900?900:height;var bufferWidth=width<900?900:width;northLatitude=jb(-0.5*bufferHeight);southLatitude=jb(1.5*bufferHeight);westLongitude=kb(-0.5*bufferWidth);eastLongitude=kb(1.5*bufferWidth);
        }
        function Ne(){
            if(currentView.mapStyle==obliqueStyle){
                graphicCanvas.Clear();return;
            }
            var points=new Array();var generalizedLineIndex=zoomLevelsForGeneralizedLines.length-1;while(zoomLevelsForGeneralizedLines[generalizedLineIndex]<currentView.zoomLevel&&generalizedLineIndex>=0){
                generalizedLineIndex--;
            }
            Oe(lineRegions[generalizedLineIndex],points);Re(points);
        }
        function Oe(Pe,Qe){
            if(We(Pe.boundingRectangle[0],Pe.boundingRectangle[1]))return;if(Pe.childRegions!=null)for(var i=0;i<Pe.childRegions.length;i++){
                Oe(Pe.childRegions[i],Qe);
            }
            else{
                var indices=Pe.indices;var firstPoint=new Msn.VE.LatLong(latitudes[indices[0]],longitudes[indices[0]]);var secondPoint;var inVisibleSegment=false;if(Te(firstPoint.latitude,firstPoint.longitude)){
                    var firstPixel=currentMode.LatLongToPixel(firstPoint,currentView.zoomLevel);Qe.push(new Msn.Drawing.Point(firstPixel.x-originX,firstPixel.y-originY));inVisibleSegment=true;
                }
                for(var pointIndex=1;pointIndex<indices.length;pointIndex++){
                    secondPoint=new Msn.VE.LatLong(latitudes[indices[pointIndex]],longitudes[indices[pointIndex]]);if(Te(secondPoint.latitude,secondPoint.longitude)){
                        if(!inVisibleSegment){
                            var firstPixel=currentMode.LatLongToPixel(firstPoint,currentView.zoomLevel);Qe.push(new Msn.Drawing.Point(firstPixel.x-originX,firstPixel.y-originY));
                        }
                        inVisibleSegment=true;var secondPixel=currentMode.LatLongToPixel(secondPoint,currentView.zoomLevel);Qe.push(new Msn.Drawing.Point(secondPixel.x-originX,secondPixel.y-originY));
                    }
                    else{
                        if(inVisibleSegment){
                            inVisibleSegment=false;var secondPixel=currentMode.LatLongToPixel(secondPoint,currentView.zoomLevel);Qe.push(new Msn.Drawing.Point(secondPixel.x-originX,secondPixel.y-originY));
                        }
                        
                    }
                    firstPoint=secondPoint;
                }
                
            }
            
        }
        function Re(Se){
            if(!graphicCanvas)return;He();graphicCanvas.Clear();var polyline=new Msn.Drawing.PolyLine(Se);polyline.id=elementId;routeStroke.width=4;graphicCanvas.SetZIndex(zIndex);graphicCanvas.SetStroke(routeStroke);graphicCanvas.DrawPolyline(polyline);element=document.getElementById(elementId);if(visible)element.style.display="block";else element.style.display="none";
        }
        function Te(Ue,Ve){
            return Ue>=southLatitude&&Ue<=northLatitude&&Ve>=westLongitude&&Ve<=eastLongitude;
        }
        function We(Xe,Ye){
            return Xe.latitude>northLatitude&&Ye.latitude>northLatitude||Xe.latitude<southLatitude&&Ye.latitude<southLatitude||Xe.longitude>eastLongitude&&Ye.longitude>eastLongitude||Xe.longitude<westLongitude&&Ye.longitude<westLongitude;
        }
        this.Init=ve;this.Destroy=Ee;this.RemoveFromMap=Fe;this.Show=Ge;this.Hide=He;this.ChangeVisibility=Ie;this.StartLine=Ke;this.UpdateLine=Le;
    }
    function Ze(ag){
        var image=null;this.Init=function(){
            if(navigator.userAgent.toLowerCase().indexOf("msie")!=-1){
                image=document.createElement("div");image.className="PoweredByLogo PoweredByLogo_ie";if(Msn.VE.API!=null)image.style.filter="progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+Msn.VE.API.Globals.vecurrentdomain+"/"+MapControl.Features.Image.PoweredLogo+"', sizingMethod='scale')";
            }
            else{
                image=document.createElement("img");var imgPrefix="http://"+location.host;if(Msn.VE.API!=null)imgPrefix=Msn.VE.API.Globals.vecurrentdomain;image.src=imgPrefix+"/"+MapControl.Features.Image.PoweredLogo;image.className="PoweredByLogo";
            }
            image.onclick=function(){
                window.open("http://local.live.com");
            }
            ;bg();ag.appendChild(image);
        }
        ;this.Destroy=function(){
            ag.removeChild(image);image=null;
        }
        ;function bg(){
            image.style.top=height-40+"px";image.style.left="6px";image.style.display="block";
        }
        function cg(){
            bg();
        }
        this.Reposition=bg;this.Update=cg;
    }
    function eg(e){
        e=GetEvent(e);CancelEvent(e);if(zooming)return false;if(panning)vg();if(obliqueMode)obliqueMode.CancelRequest();if(e.which&&e.which==2)currentTool=boxTool;else{
            if(!e.which&&e.button&&e.button==4)currentTool=boxTool;else{
                if(e.altKey)currentTool=boxTool;
            }
            
        }
        dragging=true;currentTool.OnMouseDown(e);return false;
    }
    function gg(e){
        e=GetEvent(e);CancelEvent(e);if(dragging)currentTool.OnMouseMove(e);return false;
    }
    function hg(e){
        e=GetEvent(e);CancelEvent(e);dragging=false;currentTool.OnMouseUp(e);currentTool=panTool;try{
            var y=window.pageYOffset;keyboard.focus();if(typeof y=="number")window.scrollTo(0,y);
        }
        catch(err){
            
        }
        return false;
    }
    function jg(e){
        e=GetEvent(e);CancelEvent(e);O();if(panning||zooming)return false;var view=preferredView.MakeCopy();view.SetCenter(new Msn.VE.Pixel(originX+offsetX+GetMouseX(e)-x,originY+offsetY+GetMouseY(e)-y));if(e.altKey)view.SetZoomLevel(currentView.zoomLevel-1);else view.SetZoomLevel(currentView.zoomLevel+1);Jj(view);return false;
    }
    function kg(e){
        e=GetEvent(e);CancelEvent(e);if(panning||zooming)return false;var delta=GetMouseScrollDelta(e);if(delta>0)jk();else{
            if(delta<0)kk();
        }
        return false;
    }
    function lg(e){
        e=GetEvent(e);CancelEvent(e);var clickX=originX+offsetX+GetMouseX(e)-x;var clickY=originY+offsetY+GetMouseY(e)-y;var clickEvent=Ic(currentMode.PixelToLatLong(new Msn.VE.Pixel(clickX,clickY),currentView.zoomLevel));Sc("oncontextmenu",clickEvent);return false;
    }
    function mg(ng,og){
        if(ng==0&&og==0)return;Rb(currentView,currentBounds,ng,og);offsetX=currentView.center.x-originX-width/2;offsetY=currentView.center.y-originY-height/2;map.style.top=-offsetY+"px";map.style.left=-offsetX+"px";copyright.Update();window.setTimeout(Ij,1);window.setTimeout(pe,2);
    }
    function pg(qg,rg,sg,tg){
        if(zooming)return;if(!sg)sg=-1;panningX=qg;panningY=rg;panCounter=sg;if(!qg&&!rg){
            vg();return;
        }
        keyboardPan=tg;if(!panning){
            panning=true;ug();Sc("onstartcontinuouspan");
        }
        
    }
    function ug(){
        if(panning){
            mg(panningX,panningY);if(panCounter>0)panCounter--;if(panCounter!=0)window.setTimeout(ug,10);else vg();
        }
        
    }
    function vg(){
        panningX=0;panningY=0;panning=false;keyboardPan=false;if(panLatitude!=null&&panLongitude!=null){
            var latlong=new Msn.VE.LatLong(panLatitude,panLongitude);var pixel=currentMode.LatLongToPixel(latlong,currentView.zoomLevel);var dx=pixel.x-(originX+offsetX+width/2);var dy=pixel.y-(originY+offsetY+height/2);mg(dx,dy);currentView.latlong.latitude=panLatitude;currentView.latlong.longitude=panLongitude;preferredView.Copy(currentView);panLatitude=null;panLongitude=null;if(obliqueMode)obliqueMode.UpdateAvailability();
        }
        else gb(true);Sc("onendcontinuouspan");Sc("onchangeview");
    }
    function wg(xg,yg){
        panLatitude=xg;panLongitude=yg;Bg(currentMode.LatLongToPixel(new Msn.VE.LatLong(xg,yg),currentView.zoomLevel));
    }
    function zg(Ag){
        Bg(Ag.center);
    }
    function Bg(Cg){
        if(currentView.mapStyle==obliqueStyle){
            var scene=obliqueMode.GetScene();if(!scene||!scene.ContainsPixel(Cg,currentView.zoomLevel)){
                var view=preferredView.MakeCopy();view.sceneId=null;view.SetCenterLatLong(obliqueMode.PixelToLatLong(Cg,currentView.zoomLevel));Jj(view);return;
            }
            
        }
        var dx=Cg.x-(originX+offsetX+width/2);var dy=Cg.y-(originY+offsetY+height/2);var distance=Math.sqrt(dx*dx+dy*dy);if(!animatedMovementEnabled||MathAbs(dx)>2*width||MathAbs(dy)>2*height||distance>1.5*Math.sqrt(width*width+height*height)){
            var view=preferredView.MakeCopy();view.SetCenter(Cg);Jj(view);return;
        }
        var angle=Math.atan2(dy,dx);var count=MathCeil(distance/panToLatLongSpeed);var speed=MathRound(distance/count);dx=MathRound(Math.cos(angle)*speed);dy=MathRound(Math.sin(angle)*speed);pg(dx,dy,count);
    }
    function Dg(x,y){
        this.x=x;this.y=y;
    }
    function Eg(Fg){
        var pinType=Msn.VE.PushPinTypes;var offset;switch(Fg){
            case pinType.Annotation:offset=new Dg(-2,-19.5);break;case pinType.SearchResult:offset=new Dg(0,-11.5);break;case pinType.Direction:offset=new Dg(-3,-16);break;case pinType.DirectionTemp:offset=new Dg(2,-10);break;case pinType.TrafficLight:offset=new Dg(0,-13);break;case pinType.TrafficOthers:offset=new Dg(0,-14.5);break;case pinType.YouAreHere:offset=new Dg(0,-13);break;case pinType.Default:default:offset=new Dg(0,0);break;
        }
        return offset;
    }
    function Gg(){
        return pushpins;
    }
    function Hg(Ig,Jg,Kg,Lg,Mg,Ng,Og,Pg,Qg){
        var pin=new Vg();pin.Init(Ig,Jg,Kg,Lg,Mg,Ng,Og,Pg,Qg);pushpins.push(pin);return pin.pin;
    }
    function Rg(Sg){
        for(var i=0;i<pushpins.length;i++){
            var p=pushpins[i];if(p.id==Sg){
                pushpins.splice(i,1);p.Destroy();return;
            }
            
        }
        
    }
    function Tg(){
        while(pushpins.length>0){
            pushpins.pop().Destroy();
        }
        
    }
    function Ug(){
        for(var i=0;i<pushpins.length;i++){
            pushpins[i].Reposition();
        }
        
    }
    function Vg(){
        var pin=document.createElement("a");pin.href="javascript://pushin hover";pin.onclick=function(){
            return ParseShiftKeyForLinks(event);
        }
        ;pin.vePushpin=this;this.pin=pin;var x1=0;var y1=0;var x2=0;var y2=0;var center=null;var w=0;var h=0;var n=zoomTotalSteps+1;var xs=new Array(n);var ys=new Array(n);var Offset;this.Init=function(Wg,Xg,Yg,Zg,ah,bh,ch,eh,gh){
            this.id=Wg;pin.id=Wg;pin.className=bh;pin.style.position="absolute";pin.innerHTML=ch;pin.pinType=gh||Msn.VE.PushPinTypes.Default;Offset=Eg(pin.pinType);if(!N.fixedView){
                pin.attachEvent("ondblclick",sh);pin.attachEvent("onmousewheel",th);
            }
            pin.unselectable="on";center=new Msn.VE.LatLong(Xg,Yg);w=Zg;h=ah;var pixel=currentMode.LatLongToPixel(center,currentView.zoomLevel);if(pixel){
                x1=MathRound(pixel.x-originX);y1=MathRound(pixel.y-originY);x2=x1;y2=y1;jh();kh(0);pin.style.display="block";
            }
            else pin.style.display="none";map.appendChild(pin);
        }
        ;this.Destroy=function(){
            pin.detachEvent("ondblclick",sh);pin.detachEvent("onmousewheel",th);rh();pin.vePushpin=null;pin=null;this.pin=null;while(xs.length>0){
                xs.pop();
            }
            while(ys.length>0){
                ys.pop();
            }
            
        }
        ;this.GetLatitude=function(){
            return center.latitude;
        }
        ;this.GetLongitude=function(){
            return center.longitude;
        }
        ;function hh(){
            var n=zoomTotalSteps;for(var i=0;i<=n;i++){
                xs[i]=x1-w/2+Offset.x+"px";ys[i]=y1-h/2+Offset.y+"px";
            }
            
        }
        function jh(){
            var n=zoomTotalSteps;for(var i=0;i<=n;i++){
                var a=i/n;var b=1-a;xs[i]=MathFloor(b*x1+a*x2-w/2+Offset.x)+"px";ys[i]=MathFloor(b*y1+a*y2-h/2+Offset.y)+"px";
            }
            
        }
        function kh(i){
            pin.style.left=xs[i];pin.style.top=ys[i];
        }
        function lh(){
            var t=0;t=x1;x1=x2;x2=t;t=y1;y1=y2;y2=t;
        }
        function mh(){
            var pixel=currentMode.LatLongToPixel(center,currentView.zoomLevel);if(pixel){
                x1=MathRound(pixel.x-originX);y1=MathRound(pixel.y-originY);hh();kh(0);pin.style.display="block";
            }
            else pin.style.display="none";
        }
        function nh(oh,ph,qh){
            x1-=offsetX;y1-=offsetY;var pixel=currentMode.LatLongToPixel(center,qh);if(pixel){
                x2=MathRound(pixel.x-oh);y2=MathRound(pixel.y-ph);jh();pin.style.display="block";
            }
            else pin.style.display="none";
        }
        function rh(){
            if(pin.parentNode==map)map.removeChild(pin);
        }
        function sh(e){
            e=GetEvent(e);CancelEvent(e);if(panning||zooming)return false;var view=preferredView.MakeCopy();view.SetCenterLatLong(center);if(e.altKey)view.SetZoomLevel(currentView.zoomLevel-1);else view.SetZoomLevel(currentView.zoomLevel+1);Jj(view);return false;
        }
        function th(e){
            e=GetEvent(e);CancelEvent(e);if(panning||zooming)return false;var delta=GetMouseScrollDelta(e);if(delta>0)jk();else{
                if(delta<0)kk();
            }
            return false;
        }
        function uh(vh,wh){
            center=rb(vh);mh();
        }
        this.ClearSteps=hh;this.PrecomputeSteps=jh;this.SetFactor=kh;this.SwapStates=lh;this.Reposition=mh;this.PrepareForZoom=nh;this.RemoveFromMap=rh;this.Move=uh;
    }
    function xh(yh){
        var xOffset=0;var yOffset=0;var labelBg=document.createElement("div");var labelFg=document.createElement("div");var barBg=document.createElement("div");var barFg=document.createElement("div");var scaleBarWidth=150;this.Init=function(){
            labelBg.className="ScaleBarLabel ScaleBarLabelBackground";labelFg.className="ScaleBarLabel ScaleBarLabelForeground";barBg.className="ScaleBar ScaleBarBackground";barFg.className="ScaleBar ScaleBarForeground";Gh();zh();yh.appendChild(labelBg);yh.appendChild(labelFg);yh.appendChild(barBg);yh.appendChild(barFg);
        }
        ;this.Destroy=function(){
            yh.removeChild(labelBg);yh.removeChild(labelFg);yh.removeChild(barBg);yh.removeChild(barFg);labelBg=labelFg=barBg=BarFg=null;
        }
        ;function zh(){
            labelBg.style.top=height-45-yOffset+"px";labelBg.style.right="10px";labelBg.style.display="block";labelFg.style.top=height-46-yOffset+"px";labelFg.style.right="11px";labelFg.style.display="block";barBg.style.top=height-30-yOffset+"px";barBg.style.right="9px";barBg.style.display="block";barFg.style.top=height-31-yOffset+"px";barFg.style.right="10px";barFg.style.display="block";
        }
        function Ah(Bh){
            return Bh*0.001;
        }
        function Ch(Dh){
            return Dh*0.000621371192;
        }
        function Eh(Fh){
            return Fh*1.0936133;
        }
        function Gh(){
            try{
                var mpp=vb();var maxMeters=mpp*scaleBarWidth;if(Msn.VE.Marketization.IsEnabled(MapControl.Features.ScaleBarKilometers)){
                    var units=L_ScaleBarKilometers_Text;var dMeasure=Ah(maxMeters);var niceValue=Hh(dMeasure);if(niceValue<0.5){
                        units=L_ScaleBarMeters_Text;dMeasure=maxMeters;niceValue=Hh(dMeasure);
                    }
                    Jh("metric",units,niceValue,Math.round(niceValue/dMeasure*scaleBarWidth));
                }
                else{
                    var units=L_ScaleBarMiles_Text;var dMeasure=Ch(maxMeters);var niceValue=Hh(dMeasure);if(niceValue<0.5){
                        units=L_ScaleBarYards_Text;dMeasure=Eh(maxMeters);niceValue=Hh(dMeasure);
                    }
                    Jh("us",units,niceValue,Math.round(niceValue/dMeasure*scaleBarWidth));
                }
                
            }
            catch(ex){
                
            }
            
        }
        function Hh(Ih){
            var dLog10=Math.log(Ih)/Math.log(10);var dExponent=Math.floor(dLog10);var dExponentValue=Math.pow(10,dExponent);var dRoot=Ih/dExponentValue;var dIntegerRoot=Math.floor(dRoot);if(dIntegerRoot>=3)return dIntegerRoot*dExponentValue;var dNiceRoot=Math.floor(dRoot*2)*0.5;return dNiceRoot*dExponentValue;
        }
        function Jh(Kh,Lh,Mh,Nh){
            if(Mh<1)Mh=Mh.toFixed(1);var text=Mh+" "+Lh;labelBg.innerHTML=text;labelFg.innerHTML=text;barBg.style.width=Nh;barFg.style.width=Nh;
        }
        function Oh(Ph,Qh){
            xOffset=Ph;yOffset=Qh;zh();
        }
        this.Update=Gh;this.Reposition=zh;this.SetOffset=Oh;
    }
    var totalRequestTime=0;var totalRequestCount=0;var totalFailureCount=0;var responseRangeCeilings=new Array();responseRangeCeilings[roadStyle]=[325,975];responseRangeCeilings[aerialStyle]=[350,1050];responseRangeCeilings[hybridStyle]=[425,1275];responseRangeCeilings[obliqueStyle]=[450,1350];var responseRangeCounts=[0,0,0];function Rh(x,y,z,s,Sh){
        var t=new Yh();t.Init(x,y,z,s,x*tileSize-originX,y*tileSize-originY,Sh);return t;
    }
    function Th(Uh){
        while(Uh.length>0){
            var tile=Uh.pop();tile.Destroy();tile=null;
        }
        
    }
    function Vh(){
        var total=0;for(var i=0;i<responseRangeCounts.length;i++){
            total+=responseRangeCounts[i];
        }
        if(total==0)return responseRangeCounts;var responseRangePercentages=new Array(responseRangeCounts.length);for(var i=0;i<responseRangeCounts.length;i++){
            responseRangePercentages[i]=responseRangeCounts[i]/total;
        }
        return responseRangePercentages;
    }
    function Wh(){
        for(var i=0;i<responseRangeCounts.length;i++){
            responseRangeCounts[i]=0;
        }
        
    }
    function Xh(){
        return totalFailureCount/totalRequestCount;
    }
    function Yh(){
        var img=null;var request=null;var overlay=document.createElement("div");var tileX=0;var tileY=0;var tileZoom=0;var mapStyle=0;var zIndex=0;var n=zoomTotalSteps+1;var xs=new Array(n);var ys=new Array(n);var ws=new Array(n);var hs=new Array(n);var animated=false;var x1=0;var y1=0;var w1=0;var h1=0;var x2=0;var y2=0;var w2=0;var h2=0;var startTime=null;var tiletype=0;this.Init=function(Zh,aj,bj,cj,x,y,ej){
            tileX=Zh;tileY=aj;tileZoom=bj;mapStyle=cj;overlay.style.font="7pt Verdana, sans-serif";overlay.style.color="Red";overlay.style.backgroundColor="White";if(!currentMode.IsValidTile(tileX,tileY,tileZoom))return;gj(x,y,tileSize,tileSize);hj(x,y,tileSize,tileSize);kj();tiletype=ej;request=new Image();request.onload=oj;request.onerror=pj;startTime=new Date();request.src=currentMode.GetFilename(tileX,tileY,tileZoom,ej);
        }
        ;this.Destroy=function(){
            if(img)img.onmousedown=null;nj();while(xs.length>0){
                xs.pop();
            }
            while(ys.length>0){
                ys.pop();
            }
            while(ws.length>0){
                ws.pop();
            }
            while(hs.length>0){
                hs.pop();
            }
            xs=ys=ws=hs=null;
        }
        ;function gj(x,y,w,h){
            x1=x;y1=y;w1=w;h1=h;
        }
        this.SetCurrentState=gj;function hj(x,y,w,h){
            x2=x;y2=y;w2=w;h2=h;
        }
        this.SetNextState=hj;function jj(){
            for(var i=0;i<=zoomTotalSteps;i++){
                xs[i]=x1+"px";ys[i]=y1+"px";ws[i]=w1+"px";hs[i]=h1+"px";
            }
            
        }
        this.ClearSteps=jj;function kj(){
            for(var i=0;i<=zoomTotalSteps;i++){
                var a=i/zoomTotalSteps;var b=1-a;xs[i]=MathFloor(b*x1+a*x2)+"px";ys[i]=MathFloor(b*y1+a*y2)+"px";ws[i]=MathCeil(b*w1+a*w2)+"px";hs[i]=MathCeil(b*h1+a*h2)+"px";
            }
            
        }
        this.PrecomputeSteps=kj;function lj(i){
            if(img==null||zooming&&!animated)return;var style=img.style;style.left=xs[i];style.top=ys[i];style.width=ws[i];style.height=hs[i];var overlayStyle=overlay.style;if(debug&&i==0){
                style.border="1px dashed red";overlayStyle.left=xs[i];overlayStyle.top=ys[i];
            }
            if(img.parentNode!=map){
                style.position="absolute";style.zIndex=zIndex;if(tiletype>0){
                    style.zIndex=tiletype+1;if(style&&typeof style.filter!="undefined")style.filter="alpha(opacity=60);opacity:.60;";else style.opacity=0.6;
                }
                map.appendChild(img);if(debug&&overlay.parentNode!=map){
                    var path=img.src;overlay.innerHTML=path.substring(path.lastIndexOf("/")+1,path.lastIndexOf("."));overlayStyle.position="absolute";overlayStyle.zIndex=zIndex+1;map.appendChild(overlay);
                }
                
            }
            
        }
        this.SetFactor=lj;function mj(){
            var t=0;t=x1;x1=x2;x2=t;t=y1;y1=y2;y2=t;t=w1;w1=w2;w2=t;t=h1;h1=h2;h2=t;
        }
        this.SwapStates=mj;function nj(){
            if(request){
                request.onload=null;request.onerror=null;request.src=null;request=null;
            }
            if(img){
                if(img.parentNode==map)map.removeChild(img);img=null;
            }
            if(overlay){
                if(overlay.parentNode==map)map.removeChild(overlay);overlay=null;
            }
            
        }
        this.RemoveFromMap=nj;function oj(){
            if(tileZoom!=currentView.zoomLevel||request==null)return;var endTime=new Date();var lastTime=endTime.getTime()-startTime.getTime();qj(lastTime);totalRequestTime+=lastTime;totalRequestCount++;if(debug)window.status="last="+lastTime+", average="+totalRequestTime/totalRequestCount;request.onload=null;request.onerror=null;img=request;img.onmousedown=function(e){
                return false;
            }
            ;request=null;if(!zooming)lj(zoomCounter);
        }
        function pj(){
            if(tileZoom!=currentView.zoomLevel||request==null)return;var endTime=new Date();var lastTime=endTime.getTime()-startTime.getTime();qj(lastTime);totalRequestTime+=lastTime;totalRequestCount++;totalFailureCount++;request.onload=null;request.onerror=null;request=null;
        }
        function qj(rj){
            for(var i=0;i<responseRangeCeilings[mapStyle].length;i++){
                if(rj<responseRangeCeilings[mapStyle][i]){
                    responseRangeCounts[i]++;return;
                }
                
            }
            responseRangeCounts[responseRangeCounts.length-1]++;
        }
        function sj(tj,uj,vj,wj,xj,yj){
            gj(x1-offsetX,y1-offsetY,w1,h1);var deltaZoom=yj-vj;var zoomFactor=Math.pow(2,deltaZoom);x2=MathFloor((tj+x1)*zoomFactor-wj);y2=MathFloor((uj+y1)*zoomFactor-xj);w2=MathCeil((tj+x1+w1)*zoomFactor-wj)-x2;h2=MathCeil((uj+y1+h1)*zoomFactor-xj)-y2;animated=true;kj();zIndex=baseZIndex;if(img!=null)img.style.zIndex=zIndex;
        }
        this.PrepareBaseTile=sj;function zj(Aj,Bj,Cj,Dj,Ej,Fj){
            var deltaZoom=Cj-Fj;var zoomFactor=Math.pow(2,deltaZoom);x2=MathFloor((Dj+x1)*zoomFactor-Aj);y2=MathFloor((Ej+y1)*zoomFactor-Bj);w2=MathCeil((Dj+x1+w1)*zoomFactor-Aj)-x2;h2=MathCeil((Ej+y1+h1)*zoomFactor-Bj)-y2;var quarterWidth=MathCeil(tileViewportWidth*0.25);var quarterHeight=MathCeil(tileViewportHeight*0.25);animated=Fj<Cj&&(tileX<tileViewportX1+quarterWidth||tileX>tileViewportX2-quarterWidth||tileY<tileViewportY1+quarterHeight||tileY>tileViewportY2-quarterHeight);mj();kj();zIndex=swapZIndex;
        }
        this.PrepareSwapTile=zj;function Gj(d){
            if(img!=null)img.style.border=d?"1px dashed red":"0px";overlay.style.display=d?"block":"none";
        }
        this.Debug=Gj;
    }
    function Hj(){
        Th(currentTilesList);map.style.top="0px";map.style.left="0px";originX=MathRound(currentView.center.x-width/2);originY=MathRound(currentView.center.y-height/2);offsetX=0;offsetY=0;tileViewportX1=MathFloor((originX-buffer)/tileSize);tileViewportY1=MathFloor((originY-buffer)/tileSize);tileViewportX2=MathFloor((originX+width+buffer)/tileSize);tileViewportY2=MathFloor((originY+height+buffer)/tileSize);tileViewportWidth=tileViewportX2-tileViewportX1+1;tileViewportHeight=tileViewportY2-tileViewportY1+1;for(var y=tileViewportY1;y<=tileViewportY2;y++){
            for(var x=tileViewportX1;x<=tileViewportX2;x++){
                var tile=Rh(x,y,currentView.zoomLevel,currentView.mapStyle,0);currentTilesList.push(tile);
            }
            
        }
        
    }
    function Ij(){
        if(zooming)return;var ox=originX+offsetX;var oy=originY+offsetY;var x1=MathFloor((ox-buffer)/tileSize);var y1=MathFloor((oy-buffer)/tileSize);var x2=MathFloor((ox+width+buffer)/tileSize);var y2=MathFloor((oy+height+buffer)/tileSize);var X1=tileViewportX1;var X2=tileViewportX2;var Y1=tileViewportY1;var Y2=tileViewportY2;var W1=tileViewportWidth;var H1=tileViewportHeight;while(tileViewportX1<x1){
            for(var y=tileViewportHeight-1;y>=0;y--){
                var tile=currentTilesList.splice(y*tileViewportWidth,1)[0];try{
                    tile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                if(trafficAvailable&&trafficAvailable==true){
                    var ttile=currentTrafficTilesList.splice(y*tileViewportWidth,1)[0];try{
                        ttile.RemoveFromMap();
                    }
                    catch(ex){
                        
                    }
                    
                }
                
            }
            tileViewportX1++;tileViewportWidth--;
        }
        while(tileViewportX1>x1){
            tileViewportX1--;tileViewportWidth++;for(var y=0;y<tileViewportHeight;y++){
                var tile=Rh(tileViewportX1,tileViewportY1+y,currentView.zoomLevel,currentView.mapStyle,0);currentTilesList.splice(y*tileViewportWidth,0,tile);if(trafficAvailable&&trafficAvailable==true){
                    var ttile=Rh(tileViewportX1,tileViewportY1+y,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.splice(y*tileViewportWidth,0,ttile);
                }
                
            }
            
        }
        while(tileViewportY1<y1){
            for(var x=0;x<tileViewportWidth;x++){
                var tile=currentTilesList.shift();try{
                    tile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                if(trafficAvailable&&trafficAvailable==true){
                    var ttile=currentTrafficTilesList.shift();try{
                        ttile.RemoveFromMap();
                    }
                    catch(ex){
                        
                    }
                    
                }
                
            }
            tileViewportY1++;tileViewportHeight--;
        }
        while(tileViewportY1>y1){
            tileViewportY1--;tileViewportHeight++;for(var x=tileViewportWidth-1;x>=0;x--){
                var tile=Rh(tileViewportX1+x,tileViewportY1,currentView.zoomLevel,currentView.mapStyle,0);currentTilesList.unshift(tile);if(trafficAvailable&&trafficAvailable==true){
                    var ttile=Rh(tileViewportX1+x,tileViewportY1,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.unshift(ttile);
                }
                
            }
            
        }
        while(tileViewportX2>x2){
            for(var y=tileViewportHeight-1;y>=0;y--){
                var tile=currentTilesList.splice(y*tileViewportWidth+tileViewportWidth-1,1)[0];try{
                    tile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                if(trafficAvailable&&trafficAvailable==true){
                    var ttile=currentTrafficTilesList.splice(y*tileViewportWidth+tileViewportWidth-1,1)[0];try{
                        ttile.RemoveFromMap();
                    }
                    catch(ex){
                        
                    }
                    
                }
                
            }
            tileViewportX2--;tileViewportWidth--;
        }
        while(tileViewportX2<x2){
            tileViewportX2++;tileViewportWidth++;for(var y=0;y<tileViewportHeight;y++){
                var tile=Rh(tileViewportX2,tileViewportY1+y,currentView.zoomLevel,currentView.mapStyle,0);currentTilesList.splice(y*tileViewportWidth+tileViewportWidth-1,0,tile);if(trafficAvailable&&trafficAvailable==true){
                    var ttile=Rh(tileViewportX2,tileViewportY1+y,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.splice(y*tileViewportWidth+tileViewportWidth-1,0,ttile);
                }
                
            }
            
        }
        while(tileViewportY2>y2){
            for(var x=0;x<tileViewportWidth;x++){
                var tile=currentTilesList.pop();try{
                    tile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                if(trafficAvailable&&trafficAvailable==true){
                    var ttile=currentTrafficTilesList.pop();try{
                        ttile.RemoveFromMap();
                    }
                    catch(ex){
                        
                    }
                    
                }
                
            }
            tileViewportY2--;tileViewportHeight--;
        }
        while(tileViewportY2<y2){
            tileViewportY2++;tileViewportHeight++;for(var x=0;x<tileViewportWidth;x++){
                var tile=Rh(tileViewportX1+x,tileViewportY2,currentView.zoomLevel,currentView.mapStyle,0);currentTilesList.push(tile);if(trafficAvailable&&trafficAvailable==true){
                    var ttile=Rh(tileViewportX1+x,tileViewportY2,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.push(ttile);
                }
                
            }
            
        }
        
    }
    function Jj(Kj){
		window.pyca.push(Kj);
        if(zooming||dragging)return true;
		if(panning)vg();
		var centerLatLong=Kj.latlong;
		if(Kj.GetViewType()=="latlongRect")centerLatLong=Kj.latlongRect.Center();
		if(Kj.mapStyle==obliqueStyle){
            if(obliqueMode==null)return true;preferredView.Copy(Kj);currentMode=obliqueMode;M.style.backgroundColor="black";Kj.Resolve(currentMode,width,height);var scene=obliqueMode.GetScene();if((!scene||scene.GetID()!=Kj.sceneId)&&Kj.sceneId!=null){
                obliqueMode.RequestScene(Kj.sceneId);return true;
            }
            if(!scene||!scene.ContainsLatLong(centerLatLong,Kj.zoomLevel)&&scene.GetID()!=Kj.sceneId||scene.GetOrientation()!=Kj.sceneOrientation){
                obliqueMode.RequestSceneAtLatLong(centerLatLong,Kj.sceneOrientation,true);return true;
            }
            
        } else {
            currentMode=orthoMode;if(Kj.mapStyle=="r")M.style.backgroundColor="#e9e7d4";else M.style.backgroundColor="black";Kj.Resolve(currentMode,width,height);
        }
		
        centerLatLong=Kj.latlong;
		preferredView.Copy(Kj);
		currentMode.ValidateZoomLevel(Kj);
		currentBounds=currentMode.GetBounds(Kj);
		Ob(Kj,currentBounds);
		Kj.Resolve(currentMode,width,height);
		if(Kj.Equals(currentView))return false;
		var deltaX=Kj.GetX(currentView.zoomLevel)-currentView.center.x;
		var deltaY=Kj.GetY(currentView.zoomLevel)-currentView.center.y;
		var distance=Math.sqrt(deltaX*deltaX+deltaY*deltaY);
		var animatedPan=distance<width&&distance<height&&Kj.zoomLevel==currentView.zoomLevel&&animatedMovementEnabled&&Kj.mapStyle==currentView.mapStyle&&(Kj.sceneId==null||Kj.sceneId==currentView.sceneId);
		if(animatedPan){
            wg(centerLatLong.latitude,centerLatLong.longitude);return true;
        }

        previousZoomLevel=currentView.zoomLevel;if(currentView.zoomLevel!=Kj.zoomLevel){
            Sc("onstartzoom");zooming=true;
        }
        var animatedZoom=distance<width&&distance<height&&(Kj.zoomLevel==currentView.zoomLevel-1||Kj.zoomLevel==currentView.zoomLevel+1)&&animatedMovementEnabled&&Kj.mapStyle==currentView.mapStyle&&(Kj.sceneId==null||Kj.sceneId==currentView.sceneId);
		
		if(animatedZoom){
            var oldOriginX=originX+offsetX;var oldOriginY=originY+offsetY;var oldZoom=currentView.zoomLevel;var newZoom=Kj.zoomLevel;var newOriginX=MathRound(Kj.center.x-width/2);var newOriginY=MathRound(Kj.center.y-height/2);oldTilesList=currentTilesList;currentTilesList=new Array();for(var i=0;i<oldTilesList.length;i++){
                oldTilesList[i].PrepareBaseTile(oldOriginX,oldOriginY,oldZoom,newOriginX,newOriginY,newZoom);
            }
            for(var i=0;i<pushpins.length;i++){
                pushpins[i].PrepareForZoom(newOriginX,newOriginY,newZoom);
            }
            oe();currentView.Destroy();currentView=Kj;Hj();nm();for(var i=0;i<currentTilesList.length;i++){
                currentTilesList[i].PrepareSwapTile(oldOriginX,oldOriginY,oldZoom,newOriginX,newOriginY,newZoom);
            }
            if(trafficAvailable&&trafficAvailable==true)for(var i=0;i<currentTrafficTilesList.length;i++){
                currentTrafficTilesList[i].PrepareSwapTile(oldOriginX,oldOriginY,oldZoom,newOriginX,newOriginY,newZoom);
            }
            zoomCounter=1;Lj();return true;
        }
		
        oldTilesList=currentTilesList;currentTilesList=new Array();
		currentView.Destroy();currentView=Kj;
		oe();Hj();nm();
		Mj();
		Ug();
		return true;
    }
    function Lj(){
        if(!zooming)return;for(var i=0;i<oldTilesList.length;i++){
            oldTilesList[i].SetFactor(zoomCounter);
        }
        for(var i=0;i<currentTilesList.length;i++){
            currentTilesList[i].SetFactor(zoomCounter);
        }
        for(var i=0;i<pushpins.length;i++){
            pushpins[i].SetFactor(zoomCounter);
        }
        if(zoomCounter<zoomTotalSteps){
            zoomCounter++;window.setTimeout(Lj,1);
        }
        else{
            zoomCounter=0;Mj();
        }
        
    }
    function Mj(){
        if(oldTilesList!=null){
            Th(oldTilesList);oldTilesList=null;
        }
        lm();zooming=false;
		for(var i=0;i<currentTilesList.length;i++){
            currentTilesList[i].SwapStates();currentTilesList[i].ClearSteps();currentTilesList[i].SetFactor(0);if(trafficAvailable&&trafficAvailable==true){
                if(currentTrafficTilesList[i]!=null){
                    currentTrafficTilesList[i].SwapStates();currentTrafficTilesList[i].ClearSteps();currentTrafficTilesList[i].SetFactor(0);
                }
                
            }
            
        }
        for(var i=0;i<pushpins.length;i++){
            pushpins[i].SwapStates();pushpins[i].ClearSteps();pushpins[i].SetFactor(0);
        }
        currentTilesIndexes=null;oldTilesIndexes=null;window.setTimeout(ne,250);
		if(copyright)copyright.Update();
		if(previousMapStyle!=currentView.mapStyle)Sc("onchangemapstyle");
		if(previousZoomLevel!=currentView.zoomLevel) Sc("onendzoom");
		Sc("onchangeview");
		if(obliqueMode)window.setTimeout(obliqueMode.UpdateAvailability,100);
		try{
            CollectGarbage();
        }
        catch(ex){
            
        }
    }
    function Nj(Oj,Pj,Qj,Rj){
        var view=preferredView.MakeCopy();
		view.sceneId=null;
		view.SetLatLongRectangle(new Msn.VE.LatLongRectangle(new Msn.VE.LatLong(Wj(Oj),Yj(Pj)),new Msn.VE.LatLong(Wj(Qj),Yj(Rj))));
		return Jj(view);
    }
    function Sj(l){
        if(!l||l.constructor!=Array)return;
		var a=l[0].latitude;var b=l[0].longitude;
		var c=a;var d=b;
		for(var i=1;i<l.length;i++){
            a=MathMin(a,l[i].latitude);b=MathMin(b,l[i].longitude);c=MathMax(c,l[i].latitude);d=MathMax(d,l[i].longitude);
        }
        var dLat=(c-a)*0.1;var dLon=(d-b)*0.1;a-=dLat;b-=dLon;c+=dLat;d+=dLon;
		Nj(Wj(a),Yj(b),Wj(c),Yj(d));
    }
    function Tj(Uj,Vj){
        var latlong=new Msn.VE.LatLong(Uj,Vj);if(currentView.mapStyle==obliqueStyle){
            var scene=obliqueMode.GetScene();if(!scene||!scene.ContainsLatLong(latlong))W(lastOrthoMapStyle);
        }
        Sj(new Array(currentView.latlong,latlong));
    }
    function Wj(Xj){
        return ak(Xj,minLatitude,maxLatitude);
    }
    function Yj(Zj){
        return ak(Zj,minLongitude,maxLongitude);
    }
    function ak(n,bk,ck){
        if(n<bk)return bk;if(n>ck)return ck;return n;
    }
    function ek(){
        var x=null;try{
            x=new ActiveXObject("Msxml2.XMLHTTP");
        }
        catch(ex){
            try{
                x=new ActiveXObject("Microsoft.XMLHTTP");
            }
            catch(ex){
                x=null;
            }
            
        }
        if(!x&&typeof XMLHttpRequest!="undefined")x=new XMLHttpRequest();return x;
    }
    function gk(hk){
        var view=preferredView.MakeCopy();view.SetZoomLevel(hk);Jj(view);
    }
    function jk(){
        var view=preferredView.MakeCopy();view.SetZoomLevel(currentView.zoomLevel+1);Jj(view);
    }
    function kk(){
        var view=preferredView.MakeCopy();view.SetZoomLevel(currentView.zoomLevel-1);Jj(view);
    }
    function lk(mk,nk,ok){
        var view=preferredView.MakeCopy();view.sceneId=null;view.SetCenterLatLong(new Msn.VE.LatLong(mk,nk));view.SetZoomLevel(ok);Jj(view);
    }
    function pk(){
        var scene=null;var available=false;var availableBefore=false;var xmlHttp=null;var obliqueUrl=null;var showOnLoad=false;var requestUrl=null;var timerId=-1;var bounds=['02121222233','02121222322','02121222323','02121222332','02121222333','02121223222','02121223223','02121223232','02123000101','02123000103','02123000110','02123000111','02123000112','02123000113','02123000130','02123000131','02123001000','02123001001','02123001002','02123001003','02123001010','02123001012','02123001020','02123001021','02123001030','02123002113','02123002131','02123002133','02123002311','02123002313','02123003002','02123003003','02123003012','02123003020','02123003021','02123003022','02123003023','02123003030','02123003032','02123003200','02123003201','02123003202','02123003210','02133301103','02133301112','02133301113','02133301120','02133301121','02133301122','02133301123','02133301130','02133301131','02133301132','02133301133','02133301300','02133301301','02133301303','02133301310','02133301311','02133301312','02133310020','02133310022','02133310200','02133310222','02133310223','02133310232','02133310233','02133310322','02133312000','02133312001','02133312002','02133312003','02133312010','02133312011','02133312012','02133312013','02133312021','02133312030','02133312031','02133312100','02133312102','02133333112','02133333121','02133333122','02133333123','02133333130','02133333131','02133333132','02133333133','02133333201','02133333203','02133333210','02133333211','02133333212','02133333213','02133333300','02133333301','02133333302','02133333303','02133333310','02301020311','02301020313','02301020331','02301020332','02301020333','02301021013','02301021021','02301021022','02301021023','02301021030','02301021031','02301021032','02301021033','02301021122','02301021200','02301021201','02301021202','02301021203','02301021210','02301021211','02301021212','02301021213','02301021222','02301021300','02301022110','02301022111','02301031102','02301031103','02301031120','02301031121','02301031131','02301031133','02301120020','02301120022','02301213211','02301213213','02301213300','02301213301','02301213302','02301213303','02301213310','02301213311','02301213312','02301213313','02301213320','02301213321','02301213322','02301213323','02301213330','02301213331','02301213332','02301213333','02301231013','02301231031','02301231100','02301231101','02301231102','02301231103','02301231110','02301231111','02301231112','02301231113','02301231120','02301231121','02301231130','02301231131','02301231132','02301231133','02301231310','02301231311','02301300230','02301300231','02301300232','02301300233','02301300302','02301300320','02301301131','02301301133','02301301332','02301301333','02301302123','02301302132','02301302133','02301302200','02301302201','02301302202','02301302203','02301302210','02301302211','02301302212','02301302213','02301302220','02301302221','02301302222','02301302223','02301302230','02301302231','02301302232','02301302233','02301302300','02301302301','02301302302','02301302303','02301302310','02301302311','02301302312','02301302313','02301302320','02301302321','02301302322','02301302323','02301302330','02301302331','02301302332','02301302333','02301303021','02301303022','02301303110','02301303111','02301303200','02301303201','02301310020','02301310021','02301310022','02301310023','02301310200','02301310201','02301312033','02301312211','02301312300','02301312302','02301312320','02301312321','02301312332','02301320000','02301320001','02301320002','02301320003','02301320010','02301320011','02301320012','02301320013','02301320020','02301320021','02301320022','02301320023','02301320030','02301320031','02301320032','02301320033','02301320100','02301320101','02301320102','02301320103','02301320110','02301320111','02301320112','02301320113','02301320120','02301320121','02301320130','02301320200','02301320201','02301320203','02301320210','02301320211','02301320212','02301320213','02301320230','02301320231','02301320300','02301321001','02301321002','02301321003','02301321010','02301321011','02301321012','02301321013','02301321100','02301321101','02301321102','02301321103','02301330011','02301330100','02301330101','02301330102','02301330103','02301330110','02310101223','02310101230','02310101232','02310101233','02310103001','02310103010','02310103023','02310103030','02310103031','02310103032','02310103033','02310103120','02310103122','02310103203','02310103210','02310103211','02310103212','02310103213','02310103300','02310103302','02310210322','02310210323','02310210332','02310210333','02310211203','02310211212','02310211213','02310211221','02310211222','02310211223','02310211230','02310211231','02310211232','02310211233','02310211302','02310211303','02310211320','02310211321','02310211322','02310212011','02310212100','02310212101','02310212110','02310212111','02310212112','02310212130','02310212132','02310213000','02310213001','02310213002','02310213003','02310213010','02310213011','02310213012','02310213100','02310213112','02310213113','02310213130','02310213131','02310213132','02310213133','02310213311','02310223202','02310223203','02310223220','02310223221','02310302002','02310302003','02310302012','02310302013','02310302020','02310302021','02310302022','02310302023','02310302030','02310302031','02310302032','02310302033','02310302120','02310302121','02310302122','02310302123','02310302200','02310302201','02310302210','02310302211','02310302212','02310302213','02310302230','02310302231','02310302232','02310302233','02310302300','02310302301','02310302302','02310302320','02311030103','02311030112','02311030113','02311030121','02311030123','02311030130','02311030131','02311030132','02311030133','02311030310','02311030311','02311030313','02311031002','02311031003','02311031020','02311031021','02311031022','02311031023','02311031200','02311031201','02311031202','02311031203','02311102213','02311102231','02311102302','02311102303','02311102320','02311102321','02311102323','02311102332','02311102333','02311103222','02311120101','02311120103','02311120110','02311120111','02311120112','02311120113','02311120121','02311120130','02311120131','02311121000','02311121002','02311121020','02311231220','02311231221','02311231222','02311231223','02311231230','02311231231','02311231232','02311231233','02311231320','02311231322','02311232023','02311232032','02311232033','02311232100','02311232101','02311232102','02311232103','02311232110','02311232111','02311232112','02311232113','02311232120','02311232121','02311232122','02311232123','02311232130','02311232131','02311232132','02311232133','02311232201','02311232210','02311232211','02311232212','02311232213','02311232230','02311232231','02311232300','02311232301','02311232302','02311232310','02311232311','02311233000','02311233001','02311233002','02311233003','02311233010','02311233011','02311233012','02311233013','02311233020','02311233021','02311233022','02311233100','02311233102','02311233200','02311300101','02311300103','02311300110','02311300111','02311300112','02311300113','02311300121','02311300123','02311300130','02311300131','02311300132','02311300133','02311300310','02311300311','02311300312','02311300313','02311300331','02311301000','02311301001','02311301002','02311301003','02311301010','02311301012','02311301020','02311301021','02311301022','02311301023','02311301030','02311301200','02311301201','02311301202','02311301203','02311323131','02311323133','02311323311','02311332020','02311332021','02311332022','02311332023','02311332032','02311332200','02311332201','02311332210','02313032013','02313032030','02313032031','02313032032','02313032033','02313032120','02313032121','02313032122','02313032123','02313032130','02313032131','02313032132','02313032133','02313032210','02313032211','02313032300','02313032301','02313032310','02313032311','02313102232','02313102233','02313102332','02313102333','02313113033','02313113122','02313113210','02313113211','02313113212','02313113213','02313113230','02313113231','02313113233','02313113300','02313113302','02313113303','02313113311','02313113313','02313113320','02313113321','02313113322','02313113323','02313113330','02313113331','02313113332','02313113333','02313120010','02313120011','02313120012','02313120013','02313120030','02313120031','02313120032','02313120100','02313120101','02313120102','02313120103','02313120110','02313120120','02313131101','02313131103','02313131110','02313131111','02313131112','02313131113','02313131121','02313131130','02313131131','02313131132','02313131133','02313210211','02313210213','02313210231','02313210300','02313210301','02313210302','02313210303','02313210310','02313210311','02313210312','02313210313','02313210320','02313210321','02313210322','02313210323','02313210330','02313210331','02313210332','02313210333','03022220013','03022220031','03022220033','03022220102','03022220103','03022220112','03022220113','03022220120','03022220121','03022220122','03022220123','03022220130','03022220131','03022220132','03022220133','03022220211','03022220300','03022220301','03022220310','03022220311','03022313313','03022313330','03022313331','03022313332','03022313333','03022320313','03022322030','03022322031','03022322032','03022322033','03022322120','03022322121','03022322122','03022322123','03022322130','03022322132','03022322210','03022322211','03022323021','03022323022','03022323023','03022323123','03022323200','03022323201','03022323202','03022323203','03022323210','03022323211','03022323212','03022323213','03022323231','03022323233','03022323300','03022323301','03022323302','03022323303','03022323312','03022323320','03022323321','03022323322','03022330332','03022330333','03022331110','03022331111','03022331113','03022331123','03022331130','03022331131','03022331132','03022331133','03022331220','03022331221','03022331222','03022331223','03022331230','03022331232','03022331301','03022331310','03022331311','03022332003','03022332012','03022332013','03022332020','03022332021','03022332022','03022332023','03022332030','03022332031','03022332032','03022332033','03022332101','03022332103','03022332110','03022332111','03022332112','03022332113','03022332200','03022332201','03022332202','03022332203','03022332210','03022332211','03022332212','03022332213','03022332231','03022332232','03022332233','03022332320','03022332321','03022332322','03022332323','03022333000','03022333001','03022333002','03022333003','03022333010','03022333011','03022333012','03022333013','03023202202','03023202203','03023202212','03023202213','03023202220','03023202221','03023202222','03023202223','03023202230','03023202231','03023202232','03023202233','03023202302','03023202303','03023202320','03023202321','03023202322','03023202323','03023202330','03023202331','03023202332','03023202333','03023203213','03023203231','03023203233','03023203302','03023203320','03023203321','03023203322','03023203323','03023203330','03023203331','03023203332','03023203333','03023212222','03023212233','03023220000','03023220001','03023220002','03023220003','03023220010','03023220011','03023220012','03023220013','03023220020','03023220021','03023220022','03023220023','03023220030','03023220031','03023220032','03023220033','03023220100','03023220101','03023220102','03023220103','03023220110','03023220111','03023220112','03023220113','03023220120','03023220122','03023220130','03023220131','03023220132','03023220133','03023220200','03023220201','03023220210','03023220211','03023220212','03023220213','03023220230','03023220231','03023220232','03023220233','03023220300','03023220301','03023220302','03023220303','03023220310','03023220311','03023220312','03023220313','03023220320','03023220321','03023220322','03023220323','03023220330','03023220331','03023220332','03023220333','03023221000','03023221001','03023221002','03023221003','03023221010','03023221011','03023221012','03023221013','03023221020','03023221021','03023221022','03023221023','03023221030','03023221031','03023221032','03023221033','03023221100','03023221101','03023221102','03023221103','03023221110','03023221111','03023221112','03023221113','03023221120','03023221121','03023221122','03023221123','03023221130','03023221131','03023221132','03023221200','03023221201','03023221202','03023221203','03023221210','03023221211','03023221220','03023221221','03023221222','03023221223','03023221230','03023221232','03023221300','03023221303','03023221312','03023221313','03023221320','03023221321','03023221322','03023221323','03023221330','03023221331','03023221332','03023221333','03023222010','03023222011','03023222100','03023222101','03023222110','03023222111','03023223000','03023223001','03023223010','03023223100','03023223101','03023223110','03023223111','03023230000','03023230002','03023230020','03023231130','03023231131','03023231132','03023231133','03023231310','03023231311','03023231312','03023231313','03023231321','03023231323','03023231330','03023231331','03023231332','03023231333','03023233101','03023233110','03023233111','03023233212','03023233213','03023233221','03023233223','03023233230','03023233231','03023233232','03023233233','03023320020','03023320021','03023320022','03023320023','03023320030','03023320031','03023320032','03023320033','03023320120','03023320121','03023320122','03023320123','03023320130','03023320131','03023320132','03023320133','03023320200','03023320201','03023320202','03023320203','03023320210','03023320211','03023320212','03023320213','03023320220','03023320221','03023320222','03023320223','03023320230','03023320231','03023320232','03023320233','03023320300','03023320301','03023320302','03023320303','03023320310','03023320311','03023320312','03023320313','03023320320','03023320321','03023320322','03023320323','03023320330','03023320331','03023320332','03023320333','03023321003','03023321013','03023321020','03023321021','03023321022','03023321023','03023321030','03023321031','03023321032','03023321033','03023321102','03023321103','03023321120','03023321121','03023321122','03023321123','03023321130','03023321132','03023321200','03023321201','03023321202','03023321203','03023321210','03023321211','03023321212','03023321213','03023321220','03023321221','03023321222','03023321223','03023321230','03023321231','03023321232','03023321233','03023321300','03023321301','03023321302','03023321320','03023321321','03023321322','03023321323','03023321332','03023322000','03023322001','03023322010','03023322011','03023322100','03023322101','03023322110','03023322111','03023323000','03023323001','03023323002','03023323003','03023323010','03023323011','03023323012','03023323013','03023323020','03023323021','03023323023','03023323030','03023323031','03023323032','03023323033','03023323100','03023323101','03023323102','03023323103','03023323110','03023323112','03023323113','03023323120','03023323121','03023323122','03023323123','03023323130','03023323131','03023323132','03023323133','03023323201','03023323210','03023323211','03023323300','03023323301','03023323302','03023323303','03023323310','03023323311','03023323312','03023323313','03023330222','03023330223','03023332000','03023332001','03023332002','03023332003','03023332010','03023332012','03023332020','03023332021','03023332022','03023332023','03023332030','03023332032','03023332201','03023332202','03023332203','03023332212','03023332220','03023332221','03131013130','03131013131','03131013132','03131013133','03131102020','03131102022','03131133020','03131133021','03131133022','03131133023','03131133030','03131133032','03131133200','03131133201','03131133210','03131310323','03131310332','03131311113','03131311131','03131311303','03131311312','03131311321','03131311323','03131311330','03131311332','03131312000','03131312001','03131312002','03131312003','03131312010','03131312012','03131312020','03131312021','03131312030','03131312101','03131312103','03131312110','03131312112','03131312312','03131312313','03131312330','03131312331','03131312332','03131312333','03131313111','03131313113','03131313130','03131313131','03131313202','03131313203','03131313212','03131313220','03131313221','03131313222','03131313223','03131313230','03131313232','03131313321','03131313322','03131313323','03131313330','03131313331','03131313332','03131313333','03200000320','03200000321','03200000322','03200000323','03200000330','03200000331','03200000332','03200000333','03200002100','03200002101','03200002102','03200002103','03200002110','03200002111','03200002112','03200002113','03200002120','03200002121','03200002130','03200010303','03200010312','03200010313','03200010321','03200010322','03200010323','03200010330','03200010331','03200010332','03200010333','03200011233','03200011322','03200011323','03200012100','03200012101','03200012102','03200012103','03200012110','03200012111','03200012112','03200012113','03200012120','03200012121','03200012130','03200012131','03200013011','03200013013','03200013100','03200013101','03200013102','03200013103','03200013131','03200013301','03200013303','03200013310','03200013311','03200013312','03200013313','03200013330','03200013331','03200023130','03200023131','03200023132','03200023133','03200023311','03200031310','03200031311','03200031312','03200031313','03200031330','03200031331','03200031333','03200032020','03200032021','03200032022','03200032023','03200032200','03200032201','03200100311','03200100312','03200100313','03200100322','03200100323','03200100330','03200100331','03200100332','03200101202','03200101220','03200102020','03200102021','03200102022','03200102023','03200102030','03200102032','03200102100','03200102101','03200102102','03200102103','03200102110','03200102112','03200102200','03200102201','03200102202','03200102210','03200102220','03200110010','03200110011','03200110100','03200110101','03200120122','03200120123','03200120132','03200120200','03200120202','03200120220','03200120222','03200120300','03200120301','03200120302','03200120303','03200120310','03200120312','03200203001','03200203003','03200203010','03200203011','03200203012','03200203013','03200203021','03200203023','03200203030','03200203031','03200203032','03200203033','03200210033','03200210122','03200210211','03200210212','03200210213','03200210230','03200210231','03200210300','03200210301','03200210302','03200210303','03200210310','03200210320','03200210321','03200213032','03200213033','03200213103','03200213112','03200213113','03200213121','03200213122','03200213123','03200213130','03200213131','03200213132','03200213133','03200213210','03200213211','03200213300','03200230101','03200230102','03200230103','03200230110','03200230111','03200230112','03200230113','03200230120','03200230121','03200230130','03200230131','03200230132','03200231002','03200231020','03200231103','03200231112','03200231113','03200231121','03200231123','03200231130','03200231131','03200231132','03200231133','03200231301','03200231303','03200231310','03200231311','03200231312','03200231313','03200232120','03200232121','03200232122','03200232123','03200232130','03200232131','03200232132','03200232133','03200232300','03200232301','03200232310','03200232311','03200232312','03200302002','03200302020','03200302022','03200302222','03200302223','03200302232','03200320000','03200320001','03200320002','03200320003','03200320010','03200320012','03200320013','03200320020','03200320021','03200320022','03200320023','03200320030','03200320031','03200320032','03200320200','03200320201','03200320210','03200332203','03200332212','03200332220','03200332221','03200332222','03200332223','03200332230','03200332231','03200332232','03200332233','03200332322','03201000333','03201001212','03201001213','03201001220','03201001221','03201001222','03201001223','03201001230','03201001231','03201001232','03201001233','03201001320','03201001322','03201001323','03201002111','03201002113','03201002311','03201002312','03201002313','03201002331','03201002332','03201002333','03201003000','03201003001','03201003002','03201003003','03201003010','03201003011','03201003012','03201003013','03201003033','03201003100','03201003101','03201003102','03201003103','03201003110','03201003112','03201003122','03201003200','03201003201','03201003202','03201003203','03201003211','03201003212','03201003220','03201003221','03201003222','03201003223','03201003230','03201003231','03201003232','03201003233','03201003300','03201003302','03201010032','03201010201','03201010203','03201010210','03201010211','03201010212','03201010213','03201010221','03201010230','03201010231','03201010232','03201010233','03201010300','03201010301','03201010302','03201010303','03201010310','03201010311','03201010312','03201010313','03201010320','03201010321','03201010322','03201010323','03201010330','03201010331','03201011001','03201011002','03201011003','03201011010','03201011011','03201011012','03201011013','03201011020','03201011021','03201011023','03201011030','03201011031','03201011032','03201011033','03201011100','03201011101','03201011102','03201011103','03201011110','03201011112','03201011120','03201011121','03201011122','03201011123','03201011130','03201011202','03201012011','03201012100','03201012101','03201012112','03201012113','03201012121','03201012123','03201012130','03201012131','03201012132','03201012133','03201012301','03201012303','03201012310','03201012311','03201012312','03201012313','03201012321','03201012323','03201012330','03201012332','03201013020','03201013022','03201013023','03201013200','03201020111','03201020132','03201020133','03201021000','03201021001','03201021002','03201021003','03201021010','03201021011','03201021012','03201021013','03201021031','03201022110','03201022111','03201022112','03201022113','03201022130','03201022131','03201023303','03201023312','03201023313','03201023320','03201023321','03201023322','03201023323','03201023330','03201023331','03201023332','03201023333','03201032220','03201032222','03201201100','03201201101','03201201110','03201201111','03201210000','03202002022','03202002023','03202002032','03202002200','03202002201','03202002202','03202002210','03202010333','03202011222','03202011223','03202011232','03202012111','03202012113','03202012130','03202012131','03202013000','03202013001','03202013002','03202013003','03202013010','03202013012','03202013020','03202013021','03202101311','03202101313','03202101323','03202101332','03202101333','03202102331','03202102333','03202103101','03202103103','03202103110','03202103111','03202103112','03202103113','03202103121','03202103123','03202103130','03202103131','03202103132','03202103133','03202103202','03202103203','03202103220','03202103221','03202103222','03202103223','03202103311','03202110001','03202110003','03202110010','03202110011','03202110012','03202110013','03202110100','03202110200','03202110201','03202110202','03202110203','03202110220','03202112000','03202112002','03202112020','03202112021','03202112022','03202112023','03202112200','03202121023','03202121032','03202121033','03202121201','03202121203','03202121210','03202121211','03202121212','03202121213','03202121300','03202121302','03202121311','03202121313','03202121323','03202121331','03202121332','03202121333','03202123100','03202123101','03202123103','03202123110','03202123111','03202123112','03202123113','03202123121','03202123123','03202123130','03202123131','03202123132','03202123133','03202123301','03202123310','03202123311','03202130200','03202130201','03202130202','03202130203','03202130210','03202130212','03202130220','03202130221','03202130222','03202130223','03202130230','03202130231','03202130232','03202130233','03202132000','03202132002','03202132003','03202132020','03202132021','03202132022','03202132023','03202132032','03202132200','03202132201','03202132210','03202301011','03202301013','03202301031','03202301100','03202301102','03202301103','03202301112','03202301113','03202301120','03202301121','03202301122','03202301123','03202301130','03202301131','03202301132','03202301133','03202301300','03202301301','03202301310','03202301311','03202310020','03202310022','03202310200','12020200002','12020200003','12020200020','12020200021','12020200022','12020200023','12020202000','12020202001','12020202002','12020202003','12020202020','12020202021','12020202311'];this.Init=function(qk){
            obliqueUrl=qk;
        }
        ;this.Destroy=function(){
            
        }
        ;function rk(sk,tk,uk){
            return scene.IsValidTile(sk,tk,uk);
        }
        function vk(wk,xk,yk){
            return scene.GetTileFilename(wk,xk,yk);
        }
        function zk(Ak){
            if(!scene)return 0;var pixel=new Msn.VE.Pixel(MathRound(originX+offsetX+width/2),MathRound(originY+offsetY+height/2));var latlong1=scene.PixelToLatLong(pixel,Ak);pixel.x++;var latlong2=scene.PixelToLatLong(pixel,Ak);var sinLat1=Math.sin(DegToRad(latlong1.latitude));var sinLat2=Math.sin(DegToRad(latlong2.latitude));var metersHeight=earthRadius/2*MathAbs(Math.log((1+sinLat1)/(1-sinLat1))-Math.log((1+sinLat2)/(1-sinLat2)));var metersWidth=earthRadius*MathAbs(DegToRad(latlong1.longitude)-DegToRad(latlong2.longitude));return Math.sqrt(metersWidth*metersWidth+metersHeight*metersHeight);
        }
        function Bk(Ck,Dk){
            return scene?scene.PixelToLatLong(Ck,Dk):null;
        }
        function Ek(Fk,Gk){
            return scene?scene.LatLongToPixel(Fk,Gk):null;
        }
        function Hk(Ik){
            if(Ik.zoomLevel<1)Ik.SetZoomLevel(1);else{
                if(Ik.zoomLevel>2)Ik.SetZoomLevel(2);
            }
            
        }
        function Jk(){
            return scene;
        }
        function Kk(){
            return scene.GetBounds();
        }
        function Lk(){
            return available;
        }
        function Mk(){
            if(!available)return null;var info=new Object();return info;
        }
        function Nk(){
            if(currentView.mapStyle==obliqueStyle)return;if(currentView.zoomLevel<=0)return;if(currentView.zoomLevel<MapControl.Features.BirdsEyeAtZoomLevel){
                scene=null;availableBefore=available;available=false;al();return;
            }
            Ok(currentView.latlong,"North",false,500);
        }
        function Ok(Pk,Qk,Rk,Sk){
            Vk();showOnLoad=Rk;if(!bl(Pk)){
                scene=null;availableBefore=available;available=false;al();return;
            }
            requestUrl=obliqueUrl+"?ver=3&lat="+Pk.latitude+"&lon="+Pk.longitude;if(Qk)requestUrl+="&o="+Qk;if(Sk)timerId=window.setTimeout(Wk,Sk);else{
                Wk();timerId=-1;
            }
            
        }
        function Tk(Uk){
            if(scene&&scene.GetID()==Uk)return;Vk();showOnLoad=true;requestUrl=obliqueUrl+"?ver=3&id="+Uk;Wk();
        }
        function Vk(){
            try{
                if(timerId!=-1)window.clearTimeout(timerId);
            }
            catch(ex){
                
            }
            timerId=-1;try{
                if(xmlHttp){
                    xmlHttp.onreadystatechange=null;xmlHttp.abort();
                }
                
            }
            catch(ex){
                
            }
            
        }
        function Wk(){
            Vk();if(!requestUrl)return;if(Msn.VE.API!=null){
                var network=new VENetwork();network.ServiceUrl=requestUrl;network.BeginInvoke("EndInvokeImagery",null,Xk);
            }
            else{
                if(!xmlHttp)xmlHttp=ek();if(xmlHttp){
                    xmlHttp.open("POST",requestUrl,true);xmlHttp.onreadystatechange=Zk;xmlHttp.send("");
                }
                
            }
            
        }
        function Xk(Yk){
            if(Yk!=null){
                scene=Yk;available=true;
            }
            else{
                scene=null;available=false;
            }
            al();
        }
        function Zk(){
            if(!xmlHttp||xmlHttp.readyState!=4)return;timerId=-1;availableBefore=available;var code=xmlHttp.responseText;if(code)try{
                scene=eval(code+"EndInvokeImagery();");if(scene!=null)available=true;else available=false;
            }
            catch(ex){
                scene=null;available=false;
            }
            else{
                scene=null;available=false;
            }
            al();
        }
        function al(){
            if(showOnLoad){
                showOnLoad=false;if(available){
                    var view=preferredView.MakeCopy();view.SetMapStyle(obliqueStyle,scene.GetID(),scene.GetOrientation());Jj(view);Sc("onobliquechange");
                }
                else{
                    var view=preferredView.MakeCopy();view.SetMapStyle(lastOrthoMapStyle);if(view.GetViewType()!="latlongRect")view.SetZoomLevel(lastOrthoZoomLevel);Jj(view);Sc("onerror",Ic(currentView.latlong,currentView.zoomLevel,L_ObliqueModeImageNotAvailable_Text));
                }
                
            }
            if(availableBefore!=available){
                if(available)Sc("onobliqueenter");else Sc("onobliqueleave");
            }
            
        }
        function bl(cl){
            if(!cl||!bounds||bounds.length==0)return false;var quadKey=el(cl,bounds[0].length);return jl(quadKey,0,bounds.length-1);
        }
        function el(gl,hl){
            var pixel=orthoMode.LatLongToPixel(gl,hl);var tileX=MathFloor(pixel.x/tileSize);var tileY=MathFloor(pixel.y/tileSize);var quadKey="";for(var i=hl;i>0;i--){
                var cell=0;var mask=1<<i-1;if((tileX&mask)!=0)cell++;if((tileY&mask)!=0)cell+=2;quadKey+=cell+"";
            }
            return quadKey;
        }
        function jl(kl,ll,ml){
            if(ml<ll)return false;var middle=MathFloor((ll+ml)/2);if(bounds[middle]==kl)return true;if(kl<bounds[middle])return jl(kl,ll,middle-1);return jl(kl,middle+1,ml);
        }
        this.IsValidTile=rk;this.GetFilename=vk;this.MetersPerPixel=zk;this.PixelToLatLong=Bk;this.LatLongToPixel=Ek;this.GetBounds=Kk;this.ValidateZoomLevel=Hk;this.IsAvailable=Lk;this.UpdateAvailability=Nk;this.CancelRequest=Vk;this.GetEventInfo=Mk;this.GetScene=Jk;this.RequestSceneAtLatLong=Ok;this.RequestScene=Tk;
    }
    function nl(){
        var bounds=[new Msn.VE.Bounds(1, 17, 0, 0, 2, 2),new Msn.VE.Bounds(18, 19, 35680, 82915, 83740, 113061),new Msn.VE.Bounds(18, 19, 123062, 74647, 132528, 89130),new Msn.VE.Bounds(18, 19, 12379, 112260, 20388, 119266),new Msn.VE.Bounds(18, 19, 80099, 115425, 85051, 119645)];this.Init=function(){
            
        }
        ;this.Destroy=function(){
            
        }
        ;function ol(pl,ql,rl){
            var max=1<<rl;return pl>=0&&ql>=0&&pl<max&&ql<max;
        }
        function sl(tl,ul,vl,wl){
            var key="";var cell=0;for(var i=vl;i>0;i--){
                cell=0;var mask=1<<i-1;if((tl&mask)!=0)cell++;if((ul&mask)!=0)cell+=2;key+=cell+"";
            }
            if(wl==0)return "http://"+currentView.mapStyle+cell+".ortho.tiles.virtualearth.net/tiles/"+currentView.mapStyle+key+(currentView.mapStyle==roadStyle?".png":".jpeg")+"?g="+generations[currentView.mapStyle];else{
                if(wl==1){
                    var i=cell%2;return "http://t%1.traffic.virtualearth.net/Flow/t".replace(/%1/g,i)+key+".png";
                }
                
            }
            
        }
        function xl(yl){
            return earthCircumference/((1<<yl)*tileSize);
        }
        function zl(Al,Bl){
            var metersPerPixel=xl(Bl);
			var metersX=Al.x*metersPerPixel-projectionOffset;
			var metersY=projectionOffset-Al.y*metersPerPixel;
			var latlong=new Msn.VE.LatLong();
			latlong.latitude=RadToDeg(Math.PI/2-2*Math.atan(Math.exp(-metersY/earthRadius)));
			latlong.longitude=RadToDeg(metersX/earthRadius);
			return latlong;
        }
        function Cl(Dl,El){
            var sinLat=Math.sin(DegToRad(Dl.latitude));var metersX=earthRadius*DegToRad(Dl.longitude);var metersY=earthRadius/2*Math.log((1+sinLat)/(1-sinLat));var metersPerPixel=xl(El);var pixel=new Msn.VE.Pixel();pixel.x=(projectionOffset+metersX)/metersPerPixel;pixel.y=(projectionOffset-metersY)/metersPerPixel;return pixel;
        }
        function Fl(Gl){
            if(Gl==undefined)Gl=currentView;var zoomLevel=Gl.zoomLevel;var x=Gl.center.x;var y=Gl.center.y;for(var i=0;i<bounds.length;i++){
                var deltaZ=zoomLevel-bounds[i].z1;var factor=tileSize*Math.pow(2,deltaZ);var minX=bounds[i].x1*factor;var maxX=bounds[i].x2*factor;var minY=bounds[i].y1*factor;var maxY=bounds[i].y2*factor;if(x>=minX&&x<=maxX&&y>=minY&&y<=maxY){
                    if(zoomLevel>=bounds[i].z1&&zoomLevel<=bounds[i].z2)return bounds[i];
                }
                
            }
            
        }
        function Hl(Il){
            var x=Il.center.x;var y=Il.center.y;var maxZoom=0;for(var i=0;i<bounds.length;i++){
                var factor=tileSize*Math.pow(2,Il.zoomLevel-bounds[i].z1);var minX=bounds[i].x1*factor;var maxX=bounds[i].x2*factor;var minY=bounds[i].y1*factor;var maxY=bounds[i].y2*factor;if(x>=minX&&x<=maxX&&y>=minY&&y<=maxY){
                    if(bounds[i].z2>=Il.zoomLevel)return;else{
                        if(bounds[i].z2>maxZoom)maxZoom=bounds[i].z2;
                    }
                    
                }
                
            }
            Il.SetZoomLevel(maxZoom);
        }
        this.IsValidTile=ol;this.GetFilename=sl;this.MetersPerPixel=xl;this.PixelToLatLong=zl;this.LatLongToPixel=Cl;this.GetBounds=Fl;this.ValidateZoomLevel=Hl;
    }
    function Jl(){
        var bg=document.createElement("div");var fg=document.createElement("div");var x1=0;var y1=0;var x2=0;var y2=0;this.Init=function(){
            bg.className="ZoomBox_bg";fg.className="ZoomBox_fg";bg.attachEvent("onmouseup",hg);fg.attachEvent("onmouseup",hg);if(map!=null){
                map.appendChild(bg);map.appendChild(fg);
            }
            
        }
        ;this.Destroy=function(){
            bg.detachEvent("onmouseup",hg);fg.detachEvent("onmouseup",hg);if(map!=null){
                map.removeChild(bg);map.removeChild(fg);
            }
            
        }
        ;function Kl(e){
            if(VE_ContextMenu!=null){
                VE_ContextMenu.RemoveContextPin();VE_ContextMenu.CloseMenu();
            }
            x1=x2=GetMouseX(e)-x+offsetX;y1=y2=GetMouseY(e)-y+offsetY;Nl(x1,y1,1,1);Ql();if(fg.setCapture)fg.setCapture();
        }
        function Ll(e){
            x2=GetMouseX(e)-x+offsetX;y2=GetMouseY(e)-y+offsetY;Nl(MathMin(x1,x2),MathMin(y1,y2),MathMax(1,MathAbs(x2-x1)),MathMax(1,MathAbs(y2-y1)));
        }
        function Ml(e){
            if(MathAbs(x1-x2)>1&&MathAbs(y1-y2)>1){
                var view=preferredView.MakeCopy();view.SetZoomLevel(currentView.zoomLevel);view.SetPixelRectangle(new Msn.VE.PixelRectangle(new Msn.VE.Pixel(originX+x1,originY+y1),new Msn.VE.Pixel(originX+x2,originY+y2)));Jj(view);
            }
            Rl();if(fg.releaseCapture)fg.releaseCapture();
        }
        function Nl(x,y,w,h){
            Ol(bg,x+1,y+1,w,h);Ol(fg,x,y,w,h);
        }
        function Ol(Pl,x,y,w,h){
            Pl.style.left=x+"px";Pl.style.top=y+"px";Pl.style.width=w+"px";Pl.style.height=h+"px";
        }
        function Ql(){
            bg.style.display="block";fg.style.display="block";
        }
        function Rl(){
            bg.style.display="none";fg.style.display="none";
        }
        this.OnMouseDown=Kl;this.OnMouseMove=Ll;this.OnMouseUp=Ml;
    }
    function Sl(){
        var moved=false;this.Init=function(){
            
        }
        ;this.Destroy=function(){
            
        }
        ;function Tl(e){
            moved=false;lastMouseX=GetMouseX(e);lastMouseY=GetMouseY(e);if(M.setCapture)M.setCapture();var clickX=originX+offsetX+GetMouseX(e)-x;var clickY=originY+offsetY+GetMouseY(e)-y;Sc("onstartcontinuouspan",Ic(currentMode.PixelToLatLong(new Msn.VE.Pixel(clickX,clickY),currentView.zoomLevel)));
        }
        function Ul(e){
            var mouseX=GetMouseX(e);var mouseY=GetMouseY(e);mg(lastMouseX-mouseX,lastMouseY-mouseY);lastMouseX=mouseX;lastMouseY=mouseY;moved=true;
        }
        function Vl(e){
            gb(true);if(M.releaseCapture)M.releaseCapture();if(moved){
                Sc("onendcontinuouspan");Sc("onchangeview");moved=false;
            }
            var clickX=originX+offsetX+GetMouseX(e)-x;var clickY=originY+offsetY+GetMouseY(e)-y;var clickEvent=Ic(currentMode.PixelToLatLong(new Msn.VE.Pixel(clickX,clickY),currentView.zoomLevel));Sc("onmouseup",clickEvent);Sc("onclick",clickEvent);
        }
        this.OnMouseDown=Tl;this.OnMouseMove=Ul;this.OnMouseUp=Vl;
    }
    function Wl(){
        return trafficAvailable;
    }
    function Xl(){
        return 1800000;
    }
    function Yl(){
        return 300000;
    }
    function Zl(){
        return "http://t1.traffic.virtualearth.net/incidents/markets.js";
    }
    function am(){
        return "http://t0.traffic.virtualearth.net/incidents/market";
    }
    var setTrafficViewflag=true;function bm(){
        if(setTrafficViewflag){
            setTrafficViewflag=false;trafficAvailable=true;oldTrafficList=currentTrafficTilesList;Th(currentTrafficTilesList);currentTrafficTilesList=new Array();window.setTimeout(cm,1);
        }
        else window.setTimeout(bm,1);
    }
    function cm(){
        if(setTrafficViewflag)return;for(var y=tileViewportY1;y<=tileViewportY2;y++){
            for(var x=tileViewportX1;x<=tileViewportX2;x++){
                var tile=Rh(x,y,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.push(tile);
            }
            
        }
        setTrafficViewflag=true;
    }
    function em(){
        trafficAvailable=false;if(currentTrafficTilesList!=null)Th(currentTrafficTilesList);gm();
    }
    function gm(){
        if(oldTrafficList!=null){
            Th(oldTrafficList);oldTrafficList=null;
        }
        
    }
    function hm(){
        for(var i=0;i<currentTrafficTilesList.length;i++){
            currentTrafficTilesList[i].SwapStates();currentTrafficTilesList[i].ClearSteps();currentTrafficTilesList[i].SetFactor(0);
        }
        
    }
    function jm(){
        var oldOriginX=originX+offsetX;var oldOriginY=originY+offsetY;var oldZoom=currentView.zoomLevel;var newZoom=layerRequestedView.zoomLevel;var newOriginX=MathRound(layerRequestedView.center.x-width/2);var newOriginY=MathRound(layerRequestedView.center.y-height/2);for(var i=0;i<currentTrafficTilesList.length;i++){
            currentTrafficTilesList[i].PrepareSwapTile(oldOriginX,oldOriginY,oldZoom,newOriginX,newOriginY,newZoom);
        }
        
    }
    function km(){
        if(zooming)return;var ox=originX+offsetX;var oy=originY+offsetY;var x1=MathFloor((ox-buffer)/tileSize);var y1=MathFloor((oy-buffer)/tileSize);var x2=MathFloor((ox+width+buffer)/tileSize);var y2=MathFloor((oy+height+buffer)/tileSize);var X1=tileViewportX1;var X2=tileViewportX2;var Y1=tileViewportY1;var Y2=tileViewportY2;var W1=tileViewportWidth;var H1=tileViewportHeight;while(tileViewportX1<x1){
            for(var y=tileViewportHeight-1;y>=0;y--){
                var ttile=currentTrafficTilesList.splice(y*tileViewportWidth,1)[0];try{
                    ttile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                
            }
            tileViewportX1++;tileViewportWidth--;
        }
        while(tileViewportX1>x1){
            tileViewportX1--;tileViewportWidth++;for(var y=0;y<tileViewportHeight;y++){
                var ttile=Rh(tileViewportX1,tileViewportY1+y,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.splice(y*tileViewportWidth,0,ttile);
            }
            
        }
        while(tileViewportY1<y1){
            for(var x=0;x<tileViewportWidth;x++){
                var ttile=currentTrafficTilesList.shift();try{
                    ttile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                
            }
            tileViewportY1++;tileViewportHeight--;
        }
        while(tileViewportY1>y1){
            tileViewportY1--;tileViewportHeight++;for(var x=tileViewportWidth-1;x>=0;x--){
                var ttile=Rh(tileViewportX1+x,tileViewportY1,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.unshift(ttile);
            }
            
        }
        while(tileViewportX2>x2){
            for(var y=tileViewportHeight-1;y>=0;y--){
                var ttile=currentTrafficTilesList.splice(y*tileViewportWidth+tileViewportWidth-1,1)[0];try{
                    ttile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                
            }
            tileViewportX2--;tileViewportWidth--;
        }
        while(tileViewportX2<x2){
            tileViewportX2++;tileViewportWidth++;for(var y=0;y<tileViewportHeight;y++){
                var ttile=Rh(tileViewportX2,tileViewportY1+y,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.splice(y*tileViewportWidth+tileViewportWidth-1,0,ttile);
            }
            
        }
        while(tileViewportY2>y2){
            for(var x=0;x<tileViewportWidth;x++){
                var ttile=currentTrafficTilesList.pop();try{
                    ttile.RemoveFromMap();
                }
                catch(ex){
                    
                }
                
            }
            tileViewportY2--;tileViewportHeight--;
        }
        while(tileViewportY2<y2){
            tileViewportY2++;tileViewportHeight++;for(var x=0;x<tileViewportWidth;x++){
                var ttile=Rh(tileViewportX1+x,tileViewportY2,currentView.zoomLevel,currentView.mapStyle,1);currentTrafficTilesList.push(ttile);
            }
            
        }
        
    }
    var currentTrafficTilesList=new Array();var oldTrafficList=null;var layerRequestedView=null;function lm(){
        if(trafficAvailable&&trafficAvailable==true)gm();
    }
    function mm(){
        if(trafficAvailable&&trafficAvailable==true)hm();
    }
    function nm(){
        if(trafficAvailable&&trafficAvailable==true)bm();
    }
    function om(){
        if(trafficAvailable&&trafficAvailable==true)jm();
    }
    function pm(){
        if(trafficAvailable&&trafficAvailable==true)km();
    }
    this.SetCenter=T;this.SetMapStyle=W;this.GetCenterLatitude=cb;this.GetCenterLongitude=eb;this.GetLatitude=jb;this.GetLongitude=kb;this.GetY=lb;this.GetX=nb;this.LatLongToPixel=pb;this.PixelToLatLong=rb;this.GetZoomLevel=tb;this.GetMapStyle=ub;this.GetMetersPerPixel=vb;this.Resize=yb;this.PanMap=mg;this.ContinuousPan=pg;this.StopContinuousPan=vg;this.StopKeyboardPan=Nb;this.PanToLatLong=wg;this.GetPushpins=Gg;this.AddPushpin=Hg;this.RemovePushpin=Rg;this.ClearPushpins=Tg;this.SetViewport=Nj;
	this.SetBestMapView=Sj;this.IncludePointInViewport=Tj;this.SetZoom=gk;this.ZoomIn=jk;this.ZoomOut=kk;this.SetCenterAndZoom=lk;this.AddLine=Yc;this.RemoveLine=ke;this.ClearLines=me;this.AttachEvent=Mc;this.DetachEvent=Pc;this.IsObliqueAvailable=zb;this.GetObliqueScene=Ab;this.SetAnimationEnabled=Bb;this.IsAnimationEnabled=Db;this.SetObliqueScene=Eb;this.SetObliqueOrientation=Gb;this.SetView=Jj;this.Debug=Ib;this.GetResponseRangeCounts=Vh;this.ResetResponseRangeCounts=Wh;this.GetFailureRate=Xh;this.SetTrafficView=bm;this.GetTrafficAvailability=Wl;this.RemoveTrafficLayer=em;this.GetMarketsFile=Zl;this.GetIncidentsFile=am;this.GetSlidingExpirationForAutoRefresh=Xl;this.GetAutoRefreshRate=Yl;this.SetCopyrightOffset=Jb;this.SetFocus=Mb;
}
;Msn.VE.Bounds=function(qm,rm,sm,tm,um,vm){
    this.z1=qm;this.z2=rm;this.x1=sm;this.y1=tm;this.x2=um;this.y2=vm;
}
;Msn.VE.Dashboard=function(wm,xm,ym){
    var header=document.createElement("div");header.className="header";wm.appendChild(header);var toggleGlyph=new Microsoft.Web.UI.IEGlyph(null,"toggleGlyph");var toggleGlyphElement=toggleGlyph.getElement();header.appendChild(toggleGlyphElement);wm.className+=" expanded";var roadTab=document.createElement("div");var aerialTab=document.createElement("div");var obliqueTab=document.createElement("div");var selectedTab=null;var separator=document.createElement("hr");var labelsContainer=document.createElement("div");var labelsCheckbox=document.createElement("input");var firstAerial=true;var compass=null;var obliqueCompass=null;var orthoZoom=null;var obliqueZoom=null;var obliqueNotification=null;var obliqueSelector=null;var containerTable=document.createElement("table");containerTable.className="dashboardContainerTable";var containerTBody=document.createElement("tbody");var compassZoomRow=document.createElement("tr");containerTable.appendChild(containerTBody);containerTBody.appendChild(compassZoomRow);var compassCell=document.createElement("td");var zoomCell=document.createElement("td");zoomCell.vAlign="top";var notificationCell=document.createElement("td");notificationCell.colSpan=2;notificationCell.setAttribute("colspan",2);notificationCell.className="obliqueSelectorTable";compassZoomRow.appendChild(compassCell);compassZoomRow.appendChild(zoomCell);var notificationRow=document.createElement("tr");notificationRow.appendChild(notificationCell);containerTBody.appendChild(notificationRow);this.Init=function(){
        var mapStyle=xm.GetMapStyle();if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Road))Am(roadTab,L_DashboardRoad_Text,Rm);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Aerial))Am(aerialTab,L_DashboardAerial_Text,Sm);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye))Am(obliqueTab,L_DashboardBirdsEye_Text,Tm);separator.className="Dashboard_separator";wm.appendChild(separator);wm.appendChild(containerTable);if(!ym||ym==Msn.VE.DashboardSize.Normal){
            compass=new an(compassCell,5,30);compass.Init();compass.Show();
        }
        obliqueCompass=new Go(compassCell);obliqueCompass.Hide();orthoZoom=new vn(zoomCell,100,30);orthoZoom.Init();obliqueZoom=new Ln(zoomCell);this.HideToggleGlyph();if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Hybrid))Km();if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye)){
            Lm();obliqueSelector=new kn(notificationCell);obliqueSelector.Init();
        }
        xm.AttachEvent("onendzoom",Vm);xm.AttachEvent("onchangemapstyle",Ym);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye)){
            xm.AttachEvent("onobliqueenter",Wm);xm.AttachEvent("onobliqueleave",Xm);xm.AttachEvent("onobliquechange",Zm);
        }
        if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye)){
            if(xm.IsObliqueAvailable())Pm();else Qm();
        }
        switch(mapStyle){
            case "r":Mm();break;case "a":case "h":Nm();break;case "o":Om();break;
        }
        
    }
    ;this.Destroy=function(){
        if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Road))Fm(roadTab,Rm);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Aerial))Fm(aerialTab,Sm);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye))Fm(obliqueTab,Tm);selectedTab=roadTab=aerialTab=obliqueTab=null;header.removeChild(toggleGlyphElement);wm.removeChild(header);header=toggleGlyphElement=toggleGlyph=null;if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Hybrid)){
            labelsContainer.removeChild(labelsCheckbox);zoomCell.removeChild(labelsContainer);labelsContainer.detachEvent("onclick",Um);labelsContainer=labelsCheckbox=null;
        }
        if(compass){
            compass.Destroy();compass=null;
        }
        if(obliqueCompass){
            obliqueCompass.Destroy();obliqueCompass=null;
        }
        if(orthoZoom){
            orthoZoom.Destroy();orthoZoom=null;
        }
        if(obliqueZoom){
            obliqueZoom.Destroy();obliqueZoom=null;
        }
        if(obliqueNotification){
            obliqueNotification.detachEvent("onclick",Tm);obliqueNotification=null;
        }
        if(obliqueSelector){
            obliqueSelector.Destroy();obliqueSelector=null;
        }
        if(xm){
            xm.DetachEvent("onendzoom",Vm);xm.DetachEvent("onchangemapstyle",Ym);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye)){
                xm.DetachEvent("onobliqueenter",Wm);xm.DetachEvent("onobliqueleave",Xm);xm.DetachEvent("onobliquechange",Zm);
            }
            xm=null;
        }
        
    }
    ;this.SetX=function(zm){
        wm.style.left=zm+"px";
    }
    ;this.GetElement=function(){
        return wm;
    }
    ;this.GetHeader=function(){
        return header;
    }
    ;this.GetY=function(){
        return GetTopPosition(wm);
    }
    ;this.GetHeight=function(){
        return wm.offsetHeight;
    }
    ;this.ShowToggleGlyph=function(){
        if(toggleGlyphElement!=null&&toggleGlyphElement!="undefined")toggleGlyphElement.style.display="block";
    }
    ;this.HideToggleGlyph=function(){
        if(toggleGlyphElement!=null&&toggleGlyphElement!="undefined")toggleGlyphElement.style.display="none";
    }
    ;function Am(Bm,Cm,Dm,Em){
        Bm.className="Dashboard_tab Dashboard_unselected";Bm.href="javascript:void(0)";Bm.innerText=Cm;Bm.attachEvent("onclick",Dm);var lastChild=header.lastChild;if(lastChild&&typeof lastChild!="undefined")header.insertBefore(Bm,lastChild);else header.appendChild(Bm);
    }
    function Fm(Gm,Hm){
        Gm.detachEvent("onclick",Hm);if(header!=null)try{
            header.removeChild(Gm);
        }
        catch(exp){
            
        }
        
    }
    function Im(Jm){
        if(selectedTab)selectedTab.className="Dashboard_tab Dashboard_unselected";Jm.className="Dashboard_tab Dashboard_selected";selectedTab=Jm;
    }
    function Km(){
        labelsCheckbox.type="checkbox";labelsContainer.className="Dashboard_toggler";labelsContainer.style.display="none";labelsContainer.attachEvent("onclick",Um);labelsContainer.appendChild(labelsCheckbox);labelsContainer.appendChild(document.createTextNode(L_DashboardShowLabels_Text));zoomCell.appendChild(labelsContainer);
    }
    function Lm(){
        obliqueNotification=document.createElement("div");obliqueNotification.className="Dashboard_notification";obliqueNotification.innerHTML="<div id=\"obliqueNotifyIcon\">&nbsp;</div> "+L_DashboardBirdsEyeText_Text;obliqueNotification.style.display="none";obliqueNotification.attachEvent("onclick",Tm);notificationCell.appendChild(obliqueNotification);
    }
    function Mm(){
        Im(roadTab);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Hybrid))labelsContainer.style.display="none";if(obliqueSelector)obliqueSelector.Hide();obliqueZoom.Hide();orthoZoom.Show();if(xm.IsObliqueAvailable()&&Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye))obliqueNotification.style.display="block";if(compass)compass.Show();obliqueCompass.Hide();
    }
    function Nm(){
        Im(aerialTab);if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Hybrid))labelsContainer.style.display="block";if(obliqueSelector)obliqueSelector.Hide();obliqueZoom.Hide();orthoZoom.Show();if(Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Hybrid)){
            if(xm.GetMapStyle()=="h")labelsCheckbox.checked=true;else labelsCheckbox.checked=false;
        }
        if(xm.IsObliqueAvailable()&&Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.BirdsEye))obliqueNotification.style.display="block";if(compass)compass.Show();obliqueCompass.Hide();
    }
    function Om(){
        Im(obliqueTab);labelsContainer.style.display="none";obliqueNotification.style.display="none";obliqueSelector.Show();orthoZoom.Hide();obliqueZoom.Show();if(compass)compass.Hide();obliqueCompass.Show();
    }
    function Pm(){
        obliqueTab.className="Dashboard_tab Dashboard_unselected";obliqueNotification.style.display="block";
    }
    function Qm(){
        obliqueTab.className="Dashboard_tab Dashboard_disabled";obliqueNotification.style.display="none";
    }
    function Rm(){
        xm.SetMapStyle("r");
    }
    function Sm(){
        if((firstAerial||labelsCheckbox.checked)&&Msn.VE.Marketization.IsEnabled(MapControl.Features.MapStyle.Hybrid))xm.SetMapStyle("h");else xm.SetMapStyle("a");firstAerial=false;
    }
    function Tm(){
        xm.SetMapStyle("o");
    }
    function Um(e){
        var mapStyle=xm.GetMapStyle();if(mapStyle=="a"){
            xm.SetMapStyle("h");labelsCheckbox.checked=true;
        }
        else{
            if(mapStyle=="h"){
                xm.SetMapStyle("a");labelsCheckbox.checked=false;
            }
            
        }
        
    }
    function Vm(e){
        orthoZoom.UpdateFromMap();obliqueZoom.UpdateFromMap();
    }
    function Wm(e){
        if(xm.GetMapStyle()=="o")return;Pm();obliqueCompass.UpdateFromMap();
    }
    function Xm(e){
        Qm();
    }
    function Ym(e){
        switch(e.view.mapStyle){
            case "r":Mm();break;case "a":case "h":Nm();break;case "o":Om();break;
        }
        
    }
    function Zm(e){
        obliqueSelector.Update();obliqueCompass.UpdateFromMap();
    }
    function an(bn){
        var wm=document.createElement("div");var x=0;var y=0;var panning=false;var maxScrollSpeed=15;this.Init=function(){
            wm.className="Compass";wm.attachEvent("onmousedown",cn);wm.attachEvent("onmouseup",gn);wm.attachEvent("onmousemove",en);wm.attachEvent("ondblclick",IgnoreEvent);bn.appendChild(wm);
        }
        ;this.Destroy=function(){
            wm.detachEvent("onmousedown",cn);wm.detachEvent("onmouseup",gn);wm.detachEvent("onmousemove",en);wm.detachEvent("ondblclick",IgnoreEvent);wm=null;
        }
        ;function cn(e){
            e=GetEvent(e);CancelEvent(e);x=GetLeftPosition(wm);y=GetTopPosition(wm);if(wm.setCapture)wm.setCapture();var dx=GetMouseX(e)-x-wm.offsetWidth/2;var dy=GetMouseY(e)-y-wm.offsetHeight/2;dx=Math.min(Math.max(dx,-maxScrollSpeed),maxScrollSpeed);dy=Math.min(Math.max(dy,-maxScrollSpeed),maxScrollSpeed);xm.ContinuousPan(dx,dy);panning=true;return false;
        }
        function en(e){
            e=GetEvent(e);CancelEvent(e);if(panning){
                var dx=GetMouseX(e)-x-wm.offsetWidth/2;var dy=GetMouseY(e)-y-wm.offsetHeight/2;dx=Math.min(Math.max(dx,-maxScrollSpeed),maxScrollSpeed);dy=Math.min(Math.max(dy,-maxScrollSpeed),maxScrollSpeed);xm.ContinuousPan(dx,dy);
            }
            return false;
        }
        function gn(e){
            e=GetEvent(e);CancelEvent(e);if(wm.releaseCapture)wm.releaseCapture();xm.StopContinuousPan();panning=false;return false;
        }
        function hn(){
            wm.style.display="none";
        }
        function jn(){
            wm.style.display="block";
        }
        this.Hide=hn;this.Show=jn;
    }
    function kn(ln){
        var wm=document.createElement("table");var cells=new Array(3);this.Init=function(){
            wm.className="obliqueSelectorTable";nn();ln.appendChild(wm);var tbody=document.createElement("tbody");tbody.className="obliqueSelectorTable";wm.appendChild(tbody);for(var i=0;i<3;i++){
                var row=document.createElement("tr");tbody.appendChild(row);cells[i]=new Array(3);for(var j=0;j<3;j++){
                    var link=document.createElement("div");var cell=document.createElement("td");row.appendChild(cell);cell.appendChild(link);link.className="Dashboard_thumbnail";if(i==1&&j==1){
                        cells[i][j]=new pn(link,false);cell.className="obliqueSelectorCellCenter";
                    }
                    else{
                        cells[i][j]=new pn(link,true);cell.className="obliqueSelectorCellOff";
                    }
                    cells[i][j].Init();
                }
                
            }
            
        }
        ;this.Destroy=function(){
            ln.removeChild(wm);wm=null;for(var i=0;i<cells.length;i++){
                for(var j=0;j<cells[i].length;j++){
                    cells[i][j].Destroy();cells[i][j]=null;
                }
                
            }
            cells=null;
        }
        ;function mn(){
            on();wm.style.display="block";
        }
        function nn(){
            wm.style.display="none";
        }
        function on(){
            var scene=xm.GetObliqueScene();if(!scene)return;cells[1][1].SetScene(scene);switch(scene.GetOrientation()){
                case "North":cells[0][0].SetScene(scene.GetNeighbor("Northwest"));cells[0][1].SetScene(scene.GetNeighbor("North"));cells[0][2].SetScene(scene.GetNeighbor("Northeast"));cells[1][0].SetScene(scene.GetNeighbor("West"));cells[1][2].SetScene(scene.GetNeighbor("East"));cells[2][0].SetScene(scene.GetNeighbor("Southwest"));cells[2][1].SetScene(scene.GetNeighbor("South"));cells[2][2].SetScene(scene.GetNeighbor("Southeast"));break;case "East":cells[0][0].SetScene(scene.GetNeighbor("Northeast"));cells[0][1].SetScene(scene.GetNeighbor("East"));cells[0][2].SetScene(scene.GetNeighbor("Southeast"));cells[1][0].SetScene(scene.GetNeighbor("North"));cells[1][2].SetScene(scene.GetNeighbor("South"));cells[2][0].SetScene(scene.GetNeighbor("Northwest"));cells[2][1].SetScene(scene.GetNeighbor("West"));cells[2][2].SetScene(scene.GetNeighbor("Southwest"));break;case "West":cells[0][0].SetScene(scene.GetNeighbor("Southwest"));cells[0][1].SetScene(scene.GetNeighbor("West"));cells[0][2].SetScene(scene.GetNeighbor("Northwest"));cells[1][0].SetScene(scene.GetNeighbor("South"));cells[1][2].SetScene(scene.GetNeighbor("North"));cells[2][0].SetScene(scene.GetNeighbor("Southeast"));cells[2][1].SetScene(scene.GetNeighbor("East"));cells[2][2].SetScene(scene.GetNeighbor("Northeast"));break;case "South":cells[0][0].SetScene(scene.GetNeighbor("Southeast"));cells[0][1].SetScene(scene.GetNeighbor("South"));cells[0][2].SetScene(scene.GetNeighbor("Southwest"));cells[1][0].SetScene(scene.GetNeighbor("East"));cells[1][2].SetScene(scene.GetNeighbor("West"));cells[2][0].SetScene(scene.GetNeighbor("Northeast"));cells[2][1].SetScene(scene.GetNeighbor("North"));cells[2][2].SetScene(scene.GetNeighbor("Northwest"));break;
            }
            
        }
        function pn(qn,rn){
            var scene=null;this.Init=function(){
                qn.title=L_ObliqueSelectorSelectThumbnail_Text;if(rn){
                    qn.attachEvent("onclick",sn);qn.attachEvent("onmouseover",tn);qn.attachEvent("onmouseout",un);
                }
                
            }
            ;this.Destroy=function(){
                if(rn){
                    qn.detachEvent("onclick",sn);qn.detachEvent("onmouseover",tn);qn.detachEvent("onmouseout",un);
                }
                
            }
            ;this.SetScene=function(s){
                scene=s;if(scene){
                    qn.innerHTML="<img src=\""+scene.GetThumbnailFilename()+"\" width=48 height=48 border=0>";if(rn)qn.style.cursor="pointer";
                }
                else{
                    qn.innerHTML="";qn.style.cursor="default";
                }
                if(rn)qn.parentNode.className="obliqueSelectorCellOff";
            }
            ;function sn(){
                if(!scene)return;xm.SetObliqueScene(scene.GetID());
            }
            function tn(e){
                qn.parentNode.className="obliqueSelectorCellOn";
            }
            function un(e){
                qn.parentNode.className="obliqueSelectorCellOff";
            }
            
        }
        this.Update=on;this.Show=mn;this.Hide=nn;
    }
    function vn(wn){
        var container=document.createElement("div");var plus=document.createElement("div");var bar=document.createElement("div");var slider=document.createElement("div");var minus=document.createElement("div");var x=0;var y=0;var dragging=false;this.Init=function(){
            minus.className="ZoomBar_minus";minus.unselectable="on";minus.attachEvent("onclick",En);slider.className="ZoomBar_slider";slider.unselectable="on";slider.attachEvent("onmousedown",An);slider.attachEvent("onmousemove",Bn);slider.attachEvent("onmouseup",Cn);slider.attachEvent("onclick",IgnoreEvent);bar.className="ZoomBar_bar";bar.unselectable="on";bar.appendChild(slider);bar.attachEvent("onclick",Fn);plus.className="ZoomBar_plus";plus.unselectable="on";plus.attachEvent("onclick",Dn);container.className="ZoomBar";container.appendChild(minus);container.appendChild(bar);container.appendChild(plus);container.attachEvent("onmousedown",IgnoreEvent);container.attachEvent("onmouseup",IgnoreEvent);container.attachEvent("onclick",IgnoreEvent);container.attachEvent("ondblclick",IgnoreEvent);wn.appendChild(container);Kn();
        }
        ;this.Destroy=function(){
            minus.detachEvent("onclick",En);slider.detachEvent("onmousedown",An);slider.detachEvent("onmousemove",Bn);slider.detachEvent("onmouseup",Cn);slider.detachEvent("onclick",IgnoreEvent);bar.removeChild(slider);bar.detachEvent("onclick",Fn);plus.detachEvent("onclick",Dn);container.removeChild(plus);container.removeChild(bar);container.removeChild(minus);container.detachEvent("onmousedown",IgnoreEvent);container.detachEvent("onmousedown",IgnoreEvent);container.detachEvent("onclick",IgnoreEvent);container.detachEvent("ondblclick",IgnoreEvent);wn.removeChild(container);xm.DetachEvent("onendzoom",Kn);minus=slider=bar=plus=container=wn=xm=null;
        }
        ;function xn(){
            container.style.display="block";
        }
        function yn(){
            container.style.display="none";
        }
        function zn(){
            x=GetLeftPosition(container);y=GetTopPosition(container);
        }
        function An(e){
            e=GetEvent(e);CancelEvent(e);zn();if(slider.setCapture)slider.setCapture();dragging=true;return false;
        }
        function Bn(e){
            e=GetEvent(e);CancelEvent(e);if(dragging)slider.style.left=Gn(GetMouseX(e))+"px";return false;
        }
        function Cn(e){
            e=GetEvent(e);CancelEvent(e);if(slider.releaseCapture)slider.releaseCapture();dragging=false;In(Gn(GetMouseX(e)));orthoZoom.UpdateFromMap();obliqueZoom.UpdateFromMap();return false;
        }
        function Dn(e){
            xm.ZoomIn();
        }
        function En(e){
            xm.ZoomOut();
        }
        function Fn(e){
            e=GetEvent(e);CancelEvent(e);zn();In(Gn(GetMouseX(e)));return false;
        }
        function Gn(Hn){
            Hn-=(x+minus.offsetWidth+slider.offsetWidth);var max=bar.offsetWidth-slider.offsetWidth;if(Hn<0)Hn=0;else{
                if(Hn>max)Hn=max;
            }
            return Hn;
        }
        function In(Jn){
            var max=bar.offsetWidth-slider.offsetWidth;var zoom=1+MathRound(Jn/max*18);xm.SetZoom(zoom);
        }
        function Kn(){
            var max=bar.offsetWidth-slider.offsetWidth;var pos=(xm.GetZoomLevel()-1)/18*max;slider.style.left=pos+"px";
        }
        this.UpdateFromMap=Kn;this.Show=xn;this.Hide=yn;
    }
    function Ln(Mn){
        var container=document.createElement("div");var smallViewButton=document.createElement("div");var largeViewButton=document.createElement("div");container.title=L_ObliqueZoomBarSelectZoom_Text;container.setAttribute("id","obliqueZoomContainer");smallViewButton.setAttribute("id","obliqueZoomSmall");smallViewButton.className="obliqueZoomSmallOn";largeViewButton.setAttribute("id","obliqueZoomLarge");largeViewButton.className="obliqueZoomLargeOff";smallViewButton.attachEvent("onclick",Pn);largeViewButton.attachEvent("onclick",Qn);container.appendChild(smallViewButton);container.appendChild(largeViewButton);Mn.appendChild(container);function Nn(){
            container.style.display="block";
        }
        function On(){
            container.style.display="none";
        }
        function Pn(e){
            xm.ZoomOut();smallViewButton.className="obliqueZoomSmallOn";largeViewButton.className="obliqueZoomLargeOff";
        }
        function Qn(e){
            xm.ZoomIn();smallViewButton.className="obliqueZoomSmallOff";largeViewButton.className="obliqueZoomLargeOn";
        }
        function Rn(){
            smallViewButton.detachEvent("onclick",Pn);largeViewButton.detachEvent("onclick",Qn);container.removeChild(smallViewButton);container.removeChild(largeViewButton);smallViewButton=null;largeViewButton=null;container.parentNode.removeChild(container);container=null;
        }
        function Sn(){
            if(xm.GetZoomLevel()==1){
                smallViewButton.className="obliqueZoomSmallOn";largeViewButton.className="obliqueZoomLargeOff";
            }
            else{
                smallViewButton.className="obliqueZoomSmallOff";largeViewButton.className="obliqueZoomLargeOn";
            }
            
        }
        this.Destroy=Rn;this.Show=Nn;this.Hide=On;this.UpdateFromMap=Sn;
    }
    function Tn(Un,Vn,Wn){
        var wm=document.createElement("div");wm.setAttribute("id",Un);wm.innerHTML=Vn;var previousClass="obliqueCompassPointOff";var currentPositionIndex=Wn;wm.attachEvent("onmouseover",Xn);wm.attachEvent("onmouseout",Zn);wm.attachEvent("onclick",Yn);this.onclick=null;this.onmouseover=null;this.onmouseout=null;var me=this;var disabled=false;var rotator=new oo(wm,17,17);function Xn(e){
            if(disabled)return;previousClass=wm.className;wm.className="obliqueCompassPointHover";if(me.onmouseover)me.onmouseover(e);
        }
        function Yn(e){
            if(disabled)return;Xn(e);previousClass="obliqueCompassPointOn";if(me.onclick)me.onclick(e);
        }
        function Zn(e){
            if(disabled)return;wm.className=previousClass;if(me.onmouseout)me.onmouseout(e);
        }
        function ao(){
            previousClass="obliqueCompassPointOn";wm.className="obliqueCompassPointOn";
        }
        function bo(){
            previousClass="obliqueCompassPointOff";wm.className="obliqueCompassPointOff";
        }
        function co(){
            disabled=true;bo();
        }
        function eo(){
            disabled=false;ao();
        }
        function go(){
            return wm;
        }
        function ho(){
            return currentPositionIndex;
        }
        function jo(ko){
            currentPositionIndex=ko;
        }
        function lo(){
            rotator.Reset();eo();
        }
        function mo(no){
            wm.style.left=no.left;wm.style.top=no.top;
        }
        function oo(po,qo,ro){
            var wm=po;var currentAngle=0;var deltaAngle=0.3;var targetAngle=0;var deltaTime=40;var radius=25;var animating=false;var quartCircle=Math.PI/2;var isCCW=true;var limit=deltaAngle+0.1;function so(to,uo,vo){
                if(uo>=vo-to&&uo<=vo+to)return true;return false;
            }
            function wo(){
                currentAngle+=deltaAngle;if(currentAngle>Math.PI*2)currentAngle-=Math.PI*2;else{
                    if(currentAngle<0)currentAngle+=Math.PI*2;
                }
                if(so(limit,currentAngle,targetAngle)){
                    deltaAngle=0.3;currentAngle=targetAngle;xo(currentAngle);animating=false;return;
                }
                xo(currentAngle);window.setTimeout(wo,deltaTime);
            }
            function xo(yo){
                var x=qo+radius*Math.sin(yo);var y=ro+radius*Math.cos(yo);wm.style.left=x+"px";wm.style.top=y+"px";
            }
            function zo(Ao){
                if(animating)return;animating=true;targetAngle=Ao;wo();
            }
            function Bo(Co,Do){
                isCCW=Do;if(!isCCW)deltaAngle*=-1;zo(quartCircle*Co);
            }
            function Eo(){
                animating=false;currentAngle=0;
            }
            this.RotateTo=zo;this.RotateToIndex=Bo;this.Reset=Eo;
        }
        function Fo(){
            wm.parentNode.removeChild(wm);wm.detachEvent("onmouseover",Xn);wm.detachEvent("onmouseout",Zn);wm.detachEvent("onclick",Yn);wm=null;
        }
        this.GetElement=go;this.GetCurrentPositionIndex=ho;this.SetCurrentPositionIndex=jo;this.SetCurrentPosition=mo;this.On=ao;this.Off=bo;this.RotateToIndex=rotator.RotateToIndex;this.Reset=lo;this.Disable=co;this.Enable=eo;this.Destroy=Fo;
    }
    function Go(Ho){
        var pointPositions=new Array();pointPositions.push({
            "top":"-8px","left":"17px"
        }
        );pointPositions.push({
            "top":"17px","left":"42px"
        }
        );pointPositions.push({
            "top":"42px","left":"17px"
        }
        );pointPositions.push({
            "top":"17px","left":"-8px"
        }
        );var compassContainer=document.createElement("div");compassContainer.setAttribute("id","obliqueCompassContainer");compassContainer.title=L_ObliqueCompassSelectDirection_Text;var northElm=new Tn("obliqueCompassPointN","N",0);var northElmRef=northElm.GetElement();northElmRef.attachEvent("onclick",To);northElmRef.attachEvent("onmouseover",Zo);northElmRef.attachEvent("onmouseout",Oo);var eastElm=new Tn("obliqueCompassPointE","E",1);var eastElmRef=eastElm.GetElement();eastElmRef.attachEvent("onclick",Uo);eastElmRef.attachEvent("onmouseover",Xo);eastElmRef.attachEvent("onmouseout",Oo);var southElm=new Tn("obliqueCompassPointS","S",2);var southElmRef=southElm.GetElement();southElmRef.attachEvent("onclick",So);southElmRef.attachEvent("onmouseover",Wo);southElmRef.attachEvent("onmouseout",Oo);var westElm=new Tn("obliqueCompassPointW","W",3);var westElmRef=westElm.GetElement();westElmRef.attachEvent("onclick",Vo);westElmRef.attachEvent("onmouseover",Yo);westElmRef.attachEvent("onmouseout",Oo);var arrowElm=document.createElement("div");compassContainer.appendChild(northElmRef);compassContainer.appendChild(eastElmRef);compassContainer.appendChild(southElmRef);compassContainer.appendChild(westElmRef);compassContainer.appendChild(arrowElm);Ho.appendChild(compassContainer);cp();function Io(Jo){
            if(Jo<0)Jo=4-Math.abs(Jo);return Jo;
        }
        function Ko(Lo){
            var pos=Lo.GetCurrentPositionIndex();eastElm.SetCurrentPositionIndex(Io(eastElm.GetCurrentPositionIndex()-pos));westElm.SetCurrentPositionIndex(Io(westElm.GetCurrentPositionIndex()-pos));northElm.SetCurrentPositionIndex(Io(northElm.GetCurrentPositionIndex()-pos));southElm.SetCurrentPositionIndex(Io(southElm.GetCurrentPositionIndex()-pos));var ccw=true;if(pos==3)ccw=false;northElm.RotateToIndex(2-northElm.GetCurrentPositionIndex()<0?northElm.GetCurrentPositionIndex():2-northElm.GetCurrentPositionIndex(),ccw);eastElm.RotateToIndex(2-eastElm.GetCurrentPositionIndex()<0?eastElm.GetCurrentPositionIndex():2-eastElm.GetCurrentPositionIndex(),ccw);southElm.RotateToIndex(2-southElm.GetCurrentPositionIndex()<0?southElm.GetCurrentPositionIndex():2-southElm.GetCurrentPositionIndex(),ccw);westElm.RotateToIndex(2-westElm.GetCurrentPositionIndex()<0?westElm.GetCurrentPositionIndex():2-westElm.GetCurrentPositionIndex(),ccw);
        }
        function Mo(No){
            switch(No){
                case 0:Oo();break;case 1:Qo();break;case 2:Po();break;case 3:Ro();break;
            }
            
        }
        function Oo(){
            arrowElm.className="obliqueCompassArrowU";
        }
        function Po(){
            arrowElm.className="obliqueCompassArrowD";
        }
        function Qo(){
            arrowElm.className="obliqueCompassArrowR";
        }
        function Ro(){
            arrowElm.className="obliqueCompassArrowL";
        }
        function So(e){
            Ko(southElm);Mo(0);var scene=xm.GetObliqueScene();if(scene){
                var aScene=scene.GetRotation("South");if(aScene)xm.SetObliqueOrientation("South");
            }
            
        }
        function To(e){
            Ko(northElm);Mo(0);var scene=xm.GetObliqueScene();if(scene){
                var aScene=scene.GetRotation("North");if(aScene)xm.SetObliqueOrientation("North");
            }
            
        }
        function Uo(e){
            Ko(eastElm);Mo(0);var scene=xm.GetObliqueScene();if(scene){
                var aScene=scene.GetRotation("East");if(aScene)xm.SetObliqueOrientation("East");
            }
            
        }
        function Vo(e){
            Ko(westElm);Mo(0);var scene=xm.GetObliqueScene();if(scene){
                var aScene=scene.GetRotation("West");if(aScene)xm.SetObliqueOrientation("West");
            }
            
        }
        function Wo(e){
            Mo(southElm.GetCurrentPositionIndex());
        }
        function Xo(e){
            Mo(eastElm.GetCurrentPositionIndex());
        }
        function Yo(e){
            Mo(westElm.GetCurrentPositionIndex());
        }
        function Zo(e){
            Mo(northElm.GetCurrentPositionIndex());
        }
        function ap(){
            compassContainer.style.display="none";
        }
        function bp(){
            compassContainer.style.display="block";
        }
        function cp(){
            var scene=xm.GetObliqueScene();if(!scene)return;switch(scene.GetOrientation()){
                case "North":Ko(northElm);break;case "South":Ko(southElm);break;case "East":Ko(eastElm);break;case "West":Ko(westElm);break;
            }
            Mo(0);if(scene.GetRotation("North"))northElm.Enable();else northElm.Disable();if(scene.GetRotation("South"))southElm.Enable();else southElm.Disable();if(scene.GetRotation("East"))eastElm.Enable();else eastElm.Disable();if(scene.GetRotation("West"))westElm.Enable();else westElm.Disable();
        }
        function ep(){
            northElm.Destroy();eastElm.Destroy();southElm.Destroy();westElm.Destroy();northElmRef.detachEvent("onclick",To);northElmRef.detachEvent("onmouseover",Zo);northElmRef.detachEvent("onmouseout",Oo);eastElmRef.detachEvent("onclick",Uo);eastElmRef.detachEvent("onmouseover",Xo);eastElmRef.detachEvent("onmouseout",Oo);southElmRef.detachEvent("onclick",So);southElmRef.detachEvent("onmouseover",Wo);southElmRef.detachEvent("onmouseout",Oo);westElmRef.detachEvent("onclick",Vo);westElmRef.detachEvent("onmouseover",Yo);westElmRef.detachEvent("onmouseout",Oo);compassContainer.parentNode.removeChild(compassContainer);compassContainer=null;
        }
        this.Hide=ap;this.Show=bp;this.UpdateFromMap=cp;this.Destroy=ep;
    }
    
}
;Msn.VE.DashboardSize=new function(){
    this.Normal="normal";this.Small="small";this.Tiny="tiny";
}
();Msn.VE.LatLong=function(gp,hp){
    this.latitude=gp;this.longitude=hp;this.ToString=function(){
        return "("+this.latitude+", "+this.longitude+")";
    }
    ;this.Copy=function(jp){
        if(!jp)return;this.latitude=jp.latitude;this.longitude=jp.longitude;
    }
    ;
}
;Msn.VE.LatLongRectangle=function(kp,lp){
    this.northwest=kp;this.southeast=lp;this.ToString=function(){
        return "("+(this.northwest?this.northwest.ToString():"null")+", "+(this.southeast?this.southeast.ToString():"null")+")";
    }
    ;this.Copy=function(mp){
        if(!mp)return;if(!this.northwest)this.northwest=new Msn.VE.LatLong();if(!this.southeast)this.southeast=new Msn.VE.LatLong();this.northwest.Copy(mp.northwest);this.southeast.Copy(mp.southeast);
    }
    ;this.Center=function(){
        var sinLat1=Math.sin(this.northwest.latitude*Math.PI/180);var sinLat2=Math.sin(this.southeast.latitude*Math.PI/180);var average=0.25*(Math.log((1+sinLat1)/(1-sinLat1))+Math.log((1+sinLat2)/(1-sinLat2)));var center=new Msn.VE.LatLong();center.latitude=Math.atan(Math.exp(average))*360/Math.PI-90;center.longitude=0.5*(this.northwest.longitude+this.southeast.longitude);return center;
    }
    ;this.Contains=function(np){
        return np.latitude<=kp.latitude&&np.longitude>=kp.longitude&&np.latitude>=lp.latitude&&np.longitude<=lp.longitude;
    }
    ;
}
;Msn.VE.MapStyle=new function(){
    this.Road="r";this.Aerial="a";this.Hybrid="h";this.Oblique="o";
}
();Msn.VE.MapView=function(){
    this.zoomLevel=0;this.mapStyle=null;this.center=new Msn.VE.Pixel();this.latlong=new Msn.VE.LatLong();this.pixelRect=new Msn.VE.PixelRectangle();this.latlongRect=new Msn.VE.LatLongRectangle();this.sceneId=null;this.sceneOrientation=null;var p_this=this;var viewType="pixel";this.Destroy=function(){
        this.center=this.latlong=p_this=null;
    }
    ;this.GetViewType=function(){
        return viewType;
    }
    ;function op(){
        var copy=new Msn.VE.MapView();copy.Copy(p_this);return copy;
    }
    function pp(qp){
        p_this.zoomLevel=qp.zoomLevel;p_this.mapStyle=qp.mapStyle;p_this.center.Copy(qp.center);p_this.latlong.Copy(qp.latlong);p_this.pixelRect.Copy(qp.pixelRect);p_this.latlongRect.Copy(qp.latlongRect);p_this.sceneId=qp.sceneId;p_this.sceneOrientation=qp.sceneOrientation;viewType=qp.GetViewType();
    }
    function rp(sp){
        return sp!=null&&p_this.zoomLevel==sp.zoomLevel&&p_this.mapStyle==sp.mapStyle&&MathAbs(p_this.center.x-sp.center.x)<1E-06&&MathAbs(p_this.center.y-sp.center.y)<1E-06&&p_this.sceneId==sp.sceneId&&p_this.sceneOrientation==sp.sceneOrientation;
    }
    function tp(){
        return "("+p_this.latlong.ToString()+", "+p_this.zoomLevel+", "+p_this.mapStyle+")";
    }
    function up(vp){
        if(!vp)return;p_this.center=vp;viewType="pixel";
    }
    function wp(xp){
        if(!xp)return;p_this.latlong=xp;viewType="latlong";
    }
    function yp(zp){
        p_this.pixelRect=zp;viewType="pixelRect";
    }
    function Ap(Bp){
        p_this.latlongRect=Bp;viewType="latlongRect";
    }
    function Cp(Dp){
        if(Dp<=0)Dp=1;switch(viewType){
            case "pixel":var factor=Math.pow(2,Dp-p_this.zoomLevel);p_this.center.x*=factor;p_this.center.y*=factor;break;case "pixelRect":var factor=Math.pow(2,Dp-p_this.zoomLevel);p_this.pixelRect.topLeft.x*=factor;p_this.pixelRect.topLeft.y*=factor;p_this.pixelRect.bottomRight.x*=factor;p_this.pixelRect.bottomRight.y*=factor;break;
        }
        p_this.zoomLevel=Dp;
    }
    function Ep(Fp,Gp,Hp){
        p_this.mapStyle=Fp;if(viewType=="pixel")viewType="latlong";if(Fp!="o"){
            p_this.sceneId=null;p_this.sceneOrientation=null;
        }
        else{
            p_this.sceneId=Gp;p_this.sceneOrientation=Hp;
        }
        
    }
    function Ip(Jp){
        if(Jp)return p_this.center.x*Math.pow(2,Jp-p_this.zoomLevel);return p_this.center.x;
    }
    function Kp(Lp){
        if(Lp)return p_this.center.y*Math.pow(2,Lp-p_this.zoomLevel);return p_this.center.y;
    }
    function Mp(Np){
        if(Np==undefined)return p_this.center;return new Msn.VE.Pixel(p_this.GetX(Np),p_this.GetY(Np));
    }
    function Op(Pp,Qp,Rp){
        switch(viewType){
            case "pixel":p_this.latlong=Pp.PixelToLatLong(p_this.center,p_this.zoomLevel);break;case "latlong":p_this.center=Pp.LatLongToPixel(p_this.latlong,p_this.zoomLevel);break;case "pixelRect":Sp(Pp,Qp,Rp);break;case "latlongRect":if(p_this.mapStyle=="o"){
                p_this.zoomLevel=1;var scene=Pp.GetScene();if(!scene.ContainsLatLong(p_this.latlongRect.northwest)||!scene.ContainsLatLong(p_this.latlongRect.southeast)){
                    p_this.latlong=p_this.latlongRect.Center();p_this.center=Pp.LatLongToPixel(p_this.latlong,p_this.zoomLevel);
                }
                else{
                    p_this.pixelRect.topLeft=Pp.LatLongToPixel(p_this.latlongRect.northwest,p_this.zoomLevel);p_this.pixelRect.bottomRight=Pp.LatLongToPixel(p_this.latlongRect.southeast,p_this.zoomLevel);Sp(Pp,Qp,Rp);
                }
                
            }
            else{
                p_this.zoomLevel=12;p_this.pixelRect.topLeft=Pp.LatLongToPixel(p_this.latlongRect.northwest,p_this.zoomLevel);p_this.pixelRect.bottomRight=Pp.LatLongToPixel(p_this.latlongRect.southeast,p_this.zoomLevel);Sp(Pp,Qp,Rp);
            }
            break;
        }
        viewType="pixel";
    }
    function Sp(Tp,Up,Vp){
        var zoomPivot=19;var zoomFactor=Math.pow(2,zoomPivot-p_this.zoomLevel);var viewportWidth=MathMax(1,MathAbs(p_this.pixelRect.topLeft.x-p_this.pixelRect.bottomRight.x)*zoomFactor);var viewportHeight=MathMax(1,MathAbs(p_this.pixelRect.topLeft.y-p_this.pixelRect.bottomRight.y)*zoomFactor);var log2=Math.log(2);var horizontalZoom=zoomPivot-Math.ceil(Math.log(viewportWidth/Up)/log2);var verticalZoom=zoomPivot-Math.ceil(Math.log(viewportHeight/Vp)/log2);var newZoom=MathMin(horizontalZoom,verticalZoom);if(newZoom<=0)newZoom=1;zoomFactor=Math.pow(2,newZoom-p_this.zoomLevel);p_this.center.x=0.5*(p_this.pixelRect.topLeft.x+p_this.pixelRect.bottomRight.x)*zoomFactor;p_this.center.y=0.5*(p_this.pixelRect.topLeft.y+p_this.pixelRect.bottomRight.y)*zoomFactor;p_this.zoomLevel=newZoom;p_this.latlong=Tp.PixelToLatLong(p_this.center,p_this.zoomLevel);
    }
    this.MakeCopy=op;this.Copy=pp;this.Equals=rp;this.ToString=tp;this.SetCenter=up;this.SetCenterLatLong=wp;this.SetPixelRectangle=yp;this.SetLatLongRectangle=Ap;this.SetZoomLevel=Cp;this.SetMapStyle=Ep;this.GetX=Ip;this.GetY=Kp;this.GetCenter=Mp;this.Resolve=Op;this.SetZoomLevel=Cp;
}
;Msn.VE.ObliqueScene=function(Wp,Xp,Yp,Zp,aq,bq,cq,eq,gq,hq,jq,kq){
    var tileSize=256;this.neighborScenes=jq;var bounds=new Msn.VE.Bounds(1,2,0,0,cq/2,eq/2);function lq(mq,nq){
        var zoomFactor=Math.pow(2,nq-2);var vector=[[mq.x/zoomFactor],[mq.y/zoomFactor],[1]];var result=MatrixMultiply(gq,vector);var latlong=new Msn.VE.LatLong();latlong.longitude=result[0][0]/result[2][0];latlong.latitude=result[1][0]/result[2][0];return latlong;
    }
    function oq(pq,qq){
        var zoomFactor=Math.pow(2,qq-2);var vector=[[pq.longitude],[pq.latitude],[1]];var result=MatrixMultiply(hq,vector);var pixel=new Msn.VE.Pixel();pixel.x=result[0][0]/result[2][0]*zoomFactor;pixel.y=result[1][0]/result[2][0]*zoomFactor;return pixel;
    }
    function rq(sq,tq,uq){
        if(sq<0||tq<0)return false;if(uq==1)return sq<cq/2&&tq<eq/2;return sq<cq&&tq<eq;
    }
    function vq(){
        return Wp;
    }
    function wq(xq,yq,zq){
        var tileId=yq*(zq==1?cq/2:cq)+xq;return "http://c"+xq%2+".p"+bq+".oblique.tiles.virtualearth.net/tiles/o"+Xp+"-"+Yp+"-"+(aq+zq-2)+"-"+tileId+".jpeg?g=24";
    }
    function Aq(){
        return "http://thumbs.oblique.tiles.virtualearth.net/tiles/ot"+Wp+".jpeg?g=24";
    }
    function Bq(i){
        var sceneId=jq[i];if(sceneId==null||sceneId==-1)return null;return new Msn.VE.ObliqueScene(sceneId);
    }
    function Cq(i){
        var sceneId=kq[i];if(sceneId==null||sceneId==-1)return null;return new Msn.VE.ObliqueScene(sceneId);
    }
    function Dq(){
        return Zp;
    }
    function Eq(){
        return bounds;
    }
    function Fq(){
        return cq*tileSize;
    }
    function Gq(){
        return eq*tileSize;
    }
    function Hq(Iq){
        if(!Iq)return false;var pixel=oq(Iq,2);return Jq(pixel,2);
    }
    function Jq(Kq,Lq){
        var zoomFactor=Math.pow(2,2-Lq);var x=Kq.x*zoomFactor;var y=Kq.y*zoomFactor;return x>=0&&y>=0&&x<Fq()&&y<Gq();
    }
    this.PixelToLatLong=lq;this.LatLongToPixel=oq;this.IsValidTile=rq;this.GetID=vq;this.GetTileFilename=wq;this.GetThumbnailFilename=Aq;this.GetNeighbor=Bq;this.GetRotation=Cq;this.GetOrientation=Dq;this.GetBounds=Eq;this.GetWidth=Fq;this.GetHeight=Gq;this.ContainsLatLong=Hq;this.ContainsPixel=Jq;
}
;Msn.VE.Orientation=new function(){
    this.North="North";this.East="East";this.West="West";this.South="South";
}
();Msn.VE.Pixel=function(x,y){
    this.x=x;this.y=y;this.ToString=function(){
        return "("+this.x+", "+this.y+")";
    }
    ;this.Copy=function(Mq){
        if(!Mq)return;this.x=Mq.x;this.y=Mq.y;
    }
    ;
}
;Msn.VE.PixelRectangle=function(Nq,Oq){
    this.topLeft=Nq;this.bottomRight=Oq;this.ToString=function(){
        return "("+(this.topLeft?this.topLeft.ToString():"null")+", "+(this.bottomRight?this.bottomRight.ToString():"null")+")";
    }
    ;this.Copy=function(Pq){
        if(!Pq)return;if(!this.topLeft)this.topLeft=new Msn.VE.Pixel();if(!this.bottomRight)this.bottomRight=new Msn.VE.Pixel();this.topLeft.Copy(Pq.topLeft);this.bottomRight.Copy(Pq.bottomRight);
    }
    ;
}
;Msn.VE.LineRegion=function(Qq,Rq,Sq){
    this.boundingRectangle=Qq;this.indices=Rq;this.childRegions=Sq;function Tq(){
        return "Bounding Rectangle: "+this.boundingRectangle[0].ToString()+" to "+this.boundingRectangle[1].ToString()+" | Indices: ["+Rq+"]";
    }
    this.ToString=Tq;
}
;var L_integerencodingoutofrange_text="VEIntegerEncoding: The number encoded is out of supported range";var L_floatintegermapencodingoutofrange_text="VEFloatIntegerMap: The number encoded is out of supported range";var L_integerencodinginvalidstringlength_text="VEIntegerEncoding: Invalid string length";var L_integerencodingunknowndigit_text="VEIntegerEncoding: The encoded string has an unknown digit";function VEIntegerEncoding(Uq,Vq){
    var m_digits=Uq;var m_base=Uq.length;var m_valueLength=Vq;var power=1;for(var i=0;i<m_valueLength;++i){
        power*=m_base;
    }
    var m_maxValue=power-1;var m_digitMap=new Array();for(var digitValue=0;digitValue<m_digits.length;++digitValue){
        m_digitMap[m_digits.substr(digitValue,1)]=digitValue;
    }
    this.MaxValue=function(){
        return m_maxValue;
    }
    ;this.ValueLength=function(){
        return m_valueLength;
    }
    ;this.Encode=function(Wq){
        if(Wq<=m_maxValue){
            var encodedString="";var digitValues=new Array();for(var i=0;i<m_valueLength;++i){
                digitValues[i]=0;
            }
            var digitIndex=m_valueLength-1;while(Wq>0){
                digitValues[digitIndex]=Math.floor(Wq%m_base);Wq=Math.floor(Wq/m_base);--digitIndex;
            }
            for(var i=0;i<digitValues.length;++i){
                encodedString+=m_digits.substr(digitValues[i],1);
            }
            return encodedString;
        }
        else throw L_integerencodingoutofrange_text;
    }
    ;this.Decode=function(Xq){
        if(Xq.length==m_valueLength){
            var numValue=0;for(var i=0;i<Xq.length;++i){
                numValue*=m_base;numValue+=this.DigitValue(Xq.substr(i,1));
            }
            return numValue;
        }
        else throw L_integerencodinginvalidstringlength_text;
    }
    ;this.DigitValue=function(Yq){
        if(m_digitMap[Yq]!=null&&m_digitMap[Yq]!="undefined")return m_digitMap[Yq];else throw L_integerencodingunknowndigit_text;
    }
    ;
}
function VEFloatIntegerMap(Zq,ar,br){
    var m_minFloat=Zq;var m_maxFloat=ar;var m_maxInt=br;this.MinFloat=function(){
        return m_minFloat;
    }
    ;this.MaxFloat=function(){
        return m_maxFloat;
    }
    ;this.MaxInt=function(){
        return m_maxInt;
    }
    ;this.FloatToInt=function(cr){
        if(cr>=m_minFloat&&cr<=m_maxFloat){
            var fraction=(cr-m_minFloat)/(m_maxFloat-m_minFloat);var intValue=fraction*m_maxInt+0.5;return Math.min(Math.floor(intValue),m_maxInt);
        }
        else throw L_floatintegermapencodingoutofrange_text;
    }
    ;this.IntToFloat=function(er){
        if(er<=m_maxInt){
            var fraction=er/m_maxInt;var floatNumber=m_minFloat+fraction*(m_maxFloat-m_minFloat);return floatNumber;
        }
        else throw L_floatintegermapencodingoutofrange_text;
    }
    ;
}
var L_velatlongencodinginvalidstringlength_text="VELatLongEncoding: Invalid string length";function VELatLongEncoding(){
    var m_minLatitude=-90;var m_maxLatitude=90;var m_minLongitude=-180;var m_maxLongitude=180;var m_digits="0123456789bcdfghjkmnpqrstvwxyz";var m_valueLength=6;var m_integerEncoding=new VEIntegerEncoding(m_digits,m_valueLength);var m_latitudeMap=new VEFloatIntegerMap(m_minLatitude,m_maxLatitude,m_integerEncoding.MaxValue());var m_longitudeMap=new VEFloatIntegerMap(m_minLongitude,m_maxLongitude,m_integerEncoding.MaxValue());this.Encode=function(gr,hr){
        var s=m_integerEncoding.Encode(m_latitudeMap.FloatToInt(gr))+m_integerEncoding.Encode(m_longitudeMap.FloatToInt(hr));return s;
    }
    ;this.Decode=function(jr){
        if(jr.length==2*m_integerEncoding.ValueLength()){
            var valueLength=m_integerEncoding.ValueLength();var strLatitude=jr.substr(0,valueLength);var strLongitude=jr.substr(valueLength,valueLength);var intLatitude=m_integerEncoding.Decode(strLatitude);var intLongitude=m_integerEncoding.Decode(strLongitude);var latLongArray=new Array();latLongArray[0]=m_latitudeMap.IntToFloat(intLatitude);latLongArray[1]=m_longitudeMap.IntToFloat(intLongitude);return latLongArray;
        }
        else throw L_velatlongencodinginvalidstringlength_text;
    }
    ;
}
var windowWidth=0;var windowHeight=0;var scrollbarWidth=null;function GetWindowWidth(){
    var width=0;if(typeof window.innerWidth=="number")width=window.innerWidth;else{
        if(document.documentElement&&document.documentElement.clientWidth)width=document.documentElement.clientWidth;else{
            if(document.body&&document.body.clientWidth)width=document.body.clientWidth;
        }
        
    }
    if(!width||width<100)width=100;return width;
}
function GetWindowHeight(){
    var height=0;if(typeof window.innerHeight=="number")height=window.innerHeight;else{
        if(document.documentElement&&document.documentElement.clientHeight)height=document.documentElement.clientHeight;else{
            if(document.body&&document.body.clientHeight)height=document.body.clientHeight;
        }
        
    }
    if(!height||height<100)height=100;return height;
}
function GetScrollbarWidth(){
    if(scrollbarWidth)return scrollbarWidth;if(navigator.userAgent.indexOf("IE")>=0){
        var div=document.createElement("div");var sbWidth=null;div.style.visible="hidden";div.style.overflowY="scroll";div.style.position="absolute";div.style.width=0;document.body.insertAdjacentElement("afterBegin",div);sbWidth=div.offsetWidth;div.parentNode.removeChild(div);if(!sbWidth)sbWidth=16;scrollbarWidth=sbWidth;return sbWidth;
    }
    else return 0;
}
function GetUrlPrefix(){
    var lastfslash=window.location.pathname.lastIndexOf("/");var hosturl=window.location.protocol+"//"+window.location.hostname+window.location.pathname.substring(0,lastfslash+1);return hosturl;
}
function GetUrlParameterString(){
    var urlParameterString=window.location.search;if(urlParameterString.length==0||urlParameterString.indexOf("?")==-1)return "";return urlParameterString.substr(urlParameterString.indexOf("?")+1);
}
function CheckWipExistence(){
    var parameterString=GetUrlParameterString();if(parameterString!=""&&parameterString.indexOf("wip=")>-1)return true;return false;
}
function GetUrlParameters(){
    var parameters=new Array();var urlParameterString=GetUrlParameterString();if(!urlParameterString)return parameters;var parameterStrings=urlParameterString.split("&");for(var i=0;i<parameterStrings.length;i++){
        var parameterParts=parameterStrings[i].split("=");if(parameterParts.length==2&&parameterParts[0]&&parameterParts[1]){
            parameters.push(unescape(parameterParts[0]));parameters.push(unescape(parameterParts[1]));
        }
        
    }
    return parameters;
}
function ParseShiftKeyForLinks(e){
    if(e.shiftKey)return false;return true;
}
Msn.VE.API=new Object();Msn.VE.API.Globals=new Object();Msn.VE.API.Constants=new Object();Msn.VE.API.Globals.vemapinstances=null;Msn.VE.API.Globals.veonbegininvokeevent=null;Msn.VE.API.Globals.veonendinvokeevent=null;Msn.VE.API.Globals.vefindresultsnpanel=null;Msn.VE.API.Globals.language="en";Msn.VE.API.Globals.vecurrentversion="1.3.0515";Msn.VE.API.Globals.vecurrentdomain="http://local.live.com";Msn.VE.API.Globals.veanalyticsenabled="True";Msn.VE.API.Globals.veomnitureaccount="msnportalearth";Msn.VE.API.Globals.vedebug=false;Msn.VE.API.Globals.analyticsInitialized=false;Msn.VE.API.Constants.omnitureurl="http://stj.msn.com/br/om/js/s_code.js";Msn.VE.API.Constants.imageryurl=Msn.VE.API.Globals.vecurrentdomain+"/imagery.ashx";Msn.VE.API.Constants.iconurl=Msn.VE.API.Globals.vecurrentdomain+"/i/pins/poi_usergenerated.gif";Msn.VE.API.Constants.mapcontroljs=Msn.VE.API.Globals.vecurrentdomain+"/mapcontrol.ashx";Msn.VE.API.Constants.searchservice=Msn.VE.API.Globals.vecurrentdomain+"/search.ashx";Msn.VE.API.Constants.directionsservice=Msn.VE.API.Globals.vecurrentdomain+"/directions.ashx";Msn.VE.API.Constants.collectionservice=Msn.VE.API.Globals.vecurrentdomain+"/UserCollections.aspx";Msn.VE.API.Constants.atlascompatjs=Msn.VE.API.Globals.vecurrentdomain+"/js/atlascompat.js";Msn.VE.API.Constants.stylesheet=Msn.VE.API.Globals.vecurrentdomain+"/css/"+Msn.VE.API.Globals.language+"/api.css";Msn.VE.API.Constants.erostylesheet=Msn.VE.API.Globals.vecurrentdomain+"/css/"+Msn.VE.API.Globals.language+"/ero.css";Msn.VE.API.Constants.vedirectionsstarticon=Msn.VE.API.Globals.vecurrentdomain+"/i/pins/mapicon_start.gif";Msn.VE.API.Constants.vedirectionsendicon=Msn.VE.API.Globals.vecurrentdomain+"/i/pins/mapicon_end.gif";Msn.VE.API.Constants.vedirectionsstepicon=Msn.VE.API.Globals.vecurrentdomain+"/i/pins/RedCircle%1.gif";Msn.VE.API.Constants.mapguid="mapguid";Msn.VE.API.Constants.contextid="contextid";Msn.VE.API.Globals.vemapheight=400;Msn.VE.API.Globals.vemapwidth=600;Msn.VE.API.Globals.vemapzoom=4;Msn.VE.API.Globals.vemaplatitude=43.75;Msn.VE.API.Globals.vemaplongitude=-99.71;Msn.VE.API.Globals.vemapstyle="r";Msn.VE.API.Globals.vepushpinpanelzIndex=999;Msn.VE.API.Globals.vemessagepanelheight=75;Msn.VE.API.Globals.vemessagepanelzIndex=99;Msn.VE.API.Globals.veplacelistpanelheight=200;Msn.VE.API.Globals.veplacelistpanelwidth=350;Msn.VE.API.Globals.veplacelistpanelzIndex=300;Msn.VE.API.Globals.vefindresultsnpanelwidth=200;Msn.VE.API.Globals.vefindresultsnpanelzIndex=99;Msn.VE.API.Globals.vefindresultsnpanelcolor="blue";Msn.VE.API.Globals.vecurrentsearchindex=1;Msn.VE.API.Globals.vesearchpoiresults=null;Msn.VE.API.Globals.vesearchlocresults=null;Msn.VE.API.Globals.veiscommercialcontrol=false;Msn.VE.API.Globals.veobliqueMode=null;Msn.VE.API.Globals.Dispose=function(){
    Msn.VE.API.Globals.veonbegininvokeevent=null;Msn.VE.API.Globals.veonendinvokeevent=null;Msn.VE.API.Globals.vefindresultsnpanel=null;
}
;Msn.VE.API.Globals.PosX=function(e){
    var posx=0;if(!e)var e=window.event;if(e.pageX)posx=e.pageX;else{
        if(e.clientX)posx=e.clientX+document.body.scrollLeft;
    }
    return posx;
}
;Msn.VE.API.Globals.PosY=function(e){
    var posy=0;if(!e)var e=window.event;if(e.pageY)posy=e.pageY;else{
        if(e.clientY)posy=e.clientY+document.body.scrollTop;
    }
    return posy;
}
;function VE_Help(){
    
}
RegisterNamespaces("Msn.VE.Constants.Css");var header=document.getElementsByTagName("body")[0];var VE_ContextMenu=null;s_account=Msn.VE.API.Globals.veomnitureaccount;function RegisterNamespaces(){
    for(var i=0;i<arguments.length;i++){
        var astrParts=arguments[i].split(".");var root=window;for(var j=0;j<astrParts.length;j++){
            if(!root[astrParts[j]])root[astrParts[j]]=new Object();root=root[astrParts[j]];
        }
        
    }
    
}
function VE_SelectItem(kr,lr){
    this.data=kr;this.description=lr;
}
VE_SelectItem.prototype.toString=function(){
    return this.description;
}
;function VE_Select(mr,nr,or,pr){
    this.isVisible=false;var items=new Array();var element=document.createElement("div");element.setAttribute("id",mr);this.id=mr;var elementId=mr;var objRef=this;var selectedIndex=-1;var selectedClass=or?or:"";var defaultClass=nr?nr:"";var mouseOverClass=pr?pr:"";var previousDefaultClass="";function qr(rr){
        if(!(rr instanceof VE_SelectItem))rr=new VE_SelectItem(rr,rr.toString());items.push(rr);var listDiv=document.createElement("div");listDiv.setAttribute("id",elementId+"_"+(items.length-1));listDiv.onclick=ur;listDiv.onmouseover=vr;listDiv.onmouseout=wr;listDiv.innerHTML=rr.description;element.appendChild(listDiv);
    }
    function sr(){
        return items.length;
    }
    function tr(){
        return element;
    }
    function ur(e){
        var itemDiv=GetTarget(e);var index=Fr(itemDiv);xr(index);if(objRef.OnClick)objRef.OnClick(index,items[index]);if(objRef.OnSelect)objRef.OnSelect(index,items[index]);
    }
    function vr(e){
        var itemDiv=GetTarget(e);var index=Fr(itemDiv);previousDefaultClass=itemDiv.className;itemDiv.className=mouseOverClass;if(objRef.OnMouseOver)objRef.OnMouseOver(index,items[index]);
    }
    function wr(e){
        var itemDiv=GetTarget(e);var index=Fr(itemDiv);itemDiv.className=previousDefaultClass;if(objRef.OnMouseOut)objRef.OnMouseOut(index,items[index]);
    }
    function xr(yr){
        if(yr>=0&&yr<items.length){
            var previousIndex=zr();if(previousIndex>=0)element.childNodes[previousIndex].className=defaultClass;selectedIndex=yr;element.childNodes[yr].className=selectedClass;previousDefaultClass=element.childNodes[yr].className;
        }
        else{
            var previousIndex=zr();if(previousIndex>=0)element.childNodes[previousIndex].className=defaultClass;selectedIndex=-1;
        }
        
    }
    function zr(){
        return selectedIndex;
    }
    function Ar(){
        if(selectedIndex>=0&&selectedIndex<items.length)return items[selectedIndex];return null;
    }
    function Br(Cr){
        if(Cr>=0&&Cr<items.length)return items[Cr];return null;
    }
    function Dr(Er){
        if(Er<0||Er>=items.length)return;if(Er<selectedIndex)selectedIndex-=1;else{
            if(Er==selectedIndex)selectedIndex=-1;
        }
        items.splice(Er,1);element.removeChild(element.childNodes[Er]);
    }
    function Fr(Gr){
        for(var i=0;i<element.childNodes.length;++i){
            if(Gr==element.childNodes[i])return i;
        }
        return -1;
    }
    function Hr(){
        while(items.length>0){
            items.pop();
        }
        while(element.childNodes.length>0){
            element.removeChild(element.lastChild);
        }
        selectedIndex=-1;
    }
    function Ir(){
        element.style.display="block";this.isVisible=true;
    }
    function Jr(){
        element.style.display="none";this.isVisible=false;
    }
    this.OnClick=null;this.GetCount=sr;this.GetElement=tr;this.GetSelectedIndex=zr;this.GetSelectedItem=Ar;this.SelectItemAtIndex=xr;this.OnSelect=null;this.AddItem=qr;this.OnMouseOver=null;this.OnSelect=null;this.OnMouseOut=null;this.ClearItems=Hr;this.RemoveItemAtIndex=Dr;this.Show=Ir;this.Hide=Jr;
}
function OutputEncoder_EncodeHtml(Kr){
    var c;var EncodeHtml="";if(Kr==null)return "";for(var cnt=0;cnt<Kr.length;cnt++){
        c=Kr.charCodeAt(cnt);if(c>96&&c<123||c>64&&c<91||c==32||c>47&&c<58||c==46||c==44||c==45||c==95)EncodeHtml=EncodeHtml+String.fromCharCode(c);else EncodeHtml=EncodeHtml+"&#"+c+";";
    }
    return EncodeHtml;
}
function OutputEncoder_EncodeHtmlAttribute(Lr){
    var c;var EncodeHtmlAttribute="";if(Lr==null)return "";for(var cnt=0;cnt<Lr.length;cnt++){
        c=Lr.charCodeAt(cnt);if(c>96&&c<123||c>64&&c<91||c>47&&c<58||c==46||c==44||c==45||c==95)EncodeHtmlAttribute=EncodeHtmlAttribute+String.fromCharCode(c);else EncodeHtmlAttribute=EncodeHtmlAttribute+"&#"+c+";";
    }
    return EncodeHtmlAttribute;
}
function OutputEncoder_EncodeXml(Mr){
    return OutputEncoder_EncodeHtml(Mr);
}
function OutputEncoder_EncodeXmlAttribute(Nr){
    return OutputEncoder_EncodeHtmlAttribute(Nr);
}
function OutputEncoder_EncodeJs(Or){
    var c;var EncodeJs="";if(Or==null)return "";for(var cnt=0;cnt<Or.length;cnt++){
        c=Or.charCodeAt(cnt);if(c>96&&c<123||c>64&&c<91||c==32||c>47&&c<58||c==46||c==44||c==45||c==95)EncodeJs=EncodeJs+String.fromCharCode(c);else{
            if(c>127)EncodeJs=EncodeJs+"\\u"+OutputEncoder_TwoByteHex(c);else EncodeJs=EncodeJs+"\\x"+OutputEncoder_SingleByteHex(c);
        }
        
    }
    return "'"+EncodeJs+"'";
}
function OutputEncoder_EncodeVbs(Pr){
    var c;var EncodeVbs="";var bInQuotes=false;if(Pr==null)return "";for(var cnt=0;cnt<Pr.length;cnt++){
        c=Pr.charCodeAt(cnt);if(c>96&&c<123||c>64&&c<91||c==32||c>47&&c<58||c==46||c==44||c==45||c==95){
            if(!bInQuotes){
                EncodeVbs=EncodeVbs+"&\"";bInQuotes=true;
            }
            EncodeVbs=EncodeVbs+String.fromCharCode(c);
        }
        else{
            if(bInQuotes){
                EncodeVbs=EncodeVbs+"\"";bInQuotes=false;
            }
            EncodeVbs=EncodeVbs+"&chrw("+c+")";
        }
        
    }
    if(EncodeVbs.charAt(0)=="&")EncodeVbs=EncodeVbs.substring(1);if(EncodeVbs.length==0)EncodeVbs="\"\"";if(bInQuotes)EncodeVbs=EncodeVbs+"\"";return EncodeVbs;
}
function OutputEncoder_AsUrl(Qr){
    if(Qr==null)return "";if(Qr.search(/^(?:http|https|ftp):\/\/[a-zA-Z0-9\.\-]+(?:\:\d{1,5})?(?:[A-Za-z0-9\.\;\:\@\&\=\+\$\,\?\/]|%u[0-9A-Fa-f]{4}|%[0-9A-Fa-f]{2} )*$/i))throw "Unsanitized value passed to AsUrl";return Qr;
}
function OutputEncoder_QualifyUrl(Rr){
    if(Rr==null)return "";if(Rr.search(/^(?:http|https|ftp):\/\//i)){
        if(document.location.protocol=="HTTPS")return "https://"+document.location.hostname+OutputEncoder_QualifyUrl_MakePath(Rr);else return "http://"+document.location.hostname+OutputEncoder_QualifyUrl_MakePath(Rr);
    }
    else return Rr;
}
function OutputEncoder_QualifyUrl_MakePath(Sr){
    if(Sr==null)return "";if(!Sr.search(/^[\/\\]/))return Sr;var re=/^(\/(?:.*\/|))(?:[^\/\\]*\.\w+|\w*)$/;if(!document.location.pathname.search(re)){
        var path=re.exec(document.location.pathname);return path[1]+Sr;
    }
    return "/"+Sr;
}
function OutputEncoder_AsNumeric(Tr){
    if(Tr==null)return "";if(isNaN(parseFloat(Tr)))throw "IOSec.AsNumeric(): Error input ["+Tr+"] not a valid number.";return Tr;
}
function OutputEncode_TruncateUrlSafe(Ur,Vr,Wr){
    if(Ur.length<=Vr)return Ur;var strEncNotification="";if(Wr&&Wr.length>0){
        strEncNotification=OutputEncoder_EncodeUrl(Wr);Vr-=strEncNotification.length;
    }
    var Ur=Ur.substring(0,Vr);for(var ii=1;ii<6;ii++){
        if(Ur.charAt(Vr-ii)=="%"){
            Ur=Ur.substring(0,Vr-ii);break;
        }
        
    }
    return Ur+strEncNotification;
}
function OutputEncode_EncodeUrlDelims(Xr,Yr){
    if(!Xr)return Yr;var c;var d;var EncodeUrl="";for(var cnt=0;cnt<Yr.length;cnt++){
        c=Yr.charCodeAt(cnt);if(37==c){
            EncodeUrl=EncodeUrl+"%"+OutputEncoder_SingleByteHex(c);continue;
        }
        var encodedCharacter=Yr.charAt(cnt);for(var dcnt=0;dcnt<Xr.length;dcnt++){
            d=Xr.charCodeAt(dcnt);if(d==c){
                if(c>127)encodedCharacter="%u"+OutputEncoder_TwoByteHex(c);else encodedCharacter="%"+OutputEncoder_SingleByteHex(c);break;
            }
            
        }
        EncodeUrl+=encodedCharacter;
    }
    return EncodeUrl;
}
function OutputEncoder_EncodeUrl(Zr){
    if(Zr==null)return "";var c;var EncodeUrl="";for(var cnt=0;cnt<Zr.length;cnt++){
        c=Zr.charCodeAt(cnt);if(c>96&&c<123||c>64&&c<91||c>47&&c<58||c==46||c==45||c==95)EncodeUrl=EncodeUrl+String.fromCharCode(c);else{
            if(c>127)EncodeUrl=EncodeUrl+"%u"+OutputEncoder_TwoByteHex(c);else EncodeUrl=EncodeUrl+"%"+OutputEncoder_SingleByteHex(c);
        }
        
    }
    return EncodeUrl;
}
function OutputEncoder_SingleByteHex(as){
    if(as==null)return "";var SingleByteHex=as.toString(16);for(var cnt=SingleByteHex.length;cnt<2;cnt++){
        SingleByteHex="0"+SingleByteHex;
    }
    return SingleByteHex;
}
function OutputEncoder_TwoByteHex(bs){
    if(bs==null)return "";var TwoByteHex=bs.toString(16);for(var cnt=TwoByteHex.length;cnt<4;cnt++){
        TwoByteHex="0"+TwoByteHex;
    }
    return TwoByteHex;
}
function OutputEncoder(){
    this.EncodeHtml=OutputEncoder_EncodeHtml;this.EncodeHtmlAttribute=OutputEncoder_EncodeHtmlAttribute;this.EncodeXml=OutputEncoder_EncodeXml;this.EncodeXmlAttribute=OutputEncoder_EncodeXmlAttribute;this.EncodeJs=OutputEncoder_EncodeJs;this.EncodeVbs=OutputEncoder_EncodeVbs;this.AsNumeric=OutputEncoder_AsNumeric;this.EncodeUrl=OutputEncoder_EncodeUrl;this.EncodeUrlDelims=OutputEncode_EncodeUrlDelims;this.TruncateUrlSafe=OutputEncode_TruncateUrlSafe;this.SingleByteHex=OutputEncoder_SingleByteHex;this.TwoByteHex=OutputEncoder_TwoByteHex;this.AsUrl=OutputEncoder_AsUrl;this.QualifyUrl=OutputEncoder_QualifyUrl;
}
var IOSec=new OutputEncoder();function VE_Panel(cs,x,y,es,gs,hs,js,ks,ls,ms,ns,os,ps){
    this.index=0;this.x=x;this.y=y;this.width=es;this.height=gs;this.dynamicHeightMax=250;this.color=hs;this.toolbarHeight=20;this.footerHeight=20;this.min=false;this.visible=true;this.onTitleClick=null;this.onCloseClick=null;this.onMaximize=null;var el=VE_Panel._CreateElement("div",cs,"VE_Panel_el",js);this.el=el;this.titleDisabled=false;this.title=document.createElement("div");this.title.id=cs+"_title";this.title.className="VE_Panel_title";this.title.appendChild(document.createElement("h1"));this.title.onclick=VE_Panel._OnTitleClick;el.appendChild(this.title);this.SetTitle(ks);this.closeboxDisabled=false;this.cb=VE_Panel._CreateElement("a",cs+"_cb","VE_Panel_cb VE_Panel_cb_"+hs,js+1);this.cb.onclick=VE_Panel._OnCloseClick;this.cb.unselectable="on";el.appendChild(this.cb);this.tb=VE_Panel._CreateElement("div",cs+"_tb","VE_Panel_tb VE_Panel_tb_"+hs,js+1);this.tb.unselectable="on";el.appendChild(this.tb);this.body=VE_Panel._CreateElement("div",cs+"_body","VE_Panel_body",js+1);this.body.innerHTML=ls;el.appendChild(this.body);this.foot=VE_Panel._CreateElement("div",cs+"_foot","VE_Panel_foot VE_Panel_foot_"+hs,js+1);this.foot.innerHTML=ms;this.foot.unselectable="on";el.appendChild(this.foot);this.Resize();if(!os)this.SetOpacity(90);VE_Panel.panels.push(this);if(!ps)ps=document.body;ps.appendChild(el);
}
VE_Panel.panels=new Array();VE_Panel.shadowThickness=3;VE_Panel._CreateElement=function(qs,rs,ss,ts){
    var el=document.createElement(qs);el.id=rs;el.className=ss;el.style.zIndex=ts;return el;
}
;VE_Panel._PositionElement=function(us,x,y,w,h){
    us.style.top=y+"px";us.style.left=x+"px";us.style.width=w+"px";us.style.height=h+"px";
}
;VE_Panel.prototype.SetPosition=function(x,y,w,h){
    this.x=x;this.y=y;this.width=w;this.height=h;
}
;VE_Panel.prototype.SetToolbarSize=function(vs){
    this.toolbarHeight=vs;var d=eval(vs)>0?"block":"none";this.tb.style.display=d;this.Resize();
}
;VE_Panel.prototype.SetFooterSize=function(ws){
    this.footerHeight=ws;var d=eval(ws)>0?"block":"none";this.foot.style.display=d;this.Resize();
}
;VE_Panel.prototype.Resize=function(){
	if (typeof(footer) == "undefined" || typeof(header) == "undefined") { return; }
	var taskAreaHeight=document.body.clientHeight-header.offsetHeight-footer.offsetHeight;
	if(document.all){
        var css=footer.currentStyle;if(css&&typeof css!="undefined"){
            var strBottom=css["bottom"];if(strBottom&&typeof strBottom!="undefined"){
                var nBottom=Math.abs(parseInt(strBottom));taskAreaHeight+=nBottom;
            }
            
        }
        
    }
    if(taskAreaHeight>=0&&typeof taskAreaHeight=="number")taskArea_data.style.height=taskAreaHeight+"px";if(this.el.id=="contextMenu"||this.el.id=="scratchpad"||this.el.id=="annotationPanel"||this.el.id=="annotationPopup"||this.el.id=="searchPopup"||this.el.id=="help"){
        if(this.height!="auto"&&typeof this.height=="number")this.el.style.height=eval(this.height)+"px";if(this.width!="auto"&&typeof this.width=="number")this.el.style.width=eval(this.width)+"px";if(this.x!="auto"&&typeof this.x=="number")this.el.style.left=eval(this.x)+"px";if(this.y!="auto"&&typeof this.y=="number")this.el.style.top=eval(this.y)+"px";
    }
    else{
        var count=taskArea.getCount();var titleMargin=3;var titleHeight=this.title.offsetHeight+titleMargin;var bodyHeight=taskArea_data.offsetHeight-titleHeight*count-this.tb.offsetHeight-this.foot.offsetHeight;if(bodyHeight>=0&&typeof bodyHeight=="number")this.body.style.height=bodyHeight+"px";
    }
    
}
;VE_Panel.prototype.SetHeightToFit=function(){
    var contentid=this.id+"_body_table";var content=document.getElementById(contentid);if(!content)return false;this.height=0;var width=Math.max(eval(this.width),100);if(content.offsetWidth>width-14)this.height+=scrollbarWidth;this.height+=(this.titleDisabled?14:35);this.height+=this.toolbarHeight;this.height+=content.offsetHeight;this.height+=this.footerHeight;this.height=Math.min(this.dynamicHeightMax,this.height);
}
;VE_Panel.prototype.DisableClosebox=function(){
    if(this.closeboxDisabled)return;this.closeboxDisabled=true;this.el.removeChild(this.cb);
}
;VE_Panel.prototype.EnableClosebox=function(){
    if(!this.closeboxDisabled)return;this.closeboxDisabled=false;this.el.insertBefore(this.cb,this.tb);
}
;VE_Panel.prototype.DisableTitle=function(){
    if(this.titleDisabled)return;this.titleDisabled=true;this.el.removeChild(this.cb);this.el.removeChild(this.title);
}
;VE_Panel.prototype.EnableTitle=function(){
    if(!this.titleDisabled)return;this.titleDisabled=false;this.el.insertBefore(this.cb,this.tb);this.el.insertBefore(this.title,this.cb);
}
;VE_Panel.prototype.SetTitle=function(c){
    var txtNode=document.createTextNode(c);var h1=this.title.firstChild;if(h1){
        if(h1.firstChild)h1.replaceChild(txtNode,h1.firstChild);else h1.appendChild(txtNode);
    }
    
}
;VE_Panel.prototype.SetToolbar=function(c){
    this.tb.innerHTML=c;
}
;VE_Panel.prototype.SetBody=function(c){
    this.body.innerHTML=c;
}
;VE_Panel.prototype.SetDynamicBody=function(c){
    this.body.innerHTML="<table id=\""+this.id+"_body_table\"><tr><td>"+c+"</td></tr></table>";
}
;VE_Panel.prototype.SetFooter=function(c){
    this.foot.innerHTML=c;
}
;VE_Panel.prototype.SetOpacity=function(o){
    if(o>=100)o=99.99;with(this.el.style){
        filter="alpha(opacity:"+o+")";o*=0.01;KHTMLOpacity=o;MozOpacity=o;opacity=o;
    }
    
}
;VE_Panel.prototype.SetColor=function(c){
    this.color=c;this.title.className="VE_Panel_title VE_Panel_title_"+c;this.foot.className="VE_Panel_foot VE_Panel_foot_"+c;this.cb.className="VE_Panel_cb VE_Panel_cb_"+c;
}
;VE_Panel.prototype.Minimize=function(){
    this.el.className=" VE_Panel_el_minimized";
}
;VE_Panel.prototype.Maximize=function(){
    this.el.className="VE_Panel_el";if(this.onMaximize)this.onMaximize(this._CreateEvent());this.Resize();
}
;VE_Panel.prototype.Show=function(){
    this.el.style.display="block";this.visible=true;
}
;VE_Panel.prototype.Hide=function(){
    this.el.style.display="none";this.visible=false;
}
;VE_Panel.prototype.Destroy=function(){
    this.el.parentNode.removeChild(this.el);var p=VE_Panel.panels;for(var i=0;i<p.length;i++){
        if(p[i]==this){
            p.splice(i,1);return;
        }
        
    }
    this.onTitleClick=null;this.onCloseClick=null;this.onMaximize=null;
}
;function VE_PanelEvent(xs){
    this.srcPanel=xs;
}
VE_Panel.prototype._CreateEvent=function(){
    return new VE_PanelEvent(this);
}
;VE_Panel._OnTitleClick=function(e){
    if(!e)e=window.event;var t=GetTarget(e);var p=VE_Panel.panels;for(var i=0;i<p.length;i++){
        if(p[i].title==t||p[i].title==t.parentNode){
            if(p[i].onTitleClick)p[i].onTitleClick(p[i]._CreateEvent());return;
        }
        
    }
    
}
;VE_Panel._OnCloseClick=function(e){
    if(!e)e=window.event;var c=GetTarget(e);var p=VE_Panel.panels;for(var i=0;i<p.length;i++){
        if(p[i].cb==c){
            if(p[i].onCloseClick)p[i].onCloseClick(p[i]._CreateEvent());return;
        }
        
    }
    
}
;function VE_SearchResult(ys,zs,As,Bs,Cs,Ds,Es,Fs,Gs,Hs,Is,Js){
    this.id=ys;this.name=zs;this.description=As;this.phone=Bs;this.rating=Cs;this.type=Ds;this.latitude=Es;this.longitude=Fs;this.pushPin=null;this.pinId=null;this.keywords=Is;this.infoUrl=Gs;this.photoUrl=Hs;this.country=Js;
}
VE_SearchResult.prototype.Equals=function(Ks){
    if(Ks==null||Ks=="undefined")return false;try{
        var flag=this.name==Ks.name&&this.description==Ks.description&&this.phone==Ks.phone&&this.rating==Ks.rating&&this.type==Ks.type&&this.latitude==Ks.latitude&&this.longitude==Ks.longitude;return flag;
    }
    catch(ex){
        return false;
    }
    
}
;VE_SearchResult.prototype.GetSerializedId=function(){
    switch(this.type){
        case "al":return "";case "adr":return "adr."+this.name;case "aN":return VE_AnnotationData.SerializeAnnotation(this.pinId);default:return this.type+"."+this.id.toString();
    }
    
}
;function VE_SearchResultCategory(Ls,Ms){
    this.id=Ls;this.name=Ms;
}
function Ad(Ns,Os,Ps,Qs,Rs){
    this.title=Ns;this.url=Os;this.description=Ps;this.latitude=Qs;this.longitude=Rs;
}
Ad.prototype.ToHtml=function(){
    var li="<li><a href = \""+this.url+"\" target = \"_blank\">"+IOSec.EncodeHtml(this.title)+"</a>"+"$AdDescription$"+"</li>";if(this.description&&this.description.length>0)li=li.replace("$AdDescription$","<p>"+IOSec.EncodeHtml(this.description)+"</p>");return li;
}
;Msn.VE.DirectionsDecoder=function(){
    var encodedCoordinateLength=4;var encodedCoordinateBase=1000000;function Ss(Ts,Us,Vs,Ws){
        if(!Ts||Ts.length<Us)return [];var length=Ts.length-Ts.length%Us;var numbers=new Array();var negative=false;var currentNumber=0;var lastByteIndex=Us-1;for(var i=0;i<length;i++){
            var currentCharCode=Ts.charCodeAt(i);var byteIndex=i%Us;if(Ws&&byteIndex==0){
                negative=currentCharCode&128;currentCharCode&=127;
            }
            currentNumber|=currentCharCode;if(byteIndex==lastByteIndex){
                var translatedNumber=currentNumber/Vs;numbers.push(negative?-translatedNumber:translatedNumber);currentNumber=0;negative=false;
            }
            else currentNumber<<=8;
        }
        return numbers;
    }
    function Xs(Ys){
        return Ss(Ys,encodedCoordinateLength,encodedCoordinateBase,true);
    }
    this.DecodeCoordinatesString=Xs;
}
;var L_GraphicsInitError_Text="Your Web browser does not support SVG or VML. Some graphics features may not function properly.";RegisterNamespaces("Msn.Drawing");Msn.Drawing.Exception=function(Zs){
    this.message=Zs;this.name="Msn.Drawing.Exception";
}
;Msn.Drawing.Exception.prototype.toString=function(){
    return this.name+": "+this.message;
}
;Msn.Drawing.Graphic=function(){
    
}
;Msn.Drawing.Graphic.CreateGraphic=function(at){
    if(document.all)return new Msn.Drawing.VMLGraphic(at);else{
        var major=0;var minor=0;var versionRegex=new RegExp("Firefox/(.*)");var match=versionRegex.exec(navigator.userAgent);if(match[1]){
            var versionNumbers=match[1].split(".");if(versionNumbers){
                major=versionNumbers[0];minor=versionNumbers[1];if(parseInt(major)>0&&parseInt(minor)>=5)return new Msn.Drawing.SVGGraphic(at);
            }
            
        }
        throw new Msn.Drawing.Exception(L_GraphicsInitError_Text);
    }
    
}
;Msn.Drawing.Point=function(x,y){
    this.x=x?x:0;this.y=y?y:0;
}
;Msn.Drawing.Point.prototype.toString=function(){
    return this.x+","+this.y;
}
;Msn.Drawing.PolyLine=function(bt){
    this.id=0;this.points=bt?bt:new Array();this.AddPoint=function(ct){
        this.points.push(ct);
    }
    ;
}
;Msn.Drawing.PolyLine.prototype.toString=function(){
    return this.points.join(" ");
}
;Msn.Drawing.Stroke=function(){
    this.width=1;this.linecap="round";this.opacity=1;this.linejoin="miter";this.color=new Msn.Drawing.Color(255,255,255,1);
}
;Msn.Drawing.Color=function(r,g,b,a){
    this.R=r?r:0;this.G=g?g:0;this.B=b?b:0;this.A=a?a:1;this.ToHexString=function(){
        return "#"+Number(this.R).toString(16)+(this.R<16?"0":"")+Number(this.G).toString(16)+(this.G<16?"0":"")+Number(this.B).toString(16)+(this.B<16?"0":"");
    }
    ;
}
;Msn.Drawing.VMLGraphic=function(et){
    var graphicsElm=et;var color=new Msn.Drawing.Color(255,0,0,1);var stroke=new Msn.Drawing.Stroke();var zIndex=1;var parentLeft=et.offsetLeft;var parentTop=et.offsetTop;et.unselectable="on";var currentShapes=new Array();this.DrawPolyline=function(gt){
        var element=null;element=document.createElement("v:polyline");element.id=gt.id;element.unselectable="on";element.style.position="absolute";element.points=gt.points.join(" ");element.style.zIndex=zIndex;element.filled="false";graphicsElm.appendChild(element);if(stroke){
            var strokeElm=document.createElement("v:stroke");strokeElm.unselectable="on";strokeElm.setAttribute("weight",stroke.width);strokeElm.setAttribute("joinstyle",stroke.linejoin);strokeElm.setAttribute("color",stroke.color.ToHexString());strokeElm.setAttribute("endcap",stroke.linecap);strokeElm.setAttribute("opacity",stroke.color.A.toString());element.appendChild(strokeElm);
        }
        currentShapes.push(element);
    }
    ;this.SetColor=function(ht){
        color=ht;
    }
    ;this.SetStroke=function(jt){
        stroke=jt;
    }
    ;this.SetZIndex=function(kt){
        zIndex=kt;
    }
    ;this.Clear=function(){
        var currentShape=null;while(currentShape=currentShapes.pop()){
            graphicsElm.removeChild(currentShape);currentShape=null;
        }
        
    }
    ;this.Destroy=function(){
        this.Clear();graphicsElm=null;
    }
    ;
}
;Msn.Drawing.SVGGraphic=function(lt){
    var divElm=document.createElement("div");divElm.id="svgCanvas";divElm.style.position="absolute";var graphicsElm=null;var zIndex=1;divElm.style.top=lt.offsetTop+"px";divElm.style.left=lt.offsetLeft+"px";lt.appendChild(divElm);var currentShapes=new Array();var color=new Msn.Drawing.Color(255,0,0,1);var stroke=new Msn.Drawing.Stroke();divElm.style.width="0px";divElm.style.height="0px";graphicsElm=document.createElementNS("http://www.w3.org/2000/svg","svg");graphicsElm.setAttribute("height","100%");graphicsElm.setAttribute("width","100%");divElm.appendChild(graphicsElm);function mt(){
        var startSearchNode=lt;while(startSearchNode&&startSearchNode.offsetWidth==0){
            startSearchNode=startSearchNode.parentNode;
        }
        divElm.style.position="absolute";divElm.style.width=startSearchNode.offsetWidth+"px";divElm.style.height=startSearchNode.offsetHeight+"px";
    }
    function nt(ot){
        if(!ot||!ot.points||ot.points.length<2)return;var points=ot.points;var pointsLen=points.length;var minX=0;var maxX=0;var minY=0;var maxY=0;var maxWidth=0;var maxHeight=0;minX=Math.min(points[0].x,points[1].x);maxX=Math.max(points[0].x,points[1].x);minY=Math.min(points[0].y,points[1].y);maxY=Math.max(points[0].y,points[1].y);maxWidth=Math.max(maxX-minX,maxWidth);maxHeight=Math.max(maxY-minX,maxHeight);for(var i=2;i<pointsLen;++i){
            minX=Math.min(points[i].x,minX);maxX=Math.max(points[i].x,maxX);minY=Math.min(points[i].y,minY);maxY=Math.max(points[i].y,maxY);maxWidth=Math.max(maxX-minX,maxWidth);maxHeight=Math.max(maxY-minY,maxHeight);
        }
        divElm.style.top=minY+"px";divElm.style.left=minX+"px";divElm.style.width=maxWidth+"px";divElm.style.height=maxHeight+"px";graphicsElm.setAttribute("width",maxWidth+"");graphicsElm.setAttribute("height",maxHeight+"");for(var i=0;i<pointsLen;++i){
            points[i].x-=minX;points[i].y-=minY;
        }
        
    }
    this.DrawPolyline=function(pt){
        nt(pt);var line=document.createElementNS("http://www.w3.org/2000/svg","polyline");line.setAttribute("points",pt.toString());line.setAttribute("fill","none");line.setAttribute("id",pt.id);if(stroke){
            line.setAttribute("stroke",stroke.color.ToHexString());line.setAttribute("stroke-width",stroke.width);line.setAttribute("stroke-opacity",stroke.color.A);
        }
        graphicsElm.appendChild(line);currentShapes.push(line);
    }
    ;this.SetColor=function(qt){
        color=qt;
    }
    ;this.SetStroke=function(rt){
        stroke=rt;
    }
    ;this.SetZIndex=function(st){
        zIndex=st;divElm.style.zIndex=zIndex;
    }
    ;this.Destroy=function(){
        this.Clear();
    }
    ;this.Clear=function(){
        var currentShape=null;while(currentShape=currentShapes.pop()){
            graphicsElm.removeChild(currentShape);currentShape=null;
        }
        
    }
    ;
}
;var HelpHistory=new Array();function VE_Help(){
    
}
VE_Help.helpZIndex=31;VE_Help.introZIndex=31;VE_Help.introPanel=null;VE_Help.helpPanel=null;VE_Help.margins=110;VE_Help.CreateHelpPanel=function(){
    var helpFrame="<iframe id=\"helpFrame\" src=\"about:blank\" width=\"100%\" height=\"100%\" allowtransparency=\"true\" frameborder=\"0\"></iframe>";var p=new VE_Panel("help",220,160,"windowWidth-430","windowHeight-190","blue",VE_Help.helpZIndex,L_Help_Text,helpFrame,"");p.body.className="VE_Panel_body_help";p.Hide();p.SetToolbarSize(0);p.SetFooterSize(0);p.SetOpacity(95);p.onCloseClick=function(e){
        VE_Help.ClosePanel();
    }
    ;VE_Help.helpPanel=p;
}
;VE_Help.EnablePreventLayer=function(){
    return;var preventLayer=document.getElementById("__preventLayer__");if(!preventLayer)preventLayer=document.createElement("div");preventLayer.id="__preventLayer__";preventLayer.className="preventLayer";document.body.appendChild(preventLayer);
}
;VE_Help.DisablePreventLayer=function(){
    return;var preventLayer=document.getElementById("__preventLayer__");if(preventLayer)document.body.removeChild(preventLayer);
}
;VE_Help.CreateIntroPanel=function(){
    var db=map.GetDashboard();var introFrame="<iframe id=\"introFrame\" src="+welcomeUrl+" width=\"100%\" height=\"100%\" allowtransparency=\"true\" frameborder=\"0\"></iframe>";var p=new VE_Panel("intro",0,0,"auto","auto","welcomePanel",VE_Help.introZIndex,L_Welcome_Text,introFrame,"","",true,taskArea_data);p.el.className="welcomePanel";p.body.className="VE_Panel_body_help";pseudoHover(p.title);p.SetToolbarSize(0);p.SetFooterSize(0);p.onTitleClick=function(e){
        taskArea.setCurrent(this);
    }
    ;p.onCloseClick=function(e){
        var parent=this.el.parentElement;if(parent)parent.removeChild(this.el);taskArea.removeItem(this);VE_Help.introPanel=null;
    }
    ;p.onMaximize=function(e){
        resetWhatBox();
    }
    ;taskArea.addItem(p);VE_Help.introPanel=p;
}
;VE_Help.Open=function(tt,ut){
    VE_Help.EnablePreventLayer();VE_Help.helpPanel.Show();VE_Help.helpPanel.SetTitle(tt);VE_Help.helpPanel.SetBody("<iframe id = \"helpFrame\" src = \"about:blank\" width = \"100%\" allowtransparency = \"true\" scrolling = \"auto\" frameborder = \"0\"></iframe>");var helpFrame=document.getElementById("helpFrame");helpFrame.src=ut;VE_Help.Redraw();
}
;VE_Help.Redraw=function(vt){
    var panel=VE_Help.helpPanel;if(!panel)return;if(!vt){
        var taskAreaWidth=taskArea_transparency?taskArea_transparency.offsetWidth:0;var scratchPadWidth=scratchPad?scratchPad.getElement().offsetWidth:0;if(document.body.clientWidth>800)var width=document.body.clientWidth-taskAreaWidth-scratchPadWidth-VE_Help.margins;else var width=document.body.clientWidth-taskAreaWidth-scratchPadWidth-50;var height=document.body.clientHeight-header.offsetHeight-mapActionBar.offsetHeight-VE_Help.margins;if(width>0)panel.width=width;if(height>0)panel.height=height;
    }
    panel.x=278;panel.Resize();
}
;VE_Help.CloseIntro=function(){
    if(VE_Help.introPanel)VE_Help.introPanel.Hide();
}
;VE_Help.OpenIntro=function(){
    toggleTaskArea(true);if(!VE_Help.introPanel)VE_Help.CreateIntroPanel();else taskArea.setCurrent(VE_Help.introPanel);VE_Analytics.Log("VE | Welcome Pane","Welcome");
}
;VE_Help.ClosePanel=function(){
    if(VE_Help.helpPanel){
        VE_Help.helpPanel.Hide();VE_Help.DisablePreventLayer();
    }
    
}
;function SanitizeHtmlString(s){
    if(!s||typeof s!="string")return s;return IOSec.EncodeHtml(s);
}
function GetMousePosX(e){
    var posX=0;if(e.pageX)posX=e.pageX;else{
        if(e.clientX)posX=e.clientX+document.body.scrollLeft;
    }
    return posX;
}
function GetMousePosY(e){
    var posY=0;if(e.pageY)posY=e.pageY;else{
        if(e.clientY)posY=e.clientY+document.body.scrollTop;
    }
    return posY;
}
function GetTarget(e){
    if(!e)var e=window.event;var eventTarget;if(e.srcElement)eventTarget=e.srcElement;else{
        if(e.target)eventTarget=e.target;
    }
    if(eventTarget.nodeType==3)eventTarget=targ.parentNode;return eventTarget;
}
function SelectText(wt,xt,yt){
    if(!wt)return;if(wt.createTextRange){
        var textRange=wt.createTextRange();textRange.moveStart("character",xt);textRange.moveEnd("character",yt);textRange.select();
    }
    else{
        if(wt.setSelectionRange)wt.setSelectionRange(xt,yt);
    }
    
}
function GetElementLeftPosition(zt){
    var offsetTrail=document.getElementById(zt);var offsetLeft=0;while(offsetTrail){
        offsetLeft+=offsetTrail.offsetLeft;offsetTrail=offsetTrail.offsetParent;
    }
    if(navigator.userAgent.indexOf("Mac")!=-1&&typeof document.body.leftMargin!="undefined")offsetLeft+=document.body.leftMargin;return offsetLeft;
}
function GetElementTopPosition(At){
    var offsetTrail=document.getElementById(At);var offsetTop=0;while(offsetTrail){
        offsetTop+=offsetTrail.offsetTop;offsetTrail=offsetTrail.offsetParent;
    }
    if(navigator.userAgent.indexOf("Mac")!=-1&&typeof document.body.topMargin!="undefined")offsetTop+=document.body.topMargin;return offsetTop;
}
function SelectedTextLength(Bt){
    if(!Bt)return 0;if(Bt.document){
        var selectedTextObj=Bt.document.selection.createRange();return selectedTextObj.text.length;
    }
    else{
        var selStart=Bt.selectionStart;var selEnd=Bt.selectionEnd;return selEnd-selStart;
    }
    
}
function VEParameter(Ct,Dt){
    this.Name=Ct;this.Value=Dt;
}
VEParameter.prototype.Name=this.name;VEParameter.prototype.Value=this.value;function VENetwork(Et,Ft,Gt){
    if(Et!=null&&Et!="undefined")this.ServiceUrl=Et;if(Ft!=null&&Ft!="undefined")Msn.VE.API.Globals.veonbegininvokeevent=Ft;if(Gt!=null&&Gt!="undefined")Msn.VE.API.Globals.veonendinvokeevent=Gt;
}
function BeginInvoke(Ht,It,Jt,Kt){
    if(this.ServiceUrl==null||this.ServiceUrl=="undefined"||this.ServiceUrl.length==0)throw new VEException("VENetwork:BeginInvoke","err_noserviceurl",L_noserviceurl_text);if(Msn.VE.API.Globals.veonbegininvokeevent)Msn.VE.API.Globals.veonbegininvokeevent();var executionid=VENetwork.GetExecutionID();if(It){
        var methodurl=this.ServiceUrl+"?";for(var i=0;i<It.length;i++){
            methodurl=methodurl+It[i].Name;methodurl=methodurl+"=";methodurl=methodurl+It[i].Value;methodurl=methodurl+"&";
        }
        
    }
    else var methodurl=this.ServiceUrl;if(Msn.VE.API.Globals.vedebug)alert(methodurl);var elScript=document.createElement("script");elScript.type="text/javascript";elScript.language="javascript";elScript.id=executionid;elScript.src=methodurl;if(navigator.userAgent.indexOf("IE")>=0)elScript.onreadystatechange=function(){
        if(elScript&&("loaded"==elScript.readyState||"complete"==elScript.readyState)){
            elScript.onreadystatechange=null;EndInvoke(Kt,Jt,Ht,elScript,executionid);
        }
        
    }
    ;else elScript.onload=function(){
        elScript.onload=null;EndInvoke(Kt,Jt,Ht,elScript,executionid);
    }
    ;VENetwork.GetAttachTarget().appendChild(elScript);
}
function EndInvoke(Lt,Mt,Nt,Ot,Pt){
    var objects=null;if(Nt)eval("objects = "+Nt+"();");document.getElementsByTagName("head")[0].removeChild(Ot);Ot=null;if(Mt!=null&&Mt!="undefined")Mt(objects,Lt);if(Msn.VE.API.Globals.veonendinvokeevent)Msn.VE.API.Globals.veonendinvokeevent();
}
VENetwork.GetExecutionID=function(){
    var date=new Date();var id=Date.UTC(date.getFullYear(),date.getMonth(),date.getDate(),date.getHours(),date.getMinutes(),date.getSeconds(),date.getMilliseconds());id+=Math.round(Math.random()*1000000);return id;
}
;function GetXmlHttp(){
    var xmlhttp=null;try{
        xmlhttp=new ActiveXObject("Msxml2.XMLHTTP");
    }
    catch(ex){
        try{
            xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
        }
        catch(ex){
            xmlhttp=null;
        }
        
    }
    if(!xmlhttp&&typeof XMLHttpRequest!="undefined")xmlhttp=new XMLHttpRequest();return xmlhttp;
}
VENetwork.AttachStyleSheetCallback=function(Qt){
    if(Qt)Qt();
}
;VENetwork.AttachStyleSheet=function(Rt,St){
    if(Rt==null||Rt=="undefined"||Rt.length==0)throw new VEException("VENetwork:AttachStylesheet","err_nostylesurl",L_nostylesurl_text);elStyle=document.createElement("link");elStyle.rel="stylesheet";elStyle.type="text/css";elStyle.rev="stylesheet";elStyle.id=VENetwork.GetExecutionID();elStyle.href=Rt;VENetwork.GetAttachTarget().appendChild(elStyle);if(navigator.userAgent.indexOf("IE")>=0)elStyle.onreadystatechange=function(){
        if(elStyle&&("loaded"==elStyle.readyState||"complete"==elStyle.readyState)){
            elStyle.onreadystatechange=null;VENetwork.AttachStyleSheetCallback(St);
        }
        
    }
    ;else VENetwork.AttachStyleSheetCallback(St);return;
}
;VENetwork.DownloadScriptCallback=function(Tt){
    if(Tt)Tt();
}
;VENetwork.DownloadScript=function(Ut,Vt){
    if(Ut==null||Ut=="undefined"||Ut.length==0)throw new VEException("VENetwork:DownloadScript","err_noscripturl",L_noscripturl_text);elScript=document.createElement("script");elScript.type="text/javascript";elScript.language="javascript";elScript.id=VENetwork.GetExecutionID();elScript.src=Ut;if(navigator.userAgent.indexOf("IE")>=0)elScript.onreadystatechange=function(){
        if(elScript&&("loaded"==elScript.readyState||"complete"==elScript.readyState)){
            elScript.onreadystatechange=null;VENetwork.DownloadScriptCallback(Vt);
        }
        
    }
    ;else elScript.onload=function(){
        elScript.onload=null;VENetwork.DownloadScriptCallback(Vt);
    }
    ;VENetwork.GetAttachTarget().appendChild(elScript);return;
}
;VENetwork.DownloadXml=function(Wt,Xt,Yt){
    var xmlhttp=GetXmlHttp();xmlhttp.open(Xt,Wt,true);xmlhttp.onreadystatechange=function(){
        if(xmlhttp.readyState==4){
            if(Yt)Yt(xmlhttp.responseXML);xmlhttp=null;
        }
        
    }
    ;xmlhttp.send(null);
}
;VENetwork.GetAttachTarget=function(){
    if(document.getElementsByTagName("head")[0]!=null)return document.getElementsByTagName("head")[0];else throw new VEException("VENetwork:cstr","err_noheadelement",L_noheadelement_text);
}
;VENetwork.prototype.BeginInvoke=BeginInvoke;VENetwork.prototype.EndInvoke=EndInvoke;function VEException(Zt,au,bu){
    this.source=Zt;this.name=au;this.message=bu;
}
VEException.prototype.Name=this.name;VEException.prototype.Source=this.source;VEException.prototype.Message=this.message;function VEValidator(){
    
}
VEValidator.ValidateFloat=function(cu,eu){
    var method="";if(arguments!=null&&arguments.caller!=null)method=VEValidator.GetCaller(arguments.caller);if(method=="")method="VEValidator.ValidateFloat";if(cu==null||cu=="undefined")throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",eu).replace("%2","float"));try{
        if(isNaN(parseFloat(cu)))throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",eu).replace("%2","float"));return true;
    }
    catch(err){
        throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",eu).replace("%2","float"));
    }
    
}
;VEValidator.ValidateInt=function(gu,hu){
    var method="";if(arguments!=null&&arguments.caller!=null)method=VEValidator.GetCaller(arguments.caller);if(method=="")method="VEValidator.ValidateInt";if(gu==null||gu=="undefined")throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",hu).replace("%2","int"));try{
        if(isNaN(parseInt(gu)))throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",hu).replace("%2","int"));return true;
    }
    catch(err){
        throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",hu).replace("%2","int"));
    }
    
}
;VEValidator.ValidateNonNull=function(ju,ku){
    var method="";if(arguments!=null&&arguments.caller!=null)method=VEValidator.GetCaller(arguments.caller);if(method=="")method="VEValidator.ValidateNonNull";if(ju==null||ju=="undefined")throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",ku).replace("%2","non null"));
}
;VEValidator.ValidateMapStyle=function(lu,mu){
    var method="";if(arguments!=null&&arguments.caller!=null)method=VEValidator.GetCaller(arguments.caller);if(method=="")method="VEValidator.ValidateMapStyle";if(lu==null||lu=="undefined")throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",mu).replace("%2","MapStyle"));if(lu=="r"||lu=="R"||lu=="a"||lu=="A"||lu=="o"||lu=="O"||lu=="h"||lu=="H")return true;throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",mu).replace("%2","MapStyle"));
}
;VEValidator.ValidateLayerType=function(nu,ou){
    var method="";if(arguments!=null&&arguments.caller!=null)method=VEValidator.GetCaller(arguments.caller);if(method=="")method="VEValidator.ValidateLayerType";if(nu==null||nu=="undefined")throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",ou).replace("%2","VELayerType"));if(nu==VELayerType.GeoRSS||nu==VELayerType.VECollection)return true;throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",ou).replace("%2","VELayerType"));
}
;VEValidator.ValidateObject=function(pu,qu,ru,su){
    var method="";if(arguments!=null&&arguments.caller!=null)method=VEValidator.GetCaller(arguments.caller);if(method=="")method="VEValidator.ValidateObject";if(pu==null||pu=="undefined")throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",qu).replace("%2","non null"));if(!ru.prototype.isPrototypeOf(pu))throw new VEException(method,"err_invalidargument",L_invalidargument_text.replace("%1",qu).replace("%2",su));
}
;VEValidator.GetCaller=function(tu){
    if(tu!=null||tu!=""){
        try{
            var s=tu.toString().match(/function (\w*)/)[1];
        }
        catch(err){
            s="";
        }
        if(s==null||s.length==0)return "";else return s;
    }
    else return "";
}
;function VEPushpin(uu,vu,wu,xu,yu,zu,Au,Bu){
    VEValidator.ValidateNonNull(uu,"pinId");VEValidator.ValidateNonNull(vu,"veLatLong");var self=this;this.IsInLayer=false;this.ID=uu;this.LatLong=vu;this.Title=xu;if(wu==null||wu=="undefined"||wu.length==0)this.Iconurl=Msn.VE.API.Constants.iconurl;else this.Iconurl=wu;this.Details=yu;if(zu==null||zu=="undefined"||zu.length==0)this.IconStyle="";else this.IconStyle=zu;if(Au==null||Au=="undefined"||Au.length==0)this.TitleStyle="VE_Pushpin_Popup_Title";else this.TitleStyle=Au;if(Bu==null||Bu=="undefined"||Bu.length==0)this.DetailsStyle="VE_Pushpin_Popup_Body";else this.DetailsStyle=Bu;if(window.ero==null||window.ero=="undefined")window.ero=ERO.getInstance();
}
VEPushpin.ShowDetailOnMouseOver=true;VEPushpin.OnMouseOverCallback=null;VEPushpin.prototype.Dispose=function(){
    this.DetailsStyle==null;this.TitleStyle=null;this.IconStyle=null;this.Details=null;this.IconUrl=null;this.Title=null;this.LatLong=null;this.ID=null;this.m_vemapcontrol=null;this.m_vemap=null;
}
;VEPushpin.Hide=function(Cu){
    VEMap.ValidateState();if(window.ero!=null){
        if(Cu=="undefined"||Cu==null)Cu=false;window.ero.hide(Cu);
    }
    
}
;VEPushpin.Show=function(Du,Eu,Fu,Gu,Hu,Iu,Ju,Ku){
    var mapInstance=VEMap._GetMapFromGUID(Du);if(mapInstance==null||mapInstance=="undefined")return;VEMap.ValidateState();var currentX=mapInstance.vemapcontrol.GetX(Gu)+mapInstance.GetLeft();var currentY=mapInstance.vemapcontrol.GetY(Fu)+mapInstance.GetTop();if(VEPushpin.ShowDetailOnMouseOver){
        var e=document.getElementById(Eu+"_"+mapInstance.GUID);if(e!=null&&e!="undefined"){
            window.ero.setBoundingArea(new Microsoft.Web.Geometry.Point(0,0),new Microsoft.Web.Geometry.Point(document.body.clientWidth,document.body.clientHeight));var eroContent="<p>";if(Hu.length>0)eroContent+="<div class=\""+Ju+"\">"+unescape(Hu)+"</div>";if(Iu.length>0)eroContent+="<div class=\""+Ku+"\">"+unescape(Iu)+"</div>";if(!document.all&&(Hu.length==0||Iu.length==0))eroContent+="<br/><br/>";eroContent+="</p>";window.ero.setContent(eroContent);window.ero.display(e);
        }
        
    }
    if(VEPushpin.OnMouseOverCallback!=null)VEPushpin.OnMouseOverCallback(currentX,currentY,Hu,unescape(Iu));
}
;function GetContent(){
    var pinId=this.ID+"_"+this.m_vemap.GUID;var content="<img class='"+this.IconStyle+"' src='"+this.Iconurl+"' id='"+pinId+"' ";var isTitleValid=this.Title!=null&&this.Title!="undefined"&&this.Title.length>0;var isDetailsValid=this.Details!=null&&this.Details!="undefined"&&this.Details.length>0;if(isTitleValid||isDetailsValid){
        content+=" onmouseout='VEPushpin.Hide();' onmousedown='VEPushpin.Hide(true);' onmouseover='VEPushpin.Show(\""+this.m_vemap.GUID+"\",\""+this.ID+"\","+this.LatLong.Latitude+","+this.LatLong.Longitude;if(isTitleValid)content+=", \""+escape(this.Title)+"\"";else content+=",\"\"";if(isDetailsValid)content+=", \""+escape(this.Details)+"\"";else content+=",\"\"";content+=",\""+this.TitleStyle+"\"";content+=",\""+this.DetailsStyle+"\"";content+=");' ";
    }
    content+="/>";return content;
}
VEPushpin.DisposeERO=function(){
    if(window.ero!=null&&window.ero!="undefined"){
        window.ero.destroy();window.ero=null;
    }
    
}
;VEPushpin.prototype._SetMapInstance=function(Lu){
    this.m_vemap=Lu;this.m_vemapcontrol=Lu.vemapcontrol;
}
;VEPushpin.prototype.GetContent=GetContent;function VE_Scratchpad(){
    
}
VE_Scratchpad.AddLocation=function(a,b,c){
    return;
}
;function VEFindResult(Mu,Nu,Ou,Pu,Qu){
    VEValidator.ValidateNonNull(Nu,"name");VEValidator.ValidateNonNull(Ou,"description");VEValidator.ValidateNonNull(Qu,"isSponsored");this.ID=Mu;this.Name=Nu;this.Description=Ou;this.LatLong=Pu;this.IsSponsored=Qu;
}
function VE_SearchManager(Ru){
    VEValidator.ValidateObject(Ru,"vemap",VEMap,"VEMap");this.m_vemap=Ru;var m_veLatLongFactory=new VELatLongFactory(new VELatLongFactorySpecFromMap(this.m_vemap));this.Initialize=function(){
        
    }
    ;this.Find=function(Su,Tu,Uu,Vu,Wu){
        VEMap.ValidateState();var a="";var b="";if(Su==null||Su=="undefined"||Su.length<=0)a="";else a=Su;if(Tu==null||Tu=="undefined"||Tu.length<=0)b="";else b=Tu;if(a==""&&b=="")throw new VEException("VEMap:Find","err_invalidwhatwhere",L_invalidwhatwhere_text);var parms=new Array();var Su=new VEParameter("a",a);parms.push(Su);var Tu=new VEParameter("b",b);parms.push(Tu);var c=0;var d=0;var e=0;var f=0;var g=1;var i=1;var r="false";if(a!=null&&a.length>0){
            var topLeft=this.m_vemap.vemapcontrol.PixelToLatLong(new Msn.VE.Pixel(0,0));var bottomRight=this.m_vemap.vemapcontrol.PixelToLatLong(new Msn.VE.Pixel(this.m_vemap.GetWidth(),this.m_vemap.GetHeight()));if(topLeft==null||bottomRight==null)return;c=topLeft.latitude;d=bottomRight.longitude;e=bottomRight.latitude;f=topLeft.longitude;if(c<e){
                var t=c;c=e;e=t;
            }
            if(d<f){
                var t=d;d=f;f=t;
            }
            if(Wu!=null&&Wu!="undefined"){
                VEValidator.ValidateInt(Wu,"startPageIndex");g=parseInt(Wu);
            }
            var param=new VEParameter("c",c);parms.push(param);param=new VEParameter("d",d);parms.push(param);param=new VEParameter("e",e);parms.push(param);param=new VEParameter("f",f);parms.push(param);param=new VEParameter("g",g);parms.push(param);param=new VEParameter("i",i);parms.push(param);param=new VEParameter("r",r);parms.push(param);
        }
        parms.push(new VEParameter(Msn.VE.API.Constants.mapguid,this.m_vemap.GUID));this.vesearchcallback=Uu;this.vesearchdisambiguatecallback=Vu;var network=new VENetwork();network.ServiceUrl=Msn.VE.API.Constants.searchservice;network.BeginInvoke(null,parms,null);
    }
    ;this._HandleFailedWhereSearch=function(Xu){
        VEMap.ValidateState();if(Xu!=null&&Xu!="undefined")this.m_vemap.ShowMessage(Xu.replace(/%1/g,MapControl.Features.PlatformName));
    }
    ;this._ApplyResults=function(a,b,c,d,e){
        VEMap.ValidateState();var findResults=new Array();var searchContainer=null;if(!Msn.VE.API.Globals.veiscommercialcontrol){
            if(this.m_vemap.searchelement!=null){
                searchContainer=document.getElementById(this.m_vemap.searchelement);searchContainer.innerHTML="";
            }
            if(b!=null)for(var i=0;i<b.length;i++){
                var findResult=new VEFindResult(b[i].id,b[i].name,b[i].description,m_veLatLongFactory.CreateVELatLong(b[i].latitude,b[i].longitude),false);findResults.push(findResult);if(searchContainer!=null)searchContainer.appendChild(VE_SearchManager.CreateSearchResultElement(b[i]));try{
                    var pushpin=new VEPushpin(b[i].id,m_veLatLongFactory.CreateVELatLong(b[i].latitude,b[i].longitude),null,b[i].name,b[i].description);this.m_vemap.AddPushpin(pushpin);
                }
                catch(err){
                    
                }
                
            }
            if(c!=null)for(var i=0;i<c.length;i++){
                var findResultLatLong=null;if(c[i].latitude!=null&&c[i].latitude!="undefined"&&c[i].longitude!=null&&c[i].longitude!="undefined"&&c[i].latitude>=-85&&c[i].latitude<=85&&c[i].longitude>=-180&&c[i].longitude<=180)findResultLatLong=m_veLatLongFactory.CreateVELatLong(c[i].latitude,c[i].longitude);var findResult=new VEFindResult(c[i].id,c[i].title,c[i].description,findResultLatLong,true);findResults.push(findResult);if(searchContainer!=null)searchContainer.appendChild(VE_SearchManager.CreateAdElement(c[i]));try{
                    if(findResultLatLong!=null){
                        var pushpin=new VEPushpin(c[i].id,findResultLatLong,null,c[i].title,c[i].description);this.m_vemap.AddPushpin(pushpin);
                    }
                    
                }
                catch(err){
                    
                }
                
            }
            if(e!=null&&e!="undefined"&&e.length!=0)this.m_vemap.ShowMessage(e);
        }
        findResults.HasMore=d;findResults.Message=e;Msn.VE.API.Globals.vesearchpoiresults=findResults;if(this.vesearchcallback!=null&&this.vesearchcallback!="undefined")this.vesearchcallback(findResults);
    }
    ;this.ApplySuggestion=function(Yu,Zu){
        VEMap.ValidateState();var el=document.getElementById("vewhatinput");if(el)el.value=Zu;this.Find(Zu,this.m_vemap.lastwheresearch,null,"VEMap._GetMapFromGUID("+this.m_vemap.GUID+")._Disambiguate",1);
    }
    ;this.CreateAdElement=function(av){
        VEMap.ValidateState();if(av==null||av=="undefined")return null;var el=document.createElement("div");el.id="veadresults_"+av.id;el.className="VE_AdResult";var title=document.createElement("a");title.className="VE_AdResult_Title";title.innerHTML=av.title;title.href=av.url;el.appendChild(title);var desc=document.createElement("div");desc.className="VE_AdResult_Description";desc.innerHTML=av.description;el.appendChild(desc);return el;
    }
    ;this.CreateSearchResultElement=function(bv){
        VEMap.ValidateState();if(bv==null||bv=="undefined")return null;var el=document.createElement("div");el.id="vesearchresults_"+bv.id;el.className="VE_SearchResult";var title=document.createElement("a");title.className="VE_SearchResult_Title";title.innerHTML=bv.name;el.appendChild(title);var desc=document.createElement("div");desc.className="VE_SearchResult_Description";desc.innerHTML=bv.description;el.appendChild(desc);var phone=document.createElement("div");phone.className="VE_SearchResult_Phone";phone.innerHTML=bv.phone;el.appendChild(phone);var type=document.createElement("div");type.className="VE_SearchResult_Type";type.innerHTML=bv.phone;el.appendChild(type);var rating=document.createElement("div");rating.className="VE_SearchResult_Rating";rating.innerHTML=bv.phone;el.appendChild(rating);return el;
    }
    ;this.UpdateAmbiguousList=function(a){
        VEMap.ValidateState();if(a==null||a=="undefined"||a.length==0)return;Msn.VE.API.Globals.vesearchlocresults=a;this.m_vemap.m_veambiguouslist.Show(a,this.vesearchdisambiguatecallback);
    }
    ;
}
Msn.VE.Search=new Object();Msn.VE.Search.strLastWhere="";function VEMessage(cv){
    VEValidator.ValidateObject(cv,"vemap",VEMap,"VEMap");this.m_vemap=cv;var self=this;this.Show=function(ev){
        if(ev==null||ev=="undefined"||ev.length<=0)return;ev=gv(ev);if(this.vemessagepanel==null||this.vemessagepanel=="undefined"){
            var e=document.createElement("div");e.id=this.m_vemap.ID+"_vemessagepanel";e.className="VE_Message";e.style.zIndex=Msn.VE.API.Globals.vemessagepanelzIndex;e.style.top=this.m_vemap.GetHeight()/2-Msn.VE.API.Globals.vemessagepanelheight/2+"px";e.style.left="30px";e.style.width=this.m_vemap.GetWidth()-60+"px";e.style.height=Msn.VE.API.Globals.vemessagepanelheight+"px";e.style.position="absolute";this.vemessagepanel=e;var title=document.createElement("a");title.className="VE_Message_Title";title.style.zIndex=parseInt(Msn.VE.API.Globals.vemessagepanelzIndex)+1;title.style.top="1px";title.style.left="1px";title.style.width=parseInt(this.vemessagepanel.style.width)-5+"px";title.innerHTML=IOSec.EncodeHtml(L_error_text);title.unselectable="on";this.vemessagepanel.appendChild(title);var cb=document.createElement("a");cb.className="VE_Message_Close";cb.style.zIndex=parseInt(Msn.VE.API.Globals.vemessagepanelzIndex)+2;cb.style.top="1px";cb.style.right="1px";cb.onclick=self.Hide;cb.unselectable="on";cb.innerHTML=L_close_text;this.vemessagepanel.appendChild(cb);var body=document.createElement("div");body.id=this.m_vemap.ID+"_vemessagepanel_body";body.className="VE_Message_Body";body.style.zIndex=parseInt(Msn.VE.API.Globals.vemessagepanelzIndex)+3;body.style.top="22px";body.style.width=parseInt(this.vemessagepanel.style.width)-8+"px";body.onclick=self.Hide;body.unselectable="on";body.innerHTML=ev;this.vemessagepanel.appendChild(body);this.m_vemap.AddControl(this.vemessagepanel,Msn.VE.API.Globals.vemessagepanelzIndex);
        }
        else{
            var body=document.getElementById(this.m_vemap.ID+"_vemessagepanel_body");body.innerHTML=ev;
        }
        this.vemessagepanel.style.display="block";this.timeoutIntervalID=window.setInterval(this.Hide,10000);
    }
    ;this.Hide=function(){
        VEMap.ValidateState();if(self.vemessagepanel!=null&&self.vemessagepanel!="undefined"){
            self.vemessagepanel.style.display="none";if(self.timeoutIntervalID!=null){
                window.clearInterval(self.timeoutIntervalID);self.timeoutIntervalID=null;
            }
            
        }
        
    }
    ;this.Dispose=function(){
        if(this.vemessagepanel!=null&&this.vemessagepanel!="undefined")this.vemessagepanel=null;
    }
    ;function gv(hv){
        var regExp=/<a[^>]*>/ig;hv=hv.replace(regExp,"");regExp=/<\/a>/ig;hv=hv.replace(regExp,"");return hv;
    }
    
}
var L_cannotrenderroute_text="The route could not be drawn because this web browser does not support SVG and VML.";VEDistanceUnit=new function(){
    this.Miles="m";this.Kilometers="k";
}
();VERouteType=new function(){
    this.Shortest="s";this.Quickest="q";
}
();function VERoute(jv,kv,lv){
    VEValidator.ValidateObject(jv,"startLocation",VERouteLocation,"VERouteLocation");VEValidator.ValidateObject(kv,"endLocation",VERouteLocation,"VERouteLocation");VEValidator.ValidateObject(lv,"veRouteItinerary",VERouteItinerary,"VERouteItinerary");this.StartLocation=jv;this.EndLocation=kv;this.Itinerary=lv;
}
function VERouteLocation(mv,nv){
    VEValidator.ValidateNonNull(mv,"address");VEValidator.ValidateObject(nv,"veLatLong",VELatLong,"VELatLong");this.Address=mv;this.LatLong=nv;
}
function VERouteItinerary(ov,pv,qv,rv){
    this.Distance=ov;this.DistanceUnit=pv;this.Time=qv;this.RouteType=rv;this.Segments=new Array();this.AddSegment=function(sv){
        VEValidator.ValidateObject(sv,"segment",VERouteSegment,"VERouteSegment");this.Segments.push(sv);
    }
    ;
}
function VERouteSegment(tv,uv,vv){
    VEValidator.ValidateObject(vv,"veLatLong",VELatLong,"VELatLong");this.Instruction=tv;this.Distance=uv;this.LatLong=vv;
}
function VEDirectionsManager(wv){
    VEValidator.ValidateObject(wv,"vemap",VEMap,"VEMap");this.m_vemap=wv;var self=this;this.lastStartString="";this.lastEndString="";this.laststart="";this.lastend="";this.lastcallback=null;this.disambigwhat="";this.veroutecache=new Array();var m_veLatLongFactory=new VELatLongFactory(new VELatLongFactorySpecFromMap(this.m_vemap));var m_veLatLongDecoder=new VELatLongDecoder();this.Initialize=function(){
        try{
            document.namespaces.add("v","urn:schemas-microsoft-com:vml");
        }
        catch(e){
            
        }
        if(this.veroutecache==null||this.veroutecache=="undefined")this.veroutecache=new Array();else this.RemoveRoutePins();
    }
    ;this.GetDrivingDirections=function(xv,yv,zv,Av,Bv){
        VEMap.ValidateState();this.ClearRoute();var a="";var b="";var c="m";var d="q";try{
            if(xv==null||xv=="undefined"||xv.length<=0)throw new VEException("VEDirectionsManager:GetDrivingDirections","err_invaliddirections",L_invaliddirections_text);else a=xv;if(yv==null||yv=="undefined"||yv.length<=0)throw new VEException("VEDirectionsManager:GetDrivingDirections","err_invaliddirections",L_invaliddirections_text);else b=yv;if(zv!=null&&zv!="undefined"){
                this.lastdist=zv;if(zv==VEDistanceUnit.Kilometers)c="k";
            }
            else this.lastdist=VEDistanceUnit.Miles;if(Av!=null&&Av!="undefined"){
                this.lasttype=Av;if(Av==VERouteType.Shortest)d="s";
            }
            else this.lastdist=VERouteType.Quickest;var parms=new Array();this.laststart=xv;if(typeof xv=="object"){
                var veLatLongDecoded=m_veLatLongDecoder.Decode(xv);parms.push(new VEParameter("startlat",veLatLongDecoded.Latitude));parms.push(new VEParameter("startlon",veLatLongDecoded.Longitude));
            }
            else parms.push(new VEParameter("start",a));this.lastend=yv;if(typeof yv=="object"){
                var veLatLongDecoded=m_veLatLongDecoder.Decode(yv);parms.push(new VEParameter("endlat",veLatLongDecoded.Latitude));parms.push(new VEParameter("endlon",veLatLongDecoded.Longitude));
            }
            else parms.push(new VEParameter("end",b));parms.push(new VEParameter("units",c));parms.push(new VEParameter("type",d));parms.push(new VEParameter(Msn.VE.API.Constants.mapguid,this.m_vemap.GUID));this.vedirectionscallback=Bv;this.vedddisambiguatecallback="VEMap._GetMapFromGUID("+this.m_vemap.GUID+")._dm.DisambiguateDirections";var network=new VENetwork();network.ServiceUrl=Msn.VE.API.Constants.directionsservice;network.BeginInvoke(null,parms,null);
        }
        catch(ex){
            throw ex;
        }
        
    }
    ;this.Populate=function(Cv,Dv,Ev,Fv,Gv,Hv,Iv,Jv,Kv,Lv,Mv,Nv,Ov,Pv){
        try{
            if(Dv==null||Fv==null||Gv==null||Hv==null||Iv==null||Jv==null||Kv==null||Mv==null||Nv==null||Ov==null||Pv==null)throw new VEException("VEDirectionsManager:GetDrivingDirections","err_noroute",L_noroute_text);if(Cv==null||Cv=="undefined"||Cv.length==0)Cv=this.lastStartString;if(Ev==null||Ev=="undefined"||Ev.length==0)Ev=this.lastEndString;var StartLocation=new VERouteLocation(Cv,m_veLatLongFactory.CreateVELatLong(Dv[0],Dv[1]));var EndLocation=new VERouteLocation(Ev,m_veLatLongFactory.CreateVELatLong(Fv[0],Fv[1]));var routeDecoder=new Msn.VE.DirectionsDecoder();Hv=routeDecoder.DecodeCoordinatesString(Hv);Iv=routeDecoder.DecodeCoordinatesString(Iv);var itineraryDistanceUnit=Kv;if(Kv==null||Kv.length==0)itineraryDistanceUnit="mi";var routeItinerary=new VERouteItinerary(Jv,itineraryDistanceUnit,Mv,Lv);var StartSegment=new VERouteSegment(L_startat_text+" "+Cv,0,m_veLatLongFactory.CreateVELatLong(Dv[0],Dv[1]));routeItinerary.AddSegment(StartSegment);var firstone=true;var vepp=null;if(Gv!=null){
                var i=Gv.length;for(var j=0;j<i;j++){
                    var ri=Gv[j];var Segment=new VERouteSegment(ri.name,ri.distance,m_veLatLongFactory.CreateVELatLong(ri.latitude,ri.longitude));routeItinerary.AddSegment(Segment);if(firstone){
                        vepp=new VEPushpin(VENetwork.GetExecutionID(),m_veLatLongFactory.CreateVELatLong(ri.latitude,ri.longitude),Msn.VE.API.Constants.vedirectionsstarticon,L_Start_Text,ri.name);this.m_vemap.AddPushpin(vepp);this.veroutecache.push(vepp);firstone=false;
                    }
                    else{
                        vepp=new VEPushpin(VENetwork.GetExecutionID(),m_veLatLongFactory.CreateVELatLong(ri.latitude,ri.longitude),Msn.VE.API.Constants.vedirectionsstepicon.replace("%1",j).replace("%2",i),L_DirectionsStep_Text+" "+j,ri.name);this.m_vemap.AddPushpin(vepp);this.veroutecache.push(vepp);
                    }
                    
                }
                var EndSegment=new VERouteSegment(L_arriveat_text+" "+Ev,0,m_veLatLongFactory.CreateVELatLong(Fv[0],Fv[1]));routeItinerary.AddSegment(EndSegment);vepp=new VEPushpin(VENetwork.GetExecutionID(),m_veLatLongFactory.CreateVELatLong(Fv[0],Fv[1]),Msn.VE.API.Constants.vedirectionsendicon,L_End_Text,L_arriveat_text+" "+Ev);this.m_vemap.AddPushpin(vepp);this.veroutecache.push(vepp);this.m_vemap.vemapcontrol.SetViewport(Dv[0],Dv[1],Fv[0],Fv[1]);var route=new VERoute(StartLocation,EndLocation,routeItinerary);
            }
            this.CreateRouteHighLight("veDDHighlight",Hv,Iv,Ov,Pv);if(this.vedirectionscallback!=null&&this.vedirectionscallback!="undefined")this.vedirectionscallback(route);
        }
        catch(ex){
            throw ex;
        }
        
    }
    ;this.CreateRouteHighLight=function(Qv,Rv,Sv,Tv,Uv){
        VEMap.ValidateState();if(this.verenderingdisabled){
            this.ShowMessage(L_cannotrenderroute_text);return;
        }
        var routeHighlightWeight=6;var routeHighlightColor="#11DD11";var routeHighlightZIndex=4;if(this.verouteHighlight!=null)this.RemoveRouteHighLight();this.verouteHighlight=this.m_vemap.vemapcontrol.AddLine(Qv,Rv,Sv,routeHighlightWeight,routeHighlightColor,routeHighlightZIndex,Tv,Uv);
    }
    ;this.ClearRoute=function(){
        this.RemoveRoutePins();this.RemoveRouteHighLight();VEPushpin.Hide();this.m_vemap.m_veambiguouslist.Hide();
    }
    ;this.RemoveRoutePins=function(){
        try{
            VEMap.ValidateState();var pp=null;if(this.veroutecache!=null){
                var len=this.veroutecache.length;for(var i=0;i<len;i++){
                    pp=this.veroutecache[i];if(pp==null||pp=="undefined")continue;this.m_vemap.DeletePushpin(pp.ID);
                }
                for(var i=0;i<len;i++){
                    this.veroutecache.pop();
                }
                
            }
            
        }
        catch(err){
            
        }
        
    }
    ;this.RemoveRouteHighLight=function(){
        VEMap.ValidateState();if(this.verouteHighlight==null)return;this.m_vemap.vemapcontrol.RemoveLine(this.verouteHighlight.id);
    }
    ;this.ShowMessage=function(a,b){
        this.m_vemap.ShowMessage(b);
    }
    ;this.ShowNotFoundMessage=function(a,b){
        
    }
    ;this.HandleFailedGetDirections=function(Vv){
        if(Vv!=null&&Vv!="undefined"){
            window.setTimeout("VEMap._GetMapFromGUID('"+this.m_vemap.GUID+"')._dm.ClearRoute()",10);this.m_vemap.ShowMessage(Vv.replace(/%1/g,MapControl.Features.PlatformName));
        }
        
    }
    ;this.Disambiguate=function(a,b){
        if(!this.m_vemap.m_veambiguouslist.IsVisible()){
            this.disambigwhat=a;this.m_vemap.m_veambiguouslist.Show(b,this.vedddisambiguatecallback);
        }
        
    }
    ;this.DisambiguateDirections=function(a,b,c,d,e){
        var start="";var end="";if(this.disambigwhat=="end"){
            start=this.laststart;this.lastEndString=a;if(b!=null&&b!="undefined"&&c!=null&&c!="undefined")end=m_veLatLongFactory.CreateVELatLong(b,c);else end=a;
        }
        else{
            end=this.lastend;this.lastStartString=a;if(b!=null&&b!="undefined"&&c!=null&&c!="undefined")start=new VELatLong(b,c);else start=a;
        }
        this.GetDrivingDirections(start,end,this.lastdist,this.lasttype,this.vedirectionscallback);
    }
    ;
}
function VE_Directions(){
    
}
function VE_RouteInstruction(Wv,Xv,Yv,Zv){
    this.name=Wv;this.distance=Zv;this.latitude=Xv;this.longitude=Yv;this.permanentPin=false;
}
function VE_Location(aw,bw,cw){
    this.name=aw;this.latitude=bw;this.longitude=cw;
}
function VEAmbiguouslist(ew){
    VEValidator.ValidateNonNull(ew,"vemap");this.m_vemap=ew;var self=this;this.ID=this.m_vemap.ID+"_veplacelistpanel";this.Show=function(a,gw){
        var body=null;if(this.veplacelistpanel==null||this.veplacelistpanel=="undefined"){
            var e=document.createElement("div");e.id=this.ID;e.className="VE_PlaceList";e.style.top=this.m_vemap.GetHeight()/2-Msn.VE.API.Globals.veplacelistpanelheight/2+"px";e.style.left=this.m_vemap.GetWidth()/2-Msn.VE.API.Globals.veplacelistpanelwidth/2+"px";e.style.width=Msn.VE.API.Globals.veplacelistpanelwidth+"px";e.style.height=Msn.VE.API.Globals.veplacelistpanelheight+"px";e.style.position="absolute";this.veplacelistpanel=e;var title=document.createElement("a");title.className="VE_PlaceList_Title";title.style.zIndex=parseInt(Msn.VE.API.Globals.veplacelistpanelzIndex)+1;title.style.width=parseInt(Msn.VE.API.Globals.veplacelistpanelwidth)-5+"px";title.style.top="1px";title.style.left="1px";title.innerHTML=IOSec.EncodeHtml(L_selectlocation_text);title.unselectable="on";this.veplacelistpanel.appendChild(title);var cb=document.createElement("a");cb.className="VE_PlaceList_Close";cb.style.zIndex=parseInt(Msn.VE.API.Globals.veplacelistpanelzIndex)+2;cb.style.top="1px";cb.style.right="1px";cb.onclick=self.Hide;cb.unselectable="on";cb.innerHTML=L_close_text;this.veplacelistpanel.appendChild(cb);body=document.createElement("div");body.id=this.m_vemap.ID+"_veplacelistbody";body.style.zIndex=300;body.className="VE_PlaceList_Body";this.veplacelistpanel.appendChild(body);this.m_vemap.AddControl(this.veplacelistpanel,Msn.VE.API.Globals.veplacelistpanelzIndex);
        }
        else body=document.getElementById(this.m_vemap.ID+"_veplacelistbody");body.innerHTML="";for(var i=0;i<a.length;i++){
            if(a[i]==null||a[i]=="undefined")continue;var loc=document.createElement("div");loc.id="veplacelistpanel_body_loc"+i;loc.className="VE_PlaceList_Location";loc.style.position="relative";loc.style.zIndex=parseInt(Msn.VE.API.Globals.veplacelistpanelzIndex)+4;loc.unselectable="on";var veambiglistHide="VEMap._GetMapFromGUID('"+this.m_vemap.GUID+"').m_veambiguouslist.Hide();";var veambiglistSetViewport="VEMap._GetMapFromGUID('"+this.m_vemap.GUID+"').vemapcontrol.SetViewport";if(a[i].name){
                if(gw!=null&&gw!="undefined")loc.innerHTML="<a onclick=\"javascript:"+veambiglistHide+gw+"('"+a[i].name+"', "+a[i].latitude+", "+a[i].longitude+");\">"+a[i].name+"</a>";else loc.innerHTML="<a onclick=\"javascript:"+veambiglistHide+"\">"+a[i].name+"</a>";
            }
            else{
                if(gw!=null&&gw!="undefined")loc.innerHTML="<a onclick=\"javascript:"+veambiglistHide+gw+"('"+a[i][0]+"', "+a[i][1]+", "+a[i][2]+", "+a[i][3]+", "+a[i][4]+");\">"+a[i][0]+"</a>";else loc.innerHTML="<a onclick=\"javascript:"+veambiglistHide+veambiglistSetViewport+"("+a[i][1]+", "+a[i][2]+", "+a[i][3]+", "+a[i][4]+");\">"+a[i][0]+"</a>";
            }
            body.appendChild(loc);
        }
        this.veplacelistpanel.style.display="block";
    }
    ;this.Hide=function(){
        if(self.veplacelistpanel!=null&&self.veplacelistpanel!="undefined")self.veplacelistpanel.style.display="none";
    }
    ;this.IsVisible=function(){
        var isVisible=false;if(this.veplacelistpanel!=null&&this.veplacelistpanel!="undefined"&&this.veplacelistpanel.style.display!="none")isVisible=true;return isVisible;
    }
    ;this.Dispose=function(){
        if(this.veplacelistpanel!=null&&this.veplacelistpanel!="undefined")this.veplacelistpanel=null;
    }
    ;
}
function VEGraphicsManager(hw){
    VEValidator.ValidateObject(hw,"vemap",VEMap,"VEMap");var self=this;this.m_vemap=hw;this.m_vemapcontrol=this.m_vemap.vemapcontrol;var m_veLatLongDecoder=new VELatLongDecoder();this.Initialize=function(){
        if(this.m_vegraphiccanvas==null||this.m_vegraphiccanvas=="undefined")try{
            this.m_vegraphicspolylines=new Array();this.m_vegraphiccanvas=Msn.Drawing.Graphic.CreateGraphic(this.m_vemap.mapelement);this.m_vegraphiccanvas.SetZIndex(17);this.m_vemapcontrol.AttachEvent("onstartzoom",self.Clear);this.m_vemapcontrol.AttachEvent("onendzoom",self.Draw);this.m_vemapcontrol.AttachEvent("onstartcontinuouspan",self.Clear);this.m_vemapcontrol.AttachEvent("onmouseup",self.Draw);this.m_vemapcontrol.AttachEvent("onobliquechange",self.Update);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.Update=function(){
        self.Clear();self.Draw();
    }
    ;this.Clear=function(){
        if(self.m_vegraphiccanvas!=null&&self.m_vegraphiccanvas!="undefined")self.m_vegraphiccanvas.Clear();
    }
    ;this.Draw=function(){
        if(self.m_vegraphicspolylines==null||self.m_vegraphicspolylines.length<=0)return;var lineslength=self.m_vegraphicspolylines.length;for(var j=0;j<lineslength;j++){
            var vepolyline=self.m_vegraphicspolylines[j];var points=new Array();var ll=null;var pix=null;var vepoints=vepolyline.GetLatLongs();for(var i=0;i<vepoints.length;i++){
                var veLatLongDecoded=m_veLatLongDecoder.Decode(vepoints[i]);ll=new Msn.VE.LatLong(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);pix=self.m_vemapcontrol.LatLongToPixel(ll);points.push(new Msn.Drawing.Point(pix.x,pix.y));
            }
            var polyline=new Msn.Drawing.PolyLine(points);self.m_vegraphiccanvas.SetZIndex(17);self.m_vegraphiccanvas.SetStroke(vepolyline.Stroke);self.m_vegraphiccanvas.DrawPolyline(polyline);
        }
        
    }
    ;
}
VEGraphicsManager.prototype.RemoveLine=function(jw){
    this.RemoveLinebyId(jw.ID);
}
;VEGraphicsManager.prototype.RemoveLinebyId=function(kw){
    if(this.m_vegraphiccanvas==null||this.m_vegraphiccanvas=="undefined"){
        throw new VEException("VEMap:DrawLine","err_GraphicsInitError",L_GraphicsInitError_Text);return;
    }
    try{
        var linelength=this.m_vegraphicspolylines.length;var i=0;while(i<linelength&&kw!=this.m_vegraphicspolylines[i].ID){
            i++;
        }
        if(i<linelength)this.m_vegraphicspolylines.splice(i,1);else{
            throw new VEException("VEMap:DrawLine","err_GraphicsInitError",L_invalidpolylineid_text);return;
        }
        
    }
    catch(ex){
        throw ex;return;
    }
    this.Clear();this.Draw();
}
;VEGraphicsManager.prototype.RemoveAllLines=function(){
    this.m_vegraphicspolylines=new Array();this.Clear();this.Draw();
}
;VEGraphicsManager.prototype.DrawLine=function(lw){
    if(this.m_vegraphiccanvas==null||this.m_vegraphiccanvas=="undefined"){
        throw new VEException("VEMap:DrawLine","err_GraphicsInitError",L_GraphicsInitError_Text);return;
    }
    try{
        VEValidator.ValidateObject(lw,"vePolyline",VEPolyline,"VEPolyline");var linelength=this.m_vegraphicspolylines.length;for(var i=0;i<linelength;i++){
            if(lw.ID==this.m_vegraphicspolylines[i].ID)throw new VEException("VEMap:DrawLine","err_invalidpolylineid",L_invalidpolylineid_text);
        }
        this.m_vegraphicspolylines.push(lw);
    }
    catch(ex){
        throw ex;return;
    }
    this.Draw();
}
;VEGraphicsManager.prototype.Dispose=function(){
    if(this.m_vegraphiccanvas!=null){
        this.m_vegraphiccanvas.Clear();this.m_vegraphiccanvas.Destroy();this.m_vegraphiccanvas=null;
    }
    if(this.m_vegraphicspolylines!=null&&this.m_vegraphicspolylines!="undefined"){
        var lineslength=this.m_vegraphicspolylines.length;for(var j=0;j<lineslength;j++){
            this.m_vegraphicspolylines.pop();
        }
        
    }
    if(this.m_vemap!=null){
        this.m_vemapcontrol.DetachEvent("onstartzoom",this.Clear);this.m_vemapcontrol.DetachEvent("onendzoom",this.Draw);this.m_vemapcontrol.DetachEvent("onstartcontinuouspan",this.Clear);this.m_vemapcontrol.DetachEvent("onmouseup",this.Draw);
    }
    
}
;VELayerType=new function(){
    this.VECollection="c";this.GeoRSS="g";
}
();function VELayerSpecification(mw,nw,ow,pw,qw,rw){
    this.Type=null;this.ID=null;this.LayerSource=null;this.Method=null;this.FnCallback=null;this.IconUrl=null;if(mw!="undefined"&&mw!=null){
        VEValidator.ValidateLayerType(mw,"veLayerType");this.Type=mw;
    }
    if(nw!="undefined"&&nw!=null)this.ID=nw;if(ow!="undefined"&&ow!=null)this.LayerSource=ow;if(pw!="undefined"&&pw!=null)this.Method=pw;if(qw!="undefined"&&qw!=null)this.FnCallback=qw;if(rw!="undefined"&&rw!=null)this.IconUrl=rw;
}
function VELayerManager(sw){
    var self=this;VEValidator.ValidateNonNull(sw,"vemap");this.m_vemap=sw;this.m_vemapcontrol=this.m_vemap.vemapcontrol;this.m_velayers=new Array();this.m_veLatLongDecoder=new VELatLongDecoder();this.m_spec=new VELatLongFactorySpecFromMap(this.m_vemap);var m_veLatLongFactory=new VELatLongFactory(this.m_spec);this.AddLayer=function(tw){
        VEValidator.ValidateObject(tw,"veLayerSpec",VELayerSpecification,"VELayerSpecification");VEValidator.ValidateLayerType(tw.Type,"veLayerSpec.Type");VEValidator.ValidateNonNull(tw.ID,"veLayerSpec.ID");VEValidator.ValidateNonNull(tw.LayerSource,"veLayerSpec.LayerSource");if(tw.Type==VELayerType.GeoRSS){
            VEValidator.ValidateNonNull(tw.Method,"veLayerSpec.Method");this.AddGeoRSSLayer(tw);
        }
        else{
            if(tw.Type==VELayerType.VECollection)this.AddVECollectionLayer(tw);else throw new VEException("VEMap:AddLayer","err_invalidlayertype",L_invalidlayertype_text);
        }
        
    }
    ;this.AddGeoRSSLayer=function(uw){
        VEMap.ValidateState();try{
            var layer=this.GetLayerById(uw.ID);if(layer!=null&&layer!="undefined")throw new VEException("VELayerManager:AddGeoRSSLayer","err_invalidlayerid",L_invalidlayerid_text);var veLayer=new VELayer(uw,VENetwork.GetExecutionID(),this);this.m_velayers.push(veLayer);VENetwork.DownloadXml(uw.LayerSource,uw.Method,veLayer.AddGeoRSSLayerCallback);
        }
        catch(err){
            throw err;
        }
        
    }
    ;this.AddVECollectionLayer=function(vw){
        VEMap.ValidateState();try{
            var layer=this.GetLayerById(vw.ID);if(layer!=null&&layer!="undefined")throw new VEException("VELayerManager:AddCollectionLayer","err_invalidlayerid",L_invalidlayerid_text);var veLayer=new VELayer(vw,VENetwork.GetExecutionID(),this);this.m_velayers.push(veLayer);var parms=new Array();parms.push(new VEParameter("action",VE_AnnotationActions.RetrieveAll));parms.push(new VEParameter(VE_CollectionsManagerConstants.C_Id,veLayer.Spec.LayerSource));parms.push(new VEParameter(VE_CollectionsManagerConstants.Market,Msn.VE.API.Globals.language));parms.push(new VEParameter(Msn.VE.API.Constants.mapguid,this.m_vemap.GUID));parms.push(new VEParameter(Msn.VE.API.Constants.contextid,veLayer.GUID));var network=new VENetwork();network.ServiceUrl=Msn.VE.API.Constants.collectionservice;network.BeginInvoke(null,parms,null);
        }
        catch(err){
            throw err;
        }
        
    }
    ;this.GetLayerById=function(ww){
        var layerlength=this.m_velayers.length;for(var i=0;i<layerlength;++i){
            if(this.m_velayers[i].Spec.ID==ww)return this.m_velayers[i];
        }
        return null;
    }
    ;this.GetLayerByGUID=function(xw){
        var layerlength=this.m_velayers.length;for(var i=0;i<layerlength;++i){
            if(this.m_velayers[i].GUID==xw)return this.m_velayers[i];
        }
        return null;
    }
    ;this.AddGeoRSSLayerPushpins=function(yw,zw){
        var pinArray=new Array();var title=null;var description=null;var link=null;var icon=null;var lat=null;var lon=null;var x=yw.getElementsByTagName("item");for(i=0;i<x.length;i++){
            count=i;for(j=0;j<x[i].childNodes.length;j++){
                if(x[i].childNodes[j].nodeType!=1)continue;if(x[i].childNodes[j].nodeName=="title"){
                    if(x[i].childNodes[j].firstChild)title=x[i].childNodes[j].firstChild.nodeValue;else title="";
                }
                else{
                    if(x[i].childNodes[j].nodeName=="description"){
                        if(x[i].childNodes[j].firstChild)description=x[i].childNodes[j].firstChild.nodeValue;else description="";
                    }
                    else{
                        if(x[i].childNodes[j].nodeName=="link")link=x[i].childNodes[j].firstChild.nodeValue;else{
                            if(x[i].childNodes[j].nodeName=="icon")icon=x[i].childNodes[j].firstChild.nodeValue;else{
                                if(x[i].childNodes[j].nodeName=="virtualearth:icon")icon=x[i].childNodes[j].firstChild.nodeValue;else{
                                    if(x[i].childNodes[j].nodeName=="geo:lat")lat=x[i].childNodes[j].firstChild.nodeValue;else{
                                        if(x[i].childNodes[j].nodeName=="geo:lon")lon=x[i].childNodes[j].firstChild.nodeValue;else{
                                            if(x[i].childNodes[j].nodeName=="geo:long")lon=x[i].childNodes[j].firstChild.nodeValue;else{
                                                if(x[i].childNodes[j].nodeName=="gml:name"){
                                                    if(x[i].childNodes[j].firstChild)title=x[i].childNodes[j].firstChild.nodeValue;else title="";
                                                }
                                                else{
                                                    if(x[i].childNodes[j].nodeName=="gml:description"){
                                                        if(x[i].childNodes[j].firstChild)description=x[i].childNodes[j].firstChild.nodeValue;else description="";
                                                    }
                                                    else{
                                                        if(x[i].childNodes[j].nodeName=="gml:Point"||x[i].childNodes[j].nodeName=="gml:point"){
                                                            if(x[i].childNodes[j].firstChild&&x[i].childNodes[j].firstChild.nodeName=="gml:pos"){
                                                                if(x[i].childNodes[j].firstChild.firstChild){
                                                                    var nodeValue=x[i].childNodes[j].firstChild.firstChild.nodeValue;latlon=Aw(nodeValue);if(latlon.length>1){
                                                                        lat=latlon[0];lon=latlon[1];
                                                                    }
                                                                    
                                                                }
                                                                
                                                            }
                                                            
                                                        }
                                                        else{
                                                            if(x[i].childNodes[j].nodeName=="gml:pos"){
                                                                if(x[i].childNodes[j].firstChild){
                                                                    var nodeValue=x[i].childNodes[j].firstChild.nodeValue;latlon=Aw(nodeValue);if(latlon.length>1){
                                                                        lat=latlon[0];lon=latlon[1];
                                                                    }
                                                                    
                                                                }
                                                                
                                                            }
                                                            
                                                        }
                                                        
                                                    }
                                                    
                                                }
                                                
                                            }
                                            
                                        }
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            if(lat==null||lat=="undefined"||lat.length<=0||lon==null||lon=="undefined"||lon.length<=0)continue;if(zw.Spec.IconUrl!=null&&zw.Spec.IconUrl!="undefined")icon=zw.Spec.IconUrl;if(icon==null||icon=="undefined"||icon.length<=0)icon=Msn.VE.API.Constants.iconurl;var details=description;if(link!=null&&link!="undefined")details+="<p><a href='"+link+"' class=\"VE_Pushpin_Popup_Link\" target=_blank>. . .</a></p>";var pinid="Layer"+zw.Spec.ID+"_"+i;var pin=new VEPushpin(pinid,m_veLatLongFactory.CreateVELatLong(lat,lon),icon,title,details);pin.IsInLayer=true;pinArray.push(pin);
        }
        zw.Pins=pinArray;this.Show(zw.Spec.ID);if(zw.Spec.FnCallback!=null&&zw.Spec.FnCallback!="undefined")zw.Spec.FnCallback(pinArray);
    }
    ;function Aw(Bw){
        Bw=Bw.replace(/^\s+/g,"");Bw=Bw.replace(/\s+$/g,"");var latlon=new Array();if(Bw.indexOf(",")>0)latlon=Bw.split(",");else{
            Bw=Bw.replace(/\s+/g," ");latlon=Bw.split(" ");
        }
        return latlon;
    }
    this.RetrieveAllAnnotationsCallback=function(Cw,Dw){
        if(Dw!="undefined"&&Dw!=null){
            var layer=self.GetLayerByGUID(Dw);if(layer!=null&&layer!="undefined"){
                var icon=Msn.VE.API.Constants.iconurl;if(layer.Spec.IconUrl!=null&&layer.Spec.IconUrl!="undefined")icon=layer.Spec.IconUrl;var pinArray=new Array();for(var i=0;i<Cw.length;++i){
                    var title=IOSec.EncodeHtml(Cw[i].Title);var description=IOSec.EncodeHtml(Cw[i].Notes);var link=Cw[i].Url;var lat=Cw[i].Latitude;var lon=Cw[i].Longitude;var photoUrl=Cw[i].PhotoUrl;var details=description;var pinid="Layer"+layer.Spec.ID+"_"+i;if(photoUrl!=null&&photoUrl!="undefined"&&photoUrl.length>1)title="<a href=\"\" onclick=\"window.open('"+photoUrl+"', '_blank' , 'menubar=0,resizable=1,scrollbars=0,status=0,titlebar=0,toolbar=0,width=800,height=600,screenX=200,left=200,screenY=200,top=200');return false;\"><img border=0 id=eroImg_"+pinid+" style=\"position: relative; display: block; padding-right: 10px; padding-left: 0px; padding-bottom: 5px; padding-top: 3px; width: 80px; height: 80px; float: left;\" src=\""+photoUrl+"\"/></a>"+title;if(link!=null&&link!="undefined"&&link.length>0)details+="<p><a href='"+link+"' class=\"VE_Pushpin_Popup_Link\" target=_blank>. . .</a></p>";var pin=new VEPushpin(pinid,m_veLatLongFactory.CreateVELatLong(lat,lon),icon,title,details);pin.IsInLayer=true;pinArray.push(pin);
                }
                layer.Pins=pinArray;self.Show(layer.Spec.ID);if(layer.Spec.FnCallback!=null&&layer.Spec.FnCallback!="undefined")layer.Spec.FnCallback(pinArray);
            }
            
        }
        
    }
    ;
}
VELayerManager.prototype.Dispose=function(){
    this.DeleteAllLayers();this.m_velayers=null;this.m_vemapcontrol=null;this.m_vemap=null;this.m_veLatLongDecoder=null;this.m_spec=null;
}
;VELayerManager.prototype.Show=function(Ew){
    VEMap.ValidateState();try{
        VEValidator.ValidateNonNull(Ew,"layerId");var layer=this.GetLayerById(Ew);if(layer!=null&&layer!="undefined"){
            var llArray=new Array();var pins=layer.Pins;var length=pins.length;for(var j=0;j<length;j++){
                var ll=new Object();var latLong=pins[j].LatLong;if(this.m_spec.IsEncode())latLong=this.m_veLatLongDecoder.Decode(latLong);ll.latitude=latLong.Latitude;ll.longitude=latLong.Longitude;llArray.push(ll);try{
                    this.m_vemap.AddPushpin(pins[j]);
                }
                catch(ex){
                    
                }
                
            }
            if(llArray!=null&&llArray.length>0)this.m_vemapcontrol.SetBestMapView(llArray);
        }
        else throw new VEException("VEMap:RemoveLayerbyId","err_invalidlayerid",L_invalidlayerid_text);
    }
    catch(err){
        throw err;
    }
    
}
;VELayerManager.prototype.Hide=function(Fw){
    VEMap.ValidateState();try{
        VEValidator.ValidateNonNull(Fw,"layerId");var layer=this.GetLayerById(Fw);if(layer!=null&&layer!="undefined")try{
            this.DeletePushpinsForLayer(layer);
        }
        catch(ex){
            
        }
        else throw new VEException("VEMap:RemoveLayerbyId","err_invalidlayerid",L_invalidlayerid_text);
    }
    catch(err){
        throw err;
    }
    
}
;VELayerManager.prototype.DeleteAllLayers=function(){
    var len=this.m_velayers.length;for(var i=0;i<len;++i){
        this.m_velayers[i].Dispose();
    }
    this.m_velayers=new Array();
}
;VELayerManager.prototype.DeleteLayer=function(Gw){
    this.DeleteLayerById(Gw.Spec.ID);
}
;VELayerManager.prototype.DeleteLayerById=function(Hw){
    try{
        if(this.m_velayers==null||this.m_velayers=="undefined"){
            throw new VEException("VEMap:RemoveLayerbyId","err_GraphicsInitError",L_GraphicsInitError_Text);return;
        }
        var layerlength=this.m_velayers.length;var i=0;while(i<layerlength&&Hw!=this.m_velayers[i].Spec.ID){
            i++;
        }
        if(i<layerlength){
            try{
                this.DeletePushpinsForLayer(this.m_velayers[i]);
            }
            catch(ex){
                
            }
            this.m_velayers[i].Dispose();this.m_velayers[i]=null;this.m_velayers.splice(i,1);
        }
        else{
            throw new VEException("VEMap:RemoveLayerbyId","err_invalidlayerid",L_invalidlayerid_text);return;
        }
        
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VELayerManager.prototype.DeletePushpinsForLayer=function(Iw){
    VEMap.ValidateState();VEValidator.ValidateNonNull(Iw,"layer");try{
        var pins=Iw.Pins;var length=pins.length;for(var i=0;i<length;i++){
            this.m_vemap.DeletePushpin(pins[i].ID);
        }
        
    }
    catch(ex){
        throw ex;return;
    }
    
}
;function VELayer(Jw,Kw,Lw){
    VEValidator.ValidateObject(Jw,"veLayerSpec",VELayerSpecification,"VELayerSpecification");this.Spec=Jw;this.GUID=Kw;this.Pins=new Array();var self=this;this.m_veLayerManager=Lw;this.AddGeoRSSLayerCallback=function(Mw){
        self.m_veLayerManager.AddGeoRSSLayerPushpins(Mw,self);
    }
    ;this.Dispose=function(){
        for(var i=0;i<this.Pins.length;++i){
            if(this.Pins[i]!=null&&this.Pins[i]!="undefined"){
                this.Pins[i].Dispose();this.Pins[i]=null;
            }
            
        }
        this.Pins=null;this.GUID=null;this.Spec=null;this.m_veLayerManager=null;
    }
    ;
}
function VELatLong(Nw,Ow){
    try{
        this.Latitude=null;this.Longitude=null;this._reserved=null;if(Nw!=null&&Nw!="undefined"){
            VEValidator.ValidateFloat(Nw,"latitude");this.Latitude=Nw;
        }
        if(Ow!=null&&Ow!="undefined"){
            VEValidator.ValidateFloat(Ow,"longitude");this.Longitude=Ow;
        }
        
    }
    catch(ex){
        throw ex;return;
    }
    
}
function Clone(){
    var veLatLong=new VELatLong();veLatLong.Latitude=this.Latitude;veLatLong.Longitude=this.Longitude;veLatLong._reserved=this._reserved;return veLatLong;
}
function toString(){
    var s="";if(this.Latitude!=null&&this.Longitude!=null)s=this.Latitude+", "+this.Longitude;return s;
}
VELatLong.prototype.toString=toString;VELatLong.prototype.Clone=Clone;function VELatLongRectangle(Pw,Qw){
    VEValidator.ValidateObject(Pw,"topLeftLatLong",VELatLong,"VELatLong");VEValidator.ValidateObject(Qw,"bottomRightLatLong",VELatLong,"VELatLong");this.TopLeftLatLong=Pw;this.BottomRightLatLong=Qw;
}
function VELatLongDecoder(){
    var m_latlongEncoding=new VELatLongEncoding();this.Decode=function(Rw){
        VEValidator.ValidateObject(Rw,"veLatLong",VELatLong,"VELatLong");var veLatLongCopy=Rw.Clone();if(veLatLongCopy.Latitude==null||veLatLongCopy.Longitude==null&&veLatLongCopy._reserved!=null){
            var latLong=m_latlongEncoding.Decode(veLatLongCopy._reserved);veLatLongCopy.Latitude=latLong[0];veLatLongCopy.Longitude=latLong[1];veLatLongCopy._reserved=null;
        }
        return veLatLongCopy;
    }
    ;
}
function VELatLongFactoryAlwaysEncodeSpec(){
    this.IsEncode=function(){
        return true;
    }
    ;
}
function VELatLongFactorySpecFromMap(Sw){
    VEValidator.ValidateObject(Sw,"vemap",VEMap,"VEMap");var m_vemap=Sw;this.IsEncode=function(){
        return m_vemap.GetMapStyle()==VEMapStyle.Birdseye;
    }
    ;
}
function VELatLongFactorySpecFromMapView(Tw){
    VEValidator.ValidateNonNull(Tw,"mapView");var m_mapView=Tw;this.IsEncode=function(){
        return m_mapView.mapStyle==Msn.VE.MapStyle.Oblique;
    }
    ;
}
function VELatLongFactory(Uw){
    VEValidator.ValidateNonNull(Uw,"veLatLongFactorySpec");var m_spec=Uw;var m_latLongEncoder=new VELatLongEncoding();this.CreateVELatLong=function(Vw,Ww){
        var veLatLong=null;if(m_spec.IsEncode()){
            veLatLong=new VELatLong();veLatLong._reserved=m_latLongEncoder.Encode(Vw,Ww);
        }
        else veLatLong=new VELatLong(Vw,Ww);return veLatLong;
    }
    ;
}
function VEPolyline(Xw,Yw,Zw,ax){
    VEValidator.ValidateNonNull(Xw,"id");VEValidator.ValidateNonNull(Yw,"arrVELatLong");this.ID=Xw;this.LatLongs=Yw;this.Stroke=new Msn.Drawing.Stroke();if(Zw==null||Zw=="undefined")Zw=new VEColor(17,221,17,0.7);this.SetColor(Zw);if(ax==null||ax=="undefined")ax=6;this.SetWidth(ax);
}
function SetColor(bx){
    VE_Analytics.LogAPI("VE | APIs","VEPolyline - SetColor");VEValidator.ValidateNonNull(bx);this.Stroke.color=new Msn.Drawing.Color(bx.R,bx.G,bx.B,bx.A);
}
function SetWidth(cx){
    VE_Analytics.LogAPI("VE | APIs","VEPolyline - SetWidth");VEValidator.ValidateInt(cx,"width");this.Stroke.width=cx;
}
function GetLatLongs(){
    return this.LatLongs;
}
VEPolyline.prototype.SetColor=SetColor;VEPolyline.prototype.SetWidth=SetWidth;VEPolyline.prototype.GetLatLongs=GetLatLongs;function VEColor(r,g,b,a){
    try{
        VEValidator.ValidateInt(r,"r");VEValidator.ValidateInt(g,"g");VEValidator.ValidateInt(b,"b");VEValidator.ValidateFloat(a,"a");this.R=r;this.G=g;this.B=b;this.A=a;
    }
    catch(ex){
        throw ex;return;
    }
    
}
VE_CollectionActions=function(){
    
}
;VE_CollectionActions.Create="CreateCollection";VE_CollectionActions.Update="UpdateCollection";VE_CollectionActions.RetrieveAll="RetrieveAllCollections";VE_CollectionActions.RetrieveDetails="RetrieveCollectionDetails";VE_CollectionActions.Delete="DeleteCollection";VE_CollectionActions.DeleteAll="DeleteAllCollections";VE_CollectionActions.DeleteAllAnnotations="DeleteAllAnnotations";VE_AnnotationActions=function(){
    
}
;VE_AnnotationActions.Create="CreateAnnotation";VE_AnnotationActions.Delete="DeleteAnnotation";VE_AnnotationActions.Update="UpdateAnnotation";VE_AnnotationActions.RetrieveAll="RetrieveAllAnnotations";VE_AnnotationState=function(){
    
}
;VE_AnnotationState.None="None";VE_AnnotationState.Added="Added";VE_AnnotationState.Updated="Updated";VE_AnnotationState.Deleted="Deleted";VE_CollectionsManagerConstants=function(){
    
}
;VE_CollectionsManagerConstants.Handler="UserCollections.aspx?action=";VE_CollectionsManagerConstants.Market="mkt=";VE_CollectionsManagerConstants.Random="rand=";VE_CollectionsManagerConstants.A_Id="aid";VE_CollectionsManagerConstants.A_Title="atitle";VE_CollectionsManagerConstants.A_Latitude="alatitude";VE_CollectionsManagerConstants.A_Longitude="alongitude";VE_CollectionsManagerConstants.A_Notes="anotes";VE_CollectionsManagerConstants.A_Keywords="akeywords";VE_CollectionsManagerConstants.A_IconId="aiconid";VE_CollectionsManagerConstants.A_InfoUrl="aurl";VE_CollectionsManagerConstants.A_PhotoUrl="aphotourl";VE_CollectionsManagerConstants.A_UserDate="auserdate";VE_CollectionsManagerConstants.A_DisplayOrder="adisplayorder";VE_CollectionsManagerConstants.A_BusinessId="abusinesslistingid";VE_CollectionsManagerConstants.A_CreationId="acreationid";VE_CollectionsManagerConstants.A_State="astate";VE_CollectionsManagerConstants.C_Id="cid";VE_CollectionsManagerConstants.C_Name="cname";VE_CollectionsManagerConstants.C_IsPublic="cispublic";VE_CollectionsManagerConstants.C_Length="cannotationcount";VE_CollectionsManagerConstants.C_Keywords="ckeywords";VE_CollectionsManagerConstants.ViewerDefaultTitle=L_CollectionManagerViewerDefaultTitle_Text;VE_CollectionsManagerConstants.MinimizedTimerDelay=1;VE_CollectionsManagerConstants.TimerDelay=2000;VE_CollectionsManagerConstants.ExtendedTimerDelay=5000;VE_CollectionsManagerConstants.MAX_COLLECTION_SIZE=200;VE_CollectionsManagerConstants.HELP_FILE_PATH="/cPublicPrivate.htm";VE_Annotation=function(ex,gx,hx,jx,kx,lx,mx,nx,ox,px,qx,rx,sx){
    this.Id=ex;if(gx!=null&&gx!="undefined")this.Title=gx.replace(/%0D%0A/g,"\r\n").replace(/%0A/g,"\n");else this.Title=gx;this.Latitude=mx;this.Longitude=nx;this.Notes=lx;if(this.Notes!=null)this.Notes=this.Notes.replace(/%0D%0A/g,"\r\n").replace(/%0A/g,"\n");if(sx!=null&&sx.length>0&&sx[0]!=null){
        this.Keywords=sx;this.Keywords[0]=this.Keywords[0].replace(/%0D%0A/g,"\r\n").replace(/%0A/g,"\n");
    }
    else this.Keywords=sx;this.Url=hx;this.PhotoUrl=jx;this.UserDate=kx;this.DisplayOrder=px;this.BusinessListingId=ox;this.IconId=qx;this.LastModified=rx;this.Delta=0;this.MoveUp=function(){
        this.Delta=this.Delta-1;
    }
    ;this.MoveDown=function(){
        this.Delta=this.Delta+1;
    }
    ;this.State=VE_AnnotationState.None;this.PushPin="";
}
;var L_integerencodingoutofrange_text="VEIntegerEncoding: The number encoded is out of supported range";var L_floatintegermapencodingoutofrange_text="VEFloatIntegerMap: The number encoded is out of supported range";var L_integerencodinginvalidstringlength_text="VEIntegerEncoding: Invalid string length";var L_integerencodingunknowndigit_text="VEIntegerEncoding: The encoded string has an unknown digit";function VEIntegerEncoding(tx,ux){
    var m_digits=tx;var m_base=tx.length;var m_valueLength=ux;var power=1;for(var i=0;i<m_valueLength;++i){
        power*=m_base;
    }
    var m_maxValue=power-1;var m_digitMap=new Array();for(var digitValue=0;digitValue<m_digits.length;++digitValue){
        m_digitMap[m_digits.substr(digitValue,1)]=digitValue;
    }
    this.MaxValue=function(){
        return m_maxValue;
    }
    ;this.ValueLength=function(){
        return m_valueLength;
    }
    ;this.Encode=function(vx){
        if(vx<=m_maxValue){
            var encodedString="";var digitValues=new Array();for(var i=0;i<m_valueLength;++i){
                digitValues[i]=0;
            }
            var digitIndex=m_valueLength-1;while(vx>0){
                digitValues[digitIndex]=Math.floor(vx%m_base);vx=Math.floor(vx/m_base);--digitIndex;
            }
            for(var i=0;i<digitValues.length;++i){
                encodedString+=m_digits.substr(digitValues[i],1);
            }
            return encodedString;
        }
        else throw L_integerencodingoutofrange_text;
    }
    ;this.Decode=function(wx){
        if(wx.length==m_valueLength){
            var numValue=0;for(var i=0;i<wx.length;++i){
                numValue*=m_base;numValue+=this.DigitValue(wx.substr(i,1));
            }
            return numValue;
        }
        else throw L_integerencodinginvalidstringlength_text;
    }
    ;this.DigitValue=function(xx){
        if(m_digitMap[xx]!=null&&m_digitMap[xx]!="undefined")return m_digitMap[xx];else throw L_integerencodingunknowndigit_text;
    }
    ;
}
function VEFloatIntegerMap(yx,zx,Ax){
    var m_minFloat=yx;var m_maxFloat=zx;var m_maxInt=Ax;this.MinFloat=function(){
        return m_minFloat;
    }
    ;this.MaxFloat=function(){
        return m_maxFloat;
    }
    ;this.MaxInt=function(){
        return m_maxInt;
    }
    ;this.FloatToInt=function(Bx){
        if(Bx>=m_minFloat&&Bx<=m_maxFloat){
            var fraction=(Bx-m_minFloat)/(m_maxFloat-m_minFloat);var intValue=fraction*m_maxInt+0.5;return Math.min(Math.floor(intValue),m_maxInt);
        }
        else throw L_floatintegermapencodingoutofrange_text;
    }
    ;this.IntToFloat=function(Cx){
        if(Cx<=m_maxInt){
            var fraction=Cx/m_maxInt;var floatNumber=m_minFloat+fraction*(m_maxFloat-m_minFloat);return floatNumber;
        }
        else throw L_floatintegermapencodingoutofrange_text;
    }
    ;
}
var L_velatlongencodinginvalidstringlength_text="VELatLongEncoding: Invalid string length";function VELatLongEncoding(){
    var m_minLatitude=-90;var m_maxLatitude=90;var m_minLongitude=-180;var m_maxLongitude=180;var m_digits="0123456789bcdfghjkmnpqrstvwxyz";var m_valueLength=6;var m_integerEncoding=new VEIntegerEncoding(m_digits,m_valueLength);var m_latitudeMap=new VEFloatIntegerMap(m_minLatitude,m_maxLatitude,m_integerEncoding.MaxValue());var m_longitudeMap=new VEFloatIntegerMap(m_minLongitude,m_maxLongitude,m_integerEncoding.MaxValue());this.Encode=function(Dx,Ex){
        var s=m_integerEncoding.Encode(m_latitudeMap.FloatToInt(Dx))+m_integerEncoding.Encode(m_longitudeMap.FloatToInt(Ex));return s;
    }
    ;this.Decode=function(Fx){
        if(Fx.length==2*m_integerEncoding.ValueLength()){
            var valueLength=m_integerEncoding.ValueLength();var strLatitude=Fx.substr(0,valueLength);var strLongitude=Fx.substr(valueLength,valueLength);var intLatitude=m_integerEncoding.Decode(strLatitude);var intLongitude=m_integerEncoding.Decode(strLongitude);var latLongArray=new Array();latLongArray[0]=m_latitudeMap.IntToFloat(intLatitude);latLongArray[1]=m_longitudeMap.IntToFloat(intLongitude);return latLongArray;
        }
        else throw L_velatlongencodinginvalidstringlength_text;
    }
    ;
}
VEMapStyle=new function(){
    this.Road=Msn.VE.MapStyle.Road;this.Aerial=Msn.VE.MapStyle.Aerial;this.Hybrid=Msn.VE.MapStyle.Hybrid;this.Oblique=Msn.VE.MapStyle.Oblique;this.Birdseye=Msn.VE.MapStyle.Oblique;
}
();VEOrientation=new function(){
    this.North=Msn.VE.Orientation.North;this.East=Msn.VE.Orientation.East;this.West=Msn.VE.Orientation.West;this.South=Msn.VE.Orientation.South;this.SouthWest="Southwest";this.NorthEast="Northeast";this.SouthEast="Southeast";this.NorthWest="Northwest";
}
();function VEBirdseyeScene(Gx){
    VEValidator.ValidateNonNull(Gx,"obliqueScene");var m_obliqueScene=Gx;var m_veLatLongFactory=new VELatLongFactory(new VELatLongFactoryAlwaysEncodeSpec());var m_veLatLongDecoder=new VELatLongDecoder();this.PixelToLatLong=function(x,y,Hx){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - PixelToLatLong");var pixel=new Msn.VE.Pixel(x,y);var latLong=m_obliqueScene.PixelToLatLong(pixel,Hx);return m_veLatLongFactory.CreateVELatLong(latLong.latitude,latLong.longitude);
    }
    ;this.LatLongToPixel=function(Ix,Jx){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - LatLongToPixel");VEValidator.ValidateObject(Ix,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(Ix);var latLong=new Msn.VE.LatLong(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);return m_obliqueScene.LatLongToPixel(latLong,Jx);
    }
    ;this.IsValidTile=function(Kx,Lx,Mx){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - IsValidTile");return m_obliqueScene.IsValidTile(Kx,Lx,Mx);
    }
    ;this.GetID=function(){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetID");return m_obliqueScene.GetID();
    }
    ;this.GetTileFilename=function(Nx,Ox,Px){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetTileFilename");return m_obliqueScene.GetTileFilename();
    }
    ;this.GetThumbnailFilename=function(){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetThumbnailFilename");return m_obliqueScene.GetThumbnailFilename();
    }
    ;this.GetNeighbor=function(i){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetNeighbor");var neighbor=null;var scene=m_obliqueScene.neighborScenes[i];if(scene!=null){
            neighbor=new Msn.VE.ObliqueScene(scene);return new VEBirdseyeScene(neighbor);
        }
        return null;
    }
    ;this.GetRotation=function(i){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetRotation");var rotation=null;var scene=m_obliqueScene.GetRotation(i);if(scene!=null)rotation=new VEBirdseyeScene(scene);return rotation;
    }
    ;this.GetOrientation=function(){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetOrientation");return m_obliqueScene.GetOrientation();
    }
    ;this.GetBounds=function(){
        return m_obliqueScene.GetBounds();
    }
    ;this.GetWidth=function(){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetWidth");return m_obliqueScene.GetWidth();
    }
    ;this.GetHeight=function(){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - GetHeight");return m_obliqueScene.GetHeight();
    }
    ;this.ContainsLatLong=function(Qx){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - ContainsLatLong");VEValidator.ValidateObject(Qx,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(Qx);var latLong=new Msn.VE.LatLong(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);return m_obliqueScene.ContainsLatLong(latLong);
    }
    ;this.ContainsPixel=function(x,y,Rx){
        VE_Analytics.LogAPI("VE | APIs","VEBirdseyeScene - ContainsPixel");var pixel=new Msn.VE.Pixel(x,y);return m_obliqueScene.ContainsPixel(pixel,Rx);
    }
    ;
}
function VE_Analytics(){
    
}
function VE_Range(Sx,Tx){
    this.min=Sx;this.max=Tx;
}
VE_Range.prototype.IsInRange=function(Ux){
    return Ux>=this.min&&Ux<=this.max;
}
;VE_Range.prototype.toString=function(){
    return this.min+"-"+this.max;
}
;VE_Analytics.distanceBuckets=new Array(new VE_Range(0,10),new VE_Range(11,25),new VE_Range(26,100),new VE_Range(101,200),new VE_Range(201,500),new VE_Range(501,1000));VE_Analytics.analyticsEnabled=true;VE_Analytics.LogHelp=function(){
    VE_Analytics.Log("VE | Help Pane","Help");
}
;VE_Analytics.LogAbout=function(){
    VE_Analytics.Log("VE | About Pane","About");
}
;VE_Analytics.LogPrintDetailsPage=function(){
    VE_Analytics.Log("VE | Details Page","Print");
}
;VE_Analytics.LogGetDirectionsDetailsPage=function(){
    VE_Analytics.Log("VE | Details Page","Get Directions");
}
;VE_Analytics.LogGetMoreInfoDetailsPage=function(){
    VE_Analytics.Log("VE | Details Page","MSN Search");
}
;VE_Analytics.LogLocate=function(){
    VE_Analytics.Log("VE | Locate Me","Locate Me");
}
;VE_Analytics.LogResponseTimes=function(){
    var tempVar=map.GetFailureRate()*100;s.prop33=tempVar.toFixed(1);tempVar=map.GetResponseRangeCounts()[0]*100;s.prop34=tempVar.toFixed(1);tempVar=map.GetResponseRangeCounts()[2]*100;s.prop35=tempVar.toFixed(1);VE_Analytics.Log("VE | Response Times");map.ResetResponseRangeCounts();
}
;VE_Analytics.LogZoom=function(){
    VE_Analytics.Log(map.GetMapStyle()==Msn.VE.MapStyle.Oblique?"VE | Oblique Imagery":"VE | Home Page","Zoom","Mouse/Game Control/Keyboard");
}
;VE_Analytics.LogPan=function(){
    VE_Analytics.Log(map.GetMapStyle()==Msn.VE.MapStyle.Oblique?"VE | Oblique Imagery":"VE | Home Page","Pan","Mouse/Game Control/Keyboard");
}
;VE_Analytics.LogFailedSearch=function(){
    s.prop11="No Search Results";VE_Analytics.Log("VE | Exception","Search");
}
;VE_Analytics.LogJSWatson=function(Vx){
    if(Vx!=null&&Vx!="undefined"&&Vx.length>0){
        s.prop11=Vx;VE_Analytics.Log("VE | Exception","JSWatson");
    }
    
}
;VE_Analytics.LogScrachPadItems=function(){
    s.prop12=VE_Scratchpad.highWaterCount;VE_Analytics.Log("VE | Scratch Pad","Exit");
}
;VE_Analytics.LogAds=function(Wx,Xx,Yx,Zx,ay,by){
    s.events=Xx;if(Wx==null||Wx=="undefined")s.eVar8=document.getElementById("what")?document.getElementById("what").value==L_MainWhatHelp_Text?"":document.getElementById("what").value:"";else s.eVar8=Wx;s.eVar9=document.getElementById("where")?document.getElementById("where").value==L_SearchUseCurrentViewText_Text?VE_Analytics.FormatLatLong(map.GetCenterLatitude(),map.GetCenterLongitude()):document.getElementById("where").value:"";if(Xx=="Event6")s.eVar11=ay;else s.eVar10=Zx;if(by!=null&&by!="undefined")s.eVar12=by;else s.eVar12="";VE_Analytics.Log("VE | "+Yx,null);
}
;VE_Analytics.SetCampaignId=function(cy){
    if(cy!=null&&cy!=""&&cy!="undefined"){
        if(s){
            s.campaign=cy;VE_Analytics.Log("VE | Home Page","Campaign Page View");
        }
        
    }
    
}
;VE_Analytics.LogClick2Call=function(ey){
    if(ey!=null&&ey!="undefined"){
        if(ey=="1")VE_Analytics.Log("VE | Search Pane ERO","C2C call Entry Point");else{
            if(ey=="2")VE_Analytics.Log("VE | Map ERO","C2C call Entry Point");else{
                if(ey=="3")VE_Analytics.Log("VE | Details Page","C2C call Entry Point");else VE_Analytics.Log("VE | Click-2-Call","C2C call Entry Point");
            }
            
        }
        
    }
    else VE_Analytics.Log("VE | Click-2-Call","C2C call entry point");
}
;VE_Analytics.LogAPI=function(gy,hy){
    return;if(window.s=="undefined"||window.s==null)return;if(!VE_Analytics.analyticsEnabled)return;s.pageName=gy;s.prop6=hy?hy:"";var elm=document.getElementById("logging");if(elm)elm.innerHTML=s.t();VE_Analytics.ResetLogProps();
}
;VE_Analytics.Log=function(jy,ky,ly,my){
    if(window.s=="undefined"||window.s==null)return;if(!VE_Analytics.analyticsEnabled)return;s.pageName=jy;s.prop3=window["map"]?map.GetMapStyle():"";s.prop4=window["map"]?map.GetZoomLevel():"";s.prop5=window["map"]?VE_Analytics.FormatLatLong(map.GetCenterLatitude(),map.GetCenterLongitude()):"";s.prop6=ky?ky:"";s.prop7=ly?ly:"";s.prop8=document.getElementById("what")?document.getElementById("what").value==L_MainWhatHelp_Text?"":document.getElementById("what").value:"";s.prop9=document.getElementById("where")?document.getElementById("where").value==L_SearchUseCurrentViewText_Text?"":document.getElementById("where").value:"";s.prop36=window.usertype==undefined?1:usertype;if(my){
        s.prop10=VE_Analytics.ConvertDistanceToBucket(my);s.prop32=my.numberOfWaypoints;
    }
    else s.prop10="";var elm=document.getElementById("logging");if(elm)elm.innerHTML=s.t();VE_Analytics.ResetLogProps();
}
;VE_Analytics.FormatLatLong=function(ny,oy){
    if(!ny||!oy){
        if(state&&state.GetLatitude()&&state.GetLongitude())return state.GetLatitude().toFixed(1)+","+Math.round(state.GetLongitude());return "0.0,0";
    }
    return ny.toFixed(1)+","+Math.round(oy);
}
;VE_Analytics.ConvertDistanceToBucket=function(py){
    var distance=py.distance;if(!distance)return "";if(py.distanceUnit&&py.distanceUnit.indexOf("mi")!=-1)distance=Math.round(distance*1.6093);for(var i=0;i<VE_Analytics.distanceBuckets.length;i++){
        if(VE_Analytics.distanceBuckets[i].IsInRange(distance))return VE_Analytics.distanceBuckets[i].toString();
    }
    return "1001 and Above";
}
;VE_Analytics.ResetLogProps=function(){
    s.prop11="";s.prop12="";s.prop32="";s.prop33="";s.prop34="";s.prop35="";s.events="";s.eVar8="";s.eVar9="";s.eVar10="";s.eVar11="";s.eVar12="";s.campaign="";
}
;var Microsoft;if(!Microsoft)Microsoft={
    
}
;if(!Microsoft.Web)Microsoft.Web={
    
}
;Microsoft.Web.Css={
    "Style":{
        "Height":0,"Width":1,"Top":2,"Left":3,"Bottom":4,"Right":5,"Position":6,"Margin":7,"Padding":8,"Display":9,"Visibility":10
    }
    ,"Units":{
        "Auto":"auto","Pixels":"px","Points":"pt","Ems":"em","Percentage":"%"
    }
    ,"Position":{
        "Static":"static","Relative":"relative","Absolute":"absolute"
    }
    ,"Display":{
        "None":"none","Block":"block","Table":"table","Inline":"inline"
    }
    ,"Visibility":{
        "Visible":"visible","Hidden":"hidden"
    }
    ,"Cursors":{
        "Auto":"auto","Default":"default","Crosshair":"crosshair","Pointer":"pointer","Move":"move","Wait":"wait","Text":"text","Help":"help","NResize":"n-resize","NEResize":"ne-resize","NWResize":"nw-resize","SResize":"s-resize","SEResize":"se-resize","SWResize":"sw-resize","EResize":"e-resize","WResize":"w-resize"
    }
    
}
;var Microsoft;if(!Microsoft)Microsoft={
    
}
;if(!Microsoft.Web)Microsoft.Web={
    
}
;Microsoft.Web.Animation={
    "AccelerationFunction":function(qy){
        var self=this;var m_nTotal=-1;var m_nSteps=-1;var m_pFn=qy;this.setSteps=function(ry){
            m_nSteps=ry;ty();
        }
        ;this.getValue=function(sy){
            return m_pFn(sy)/m_nTotal;
        }
        ;function ty(){
            m_nTotal=0;for(var i=0;i<m_nSteps;i++){
                m_nTotal+=m_pFn(i/m_nSteps);
            }
            
        }
        
    }
    ,"Movie":function(uy,vy){
        var self=this;this.Repeat=true;this.AppendContent=true;var m_frames=new Array();var m_counter=-1;var m_intervalId=null;this.addFrame=function(wy,xy){
            if(xy==null)xy=true;var f={
                "data":wy,"append":xy
            }
            ;m_frames.push(f);
        }
        ;this.start=function(){
            self.stop();self.show();self.clear();m_counter=-1;m_intervalId=setInterval(yy,vy);
        }
        ;this.stop=function(){
            if(m_intervalId)clearInterval(m_intervalId);
        }
        ;this.show=function(){
            uy.style.visibility="visible";
        }
        ;this.hide=function(){
            uy.style.visibility="hidden";
        }
        ;this.clear=function(){
            uy.innerHTML="";
        }
        ;function yy(){
            m_counter++;if(m_counter>m_frames.length-1){
                m_counter=0;if(!self.Repeat){
                    clearInterval(m_intervalId);return;
                }
                else self.clear();
            }
            var f=m_frames[m_counter];if(f.append)uy.innerHTML+=f.data;else uy.innerHTML=f.data;
        }
        
    }
    ,"RollDirection":{
        "TopDown":0,"RightLeft":1,"BottomUp":2,"LeftRight":3,"Count":4
    }
    ,"RollStyle":{
        "In":0,"Out":1
    }
    ,"Roller":function(zy,Ay){
        var self=this;var css=Microsoft.Web.Css;var ani=Microsoft.Web.Animation;var m_elem=zy;var m_pals=null;var m_isExpanded=true;this.LeaveAmount=typeof Ay=="number"?Ay:10;this.AccFunction=null;this.Factor=null;this.onbeforerollin=null;this.onafterrollin=null;this.onbeforerollout=null;this.onafterrollout=null;this.isExpanded=function(){
            return m_isExpanded;
        }
        ;this.associate=function(By){
            m_pals=By;
        }
        ;this.rollIn=function(Cy){
            My(m_elem);Ey(ani.RollStyle.In,Cy);m_isExpanded=false;
        }
        ;this.rollOut=function(Dy){
            Qy(m_elem);Ey(ani.RollStyle.Out,Dy);m_isExpanded=true;
        }
        ;function Ey(Fy,Gy){
            if(!self.AccFunction)self.AccFunction=AccelerationFunctions.ExponentialAcc;if(!self.Factor)self.Factor=15;var size;if(Gy==ani.RollDirection.TopDown||Gy==ani.RollDirection.BottomUp)size=m_elem.offsetHeight;else size=m_elem.offsetWidth;var rollDistance=size-self.LeaveAmount;if(Gy==ani.RollDirection.TopDown||Gy==ani.RollDirection.LeftRight){
                size=0;if(Fy==ani.RollStyle.Out)size=self.LeaveAmount;
            }
            else{
                if(Fy==ani.RollStyle.Out)size-=self.LeaveAmount;
            }
            var steps=Math.ceil(rollDistance/10);if(steps<50)steps=50;self.AccFunction.setSteps(steps);for(var i=1;i<=steps;i++){
                var percentComplete=i/steps;setTimeout(Hy(percentComplete),i*self.Factor);
            }
            function Hy(Iy){
                return function(){
                    var fnX=self.AccFunction.getValue(Iy)*rollDistance;if(Gy==ani.RollDirection.TopDown||Gy==ani.RollDirection.LeftRight)size+=fnX;else size-=fnX;var dir=Gy;if(Fy==ani.RollStyle.Out)dir=(Gy+ani.RollDirection.Count/2)%ani.RollDirection.Count;var clip=Jy(dir,size);m_elem.style.clip=clip;if(m_pals)for(var i=0;i<m_pals.length;i++){
                        m_pals[i].style.left=size+"px";
                    }
                    if(Iy==1){
                        if(Fy==ani.RollStyle.In)Oy(m_elem);else{
                            m_elem.style.clip="rect(auto auto auto auto)";Sy(m_elem);
                        }
                        
                    }
                    
                }
                ;
            }
            
        }
        function Jy(Ky,Ly){
            var topClip;var rightClip;var bottomClip;var leftClip;topClip=rightClip=bottomClip=leftClip=css.Units.Auto;var sizeClip=parseInt(Math.round(Ly))+css.Units.Pixels;switch(Ky){
                case ani.RollDirection.TopDown:topClip=sizeClip;break;case ani.RollDirection.RightLeft:rightClip=sizeClip;break;case ani.RollDirection.BottomUp:bottomClip=sizeClip;break;case ani.RollDirection.LeftRight:leftClip=sizeClip;break;
            }
            var clip="rect("+topClip+" "+rightClip+" "+bottomClip+" "+leftClip+")";return clip;
        }
        function My(Ny){
            if(self.onbeforerollin)self.onbeforerollin(Ny);
        }
        function Oy(Py){
            if(self.onafterrollin)self.onafterrollin(Py);
        }
        function Qy(Ry){
            if(self.onbeforerollout)self.onbeforerollout(Ry);
        }
        function Sy(Ty){
            if(self.onafterrollout)self.onafterrollout(Ty);
        }
        
    }
    ,"Slider":function(Uy){
        var self=this;var geo=Microsoft.Web.Geometry;var m_elem=Uy;var m_displacement=0;var m_currentX;this.EasingFunction=null;this.Factor=null;this.slideToPoint=function(Vy){
            if(!self.AccFunction)self.AccFunction=AccelerationFunctions.Linear;if(!self.Factor)self.Factor=10;var startPoint=geo.Functions.getElementPosition(m_elem);var currentX=startPoint.x;var currentY=startPoint.y;var m=geo.Functions.getSlope(startPoint,Vy);var b=geo.Functions.getYIntercept(m,Vy);var distance=Math.abs(startPoint.x-Vy.x);var steps=Math.ceil(distance/10);if(steps<50)steps=50;self.AccFunction.setSteps(steps);for(var i=0;i<steps;i++){
                var percentComplete=i/steps;setTimeout(Wy(percentComplete),i*self.Factor);
            }
            function Wy(Xy){
                return function(){
                    if(Vy.x>startPoint.x)currentX+=self.AccFunction.getValue(Xy)*distance;else currentX-=self.AccFunction.getValue(Xy)*distance;var currentY=m*currentX+b;m_elem.style.left=parseFloat(Math.round(currentX))+"px";m_elem.style.top=parseFloat(Math.round(currentY))+"px";
                }
                ;
            }
            
        }
        ;
    }
    
}
;var AccelerationFunctions={
    "Linear":new Microsoft.Web.Animation.AccelerationFunction(function(Yy){
        return 1;
    }
    ),"ExponentialAcc":new Microsoft.Web.Animation.AccelerationFunction(function(Zy){
        var lower=0;var upper=1;var range=upper-lower;var x=lower+Zy*range;var fnX=Math.pow(x,2);return fnX;
    }
    ),"ExponentialDec":new Microsoft.Web.Animation.AccelerationFunction(function(az){
        var lower=-1;var upper=0;var range=upper-lower;var x=lower+az*range;var fnX=Math.pow(x,2);return fnX;
    }
    ),"CosineWave":new Microsoft.Web.Animation.AccelerationFunction(function(bz){
        var lower=-Math.PI;var upper=Math.PI;var range=upper-lower;var x=lower+bz*range;var fnX=Math.cos(x)+1;return fnX;
    }
    ),"CrazyElevator":new Microsoft.Web.Animation.AccelerationFunction(function(cz){
        var lower=-5;var upper=5;var range=upper-lower;var x=lower+cz*range;var fnX=2/(Math.pow(Math.abs(x),3)+1);return fnX;
    }
    )
}
;var Microsoft;if(!Microsoft)Microsoft={
    
}
;if(!Microsoft.Web)Microsoft.Web={
    
}
;if(!Microsoft.Web.Geometry)Microsoft.Web.Geometry={
    
}
;Microsoft.Web.Geometry.Point=function(ez,gz){
    var self=this;var geo=Microsoft.Web.Geometry;this.x=ez;this.y=gz;this.add=function(hz,jz){
        var pt=new geo.Point(self.x+hz,self.y+jz);return pt;
    }
    ;this.getDistanceFrom=function(kz){
        var tmp=Math.pow(kz.x-self.x,2)+Math.pow(kz.y-self.y,2);var s=Math.sqrt(tmp);return s;
    }
    ;
}
;Microsoft.Web.Geometry.Overlap={
    "Range":{
        "GreaterThanX":1,"LessThanX":2,"GreaterThanY":4,"LessThanY":8,"InXRange":16,"InYRange":32,"InRange":48
    }
    ,"getInstance":function(lz,mz){
        var ol=Microsoft.Web.Geometry.Overlap;var m_r1=lz;var m_r2=mz;var m_range=0;nz();function nz(){
            if(m_r2.getP2().x>m_r1.getP2().x)m_range+=ol.Range.GreaterThanX;if(m_r2.getP1().x<m_r1.getP1().x)m_range+=ol.Range.LessThanX;if(m_r2.getP2().y>m_r1.getP2().y)m_range+=ol.Range.GreaterThanY;if(m_r2.getP1().y<m_r1.getP1().y)m_range+=ol.Range.LessThanY;if(m_r1.getP1().x<=m_r2.getP1().x&&m_r2.getP2().x<=m_r1.getP2().x)m_range+=ol.Range.InXRange;if(m_r1.getP1().y<=m_r2.getP1().y&&m_r2.getP2().y<=m_r1.getP2().y)m_range+=ol.Range.InYRange;
        }
        this.getRange=function(){
            return m_range;
        }
        ;this.getLeftXBleed=function(){
            if(m_range&ol.Range.LessThanX)return Math.abs(m_r1.getP1().x-m_r2.getP1().x);else return 0;
        }
        ;this.getRightXBleed=function(){
            if(m_range&ol.Range.GreaterThanX)return m_r2.getP2().x-m_r1.getP2().x;else return 0;
        }
        ;this.getTopYBleed=function(){
            if(m_range&ol.Range.LessThanY)return Math.abs(m_r1.getP1().y-m_r2.getP1().y);else return 0;
        }
        ;this.getBottomYBleed=function(){
            if(m_range&ol.Range.GreaterThanY)return m_r2.getP2().y-m_r1.getP2().y;else return 0;
        }
        ;
    }
    
}
;Microsoft.Web.Geometry.Rectangle=function(oz,pz){
    var self=this;var m_p1=oz;var m_p2=pz;var m_nHeight;var m_nWidth;qz();function qz(){
        wz();
    }
    this.move=function(rz){
        m_p1.x=rz.x;m_p1.y=rz.y;m_p2.x=rz.x+m_nWidth;m_p2.y=rz.y+m_nHeight;
    }
    ;this.getP1=function(){
        return m_p1;
    }
    ;this.getP2=function(){
        return m_p2;
    }
    ;this.setP1=function(sz){
        m_p1=sz;wz();
    }
    ;this.setP2=function(tz){
        m_p2=tz;wz();
    }
    ;this.getWidth=function(){
        return m_nWidth;
    }
    ;this.getHeight=function(){
        return m_nHeight;
    }
    ;this.containsPoint=function(uz){
        return uz.x>=m_p1.x&&uz.x<=m_p2.x&&uz.y>=m_p1.y&&uz.y<=m_p2.y;
    }
    ;this.getOverlap=function(vz){
        var geo=Microsoft.Web.Geometry;return new geo.Overlap.getInstance(self,vz);
    }
    ;function wz(){
        m_nHeight=m_p2.y-m_p1.y;m_nWidth=m_p2.x-m_p1.x;
    }
    
}
;Microsoft.Web.Geometry.Functions={
    "getSlope":function(xz,yz){
        return (yz.y-xz.y)/(yz.x-xz.x);
    }
    ,"getYIntercept":function(zz,Az){
        return Az.y-zz*Az.x;
    }
    ,"getElementPosition":function(Bz){
        var geo=Microsoft.Web.Geometry;var xPos=0;var yPos=0;while(Bz&&Bz.offsetParent){
            xPos+=Bz.offsetLeft-Bz.scrollLeft;yPos+=Bz.offsetTop-Bz.scrollTop;Bz=Bz.offsetParent;
        }
        return new geo.Point(xPos,yPos);
    }
    ,"getBestBoundingPoint":function(Cz,Dz,Ez){
        var geo=Microsoft.Web.Geometry;if(!Dz)Dz=geo.Functions.getElementPosition(Cz);var elemRect=new geo.Rectangle(Dz,new geo.Point(Dz.x+Cz.offsetWidth,Dz.y+Cz.offsetHeight));var ol=Ez.getOverlap(elemRect);var rng=ol.getRange();if((rng&geo.Overlap.Range.InRange)==geo.Overlap.Range.InRange)return Dz;var left=Dz.x;var top=Dz.y;if(rng&geo.Overlap.Range.GreaterThanX)left=Ez.getP2().x-elemRect.getWidth();if(rng&geo.Overlap.Range.LessThanX)left=Ez.getP1().x;if(rng&geo.Overlap.Range.GreaterThanY)top=Ez.getP2().y-elemRect.getHeight();if(rng&geo.Overlap.Range.LessThanY)top=Ez.getP1().y;return new geo.Point(left,top);
    }
    
}
;var Microsoft;if(!Microsoft)Microsoft={
    
}
;if(!Microsoft.Web)Microsoft.Web={
    
}
;if(!Microsoft.Web.UI)Microsoft.Web.UI={
    
}
;Microsoft.Web.UI.IEGlyphStates={
    "Unselected":"-unselected","Hover":"-hover","Pressed":"-pressed"
}
;Microsoft.Web.UI.IEGlyph=function(Fz,Gz){
    var ui=Microsoft.Web.UI;var m_elem;var m_stateHover;var m_statePressed;var m_defaultClass;Hz();function Hz(){
        m_elem=document.createElement("div");if(Fz)m_elem.id=Fz;m_defaultClass=Gz||"ieglyph";m_stateHover=m_defaultClass+ui.IEGlyphStates.Hover;m_statePressed=m_defaultClass+ui.IEGlyphStates.Pressed;m_elem.className=m_defaultClass;if(!document.all)return;m_elem.attachEvent("onmouseover",Kz);m_elem.attachEvent("onmousedown",Lz);m_elem.attachEvent("onmouseup",Kz);m_elem.attachEvent("onmouseout",Mz);window.attachEvent("onunload",Jz);
    }
    this.getElement=function(){
        return m_elem;
    }
    ;this.setContent=function(Iz){
        m_elem.innerHTML=Iz;
    }
    ;function Jz(){
        m_elem.detachEvent("onmouseover",Kz);m_elem.detachEvent("onmousedown",Lz);m_elem.detachEvent("onmouseup",Kz);m_elem.detachEvent("onmouseout",Mz);m_elem=null;m_stateHover=null;m_statePressed=null;m_defaultClass=null;
    }
    function Kz(){
        Mz();Nz(m_stateHover);
    }
    function Lz(){
        Nz(m_statePressed);
    }
    function Mz(){
        Pz(m_stateHover);Pz(m_statePressed);
    }
    function Nz(Oz){
        m_elem.className+=" "+Oz;
    }
    function Pz(Qz){
        var regex=new RegExp(" "+Qz,"g");m_elem.className=m_elem.className.replace(regex,"");
    }
    
}
;var ERO={
    "Classes":{
        "Container":"ero","Shadow":"ero-shadow","Body":"ero-body","Actions":"ero-actions","ActionsBackground":"ero-actionsBackground","PreviewArea":"ero-previewArea","LeftBeak":"ero-leftBeak","RightBeak":"ero-rightBeak","PaddingHack":"ero-paddingHack","ProgressAnimation":"ero-progressAnimation"
    }
    ,"BeakDirection":{
        "Right":0,"Left":1
    }
    ,"DockPosition":{
        "Top":0,"Center":1
    }
    ,"m_theEro":null,"BeakHeight":34,"getInstance":function(Rz){
        var geo=Microsoft.Web.Geometry;if(!ERO.m_theEro){
            ERO.m_theEro=new Sz();ERO.m_theEro.setBoundingArea(new geo.Point(0,5),new geo.Point(document.body.clientWidth,document.body.clientHeight));
        }
        ERO.m_theEro.addToPage();return ERO.m_theEro;function Sz(){
            var self=this;var m_boundingArea=null;var m_entity=null;var m_bIsInUse=false;var ero=document.createElement("div");ero.className=ERO.Classes.Container;if(typeof ero.addEventListener!="undefined"){
                ero.addEventListener("mouseover",mA,false);ero.addEventListener("mouseout",nA,false);
            }
            else{
                ero.attachEvent("onmouseover",mA);ero.attachEvent("onmouseout",nA);
            }
            var eroShadow=document.createElement("div");eroShadow.className=ERO.Classes.Shadow;var eroBody=document.createElement("div");eroBody.className=ERO.Classes.Body;var eroActions=document.createElement("div");eroActions.className=ERO.Classes.Actions;var eroActionsList=document.createElement("ul");var eroActionsBackground=document.createElement("div");eroActionsBackground.className=ERO.Classes.ActionsBackground;var eroPreviewArea=document.createElement("div");eroPreviewArea.className=ERO.Classes.PreviewArea;var eroBeak=document.createElement("div");eroBeak.className=ERO.Classes.LeftBeak;var eroPaddingHack=document.createElement("div");eroPaddingHack.className=ERO.Classes.PaddingHack;ero.appendChild(eroShadow);ero.appendChild(eroBeak);eroShadow.appendChild(eroBody);eroBody.appendChild(eroActionsBackground);eroActionsBackground.appendChild(eroPreviewArea);eroActionsBackground.appendChild(eroActions);eroActions.appendChild(eroActionsList);eroActionsBackground.appendChild(eroPaddingHack);var prog=document.createElement("div");prog.className=ERO.Classes.ProgressAnimation;var ani=new Microsoft.Web.Animation.Movie(prog,75);ani.addFrame("<div class = \"frame1\"></div>");ani.addFrame("<div class = \"frame2\"></div>");ani.addFrame("<div class = \"frame3\"></div>");ani.addFrame("");ani.addFrame("");ani.addFrame("<div class = \"frame2\"></div><div class = \"frame3\"></div>",false);ani.addFrame("<div class = \"frame3\"></div>",false);ani.Repeat=false;this.destroy=function(){
                if(ero){
                    if(typeof ero.removeEventListener!="undefined"){
                        ero.removeEventListener("mouseover",mA,false);ero.removeEventListener("mouseout",nA,false);
                    }
                    else{
                        ero.detachEvent("onmouseover",mA);ero.detachEvent("onmouseout",nA);
                    }
                    ero=null;eroShadow=null;eroBody=null;eroActions=null;eroActionsList=null;eroActionsBackground=null;eroPreviewArea=null;eroBeak=null;eroPaddingHack=null;
                }
                m_entity=null;
            }
            ;this.getElement=function(){
                return ero;
            }
            ;this.getAnimation=function(){
                return ani;
            }
            ;this.setBeak=function(Tz,Uz){
                if(Tz==ERO.BeakDirection.Right)eroBeak.className=ERO.Classes.RightBeak;else eroBeak.className=ERO.Classes.LeftBeak;
            }
            ;this.setContent=function(Vz){
                var div=document.createElement("div");div.className="firstChild";div.innerHTML=Vz;var firstChild=eroPreviewArea.firstChild;if(firstChild)eroPreviewArea.replaceChild(div,firstChild);else eroPreviewArea.appendChild(div);div=null;firstChild=null;
            }
            ;this.addAction=function(Wz){
                var li=document.createElement("li");if(!Wz)return;li.innerHTML=Wz;eroActionsList.appendChild(li);li=null;
            }
            ;this.clearActions=function(){
                var children=eroActionsList.getElementsByTagName("li");var len=children.length;for(var i=0;i<len;i++){
                    eroActionsList.removeChild(children[0]);
                }
                
            }
            ;this.dockToText=function(Xz,Yz){
                self.display(Xz,ERO.DockPosition.Top,Yz);
            }
            ;this.dockToElement=function(Zz){
                self.display(Zz,ERO.DockPosition.Center);
            }
            ;this.display=function(aA,bA,cA){
                cA=typeof cA!="undefined"?cA:typeof window.event!="undefined"?window.event:null;m_bIsInUse=true;m_entity=aA;self.addToPage();var UNITS="px";var p=geo.Functions.getElementPosition(aA);var beakYOffset=eroPreviewArea.offsetHeight-ERO.BeakHeight;var x;var y;if(bA==ERO.DockPosition.Top){
                    var mouseX;if(cA==null)mouseX=p.x;else mouseX=typeof event.pageX!="undefined"?cA.pageX:cA.clientX;prog.style.top=p.y-prog.offsetHeight-2+UNITS;prog.style.left=mouseX+UNITS;x=mouseX+prog.offsetWidth+2;y=p.y-beakYOffset-ERO.BeakHeight/2-prog.offsetHeight;
                }
                else{
                    prog.style.top=p.y-prog.offsetHeight-2+UNITS;prog.style.left=p.x+aA.offsetWidth-prog.offsetWidth+UNITS;x=p.x+aA.offsetWidth;y=p.y-beakYOffset;
                }
                var r1=self.getSize();var eroHeight=r1.getP2().y-r1.getP1().y;var eroWidth=r1.getP2().x-r1.getP1().x;var r2=new geo.Rectangle(new geo.Point(x,y),new geo.Point(x+eroWidth,y+eroHeight));var ol=m_boundingArea.getOverlap(r2);var rng=ol.getRange();self.setBeak(ERO.BeakDirection.Left);var top;var right;var bottom;var left;top=right=bottom=left="auto";if(rng&geo.Overlap.Range.InXRange)left=x;if(rng&geo.Overlap.Range.InYRange)top=y;if(rng&geo.Overlap.Range.GreaterThanX){
                    self.setBeak(ERO.BeakDirection.Right);if(x>m_boundingArea.getP2().x)right=document.body.clientWidth-m_boundingArea.getP2().x;else left=x-eroWidth-aA.offsetWidth;
                }
                if(rng&geo.Overlap.Range.LessThanX){
                    self.setBeak(ERO.BeakDirection.Left);left=m_boundingArea.getP1().x;
                }
                if(rng&geo.Overlap.Range.GreaterThanY){
                    bottom=document.body.clientHeight-m_boundingArea.getP2().y;var yBleed=ol.getBottomYBleed();beakYOffset+=yBleed;if(beakYOffset>ero.offsetHeight-ERO.BeakHeight)beakYOffset=ero.offsetHeight-ERO.BeakHeight-4;
                }
                if(rng&geo.Overlap.Range.LessThanY){
                    top=m_boundingArea.getP1().y;var yBleed=ol.getTopYBleed();beakYOffset-=yBleed;if(beakYOffset<0)beakYOffset=0;
                }
                ani.start();setTimeout(eA,500);function eA(){
                    if(m_entity!=aA)return;ero.style.top=top=="auto"?top:top+UNITS;ero.style.bottom=bottom=="auto"?bottom:bottom+UNITS;ero.style.left=left=="auto"?left:left+UNITS;ero.style.right=right=="auto"?right:right+UNITS;eroBeak.style.top=beakYOffset+"px";gA();
                }
                
            }
            ;function gA(){
                if(ero.style&&typeof ero.style.filter!="undefined"){
                    ero.style.filter="progid:DXImageTransform.Microsoft.Fade(duration=.5)";ero.filters[0].Apply();ero.style.visibility="visible";ero.style.display="block";ero.filters[0].Play();
                }
                else{
                    window.__eroFadeValue__=1;ero.style.visibility="visible";ero.style.display="block";ero.style.opacity=0;var i;for(i=1;i<=10;i++){
                        setTimeout(function(){
                            var opacity=__eroFadeValue__++*0.09999999;ero.style.opacity=opacity;
                        }
                        ,50*i);
                    }
                    
                }
                
            }
            this.hide=function(hA){
                m_bIsInUse=false;if(hA&&hA==true)jA();else setTimeout(jA,500);function jA(){
                    if(!m_bIsInUse){
                        ero.style.visibility="hidden";ani.hide();m_entity=null;
                    }
                    
                }
                
            }
            ;this.setBoundingArea=function(kA,lA){
                m_boundingArea=new geo.Rectangle(kA,lA);
            }
            ;this.isInUse=function(){
                return m_bIsInUse;
            }
            ;this.addToPage=function(){
                ero.style.visibility="hidden";prog.style.visibility="hidden";document.body.appendChild(ero);document.body.appendChild(prog);
            }
            ;this.getSize=function(){
                var x1=ero.offsetLeft;var y1=ero.offsetTop;var x2=x1+ero.offsetWidth;var y2=y1+ero.offsetHeight;var size=new geo.Rectangle(new geo.Point(x1,y1),new geo.Point(x2,y2));return size;
            }
            ;function mA(){
                m_bIsInUse=true;
            }
            function nA(){
                self.hide();
            }
            
        }
        
    }
    
}
;if(!(navigator.userAgent.indexOf("IE")>=0))VENetwork.DownloadScript(Msn.VE.API.Constants.atlascompatjs,DownloadMapStyles);else DownloadMapStyles();function DownloadMapStyles(){
    VENetwork.AttachStyleSheet(Msn.VE.API.Constants.erostylesheet);VENetwork.AttachStyleSheet(Msn.VE.API.Constants.stylesheet);
}
function VEMap(oA){
    var self=this;this.ID=oA;this.GUID=VENetwork.GetExecutionID();if(Msn.VE.API.Globals.vemapinstances==null||Msn.VE.API.Globals.vemapinstances=="undefined")Msn.VE.API.Globals.vemapinstances=new Array();Msn.VE.API.Globals.vemapinstances[this.GUID]=this;this.network=new VENetwork();this.mapelement=document.getElementById(oA);this.pushpins=new Array();if(this.mapelement==null)throw new VEException("VEMap:cstr","err_invalidelement",L_invalidelement_text);this.m_vedirectionsmanager=new VEDirectionsManager(this);this.m_vedirectionsmanager.Initialize();this._dm=this.m_vedirectionsmanager;this.m_vesearchmanager=new VE_SearchManager(this);this.m_vesearchmanager.Initialize();this._sm=this.m_vesearchmanager;this.m_vemessage=new VEMessage(this);this.m_veambiguouslist=new VEAmbiguouslist(this);var m_veLatLongFactory=new VELatLongFactory(new VELatLongFactorySpecFromMap(this));var m_veLatLongDecoder=new VELatLongDecoder();windowWidth=GetWindowWidth();windowHeight=GetWindowHeight();scrollbarWidth=GetScrollbarWidth();this.LoadMap=function(pA,qA,rA,sA){
        if(pA!=null&&pA!="undefined"){
            VEValidator.ValidateObject(pA,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(pA);this.initialLatitude=veLatLongDecoded.Latitude;this.initialLongitude=veLatLongDecoded.Longitude;
        }
        this.fixedMap=sA;this.initialZoomLevel=qA;this.initialMapStyle=rA;this.veonmaploadevent=this.onLoadMap;this.mapelement.innerHTML="";this.mapelement.innerHTML="<table width=100% height=100%><tr valign=middle><td align=center valign=middle><h3>"+L_loading_text+"</h3></td></tr></table>";this.InitializeMap();VE_Analytics.LogAPI("VE | APIs","VEMap - LoadMap");
    }
    ;this._ReArrangeControls=function(){
        if(self.controlzIndexes!=null&&self.controls!=null&&self.controlzIndexes.length==self.controls.length){
            var len=self.controls.length;for(var i=0;i<len;i++){
                document.body.removeChild(self.controls[i]);var control=self.controls[i];control.style.top=self.controltops[i];control.style.left=self.controllefts[i];self._AddControlInner(control,self.controlzIndexes[i]);
            }
            
        }
        
    }
    ;this._ClearView=function(){
        VEMap.ValidateState();VEPushpin.Hide();self.m_vemessage.Hide();
    }
    ;this.SetViewport=function(tA,uA,vA,wA){
        VEMap.ValidateState();try{
            return this.vemapcontrol.SetViewport(tA,uA,vA,wA);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.GetCenter=function(){
        VEMap.ValidateState();var lat=this.vemapcontrol.GetCenterLatitude();var lon=this.vemapcontrol.GetCenterLongitude();var oVELatLong=m_veLatLongFactory.CreateVELatLong(lat,lon);VE_Analytics.LogAPI("VE | APIs","VEMap - GetCenter");return oVELatLong;
    }
    ;this.GetMapView=function(){
        VEMap.ValidateState();try{
            var topLeftLatLong=this.vemapcontrol.PixelToLatLong(new Msn.VE.Pixel(0,0));var bottomRightLatLong=this.vemapcontrol.PixelToLatLong(new Msn.VE.Pixel(this.GetWidth(),this.GetHeight()));var veLatLongRect=new VELatLongRectangle(m_veLatLongFactory.CreateVELatLong(topLeftLatLong.latitude,topLeftLatLong.longitude),m_veLatLongFactory.CreateVELatLong(bottomRightLatLong.latitude,bottomRightLatLong.longitude));VE_Analytics.LogAPI("VE | APIs","VEMap - GetMapView");return veLatLongRect;
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.PixelToLatLong=function(x,y,xA){
        VEMap.ValidateState();try{
            VEValidator.ValidateInt(x,"x");VEValidator.ValidateInt(y,"y");var vepixel=new Msn.VE.Pixel(parseInt(x),parseInt(y));var latlon=this.vemapcontrol.PixelToLatLong(vepixel,xA);var oVELatLong=m_veLatLongFactory.CreateVELatLong(latlon.latitude,latlon.longitude);VE_Analytics.LogAPI("VE | APIs","VEMap - PixelToLatLong");return oVELatLong;
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.SetCenter=function(yA){
        VEMap.ValidateState();try{
            VEValidator.ValidateObject(yA,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(yA);VE_Analytics.LogAPI("VE | APIs","VEMap - SetCenter");return this.vemapcontrol.SetCenter(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.SetCenterAndZoom=function(zA,AA){
        VEMap.ValidateState();try{
            VEValidator.ValidateObject(zA,"veLatLong",VELatLong,"VELatLong");VEValidator.ValidateInt(AA,"zoomLevel");var veLatLongDecoded=m_veLatLongDecoder.Decode(zA);VE_Analytics.LogAPI("VE | APIs","VEMap - SetCenterAndZoom");return this.vemapcontrol.SetCenterAndZoom(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude,AA);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.IncludePointInView=function(BA){
        VEMap.ValidateState();try{
            VEValidator.ValidateObject(BA,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(BA);VE_Analytics.LogAPI("VE | APIs","VEMap - IncludePointInView");return this.vemapcontrol.IncludePointInViewport(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.LatLongToPixel=function(CA,DA){
        VEMap.ValidateState();try{
            VEValidator.ValidateObject(CA,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(CA);var latlong=new Msn.VE.LatLong(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);VE_Analytics.LogAPI("VE | APIs","VEMap - LatLongToPixel");return this.vemapcontrol.LatLongToPixel(latlong,DA);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.PanToLatLong=function(EA){
        VEMap.ValidateState();try{
            VEValidator.ValidateObject(EA,"veLatLong",VELatLong,"VELatLong");var veLatLongDecoded=m_veLatLongDecoder.Decode(EA);VE_Analytics.LogAPI("VE | APIs","VEMap - PanToLatLong");return this.vemapcontrol.PanToLatLong(veLatLongDecoded.Latitude,veLatLongDecoded.Longitude);
        }
        catch(ex){
            throw ex;return;
        }
        
    }
    ;this.SetMapView=function(FA){
        VEMap.ValidateState();
//		try{
            VEValidator.ValidateNonNull(FA,"arrObject");var llArray=new Array();if(VELatLongRectangle.prototype.isPrototypeOf(FA)){
                var ll=new Object();ll.latitude=FA.TopLeftLatLong.Latitude;ll.longitude=FA.TopLeftLatLong.Longitude;llArray.push(ll);var ll=new Object();ll.latitude=FA.BottomRightLatLong.Latitude;ll.longitude=FA.BottomRightLatLong.Longitude;llArray.push(ll);
            }
            else{
                VEValidator.ValidateNonNull(FA[0],"arrObject[0]");if(VELatLong.prototype.isPrototypeOf(FA[0]))for(var i=0;i<FA.length;i++){
                    var veLatLongDecoded=m_veLatLongDecoder.Decode(FA[i]);var ll=new Object();ll.latitude=veLatLongDecoded.Latitude;ll.longitude=veLatLongDecoded.Longitude;llArray.push(ll);
                }
                else{
                    if(VEPolyline.prototype.isPrototypeOf(FA[0]))for(var i=0;i<FA.length;i++){
                        var vePolyline=FA[i];var polyLatLongs=vePolyline.GetLatLongs();for(var j=0;j<polyLatLongs.length;j++){
                            var ll=new Object();ll.latitude=polyLatLongs[j].Latitude;ll.longitude=polyLatLongs[j].Longitude;llArray.push(ll);
                        }
                        
                    }
                    
                }
            }

            VE_Analytics.LogAPI("VE | APIs","VEMap - SetMapView");
			return this.vemapcontrol.SetBestMapView(llArray);
	/*    }
        catch(ex){
		alert('err');
            throw ex;return;
        }
      */  
    }
    ;this.AddPushpin=function(GA){
        VEMap.ValidateState();VEValidator.ValidateObject(GA,"vePushpin",VEPushpin,"VEPushpin");var len=this.pushpins.length;for(var i=0;i<len;i++){
            var p=this.pushpins[i];if(p.ID==GA.ID)throw new VEException("VEMap:AddPushpin","err_invalidpushpinid",L_invalidpushpinid_text);
        }
        this.pushpins.push(GA);GA._SetMapInstance(this);var veLatLongDecoded=m_veLatLongDecoder.Decode(GA.LatLong);this.vemapcontrol.AddPushpin(GA.ID,veLatLongDecoded.Latitude,veLatLongDecoded.Longitude,25,25,"VEAPI_Pushpin",GA.GetContent(),Msn.VE.API.Globals.vepushpinpanelzIndex-1);VE_Analytics.LogAPI("VE | APIs","VEMap - AddPushpin");
    }
    ;this._DisambiguateCallback="VEMap._GetMapFromGUID("+this.GUID+")._Disambiguate";this._Disambiguate=function(a,HA,IA,JA,KA){
        VEMap.ValidateState();var el=document.getElementById(this.ID+"_vewhereinput");if(el)el.value=unescape(a);this.vemapcontrol.SetViewport(HA,IA,JA,KA);if(this.lastwhatsearch!=null&&this.lastwhatsearch.length>0)this.Find(this.lastwhatsearch,null,1,this.m_vesearchmanager.vesearchcallback);
    }
    ;this._DoFind=function(){
        VEMap.ValidateState();try{
            this.lastwhatsearch=document.getElementById(this.ID+"_vewhatinput").value;this.lastwheresearch=document.getElementById(this.ID+"_vewhereinput").value;this.m_vesearchmanager.Find(this.lastwhatsearch,this.lastwheresearch,null,this._DisambiguateCallback,1);
        }
        catch(e){
            this.ShowMessage(e.message);
        }
        
    }
    ;this.UpdateAmbiguousList=function(a){
        this.m_vesearchmanager.UpdateAmbiguousList(a);
    }
    ;
}
VEMap._GetMapFromGUID=function(LA){
    if(Msn.VE.API.Globals.vemapinstances[LA]==null||Msn.VE.API.Globals.vemapinstances[LA]=="undefined"){
        throw new VEException("VEMap:_GetMapFromGUID","err_notinitialized",L_notinitialized_text);return;
    }
    return Msn.VE.API.Globals.vemapinstances[LA];
}
;VEMap.prototype.InitializeMap=function(){
    RegisterNamespaces("Msn.VE");this.mapelement.innerHTML="";this.mapelement.style.overflow="hidden";if(this.mapelement.className==null||this.mapelement.className=="undefined"||this.mapelement.className==""){
        if(this.mapelement.style==null||this.mapelement.style.height==null||this.mapelement.style.height=="undefined"||this.mapelement.style.height=="")this.mapelement.style.height=Msn.VE.API.Globals.vemapheight+"px";if(this.mapelement.style==null||this.mapelement.style.width==null||this.mapelement.style.width=="undefined"||this.mapelement.style.width=="")this.mapelement.style.width=Msn.VE.API.Globals.vemapwidth+"px";
    }
    var params=new Object();if(this.initialLatitude!=null&&this.initialLatitude!="undefined")params.latitude=this.initialLatitude;else params.latitude=Msn.VE.API.Globals.vemaplatitude;if(this.initialLongitude!=null&&this.initialLongitude!="undefined")params.longitude=this.initialLongitude;else params.longitude=Msn.VE.API.Globals.vemaplongitude;if(this.initialZoomLevel!=null&&this.initialZoomLevel!="undefined")params.zoomlevel=this.initialZoomLevel;else params.zoomlevel=Msn.VE.API.Globals.vemapzoom;if(this.initialMapStyle!=null&&this.initialMapStyle!="undefined")params.mapstyle=this.initialMapStyle;else params.mapstyle=Msn.VE.API.Globals.vemapstyle;this.m_dashboardId=this.ID+"_dashboard";if(this.fixedMap!=true){
        params.showDashboard=true;params.dashboardSize=Msn.VE.DashboardSize.Normal;params.dashboardX=5;params.dashboardY=5;params.dashboardId=this.m_dashboardId;params.showScaleBar=true;
    }
    params.obliqueEnabled=true;params.obliqueUrl=Msn.VE.API.Constants.imageryurl;if(this.fixedMap==true)params.fixedView=true;params.disableLogo=false;this.vemapcontrol=new Msn.VE.MapControl(this.mapelement,params);this.vemapcontrol.Init();if(!this.fixedMap==true)this.vemapcontrol.AttachEvent("onchangeview",this._ClearView);RegisterNamespaces("Msn.Drawing");this.m_vegraphicsmanager=new VEGraphicsManager(this);this.m_vegraphicsmanager.Initialize();this.m_velayermanager=new VELayerManager(this);this._lm=this.m_velayermanager;if(document.getElementById("help")==null||document.getElementById("help")=="undefined")VE_Help.CreateHelpPanel();if(this.veonmaploadevent)this.veonmaploadevent(this);this.controlzIndexes=new Array();this.controls=new Array();this.controltops=new Array();this.controllefts=new Array();this.vemapcontrol.AttachEvent("onresize",this._ReArrangeControls);window.onunload=this.Dispose;
}
;VEMap.prototype.Dispose=function(){
    try{
        VEMap.ValidateState();if(this.vemapcontrol!=null){
            this.vemapcontrol.DetachEvent("onchangeview",this._ClearView);this.vemapcontrol.DetachEvent("onresize",this._ReArrangeControls);
        }
        this.vemapcontrol.DetachEvent("onclick",VEPushpin.Hide);var len=this.controlzIndexes.length;for(var i=0;i<len;i++){
            this.controlzIndexes.pop();
        }
        var len=this.controls.length;for(var i=0;i<len;i++){
            try{
                document.body.removeChild(this.controls[i]);
            }
            catch(error){
                
            }
            this.controls[i]=null;this.controltops[i]=null;this.controllefts[i]=null;
        }
        this.controls=null;this.controlzIndexes=null;this.m_vegraphicsmanager.Dispose();this.m_velayermanager.Dispose();this.m_vemessage.Dispose();this.m_veambiguouslist.Dispose();Msn.VE.API.Globals.vemapinstances[this.GUID]=null;this.veonmaploadevent=null;this.veloadingdiv=null;for(var i=0;i<this.pushpins.length;++i){
            if(this.pushpins[i]!=null&&this.pushpins[i]!="undefined"){
                this.pushpins[i].Dispose();this.pushpins[i]=null;
            }
            
        }
        this.pushpins=null;this.ID=null;this.vemapcontrol.Destroy();this.vemapcontrol=null;var iMapInstanceCount=0;for(var v in Msn.VE.API.Globals.vemapinstances){
            if(Msn.VE.API.Globals.vemapinstances[v]!=null)++iMapInstanceCount;
        }
        if(iMapInstanceCount==0){
            var e=document.getElementById("help");if(e!=null&&e!="undefined")document.body.removeChild(e);Msn.VE.API.Globals.Dispose();
        }
        
    }
    catch(err){
        
    }
    
}
;VEMap.ValidateState=function(){
    return true;
}
;VEMap.prototype.DeleteAllPushpins=function(){
    VEMap.ValidateState();VEPushpin.Hide();if(this.pushpins!=null&&this.pushpins!="undefined"){
        var len=this.pushpins.length;for(var i=0;i<len;i++){
            var p=this.pushpins.pop();if(!p.IsInLayer)p.Dispose();
        }
        
    }
    VE_Analytics.LogAPI("VE | APIs","VEMap - DeleteAllPushpins");return this.vemapcontrol.ClearPushpins();
}
;VEMap.prototype.GetMapStyle=function(){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - GetMapStyle");return this.vemapcontrol.GetMapStyle();
}
;VEMap.prototype.GetBirdseyeScene=function(){
    VEMap.ValidateState();var veBirdseyeScene=null;var obliqueScene=this.vemapcontrol.GetObliqueScene();if(obliqueScene!=null&&obliqueScene!="undefined")veBirdseyeScene=new VEBirdseyeScene(obliqueScene);VE_Analytics.LogAPI("VE | APIs","VEMap - GetBirdseyeScene");return veBirdseyeScene;
}
;VEMap.prototype.IsBirdseyeAvailable=function(){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - IsBirdseyeAvailable");return this.vemapcontrol.IsObliqueAvailable();
}
;VEMap.prototype.SetBirdseyeOrientation=function(MA){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - SetBirdseyeOrientation");return this.vemapcontrol.SetObliqueOrientation(MA);
}
;VEMap.prototype.SetBirdseyeScene=function(NA){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - SetBirdseyeScene");return this.vemapcontrol.SetObliqueScene(NA);
}
;VEMap.prototype.GetZoomLevel=function(){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - GetZoomLevel");return this.vemapcontrol.GetZoomLevel();
}
;VEMap.prototype.Pan=function(OA,PA){
    VEMap.ValidateState();try{
        VEValidator.ValidateInt(OA,"deltaX");VEValidator.ValidateInt(PA,"deltaY");VE_Analytics.LogAPI("VE | APIs","VEMap - Pan");return this.vemapcontrol.PanMap(parseInt(OA),parseInt(PA));
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.DeletePushpin=function(QA){
    VEMap.ValidateState();try{
        var len=this.pushpins.length;for(var i=0;i<len;i++){
            var p=this.pushpins[i];if(p!=null&&p.ID==QA){
                if(!p.IsInLayer)p.Dispose();this.pushpins.splice(i,1);VE_Analytics.LogAPI("VE | APIs","VEMap - DeletePushpin");return this.vemapcontrol.RemovePushpin(QA);
            }
            
        }
        throw new VEException("VEMap:DeletePushpin","err_invalidpushpinid",L_invalidpushpinid_text);
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.Resize=function(RA,SA){
    VEMap.ValidateState();try{
        VEValidator.ValidateInt(RA,"width");VEValidator.ValidateInt(SA,"height");return this.vemapcontrol.Resize(RA,SA);
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.SetMapStyle=function(TA){
    VEMap.ValidateState();try{
        VEValidator.ValidateMapStyle(TA,"mapStyle");this.vemapcontrol.SetMapStyle(TA);VE_Analytics.LogAPI("VE | APIs","VEMap - SetMapStyle");
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.SetZoomLevel=function(UA){
    VEMap.ValidateState();try{
        VEValidator.ValidateInt(UA,"zoomLevel");VE_Analytics.LogAPI("VE | APIs","VEMap - SetZoomLevel");return this.vemapcontrol.SetZoom(UA);
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.ZoomIn=function(){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - ZoomIn");this.vemapcontrol.ZoomIn();
}
;VEMap.prototype.ZoomOut=function(){
    VEMap.ValidateState();VE_Analytics.LogAPI("VE | APIs","VEMap - ZoomOut");this.vemapcontrol.ZoomOut();
}
;VEMap.prototype.AttachEvent=function(VA,WA){
    VEMap.ValidateState();try{
        VEValidator.ValidateNonNull(VA,"eventname");VEValidator.ValidateNonNull(WA,"eventhandler");this.vemapcontrol.AttachEvent(VA,WA);VE_Analytics.LogAPI("VE | APIs","VEMap - AttachEvent");
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.DetachEvent=function(XA,YA){
    VEMap.ValidateState();try{
        VEValidator.ValidateNonNull(XA,"eventname");VEValidator.ValidateNonNull(YA,"eventhandler");this.vemapcontrol.DetachEvent(XA,YA);VE_Analytics.LogAPI("VE | APIs","VEMap - DetachEvent");
    }
    catch(ex){
        throw ex;return;
    }
    
}
;VEMap.prototype.FindLocation=function(ZA,aB){
    VEMap.ValidateState();this.lastwhatsearch=null;this.lastwheresearch=ZA;this.m_vesearchmanager.Find(null,ZA,aB,this._DisambiguateCallback,1);VE_Analytics.LogAPI("VE | APIs","VEMap - FindLocation");
}
;VEMap.prototype.FindNearby=function(bB,cB,eB){
    VEMap.ValidateState();this.lastwhatsearch=bB;this.lastwheresearch=null;this.m_vesearchmanager.Find(bB,null,eB,this._DisambiguateCallback,cB);VE_Analytics.LogAPI("VE | APIs","VEMap - FindNearby");
}
;VEMap.prototype.Find=function(gB,hB,jB,kB){
    VEMap.ValidateState();this.lastwhatsearch=gB;this.lastwheresearch=hB;this.m_vesearchmanager.Find(gB,hB,kB,this._DisambiguateCallback,jB);VE_Analytics.LogAPI("VE | APIs","VEMap - Find");
}
;VEMap.prototype.GetRoute=function(lB,mB,nB,oB,pB){
    VEMap.ValidateState();this.m_vedirectionsmanager.GetDrivingDirections(lB,mB,nB,oB,pB);VE_Analytics.LogAPI("VE | APIs","VEMap - GetRoute");
}
;VEMap.prototype.DeleteRoute=function(){
    VEMap.ValidateState();this.m_vedirectionsmanager.ClearRoute();VE_Analytics.LogAPI("VE | APIs","VEMap - DeleteRoute");
}
;VEMap.prototype.ShowMessage=function(qB){
    VEMap.ValidateState();this.m_vemessage.Show(qB);VE_Analytics.LogAPI("VE | APIs","VEMap - ShowMessage");
}
;VEMap.prototype.GetHeight=function(){
    VEMap.ValidateState();var height=parseInt(this.mapelement.style.height.replace("px",""));if(isNaN(height))height=this.mapelement.offsetHeight;return height;
}
;VEMap.prototype.GetWidth=function(){
    VEMap.ValidateState();var width=parseInt(this.mapelement.style.width.replace("px",""));if(isNaN(width))width=this.mapelement.offsetWidth;return width;
}
;VEMap.prototype.GetLeft=function(){
    var curleft=0;if(this.mapelement.offsetLeft)curleft=this.mapelement.offsetLeft;else{
        if(this.mapelement.offsetParent)while(this.mapelement.offsetParent){
            window.status=curleft;curleft+=this.mapelement.offsetLeft;this.mapelement=this.mapelement.offsetParent;
        }
        else{
            if(this.mapelement.x)curleft+=this.mapelement.x;
        }
        
    }
    VE_Analytics.LogAPI("VE | APIs","VEMap - GetLeft");return curleft;
}
;VEMap.prototype.GetTop=function(){
    var curtop=0;if(this.mapelement.offsetTop)curtop=this.mapelement.offsetTop;else{
        if(this.mapelement.offsetParent)while(this.mapelement.offsetParent){
            this.mapelement.offsetTop;this.mapelement=this.mapelement.offsetParent;
        }
        else{
            if(this.mapelement.y)curtop+=this.mapelement.y;
        }
        
    }
    VE_Analytics.LogAPI("VE | APIs","VEMap - GetTop");return curtop;
}
;VEMap.prototype.SetFindResultsPanel=function(rB){
    VEMap.ValidateState();if(rB==null||rB=="undefined")throw new VEException("VEMap:SetFindResultsPanel","err_invalidelement",L_invalidelement_text);var el=document.getElementById(rB);if(el==null||el=="undefined")throw new VEException("VEMap:SetFindResultsPanel","err_invalidelement",L_invalidelement_text);this.searchelement=rB;
}
;VEMap.prototype._AddControlInner=function(sB,tB){
    sB.style.position="absolute";sB.style.zIndex=201;var top=this.GetTop();var left=this.GetLeft();if(!sB.style.top)sB.style.top="0px";if(!sB.style.left)sB.style.left="0px";var tempTop=sB.style.top;var tempLeft=sB.style.left;if(isNaN(tempTop))tempTop=tempTop.toString().toLowerCase();if(isNaN(tempLeft))tempLeft=tempLeft.toString().toLowerCase();top+=parseInt(tempTop.replace("px"));left+=parseInt(tempLeft.replace("px"));sB.style.top=top+"px";sB.style.left=left+"px";document.body.appendChild(sB);
}
;VEMap.prototype.AddControl=function(uB,vB){
    VEMap.ValidateState();if(uB==null||uB=="undefined")throw new VEException("VEMap:AddControl","err_invalidelement",L_invalidelement_text);if(this.controls==null||this.controls=="undefined")throw new VEException("VEMap:AddControl","err_notinitialized",L_notinitialized_text);this.controlzIndexes.push(vB);this.controls.push(uB);this.controltops.push(uB.style.top);this.controllefts.push(uB.style.left);this._AddControlInner(uB,vB);VE_Analytics.LogAPI("VE | APIs","VEMap - AddControl");
}
;VEMap.prototype.HideFindControl=function(){
    VEMap.ValidateState();var el=document.getElementById(this.ID+"_vefindcontrolinput");if(el!=null&&el!="undefined")el.style.display="none";VE_Analytics.LogAPI("VE | APIs","VEMap - HideFindControl");
}
;VEMap.prototype.ShowDashboard=function(){
    this._ToggleDashboard(true);VE_Analytics.LogAPI("VE | APIs","VEMap - ShowDashboard");
}
;VEMap.prototype.HideDashboard=function(){
    this._ToggleDashboard(false);VE_Analytics.LogAPI("VE | APIs","VEMap - HideDashboard");
}
;VEMap.prototype._ToggleDashboard=function(wB){
    VEMap.ValidateState();var el=document.getElementById(this.m_dashboardId);if(el!=null){
        if(wB)el.style.display="block";else el.style.display="none";return;
    }
    if(this.mapelement.childNodes!=null&&this.mapelement.childNodes!="undefined"){
        var len=this.mapelement.childNodes.length;var el=null;for(var i=0;i<len;i++){
            el=this.mapelement.childNodes[i];if(el==null)continue;if(el.className!=null&&el.className=="Dashboard Dashboard_normal"){
                if(wB)el.style.display="block";else el.style.display="none";break;
            }
            
        }
        
    }
    
}
;VEMap.prototype.ShowFindControl=function(xB){
    VEMap.ValidateState();var findControlId=this.ID+"_vefindcontrolinput";var el=document.getElementById(findControlId);if(el!=null&&el!="undefined")el.style.display="block";else{
        el=document.createElement("div");el.className="VE_FindControl";el.id=findControlId;el.style.zIndex=199;el.style.position="absolute";el.style.top="5px";el.style.left="195px";el.style.padding="5px";var whatInputContainerId=this.ID+"_vewhatinputcontainer";var whatInputId=this.ID+"_vewhatinput";var whereInputId=this.ID+"_vewhereinput";el.innerHTML="<div class=VE_WhatControl id='"+whatInputContainerId+"'>"+L_what_text+" "+"<input id=\""+whatInputId+"\" type=\"text\" name=\"vewhatinput\" size=\"25\" onfocus=\"this.select()\" onblur=\"this.value = this.value\" />"+"</div>"+"<div class=VE_WhereControl>"+L_where_text+" "+"<input id=\""+whereInputId+"\" type=\"text\" name=\"vewhereinput\" size=\"25\" style=\"color: #333333\""+"ondrop=\"this.value='';this.style.color='black';SelectText(this,0,0);\" />"+"</div>"+"<div class=VE_FindButton>"+"<button id=\"searchbttn\" onclick=\"VEMap._GetMapFromGUID("+this.GUID+")._DoFind();\" type=\"submit\" name=\"submit\" value=\"Local Search\">"+L_find_text+"</button>"+"</div>";this.AddControl(el);if(xB){
            var whatelement=document.getElementById(whatInputContainerId);if(whatelement)whatelement.style.display="none";
        }
        
    }
    VE_Analytics.LogAPI("VE | APIs","VEMap - ShowFindControl");
}
;VEMap.prototype.Clear=function(){
    VEMap.ValidateState();this._ClearView();this.DeleteAllPushpins();this.m_vedirectionsmanager.RemoveRouteHighLight();this.m_vegraphicsmanager.Clear();this.m_veambiguouslist.Hide();this.m_vemessage.Hide();VE_Analytics.LogAPI("VE | APIs","VEMap - Clear");
}
;VEMap.prototype._ShowLoading=function(){
    VEMap.ValidateState();if(!this.veloadingdiv){
        this.veloadingdiv=document.createElement("div");this.veloadingdiv.className="VE_Network_Loading";this.veloadingdiv.style.top="75px";this.veloadingdiv.style.left="80px";this.veloadingdiv.innerHTML=L_loading_text;this.AddControl(this.veloadingdiv,202);
    }
    if(this.veloadingdiv.style.display!="block")this.veloadingdiv.style.display="block";else this.veloadingdiv.style.display="none";
}
;VEMap.prototype.AddPolyline=function(yB){
    VEMap.ValidateState();this.m_vegraphicsmanager.DrawLine(yB);VE_Analytics.LogAPI("VE | APIs","VEMap - AddPolyline");
}
;VEMap.prototype.DeletePolyline=function(zB){
    VEMap.ValidateState();this.m_vegraphicsmanager.RemoveLinebyId(zB);VE_Analytics.LogAPI("VE | APIs","VEMap - DeletePolyline");
}
;VEMap.prototype.DeleteAllPolylines=function(){
    VEMap.ValidateState();this.m_vegraphicsmanager.RemoveAllLines();VE_Analytics.LogAPI("VE | APIs","VEMap - DeleteAllPolylines");
}
;VEMap.prototype.AddLayer=function(AB){
    VEMap.ValidateState();VEValidator.ValidateObject(AB,"veLayerSpec",VELayerSpecification,"VELayerSpecification");this.m_velayermanager.AddLayer(AB);VE_Analytics.LogAPI("VE | APIs","VEMap - AddLayer");
}
;VEMap.prototype.ShowLayer=function(BB){
    VEMap.ValidateState();this.m_velayermanager.Show(BB);VE_Analytics.LogAPI("VE | APIs","VEMap - ShowLayer");
}
;VEMap.prototype.HideLayer=function(CB){
    VEMap.ValidateState();VEPushpin.Hide();this.m_velayermanager.Hide(CB);VE_Analytics.LogAPI("VE | APIs","VEMap - HideLayer");
}
;VEMap.prototype.DeleteLayer=function(DB){
    VEMap.ValidateState();this.m_velayermanager.DeleteLayerById(DB);this.m_vegraphicsmanager.Clear();this.m_vegraphicsmanager.Draw();VE_Analytics.LogAPI("VE | APIs","VEMap - DeleteLayer");
}
;VEMap.GetVersion=function(){
    VE_Analytics.LogAPI("VE | APIs","VEMap - GetVersion");return Msn.VE.API.Globals.vecurrentversion;
}
;
OAT.Loader.pendingCount--;
