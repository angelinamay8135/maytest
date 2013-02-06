#! ruby -Ku

=begin
  pscli.rb COMMAND LINE and INTERACTIVE MODE program
  K. Tsubouchi @ 4DN
  2013/01/21
=end

require 'rubygems'
require 'ffi-rzmq'
require 'optparse'
require 'yaml'
require 'date'
require './narrow_parser'

# format decimal       =========================================
def with_dec (number, dec)
  return number.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,').rjust(dec, " ")
end

# format time          =========================================
def format_time (time, format)
  date = DateTime.new(time.slice(0,4).to_i, time.slice(4,2).to_i, time.slice(6,2).to_i, time.slice(8,2).to_i, time.slice(10,2).to_i, time.slice(12,2).to_i)
  return date.strftime(format)
end

# format second        =========================================
def format_second (second, format)
  begin
    sec = second.to_i
	rescue
    return nil
  end
  case format
  when "m" then
    sec *= 60
  when "h" then
    sec *= 60 * 60
  when "d" then
    sec *= 60 * 60 * 24
  when "" then
  else
    return nil
  end
  return sec
end

# add error message    =========================================
def add_error_message (errorPreb, messageNew)
  if errorPreb == nil then
    return messageNew
  end
  return errorPreb,messageNew
end

# check status         =========================================
def check_rep_status(command,status)
  errorMessage = nil
  case status
  when "0"
  when "10"
    errorMessage = command + " - " + MESSAGE_HASH["STATUS_10"]
  when "11"
    errorMessage = command + " - " + MESSAGE_HASH["STATUS_11"]
  when "12"
    errorMessage = command + " - " + MESSAGE_HASH["STATUS_12"]
  when "13"
    errorMessage = command + " - " + MESSAGE_HASH["STATUS_13"]
  when "-1"
    errorMessage = command + " - " + MESSAGE_HASH["STATUS_n1"]
  else
    errorMessage = command + " - " + MESSAGE_HASH["STATUS_ELSE"] + ":" + status
  end
  return errorMessage
end

# Prepare context
@context = ZMQ::Context.new(1)

# send and recv_string =========================================
def send_each (send)
  # command
  if send[0] == COMMANDS[2][0] then
    port = BINARY_SERVICE_PORT
  else
    port = TEXT_SERVICE_PORT
  end

  # Prepare socket
  receiver = @context.socket(ZMQ::REQ)
  receiver.connect("tcp://#{IP}:#{port}")

  receiver.send_strings(send)
  receiver.recv_strings(list = [])

  return list
end

# repeat each sends    =========================================
def sends (sends, show_last_count = false, csv = false, header = true)
  psize = 0
  pcount = 0
  errorMessage = nil

  if header then
    if csv then
      if sends[0][5] == "" then
        print MESSAGE_HASH["HEADER_TIME"],",",MESSAGE_HASH["HEADER_COUNT"],",",MESSAGE_HASH["HEADER_SIZE"],"\n"
      else
        # with aggregation groups
        # field to summarize
        sends[0][5].split("\x0a").each {|no|
          if @fieldNOs.include?(no) then
            print @fields[@fieldNOs.index(no)]
          end
          print ","
        }
        print MESSAGE_HASH["HEADER_COUNT"],",",MESSAGE_HASH["HEADER_SIZE"],"\n"
      end
    else
      if sends[0][5] == "" then
        print "\n",MESSAGE_HASH["HEADER_VIEW_TIME"]," ",MESSAGE_HASH["HEADER_VIEW_COUNT"]," ",MESSAGE_HASH["HEADER_VIEW_SIZE"],"\n"
      else
        # with aggregation groups
        print "\n"
        # field to summarize
        sends[0][5].split("\x0a").each {|no|
          if @fieldNOs.include?(no) then
            print @fields[@fieldNOs.index(no)].ljust(19," ")
          end
        }
        print " ",MESSAGE_HASH["HEADER_VIEW_COUNT"]," ",MESSAGE_HASH["HEADER_VIEW_SIZE"],"\n"
      end
    end
  end

  # sending commands loop begin
  sends.each { |send|
    list = send_each(send)
    errorMessage = check_rep_status(send[0], list[0])

    # 0 SEND OK
    if errorMessage == nil then
      case send[0]
      when COMMANDS[0][0] then
      when COMMANDS[1][0] then
        line = ""
        # without Frame6 in SEND command show Frame2 on RECIVED data
        if send[5] == "" then
          line = list[1]
          line.match(/(.*)(\x09)(.*)/)
          psize += $1.to_i
          pcount += $3.to_i
        # with Frame6 in SEND command show Frame3 on RECIVED data
        else
          line = list[2]
          line.split("\x0a").each {|l|
            l.match(/(.*)(\x09)(.*)(\x09)(.*)/)
            psize += $3.to_i
            pcount += $5.to_i
           }
        end
        # output formating
        line.gsub!(/\x09/, ",") # <TAB>
        line.gsub!(Regexp.new("\xfd", nil, 'n'), ",") # <VM>
        if send[5] == "" then
          print format_time(send[1], DISPLAY_DATE_FORMAT)
          if csv then
            print ",", line, "\n"
          else
            values = line.split(",")
            print "   ", with_dec(values[0], 12), "   ",with_dec(values[1], 12), "\n"
          end
        else
          if csv then
            print line, "\n"
          else
            line.split("\x0a").each {|group|
              values = group.split(",")
              print values[0].ljust(19, " ")," ",with_dec(values[1], 12).rjust(14, " ")," ",with_dec(values[2], 12).rjust(14, " "),"\n"
              }
          end
        end
      end
    else
      puts errorMessage
      break
    end
  }

  if errorMessage == nil && !csv then
    print "-".ljust(19,"-"),"   ".ljust(15,"-"),"   ".ljust(15,"-"),"\n"
    print MESSAGE_HASH["FOOTER_VIEW_SUM"],"   ",with_dec(psize, 12),"   ",with_dec(pcount, 12),"\n\n"
    send = sends[0] 
    send = sends.pop if 1 < sends.length
    time = send[1]
    date = DateTime.new(time.slice(0,4).to_i, time.slice(4,2).to_i, time.slice(6,2).to_i, time.slice(8,2).to_i, time.slice(10,2).to_i, time.slice(12,2).to_i)
    print MESSAGE_HASH["FOOTER_VIEW_TIME"],": ",format_time(sends[0][1], DISPLAY_DATE_FORMAT)," => ",(date + Rational(send[2].to_i, 24*60*60)).strftime(DISPLAY_DATE_FORMAT),"\n"
    if show_last_count then
      print MESSAGE_HASH["FOOTER_VIEW_COUNT"],": ",with_dec(@psize, 0)," => ",with_dec(psize, 0),"\n"
      @psize = psize
      print MESSAGE_HASH["FOOTER_VIEW_SIZE"],": ",with_dec(@pcount, 0)," => ",with_dec(pcount, 0),"\n"
      @pcount = pcount
    end
    print MESSAGE_HASH["FOOTER_VIEW_INTERFACE"],": ",sends[0][3].gsub(/\x0a/, " "),"\n" if sends[0][3] != ""
    print MESSAGE_HASH["FOOTER_VIEW_NARROEW"],": ",@narrow_as_input,"\n" if sends[0][4] != ""
  end
