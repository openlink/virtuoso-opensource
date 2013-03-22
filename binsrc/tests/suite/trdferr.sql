


create table rdftst (a any);

insert into rdftst values (rdf_box (0, 257, 257, 12345678901, 0));

insert into rdftst values (#i1234567891);

select __ro2sq (a) from rdftst;

