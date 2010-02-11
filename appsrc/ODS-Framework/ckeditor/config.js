/*
Copyright (c) 2003-2010, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
	// Define changes to default configuration here. For example:
  config.skin = 'kama';
  config.height = '170px';
  config.width = '100%';
	config.language = 'en';
	config.uiColor = '#F3F3EE';
	config.newpage_html = '';
  config.toolbar_Full = [
                         ['Source','-','Preview'],
                         ['Cut','Copy','Paste','-','Print', 'SpellChecker'],
                         ['Undo','Redo','-','Find','Replace','-','SelectAll','RemoveFormat'],
                         '/',
                         ['Bold','Italic','Underline','Strike','-','Subscript','Superscript'],
                         ['NumberedList','BulletedList','-','Outdent','Indent','Blockquote'],
                         ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
                         ['Link','Unlink','Anchor'],
                         ['Image','Flash','Table','Smiley','SpecialChar'],
                         '/',
                         ['Styles','Format','Font','FontSize'],
                         ['TextColor','BGColor']
                        ];
  config.toolbar_Basic = [
                          ['Source','-','Preview'],
                          ['Cut','Copy','Paste','-','Print', 'SpellChecker'],
                          ['Undo','Redo','-','Find','Replace','-','SelectAll','RemoveFormat'],
                          '/',
                          ['Bold','Italic','Underline','Strike'],
                          ['NumberedList','BulletedList','-','Outdent','Indent'],
                          ['JustifyLeft','JustifyCenter','JustifyRight','JustifyBlock'],
                          ['Link','Unlink','Anchor'],
                          ['Image','Flash','Table','Smiley','SpecialChar'],
                          '/',
                          ['Styles','Format','Font','FontSize'],
                          ['TextColor','BGColor']
                         ];
  config.toolbar = 'Basic';
  config.removePlugins = 'elementspath';
  config.resize_enabled = false;
  config.on = { instanceReady : function( ev )
                  {
                      this.dataProcessor.writer.lineBreakChars = '';

                      // Output paragraphs as <p>Text</p>.
                      this.dataProcessor.writer.setRules( 'p',
                          {
                              indent : false,
                              breakBeforeOpen : true,
                              breakAfterOpen : false,
                              breakBeforeClose : false,
                              breakAfterClose : true
                          });
                  }
              };
  // config.filebrowserImageBrowseUrl = function(){davBrowse('ss');};
	config.baseFloatZIndex = 51;
};
