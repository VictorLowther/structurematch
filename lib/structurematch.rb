# = structurematch.rb - Library for deep binding values from JSON
# Copyright 2014, Victor Lowther <victor.lowther@gmail.com>
# Licensed under the terms of the Apache 2 license.
#

# StructureMatch encapsulates all the logic needed perform deep binding and
# scoring of a JSON data structure.
class StructureMatch

  # Comparator handles the actual comparison operations that StructureMatch uses.
  class Comparator
    # Comparators are initialized using a hash with the following structure:
    #
    #  {
    #    "op" => "operation"
    #    "match" => "The value that the operation should work with"
    #    # Optional, defaults to 1 or the length of the matched thing (if array-ish)
    #    "score" => 1 # The score adjustment a match here gives.
    #  }
    #
    # Comparator knows about the following tests:
    #
    # "==","!=",">","<",">=","<=":: The matching tests from Comparable.
    # "and":: Returns true if all the submatches return true, false otherwise.
    # "or":: Returns true if one of the submatches return true, false otherwise.
    #        "and" and "or" require that "match" be an array of hashes that Comparator.new can process.
    # "not":: Inverts its submatch.  Requires that "match" be a hash that Comparator.new can process.
    # "range":: Tests to see if a value is within a range of values.
    #           Requires that "match" be a two-element array whose elements can be used to construct a Range.
    # "regex":: Tests to see if a value matches a regular expression.  "match" must be a regex.
    #           The score on a matching regex will be the length of the MatchData by default, and the returned
    #           value will be matching MatchData.
    # "member":: Tests to see if a value is within an array.  "match" must be the array.
    #            If an array is passed to a member test, then scoring and the returned value will be the
    #            set intersection of the match array and the tested array.
    def initialize(op)
      raise "#{op.inspect} must be a Hash" unless op.kind_of?(Hash)
      unless ["==","!=",">","<",">=","<=","and","or","not","range","regex","member"].member?(op["op"])
        raise "Operator #{op["op"]} is not one that Comparator knows how to use!"
      end
      raise "#{op.inspect} must have a match key" unless op.has_key?("match")
      @op = op["op"].dup.freeze
      @match = op["match"]
      @score = op["score"].to_i
      @score = nil if @score == 0
      case @op
      when "and","or"
        raise "#{op.inspect} match key must be an array of submatches" unless @match.kind_of?(Array)
        @match.map!{|m|Comparator.new(m)}
      when "not"
        @match = Comparator.new(@match)
      when "range"
        raise "#{@match.inspect} is not a two-element array" unless @match.kind_of?(Array) && @match.length == 2
        @match = Range.new(@match[0],@match[1])
      when "regex" then @match = Regexp.compile(@match)
      end
    end

    # Takes a single argument which is the value to be tested.
    #
    # It returns a two-element array:
    #   [score,val]
    # score:: the score adjustment factor for this test
    # val:: the value that test returns.  It is usually the value that was passed in,
    #       except for regular expressions (which return the MatchData) and array & array
    #       comparisons performed by member (which returns the set intersection of the arrays)
    def test(v=true)
      case @op
      when "and" then [_t(@match.all?{|m|m.test(v)[0]}),v]
      when "or" then [_t(@match.any?{|m|m.test(v)[0]}),v]
      when "not" then [_t(!@match.test(v)[0]),v]
      when "range" then [_t(@match === v),v]
      when "regex"
        r = @match.match(v)
        [r.nil? ? -1 : @score || r.length, r]
      when "member"
        if v.kind_of?(Array)
          r = @match & v
          [r.empty? ? -1 : @score || r.length, r]
        else
          [_t(@match.member?(v)),v]
        end
      when "==" then [_t(@match == v),v]
      when "!=" then [_t(@match != v),v]
      when ">" then [_t(@match > v),v]
      when "<" then [_t(@match < v),v]
      when ">=" then [_t(@match >= v),v]
      when "<=" then [_t(@match <= v),v]
      else
        raise "Comparator cannot handle #{@op}"
      end
    end

    private
    def _t(v)
      v ? @score || 1 : -1
    end
  end

  # StructureMatchers are initialized by passing in an example nested hash that maps out what
  # StructureMatch should dig through, bind matching values, and how to score the matches it found.
  # As an example:
  #  StructureMatch.new("foo" => "bar",
  #                     "numbermatch" => 5,
  #                     "regexmatch" => {
  #                       "__sm_leaf" => true,
  #                       "op"=> "regex",
  #                       "match" => "foo(bar)"},
  #                     "ormatch" => {
  #                       "__sm_leaf" => true,
  #                       "op" => "or",
  #                       "match" => [
  #                         {
  #                           "op" => ">",
  #                           "match" => 7
  #                         },
  #                         {
  #                           "op" => "<",
  #                           "match" => 10}]})
  # will create a matcher that perfectly matches the following JSON:
  #  { "foo": "bar",
  #    "numbermatch": 5,
  #    "regexmatch": "foobar",
  #    "ormatch": 8
  #  }
  # This match will be assigned a score of 5.
  def initialize(matcher)
    raise "#{matcher.inspect} must be a Hash" unless matcher.kind_of?(Hash)
    @matchers = Hash.new
    matcher.each do |k,v|
      raise "#{k} must be a String" unless k.kind_of?(String)
      key = k.dup.freeze
      @matchers[key] = case
                       when v.kind_of?(TrueClass) ||
                           v.kind_of?(FalseClass) ||
                           v.kind_of?(NilClass)   ||
                           v.kind_of?(Numeric)
                         Comparator.new("op" => "==", "match" => v)
                       when v.kind_of?(String) then Comparator.new("op" => "==", "match" => v.dup.freeze)
                       when v.kind_of?(Array) then Comparator.new("op" => "member", "match" => v.dup.freeze)
                       when v.kind_of?(Hash) then !!v["__sm_leaf"] ? Comparator.new(v) : StructureMatch.new(v)
                       else
                         raise "Cannot handle node type #{v.inspect}"
                       end
    end
  end

  # Takes a (possibly nested) hash that is a result of parsing JSON and matches what it can,
  # assigning a score in the process.
  #
  # Returns a two-entry array in the form of [binds,score]:
  # binds:: The nested hash corresponding to the matched values from val.
  # score:: The score assigned to this match.
  def bind(val)
    raise "Must pass a Hash to StructureMatch.bind" unless val.kind_of?(Hash)
    score = 0
    binds = Hash.new
    @matchers.each do |k,v|
      offset = 0
      res = nil
      case
      when !val.has_key?(k) then offset = -1
      when v.kind_of?(Comparator)
        offset,res = v.test(val[k])
        binds[k] = res if offset > 0
      when v.kind_of?(StructureMatch)
        res,offset = v.bind(val[k])
        binds[k] = v
      else
        raise "StructureMatch.bind: No idea how to handle #{v.class.name}: #{v.inspect}"
      end
      score += offset
    end
    [binds,score]
  end

  # As bind, but transforms the nested hash into a flat hash with nested keys
  # joined by sep.
  def flatbind(val, sep='.')
    binds,score = bind(val)
    [_flatbind(binds,sep,Hash.new,""),score]
  end

  # Runs bind on val and returns just the score component.
  def score(val)
    bind(val)[1]
  end

  private

  def _flatbind(binds,sep,target,prefix)
    binds.each do |k,v|
      key = prefix.empty? ? k : "#{prefix}#{sep}#{k.to_s}"
      if v.kind_of?(Hash)
        _flatbind(v,sep,target,key)
      else
        target[key]=v
      end
    end
  end

end
