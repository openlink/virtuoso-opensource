--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
-- SET echo on;
SET MACRO_SUBSTITUTION OFF;
USE "Portal";

-- 

-- =======================================================
-- INSERT INITIAL DATA INTO IBUYSPY Portal DB
-- =======================================================

-- insert some initial template values

DELETE FROM MODULEDEFINITIONS; 
DELETE FROM LINKS;
DELETE FROM ANNOUNCEMENTS;
DELETE FROM CONTACTS;
DELETE FROM EVENTS;
DELETE FROM DOCUMENTS;
DELETE FROM DISCUSSION;
DELETE FROM HTMLTEXT;
DELETE FROM MODULESETTINGS;
DELETE FROM MODULES;
DELETE FROM USERROLES;
DELETE FROM ROLES;
DELETE FROM TABS;
DELETE FROM PORTALS;

DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Portals',		'PortalID', -1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Modules',		'ModuleID',  0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Tabs',			'TabID',     0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Links',		'ItemID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Announcements',	'ItemID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Contacts',		'ItemID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Events',		'ItemID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Documents',		'ItemID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Discussion',		'ItemID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Roles',		'RoleID',    0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Users',		'UserID',    1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.ModuleDefinitions',	'ModuleDefID',    1);

INSERT INTO PORTALS (PortalAlias,PortalName,AlwaysShowEditButton) VALUES ('unused','Unused Portal',0);

INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (0,-1,'Unused Tab','Unused Tab','All Users;',0);


INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Announcements','DesktopModules/Announcements.ascx','MobileModules/Announcements.ascx');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Contacts','DesktopModules/Contacts.ascx','MobileModules/Contacts.ascx');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Discussion','DesktopModules/Discussion.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Events','DesktopModules/Events.ascx','MobileModules/Events.ascx');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Html Document','DesktopModules/HtmlModule.ascx','MobileModules/Text.ascx');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Image','DesktopModules/ImageModule.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Links','DesktopModules/Links.ascx','MobileModules/Links.ascx');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'QuickLinks','DesktopModules/QuickLinks.ascx','MobileModules/Links.ascx');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'XML/XSL','DesktopModules/XmlModule.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Documents','DesktopModules/Document.ascx','');

INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (0,1,1,'','Unused Module','All Users;',0,0);
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Module Types (Admin)','Admin/ModuleDefs.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Roles (Admin)','Admin/Roles.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Tabs (Admin)','Admin/Tabs.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Site Settings (Admin)','Admin/SiteSettings.ascx','');
INSERT INTO ModuleDefinitions(PortalID,FriendlyName,DesktopSrc,MobileSrc) VALUES (0,'Manage Users (Admin)','Admin/Users.ascx','');

-- insert templated records for each module type
INSERT INTO LINKS (ModuleID) VALUES (0);
INSERT INTO EVENTS (ModuleID) VALUES (0);
INSERT INTO ANNOUNCEMENTS (ModuleID) VALUES (0);
INSERT INTO CONTACTS (ModuleID) VALUES (0);
INSERT INTO DOCUMENTS (ModuleID) VALUES (0);
INSERT INTO DISCUSSION (ModuleID, Title, Body, DisplayOrder, CreatedByUser) VALUES (0,'','','','');

-- insert default IBuySpy Store data
INSERT INTO PORTALS (PortalAlias,PortalName,AlwaysShowEditButton) VALUES ('p_default','IBuySpy Portal',0);
INSERT INTO ROLES (PortalID,RoleName) VALUES (0,'Admins');
INSERT INTO USERS (Name, "Password", Email) VALUES ('Guest','guest','guest');
INSERT INTO UserRoles (UserID,RoleID) VALUES (1,0);
INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (0,0,'Home','Home','All Users;',1);
INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (1,0,'Employee Info','HR','All Users;',1);
INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (2,0,'Product Info','Products','All Users;',1);
INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (3,0,'Discussions','Discussions','All Users;',0);
INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (4,0,'About the Portal','About','All Users;',1);
INSERT INTO TABS (TabOrder,PortalID,TabName,MobileTabName,AuthorizedRoles,ShowMobile) VALUES (5,0,'Admin','Admin','Admins;',0);

Commit work;

INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (1,8,1,'LeftPane','Quick Links','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (1,5,1,'ContentPane','Welcome to the IBuySpy Portal','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (1,1,2,'ContentPane','News and Features','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (1,4,3,'ContentPane','Upcoming Events','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (1,5,1,'RightPane','This Week\'s Special','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (1,9,2,'RightPane','Top Movers','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (2,5,1,'LeftPane','Spy Diary','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (2,1,1,'ContentPane','HR/Benefits','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (2,2,2,'ContentPane','Employee Contact Information','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (2,10,3,'ContentPane','New Employee Documentation','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (3,5,1,'LeftPane','Spy Diary','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (3,1,1,'ContentPane','Competition: TradeCraft','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (3,1,2,'ContentPane','Competition: Surveillance','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (3,1,3,'ContentPane','Competition: Protection','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (3,6,1,'RightPane','Night Vision Goggles','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (3,8,2,'RightPane','Competitors to Watch','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (4,5,1,'LeftPane','Spy Diary','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (4,3,1,'ContentPane','TradeCraft Techniques and Gear','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (4,3,2,'ContentPane','Recipes From the Field','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (4,10,3,'ContentPane','GoodReads','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,8,1,'LeftPane','Quick Links','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,5,1,'ContentPane','About the IBuySpy Portal Sample','Admins',0,1);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,5,2,'ContentPane','Portal Tabs','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,5,3,'ContentPane','Portal Modules','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,5,4,'ContentPane','Managing the Portal','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,5,5,'ContentPane','Managing Portal Layout','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (5,5,6,'ContentPane','Managing User Security','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (6,11,1,'RightPane','Module Definitions','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (6,14,1,'ContentPane','Site Settings','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (6,13,2,'ContentPane','Tabs','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (6,12,3,'ContentPane','Security Roles','Admins',0,0);
INSERT INTO MODULES (TabID,ModuleDefID,ModuleOrder,PaneName,ModuleTitle,AuthorizedEditRoles,CacheTime,ShowMobile) VALUES (6,15,4,'ContentPane','Manage Users','Admins',0,0);


INSERT INTO ModuleSettings(ModuleID,SettingName,SettingValue) VALUES (6,'xmlsrc','~/data/sales.xml');
INSERT INTO ModuleSettings(ModuleID,SettingName,SettingValue) VALUES (6,'xslsrc','~/data/sales.xsl');
INSERT INTO ModuleSettings(ModuleID,SettingName,SettingValue) VALUES (15,'src','~/data/nightvis.gif');

INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (1,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'ASP.NET Site','http://www.asp.net','',1,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (1,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'GotDotNet.com','http://www.gotdotnet.com','',3,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (1,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'ASP.NET on MSDN','http://msdn.microsoft.com/net/aspnet','',5,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (1,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'QuickStart Samples','http://www.gotdotnet.com/quickstart/aspplus','',7,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (16,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'SpyWorld','http://www.SpyWorld.com','',1,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (16,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'SpyGear4U','http://www.SpyGear4U.com','',3,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (16,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'GlobalSpy','http://www.GlobalSpy.com','',5,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (16,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'SpyProducts','http://www.SpyProducts.com','',7,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (21,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'ASP.NET Site','http://www.asp.net','',1,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (21,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'GotDotNet.com','http://www.gotdotnet.com','',3,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (21,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'ASP.NET on MSDN','http://msdn.microsoft.com/net/aspnet','',5,'');
INSERT INTO LINKS (ModuleID,CreatedByUser,CreatedDate,Title,Url,MobileUrl,ViewOrder,Description) VALUES (21,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:41:40.840'),'QuickStart Samples','http://www.gotdotnet.com/quickstart/aspplus','',7,'');

INSERT INTO EVENTS (ModuleID,CreatedByUser,CreatedDate,Title,ExpireDate,Description,WhereWhen) VALUES (4,'JennaJ@ibuyspy.com', stringdate ('2001-12-19 15:46:25.053'),'Spy-o-Rama', stringdate ('2005-12-31 00:00:00'),'It\'s back!  The premier regional swap meet for spy paraphernalia of every description.  Shop early for some amazing bargins.', 'This Saturday, usual secret time and place...');
INSERT INTO EVENTS (ModuleID,CreatedByUser,CreatedDate,Title,ExpireDate,Description,WhereWhen) VALUES (4,'JennaJ@ibuyspy.com', stringdate ('2001-12-19 15:48:22.813'),'Dark Ops Sock Hop', stringdate ('2005-12-31 00:00:00'),'Back by popular demand!  Practice your surveillance of the opposite sex, and dance some too.  Great opportunity for a brush pass!', 'Saturday, 8pm to ?, Dark Ops Cafe');

INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (8,'JennaJ@ibuyspy.com', stringdate ('2001-12-19 15:46:25.053'),'Open Enrollment and Payroll Checklist','~/admin/notimplemented.aspx?title=Open%20Enrollment%20and%20Payroll%20Checklist','', stringdate ('2005-12-31 00:00:00'),'Please take a few moments to review this year-end checklist that will guide you through the Benefits Open Enrollment process and instruct you on how to ensure your payroll information is accurate for 2001.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (8,'JennaJ@ibuyspy.com', stringdate ('2001-12-19 15:49:05.603'),'Selecting Your Primary Care Provider','~/admin/notimplemented.aspx?title=Selecting%20Your%20Primary%20Care%20Provider','', stringdate ('2005-12-31 00:00:00'),'Learn how to find the Primary Care Provider (PCP) that best suits your needs with this list of things to think about and questions to ask yourself and your potential PCP.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (3,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 11:17:52.903'),'Q4 Sales Rise 200% Over Last Year','~/admin/notimplemented.aspx?title=Q4%20Sales%20Rise%20200%%20Over%20Last%20Year','', stringdate ('2005-12-31 00:00:00'),'IBuySpy online sales for the crucial fourth quarter of last year rose nearly 200% over the previous year, despite a lackluster holiday sales overall. ');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (13,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 06:09:11.117'),'Envelope X-Ray Spray','http://www.spyworld.net/Surveil3.htm','', stringdate ('2005-12-31 00:00:00'),'Envelope X-RAY Spray turns opaque paper temporarily translucent, allowing the user to view the contents of an envelope without ever opening it. SpyWorld, $42.95.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (13,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 06:19:35.883'),'Wrist Watch Video Camera','http://www.spyworld.net/Surveil1.htm','', stringdate ('2005-12-31 00:00:00'),'This is not a device from a James bond movie, but a real, sophisticated video camera disguised as a watch.  SpyWorld, $489.95.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (13,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 10:43:59.150'),'Bionic Ear','http://www.spyworld.net/Surveil3.htm','', stringdate ('2005-12-31 00:00:00'),'Zoom in on a whisper at up to 100 yards away, door shutting at 4 blocks, dog barking up to 2 miles away.  SpyWorld, $198.95.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (13,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 10:44:18.217'),'CAMCopter','http://www.spyworld.com/camcopter.htm','', stringdate ('2005-12-31 00:00:00'),'The CAMCopter is a remotely controlled, autonomous Aerial Vehicle System developed under military specifications design to carry various sensors that transmit data and live video.  SpyWorld, $490,000.00.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (12,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 07:01:58.280'),'Ultraviolet Pen','http://www.spyproducts.com/Theftpowders1.html','', stringdate ('2005-12-31 00:00:00'),'This felt-tipped pen is an inexpensive and convenient ultraviolet writing instrument.  SpyProducts, $6.95.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (12,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 07:06:09.160'),'Micro Bug Detector ','http://www.spygear4u.com/hi_tech.htm','', stringdate ('2005-12-31 00:00:00'),'Covert bug detection probe for room sweeping include a vibration mode.  SpyGear4U, $399.00.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (12,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 07:09:51.920'),'Telephone Voice Changer','http://www.firstlineindustries.com/telvoicchani.html','', stringdate ('2005-12-31 00:00:00'),'Answer the telephone without anyone recognizing your voice.  FirstLine, $42.95.');
INSERT INTO ANNOUNCEMENTS (ModuleID,CreatedByUser,CreatedDate,Title,MoreLink,MobileMoreLink,ExpireDate,Description) VALUES (14,'JennaJ@ibuyspy.com', stringdate ('2002-01-10 06:57:28.190'),'Air Taser','http://www.spyworld.com/3005.htm','', stringdate ('2005-12-31 00:00:00'),'Uses compressed air to shoot two small probes up to 15 feet.  These probes are connected by wire to the launcher, which sends a powerful electric signal into the nervous system of an assailant.  SpyWorld, $285.95.');

INSERT INTO CONTACTS (ModuleID,CreatedByUser,CreatedDate,Name,"Role",Email,Contact1,Contact2) VALUES (9,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 12:58:58.250'),'JennaJ','Program Lead','JennaJ@ibuyspy.com','home: 206-555-4434','mobile: 206-555-8381');
INSERT INTO CONTACTS (ModuleID,CreatedByUser,CreatedDate,Name,"Role",Email,Contact1,Contact2) VALUES (9,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 13:00:19.057'),'ManishG','Technical Lead','ManishG@ibuyspy.com','home: 425-555-9008','mobile: 425-555-7665');
INSERT INTO CONTACTS (ModuleID,CreatedByUser,CreatedDate,Name,"Role",Email,Contact1,Contact2) VALUES (9,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 13:03:55.657'),'BrettH','Development Lead','BrettH@ibuyspy.com','home: 206-555-5580','mobile: 206-555-1323');
INSERT INTO CONTACTS (ModuleID,CreatedByUser,CreatedDate,Name,"Role",Email,Contact1,Contact2) VALUES (9,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:07:31.290'),'MaryK','Test Lead','MaryK@ibuyspy.com','home: 206-555-7729','mobile: 206-555-8585');
INSERT INTO CONTACTS (ModuleID,CreatedByUser,CreatedDate,Name,"Role",Email,Contact1,Contact2) VALUES (9,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 14:07:44.470'),'RajivP','Fullfillment Lead','RajivP@ibuyspy.com','home: 425-555-7787','mobile: 425-555-4443');
INSERT INTO CONTACTS (ModuleID,CreatedByUser,CreatedDate,Name,"Role",Email,Contact1,Contact2) VALUES (9,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 13:02:54.730'),'TomVZ','Secret Agent','TomVZ@ibuyspy.com','shoe phone: 206-555-4433','fountain pen: 206-555-9985');

INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Edible Tape Puttanesca', stringdate ('2001-12-20 14:10:36'),'Had this last night in the Dark Ops Cafe and -- WOW -- is it good!  Red sauce with olives, capers and anchovies.','2001-12-20 14:10:36.317','MaryK@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Re: Edible Tape Puttanesca', stringdate ('2001-12-20 14:11:59'),'Their Edible Tape Carbonara is terrific too.  I think they add number two pencil shavings.','2001-12-20 14:10:36.3172001-12-20 14:11:59.090','JennaJ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Help - need a Survival Bar recipe', stringdate ('2001-12-20 14:25:41'),'My wife\'s boss is coming for dinner this week and we wanted to serve survival bar.  Anybody have a favorite recipe?','2001-12-20 14:25:41.333','RajivP@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Re: Help - need a Survival Bar recipe', stringdate ('2001-12-20 14:26:53'),'I saute it with some garlic and onions in butter and white wine.  When it softens up (about an hour), I finish the dish with a little lemon and pine nuts, and serve over edible tape.  Yum!', '2001-12-20 14:25:41.3332001-12-20 14:26:53.180','ManishG@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Re: Help - need a Survival Bar recipe', stringdate ('2001-12-20 14:28:18'),'Survival bar can be pretty chewy, so I throw it in the pressure cooker for about a half hour with onions, carrots, celery and a bay leaf.','2001-12-20 14:25:41.3332001-12-20 14:28:18.367','TomVZ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Re: Help - need a Survival Bar recipe', stringdate ('2001-12-20 14:29:25'),'There\'s just one thing that can improve a survival bar: Ketchup ;)','2001-12-20 14:25:41.3332001-12-20 14:28:18.3672001-12-20 14:29:25.987','BrettH@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (19,'Eat my shoelaces', stringdate ('2001-12-20 14:30:44'),'I just tried the new Glow in the Dark Shoelaces and they are *yummy*!  Even better with ketchup...','2001-12-20 14:30:44.013','BrettH@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'What\'s the best dead drop mark?', stringdate ('2001-01-08 08:06:52'),'I know this is a total newbie question, but how do I mark a dead drop?  What\'s the best mark?','2001-01-08 08:06:51.607','MaryK@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Re: What\'s the best dead drop mark?', stringdate ('2001-01-08 08:07:59'),'I just use chalk.  It\'s fast, writes on just about anything, and doesn\'t stick around long enough to get noticed.','2001-01-08 08:06:51.6072001-01-08 08:07:59.177','JennaJ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Re: What\'s the best dead drop mark?', stringdate ('2001-01-09 08:15:33'),'I use chalk too -- it\'s really easy to erase.','2001-01-08 08:06:51.6072001-01-08 08:07:59.1772001-01-09 08:15:32.970','BrettH@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Re: What\'s the best dead drop mark?', stringdate ('2001-01-09 08:14:57'),'There are several things to consider in making your mark: it has to made (and later erased) quickly and discretely, durable enough to stick around until it\'s read, easily ignored by passers by, and not missed when it\'s gone.  Lots of folks like chalk, but I find it washes away too easily in rainy weather.  Chewing gum (already chewed) works great, but you\'ll want to place it well below eye level lest some zealous maintenance worker cleans it off before it has done the job.','2001-01-08 08:06:51.6072001-01-09 08:14:57.357','TomVZ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Best night vision gear for nocturnal paint ball?', stringdate ('2001-01-10 08:27:17'),'We\'re going to start playing paint ball at night, and I\'m looking for recommendations.  What night vision gear is best for this?','2001-01-10 08:27:17.640','BrettH@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Re: Best night vision gear for nocturnal paint ball?', stringdate ('2001-01-10 08:34:34'),'Well, you definitely want to use the goggle type since you\'ll want your hands free (btw, I think you are crazy to play paintball at night).  The Viper 2 (<a href=''http://www.spyworld.com/Viper2.htm''>http://www.spyworld.com/Viper2.htm</a>) is pretty comfortable and not too pricey ($550, vs the thousands you pay for the military versions).  It has a built-in IR illuminator, which is a \'must have\' in your application.  Best of all, it will make you look just like a Borg... :)','2001-01-10 08:27:17.6402001-01-10 08:34:34.810','TomVZ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Foreign language terms for \'mole\'?', stringdate ('2001-01-11 08:49:58'),'Anyone know where I can find this?','2001-01-10 08:49:57.503','JennaJ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'Re: Foreign language terms for \'mole\'?', stringdate ('2001-01-11 08:53:56'),'There\'s a great dictionary for intelligence terms both in English and the languages of the other major intelligence agencies: <i>The CIA Insider\'s Dictionary of US and Foreign Intelligence, Counterintelligence & Tradecraft</i>.  Last time I looked Amazon offered it, but was out of stock.  Let me know if you want to borrow my copy.', '2001-01-10 08:49:57.5032001-01-10 08:53:55.600','TomVZ@ibuyspy.com');
INSERT INTO DISCUSSION (ModuleID,Title,CreatedDate,Body,DisplayOrder,CreatedByUser) VALUES (18,'AMT Mini Night Vision Monocular', stringdate ('2001-01-12 09:16:00'),'Has anyone tried this yet?  It looks really good: tiny (9.5 oz), built-in IR illumination.  The only downside I see is that it seems to be limited to 1.5x magnification.', '2001-01-12 09:15:59.640','ManishG@ibuyspy.com');

INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (10,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 12:35:01.883'),'~/uploads/sample.doc','Employee Handbook','New Employee Info');
INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (10,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 12:37:54.503'),'~/uploads/sample.doc','Annual Reviews','New Employee Info');
INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (10,'JennaJ@ibuyspy.com', stringdate ('2001-12-20 12:39:09.890'),'~/uploads/sample.doc','Vacation Policy','New Employee Info');
INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (20,'TomVZ@ibuyspy.com', stringdate ('2001-12-20 12:35:01.883'),'~/uploads/sample.doc','Secret Diary of a Field Operative','Dossiers');
INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (20,'TomVZ@ibuyspy.com', stringdate ('2001-12-20 12:37:54.503'),'~/uploads/sample.doc','Toaster Boat Users Guide','Documentation');
INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (20,'TomVZ@ibuyspy.com', stringdate ('2001-12-20 12:39:09.890'),'~/uploads/sample.doc','Mistranslated: Translator Moustache Meets Interpreter Earrings','Spy Humor');
INSERT INTO DOCUMENTS (ModuleID,CreatedByUser,CreatedDate,FileNameUrl,FileFriendlyName,Category) VALUES (20,'TomVZ@ibuyspy.com', stringdate ('2001-12-20 12:35:01.883'),'~/uploads/sample.doc','The Edible Tape Recipe Book','Documentation');


INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (2,'&lt;table cellSpacing=&quot;0&quot; cellPadding=&quot;5&quot; border=&quot;0&quot;&gt;
    &lt;tr valign=&quot;top&quot;&gt;
        &lt;td&gt;
            &lt;a target=&quot;_blank&quot; href=&quot;http://www.ibuyspy.com&quot;&gt;
                &lt;img src=&quot;data/logoneg.gif&quot; border=&quot;0&quot; align=&quot;left&quot; hspace=&quot;10&quot;&gt;
            &lt;/a&gt;
        &lt;/td&gt;
        &lt;td class=&quot;Normal&quot; width=&quot;100%&quot;&gt;
            Welcome to the &lt;b&gt;IBuySpy Portal&lt;/b&gt;, the Intranet Home for IBuySpy\'s corporate employees.  This site serves as the hub application for IBuySpy\'s internal operations.  It provides online news, event and sales information, along with interactive discussion forums and employee contact information.  In a nutshell, everything needed to maintain and run the fast-growing IBuySpy commercial empire.
            &lt;br&gt;
            &lt;br&gt;
            Feel free to browse the site and explore.  Sign in to obtain edit access to different modules within the framework, as well as view the restricted sections of the site.
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;','Welcome to the &lt;b&gt;IBuySpy Portal&lt;/b&gt;, the Intranet Home for IBuySpy\'s corporate employees.','This site serves as the hub application for IBuySpy\'s internal operations.  It provides online news, event and sales information, along with interactive discussion forums and employee contact information.  In a nutshell, everything needed to maintain and run the fast-growing IBuySpy commercial empire.  Feel free to browse the site and explore.  

&lt;br&gt;&lt;br&gt;Sign in with a desktop browser to obtain edit access to different modules within the framework, as well as view the restricted sections of the site.
')
;

INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (5,'&lt;span class=&quot;Normal&quot;&gt;
The QLT2112 &lt;a href=&quot;http://www.ibuyspy.com/store/ProductDetails.aspx?productID=399&quot;&gt;&lt;b&gt;Document Transportation System&lt;/b&gt;&lt;/a&gt; is on special this week to clear an overstock.  Purchasers of the P38 &lt;a href=&quot;http://www.ibuyspy.com/store/ProductDetails.aspx?productID=357&quot;&gt;Escape Vehicle (Air)&lt;/a&gt; receive one free.
&lt;p&gt;
&lt;img align=&quot;left&quot; src=&quot;data/qlt2112.gif&quot;&gt;
&lt;/p&gt;
&lt;/span&gt;
','The QLT2112 &lt;a href=&quot;http://www.ibuyspy.com/store&quot;&gt;&lt;b&gt;Document Transportation System&lt;/b&gt;&lt;/a&gt; is on special this week to clear an overstock.','The QLT2112 &lt;a href=&quot;http://www.ibuyspy.com/store/ProductDetails.aspx?productID=399&quot;&gt;&lt;b&gt;Document Transportation System&lt;/b&gt;&lt;/a&gt; is on special this week to clear an overstock.  Purchasers of the P38 &lt;a href=&quot;http://www.ibuyspy.com/store/ProductDetails.aspx?productID=357&quot;&gt;Escape Vehicle (Air)&lt;/a&gt; receive one free.');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (7,'&lt;span class=&quot;Normal&quot;&gt;
&lt;img align=&quot;right&quot; hspace=&quot;0&quot; src=&quot;data/hart.gif&quot;&gt;
&lt;p&gt;&lt;b&gt;Nancy Hart&lt;/b&gt; served as a scout, guide and spy for the Confederate army, carrying messages between the Southern Armies. She hung around isolated Federal outposts, acting as a peddlar, to report their strength, population and vulnerability to General Jackson. Nancy was twenty years old when she was captured by the Yankees and jailed in a dilapidated house with guards constantly patrolling the building. Nancy gained the trust of one of her guards, got his weapon from him, shot him and escaped.&lt;/p&gt;
&lt;/span&gt;
','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (11,'&lt;table cellspacing=&quot;0&quot; cellpadding=&quot;0&quot; border=&quot;0&quot;&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;img src=&quot;data/enigma.gif&quot;&gt;
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;br&gt;The WWII &lt;b&gt;Enigma&lt;/b&gt; cypher was based on a system of three rotors that substituted cipher text letters for plain text letters. The innovation that made Enigma machine so powerful was the spinning of its rotors. As the plain text letter passed through the first rotor, the first rotor would rotate one position. The other two rotors would remain stationary until the first rotor had rotated 26 times. Then the second rotor would rotate one position. After the second rotor had rotated 26 times, the third rotor would rotate one position.  As a result, an \'s\' could be encoded as a \'b\' in the first part of the message, and then as an \'m\' later in the same message.  
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;
','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (17,'&lt;span class=&quot;Normal&quot;&gt;
    &lt;img align=&quot;right&quot; hspace=&quot;0&quot; src=&quot;data/vanlew.gif&quot;&gt;
    &lt;p&gt;
        &lt;b&gt;Elizabeth Van Lew&lt;/b&gt; asked to be allowed to visit Union prisoners held by the Confederates in Richmond and began taking them food and medicines. She realized that many of the prisoners had been marched through Confederate lines on their way to Richmond and were full of useful information about Confederate movements. She became a spy for the North for the next four years, setting up a network of couriers, and devising a code. For her efforts during the Civil War, Elizabeth Van Lew was made Postmaster of Richmond by General Grant. 
    &lt;/p&gt;
&lt;/span&gt;
','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (22,'&lt;table cellspacing=0 cellpadding=0 border=0&gt;
    &lt;tr&gt;
        &lt;td class=Normal width=&quot;100%&quot;&gt;
            The &lt;b&gt;IBuySpy Portal&lt;/b&gt; Solution Starter Kit demonstrates how you can use ASP.NET and the .NET Framework to build a either an intranet or Internet portal application. &lt;b&gt;IBuySpy Portal&lt;/b&gt; offers all the functionality of typical portal applications, including:&lt;br&gt;&lt;br&gt;

            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;140&quot;&gt;
                        &lt;image src=&quot;data/sample.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&lt;/td&gt;
                    &lt;td class=&quot;Normal&quot; width=&quot;*&quot;&gt;

                        &lt;ul&gt;
                            &lt;li&gt;
                            &lt;a href=&quot;#basicmod&quot;&gt;10 basic portal modules&lt;/a&gt; for common types of content
                            &lt;li&gt;
                            A &quot;pluggable&quot; framework that is simple to extend with &lt;a href=&quot;#custommod&quot;&gt;custom portal modules&lt;/a&gt;
                            &lt;li&gt;
                            &lt;a href=&quot;#admintool&quot;&gt;Online administration&lt;/a&gt; of portal layout, content and security
                            &lt;li&gt;
                            &lt;a href=&quot;#security&quot;&gt;Roles-based security&lt;/a&gt; for viewing content, editing content, and administering 
                            the portal
                            &lt;/li&gt;
                        &lt;/ul&gt;


                        All code contained in the IBuySpy Portal download package is free for use
                in your own applications.  But if you prefer, you may customize the portal for your own use without writing a line of code.  The portal includes built-in Administration pages for setting up your portal, adding content, and setting security options.&lt;br&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td colspan=3 class=&quot;Normal&quot;&gt;
                        &lt;br&gt;
                        &lt;u&gt;Getting Started with the IBuySpy Portal&lt;/u&gt;&lt;br&gt;
                        This page explains how users interact with the portal, and how to use the Administration tool to customize it.  To browse the source code and read about it works, click the &lt;a href=&quot;Docs/Docs.htm&quot; target=&quot;_new&quot;&gt;Portal Documentation&lt;/a&gt; link at the top of the page. 
                    &lt;/td&gt;
                &lt;/tr&gt;
        &lt;/table&gt;    
            
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;','The &lt;b&gt;IBuySpy Portal&lt;/b&gt; Solution Starter Kit demonstrates how you can use ASP.NET and the .NET Framework to build a either an intranet or Internet portal application.','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (23,'&lt;a name=&quot;tabs&quot;&gt;
&lt;table cellspacing=0 cellpadding=0 border=0&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot; width=&quot;100%&quot;&gt;

            Content in the portal is grouped by &lt;b&gt;Tabs&lt;/b&gt;.  For example, the IBuySpy portal has five content tabs:&lt;br&gt;&lt;br&gt;
            
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td&gt;
            &lt;img src=&quot;data/tabbar.gif&quot;&gt;    
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;

            You can create tabs that are visible only to certain users.  For example, you might create a private tab that only users in the &quot;Managers&quot; role can view.  See &lt;a href=&quot;#layout&quot;&gt;Managing Portal Layout&lt;/a&gt; to learn how to create a tab, and &lt;a href=&quot;#security&quot;&gt;Managing User Security&lt;/a&gt; to learn how to control access to a tab.
        
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;
','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (24,'&lt;a name=&quot;modules&quot;&gt;
&lt;table cellspacing=0 cellpadding=5 border=0&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot; width=&quot;100%&quot;&gt;

            Portal Modules are modular pieces of code and UI that each present some functionality to the user, like a threaded discussion list, or render data, graphics and text, like a &quot;sales by region&quot; report.  Typically, several portal modules are grouped on a portal tab.  For example, the Home tab of the IBuySpy Portal has seven modules:&lt;br&gt;
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;img align=&quot;left&quot; src=&quot;data/whataremodules.gif&quot;&gt;
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            When a user browses a tab in the portal, the portal framework reads a description of the tab from it\'s configuration file, and automatically assembles a page from the portal modules associated with the tab.  The Home tab is composed from these modules:
            
            &lt;ol&gt;
            &lt;li&gt;&lt;u&gt;Sign-in module&lt;/u&gt;:  the portal framework inserts this module on the first tab automatically if the user is not yet authenticated.
            &lt;li&gt;&lt;u&gt;QuickLinks module&lt;/u&gt;:  a list of ASP.NET links rendered compactly.
            &lt;li&gt;&lt;u&gt;Html/Text module&lt;/u&gt;:  an Html snippet, including an image, that introduces the IBuySpy Portal.  An alternate, text-only version is supplied to Mobile users.
            &lt;li&gt;&lt;u&gt;Announcements module&lt;/u&gt;:  a list of IBuySpy news items, briefly summarized, with links for more information.
            &lt;li&gt;&lt;u&gt;Events module&lt;/u&gt;:  a list of upcoming IBuySpy events, including time, location and a brief description.
            &lt;li&gt;&lt;u&gt;Another Html/Text module&lt;/u&gt;:  an Html snippet, including an image, that describes this week\'s special on IBuySpy.com.
            &lt;li&gt;&lt;u&gt;XML module&lt;/u&gt;:  the results of an XSL/T transform on an XML file that shows recent revenue trends for IBuySpy.com.
            &lt;/ol&gt;
            
            &lt;a name=&quot;basicmod&quot;&gt;
            &lt;u&gt;Built-In Portal Modules&lt;/u&gt;
            &lt;br&gt;
            You can use multiple instances of a module type in the portal, for example an HR &lt;i&gt;Links&lt;/i&gt; module and a Products &lt;i&gt;Links&lt;/i&gt; module.  The IBuySpy Portal provides 10 basic Desktop module types, listed below.  Four of these--Announcements, Contacts, Events and HTML/Text--support an alternate rendering for Mobile devices.&lt;br&gt;&lt;br&gt;

            &lt;table cellpadding=&quot;5&quot; cellspacing=&quot;0&quot; border=&quot;0&quot;&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_ann.gif&quot;&gt;

                        &lt;b&gt;Announcements&lt;/b&gt;&lt;br&gt;
                        This module renders a list of announcements. Each announcement includes title, text and a &quot;read more&quot; link, and can be set to automatically expire after a particular date.  Announcements includes an edit page, which allows authorized users to edit the data stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_con.gif&quot;&gt;

                        &lt;b&gt;Contacts&lt;/b&gt;&lt;br&gt;
                        This module renders contact information for a group of people, for example a project team.  The Mobile version of this module also provides a Call link to phone a contact when the module is browsed from a wireless telephone.  Contacts includes an edit page, which allows authorized users to edit the Contacts data stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_dsc.gif&quot;&gt;

                        &lt;b&gt;Discussion&lt;/b&gt;&lt;br&gt;
                        This module renders a group of message threads on a specific topic.  Discussion includes a Read/Reply Message page, which allows authorized users to reply to exising messages or add a new message thread.  The data for Discussion is stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_doc.gif&quot;&gt;

                        &lt;b&gt;Documents&lt;/b&gt;&lt;br&gt;
                        This module renders a list of documents, including links to browse or download the document.  Documents includes an edit page, which allows authorized users to edit the information about the Documents (for example, a friendly title) stored in the SQL database.  The document itself may be linked to via URL or uploaded and stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_evt.gif&quot;&gt;

                        &lt;b&gt;Events&lt;/b&gt;&lt;br&gt;
                        This module renders a list of upcoming events, including time and location.  Individual events can be set to automatically expire from the list after a particular date.  Events includes an edit page, which allows authorized users to edit the Events data stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_htm.gif&quot;&gt;

                        &lt;b&gt;Html/Text&lt;/b&gt;&lt;br&gt;
                        This module renders a snippet of HTML or text.  The Html/Text module includes an edit page, which allows authorized users to the HTML or text snippets directly.  The snippets are stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_img.gif&quot;&gt;

                        &lt;b&gt;Image&lt;/b&gt;&lt;br&gt;
                        This module renders an image using an HTML IMG tag.  The module simply sets the IMG tag\'s src attribute to a relative or absolute URL, so the image file does not need to reside within the portal.  The module also exposes height and width attributes, which permits you to scale the image.  Image includes an edit page, which persists these settings to the portal\'s configuration file.                        
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_lnk.gif&quot;&gt;

                        &lt;b&gt;Links&lt;/b&gt;&lt;br&gt;
                        This module renders a list of hyperlinks.  Links includes an edit page, which allows authorized users to edit the Links data stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_ql.gif&quot;&gt;

                        &lt;b&gt;QuickLinks&lt;/b&gt;&lt;br&gt;
                        Like Links, this module renders a list of hyperlinks.  Rather than rendering it\'s title, however, QuickLinks shows the title &quot;Quick Launch.&quot;  It\'s compact rendering and generic title make it ideal for a set of \'global\' links that appears on several tabs in the portal.  QuickLinks shares the Links edit page, which allows authorized users to edit the QuickLinks data stored in the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                        &lt;img align=&quot;right&quot; hspace=&quot;10&quot; vspace=&quot;10&quot; src=&quot;data/m_xml.gif&quot;&gt;

                        &lt;b&gt;Xml/Xsl&lt;/b&gt;&lt;br&gt;
                        This module renders the result of an XML/XSL transform.  The XML and XSL files are identified by their UNC paths in the xmlsrc and xslsrc properties of the module.  The Xml/Xsl module includes an edit page, which persists these settings to the SQL database.
                    &lt;/td&gt;    
                &lt;/tr&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        &lt;hr&gt;&lt;br&gt;
                    &lt;/td&gt;    
                &lt;/tr&gt;
            &lt;/table&gt;
            
            &lt;a name=&quot;custommod&quot;&gt;
            &lt;u&gt;Custom Portal Modules&lt;/u&gt;
            &lt;br&gt;
            You can create your own custom modules and add them to the portal framework.  See the &lt;a href=&quot;docs/docs.htm&quot;&gt;Portal Documentation&lt;/a&gt; for more information about how to create a custom module.&lt;br&gt;&lt;br&gt;
            See &lt;a href=&quot;#layout&quot;&gt;Managing Portal Layout&lt;/a&gt; below to learn about how to add your custom modules to the portal administration system.
            
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (25,'&lt;table cellspacing=0 cellpadding=5 border=0&gt;
    &lt;tr&gt;
        &lt;td&gt;
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                    
                        &lt;a name=&quot;admintool&quot;&gt;
                        &lt;u&gt;Using the Admin Tool&lt;/u&gt;&lt;br&gt;
                        The IBuySpy Portal provides an online Admin tool that authenticated users in the &quot;Admins&quot; role can use to set up the layout, content and security of the portal.&lt;br&gt;&lt;br&gt;

                        You must sign in on the Home tab to use the Admin tool.  If you\'ve never signed in before, you\'ll need to add yourself to the portal database using the &quot;register&quot; button.  After signing in, you\'ll see a new tab called &quot;Admin&quot; at the top of the page.  Click it to go to the Admin tool.&lt;br&gt;&lt;br&gt;
        
                        
                        &lt;a name=&quot;sitesettings&quot;&gt;
                        &lt;u&gt;Site Settings&lt;/u&gt;&lt;br&gt;&lt;br&gt;
                        &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                            &lt;tr&gt;
                                &lt;td width=&quot;235&quot;&gt;
                                    &lt;img src=&quot;data/sitesettings.gif&quot;&gt;
                                &lt;/td&gt;
                            &lt;/tr&gt;
                            &lt;tr&gt;
                                &lt;td class=&quot;Normal&quot;&gt;
                                    &lt;br&gt;
                                    The &lt;b&gt;Site Settings&lt;/b&gt; section of the Admin tool lets you to set the portal\'s title, and whether to show edit links to all users.  When changing one of these settings, by sure to click the Apply Changes button at the bottom of the section.
                                &lt;/td&gt;
                            &lt;/tr&gt;
                       &lt;/table&gt;    

                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;420&quot;&gt;
                        &lt;img src=&quot;data/admin.gif&quot;&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;    
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;
','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (26,'&lt;table cellspacing=0 cellpadding=5 border=0&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;a name=&quot;layout&quot;&gt;
            &lt;b&gt;Note:&lt;/b&gt; Portal layout is managed using the &lt;a href=&quot;#admintool&quot;&gt;Admin tool&lt;/a&gt; described above.&lt;br&gt;&lt;br&gt;
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td&gt;
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;235&quot; rowspan=&quot;2&quot;&gt;
                        &lt;img align=&quot;left&quot; src=&quot;data/tabs.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td class=&quot;Normal&quot;&gt;
                        
                        &lt;u&gt;Working with Tabs&lt;/u&gt;&lt;br&gt;
                        The &lt;b&gt;Tabs&lt;/b&gt; section lets you add and remove tabs, and change the order of the tabs.  
                        &lt;ul&gt;
                        &lt;li&gt;To &lt;b&gt;add&lt;/b&gt; a new tab to the portal, click the &quot;Add new tab&quot; link (1).  
                        &lt;li&gt;To &lt;b&gt;modify&lt;/b&gt; an existing tab, first select the tab to modify (2) then click the pencil button (3).
                        &lt;li&gt;To &lt;b&gt;reorder&lt;/b&gt; the tabs, click the tab name (2), then click the up or down button (3).
                        &lt;li&gt;To &lt;b&gt;delete&lt;/b&gt; a tab, click the tab name (2), then click the X button (3).
                        &lt;/ul&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
           &lt;/table&gt;    
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;420&quot; rowspan=&quot;2&quot;&gt;
                        &lt;img align=&quot;left&quot; src=&quot;data/layout.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                    
                        &lt;a name=&quot;workmodules&quot;&gt;&lt;/a&gt;
                        &lt;u&gt;Working With Modules on a Tab&lt;/u&gt;&lt;br&gt;
                        The &lt;b&gt;Tab Name and Layout&lt;/b&gt; page lets you manipulate the modules for the selected tab.  Use this page to set the tab name and which roles may view the tab.  Optionally, you can use this page to make the tab visible to Mobile users, and set a different (often abbreviated) tab name for mobile viewing (1).&lt;br&gt;&lt;br&gt;
                        
                        To open the Tab Name and Layout page, select the tab you wish to modify in the Tabs section of the Admin page, then click the pencil button.  See &lt;a href=&quot;#layout&quot;&gt;Portal Layout&lt;/a&gt; above.
                        &lt;ul&gt;
                        &lt;li&gt;To &lt;b&gt;add a new module&lt;/b&gt; to the Tab, pick a Module Type from the list, and give your module a name (2).  Then click the &quot;Add to Organize Modules below&quot; link (3).  The module is added to the bottom of the center Content Pane (4).
                        &lt;li&gt;To &lt;b&gt;add an existing module&lt;/b&gt; to this Tab, click the Exising Module radio button (2).  Pick the module you wish by name from the Module Type list (2).  Then click the &quot;Add to Organize Modules below&quot; link (3).
                        &lt;li&gt;To &lt;b&gt;move a module&lt;/b&gt; within the tab, first select the module to move (4) then click the up, down, right or left button (4).
                        &lt;li&gt;To &lt;b&gt;delete a module&lt;/b&gt; from this tab, click the module name (4), then click the X button (4).
                        &lt;li&gt;To &lt;b&gt;change a module\'s name&lt;/b&gt;, set it\'s caching timeout or control which roles may modify the first select the tab to modify it\'s data click the module name (4), then click the pencil button (4).
                        &lt;/ul&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;    
            
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;235&quot; rowspan=&quot;2&quot;&gt;
                        &lt;img align=&quot;left&quot; src=&quot;data/modulesettings.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                    
                        &lt;a name=&quot;modulesettings&quot;&gt;&lt;/a&gt;
                        &lt;u&gt;Modules Settings&lt;/u&gt;&lt;br&gt;
                        The &lt;b&gt;Modules Settings&lt;/b&gt; page lets you change a module\'s name, set it\'s cache timeout, set edit permissions for the module\'s data, and indicate whether the module should be visible to mobile users.  Click the Apply Modules Changes button to save the changes.&lt;br&gt;&lt;br&gt;
                        
                        To open the Module Settings page, select the module you wish to modify in the Tab Name and Layout page, then click the pencil button.  See &lt;a href=&quot;#workmodules&quot;&gt;Working with Modules on a Tab&lt;/a&gt; above.&lt;br&gt;&lt;br&gt;
                        
                        For information about setting edit permissions, see &lt;a href=&quot;#authorization&quot;&gt;Roles-Based Authorization&lt;/a&gt; below.
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;    
        &lt;/td&gt;
    &lt;/tr&gt;
        &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;middle&quot;&gt;
                    &lt;td&gt;
                        &lt;img align=&quot;bottom&quot; src=&quot;data/moduledefs.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                                    
                        &lt;a name=&quot;moduledefs&quot;&gt;&lt;/a&gt;
                        &lt;u&gt;Defining New Module Types&lt;/u&gt;&lt;br&gt;
                            The &lt;b&gt;Module Definitions&lt;/b&gt; section lets you add or change a module type definition.  To modify an existing definition, click the pencil button next to the definition name.  To add a new definition click the Add New Module Type button.&lt;br&gt;&lt;br&gt;
                            
                            On the &lt;b&gt;Module Type Definition&lt;/b&gt; page, set a Friendly name and path to the Desktop module source file.  If applicable, set a path to the Mobile version of the module as well.  Due to the ASP.NET security restrictions, the module files must be located within the portal\'s application directory or subdirectories.&lt;br&gt;&lt;br&gt;&lt;br&gt;&lt;br&gt;
                        &lt;img src=&quot;data/moduletypedef.gif&quot;&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;    
        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;','','');
INSERT INTO HTMLTEXT (ModuleID,DesktopHtml,MobileSummary,MobileDetails) VALUES (27,'&lt;table cellspacing=0 cellpadding=5 border=0&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
        
            &lt;a name=&quot;security&quot;&gt;
            Portal security is managed using the &lt;a href=&quot;#admintool&quot;&gt;Admin tool&lt;/a&gt; described above.&lt;br&gt;&lt;br&gt;
        
            &lt;a name=&quot;authentication&quot;&gt;
            &lt;u&gt;Authentication&lt;/u&gt;&lt;br&gt;

            &lt;i&gt;Authentication&lt;/i&gt; validates a user\'s crenditials.  The IBuySpy Portal sample supports two forms of authentication.  
            
            &lt;ul&gt;
            &lt;li&gt;&lt;b&gt;Forms-Based/Cookie authentication&lt;/b&gt; collects a user name and password in a simple input form, then validates them against the Users table in the database.  This type of authentication is typically used for Internet and extranet portals.

            &lt;li&gt;With &lt;b&gt;Windows/NTLM authentication&lt;/b&gt;, either the Windows SAM or Active Directory is used to store and validate all username/password credentials.  This type of authentication is typically used  for intranet-based portals.
           
            &lt;/ul&gt;
            When you install the IBuySpy Portal, Forms Authentication is enabled by default.  To change the authentication mode, edit the web.config file in the root portal directory:&lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td&gt;
            &lt;img align=&quot;left&quot; src=&quot;data/config_auth_win.gif&quot;&gt;
            &lt;img align=&quot;left&quot; src=&quot;data/config_auth_forms.gif&quot;&gt;
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
        
            &lt;a name=&quot;authorization&quot;&gt;
            &lt;u&gt;Roles-Based Authorization&lt;/u&gt;&lt;br&gt;

            &lt;i&gt;Authorization&lt;/i&gt; is used to control access to the modules and tabs in the portal, including the Admin tab.  The IBuySpy Portal sample uses roles-based authorization.  The portal administrator uses these steps to set up roles-based authorization:
            
            &lt;ol&gt;
            &lt;li&gt;&lt;a href=&quot;#createrole&quot;&gt;&lt;b&gt;Create a role&lt;/b&gt;&lt;/a&gt;, for example &quot;Managers&quot; or &quot;HR&quot;.
            &lt;li&gt;&lt;a href=&quot;#addtorole&quot;&gt;&lt;b&gt;Add users to the role&lt;/b&gt;&lt;/a&gt;, for example &quot;CORP01\andreabr&quot;, &quot;CORP01\tomka&quot;, and &quot;CORP01\marklo&quot;.
            &lt;li&gt;&lt;a href=&quot;#tabperms&quot;&gt;&lt;b&gt;Set view permission for tabs&lt;/b&gt;&lt;/a&gt;, for example, limit viewing of the &quot;FY01 Budget&quot; tab to users in the &quot;Managers&quot; role.
            &lt;li&gt;&lt;a href=&quot;#editperms&quot;&gt;&lt;b&gt;Set edit permission for modules&lt;/b&gt;&lt;/a&gt;, for example, limit permission to edit information in the &quot;HR/Benefits News&quot; module to users in the &quot;HR&quot; role.
            &lt;/ol&gt;
            
            The roles-based authorization system in the IBuySpy portal works independently of the authentication mode.  Role membership data is stored in the portal\'s configuration system, and does not rely on the ASP.NET configuration system or Windows groups.  

            &lt;ul&gt;&lt;li&gt;
            &lt;b&gt;IMPORTANT NOTE&lt;/b&gt;: &lt;i&gt;The &quot;All Users&quot; member is a special value that, if present, adds all authenticated users to the role.  When you first install the IBuySpy Portal sample, the &quot;Admins&quot; and &quot;Power Users&quot; roles contain the All Users member.  Remove this member to make the these role secure.&lt;/i&gt;
            &lt;/li&gt;&lt;/ul&gt;

        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;a name=&quot;createrole&quot;&gt;
            &lt;u&gt;Creating and Managing Roles&lt;/u&gt;&lt;br&gt;
        
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td class=&quot;Normal&quot; width=&quot;*&quot;&gt;
                        The &lt;b&gt;Security Roles&lt;/b&gt; section of the Admin tab lets you define roles for the portal.  
                        &lt;ul&gt;
                        &lt;li&gt;To &lt;b&gt;create&lt;/b&gt; a new role to the portal, click the &quot;Add new role&quot; link.  
                        &lt;li&gt;To &lt;b&gt;edit&lt;/b&gt; an existing role, click the pencil button next to the role name.  See &lt;a href=&quot;#addtorole&quot;&gt;Adding Users to a Role&lt;/a&gt; below.
                        &lt;li&gt;To &lt;b&gt;delete&lt;/b&gt; a role, click the X button next to the role name.
                        &lt;/ul&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;320&quot;&gt;
                        &lt;img src=&quot;data/roles1.gif&quot;&gt;
                        &lt;br&gt;
                        &lt;img align=&quot;left&quot; src=&quot;data/roles.gif&quot;&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
           &lt;/table&gt;    
        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
            &lt;a name=&quot;addtorole&quot;&gt;
            &lt;u&gt;Adding Users to a Role&lt;/u&gt;&lt;br&gt;

            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                        The &lt;b&gt;Role Membership&lt;/b&gt; page lets you manage the add or delete users for the selected role.&lt;br&gt;&lt;br&gt;
                        
                        To open the Role Name and Membership page, select the role you wish to modify in the Security Roles section of the Admin page, then click the Change Role Members button.  See &lt;a href=&quot;#createrole&quot;&gt;Creating and Managing Roles&lt;/a&gt; above.
                        &lt;ul&gt;
                        &lt;li&gt;To &lt;b&gt;add&lt;/b&gt; a member to the role, select the user name from the dropdown and click the &quot;Add to Role&quot; link.
                        &lt;li&gt;To &lt;b&gt;delete&lt;/b&gt; a member from the role,  click the X button to the left of the member name.
                        &lt;/ul&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;320&quot;&gt;
                        &lt;img align=&quot;left&quot; src=&quot;data/rolemembership.gif&quot;&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;  

        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
        
            &lt;a name=&quot;tabperms&quot;&gt;&lt;/a&gt;
            &lt;u&gt;Setting View Permission for a Tab&lt;/u&gt;&lt;br&gt;

            You can show show or hide an entire tab depending on whether a user is in an authorized role.  For example, you can limit viewing of the &quot;FY01 Budget&quot; tab to users in the &quot;Managers&quot; role. 
              
            &lt;br&gt;&lt;br&gt;
            
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;220&quot;&gt;
                        &lt;img src=&quot;data/layout.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                        &lt;ul&gt;
                        &lt;li&gt;To set which security roles may view a tab, go to the &lt;a href=&quot;#workmodules&quot;&gt;Tab Name and Layout&lt;/a&gt; page for the tab.  Check the desired roles in the &quot;Authorized Roles&quot; section, then click the &quot;Save Tab Changes&quot; button.
                        &lt;/ul&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;  

        &lt;/td&gt;
    &lt;/tr&gt;
    &lt;tr&gt;
        &lt;td class=&quot;Normal&quot;&gt;
        
            &lt;a name=&quot;editperms&quot;&gt;&lt;/a&gt;
            &lt;u&gt;Setting Edit Access for a Module&lt;/u&gt;&lt;br&gt;

            Permission to edit module data is granted by security role on a per-module basis.  
            
            &lt;ul&gt;
            &lt;li&gt;To set the roles that may edit data for a specific module, go to the &lt;a href=&quot;#modulesettings&quot;&gt;Module Settings&lt;/a&gt; page for the module.  Check the desired roles in the &quot;Roles that can edit content&quot; section, then click the &quot;Apply Module Changes&quot; button.
            &lt;/ul&gt;
            
            &lt;table cellspacing=0 cellpadding=0 border=0&gt;
                &lt;tr valign=&quot;top&quot;&gt;
                    &lt;td width=&quot;220&quot;&gt;
                        &lt;img src=&quot;data/modulesettings.gif&quot;&gt;
                    &lt;/td&gt;
                    &lt;td&gt;&amp;nbsp;&amp;nbsp;&lt;/td&gt;
                    &lt;td width=&quot;*&quot; class=&quot;Normal&quot;&gt;
                    
                        Normally, a module\'s Edit button is shown only to users who have permission to edit the module\'s data.  If you wish, however, you can show the Edit button to all users.  When an unauthorized user clicks the Edit button she recieves an &quot;Edit Access Denied&quot; message, which prompts her to contact the portal administrator to set up edit access.   
                        
                        &lt;ul&gt;
                        &lt;li&gt;This is a portal-wide setting.  To show the Edit button to all users -- even those who do not have edit access -- go to the &lt;b&gt;Site Settings&lt;/b&gt; section on the main Admin page and check the &quot;Always show Edit button&quot; checkbox, then click the &quot;Apply  Changes&quot; button.
                        &lt;/ul&gt;
                    &lt;/td&gt;
                &lt;/tr&gt;
            &lt;/table&gt;  

        &lt;/td&gt;
    &lt;/tr&gt;
&lt;/table&gt;','','');

--
-- End load data
-- 

