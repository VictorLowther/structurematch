StructureMatch is a little Ruby library that sees how closely a given
nested hash (expected to be from parsing a blob of JSON) matches a
reference blob.

[![Build Status](https://travis-ci.org/VictorLowther/structurematch.svg)](https://travis-ci.org/VictorLowther/structurematch)

To use it:

Arrange for the 'structurematch' gem to be installed via whatever
method is appropriate for your environment.

In irb:

    irb(main):001:0> require 'structurematch'
    => true
    irb(main):002:0> require 'json'
    => true
    irb(main):003:0> json = JSON.parse('{"key": "val", "numeric_key": 12345, "key3": "foobarriffic", "a": "b"}')
    => {"key"=>"val", "numeric_key"=>12345, "key3"=>"foobarriffic", "a"=>"b"}
    irb(main):004:0> matcher = StructureMatch.new("key" => "val",
    irb(main):005:1*                              "numeric_key" => 12345,
    irb(main):006:1*                              "key3" => { "__sm_leaf" => true,
    irb(main):007:2*                                          "op" => "regex",
    irb(main):008:2*                                          "match" => "foo(bar)"})
    => #<StructureMatch:0x00000001435b10 @matchers={"key"=>#<StructureMatch::Comparator:0x00000001435340 @op="==", @match="val">, "numeric_key"=>#<StructureMatch::Comparator:0x000000014342d8 @op="==", @match=12345>, "key3"=>#<StructureMatch::Comparator:0x00000001433770 @op="regex", @match=/foo(bar)/>}>
    irb(main):0090> matches = matcher.bind(json)
    => [{"key"=>"val", "numeric_key"=>12345, "key3"=>#<MatchData "foobar" 1:"bar">}, 4]
    irb(main):010:0> matcher.score(json)
    => 4
    irb(main):011:0>


As you can see, bind returns a two-part array.  The first part is a
hash containing all the keys from json that matched the matcher, and
the second part is the score that the matcher assigned to the JSON
based on how closely it matched.  The higher the score, the closer the
match.
