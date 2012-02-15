#!/usr/bin/env ruby1.8

require 'rubygems'
require 'fog'

config = YAML::load_file('config.yml')

connection = Fog::Storage.new({
  :provider => 'AWS',
  :aws_secret_access_key => config['aws_secret_access_key'],
  :aws_access_key_id => config['aws_access_key_id'],
  :region => config['region']
})

bucket_name = config['bucket_name']

begin
  directory = connection.directories.get(bucket_name)
rescue
  puts "No bucket yet."
end

if directory.nil?

  directory = connection.directories.create({
    :key => bucket_name,
    :public => false,
    :location => config['region']
  })

end

begin
  lifecycle = connection.get_bucket_lifecycle(bucket_name)
rescue
  puts "No lifecycle"
end

lifecycle_data = {'Rules' => [{'ID' => 'flush_backups', 'Prefix' => '*', 'Enabled' => true, 'Days' => config['lifecycle']}]}

if lifecycle.nil?
  connection.put_bucket_lifecycle(bucket_name, lifecycle_data)
else
  puts lifecycle.inspect
end

databases = config['databases']

if !File.exists?('tmp')
  FileUtils.mkdir('tmp')
end

databases.each do |db_name|
  
  backup_file_name = [db_name, Time.now.to_s].join('-') + ".sql.gz"
  backup_file_path = File.join('tmp', backup_file_name)
  
  puts "Backing up #{db_name} to #{backup_file_path}..."
  
  if config['mysql']['password']
    password_arguments = "--password=#{config['mysql']['password']}"
  end
  
  if config['mysql']['username']
    username_arguments = "-u #{config['mysql']['username']}"
  end
  
  if config['mysqldump_path']
    mysqldump_binary = config['mysqldump_path']
  else
    mysqldump_binary = "mysqldump"
  end
  
  dump_command = "#{mysqldump_binary} -h #{config['mysql']['hostname']} #{username_arguments} #{password_arguments} #{db_name} | gzip -c"
  
  if config['ssh']
    command = "ssh #{config['ssh']['username']}@#{config['ssh']['hostname']} '#{dump_command}' > \"#{backup_file_path}\""
  else
    command = "#{dump_command} > \"#{backup_file_path}\""
  end
  
  `#{command}`
  
  puts "Storing #{backup_file_name} on S3..."
  
  backup_file_on_s3 = directory.files.create({
    :key => File.join(db_name, backup_file_name),
    :body => File.open(backup_file_path),
    :public => false,
    :encryption => 'AES256'
  })
  
  FileUtils.rm(backup_file_path)
end
