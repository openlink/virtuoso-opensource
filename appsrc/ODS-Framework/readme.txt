setup

*make sure wa directory is under your http root as "webapp" , or change the
hosted_services.sql instead
*load hosted_services.sql as DBA via ISQL tool
* hit http://host:port/ods , if you see login there all is installed

Below are the infrastructure components for hosted services, such as blogs,
    wikis and anything else.   Compare this to the many-to-many between
    various
    yahoo features and yahoo accounts.


    create type web_app as
    wa_name varchar,
    wa_member_model int,

    method wa_id_string (), -- string in memberships list
    method wa__join_request (login varchar),
    method wa_state_edit_form (inout stream any), -- emit a state
    edit  form
    into the stream, present this to owner for setting the state
    wa_state_posted (in post any, inout stream),  -- process a
    post,
    updateing state and writing a reply into the stream for web
    interface
    method wa_home_url () returns varchar -- e the homepage url
    of the
    service instance
    method wa_periodic_activity () -- send reminders,
    invoices, refresh
    content whatever is regularly done.
    ...);




    create table wa_types (wat_name varchar, wat_type varchar,
	primary key (wat_name));

-- wat_name is the print name of the service, e.g. blog.  wat_type is  the
udt name of a web_app subclass representing the service instance.

create table wa_instance (wai_name varchar,  wai_inst web_app,
    primary key (wai_name));


create table wa_member (wam_user int,-- references sys_users
    wam_inst varchar references wa_instance,
    wam_member_type int
    primary key (wam_user, wam_inst, wam_member_type))

    -- the member type is one of 1= owner 2= admin 3=regular  Depending on
    service type, other membership forms may exist.

    When a user makes a service instance this user becomes the owner . This
    is
    irrevocable except by the owner self or system admin.

    The UI will consist of:

    -- page for making accounts
    - page for making service instances.  Show list of service types, make  an
    instance of one with the logged in user as owner.

    page for listing existing service instances by type (allow for tyope
	spec,
	e.g. blogs only, wikis only)
    Have a link for requesting to join, will  be handled according to the
    service instance's policies.


    Page for service memberships - blogs, wikis etc where one participates,
    lists the membership status.  For owned services allows going to the
    service dependent config page.  Allows dropping the membership in
    non-owned
    services.  Will have a link to the service instance's home  page.




The added properties are:

- Is the member list visible to other members?  Administrators and  owner
will  have access to this.

- Is the service viewable to public?  If so, it will appear in the  service
instance list, otherwise not.


Other:

- the membership application pending approval is marked by a value in  the
membership class field of the membership table.  Have -1 or  something less
than all others to create a simple membership check of  >= 0.


Pages:
Selecting a service instance will go to the home page of said service
instance, not show the members.

- The my services  page will show all services with some type of
membership.  There will be a link for membership options.  his will be  a
URL to a page chosen in function of the user and the service  instance.  For
owners this is editing the service instance's options.   For other members
this is setting attributes of membership.  These can  be notification
delivery email, screen name in the service, any service  dependent user
preferences which are not the service instance's global  attributes.  The
method may best return a link to another page.


Each service instance will have a public home page.  This will,  depending
on the type of public access show varying information.  If  the service is
completely not public accessible then this may only show  a logun form.  For
owners and administrators this may show a different  content and different
menu choices etc.  For all membership categories  except owner this will
show a terminate membership choice which will  ask for confirmation.

***