end

# repeat each sends and PCAP out ===============================
def pcap_out (sends, pcap)
  # sending commands loop begin
  sends.each { |send|
    list = send_each(send)
    errorMessage = check_rep_status(send[0], list[0])

    # 0 SEND OK
    if errorMessage == nil then
      case send[0]
      when COMMANDS[2][0] then
        # PCAP output
        if pcap != nil then
          pcap.write(list[1])
        else
          puts list[1]
        end
      end
    else
      puts errorMessage
      break
    end
  }
end

# create sends command  ========================================
def create_sends (command, date, duration, step, stepMax, interface, narrow, field)
  sends = nil
  if 0 < step.to_i then
    stepMax = step.to_i
  end
  past = 0
  if command == COMMANDS[1][0] then
    sends = []
    # without aggregation groups
    if field == "" then
      if 0 < stepMax then
        stepMax.step(duration.to_i, stepMax) { |d|
          sends.push([command, (date + Rational(past, 24*60*60)).strftime(SEND_DATE_FORMAT), stepMax.to_s, interface, narrow, field])
          past+=stepMax
         }
      end
    end
    if 0 < duration.to_i - past then
      sends.push([command, (date + Rational(past, 24*60*60)).strftime(SEND_DATE_FORMAT) , (duration.to_i - past).to_s, interface, narrow, field])
    end
  elsif command == COMMANDS[2][0] then
    sends = []
    if 0 < stepMax then
      stepMax.step(duration.to_i, stepMax) { |d|
        sends.push([command, (date + Rational(past, 24*60*60)).strftime(SEND_DATE_FORMAT), stepMax.to_s, interface, narrow])
        past+=stepMax
       }
    end
    if 0 < duration.to_i - past then
      sends.push([command, (date + Rational(past, 24*60*60)).strftime(SEND_DATE_FORMAT) , (duration.to_i - past).to_s, interface, narrow])
    end
  else
  end

  return sends
end

