/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
 *
 *  See LICENSE file for details.
 */
var G_INCOMPAT = false;
function GScript(src)
{
//    document.write('<' + 'script src="' + src + '"' + ' type="text/javascript"><' + '/script>');
	var h = document.getElementsByTagName("head")[0];
	var s = document.createElement("script");
	s.setAttribute("src",src);
	h.appendChild(s);
}

function GBrowserIsCompatible(setBodyClass)
{
    if (G_INCOMPAT) return false;
    if (!window.RegExp) return false;

    var AGENTS = ["opera", "msie", "safari", "firefox", "netscape", "mozilla"];
    var agent = navigator.userAgent.toLowerCase();
    for (var i = 0; i < AGENTS.length; i++) {
        var agentStr = AGENTS[i];
		if (agent.indexOf(agentStr) != -1) {
		    if (setBodyClass && document.body) {
				document.body.className = agentStr;
	    	}
            var versionExpr = new RegExp(agentStr + "[ \/]?([0-9]+(\.[0-9]+)?)");
            var version = 0;
                
			if (versionExpr.exec(agent) != null) { version = parseFloat(RegExp.$1); }
            if (agentStr == "opera") return version >= 7;
            if (agentStr == "safari") return version >= 125;
			if (agentStr == "msie")	return (version >= 5.5 && agent.indexOf("powerpc") == -1);
            if (agentStr == "netscape") return version > 7;
			if (agentStr == "firefox") return version >= 0.8;
        }
    }
    return !!document.getElementById;
}

function GLoad()
{
    GAddMessages( {
  160: '\x3cH1\x3eServer Error\x3c/H1\x3eThe server encountered a temporary error and could not complete your request.\x3cp\x3ePlease try again in a minute or so.\x3c/p\x3e', 1415: '.', 1416: ',', 1547: 'mi', 1616: 'km', 10018: 'Loading...', 10021: 'Zoom In', 10022: 'Zoom Out', 10029: 'Return to the last result', 10049: 'Map', 10050: 'Satellite', 10093: 'Terms of Use', 10109: 'm', 10110: 'ft', 10111: 'Map', 10112: 'Sat', 10116: 'Hybrid', 10117: 'Hyb', 10120: 'We are sorry, but we don\x27t have maps at this zoom level for this region.\x3cp\x3eTry zooming out for a broader look.\x3c/p\x3e', 10121: 'We are sorry, but we don\x27t have imagery at this zoom level for this region.\x3cp\x3eTry zooming out for a broader look.\x3c/p\x3e', 10507: 'Pan left', 10508: 'Pan right', 10509: 'Pan up', 10510: 'Pan down', 10511: 'Show street map', 10512: 'Show satellite imagery', 10513: 'Show imagery with street names', 10806: 'Click to see this area on Google Maps', 10807: 'Traffic', 10808: 'Show Traffic', 10809: 'Hide Traffic', 10985: 'Zoom in', 10986: 'Zoom out', 11047: 'Center map here', 11089: '\x3ca href\x3d\x22javascript:void(0);\x22\x3eZoom In\x3c/a\x3e to see traffic for this region', 11259: 'Full-screen', 11751: 'Show street map with terrain', 11752: 'Style:', 11757: 'Change map style', 11758: 'Terrain', 11759: 'Ter', 11794: 'Show labels', 11303: 'Street View Help', 11274: 'To use street view, you need Adobe Flash Player version %1$d or newer.', 11382: 'Get the latest Flash Player.', 11314: 'We\x27re sorry, street view is currently unavailable due to high demand.\x3cbr\x3ePlease try again later!', 1559: 'N', 1560: 'S', 1561: 'W', 1562: 'E', 1608: 'NW', 1591: 'NE', 1605: 'SW', 1606: 'SE', 11907: 'This image is no longer available', 10041: 'Help', 0:''}
    );

    if (!true) {
        G_INCOMPAT = true;
		alert
	    	("The Google Maps API key used on this web site was registered for a different web site. You can generate a new key for this web site at http://code.google.com/apis/maps/.");
        return;
    }
        
    GLoadApi(["http://mt0.google.com/mt?n\x3d404\x26v\x3dap.69\x26hl\x3den\x26", "http://mt1.google.com/mt?n\x3d404\x26v\x3dap.69\x26hl\x3den\x26", "http://mt2.google.com/mt?n\x3d404\x26v\x3dap.69\x26hl\x3den\x26", "http://mt3.google.com/mt?n\x3d404\x26v\x3dap.69\x26hl\x3den\x26"],["http://kh0.google.com/kh?n\x3d404\x26v\x3d25\x26hl\x3den\x26", "http://kh1.google.com/kh?n\x3d404\x26v\x3d25\x26hl\x3den\x26", "http://kh2.google.com/kh?n\x3d404\x26v\x3d25\x26hl\x3den\x26", "http://kh3.google.com/kh?n\x3d404\x26v\x3d25\x26hl\x3den\x26"],["http://mt0.google.com/mt?n\x3d404\x26v\x3dapt.69\x26hl\x3den\x26", "http://mt1.google.com/mt?n\x3d404\x26v\x3dapt.69\x26hl\x3den\x26", "http://mt2.google.com/mt?n\x3d404\x26v\x3dapt.69\x26hl\x3den\x26", "http://mt3.google.com/mt?n\x3d404\x26v\x3dapt.69\x26hl\x3den\x26"],window._apiKey, "", "", true, "G", {
  public_api:true}
	     ,
	     ["http://mt0.google.com/mt?n\x3d404\x26v\x3dapp.64\x26hl\x3den\x26",
	      "http://mt1.google.com/mt?n\x3d404\x26v\x3dapp.64\x26hl\x3den\x26",
	      "http://mt2.google.com/mt?n\x3d404\x26v\x3dapp.64\x26hl\x3den\x26",
	      "http://mt3.google.com/mt?n\x3d404\x26v\x3dapp.64\x26hl\x3den\x26"]);
    if (window.GJsLoaderInit) {
	GJsLoaderInit
	    ("http://maps.google.com/intl/en_ALL/mapfiles/102/maps2" + ".api/main.js");
    }
}

