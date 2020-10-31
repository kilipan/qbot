# frozen_string_literal: true

# Configuration command for the admin module.
module Admin
  extend Discordrb::Commands::CommandContainer

  # rubocop: disable Metrics/BlockLength
  command :config, {
    aliases: [:cfg],
    help_available: true,
    description: 'Sets various configuration options for the bot',
    usage: '.cfg <args>',
    min_args: 0
  } do |event, *args|
    log(event)
    command = args.shift

    case command
    when 'help', ''
      Config.help_msg event, 'cfg', {
        help: 'show this message',
        prefix: 'set the command prefix for this server',
        'extra-color-role': 'configure extra color roles',
        snippet: 'add, remove, or modify snippets for this server',
        'rolegroup': 'manage groups of self-assignable roles',
        'reaction': 'configure reaction actions'
      }

    when 'prefix', 'pfx'
      cfg = Config[event.server.id]
      subcmd = args.shift

      case subcmd
      when 'help', ''
        Config.help_msg event, 'cfg prefix', {
          set: 'set the prefix for this server',
          reset: 'resets the prefix to the default'
        }
      when 'set'
        Config.save_prefix event, cfg, args.shift
      when 'reset'
        Config.save_prefix event, cfg, QBot.config.global.prefix || '.'
      end

    when 'extra-color-role', 'ecr'
      subcmd = args.shift
      role_id = args.shift.to_i

      case subcmd
      when 'help', ''
        Config.help_msg event, 'cfg extra-color-role', {
          list: 'print the list of extra color roles',
          add: 'add a role (by ID) to the list of extra roles',
          remove: 'remove a role (by ID) from the list of extra roles'
        }

      when 'list'
        role_rows = ExtraColorRole.where(server_id: event.server.id)
        return 'No extra color roles configured yet.' if role_rows.empty?

        roles = role_rows.map { event.server.role(_1.role_id.to_i) }

        role_descriptions = roles.map {
          hex = _1.color.hex.rjust(6, '0')
          "##{hex} #{_1.id} #{1.name}"
        }

        embed event, "```#{role_descriptions}```"

      when 'add'
        role = event.server.role(role_id)
        return 'Role not found.' unless role

        begin
          ExtraColorRole.create(server_id: event.server.id, role_id: role_id)
        rescue ActiveRecord::RecordNotUnique
          return 'That role is already in the list.'
        end

        embed event, "Role `#{role.name}` (`#{role.id}`) added to the list of extra color roles."

      when 'remove', 'del', 'rm'
        ExtraColorRole.where(role_id: role_id).delete_all

        embed event, "Removed #{role_id} from the list of extra color roles if it was there."
      end
    end
  end
  # rubocop: enable Metrics/BlockLength
end