# init with -ci               ==================================
def init_with_ci (view = false)
  list = send_each([COMMANDS[0][0]])
  errorMessage = check_rep_status(COMMANDS[0][0], list[0])

  # 0 SEND OK
  if errorMessage == nil then
    # see each headers
    print MESSAGE_HASH["HEADER_FIELD_TYPE"],":\n" if view
    @field_list = ""
    list[1].split(/\x0a/).each {|no|
      fieldName = ""
      if FIELD_NOS.include?(no) then
        fieldName = FIELDS[FIELD_NOS.index(no)]
      end
      fieldName = "" if fieldName == nil
      @field_list += "   " + no + "." + fieldName + "\n"
      @fields.push(fieldName)
      @fieldNOs.push(no)
     }
    print @field_list if view

    print MESSAGE_HASH["HEADER_INPUT_INTERFACE"],":\n" if view
    @interface_list = ""
    interfacesExists = list[2].split(/\x0a/)
    for count in 1..interfacesExists.length do
      @interface_list += "   " + count.to_s + "." + interfacesExists[count-1] + "\n"
      @interface.push(interfacesExists[count-1])
    end
    print @interface_list if view

    timeMin = list[3]
    @dateMin = DateTime.new(timeMin.slice(0,4).to_i, timeMin.slice(4,2).to_i, timeMin.slice(6,2).to_i, timeMin.slice(8,2).to_i, timeMin.slice(10,2).to_i, timeMin.slice(12,2).to_i)
    print MESSAGE_HASH["HEADER_TIME"],":",@dateMin.strftime(DISPLAY_DATE_FORMAT),"\n" if view
  end
  return errorMessage
end

# read yaml format file from config.yml
config = nil
begin
  config = YAML.load_file("config.yml")
rescue => ex
  p ex
end

# tcp destination and two of port numbers
config_tcp = config["tcp"] if config != nil
if config_tcp != nil && config_tcp["IP"] != nil then
  IP = config_tcp["IP"]
else IP = "127.0.0.12" end
if config_tcp != nil && config_tcp["TEXT_SERVICE_PORT"] != nil then
  TEXT_SERVICE_PORT = config_tcp["TEXT_SERVICE_PORT"]
else TEXT_SERVICE_PORT = "51002" end
if config_tcp != nil && config_tcp["BINARY_SERVICE_PORT"] != nil then
  BINARY_SERVICE_PORT = config_tcp["BINARY_SERVICE_PORT"]
else BINARY_SERVICE_PORT = "51012" end

# List of distinguished names of the sending commands (SEND) (second column abbreviation)
COMMANDS = [["GET_SERVICE_INFO", "I"], ["SEARCH_FLOW", "F"], ["SEARCH_PCAP", "P"], ["SEARCH_FLOW_WITH_HEADER", "FH"]]
WITH_HEADER = "_WITH_HEADER"

command = ""    # distinguished name of the command (required
time = ""       # start time (mandatory in F|FH|P
date = nil      # start time (in DateTime
SEND_DATE_FORMAT = "%Y%m%d%H%M%S" # start time format
DISPLAY_DATE_FORMAT = "%Y/%m/%d %H:%M:%S" # time format to display
duration = "1"  # aggregate time in seconds
durationInteractive = 86400  # duration at first time in interactive mode
step = "0"      # interval time in seconds
stepInteractive = 3600      # step at first time in interactive mode
stepMax = 3600  # max default value of the duration
header = false  # put header on the aggregate results
@interface = []
@interface_list = ""
interface = ""  # input interface
narrow = ""     # refiners
@narrow_as_input = ""
@fields = []
@fieldNOs = []
@field_list = ""
field = ""      # list of field type IDs summarized into lines
pcap = nil      # PCAP output file
pcapFileName = nil      # PCAP output file name
GLBLHD_PCAP = "./glblhd.pcap"      # PCAP header
helpMax = 24    # max line of HELP message
@psize = 0      # last packet size sum
@pcount = 0     # last packet count sum

config_duration = config["duration"] if config != nil
if config_duration != nil then
  durationInteractiveTmp = config_duration["durationInteractive"]
  durationInteractive = durationInteractiveTmp if durationInteractiveTmp != nil && (/^\d+$/ =~ durationInteractiveTmp.to_s) != nil
  stepInteractiveTmp = config_duration["stepInteractive"]
  stepInteractive = stepInteractiveTmp if stepInteractiveTmp != nil && (/^\d+$/ =~ stepInteractiveTmp.to_s) != nil
  stepMaxTmp = config_duration["stepMax"]
  stepMax = stepMaxTmp if stepMaxTmp != nil && (/^\d+$/ =~ stepMaxTmp.to_s) != nil
end

# Parser for the refiners
parser = NarrowParser.new

# Transmission frame
sends = nil

# Message for display the results
message = ""
errorMessage = nil

if config_tcp == nil then
  errorMessage = "config.yml error."
end

