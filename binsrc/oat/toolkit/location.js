/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 */


OAT.CircularBuffer = function (len, initList) {
    var self = this;
    this._length = len;
    this._buf = [];
    this._ptr = 0;
    this._fill = 0;
    
	this.serialize = function () {
		var ser_buf = [];
		for (i = 1;i<self._buf.length;i++) {
			if (typeof self._buf[i] == 'object')
				ser_buf[i] = self._buf[i].serialize();
			else ser_buf[i] = self._buf[i];
		}

		var o = {
			buf: self.ser_buf,
			length: self._length,
			ptr: self._ptr,
			fill: self._fill
		}
		return OAT.JSON.serialize (o);
	}

	this.initFromSerialized = function (s) {
		var o = OAT.JSON.deserialize (s);
		if (o != null) {
			self._length = o.length;
			self._buf = o.buf;
			self._ptr = o.ptr;
			self._fill = o.fill;
			return true;
		}
		return false;
	}

    this.append = function (item) {
		if (self._fill < self._length) {
			self._buf.append(item);
			self._fill++;
			self._ptr++;
			return item;
		}
		if (self._ptr == self._length)
			(self._ptr = 0)
		
		self._buf[self._ptr] = item;
		self._ptr++;
		return item;
    }
	
    this.clear = function () {
		self._buf = [];
		self._fill = self._ptr = 0;
    }
	
    this.appendList = function (list) {
		for (var i=0;i<list.length;i++)
			self.append (list[i]);
    }
	
    this.getFill = function () {
		return self._fill;
    }
	
    this.getLength = this.getFill;
	
    this.getNth = function (n)
    {
		return self._buf[(self._ptr+n)%self._fill];
    }
	
    this.putNth = function (n, item) {
		self._buf[(self._ptr+n)%self._fill] = item;
		return item;
    }
	
    this.toList = function () {
		var retList = [];
		
		if (self._buf.length == 0) 
			return retList;
		
		for (var i=0;i<self._fill;i++) {
			retList.append(self.getNth(i));
		}
		return retList;
    }
	
    this.find = function (item) {
		for (i=0;i<self._fill;i++) {
			if (self.getNth(i) == item)
				return i;
		}
		return -1;
    }
	
    if (isArray(initList)) {
		if (initList.length <= self._length) {
			self._buf = initList;
			self._fill = initList.length;
			self._ptr = self._fill;
			return;
		} else {
			self._buf = initList.slice (initList.length - self._length, initList.length-1);
		}
    }
}


/*
	OAT.Notify.send(content, optObj);
*/

/*
   Acquiring a location:

   If empty cache, acquire location according to accuracy mode
     
   If last cache entry age < LocOpts.

*/

