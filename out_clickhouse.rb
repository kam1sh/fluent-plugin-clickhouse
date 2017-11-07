require 'fluent/output'
require 'fluent/config/error'
require 'net/http'
require 'date'

module Fluent
    class ClickhouseOutput < BufferedOutput
        Fluent::Plugin.register_output("clickhouse", self)

        DEFAULT_TIMEKEY = 60 * 60 * 24

        desc "IP or fqdn of ClickHouse node"
        config_param :host, :string
        desc "Port of ClickHouse HTTP interface"
        config_param :port, :integer, default: 8123
        desc "Database to use"
        config_param :database, :string, default: "default"
        desc "Table to use"
        config_param :table, :string
        desc "Offset in minutes, could be useful to substract timestamps because of timezones"
	    config_param :tz_offset, :integer, default: 0
	    # TODO auth and SSL params. and maybe gzip
        desc "Order of fields while insert"
	    config_param :fields, :array, value_type: :string
        config_section :format do
            config_set_default :@type, "out_file"
        end
        config_section :buffer do
            config_set_default :@type, "file"
            config_set_default :chunk_keys, ["time"]
            config_set_default :flush_at_shutdown, true
            config_set_default :timekey, DEFAULT_TIMEKEY
        end

        def configure(conf)
            super
            @host       = conf["host"]
            @port       = conf["port"] || 8123
            @uri_str    = "http://#{ conf['host'] }:#{ conf['port']}/"
            @database   = conf["database"] || "default"
            @table      = conf["table"]
            @fields     = fields.select{|f| !f.empty? }
            @tz_offset  = conf["tz_offset"].to_i
        	uri = URI(@uri_str)
            begin
            	res = Net::HTTP.get_response(uri)
            rescue Errno::ECONNREFUSED
            	raise Fluent::ConfigError, "Couldn't connect to ClickHouse at #{ @uri_str } - connection refused" 
            end
            if res.code != "200"
                raise Fluent::ConfigError, "ClickHouse server responded non-200 code: #{ res.body }"
            end
        end

        def format(tag, timestamp, record)
            datetime = Time.at(timestamp + @tz_offset * 60).to_datetime
            row = Array.new
            @fields.map { |key|
            	case key
                when "tag" 
            		row << tag
            	when "_DATETIME"
            		row << datetime.strftime("%s")          # To UNIX timestamp
            	when "_DATE"
            		row << datetime.strftime("%Y-%m-%d")	# ClickHouse 1.1.54292 has a bug in parsing UNIX timestamp into Date. 
            	else
            	    row << record[key]
            	end
            }
            "#{row.join("\t")}\n"
    	end

        def write(chunk)
            http = Net::HTTP.new(@host, @port.to_i)
            uri = URI.encode("#{ @uri_str }?query=INSERT INTO #{ @database }.#{ @table } FORMAT TabSeparated")
            req = Net::HTTP::Post.new(URI.parse(uri))
            req.body = chunk.read
            resp = http.request(req)
            if resp.code != "200"
            	log.warn "Clickhouse responded: #{resp.body}"
            end
        end
    end
end
