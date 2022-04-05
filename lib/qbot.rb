# frozen_string_literal: true

##
# Base QBot class. An extension of the discordrb CommandBot.
class QBot < Discordrb::Commands::CommandBot
  attr_accessor :config, :options, :version

  include Singleton

  prepend QBotPatches
  include QBotOptions
  include HookRegistry
  include CLIRegistry
  include QBotModules

  def self.bot = instance

  # rubocop: disable Metrics/MethodLength
  def initialize
    @options = parse_options(ARGV)
    @config  = init_config

    token     = @config.token     || raise('No token in configuration; set token')
    client_id = @config.client_id || raise('No client_id in configuration; set client_id')

    super(
      token: token,
      client_id: client_id,
      name: 'QueryBot',
      prefix: method(:cmd_prefix),
      fancy_log: true,
      ignore_bots: true,
      no_permission_message: 'You are not allowed to do that',
      help_command: false,
      intents: Discordrb::INTENTS.keys - %i[
        server_presences
        server_message_typing
        direct_message_typing
      ]
    )
  end
  # rubocop: enable Metrics/MethodLength

  # minimize log spam
  def inspect = '[QBot]'

  def execute_command(name, event, *rest)
    check_hooks(name, event)
    super
  end

  def self.log
    @log ||= init_log
  end

  def self.options
    instance.options
  end

  def run
    print_logo

    init_db
    load_all_modules

    register_ready_handler
    register_ctrlc_handler
    at_exit { stop }

    super :async

    run_cli
    sync
  end

  def dbname
    conf = config.database

    if @options.state_dir && conf.type == 'sqlite3'
      File.join(@options.state_dir, conf.db)
    else
      conf.db
    end
  end

  def init_db
    conf = config.database

    ActiveRecord::Base.establish_connection(
      adapter: conf.type,
      database: dbname,
      username: conf.user,
      password: conf.pass
    )

    QBot.log.info 'Database connection initialized.'
  end

  def register_ready_handler
    ready do |event|
      self.class.log.info 'Bot ready.'
      event.bot.playing = "version #{QBOT_VERSION}"
    end
  end

  def register_ctrlc_handler
    trap :INT do
      self.class.log.info 'Ctrl-C caught, exiting gracefully...'
      stop
      exit 130
    end
  end

  def print_logo
    logo = File.read File.join(__dir__, 'resources/logo.txt')
    puts "\n#{logo.chomp}   #{Paint["version #{QBOT_VERSION}", :italic, :bright, :gray]}\n\n"
  end

  def init_config
    (YAML.load_file @options.config_path || {}).to_hashugar
  end

  def load_config
    @config = init_config
    self.class.log.info 'Loaded configuration'
  end

  def self.init_log
    Discordrb::Logger.new(true)
  end
end
