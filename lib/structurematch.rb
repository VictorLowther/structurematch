class StructureMatch

  def initialize(matcher)
    raise "#{matcher.inspect} must be a Hash" unless matcher.kind_of?(Hash)
    @matchers = Hash.new
    matcher.each do |k,v|
      raise "#{k} must be a String" unless k.kind_of?(String)
      key = k.dup.freeze
      case
      when v.kind_of?(TrueClass) ||
          v.kind_of?(FalseClass) ||
          v.kind_of?(NilClass)   ||
          v.kind_of?(Numeric)
        val = v
      when v.kind_of?(String) || v.kind_of?(Array) then val = v.dup.freeze
      when v.kind_of?(Hash)
        case v["__sm_leaf"]
        when nil then val = StructureMatch.new(v)
        when "regex" then val = Regexp.compile(v["regex"])
        when "range" then val = Range.new(v["first"],v["last"])
        else
          raise "Cannot handle StructureMatch leafnode #{v.inspect}"
        end
      else
        raise "Cannot handle node type #{v.inspect}"
      end
      @matchers[key] = val
    end
  end

  def score(val)
    res = 0
    raise "Must pass a Hash to score" unless val.kind_of?(Hash)
    @matchers.each do |k,v|
      unless val.has_key?(k)
        res -= 1
        next
      end
      case
      when v.class == val[k].class
        if v.kind_of?(Array)
          res += (v & val[k]).length
        else
          res += 1 if v == val[k]
        end
      when v.kind_of?(Array)
        res += 1 if v.member?(val[k])
      when v.kind_of?(Numeric) && val[k].kind_of?(Numeric)
        res += 1 if v == val[k]
      when v.kind_of?(StructureMatch) && val[k].kind_of?(Hash)
        res += v.score(val[k])
      when v.kind_of(Regexp)
        res += (v.match(val[k].to_s) || []).length
      when v.kind_of(Range)
        res += 1 if v === val[k]
      end
    end
    res
  end

end
