function dd(txt){
  if(typeof console == 'object'){
    console.debug(txt);
  }
}

window.ODS = {};

ODS.Preferences = {
  imagePath:"/ods/images/",
  dataspacePath:"/dataspace/",
  odsHome:"/ods/",
  svcEndpoint:"/ods_services/Http/",
  version:"08.10.2007",
}

ODS.app = {AddressBook  : {menuName:'AddressBook',icon:'images/icons/ods_ab_16.png'},
           Bookmarks    : {menuName:'Bookmarks',icon:'images/icons/ods_bookmarks_16.png'},
           Calendar     : {menuName:'Calendar',icon:'images/icons/ods_calendar_16.png'},
           Community    : {menuName:'Community',icon:'images/icons/ods_community_16.png'},
           Discussion   : {menuName:'Discussion',icon:'images/icons/apps_16.png'},
           Polls        : {menuName:'Polls',icon:'images/icons/ods_poll_16.png'},
           Weblog       : {menuName:'Weblog',icon:'images/icons/ods_weblog_16.png'},
           FeedManager  : {menuName:'Feed Manager',icon:'images/icons/ods_feeds_16.png'},
           Briefcase    : {menuName:'Briefcase',icon:'images/icons/ods_briefcase_16.png'},
           Gallery      : {menuName:'Gallery',icon:'images/icons/ods_gallery_16.png'},
           Mail         : {menuName:'Mail',icon:'images/icons/ods_mail_16.png'},
           Wiki         : {menuName:'Wiki',icon:'images/icons/ods_wiki_16.png'}
          }


