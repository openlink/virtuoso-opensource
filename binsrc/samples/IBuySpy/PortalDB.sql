--  
--  $Id$
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
-- ===============================================
-- CONFIG IBUYSPY Portal DATABASE
-- 
-- Version:	1.2 - 01/02 (swarren)
--
-- ===============================================

create user "portal";
DB.DBA.user_set_qualifier ('portal', 'Portal');

USE "Portal";


-- =============================================================
-- create the tables
-- =============================================================

DROP TABLE Announcements
;
DROP TABLE Contacts
;
DROP TABLE Discussion
;
DROP TABLE Documents
;
DROP TABLE Events
; 
DROP TABLE HtmlText
;
DROP TABLE Links
;
DROP TABLE ModuleSettings
;
DROP TABLE Modules
;
DROP TABLE ModuleDefinitions
;
DROP TABLE Tabs
;
DROP TABLE UserRoles
;
DROP TABLE Users
;
DROP TABLE Roles
;
DROP TABLE Portals
;


CREATE TABLE Portals (
    PortalID int IDENTITY NOT NULL,
    PortalAlias varchar (50) NULL,
    PortalName varchar (128) NOT NULL,
    AlwaysShowEditButton int NOT NULL,
    PRIMARY KEY (PortalID)
)
;

 
CREATE TABLE Roles (
    RoleID int IDENTITY NOT NULL,
    PortalID int NOT NULL,
    RoleName varchar (50) NOT NULL, 
    PRIMARY KEY (RoleID),
    FOREIGN KEY (PortalID) REFERENCES Portals
)
;


CREATE TABLE Tabs (
    TabID int IDENTITY NOT NULL,
    TabOrder int NOT NULL,
    PortalID int NOT NULL,
    TabName varchar (50) NOT NULL,
    MobileTabName varchar (50) NOT NULL,
    AuthorizedRoles varchar (256) NULL,
    ShowMobile int NOT NULL, 
    PRIMARY KEY (TabID),
    FOREIGN KEY (PortalID) REFERENCES Portals
) 
;
 
CREATE TABLE ModuleDefinitions (
    ModuleDefID int IDENTITY NOT NULL,
    PortalID int NOT NULL,
    FriendlyName varchar (128) NOT NULL,
    DesktopSrc varchar (256) NOT NULL,
    MobileSrc varchar (256) NOT NULL,
    PRIMARY KEY (ModuleDefID) 
) 
;

CREATE TABLE Modules (
    ModuleID int IDENTITY NOT NULL,
    TabID int NOT NULL,
    ModuleDefID int NOT NULL,
    ModuleOrder int NOT NULL,
    PaneName varchar (50) NOT NULL,
    ModuleTitle varchar (256) NULL,
    AuthorizedEditRoles varchar (256) NULL,
    CacheTime int NOT NULL,
    ShowMobile int NULL,
    PRIMARY KEY (ModuleID),
    FOREIGN KEY (ModuleDefID) REFERENCES ModuleDefinitions, 
    FOREIGN KEY (TabID) REFERENCES Tabs 
) 
;

CREATE TABLE Announcements (
    ItemID int IDENTITY NOT NULL,
    ModuleID int NOT NULL,
    CreatedByUser varchar (100) NULL,
    CreatedDate datetime NULL,
    Title varchar (150) NULL,
    MoreLink varchar (150) NULL,
    MobileMoreLink varchar (150) NULL,
    ExpireDate datetime NULL,
    Description varchar (2000) NULL, 
    PRIMARY KEY (ItemID),
    FOREIGN KEY (ModuleID) REFERENCES Modules
)
;

CREATE TABLE Contacts (
    ItemID int IDENTITY NOT NULL,
    ModuleID int NOT NULL,
    CreatedByUser varchar (100) NULL,
    CreatedDate datetime NULL,
    Name varchar (50) NULL,
    "Role" varchar (100) NULL,	
    Email varchar (100) NULL,
    Contact1 varchar (250) NULL,
    Contact2 varchar (250) NULL ,
    PRIMARY KEY (ItemID),
    FOREIGN KEY (ModuleID) REFERENCES Modules 
)
;

 
CREATE TABLE Discussion (
    ItemID int IDENTITY NOT NULL,
    ModuleID int NOT NULL,
    Title varchar (100) NULL,
    CreatedDate datetime NULL,
    Body varchar (3000) NULL,
    DisplayOrder varchar (750) NULL,
    CreatedByUser varchar (100) NULL,
    PRIMARY KEY (ItemID),
    FOREIGN KEY (ModuleID) REFERENCES Modules 
) 
;

 
CREATE TABLE Documents (
    ItemID int IDENTITY NOT NULL,
    ModuleID int NOT NULL,
    CreatedByUser varchar (100) NULL,
    CreatedDate datetime NULL,
    FileNameUrl varchar (250) NULL,
    FileFriendlyName varchar (150) NULL,
    Category varchar (50) NULL,
    Content long varchar NULL,
    ContentType varchar (50) NULL,
    ContentSize int NULL,
    PRIMARY KEY (ItemID),
    FOREIGN KEY (ModuleID) REFERENCES Modules 
) 
;


CREATE TABLE Events (
    ItemID int IDENTITY NOT NULL,
    ModuleID int NOT NULL,
    CreatedByUser varchar (100) NULL,
    CreatedDate datetime NULL,
    Title varchar (150) NULL,
    WhereWhen varchar (150) NULL,
    Description varchar (2000) NULL,
    ExpireDate datetime NULL,
    PRIMARY KEY (ItemID),
    FOREIGN KEY (ModuleID) REFERENCES Modules 
) 
;

 
CREATE TABLE HtmlText (
    ModuleID int NOT NULL,
    DesktopHtml long varbinary NOT NULL,
    MobileSummary varbinary NOT NULL,
    MobileDetails varbinary NOT NULL,
    PRIMARY KEY (ModuleID),
    FOREIGN KEY (ModuleID) REFERENCES Modules 
) 
;

 
CREATE TABLE Links (
    ItemID int IDENTITY NOT NULL,
    ModuleID int NOT NULL,
    CreatedByUser varchar (100) NULL,
    CreatedDate datetime NULL,
    Title varchar (100) NULL,
    Url varchar (250) NULL,
    MobileUrl varchar (250) NULL,
    ViewOrder int NULL,
    Description varchar (2000) NULL,
    PRIMARY KEY (ItemID),
    FOREIGN KEY (ModuleID) REFERENCES Modules 
) 
;


 
CREATE TABLE ModuleSettings (
    ModuleID int NOT NULL,
    SettingName varchar (50) NOT NULL,
    SettingValue varchar (256) NOT NULL,
    FOREIGN KEY (ModuleID) REFERENCES Modules
)
;

CREATE INDEX IX_ModuleSettings ON ModuleSettings (ModuleID, SettingName)
;


 
CREATE TABLE Users (
    UserID int IDENTITY NOT NULL,		
    Name varchar (50) NOT NULL,
    "Password" varchar (20) NULL,
    Email varchar (100) NOT NULL,
    PRIMARY KEY (UserID) 
) 
;

 
CREATE TABLE UserRoles (
    UserID int NOT NULL,
    RoleID int NOT NULL,
    FOREIGN KEY (RoleID) REFERENCES Roles,
    FOREIGN KEY (UserID) REFERENCES Users
) 
;

