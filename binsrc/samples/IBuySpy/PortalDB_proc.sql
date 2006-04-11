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

USE "Portal";

-- =============================================================
-- create the stored procs
-- =============================================================


CREATE PROCEDURE 
Portal..GetPortalSettings (in in_PortalAlias varchar, in in_TabID int)
{
  declare PaneName, ModuleTitle, AuthorizedEditRoles, FriendlyName, DesktopSrc, MobileSrc varchar (255);
  declare PortalName, TabName, MobileTabName, AuthRoles, AuthorizedRoles varchar (255);
  declare ModuleID, ModuleDefID, ModuleOrder, CacheTime, ShowMobile, is_fill integer;
  declare PortalID, AlwaysShowEditButton, TabOrder, ShowMobile, PortalID2, TabID, int_TabID integer;

  --dbg_obj_print ('In side procedure PortalAlias = ', in_PortalAlias);
  --dbg_obj_print ('In side procedure TabID = ', in_TabID);

  if (in_TabID = 0)
    {

	SELECT TOP 1 Portals.PortalID, Portals.PortalName, Portals.AlwaysShowEditButton, Tabs.TabID, 
		     Tabs.TabOrder, Tabs.TabName, Tabs.MobileTabName, Tabs.AuthorizedRoles, Tabs.ShowMobile
	       into 
		     PortalID2, PortalName, AlwaysShowEditButton, int_TabID,     
		     TabOrder, TabName, MobileTabName, AuthRoles, ShowMobile    
	       from
		     Tabs INNER JOIN Portals ON Tabs.PortalID = Portals.PortalID
	       where
		     PortalAlias=in_PortalAlias
	       order by
		     TabOrder;

    }
  else 
    {
	SELECT TOP 1 Portals.PortalID, Portals.PortalName, Portals.AlwaysShowEditButton, Tabs.TabID, 
		     Tabs.TabOrder, Tabs.TabName, Tabs.MobileTabName, Tabs.AuthorizedRoles, Tabs.ShowMobile
	       into 
		     PortalID2, PortalName, AlwaysShowEditButton, int_TabID,     
		     TabOrder, TabName, MobileTabName, AuthRoles, ShowMobile    

    	       from
        	     Tabs INNER JOIN Portals ON Tabs.PortalID = Portals.PortalID
        
    	       where TabID=in_TabID;

    }


/* Get Tabs list */
   result_names (TabName, AuthorizedRoles, TabID, TabOrder);
   for (SELECT TabName, AuthorizedRoles, TabID, TabOrder
     from Tabs
     where PortalID = PortalID2
     order by TabOrder) do 
       {
     	  result (TabName, AuthorizedRoles, TabID, TabOrder);
       }

    end_result (); 

/* Get Mobile Tabs list */
   result_names (TabID, MobileTabName, AuthorizedRoles);
   for (SELECT MobileTabName, AuthorizedRoles, TabID, ShowMobile
     from Tabs
     where PortalID = PortalID and ShowMobile = 1
     order by TabOrder ) do 
       {
	   result       (TabID, MobileTabName, AuthorizedRoles);
       }
 
   end_result (); 

   result_names (ModuleID, TabID, ModuleDefID, ModuleOrder, PaneName, ModuleTitle, 
		 AuthorizedEditRoles, CacheTime, ShowMobile, FriendlyName, DesktopSrc, MobileSrc);

   is_fill := 0;

   for (SELECT ModuleID, TabID, ModuleDefinitions.ModuleDefID as i_ModuleDefinitions, ModuleOrder, PaneName, 
	       ModuleTitle, AuthorizedEditRoles, CacheTime, ShowMobile, FriendlyName, DesktopSrc, MobileSrc
     from Modules INNER JOIN ModuleDefinitions on Modules.ModuleDefID = ModuleDefinitions.ModuleDefID
     where TabID = int_TabID 
     order by ModuleOrder ) do 
       {
     	   result (ModuleID, TabID, i_ModuleDefinitions, ModuleOrder, PaneName, ModuleTitle, 
		   AuthorizedEditRoles, CacheTime, ShowMobile, FriendlyName, DesktopSrc, MobileSrc);
	   is_fill := 1;
       } 

    if (is_fill = 0)
      {
     	   result (0, 0, 0, 0, '', '', '', '', 0, 0, '', '');
      }

  end_result ();

  result_names (PortalID, PortalName, AlwaysShowEditButton, 
		TabName, TabOrder, MobileTabName, AuthRoles, ShowMobile, AuthorizedRoles);
  result       (PortalID, PortalName, AlwaysShowEditButton, 
	  	TabName, TabOrder, MobileTabName, AuthRoles, ShowMobile, AuthorizedRoles);
  end_result (); 

}
;



