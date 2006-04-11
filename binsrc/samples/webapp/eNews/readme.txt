Overview
--------

This application allows for users to register and define own themes for interest. 
The user's profile cntains channels and category, once user registred it should add some 
channel(s) to his profile. 
When channal data is feeded the user can see the incoming news via monitor.

In practice the Moreover newsfeed application downloads a XML news feeds from the Moreover site and store into the local WebDAV repository.
The automatic download is done with Web Import APIterface. For each channel we have defined a one target with automatic scheduled update.


The application have following pages:

- registration 
  allows to an new user to register in application (ie. make a new account)
  Hi must supply the names, password and e-mail. Passowrds are keeped as MD5 in the Database,
  so no way to be decrypted or restored. After registration to the user will be sent an e-mail, 
  that menans it is registred.
    
- login 
  allows an existing user to authorize and continue with application 
  the new users supplied a name, password, e-mail 
  after sucessful registration they will receive an e-mail from eNews admin 
  
  after sucessful registration or login users will be redirected to the configuration page if no channels(articles) 
  added to their profiles.
  
- configuration
  allows to alredy registred users to choose a own articles from channels
  and add to their profile. After this tep is done and at least one channel added,
  the user will be redirected to the watch page.
  
- news watch
  The configured in feeds can be viewed

  This is a fame that allows users to select channel for monitoring. 
  The incoming news can be displayed as a table and different styles.  




Instalation
-----------

- make the eNews directory under HTTP Root
- copy all files into the directory eNews
- apply eNews.sql as dba user 
- edit enews.ini and set mail server and eNews admin e-mail   
- make /DAV/css folder onto the WebDAV repository and put the one.css an two.css
- make /DAV/NewsfeedsList/categories/ folder and put the category_list_pctsv.tsv
- execute the updateNewsList() procedure
- make the ~/eNews directory executable for VSPs (via Virtual Directories UI)


