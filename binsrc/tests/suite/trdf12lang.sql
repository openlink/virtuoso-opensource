-- RDF 1.2 language-tag compatibility tests.

create procedure RDF12LANG_ASSERT (in test_name varchar, in expected any, in actual any)
{
  if (expected <> actual)
    signal ('RDF12LANG', sprintf ('%s: expected %s, got %s', test_name, expected, actual));
}
;

create procedure RDF12LANG_EXPECT_ERROR (in text varchar, in flags integer := 0) returns integer
{
  declare exit handler for sqlstate '*'
    {
      return 1;
    };
  DB.DBA.TTLP_VALIDATE (text, 'http://example.org', 'urn:virtuoso:test:rdf12lang:validation', flags);
  return 0;
}
;

RDF12LANG_ASSERT ('BCP 47 extended tag', 1, rdf_langtag_is_valid ('zh-Hant-TW'));
RDF12LANG_ASSERT ('BCP 47 variant tag', 1, rdf_langtag_is_valid ('de-1996'));
RDF12LANG_ASSERT ('BCP 47 private-use tag', 1, rdf_langtag_is_valid ('x-private'));
RDF12LANG_ASSERT ('BCP 47 invalid variant', 0, rdf_langtag_is_valid ('en-1'));

RDF12LANG_ASSERT ('STRLANG extended tag', 1,
  case when DB.DBA.rdf_strlang_impl ('HHGG', 'zh-Hant-TW') is null then 0 else 1 end);
RDF12LANG_ASSERT ('STRLANG variant serialization', 'de-1996',
  DB.DBA.RDF_LANGUAGE_OF_LONG (DB.DBA.rdf_strlang_impl ('HHGG', 'de-1996')));
RDF12LANG_ASSERT ('STRLANG private-use serialization', 'x-private',
  DB.DBA.RDF_LANGUAGE_OF_LONG (DB.DBA.rdf_strlang_impl ('HHGG', 'x-private')));
RDF12LANG_ASSERT ('STRLANG rejects invalid variant', 1,
  case when DB.DBA.rdf_strlang_impl ('HHGG', 'en-1') is null then 1 else 0 end);

RDF12LANG_ASSERT ('STRLANGDIR extended tag', 'zh-hant-tw--ltr',
  DB.DBA.RDF_LANGUAGE_OF_LONG (DB.DBA.rdf_strlangdir_impl ('HHGG', 'zh-Hant-TW', 'ltr')));
RDF12LANG_ASSERT ('STRLANGDIR rejects invalid direction', 1,
  case when DB.DBA.rdf_strlangdir_impl ('HHGG', 'en', 'auto') is null then 1 else 0 end);
RDF12LANG_ASSERT ('STRLANGDIR rejects upper-case direction', 1,
  case when DB.DBA.rdf_strlangdir_impl ('HHGG', 'en', 'LTR') is null then 1 else 0 end);
RDF12LANG_ASSERT ('STRDIR rejects invalid direction', 1,
  case when DB.DBA.rdf_strdir_impl ('HHGG', 'auto') is null then 1 else 0 end);

RDF12LANG_ASSERT ('TTLP accepts legacy tag in compatibility mode', 0,
  RDF12LANG_EXPECT_ERROR ('<#subj> <#prop> "HHGG"@abcddefghg .'));
sparql clear graph <urn:virtuoso:test:rdf12lang:compat>;
DB.DBA.TTLP ('<#subj> <#prop> "HHGG"@abcddefghg .',
  'http://example.org', 'urn:virtuoso:test:rdf12lang:compat');
commit work;
RDF12LANG_ASSERT ('legacy tag is preserved in RDF box', 1,
  (select count (*) from DB.DBA.RDF_QUAD
    where G = iri_to_id ('urn:virtuoso:test:rdf12lang:compat')
      and rdf_box_data (O) = 'HHGG'
      and DB.DBA.RDF_LANGUAGE_OF_LONG (O) = 'abcddefghg'));
RDF12LANG_ASSERT ('legacy tag matches case-insensitively', 1,
  (sparql select count (*) from <urn:virtuoso:test:rdf12lang:compat>
    { ?s ?p ?o filter (langMatches (lang (?o), "ABCDDEFGHG")) }));

RDF12LANG_ASSERT ('TTLP_VALIDATE rejects legacy tag', 1,
  RDF12LANG_EXPECT_ERROR ('<#subj> <#prop> "HHGG"@abcddefghg .'));
RDF12LANG_ASSERT ('strict loader rejects invalid variant', 1,
  RDF12LANG_EXPECT_ERROR ('<#subj> <#prop> "HHGG"@en-1 .'));
RDF12LANG_ASSERT ('strict loader accepts extended tag', 0,
  RDF12LANG_EXPECT_ERROR ('<#subj> <#prop> "HHGG"@zh-Hant-TW .'));

commit work;