function GUnload()
{
    if (window.GUnloadApi) {
	GUnloadApi();
    }
}

var _mIsRtl = false;
var _mF = [,, false, true, true, 100, 4096, "bounds_cippppt.txt",
     "cities_cippppt.txt", "local/add/flagStreetView", true, true, 400,
     true, true,, true,, true,
     "/maps/c/ui/HovercardLauncher/dommanifest.js",, true, true, false,
     false, true, true, false, true, true, true, true, true, true, true,
     true, true, false, "", 0, true, true, true, false,, true, true,, true,
     "", false, "107485602240773805043.00043dadc95ca3874f1fa", false,
     "US,AU,NZ", false, 1000, 40, "http://cbk0.google.com", false, false,
     "iw,ar", false, false];
var _mHost = "http://maps.google.com";
var _mUri = "/maps";
var _mDomain = "google.com";
var _mStaticPath = "http://maps.google.com/intl/en_ALL/mapfiles/";
var _mJavascriptVersion = "103";
var _mTermsUrl = "http://www.google.com/intl/en_ALL/help/terms_maps.html";
var _mHL = "en";
var _mGL = "";
var _mTrafficEnableApi = true;
var _mTrafficTileServerUrlBase = "http://www.google.com/mapstt";
var _mCityblockLatestFlashUrl = "http://maps.google.com/local_url?q=http://www.adobe.com/shockwave/download/download.cgi%3FP1_Prod_Version%3DShockwaveFlash&amp;dq=&amp;file=api&amp;v=2&amp;key=ABQIAAAAzr2EBOXUKnm_jVnk0OJI7xSosDVG8KKPE1-m51RBrvYughuyMxQ-i1QfUnH94QxWIa6N4U6MouMmBA&amp;s=ANYYN7manSNIV_th6k0SFvGB4jz36is1Gg";
var _mCityblockLogUsage = true;
var _mCityblockInfowindowLogUsage = false;
var _mSavedLocationsLogUsage = true;
var _mWizActions = { hyphenSep: 1, breakSep: 2, dir: 3, searchNear: 6, savePlace:9 };
var _mIdcRouterPath = "/maps/mpl/router";
var _mIdcRelayPath = "/maps/mpl/relay";
var _mIGoogleUseXSS = false;
var _mIGoogleServerUntrustedUrl = "http://maps.gmodules.com";
var _mIGoogleEt = "6PlFHAMJ";
var _mMplGGeoXml = 100;
var _mMplGPoly = 1000;
var _mMplMapViews = 100;
var _mMplGeocoding = 100;
var _mMplDirections = 100;
var _mMplEnableGoogleLinks = true;
var _mIGoogleServerTrustedUrl = "";
var _mIGoogleEt = "6PlFHAMJ";
var _mIGoogleUseXSS = false;
var _mMMEnableAddContent = true;
var _mMSEnablePublicView = true;
var _mSatelliteToken = "fzwq1JrJtfSm1b7oZd-1MP-VzpmfHbTbQ0bPsw";
var _mMapCopy = "Map data \x26#169;2008 ";
var _mSatelliteCopy = "Imagery \x26#169;2008 ";
var _mGoogleCopy = "\x26#169;2008 Google";
var _mPreferMetric = false;
var _mPanelWidth = 20;
var _mMapPrintUrl = 'http://www.google.com/mapprint';
var _mAutocompleteEnabled = true;
var _mSvgEnabled = true;
var _mSvgForced = false;
var _mLogInfoWinExp = true;
var _mLogPanZoomClks = false;
var _mLogWizard = true;
var _mLogLimitExceeded = true;
var _mLogPrefs = true;
var _mMMLogMyMapViewpoints = true;
var _mCalPopupMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var _mCalPopupDaysOfWeek =["S", "M", "T", "W", "T", "F", "S"];
var _mSXBmwAssistUrl = '';
var _mSXCarEnabled = true;
var _mSXServices = { car_bmw_at: {type: 1, make: "11390", account: "11032", system: "BMW Assist", link: "11086", group: "11383", name:"11395"}
, car_bmw_ca: {type: 1, make: "11390", account: "11032", system: "BMW Assist", link: "11086", group: "11383", name:"BMW Canada"}
, car_bmw_de: {type: 1, make: "11390", account: "11032", system: "BMW Assist", link: "11086", group: "11383", name:"11385"}
, car_bmw_it: {type: 1, make: "11390", account: "11032", system: "BMW Assist", link: "11086", group: "11383", name:"11387"}
, car_bmw_gb: {type: 1, make: "11390", account: "11032", system: "BMW Assist", link: "11086", group: "11383", name:"11386"}
, car_mercedes_us: {type: 1, make: "11391", account: "11388", system: "Mercedes-Benz Search\x26amp;Send powered by Tele Aid", link:"11394"}
, pnd_tomtom: {type: 2, make: "TomTom", system: "TomTom", link:"http://www.tomtom.com/page/tomtom-on-google-maps"}
};
var _mSXPhoneEnabled = false;
var _mMSMarker = 'Placemark';
var _mMSLine = 'Line';
var _mMSPolygon = 'Shape';
var _mMSImage = 'Image';
var _mDirectionsDragging = true;
var _mDirectionsEnableApi = true;
var _mAdSenseForMapsEnable = "true";
var _mAdSenseForMapsFeedUrl = "http://pagead2.googlesyndication.com/afmaps/ads";
var _mSesameLearnMoreUrl = "http://maps.google.com/support/bin/answer.py?answer\x3d68474\x26hl\x3den#modify";
var _mSesameSurveyLink = "Help improve this feature: \x3ca id\x3dssl\x3etake our survey\x3c/a\x3e.";
var _mSesameSurveyUrls =
    ["https://survey.google.com/wix/p1899602.aspx",
     "https://survey.google.com/wix/p1899218.aspx",
     "https://survey.google.com/wix/p1899850.aspx",
     "https://survey.google.com/wix/p1899628.aspx"];
var _mSesameMoveLearnMoreUrl = "http://maps.google.com/support/bin/answer.py?answer\x3d68474\x26hl\x3den#modify";
var _mReviewsWidgetUrl = "/reviews/scripts/annotations_bootstrap.js?hl\x3den\x26amp;gl\x3d";

function GLoadMapsScript()
{
    if (GBrowserIsCompatible()) {
    }
}

GLoadMapsScript();
OAT.Loader.featureLoaded("gmaps");
