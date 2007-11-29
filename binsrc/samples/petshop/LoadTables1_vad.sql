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
--RECONNECT "petshop";

DB.DBA.user_set_qualifier ('petshop', 'MSPetShop');
set_user_id('petshop', 1, DB.DBA.GET_PWD_FOR_VAD('password'));

INSERT SOFT "SignOn" VALUES('DotNet', 'DotNet');
INSERT SOFT "Account" VALUES('DotNet', 'yourname@yourdomain.com', 'ABC', 'XYX', 'OK', '901 San Antonio Road', 'MS UCUP02-206', 'Palo Alto', 'CA', '94303', 'USA', '555-555-5555');
INSERT SOFT "Profile" VALUES('DotNet', 'English', 'Dogs', 1, 1);

INSERT SOFT "SignOn" VALUES('ACID', 'ACID');
INSERT SOFT "Account" VALUES('ACID', 'test@rollback.com', 'Distributed', 'Transaction', 'OK', 'PO Box 4482', '', 'Carmel', 'CA', '93921', 'USA', '831-625-1861');
INSERT SOFT "Profile" VALUES('ACID', 'English', 'Birds', 1, 1);

INSERT SOFT "BannerData" VALUES ('Fish', '<img src="Images/bannerFish.gif">');
INSERT SOFT "BannerData" VALUES ('Cats', '<img src="Images/bannerCats.gif">');
INSERT SOFT "BannerData" VALUES ('Dogs', '<img src="Images/bannerDogs.gif">');
INSERT SOFT "BannerData" VALUES ('Reptiles', '<img src="Images/bannerReptiles.gif">');
INSERT SOFT "BannerData" VALUES ('Birds', '<img src="Images/bannerBirds.gif">');

INSERT SOFT "Category" VALUES ('FISH', 'Fish', NULL);
INSERT SOFT "Category" VALUES ('DOGS', 'Dogs', NULL);
INSERT SOFT "Category" VALUES ('REPTILES', 'Reptiles', NULL);
INSERT SOFT "Category" VALUES ('CATS', 'Cats', NULL);
INSERT SOFT "Category" VALUES ('BIRDS', 'Birds', NULL);

INSERT SOFT "Product" VALUES ('FI-SW-01', 'FISH', 'Angelfish', '<img align="absmiddle" src="Images/Pets/fish1.jpg">Saltwater fish from Australia');
INSERT SOFT "Product" VALUES ('FI-SW-02', 'FISH', 'Tiger Shark', '<img align="absmiddle" src="Images/Pets/fish2.jpg">Saltwater fish from Australia');
INSERT SOFT "Product" VALUES ('FI-FW-01', 'FISH', 'Koi', '<img align="absmiddle" src="Images/Pets/fish3.jpg">Freshwater fish from Japan');
INSERT SOFT "Product" VALUES ('FI-FW-02', 'FISH', 'Goldfish', '<img align="absmiddle" src="Images/Pets/fish4.jpg">Freshwater fish from China');
INSERT SOFT "Product" VALUES ('K9-BD-01', 'DOGS', 'Bulldog', '<img align="absmiddle" src="Images/Pets/dog1.jpg">Friendly dog from England');
INSERT SOFT "Product" VALUES ('K9-PO-02', 'DOGS', 'Poodle', '<img align="absmiddle" src="Images/Pets/dog2.jpg">Cute dog from France');
INSERT SOFT "Product" VALUES ('K9-DL-01', 'DOGS', 'Dalmation', '<img align="absmiddle" src="Images/Pets/dog3.jpg">Great dog for a fire station');
INSERT SOFT "Product" VALUES ('K9-RT-01', 'DOGS', 'Golden Retriever', '<img align="absmiddle" src="Images/Pets/dog4.jpg">Great family dog');
INSERT SOFT "Product" VALUES ('K9-RT-02', 'DOGS', 'Labrador Retriever', '<img align="absmiddle" src="Images/Pets/dog5.jpg">Great hunting dog');
INSERT SOFT "Product" VALUES ('K9-CW-01', 'DOGS', 'Chihuahua', '<img align="absmiddle" src="Images/Pets/dog6.jpg">Great companion dog');
INSERT SOFT "Product" VALUES ('RP-SN-01', 'REPTILES', 'Rattlesnake', '<img align="absmiddle" src="Images/Pets/reptile1.jpg">Doubles as a watch dog');
INSERT SOFT "Product" VALUES ('RP-LI-02', 'REPTILES', 'Iguana', '<img align="absmiddle" src="Images/Pets/reptile2.jpg">Friendly green friend');
INSERT SOFT "Product" VALUES ('FL-DSH-01', 'CATS', 'Manx', '<img align="absmiddle" src="Images/Pets/cat1.jpg">Great for reducing mouse populations');
INSERT SOFT "Product" VALUES ('FL-DLH-02', 'CATS', 'Persian', '<img align="absmiddle" src="Images/Pets/cat2.jpg">Friendly house cat, doubles as a princess');
INSERT SOFT "Product" VALUES ('AV-CB-01', 'BIRDS', 'Amazon Parrot', '<img align="absmiddle" src="Images/Pets/bird1.jpg">Great companion for up to 75 years');
INSERT SOFT "Product" VALUES ('AV-SB-02', 'BIRDS', 'Finch', '<img align="absmiddle" src="Images/Pets/bird2.jpg">Great stress reliever');

