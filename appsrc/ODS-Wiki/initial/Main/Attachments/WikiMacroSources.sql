-- ODS Wiki macros are simply stored function/procedures in virtuoso.
-- Macro source code excerpted from http://wiki.usnet.private/wiki/main/Main/WikiMacros:

create function WV.WIKI.MACRO_BLOGTABS (inout _data varchar, inout _context
any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsWeblogProductTourWhat][1]] |[[OdsWeblogProductTourOverview][2]] |
  [[OdsWeblogProductTourWhy][3]]  |  [[OdsWeblogProductTourHow][4]]  |
  [[OdsWeblogProductTourBasic Features][5]] |
  [[OdsWeblogProductTourAdvancedFeatures][6]]
  |[[OdsWeblogProductTourStart][7]] | [[OdsWeblogProductTourLearn][8]]
  |</div> </div>';
};

create function WV.WIKI.MACRO_BRIEFCASETABS (inout _data varchar, inout
_context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsBriefcaseProductTourWhat][1]]
  |[[OdsBriefcaseProductTourOverview][2]] |
  [[OdsBriefcaseProductTourWhy][3]]   | [[OdsBriefcaseProductTourHow][4]]
  | [[OdsBriefcaseProductTourBasic Features][5]] |
  [[OdsBriefcaseProductTourAdvancedFeatures][6]]
  |[[OdsBriefcaseProductTourStart][7]] |
  [[OdsBriefcaseProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_FEEDSTABS (inout _data varchar, inout
_context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsFeedsProductTourWhat][1]] |[[OdsFeedsProductTourOverview][2]] |
  [[OdsFeedsProductTourWhy][3]]  |  [[OdsFeedsProductTourHow][4]]  |
  [[OdsFeedsProductTourBasic Features][5]] |
  [[OdsFeedsProductTourAdvancedFeatures][6]]
  |[[OdsFeedsProductTourStart][7]] | [[OdsFeedsProductTourLearn][8]]
  |</div> </div>';
};

create function WV.WIKI.MACRO_BOOKMARKTABS (inout _data varchar, inout
_context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsBookmarkProductTourWhat][1]] |[[OdsBookmarkProductTourOverview][2]]
  | [[OdsBookmarkProductTourWhy][3]]  |  [[OdsBookmarkProductTourHow][4]]
  | [[OdsBookmarkProductTourBasic Features][5]] |
  [[OdsBookmarkProductTourAdvancedFeatures][6]]
  |[[OdsBookmarkProductTourStart][7]] | [[OdsBookmarkProductTourLearn][8]]
  |</div> </div>';
};

create function WV.WIKI.MACRO_WIKITABS (inout _data varchar, inout _context
any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsWikiProductTourWhat][1]] |[[OdsWikiProductTourOverview][2]] |
  [[OdsWikiProductTourWhy][3]]   | [[OdsWikiProductTourHow][4]]  |
  [[OdsWikiProductTourBasic Features][5]] |
  [[OdsWikiProductTourAdvancedFeatures][6]]
  |[[OdsWikiProductTourStart][7]] | [[OdsWikiProductTourLearn][8]] |</div>
  </div>';
};

create function WV.WIKI.MACRO_MAILTABS (inout _data varchar, inout _context
any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsMailProductTourWhat][1]] |[[OdsMailProductTourOverview][2]] |
  [[OdsMailProductTourWhy][3]]  | [[OdsMailProductTourHow][4]]  |
  [[OdsMailProductTourBasic Features][5]] |
  [[OdsMailProductTourAdvancedFeatures][6]]
  |[[OdsMailProductTourStart][7]] | [[OdsMailProductTourLearn][8]] |</div>
  </div>';
};

create function WV.WIKI.MACRO_GALLERYTABS (inout _data varchar, inout
_context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsGalleryProductTourWhat][1]] |[[OdsGalleryProductTourOverview][2]] |
  [[OdsGalleryProductTourWhy][3]]   | [[OdsGalleryProductTourHow][4]]  |
  [[OdsGalleryProductTourBasic Features][5]] |
  [[OdsGalleryProductTourAdvancedFeatures][6]]
  |[[OdsGalleryProductTourStart][7]] | [[OdsGalleryProductTourLearn][8]]
  |</div> </div>';
};