# message
message_array = []
# options 
message_array.push(["OPTION_COMMAND", "get_service_Info|search_Flow|search_Pcap"])
message_array.push(["OPTION_TIME", "search TIME begins at YYYYMMDD[hh[mm[ss]]]"])
message_array.push(["OPTION_DURATION", "search time DURATION in seconds"])
message_array.push(["OPTION_STEP", "search time STEP size in seconds"])
message_array.push(["OPTION_INTERFACE", "INTERFACES to filter search"])
message_array.push(["OPTION_NARROW", "expressions for NARROW down search"])
message_array.push(["OPTION_FIELD", "view by FIELD type id list"])
message_array.push(["OPTION_PCAP", "file name of PCAP data output"])
# errors 
message_array.push(["ERROR_NO_COMMAND", ": -h to see option help. "])
message_array.push(["ERROR_COMMAND", ": -c argument only take I|F[H]|P. "])
message_array.push(["ERROR_TIME", ": is invalid argument for -t (YYYYMMDDhhmmss). "])
message_array.push(["ERROR_TIME_DIGIT", ": -t must have argument in 14-digit-number. "])
message_array.push(["ERROR_TIME_REQUIRED", ": -c with F[H],P argument must be specified with -t option. "])
message_array.push(["ERROR_TIME_MINIMUM", ": -t must have argument later than "])
message_array.push(["ERROR_DURATION", ": -d must have argument in numeric (0<n). "])
message_array.push(["ERROR_DURATION_MULTIPLY", ": -d argument in numeric only take d|h|m. "])
message_array.push(["ERROR_STEP", ": -s must have argument in numeric (1<n). "])
message_array.push(["ERROR_STEP_MULTIPLY", ": -s argument in numeric only take d|h|m. "])
message_array.push(["ERROR_INTEFACE", ": -i argument is invalid interface. "])
message_array.push(["ERROR_NARROW_PARSER", ": -n argument is invalid expression. "])
message_array.push(["ERROR_FIELD_TYPE_ID", ": -f argument is invalid filetypeID. "])
message_array.push(["ERROR_INVALID_OPTION", ": is invalid option. "])
message_array.push(["ERROR_MISSING_ARGUMENT", ": argument required. "])
# status 
message_array.push(["STATUS_RECV", "result:"])
message_array.push(["STATUS_0", "OK. "])
message_array.push(["STATUS_10", "(input specification error) start time format error. "])
message_array.push(["STATUS_11", "(input specification error) unknown input interface. "])
message_array.push(["STATUS_12", "(input specification error) unknown field type. "])
message_array.push(["STATUS_13", "(input specification error) unknown comparison operator. "])
message_array.push(["STATUS_n1", "unexpected error. "])
message_array.push(["STATUS_ELSE", "unknown error. "])
# headers and footers
message_array.push(["HEADER_FIELD_TYPE", "field type"])
message_array.push(["HEADER_INPUT_INTERFACE", "input interface"])
message_array.push(["HEADER_TIME", "date time"])
message_array.push(["HEADER_COUNT", "packet count"])
message_array.push(["HEADER_SIZE", "packet size"])
message_array.push(["HEADER_VIEW_TIME", "date time         ."])
message_array.push(["HEADER_VIEW_COUNT", ". packet count"])
message_array.push(["HEADER_VIEW_SIZE", ".  packet size"])
message_array.push(["FOOTER_VIEW_SUM", ".              sum:"])
message_array.push(["FOOTER_VIEW_TIME", "date time"])
message_array.push(["FOOTER_VIEW_COUNT", "packet count"])
message_array.push(["FOOTER_VIEW_SIZE", "packet size"])
message_array.push(["FOOTER_VIEW_INTERFACE", "interface"])
message_array.push(["FOOTER_VIEW_NARROEW", "filters"])
# interact 
message_array.push(["MESSAGE_BEGIN_INTERACT", " === INTERACTIVE MODE BEGIN === "])
message_array.push(["MESSAGE_END_INTERACT", " === INTERACTIVE MODE END === "])
message_array.push(["MESSAGE_MAIN_MENU", " === MAIN MENU === "])
message_array.push(["MESSAGE_MAIN_MENU1", "1.edit filter. "])
message_array.push(["MESSAGE_MAIN_MENU2", "2.redisplay result. "])
message_array.push(["MESSAGE_MAIN_MENU3", "3.specify the file name and output PCAP. "])
message_array.push(["MESSAGE_MAIN_MENU4", "4.reset filter. "])
message_array.push(["MESSAGE_MAIN_MENU_ENTER", "select the operation. (1-4) >>"])
message_array.push(["MESSAGE_MAIN_MENU_ERROR", "is an invalid value. enter empty value to end. "])
message_array.push(["MESSAGE_CONDITION_MENU", " === EDIT FILTER === "])
message_array.push(["MESSAGE_CONDITION_MENU1", "1.start time. (time duration step)"])
message_array.push(["MESSAGE_CONDITION_MENU2", "2.input interface. "])
message_array.push(["MESSAGE_CONDITION_MENU3", "3.filter explession. "])
message_array.push(["MESSAGE_CONDITION_MENU_ENTER", "select the condition to edit (1-3) >>"])
message_array.push(["MESSAGE_CONDITION_MENU_ERROR", "is an invalid value. enter empty value for main menu. "])
message_array.push(["MESSAGE_PCAP_FILE_OUT_ENTER", "enter PCAP output file name. >>"])
message_array.push(["MESSAGE_PCAP_FILE_OUT", "PCAP file output completed. "])
message_array.push(["MESSAGE_DATE", "enter start date. (YYYYMMDD) >> "])
message_array.push(["MESSAGE_CONDITION_TIME_ENTER", "enter start time. (hhmmss[ n[d|h|m][ n[d|h|m]]]) >>"])
message_array.push(["MESSAGE_CONDITION_INTERFACE", " === INPUT INTERFACE === "])
message_array.push(["MESSAGE_CONDITION_INTERFACE_ENTER", "enter input interface. >>"])
message_array.push(["MESSAGE_CONDITION_NARROW", " === FILTER EXPLESSION === "])
message_array.push(["MESSAGE_CONDITION_NARROW_ENTER", "enter filter explession."])
# errors 
message_array.push(["ERROR_CONDITION_DATE", ": invalid date. enter date exists. "])
message_array.push(["ERROR_CONDITION_DATE_DIGIT", ": invalid date. enter in 8-digit-number. "])
message_array.push(["ERROR_CONDITION_DATE_MINIMUM", ": invalid date. enter date later than "])
message_array.push(["ERROR_CONDITION_TIME", ": invalid time. enter time exists. "])
message_array.push(["ERROR_CONDITION_TIME_DIGIT", ": invalid time. enter in 8-digit-number. "])
message_array.push(["ERROR_CONDITION_DURATION", ": enter positive number for duration. "])
message_array.push(["ERROR_CONDITION_DURATION_MULTIPLY", ": for duration only d|h|m can be set after the number. "])
message_array.push(["ERROR_CONDITION_STEP", ": enter positive number for step. "])
message_array.push(["ERROR_CONDITION_STEP_MULTIPLY", ": for step only d|h|m can be set after the number. "])
message_array.push(["ERROR_CONDITION_NARROW_PARSER", ": invalid expression. enter expression in the correct format. "])
message_array.push(["ERROR_CONDITION_INTEFACE", ": invalid input interface. enter input interface from the list. "])
message_array.push(["ERROR_CONDITION_FIELD_TYPE_ID", ": invalid filetypeID. enter filetypeID from the list. "])