OAT.Location        = function (o) {
    var self        = this;
    this._lat       = 0;
    this._lon       = 0;
    this._alt       = 0;
    this._acc       = -1;
    this._altacc    = -1;
    this._dir       = 0;
    this._spd       = 0;
    this._cdate     = new Date ();
    this._mdate     = new Date ();

    this.getLat     = function () { return self._lat; }
    this.getLon     = function () { return self._lon; }
    this.getAlt     = function () { return self._alt; }

    this.getAcc     = function () { return self._acc; }
    this.getAltAcc  = function () { return self.altacc; }

    this.getCdate   = function () { return self._cdate; }
    this.getMdate   = function () { return self._mdate; }

    this.setLat     = function (lat) { self._lat = lat; self.touch(); return lat; };
    this.setLon     = function (lon) { self._lon = lon; self.touch(); return lon; };
    this.setAlt     = function (alt) { self._alt = alt; self.touch(); return alt; };

    this.setAcc     = function (acc) { self._acc = acc; self.touch(); return acc; };
    this.setAltAcc  = function (altacc) { self._altacc = _altacc; self.touch(); return _altacc;};

    this.setCdate   = function (d) {
	self._cdate = new Date (d);
    }

    this.setMdate = function (d) {
	self._mdate = new Date (d);
    }

    // http://bit.ly/XFFe4

    this.touch = function () {
	_mdate = new Date ();
    }

    this.serialize = function () {
	OAT.Debug.log (0,'Location.serialize');
	return (OAT.JSON.serialize(
	    {lat:    self._lat,
	     lon:    self._lon,
	     alt:    self._alt,
	     acc:    self._acc,
	     altacc: self._altacc,
	     dir:    self._dir,
	     spd:    self._spd,
	     cate:   self._cdate.toUTCString(),
	     mdate:  self._mdate.toUTCString()}));
    }

    this.initFromSerialized = function () {
    }

    this.parse = function (serLoc) {
	if (serLoc.lat) self._lat = serLoc.lat;
	if (serLoc.lon) self._lon = serLoc.lon;
	if (serLoc.alt) self._alt = serLoc.alt;
	if (serLoc.acc) self._acc = serLoc.acc;
	if (serLoc.altacc) self._altacc = serLoc.altAcc;
	if (serLoc.spd) self._spd = serLoc.spd;
	if (serLoc.dir) self._dir = serLoc.dir;
	if (serLoc.mdate)
	    self._mdate = new Date (serLoc.mdate);
	else 
	    self._mdate = new Date ();

	if (serLoc.cdate) 
	    self._cdate = new Date (serLoc.cdate);
	else 
	    self._mdate = new Date ();

	return self;
    }

    this.notImplemented = function (m) { throw (new Error (m)); }

    this.triplify    = function () { self.notImplemented("triplify");};
    this.fromRDFItem = function () { self.notImplemented("fromRDFItem");};
    this.toRDFItem   = function () { self.notImplemented("toRDFItem");};

    if (typeof o == "object")
	this.parse (o);
}

//OAT.E_LocationException = function () {
//    this._OAT_ex_type = "E_LocationException";
//}

//OAT.E_LocationException.prototype = OAT.Exception.prototype;

OAT.LocationCache = function (size, initArr, getCurrent) {
    var self = this;
    this._timeout = 10000; // milliseconds
    this._currentLocation = [];
    this._locationCache = new OAT.CircularBuffer (size);
    this._locOpts = {timeout: self._timeout, enableHighAccuracy: true};
    this._acquiring = false;
    this._acquire_denied = false;
    this._timed_out = false;

    this._persistLocationCache = function () {
	if (typeof localStorage != 'undefined') {
	    OAT.Debug.log (0,'LocationCache: in _persistLocationCache: DISABLED.');
//	    localStorage.iSPARQL_locationCache = self._locationCache.serialize();
//	    iSPARQL.Common.log ('LocationCache: in _persistLocationCache: saved');
	}
    }

    this._locAcquireHandler = function (pos) {
	OAT.Debug.log (0,'LocationCache: in _locAcquireHandler');
	self._acquiring = false;
	var o = {};

	if (pos.coords.latitude) o.lat = pos.coords.latitude;
	if (pos.coords.longitude) o.lon = pos.coords.longitude;
	if (pos.coords.altitude) o.alt = pos.coords.altitude;
	if (pos.coords.accuracy) o.acc = pos.coords.accuracy;
	if (pos.coords.altitudeAccuracy) o.altacc = pos.coords.altitudeAccuracy;
	if (pos.coords.speed) o.spd = pos.coords.speed;
	if (pos.coords.direction) o.dir = pos.coords.direction;

	l = new OAT.Location (o);
	l.setCdate (new Date (pos.timestamp));
	self._locationCache.append (l);
	self._persistLocationCache();
	OAT.MSG.send (self, "LOCATION_ACQUIRED", l);
    }

    this._locErrorHandler = function (e) {
	OAT.Debug.log (0,'LocationCache: in _locErrorHandler');
        self._acquiring = false;
	switch (e.code) {
	case e.TIMEOUT:
	    self._timed_out = true;
	    OAT.MSG.send (self, "LOCATION_TIMEOUT", e);
	    break;
	case e.PERMISSION_DENIED:
	    self._acquire_denied = true;
	    OAT.MSG.send (self, "LOCATION_ERROR", e);
	    break;
	}
	OAT.MSG.send (self, "LOCATION_ERROR", e);
    }

    this.acquireCurrent = function () {
	if (navigator.geolocation) {
	    if (!self._acquiring) {
		navigator.geolocation.getCurrentPosition (self._locAcquireHandler, 
							  self._locErrorHandler, 
							  self._locOpts);
		self._acquiring = true;
	    }
	}
    }

    this.startTracking = function () {
	if (navigator.geolocation) {
	    navigator.geoLocation.watchPosition (self._locAcquireHandler, 
						 self._locErrorHandler, 
						 {maxAge: 10000});
	}
    }

    this.getLatest = function () {
	return self._locationCache.getNth(self._locationCache.getLength()-1);
    }

    for (i=0;i<initArr.length;i++)
	self._locationCache.append (new Location(initArr[i]));
    
    if (getCurrent) {
	self.acquireCurrent ();
    }

    this.addLocation = function (l) {
	self._locationCache.append (l);
    }

    this.setManualLocation = function (l) {
	self._locationCache.append(l);
	self._acquiring = false;
	OAT.MSG.send (self, "LOCATION_ACQUIRED", l);
    }

// XXX

    this.serialize = function () {
	return false;
    }

    this.initFromSerialized = function () {
	return false;
    }

    this.cancelLocation = function () {
	return false;
    }
}

