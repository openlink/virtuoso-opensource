--DB.DBA.VHOST_DEFINE (lpath=>'/domain_test', ppath=>'/DAV/VAD/domain_test/', is_dav=>1, vsp_user=>'dba', def_page=>'index.vsp');


create procedure DB.DBA.SEARCH_DOMAIN_NAMECHEAP (in domain_name varchar, in username varchar,  in api_key varchar, in client_ip varchar, in proxy_server varchar := '')
{
	declare xd, xt, url, tmp, hdr any;
	declare exit handler for sqlstate '*'
	{
		--dbg_obj_princ(__SQL_MESSAGE); 	
		return -1;
	};
	url := sprintf('https://api.namecheap.com/xml.response?ApiUser=%s&ApiKey=%s&UserName=%s&Command=namecheap.domains.check&ClientIp=%s&DomainList=%s', username, api_key, username, client_ip, domain_name);
--dbg_obj_princ(url);
	tmp := http_client_ext (url, headers=>hdr, proxy=>proxy_server);
--dbg_obj_princ(tmp);
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	xt := cast (xpath_eval(sprintf('/ApiResponse/CommandResponse/DomainCheckResult[@Domain="%s"]/@Available', domain_name), xd) as varchar);
	if (xt = 'true')
		return 1;
	else
		return 0;
}
;

create procedure DB.DBA.CREATE_DOMAIN_NAMECHEAP (in domain_name varchar, in username varchar,  in api_key varchar, in client_ip varchar,
in years integer, 
in firstName varchar,
in lastName varchar,
in addr1 varchar,
in province varchar,
in zip varchar,
in country varchar,
in phone varchar,
in email varchar,
in org varchar,
in city varchar,
in proxy_server varchar := '')
{
	declare xd, xt, url, tmp, hdr any;
	declare exit handler for sqlstate '*'
	{
		--dbg_obj_princ(__SQL_MESSAGE); 	
		return -1;
	};
	url := sprintf('https://api.namecheap.com/xml.response?ApiUser=%s&ApiKey=%s&UserName=%s&Command=namecheap.domains.create&ClientIp=%s&DomainName=%s&Years=%d&AuxBillingFirstName=%s&AuxBillingLastName=%s&AuxBillingAddress1=%s&AuxBillingStateProvince=%s&AuxBillingPostalCode=%s&AuxBillingCountry=%s&AuxBillingPhone=%s&AuxBillingEmailAddress=%s&AuxBillingOrganizationName=%s&AuxBillingCity=%s&TechFirstName=%s&TechLastName=%s&TechAddress1=%s&TechStateProvince=%s&TechPostalCode=%s&TechCountry=%s&TechPhone=%s&TechEmailAddress=%s&TechOrganizationName=%s&TechCity=%s&AdminFirstName=%s&AdminLastName=%s&AdminAddress1=%s&AdminStateProvince=%s&AdminPostalCode=%s&AdminCountry=%s&AdminPhone=%s&AdminEmailAddress=%s&AdminOrganizationName=%s&AdminCity=%s&RegistrantFirstName=%s&RegistrantLastName=%s&RegistrantAddress1=%s&RegistrantStateProvince=%s&RegistrantPostalCode=%s&RegistrantCountry=%s&RegistrantPhone=%s&RegistrantEmailAddress=%s&RegistrantOrganizationName=%s&RegistrantCity=%s',
	username, api_key, username, client_ip, domain_name, years,
	firstName, lastName, addr1, province, zip, country, phone, email, org, city,
	firstName, lastName, addr1, province, zip, country, phone, email, org, city,
	firstName, lastName, addr1, province, zip, country, phone, email, org, city,
	firstName, lastName, addr1, province, zip, country, phone, email, org, city
	);
	tmp := http_client_ext (url, headers=>hdr, proxy=>proxy_server);
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	xt := cast (xpath_eval(sprintf('/ApiResponse/CommandResponse/DomainCreateResult[@Domain="%s"]/@Registered', domain_name), xd) as varchar);
	if (xt = 'true')
		return 1;
	else
		return 0;
}
;

create procedure DB.DBA.SEARCH_DOMAIN_INTERNETBS (in domain_name varchar, in pass varchar,  in api_key varchar, in proxy_server varchar := '')
{
	declare xd, xt, url, tmp, hdr any;
	declare exit handler for sqlstate '*'
	{
		--dbg_obj_princ(__SQL_MESSAGE); 	
		return -1;
	};
	url := sprintf('https://testapi.internet.bs/Domain/Check?Domain=%s&ApiKey=%s&Password=%s&ResponseFormat=xml', domain_name, api_key, pass);
	tmp := http_client_ext (url, headers=>hdr, proxy=>proxy_server);
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	xt := cast (xpath_eval('/response/status', xd) as varchar);
	if (xt = 'AVAILABLE')
		return 1;
	else
		return 0;
}
;

create procedure DB.DBA.CREATE_DOMAIN_INTERNETBS (in domain_name varchar, in pass varchar,  in api_key varchar,
in years integer, 
in firstName varchar,
in lastName varchar,
in addr1 varchar,
in zip varchar,
in country varchar,
in phone1 varchar,
in email varchar,
in org varchar,
in city varchar,
in proxy_server varchar := '')
{
	declare xd, xt, url, tmp, hdr any;
	declare phone varchar;
	phone := replace(phone1, '+', '%2B');
	declare exit handler for sqlstate '*'
	{
		--dbg_obj_princ(__SQL_MESSAGE); 	
		return -1;
	};
	url := sprintf('https://testapi.internet.bs/Domain/Create?ResponseFormat=xml&ApiKey=%s&Password=%s&registrant_email=%s&registrant_firstname=%s&registrant_lastname=%s&registrant_organization=%s&registrant_street=%s&registrant_countrycode=%s&registrant_postalcode=%s&Domain=%s&registrant_phonenumber=%s&registrant_obfuscateemail=1&technical_firstname=%s&technical_lastname=%s&technical_organization=%s&technical_street=%s&technical_countrycode=%s&technical_postalcode=%s&technical_email=%s&technical_phonenumber=%s&admin_firstname=%s&admin_lastname=%s&admin_organization=%s&admin_street=%s&admin_countrycode=%s&admin_postalcode=%s&admin_email=%s&admin_phonenumber=%s&registrant_city=%s&technical_city=%s&admin_city=%s&billing_firstname=%s&billing_lastname=%s&billing_organization=%s&billing_street=%s&billing_countrycode=%s&billing_postalcode=%s&billing_email=%s&billing_phonenumber=%s&billing_city=%s&privatewhois=partial&period=%dy',
	api_key, pass, email,
	firstName, lastName, org, addr1, country, zip, domain_name, phone,
	firstName, lastName, org, addr1, country, zip, email, phone,
	firstName, lastName, org, addr1, country, zip, email, phone,
	city, city, city,
	firstName, lastName, org, addr1, country, zip, email, phone,
	city, years
	);
	url := replace(url, ' ', '+');
--dbg_obj_princ(url);
	tmp := http_client_ext (url, headers=>hdr, proxy=>proxy_server);
--dbg_obj_princ(tmp);
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	xt := cast (xpath_eval('/response/product/status', xd) as varchar);
--dbg_obj_princ(xt);
	if (xt = 'SUCCESS')
		return 1;
	else
		return 0;
}
;