create function WV.WIKI.MACRO_ODSTABS (inout _data varchar, inout _context
any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsProductTourWhat][1]] |[[OdsProductTourOverview][2]] |
  [[OdsProductTourWhy][3]]  | [[OdsProductTourHow][4]]  |
  [[OdsProductTourBasic Features][5]] |
  [[OdsProductTourAdvancedFeatures][6]]  |[[OdsProductTourStart][7]] |
  [[OdsProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_DISCUSSIONTABS (inout _data varchar, inout
_context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsDiscussionProductTourWhat][1]]
  |[[OdsDiscussionProductTourOverview][2]] |
  [[OdsDiscussionProductTourWhy][3]]  |  [[OdsDiscussionProductTourHow][4]]
  | [[OdsDiscussionProductTourBasic Features][5]] |
  [[OdsDiscussionProductTourAdvancedFeatures][6]]
  |[[OdsDiscussionProductTourStart][7]] |
  [[OdsDiscussionProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_COMMUNITYTABS (inout _data varchar, inout
_context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:
  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div
  style="width: 100%; text-align: left; left; clear: none"> |
  [[OdsCommunityProductTourWhat][1]]
  |[[OdsCommunityProductTourOverview][2]] |
  [[OdsCommunityProductTourWhy][3]]  |  [[OdsCommunityProductTourHow][4]]
  | [[OdsCommunityProductTourBasic Features][5]] |
  [[OdsCommunityProductTourAdvancedFeatures][6]]
  |[[OdsCommunityProductTourStart][7]] |
  [[OdsCommunityProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_BLOGNAV (inout _data varchar, inout _context
any, inout _env any) {
  return '<div style="width: 100%; clear: both; float: none; margin-top:
  5em"><hr /></div><div id="blognav" style="width: 100%; padding: 3px;
  background: #2CBCEF; color: white; font-family: helvetica; font-size:
  10pt; text-align: left; float:none; clear:both">Copyright  (C)
  [[http://www.openlinksw.com/][OpenLink Software]] 2006 </div>';
};

create function WV.WIKI.MACRO_VSREALM (inout _data varchar, inout _context
any, inout _env any) {
  return '<div id="vsrealm" style="width: 100%;background: #000066; color:
  white; font-family: helvetica; font-size: 11pt;padding: 4px"><div
  style="width: 90%; text-align: left; left; clear: none"> EXPLORE THE
  VIRTUOSO REALMS [[VirtuosoProductWebDataManagement][Data Management &
  Integration]]  [[VirtuosoProductWebSOAPlatform][SOA Platform]]
  [[VirtuosoProductWebWeb20][Collaboration]] </div> <div style="float:
  none; clear: both"> </div> </div>';
};

create function WV.WIKI.MACRO_ODSARRLG (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/Arrow.png" alt="Arrow.png" width="40"
  height="40" />';
};

create function WV.WIKI.MACRO_ODSARR (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/Arrow-sm.jpg" alt="Arrow-sm.jpg"
  width="30" height="30" />';
};

create function WV.WIKI.MACRO_ODSSTART (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/getstarted-sm.jpg"
  alt="getstarted-sm.jpg" width="147" height="35" />';
};

create function WV.WIKI.MACRO_ODSNEXT (inout _data varchar, inout _context
any, inout _env any) {
  return ' <img src="%ATTACHURLPATH%/next-sm.jpg" alt="next-sm.jpg"
  width="93" height="36" />';
};

create function WV.WIKI.MACRO_ODSPREV (inout _data varchar, inout _context
any, inout _env any) {
  return ' <img src="%ATTACHURLPATH%/previous-sm.jpg" alt="previous-sm.jpg"
  width="105" height="34" />';
};

create function WV.WIKI.MACRO_BULSQ (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/BULSQ.jpg" alt="BULSQ.jpg" width="25"
  height="24" />';
};

create function WV.WIKI.MACRO_BULCR (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/BULCR.png" alt="BULCR.png" width="26"
  height="27" />';
};

create function WV.WIKI.MACRO_GLOBE (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/GLOBE.jpg" alt="GLOBE.jpg" width="67"
  height="67" />';
};

create function WV.WIKI.MACRO_VSDRKBLUE (inout _data varchar, inout
_context any, inout _env any) {
  return '<font color="#000066"> ';
};

create function WV.WIKI.MACRO_VSLTBLUE (inout _data varchar, inout _context
any, inout _env any) {
  return '<font color="#6699CC"> ';
};

create function WV.WIKI.MACRO_ODSTURQ (inout _data varchar, inout _context
any, inout _env any) {
  return '<font color="#0085BF">';
};