ODS.session = function(customEndpoint){

  var self=this;

  this.sid=false;
  this.realm='wa';
  this.userName=false;
  this.endpoint=ODS.Preferences.svcEndpoint;

  
  if(typeof(customEndpoint)!='undefined' && length(customEndpoint))
     this.endpoint=customEndpoint;

      
  var options = {auth:OAT.AJAX.AUTH_BASIC,
                 onerror:function(request) { dd(request.getStatus()); }
                }

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
    
    function showLoginErr()
    {
      $('loginErrDiv').innerHTML='';
      var warnImg=OAT.Dom.create('img',{verticalAlign:'text-bottom',paddingTop:'3px'});
      warnImg.src='images/warn_16.png';
      OAT.Dom.append([$('loginErrDiv'),warnImg,OAT.Dom.text(' Invalid Member ID or Password')]);
      return;

    }
    if($('userName').value.length==0 || $('userPass').value.length==0)
    {
      showLoginErr();
      return;
    }

    $('loginErrDiv').innerHTML='';
    
    var data = 'sid='+self.sid+'&realm=wa&userName='+$('userName').value+'&authStr='+OAT.Crypto.sha(self.sid+$('userName').value+$('userPass').value);
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

                                           if(!self.isErr(xmlDoc))
                                           {
                                             self.userName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userName',{})[0]);
                                             
                                             //resXmlNodes = OAT.Xml.xpath(xmlDoc, '/sessionStart_response/userName',{});
                                             OAT.MSG.send(self,OAT.MSG.SES_VALIDBIND,{});
                                           }else
                                           {
                                              showLoginErr();
                                              return;
                                           }
                                            
                                       };
                                         
    OAT.AJAX.POST(self.endpoint+"sessionValidate", data, callback, options);
  }
  this.validateSid=function(){
//    var data = 'sid='+self.sid+'&realm=wa&userName='+$('userName').value+'&authStr='+OAT.Crypto.sha(self.sid+$('userName').value+$('userPass').value);
    var data = 'sid='+self.sid+'&realm=wa';
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

                                           if(!self.isErr(xmlDoc))
                                           {
                                             self.userName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userName',{})[0]);
                                             
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
                                             OAT.MSG.send(self,OAT.MSG.SES_INVALID,{});
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.endpoint+"sessionEnd", data, callback, options);
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
  this.userLogged=0;
  this.options = {
    imagePath:ODS.Preferences.imagePath
  };
  

  this.session= new ODS.session();
//  var session= new ODS.session();


  OAT.MSG.attach(self.session,OAT.MSG.SES_TOKEN_RECEIVED,function(){OAT.Event.attach($('loginBtn'),"click",self.session.validate);});
  OAT.MSG.attach(self.session,OAT.MSG.SES_VALIDBIND,function(){self.swithToLogged();});
  OAT.MSG.attach(self.session,OAT.MSG.SES_INVALID,function(){self.swithToNotLogged();});
  
  
  
  this.swithToLogged = function()
  {
    //sravniavam sas sesiata to cookies. i proveriavam 
    self.createCookie('sid',self.session.sid,1);
    self.userLogged=1;
    self.session.usersGetInfo(self.session.userName,'fullName',function(xmlDoc){self.setLoggedUserInfo(xmlDoc);});
    this.initLeftBar();
    this.initRightBar();
    this.initAppMenu();
    OAT.Dimmer.hide();
  }  

  this.setLoggedUserInfo = function(xmlDoc)
  {
    var userDisplayName=OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/fullName',{});
    if(userDisplayName.length)
       userDisplayName=OAT.Xml.textValue(userDisplayName);
    else
       userDisplayName='';
    
    if(userDisplayName=='')
       userDisplayName=self.session.userName;
    
    $('aUserProfile').innerHTML=userDisplayName;
  };

  this.swithToNotLogged = function()
  {
   self.userLogged=0;
   self.session.sid=false;
   self.session.userName=false;
   self.createCookie('sid','',1);
   self.loadVspx(self.ods+'sfront.vspx');
   this.initLeftBar();
   this.initRightBar();
   this.initAppMenu();
   
   
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
      

       if(resXmlNodes[i].attributes.instcount.value==0)
          OAT.Event.attach(appMenuItemA,"click",function(){ self.createApplication( this.packageName,self.appCreate);});  
       else
       { 
        appMenuItemA.defaultUrl=resXmlNodes[i].attributes.defaulturl.value;
        OAT.Event.attach(appMenuItemA,"click",function(){if(this.defaultUrl.length) self.loadVspx(self.expandURL(this.defaultUrl));});  
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
    OAT.Dom.clear(rootDiv);
    
//    var comm_m = new OAT.Menu();
//    comm_m.createFromUL ("communities_menu");
//    
//    var conn_m = new OAT.Menu();
//    conn_m.createFromUL ("connections_menu");
//    
//    var msg_m = new OAT.Menu();
//    msg_m.createFromUL ("messages_menu");

  
//    if($('ODS_BAR_RC'))
//       OAT.Dom.unlink($('ODS_BAR_RC'));


    var loginfoDiv = OAT.Dom.create("div")
    loginfoDiv.id="ODS_BAR_RC";


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
    
    if(!loginDiv)
    {
       loginDiv=OAT.Dom.create('div');
       loginDiv.id='loginDiv';
       loginDiv.className='login_dialog';

       var titleDiv=OAT.Dom.create('div');
       titleDiv.id='loginTitle';
       titleDiv.className='dlg_title';
       
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
//       OAT.Event.attach(loginBtn,"click",OAT.Dimmer.hide);  
       
       
       var signupBtn=OAT.Dom.create('input',{margin:'20px 5px 20px 5px'});
       signupBtn.type='button';
       signupBtn.value = 'Sign Up!';
       OAT.Event.attach(signupBtn,"click",OAT.Dimmer.hide);  
      
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

  }
  
  this.loadVspx= function (url)
  {
     self.wait();
     var iframe=$('vspxApp');
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
  
  
  this.wait= function ()
  {
   
   if(OAT.Dimmer.root)
   {
    OAT.Dimmer.hide()
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
    if(applicationType='FeedManager')
       applicationType='FeedManager';
       
    var data = 'sid='+self.session.sid+'&application='+applicationType;
      
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
  
  var cookieSid=this.readCookie('sid');
  if(cookieSid)
  {
    self.session.sid=cookieSid;
    self.session.validateSid();
  }
    
     
  
  OAT.Event.attach($('vspxApp'),"load",function(){self.wait();});  
  this.initLeftBar();
  this.initRightBar()
  this.initAppMenu();



}  

var navOptions ={leftbar  : 'ods_logo',
                 rightbar : 'ODS_BAR',
                 appmenu  : 'APP_MENU_C'
                }

ODSInitArray.push(initNav);

var nav=false;
function initNav ()
{
  
  OAT.MSG.SES_TOKEN_RECEIVED = 30;
  OAT.MSG.SES_VALID          = 31;
  OAT.MSG.SES_VALIDBIND      = 32;
  OAT.MSG.SES_INVALID        = 33;
  
  
  var vpsize=OAT.Dom.getViewport();
  $('RT').style.width=vpsize[0]-150+'px';
  $('vspxApp').style.height=vpsize[1]-80+'px';

  var nav=new ODS.Nav(navOptions);
  
  
}
