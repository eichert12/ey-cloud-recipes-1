#
# Cookbook Name:: sti_nginx
# Recipe:: default
#
node[:applications].each do |app_name,data|
  user = node[:users].first

  case node[:instance_role]
  when "solo", "app", "app_master"

    restart_nginx = false
    
    # Custom nginx conf 
    ey_cloud_report "nginx config" do
      message "Configuring nginx"
    end

    if File.exists?("/data/#{app_name}/current/config/ey_config/nginx/custom.conf")
      ey_cloud_report "nginx config copy" do
        message "Copying custom rewrites"
      end

      execute "Copy custom.conf to nginx custom.conf file" do
        command "cp /data/#{app_name}/current/config/ey_config/nginx/custom.conf /data/nginx/servers/#{app_name}/custom.conf"
        user node[:owner_name]
        cwd "/data/#{app_name}/current"
      end
      
      # We do this since the ssl.conf file doesn't include the custom.conf file, instead includes the custom.ssl.conf file
      execute "Copy custom.conf to nginx custom.ssl.conf file" do
        command "cp /data/#{app_name}/current/config/ey_config/nginx/custom.conf /data/nginx/servers/#{app_name}/custom.ssl.conf"
        user node[:owner_name]
        cwd "/data/#{app_name}/current"
      end

      restart_nginx = true

    else

      ey_cloud_report "nginx config - None detected" do
        message "No custom nginx rewrites"
        message "/data/#{app_name}/current/config/ey_config/nginx/custom.conf does not exist"
      end

    end
    
    
    # SSL Cert
    # Required settings:
    # * certificate_path
    # * certificate_key_path
    # * cert_name
    # * server_name 

    ey_cloud_report "nginx ssl config" do
      message "Configuring nginx to use custom SSL certs"
    end
    if File.exists?("/data/#{app_name}/current/config/ey_config/nginx/ssl_settings.yml")
      nginx_ssl_settings = YAML.load(IO.read(File.join("/data/#{app_name}/current/config/ey_config", "nginx", "ssl_settings.yml")))
      unless nginx_ssl_settings[node[:environment][:framework_env]].nil? or File.exists?("/etc/nginx/servers/#{app_name}.ssl.conf")
        
        execute "Copy certificate .crt file to nginx ssl directory" do
          command "cp /data/#{app_name}/current/certs/cert.crt /data/nginx/ssl/<%=@app_name%>.crt"
          user node[:owner_name]
          cwd "/data/#{app_name}/current"
        end
        
        execute "Copy certificate .key file to nginx ssl directory" do
          command "cp /data/#{app_name}/current/certs/cert.key /data/nginx/ssl/<%=@app_name%>.key"
          user node[:owner_name]
          cwd "/data/#{app_name}/current"
        end
        
        template "/etc/nginx/servers/#{app_name}.ssl.conf" do
          owner "root"
          group "root"
          mode 0644
          source "app.ssl.conf.erb"
          backup false
          action :create
          variables({
            :app_name => app_name,
            :server_name => data[:vhosts][:domain_name],
            :cert_name => app_name,
            :framework_env => node[:environment][:framework_env]
          })
        end
        
        unless File.exists?("/etc/nginx/servers/#{app_name}/custom.ssl.conf")
          execute "Creating an empty custom.ssl.conf (to prevent errors)" do
            command "touch /etc/nginx/servers/#{app_name}/custom.ssl.conf"
            user node[:owner_name]
            cwd "/data/#{app_name}/current"
          end
        end

        restart_nginx = true
        
      else
        ey_cloud_report "nginx ssl config - No ssl settings for this environment or environment already has ssl assigned for this app" do
          message "nginx ssl config - No ssl settings for this environment or already exists ssl assigned for this app" 
          message "- current environment: #{node[:environment][:framework_env]})"
          message "- does /etc/nginx/servers/#{app_name}.ssl.conf exist: #{File.exists?("/etc/nginx/servers/#{app_name}.ssl.conf")}"
        end
      end
    else
      ey_cloud_report "nginx ssl config - None detected" do
        message "No custom SSL certs"
        message "/data/#{app_name}/current/config/ey_config/nginx/ssl_settings.yml does not exist"
      end
    end
    
    # If changes where made, restart nginx!
    if restart_nginx
      service "nginx" do
        supports :status => true, :stop => true, :restart => true
        action :restart
      end
    end
  end
end
