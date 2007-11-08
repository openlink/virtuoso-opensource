function dd(txt){
  if(typeof console == 'object'){
    console.debug(txt);
  }
}
function eTarget(e)
{
 if (!e) var e = window.event
    var el = (e.target) ? e.target : e.srcElement

 return el ;
}
function buildObjByChildNodes(elm)
{
   var obj={};
   for(var i=0;i<elm.childNodes.length;i++)
   {
     obj[elm.childNodes[i].nodeName]=OAT.Xml.textValue(elm.childNodes[i]);
   }
   return obj;
};

window.ODS = {};


ODS.Preferences = {
  imagePath:"/ods/images/",
  dataspacePath:"/dataspace/",
  odsHome:"/ods/",
  svcEndpoint:"/ods_services/Http/",
  version:"08.10.2007"
}

ODS.app = {AddressBook  : {menuName:'AddressBook',icon:'images/icons/ods_ab_16.png',dsUrl:'#UID#/addressbook/'},
           Bookmarks    : {menuName:'Bookmarks',icon:'images/icons/ods_bookmarks_16.png',dsUrl:'#UID#/bookmark/'},
           Calendar     : {menuName:'Calendar',icon:'images/icons/ods_calendar_16.png',dsUrl:'#UID#/calendar/'},
           Community    : {menuName:'Community',icon:'images/icons/ods_community_16.png',dsUrl:'#UID#/community/'},
           Discussion   : {menuName:'Discussion',icon:'images/icons/apps_16.png',dsUrl:'#UID#/discussion/'},
           Polls        : {menuName:'Polls',icon:'images/icons/ods_poll_16.png',dsUrl:'#UID#/polls/'},
           Weblog       : {menuName:'Weblog',icon:'images/icons/ods_weblog_16.png',dsUrl:'#UID#/weblog/'},
           FeedManager  : {menuName:'Feed Manager',icon:'images/icons/ods_feeds_16.png',dsUrl:'#UID#/feed/'},
           Briefcase    : {menuName:'Briefcase',icon:'images/icons/ods_briefcase_16.png',dsUrl:'#UID#/briefcase/'},
           Gallery      : {menuName:'Gallery',icon:'images/icons/ods_gallery_16.png',dsUrl:'#UID#/gallery/'},
           Mail         : {menuName:'Mail',icon:'images/icons/ods_mail_16.png',dsUrl:'#UID#/mail/'},
           Wiki         : {menuName:'Wiki',icon:'images/icons/ods_wiki_16.png',dsUrl:'#UID#/wiki/'}
          }


ODS.session = function(customEndpoint){

  var self=this;

  this.sid=false;
  this.realm='wa';
  this.userName=false;
  this.userId=false;
  this.endpoint=ODS.Preferences.svcEndpoint;
  this.openId={server:false,
               delegate:false,
               sig:false,
               identity:false,
               assoc_handle:false,
               signed:false
              };
  
  if(typeof(customEndpoint)!='undefined' && length(customEndpoint))
     this.endpoint=customEndpoint;

      
  this.start=function(){
       
      var data = '';
      
      var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.isErr(xmlDoc))
                                           {
                                             resXmlNodes = OAT.Xml.xpath(xmlDoc, '/sessionStart_response/session',{});
                                             self.sid=OAT.Xml.textValue(resXmlNodes[0]);
                                             OAT.MSG.send(self,OAT.MSG.SES_TOKEN_RECEIVED,{});
                                           }
                                         };
                                         
      OAT.AJAX.POST(self.endpoint+"sessionStart", data, callback, options);
  
  }  

  this.validate=function(){
    
    if($('loginDiv').loginTab.selectedIndex==0)                                       
    {
    function showLoginErr()
    {
      $('loginErrDiv').innerHTML='';
      var warnImg=OAT.Dom.create('img',{verticalAlign:'text-bottom',paddingTop:'3px'});
      warnImg.src='images/warn_16.png';
      OAT.Dom.append([$('loginErrDiv'),warnImg,OAT.Dom.text(' Invalid Member ID or Password')]);
      return;

    }
       if($('loginUserName').value.length==0 || $('loginUserPass').value.length==0)
    {
      showLoginErr();
      return;
    }

    $('loginErrDiv').innerHTML='';
    
       var data = 'sid='+self.sid+'&realm=wa&userName='+$('loginUserName').value+'&authStr='+OAT.Crypto.sha(self.sid+$('loginUserName').value+$('loginUserPass').value);
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

                                           if(!self.isErr(xmlDoc))
                                           {
                                             self.userName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userName',{})[0]);
                                                self.userId=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userId',{})[0]);
                                             
                                             //resXmlNodes = OAT.Xml.xpath(xmlDoc, '/sessionStart_response/userName',{});
                                             OAT.MSG.send(self,OAT.MSG.SES_VALIDBIND,{});
                                           }else
                                           {
                                              showLoginErr();
                                              return;
                                           }
                                            
                                       };
       OAT.Dimmer.hide();
       nav.wait();
       OAT.AJAX.POST(self.endpoint+"sessionValidate", data, callback, optionsSynch);
    }else
    {
       function showLoginErr(errMsg)
       {
         if(typeof(errMsg)=='undefined')
            errMsg=' Invalid OpenID URL';
         $('loginErrDiv').innerHTML='';
         var warnImg=OAT.Dom.create('img',{verticalAlign:'text-bottom',paddingTop:'3px'});
         warnImg.src='images/warn_16.png';
         OAT.Dom.append([$('loginErrDiv'),warnImg,OAT.Dom.text(errMsg)]);
         return;
                                         
  }
       if($('loginOpenIdUrl').value.length==0)
       {
         showLoginErr();
         return;
       }


       $('loginErrDiv').innerHTML='';
        
       var openIdUrl=$('loginOpenIdUrl').value;

       var data = 'realm=wa&openIdUrl='+encodeURIComponent(openIdUrl);
         
       var callback = function(xmlString) {
                                              var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
       
                                              if(!self.isErr(xmlDoc))
                                              {
                                                self.openId.server=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/openIdServer_response/server',{})[0]);
                                                self.openId.delegate=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/openIdServer_response/delegate',{})[0]);
                                                if(!self.openId.server || self.openId.server.length==0)
                                                   showLoginErr(' Cannot locate OpenID server');
                                                
                                                var oidIdent=openIdUrl;
                                                if(self.openId.delegate || self.openId.delegate.length>0)
                                                   oidIdent=self.openId.delegate;

                                                var thisPage  = document.location.protocol+'//'+ document.location.host + document.location.pathname+'?oid-srv='+encodeURIComponent(self.openId.server);
                                                var trustRoot = document.location.protocol+'//'+document.location.host;

                                                var checkImmediate = self.openId.server+'?openid.mode=checkid_setup'+
                                                                                        '&openid.identity='+encodeURIComponent(oidIdent)+
                                                                                        '&openid.return_to='+encodeURIComponent(thisPage)+
                                                                                        '&openid.trust_root='+encodeURIComponent(trustRoot);
                                                document.location=checkImmediate;
                                              }else
                                              {
                                                 showLoginErr();
                                                 return;
                                              }
                                               
                                          };
       OAT.Dimmer.hide();
       nav.wait();

       OAT.AJAX.POST(self.endpoint+"openIdServer", data, callback, optionsSynch);

       
    }
  }

  this.validateSid=function(){
//    var data = 'sid='+self.sid+'&realm=wa&userName='+$('userName').value+'&authStr='+OAT.Crypto.sha(self.sid+$('userName').value+$('userPass').value);
    var data = 'sid='+self.sid+'&realm=wa';
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

                                           if(!self.isErr(xmlDoc))
                                           {
                                             self.userName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userName',{})[0]);
                                             self.userId=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userId',{})[0]);
                                             OAT.MSG.send(self,OAT.MSG.SES_VALIDBIND,{});
                                           }
                                            
                                       };
                                         
    OAT.AJAX.POST(self.endpoint+"sessionValidate", data, callback, options);
  }
  
  this.end=function(){
    
    var data = 'sid='+self.sid;
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           
                                           if(!self.isErr(xmlDoc))
                                           {
                                             //resXmlNodes = OAT.Xml.xpath(xmlDoc, '/sessionStart_response/session',{});
                                             self.sid=false;
                                             self.userName=false;
                                             self.userId=false;
                                             OAT.MSG.send(self,OAT.MSG.SES_INVALID,{});
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.endpoint+"sessionEnd", data, callback, options);
  }
  
  this.openIdVerify = function()
  {
    var uriParams=OAT.Dom.uriParams();
    
    var url=self.openId.server+'?openid.mode=check_authentication&openid.assoc_handle='+encodeURIComponent(self.openId.assoc_handle)+
                               '&openid.sig='+encodeURIComponent(self.openId.sig)+
                               '&openid.signed='+encodeURIComponent(self.openId.signed);


    var sig=self.openId.signed.split(',');
    
    for(var i=0;i<sig.length;i++)
    {
        var _key = sig[i].trim ();
        if (_key!='mode' && _key!='signed' && _key!='assoc_handle')
        {
           var _val = uriParams['openid.'+_key];
	         if (_val != '')
	         url = url + '&openid.'+_key+'='+ encodeURIComponent(_val);
	      }

    }

    var data = 'realm=wa&openIdUrl='+encodeURIComponent(url)+'&openIdIdentity='+encodeURIComponent(self.openId.identity);
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

                                           if(!self.isErr(xmlDoc))
                                           {
                                             self.sid=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/openIdCheckAuthentication_response/session',{})[0]);
                                             self.userName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/openIdCheckAuthentication_response/userName',{})[0]);
                                             self.userId=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/openIdCheckAuthentication_response/userId',{})[0]);
                                             OAT.MSG.send(self,OAT.MSG.SES_VALIDBIND,{});
                                           }
                                            
                                       };
    OAT.AJAX.POST(self.endpoint+"openIdCheckAuthentication", data, callback, optionsSynch);

  }

  this.usersGetInfo=function(users,fields,callbackFunction){
    var data ='sid='+self.sid+'&realm='+self.realm+
              '&usersStr='+encodeURIComponent(users)+'&fieldsStr='+encodeURIComponent(fields);
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.endpoint+"usersGetInfo", data, callback, options);
 
  }

  this.isErr = function (xmlDoc)
  {
    var errXmlNodes = OAT.Xml.xpath(xmlDoc, '//error_response', {});
                               
    if(errXmlNodes.length)
    {
       var errCode=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/error_response/error_code',{})[0]);
       var errMsg=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/error_response/error_msg',{})[0]);
       dd('ERROR - msg: '+errMsg+' code: '+errCode);
    }else
       return 0;
    
    return 1;
  };
  

}

