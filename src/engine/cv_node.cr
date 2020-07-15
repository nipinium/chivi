class CvNode
  SEP_0 = "ǁ"
  SEP_1 = "¦"

  property key : String
  property val : String
  property dic : Int32
  property etc : String

  def initialize(@key : String, @val : String, @dic : Int32 = 0, @etc = "")
  end

  def initialize(key : Char, val : Char, @dic : Int32 = 0, @etc = "")
    @key = key.to_s
    @val = val.to_s
  end

  def initialize(char : Char, @dic : Int32 = 0, @etc = "")
    @key = @val = char.to_s
  end

  def to_s
    String.build { |io| to_s(io) }
  end

  def to_s(io : IO)
    io << @key << SEP_1 << @val << SEP_1 << @dic
  end

  # return true if
  def capitalize!
    @val = TextUtil.capitalize(@val)
  end

  LETTER_RE = /[\p{L}\p{N}]/

  def match_letter?
    LETTER_RE.matches?(@val)
  end

  def special_char?
    case @key[0]?
    when '_', '.', '%', '-', '/', '?', '=', ':'
      true
    else
      false
    end
  end

  def unchanged?
    @key == @val
  end

  def combine!(other : self)
    @key = other.key + @key
    @val = other.val + @val
  end

  def should_cap_after?
    case @val[-1]?
    when '“', '‘', '⟨', '[', '{', '.', ':', '!', '?', ' '
      return true
    else
      return false
    end
  end

  def should_space_before?
    # return true if @dic > 0

    case @val[0]?
    when '”', '’', '⟩', ')', ']', '}', ',', '.', ':', ';',
         '!', '?', '%', ' ', '_', '…', '/', '\\', '~', '·'
      false
    else
      true
    end
  end

  def should_space_after?
    # return true if @dic > 0

    case @val[-1]?
    # when '”', '’', '⟩', ')', ']', '}', ',', '.', ':', ';',
    #      '!', '?', '%', '…', '~', '—'
    #   true
    # else
    #   false
    when '“', '‘', '⟨', '(', '[', '{', ' ', '_', '/', '\\', '·'
      false
    else
      true
    end
  end
end
