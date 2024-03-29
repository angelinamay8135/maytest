#
# DO NOT MODIFY!!!!
# This file is automatically generated by Racc 1.4.9
# from Racc grammer file "".
#

require 'racc/parser.rb'

# parse narrow line 2013/01/18 K. Tsubouchi
# config.yml
require 'yaml'

class NarrowParser < Racc::Parser

module_eval(<<'...end narrow_parser.y/module_eval...', 'narrow_parser.y', 41)

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

...end narrow_parser.y/module_eval...
##### State transition tables begin ###

racc_action_table = [
    12,    14,    15,    16,    17,     7,     8,     9,    10,     4,
     5,     7,     8,     9,    10,     4,     5,     7,     8,     9,
    10,     4,     5,    14,    15,    16,    17,    14,    15,    16,
    17,     1,    22,    25,    26,    27,    28,    11,    25,    25 ]

racc_action_check = [
     3,    23,    23,    23,    23,     3,     3,     3,     3,     3,
     3,     1,     1,     1,     1,     1,     1,    12,    12,    12,
    12,    12,    12,     6,     6,     6,     6,    13,    13,    13,
    13,     0,    11,    18,    19,    20,    21,     2,    24,    29 ]

racc_action_pointer = [
    29,     4,    37,    -2,   nil,   nil,    20,   nil,   nil,   nil,
   nil,    32,    10,    24,   nil,   nil,   nil,   nil,    30,    30,
    30,    30,   nil,    -2,    35,   nil,   nil,   nil,   nil,    36 ]

racc_action_default = [
   -22,   -22,   -22,    -1,   -20,   -21,   -22,   -16,   -17,   -18,
   -19,   -22,   -22,   -22,    -5,   -10,   -12,   -14,    -2,    -7,
    -8,    -9,    30,   -22,    -4,    -6,   -11,   -13,   -15,    -3 ]

racc_goto_table = [
    18,     6,     3,    13,     2,   nil,   nil,    24,   nil,   nil,
   nil,   nil,    23,   nil,   nil,   nil,   nil,    29 ]

racc_goto_check = [
     4,     3,     2,     3,     1,   nil,   nil,     4,   nil,   nil,
   nil,   nil,     3,   nil,   nil,   nil,   nil,     4 ]

racc_goto_pointer = [
   nil,     4,     2,     0,    -6,   nil,   nil,   nil ]

racc_goto_default = [
   nil,   nil,   nil,   nil,   nil,    19,    20,    21 ]

racc_reduce_table = [
  0, 0, :racc_error,
  1, 14, :_reduce_none,
  3, 15, :_reduce_2,
  4, 15, :_reduce_3,
  3, 15, :_reduce_4,
  1, 17, :_reduce_5,
  2, 17, :_reduce_6,
  1, 17, :_reduce_none,
  1, 17, :_reduce_none,
  1, 17, :_reduce_none,
  1, 18, :_reduce_10,
  2, 18, :_reduce_11,
  1, 19, :_reduce_12,
  2, 19, :_reduce_13,
  1, 20, :_reduce_14,
  2, 20, :_reduce_15,
  1, 16, :_reduce_none,
  1, 16, :_reduce_17,
  1, 16, :_reduce_none,
  1, 16, :_reduce_none,
  1, 16, :_reduce_none,
  1, 16, :_reduce_none ]

racc_reduce_n = 22

racc_shift_n = 30

racc_token_table = {
  false => 0,
  :error => 1,
  :FIELD => 2,
  :VALUE => 3,
  :PM => 4,
  :SW => 5,
  :EW => 6,
  "=" => 7,
  "!=" => 8,
  ">" => 9,
  "<" => 10,
  ">=" => 11,
  "<=" => 12 }

racc_nt_base = 13

racc_use_result_var = true

Racc_arg = [
  racc_action_table,
  racc_action_check,
  racc_action_default,
  racc_action_pointer,
  racc_goto_table,
  racc_goto_check,
  racc_goto_default,
  racc_goto_pointer,
  racc_nt_base,
  racc_reduce_table,
  racc_token_table,
  racc_shift_n,
  racc_reduce_n,
  racc_use_result_var ]

Racc_token_to_s_table = [
  "$end",
  "error",
  "FIELD",
  "VALUE",
  "PM",
  "SW",
  "EW",
  "\"=\"",
  "\"!=\"",
  "\">\"",
  "\"<\"",
  "\">=\"",
  "\"<=\"",
  "$start",
  "narrow",
  "siki",
  "kankei",
  "value",
  "pm",
  "sw",
  "ew" ]

Racc_debug_parser = false

##### State transition tables end #####

# reduce 0 omitted

# reduce 1 omitted

module_eval(<<'.,.,', 'narrow_parser.y', 5)
  def _reduce_2(val, _values, result)
     result = val[0] + "\t" + val[1] + val[2] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 6)
  def _reduce_3(val, _values, result)
     result = val[0] + "\n" + val[1] + "\t" + val[2] + val[3] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 8)
  def _reduce_4(val, _values, result)
               if result.rindex(/\n\S\t/) then
             result = val[0] + $& + val[1] + val[2]
           elsif /\S\t/ =~ result then
             result = val[0] + "\n" + $& + val[1] + val[2]
           end
          
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 15)
  def _reduce_5(val, _values, result)
     result = "\t" + val[0] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 16)
  def _reduce_6(val, _values, result)
     result = val[0] + "\xfd" + val[1] 
    result
  end
.,.,

# reduce 7 omitted

# reduce 8 omitted

# reduce 9 omitted

module_eval(<<'.,.,', 'narrow_parser.y', 21)
  def _reduce_10(val, _values, result)
     result = "PM\t" + val[0] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 22)
  def _reduce_11(val, _values, result)
     result = val[0] + "\xfd" + val[1] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 24)
  def _reduce_12(val, _values, result)
     result = "SW\t" + val[0] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 25)
  def _reduce_13(val, _values, result)
     result = val[0] + "\xfd" + val[1] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 27)
  def _reduce_14(val, _values, result)
     result = "EW\t" + val[0] 
    result
  end
.,.,

module_eval(<<'.,.,', 'narrow_parser.y', 28)
  def _reduce_15(val, _values, result)
     result = val[0] + "\xfd" + val[1] 
    result
  end
.,.,

# reduce 16 omitted

module_eval(<<'.,.,', 'narrow_parser.y', 30)
  def _reduce_17(val, _values, result)
     result = '!' 
    result
  end
.,.,

# reduce 18 omitted

# reduce 19 omitted

# reduce 20 omitted

# reduce 21 omitted

def _reduce_none(val, _values, result)
  val[0]
end

end   # class NarrowParser


