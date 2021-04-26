require "./cword"

class CV::Cline
  SEP = 'ǀ'

  getter data : Array(Cword)

  def initialize(@data)
  end

  def fix_grammar!
    res = [] of Cword
    i = 0

    while i < @data.size
      curr = @data.unsafe_fetch(i)
      i += 1

      case curr.key
      when "的"
        curr.fix(val: "", cat: 0)
      when "了"
        curr.fix(val: "rồi", cat: 0)

        if (prev = @data[i - 2]?) && (prev.verb? || prev.cat == 0)
          next unless succ = @data[i]?
          curr.fix("") if succ.word? && succ.key != prev.key
        end
      when "对"
        if @data[i]?.try { |x| x.cat > 0 || x.key[0] == '“' }
          curr.fix("đối với")
        else
          curr.fix("đúng")
        end
      when "不对"
        if @data[i]?.try { |x| x.cat > 0 || x.key[0] == '“' }
          curr.fix("không đối với")
        else
          curr.fix("không đúng")
        end
      when "也"
        curr.fix(@data[i]?.try(&.word?) ? "cũng" : "vậy")
      when "地"
        # TODO: check noun, verb?
        curr.fix(@data[i - 2]?.try(&.word?) ? "mà" : "địa")
      when "原来"
        if @data[i]?.try(&.match_key?("的")) || @data[i - 2]?.try(&.word?)
          val = "ban đầu"
        else
          val = "thì ra"
        end
        curr.fix(val)
      when "行"
        curr.fix("được") unless @data[i]?.try(&.word?)
      when "高达"
        curr.fix("cao đến") if @data[i]?.try(&.is_num)
      when "石"
        curr.fix("thạch") if @data[i - 2]?.try(&.is_num)
      when "两"
        curr.fix("lượng") if @data[i - 2]?.try(&.is_num)
      when "里"
        curr.fix("dặm") if @data[i - 2]?.try(&.is_num)
      when "米"
        curr.fix("mét") if @data[i - 2]?.try(&.is_num)
      when "年"
        # TODO: handle special cases for year
        next unless prev = @data[i - 2]?
        next unless prev.to_i?.try(&.>= 100)

        curr.key = "#{prev.key}#{curr.key}"
        curr.fix("năm #{prev.key}")

        prev.clear!
      when "月"
        next unless prev = @data[i - 2]?
        next unless prev.to_i?.try(&.<= 15)

        curr.key = "#{prev.key}#{curr.key}"
        curr.fix("tháng #{prev.key}")

        prev.clear!
      when "日"
        next unless prev = @data[i - 2]?
        next unless prev.to_i?.try(&.<= 40)

        curr.key = "#{prev.key}#{curr.key}"
        curr.fix("ngày #{prev.key}")

        prev.clear!
      end
    end

    handle_adjes!
    handle_nouns!
    combine_的!

    self
  rescue err
    self
  end

  private def handle_adjes!
    res = [] of Cword
    idx = 0
    prev = nil

    @data.each do |curr|
      if prev && curr.adje?
        skip, left, right = false, "", ""

        case prev.key
        when "不", "很", "太", "多", "未", "更", "级", "超"
          skip, left = true, "#{prev.val} "
        when "最", "那么", "这么", "非常", "不太",
             "很大", "如此", "极为"
          skip, right = true, " #{prev.val}"
        else
          skip, left = true, "#{prev.val} " if prev.cat == 4
        end

        if skip
          prev.key = "#{prev.key}#{curr.key}"
          prev.val = "#{left}#{curr.val}#{right}"

          prev.cat |= 4
          prev.dic = curr.dic if prev.dic < curr.dic

          next
        end
      end

      prev = curr
      res << curr
    end

    @data = res
  end

  private def handle_nouns!
    res = [] of Cword
    prev = nil

    @data.each_with_index do |curr, idx|
      if prev && curr.cat == 1
        skip, left, right = false, "", ""

        case prev.key
        when "这", "这位", "这具", "这个", "这种",
             "这些", "这样", "这段", "这份", "这帮",
             "这条"
          skip, left, right = true, suffix(prev.key[1]?), " này"
        when "那位", "那具", "那个", "那种",
             "那些", "那样", "那段", "那份", "那帮",
             "那条"
          skip, left, right = true, suffix(prev.key[1]?), " kia"
        when "那"
          # skipping if 那 is in front
          if @data[idx - 2]?.try(&.key.ends_with?("“")) &&
             @data[idx + 1]?.try(&.word?)
            prev.fix(val: "vậy")
          else
            skip, left, right = true, suffix(prev.key[1]?), " kia"
          end
        when "什么"
          skip, left, right = true, "cái ", " gì"
        when "没什么"
          skip, left, right = true, "không có ", " gì"
        when "这样的"
          skip, right = true, " như vậy"
        when "哪个"
          skip, left, right = true, "cái ", " nào"
        when "其他", "其她", "其它"
          skip, left, right = true, "cái ", " khác"
        when "别的"
          skip, right = true, " khác"
        when "某个"
          skip, right = true, " nào đó"
        when "一串", "一个", "一只", "几个"
          skip, left = true, "#{prev.val} "
        when "另一个"
          skip, left, right = true, "một cái ", " khác"
        end

        case prev.cat
        when 5 # noun and adje
          skip, left = true, "#{prev.val} "
          # when 4 # only adje
          #   skip, right = true, " #{prev.val}"
        when 1 # only nown
          case curr.key
          when "姐", "姐姐", "大姐", "小姐", "大小姐",
               "哥", "哥哥", "大哥", "先生", "小姐姐",
               "小队", "老师", "身上", "大人"
            skip, left = true, "#{prev.val} "
          else
            if prev.pronoun?
              skip, left = true, "#{prev.val} "
            end
          end
        end

        if skip
          prev.key = "#{prev.key}#{curr.key}"
          prev.val = "#{left}#{curr.val}#{right}"

          prev.cat = 1
          prev.dic = curr.dic if prev.dic < curr.dic

          next
        end
      end

      prev = curr
      res << curr
    end

    @data = res
  end

  private def suffix(char : Char?)
    case char
    when '位' then "vị "
    when '具' then "cụ "
    when '个' then "cái "
    when '种' then "loại "
    when '些' then "những "
    when '样' then "dạng "
    when '段' then "đoạn "
    when '份' then "phần "
    when '帮' then "đám "
    when '条' then "điều "
    else          ""
    end
  end

  private def combine_的!
    res = [] of Cword
    idx = 0

    while idx < @data.size
      curr = @data.unsafe_fetch(idx)

      if curr.key == "的" && (left = res.last?)
        if right = @data[idx + 1]?
          if right.noun? && !res[-2]?.try(&.verb?)
            skip = false
            if left.adje?
              left.val = "#{right.val} #{left.val}"
              skip = true
            elsif left.cat == 1
              left.val = "#{right.val} của #{left.val}"
              skip = true
            end

            if skip
              left.key = "#{left.key}的#{right.key}"
              left.dic = 9
              left.cat |= 1

              idx += 2
              next
            end
          end
        elsif left.pronoun? && !res[-2]?.try(&.verb?)
          left.key = "#{left.key}的"
          left.val = "của #{left.val}"
          left.cat |= 1
          left.dic = 9
          idx += 1
          next
        end
      end

      res << curr
      idx += 1
    end

    @data = res
  end

  def capitalize! : self
    cap_mode = 1

    @data.each do |entry|
      next if entry.val.empty?

      if cap_mode > 0 && entry.dic > 0
        entry.capitalize!(cap_mode) if entry.dic > 1
        cap_mode = 0 unless cap_mode > 1
      else
        cap_mode = entry.cap_mode(cap_mode)
      end
    end

    self
  end

  def pad_spaces! : self
    return self if @data.empty?

    prev = @data.first
    temp = [prev]

    1.upto(@data.size - 1).each do |i|
      curr = @data.unsafe_fetch(i)

      unless curr.val.empty?
        temp << Cword.new("", " ") if curr.space_before?(prev)
        prev = curr
      end

      temp << curr
    end

    @data = temp
    self
  end

  def to_s : String
    String.build { |io| to_s(io) }
  end

  def to_s(io : IO) : Nil
    @data.each { |x| io << x.val }
  end

  def to_str : String
    String.build { |io| to_str(io) }
  end

  def to_str(io : IO) : Nil
    @data.map { |x| {x.key, x.val, x.dic}.join(SEP) }.join(io, '\t')
  end

  def inspect(io : IO) : Nil
    @data.map do |x|
      x.key.empty? ? x.val : "[#{x.key}¦#{x.val}¦#{x.dic}]"
    end.join(io, " ")
  end
end
