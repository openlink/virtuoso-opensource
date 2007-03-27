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

-- =======================================================
-- INSERT INITIAL DATA INTO IBUYSPY Store DB
-- =======================================================

-- point to proper DB

DB.DBA.user_set_qualifier ('portal', 'Portal'); 

delete from Categories;
delete from Customers;
delete from Orders;
delete from OrderDetails;
delete from Products;
delete from Reviews;
delete from ShoppingCart;

DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Categories',   'CategoryID',1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Customers',    'CustomerID', 1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Orders',       'OrderID', 1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.OrderDetails', 'OrderID', 0);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Products',     'ProductID', 1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.Reviews',      'ReviewID', 1);
DB.DBA.SET_IDENTITY_COLUMN ('Portal.demo.ShoppingCart', 'RecordID', 1);

INSERT INTO Categories (CategoryID,CategoryName) VALUES (14,'Communications');
INSERT INTO Categories (CategoryID,CategoryName) VALUES (15,'Deception');
INSERT INTO Categories (CategoryID,CategoryName) VALUES (16,'Travel');
INSERT INTO Categories (CategoryID,CategoryName) VALUES (17,'Protection');
INSERT INTO Categories (CategoryID,CategoryName) VALUES (18,'Munitions');
INSERT INTO Categories (CategoryID,CategoryName) VALUES (19,'Tools');
INSERT INTO Categories (CategoryID,CategoryName) VALUES (20,'General');


INSERT INTO Customers (CustomerID,FullName,EmailAddress,"Password") VALUES (1,'James Bondwell','jb@ibuyspy.com','IBS_007');
INSERT INTO Customers (CustomerID,FullName,EmailAddress,"Password") VALUES (2,'Sarah Goodpenny','sg@ibuyspy.com','IBS_001');
INSERT INTO Customers (CustomerID,FullName,EmailAddress,"Password") VALUES (3,'Gordon Que','gq@ibuyspy.com','IBS_000');
INSERT INTO Customers (CustomerID,FullName,EmailAddress,"Password") VALUES (19,'Guest Account','guest','guest');
INSERT INTO Customers (CustomerID,FullName,EmailAddress,"Password") VALUES (16,'Test Account','d','d');



INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (99,19,stringdate ('2000-07-06 01:01:00.000'), stringdate ('2000-07-07 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (93,16,stringdate ('2000-07-03 01:01:00.000'), stringdate ('2000-07-04 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (101,16,stringdate ('2000-07-10 01:01:00.000'), stringdate ('2000-07-11 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (103,16,stringdate ('2000-07-10 01:01:00.000'), stringdate ('2000-07-10 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (96,19,stringdate ('2000-07-03 01:01:00.000'), stringdate ('2000-07-03 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (104,19,stringdate ('2000-07-10 01:01:00.000'), stringdate ('2000-07-11 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (105,16,stringdate ('2000-10-30 01:01:00.000'), stringdate ('2000-10-31 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (106,16,stringdate ('2000-10-30 01:01:00.000'), stringdate ('2000-10-30 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (107,16,stringdate ('2000-10-30 01:01:00.000'), stringdate ('2000-10-31 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (100,19,stringdate ('2000-07-06 01:01:00.000'), stringdate ('2000-07-08 01:01:00.000'));
INSERT INTO Orders (OrderID,CustomerID,OrderDate,ShipDate) VALUES (102,16,stringdate ('2000-07-10 01:01:00.000'), stringdate ('2000-07-12 01:01:00.000'));


INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (99,404,2,459.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (93,363,1,1.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (101,378,2,14.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (102,372,1,129.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (96,378,1,14.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (103,363,1,1.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (104,355,1,1499.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (104,378,1,14.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (104,406,1,399.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (100,404,2,459.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (101,401,1,599.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (102,401,1,599.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (104,362,1,1.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (104,404,1,459.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (105,355,2,1499.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (106,401,1,599.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (106,404,2,459.99);
INSERT INTO OrderDetails (OrderID,ProductID,Quantity,UnitCost) VALUES (107,368,2,19999.98);


INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (355,16,'RU007','Rain Racer 2000','image.gif',1499.99,'Looks like an ordinary bumbershoot, but don\'t be fooled! Simply place Rain Racer\'s tip on the ground and press the release latch. Within seconds, this ordinary rain umbrella converts into a two-wheeled gas-powered mini-scooter. Goes from 0 to 60 in 7.5 seconds - even in a driving rain! Comes in black, blue, and candy-apple red.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (356,20,'STKY1','Edible Tape','image.gif',3.99,'The latest in personal survival gear, the STKY1 looks like a roll of ordinary office tape, but can save your life in an emergency.  Just remove the tape roll and place in a kettle of boiling water with mixed vegetables and a ham shank. In just 90 minutes you have a great tasking soup that really sticks to your ribs! Herbs and spices not included.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (357,16,'P38','Escape Vehicle (Air)','image.gif',2.99,'In a jam, need a quick escape? Just whip out a sheet of our patented P38 paper and, with a few quick folds, it converts into a lighter-than-air escape vehicle! Especially effective on windy days - no fuel required. Comes in several sizes including letter, legal, A10, and B52.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (358,19,'NOZ119','Extracting Tool','image.gif',199,'High-tech miniaturized extracting tool. Excellent for extricating foreign objects from your person. Good for picking up really tiny stuff, too! Cleverly disguised as a pair of tweezers. ');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (359,16,'PT109','Escape Vehicle (Water)','image.gif',1299.99,'Camouflaged as stylish wing tips, these \'shoes\' get you out of a jam on the high seas instantly. Exposed to water, the pair transforms into speedy miniature inflatable rafts. Complete with 76 HP outboard motor, these hip heels will whisk you to safety even in the roughest of seas. Warning: Not recommended for beachwear.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (360,14,'RED1','Communications Device','image.gif',49.99,'Subversively stay in touch with this miniaturized wireless communications device. Speak into the pointy end and listen with the other end! Voice-activated dialing makes calling for backup a breeze. Excellent for undercover work at schools, rest homes, and most corporate headquarters. Comes in assorted colors.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (362,14,'LK4TLNT','Persuasive Pencil','image.gif',1.99,'Persuade anyone to see your point of view!  Captivate your friends and enemies alike!  Draw the crime-scene or map out the chain of events.  All you need is several years of training or copious amounts of natural talent. You\'re halfway there with the Persuasive Pencil. Purchase this item with the Retro Pocket Protector Rocket Pack for optimum disguise.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (363,18,'NTMBS1','Multi-Purpose Rubber Band','image.gif',1.99,'One of our most popular items!  A band of rubber that stretches  20 times the original size. Uses include silent one-to-one communication across a crowded room, holding together a pack of Persuasive Pencils, and powering lightweight aircraft. Beware, stretching past 20 feet results in a painful snap and a rubber strip.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (364,19,'NE1RPR','Universal Repair System','image.gif',4.99,'Few people appreciate the awesome repair possibilities contained in a single roll of duct tape. In fact, some houses in the Midwest are made entirely out of the miracle material contained in every roll! Can be safely used to repair cars, computers, people, dams, and a host of other items.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (365,19,'BRTLGT1','Effective Flashlight','image.gif',9.99,'The most powerful darkness-removal device offered to creatures of this world.  Rather than amplifying existing/secondary light, this handy product actually REMOVES darkness allowing you to see with your own eyes.  Must-have for nighttime operations. An affordable alternative to the Night Vision Goggles.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (367,18,'INCPPRCLP','The Incredible Versatile Paperclip','image.gif',1.49,'This 0. 01 oz piece of metal is the most versatile item in any respectable spy\'s toolbox and will come in handy in all sorts of situations. Serves as a wily lock pick, aerodynamic projectile (used in conjunction with Multi-Purpose Rubber Band), or escape-proof finger cuffs.  Best of all, small size and pliability means it fits anywhere undetected.  Order several today!');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (368,16,'DNTRPR','Toaster Boat','image.gif',19999.98,'Turn breakfast into a high-speed chase! In addition to toasting bagels and breakfast pastries, this inconspicuous toaster turns into a speedboat at the touch of a button. Boasting top speeds of 60 knots and an ultra-quiet motor, this valuable item will get you where you need to be ... fast! Best of all, Toaster Boat is easily repaired using a Versatile Paperclip or a standard butter knife. Manufacturer\'s Warning: Do not submerge electrical items.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (370,17,'TGFDA','Multi-Purpose Towelette','image.gif',12.99,'Don\'t leave home without your monogrammed towelette! Made from lightweight, quick-dry fabric, this piece of equipment has more uses in a spy\'s day than a Swiss Army knife. The perfect all-around tool while undercover in the locker room: serves as towel, shield, disguise, sled, defensive weapon, whip and emergency food source. Handy bail gear for the Toaster Boat. Monogram included with purchase price.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (371,18,'WOWPEN','Mighty Mighty Pen','image.gif',129.99,'Some spies claim this item is more powerful than a sword. After examining the titanium frame, built-in blowtorch, and Nerf dart-launcher, we tend to agree! ');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (372,20,'ICNCU','Perfect-Vision Glasses','image.gif',129.99,'Avoid painful and potentially devastating laser eye surgery and contact lenses. Cheaper and more effective than a visit to the optometrist, these Perfect-Vision Glasses simply slide over nose and eyes and hook on ears. Suddenly you have 20/20 vision! Glasses also function as HUD (Heads Up Display) for most European sports cars manufactured after 1992.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (373,17,'LKARCKT','Pocket Protector Rocket Pack','image.gif',1.99,'Any debonair spy knows that this accoutrement is coming back in style. Flawlessly protects the pockets of your short-sleeved oxford from unsightly ink and pencil marks. But there\'s more! Strap it on your back and it doubles as a rocket pack. Provides enough turbo-thrust for a 250-pound spy or a passel of small children. Maximum travel radius: 3000 miles.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (374,15,'DNTGCGHT','Counterfeit Creation Wallet','image.gif',999.99,'Don\'t be caught penniless in Prague without this hot item! Instantly creates replicas of most common currencies! Simply place rocks and water in the wallet, close, open up again, and remove your legal tender!');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (375,16,'WRLD00','Global Navigational System','image.gif',29.99,'No spy should be without one of these premium devices. Determine your exact location with a quick flick of the finger. Calculate destination points by spinning, closing your eyes, and stopping it with your index finger.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (376,15,'CITSME9','Cloaking Device','image.gif',9999.99,'Worried about detection on your covert mission? Confuse mission-threatening forces with this cloaking device. Powerful new features include string-activated pre-programmed phrases such as \'Danger! Danger!\', \'Reach for the sky!\', and other anti-enemy expressions. Hyper-reactive karate chop action deters even the most persistent villain.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (377,15,'BME007','Indentity Confusion Device','image.gif',6.99,'Never leave on an undercover mission without our Identity Confusion Device! If a threatening person approaches, deploy the device and point toward the oncoming individual. The subject will fail to recognize you and let you pass unnoticed. Also works well on dogs.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (379,17,'SHADE01','Ultra Violet Attack Defender','image.gif',89.99,'Be safe and suave. A spy wearing this trendy article of clothing is safe from ultraviolet ray-gun attacks. Worn correctly, the Defender deflects rays from ultraviolet weapons back to the instigator. As a bonus, also offers protection against harmful solar ultraviolet rays, equivalent to SPF 50.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (378,17,'SQUKY1','Guard Dog Pacifier','image.gif',14.99,'Pesky guard dogs become a spy\'s best friend with the Guard Dog Pacifier. Even the most ferocious dogs suddenly act like cuddly kittens when they see this prop.  Simply hold the device in front of any threatening dogs, shaking it mildly.  For tougher canines, a quick squeeze emits an irresistible squeak that never fails to  place the dog under your control.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (382,20,'CHEW99','Survival Bar','image.gif',6.99,'Survive for up to four days in confinement with this handy item. Disguised as a common eraser, it\'s really a high-calorie food bar. Stranded in hostile territory without hope of nourishment? Simply break off a small piece of the eraser and chew vigorously for at least twenty minutes. Developed by the same folks who created freeze-dried ice cream, powdered drink mix, and glow-in-the-dark shoelaces.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (402,20,'C00LCMB1','Telescoping Comb','image.gif',399.99,'Use the Telescoping Comb to track down anyone, anywhere! Deceptively simple, this is no normal comb. Flip the hidden switch and two telescoping lenses project forward creating a surprisingly powerful set of binoculars (50X). Night-vision add-on is available for midnight hour operations.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (384,19,'FF007','Eavesdrop Detector','image.gif',99.99,'Worried that counteragents have placed listening devices in your home or office? No problem! Use our bug-sweeping wiener to check your surroundings for unwanted surveillance devices. Just wave the frankfurter around the room ... when bugs are detected, this \'foot-long\' beeps! Comes complete with bun, relish, mustard, and headphones for privacy.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (385,16,'LNGWADN','Escape Cord','image.gif',13.99,'Any agent assigned to mountain terrain should carry this ordinary-looking extension cord ... except that it\'s really a rappelling rope! Pull quickly on each end to convert the electrical cord into a rope capable of safely supporting up to two agents. Comes in various sizes including Mt McKinley, Everest, and Kilimanjaro. WARNING: To prevent serious injury, be sure to disconnect from wall socket before use.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (386,17,'1MOR4ME','Cocktail Party Pal','image.gif',69.99,'Do your assignments have you flitting from one high society party to the next? Worried about keeping your wits about you as you mingle witih the champagne-and-caviar crowd? No matter how many drinks you\'re offered, you can safely operate even the most complicated heavy machinery as long as you use our model 1MOR4ME alcohol-neutralizing coaster. Simply place the beverage glass on the patented circle to eliminate any trace of alcohol in the drink.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (387,20,'SQRTME1','Remote Foliage Feeder','image.gif',9.99,'Even spies need to care for their office plants.  With this handy remote watering device, you can water your flowers as a spy should, from the comfort of your chair.  Water your plants from up to 50 feet away.  Comes with an optional aiming system that can be mounted to the top for improved accuracy.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (388,20,'ICUCLRLY00','Contact Lenses','image.GIF',59.99,'Traditional binoculars and night goggles can be bulky, especially for assignments in confined areas. The problem is solved with these patent-pending contact lenses, which give excellent visibility up to 100 miles. New feature: now with a night vision feature that permits you to see in complete darkness! Contacts now come in a variety of fashionable colors for coordinating with your favorite ensembles.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (389,20,'OPNURMIND','Telekinesis Spoon','image.gif',2.99,'Learn to move things with your mind! Broaden your mental powers using this training device to hone telekinesis skills. Simply look at the device, concentrate, and repeat \'There is no spoon\' over and over.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (390,19,'ULOST007','Rubber Stamp Beacon','image.gif',129.99,'With the Rubber Stamp Beacon, you\'ll never get lost on your missions again. As you proceed through complicated terrain, stamp a stationary object with this device. Once an object has been stamped, the stamp\'s patented ink will emit a signal that can be detected up to 153.2 miles away by the receiver embedded in the device\'s case. WARNING: Do not expose ink to water.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (391,17,'BSUR2DUC','Bullet Proof Facial Tissue','image.gif',79.99,'Being a spy can be dangerous work. Our patented Bulletproof Facial Tissue gives a spy confidence that any bullets in the vicinity risk-free. Unlike traditional bulletproof devices, these lightweight tissues have amazingly high tensile strength. To protect the upper body, simply place a tissue in your shirt pocket. To protect the lower body, place a tissue in your pants pocket. If you do not have any pockets, be sure to check out our Bulletproof Tape. 100 tissues per box. WARNING: Bullet must not be moving for device to successfully stop penetration.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (393,20,'NOBOOBOO4U','Speed Bandages','image.GIF',3.99,'Even spies make mistakes.  Barbed wire and guard dogs pose a threat of injury for the active spy.  Use our special bandages on cuts and bruises to rapidly heal the injury.  Depending on the severity of the wound, the bandages can take between 10 to 30 minutes to completely heal the injury.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (394,15,'BHONST93','Correction Fluid','image.gif',1.99,'Disguised as typewriter correction fluid, this scientific truth serum forces subjects to correct anything not perfectly true. Simply place a drop of the special correction fluid on the tip of the subject\'s nose. Within seconds, the suspect will automatically correct every lie. Effects from Correction Fluid last approximately 30 minutes per drop. WARNING: Discontinue use if skin appears irritated.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (396,19,'BPRECISE00','Dilemma Resolution Device','image.gif',11.99,'Facing a brick wall? Stopped short at a long, sheer cliff wall?  Carry our handy lightweight calculator for just these emergencies. Quickly enter in your dilemma and the calculator spews out the best solutions to the problem.   Manufacturer Warning: Use at own risk. Suggestions may lead to adverse outcomes.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (397,14,'LSRPTR1','Nonexplosive Cigar','image.gif',29.99,'Contrary to popular spy lore, not all cigars owned by spies explode! Best used during mission briefings, our Nonexplosive Cigar is really a cleverly-disguised, top-of-the-line, precision laser pointer. Make your next presentation a hit.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (399,20,'QLT2112','Document Transportation System','image.gif',299.99,'Keep your stolen Top Secret documents in a place they\'ll never think to look!  This patent leather briefcase has multiple pockets to keep documents organized.  Top quality craftsmanship to last a lifetime.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (400,15,'THNKDKE1','Hologram Cufflinks','image.gif',799.99,'Just point, and a turn of the wrist will project a hologram of you up to 100 yards away. Sneaking past guards will be child\'s play when you\'ve sent them on a wild goose chase. Note: Hologram adds ten pounds to your appearance.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (401,14,'TCKLR1','Fake Moustache Translator','image.gif',599.99,'Fake Moustache Translator attaches between nose and mouth to double as a language translator and identity concealer. Sophisticated electronics translate your voice into the desired language. Wriggle your nose to toggle between Spanish, English, French, and Arabic. Excellent on diplomatic missions.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (404,14,'JWLTRANS6','Interpreter Earrings','image.gif',459.99,'The simple elegance of our stylish monosex earrings accents any wardrobe, but their clean lines mask the sophisticated technology within. Twist the lower half to engage a translator function that intercepts spoken words in any language and converts them to the wearer''s native tongue. Warning: do not use in conjunction with our Fake Moustache Translator product, as the resulting feedback loop makes any language sound like Pig Latin.');
INSERT INTO Products (ProductID,CategoryID,ModelNumber,ModelName,ProductImage,UnitCost,Description) VALUES (406,19,'GRTWTCH9','Multi-Purpose Watch','image.gif',399.99,'In the tradition of famous spy movies, the Multi Purpose Watch comes with every convenience! Installed with lighter, TV, camera, schedule-organizing software, MP3 player, water purifier, spotlight, and tire pump. Special feature: Displays current date and time. Kitchen sink add-on will be available in the fall of 2001.');

INSERT INTO Reviews (ReviewID,ProductID,CustomerName,CustomerEmail,Rating,Comments) VALUES (21,404,'Sarah Goodpenny','sg@ibuyspy.com',5,'Really smashing! &nbsp;Don\'t know how I\'d get by without them!');
INSERT INTO Reviews (ReviewID,ProductID,CustomerName,CustomerEmail,Rating,Comments) VALUES (22,378,'James Bondwell','jb@ibuyspy.com',3,'Well made, but only moderately effective. &nbsp;Ouch!');
