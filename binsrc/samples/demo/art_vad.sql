--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

USE Demo;


DB.DBA.exec_no_error('DROP TABLE demo.WorkOfArt');
DB.DBA.exec_no_error('DROP TABLE demo.Artist');
DB.DBA.exec_no_error('DROP TABLE demo.WorkOfArtType');

CREATE TABLE demo.Artist (
    ArtistID    INTEGER PRIMARY KEY,
    CountryCode VARCHAR references Countries (Code) on update cascade on delete cascade,
    Name        VARCHAR);

CREATE TABLE demo.WorkOfArtType (
    WorkArtTypeID INTEGER PRIMARY KEY,
    Description VARCHAR);

CREATE TABLE demo.WorkOfArt (
    WorkArtID   INTEGER PRIMARY KEY,
    CountryCode VARCHAR references Countries (Code) on update cascade on delete cascade,
    WorkArtType INTEGER references WorkOfArtType (WorkArtTypeID),
    ArtistID    INTEGER references Artist (ArtistID),
    Photo       LONG VARBINARY,
    PhotoDAVResourceName VARCHAR,
    PhotoDAVResourceURI VARCHAR,
    Description LONG VARCHAR);


INSERT INTO WorkOfArtType (WorkArtTypeID, Description) values (1, 'Painting');
INSERT INTO WorkOfArtType (WorkArtTypeID, Description) values (2, 'Sculpture');

INSERT INTO Artist (ArtistID, CountryCode, Name) values (1, 'nl', 'Rembrandt Harmenszoon van Rijn');


INSERT INTO WorkOfArt (WorkArtID,CountryCode,WorkArtType,ArtistID,Photo,Description, PhotoDAVResourceName)
    values (1, 'nl', 1, 1, DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/sample_data/images/art/JohannesElison.jpg'), 'Johannes Elison', 'JohannesElison.jpg');
INSERT INTO WorkOfArt (WorkArtID,CountryCode,WorkArtType,ArtistID,Photo,Description, PhotoDAVResourceName)
    values (2, 'nl', 1, 1, DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/sample_data/images/art/LaMarcheNocturne.jpg'), 'La Marche Nocturne', 'LaMarcheNocturne.jpg');
INSERT INTO WorkOfArt (WorkArtID,CountryCode,WorkArtType,ArtistID,Photo,Description, PhotoDAVResourceName)
    values (3, 'nl', 1, 1, DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/sample_data/images/art/SelfPortrait1628.jpg'), 'Self Portrait (1628)', 'SelfPortrait1628.jpg');
INSERT INTO WorkOfArt (WorkArtID,CountryCode,WorkArtType,ArtistID,Photo,Description, PhotoDAVResourceName)
    values (4, 'nl', 1, 1, DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/sample_data/images/art/SelfPortrait1640.jpg'), 'Self Portrait (1640)','SelfPortrait1640.jpg');
INSERT INTO WorkOfArt (WorkArtID,CountryCode,WorkArtType,ArtistID,Photo,Description, PhotoDAVResourceName)
    values (5, 'nl', 1, 1, DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/sample_data/images/art/TheArtistInHisStudio.jpg'), 'The Artist In His Studio', 'TheArtistInHisStudio.jpg');
INSERT INTO WorkOfArt (WorkArtID,CountryCode,WorkArtType,ArtistID,Photo,Description, PhotoDAVResourceName)
    values (6, 'nl', 1, 1, DB.DBA.get_blob_from_dav ('/DAV/VAD/demo/sample_data/images/art/TheReturnOfTheProdigalSon.jpg'), 'The Return Of The Prodigal Son', 'TheReturnOfTheProdigalSon.jpg');


create procedure fill_art_pict ()
{
  declare rc int;
  --declare pwd any;
  --pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  --DB.DBA.DAV_COL_CREATE ('/DAV/sample_data/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  --DB.DBA.DAV_COL_CREATE ('/DAV/sample_data/images/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  --DB.DBA.DAV_COL_CREATE ('/DAV/sample_data/images/art/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  for select PhotoDAVResourceName as name, WorkArtID as ID from WorkOfArt do
    {
      --DB.DBA.DAV_RES_UPLOAD ('/DAV/sample_data/images/art/'||name, file_to_string ('art/'||name), '', '110100100NN', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
      if (isstring (registry_get ('URIQADefaultHost')))
	update WorkOfArt set PhotoDAVResourceURI = 'http://' || registry_get ('URIQADefaultHost') ||  '/DAV/sample_data/images/art/' || name where WorkArtID = id;
      else
        update WorkOfArt set PhotoDAVResourceURI = '/DAV/sample_data/images/art/' || name where WorkArtID = id;
    }
};

fill_art_pict ();

DB.DBA.exec_no_error('drop procedure fill_art_pict');

select count(*) from WorkOfArt;
--ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
--ECHO BOTH ": " $LAST[1] " Paintings loaded\n";