config_message = nil
config_message = config["message"] if config != nil
if config_message != nil then
  config_message.each { |key,value|
    message_array.push([key, config_message[key]])
  }
end
MESSAGE_HASH = Hash[*message_array.flatten(1)]

# field names
fields = []
fieldNOs = []
config_field = config["field"] if config != nil
if config_field != nil then
  noMax = config_field["noMax"]
  if (/^\d+$/ =~ noMax.to_s) != nil then
    for i in 0..noMax
      fields.push(config_field["FIELD" + i.to_s])
      fieldNOs.push(i.to_s)
    end
  end
end
FIELDS = fields
FIELD_NOS = fieldNOs

errorMessage = init_with_ci() if errorMessage == nil # fields and interfaces dateMin

# init error             =======================================
if errorMessage != nil then
  puts errorMessage
# Command Lime Mode      =======================================
elsif nil != ARGV[0] then
  # Parses the arguments from command line
  OptionParser.new do |opt|
    # Main command (required
    opt.on('-c VAL', '--command VAL', MESSAGE_HASH["OPTION_COMMAND"]) {|v|
      COMMANDS.each {|fullName, abbr|
        if v.upcase == fullName || v.upcase == abbr then
          command = fullName
          if command.index(WITH_HEADER) then
            command = command.slice(0, command.index(WITH_HEADER))
            header = true
          end
        end
      }
      errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_COMMAND"]) if command == ""
    }
    # start time (mandatory in F|FH|P
    opt.on('-t VAL', '--time VAL', MESSAGE_HASH["OPTION_TIME"]) {|v|
      begin
        if (/^\d+$/ =~ v) != nil && v.length <= 14 then
          time = v
          date = DateTime.new(time.slice(0,4).to_i, time.slice(4,2).to_i, time.slice(6,2).to_i, time.slice(8,2).to_i, time.slice(10,2).to_i, time.slice(12,2).to_i)
          date_temp = DateTime.new(time.slice(0,4).to_i, time.slice(4,2).to_i, time.slice(6,2).to_i)
          date_check = DateTime.new(@dateMin.year, @dateMin.month, @dateMin.day)
          if date_temp < date_check then
            errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_TIME_MINIMUM"] + ": " + @dateMin.strftime(DISPLAY_DATE_FORMAT))
          end
        else
          errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_TIME_DIGIT"])
        end
      rescue ArgumentError
        errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_TIME"])
      end
    }
    # Aggregate time in seconds
    opt.on('-d VAL', '--duration VAL', MESSAGE_HASH["OPTION_DURATION"]) {|v|
      /^(\d+)(.*)/ =~ v
      ans = format_second($1,$2)
      if ans == nil then
        errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_DURATION_MULTIPLY"])
      elsif ans < 1 then
        errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_DURATION"])
      else
        duration = ans.to_s
      end
    }
    # Interval time in seconds
    opt.on('-s VAL', '--step VAL', MESSAGE_HASH["OPTION_STEP"]) {|v|
      /^(\d+)(.*)/ =~ v
      ans = format_second($1,$2)
      if ans == nil then
        errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_STEP_MULTIPLY"])
      elsif ans < 1 then
        errorMessage = add_error_message(errorMessage, v + " " + MESSAGE_HASH["ERROR_STEP"])
      else 
        step = ans.to_s
      end 
    }
    # input interface
    opt.on('-i VAL', '--interface VAL', MESSAGE_HASH["OPTION_INTERFACE"]) {|v|
      interface = v.gsub(/^\s+/,'').gsub(/\s+/, "\x0a").chomp
      interface.split("\x0a").each {|no|
        if @interface.include?(no) then
        else
          errorMessage = add_error_message(errorMessage, no + " " + MESSAGE_HASH["ERROR_INTEFACE"])
        end
       }
    }
    # refiners
    opt.on('-n VAL', '--narrow VAL', MESSAGE_HASH["OPTION_NARROW"]) {|v|
      begin
        narrow = parser.parse(v, @fields, @fieldNOs)
      rescue ParseError
        errorMessage = add_error_message(errorMessage, MESSAGE_HASH["ERROR_NARROW_PARSER"] + $!)
      end
    }
    # list of field type IDs summarized into lines
    opt.on('-f VAL', '--field VAL', MESSAGE_HASH["OPTION_FIELD"]) {|v|
      field = v.gsub(/^\s+/,'').gsub(/\s+/, "\x0a").chomp
      field.split("\x0a").each {|no|
        if @fields.include?(no) then
          field.gsub!(no, @fieldNOs[@fields.index(no)].to_s)
        elsif @fieldNOs.include?(no) then
        else
          errorMessage = add_error_message(errorMessage, no + " " + MESSAGE_HASH["ERROR_FIELD_TYPE_ID"])
        end
      }
    }
    # PCAP output file name
    opt.on('-p VAL', '--pcap VAL', MESSAGE_HASH["OPTION_PCAP"]) {|v|
        pcapFileName = v
    }

    opt.version = '1.0.0' # version

    begin
      opt.parse!(ARGV)
    rescue => ex # option perse error
      case ex
      when OptionParser::InvalidOption then
        /(.*: )(.+)/ =~ ex.message
        errorMessage = add_error_message(errorMessage, $2 + " " + MESSAGE_HASH["ERROR_INVALID_OPTION"])
      when OptionParser::MissingArgument then
        /(.*: )(.+)/ =~ ex.message
        errorMessage = add_error_message(errorMessage, $2 + " " + MESSAGE_HASH["ERROR_MISSING_ARGUMENT"])
      end
    end
  end

  # Create and SEND command
  if errorMessage == nil then
    case command
    when COMMANDS[0][0] then
      errorMessage = init_with_ci(true) # fields and interfaces dateMin
    when COMMANDS[1][0] then
      if date == nil then
        errorMessage = MESSAGE_HASH["ERROR_TIME_REQUIRED"]
      else
        sends = create_sends(COMMANDS[1][0], date, duration, step, stepMax, interface, narrow, field)
        sends(sends, false, true, header)
      end
    when COMMANDS[2][0] then
      if date == nil then
        errorMessage = error_TIME_REQUIRED
      else
        pcapFileName = "./output.pcap" if pcapFileName == nil
        begin
          sends = create_sends(COMMANDS[2][0], date, duration, step, stepMax, interface, narrow, "")
          glblhd_pcap = open(GLBLHD_PCAP, "rb")
          pcap = File.open(pcapFileName, "wb")
          pcap.write(glblhd_pcap.read)
          glblhd_pcap.close
          pcap_out(sends, pcap)
          if pcap != nil then
            pcap.close
          end
        rescue => ex # file open error
          errorMessage = ex.message
        end
      end
    else
       errorMessage = MESSAGE_HASH["ERROR_NO_COMMAND"]
    end
  end

  # Error creating sending commands
  if errorMessage != nil then
    puts errorMessage
  end
