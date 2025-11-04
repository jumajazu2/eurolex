prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
select distinct ?celex, ?work, ?expr, ?manif, ?langCode, str(?format) as ?format, ?item
where {
 ?work a cdm:resource_legal ;
        cdm:resource_legal_id_celex ?celex .
 FILTER(STRSTARTS(STR(?celex), "6"))
  FILTER(SUBSTR(STR(?celex), 2, 4) = "2001")
?expr cdm:expression_belongs_to_work ?work ;
cdm:expression_uses_language ?lang .
?lang purl:identifier ?langCode .
?manif cdm:manifestation_manifests_expression ?expr;
cdm:manifestation_type ?format.
?item cdm:item_belongs_to_manifestation ?manif.

FILTER(str(?langCode)="ENG")
} LIMIT 10000

