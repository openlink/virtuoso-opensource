/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */

OAT.MapOverlay = function (map) {
    var self = this;
    this.div_ = OAT.Dom.create("div");
    this.div_.className = "overlay";

    this.onAdd = function() {
        var pane = this.getPanes().overlayLayer;
        pane.appendChild(self.div_);
    }

    this.onRemove = function() {
        self.div_.parentNode.removeChild(self.div_);
    }

    this.draw = function() {
        var projection = self.getProjection();
        var position = projection.fromLatLngToDivPixel(self.getMap().getCenter());

        var div = self.div_;
        div.style.left = position.x + 'px';
        div.style.top = position.y + 'px';
        div.style.display = 'block';

    }
    this.setMap(map);
}
;

/**
 * @class Abstract API atop various mapping providers.
 */

OAT.Map = function(something, provider, optionsObject, specificOptions) {
    var self = this;

    this.options = {
	fix:OAT.Map.FIX_NONE,	/* method of reposition of overlapping markers */
	fixDistance:20,		/* new distance after repositioning in px */
	fixEpsilon:15,		/* reposition markers closer than fixEpsilon px */
	markerIcon:"icon.png",	/* icon used as map marker */
	markerIconSize:[16,16],	/* icon size */
	init:false		/* init on constructor call */
    }

    for (var p in optionsObject) { self.options[p] = optionsObject[p]; }

    this.obj = false;		/* map object */
    this.elm = $(something);	/* map element */
    this.markers = [];		/* map markers */
    this.provider = provider;

    /**
     * instantiates the map of the given provider
     * @param {integer} provider
     */

    this._init = function(provider) {
	OAT.Dom.clear(self.elm);

	/* create main object */
	switch (provider) {

	    /* google */
	case OAT.Map.TYPE_G:
	    self.obj = new GMap2(self.elm,specificOptions);
	    self.geoCoder = new GClientGeocoder();
	    break;

	case OAT.Map.TYPE_G3:
	    if (!specificOptions) specificOptions = {MapTypeId:google.maps.MapTypeId.ROADMAP}
	    self.obj = new google.maps.Map(self.elm, specificOptions);
	    self.geoCoder = new google.maps.Geocoder();
	    OAT.MapOverlay.prototype = new google.maps.OverlayView;
	    self.overlay = new OAT.MapOverlay (self.obj);
	    break;

	    /* yahoo */
	case OAT.Map.TYPE_Y:
	    self.obj = new YMap(self.elm,specificOptions);
	    self.geoCodeBuffer = [];

	    /* register user callback on geocode responses */
	    YEvent.Capture(self.obj,EventsList.onEndGeoCode,function(result) {
		var index = -1;

		for (var i=0;i<self.geoCodeBuffer.length;i++) {
		    var item = self.geoCodeBuffer[i];
		    if (item[0] == result.Address) { index = i; }
		}
		if (index == -1) { return; }

		var cb = self.geoCodeBuffer[index][1];
		self.geoCodeBuffer.splice(index,1);
		if (!result.success) { cb(false); }
		cb([result.GeoPoint.Lat,result.GeoPoint.Lon]);
	    });
	    break;

	    /* microsoft */
	case OAT.Map.TYPE_MS:
	    self.elm.id = 'our_mapping_element';
	    self.obj = new VEMap('our_mapping_element',specificOptions);

	    /* listeners for shape events */
	    self.obj.AttachEvent("onmouseover",function(event) {
		OAT.Event.cancel(event);
		if (event.elementID == null) { return; }
		var marker = self.obj.GetShapeByID(event.elementID);
		OAT.MSG.send(self,"MAP_MARKER_OVER",marker);
	    });

	    self.obj.AttachEvent("onclick",function(event) {
		OAT.Event.cancel(event);
		if (event.elementID == null) { return; }
		var marker = self.obj.GetShapeByID(event.elementID);
		OAT.MSG.send(self,"MAP_MARKER_CLICK",marker);
	    });

	    /* close infoboxen on panning/map zoom */
	    self.obj.AttachEvent("onstartpan",self.closeWindow);
	    self.obj.AttachEvent("onstartzoom",self.closeWindow);

	    /* unfortunately, there is a css/api race breaking compass */
	    var id = Math.random().toString().replace(".","");
	    var msvefix = OAT.Dom.create("style",{type:"text/css",id:id});
	    var txt = ".MSVE_Dashboard_V6 #Compass { width:49px; height: 49px; }";

	    if (msvefix.styleSheet) {
		msvefix.styleSheet.cssText = txt;
	    } else {
		msvefix.appendChild(OAT.Dom.text(txt));
	    }

	    var h = document.getElementsByTagName("head")[0];
	    h.appendChild(msvefix);

	    /* hide dashboard and remove the css fixing the compass bug */
	    self.obj.onLoadMap = function() {
		OAT.Dom.unlink(msvefix);
		self.obj.HideDashboard();
	    }

	    self.obj.LoadMap();
	    break;

	    /* openlayers */
	case OAT.Map.TYPE_OL:
	    /* only controls passed in opts will be added (or default set if no options)
	     * this workaround is needed to be able to hide/show controls and start with
	     * blank map
	     */
	    var opts = {};
	    for (var p in specificOptions) {
		opts[p] = specificOptions[p];
	    }
	    var controls = [
		new OpenLayers.Control.Navigation(),
		new OpenLayers.Control.Attribution(),
	    ];
	    opts.controls = opts.controls || controls;

	    self.obj = new OpenLayers.Map(self.elm,opts);

	    /*
             * Using OpenStreetMap by default (CC-by-SA attribution shown automatically on map)
             * to enable layer switching
 	     */

	    self.fromProjection = 
		
            self.fromProj = new OpenLayers.Projection("EPSG:4326");
            self.toProj  = new OpenLayers.Projection("EPSG:900913");

	    var map = new OpenLayers.Layer.OSM();
	    map.OAT_MAP_TYPE = OAT.Map.MAP_MAP;
	    self.obj.addLayer(map);

	    /* satellite (NASA) */
//	    var sat = new OpenLayers.Layer.WMS( "NASA Global Mosaic",
//						"http://wms.jpl.nasa.gov/wms.cgi", 
//						{layers: "global_mosaic"});

//	    sat.OAT_MAP_TYPE = OAT.Map.MAP_ORTO;
//	    self.obj.addLayer(sat);

	    /* markers */
	    self.markersLayer = new OpenLayers.Layer.Markers("Marker Pins");
	    self.obj.addLayer(self.markersLayer);

	    /* set map as baselayer */
	    self.obj.setBaseLayer(map);
	    break;
	}

	/* fix position of markers on zoom */
	if (self.options.fix != OAT.Map.FIX_NONE) {
	    switch (provider) {
	    case OAT.Map.TYPE_G:
		GEvent.addListener(self.obj,'zoomend',self._fixMarkers);
		break;
	    case OAT.Map.TYPE_G3:
		google.maps.event.addListener(self.obj,'idle',self._fixMarkers);
		break;
	    case OAT.Map.TYPE_Y:
		YEvent.Capture(self.obj,EventsList.changeZoom,self._fixMarkers);
		break;
	    case OAT.Map.TYPE_MS:
		self.obj.AttachEvent("onendzoom",self._fixMarkers);
		break;
	    case OAT.Map.TYPE_OL:
		self.obj.events.register("move",self.obj,self._fixMarkers);
		break;
	    }
	}

	self.provider = provider;
	self.centerAndZoom(0.0,0.0,2);
    }

    /**
     * initializes map provider
     * @param {integer} provider
     */
    this.init = function(provider) {
	try {
	    self._init(provider);
	} catch (e) {
	    /* due to a faulty msve browser check
	     * SVG support error is catched here. see e.g.
	     * http://my.opera.com/hallvors/blog/index.dml/tag/microsoft
             */
	    if (provider == OAT.Map.TYPE_MS && !!e.message.match(/SVG/)) { return; }

	    OAT.Dom.clear(self.elm);
	    var msg = "Map service currently disabled or not available.<br>"
	    self.elm.innerHTML = msg + e.message;
	    self.provider = OAT.Map.TYPE_NONE;
	}
    }

    /* --- map methods --- */

    /**
     * Map geocoding. OpenLayers currently not supported.
     * @param {string} addr address to lookup
     * @param {function} callback callback, will receive [lat,lon] pair or false if address not found
     */
    this.geoCode = function(addr,callback) {
	var cb = function() {
	    switch (self.provider) {
	    case OAT.Map.TYPE_G:
		var results = arguments[0];
		if (!results) { callback(false); return; }
		callback([results.lat(),results.lng()]);
		break;
	    case OAT.Map.TYPE_G3:
		var results = arguments[0];
		if (!results) { callback(false); return; }
		callback([results.Location.lat(), results.Location.lng()]);
		break;
	    case OAT.Map.TYPE_MS:
		var results = arguments[2];
		if (!results || !results.length) { callback(false); return }
		callback([results[0].LatLong.Latitude,results[0].LatLong.Longitude]);
		break;
	    } /* switch */
	} /* geocoding results */

	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    callback(false);
	    break;
	case OAT.Map.TYPE_G:
	    self.geoCoder.getLatLng(addr,cb);
	    break;
	case OAT.Map.TYPE_G3:
	    self.geoCoder.geocode({address:addr},cb);
	    break;
	case OAT.Map.TYPE_Y:
	    self.geoCodeBuffer.push([addr,callback]);
	    self.obj.geoCodeAddress(addr);
	    break;
	case OAT.Map.TYPE_MS:
	    self.obj.Find(null,addr, null, null, null, null, true, true, null, false, cb);
	    break;
	case OAT.Map.TYPE_OL:
	    callback(false); /* no GC support */
	    break;
	}
    }

    /**
	 * given a geoposition, return a map pixel coordinates
	 * @param {array} geoPosition [lat,lon]
	 * @returns {array} [x,y]
	 */
    this.getPixelFromCoords = function(geoPosition) {
	switch(self.provider) {
	case OAT.Map.TYPE_NONE:
	    return [];
	    break;
	case OAT.Map.TYPE_G:
	    var ll = new GLatLng(geoPosition[0],geoPosition[1]);
	    var p = self.obj.fromLatLngToDivPixel(ll);
	    return [p.x,p.y];
	    break;
	case OAT.Map.TYPE_G3:
	    var ll = new google.maps.LatLng(geoPosition[0],geoPosition[1]);
	    var proj = self.overlay.getProjection();
	    var p = proj.fromLatLngToDivPixel(ll);
	    return [p.x,p.y];
	    break;
	case OAT.Map.TYPE_Y:
	    var ll = new YGeoPoint(geoPosition[0],geoPosition[1]);
	    var p = self.obj.convertLatLonXY(ll);
	    return [p.x,p.y];
	    break;
	case OAT.Map.TYPE_MS:
	    var ll = new VELatLong(geoPosition[0],geoPosition[1]);
	    var p = self.obj.LatLongToPixel(ll);
	    return [p.x,p.y];
	    break;
	case OAT.Map.TYPE_OL:
	    var ll = new OpenLayers.LonLat(geoPosition[1],geoPosition[0]).transform(self.fromProj,self.toProj);
	    var p = self.obj.getPixelFromLonLat(ll);
	    return [p.x,p.y];
	    break;
	}
    }

    /**
	 * given a pixel coordinates from the map div, return a map geoposition
	 * @param {array} divPosition [x,y] in the map
	 * @returns {array} [lat,lon]
	 */
    this.getCoordsFromPixel = function(divPosition) {
	switch(self.provider) {
	case OAT.Map.TYPE_NONE:
	    return [];
	    break;
	case OAT.Map.TYPE_G:
	    var p = new GPoint(divPosition[0],divPosition[1]);
	    var ll = self.obj.fromDivPixelToLatLng(p);
	    return [ll.lat(),ll.lng()];
	    break;
	case OAT.Map.TYPE_G3:
	    var p = new google.maps.Point(divPosition[0],divPosition[1]);
	    var ll = self.overlay.getProjection().fromDivPixelToLatLng(p);
	    return [ll.lat(),ll.lng()];
	    break;
	case OAT.Map.TYPE_Y:
	    var p = new YCoordPoint(divPosition[0],divPosition[1]);
	    var ll = self.obj.convertXYLatLon(p);
	    return [ll.Lat,ll.Lon];
	    break;
	case OAT.Map.TYPE_MS:
	    var z = 1 + self.getZoom();
	    var p = new VEPixel(divPosition[0],divPosition[1]);
	    var ll = self.obj.PixelToLatLong(p,z);
	    return [ll.Latitude,ll.Longitude];
	    break;
	case OAT.Map.TYPE_OL:
	    var p = new OpenLayers.Pixel(divPosition[0],divPosition[1]);
	    var ll = self.obj.getLonLatFromPixel(p);
	    return [ll.lat,ll.lon];
	    break;
	}
    }

	/**
	 * display map controls
	 */
    this.showControls = function() {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    /* noop */
	    break;
	case OAT.Map.TYPE_G:
	    self.typeControl = new GMapTypeControl();
	    self.mapControl = new GLargeMapControl()

	    self.obj.addControl(self.typeControl);
	    self.obj.addControl(self.mapControl);
	    break;

	case OAT.Map.TYPE_Y:
	    var dim = OAT.Dom.getWH(self.elm);
	    var pos = new YCoordPoint(dim[0]-50, 10);
	    self.typeControl = new YMapTypeControl(pos);

	    var icons = {
		"map":YMapConfig.imgPrefixURL+'med_map.png',
		"sat":YMapConfig.imgPrefixURL+'med_sat.png',
		"hyb":YMapConfig.imgPrefixURL+'med_hyb.png'
	    };

	    self.typeControl.setControl(YAHOO_MAP_REG, new YImage(icons["map"],new YSize(33,17)), new YSize(33,17));
	    self.typeControl.setControl(YAHOO_MAP_SAT, new YImage(icons["sat"],new YSize(33,17)), new YSize(33,17));
	    self.typeControl.setControl(YAHOO_MAP_HYB, new YImage(icons["hyb"],new YSize(33,17)), new YSize(33,17));

	    self.obj.addZoomLong();
	    self.obj.addPanControl();
	    self.obj.addOverlay(self.typeControl);
	    break;

	case OAT.Map.TYPE_OL:
	    self.typeControl = new OpenLayers.Control.LayerSwitcher();
	    self.mapControl = new OpenLayers.Control.PanZoomBar();

	    self.obj.addControl(self.typeControl);
	    self.obj.addControl(self.mapControl);
	    break;

	case OAT.Map.TYPE_MS:
	    self.obj.ShowDashboard();
	    break;
	}
    }

    /**
	 * hide map controls
	 */
    this.hideControls = function() {
  	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    /* noop */
	    break;
	case OAT.Map.TYPE_G:
	    if (self.typeControl) { self.obj.removeControl(self.typeControl); self.typeControl = null; }
	    if (self.mapControl) { self.obj.removeControl(self.mapControl); self.mapControl = null; }
	    break;

	case OAT.Map.TYPE_Y:
	    if (self.typeControl) { self.obj.removeOverlay(self.typeControl); self.typeControl = null; }
	    self.obj.removeZoomControl();
	    self.obj.removePanControl();
	    break;

	case OAT.Map.TYPE_OL:
	    if (self.typeControl) { self.obj.removeControl(self.typeControl); self.typeControl = null; }
	    if (self.mapControl) { self.obj.removeControl(self.mapControl);	self.mapControl = null; }
	    break;

	case OAT.Map.TYPE_MS:
	    self.obj.HideDashboard();
	    break;
	}
    }

    /**
	 * switches map type between satellite / normal / hybrid
	 * @param {integer} type
	 */
    this.setMapType = function(type) {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    /* noop */
	    break;
	case OAT.Map.TYPE_G:
	    switch (type) {
	    case OAT.Map.MAP_MAP: self.obj.setMapType(G_NORMAL_MAP); break;
	    case OAT.Map.MAP_ORTO: self.obj.setMapType(G_SATELLITE_MAP); break;
	    case OAT.Map.MAP_HYB: self.obj.setMapType(G_HYBRID_MAP); break;
	    }
	    break;
	case OAT.Map.TYPE_G3:
	    switch (type) {
	    case OAT.Map.MAP_MAP:  self.obj.setMapTypeId(google.maps.MapTypeId.ROADMAP); break;
	    case OAT.Map.MAP_ORTO: self.obj.setMapTypeId(google.maps.MapTypeId.SATELLITE); break;
	    case OAT.Map.MAP_HYB:  self.obj.setMapTypeId(google.maps.MapTypeId.HYBRID); break;
            case OAT.Map.MAP_TER:  self.obj.setMapTypeId(google.maps.MapTypeId.TERRAIN); break;
	    }
	    break;

	case OAT.Map.TYPE_Y:
	    switch (type) {
	    case OAT.Map.MAP_MAP: self.obj.setMapType(YAHOO_MAP_REG); break;
	    case OAT.Map.MAP_ORTO: self.obj.setMapType(YAHOO_MAP_SAT); break;
	    case OAT.Map.MAP_HYB: self.obj.setMapType(YAHOO_MAP_HYB); break;
	    }
	    break;

	case OAT.Map.TYPE_MS:
	    switch (type) {
	    case OAT.Map.MAP_MAP: self.obj.SetMapStyle(VEMapStyle.Road); break;
	    case OAT.Map.MAP_ORTO: self.obj.SetMapStyle(VEMapStyle.Aerial); break;
	    case OAT.Map.MAP_HYB: self.obj.SetMapStyle(VEMapStyle.Hybrid); break;
	    }
	    break;

	case OAT.Map.TYPE_OL:
	    var layer = self.obj.getLayersBy('OAT_MAP_TYPE',type)[0];
	    self.obj.setBaseLayer(layer);
	    break;
	}
    }

    /**
	 * center on given geoposition and zoom to certain level
	 * @param lat latitude
	 * @param lon longitude
	 * @param {integer} zoom zoom level 0 - far, 16 - close
	 */
    this.centerAndZoom = function(lat,lon,zoom) {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE: /* noop */ break;
	case OAT.Map.TYPE_G: self.obj.setCenter(new GLatLng(lat,lon),zoom); break;
	case OAT.Map.TYPE_G3:
	    self.obj.setCenter(new google.maps.LatLng(lat,lon));
	    self.obj.setZoom(zoom);
	    break;
	case OAT.Map.TYPE_Y: self.obj.drawZoomAndCenter(new YGeoPoint(lat,lon),17-zoom); break;
	case OAT.Map.TYPE_MS: self.obj.SetCenterAndZoom(new VELatLong(lat,lon),zoom+1); break;
	case OAT.Map.TYPE_OL: self.obj.setCenter(new OpenLayers.LonLat(lon,lat),zoom); break;
	}
    }

    /**
	 * set zoom on given level
	 * @param {integer} zoom zoom level 0 - far, 16 - close
	 */
    this.setZoom = function(zoom) {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE: /* noop */ break;
	case OAT.Map.TYPE_G: self.obj.setZoom(zoom); break;
	case OAT.Map.TYPE_G3: self.obj.setZoom(zoom); break;
	case OAT.Map.TYPE_Y: self.obj.setZoomLevel(17-zoom); break;
	case OAT.Map.TYPE_MS: self.obj.SetZoomLevel(zoom+1); break;
	case OAT.Map.TYPE_OL: self.obj.zoomTo(zoom); break;
	}
    }

    /**
	 * get current zoom level
	 * @returns zoom 0 - far, 16 - close
	 */
    this.getZoom = function() {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE: /* noop */ break;
	case OAT.Map.TYPE_G: return self.obj.getZoom(); break;
	case OAT.Map.TYPE_G3: return self.obj.getZoom(); break;
	case OAT.Map.TYPE_Y: return 17-self.obj.getZoomLevel(); break;
	case OAT.Map.TYPE_MS: return self.obj.GetZoomLevel()-1; break;
	case OAT.Map.TYPE_OL: return self.obj.getZoom(); break;
	}
	return false;
    }

    /**
     * computes optimal position so all given geopoints are visible and zoomed
     * to max possible level
     * @param {array} geopoints array of geoposition pairs [lat,lon]
     */
    this.optimalPosition = function(geopoints) {

	/* if no points passed, focus on markers present on the map */
	var points = (geopoints && geopoints.length)? geopoints : [];
	if (!points.length) {
	    for (var i=0;i<self.markers.length;i++) {
		var marker = self.markers[i];
		points.push(marker.__coords);
	    }
	}

	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    return;
	    break;
	case OAT.Map.TYPE_G:
	    var bounds = new GLatLngBounds();
	    for (var i=0;i<points.length;i++) {
		var point = new GLatLng(points[i][0],points[i][1]);
		bounds.extend(point);
	    }
	    var clat = (bounds.getNorthEast().lat() + bounds.getSouthWest().lat())/2;
	    var clon = (bounds.getNorthEast().lng() + bounds.getSouthWest().lng())/2;
	    var autoZoom = self.obj.getBoundsZoomLevel(bounds);
	    break;
	case OAT.Map.TYPE_G3:
	    var bounds = new google.maps.LatLngBounds();
	    for (var i=0;i<points.length;i++) {
		var point = new google.maps.LatLng(points[i][0],points[i][1]);
		bounds.extend(point);
	    }
	    self.obj.fitBounds (bounds);
//	    self.fixMarkers ();
	    return;
	    break;
	case OAT.Map.TYPE_Y:
	    var ypoints = [];
	    for (var i=0;i<points.length;i++) {
		var lat = points[i][0];
		var lon = points[i][1];
		var ypoint = new YGeoPoint(lat,lon);
		ypoints.push(ypoint);
	    }
	    var r = self.obj.getBestZoomAndCenter(ypoints);
	    var autoZoom = 17 - r.zoomLevel;
	    var clat = r.YGeoPoint.Lat;
	    var clon = r.YGeoPoint.Lon;
	    break;

	case OAT.Map.TYPE_MS:
	    var mspoints = [];
	    for (var i=0;i<points.length;i++) {
		var lat = points[i][0];
		var lon = points[i][1];
		var mspoint = new VELatLong(lat,lon);
		mspoints.push(mspoint);
	    }
	    self.obj.SetMapView(mspoints);
	    var c = self.obj.GetCenter();
	    var clat = c.Latitude;
	    var clon = c.Longitude;
	    var autoZoom = self.getZoom();
	    break;

	case OAT.Map.TYPE_OL:
	    var bounds = new OpenLayers.Bounds();
	    for (var i=0;i<points.length;i++) {
		var lat = points[i][0];
		var lon = points[i][1];
		bounds.extend(new OpenLayers.LonLat(points[i][1], points[i][0]).transform(self.fromProj, self.toProj));
	    }
	    var c = bounds.getCenterLonLat();
	    var clat = c.lat;
	    var clon = c.lon;
	    var autoZoom = self.obj.getZoomForExtent(bounds,true);
	    break;
	}

	self.centerAndZoom(clat,clon,autoZoom);
	self._fixMarkers();
    }

    /* --- infowindow methods --- */
    /**
	 * opens an info window with user content above given marker
	 * @param {object} marker
	 * @param something info window content
	 */
    this.openWindow = function(marker,something) {
	var elm = $(something);
	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    /* noop */
	    break;
	case OAT.Map.TYPE_G:
	    marker.openInfoWindow(elm);
	    break;

	case OAT.Map.TYPE_G3:
	    if (!marker.__iSPARQL_infoWindow)
		marker.__iSPARQL_infoWindow = new google.maps.InfoWindow({content:elm});
	    marker.__iSPARQL_infoWindow.open(self.obj, marker);
	    break;

	case OAT.Map.TYPE_Y:
	    /*
	     * smartwindow accepts only nodes with nodeValue text
	     * http://developer.yahoo.com/maps/ajax/V3/reference.html#YMarker
             */
	    marker.openSmartWindow(" ");
	    var inner = $("ysaeid");
	    if (inner) {
		OAT.Dom.clear(inner);
		inner.style.position = "relative";
		inner.appendChild(elm);
	    } else {
		throw new Error("Yahoo map API changed, please, report this to OAT developers");
	    }
	    break;

	case OAT.Map.TYPE_MS:
	    /* close others */
	    self.closeWindow();
	    var w = marker.__window;

	    OAT.Dom.clear(w.dom.content);
	    OAT.Dom.append([w.dom.content,elm]);

	    w.open();

	    /* use internal coords affected by fixmarkers */
	    var geo = marker.GetPoints()[0];
	    var pos = self.getPixelFromCoords([geo.Latitude,geo.Longitude]);
	    var size = self.options.markerIconSize;
	    var dim = OAT.Dom.getWH(w.dom.container);

	    w.moveTo(pos[0]+size[0],pos[1]-size[1]-dim[1]);
	    break;

	case OAT.Map.TYPE_OL:
	    /* close others first */
	    self.closeWindow();

	    var w = marker.__window;

	    OAT.Dom.clear(w.contentDiv);
	    OAT.Dom.append([w.contentDiv,elm]);
	    w.updateSize();
	    w.show();
	    break;
	}
    }

    /**
	 * closes opened info window
	 */
    this.closeWindow = function() {
	/* since only one window can be opened at a time
		 * we simply iterate over all markers and close any window
		 * we find
		 */
	for (var i=0;i<self.markers.length;i++) {
	    var marker = self.markers[i];
	    switch (self.provider) {
	    case OAT.Map.TYPE_NONE: /* noop */ break;
	    case OAT.Map.TYPE_G: marker.closeInfoWindow(); break;
	    case OAT.Map.TYPE_G3: marker.closeInfoWindow(); break;
	    case OAT.Map.TYPE_Y: marker.closeSmartWindow(); break;
	    case OAT.Map.TYPE_MS: marker.closeInfoWindow();	break;
	    case OAT.Map.TYPE_OL: marker.closeInfoWindow();	break;
	    } /* switch */
	} /* for all markers */
    }

    /* --- marker methods --- */

    /**
	 * recompute position of marker
	 * repositioning is relative to first marker in a given group
	 * @param {array} markerGroup
	 * @param {integer} index index of a marker to reposition
	 */
    this._newGeoPosition = function(markerGroup,index) {
	var marker = markerGroup[index];
	var dx = 0; /* pixel change */
	var dy = 0;
	var dist = self.options.fixDistance;

	switch (self.options.fix) {
	    /* first in the middle, others around */
	case OAT.Map.FIX_ROUND1:
	    /* first in the middle, skip the repositioning */
	    if (index) {
		var ang = 2*Math.PI*index/(markerGroup.length-1);
		dx = dist * Math.cos(ang);
		dy = dist * Math.sin(ang);
	    }
	    break;

	    /* in the circle around point */
	case OAT.Map.FIX_ROUND2:
	    var ang = 2*Math.PI*index/markerGroup.length;
	    dx = dist * Math.cos(ang);
	    dy = dist * Math.sin(ang);
	    break;

	    /* stacked above */
	case OAT.Map.FIX_STACK:
	    dy = dist * index;
	    break;
	}

	var off = self._getNewCoords(marker,[dx,dy]);
	var lat = off[0];
	var lon = off[1];

	switch (self.provider) {
	case OAT.Map.TYPE_G:
	    marker.setPoint(new GLatLng(lat,lon));
	    break;
	case OAT.Map.TYPE_G3:
	    marker.setPosition (new google.maps.LatLng (lat, lon));
	    break;
	case OAT.Map.TYPE_Y:
	    marker.setYGeoPoint(new YGeoPoint(lat,lon));
	    break;
	case OAT.Map.TYPE_MS:
	    marker.SetPoints(new VELatLong(lat,lon));
	    break;
	case OAT.Map.TYPE_OL:
	    marker.lonlat.lon = lon;
	    marker.lonlat.lat = lat;
	    break;
	}
    }


    /**
     * given a marker and pixel offset, recompute its geoposition
     * @param {object} marker
     * @param {array} shiftArray [dx,dy] offset
     * @returns {array} new [lat,lon]
     */

    this._getNewCoords = function(marker,shiftArray) {
	var p = self.getPixelFromCoords(marker.__coords);
	p[0] += shiftArray[0];
	p[1] += shiftArray[1];
	return self.getCoordsFromPixel(p);
    }

    /**
     * rearrange markers when they would overlap
     */

    this._fixMarkers = function() {
	if (self.markers.length < 2) { return; }
	/* group markers according to distance/overlap */
	var groups = [];

	/* analyze positions */
	for (var i=0;i<self.markers.length;i++) {
	    var m = self.markers[i];
	    var mpos = self.getPixelFromCoords(m.__coords);
	    var index = -1;
	    for (var j=0;j<groups.length;j++) {
		/* find group for this marker */
		var pivot = groups[j][0];
		var ppos = self.getPixelFromCoords(pivot.__coords);
		var dx = mpos[0] - ppos[0];
		var dy = mpos[1] - ppos[1];
		var dist = Math.sqrt(dx*dx+dy*dy);
		if (dist <= self.options.fixEpsilon) { index = j; }
	    }
	    if (index != -1) {
		groups[index].push(m);
	    } else {
		groups.push([m]);
	    }
	}

	/* create better positions */
	for (var i=0;i<groups.length;i++) {
	    var g = groups[i];
	    for (var j=0;j<g.length;j++) { /* re-position all markers */
		self._newGeoPosition(g,j);
	    }
	} /* for all groups */

	if (self.provider == OAT.Map.TYPE_OL) {  /* redraw markers layer */
	    self.obj.layers[1].redraw();
	}
    }

    /**
     * adds marker to the map
     * @param {float} lat marker latitude
     * @param {float} lon marker longitude
     * @param {string/integer} group marker's group name / index
     * @param {string} custOpts custom options:
     *                   image: marker image href,
     *                   imageSize: marker image size,
     *                   custData: custom data to be added to marker object created.
     */

    this.addMarker = function(lat,lon,group,custOpts) {
	var marker = false;
	var markerImage = self.options.markerIcon;
	var markerImageSize = self.options.markerIconSize;

	if (custOpts && custOpts.image) markerImage = custOpts.image;
	if (custOpts && custOpts.imageSize) markerImageSize = custOpts.imageSize;

	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    return;
	    break;

        /* google */

	case OAT.Map.TYPE_G:
	    var icon = new GIcon(G_DEFAULT_ICON,markerImage);
	    icon.shadow = false;
	    icon.printShadow = false;
	    icon.printImage = false;

	    icon.iconSize = new GSize(markerImageSize[0],markerImageSize[1]);

	    marker = new GMarker(new GLatLng(lat,lon),icon);
	    self.obj.addOverlay(marker);

	    GEvent.addListener(marker,'click',function() {
		OAT.MSG.send(self,"MAP_MARKER_CLICK",marker);
	    });
	    GEvent.addListener(self,'mouseover',function() {
		OAT.MSG.send(self,"MAP_MARKER_OVER",marker);
	    });

	    break;
	case OAT.Map.TYPE_G3:
	    var size = new google.maps.Size(markerImageSize[0],markerImageSize[1]);
	    var icon = new google.maps.MarkerImage(markerImage, size);
	    mo = {};
	    mo.position = new google.maps.LatLng (lat,lon);
	    mo.icon = icon;
	    mo.map = self.obj;
	    var marker = new google.maps.Marker(mo);
	    google.maps.event.addListener(marker,'click',function() {
		OAT.MSG.send(self,"MAP_MARKER_CLICK", marker);
	    });
	    google.maps.event.addListener(marker,'mouseover',function() {
		OAT.MSG.send(self,"MAP_MARKER_OVER", marker);
	    });
	    break;

	/* yahoo */

	case OAT.Map.TYPE_Y:
	    var icon = new YImage(markerImage,new YSize(markerImageSize[0],markerImageSize[1]));

	    marker = new YMarker(new YGeoPoint(lat,lon),icon);
	    self.obj.addOverlay(marker);

	    YEvent.Capture(marker,EventsList.MouseClick,function() {
		OAT.MSG.send(self,"MAP_MARKER_CLICK",marker);
	    });
	    YEvent.Capture(marker,EventsList.MouseOver,function() {
		OAT.MSG.send(self,"MAP_MARKER_OVER",marker);
	    });
	    break;

	/* microsoft */

	case OAT.Map.TYPE_MS:
	    marker = new VEShape(VEShapeType.Pushpin,new VELatLong(lat,lon));
	    marker.SetCustomIcon(self.options.markerIcon);
	    marker.ShowDetailOnMouseOver = false;
	    self.obj.AddShape(marker);

	    /* msve windows dont support controlled hiding / show, use OAT.Win */
	    marker.__window = new OAT.Win({buttons:"c",type:OAT.Win.Round});
	    marker.closeInfoWindow = marker.__window.close;

	    /* listeners added in constructor */
	    break;

	/* openlayers */

	case OAT.Map.TYPE_OL:
	    /* custom marker icon */
	    var size = self.options.markerIconSize;
	    var offs = new OpenLayers.Pixel(-(size[0]/2),-size[1]);
	    var icon = new OpenLayers.Icon(self.options.markerIcon,new OpenLayers.Size(size[0],size[1]),offs);

	    /* marker */
	    var marker = 
		new OpenLayers.Marker(new OpenLayers.LonLat(lon,lat).transform(self.fromProj, self.toProj), 
				      icon.clone());

	    self.markersLayer.addMarker(marker);

	    /* we need to associate infowin with popup */
	    marker.__window = new OpenLayers.Popup.Anchored(null,
								  marker.lonlat,
							    new OpenLayers.Size(300,100),
								  "",
								  icon,
								  true,
								  marker.closeInfoWindow);

	    marker.__window.maxSize = new OpenLayers.Size(self.elm.clientWidth-50,self.elm.clientHeight-50);
	    marker.__window.hide();
	    marker.__window.panMapIfOutOfView = true;

	    marker.closeInfoWindow = function() { marker.__window.hide(); }

	    self.obj.addPopup(marker.__window,false);

	    /* callbacks */
	    OAT.Event.attach(marker.icon.imageDiv,"click",function() {
		OAT.MSG.send(self,"MAP_MARKER_CLICK",marker);
	    });

	    OAT.Event.attach(marker.icon.imageDiv,"touchend",function() {
		OAT.MSG.send(self,"MAP_MARKER_CLICK",marker);
	    });

	    OAT.Event.attach(marker.icon.imageDiv,"mouseover",function() {
		OAT.MSG.send(self,"MAP_MARKER_OVER",marker);
	    });
	    break;
	}

	/* set internal properties of marker */
	if (marker) {
	    marker.__window = marker.__window || false;
	    marker.__coords = [lat,lon];
	    marker.__group = group || "none";
	    self.markers.push(marker);
	    if (custOpts.custData) {
		for (var o in custOpts.custData)
		    marker[o] = custOpts.custData[o];
	    }
	}

	return marker;
    }

    /**
     * removes a given marker from the map
     * @param {object} marker
     */

    this.removeMarker = function(marker) {
	var index = self.markers.indexOf(marker);
	if (index == -1) { return; }
	self.markers.splice(index,1);

	switch (self.provider) {
	case OAT.Map.TYPE_G:
	    self.obj.removeOverlay(marker);
	    marker.closeInfoWindow();
	    break;
	case OAT.Map.TYPE_G3:
	    marker.setMap(null)
	    self.obj.closeInfoWindow();
	    break;
	case OAT.Map.TYPE_Y:
	    self.obj.removeOverlay(marker);
	    marker.closeSmartWindow();
	    break;
	case OAT.Map.TYPE_MS:
	    marker.closeInfoWindow();
	    self.obj.DeleteShape(marker);
	    break;
	case OAT.Map.TYPE_OL:
	    marker.closeInfoWindow();
	    self.markersLayer.removeMarker(marker);
	    break;
	}
    }

    /**
	 * removes markers that belong to given group
	 * @param {?} group group name / id
	 */
    this.removeMarkers = function(group) {
	var remove = [];
	var g = group || "*";
	var re = new RegExp(g);

	for (var i=0;i<self.markers.length;i++) {
	    var marker = self.markers[i];
	    if (re.test(marker.__group)) {
		remove.push(marker);
	    }
	}

	while (remove.length) {
	    self.removeMarker(remove[0]);
	    remove.splice(0,1);
	}
    }

    /**
     * shows specific marker
     * @param {object} marker
     */

    this.showMarker = function(marker) {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    /* noop */
	    break;
	case OAT.Map.TYPE_Y:
	    marker.unhide();
	    break;
	case OAT.Map.TYPE_MS:
	    marker.Show();
	    break;
	case OAT.Map.TYPE_G:
	    marker.show();
	    break;
	case OAT.Map.TYPE_G3:
	    marker.setVisible(true);
	    break;
	case OAT.Map.TYPE_OL:
	    marker.display(true);
	    break;
	}
    }

    /**
 	 * hides specific marker
 	 * @param {object} marker
 	 */
    this.hideMarker = function(marker) {
	switch (self.provider) {
	case OAT.Map.TYPE_NONE:
	    /* noop */
	    break;
	case OAT.Map.TYPE_Y:
	    marker.closeSmartWindow();
	    marker.hide();
	    break;
	case OAT.Map.TYPE_MS:
	    marker.closeInfoWindow();
	    marker.Hide();
	    break;
	case OAT.Map.TYPE_G:
	    marker.closeInfoWindow();
	    marker.hide();
	    break;
	case OAT.Map.TYPE_G3:
	    marker.closeInfoWindow();
	    marker.setVisible(false);
	    break;
	case OAT.Map.TYPE_OL:
	    marker.closeInfoWindow();
	    marker.display(false);
	    break;
	}
    }

    /**
     * shows markers that belong to given group
     * @param {string} group regex group of markers to show
     */

    this.showMarkers = function(group) {
	var g = group || ".*";
	var re = new RegExp(g);

	for (var i=0;i<self.markers.length;i++) {
	    var marker = self.markers[i];
	    if (re.test(marker.__group)) {
		self.showMarker(marker);
	    }
	}
    }

    /**
     * hides markers that belong to given group
     * @param {string} group regex group of markers to hide
     */

    this.hideMarkers = function(group) {
	var g = group || ".*";
	var re = new RegExp(g);

	for (var i=0;i<self.markers.length;i++) {
	    var marker = self.markers[i];
	    if (re.test(marker.__group)) {
		self.hideMarker(marker);
	    }
	}
    }

    if (self.options.init) { self.init(provider); }
} /* OAT.Map() */

