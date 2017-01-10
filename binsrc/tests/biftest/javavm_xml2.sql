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

create type java_lang_Class language java external name 'java.lang.Class'

	static method forName (cls varchar)
	   returns java_lang_Class external type 'Ljava/lang/Class;' external name 'forName',

        method getFields () returns any external type '[Ljava/lang/reflect/Field;' external name 'getFields',

	method getDeclaredFields () returns any external type '[Ljava/lang/reflect/Field;' external name 'getDeclaredFields',

        method getName () returns varchar external name 'getName',

	method isPrimitive () returns smallint external type 'Z' external name 'isPrimitive',

	method isArray () returns smallint external type 'Z' external name 'isArray',

        method getConstructors () returns any external type '[Ljava/lang/reflect/Constructor;' external name 'getConstructors',

	method getDeclaredConstructors () returns any external type '[Ljava/lang/reflect/Constructor;' external name 'getDeclaredConstructors',

	method getMethods () returns any external type '[Ljava/lang/reflect/Method;' external name 'getMethods',

	method getDeclaredMethods () returns any external type '[Ljava/lang/reflect/Method;' external name 'getDeclaredMethods'

;

create type java_lang_reflect_Method language java external name 'java.lang.reflect.Method'

	method getName () returns varchar external name 'getName',

	method getModifiers () returns integer external type 'I' external name 'getModifiers',

        method getReturnType () returns java_lang_Class external type 'Ljava/lang/Class;' external name 'getReturnType',

        method getParameterTypes () returns any external type '[Ljava/lang/Class;' external name 'getParameterTypes'

;


create type java_lang_reflect_Modifier language java external name 'java.lang.reflect.Modifier'

	static method getSTATIC () returns integer external variable name 'STATIC' external type 'I',

	static method getFINAL () returns integer external variable name 'FINAL' external type 'I'

;


create type java_lang_reflect_Field language java external name 'java.lang.reflect.Field'

	method getName () returns varchar external name 'getName',

	method getType () returns java_lang_Class external type 'Ljava/lang/Class;' external name 'getType',

	method getModifiers () returns integer external type 'I' external name 'getModifiers'
;


create type java_lang_reflect_Constructor language java external name 'java.lang.reflect.Constructor'

	method getName () returns varchar external name 'getName',

        method getParameterTypes () returns any external type '[Ljava/lang/Class;' external name 'getParameterTypes'

;