ODS.Nav = function(navOptions) {
  var self = this;
  this.ods=ODS.Preferences.odsHome;
  this.leftbar=$(navOptions.leftbar);
  this.rightbar=$(navOptions.rightbar);
  this.appmenu=$(navOptions.appmenu);
  this.logindiv=false;
  this.userLogged=0;
  this.options = {
    imagePath:ODS.Preferences.imagePath
  };
  

  this.session= new ODS.session();
  this.profile={userName :false,
                userId : false,
                connections : new Array(),
                ciTab: false,
                connTab: false,
                set : function(profileId){ this.userName=false;
                                           this.userId = profileId;
                                           this.connections = new Array();
                                         }
                
               };
               
    

//  var session= new ODS.session();


  OAT.MSG.attach(self.session,OAT.MSG.SES_TOKEN_RECEIVED,function(){OAT.Event.attach($('loginBtn'),"click",self.session.validate);});
  OAT.MSG.attach(self.session,OAT.MSG.SES_VALIDBIND,function(){self.swithToLogged();});
  OAT.MSG.attach(self.session,OAT.MSG.SES_INVALID,function(){self.swithToNotLogged();});
  
  
  
  this.swithToLogged = function()
  {
    //sravniavam sas sesiata to cookies. i proveriavam 
    self.createCookie('sid',self.session.sid,1);
    self.userLogged=1;
    self.session.usersGetInfo(self.session.userId,'fullName',function(xmlDoc){self.setLoggedUserInfo(xmlDoc);});
    this.initProfile();
    this.initLeftBar();
    this.initRightBar();
    this.initAppMenu();
    OAT.Dimmer.hide();
  }  

  this.setLoggedUserInfo = function(xmlDoc)
  {
    var userDisplayName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName',{})[0]);
    
    if(userDisplayName=='')
       userDisplayName=self.session.userName;
    
    $('aUserProfile').innerHTML=userDisplayName;
    
  };

  
  this.swithToNotLogged = function()
  {
   self.userLogged=0;
   self.createCookie('sid','',1);
   document.location.search='';
//   self.loadVspx(self.ods+'sfront.vspx');
//   this.initProfile();
//   this.initLeftBar();
//   this.initRightBar();
//   this.initAppMenu();
   
   
  }  

  
  this.initAppMenu = function ()
  {
    var rootDiv=self.appmenu;

    OAT.Dom.clear(rootDiv);
    
    if(!self.session.userName)
       return;
    var appTitle=OAT.Dom.create("h3",{},'app_menu_t');
    appTitle.id='APP_MENU_T';
    var appTitleApplicationA=OAT.Dom.create("a",{paddingRight:'3px'});
    appTitleApplicationA.innerHTML='Applications';
    var appTitleEditA=OAT.Dom.create("a",{cursor:'pointer'},'lnk');
    appTitleEditA.innerHTML='edit';
    OAT.Event.attach(appTitleEditA,"click",function(){self.loadVspx(self.expandURL(self.ods+'services.vspx'));});  

    OAT.Dom.append([rootDiv,appTitle],[appTitle,appTitleApplicationA,appTitleEditA]); 

    var ulApp=OAT.Dom.create("ul");
    ulApp.id='APP_MENU';
    ulApp.className='app_menu';
    OAT.Dom.append([rootDiv,ulApp]); 
    
    var  ftApp=OAT.Dom.create('div');
    ftApp.id='APP_MENU_FT';
    ftApp.className='app_menu_ft';
    
    var ftAppA=OAT.Dom.create('a');
    ftAppA.href='javascript:void(0)';
    ftAppA.innerHTML='More...';
    OAT.Event.attach(ftAppA,"click",function(){ self.loadVspx(self.expandURL('admin.vspx'));});  
    
    OAT.Dom.append([rootDiv,ftApp],[ftApp,ftAppA]); 

    function renderAppUl(xmlDoc)
    {
       var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//installedPackages_response/application',{});
    
     
      for(var i=0;i<resXmlNodes.length;i++)
    {
       

       var packageName=OAT.Xml.textValue(resXmlNodes[i]);
       packageName=packageName.replace(' ','');
       var appOpt=ODS.app[packageName];

     var appMenuItem=OAT.Dom.create('li');
       var appMenuItemA=OAT.Dom.create('a',{cursor:'pointer'});
       appMenuItemA.packageName=packageName;
       appMenuItemA.id=packageName+'_menuItem';
      

       if(resXmlNodes[i].getAttribute('instcount')==0)
          OAT.Event.attach(appMenuItemA,"click",function(){ self.createApplication( this.packageName,self.appCreate);});  
       else
       { 
        appMenuItemA.defaultUrl=false;
        if(resXmlNodes[i].getAttribute('defaulturl')!='')
           appMenuItemA.defaultUrl=resXmlNodes[i].getAttribute('defaulturl');
           
        OAT.Event.attach(appMenuItemA,"click",function(e){ var t=eTarget(e);if(t.defaultUrl) self.loadVspx(self.expandURL(t.defaultUrl));});  
       }

     
     var appMenuItemImg=OAT.Dom.create('img')
     appMenuItemImg.className='app_icon';
       appMenuItemImg.src=appOpt.icon;
    
//exception - items that should not be show;
       if(appOpt.menuName!='Community')
       {
     OAT.Dom.append([ulApp,appMenuItem],
                    [appMenuItem,appMenuItemA],
                        [appMenuItemA,appMenuItemImg,OAT.Dom.text(' '+appOpt.menuName)]);
       }else
       {
        $('communities_menu').isInstalled=true;
    }
    
      }
    
    }
    
    self.installedPackages(renderAppUl);

  }
  
  this.appCreate = function (xmlDoc)
  {
     var packageName = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/createApplication_response/application/type',{})[0]);
     var url = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/createApplication_response/application/url',{})[0]);

     var menuObj=$(packageName+'_menuItem');

     var appMenuItemA=OAT.Dom.create('a',{cursor:'pointer'});
     appMenuItemA.packageName=packageName;
     appMenuItemA.defaultUrl=url;
     appMenuItemA.id=packageName+'_menuItem';
     appMenuItemA.innerHTML=menuObj.innerHTML;
     OAT.Event.attach(appMenuItemA,"click",function(){if(this.defaultUrl.length) self.loadVspx(self.expandURL(this.defaultUrl));});  
     
     menuObj=menuObj.parentNode;
     OAT.Dom.clear(menuObj);
     OAT.Dom.append([menuObj,appMenuItemA]);
     
     self.loadVspx(self.expandURL(url));

     self.wait();

  }

  this.initLeftBar= function ()
  {
    rootDiv=self.leftbar;
    OAT.Dom.clear(rootDiv);
    var odsHomeA=OAT.Dom.create('a',{cursor:'pointer'})
    odsHomeA.innerHTML='<img class="ods_logo" src="images/odslogosml_new.png" alt="Site Home"/>';
    if(self.session.userName)
       OAT.Event.attach(odsHomeA,"click",function(){self.loadVspx(self.expandURL(self.ods+'myhome.vspx'));});  
    else      
       OAT.Event.attach(odsHomeA,"click",function(){self.loadVspx(self.ods+'sfront.vspx');});  
     
    OAT.Dom.append([rootDiv,odsHomeA]);
  }

  this.initRightBar= function ()
  {
    
    var rootDiv=self.rightbar;
    
//Profile menu interface create START    

//Community menu interface create START    
//    var communityMenuDiv=OAT.Dom.create('div',{},'button');
//    var communityMenuUl=OAT.Dom.create('ul',{},'menu');
//    communityMenuUl.id='communities_menu';
//    var communityMenuLi=OAT.Dom.create('li');
//    var communityMenuHeadDiv=OAT.Dom.create('div',{},'menu_head');
//    var communityMenuHeadDivA=OAT.Dom.create('a',{cusor:'pointer'});
//    communityMenuHeadDivA.innerHTML='Communities';
//    var communityMenuHeadDivImg=OAT.Dom.create('img',{},'menu_dd_handle');
//    communityMenuHeadDivImg.src='images/menu_dd_handle.png'
//    communityMenuHeadDivImg.alt='V';
//    var communityMenuBodyUl=OAT.Dom.create('ul',{},'menu_dd_1st_lvl');
//    
//    OAT.Dom.append([rootDiv,communityMenuDiv],
//                   [communityMenuDiv,communityMenuUl],[communityMenuUl,communityMenuLi],
//                   [communityMenuLi,communityMenuHeadDiv,communityMenuBodyUl],[communityMenuHeadDiv,communityMenuHeadDivA,communityMenuHeadDivImg]
//                  );


    var profileMenuDiv=$('profile_menu');
    if(profileMenuDiv)
    {
       OAT.Dom.hide($('profile_menu'));
       OAT.Dom.clear($('profile_menu'));
       var profileMenuAProfile=OAT.Dom.create('a',{cursor:'pointer',paddingRight:'3px'},'menu_link profile');
       profileMenuAProfile.innerHTML='Profile';
       OAT.Event.attach(profileMenuAProfile,"click",self.showProfile);  
//       OAT.Event.attach(profileMenuAProfile,"click",function(){self.showProfile});  


       var profileMenuAProfileEdit=OAT.Dom.create('a',{cursor:'pointer'},'menu_link profile_edit shortcut');
       profileMenuAProfileEdit.innerHTML='edit';
       OAT.Event.attach(profileMenuAProfileEdit,"click",function(){self.loadVspx(self.expandURL(self.ods+'uiedit.vspx'));});  

       if(self.session.userName)
         OAT.Dom.append([profileMenuDiv,profileMenuAProfile,profileMenuAProfileEdit]);
       else
       {
         if(self.profile.userName)
            OAT.Dom.append([profileMenuDiv,profileMenuAProfile]);
       };
       OAT.Dom.show($('profile_menu'));
    }
    
    OAT.Dom.hide($('communities_menu').parentNode);
    var communityMenuBodyUl=$('communities_menu_body');

    function renderCommunityMenu(xmlDoc)
    {
      
      OAT.Dom.clear(communityMenuBodyUl);

      if(typeof($('communities_menu').isInstalled)=='indefined' || $('communities_menu').isInstalled==false)
      {
         OAT.Dom.hide($('communities_menu'));
         return;
      }

      var communities = OAT.Xml.xpath(xmlDoc, '//userCommunities_response/community',{});

      for(var i=0;i<communities.length;i++)
      {
        var communityMenuBodyLi=OAT.Dom.create('li',{},'menu_item');
        var communityMenuBodyLiA=OAT.Dom.create('a',{cursor:'pointer'});
        communityMenuBodyLiA.innerHTML=OAT.Xml.textValue(communities[i].childNodes[0]);
        communityMenuBodyLiA.homepage=OAT.Xml.textValue(communities[i].childNodes[1]);
        OAT.Event.attach(communityMenuBodyLiA,"click",function(){self.loadVspx(self.expandURL(this.homepage));});  
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi],[communityMenuBodyLi,communityMenuBodyLiA]);
      }
      

      if(self.session.userName)
      {
        var communityMenuBodyLi=OAT.Dom.create('li',{},'menu_item');
        var communityMenuBodyLiA=OAT.Dom.create('a',{cursor:'pointer'});
        communityMenuBodyLiA.innerHTML='Join community now';
        communityMenuBodyLiA.homepage='search.vspx?apps=apps&q=Community';
        OAT.Event.attach(communityMenuBodyLiA,"click",function(){self.loadVspx(self.expandURL(this.homepage));});  
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi],[communityMenuBodyLi,communityMenuBodyLiA]);

        var communityMenuBodyLi=OAT.Dom.create('li',{},'menu_item');
        var communityMenuBodyLiA=OAT.Dom.create('a',{cursor:'pointer'});
        communityMenuBodyLiA.innerHTML='Create new community';
        communityMenuBodyLiA.homepage='index_inst.vspx?wa_name=Community';
        OAT.Event.attach(communityMenuBodyLiA,"click",function(){self.loadVspx(self.expandURL(this.homepage));});  
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi],[communityMenuBodyLi,communityMenuBodyLiA]);
      }

      var communityMenu = new OAT.Menu();
      
      communityMenu.createFromUL ("communities_menu");
      
      OAT.Dom.show($('communities_menu').parentNode);

      self.wait('hide');
      return;
    }
    
    this.userCommunities(renderCommunityMenu);
    
