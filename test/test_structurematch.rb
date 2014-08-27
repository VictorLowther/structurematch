# Copyright 2014, Victor Lowther <victor.lowther@gmail.com>
# Licensed under the terms of the Apache 2 license.

require 'minitest/autorun'
require 'structurematch'

class TestStructureMatch < Minitest::Test

  def setup
    match_tmpl = {
      # Simple equality tests require no magic
      "string" => "foo",
      "number" => 5,
      # Ditto for nested matches
      "simplenest" => {
        "string" => "bar",
        "number" => 23
      },
      # Matches for anything but simple equality require
      # a hash with "__sm_leaf", "op", and "match" keys.
      #
      # We also know how to match on regular expressions.
      "regexmatch" => {
        # Let simplematch know this is a leaf.
        "__sm_leaf" => true,
        "op" => "regex",
        # Note the lack of // in the match data.
        "match" => "foo(bar)"
      },
      # We do ranges, too
      "rangematch" => {
        "__sm_leaf" => true,
        "op" => "range",
        # With a range, match must be a two-element array
        "match" => [0,9]
      },
      # We also know how to do and, or, and not.
      "logics" => {
        "andmatch" => {
          "__sm_leaf" => true,
          "op" => "and",
          # For and, match must be an array of matches.
          "match" => [
                      {
                        "op" => "<=",
                        "match" => 7
                      },
                      {
                        "op" => ">=",
                        "match" => 5
                      }
                     ]
        },
        "ormatch" => {
          "__sm_leaf" => true,
          "op" => "or",
          # An or match also must be an array of matches.
          "match" => [
                      {
                        "op" => ">=",
                        "match" => 7
                      },
                      {
                        "op" => "<=",
                        "match" => 5
                      }
                     ]
        },
        "notmatch" => {
          "__sm_leaf" => true,
          "op" => "not",
          # A not match takes a single submatch.
          "match" => {
            "op" => "==",
            "match" => 1
          }
        }
      },
      # We can also see if a key is a member of a specific set.
      "member" => [3,4,5]
    }
    @matcher = StructureMatch.new(match_tmpl)
    @perfect = {
      "string" => "foo",
      "number" => 5,
      "simplenest" => {
        "string" => "bar",
        "number" => 23
      },
      "regexmatch" => "foobar",
      "rangematch" => 5,
      "logics" => {
        "andmatch" => 6,
        "ormatch" => 9,
        "notmatch" => 6
      },
      "member" => 4
    }
    @negative ={
      "string" => "bar",
      "number" => 23,
      "simplenest" => {
        "string" => "foo",
        "number" => 5
      },
      "regexmatch" => "foba",
      "rangematch" => 11,
      "logics" => {
        "andmatch" => 9,
        "ormatch" => 6,
        "notmatch" => 1
      },
      "member" => 7
    }
  end

  def test_perfect_bind
    res,score = @matcher.bind(@perfect)
    assert_equal("foo", res["string"])
    assert_equal(5,res["number"])
    assert_equal("bar",res["simplenest"]["string"])
    assert_equal(23,res["simplenest"]["number"])
    assert_equal(2,res["regexmatch"].length)
    assert_equal("foobar",res["regexmatch"][0])
    assert_equal(5,res["rangematch"])
    assert_equal(6,res["logics"]["andmatch"])
    assert_equal(9,res["logics"]["ormatch"])
    assert_equal(6,res["logics"]["notmatch"])
    assert_equal(4,res["member"])
        assert_equal(11,score)
  end

  def test_perfect_flatbind
    res,score = @matcher.flatbind(@perfect,'.')
    assert_equal("foo", res["string"])
    assert_equal(5,res["number"])
    assert_equal("bar",res["simplenest.string"])
    assert_equal(23,res["simplenest.number"])
    assert_equal(2,res["regexmatch"].length)
    assert_equal("foobar",res["regexmatch"][0])
    assert_equal(5,res["rangematch"])
    assert_equal(6,res["logics.andmatch"])
    assert_equal(9,res["logics.ormatch"])
    assert_equal(6,res["logics.notmatch"])
    assert_equal(4,res["member"])
    assert_equal(11,score)
  end

  def test_negative_bind
    res,score = @matcher.bind(@negative)
    assert_empty(res)
    assert_equal(-10,score)
  end
end
