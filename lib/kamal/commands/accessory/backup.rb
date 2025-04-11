module Kamal::Commands::Accessory::Backup
  def backup(options = {})
    type = detect_accessory_type

    case type
    when :mysql, :postgresql
      db_backup(options)
    when :redis
      redis_backup(options)
    else
      raise "Backup not supported for #{name} (#{type || 'unknown type'})"
    end
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

  private

  def db_backup(options = {})
    type = detect_accessory_type
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = "#{name}_#{type}_backup_#{timestamp}.sql"
    remote_path = "/tmp/#{filename}"

    case type
    when :mysql
      execute_in_existing_container "bash", "-c",
        "mysqldump --single-transaction -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE > #{remote_path}"
    when :postgresql
      execute_in_existing_container "bash", "-c",
        "PGPASSWORD=$POSTGRES_PASSWORD pg_dump -U $POSTGRES_USER -d $POSTGRES_DB -F plain > #{remote_path}"
    end

    [ remote_path, filename ]
  end

  def redis_backup(options = {})
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    filename = "#{name}_redis_backup_#{timestamp}.rdb"
    remote_path = "/tmp/#{filename}"

    # Redis can use SAVE command to trigger backup to disk
    execute_in_existing_container "redis-cli", "SAVE"

    # Copy the RDB file to our temporary location
    execute_in_existing_container "bash", "-c", "cp /data/dump.rdb #{remote_path}"

    [ remote_path, filename ]
  end
end
