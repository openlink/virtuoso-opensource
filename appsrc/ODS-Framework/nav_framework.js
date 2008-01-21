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

function onEnterDown(e)
{
      if(!e) return;

      var keycode = (window.event) ? window.event.keyCode : e.which;

      if (keycode == 13)
      {
          var t=eTarget(e);
          if(typeof(t.callback) == "function")
             t.callback(e);
          return false;
      }
      else
        return true;
}

function buildObjByAttributes(elm)
{
   var obj={};
   for(var i=0;i<elm.attributes.length;i++)
   {
       obj[elm.attributes[i].nodeName]=OAT.Xml.textValue(elm.attributes[i]);
   }
   return obj;
};

function buildObjByChildNodes(elm)
{
   var obj={};
   for(var i=0;i<elm.childNodes.length;i++)
   {
      var pName=elm.childNodes[i].nodeName;
      var pValue=OAT.Xml.textValue(elm.childNodes[i]);
      var pAttrib=elm.childNodes[i].attributes;

     if( !(pName=='#text' && pValue=='\n') )
     {   
        if(typeof(obj[pName])=='undefined')
           obj[pName]=pValue;
        else
        { 
          var tmpObj=false;
          if(!(obj[pName] instanceof Array))
          {
            tmpObj=obj[pName];
            obj[pName]=new Array();
            obj[pName].push(tmpObj);
            obj[pName].push(pValue);
          }else
            obj[pName].push(pValue);

        }
         if(pAttrib.length>0)
         {
           var tmpVal=false;
           if((obj[pName] instanceof Array))
           {
            obj[pName][(obj[pName].length-1)]={};
            obj[pName][(obj[pName].length-1)]['value']=pValue;
           }
           else
           {
            obj[pName]={};
            obj[pName]['value']=pValue;
           }
           
           for(var k=0;k<pAttrib.length;k++)
           {
             if((obj[pName] instanceof Array))
                 obj[pName][(obj[pName].length-1)]['@'+pAttrib[k].nodeName]=OAT.Xml.textValue(pAttrib[k]);
             else
                 obj[pName]['@'+pAttrib[k].nodeName]=OAT.Xml.textValue(pAttrib[k]);
           }
         }

     }
   }
   return obj;
};

function replaceChild(newElm,oldElm)
{
   if(typeof(newElm)=='undefined' || typeof(oldElm)=='undefined' || typeof(oldElm.parentNode)=='undefined') return;

   OAT.Dom.hide(oldElm);
   oldElm.parentNode.insertBefore(newElm, oldElm);
   OAT.Dom.unlink(oldElm);
    
   return;
}

function inverseSelected(parentDiv)
{
  if(typeof(parentDiv)=='undefined') return;
  
  var inputCtrls=parentDiv.getElementsByTagName('input');
  
  for(var i=0; i<inputCtrls.length;i++)
  {
    if(inputCtrls[i].type=='checkbox')
       inputCtrls[i].checked= inputCtrls[i].checked ? false : true;
  } 
}
OAT.Preferences.imagePath="/ods/images/oat/";
OAT.Preferences.stylePath="/ods/";

window.ODS = {};

ODS.Preferences = {
  imagePath:"/ods/images/",
  dataspacePath:"/dataspace/",
  odsHome:"/ods/",
  svcEndpoint:"/ods_services/Http/",
  activitiesEndpoint:"/activities/feeds/activities/user/",
  version:"11.01.2008"
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
           Wiki             : {menuName:'Wiki',icon:'images/icons/ods_wiki_16.png',dsUrl:'#UID#/wiki/'},
           InstantMessenger : {menuName:'Instant Messenger',icon:'images/icons/ods_wiki_16.png',dsUrl:'#UID#/IM/'},
           eCRM             : {menuName:'eCRM',icon:'images/icons/apps_16.png',dsUrl:'#UID#/ecrm/'}
          };
ODS.ico = {addressBook      : {alt:'AddressBook',icon:'images/icons/ods_ab_16.png'},
           bookmarks        : {alt:'Bookmarks',icon:'images/icons/ods_bookmarks_16.png'},
           calendar         : {alt:'Calendar',icon:'images/icons/ods_calendar_16.png'},
           community        : {alt:'Community',icon:'images/icons/ods_community_16.png'},
           discussion       : {alt:'Discussion',icon:'images/icons/apps_16.png'},
           polls            : {alt:'Polls',icon:'images/icons/ods_poll_16.png'},
           weblog           : {alt:'Weblog',icon:'images/icons/ods_weblog_16.png'},
           feeds            : {alt:'Feed Manager',icon:'images/icons/ods_feeds_16.png'},
           briefcase        : {alt:'Briefcase',icon:'images/icons/ods_briefcase_16.png'},
           gallery          : {alt:'Gallery',icon:'images/icons/ods_gallery_16.png'},
           mail             : {alt:'Mail',icon:'images/icons/ods_mail_16.png'},
           wiki             : {alt:'Wiki',icon:'images/icons/ods_wiki_16.png'},
           system           : {alt:'ODS',icon:'images/icons/apps_16.png'},
           instantmessenger : {alt:'InstantMessenger',icon:'images/icons/ods_im_16.png'}
          };

ODS.paginator = function(iSet,containerTop,containerBottom,callback,customItemsPerPage){

    var self=this;

		this.elmTop    = $(containerTop);
		this.elmBottom = $(containerBottom);

		if (!self.elmTop && !self.elmBottom) return;

    this.totalItems   = iSet.length;
    this.pages        = false;
    this.currentPage  = false;
    this.startIndex   = false;
    this.endIndex     = false;
    this.iSet         = iSet;
    this.currenISet   = new Array();
    this.idTop        = typeof(self.elmTop.id)!='undefined' ? self.elmTop.id : 'pagerTop';
    this.idBottom     = typeof(self.elmBottom.id)!='undefined' ? self.elmBottom.id : 'pagerBottom';

    this.itemsPerPage = 5;
    if(typeof(customItemsPerPage)=='number')
    {
      this.itemsPerPage=customItemsPerPage;
    }else if(typeof(customItemsPerPage)!='undefined' && !isNaN(parseInt(customItemsPerPage,10)))
    {
      this.itemsPerPage=parseInt(customItemsPerPage,10);
    }
    
    this.first         = function()
                        {
                          if(self.currentPage==1 ) return;

                          self.go(1);                        
                        };
    this.last          = function()
                        {
                          if(self.currentPage==(self.pages) ) return;

                          self.go(self.pages);                        
                        };
    this.prev         = function()
                        {
                          if(self.currentPage==1) return;

                          self.go(self.currentPage - 1);                        
                        };
    this.next         = function()
                        {
                          if(self.currentPage==(self.pages)) return;

                          self.go(self.currentPage + 1);                        
                        };

    this.go           = function(pageNum)
                        {
                          if( typeof(pageNum)!='number' || pageNum<0) return;
 
                          if( this.totalItems==0)
                          {
                            self.pages        = false;
                            self.currentPage  = false;
                            self.startIndex   = false;
                            self.endIndex     = false;
                          }else if( self.totalItems<=self.itemsPerPage)
                          {
                            self.pages        = 1;
                            self.currentPage  = 1;
                            self.startIndex   = 1;
                            self.endIndex     = self.totalItems;
                          }else
                          {
                            self.pages=Math.ceil(self.totalItems/self.itemsPerPage);
                            
                            var startIndex=pageNum*self.itemsPerPage-(self.itemsPerPage-1);
                            if (startIndex>this.totalItems) startIndex=this.totalItems;
                            
                            var endIndex=startIndex+(self.itemsPerPage-1);
                            if (endIndex>this.totalItems) endIndex=this.totalItems;
                            
                            self.startIndex=startIndex;
                            self.endIndex=endIndex;
                            
                            self.currenISet=new Array();
                            var i=0;
                            for(var idx=startIndex;idx<=endIndex;idx++)
                            {
                              self.currenISet[i]=self.iSet[idx];
                              i++;
                            }
                            
                            self.currentPage=pageNum;
                          }
                          
                          
                          if(self.elmTop)
                          {
                            var newElmTop=self.paginatorCtrl(self.idTop);
                            replaceChild(newElmTop,self.elmTop)
                            self.elmTop=newElmTop;
                          }
                          
                          if(self.elmBottom)
                          {
                            var newElmBottom=self.paginatorCtrl(self.idBottom);
                            replaceChild(newElmBottom,self.elmBottom)
                            self.elmBottom=newElmBottom;

                          }
                          
                          if(typeof(callback)=='function')
                             callback(self);
                          
                        };
   this.paginatorCtrl = function (divId)
   {
      var settings = { first     : {txt:'first',txtAlt:'First page',imgE:'p_first.png',imgD:'p_first_gr.png'},
                       prev      : {txt:'prev',txtAlt:'Previous page',imgE:'p_prev.png',imgD:'p_prev_gr.png'},
                       next      : {txt:'next',txtAlt:'Next page',imgE:'p_next.png',imgD:'p_next_gr.png'},
                       last      : {txt:'last',txtAlt:'Last page',imgE:'p_last.png',imgD:'p_last_gr.png'},
                       skinBase  : 'images/skin/pager/'
                     };

      function elmCtrl(elmType,disabled)
      {
         
         if(typeof(settings[elmType])=='undefined') return false;

         var isD=0;
         if(typeof(disabled)!=undefined && disabled==1)
             isD=1;
         
         var elmA=false;

         if(isD)
         {
            elmA=OAT.Dom.create('a');
            var elmImg=OAT.Dom.create('img');
            elmImg.src=settings.skinBase+settings[elmType].imgD;
            elmImg.alt=settings[elmType].txtAlt;
         }else
         {
            elmA=OAT.Dom.create('a',{cursor:'pointer'});
            elmA.action=elmType;
            OAT.Event.attach(elmA,"click",function(e){var t=eTarget(e);self[t.action]();});  
            var elmImg=OAT.Dom.create('img');
            elmImg.action=elmType;
            elmImg.src=settings.skinBase+settings[elmType].imgE;
            elmImg.alt=settings[elmType].txtAlt;

         }

         OAT.Dom.append([elmA,elmImg,OAT.Dom.text(settings[elmType].txt)]);
         
         return elmA;
     }
      
      var pagerDiv=OAT.Dom.create('div',{},'pager');
      pagerDiv.id=divId;
      pagerDiv.paginator=self;
      
      
      if(self.totalItems>1)
      {
        var resultsTxt='Results '+self.startIndex+' - '+self.endIndex+' of '+self.totalItems +':';
      }else
        var resultsTxt='Results 0';

      var firstA=elmCtrl('first',1);
      var prevA=elmCtrl('prev',1);
      var nextA=elmCtrl('next',1);
      var lastA=elmCtrl('last',1);

      if(self.pages>1)
      {
        if(self.currentPage>1)
        {
           firstA=elmCtrl('first');
           prevA=elmCtrl('prev');
        }
        if(self.currentPage<self.pages)
        {
          nextA=elmCtrl('next');
          lastA=elmCtrl('last');
        }
      }

      OAT.Dom.append([pagerDiv,OAT.Dom.text(resultsTxt),firstA,prevA,nextA,lastA]);

      return pagerDiv;
   }

   this.first();
}
ODS.session = function(customEndpoint){

  var self=this;

  this.sid=false;
  this.realm='wa';
  this.userName=false;
  this.userId=false;
  this.connections   = false;
  this.connectionsId = false;

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
    
    function showLoginErr(errMsg)
    {
        if(typeof(nav.showLoginErr) == "function")
    {
          if(typeof(errMsg)!='undefined')
             nav.showLoginErr(errMsg);
          else
             nav.showLoginErr();
        }
        else if(typeof(errMsg)!='undefined')
           alert(errMsg);
      return;
    }

    if($('loginDiv').loginTab.selectedIndex==0)                                       
    {
       if($('loginUserName').value.length==0 || $('loginUserPass').value.length==0)
    {
      showLoginErr();
      return;
    }

    
       var data = 'sid='+self.sid+'&realm=wa&userName='+$('loginUserName').value+'&authStr='+OAT.Crypto.sha(self.sid+$('loginUserName').value+$('loginUserPass').value);
      
    var callback = function(xmlString) {

                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);

                                           if(!self.isErr(xmlDoc))
                                           {
                                             self.userName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userName',{})[0]);
                                                self.userId=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/sessionValidate_response/userId',{})[0]);
                                             
                                                $('loginErrDiv').innerHTML='';
                                             //resXmlNodes = OAT.Xml.xpath(xmlDoc, '/sessionStart_response/userName',{});
                                             OAT.MSG.send(self,OAT.MSG.SES_VALIDBIND,{});
                                           }else
                                           {
                                                 OAT.MSG.send(self,OAT.MSG.SES_INVALID,{retryLogIn:true});
                                           }
                                            
                                       };
       OAT.Dimmer.hide();
       nav.wait();
       OAT.AJAX.POST(self.endpoint+"sessionValidate", data, callback, optionsSynch);
    }else
    {
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
                                                 nav.wait('hide');
                                                 showLoginErr('Invalid OpenID URL');
                                                 nav.logIn();
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
                                           }else
                                           {
                                             self.sid=false;
                                             OAT.MSG.send(self,OAT.MSG.SES_INVALID,{});
                                             
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
                                             self.sid=false;
                                             self.userName=false;
                                             self.userId=false;
                                             OAT.MSG.send(self,OAT.MSG.SES_INVALID,{sessionEnd:true});
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
                                           }else
                                           {
                                             dd($('loginErrDiv'));
//                                             $('loginErrDiv').innerHTML='';
//                                             var warnImg=OAT.Dom.create('img',{verticalAlign:'text-bottom',paddingTop:'3px'});
//                                             warnImg.src='images/warn_16.png';
//                                             var errMsg=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/error_response/error_msg',{})[0]);
//                                             
//                                             OAT.Dom.append([$('loginErrDiv'),warnImg,OAT.Dom.text(' '+errMsg)]);
//                                             
//                                             nav.logIn();
                                             return;
                                            
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
       return 1;
    }else
       return 0;
    
    return 1;
  };
  
  this.connectionAdd = function (connectionId,connectionFullName)
  {
    var connection = {};
    connection[connectionId]=connectionFullName;
    self.connections.push(connection);
    self.connectionsId.push(connectionId);
  };

  this.connectionRemove = function(connectionId)
  {
    var arrPos=self.connectionsId.find(connectionId);
    
    if(arrPos>-1)
    {
      var newArr = new Array();
      newArr=newArr.concat(self.connectionsId.slice(0,arrPos));
      newArr=newArr.concat(self.connectionsId.slice(arrPos+1,self.connectionsId.length));

      self.connectionsId=newArr;

      for (var i=0;i<self.connections.length;i++)
      {
           var done=false;
           for(connId in self.connections[i])
           {
            if(connId==connectionId)
            {
               var newArr=new Array();
               newArr=newArr.concat(self.connections.slice(0,i));
               newArr=newArr.concat(self.connections.slice(i+1,self.connections.length));
             
               self.connections=newArr;
               done=true;
            }
           };
           if(done) break;
      }
    }
  };
  

}

