class TypedJSON
  def self.generate(obj, *args)
    hash_dup = each_with_parent(obj)
    JSON.generate(hash_dup, *args)
  end

  def self.map_to_json(obj)
    case obj
    when Time
      JSONTime.new(obj)
    when Date
      JSONDate.new(obj)
    when DateTime
      JSONDateTime.new(obj)
    when Symbol
      JSONSymbol.new(obj)
    else
      obj
    end
  end

  def self.each_with_parent(hash, result=nil)
    duplicated_hash = {} || result

    hash.each do |k, v|
      case v
      when Hash
        duplicated_hash[k] = each_with_parent(v, duplicated_hash)
      else
        duplicated_hash[k] = map_to_json(v)
      end
    end

    duplicated_hash
  end
end

class JSONSymbol < SimpleDelegator
  # Returns a hash, that will be turned into a JSON object and represent this
  # object.
  def as_json(*)
    {
      JSON.create_id => self.class.name,
      's'            => to_s,
    }
  end

  # Stores class name (Symbol) with String representation of Symbol as a JSON string.
  def to_json(*a)
    as_json.to_json(*a)
  end

  # Deserializes JSON string by converting the <tt>string</tt> value stored in the object to a Symbol
  def self.json_create(o)
    o['s'].to_sym
  end
end

class JSONTime < SimpleDelegator
  # Deserializes JSON string by converting time since epoch to Time
  def self.json_create(object)
    if usec = object.delete('u') # used to be tv_usec -> tv_nsec
      object['n'] = usec * 1000
    end
    if method_defined?(:tv_nsec)
      Time.at(object['s'], Time.Rational(object['n'], 1000))
    else
      Time.at(object['s'], object['n'] / 1000)
    end
  end

  # Returns a hash, that will be turned into a JSON object and represent this
  # object.
  def as_json(*)
    nanoseconds = [ tv_usec * 1000 ]
    respond_to?(:tv_nsec) and nanoseconds << tv_nsec
    nanoseconds = nanoseconds.max
    {
      JSON.create_id => self.class.name,
      's'            => tv_sec,
      'n'            => nanoseconds,
    }
  end

  # Stores class name (Time) with number of seconds since epoch and number of
  # microseconds for Time as JSON string
  def to_json(*args)
    as_json.to_json(*args)
  end
end

class JSONDate < SimpleDelegator
  # Deserializes JSON string by converting Julian year <tt>y</tt>, month
  # <tt>m</tt>, day <tt>d</tt> and Day of Calendar Reform <tt>sg</tt> to Date.
  def self.json_create(object)
    Date.civil(*object.values_at('y', 'm', 'd', 'sg'))
  end

  #alias start sg unless method_defined?(:start)

  # Returns a hash, that will be turned into a JSON object and represent this
  # object.
  def as_json(*)
    {
      JSON.create_id => self.class.name,
      'y' => year,
      'm' => month,
      'd' => day,
      'sg' => start,
    }
  end

  # Stores class name (Date) with Julian year <tt>y</tt>, month <tt>m</tt>, day
  # <tt>d</tt> and Day of Calendar Reform <tt>sg</tt> as JSON string
  def to_json(*args)
    as_json.to_json(*args)
  end
end

class JSONDateTime < SimpleDelegator
  # Deserializes JSON string by converting year <tt>y</tt>, month <tt>m</tt>,
  # day <tt>d</tt>, hour <tt>H</tt>, minute <tt>M</tt>, second <tt>S</tt>,
  # offset <tt>of</tt> and Day of Calendar Reform <tt>sg</tt> to DateTime.
  def self.json_create(object)
    args = object.values_at('y', 'm', 'd', 'H', 'M', 'S')
    of_a, of_b = object['of'].split('/')
    if of_b and of_b != '0'
      args << DateTime.Rational(of_a.to_i, of_b.to_i)
    else
      args << of_a
    end
    args << object['sg']
    DateTime.civil(*args)
  end

  #alias start sg unless method_defined?(:start)

  # Returns a hash, that will be turned into a JSON object and represent this
  # object.
  def as_json(*)
    {
      JSON.create_id => self.class.name,
      'y' => year,
      'm' => month,
      'd' => day,
      'H' => hour,
      'M' => min,
      'S' => sec,
      'of' => offset.to_s,
      'sg' => start,
    }
  end

  # Stores class name (DateTime) with Julian year <tt>y</tt>, month <tt>m</tt>,
  # day <tt>d</tt>, hour <tt>H</tt>, minute <tt>M</tt>, second <tt>S</tt>,
  # offset <tt>of</tt> and Day of Calendar Reform <tt>sg</tt> as JSON string
  def to_json(*args)
    as_json.to_json(*args)
  end
end