//
// Use (GOOG) geoCoder Api - only by address, no bounds atm...
//

OAT.Geocoder = function (o) {
    var self = this;

    this._options = {
	retries: 2,
	retry_to_ms:2500 // msec between retries upon server error
    };

    this._retries_left = 0;
    this._request = {};
    this._retry_to = false;

    for (var p in o) { this._options[p] = o[p]; }

    this._geocoder = new google.maps.Geocoder();

    this._geocode = function () {
	self._geocoder.geocode (self._request, self.handleResult); 
    }

    this._retry_geocode = function () {
	OAT.MSG.send (self,"GEOCODE_RETRYING",null);
	self._geocode();
    }

    this.geocode = function (addr) {
	self._retries_left = self._options.retries;
	self._request = {address: addr};
	self._geocode ();
    }

    this.handleResult = function (results, stat) {
	var s = google.maps.GeocodeStatus;
	switch (stat) {
	case m.OK:
	    if (self._retry_to) window.clearTimeout (self._retry_to);
	    OAT.MSG.send (self,"GEOCODE_RESULT",results);
	    break;
	case m.UNKNOWN_ERROR:
	    if (self._retries_left) {
		self._retries_left--;
		OAT.MSG.send (self,"GEOCODE_FAIL_RETRYING",stat);
		if (!self._retry_to) 
		    self._retry_to = setTimeout (self._retry_geocode(), self._options.retry_to_ms);
		break;
	    }
	default:
	    if (self._retry_to) window.clearTimeout (self._retry_to);
	    OAT.MSG.send (self,"GEOCODE_FAIL",stat);
	}
    }
}

//
// Requires HTML template. IDs:
// #locAcquireUI - outer ctr - shown when loc being acquired
// #locAcquireMsg
// #locAcquireBtnCtr
// #locAcquireLonCtr
// #locAcquireLatCtr
// #locAcquireAccCtr
// #locAcquireUseBtn
// #locAcquireCancelBtn
//
// o.useCB - use button callback
// o.cancelCB - cancel callback
// o.cache - cache
//

OAT.locAcquireUIMode = {
    AUTO:   0,
    GEOCODE:1,
    MANUAL: 2
}

