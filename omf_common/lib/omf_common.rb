# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'active_support'
require 'active_support/deprecation'
require 'active_support/core_ext'

require 'omf_common/default_logging'
require 'omf_common/version'
require 'omf_common/measure'
require 'omf_common/message'
require 'omf_common/comm'
require 'omf_common/command'
require 'omf_common/auth'
require 'omf_common/core_ext/string'
require 'omf_common/eventloop'

require 'oml4r/logging/oml4r_appender'

include OmfCommon::DefaultLogging

# Set the default encoding to UTF8
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

module OmfCommon
  DEFAULTS = {
      development: {
          eventloop: {
              type: 'em'
          },
          logging: {
              level: {
                  default: 'debug'
              },
              appenders: {
                  stdout: {
                      date_pattern: '%H:%M:%S',
                      pattern: '%d %5l %c{2}: %m\n',
                      color_scheme: 'none'
                  }
              }
          }
      },
      production: {
          eventloop: {
              type: :em
          },
          logging: {
              level: {
                  default: 'info'
              },
              appenders: {
                  rolling_file: {
                      log_dir: '/var/log',
                      size: 10240,
                      keep: 1,
                      date_pattern: '%F %T %z',
                      pattern: '[%d] %-5l %c: %m\n'
                  }
              }

          }
      },
      daemon: {
          daemonize: {
              dir_mode: :script,
              dir: '/tmp',
              backtrace: true,
              log_dir: '/var/log',
              log_output: true
          },
          eventloop: {
              type: :em
          },
          logging: {
              level: {
                  default: 'info'
              },
              appenders: {
                  file: {
                      log_dir: '/var/log',
                      #log_file: 'foo.log',
                      date_pattern: '%F %T %z',
                      pattern: '[%d] %-5l %c: %m\n'
                  }
              }

          }
      },
      local: {
          communication: {
              type: :local,
          },
          eventloop: { type: :local},
          logging: {
              level: {
                  default: 'debug'
              },
              appenders: {
                  stdout: {
                      date_pattern: '%H:%M:%S',
                      pattern: '%d %5l %c{2}: %m\n',
                      color_scheme: 'none'
                  }
              }
          }
      },
      test_daemon: {
          daemonize: {
              dir_mode: :script,
              dir: '/tmp',
              backtrace: true,
              log_dir: '/tmp',
              log_output: true
          },
          eventloop: {
              type: :em
          },
          logging: {
              level: {
                  default: 'debug'
              },
              appenders: {
                  file: {
                      log_dir: '/tmp',
                      #log_file: 'foo.log',
                      date_pattern: '%F %T %z',
                      pattern: '[%d] %-5l %c: %m\n'
                  }
              }
          }
      }
  }

  # Initialise the OMF runtime.
  #
  # The options here can be customised via EC or RC's configuration files.
  #
  # Given the following example EC configuration file (YAML format):
  #
  #   environment: development
  #   communication:
  #     url: amqp://localhost
  #
  # OMF runtime will be configured as:
  #
  #   OmfCommon.init(:development, { communication: { url: "amqp://localhost" }})
  #
  #
  # @example Use AMQP for communication in :development mode
  #
  #   OmfCommon.init(:development, { communication: { url: "amqp://localhost" }})
  #
  # @example Change Logging configuration
  #
  #   options = {
  #     communication: { url: "amqp://localhost" },
  #     logging: {
  #       level: { default: 'debug' },
  #         appenders: {
  #           stdout: {
  #             level: :info,
  #             date_pattern: '%H:%M:%S',
  #             pattern: '%d %5l %c{2}: %m\n'
  #           },
  #           rolling_file: {
  #             level: :debug,
  #             log_dir: '/var/tmp',
  #             size: 1024*1024*50, # max 50mb of each log file
  #             keep: 5, # keep a 5 logs in total
  #             date_pattern: '%F %T %z',
  #             pattern: '[%d] %-5l %c: %m\n'
  #           },
  #         }
  #      }
  #   }
  #
  #   OmfCommon.init(:development, options)
  #
  # @see _init_logging
  #
  # @param [Symbol] op_mode
  # @param [Hash] opts
  #
  def self.init(op_mode, opts = {}, &block)
    opts = _rec_sym_keys(opts)

    if op_mode && defs = DEFAULTS[op_mode.to_sym]
      opts = _rec_merge(defs, opts)
    end
    if dopts = opts.delete(:daemonize)
      dopts[:app_name] ||= "#{File.basename($0, File.extname($0))}_daemon"
      require 'daemons'
      Daemons.run_proc(dopts[:app_name], dopts) do
        init(nil, opts, &block)
      end
      return
    end

    if lopts = opts[:logging]
      _init_logging(lopts) unless lopts.empty?
    end

    unless copts = opts[:communication]
      raise "Missing :communication description"
    end

    if aopts = opts[:auth]
      require 'omf_common/auth/credential_store'
      OmfCommon::Auth::CredentialStore.init(aopts)
    end

    # Initialise event loop
    eopts = opts[:eventloop]
    Eventloop.init(eopts)
    # start eventloop immediately if we received a run block
    eventloop.run do
      Comm.init(copts)
      block.call(eventloop) if block
    end
  end

  # Return the communication driver instance
  #
  def self.comm()
    Comm.instance
  end

  # Return the communication driver instance
  #
  def self.eventloop()
    Eventloop.instance
  end

  class << self
    alias_method :el, :eventloop
  end

  # Load a YAML file and return it as hash.
  #
  # options:
  #   :symbolize_keys FLAG: Symbolize keys if set
  #   :path:
  #      :same - Look in the same directory as '$0'
  #   :remove_root ROOT_NAME: Remove the root node. Throw exception if not ROOT_NAME
  #   :wait_for_readable SECS: Wait until the yaml file becomes readable. Check every SECS
  #   :erb_process flag: Run the content of the loaded file through ERB first before YAML parsing
  #   :erb_safe_level level: If safe_level is set to a non-nil value, ERB code will be run in a
  #                                   separate thread with $SAFE set to the provided level.
  #   :erb_binding binding: Optional binding given to ERB#result
  #
  def self.load_yaml(file_name, opts = {})
    if path_opt = opts[:path]
      case path_opt
        when :same
          file_name = File.join(File.dirname($0), file_name)
        else
          raise "Unknown value '#{path_opt}' for 'path' option"
      end
    end
    if readable_check = opts[:wait_for_readable]
      while not File.readable?(file_name)
        puts "WAIT #{file_name}"
        sleep readable_check # wait until file shows up
      end
    end

    str = File.read(file_name)
    if opts[:erb_process]
      require 'erb'
      str = ERB.new(str, opts[:erb_safe_level]).result(opts[:erb_binding] || binding)
    end
    yh = YAML.load(str)

    if opts[:symbolize_keys]
      yh = _rec_sym_keys(yh)
    end
    if root = opts[:remove_root]
      if yh.length != 1 && yh.key?(root)
        raise "Expected root '#{root}', but found '#{yh.keys.inspect}"
      end
      yh = yh.delete(root)
    end
    yh
  end

  # DO NOT CALL THIS METHOD DIRECTLY
  #
  # By providing logging section via init method, you could custom how logging messages could be written.
  #
  # @example Change default logging level to :default, but :info under OmfEc namespace
  #
  #   {
  #     logging: {
  #       level: { default: 'debug', 'OmfEc' => 'info' }
  #     }
  #   }
  #
  # @example Write logging message to STDOUT, OML, and ROLLING_FILE
  #   {
  #     logging: {
  #       level: { default: 'debug' }, # root logger set to level :debug
  #       appenders: {
  #         stdout: {
  #           level: :info,
  #           date_pattern: '%H:%M:%S', # show hours, mintues, seconds
  #           pattern: '%d %5l %c{2}: %m\n' # show date time, logging level, namespace/class
  #         },
  #         rolling_file: {
  #           level: :debug,
  #           log_dir: '/var/tmp', # files go to /var/tmp
  #           log_file: 'bob', # name of file
  #           size: 1024*1024*50, # max 50mb of each log file
  #           keep: 5, # keep a 5 logs in total
  #           date_pattern: '%F %T %z', # shows date, time, timezone
  #           pattern: '[%d] %-5l %c: %m\n'
  #         },
  #         oml4r: {
  #           appName: 'bob', # OML appName
  #           domain: 'bob_2345', # OML domain (database name)
  #           collect: 'tcp:localhost:3003' # OML server
  #         }
  #       }
  #     }
  #   }
  #
  # @note OmfCommon now ONLY provides support for STDOUT, OML, FILE, and ROLLING_FILE.
  #
  # @param [Hash] opts
  def self._init_logging(opts = {})
    logger = Logging.logger.root

    if level = opts[:level]
      if level.is_a? Hash
        # package level settings
        level.each do |name, lvl|
          if name.to_s == 'default'
            logger.level = lvl.to_sym
          else
            Logging.logger[name.to_s].level = lvl.to_sym
          end
        end
      else
        logger.level = level.to_sym
      end
    end

    if appenders = opts[:appenders]
      logger.clear_appenders
      appenders.each do |type, topts|
        pattern_opts = {
            pattern:  topts.delete(:pattern),
            date_pattern: topts.delete(:date_pattern),
            color_scheme: topts.delete(:color_scheme),
            date_method: topts.delete(:date_method)
        }

        if pattern_opts[:pattern]
          appender_opts = topts.merge(layout: Logging.layouts.pattern(pattern_opts))
        else
          appender_opts = topts
        end

        case type.to_sym
          when :stdout
            $stdout.sync = true
            logger.add_appenders(Logging.appenders.stdout('custom_stdout', appender_opts))
          when :file, :rolling_file
            dir_name = topts.delete(:log_dir) || DEF_LOG_DIR
            file_name = topts.delete(:log_file) || "#{File.basename($0, File.extname($0))}.log"
            path = File.join(dir_name, file_name)
            logger.add_appenders(Logging.appenders.send(type, path, appender_opts))
          when :oml4r
            logger.add_appenders(Logging.appenders.oml4r('oml4r', appender_opts))
          else
            raise "Unknown logging appender type '#{type}'"
        end
      end
    end
  end

  def self._rec_merge(this_hash, other_hash)
    # if the dominant side is not a hash we stop recursing and pick the primitive value
    return other_hash unless other_hash.is_a? Hash

    r = {}
    this_hash.merge(other_hash) do |key, oldval, newval|
      r[key] = oldval.is_a?(Hash) ? _rec_merge(oldval, newval) : newval
    end
  end

  # Recursively Symbolize keys of hash
  #
  def self._rec_sym_keys(hash)
    h = {}
    hash.each do |k, v|
      if v.is_a? Hash
        v = _rec_sym_keys(v)
      elsif v.is_a? Array
        v = v.map {|e| e.is_a?(Hash) ? _rec_sym_keys(e) : e }
      end
      h[k.to_sym] = v
    end
    h
  end

  # Load a config file compatible with Logging gem
  #
  # @param [String] file_path of the logging config file
  def self.load_logging_config(file_path)
    unless file_path.nil?
      l_cfg_mime_type = File.extname(file_path)
      case l_cfg_mime_type
        when /rb/
          load file_path
        when /yml|yaml/
          Logging::Config::YamlConfigurator.load(file_path)
        else
          warn "Invalid config file format for logging, please use Ruby or Yaml."
      end
    end
  end

  def self.load_credentials(opts)
    unless opts.nil?
      OmfCommon::Auth::CertificateStore.instance.register_default_certs(File.expand_path(opts[:root_cert_dir]))
      cert_and_priv_key = File.read(File.expand_path(opts[:entity_cert])) << "\n" << File.read(File.expand_path(opts[:entity_key]))
      OmfCommon::Auth::Certificate.create_from_pem(cert_and_priv_key)
    end
  end
end
