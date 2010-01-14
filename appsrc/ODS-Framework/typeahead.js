// TypeAhead - a javascript auto-complete functionality for web forms.
// v1.1 - May 7th 2005
// Copyright (c) 2005 Cédric Savarese <pro@4213miles.com>
// This software is licensed under the CC-GNU LGPL <http://creativecommons.org/licenses/LGPL/2.1/>

// Change Log
// v1.1 Added Suggestion drop-down ('google suggests' style)

// Modified By Anton Avramov for OpenLink eCRM purposes
// $Id$
// Modified By Anton Avramov for OpenLink eCRM purposes
// $Id$

function TypeAhead(pInputId,pKey,pDepend)
{
	this.typeAheadServiceURL = "/ods/api/lookup.list?key=" + encodeURIComponent(pKey);
	this.inputId = pInputId;		    // id of the text input
	this.inputElement = null;		    // reference to the text input element
	this.suggestions = new Array();	// list of suggestions retrieved for the given input id
	this.suggestedText = "";		    // latest suggested text
	this.userText = "";				      // latest user typed text
	this.suggestionDropDown = null; // reference to the Drop Down DIV w/ the list of suggestions
	this.hasFocus = 0;
	var suggestedIndex = 0;			    // index of the selected suggestion in the Drop Down list (changed w/ up & down arrows)
	var isWaitingForSuggestions = false;
	var self = this;				        // TypeAhead object reference
	var HTTPReq; 					          // HTTP Request object reference
	var HTTPReqPost;
	//var pressedKeyCount=0;
	this.depend = $(pDepend);

	var debugOutput = $('eCRMdebugOutput'); // Debug Output
	function debug(text)
	{
		if(typeof debugOutput != "undefined" && debugOutput)
			debugOutput.innerHTML = debugOutput.innerHTML+"<br /><hr />"+text;
	}

	this.init = function()
	{
		debug("TypeAhead Object Initialization");
		if(window.ActiveXObject)
			HTTPReq = new ActiveXObject("Microsoft.XMLHTTP");
		else
			HTTPReq = new XMLHttpRequest();

		if (HTTPReq)
		{
			if(!self.inputElement && self.inputId) self.inputElement = $(self.inputId);
			if(self.inputElement)
			{
				// create markup for drop-down list of suggestions
				self.suggestionDropDown = $("THDropDown-" + self.inputId);
				if(!self.suggestionDropDown)
				{
					var pos = OAT.Event.position(self.inputElement);
					self.suggestionDropDown = document.createElement('DIV');
					self.suggestionDropDown.id = "THDropDown-" + self.inputId;
					self.suggestionDropDown.className = "THHideDropDown";
					self.suggestionDropDown = self.inputElement.parentNode.insertBefore(self.suggestionDropDown, self.inputElement.nextSibling);
					self.suggestionDropDown.style.top =  (pos[1] + self.inputElement.offsetHeight + 2).toString() + "px";
					self.suggestionDropDown.style.left = pos[0].toString() + "px";
					self.suggestionDropDown.style.width = self.inputElement.offsetWidth.toString() + "px";
				}
				//init suggestions array with something
				//self.getSuggestions();
				//handle user input
				self.inputElement.onkeyup = function (evt) {
					if(!evt) evt = window.event;

					switch(evt.keyCode) {
						case 8: // backspace
							self.userText = self.inputElement.value;
							suggestedIndex = 0;
							isWaitingForSuggestions = true;
							self.getSuggestions();
							return; // no suggest on backspace
						case 46: // delete
							self.userText = self.inputElement.value;
							suggestedIndex = 0;
							isWaitingForSuggestions = true;
							self.getSuggestions();
							return; // no suggest on backspace
						case 40:	// arrow down
							if(suggestedIndex < self.suggestions.length) suggestedIndex ++;
							self.suggest();
							self.divScroll();
							break;
						case 38:	// arrow up
							if(suggestedIndex > 1) suggestedIndex --;
							self.suggest();
							self.divScroll();
							break;
						case 33:	// page up
							if(suggestedIndex > self.divPageSize()) suggestedIndex -= self.divPageSize();
							else suggestedIndex = 1;
							self.suggest();
							self.divScroll();
							break;
						case 34:	// page down
							if(suggestedIndex < self.suggestions.length - self.divPageSize()) suggestedIndex += self.divPageSize();
							else suggestedIndex = self.suggestions.length;
							self.suggest();
							self.divScroll();
							break;
						default:
						  //if(!evt.keyCode == 9)
								//pressedKeyCount--;
							if (self.userText != self.inputElement.value) {
								suggestedIndex = 0;
								self.userText = self.inputElement.value.toLowerCase();
								self.suggest();
							}
					}
				}
				self.inputElement.onkeydown = function (evt) {
					if(!evt) evt = window.event;
					//if(evt.keyCode != 8 &&
					//	 evt.keyCode != 46 &&
					//	 evt.keyCode != 40 &&
					//	 evt.keyCode != 38 &&
					//	 evt.keyCode != 33 &&
					//	 evt.keyCode != 33 &&
					//	 evt.keyCode != 9)
					//	pressedKeyCount++;
				}
				self.inputElement.onfocus = function(evt) {
					self.hasFocus = 1;
					self.userText = self.inputElement.value;
					suggestedIndex = 0;
					isWaitingForSuggestions = true;
					self.getSuggestions();
				}
				// hides the suggestion drop-down when input field not in focus
				self.inputElement.onblur = function(evt) {
					self.hasFocus = 0;
					window.setTimeout(function() {
					   self.suggestionDropDown.className = self.suggestionDropDown.className.replace("THShowDropDown","THHideDropDown");
					   },500);
				}
			}
		}
	}

	this.getSuggestions = function(text)
	{
		if(text) self.userText = text;
		HTTPReq.abort();
		HTTPReq.onreadystatechange = self.populateSuggestions;
		var sURL = self.typeAheadServiceURL + "&input="+encodeURIComponent(self.userText);
		if (self.depend)
		  sURL += "&depend="+encodeURIComponent(self.depend.value);
		HTTPReq.open("GET", sURL, true);
		HTTPReq.send(null);
		debug("request sent: " + sURL);
	}

	this.populateSuggestions = function(evt)
	{
	  if (HTTPReq.readyState == 4)
	  {
	  	self.suggestions = HTTPReq.responseText.split("\n").clean("");
		  debug("response: "+ HTTPReq.responseText);
		  if(isWaitingForSuggestions) self.showSuggestionList();
	  }
	}

	this.suggest = function(text)
	{
		if (!HTTPReq) return;
		if (text) self.userText = text;
		//if(self.userText == "") return;
		self.suggestedText = "";

		if (suggestedIndex==0)
		{
			//search for one matching suggestion
			var newSuggestionArray = new Array();
			for (var i=0; i < self.suggestions.length; i++)
			{
				if (self.suggestions[i].toLowerCase().indexOf(self.userText.toLowerCase()) == 0)
				{
					if(self.suggestedText == "")
						self.suggestedText = self.suggestions[i];
					newSuggestionArray[newSuggestionArray.length] = self.suggestions[i];
				} else {
					// non-matching suggestion. will be removed from the array.
				}
			}
			self.suggestions = newSuggestionArray;
		} else {
			// used up/down arrow key to select in the drop-down list
			self.suggestedText = self.suggestions[suggestedIndex-1];
		}
		if (self.suggestedText=="")
    {
      // no matching suggestions in store, get more from the server.
      debug("loading more suggestions...");
      isWaitingForSuggestions = true;
      self.getSuggestions();
    } else {
      isWaitingForSuggestions = false;
      debug("suggestion: "+self.suggestedText);
      //if(pressedKeyCount==0) { // can't suggest if more than one key is pressed at the same time
      if (suggestedIndex != 0)
      {
        var startIndex = self.inputElement.value.length;
        self.inputElement.value = self.suggestedText;
        if (self.inputElement.onchange)
          self.inputElement.onchange(self.inputElement);
        this.selectText(startIndex, self.suggestedText.length);
      }
      self.showSuggestionList();
    }

  }

  this.selectText = function(startIndex, nbChars)
  {
    if (self.inputElement.createTextRange)
    { // for Internet Explorer
      var txtRange = self.inputElement.createTextRange();
      txtRange.moveStart("character", startIndex);
      txtRange.moveEnd("character", nbChars - self.inputElement.value.length);
      txtRange.select();
    }
    else if (self.inputElement.setSelectionRange)
    { // for Mozilla
       self.inputElement.setSelectionRange(startIndex, nbChars);
    }
    //set focus back to the textbox
    self.inputElement.focus();
  }

  this.showSuggestionList = function()
  {
    var htmlList="";
    for (var i=0; i < self.suggestions.length; i++)
    {
      if (self.suggestions[i].toLowerCase().indexOf(self.userText.toLowerCase()) == 0)
      {
        htmlList += "<li";
        if (suggestedIndex-1 == i)
          htmlList += " class='THLIHover'";
        htmlList += " onclick='var x = $(\"" + self.inputId + "\"); x.value=\"" + self.suggestions[i] + "\"; if (x.onchange) x.onchange(x);' onmouseover='this.className+=\" THLIHover\"' onmouseout='this.className=this.className.replace(\"THLIHover\",\"\")' >" + self.suggestions[i] + "</li>";
      }
    }
    if (htmlList=="")
      if (!isWaitingForSuggestions)
        self.suggestionDropDown.innerHTML = "<ul><li>loading more suggestions...</li></ul>";
      else
        self.suggestionDropDown.innerHTML = "<ul><li>no suggestion available</li></ul>";
    else
      self.suggestionDropDown.innerHTML = "<ul>"+htmlList+"</ul>";
    self.suggestionDropDown.className = self.suggestionDropDown.className.replace("THHideDropDown","THShowDropDown");
  }

  this.divPageSize = function ()
  {
    var elem = $("THDropDown-" + self.inputId);
    var rowlen = elem.scrollHeight / self.suggestions.length;
    return Math.floor(elem.clientHeight / rowlen) - 1;
  }

  this.divScroll = function ()
  {
    var elem = $("THDropDown-" + self.inputId);
    var rowlen = elem.scrollHeight / self.suggestions.length;
    if (suggestedIndex * rowlen > elem.scrollTop + elem.clientHeight)
    {
      elem.scrollTop = (suggestedIndex - 1) * rowlen;
    }
    if ((suggestedIndex - 1) * rowlen < elem.scrollTop)
    {
      elem.scrollTop = suggestedIndex * rowlen - elem.clientHeight;
    }
  }

  //  Initialize instance
  this.init();
}

