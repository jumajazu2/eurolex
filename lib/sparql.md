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


//sample return

{ "celex": { "type": "literal", "datatype": "http://www.w3.org/2001/XMLSchema#string", "value": "61991CC0017" }	, "work": { "type": "uri", "value": "http://publications.europa.eu/resource/cellar/cdaa796b-7ff8-49bf-a580-25dfaad6da44" }	, "expr": { "type": "uri", "value": "http://publications.europa.eu/resource/cellar/cdaa796b-7ff8-49bf-a580-25dfaad6da44.0002" }	, "manif": { "type": "uri", "value": "http://publications.europa.eu/resource/cellar/cdaa796b-7ff8-49bf-a580-25dfaad6da44.0002.04" }	, "langCode": { "type": "literal", "value": "ENG" }	, "format": { "type": "literal", "value": "xhtml" }	, "item": { "type": "uri", "value": "http://publications.europa.eu/resource/cellar/cdaa796b-7ff8-49bf-a580-25dfaad6da44.0002.04/DOC_1" }} 


{head: {link: [], vars: [celex, work, expr, manif, langCode, format, item]}, results: {distinct: false, ordered: true, bindings: [{celex: {type: literal, datatype: http://www.w3.org/2001/XMLSchema#string, value: 61991CC0002}, work: {type: uri, value: http://publications.europa.eu/resource/cellar/3fffb793-f43b-4d11-9b2b-e97c2221687e}, expr: {type: uri, value: http://publications.europa.eu/resource/cellar/3fffb793-f43b-4d11-9b2b-e97c2221687e.0006}, manif: {type: uri, value: http://publications.europa.eu/resource/cellar/3fffb793-f43b-4d11-9b2b-e97c2221687e.0006.01}, langCode: {type: literal, value: NLD}, format: {type: literal, value: xhtml}, item: {type: uri, value: http://publications.europa.eu/resource/cellar/3fffb793-f43b-4d11-9b2b-e97c2221687e.0006.01/DOC_1}},








//convert celex to cellar

prefix cdm: <http://publications.europa.eu/ontology/cdm#> 
SELECT ?celex, ?expr, ?manif, ?item  WHERE { ?work cdm:resource_legal_id_celex ?celex . FILTER(str(?celex) = "52020SC0543") 


?expr cdm:expression_belongs_to_work ?work ;
cdm:expression_uses_language ?lang .

?manif cdm:manifestation_manifests_expression ?expr;
cdm:manifestation_type ?format.
?item cdm:item_belongs_to_manifestation ?manif.
}
LIMIT 10



prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
select distinct ?celex, ?work, ?expr, ?manif, ?langCode, str(?format) as ?format, ?item
where {
 ?work cdm:resource_legal_id_celex ?celex . FILTER(str(?celex) = "52020SC0543" || str(?celex) = "12012P/TXT") 
?expr cdm:expression_belongs_to_work ?work ;
cdm:expression_uses_language ?lang .
?lang purl:identifier ?langCode .
?manif cdm:manifestation_manifests_expression ?expr;
cdm:manifestation_type ?format.
?item cdm:item_belongs_to_manifestation ?manif.

FILTER(str(?langCode)="ENG")
} LIMIT 10000



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

FILTER(str(?format)="html")
} 
ORDER BY ASC(?celex)
LIMIT 10000