OAT.Map.TYPE_NONE = 0;		/* none */
OAT.Map.TYPE_G    = 1;		/* google maps */
OAT.Map.TYPE_Y    = 2;		/* yahoo */
OAT.Map.TYPE_MS   = 3;		/* msve */
OAT.Map.TYPE_OL   = 4;		/* openlayers */
OAT.Map.TYPE_G3   = 5;          /* google api v3 */
OAT.Map.MAP_MAP   = 1;		/* map type - normal */
OAT.Map.MAP_ORTO  = 2;		/* satelite */
OAT.Map.MAP_HYB   = 3;		/* hybrid */
OAT.Map.FIX_NONE  = 0;		/* do not reposition markers */
OAT.Map.FIX_ROUND1 = 1;		/* first marker in the center, others on the circle around it */
OAT.Map.FIX_ROUND2 = 2;		/* circle around empty center */
OAT.Map.FIX_STACK  = 3;		/* stack above first */

/**
 * loads requested api and calls user callback
 */

OAT.Map.loadApi = function(provider, optObj) {

    /* generate temporary referencable callback */
    var gencallback = function() {
	var funcName = "func_" + Math.random().toString().replace(".","");
	window[funcName] = function() {
	    window[funcName] = null;
	    if (options.callback) { options.callback(provider); }
	    OAT.MSG.send (OAT, "OAT_MAP_API_LOADED", provider);
	}
	return funcName;
    }

    var providers = {
	'google':'https://maps.google.com/maps?file=api&v=2.x&async=2',
	'googlev3':'https://maps.google.com/maps/api/js?sensor=true',
	'yahoo':'https://api.maps.yahoo.com/ajaxymap?v=3.8',
	'openlayers':'https://openlayers.org/api/OpenLayers.js',
	'msve':'https://dev.virtualearth.net/mapcontrol/mapcontrol.ashx?v=6.2',
	'msve_atlascompat':'https://dev.virtualearth.net/mapcontrol/v6.2/js/atlascompat.js'
    };

    var options = {
	callback:false,
	key:false
    };

    for (var p in optObj) { options[p] = optObj[p]; }

    var features = [];
    var appKey = options.key;

    switch (provider) {
    /* google supports callbacks passed via url */

    case OAT.Map.TYPE_G:
	var url = providers["google"];

	if (!(appKey = OAT.ApiKeys.getKey ('gmapapi')))
	    appKey = '';

	url += "&key=" + appKey;
	url += "&callback=" + gencallback();
	OAT.Loader.load(url);
	break;

    case OAT.Map.TYPE_G3:
	var url = providers["googlev3"];

/*	if (!(appKey = OAT.ApiKeys.getKey ('gmapapi')))
	    appKey = '';

	url += "&key=" + appKey; */
	url += "&callback=" + gencallback();
	OAT.Loader.load(url);
	break;

    /*
     * yahoo uses document write, so we have to workaround
     * that. it also doesnt support callbacks.
     */

    case OAT.Map.TYPE_Y:
	var url = providers["yahoo"];

	if (!(appKey = OAT.ApiKeys.getKey ('ymapapi')))
	    appKey = '';

	url += "&appid=" + appKey;

	window['_dw'] = document.write;
	window['_yloaded'] = 0;

	var cb = function() {
	    window['_yloaded']++;
	    /* animation, dom, dragdrop, event, ymapapi */
	    if (window['_yloaded'] == 5) {
		document.write = window['_dw'];
		window['_dw'] = null;
		window['_yloaded'] = null;
		if (options.callback) { options.callback(provider); }
	    }
	}

	document.write = function(e) {
	    var src = e.match(/src="(.*?)"/)[1];
	    OAT.Loader.load(src,cb);
	}

	OAT.Loader.load(url,false);
	break;

    /* openlayers have single file, that can be directly loaded */
    case OAT.Map.TYPE_OL:
	var url = providers["openlayers"];
	var cb = function() { if (options.callback) { options.callback(provider); } };
	OAT.Loader.load(url,cb);
	break;

    /* msve has onScriptLoad, like google, but needs atlascompat
    * we also use our own windowing api, since theirs isnt sufficient
    */

    case OAT.Map.TYPE_MS:
	var deps = ["win"];
	var url = providers["msve"] + "&onScriptLoad=" + gencallback();
	if (!OAT.Browser.isIE) { deps.push(providers["msve_atlascompat"]); }
	OAT.Loader.load(url,false,deps);
	break;
    }
}