ODS.Nav = function(navOptions) {
  var self = this;
  this.ods=ODS.Preferences.odsHome;
  this.dataspace=ODS.Preferences.dataspacePath;
  this.uriqaDefaultHost=false;
  this.leftbar=$(navOptions.leftbar);
  this.rightbar=$(navOptions.rightbar);
  this.appmenu=$(navOptions.appmenu);
  this.logindiv=false;
  this.msgDock=false;
  this.userLogged=0;
  this.options = {
    imagePath:ODS.Preferences.imagePath
  };
  this.ui={};
//  this.defaultAction=false;

  this.session= new ODS.session();
  this.profile={userName :false,
                userId : false,
                userFullName : false,
                connections : new Array(),
                ciTab: false,
                ciMap: false,
                connTab: false,
                msgTab       : false,
                show         : false,
                set : function(profileId){ this.userName=false;
                                           this.userId = profileId;
                                           userFullName = false;
                                           this.connections = new Array();
                                         }
                
               };
  this.connections={userId : false,
                    show   : false
                   };            
  this.searchObj ={qStr : false,
                   map  : false,
                   tab  : false
                  };
             
               
  OAT.MSG.attach(self.session,OAT.MSG.SES_TOKEN_RECEIVED,function(){OAT.Event.attach($('loginBtn'),"click",self.session.validate);
                                                                    $('loginUserPass').tokenReceived=true;
                                                                    $('loginOpenIdUrl').tokenReceived=true;
                                                                   });
  OAT.MSG.attach(self.session,OAT.MSG.SES_VALIDBIND,
                 function()
                 {
                   self.createCookie('sid',self.session.sid,1);
                   self.userLogged=1;
                   self.session.usersGetInfo(self.session.userId,'fullName',function(xmlDoc){self.setLoggedUserInfo(xmlDoc);});
                   self.initProfile();
                   self.initLeftBar();
                   self.initRightBar();
                   self.initAppMenu();
                   
                   self.connections.userId=self.session.userId;
                   
//                   if(self.defaultAction)
//                   {
//                       self.defaultAction(); 
//                       self.defaultAction=false;
//                   }      
    
                   OAT.MSG.send(self.session,OAT.MSG.SES_VALIDATION_END,{sessionValid:1});
                 }
                );

  OAT.MSG.attach(self.session,OAT.MSG.SES_INVALID,
                 function(src, msg, event)
                 {
                   self.createCookie('sid','',1);

                   if(typeof(event.retryLogIn)!='undefined' && event.retryLogIn==true)
                   {
                      nav.wait('hide');
                      self.showLoginErr();
                      self.logIn();
                      return;
                   }else if(typeof(event.sessionEnd)!='undefined' && event.sessionEnd==true)                                                                                    
                   {
                      document.location.hash='';
                      document.location.href='index.html';

                   }else
                     OAT.MSG.send(self.session,OAT.MSG.SES_VALIDATION_END,{sessionValid:0});
  
                 }
                );
  
  OAT.MSG.attach(self.session,OAT.MSG.SES_VALIDATION_END,
                 function(src, msg, event)
                 {
                  if(document.location.hash.length>0)
                  {
                    defaultAction=document.location.hash;
  
                    if(defaultAction=='#invitations')
  {
                       if(self.session.userName)
                       {
                          self.invitationsGet('fullName,photo,home',self.renderInvitations);
                          document.location.href=document.location.href.split('#')[0]+'#';
                       }
                       else
                          self.logIn();
                    
  }  
                    else
                       self.loadVspx(self.expandURL(self.ods+'sfront.vspx'));
                  
                  }else
                      self.loadVspx(self.expandURL(self.ods+'sfront.vspx'));


                 }

                );
  
  OAT.MSG.attach(self,OAT.MSG.PROFILE_UPDATED,function(){if(self.profile.show)
                                                            self.showProfile();
                                                            self.profile.show=false;
                                                        });
  
  OAT.MSG.attach(self,OAT.MSG.CONNECTIONS_UPDATED,function(){if(self.connections.show)
                                                                self.showConnections();
                                                                self.connections.show=false;                                                                
                                                            });


  this.setLoggedUserInfo = function(xmlDoc)
  {
    var userDisplayName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName',{})[0]);
    
    if(userDisplayName=='')
       userDisplayName=self.session.userName;
    
    $('aUserProfile').innerHTML=userDisplayName;
    
  };

  
  
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

    OAT.Dom.append([rootDiv,appTitle],[appTitle,appTitleApplicationA,OAT.Dom.text(' '),appTitleEditA]); 

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
       
       var appOpt={};
       if(typeof(ODS.app[packageName])!='undefined')
           appOpt=ODS.app[packageName];
       else
          appOpt={menuName:packageName,icon:'images/icons/apps_16.png',dsUrl:'#UID#/'+packageName+'/'};

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

     var menuObj=$(packageName.replace(' ','')+'_menuItem');

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
       OAT.Event.attach(profileMenuAProfile,"click",function(){ 
                                                                if(self.session.userId!=self.profile.userId)
                                                                {
                                                                   self.profile.show=true; 
                                                                   self.profile.set(self.session.userId);
                                                                   self.initProfile();
                                                                }else
                                                                   self.showProfile();
                                                              });  

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

      var packageInstalled = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//userCommunities_response/community_package',{})[0]);
      if(packageInstalled==0)
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
        OAT.Event.attach(communityMenuBodyLiA,"click",function(e){var t=eTarget(e);self.loadVspx(self.expandURL(t.homepage));});  
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi],[communityMenuBodyLi,communityMenuBodyLiA]);
      }
      

      if(self.session.userName)
      {
        var communityMenuBodyLi=OAT.Dom.create('li',{},'menu_separator');
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi]);

        var communityMenuBodyLi=OAT.Dom.create('li',{},'menu_item');
        var communityMenuBodyLiA=OAT.Dom.create('a',{cursor:'pointer'});
        communityMenuBodyLiA.innerHTML='Join community now';
        communityMenuBodyLiA.homepage='search.vspx?apps=apps&q=Community';
        OAT.Event.attach(communityMenuBodyLiA,"click",function(e){var t=eTarget(e);self.loadVspx(self.expandURL(t.homepage));});  
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi],[communityMenuBodyLi,communityMenuBodyLiA]);

        var communityMenuBodyLi=OAT.Dom.create('li',{},'menu_item');
        var communityMenuBodyLiA=OAT.Dom.create('a',{cursor:'pointer'});
        communityMenuBodyLiA.innerHTML='Create new community';
        communityMenuBodyLiA.homepage='index_inst.vspx?wa_name=Community';
        OAT.Event.attach(communityMenuBodyLiA,"click",function(e){var t=eTarget(e);self.loadVspx(self.expandURL(t.homepage));});  
        OAT.Dom.append([communityMenuBodyUl,communityMenuBodyLi],[communityMenuBodyLi,communityMenuBodyLiA]);
      }
      $('communities_menu_body').style.zIndex=100;

      var communityMenu = new OAT.Menu();
      communityMenu.noCloseFilter='menu_separator';
      
      communityMenu.createFromUL ("communities_menu");
      
      OAT.Dom.show($('communities_menu').parentNode);

      self.wait('hide');
      return;
    }
    
    this.userCommunities(renderCommunityMenu);
    