//Community menu interface create END   
    
    
//    var msg_m = new OAT.Menu();
//    msg_m.createFromUL ("messages_menu");

  

//    var loginfoDiv = OAT.Dom.create("div")
//    loginfoDiv.id="ODS_BAR_RC";

    var loginfoDiv = $('ODS_BAR_RC');
    OAT.Dom.clear(loginfoDiv);


    var aSettings = OAT.Dom.create("a",{cursor: 'pointer'});
    OAT.Event.attach(aSettings,"click",function(){self.loadVspx(self.expandURL(self.ods+'app_settings.vspx'));});  
    aSettings.innerHTML='Settings'; 

    var aUserProfile = OAT.Dom.create("a",{cursor: 'pointer'});
    aUserProfile.id='aUserProfile'; 
    OAT.Event.attach(aUserProfile,"click",function(){self.loadVspx(self.expandURL(self.ods+'uhome.vspx?ufname='+self.session.userName));});  
    aUserProfile.innerHTML=self.session.userName; 
    
    var aLogin= OAT.Dom.create("a");
    aLogin.href='javascript:void(0)'; 
    aLogin.innerHTML='Sign In'; 
    OAT.Event.attach(aLogin,"click",this.logIn);  
    
    var aLogout= OAT.Dom.create("a");
    aLogout.href='javascript:void(0)'; 
    aLogout.innerHTML='Logout'; 
    OAT.Event.attach(aLogout,"click",self.session.end);  
    
    var aHelp= OAT.Dom.create("a");
    aHelp.target="_blank";
    aHelp.href=self.expandURL(self.ods+'help.vspx');
       
    aHelp.innerHTML='Help'; 

    if(self.userLogged)

       OAT.Dom.append([rootDiv,loginfoDiv],
                      [loginfoDiv,aSettings,aUserProfile,aLogout,aHelp])
    else
       OAT.Dom.append([rootDiv,loginfoDiv],
                      [loginfoDiv,aLogin,aHelp])
  
  }
  
  this.logIn= function ()
  {
    
    // add later #destroy previous session and session cookie#
    self.session.start();


    var loginDiv=$('loginDiv');
    
    if(!self.logindiv)
    {
        var loginDiv=OAT.Dom.create('div',{},'login_dialog');
       loginDiv.id='loginDiv';
        OAT.Dom.show($('login_page'));
        
        var loginTab=new OAT.Tab('loginPCtr');
        loginTab.add('loginT1','loginP1');
        loginTab.add("loginT2","loginP2");
        loginTab.go(0);
        
       
        OAT.Event.attach($('loginCloseBtn'),"click",OAT.Dimmer.hide);  

       OAT.Event.attach($('signupBtn'),"click",function(){OAT.Dimmer.hide();self.loadVspx(self.expandURL(self.ods+'register.vspx'));});  

        OAT.Dom.append([loginDiv,$('login_page')]);
       
        self.logindiv=loginDiv;
        self.logindiv.loginTab=loginTab;
        
    }

    
    if(!loginDiv)
    {
       loginDiv=OAT.Dom.create('div',{},'login_dialog');
       loginDiv.id='loginDiv';
       var titleDiv=OAT.Dom.create('div',{},'dlg_title');
       titleDiv.id='loginTitle';
       
       var titleTxt=OAT.Dom.create('h3');
       titleTxt.innerHTML='Sign In';
       
       var closeBtn=OAT.Dom.create("span",{cssFloat:'right',cursor:'pointer',color:'#ddf',paddingRight:'5px'})
       closeBtn.innerHTML='x';
       OAT.Event.attach(closeBtn,"click",OAT.Dimmer.hide);  
       OAT.Dom.append([titleDiv,closeBtn,titleTxt]);
       
       var errDiv=OAT.Dom.create('div');
       errDiv.id='loginErrDiv';
       errDiv.innerHTML='';
       
       var ctrlDiv=OAT.Dom.create('div',{cssClear:'left'});
       ctrlDiv.id='loginCtrl';
       
       var rowA=OAT.Dom.create('div');
       var unameLabel=OAT.Dom.create('label');
       unameLabel.htmlFor='userName';
       unameLabel.innerHTML='Member ID';
       var unameInput=OAT.Dom.create('input');
       unameInput.id="userName";

       var rowB=OAT.Dom.create('div');
       var upassLabel=OAT.Dom.create('label');
       upassLabel.htmlFor='userPass';
       upassLabel.innerHTML='Password';
       var upassInput=OAT.Dom.create('input');
       upassInput.type='password';
       upassInput.id="userPass";


       var btnDiv=OAT.Dom.create('div',{textAlign:'center'});
       var loginBtn=OAT.Dom.create('input',{margin:'20px 5px 20px 105px'});
       loginBtn.id='loginBtn';
       loginBtn.type='button';
       loginBtn.value = 'Sign In';
       
       
       var signupBtn=OAT.Dom.create('input',{margin:'20px 5px 20px 5px'});
       signupBtn.type='button';
       signupBtn.value = 'Sign Up!';
       OAT.Event.attach(signupBtn,"click",function(){OAT.Dimmer.hide;self.loadVspx(self.expandURL(self.ods+'register.vspx'));});  
      
       OAT.Dom.append([document.body,loginDiv],
                      [loginDiv,titleDiv,errDiv,ctrlDiv],
                      [ctrlDiv,rowA,rowB,btnDiv],
                      [rowA,unameLabel,unameInput],
                      [rowB,upassLabel,upassInput],
                      [btnDiv,loginBtn,signupBtn]
                     );

    }
    
    OAT.Dimmer.show(loginDiv);
    OAT.Dom.center(loginDiv,1,1);
// fix for missing cursor in FF
    if(OAT.Dom.isGecko())
    {
      $('loginUserName').style.position='fixed';
      $('loginUserName').style.marginLeft='105px';
      $('loginUserPass').style.position='fixed';
      $('loginUserPass').style.marginLeft='105px';
      $('loginOpenIdUrl').style.position='fixed';
      $('loginOpenIdUrl').style.marginLeft='105px';
    }
    
    
    $('loginUserName').focus();
    

  }
  
  this.initProfile = function()
  {
    var p=OAT.Dom.uriParams();
    if(typeof(p.profile)!='undefined' && p.profile!=self.session.userId)
    {
      self.profile.userId=p.profile;
    }else
    {
      if(!self.profile.userId)
      {
        self.profile.userName=self.session.userName;
        self.profile.userId=self.session.userId;
      }
    
    }  

    var pL=$('u_profile_l');
    var pR=$('u_profile_r');
    var pLWide=OAT.Dom.getWH(pL)[0]>0?OAT.Dom.getWH(pL)[0]:200;
    var pRWidth=OAT.Dom.getWH($('APP'))[0]-pLWide;
    pR.style.width=pRWidth+'px';
    var rWidgets=pR.getElementsByTagName("div");
    for(var i=0;i<rWidgets.length;i++)
    {
      if(OAT.Dom.isClass(rWidgets[i],'widget'))
         rWidgets[i].style.width=pRWidth-6+'px';
      
      if(OAT.Dom.isClass(rWidgets[i],'tab_deck'))
         rWidgets[i].style.width=pRWidth-8+'px';
    }

    alert
    if(!self.profile.connTab)
    {
       var connTab=new OAT.Tab('connPCtr');
       connTab.add('connT1','connP1');
       connTab.add("connT2","connP2");
       connTab.go(0);
       self.profile.connTab=connTab;
    }

    self.session.usersGetInfo(self.profile.userId,'userName,fullName,photo',function(xmlDoc2){self.updateProfile(xmlDoc2);});
    var mapOpt = {
    	            fix:OAT.MapData.FIX_ROUND1,
    	            fixDistance:20,
    	            fixEpsilon:0.5
                 }                 

    self.profile.connMap = new OAT.Map('connP2map',OAT.MapData.TYPE_G,mapOpt);
    self.profile.connMap.connLocations=new Array();
    self.profile.connMap.connData={};
    self.profile.connMap.centerAndZoom(0,0,8); /* africa, middle zoom */
    self.profile.connMap.setMapType(OAT.MapData.MAP_ORTO); /* aerial */

    OAT.Event.attach('connT2',"click",function(){self.profile.connMap.obj.checkResize();
                                                 self.profile.connMap.optimalPosition(self.profile.connMap.connLocations);
                                                });  
    
    if(!self.profile.ciTab)
    {
       var ciTab=new OAT.Tab('ciPCtr');
       ciTab.add('ciT1','ciP1');
       ciTab.add("ciT2","ciP2");
       ciTab.add("ciT3","ciP3");
       ciTab.add("ciT4","ciP4");
       ciTab.go(0);
       self.profile.ciTab=ciTab;
    }

    self.profile.ciMap = new OAT.Map('ciP4map',OAT.MapData.TYPE_G,mapOpt);
    self.profile.ciMap.homeLocation=false;
    self.profile.ciMap.workLocation=false;
    self.profile.ciMap.centerAndZoom(0,0,8); /* africa, middle zoom */
    self.profile.ciMap.obj.addControl(new GSmallMapControl());
    self.profile.ciMap.setMapType(OAT.MapData.MAP_ORTO); /* aerial */

    OAT.Event.attach('ciT4',"click",function(){self.profile.ciMap.obj.checkResize();
                                               if(self.profile.ciMap.homeLocation && self.profile.ciMap.workLocation)
                                                  self.profile.ciMap.optimalPosition(new Array(self.profile.ciMap.homeLocation,self.profile.ciMap.workLocation));
                                               else
                                                  self.profile.ciMap.centerAndZoom(50,-10,3);
                                              });  


  }
  
  this.updateProfile = function (xmlDoc)
  {
    var userProfileName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/userName',{})[0]);
    self.profile.userName=userProfileName;
    
    var userDisplayName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName',{})[0]);
    var userProfilePhoto=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/photo',{})[0]);

    if(userDisplayName=='')
       userDisplayName=self.profile.userName;


    $('userProfilePhotoName').innerHTML='<h3>'+userDisplayName+'</h3>';
    $('userProfilePhotoImg').src=userProfilePhoto ? userProfilePhoto : 'images/profile.png';
    $('userProfilePhotoImg').alt=userDisplayName;
    
    var gems=$('profileUserGems').getElementsByTagName("a");
    gems[0].href='/dataspace/'+self.profile.userName+'/about.rdf'; // foaf
    gems[1].href='/dataspace/'+self.profile.userName+'/sioc.rdf'; //sioc
    gems[2].href='http://geourl.org/near?p='+encodeURIComponent('http://'+document.location.host+'/dataspace/'+self.profile.userName); //GEOURL //http://geourl.org/near?p=http%3A//bdimitrov.lukanet.com%3A8890/dataspace/borislavdimitrov
    gems[3].href='sn_user_export.vspx?ufid='+self.profile.userId+'&ufname='+self.profile.userName;//vcard
    


    function renderConnectionsWidget(xmlDoc)
    {

      var connTP=$('connP1')
      OAT.Dom.clear(connTP);

      function attachClick(elm, connId)
      {
        OAT.Dom.attach(elm,"click",function() {self.profile.set(connId) ;self.initProfile();});
      };

      var connections = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user',{});

      for(var i=0;i<connections.length;i++)
      {

        $('connPTitleTxt').innerHTML='Connections ('+connections.length+')';

        self.profile.connections.push(OAT.Xml.textValue(connections[i].childNodes[0]));
        
        var _divC=OAT.Dom.create('div',{cursor:'pointer'},'conn');
        _divC.id='connW_'+OAT.Xml.textValue(connections[i].childNodes[0]);
//        _divC.profileId=OAT.Xml.textValue(connections[i].childNodes[0]);
        attachClick(_divC,OAT.Xml.textValue(connections[i].childNodes[0]));
        
        var tnail=OAT.Dom.create('img',{width:'40px',height:'40px'});
        tnail.src= (OAT.Xml.textValue(connections[i].childNodes[2]) ? OAT.Xml.textValue(connections[i].childNodes[2]) : 'images/profile_small.png');
        var _divCI=OAT.Dom.create('div',{},'conn_info');
        var cNameA=OAT.Dom.create('a',{cursor:'pointer'});
        cNameA.innerHTML=OAT.Xml.textValue(connections[i].childNodes[1]);
       
        OAT.Dom.append([connTP,_divC],[_divC,tnail,_divCI],[_divCI,cNameA]);
        
 
        var _lat = OAT.Xml.textValue(connections[i].childNodes[3].childNodes[0]);
        var _lon = OAT.Xml.textValue(connections[i].childNodes[3].childNodes[1]);
        if(_lat != '' && _lon != '')
        {
          self.profile.connMap.addMarker(i,_lat,_lon,
                                         tnail.src,40,40,
                                         function(marker){dd(self.profile.connMap.connData[marker.__group].id);self.profile.set(self.profile.connMap.connData[marker.__group].id) ;self.initProfile();}
                                         );
   
          self.profile.connMap.connLocations.push(new Array(_lat,_lon));
          self.profile.connMap.connData[i]={id    : OAT.Xml.textValue(connections[i].childNodes[0]),
                                            name  : cNameA.innerHTML,
                                            photo : tnail.src}
        
        }
      }
      self.profile.connMap.optimalPosition(self.profile.connMap.connLocations);
      self.wait('hide');
      return;
    }

    function renderContactInformationBlock(xmlDoc)
    {
        var titledFullname = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/title',{})[0])+' '+OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName',{})[0]);
        var photo = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/photo',{})[0]);
        var _home = OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/home',{});
        var _business = OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/organization',{});
        var _im = OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/im',{})[0];
  
  //       OAT.Dom.clear($('ciP1'));
  //       OAT.Dom.clear($('ciP2'));
         OAT.Dom.clear($('ciP3'));
  //       OAT.Dom.clear($('ciP4'));
  
        
        for(var i=0;i<_im.childNodes.length;i++)
        {
          var _em=OAT.Dom.create('em');
          _em.innerHTML=_im.childNodes[i].nodeName+': ';
          OAT.Dom.append([$('ciP3'),
                          _em,
                          OAT.Dom.text(OAT.Xml.textValue(_im.childNodes[i])),
                          OAT.Dom.create('br')
                         ])
        
        }
  
        var organization={};
        for(var i=0;i<_business[0].childNodes.length;i++)
        {
          organization[_business[0].childNodes[i].nodeName]=OAT.Xml.textValue(_business[0].childNodes[i]);
        }
        $('ciP2title').innerHTML='<a href="'+((organization.url.indexOf('http://')>=0) ?  organization.url : 'http://'+organization.url)+'">'+organization.title+'</a>';
        $('ciP2address').innerHTML = organization.address1+organization.address2;
        $('ciP2city').innerHTML    = (organization.city.length)>0 ? organization.city+', ' : organization.city;
        $('ciP2state').innerHTML   = organization.state;
        $('ciP2zip').innerHTML     = (organization.state.length+organization.zip.length)>0 ? organization.zip+', ' : ' ';
        $('ciP2country').innerHTML = organization.country;
  
  //      var organizationA=OAT.Dom.create('a');
  //      organizationA.href= (organization.url.indexOf('http://')>=0) ?  organization.url : 'http://'+organization.url;
  //      organizationA.target='_blank';
  //      organizationA.innerHTML=organization.title;
  //      OAT.Dom.append([$('ciP2'),
  //                      organizationA,
  //                      OAT.Dom.create('br'),
  //                      OAT.Dom.text(organization.address1+organization.address2),
  //                      OAT.Dom.create('br'),
  //                      OAT.Dom.text(organization.city+', '+organization.state+' '+organization.zip+', '+organization.country)
  //                     ]);
  
        var home={};
        for(var i=0;i<_home[0].childNodes.length;i++)
        {
          home[_home[0].childNodes[i].nodeName]=OAT.Xml.textValue(_home[0].childNodes[i]);
        }
        $('ciP1photo').src=photo;
        $('ciP1fn').innerHTML=titledFullname;
        $('ciP1org').innerHTML=organization.title;
        $('ciP1email').style.display='none';
        $('ciP1address').innerHTML=home.address1+home.address2;
        $('ciP1city').innerHTML= home.city.length ? home.city+', ' : '';
        $('ciP1state').innerHTML= home.state;
        $('ciP1zip').innerHTML= (home.state.length + home.zip.length)>0 ? home.zip+ ', ': home.zip;
        $('ciP1country').innerHTML=home.country;
        $('ciP1tel').style.display='none';
  
        self.profile.ciMap.centerAndZoom(home.latitude,home.longitude,8); /* africa, middle zoom */
        self.profile.ciMap.addTypeControl();
        if(home.latitude!='' && home.longitude!='')
        {
           self.profile.ciMap.homeLocation=new Array(home.latitude,home.longitude);
           self.profile.ciMap.addMarker(1,home.latitude,home.longitude,
                                        false,false,false,
                                        function(marker){var _div=OAT.Dom.create('div');
                                                         _div.innerHTML='Home location:<br/>'+home.address1+home.address2+'<br/>'+home.city+','+home.state+' '+home.zip+', '+home.country;
                                                         self.profile.ciMap.openWindow(marker,_div);});
        }
        if(organization.latitude!='' && organization.longitude!='')
        {
           self.profile.ciMap.workLocation=new Array(organization.latitude,organization.longitude);
           self.profile.ciMap.addMarker(2,organization.latitude,organization.longitude,
                                        false,false,false,
                                        function(marker){var _div=OAT.Dom.create('div');
                                                         _div.innerHTML='Work location:<br/>'+organization.title+'<br/>'+organization.address1+organization.address2+'<br/>'+  organization.city+', '+organization.state+' '+organization.zip+', '+organization.country;
                                                         self.profile.ciMap.openWindow(marker,_div);});
        }
  
  //      OAT.Dom.append([$('ciP1'),
  //                      organizationA,
  //                      OAT.Dom.create('br'),
  //                      OAT.Dom.text(organization.address1+organization.address2),
  //                      OAT.Dom.create('br'),
  //                      OAT.Dom.text(organization.city+', '+organization.state+' '+organization.zip+', '+organization.country)
  //                     ]);
  

      if(self.profile.ciMap.homeLocation && self.profile.ciMap.workLocation)
         self.profile.ciMap.optimalPosition(new Array(self.profile.ciMap.homeLocation,self.profile.ciMap.workLocation));
      else
         self.profile.ciMap.centerAndZoom(50,-10,3);

  
