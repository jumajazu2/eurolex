to get specific sequence ID in specific Celex, to offset parMismatch
 {"query": {
    "bool": {
      "must": [
        { "term": { "celex": "32016R0679" } },
        { "term": { "sequence_id": 2
         } }
      ]
    }
  },
  "size": 10
}





WORKING, FAST
For celex, returns links and title for each lang

prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
select distinct ?celex ?langCode ?item ?title
where {
 VALUES ?celex { "52020DC0690"^^xsd:string }
?work cdm:resource_legal_id_celex ?celex .

  ?expr cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language ?lang ;
        cdm:expression_title ?title . 
  ?lang purl:identifier ?langCode .
  ?manif cdm:manifestation_manifests_expression ?expr ;
        cdm:manifestation_type ?format .
  ?item cdm:item_belongs_to_manifestation ?manif .
  FILTER(str(?format)="xhtml")
}
ORDER BY ?celex
























💡 Alternative method (REST API) WORKS, FAST

If SPARQL is too tricky, you can also use the Cellar REST API to get the metadata:

Use the Cellar dissemination API to fetch the CELEX notice:
http://publications.europa.eu/resource/celex/32020R0857

Publications Office of the EU
+1

Add ?language=en and ?notice=tree to get a full XML tree:

curl -H "Accept: application/xml;notice=tree" \
  "http://publications.europa.eu/resource/celex/32020R0857?language=en" \
  -L


This returns a hierarchical XML with metadata, including the Cellar work URI.



---------------------------------------------------------------------
Working, fast

PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>

SELECT DISTINCT ?work ?expr ?manif ?item
WHERE {
  # Match the CELEX resource using IRI
  ?work owl:sameAs <http://publications.europa.eu/resource/celex/32020R0857> .

  # Navigate down the WEMI hierarchy
  ?expr cdm:expression_belongs_to_work ?work .
  ?manif cdm:manifestation_manifests_expression ?expr .
  ?item cdm:item_belongs_to_manifestation ?manif .
}


-------------------------------------------------------

WORKING, to implement, return for specific Celex - Cellar links and lang codes 
//VERY SLOW//


prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
select distinct ?celex ?langCode ?item
where {
  ?work cdm:resource_legal_id_celex ?celex .
FILTER(str(?celex) = "52025DC0030")

  ?expr cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language ?lang .
  ?lang purl:identifier ?langCode .
  ?manif cdm:manifestation_manifests_expression ?expr ;
        cdm:manifestation_type ?format .
  ?item cdm:item_belongs_to_manifestation ?manif .
  FILTER(str(?format)="xhtml")
}
ORDER BY ?celex

***************************

 -WORKING 17-11-2025
returns filtered by ENG, but missing some (52025DC0030)

prefix cdm: <http://publications.europa.eu/ontology/cdm#>
prefix purl: <http://purl.org/dc/elements/1.1/>
select distinct ?celex ?langCode ?item
where {
  ?work a cdm:resource_legal ;
        cdm:resource_legal_id_celex ?celex .
  FILTER(STRSTARTS(STR(?celex), "5"))
  FILTER(SUBSTR(STR(?celex), 2, 4) = "2025")
 
  ?expr cdm:expression_belongs_to_work ?work ;
        cdm:expression_uses_language ?lang .
  ?lang purl:identifier ?langCode .
 FILTER(str(?langCode)="ENG")
  ?manif cdm:manifestation_manifests_expression ?expr ;
        cdm:manifestation_type ?format .
  ?item cdm:item_belongs_to_manifestation ?manif .
  FILTER(str(?format)="xhtml")

}

WORKING 17-11-2025
return cellars for individual celex

prefix cdm: <http://publications.europa.eu/ontology/cdm#> 
SELECT ?celex, ?expr, ?manif, ?item  WHERE { ?work cdm:resource_legal_id_celex ?celex . FILTER(str(?celex) = "52025DC0030") 


?expr cdm:expression_belongs_to_work ?work ;
cdm:expression_uses_language ?lang .

?manif cdm:manifestation_manifests_expression ?expr;
cdm:manifestation_type ?format.
?item cdm:item_belongs_to_manifestation ?manif.
}
LIMIT 1000









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



PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>

SELECT ?consolidatedWork ?title ?date
WHERE {
BIND("32022R2391" AS ?originalCELEX)  # change CELEX here

?originalWork a cdm:resource_legal ;
cdm:resource_legal_id_celex ?originalCELEX .
?consolidatedWork a cdm:resource_legal ;
cdm:consolidates ?originalWork .
OPTIONAL {
?exp  cdm:expression_belongs_to_work ?consolidatedWork ;
cdm:expression_uses_language <http://publications.europa.eu/resource/authority/language/ENG> ;
cdm:expression_title ?title .
}
OPTIONAL { ?consolidatedWork cdm:resource_legal_date_document ?date . }
}
ORDER BY DESC(?date)