//Community menu interface create END   
    
    
    OAT.Dom.hide($('messages_menu').parentNode);
    function renderMessagesMenu(xmlDoc)
    {
      
      msgMenuItems=$('messages_menu_items');
      msgMenuItems.style.zIndex=101;
      for (var i=0;i<msgMenuItems.childNodes.length;i++)
      {
        if(msgMenuItems.childNodes[i].nodeName=='LI')
        {
          if(msgMenuItems.childNodes[i].id=='mi_inbox')
            OAT.Event.attach(msgMenuItems.childNodes[i],"click",function(){ self.profile.msgTab.go(0);self.showMessages();});  
          else if (msgMenuItems.childNodes[i].id=='mi_sent')
            OAT.Event.attach(msgMenuItems.childNodes[i],"click",function(){ self.profile.msgTab.go(1);self.showMessages();});  
          else if (msgMenuItems.childNodes[i].id=='mi_notification')
            OAT.Event.attach(msgMenuItems.childNodes[i],"click",function(){ self.profile.msgTab.go(3);self.showMessages();});  
          else if (msgMenuItems.childNodes[i].id=='mi_new_message')
            OAT.Event.attach(msgMenuItems.childNodes[i],"click",function(){ self.profile.msgTab.go(4);self.showMessages();});  
//          else  
//            OAT.Event.attach(msgMenuItems.childNodes[i],"click",function(){self.showMessages();});  
        }
      }

      var newMsgCount = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//userMessages_response/new_message_count',{})[0]);

      $('newMsgCountSpan').innerHTML='('+newMsgCount+')';

      var messagesMenu = new OAT.Menu();
      messagesMenu.noCloseFilter='menu_separator';

      messagesMenu.createFromUL ("messages_menu");
      
     OAT.Style.include('dock.css');

      OAT.Dom.show($('messages_menu').parentNode);

      OAT.Loader.loadFeatures(["dock"],function(){self.userMessages(1,renderMessagesInterface);
//                                                  setInterval(function(){self.userMessages(1,renderMessagesInterface);},10000);
                                                 });
      self.wait('hide');
      return;

    }

    function renderMessagesInterface(xmlDoc)
    {


      if(!self.profile.msgTab)
      {
         var msgTab=new OAT.Tab('msgPCtr');
         msgTab.add('msgT1','msgP1');
         msgTab.add("msgT2","msgP2");
         msgTab.add('msgT3','msgP3');
         msgTab.add("msgT4","msgP4");
         msgTab.add("msgT5","msgP5");
         msgTab.go(0);
  
         self.profile.msgTab=msgTab;
      }
      
      OAT.Event.attach('msgT1',"click",function(){ self.userMessages(2,renderInboxBlock); });    
      OAT.Event.attach('msgT2',"click",function(){ self.userMessages(3,renderSentBlock); });    
      OAT.Event.attach('msgT3',"click",function(){ self.userMessages(1,renderConversationBlock); });    
     
//      OAT.Dom.clear($('msgP5'));
      if(!$('sendBlock'))
         OAT.Dom.append([$('msgP5'),renderSendBlock()]);
      $('sendBlock').style.width=OAT.Dom.getWH($('APP'))[0]-6+'px';


      var updateDock=false;
      if(!self.msgDock)
      {
         self.msgDock=new OAT.Dock('messages_div',2);
      }else
      { 
        updateDock=true;
        for(var i=0; i<self.msgDock.windows.length;i++)
        {
            var dockTitle=self.msgDock.windows[i].options.title;
            if(dockTitle=='Inbox' || dockTitle=='Sent' || dockTitle =='Conversation')
            {
             self.msgDock.windows[i].dock.removeObject(self.msgDock.windows[i]);
             i--;
            }
        }
      }

      var dock = self.msgDock

      // hide dock control for now
      OAT.Dom.hide(dock.columns[0]);
      OAT.Dom.hide(dock.columns[1]);
      // remove these lines to show dock control.

      var titleBGColor="#336699";
      var titleTxtColor="#fff";
      
      function renderMsgNavBlock()
      {
        var container=OAT.Dom.create("div");
        
        var showSendA=OAT.Dom.create('a',{cursor: 'pointer'});
        showSendA.blockId='sendBlock';
        OAT.Event.attach(showSendA,"click",function(e){ var t=eTarget(e);
                                                        if($(t.blockId)) return;
                                                        dock.addObject(0,renderSendBlock(),{color:titleBGColor,title:'New message',titleColor:titleTxtColor});
                                                      });  
        
        OAT.Dom.append([showSendA,OAT.Dom.text('New message')]);

        var showInboxA=OAT.Dom.create('a',{cursor: 'pointer'});
        showInboxA.blockId='inboxBlock';
        OAT.Event.attach(showInboxA,"click",function(e){ var t=eTarget(e);
                                                         if($(t.blockId)) return;
                                                         inboxDock=false;
                                                         inboxDock=renderInboxBlock(xmlDoc);
                                                       });  
        OAT.Dom.append([showInboxA,OAT.Dom.text('Inbox')]);


        var showSentA=OAT.Dom.create('a',{cursor: 'pointer'});
        showSentA.blockId='sentBlock';
        OAT.Event.attach(showSentA,"click",function(e){ var t=eTarget(e);
                                                        if($(t.blockId)) return;
                                                        sentDock=false;
                                                        sentDock=renderSentBlock(xmlDoc);
                                                       });  
        OAT.Dom.append([showSentA,OAT.Dom.text('Sent')]);

        var showConversationA=OAT.Dom.create('a',{cursor: 'pointer'});
        showConversationA.blockId='conversationBlock';
        OAT.Event.attach(showConversationA,"click",function(e){ var t=eTarget(e);
                                                        if($(t.blockId)) return;
                                                        conversationDock=false;
                                                        conversationDock=renderConversationBlock(xmlDoc);
                                                       });  
        OAT.Dom.append([showConversationA,OAT.Dom.text('Conversation')]);

        OAT.Dom.append([container,showSendA,OAT.Dom.text(' | '),showInboxA,OAT.Dom.text(' | '),showSentA,OAT.Dom.text(' | '),showConversationA]);
        return container;
      }

    	if(!updateDock)
    	{
    	  var msgNavDock = dock.addObject(0,renderMsgNavBlock(),{color:titleBGColor,title:'Show dashboard',titleColor:titleTxtColor});
        OAT.Dom.unlink(msgNavDock.close.firstChild);
      }
      
      function renderSendBlock()
      {
        var container=OAT.Dom.create("div",{textAlign:'center'});
        container.id='sendBlock';
        
        var _span=OAT.Dom.create('span',{cssFloat:'left',padding:'5px 0px 0px 5px'});
        _span.innerHTML='To:';
        var msgUserSpan=OAT.Dom.create('span',{width:'45%',cssFloat:'left',textAlign:'left',padding:'5px 0px 0px 5px'});
        msgUserSpan.id='msgUserSpan';
        
        var userList = OAT.Dom.create("select",{width:'45%',cssFloat:'right',margin:'0px 3px 5px 0px'});
        userList.id = 'userList';
        OAT.Dom.option('&lt;Select recipient&gt;',-1,userList);
        for (var i=0;i<self.session.connections.length;i++)
        {
         for(cId in self.session.connections[i])
         {
          OAT.Dom.option(self.session.connections[i][cId],cId,userList);
         }
        }

        OAT.Event.attach(userList,"change",function(e){ var t=eTarget(e);

                                                        if(t.options[t.selectedIndex].value==-1)
                                                           $('msgUserSpan').innerHTML='';
                                                        else
                                                           $('msgUserSpan').innerHTML=t.options[t.selectedIndex].text;
                    
                                                        $('sendBtn').sendto=t.options[t.selectedIndex].value;

                                                     });
        OAT.Event.attach(userList,"click",function(e){ userList.style.color='#000';});

        var msgText=OAT.Dom.create('textarea',{width:'99%'});
        msgText.id='msgText';
        
        
        
        var sendBtn=OAT.Dom.create('input');
        sendBtn.id='sendBtn';
        sendBtn.type='button';
        sendBtn.sendto=-1;
        sendBtn.value='Send';


        OAT.Event.attach(sendBtn,"click",function(e){ var t=eTarget(e);

                                                       if(t.sendto==-1)
                                                       {
                                                          userList.style.color='#f00';
                                                          userList.focus();
                                                          return;
                                                       }
                                                       if($('msgText').value.length==0)
                                                       {
                                                          $('msgText').focus();
                                                          return;
                                                       }
                                                       userList.style.color='#000';
                                               
                                                       self.userMessageSend(t.sendto,$('msgText').value,false,function(){self.userMessages(1,renderMessagesInterface);})
                                                       
                                                     });

        var msgSentTxt=OAT.Dom.create('span',{color:'green',cssFloat:'right',padding:'0px 5px 0px 0px',display:'none',marginTop:'-18px'});
        msgSentTxt.id='msgSentTxt';
        msgSentTxt.innerHTML=" Message sent! ";

        
      OAT.Dom.append([container,_span,msgUserSpan,userList,OAT.Dom.create('br'),msgText,OAT.Dom.create('br'),sendBtn,msgSentTxt]);

        return container;
      }

    	if(!updateDock)
    	{
      	var sendDock = dock.addObject(0,renderSendBlock(),{color:titleBGColor,title:'New message',titleColor:titleTxtColor});
      }
      
      function renderInboxBlock(xmlDoc)
      {
        var container=OAT.Dom.create("div");
        container.id='inboxBlock';
 
        var containerTab=OAT.Dom.create("div");
        containerTab.id='inboxTab';

        var messages=OAT.Xml.xpath(xmlDoc, '//userMessages_response/message',{});

        for (var i=0;i<messages.length;i++)
        {
           var msg=buildObjByChildNodes(messages[i]);
           if(msg.recipient['@id']==self.session.userId)
           {
              var div=OAT.Dom.create('div',{overflow:'auto',width:'100%', borderBottom:'1px dotted #DDDDDD'},'msg');
              div.innerHTML='<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> From: '+msg.sender.value+'</span> - '+msg.text;

              var divC=OAT.Dom.create('div',{},'msg_item');
              divC.innerHTML='<img style="width:16px;height:16px;cursor:pointer;float:right;" src="images/skin/default/notify_remove_btn.png">'+
                             '<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> From: '+msg.sender.value+'</span> - '+msg.text;
              
              ctrl_hide=divC.getElementsByTagName('img')[0];
              ctrl_hide.msgId=msg.id;
              OAT.Event.attach(ctrl_hide,"click",function(e){ var t=eTarget(e); self.userMessageStatusSet(t.msgId,-1,function(){OAT.Dom.unlink(t.parentNode);
                                                                                                                                var msgCount=$('newMsgCountSpan').innerHTML.substring(1,$('newMsgCountSpan').innerHTML.length-1);
                                                                                                                                $('newMsgCountSpan').innerHTML='('+(msgCount-1)+')';
                                                                                                                                self.wait('hide');
                                                                                                                               }
                                                                                                          );});
            
              OAT.Dom.append([container,div]);
              OAT.Dom.append([containerTab,divC]);
           }
        }       
  
        OAT.Dom.clear($('msgP1'));
        OAT.Dom.append([$('msgP1'),containerTab]);

        self.wait('hide');

        if(inboxDock)
        {
           OAT.Dom.clear(inboxDock.div);
           OAT.Dom.append([inboxDock.div,container]);   
           return inboxDock;
        }else
        {
          var newDock=dock.addObject(1,container,{color:titleBGColor,title:'Inbox',titleColor:titleTxtColor});
          return newDock;
        }
      }

    	var inboxDock = false;
    	inboxDock=renderInboxBlock(xmlDoc);

      function renderSentBlock(xmlDoc)
      {

        var container=OAT.Dom.create("div");
        container.id='sentBlock';

        var containerTab=OAT.Dom.create("div");
        containerTab.id='sentTab';

        var messages=OAT.Xml.xpath(xmlDoc, '//userMessages_response/message',{});
        for (var i=0;i<messages.length;i++)
        {
           var msg=buildObjByChildNodes(messages[i]);
           if(msg.sender['@id']==self.session.userId)
           {
              var div=OAT.Dom.create('div',{},'msg');
              div.innerHTML='<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> To: '+msg.recipient.value+'</span> - '+msg.text;
        
              var divC=OAT.Dom.create('div',{},'msg_item');
              divC.innerHTML='<img style="width:16px;height:16px;cursor:pointer;float:right;" src="images/skin/default/notify_remove_btn.png">'+
                             '<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> To: '+msg.recipient.value+'</span> - '+msg.text;

              ctrl_hide=divC.getElementsByTagName('img')[0];
              ctrl_hide.msgId=msg.id;
              OAT.Event.attach(ctrl_hide,"click",function(e){ var t=eTarget(e); self.userMessageStatusSet(t.msgId,-1,function(){OAT.Dom.unlink(t.parentNode);
        self.wait('hide');
                                                                                                                               }
                                                                                                          );});

              OAT.Dom.append([container,div]);
              OAT.Dom.append([containerTab,divC]);
              
           }
        }       
        
        OAT.Dom.clear($('msgP2'));
        OAT.Dom.append([$('msgP2'),containerTab]);

        self.wait('hide');
        
        
        if(sentDock)
        {
           OAT.Dom.append([sentDock.div,container]);   
           return sentDock;
        }else
        {
          var newDock=dock.addObject(1,container,{color:titleBGColor,title:'Sent',titleColor:titleTxtColor});
          return newDock;
        }
      }

    	var sentDock = false;
    	sentDock=renderSentBlock(xmlDoc);

      function renderConversationBlock(xmlDoc)
      {

        var container=OAT.Dom.create("div");
        container.id='conversationBlock';

        var containerTab=OAT.Dom.create("div");
        containerTab.id='conversationTab';

        var messages=OAT.Xml.xpath(xmlDoc, '//userMessages_response/message',{});
        for (var i=0;i<messages.length;i++)
        {
           var msg=buildObjByChildNodes(messages[i]);
           if(msg.sender['@id']==self.session.userId)
           {
              var div=OAT.Dom.create('div',{},'msg');
              div.innerHTML='<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> To: '+msg.recipient.value+'</span> - '+msg.text;
              var divC=OAT.Dom.create('div',{},'msg_item');
              divC.innerHTML='<img style="width:16px;height:16px;cursor:pointer;float:right;" src="images/skin/default/notify_remove_btn.png">'+
                             '<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> To: '+msg.recipient.value+'</span> - '+msg.text;

              ctrl_hide=divC.getElementsByTagName('img')[0];
              ctrl_hide.msgId=msg.id;
              OAT.Event.attach(ctrl_hide,"click",function(e){ var t=eTarget(e); self.userMessageStatusSet(t.msgId,-1,function(){OAT.Dom.unlink(t.parentNode);
                                                                                                                                self.wait('hide');
                                                                                                                               }
                                                                                                          );});

              OAT.Dom.append([container,div]);
              OAT.Dom.append([containerTab,divC]);

           }else if(msg.recipient['@id']==self.session.userId)
           {
              var div=OAT.Dom.create('div',{},'msg');
              div.innerHTML='<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> From: '+msg.sender.value+'</span> - '+msg.text;
              var divC=OAT.Dom.create('div',{},'msg_item');
              divC.innerHTML='<img style="width:16px;height:16px;cursor:pointer;float:right;" src="images/skin/default/notify_remove_btn.png">'+
                             '<span class="time">'+msg.received.substr(0,10)+' '+msg.received.substr(11,5)+'</span><span style="font-style:italic"> From: '+msg.sender.value+'</span> - '+msg.text;

              OAT.Dom.append([container,div]);
              OAT.Dom.append([containerTab,divC]);
           }
           
        }       
        
        OAT.Dom.clear($('msgP3'));
        OAT.Dom.append([$('msgP3'),containerTab]);

        self.wait('hide');
        
        if(conversationDock)
        {
           OAT.Dom.append([conversationDock.div,container]);   
           return conversationDock;
        }else
        {
          var newDock=dock.addObject(1,container,{color:titleBGColor,title:'Conversation',titleColor:titleTxtColor});
          return newDock;
        }
      }

    	var conversationDock = false;
    	conversationDock=renderConversationBlock(xmlDoc);

      dock.div.style.width='100%';
      dock.columns[0].style.width='49%';
      dock.columns[1].style.width='49%';

      self.wait('hide');
      return;
    }
    
      if(self.session.userName)
      {
       this.userMessages(0,renderMessagesMenu);
      }


      function renderConnectionsMenu()
      {
        
        
        var connectionsMenu = new OAT.Menu();
        connectionsMenu.noCloseFilter='menu_separator';
        connectionsMenu.createFromUL ("connections_menu");
        
       connMenuItems=$('connections_menu_items');
       connMenuItems.style.zIndex=101;
       for (var i=0;i<connMenuItems.childNodes.length;i++)
       {
        if(connMenuItems.childNodes[i].nodeName=='LI'
           &&
           connMenuItems.childNodes[i].className!='menu_separator'
           &&
           connMenuItems.childNodes[i].innerHTML.indexOf('loadVspx')==-1
          )
          {
           if( connMenuItems.childNodes[i].innerHTML.indexOf('Invitations')!=-1)
              OAT.Event.attach(connMenuItems.childNodes[i],"click",function(){self.invitationsGet('fullName,photo,home',self.renderInvitations)});
           else
              OAT.Event.attach(connMenuItems.childNodes[i],"click",function(){self.connections.show=true;
                                                                          self.connections.userId=self.session.userId;
                                                                          self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface)
                                                                         });  
          }
       }                                                                  
                                                                          
     
     
        OAT.Dom.show($('connections_menu').parentNode);

        var connInterfaceTab=new OAT.Tab('cisPCtr');
        connInterfaceTab.add('csiT1','cisP1');
        connInterfaceTab.add("csiT2","cisP2");
        connInterfaceTab.go(0);
     
     
      }
  
      if(self.session.userName)
      {
       
       renderConnectionsMenu();
      }
      


    var loginfoDiv = $('ODS_BAR_RC');
    OAT.Dom.clear(loginfoDiv);


    var aSettings = OAT.Dom.create("a",{cursor: 'pointer'});
    OAT.Event.attach(aSettings,"click",function(){self.loadVspx(self.expandURL(self.ods+'app_settings.vspx'));});  
    aSettings.innerHTML='Settings'; 

    var aUserProfile = OAT.Dom.create("a",{cursor: 'pointer'});
    aUserProfile.id='aUserProfile'; 
    OAT.Event.attach(aUserProfile,"click",function(){self.loadVspx(self.expandURL(self.dataspace+'person/'+self.session.userName+'#this'));});  
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
  
  this.getSearchOptions = function (searchBoxObj)
  { 
    var searchQ = false;
  
    if(searchBoxObj && searchBoxObj.value && searchBoxObj.value.trim()!='')
    {
       searchQ='q='+encodeURIComponent(searchBoxObj.value.trim());
       if($('search_lst_sort') && $('search_lst_sort').value)
          searchQ+='&'+$('search_lst_sort').value;
       if($('search_focus_sel') && $('search_focus_sel').value)
       {

         if($('search_focus_sel').value!='' && $('search_focus_sel').value!='on_advanced')
            searchQ+='&'+$('search_focus_sel').value+'=1';
         else if($('search_focus_sel').value!='' && $('search_focus_sel').value=='on_advanced' && typeof($('search_focus_advanced'))!='undefined')
         {

            var advancedFocusCB=$('search_focus_advanced').getElementsByTagName('input');
            for(var i=0; i<advancedFocusCB.length;i++)
            {
              if(advancedFocusCB[i].type=='checkbox' && advancedFocusCB[i].checked)
                searchQ+='&'+advancedFocusCB[i].value+'=1';
            }
        } 
       }
       
    }
    return searchQ;
  }

  this.initSearch = function()
  {
        
        function modifySearchOptions(xmlDoc)
        {
//          dd(xmlDoc);
           
          var searchVal2Pack = {on_wikis       : 'Wiki',
                                on_blogs       : 'Weblog',
                                on_news        : 'Feed Manager',
                                on_bookmark    : 'Bookmarks',
                                on_omail       : 'Mail',
                                on_polls       : 'Polls',
                                on_addressbook : 'AddressBook',
                                on_calendar    : 'Calendar',
                                on_nntp        : 'Discussion',
                                on_community   : 'Community',
                                on_photos      : 'Gallery'
                               }

          if($('search_lst_sort'))
          {
           var searchFocusOptions=$('search_focus_sel').options;

            for(var i=0;i<searchFocusOptions.length;i++)
            {
                if(typeof(searchVal2Pack[searchFocusOptions[i].value])!='undefined')
                {   

                 var pack=  OAT.Xml.xpath(xmlDoc, "//installedPackages_response/application[text()='"+searchVal2Pack[searchFocusOptions[i].value]+"']",{})[0];
                 if(typeof(pack)!='undefined')
                 {
                   var att=buildObjByAttributes(pack);
                   if(typeof(att.maxinstances)!='undefined' && att.maxinstances=='0')
                      $('search_focus_sel').remove(i);
                   
                 }else
                  $('search_focus_sel').remove(i);
                }
            }
          }
          
          if($('search_focus_advanced'))
          {
            var advancedFocusCB=$('search_focus_advanced').getElementsByTagName('input');
            for(var i=0;i<advancedFocusCB.length;i++)
            {
              if(advancedFocusCB[i].type=='checkbox')
              {
                if(typeof(searchVal2Pack[advancedFocusCB[i].value])!='undefined')
                {   

                 var pack=  OAT.Xml.xpath(xmlDoc, "//installedPackages_response/application[text()='"+searchVal2Pack[advancedFocusCB[i].value]+"']",{})[0];
                 if(typeof(pack)!='undefined')
                 {

                   var att=buildObjByAttributes(pack);
                   if(typeof(att.maxinstances)!='undefined' && att.maxinstances=='0')
          {
                     advancedFocusCB[i].checked=false;
                     advancedFocusCB[i].disabled=true;
                   }
                   
                 }else
           { 
                   advancedFocusCB[i].checked=false;
                   advancedFocusCB[i].disabled=true;
                 }
           }
          }
        }
          }
           
        }

        self.installedPackages(modifySearchOptions);
        
        self.searchObj.tab=new OAT.Tab('searchPCtr');
        self.searchObj.tab.add('searcT1','searchP1');
        self.searchObj.tab.add('searcT2','searchP2');
        self.searchObj.tab.go(0);
        
        
        
        OAT.Event.attach('searcT2',"click",function(){self.searchObj.map.obj.checkResize();
                                                      if($v('search_textbox_searchC')=='')
                                                          self.searchContacts('',self.renderSearchResultsMap);

                                                     });

        var mapOpt = {
                      fix:OAT.MapData.FIX_ROUND1,
    	                fixDistance:20,
    	                fixEpsilon:0.5
                     }                 

        

        self.searchObj.map = new OAT.Map('searchMap',OAT.MapData.TYPE_G,mapOpt);
        self.searchObj.map.centerAndZoom(0,0,8); /* africa, middle zoom */
        self.searchObj.map.obj.addControl(new GSmallMapControl());
        self.searchObj.map.setMapType(OAT.MapData.MAP_ORTO); /* aerial */
        self.searchObj.map.removeAllMarkers = function(){ var totalCount=this.markerArr.length;
                                                          for (var i=0;i<totalCount;i++)
                                                               this.removeMarker(this.markerArr[0]);
                                                        };
        self.searchObj.map.ref = function(mapObj,infoDiv){ return function(marker){
                                                                                   mapObj.closeWindow();
                                                                                   mapObj.openWindow(marker,infoDiv);
                                                                                  }
                                                             
                                                 };

        if($('search_textbox_searchC'))
        {  $('search_textbox_searchC').callback=function(e){
                                                    var t=eTarget(e);

                                                    if(t && t.value && t.value.length<2)
                                                    {
                                                     self.dimmerMsg('Invalid keyword string entered.');
                                                     return;
                                                    }

                                                    if(t && t.value && t.value.length>0)
                                                    {
                                                       self.search(self.getSearchOptions(t),self.renderSearchResults);
                                                       self.searchContacts('keywords='+t.value,self.renderSearchResultsMap);
                                                    
                                                    }
                                                    else if(self.searchObj.tab.selectedIndex==1)
                                                    {
                                                     self.searchContacts('',self.renderSearchResultsMap);
                                                    }
                                                      
                                                    
                                                };
           OAT.Event.attach($('search_textbox_searchC'),"keypress",onEnterDown);  
        };
        OAT.Event.attach($('search_textbox_searchC'),"keypress",onEnterDown);  
        
        if($('search_button_searchC'))
        {  $('search_button_searchC').callback=function(){
                                                  var t=$('search_textbox_searchC');

                                                  if(t && t.value && t.value.length<2)
                                                  {
                                                     self.dimmerMsg('Invalid keyword string entered.');
                                                     return;
                                                  }

                                                  if(t && t.value && t.value.length>0)
                                                  {
                                                     self.search(self.getSearchOptions(t),self.renderSearchResults);
                                                     self.searchContacts('keywords='+t.value,self.renderSearchResultsMap);
                                                  
                                                  }
                                                  else if(self.searchObj.tab.selectedIndex==1)
                                                  {
                                                   self.searchContacts('',self.renderSearchResultsMap);
                                                  }
                                                };
        }
        

        if($('toggleSelect'))
           $('toggleSelect').callback=function(){inverseSelected($('search_listing'))};
           
        if($('search_focus_sel'))
           $('search_focus_sel').callback=function(){if(this[this.selectedIndex].value=='on_advanced')
                                                        OAT.Dom.show($('search_focus_advanced'));
                                                     else OAT.Dom.hide($('search_focus_advanced'));
                                                }
        $('search_focus_sel').callback();
        if($('advanced_search_searchC'))
           $('advanced_search_searchC').callback=function(){
                                                            var t=$('search_textbox_searchC');
                                                            if(t && t.value && t.value.length>0)
                                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx?q='+encodeURIComponent(t.value.trim())));
                                                            else
                                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx'));
                                                           }
        
        if($('tagSelectedToggle'))
        {
          $('tagSelectedToggle').divId='do_tag_block';
           $('tagSelectedToggle').callback=function(){
                                                       if($(this.divId))
                                                       {
                                                        if($(this.divId).style.display=='none')
                                                           OAT.Dom.show($(this.divId));
                                                        else
                                                           OAT.Dom.hide($(this.divId));
                                                       }
                                                       return;
                                                     }
        
        }
        if($('tagsInput'))
        {
           $('tagsInput').doTagToggle=function(){
                                                      var img=this.parentNode.getElementsByTagName("img")[0];
                                                      if(!self.session.userId || 
                                                         this.value.length==0 ||
                                                         typeof($('top_pager').paginator)=='undefined' || 
                                                         (typeof($('top_pager').paginator)!='undefined' && $('top_pager').paginator.totalCount==0)
                                                        )
                                                      {
                                                       
                                                       img.action=false;
                                                       img.style.cursor='';
                                                       if(img.src!='images/icons/add_16_gr.png')
                                                          img.src='images/icons/add_16_gr.png';
                                                      }else
                                                      {
                                                       img.action='tag';
                                                       img.style.cursor='pointer';
                                                       if(img.src!='images/icons/add_16.png')
                                                          img.src='images/icons/add_16.png';
                                                      }
                                                      return;
                                                }
        
  }

        if($('do_tag'))
        {
           $('do_tag').callback=function(){  if(typeof(this.action)!='undefined' && this.action=='tag')
                                             {
                                               var tagStr=$('tagsInput').value.trim();
                                               var tagObjStr='';
                                               
                                               if(tagStr!='')
                                               {
                                                 var i=0;
                                                 var inps=$('search_listing').getElementsByTagName('input');

                                                 for(var k=0;k<inps.length;k++)
                                                 {
                                                   if(inps[k].type=='checkbox' && inps[k].checked)
                                                   {
                                                      tagObjStr+='&obj'+i+'='+inps[k].value;
                                                      i++;
                                                   }
                                                 }
                                                 
                                               }
                                               
                                               if(tagStr.length>0 && tagObjStr.length>0)
                                                  self.tagSearchResult('tagStr='+tagStr+tagObjStr,function(){self.wait('hide');});
                                                
                                             }
                                             return;
                                       }
        
        }

        var permaInstant = new OAT.Instant($('search_gems_block'));
        permaInstant.createHandle($('searchPermalinkA'));
        permaInstant.createHandle($('searchPermalinkImg'));
        
  
  
        function gemHref(gemType)
        {
          if(typeof(gemType)=='undefined') return;
          
          var q=$('search_textbox_searchC').value+'';

          var onStr='';
          
          if($('search_focus_sel') && $('search_focus_sel').value)
          {
   
            var allSearchOpts='';
            var selectedSearchOpts='';

            var searchVal2Gems = {on_people      : 'people',
                                  on_apps        : 'apps',
                                  on_dav         : 'dav',                                                
                                  on_wikis       : 'wiki',
                                  on_blogs       : 'weblog',
                                  on_news        : 'feeds',
                                  on_bookmark    : 'bookmark',
                                  on_omail       : 'mail',
                                  on_polls       : 'polls',
                                  on_addressbook : 'addressbook',
                                  on_calendar    : 'calendar',
                                  on_nntp        : 'discussion',
                                  on_community   : 'community',
                                  on_photos      : 'gallery'
                                 }
            
            var advancedFocusCB=$('search_focus_advanced').getElementsByTagName('input');
            if(typeof($('search_focus_advanced'))!='undefined')
            {
               for(var i=0; i<advancedFocusCB.length;i++)
               {
                 if(advancedFocusCB[i].type=='checkbox' && advancedFocusCB[i].checked && typeof(searchVal2Gems[advancedFocusCB[i].value])!='undefined')
                 {
                   var optStr=searchVal2Gems[advancedFocusCB[i].value]
                   
                   if(!advancedFocusCB[i].disabled)
                      allSearchOpts += (i==advancedFocusCB.length-1) ? optStr : optStr+',';
                   if(advancedFocusCB[i].checked)
                      selectedSearchOpts += (i==advancedFocusCB.length-1) ? optStr : optStr+',';
                 }
               }
            }

            if($('search_focus_sel').value=='on_all')
                 onStr=allSearchOpts;
            else if($('search_focus_sel').value=='on_advanced')
                 onStr=selectedSearchOpts;
            else if($('search_focus_sel').value!='' && typeof(searchVal2Gems[advancedFocusCB[i].value])!='undefined')
                 onStr=searchVal2Gems[advancedFocusCB[i].value];
          
          }
          
          var gHref=false;
          if(gemType=='gdata')
          {
//             dd('/dataspace/GData/people,apps,weblog,dav,feeds,wiki,mail,bookmark,polls,addressbook,discussion/?q=tester&sid=f21bca9b6bd68a3db8b86a64a0170654&realm=wa');
             gHref=self.expandURL('/dataspace/GData/'+onStr+'/?q='+q);
          }
          else
          {
//             dd('search.vspx?q=tester&q_tags=&r=100&s=1&apps=people,apps,weblog,dav,feeds,wiki,mail,bookmark,polls,addressbook,discussion&o=xml&sid=f21bca9b6bd68a3db8b86a64a0170654&realm=wa');
             gHref=self.expandURL('search.vspx?q='+q+'&q_tags=&r=100&s=1&apps='+onStr+'&o='+gemType);
          }
        
           return gHref;
        }

        if($('search_gems_block'))
        {
           var gems=$('search_gems_block').getElementsByTagName('a');
           
           for(var i=0;i<gems.length;i++)
           {
              OAT.Dom.attach()
              OAT.Dom.attach(gems[i],"click",function(e) {var t=eTarget(e);
                                                          var gemUrl=gemHref(t.rel);
                                                          if(gemUrl.length)
                                                             window.open(gemUrl);
                                                         });
           }
        }
        



  }
  
  this.renderSearchResultsMap = function(xmlDoc)
  {
     self.wait('hide');
     self.searchObj.map.removeAllMarkers();

     var mapResults=OAT.Xml.xpath(xmlDoc, '//searchContacts_response/search_result',{});
     self.searchObj.map.geoCoordArr=new Array();
     
     
     for (var i=0;i<mapResults.length;i++)
     {
        var result=buildObjByChildNodes(mapResults[i]);
        
        var htmlDiv=OAT.Dom.create('div');
        htmlDiv.innerHTML=result.html;
        self.searchObj.map.addMarker(result.uid,result.latitude,result.longitude,
                            false,false,false,
                            self.searchObj.map.ref(self.searchObj.map,htmlDiv)
              );
       self.searchObj.map.geoCoordArr.push(new Array(result.latitude,result.longitude));
        
     }
      self.searchObj.map.optimalPosition(self.searchObj.map.geoCoordArr);

  }

  this.renderSearchResults = function(xmlDoc)
  {
    if(typeof($('search_focus_sel').callback)=='function')
       $('search_focus_sel').callback();

    OAT.Dom.clear($('search_listing'));
    if($('search_textbox_searchC').value.length>0)
       $('search_textbox').value='';
    
    var results=OAT.Xml.xpath(xmlDoc, '//search_response/search_result',{});
    
    var resultsPagination= new ODS.paginator(results,$('top_pager'),$('bottom_pager'),renderResultsPage);

    function renderResultsPage(paginationCtrl)
    {
     OAT.Dom.clear($('search_listing'));

     if(paginationCtrl.startIndex && paginationCtrl.endIndex)
     {
       for (var i=paginationCtrl.startIndex;i<=paginationCtrl.endIndex;i++)
       {
         var result=buildObjByChildNodes(paginationCtrl.iSet[i-1]);
         result.date=new Date(result.date);
       
         var resultLi=OAT.Dom.create('li');
         var resultCB=OAT.Dom.create('input',{},'sel_ckb')
         resultCB.type='checkbox';
         resultCB.checked=true;
         resultCB.value=result.tag_table_fk;
         
         var resultDiv=OAT.Dom.create('div',{},'hit');
       
         var resultInnerDiv=OAT.Dom.create('div',{},'hit_ctr');
         resultInnerDiv.innerHTML=result.html;
         
         OAT.Dom.append([$('search_listing'),resultLi],[resultLi,resultDiv],[resultDiv,resultCB,resultInnerDiv]);
       }
     }
    }

    if(resultsPagination.totalItems==0)
    {
      var resultLi=OAT.Dom.create('li');
      resultLi.innerHTML='<div class="hit" style="padding:10px 0px 5px 0px;">&nbsp;Your search - <b>'+$('search_textbox_searchC').value+'</b> - did not match any documents.</div>';
      OAT.Dom.append([$('search_listing'),resultLi]);

    }
    
        
    self.showSearch()
    self.wait('hide');

  };
  
  this.renderInvitations = function(xmlDoc)
  {
    var invitations=OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation',{});

    if (invitations.length>0)
    { 
      var fullName=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/fullName',{})[0]);
      var invUserID=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/uid',{})[0]);
      
      function showInvProfile()
      {
        self.wait();
        self.profile.show=true; 
        self.profile.set(invUserID);
        self.initProfile();
      }

      function showLoggedUserProfile()
      {
        self.wait();
        self.profile.show=true; 
        self.profile.set(self.session.userID);
        self.initProfile();
      }
      
      OAT.Event.attach($('ivitaitons_connection_photo'),"click",showInvProfile);  
      OAT.Event.attach($('ivitaitons_connection_profileA'),"click",showInvProfile);  
      OAT.Event.attach($('ivitaitons_connection_ownprofileA'),"click",showLoggedUserProfile);  


      $('ivitaitons_connection_full_name_1').innerHTML=fullName;
      $('ivitaitons_connection_full_name_2').innerHTML=fullName;
      $('ivitaitons_connection_full_name_3').innerHTML=fullName;
      $('ivitaitons_connection_full_name_4').innerHTML=fullName;
      $('ivitaitons_connection_full_name_5').innerHTML=fullName;

      $('ivitaitons_connection_photo').alt=fullName;
      $('ivitaitons_connection_photo').src=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/photo',{})[0])

      $('ivitaitons_connection_city').innerHTML=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/home/city',{})[0]);
      $('ivitaitons_connection_country').innerHTML=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/home/country',{})[0]);
      $('ivitaitons_connection_conncount').innerHTML=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '//invitationsGet_response/invitation/connections/count',{})[0]);

      OAT.Event.attach($('ivitaitons_connection_acceptA'),"click",function(){self.connectionSet(invUserID,2,function(){self.invitationsGet('fullName,photo,home',self.renderInvitations);})} );  
      OAT.Event.attach($('ivitaitons_connection_rejectA'),"click",function(){self.connectionSet(invUserID,3,function(){self.invitationsGet('fullName,photo,home',self.renderInvitations);})} );  

      self.showInvitations();
    }else
    {
      self.dimmerMsg('You have no new invitations.', function(){ self.connections.show=true;self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface); });
    }
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
        loginTab.add('loginT2','loginP2');
        loginTab.go(0);
        
        OAT.Event.attach('loginT1',"click",function(){$('loginErrDiv').innerHTML='';if(!OAT.Dom.isIE()) $('loginUserName').focus();});  
        OAT.Event.attach('loginT2',"click",function(){$('loginErrDiv').innerHTML='';if(!OAT.Dom.isIE()) $('loginOpenIdUrl').focus();});  
       
        OAT.Event.attach($('loginCloseBtn'),"click",OAT.Dimmer.hide);  

        OAT.Event.attach($('signupBtn'),"click",function(){self.session.sid=false;OAT.Dimmer.hide();self.loadVspx(self.expandURL(self.ods+'register.vspx'));});  
        
        if($('loginUserName'))
        {
           $('loginUserName').callback=function(){if($('loginUserPass')) $('loginUserPass').focus(); return;}
           OAT.Event.attach($('loginUserName'),"keypress",onEnterDown);  

        }

        if($('loginUserPass'))
        {
           $('loginUserPass').tokenReceived=false;
           $('loginUserPass').callback=function(){
                                                  if(this.tokenReceived)
                                                  {
                                                    self.session.validate();
                                                  }else
                                                  {
                                                   if($('loginErrDiv').innerHTML.indexOf('Please wait ...')==-1)
                                                      $('loginErrDiv').innerHTML='<img src="images/warn_16.png" style="vertical-align: text-bottom; padding: 3px 3px 0px 0px;" >Please wait ...';
                                                   setTimeout(function(){$('loginUserPass').callback()},500);
                                                  }
                                                 }  
           OAT.Event.attach($('loginUserPass'),"keypress",onEnterDown);  

        }


        if($('loginOpenIdUrl'))
        {
           $('loginOpenIdUrl').tokenReceived=false;
           $('loginOpenIdUrl').callback=function(){
                                                  if(this.tokenReceived)
                                                  {
                                                    self.session.validate();
                                                  }else
                                                  {
                                                   if($('loginErrDiv').innerHTML.indexOf('Please wait ...')==-1)
                                                      $('loginErrDiv').innerHTML='<img src="images/warn_16.png" style="vertical-align: text-bottom; padding: 3px 3px 0px 0px;" >Please wait ...';
                                                   setTimeout(function(){$('loginOpenIdUrl').callback()},500);
                                                  }
                                                 }  
           OAT.Event.attach($('loginOpenIdUrl'),"keypress",onEnterDown);  
        }

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
       OAT.Event.attach(signupBtn,"click",function(){self.session.sid=false;OAT.Dimmer.hide;self.loadVspx(self.expandURL(self.ods+'register.vspx'));});  
      
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

  this.showLoginErr=function(errMsg)
  {
    if(typeof(errMsg)=='undefined')
    {
      if($('loginDiv').loginTab.selectedIndex==1)
          errMsg='Invalid OpenID URL';
      else
          errMsg='Invalid Member ID or Password';
    }
    OAT.Dom.clear('loginErrDiv');
    var warnImg=OAT.Dom.create('img',{verticalAlign:'text-bottom',padding:'3px 3px 0px 0px'});
    warnImg.src='images/warn_16.png';
    OAT.Dom.append([$('loginErrDiv'),warnImg,OAT.Dom.text(errMsg)]);
    return;
  
  }


  this.updateConnectionsInterface = function (xmlDoc)
  {
    var connections = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user',{});
    var invitations = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user/invited',{});

// START render connection Interface 
        if(self.session.userId==self.connections.userId)
           $('connectionsCountSpan').innerHTML='('+(connections.length-invitations.length)+')';

        
        OAT.Dom.clear($('connections_list'));
        var templateHtml= $('connectionsTemplate').innerHTML;
        for(var i=0;i<connections.length;i++)
        {
          
          var conn=buildObjByChildNodes(connections[i]);
          
          var arrPos = -1;
          if(self.session.connectionsId)
            arrPos=self.session.connectionsId.find(conn.uid);
          
          if(self.session.userId==self.connections.userId && arrPos==-1 )
             self.session.connectionAdd(conn.uid,conn.fullName);
          
          var connHTML=templateHtml;

          connHTML=connHTML.replace('#connImgSRC#',conn.photo.length>0 ? conn.photo : 'images/profile.png');
          connHTML=connHTML.replace('#connProfileFullName#',conn.fullName);
          connHTML=connHTML.replace('#sendMsg#','sendMsg_'+conn.uid);
          connHTML=connHTML.replace('#viewConnections#','viewConnections_'+conn.uid);
          connHTML=connHTML.replace('#doConnection#','doConnection_'+conn.uid);
          
          var divSize=(OAT.Dom.getWH($('RT'))[0]-20) +'px';
          
          var div=OAT.Dom.create('div',{width:divSize,border:'1px solid',margin:'5px'});
          div.uid=conn.uid;
          div.innerHTML=connHTML;
          
          var elm=div.getElementsByTagName("img")[0];
          elm.uid=conn.uid;
          OAT.Dom.attach(elm,"click",function(e) {var t=eTarget(e);self.profile.show=true;self.profile.set(t.uid) ;self.initProfile();});

          var elm=div.getElementsByTagName("span")[0];
          elm.uid=conn.uid;
          OAT.Dom.attach(elm,"click",function(e) {var t=eTarget(e);self.profile.show=true;self.profile.set(t.uid) ;self.initProfile();});
          
          OAT.Dom.append([$('connections_list'),div]);


          var elm=$('sendMsg_'+conn.uid);
          elm.uid=conn.uid;
          if(conn.uid==self.session.userId)
             OAT.Dom.unlink(elm);
          else 
          {
            OAT.Event.attach(elm,"click",function(e){var t=eTarget(e);
                                                     self.ui.newMsgWin(t,t.uid);
                                                    });
          };
          
          
          var elm=$('viewConnections_'+conn.uid);
          elm.uid=conn.uid;
          OAT.Event.attach(elm,"click",function(e){
                                                   var t=eTarget(e);
                                                   self.connections.show=true;
                                                   self.connections.userId=t.uid;
                                                   self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface)
                                                 });  

          var elm=$('doConnection_'+conn.uid);

          
          var elmParent=elm.parentNode;

          OAT.Dom.unlink(elm);
          
          var elm=OAT.Dom.create('a',{cursor:'pointer',textDecoration:'underline'});
          elm.id="'doConnection_'+conn.uid";
          elm.uid=conn.uid;
          elm.fullName=conn.fullName;
          
          if(self.session.connectionsId.find(conn.uid) > -1 && typeof(conn.invited)=='undefined')
          {
             elm.innerHTML='Disconnect';
             
             OAT.Dom.attach(elm,"click",function(e) {var t=eTarget(e);
                                                     self.connectionSet(t.uid,0,function(){self.session.connectionRemove(t.uid);
                                                                                           self.initProfile();
                                                                                           self.connections.show=true;
                                                                                           self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface);
                                                                                           
                                                                                          }
                                                                        )
                                                     });
          }else if(self.session.connectionsId.find(conn.uid) > -1 && typeof(conn.invited)!='undefined' && conn.invited==1)
          {
             elm.innerHTML='Withdraw invitation';
             
             OAT.Dom.attach(elm,"click",function(e) {var t=eTarget(e);
                                                     self.connectionSet(t.uid,4,function(){self.session.connectionRemove(t.uid);
                                                                                           self.initProfile();
                                                                                           self.connections.show=true;
                                                                                           self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface);
                                                                                          }
                                                                        )
                                                     });

          }else if(self.session.userId!=conn.uid)
          {
             elm.innerHTML='Connect';
             OAT.Dom.attach(elm,"click",function(e) {var t=eTarget(e);
                                                    self.connectionSet(t.uid,1,function(){  
                                                                                            self.session.connectionAdd(t.uid,t.fullName);
                                                                                            self.connections.show=true;
                                                                                            self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface);
                                                                                         }
                                                                      )
                                                     });
          }
          
