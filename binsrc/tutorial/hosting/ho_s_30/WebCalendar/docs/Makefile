# Makefile for updating documentation automatically


all: database.html


database.html: ../tables-mysql.sql sql2html.pl
	perl sql2html.pl < ../tables-mysql.sql > database.html


