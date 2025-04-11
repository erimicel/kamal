module Kamal::Commands::Accessory::Backup
  def backup(options = {})
    type = detect_accessory_type

    case type
    when :mysql, :postgresql
      unless backup_env_variables_set?
        # TODO: Add port env?
        say "Backup not supported for #{service_name} (missing env variables)", :red
        say "Please set BACKUP_DB_USER, BACKUP_DB_PASSWORD, and BACKUP_DB_NAME", :red
        raise
      end

      db_backup(type, options)
    when :redis
      redis_backup(options)
    else
      raise "Backup not supported for #{service_name} (#{type || 'unknown type'})"
    end
  end

  def backup_cleanup(remote_path)
    execute_in_existing_container "rm", remote_path
  end

  private
    def db_backup(type, options = {})
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      filename = "#{service_name}_#{type}_backup_#{timestamp}.sql"
      remote_path = "/tmp/#{filename}"

      case type
      when :mysql
        execute_in_existing_container "bash", "-c",
          "mysqldump --single-transaction -u $BACKUP_DB_USER -p$BACKUP_DB_PASSWORD $BACKUP_DB_NAME > #{remote_path}"
      when :postgresql
        execute_in_existing_container "bash", "-c",
          "PGPASSWORD=$BACKUP_DB_PASSWORD pg_dump -U $BACKUP_DB_USER -d $BACKUP_DB_NAME -F plain > #{remote_path}"
      end

      [ remote_path, filename ]
    end

    def redis_backup(options = {})
      # TODO: Valkey?
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      filename = "#{service_name}_redis_backup_#{timestamp}.rdb"
      remote_path = "/tmp/#{filename}"

      execute_in_existing_container "redis-cli", "SAVE"
      execute_in_existing_container "bash", "-c", "cp /data/dump.rdb #{remote_path}"

      [ remote_path, filename ]
    end

    def detect_accessory_type
      return nil unless image

      image_name = image.downcase

      if image_name.include?("mysql") || image_name.include?("mariadb")
        :mysql
      elsif image_name.include?("postgres")
        :postgresql
      elsif image_name.include?("redis")
        :redis
      else
        nil
      end
    end

    def backup_env_variables_set?
      %w[ BACKUP_DB_USER BACKUP_DB_PASSWORD BACKUP_DB_NAME ].all? { |var| ENV.key?(var) }
    end
end