//      self.profile.ciMap.optimalPosition(new Array(self.profile.ciMap.homeLocation,self.profile.ciMap.workLocation));
      self.wait('hide');
      return;

   }
    
    
    
    function renderDataspaceUl(xmlDoc)
    {
      var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//installedPackages_response/application',{});
      var ulDS=$('ds_list');  
      OAT.Dom.clear(ulDS);
      
      for(var i=0;i<resXmlNodes.length;i++)
      {
       
      
       var packageName=OAT.Xml.textValue(resXmlNodes[i]);
       packageName=packageName.replace(' ','');
       var appOpt=ODS.app[packageName];

       var appDataSpaceItem=OAT.Dom.create('li');
       var appDataSpaceItemA=OAT.Dom.create('a',{cursor:'pointer'});
       appDataSpaceItemA.packageName=packageName;
       appDataSpaceItemA.href=ODS.Preferences.dataspacePath+appOpt.dsUrl.replace('#UID#',self.profile.userName);
       appDataSpaceItemA.target="_blank";

//       appDataSpaceItemA.id=packageName+'_dataSpaceItem';
//       OAT.Event.attach(appDataSpaceItemA,"click",function(){ self.createApplication( this.packageName,self.appCreate);});  

       var appDataSpaceItemImg=OAT.Dom.create('img')
       appDataSpaceItemImg.className='app_icon';
       appDataSpaceItemImg.src=appOpt.icon;
      
//exception - items that should not be show;
       if(appOpt.menuName!='Community')
       {
         OAT.Dom.append([ulDS,appDataSpaceItem],
                        [appDataSpaceItem,appDataSpaceItemA],
                        [appDataSpaceItemA,appDataSpaceItemImg,OAT.Dom.text(' '+appOpt.menuName)]);
       }
       
      }

    }

    function renderDiscussionGroups(xmlDoc)
    {
      
      var disvussionsDiv=$('discussionsCtr');
      OAT.Dom.clear(disvussionsDiv);
      
      var resXmlNodes = OAT.Xml.xpath(xmlDoc, '//userDiscussionGroups_response/discussionGroup',{});
      
      var discussionGroup={}
      for(var i=0;i<resXmlNodes.length;i++)
      {
        discussionGroup=buildObjByChildNodes(resXmlNodes[i]);

        var discussionA=OAT.Dom.create('a');
        discussionA.innerHTML=discussionGroup.name;
        discussionA.href=self.expandURL(discussionGroup.url);
        discussionA.target='_blank';
        
        if(i==0)
           OAT.Dom.append([disvussionsDiv,discussionA]);
        else
           OAT.Dom.append([disvussionsDiv,OAT.Dom.text(', '),discussionA]);
      }
    
      $('discussionsTitleTxt').innerHTML='Discussion Groups ('+(i)+')';
    }
    function renderPersonalInformationBlock(xmlDoc)
    {
      var interestsP=$('interestsCtr');
      OAT.Dom.clear(interestsP);
      var musicP=$('musicCtr');
      OAT.Dom.clear(musicP);
      
      var interests = OAT.Xml.xpath(xmlDoc, '//usersGetInfo_response/user/interests',{});
      interests=OAT.Xml.textValue(interests[0]).split('\n');
      for(var i=0; i<interests.length;i++)
      {
        if(interests[i].length)
        {
          var iArr=interests[i].split(';')

          var interestA=OAT.Dom.create('a');
          interestA.innerHTML=iArr[1];
          interestA.href=self.expandURL(iArr[0]);
          interestA.target='_blank';
          
          if(i==0)
             OAT.Dom.append([interestsP,interestA]);
          else
             OAT.Dom.append([interestsP,OAT.Dom.text(', '),interestA]);
        }
      }
      
      var music = OAT.Xml.xpath(xmlDoc, '//usersGetInfo_response/user/music',{});
      musicP.innerHTML=OAT.Xml.textValue(music[0]);


    }

    self.installedPackages(renderDataspaceUl);
    
    self.connectionsGet(self.profile.userId,'fullName,photo,homeLocation',renderConnectionsWidget);
    self.discussionGroupsGet(self.profile.userId,renderDiscussionGroups)
    self.session.usersGetInfo(self.profile.userId,'title,fullName,photo,home,homeLocation,business,businessLocation,im',function(xmlDoc3){renderContactInformationBlock(xmlDoc3);});
    self.session.usersGetInfo(self.profile.userId,'interests,music',function(xmlDoc3){renderPersonalInformationBlock(xmlDoc3);});

    if(self.session.userId!=self.profile.userId)
       self.showProfile();
    

  }
  
  this.showProfile = function()
  {
     self.wait();
     OAT.Dom.hide('vspxApp');
//     var pL=$('u_profile_l');
//     var pR=$('u_profile_r');
//     var pRWidth=OAT.Dom.getWH($('APP'))[0]-OAT.Dom.getWH(pL)[0];
//     pR.style.width=pRWidth+'px';
//     var rWidgets=pR.getElementsByTagName("div");
//     for(var i=0;i<rWidgets.length;i++)
//     {
//       if(OAT.Dom.isClass(rWidgets[i],'widget'))
//          rWidgets[i].style.width=pRWidth-6+'px';
//       
//       if(OAT.Dom.isClass(rWidgets[i],'tab_deck'))
//          rWidgets[i].style.width=pRWidth-8+'px';
//     }


     OAT.Dom.show('u_profile_l');
     OAT.Dom.show('u_profile_r');
     self.wait('hide');
  }
  
  this.loadVspx= function (url)
  {
     self.wait();
     OAT.Dom.hide('u_profile_l');
     OAT.Dom.hide('u_profile_r');

     var iframe=$('vspxApp');
     OAT.Dom.show(iframe);
     iframe.src=(url);
     
  }

  this.expandURL= function (url)
  {
    var retUrl =url;
    if(self.session.userName)
    {
      if(url.indexOf('?')>-1)
         retUrl =url+'&sid='+self.session.sid+'&realm='+self.session.realm;
      else         
         retUrl =url+'?sid='+self.session.sid+'&realm='+self.session.realm;
    }

    return retUrl;
  }
  
  
  this.wait= function (waitState)
  {
   
   if(OAT.Dimmer.root || waitState=='hide')
   {
    if(OAT.Dimmer.root)
       OAT.Dimmer.hide();
    return;
   }
   
   var waitDiv=$('waitDiv');
   if(!waitDiv)
   {
      waitDiv=OAT.Dom.create("div",{width:'32px',height:'32px',position: 'absolute',backgroundColor: '#fff'});
      waitDiv.id='waitDiv';
      
      var throbberImg=OAT.Dom.create('img');
      throbberImg.src='images/oat/throbber.gif';
      
      OAT.Dom.append([document.body,waitDiv],[waitDiv,throbberImg]);

   }

   OAT.Dimmer.show(waitDiv);
   OAT.Dom.center(waitDiv,1,1);

  }
  

  var ajaxOptions = {auth:OAT.AJAX.AUTH_BASIC,
                     onerror:function(request) { dd(request.getStatus()); }
                   }

  this.installedPackages = function (callbackFunction){
    
    var data = 'sid='+(self.session.sid ? self.session.sid : '');
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"installedPackages", data, callback, ajaxOptions);
  }


  this.createApplication = function (applicationType, callbackFunction){
    
    self.wait();
    if(applicationType=='FeedManager')
       applicationType='FeedManager';
       
    var data = 'sid='+self.session.sid+'&application='+encodeURIComponent(applicationType);
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }else
                                           {
                                              self.wait();
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"createApplication", data, callback, ajaxOptions);
  }

  this.userCommunities = function (callbackFunction){
    
    self.wait();
    var data = 'sid='+self.session.sid;
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }else
                                           {
                                              self.wait();
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"userCommunities", data, callback, ajaxOptions);
  }

  this.connectionsGet = function (userId,extraFields,callbackFunction){
    
    self.wait();
    var data = 'sid='+self.session.sid+'&userId='+userId+'&extraFields='+encodeURIComponent(extraFields);
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }else
                                           {
                                              self.wait();
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"connectionsGet", data, callback, ajaxOptions);
  }


  this.discussionGroupsGet = function (userId,callbackFunction){
    
    self.wait();
    var data = 'sid='+self.session.sid+'&userId='+userId;
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }else
                                           {
                                              self.wait();
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"userDiscussionGroups", data, callback, ajaxOptions);
  }

  this.createCookie = function (name, value, hours)
  {
    if (hours)
      {
        var date = new Date ();
        date.setTime (date.getTime () + (hours*60*60*1000));
        var expires = "; expires=" + date.toGMTString ();
      }
    else var expires = "";
  
    document.cookie = name + "=" + value + expires + "; path=/";
  }
  
  this.readCookie = function(name)
  {
    var cookiesArr = document.cookie.split (';');
  
    for (var i=0; i < cookiesArr.length; i++)
    {
      cookiesArr[i]=cookiesArr[i].trim();

      if (cookiesArr[i].indexOf (name+'=') == 0)
        return cookiesArr[i].substring (name.length+1, cookiesArr[i].length);
    }

    return false;
  }
  
  
  var uriParams=OAT.Dom.uriParams();
    
  if(typeof(uriParams.sid)!='undefined' && uriParams.sid!='')
  {
    self.session.sid=uriParams.sid;
    self.session.validateSid();
  }

  
  if(!self.session.sid && typeof(uriParams['openid.signed'])!='undefined' && uriParams['openid.signed']!='')
  {
    self.session.openId.server=uriParams['oid-srv']
    self.session.openId.sig=uriParams['openid.sig'];
    self.session.openId.identity=uriParams['openid.identity']
    self.session.openId.assoc_handle=uriParams['openid.assoc_handle']
    self.session.openId.signed=uriParams['openid.signed']

    self.session.openIdVerify()
  }

  var cookieSid=this.readCookie('sid');
  if(!self.session.sid && cookieSid)
  {
    self.session.sid=cookieSid;
    self.session.validateSid();
  }
    
     
  
  OAT.Event.attach($('vspxApp'),"load",function(){self.wait('hide');});  
  
  
  this.initLeftBar();
  this.initRightBar()
  this.initAppMenu();
  this.loadVspx(self.expandURL(self.ods+'sfront.vspx'));



}  

var navOptions ={leftbar  : 'ods_logo',
                 rightbar : 'ODS_BAR',
                 appmenu  : 'APP_MENU_C'
                }

ODSInitArray.push(initNav);

var nav=false;

var options=false;
var optionsSynch=false;

function initNav ()
{
  
  OAT.MSG.SES_TOKEN_RECEIVED = 30;
  OAT.MSG.SES_VALID          = 31;
  OAT.MSG.SES_VALIDBIND      = 32;
  OAT.MSG.SES_INVALID        = 33;
  
  
  options = {auth:OAT.AJAX.AUTH_BASIC,
             onerror:function(request) { dd(request.getStatus()); }
            };
  
  optionsSynch = {auth:OAT.AJAX.AUTH_BASIC,
                  async:false,
                  onerror:function(request) { dd(request.getStatus()); }
                 };

  var vpsize=OAT.Dom.getViewport();
  $('RT').style.width=vpsize[0]-168+'px';

  $('vspxApp').style.height=vpsize[1]-80+'px';

  nav=new ODS.Nav(navOptions);
  
  
}