// Utility function
var XBrowserAddHandler = function (target,eventName,handlerName)
{
  if (!target) return;
  if (target.addEventListener)
  {
    target.addEventListener(eventName, function(e){eval(handlerName)(e);}, false);
  }
  else if (target.attachEvent)
  {
    target.attachEvent("on" + eventName, function(e){eval(handlerName)(e);});
  }
  else
  {
    // THIS CODE NOT TESTED
    var originalHandler = target["on" + eventName];
    if (originalHandler)
    {
      target["on" + eventName] = function(e){originalHandler(e);eval(handlerName)(e);};
    } else {
      target["on" + eventName] = eval(handlerName);
    }
  }
}

Array.prototype.clean = function(to_delete)
{
  var a;
  for (a = 0; a < this.length; a++)
  {
    if (this[a] == to_delete)
    {
      this.splice(a, 1);
      a--;
    }
  }
  return this;
}

taVars = new Array();
function CheckSubmit()
{
  for (var i=0; i < taVars.length; i++)
  {
    if (taVars[i].suggestionDropDown && taVars[i].suggestionDropDown.className == 'THShowDropDown' && taVars[i].hasFocus == 1)
    {
      nextFocus(taVars[i].inputElement);
      return false;
    }
  }
  return true;
}

function nextFocus(elem)
{
  var frm = elem.form;
  for(var i=0; i < frm.elements.length; i++)
    if (frm.elements[i].tabIndex == elem.tabIndex + 1)
    {
      frm.elements[i].focus();
      return;
    }
}