//          if(typeof(elmParent)!='undefined')
             OAT.Dom.append([elmParent,elm]);

        }



//          OAT.Event.attach(connMenuItems.childNodes[i],"click",function(){self.connections.show=true;
//                                                                          self.connectionsGet(self.connections.userId,'fullName,photo,homeLocation',self.updateConnectionsInterface)
//                                                                         });  

        OAT.MSG.send(self,OAT.MSG.CONNECTIONS_UPDATED,{});

// END render connection Interface 

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
    self.profile.userFullName=userDisplayName;
    var userProfilePhoto=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/photo',{})[0]);

    if(userDisplayName=='')
       userDisplayName=self.profile.userName;


    $('userProfilePhotoName').innerHTML='<h3>'+userDisplayName+'</h3>';
    $('userProfilePhotoImg').src=userProfilePhoto ? userProfilePhoto : 'images/profile.png';
    $('userProfilePhotoImg').alt=userDisplayName;
    
    var gems=$('profileUserGems').getElementsByTagName("a");
    gems[0].href=self.odsLink()+'/dataspace/person/'+self.profile.userName+'/foaf.rdf'; // foaf
    gems[1].href=self.odsLink()+'/dataspace/'+self.profile.userName+'/sioc.rdf'; //sioc
//    gems[2].href='http://geourl.org/near?p='+encodeURIComponent('http://'+document.location.host+'/dataspace/'+self.profile.userName); //GEOURL //http://geourl.org/near?p=http%3A//bdimitrov.lukanet.com%3A8890/dataspace/borislavdimitrov
    gems[2].href=self.odsLink()+self.ods+'sn_user_export.vspx?ufid='+self.profile.userId+'&ufname='+self.profile.userName;//vcard
    
    function renderProfileUserActions()
    {
     
      OAT.Dom.show($('profile_user_actions'));
    
      var msgA=$('profileSendMsg');
      if(self.session.userId==self.profile.userId)
         OAT.Dom.hide(msgA);
      else       
      {
         OAT.Dom.show(msgA);
         OAT.Dom.attach(msgA,"click",function() {self.ui.newMsgWin(msgA,self.profile.userId);});
      }

      var connA=$('profileConnAction');
      if(self.session.userId==self.profile.userId)
         OAT.Dom.hide(connA);
      else       
      {
         var connLi=connA.parentNode;
         OAT.Dom.unlink(connA);
         
         var connA=OAT.Dom.create('a',{cursor:'pointer'});
         connA.id="profileConnAction";
         
         if(self.session.connectionsId.find(self.profile.userId) > -1)
         {
            connA.innerHTML='Disconnect';
            OAT.Dom.attach(connA,"click",function() {self.connectionSet(self.profile.userId,0,function(){self.session.connectionRemove(self.profile.userId);
                                                                                                         self.initProfile();
                                                                                                        }
                                                                       )
                                                    });
         }else
         {
            connA.innerHTML='Connect';
            OAT.Dom.attach(connA,"click",function() {self.connectionSet(self.profile.userId,1,function(){//self.session.connectionAdd(self.profile.userId,self.profile.userFullName);
                                                                                                         self.initProfile();
                                                                                                        }
                                                                       )
                                                    });
         }
         
         OAT.Dom.append([connLi,connA]);
      }



    }
    
    renderProfileUserActions();

    function renderConnectionsWidget(xmlDoc)
    {

      var connTP=$('connP1')
      OAT.Dom.clear(connTP);

      function attachClick(elm, connId)
      {
        OAT.Dom.attach(elm,"click",function() {self.profile.show=true; self.profile.set(connId) ;self.initProfile();});
      };

      var connections = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user',{});

      var invitations = OAT.Xml.xpath(xmlDoc, '//connectionsGet_response/user/invited',{});


      $('connPTitleTxt').innerHTML='Connections ('+(connections.length-invitations.length)+')';

      var connectionsArr= new Array();

      for(var i=0;i<connections.length;i++)
      {

        var connObj=buildObjByChildNodes(connections[i]);

        if(typeof(connObj.invited)=='undefined' )
        {
           
           var connProfileObj={};
           connProfileObj[connObj.uid]=connObj.fullName;

           self.profile.connections.push(connProfileObj);
           connectionsArr.push(connObj.uid);
        
        var _divC=OAT.Dom.create('div',{cursor:'pointer'},'conn');

           _divC.id='connW_'+connObj.uid;
           attachClick(_divC,connObj.uid);
        
        var tnail=OAT.Dom.create('img',{width:'40px',height:'40px'});
           tnail.src= (connObj.photo.length>0 ? connObj.photo : 'images/profile_small.png');
        var _divCI=OAT.Dom.create('div',{},'conn_info');
        var cNameA=OAT.Dom.create('a',{cursor:'pointer'});
           cNameA.innerHTML=connObj.fullName;
       
        OAT.Dom.append([connTP,_divC],[_divC,tnail,_divCI],[_divCI,cNameA]);
        
 
        var _lat = OAT.Xml.textValue(connections[i].childNodes[3].childNodes[0]);
        var _lon = OAT.Xml.textValue(connections[i].childNodes[3].childNodes[1]);
        if(_lat != '' && _lon != '')
        {
          self.profile.connMap.addMarker(i,_lat,_lon,
                                         tnail.src,40,40,
                                            function(marker){self.profile.show=true;self.profile.set(self.profile.connMap.connData[marker.__group].id) ;self.initProfile();}
                                         );
   
          self.profile.connMap.connLocations.push(new Array(_lat,_lon));
             self.profile.connMap.connData[i]={id    : connObj.uid,
                                            name  : cNameA.innerHTML,
                                            photo : tnail.src}
        
        }
      }
      }

      if(self.session.userId==self.profile.userId)
      {
        self.session.connections=self.profile.connections;
        self.session.connectionsId=connectionsArr;
      }

      self.profile.connMap.optimalPosition(self.profile.connMap.connLocations);
      self.wait('hide');
      return;
    }

    function activitiesByAtom(atomXml)
    {
     var activities=new Array();
     return activities;
    }

    
    function buildTimeObj()
    {
      function pZero(val,prec)
      {
        if (!prec) prec = 2;
        if(String(val).length < prec)
          return '0'.repeat(prec - String(val).length) + String(val);
        else 
          return val;
      };

     var weekday=new Array(7)
         weekday[0]="Sunday";
         weekday[1]="Monday";
         weekday[2]="Tuesday";
         weekday[3]="Wednesday";
         weekday[4]="Thursday";
         weekday[5]="Friday";
         weekday[6]="Saturday";
     
     var obj={};
     var d=new Date();
//     d.setFullYear(2007,0,1);
     var titleObj=OAT.Dom.create('h3',{},'date');
     OAT.Dom.append([titleObj,OAT.Dom.text('Today')]);
     obj[d.getFullYear()+'-'+pZero(d.getMonth()+1)+'-'+pZero(d.getDate())]={title:'Today',titleObj:titleObj,ulObj:OAT.Dom.create('ul',{},'msgs')};
     
     d.setDate(d.getDate()-1);
     var titleObj=OAT.Dom.create('h3',{},'date');
     OAT.Dom.append([titleObj,OAT.Dom.text('Yesterday')]);
     obj[d.getFullYear()+'-'+pZero(d.getMonth()+1)+'-'+pZero(d.getDate())]={title:'Yesterday',titleObj:titleObj,ulObj:OAT.Dom.create('ul',{},'msgs')};

     for(var i=0;i<5;i++)
     {
       d.setDate(d.getDate()-1);
       var titleObj=OAT.Dom.create('h3',{},'date');
       OAT.Dom.append([titleObj,OAT.Dom.text(weekday[d.getDay()])]);
       obj[d.getFullYear()+'-'+pZero(d.getMonth()+1)+'-'+pZero(d.getDate())]={title:weekday[d.getDay()],titleObj:titleObj,ulObj:OAT.Dom.create('ul',{},'msgs')};
     }

     var titleObj=OAT.Dom.create('h3',{},'date');
     OAT.Dom.append([titleObj,OAT.Dom.text('Older')]);
     obj['older']={title:'Older',titleObj:titleObj,ulObj:OAT.Dom.create('ul',{},'msgs')};

    
     return obj;
    }
    
    function renderNewsFeedBlock(xmlString)
    {
      var actHidden=new Array;
      self.feedStatus(function(xmlDoc){ var actOpt = OAT.Xml.xpath(xmlDoc, '/feedStatus_response/activity',{});
                                        for(var i=0;i<actOpt.length;i++)
                                        {
                                          var act=buildObjByAttributes(actOpt[i]);
                                          if(act.status==0)
                                             actHidden.push(act.id);
                                        }
                                        self.wait('hide');
                                      });

      var daily=buildTimeObj();
      var cont = $('notify_content');
      if(!cont) return;
      
      var xmlDoc = OAT.Xml.createXmlDoc(OAT.Xml.removeDefaultNamespace(xmlString));
      var entries = OAT.Xml.xpath(xmlDoc, '/feed/entry',{});


      for(var i=0;i<entries.length;i++)
      {
          var entry=buildObjByChildNodes(entries[i]);


          var actImg=false;
          if( (typeof(entry['dc:type'])!='undefined') && (typeof(entry['dc:type'].value)!='undefined') && (entry['dc:type'].value.length>0) && (typeof(ODS.ico[entry['dc:type'].value]) != 'undefined'))
          {
             actImg=OAT.Dom.create('img',{},'msg_icon');
             actImg.alt=ODS.ico[entry['dc:type'].value].alt;
             actImg.src=ODS.ico[entry['dc:type'].value].icon;
          
          };
            
          var feedId=entry.id.split('/');
          feedId=feedId[feedId.length-1];

          var ctrl_hide = OAT.Dom.create('img',{width:'16px',height:'16px',cursor:'pointer'});
              ctrl_hide.src='images/skin/default/notify_remove_btn.png'
              ctrl_hide.alt='Hide';
          
          ctrl_hide.feedId=feedId;
          OAT.Event.attach(ctrl_hide,"click",function(e){ var t=eTarget(e);var feedId=t.feedId;t=t.parentNode.parentNode;
                                                          self.feedStatusSet( feedId,0,function(){if(t.parentNode.childNodes.length==1)
                                                                                                  {  if(t.parentNode.previousSibling.tagName=='H3')
                                                                                                        OAT.Dom.unlink(t.parentNode.previousSibling);
                                                                                                     OAT.Dom.unlink(t.parentNode);
                                                                                                  }else OAT.Dom.unlink(t);
                                                                                                  self.wait('hide');});
                                                                                                  });  

          var ctrl=OAT.Dom.create('div',{},'msg_r')
          OAT.Dom.append([ctrl,ctrl_hide]);
          
          var actDiv=OAT.Dom.create('div',{},'msg');
          actDiv.innerHTML='<span class="time">'+entry.updated.substr(11,5)+'</span> '+entry.title;
         
          var actLi=OAT.Dom.create('li');
          
          if(actImg)
             OAT.Dom.append([actLi,actImg,actDiv,ctrl])
          else
             OAT.Dom.append([actLi,actDiv,ctrl])
          
          var actDate=entry.updated.substring(0,10);
          
          if(typeof(daily[actDate])=='object' && actHidden.find(feedId)==-1)
          { 
              OAT.Dom.append([daily[actDate].ulObj,actLi]);
          }else
              OAT.Dom.append([daily['older'].ulObj,actLi]);

      }
      
      OAT.Dom.clear($('notify_content'));
      for(day in daily)
      {
        if(daily[day].ulObj.childNodes.length>0)
        {
         OAT.Dom.append([$('notify_content'),daily[day].titleObj,daily[day].ulObj]) 
        }
      }


    }

    function renderContactInformationBlock(xmlDoc)
    {
        var titledFullname = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/title',{})[0])+' '+OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/fullName',{})[0]);

        var photo = OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/usersGetInfo_response/user/photo',{})[0]);
        if(photo.length<1) photo = 'images/profile_small.png';
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
       
       var appOpt={};
       if(typeof(ODS.app[packageName])!='undefined')
           appOpt=ODS.app[packageName];
       else
          appOpt={menuName:packageName,icon:'images/icons/apps_16.png',dsUrl:'#UID#/'+packageName+'/'};

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
    
    self.connectionsGet(self.profile.userId,'fullName,photo,homeLocation',function(xmlDocRet){renderConnectionsWidget(xmlDocRet);
                                                                                              if(self.session.userId==self.profile.userId)
                                                                                                 self.updateConnectionsInterface(xmlDocRet);
                                                                                             });
    self.discussionGroupsGet(self.profile.userId,renderDiscussionGroups)

    OAT.AJAX.GET(ODS.Preferences.activitiesEndpoint+self.profile.userName+'/0/', false , renderNewsFeedBlock, optionsGet);

    self.session.usersGetInfo(self.profile.userId,'title,fullName,photo,home,homeLocation,business,businessLocation,im',function(xmlDoc3){renderContactInformationBlock(xmlDoc3);});
    self.session.usersGetInfo(self.profile.userId,'interests,music',function(xmlDoc3){renderPersonalInformationBlock(xmlDoc3);});


     OAT.MSG.send(self,OAT.MSG.PROFILE_UPDATED,{});

     //if(self.session.userId!=self.profile.userId)
     //   self.showProfile();
    

  }
  
  this.showProfile = function()
  {
     self.wait();
     OAT.Dom.hide('vspxApp');
     OAT.Dom.hide('messages_div');
     OAT.Dom.hide('contacts_interface');
     OAT.Dom.hide('invitations_C');
     OAT.Dom.hide('generalSearch_C');

     OAT.Dom.show('u_profile_l');
     OAT.Dom.show('u_profile_r');
     self.wait('hide');
  }
  
  this.showMessages = function()
  {
     self.wait();
     OAT.Dom.hide('vspxApp');
     OAT.Dom.hide('u_profile_l');
     OAT.Dom.hide('u_profile_r');
     OAT.Dom.hide('contacts_interface');
     OAT.Dom.hide('invitations_C');
     OAT.Dom.hide('generalSearch_C');
     
     OAT.Dom.show('messages_div');


     self.wait('hide');
  }

  this.showConnections = function()
  {
     self.wait();
     OAT.Dom.hide('vspxApp');
     OAT.Dom.hide('u_profile_l');
     OAT.Dom.hide('u_profile_r');
     OAT.Dom.hide('messages_div');
     OAT.Dom.hide('invitations_C');
     OAT.Dom.hide('generalSearch_C');
    
     OAT.Dom.show('contacts_interface');

     self.wait('hide');
  }
  

  this.showInvitations = function()
  {
     self.wait();
     OAT.Dom.hide('vspxApp');
     OAT.Dom.hide('u_profile_l');
     OAT.Dom.hide('u_profile_r');
     OAT.Dom.hide('messages_div');
     OAT.Dom.hide('contacts_interface');
     OAT.Dom.hide('generalSearch_C');

     OAT.Dom.show('invitations_C');


     self.wait('hide');
  }
  
  this.showSearch = function()
  {
     self.wait();
     OAT.Dom.hide('vspxApp');
     OAT.Dom.hide('u_profile_l');
     OAT.Dom.hide('u_profile_r');
     OAT.Dom.hide('messages_div');
     OAT.Dom.hide('contacts_interface');
     OAT.Dom.hide('invitations_C');

     OAT.Dom.show('generalSearch_C');

     self.wait('hide');
  }
  
  this.loadVspx= function (url)
  {
     self.wait();
     OAT.Dom.hide('u_profile_l');
     OAT.Dom.hide('u_profile_r');
     OAT.Dom.hide('messages_div');
     OAT.Dom.hide('contacts_interface');
     OAT.Dom.hide('invitations_C');
     OAT.Dom.hide('generalSearch_C');

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
   
   if($('loginDiv') && $('loginDiv').style.display!='none') return; //checks if login is show.. so login disables wait div
   if($('dimmerMsg') && $('dimmerMsg').style.display!='none') return; //checks if dimmer message is shown.
   
   if(OAT.Dimmer.root || waitState=='hide')
   {
    if(OAT.Dimmer.root)
    {
       OAT.Dimmer.hide();
    }
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
  
  this.dimmerMsg = function (msg,callback)
  {
      var div=OAT.Dom.create('div',{background: '#FFF',cursor:'pointer',padding:'10px'})
      div.innerHTML=''+msg;
      div.id='dimmerMsg';
      if(typeof(callback) == "function")
      {
       OAT.Event.attach(div,"click",function(){OAT.Dimmer.hide();callback()});  
      }
      else
       OAT.Event.attach(div,"click",function(){OAT.Dimmer.hide();});  

      OAT.Dimmer.hide();
      OAT.Dimmer.show(div,{popup:true});
      OAT.Dom.center(div,1,1);
      
      if(typeof(callback) == "function")
         OAT.Dom.attach(OAT.Dimmer.root,"click",callback);


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
    if(applicationType=='InstantMessenger')
       applicationType='Instant Messenger';
       
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

//
  this.invitationsGet = function (extraFields,callbackFunction){
    
    self.wait();
    var data = 'sid='+self.session.sid+'&extraFields='+encodeURIComponent(extraFields);
      
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
                                         
    OAT.AJAX.POST(self.session.endpoint+"invitationsGet", data, callback, ajaxOptions);
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
  this.connectionSet = function (connectionId,action,callbackFunction){
    
    //action invite 1,confirm 2, disconnect 0
    
    self.wait();
    var data = 'sid='+self.session.sid+'&connectionId='+connectionId+'&action='+action;
      
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
                                         
    OAT.AJAX.POST(self.session.endpoint+"connectionSet", data, callback, ajaxOptions);
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

  this.feedStatusSet = function (feedId,feedStatus,callbackFunction){
    
    self.wait();
    var data = 'sid='+self.session.sid+'&feedId='+feedId+'&feedStatus='+feedStatus;
      
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
                                         
    OAT.AJAX.POST(self.session.endpoint+"feedStatusSet", data, callback, ajaxOptions);
  }

  this.feedStatus = function (callbackFunction){
    
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
                                         
    OAT.AJAX.POST(self.session.endpoint+"feedStatus", data, callback, optionsSynch);
  }

  this.userMessages = function (msgType,callbackFunction){
    
//    self.wait();
    
    var data = 'sid='+self.session.sid+'&msgType='+msgType;
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }
//                                           else
//                                           {
//                                            self.wait();
//                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"userMessages", data, callback, ajaxOptions);
  };

  this.userMessageSend=function(recipientId,msg,senderId,callbackFunction)
   {
    self.wait();
    
    var data = 'sid='+self.session.sid+'&recipientId='+recipientId+'&msg='+encodeURIComponent(msg);
    if(typeof(senderId)!='undefined' && senderId)
      data = data +'&senderId='+senderId;
      
    var callback = function(xmlString) {
                                           var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                           if(!self.session.isErr(xmlDoc))
                                           {
                                              var respObj=buildObjByAttributes(OAT.Xml.xpath(xmlDoc, '/userMessageSend_response/message',{})[0])
   
                                              if(respObj.status==1)
                                              {
                                               OAT.Dom.show($('msgSentTxt'));
                                               setTimeout(function(){OAT.Dom.hide($('msgSentTxt'))}, 3000);
                                               OAT.Dom.show($('msgSentTxtWin'));
                                               setTimeout(function(){OAT.Dom.hide($('msgSentTxtWin'))}, 3000);
                                              }
                                             if(typeof(callbackFunction) == "function")
                                                callbackFunction(xmlDoc);
                                           }else
                                           {
                                              self.wait();
                                           }
                                       };
                                         
    OAT.AJAX.POST(self.session.endpoint+"userMessageSend", data, callback, optionsSynch);
  };

  this.userMessageStatusSet=function(msgId,msgStatus,callbackFunction)
   {
      self.wait();
    
      var data = 'sid='+self.session.sid+'&msgId='+msgId+'&msgStatus='+msgStatus;
       
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
                                          
      OAT.AJAX.POST(self.session.endpoint+"userMessageStatusSet", data, callback, ajaxOptions);
   };

   this.search=function(searchParamsStr,callbackFunction)
   {
      self.wait();
    
      var data = 'sid='+self.session.sid+'&searchParams='+encodeURIComponent(searchParamsStr);
       
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
                                          
      OAT.AJAX.POST(self.session.endpoint+"search", data, callback, optionsSynch);
   };

   this.searchContacts=function(searchParamsStr,callbackFunction)
   {
      self.wait();
    
      var data = 'sid='+self.session.sid+'&searchParams='+encodeURIComponent(searchParamsStr);
       
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
                                          
      OAT.AJAX.POST(self.session.endpoint+"searchContacts", data, callback, optionsSynch);
   };

   this.tagSearchResult=function(tagParamsStr,callbackFunction)
   {
      self.wait();
    
      var data = 'sid='+self.session.sid+'&tagParams='+encodeURIComponent(tagParamsStr);
       
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
                                          
      OAT.AJAX.POST(self.session.endpoint+"tagSearchResult", data, callback, ajaxOptions);
   };


   this.serverSettings=function()
   {
      var data = '';
       
      var callback = function(xmlString) {
                                            var xmlDoc = OAT.Xml.createXmlDoc(xmlString);
                                            if(!self.session.isErr(xmlDoc))
                                            {
                                               if(!self.uriqaDefaultHost)
                                                   self.uriqaDefaultHost=OAT.Xml.textValue(OAT.Xml.xpath(xmlDoc, '/serverSettings_response/uriqaDefaultHost',{})[0]);
                                            }
                                        };
                                          
      OAT.AJAX.POST(self.session.endpoint+"serverSettings", data, callback, ajaxOptions);
   };

   this.ui=
   {
    newMsgWin:function(anchorObj,sendToUid)
    {
      if($('sendBlockWin'))
         OAT.Dom.unlink($('sendBlockWin').parentNode.parentNode); 
      
      var msgWin = self.ui.newWindow({close:1,resize:1,width:400,height:140,title:'New Message'},OAT.WindowData.TYPE_RECT);
//      msgWin.div.className = "errorWin";
      
      var div=self.ui.renderSendBlock(sendToUid)
      
      OAT.Dom.show(msgWin.div);
      OAT.Dom.clear(msgWin.content);
      OAT.Dom.append([msgWin.content,div]);

      var pos = OAT.Dom.position(anchorObj);
      var size = OAT.Dom.getWH(anchorObj);
      if(isNaN(size[0])) size[0]=0;

      msgWin.anchorTo(pos[0]+size[0]-5,pos[1]);
   },
    newWindow:function(options,type,parent)
    {
     if (!parent) parent = document.body;
     if (!type)   type = 0;
     var win = new OAT.Window(options,type);
     win.onclose = function() { OAT.Dom.hide(win.div); }
 //  l.addLayer(win.div);
 //  win.resize._Resize_movers[0][2] = function(x,y){return x < 150 || y < 50;}
     var keyPress = function(event) {
      if (event.keyCode == 27) { win.onclose(); }
     }
     OAT.Dom.attach(win.div,"keypress",keyPress);
     OAT.Dom.append([parent,win.div]);
     return win;
    },
    

   renderSendBlock:function (sendToUid)
   {
        if (typeof(sendToUid)=='undefined')
            var sendToUid=-1;
            
        var selectedUid=false;
            
        var container=OAT.Dom.create("div",{textAlign:'center'});
        container.id='sendBlockWin';
        
        var _span=OAT.Dom.create('span',{cssFloat:'left',padding:'5px 0px 0px 5px'});
        _span.innerHTML='To:';
        var msgUserSpan=OAT.Dom.create('span',{width:'45%',cssFloat:'left',textAlign:'left',padding:'5px 0px 0px 5px'});
        msgUserSpan.id='msgUserSpanWin';
        
        var userList = OAT.Dom.create("select",{width:'45%',cssFloat:'right',margin:'0px 3px 5px 0px'});
        userList.id = 'userListWin';
        OAT.Dom.option('&lt;Select recipient&gt;',-1,userList);
        for (var i=0;i<self.session.connections.length;i++)
        {
         for(cId in self.session.connections[i])
         {
          OAT.Dom.option(self.session.connections[i][cId],cId,userList);
          
          if(cId==sendToUid)
          {
             userList.selectedIndex=userList.options.length-1;
             msgUserSpan.innerHTML=self.session.connections[i][cId];
             selectedUid=cId;
          } 
         }
        }

        OAT.Event.attach(userList,"change",function(e){ var t=eTarget(e);
                                                        if(t.options[t.selectedIndex].value==-1)
                                                           $('msgUserSpanWin').innerHTML='';
                                                        else
                                                           $('msgUserSpanWin').innerHTML=t.options[t.selectedIndex].text;
                    
                                                        $('sendBtnWin').sendto=t.options[t.selectedIndex].value;

                                                     });
        OAT.Event.attach(userList,"click",function(e){ userList.style.color='#000';});

        var msgText=OAT.Dom.create('textarea',{width:'97%'});
        msgText.id='msgTextWin';
        
        
        
        var sendBtn=OAT.Dom.create('input');
        sendBtn.id='sendBtnWin';
        sendBtn.type='button';
        if(!selectedUid)
            sendBtn.sendto=-1;
        else sendBtn.sendto=selectedUid;
        sendBtn.value='Send';

        OAT.Event.attach(sendBtn,"click",function(e){ var t=eTarget(e);

                                                       if(t.sendto==-1)
                                                       {
                                                          userList.style.color='#f00';
                                                          userList.focus();
                                                          return;
                                                       }
                                                       if($('msgTextWin').value.length==0)
                                                       {
                                                          $('msgTextWin').focus();
                                                          return;
                                                       }
                                                       userList.style.color='#000';
                                               
                                                       self.userMessageSend(t.sendto,$('msgTextWin').value,false,function(){self.wait('hide');})
                                                       
                                                     });

        var msgSentTxt=OAT.Dom.create('span',{color:'green',cssFloat:'right',padding:'0px 5px 0px 0px',display:'none',marginTop:'-18px'});
        msgSentTxt.id='msgSentTxtWin';
        msgSentTxt.innerHTML=" Message sent! ";

        
      OAT.Dom.append([container,_span,msgUserSpan,userList,OAT.Dom.create('br'),msgText,OAT.Dom.create('br'),sendBtn,msgSentTxt]);

        return container;
   }
  } //end ui
  
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
  this.odsLink = function(extPath)
  {
    var odsLink = '';
    var odsHost = self.uriqaDefaultHost ? self.uriqaDefaultHost :document.location.host;
    
    if(typeof(extPath)!='undefined')
       odsLink=document.location.protocol+'//'+odsHost+extPath;
    else
       odsLink=document.location.protocol+'//'+odsHost;
  
    return odsLink;
  }
  
  self.serverSettings()
  var uriParams=OAT.Dom.uriParams();
  var cookieSid=this.readCookie('sid');
  
  if(!self.session.sid && typeof(uriParams['openid.signed'])!='undefined' && uriParams['openid.signed']!='')
  {
    self.session.openId.server=uriParams['oid-srv'];
    self.session.openId.sig=uriParams['openid.sig'];
    self.session.openId.identity=uriParams['openid.identity'];
    self.session.openId.assoc_handle=uriParams['openid.assoc_handle'];
    self.session.openId.signed=uriParams['openid.signed'];
    
    self.session.openIdVerify();
  }else if(typeof(uriParams.sid)!='undefined' && uriParams.sid!='')
  {
    self.session.sid=uriParams.sid;
    self.session.validateSid();
  }else if(!self.session.sid && cookieSid)
  {
    self.session.sid=cookieSid;
    self.session.validateSid();
  }else
  {
    OAT.MSG.send(self.session,OAT.MSG.SES_VALIDATION_END,{sessionValid:0});
  };
 
  OAT.Event.attach($('vspxApp'),"load",function(){self.wait('hide');});  
  OAT.Event.attach($('vspxApp'),"load",function(){
                                                   if(!self.session.sid)
                                                   {                                                  
                                                      var getParams= OAT.Dom.isIE() ? $('vspxApp').contentWindow.location.href : $('vspxApp').contentDocument.location.search;
                                                     
                                                      if(getParams.indexOf('sid=')>-1)
                                                      {
                                                       var iframeSid=getParams.substring(getParams.indexOf('sid=')+4,getParams.length);
                                                       iframeSid=iframeSid.substring(0,iframeSid.indexOf('&'));
                                                       
                                                        self.session.sid=iframeSid;
                                                        self.session.validateSid();
                                                      }
                                                   }
  }
                  );

  if($('search_textbox'))
  {  $('search_textbox').callback=function(e){
                                               if($('search_lst_sort'))
                                                  $('search_lst_sort').selectedIndex=0;
                                               if($('search_focus_sel'))
                                                  $('search_focus_sel').selectedIndex=0;
  
                                              var t=eTarget(e);

                                              if(t && t.value && t.value.length<2)
  {
                                               self.dimmerMsg('Invalid keyword string entered.');
                                               return;
                                              }

                                              if(t && t.value && t.value.length>0)
                                              {
//                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx?q='+encodeURIComponent(t.value.trim())));

                                                 $('search_textbox_searchC').value=t.value;
                                                 self.search('q='+encodeURIComponent(t.value.trim())+'&on_all=1',self.renderSearchResults);

  }
                                          };
     OAT.Event.attach($('search_textbox'),"keypress",onEnterDown);  
  };
  OAT.Event.attach($('search_textbox'),"keypress",onEnterDown);  

  if($('search_img'))
  {  $('search_img').callback=function(){
                                            if($('search_lst_sort'))
                                               $('search_lst_sort').selectedIndex=0;
                                            if($('search_focus_sel'))
                                               $('search_focus_sel').selectedIndex=0;

                                            var t=$('search_textbox');

                                            if(t && t.value && t.value.length<2)
  {
                                               self.dimmerMsg('Invalid keyword string entered.');
                                               return;
  }
    
//                                            if(t && t.value && t.value.length>0)
//                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx?q='+encodeURIComponent(t.value.trim())));
//                                            else
//                                                nav.loadVspx(nav.expandURL(nav.ods+'search.vspx'));

                                            if(t && t.value && t.value.length>0)
                                            {

                                               $('search_textbox_searchC').value=t.value;
                                               self.search('q='+encodeURIComponent(t.value.trim())+'&on_all=1',self.renderSearchResults);
                                            }
                                            else
                                                self.showSearch();
     
  

                                          };
  };
  
  
  this.initLeftBar();
  this.initRightBar()
  this.initAppMenu();
  this.initSearch();


}  

var navOptions ={leftbar  : 'ods_logo',
                 rightbar : 'ODS_BAR',
                 appmenu  : 'APP_MENU_C'
                }

ODSInitArray.push(initNav);

var nav=false;

var options=false;
var optionsSynch=false;
var optionsGet=false;

function initNav ()
{
  
  OAT.MSG.SES_TOKEN_RECEIVED = 30;
  OAT.MSG.SES_VALID          = 31;
  OAT.MSG.SES_VALIDBIND      = 32;
  OAT.MSG.SES_INVALID        = 33;
  OAT.MSG.SES_VALIDATION_END  = 34;
  OAT.MSG.PROFILE_UPDATED     = 51;
  OAT.MSG.CONNECTIONS_UPDATED = 52;
  
  
  options = {auth:OAT.AJAX.AUTH_BASIC,
             noSecurityCookie:1,
             onerror:function(request) { dd(request.getStatus()); }
            };
  
  optionsSynch = {auth:OAT.AJAX.AUTH_BASIC,
                  async:false,
                  onerror:function(request) { dd(request.getStatus()); }
                 };
  optionsGet = {auth:OAT.AJAX.AUTH_NONE,
                noSecurityCookie:1,
                onerror:function(request) { dd(request.getStatus()); }
               };

  var vpsize=OAT.Dom.getViewport();
  $('RT').style.width=vpsize[0]-168+'px';

  $('vspxApp').style.height=vpsize[1]-80+'px';

  nav=new ODS.Nav(navOptions);
  
  
}