else
  # Interactive begin           ================================
  print" " + MESSAGE_HASH["MESSAGE_BEGIN_INTERACT"] + " \n\n"

  # Interactive mode 
  MODE_MAIN_MENU = 0
  MODE_CONDITION = 1
  MODE_VIEW = 2
  MODE_PCAP_FILE_OUT = 3
  MODE_DATE = 4
  MODE_CONDITION_TIME = 11
  MODE_CONDITION_INTERFACE = 12
  MODE_CONDITION_NARROW = 13

  active = true
  mode = MODE_DATE

  # Interactive body begin ============================================
  while active do
    case mode
    when MODE_MAIN_MENU
      print "\n ",MESSAGE_HASH["MESSAGE_MAIN_MENU"]," \n"
      print MESSAGE_HASH["MESSAGE_MAIN_MENU1"],"\n"
      print MESSAGE_HASH["MESSAGE_MAIN_MENU2"],"\n"
      print MESSAGE_HASH["MESSAGE_MAIN_MENU3"],"\n"
      print MESSAGE_HASH["MESSAGE_MAIN_MENU4"],"\n"
      print MESSAGE_HASH["MESSAGE_MAIN_MENU_ENTER"]
      case v = gets.chomp # NEXT.
      when "1"
        mode = MODE_CONDITION
      when "2"
        mode = MODE_VIEW
      when "3"
        mode = MODE_PCAP_FILE_OUT
      when "4"
        mode = MODE_DATE
      when ""
        active = false
      else
        print v," ",MESSAGE_HASH["MESSAGE_MAIN_MENU_ERROR"]," \n"
      end
    when MODE_CONDITION
      print "\n ",MESSAGE_HASH["MESSAGE_CONDITION_MENU"]," \n"
      print MESSAGE_HASH["MESSAGE_CONDITION_MENU1"],"\n"
      print MESSAGE_HASH["MESSAGE_CONDITION_MENU2"],"\n"
      print MESSAGE_HASH["MESSAGE_CONDITION_MENU3"],"\n"
      print MESSAGE_HASH["MESSAGE_CONDITION_MENU_ENTER"]
      case v = gets.chomp # NEXT.
      when "1"
        mode = MODE_CONDITION_TIME
      when "2"
        mode = MODE_CONDITION_INTERFACE
      when "3"
        mode = MODE_CONDITION_NARROW
      when ""
        mode = MODE_MAIN_MENU
      else
        print v," ",MESSAGE_HASH["MESSAGE_CONDITION_MENU_ERROR"]," \n"
      end
    when MODE_VIEW
      sends = create_sends(COMMANDS[1][0], date, duration, step, stepMax, interface, narrow, field)
      sends(sends)
      mode = MODE_MAIN_MENU # NEXT.
    when MODE_PCAP_FILE_OUT
      print MESSAGE_HASH["MESSAGE_PCAP_FILE_OUT_ENTER"]
      case v = gets.chomp # NEXT.
      when ""
        mode = MODE_MAIN_MENU
      else
        pcapFileName = v
        begin
          sends = create_sends(COMMANDS[2][0], date, duration, step, stepMax, interface, narrow, "")
          glblhd_pcap = open(GLBLHD_PCAP, "rb")
          pcap = File.open(pcapFileName, "wb")
          pcap.write(glblhd_pcap.read)
          glblhd_pcap.close
          pcap_out(sends, pcap)
          if pcap != nil then
            pcap.close
          end
          print "\n ** ",MESSAGE_HASH["MESSAGE_PCAP_FILE_OUT"]," \n"
          mode = MODE_MAIN_MENU # NEXT.
        rescue => ex # file open error
          puts ex.message
        end
      end
    when MODE_DATE
      print MESSAGE_HASH["MESSAGE_DATE"]
      v = gets.chomp
      begin
        if v == "" then 
          active = false if date == nil
          errorMessage = ""
          mode = MODE_MAIN_MENU # NEXT.
        elsif (/^\d+$/ =~ v) != nil && v.length <= 8 then
          time_temp = v
          date_temp = DateTime.new(time_temp.slice(0,4).to_i, time_temp.slice(4,2).to_i, time_temp.slice(6,2).to_i)
          date_check = DateTime.new(@dateMin.year, @dateMin.month, @dateMin.day)
          if date_temp < date_check then
            errorMessage = v + " " + MESSAGE_HASH["ERROR_CONDITION_DATE_MINIMUM"] + ": " + @dateMin.strftime(DISPLAY_DATE_FORMAT) 
          else
            time = time_temp
            date = date_temp
            # reset
            duration = durationInteractive.to_s
            step = stepInteractive.to_s
            interface = ""
            narrow = ""
            field = ""
          end
        else
          errorMessage = v + " " + MESSAGE_HASH["ERROR_CONDITION_DATE_DIGIT"]
        end
      rescue ArgumentError
        errorMessage = v + " " +  MESSAGE_HASH["ERROR_CONDITION_DATE"]
      end
      if errorMessage != nil then
        puts errorMessage if errorMessage != ""
        errorMessage = nil
      else
        sends = create_sends(COMMANDS[1][0], date, duration, step, stepMax, interface, narrow, field)
        sends(sends, true)
        mode = MODE_MAIN_MENU # NEXT.
      end
    when MODE_CONDITION_TIME
      print MESSAGE_HASH["MESSAGE_CONDITION_TIME_ENTER"]
      v = gets.chomp
      /^(\S+)(\s*)(\S*)(\s*)(.*)$/ =~ v
      sec = $1
      dur = $3
      ste = $5
      if v == "" then
        errorMessage = ""
        mode = MODE_CONDITION # NEXT.
      elsif sec == nil then
        errorMessage = v + " " + MESSAGE_HASH["ERROR_CONDITION_TIME_DIGIT"]
      elsif (/^\d+$/ =~ sec) != nil && sec.length <= 6 then
        time_tmp = time
        date_tmp = date
        begin
          time = date.strftime("%Y%m%d") + sec
          date = DateTime.new(time.slice(0,4).to_i, time.slice(4,2).to_i, time.slice(6,2).to_i, time.slice(8,2).to_i, time.slice(10,2).to_i, time.slice(12,2).to_i)
        rescue ArgumentError
          errorMessage = sec + " " + MESSAGE_HASH["ERROR_CONDITION_TIME"]
        end
        if errorMessage != nil then
          time = time_tmp
          date = date_tmp
        end
      else
        errorMessage = sec + " " + MESSAGE_HASH["ERROR_CONDITION_TIME_DIGIT"]
      end
      if dur != nil && dur != "" then
        /^(\d+)(.*)/ =~ dur
        ans = format_second($1,$2)
        if ans == nil then
          errorMessage = add_error_message(errorMessage, dur + " " + MESSAGE_HASH["ERROR_CONDITION_DURATION_MULTIPLY"])
        elsif ans < 1 then
          errorMessage = add_error_message(errorMessage, dur + " " + MESSAGE_HASH["ERROR_CONDITION_DURATION"])
        else 
          duration = ans.to_s
        end
      end
      if ste != nil && ste != "" then
        /^(\d+)(.*)/ =~ ste
        ans = format_second($1,$2)
        if ans == nil then
          errorMessage = add_error_message(errorMessage, ste + " " + MESSAGE_HASH["ERROR_CONDITION_STEP_MULTIPLY"])
        elsif ans < 1 then
          errorMessage = add_error_message(errorMessage, ste + " " + MESSAGE_HASH["ERROR_CONDITION_STEP"])
        else 
          step = ans.to_s
        end
      end
      if errorMessage != nil then
        puts errorMessage if errorMessage != ""
        errorMessage = nil
      else
        sends = create_sends(COMMANDS[1][0], date, duration, step, stepMax, interface, narrow, field)
        sends(sends, true)
        mode = MODE_CONDITION # NEXT.
      end
    when MODE_CONDITION_INTERFACE
      print "\n ",MESSAGE_HASH["MESSAGE_CONDITION_INTERFACE"]," \n"
      print @interface_list
      print MESSAGE_HASH["MESSAGE_CONDITION_INTERFACE_ENTER"]
      v = gets.chomp
      if v == "" then
        errorMessage = ""
        mode = MODE_CONDITION # NEXT.
      else
        interface = v.gsub(/^\s+/,'').gsub(/\s+/, "\x0a").chomp
        interface.split("\x0a").each {|no|
          if @interface.include?(no) then
          else
            errorMessage = add_error_message(errorMessage, no + " " + MESSAGE_HASH["ERROR_CONDITION_INTEFACE"])
          end
        }
      end
      if errorMessage != nil then
        puts errorMessage if errorMessage != ""
        errorMessage = nil
      else
        sends = create_sends(COMMANDS[1][0], date, duration, step, stepMax, interface, narrow, field)
        sends(sends, true)
        mode = MODE_CONDITION # NEXT.
      end
    when MODE_CONDITION_NARROW
      print "\n ",MESSAGE_HASH["MESSAGE_CONDITION_NARROW"]," \n"
      print @field_list
      print MESSAGE_HASH["MESSAGE_CONDITION_NARROW_ENTER"]," (",@narrow_as_input,") >>"
      v = gets.chomp
      if v == "" then
        errorMessage = ""
        mode = MODE_CONDITION # NEXT.
      elsif /^(\S+)([?])$/ =~ v then
        v = $1
        field = v.gsub(/^\s+/,'').gsub(/\s+/, "\x0a").chomp
        field.split("\x0a").each {|no|
          if @fields.include?(no) then
            field.gsub!(no, @fieldNOs[@fields.index(no)].to_s)
          elsif @fieldNOs.include?(no) then
          else
            errorMessage = add_error_message(errorMessage, no + " " + MESSAGE_HASH["ERROR_CONDITION_FIELD_TYPE_ID"])
          end
        }
      else
        begin
          narrow += "\x0a" if narrow != ""
          narrow += parser.parse(v, @fields, @fieldNOs)
          @narrow_as_input += " " if @narrow_as_input != ""
          @narrow_as_input += v
        rescue ParseError
          errorMessage = MESSAGE_HASH["ERROR_CONDITION_NARROW_PARSER"] + $!.to_s
        end
      end
      if errorMessage != nil then
        puts errorMessage if errorMessage != ""
        errorMessage = nil
      else
        sends = create_sends(COMMANDS[1][0], date, duration, step, stepMax, interface, narrow, field)
        sends(sends, true)
        if field != "" then
          field = ""
        else
          mode = MODE_CONDITION # NEXT.
        end
      end
    else
      print "INVALID! \n"
      active = false
    end
  end
  # Interactive body end ==============================================

  print "\n " + MESSAGE_HASH["MESSAGE_END_INTERACT"] + " \n"
  # Interactive end    =================================================
end