OAT.locationAcquireUI = function (o) {
    var self = this;

    this.o = {useGeocoder:false,
	      manualFallback:true,
	      uiMode: OAT.locAcquireUIMode.AUTO};

    for (p in o)
	this.o[p] = o[p];

    this._lc = o.cache;

    this._latC        = $("locAcquireLatCtr");
    this._lonC        = $("locAcquireLonCtr");
    this._accC        = $("locAcquireAccCtr");
    this._titleT      = $("locAcquireTitleT");
    this._msg         = $("locAcquireMsg");
    this._err         = $("locAcquireErrMsg");
    this._useBtn      = $("locAcquireUseBtn");
    this._cancelBtn   = $("locAcquireCancelBtn");
    this._manualBtn   = $("locAcquireManualBtn");
    this._geocodeBtn  = $("locAcquireGeocodeBtn");
    this._refBtn      = $("locAcquireRefreshBtn");
    this._thr         = $("locAcquireThrobber");
    this._geocodeForm = $("locAcquireGeocodeForm");
    this._latI        = $("locAcquireManualLatInput");
    this._lonI        = $("locAcquireManualLonInput");

    this._ctr = $("locAcquireUI");

    this._currL = false;

    this._useCB = self.o.useCB;
    this._cancelCB = self.o.cancelCB;

    this._uiMode = self.o.uiMode;

    this.hide = function () {
	OAT.Dom.hide (self._ctr);
    }

    this.show = function () {
	OAT.Dom.show(self._ctr);
    }

    this.refresh = function () {
	
	OAT.Dom.hide (self._err);
	OAT.Dom.show (self._thr);
	self._lc.acquireCurrent();
    }

    this.getCtr = function () {
	return this._ctr;
    }

// "private" members

    this._refresh_to = 0;    

    this._locHandler = function (m,s,l) {
	OAT.Debug.log (0,'LocAcquireUI: in _locHandler');
	self._latI.value = l.getLat();
	self._lonI.value = l.getLon();
	self._accC.innerHTML = l.getAcc();
	self._currL = l;
	OAT.Dom.show (self._useBtn);
	self._refBtn.innerHTML = "Refresh";
	OAT.Dom.hide(self._thr);
	OAT.Dom.hide(self._err);
	if (l.getAcc() > o.minAcc) {
	    self._refresh_to = setTimeout(self.refresh, 5000);
	} else {
	    self.hide();
	    self.o.useCB(self.o.cbParm, self._currL);
	}
    }

    this._errHandler = function (m,s,e) {
	switch (e.code) {
	case e.TIMEOUT:
	    self._titleT.innerHTML = "Timed out";
	    break;
        case e.PERMISSION_DENIED:
	    self._titleT.innerHTML = "Permission denied";
	    break;
        case e.POSITION_UNAVAILABLE:
	    self._titleT.innerHTML = "Location failed";
	    break;
	}

	if (e.message) self._err.innerHTML = e.message;
	self._refBtn.innerHTML = "Retry";

	OAT.Dom.show (self._err);
	OAT.Dom.hide (self._thr);
	OAT.Dom.hide (self._useBtn);
    }

    this._refreshHandler = function () {
	self._reset();
	self.refresh();
    }

    this._manualHandler = function () {
	self._setManualMode();
    }

    this._geocodeHandler = function () {
	self._setGeocodeMode();
    }

    this._reset = function () {
	clearTimeout (self._refresh_to);
	OAT.Dom.hide(self._geocodeForm);
	OAT.Dom.hide(self._manualForm);

	OAT.Dom.hide (self._err);
	self._titleT.innerHTML = "Locating";
	self._err.innerHTML = "";
	self._refBtn.innerHTML = "Refresh";
	self._useBtn.disabled = false;

	if (!self.currL) OAT.Dom.hide (self._useBtn);

	if (!self.o.manualFallback) 
	    OAT.Dom.hide (self._manualBtn);
	else
	    OAT.Dom.show (self._manualBtn);

	if (!self.o.useGeocoder) 
	    OAT.Dom.hide (self._geocodeBtn);
	else
	    OAT.Dom.show (self._manualBtn);

	self._lonI.disabled = true;
	self._latI.disabled = true;

	OAT.Event.detach (self._latI, "change", self._latLonIChangeHandler);
	OAT.Event.detach (self._lonI, "change", self._latLonIChangeHandler);

	OAT.Dom.show (self._thr);
    }

    this._setGeocodeMode = function () {
	self._uiMode = OAT.locAcquireUIMode.GEOCODE;
	self._reset();
	OAT.Dom.hide(self._useBtn);
	OAT.Dom.hide(self._thr);
	OAT.Dom.show(self._geocodeForm);
    }

    this._useHandler = function (e,s) {
	self.hide();
        self._reset();
	switch (self._uiMode) {
	case OAT.locAcquireUIMode.MANUAL:
	    var l = new OAT.Location ({lat: self._latI.value, 
				       lon: self._lonI.value});
	    self._lc.setManualLocation(l);
	    self._currL = l;
	    self._uiMode = self.o.uiMode;
	    break;
	case OAT.locAcquireUIMode.AUTO:
	case OAT.locAcquireUIMode.GEOCODE:
	    self._uiMode = self.o.uiMode;
	    self.o.useCB(self.o.cbParm, self._currL);
	}
    }

    this._latLonIChangeHandler = function () {
	if (isNaN(self._latI.value) || isNaN(self._lonI.value))
	    self._useBtn.disabled = true;
        else
	    self._useBtn.disabled = false;
    }

    this._setManualMode = function () {
	self._uiMode = OAT.locAcquireUIMode.MANUAL;
	self._reset();

	OAT.Dom.hide(self._thr);
	OAT.Dom.show(self._useBtn);
	OAT.Dom.hide(self._manualBtn);
	OAT.Dom.show(self._manualForm);

	self._lonI.disabled = false;
	self._latI.disabled = false;

	self._refBtn.innerHTML="Auto";

	OAT.Event.attach (self._latI, "change", self._latLonIChangeHandler);
	OAT.Event.attach (self._lonI, "change", self._latLonIChangeHandler);

	self._latI.focus();
    }

    this._cancelHandler = function (e,s) {
	switch (self._uiMode) {
	case OAT.locAcquireUIMode.AUTO:
	    if (self.o.useGeocoder)
		self._setGeocodeMode();
	    else if (self.o.manualFallback)
		self._setManualMode();
	    return;
	case OAT.locAcquireUIMode.GEOCODE:
	    if (self.o.manualFallback)
		self._setManualMode();
	    return;
	}
	self.hide();
	self._reset();
	if (self.o.cancelCB) self.o.cancelCB(self.o.cbParm);
    }

    this._geocodeHandler = function (e,s) {
	return;
    }

    this._geocodeRetryingH = function (e,s) {
	return;
    }

    this._geocodeFailRetryH = function (e,s) {
	return;
    }

    this._geocodeFailH = function (e,s) {
	return;
    }

    this.init = function () {
	OAT.Event.attach (self._useBtn,    "click", self._useHandler);
	OAT.Event.attach (self._refBtn,    "click", self._refreshHandler);
	OAT.Event.attach (self._cancelBtn, "click", self._cancelHandler);
        OAT.Event.attach (self._manualBtn, "click", self._manualHandler);
	OAT.Event.attach (self._geocodeBtn,"click", self._geocodeHandler);

	OAT.MSG.attach ("*","LOCATION_ACQUIRED",    self._locHandler);
	OAT.MSG.attach ("*","LOCATION_ERROR",       self._errHandler);
	OAT.MSG.attach ("*","LOCATION_TIMEOUT",     self._errHandler);
	OAT.MSG.attach ("*","GEOCODE_RESULT",       self._geocodeHandler);
	OAT.MSG.attach ("*","GEOCODE_RETRYING",     self._geocodeRetryingH);
	OAT.MSG.attach ("*","GEOCODE_FAIL",         self._geocodeFailH);
	OAT.MSG.attach ("*","GEOCODE_FAIL_RETRYING",self._geocodeFailRetryH);

	self._reset();
	
	switch (self.o.uiMode) {
	case OAT.locAcquireUIMode.AUTO:
	    OAT.Debug.log (0,'locAcquireUIMode: AUTO');
	    self.refresh();
	    break;
	case OAT.locAcquireUIMode.GEOCODE:
	    OAT.Debug.log (0,'locAcquireUIMode: GEOCODE');
	    self._setGeocodeMode();
	    break;
	case OAT.locAcquireUIMode.MANUAL:
	    OAT.Debug.log (0,'locAcquireUIMode: MANUAL');
	    self._setManualMode();
	    break;
	}
	self.show();
    }

    self.init ();
}

