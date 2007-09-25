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
//    document.write('<' + 'script src="' + src + '"' +' type="text/javascript"><' + '/script>');
	var h = document.getElementsByTagName("head")[0];
	var s = document.createElement("script");
	s.setAttribute("src",src);
	h.appendChild(s);
}
function GBrowserIsCompatible()
{
    if (G_INCOMPAT) return false;
    if (!window.RegExp) return false;
    var AGENTS = ["opera","msie","safari","firefox","netscape","mozilla"];
    var agent = navigator.userAgent.toLowerCase();
    for (var i = 0;
    i < AGENTS.length;
    i++)
    {
        var agentStr = AGENTS[i];
        if (agent.indexOf(agentStr) != -1)
        {
            var versionExpr = new RegExp(agentStr + "[ \/]?([0-9]+(\.[0-9]+)?)");
            var version = 0;
            if (versionExpr.exec(agent) != null)
            {
                version = parseFloat(RegExp.$1);
                
            }
            if (agentStr == "opera") return version >= 7;
            if (agentStr == "safari") return version >= 125;
            if (agentStr == "msie") return (version >= 5.5 &&agent.indexOf("powerpc") == -1);
            if (agentStr == "netscape") return version > 7;
            
        }
        
    }
    return document.getElementById;
    
}
function GLoad()
{
    if (!true)
    {
        G_INCOMPAT = true;
        alert("The Google Maps API key used on this web site was registered for a different web site. You can generate a new key for this web site at http://www.google.com/apis/maps/.");
        return;
        
    }
	GLoadApi(["http://mt0.google.com/mt?n=404&v=w2.61&","http://mt1.google.com/mt?n=404&v=w2.61&","http://mt2.google.com/mt?n=404&v=w2.61&","http://mt3.google.com/mt?n=404&v=w2.61&"], ["http://kh0.google.com/kh?n=404&v=20&","http://kh1.google.com/kh?n=404&v=20&","http://kh2.google.com/kh?n=404&v=20&","http://kh3.google.com/kh?n=404&v=20&"], ["http://mt0.google.com/mt?n=404&v=w2t.61&","http://mt1.google.com/mt?n=404&v=w2t.61&","http://mt2.google.com/mt?n=404&v=w2t.61&","http://mt3.google.com/mt?n=404&v=w2t.61&"],window._apiKey,"","",false,"G");
	if (window.GJsLoaderInit) {
	        GJsLoaderInit("http://www.google.com/mapfiles/81/maps2" +".api/main.js","http://maps.google.com/maps?file=msgs_%1$s");
        
    }
}
function GUnload()
{
    if (window.GUnloadApi)
    { GUnloadApi();  }
    
}
var _mF = [ true,true,true,true,true,400,200,true,false,false,100,4096,"bounds.txt","cities.txt" ];
var _mHost = "http://maps.google.com";
var _mUri = "/maps";
var _mDomain = "google.com";
var _mStaticPath = "http://www.google.com/intl/en_ALL/mapfiles/";
var _mTermsUrl = "http://www.google.com/intl/en_ALL/help/terms_local.html";
var _mTerms = "Terms of Use";
var _mMapMode = "Map";
var _mMapModeShort = "Map";
var _mMapError = "We are sorry, but we don\'t have maps at this zoom level for this region.\x3cp\x3eTry zooming out for a broader look.\x3c/p\x3e";
var _mSatelliteMode = "Satellite";
var _mSatelliteModeShort = "Sat";
var _mSatelliteError = "We are sorry, but we don\'t have imagery at this zoom level for this region.\x3cp\x3eTry zooming out for a broader look.\x3c/p\x3e";
var _mHybridMode = "Hybrid";
var _mHybridModeShort = "Hyb";
var _mTrafficEnableApi = true;
var _mTrafficTileServerUrlBase = "http://www.google.com/mapstt";
var _mTraffic = "Traffic";
var _mTrafficShow = "Show Traffic";
var _mTrafficHide = "Hide Traffic";
var _mCityblock = "Street View";
var _mCityblockHelp = "Street View Help";
var _mCityblockHide = "Hide Street View";
var _mCityblockLatestFlashUrl = "http://maps.google.com/local_url?q\x3dhttp://www.adobe.com/shockwave/download/download.cgi%3FP1_Prod_Version%3DShockwaveFlash\x26dq\x3d\x26file\x3dapi\x26v\x3d2.x";
var _mCityblockNew = "New!";
var _mCityblockRequiresFlash8 = "To use street view, you need Adobe Flash Player version 9 or newer.";
var _mCityblockShow = "Show Street View";
var _mCityblockTooltip = "Drag me onto a blue outlined street.\x3cbr/\x3eYou can also just click on a blue outlined street.";
var _mGetLatestFlash = "Get the latest Flash Player.";
var _mCityblockBack = "Back to street view";
var _mCityblockUsing = "Using Street View";
var _mCityblockHow = "In certain locations, you can view and navigate within street-level imagery. Here\'s how:";
var _mCityblockBlueOutlines = "Blue outlines show roads where street view is available.";
var _mCityblockIcon = "This icon shows where you are on the map. The green arrow points in the direction you\'re looking. You can drag the icon to navigate to a different location. You can also just click on a blue outlined road to go there.";
var _mCityblockNavigate = "Drag the street view to look around 360\x26deg;. Use the arrow buttons to navigate down the street. You can also use the arrow keys on the keyboard.";
var _mCityblockUnavailable = "We\'re sorry, street view is currently unavailable due to high demand.\x3cbr/\x3ePlease try again later!";
var _mCityblockLogUsage = true;
var _mCityblockApproxAddress = "Address is approximate";
var _mJavascriptVersion = "81";
var _mIdcRouterPath = "/maps/mpl/router";
var _mIdcRelayPath = "/maps/mpl/relay";
var _mIdcMaxLatencyMs = 100;
var _mIdcMaxPacketSize = 4095;
var _mIGoogleUseXSS = false;
var _mIGoogleServerTrustedUrl = "";
var _mIGoogleServerUntrustedUrl = "http://gmodules.com";
var _mIGoogleEt = "Q4qbBQZr";
var _mMplGGeoXml = 100;
var _mMplGPoly = 1000;
var _mMplMapViews = 1000;
var _mMplGeocoding = 100;
var _mWizActions = { breakSep: 2,dir: 3,searchNear: 6 };
var _mLoadingMessage = 'Loading...';
var _mTimeoutMessage = '\x3cH1\x3eServer Error\x3c/H1\x3eThe server encountered a temporary error and could not complete your request.\x3cp\x3ePlease try again in a minute or so.\x3c/p\x3e';
var _mSatelliteToken = "fzwq2gmylADNuC1J74FuxLDDDUIORWAkkCAcqw";
var _mZoomIn = "Zoom In";
var _mZoomOut = "Zoom Out";
var _mZoomSet = "Click to set zoom level";
var _mZoomDrag = "Drag to zoom";
var _mPanWest = "Pan left";
var _mPanEast = "Pan right";
var _mPanNorth = "Pan up";
var _mPanSouth = "Pan down";
var _mLastResult = "Return to the last result";
var _mMapCopy = "Map data &#169;2007 ";
var _mSatelliteCopy = "Imagery &#169;2007 ";
var _mGoogleCopy = "&#169;2007 Google";
var _mKilometers = "km";
var _mMiles = "mi";
var _mMeters = "m";
var _mFeet = "ft";
var _mPreferMetric = false;
var _mPanelWidth = 20;
var _mIwButtonFullSize = "Full-screen";
var _mTabBasics = "Address";
var _mTabDetails = "Details";
var _mDecimalPoint = '.';
var _mThousandsSeparator = ',';
var _mUsePrintLink = 'To see all the details that are visible on the screen,use the \"Print\" link next to the map.';
var _mPrintSorry = '';
var _mMapPrintUrl = 'http://www.google.com/mapprint';
var _mPrint = 'Print';
var _mAutocompleteFrom = 'from';
var _mAutocompleteTo = 'to';
var _mAutocompleteNearRe = '^(?:(?:.*?)\\s+)(?:(?:in|near|around|close to):?\\s+)(.+)$';
var _mSvgEnabled = true;
var _mSvgForced = false;
var _mStreetMapAlt = 'Show street map';
var _mSatelliteMapAlt = 'Show satellite imagery';
var _mHybridMapAlt = 'Show imagery with street names';
var _mSeeOnGoogleMaps = "Click to see this area on Google Maps";
var _mLogInfoWinExp = true;
var _mLogPanZoomClks = false;
var _mLogWizard = true;
var _mLogLimitExceeded = true;
var _mLogPrefs = true;
var _mMSHelpMarker = 'Click to place me on the map';
var _mMSHelpLine = 'Click to start drawing a line';
var _mMSHelpPolygon = 'Click to start drawing a shape';
var _mMSPlainTextWarning = 'Converting to plain text will lose some formatting. Continue?';
var _mCancel = 'Cancel';
var _mDone = 'OK';
var _mTitle = 'Title';
var _mDescription = 'Description';
var _mRichText = 'Rich text';
var _mMSMarker = 'Placemark';
var _mMSLine = 'Line';
var _mMSLineColor = 'Line color';
var _mMSWidthPixels = 'Width (pixels)';
var _mMSLineOpacity = 'Line opacity';
var _mMSDeletePoint = 'Delete this point';
var _mMSContinueLine = 'Continue this line';
var _mMSAddPoint = 'Add a point';
var _mMSPolygon = 'Shape';
var _mMSFillColor = 'Fill color';
var _mMSFillOpacity = 'Fill opacity';
var _mMSErrorCreating = 'Error creating map';
var _mMSSavedTo = 'Saved to %1$s';
var _mMSErrorSaving = 'Error saving placemark';
var _mMSSaving = 'Saving...';
var _mUntitled = 'Untitled';
var _mMSToolPointerTip = 'Select/edit map features';
var _mMSToolMarkerTip = 'Add a placemark';
var _mMSToolLineTip = 'Draw a line';
var _mMSToolPolygonTip = 'Draw a shape';
var _mMSToolImageTip = 'Add an image';
var _mMSSaveNow = 'Save';
var _mMSSaved = 'Saved';
var _mMSImage = 'Image';
var _mMSPromptImage = 'Please enter the URL to an image';
var _mMSUnsavedWarning = 'If you continue, you will lose unsaved changes.';
var _mMSEdit = 'Edit';
var _mMSDelete = 'Delete';
var _mMSCHDragLine = 'Drag to reposition this line';
var _mMSCHDragPolygon = 'Drag to reposition this shape';
var _mMSCHMovePoint = 'Drag to move this point';
var _mMSCHAddPoint = 'Drag to move this point';
var _mMSCHEndPolygon = 'Double-click to end this shape.';
var _mMSCHContPolygon = 'Click to continue drawing a shape';
var _mMSCHEndLine = 'Double-click to end this line';
var _mMSCHContLine = 'Click to continue drawing a line';
var _mMSCHMoveMarker = 'Drag to move this placemark';
var _mPlainText = 'Plain text';
var _mEditHTML = 'Edit HTML';
var _mMSHCSelectText = 'First select the text that you want to make into a link.';
var _mMSHCEnterUrl = 'Enter a URL';
var _mMSHCHuge = 'Huge';
var _mMSHCLarge = 'Large';
var _mMSHCNormal = 'Normal';
var _mMSHCSmall = 'Small';
var _mMSHCBold = 'Bold';
var _mMSHCItalic = 'Italic';
var _mMSHCUnderline = 'Underline';
var _mMSHCFont = 'Font';
var _mMSHCSize = 'Size';
var _mMSHCTextColor = 'Text Color';
var _mMSHCHighlightColor = 'Highlight Color';
var _mMSHCRemoveFormatting = 'Remove Formatting';
var _mMSHCLink = 'Link';
var _mMSHCNumberedList = 'Numbered List';
var _mMSHCBulletedList = 'Bulleted List';
var _mMSHCIndentLess = 'Indent Less';
var _mMSHCIndentMore = 'Indent More';
var _mMSHCAlignLeft = 'Align Left';
var _mMSHCAlignCenter = 'Align Center';
var _mMSHCAlignRight = 'Align Right';
var _mMSHCInsertImage = 'Insert Image';
var _mMSHCFontNormal = 'Normal';
var _mMSHCFontTimes = 'Times New Roman';
var _mMSHCFontArial = 'Arial';
var _mMSHCFontCourier = 'Courier New';
var _mMSHCFontGeorgia = 'Georgia';
var _mMSHCFontTrebuchet = 'Trebuchet';
var _mMSHCFontVerdana = 'Verdana';
var _mMSDeleteMarkerConfirm = 'Are you sure you want to delete this placemark?';
var _mMSDeleteLineConfirm = 'Are you sure you want to delete this line?';
var _mMSDeletePolygonConfirm = 'Are you sure you want to delete this shape?';
var _mMSAbandonChangesConfirm = 'Are you sure you want to abandon unsaved changes to your map?';
var _mMSColor = 'Color';
var _mMSOpacity = 'Opacity';
var _mMSPolygonIsFilled = 'Filled?';
var _mMSAdvanced = 'Advanced';
var _mMSBasic = 'Basic';
var _mMSLineWidthPixels = 'Line width (pixels)';
var _mMSProperties = 'Properties';
var _mMSMapNotExist = 'This map does not exist.';
var _mMSEditTitle = 'Edit title/settings';
var _mMSNew = 'Create new map';
var _mMSMyMaps = 'My Maps';
var _mMSNoContact = 'Unable to contact server.';
var _mMSLastSaved = 'Last saved at %1$s';
var _mMSEditLineStyle = 'Edit line style';
var _mMSConvertToShape = 'Convert to filled shape';
var _mMSEditShapeStyle = 'Edit shape style';
var _mMSPhoto = 'Photo';
var _mMSDescriptionTooLong = 'Maximum character length exceeded.';
var _mYouAreNoLongerSignedIn = 'You are no longer signed in to your Google Account.';
var _mPleaseSignIn = 'Please sign in';
var _mMSLogInToSaveMap = 'To save your map, please sign in as %1$s';
var _mTechnicalDifficulties = 'Sorry, we\'re having technical difficulties.\x3cbr /\x3e(Error code %1$d)';
var _mUnableToSave = 'Unable to save.';
var _mViewOnly = 'View only';
var _mMSPublic = 'Public';
var _mMSUnlisted = 'Unlisted';
var _mMSIncludeInSearchResults = 'Public maps are included in search results.';
var _mMSPublicUnlistedExplainTxt = 'Learn more';
var _mMSPublicUnlistedExplainHref = 'http://maps.google.com/help/maps/userguide/index.html#public';
var _mMSCollaborate = 'Collaborate';
var _mMSInvite = 'Invite collaborators';
var _mMSSeparateEmails = 'Separate email addresses with commas';
var _mMSAllowAnyoneEdit = 'Allow anyone to collaborate';
var _mMSInvitePeople = 'Invite these people';
var _mMSCollaborators = 'Collaborators';
var _mMSCanInviteOthers = 'Collaborators can invite more people.';
var _mMSTurnOff = 'Turn off';
var _mMSRemoveCollaborator = 'Remove';
var _mMSEmailCollaborators = 'Email collaborators';
var _mMenuZoomIn = 'Zoom in';
var _mMenuZoomOut = 'Zoom out';
var _mMenuCenterMap = 'Center map here';
var _mMSClearSearchResults = 'Clear search results';
var _mMSSaveToMyMaps = 'Save to My Maps';
var _mMenuAddDestination = 'Add a destination';
var _mMenuRemoveDestination = 'Remove this destination';
var _mTransitV2 = true;
var _mDirectionsDragging = false;
var _mMMSignInToView = '\x3ca href\x3d\"%1$s\"\x3eSign in\x3c/a\x3e to view my existing bookmarks';
var _mDirectionsEnableApi = true;

function GLoadMapsScript()
{
    if (GBrowserIsCompatible())
    {
        
    }
    
}
GLoadMapsScript();
OAT.Loader.featureLoaded("gmaps");