CREATE PROCEDURE 
Portal..GetLinks (in in_ModuleID int)
{

   declare ItemID, ViewOrder integer;
   declare CreatedByUser, Title, Url, Description varchar (255);
   declare CreatedDate date;

   result_names (ItemID, CreatedByUser, CreatedDate, Title, Url, ViewOrder, Description);

   for (SELECT ItemID, CreatedByUser, CreatedDate, Title, Url, ViewOrder, Description
   	   from Links where ModuleID = in_ModuleID
   	   order by ViewOrder ) do
     {
   	result (ItemID, CreatedByUser, CreatedDate, Title, Url, ViewOrder, Description);
     }

  end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetHtmlText (in in_ModuleID int)
{
   declare ModuleID integer;
   declare DesktopHtml varchar (100000);
   declare MobileSummary, MobileDetails varchar (1000);

   result_names (ModuleID, DesktopHtml, MobileSummary, MobileDetails);

   for (SELECT ModuleID, cast (DesktopHtml as varchar) as int_DesktopHtml, 
			 cast (MobileSummary as varchar) as int_MobileSummary, 
			 cast (MobileDetails as varchar) as int_MobileDetails
	from HtmlText where ModuleID = in_ModuleID) do
     {
	result (ModuleID, int_DesktopHtml, int_MobileSummary, int_MobileDetails);
     }

  end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetAnnouncements (in in_ModuleID int)
{

   declare ItemID integer;
   declare Title, Description, MoreLink varchar (255); 

   result_names (ItemID, Title, Description, MoreLink);

   for (SELECT ItemID, Title, MoreLink, Description
	  from Announcements 
	  where ModuleID = in_ModuleID AND ExpireDate > now()) do
     {
	result (ItemID, Title, Description, MoreLink);
     }

   end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetEvents (in in_ModuleID int)
{
   declare ItemID integer;
   declare Description varchar (2000);
   declare Title, WhereWhen varchar (150);

   result_names (ItemID, Title, Description, WhereWhen);

   for (SELECT ItemID as int_ItemID, Title, CreatedByUser, WhereWhen, CreatedDate, Title, ExpireDate, Description
	from Events where ModuleID = in_ModuleID AND ExpireDate > Now()) do
     {
	result (int_ItemID, Title, Description, WhereWhen);
     }

   end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetModuleSettings (in in_ModuleID int)
{
   declare SettingName, SettingValue varchar (200);
   result_names (SettingName, SettingValue);

   for (SELECT SettingName, SettingValue from ModuleSettings
          where ModuleID = in_ModuleID) do
     {
	result (SettingName, SettingValue);
     }

   end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetContacts (in in_ModuleID int)
{
   declare ItemID integer;
   declare Name, "Role", Email, Contact1, Contact2 varchar (1024);

   result_names (ItemID, Name, "Role", Email, Contact1, Contact2);

   for (SELECT ItemID, Name, "Role", Email, Contact1, Contact2
	  from Contacts where ModuleID = in_ModuleID) do 
     {
	result (ItemID, Name, "Role", Email, Contact1, Contact2);
     }

   end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetDocuments (in in_ModuleID int)
{
   declare ItemID, ContentSize integer;
   declare CreatedDate date;
   declare FileFriendlyName varchar (150);
   declare FileNameUrl varchar (250);
   declare CreatedByUser varchar (100);
   declare Category varchar (50);

   result_names (ItemID, FileFriendlyName, FileNameUrl, ContentSize, CreatedByUser, Category, CreatedDate);

   for (SELECT ItemID, FileFriendlyName, FileNameUrl, CreatedByUser, CreatedDate, Category, ContentSize
	  from Documents where ModuleID = in_ModuleID) do
     {
	result (ItemID, FileFriendlyName, FileNameUrl, ContentSize, CreatedByUser, Category, CreatedDate);
     }

   end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetTopLevelMessages (in in_ModuleID int)
{
   declare ItemID integer;
   declare ChildCount integer;
   declare Parent varchar(64);
   declare Title, CreatedByUser varchar(100);
   declare CreatedDate datetime;

   result_names (ItemID, Parent, ChildCount, Title, CreatedByUser, CreatedDate);

   for (SELECT ItemID as int_ItemID, (SELECT (COUNT(*) -1) FROM Discussion Disc2 WHERE "LEFT"(Disc2.DisplayOrder, 
		    length( RTRIM(cast (Disc.DisplayOrder as varchar)))) = Disc.DisplayOrder) AS int_ChildCount, 
		Title as int_Title, CreatedByUser as int_CreatedByUser,
		CreatedDate as int_CreatedDate, DisplayOrder, "LEFT"(DisplayOrder, 23) AS int_Parent 
	from Discussion Disc where ModuleID=in_ModuleID AND (Length( DisplayOrder ) / 23 ) = 1 
	  order by DisplayOrder) do
     {
	result (int_ItemID, int_Parent, int_ChildCount, int_Title, int_CreatedByUser, int_CreatedDate);
     }

  end_result (); 
}
;


CREATE PROCEDURE 
Portal..AddUser (in in_Name varchar, in in_Email varchar, in in_Password varchar, in UserID integer)
{

   INSERT into Users (Name, Email, "Password") values (in_Name, in_Email, in_Password);

   result_names (UserID);
   result (identity_value ());
   end_result (); 

}
;


CREATE PROCEDURE 
Portal..GetRolesByUser (in in_Email varchar)
{
  declare RoleName varchar (100);
  declare RoleID integer;

  result_names (RoleName, RoleID);

  for (SELECT Roles.RoleName as out_RoleName, Roles.RoleID as out_RoleID
         from UserRoles INNER JOIN Users 
           on UserRoles.UserID = Users.UserID INNER JOIN Roles 
           on UserRoles.RoleID = Roles.RoleID
        where Users.Email = in_Email) do
    {
      result (out_RoleName, out_RoleID);
    }

   end_result (); 
}
;


CREATE PROCEDURE 
Portal..UserLogin (in Email varchar, in in_Password varchar, in UserName varchar (200))
{

   if (exists (SELECT 1 from Users where Email = Email AND "Password" = in_Password))
     {
	SELECT Name into UserName from Users
	  where Email = Email AND "Password" = in_Password;
     }
   else
     UserName := '';

   result_names (UserName);
   result (UserName);
   end_result (); 
}
;


CREATE PROCEDURE 
Portal..GetAuthRoles (in in_ModuleID int, in in_PortalID int, in in_AccessRoles varchar, in in_EditRoles varchar)
{
   declare AccessRoles, EditRoles varchar (256);

   SELECT Tabs.AuthorizedRoles, Modules.AuthorizedEditRoles into AccessRoles, EditRoles
     from Modules INNER JOIN Tabs ON Modules.TabID = Tabs.TabID    
     where Modules.ModuleID = in_ModuleID AND Tabs.PortalID = in_PortalID;

   result_names (AccessRoles, EditRoles);
   result (AccessRoles, EditRoles);
   end_result ();
}
;


CREATE PROCEDURE 
Portal..AddLink (in ItemID int, in ModuleID int, in UserName varchar, in Title varchar, in Description varchar,
		 in  Url varchar, in MobileUrl varchar, in ViewOrder int)
{

   INSERT into Links (ModuleID, CreatedByUser, CreatedDate, Title, Url, MobileUrl, ViewOrder, Description)
	values (ModuleID, UserName, Now(), Title, Url, MobileUrl, ViewOrder, Description);

   result_names (ItemID);
   result (identity_value ());
   end_result (); 

}
;


CREATE PROCEDURE 
Portal..UpdateHtmlText (in in_ModuleID int, in in_DesktopHtml varchar, 
			in in_MobileSummary varchar, in in_MobileDetails varchar)
{

  if (not exists (SELECT 1 FROM HtmlText WHERE  ModuleID = in_ModuleID))
    {
       INSERT into HtmlText (ModuleID, DesktopHtml, MobileSummary, MobileDetails) 
	    values (in_ModuleID, in_DesktopHtml, in_MobileSummary, in_MobileDetails);
    }
  else
    {
       UPDATE HtmlText set DesktopHtml = in_DesktopHtml, MobileSummary = in_MobileSummary,
			   MobileDetails = in_MobileDetails
	where ModuleID = in_ModuleID;
    }

}
;


CREATE PROCEDURE 
Portal..AddAnnouncement (in ItemID int, in in_ModuleID int, in in_UserName varchar,  in in_Title varchar, 
			 in in_MoreLink varchar, in in_MobileMoreLink varchar, in in_ExpireDate datetime, 
			 in in_Description varchar)
{

  INSERT into Announcements (ModuleID, CreatedByUser, CreatedDate, Title,
    			     MoreLink, MobileMoreLink, ExpireDate, Description)

	values (in_ModuleID, in_UserName, now(), in_Title, in_MoreLink, 
		in_MobileMoreLink, in_ExpireDate, in_Description);

   result_names (ItemID);
   result (identity_value ());
   end_result ();

}
;


CREATE PROCEDURE 
Portal..AddEvent (in ItemID int, in in_ModuleID int, in in_UserName varchar, in in_Title varchar,
    		  in in_WhereWhen varchar, in ExpireDate datetime, in in_Description varchar)
{

  INSERT into Events (ModuleID, CreatedByUser, Title, CreatedDate, ExpireDate, Description, WhereWhen)
      values (in_ModuleID, in_UserName, in_Title, Now(), ExpireDate, in_Description, in_WhereWhen);

   result_names (ItemID);
   result (identity_value ());
   end_result ();

}
;


CREATE PROCEDURE 
Portal..UpdateModuleSetting (in in_ModuleID int, in in_SettingName varchar, in in_SettingValue varchar)
{

  if (not exists (SELECT 1 from ModuleSettings where ModuleID = in_ModuleID AND SettingName = in_SettingName))
    {
	INSERT into ModuleSettings (ModuleID, SettingName, SettingValue) 
	    values (in_ModuleID, in_SettingName, in_SettingValue);
    }
  else
    {
	UPDATE ModuleSettings set SettingValue = in_SettingValue 
	   where ModuleID = in_ModuleID AND SettingName = in_SettingName;
    }

}
;


CREATE PROCEDURE 
Portal..GetSingleLink (in in_ItemID int)
{

  declare ViewOrder integer;
  declare CreatedDate varchar (20);
  declare CreatedByUser, Title varchar (100);
  declare Url, MobileUrl varchar (250);
  declare Description varchar (2000);

  result_names (CreatedByUser, CreatedDate, Title, Url, MobileUrl, ViewOrder, Description);

  for (SELECT CreatedByUser as int_CreatedByUser, CreatedDate as int_CreatedDate, Title as int_Title, 
	      Url as int_Url, MobileUrl as int_MobileUrl, ViewOrder as int_ViewOrder, Description as int_Description
         from Links where ItemID = in_ItemID) do
     {
        result (int_CreatedByUser, datestring (int_CreatedDate), int_Title, int_Url, 
		int_MobileUrl, int_ViewOrder, int_Description);
     }

   end_result ();
}
;


CREATE PROCEDURE 
Portal..UpdateLink (in in_ItemID int, in in_UserName varchar, in in_Title varchar, in in_Description varchar,
		    in in_Url varchar, in in_MobileUrl varchar, in in_ViewOrder int)
{

  UPDATE Links set CreatedByUser = in_UserName, CreatedDate = Now(), Title = in_Title,
    		   Url = in_Url, MobileUrl = in_MobileUrl, ViewOrder = in_ViewOrder,
    		   Description = in_Description
    where ItemID = in_ItemID;
}
;


CREATE PROCEDURE 
Portal..DeleteLink (in in_ItemID int)
{
  DELETE from Links where ItemID = in_ItemID;
}
;


CREATE PROCEDURE 
Portal..GetSingleAnnouncement (in in_ItemID int)
{

  declare CreatedByUser varchar (100);
  declare Title, MoreLink, MobileMoreLink varchar (150);
  declare Description varchar (2000);
  declare ExpireDate, CreatedDate datetime;

  result_names (CreatedByUser, CreatedDate, Title, MoreLink, MobileMoreLink, ExpireDate, Description);

  for (SELECT CreatedByUser as int_CreatedByUser, CreatedDate as int_CreatedDate, Title as int_Title, 
	      MoreLink as int_MoreLink, MobileMoreLink as int_MobileMoreLink, 
	      ExpireDate as int_ExpireDate, Description as int_Description
    from Announcements where ItemID = in_ItemID) do
    {
       result (int_CreatedByUser, int_CreatedDate, int_Title, int_MoreLink, 
	       int_MobileMoreLink, int_ExpireDate, int_Description);
    }

  end_result ();
}
;


CREATE PROCEDURE 
Portal..DeleteAnnouncement (in in_ItemID int)
{

  DELETE from Announcements where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..UpdateAnnouncement (in in_ItemID int, in in_UserName varchar, in in_Title varchar, in in_MoreLink varchar,
    			    in in_MobileMoreLink varchar, in in_ExpireDate datetime, in in_Description varchar)
{

   UPDATE Announcements set CreatedByUser = in_UserName, CreatedDate = now(), Title = in_Title,
    			    MoreLink = in_MoreLink, MobileMoreLink = in_MobileMoreLink,
			    ExpireDate = in_ExpireDate, Description = in_Description
      where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..GetSingleEvent (in in_ItemID int)
{

  declare CreatedByUser varchar (100);
  declare Title, WhereWhen varchar (150);
  declare Description varchar (2000);
  declare CreatedDate, ExpireDate datetime;
  
  result_names (CreatedByUser, CreatedDate, Title, ExpireDate, Description, WhereWhen);
 
  for (SELECT CreatedByUser as int_CreatedByUser, CreatedDate as int_CreatedDate, Title as int_Title, 
	      ExpireDate as int_ExpireDate, Description as int_Description, 
	      WhereWhen as int_WhereWhen 
    from Events where ItemID = in_ItemID) do
    {
       result (int_CreatedByUser, int_CreatedDate, int_Title, int_ExpireDate, int_Description, int_WhereWhen);
    }

  end_result ();
}
;



CREATE PROCEDURE 
Portal..UpdateEvent (in in_ItemID int, in in_UserName varchar, in in_Title varchar,
    		     in in_WhereWhen varchar, in in_ExpireDate datetime, in in_Description varchar)
{

   UPDATE Events set CreatedByUser = in_UserName, CreatedDate = Now(), Title = in_Title,
    		     ExpireDate = in_ExpireDate, Description = in_Description, 
		     WhereWhen = in_WhereWhen
     where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..DeleteEvent (in in_ItemID int)
{

  DELETE from Events where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..AddContact (in ItemID integer, in in_ModuleID int, in in_UserName varchar, in in_Name varchar, 
		    in in_Role varchar, in in_Email varchar, in in_Contact1 varchar, in in_Contact2 varchar)
{

   INSERT INTO Contacts (CreatedByUser, CreatedDate, ModuleID, Name, "Role", Email, Contact1, Contact2)
     values (in_UserName, Now(), in_ModuleID, in_Name, in_Role, in_Email, in_Contact1, in_Contact2);

   result_names (ItemID);
   result (identity_value ());
   end_result ();

}
;


CREATE PROCEDURE 
Portal..GetSingleContact (in in_ItemID int)
{
   declare CreatedByUser, Name, Role2, Email varchar (100);
   declare Contact1, Contact2 varchar (250);
   declare Name varchar (100);
   declare CreatedDate datetime;
   
   result_names (CreatedByUser, CreatedDate, Name, Role2, Email, Contact1, Contact2);

   for (SELECT CreatedByUser as int_CreatedByUser, CreatedDate as int_CreatedDate,
    	       Name as int_Name, "Role" as int_Role, Email as int_Email, Contact1 as int_Contact1,
    	       Contact2 as int_Contact2
	from Contacts where ItemID = in_ItemID) do
      {
         result (int_CreatedByUser, int_CreatedDate, int_Name, int_Role, int_Email, int_Contact1, int_Contact2);
      }

   end_result ();
}
;


CREATE PROCEDURE 
Portal..UpdateContact (in in_ItemID int, in in_UserName varchar, in in_Name varchar, in in_Role varchar,
    		       in in_Email varchar, in in_Contact1 varchar, in in_Contact2 varchar)
{

  UPDATE Contacts set CreatedByUser = in_UserName, CreatedDate = Now(), Name = in_Name, "Role" = in_Role,
    		      Email = in_Email, Contact1 = in_Contact1, Contact2 = in_Contact2
     where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..DeleteContact (in in_ItemID int)
{

  DELETE from Contacts where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..UpdateDocument (in in_ItemID int, in in_ModuleID int, in in_UserName varchar,
			in in_FileFriendlyName varchar, in in_FileNameUrl varchar, in in_Category varchar,
			in in_Content long varchar, in in_ContentType varchar, in in_ContentSize int)
{


  if ((in_ItemID=0) or not exists (SELECT 1 from Documents where ItemID = in_ItemID))
    {
       INSERT into Documents (ModuleID, FileFriendlyName, FileNameUrl, CreatedByUser, CreatedDate, Category, 
			      Content, ContentType, ContentSize)
	    values (in_ModuleID, in_FileFriendlyName, in_FileNameUrl, in_UserName, Now(),
    		    in_Category, in_Content, in_ContentType, in_ContentSize);
    }
  else
    {
       if (in_ContentSize=0)
         {
	    UPDATE Documents set CreatedByUser = in_UserName, CreatedDate = Now(), Category = in_Category,
    		   		 FileFriendlyName = in_FileFriendlyName, FileNameUrl = in_FileNameUrl
	    where ItemID = in_ItemID;
         }
       else
         {

	    UPDATE Documents set CreatedByUser = in_UserName, CreatedDate = Now (), Category = in_Category,
    		   		 FileFriendlyName = in_FileFriendlyName, FileNameUrl = in_FileNameUrl, 
				 Content = in_Content, ContentType = in_ContentType, ContentSize = in_ContentSize
		where ItemID = in_ItemID;
         }
     }
}
;


CREATE PROCEDURE 
Portal..GetSingleDocument (in in_ItemID int)
{

  declare ContentSize integer;
  declare FileFriendlyName, FileNameUrl, reatedByUser varchar (250);
  declare CreatedByUser, Category, CreatedDate varchar (100);

  result_names (FileFriendlyName, FileNameUrl, CreatedByUser, CreatedDate, Category, ContentSize);

  for (SELECT FileFriendlyName as int_FileFriendlyName , FileNameUrl as int_FileNameUrl, 
	      CreatedByUser as int_CreatedByUser, CreatedDate as int_CreatedDate,
	      Category as int_Category, ContentSize as int_ContentSize
         from Documents where ItemID = in_ItemID) do

     {
	result (int_FileFriendlyName, int_FileNameUrl, int_CreatedByUser, int_CreatedDate, 
		int_Category, int_ContentSize);
     }

  end_result ();
}
;


CREATE PROCEDURE 
Portal..DeleteDocument (in in_ItemID int)
{

  DELETE from Documents where ItemID = in_ItemID;

}
;


CREATE PROCEDURE 
Portal..GetDocumentContent (in in_ItemID int)
{

  declare ContentSize integer;
  declare ContentType, FileName varchar (150); 
  declare Content varchar (10000); 

  result_names (Content, ContentType, ContentSize, FileName);

  for (SELECT Content as int_Content, ContentType as int_ContentType, 
	      ContentSize as int_ContentSize, FileFriendlyName
	  from Documents where ItemID = in_ItemID) do
     {
        result (int_Content, int_ContentType, int_ContentSize, FileFriendlyName);  
     }

  end_result ();
}
;


CREATE PROCEDURE 
Portal..GetPortalRoles (in in_PortalID  int)
{

  declare RoleID integer;
  declare RoleName varchar (50);

  result_names (RoleName, RoleID);

  for (SELECT RoleName as int_RoleName, RoleID as int_RoleID from Roles where PortalID = in_PortalID) do
    {
       result (int_RoleName, int_RoleID);
    }

  end_result ();
}
;


CREATE PROCEDURE 
Portal..GetUsers ()
{
   
  declare UserID integer;
  declare Email varchar (100);

  result_names (UserID, Email);

  for (SELECT UserID as int_UserID, Email as int_Email from Users order by Email) do
     {
        result (int_UserID, int_Email);
     }

  end_result ();
}
;


CREATE PROCEDURE 
Portal..GetModuleDefinitions (in in_PortalID  int)
{

  declare ModuleDefID integer;
  declare DesktopSrc, MobileSrc varchar (256);
  declare FriendlyName varchar (128);

  result_names (FriendlyName, DesktopSrc, MobileSrc, ModuleDefID);

  for (SELECT FriendlyName as int_FriendlyName, DesktopSrc as int_DesktopSrc, 
	      MobileSrc as int_MobileSrc, ModuleDefID as int_ModuleDefID
	 from ModuleDefinitions 
	 where PortalID = in_PortalID) do
    {
       result (int_FriendlyName, int_DesktopSrc, int_MobileSrc, int_ModuleDefID);
    }

   end_result ();
}
;


CREATE PROCEDURE 
Portal..AddModuleDefinition (in in_PortalID int, in in_FriendlyName varchar, in in_DesktopSrc varchar,
			     in in_MobileSrc varchar, in ModuleDefID int)
{

   INSERT into ModuleDefinitions (PortalID, FriendlyName, DesktopSrc, MobileSrc)
       values (in_PortalID, in_FriendlyName, in_DesktopSrc, in_MobileSrc);

   result_names (ModuleDefID);
   result (identity_value ());
   end_result ();

}
;


CREATE PROCEDURE 
Portal..DeleteModuleDefinition (in in_ModuleDefID int)
{

   declare temp integer;

   SELECT ModuleID into temp from Modules where ModuleDefID = in_ModuleDefID; 
   dbg_obj_print ('Portal..DeleteModuleDefinition (in in_ModuleDefID = ', in_ModuleDefID);
   dbg_obj_print ('temp = ', temp);
   dbg_obj_print ('1');

   DELETE from Documents where ModuleID = temp;
   DELETE from Discussion where ModuleID = temp;
   DELETE from Events where ModuleID = temp;
   DELETE from ModuleSettings where ModuleID = temp;
   DELETE from Announcements where ModuleID = temp;

   dbg_obj_print ('2');
   DELETE from Modules where ModuleDefID = in_ModuleDefID;
   dbg_obj_print ('3');
   DELETE from ModuleDefinitions where ModuleDefID = in_ModuleDefID;

}
;


CREATE PROCEDURE 
Portal..UpdatePortalInfo (in in_PortalID int, in in_PortalName varchar, in in_AlwaysShowEditButton int)
{

   UPDATE Portals set PortalName = in_PortalName, AlwaysShowEditButton = in_AlwaysShowEditButton
      where PortalID = in_PortalID;

}
;


CREATE PROCEDURE 
Portal..AddTab (in in_PortalID int, in in_TabName varchar, in in_TabOrder int,
    		in in_AuthorizedRoles varchar, in in_MobileTabName varchar, in TabID int)
{

  INSERT into Tabs (PortalID, TabName, TabOrder, ShowMobile, MobileTabName, AuthorizedRoles)
         values (in_PortalID, in_TabName, in_TabOrder, 0, in_MobileTabName, in_AuthorizedRoles);

  result_names (TabID);
  result (identity_value ());
  end_result ();

}
;


CREATE PROCEDURE 
Portal..UpdateTabOrder (in in_TabID int, in in_TabOrder int)
{

  UPDATE Tabs set TabOrder = in_TabOrder where TabID = in_TabID;

}
;


CREATE PROCEDURE 
Portal..DeleteTab (in in_TabID int)
{
 
  dbg_obj_print ('Portal..DeleteTab (in in_TabID = ', in_TabID);

  DELETE from Modules where TabID = in_TabID;
  DELETE from Tabs where TabID = in_TabID;

}
;


CREATE PROCEDURE 
Portal..UpdateTab (in in_PortalID int, in in_TabID int, in in_TabName varchar, in in_TabOrder int,
    		   in in_AuthorizedRoles varchar, in in_MobileTabName varchar, in in_ShowMobile int)
{
   if (not exists (SELECT 1 from Tabs where TabID = in_TabID))
     {
	INSERT into Tabs (PortalID, TabOrder, TabName, AuthorizedRoles, MobileTabName, ShowMobile) 
           values (in_PortalID, in_TabOrder, in_TabName, in_AuthorizedRoles, in_MobileTabName, in_ShowMobile);
     }
   else
     {
	UPDATE Tabs set TabOrder = in_TabOrder, TabName = in_TabName, AuthorizedRoles = in_AuthorizedRoles,
    			MobileTabName = in_MobileTabName, ShowMobile = in_ShowMobile
	   where TabID = in_TabID;
     }
}
;


CREATE PROCEDURE 
Portal..UpdateModule (in in_ModuleID int, in in_ModuleOrder int, in in_ModuleTitle varchar, in in_PaneName varchar,
    		      in in_CacheTime int, in EditRoles varchar, in in_ShowMobile int)
{

   UPDATE Modules set ModuleOrder = in_ModuleOrder, ModuleTitle = in_ModuleTitle, PaneName = in_PaneName,
    		      CacheTime = in_CacheTime, ShowMobile  = in_ShowMobile, AuthorizedEditRoles = EditRoles
	where ModuleID = in_ModuleID;

}
;


CREATE PROCEDURE 
Portal..UpdateModuleOrder (in in_ModuleID int, in in_ModuleOrder int, in in_PaneName varchar)
{

   UPDATE Modules set ModuleOrder = in_ModuleOrder, PaneName = in_PaneName where ModuleID = in_ModuleID;

}
;


CREATE PROCEDURE 
Portal..DeleteModule (in in_ModuleID int)
{

--   declare Module_def integer;

--   SELECT ModuleDefID into Module_def from Modules where ModuleID = in_ModuleID;

--   dbg_obj_print ('Portal..DeleteModule Module_def = ', Module_def);

--   DELETE from ModuleDefinitions where ModuleDefID = Module_def; 
   dbg_obj_print ('-1 ', in_ModuleID);
   DELETE from ModuleSettings where ModuleID = in_ModuleID;
   dbg_obj_print ('-2 ');
   DELETE from Modules where ModuleID = in_ModuleID;
   dbg_obj_print ('-3 ');

}
;


CREATE PROCEDURE 
Portal..UpdateRole (in in_RoleID int, in in_RoleName varchar)
{

   UPDATE Roles set RoleName = in_RoleName where RoleID = in_RoleID;

}
;


CREATE PROCEDURE 
Portal..GetRoleMembership (in in_RoleID  int)
{

   declare UserID integer; 
   declare Name varchar (50);
   declare Email varchar (100); 

   result_names (Name, UserID, Email);

   for (SELECT UserRoles.UserID as int_UserID, Name as int_Name, Email as int_Email 
          from UserRoles INNER JOIN Users On Users.UserID = UserRoles.UserID
          where UserRoles.RoleID = in_RoleID) do
     {
        result (int_Name, int_UserID, int_Email);
     }

   end_result ();
}
;


CREATE PROCEDURE 
Portal..AddUserRole (in in_RoleID int, in in_UserID int)
{

   declare u_count integer;

   SELECT count (*) into u_count from UserRoles where UserID = in_UserID and RoleID= in_RoleID;

   if (u_count < 1)
     {
        INSERT into UserRoles (UserID, RoleID) values (in_UserID, in_RoleID);
     }
}
;


CREATE PROCEDURE 
Portal..DeleteUser (in in_UserID int)
{

   DELETE from UserRoles where UserID = in_UserID;
   DELETE from Users where UserID = in_UserID;

}
;


CREATE PROCEDURE 
Portal..DeleteUserRole (in in_RoleID int, in in_UserID int)
{

   DELETE from UserRoles where UserID = in_UserID and RoleID = in_RoleID;

}
;


CREATE PROCEDURE 
Portal..AddRole (in in_PortalID int, in in_RoleName varchar, in RoleID int)
{

   INSERT into Roles (PortalID, RoleName)
	values (in_PortalID, in_RoleName);

   result_names (RoleID);
   result (identity_value ());
   end_result ();

}
;


CREATE PROCEDURE 
Portal..DeleteRole (in in_RoleID int)
{

   DELETE from UserRoles where RoleID = in_RoleID;
   DELETE from Roles where RoleID = in_RoleID;

}
;


CREATE PROCEDURE 
Portal..GetSingleUser (in in_Email varchar)
{

   declare Name varchar (50);
   declare "Password" varchar (20);
   declare Email varchar (100);

   result_names (Email, "Password");

   for (SELECT Email as int_Email, "Password" as int_Password, Name as int_Name from Users where Email = in_Email) do
     {
       result (int_Email, int_Password);
     }

   end_result ();
}
;


CREATE PROCEDURE 
UpdateUser (in in_UserID int, in in_Email varchar, in in_Password varchar)
{

   UPDATE Users set Email = in_Email, "Password" = in_Password where UserId = in_UserID;
}
;


CREATE PROCEDURE 
Portal..GetSingleModuleDefinition (in in_ModuleDefID int)
{

   declare FriendlyName, DesktopSrc, MobileSrc varchar(256);

   result_names (FriendlyName, DesktopSrc, MobileSrc);

   for (SELECT FriendlyName as int_FriendlyName, DesktopSrc as int_DesktopSrc, MobileSrc as int_MobileSrc
	from ModuleDefinitions where ModuleDefID = in_ModuleDefID) do
     {
	result (int_FriendlyName, int_DesktopSrc, int_MobileSrc);	
     }

   end_result ();
}
;


CREATE PROCEDURE 
Portal..UpdateModuleDefinition (in in_ModuleDefID int, in in_FriendlyName varchar,
    				in in_DesktopSrc varchar, in in_MobileSrc varchar)
{

   UPDATE ModuleDefinitions set FriendlyName = in_FriendlyName, DesktopSrc = in_DesktopSrc, MobileSrc = in_MobileSrc
	where ModuleDefID = in_ModuleDefID;

}
;


CREATE PROCEDURE 
Portal..GetThreadMessages (in in_Parent varchar)
{

   declare ItemID integer;
   declare Title, CreatedByUser, Indent varchar(100);
   declare CreatedDate datetime;

   result_names (ItemID, Title, CreatedByUser, CreatedDate, Indent);

   for (SELECT ItemID as int_ItemID, DisplayOrder, 
       	       repeat( '&nbsp;', ( ( length( DisplayOrder ) / 23 ) - 1 ) * 2 ) AS int_Indent,
       	       Title as int_Title, CreatedByUser as int_CreatedByUser, CreatedDate as int_CreatedDate
       from Discussion where "LEFT" (DisplayOrder, 23) = in_Parent and (length ( DisplayOrder ) / 23 ) > 1
       order by DisplayOrder) do 
    {
       result (int_ItemID, int_Title, int_CreatedByUser, int_CreatedDate, int_Indent);
    }

}
;


CREATE PROCEDURE
Portal..GetSingleMessage (in in_ItemID int)
{

   declare nextMessageID, prevMessageID, ItemID integer;
   declare Title, CreatedByUser, Indent varchar(100);
   declare Body varchar(3000);
   declare CreatedDate datetime;

   result_names (Title, Body, CreatedByUser, CreatedDate, prevMessageID, nextMessageID);

   nextMessageID := GetNextMessageID (in_ItemID);
   prevMessageID := GetPrevMessageID (in_ItemID);

   for (SELECT ItemID, Title as int_Title, CreatedByUser as int_CreatedByUser,
	       CreatedDate as int_CreatedDate, Body as int_Body, DisplayOrder
	from Discussion where ItemID = in_ItemID) do
       {
	  result (int_Title, int_Body, int_CreatedByUser, int_CreatedDate, prevMessageID, nextMessageID);
       }

  end_result ();
}
;


CREATE PROCEDURE 
Portal..GetNextMessageID (in in_ItemID int)
{

   declare CurrentDisplayOrder varchar;
   declare CurrentModule, NextID integer;

-- Find DisplayOrder of current item 
   SELECT DisplayOrder, ModuleID into CurrentDisplayOrder, CurrentModule
	from Discussion where ItemID = in_ItemID;

-- Get the next message in the same module 

   if (exists (SELECT 1 from Discussion where DisplayOrder > CurrentDisplayOrder and ModuleID = CurrentModule))
     {
   SELECT Top 1 ItemID into NextID from Discussion 
	where DisplayOrder > CurrentDisplayOrder and ModuleID = CurrentModule order by DisplayOrder ASC;
     }
    else 
      NextID := null;

   return NextID; 
}
;


CREATE PROCEDURE 
Portal..GetPrevMessageID (in in_ItemID int)
{

   declare CurrentDisplayOrder varchar;
   declare CurrentModule, PrevID integer;

   SELECT DisplayOrder, ModuleID into CurrentDisplayOrder,CurrentModule
      from Discussion where ItemID = in_ItemID;



   if (exists (SELECT 1 from Discussion where DisplayOrder < CurrentDisplayOrder and ModuleID = CurrentModule))
   SELECT Top 1 ItemID into PrevID 
	from Discussion where DisplayOrder < CurrentDisplayOrder and ModuleID = CurrentModule 
	order by DisplayOrder desc;
    else
    PrevID := null;

  return PrevID;

}
;


CREATE PROCEDURE 
Portal..AddMessage (in ItemID int, in in_Title varchar, in in_Body varchar, in in_ParentID int,
		    in in_UserName varchar, in in_ModuleID int)   
{ 

   declare ParentDisplayOrder varchar;

   ParentDisplayOrder := '';

   SELECT DisplayOrder into ParentDisplayOrder from Discussion where ItemID = in_ParentID;

   INSERT into Discussion (Title, Body, DisplayOrder, CreatedDate, CreatedByUser, ModuleID)
	values (in_Title, in_Body, concat (ParentDisplayOrder, "LEFT" (datestring (Now()), 23)),
    		Now(), in_UserName, in_ModuleID);

   result_names (ItemID);
   result (identity_value ());
   end_result ();

   commit work;
}
;


CREATE PROCEDURE 
Portal..AddModule (in ModuleID int, in in_ModuleDefID int, in in_TabID int, in in_ModuleOrder int, 
		   in in_ModuleTitle varchar, in in_PaneName varchar, in in_CacheTime int, 
		   in in_EditRoles varchar, in in_ShowMobile int)
{

   INSERT into Modules (TabID, ModuleOrder, ModuleTitle, PaneName, ModuleDefID, CacheTime, 
			AuthorizedEditRoles, ShowMobile) 
		values (in_TabID, in_ModuleOrder, in_ModuleTitle, in_PaneName, in_ModuleDefID,
    			in_CacheTime, in_EditRoles, in_ShowMobile);

   result_names (ModuleID);
   result (identity_value ());
   end_result ();

}
;


CREATE PROCEDURE 
Portal..GetSingleRole (in in_RoleID int)
{
   declare RoleName varchar(50);

   result_names (RoleName);
   
   SELECT RoleName into RoleName from Roles where RoleID = in_RoleID;

   result (RoleName);

   end_result ();
}
;