INSERT SOFT "Supplier" VALUES (1, 'XYZ Pets', 'AC', '600 Avon Way', '', 'Los Angeles', 'CA', '94024', '212-947-0797');
INSERT SOFT "Supplier" VALUES (2, 'ABC Pets', 'AC', '700 Abalone Way', '', 'San Francisco', 'CA', '94024', '415-947-0797');

INSERT SOFT "Item" VALUES ('EST-1', 'FI-SW-01', 16.50, 10.00, 1, 'P', 'Large', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-2', 'FI-SW-01', 16.50, 10.00, 1, 'P', 'Small', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-3', 'FI-SW-02', 18.50, 12.00, 1, 'P', 'Toothless', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-4', 'FI-FW-01', 18.50, 12.00, 1, 'P', 'Spotted', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-5', 'FI-FW-01', 18.50, 12.00, 1, 'P', 'Spotless', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-6', 'K9-BD-01', 18.50, 12.00, 1, 'P', 'Male Adult', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-7', 'K9-BD-01', 18.50, 12.00, 1, 'P', 'Female Puppy', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-8', 'K9-PO-02', 18.50, 12.00, 1, 'P', 'Male Puppy', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-9', 'K9-DL-01', 18.50, 12.00, 1, 'P', 'Spotless Male Puppy', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-10', 'K9-DL-01', 18.50, 12.00, 1, 'P', 'Spotted Adult Female', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-11', 'RP-SN-01', 18.50, 12.00, 1, 'P', 'Venomless', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-12', 'RP-SN-01', 18.50, 12.00, 1, 'P', 'Rattleless', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-13', 'RP-LI-02', 18.50, 12.00, 1, 'P', 'Green Adult', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-14', 'FL-DSH-01', 58.50, 12.00, 1, 'P', 'Tailless', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-15', 'FL-DSH-01', 23.50, 12.00, 1, 'P', 'Tailed', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-16', 'FL-DLH-02', 93.50, 12.00, 1, 'P', 'Adult Female', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-17', 'FL-DLH-02', 93.50, 12.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-18', 'AV-CB-01', 193.50, 92.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-19', 'AV-SB-02', 15.50, 2.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-20', 'FI-FW-02', 5.50, 2.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-21', 'FI-FW-02', 5.29, 1.00, 1, 'P', 'Adult Female', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-22', 'K9-RT-02', 135.50, 100.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-23', 'K9-RT-02', 145.49, 100.00, 1, 'P', 'Adult Female', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-24', 'K9-RT-02', 255.50, 92.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-25', 'K9-RT-02', 325.29, 90.00, 1, 'P', 'Adult Female', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-26', 'K9-CW-01', 125.50, 92.00, 1, 'P', 'Adult Male', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-27', 'K9-CW-01', 155.29, 90.00, 1, 'P', 'Adult Female', NULL, NULL, NULL, NULL);
INSERT SOFT "Item" VALUES ('EST-28', 'K9-RT-01', 155.29, 90.00, 1, 'P', 'Adult Female', NULL, NULL, NULL, NULL);

INSERT SOFT "Inventory" VALUES ('EST-1', 10000);
INSERT SOFT "Inventory" VALUES ('EST-2', 10000);
INSERT SOFT "Inventory" VALUES ('EST-3', 10000);
INSERT SOFT "Inventory" VALUES ('EST-4', 10000);
INSERT SOFT "Inventory" VALUES ('EST-5', 10000);
INSERT SOFT "Inventory" VALUES ('EST-6', 10000);
INSERT SOFT "Inventory" VALUES ('EST-7', 10000);
INSERT SOFT "Inventory" VALUES ('EST-8', 10000);
INSERT SOFT "Inventory" VALUES ('EST-9', 10000);
INSERT SOFT "Inventory" VALUES ('EST-10', 10000);
INSERT SOFT "Inventory" VALUES ('EST-11', 10000);
INSERT SOFT "Inventory" VALUES ('EST-12', 10000);
INSERT SOFT "Inventory" VALUES ('EST-13', 10000);
INSERT SOFT "Inventory" VALUES ('EST-14', 10000);
INSERT SOFT "Inventory" VALUES ('EST-15', 10000);
INSERT SOFT "Inventory" VALUES ('EST-16', 10000);
INSERT SOFT "Inventory" VALUES ('EST-17', 10000);
INSERT SOFT "Inventory" VALUES ('EST-18', 10000);
INSERT SOFT "Inventory" VALUES ('EST-19', 10000);
INSERT SOFT "Inventory" VALUES ('EST-20', 10000);
INSERT SOFT "Inventory" VALUES ('EST-21', 10000);
INSERT SOFT "Inventory" VALUES ('EST-22', 10000);
INSERT SOFT "Inventory" VALUES ('EST-23', 10000);
INSERT SOFT "Inventory" VALUES ('EST-24', 10000);
INSERT SOFT "Inventory" VALUES ('EST-25', 10000);
INSERT SOFT "Inventory" VALUES ('EST-26', 10000);
INSERT SOFT "Inventory" VALUES ('EST-27', 10000);
INSERT SOFT "Inventory" VALUES ('EST-28', 10000);
