/*
	Abstract API atop various mapping engines
	var m = new OAT.Map(something, provider, fix)
	m.addTypeControl()
	m.addMapControl()
	m.setMapType(type)
	m.centerAndZoom(lat,lon,zoom)
	m.setZoom(zoom)
	m.getZoom()
	m.addMarker(lat,lon,file,callback)
	m.removeMarker(marker)
	m.removeMarkers()
	m.openWindow(marker,something)
	m.closeWindow()
	m.optimalPosition(pointArr)
*/

window.pyca = [];
OAT.MapData = {
	TYPE_G:1,
	TYPE_Y:2,
	TYPE_MS:3,
	TYPE_OL:4,
	MAP_MAP:1,
	MAP_ORTO:2,
	MAP_HYB:3,
	FIX_NONE:0,
	FIX_ROUND1:1,
	FIX_ROUND2:2,
	FIX_STACK:3
}

OAT.Map = function(something, provider, fix, fixDistance) {
	var self = this;
	this.id = 0; /* ms map pins need id */
	this.provider = provider;
	this.obj = false;
	this.fix = fix;
	this.fixDistance = fixDistance;
	this.elm = $(something);
	this.markerArr = [];
	
	switch (self.provider) { /* create main object */
		case OAT.MapData.TYPE_G: self.obj = new GMap2(self.elm); break;
		case OAT.MapData.TYPE_Y: self.obj = new YMap(self.elm); break;
		case OAT.MapData.TYPE_MS: 
			var params = {};
			params.latitude = 34.0453522;
			params.longitude = -118.26197;
			params.zoomlevel = 16;
			params.mapstyle = 'r';
			params.showScaleBar = true;
			params.showDashboard = true;
			params.dashboardSize = "normal";
			params.dashboardX = 3;
			params.dashboardY = 3;
			self.elm.id = 'our_mapping_element';
			self.obj = new VEMap('our_mapping_element');
			self.obj.LoadMap();
		break;
		case OAT.MapData.TYPE_OL: 
		    self.obj = new OpenLayers.Map(self.elm);
		    var wms = new OpenLayers.Layer.WMS( "OpenLayers WMS", 
		        "http://labs.metacarta.com/wms/vmap0", {layers: 'basic'} );
		    self.obj.addLayer(wms);
		    self.markersLayer = new OpenLayers.Layer.Markers("Marker Pins");
		    self.obj.addLayer(self.markersLayer);		
			self.obj.zoomToFullExtent();
		break;
	}
	
	if (fix != OAT.MapData.FIX_NONE) { /* marker fix */
		switch (self.provider) { 
			case OAT.MapData.TYPE_G: 
				GEvent.addListener(self.obj,'zoomend',function(){self.fixMarkers();});
			break;
			case OAT.MapData.TYPE_Y: 
				YEvent.Capture(self.obj,EventsList.changeZoom,function(){self.fixMarkers();});
			break;
			case OAT.MapData.TYPE_MS:
				self.obj.AttachEvent("onendzoom",function(){self.fixMarkers();});
			break;
		}
	}
	
	/* --- methods --- */
	
	this.newGeoPosition = function(marker,siblingIndex,siblingCount) {
		/* new position for marker: siblingIndex in [0,siblingCount-1] */
		var lat = marker.__coords[0];
		var lon = marker.__coords[1];
		var dx = 0; /* pixel change */
		var dy = 0;
		switch (self.fix) {
			case OAT.MapData.FIX_ROUND1:
				if (siblingIndex) {
					var ang = 2*Math.PI*(siblingIndex-1)/(siblingCount-1);
					dx = self.fixDistance * Math.cos(ang);
					dy = self.fixDistance * Math.sin(ang);
				}
			break;
			case OAT.MapData.FIX_ROUND2:
				var ang = 2*Math.PI*siblingIndex/siblingCount;
				dx = self.fixDistance * Math.cos(ang);
				dy = self.fixDistance * Math.sin(ang);
			break;
			case OAT.MapData.FIX_STACK:
				dy = self.fixDistance*siblingIndex;
			break;
		}
		
		switch (self.provider) { 
			case OAT.MapData.TYPE_G: marker.setPoint(new GLatLng(lat+dy*self.opp,lon+dx*self.opp));	break;
			case OAT.MapData.TYPE_Y: marker.setYGeoPoint(new YGeoPoint(lat+dy*self.opp,lon+dx*self.opp)); break;
			case OAT.MapData.TYPE_MS: 
				marker.LatLong.latitude = lat + dy*self.opp;
				marker.LatLong.longitude = lon + dx*self.opp;
			break;
		}
	}
	
	this.fixMarkers = function() {
		if (self.markerArr.length < 2) { return; }
		/* get geo offset per 1 pixel */
		var testm = self.markerArr[0];
		switch (self.provider) { 
			case OAT.MapData.TYPE_G: 
				var ll1 = new GLatLng(testm.__coords[0],testm.__coords[1]);
				var p1 = self.obj.fromLatLngToDivPixel(ll1);
				var p2 = new GPoint(p1.x,p1.y-1);
				var ll2 = self.obj.fromDivPixelToLatLng(p2)
				self.opp = ll2.lat() - testm.__coords[0];
			break;
			case OAT.MapData.TYPE_Y: 
				var ll1 = new YGeoPoint(testm.__coords[0],testm.__coords[1]);
				var p1 = self.obj.convertLatLonXY(ll1);
				var p2 = new YCoordPoint(p1.x,p1.y-1);
				var ll2 = self.obj.convertXYLatLon(p2);
				self.opp = ll2.Lat - testm.__coords[0];
			break;
			case OAT.MapData.TYPE_MS: 
				var z = 1 + self.getZoom();
				var ll1 = new VELatLong(testm.__coords[0],testm.__coords[1]);
				var p1 = self.obj.LatLongToPixel(ll1,z);
				var p2 = new Msn.VE.Pixel(p1.x,p1.y-1);
				var ll2 = self.obj.PixelToLatLong(p2.x,p2.y,z);
				self.opp = ll2.Latitude - testm.__coords[0];
			break;
		}		
		var conversionObject = {}
		/* analyze positions */
		for (var i=0;i<self.markerArr.length;i++) {
			var m = self.markerArr[i];
			var index = m.__coords[0]+","+m.__coords[1];
			if (index in conversionObject) {
				conversionObject[index]++;
			} else {
				conversionObject[index] = 1;
			}
		}
		
		/* create better positions */
		var usedConversion = {};
		for (var i=0;i<self.markerArr.length;i++) {
			var m = self.markerArr[i];
			var index = m.__coords[0]+","+m.__coords[1];
			if (!(index in usedConversion)) { usedConversion[index] = 0; }
			self.newGeoPosition(m,usedConversion[index],conversionObject[index]);
			usedConversion[index]++;
		}
	}
	
	this.addTypeControl = function() {
		switch (self.provider) {
			case OAT.MapData.TYPE_G: self.obj.addControl(new GMapTypeControl()); break;
			case OAT.MapData.TYPE_Y: self.obj.addTypeControl(); break;
			case OAT.MapData.TYPE_OL: self.obj.addControl(new OpenLayers.Control.LayerSwitcher()); break;

		}	
	}
	
	this.addMapControl = function() {
		switch (self.provider) {
			case OAT.MapData.TYPE_G: self.obj.addControl(new GLargeMapControl()); break;
			case OAT.MapData.TYPE_Y: self.obj.addZoomLong(); self.obj.addPanControl(); break;
		}	
	}

	this.setMapType = function(type) {
		switch (self.provider) {
			case OAT.MapData.TYPE_G: 
				switch (type) {
					case OAT.MapData.MAP_MAP: self.obj.setMapType(G_NORMAL_MAP); break;
					case OAT.MapData.MAP_ORTO: self.obj.setMapType(G_SATELLITE_MAP); break;
					case OAT.MapData.MAP_HYB: self.obj.setMapType(G_HYBRID_MAP); break;
				}
			break;
			
			case OAT.MapData.TYPE_Y: 
				switch (type) {
					case OAT.MapData.MAP_MAP: self.obj.setMapType(YAHOO_MAP_REG); break;
					case OAT.MapData.MAP_ORTO: self.obj.setMapType(YAHOO_MAP_SAT); break;
					case OAT.MapData.MAP_HYB: self.obj.setMapType(YAHOO_MAP_HYB); break;
				}
			break;

			case OAT.MapData.TYPE_MS: 
				switch (type) {
					case OAT.MapData.MAP_MAP: self.obj.SetMapStyle("r"); break;
					case OAT.MapData.MAP_ORTO: self.obj.SetMapStyle("a"); break;
					case OAT.MapData.MAP_HYB: self.obj.SetMapStyle("h"); break;
				}
			break;
		}	
	}

	this.centerAndZoom = function(lat,lon,zoom) { /* 0 - far, 16 - close */
		switch (self.provider) {
			case OAT.MapData.TYPE_G: self.obj.setCenter(new GLatLng(lat,lon),zoom); break;
			case OAT.MapData.TYPE_Y: self.obj.drawZoomAndCenter(new YGeoPoint(lat,lon),17-zoom); break;
			case OAT.MapData.TYPE_MS: self.obj.SetCenterAndZoom(new VELatLong(lat,lon),zoom+1); break;
			case OAT.MapData.TYPE_OL: self.obj.setCenter(new OpenLayers.LonLat(lon,lat),zoom); break;
		}	
	}
	
	this.setZoom = function(zoom) {
		switch (self.provider) {
			case OAT.MapData.TYPE_G: self.obj.setZoom(zoom); break;
			case OAT.MapData.TYPE_Y: self.obj.setZoomLevel(17-zoom); break;
			case OAT.MapData.TYPE_MS: self.obj.SetZoomLevel(zoom+1); break;
//			case OAT.MapData.TYPE_OL: self.obj.zoomTo(5); break;
		}	
	}
	
	this.getZoom = function() {
		switch (self.provider) {
			case OAT.MapData.TYPE_G: return self.obj.getZoom(); break;
			case OAT.MapData.TYPE_Y: return 17-self.obj.getZoomLevel(); break;
			case OAT.MapData.TYPE_MS: return self.obj.GetZoomLevel()-1; break;
			case OAT.MapData.TYPE_OL: return self.obj.getZoom(); break;
		}	
	}
	
	this.addMarker = function(lat,lon,file,clickCallback) { /* array of [lat,lon,file,callback]; will callback(marker) when clicked */
		switch (self.provider) {
			case OAT.MapData.TYPE_G: 
				var icon = new GIcon(G_DEFAULT_ICON,file);
				icon.iconSize = new GSize(18,41);
				icon.shadow = "";
				var marker = new GMarker(new GLatLng(lat,lon),icon);
				self.obj.addOverlay(marker);
				if (clickCallback) { GEvent.addListener(marker,'click',function(){clickCallback(marker);}); }
			break;
			case OAT.MapData.TYPE_Y: 
				var icon = new YImage(file,new YSize(18,41));
				var marker = new YMarker(new YGeoPoint(lat,lon),icon);
				self.obj.addOverlay(marker);
				if (clickCallback) { YEvent.Capture(marker,EventsList.MouseClick,function(){clickCallback(marker);}); }
			break;
			case OAT.MapData.TYPE_MS:
				self.id++;
				var id = "pin_"+self.id;
				var marker = new VEPushpin(id,new VELatLong(lat,lon),file,null,null);
				VEPushpin.ShowDetailOnMouseOver = false;
				self.obj.AddPushpin(marker);
				marker.__id = id;
				marker.closeInfoWindow = function() { if (marker.__win) {
						OAT.Dom.unlink(marker.__win); 
						marker.__win = false;
					}
				}
				OAT.Layers.addLayer(id,"mouseover");
				if (clickCallback) { OAT.Dom.attach($(id).firstChild,"click",function(){clickCallback(marker);}); }
			break;
			case OAT.MapData.TYPE_OL: 
			    var marker = new OpenLayers.Marker(
			        new OpenLayers.LonLat(lon,lat), 
			        new OpenLayers.Icon(file,new OpenLayers.Size(18,41))
				);
			    self.markersLayer.addMarker(marker);
				marker.closeInfoWindow = function() { if (marker.__win) {
						OAT.Dom.unlink(marker.__win); 
						marker.__win = false;
					}
				}
				OAT.Layers.addLayer(marker.icon.imageDiv,"mouseover");
				if (clickCallback) { 
					marker.icon.imageDiv.style.cursor = "pointer";
					OAT.Dom.attach(marker.icon.imageDiv,"click",function(){if (!marker.__win){clickCallback(marker);}}); 
					}
			break;
		}	

		marker.__coords = [lat,lon];
		self.markerArr.push(marker);
		return marker;
	}
	
	this.removeMarker = function(marker) {
		var index = self.markerArr.find(marker);
		self.markerArr.splice(index,1);
		switch (self.provider) {
			case OAT.MapData.TYPE_G: 
				self.obj.removeOverlay(marker);
				self.obj.closeInfoWindow(); 
			break;
			case OAT.MapData.TYPE_Y:
				self.obj.removeOverlay(marker);
				marker.closeSmartWindow(); 
			break;
			case OAT.MapData.TYPE_MS: 
				marker.closeInfoWindow();
				OAT.Layers.removeLayer(marker.__id);
				self.obj.DeletePushpin(marker.__id);
			break;
			case OAT.MapData.TYPE_OL: 
				marker.closeInfoWindow();
				OAT.Layers.removeLayer(marker);
				self.markersLayer.removeMarker(marker);
			break;
		}	
	}
	
	this.removeMarkers = function() {
		while (self.markerArr.length) {
			self.removeMarker(self.markerArr[0]);
		}
	}
	
	this.optimalPosition = function(pointArr) {
		switch (self.provider) {
			case OAT.MapData.TYPE_G: 
				var bounds = new GLatLngBounds();
				for (var i=0;i<pointArr.length;i++) {
					var point = new GLatLng(pointArr[i][0],pointArr[i][1]);
					bounds.extend(point);
				}
				var clat = (bounds.getNorthEast().lat() + bounds.getSouthWest().lat())/2;
				var clon = (bounds.getNorthEast().lng() + bounds.getSouthWest().lng())/2;
				var autoZoom = self.obj.getBoundsZoomLevel(bounds);
			break;
			
			case OAT.MapData.TYPE_Y: 
				var points = [];
				var minLat = 180;
				var minLon = 180;
				var maxLat = -180;
				var maxLon = -180;
				for (var i=0;i<pointArr.length;i++) {
					var lat = pointArr[i][0];
					var lon = pointArr[i][1];
					var point = new YGeoPoint(lat,lon);
					points.push(point);
					/* resize bounding box */
					if (lat > maxLat) { maxLat = lat; }
					if (lat < minLat) { minLat = lat; }
					if (lon > maxLon) { maxLon = lon; }
					if (lon < minLon) { minLon = lon; }
				}
				var clat = (minLat + maxLat)/2;
				var clon = (minLon + maxLon)/2;
				var autoZoom = self.obj.getZoomLevel(points);
			break;
			
			case OAT.MapData.TYPE_MS: 
				var points = [];
				for (var i=0;i<pointArr.length;i++) {
					var lat = pointArr[i][0];
					var lon = pointArr[i][1];
					var point = new VELatLong(lat,lon);
					points.push(point);
				}
				self.obj.SetMapView(points);			
				var c = self.obj.GetCenter();
				var clat = c.Latitude;
				var clon = c.Longitude;
				var autoZoom = self.getZoom();
			break;

			case OAT.MapData.TYPE_OL: 
				var c = self.obj.getCenter();
				var clat = c.lat;
				var clon = c.lon;
				var autoZoom = self.obj.getZoom(bounds);
			break;

		}

		self.centerAndZoom(clat,clon,autoZoom);
		self.fixMarkers();
	}
	
	this.openWindow = function(marker,something) {
		var elm = $(something);
		switch (self.provider) {
			case OAT.MapData.TYPE_G:
				marker.openInfoWindow(elm);
			break;
			
			case OAT.MapData.TYPE_Y:
				marker.openSmartWindow(" ");
				var inner = $("ysaeid");
				if (inner) {
					inner.style.position = "relative";
					inner.appendChild(elm);
				} else { alert('Yahoo! Map API change - could not find window to append to.'); }
			break;
			
			case OAT.MapData.TYPE_MS:
				for (var i=0;i<self.markerArr.length;i++) { self.markerArr[i].closeInfoWindow(); }
				marker.__win = OAT.Dom.create("div",{position:"relative",border:"2px solid #000",padding:"1em",backgroundColor:"#fff",zIndex:"200"});
				OAT.Dom.attach(marker.__win,"mousedown",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"dblclick",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"mousewheel",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"scroll",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"DOMMouseScroll",function(event){event.cancelBubble = true;});
				marker.__win.appendChild(elm);
				$(marker.__id).appendChild(marker.__win);
				var close = OAT.Dom.create("img",{position:"absolute",top:"0px",right:"0px",margin:"2px",cursor:"pointer"});
				close.src = "/DAV/JS/images/MsWin_close.png";
				marker.__win.appendChild(close);
				OAT.Dom.attach(close,"click",marker.closeInfoWindow);
			break;

			case OAT.MapData.TYPE_OL:
				for (var i=0;i<self.markerArr.length;i++) { self.markerArr[i].closeInfoWindow(); }
				marker.__win = OAT.Dom.create("div",{position:"absolute",border:"2px solid #000",padding:"1em",backgroundColor:"#fff",zIndex:"200"});
				OAT.Dom.attach(marker.__win,"dblclick",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"mousewheel",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"scroll",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"DOMMouseScroll",function(event){event.cancelBubble = true;});
				OAT.Dom.attach(marker.__win,"mousedown",function(event){event.cancelBubble = true;});
				marker.__win.appendChild(elm);
				marker.icon.imageDiv.appendChild(marker.__win);
				var close = OAT.Dom.create("img",{position:"absolute",top:"0px",right:"0px",margin:"2px",cursor:"pointer"});
				close.src = "/DAV/JS/images/MsWin_close.png";
				marker.__win.appendChild(close);
				OAT.Dom.attach(close,"click",marker.closeInfoWindow);
			break;
		}	
	}
	
	this.closeWindow = function() {
		for (var i=0;i<self.markerArr.length;i++) {
			var marker = self.markerArr[i];
			switch (self.provider) {
				case OAT.MapData.TYPE_G: self.obj.closeInfoWindow(); break;
				case OAT.MapData.TYPE_Y: marker.closeSmartWindow(); break;
				case OAT.MapData.TYPE_MS: marker.closeInfoWindow();	break;
				case OAT.MapData.TYPE_OL: marker.closeInfoWindow();	break;
			} /* switch */
		} /* for all markers */
	}

} /* OAT.Map() */

OAT.Loader.pendingCount--;