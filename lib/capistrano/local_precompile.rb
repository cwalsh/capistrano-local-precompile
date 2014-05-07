require 'capistrano'

module Capistrano
  module LocalPrecompile

    def self.load_into(configuration)
      configuration.load do

        set(:precompile_cmd)   { "RAILS_ENV=#{rails_env.to_s.shellescape} #{asset_env} #{rake} assets:precompile" }
        set(:cleanexpired_cmd) { "RAILS_ENV=#{rails_env.to_s.shellescape} #{asset_env} #{rake} assets:clean_expired" }
        set(:assets_dir)       { "public/assets" }

        set(:turbosprockets_enabled)    { false }
        set(:turbosprockets_backup_dir) { "public/.assets" }

        before "deploy:assets:precompile", "deploy:assets:prepare"
        after "deploy:assets:precompile", "deploy:assets:cleanup"

        namespace :deploy do
          namespace :assets do

            task :cleanup, :on_no_matching_servers => :continue  do
              if fetch(:turbosprockets_enabled)
                run_locally "mv #{fetch(:assets_dir)} #{fetch(:turbosprockets_backup_dir)}"
              else
                run_locally "rm -rf #{fetch(:assets_dir)}"
              end
            end

            task :prepare, :on_no_matching_servers => :continue  do
              if fetch(:turbosprockets_enabled)
                run_locally "mkdir -p #{fetch(:turbosprockets_backup_dir)}"
                run_locally "mv #{fetch(:turbosprockets_backup_dir)} #{fetch(:assets_dir)}"
                run_locally "#{fetch(:cleanexpired_cmd)}"
              end
              run_locally "#{fetch(:precompile_cmd)}"
            end

            desc "Precompile assets locally and then rsync to app servers"
            task :precompile, :on_no_matching_servers => :continue do

              local_manifest_path = run_locally "ls #{assets_dir}/manifest*"
              local_manifest_path.strip!
              copy_options = {:only => { assets_role => true }, :except => { :no_release => true },
                :recursive => true, via: :scp}
              top.upload "./#{fetch(:assets_dir)}/", "#{release_path}/#{fetch(:assets_dir)}/", copy_options
              top.upload "./#{local_manifest_path}", "#{release_path}/assets_manifest#{File.extname(local_manifest_path)}", copy_options
            end
          end
        end
      end
    end

  end
end

if Capistrano::Configuration.instance
  Capistrano::LocalPrecompile.load_into(Capistrano::Configuration.instance)
end
