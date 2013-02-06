class NarrowParser
rule

  narrow : siki

  siki : FIELD kankei value { result = val[0] + "\t" + val[1] + val[2] }
       | siki FIELD kankei value  { result = val[0] + "\n" + val[1] + "\t" + val[2] + val[3] }
       | siki kankei value {
           if result.rindex(/\n\S\t/) then
             result = val[0] + $& + val[1] + val[2]
           elsif /\S\t/ =~ result then
             result = val[0] + "\n" + $& + val[1] + val[2]
           end
          }

  value : VALUE { result = "\t" + val[0] }
        | value VALUE { result = val[0] + "\xfd" + val[1] }
        | pm
        | sw
        | ew

  pm : PM { result = "PM\t" + val[0] }
     | pm PM { result = val[0] + "\xfd" + val[1] }

  sw : SW { result = "SW\t" + val[0] }
     | sw SW { result = val[0] + "\xfd" + val[1] }

  ew : EW { result = "EW\t" + val[0] }
     | ew EW { result = val[0] + "\xfd" + val[1] }

  kankei : '=' | '!='  { result = '!' } | '>' | '<' | '>=' | '<=' 

end

---- header
# parse narrow line 2013/01/18 K. Tsubouchi
# config.yml
require 'yaml'

---- inner

  def parse (str, fields, fieldNOs)
    @q = []
    until str.empty?
      case str
      when /^\s+/ # supesu musi
      when /^([^\s]*?)((!|<|>)?=|<|>)/ # siki
        field = $1
        eq = $2
        if fields.include?(field) then
          @q.push [:FIELD, fieldNOs[fields.index(field)].to_s]
        elsif fieldNOs.include?(field) then
          @q.push [:FIELD, field]
        elsif field != "" then
          @q.push [:UNKNOWN, field]
        end
        @q.push [eq, eq]
      when /^(\*?)([^*\s]+)(\*?)/ # match
        eWith = "\*" == $1
        value = $2
        sWith = "\*" == $3
        if eWith then
          if sWith then
            @q.push [:PM, value]
          else
            @q.push [:EW, value]
          end
        elsif sWith then
          @q.push [:SW, value]
        else
          @q.push [:VALUE, value]
        end
      when /^\S+/ # atai
         s = $&
         @q.push ["ERROR!", s]
      else
      end
      str = $'
      break if str == nil
    end
    @q.push [false,"$end"]
    do_parse
  end

  def next_token
    @q.shift
  end

---- footer

