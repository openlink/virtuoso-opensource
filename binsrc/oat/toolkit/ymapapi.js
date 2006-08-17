/*
Copyright (c) 2006 Yahoo! Inc. All rights reserved. - version 3.0.3.0
*/

function YahooMapsAPIAjax(){
    var YGeoPoint=function(a,b){
        this.Lat=parseFloat(a)||0;this.Lon=parseFloat(b)||0;
    }
    ;YGeoPoint.prototype.greater=function(p){
        if(p&&p.valid){
            return(this.Lat>p.Lat&&this.Lon>p.Lon);
        }
        
        return false;
    }
    ;YGeoPoint.prototype.equal=function(p){
        if(p&&p.valid){
            return(this.Lat==p.Lat&&this.Lon==p.Lon);
        }
        
        return false;
    }
    ;YGeoPoint.prototype.valid=function(){
        return true;
    }
    ;YGeoPoint.prototype.getRad=function(){
        return new YGeoPoint(this.Lat*Math.PI/180,this.Lon*Math.PI/180);
    }
    ;YGeoPoint.prototype.distance=function(p,u){
        var a=this.pointDiff(p);var _do=new Object();var p1r=this.getRad();var p2r=p.getRad();var _b=Math.acos(Math.cos(p1r.Lat)*Math.cos(p1r.Lon)*Math.cos(p2r.Lat)*Math.cos(p2r.Lon)+Math.cos(p1r.Lat)*Math.sin(p1r.Lon)*Math.cos(p2r.Lat)*Math.sin(p2r.Lon)+Math.sin(p1r.Lat)*Math.sin(p2r.Lat));_do.kilometers=6378*_b;_do.miles=3963.1*_b;_do.nautical=3443.9*_b;_do.degrees=Math.sqrt(a.Lat*a.Lat+a.Lon*a.Lon);if(u){
            _do.pixels=_do.kilometers/u.kilometers;
        }
        
        return _do;
    }
    ;YGeoPoint.prototype.pointDiff=function(p){
        var _l=this.Lat-p.Lat;var _g=p.Lon-this.Lon;return(new YGeoPoint(_l,_g));
    }
    ;YGeoPoint.prototype.middle=function(p){
        var _a=(this.Lat+p.Lat)/2;var _b=(this.Lon+p.Lon)/2;return(new YGeoPoint(_a,_b));
    }
    ;YGeoPoint.prototype.setgeobox=function(_b){
        this.LatMax=(this.Lat>_b.Lat)?this.Lat:_b.Lat;this.LatMin=(this.Lat>_b.Lat)?_b.Lat:this.Lat;this.LonMax=(this.Lon>_b.Lon)?this.Lon:_b.Lon;this.LonMin=(this.Lon>_b.Lon)?_b.Lon:this.Lon;this.min=new YGeoPoint((this.Lat>_b.Lat)?_b.Lat:this.Lat,(this.Lon>_b.Lon)?_b.Lon:this.Lon);this.max=new YGeoPoint((this.Lat>_b.Lat)?this.Lat:_b.Lat,(this.Lon>_b.Lon)?this.Lon:_b.Lon);
    }
    ;var YCoordPoint=function(x,y){
        this.x=parseFloat(x)||0;this.y=parseFloat(y)||0;this._xpos='left';this._ypos='top';
    }
    ;YCoordPoint.prototype.equal=function(p){
        if(p&&p.valid){
            return(this.x==p.x&&this.y==p.y);
        }
        
        return false;
    }
    ;YCoordPoint.prototype.translate=function(_a,_b){
        this._xpos=_a;this._ypos=_b;
    }
    ;YCoordPoint.prototype.valid=function(){
        return true;
    }
    ;YCoordPoint.prototype.distance=function(p){
        var a=this.pointDiff(p);return Math.sqrt(a.x*a.x+a.y*a.y);
    }
    ;YCoordPoint.prototype.pointDiff=function(p){
        var _x=p.x-this.x;var _y=this.y-p.y;return(new YCoordPoint(_x,_y));
    }
    ;var YSize=function(w,h){
        this.width=parseInt(w)||0;this.height=parseInt(h)||0;
    }
    ;YSize.prototype.hasSmallerSide=function(_s){
        return(this.width<_s.width||this.height<_s.height);
    }
    ;YSize.prototype.valid=function(){
        return true;
    }
    ;YSize.prototype.area=function(_s){
        if(_s)return _s.width*_s.height;return this.width*this.height;
    }
    ;var YImage=function(a,b,c,d){
        this.src=a||'http://us.i1.yimg.com/us.yimg.com/i/us/tr/fc/map/orange_bubble_b.png';this.size=b||new YSize(30,33);this.offsetSmartWindow=c||new YCoordPoint(-1,-1);this.offset=d||new YCoordPoint(0,0);
    }
    ;var _baseURL='http://us.i1.yimg.com/us.yimg.com/i/us/map/aj/';var M_PER_DEGREE=111111;var EARTH_CIRCUM_M=M_PER_DEGREE*360;var RAD_PER_DEG=Math.PI/180;var MAXLEVEL=18;var TILE_WH=256;function Projection(p_level,clat,tilew,tileh){
        this.init(p_level,clat,tilew,tileh);
    }
    
    Projection.prototype.init=function(p_level,clat,tilew,tileh){
        if(p_level<1)this.level_=1;else if(p_level>MAXLEVEL)this.level_=MAXLEVEL;else this.level_=p_level;this.tile_w_=tilew;this.tile_h_=tileh;this.status_=1;this.isok=isok;this.tile_width=tile_width;this.pixel_width=pixel_width;this.tile_height=tile_height;this.pixel_height=pixel_height;this.mpp=mpp;this.level=level;this.tile_size=tile_size;this.scaleKm=scaleKm;this.scaleMiles=scaleMiles;this.scaleFeet=scaleFeet;this.pix_to_tile=pix_to_tile;
    }
    ;function TileXY(tx,ty,x,y){
        this.tx=tx||0;this.ty=ty||0;this.x=x||0;this.y=y||0;
    }
    
    function pix_to_tile(xp,yp){
        var _txy=new TileXY();var ypos=Math.abs(yp);_txy.tx=Math.floor(xp/this.tile_w_);_txy.x=xp%this.tile_w_;_txy.ty=Math.floor(ypos/this.tile_h_);_txy.y=ypos%this.tile_h_;if(yp<0)
        {
            _txy.ty=-_txy.ty;var y=ypos%this.tile_h_;if(y&&y>0)
            {
                _txy.ty--;_txy.y=this.tile_h_-_txy.y;
            }
            
        }
        
        return _txy;
    }
    
    function tile_width(){
        return this.ntiles_w_;
    }
    
    function pixel_width(){
        return this.ntiles_w_*this.tile_w_;
    }
    
    function tile_height(){
        return this.ntiles_h_;
    }
    
    function pixel_height(){
        return this.ntiles_h_*this.tile_h_;
    }
    
    function mpp(){
        return this.meters_per_pixel_;
    }
    
    function level(){
        return this.level_;
    }
    
    function tile_size(){
        return this.tile_w_;
    }
    
    function isok(){
        return this.status_==1;
    }
    
    function scaleKm(km,clat){
        return(this.scaleMeters(km*1000.0,clat));
    }
    
    function scaleMiles(miles,clat){
        return(this.scaleMeters(miles*1609.344,clat));
    }
    
    function scaleFeet(feet,clat){
        return(this.scaleMeters(feet/3.282,clat));
    }
    
    function sinh(x){
        ret=Math.exp(x);ret=(ret-1/ret)/2;return ret;
    }
    
    function MercatorProjection(p_level,tilew,tileh){
        tileh=tilew=TILE_WH;this.init(p_level,0.0,tilew,tileh);this.circum_px=1<<(26-this.level_);this.ntiles_w_=this.circum_px/this.tile_w_;this.ntiles_h_=this.circum_px/this.tile_h_;this.meters_per_pixel_=EARTH_CIRCUM_M/this.circum_px;this.x_per_lon_=this.circum_px/360;this.ll_to_xy=ll_to_xy;this.xy_to_ll=xy_to_ll;this.mpp_m=mpp_m;this.scaleMeters=scaleMeters;this.ll_to_pxy=ll_to_pxy;this.pxy_to_ll=pxy_to_ll;
    }
    
    MercatorProjection.prototype=new Projection();MercatorProjection.prototype.constructor=MercatorProjection;MercatorProjection.superclass=Projection.prototype;MercatorProjection.prototype._returnCoordPoint=function(l,t,x,y){
        return new YCoordPoint(l+x,t+TILE_WH-y);
    }
    ;function xy_to_ll(col,row,x,y){
        var x_pixel=col*this.tile_w_+x;var y_pixel=row*this.tile_h_+y;return(this.pxy_to_ll(x_pixel,y_pixel));
    }
    
    function ll_to_xy(_g){
        var _txy=new TileXY();var _cp=this.ll_to_pxy(_g.Lat,_g.Lon);if(this.isok()){
            _txy=this.pix_to_tile(_cp.x,_cp.y);
        }
        
        return _txy;
    }
    
    function ll_to_pxy(lat,lon){
        var _cp=new YCoordPoint();var alon=lon+180;var ltmp=Math.abs(alon)%360;if(alon<0)
        alon=360-ltmp;if(alon>360)
        alon=ltmp;alat=Math.abs(lat);if(alat>90)
        alat=90;alat*=RAD_PER_DEG;_cp.x=parseInt(alon*this.x_per_lon_);ytemp=Math.log(Math.tan(alat)+1.0/Math.cos(alat))/Math.PI;_cp.y=parseInt(ytemp*this.pixel_height())/2;if(lat<0)
        _cp.y=-_cp.y;this.status_=1;return _cp;
    }
    
    function pxy_to_ll(x_pixel,y_pixel){
        var _gp=new YGeoPoint();this.status_=0;var alon=x_pixel/this.x_per_lon_;var ltmp=Math.abs(alon)%360;if(alon<0)
        alon=360-ltmp;if(alon>360)
        alon=ltmp;_gp.Lon=alon-180;alat=(y_pixel/(this.pixel_height()/2))*Math.PI;alat=Math.atan(sinh(alat))/RAD_PER_DEG;if(alat<-90)
        alat=-90;if(alat>90)
        alat=90;_gp.Lat=alat;this.status_=1;return _gp;
    }
    
    function mpp_m(clat){
        return(this.meters_per_pixel_*Math.cos(clat*RAD_PER_DEG));
    }
    
    function scaleMeters(meters,clat){
        return(parseInt(meters/this.mpp_m(clat)+0.5));
    }
    
    var _setBounds=function(x,y,bx,by){
        this.bL=x-bx;this.bR=x+bx;this.bT=y+by;this.bB=y-by;
    }
    ;_setBounds.prototype={
        abL:function(){
            this.pbL=this.bL;this.bL--;
        }
        ,abR:function(){
            this.pbR=this.bR;this.bR++;
        }
        ,abT:function(){
            this.pbT=this.bT;this.bT++;
        }
        ,abB:function(){
            this.pbB=this.bB;this.bB--;
        }
        ,sbL:function(){
            this.bL++;
        }
        ,sbR:function(){
            this.bR--;
        }
        ,sbT:function(){
            this.bT--;
        }
        ,sbB:function(){
            this.bB++;
        }
        ,inB:function(x,y){
            if(x>=this.bL&&x<=this.bR)
            if(y<=this.bT&&y>=this.bB)
            return true;return false;
        }
        
    }
    ;var YUtility=new function(){
        
    }
    ;YUtility.tracker=function(maptype,size,operation){
        var width=size.width;var height=size.height;var _dsopkey='';if(operation=='zoom')
        _dsopkey='ds_zmtr';if(operation=='start')
        _dsopkey='ds_initr';if(operation=='pan_ob')
        _dsopkey='ds_pantr';var _img=document.createElement('img');_img.id='ymaptrk'+operation;var _nvq=(maptype==YAHOO_MAP_REG)?'n':0;var _mvt='m';if(maptype==YAHOO_MAP_SAT)
        _mvt='s';if(maptype==YAHOO_MAP_HYB)
        _mvt='h';var _opt={
            s:97199103,appid:YMAPPID,swpx:width,shpx:height,oper:operation,i_api:1,apptype:'ajax',testid:'M077',nloc:0,i_smvw:0,i_bizloc:0,i_tbt:0,i_trf:0,i_flash:0,ds_i:_nvq,ds_maptr:_nvq,mvt:_mvt
        }
        ;var _l='';for(var o in _opt){
            _l+=o+'='+_opt[o]+'&';
        }
        
        _l+=_dsopkey+'='+_nvq;_img.src='http://geo.yahoo.com/serv?'+_l;YUtility.appendNode(document.body,_img);YUtility.removeNode(_img);
    }
    ;YUtility._xyKey=function(x,y,z,t){
        var _z=z||0;var _t=t||0;var _c='_';return'xy'+x+_c+y+_c+_z+_c+_t;
    }
    ;YUtility.getByID=function(id){
        return document.getElementById(id);
    }
    ;YUtility.getByTag=function(tag){
        return document.getElementsByTagName(tag);
    }
    ;YUtility.getRandomID=function(){
        var r='yid'+Math.random().toString();return(r.replace(/\./g,''));
    }
    ;YUtility.removeNode=function(_n){
        if(!_n||(_n&&!_n.parentNode))return;var o=(_n.dom)?_n.dom:_n;if(typeof o==='object'){
            YUtility.deleak(o);try{
                var n=o.parentNode.removeChild(o);n=null;
            }
            
            catch(x){
                
            }
            ;
        }
        
    }
    ;var _selectOnCache=[];YUtility.setDefaultSelectStyle=function(_c){
        if(YUtility.browser.id==0){
            _c.unselectable='on';if(_c.nodeName=='IMG')
            _c.galleryImg='no';
        }
        else if(YUtility.browser.id==1){
            YUtility.setStyle(_c,'MozUserSelect','none');
        }
        
    }
    ;var _nodeCache={
        
    }
    ;YUtility.cloneNode=function(_e,_p){
        var _c=null;var _k=_e+_p;var _n=_nodeCache[_k];if(!_n){
            _c=_nodeCache[_k]=YUtility.createNode(_e);
        }
        else{
            _c=_n.cloneNode(true);
        }
        
        YUtility.setDefaultSelectStyle(_c);return _c;
    }
    ;YUtility.createNode=function(_e,_id){
        var _c=document.createElement(_e);if(_id)_c.id=_id;return _c;
    }
    ;YUtility.appendNode=function(_s,_n){
        if(!_n||!_s)return;var _c=(_n.dom)?_n.dom:_n;var _p=(_s.dom)?_s.dom:_s;if(!_c.parentNode){
            _p.appendChild(_c);return;
        }
        
        if(_c.parentNode&&_c.parentNode.nodeType>3){
            _p.appendChild(_c);return;
        }
        
    }
    ;YUtility.deleak=function(o){
        var a,i,l,n;a=(o)?o.attributes:null;if(a){
            l=a.length;for(i=0;i<l;i+=1){
                n=a[i].name;if(typeof o[n]==='function'){
                    o[n]=null;
                }
                
            }
            
        }
        
        if(o)a=o.childNodes;if(a){
            l=a.length;for(i=0;i<l;i+=1){
                YUtility.deleak(o.childNodes[i]);
            }
            
        }
        
    }
    
    YUtility.dynamicSNode=function(i,r){
        var shead=YUtility.getByTag('head');var snode=YUtility.getByID(i);if(snode)
        YUtility.removeNode(snode);snode=YUtility.createNode('script');snode.type='text/javascript';snode.src=r;snode.id=i;YUtility.appendNode(shead[0],snode);
    }
    
    YUtility.getSize=function(_e){
        var d=YAHOO.util.Dom.getRegion(_e);var s=(d.getArea())?(new YSize((d.right-d.left),(d.bottom-d.top))):(new YSize(0,0));return s;
    }
    
    YUtility.setStyle=function(e,k,v){
        if(!e)return;var _e=(e.dom)?e.dom:e;if(typeof k=='object'){
            for(var t in k){
                _e.style[t]=k[t];
            }
            
        }
        else{
            _e.style[k]=v;
        }
        
    }
    
    YUtility.browser=new function(){
        var _n={
            'ie':0,'moz':1,'saf':2,'opr':3,'oth':9
        }
        ;var _o={
            'win':0,'mac':1,'oth':3
        }
        ;var ua=navigator.userAgent.toLowerCase();this.os=3;if(/windows/.test(ua))this.os=0;else if(/mac/.test(ua))this.os=1;this.id=9;if(typeof document.all!='undefined')this.id=0;else if(/gecko/.test(ua))this.id=1;else if(/safari/.test(ua))this.id=2;else if(/opera 7/.test(ua))this.id=3;
    }
    ;YUtility.getInt=function(_n){
        var n=parseInt(_n);return(isNaN(n)?0:n);
    }
    ;YUtility.alphaLoad=function(_n,_t){
        var _clr='http://us.i1.yimg.com/us.yimg.com/i/tb/yds/clr.gif';var _typ=(_t)?'crop':'scale';var _p=(_n.dom)?_n.dom:_n;if(YUtility.browser.id){
            return;
        }
        
        else{
            if(_p&&_p.nodeName=='IMG'){
                var _ie="progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+_p.src+"', sizingMethod="+_typ+")";YUtility.setStyle(_p,'filter',_ie);_p.src=_clr;
            }
            
        }
        
    }
    ;YUtility.alphaImg=function(_ni,_t,_oi){
        if(_oi)
        _oi.src='http://us.i1.yimg.com/us.yimg.com/i/tb/yds/clr.gif';var _typ=(_t)?'scale':'crop';return"progid:DXImageTransform.Microsoft.AlphaImageLoader(src='"+_ni+"', sizingMethod="+_typ+")";
    }
    ;var _subscriber=function(fn,obj,cast){
        this.fn=fn;this.obj=obj||null;this.override=(cast);this._muted=false;
    }
    ;_subscriber.prototype.contains=function(fn,obj){
        return(this.fn==fn&&this.obj==obj);
    }
    ;var _captureEvent=function(_t,_s){
        this.type=_t;this.scope=_s;this.subscribers=[];if(YAHOO.util["Event"]){
            YAHOO.util.Event.regCE(this);
        }
        
    }
    ;_captureEvent.prototype=new YAHOO.util.CustomEvent;_captureEvent.prototype.trigger=function(_e,_o){
        for(var i=0;i<this.subscribers.length;i++){
            var _s=this.subscribers[i];
			if(_s){
                var scope=(_s.override)?_s.obj:this.scope;if(_s.fn&&!_s._muted){
                    _s.fn.call(scope,_e,_o);
                }
                
            }
            
        }
        
    }
    ;_captureEvent.prototype.subscribe=function(fn,obj,cast){
        this.subscribers.push(new _subscriber(fn,obj,cast));
    }
    ;var _eventObject=function(_a,_b,_c){
        this._elem=_a;this._type=_b;this._func=_c;
    }
    ;var YEvent=new function(){
        this._cache=[];
    }
    ;YEvent.Capture=function(_a,_b,_c,_d,_p){
        if(!_a||!_b||!_c)return;var el=(_a.dom)?_a.dom:(_a.id?_a.id:_a);if(_a.Events&&_a.Events[_b]&&!_p){
            _a.Events[_b].subscribe(_c,(_d?_d:_a),true);
        }
        
        else{
            YAHOO.util.Event.addListener(el,(_p?_p:_b),_c,(_d?_d:_a),true);
        }
        
        if(_a.id)this._cache[_a.id]=_a;if(!_a._elist)_a._elist=[];if(_a._elist)_a._elist.push(new _eventObject(el,_b,_c));
    }
    ;YEvent.Remove=function(_a,_b,_c,_p){
        if(!_a||!_b||!_c)return;if(_a.Events&&_a.Events[_b]&&!_p){
            _a.Events[_b].unsubscribe(_c,_a);
        }
        
        else{
            var el=(_a.dom)?_a.dom:(_a.id?_a.id:_a);YAHOO.util.Event.removeListener(el,(_p?_p:_b),_c);
        }
        
    }
    ;YEvent.ClearAll=function(_a){
        if(!_a)return;for(var _e in _a._elist){
            try{
                YAHOO.util.Event.removeListener(_a._elist[_e]._elem,_a._elist[_e]._type,_a._elist[_e]._func);_a.Events[_a._elist[_e]._type].unsubscribe(_a._elist[_e]._func,_a);
            }
            catch(x){
                
            }
            
            delete _a._elist[_e];
        }
        
    }
    ;YEvent.isCaptureSet=function(_a,_t){
        for(var _e in _a.Events){
            if(_e==_t&&_a.Events[_e].subscribers.length){
                return true;
            }
            
        }
        
        return false;
    }
    ;YEvent.stopDefault=function(_e){
        if(!_e)return;YAHOO.util.Event.preventDefault(_e);
    }
    ;YEvent.stopPropag=function(_e){
        if(!_e)return;YAHOO.util.Event.stopPropagation(_e);
    }
    ;YEvent.stopEvent=function(_e){
        if(!_e)return;YAHOO.util.Event.stopEvent(_e);
    }
    ;var EventsList=new function(){
        
    }
    ;EventsList.unload='unload';EventsList.wheel=(YUtility.browser.id)?'DOMMouseScroll':'mousewheel';EventsList.resize='resize';EventsList.MouseClick='MouseClick';EventsList.MouseUp='MouseUp';EventsList.KeyDown='KeyDown';EventsList.KeyUp='KeyUp';EventsList.MouseDoubleClick='MouseDoubleClick';EventsList.MouseDown='MouseDown';EventsList.MouseOver='MouseOver';EventsList.MouseOut='MouseOut';EventsList.endMapDraw='endMapDraw';EventsList.zoomAdded='zoomAdded';EventsList.MapTypeControlAdded='MapTypeControlAdded';EventsList.miniAdded='miniAdded';EventsList.startPan='startPan';EventsList.endPan='endPan';EventsList.onPan='onPan';EventsList.startAutoPan='startAutoPan';EventsList.endAutoPan='endAutoPan';EventsList.changeZoom='changeZoom';EventsList.changeMapType='changeMapType';EventsList.openSmartWindow='openSmartWindow';EventsList.closeSmartWindow='closeSmartWindow';EventsList.openExpanded='openExpanded';EventsList.closeExpanded='closeExpanded';EventsList.onStartGeoCode='onStartGeoCode';EventsList.onEndGeoCode='onEndGeoCode';EventsList.onStartGeoRSS='onStartGeoRSS';EventsList.onEndGeoRSS='onEndGeoRSS';var Overlay=function(_p,_n){
        this._defaults(_p,_n);
    }
    ;Overlay.prototype.setMapObject=function(_m){
        this._map=_m;
    }
    ;Overlay.prototype._defaults=function(a,b){
        if(!a)return;if(a.Lat){
            this.YGeoPoint=a;
        }
        
        else if(a.x){
            this.YCoordPoint=a;
        }
        
        this.id=(b&&b.id)?b.id:YUtility.getRandomID();if(b){
            this.dom=(b.dom)?b.dom:b;
        }
        
        else{
            this._container();
        }
        
        this._setBaseElStyle();this._defineEvents();this._registerEvents();
    }
    ;Overlay.prototype._setBaseElStyle=function(_n){
        if(this.dom){
            YUtility.setStyle(this.dom,'position','absolute');
        }
        
    }
    ;Overlay.prototype._defineEvents=function(){
        this.Events={
            
        }
        ;this.Events.openSmartWindow=new _captureEvent(EventsList.openSmartWindow,this);this.Events.closeSmartWindow=new _captureEvent(EventsList.closeSmartWindow,this);this.Events.openExpanded=new _captureEvent(EventsList.openExpanded,this);this.Events.closeExpanded=new _captureEvent(EventsList.closeExpanded,this);this.Events.MouseClick=new _captureEvent(EventsList.MouseClick,this);this.Events.MouseOver=new _captureEvent(EventsList.MouseOver,this);this.Events.MouseOut=new _captureEvent(EventsList.MouseOut,this);this.Events.MouseDoubleClick=new _captureEvent(EventsList.MouseDoubleClick,this);this.Events.MouseUp=new _captureEvent(EventsList.MouseUp,this);
    }
    ;Overlay.prototype._registerEvents=function(){
        YEvent.Capture(this,EventsList.openSmartWindow,this._openSmartWindowRun);YEvent.Capture(this,EventsList.closeSmartWindow,this._closeSmartWindowRun);YEvent.Capture(this,EventsList.openExpanded,this._openExpandedRun);YEvent.Capture(this,EventsList.closeExpanded,this._closeExpandedRun);YEvent.Capture(this,EventsList.MouseClick,this._MouseClickRun,null,'click');YEvent.Capture(this,EventsList.MouseOver,this._MouseOverRun,null,'mouseover');YEvent.Capture(this,EventsList.MouseOut,this._MouseOutRun,null,'mouseout');YEvent.Capture(this,EventsList.MouseDoubleClick,this._MouseDoubleClickRun,null,'dblclick');YEvent.Capture(this,EventsList.MouseUp,this._MouseUpRun,null,'mouseup');
    }
    ;Overlay.prototype._openSmartWindowRun=function(_e){
        this.Events.openSmartWindow.trigger(new _eO(this));
    }
    ;Overlay.prototype._closeSmartWindowRun=function(_e){
        this.Events.closeSmartWindow.trigger(new _eO(this));
    }
    ;Overlay.prototype._openExpandedRun=function(_e){
        this.Events.openExpanded.trigger(new _eO(this));
    }
    ;Overlay.prototype._closeExpandedRun=function(_e){
        this.Events.closeExpanded.trigger(new _eO(this));
    }
    ;Overlay.prototype._MouseClickRun=function(_e){
        this.Events.MouseClick.trigger(new _eO(this));
    }
    ;Overlay.prototype._MouseOverRun=function(_e){
        this.Events.MouseOver.trigger(new _eO(this));
    }
    ;Overlay.prototype._MouseOutRun=function(_e){
        this.Events.MouseOut.trigger(new _eO(this));
    }
    ;Overlay.prototype._MouseDoubleClickRun=function(_e){
        this.Events.MouseDoubleClick.trigger(new _eO(this));
    }
    ;Overlay.prototype.assignCoordPoint=function(){
        if(this.YCoordPoint){
            var _xC=this.YCoordPoint._xpos;var _yC=this.YCoordPoint._ypos;var _s={
                
            }
            ;_s[_xC]=this.YCoordPoint.x+'px';_s[_yC]=this.YCoordPoint.y+'px';YUtility.setStyle(this,_s);
        }
        
    }
    ;Overlay.prototype.setGeoXYPoint=function(_z,_a){
        if(_z&&_a){
            var _p=this.calculatePosition(_z);var _k=YUtility._xyKey(_p.tx,_p.ty,_z);if(_a[_k]){
                var ps=this.MP._returnCoordPoint(_a[_k].tx,_a[_k].ty,_p.x,_p.y);var IMAGE_OFFSET_TBD=0;this._xy=new YCoordPoint(ps.x,(ps.y-IMAGE_OFFSET_TBD));this._z=_z;this._posTbl=_a;if(!this._hidden)this.unhide();
            }
            
            else{
                this.hide(true);
            }
            
        }
        
        else{
            this.hide(true);
        }
        
    }
    ;Overlay.prototype.calculatePosition=function(_z){
        this.MP=new MercatorProjection(_z);return this.MP.ll_to_xy(this.YGeoPoint);
    }
    ;Overlay.prototype.setYGeoPoint=function(_p){
        this.YGeoPoint=new YGeoPoint(_p.Lat,_p.Lon);this.setGeoXYPoint(this._z,this._posTbl);
    }
    ;Overlay.prototype.hide=function(_i){
        if(!_i)this._hidden=true;this.dom.style.left=this.dom.style.top='-9500px';this.dom.style.zIndex=-9999;
    }
    ;Overlay.prototype.ishidden=function(){
        return this._hidden;
    }
    ;Overlay.prototype.unhide=function(){
        this._hidden=false;if(this._xy){
            this.dom.style.left=this._xy.x+'px';this.dom.style.top=this._xy.y+'px';this.dom.style.zIndex=1;
        }
        
    }
    ;Overlay.prototype.getCoordPoint=function(){
        var x=YUtility.getInt(this.dom.style.left);var y=YUtility.getInt(this.dom.style.top);return new YCoordPoint(x,y);
    }
    ;Overlay.prototype._container=function(_n){
        this.dom=YUtility.cloneNode('div',this.id);this.dom.id=this.id;if(_n)
        YUtility.appendNode(this.dom,_n);
    }
    ;var CustomOverlay=function(a,b){
        this._defaults(a,b);
    }
    ;CustomOverlay.prototype=new Overlay();CustomOverlay.prototype.constructor=CustomOverlay;CustomOverlay.prototype.superclass=Overlay.prototype;var CM=function(a){
        if(!a)return;var im,id;for(var i=1;i<arguments.length;i++){
            if(typeof arguments[i]=='object')im=arguments[i];if(typeof arguments[i]=='string')id=arguments[i];
        }
        
        this.id=id||'ymarker'+YUtility.getRandomID();this._hidden=false;this._disableAutoContain=false;this._autoExpand=false;var my=YUtility.createNode('img');my.src='http://us.i1.yimg.com/us.yimg.com/i/us/tr/fc/map/orange_bubble_b.png';my.src=im.src;my.style.zIndex=5;my.id=this.id;this._defaults(a,my);
    }
    ;CM.prototype=new Overlay;CM.prototype.constructor=CustomOverlay;CM.prototype.superclass=Overlay.prototype;var Marker=function(gp){
        var im,id;if(!gp)return;for(var i=1;i<arguments.length;i++){
            if(typeof arguments[i]=='object')im=arguments[i];if(typeof arguments[i]=='string')id=arguments[i];
        }
        
        this.id=id||'ymarker'+YUtility.getRandomID();this.YGeoPoint=new YGeoPoint(gp.Lat,gp.Lon);this._hidden=false;this._disableAutoContain=false;this._autoExpand=false;this._defineEvents();this._registerEvents();if(im)this.Image=im;else this.Image=new YImage();this._createMarkerDom();if(typeof(gp)=='string'){
            this.Address=gp;
        }
        
    }
    ;Marker.prototype.setMapObject=function(_m){
        this._map=_m;if(this.Address){
            this._map._startGeoCode(this.Address,12,this.id);
        }
        
    }
    ;Marker.prototype.setYGeoPoint=function(_p){
        this.YGeoPoint=new YGeoPoint(_p.Lat,_p.Lon);this.setGeoXYPoint(this._z,this._posTbl);
    }
    ;Marker.prototype.setGeoXYPoint=function(_z,_a,_l){
        if(_z&&_a){
            var _m=(_l)?(_l):0;var _p=this.calculatePosition(_z);var _k=YUtility._xyKey(_p.tx,_p.ty,_z);if(_a[_k]){
                var ps=this.MP._returnCoordPoint(_a[_k].tx,_a[_k].ty,_p.x,_p.y);this._xy=new YCoordPoint(ps.x+this.Image.offset.x+_m,(ps.y-this.Image.size.height+this.Image.offset.y));if(this._map)
                this._xybr=new YCoordPoint(this._xy.x+parseFloat(this._map.subContainer.style.left),this._xy.y+parseFloat(this._map.subContainer.style.top));this._z=_z;this._posTbl=_a;if(!this._hidden)this.unhide();
            }
            
            else{
                this.hide(true);
            }
            
        }
        
        else{
            this.hide(true);
        }
        
    }
    ;Marker.prototype.hide=function(_i){
        if(!_i)this._hidden=true;this.dom.style.left=this.dom.style.top='-9500px';this.dom.style.zIndex=-9999;
    }
    ;Marker.prototype.ishidden=function(){
        return this._hidden;
    }
    ;Marker.prototype.unhide=function(){
        this._hidden=false;if(this._xy){
            this.dom.style.left=this._xy.x+'px';this.dom.style.top=this._xy.y+'px';if(this.swdom)
            this.dom.style.zIndex=888;else
            this.dom.style.zIndex=1;
        }
        
    }
    ;Marker.prototype._defineEvents=function(){
        this.Events={
            
        }
        ;this.Events.openSmartWindow=new _captureEvent(EventsList.openSmartWindow,this);this.Events.closeSmartWindow=new _captureEvent(EventsList.closeSmartWindow,this);this.Events.openExpanded=new _captureEvent(EventsList.openExpanded,this);this.Events.closeExpanded=new _captureEvent(EventsList.closeExpanded,this);this.Events.MouseClick=new _captureEvent(EventsList.MouseClick,this);this.Events.MouseOver=new _captureEvent(EventsList.MouseOver,this);this.Events.MouseOut=new _captureEvent(EventsList.MouseOut,this);this.Events.MouseDoubleClick=new _captureEvent(EventsList.MouseDoubleClick,this);this.Events.MouseUp=new _captureEvent(EventsList.MouseUp,this);
    }
    ;Marker.prototype._registerEvents=function(){
        YEvent.Capture(this,EventsList.openSmartWindow,this._openSmartWindowRun);YEvent.Capture(this,EventsList.closeSmartWindow,this._closeSmartWindowRun);YEvent.Capture(this,EventsList.openExpanded,this._openExpandedRun);YEvent.Capture(this,EventsList.closeExpanded,this._closeExpandedRun);YEvent.Capture(this,EventsList.MouseClick,this._MouseClickRun,null,'click');YEvent.Capture(this,EventsList.MouseOver,this._MouseOverRun,null,'mouseover');YEvent.Capture(this,EventsList.MouseOut,this._MouseOutRun,null,'mouseout');YEvent.Capture(this,EventsList.MouseDoubleClick,this._runmouseDoubleClick,null,'dblclick');YEvent.Capture(this,EventsList.MouseUp,this._MouseUpRun,null,'mouseup');
    }
    ;Marker.prototype._MouseClickRun=function(_e){
        YEvent.stopPropag(_e);var _ce=new _eO(this);this.Events.MouseClick.trigger(_ce);
    }
    ;Marker.prototype._MouseOverRun=function(_e){
        YEvent.stopEvent(_e);if(this._autoExpand){
            if(_expCache._exmid){
                if(this.id!=_expCache._exmid){
                    _expCache._destroy();
                }
                
            }
            
            if(!this.swdom){
                _expCache.dom.style.zIndex=3;_expCache.setContent(this._expContent);_expCache.setColor(this.swColor);_expCache._exmid=this.id;YUtility.appendNode(this.dom,_expCache.dom);var _ce=(new _eO(this));this.Events.openExpanded.trigger(_ce);
            }
            
        }
        
        var _ce=new _eO(this);this.Events.MouseOver.trigger(_ce);if(this.swdom){
            this.dom.style.zIndex=888;
        }
        
        else{
            this.dom.style.zIndex=2;
        }
        
    }
    ;Marker.prototype._MouseOutRun=function(_e){
        YEvent.stopEvent(_e);var _ce=new _eO(this);this.Events.MouseOut.trigger(_ce);if(this.swdom){
            this.dom.style.zIndex=888;
        }
        
        else if(!this._autoExpand&&!this.swdom){
            this.dom.style.zIndex=1;
        }
        
    }
    ;Marker.prototype._runmouseDoubleClick=function(_e){
        YEvent.stopEvent(_e);var _ce=new _eO(this);this.Events.MouseDoubleClick.trigger(_ce);
    }
    ;Marker.prototype._MouseUpRun=function(_e){
        var _ce=new _eO(this);this.Events.MouseUp.trigger(_ce);
    }
    ;Marker.prototype._openExpandedRun=function(e){
        if(!this.swdom){
            this.dom.style.zIndex=2;_expCache.dom.style.zIndex=3;
        }
        
    }
    ;Marker.prototype._closeExpandedRun=function(e){
        if(this.swdom){
            this.dom.style.zIndex=888;
        }
        
        else{
            this.dom.style.zIndex=1;
        }
        
    }
    ;Marker.prototype._openSmartWindowRun=function(e){
        for(var m in this._map._mTb){
            if(m!=e.thisObj.id){
                if(this._map._mTb[m].swdom){
                    this._map._mTb[m].closeSmartWindow();
                }
                
            }
            
        }
        
        if(this._autoHideControls)
        this._modifyctrls(-1);
    }
    ;Marker.prototype.autoHideControls=function(i){
        this._autoHideControls=(i?false:true);
    }
    ;Marker.prototype._modifyctrls=function(i){
        if(!this._map||!this.swdom){
            this._map._setpanz();this._map._setzoomz();return;
        }
        
        var _i=i?i:0;var _wh=parseInt(this.swdom.style.width);var _tx=this._map.YSize.width-25;var _ty=80;var _lx=this._xybr.x+_wh;var _ly=this._xybr.y-_wh;if(_lx>=_tx&&_ly<_ty){
            this._map._setpanz(_i);this._map._setzoomz(_i);
        }
        
    }
    ;Marker.prototype._closeSmartWindowRun=function(e){
        if(_nodeCache.divsw){
            delete _nodeCache.divsw;
        }
        
        if(this._autoHideControls)
        this._modifyctrls();
    }
    ;Marker.prototype.disableAutoContain=function(){
        this._disableAutoContain=true;
    }
    ;Marker.prototype.enableAutoContain=function(){
        this._disableAutoContain=false;
    }
    ;Marker.prototype.changeImage=function(_o){
        if(YUtility.browser.id==0){
            this.markerImage.style.filter=YUtility.alphaImg(_o.src);
        }
        
        else{
            this.markerImage.src=_o.src;
        }
        
        if(_o.size.width)
        this.markerImage.style.width=_o.size.width;if(_o.size.height)
        this.markerImage.style.height=_o.size.height;
    }
    ;Marker.prototype._createMarkerDom=function(){
        var o=YUtility.cloneNode('div',this.id);o.id=this.id;o.align='left';var _s={
            'position':'absolute','zIndex':1,'width':this.Image.size.width+'px','height':this.Image.size.height+'px'
        }
        ;YUtility.setStyle(o,_s);var m=YUtility.cloneNode('img');m.id='ymi'+this.id;YUtility.setStyle(m,_s);if(!YUtility.browser.id){
            YUtility.setStyle(m,'filter',YUtility.alphaImg(this.Image.src,'image',m));
        }
        else{
            m.src=this.Image.src;
        }
        
        this.markerImage=m;this.dom=o;YUtility.appendNode(this.dom,m);
    }
    ;Marker.prototype.getElement=function(){
        return this.dom;
    }
    ;Marker.prototype.getCoordPoint=function(){
        var x=YUtility.getInt(this.dom.style.left);var y=YUtility.getInt(this.dom.style.top);return new YCoordPoint(x,y);
    }
    ;Marker.prototype.setSmartWindowColor=function(_c){
        var _ac={
            orange:'org',blue:'blu',violet:'blv',brown:'brn',green:'grn',maroon:'mar',ocre:'ocr',purple:'ple'
        }
        ;this.swColor=_ac['org'];if(_ac[_c])
        this.swColor=_ac[_c];
    }
    ;Marker.prototype.reLabel=function(nl){
        if(this._domLabel){
            this._domLabel.innerHTML=nl;
        }
        
    }
    ;Marker.prototype.closeSmartWindow=function(_e){
        if(this.swdom){
            YUtility.removeNode(this.swdom);this.dom.style.zIndex=1;this.swdom=null;var _ce=new _eO(this);this.Events.closeSmartWindow.trigger(_ce)
        }
        
    }
    ;var _expCache=null;Marker.prototype.openAutoExpand=function(_c){
        if(this._autoExpand){
            if(!this.swdom){
                this.dom.style.zIndex=2;_expCache.dom.style.zIndex=3;_expCache.setContent(this._expContent);_expCache.setColor(this.swColor);_expCache._exmid=this.id;YUtility.appendNode(this.dom,_expCache.dom);var _ce=new _eO(this);this.Events.openExpanded.trigger(_ce);
            }
            
        }
        
    }
    ;Marker.prototype.closeAutoExpand=function(_c){
        if(this._autoExpand){
            _expCache._destroy();
        }
        
    }
    ;Marker.prototype.addAutoExpand=function(_c){
        this._autoExpand=true;this._expContent=_c;if(!_expCache){
            _expCache=new SmartWindow(this,_c,this.Image,this.swColor,'swae'+this.id,true);_expCache.dom.style.width='160px';if(!YUtility.browser.id)
            _expCache.dom.style.cursor='hand';
        }
        
    }
    ;Marker.prototype.openSmartWindow=function(_c){
        if(_expCache)
        if(_expCache._exmid){
            _expCache._destroy();
        }
        
        if(this.swdom)return;var _sw=new SmartWindow(this,_c,this.Image,this.swColor,this.id);this.swdom=_sw.dom;YUtility.appendNode(this.dom,this.swdom);this.dom.style.zIndex=888;this.swdom.style.zIndex=888;this.containSmartWindow();YEvent.Capture(this.swdom._swclid,EventsList.MouseClick,this._runXcloser,this,'click');var _ce=new _eO(this);this.Events.openSmartWindow.trigger(_ce)
    }
    ;Marker.prototype._runXcloser=function(_e){
        YEvent.stopEvent(_e);this.closeSmartWindow();
    }
    ;var SmartWindow=function(_mrk,_c,_io,_clr,id,_ae){
        this._marker=_mrk;this._aeon=(_ae)?true:false;this._swid='ysmw'+((id)?id:'');if(this._aeon)
        this._swid='ysmwexp';this._clids='clw'+this._swid;this._createNode();this.setColor(_clr);this.setContent(_c);this.setPosition(_io);this._defineEvents();this._registerEvents();if(!this._aeon)
        YEvent.Capture(this.dom,EventsList.MouseDown,function(_e){
            YEvent.stopPropag(_e);
        }
        ,null,'mousedown');
    }
    ;SmartWindow.prototype._defineEvents=function(){
        this.Events={
            
        }
        ;this.Events.MouseClick=new _captureEvent(EventsList.MouseClick,this);this.Events.MouseOver=new _captureEvent(EventsList.MouseOver,this);this.Events.MouseOut=new _captureEvent(EventsList.MouseOut,this);this.Events.MouseDoubleClick=new _captureEvent(EventsList.MouseDoubleClick,this);this.Events.MouseUp=new _captureEvent(EventsList.MouseUp,this);
    }
    ;SmartWindow.prototype._registerEvents=function(){
        YEvent.Capture(this,EventsList.MouseClick,this._MouseClickRun,null,'click');YEvent.Capture(this,EventsList.MouseOver,this._MouseOverRun,null,'mouseover');YEvent.Capture(this,EventsList.MouseOut,this._MouseOutRun,null,'mouseout');YEvent.Capture(this,EventsList.MouseDoubleClick,this._runmouseDoubleClick,null,'dblclick');YEvent.Capture(this,EventsList.MouseUp,this._MouseUpRun,null,'mouseup');
    }
    ;SmartWindow.prototype._MouseClickRun=function(_e){
        YEvent.stopPropag(_e);if(this._aeon){
            var marker=this._marker._map._mTb[this._exmid];if(marker){
                var _ce=new _eO(marker);marker.Events.MouseClick.trigger(_ce);
            }
            
        }
        
    }
    ;SmartWindow.prototype._MouseOverRun=function(_e){
        YEvent.stopEvent(_e);
    }
    ;SmartWindow.prototype._MouseOutRun=function(_e){
        YEvent.stopEvent(_e);if(_expCache)
        _expCache._destroy();
    }
    ;SmartWindow.prototype._runmouseDoubleClick=function(_e){
        YEvent.stopEvent(_e);
    }
    ;SmartWindow.prototype._MouseUpRun=function(_e){
        
    }
    ;SmartWindow.prototype._createNode=function(){
        this.dom=YUtility.cloneNode('div','sw');this.dom.id=this._swid;this.dom._swclid=this._clids;
    }
    ;SmartWindow.prototype._destroy=function(_w){
        if(this._exmid){
            var marker=this._marker._map._mTb[this._exmid];var _ce=new _eO(marker);if(marker)
            marker.Events.closeExpanded.trigger(_ce);
        }
        
        else{
            
        }
        
        if(this._exmid)
        this._exmid=null;YUtility.removeNode(this.dom);
    }
    ;SmartWindow.prototype._hide=function(){
        YUtility.setStyle(this.dom,'zIndex',-10);
    }
    ;SmartWindow.prototype._show=function(){
        YUtility.setStyle(this.dom,'zIndex',99);
    }
    ;SmartWindow.prototype.setPosition=function(o){
        if(!o)return;var _x=o.offsetSmartWindow.x+'px';var _y=o.offsetSmartWindow.y+'px';var _so={
            'position':'absolute','left':_x,'bottom':_y
        }
        ;YUtility.setStyle(this.dom,_so);
    }
    ;SmartWindow.prototype._combine=function(){
        this.dom.innerHTML=this._sc+this._data+this._ec;
    }
    ;SmartWindow.prototype.setContent=function(_c){
        if(!_c)return;this._data=_c;if(_c.nodeValue)this._data=_c.nodeValue;this._combine();
    }
    ;SmartWindow.prototype.setColor=function(_clr){
        var w=new _sw(_clr,this._clids,this._aeon);this._sc=w._sc;this._ec=w._ec;this._combine();
    }
    ;var _sw=function(_clr,_clids,ae){
        var _s,_sw,_ne,_se,_e,_nw,_n,_w;var _swi=_baseURL;var _col=(_clr)?_clr:'org';var _cls=_swi+'x.gif';if(!YUtility.browser.id){
            _s="filter:"+YUtility.alphaImg(_swi+_col+'_s.png','scale');_sw="filter:"+YUtility.alphaImg(_swi+_col+'_sw.png','scale');_ne="filter:"+YUtility.alphaImg(_swi+_col+'_ne.png','scale');_se="filter:"+YUtility.alphaImg(_swi+_col+'_se.png','scale');_e="filter:"+YUtility.alphaImg(_swi+_col+'_e.png','scale');_nw="filter:"+YUtility.alphaImg(_swi+_col+'_nw.png','scale');_n="filter:"+YUtility.alphaImg(_swi+_col+'_n.png','scale');_w="filter:"+YUtility.alphaImg(_swi+_col+'_w.png','scale');
        }
        else{
            _nw="background:url("+_swi+_col+"_nw.png) bottom no-repeat;";_n="background:url("+_swi+_col+"_n.png) bottom repeat-x;";_ne="background:url("+_swi+_col+"_ne.png) bottom left no-repeat;";_sw="background:url("+_swi+_col+"_sw.png);";_s="background:url("+_swi+_col+"_s.png) repeat-x;";_se="background:url("+_swi+_col+"_se.png) no-repeat;";_e="background:url("+_swi+_col+"_e.png) repeat-y;";_w="background:url("+_swi+_col+"_w.png) repeat-y;";
        }
        
        var _x='';var _spid='yswid';if(!ae){
            _x='<a href="javascript:void(0);" id="'+_clids+'"><img src="'+_swi+'x.gif" alt="" width="12" height="12" border="0"></a>';_spid='ysaeid';
        }
        
        this._sc='<div><table cellspacing="0" cellpadding="0" border="0"><tr style="line-height:6px"><td style="line-height:6px; '+_nw+'">&nbsp;</td><td style="line-height:6px; '+_n+'"></td><td style="line-height:6px; '+_ne+'"></td></tr><tr><td style="'+_w+'"></td> <td align=right valign=top bgcolor="#ffffff">'+_x+'<div id="'+_spid+'" style="text-align:left;">';this._ec='</div></td><td style="'+_e+'">&nbsp;&nbsp;&nbsp;</td></tr><tr style="height:16px;"><td style="'+_sw+'"></td><td style="'+_s+'"></td><td style="'+_se+'"></td></tr></table></div>';YEvent.Capture(_spid,EventsList.MouseOut,function(_e){
            YEvent.stopPropag(_e);
        }
        ,null,'mouseout');
    }
    ;Marker.prototype.containSmartWindow=function(){
        var _x=_y=0;var _ws;if(this.swdom){
            _ws=YUtility.getSize(this.swdom);
        }
        else if(_expCache){
            _ws=YUtility.getSize(_expCache.dom);
        }
        else{
            return;
        }
        
        this.swdom.style.width='160px';var _mp=this._map._ll2xy(this.YGeoPoint);var _mvbx=_ws.width;var _mvby=_ws.height;var cmX=this.Image.size.width+this.Image.offsetSmartWindow.x;var cmY=this.Image.size.height+this.Image.offsetSmartWindow.y;var nx=_mvbx-(this._map.YSize.width-_mp.x);var ny=_mp.y-_mvby;var _off=0;if(_mp.x<_off){
            _x=cmX-_mp.x;
        }
        
        else if(nx>0){
            _x=-(nx+cmX);
        }
        
        if(ny<_off){
            _y=-(ny-cmY);
        }
        
        else if(_mp.y>this._map.YSize.height){
            _y=this._map.YSize.height-_mp.y-cmY;
        }
        
        if(!this._disableAutoContain){
            this._map.smoothMoveByXY(new YCoordPoint(_x,_y));
        }
        
    }
    ;Marker.prototype.addLabel=function(cin){
        if(this._domLabel)return;var o=YUtility.createNode('div');o.style.position="absolute";o.style.fontWeight="bold";o.style.textAlign='center';o.style.width='20px';o.style.height='20px';o.onmouseover=function(){
            o.style.cursor='default';
        }
        
        o.style.zIndex=1;o.innerHTML=cin;this._domLabel=o;YUtility.setDefaultSelectStyle(o);YUtility.appendNode(this.dom,this._domLabel);
    }
    ;Marker.prototype.calculatePosition=function(z){
        this.MP=new MercatorProjection(z);return this.MP.ll_to_xy(this.YGeoPoint,77);
    }
    ;var GeoCode=function(a,m){
        if(!m)return;this.GeoAddress=a||false;this.Obj=m;this.getPoint=GeoCode.getPoint;
    }
    ;GeoCode.prototype.set=function(s,t,id){
        var mID=(id)?id:'map';var qtype=(t)?t:99;var rnd=YUtility.getRandomID();var _id='ygeocodenode:'+rnd;if(s){
            var req="http://api.maps.yahoo.com/ajax/geocode?";req+="appid="+YMAPPID+"&qs="+escape(s)+"&qt="+qtype;req+="&mid="+this.Obj.id;req+="&id="+mID+"&r="+rnd;YUtility.dynamicSNode(_id,req);
        }
        
    }
    ;GeoCode.getPoint=function(s,t){
        if(s&&s.GeoMID){
            _GTab[s.GeoMID]._endGeoCode(s,t);
        }
        
    }
    ;var GeoRSS=function(a){
        this.GeoRSS=a||false;this.Obj=null;
    }
    ;GeoRSS.prototype.set=function(s,m,t){
        this.Obj=m;var rnd=YUtility.getRandomID();var _id='ygeorssnode:'+rnd;if(s){
            var req="http://api.maps.yahoo.com/ajax/georss?";req+="appid="+YMAPPID+"&xml="+escape(s)+"&r="+YUtility.getRandomID()+"&mid="+this.Obj.id+"&t="+t;YUtility.dynamicSNode(_id,req);
        }
        
    }
    ;GeoRSS.get=function(s,m,t){
        if(s&&m){
            _GTab[m]._endGeoRSS(s,t);
        }
        
    }
    ;var Template=function(p,d){
        this._p=p;this._d=d;
    }
    ;Template.prototype.process=function(){
        var im=new YImage();if(this._d.BASEICON){
            im.src=this._d.BASEICON.src;var w=this._d.BASEICON.width?this._d.BASEICON.width:10;var h=this._d.BASEICON.height?this._d.BASEICON.height:15;im.size=new YSize(w,h);im.offsetSmartWindow=new YCoordPoint(0,h);
        }
        
        var mrk=new YMarker(this._p,im);var csy=this._d.YMAPS_CITYSTATE?this._d.YMAPS_CITYSTATE:'';var zip=this._d.YMAPS_ZIP?this._d.YMAPS_ZIP:'';var sw=new Object();sw.title=this._d.TITLE?"<b>"+this._d.TITLE+"</b><br/>":'';sw.address=this._d.YMAPS_ADDRESS?this._d.YMAPS_ADDRESS+"<br/>":'';sw.city_state=csy?csy+"<br/>":'';sw.phone=this._d.YMAPS_PHONENUMBER?this._d.YMAPS_PHONENUMBER+"<br/>":'';sw.description=(this._d.DESCRIPTION)?"<div style='width:200px;'>"+this._d.DESCRIPTION+"</div><br/>":'';sw.link=this._d.LINK?"<a href='"+this._d.LINK+"' target='_blank'>":'';sw.lnam=sw.link?sw.title+"</a>":'';sw.eimgTitle=sw.eimg='';if(this._d.YMAPS_EXTRAIMAGE){
            sw.eimgTitle=this._d.YMAPS_EXTRAIMAGE.TITLE?this._d.YMAPS_EXTRAIMAGE.TITLE:'';sw.eimg=this._d.YMAPS_EXTRAIMAGE.URL?"<br/><img src=\""+this._d.YMAPS_EXTRAIMAGE.URL+"\" border=0 title=\""+sw.eimgTitle+"\">":'';
        }
        
        sw.itmurl=this._d.YMAPS_ITEMURL?"<iframe src=\""+this._d.YMAPS_ITEMURL+"\"></iframe>":'';sw.dirt="<a href=\"http://maps.yahoo.com/dd?taddr="+escape(this._d.YMAPS_ADDRESS)+"&tlt="
        +this._d.GEO_LAT+"&tln="+this._d.GEO_LONG+"&tname="
        +this._d.TITLE+"&tcsz="+escape(csy)+" "+zip
        +"+&terr=12\" target=_blank>To here</a>";sw.dirf="<a href=\"http://maps.yahoo.com/dd?newaddr="+escape(this._d.YMAPS_ADDRESS)+"&slt="
        +this._d.GEO_LAT+"&sln="+this._d.GEO_LONG+"&name="
        +this._d.TITLE+"&csz="+escape(csy)+" "+zip
        +"&oerr=12\" target=_blank>From here</a>";sw.dirline=(csy||zip)?"Directions: "+sw.dirt+" - "+sw.dirf:'';var ht="<div style='margin: 0 3px 2px 3px;'>"
        +"<font face=\"verdana,geneva,sans-serif\" size=\"-2\">"
        +sw.title
        +sw.address
        +sw.city_state
        +sw.phone
        +sw.description
        +sw.link
        +sw.lnam
        +sw.dirline
        +sw.eimg
        +sw.itmurl
        +"</font></div>";YEvent.Capture(mrk,EventsList.MouseClick,function(){
            this.openSmartWindow(ht);
        }
        );return mrk;
    }
    ;var _pEvent=function(_t){
        this._type=_t;
    }
    ;var _eO=function(o,p,z){
        this.thisObj=o;this.YGeoPoint=p;this.zoomObj=z;
    }
    ;function eventObject(m){
        this.ThisMap=m;
    }
    
    function eventObjectGeoRSS(m,u,d){
        this.ThisMap=m;this.URL=u;this.Data=d||null;this.success=(d&&d.success)?d.success:0;
    }
    
    function eventObjectGeoCode(m,a,g,s){
        this.ThisMap=m;this.Address=a;this.GeoPoint=g||null;this.success=s||0;
    }
    
    var _GTab={
        
    }
    ;YAHOO_MAP_REG='YAHOO_MAP';YAHOO_MAP_SAT='YAHOO_SAT';YAHOO_MAP_HYB='YAHOO_HYB';var Map=function(_c,_t,_s){
        try{
            this.YSize=this._getContainerSize(_c,_s);
        }
        catch(x){
            throw("Y!Map.Error "+x+", no container object!");
        }
        
        this._defaultStart();this._setParentContainer(_c);this._ylogo();this._defineEvents();this._registerEvents();this.setMapType(_t);this._tileCache=[];this._posTbl=[];this._mTb=[];this._totalX=this._totalY=0;this.id='ymap'+YUtility.getRandomID();_GTab[this.id]=this;
    }
    ;Map.prototype={
        _defaultStart:function(){
            this._mapType=YAHOO_MAP_REG;this.setZoomRange(1,17);this._disableDrag=false;this.zoomLevelPrev=null;
        }
        ,_setMapTypeHigh:function(_i){
            var _t=(_i)?_i:this._mapType;var _p='ytype';var _k=_p+_t;if(this._coordTable[_k]){
                var _tps=this.getMapTypes();
				for(var i=0;i<_tps.length;i++){
                    var _ik=_p+_tps[i];

					if(_ik==_k){
                        this._coordTable[_ik].dom.style.borderWidth='1px';
                    }
                    else{
                        this._coordTable[_ik].dom.style.borderWidth='0px';
                    }
                    
                }
                
            }
            
        }
        ,setMapType:function(_t){
            if(!_t||this._mapType==_t)return;this._mapType=_t;this._setMapTypeHigh();if(this.YGeoPoint)
            this.drawZoomAndCenter(this.YGeoPoint,this.zoomLevel);
        }
        ,getMapTypes:function(){
            var _t=[YAHOO_MAP_REG,YAHOO_MAP_SAT,YAHOO_MAP_HYB];return _t;
        }
        ,getCurrentMapType:function(){
            return this._mapType;
        }
        ,addTypeControl:function(_t){
            var _mC,_sC,_hC;for(var i in _t){
                if(_t[i]==YAHOO_MAP_REG)
                _mC=true;if(_t[i]==YAHOO_MAP_SAT)
                _sC=true;if(_t[i]==YAHOO_MAP_HYB)
                _hC=true;
            }
            
            if(!_t)
            _mC=_sC=_hC=true;var _st='ytype';var _mid=_st+YAHOO_MAP_REG;var _dm=YUtility.cloneNode('div',_mid);var _m=YUtility.cloneNode('img',_mid);_m.src=_baseURL+'med_map.png?v=1.3';YUtility.appendNode(_dm,_m);var _hid=_st+YAHOO_MAP_HYB;var _dh=YUtility.cloneNode('div',_hid);var _h=YUtility.cloneNode('img',_hid);_h.src=_baseURL+'med_hyb.png?v=1.3';YUtility.appendNode(_dh,_h);var _sid=_st+YAHOO_MAP_SAT;var _ds=YUtility.cloneNode('div',_sid);var _s=YUtility.cloneNode('img',_sid);_s.src=_baseURL+'med_sat.png?v=1.3';YUtility.appendNode(_ds,_s);var _ss={
                borderColor:'white',borderStyle:'solid',borderWidth:'0px',width:'33px',height:'17px'
            }
            ;if(!YUtility.browser.id)
            _ss.cursor='hand';YUtility.setStyle(_m,_ss);YUtility.setStyle(_dm,_ss);YUtility.setStyle(_h,_ss);YUtility.setStyle(_dh,_ss);YUtility.setStyle(_s,_ss);YUtility.setStyle(_ds,_ss);var _mo=new YCustomOverlay(new YCoordPoint(5,10),_dm);_mo.id=_mid;var _ho=new YCustomOverlay(new YCoordPoint(5,30),_dh);_ho.id=_hid;var _so=new YCustomOverlay(new YCoordPoint(5,50),_ds);_so.id=_sid;YEvent.Capture(_mo,EventsList.MouseClick,this._runMapRegTypeClick,this,'click');YEvent.Capture(_ho,EventsList.MouseClick,this._runMapHybTypeClick,this,'click');YEvent.Capture(_so,EventsList.MouseClick,this._runMapSatTypeClick,this,'click');YEvent.Capture(_mo,EventsList.MouseDoubleClick,this._runSilentDoubleClick,this,'dblclick');YEvent.Capture(_ho,EventsList.MouseDoubleClick,this._runSilentDoubleClick,this,'dblclick');YEvent.Capture(_so,EventsList.MouseDoubleClick,this._runSilentDoubleClick,this,'dblclick');if(_mC)this.addOverlay(_mo);if(_hC)this.addOverlay(_ho);if(_sC)this.addOverlay(_so);var _ce=new _eO(this,this.YGeoPoint);this.Events.MapTypeControlAdded.trigger(_ce);
        }
        ,_runMapRegTypeClick:function(_e){
            YEvent.stopEvent(_e);this.setMapType(YAHOO_MAP_REG);var _ce=new _eO(this,this.YGeoPoint);this.Events.changeMapType.trigger(_ce);
        }
        ,_runMapHybTypeClick:function(_e){
            YEvent.stopEvent(_e);this.setMapType(YAHOO_MAP_HYB);var _ce=new _eO(this,this.YGeoPoint);this.Events.changeMapType.trigger(_ce);
        }
        ,_runMapSatTypeClick:function(_e){
            YEvent.stopEvent(_e);this.setMapType(YAHOO_MAP_SAT);var _ce=new _eO(this,this.YGeoPoint);this.Events.changeMapType.trigger(_ce);
        }
        ,_runSilentDoubleClick:function(_e){
            YEvent.stopEvent(_e);YEvent.stopDefault(_e);YEvent.stopPropag(_e);
        }
        ,_showMini:function(){
            this._navigatorLayer.setMapParent(this);
        }
        ,addNavigatorControl:function(){
            if(!this._navigatorLayer){
                var r=-5;var t=140;this._navdockLayer=new Dock({
                    bottom:t,right:r
                }
                ,this.getElement());this._navigatorLayer=new Navigator({
                    bottom:t,right:r
                }
                ,this.getElement());this._navdockLayer.attach(this._navigatorLayer);var _ce=(new _eO(this,this.YGeoPoint,{
                    previous:this.zoomLevelPrev,current:this.zoomLevel
                }
                ));this.Events.miniAdded.trigger(_ce);
            }
            
        }
        ,_setZoomLevel:function(z,p){
            this.zoomLevelPrev=p||this.zoomLevel;this.drawZoomAndCenter(this.YGeoPoint,z);if(Math.abs(this.zoomLevelPrev-this.zoomLevel)>0){
                var _ce=(new _eO(this,this.YGeoPoint,{
                    previous:this.zoomLevelPrev,current:this.zoomLevel
                }
                ));this.Events.changeZoom.trigger(_ce);
            }
            
        }
        ,_enableZoomControl:function(type){
            var _t=5;if(!this._zoomControl){
                if(type!='s'){
                    this._zoomControl=new LongZoom({
                        top:_t,right:5
                    }
                    ,this.getElement());
                }
                
                else{
                    this._zoomControl=new ShortZoom({
                        top:10,right:5
                    }
                    ,this.getElement());
                }
                
                this._zoomControl.setMin(this._zoomMin);this._zoomControl.setMax(this._zoomMax);this._zoomControl.setValue(this.zoomLevel);this._zoomControl.setCallback(this._zoomHandler,this);var _ce=(new _eO(this,this.YGeoPoint,{
                    previous:this.zoomLevelPrev,current:this.zoomLevel
                }
                ));this.Events.zoomAdded.trigger(_ce);
            }
            
        }
        ,_zoomHandler:function(z,context){
            if(z>context._zoomMax)return;if(z<context._zoomMin)return;context.setZoomLevel(z);context._zoomControl.setValue(z);
        }
        ,setZoomRange:function(min,max){
            this._zoomMin=min;this._zoomMax=max;if(this._zoomControl){
                this._zoomControl.setMin(this._zoomMin);this._zoomControl.setMax(this._zoomMax);
            }
            
        }
        ,getElement:function(){
            return this.dom;
        }
        ,_enablePointPan:function(){
            if(!this._panLayer){
                this._panLayer=new Pan({
                    top:10,right:25
                }
                ,this.getElement());this._panLayer.setCallback(this._panHandler,this);if(this._zoomLayer){
                    this._zoomLayer.setStyle({
                        top:70,right:23
                    }
                    );
                }
                
            }
            
        }
        ,_setzoomz:function(i){
            var _v=i?15:75;this._zoomControl._element.style.filter='alpha(opacity='+_v+')';this._zoomControl._element.style.opacity=_v/100;
        }
        ,_setpanz:function(i){
            var _v=i?15:75;this._panLayer._element.style.filter='alpha(opacity='+_v+')';this._panLayer._element.style.opacity=_v/100;
        }
        ,_panHandler:function(xmove,ymove,context){
            var speed=200;var pt=new YCoordPoint(speed*xmove,speed*ymove);context.smoothMoveByXY(pt);
        }
        ,_ylogo:function(){
            var _l=YUtility.cloneNode('img','ylogo');var _s={
                position:'absolute',width:71,height:13,zIndex:3
            }
            ;_l.src=_baseURL+'yahoo.png';YUtility.setStyle(_l,_s);var _p=new YCoordPoint(1,12);_p.translate('right','bottom');var _ol=new YCustomOverlay(_p,_l);_ol.id='ylogo';this.addOverlay(_ol);
        }
        ,_datacopy:function(){
            var _sc={
                position:'absolute',zIndex:3,cursor:'default',textAlign:'left'
            }
            ;var _id='ycopy1';var _l1=YUtility.cloneNode('div',_id);_l1.innerHTML='<span style="font:.6em verdana;">Data &copy;Navteq, TeleAtlas</span>';YUtility.setStyle(_l1,_sc);var _p1=new YCoordPoint(1,1);_p1.translate('left','bottom');var _ovcpy1=new YCustomOverlay(_p1,_l1);_ovcpy1.id=_id;this.addOverlay(_ovcpy1);
        }
        ,_satcopy:function(np){
            var _sc={
                position:'absolute',zIndex:3,cursor:'default',height:'10px',textAlign:'left'
            }
            ;var _id='ycopy3';var _l3=YUtility.cloneNode('img',_id);_l3.src=this._cpySrv+'x='+this._txy.tx+'&y='+this._txy.ty+'&z='+this.zoomLevel+'&ew=1&ns=1';YUtility.setStyle(_l3,_sc);var _p3=(np)?np:new YCoordPoint(1,0);_p3.translate('left','bottom');var _ovcpy3=new YCustomOverlay(_p3,_l3);_ovcpy3.id=_id;this.addOverlay(_ovcpy3);
        }
        ,disableCopyright:function(){
            this._disableCopy=true;
        }
        ,_ycopy:function(){
            if(this._disableCopy)return;var _sc={
                position:'absolute',zIndex:3,cursor:'default',textAlign:'left'
            }
            ;this.removeOverlay('ycopy1');this.removeOverlay('ycopy3');if(this._mapType==YAHOO_MAP_REG){
                this._datacopy();
            }
            
            else if(this._mapType==YAHOO_MAP_SAT){
                this._satcopy();
            }
            
            else if(this._mapType==YAHOO_MAP_HYB){
                this._datacopy();this._satcopy(new YCoordPoint(142,0));
            }
            
            var _l2=YUtility.cloneNode('div','ycopy2');_l2.innerHTML='<span style="font:.6em verdana;">&copy;2006 Yahoo! Inc.</span>';YUtility.setStyle(_l2,_sc);YUtility.setStyle(_l2,'textAlign','right');var _p2=new YCoordPoint(1,1);_p2.translate('right','bottom');var _ol2=new YCustomOverlay(_p2,_l2);_ol2.id='ycopy2';this.addOverlay(_ol2);
        }
        ,_yscale:function(){
            if(this._disableScale)return;
			var upp=this.getUnitsPerPixel();
			var ukm=(this._zr[this.zoomLevel-1])?this._zr[this.zoomLevel-1][2][0]:0;
			var umi=(this._zr[this.zoomLevel-1])?this._zr[this.zoomLevel-1][2][1]:0;
			var pkm=YUtility.getInt(1/upp.kilometers*ukm)+'px';
			var pmi=YUtility.getInt(1/upp.miles*umi)+'px';
			if (parseInt(pkm) < 0) { pkm = "0px"; }
			if (parseInt(pmi) < 0) { pmi = "0px"; }
			ukm=(ukm<0.5)?ukm*1000+'  m':ukm+'  km';umi=(umi<0.5)?umi*5280+'  ft':umi+'  mi';var oid='yzscale'+this.id;var myo=YUtility.getByID(oid);
			if(!myo){
                var _skml=YUtility.cloneNode('img','ysc');
				_skml.src=_baseURL+'zsl.gif';_skml.style.width='4px';
				_skml.style.height='8px';
				var _skmm=YUtility.cloneNode('img','ysc');
				_skmm.src=_baseURL+'zs.gif';
				_skmm.style.width=pkm;
				_skmm.style.height='8px';
				var _skmr=YUtility.cloneNode('img','ysc');
				_skmr.src=_baseURL+'zsr.gif';
				_skmr.style.width='4px';
				_skmr.style.height='8px';
				var _km=YUtility.cloneNode('span','ztxt');
				_km.innerHTML=ukm;_km.style.position='relative';
				_km.style.top='-1px';
				var _smil=YUtility.cloneNode('img','ysc');
				_smil.src=_baseURL+'zsl.gif';_smil.style.width='4px';_smil.style.height='8px';
				var _smim=YUtility.cloneNode('img','ysc');_smim.src=_baseURL+'zs.gif';_smim.style.width=pmi;
				_smim.style.height='8px';var _smir=YUtility.cloneNode('img','ysc');_smir.src=_baseURL+'zsr.gif';
				_smir.style.width='4px';_smir.style.height='8px';var _mi=YUtility.cloneNode('span','ztxt');
				_mi.innerHTML=umi;_mi.style.position='relative';_mi.style.top='-1px';var _br=YUtility.cloneNode('br');
				var o=YUtility.cloneNode('div',oid);o.align='left';o.id=oid;o._km=_skmm;o._kmtxt=_km;o._mi=_smim;
				o._mitxt=_mi;var _s={'position':'absolute','bottom':'12px','left':'1px','zIndex':3,'font':'normal 9px verdana'};
				YUtility.setStyle(o,_s);YUtility.appendNode(o,_skml);YUtility.appendNode(o,_skmm);YUtility.appendNode(o,_skmr);YUtility.appendNode(o,_km);YUtility.appendNode(o,_br);YUtility.appendNode(o,_smil);YUtility.appendNode(o,_smim);YUtility.appendNode(o,_smir);YUtility.appendNode(o,_mi);var _p=new YCoordPoint(1,12);_p.translate('left','bottom');var _ol=new YCustomOverlay(_p,o);this.addOverlay(_ol);
            }
            else{
                myo._km.style.width=pkm;myo._kmtxt.innerHTML=ukm;myo._mi.style.width=pmi;myo._mitxt.innerHTML=umi;
            }
            
        }
        ,_defineEvents:function(){
            this.Events={
                
            }
            ;this.Events.endPan=new _captureEvent(EventsList.endPan,this);this.Events.endAutoPan=new _captureEvent(EventsList.endAutoPan,this);this.Events.startPan=new _captureEvent(EventsList.startPan,this);this.Events.startAutoPan=new _captureEvent(EventsList.startAutoPan,this);this.Events.onPan=new _captureEvent(EventsList.onPan,this);this.Events.changeZoom=new _captureEvent(EventsList.changeZoom,this);this.Events.changeMapType=new _captureEvent(EventsList.changeMapType,this);this.Events.onStartGeoCode=new _captureEvent(EventsList.onStartGeoCode,this);this.Events.onEndGeoCode=new _captureEvent(EventsList.onEndGeoCode,this);this.Events.onStartGeoRSS=new _captureEvent(EventsList.onStartGeoRSS,this);this.Events.onEndGeoRSS=new _captureEvent(EventsList.onEndGeoRSS,this);this.Events.endMapDraw=new _captureEvent(EventsList.endMapDraw,this);this.Events.zoomAdded=new _captureEvent(EventsList.zoomAdded,this);this.Events.MapTypeControlAdded=new _captureEvent(EventsList.MapTypeControlAdded,this);this.Events.miniAdded=new _captureEvent(EventsList.miniAdded,this);this.Events.MouseClick=new _captureEvent(EventsList.MouseClick,this);this.Events.MouseUp=new _captureEvent(EventsList.MouseUp,this);this.Events.MouseDoubleClick=new _captureEvent(EventsList.MouseDoubleClick,this);this.Events.MouseOver=new _captureEvent(EventsList.MouseOver,this);this.Events.MouseDown=new _captureEvent(EventsList.MouseDown,this);this._endPan=true;this.keyTypes={
                
            }
            ;this.keyTypes.zoomIn=1;this.keyTypes.zoomOut=2;this.keyTypes.panN=3;this.keyTypes.panS=4;this.keyTypes.panW=5;this.keyTypes.panE=6;this.keyTypes.panNW=7;this.keyTypes.panNE=8;this.keyTypes.panSW=9;this.keyTypes.panSE=10;this.Events.KeyDown=new _captureEvent(EventsList.KeyDown,this);this.Events.KeyUp=new _captureEvent(EventsList.KeyUp,this);
        }
        ,_registerEvents:function(){
            YEvent.Capture(window,EventsList.resize,this._onResizeRun,this);YEvent.Capture(window,EventsList.unload,this._runUnload,this);YEvent.Capture(this,EventsList.wheel,this._runWheel);YEvent.Capture(this,EventsList.endMapDraw,this._endMapDrawRun);YEvent.Capture(this,EventsList.zoomAdded,this._zoomAddedRun);YEvent.Capture(this,EventsList.MapTypeControlAdded,this._MapTypeControlAddedRun);YEvent.Capture(this,EventsList.miniAdded,this._miniAddedRun);YEvent.Capture(this,EventsList.endPan,this._runendPan);YEvent.Capture(this,EventsList.endAutoPan,this._runendPan);YEvent.Capture(this,EventsList.startPan,this._runstartPan);YEvent.Capture(this,EventsList.onPan,this._runonPan);YEvent.Capture(this,EventsList.changeZoom,this._runchangeZoom);YEvent.Capture(this,EventsList.changeMapType,this._changeMapTypeRun);YEvent.Capture(this,EventsList.MouseClick,this._MouseClickRun,null,'click');YEvent.Capture(this,EventsList.MouseUp,this._MouseUpRun,null,'mouseup');YEvent.Capture(this,EventsList.MouseDoubleClick,this._rundoubleClick,null,'dblclick');YEvent.Capture(this,EventsList.MouseDown,this._MouseDownRun,null,'mousedown');YEvent.Capture(this,EventsList.MouseOver,this._MouseOverRun,null,'mouseover');YEvent.Capture(document,EventsList.KeyDown,this._runkeyDown,this,'keydown');YEvent.Capture(document,EventsList.KeyUp,this._runkeyUp,this,'keyup');YEvent.Capture(this,EventsList.KeyDown,this._keyZoom);YEvent.Capture(this,EventsList.KeyDown,this._keyPan);
        }
        ,_changeMapTypeRun:function(_e){
            
        }
        ,_MapTypeControlAddedRun:function(_e){
            this._setMapTypeHigh();
        }
        ,_miniAddedRun:function(_e){
            this._miniON=true;
        }
        ,_zoomAddedRun:function(_e){
            this._zoomON=true;
        }
        ,_panAddedRun:function(_e){
            this._panON=true;
        }
        ,_startGeoCode:function(_a,_t,_id){
            var _n=new GeoCode(_a,this);_n.set(_n.GeoAddress,_t,_id);var _ce=new eventObjectGeoCode(this,_a);this.Events.onStartGeoCode.trigger(_ce);
        }
        ,_endGeoCode:function(_e,_t){
            if(_t==10){
                this.drawZoomAndCenter(_e.GeoPoint,this.zoomLevel);
            }
            
            if(_t==11){
                this.addMarker(_e.GeoPoint);
            }
            
            if(_t==12){
                if(this._mTb[_e.GeoID]){
                    this._mTb[_e.GeoID].setYGeoPoint(_e.GeoPoint);this._mTb[_e.GeoID].setGeoXYPoint(this.zoomLevel,this._posTbl);
                }
                
            }
            
            var _gp=new YGeoPoint(_e.GeoPoint.Lat,_e.GeoPoint.Lon);var _ce=new eventObjectGeoCode(this,_e.GeoAddress,_gp,_e.success);this.Events.onEndGeoCode.trigger(_ce);
        }
        ,_startGeoRSS:function(_o,_t){
            _o.set(_o.GeoRSS,this,_t);var _ce=new eventObjectGeoRSS(this,_o);this.Events.onStartGeoRSS.trigger(_ce);
        }
        ,_endGeoRSS:function(_e,_t){
            if(_t==1){
                var _c=this.getBoxGeoCenter(_e.GEOBOX.MIN,_e.GEOBOX.MAX);var _z=this.getZoomLevel(_e.GEOBOX.MIN,_e.GEOBOX.MAX);this.drawZoomAndCenter(_c,_z);for(var o in _e.ITEMS){
                    var i=_e.ITEMS[o];var p=new YGeoPoint(i.GEO_LAT,i.GEO_LONG);var t=new Template(p,i);var m=t.process();this.addOverlay(m);
                }
                
            }
            
            if(_t==2){
                
            }
            
            var _ce=new eventObjectGeoRSS(this,_e.URL,_e);this.Events.onEndGeoRSS.trigger(_ce);
        }
        ,_endMapDrawRun:function(_e){
            if(this._zoomON==true){
                this._zoomControl.setValue(this.zoomLevel);
            }
            
            if(this._disableDrag==true){
                this.disableDragMap();
            }
            this._yscale();
			this._ycopy();
			if(this._miniON==true){
                this._showMini();
            }
            
        }
        ,_runUnload:function(_e){
            this._clearView();for(var m in this._mTb){
                if(this._mTb[m].aedom)
                YUtility.removeNode(this._mTb[m].aedom);if(this._mTb[m].swdom)
                YUtility.removeNode(this._mTb[m].swdom);YUtility.deleak(this._mTb[m]);YUtility.removeNode(this._mTb[m].dom);
            }
            
            YUtility.deleak(_expCache);
        }
        ,_runWheel:function(_e){
            if(this._disableKeys)return;var _d;if(_e.detail)
            _d=YUtility.getInt(_e.detail)*(-40);if(_e.wheelDelta)
            _d=_e.wheelDelta;if(_d>=120){
                this.setZoomLevel(this.zoomLevel-1);
            }
            else{
                this.setZoomLevel(this.zoomLevel+1);
            }
            
        }
        ,_getKeyType:function(_k){
            var _ks={
                '109':this.keyTypes.zoomOut,'45':this.keyTypes.zoomOut,'107':this.keyTypes.zoomIn,'61':this.keyTypes.zoomIn,'46':this.keyTypes.zoomIn,'38':this.keyTypes.panN,'40':this.keyTypes.panS,'37':this.keyTypes.panW,'188':this.keyTypes.panW,'39':this.keyTypes.panE,'190':this.keyTypes.panE,'36':this.keyTypes.panNW,'33':this.keyTypes.panNE,'35':this.keyTypes.panSW,'34':this.keyTypes.panSE,'_':''
            }
            ;if(_ks[_k])
            return _ks[_k];return false;
        }
        ,_keyZoom:function(_e,_k){
            if(this._disableKeys)return;if(this._getKeyType(_k)==this.keyTypes.zoomIn){
                this.setZoomLevel(this.zoomLevel-1);
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.zoomOut){
                this.setZoomLevel(this.zoomLevel+1);
            }
            
        }
        ,_keyPan:function(_e,_k){
            if(this._disableKeys)return;var x=40;var y=40;if(this._disableDrag==true)return;if(this._getKeyType(_k)==this.keyTypes.panN){
                this.smoothMoveByXY(new YCoordPoint(0,y));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panS){
                this.smoothMoveByXY(new YCoordPoint(0,-y));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panW){
                this.smoothMoveByXY(new YCoordPoint(x,0));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panE){
                this.smoothMoveByXY(new YCoordPoint(-x,0));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panNW){
                this.smoothMoveByXY(new YCoordPoint(x,y));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panNE){
                this.smoothMoveByXY(new YCoordPoint(-x,y));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panSW){
                this.smoothMoveByXY(new YCoordPoint(x,-y));
            }
            
            else if(this._getKeyType(_k)==this.keyTypes.panSE){
                this.smoothMoveByXY(new YCoordPoint(-x,-y));
            }
            
        }
        ,_runkeyDown:function(_e){
            var _key=_e.keyCode;var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.KeyDown.trigger(_ce,_key);
        }
        ,_runkeyUp:function(_e){
            var _key=_e.keyCode;var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.KeyUp.trigger(_ce,_key);
        }
        ,_MouseOverRun:function(_e){
            var _ll=this._getEvGP(_e);var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.MouseOver.trigger(_ce,_ll);
        }
        ,_MouseDownRun:function(_e){
            var _ll=this._getEvGP(_e);var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.MouseDown.trigger(_ce,_ll);
        }
        ,_MouseUpRun:function(_e){
            if(this._endPan){
                if(this.Events.MouseClick){
                    
                }
                
            }
            else{
                if(this.Events.MouseClick){
                    
                }
                
            }
            
            var _ll=this._getEvGP(_e);var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.MouseUp.trigger(_ce,_ll);
        }
        ,_MouseClickRun:function(_e){
            YEvent.stopPropag(_e);if(!this.YCoordPoint)return;var _ll=this._getEvGP(_e);var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.MouseClick.trigger(_ce,_ll);
        }
        ,_runstartPan:function(_e){
            this._endPan=false;
        }
        ,_runonPan:function(_e){
            
        }
        ,_runendPan:function(_e){
            this._endPan=true;this._adjustOverlay();this._cleanOutOfView();if(this.YSize.hasSmallerSide(new YSize(Math.abs(this._totalX),Math.abs(this._totalY)))){
                YUtility.tracker(this._mapType,this.YSize,'pan_ob');if(this._mapType==YAHOO_MAP_SAT||this._mapType==YAHOO_MAP_HYB){
                    var src=this._cpySrv+'x='+this._txy.tx+'&y='+this._txy.ty+'&z='+this.zoomLevel+'&ew=1&ns=1';if(this._coordTable['ycopy3'])
                    this._coordTable['ycopy3'].dom.src=src;
                }
                
                this._totalX=this._totalY=0;
            }
            
        }
        ,_runchangeZoom:function(e){
            this._adjustOverlay();
        }
        ,_getEvCP:function(_e){
            var tr=YAHOO.util.Event.getTarget(_e);var xy=YAHOO.util.Event.getXY(_e);var ps=YAHOO.util.Dom.getXY(this.dom);var ax=xy[0]-ps[0];var ay=xy[1]-ps[1];var np=new YCoordPoint(ax,ay);var _cx=this.YSize.width/2;var _cy=this.YSize.height/2;var dx=_cx-np.x;var dy=_cy-np.y;var cp=new YCoordPoint(dx,dy);return cp;
        }
        ,_getEvXY:function(_e){
            var _tr=YAHOO.util.Event.getTarget(_e);var _xy=YAHOO.util.Event.getXY(_e);var _dp=YAHOO.util.Dom.getXY(this.dom);var _ep=new YCoordPoint(_xy[0]-_dp[0],_xy[1]-_dp[1]);var dx=this.YCoordPoint.x-_ep.x;var dy=this.YCoordPoint.y-_ep.y;var otx=this._txy.x;var oty=this._txy.y;var tdx=this._txy.tx-_tr.tx;var tdy=this._txy.ty-_tr.ty;var ntx=otx-(dx-tdx*256);var nty=oty+(dy+tdy*256);return(new TileXY(_tr.tx,_tr.ty,ntx,nty));
        }
        ,_getEvGP:function(_e){
            var _txy=this._getEvXY(_e);var _ll=this.MP.xy_to_ll(_txy.tx,_txy.ty,_txy.x,_txy.y);return _ll;
        }
        ,_cleanOutOfView:function(){
            for(var i in this._tileCache){
                if(!this.bO.inB(this._tileCache[i].tx,this._tileCache[i].ty)){
                    if(this._tileCache[i]._h)
                    YUtility.removeNode(this._tileCache[i]._h);YUtility.removeNode(this._tileCache[i]._t);delete this._tileCache[i];
                }
                
            }
            
        }
        ,_adjustOverlay:function(){
            var _ps=parseFloat(this.subContainer.style.left);var _cr=this.MP.circum_px;var _nm=(parseInt(_ps/_cr));for(var m in this._mTb){
                if(this._mTb[m].setGeoXYPoint){
                    var _adj=-(_nm*_cr);this._mTb[m].setGeoXYPoint(this.zoomLevel,this._posTbl,_adj);
                }
                
            }
            
        }
        ,handleSizeChange:function(_e){
            this._onResizeRun(_e);
        }
        ,_onResizeRun:function(_e){
            YEvent.stopEvent(_e);if(!this.YSize)return;this._adjustOnResize(this.YSize,YUtility.getSize(this.dom));
        }
        ,_rundoubleClick:function(_e){
            YEvent.stopEvent(_e);var _ll=this._getEvGP(_e);var _ce=(new _eO(this,this.YGeoPoint,{
                previous:this.zoomLevelPrev,current:this.zoomLevel
            }
            ));this.Events.MouseDoubleClick.trigger(_ce,_ll);var cp=this._getEvCP(_e);this._pointPan(cp);
        }
        ,vZoom:[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18],_zr:[[1,"1",[0.1,0.05]],[2,"st",[0.125,0.1]],[3,"3",[0.25,0.2]],[4,"city",[0.5,0.5]],[5,"5",[1,1]],[6,"6",[2,2]],[7,"7",[5,3]],[8,"state",[10,7]],[9,"9",[20,15]],[10,"10",[30,25]],[11,"11",[75,50]],[12,"12",[150,100]],[13,"13",[300,200]],[14,"14",[600,400]],[15,"15",[1000,750]],[16,"16",[2000,1500]],[17,"17",[5000,3000]],[18,"18",[5000,3000]]],_imgU:"http://us.i1.yimg.com/us.yimg.com/i/us/map/gr/",_lct:function(x,y){
            var _a=this._txy.x-this.YSize.width/2+x;var _b=this._txy.y+this.YSize.height/2-y;return new YCoordPoint(_a,_b);
        }
        ,_xy2ll:function(_c,_t){
            var _p=this._lct(_c.x,_c.y);return this.MP.xy_to_ll(this._txy.tx,this._txy.ty,_p.x,_p.y);
        }
        ,_ll2xy:function(_gp){
            var v=this.MP.ll_to_xy(_gp);var k=YUtility._xyKey(v.tx,v.ty,this.zoomLevel);if(this._posTbl[k]){
                var lm=YUtility.getInt(this._posTbl[k].tx)+YUtility.getInt(this.subContainer.style.left);var tm=YUtility.getInt(this._posTbl[k].ty)+YUtility.getInt(this.subContainer.style.top);var rv=this.MP._returnCoordPoint(lm,tm,v.x,v.y);return rv;
            }
            
            return false;
        }
        ,_mapSrv:'http://us.i1.yimg.com/png.maps.yimg.com/png?v=3.0.1&',_satSrv:'http://us.maps3.yimg.com/aerial.maps.yimg.com/tile?v=1.3&t=a&',_hybSrv:'http://us.maps3.yimg.com/aerial.maps.yimg.com/png?v=1.0&t=h&',_cpySrv:'http://us.i1.yimg.com/api.maps.yahoo.com/ajax/copy?v=1.3&',_tileXY:TILE_WH,setTileServer:function(_u){
            var _s={
                YAHOO_MAP:this._mapSrv,YAHOO_SAT:this._satSrv,YAHOO_HYB:this._hybSrv
            }
            
            this.tileServer=_u||this._mapSrv;if(_s[_u]){
                this.tileServer=_s[_u];
            }
            
        }
        ,_setParentContainer:function(_c){
            this.id=_c.id=(_c.id)?_c.id:'ymapid'+YUtility.getRandomID();var _s={
                'position':'relative','overflow':'hidden','background':'#f1f1f1'
            }
            ;YUtility.setStyle(_c,_s);this.dom=_c;if(!this.subContainer){
                this._setSubContainer();
            }
            
            this._setTileXY();
        }
        ,_setSubContainer:function(_p){
            this.subContainer=YUtility.createNode('div');var _s1={
                'position':'absolute','zIndex':0,'left':'0px','top':'0px'
            }
            ;YUtility.setStyle(this.subContainer,_s1);YUtility.appendNode(this.dom,this.subContainer);
        }
        ,_setTileXY:function(){
            var _x=Math.ceil(((this._tileXY*Math.ceil(this.YSize.width/this._tileXY))/this._tileXY)/2);var _y=Math.ceil(((this._tileXY*Math.ceil(this.YSize.height/this._tileXY))/this._tileXY)/2);this._xyFill=new YSize(_x,_y);
        }
        ,_getContainerSize:function(_c,_s){
            if(_s){
                this.setContainerSize(_c,_s);return _s;
            }
            
            return this._sizeCheck(YUtility.getSize(_c),_c);
        }
        ,_sizeCheck:function(_s,_c){
            var _dYSize=new YSize(400,400);if(!_s.width||!_s.height){
                _s.width=_s.height=_dYSize.width;this.setContainerSize(_c,_dYSize);return _s;
            }
            
            else if(_s.width<this._tileXY||_s.height<this._tileXY){
                if(isNaN(parseInt(_c.style.width))||isNaN(parseInt(_c.style.height))){
                    _s.width=_s.height=_dYSize.width;this.setContainerSize(_c,_dYSize);return _s;
                }
                
            }
            
            return _s;
        }
        ,setContainerSize:function(_c,_s){
            var _wh={
                'width':_s.width+'px','height':_s.height+'px'
            }
            ;YUtility.setStyle(_c,_wh);
        }
        ,_addTile:function(_n,_k,_m){
            YUtility.appendNode(this.subContainer,_n);
        }
        ,_ipA:function(o,_k){
            var X=o.tx;var Y=o.ty;var L=o.x;var T=o.y;var _key=_k||(YUtility._xyKey(X,Y,this.zoomLevel));this._posTbl[_key]=new TileXY(L,T,X,Y);
        }
        ,_getSrc:function(x,y){
            var _ru=this.tileServer+"x="+x+"&y="+y+"&z="+this.zoomLevel;return _ru;
        }
        ,_browserTile:function(_t,_o){
            var _s={
                'position':'absolute','padding':'0px','cursor':'move','margin':'0px','width':'258px','height':'258px','zIndex':0,'left':_o.x+'px','top':_o.y+'px'
            }
            ;YUtility.setStyle(_t,_s);_t.tx=_o.tx;_t.ty=_o.ty;if(YUtility.browser.id){
                YUtility.setStyle(_t,'visibility','hidden');_t.onload=function(){
                    YUtility.setStyle(_t,'visibility','visible');
                }
                ;
            }
            
        }
        ,_getTile:function(_o){
            var _k=YUtility._xyKey(_o.tx,_o.ty,this.zoomLevel);this._ipA(_o,_k);if(this._mapType==YAHOO_MAP_HYB){
                var _k1=YUtility._xyKey(_o.tx,_o.ty,this.zoomLevel,YAHOO_MAP_SAT);this.__loadTiles(_o,_k1,YAHOO_MAP_SAT);var _k2=YUtility._xyKey(_o.tx,_o.ty,this.zoomLevel,YAHOO_MAP_HYB);this.__loadTiles(_o,_k2,YAHOO_MAP_HYB);
            }
            
            else{
                var _k3=YUtility._xyKey(_o.tx,_o.ty,this.zoomLevel,this._mapType);this.__loadTiles(_o,_k3,this._mapType);
            }
            
        }
        ,__loadTiles:function(_o,_k,_m){
            this.setTileServer(_m);var _f=this.MP.xy_to_ll(_o.tx,_o.ty,128,128);var _r=this.MP.ll_to_xy(_f);if(!this._tileCache[_k]){
                var _t=YUtility.cloneNode('img',_m);this._browserTile(_t,_o);if(_m==YAHOO_MAP_HYB&&!YUtility.browser.id){
                    _t.style.filter=YUtility.alphaImg(this._getSrc(_r.tx,_o.ty),'scale',_t);
                }
                else{
                    _t.src=this._getSrc(_r.tx,_o.ty);
                }
                
                this._tileCache[_k]=_o;if(_m==YAHOO_MAP_HYB){
                    this._tileCache[_k]._h=_t;
                }
                else{
                    this._tileCache[_k]._t=_t;
                }
                
                this._addTile(_t,_k,_m);
            }
            
        }
        ,_callTiles:function(){
            var _cxy=new YCoordPoint(((this.YSize.width/2)-this._txy.x),((this.YSize.height/2)-this._tileXY+this._txy.y));var _pth=[];for(var xI=0;xI<=this._xyFill.width;xI++){
                for(var yI=0;yI<=this._xyFill.height;yI++){
                    this._getTile(new TileXY(this._txy.tx+xI,this._txy.ty+yI,_cxy.x+(xI*this._tileXY),_cxy.y+(-yI*this._tileXY)));_pth[xI+'.'+yI]=true;
                }
                
            }
            
            for(var xI=-this._xyFill.width;xI<=this._xyFill.width;xI++){
                for(var yI=-this._xyFill.height;yI<=this._xyFill.height;yI++){
                    if(_pth[xI+'.'+yI]){
                        continue;
                    }
                    
                    this._getTile(new TileXY(this._txy.tx+xI,this._txy.ty+yI,_cxy.x+(xI*this._tileXY),_cxy.y+(-yI*this._tileXY)));
                }
                
            }
            
        }
        ,_clearView:function(_e){
            for(m in this._mTb){
                if(this._mTb[m].setGeoXYPoint)
                this._mTb[m].setGeoXYPoint();
            }
            
            for(var i in this._tileCache){
                if(this._tileCache[i]._h)
                YUtility.removeNode(this._tileCache[i]._h);YUtility.removeNode(this._tileCache[i]._t);delete this._tileCache[i];
            }
            
            for(var p in this._posTbl){
                delete this._posTbl[p];
            }
            
        }
        ,_adjustSubContPos:function(_c){
            var _s={
                left:'0px',top:'0px'
            }
            ;if(this.subContainer)
            YUtility.setStyle(this.subContainer,_s);
        }
        ,_setProjection:function(){
            this.MP=new MercatorProjection(this.zoomLevel,this._tileXY);this._txy=this.MP.ll_to_xy(this.YGeoPoint);this.YCoordPoint=new YCoordPoint(this.YSize.width/2,this.YSize.height/2);
        }
        ,_draw:function(){
            if(!this.YGeoPoint)
            return;this._adjustSubContPos(new YCoordPoint(0,0));this._clearView();this._setProjection();this.bO=new _setBounds(this._txy.tx,this._txy.ty,this._xyFill.width,this._xyFill.height);this._callTiles();this._adjustOverlay();this._updateGeoBox();var _t=(this.zoomLevelPrev)?'zoom':'start';YUtility.tracker(this._mapType,this.YSize,_t);
        }
        ,_updateGeoBox:function(){
            var bSW=this.MP.xy_to_ll(this._txy.tx,this._txy.ty,this._txy.x+this.YSize.width/2,this._txy.y-this.YSize.height/2);var bNE=this.MP.xy_to_ll(this._txy.tx,this._txy.ty,this._txy.x-this.YSize.width/2,this._txy.y+this.YSize.height/2);if((this.MP.ntiles_w_*this._tileXY)<=this.YSize.width){
                bSW.Lon=-180;bNE.Lon=180;
            }
            
            bSW.setgeobox(bNE);this._geoBox=bSW;
        }
        ,_gLC:function(){
            this.bO.abL();for(var tb=this.bO.bB;tb<=this.bO.bT;tb++){
                var key=YUtility._xyKey(this.bO.pbL,tb,this.zoomLevel);this._getTile(new TileXY(this.bO.bL,tb,this._posTbl[key].tx-this._tileXY,this._posTbl[key].ty));
            }
            
            this.bO.sbR();
        }
        ,_gRC:function(){
            this.bO.abR();for(var tb=this.bO.bB;tb<=this.bO.bT;tb++){
                var key=YUtility._xyKey(this.bO.pbR,tb,this.zoomLevel);this._getTile(new TileXY(this.bO.bR,tb,this._posTbl[key].tx+this._tileXY,this._posTbl[key].ty));
            }
            
            this.bO.sbL();
        }
        ,_gTR:function(){
            this.bO.abT();for(var tb=this.bO.bL;tb<=this.bO.bR;tb++){
                var key=YUtility._xyKey(tb,this.bO.pbT,this.zoomLevel);this._getTile(new TileXY(tb,this.bO.bT,this._posTbl[key].tx,this._posTbl[key].ty-this._tileXY));
            }
            
            this.bO.sbB();
        }
        ,_gBR:function(){
            this.bO.abB();for(var tb=this.bO.bL;tb<=this.bO.bR;tb++){
                var key=YUtility._xyKey(tb,this.bO.pbB,this.zoomLevel);this._getTile(new TileXY(tb,this.bO.bB,this._posTbl[key].tx,this._posTbl[key].ty+this._tileXY));
            }
            
            this.bO.sbT();
        }
        ,_pan:function(iX,iY,r){
            var _x=YUtility.getInt(iX);var _y=YUtility.getInt(iY);if(!_x&&!_y||!this.bO)return;var t=this.subContainer;var pL=YUtility.getInt(t.style.left)+_x;var pT=YUtility.getInt(t.style.top)+_y;t.style.left=(pL)+'px';t.style.top=(pT)+'px';var nR,nB,nL,nT;var kR=YUtility._xyKey(this.bO.bR,this.bO.bT,this.zoomLevel);var kB=YUtility._xyKey(this.bO.bL,this.bO.bB,this.zoomLevel);if(this._posTbl[kR]){
                nR=this._posTbl[kR].tx;
            }
            
            if(this._posTbl[kB]){
                nB=this._posTbl[kB].ty;
            }
            
            if(this._posTbl[kB]){
                nL=this._posTbl[kB].tx;
            }
            
            if(this._posTbl[kR]){
                nT=this._posTbl[kR].ty;
            }
            
            if((nL+pL)>-this._tileXY)this._gLC();if((nR+pL)<this.YSize.width)this._gRC();if((nT+pT)>-this._tileXY)this._gTR();if((nB+pT)<this.YSize.height)this._gBR();this._panUpdate(_x,_y,r);this._totalX+=_x;this._totalY+=_y;
        }
        ,_panUpdate:function(x,y,r){
            if(!x&&!y)return;var _x=x;var _y=y;if(r){
                _x=0;_y=0;
            }
            
            this._txy.tx=this._txy.tx-_x/this._tileXY;this._txy.ty=this._txy.ty+_y/this._tileXY;this.YGeoPoint=this.MP.xy_to_ll(this._txy.tx,this._txy.ty,this._txy.x,this._txy.y);this._updateGeoBox();
        }
        ,_drag:function(){
            if(!this._dragObject){
                this._dragObject=new YAHOO.util.DDProxy(this.dom.id);this._dragObject.scroll=false;
            }
            
            var that=this;that._dragObject.onDrag=function(_e){
                YEvent.stopDefault(_e);var _ex=_e.clientX;var _ey=_e.clientY;var pos={
                    x:_ex-ox,y:_ey-oy
                }
                ;ox=_ex;oy=_ey;with(that){
                    _pan(pos.x,pos.y);var _ce=(new _eO(that,YGeoPoint,{
                        previous:zoomLevelPrev,current:zoomLevel
                    }
                    ));Events.onPan.trigger(_ce);
                }
                
            }
            ;that._dragObject.endDrag=function(_e){
                with(that){
                    var _ce=(new _eO(that,YGeoPoint,{
                        previous:zoomLevelPrev,current:zoomLevel
                    }
                    ));Events.endPan.trigger(_ce);
                }
                
            }
            ;that._dragObject.b4StartDrag=function(_e){
                
            }
            ;that._dragObject.startDrag=function(_e){
                ox=_e.clientX;oy=_e.clientY;with(that){
                    var _ce=(new _eO(that,YGeoPoint,{
                        previous:zoomLevelPrev,current:zoomLevel
                    }
                    ));Events.startPan.trigger(_ce);
                }
                
            }
            ;
        }
        ,drawZoomAndCenter:function(o,z){
            this.zoomLevel=z||5;if(typeof(o)=='string'){
                this._startGeoCode(o,10);
            }
            else if(o){
                this.YGeoPoint=new YGeoPoint(o.Lat,o.Lon);
				this._draw();
				this._drag();
				var _ce=(
					new _eO(this,this.YGeoPoint,{previous:this.zoomLevelPrev,current:this.zoomLevel})
				);
				this.Events.endMapDraw.trigger(_ce);
            }
            
        }
        ,panToLatLon:function(_geoPoint){
            this.PANRAN=1;var _lldiff=_geoPoint.pointDiff(this.YGeoPoint);var _units=this.getUnitsPerPixel();var _xdiff=Math.ceil(_lldiff.Lon/_units.longitude);var _ydiff=Math.ceil(_lldiff.Lat/_units.latitude);var _panMax=0.5;if(Math.abs(_xdiff)>this.YSize.width*_panMax||Math.abs(_ydiff)>this.YSize.height*_panMax){
                this.drawZoomAndCenter(_geoPoint,this.zoomLevel);
            }
            
            else{
                this._pointPan(new YCoordPoint(_xdiff,_ydiff));
            }
            
        }
        ,_pointPan:function(_cp){
            var attributes={
                
            }
            ;var _f=(YUtility.browser.id)?10:1;var _anm=new YAHOO.util.Motion(this.subContainer,attributes,_f,YAHOO.util.Easing.easeOut);_anm.useSeconds=false;var that=this;_anm.onStart.subscribe(function(){
                with(that){
                    Events.startAutoPan.trigger(new _eO(that));
                }
                
            }
            );_anm.onTween.subscribe(function(){
                with(that){
                    _pan(_cp.x/_f,_cp.y/_f);Events.onPan.trigger(new _eO(that));
                }
                
            }
            );_anm.onComplete.subscribe(function(){
                with(that){
                    Events.endAutoPan.trigger(new _eO(that));
                }
                
            }
            );_anm.animate();
        }
        ,addOverlay:function(o){
            if(!o)throw("Error: attempting to add invalid overlay object!");if(o.YGeoPoint){
                o.setMapObject(this);o.setGeoXYPoint(this.zoomLevel,this._posTbl);if(!this._mTb[o.id])
                YUtility.appendNode(this.subContainer,o);this._mTb[o.id]=o;
            }
            
            else if(o.YCoordPoint){
                o.setMapObject(this);o.assignCoordPoint();if(!this._coordTable)
                this._coordTable=[];if(!this._coordTable[o.id])
                YUtility.appendNode(this,o);this._coordTable[o.id]=o;
            }
            
            else if(o.GeoRSS){
                this._startGeoRSS(o,1);return;
            }
            
            YUtility.alphaLoad(o);
        }
        ,processRSS:function(o){
            this._startGeoRSS(o,2);
        }
        ,removeOverlay:function(o){
            if(o&&o.dom){
                YUtility.removeNode(o.dom);delete this._mTb[o.id];
            }
            
            else if(typeof(o)=='string'){
                if(this._coordTable[o]){
                    var _obj=this._coordTable[o]
                    YUtility.removeNode(_obj.dom);delete this._coordTable[o];
                }
                
            }
            
        }
        ,addXY:function(_cp){
            var m=document.createElement("img");m.id="xypt"+Math.random();m.src="http://us.i1.yimg.com/us.yimg.com/i/us/map/gr/str_ico_s.gif";var _s={
                'position':'absolute','left':_cp.x,'top':_cp.y,'zIndex':2
            }
            ;YUtility.setStyle(m,_s);YUtility.appendNode(this.dom,m);
        }
        ,getMarkerObject:function(k){
            return this._mTb[k];
        }
        ,getEventsList:function(){
            return EventsList;
        }
        ,addZoomLong:function(){
            this._showZoomLong=true;if(!this._showZoomShort)
            this._enableZoomControl();
        }
        ,addZoomShort:function(){
            this._showZoomShort=true;if(!this._showZoomLong)
            this._enableZoomControl('s');
        }
        ,addZoomScale:function(){
            this._showZoomScale=true;
        }
        ,removeZoomScale:function(){
            this._disableScale=true;
        }
        ,addPanControl:function(){
            this._showPointPan=true;this._enablePointPan();
        }
        ,convertLatLonXY:function(gp){
            return this._ll2xy(gp);
        }
        ,convertXYLatLon:function(cpt){
            return this._xy2ll(cpt);
        }
        ,removeFromMap:function(id){
            YUtility.removeNode(YUtility.getByID(id));
        }
        ,addMarker:function(a,b){
            if(typeof(a)=='string'){
                this._startGeoCode(a,11);
            }
            
            else{
                this.addOverlay(new Marker(a,b));
            }
            
        }
        ,getZoomFromDegreePerPixel:function(degppx,uppx){
            return Math.ceil(1+Math.log(degppx/(uppx))/Math.log(2));
        }
        ,getZoomLevel:function(gpa,gpb,cs){
            var _a,_b;if(gpa&&!gpb){
                var _o=this.getGeoBox(gpa);_a=_o.min;_b=_o.max;
            }
            else{
                _a=gpa;_b=gpb;
            }
            
            if(_a&&_b){
                var tcs=this.YSize;if(cs)tcs=cs;if(_a&&!_a.setgeobox){
                    _a=new YGeoPoint(_a.Lat,_a.Lon);_b=new YGeoPoint(_b.Lat,_b.Lon);
                }
                
                _a.setgeobox(_b);var nbd=_a;var c1=this.getBoxGeoCenter(_a,_b);if(!this.YGeoPoint){
                    this.YGeoPoint=new YGeoPoint(c1.Lat,c1.Lon);
                }
                
                var lnpx=(nbd.LonMax-nbd.LonMin)/tcs.width;var ltpx=(nbd.LatMax-nbd.LatMin)/tcs.height;if(!lnpx)return 1;var zmlon=this.getZoomFromDegreePerPixel(lnpx,this.getUnitsPerPixel(1).longitude);var zmlat=this.getZoomFromDegreePerPixel(ltpx,this.getUnitsPerPixel(1).latitude);var rz=(zmlon>zmlat)?zmlon:zmlat;return Math.abs(rz);
            }
            
            return this.zoomLevel;
        }
        ,getZoomBestFit:function(a,b,c){
            
        }
        ,getGeoBox:function(inp){
            var o={
                
            }
            ;var p=inp.shift();o.min=new YGeoPoint(p.Lat,p.Lon);o.max=new YGeoPoint(p.Lat,p.Lon);while(inp.length){
                var n=inp.shift();if(n.Lat<o.min.Lat)o.min.Lat=n.Lat;if(n.Lon<o.min.Lon)o.min.Lon=n.Lon;if(n.Lat>o.max.Lat)o.max.Lat=n.Lat;if(n.Lon>o.max.Lon)o.max.Lon=n.Lon;
            }
            
            return o;
        }
        ,getCenterGeoPoint:function(a){
            return this.getCenterPoint(a);
        }
        ,getCenterPoint:function(a){
            var _o=this.getGeoBox(a);var _c=this.getBoxGeoCenter(_o.min,_o.max);return _c;
        }
        ,getGeoBoxCenter:function(a,b){
            return this.getBoxGeoCenter(a,b);
        }
        ,getBoxGeoCenter:function(a,b){
            var _a=(a.Lat+b.Lat)/2;var _b=(a.Lon+b.Lon)/2;return(new YGeoPoint(_a,_b));
        }
        ,setZoomLevel:function(z){
            if(this.isValidZoomLevel(z)){
                this._setZoomLevel(YUtility.getInt(z));
            }
            
        }
        ,isValidZoomLevel:function(z){
            if(this._zr[YUtility.getInt(z)-1]&&z>=this._zoomMin&&z<=this._zoomMax)
            return true;return false;
        }
        ,getZoomValidLevels:function(){
            return this.vZoom;
        }
        ,removeZoomControl:function(){
            this._showZoomLong=false;var n=YUtility.getByID('ymapzl');YUtility.removeNode(YUtility.getByID('ymapzl'));this._zoomControl=null;this._zoomON=false;
        }
        ,removePanControl:function(){
            this._showPointPan=false;YUtility.removeNode(YUtility.getByID('ymappan'));this._panLayer=null;
        }
        ,getMarkerIDs:function(){
            var a=[];for(m in this._mTb){
                a.push(m);
            }
            
            return a;
        }
        ,getMarkerTable:function(){
            return this._mTb;
        }
        ,removeMarkersAll:function(){
            if(_expCache){
                _expCache._destroy();_expCache=null;
            }
            
            for(m in this._mTb){
                if(this._mTb[m].aedom)
                YUtility.removeNode(this._mTb[m].aedom);if(this._mTb[m].swdom)
                YUtility.removeNode(this._mTb[m].swdom);YUtility.removeNode(this._mTb[m].dom);delete this._mTb[m];
            }
            
            if(this._mTb.length)return false;return true;
        }
        ,removeMarker:function(id){
            if(typeof this._mTb[id]=='object'){
                YUtility.removeNode(this._mTb[id].dom);delete this._mTb[id];return true;
            }
            
            return false;
        }
        ,getOuterRadius:function(){
            return(YUtility.getInt(this.YSize.width>this.YSize.height?this.YSize.width:this.YSize.height))/2;
        }
        ,getInnerRadius:function(){
            return(YUtility.getInt(this.YSize.width>this.YSize.height?this.YSize.height:this.YSize.width))/2;
        }
        ,_adjustOnResize:function(_os,_ns){
            var _oldYSize=_os;this.YSize=_ns;this.YCoordPoint=new YCoordPoint(this.YSize.width/2,this.YSize.height/2);this._setTileXY();var _dx=(this.YSize.width-_oldYSize.width)/2;var _dy=(this.YSize.height-_oldYSize.height)/2;this._pan(_dx,_dy,true);
        }
        ,resizeTo:function(ys){
            if(ys)
            this._adjustOnResize(this.YSize,this._getContainerSize(this.dom,ys));
        }
        ,moveByXY:function(cpt){
            this._pan(cpt.x,cpt.y);
        }
        ,smoothMoveByXY:function(cpt){
            this._pointPan(cpt);
        }
        ,panToXY:function(np){
            var op=new YCoordPoint(this.YSize.width/2,this.YSize.height/2);for(var i=1;i<arguments.length;i++){
                if(typeof arguments[i]=='object')op=arguments[i];
            }
            
            var xd=Math.floor(op.x-np.x);var yd=Math.floor(op.y-np.y);this._pointPan(new YCoordPoint(-xd,-yd));
        }
        ,getBoundsLatLon:function(){
            return this._geoBox;
        }
        ,getPortSize:function(){
            return this.YSize;
        }
        ,getContainerSize:function(){
            return this.YSize;
        }
        ,getCenterLatLon:function(){
            return this.YGeoPoint;
        }
        ,getUnitsPerPixel:function(z){
            var zm=z||this.zoomLevel;var mp=new MercatorProjection(zm);var km=(this.YGeoPoint)?mp.mpp_m(this.YGeoPoint.Lat)/1000:0;var mi=(this.YGeoPoint)?mp.mpp_m(this.YGeoPoint.Lat)/1609.344:0;var lonppx=1/mp.x_per_lon_;var latppx=lonppx*0.794370211280205;return{
                miles:mi,kilometers:km,latitude:latppx,longitude:lonppx
            }
            ;
        }
        ,showSmartWindow:function(gp,cin,id){
            if(!gp||!cin)return;var im=new YImage();im.src='http://us.i1.yimg.com/us.yimg.com/i/us/map/gr/sp.gif';im.size=new YSize(0,0);im.offsetSmartWindow=new YCoordPoint(0,0);var marker=new Marker(gp,id,im);this.addOverlay(marker);marker.openSmartWindow(cin);
        }
        ,disableDragMap:function(){
            if(this._dragObject)
            this._dragObject.lock();this._disableDrag=true;for(var _t in this._tileCache){
                YUtility.setStyle(this._tileCache[_t]._t,'cursor','default');
            }
            
        }
        ,enableDragMap:function(){
            if(this._dragObject)
            this._dragObject.unlock();this._disableDrag=false;for(var _t in this._tileCache){
                YUtility.setStyle(this._tileCache[_t]._t,'cursor','move');
            }
            
        }
        ,disableKeyControls:function(){
            this._disableKeys=true;
        }
        ,geoCodeAddress:function(s){
            this._startGeoCode(s);
        }
        ,__end:function(){
            
        }
        
    }
    ;YUtility.containerResize=function(panelElId,handleElId,sGroup){
        if(handleElId){
            this.init(panelElId,sGroup);this.handleElId=handleElId;this.setHandleElId(handleElId);
        }
        
    }
    ;YUtility.containerResize.prototype=new YAHOO.util.DragDrop();YUtility.containerResize.prototype.onMouseDown=function(e){
        var panel=this.getEl();this.startWidth=panel.offsetWidth;this.startHeight=panel.offsetHeight;this.startPos=[YAHOO.util.Event.getPageX(e),YAHOO.util.Event.getPageY(e)];
    }
    ;YUtility.containerResize.prototype.onDrag=function(e){
        var newPos=[YAHOO.util.Event.getPageX(e),YAHOO.util.Event.getPageY(e)];var offsetX=newPos[0]-this.startPos[0];var offsetY=newPos[1]-this.startPos[1];var newWidth=Math.max(this.startWidth+offsetX,10);var newHeight=Math.max(this.startHeight+offsetY,10);var panel=this.getEl();panel.style.width=newWidth+"px";panel.style.height=newHeight+"px";
    }
    ;var Debug=function(i){
        this.id=i||'ymapdebug';this._count=0;this.initSize(new YSize(200,200));this.initPos(new YCoordPoint(10,10));
    }
    ;Debug.prototype.initPos=function(yc){
        this._x=yc.x;this._y=yc.y;
    }
    ;Debug.prototype.initSize=function(ys){
        this._w=ys.width;this._h=ys.height;
    }
    ;Debug.prototype.print=function(inp){
        this._count=0;if(!this._p){
            this._p=document.getElementById(this.id);this._p=YUtility.createNode('div');this._p.id=this.id;this._p.style.position='absolute';this._p.style.background='#EEEEEE';this._p.style.filter="alpha(opacity=75)";this._p.style.opacity=0.75;this._p.style.width=this._w;this._p.style.height=this._h;this._p.style.left=this._x;this._p.style.top=this._y;this._p.style.zIndex=999;this._p.style.borderStyle='solid';if(!YUtility.browser.id)
            this._p.style.overflow='auto';var _h=YUtility.createNode('div','yloghd');var hs={
                backgroundColor:'#EEE000',position:'absolute',overflow:'visible',zIndex:999,bottom:-5,right:-5,width:15,height:15
            }
            ;YUtility.setStyle(_h,hs);var _l=YUtility.createNode('div');_l.style.borderWidth='1px';_l.style.padding='1px';_l.style.borderStyle='solid';var _c=YUtility.createNode('img','ylogx');_c.src=_baseURL+'x.gif';_c.style.position='absolute';_c.style.right='3px';_c.style.top='3px';YEvent.Capture(_c,EventsList.MouseClick,this._MouseClickRun,this,'click');var _t=YUtility.createNode('div');_t.innerHTML='<b>Yahoo! Maps API Logger</b>';_t.style.background='#EEE000';_t.style.width='98%';_t.style.paddingLeft='3px';YUtility.appendNode(_t,_c);YUtility.appendNode(this._p,_t);YUtility.appendNode(this._p,_l);YUtility.appendNode(this._p,_h);YUtility.appendNode(document.body,this._p);if(!this._o){
                this._o=YUtility.createNode('div','ylogmn');if(YUtility.browser.id)
                this._o.style.height='90%';this._o.style.background='#EEEEEE';this._o.style.filter="alpha(opacity=75)";this._o.style.opacity=0.75;if(YUtility.browser.id)
                this._o.style.overflow='auto';YUtility.appendNode(this._p,this._o);
            }
            
        }
        
        if(YUtility.browser.id){
            var _d=new YAHOO.util.DD(this._p.id);var _r=new YUtility.containerResize(this.id,'yloghd');
        }
        else{
            var _r=new YUtility.containerResize(this.id,'yloghd');var _d=new YAHOO.util.DD(this._p.id);
        }
        
        YEvent.Capture(this._o,EventsList.MouseDown,function(_e){
            YEvent.stopPropag(_e);
        }
        ,null,'mousedown');var t=typeof inp;this._o.innerHTML+='<div>';if(t=='object'||t=='array'){
            for(var o in inp){
                this._o.innerHTML+=this._count+'. <b>'+o+'</b>'+' :: '+inp[o]+'<br>';this._count++;
            }
            
        }
        else{
            this._o.innerHTML+=this._count+'. '+inp;this._count++;
        }
        
        this._o.innerHTML+='</div>';
    }
    ;Debug.prototype._MouseClickRun=function(){
        this.hide();
    }
    ;Debug.prototype.hide=function(){
        this._p.style.visibility='hidden';
    }
    ;Debug.prototype.write=function(inp){
        this.print(inp);
    }
    ;function Exporter(o){
        var _E=o||window;_E.YCoordPoint=YCoordPoint;_E.YGeoPoint=YGeoPoint;_E.YImage=YImage;_E.YSize=YSize;_E.YEvent=YEvent;_E.YMarker=Marker;_E.YSmartWindow=SmartWindow;_E.YCustomOverlay=CustomOverlay;_E.YUtility=YUtility;_E.YGeoCode=GeoCode;_E.YGeoRSS=GeoRSS;_E.YMap=Map;_E.EventsList=EventsList;_E.YLog=new Debug('ymaplog');
    }
    
    Exporter();
}
;YahooMapsAPIAjax();