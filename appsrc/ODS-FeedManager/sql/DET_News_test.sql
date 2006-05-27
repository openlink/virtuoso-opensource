set echo on;
set verbose off;

create procedure
TEST_DAV_RES_CONTENT (in path varchar, in auth_uname varchar := null, in auth_pwd varchar := null)
{
  declare content any;
  declare type varchar;
  declare rc integer;
  rc := DAV_RES_CONTENT (path, content, type, auth_uname, auth_pwd);
  return concat (sprintf ('Status %d\nType %s\n', rc, type), blob_to_string (content));
}
;

select DAV_ADD_GROUP ('aziz', 'dav', 'dav');
select DAV_ADD_USER ('aziz', '1', 'aziz', '110100000T', 0, '/DAV/home/aziz/', 'User aziz of group aziz', 'aziz@localhost', 'dav', 'dav');

-- test begin here

-- DET folder creation
select DAV_COL_CREATE ('/DAV/home/aziz/My Feeds/', '110110110R', 'aziz', 'aziz', 'dav', 'dav');
update WS.WS.SYS_DAV_COL set COL_DET='News3' where COL_ID = DAV_SEARCH_ID ('/DAV/home/aziz/My Feeds/', 'C');

-- check list of feed folders
select length(DAV_DIR_LIST('/DAV/home/aziz/My Feeds/', 0, 'aziz', '1'));
select DAV_SEARCH_ID('/DAV/home/aziz/My Feeds/', 'C');

-- check list of "LiveJournal News" ('new' livejournal) feed posts
select DAV_SEARCH_ID('/DAV/home/aziz/My Feeds/LiveJournal News/', 'C');
select length(DAV_DIR_LIST('/DAV/home/aziz/My Feeds/LiveJournal News/', 0, 'aziz', '1'));

-- check list of "The C++ Community" ('cpp' livejournal) feed posts
select DAV_SEARCH_ID('/DAV/home/aziz/My Feeds/The C++ Community/', 'C');
select length(DAV_DIR_LIST('/DAV/home/aziz/My Feeds/The C++ Community/', 0, 'aziz', '1'));

-- read the rss.xml file for LiveJournal News ('new' livejournal)
select DAV_SEARCH_ID('/DAV/home/aziz/My Feeds/LiveJournal News.xml', 'R');
select TEST_DAV_RES_CONTENT('/DAV/home/aziz/My Feeds/LiveJournal News.xml', 'aziz', '1');

-- read the rss.xml file for The C++ Community ('cpp' livejournal)
select DAV_SEARCH_ID('/DAV/home/aziz/My Feeds/The C++ Community.xml', 'R');
select TEST_DAV_RES_CONTENT('/DAV/home/aziz/My Feeds/The C++ Community.xml', 'aziz', '1');
